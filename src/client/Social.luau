-- Social.luau: incoming Request popup (Accept/Decline -> Respond, auto-decline after 20 s) and the Social menu:
-- pick a nearby guest (within 20 studs, players + bots) -> Team Up / Ask to Follow / Trade / Give coins.
local Players = game:GetService("Players")

local U = require(script.Parent.Util)
local State = require(script.Parent.State)
local Hud = require(script.Parent.Hud)

local Social = {}

local NEAR = 20
local KIND_TEXT = {
	TeamUp = { "🤝", "wants to TEAM UP", Color3.fromRGB(80, 200, 120) },
	Follow = { "👣", "asks you to FOLLOW them", Color3.fromRGB(80, 170, 255) },
	Trade = { "🔁", "wants to TRADE", Color3.fromRGB(255, 170, 60) },
	Give = { "🎁", "wants to GIVE you something", Color3.fromRGB(255, 120, 210) },
}

local gui: ScreenGui
local reqHolder: Frame
local sBack: TextButton
local sPanel: Frame
local sBody: Frame
local sOpen = false
local selected: any = nil

-------------------------------------------------------------------------------- incoming requests
local function requestPopup(p: any)
	local k = KIND_TEXT[p.kind] or { "💬", "sent you a request", U.C.social }
	local card = U.frame(reqHolder, {
		Name = "Req",
		Size = UDim2.new(1, 0, 0, 200),
		BackgroundColor3 = U.C.bg,
		LayoutOrder = math.floor(os.clock() * 10) % 1e8,
	})
	U.corner(card, 18)
	U.stroke(card, k[3], 4)
	local av = U.avatar(card, tonumber(p.fromUserId) or -1, 70, k[3])
	av.Position = UDim2.fromOffset(12, 12)
	U.label(card, string.format("%s <b>%s</b> %s", k[1], U.esc(p.fromName or U.nameOf(p.fromUserId)), k[2]), 24, {
		Position = UDim2.fromOffset(92, 10),
		Size = UDim2.new(1, -102, 0, 60),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = true,
	})
	if type(p.detail) == "string" and p.detail ~= "" then
		U.label(card, U.esc(p.detail), 20, {
			Position = UDim2.fromOffset(92, 70),
			Size = UDim2.new(1, -102, 0, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = U.BOLD,
			TextColor3 = U.C.muted,
			TextScaled = true,
		})
	end
	local timeBar = U.frame(card, {
		Position = UDim2.new(0, 12, 0, 104),
		Size = UDim2.new(1, -24, 0, 6),
		BackgroundColor3 = k[3],
	})
	U.round(timeBar)
	local answered = false
	local function answer(accept: boolean)
		if answered then
			return
		end
		answered = true
		U.fire("Respond", { requestId = p.requestId, accept = accept })
		U.tween(card, 0.2, { BackgroundTransparency = 1 })
		U.popOut(card, function()
			card:Destroy()
		end)
	end
	U.button(card, "✅ ACCEPT", U.C.good, function()
		answer(true)
	end, {
		Position = UDim2.new(0, 12, 1, -82),
		Size = UDim2.new(0.5, -18, 0, 70),
		TextSize = 28,
	})
	U.button(card, "❌ NO", U.C.bad, function()
		answer(false)
	end, {
		Position = UDim2.new(0.5, 6, 1, -82),
		Size = UDim2.new(0.5, -18, 0, 70),
		TextSize = 28,
	})
	U.popIn(card, 0.5)
	U.sfx("Click")
	U.tween(timeBar, 20, { Size = UDim2.new(0, 0, 0, 6) }, Enum.EasingStyle.Linear)
	task.delay(20, function()
		if not answered and card.Parent then
			answer(false)
		end
	end)
	-- max 2 visible
	local cards = {}
	for _, c in ipairs(reqHolder:GetChildren()) do
		if c:IsA("Frame") then
			table.insert(cards, c)
		end
	end
	if #cards > 2 then
		table.sort(cards, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		cards[1]:Destroy()
	end
end

-------------------------------------------------------------------------------- social menu
local function nearby(): { any }
	local me = U.hrp()
	local out = {}
	if not me then
		return out
	end
	for _, p in ipairs(U.participants(false)) do
		local ch = U.charOf(p.id)
		local root = ch and (ch:FindFirstChild("HumanoidRootPart") or ch.PrimaryPart) :: BasePart?
		if root then
			local d = (root.Position - me.Position).Magnitude
			if d <= NEAR then
				p.dist = d
				table.insert(out, p)
			end
		end
	end
	table.sort(out, function(a, b)
		return a.dist < b.dist
	end)
	return out
end

local renderSocial: () -> ()

local function closeSocial()
	if not sOpen then
		return
	end
	sOpen = false
	U.closedModal("Social")
	U.hideWindow(sBack, sPanel)
end

renderSocial = function()
	U.clear(sBody)
	U.list(sBody, Enum.FillDirection.Vertical, 10)
	if not selected then
		U.label(sBody, "Guests near you (" .. NEAR .. " studs)", 26, { Size = UDim2.new(1, 0, 0, 34), TextColor3 = U.C.gold, LayoutOrder = 1 })
		local sc = U.scroll(sBody, { Size = UDim2.new(1, 0, 1, -110), LayoutOrder = 2 })
		U.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(150, 170),
			CellPadding = UDim2.fromOffset(10, 10),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = sc,
		})
		local list = nearby()
		for i, p in ipairs(list) do
			local cell = U.new("TextButton", { Text = "", BackgroundColor3 = U.C.panel, LayoutOrder = i, Parent = sc })
			U.corner(cell, 14)
			U.stroke(cell, State.allies[p.id] and U.C.good or U.C.line, 2)
			local av = U.avatar(cell, p.id, 90, State.allies[p.id] and U.C.good or U.C.white)
			av.AnchorPoint = Vector2.new(0.5, 0)
			av.Position = UDim2.new(0.5, 0, 0, 10)
			U.label(cell, U.esc(p.name), 20, { Position = UDim2.fromOffset(4, 106), Size = UDim2.new(1, -8, 0, 28), TextScaled = true, Font = U.BOLD })
			U.label(cell, string.format("%s%d studs", State.allies[p.id] and "🤝 " or "", math.floor(p.dist)), 16, {
				Position = UDim2.fromOffset(4, 136),
				Size = UDim2.new(1, -8, 0, 22),
				TextColor3 = U.C.muted,
				Font = U.BOLD,
			})
			cell.Activated:Connect(function()
				U.sfx("Click", nil, 0.6)
				selected = p
				renderSocial()
			end)
		end
		if #list == 0 then
			U.label(sc, "Nobody close by.\nWalk up to another guest and try again! 🚶", 26, { Size = UDim2.new(1, 0, 0, 120), TextColor3 = U.C.muted })
		end
		U.button(sBody, "🔄 REFRESH", U.C.panel2, renderSocial, { Size = UDim2.new(1, 0, 0, 56), LayoutOrder = 3, TextSize = 24 })
		return
	end
	local p = selected
	local head = U.frame(sBody, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 100), LayoutOrder = 1 })
	local av = U.avatar(head, p.id, 90, U.C.social)
	av.Position = UDim2.fromOffset(0, 5)
	U.label(head, U.esc(p.name), 34, {
		Position = UDim2.fromOffset(104, 10),
		Size = UDim2.new(1, -104, 0, 44),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	U.label(head, State.allies[p.id] and "🤝 Your ally" or (p.isBot and "Resort guest" or "Player"), 20, {
		Position = UDim2.fromOffset(104, 56),
		Size = UDim2.new(1, -104, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = U.C.muted,
		Font = U.BOLD,
	})
	local function req(kind: string, detail: string?)
		U.fire("SocialRequest", { targetId = p.id, kind = kind, detail = detail })
		closeSocial()
	end
	local acts = {
		{ "🤝 TEAM UP", "TeamUp", Color3.fromRGB(70, 180, 110) },
		{ "👣 ASK TO FOLLOW ME", "Follow", Color3.fromRGB(60, 140, 220) },
		{ "🔁 OFFER A TRADE", "Trade", Color3.fromRGB(230, 150, 40) },
	}
	for i, a in ipairs(acts) do
		U.button(sBody, a[1], a[3], function()
			local detail = nil
			if a[2] == "Trade" then
				local t = U.heldTool()
				detail = t and ("Offers: " .. t.Name) or nil
			end
			req(a[2], detail)
		end, { Size = UDim2.new(1, 0, 0, 70), LayoutOrder = 1 + i })
	end
	U.label(sBody, "🎁 GIVE COINS", 24, { Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 10, TextColor3 = U.C.gold })
	local row = U.frame(sBody, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 70), LayoutOrder = 11 })
	U.list(row, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	for _, amt in ipairs({ 10, 25, 50, 100 }) do
		U.button(row, "🪙" .. amt, Color3.fromRGB(200, 150, 30), function()
			U.fire("GiveCoins", { targetId = p.id, amount = amt })
			closeSocial()
		end, { Size = UDim2.new(0.25, -6, 1, 0), TextSize = 26 })
	end
	U.button(sBody, "◀ BACK", U.C.panel2, function()
		selected = nil
		renderSocial()
	end, { Size = UDim2.new(1, 0, 0, 56), LayoutOrder = 20, TextSize = 24 })
end

function Social.open(target: any?)
	if sOpen and not target then
		closeSocial()
		return
	end
	U.openModal("Social", function()
		sOpen = false
		sBack.Visible = false
	end)
	sOpen = true
	selected = target
	renderSocial()
	U.showWindow(sBack, sPanel)
end

function Social.init()
	gui = U.screen("EHAS_Social", 26)
	reqHolder = U.frame(gui, {
		Name = "Requests",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 360),
		Size = UDim2.fromOffset(520, 420),
	})
	U.list(reqHolder, Enum.FillDirection.Vertical, 10)
	local function layout()
		local vp = U.viewport()
		local k = math.max(U.scale, 0.01)
		-- right of center so it never sits under the thumbstick; well below toasts
		reqHolder.Size = UDim2.fromOffset(math.min(520, vp.X * 0.55 / k), 420)
		reqHolder.Position = UDim2.new(0.5, 0, 0, 300)
	end
	U.scaleChanged:Connect(layout)
	layout()

	local b, p, c, body = U.window(gui, "🤝 SOCIAL", 640, 860, U.C.social)
	sBack, sPanel, sBody = b, p, body
	sBack.Activated:Connect(closeSocial)
	c.Activated:Connect(closeSocial)
	Hud.open.Social = function()
		Social.open(nil)
	end

	State.sig("Request"):Connect(requestPopup)
	State.sig("Allies"):Connect(function()
		if sOpen then
			renderSocial()
		end
	end)
	State.sig("Phase"):Connect(function(phase)
		if phase == "Reveal" then
			closeSocial()
			for _, ch in ipairs(reqHolder:GetChildren()) do
				if ch:IsA("Frame") then
					ch:Destroy()
				end
			end
		end
	end)
	local _ = Players
end

return Social
