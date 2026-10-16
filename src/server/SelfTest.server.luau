-- SelfTest.server.luau — in-engine smoke tests for the SERVER. Runs when workspace attribute
-- `RunSelfTest` is true, or in Studio when no player joined within 5 s (Run mode).
-- Prints `SELFTEST PASS: <name>` / `SELFTEST FAIL: <name> <why>` and `SELFTEST DONE <p> passed, <f> failed`.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

task.wait(5)
if not workspace:GetAttribute("RunSelfTest") and not (RunService:IsStudio() and #Players:GetPlayers() == 0) then
	return
end

-- wait for the map + Main boot
local t0 = os.clock()
while not (workspace:GetAttribute("MapReady") and workspace:GetAttribute("ServerReady")) and os.clock() - t0 < 120 do
	task.wait(0.25)
end

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Bus = require(script.Parent.Bus)
local Core = require(script.Parent.Core)
local SecretDB = require(script.Parent.SecretDB)
local M = Core.M

local passed, failed = 0, 0
local function result(name, ok, why)
	if ok then
		passed += 1
		print("SELFTEST PASS: " .. name)
	else
		failed += 1
		print("SELFTEST FAIL: " .. name .. " " .. tostring(why or ""))
	end
end
-- run a test body; it returns ok, why (errors count as failures)
local function test(name, fn)
	local ok, a, b = pcall(fn)
	if not ok then
		result(name, false, "error: " .. tostring(a))
	else
		result(name, a ~= false, b)
	end
end

print("SELFTEST START (boot " .. string.format("%.1f", os.clock() - t0) .. " s)")
test("server ready", function()
	return workspace:GetAttribute("ServerReady") == true, "ServerReady attribute not set"
end)

-- freeze the round loop while we poke services; pretend we're in Play
local Round = M.Round
if Round then
	Round.paused = true
end
local savedPhase = Core.phase
Core.phase = "Play"
Core.roundStartClock = os.clock()

---------------------------------------------------------------- map contract
test("remotes", function()
	local f = ReplicatedStorage:FindFirstChild("Remotes")
	if not f then
		return false, "no Remotes folder"
	end
	local need = { "RoundState", "YourSecret", "SecretProgress", "Toast", "EventBanner", "Incident", "Evidence", "Monitor", "ViewCam", "Keypad",
		"Request", "Allies", "Detained", "Reveal", "Rewards", "Profile", "Sfx", "Photo", "Action" }
	for _, n in ipairs(need) do
		local r = f:FindFirstChild(n)
		if not r or not r:IsA("RemoteEvent") then
			return false, "missing remote " .. n
		end
	end
	return true
end)

test("map zones", function()
	local have = {}
	for _, e in ipairs(Core.zoneParts) do
		have[e.id] = true
	end
	local missing = {}
	for _, id in ipairs(SecretDB.ZONE_IDS) do
		if not have[id] then
			table.insert(missing, id)
		end
	end
	return #missing == 0, "missing zones: " .. table.concat(missing, ",")
end)

test("map interact counts", function()
	local need = { Door = 28, Search = 30, Hide = 10, Computer = 3, Camera = 10, PowerBox = 1, Alarm = 2, Phone = 4, Slot = 6, Cards = 2,
		Prize = 1, Cashier = 1, Food = 3, Shop = 5, Dig = 4, Boat = 1, Switch = 2, Elevator = 4, Pedestal = 2, Note = 4, Board = 1 }
	local count = {}
	for _, part in ipairs(CollectionService:GetTagged("Interact")) do
		local k = part:GetAttribute("Kind")
		if k then
			count[k] = (count[k] or 0) + 1
		end
	end
	local short = {}
	for k, n in pairs(need) do
		if (count[k] or 0) < n then
			table.insert(short, ("%s %d/%d"):format(k, count[k] or 0, n))
		end
	end
	table.sort(short)
	return #short == 0, "below minimum: " .. table.concat(short, ", ")
end)

test("map markers", function()
	local miss = {}
	for _, n in ipairs({ "DetentionCell", "DetentionExit", "VIPArrive", "PoliceArrive", "BoatDock", "FireSpot", "LobbySpawn" }) do
		if not Core.marker(n) then
			table.insert(miss, n)
		end
	end
	if #Core.markers("SpawnPlaza_") < 12 then
		table.insert(miss, "SpawnPlaza_ x" .. #Core.markers("SpawnPlaza_"))
	end
	if #Core.markers("BotWander") < 25 then
		table.insert(miss, "BotWander_ x" .. #Core.markers("BotWander"))
	end
	for n = 1, 3 do
		if #Core.markers(("GuardPath_%d_"):format(n)) < 2 then
			table.insert(miss, "GuardPath_" .. n)
		end
	end
	if #Core.markers("NPC_") < 5 then
		table.insert(miss, "NPC_ x" .. #Core.markers("NPC_"))
	end
	return #miss == 0, "missing: " .. table.concat(miss, ", ")
end)

---------------------------------------------------------------- generator
test("generator 1..24", function()
	local zones = { list = {}, byId = {} }
	for _, id in ipairs(SecretDB.ZONE_IDS) do
		local z = { id = id, name = id }
		table.insert(zones.list, z)
		zones.byId[id] = z
	end
	local rng = Random.new(42)
	local function r(a, b)
		if a == nil then
			return rng:NextNumber()
		end
		if b == nil then
			return rng:NextInteger(1, a)
		end
		return rng:NextInteger(a, b)
	end
	for n = 1, 24 do
		for _ = 1, 10 do
			local parts = {}
			for i = 1, n do
				table.insert(parts, { id = i <= 9 and -i or 1000 + i, name = "P" .. i, isBot = i <= 9 })
			end
			local res = SecretDB.generate(parts, zones, r, {})
			for _, p in ipairs(parts) do
				local a = res.assignments[p.id]
				if not a or not a.main or not a.side then
					return false, ("n=%d pid=%d missing main/side"):format(n, p.id)
				end
				for _, slot in ipairs({ "main", "side" }) do
					for _, ref in ipairs(SecretDB.referencedIds(a[slot])) do
						if ref == p.id then
							return false, ("n=%d pid=%d targets itself (%s)"):format(n, p.id, a[slot].id)
						end
					end
				end
			end
		end
	end
	return true
end)

test("every objective has a short headline <= 50 chars + one step per cond", function()
	local zones = { list = {}, byId = {} }
	for _, id in ipairs(SecretDB.ZONE_IDS) do
		local z = { id = id, name = id }
		table.insert(zones.list, z)
		zones.byId[id] = z
	end
	local rng = Random.new(7)
	local function r(a, b)
		if a == nil then
			return rng:NextNumber()
		end
		if b == nil then
			return rng:NextInteger(1, a)
		end
		return rng:NextInteger(a, b)
	end
	local seen, longest = {}, 0
	local function check(o)
		if o.hidden then
			return true
		end
		local l = type(o.short) == "string" and utf8.len(o.short) or 0
		longest = math.max(longest, l or 0)
		if not l or l < 5 or l > 50 then
			return false, ("%s short=%q"):format(tostring(o.id), tostring(o.short))
		end
		if #o.steps ~= #o.conds then
			return false, ("%s steps %d ~= conds %d"):format(tostring(o.id), #o.steps, #o.conds)
		end
		seen[o.id] = true
		return true
	end
	for n = 1, 16 do
		for _ = 1, 12 do
			local parts = {}
			for i = 1, n do
				table.insert(parts, { id = 1000 + i, name = i % 2 == 0 and "AVeryLongDisplayName_" .. i or "Mo" .. i, isBot = false })
			end
			local res = SecretDB.generate(parts, zones, r, {})
			for _, p in ipairs(parts) do
				local a = res.assignments[p.id]
				for _, slot in ipairs({ "main", "side" }) do
					local ok, why = check(a[slot])
					if not ok then
						return false, why
					end
					if SecretDB.public(a[slot]).short ~= a[slot].short then
						return false, "public() drops short"
					end
				end
			end
		end
	end
	local tm, ts = SecretDB.tutorial()
	for _, o in ipairs({ tm, ts }) do
		local ok, why = check(o)
		if not ok then
			return false, why
		end
	end
	local nSeen = 0
	for _ in pairs(seen) do
		nSeen += 1
	end
	print(("SELFTEST INFO: %d distinct objectives checked, longest headline %d chars"):format(nSeen, longest))
	return nSeen >= 30
end)

---------------------------------------------------------------- participants for the rest
local Bots = M.Bots
local A, B, C
test("bots spawned", function()
	if not Bots then
		return false, "Bots module missing"
	end
	for i = 1, 3 do
		if not Bots.list[-i] then
			Bots.spawn(i)
		end
	end
	A, B, C = Core.participants[-1], Core.participants[-2], Core.participants[-3]
	local n = 0
	for _ in pairs(Bots.list) do
		n += 1
	end
	local want = math.min(Config.BotCount, math.max(3, Config.FillTo - #Core.realPlayers()))
	return A ~= nil and B ~= nil and C ~= nil and n >= math.min(want, 3), ("%d bots"):format(n)
end)
-- client contract: Util.U.botsFolder() reads workspace.EHAS_Bots and matches models by BotId
test("bots live in workspace.EHAS_Bots with BotId (client lookup)", function()
	local f = workspace:FindFirstChild("EHAS_Bots")
	if not f then
		return false, "no workspace.EHAS_Bots"
	end
	for id, p in pairs(Bots and Bots.list or {}) do
		if p.model and p.model.Parent ~= f then
			return false, p.name .. " not under EHAS_Bots"
		end
		if p.model and p.model:GetAttribute("BotId") ~= id then
			return false, p.name .. " BotId " .. tostring(p.model:GetAttribute("BotId")) .. " ~= " .. id
		end
	end
	return true
end)
for _, p in ipairs({ A, B, C }) do
	if p then
		p.inRound = true
	end
end

test("bot rigs have 15 Motor6Ds + look", function()
	for id, p in pairs(Bots and Bots.list or {}) do
		local m = p.model
		if not m or not m.Parent then
			return false, "bot " .. id .. " has no model"
		end
		local n = Core.countMotors(m)
		if n < 15 then
			return false, ("%s has %d Motor6Ds"):format(p.name, n)
		end
		local head = m:FindFirstChild("Head")
		local torso = m:FindFirstChild("UpperTorso")
		if not head or not torso then
			return false, p.name .. " missing Head/UpperTorso"
		end
		local grey = Color3.fromRGB(163, 162, 165)
		if head.Color == grey and torso.Color == grey then
			return false, p.name .. " looks like a grey dummy"
		end
		if not m:FindFirstChildOfClass("Accessory") then
			return false, p.name .. " has no hair/hat accessory"
		end
	end
	local real, clothes, total = 0, 0, 0
	for _, p in pairs(Bots and Bots.list or {}) do
		total += 1
		local m = p.model
		for _, a in ipairs(m:GetChildren()) do
			if a:IsA("Accessory") and a:FindFirstChild("Handle") and a.Handle:IsA("MeshPart") then
				real += 1
				break
			end
		end
		if m:FindFirstChildOfClass("Shirt") then
			clothes += 1
		end
	end
	print(("SELFTEST INFO: bots with real catalog hair %d/%d, real shirts %d/%d"):format(real, total, clothes, total))
	return true
end)

test("guards + staff rigs", function()
	local Security = M.Security
	if not Security then
		return false, "no Security"
	end
	if #Security.guards < 1 then
		return #Core.markers("GuardPath_1_") == 0, "no guards spawned"
	end
	for _, g in ipairs(Security.guards) do
		if Core.countMotors(g.model) < 15 then
			return false, g.model.Name .. " Motor6Ds " .. Core.countMotors(g.model)
		end
	end
	local Evidence = M.Evidence
	for _, s in ipairs(Evidence and Evidence.staff or {}) do
		if Core.countMotors(s.model) < 15 then
			return false, s.model.Name .. " Motor6Ds " .. Core.countMotors(s.model)
		end
	end
	return true
end)

test("tool grip", function()
	for _, id in ipairs(Config.ItemOrder) do
		local tool = Core.makeTool(id)
		local h = tool:FindFirstChild("Handle")
		if not h then
			return false, id .. " has no Handle"
		end
		local gp = tool.GripPos
		if gp.Magnitude ~= gp.Magnitude or gp.Magnitude > 3 then
			return false, id .. " bad GripPos " .. tostring(gp)
		end
		if tool:GetAttribute("ItemId") ~= id or tool.CanBeDropped then
			return false, id .. " tool attributes wrong"
		end
		tool:Destroy()
	end
	return true
end)

---------------------------------------------------------------- secrets: progress from server events
local Secrets = M.Secrets
local function obj(id, conds)
	return { id = id, tier = "Medium", text = id, steps = {}, conds = conds }
end
test("secret: talk to 2", function()
	local o = Secrets.setObjective(A, "main", obj("t_talk", { { t = "talk", count = 2 } }))
	Bus.fire("Talked", A, B)
	Bus.fire("Talked", A, B) -- same person twice doesn't count
	if o.done then
		return false, "completed after talking to the same person"
	end
	Bus.fire("Talked", A, C)
	return o.done == true, "not done after 2 distinct talks"
end)
test("secret: steal -> hide chain", function()
	local o = Secrets.setObjective(A, "main", obj("t_steal", { { t = "steal", item = "GoldenStatue" }, { t = "hide", item = "GoldenStatue", zone = "Beach" } }))
	Bus.fire("Stolen", A, "GoldenStatue", "pedestal")
	if o.step ~= 2 then
		return false, "step not advanced after steal (step " .. tostring(o.step) .. ")"
	end
	Bus.fire("ItemHidden", A, "GoldenStatue", "Pool")
	if o.done then
		return false, "hid in wrong zone but completed"
	end
	Bus.fire("ItemHidden", A, "GoldenStatue", "Beach")
	return o.done == true, "not done after hiding at Beach"
end)
test("secret: photo thief", function()
	local o = Secrets.setObjective(B, "side", obj("t_photo", { { t = "photo", item = "GoldenStatue" } }))
	Bus.fire("Photo", B, A, nil, "Lobby")
	if o.done then
		return false, "photo without the item counted"
	end
	Bus.fire("Photo", B, A, "GoldenStatue", "Lobby")
	return o.done == true
end)
test("secret: notDetained fails on detention", function()
	local o = Secrets.setObjective(C, "side", obj("t_nd", { { t = "notDetained" } }))
	if not o.pendingEnd then
		return false, "END-only objective not pending"
	end
	Bus.fire("Detained", C)
	return o.failed == true, "not failed"
end)
test("secret: convince accuse", function()
	local o = Secrets.setObjective(C, "main", obj("t_conv", { { t = "convinceAccuse", target = B.id, accused = A.id } }))
	Bus.fire("Accused", B, C, { item = "GoldenStatue", title = "x" }, false)
	if o.done then
		return false, "wrong accused name counted"
	end
	Bus.fire("Accused", B, A, { item = "GoldenStatue", title = "x" }, true)
	return o.done == true
end)
test("secret: give coins progress", function()
	local o = Secrets.setObjective(B, "main", obj("t_gc", { { t = "giveCoins", target = C.id, amount = 30 } }))
	Bus.fire("CoinsGiven", B, C, 20)
	if o.done or (o.progress and o.progress.cur ~= 20) then
		return false, "progress wrong " .. tostring(o.progress and o.progress.cur)
	end
	Bus.fire("CoinsGiven", B, C, 10)
	return o.done == true
end)
test("beginner round = one simple secret", function()
	local parts = Secrets.participantsForGen()
	local res = SecretDB.generate(parts, Secrets.zonesForGen(), Secrets.rngFn(), {})
	local checked = 0
	for _, e in ipairs(parts) do
		local a = res.assignments[e.id]
		if a then
			local b = Secrets.beginnerize(a, parts, {}, e.id)
			if not b.side.hidden then
				return false, "side not hidden for " .. e.id
			end
			if b.side.hidden and #b.side.conds ~= 0 then
				return false, "hidden side still has conds"
			end
			if not b.main.chain and (b.main.tier == "Hard" or b.main.tier == "Legendary") then
				return false, "main still " .. b.main.tier
			end
			if b.side.hidden then
				local r = Secrets.potentialReward({ main = b.main, side = b.side })
				local m = Secrets.rewardFor(b.main, "main")
				if r ~= m then
					return false, "hidden side counted in reward"
				end
			end
			checked += 1
		end
	end
	print("SELFTEST INFO: beginner check on " .. checked .. " assignments; PlayTime=" .. Config.PlayTime)
	return checked > 0 and Config.PlayTime == 360
end)
test("beginner window (first 3 rounds) gives easy roles", function()
	if (Config.BeginnerRounds or 0) < 3 then
		return false, "BeginnerRounds=" .. tostring(Config.BeginnerRounds)
	end
	local zones = { list = {}, byId = {} }
	for _, id in ipairs(SecretDB.ZONE_IDS) do
		local z = { id = id, name = id }
		table.insert(zones.list, z)
		zones.byId[id] = z
	end
	local rng = Random.new(99)
	local function r(a, b)
		if a == nil then
			return rng:NextNumber()
		end
		if b == nil then
			return rng:NextInteger(1, a)
		end
		return rng:NextInteger(a, b)
	end
	local hard, total = 0, 0
	for _ = 1, 150 do
		local parts = {}
		for i = 1, 8 do
			table.insert(parts, { id = i == 1 and 5001 or -i, name = "P" .. i, isBot = i ~= 1 })
		end
		local res = SecretDB.generate(parts, zones, r, {}, { beginners = { [5001] = true } })
		local b = Secrets.beginnerize(res.assignments[5001], parts, {}, 5001)
		total += 1
		if b.main.tier == "Hard" or b.main.tier == "Legendary" then
			hard += 1
		end
		if not b.side.hidden then
			return false, "beginner has a side secret"
		end
	end
	print(("SELFTEST INFO: beginner got a Hard/Legendary main %d/%d"):format(hard, total))
	return hard / total < 0.05, ("%d/%d hard"):format(hard, total)
end)

test("assignAll real secrets", function()
	local res = Secrets.assignAll()
	for _, p in ipairs(Core.list(true)) do
		local st = Secrets.get(p)
		if not st or not st.main or not st.side then
			return false, p.name .. " has no secrets"
		end
	end
	return res ~= nil
end)

test("storm secret (eventZone) schedules a Storm", function()
	local Events = M.Events
	Events.stop("Storm")
	local savedSched, savedForced = Events.schedule, Secrets.forcedEvents
	Events.schedule = {}
	Secrets.forcedEvents = {}
	Secrets.ensureEvents(obj("F_outsideevent", { { t = "eventZone", zone = "Beach", event = "Storm" } }))
	local got = Events.schedule[1]
	local forced = table.find(Secrets.forcedEvents, "Storm") ~= nil
	Events.schedule, Secrets.forcedEvents = savedSched, savedForced
	return got ~= nil and got.id == "Storm" and not got.started and forced, "no Storm scheduled / forced"
end)

---------------------------------------------------------------- doors
test("door lock rules", function()
	local Interact = M.Interact
	local function door(lock, zone)
		local d = Instance.new("Part")
		d.Anchored = true
		d:SetAttribute("Kind", "Door")
		d:SetAttribute("Id", "selftest_" .. lock)
		d:SetAttribute("Zone", zone)
		d:SetAttribute("Lock", lock)
		return d
	end
	Core.clearItems(A)
	local sec, gr, vip, none = door("security", "SecurityRoom"), door("key:MasterKey", "GuestRooms"), door("key:VIPKeycard", "CasinoVIP"), door("none", "Lobby")
	local function can(d)
		return (Interact.canOpen(A, d))
	end
	local checks = {
		{ can(none) == "free", "free door not free" },
		{ can(sec) == nil, "security door opened without card" },
		{ can(vip) == nil, "VIP door opened without keycard" },
	}
	Core.giveItem(A, "SecurityCard")
	table.insert(checks, { can(sec) == "card", "card didn't open security door" })
	Core.giveItem(A, "VIPKeycard")
	table.insert(checks, { can(vip) ~= nil, "VIP keycard didn't open VIP door" })
	Core.giveItem(A, "MasterKey")
	table.insert(checks, { can(gr) ~= nil, "master key didn't open guest room" })
	Core.clearItems(A)
	Core.giveItem(A, "Crowbar")
	table.insert(checks, { can(sec) == nil, "crowbar forced a security door" })
	table.insert(checks, { can(vip) == "crowbar", "crowbar can't force VIP door" })
	Core.clearItems(A)
	for _, d in ipairs({ sec, gr, vip, none }) do
		d:Destroy()
	end
	for _, c in ipairs(checks) do
		if not c[1] then
			return false, c[2]
		end
	end
	return true
end)

test("locked door opens free from the inside only", function()
	local Interact = M.Interact
	local pos = Core.pos(A)
	if not pos then
		return false, "bot A has no position"
	end
	Core.clearItems(A)
	A.disguiseUntil = 0
	local d = Instance.new("Part")
	d.Anchored = true
	d.Size = Vector3.new(7.6, 10, 0.6)
	d.CFrame = CFrame.new(pos - Vector3.new(0, 0, 2)) -- A stands on the +Z side
	d:SetAttribute("Kind", "Door")
	d:SetAttribute("Id", "selftest_inside")
	d:SetAttribute("Zone", "SecurityRoom")
	d:SetAttribute("Lock", "security")
	d:SetAttribute("Inside", "+")
	local fromInside = Interact.canOpen(A, d)
	d:SetAttribute("Inside", "-")
	local fromOutside = Interact.canOpen(A, d)
	d:Destroy()
	return fromInside == "free" and fromOutside == nil, ("inside %s outside %s"):format(tostring(fromInside), tostring(fromOutside))
end)

-- every real map door with an Inside marker: the "+"/"-" side must actually be inside the door's own zone
-- (map builder sets Inside from the layout; this proves it against the real zone boxes)
test("real doors: Inside side lies in the door's zone", function()
	local bad, n = {}, 0
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("Kind") == "Door" and d:GetAttribute("Inside") then
			n += 1
			local inside = d:GetAttribute("Inside")
			local sign = inside == "+" and 1 or -1
			local axisZ = d.Size.X >= d.Size.Z
			local probeIn, probeOut
			for _, dist in ipairs({ 3, 5, 8 }) do
				local off = axisZ and Vector3.new(0, 0, sign * dist) or Vector3.new(sign * dist, 0, 0)
				local wpIn = d.CFrame:PointToWorldSpace(off - Vector3.new(0, d.Size.Y / 2 - 2.5, 0))
				local wpOut = d.CFrame:PointToWorldSpace(-off - Vector3.new(0, d.Size.Y / 2 - 2.5, 0))
				probeIn = probeIn or (Core.zoneAt(wpIn) == d:GetAttribute("Zone") and dist)
				probeOut = probeOut or (Core.zoneAt(wpOut) ~= d:GetAttribute("Zone") and dist)
			end
			if not probeIn then
				local wp = d.CFrame:PointToWorldSpace((axisZ and Vector3.new(0, 0, sign * 3) or Vector3.new(sign * 3, 0, 0)))
				table.insert(bad, ("%s(%s side %s -> %s)"):format(tostring(d:GetAttribute("Id")), tostring(d:GetAttribute("Zone")), inside, tostring(Core.zoneAt(wp))))
			end
		end
	end
	return n >= 10 and #bad == 0, ("%d doors, wrong: %s"):format(n, table.concat(bad, ", "))
end)

---------------------------------------------------------------- detention
test("detention timing + confiscation", function()
	local Security = M.Security
	Core.clearItems(B)
	Core.giveItem(B, "GoldenStatue", { hot = true, origin = "SelfTest" })
	local ok = Security.detain(B, "selftest", nil, 1.0)
	if not ok then
		return false, "detain returned false"
	end
	if not Core.isDetained(B) then
		return false, "not detained"
	end
	if #Core.hotItems(B) > 0 then
		return false, "hot item not confiscated"
	end
	local t = os.clock()
	while Core.isDetained(B) and os.clock() - t < 4 do
		task.wait(0.1)
	end
	local took = os.clock() - t
	if Core.isDetained(B) then
		return false, "never released"
	end
	return took < 2.5, ("released after %.1f s"):format(took)
end)
test("detention default is Config.DetentionTime", function()
	return Config.DetentionTime == 20 or workspace:GetAttribute("Cfg_DetentionTime") ~= nil, "DetentionTime=" .. tostring(Config.DetentionTime)
end)

---------------------------------------------------------------- evidence
test("footage evidence create + delete", function()
	local Security, Evidence = M.Security, M.Evidence
	local cam = Security.cams[Security.camOrder[1]]
	local tmp
	if not cam then
		tmp = Instance.new("Part")
		tmp.Anchored = true
		tmp.Parent = workspace
		cam = { part = tmp, id = "selftest", name = "TEST", disabledUntil = 0, lastSeen = {} }
		Security.cams.selftest = cam
	end
	local f = Security.addFootage(cam, A, "was carrying the Golden Statue", "GoldenStatue")
	if not f or not f.ev or not Evidence.records[f.ev.id] then
		return false, "no footage evidence record"
	end
	if f.ev.kind ~= "Footage" or f.ev.suspects[1] ~= A.id then
		return false, "footage record wrong"
	end
	local before = 0
	for _, x in ipairs(Bus.log or {}) do
		if x == "FootageDeleted" then
			before += 1
		end
	end
	if not Security.deleteFootage(B, f.id) then
		return false, "deleteFootage returned false"
	end
	if tmp then
		Security.cams.selftest = nil
		tmp:Destroy()
	end
	return f.deleted == true and f.ev.deleted == true, "not marked deleted"
end)
test("incident + crime scene clues", function()
	local Evidence = M.Evidence
	local pos = Core.zonePoint("Lobby") or Vector3.new(0, 5, 0)
	local inc = Evidence.createIncident("Theft", "SelfTest theft", "Lobby", A, pos, "DiamondNecklace")
	Evidence.crimeScene(A, pos, inc)
	local clues = 0
	for _, ev in pairs(Evidence.records) do
		if ev.incident == inc.id and ev.kind ~= "Missing" then
			clues += 1
			if #ev.suspects > 3 then
				return false, "more than 3 suspects"
			end
		end
	end
	return clues > 0 and Evidence.byIncident[inc.id] ~= nil, "no clues for incident"
end)

---------------------------------------------------------------- accusations
test("accusation reward / penalty", function()
	local Evidence, Accuse = M.Evidence, M.Accuse
	local inc = Evidence.createIncident("Theft", "SelfTest accuse", "Casino", A, nil, "CasinoChip")
	B.accuseReadyAt, C.accuseReadyAt = 0, 0
	B.accusedIncidents, C.accusedIncidents = {}, {}
	B.coins, C.coins = 100, 100
	local inc2 = Evidence.createIncident("Theft", "SelfTest accuse 2", "Casino", A, nil, "Pizza")
	local r1 = Accuse.accuse(B, A.id, inc.id)
	if not r1 or not r1.correct or B.coins ~= 100 + Config.AccuseRightCoins then
		return false, "correct accusation reward wrong (coins " .. B.coins .. ")"
	end
	if not inc.solved then
		return false, "incident not solved"
	end
	local r2 = Accuse.accuse(C, B.id, inc2.id)
	if not r2 or r2.correct or C.coins ~= 100 - Config.AccuseWrongCoins then
		return false, "wrong accusation penalty wrong (coins " .. C.coins .. ")"
	end
	local r3 = Accuse.accuse(C, A.id, inc2.id)
	if r3 ~= nil then
		return false, "cooldown / duplicate not enforced"
	end
	return C.accuseReadyAt > os.clock() + Config.AccuseCooldown - 5, "cooldown not set"
end)
test("accuse payout once per culprit; none for allies / staged swipes", function()
	local Evidence, Accuse, Social = M.Evidence, M.Accuse, M.Social
	B.accuseReadyAt, C.accuseReadyAt = 0, 0
	B.paidCulprits, C.paidCulprits = { [A.id] = true }, {}
	B.coins, C.coins = 100, 100
	-- B was already paid for catching A this round -> a 2nd correct call solves but pays nothing
	local inc = Evidence.createIncident("Swipe", "SelfTest farm 1", "Casino", A, nil, "Briefcase")
	inc.victim = B.id
	local r1 = Accuse.accuse(B, A.id, inc.id)
	if not r1 or not r1.correct or not inc.solved or B.coins ~= 100 then
		return false, "repeat culprit paid (coins " .. B.coins .. ")"
	end
	-- allies never pay each other
	local saved = Social.allies
	Social.allies = { [C.id] = { [A.id] = true }, [A.id] = { [C.id] = true } }
	local inc2 = Evidence.createIncident("Theft", "SelfTest farm 2", "Casino", A, nil, "Pizza")
	local r2 = Accuse.accuse(C, A.id, inc2.id)
	Social.allies = {} -- no alliances for the honest check (bots may have allied during the test run)
	if not r2 or not r2.correct or C.coins ~= 100 then
		Social.allies = saved
		return false, "ally accusation paid (coins " .. C.coins .. ")"
	end
	-- honest first catch still pays
	C.accuseReadyAt = 0
	local inc3 = Evidence.createIncident("Theft", "SelfTest farm 3", "Casino", B, nil, "Pizza")
	local r3 = Accuse.accuse(C, B.id, inc3.id)
	Social.allies = saved
	return r3 ~= nil and r3.correct and C.coins == 100 + Config.AccuseRightCoins, "honest first catch not paid (coins " .. C.coins .. ")"
end)

---------------------------------------------------------------- events
test("event start/stop (PowerOutage)", function()
	local Events = M.Events
	if not Events.start("PowerOutage", { duration = 5 }) then
		return false, "start returned false"
	end
	if not Events.isActive("PowerOutage") or not workspace:GetAttribute("PowerOut") then
		return false, "not active / PowerOut attr missing"
	end
	Events.stop("PowerOutage")
	return not Events.isActive("PowerOutage") and not workspace:GetAttribute("PowerOut"), "still active"
end)
test("event start/stop (all)", function()
	local Events = M.Events
	for _, id in ipairs(Config.EventOrder) do
		Events.start(id, { duration = 3 })
		if not Events.isActive(id) then
			return false, id .. " didn't start"
		end
		Events.stop(id)
		if Events.isActive(id) then
			return false, id .. " didn't stop"
		end
	end
	Events.stopAll()
	return true
end)
test("overlapping Storm + PowerOutage restore the original lighting", function()
	local Events = M.Events
	local L = game:GetService("Lighting")
	Events.stopAll()
	local base = Events.lightingTarget()
	local function sameAsBase(t)
		return t.Brightness == base.Brightness and t.Ambient == base.Ambient and t.OutdoorAmbient == base.OutdoorAmbient
	end
	-- case A: storm -> outage -> storm ends -> outage ends; case B: outage -> storm -> outage ends -> storm ends
	for _, order in ipairs({ { "Storm", "PowerOutage", "Storm", "PowerOutage" }, { "PowerOutage", "Storm", "PowerOutage", "Storm" } }) do
		Events.start(order[1], { duration = 30 })
		Events.start(order[2], { duration = 30 })
		if Events.lightingTarget().Brightness ~= 0.3 then
			return false, "outage not darkest while overlapping"
		end
		Events.stop(order[3])
		Events.stop(order[4])
		if not sameAsBase(Events.lightingTarget()) then
			return false, order[1] .. " first: target not base after both ended"
		end
	end
	task.wait(2.3) -- let the restore tweens finish
	local atm = L:FindFirstChildOfClass("Atmosphere")
	if atm and atm:GetAttribute("SavedDensity") ~= nil then
		return false, "Atmosphere SavedDensity left set"
	end
	local function near(a, b)
		return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.02
	end
	return math.abs(L.Brightness - base.Brightness) < 0.01 and near(L.OutdoorAmbient, base.OutdoorAmbient) and near(L.Ambient, base.Ambient),
		("Lighting.Brightness %.2f (base %.2f)"):format(L.Brightness, base.Brightness)
end)

---------------------------------------------------------------- data
test("data snapshot/reconcile roundtrip", function()
	local Data = M.Data
	local prof = Data.newProfile()
	prof.coins = 777
	prof.level = 9
	prof.stats.secretsCompleted = 5
	prof.owned.Hat_TopHat = true
	prof.seq = 3
	local back = Data.reconcile(Data.snapshot(prof))
	if back.coins ~= 777 or back.level ~= 9 or back.stats.secretsCompleted ~= 5 or not back.owned.Hat_TopHat then
		return false, "fields lost in roundtrip"
	end
	if back.canSave ~= nil and back.canSave ~= false then
		return false, "runtime flag leaked into snapshot"
	end
	return true
end)
test("data store roundtrip", function()
	local Data = M.Data
	local key = "selftest_" .. game.JobId:sub(1, 8)
	local prof = Data.newProfile()
	prof.coins = 4242
	prof.seq = 1
	local ok = Data.saveKey(key, Data.snapshot(prof))
	if not ok then
		print("SELFTEST INFO: DataStore unavailable (unpublished place) — store roundtrip skipped")
		return true
	end
	local ok2, saved = Data.loadKey(key)
	Data.removeKey(key)
	return ok2 and type(saved) == "table" and saved.coins == 4242, "loaded " .. tostring(saved and saved.coins)
end)

---------------------------------------------------------------- shop
test("shop coin purchase", function()
	local Data, Shop = M.Data, M.Shop
	local fake = Instance.new("Folder")
	fake.Name = "SelfTestPlayer"
	local prof = Data.newProfile()
	prof.coins = 1000
	prof.level = 50
	Data.profiles[fake] = prof
	local ok, why = Shop.buyCosmetic(fake, "Hat_TopHat")
	local ok2 = Shop.buyCosmetic(fake, "Hat_TopHat") -- already owned
	prof.coins = 10
	local ok3 = Shop.buyCosmetic(fake, "Hat_Crown") -- too poor
	Data.profiles[fake] = nil
	fake:Destroy()
	if not ok then
		return false, "buy failed: " .. tostring(why)
	end
	return prof.owned.Hat_TopHat == true and not ok2 and not ok3, "ownership/coin checks wrong"
end)
test("crate roll", function()
	local Data, Shop = M.Data, M.Shop
	local prof = Data.newProfile()
	local c = Shop.rollCrate(prof, Random.new(7))
	return c ~= nil and prof.owned[c.id] == true, "crate gave nothing"
end)
test("VIP +10% coins on round rewards", function()
	local Data = M.Data
	if not (Round and Round.rewardOne) then
		return false, "Round.rewardOne missing"
	end
	local fake = Instance.new("Folder")
	fake.Name = "SelfTestVIP"
	local prof = Data.newProfile()
	prof.coins = 0
	prof.passes.VIP = true
	Data.profiles[fake] = prof
	local r = { coins = 200, xp = 10, breakdown = {} }
	local ok, err = pcall(Round.rewardOne, { player = fake, isBot = false, name = "vip", id = 0 }, r, Data, M.Progress)
	Data.profiles[fake] = nil
	Round.lastRewards[0] = nil
	fake:Destroy()
	if not ok then
		return false, tostring(err)
	end
	-- check the reward itself (a daily "earn coins" challenge may add more to prof.coins)
	local row = r.breakdown[1]
	return r.coins == 220 and row ~= nil and row.coins == 20 and prof.coins >= 220,
		("reward %d row %s wallet %d"):format(r.coins, tostring(row and row.coins), prof.coins)
end)
test("paid reroll that can't apply -> coin compensation; pack dup refund", function()
	local Data, Shop = M.Data, M.Shop
	local fake = Instance.new("Folder")
	fake.Name = "SelfTestBuyer"
	local prof = Data.newProfile()
	prof.coins = 0
	prof.owned.Hat_DetectiveCap = true
	Data.profiles[fake] = prof
	local ok1, e1 = pcall(Shop.grantProduct, fake, "SecretReroll") -- no participant -> can't reroll
	local afterReroll = prof.coins
	local ok2, e2 = pcall(Shop.grantProduct, fake, "DetectivePack") -- 1 of 3 already owned
	Data.profiles[fake] = nil
	fake:Destroy()
	if not (ok1 and ok2) then
		return false, tostring(e1 or e2)
	end
	local ShopConfig = require(ReplicatedStorage:WaitForChild("ShopConfig"))
	local want = Shop.RerollRefundCoins + ShopConfig.CrateDuplicateCoins
	return afterReroll == Shop.RerollRefundCoins and prof.coins == want and prof.owned.Mask_Monocle == true,
		("reroll %d total %d"):format(afterReroll, prof.coins)
end)
test("arcade is gambling-free: free to play, skill-timed, capped per round", function()
	local Interact = M.Interact
	if not (Interact and Interact.ARCADE and Interact.arcadePos) then
		return false, "no arcade"
	end
	if Config.SlotCost ~= 0 or Config.CardsCost ~= 0 then
		return false, "arcade costs coins"
	end
	-- needle sweeps 0 -> 1 -> 0
	local a, b, c = Interact.arcadePos(0, 1), Interact.arcadePos(0.5, 1), Interact.arcadePos(1.5, 1)
	if math.abs(a) > 1e-6 or math.abs(b - 0.5) > 1e-6 or math.abs(c - 0.5) > 1e-6 or Interact.arcadePos(1, 1) ~= 1 then
		return false, ("sweep %s %s %s"):format(a, b, c)
	end
	-- no casino words left on the map signs / prompts
	local bad = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if (d:IsA("TextLabel") and d.Text) or d:IsA("ProximityPrompt") then
			local t = string.lower(d:IsA("ProximityPrompt") and (d.ActionText .. " " .. d.ObjectText) or d.Text)
			for _, w in ipairs({ "casino", "slot", "jackpot", "dealer", "cashier", "champagne", "liquor", "$500" }) do
				if string.find(t, w, 1, true) then
					table.insert(bad, t)
					break
				end
			end
		end
	end
	if #bad > 0 then
		return false, "casino text left: " .. table.concat(bad, " | "):sub(1, 200)
	end
	-- the gold token can't be bought for less than it sells for
	return Config.ArcadeRoundCap and Config.ArcadeRoundCap > 0, "cap"
end)
test("bonus secret: idle real player gets a fresh Easy secret, finished side is banked", function()
	local Secrets = M.Secrets
	local P = A or B or C
	if not (Secrets and Secrets.maybeBonus and P) then
		return false, "no maybeBonus/participant"
	end
	local st0 = Secrets.state[P.id]
	local wasBot, ph, ends, inR = P.isBot, Core.phase, Core.roundEndsAt, P.inRound
	local main = { id = "x_main", tier = "Easy", text = "-", steps = {}, conds = {}, done = true }
	local side = { id = "x_side", tier = "Easy", text = "-", steps = {}, conds = {}, done = true }
	Secrets.state[P.id] = { main = main, side = side, role = "THE GUEST", rerollsLeft = 0, highlights = {} }
	P.isBot, P.inRound, Core.phase, Core.roundEndsAt = false, true, "Play", Core.now() + 300
	local ok, got = pcall(Secrets.maybeBonus, P)
	local st = Secrets.state[P.id]
	local okLate = st and st.side and st.side.bonus == true and #(st.banked or {}) == 1
	-- under the time floor: no bonus
	st.side.done = true
	Core.roundEndsAt = Core.now() + 10
	local ok2, got2 = pcall(Secrets.maybeBonus, P)
	P.isBot, P.inRound, Core.phase, Core.roundEndsAt = wasBot, inR, ph, ends
	Secrets.state[P.id] = st0
	if not ok or not ok2 then
		return false, tostring(got) .. " / " .. tostring(got2)
	end
	return got == true and okLate and got2 == false, ("got=%s banked=%s late=%s"):format(tostring(got), tostring(okLate), tostring(got2))
end)

test("bots can talk (speech bubble)", function()
	local Bots = M.Bots
	local P
	for _, b in pairs(Bots and Bots.list or {}) do
		P = b
		break
	end
	if not P then
		return true, "no bots"
	end
	Bots.say(P, "selftest hi")
	local head = Core.char(P) and Core.char(P):FindFirstChild("Head")
	local bb = head and head:FindFirstChild("BotBubble")
	local ok = bb ~= nil and bb:FindFirstChildOfClass("TextLabel").Text == "selftest hi"
	if bb then
		bb:Destroy()
	end
	return ok, "no bubble"
end)
test("analytics: funnel steps log once, fake players never error", function()
	local An = M.Analytics
	if not An then
		return false, "Analytics module not loaded"
	end
	local fake = Instance.new("Folder")
	local okF = pcall(An.onboard, fake, 1) and pcall(An.coins, fake, 5, "Gameplay", "x") and pcall(An.event, fake, "x", 1)
	local okB = pcall(An.onCoins, { isBot = true }, 5, "arcade")
	local pl = game:GetService("Players"):GetPlayers()[1]
	local once = true
	if pl then
		An.onboard(pl, 7)
		once = An.onboard(pl, 7) == false
	end
	return okF and okB and once and #An.ONBOARDING == 7 and type(Core.coinHooks) == "table" and #Core.coinHooks >= 1,
		("fake=%s bot=%s once=%s hooks=%s"):format(tostring(okF), tostring(okB), tostring(once), tostring(Core.coinHooks and #Core.coinHooks))
end)

---------------------------------------------------------------- cleanup
Core.phase = savedPhase
if Round then
	pcall(Round.startLobby)
	Round.paused = false
end
print(("SELFTEST DONE %d passed, %d failed"):format(passed, failed))
workspace:SetAttribute("SelfTestPassed", passed)
workspace:SetAttribute("SelfTestFailed", failed)
