-- Bots.luau — 9 named R15 guests (ids -1..-9) that fill the server up to Config.FillTo participants.
-- Realistic look (varied skin, resort outfits, part-built hair/hats), Motor6D fix via Core.makeRig,
-- PathfindingService movement (Nav), default R15 animations. Each bot reads its CURRENT secret step
-- and runs a scripted behaviour for that condition type, through the very same server APIs players use
-- (Interact.use, Social.request, Security monitor, Accuse) — no shortcuts that bypass rules.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Bus = require(script.Parent.Bus)
local Core = require(script.Parent.Core)
local Nav = require(script.Parent.Nav)
local Anim = require(script.Parent.Anim)

local Bots = {}
Bots.list = {} -- id -> bot record (participant p with p.bot = state)

local OUTFIT_COLORS = {
	{ 255, 120, 120 }, { 255, 190, 90 }, { 250, 230, 120 }, { 120, 210, 150 }, { 90, 200, 220 }, { 110, 150, 240 },
	{ 190, 140, 240 }, { 250, 150, 200 }, { 245, 245, 245 }, { 60, 70, 90 }, { 230, 210, 170 }, { 40, 120, 110 },
}
local PANTS_COLORS = { { 235, 225, 200 }, { 60, 80, 120 }, { 40, 40, 50 }, { 120, 160, 200 }, { 200, 170, 120 }, { 245, 245, 245 } }
local HAIR_STYLES = { "short", "long", "bun", "fringe", "afro", "short", "long" }

local function c3(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function botFolder()
	local f = workspace:FindFirstChild("EHAS_Bots")
	if not f then
		f = Instance.new("Folder")
		f.Name = "EHAS_Bots"
		f.Parent = workspace
	end
	return f
end

local function spawnPos(i)
	local spawns = Core.markers("SpawnPlaza_")
	if #spawns > 0 then
		return spawns[(i - 1) % #spawns + 1].Position
	end
	return Core.zonePoint("Plaza") or Vector3.new(0, 10, 0)
end

---------------------------------------------------------------- spawn / despawn
function Bots.spawn(index)
	local id = -index
	if Core.participants[id] then
		return Core.participants[id]
	end
	local name = Config.BotNames[index] or ("Guest_" .. index)
	local r = Core.rng
	local look = {
		outfit = "guest",
		displayName = name,
		skin = Core.SKIN_TONES[(index * 5) % #Core.SKIN_TONES + 1],
		shirt = c3(OUTFIT_COLORS[(index * 7) % #OUTFIT_COLORS + 1]),
		pants = c3(PANTS_COLORS[(index * 3) % #PANTS_COLORS + 1]),
		shoes = c3(({ { 245, 245, 245 }, { 40, 30, 25 }, { 150, 90, 50 } })[index % 3 + 1]),
		accent = c3(OUTFIT_COLORS[(index * 11 + 3) % #OUTFIT_COLORS + 1]),
		hair = HAIR_STYLES[index % #HAIR_STYLES + 1],
		hairColor = Core.HAIR_COLORS[(index * 2) % #Core.HAIR_COLORS + 1],
		shorts = index % 3 == 0,
		longSleeves = index % 2 == 0,
		variant = (index % 4) + 1,
	}
	local ok, model = pcall(Core.makeRig, name, look)
	if not ok or not model then
		warn("[Bots] rig failed: " .. tostring(model))
		return nil
	end
	model:SetAttribute("BotId", id)
	model:PivotTo(CFrame.new(spawnPos(index) + Vector3.new(r:NextNumber(-3, 3), 1, r:NextNumber(-3, 3))))
	model.Parent = botFolder()
	local root = model:FindFirstChild("HumanoidRootPart")
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local p = Core.addBot(id, name, model)
	p.botSpeed = Config.BotWalkSpeed
	p.bot = {
		nav = Nav.new(model),
		goal = nil,
		nextThink = 0,
		wanderUntil = 0,
		searches = 0,
		lastAccuseCheck = 0,
		personality = r:NextNumber(), -- 0 = cautious, 1 = bold
	}
	Bots.list[id] = p
	if Core.M.Interact then
		Core.M.Interact.attachSwipe(p)
	end
	return p
end

function Bots.despawn(id)
	local p = Bots.list[id]
	if not p then
		return
	end
	Bots.list[id] = nil
	local model = p.model
	Core.removeParticipant(id)
	if model then
		model:Destroy()
	end
end

-- keep bots = clamp(FillTo - realPlayers, 0, BotCount); total never above MaxPlayers
function Bots.rebalance()
	local real = #Core.realPlayers()
	local want = math.clamp(Config.FillTo - real, 0, Config.BotCount)
	want = math.min(want, Config.MaxPlayers - real)
	local have = {}
	for id in pairs(Bots.list) do
		table.insert(have, -id)
	end
	table.sort(have)
	-- never spawn mid-round either: a bot added in Intro/Play/Reveal has no secret, isn't in the round and
	-- misses the reveal (a leaver's slot is refilled at the next Lobby)
	local midRound = Core.phase == "Intro" or Core.phase == "Play" or Core.phase == "Reveal"
	for i = 1, (midRound and 0 or want) do
		if not Bots.list[-i] then
			Bots.spawn(i)
		end
	end
	for _, idx in ipairs(have) do
		-- never remove a bot mid-round (its secret, evidence and accusations would vanish); trim in the Lobby
		if idx > want and Core.phase ~= "Intro" and Core.phase ~= "Play" and Core.phase ~= "Reveal" then
			Bots.despawn(-idx)
		end
	end
end

function Bots.resetPositions()
	local i = 0
	for _, p in pairs(Bots.list) do
		i += 1
		if p.model and p.model.Parent then
			p.model:PivotTo(CFrame.new(spawnPos(i + 3) + Vector3.new(0, 1, 0)))
			Nav.stop(p.bot.nav)
		end
		p.bot.goal = nil
		p.bot.searches = 0
		p.bot.wanderUntil = 0
		p.botFollow = nil
		p.botForceGoal = nil
		p.botLure = nil
		p.botAccuseBias = nil
	end
end

---------------------------------------------------------------- helpers
local function nearestPart(p, parts)
	local pos = Core.pos(p)
	if not pos then
		return nil
	end
	local best, bd
	for _, part in ipairs(parts) do
		local d = (part.Position - pos).Magnitude
		if not bd or d < bd then
			best, bd = part, d
		end
	end
	return best, bd
end

local function goTo(p, pos, arrive)
	if not pos then
		return
	end
	local nav = p.bot.nav
	if nav.target and (nav.target - pos).Magnitude < 3 and not nav.arrived then
		return
	end
	task.spawn(Nav.goTo, nav, pos, arrive or 5)
end

local function near(p, pos, d)
	local pp = Core.pos(p)
	return pp ~= nil and pos ~= nil and (pp - pos).Magnitude <= (d or 8)
end

-- walk to a part and use it when close; returns true when used this tick
local function useAt(p, part, opts)
	if not part then
		return false
	end
	if near(p, part.Position, 9) then
		Nav.stop(p.bot.nav)
		local hum = Core.hum(p)
		if hum then
			Anim.play(hum, "point", 1.2, false)
		end
		local Interact = Core.M.Interact
		local ok = Interact and Interact.use(p, part, opts or {})
		p.bot.cool = os.clock() + 2.5
		return ok
	end
	goTo(p, part.Position, 5)
	return false
end

local function equipItem(p, itemId)
	local t = Core.findItem(p, itemId)
	if not t then
		return nil
	end
	local hum = Core.hum(p)
	local cur = p.model:FindFirstChildOfClass("Tool")
	if cur ~= t then
		if cur then
			cur.Parent = p.inv
		end
		pcall(function()
			hum:EquipTool(t)
		end)
	end
	return t
end

local function faceTowards(p, pos)
	local root = Core.root(p)
	if root and pos then
		local flat = Vector3.new(pos.X, root.Position.Y, pos.Z)
		if (flat - root.Position).Magnitude > 0.1 then
			-- turn over ~0.2 s instead of snapping (snap looked robotic in play-test)
			local from = root.CFrame - root.CFrame.Position
			local to = CFrame.lookAt(root.Position, flat) - root.Position
			task.spawn(function()
				for i = 1, 6 do
					if not root.Parent then
						return
					end
					root.CFrame = CFrame.new(root.Position) * from:Lerp(to, i / 6)
					task.wait(0.033)
				end
			end)
		end
	end
end

local function partsIn(kind, zone)
	local list = Core.interactParts(kind, zone)
	if #list == 0 and zone then
		list = Core.interactParts(kind)
	end
	return list
end

local function wander(p)
	local b = p.bot
	if os.clock() < b.wanderUntil and not b.nav.arrived then
		return
	end
	local pts = Core.markers("BotWander")
	local pos
	if #pts > 0 then
		pos = Core.pick(pts).Position
	else
		pos = Core.zonePoint(Core.pick({ "Plaza", "Lobby", "Casino", "Pool", "Beach", "ShopStreet" }))
	end
	b.wanderUntil = os.clock() + Core.rng:NextNumber(8, 16)
	goTo(p, pos, 6)
end

-- ITEM SOURCES for getItem-style steps
local ITEM_SOURCE = {
	Pizza = "Food", Champagne = "Food", CasinoChip = "Cashier", PhotoCamera = "Shop", Flashlight = "Shop",
	TreasureMap = "Shop", StaffUniform = "Shop", Crowbar = "Shop", SecretLetter = "Shop",
}

local function acquire(p, itemId)
	if Core.hasItem(p, itemId) then
		return true
	end
	local b = p.bot
	-- items stolen from a pedestal
	local Interact = Core.M.Interact
	if Interact then
		local ped, st = Interact.pedestalFor(itemId)
		if ped and st.present then
			useAt(p, ped)
			return false
		end
	end
	-- someone carries it? go swipe (bold bots) / ask (cautious)
	for _, q in pairs(Core.participants) do
		if q ~= p and q.inRound and Core.hasItem(q, itemId) then
			if near(p, Core.pos(q), 6) then
				if b.personality > 0.4 and Interact then
					Interact.swipe(p, q)
				elseif Core.M.Social and (b.askedAt or 0) < os.clock() then
					b.askedAt = os.clock() + 20
					Core.M.Social.request(p, q, "TeamUp", "wants to make a deal for your " .. Core.itemName(itemId))
				end
			else
				goTo(p, Core.pos(q), 4)
			end
			return false
		end
	end
	local kind = ITEM_SOURCE[itemId]
	if kind and Core.getCoins(p) >= 60 then
		local part
		if kind == "Shop" and Interact then
			for _, s in ipairs(Core.interactParts("Shop")) do
				for _, e in ipairs(Interact.SHOP_STOCK[s:GetAttribute("ShopId") or "General"] or {}) do
					if e.id == itemId then
						part = part or s
					end
				end
			end
		elseif kind == "Food" then
			local wantZones = itemId == "Pizza" and { Restaurant = true, Kitchen = true } or { HotelBar = true, PoolBar = true }
			for _, f in ipairs(Core.interactParts("Food")) do
				if wantZones[f:GetAttribute("Zone") or ""] then
					part = part or f
				end
			end
			part = part or Core.interactParts("Food")[1]
		else
			part = nearestPart(p, Core.interactParts(kind))
		end
		if part then
			useAt(p, part)
			return false
		end
	end
	-- search containers; after a few tries the bot "finds" it (searches are real interactions)
	local search = b.searchTarget
	if not search or not search.Parent then
		search = Core.pick(Core.interactParts("Search"))
		b.searchTarget = search
	end
	if search then
		if near(p, search.Position, 9) then
			b.searches += 1
			local force = b.searches >= 3 and itemId or nil
			useAt(p, search, { forceLoot = force })
			b.searchTarget = nil
			if force then
				b.searches = 0
			end
		else
			goTo(p, search.Position, 5)
		end
	else
		wander(p)
	end
	return false
end

---------------------------------------------------------------- behaviours per condition
local function doTalk(p, targetId)
	local target = targetId and Core.participants[targetId]
	if not target then
		-- nearest participant not talked to recently
		local best, bd
		for _, q in pairs(Core.participants) do
			if q ~= p and q.inRound and not q.hidden then
				local Social = Core.M.Social
				if not (Social and Social.talkedRecently(p.id, q.id, 120)) then
					local d = Core.dist(p, q)
					if not bd or d < bd then
						best, bd = q, d
					end
				end
			end
		end
		target = best
	end
	if not target then
		wander(p)
		return
	end
	local tp = Core.pos(target)
	if near(p, tp, 5) then
		Nav.stop(p.bot.nav)
		faceTowards(p, tp)
		if (p.bot.waveAt or 0) < os.clock() then
			p.bot.waveAt = os.clock() + 6
			local hum = Core.hum(p)
			if hum then
				Anim.play(hum, Core.pick({ "wave", "laugh", "point" }), 1, false)
			end
		end
	else
		goTo(p, tp, 3)
	end
	return target
end

local function doFollow(p, targetId)
	local t = Core.participants[targetId]
	if not t then
		return wander(p)
	end
	local tp, tr = Core.pos(t), Core.root(t)
	if not tp then
		return
	end
	local d = Core.dist(p, t)
	-- stay ~22 studs behind the target, out of its view
	local behind = tp - tr.CFrame.LookVector * 22
	if d > 32 or d < 12 then
		goTo(p, behind, 4)
	else
		Nav.stop(p.bot.nav)
	end
end

local CONDS = {}
CONDS.zone = function(p, c)
	goTo(p, Core.zonePoint(c.zone), 6)
end
CONDS.eventZone = function(p, c)
	local Events = Core.M.Events
	if Events and Events.isActive(c.event) then
		goTo(p, Core.zonePoint(c.zone), 6)
	else
		wander(p)
	end
end
CONDS.zones = function(p, c, o)
	local seen = o.cs and o.cs.set or {}
	for _, z in ipairs(c.zones) do
		if not seen[z] then
			goTo(p, Core.zonePoint(z), 6)
			return
		end
	end
end
CONDS.itemAtZone = function(p, c)
	if acquire(p, c.item) then
		goTo(p, Core.zonePoint(c.zone), 6)
	end
end
CONDS.getItem = function(p, c)
	acquire(p, c.item)
end
CONDS.receiveItem = function(p, c)
	-- hang around; the courier comes to us. Wander near the Lobby/Plaza.
	if (p.bot.wanderUntil or 0) < os.clock() then
		goTo(p, Core.zonePoint(Core.pick({ "Lobby", "Plaza", "HotelBar" })), 6)
		p.bot.wanderUntil = os.clock() + 15
	end
end
CONDS.steal = function(p, c)
	local Interact = Core.M.Interact
	local Events = Core.M.Events
	if c.item == "Briefcase" then
		local vip = Events and Events.vip
		if vip and vip.hasCase and vip.model.Parent then
			local root = vip.model:FindFirstChild("HumanoidRootPart")
			if root and near(p, root.Position, 7) then
				Events.stealBriefcase(p)
			elseif root then
				goTo(p, root.Position, 3)
			end
		else
			wander(p)
		end
		return
	end
	-- bold thieves wait for good moments: during outages they go immediately; cautious ones wait a bit
	local ped
	if c.item and Interact then
		ped = Interact.pedestalFor(c.item)
	elseif Interact then
		for part, st in pairs(Interact.pedestals) do
			if st.present then
				ped = part
			end
		end
	end
	if ped and Interact.pedestals[ped] and Interact.pedestals[ped].present then
		local outage = Events and Events.isActive("PowerOutage")
		local ready = outage or Core.elapsed() > (60 + (1 - p.bot.personality) * 120)
		if ready then
			useAt(p, ped)
		else
			goTo(p, ped.Position + Vector3.new(Core.rng:NextNumber(-15, 15), 0, Core.rng:NextNumber(-15, 15)), 8)
		end
	elseif not c.item then
		-- pickpocket someone carrying something
		for _, q in pairs(Core.participants) do
			if q ~= p and q.inRound and Core.itemCount(q) > 0 then
				if near(p, Core.pos(q), 6) then
					if Interact then
						Interact.swipe(p, q)
					end
				else
					goTo(p, Core.pos(q), 4)
				end
				return
			end
		end
		wander(p)
	else
		-- the item is already gone: chase whoever has it
		acquire(p, c.item)
	end
end
CONDS.hide = function(p, c)
	if c.item and not Core.hasItem(p, c.item) then
		return acquire(p, c.item)
	end
	if not c.item and Core.itemCount(p) == 0 then
		return acquire(p, Core.pick({ "Flashlight", "Champagne", "Pizza" }))
	end
	local spots = {}
	for _, k in ipairs({ "Hide", "Dig" }) do
		for _, part in ipairs(Core.interactParts(k, c.zone)) do
			table.insert(spots, part)
		end
	end
	if #spots == 0 then
		for _, part in ipairs(Core.interactParts("Hide")) do
			table.insert(spots, part)
		end
	end
	local spot = nearestPart(p, spots)
	if spot then
		local action = spot:GetAttribute("Kind") == "Dig" and "Bury" or "Stash"
		useAt(p, spot, { action = action, itemId = c.item })
	elseif c.zone then
		goTo(p, Core.zonePoint(c.zone), 6)
	end
end
CONDS.dig = function(p)
	useAt(p, nearestPart(p, Core.interactParts("Dig")), { action = "Dig" })
end
CONDS.interact = function(p, c)
	if c.zone and p.zone ~= c.zone and #Core.interactParts(c.kind, c.zone) > 0 then
		local tgt = nearestPart(p, Core.interactParts(c.kind, c.zone))
		-- restricted target zones (e.g. CasinoBackRoom) need a way in: try the door, else wander nearby
		useAt(p, tgt, { action = c.kind == "Hide" and "Search" or nil })
		return
	end
	useAt(p, nearestPart(p, partsIn(c.kind, c.zone)), { action = c.kind == "Hide" and "Search" or nil })
end
CONDS.talk = function(p, c)
	doTalk(p, c.target)
end
CONDS.follow = function(p, c)
	doFollow(p, c.target)
end
CONDS.giveCoins = function(p, c)
	local t = doTalk(p, c.target)
	if t and Core.dist(p, t) < 10 and Core.M.Social and (p.bot.giveAt or 0) < os.clock() then
		p.bot.giveAt = os.clock() + 8
		Core.M.Social.giveCoins(p, t, math.min(c.amount, 15))
	end
end
CONDS.getCoins = function(p)
	doTalk(p, nil)
end
CONDS.giveItem = function(p, c)
	if c.item and not Core.hasItem(p, c.item) then
		return acquire(p, c.item)
	end
	if not c.item and Core.itemCount(p) == 0 then
		return acquire(p, "Champagne")
	end
	local t = doTalk(p, c.target)
	if t and Core.dist(p, t) < 12 and Core.M.Social and (p.bot.reqAt or 0) < os.clock() then
		p.bot.reqAt = os.clock() + 15
		if c.item then
			equipItem(p, c.item)
		end
		Core.M.Social.request(p, t, "Give", c.item)
	end
end
CONDS.makeEnter = function(p, c, o)
	local Social = Core.M.Social
	local done = o.cs and o.cs.set or {}
	local target
	if c.target then
		target = Core.participants[c.target]
	else
		for _, q in pairs(Core.participants) do
			if q ~= p and q.inRound and not done[q.id] and not (Social and Social.talkedRecently(p.id, q.id)) then
				target = target or q
			end
		end
		-- already talked to someone? walk to the zone so they "follow the party"
		if not target then
			goTo(p, Core.zonePoint(c.zone), 6)
			return
		end
	end
	if not target then
		return wander(p)
	end
	if Social and Social.talkedRecently(p.id, target.id) then
		-- lure: bots being lured actually go (they're curious); players need convincing
		if target.isBot and not target.botLure then
			target.botLure = { zone = c.zone, untilT = os.clock() + 40 }
		end
		if not target.isBot and (p.bot.reqAt or 0) < os.clock() then
			p.bot.reqAt = os.clock() + 25
			Social.request(p, target, "Follow", ("says: come to the %s with me!"):format(Core.zoneName(c.zone)))
		end
		goTo(p, Core.zonePoint(c.zone), 6)
	else
		doTalk(p, target.id)
	end
end
CONDS.accuse = function(p)
	Bots.investigate(p, true)
end
CONDS.convinceAccuse = function(p, c)
	local t = doTalk(p, c.target)
	local target = Core.participants[c.target]
	if target and target.isBot and t and Core.dist(p, t) < 8 then
		target.botAccuseBias = { by = p.id, accused = c.accused }
	end
end
CONDS.photo = function(p, c)
	if not Core.hasItem(p, "PhotoCamera") then
		return acquire(p, "PhotoCamera")
	end
	local target
	if c.target then
		target = Core.participants[c.target]
	elseif c.item then
		for _, q in pairs(Core.participants) do
			if q ~= p and q.inRound and Core.hasItem(q, c.item) then
				local hot = Core.findItem(q, c.item)
				if hot and hot:GetAttribute("Hot") then
					target = q
				end
			end
		end
	else
		for _, q in pairs(Core.participants) do
			if q ~= p and q.inRound and (not c.zone or q.zone == c.zone) then
				target = target or q
			end
		end
	end
	if not target then
		if c.zone then
			goTo(p, Core.zonePoint(c.zone), 6)
		else
			wander(p)
		end
		return
	end
	local tp = Core.pos(target)
	if near(p, tp, 18) then
		Nav.stop(p.bot.nav)
		faceTowards(p, tp)
		equipItem(p, "PhotoCamera")
		if (p.bot.photoAt or 0) < os.clock() and Core.M.Interact then
			p.bot.photoAt = os.clock() + 3
			Core.M.Interact.takePhoto(p)
		end
	else
		goTo(p, tp, 10)
	end
end
local function securityComputer()
	for _, part in ipairs(Core.interactParts("Computer")) do
		if (part:GetAttribute("Role") or "Security") == "Security" then
			return part
		end
	end
	return nil
end
CONDS.deleteFootage = function(p)
	local comp = securityComputer()
	local Security = Core.M.Security
	if not comp or not Security then
		return wander(p)
	end
	if near(p, comp.Position, 9) then
		Nav.stop(p.bot.nav)
		Security.openMonitor(p, comp, "Security")
		for i = #Security.footage, 1, -1 do
			local f = Security.footage[i]
			if not f.deleted then
				Security.deleteFootage(p, f.id)
				return
			end
		end
	else
		useAt(p, comp)
	end
end
CONDS.disableCam = function(p)
	local comp = securityComputer()
	local Security = Core.M.Security
	if not comp or not Security then
		return wander(p)
	end
	if near(p, comp.Position, 9) then
		Nav.stop(p.bot.nav)
		if (p.bot.camAt or 0) < os.clock() then
			p.bot.camAt = os.clock() + 2
			Security.openMonitor(p, comp, "Security")
			local ids = Core.shuffle(Security.camOrder)
			for _, id in ipairs(ids) do
				if Security.cams[id].disabledUntil <= os.clock() then
					Security.disableCam(p, id)
					return
				end
			end
		end
	else
		useAt(p, comp)
	end
end
CONDS.trigger = function(p, c)
	local kind = ({ PowerOutage = "PowerBox", SecurityLockdown = "Alarm", Prank = "Phone" })[c.event] or "Phone"
	local wait = c.event == "PowerOutage" and Core.elapsed() < 120 * (1 - p.bot.personality)
	if wait then
		return wander(p)
	end
	useAt(p, nearestPart(p, Core.interactParts(kind)))
end
CONDS.detained = function(p)
	-- act suspicious in front of a guard
	local Security = Core.M.Security
	if not Security then
		return
	end
	local best, bd
	for _, g in ipairs(Security.guards) do
		if g.root and g.root.Parent then
			local d = (g.root.Position - (Core.pos(p) or g.root.Position)).Magnitude
			if not bd or d < bd then
				best, bd = g, d
			end
		end
	end
	if best then
		if bd < 20 then
			Security.alert(p, Core.pos(p), "acting very suspicious")
		end
		goTo(p, best.root.Position, 3)
	end
end
CONDS.escape = function(p, c)
	if c.item and not Core.hasItem(p, c.item) then
		return acquire(p, c.item)
	end
	local Events = Core.M.Events
	if Events and Events.isActive("BoatArrival") then
		useAt(p, nearestPart(p, Core.interactParts("Boat")))
	else
		goTo(p, Core.zonePoint(Core.pick({ "Beach", "Dock", "BeachShop" })), 8)
	end
end
CONDS.ally = function(p, c)
	local t = doTalk(p, c.target)
	if t and Core.dist(p, t) < 10 and Core.M.Social and (p.bot.reqAt or 0) < os.clock() then
		p.bot.reqAt = os.clock() + 20
		Core.M.Social.request(p, t, "TeamUp")
	end
end
CONDS.frame = function(p, c)
	local Evidence = Core.M.Evidence
	local inc
	if Evidence then
		for i = #Evidence.incidents, 1, -1 do
			local x = Evidence.incidents[i]
			if not x.solved and x.pos and x.culprit ~= p.id then
				inc = x
				break
			end
		end
	end
	if not inc then
		return wander(p)
	end
	local item = Core.hasItem(p, "SecretLetter") and "SecretLetter" or (Core.hasItem(p, "StaffUniform") and "StaffUniform" or nil)
	if not item then
		return acquire(p, "SecretLetter")
	end
	if near(p, inc.pos, 12) then
		equipItem(p, item)
		if Core.M.Interact then
			Core.M.Interact.dropItem(p, c.target)
		end
	else
		goTo(p, inc.pos, 6)
	end
end
CONDS.bribe = function(p)
	local Evidence = Core.M.Evidence
	if not Evidence or #Evidence.incidents == 0 or #Evidence.staff == 0 then
		return wander(p)
	end
	local s = Evidence.staff[1]
	local best, bd
	for _, x in ipairs(Evidence.staff) do
		local d = Core.pos(p) and (x.part.Position - Core.pos(p)).Magnitude or 0
		if not bd or d < bd then
			best, bd = x, d
		end
	end
	s = best
	if near(p, s.part.Position, 8) then
		Evidence.bribe(p, s)
	else
		goTo(p, s.part.Position, 5)
	end
end
CONDS.winCoins = function(p)
	useAt(p, nearestPart(p, Core.interactParts("Slot")))
end
CONDS.buy = function(p)
	useAt(p, nearestPart(p, Core.interactParts("Shop")))
end

---------------------------------------------------------------- investigation + accusations
function Bots.investigate(p, eager)
	local Evidence, Accuse = Core.M.Evidence, Core.M.Accuse
	if not Evidence or not Accuse then
		return wander(p)
	end
	local inc
	for i = #Evidence.incidents, 1, -1 do
		local x = Evidence.incidents[i]
		if not x.solved and x.culprit ~= p.id and not (p.accusedIncidents and p.accusedIncidents[x.id]) then
			inc = x
			break
		end
	end
	if not inc then
		if eager then
			-- patrol near valuables while waiting for a crime
			goTo(p, Core.zonePoint(Core.pick({ "Lobby", "JewelryShop", "Casino", "Plaza" })), 8)
		else
			wander(p)
		end
		return
	end
	-- gather evidence: ask a witness, look at the scene
	local evs = {}
	for _, ev in ipairs(Evidence.journalFor(p.id)) do
		if ev.incident == inc.id and #ev.suspects > 0 then
			table.insert(evs, ev)
		end
	end
	if #evs < 2 and (p.bot.askedInc ~= inc.id) then
		local s = Evidence.nearestStaff(Core.pos(p) or Vector3.zero, 1e9)
		if s then
			if near(p, s.part.Position, 9) then
				p.bot.askedInc = inc.id
				Evidence.askWitness(p, s)
			else
				goTo(p, s.part.Position, 5)
			end
			return
		end
	end
	if inc.pos and not near(p, inc.pos, 10) and #evs == 0 then
		goTo(p, inc.pos, 6)
		-- inspecting the scene: discover physical clues within reach
		return
	end
	if inc.pos and #evs == 0 then
		for _, ev in pairs(Evidence.records) do
			if ev.incident == inc.id and ev.prop and not ev.deleted then
				Evidence.discover(p, ev, true)
			end
		end
	end
	Bots.tryAccuse(p, inc, eager)
end

function Bots.tryAccuse(p, inc, eager)
	local Evidence, Accuse = Core.M.Evidence, Core.M.Accuse
	if p.accuseReadyAt > os.clock() then
		return
	end
	local counts = {}
	for _, ev in ipairs(Evidence.journalFor(p.id)) do
		if ev.incident == inc.id then
			for _, s in ipairs(ev.suspects) do
				if s ~= p.id then
					counts[s] = (counts[s] or 0) + 1
				end
			end
		end
	end
	if next(counts) == nil then
		return
	end
	if not eager and Core.rng:NextNumber() > 0.35 then
		return
	end
	local target
	local bias = p.botAccuseBias
	if bias and Core.rng:NextNumber() < 0.7 then
		if bias.accused and Core.participants[bias.accused] then
			target = bias.accused
		else
			local opts = {}
			for s in pairs(counts) do
				if s ~= inc.culprit then
					table.insert(opts, s)
				end
			end
			target = Core.pick(opts)
		end
	end
	if not target then
		if inc.culprit and counts[inc.culprit] and Core.rng:NextNumber() < Config.BotAccuseCorrectChance then
			target = inc.culprit
		else
			local opts = {}
			for s in pairs(counts) do
				table.insert(opts, s)
			end
			target = Core.pick(opts)
		end
	end
	if target and target ~= p.id then
		Accuse.accuse(p, target, inc.id)
	end
end

function Bots.decideRequest(bot, from, req)
	if req.kind == "Give" then
		return Core.itemCount(bot) < Config.MaxCarry
	end
	if req.kind == "Trade" then
		return Core.rng:NextNumber() < 0.5
	end
	if req.kind == "Follow" then
		local accept = Core.rng:NextNumber() < 0.6
		return accept
	end
	return Core.rng:NextNumber() < 0.7 -- TeamUp
end

---------------------------------------------------------------- think loop
local function currentObjective(p)
	local Secrets = Core.M.Secrets
	local st = Secrets and Secrets.get(p)
	if not st then
		return nil
	end
	for _, slot in ipairs({ "main", "side" }) do
		local o = st[slot]
		if o and not o.done and not o.failed and not o.pendingEnd and o.conds[o.step] then
			return o, o.conds[o.step]
		end
	end
	return nil
end

local function think(p)
	local b = p.bot
	if not p.model or not p.model.Parent or not Core.alive(p) then
		return
	end
	if Core.isDetained(p) then
		Nav.stop(b.nav)
		return
	end
	if p.hidden then
		if os.clock() > (b.hideOut or 0) and Core.M.Interact then
			Core.M.Interact.unhide(p)
		end
		return
	end
	if b.cool and b.cool > os.clock() then
		return
	end
	if not Core.inPlay() then
		-- lobby: mingle near the plaza
		if Core.phase == "Lobby" or Core.phase == "Intro" then
			if (b.wanderUntil or 0) < os.clock() then
				goTo(p, Core.zonePoint("Plaza"), 8)
				b.wanderUntil = os.clock() + Core.rng:NextNumber(6, 12)
			end
		end
		return
	end
	-- forced goals (kitchen fire exit, lures, follow requests)
	if p.botForceGoal then
		goTo(p, p.botForceGoal, 6)
		if near(p, p.botForceGoal, 8) then
			p.botForceGoal = nil
		end
		return
	end
	-- being chased: hide or run
	if p.wantedUntil and p.wantedUntil > os.clock() then
		local Interact = Core.M.Interact
		local spot = nearestPart(p, Core.interactParts("Hide"))
		if spot and Interact and near(p, spot.Position, 30) and b.personality < 0.7 then
			if near(p, spot.Position, 8) then
				b.hideOut = os.clock() + Core.rng:NextNumber(8, 15)
				Interact.use(p, spot, {})
			else
				goTo(p, spot.Position, 4)
			end
			return
		end
		-- disguise if possible
		if Core.hasItem(p, "StaffUniform") and Interact then
			Interact.disguise(p)
			return
		end
	end
	if p.botLure and p.botLure.untilT > os.clock() then
		goTo(p, Core.zonePoint(p.botLure.zone), 6)
		if p.zone == p.botLure.zone then
			p.botLure = nil
			b.cool = os.clock() + 6
		end
		return
	end
	if p.botFollow and p.botFollow.untilT > os.clock() then
		local t = Core.participants[p.botFollow.id]
		if t then
			goTo(p, Core.pos(t), 6)
			return
		end
	end
	-- occasional investigation by anyone holding evidence
	if os.clock() - (b.lastAccuseCheck or 0) > 20 then
		b.lastAccuseCheck = os.clock()
		local Evidence = Core.M.Evidence
		if Evidence then
			for i = #Evidence.incidents, 1, -1 do
				local inc = Evidence.incidents[i]
				if not inc.solved and inc.culprit ~= p.id and not (p.accusedIncidents and p.accusedIncidents[inc.id]) then
					Bots.tryAccuse(p, inc, false)
					break
				end
			end
		end
	end
	local o, c = currentObjective(p)
	if not o then
		-- all done: socialise / investigate
		if Core.rng:NextNumber() < 0.5 then
			Bots.investigate(p, false)
		else
			doTalk(p, nil)
		end
		return
	end
	local fn = CONDS[c.t]
	if fn then
		fn(p, c, o)
	else
		wander(p)
	end
end
Bots.think = think

---------------------------------------------------------------- chatter (speech bubbles)
-- Bots never said anything, so 1-player servers felt dead (first-10-min review, top 5). A small BillboardGui
-- bubble over the head: greetings when a real player comes close, reactions to events, idle gossip.
local LINES = {
	greet = { "hey %s!", "oh hi %s 👋", "%s!! wassup", "hii %s", "yo %s" },
	idle = { "this resort is so sus 👀", "anyone seen the golden statue?", "I'm totally not hiding anything 😇",
		"the arcade is fun ngl", "who keeps stealing stuff??", "everyone here has a secret...", "act normal act normal",
		"I saw someone near the jewelry shop 🤔", "the pool is the best spot", "what's YOUR secret? 😏" },
	done = { "hehe done 😎", "nobody saw that right?", "mission complete 🤫" },
	detained = { "I'M INNOCENT 😭", "this is a setup!!", "not fair 😤" },
	event = { "WHOA what was that?!", "did you see that??", "uh oh 😳" },
}
local function pick(t)
	return t[Core.rng:NextInteger(1, #t)]
end
function Bots.say(p, text)
	local c = p and Core.char(p)
	local head = c and c:FindFirstChild("Head")
	if not head or not text or text == "" then
		return
	end
	local old = head:FindFirstChild("BotBubble")
	if old then
		old:Destroy()
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "BotBubble"
	bb.Size = UDim2.fromOffset(220, 46)
	bb.StudsOffset = Vector3.new(0, 3.6, 0)
	bb.MaxDistance = 70
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	local fr = Instance.new("TextLabel")
	fr.Size = UDim2.fromScale(1, 1)
	fr.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	fr.BackgroundTransparency = 0.05
	fr.TextColor3 = Color3.fromRGB(30, 30, 40)
	fr.Font = Enum.Font.GothamBold
	fr.TextScaled = true
	fr.TextWrapped = true
	fr.Text = text
	local cr = Instance.new("UICorner")
	cr.CornerRadius = UDim.new(0, 12)
	cr.Parent = fr
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
	pad.Parent = fr
	local lim = Instance.new("UITextSizeConstraint")
	lim.MaxTextSize = 22
	lim.Parent = fr
	fr.Parent = bb
	bb.Parent = head
	game:GetService("Debris"):AddItem(bb, 4)
end
local lastSay = {} -- bot id -> clock
local greeted = {} -- bot id .. ":" .. player id -> true (per round)
local function canSay(p, gap)
	if os.clock() - (lastSay[p.id] or 0) < (gap or 8) then
		return false
	end
	lastSay[p.id] = os.clock()
	return true
end
Bots.LINES = LINES
local function chatterTick()
	local players = {}
	for _, q in pairs(Core.participants) do
		if not q.isBot then
			table.insert(players, q)
		end
	end
	if #players == 0 then
		return
	end
	for _, b in pairs(Bots.list) do
		local bp = Core.pos(b)
		if bp and not b.hidden and Core.alive(b) then
			-- greet a real player who walks up (once per round per pair)
			local said = false
			for _, q in ipairs(players) do
				local qp = Core.pos(q)
				local key = b.id .. ":" .. q.id
				if qp and not greeted[key] and (qp - bp).Magnitude < 14 and canSay(b, 6) then
					greeted[key] = true
					Bots.say(b, pick(LINES.greet):format(q.name))
					faceTowards(b, qp)
					said = true
					break
				end
			end
			-- rare idle line, only when a real player is close enough to read it
			if not said and Core.inPlay() and Core.rng:NextNumber() < 0.04 then
				for _, q in ipairs(players) do
					local qp = Core.pos(q)
					if qp and (qp - bp).Magnitude < 45 and canSay(b, 25) then
						Bots.say(b, pick(LINES.idle))
						break
					end
				end
			end
		end
	end
end

function Bots.init()
	Bus.on("PhaseChanged", function(phase)
		if phase == "Intro" then
			table.clear(greeted)
		end
	end)
	Bus.on("SecretCompleted", function(p)
		if p and p.isBot and Core.rng:NextNumber() < 0.5 and canSay(p, 5) then
			Bots.say(p, pick(LINES.done))
		end
	end)
	Bus.on("Detained", function(p)
		if p and p.isBot and canSay(p, 2) then
			Bots.say(p, pick(LINES.detained))
		end
	end)
	Bus.on("EventStarted", function()
		for _, b in pairs(Bots.list) do
			if Core.rng:NextNumber() < 0.35 and canSay(b, 3) then
				Bots.say(b, pick(LINES.event))
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			pcall(chatterTick)
		end
	end)
	Bus.on("ParticipantRemoving", function(p)
		for _, b in pairs(Bots.list) do
			if b.botFollow and b.botFollow.id == p.id then
				b.botFollow = nil
			end
		end
	end)
	-- movement step (0.2 s) + think (0.5 s)
	task.spawn(function()
		local last = os.clock()
		local acc = 0
		while true do
			task.wait(0.2)
			local now = os.clock()
			local dt = now - last
			last = now
			acc += dt
			local doThink = acc >= Config.BotThinkInterval
			if doThink then
				acc = 0
			end
			local lost = false
			for id, p in pairs(Bots.list) do
				if not (p.model and p.model.Parent) then
					-- fell out of the world / destroyed: replace it between rounds (never mid-round)
					if Core.phase == "Lobby" or Core.phase == "Rewards" then
						pcall(Bots.despawn, id)
						lost = true
					end
				elseif p.model and p.model.Parent then
					if not p.hidden and not Core.isDetained(p) then
						pcall(Nav.step, p.bot.nav, dt)
					end
					pcall(Anim.autoLoco, p.model)
					if doThink then
						local ok, err = pcall(think, p)
						if not ok then
							warn("[Bots] " .. p.name .. ": " .. tostring(err))
						end
					end
				end
			end
			if lost then
				pcall(Bots.rebalance)
			end
		end
	end)
end

return Bots
