-- Shop.luau — coin cosmetics (buy / equip, applied server-side to the character), Robux developer
-- products + game passes (ids 0 = placeholder: never prompt), idempotent ProcessReceipt, mystery crate,
-- the overhead name tag (name + title + name effect + VIP badge).
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local Bus = require(script.Parent.Bus)
local Core = require(script.Parent.Core)

local Shop = {}
Shop.RerollRefundCoins = 300 -- paid reroll that couldn't be applied -> coins instead
local Data, Progress

local function rgb(t, fallback)
	if type(t) == "table" then
		return Color3.fromRGB(t[1], t[2], t[3])
	end
	return fallback or Color3.new(1, 1, 1)
end

---------------------------------------------------------------- cosmetics on the character
local function clearSlot(char, slot)
	for _, c in ipairs(char:GetChildren()) do
		if c:GetAttribute("CosmeticSlot") == slot then
			c:Destroy()
		end
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if slot == "Trail" and root then
		for _, c in ipairs(root:GetChildren()) do
			if c:GetAttribute("CosmeticSlot") == "Trail" then
				c:Destroy()
			end
		end
	end
end

local function buildHat(char, def)
	local head = char:FindFirstChild("Head")
	if not head then
		return
	end
	local a = def.art or {}
	local c, ac = rgb(a.color), rgb(a.accent)
	local hs = head.Size
	local pieces
	local off = CFrame.new(0, hs.Y * 0.55, 0)
	local style = a.style
	if style == "tophat" then
		pieces = {
			{ size = Vector3.new(hs.X * 0.85, hs.Y * 0.9, hs.Z * 0.85), color = c },
			{ size = Vector3.new(hs.X * 1.35, 0.1, hs.Z * 1.35), color = c, offset = CFrame.new(0, -hs.Y * 0.42, 0) },
			{ size = Vector3.new(hs.X * 0.87, hs.Y * 0.14, hs.Z * 0.87), color = ac, offset = CFrame.new(0, -hs.Y * 0.28, 0) },
		}
		off = CFrame.new(0, hs.Y * 0.9, 0)
	elseif style == "fedora" or style == "cap" then
		pieces = {
			{ size = Vector3.new(hs.X * 1.05, hs.Y * 0.38, hs.Z * 1.05), color = c },
			{ size = Vector3.new(hs.X * (style == "fedora" and 1.55 or 0.95), 0.08, hs.Z * (style == "fedora" and 1.55 or 0.55)), color = c,
				offset = style == "fedora" and CFrame.new(0, -hs.Y * 0.17, 0) or CFrame.new(0, -hs.Y * 0.17, -hs.Z * 0.62) },
			{ size = Vector3.new(hs.X * 1.07, hs.Y * 0.1, hs.Z * 1.07), color = ac, offset = CFrame.new(0, -hs.Y * 0.1, 0) },
		}
	elseif style == "crown" then
		pieces = { { size = Vector3.new(hs.X * 1.0, hs.Y * 0.3, hs.Z * 1.0), color = c, material = Enum.Material.Metal } }
		for i = 0, 4 do
			local ang = i / 5 * math.pi * 2
			table.insert(pieces, { size = Vector3.new(0.18, 0.35, 0.18), color = c, material = Enum.Material.Metal, offset = CFrame.new(math.cos(ang) * hs.X * 0.42, hs.Y * 0.28, math.sin(ang) * hs.Z * 0.42) })
		end
		table.insert(pieces, { size = Vector3.new(0.2, 0.2, 0.08), color = ac, material = Enum.Material.Neon, offset = CFrame.new(0, 0, -hs.Z * 0.51) })
	elseif style == "beret" then
		pieces = { { size = Vector3.new(hs.X * 1.15, hs.Y * 0.22, hs.Z * 1.15), color = c, material = Enum.Material.Fabric, offset = nil } }
		off = CFrame.new(hs.X * 0.08, hs.Y * 0.52, 0) * CFrame.Angles(0, 0, math.rad(-10))
	elseif style == "sunhat" then
		pieces = {
			{ size = Vector3.new(hs.X * 1.0, hs.Y * 0.32, hs.Z * 1.0), color = c, material = Enum.Material.Fabric },
			{ size = Vector3.new(hs.X * 1.9, 0.08, hs.Z * 1.9), color = c, material = Enum.Material.Fabric, offset = CFrame.new(0, -hs.Y * 0.15, 0) },
			{ size = Vector3.new(hs.X * 1.02, hs.Y * 0.08, hs.Z * 1.02), color = ac, offset = CFrame.new(0, -hs.Y * 0.08, 0) },
		}
	elseif style == "halo" then
		pieces = {
			{ size = Vector3.new(hs.X * 1.1, 0.1, 0.1), color = c, material = Enum.Material.Neon },
			{ size = Vector3.new(hs.X * 1.1, 0.1, 0.1), color = c, material = Enum.Material.Neon, offset = CFrame.new(0, 0, hs.Z * 0.9) },
			{ size = Vector3.new(0.1, 0.1, hs.Z * 0.9), color = c, material = Enum.Material.Neon, offset = CFrame.new(-hs.X * 0.5, 0, hs.Z * 0.45) },
			{ size = Vector3.new(0.1, 0.1, hs.Z * 0.9), color = c, material = Enum.Material.Neon, offset = CFrame.new(hs.X * 0.5, 0, hs.Z * 0.45) },
		}
		off = CFrame.new(0, hs.Y * 0.95, -hs.Z * 0.45)
	elseif style == "chef" then
		pieces = {
			{ size = Vector3.new(hs.X * 0.95, hs.Y * 0.55, hs.Z * 0.95), color = c },
			{ size = Vector3.new(hs.X * 1.25, hs.X * 1.0, hs.Z * 1.25), color = c, offset = CFrame.new(0, hs.Y * 0.42, 0), shape = Enum.PartType.Ball },
		}
		off = CFrame.new(0, hs.Y * 0.62, 0)
	else
		pieces = { { size = Vector3.new(hs.X * 1.05, hs.Y * 0.4, hs.Z * 1.05), color = c } }
	end
	-- existing hair stays (hats sit over it)
	local acc = Core.makeAccessory("Cosmetic_" .. def.id, head, off, pieces)
	acc:SetAttribute("CosmeticSlot", "Hat")
end

local function buildMask(char, def)
	local head = char:FindFirstChild("Head")
	if not head then
		return
	end
	local a = def.art or {}
	local c, ac = rgb(a.color), rgb(a.accent)
	local hs = head.Size
	local pieces
	local off = CFrame.new(0, hs.Y * 0.1, -hs.Z * 0.52)
	if a.style == "masquerade" then
		pieces = {
			{ size = Vector3.new(hs.X * 0.9, hs.Y * 0.22, 0.08), color = c },
			{ size = Vector3.new(hs.X * 0.92, 0.05, 0.09), color = ac, offset = CFrame.new(0, hs.Y * 0.11, 0), material = Enum.Material.Metal },
		}
	elseif a.style == "bandit" then
		pieces = { { size = Vector3.new(hs.X * 1.02, hs.Y * 0.38, 0.08), color = c, material = Enum.Material.Fabric } }
		off = CFrame.new(0, -hs.Y * 0.22, -hs.Z * 0.5)
	elseif a.style == "monocle" then
		pieces = {
			{ size = Vector3.new(0.05, hs.Y * 0.3, hs.Y * 0.3), color = ac, shape = Enum.PartType.Cylinder, material = Enum.Material.Glass },
			{ size = Vector3.new(0.04, 0.5, 0.04), color = c, offset = CFrame.new(0, -0.3, 0), material = Enum.Material.Metal },
		}
		off = CFrame.new(hs.X * 0.2, hs.Y * 0.1, -hs.Z * 0.52) * CFrame.Angles(0, math.rad(90), 0)
	else -- mustache
		pieces = {
			{ size = Vector3.new(hs.X * 0.25, hs.Y * 0.09, 0.08), color = c, offset = nil },
			{ size = Vector3.new(hs.X * 0.25, hs.Y * 0.09, 0.08), color = c, offset = CFrame.new(-hs.X * 0.22, -0.03, 0) * CFrame.Angles(0, 0, math.rad(12)) },
			{ size = Vector3.new(hs.X * 0.25, hs.Y * 0.09, 0.08), color = c, offset = CFrame.new(hs.X * 0.22, -0.03, 0) * CFrame.Angles(0, 0, math.rad(-12)) },
		}
		off = CFrame.new(0, -hs.Y * 0.15, -hs.Z * 0.52)
	end
	local acc = Core.makeAccessory("Cosmetic_" .. def.id, head, off, pieces)
	acc:SetAttribute("CosmeticSlot", "Mask")
end

local function buildTrail(char, def)
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local a = def.art or {}
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailA0"
	a0.Position = Vector3.new(0, 0.9, 0.4)
	a0:SetAttribute("CosmeticSlot", "Trail")
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailA1"
	a1.Position = Vector3.new(0, -1.4, 0.4)
	a1:SetAttribute("CosmeticSlot", "Trail")
	a1.Parent = root
	local tr = Instance.new("Trail")
	tr.Name = "CosmeticTrail"
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Lifetime = 0.6
	tr.MinLength = 0.1
	tr.LightEmission = 0.6
	tr.FaceCamera = true
	tr.Color = ColorSequence.new(rgb(a.c0), rgb(a.c1))
	tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	tr:SetAttribute("CosmeticSlot", "Trail")
	tr.Parent = root
end

-- overhead tag: name + title; colors from NameFx; VIP badge
function Shop.applyTag(player)
	local char = player.Character
	local prof = Data and Data.get(player)
	local head = char and char:FindFirstChild("Head")
	if not head or not prof then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local bb = head:FindFirstChild("EHAS_Tag")
	if not bb then
		bb = Instance.new("BillboardGui")
		bb.Name = "EHAS_Tag"
		bb.Size = UDim2.fromScale(6, 1.6)
		bb.StudsOffset = Vector3.new(0, 2.4, 0)
		bb.AlwaysOnTop = false
		bb.MaxDistance = 70
		bb.LightInfluence = 0
		bb.Parent = head
		local name = Instance.new("TextLabel")
		name.Name = "NameLabel"
		name.BackgroundTransparency = 1
		name.Size = UDim2.fromScale(1, 0.6)
		name.Font = Enum.Font.GothamBold
		name.TextScaled = true
		name.Parent = bb
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = name
		local title = Instance.new("TextLabel")
		title.Name = "TitleLabel"
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromScale(0, 0.6)
		title.Size = UDim2.fromScale(1, 0.4)
		title.Font = Enum.Font.GothamBold
		title.TextScaled = true
		title.TextColor3 = Color3.fromRGB(255, 230, 150)
		title.Parent = bb
		local ts = Instance.new("UIStroke")
		ts.Thickness = 1.5
		ts.Parent = title
		-- disguise hides the tag
		char:GetAttributeChangedSignal("Disguised"):Connect(function()
			bb.Enabled = not char:GetAttribute("Disguised")
		end)
	end
	local nameL, titleL = bb:FindFirstChild("NameLabel"), bb:FindFirstChild("TitleLabel")
	local fx = prof.equipped.NameFx and ShopConfig.byId[prof.equipped.NameFx]
	nameL.Text = (prof.passes.VIP and "👑 " or "") .. (player.DisplayName ~= "" and player.DisplayName or player.Name)
	nameL.TextColor3 = fx and rgb(fx.art and fx.art.color) or Color3.new(1, 1, 1)
	nameL.UIStroke.Color = fx and rgb(fx.art and fx.art.stroke, Color3.new(0, 0, 0)) or Color3.fromRGB(30, 30, 40)
	local tdef = prof.equipped.Title and ShopConfig.byId[prof.equipped.Title]
	titleL.Text = tdef and tdef.name or ("Lv " .. prof.level .. " " .. Config.titleForLevel(prof.level))
end

function Shop.applyCosmetics(player)
	local char = player.Character
	local prof = Data and Data.get(player)
	if not char or not prof then
		return
	end
	for _, slot in ipairs({ "Hat", "Trail", "Mask" }) do
		clearSlot(char, slot)
		local id = prof.equipped[slot]
		local def = id and ShopConfig.byId[id]
		if def and prof.owned[id] then
			local ok, err = pcall(function()
				if slot == "Hat" then
					buildHat(char, def)
				elseif slot == "Mask" then
					buildMask(char, def)
				else
					buildTrail(char, def)
				end
			end)
			if not ok then
				warn("[Shop] cosmetic " .. id .. ": " .. tostring(err))
			end
		end
	end
	Shop.applyTag(player)
end

---------------------------------------------------------------- coin purchases / equip
function Shop.owns(prof, id)
	local def = ShopConfig.byId[id]
	if not def then
		return false
	end
	if def.vip then
		return prof.passes.VIP == true
	end
	return prof.owned[id] == true or def.default == true
end

-- returns ok, reason
function Shop.buyCosmetic(player, id)
	local prof = Data.get(player)
	local def = ShopConfig.byId[id]
	if not prof or not def then
		return false, "unknown"
	end
	if Shop.owns(prof, id) then
		return false, "owned"
	end
	if def.vip or def.reward or (def.price or 0) <= 0 then
		return false, "not for sale"
	end
	if def.minLevel and prof.level < def.minLevel then
		Core.toast(Core.byPlayer[player], ("Requires level %d."):format(def.minLevel), "bad", "Locked")
		return false, "level"
	end
	if prof.coins < def.price then
		Core.toast(Core.byPlayer[player], ("Not enough coins (%d needed)."):format(def.price), "bad", "Locked")
		return false, "coins"
	end
	prof.coins -= def.price
	prof.owned[id] = true
	prof.dirty = true
	if Core.M.Analytics then
		pcall(Core.M.Analytics.shopBuy, player, id, def.price)
	end
	Data.refreshLeaderstats(player)
	Core.toast(Core.byPlayer[player], ("🛍️ Bought %s!"):format(def.name), "good", "CoinGet")
	Progress.sendProfile(player)
	return true
end

function Shop.equip(player, slot, id)
	local prof = Data.get(player)
	if not prof or not table.find(ShopConfig.Slots, slot) then
		return false
	end
	if id == nil or id == "" or id == false then
		prof.equipped[slot] = nil
	else
		local def = ShopConfig.byId[id]
		if not def or def.slot ~= slot or not Shop.owns(prof, id) then
			return false
		end
		prof.equipped[slot] = id
	end
	prof.dirty = true
	Shop.applyCosmetics(player)
	Progress.sendProfile(player)
	return true
end

---------------------------------------------------------------- Robux
-- returns how many were already owned (refunded as coins, like crate duplicates)
local function grantCosmetics(prof, list)
	local dups = 0
	for _, id in ipairs(list or {}) do
		if prof.owned[id] then
			dups += 1
			prof.coins += ShopConfig.CrateDuplicateCoins
		else
			prof.owned[id] = true
		end
	end
	return dups
end

function Shop.rollCrate(prof, rng)
	rng = rng or Core.rng
	local r = rng:NextNumber() * 100
	local rarity = "Common"
	for _, e in ipairs(ShopConfig.CrateOdds) do
		r -= e.pct
		if r <= 0 then
			rarity = e.rarity
			break
		end
	end
	local pool = {}
	for _, c in ipairs(ShopConfig.Cosmetics) do
		if c.rarity == rarity and not c.vip and not c.default then
			table.insert(pool, c)
		end
	end
	if #pool == 0 then
		for _, c in ipairs(ShopConfig.Cosmetics) do
			if not c.vip and not c.default then
				table.insert(pool, c)
			end
		end
	end
	local c = pool[rng:NextInteger(1, #pool)]
	if prof.owned[c.id] then
		prof.coins += ShopConfig.CrateDuplicateCoins
		return c, true
	end
	prof.owned[c.id] = true
	return c, false
end

-- apply a product grant (no receipt bookkeeping); returns true if granted
function Shop.grantProduct(player, key)
	local prof = Data.get(player)
	local def = ShopConfig.Products[key]
	if not prof or not def then
		return false
	end
	local p = Core.byPlayer[player]
	if key == "SecretReroll" then
		local Secrets = Core.M.Secrets
		local slot = (Secrets and p and Secrets.pendingReroll[p.id]) or "main"
		local done = false
		if Secrets and p and (Core.phase == "Intro" or Core.phase == "Play") then
			Secrets.pendingReroll[p.id] = nil
			done = Secrets.reroll(p, slot) == true
		end
		if not done then
			-- never take Robux for nothing: compensate with coins when the reroll can't happen
			prof.coins += Shop.RerollRefundCoins
			Core.toast(p, ("🎲 Reroll not possible right now — you got %d 🪙 instead."):format(Shop.RerollRefundCoins), "good", "CoinGet")
		end
	elseif def.crate then
		local c, dup = Shop.rollCrate(prof)
		Core.toast(p, dup and ("📦 Duplicate %s → +%d coins"):format(c.name, ShopConfig.CrateDuplicateCoins) or ("📦 You unboxed: %s (%s)!"):format(c.name, c.rarity), "good", "Jackpot")
	else
		if def.once then
			prof.products[key] = true
		end
		if def.coins then
			prof.coins += def.coins
		end
		local dups = grantCosmetics(prof, def.grant)
		if dups > 0 then
			Core.toast(p, ("%d item(s) already owned → +%d coins"):format(dups, dups * ShopConfig.CrateDuplicateCoins), "good", "CoinGet")
		end
		if def.xpBoostMinutes then
			prof.xpBoostUntil = math.max(prof.xpBoostUntil or 0, os.time()) + def.xpBoostMinutes * 60
		end
		Core.toast(p, ("🎁 %s unlocked!"):format(def.name), "good", "Complete")
	end
	prof.dirty = true
	Data.refreshLeaderstats(player)
	Progress.sendProfile(player)
	return true
end

local function productKeyFor(productId)
	for key, def in pairs(ShopConfig.Products) do
		if def.ProductId == productId and productId ~= 0 then
			return key
		end
	end
	return nil
end

function Shop.processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local prof = Data.get(player)
	if not prof then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if prof.purchases[info.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted (idempotent)
	end
	local key = productKeyFor(info.ProductId)
	if not key then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- save didn't load: a grant would only live in memory and be lost on leave. Roblox re-delivers
	-- the receipt next session once the save loads. (The reroll is used right now, so it's granted.)
	if not prof.canSave and key ~= "SecretReroll" then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok = pcall(Shop.grantProduct, player, key)
	if not ok then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	prof.purchases[info.PurchaseId] = true
	table.insert(prof.purchaseOrder, info.PurchaseId)
	while #prof.purchaseOrder > 200 do
		local old = table.remove(prof.purchaseOrder, 1)
		prof.purchases[old] = nil
	end
	-- persist the receipt before telling Roblox it's granted (if saving works)
	if prof.canSave then
		if not Data.save(player, prof) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function Shop.refreshPasses(player)
	local prof = Data.get(player)
	if not prof then
		return
	end
	for key, def in pairs(ShopConfig.Passes) do
		if def.PassId and def.PassId > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, def.PassId)
			end)
			if ok then
				prof.passes[key] = owns or nil
			end
		end
	end
	Shop.applyTag(player)
	Progress.sendProfile(player)
end

function Shop.prompt(player, id)
	local prod = ShopConfig.Products[id]
	if prod then
		if (prod.ProductId or 0) <= 0 then
			Core.toast(Core.byPlayer[player], "This item isn't on sale yet.", "info")
			return false
		end
		local prof = Data.get(player)
		if not prof or (prof.loadFailed and id ~= "SecretReroll") then
			Core.toast(Core.byPlayer[player], "Shop unavailable — your save didn't load. Please rejoin.", "bad")
			return false
		end
		if prod.once and prof and prof.products[id] then
			Core.toast(Core.byPlayer[player], "You already own the Starter Pack.", "info")
			return false
		end
		pcall(function()
			MarketplaceService:PromptProductPurchase(player, prod.ProductId)
		end)
		return true
	end
	local pass = ShopConfig.Passes[id]
	if pass then
		if (pass.PassId or 0) <= 0 then
			Core.toast(Core.byPlayer[player], "This pass isn't on sale yet.", "info")
			return false
		end
		pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, pass.PassId)
		end)
		return true
	end
	return false
end

---------------------------------------------------------------- init
function Shop.init()
	Data, Progress = Core.M.Data, Core.M.Progress
	MarketplaceService.ProcessReceipt = Shop.processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			for key, def in pairs(ShopConfig.Passes) do
				if def.PassId == passId and passId > 0 then
					local prof = Data.get(player)
					if prof then
						prof.passes[key] = true
						prof.dirty = true
						Core.toast(Core.byPlayer[player], ("⭐ %s pass active!"):format(def.name), "good", "Complete")
						Shop.applyTag(player)
						Progress.sendProfile(player)
					end
				end
			end
		end
	end)
	Bus.on("ProfileLoaded", function(player)
		task.spawn(Shop.refreshPasses, player)
		if player.Character then
			Shop.applyCosmetics(player)
		end
	end)
	Bus.on("ProfileChanged", function(player)
		local char = player.Character
		if char then
			pcall(Shop.applyTag, player)
		end
	end)
	Core.onAction("Buy", function(player, args)
		local id = Core.vStr(args.id, 40)
		if not id then
			return
		end
		if ShopConfig.byId[id] then
			Shop.buyCosmetic(player, id)
		else
			Shop.prompt(player, id)
		end
	end)
	Core.onAction("Equip", function(player, args)
		local slot = Core.vStr(args.slot, 12)
		local id = args.id
		if slot and (id == nil or id == "" or Core.vStr(id, 40)) then
			Shop.equip(player, slot, id)
		end
	end)
end

return Shop
