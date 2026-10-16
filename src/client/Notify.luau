-- Notify.luau: toasts (top-center under the timer, colored by kind, max 3), big EventBanner (slides in from the
-- top with a small screen shake), the detention overlay (bars + countdown) and the photo flash + polaroid.
local RunService = game:GetService("RunService")

local U = require(script.Parent.Util)
local State = require(script.Parent.State)

local Notify = {}

local gui: ScreenGui
local toastHolder: Frame
local toasts: { Frame } = {}

local KIND_ICON = {
	info = "💬",
	good = "✅",
	bad = "❌",
	event = "⚡",
	evidence = "🔍",
	security = "🚨",
	social = "🤝",
}

local function removeToast(t: Frame)
	local i = table.find(toasts, t)
	if i then
		table.remove(toasts, i)
	end
	if not t.Parent then
		return
	end
	local inner = t:FindFirstChild("Inner") :: Frame?
	if inner then
		local tw = U.tween(inner, 0.25, { Position = UDim2.new(0, 0, -1.2, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tw.Completed:Connect(function()
			t:Destroy()
		end)
	else
		t:Destroy()
	end
end

-- toasts that arrive while the big SECRET card or the end-of-round REVEAL is open wait until it closes,
-- so they never cover its title (other windows like the shop keep instant toasts: "Not enough coins!" must show)
local pending: { { any } } = {}
local secretOpen = false
local HOLD = { Secret = true, SecretPop = true, Reveal = true } -- SecretPop = the auto pop-up at round start
local holding: { [string]: boolean } = {}
function Notify.toast(text: string, kind: string?, sfx: string?)
	if State.round and State.round.phase == "Reveal" and (kind == "event" or kind == "info") then
		return -- round is over: "storm passed"/"police left" notes would only cover the reveal cards
	end
	if secretOpen then
		table.insert(pending, { text, kind, sfx })
		while #pending > 3 do
			table.remove(pending, 1)
		end
		return
	end
	kind = kind or "info"
	local color = U.KIND_COLOR[kind :: string] or U.C.info
	while #toasts >= 3 do
		local oldest = table.remove(toasts, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	local holder = U.frame(toastHolder, {
		Name = "Toast",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 56),
		LayoutOrder = math.floor(os.clock() * 100) % 1e8,
		ClipsDescendants = false,
	})
	local inner = U.frame(holder, {
		Name = "Inner",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, -1),
		BackgroundColor3 = U.C.bg,
		BackgroundTransparency = 0.08,
	})
	U.corner(inner, 16)
	U.stroke(inner, color, 3)
	local stripe = U.frame(inner, { Size = UDim2.new(0, 10, 1, 0), BackgroundColor3 = color })
	U.corner(stripe, 16)
	local l = U.label(inner, (KIND_ICON[kind :: string] or "💬") .. "  " .. U.esc(text), 24, {
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.new(1, -30, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
	})
	U.new("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 12, Parent = l })
	U.textStroke(l, 1.5)
	table.insert(toasts, holder)
	U.tween(inner, 0.3, { Position = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Back)
	if sfx and sfx ~= "" then
		U.sfx(sfx)
	elseif kind == "evidence" then
		U.sfx("Evidence")
	elseif kind == "security" then
		U.sfx("Detected")
	elseif kind == "bad" then
		U.sfx("Fail", nil, 0.5)
	elseif kind == "good" then
		U.sfx("CoinGet", nil, 0.6)
	end
	task.delay(kind == "event" and 5 or 3.8, function()
		removeToast(holder)
	end)
end

-------------------------------------------------------------------------------- screen shake
local shakeUntil, shakeMag = 0, 0
function Notify.shake(mag: number, dur: number)
	shakeMag = math.max(mag, shakeUntil > os.clock() and shakeMag or 0)
	shakeUntil = os.clock() + dur
end
-- The offset is removed again before the camera scripts run next frame, so it never accumulates/drifts.
local shakeOffset: CFrame? = nil
RunService:BindToRenderStep("EHAS_ShakeUndo", Enum.RenderPriority.Camera.Value - 1, function()
	local cam = workspace.CurrentCamera
	if shakeOffset and cam then
		if cam.CameraType ~= Enum.CameraType.Scriptable then
			cam.CFrame = cam.CFrame * shakeOffset:Inverse()
		end
		shakeOffset = nil
	end
end)
RunService:BindToRenderStep("EHAS_Shake", Enum.RenderPriority.Camera.Value + 1, function()
	if os.clock() < shakeUntil then
		local cam = workspace.CurrentCamera
		if cam and cam.CameraType ~= Enum.CameraType.Scriptable then
			local m = math.min(shakeMag, shakeMag * ((shakeUntil - os.clock()) / 0.5))
			local off = CFrame.Angles(
				math.rad((math.random() - 0.5) * m),
				math.rad((math.random() - 0.5) * m),
				math.rad((math.random() - 0.5) * m * 0.5)
			)
			cam.CFrame = cam.CFrame * off
			shakeOffset = off
		end
	end
end)

-------------------------------------------------------------------------------- event banner
local bannerQueue: { any } = {}
local bannerBusy = false
local function showBanner(p: any)
	bannerBusy = true
	local banner = U.frame(gui, {
		Name = "EventBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -260),
		Size = UDim2.fromOffset(760, 150),
		BackgroundColor3 = U.C.event,
		ZIndex = 10,
	})
	U.corner(banner, 24)
	U.stroke(banner, U.C.white, 4)
	U.gradient(banner, Color3.fromRGB(255, 170, 60), Color3.fromRGB(220, 60, 60), 0)
	local icon = U.label(banner, tostring(p.icon or "⚡"), 86, {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.fromOffset(140, 150),
		TextWrapped = false,
		ZIndex = 11,
	})
	local title = U.label(banner, string.upper(tostring(p.title or "EVENT")), 46, {
		Position = UDim2.fromOffset(150, 14),
		Size = UDim2.new(1, -170, 0, 56),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
		ZIndex = 11,
	})
	U.new("UITextSizeConstraint", { MaxTextSize = 48, Parent = title })
	U.textStroke(title, 3)
	local desc = U.label(banner, U.esc(p.desc or ""), 24, {
		Position = UDim2.fromOffset(150, 72),
		Size = UDim2.new(1, -170, 0, 66),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = U.BOLD,
		ZIndex = 11,
	})
	U.textStroke(desc, 1.5)
	U.sfx("Event")
	-- below the timer
	U.tween(banner, 0.45, { Position = UDim2.new(0.5, 0, 0, 120) }, Enum.EasingStyle.Back)
	U.tween(toastHolder, 0.3, { Position = UDim2.new(0.5, 0, 0, 280) })
	Notify.shake(1.6, 0.5)
	task.spawn(function()
		for _ = 1, 3 do
			U.tween(icon, 0.25, { Rotation = 15 })
			task.wait(0.25)
			U.tween(icon, 0.25, { Rotation = -15 })
			task.wait(0.25)
		end
		icon.Rotation = 0
	end)
	task.wait(4)
	U.tween(banner, 0.35, { Position = UDim2.new(0.5, 0, 0, -260) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	U.tween(toastHolder, 0.3, { Position = UDim2.new(0.5, 0, 0, 160) })
	task.wait(0.4)
	banner:Destroy()
	bannerBusy = false
	if #bannerQueue > 0 then
		local nxt = table.remove(bannerQueue, 1)
		task.spawn(showBanner, nxt)
	end
end
function Notify.banner(p: any)
	if bannerBusy then
		table.insert(bannerQueue, p)
		return
	end
	task.spawn(showBanner, p)
end

-------------------------------------------------------------------------------- detention overlay
local detain: Frame
local detainTime: TextLabel
local detainReason: TextLabel
local function buildDetain()
	detain = U.frame(gui, {
		Name = "Detained",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(20, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 30,
	})
	local bars = U.frame(detain, { Name = "Bars", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 31 })
	for i = 0, 11 do
		local b = U.frame(bars, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale((i + 0.5) / 12, 0),
			Size = UDim2.new(0, 22, 1, 0),
			BackgroundColor3 = Color3.fromRGB(70, 74, 86),
			ZIndex = 31,
		})
		U.gradient(b, Color3.fromRGB(200, 205, 220), Color3.fromRGB(80, 84, 96), 0)
	end
	local box = U.frame(detain, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(560, 230),
		BackgroundColor3 = U.C.bg,
		ZIndex = 32,
	})
	U.corner(box, 22)
	U.stroke(box, U.C.bad, 5)
	local t = U.label(box, "🚔 DETAINED", 52, { Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 60), TextColor3 = U.C.bad, ZIndex = 33 })
	U.textStroke(t, 3)
	detainReason = U.label(box, "", 24, {
		Position = UDim2.fromOffset(20, 74),
		Size = UDim2.new(1, -40, 0, 60),
		Font = U.BOLD,
		ZIndex = 33,
	})
	detainTime = U.label(box, "0:20", 64, { Position = UDim2.fromOffset(0, 136), Size = UDim2.new(1, 0, 0, 72), ZIndex = 33 })
	U.textStroke(detainTime, 3)
end

local detainLoop: thread? = nil
local function onDetained(untilTime: number, reason: any)
	if untilTime <= U.now() then
		if detain.Visible then
			U.tween(detain, 0.3, { BackgroundTransparency = 1 })
			local bars = detain:FindFirstChild("Bars") :: Frame
			U.tween(bars, 0.35, { Position = UDim2.fromScale(0, -1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.4, function()
				detain.Visible = false
				bars.Position = UDim2.new()
			end)
			Notify.toast("You're free. Be more careful...", "good")
		end
		return
	end
	U.closeAllModals()
	detainReason.Text = U.esc(reason or "Security caught you!")
	detain.Visible = true
	detain.BackgroundTransparency = 1
	U.tween(detain, 0.3, { BackgroundTransparency = 0.45 })
	local bars = detain:FindFirstChild("Bars") :: Frame
	bars.Position = UDim2.fromScale(0, -1)
	U.tween(bars, 0.45, { Position = UDim2.new() }, Enum.EasingStyle.Bounce)
	U.sfx("Alarm", nil, 0.7)
	Notify.shake(2.5, 0.4)
	if detainLoop then
		pcall(task.cancel, detainLoop)
	end
	detainLoop = task.spawn(function()
		while State.detainedUntil > U.now() do
			detainTime.Text = U.fmtTime(State.detainedUntil - U.now())
			task.wait(0.2)
		end
		detainLoop = nil
		if detain.Visible then
			onDetained(0, nil)
		end
	end)
end

-------------------------------------------------------------------------------- photo
local function photo(p: any)
	local flash = U.frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 50 })
	U.sfx("Photo")
	U.tween(flash, 0.6, { BackgroundTransparency = 1 })
	task.delay(0.65, function()
		flash:Destroy()
	end)
	-- polaroid
	local pol = U.frame(gui, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 300, 0.42, 0),
		Size = UDim2.fromOffset(230, 270),
		BackgroundColor3 = Color3.fromRGB(250, 248, 240),
		Rotation = 6,
		ZIndex = 45,
	})
	U.corner(pol, 6)
	U.stroke(pol, Color3.fromRGB(60, 60, 60), 2)
	local pic = U.frame(pol, {
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.new(1, -28, 0, 190),
		BackgroundColor3 = Color3.fromRGB(40, 60, 90),
		ZIndex = 46,
	})
	U.gradient(pic, Color3.fromRGB(120, 190, 240), Color3.fromRGB(40, 70, 110), 90)
	local target = p.targetName and tostring(p.targetName) or nil
	U.label(pic, target and "👤" or "🌴", 90, { Size = UDim2.fromScale(1, 1), ZIndex = 47, TextWrapped = false })
	local cap = target and ("📸 " .. target) or "📸 Snap!"
	if p.caught then
		cap = "🚨 " .. tostring(p.caught)
	end
	U.label(pol, U.esc(cap), 22, {
		Position = UDim2.new(0, 8, 1, -60),
		Size = UDim2.new(1, -16, 0, 52),
		TextColor3 = Color3.fromRGB(40, 40, 50),
		TextScaled = true,
		ZIndex = 46,
	})
	U.tween(pol, 0.45, { Position = UDim2.new(1, -24, 0.42, 0), Rotation = -4 }, Enum.EasingStyle.Back)
	task.delay(3.2, function()
		U.tween(pol, 0.35, { Position = UDim2.new(1, 300, 0.42, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.4)
		pol:Destroy()
	end)
	if p.caught then
		Notify.toast("Photo evidence: " .. tostring(p.caught), "evidence")
	end
end
Notify.photo = photo

function Notify.init()
	gui = U.screen("EHAS_Notify", 30, 0.58)
	toastHolder = U.frame(gui, {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 128),
		Size = UDim2.fromOffset(560, 190),
	})
	U.list(toastHolder, Enum.FillDirection.Vertical, 6)
	buildDetain()

	local function layout()
		local vp = U.viewport()
		local k = math.max(U.scale, 0.01)
		local w = math.min(560, (vp.X * 0.6) / k)
		toastHolder.Size = UDim2.fromOffset(w, 190)
		-- below timer (78) + "round is ending" line (34) + event chips (36)
		toastHolder.Position = UDim2.new(0.5, 0, 0, 160)
	end
	U.scaleChanged:Connect(layout)
	layout()

	U.modalChanged:Connect(function(name, open)
		if not HOLD[name] then
			return
		end
		holding[name] = open or nil
		secretOpen = next(holding) ~= nil
		-- hide world "Pick up" prompts while a big card is open (they drew over its buttons)
		pcall(function()
			game:GetService("ProximityPromptService").Enabled = not secretOpen
		end)
		if secretOpen or #pending == 0 then
			return
		end
		local q = pending
		pending = {}
		for i, t in ipairs(q) do
			task.delay(0.25 + (i - 1) * 0.35, function()
				Notify.toast(t[1], t[2], t[3])
			end)
		end
	end)
	State.sig("Toast"):Connect(function(p)
		Notify.toast(tostring(p.text or ""), p.kind, p.sfx)
	end)
	State.sig("EventBanner"):Connect(function(p)
		Notify.banner(p)
	end)
	State.sig("Detained"):Connect(onDetained)
	State.sig("Photo"):Connect(photo)
	State.sig("FinalMinute"):Connect(function()
		-- the server already toasts "ONE MINUTE LEFT" to everyone; just shake here (no duplicate toast)
		Notify.shake(1, 0.4)
	end)
end

return Notify
