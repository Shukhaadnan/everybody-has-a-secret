-- Shop.luau: Shop / Profile window with tabs: Cosmetics (buy with coins / equip), Robux (only items whose ProductId
-- or PassId is non-zero; prompts MarketplaceService), Challenges (daily + weekly progress bars), Stats (profile card).
local MarketplaceService = game:GetService("MarketplaceService")

local U = require(script.Parent.Util)
local State = require(script.Parent.State)
local Hud = require(script.Parent.Hud)
local ShopData = require(script.Parent.ShopData)

local Shop = {}

local gui: ScreenGui
local back: TextButton
local panel: Frame
local body: Frame
local isOpen = false
local tab = "Cosmetics"
local slotFilter: string? = nil

local TABS = {
	{ "Cosmetics", "🎩 Cosmetics" },
	{ "Robux", "💎 Robux" },
	{ "Challenges", "🏆 Challenges" },
	{ "Stats", "📊 Profile" },
}

local render: () -> ()

local RARITY = {
	Common = Color3.fromRGB(170, 180, 200),
	Uncommon = Color3.fromHex("3ddc84"),
	Rare = Color3.fromRGB(70, 160, 255),
	Epic = Color3.fromHex("b36bff"),
	Legendary = Color3.fromHex("ffc83d"),
}

local function owned(id: string): boolean
	local p = State.profile
	return type(p) == "table" and type(p.owned) == "table" and p.owned[id] == true
end

local function equippedIn(slot: string): any
	local p = State.profile
	return type(p) == "table" and type(p.equipped) == "table" and p.equipped[slot] or nil
end

local function coins(): number
	local p = State.profile
	return type(p) == "table" and (tonumber(p.coins) or 0) or 0
end

local function header(parent: Instance, text: string, order: number)
	U.label(parent, text, 26, {
		Size = UDim2.new(1, -8, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = U.C.gold,
		LayoutOrder = order,
	})
end

-------------------------------------------------------------------------------- tabs
local function renderCosmetics(sc: ScrollingFrame)
	local data = ShopData.get()
	if #data.cosmetics == 0 then
		U.label(sc, "Shop is restocking... check back soon! 🛍️", 26, { Size = UDim2.new(1, 0, 0, 80), TextColor3 = U.C.muted })
		return
	end
	-- slot filter chips
	local slots, seen = {}, {}
	for _, c in ipairs(data.cosmetics) do
		if not seen[c.slot] then
			seen[c.slot] = true
			table.insert(slots, c.slot)
		end
	end
	local chips = U.scroll(sc, {
		Size = UDim2.new(1, -8, 0, 56),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 4,
		LayoutOrder = 1,
	})
	U.list(chips, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local function chip(label: string, val: string?, o: number)
		local on = slotFilter == val
		local b = U.button(chips, label, on and U.C.gold or U.C.panel2, function()
			slotFilter = val
			render()
		end, {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 48),
			TextSize = 20,
			TextWrapped = false,
			LayoutOrder = o,
			TextColor3 = on and U.C.dark or U.C.white,
		})
		U.pad(b, 14, 4)
	end
	chip("All", nil, 0)
	for i, s in ipairs(slots) do
		chip((ShopData.SLOT_ICON[s] or "🎁") .. " " .. s, s, i)
	end

	local grid = U.frame(sc, {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
	})
	U.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(200, 232),
		CellPadding = UDim2.fromOffset(10, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	local level = type(State.profile) == "table" and (tonumber(State.profile.level) or 1) or 1
	for i, c in ipairs(data.cosmetics) do
		if slotFilter == nil or c.slot == slotFilter then
			local own = owned(c.id)
			local eq = equippedIn(c.slot) == c.id
			local cell = U.frame(grid, { BackgroundColor3 = U.C.panel, LayoutOrder = i })
			U.corner(cell, 16)
			local rarityCol = RARITY[tostring(c.rarity)] or U.tierColor(type(c.rarity) == "string" and c.rarity or nil)
			U.stroke(cell, eq and U.C.good or (c.rarity and rarityCol or U.C.line), eq and 4 or 2)
			U.label(cell, c.icon, 54, { Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 66), TextWrapped = false })
			local nm = U.label(cell, U.esc(c.name), 22, {
				Position = UDim2.fromOffset(6, 78),
				Size = UDim2.new(1, -12, 0, 30),
				TextScaled = true,
			})
			U.new("UITextSizeConstraint", { MaxTextSize = 22, Parent = nm })
			local ds = U.label(cell, U.esc(c.desc ~= "" and c.desc or c.slot), 15, {
				Position = UDim2.fromOffset(6, 108),
				Size = UDim2.new(1, -12, 0, 40),
				TextColor3 = U.C.muted,
				Font = U.BOLD,
				TextScaled = true,
			})
			U.new("UITextSizeConstraint", { MaxTextSize = 15, Parent = ds })
			local txt, col, fn
			if eq then
				txt, col = "✔ EQUIPPED", Color3.fromRGB(60, 120, 80)
				fn = function()
					U.fire("Equip", { slot = c.slot, id = "" })
				end
			elseif own then
				txt, col = "EQUIP", U.C.good
				fn = function()
					U.fire("Equip", { slot = c.slot, id = c.id })
				end
			elseif c.isDefault and c.price <= 0 then
				txt, col = "EQUIP", U.C.good
				fn = function()
					U.fire("Equip", { slot = c.slot, id = c.id })
				end
			elseif c.vipOnly then
				local vip = type(State.profile) == "table" and State.profile.vip
				txt, col = vip and "EQUIP" or "⭐ VIP ONLY", vip and U.C.good or Color3.fromRGB(120, 90, 30)
				fn = function()
					if vip then
						U.fire("Equip", { slot = c.slot, id = c.id })
					else
						State.emit("Toast", { text = "This one is for VIP members ⭐", kind = "info" })
					end
				end
			elseif c.rewardOnly then
				txt, col = "🏆 REWARD", U.C.panel2
				fn = function()
					State.emit("Toast", { text = "Unlocked through challenges & achievements!", kind = "info" })
				end
			elseif c.levelReq and level < c.levelReq then
				txt, col = "🔒 LV " .. c.levelReq, U.C.panel2
				fn = function()
					State.emit("Toast", { text = "Reach level " .. c.levelReq .. " to unlock this!", kind = "info" })
				end
			else
				local afford = coins() >= c.price
				txt, col = "🪙 " .. U.commas(c.price), afford and Color3.fromRGB(220, 160, 30) or Color3.fromRGB(110, 90, 50)
				fn = function()
					if coins() < c.price then
						State.emit("Toast", { text = "Not enough coins! Complete secrets to earn more.", kind = "bad" })
						return
					end
					U.fire("Buy", { id = c.id })
				end
			end
			U.button(cell, txt, col, fn, {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -10),
				Size = UDim2.new(1, -20, 0, 58),
				TextSize = 24,
			})
		end
	end
end

local function renderRobux(sc: ScrollingFrame)
	local data = ShopData.get()
	if #data.robux == 0 then
		U.label(sc, "💎 Premium items are coming soon!", 28, { Size = UDim2.new(1, 0, 0, 80), TextColor3 = U.C.muted })
		return
	end
	U.label(sc, "Cosmetic & convenience only — no pay-to-win. 💜", 20, {
		Size = UDim2.new(1, -8, 0, 28),
		TextColor3 = U.C.muted,
		Font = U.BOLD,
		LayoutOrder = 0,
	})
	for i, e in ipairs(data.robux) do
		local row = U.frame(sc, { BackgroundColor3 = U.C.panel, Size = UDim2.new(1, -8, 0, 120), LayoutOrder = i })
		U.corner(row, 16)
		U.stroke(row, U.C.purple, 3)
		U.gradient(row, Color3.fromRGB(70, 50, 120), Color3.fromRGB(34, 30, 60), 0)
		U.label(row, e.icon, 56, { Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(90, 120), TextWrapped = false })
		local isPass = e.passId ~= 0
		local ownedPass = isPass and type(State.profile) == "table" and (owned(e.id) or (string.find(string.lower(e.id), "vip", 1, true) and State.profile.vip))
		U.label(row, U.esc(e.name), 28, {
			Position = UDim2.fromOffset(104, 10),
			Size = UDim2.new(1, -300, 0, 36),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = true,
		})
		local d = U.label(row, U.esc(e.desc), 18, {
			Position = UDim2.fromOffset(104, 48),
			Size = UDim2.new(1, -300, 0, 62),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = U.C.muted,
			Font = U.BOLD,
			TextScaled = true,
		})
		U.new("UITextSizeConstraint", { MaxTextSize = 18, Parent = d })
		U.button(row, ownedPass and "✔ OWNED" or ("R$ " .. tostring(e.robux)), ownedPass and Color3.fromRGB(60, 120, 80) or Color3.fromRGB(40, 170, 90), function()
			if ownedPass then
				return
			end
			local ok, err = pcall(function()
				if isPass then
					MarketplaceService:PromptGamePassPurchase(U.player, e.passId)
				else
					MarketplaceService:PromptProductPurchase(U.player, e.productId)
				end
			end)
			if not ok then
				warn("[EHAS client] purchase prompt: " .. tostring(err))
			end
		end, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(170, 70),
			TextSize = 28,
		})
	end
	-- crate odds (Roblox rule: paid random rewards show odds)
	local odds = data.crateOdds
	if type(odds) == "table" then
		header(sc, "🎲 Mystery Crate odds", 900)
		local parts = {}
		local function each(t: any): any
			if #t > 0 then
				return ipairs(t)
			end
			return pairs(t)
		end
		for k, v in each(odds) do
			if type(v) == "number" then
				table.insert(parts, string.format("%s: %s%%", tostring(k), tostring(v)))
			elseif type(v) == "table" then
				local n = v.name or v.Name or v.rarity or v.Rarity or v.tier or v.Tier or k
				local pct = v.pct or v.chance or v.Chance or v.percent or v.weight or v.Weight
				if pct then
					table.insert(parts, string.format("%s: %s%%", tostring(n), tostring(pct)))
				end
			end
		end
		U.label(sc, table.concat(parts, "   "), 20, {
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = U.BOLD,
			LayoutOrder = 901,
		})
	end
end

local function challengeRow(sc: Instance, ch: any, order: number)
	local cur, max = tonumber(ch.cur) or 0, math.max(1, tonumber(ch.max) or 1)
	local row = U.frame(sc, { BackgroundColor3 = U.C.panel, Size = UDim2.new(1, -8, 0, 96), LayoutOrder = order })
	U.corner(row, 14)
	U.stroke(row, ch.done and U.C.good or U.C.line, 2)
	U.label(row, (ch.done and "✅ " or "🎯 ") .. U.esc(ch.text), 22, {
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -170, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
	})
	U.label(row, "🪙 " .. U.commas(tonumber(ch.reward) or 0), 24, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 8),
		Size = UDim2.fromOffset(150, 40),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = U.C.gold,
	})
	local bg = U.frame(row, { Position = UDim2.fromOffset(14, 58), Size = UDim2.new(1, -120, 0, 22), BackgroundColor3 = U.C.dark })
	U.round(bg)
	local fill = U.frame(bg, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = ch.done and U.C.good or U.C.info })
	U.round(fill)
	U.tween(fill, 0.6, { Size = UDim2.fromScale(math.clamp(cur / max, 0, 1), 1) })
	U.label(row, string.format("%d/%d", math.min(cur, max), max), 22, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 52),
		Size = UDim2.fromOffset(96, 34),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
end

local function renderChallenges(sc: ScrollingFrame)
	local p = State.profile or {}
	header(sc, "📅 DAILY", 1)
	local o = 2
	if type(p.daily) == "table" and #p.daily > 0 then
		for _, ch in ipairs(p.daily) do
			challengeRow(sc, ch, o)
			o += 1
		end
	else
		U.label(sc, "No daily challenges yet.", 22, { TextColor3 = U.C.muted, LayoutOrder = o })
		o += 1
	end
	header(sc, "🗓️ WEEKLY", 100)
	o = 101
	if type(p.weekly) == "table" and #p.weekly > 0 then
		for _, ch in ipairs(p.weekly) do
			challengeRow(sc, ch, o)
			o += 1
		end
	else
		U.label(sc, "No weekly challenges yet.", 22, { TextColor3 = U.C.muted, LayoutOrder = o })
	end
end

local STAT_LABEL = {
	roundsPlayed = "🎲 Rounds played",
	rounds = "🎲 Rounds played",
	secretsCompleted = "🔓 Secrets completed",
	secrets = "🔓 Secrets completed",
	wins = "🏆 Wins",
	correctAccusations = "⚖️ Correct accusations",
	accuseRight = "⚖️ Correct accusations",
	accuseWrong = "❌ Wrong accusations",
	evidenceFound = "🔍 Evidence found",
	evidence = "🔍 Evidence found",
	itemsStolen = "💎 Items stolen",
	thefts = "💎 Items stolen",
	timesCaught = "🚔 Times caught",
	detained = "🚔 Times detained",
	legendary = "🟣 Legendary secrets",
	legendaryCompleted = "🟣 Legendary secrets",
	coinsEarned = "🪙 Coins earned",
	mvp = "👑 MVPs",
}

local function renderStats(sc: ScrollingFrame)
	local p = State.profile or {}
	local card = U.frame(sc, { BackgroundColor3 = U.C.panel, Size = UDim2.new(1, -8, 0, 170), LayoutOrder = 1 })
	U.corner(card, 18)
	U.stroke(card, U.C.purple, 3)
	U.gradient(card, Color3.fromRGB(90, 60, 150), Color3.fromRGB(36, 30, 70), 0)
	local av = U.avatar(card, U.player.UserId, 130, U.C.gold)
	av.Position = UDim2.fromOffset(18, 20)
	U.label(card, U.esc(U.player.DisplayName) .. (p.vip and "  ⭐VIP" or ""), 36, {
		Position = UDim2.fromOffset(166, 20),
		Size = UDim2.new(1, -180, 0, 44),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
	})
	U.label(card, string.format("LV %s · <font color=\"#ffc83d\">%s</font>", tostring(p.level or 1), U.esc(p.title or "Rookie")), 26, {
		Position = UDim2.fromOffset(166, 66),
		Size = UDim2.new(1, -180, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local xp, nxt = tonumber(p.xp) or 0, tonumber(p.xpNext) or 0
	local bg = U.frame(card, { Position = UDim2.fromOffset(166, 110), Size = UDim2.new(1, -184, 0, 22), BackgroundColor3 = U.C.dark })
	U.round(bg)
	local fill = U.frame(bg, { Size = UDim2.fromScale(nxt > 0 and math.clamp(xp / nxt, 0, 1) or 0, 1), BackgroundColor3 = U.C.purple })
	U.round(fill)
	U.label(card, string.format("%s / %s XP   ·   🪙 %s", U.commas(xp), U.commas(nxt), U.commas(coins())), 18, {
		Position = UDim2.fromOffset(166, 136),
		Size = UDim2.new(1, -184, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = U.BOLD,
		TextColor3 = U.C.muted,
	})
	-- equipped
	if type(p.equipped) == "table" then
		local parts = {}
		for slot, id in pairs(p.equipped) do
			if id and id ~= "" then
				local e = ShopData.find(tostring(id))
				table.insert(parts, string.format("%s %s", ShopData.SLOT_ICON[slot] or "🎁", e and e.name or tostring(id)))
			end
		end
		if #parts > 0 then
			table.sort(parts)
			U.label(sc, "Wearing: " .. U.esc(table.concat(parts, "  ·  ")), 20, {
				Size = UDim2.new(1, -8, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = U.BOLD,
				LayoutOrder = 2,
			})
		end
	end
	header(sc, "📊 STATS", 3)
	local grid = U.frame(sc, { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4 })
	U.new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -6, 0, 70),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	local stats = type(p.stats) == "table" and p.stats or {}
	local keys = {}
	for k, v in pairs(stats) do
		if type(v) == "number" then
			table.insert(keys, k)
		end
	end
	table.sort(keys)
	for i, k in ipairs(keys) do
		local cell = U.frame(grid, { BackgroundColor3 = U.C.panel, LayoutOrder = i })
		U.corner(cell, 12)
		local nice = STAT_LABEL[k] or ("• " .. tostring(k):gsub("(%l)(%u)", "%1 %2"))
		U.label(cell, U.esc(nice), 18, {
			Position = UDim2.fromOffset(12, 4),
			Size = UDim2.new(1, -24, 0, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = U.BOLD,
			TextColor3 = U.C.muted,
			TextScaled = true,
		})
		U.label(cell, U.commas(stats[k]), 30, {
			Position = UDim2.fromOffset(12, 30),
			Size = UDim2.new(1, -24, 0, 36),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
	if #keys == 0 then
		U.label(grid, "Play a round to start your stats!", 22, { TextColor3 = U.C.muted })
	end
end

render = function()
	if not isOpen then
		return
	end
	local keepY = 0
	local old = body:FindFirstChild("Scroll") :: ScrollingFrame?
	if old and old:GetAttribute("Tab") == tab then
		keepY = old.CanvasPosition.Y
	end
	U.clear(body)
	local tabs = U.frame(body, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 58) })
	U.list(tabs, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center)
	for i, t in ipairs(TABS) do
		local on = tab == t[1]
		U.button(tabs, t[2], on and U.C.gold or U.C.panel2, function()
			tab = t[1]
			render()
		end, {
			Size = UDim2.new(0.25, -5, 1, 0),
			TextSize = 20,
			LayoutOrder = i,
			TextColor3 = on and U.C.dark or U.C.white,
			TextScaled = true,
		})
	end
	local sc = U.scroll(body, { Name = "Scroll", Position = UDim2.fromOffset(0, 68), Size = UDim2.new(1, 0, 1, -68) })
	sc:SetAttribute("Tab", tab)
	U.list(sc, Enum.FillDirection.Vertical, 10)
	if tab == "Cosmetics" then
		renderCosmetics(sc)
	elseif tab == "Robux" then
		renderRobux(sc)
	elseif tab == "Challenges" then
		renderChallenges(sc)
	else
		renderStats(sc)
	end
	task.defer(function()
		sc.CanvasPosition = Vector2.new(0, keepY)
	end)
end

local function close()
	if not isOpen then
		return
	end
	isOpen = false
	U.closedModal("Shop")
	U.hideWindow(back, panel)
end

function Shop.open(which: string?)
	if isOpen and not which then
		close()
		return
	end
	if which then
		tab = which
	end
	U.openModal("Shop", function()
		isOpen = false
		back.Visible = false
	end)
	isOpen = true
	render()
	U.showWindow(back, panel)
end

function Shop.init()
	gui = U.screen("EHAS_Shop", 25)
	local b, p, c, bd = U.window(gui, "🛍️ SHOP & PROFILE", 860, 920, Color3.fromRGB(240, 160, 40))
	back, panel, body = b, p, bd
	back.Activated:Connect(close)
	c.Activated:Connect(close)
	Hud.open.Shop = function()
		Shop.open(nil)
	end
	State.sig("Profile"):Connect(function()
		if isOpen then
			render()
		end
	end)
	State.sig("Phase"):Connect(function(phase)
		if phase == "Reveal" then
			close()
		end
	end)
end

return Shop
