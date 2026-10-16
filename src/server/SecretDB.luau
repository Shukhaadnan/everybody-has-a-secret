-- SecretDB.luau — PURE Luau (no Instances / Roblox APIs). Objective templates + connected story-chain
-- generator. Server-verifiable condition types are documented below; Secrets.luau verifies them.
--
-- SecretDB.generate(participants, zones, rng, recent) -> result
--   participants = { {id=number, name=string, isBot=bool?}, ... }   (1..24, ids unique, bots negative)
--   zones        = Zones module shape {list={{id,name,outdoor,restricted}}, byId}  (nil -> built-in fallback)
--                  optional extras: zones.hideZones = {zoneId...} (zones that contain Hide/Dig spots)
--   rng          = function(a?, b?) : integer in [a,b] when given, else float [0,1)
--   recent       = { [id] = {objectiveId...} } recently used objective ids per participant (may be nil)
-- result = {
--   assignments = { [id] = { main=Obj, side=Obj, role=string, chain=string? } },
--   chains = { {id=string, title=string, roles={ {pid=, key=, role=, slot=} } } },
--   forcedEvents = { eventId... },     -- events a chosen chain needs (BoatArrival, VIPArrival...)
--   recent = updated recent table (new table, last SecretDB.RECENT_KEEP ids per participant)
-- }
-- Obj = { id, tier, text, short (<= 50 chars headline), steps={string} (one per cond), conds={cond...}, step=1, progress={cur,max}?, done=false, failed=false,
--         hintZone=string?, role=string, slot="main"|"side", chain=string?, target=id?, startItems={itemId}? }
--
-- Condition types (cond.t):
--   zone{zone}                      enter zone
--   zones{zones,max}                visit every listed zone (progress)
--   itemAtZone{item,zone}           be inside zone while carrying item
--   steal{item?}                    take an item from a Pedestal / the VIP / another player (hot item)
--   getItem{item}                   obtain item any way (search, shop, trade, steal)
--   hide{item?,zone?}               hide a carried item in a Hide spot (or bury at a Dig spot) [in zone]
--   dig{count}                      dig / bury at beach dig spots
--   pedestalEnd{item}         END   item is on its pedestal when the round ends
--   interact{kind,zone?,count}      use Interact parts of Kind (Slot, Cards, Food, Search, Shop, Note, Phone...)
--   talk{count,target?}             be within 8 studs of N distinct participants for 3 s each (or the target)
--   follow{target,seconds}          stay 10-40 studs from target for N s (spotted -> lose progress)
--   giveCoins{amount,target?}       give coins (to target)
--   getCoins{amount}                receive coins from other participants
--   giveItem{item?,target?}         hand an item to (target) via a Give request
--   receiveItem{item?}              receive an item from another participant
--   makeEnter{zone,count,target?}   distinct others (or target) enter zone within 90 s after you talked to them
--   accuse{item?}                   make a CORRECT accusation (for the incident about item)
--   convinceAccuse{target,accused?} target makes a wrong accusation (or one naming `accused`)
--   photo{item?,target?,zone?}      photograph someone carrying item / the target / anyone in zone
--   deleteFootage{count}            delete security footage
--   disableCam{count}               disable cameras
--   trigger{event}                  trigger PowerOutage (PowerBox) / SecurityLockdown (Alarm) / Prank (Phone)
--   never{zones}              END   never enter any of the zones (fails on entry)
--   notDetained{}             END   never get detained (fails on detention)
--   detained{}                      get detained by security
--   escape{item?}                   leave on the boat (Boat interact) while carrying item
--   ally{target}                    team up with target (TeamUp request accepted either way)
--   protect{target}           END   target never gets detained
--   eventZone{zone,event}           be in zone while the event is active
--   frame{target}                   plant evidence that names target as a suspect
--   bribe{}                         bribe a witness NPC
--   winCoins{amount}                win coins at the casino (slots / cards)
--   buy{shop?}                      buy something at a shop counter
--   notAccused{}              END   nobody accuses you all round
local SecretDB = {}

SecretDB.RECENT_KEEP = 10
SecretDB.END_CONDS = { pedestalEnd = true, never = true, notDetained = true, protect = true, notAccused = true }

---------------------------------------------------------------- static data
SecretDB.ZONE_IDS = {
	"Plaza", "Lobby", "Reception", "GuestRooms", "Balcony", "Rooftop", "HotelBar", "Restaurant", "PrivateDining",
	"Kitchen", "Housekeeping", "SecurityRoom", "Detention", "Casino", "CasinoVIP", "CasinoBackRoom", "Pool",
	"ChangingRooms", "PoolBar", "Beach", "Dock", "BeachShop", "ShopStreet", "JewelryShop", "Underground",
	"ElectricalRoom", "HiddenRoom",
}
local FALLBACK_NAMES = {
	Plaza = "Plaza", Lobby = "Hotel Lobby", Reception = "Reception", GuestRooms = "Guest Rooms", Balcony = "Balcony",
	Rooftop = "Rooftop", HotelBar = "Hotel Bar", Restaurant = "Restaurant", PrivateDining = "Private Dining",
	Kitchen = "Kitchen", Housekeeping = "Housekeeping", SecurityRoom = "Security Room", Detention = "Detention",
	Casino = "Arcade", CasinoVIP = "Arcade VIP Room", CasinoBackRoom = "Arcade Back Room", Pool = "Pool",
	ChangingRooms = "Changing Rooms", PoolBar = "Pool Bar", Beach = "Beach", Dock = "Dock", BeachShop = "Beach Shop",
	ShopStreet = "Shop Street", JewelryShop = "Jewelry Shop", Underground = "Underground Tunnels",
	ElectricalRoom = "Electrical Room", HiddenRoom = "Hidden Room",
}
-- plain short zone names for headlines (players read these on a phone in one glance)
local SHORT_ZONE = {
	Plaza = "Plaza", Lobby = "Lobby", Reception = "Reception", GuestRooms = "Guest Rooms", Balcony = "Balcony",
	Rooftop = "Rooftop", HotelBar = "Bar", Restaurant = "Restaurant", PrivateDining = "Private Dining",
	Kitchen = "Kitchen", Housekeeping = "Housekeeping", SecurityRoom = "Security Room", Detention = "Jail",
	Casino = "Arcade", CasinoVIP = "VIP Room", CasinoBackRoom = "Back Room", Pool = "Pool",
	ChangingRooms = "Changing Rooms", PoolBar = "Pool Bar", Beach = "Beach", Dock = "Dock", BeachShop = "Surf Shop",
	ShopStreet = "Shop Street", JewelryShop = "Jewelry Shop", Underground = "Tunnels",
	ElectricalRoom = "Electrical Room", HiddenRoom = "Hidden Room",
}
SecretDB.SHORT_ZONE = SHORT_ZONE
local FALLBACK_RESTRICTED = {
	Reception = true, PrivateDining = true, Housekeeping = true, SecurityRoom = true, CasinoVIP = true,
	CasinoBackRoom = true, ElectricalRoom = true, HiddenRoom = true,
}
local FALLBACK_OUTDOOR = { Plaza = true, Balcony = true, Rooftop = true, Pool = true, PoolBar = true, Beach = true, Dock = true, ShopStreet = true }

SecretDB.ITEM_NAMES = {
	GoldenStatue = "Golden Statue", DiamondNecklace = "Diamond Necklace", VIPKeycard = "VIP Keycard",
	SecurityCard = "Security Card", MasterKey = "Master Key", CasinoChip = "Gold Token", Briefcase = "Briefcase",
	PhotoCamera = "Photo Camera", StaffUniform = "Staff Uniform", Crowbar = "Crowbar", TreasureMap = "Treasure Map",
	SecretLetter = "Secret Letter", Champagne = "Sparkling Juice", Pizza = "Pizza", Flashlight = "Flashlight",
}
-- where hot items start (pedestals / VIP)
SecretDB.ITEM_HOME = { GoldenStatue = "Lobby", DiamondNecklace = "JewelryShop", Briefcase = "Plaza" }

local PUBLIC_FUN = { "Casino", "Pool", "Beach", "Rooftop", "Balcony", "HotelBar", "ShopStreet", "Dock", "PoolBar", "Restaurant", "BeachShop", "GuestRooms" }
local RESTRICTED_GOALS = { "Reception", "PrivateDining", "Housekeeping", "CasinoBackRoom", "ElectricalRoom", "SecurityRoom", "CasinoVIP" }
local HIDE_CANDIDATES = { "Restaurant", "Kitchen", "Pool", "Beach", "Underground", "GuestRooms", "ChangingRooms", "Housekeeping", "BeachShop" }
local HOTEL_ZONES = { "Lobby", "GuestRooms", "HotelBar", "Restaurant" }
local _CARRY_ITEMS = { "Pizza", "Champagne", "CasinoChip", "Flashlight" }

---------------------------------------------------------------- helpers
local function pick(rng, list)
	if #list == 0 then
		return nil
	end
	return list[rng(1, #list)]
end

local function shuffle(rng, list)
	local t = table.clone(list)
	for i = #t, 2, -1 do
		local j = rng(1, i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

local function contains(list, v)
	for _, x in ipairs(list) do
		if x == v then
			return true
		end
	end
	return false
end

local function weightedPick(rng, entries) -- entries {{w=}, ...}
	local total = 0
	for _, e in ipairs(entries) do
		total += e.w
	end
	if total <= 0 then
		return entries[1]
	end
	local r = rng() * total
	for _, e in ipairs(entries) do
		r -= e.w
		if r <= 0 then
			return e
		end
	end
	return entries[#entries]
end

-- context: zone names / availability, participant names
local function makeCtx(participants, zones, rng)
	local ctx = { rng = rng, names = {}, zoneName = {}, zoneExists = {}, restricted = {}, outdoor = {} }
	for _, p in ipairs(participants) do
		ctx.names[p.id] = p.name or tostring(p.id)
	end
	local list = zones and zones.list
	if type(list) == "table" and #list > 0 then
		for _, z in ipairs(list) do
			if type(z) == "table" and type(z.id) == "string" then
				ctx.zoneExists[z.id] = true
				ctx.zoneName[z.id] = z.name or FALLBACK_NAMES[z.id] or z.id
				ctx.restricted[z.id] = z.restricted == true
				ctx.outdoor[z.id] = z.outdoor == true
			end
		end
	end
	for _, id in ipairs(SecretDB.ZONE_IDS) do -- contract ids always valid for text even if list incomplete
		if not ctx.zoneName[id] then
			ctx.zoneName[id] = FALLBACK_NAMES[id]
			ctx.zoneExists[id] = true
			ctx.restricted[id] = FALLBACK_RESTRICTED[id] == true
			ctx.outdoor[id] = FALLBACK_OUTDOOR[id] == true
		end
	end
	local hz = {}
	if zones and type(zones.hideZones) == "table" and #zones.hideZones > 0 then
		for _, z in ipairs(zones.hideZones) do
			if ctx.zoneExists[z] and z ~= "Detention" then
				table.insert(hz, z)
			end
		end
	end
	if #hz == 0 then
		hz = table.clone(HIDE_CANDIDATES)
	end
	ctx.hideZones = hz
	function ctx.zn(id)
		return ctx.zoneName[id] or id
	end
	function ctx.nm(pid)
		return ctx.names[pid] or "someone"
	end
	function ctx.it(id)
		return SecretDB.ITEM_NAMES[id] or id
	end
	-- short forms for the one-line headline (`short`): plain zone names, names capped at 14 characters
	function ctx.zs(id)
		return SHORT_ZONE[id] or ctx.zoneName[id] or id
	end
	function ctx.sn(pid)
		local n = ctx.names[pid] or "someone"
		if (utf8.len(n) or #n) > 14 then
			local cut = utf8.offset(n, 14)
			n = (cut and n:sub(1, cut - 1) or n:sub(1, 13)) .. "…"
		end
		return n
	end
	return ctx
end
SecretDB._makeCtx = makeCtx

-- objective constructor
local function obj(id, tier, role, text, conds, steps, extra)
	local o = {
		id = id,
		tier = tier,
		role = role,
		text = text,
		conds = conds,
		steps = steps,
		step = 1,
		done = false,
		failed = false,
	}
	if extra then
		for k, v in pairs(extra) do
			o[k] = v
		end
	end
	return o
end

-- the zone hint for the current step of an objective (exposed for Secrets)
function SecretDB.hintFor(o)
	local c = o.conds and o.conds[o.step or 1]
	if not c then
		return nil
	end
	if c.zone then
		return c.zone
	end
	if c.t == "steal" and c.item then
		return SecretDB.ITEM_HOME[c.item]
	end
	if c.t == "zones" and c.zones then
		return c.zones[1]
	end
	if c.t == "deleteFootage" or c.t == "disableCam" then
		return "SecurityRoom"
	end
	if c.t == "trigger" and c.event == "PowerOutage" then
		return "ElectricalRoom"
	end
	if c.t == "escape" then
		return "Dock"
	end
	if c.t == "dig" then
		return "Beach"
	end
	if c.t == "winCoins" then
		return "Casino"
	end
	if c.t == "bribe" then
		return "Lobby"
	end
	return nil
end

-- progress max for counting conds
function SecretDB.progressMax(c)
	if c.t == "zones" then
		return #c.zones
	elseif c.t == "follow" then
		return c.seconds
	elseif c.t == "interact" or c.t == "talk" or c.t == "dig" or c.t == "makeEnter" or c.t == "deleteFootage" or c.t == "disableCam" then
		return c.count or 1
	elseif c.t == "giveCoins" or c.t == "getCoins" or c.t == "winCoins" then
		return c.amount
	end
	return nil
end

-- finalize: steps default, progress, hint
-- headline fallback: first sentence of the long text, capped at 50 characters
function SecretDB.shortOf(o)
	if type(o.short) == "string" and o.short ~= "" then
		return o.short
	end
	local t = tostring(o.text or "")
	t = t:match("^(.-[%.!?])%s") or t
	t = t:gsub("%.$", "")
	if (utf8.len(t) or #t) > 50 then
		local cut = utf8.offset(t, 48)
		t = (cut and t:sub(1, cut - 1) or t:sub(1, 47)) .. "…"
	end
	return t
end

local function finalize(o)
	o.steps = o.steps or {}
	o.short = SecretDB.shortOf(o)
	local c = o.conds[1]
	local mx = c and SecretDB.progressMax(c)
	if mx then
		o.progress = { cur = 0, max = mx }
	end
	o.hintZone = SecretDB.hintFor(o)
	return o
end
SecretDB.finalize = finalize

---------------------------------------------------------------- CHAINS (connected stories)
-- role = {key, slot, tier, role, core?, needs={keys}?, build=function(ctx, ids, pid) -> Obj}
-- ids: role key -> pid within this chain (only filled roles present).
-- Every objective has `short` (one plain sentence, <= 50 chars, shown in the pop-up / HUD) and one step per cond.
local CHAINS = {}

local function addChain(c)
	table.insert(CHAINS, c)
end

-- 1. THE GOLDEN STATUE ------------------------------------------------------
addChain({
	id = "GoldenStatue",
	title = "The Golden Statue",
	weight = 10,
	roles = {
		{
			key = "thief", slot = "main", tier = "Legendary", role = "THE THIEF", core = true,
			build = function(ctx, ids)
				local z = pick(ctx.rng, ctx.hideZones)
				return obj("GS_thief", "Legendary", "THE THIEF",
					("Steal the Golden Statue from the Lobby and hide it in the %s."):format(ctx.zn(z)),
					{ { t = "steal", item = "GoldenStatue" }, { t = "hide", item = "GoldenStatue", zone = z } },
					{ "Grab the statue 🗿 in the Lobby", ("Hide it in the %s"):format(ctx.zs(z)) },
					{ short = ("Steal the statue 🗿, hide in the %s"):format(ctx.zs(z)) })
			end,
		},
		{
			key = "detective", slot = "main", tier = "Hard", role = "THE DETECTIVE",
			build = function(ctx)
				return obj("GS_detective", "Hard", "THE DETECTIVE",
					"Someone will steal the Golden Statue. Find out who and accuse them.",
					{ { t = "accuse", item = "GoldenStatue" } },
					{ "Find clues, then ⚖️ Accuse the statue thief" },
					{ short = "Find the statue thief 🗿 and accuse them" })
			end,
		},
		{
			key = "protector", slot = "main", tier = "Hard", role = "THE PROTECTOR",
			build = function(ctx)
				return obj("GS_protector", "Hard", "THE PROTECTOR",
					"Protect the Golden Statue: it must be on its stand in the Lobby when the round ends.",
					{ { t = "pedestalEnd", item = "GoldenStatue" } },
					{ "If it's stolen, bring it back to its stand" },
					{ short = "Keep the statue 🗿 safe in the Lobby" })
			end,
		},
		{
			key = "photographer", slot = "main", tier = "Medium", role = "THE PAPARAZZI",
			build = function(ctx)
				return obj("GS_photo", "Medium", "THE PAPARAZZI",
					"Photograph whoever is carrying the Golden Statue.",
					{ { t = "photo", item = "GoldenStatue" } },
					{ "Hold your camera 📷, snap whoever has the statue" },
					{ startItems = { "PhotoCamera" }, short = "Take a photo 📷 of the statue thief" })
			end,
		},
		{
			key = "fixer", slot = "main", tier = "Medium", role = "THE FIXER",
			build = function(ctx)
				return obj("GS_fixer", "Medium", "THE FIXER",
					"Delete a security video in the Security Room before anyone sees it.",
					{ { t = "deleteFootage", count = 1 } },
					{ "Use your Security Card, delete a video on the screen" },
					{ startItems = { "SecurityCard" }, short = "Delete a camera video 📹 in Security" })
			end,
		},
		{
			key = "manipulator", slot = "main", tier = "Legendary", role = "THE MANIPULATOR", needs = { "detective" },
			build = function(ctx, ids)
				local d = ids.detective
				return obj("GS_manipulator", "Legendary", "THE MANIPULATOR",
					("Make %s accuse the WRONG person of stealing the Golden Statue. Tip: drop a Secret Letter at the crime to frame another guest."):format(ctx.nm(d)),
					{ { t = "convinceAccuse", target = d, item = "GoldenStatue" } },
					{ ("Make %s blame the wrong guest"):format(ctx.sn(d)) },
					{ target = d, short = ("Trick %s into blaming the wrong guest"):format(ctx.sn(d)) })
			end,
		},
		{
			key = "saboteur", slot = "side", tier = "Medium", role = "THE SABOTEUR",
			build = function(ctx)
				return obj("GS_saboteur", "Medium", "THE SABOTEUR",
					"Cut the power at the breaker in the Electrical Room (Underground).",
					{ { t = "trigger", event = "PowerOutage" } },
					{ "Use your card, pull the breaker ⚡" },
					{ startItems = { "SecurityCard" }, short = "Cut the power ⚡ in the Electrical Room" })
			end,
		},
	},
})

-- 2. THE DIAMOND NECKLACE HEIST ----------------------------------------------
addChain({
	id = "Necklace",
	title = "The Diamond Necklace Heist",
	weight = 8,
	roles = {
		{
			key = "jewelthief", slot = "main", tier = "Hard", role = "THE JEWEL THIEF", core = true,
			build = function(ctx)
				local z = ctx.zoneExists.Underground and "Underground" or pick(ctx.rng, ctx.hideZones)
				return obj("NK_thief", "Hard", "THE JEWEL THIEF",
					("Steal the Diamond Necklace from the Jewelry Shop and hide it in the %s."):format(ctx.zn(z)),
					{ { t = "steal", item = "DiamondNecklace" }, { t = "hide", item = "DiamondNecklace", zone = z } },
					{ "Grab the necklace 💎 in the Jewelry Shop", ("Hide it in the %s"):format(ctx.zs(z)) },
					{ short = ("Steal the necklace 💎, hide in the %s"):format(ctx.zs(z)) })
			end,
		},
		{
			key = "lookout", slot = "main", tier = "Medium", role = "THE LOOKOUT",
			build = function(ctx)
				return obj("NK_lookout", "Medium", "THE LOOKOUT",
					"Turn off a security camera so the heist goes unseen.",
					{ { t = "disableCam", count = 1 } },
					{ "Use your card, turn off a camera on the screen" },
					{ startItems = { "SecurityCard" }, short = "Turn off a security camera 📹" })
			end,
		},
		{
			key = "insurance", slot = "main", tier = "Hard", role = "THE INSURANCE AGENT",
			build = function(ctx)
				return obj("NK_agent", "Hard", "THE INSURANCE AGENT",
					"The Diamond Necklace is a target tonight. Find the jewel thief and accuse them.",
					{ { t = "accuse", item = "DiamondNecklace" } },
					{ "Find clues, then ⚖️ Accuse the necklace thief" },
					{ short = "Find the necklace thief 💎 and accuse them" })
			end,
		},
		{
			key = "fence", slot = "side", tier = "Hard", role = "THE FENCE", needs = { "jewelthief" },
			build = function(ctx)
				return obj("NK_fence", "Hard", "THE FENCE",
					"Someone is after the Diamond Necklace. Get it handed to you (or take it yourself).",
					{ { t = "getItem", item = "DiamondNecklace" } },
					{ "Get the necklace: trade, swipe or grab it" },
					{ short = "Get the diamond necklace 💎 any way" })
			end,
		},
	},
})

-- 3. THE HIGH ROLLER (VIP keycard / casino back room) ------------------------
addChain({
	id = "HighRoller",
	title = "The VIP Gamer",
	weight = 7,
	roles = {
		{
			key = "roller", slot = "main", tier = "Hard", role = "THE VIP GAMER", core = true,
			build = function(ctx)
				return obj("HR_roller", "Hard", "THE VIP GAMER",
					"Get a VIP Keycard, enter the Arcade VIP room and play the game table.",
					{ { t = "getItem", item = "VIPKeycard" }, { t = "zone", zone = "CasinoVIP" }, { t = "interact", kind = "Cards", count = 1 } },
					{ "Get a VIP Keycard 💳 (another guest has one)", "Go into the Arcade VIP room", "Play the VIP game table 🎯" },
					{ short = "Get a VIP card 💳, play the VIP game table" })
			end,
		},
		{
			key = "insider", slot = "main", tier = "Medium", role = "THE INSIDER", needs = { "roller" },
			build = function(ctx, ids)
				local r = ids.roller
				return obj("HR_insider", "Medium", "THE INSIDER",
					("Secretly give your VIP Keycard to %s."):format(ctx.nm(r)),
					{ { t = "giveItem", item = "VIPKeycard", target = r } },
					{ ("Find %s, then 🤝 Social → 🎁 Give"):format(ctx.sn(r)) },
					{ target = r, startItems = { "VIPKeycard" }, short = ("Give your VIP card 💳 to %s"):format(ctx.sn(r)) })
			end,
		},
		{
			key = "cardshark", slot = "side", tier = "Medium", role = "THE ARCADE PRO",
			build = function(ctx)
				return obj("HR_shark", "Medium", "THE ARCADE PRO",
					"Win 60 coins at the arcade.",
					{ { t = "winCoins", amount = 60 } },
					{ "Play arcade games 🕹️ in the Arcade (stop in the green!)" },
					{ short = "Win 60 coins 🪙 at the arcade" })
			end,
		},
		{
			key = "backroom", slot = "main", tier = "Hard", role = "THE SNOOP",
			build = function(ctx)
				return obj("HR_backroom", "Hard", "THE SNOOP",
					"Sneak into the Arcade Back Room and search it.",
					{ { t = "zone", zone = "CasinoBackRoom" }, { t = "interact", kind = "Search", zone = "CasinoBackRoom", count = 1 } },
					{ "Get in (the door code is on a note somewhere)", "Search a box in the Back Room" },
					{ short = "Sneak into the arcade Back Room 💰" })
			end,
		},
	},
})

-- 4. THE SECRET LETTER ---------------------------------------------------------
addChain({
	id = "Letter",
	title = "The Secret Letter",
	weight = 7,
	roles = {
		{
			key = "courier", slot = "main", tier = "Medium", role = "THE COURIER", core = true, needs = { "recipient" },
			build = function(ctx, ids)
				local r = ids.recipient
				return obj("SL_courier", "Medium", "THE COURIER",
					("Deliver the Secret Letter to %s without anyone else getting it."):format(ctx.nm(r)),
					{ { t = "giveItem", item = "SecretLetter", target = r } },
					{ ("Find %s, then 🤝 Social → 🎁 Give"):format(ctx.sn(r)) },
					{ target = r, startItems = { "SecretLetter" }, short = ("Give the Secret Letter ✉️ to %s"):format(ctx.sn(r)) })
			end,
		},
		{
			key = "recipient", slot = "main", tier = "Medium", role = "THE RECIPIENT", core = true,
			build = function(ctx)
				return obj("SL_recipient", "Medium", "THE RECIPIENT",
					"Someone is bringing you a Secret Letter. Get it and read it on the Rooftop.",
					{ { t = "receiveItem", item = "SecretLetter" }, { t = "itemAtZone", item = "SecretLetter", zone = "Rooftop" } },
					{ "Get the Secret Letter ✉️ from a guest", "Take it to the Rooftop 🚁" },
					{ short = "Get a letter ✉️, take it to the Rooftop" })
			end,
		},
		{
			key = "interceptor", slot = "main", tier = "Hard", role = "THE INTERCEPTOR", needs = { "courier" },
			build = function(ctx, ids)
				local c = ids.courier
				return obj("SL_intercept", "Hard", "THE INTERCEPTOR",
					("%s is carrying a Secret Letter. Get it before it's delivered."):format(ctx.nm(c)),
					{ { t = "getItem", item = "SecretLetter" } },
					{ ("Swipe or trade the letter from %s"):format(ctx.sn(c)) },
					{ target = c, short = ("Get the letter ✉️ from %s"):format(ctx.sn(c)) })
			end,
		},
	},
})

-- 5. THE GREAT ESCAPE ------------------------------------------------------------
addChain({
	id = "Escape",
	title = "The Great Escape",
	weight = 5,
	forcedEvents = { "BoatArrival" },
	roles = {
		{
			key = "smuggler", slot = "main", tier = "Legendary", role = "THE SMUGGLER", core = true,
			build = function(ctx)
				return obj("ES_smuggler", "Legendary", "THE SMUGGLER",
					"Find a Treasure Map, dig up the treasure at the beach and escape by boat with a Gold Token.",
					{ { t = "getItem", item = "TreasureMap" }, { t = "dig", count = 1 }, { t = "escape", item = "CasinoChip" } },
					{ "Search the hotel for a Treasure Map 🗺️", "Dig at a beach dig spot", "Get on the boat ⛵ holding a Gold Token 🪙" },
					{ short = "Find a treasure map 🗺️, dig, escape by boat" })
			end,
		},
		{
			key = "harbor", slot = "main", tier = "Medium", role = "THE HARBOR MASTER",
			build = function(ctx)
				return obj("ES_harbor", "Medium", "THE HARBOR MASTER",
					"A boat will arrive later. Be on the Dock while it's here.",
					{ { t = "eventZone", zone = "Dock", event = "BoatArrival" } },
					{ "Be on the Dock when the boat ⛵ comes" },
					{ short = "Be on the Dock ⚓ when the boat comes" })
			end,
		},
		{
			key = "tipster", slot = "side", tier = "Easy", role = "THE TIPSTER", needs = { "smuggler" },
			build = function(ctx, ids)
				local s = ids.smuggler
				return obj("ES_tipster", "Easy", "THE TIPSTER",
					("Talk to %s — they're planning something."):format(ctx.nm(s)),
					{ { t = "talk", count = 1, target = s } },
					{ ("Stand next to %s for 3 seconds"):format(ctx.sn(s)) },
					{ target = s, short = ("Talk to %s 💬"):format(ctx.sn(s)) })
			end,
		},
	},
})

-- 6. THE FRAME-UP ------------------------------------------------------------------
addChain({
	id = "Frame",
	title = "The Frame-Up",
	weight = 6,
	roles = {
		{
			key = "victim", slot = "side", tier = "Medium", role = "THE PATSY", core = true,
			build = function(ctx)
				return obj("FR_victim", "Medium", "THE PATSY",
					"Someone wants to frame you. Don't get caught by security this round.",
					{ { t = "notDetained" } },
					{ "Stay away from guards" },
					{ short = "Don't get caught by security 🚔" })
			end,
		},
		{
			key = "framer", slot = "main", tier = "Hard", role = "THE FRAMER", core = true, needs = { "victim" },
			build = function(ctx, ids)
				local v = ids.victim
				return obj("FR_framer", "Hard", "THE FRAMER",
					("Frame %s: when a crime happens, drop your Secret Letter at the crime scene."):format(ctx.nm(v)),
					{ { t = "frame", target = v } },
					{ "Drop your letter ✉️ where a crime happened" },
					{ target = v, startItems = { "SecretLetter" }, short = ("Frame %s for a crime ✉️"):format(ctx.sn(v)) })
			end,
		},
	},
})

-- 7. THE SPY -------------------------------------------------------------------------
addChain({
	id = "Spy",
	title = "The Spy",
	weight = 7,
	roles = {
		{
			key = "mark", slot = "side", tier = "Medium", role = "THE MARK", core = true,
			build = function(ctx, ids)
				return obj("SP_mark", "Medium", "THE MARK",
					"Someone is following you. Photograph your tail.",
					{ { t = "photo", target = ids.spy } },
					{ "Take a photo 📷 of whoever follows you" },
					{ startItems = { "PhotoCamera" }, short = "Someone follows you. Photo them 📷" })
			end,
			needs = { "spy" },
		},
		{
			key = "spy", slot = "main", tier = "Hard", role = "THE SPY", core = true,
			build = function(ctx, ids, pid, chainIds)
				local m = chainIds.markTarget
				return obj("SP_spy", "Hard", "THE SPY",
					("Follow %s for 60 seconds without being noticed."):format(ctx.nm(m)),
					{ { t = "follow", target = m, seconds = 60 } },
					{ ("Stay behind %s, not too close"):format(ctx.sn(m)) },
					{ target = m, short = ("Secretly follow %s for 60 s 👣"):format(ctx.sn(m)) })
			end,
		},
	},
})

-- 8. THE POOL PARTY ---------------------------------------------------------------------
addChain({
	id = "Party",
	title = "The Pool Party",
	weight = 6,
	roles = {
		{
			key = "host", slot = "main", tier = "Medium", role = "THE PARTY HOST", core = true,
			build = function(ctx, ids, pid, chainIds)
				local cnt = math.clamp((chainIds.n or 4) - 1, 1, 3)
				local g = cnt == 1 and "guest" or "guests"
				return obj("PP_host", "Medium", "THE PARTY HOST",
					("Convince %d %s to visit the pool (talk to them, then they must go there)."):format(cnt, g),
					{ { t = "makeEnter", zone = "Pool", count = cnt } },
					{ ("Talk to %d %s, then get them to the Pool"):format(cnt, g) },
					{ short = ("Bring %d %s to the Pool 🏊"):format(cnt, g) })
			end,
		},
		{
			key = "bartender", slot = "side", tier = "Easy", role = "THE PARTY STARTER",
			build = function(ctx)
				return obj("PP_champ", "Easy", "THE PARTY STARTER",
					"Bring a Sparkling Juice to the pool.",
					{ { t = "itemAtZone", item = "Champagne", zone = "Pool" } },
					{ "Get Sparkling Juice at a bar, take it to the Pool" },
					{ short = "Bring Sparkling Juice 🧃 to the Pool" })
			end,
		},
		{
			key = "guest", slot = "side", tier = "Easy", role = "THE PARTY GUEST",
			build = function(ctx)
				return obj("PP_guest", "Easy", "THE PARTY GUEST",
					"Rumor says there's a party at the pool. Go check it out.",
					{ { t = "zone", zone = "Pool" } }, { "Go to the Pool 🏊" },
					{ short = "Go to the Pool party 🏊" })
			end,
		},
		{
			key = "pooper", slot = "side", tier = "Medium", role = "THE PARTY POOPER", needs = { "host" },
			build = function(ctx, ids)
				local h = ids.host
				return obj("PP_pooper", "Medium", "THE PARTY POOPER",
					("%s is throwing a pool party. Lure them to the Arcade instead."):format(ctx.nm(h)),
					{ { t = "makeEnter", zone = "Casino", count = 1, target = h } },
					{ ("Talk to %s, then lead them to the Arcade"):format(ctx.sn(h)) },
					{ target = h, short = ("Lure %s to the Arcade 🕹️"):format(ctx.sn(h)) })
			end,
		},
	},
})

-- 9. THE VIP's BRIEFCASE -----------------------------------------------------------------
addChain({
	id = "Briefcase",
	title = "The VIP's Briefcase",
	weight = 5,
	forcedEvents = { "VIPArrival" },
	roles = {
		{
			key = "taker", slot = "main", tier = "Legendary", role = "THE OPPORTUNIST", core = true,
			build = function(ctx)
				return obj("BC_taker", "Legendary", "THE OPPORTUNIST",
					"A VIP will arrive with a briefcase. Steal it and hide it in the Underground.",
					{ { t = "steal", item = "Briefcase" }, { t = "hide", item = "Briefcase", zone = "Underground" } },
					{ "Steal the briefcase 💼 when the VIP arrives", "Hide it in the Tunnels" },
					{ short = "Steal the VIP's briefcase 💼, hide it" })
			end,
		},
		{
			key = "bodyguard", slot = "main", tier = "Hard", role = "THE BODYGUARD",
			build = function(ctx)
				return obj("BC_guard", "Hard", "THE BODYGUARD",
					"A VIP arrives later. If their briefcase is stolen, find the thief and accuse them.",
					{ { t = "accuse", item = "Briefcase" } },
					{ "If the briefcase is stolen, ⚖️ Accuse the thief" },
					{ short = "Catch the briefcase thief 💼" })
			end,
		},
	},
})

SecretDB.CHAINS = CHAINS

---------------------------------------------------------------- FILL TEMPLATES (solo / player-targeted)
-- {id, slot="main"|"side"|"any", tier, target=bool?, build(ctx, pid, target) -> Obj}
local FILL = {}
local function addFill(t)
	table.insert(FILL, t)
end

-- EASY
addFill({ id = "F_visit", slot = "any", tier = "Easy", build = function(ctx)
	local z = pick(ctx.rng, PUBLIC_FUN)
	return obj("F_visit_" .. z, "Easy", "THE TOURIST", ("Visit the %s."):format(ctx.zn(z)), { { t = "zone", zone = z } },
		{ ("Go to the %s"):format(ctx.zs(z)) }, { short = ("Go to the %s 📍"):format(ctx.zs(z)) })
end })
addFill({ id = "F_tour", slot = "any", tier = "Easy", build = function(ctx)
	local zs = shuffle(ctx.rng, PUBLIC_FUN)
	local three = { zs[1], zs[2], zs[3] }
	return obj("F_tour", "Easy", "THE SIGHTSEER",
		("Visit the %s, %s and %s."):format(ctx.zn(three[1]), ctx.zn(three[2]), ctx.zn(three[3])),
		{ { t = "zones", zones = three } }, { "Visit all three places (any order)" },
		{ short = ("Visit %s, %s & %s"):format(ctx.zs(three[1]), ctx.zs(three[2]), ctx.zs(three[3])) })
end })
addFill({ id = "F_talk3", slot = "any", tier = "Easy", build = function(ctx, _, _, n)
	local c = math.clamp((n or 4) - 1, 1, 3)
	return obj("F_talk3", "Easy", "THE SOCIALITE", ("Talk to %d different guests."):format(c), { { t = "talk", count = c } },
		{ "Stand next to a guest for 3 seconds" }, { short = ("Talk to %d different guests 💬"):format(c) })
end, minN = 2 })
addFill({ id = "F_give", slot = "any", tier = "Easy", build = function(ctx)
	return obj("F_give", "Easy", "THE GENEROUS ONE", "Give 30 coins to other guests.", { { t = "giveCoins", amount = 30 } },
		{ "Go near a guest: ☰ MENU → 🤝 Social → coins" }, { short = "Give 30 coins 🪙 to other guests" })
end, minN = 2 })
addFill({ id = "F_slots", slot = "any", tier = "Easy", build = function(ctx)
	return obj("F_slots", "Easy", "THE GAMER", "Play the arcade machines 3 times.", { { t = "interact", kind = "Slot", count = 3 } },
		{ "Arcade machines are in the Arcade 🕹️" }, { short = "Play the arcade machines 🕹️ 3 times" })
end })
addFill({ id = "F_food", slot = "any", tier = "Easy", build = function(ctx)
	return obj("F_food", "Easy", "THE FOODIE", "Order food or drinks twice.", { { t = "interact", kind = "Food", count = 2 } },
		{ "Order at the restaurant or a bar" }, { short = "Order food or drinks 🍔 two times" })
end })
addFill({ id = "F_search", slot = "any", tier = "Easy", build = function(ctx)
	return obj("F_search", "Easy", "THE SNOOP", "Search 4 drawers, cabinets or bags.", { { t = "interact", kind = "Search", count = 4 } },
		{ "Search drawers, boxes and bags anywhere" }, { short = "Search 4 drawers, boxes or bags 🔍" })
end })
addFill({ id = "F_notes", slot = "any", tier = "Easy", build = function(ctx)
	return obj("F_notes", "Easy", "THE READER", "Read 2 notes around the resort.", { { t = "interact", kind = "Note", count = 2 } },
		{ "Find notes and signs to read" }, { short = "Read 2 notes 📜 around the resort" })
end })
addFill({ id = "F_shop", slot = "any", tier = "Easy", build = function(ctx)
	return obj("F_shop", "Easy", "THE SHOPPER", "Buy something at a shop.", { { t = "buy" } },
		{ "Buy at a shop counter on Shop Street" }, { short = "Buy something at a shop 🛍️" })
end })
addFill({ id = "F_dig", slot = "any", tier = "Easy", build = function(ctx)
	return obj("F_dig", "Easy", "THE BEACHCOMBER", "Dig at a beach dig spot.", { { t = "dig", count = 1 } },
		{ "Find a dig spot on the Beach" }, { short = "Dig for treasure on the Beach 🏖️" })
end })
addFill({ id = "F_hotel", slot = "side", tier = "Easy", build = function(ctx)
	return obj("F_nohotel", "Easy", "THE OUTSIDER", "Never enter the hotel (Lobby, Guest Rooms, Bar, Restaurant) this round.",
		{ { t = "never", zones = table.clone(HOTEL_ZONES) } }, { "Stay outside the hotel until the end" },
		{ short = "Stay out of the hotel all round 🚫" })
end })
addFill({ id = "F_clean", slot = "side", tier = "Easy", build = function(ctx)
	return obj("F_clean", "Easy", "THE GOOD GUEST", "Don't get caught by security this round.", { { t = "notDetained" } },
		{ "Stay away from guards and cameras" }, { short = "Don't get caught by security 🚔" })
end })
addFill({ id = "F_photo", slot = "any", tier = "Easy", build = function(ctx)
	local z = pick(ctx.rng, { "Casino", "Pool", "Beach", "Lobby" })
	return obj("F_photo_" .. z, "Easy", "THE PHOTOGRAPHER", ("Photograph someone in the %s."):format(ctx.zn(z)),
		{ { t = "photo", zone = z } }, { "Hold your camera 📷, tap PHOTO near a guest" },
		{ startItems = { "PhotoCamera" }, short = ("Take a photo 📷 of a guest at the %s"):format(ctx.zs(z)) })
end, minN = 2 })
addFill({ id = "F_deliver", slot = "any", tier = "Easy", build = function(ctx)
	local it = pick(ctx.rng, { "Pizza", "Champagne" })
	local z = pick(ctx.rng, { "Balcony", "Rooftop", "Beach", "Dock" })
	local icon = it == "Pizza" and "🍕" or "🧃"
	return obj("F_deliver_" .. it, "Easy", "THE DELIVERY GUY", ("Bring %s to the %s."):format(ctx.it(it), ctx.zn(z)),
		{ { t = "itemAtZone", item = it, zone = z } },
		{ ("Get %s (%s), take it to the %s"):format(ctx.it(it), it == "Pizza" and "restaurant" or "bar", ctx.zs(z)) },
		{ short = ("Bring %s %s to the %s"):format(ctx.it(it), icon, ctx.zs(z)) })
end })

-- MEDIUM
addFill({ id = "F_restricted", slot = "any", tier = "Medium", build = function(ctx)
	local z = pick(ctx.rng, RESTRICTED_GOALS)
	return obj("F_restricted_" .. z, "Medium", "THE TRESPASSER", ("Get into the %s without being caught."):format(ctx.zn(z)),
		{ { t = "zone", zone = z } }, { ("Find a key, card or code, then enter the %s"):format(ctx.zs(z)) },
		{ short = ("Sneak into the %s 🔒"):format(ctx.zs(z)) })
end })
addFill({ id = "F_follow", slot = "any", tier = "Medium", target = true, build = function(ctx, _, t)
	return obj("F_follow", "Medium", "THE SHADOW", ("Follow %s for 45 seconds without being noticed."):format(ctx.nm(t)),
		{ { t = "follow", target = t, seconds = 45 } }, { ("Stay behind %s, not too close"):format(ctx.sn(t)) },
		{ target = t, short = ("Secretly follow %s for 45 s 👣"):format(ctx.sn(t)) })
end })
addFill({ id = "F_lure", slot = "any", tier = "Medium", target = true, build = function(ctx, _, t)
	local z = pick(ctx.rng, { "Casino", "Pool", "Beach", "Rooftop", "Kitchen", "ChangingRooms" })
	return obj("F_lure_" .. z, "Medium", "THE PERSUADER", ("Convince %s to go to the %s."):format(ctx.nm(t), ctx.zn(z)),
		{ { t = "makeEnter", zone = z, count = 1, target = t } }, { ("Talk to %s, then lead them to the %s"):format(ctx.sn(t), ctx.zs(z)) },
		{ target = t, short = ("Get %s to go to the %s"):format(ctx.sn(t), ctx.zs(z)) })
end })
addFill({ id = "F_beg", slot = "any", tier = "Medium", build = function(ctx)
	return obj("F_beg", "Medium", "THE SCROUNGER", "Get other guests to give you 25 coins.", { { t = "getCoins", amount = 25 } },
		{ "Ask guests to give you coins" }, { short = "Get 25 coins 🪙 from other guests" })
end, minN = 2 })
addFill({ id = "F_trade", slot = "any", tier = "Medium", build = function(ctx)
	return obj("F_trade", "Medium", "THE TRADER", "Give an item to another guest.", { { t = "giveItem" } },
		{ "Hold an item near a guest: 🤝 Social → 🎁 Give" }, { short = "Give an item 🎁 to another guest" })
end, minN = 2 })
addFill({ id = "F_trust", slot = "side", tier = "Medium", target = true, build = function(ctx, _, t)
	return obj("F_trust", "Medium", "THE FRIEND", ("Make %s trust you: team up with them."):format(ctx.nm(t)),
		{ { t = "ally", target = t } }, { ("Near %s: 🤝 Social → Team Up"):format(ctx.sn(t)) },
		{ target = t, short = ("Team up 🤝 with %s"):format(ctx.sn(t)) })
end })
addFill({ id = "F_protect", slot = "side", tier = "Medium", target = true, build = function(ctx, _, t)
	return obj("F_protect", "Medium", "THE GUARDIAN", ("Protect %s: they must not get caught by security this round."):format(ctx.nm(t)),
		{ { t = "protect", target = t } }, { "Keep them away from the guards" },
		{ target = t, short = ("Keep %s out of jail 🚔"):format(ctx.sn(t)) })
end })
addFill({ id = "F_pickpocket", slot = "any", tier = "Medium", build = function(ctx)
	return obj("F_pickpocket", "Medium", "THE PICKPOCKET", "Swipe an item from another guest.", { { t = "steal" } },
		{ "Sneak behind someone holding an item, Swipe" }, { short = "Swipe an item from a guest 🫳" })
end, minN = 2 })
addFill({ id = "F_hidepool", slot = "any", tier = "Medium", build = function(ctx)
	local z = pick(ctx.rng, ctx.hideZones)
	return obj("F_hide_" .. z, "Medium", "THE STASHER", ("Hide any item in the %s."):format(ctx.zn(z)),
		{ { t = "hide", zone = z } }, { ("Hold any item, hide it in the %s"):format(ctx.zs(z)) },
		{ short = ("Hide any item in the %s 🙈"):format(ctx.zs(z)) })
end })
addFill({ id = "F_bribe", slot = "any", tier = "Medium", build = function(ctx)
	return obj("F_bribe", "Medium", "THE BRIBER", "Pay a staff witness 50 coins to keep quiet.", { { t = "bribe" } },
		{ "After a crime, bribe a staff member (50 🪙)" }, { short = "Pay a witness to keep quiet 🤫" })
end })
addFill({ id = "F_jackpot", slot = "any", tier = "Medium", build = function(ctx)
	return obj("F_win", "Medium", "THE HIGH SCORER", "Win 50 coins at the arcade.", { { t = "winCoins", amount = 50 } },
		{ "Play arcade games 🕹️ in the Arcade (stop in the green!)" }, { short = "Win 50 coins 🪙 at the arcade" })
end })
addFill({ id = "F_prank", slot = "any", tier = "Medium", build = function(ctx)
	return obj("F_prank", "Medium", "THE PRANKSTER", "Make a prank call to distract security.", { { t = "trigger", event = "Prank" } },
		{ "Use any phone ☎️ in the hotel" }, { short = "Make a prank call ☎️" })
end })
addFill({ id = "F_storm", slot = "side", tier = "Medium", build = function(ctx)
	return obj("F_outsideevent", "Medium", "THE THRILL SEEKER", "If a storm hits, be on the Beach during it.",
		{ { t = "eventZone", zone = "Beach", event = "Storm" } }, { "When the storm ⛈️ comes, stand on the Beach" },
		{ short = "Be on the Beach 🏖️ during the storm" })
end })

-- HARD
addFill({ id = "F_caught", slot = "main", tier = "Hard", build = function(ctx)
	local z = pick(ctx.rng, ctx.hideZones)
	return obj("F_caught", "Hard", "THE ESCAPE ARTIST",
		("Get the Master Key, get caught by security, escape, then hide the key in the %s."):format(ctx.zn(z)),
		{ { t = "getItem", item = "MasterKey" }, { t = "detained" }, { t = "hide", item = "MasterKey", zone = z } },
		{ "Find the Master Key 🗝️ (Reception)", "Let a guard catch you 🚔", ("Hide the key in the %s"):format(ctx.zs(z)) },
		{ short = "Get the Master Key 🗝️, get caught, hide it" })
end })
addFill({ id = "F_hidden", slot = "main", tier = "Hard", build = function(ctx)
	return obj("F_hidden", "Hard", "THE EXPLORER", "Find the secret room in the Underground and search it.",
		{ { t = "zone", zone = "Underground" }, { t = "zone", zone = "HiddenRoom" }, { t = "interact", kind = "Search", zone = "HiddenRoom", count = 1 } },
		{ "Go down to the Tunnels", "Find the hidden switch, enter the Hidden Room", "Search the Hidden Room" },
		{ short = "Find the Hidden Room 🗝️ under the hotel" })
end })
addFill({ id = "F_cams", slot = "main", tier = "Hard", build = function(ctx)
	return obj("F_cams", "Hard", "THE HACKER", "Turn off 2 security cameras.", { { t = "disableCam", count = 2 } },
		{ "Use your card in the Security Room, turn off 2" }, { startItems = { "SecurityCard" }, short = "Turn off 2 security cameras 📹" })
end })
addFill({ id = "F_blackout", slot = "main", tier = "Hard", build = function(ctx)
	return obj("F_blackout", "Hard", "THE SABOTEUR", "Cause a power outage, then steal anything during the blackout.",
		{ { t = "trigger", event = "PowerOutage" }, { t = "steal" } },
		{ "Pull the breaker ⚡ in the Electrical Room", "Steal an item in the dark" },
		{ startItems = { "SecurityCard" }, short = "Cut the power ⚡, then steal something" })
end })
addFill({ id = "F_pit", slot = "main", tier = "Hard", target = true, target2 = true, minN = 3, build = function(ctx, _, t, _, t2)
	return obj("F_pit", "Hard", "THE PUPPET MASTER", ("Make %s accuse %s of something."):format(ctx.nm(t), ctx.nm(t2)),
		{ { t = "convinceAccuse", target = t, accused = t2 } },
		{ ("Convince %s that %s did it"):format(ctx.sn(t), ctx.sn(t2)) },
		{ target = t, short = ("Make %s blame %s ⚖️"):format(ctx.sn(t), ctx.sn(t2)) })
end })
addFill({ id = "F_detective", slot = "main", tier = "Hard", build = function(ctx)
	return obj("F_detective", "Hard", "THE SLEUTH", "Make any correct accusation this round.", { { t = "accuse" } },
		{ "Find clues, then ⚖️ Accuse the guilty guest" }, { short = "Catch a criminal: accuse the right one ⚖️" })
end })
addFill({ id = "F_disguise", slot = "main", tier = "Hard", build = function(ctx)
	return obj("F_disguise", "Hard", "THE IMPOSTOR", "Get a Staff Uniform, then sneak into the Kitchen and Housekeeping.",
		{ { t = "getItem", item = "StaffUniform" }, { t = "zones", zones = { "Kitchen", "Housekeeping" } } },
		{ "Find a Staff Uniform 🦺 (lockers, changing rooms)", "Visit the Kitchen and Housekeeping" },
		{ short = "Get a staff uniform 🦺, sneak into staff areas" })
end })

-- LEGENDARY
addFill({ id = "F_grandtour", slot = "main", tier = "Legendary", build = function(ctx)
	return obj("F_grandtour", "Legendary", "THE INFILTRATOR", "Visit the Rooftop, Arcade VIP room, Hidden Room and Security Room.",
		{ { t = "zones", zones = { "Rooftop", "CasinoVIP", "HiddenRoom", "SecurityRoom" } } },
		{ "Rooftop, VIP room, Hidden Room, Security Room" }, { short = "Sneak into 4 secret places 🕵️" })
end })
addFill({ id = "F_heistsolo", slot = "main", tier = "Legendary", build = function(ctx)
	return obj("F_heistsolo", "Legendary", "THE GHOST", "Steal any item, delete the camera video, and don't get caught.",
		{ { t = "steal" }, { t = "deleteFootage", count = 1 }, { t = "notDetained" } },
		{ "Steal any item", "Delete the video in the Security Room", "Don't get caught until the end" },
		{ startItems = { "SecurityCard" }, short = "Steal, delete the video, don't get caught" })
end })

SecretDB.FILL = FILL

---------------------------------------------------------------- tutorial
function SecretDB.tutorial()
	local main = obj("TUT_main", "Easy", "THE NEWCOMER", "Visit the arcade and play a game table.",
		{ { t = "zone", zone = "Casino" }, { t = "interact", kind = "Cards", count = 1 } },
		{ "Follow the arrow to the Arcade", "Play a game table 🎯 (press the prompt)" },
		{ short = "Go to the Arcade 🕹️, play a game table" })
	local side = obj("TUT_side", "Easy", "THE NEWCOMER", "Play an arcade machine once.", { { t = "interact", kind = "Slot", count = 1 } },
		{ "Arcade machines are in the Arcade" }, { short = "Play an arcade machine 🕹️ once" })
	main.slot, side.slot = "main", "side"
	return finalize(main), finalize(side)
end

---------------------------------------------------------------- generator
local MAIN_TIER_W = { { tier = "Easy", w = 15 }, { tier = "Medium", w = 40 }, { tier = "Hard", w = 33 }, { tier = "Legendary", w = 12 } }
local SIDE_TIER_W = { { tier = "Easy", w = 60 }, { tier = "Medium", w = 35 }, { tier = "Hard", w = 5 } }

local function inRecent(recent, pid, id)
	local r = recent and recent[pid]
	if not r then
		return false
	end
	for _, x in ipairs(r) do
		if x == id then
			return true
		end
	end
	return false
end

-- build one filler objective for pid in slot; avoids template ids in `avoid` (set) and recent
local function buildFill(ctx, pid, slot, tierWant, participants, recent, avoid)
	local rng = ctx.rng
	local n = #participants
	local others = {}
	for _, p in ipairs(participants) do
		if p.id ~= pid then
			table.insert(others, p.id)
		end
	end
	local function eligible(t, strictTier, strictRecent)
		if t.slot ~= "any" and t.slot ~= slot then
			return false
		end
		if strictTier and t.tier ~= tierWant then
			return false
		end
		if (t.minN or 1) > n then
			return false
		end
		if t.target and #others < 1 then
			return false
		end
		if t.target2 and #others < 2 then
			return false
		end
		if avoid[t.id] then
			return false
		end
		if strictRecent and inRecent(recent, pid, t.id) then
			return false
		end
		return true
	end
	local cands = {}
	for pass = 1, 4 do
		local strictTier = pass == 1 or pass == 2
		local strictRecent = pass == 1 or pass == 3
		for _, t in ipairs(FILL) do
			if eligible(t, strictTier, strictRecent) then
				table.insert(cands, t)
			end
		end
		if #cands > 0 then
			break
		end
	end
	if #cands == 0 then -- everything avoided: allow any slot-compatible template
		for _, t in ipairs(FILL) do
			if (t.slot == "any" or t.slot == slot) and (t.minN or 1) <= n and (not t.target or #others >= 1) and (not t.target2 or #others >= 2) then
				table.insert(cands, t)
			end
		end
	end
	local t = pick(rng, cands)
	local target, target2
	if t.target then
		local sh = shuffle(rng, others)
		target, target2 = sh[1], sh[2]
	end
	local o = t.build(ctx, pid, target, n, target2)
	o.templateId = t.id
	o.slot = slot
	return finalize(o)
end
SecretDB._buildFill = buildFill

-- choose tier by weights
local function rollTier(rng, slot)
	return weightedPick(rng, slot == "main" and MAIN_TIER_W or SIDE_TIER_W).tier
end

-- opts.beginners = { [pid] = true }: new players are cast last for Hard/Legendary story roles
function SecretDB.generate(participants, zones, rng, recent, opts)
	recent = recent or {}
	local beginners = (type(opts) == "table" and type(opts.beginners) == "table") and opts.beginners or {}
	local HARD_TIER = { Hard = true, Legendary = true }
	local ctx = makeCtx(participants, zones, rng)
	local n = #participants
	local result = { assignments = {}, chains = {}, forcedEvents = {}, recent = {} }
	if n == 0 then
		return result
	end
	local free = {} -- pid -> {main=bool, side=bool}
	local chainOf = {} -- pid -> {chainId=true}
	local ids = {}
	for _, p in ipairs(participants) do
		free[p.id] = { main = true, side = true }
		chainOf[p.id] = {}
		table.insert(ids, p.id)
	end
	local slotsFor = {} -- pid -> {main=Obj, side=Obj}
	for _, pid in ipairs(ids) do
		slotsFor[pid] = {}
	end

	-- how many participants should be in chains: ~75% of mains, at least 1
	local chainMainBudget = math.max(1, math.ceil(n * 0.8))
	local mainsUsed = 0

	-- order chains by weighted shuffle; GoldenStatue strongly preferred first (iconic)
	local pool = {}
	for _, c in ipairs(CHAINS) do
		table.insert(pool, { c = c, w = c.weight })
	end
	local chainOrder = {}
	while #pool > 0 do
		local e = weightedPick(rng, pool)
		for i, x in ipairs(pool) do
			if x == e then
				table.remove(pool, i)
				break
			end
		end
		table.insert(chainOrder, e.c)
	end

	local function candidatesFor(slot, chainId, roleId, tier)
		local c = {}
		for _, pid in ipairs(ids) do
			if free[pid][slot] and not chainOf[pid][chainId] then
				table.insert(c, pid)
			end
		end
		c = shuffle(rng, c)
		local hard = HARD_TIER[tier] == true
		-- prefer: beginners away from hard roles; did not have this role recently; then fewer chain roles so far
		table.sort(c, function(a, b)
			if hard then
				local ba, bb = beginners[a] and 1 or 0, beginners[b] and 1 or 0
				if ba ~= bb then
					return ba < bb
				end
			end
			local ra, rb = inRecent(recent, a, roleId) and 1 or 0, inRecent(recent, b, roleId) and 1 or 0
			if ra ~= rb then
				return ra < rb
			end
			local na, nb = 0, 0
			for _ in pairs(chainOf[a]) do
				na += 1
			end
			for _ in pairs(chainOf[b]) do
				nb += 1
			end
			return na < nb
		end)
		return c
	end

	for _, chain in ipairs(chainOrder) do
		if mainsUsed >= chainMainBudget then
			break
		end
		-- tentative assignment
		local roleIds = {} -- key -> pid
		local tentative = {} -- {pid, role}
		local usedSlots = {} -- pid -> {slot=true}
		local chainIds = { n = n }
		-- stable: core roles first, keep priority order within groups
		local sorted = {}
		for _, r in ipairs(chain.roles) do
			if r.core then
				table.insert(sorted, r)
			end
		end
		for _, r in ipairs(chain.roles) do
			if not r.core then
				table.insert(sorted, r)
			end
		end
		local coreOk = true
		local mainsHere = 0
		for _, r in ipairs(sorted) do
			local limitHit = r.slot == "main" and (mainsUsed + mainsHere) >= chainMainBudget and not r.core
			if not limitHit then
				local cands = candidatesFor(r.slot, chain.id, chain.id .. ":" .. r.key, r.tier)
				local chosen
				for _, pid in ipairs(cands) do
					if not (usedSlots[pid]) then
						chosen = pid
						break
					end
				end
				if chosen then
					roleIds[r.key] = chosen
					usedSlots[chosen] = true
					table.insert(tentative, { pid = chosen, role = r })
					if r.slot == "main" then
						mainsHere += 1
					end
				elseif r.core then
					coreOk = false
					break
				end
			end
		end
		-- drop non-core roles whose needs are missing
		if coreOk then
			local changed = true
			while changed do
				changed = false
				for i = #tentative, 1, -1 do
					local r = tentative[i].role
					for _, need in ipairs(r.needs or {}) do
						if not roleIds[need] then
							if r.core then
								coreOk = false
							end
							roleIds[r.key] = nil
							if r.slot == "main" then
								mainsHere -= 1
							end
							table.remove(tentative, i)
							changed = true
							break
						end
					end
				end
			end
		end
		-- chains with a single participant only for chains whose core is one role (statue, necklace,
		-- high roller, escape, briefcase, party); multi-core chains need all cores
		if coreOk and #tentative > 0 then
			-- spy chain: mark target for the spy
			chainIds.markTarget = roleIds.mark
			local entry = { id = chain.id, title = chain.title, roles = {} }
			for _, t in ipairs(tentative) do
				local o = t.role.build(ctx, roleIds, t.pid, chainIds)
				o.slot = t.role.slot
				o.chain = chain.id
				o.templateId = chain.id .. ":" .. t.role.key
				-- never target self (defensive; chain roles are distinct participants)
				if o.target == t.pid then
					o.target = nil
				end
				finalize(o)
				slotsFor[t.pid][t.role.slot] = o
				free[t.pid][t.role.slot] = false
				chainOf[t.pid][chain.id] = true
				table.insert(entry.roles, { pid = t.pid, key = t.role.key, role = t.role.role, slot = t.role.slot })
			end
			mainsUsed += mainsHere
			table.insert(result.chains, entry)
			for _, ev in ipairs(chain.forcedEvents or {}) do
				if not contains(result.forcedEvents, ev) then
					table.insert(result.forcedEvents, ev)
				end
			end
		end
	end

	-- fill remaining slots
	for _, pid in ipairs(ids) do
		local avoid = {}
		for _, slot in ipairs({ "main", "side" }) do
			local o = slotsFor[pid][slot]
			if o and o.templateId then
				avoid[o.templateId] = true
			end
		end
		for _, slot in ipairs({ "main", "side" }) do
			if not slotsFor[pid][slot] then
				local o = buildFill(ctx, pid, slot, rollTier(rng, slot), participants, recent, avoid)
				avoid[o.templateId] = true
				slotsFor[pid][slot] = o
			end
		end
	end

	-- side must not outrank main badly: if side is Legendary and main is Easy, swap
	for _, pid in ipairs(ids) do
		local s = slotsFor[pid]
		local rank = { Easy = 1, Medium = 2, Hard = 3, Legendary = 4 }
		if rank[s.side.tier] > rank[s.main.tier] and not s.side.chain and not s.main.chain then
			s.main, s.side = s.side, s.main
			s.main.slot, s.side.slot = "main", "side"
		end
		result.assignments[pid] = { main = s.main, side = s.side, role = s.main.role, chain = s.main.chain or s.side.chain }
		-- recent bookkeeping
		local r = table.clone(recent[pid] or {})
		table.insert(r, s.main.templateId)
		table.insert(r, s.side.templateId)
		while #r > SecretDB.RECENT_KEEP do
			table.remove(r, 1)
		end
		result.recent[pid] = r
	end
	-- carry over recent for absent participants
	for pid, r in pairs(recent) do
		if result.recent[pid] == nil then
			result.recent[pid] = r
		end
	end
	return result
end

-- Reroll one slot with a filler of the same tier (never the same template, never a chain role)
function SecretDB.reroll(participants, zones, rng, recent, pid, slot, current)
	local ctx = makeCtx(participants, zones, rng)
	local avoid = {}
	if current and current.templateId then
		avoid[current.templateId] = true
	end
	local tier = current and current.tier or rollTier(rng, slot)
	return buildFill(ctx, pid, slot, tier, participants, recent or {}, avoid)
end

-- every participant id referenced by an objective's conds (targets)
function SecretDB.referencedIds(o)
	local out = {}
	if o.target then
		table.insert(out, o.target)
	end
	for _, c in ipairs(o.conds or {}) do
		if c.target then
			table.insert(out, c.target)
		end
		if c.accused then
			table.insert(out, c.accused)
		end
	end
	return out
end

-- client-safe copy of an objective
function SecretDB.public(o)
	if not o then
		return nil
	end
	return {
		id = o.id,
		tier = o.tier,
		text = o.text,
		short = o.short,
		steps = o.steps,
		step = o.step,
		progress = o.progress and { cur = o.progress.cur, max = o.progress.max } or nil,
		done = o.done,
		failed = o.failed,
		hintZone = o.hintZone,
	}
end

return SecretDB
