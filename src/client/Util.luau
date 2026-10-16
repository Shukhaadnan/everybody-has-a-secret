-- Util.luau: shared client helpers for "Everybody Has a Secret".
-- UI builders, tweens, HudScale, remotes (safe WaitForChild), shared-module loading, sfx, modal manager,
-- tiny signals and participant/name lookup. Every other client module requires this via script.Parent.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")
local Debris = game:GetService("Debris")

local U = {}
U.player = Players.LocalPlayer

U.FONT = Enum.Font.FredokaOne
U.BOLD = Enum.Font.GothamBold
U.BODY = Enum.Font.GothamMedium

U.TIER = {
	Easy = Color3.fromHex("3ddc84"),
	Medium = Color3.fromHex("ffc83d"),
	Hard = Color3.fromHex("ff4d4d"),
	Legendary = Color3.fromHex("b36bff"),
}
U.C = {
	bg = Color3.fromRGB(20, 24, 44),
	panel = Color3.fromRGB(32, 38, 68),
	panel2 = Color3.fromRGB(44, 52, 90),
	line = Color3.fromRGB(90, 104, 170),
	gold = Color3.fromRGB(255, 200, 61),
	white = Color3.fromRGB(255, 255, 255),
	muted = Color3.fromRGB(176, 186, 224),
	good = Color3.fromHex("3ddc84"),
	bad = Color3.fromHex("ff4d4d"),
	info = Color3.fromRGB(80, 170, 255),
	event = Color3.fromRGB(255, 140, 50),
	evidence = Color3.fromRGB(60, 220, 230),
	security = Color3.fromRGB(255, 70, 110),
	social = Color3.fromRGB(255, 120, 210),
	purple = Color3.fromHex("b36bff"),
	dark = Color3.fromRGB(10, 12, 22),
}
U.KIND_COLOR = {
	info = U.C.info,
	good = U.C.good,
	bad = U.C.bad,
	event = U.C.event,
	evidence = U.C.evidence,
	security = U.C.security,
	social = U.C.social,
}

function U.tierColor(tier: string?): Color3
	return U.TIER[tier or ""] or U.C.muted
end

-------------------------------------------------------------------------------- signals
export type Signal = {
	Connect: (any, (...any) -> ()) -> { Disconnect: () -> () },
	Fire: (any, ...any) -> (),
}
function U.signal(): any
	local s = { _fns = {} }
	function s:Connect(fn)
		table.insert(self._fns, fn)
		return {
			Disconnect = function()
				local i = table.find(s._fns, fn)
				if i then
					table.remove(s._fns, i)
				end
			end,
		}
	end
	function s:Fire(...)
		for _, fn in ipairs(table.clone(self._fns)) do
			task.spawn(fn, ...)
		end
	end
	return s
end

-------------------------------------------------------------------------------- shared modules
local modCache: { [string]: any } = {}
local modTried: { [string]: boolean } = {}
function U.mod(name: string, timeout: number?): any
	if modTried[name] then
		return modCache[name]
	end
	local inst = ReplicatedStorage:FindFirstChild(name) or ReplicatedStorage:WaitForChild(name, timeout or 10)
	modTried[name] = true
	if inst and inst:IsA("ModuleScript") then
		local ok, res = pcall(require, inst)
		if ok and type(res) == "table" then
			modCache[name] = res
		else
			warn("[EHAS client] could not require " .. name .. ": " .. tostring(res))
		end
	end
	return modCache[name]
end

function U.preload(names: { string })
	local left = #names
	for _, n in ipairs(names) do
		task.spawn(function()
			U.mod(n, 10)
			left -= 1
		end)
	end
	local t0 = os.clock()
	while left > 0 and os.clock() - t0 < 12 do
		task.wait(0.1)
	end
end

function U.zone(id: string?): any
	local Z = U.mod("Zones")
	if not (Z and id) then
		return nil
	end
	if type(Z.byId) == "table" and Z.byId[id] then
		return Z.byId[id]
	end
	if type(Z.list) == "table" then
		for _, z in ipairs(Z.list) do
			if z.id == id then
				return z
			end
		end
	end
	return nil
end

function U.zoneName(id: string?): string
	local z = U.zone(id)
	if z then
		return (z.icon and (z.icon .. " ") or "") .. tostring(z.name or id)
	end
	return tostring(id or "?")
end

function U.itemInfo(id: string?): any
	local I = U.mod("Items")
	return (I and id and I[id]) or nil
end

-------------------------------------------------------------------------------- remotes
local remotesFolder: Instance? = nil
local function getFolder(): Instance?
	if remotesFolder and remotesFolder.Parent then
		return remotesFolder
	end
	remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 60)
	return remotesFolder
end

local remoteCache: { [string]: Instance } = {}
function U.remote(name: string): any
	if remoteCache[name] then
		return remoteCache[name]
	end
	local f = getFolder()
	if not f then
		return nil
	end
	local r = f:WaitForChild(name, 30)
	if r then
		remoteCache[name] = r
	end
	return r
end

-- Listen to a server->client RemoteEvent; payload is always handed over as a table.
function U.on(name: string, fn: (any) -> ())
	task.spawn(function()
		local r = U.remote(name)
		if not (r and r:IsA("RemoteEvent")) then
			warn("[EHAS client] missing remote " .. name)
			return
		end
		r.OnClientEvent:Connect(function(payload)
			local ok, err = pcall(fn, type(payload) == "table" and payload or {})
			if not ok then
				warn("[EHAS client] " .. name .. " handler: " .. tostring(err))
			end
		end)
	end)
end

function U.fire(action: string, args: any?)
	task.spawn(function()
		local r = U.remote("Action")
		if r and r:IsA("RemoteEvent") then
			r:FireServer(action, args or {})
		end
	end)
end

-------------------------------------------------------------------------------- sound
local soundTemplates: { [string]: Sound } = {}
local function template(name: string): Sound?
	if soundTemplates[name] then
		return soundTemplates[name]
	end
	local S = U.mod("Sfx")
	local def = S and S[name]
	if type(def) ~= "table" or type(def.id) ~= "string" or def.id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = "EHAS_" .. name
	s.SoundId = def.id
	s.Volume = tonumber(def.vol) or 0.6
	soundTemplates[name] = s
	return s
end
U.soundTemplate = template

function U.sfx(name: string?, pos: Vector3?, volMul: number?)
	if not name or name == "" then
		return
	end
	local t = template(name)
	if not t then
		return
	end
	local s = t:Clone()
	s.Volume = t.Volume * (volMul or 1)
	if typeof(pos) == "Vector3" then
		local att = Instance.new("Attachment")
		att.Name = "EHAS_SfxAt"
		att.Parent = workspace.Terrain
		att.WorldPosition = pos
		s.RollOffMaxDistance = 150
		s.RollOffMinDistance = 10
		s.Parent = att
		s:Play()
		Debris:AddItem(att, 12)
	else
		s.Parent = SoundService
		s:Play()
		Debris:AddItem(s, 12)
	end
end

-------------------------------------------------------------------------------- ui builders
function U.new(class: string, props: any?, children: { Instance }?): any
	local o = Instance.new(class)
	local parent = nil
	if props then
		for k, v in pairs(props) do
			if k == "Parent" then
				parent = v
			else
				(o :: any)[k] = v
			end
		end
	end
	if children then
		for _, c in ipairs(children) do
			c.Parent = o
		end
	end
	if parent then
		o.Parent = parent
	end
	return o
end

function U.corner(obj: Instance, r: number?): UICorner
	return U.new("UICorner", { CornerRadius = UDim.new(0, r or 14), Parent = obj })
end

function U.round(obj: Instance): UICorner
	return U.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = obj })
end

function U.stroke(obj: Instance, color: Color3?, thick: number?, trans: number?): UIStroke
	return U.new("UIStroke", {
		Color = color or U.C.white,
		Thickness = thick or 3,
		Transparency = trans or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = obj,
	})
end

function U.textStroke(obj: Instance, thick: number?)
	U.new("UIStroke", {
		Color = Color3.new(0, 0, 0),
		Thickness = thick or 2,
		Transparency = 0.35,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Parent = obj,
	})
end

function U.pad(obj: Instance, px: number, py: number?)
	U.new("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, py or px),
		PaddingBottom = UDim.new(0, py or px),
		Parent = obj,
	})
end

function U.list(obj: Instance, dir: Enum.FillDirection?, gap: number?, halign: Enum.HorizontalAlignment?, valign: Enum.VerticalAlignment?): UIListLayout
	local existing = obj:FindFirstChildOfClass("UIListLayout")
	if existing then
		existing:Destroy() -- one layout per container (callers may rebuild contents)
	end
	return U.new("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 8),
		HorizontalAlignment = halign or Enum.HorizontalAlignment.Center,
		VerticalAlignment = valign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = obj,
	})
end

function U.gradient(obj: Instance, a: Color3, b: Color3, rot: number?)
	return U.new("UIGradient", { Color = ColorSequence.new(a, b), Rotation = rot or 90, Parent = obj })
end

function U.frame(parent: Instance?, props: any?): Frame
	local f = U.new("Frame", { BackgroundColor3 = U.C.panel, BorderSizePixel = 0 })
	if props then
		for k, v in pairs(props) do
			(f :: any)[k] = v
		end
	end
	f.Parent = parent
	return f
end

function U.label(parent: Instance?, text: string, size: number?, props: any?): TextLabel
	local l = U.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = U.FONT,
		Text = text,
		TextSize = size or 28,
		TextColor3 = U.C.white,
		TextWrapped = true,
		RichText = true,
		Size = UDim2.new(1, 0, 0, (size or 28) + 8),
	})
	if props then
		for k, v in pairs(props) do
			(l :: any)[k] = v
		end
	end
	l.Parent = parent
	return l
end

-- Button with press feedback + click sound. `fn` is called on activation (debounced 0.15 s).
function U.button(parent: Instance?, text: string, color: Color3?, fn: (() -> ())?, props: any?): TextButton
	local b = U.new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = color or U.C.panel2,
		BorderSizePixel = 0,
		Font = U.FONT,
		Text = text,
		TextSize = 30,
		TextColor3 = U.C.white,
		TextWrapped = true,
		RichText = true,
		Size = UDim2.fromOffset(200, 64),
	})
	if props then
		for k, v in pairs(props) do
			(b :: any)[k] = v
		end
	end
	U.corner(b, 14)
	U.stroke(b, Color3.new(0, 0, 0), 2, 0.55)
	local sc = U.new("UIScale", { Name = "Press", Parent = b })
	local last = 0
	b.MouseButton1Down:Connect(function()
		U.tween(sc, 0.08, { Scale = 0.92 })
	end)
	b.MouseButton1Up:Connect(function()
		U.tween(sc, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	b.MouseLeave:Connect(function()
		U.tween(sc, 0.12, { Scale = 1 })
	end)
	b.Activated:Connect(function()
		if os.clock() - last < 0.15 then
			return
		end
		last = os.clock()
		U.tween(sc, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
		U.sfx("Click", nil, 0.6)
		if fn then
			local ok, err = pcall(fn)
			if not ok then
				warn("[EHAS client] button: " .. tostring(err))
			end
		end
	end)
	b.Parent = parent
	return b
end

function U.tween(obj: Instance, t: number, props: any, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- Pop a frame in/out using its own UIScale named "Pop".
local function popScale(f: Instance): UIScale
	local s = f:FindFirstChild("Pop")
	if not s then
		s = U.new("UIScale", { Name = "Pop", Parent = f })
	end
	return s :: UIScale
end
function U.popIn(f: GuiObject, from: number?)
	local s = popScale(f)
	s.Scale = from or 0.6
	f.Visible = true
	U.tween(s, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
end
function U.popOut(f: GuiObject, after: (() -> ())?)
	local s = popScale(f)
	local tw = U.tween(s, 0.16, { Scale = 0.5 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tw.Completed:Connect(function()
		f.Visible = false
		s.Scale = 1
		if after then
			after()
		end
	end)
end
function U.pulse(obj: GuiObject, amount: number?)
	local s = popScale(obj)
	s.Scale = 1 + (amount or 0.18)
	U.tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Elastic)
end

-------------------------------------------------------------------------------- screen + scale
U.scale = 1
U.scaleChanged = U.signal()
local guis: { UIScale } = {}

local function computeScale(): number
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	return math.clamp(math.min(vp.X, vp.Y) / 1080, 0.4, 1)
end
function U.viewport(): Vector2
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1920, 1080)
end
-- some screens carry text a kid MUST read (tutorial coach, toasts, arcade): on phones they get a higher floor
-- than the 0.4 HUD scale (at 0.4 their text was 5-9 px tall; first-10-min review, top 3)
local function scaleFor(s: UIScale, k: number): number
	local floor = s:GetAttribute("TouchMinScale")
	if type(floor) == "number" and U.isTouch and U.isTouch() then
		return math.max(k, floor)
	end
	return k
end
U.scaleFor = scaleFor
local function rescale()
	local k = computeScale()
	U.scale = k
	for _, s in ipairs(guis) do
		s.Scale = scaleFor(s, k)
	end
	U.scaleChanged:Fire(k)
end
local camConn: RBXScriptConnection? = nil
local function hookCam()
	if camConn then
		camConn:Disconnect()
	end
	local cam = workspace.CurrentCamera
	if cam then
		camConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	rescale()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookCam)
hookCam()

function U.screen(name: string, order: number?, touchMinScale: number?): ScreenGui
	local pg = U.player:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local g = U.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order or 1,
	})
	local s = U.new("UIScale", { Name = "HudScale", Scale = U.scale, Parent = g })
	if touchMinScale then
		s:SetAttribute("TouchMinScale", touchMinScale)
		s.Scale = scaleFor(s, U.scale)
	end
	table.insert(guis, s)
	g.Parent = pg
	return g
end

function U.isTouch(): boolean
	-- workspace attribute Test_Touch (screenshot test places only) forces the phone layout on desktop
	if workspace:GetAttribute("Test_Touch") == true then
		return true
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Roblox jump button rect in REAL pixels (from bottom-right), for phone layouts.
function U.jumpArea(): (number, number)
	local vp = U.viewport()
	local small = math.min(vp.X, vp.Y) <= 500
	local size = small and 70 or 120
	-- Roblox TouchJump geometry: phones 70 px button, top 90 px up, left edge ~95 px from the right;
	-- tablets 120 px button, top edge at size*1.75 = 210 px, left edge size*1.5-10 = 170 px
	local top = small and (20 + size) or math.floor(size * 1.75) -- px from bottom to top of jump button
	local width = small and 95 or math.floor(size * 1.5 - 10) -- px from right edge to left of jump button
	return top, width
end

-- real px -> HudScale units
function U.px(real: number): number
	return real / math.max(U.scale, 0.01)
end

function U.guiInset(): Vector2
	local a = GuiService:GetGuiInset()
	return a
end

-------------------------------------------------------------------------------- modal manager
-- Only one modal at a time: opening a new one closes the others.
local modals: { [string]: () -> () } = {}
U.modalChanged = U.signal()
function U.anyModalOpen(): boolean
	return next(modals) ~= nil
end
function U.openModal(name: string, closeFn: () -> ())
	for n, fn in pairs(modals) do
		if n ~= name then
			modals[n] = nil
			pcall(fn)
			U.modalChanged:Fire(n, false)
		end
	end
	modals[name] = closeFn
	U.modalChanged:Fire(name, true)
end
function U.closedModal(name: string)
	if modals[name] then
		modals[name] = nil
		U.modalChanged:Fire(name, false)
	end
end
function U.closeModal(name: string)
	local fn = modals[name]
	if fn then
		modals[name] = nil
		pcall(fn)
		U.modalChanged:Fire(name, false)
	end
end
function U.closeAllModals()
	for n, fn in pairs(modals) do
		modals[n] = nil
		pcall(fn)
		U.modalChanged:Fire(n, false)
	end
end
function U.isModalOpen(name: string?): boolean
	if name then
		return modals[name] ~= nil
	end
	return next(modals) ~= nil
end

-- Standard modal window: dim backdrop (tap to close) + centered panel with title and X.
function U.window(gui: ScreenGui, title: string, w: number, h: number, accent: Color3?): (Frame, Frame, TextButton, Frame)
	local back = U.new("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 20,
		Parent = gui,
	})
	local panel = U.frame(back, {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, w, 0.92, 0),
		BackgroundColor3 = U.C.bg,
		ZIndex = 21,
		Active = true,
	})
	U.new("UISizeConstraint", { MaxSize = Vector2.new(w, h), Parent = panel })
	U.corner(panel, 22)
	U.stroke(panel, accent or U.C.gold, 4)
	U.gradient(panel, Color3.fromRGB(40, 46, 84), Color3.fromRGB(20, 22, 40), 90)
	local head = U.frame(panel, {
		Name = "Head",
		Size = UDim2.new(1, 0, 0, 74),
		BackgroundColor3 = accent or U.C.gold,
		ZIndex = 22,
	})
	U.corner(head, 22)
	U.frame(head, { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -22), BackgroundColor3 = accent or U.C.gold, ZIndex = 22 })
	local tl = U.label(head, title, 38, {
		Size = UDim2.new(1, -110, 1, 0),
		Position = UDim2.fromOffset(24, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = U.C.dark,
		ZIndex = 23,
	})
	tl.Name = "Title"
	local close = U.button(head, "✖", U.C.bad, nil, {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(60, 56),
		ZIndex = 24,
	})
	local body = U.frame(panel, {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 1, -80),
		ZIndex = 21,
	})
	U.pad(body, 18, 10)
	return back, panel, close, body
end

function U.showWindow(back: GuiObject, panel: GuiObject)
	back.Visible = true
	back.BackgroundTransparency = 1
	U.tween(back, 0.2, { BackgroundTransparency = 0.45 })
	U.popIn(panel, 0.7)
end
function U.hideWindow(back: GuiObject, panel: GuiObject)
	if not back.Visible then
		return
	end
	U.tween(back, 0.16, { BackgroundTransparency = 1 })
	U.popOut(panel, function()
		back.Visible = false
	end)
end

function U.scroll(parent: Instance, props: any?): ScrollingFrame
	local s = U.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = U.C.gold,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	})
	if props then
		for k, v in pairs(props) do
			(s :: any)[k] = v
		end
	end
	s.Parent = parent
	return s
end

function U.clear(parent: Instance, keepClass: { string }?)
	for _, c in ipairs(parent:GetChildren()) do
		local keep = false
		if c:IsA("UIBase") or c:IsA("UIGridStyleLayout") or c:IsA("UIPadding") then
			keep = true
		end
		if keepClass then
			for _, cl in ipairs(keepClass) do
				if c:IsA(cl) then
					keep = true
				end
			end
		end
		if not keep then
			c:Destroy()
		end
	end
end

-------------------------------------------------------------------------------- misc
function U.now(): number
	return workspace:GetServerTimeNow()
end

function U.fmtTime(sec: number): string
	sec = math.max(0, math.floor(sec + 0.5))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

function U.ago(t: number?): string
	if not t then
		return ""
	end
	local d = math.max(0, U.now() - t)
	if d < 60 then
		return string.format("%ds ago", math.floor(d))
	end
	return string.format("%dm ago", math.floor(d / 60))
end

function U.commas(n: number): string
	local s = tostring(math.floor(n))
	local res = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if res:sub(1, 1) == "," then
		res = res:sub(2)
	end
	return res
end

function U.esc(s: any): string
	s = tostring(s or "")
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-------------------------------------------------------------------------------- people
U.names = {} :: { [number]: string }

-- server Bots.luau parents every bot model (attribute BotId) to workspace.EHAS_Bots
function U.botsFolder(): Instance?
	return workspace:FindFirstChild("EHAS_Bots") or workspace:FindFirstChild("Bots")
end

local function botName(m: Instance): string
	local n = m:GetAttribute("DisplayName") or m:GetAttribute("BotName") or m:GetAttribute("Name")
	return type(n) == "string" and n or m.Name
end

function U.nameOf(id: number?): string
	if not id then
		return "?"
	end
	if U.names[id] then
		return U.names[id]
	end
	if id > 0 then
		local p = Players:GetPlayerByUserId(id)
		if p then
			return p.DisplayName
		end
	else
		local f = U.botsFolder()
		if f then
			for _, m in ipairs(f:GetChildren()) do
				if m:GetAttribute("BotId") == id then
					return botName(m)
				end
			end
		end
		return "Guest " .. tostring(-id)
	end
	return "Player"
end

-- Character model for a participant id (real player or bot), or nil.
function U.charOf(id: number): Model?
	if id > 0 then
		local p = Players:GetPlayerByUserId(id)
		return p and p.Character or nil
	end
	local f = U.botsFolder()
	if f then
		for _, m in ipairs(f:GetChildren()) do
			if m:GetAttribute("BotId") == id and m:IsA("Model") then
				return m
			end
		end
	end
	return nil
end

-- All participants (players + bots in workspace.EHAS_Bots with attribute BotId). Excludes self unless asked.
function U.participants(includeSelf: boolean?): { { id: number, name: string, isBot: boolean } }
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if includeSelf or p ~= U.player then
			table.insert(out, { id = p.UserId, name = p.DisplayName, isBot = false })
		end
	end
	local f = U.botsFolder()
	if f then
		for _, m in ipairs(f:GetChildren()) do
			local bid = m:GetAttribute("BotId")
			if type(bid) == "number" then
				table.insert(out, { id = bid, name = botName(m), isBot = true })
			end
		end
	end
	-- names we only know from server payloads (e.g. bots streamed out)
	local seen = {}
	for _, e in ipairs(out) do
		seen[e.id] = true
	end
	for id, n in pairs(U.names) do
		if not seen[id] and id ~= U.player.UserId and (id < 0 or Players:GetPlayerByUserId(id)) then
			table.insert(out, { id = id, name = n, isBot = id < 0 })
		end
	end
	table.sort(out, function(a, b)
		if a.isBot ~= b.isBot then
			return not a.isBot
		end
		return a.name < b.name
	end)
	return out
end

local thumbCache: { [number]: string } = {}
-- Sets an ImageLabel to the participant's headshot (real players) or leaves the silhouette for bots.
function U.thumb(img: ImageLabel, id: number)
	if id <= 0 then
		return
	end
	if thumbCache[id] then
		img.Image = thumbCache[id]
		return
	end
	task.spawn(function()
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and type(url) == "string" then
			thumbCache[id] = url
			if img.Parent then
				img.Image = url
			end
		end
	end)
end

-- Avatar circle: headshot for players, a dark silhouette emoji for bots.
function U.avatar(parent: Instance, id: number, size: number, ring: Color3?): Frame
	local holder = U.frame(parent, {
		Name = "Avatar",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = id > 0 and Color3.fromRGB(70, 80, 130) or Color3.fromRGB(28, 30, 44),
	})
	U.round(holder)
	U.stroke(holder, ring or U.C.white, 3)
	if id > 0 then
		local img = U.new("ImageLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = "",
			Parent = holder,
		})
		U.round(img)
		U.thumb(img, id)
	else
		U.label(holder, "👤", math.floor(size * 0.62), {
			Size = UDim2.fromScale(1, 1),
			TextColor3 = Color3.fromRGB(8, 8, 12),
			TextTransparency = 0.05,
		})
	end
	return holder
end

-- Currently held Tool (or nil)
function U.heldTool(): Tool?
	local c = U.player.Character
	return c and c:FindFirstChildOfClass("Tool") or nil
end

function U.hrp(): BasePart?
	local c = U.player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart? or nil
end

return U
