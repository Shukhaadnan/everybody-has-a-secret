-- Hud.luau: always-on HUD. Phase + countdown (top-center, red pulse in the final minute), active event chips,
-- coins/level/title panel (top-left, below Roblox's buttons), ONE ☰ MENU button (sheet: Journal/Accuse/Map/Shop/Social,
-- badges add up on MENU), a quick ⚖️ ACCUSE only while accusing is possible, the "🔒 SECRET" button and the
-- current-step line under it. Other modules register openers in Hud.open[name].
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local U = require(script.Parent.Util)
local State = require(script.Parent.State)

local Hud = {}
Hud.open = {} :: { [string]: () -> () }
Hud.buttons = {} :: { [string]: GuiButton }
Hud.layoutChanged = U.signal()
Hud.gui = nil :: ScreenGui?
Hud.stepLine = nil :: TextLabel?

local badges: { [string]: TextLabel } = {}
local counts: { [string]: number } = {}

local PHASE_TEXT = {
	Lobby = "🌴 NEXT ROUND",
	Intro = "🔒 READ YOUR SECRET",
	Play = "🕵️ ROUND",
	Reveal = "🎭 THE REVEAL",
	Rewards = "💰 REWARDS",
}

-- Hud.setBadge(name, n) is defined in Hud.init (it also sums the sheet badges onto ☰ MENU)
function Hud.setBadge(_name: string, _n: number) end
function Hud.refreshAccuse() end
function Hud.refreshStep() end
function Hud.toggleMenu() end

function Hud.flash(name: string)
	local b = Hud.buttons[name]
	-- tiles inside the closed ☰ MENU sheet: flash the MENU button instead
	if b and b.Parent and b.Parent.Name == "Sheet" then
		local sheetBack = b.Parent.Parent :: GuiObject
		if not sheetBack.Visible then
			b = Hud.buttons.Menu
		end
	end
	if not b then
		return
	end
	U.pulse(b, 0.25)
	local st = b:FindFirstChildOfClass("UIStroke")
	if st then
		st.Color = U.C.gold
		st.Thickness = 5
		st.Transparency = 0
		task.delay(0.9, function()
			U.tween(st, 0.4, { Thickness = 2, Transparency = 0.55 })
			st.Color = Color3.new(0, 0, 0)
		end)
	end
end

local function callOpen(name: string)
	local fn = Hud.open[name]
	if fn then
		fn()
	end
end

function Hud.init()
	local gui = U.screen("EHAS_HUD", 5)
	Hud.gui = gui

	---------------------------------------------------------------- timer (top-center)
	local timer = U.frame(gui, {
		Name = "Timer",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(380, 78),
		BackgroundColor3 = U.C.bg,
		BackgroundTransparency = 0.12,
	})
	U.corner(timer, 20)
	local timerStroke = U.stroke(timer, U.C.gold, 3)
	local timerGrad = U.gradient(timer, Color3.fromRGB(52, 60, 108), Color3.fromRGB(24, 28, 50), 90)
	local phaseL = U.label(timer, "🌴 NEXT ROUND", 22, {
		Name = "Phase",
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 26),
		TextColor3 = U.C.gold,
		Font = U.BOLD,
	})
	local timeL = U.label(timer, "0:00", 42, {
		Name = "Time",
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 46),
	})
	U.textStroke(timeL, 2)
	local endingL = U.label(timer, "⚠️ THE ROUND IS ENDING ⚠️", 22, {
		Name = "Ending",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 4),
		Size = UDim2.fromOffset(420, 30),
		TextColor3 = U.C.bad,
		Visible = false,
	})
	U.textStroke(endingL, 2)

	-- active event chips under the timer
	local chips = U.frame(timer, {
		Name = "Events",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 36),
		Size = UDim2.fromOffset(600, 34),
	})
	U.list(chips, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)

	local chipFrames: { [string]: TextLabel } = {}
	local function refreshChips()
		local alive = {}
		for _, e in ipairs(State.events) do
			local left = e.endsAt - U.now()
			if left > 0 then
				alive[e.id] = true
				local c = chipFrames[e.id]
				if not c then
					c = U.label(chips, "", 18, {
						Name = e.id,
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.fromOffset(0, 30),
						BackgroundTransparency = 0.15,
						BackgroundColor3 = U.C.event,
						Font = U.BOLD,
						TextWrapped = false,
					})
					U.corner(c, 15)
					U.pad(c, 10, 2)
					chipFrames[e.id] = c
					U.popIn(c)
				end
				c.Text = string.format("%s %s  %s", e.icon, string.upper(e.title), U.fmtTime(left))
			end
		end
		for id, c in pairs(chipFrames) do
			if not alive[id] then
				chipFrames[id] = nil
				c:Destroy()
			end
		end
	end

	---------------------------------------------------------------- coins/level (top-left)
	local stats = U.frame(gui, {
		Name = "Stats",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(300, 86),
		BackgroundColor3 = U.C.bg,
		BackgroundTransparency = 0.15,
	})
	U.corner(stats, 18)
	U.stroke(stats, U.C.gold, 3)
	local lvl = U.frame(stats, {
		Name = "Level",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(70, 70),
		BackgroundColor3 = U.C.purple,
	})
	U.round(lvl)
	U.stroke(lvl, U.C.white, 3)
	U.gradient(lvl, Color3.fromRGB(200, 140, 255), Color3.fromRGB(120, 60, 220), 90)
	U.label(lvl, "LV", 14, { Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 16), Font = U.BOLD })
	local lvlNum = U.label(lvl, "1", 32, { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 38) })
	U.textStroke(lvlNum, 2)
	local coinL = U.label(stats, "🪙 0", 32, {
		Position = UDim2.fromOffset(88, 6),
		Size = UDim2.new(1, -96, 0, 38),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = U.C.gold,
		TextWrapped = false,
	})
	U.textStroke(coinL, 2)
	local titleL = U.label(stats, "Rookie", 18, {
		Position = UDim2.fromOffset(88, 42),
		Size = UDim2.new(1, -96, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = U.C.muted,
		Font = U.BOLD,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local xpBack = U.frame(stats, {
		Position = UDim2.fromOffset(88, 66),
		Size = UDim2.new(1, -100, 0, 10),
		BackgroundColor3 = U.C.dark,
	})
	U.round(xpBack)
	local xpFill = U.frame(xpBack, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = U.C.purple })
	U.round(xpFill)

	local shownCoins = 0
	local coinTween: thread? = nil
	local function setCoins(n: number)
		n = math.floor(n)
		if n == shownCoins then
			coinL.Text = "🪙 " .. U.commas(n)
			return
		end
		if coinTween then
			pcall(task.cancel, coinTween)
		end
		local from = shownCoins
		shownCoins = n
		if n > from then
			U.pulse(coinL, 0.15)
		end
		coinTween = task.spawn(function()
			local t0 = os.clock()
			while true do
				local a = math.min(1, (os.clock() - t0) / 0.8)
				coinL.Text = "🪙 " .. U.commas(from + (n - from) * a)
				if a >= 1 then
					break
				end
				task.wait()
			end
		end)
	end

	local function applyProfile(p: any)
		if type(p) ~= "table" then
			return
		end
		if p.coins then
			setCoins(tonumber(p.coins) or 0)
		end
		lvlNum.Text = tostring(p.level or 1)
		titleL.Text = tostring(p.title or "Rookie") .. (p.vip and "  ⭐VIP" or "")
		local xp, nxt = tonumber(p.xp) or 0, tonumber(p.xpNext) or 0
		local a = nxt > 0 and math.clamp(xp / nxt, 0, 1) or 0
		U.tween(xpFill, 0.6, { Size = UDim2.fromScale(a, 1) })
	end
	State.sig("Profile"):Connect(applyProfile)
	applyProfile(State.profile)

	-- leaderstats fallback for coins (in case Profile arrives late)
	task.spawn(function()
		local ls = U.player:WaitForChild("leaderstats", 30)
		local c = ls and ls:WaitForChild("Coins", 10)
		if c and c:IsA("ValueBase") then
			local function upd()
				setCoins(tonumber((c :: any).Value) or 0)
			end
			upd()
			c.Changed:Connect(upd)
		end
	end)

	---------------------------------------------------------------- ☰ MENU + quick ⚖️ (top-left, under the stats)
	-- One MENU button opens a small sheet (Journal / Accuse / Map / Shop / Social); badges add up on MENU.
	-- The quick ⚖️ ACCUSE button only shows while accusing is possible (Play + an unsolved incident).
	local row = U.frame(gui, {
		Name = "Menu",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 104),
		Size = UDim2.fromOffset(200, 84),
	})
	local rowLayout = U.list(row, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left)
	local function squareButton(parent: Instance, name: string, icon: string, cap: string, color: Color3, fn: () -> ()): TextButton
		local b = U.button(parent, "", color, fn, { Name = name, Size = UDim2.fromOffset(84, 84) })
		U.gradient(b, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190), 90)
		U.label(b, icon, 40, { Name = "Icon", Size = UDim2.new(1, 0, 0.7, 0), Position = UDim2.fromScale(0, 0.03), TextScaled = true, TextWrapped = false })
		local capL = U.label(b, cap, 15, {
			Name = "Cap",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 0.97),
			Size = UDim2.new(1, 0, 0.28, 0),
			Font = U.BOLD,
			TextScaled = true,
		})
		U.textStroke(capL, 1)
		local badge = U.label(b, "0", 18, {
			Name = "Badge",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(32, 32),
			BackgroundTransparency = 0,
			BackgroundColor3 = U.C.bad,
			Visible = false,
			ZIndex = 5,
			Font = U.BOLD,
		})
		U.round(badge)
		U.stroke(badge, U.C.white, 2)
		return b
	end

	-- the sheet
	local sheetBack = U.new("TextButton", {
		Name = "MenuSheet",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.7,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 30,
		Parent = gui,
	})
	local sheet = U.frame(sheetBack, {
		Name = "Sheet",
		BackgroundColor3 = U.C.bg,
		Size = UDim2.fromOffset(300, 200),
		ZIndex = 31,
		Active = true,
	})
	U.corner(sheet, 18)
	U.stroke(sheet, U.C.gold, 3)
	U.pad(sheet, 10, 10)
	local grid = U.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(90, 90),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = sheet,
	})
	local sheetOpen = false
	local function closeSheet()
		if not sheetOpen then
			return
		end
		sheetOpen = false
		U.closedModal("Menu")
		sheetBack.Visible = false
	end
	sheetBack.Activated:Connect(closeSheet)

	local defs = {
		{ "Journal", "🔍", "Clues", Color3.fromRGB(40, 150, 200) },
		{ "Accuse", "⚖️", "Accuse", Color3.fromRGB(220, 70, 90) },
		{ "Map", "🗺️", "Map", Color3.fromRGB(60, 170, 110) },
		{ "Shop", "🛍️", "Shop", Color3.fromRGB(230, 150, 40) },
		{ "Social", "🤝", "Social", Color3.fromRGB(200, 90, 200) },
	}
	local inSheet: { [string]: boolean } = {}
	for i, d in ipairs(defs) do
		local b = squareButton(sheet, d[1], d[2], d[3], d[4], function()
			closeSheet()
			callOpen(d[1])
		end)
		b.LayoutOrder = i
		b.ZIndex = 32
		for _, c in ipairs(b:GetDescendants()) do
			if c:IsA("GuiObject") then
				c.ZIndex = c.Name == "Badge" and 34 or 33
			end
		end
		badges[d[1]] = b:FindFirstChild("Badge") :: TextLabel
		Hud.buttons[d[1]] = b
		inSheet[d[1]] = true
	end

	function Hud.toggleMenu()
		if sheetOpen then
			closeSheet()
			return
		end
		U.openModal("Menu", function()
			sheetOpen = false
			sheetBack.Visible = false
		end)
		sheetOpen = true
		sheetBack.Visible = true
		U.popIn(sheet, 0.7)
	end
	local menuBtn = squareButton(row, "MenuButton", "☰", "MENU", Color3.fromRGB(70, 80, 150), function()
		Hud.toggleMenu()
	end)
	menuBtn.LayoutOrder = 1
	Hud.buttons.Menu = menuBtn
	do -- the ☰ glyph doesn't render in Roblox fonts: draw three bars instead
		local icon = menuBtn:FindFirstChild("Icon") :: TextLabel
		icon.Text = ""
		local bars = U.frame(icon, {
			Name = "Bars",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.fromScale(0.62, 0.62),
			BackgroundTransparency = 1,
		})
		local l = U.list(bars, Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Center)
		l.Padding = UDim.new(0.16, 0)
		l.VerticalAlignment = Enum.VerticalAlignment.Center
		for i = 1, 3 do
			local bar = U.frame(bars, { Name = "Bar" .. i, LayoutOrder = i, Size = UDim2.fromScale(1, 0.2), BackgroundColor3 = U.C.white })
			U.round(bar)
		end
	end
	local menuBadge = menuBtn:FindFirstChild("Badge") :: TextLabel

	local accBtn = squareButton(row, "AccuseButton", "⚖️", "ACCUSE", Color3.fromRGB(220, 70, 90), function()
		callOpen("Accuse")
	end)
	accBtn.LayoutOrder = 2
	accBtn.Visible = false
	Hud.buttons.AccuseQuick = accBtn
	local accBadge = accBtn:FindFirstChild("Badge") :: TextLabel

	-- badge counts: each sheet tile shows its own; MENU shows the sum of the tiles (Accuse has its own button)
	function Hud.setBadge(name: string, n: number)
		counts[name] = n
		local b = badges[name]
		if b then
			b.Visible = n > 0
			b.Text = n > 9 and "9+" or tostring(n)
			if n > 0 and not inSheet[name] then
				U.pulse(b, 0.5)
			end
		end
		if name == "Accuse" then
			accBadge.Visible = n > 0
			accBadge.Text = n > 9 and "9+" or tostring(n)
		end
		local total = 0
		for k, v in pairs(counts) do
			if inSheet[k] and k ~= "Accuse" then
				total += v
			end
		end
		local was = menuBadge.Visible
		menuBadge.Visible = total > 0
		menuBadge.Text = total > 9 and "9+" or tostring(total)
		if total > 0 and not was then
			U.pulse(menuBadge, 0.5)
		end
		Hud.refreshAccuse()
	end

	---------------------------------------------------------------- secret button + current-step line
	local secretBtn = U.button(gui, "🔒 SECRET", Color3.fromRGB(150, 60, 230), function()
		callOpen("Secret")
	end, { Name = "SecretButton", Size = UDim2.fromOffset(190, 70), TextSize = 30, Visible = false })
	U.gradient(secretBtn, Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 170, 200), 90)
	local secretStroke = secretBtn:FindFirstChildOfClass("UIStroke") :: UIStroke
	secretStroke.Color = U.C.gold
	secretStroke.Thickness = 3
	secretStroke.Transparency = 0
	local secretTier = U.frame(secretBtn, {
		Name = "Tier",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(0.8, 0, 0, 6),
		BackgroundColor3 = U.C.gold,
	})
	U.round(secretTier)
	U.new("UITextSizeConstraint", { MaxTextSize = 34, Parent = secretBtn })
	Hud.buttons.Secret = secretBtn
	badges.Secret = U.label(secretBtn, "!", 20, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(32, 32),
		BackgroundTransparency = 0,
		BackgroundColor3 = U.C.bad,
		Visible = false,
		ZIndex = 5,
	})
	U.round(badges.Secret)

	-- "➡️ Hide it in the Spa (120m)": always-visible current step of the active objective
	local stepLine = U.label(gui, "", 20, {
		Name = "StepLine",
		BackgroundTransparency = 0.25,
		BackgroundColor3 = U.C.bg,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Font = U.BOLD,
		Visible = false,
	})
	U.corner(stepLine, 10)
	local stepStroke = U.stroke(stepLine, U.C.gold, 2, 0.2)
	local stepPad = U.new("UIPadding", { Parent = stepLine })
	stepLine.AutomaticSize = Enum.AutomaticSize.X -- as wide as the text, capped (then "…") by stepMax
	local stepMax = U.new("UISizeConstraint", { Parent = stepLine })
	Hud.stepLine = stepLine

	function Hud.showSecretButton(show: boolean)
		if show and not secretBtn.Visible then
			U.popIn(secretBtn, 0.4)
		elseif not show then
			secretBtn.Visible = false
		end
		Hud.refreshStep()
	end

	-- text for the step line (also used by SecretCard's pop-up)
	function Hud.stepText(): (string?, Color3)
		local s = State.secret
		if not (s and type(s.main) == "table") then
			return nil, U.C.gold
		end
		local obj = State.activeObjective()
		if not obj then
			local hasSide = type(s.side) == "table"
			local allDone = s.main.done and (not hasSide or s.side.done)
			return allDone and "✅ Secret done! Act normal 😎" or "🤫 Act normal until the round ends", U.C.good
		end
		local steps = type(obj.steps) == "table" and obj.steps or {}
		local i = tonumber(obj.step) or 1
		local t: string
		if #steps > 0 and i > #steps then
			t = "⏳ " .. tostring(steps[#steps]) -- only "until the end" conditions left
		else
			t = "➡️ " .. tostring(steps[i] or obj.short or obj.text or "")
		end
		if type(obj.progress) == "table" and (tonumber(obj.progress.max) or 0) > 1 then
			t ..= string.format("  %d/%d", tonumber(obj.progress.cur) or 0, tonumber(obj.progress.max) or 0)
		end
		local z = obj.hintZone and U.zone(obj.hintZone)
		local hrp = U.hrp()
		if z and typeof(z.center) == "Vector3" then
			if State.zone == obj.hintZone then
				t ..= "  📍here"
			elseif hrp then
				local d = Vector3.new(z.center.X - hrp.Position.X, 0, z.center.Z - hrp.Position.Z).Magnitude
				t ..= string.format("  (%dm)", math.floor(d))
			end
		end
		return t, U.tierColor(obj.tier)
	end

	function Hud.refreshStep()
		local ph = State.round.phase
		local show = secretBtn.Visible and (ph == "Intro" or ph == "Play") and State.secret ~= nil
		local t, col = nil, U.C.gold
		if show then
			t, col = Hud.stepText()
		end
		stepLine.Visible = show and t ~= nil
		if stepLine.Visible then
			stepLine.Text = U.esc(t)
			stepStroke.Color = col
		end
	end

	local function updateSecretButton()
		local s = State.secret
		local obj = State.activeObjective()
		if s and type(s.main) == "table" then
			secretTier.BackgroundColor3 = U.tierColor((obj or s.main).tier)
			local hasSide = type(s.side) == "table"
			local done = (s.main.done and 1 or 0) + ((hasSide and s.side.done) and 1 or 0)
			secretBtn.Text = done > 0 and string.format("🔒 SECRET %d/%d", done, hasSide and 2 or 1) or "🔒 SECRET"
		end
		Hud.refreshStep()
	end
	State.sig("Secret"):Connect(updateSecretButton)
	State.sig("Zone"):Connect(Hud.refreshStep)
	task.spawn(function()
		while gui.Parent do
			if stepLine.Visible or secretBtn.Visible then
				Hud.refreshStep()
			end
			task.wait(0.5)
		end
	end)

	-- quick ⚖️ only while an accusation can actually be made (Play + an unsolved incident)
	function Hud.refreshAccuse()
		local open = 0
		for _, inc in ipairs(State.incidents or {}) do
			if not inc.solved then
				open += 1
			end
		end
		local show = State.round.phase == "Play" and open > 0
		if show and not accBtn.Visible then
			U.popIn(accBtn, 0.5)
		elseif not show then
			accBtn.Visible = false
		end
	end
	State.sig("Incident"):Connect(Hud.refreshAccuse)

	---------------------------------------------------------------- layout (mobile aware)
	local function layout()
		local k = math.max(U.scale, 0.01)
		local inset = GuiService:GetGuiInset()
		local vp = U.viewport()
		local touch = U.isTouch()
		local topY = math.max(10, 64 - inset.Y) -- real px below the gui inset; keeps clear of Roblox buttons
		stats.Position = UDim2.fromOffset(10 / k, topY / k)
		local statsBottom = topY + 86 * k
		-- MENU / ACCUSE: ~64 real px on phones (house rule 56-72), up to 84 on big screens
		local btnReal = touch and 64 or math.clamp(84 * k, 58, 84)
		local bs = btnReal / k
		menuBtn.Size = UDim2.fromOffset(bs, bs)
		accBtn.Size = UDim2.fromOffset(bs, bs)
		rowLayout.Padding = UDim.new(0, 8 / k)
		row.Position = UDim2.fromOffset(10 / k, (statsBottom + 8) / k)
		row.Size = UDim2.fromOffset((2 * (btnReal + 8)) / k, bs)
		local rowBottom = statsBottom + 8 + btnReal
		-- menu sheet: tiles the same size, 3 per row, opens right under the MENU button
		local tile = touch and 72 or math.clamp(96 * k, 64, 96)
		local gap = 8
		grid.CellSize = UDim2.fromOffset(tile / k, tile / k)
		grid.CellPadding = UDim2.fromOffset(gap / k, gap / k)
		local cols = 3
		local rows = math.ceil(#defs / cols)
		sheet.Size = UDim2.fromOffset((cols * tile + (cols - 1) * gap) / k + 20, (rows * tile + (rows - 1) * gap) / k + 20)
		sheet.Position = UDim2.fromOffset(10 / k, (rowBottom + 6) / k)
		-- secret button + step line (one block)
		local sw, sh = touch and 150 or math.clamp(190 * k, 150, 190), touch and 56 or math.clamp(70 * k, 56, 70)
		secretBtn.Size = UDim2.fromOffset(sw / k, sh / k)
		secretBtn.TextScaled = true
		local lineH = 28
		local lineW = math.clamp(vp.X * 0.55, 260, 520)
		stepLine.Size = UDim2.fromOffset(0, lineH / k)
		stepMax.MaxSize = Vector2.new(lineW / k, lineH / k)
		stepLine.TextSize = 18 / k -- 18 real px: readable on a phone, one line
		stepPad.PaddingLeft = UDim.new(0, 8 / k)
		stepPad.PaddingRight = UDim.new(0, 8 / k)
		local blockH = sh + 6 + lineH
		local blockTop: number
		if touch then
			-- bottom-left, above the move thumbstick; never overlapping the menu row
			local small = math.min(vp.X, vp.Y) <= 500
			local thumbTop = small and 130 or 220 -- real px from the bottom
			blockTop = vp.Y - inset.Y - thumbTop - blockH
		else
			blockTop = vp.Y - inset.Y - 20 - blockH
		end
		if blockTop < rowBottom + 8 then
			blockTop = rowBottom + 8
		end
		secretBtn.AnchorPoint = Vector2.new(0, 0)
		secretBtn.Position = UDim2.fromOffset(10 / k, blockTop / k)
		stepLine.Position = UDim2.fromOffset(10 / k, (blockTop + sh + 6) / k)
		-- timer is narrower on small phones so it never touches the left panel
		local tw = math.min(380 * k, vp.X - 2 * (10 + 300 * k) - 20)
		tw = math.max(tw, 170)
		timer.Size = UDim2.fromOffset(tw / k, 78)
		Hud.layoutChanged:Fire()
	end
	Hud.layout = layout
	U.scaleChanged:Connect(layout)
	game:GetService("UserInputService").LastInputTypeChanged:Connect(function()
		task.defer(layout)
	end)
	layout()
	task.defer(layout)

	---------------------------------------------------------------- timer loop
	local lastCountdown = -1
	local endingShown = false
	local pulseT = 0
	RunService.Heartbeat:Connect(function(dt)
		local r = State.round
		local left = State.remaining()
		local phase = r.phase
		local label = PHASE_TEXT[phase] or phase
		if phase == "Play" and (r.round or 0) > 0 then
			label = string.format("🕵️ ROUND %d", r.round)
		end
		phaseL.Text = label
		timeL.Text = (r.endsAt or 0) > 0 and U.fmtTime(left) or "--:--"
		local ending = phase == "Play" and (r.warning or (left <= 60 and left > 0))
		if ending then
			pulseT += dt * 4
			local a = (math.sin(pulseT) + 1) / 2
			timerStroke.Color = U.C.bad:Lerp(U.C.white, a * 0.4)
			timerStroke.Thickness = 3 + a * 3
			timeL.TextColor3 = U.C.bad:Lerp(U.C.white, a * 0.5)
			timerGrad.Color = ColorSequence.new(Color3.fromRGB(140, 30, 40), Color3.fromRGB(60, 10, 20))
			if not endingShown then
				endingShown = true
				endingL.Visible = true
				U.popIn(endingL, 0.3)
				U.sfx("Countdown")
				State.emit("FinalMinute")
			end
			local sec = math.ceil(left)
			if sec <= 10 and sec ~= lastCountdown and sec > 0 then
				lastCountdown = sec
				U.sfx("Countdown", nil, 0.7)
				U.pulse(timeL, 0.3)
			end
		else
			if endingShown then
				endingShown = false
				endingL.Visible = false
			end
			timerStroke.Color = U.C.gold
			timerStroke.Thickness = 3
			timeL.TextColor3 = U.C.white
			timerGrad.Color = ColorSequence.new(Color3.fromRGB(52, 60, 108), Color3.fromRGB(24, 28, 50))
		end
		chips.Position = UDim2.new(0.5, 0, 1, endingL.Visible and 36 or 6)
	end)
	task.spawn(function()
		while gui.Parent do
			refreshChips()
			task.wait(0.5)
		end
	end)

	State.sig("Phase"):Connect(function(phase)
		U.pulse(timer, 0.12)
		Hud.showSecretButton((phase == "Intro" or phase == "Play") and State.secret ~= nil)
		updateSecretButton()
		Hud.refreshAccuse()
		if phase == "Reveal" then
			closeSheet()
		end
	end)
	State.sig("YourSecret"):Connect(function()
		local ph = State.round.phase
		if ph ~= "Reveal" and ph ~= "Rewards" then
			Hud.showSecretButton(true)
		end
	end)
end

-- Bottom of the HUD's top-left block (real px), for modules that stack under it.
function Hud.leftBottom(): number
	local g = Hud.gui
	if not g then
		return 200
	end
	local sb = g:FindFirstChild("SecretButton") :: GuiObject?
	local row = g:FindFirstChild("Menu") :: GuiObject?
	local y = 0
	if row then
		y = row.AbsolutePosition.Y + row.AbsoluteSize.Y
	end
	if sb and sb.Visible and U.isTouch() then
		y = math.max(y, sb.AbsolutePosition.Y + sb.AbsoluteSize.Y)
	end
	local sl = g:FindFirstChild("StepLine") :: GuiObject?
	if sl and sl.Visible and U.isTouch() then
		y = math.max(y, sl.AbsolutePosition.Y + sl.AbsoluteSize.Y)
	end
	return y
end

local _ = Players
return Hud
