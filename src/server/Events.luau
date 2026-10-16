-- Events.luau — random round events (1-3 per round after 3:00) + forced events that story chains need.
-- Every event changes the optimal strategy and is read by other systems via Events.isActive(id):
--   PowerOutage: cameras offline, lights off, guard sight halved (thieves win, detectives lose footage)
--   SecurityLockdown: restricted doors sealed, guards on alert (+40% sight)
--   Storm: outdoor zones slow (Core.updateSpeed) + lightning knock-backs
--   CasinoJackpot: slots pay x6
--   VIPArrival: VIP NPC with a Briefcase (steal target) walks Plaza -> Lobby
--   KitchenFire: kitchen fire enabled, pushes / damages people inside
--   PoliceInvestigation: guards 2x speed, cameras can't be disabled, police NPC at PoliceArrive
--   BoatArrival: boat usable for escape for 90 s
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Bus = require(script.Parent.Bus)
local Core = require(script.Parent.Core)
local Nav = require(script.Parent.Nav)
local Anim = require(script.Parent.Anim)

local Events = {}
Events.active = {} -- id -> {endsAt=clock, startedAt}
Events.schedule = {} -- {id, at (elapsed s)}
Events.history = {} -- ids started this round
Events.vip = nil
local savedLights = {}
-- E1: Storm and PowerOutage can overlap, so neither saves/restores Lighting itself. The base lighting is
-- captured once (Events.init, after the map's Lighting setup) and every change recomputes from the
-- events that are still active, so any overlap order always ends at the original lighting.
local baseLighting = nil
local baseDensity = nil -- Atmosphere density before any storm (a storm restarted mid-restore-tween must not save the foggy value)
local function captureBase()
	if not baseLighting then
		baseLighting = { Brightness = Lighting.Brightness, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient }
		local atm = Lighting:FindFirstChildOfClass("Atmosphere")
		baseDensity = atm and atm.Density
	end
	return baseLighting
end

function Events.isActive(id)
	local e = Events.active[id]
	return e ~= nil and e.endsAt > os.clock()
end

-- target Lighting for the currently active events (base + storm + outage, outage wins)
function Events.lightingTarget()
	local t = table.clone(captureBase())
	if Events.active.Storm then
		t.Brightness = 1
		t.OutdoorAmbient = Color3.fromRGB(90, 95, 110)
	end
	if Events.active.PowerOutage then
		t.Brightness = 0.3
		t.Ambient = Color3.fromRGB(25, 25, 40)
		t.OutdoorAmbient = Color3.fromRGB(40, 40, 60)
	end
	return t
end
local function applyLighting(dur)
	TweenService:Create(Lighting, TweenInfo.new(dur), Events.lightingTarget()):Play()
end

---------------------------------------------------------------- effects
local function lightsOff(off)
	if off then
		savedLights = {}
		for _, part in ipairs(CollectionService:GetTagged("ResortLight")) do
			for _, l in ipairs(part:GetDescendants()) do
				if l:IsA("Light") then
					savedLights[l] = l.Enabled
					l.Enabled = false
				end
			end
			if part:IsA("Light") then
				savedLights[part] = part.Enabled
				part.Enabled = false
			end
		end
		for _, part in ipairs(CollectionService:GetTagged("ResortNeon")) do
			if part:IsA("BasePart") then
				savedLights[part] = part.Material
				part.Material = Enum.Material.SmoothPlastic
			end
		end
		applyLighting(1.2)
		workspace:SetAttribute("PowerOut", true)
	else
		for inst, v in pairs(savedLights) do
			if inst.Parent then
				if inst:IsA("Light") then
					inst.Enabled = v
				elseif inst:IsA("BasePart") then
					inst.Material = v
				end
			end
		end
		savedLights = {}
		applyLighting(1.5)
		workspace:SetAttribute("PowerOut", nil)
	end
end

local function fireFx(on)
	local spot = Core.marker("FireSpot")
	if not spot then
		return
	end
	for _, d in ipairs(spot:GetDescendants()) do
		if d:IsA("Fire") or d:IsA("ParticleEmitter") or d:IsA("Smoke") or d:IsA("Light") then
			d.Enabled = on
		end
	end
	if on and not spot:FindFirstChildWhichIsA("Fire", true) then
		local f = Instance.new("Fire")
		f.Name = "EventFire"
		f.Size = 12
		f.Heat = 15
		f.Parent = spot
	elseif not on then
		local f = spot:FindFirstChild("EventFire")
		if f then
			f:Destroy()
		end
	end
end

local function stormFx(on)
	if on then
		applyLighting(2)
		local atm = Lighting:FindFirstChildOfClass("Atmosphere")
		if atm then
			if atm:GetAttribute("SavedDensity") == nil then
				atm:SetAttribute("SavedDensity", baseDensity or atm.Density)
			end
			TweenService:Create(atm, TweenInfo.new(2), { Density = math.min(0.6, atm:GetAttribute("SavedDensity") + 0.3) }):Play()
		end
		workspace:SetAttribute("Storm", true)
	else
		local atm = Lighting:FindFirstChildOfClass("Atmosphere")
		if atm and atm:GetAttribute("SavedDensity") then
			TweenService:Create(atm, TweenInfo.new(2), { Density = atm:GetAttribute("SavedDensity") }):Play()
			atm:SetAttribute("SavedDensity", nil)
		end
		applyLighting(2)
		workspace:SetAttribute("Storm", nil)
	end
end

---------------------------------------------------------------- VIP / police NPCs
local function npcFolder()
	local f = workspace:FindFirstChild("EHAS_EventNPC")
	if not f then
		f = Instance.new("Folder")
		f.Name = "EHAS_EventNPC"
		f.Parent = workspace
	end
	return f
end

local function spawnVIP()
	local m = Core.marker("VIPArrive")
	local pos = m and m.Position or Core.zonePoint("Plaza")
	if not pos then
		return
	end
	local ok, model = pcall(Core.makeRig, "VIP", {
		outfit = "vip",
		displayName = "👑 VIP Mr. Sterling",
		shirt = Color3.fromRGB(20, 20, 25),
		pants = Color3.fromRGB(20, 20, 25),
		skin = Color3.fromRGB(198, 134, 66),
		hair = "short",
		hairColor = Color3.fromRGB(150, 150, 150),
	})
	if not ok or not model then
		return
	end
	model:PivotTo(CFrame.new(pos + Vector3.new(0, 1, 0)))
	model.Parent = npcFolder()
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.WalkSpeed = 8
	local vip = { model = model, nav = Nav.new(model), hasCase = true }
	Events.vip = vip
	-- briefcase in hand (visual) + steal prompt
	local root = model:FindFirstChild("HumanoidRootPart")
	local case = Core.makeTool("Briefcase")
	case.Parent = model
	pcall(function()
		hum:EquipTool(case)
	end)
	Anim.play(hum, "toolnone", 1, true)
	vip.case = case
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "StealCase"
	pr.ActionText = "Steal Briefcase"
	pr.ObjectText = "VIP"
	pr.HoldDuration = 1.2
	pr.MaxActivationDistance = 8
	pr.RequiresLineOfSight = false
	pr.Parent = root
	pr.Triggered:Connect(function(player)
		local p = Core.byPlayer[player]
		if p then
			Events.stealBriefcase(p)
		end
	end)
	-- walk to the lobby then wander between Plaza/Lobby
	task.spawn(function()
		local stops = { "Lobby", "HotelBar", "Casino", "Lobby", "Plaza" }
		local i = 1
		while Events.vip == vip and model.Parent do
			local target = Core.zonePoint(stops[i])
			if target then
				task.spawn(Nav.goTo, vip.nav, target, 5)
				local t0 = os.clock()
				while Events.vip == vip and model.Parent and os.clock() - t0 < 25 do
					local st = Nav.step(vip.nav, 0.25)
					Anim.autoLoco(model)
					if st == "arrived" then
						break
					end
					task.wait(0.25)
				end
				Anim.setLoco(hum, "idle", 1)
				task.wait(6)
			end
			i = i % #stops + 1
		end
	end)
end

function Events.stealBriefcase(p)
	local vip = Events.vip
	if not vip or not vip.hasCase or not Core.inPlay() then
		return false
	end
	local root = vip.model:FindFirstChild("HumanoidRootPart")
	local pp = Core.pos(p)
	if not root or not pp or (pp - root.Position).Magnitude > 10 or Core.isDetained(p) or p.hidden then
		return false
	end
	if Core.itemCount(p) >= Config.MaxCarry then
		Core.toast(p, "Your hands are full.", "bad")
		return false
	end
	vip.hasCase = false
	if vip.case then
		vip.case:Destroy()
		vip.case = nil
	end
	Anim.stop(vip.model:FindFirstChildOfClass("Humanoid"), "toolnone")
	local pr = root:FindFirstChild("StealCase")
	if pr then
		pr.Enabled = false
	end
	local tool = Core.giveItem(p, "Briefcase", { hot = true, origin = "VIP" })
	Core.toast(p, "💼 You swiped the VIP's briefcase!", "good", "Whoosh")
	local Evidence = Core.M.Evidence
	if Evidence then
		local zone = Core.zoneAt(root.Position) or "Plaza"
		local inc = Evidence.createIncident("Theft", "The VIP's briefcase was stolen!", zone, p, root.Position, "Briefcase")
		Evidence.crimeScene(p, root.Position, inc)
	end
	if not p.isBot and Core.M.Progress then
		Core.M.Progress.addStat(p.player, "itemsStolen", 1)
	end
	Bus.fire("Stolen", p, "Briefcase", "vip", vip.model, tool)
	Bus.fire("ItemObtained", p, "Briefcase", "steal", tool)
	return true
end

function Events.vipReturnBriefcase()
	local vip = Events.vip
	if not vip or vip.hasCase or not vip.model.Parent then
		return
	end
	vip.hasCase = true
	local case = Core.makeTool("Briefcase")
	case.Parent = vip.model
	local hum = vip.model:FindFirstChildOfClass("Humanoid")
	pcall(function()
		hum:EquipTool(case)
	end)
	Anim.play(hum, "toolnone", 1, true)
	vip.case = case
	local root = vip.model:FindFirstChild("HumanoidRootPart")
	local pr = root and root:FindFirstChild("StealCase")
	if pr then
		pr.Enabled = true
	end
end

local function despawnVIP()
	if Events.vip then
		local m = Events.vip.model
		Events.vip = nil
		if m then
			m:Destroy()
		end
	end
	-- a stolen briefcase stays in play (still hot) — that's the point
end

local function spawnPolice()
	local m = Core.marker("PoliceArrive")
	local pos = m and m.Position or Core.zonePoint("Plaza")
	if not pos then
		return
	end
	for i = 1, 2 do
		local ok, model = pcall(Core.makeRig, "Police_" .. i, {
			outfit = "guard",
			displayName = "🚓 Police Officer",
			shirt = Color3.fromRGB(40, 60, 120),
			pants = Color3.fromRGB(20, 25, 45),
			belt = true,
		})
		if ok and model then
			model:PivotTo(CFrame.new(pos + Vector3.new(i * 4 - 6, 1, 0)))
			model.Parent = npcFolder()
			local root = model:FindFirstChild("HumanoidRootPart")
			root.Anchored = true
			task.defer(function()
				Anim.setLoco(model:FindFirstChildOfClass("Humanoid"), "idle", 1)
			end)
		end
	end
end
local function despawnPolice()
	for _, c in ipairs(npcFolder():GetChildren()) do
		if c.Name:sub(1, 7) == "Police_" then
			c:Destroy()
		end
	end
end

---------------------------------------------------------------- per-event hooks
local HOOKS = {
	PowerOutage = {
		start = function()
			lightsOff(true)
			Core.sfxAll("Event")
		end,
		stop = function()
			lightsOff(false)
			Core.toastAll("💡 Power restored. Cameras are back online.", "event")
		end,
	},
	SecurityLockdown = {
		start = function()
			if Core.M.Interact then
				for door in pairs(Core.M.Interact.doors) do
					local lock = door:GetAttribute("Lock") or "none"
					if lock ~= "none" then
						Core.M.Interact.closeDoor(door)
					end
				end
			end
			Core.sfxAll("Alarm")
		end,
		stop = function()
			Core.toastAll("🔓 Lockdown lifted.", "event")
		end,
	},
	Storm = {
		start = function()
			stormFx(true)
			Core.sfxAll("Thunder")
		end,
		stop = function()
			stormFx(false)
			Core.toastAll("🌤️ The storm passed.", "event")
		end,
		tick = function()
			-- lightning near a random outdoor participant every few seconds
			if Core.rng:NextNumber() < 0.25 then
				local outside = {}
				for _, p in pairs(Core.participants) do
					if p.inRound and Core.isOutdoor(p.zone) and not p.hidden then
						table.insert(outside, p)
					end
				end
				local p = Core.pick(outside)
				if p then
					Core.sfxAll("Thunder", Core.pos(p))
					Core.toast(p, "⚡ Lightning struck nearby! Get indoors!", "bad")
					local root = Core.root(p)
					-- no knock-back on high/edge spots (low parapets, water): just the scare
					if root and p.zone ~= "Rooftop" and p.zone ~= "Balcony" and p.zone ~= "Dock" then
						root.AssemblyLinearVelocity = Vector3.new(Core.rng:NextNumber(-15, 15), 25, Core.rng:NextNumber(-15, 15))
					end
				end
			end
		end,
	},
	CasinoJackpot = {
		start = function()
			Core.sfxAll("Jackpot")
		end,
		stop = function()
			Core.toastAll("🕹️ Arcade Frenzy is over.", "event")
		end,
	},
	VIPArrival = {
		start = spawnVIP,
		stop = function()
			despawnVIP()
			Core.toastAll("👑 The VIP has left the resort.", "event")
		end,
	},
	KitchenFire = {
		start = function()
			fireFx(true)
			Core.sfxAll("Alarm")
		end,
		stop = function()
			fireFx(false)
			Core.toastAll("🧯 The kitchen fire is out.", "event")
		end,
		tick = function()
			local spot = Core.marker("FireSpot")
			local exitP = Core.zonePoint("Restaurant")
			for _, p in pairs(Core.participants) do
				if p.inRound and p.zone == "Kitchen" and not p.hidden and not Core.isDetained(p) then
					local hum = Core.hum(p)
					if hum and not p.isBot then
						hum.Health = math.max(10, hum.Health - 8)
					end
					local root = Core.root(p)
					if root and spot then
						local away = (root.Position - spot.Position)
						away = Vector3.new(away.X, 0, away.Z)
						if away.Magnitude < 0.1 then
							away = Vector3.new(1, 0, 0)
						end
						root.AssemblyLinearVelocity = away.Unit * 45 + Vector3.new(0, 20, 0)
					end
					if (p.fireToast or 0) < os.clock() then
						p.fireToast = os.clock() + 4
						Core.toast(p, "🔥 It's too hot in here! Get out!", "bad")
					end
					if p.isBot and exitP then
						p.botForceGoal = exitP
					end
				end
			end
		end,
	},
	PoliceInvestigation = {
		start = function()
			spawnPolice()
			for _, cam in pairs(Core.M.Security and Core.M.Security.cams or {}) do
				cam.disabledUntil = 0
			end
			Core.sfxAll("Alarm")
		end,
		stop = function()
			despawnPolice()
			Core.toastAll("🚓 The police have left.", "event")
		end,
	},
	BoatArrival = {
		start = function()
			workspace:SetAttribute("BoatHere", true)
			Core.sfxAll("Event")
		end,
		stop = function()
			workspace:SetAttribute("BoatHere", nil)
			Core.toastAll("🚤 The boat has left the dock.", "event")
		end,
	},
}
Events.HOOKS = HOOKS

---------------------------------------------------------------- start / stop
function Events.start(id, opts)
	local def = Config.Events[id]
	if not def then
		return false
	end
	if Events.isActive(id) then
		return false
	end
	local duration = (opts and opts.duration) or (id == "PowerOutage" and Config.OutageTime) or (id == "SecurityLockdown" and Config.LockdownTime) or def.duration
	Events.active[id] = { endsAt = os.clock() + duration, startedAt = os.clock() }
	table.insert(Events.history, id)
	local h = HOOKS[id]
	if h and h.start then
		local ok, err = pcall(h.start, opts)
		if not ok then
			warn("[Events] start " .. id .. ": " .. tostring(err))
		end
	end
	local desc = def.desc
	if opts and opts.by then
		if id == "PowerOutage" then
			desc = "Someone pulled the breaker! Lights and cameras are down."
		elseif id == "SecurityLockdown" then
			desc = "Someone pulled the alarm! Restricted doors are sealed."
		end
	end
	Core.broadcast("EventBanner", { id = id, title = def.title, desc = desc, icon = def.icon, duration = duration })
	Core.sfxAll("Event")
	Bus.fire("EventStarted", id, opts)
	return true
end

function Events.stop(id)
	local e = Events.active[id]
	if not e then
		return false
	end
	Events.active[id] = nil
	local h = HOOKS[id]
	if h and h.stop then
		local ok, err = pcall(h.stop)
		if not ok then
			warn("[Events] stop " .. id .. ": " .. tostring(err))
		end
	end
	Bus.fire("EventEnded", id)
	return true
end

function Events.stopAll()
	for id in pairs(Events.active) do
		Events.stop(id)
	end
	Events.active = {}
	despawnVIP()
	despawnPolice()
end

-- Plan this round's events: forced (chains) + random, total 1..3, all after FirstEventAfter.
function Events.planRound(forced, playTime)
	Events.schedule = {}
	Events.history = {}
	playTime = playTime or Config.PlayTime
	local firstAt = math.min(Config.FirstEventAfter, playTime * 0.3)
	local lastAt = playTime - math.min(100, playTime * 0.15)
	local want = Core.rng:NextInteger(Config.EventsMin, Config.EventsMax)
	local list = {}
	for _, id in ipairs(forced or {}) do
		if Config.Events[id] and not table.find(list, id) then
			table.insert(list, id)
		end
	end
	local pool = Core.shuffle(Config.EventOrder)
	for _, id in ipairs(pool) do
		if #list >= math.max(want, #(forced or {})) then
			break
		end
		if not table.find(list, id) then
			table.insert(list, id)
		end
	end
	list = Core.shuffle(list)
	local n = #list
	for i, id in ipairs(list) do
		local slotLen = (lastAt - firstAt) / math.max(1, n)
		local at = firstAt + slotLen * (i - 1) + Core.rng:NextNumber(0, math.max(0, slotLen - Config.EventGapMin * 0.5))
		table.insert(Events.schedule, { id = id, at = at, started = false })
	end
	return Events.schedule
end

-- called by the round tick with elapsed play seconds
function Events.tick(elapsed)
	for _, s in ipairs(Events.schedule) do
		if not s.started and elapsed >= s.at then
			s.started = true
			Events.start(s.id)
		end
	end
	local now = os.clock()
	for id, e in pairs(Events.active) do
		if now >= e.endsAt then
			Events.stop(id)
		else
			local h = HOOKS[id]
			if h and h.tick then
				pcall(h.tick)
			end
		end
	end
end

function Events.activeList()
	local out = {}
	for id, e in pairs(Events.active) do
		if e.endsAt > os.clock() then
			table.insert(out, id)
		end
	end
	return out
end

function Events.init()
	captureBase()
	workspace:SetAttribute("PowerOut", nil)
	workspace:SetAttribute("Storm", nil)
	workspace:SetAttribute("BoatHere", nil)
end

return Events
