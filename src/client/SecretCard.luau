-- SecretCard.luau: the "🔒 YOUR SECRET" pop-up + card.
--  * Each round (YourSecret) a big pop-up shows itself for POP_TIME s with NO tap needed: a <1 s lock flourish,
--    role, ONE short goal line, where to go, a countdown bar; then it flies into the HUD's 🔒 SECRET button.
--    Tapping it closes it early. It holds toasts + world prompts while open (Notify HOLD "SecretPop").
--  * The full card (MAIN + SIDE, steps, progress, reward, Reroll) opens from the 🔒 SECRET button.
-- SecretProgress: live ticks with a check animation + sfx (card or mini popup when collapsed).
local U = require(script.Parent.Util)
local State = require(script.Parent.State)
local Hud = require(script.Parent.Hud)
local ShopData = require(script.Parent.ShopData)

local SecretCard = {}
SecretCard.closed = U.signal()

local gui: ScreenGui
local back: TextButton
local card: Frame
local content: ScrollingFrame
local lockL: TextLabel
local roleL: TextLabel
local rewardL: TextLabel
local okBtn: TextButton
local isOpen = false
local slotFrames: { [string]: any } = {}

local function tierBadge(parent: Instance, tier: string?): TextLabel
	local t = tostring(tier or "Easy")
	local b = U.label(parent, string.upper(t), 18, {
		Name = "Tier",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		BackgroundTransparency = 0,
		BackgroundColor3 = U.tierColor(t),
		TextColor3 = U.C.dark,
		Font = U.BOLD,
		TextWrapped = false,
	})
	U.corner(b, 14)
	U.pad(b, 12, 2)
	return b
end

-- Builds or rebuilds one objective block inside the card.
local function buildSlot(slot: string, obj: any, order: number)
	local old = slotFrames[slot]
	if old then
		old.frame:Destroy()
	end
	if type(obj) ~= "table" then
		slotFrames[slot] = nil
		return
	end
	local color = U.tierColor(obj.tier)
	local f = U.frame(content, {
		Name = slot,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = U.C.panel,
	})
	U.corner(f, 16)
	local st = U.stroke(f, color, 3)
	U.pad(f, 16, 12)
	U.list(f, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Left)

	local head = U.frame(f, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1 })
	U.list(head, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	U.label(head, slot == "main" and "MAIN OBJECTIVE" or "SIDE OBJECTIVE", 22, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		TextColor3 = U.C.gold,
		Font = U.BOLD,
		TextWrapped = false,
	})
	tierBadge(head, obj.tier)
	local status = U.label(head, "", 22, {
		Name = "Status",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		TextWrapped = false,
	})
	if obj.done then
		status.Text = "✅ DONE"
		status.TextColor3 = U.C.good
	elseif obj.failed then
		status.Text = "❌ FAILED"
		status.TextColor3 = U.C.bad
	end

	local headline = U.label(f, U.esc(obj.short or obj.text), 30, {
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local txt = U.label(f, U.esc(obj.text), 20, {
		LayoutOrder = 3,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = U.C.muted,
		Font = U.BOLD,
		Visible = obj.short ~= nil and obj.short ~= obj.text,
	})
	if obj.done or obj.failed then
		txt.TextTransparency = 0.35
		headline.TextTransparency = 0.35
	end

	local stepRows = {}
	if type(obj.steps) == "table" and #obj.steps > 0 then
		local cur = tonumber(obj.step) or 1
		for i, s in ipairs(obj.steps) do
			local isDone = obj.done or i < cur
			local isCur = not obj.done and i == cur
			local r = U.frame(f, {
				LayoutOrder = 10 + i,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
			})
			local box = U.label(r, isDone and "✔" or "", 22, {
				Name = "Box",
				Size = UDim2.fromOffset(30, 30),
				BackgroundTransparency = 0,
				BackgroundColor3 = isDone and U.C.good or U.C.dark,
				Font = U.BOLD,
			})
			U.corner(box, 8)
			U.stroke(box, isCur and U.C.gold or U.C.line, 2)
			local sl = U.label(r, U.esc(s), 22, {
				Name = "Text",
				Position = UDim2.fromOffset(42, 0),
				Size = UDim2.new(1, -42, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = U.BOLD,
				TextColor3 = isDone and U.C.muted or (isCur and U.C.white or U.C.muted),
				TextTransparency = isDone and 0.3 or 0,
			})
			if isCur then
				sl.Text = "▶ " .. sl.Text
			end
			stepRows[i] = { box = box, text = sl }
		end
	end

	local bar = nil
	if type(obj.progress) == "table" and (tonumber(obj.progress.max) or 0) > 0 then
		local cur, max = tonumber(obj.progress.cur) or 0, tonumber(obj.progress.max) or 1
		local holder = U.frame(f, { LayoutOrder = 50, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30) })
		local bg = U.frame(holder, { Size = UDim2.new(1, -90, 0, 18), Position = UDim2.fromOffset(0, 6), BackgroundColor3 = U.C.dark })
		U.round(bg)
		bar = U.frame(bg, { Size = UDim2.fromScale(math.clamp(cur / max, 0, 1), 1), BackgroundColor3 = color })
		U.round(bar)
		U.label(holder, string.format("%d/%d", cur, max), 24, {
			Position = UDim2.new(1, -80, 0, 0),
			Size = UDim2.fromOffset(80, 30),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
	end

	if obj.hintZone and not obj.done and not obj.failed then
		U.label(f, "📍 " .. U.zoneName(obj.hintZone) .. "  (follow the arrow)", 20, {
			LayoutOrder = 60,
			Size = UDim2.new(1, 0, 0, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = U.C.evidence,
			Font = U.BOLD,
		})
	end

	-- reroll: Robux product when one is configured, otherwise the server's coin reroll (Config.RerollCoinCost).
	-- Window matches the server (Secrets.luau Reroll action): Intro, or the first 90 s of Play.
	local s = State.secret
	local ph = State.round.phase
	local cfg = U.mod("Config") or {}
	local sincePlay = (tonumber(cfg.PlayTime) or 360) - State.remaining() -- seconds since Play began
	local inWindow = ph == "Intro" or (ph == "Play" and sincePlay < 90)
	if s and (tonumber(s.rerollsLeft) or 0) > 0 and not obj.done and not obj.failed and not obj.hidden and inWindow and not s.tutorial then
		local p = ShopData.rerollProduct()
		local price = p and (tostring(p.robux) .. " R$") or ("🪙" .. tostring(cfg.RerollCoinCost or 150))
		U.button(f, string.format("🎲 REROLL (%d left) · %s", s.rerollsLeft, price), Color3.fromRGB(70, 90, 160), function()
			U.fire("Reroll", { slot = slot })
		end, { LayoutOrder = 70, Size = UDim2.new(1, 0, 0, 52), TextSize = 22 })
	end

	slotFrames[slot] = { frame = f, stroke = st, steps = stepRows, bar = bar, status = status }
end

local function refresh()
	local s = State.secret
	if not s then
		return
	end
	roleL.Text = string.upper(tostring(s.role or "THE GUEST"))
	roleL.TextColor3 = U.tierColor(type(s.main) == "table" and s.main.tier or "Easy")
	rewardL.Text = string.format("💰 REWARD  <font color=\"#ffc83d\">%s Coins</font>", U.commas(tonumber(s.reward) or 0))
	buildSlot("main", s.main, 3)
	buildSlot("side", s.side, 4)
	if s.side == nil and s.beginner and not slotFrames.side then
		local f = U.label(content, "⭐ Beginner round: you only have ONE secret. Finish it for a 🔥 BONUS secret! Side secrets unlock after 3 rounds.", 20, {
			Name = "side",
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextColor3 = U.C.muted,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		slotFrames.side = { frame = f }
	end
end

function SecretCard.close()
	if not isOpen then
		return
	end
	isOpen = false
	U.closedModal("Secret")
	-- fly the card toward the 🔒 SECRET button
	local btn = Hud.buttons.Secret
	local sc = card:FindFirstChild("Pop") :: UIScale?
	U.tween(back, 0.25, { BackgroundTransparency = 1 })
	if btn and btn.Visible and sc then
		local k = math.max(U.scale, 0.01)
		local tgt = (btn.AbsolutePosition + btn.AbsoluteSize / 2) / k
		local tw = U.tween(card, 0.3, { Position = UDim2.fromOffset(tgt.X, tgt.Y) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		U.tween(sc, 0.3, { Scale = 0.05 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tw.Completed:Connect(function()
			if not isOpen then
				back.Visible = false
				card.Position = UDim2.fromScale(0.5, 0.5)
				sc.Scale = 1
				U.pulse(btn, 0.3)
			end
		end)
	else
		U.popOut(card, function()
			back.Visible = false
		end)
	end
	Hud.setBadge("Secret", 0)
	SecretCard.closed:Fire()
	State.emit("SecretClosed")
end

function SecretCard.open()
	if not State.secret then
		return
	end
	U.openModal("Secret", function()
		if isOpen then
			isOpen = false
			back.Visible = false
		end
	end)
	isOpen = true
	refresh()
	card.Position = UDim2.fromScale(0.5, 0.5)
	back.Visible = true
	content.CanvasPosition = Vector2.zero
	local sc = card:FindFirstChild("Pop") :: UIScale?
	if not sc then
		sc = U.new("UIScale", { Name = "Pop", Parent = card })
	end
	U.tween(back, 0.2, { BackgroundTransparency = 0.45 })
	card.Rotation = 0
	card.Visible = true
	U.popIn(card, 0.7)
	okBtn.Text = "CLOSE"
	lockL.Text = "🔓"
	Hud.setBadge("Secret", 0)
end

function SecretCard.toggle()
	if isOpen then
		SecretCard.close()
	else
		SecretCard.open()
	end
end

-- Little popup next to the 🔒 SECRET button when progress happens while the card is collapsed.
local function miniPopup(text: string, color: Color3)
	local btn = Hud.buttons.Secret
	local k = math.max(U.scale, 0.01)
	local pos = UDim2.fromOffset(20, 300)
	if btn and btn.Visible then
		local ap = btn.AbsolutePosition / k
		pos = UDim2.fromOffset(ap.X + btn.AbsoluteSize.X / k + 12, ap.Y)
	end
	local p = U.label(gui, text, 24, {
		Name = "Mini",
		Position = pos,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 0.05,
		BackgroundColor3 = U.C.bg,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
	})
	U.new("UISizeConstraint", { MaxSize = Vector2.new(520, 200), Parent = p })
	p.TextWrapped = true
	U.corner(p, 12)
	U.stroke(p, color, 3)
	U.pad(p, 14, 8)
	U.popIn(p, 0.3)
	task.delay(3.2, function()
		U.tween(p, 0.3, { TextTransparency = 1, BackgroundTransparency = 1 })
		local st = p:FindFirstChildOfClass("UIStroke")
		if st then
			U.tween(st, 0.3, { Transparency = 1 })
		end
		task.wait(0.35)
		p:Destroy()
	end)
end

local function onProgress(slot: string, obj: any, old: any)
	local finished = obj.done and not (old and old.done)
	local failed = obj.failed and not (old and old.failed)
	local stepUp = old and (tonumber(obj.step) or 0) > (tonumber(old.step) or 0)
	local progUp = old
		and type(obj.progress) == "table"
		and type(old.progress) == "table"
		and (tonumber(obj.progress.cur) or 0) > (tonumber(old.progress.cur) or 0)
	if finished then
		U.sfx("Complete")
	elseif failed then
		U.sfx("Fail")
	elseif stepUp or progUp then
		U.sfx("Progress")
	end
	if isOpen then
		refresh()
		local sf = slotFrames[slot]
		if sf then
			-- tick animation on the step that just completed
			if stepUp and old then
				local idx = tonumber(old.step) or 1
				local row = sf.steps[idx]
				if row then
					local s = U.new("UIScale", { Scale = 2.2, Parent = row.box })
					U.tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
				end
			end
			if finished then
				local s = U.new("UIScale", { Scale = 2, Parent = sf.status })
				U.tween(s, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
			end
			sf.stroke.Thickness = 7
			U.tween(sf.stroke, 0.6, { Thickness = 3 })
		end
	else
		local label = slot == "main" and "MAIN" or "SIDE"
		if finished then
			miniPopup("✅ " .. label .. " COMPLETE!  " .. U.esc(obj.short or obj.text), U.C.good)
		elseif failed then
			miniPopup("❌ " .. label .. " FAILED", U.C.bad)
		elseif stepUp and type(obj.steps) == "table" then
			local done = obj.steps[(tonumber(old.step) or 1)]
			local nxt = obj.steps[tonumber(obj.step) or 1]
			miniPopup("✔ " .. U.esc(done or "Step done") .. (nxt and ("\n▶ " .. U.esc(nxt)) or ""), U.tierColor(obj.tier))
		elseif progUp then
			miniPopup(string.format("▲ %s  %d/%d", label, obj.progress.cur, obj.progress.max), U.tierColor(obj.tier))
		end
		Hud.setBadge("Secret", 1)
		Hud.flash("Secret")
	end
end


-------------------------------------------------------------------------------- auto pop-up
local POP_TIME = 6 -- seconds the pop-up stays before it flies into the 🔒 SECRET button
SecretCard.POP_TIME = POP_TIME
local pop: { [string]: any } = {}
local popOpen = false
local popGen = 0

local function popLayout()
	if not pop.holder then
		return
	end
	local k = math.max(U.scale, 0.01)
	local vp = U.viewport()
	-- design units (760 wide) -> real px: phones ~0.6 (456 px wide, 24 px headline), 1080p screens 1.0
	local s = math.clamp(math.min(vp.X, vp.Y) / 1080 * 1.4, 0.6, 1)
	s = math.min(s, (vp.X * 0.9) / 760)
	pop.fit.Scale = s / k
end

local function popText()
	local s = State.secret
	if type(s) ~= "table" or type(s.main) ~= "table" then
		return nil
	end
	local obj = State.activeObjective() or s.main
	local where: string
	if obj.hintZone then
		where = "📍 Go to: " .. U.zoneName(obj.hintZone)
	else
		local steps = type(obj.steps) == "table" and obj.steps or {}
		where = "➡️ " .. tostring(steps[tonumber(obj.step) or 1] or steps[1] or "Follow the steps in 🔒 SECRET")
	end
	local extra = string.format("%s  ·  💰 %s coins", string.upper(tostring(obj.tier or "Easy")), U.commas(tonumber(s.reward) or 0))
	if s.tutorial then
		extra = "🎓 Practice secret · follow the arrow!"
	elseif s.beginner then
		extra ..= "  ·  ⭐ just ONE secret"
	elseif type(s.side) == "table" then
		extra ..= "  ·  + a side secret"
	end
	return {
		role = string.upper(tostring(s.role or "THE GUEST")),
		short = tostring(obj.short or obj.text or ""),
		where = where,
		extra = extra,
		color = U.tierColor(obj.tier),
	}
end

-- close the pop-up: fly into the 🔒 SECRET button (or just shrink away)
function SecretCard.closePop(instant: boolean?)
	if not popOpen then
		return
	end
	popOpen = false
	popGen += 1
	U.closedModal("SecretPop")
	local holder, sc = pop.holder, pop.sc
	pop.back.Visible = false
	local function done()
		holder.Visible = false
		holder.Position = UDim2.fromScale(0.5, 0.46)
		sc.Scale = 1
	end
	local btn = Hud.buttons.Secret
	if not instant and btn and btn.Visible then
		local k = math.max(U.scale, 0.01)
		local tgt = (btn.AbsolutePosition + btn.AbsoluteSize / 2) / k
		U.tween(holder, 0.45, { Position = UDim2.fromOffset(tgt.X, tgt.Y) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local tw = U.tween(sc, 0.45, { Scale = 0.04 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local my = popGen
		tw.Completed:Connect(function()
			if popGen == my and not popOpen then
				done()
				U.pulse(btn, 0.35)
				Hud.flash("Secret")
				U.sfx("Whoosh", nil, 0.5)
			end
		end)
	elseif not instant then
		local my = popGen
		local tw = U.tween(sc, 0.2, { Scale = 0.5 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tw.Completed:Connect(function()
			if popGen == my and not popOpen then
				done()
			end
		end)
	else
		done()
	end
	State.emit("SecretClosed")
end

-- show the pop-up for POP_TIME s (no tap needed)
function SecretCard.popUp()
	local t = popText()
	if not t then
		return
	end
	popGen += 1
	local my = popGen
	local wasOpen = popOpen
	popOpen = true
	U.openModal("SecretPop", function()
		-- another window opened on top (e.g. the player tapped 🔒 SECRET): vanish at once
		if popOpen then
			popOpen = false
			popGen += 1
			pop.back.Visible = false
			pop.holder.Visible = false
			pop.sc.Scale = 1
			State.emit("SecretClosed")
		end
	end)
	popLayout()
	pop.role.Text = t.role
	pop.role.TextColor3 = t.color
	pop.short.Text = U.esc(t.short)
	pop.where.Text = U.esc(t.where)
	pop.extra.Text = U.esc(t.extra)
	pop.stroke.Color = t.color
	pop.bar.BackgroundColor3 = t.color
	pop.back.Visible = true
	pop.back.BackgroundTransparency = 1
	U.tween(pop.back, 0.25, { BackgroundTransparency = 0.55 })
	pop.holder.Position = UDim2.fromScale(0.5, 0.46)
	pop.holder.Visible = true
	if not wasOpen then
		pop.sc.Scale = 0.3
		U.tween(pop.sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	else
		U.pulse(pop.panel, 0.08)
	end
	-- short lock flourish (0.7 s): 🔒 pops, shakes, opens
	local lock = pop.lock :: TextLabel
	lock.Text = "🔒"
	lock.Rotation = 0
	local ls = pop.lockScale :: UIScale
	ls.Scale = 0.3
	U.tween(ls, 0.25, { Scale = 1.15 }, Enum.EasingStyle.Back)
	U.sfx("Whoosh", nil, 0.6)
	task.spawn(function()
		task.wait(0.25)
		for i = 1, 4 do
			if popGen ~= my then
				return
			end
			lock.Rotation = (i % 2 == 0) and 12 or -12
			task.wait(0.05)
		end
		lock.Rotation = 0
		lock.Text = "🔓"
		U.sfx("SecretGet")
		U.tween(ls, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		U.pulse(pop.role, 0.15)
	end)
	-- countdown bar
	pop.bar.Size = UDim2.fromScale(1, 1)
	U.tween(pop.bar, POP_TIME, { Size = UDim2.fromScale(0, 1) }, Enum.EasingStyle.Linear)
	task.delay(POP_TIME, function()
		if popGen == my and popOpen then
			SecretCard.closePop()
		end
	end)
end

function SecretCard.isPopOpen(): boolean
	return popOpen
end

local function buildPop()
	pop.back = U.new("TextButton", {
		Name = "PopBackdrop",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 50,
		Parent = gui,
	})
	pop.back.Activated:Connect(function()
		SecretCard.closePop()
	end)
	-- holder carries the fit scale; the panel inside carries the pop/fly scale
	pop.holder = U.frame(gui, {
		Name = "SecretPop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(760, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 51,
	})
	pop.fit = U.new("UIScale", { Name = "Fit", Parent = pop.holder })
	local panel = U.new("Frame", {
		Name = "Panel",
		Active = true,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = U.C.bg,
		ZIndex = 52,
		Parent = pop.holder,
	})
	pop.panel = panel
	pop.sc = U.new("UIScale", { Name = "Pop", Parent = panel })
	U.corner(panel, 28)
	pop.stroke = U.stroke(panel, U.C.gold, 5)
	U.gradient(panel, Color3.fromRGB(80, 44, 140), Color3.fromRGB(20, 22, 44), 90)
	U.pad(panel, 26, 16)
	U.list(panel, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center)
	-- tap anywhere on the panel closes it early
	panel.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			SecretCard.closePop()
		end
	end)

	local head = U.frame(panel, { Name = "Head", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 64), LayoutOrder = 1, ZIndex = 53 })
	U.list(head, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	pop.lock = U.label(head, "🔒", 54, { Name = "Lock", Size = UDim2.fromOffset(64, 64), TextWrapped = false, ZIndex = 54, LayoutOrder = 1 })
	pop.lockScale = U.new("UIScale", { Parent = pop.lock })
	local yl = U.label(head, "YOUR SECRET", 34, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 44),
		TextColor3 = U.C.gold,
		TextWrapped = false,
		ZIndex = 54,
		LayoutOrder = 2,
	})
	U.textStroke(yl, 2)
	pop.role = U.label(panel, "THE GUEST", 52, { Name = "Role", Size = UDim2.new(1, 0, 0, 60), LayoutOrder = 2, TextScaled = true, ZIndex = 53 })
	U.new("UITextSizeConstraint", { MaxTextSize = 54, Parent = pop.role })
	U.textStroke(pop.role, 3)
	pop.short = U.label(panel, "", 40, {
		Name = "Short",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
		ZIndex = 53,
	})
	U.textStroke(pop.short, 2)
	pop.where = U.label(panel, "", 30, {
		Name = "Where",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		TextColor3 = U.C.evidence,
		Font = U.BOLD,
		ZIndex = 53,
	})
	pop.extra = U.label(panel, "", 24, {
		Name = "Extra",
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 5,
		TextColor3 = U.C.muted,
		Font = U.BOLD,
		ZIndex = 53,
	})
	U.label(panel, "Tap 🔒 SECRET anytime to see it again", 24, {
		Name = "Hint",
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 6,
		TextColor3 = U.C.gold,
		Font = U.BOLD,
		ZIndex = 53,
	})
	local barBack = U.frame(panel, { Name = "Countdown", Size = UDim2.new(1, 0, 0, 12), LayoutOrder = 7, BackgroundColor3 = U.C.dark, ZIndex = 53 })
	U.round(barBack)
	pop.bar = U.frame(barBack, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = U.C.gold, ZIndex = 54 })
	U.round(pop.bar)
	U.scaleChanged:Connect(popLayout)
	popLayout()
end

function SecretCard.init()
	gui = U.screen("EHAS_Secret", 20)
	back = U.new("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = gui,
	})
	back.Activated:Connect(function()
		SecretCard.close()
	end)
	card = U.frame(back, {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 680, 0.94, 0),
		BackgroundColor3 = U.C.bg,
		Active = true,
	})
	U.new("UISizeConstraint", { MaxSize = Vector2.new(680, 900), Parent = card })
	U.new("UIScale", { Name = "Pop", Parent = card })
	U.corner(card, 26)
	U.stroke(card, U.C.gold, 5)
	U.gradient(card, Color3.fromRGB(70, 40, 120), Color3.fromRGB(18, 20, 40), 90)

	-- header
	lockL = U.label(card, "🔒", 64, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -40),
		Size = UDim2.fromOffset(100, 100),
		TextWrapped = false,
		ZIndex = 3,
	})
	U.label(card, "YOUR SECRET", 26, {
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 30),
		TextColor3 = U.C.muted,
		Font = U.BOLD,
	})
	roleL = U.label(card, "THE GUEST", 54, {
		Position = UDim2.fromOffset(20, 84),
		Size = UDim2.new(1, -40, 0, 62),
		TextScaled = true,
	})
	U.textStroke(roleL, 3)
	U.new("UITextSizeConstraint", { MaxTextSize = 56, Parent = roleL })

	content = U.scroll(card, {
		Name = "Content",
		Position = UDim2.fromOffset(20, 154),
		Size = UDim2.new(1, -40, 1, -154 - 150),
	})
	U.list(content, Enum.FillDirection.Vertical, 12)
	U.pad(content, 4, 4)

	rewardL = U.label(card, "💰 REWARD", 32, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -84),
		Size = UDim2.new(1, -40, 0, 50),
	})
	U.textStroke(rewardL, 2)
	okBtn = U.button(card, "CLOSE", Color3.fromRGB(150, 60, 230), function()
		SecretCard.close()
	end, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.new(1, -40, 0, 64),
	})
	U.gradient(okBtn, Color3.new(1, 1, 1), Color3.fromRGB(180, 180, 210), 90)

	Hud.open.Secret = SecretCard.toggle
	buildPop()

	State.sig("YourSecret"):Connect(function(s)
		if type(s) ~= "table" then
			return
		end
		-- YourSecret can arrive just before the Intro RoundState; only skip it during the reveal/rewards
		local phase = State.round.phase
		if phase ~= "Reveal" and phase ~= "Rewards" then
			if isOpen then
				refresh() -- e.g. reroll result
				U.sfx("SecretGet")
			else
				SecretCard.popUp() -- auto pop-up, goes away by itself
			end
		end
	end)
	State.sig("SecretProgress"):Connect(onProgress)
	State.sig("Phase"):Connect(function(phase)
		if (phase == "Reveal" or phase == "Lobby") and isOpen then
			SecretCard.close()
		end
		if (phase == "Reveal" or phase == "Lobby" or phase == "Rewards") and popOpen then
			SecretCard.closePop(true)
		end
		if phase == "Lobby" then
			State.secret = nil
		end
	end)
	State.sig("Phase"):Connect(function(phase)
		-- auto-collapse when play starts so nothing covers the screen
		if phase == "Play" and isOpen then
			task.delay(4, function()
				if isOpen and State.round.phase == "Play" then
					SecretCard.close()
				end
			end)
		end
	end)
end

function SecretCard.isOpen(): boolean
	return isOpen
end

return SecretCard
