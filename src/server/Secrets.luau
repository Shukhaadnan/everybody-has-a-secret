-- Secrets.luau — assigns MAIN + SIDE secrets each round (SecretDB generator, tutorial for first-timers,
-- start items), tracks progress purely from server Bus events + server polling, and finalizes at round
-- end (END conditions, rewards, stats, reveal rows + story). The client can never claim completion.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
local Bus = require(script.Parent.Bus)
local Core = require(script.Parent.Core)
local SecretDB = require(script.Parent.SecretDB)

local Secrets = {}
Secrets.state = {} -- pid -> {main, side, role, tutorial, rerollsLeft, chain, highlights}
Secrets.chains = {}
Secrets.recent = {} -- pid -> {templateIds} (bots + players; players also persisted in profile.recent)
Secrets.forcedEvents = {}
Secrets.pendingReroll = {} -- pid -> slot (awaiting Robux receipt)

local END = SecretDB.END_CONDS
local SOCIAL_CONDS = { talk = true, follow = true, makeEnter = true, ally = true, convinceAccuse = true, giveCoins = true, getCoins = true, giveItem = true, receiveItem = true }
local THEFT_CONDS = { steal = true, escape = true }

---------------------------------------------------------------- helpers
local function rngFn()
	local r = Core.rng
	return function(a, b)
		if a == nil then
			return r:NextNumber()
		end
		if b == nil then
			return r:NextInteger(1, a)
		end
		return r:NextInteger(a, b)
	end
end
Secrets.rngFn = rngFn

local function zonesForGen()
	local Z = Core.Zones
	local z = { list = {}, byId = {} }
	if Z and type(Z.list) == "table" then
		for _, e in ipairs(Z.list) do
			table.insert(z.list, e)
			z.byId[e.id] = e
		end
	end
	if Core.M.Interact then
		z.hideZones = Core.M.Interact.hideZones()
	end
	return z
end

local function stateOf(p)
	return p and Secrets.state[p.id]
end

local function curCond(o)
	if not o or o.done or o.failed then
		return nil
	end
	return o.conds[o.step]
end

local function sendSecret(p)
	local st = stateOf(p)
	if not st or p.isBot then
		return
	end
	Core.send(p, "YourSecret", {
		main = SecretDB.public(st.main),
		side = (st.side and not st.side.hidden) and SecretDB.public(st.side) or nil,
		role = st.role,
		beginner = st.beginner == true,
		reward = Secrets.potentialReward(st),
		rerollsLeft = st.rerollsLeft,
		-- once a bonus secret replaced the tutorial side, the client coach should wrap up (tutorial already done)
		tutorial = st.tutorial == true and not st.bonusCount,
	})
end
Secrets.sendSecret = sendSecret

local function sendProgress(p, slot)
	local st = stateOf(p)
	if not st or p.isBot then
		return
	end
	if st[slot] and st[slot].hidden then
		return
	end
	Core.send(p, "SecretProgress", { slot = slot, obj = SecretDB.public(st[slot]) })
end

function Secrets.rewardFor(o, slot)
	local r = Config.TierReward[o.tier] or Config.TierReward.Easy
	local f = slot == "side" and Config.SideFactor or 1
	return math.floor(r.coins * f), math.floor(r.xp * f)
end
function Secrets.potentialReward(st)
	local a = Secrets.rewardFor(st.main, "main")
	if st.side and st.side.hidden then
		return a
	end
	local b = Secrets.rewardFor(st.side, "side")
	return a + b
end

local function addHighlight(p, text)
	local st = stateOf(p)
	if st then
		st.highlights = st.highlights or {}
		if #st.highlights < 6 and not table.find(st.highlights, text) then
			table.insert(st.highlights, text)
		end
	end
end
Secrets.addHighlight = addHighlight

-- index of the first non-END cond at/after i
local function nextActive(o, i)
	while o.conds[i] and END[o.conds[i].t] do
		i += 1
	end
	return i
end

local function setupCond(p, o)
	local c = curCond(o)
	if not c then
		return
	end
	o.cs = { set = {}, n = 0 }
	local mx = SecretDB.progressMax(c)
	o.progress = mx and { cur = 0, max = mx } or nil
	o.hintZone = SecretDB.hintFor(o)
	if c.t == "follow" and c.target and Core.M.Social then
		Core.M.Social.setFollowWatch(p.id, c.target, true)
	end
end

local function complete(p, o, slot)
	o.done = true
	o.progress = o.progress and { cur = o.progress.max, max = o.progress.max } or nil
	o.hintZone = nil
	local coins = Secrets.rewardFor(o, slot)
	Core.toast(p, ("✅ %s SECRET COMPLETE! (+%d 🪙 at round end)"):format(slot == "main" and "MAIN" or "SIDE", coins), "good", "Complete")
	addHighlight(p, (slot == "main" and "Main: " or "Side: ") .. SecretDB.shortOf(o))
	Bus.fire("SecretCompleted", p, slot, o)
end

local function failObj(p, o, slot, why)
	if o.done or o.failed then
		return
	end
	o.failed = true
	o.hintZone = nil
	Core.toast(p, ("❌ %s secret failed%s"):format(slot == "main" and "Main" or "Side", why and (": " .. why) or "."), "bad", "Fail")
	sendProgress(p, slot)
	Bus.fire("SecretFailed", p, slot, o)
end

-- step finished
local function advance(p, o, slot)
	local c = curCond(o)
	if c and c.t == "follow" and c.target and Core.M.Social then
		Core.M.Social.setFollowWatch(p.id, c.target, false)
	end
	local nxt = nextActive(o, o.step + 1)
	if o.conds[nxt] then
		o.step = nxt
		setupCond(p, o)
		Core.toast(p, ("➡️ Next step: %s"):format(o.steps[math.min(o.step, #o.steps)] or o.text), "good", "Progress")
		sendProgress(p, slot)
		return
	end
	-- only END conds remain (or none)
	local hasEnd = false
	for _, cc in ipairs(o.conds) do
		if END[cc.t] then
			hasEnd = true
		end
	end
	if hasEnd then
		o.step = #o.conds + 1
		o.pendingEnd = true
		o.progress = nil
		o.hintZone = nil
		Core.toast(p, "⏳ Almost there — keep it that way until the round ends!", "good", "Progress")
		sendProgress(p, slot)
	else
		o.step = #o.conds
		complete(p, o, slot)
		sendProgress(p, slot)
	end
end

local function bump(p, o, slot, n, key)
	if key ~= nil then
		if o.cs.set[key] then
			return
		end
		o.cs.set[key] = true
	end
	o.cs.n += n or 1
	if o.progress then
		o.progress.cur = math.min(o.progress.max, math.floor(o.cs.n))
	end
	local c = curCond(o)
	local mx = SecretDB.progressMax(c) or 1
	if o.cs.n >= mx then
		advance(p, o, slot)
	else
		sendProgress(p, slot)
	end
end

-- iterate active (current-step) conds of type t for participant p: fn(o, slot, c)
local function eachCur(p, t, fn)
	local st = stateOf(p)
	if not st then
		return
	end
	for _, slot in ipairs({ "main", "side" }) do
		local o = st[slot]
		local c = curCond(o)
		if c and c.t == t and not o.pendingEnd then
			fn(o, slot, c)
		end
	end
end
-- iterate END/watch conds of type t anywhere in an unfinished objective
local function eachWatch(p, t, fn)
	local st = stateOf(p)
	if not st then
		return
	end
	for _, slot in ipairs({ "main", "side" }) do
		local o = st[slot]
		if o and not o.done and not o.failed then
			for _, c in ipairs(o.conds) do
				if c.t == t then
					fn(o, slot, c)
				end
			end
		end
	end
end
local function everyone(fn)
	for pid, st in pairs(Secrets.state) do
		local p = Core.participants[pid]
		if p then
			fn(p, st)
		end
	end
end

---------------------------------------------------------------- assignment
function Secrets.participantsForGen()
	local out = {}
	for _, p in ipairs(Core.list(true)) do
		table.insert(out, { id = p.id, name = p.name, isBot = p.isBot })
	end
	return out
end

local function giveStartItems(p, o)
	for _, it in ipairs(o.startItems or {}) do
		if not Core.hasItem(p, it) then
			Core.giveItem(p, it)
		end
	end
end

-- Beginner round (first rounds after the tutorial): ONE simple secret.
-- Story-chain objectives are kept (other players' secrets depend on them); otherwise a Hard/Legendary main
-- is swapped for an Easy one and the side secret becomes hidden + inert (not shown, not rewarded, not in reveal).
Secrets.zonesForGen = zonesForGen
Secrets.rngFn = rngFn
function Secrets.beginnerize(a, parts, recent, pid)
	local rank = { Easy = 1, Medium = 2, Hard = 3, Legendary = 4 }
	local out = { main = a.main, side = a.side, role = a.role, chain = a.chain }
	if not a.main.chain and (rank[a.main.tier] or 1) > 2 then
		local okR, nu = pcall(SecretDB.reroll, parts, zonesForGen(), rngFn(), recent, pid, "main", { tier = "Easy", templateId = a.main.templateId })
		if okR and nu then
			out.main = nu
			out.role = nu.role
		end
	end
	-- always hide the side for beginners (a chain side like "someone wants to frame you" is passive/confusing;
	-- other players' chain objectives have their own conds, so hiding it never breaks their story)
	local side = table.clone(a.side)
	side.conds = {}
	side.hidden = true
	out.side = side
	return out
end

-- S1: objectives that need an event (eventZone, e.g. THE THRILL SEEKER's Storm) make sure it happens.
local function eventsNeeded(o, out)
	for _, c in ipairs((o and not o.hidden and o.conds) or {}) do
		if c.t == "eventZone" and c.event and not table.find(out, c.event) then
			table.insert(out, c.event)
		end
	end
	return out
end
-- reroll / late assignment during Intro or Play: schedule the event if it isn't still coming or running
function Secrets.ensureEvents(o)
	local Events = Core.M.Events
	for _, id in ipairs(eventsNeeded(o, {})) do
		if not table.find(Secrets.forcedEvents, id) then
			table.insert(Secrets.forcedEvents, id)
		end
		if Events and (Core.phase == "Intro" or Core.phase == "Play") and not Events.isActive(id) then
			local coming = false
			for _, s in ipairs(Events.schedule) do
				if s.id == id and not s.started then
					coming = true
				end
			end
			if not coming then
				local at = math.min(Config.FirstEventAfter, Config.PlayTime * 0.3)
				if Core.phase == "Play" then
					local el = Core.elapsed()
					at = math.min(el + 60, math.max(el + 5, Config.PlayTime - 90))
				end
				table.insert(Events.schedule, { id = id, at = at, started = false })
			end
		end
	end
end

function Secrets.assignAll()
	Secrets.state = {}
	Secrets.pendingReroll = {} -- a cancelled prompt from last round must not pick this round's slot
	local parts = Secrets.participantsForGen()
	local Data = Core.M.Data
	-- recent ids: players from profile, bots from memory
	local recent = {}
	for _, e in ipairs(parts) do
		local p = Core.participants[e.id]
		if p and not p.isBot and Data then
			local prof = Data.get(p.player)
			recent[e.id] = prof and prof.recent or Secrets.recent[e.id]
		else
			recent[e.id] = Secrets.recent[e.id]
		end
	end
	-- first-time (tutorial) and beginner players: known before casting so they get the easier story roles
	local isTutorial, isBeginner = {}, {}
	for _, e in ipairs(parts) do
		local p = Core.participants[e.id]
		local prof = (p and not p.isBot and Data) and Data.get(p.player) or nil
		if prof and not prof.tutorialDone then
			isTutorial[e.id] = true
		elseif prof then
			local played = prof.stats and tonumber(prof.stats.roundsPlayed) or 0
			-- the tutorial round counts as round 1, so beginners are rounds 2..(1 + BeginnerRounds)
			isBeginner[e.id] = played <= (Config.BeginnerRounds or 0)
		end
	end
	local easy = {}
	for id in pairs(isTutorial) do
		easy[id] = true
	end
	for id, b in pairs(isBeginner) do
		easy[id] = b or nil
	end
	local res = SecretDB.generate(parts, zonesForGen(), rngFn(), recent, { beginners = easy })
	Secrets.chains = res.chains
	Secrets.forcedEvents = res.forcedEvents
	for pid, r in pairs(res.recent) do
		Secrets.recent[pid] = r
		local p = Core.participants[pid]
		if p and not p.isBot and Data then
			local prof = Data.get(p.player)
			if prof then
				prof.recent = r
			end
		end
	end
	for _, e in ipairs(parts) do
		local p = Core.participants[e.id]
		local a = res.assignments[e.id]
		local tutorial = isTutorial[e.id] == true
		local beginner = false
		if tutorial then
			local m, s = SecretDB.tutorial()
			a = { main = m, side = s, role = "THE NEWCOMER" }
		else
			beginner = isBeginner[e.id] == true
		end
		if beginner then
			a = Secrets.beginnerize(a, parts, recent, e.id)
			print("[EHAS] beginner round (one secret) for " .. tostring(e.name or e.id))
		end
		Secrets.state[e.id] = {
			main = a.main,
			side = a.side,
			role = a.role or a.main.role,
			chain = a.chain,
			tutorial = tutorial,
			beginner = beginner,
			rerollsLeft = Config.MaxRerollsPerRound,
			highlights = {},
		}
		for _, slot in ipairs({ "main", "side" }) do
			local o = a[slot]
			o.slot = slot
			o.step = nextActive(o, 1)
			if not o.conds[o.step] then
				o.pendingEnd = true
			end
			setupCond(p, o)
		end
	end
	-- force the events that assigned objectives need (planRound reads Secrets.forcedEvents next)
	for _, st in pairs(Secrets.state) do
		eventsNeeded(st.main, Secrets.forcedEvents)
		eventsNeeded(st.side, Secrets.forcedEvents)
	end
	return res
end

function Secrets.startRound()
	for pid, st in pairs(Secrets.state) do
		local p = Core.participants[pid]
		if p then
			giveStartItems(p, st.main)
			if not st.side.hidden then
				giveStartItems(p, st.side)
			end
			sendSecret(p)
			Core.sfx(p, "SecretGet")
		end
	end
end

-- late joiner during Play: a solo secret (never part of chains, never targeted).
-- First-timers get the tutorial secret, beginners ONE Easy secret (same rules as assignAll), and nobody gets a
-- fresh secret with under 90 s left (they spectate the reveal and start clean next round).
Secrets.LATE_MIN_LEFT = 90
function Secrets.assignLate(p)
	if Secrets.timeLeft() < Secrets.LATE_MIN_LEFT then
		Core.toast(p, "👀 Round almost over: watch the reveal, your secret comes next round!", "info")
		return false
	end
	local Data = Core.M.Data
	local prof = (not p.isBot and Data and p.player) and Data.get(p.player) or nil
	if prof and not prof.tutorialDone then
		local m, s = SecretDB.tutorial()
		Secrets.state[p.id] = { main = m, side = s, role = "THE NEWCOMER", tutorial = true, rerollsLeft = Config.MaxRerollsPerRound, highlights = {} }
		for _, o in ipairs({ m, s }) do
			o.step = nextActive(o, 1)
			setupCond(p, o)
		end
		sendSecret(p)
		return true
	end
	local played = prof and prof.stats and tonumber(prof.stats.roundsPlayed) or math.huge
	local beginner = played <= (Config.BeginnerRounds or 0)
	local parts = Secrets.participantsForGen()
	local found = false
	for _, e in ipairs(parts) do
		if e.id == p.id then
			found = true
		end
	end
	if not found then
		table.insert(parts, { id = p.id, name = p.name, isBot = p.isBot })
	end
	-- late joiners never get Legendary; beginners always Easy
	local main = SecretDB.reroll(parts, zonesForGen(), rngFn(), Secrets.recent, p.id, "main", beginner and { tier = "Easy" } or nil)
	if main.tier == "Legendary" or (Secrets.timeLeft() < 200 and main.tier == "Hard") then
		main = SecretDB.reroll(parts, zonesForGen(), rngFn(), Secrets.recent, p.id, "main", { tier = "Medium", templateId = main.templateId })
	end
	local side = SecretDB.reroll(parts, zonesForGen(), rngFn(), Secrets.recent, p.id, "side", { tier = "Easy", templateId = main.templateId })
	main.slot, side.slot = "main", "side"
	if beginner then
		side.conds = {}
		side.hidden = true
	end
	Secrets.state[p.id] = { main = main, side = side, role = main.role, beginner = beginner, rerollsLeft = Config.MaxRerollsPerRound, highlights = {} }
	for _, o in ipairs({ main, side }) do
		o.step = nextActive(o, 1)
		setupCond(p, o)
	end
	giveStartItems(p, main)
	giveStartItems(p, side)
	Secrets.ensureEvents(main)
	Secrets.ensureEvents(side)
	sendSecret(p)
end

function Secrets.reroll(p, slot)
	local st = stateOf(p)
	if not st or (slot ~= "main" and slot ~= "side") then
		return false
	end
	if st.tutorial then
		Core.toast(p, "Finish the tutorial secret first!", "info")
		return false
	end
	if st.rerollsLeft <= 0 then
		Core.toast(p, "No rerolls left this round.", "bad")
		return false
	end
	local o = st[slot]
	if o.hidden then
		return false
	end
	if o.done or o.failed then
		Core.toast(p, "That secret is already finished.", "info")
		return false
	end
	local c = curCond(o)
	if c and c.t == "follow" and c.target and Core.M.Social then
		Core.M.Social.setFollowWatch(p.id, c.target, false)
	end
	local nu = SecretDB.reroll(Secrets.participantsForGen(), zonesForGen(), rngFn(), Secrets.recent, p.id, slot, o)
	nu.slot = slot
	nu.step = nextActive(nu, 1)
	st[slot] = nu
	if slot == "main" then
		st.role = nu.role
	end
	setupCond(p, nu)
	st.rerollsLeft -= 1
	giveStartItems(p, nu)
	Secrets.ensureEvents(nu)
	sendSecret(p)
	Core.toast(p, "🎲 New secret!", "good", "SecretGet")
	return true
end

-- install a specific objective (SelfTest / admin): same setup path as assignment
function Secrets.setObjective(p, slot, o)
	local st = Secrets.state[p.id]
	if not st then
		local filler = { id = "none", tier = "Easy", text = "-", steps = {}, conds = {} }
		st = { main = filler, side = table.clone(filler), role = "THE GUEST", rerollsLeft = 0, highlights = {} }
		Secrets.state[p.id] = st
	end
	o.slot = slot
	o.steps = o.steps or {}
	o.tier = o.tier or "Easy"
	o.short = SecretDB.shortOf(o)
	o.done, o.failed, o.pendingEnd = nil, nil, nil
	o.step = nextActive(o, 1)
	if not o.conds[o.step] then
		o.pendingEnd = true
	end
	st[slot] = o
	setupCond(p, o)
	return o
end

function Secrets.frameTargetOf(p)
	local st = stateOf(p)
	if not st then
		return nil
	end
	for _, slot in ipairs({ "main", "side" }) do
		local c = curCond(st[slot])
		if c and c.t == "frame" then
			return c.target
		end
	end
	return nil
end

-- objectives of p that target someone (bots use it)
function Secrets.get(p)
	return stateOf(p)
end

---------------------------------------------------------------- event handlers
local function onEvents()
	Bus.on("Stolen", function(p, itemId)
		p.stolenThisRound = p.stolenThisRound or {}
		p.stolenThisRound[itemId] = true
		eachCur(p, "steal", function(o, slot, c)
			if c.item == nil or c.item == itemId then
				advance(p, o, slot)
			end
		end)
		addHighlight(p, "Stole the " .. Core.itemName(itemId))
	end)
	Bus.on("ItemHidden", function(p, itemId, zone)
		p.hiddenThisRound = p.hiddenThisRound or {}
		table.insert(p.hiddenThisRound, { item = itemId, zone = zone })
		eachCur(p, "hide", function(o, slot, c)
			if (c.item == nil or c.item == itemId) and (c.zone == nil or c.zone == zone) then
				advance(p, o, slot)
			end
		end)
		if itemId == "GoldenStatue" or itemId == "DiamondNecklace" or itemId == "Briefcase" then
			addHighlight(p, ("Hid the %s in the %s"):format(Core.itemName(itemId), Core.zoneName(zone)))
		end
	end)
	Bus.on("Dig", function(p)
		eachCur(p, "dig", function(o, slot)
			bump(p, o, slot, 1)
		end)
	end)
	Bus.on("Interacted", function(p, kind, part, zone)
		eachCur(p, "interact", function(o, slot, c)
			if c.kind == kind and (c.zone == nil or c.zone == zone) then
				bump(p, o, slot, 1, c.kind == "Note" and part or nil)
			end
		end)
	end)
	Bus.on("Talked", function(a, b)
		eachCur(a, "talk", function(o, slot, c)
			if c.target == nil or c.target == b.id then
				bump(a, o, slot, 1, b.id)
			end
		end)
	end)
	Bus.on("Following", function(f, t, secs)
		eachCur(f, "follow", function(o, slot, c)
			if c.target == t.id then
				local cur = math.floor(secs)
				if o.progress and o.progress.cur ~= cur then
					o.progress.cur = math.min(o.progress.max, cur)
					if cur % 5 == 0 then
						sendProgress(f, slot)
					end
				end
				if secs >= c.seconds then
					advance(f, o, slot)
				end
			end
		end)
	end)
	Bus.on("Spotted", function(f, t, secs)
		eachCur(f, "follow", function(o, slot, c)
			if c.target == t.id and o.progress then
				o.progress.cur = math.floor(secs)
				sendProgress(f, slot)
			end
		end)
	end)
	Bus.on("CoinsGiven", function(from, to, amount)
		eachCur(from, "giveCoins", function(o, slot, c)
			if c.target == nil or c.target == to.id then
				bump(from, o, slot, amount)
			end
		end)
		eachCur(to, "getCoins", function(o, slot)
			bump(to, o, slot, amount)
		end)
	end)
	Bus.on("ItemGiven", function(from, to, itemId)
		eachCur(from, "giveItem", function(o, slot, c)
			if (c.item == nil or c.item == itemId) and (c.target == nil or c.target == to.id) then
				advance(from, o, slot)
			end
		end)
		eachCur(to, "receiveItem", function(o, slot, c)
			if c.item == nil or c.item == itemId then
				advance(to, o, slot)
			end
		end)
		if itemId == "SecretLetter" or itemId == "VIPKeycard" then
			addHighlight(from, ("Handed the %s to %s"):format(Core.itemName(itemId), to.name))
		end
	end)
	Bus.on("Accused", function(accuser, target, inc, correct)
		eachCur(accuser, "accuse", function(o, slot, c)
			if correct and (c.item == nil or c.item == inc.item) then
				advance(accuser, o, slot)
			end
		end)
		if correct then
			addHighlight(accuser, ("Caught %s (%s)"):format(target.name, inc.title))
		else
			addHighlight(accuser, ("Wrongly accused %s"):format(target.name))
		end
		-- manipulators: someone whose secret is "make <accuser> accuse ..."
		everyone(function(p)
			eachCur(p, "convinceAccuse", function(o, slot, c)
				if c.target == accuser.id then
					local ok
					if c.accused then
						ok = target.id == c.accused
					else
						ok = (not correct) and (c.item == nil or c.item == inc.item)
					end
					if ok then
						addHighlight(p, ("Made %s accuse %s"):format(accuser.name, target.name))
						advance(p, o, slot)
					end
				end
			end)
		end)
		eachWatch(target, "notAccused", function(o, slot)
			failObj(target, o, slot, "someone accused you")
		end)
	end)
	Bus.on("Photo", function(p, q, caughtId, zone)
		eachCur(p, "photo", function(o, slot, c)
			local ok = true
			if c.item and caughtId ~= c.item then
				ok = false
			end
			if c.target and q.id ~= c.target then
				ok = false
			end
			if c.zone and zone ~= c.zone then
				ok = false
			end
			if ok then
				if caughtId then
					addHighlight(p, ("Photographed %s with the %s"):format(q.name, Core.itemName(caughtId)))
				end
				advance(p, o, slot)
			end
		end)
	end)
	Bus.on("FootageDeleted", function(p)
		eachCur(p, "deleteFootage", function(o, slot)
			bump(p, o, slot, 1)
		end)
		addHighlight(p, "Deleted security footage")
	end)
	Bus.on("CamDisabled", function(p)
		eachCur(p, "disableCam", function(o, slot)
			bump(p, o, slot, 1)
		end)
		addHighlight(p, "Disabled a camera")
	end)
	Bus.on("Trigger", function(p, ev)
		eachCur(p, "trigger", function(o, slot, c)
			if c.event == ev then
				advance(p, o, slot)
			end
		end)
		if ev == "PowerOutage" then
			addHighlight(p, "Cut the power")
		elseif ev == "Prank" then
			addHighlight(p, "Prank-called security")
		end
	end)
	Bus.on("Detained", function(p)
		eachCur(p, "detained", function(o, slot)
			advance(p, o, slot)
		end)
		eachWatch(p, "notDetained", function(o, slot)
			failObj(p, o, slot, "you got detained")
		end)
		everyone(function(q)
			eachWatch(q, "protect", function(o, slot, c)
				if c.target == p.id then
					failObj(q, o, slot, p.name .. " got detained")
				end
			end)
		end)
		addHighlight(p, "Got detained by security")
	end)
	Bus.on("Escape", function(p, ids)
		eachCur(p, "escape", function(o, slot, c)
			if c.item == nil or table.find(ids, c.item) then
				advance(p, o, slot)
			end
		end)
		addHighlight(p, "Escaped by boat")
	end)
	Bus.on("Allied", function(a, b)
		eachCur(a, "ally", function(o, slot, c)
			if c.target == b.id then
				advance(a, o, slot)
			end
		end)
		eachCur(b, "ally", function(o, slot, c)
			if c.target == a.id then
				advance(b, o, slot)
			end
		end)
	end)
	Bus.on("Framed", function(framer, targetId)
		eachCur(framer, "frame", function(o, slot, c)
			if c.target == nil or c.target == targetId then
				advance(framer, o, slot)
			end
		end)
		addHighlight(framer, "Framed " .. Core.nameOf(targetId))
	end)
	Bus.on("Bribed", function(p)
		eachCur(p, "bribe", function(o, slot)
			advance(p, o, slot)
		end)
		addHighlight(p, "Bribed a witness")
	end)
	Bus.on("CasinoWin", function(p, amount)
		eachCur(p, "winCoins", function(o, slot)
			bump(p, o, slot, amount)
		end)
	end)
	Bus.on("Buy", function(p, shopId)
		eachCur(p, "buy", function(o, slot, c)
			if c.shop == nil or c.shop == shopId then
				advance(p, o, slot)
			end
		end)
	end)
	Bus.on("ParticipantRemoving", function(p)
		-- objectives that target the leaver become free completions (fair to the hunter)
		everyone(function(q, st)
			if q ~= p then
				for _, slot in ipairs({ "main", "side" }) do
					local o = st[slot]
					if o and not o.done and not o.failed then
						local refs = SecretDB.referencedIds(o)
						if table.find(refs, p.id) then
							Core.toast(q, ("%s left the resort — that secret counts as done."):format(p.name), "info")
							o.done = true
							o.hintZone = nil
							sendProgress(q, slot)
						end
					end
				end
			end
		end)
		Secrets.state[p.id] = nil
	end)
end

---------------------------------------------------------------- bonus secrets (no dead time)
-- When a REAL player has nothing left to do (main finished/failed, side finished/failed/hidden) and there is
-- still time, deal a fresh Easy secret into the side slot. The finished side is banked first (reward + stats),
-- so nothing is lost. Fixes "4-5 minutes of 'Act normal until the round ends'" (first-10-min review, top 1).
Secrets.BONUS_MIN_LEFT = 75 -- seconds of Play needed to deal another bonus
local function idle(o)
	return o == nil or o.hidden or o.done or o.failed
end
function Secrets.timeLeft()
	if Core.phase ~= "Play" or not Core.roundEndsAt then
		return math.huge
	end
	return Core.roundEndsAt - Core.now()
end
function Secrets.maybeBonus(p)
	local st = stateOf(p)
	if not st or p.isBot or not p.inRound or not Core.inPlay() then
		return false
	end
	if not (idle(st.main) and idle(st.side)) or (st.main and st.main.pendingEnd) then
		return false
	end
	if Secrets.timeLeft() < Secrets.BONUS_MIN_LEFT then
		return false
	end
	-- bank the finished side so its reward / story line survive the swap
	local old = st.side
	if old and old.done and not old.hidden then
		local c, x = Secrets.rewardFor(old, "side")
		if st.tutorial and tostring(old.id or ""):sub(1, 4) == "TUT_" then
			c, x = 50, 60
		end
		st.banked = st.banked or {}
		table.insert(st.banked, { label = (old.bonus and "Bonus secret (" or "Side secret (") .. tostring(old.tier) .. ")", coins = c, xp = x, tier = old.tier })
	end
	if old and old.chain then
		st.prevSide = old
	end
	local okR, nu = pcall(SecretDB.reroll, Secrets.participantsForGen(), zonesForGen(), rngFn(), Secrets.recent, p.id, "side", { tier = "Easy", templateId = old and old.templateId })
	if not okR or not nu or nu.chain then
		return false
	end
	-- an Easy bonus that targets another player can be impossible solo; one retry for a self-only one
	if #SecretDB.referencedIds(nu) > 0 then
		local ok2, nu2 = pcall(SecretDB.reroll, Secrets.participantsForGen(), zonesForGen(), rngFn(), Secrets.recent, p.id, "side", { tier = "Easy", templateId = nu.templateId })
		if ok2 and nu2 and not nu2.chain and #SecretDB.referencedIds(nu2) == 0 then
			nu = nu2
		end
	end
	nu.slot = "side"
	nu.bonus = true
	nu.step = nextActive(nu, 1)
	st.side = nu
	st.bonusCount = (st.bonusCount or 0) + 1
	setupCond(p, nu)
	giveStartItems(p, nu)
	Secrets.ensureEvents(nu)
	sendSecret(p)
	Core.toast(p, ("🔥 BONUS SECRET #%d! %s"):format(st.bonusCount, SecretDB.shortOf(nu)), "good", "SecretGet")
	return true
end
local function queueBonus(p)
	if p and not p.isBot then
		task.delay(3, function()
			pcall(Secrets.maybeBonus, p)
		end)
	end
end
Bus.on("SecretCompleted", function(p)
	queueBonus(p)
end)
Bus.on("SecretFailed", function(p)
	queueBonus(p)
end)

---------------------------------------------------------------- polling (zones / items / events)
local function poll()
	if not Core.inPlay() then
		return
	end
	local Events = Core.M.Events
	local Social = Core.M.Social
	for pid, st in pairs(Secrets.state) do
		local p = Core.participants[pid]
		if p and p.inRound then
			for _, slot in ipairs({ "main", "side" }) do
				local o = st[slot]
				-- watch: never enter
				if o and not o.done and not o.failed then
					for _, c in ipairs(o.conds) do
						if c.t == "never" and p.zone and table.find(c.zones, p.zone) then
							failObj(p, o, slot, "you entered the " .. Core.zoneName(p.zone))
						end
					end
				end
				local c = curCond(o)
				if c and not o.pendingEnd then
					local t = c.t
					if t == "zone" then
						if p.zone == c.zone then
							advance(p, o, slot)
						end
					elseif t == "zones" then
						if p.zone and table.find(c.zones, p.zone) then
							bump(p, o, slot, 1, p.zone)
						end
					elseif t == "itemAtZone" then
						if p.zone == c.zone and Core.hasItem(p, c.item) then
							advance(p, o, slot)
						end
					elseif t == "getItem" or t == "receiveItem" then
						if c.item and Core.hasItem(p, c.item) and (t == "getItem" or not table.find(o.startItems or {}, c.item)) then
							advance(p, o, slot)
						end
					elseif t == "steal" then
						local s = p.stolenThisRound
						if s and ((c.item and s[c.item]) or (not c.item and next(s) ~= nil)) then
							advance(p, o, slot)
						end
					elseif t == "hide" then
						for _, h in ipairs(p.hiddenThisRound or {}) do
							if (c.item == nil or c.item == h.item) and (c.zone == nil or c.zone == h.zone) then
								advance(p, o, slot)
								break
							end
						end
					elseif t == "eventZone" then
						if Events and Events.isActive(c.event) and p.zone == c.zone then
							advance(p, o, slot)
						end
					elseif t == "makeEnter" and Social then
						for _, q in pairs(Core.participants) do
							if q ~= p and q.inRound and q.zone == c.zone and (c.target == nil or c.target == q.id) then
								if Social.talkedRecently(p.id, q.id) then
									bump(p, o, slot, 1, q.id)
								end
							end
						end
					end
				end
			end
		end
	end
end

---------------------------------------------------------------- finalize
local function storyLine(chain)
	local parts = {}
	for _, r in ipairs(chain.roles) do
		local st = Secrets.state[r.pid]
		local o = st and st[r.slot]
		if st and r.slot == "side" and st.prevSide and st.prevSide.chain == chain.id then
			o = st.prevSide
		end
		if o then
			table.insert(parts, ("%s %s (%s)"):format(Core.nameOf(r.pid), r.role:lower(), o.done and "✅" or "❌"))
		end
	end
	if #parts == 0 then
		return nil
	end
	return chain.title .. ": " .. table.concat(parts, ", ")
end

-- returns {rows, mvp, story, results = {pid -> {coins, xp, breakdown}}}
function Secrets.finalizeRound()
	local Interact = Core.M.Interact
	-- END conditions
	for pid, st in pairs(Secrets.state) do
		local p = Core.participants[pid]
		for _, slot in ipairs({ "main", "side" }) do
			local o = st[slot]
			if o and not o.done and not o.failed then
				local endOk = true
				local hasEnd = false
				for _, c in ipairs(o.conds) do
					if END[c.t] then
						hasEnd = true
						if c.t == "pedestalEnd" then
							endOk = endOk and Interact ~= nil and Interact.pedestalHas(c.item)
						elseif c.t == "protect" then
							endOk = endOk and Core.participants[c.target] ~= nil
						end
					end
				end
				-- all non-END steps must be done (pendingEnd) or the objective has only END conds
				if hasEnd and o.pendingEnd and endOk then
					o.done = true
				elseif hasEnd and o.pendingEnd and not endOk then
					o.failed = true
				else
					o.failed = true
				end
				if p and o.done then
					addHighlight(p, (slot == "main" and "Main: " or "Side: ") .. SecretDB.shortOf(o))
				end
			end
		end
	end
	-- rewards + rows
	local rows, results = {}, {}
	local bestScore, mvp = -1, nil
	local tierRank = { Easy = 1, Medium = 2, Hard = 3, Legendary = 4 }
	for _, p in ipairs(Core.list(true)) do
		local st = Secrets.state[p.id]
		if st then
			local coins, xp, breakdown = 0, 0, {}
			for _, slot in ipairs({ "main", "side" }) do
				local o = st[slot]
				if o.done then
					local c, x = Secrets.rewardFor(o, slot)
					if st.tutorial and tostring(o.id or ""):sub(1, 4) == "TUT_" then
						c, x = 50, 60
					end
					coins += c
					xp += x
					table.insert(breakdown, { label = (slot == "main" and "Main secret (" or (o.bonus and "Bonus secret (" or "Side secret (")) .. o.tier .. ")", coins = c, xp = x })
				end
			end
			for _, b in ipairs(st.banked or {}) do
				coins += b.coins
				xp += b.xp
				table.insert(breakdown, { label = b.label, coins = b.coins, xp = b.xp })
			end
			coins += Config.ParticipationCoins
			xp += Config.ParticipationXP
			table.insert(breakdown, { label = "Played the round", coins = Config.ParticipationCoins, xp = Config.ParticipationXP })
			if (p.roundXP or 0) > 0 then
				table.insert(breakdown, { label = "Investigations", coins = 0, xp = p.roundXP })
			end
			local score = (st.main.done and 10 * tierRank[st.main.tier] or 0) + (st.side.done and 4 * tierRank[st.side.tier] or 0) + 4 * #(st.banked or {})
			for _, h in ipairs(st.highlights or {}) do
				-- only positive highlights count toward MVP (not "Wrongly accused X" / "Got detained")
				if h:sub(1, 7) ~= "Wrongly" and h:sub(1, 12) ~= "Got detained" then
					score += 1
				end
			end
			local mvpP = mvp and Core.participants[mvp]
			if score > bestScore or (score == bestScore and mvpP and (p.roundCoins or 0) > (mvpP.roundCoins or 0)) then
				bestScore, mvp = score, p.id
			end
			results[p.id] = { coins = coins, xp = xp, breakdown = breakdown, st = st }
			table.insert(rows, {
				userId = p.id,
				name = p.name,
				isBot = p.isBot,
				role = st.role,
				color = p.color,
				main = { text = SecretDB.shortOf(st.main), tier = st.main.tier, done = st.main.done == true },
				side = (not st.side.hidden) and { text = SecretDB.shortOf(st.side), tier = st.side.tier, done = st.side.done == true } or nil,
				reward = coins,
				highlights = table.clone(st.highlights or {}),
			})
		end
	end
	if mvp and results[mvp] and bestScore > 0 then
		results[mvp].coins += Config.MvpCoins
		results[mvp].xp += Config.MvpXP
		table.insert(results[mvp].breakdown, { label = "Round MVP", coins = Config.MvpCoins, xp = Config.MvpXP })
		for _, r in ipairs(rows) do
			if r.userId == mvp then
				r.reward = results[mvp].coins
			end
		end
	end
	-- sort reveal: chain roles first (story order), then others
	table.sort(rows, function(a, b)
		local sa, sb = Secrets.state[a.userId], Secrets.state[b.userId]
		local ca, cb = sa and sa.chain or "~", sb and sb.chain or "~"
		if ca ~= cb then
			return ca < cb
		end
		return a.userId < b.userId
	end)
	local storyParts = {}
	for _, ch in ipairs(Secrets.chains) do
		local s = storyLine(ch)
		if s then
			table.insert(storyParts, s)
		end
	end
	local Evidence = Core.M.Evidence
	if Evidence then
		for _, inc in ipairs(Evidence.incidents) do
			if inc.culprit then
				table.insert(storyParts, ("%s — it was %s%s."):format(inc.title, Core.nameOf(inc.culprit), inc.fled and " (fled the resort)" or inc.solved and " (caught!)" or " (never caught)"))
			end
		end
	end
	-- stats for real players
	local Progress = Core.M.Progress
	if Progress then
		for pid, res in pairs(results) do
			local p = Core.participants[pid]
			if p and not p.isBot and p.player then
				local st = res.st
				Progress.addStat(p.player, "roundsPlayed", 1)
				for _, slot in ipairs({ "main", "side" }) do
					local o = st[slot]
					if not st.tutorial then
						if o.done then
							Progress.addStat(p.player, "secretsCompleted", 1)
							Progress.addStat(p.player, slot == "main" and "mainCompleted" or "sideCompleted", 1)
							Progress.addStat(p.player, o.tier:lower() .. "Completed", 1)
							local social, theft = false, false
							for _, c in ipairs(o.conds) do
								social = social or SOCIAL_CONDS[c.t] == true
								theft = theft or THEFT_CONDS[c.t] == true
							end
							if social then
								Progress.addStat(p.player, "socialCompleted", 1)
							end
							if theft then
								Progress.addStat(p.player, "theftsCompleted", 1)
							end
						else
							Progress.addStat(p.player, "secretsFailed", 1)
						end
					end
				end
				if st.main.done then
					Progress.addStat(p.player, "roundsWon", 1)
				end
			end
		end
	end
	return { rows = rows, mvp = mvp or 0, story = table.concat(storyParts, "\n"), results = results }
end

---------------------------------------------------------------- init
function Secrets.init()
	onEvents()
	task.spawn(function()
		while true do
			task.wait(0.5)
			local ok, err = pcall(poll)
			if not ok then
				warn("[Secrets] poll: " .. tostring(err))
			end
		end
	end)
	Core.onAction("Reroll", function(player, args, p)
		local slot = args.slot
		if not p or (slot ~= "main" and slot ~= "side") then
			return
		end
		if Core.phase ~= "Intro" and not (Core.phase == "Play" and Core.elapsed() < 90) then
			Core.toast(p, "Rerolls are only available at the start of the round.", "info")
			return
		end
		local st = stateOf(p)
		if not st or st.rerollsLeft <= 0 then
			Core.toast(p, "No rerolls left this round.", "bad")
			return
		end
		-- refuse up front for slots that can't be rerolled (never charge coins or prompt Robux for nothing)
		local o = st[slot]
		if st.tutorial then
			Core.toast(p, "Finish the tutorial secret first!", "info")
			return
		end
		if not o or o.hidden then
			return
		end
		if o.done or o.failed then
			Core.toast(p, "That secret is already finished.", "info")
			return
		end
		local prod = ShopConfig.Products.SecretReroll
		if prod.ProductId and prod.ProductId > 0 then
			Secrets.pendingReroll[p.id] = slot
			pcall(function()
				MarketplaceService:PromptProductPurchase(player, prod.ProductId)
			end)
		else
			-- no Robux product configured yet: coin reroll (currency sink)
			if Core.getCoins(p) >= Config.RerollCoinCost then
				if Secrets.reroll(p, slot) then
					Core.addCoins(p, -Config.RerollCoinCost, "secret reroll")
				end
			else
				Core.toast(p, ("A reroll costs %d coins."):format(Config.RerollCoinCost), "bad")
			end
		end
	end)
	Core.onAction("TutorialDone", function(player, args, p)
		local Data = Core.M.Data
		local prof = Data and Data.get(player)
		-- only marks the tutorial overlay as seen; the tutorial SECRET is still verified by the server
		if prof then
			prof.tutorialSeen = true
		end
	end)
end

return Secrets
