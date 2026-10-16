-- Evidence.luau — incidents (public), evidence records, personal journals, physical clue props
-- (footprints / dropped items / broken doors) that must be inspected, framing, and staff witnesses.
-- Evidence never reveals the culprit by itself: it gives 1-3 suspects, often including innocents.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Bus = require(script.Parent.Bus)
local Core = require(script.Parent.Core)

local Evidence = {}
Evidence.incidents = {} -- ordered list of incidents
Evidence.byIncident = {} -- id -> incident
Evidence.records = {} -- id -> ev
Evidence.journal = {} -- pid -> {evId -> true}
Evidence.props = {} -- physical clue models
local nextId = 0

local function newId(prefix)
	nextId += 1
	return prefix .. nextId
end

local function propFolder()
	local f = workspace:FindFirstChild("EHAS_Clues")
	if not f then
		f = Instance.new("Folder")
		f.Name = "EHAS_Clues"
		f.Parent = workspace
	end
	return f
end

---------------------------------------------------------------- incidents
function Evidence.publicIncidents()
	local list = {}
	for _, inc in ipairs(Evidence.incidents) do
		table.insert(list, { id = inc.id, title = inc.title, zone = inc.zone, time = inc.time, solved = inc.solved })
	end
	return list
end
function Evidence.broadcastIncidents()
	Core.broadcast("Incident", { list = Evidence.publicIncidents() })
end
function Evidence.sendIncidents(p)
	Core.send(p, "Incident", { list = Evidence.publicIncidents() })
end

-- kind: "Theft" | "BrokenDoor" | "Sabotage" | "Swipe" | ...
function Evidence.createIncident(kind, title, zone, culprit, pos, item)
	local inc = {
		id = newId("inc"),
		kind = kind,
		title = title,
		zone = zone or "Lobby",
		time = Core.now(),
		clock = os.clock(),
		culprit = culprit and culprit.id or nil,
		item = item,
		pos = pos,
		solved = false,
		framed = {},
	}
	table.insert(Evidence.incidents, inc)
	Evidence.byIncident[inc.id] = inc
	Evidence.broadcastIncidents()
	Core.broadcast("Toast", { text = "🚨 SOMETHING HAPPENED: " .. title, kind = "event", sfx = "Alarm" })
	-- everyone notes the "Missing"/incident record (no suspects)
	local ev = Evidence.add("Missing", ("%s (%s, %s)"):format(title, Core.zoneName(inc.zone), Core.fmtTime(inc.time)), inc.zone, {}, inc.id)
	for _, p in ipairs(Core.list(true)) do
		Evidence.discover(p, ev, true)
	end
	Bus.fire("Incident", inc)
	return inc
end

function Evidence.latestIncidentFor(item)
	for i = #Evidence.incidents, 1, -1 do
		local inc = Evidence.incidents[i]
		if item == nil or inc.item == item then
			return inc
		end
	end
	return nil
end

---------------------------------------------------------------- suspects
-- culprit + 0..extra innocents (prefer people near pos)
function Evidence.suspectsFor(culpritId, pos, extra)
	local out = {}
	if culpritId then
		table.insert(out, culpritId)
	end
	local cands = {}
	for _, p in ipairs(Core.list(true)) do
		if p.id ~= culpritId then
			local pp = Core.pos(p)
			local d = (pp and pos) and (pp - pos).Magnitude or 999
			table.insert(cands, { id = p.id, d = d + Core.rng:NextNumber() * 60 })
		end
	end
	table.sort(cands, function(a, b)
		return a.d < b.d
	end)
	for i = 1, math.min(extra, #cands) do
		table.insert(out, cands[i].id)
	end
	return Core.shuffle(out)
end

---------------------------------------------------------------- records + journal
function Evidence.add(kind, text, zone, suspects, incidentId, extra)
	local ev = {
		id = newId("ev"),
		kind = kind,
		text = text,
		zone = zone,
		time = Core.now(),
		suspects = suspects or {},
		incident = incidentId,
		deleted = false,
	}
	if extra then
		for k, v in pairs(extra) do
			ev[k] = v
		end
	end
	Evidence.records[ev.id] = ev
	return ev
end

local pendingJournal = {}
function Evidence.sendJournal(p)
	if not p or p.isBot then
		return
	end
	local list = {}
	for evId in pairs(Evidence.journal[p.id] or {}) do
		local ev = Evidence.records[evId]
		if ev and not ev.deleted then
			table.insert(list, { id = ev.id, kind = ev.kind, text = ev.text, zone = ev.zone, time = ev.time, suspects = table.clone(ev.suspects), incident = ev.incident })
		end
	end
	table.sort(list, function(a, b)
		return a.time > b.time
	end)
	Core.send(p, "Evidence", { list = list })
end
local function sendJournalSoon(p)
	if p.isBot or pendingJournal[p.id] then
		return
	end
	pendingJournal[p.id] = true
	task.delay(0.2, function()
		pendingJournal[p.id] = nil
		if Core.participants[p.id] then
			Evidence.sendJournal(p)
		end
	end)
end

-- returns true if new
function Evidence.discover(p, ev, silent)
	if not p or not ev or ev.deleted then
		return false
	end
	local j = Evidence.journal[p.id]
	if not j then
		j = {}
		Evidence.journal[p.id] = j
	end
	if j[ev.id] then
		return false
	end
	j[ev.id] = true
	if not silent then
		Core.toast(p, "🔍 New evidence: " .. ev.text, "evidence", "Evidence")
		if not p.isBot and ev.kind ~= "Missing" then
			local Progress = Core.M.Progress
			if Progress then
				Progress.addStat(p.player, "evidenceFound", 1)
			end
		end
	end
	Bus.fire("EvidenceFound", p, ev)
	sendJournalSoon(p)
	return true
end

function Evidence.journalFor(pid)
	local out = {}
	for evId in pairs(Evidence.journal[pid] or {}) do
		local ev = Evidence.records[evId]
		if ev and not ev.deleted then
			table.insert(out, ev)
		end
	end
	return out
end

-- remove an evidence record from every journal (footage deletion / destroyed clue)
function Evidence.destroy(ev)
	if not ev then
		return
	end
	ev.deleted = true
	for pid, j in pairs(Evidence.journal) do
		if j[ev.id] then
			local p = Core.participants[pid]
			if p then
				sendJournalSoon(p)
			end
		end
	end
	if ev.prop and ev.prop.Parent then
		ev.prop:Destroy()
	end
end

-- add a suspect to every evidence record of an incident (framing)
function Evidence.addSuspect(incidentId, pid)
	for _, ev in pairs(Evidence.records) do
		if ev.incident == incidentId and not ev.deleted and ev.kind ~= "Missing" and ev.kind ~= "Footage" and ev.kind ~= "Photo" then
			if not table.find(ev.suspects, pid) then
				if #ev.suspects >= 3 then
					-- replace an innocent (never the culprit) so the list stays 1..3
					local inc = Evidence.byIncident[incidentId]
					for i, s in ipairs(ev.suspects) do
						if not inc or s ~= inc.culprit then
							table.remove(ev.suspects, i)
							break
						end
					end
				end
				table.insert(ev.suspects, pid)
				ev.suspects = Core.shuffle(ev.suspects)
				for jpid, j in pairs(Evidence.journal) do
					if j[ev.id] and Core.participants[jpid] then
						sendJournalSoon(Core.participants[jpid])
					end
				end
			end
		end
	end
end

---------------------------------------------------------------- physical clue props
local function groundAt(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { propFolder() }
	for _, p in pairs(Core.participants) do
		local c = Core.char(p)
		if c then
			table.insert(ex, c)
		end
	end
	local z = Core.resort() and Core.resort():FindFirstChild("Zones")
	if z then
		table.insert(ex, z)
	end
	params.FilterDescendantsInstances = ex
	local hit = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -20, 0), params)
	return hit and hit.Position or (pos - Vector3.new(0, 3, 0))
end
Evidence.groundAt = groundAt

local function inspectPrompt(part, actionText, onInspect)
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = actionText
	pr.ObjectText = "Clue"
	pr.HoldDuration = 0.5
	pr.MaxActivationDistance = 10
	pr.RequiresLineOfSight = false
	pr.Parent = part
	pr.Triggered:Connect(function(player)
		local p = Core.byPlayer[player]
		if p then
			onInspect(p)
		end
	end)
	return pr
end

-- footprints trail near pos: 4 small dark prints
function Evidence.spawnFootprints(pos, ev)
	local g = groundAt(pos)
	local model = Instance.new("Model")
	model.Name = "Footprints"
	local host
	for i = 0, 3 do
		local fp = Instance.new("Part")
		fp.Name = "Print"
		fp.Size = Vector3.new(0.7, 0.05, 1.2)
		fp.Anchored = true
		fp.CanCollide = false
		fp.CanTouch = false
		fp.Color = Color3.fromRGB(85, 60, 40)
		fp.Material = Enum.Material.Sand
		fp.Transparency = 0.15
		local side = (i % 2 == 0) and -0.5 or 0.5
		fp.CFrame = CFrame.new(g + Vector3.new(side, 0.04, i * 1.6 - 2.4)) * CFrame.Angles(0, math.rad(Core.rng:NextInteger(-12, 12)), 0)
		fp.Parent = model
		host = host or fp
	end
	model.Parent = propFolder()
	ev.prop = model
	inspectPrompt(host, "Inspect footprints", function(p)
		Evidence.discover(p, ev)
	end)
	return model
end

function Evidence.spawnDroppedClue(pos, ev, color)
	local g = groundAt(pos + Vector3.new(Core.rng:NextNumber(-3, 3), 0, Core.rng:NextNumber(-3, 3)))
	local part = Instance.new("Part")
	part.Name = "DroppedClue"
	part.Size = Vector3.new(0.8, 0.2, 0.6)
	part.Anchored = true
	part.CanCollide = false
	part.Color = color or Color3.fromRGB(230, 220, 190)
	part.Material = Enum.Material.Fabric
	part.CFrame = CFrame.new(g + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, Core.rng:NextNumber(0, 6.28), 0)
	part.Parent = propFolder()
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = Color3.fromRGB(255, 240, 160)
	sparkle.Parent = part
	ev.prop = part
	inspectPrompt(part, "Inspect", function(p)
		Evidence.discover(p, ev)
	end)
	return part
end

function Evidence.spawnBrokenDoorClue(doorPart, ev)
	-- splinters at the door base
	local pos = doorPart.Position
	local g = groundAt(pos)
	local part = Instance.new("Part")
	part.Name = "Splinters"
	part.Size = Vector3.new(1.6, 0.15, 1)
	part.Anchored = true
	part.CanCollide = false
	part.Color = Color3.fromRGB(120, 85, 50)
	part.Material = Enum.Material.WoodPlanks
	part.CFrame = CFrame.new(g + Vector3.new(0, 0.08, 0))
	part.Parent = propFolder()
	ev.prop = part
	inspectPrompt(part, "Inspect damage", function(p)
		Evidence.discover(p, ev)
	end)
	return part
end

-- A crime happened: footprints + maybe a dropped clue + nearby participant witnesses.
function Evidence.crimeScene(culprit, pos, inc)
	if not pos then
		return
	end
	local zone = inc.zone
	local fpSus = Evidence.suspectsFor(culprit and culprit.id, pos, Core.rng:NextInteger(0, 2))
	local fp = Evidence.add("Footprints", ("Footprints near the %s (%s). They could belong to: %s"):format(Core.zoneName(zone), inc.title, ""), zone, fpSus, inc.id)
	fp.text = ("Footprints at the scene in the %s — fresh, size matches %d guest%s."):format(Core.zoneName(zone), #fpSus, #fpSus == 1 and "" or "s")
	Evidence.spawnFootprints(pos, fp)
	if Core.rng:NextNumber() < 0.45 then
		local dSus = Evidence.suspectsFor(culprit and culprit.id, pos, 1)
		local what = Core.pick({ "a torn sleeve button", "a resort wristband", "a dropped sunglasses lens", "a crumpled receipt" })
		local d = Evidence.add("Dropped", ("Someone dropped %s near the %s."):format(what, Core.zoneName(zone)), zone, dSus, inc.id)
		Evidence.spawnDroppedClue(pos, d)
	end
	-- bystanders within 30 studs with line of sight get a vague witness note
	if culprit then
		for _, p in ipairs(Core.nearby(pos, 30, culprit.id)) do
			if not p.hidden then
				local sus = Evidence.suspectsFor(culprit.id, pos, 1)
				local ev = Evidence.add("Witness", ("You glimpsed someone near the %s right when it happened."):format(Core.zoneName(zone)), zone, sus, inc.id)
				Evidence.discover(p, ev)
			end
		end
	end
end

---------------------------------------------------------------- framing
-- a SecretLetter / StaffUniform dropped near an unsolved incident frames `targetId`
function Evidence.tryFrame(framer, itemId, pos, targetId)
	if itemId ~= "SecretLetter" and itemId ~= "StaffUniform" then
		return false
	end
	local best, bestD
	for _, inc in ipairs(Evidence.incidents) do
		if not inc.solved and inc.pos then
			local d = (inc.pos - pos).Magnitude
			if d <= 35 and (not bestD or d < bestD) then
				best, bestD = inc, d
			end
		end
	end
	if not best then
		return false
	end
	if not targetId or targetId == framer.id or not Core.participants[targetId] then
		-- fall back: framer's secret frame target, else a random innocent
		local Secrets = Core.M.Secrets
		targetId = Secrets and Secrets.frameTargetOf(framer) or nil
		if not targetId or targetId == framer.id then
			local others = {}
			for _, p in ipairs(Core.list(true)) do
				if p.id ~= framer.id and p.id ~= best.culprit then
					table.insert(others, p.id)
				end
			end
			targetId = Core.pick(others)
		end
	end
	if not targetId then
		return false
	end
	best.framed[targetId] = framer.id
	local what = itemId == "SecretLetter" and "a letter signed by" or "a staff uniform with the name tag of"
	local ev = Evidence.add("Dropped", ("Found %s %s near the %s!"):format(what, Core.nameOf(targetId), Core.zoneName(best.zone)), best.zone, { targetId }, best.id, { planted = framer.id })
	Evidence.spawnDroppedClue(pos, ev, itemId == "StaffUniform" and Color3.fromRGB(240, 240, 240) or Color3.fromRGB(250, 235, 200))
	Evidence.addSuspect(best.id, targetId)
	Core.toast(framer, ("🧪 Evidence planted: %s is now a suspect."):format(Core.nameOf(targetId)), "evidence", "Evidence")
	Bus.fire("Framed", framer, targetId, best)
	return true
end

---------------------------------------------------------------- staff NPCs (witnesses)
Evidence.staff = {} -- {model, role, part(root), sightings={pid=clock}, bribedUntil, asked={}}
local STAFF_LOOK = {
	Dealer = { outfit = "dealer", shirt = Color3.fromRGB(245, 245, 245), pants = Color3.fromRGB(25, 25, 30), name = "Game Host Rosa" },
	Receptionist = { outfit = "receptionist", shirt = Color3.fromRGB(245, 245, 245), pants = Color3.fromRGB(30, 35, 60), vest = Color3.fromRGB(30, 35, 60), name = "Receptionist Ana" },
	Chef = { outfit = "chef", shirt = Color3.fromRGB(250, 250, 250), pants = Color3.fromRGB(40, 40, 45), name = "Chef Marco" },
	Bartender = { outfit = "waiter", shirt = Color3.fromRGB(245, 245, 245), pants = Color3.fromRGB(25, 25, 30), name = "Juice Bar Joe" },
	Lifeguard = { outfit = "lifeguard", shirt = Color3.fromRGB(230, 50, 50), pants = Color3.fromRGB(230, 50, 50), shorts = true, longSleeves = false, name = "Lifeguard Kim" },
	Cashier = { outfit = "waiter", shirt = Color3.fromRGB(245, 245, 245), pants = Color3.fromRGB(25, 25, 30), vest = Color3.fromRGB(20, 90, 60), name = "Prize Desk Lou" },
	Shopkeeper = { outfit = "waiter", shirt = Color3.fromRGB(150, 210, 240), pants = Color3.fromRGB(200, 180, 140), vest = Color3.fromRGB(240, 170, 60), name = "Shopkeeper Ines" },
	Janitor = { outfit = "janitor", shirt = Color3.fromRGB(110, 150, 170), pants = Color3.fromRGB(70, 90, 110), name = "Janitor Gus" },
	DoorGuard = { outfit = "guard", shirt = Color3.fromRGB(30, 42, 90), pants = Color3.fromRGB(25, 30, 55), name = "Officer Dale" },
}
Evidence.STAFF_LOOK = STAFF_LOOK

local function staffFolder()
	local f = workspace:FindFirstChild("EHAS_Staff")
	if not f then
		f = Instance.new("Folder")
		f.Name = "EHAS_Staff"
		f.Parent = workspace
	end
	return f
end

function Evidence.spawnStaff()
	local Anim = require(script.Parent.Anim)
	for _, m in ipairs(Core.markers("NPC_")) do
		local role = m:GetAttribute("Role") or m.Name:sub(5)
		local look = table.clone(STAFF_LOOK[role] or STAFF_LOOK.Bartender)
		look.displayName = look.name
		local ok, model = pcall(Core.makeRig, "Staff_" .. role, look)
		if ok and model then
			local root = model:FindFirstChild("HumanoidRootPart")
			local hum = model:FindFirstChildOfClass("Humanoid")
			model:PivotTo(m.CFrame)
			root.Anchored = true
			model.Parent = staffFolder()
			model:SetAttribute("StaffRole", role)
			task.defer(function()
				Anim.setLoco(hum, "idle", 1)
			end)
			local s = { model = model, role = role, part = root, sightings = {}, bribedUntil = 0, asked = {}, zone = m:GetAttribute("Zone") }
			table.insert(Evidence.staff, s)
			local ask = Instance.new("ProximityPrompt")
			ask.Name = "Ask"
			ask.ActionText = role == "Dealer" and "Talk" or "Ask what they saw"
			ask.ObjectText = look.name
			ask.HoldDuration = 0.3
			ask.MaxActivationDistance = 10
			ask.RequiresLineOfSight = false
			ask.Parent = root
			ask.Triggered:Connect(function(player)
				local p = Core.byPlayer[player]
				if p then
					Evidence.askWitness(p, s)
				end
			end)
			local bribe = Instance.new("ProximityPrompt")
			bribe.Name = "Bribe"
			bribe.ActionText = ("Bribe (%d 🪙)"):format(Config.BribeCost)
			bribe.ObjectText = look.name
			bribe.KeyboardKeyCode = Enum.KeyCode.F
			bribe.GamepadKeyCode = Enum.KeyCode.ButtonY
			bribe.HoldDuration = 0.6
			bribe.MaxActivationDistance = 10
			bribe.RequiresLineOfSight = false
			bribe.UIOffset = Vector2.new(0, 70)
			bribe.Parent = root
			bribe.Triggered:Connect(function(player)
				local p = Core.byPlayer[player]
				if p then
					Evidence.bribe(p, s)
				end
			end)
		else
			warn("[Evidence] staff spawn failed: " .. tostring(model))
		end
	end
	-- sighting scanner
	task.spawn(function()
		while true do
			task.wait(1)
			pcall(function()
				local now = os.clock()
				for _, s in ipairs(Evidence.staff) do
					if s.part and s.part.Parent then
						for _, p in ipairs(Core.nearby(s.part.Position, 40)) do
							if not p.hidden then
								s.sightings[p.id] = now
							end
						end
					end
				end
			end)
		end
	end)
end

function Evidence.nearestStaff(pos, maxD)
	local best, bd
	for _, s in ipairs(Evidence.staff) do
		if s.part and s.part.Parent then
			local d = (s.part.Position - pos).Magnitude
			if d <= (maxD or 12) and (not bd or d < bd) then
				best, bd = s, d
			end
		end
	end
	return best
end

function Evidence.askWitness(p, s)
	if not Core.inPlay() then
		Core.toast(p, s.role .. ": Enjoy your stay! 🌴", "social")
		return
	end
	local pp = Core.pos(p)
	if not pp or (pp - s.part.Position).Magnitude > Config.InteractRange then
		return
	end
	Bus.fire("TalkNPC", p, s.role)
	-- staff were statues: turn to face whoever talks to them (anchored root, so tween the CFrame)
	if s.part and s.part.Anchored then
		local flat = Vector3.new(pp.X, s.part.Position.Y, pp.Z)
		if (flat - s.part.Position).Magnitude > 0.5 then
			pcall(function()
				game:GetService("TweenService"):Create(s.part, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { CFrame = CFrame.lookAt(s.part.Position, flat) }):Play()
			end)
		end
	end
	if s.role == "Dealer" then
		Bus.fire("Interacted", p, "Cards", s.part, "Casino")
	end
	-- most recent unsolved incident not yet asked by p
	local inc
	for i = #Evidence.incidents, 1, -1 do
		local c = Evidence.incidents[i]
		if not c.solved and not (s.asked[p.id] and s.asked[p.id][c.id]) then
			inc = c
			break
		end
	end
	if not inc then
		Core.toast(p, ("%s: \"Quiet day... nothing to report.\""):format(STAFF_LOOK[s.role] and STAFF_LOOK[s.role].name or s.role), "social")
		return
	end
	s.asked[p.id] = s.asked[p.id] or {}
	s.asked[p.id][inc.id] = true
	local name = STAFF_LOOK[s.role] and STAFF_LOOK[s.role].name or s.role
	if s.bribedUntil > os.clock() then
		Core.toast(p, ("%s: \"I didn't see anything. Nothing at all. 🤐\""):format(name), "social")
		return
	end
	-- who did this witness see around the incident time?
	local seen = {}
	for pid, t in pairs(s.sightings) do
		if math.abs(t - inc.clock) <= 45 and pid ~= p.id and Core.participants[pid] then
			table.insert(seen, pid)
		end
	end
	local suspects
	local culpritSeen = inc.culprit and table.find(seen, inc.culprit) ~= nil
	if culpritSeen then
		local others = {}
		for _, pid in ipairs(seen) do
			if pid ~= inc.culprit then
				table.insert(others, pid)
			end
		end
		local second = Core.pick(others)
		if not second then
			local all = {}
			for _, q in ipairs(Core.list(true)) do
				if q.id ~= inc.culprit and q.id ~= p.id then
					table.insert(all, q.id)
				end
			end
			second = Core.pick(all)
		end
		suspects = { inc.culprit }
		if second then
			table.insert(suspects, second)
		end
		suspects = Core.shuffle(suspects)
	else
		suspects = {}
		for _, pid in ipairs(Core.shuffle(seen)) do
			if #suspects < 2 then
				table.insert(suspects, pid)
			end
		end
	end
	if #suspects == 0 then
		Core.toast(p, ("%s: \"About the %s? I didn't see who did it, sorry.\""):format(name, inc.title), "social")
		return
	end
	local names = {}
	for _, pid in ipairs(suspects) do
		table.insert(names, Core.nameOf(pid))
	end
	local ev = Evidence.add("Witness", ("%s saw %s around the time of: %s."):format(name, table.concat(names, " or "), inc.title), s.zone or inc.zone, suspects, inc.id)
	Core.toast(p, ("%s: \"I saw %s around then...\""):format(name, table.concat(names, " and ")), "social")
	Evidence.discover(p, ev)
end

function Evidence.bribe(p, s)
	if not Core.inPlay() then
		return false
	end
	local pp = Core.pos(p)
	if not pp or (pp - s.part.Position).Magnitude > Config.InteractRange then
		return false
	end
	if s.bribedUntil > os.clock() then
		Core.toast(p, "They've already been paid to keep quiet.", "info")
		return false
	end
	if not Core.addCoins(p, -Config.BribeCost, "bribe") then
		Core.toast(p, "Not enough coins to bribe.", "bad", "Locked")
		return false
	end
	s.bribedUntil = os.clock() + 150
	Core.toast(p, "🤫 The witness will keep quiet for a while.", "good")
	Bus.fire("Bribed", p, s.role)
	if Core.M.Security then
		Core.M.Security.log(("%s — cash changed hands near the %s"):format(Core.fmtTime(Core.now()), Core.zoneName(s.zone or "Lobby")), "Transaction")
	end
	return true
end

---------------------------------------------------------------- reset / init
function Evidence.reset()
	Evidence.incidents = {}
	Evidence.byIncident = {}
	Evidence.records = {}
	Evidence.journal = {}
	propFolder():ClearAllChildren()
	for _, s in ipairs(Evidence.staff) do
		s.sightings = {}
		s.bribedUntil = 0
		s.asked = {}
	end
	Evidence.broadcastIncidents()
	for _, p in ipairs(Core.realPlayers()) do
		Evidence.sendJournal(p)
	end
end

function Evidence.init()
	propFolder()
	Bus.on("ParticipantRemoving", function(p)
		Evidence.journal[p.id] = nil
		-- the culprit left: close their open incidents so nobody keeps losing coins accusing a ghost
		local closed = false
		for _, inc in ipairs(Evidence.incidents) do
			if not inc.solved and inc.culprit == p.id then
				inc.solved = true
				inc.fled = true
				inc.title ..= " (culprit fled)"
				closed = true
			end
		end
		if closed then
			Evidence.broadcastIncidents()
		end
	end)
end

return Evidence
