-- Interact.luau — every tagged `Interact` part gets server-made ProximityPrompts and server logic:
-- doors (locks/keys/codes/cards/crowbar/secret), search loot, hide self / stash items, dig/bury,
-- computers, power box, alarm, phones, casino, food, shops, boat escape, switches, elevators,
-- pedestals (steal/return), notes, board; plus world pickups, item drop + framing, swiping from
-- other guests, tool activation (photo camera, uniform disguise, flashlight, treasure map).
-- Players (prompts / Action remote) and bots share Interact.use(p, part, opts) — same rules.
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Items = require(ReplicatedStorage:WaitForChild("Items"))
local Bus = require(script.Parent.Bus)
local Core = require(script.Parent.Core)

local Interact = {}
Interact.parts = {} -- Id -> part
Interact.doors = {} -- part -> {closedCF, open=bool, closeAt, openedBy}
Interact.pedestals = {} -- part -> {itemId, present, display}
Interact.stash = {} -- part -> {tools}
Interact.pickups = {} -- pickupPart -> tool
Interact.codeOk = {} -- doorId -> {pid=true}
Interact.codeFails = {} -- pid -> {n, until}
Interact.searched = {} -- part -> {pid -> clock}
Interact.fixedTaken = {} -- part -> true (fixed loot once per round)
Interact.cooldown = {} -- key -> clock
Interact.occupant = {} -- hide part -> p
Interact.treasureSpot = nil
Interact.treasureFound = false
Interact.escaped = {} -- {pid, itemIds}

local SHOP_STOCK = {
	Clothing = { { id = "StaffUniform", price = 40 } },
	Souvenir = { { id = "TreasureMap", price = 30 }, { id = "PhotoCamera", price = 40 } },
	General = { { id = "Flashlight", price = 15 }, { id = "PhotoCamera", price = 40 }, { id = "Crowbar", price = 60 } },
	Jewelry = { { id = "SecretLetter", price = 25 } },
	Beach = { { id = "Flashlight", price = 15 }, { id = "TreasureMap", price = 30 } },
}
Interact.SHOP_STOCK = SHOP_STOCK

local STAFF_DOOR_ZONES = { Kitchen = true, Housekeeping = true }

---------------------------------------------------------------- helpers
local function attr(part, name, default)
	local v = part:GetAttribute(name)
	if v == nil then
		return default
	end
	return v
end
local function zoneOf(part)
	return attr(part, "Zone", Core.zoneAt(part.Position) or "Lobby")
end
local function label(part)
	return attr(part, "Label", attr(part, "Kind", "Object"))
end
local function inRange(p, part, extra)
	local pos = Core.pos(p)
	if not pos then
		return false
	end
	local half = math.max(part.Size.X, part.Size.Y, part.Size.Z) / 2
	return (pos - part.Position).Magnitude <= Config.InteractRange + math.min(half, 10) + (extra or 0)
end
local function cool(key, secs)
	local now = os.clock()
	local t = Interact.cooldown[key]
	if t and t > now then
		return false
	end
	Interact.cooldown[key] = now + secs
	return true
end
local function fail(p, msg, sfx)
	Core.toast(p, msg, "bad", sfx or "Locked")
	return false, msg
end
local function interacted(p, kind, part)
	Bus.fire("Interacted", p, kind, part, zoneOf(part))
end
local function roundLog(text, kind)
	if Core.M.Security then
		Core.M.Security.log(("%s — %s"):format(Core.fmtTime(Core.now()), text), kind)
	end
end
local function pickupFolder()
	local f = workspace:FindFirstChild("EHAS_Pickups")
	if not f then
		f = Instance.new("Folder")
		f.Name = "EHAS_Pickups"
		f.Parent = workspace
	end
	return f
end

local function addPrompt(part, name, actionText, hold, key, offsetIdx)
	local pr = Instance.new("ProximityPrompt")
	pr.Name = name
	pr.ActionText = actionText
	pr.ObjectText = label(part)
	pr.HoldDuration = hold or 0
	pr.MaxActivationDistance = 10
	pr.RequiresLineOfSight = false
	pr.Style = Enum.ProximityPromptStyle.Default
	if key then
		pr.KeyboardKeyCode = key
	end
	if offsetIdx and offsetIdx > 0 then
		pr.UIOffset = Vector2.new(0, 72 * offsetIdx)
		pr.GamepadKeyCode = offsetIdx == 1 and Enum.KeyCode.ButtonY or Enum.KeyCode.ButtonB
	end
	pr.Parent = part
	pr.Triggered:Connect(function(player)
		local p = Core.byPlayer[player]
		if p then
			local ok, err = pcall(Interact.use, p, part, { action = name })
			if not ok then
				warn("[Interact] " .. tostring(err))
			end
		end
	end)
	return pr
end

---------------------------------------------------------------- doors
local function doorLock(door)
	return attr(door, "Lock", "none")
end

function Interact.isDoorOpen(door)
	local d = Interact.doors[door]
	return d ~= nil and d.open
end

function Interact.openDoor(door, duration, by)
	local d = Interact.doors[door]
	if not d then
		return
	end
	d.closeAt = os.clock() + (duration or 4)
	d.openedBy = by and by.id or nil
	if d.open then
		return
	end
	d.open = true
	local s = door.Size
	local offset
	if s.X >= s.Z then
		offset = CFrame.new(s.X * 0.92, 0, 0)
	else
		offset = CFrame.new(0, 0, s.Z * 0.92)
	end
	door.CanCollide = false
	TweenService:Create(door, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = d.closedCF * offset }):Play()
	Core.sfxAll("DoorOpen", door.Position)
	local pr = door:FindFirstChild("Use")
	if pr then
		pr.ActionText = "Close"
	end
end

function Interact.closeDoor(door)
	local d = Interact.doors[door]
	if not d or not d.open then
		return
	end
	d.open = false
	local tw = TweenService:Create(door, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = d.closedCF })
	tw:Play()
	tw.Completed:Connect(function()
		if not d.open then
			door.CanCollide = true
		end
	end)
	local pr = door:FindFirstChild("Use")
	if pr then
		pr.ActionText = "Open"
	end
end

-- returns method ("free"|"key"|"master"|"card"|"code"|"staff"|"crowbar") or nil, reason
function Interact.canOpen(p, door)
	local lock = doorLock(door)
	local zone = zoneOf(door)
	-- M1/E3: locked rooms always open from the inside (also during a lockdown), so nobody gets trapped.
	-- Door attribute Inside = "+"/"-": the side of the door plane the room is on (set by the map builder).
	local inside = door:GetAttribute("Inside")
	local pos = inside and Core.pos(p)
	if pos and lock ~= "secret" and zone ~= "Detention" then
		local d = Interact.doors[door]
		local lp = ((d and d.closedCF) or door.CFrame):PointToObjectSpace(pos)
		local side = if door.Size.X >= door.Size.Z then lp.Z else lp.X
		if (inside == "+" and side > 0) or (inside == "-" and side < 0) then
			return "free"
		end
	end
	local Events = Core.M.Events
	local restrictedDoor = lock ~= "none" or Core.isRestricted(zone)
	if Events and Events.isActive("SecurityLockdown") and restrictedDoor then
		return nil, "🚨 LOCKDOWN — this door is sealed."
	end
	if lock == "none" then
		return "free"
	end
	if lock == "secret" then
		return nil, "It won't budge. Maybe there's a hidden switch..."
	end
	if lock:sub(1, 4) == "key:" then
		local item = lock:sub(5)
		if Core.hasItem(p, item) then
			return item == "SecurityCard" and "card" or "key"
		end
	end
	if lock == "security" and Core.hasItem(p, "SecurityCard") then
		return "card"
	end
	if lock == "code" then
		local ok = Interact.codeOk[attr(door, "Id", "")]
		if ok and ok[p.id] then
			return "code"
		end
	end
	if Core.hasItem(p, "MasterKey") and (zone == "GuestRooms" or zone == "Housekeeping") and lock ~= "security" then
		return "master"
	end
	if Core.isDisguised(p) and STAFF_DOOR_ZONES[zone] and lock ~= "security" then
		return "staff"
	end
	if lock ~= "security" and lock ~= "code" and Core.hasItem(p, "Crowbar") then
		return "crowbar"
	end
	if lock == "code" then
		if Core.hasItem(p, "Crowbar") then
			return "crowbar"
		end
		return nil, "code"
	end
	if lock == "security" then
		return nil, "🔒 Security access only (Security Card)."
	end
	if lock:sub(1, 4) == "key:" then
		return nil, ("🔒 Locked — needs a %s."):format(Core.itemName(lock:sub(5)))
	end
	return nil, "🔒 Locked."
end

local function useDoor(p, door)
	local d = Interact.doors[door]
	if d and d.open then
		-- anti-grief: someone else's freshly opened door can't be slammed shut right away
		if d.openedBy and d.openedBy ~= p.id and os.clock() < d.closeAt - 2 then
			return fail(p, "Someone just opened this door.")
		end
		Interact.closeDoor(door)
		return true
	end
	local method, reason = Interact.canOpen(p, door)
	if not method then
		if reason == "code" then
			if not p.isBot then
				Core.send(p, "Keypad", { doorId = attr(door, "Id", "") })
			end
			return false, "code"
		end
		return fail(p, reason or "Locked.")
	end
	Interact.openDoor(door, 4, p)
	local zone = zoneOf(door)
	if method == "crowbar" then
		p.crowbarUntil = os.clock() + 10
		Core.sfxAll("VineBoom", door.Position)
		local Evidence = Core.M.Evidence
		if Evidence then
			local inc = Evidence.createIncident("BrokenDoor", ("A door was forced open (%s)"):format(label(door)), zone, p, door.Position)
			local ev = Evidence.add("BrokenDoor", ("The %s door was pried open with a crowbar."):format(label(door)), zone, Evidence.suspectsFor(p.id, door.Position, Core.rng:NextInteger(1, 2)), inc.id)
			Evidence.spawnBrokenDoorClue(door, ev)
		end
		if Core.M.Security then
			Core.M.Security.alert(p, door.Position, "forced a door")
		end
		Interact.openDoor(door, 10, p)
	end
	if method ~= "free" then
		Bus.fire("DoorUsed", p, door, method)
	end
	interacted(p, "Door", door)
	return true
end

function Interact.enterCode(p, doorId, code)
	local door = Interact.parts[doorId]
	if not door or attr(door, "Kind") ~= "Door" or doorLock(door) ~= "code" then
		return false
	end
	if not inRange(p, door) then
		return false
	end
	local f = Interact.codeFails[p.id]
	if f and f.untilT and f.untilT > os.clock() then
		return fail(p, "Keypad locked. Try again in a few seconds.")
	end
	if tostring(attr(door, "Code", "")) == code then
		Interact.codeOk[doorId] = Interact.codeOk[doorId] or {}
		Interact.codeOk[doorId][p.id] = true
		Interact.codeFails[p.id] = nil
		Core.toast(p, "✅ Code accepted.", "good", "Click")
		Interact.openDoor(door, 4, p)
		Bus.fire("DoorUsed", p, door, "code")
		interacted(p, "Door", door)
		return true
	end
	f = f or { n = 0 }
	f.n += 1
	if f.n >= 3 then
		f.n = 0
		f.untilT = os.clock() + 10
	end
	Interact.codeFails[p.id] = f
	return fail(p, "❌ Wrong code.")
end

---------------------------------------------------------------- items in the world
local function makeDisplay(itemId, cf)
	local h = Core.buildHandle(itemId)
	local model = Instance.new("Model")
	model.Name = "Display_" .. itemId
	h.Parent = model
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = true
		end
	end
	-- welds are irrelevant when anchored; place so the bottom sits at cf
	local mn, mx = Core.handleBounds(h)
	model.PrimaryPart = h
	model:PivotTo(cf * CFrame.new(0, -mn.Y, 0))
	return model, h, mx.Y - mn.Y
end

-- drop a tool as a pickup at pos (keeps Hot / Origin attrs)
function Interact.spawnPickup(tool, pos)
	local itemId = tool:GetAttribute("ItemId")
	tool.Parent = Core.holdFolder()
	local ground = Core.M.Evidence and Core.M.Evidence.groundAt(pos) or pos
	local model, h = makeDisplay(itemId, CFrame.new(ground) * CFrame.Angles(0, Core.rng:NextNumber(0, 6.28), 0))
	model.Parent = pickupFolder()
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "PickUp"
	pr.ActionText = "Pick up"
	pr.ObjectText = Core.itemName(itemId)
	pr.HoldDuration = tool:GetAttribute("Hot") and 0.5 or 0.2
	pr.MaxActivationDistance = 9
	pr.RequiresLineOfSight = false
	pr.Parent = h
	Interact.pickups[h] = tool
	pr.Triggered:Connect(function(player)
		local p = Core.byPlayer[player]
		if p then
			Interact.pickUp(p, h)
		end
	end)
	return h
end

function Interact.pickUp(p, h)
	local tool = Interact.pickups[h]
	if not tool or not Core.inPlay() and not Core.allowOutOfRound then
		return false
	end
	if not inRange(p, h) or Core.isDetained(p) then
		return false
	end
	if Core.itemCount(p) >= Config.MaxCarry then
		return fail(p, "Your hands are full (drop something first).")
	end
	Interact.pickups[h] = nil
	local model = h.Parent
	if model and model ~= pickupFolder() then
		model:Destroy()
	else
		h:Destroy()
	end
	Core.giveTool(p, tool)
	Core.sfx(p, "Click")
	Bus.fire("ItemObtained", p, tool:GetAttribute("ItemId"), "pickup", tool)
	return true
end

function Interact.spawnLoot()
	local spots = Core.shuffle(Core.markers("ItemSpawn"))
	local n = math.min(#spots, 14)
	local pool = {}
	for _, e in ipairs(Config.SearchLoot) do
		if e.id:sub(1, 1) ~= "_" then
			table.insert(pool, e)
		end
	end
	for i = 1, n do
		local total = 0
		for _, e in ipairs(pool) do
			total += e.w
		end
		local r = Core.rng:NextNumber() * total
		local id = pool[1].id
		for _, e in ipairs(pool) do
			r -= e.w
			if r <= 0 then
				id = e.id
				break
			end
		end
		local tool = Core.makeTool(id)
		Interact.spawnPickup(tool, spots[i].Position)
	end
end

---------------------------------------------------------------- pedestals
local function refreshPedestal(part)
	local st = Interact.pedestals[part]
	if not st then
		return
	end
	if st.display then
		st.display:Destroy()
		st.display = nil
	end
	if st.present then
		local top = part.CFrame * CFrame.new(0, part.Size.Y / 2, 0)
		local model = makeDisplay(st.itemId, CFrame.new(top.Position) * (part.CFrame - part.CFrame.Position))
		model.Parent = part
		st.display = model
	end
	local pr = part:FindFirstChild("Use")
	if pr then
		pr.ActionText = st.present and ("Steal " .. Core.itemName(st.itemId)) or ("Return " .. Core.itemName(st.itemId))
		pr.HoldDuration = st.present and 1.0 or 0.4
	end
end

function Interact.pedestalHas(itemId)
	for _, st in pairs(Interact.pedestals) do
		if st.itemId == itemId then
			return st.present
		end
	end
	return false
end
function Interact.pedestalFor(itemId)
	for part, st in pairs(Interact.pedestals) do
		if st.itemId == itemId then
			return part, st
		end
	end
	return nil
end

local function usePedestal(p, part)
	local st = Interact.pedestals[part]
	if not st then
		return false
	end
	if st.present then
		if not Core.inPlay() then
			return fail(p, "Not now — wait for the round to start.")
		end
		if Core.itemCount(p) >= Config.MaxCarry then
			return fail(p, "Your hands are full.")
		end
		st.present = false
		refreshPedestal(part)
		local tool = Core.giveItem(p, st.itemId, { hot = true, origin = "Pedestal:" .. attr(part, "Id", "") })
		Core.sfxAll("Whoosh", part.Position)
		local zone = zoneOf(part)
		local Evidence = Core.M.Evidence
		if Evidence then
			local inc = Evidence.createIncident("Theft", ("The %s has disappeared!"):format(Core.itemName(st.itemId)), zone, p, part.Position, st.itemId)
			Evidence.crimeScene(p, part.Position, inc)
		end
		Core.toast(p, ("You stole the %s! Don't get caught carrying it..."):format(Core.itemName(st.itemId)), "good", "Whoosh")
		if not p.isBot and Core.M.Progress then
			Core.M.Progress.addStat(p.player, "itemsStolen", 1)
		end
		Bus.fire("Stolen", p, st.itemId, "pedestal", part, tool)
		Bus.fire("ItemObtained", p, st.itemId, "steal", tool)
		interacted(p, "Pedestal", part)
		return true
	end
	local tool = Core.findItem(p, st.itemId)
	if not tool then
		return fail(p, ("The %s is gone!"):format(Core.itemName(st.itemId)), "Bruh")
	end
	tool:Destroy()
	if p.isBot then
		Core.botRefreshHold(p)
	end
	st.present = true
	refreshPedestal(part)
	Core.toast(p, ("You returned the %s to its place."):format(Core.itemName(st.itemId)), "good", "Complete")
	Core.toastAll(("✨ The %s is back on its pedestal!"):format(Core.itemName(st.itemId)), "event")
	Bus.fire("Returned", p, st.itemId)
	interacted(p, "Pedestal", part)
	return true
end

-- hot item back where it came from (detention / round end)
function Interact.returnToOrigin(tool)
	if not tool then
		return
	end
	local origin = tool:GetAttribute("Origin") or ""
	local itemId = tool:GetAttribute("ItemId")
	local owner = Core.toolOwner(tool)
	if origin:sub(1, 9) == "Pedestal:" then
		local part = Interact.parts[origin:sub(10)]
		tool:Destroy()
		if part and Interact.pedestals[part] then
			Interact.pedestals[part].present = true
			refreshPedestal(part)
			Core.toastAll(("👮 Security recovered the %s."):format(Core.itemName(itemId)), "security")
		end
	elseif origin:sub(1, 2) == "P:" then
		local victim = Core.get(tonumber(origin:sub(3)))
		if victim and victim ~= owner then
			tool:SetAttribute("Hot", nil)
			tool:SetAttribute("Origin", nil)
			Core.giveTool(victim, tool)
			Core.toast(victim, ("👮 Security returned your %s."):format(Core.itemName(itemId)), "security")
		else
			tool:SetAttribute("Hot", nil)
			tool:Destroy()
		end
	elseif origin == "VIP" then
		tool:Destroy()
		local Events = Core.M.Events
		if Events and Events.vipReturnBriefcase then
			Events.vipReturnBriefcase()
		end
	else
		tool:Destroy()
	end
	if owner and owner.isBot then
		Core.botRefreshHold(owner)
	end
end

---------------------------------------------------------------- search / hide / dig
local function rollLoot()
	local total = 0
	for _, e in ipairs(Config.SearchLoot) do
		total += e.w
	end
	local r = Core.rng:NextNumber() * total
	for _, e in ipairs(Config.SearchLoot) do
		r -= e.w
		if r <= 0 then
			return e.id
		end
	end
	return "_nothing"
end

local function useSearch(p, part, opts)
	if not Core.inPlay() and not Core.allowOutOfRound then
		return fail(p, "Wait for the round to start.")
	end
	local s = Interact.searched[part]
	if not s then
		s = {}
		Interact.searched[part] = s
	end
	local last = s[p.id]
	-- stashed items are always found
	local stash = Interact.stash[part]
	if stash and #stash > 0 then
		if Core.itemCount(p) >= Config.MaxCarry then
			return fail(p, "Your hands are full.")
		end
		local tool = table.remove(stash, 1)
		Core.giveTool(p, tool)
		Core.toast(p, ("🔍 You found a hidden %s!"):format(Core.itemName(tool:GetAttribute("ItemId"))), "evidence", "Evidence")
		Bus.fire("ItemObtained", p, tool:GetAttribute("ItemId"), "search", tool)
		Bus.fire("StashFound", p, tool:GetAttribute("ItemId"), part)
		interacted(p, "Search", part)
		if not p.isBot and Core.M.Progress then
			Core.M.Progress.addStat(p.player, "searches", 1)
		end
		return true
	end
	if last and os.clock() - last < Config.SearchRefill then
		Core.toast(p, "You already searched this.", "info")
		return false
	end
	s[p.id] = os.clock()
	local loot
	local fixed = attr(part, "Loot", nil)
	if opts and opts.forceLoot then
		loot = opts.forceLoot
	elseif fixed and Items[fixed] and not Interact.fixedTaken[part] then
		loot = fixed
	else
		loot = rollLoot()
	end
	interacted(p, "Search", part)
	if not p.isBot and Core.M.Progress then
		Core.M.Progress.addStat(p.player, "searches", 1)
	end
	if loot == "_nothing" then
		Core.toast(p, "🔍 Nothing useful here.", "info", "Click")
		return true
	elseif loot == "_coins" then
		Core.addCoins(p, Core.rng:NextInteger(4, 12), "found")
		return true
	end
	if Core.itemCount(p) >= Config.MaxCarry then
		s[p.id] = nil
		return fail(p, "Your hands are full.") -- fixed loot stays in the container for the next search
	end
	if loot == fixed and not (opts and opts.forceLoot) then
		Interact.fixedTaken[part] = true
	end
	local tool = Core.giveItem(p, loot)
	Core.toast(p, ("🔍 Found: %s %s"):format(Items[loot].icon, Items[loot].name), "good", "Progress")
	Bus.fire("ItemObtained", p, loot, "search", tool)
	return true
end

-- choose which of p's items to stash: equipped > hot > valuable > first
local function stashCandidate(p, itemId)
	if itemId then
		return Core.findItem(p, itemId)
	end
	local eq = Core.equipped(p)
	if eq and eq:GetAttribute("ItemId") then
		return eq
	end
	local hot = Core.hotItems(p)
	if #hot > 0 then
		return hot[1]
	end
	local items = Core.items(p)
	return items[1]
end

local function stashItem(p, part, itemId, verb)
	local tool = stashCandidate(p, itemId)
	if not tool then
		return fail(p, "You aren't carrying anything to hide.")
	end
	local id = tool:GetAttribute("ItemId")
	Core.takeTool(tool)
	Interact.stash[part] = Interact.stash[part] or {}
	table.insert(Interact.stash[part], tool)
	local zone = zoneOf(part)
	Core.toast(p, ("🤫 %s the %s (%s)."):format(verb or "Hid", Core.itemName(id), Core.zoneName(zone)), "good", "Progress")
	Bus.fire("ItemHidden", p, id, zone, part, tool)
	return true
end
Interact.stashItem = stashItem

local function setCharHidden(p, hidden)
	local char = Core.char(p)
	if not char then
		return
	end
	if hidden then
		p.hideSaved = {}
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") or d:IsA("Decal") then
				p.hideSaved[d] = d.Transparency
				d.Transparency = 1
			elseif d:IsA("BillboardGui") then
				p.hideSaved[d] = d.Enabled
				d.Enabled = false
			end
		end
	else
		for d, v in pairs(p.hideSaved or {}) do
			if d.Parent then
				if d:IsA("BillboardGui") then
					d.Enabled = v
				else
					d.Transparency = v
				end
			end
		end
		p.hideSaved = nil
	end
	local hum = Core.hum(p)
	if hum then
		if hidden then
			p.hideDDT = hum.DisplayDistanceType
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		elseif p.hideDDT then
			hum.DisplayDistanceType = p.hideDDT
			p.hideDDT = nil
		end
	end
end

function Interact.hide(p, part)
	if p.hidden then
		return Interact.unhide(p)
	end
	local occ = Interact.occupant[part]
	if occ and occ ~= p and occ.hidden then
		return fail(p, "Someone is already hiding in there!", "Bruh")
	end
	local root = Core.root(p)
	if not root then
		return false
	end
	p.hideFrom = root.CFrame
	Interact.occupant[part] = p
	p.hidden = true
	p.hideSpot = part
	p.hideUntil = os.clock() + 90
	setCharHidden(p, true)
	root.Anchored = true
	local char = Core.char(p)
	char:PivotTo(CFrame.new(part.Position) * (root.CFrame - root.CFrame.Position))
	local pr = part:FindFirstChild("Hide")
	if pr then
		pr.ActionText = "Leave"
	end
	Core.toast(p, "🫥 You're hiding. Use the prompt again to come out.", "info", "Whoosh")
	Bus.fire("Hidden", p, part)
	return true
end

function Interact.unhide(p)
	if not p.hidden then
		return false
	end
	local part = p.hideSpot
	p.hidden = false
	p.hideSpot = nil
	if part then
		Interact.occupant[part] = nil
		local pr = part:FindFirstChild("Hide")
		if pr then
			pr.ActionText = "Hide"
		end
	end
	local root = Core.root(p)
	if root then
		root.Anchored = false
		if p.hideFrom then
			Core.char(p):PivotTo(p.hideFrom)
		end
	end
	setCharHidden(p, false)
	Bus.fire("Unhidden", p)
	return true
end

local function useDig(p, part, opts)
	if not Core.inPlay() and not Core.allowOutOfRound then
		return fail(p, "Wait for the round to start.")
	end
	if not cool("dig:" .. p.id, 1.5) then
		return false
	end
	local zone = zoneOf(part)
	if opts.action == "Bury" then
		local ok = stashItem(p, part, opts.itemId, "Buried")
		if ok then
			Bus.fire("Dig", p, part, false)
			interacted(p, "Dig", part)
		end
		return ok
	end
	Bus.fire("Dig", p, part, true)
	interacted(p, "Dig", part)
	local stash = Interact.stash[part]
	if stash and #stash > 0 then
		local tool = table.remove(stash, 1)
		Core.giveTool(p, tool)
		Core.toast(p, ("⛏️ You dug up a %s!"):format(Core.itemName(tool:GetAttribute("ItemId"))), "good", "Progress")
		Bus.fire("ItemObtained", p, tool:GetAttribute("ItemId"), "dig", tool)
		Bus.fire("StashFound", p, tool:GetAttribute("ItemId"), part)
		return true
	end
	if part == Interact.treasureSpot and not Interact.treasureFound then
		Interact.treasureFound = true
		Core.addCoins(p, 40, "buried treasure!")
		local tool = Core.giveItem(p, "CasinoChip")
		Bus.fire("ItemObtained", p, "CasinoChip", "dig", tool)
		Core.sfx(p, "Jackpot")
		return true
	end
	Core.toast(p, "⛏️ Just sand" .. (zone == "Beach" and " and a seashell." or "."), "info")
	return true
end

---------------------------------------------------------------- arcade / food / shops
-- The old casino is now the ARCADE (gambling-free for the all-ages rating): playing is FREE and the prize depends on
-- SKILL, not luck. A needle sweeps a bar; stop it in the green zone. Server-authoritative timing: the server
-- remembers when the run started and works out where the needle was when the stop arrived (minus network delay).
local arcadeRuns = {} -- p.id -> run
local arcadeEarned = {} -- p.id -> { round = n, coins = n }
local ARCADE = {
	Slot = { title = "🕹️ ARCADE MACHINE", period = 1.15, width = 0.18, hit = 6, perfect = 15 },
	Cards = { title = "🎯 GAME TABLE", period = 0.85, width = 0.13, hit = 10, perfect = 25 },
}
Interact.ARCADE = ARCADE

local function arcadePos(e, period)
	local ph = (e / period) % 2
	return ph < 1 and ph or 2 - ph
end
Interact.arcadePos = arcadePos

local function arcadeAward(p, run, hit, perfect)
	local def = ARCADE[run.kind]
	local payout = perfect and def.perfect or (hit and def.hit or 0)
	local Events = Core.M.Events
	if payout > 0 and Events and Events.isActive("CasinoJackpot") then
		payout *= 2
	end
	-- per-round cap so the arcade can't be farmed
	local rec = arcadeEarned[p.id]
	if not rec or rec.round ~= Core.round then
		rec = { round = Core.round, coins = 0 }
		arcadeEarned[p.id] = rec
	end
	local room = math.max(0, Config.ArcadeRoundCap - rec.coins)
	local capped = payout > room
	payout = math.min(payout, room)
	rec.coins += payout
	if payout > 0 then
		Core.addCoins(p, payout, perfect and "PERFECT!" or "arcade")
		Core.sfx(p, perfect and "Jackpot" or "CoinGet")
		Bus.fire("CasinoWin", p, payout, run.kind)
		if payout >= 20 then
			roundLog(("Arcade: %s won %d coins"):format(p.name, payout), "Transaction")
		end
	elseif capped and hit then
		Core.toast(p, "🕹️ Arcade prize limit reached this round!", "info")
	end
	Core.send(p, "Arcade", { result = true, hit = hit, perfect = perfect, payout = payout })
	return payout
end

local function startArcade(p, part, kind)
	if not Core.inPlay() then
		return fail(p, "The arcade opens when the round starts.")
	end
	if not cool("arcade:" .. p.id, 1.2) then
		return false
	end
	local def = ARCADE[kind]
	interacted(p, kind, part)
	if kind == "Cards" then
		Bus.fire("TalkNPC", p, "Dealer")
	end
	local run = { kind = kind, part = part }
	if p.isBot then
		-- bots have no screen: roll a skill-like result
		local r = Core.rng:NextNumber()
		arcadeAward(p, run, r < 0.5, r < 0.12)
		return true
	end
	run.t0 = os.clock()
	run.period = def.period * Core.rng:NextNumber(0.9, 1.1)
	run.center = Core.rng:NextNumber(0.2, 0.8)
	run.width = def.width
	run.expires = run.t0 + 8
	arcadeRuns[p.id] = run
	Core.send(p, "Arcade", { start = true, kind = kind, title = def.title, period = run.period, center = run.center,
		width = run.width, hit = def.hit, perfect = def.perfect })
	return true
end

local function useSlot(p, part)
	return startArcade(p, part, "Slot")
end

local function useCards(p, part)
	return startArcade(p, part, "Cards")
end

function Interact.arcadeStop(player, p)
	local run = p and arcadeRuns[p.id]
	if not run or os.clock() > run.expires then
		return
	end
	arcadeRuns[p.id] = nil
	-- the needle the player saw started one network trip after t0 and the stop took one more trip to arrive
	local ok, ping = pcall(function()
		return player:GetNetworkPing()
	end)
	local oneWay = math.clamp(ok and ping or 0.05, 0, 0.25)
	local e = os.clock() - run.t0 - 2 * oneWay
	local pos = arcadePos(math.max(0, e), run.period)
	local dist = math.abs(pos - run.center)
	local hit = dist <= run.width / 2 + 0.03
	local perfect = dist <= run.width / 6 + 0.015
	arcadeAward(p, run, hit, perfect)
	if not hit then
		Core.toast(p, "🕹️ So close! Try again.", "info")
	end
end

local function usePrize(p, part)
	if not Core.inPlay() then
		return fail(p, "Closed between rounds.")
	end
	local chip = Core.findItem(p, "CasinoChip")
	if chip then
		chip:Destroy()
		Core.addCoins(p, 60, "token cashed in")
		roundLog(("Prize counter: token cashed in by %s"):format(p.name), "Transaction")
	else
		if Core.itemCount(p) >= Config.MaxCarry then
			return fail(p, "Your hands are full.")
		end
		if not Core.addCoins(p, -40, "Photo Camera") then
			return fail(p, "A Photo Camera costs 40 coins.")
		end
		local tool = Core.giveItem(p, "PhotoCamera")
		Bus.fire("ItemObtained", p, "PhotoCamera", "buy", tool)
	end
	interacted(p, "Prize", part)
	return true
end

local function useCashier(p, part)
	if not Core.inPlay() then
		return fail(p, "Closed between rounds.")
	end
	local chip = Core.findItem(p, "CasinoChip")
	if chip then
		chip:Destroy()
		Core.addCoins(p, 45, "token traded")
		roundLog(("Prize desk: %s traded in a gold token"):format(p.name), "Transaction")
	else
		if Core.itemCount(p) >= Config.MaxCarry then
			return fail(p, "Your hands are full.")
		end
		if not Core.addCoins(p, -70, "Gold Token") then
			return fail(p, "A Gold Token costs 70 coins.")
		end
		local tool = Core.giveItem(p, "CasinoChip")
		Bus.fire("ItemObtained", p, "CasinoChip", "buy", tool)
		roundLog(("Prize desk: %s bought a gold token"):format(p.name), "Transaction")
	end
	interacted(p, "Cashier", part)
	return true
end

local function useFood(p, part)
	if not Core.inPlay() then
		return fail(p, "Kitchen's closed between rounds.")
	end
	if not cool("food:" .. p.id, 2) then
		return false
	end
	local zone = zoneOf(part)
	local item = (zone == "Restaurant" or zone == "Kitchen" or zone == "PrivateDining") and "Pizza" or "Champagne"
	if attr(part, "Item", nil) and Items[attr(part, "Item", "")] then
		item = attr(part, "Item", item)
	end
	if Core.itemCount(p) >= Config.MaxCarry then
		return fail(p, "Your hands are full.")
	end
	if not Core.addCoins(p, -Config.FoodCost) then
		return fail(p, "Not enough coins.")
	end
	local tool = Core.giveItem(p, item)
	Core.toast(p, ("%s Here's your %s!"):format(Items[item].icon, Items[item].name), "good", "CoinGet")
	Bus.fire("ItemObtained", p, item, "buy", tool)
	interacted(p, "Food", part)
	return true
end

local function useShop(p, part)
	if not Core.inPlay() then
		return fail(p, "Shops open when the round starts.")
	end
	if not cool("shop:" .. p.id, 1.5) then
		return false
	end
	local stock = SHOP_STOCK[attr(part, "ShopId", "General")] or SHOP_STOCK.General
	local pickE
	for _, e in ipairs(stock) do
		if not Core.hasItem(p, e.id) then
			pickE = e
			break
		end
	end
	if not pickE then
		return fail(p, "You already have everything this shop sells.", "Bruh")
	end
	if Core.itemCount(p) >= Config.MaxCarry then
		return fail(p, "Your hands are full.")
	end
	if not Core.addCoins(p, -pickE.price, Items[pickE.id].name) then
		return fail(p, ("%s costs %d coins."):format(Items[pickE.id].name, pickE.price))
	end
	local tool = Core.giveItem(p, pickE.id)
	roundLog(("%s shop: %s sold to %s"):format(attr(part, "ShopId", "General"), Items[pickE.id].name, p.name), "Transaction")
	Bus.fire("ItemObtained", p, pickE.id, "buy", tool)
	Bus.fire("Buy", p, attr(part, "ShopId", "General"), pickE.id)
	interacted(p, "Shop", part)
	return true
end

---------------------------------------------------------------- misc kinds
local function useComputer(p, part)
	local role = attr(part, "Role", "Security")
	if Core.M.Security then
		Core.M.Security.openMonitor(p, part, role)
	end
	interacted(p, "Computer", part)
	return true
end

local function usePowerBox(p, part)
	if not Core.inPlay() then
		return fail(p, "Not now.")
	end
	local Events = Core.M.Events
	if not Events then
		return false
	end
	if Events.isActive("PowerOutage") then
		return fail(p, "The power is already out.")
	end
	if not cool("powerbox", 45) then
		return fail(p, "The breaker is still resetting...")
	end
	Events.start("PowerOutage", { by = p })
	local Evidence = Core.M.Evidence
	if Evidence then
		local inc = Evidence.createIncident("Sabotage", "Someone cut the power!", zoneOf(part), p, part.Position)
		Evidence.crimeScene(p, part.Position, inc)
	end
	Bus.fire("Trigger", p, "PowerOutage")
	interacted(p, "PowerBox", part)
	return true
end

local function useAlarm(p, part)
	if not Core.inPlay() then
		return fail(p, "Not now.")
	end
	local Events = Core.M.Events
	if not Events or Events.isActive("SecurityLockdown") then
		return fail(p, "The lockdown is already on.")
	end
	if not cool("alarm", 120) then
		return fail(p, "The alarm was pulled recently.")
	end
	Events.start("SecurityLockdown", { by = p })
	roundLog(("Alarm pulled in the %s"):format(Core.zoneName(zoneOf(part))), "Access")
	Bus.fire("Trigger", p, "SecurityLockdown")
	interacted(p, "Alarm", part)
	return true
end

local function usePhone(p, part)
	if not Core.inPlay() then
		return fail(p, "No one's answering.")
	end
	if not cool("phone:" .. tostring(part), 45) then
		return fail(p, "The line is busy.")
	end
	local phones = {}
	for _, ph in ipairs(Core.interactParts("Phone")) do
		if ph ~= part then
			table.insert(phones, ph)
		end
	end
	local target = Core.pick(phones) or part
	if Core.M.Security then
		Core.M.Security.prank(target.Position, zoneOf(target))
	end
	Core.toast(p, ("📞 Prank call! Security is rushing to the %s."):format(Core.zoneName(zoneOf(target))), "good", "Click")
	Bus.fire("Trigger", p, "Prank")
	interacted(p, "Phone", part)
	return true
end

local function useBoat(p, part)
	if not Core.inPlay() then
		return fail(p, "No boat right now.")
	end
	local Events = Core.M.Events
	if not (Events and Events.isActive("BoatArrival")) then
		return fail(p, "🚤 No boat is waiting right now. Watch for the BOAT ARRIVAL event.")
	end
	return Interact.escape(p)
end

function Interact.escape(p)
	local ids = {}
	local smuggled = {}
	for _, t in ipairs(Core.items(p)) do
		local id = t:GetAttribute("ItemId")
		table.insert(ids, id)
		if t:GetAttribute("Hot") then
			table.insert(smuggled, id)
			t:Destroy()
		end
	end
	if p.isBot then
		Core.botRefreshHold(p)
	end
	table.insert(Interact.escaped, { pid = p.id, items = ids })
	Bus.fire("Escape", p, ids)
	Core.sfxAll("Whoosh", Core.pos(p))
	if #smuggled > 0 then
		local names = {}
		for _, id in ipairs(smuggled) do
			table.insert(names, Core.itemName(id))
		end
		Core.toastAll(("🚤 Someone escaped by boat with the %s!"):format(table.concat(names, ", ")), "event", "Whoosh")
	end
	Core.toast(p, "🚤 You sailed away... and came back ashore unseen.", "good")
	-- the boat ride: drop them on the beach
	local dest = Core.zonePoint("Beach") or Core.zonePoint("Plaza")
	task.delay(1.5, function()
		if dest then
			Core.teleport(p, dest)
		end
	end)
	return true
end

local function useSwitch(p, part)
	local doorId = attr(part, "Opens", nil)
	local door = doorId and Interact.parts[doorId]
	if not door then
		return fail(p, "Click. Nothing happened.")
	end
	Interact.openDoor(door, 15, p)
	Core.toast(p, "*click* ...you hear stone sliding somewhere nearby.", "info", "DoorOpen")
	interacted(p, "Switch", part)
	return true
end

local function useElevator(p, part)
	local to = Interact.parts[attr(part, "To", "")]
	if not to then
		return fail(p, "The elevator is out of order.")
	end
	if not cool("elev:" .. p.id, 2) then
		return false
	end
	local dest
	if to.Size.Y <= 2 then
		dest = to.Position + Vector3.new(0, to.Size.Y / 2 + 0.5, 0)
	else
		dest = (to.CFrame * CFrame.new(0, -to.Size.Y / 2 + 0.5, -(to.Size.Z / 2 + 3))).Position
	end
	Core.sfx(p, "Whoosh")
	Core.teleport(p, dest)
	interacted(p, "Elevator", part)
	return true
end

local function useNote(p, part)
	local text = tostring(attr(part, "Text", "..."))
	Core.toast(p, "📝 " .. text, "info", "Click")
	p.knowsCodes = true
	interacted(p, "Note", part)
	return true
end

local function useBoard(p, part)
	local Evidence = Core.M.Evidence
	if Evidence then
		Evidence.sendIncidents(p)
		local n, open = 0, 0
		for _, inc in ipairs(Evidence.incidents) do
			n += 1
			if not inc.solved then
				open += 1
			end
		end
		if n == 0 then
			Core.toast(p, "📋 Notice board: All quiet at the resort... for now.", "info")
		else
			local last = Evidence.incidents[#Evidence.incidents]
			Core.toast(p, ("📋 %d incident%s (%d unsolved). Latest: %s"):format(n, n == 1 and "" or "s", open, last.title), "info")
		end
	end
	interacted(p, "Board", part)
	return true
end

---------------------------------------------------------------- dispatcher
local HANDLERS = {
	Door = function(p, part)
		return useDoor(p, part)
	end,
	Search = useSearch,
	Hide = function(p, part, opts)
		if opts.action == "Stash" then
			if not Core.inPlay() and not Core.allowOutOfRound then
				return fail(p, "Wait for the round to start.")
			end
			local ok = stashItem(p, part, opts.itemId)
			if ok then
				interacted(p, "Hide", part)
			end
			return ok
		elseif opts.action == "Search" then
			return useSearch(p, part, opts)
		end
		return Interact.hide(p, part)
	end,
	Dig = useDig,
	Computer = useComputer,
	PowerBox = usePowerBox,
	Alarm = useAlarm,
	Phone = usePhone,
	Slot = useSlot,
	Cards = useCards,
	Prize = usePrize,
	Cashier = useCashier,
	Food = useFood,
	Shop = useShop,
	Boat = useBoat,
	Switch = useSwitch,
	Elevator = useElevator,
	Pedestal = usePedestal,
	Note = useNote,
	Board = useBoard,
}

-- the single entry point: returns ok, msg
function Interact.use(p, part, opts)
	opts = opts or {}
	if not p or not part or not part.Parent then
		return false
	end
	local kind = attr(part, "Kind", "")
	local h = HANDLERS[kind]
	if not h then
		return false
	end
	if not inRange(p, part) then
		return false, "far"
	end
	if Core.isDetained(p) and kind ~= "Door" then
		return fail(p, "You're detained!")
	end
	if p.hidden and not (kind == "Hide" and opts.action ~= "Stash" and opts.action ~= "Search") then
		return false
	end
	return h(p, part, opts)
end

---------------------------------------------------------------- per-part setup
local KIND_PROMPT = {
	Search = { "Use", "Search", 0.8 },
	Computer = { "Use", "Use computer", 0.3 },
	PowerBox = { "Use", "Pull breaker", 1.5 },
	Alarm = { "Use", "Pull alarm", 0.8 },
	Phone = { "Use", "Prank call", 0.5 },
	Slot = { "Use", "Play arcade (free)", 0.3 },
	Cards = { "Use", "Play table game (free)", 0.3 },
	Prize = { "Use", "Prize counter", 0.3 },
	Cashier = { "Use", "Trade tokens", 0.3 },
	Food = { "Use", ("Order (%d 🪙)"):format(Config.FoodCost), 0.3 },
	Shop = { "Use", "Buy", 0.3 },
	Boat = { "Use", "Escape by boat", 1.0 },
	Switch = { "Use", "Pull switch", 0.5 },
	Elevator = { "Use", "Ride elevator", 0.3 },
	Note = { "Use", "Read", 0 },
	Board = { "Use", "Read board", 0 },
}

function Interact.setupPart(part)
	if not part:IsA("BasePart") or part:GetAttribute("_EHAS") then
		return
	end
	part:SetAttribute("_EHAS", true)
	local kind = attr(part, "Kind", "")
	local id = attr(part, "Id", nil)
	if not id then
		id = kind .. "_" .. tostring(#CollectionService:GetTagged("Interact")) .. "_" .. math.floor(part.Position.X)
		part:SetAttribute("Id", id)
	end
	Interact.parts[id] = part
	if kind == "Door" then
		Interact.doors[part] = { closedCF = part.CFrame, open = false, closeAt = 0 }
		local lock = doorLock(part)
		local pr = addPrompt(part, "Use", "Open", 0)
		if lock ~= "none" then
			pr.ObjectText = "🔒 " .. label(part)
		end
		if lock == "secret" then
			pr.Enabled = false
		end
	elseif kind == "Hide" then
		addPrompt(part, "Hide", "Hide", 0.3)
		addPrompt(part, "Stash", "Hide carried item", 0.6, Enum.KeyCode.F, 1)
		addPrompt(part, "Search", "Search", 0.8, Enum.KeyCode.R, 2)
	elseif kind == "Dig" then
		addPrompt(part, "Dig", "Dig", 1.0)
		addPrompt(part, "Bury", "Bury carried item", 1.0, Enum.KeyCode.F, 1)
	elseif kind == "Pedestal" then
		local itemId = attr(part, "ItemId", "GoldenStatue")
		Interact.pedestals[part] = { itemId = itemId, present = true }
		addPrompt(part, "Use", "Steal", 1.0)
		refreshPedestal(part)
	elseif kind == "Shop" then
		local stock = SHOP_STOCK[attr(part, "ShopId", "General")] or SHOP_STOCK.General
		local names = {}
		for _, e in ipairs(stock) do
			table.insert(names, ("%s %d🪙"):format(Items[e.id].name, e.price))
		end
		addPrompt(part, "Use", "Buy: " .. table.concat(names, " / "), 0.3)
	elseif KIND_PROMPT[kind] then
		local d = KIND_PROMPT[kind]
		addPrompt(part, d[1], d[2], d[3])
	end
	-- Camera parts: no prompt (handled by Security)
end

---------------------------------------------------------------- swipe from other guests
function Interact.attachSwipe(p)
	local root = Core.root(p)
	if not root or root:FindFirstChild("Swipe") then
		return
	end
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "Swipe"
	pr.ActionText = "Swipe item"
	pr.ObjectText = p.name
	pr.HoldDuration = 1.2
	pr.MaxActivationDistance = 7
	pr.RequiresLineOfSight = false
	pr.KeyboardKeyCode = Enum.KeyCode.G
	pr.Enabled = false
	pr.Parent = root
	pr.Triggered:Connect(function(player)
		local thief = Core.byPlayer[player]
		if thief and thief ~= p then
			Interact.swipe(thief, p)
		end
	end)
end

function Interact.swipe(thief, victim)
	if not Core.inPlay() or thief == victim or not victim.inRound or victim.hidden then
		return false
	end
	if Core.isDetained(thief) then
		return false
	end
	if Core.dist(thief, victim) > 9 then
		return false
	end
	if not cool("swipe:" .. thief.id, 10) then
		return fail(thief, "Wait a bit before swiping again.")
	end
	if Core.itemCount(thief) >= Config.MaxCarry then
		return fail(thief, "Your hands are full.")
	end
	local items = Core.items(victim)
	if #items == 0 then
		return fail(thief, "They have nothing to swipe.", "Bruh")
	end
	local tool = Core.equipped(victim) or Core.pick(items)
	local id = tool:GetAttribute("ItemId")
	Core.takeTool(tool)
	if victim.isBot then
		Core.botRefreshHold(victim)
	end
	tool:SetAttribute("Hot", true)
	if not tool:GetAttribute("Origin") then
		tool:SetAttribute("Origin", "P:" .. victim.id)
	end
	Core.giveTool(thief, tool)
	Core.toast(thief, ("🫳 You swiped %s's %s!"):format(victim.name, Core.itemName(id)), "good", "Whoosh")
	Core.toast(victim, ("👜 Hey! Your %s was swiped!"):format(Core.itemName(id)), "bad", "Bruh")
	local Evidence = Core.M.Evidence
	if Evidence and (Items[id] and Items[id].valuable or tool:GetAttribute("Origin"):sub(1, 9) == "Pedestal:" or tool:GetAttribute("Origin") == "VIP") then
		local inc = Evidence.createIncident("Swipe", ("%s's %s was swiped"):format(victim.name, Core.itemName(id)), victim.zone or "Lobby", thief, Core.pos(victim), id)
		inc.victim = victim.id
		Evidence.crimeScene(thief, Core.pos(victim), inc)
	end
	if not thief.isBot and Core.M.Progress then
		Core.M.Progress.addStat(thief.player, "itemsStolen", 1)
	end
	Bus.fire("Stolen", thief, id, "player", victim, tool)
	Bus.fire("ItemObtained", thief, id, "steal", tool)
	return true
end

---------------------------------------------------------------- drop / photo / tools
function Interact.dropItem(p, targetId)
	if Core.isDetained(p) or p.hidden then
		return false
	end
	local tool = Core.equipped(p) or Core.items(p)[1]
	if not tool then
		return fail(p, "You aren't holding anything.")
	end
	local itemId = tool:GetAttribute("ItemId")
	local root = Core.root(p)
	if not root then
		return false
	end
	local pos = (root.CFrame * CFrame.new(0, 0, -3)).Position
	Core.takeTool(tool)
	local Evidence = Core.M.Evidence
	if Core.inPlay() and Evidence and Evidence.tryFrame(p, itemId, pos, targetId) then
		tool:Destroy() -- became the planted clue
		return true
	end
	Interact.spawnPickup(tool, pos)
	Bus.fire("ItemDropped", p, itemId, pos)
	return true
end

function Interact.takePhoto(p)
	if not Core.hasItem(p, "PhotoCamera") then
		return fail(p, "You need a Photo Camera.")
	end
	if not cool("photo:" .. p.id, 2) then
		return false
	end
	local root = Core.root(p)
	if not root or p.hidden then
		return false
	end
	local look = root.CFrame.LookVector
	local best, bestDot
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Core.char(p) }
	for _, q in ipairs(Core.nearby(root.Position, 45, p.id)) do
		if not q.hidden then
			local qp = Core.pos(q)
			local dir = qp - root.Position
			local dot = look:Dot(dir.Unit)
			if dot >= 0.8 and (not bestDot or dot > bestDot) then
				local hit = workspace:Raycast(root.Position + Vector3.new(0, 1.5, 0), dir, params)
				if not hit or hit.Instance:IsDescendantOf(Core.char(q)) then
					best, bestDot = q, dot
				end
			end
		end
	end
	Core.sfxAll("Photo", root.Position)
	if not best then
		Core.send(p, "Photo", {})
		return true
	end
	local hot = Core.hotItems(best)
	local caughtId = hot[1] and hot[1]:GetAttribute("ItemId") or nil
	local zone = best.zone or Core.zoneAt(Core.pos(best)) or "Lobby"
	local Evidence = Core.M.Evidence
	if Evidence then
		local inc = caughtId and Evidence.latestIncidentFor(caughtId) or nil
		local text = caughtId and ("📸 Photo: %s carrying the %s in the %s!"):format(best.name, Core.itemName(caughtId), Core.zoneName(zone))
			or ("📸 Photo: %s in the %s."):format(best.name, Core.zoneName(zone))
		local ev = Evidence.add("Photo", text, zone, caughtId and { best.id } or {}, inc and inc.id or nil)
		Evidence.discover(p, ev, true)
	end
	Core.send(p, "Photo", { targetName = best.name, caught = caughtId and Core.itemName(caughtId) or nil })
	if not p.isBot and Core.M.Progress then
		Core.M.Progress.addStat(p.player, "photos", 1)
	end
	Bus.fire("Photo", p, best, caughtId, zone)
	return true
end

function Interact.disguise(p, tool)
	if Core.isDisguised(p) then
		return false
	end
	tool = tool or Core.findItem(p, "StaffUniform")
	if not tool then
		return false
	end
	tool:Destroy()
	p.disguiseUntil = os.clock() + Config.DisguiseTime
	local char = Core.char(p)
	local torso = char and char:FindFirstChild("UpperTorso")
	if torso then
		for i, x in ipairs({ -0.3, 0.3 }) do
			local v = Instance.new("Part")
			v.Name = "UniformVest" .. i
			v.Size = Vector3.new(torso.Size.X * 0.42, torso.Size.Y * 0.95, 0.1)
			v.Color = Color3.fromRGB(25, 25, 30)
			v.Material = Enum.Material.SmoothPlastic
			v.CanCollide = false
			v.CanQuery = false
			v.Massless = true
			local off = CFrame.new(torso.Size.X * x, 0, -torso.Size.Z * 0.5)
			v.CFrame = torso.CFrame * off
			local w = Instance.new("Weld")
			w.Part0, w.Part1, w.C0 = torso, v, off
			w.Parent = v
			v.Parent = char
		end
		char:SetAttribute("Disguised", true)
	end
	Core.toast(p, ("🦺 Disguised as staff for %d s — cameras and guards ignore you."):format(Config.DisguiseTime), "good", "Whoosh")
	if Core.M.Security then
		Core.M.Security.dropPursuit(p)
	end
	Bus.fire("Disguised", p)
	task.delay(Config.DisguiseTime, function()
		Interact.undisguise(p)
	end)
	return true
end
function Interact.undisguise(p)
	if p.disguiseUntil > os.clock() + 0.5 then
		return
	end
	p.disguiseUntil = 0
	local char = Core.char(p)
	if char then
		for _, n in ipairs({ "UniformVest1", "UniformVest2" }) do
			local v = char:FindFirstChild(n)
			if v then
				v:Destroy()
			end
		end
		char:SetAttribute("Disguised", nil)
	end
end

function Interact.hookTool(tool)
	tool.Activated:Connect(function()
		local p = Core.toolOwner(tool)
		if not p then
			return
		end
		local id = tool:GetAttribute("ItemId")
		if id == "PhotoCamera" then
			Interact.takePhoto(p)
		elseif id == "StaffUniform" then
			Interact.disguise(p, tool)
		elseif id == "Flashlight" then
			local h = tool:FindFirstChild("Handle")
			if h then
				local l = h:FindFirstChild("Beam")
				if not l then
					l = Instance.new("SpotLight")
					l.Name = "Beam"
					l.Range = 40
					l.Angle = 50
					l.Brightness = 3
					l.Face = Enum.NormalId.Front
					l.Parent = h
				else
					l.Enabled = not l.Enabled
				end
			end
		elseif id == "TreasureMap" then
			local spot = Interact.treasureSpot
			if spot and not Interact.treasureFound then
				Core.toast(p, ("🗺️ X marks the spot: %s"):format(label(spot)), "info", "Click")
			else
				Core.toast(p, "🗺️ Someone already dug up this treasure...", "info")
			end
		elseif id == "SecretLetter" then
			Core.toast(p, "✉️ The letter is sealed. Drop it at a crime scene to frame someone...", "info")
		elseif id == "Champagne" then
			Core.toast(p, "🧃 Cheers!", "social")
		elseif id == "Pizza" then
			Core.toast(p, "🍕 Smells amazing. Better deliver it before it gets cold.", "social")
		end
	end)
end

---------------------------------------------------------------- round lifecycle
function Interact.resetRound()
	for _, p in pairs(Core.participants) do
		if p.hidden then
			Interact.unhide(p)
		end
		p.disguiseUntil = 0
		Interact.undisguise(p)
	end
	for door in pairs(Interact.doors) do
		Interact.closeDoor(door)
	end
	for part, st in pairs(Interact.pedestals) do
		st.present = true
		refreshPedestal(part)
	end
	for part, list in pairs(Interact.stash) do
		for _, t in ipairs(list) do
			t:Destroy()
		end
		Interact.stash[part] = nil
	end
	for h, tool in pairs(Interact.pickups) do
		tool:Destroy()
		if h.Parent then
			local m = h.Parent
			if m:IsA("Model") then
				m:Destroy()
			else
				h:Destroy()
			end
		end
	end
	Interact.pickups = {}
	pickupFolder():ClearAllChildren()
	Interact.codeOk = {}
	Interact.codeFails = {}
	Interact.searched = {}
	Interact.fixedTaken = {}
	Interact.cooldown = {}
	Interact.escaped = {}
	Interact.treasureFound = false
	local digs = Core.interactParts("Dig")
	Interact.treasureSpot = Core.pick(digs)
end

-- zones that contain a Hide or Dig spot (for the secret generator)
function Interact.hideZones()
	local set, out = {}, {}
	for _, kind in ipairs({ "Hide", "Dig" }) do
		for _, part in ipairs(Core.interactParts(kind)) do
			local z = zoneOf(part)
			if not set[z] then
				set[z] = true
				table.insert(out, z)
			end
		end
	end
	return out
end

function Interact.init()
	for _, part in ipairs(CollectionService:GetTagged("Interact")) do
		pcall(Interact.setupPart, part)
	end
	CollectionService:GetInstanceAddedSignal("Interact"):Connect(function(part)
		pcall(Interact.setupPart, part)
	end)
	Interact.treasureSpot = Core.pick(Core.interactParts("Dig"))
	-- door auto-close + swipe prompt visibility + hide timeout
	task.spawn(function()
		while true do
			task.wait(0.5)
			pcall(function()
				local now = os.clock()
				for door, d in pairs(Interact.doors) do
					if d.open and now >= d.closeAt then
						Interact.closeDoor(door)
					end
				end
				for _, p in pairs(Core.participants) do
					local root = Core.root(p)
					local pr = root and root:FindFirstChild("Swipe")
					if pr then
						pr.Enabled = Core.inPlay() and p.inRound and not p.hidden and Core.itemCount(p) > 0
					end
					if p.hidden and p.hideUntil and now > p.hideUntil then
						Interact.unhide(p)
						Core.toast(p, "You had to come out of hiding.", "info")
					end
				end
			end)
		end
	end)
	-- actions
	Core.onAction("ArcadeStop", function(player, args, p)
		Interact.arcadeStop(player, p)
	end)
	Core.onAction("EnterCode", function(player, args, p)
		local doorId = Core.vStr(args.doorId, 64)
		local code = args.code
		if type(code) == "number" then
			code = tostring(code)
		end
		if not p or not doorId or type(code) ~= "string" or not code:match("^%d%d%d%d$") then
			return
		end
		Interact.enterCode(p, doorId, code)
	end)
	Core.onAction("DropItem", function(player, args, p)
		if not p then
			return
		end
		local targetId = Core.vInt(args.targetId, -9, 2 ^ 53)
		Interact.dropItem(p, targetId)
	end)
	Core.onAction("TakePhoto", function(player, args, p)
		if p and Core.inPlay() then
			Interact.takePhoto(p)
		end
	end)
	Bus.on("ParticipantRemoving", function(p)
		if p.hidden then
			Interact.unhide(p)
		end
		-- hot items held by a leaving participant go home; others vanish
		for _, t in ipairs(Core.items(p)) do
			if t:GetAttribute("Hot") then
				Interact.returnToOrigin(t)
			end
		end
		for part, occ in pairs(Interact.occupant) do
			if occ == p then
				Interact.occupant[part] = nil
			end
		end
	end)
end

return Interact
