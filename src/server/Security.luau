-- Security.luau — cameras (60 studs / 70° cone / LOS), footage + access/transaction logs, the security
-- monitor (view cams, delete footage, disable cams), 3 guard NPCs (patrol GuardPath markers, chase,
-- detain on touch), detention (20 s cell, hot items confiscated back to origin), prank distraction.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Bus = require(script.Parent.Bus)
local Core = require(script.Parent.Core)
local Nav = require(script.Parent.Nav)
local Anim = require(script.Parent.Anim)

local Security = {}
Security.cams = {} -- camId -> {part, id, name, disabledUntil, lastSeen = {pid -> clock}}
Security.camOrder = {}
Security.footage = {} -- ordered {id, camId, pid, zone, time, text, deleted, ev}
Security.logs = {} -- ordered {text, time, kind, ev?}
Security.guards = {}
Security.detentions = {} -- pid -> {untilClock}
Security.prankUntil = 0
local footSeq = 0

-- zone -> items that grant legitimate access (cards / keys)
local ACCESS = {
	SecurityRoom = { "SecurityCard" },
	ElectricalRoom = { "SecurityCard" },
	Reception = { "SecurityCard", "MasterKey" },
	CasinoVIP = { "VIPKeycard" },
	CasinoBackRoom = { "VIPKeycard" },
	Housekeeping = { "MasterKey" },
	PrivateDining = { "MasterKey" },
}
Security.ACCESS = ACCESS

---------------------------------------------------------------- helpers
local function outage()
	local E = Core.M.Events
	return E ~= nil and E.isActive("PowerOutage")
end
local function police()
	local E = Core.M.Events
	return E ~= nil and E.isActive("PoliceInvestigation")
end
local function lockdown()
	local E = Core.M.Events
	return E ~= nil and E.isActive("SecurityLockdown")
end

function Security.camOnline(cam)
	if police() then
		return true
	end
	if outage() then
		return false
	end
	return cam.disabledUntil <= os.clock()
end

-- does p have a right to be in zone?
function Security.hasAccess(p, zone)
	if not zone or not Core.isRestricted(zone) or zone == "Detention" then
		return true
	end
	if Core.isDisguised(p) then
		return true
	end
	if p.access and p.access[zone] then
		return true
	end
	for _, item in ipairs(ACCESS[zone] or {}) do
		if Core.hasItem(p, item) then
			return true
		end
	end
	return false
end

-- reason string when p is acting suspicious right now, else nil
function Security.suspicious(p)
	if not p.inRound or p.hidden or Core.isDetained(p) or Core.isDisguised(p) then
		return nil
	end
	local hot = Core.hotItems(p)
	if #hot > 0 then
		return "carrying the " .. Core.itemName(hot[1]:GetAttribute("ItemId")), hot[1]:GetAttribute("ItemId")
	end
	if p.crowbarUntil and p.crowbarUntil > os.clock() then
		return "forcing a door with a crowbar", nil
	end
	if p.zone and not Security.hasAccess(p, p.zone) then
		return "trespassing in the " .. Core.zoneName(p.zone), nil
	end
	return nil
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function losClear(fromPos, targetChar, ignore)
	local tr = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
	if not tr then
		return false
	end
	local list = { targetChar }
	for _, i in ipairs(ignore or {}) do
		table.insert(list, i)
	end
	local r = Core.resort()
	local z = r and r:FindFirstChild("Zones")
	if z then
		table.insert(list, z)
	end
	local pk = workspace:FindFirstChild("EHAS_Pickups")
	if pk then
		table.insert(list, pk)
	end
	rayParams.FilterDescendantsInstances = list
	local dir = tr.Position - fromPos
	local hit = workspace:Raycast(fromPos, dir, rayParams)
	if not hit then
		return true
	end
	-- glass, invisible parts and other characters don't block
	local inst = hit.Instance
	if inst.Transparency > 0.6 or inst.Material == Enum.Material.Glass or inst:FindFirstAncestorOfClass("Model") and inst:FindFirstAncestorOfClass("Model"):FindFirstChildOfClass("Humanoid") then
		return true
	end
	return false
end
Security.losClear = losClear

function Security.camSees(cam, p)
	local part = cam.part
	local pos = Core.pos(p)
	if not pos or not part.Parent then
		return false
	end
	local to = pos - part.Position
	local d = to.Magnitude
	if d > Config.CameraRange or d < 0.1 then
		return false
	end
	local cosHalf = math.cos(math.rad(Config.CameraConeDeg / 2))
	if part.CFrame.LookVector:Dot(to.Unit) < cosHalf then
		return false
	end
	return losClear(part.Position, Core.char(p), { part.Parent and part.Parent:IsA("Model") and part.Parent or part })
end

---------------------------------------------------------------- logs + footage
-- text, kind ("Access"|"Transaction"), suspects?, incident?
function Security.log(text, kind, suspects, incidentId, zone)
	local entry = { text = text, time = Core.now(), kind = kind or "Access" }
	if suspects and #suspects > 0 and Core.M.Evidence then
		entry.ev = Core.M.Evidence.add(kind == "Transaction" and "Transaction" or "AccessLog", text, zone or "SecurityRoom", suspects, incidentId)
	end
	table.insert(Security.logs, entry)
	if #Security.logs > 80 then
		table.remove(Security.logs, 1)
	end
	Security.refreshMonitors()
	return entry
end

function Security.addFootage(cam, p, reason, itemId)
	footSeq += 1
	local zone = p.zone or Core.zoneAt(cam.part.Position) or "Lobby"
	local Evidence = Core.M.Evidence
	local inc = Evidence and (itemId and Evidence.latestIncidentFor(itemId) or nil)
	local text = ("CAM %s (%s) %s: %s %s"):format(cam.name, Core.zoneName(zone), Core.fmtTime(Core.now()), p.name, reason)
	local f = { id = "f" .. footSeq, camId = cam.id, pid = p.id, zone = zone, time = Core.now(), text = text, deleted = false }
	if Evidence then
		f.ev = Evidence.add("Footage", text, zone, { p.id }, inc and inc.id or nil, { footageId = f.id })
	end
	table.insert(Security.footage, f)
	Security.refreshMonitors()
	Bus.fire("Footage", f, p)
	return f
end

function Security.deleteFootage(p, fid)
	for _, f in ipairs(Security.footage) do
		if f.id == fid and not f.deleted then
			f.deleted = true
			if f.ev and Core.M.Evidence then
				Core.M.Evidence.destroy(f.ev)
			end
			Security.log(("%s — a recording from CAM %s was deleted"):format(Core.fmtTime(Core.now()), Security.cams[f.camId] and Security.cams[f.camId].name or "?"), "Access")
			Core.toast(p, "🗑️ Footage deleted.", "good", "Click")
			Bus.fire("FootageDeleted", p, f)
			Security.refreshMonitors()
			return true
		end
	end
	return false
end

function Security.disableCam(p, camId)
	local cam = Security.cams[camId]
	if not cam then
		return false
	end
	if police() then
		Core.toast(p, "🕵️ Police are watching — cameras can't be disabled right now.", "bad", "Locked")
		return false
	end
	if cam.disabledUntil > os.clock() then
		return false
	end
	cam.disabledUntil = os.clock() + Config.DisableCamTime
	cam.part:SetAttribute("Online", false)
	Core.toast(p, ("📴 CAM %s offline for %d s."):format(cam.name, Config.DisableCamTime), "good", "Click")
	Bus.fire("CamDisabled", p, cam.id)
	Security.refreshMonitors()
	task.delay(Config.DisableCamTime + 0.1, function()
		Security.refreshMonitors()
	end)
	return true
end

---------------------------------------------------------------- monitor
local function monitorPayload(p)
	local m = p.monitor
	local role = m and m.role or "Security"
	local cams, footage, logs = {}, {}, {}
	if role == "Security" or role == "Casino" then
		for _, id in ipairs(Security.camOrder) do
			local cam = Security.cams[id]
			local z = cam.part:GetAttribute("Zone")
			if role == "Security" or z == "Casino" or z == "CasinoVIP" or z == "CasinoBackRoom" then
				table.insert(cams, { id = id, name = cam.name, online = Security.camOnline(cam) })
			end
		end
	end
	if role == "Security" then
		for i = #Security.footage, 1, -1 do
			local f = Security.footage[i]
			table.insert(footage, { id = f.id, text = f.text, time = f.time, deleted = f.deleted })
			if #footage >= 30 then
				break
			end
		end
	end
	for i = #Security.logs, 1, -1 do
		local l = Security.logs[i]
		if role == "Security" or (role == "Reception" and l.kind == "Access") or (role == "Casino" and l.kind == "Transaction") then
			table.insert(logs, { text = l.text, time = l.time })
			if #logs >= 30 then
				break
			end
		end
	end
	return {
		cams = cams,
		footage = footage,
		logs = logs,
		canDelete = role == "Security",
		canDisable = role == "Security" and not police(),
		role = role,
	}
end

local function monitorValid(p)
	local m = p.monitor
	if not m or not m.part or not m.part.Parent then
		return false
	end
	local pos = Core.pos(p)
	return pos ~= nil and (pos - m.part.Position).Magnitude <= Config.InteractRange + 4 and not Core.isDetained(p)
end

function Security.openMonitor(p, part, role)
	p.monitor = { part = part, role = role }
	-- reading the monitor reveals the evidence in it (footage + logs relevant to this console)
	local Evidence = Core.M.Evidence
	if Evidence and Core.inPlay() then
		if role == "Security" then
			for _, f in ipairs(Security.footage) do
				if f.ev and not f.deleted then
					Evidence.discover(p, f.ev)
				end
			end
		end
		for _, l in ipairs(Security.logs) do
			if l.ev and (role == "Security" or (role == "Reception" and l.kind == "Access") or (role == "Casino" and l.kind == "Transaction")) then
				Evidence.discover(p, l.ev)
			end
		end
	end
	Bus.fire("MonitorOpened", p, role)
	if not p.isBot then
		Core.send(p, "Monitor", monitorPayload(p))
	end
end

function Security.refreshMonitors()
	for _, p in pairs(Core.participants) do
		if p.monitor and not p.isBot then
			if monitorValid(p) then
				Core.send(p, "Monitor", monitorPayload(p))
			else
				p.monitor = nil
			end
		end
	end
end

---------------------------------------------------------------- alerts / guards
local function guardFolder()
	local f = workspace:FindFirstChild("EHAS_Guards")
	if not f then
		f = Instance.new("Folder")
		f.Name = "EHAS_Guards"
		f.Parent = workspace
	end
	return f
end

function Security.alert(p, pos, reason)
	if not p or Core.isDetained(p) or not Core.inPlay() then
		return
	end
	local fresh = not p.wantedUntil or p.wantedUntil < os.clock()
	p.wantedUntil = os.clock() + 30
	p.suspicion += 1
	-- send the nearest 2 guards (all 3 during police / lockdown)
	local pp = pos or Core.pos(p)
	local sorted = {}
	for _, g in ipairs(Security.guards) do
		if g.root and g.root.Parent and pp then
			table.insert(sorted, { g = g, d = (g.root.Position - pp).Magnitude })
		end
	end
	table.sort(sorted, function(a, b)
		return a.d < b.d
	end)
	local n = (police() or lockdown()) and 3 or 2
	for i = 1, math.min(n, #sorted) do
		local g = sorted[i].g
		if g.state ~= "chase" or g.target == p then
			g.state = "chase"
			g.target = p
			g.chaseStart = os.clock()
			g.lastKnown = pp
		end
	end
	if fresh then
		Core.toast(p, ("🚨 Security spotted you %s! Run, hide or disguise!"):format(reason or ""), "security", "Detected")
	end
	Bus.fire("Alert", p, reason)
end

function Security.dropPursuit(p)
	for _, g in ipairs(Security.guards) do
		if g.target == p then
			g.state = "return"
			g.target = nil
		end
	end
	p.wantedUntil = 0
end

function Security.prank(pos, zone)
	Security.prankUntil = os.clock() + Config.PrankTime
	for _, g in ipairs(Security.guards) do
		if g.state ~= "chase" then
			g.state = "prank"
			g.prankPos = pos
			task.spawn(Nav.goTo, g.nav, pos, 6)
		end
	end
	Bus.fire("Prank", zone)
end

local GUARD_LOOK = {
	{ name = "Officer Brooks", skin = Color3.fromRGB(141, 85, 36), hair = "short", hairColor = Color3.fromRGB(20, 20, 20) },
	{ name = "Officer Reyes", skin = Color3.fromRGB(224, 172, 105), hair = "bun", hairColor = Color3.fromRGB(70, 45, 25) },
	{ name = "Officer Novak", skin = Color3.fromRGB(255, 224, 196), hair = "short", hairColor = Color3.fromRGB(200, 160, 90) },
}

function Security.spawnGuards()
	for _, g in ipairs(Security.guards) do
		if g.model then
			g.model:Destroy()
		end
	end
	Security.guards = {}
	for n = 1, Config.GuardCount do
		local path = Core.markers(("GuardPath_%d_"):format(n))
		table.sort(path, function(a, b)
			return (tonumber(a.Name:match("_(%d+)$")) or 0) < (tonumber(b.Name:match("_(%d+)$")) or 0)
		end)
		if #path == 0 then
			local p = Core.zonePoint("Lobby") or Core.zonePoint("Plaza")
			if p then
				path = { { Position = p } }
			end
		end
		if #path > 0 then
			local gl = GUARD_LOOK[(n - 1) % #GUARD_LOOK + 1]
			local look = {
				outfit = "guard",
				displayName = "👮 " .. gl.name,
				skin = gl.skin,
				hair = gl.hair,
				hairColor = gl.hairColor,
				shirt = Color3.fromRGB(30, 42, 90),
				pants = Color3.fromRGB(24, 30, 58),
				shoes = Color3.fromRGB(20, 20, 22),
				belt = true,
			}
			local ok, model = pcall(Core.makeRig, "Guard_" .. n, look)
			if ok and model then
				model:SetAttribute("Guard", true)
				model:PivotTo(CFrame.new(path[1].Position + Vector3.new(0, 1, 0)))
				model.Parent = guardFolder()
				local root = model:FindFirstChild("HumanoidRootPart")
				pcall(function()
					root:SetNetworkOwner(nil)
				end)
				local hum = model:FindFirstChildOfClass("Humanoid")
				hum.WalkSpeed = Config.GuardPatrolSpeed
				local g = {
					n = n,
					model = model,
					root = root,
					hum = hum,
					nav = Nav.new(model),
					path = path,
					wp = 1,
					state = "patrol",
					target = nil,
					touchT = {},
				}
				table.insert(Security.guards, g)
				-- detain on touch
				for _, part in ipairs(model:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Touched:Connect(function(hit)
							if g.state ~= "chase" or not g.target then
								return
							end
							local p = Core.fromInstance(hit)
							if p and p == g.target then
								Security.detain(p, "Caught by " .. gl.name, g)
							end
						end)
					end
				end
			else
				warn("[Security] guard spawn failed: " .. tostring(model))
			end
		end
	end
end

local function guardSees(g, p, range)
	local pos = Core.pos(p)
	if not pos or not g.root then
		return false
	end
	local to = pos - g.root.Position
	local d = to.Magnitude
	if d > range then
		return false
	end
	if d > 8 and g.root.CFrame.LookVector:Dot(to.Unit) < 0.2 then
		return false
	end
	return losClear(g.root.Position + Vector3.new(0, 1.5, 0), Core.char(p), { g.model })
end

local function guardStep(g, dt)
	if not g.root or not g.root.Parent then
		return
	end
	local speedMult = police() and 2 or 1
	local playing = Core.inPlay()
	-- chase
	if g.state == "chase" then
		local t = g.target
		local giveUp = not playing or not t or not Core.participants[t.id] or t.hidden or Core.isDisguised(t) or Core.isDetained(t)
			or (os.clock() - (g.chaseStart or 0)) > Config.GuardGiveUpTime
		if giveUp then
			if t and t.hidden and Core.participants[t.id] then
				Core.toast(t, "😮‍💨 The guard lost track of you.", "good")
			end
			if t then
				t.wantedUntil = 0
			end
			g.state = "return"
			g.target = nil
		else
			g.hum.WalkSpeed = math.min(Config.GuardChaseSpeed * (police() and 1.35 or 1), 26)
			local tp = Core.pos(t)
			local d = (tp - g.root.Position).Magnitude
			if d <= Config.GuardCatchRange then
				Security.detain(t, "Caught by security", g)
				return
			end
			if d < 45 and guardSees(g, t, 45) then
				g.lastKnown = tp
				Nav.chase(g.nav, tp)
			else
				if not g.nav.target or (g.nav.target - (g.lastKnown or tp)).Magnitude > 6 then
					task.spawn(Nav.goTo, g.nav, g.lastKnown or tp, 3)
				end
				-- cheap tracking: last known position updates while the target is wanted (radio)
				if (g.repath or 0) < os.clock() then
					g.repath = os.clock() + 1.5
					g.lastKnown = tp
					task.spawn(Nav.goTo, g.nav, tp, 3)
				end
				Nav.step(g.nav, dt)
			end
			return
		end
	end
	-- sight checks while patrolling (not when distracted by a prank)
	if playing and g.state ~= "prank" then
		local range = Config.GuardSightRange * (outage() and 0.5 or 1) * ((lockdown() or police()) and 1.4 or 1)
		for _, p in pairs(Core.participants) do
			if p.inRound and (Security.suspicious(p) or (p.wantedUntil and p.wantedUntil > os.clock() and not p.hidden and not Core.isDisguised(p))) then
				if guardSees(g, p, range) then
					Security.alert(p, Core.pos(p), Security.suspicious(p) or "")
					g.state = "chase"
					g.target = p
					g.chaseStart = os.clock()
					return
				end
			end
		end
	end
	if g.state == "prank" then
		g.hum.WalkSpeed = Config.GuardChaseSpeed * 0.8
		if os.clock() > Security.prankUntil then
			g.state = "return"
		else
			Nav.step(g.nav, dt)
			return
		end
	end
	-- patrol / return
	g.hum.WalkSpeed = Config.GuardPatrolSpeed * speedMult
	local wp = g.path[g.wp]
	if not wp then
		return
	end
	if g.state == "return" then
		g.state = "patrol"
		task.spawn(Nav.goTo, g.nav, wp.Position, 4)
	end
	local st = Nav.step(g.nav, dt)
	if st == "arrived" or st == "idle" then
		g.wp = g.wp % #g.path + 1
		task.spawn(Nav.goTo, g.nav, g.path[g.wp].Position, 4)
	end
end

---------------------------------------------------------------- detention
local function cellPos()
	local m = Core.marker("DetentionCell")
	if m then
		return m.Position
	end
	return Core.zonePoint("Detention") or Core.zonePoint("Plaza")
end
local function exitPos()
	local m = Core.marker("DetentionExit")
	if m then
		return m.Position
	end
	return Core.zonePoint("Lobby") or Core.zonePoint("Plaza")
end
Security.cellPos = cellPos
Security.exitPos = exitPos

function Security.detain(p, reason, guard, duration)
	if not p or Core.isDetained(p) then
		return false
	end
	duration = duration or Config.DetentionTime
	if p.hidden and Core.M.Interact then
		Core.M.Interact.unhide(p)
	end
	p.detainedUntil = os.clock() + duration
	p.wantedUntil = 0
	p.timesDetained = (p.timesDetained or 0) + 1
	-- confiscate hot items
	local confiscated = {}
	for _, t in ipairs(Core.hotItems(p)) do
		table.insert(confiscated, t:GetAttribute("ItemId"))
		if Core.M.Interact then
			Core.M.Interact.returnToOrigin(t)
		else
			t:Destroy()
		end
	end
	for _, g in ipairs(Security.guards) do
		if g.target == p then
			g.state = "return"
			g.target = nil
		end
	end
	if guard and guard.hum then
		Anim.play(guard.hum, "point", 1, false)
	end
	Core.teleport(p, cellPos())
	Security.detentions[p.id] = p.detainedUntil
	Core.send(p, "Detained", { untilTime = Core.now() + duration, reason = reason or "Detained" })
	Core.sfx(p, "Detected")
	local extra = #confiscated > 0 and (" (confiscated: " .. table.concat(confiscated, ", ") .. ")") or ""
	Core.toastAll(("👮 %s was detained by security%s."):format(p.name, #confiscated > 0 and " with a stolen item" or ""), "security")
	Core.toast(p, ("⛓️ Detained for %d s%s"):format(duration, extra), "bad", "Bruh")
	if not p.isBot and Core.M.Progress then
		Core.M.Progress.addStat(p.player, "timesCaught", 1)
	end
	Bus.fire("Detained", p, reason, confiscated)
	return true
end

function Security.release(p)
	if not Security.detentions[p.id] then
		return
	end
	Security.detentions[p.id] = nil
	p.detainedUntil = 0
	Core.teleport(p, exitPos())
	Core.send(p, "Detained", { untilTime = 0, reason = "" })
	Core.toast(p, "🔓 You're free to go. Behave.", "info")
	Bus.fire("Released", p)
end

function Security.releaseAll()
	for pid in pairs(Security.detentions) do
		local p = Core.participants[pid]
		if p then
			Security.release(p)
		end
	end
	Security.detentions = {}
end

---------------------------------------------------------------- scanning loop
local function scanCameras()
	if not Core.inPlay() then
		return
	end
	local now = os.clock()
	for _, id in ipairs(Security.camOrder) do
		local cam = Security.cams[id]
		local online = Security.camOnline(cam)
		if cam.part:GetAttribute("Online") ~= online then
			cam.part:SetAttribute("Online", online)
		end
		if online then
			for _, p in pairs(Core.participants) do
				if p.inRound then
					local reason, itemId = Security.suspicious(p)
					if reason and Security.camSees(cam, p) then
						local last = cam.lastSeen[p.id]
						if not last or now - last >= Config.CameraDetectCooldown then
							cam.lastSeen[p.id] = now
							Security.addFootage(cam, p, reason, itemId)
							Security.alert(p, Core.pos(p), "on camera " .. reason)
							Bus.fire("Detected", p, cam.id, reason)
						end
					end
				end
			end
		end
	end
end

function Security.resetRound()
	Security.releaseAll()
	Security.footage = {}
	Security.logs = {}
	Security.prankUntil = 0
	for _, cam in pairs(Security.cams) do
		cam.disabledUntil = 0
		cam.lastSeen = {}
		cam.part:SetAttribute("Online", true)
	end
	for _, g in ipairs(Security.guards) do
		g.state = "return"
		g.target = nil
		g.wp = 1
		if g.path[1] and g.root then
			g.model:PivotTo(CFrame.new(g.path[1].Position + Vector3.new(0, 1, 0)))
		end
	end
	for _, p in pairs(Core.participants) do
		p.access = {}
		p.wantedUntil = 0
		p.monitor = nil
	end
end

function Security.indexCameras()
	Security.cams = {}
	Security.camOrder = {}
	for _, part in ipairs(Core.interactParts("Camera")) do
		local id = part:GetAttribute("CamId") or part:GetAttribute("Id") or ("cam" .. (#Security.camOrder + 1))
		local name = part:GetAttribute("Label") or id
		Security.cams[id] = { part = part, id = id, name = name, disabledUntil = 0, lastSeen = {} }
		table.insert(Security.camOrder, id)
		part:SetAttribute("Online", true)
	end
	table.sort(Security.camOrder)
end

function Security.init()
	Security.indexCameras()
	-- access logs from doors (card/key/code uses) — suspects = people near the door (1..3, incl. the user)
	Bus.on("DoorUsed", function(p, door, method)
		local zone = door:GetAttribute("Zone") or Core.zoneAt(door.Position) or "Lobby"
		if method == "key" or method == "card" or method == "code" or method == "master" or method == "staff" then
			p.access = p.access or {}
			p.access[zone] = true
		end
		if method == "free" then
			return
		end
		local how = ({ key = "a key", card = "a Security Card", code = "the door code", master = "the Master Key", staff = "a staff uniform", crowbar = "a CROWBAR" })[method] or method
		local sus = { p.id }
		for _, q in ipairs(Core.nearby(door.Position, 25, p.id)) do
			if #sus < 3 then
				table.insert(sus, q.id)
			end
		end
		local Evidence = Core.M.Evidence
		local inc = Evidence and Evidence.latestIncidentFor(nil)
		local incId = (inc and not inc.solved and os.clock() - inc.clock < 120) and inc.id or nil
		Security.log(("%s — %s door opened with %s"):format(Core.fmtTime(Core.now()), door:GetAttribute("Label") or Core.zoneName(zone), how), "Access", Core.shuffle(sus), incId, zone)
	end)
	Bus.on("ParticipantRemoving", function(p)
		Security.detentions[p.id] = nil
		for _, g in ipairs(Security.guards) do
			if g.target == p then
				g.state = "return"
				g.target = nil
			end
		end
	end)
	-- actions (monitor)
	Core.onAction("ViewCam", function(player, args, p)
		local camId = Core.vStr(args.camId, 64)
		if not p or not camId or not monitorValid(p) then
			return
		end
		local cam = Security.cams[camId]
		if not cam then
			return
		end
		local role = p.monitor.role
		local z = cam.part:GetAttribute("Zone")
		if role == "Reception" or (role == "Casino" and z ~= "Casino" and z ~= "CasinoVIP" and z ~= "CasinoBackRoom") then
			return
		end
		if not Security.camOnline(cam) then
			Core.toast(p, "📺 NO SIGNAL", "bad")
			return
		end
		local cf = cam.part.CFrame * CFrame.new(0, -0.3, -cam.part.Size.Z / 2 - 0.6)
		Core.send(p, "ViewCam", { camId = camId, cframe = cf })
		-- watching a camera reveals guests currently in view (no names on the card if hidden/disguised)
		Bus.fire("CamViewed", p, camId)
	end)
	Core.onAction("CloseMonitor", function(player, args, p)
		if p then
			p.monitor = nil
		end
	end)
	Core.onAction("DeleteFootage", function(player, args, p)
		local fid = Core.vStr(args.id, 32)
		if not p or not fid or not monitorValid(p) or p.monitor.role ~= "Security" or not Core.inPlay() then
			return
		end
		Security.deleteFootage(p, fid)
	end)
	Core.onAction("DisableCam", function(player, args, p)
		local camId = Core.vStr(args.camId, 64)
		if not p or not camId or not monitorValid(p) or p.monitor.role ~= "Security" or not Core.inPlay() then
			return
		end
		Security.disableCam(p, camId)
	end)
	-- loops
	task.spawn(function()
		while true do
			task.wait(Config.CameraScanInterval)
			local ok, err = pcall(scanCameras)
			if not ok then
				warn("[Security] cam scan: " .. tostring(err))
			end
		end
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.2)
			local now = os.clock()
			local dt = now - last
			last = now
			for _, g in ipairs(Security.guards) do
				local ok, err = pcall(guardStep, g, dt)
				if not ok then
					warn("[Security] guard: " .. tostring(err))
				end
				pcall(Anim.autoLoco, g.model)
			end
			-- detention: keep them in the cell, release on time
			for pid, untilT in pairs(Security.detentions) do
				local p = Core.participants[pid]
				if not p then
					Security.detentions[pid] = nil
				elseif now >= untilT then
					Security.release(p)
				else
					local pos = Core.pos(p)
					local cell = cellPos()
					if pos and cell and (pos - cell).Magnitude > 14 then
						Core.teleport(p, cell)
					end
				end
			end
		end
	end)
end

return Security
