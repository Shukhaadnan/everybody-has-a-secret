-- Reveal.luau: end-of-round reveal (PROMPT §30) and the Rewards panel.
-- Reveal: cards appear one by one (1.2 s each) with avatar/silhouette, role in tier color, main/side, ✅/❌ stamps,
-- highlights; then MVP + story line; auto-closes. Rewards: coins/xp count-up, level bar, LEVEL UP burst, breakdown.
local U = require(script.Parent.Util)
local State = require(script.Parent.State)

local Reveal = {}

local gui: ScreenGui
local root: Frame
local grid: ScrollingFrame
local header: TextLabel
local footer: Frame
local running = 0 -- generation counter, cancels stale sequences
local rewardsPending: any = nil
local revealActive = false

local CARD_W, CARD_H = 300, 330

local function stamp(parent: Instance, ok: boolean, z: number)
	local s = U.label(parent, ok and "✅ SUCCESS" or "❌ FAILED", 30, {
		Name = "Stamp",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 196),
		Size = UDim2.fromOffset(220, 46),
		BackgroundTransparency = 0.1,
		BackgroundColor3 = ok and Color3.fromRGB(20, 90, 50) or Color3.fromRGB(110, 20, 30),
		TextColor3 = ok and U.C.good or U.C.bad,
		Rotation = ok and -6 or 6,
		ZIndex = z,
		TextWrapped = false,
	})
	U.corner(s, 10)
	U.stroke(s, ok and U.C.good or U.C.bad, 4)
	local sc = U.new("UIScale", { Scale = 3, Parent = s })
	s.TextTransparency = 1
	s.BackgroundTransparency = 1
	U.tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	U.tween(s, 0.2, { TextTransparency = 0, BackgroundTransparency = 0.1 })
	return s
end

local function buildCard(row: any, index: number, mvp: number?): Frame
	local color = typeof(row.color) == "Color3" and row.color or U.tierColor(type(row.main) == "table" and row.main.tier or nil)
	local isMe = row.userId == U.player.UserId
	local card = U.frame(grid, {
		Name = "Card" .. index,
		LayoutOrder = index,
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		BackgroundColor3 = U.C.panel,
		ClipsDescendants = false,
	})
	U.corner(card, 18)
	U.stroke(card, isMe and U.C.gold or color, isMe and 5 or 3)
	U.gradient(card, Color3.fromRGB(56, 64, 110), Color3.fromRGB(24, 26, 46), 90)
	local av = U.avatar(card, tonumber(row.userId) or -1, 74, color)
	av.Position = UDim2.fromOffset(12, 12)
	local nameL = U.label(card, U.esc(row.name or U.nameOf(row.userId)) .. (row.isBot and " 🤖" or "") .. (isMe and " (YOU)" or ""), 22, {
		Position = UDim2.fromOffset(96, 12),
		Size = UDim2.new(1, -104, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
		Font = U.BOLD,
	})
	U.new("UITextSizeConstraint", { MaxTextSize = 22, Parent = nameL })
	local roleL = U.label(card, string.upper(tostring(row.role or "THE GUEST")), 30, {
		Position = UDim2.fromOffset(96, 40),
		Size = UDim2.new(1, -104, 0, 44),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
		TextColor3 = color,
	})
	U.new("UITextSizeConstraint", { MaxTextSize = 30, Parent = roleL })
	U.textStroke(roleL, 2)

	local main = type(row.main) == "table" and row.main or {}
	local side = type(row.side) == "table" and row.side or nil
	local mainL = U.label(card, U.esc(main.text or "?"), 20, {
		Position = UDim2.fromOffset(12, 94),
		Size = UDim2.new(1, -24, 0, 50),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextScaled = true,
	})
	U.new("UITextSizeConstraint", { MaxTextSize = 20, Parent = mainL })
	local tierB = U.label(card, string.upper(tostring(main.tier or "")), 14, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 84),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		BackgroundTransparency = 0,
		BackgroundColor3 = U.tierColor(main.tier),
		TextColor3 = U.C.dark,
		Font = U.BOLD,
		TextWrapped = false,
		Visible = main.tier ~= nil,
		ZIndex = 3,
	})
	U.corner(tierB, 10)
	U.pad(tierB, 8, 0)
	side = side or { text = "(first rounds: one secret only)", done = false }
	local sideL = U.label(card, (side.done and "✔ " or "✘ ") .. "Side: " .. U.esc(side.text or "?"), 16, {
		Position = UDim2.fromOffset(12, 148),
		Size = UDim2.new(1, -24, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
		Font = U.BOLD,
		TextColor3 = side.done and U.C.good or U.C.muted,
	})
	U.new("UITextSizeConstraint", { MaxTextSize = 16, Parent = sideL })

	-- highlights
	local hl = U.frame(card, {
		Position = UDim2.fromOffset(12, 226),
		Size = UDim2.new(1, -24, 0, 62),
		BackgroundTransparency = 1,
	})
	U.list(hl, Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Left)
	if type(row.highlights) == "table" then
		for i, h in ipairs(row.highlights) do
			if i > 3 then
				break
			end
			local l = U.label(hl, "• " .. U.esc(h), 15, {
				Size = UDim2.new(1, 0, 0, 19),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextScaled = true,
				Font = U.BOLD,
				TextColor3 = U.C.muted,
				LayoutOrder = i,
			})
			U.new("UITextSizeConstraint", { MaxTextSize = 15, Parent = l })
		end
	end
	U.label(card, "🪙 +" .. U.commas(tonumber(row.reward) or 0), 24, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -6),
		Size = UDim2.new(1, -24, 0, 32),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = U.C.gold,
	})
	if mvp and row.userId == mvp then
		card:SetAttribute("MVP", true)
	end
	return card
end

local function close(gen: number)
	if gen ~= running or not root.Visible then
		return
	end
	revealActive = false
	U.closedModal("Reveal")
	U.tween(root, 0.4, { BackgroundTransparency = 1 })
	U.popOut(root:FindFirstChild("Inner") :: Frame, function()
		if gen == running then
			root.Visible = false
			-- a long reveal on a big server can run into the next Intro: don't let the rewards panel cover the new secret card
			if rewardsPending and (State.round.phase == "Reveal" or State.round.phase == "Rewards" or State.round.phase == "Lobby") then
				local r = rewardsPending
				rewardsPending = nil
				Reveal.showRewards(r)
			end
		end
	end)
end

function Reveal.show(p: any)
	running += 1
	local gen = running
	revealActive = true
	U.openModal("Reveal", function()
		if gen == running then
			revealActive = false
			root.Visible = false
		end
	end)
	U.clear(grid)
	U.clear(footer)
	root.Visible = true
	root.BackgroundTransparency = 1
	U.tween(root, 0.4, { BackgroundTransparency = 0.25 })
	local inner = root:FindFirstChild("Inner") :: Frame
	U.popIn(inner, 0.85)
	header.Text = "🎭 EVERYBODY HAD A SECRET..."
	U.sfx("VineBoom", nil, 0.6)

	local rows = type(p.rows) == "table" and table.clone(p.rows) or {}
	-- your own card first: with 10 cards it ended up last, off-screen at the bottom right
	for i, r in ipairs(rows) do
		if type(r) == "table" and r.userId == U.player.UserId and i > 1 then
			table.insert(rows, 1, table.remove(rows, i))
			break
		end
	end
	task.spawn(function()
		task.wait(1.0)
		for i, row in ipairs(rows) do
			if gen ~= running then
				return
			end
			local card = buildCard(row, i, tonumber(p.mvp))
			local sc = U.new("UIScale", { Scale = 0.2, Parent = card })
			card.Rotation = (i % 2 == 0) and 8 or -8
			U.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			U.tween(card, 0.35, { Rotation = 0 }, Enum.EasingStyle.Back)
			U.sfx("Whoosh", nil, 0.6)
			-- keep the newest card in view
			task.defer(function()
				local y = card.AbsolutePosition.Y - grid.AbsolutePosition.Y + grid.CanvasPosition.Y
				local target = math.max(0, y + card.AbsoluteSize.Y - grid.AbsoluteSize.Y + 10)
				U.tween(grid, 0.3, { CanvasPosition = Vector2.new(0, target) })
			end)
			task.wait(0.55)
			if gen ~= running then
				return
			end
			local ok = type(row.main) == "table" and row.main.done == true
			stamp(card, ok, 5)
			U.sfx(ok and "Complete" or "Fail", nil, 0.6)
			task.wait(0.65)
		end
		if gen ~= running then
			return
		end
		-- MVP + story
		local mvpId = tonumber(p.mvp)
		local mvpName = nil
		for _, r in ipairs(rows) do
			if r.userId == mvpId then
				mvpName = r.name
			end
		end
		for _, c in ipairs(grid:GetChildren()) do
			if c:IsA("Frame") and c:GetAttribute("MVP") then
				local crown = U.label(c, "👑 MVP", 26, {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, 0, 0, -6),
					Size = UDim2.fromOffset(140, 36),
					BackgroundTransparency = 0,
					BackgroundColor3 = U.C.gold,
					TextColor3 = U.C.dark,
					ZIndex = 6,
				})
				U.corner(crown, 18)
				U.pulse(crown, 0.6)
				local st = c:FindFirstChildOfClass("UIStroke")
				if st then
					st.Color = U.C.gold
					st.Thickness = 6
				end
			end
		end
		U.list(footer, Enum.FillDirection.Vertical, 4)
		if mvpName then
			local m = U.label(footer, "👑 MVP: " .. U.esc(mvpName), 40, { Size = UDim2.new(1, 0, 0, 46), TextColor3 = U.C.gold, LayoutOrder = 1 })
			U.textStroke(m, 3)
			U.popIn(m, 0.3)
			U.sfx("Jackpot", nil, 0.7)
		end
		if type(p.story) == "string" and p.story ~= "" then
			local s = U.label(footer, "📖 " .. U.esc(p.story), 24, {
				Size = UDim2.new(1, 0, 0, 60),
				TextScaled = true,
				Font = U.BOLD,
				LayoutOrder = 2,
			})
			U.new("UITextSizeConstraint", { MaxTextSize = 24, Parent = s })
			s.TextTransparency = 1
			U.tween(s, 0.6, { TextTransparency = 0 })
		end
		local again = U.label(footer, "▶ NEXT ROUND STARTS SOON — PLAY AGAIN!", 22, {
			Size = UDim2.new(1, 0, 0, 28),
			TextColor3 = U.C.good,
			LayoutOrder = 3,
		})
		task.spawn(function()
			while again.Parent and gen == running do
				U.tween(again, 0.5, { TextTransparency = 0.5 })
				task.wait(0.5)
				U.tween(again, 0.5, { TextTransparency = 0 })
				task.wait(0.5)
			end
		end)
		task.wait(7)
		close(gen)
	end)
end

-------------------------------------------------------------------------------- rewards
local rw: Frame
local rwBack: TextButton
local rwOpen = false

local function countUp(l: TextLabel, prefix: string, to: number, dur: number)
	local t0 = os.clock()
	while true do
		local a = math.min(1, (os.clock() - t0) / dur)
		local e = 1 - (1 - a) ^ 3
		l.Text = prefix .. U.commas(to * e)
		if a >= 1 then
			break
		end
		task.wait()
	end
end

local function burst(parent: GuiObject)
	for i = 1, 14 do
		local s = U.label(parent, (i % 3 == 0) and "⭐" or ((i % 3 == 1) and "✨" or "🎉"), 40, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(50, 50),
			ZIndex = 30,
			TextWrapped = false,
		})
		local ang = (i / 14) * math.pi * 2
		local r = 220 + math.random(0, 80)
		U.tween(s, 0.9, {
			Position = UDim2.new(0.5, math.cos(ang) * r, 0.5, math.sin(ang) * r),
			TextTransparency = 1,
			Rotation = math.random(-180, 180),
		})
		task.delay(1, function()
			s:Destroy()
		end)
	end
end

local function closeRewards()
	if not rwOpen then
		return
	end
	rwOpen = false
	U.closedModal("Rewards")
	U.hideWindow(rwBack, rw)
end

function Reveal.showRewards(p: any)
	if revealActive then
		rewardsPending = p
		return
	end
	U.openModal("Rewards", function()
		rwOpen = false
		rwBack.Visible = false
	end)
	rwOpen = true
	local body = rw:FindFirstChild("Body") :: Frame
	U.clear(body)
	U.list(body, Enum.FillDirection.Vertical, 10)
	U.showWindow(rwBack, rw)
	local coinsL = U.label(body, "🪙 +0", 64, { Size = UDim2.new(1, 0, 0, 72), TextColor3 = U.C.gold, LayoutOrder = 1 })
	U.textStroke(coinsL, 3)
	local xpL = U.label(body, "⭐ +0 XP", 40, { Size = UDim2.new(1, 0, 0, 46), TextColor3 = U.C.purple, LayoutOrder = 2 })
	U.textStroke(xpL, 2)
	local lvRow = U.frame(body, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 3 })
	local lvL = U.label(lvRow, "LV " .. tostring(p.level or 1), 30, {
		Size = UDim2.fromOffset(110, 44),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local barBg = U.frame(lvRow, { Position = UDim2.fromOffset(120, 12), Size = UDim2.new(1, -120, 0, 22), BackgroundColor3 = U.C.dark })
	U.round(barBg)
	local fill = U.frame(barBg, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = U.C.purple })
	U.round(fill)
	U.gradient(fill, Color3.fromRGB(220, 160, 255), Color3.fromRGB(130, 60, 230), 0)
	U.label(body, "🏷️ " .. U.esc(p.title or ""), 24, { Size = UDim2.new(1, 0, 0, 30), Font = U.BOLD, TextColor3 = U.C.muted, LayoutOrder = 4 })
	local list = U.frame(body, {
		BackgroundColor3 = U.C.panel,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 5,
	})
	U.corner(list, 14)
	U.pad(list, 12, 8)
	U.list(list, Enum.FillDirection.Vertical, 4)
	if type(p.breakdown) == "table" then
		for i, b in ipairs(p.breakdown) do
			local r = U.frame(list, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = i })
			U.label(r, U.esc(b.label or ""), 22, {
				Size = UDim2.new(0.6, 0, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = U.BOLD,
				TextScaled = true,
			})
			U.label(r, string.format("🪙%s  ⭐%s", U.commas(tonumber(b.coins) or 0), U.commas(tonumber(b.xp) or 0)), 22, {
				Position = UDim2.fromScale(0.6, 0),
				Size = UDim2.new(0.4, 0, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = U.C.gold,
			})
			r.Visible = false
			task.delay(0.3 + i * 0.2, function()
				r.Visible = true
				U.popIn(r, 0.6)
			end)
		end
	end
	U.button(body, "AWESOME!", U.C.good, closeRewards, { Size = UDim2.new(1, 0, 0, 64), LayoutOrder = 9 })

	task.spawn(function()
		U.sfx("CoinGet")
		countUp(coinsL, "🪙 +", tonumber(p.coins) or 0, 1.2)
		countUp(xpL, "⭐ +", tonumber(p.xp) or 0, 0.8)
		xpL.Text = xpL.Text .. " XP"
		-- read XP after the count-up: the server sends the fresh Profile right after Rewards
		local prof = State.profile
		local xpNow, xpNext = 0, 0
		if type(prof) == "table" then
			xpNow, xpNext = tonumber(prof.xp) or 0, tonumber(prof.xpNext) or 0
		end
		local a = xpNext > 0 and math.clamp(xpNow / xpNext, 0, 1) or 0.6
		if p.leveledUp then
			U.tween(fill, 0.6, { Size = UDim2.fromScale(1, 1) })
			task.wait(0.65)
			lvL.Text = "LV " .. tostring(p.level or "?")
			fill.Size = UDim2.fromScale(0, 1)
			U.sfx("LevelUp")
			local up = U.label(rw, "LEVEL UP!", 80, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.42),
				Size = UDim2.fromOffset(600, 100),
				TextColor3 = U.C.gold,
				ZIndex = 30,
				Rotation = -6,
			})
			U.textStroke(up, 4)
			local s = U.new("UIScale", { Scale = 0.1, Parent = up })
			U.tween(s, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
			burst(rw)
			task.delay(2, function()
				U.tween(up, 0.4, { TextTransparency = 1 })
				task.wait(0.45)
				up:Destroy()
			end)
		end
		U.tween(fill, 0.7, { Size = UDim2.fromScale(a, 1) })
		task.wait(9)
		if rwOpen then
			closeRewards()
		end
	end)
end

function Reveal.init()
	gui = U.screen("EHAS_Reveal", 40)
	root = U.frame(gui, {
		Name = "Reveal",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(8, 6, 20),
		BackgroundTransparency = 1,
		Visible = false,
		Active = true,
	})
	local inner = U.frame(root, {
		Name = "Inner",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.96, 0.96),
	})
	header = U.label(inner, "🎭 THE REVEAL", 52, {
		Size = UDim2.new(1, 0, 0, 64),
		TextColor3 = U.C.gold,
	})
	U.textStroke(header, 3)
	grid = U.scroll(inner, {
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 1, -70 - 150),
	})
	U.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(CARD_W, CARD_H),
		CellPadding = UDim2.fromOffset(14, 20),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	U.pad(grid, 8, 14)
	footer = U.frame(inner, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 146),
	})
	local skip = U.button(inner, "SKIP ⏭", U.C.panel2, function()
		close(running)
	end, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 4),
		Size = UDim2.fromOffset(130, 54),
		TextSize = 24,
	})
	skip.ZIndex = 5

	local back, panel, closeB = U.window(gui, "💰 ROUND REWARDS", 560, 700, U.C.gold)
	rwBack, rw = back, panel
	rwBack.Activated:Connect(closeRewards)
	closeB.Activated:Connect(closeRewards)

	State.sig("Reveal"):Connect(Reveal.show)
	State.sig("Rewards"):Connect(Reveal.showRewards)
	State.sig("Phase"):Connect(function(phase)
		if phase == "Intro" or phase == "Play" then
			rewardsPending = nil -- stale: next round already started
			if root.Visible then
				close(running)
			end
			if rwOpen then
				closeRewards()
			end
		end
	end)
end

return Reveal
