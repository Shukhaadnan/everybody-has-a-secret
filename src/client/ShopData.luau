-- ShopData.luau: defensive reader for ReplicatedStorage.ShopConfig (SERVER owns its exact shape).
-- Walks the config and normalizes anything item-like into:
--   cosmetics: {id, name, price, slot, icon, desc, rarity}
--   robux:     {id, name, robux, productId, passId, icon, desc}
-- Items with ProductId/PassId == 0 are kept in `robuxAll` but excluded from `robux` (button hidden).
local U = require(script.Parent.Util)

local ShopData = {}

local SLOT_FROM_KEY = {
	hats = "Hat", hat = "Hat",
	trails = "Trail", trail = "Trail",
	titles = "Title", title = "Title",
	namefx = "NameFx", nameeffects = "NameFx", nameeffect = "NameFx", names = "NameFx",
	masks = "Mask", mask = "Mask",
	emotes = "Emote", victoryemotes = "Emote", emote = "Emote", victory = "Emote",
}
local SLOT_ICON = { Hat = "🎩", Trail = "✨", Title = "🏷️", NameFx = "🌈", Mask = "🎭", Emote = "💃", Victory = "💃" }

local function field(t: any, ...: string): any
	for _, k in ipairs({ ... }) do
		local v = t[k]
		if v ~= nil then
			return v
		end
	end
	return nil
end

local cache: any = nil

function ShopData.get(): any
	if cache then
		return cache
	end
	local cfg = U.mod("ShopConfig", 5)
	local out = { cosmetics = {}, robux = {}, robuxAll = {}, byId = {}, crateOdds = nil }
	if type(cfg) ~= "table" then
		return out
	end
	local seen: { [any]: boolean } = {}

	local function visit(t: any, key: any, parentSlot: string?, depth: number)
		if type(t) ~= "table" or seen[t] or depth > 5 then
			return
		end
		seen[t] = true
		local name = field(t, "name", "Name", "displayName", "DisplayName", "title", "Title")
		local productId = field(t, "ProductId", "productId", "productID", "DevProductId")
		local passId = field(t, "PassId", "passId", "GamePassId", "gamePassId")
		local coinPrice = field(t, "price", "Price", "cost", "Cost", "coins", "Coins", "coinPrice", "CoinPrice")
		local isItem = type(name) == "string" and (productId ~= nil or passId ~= nil or type(coinPrice) == "number")
		if isItem then
			local id = field(t, "id", "Id", "ID", "key")
			if type(id) ~= "string" and type(id) ~= "number" then
				id = key
			end
			id = tostring(id)
			if productId ~= nil or passId ~= nil then
				local e = {
					id = id,
					name = name,
					robux = tonumber(field(t, "robux", "Robux", "RobuxPrice", "robuxPrice", "R", "price", "Price")) or 0,
					productId = tonumber(productId) or 0,
					passId = tonumber(passId) or 0,
					icon = tostring(field(t, "icon", "Icon", "emoji") or "💎"),
					desc = tostring(field(t, "desc", "Desc", "description", "Description") or ""),
					raw = t,
				}
				table.insert(out.robuxAll, e)
				if e.productId ~= 0 or e.passId ~= 0 then
					table.insert(out.robux, e)
				end
				out.byId[id] = e
			else
				-- an explicit slot on the item is kept verbatim (server Equip expects its own slot names)
				local explicit = field(t, "slot", "Slot", "category", "Category")
				local slot = (type(explicit) == "string" and explicit) or parentSlot or "Hat"
				local e = {
					id = id,
					name = name,
					price = tonumber(coinPrice) or 0,
					slot = slot,
					icon = tostring(field(t, "icon", "Icon", "emoji") or SLOT_ICON[slot] or "🎁"),
					desc = tostring(field(t, "desc", "Desc", "description", "Description") or ""),
					rarity = field(t, "rarity", "Rarity", "tier", "Tier"),
					levelReq = tonumber(field(t, "minLevel", "levelReq", "MinLevel", "level", "Level")),
					rewardOnly = t.reward == true,
					vipOnly = t.vip == true,
					isDefault = t.default == true,
					raw = t,
				}
				table.insert(out.cosmetics, e)
				out.byId[id] = e
			end
			return
		end
		local slotHere = parentSlot
		if type(key) == "string" and SLOT_FROM_KEY[string.lower(key)] then
			slotHere = SLOT_FROM_KEY[string.lower(key)]
		end
		-- deterministic order: array part first, then sorted string keys
		local keys = {}
		for k in pairs(t) do
			table.insert(keys, k)
		end
		table.sort(keys, function(a, b)
			local ta, tb = type(a), type(b)
			if ta ~= tb then
				return ta == "number"
			end
			if ta == "number" or ta == "string" then
				return a < b
			end
			return false
		end)
		for _, k in ipairs(keys) do
			local v = t[k]
			if type(v) == "table" then
				local lk = type(k) == "string" and string.lower(k) or ""
				if lk == "odds" or lk == "crateodds" then
					out.crateOdds = v
				end
				visit(v, k, slotHere, depth + 1)
			end
		end
	end

	local ok, err = pcall(visit, cfg, "root", nil, 0)
	if not ok then
		warn("[EHAS client] ShopConfig parse: " .. tostring(err))
	end
	table.sort(out.cosmetics, function(a, b)
		if a.slot ~= b.slot then
			return a.slot < b.slot
		end
		return a.price < b.price
	end)
	cache = out
	return out
end

function ShopData.find(id: string): any
	return ShopData.get().byId[id]
end

-- The reroll product, if one with a real id exists.
function ShopData.rerollProduct(): any
	local d = ShopData.get()
	for _, e in ipairs(d.robux) do
		local l = string.lower(e.id .. " " .. e.name)
		if string.find(l, "reroll", 1, true) then
			return e
		end
	end
	return nil
end

ShopData.SLOT_ICON = SLOT_ICON
return ShopData
