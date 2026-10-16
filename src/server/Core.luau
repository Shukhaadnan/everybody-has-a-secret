-- Core.luau — shared server state + helpers used by every service:
-- remotes, participant registry (players + bots, bots have negative ids), zones, markers, interact
-- registry lookup, inventory (Tools), coins, speed, realistic NPC rigs (Motor6D fix), toasts.
-- Cross-service calls go through Core.M.<Service> (filled by Main) to avoid require cycles.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Items = require(ReplicatedStorage:WaitForChild("Items"))
local Bus = require(script.Parent.Bus)

local Core = {}
Core.M = {} -- services (Data, Progress, Shop, Interact, Security, Evidence, Events, Social, Accuse, Secrets, Bots, Round)
Core.participants = {} -- id -> P
Core.byPlayer = {} -- Player -> P
Core.phase = "Lobby"
Core.round = 0
Core.roundStartClock = 0
Core.roundEndsAt = 0
Core.rng = Random.new()

-- optional modules from other builders (pcall so a missing/broken file can't kill the server)
local function tryRequire(parent, name)
	local inst = parent:FindFirstChild(name)
	if not inst then
		inst = parent:WaitForChild(name, 3)
	end
	if not inst then
		return nil
	end
	local ok, m = pcall(require, inst)
	if ok then
		return m
	end
	warn("[Core] require " .. name .. " failed: " .. tostring(m))
	return nil
end
Core.Zones = tryRequire(ReplicatedStorage, "Zones")
Core.ItemArt = tryRequire(ReplicatedStorage, "ItemArt")

function Core.now()
	return workspace:GetServerTimeNow()
end
function Core.clock()
	return os.clock()
end
function Core.elapsed()
	return os.clock() - Core.roundStartClock
end
function Core.inPlay()
	return Core.phase == "Play"
end

---------------------------------------------------------------- remotes
Core.REMOTE_NAMES = {
	"RoundState", "YourSecret", "SecretProgress", "Toast", "EventBanner", "Incident", "Evidence", "Monitor", "ViewCam",
	"Keypad", "Request", "Allies", "Detained", "Reveal", "Rewards", "Profile", "Sfx", "Photo", "Action", "Arcade",
}
function Core.initRemotes()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	Core.Remotes = {}
	for _, n in ipairs(Core.REMOTE_NAMES) do
		local r = folder:FindFirstChild(n)
		if not r then
			r = Instance.new("RemoteEvent")
			r.Name = n
			r.Parent = folder
		end
		Core.Remotes[n] = r
	end
	Core.RemotesFolder = folder
end

local function playerOf(target)
	if typeof(target) == "Instance" and target:IsA("Player") then
		return target
	end
	if type(target) == "table" and target.player then
		return target.player
	end
	return nil
end
Core.playerOf = playerOf

function Core.send(target, name, payload)
	local pl = playerOf(target)
	if pl and pl.Parent and Core.Remotes and Core.Remotes[name] then
		Core.Remotes[name]:FireClient(pl, payload)
	end
end
function Core.broadcast(name, payload)
	if Core.Remotes and Core.Remotes[name] then
		Core.Remotes[name]:FireAllClients(payload)
	end
end
function Core.toast(target, text, kind, sfx)
	Core.send(target, "Toast", { text = text, kind = kind or "info", sfx = sfx })
end
function Core.toastAll(text, kind, sfx)
	Core.broadcast("Toast", { text = text, kind = kind or "info", sfx = sfx })
end
function Core.sfx(target, name, pos)
	Core.send(target, "Sfx", { name = name, pos = pos })
end
function Core.sfxAll(name, pos)
	Core.broadcast("Sfx", { name = name, pos = pos })
end

---------------------------------------------------------------- action dispatch (rate limited, validated)
local actionHandlers = {}
local rate = {} -- Player -> {t0, n}
function Core.onAction(name, fn)
	actionHandlers[name] = fn
end
function Core.handleAction(player, action, args)
	if typeof(action) ~= "string" or #action > 32 then
		return false
	end
	if args ~= nil and type(args) ~= "table" then
		return false
	end
	args = args or {}
	local now = os.clock()
	local r = rate[player]
	if not r or now - r.t0 >= 1 then
		r = { t0 = now, n = 0 }
		rate[player] = r
	end
	r.n += 1
	if r.n > Config.ActionRate then
		return false
	end
	local fn = actionHandlers[action]
	if not fn then
		return false
	end
	local ok, err = pcall(fn, player, args, Core.byPlayer[player])
	if not ok then
		warn(("[Action %s] %s"):format(action, tostring(err)))
	end
	return ok
end
function Core.initActions()
	Core.Remotes.Action.OnServerEvent:Connect(function(player, action, args)
		Core.handleAction(player, action, args)
	end)
	Players.PlayerRemoving:Connect(function(pl)
		rate[pl] = nil
	end)
end

-- validators
function Core.vInt(x, lo, hi)
	if type(x) ~= "number" or x ~= x or x % 1 ~= 0 then
		return nil
	end
	if (lo and x < lo) or (hi and x > hi) then
		return nil
	end
	return x
end
function Core.vStr(x, maxLen)
	if type(x) ~= "string" or #x == 0 or #x > (maxLen or 64) then
		return nil
	end
	return x
end

---------------------------------------------------------------- world lookups
function Core.resort()
	return workspace:FindFirstChild("Resort")
end
function Core.marker(name)
	local r = Core.resort()
	local m = r and r:FindFirstChild("Markers")
	return m and m:FindFirstChild(name)
end
function Core.markers(prefix)
	local out = {}
	local r = Core.resort()
	local m = r and r:FindFirstChild("Markers")
	if m then
		for _, c in ipairs(m:GetChildren()) do
			if c:IsA("BasePart") and c.Name:sub(1, #prefix) == prefix then
				table.insert(out, c)
			end
		end
	end
	table.sort(out, function(a, b)
		return a.Name < b.Name
	end)
	return out
end

-- zone parts sorted by volume (smallest first) so nested zones (Detention in SecurityRoom) win
Core.zoneParts = {}
function Core.indexZones()
	Core.zoneParts = {}
	local r = Core.resort()
	local z = r and r:FindFirstChild("Zones")
	if z then
		for _, p in ipairs(z:GetDescendants()) do
			if p:IsA("BasePart") then
				local id = p:GetAttribute("ZoneId") or p.Name
				table.insert(Core.zoneParts, { part = p, id = id, vol = p.Size.X * p.Size.Y * p.Size.Z })
			end
		end
	end
	table.sort(Core.zoneParts, function(a, b)
		return a.vol < b.vol
	end)
end
function Core.zoneAt(pos)
	if not pos then
		return nil
	end
	for _, e in ipairs(Core.zoneParts) do
		local p = e.part
		local lp = p.CFrame:PointToObjectSpace(pos)
		local h = p.Size * 0.5
		if math.abs(lp.X) <= h.X and math.abs(lp.Y) <= h.Y + 2 and math.abs(lp.Z) <= h.Z then
			return e.id
		end
	end
	return nil
end
function Core.zoneInfo(id)
	local Z = Core.Zones
	if Z and Z.byId and Z.byId[id] then
		return Z.byId[id]
	end
	for _, e in ipairs(Core.zoneParts) do
		if e.id == id then
			return {
				id = id,
				name = e.part:GetAttribute("DisplayName") or id,
				outdoor = e.part:GetAttribute("Outdoor") == true,
				restricted = e.part:GetAttribute("Restricted") == true,
				center = e.part.Position,
			}
		end
	end
	return nil
end
function Core.zoneName(id)
	local z = Core.zoneInfo(id)
	return (z and z.name) or tostring(id or "somewhere")
end
function Core.isOutdoor(id)
	local z = Core.zoneInfo(id)
	return z ~= nil and z.outdoor == true
end
function Core.isRestricted(id)
	local z = Core.zoneInfo(id)
	return z ~= nil and z.restricted == true
end
-- a walkable point in a zone: BotWander marker in that zone > Interact part in that zone > zone part floor
function Core.zonePoint(id)
	local cands = {}
	for _, m in ipairs(Core.markers("BotWander")) do
		if m:GetAttribute("Zone") == id then
			table.insert(cands, m.Position)
		end
	end
	if #cands == 0 then
		for _, p in ipairs(CollectionService:GetTagged("Interact")) do
			if p:IsA("BasePart") and p:GetAttribute("Zone") == id and p:GetAttribute("Kind") ~= "Camera" then
				table.insert(cands, p.Position)
			end
		end
	end
	if #cands == 0 then
		for _, e in ipairs(Core.zoneParts) do
			if e.id == id then
				local p = e.part
				table.insert(cands, (p.CFrame * CFrame.new(0, -p.Size.Y / 2 + 3, 0)).Position)
			end
		end
	end
	if #cands == 0 then
		local z = Core.zoneInfo(id)
		if z and typeof(z.center) == "Vector3" then
			return z.center
		end
		return nil
	end
	return cands[Core.rng:NextInteger(1, #cands)]
end

-- Interact parts
function Core.interactParts(kind, zone)
	local out = {}
	for _, p in ipairs(CollectionService:GetTagged("Interact")) do
		if p:IsA("BasePart") and (kind == nil or p:GetAttribute("Kind") == kind) and (zone == nil or p:GetAttribute("Zone") == zone) then
			table.insert(out, p)
		end
	end
	return out
end
function Core.interactById(id)
	for _, p in ipairs(CollectionService:GetTagged("Interact")) do
		if p:GetAttribute("Id") == id then
			return p
		end
	end
	return nil
end

---------------------------------------------------------------- participants
local PALETTE = {
	Color3.fromRGB(255, 99, 99), Color3.fromRGB(255, 170, 60), Color3.fromRGB(250, 220, 70), Color3.fromRGB(120, 220, 110),
	Color3.fromRGB(70, 200, 210), Color3.fromRGB(90, 140, 255), Color3.fromRGB(170, 110, 255), Color3.fromRGB(255, 120, 200),
	Color3.fromRGB(200, 150, 100), Color3.fromRGB(150, 230, 200), Color3.fromRGB(255, 140, 120), Color3.fromRGB(130, 170, 230),
}
local colorIdx = 0
local function nextColor()
	colorIdx += 1
	return PALETTE[(colorIdx - 1) % #PALETTE + 1]
end

local function newP(id, name, isBot)
	return {
		id = id,
		name = name,
		isBot = isBot,
		color = nextColor(),
		zone = nil,
		suspicion = 0,
		coins = Config.StartCoins, -- bots only (players use profile coins)
		roundCoins = 0,
		hidden = false,
		hideSpot = nil,
		detainedUntil = 0,
		disguiseUntil = 0,
		speedMult = 1,
		accuseReadyAt = 0,
		inRound = false,
	}
end

function Core.addPlayer(player)
	local p = Core.byPlayer[player]
	if p then
		return p
	end
	p = newP(player.UserId, player.DisplayName ~= "" and player.DisplayName or player.Name, false)
	p.player = player
	Core.participants[p.id] = p
	Core.byPlayer[player] = p
	Bus.fire("ParticipantAdded", p)
	return p
end
function Core.addBot(id, name, model)
	local p = newP(id, name, true)
	p.model = model
	p.inv = Instance.new("Folder")
	p.inv.Name = "BotInv_" .. tostring(-id)
	p.inv.Parent = Core.holdFolder()
	Core.participants[id] = p
	Bus.fire("ParticipantAdded", p)
	return p
end
function Core.removeParticipant(id)
	local p = Core.participants[id]
	if not p then
		return
	end
	Bus.fire("ParticipantRemoving", p)
	Core.participants[id] = nil
	if p.player then
		Core.byPlayer[p.player] = nil
	end
	if p.inv then
		p.inv:Destroy()
	end
	if p.stash then
		p.stash:Destroy()
		p.stash = nil
	end
end
function Core.get(id)
	return Core.participants[id]
end
function Core.list(onlyInRound)
	local out = {}
	for _, p in pairs(Core.participants) do
		if not onlyInRound or p.inRound then
			table.insert(out, p)
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end
function Core.realPlayers()
	local out = {}
	for _, p in pairs(Core.participants) do
		if not p.isBot then
			table.insert(out, p)
		end
	end
	return out
end

function Core.char(p)
	if not p then
		return nil
	end
	if p.isBot then
		return p.model
	end
	return p.player and p.player.Character
end
function Core.root(p)
	local c = Core.char(p)
	return c and c:FindFirstChild("HumanoidRootPart")
end
function Core.hum(p)
	local c = Core.char(p)
	return c and c:FindFirstChildOfClass("Humanoid")
end
function Core.pos(p)
	local r = Core.root(p)
	return r and r.Position
end
function Core.dist(a, b)
	local pa, pb = Core.pos(a), Core.pos(b)
	if not pa or not pb then
		return math.huge
	end
	return (pa - pb).Magnitude
end
function Core.alive(p)
	local h = Core.hum(p)
	return h ~= nil and h.Health > 0 and Core.root(p) ~= nil
end
function Core.fromInstance(inst)
	if not inst then
		return nil
	end
	local model = inst:FindFirstAncestorOfClass("Model")
	while model do
		local pl = Players:GetPlayerFromCharacter(model)
		if pl then
			return Core.byPlayer[pl]
		end
		for _, p in pairs(Core.participants) do
			if p.isBot and p.model == model then
				return p
			end
		end
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
	end
	return nil
end
function Core.teleport(p, pos)
	local c = Core.char(p)
	if c and pos then
		c:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
		local r = Core.root(p)
		if r then
			r.AssemblyLinearVelocity = Vector3.zero
		end
	end
end
function Core.isDetained(p)
	return p and p.detainedUntil > os.clock()
end
function Core.isDisguised(p)
	return p and p.disguiseUntil > os.clock()
end
function Core.nearby(pos, radius, exceptId)
	local out = {}
	for _, p in pairs(Core.participants) do
		if p.inRound and p.id ~= exceptId then
			local pp = Core.pos(p)
			if pp and (pp - pos).Magnitude <= radius then
				table.insert(out, p)
			end
		end
	end
	return out
end

-- movement speed composed from state (called by the round tick)
function Core.updateSpeed(p)
	local h = Core.hum(p)
	if not h then
		return
	end
	local base = p.isBot and (p.botSpeed or Config.BotWalkSpeed) or Config.PlayerWalkSpeed
	local mult = 1
	if p.hidden then
		mult = 0
	end
	if Core.M.Events and Core.M.Events.isActive("Storm") and Core.isOutdoor(p.zone) then
		mult *= 0.6
	end
	if Core.isDetained(p) then
		mult = math.min(mult, 0.4)
	end
	local s = base * mult
	h:SetAttribute("BaseSpeed", s)
	if math.abs(h.WalkSpeed - s) > 0.05 then
		h.WalkSpeed = s
	end
end

---------------------------------------------------------------- coins
function Core.getCoins(p)
	if not p then
		return 0
	end
	if p.isBot then
		return p.coins
	end
	local D = Core.M.Data
	local prof = D and D.get(p.player)
	return prof and prof.coins or 0
end
-- n may be negative; returns false (no change) if it would go below zero and allowNegative is not set
function Core.addCoins(p, n, reason, allowClamp)
	if not p or n == 0 then
		return true
	end
	n = math.floor(n)
	local cur = Core.getCoins(p)
	if cur + n < 0 then
		if not allowClamp then
			return false
		end
		n = -cur
	end
	if p.isBot then
		p.coins = cur + n
	else
		local D = Core.M.Data
		if not D or not D.addCoins(p.player, n) then
			return false
		end
		if n > 0 and Core.M.Progress then
			Core.M.Progress.addStat(p.player, "coinsEarned", n)
		end
	end
	if p.inRound then
		p.roundCoins += n
	end
	for _, h in ipairs(Core.coinHooks or {}) do
		pcall(h, p, n, reason)
	end
	if n ~= 0 and reason then
		Core.toast(p, (n > 0 and "+" or "") .. n .. " 🪙 " .. reason, n > 0 and "good" or "bad", n > 0 and "CoinGet" or nil)
	end
	return true
end

---------------------------------------------------------------- items (Tools)
local holdFolder
function Core.holdFolder()
	if not holdFolder or not holdFolder.Parent then
		holdFolder = ServerStorage:FindFirstChild("EHAS_Hold")
		if not holdFolder then
			holdFolder = Instance.new("Folder")
			holdFolder.Name = "EHAS_Hold"
			holdFolder.Parent = ServerStorage
		end
	end
	return holdFolder
end

local function fallbackHandle(itemId)
	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Size = Vector3.new(0.8, 0.8, 0.8)
	h.Color = Color3.fromRGB(255, 210, 80)
	h.Material = Enum.Material.SmoothPlastic
	if itemId == "GoldenStatue" then
		h.Size = Vector3.new(0.9, 1.8, 0.9)
		h.Material = Enum.Material.Metal
	elseif itemId == "Briefcase" then
		h.Size = Vector3.new(1.6, 1.1, 0.4)
		h.Color = Color3.fromRGB(70, 45, 30)
	end
	return h
end

-- build the visual Handle (MAP's ItemArt when available)
function Core.buildHandle(itemId)
	local h
	if Core.ItemArt and Core.ItemArt.build then
		local ok, res = pcall(Core.ItemArt.build, itemId)
		if ok and typeof(res) == "Instance" and res:IsA("BasePart") then
			h = res
		end
	end
	h = h or fallbackHandle(itemId)
	h.Name = "Handle"
	for _, d in ipairs(h:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.Massless = true
			d.CanQuery = false
		end
	end
	h.Anchored = false
	h.CanCollide = false
	h.Massless = true
	return h
end

-- bounding box of the handle + welded child parts in handle space
local function handleBounds(h)
	local mn = -h.Size / 2
	local mx = h.Size / 2
	for _, d in ipairs(h:GetDescendants()) do
		if d:IsA("BasePart") then
			local cf = h.CFrame:ToObjectSpace(d.CFrame)
			local s = d.Size / 2
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local c = cf * Vector3.new(s.X * sx, s.Y * sy, s.Z * sz)
						mn = Vector3.new(math.min(mn.X, c.X), math.min(mn.Y, c.Y), math.min(mn.Z, c.Z))
						mx = Vector3.new(math.max(mx.X, c.X), math.max(mx.Y, c.Y), math.max(mx.Z, c.Z))
					end
				end
			end
		end
	end
	return mn, mx
end
Core.handleBounds = handleBounds

-- Grip so the item sits IN the hand: identity grip = handle upright, -Z forward, centre on the palm
-- (RightGripAttachment). We move the grip point to where a hand would hold the object:
--   bottom: upright objects (statue, bottle, flashlight) held from below their centre, slightly forward
--   top:    carried by a handle (briefcase) — hangs below the fist
--   center: flat / small objects (cards, letter, map, chip, keys)
function Core.applyGrip(tool, itemId)
	local h = tool:FindFirstChild("Handle")
	if not h then
		return
	end
	local mn, mx = handleBounds(h)
	local size = mx - mn
	local cx, cz = (mn.X + mx.X) / 2, (mn.Z + mx.Z) / 2
	local def = Items[itemId]
	local hold = def and def.hold or (size.Y > 1.2 and "bottom" or "center")
	local gy
	if hold == "top" then
		gy = mx.Y - math.min(0.2, size.Y * 0.15)
	elseif hold == "bottom" then
		gy = mn.Y + math.min(0.45, size.Y * 0.25)
	else
		gy = (mn.Y + mx.Y) / 2
	end
	-- push the object half its depth forward of the palm so it never clips the forearm
	local forward = math.max(0, size.Z / 2 - 0.25)
	tool.GripForward = Vector3.new(0, 0, -1)
	tool.GripRight = Vector3.new(1, 0, 0)
	tool.GripUp = Vector3.new(0, 1, 0)
	tool.GripPos = Vector3.new(cx, gy, cz + forward)
end

function Core.makeTool(itemId, opts)
	opts = opts or {}
	local def = Items[itemId]
	local tool = Instance.new("Tool")
	tool.Name = def and def.name or itemId
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = def and def.desc or ""
	tool:SetAttribute("ItemId", itemId)
	if opts.hot then
		tool:SetAttribute("Hot", true)
	end
	if opts.origin then
		tool:SetAttribute("Origin", opts.origin)
	end
	local h = Core.buildHandle(itemId)
	h.Parent = tool
	Core.applyGrip(tool, itemId)
	-- tool activation (photo camera / uniform) handled by Interact
	if Core.M.Interact and Core.M.Interact.hookTool then
		Core.M.Interact.hookTool(tool)
	end
	return tool
end

function Core.items(p)
	local out = {}
	if not p then
		return out
	end
	local function scan(container)
		if container then
			for _, c in ipairs(container:GetChildren()) do
				if c:IsA("Tool") and c:GetAttribute("ItemId") then
					table.insert(out, c)
				end
			end
		end
	end
	if p.isBot then
		scan(p.inv)
		scan(p.model)
	else
		scan(p.player and p.player:FindFirstChildOfClass("Backpack"))
		scan(p.player and p.player.Character)
		scan(p.stash) -- items kept while dead/respawning
	end
	return out
end
function Core.findItem(p, itemId)
	for _, t in ipairs(Core.items(p)) do
		if t:GetAttribute("ItemId") == itemId then
			return t
		end
	end
	return nil
end
function Core.hasItem(p, itemId)
	return Core.findItem(p, itemId) ~= nil
end
function Core.hotItems(p)
	local out = {}
	for _, t in ipairs(Core.items(p)) do
		if t:GetAttribute("Hot") then
			table.insert(out, t)
		end
	end
	return out
end
function Core.equipped(p)
	local c = Core.char(p)
	return c and c:FindFirstChildOfClass("Tool")
end
function Core.itemCount(p)
	return #Core.items(p)
end

-- bots visibly hold the most interesting item and raise the arm (toolnone pose)
function Core.botRefreshHold(p)
	if not p.isBot or not p.model then
		return
	end
	local hum = p.model:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local best
	for _, t in ipairs(Core.items(p)) do
		if t:GetAttribute("Hot") or (Items[t:GetAttribute("ItemId")] and Items[t:GetAttribute("ItemId")].valuable) then
			best = t
			break
		end
		best = best or t
	end
	local cur = p.model:FindFirstChildOfClass("Tool")
	if cur == best then
		return
	end
	if cur then
		cur.Parent = p.inv
	end
	local Anim = require(script.Parent.Anim)
	if best then
		pcall(function()
			hum:EquipTool(best)
		end)
		Anim.play(hum, "toolnone", 1, true)
	else
		Anim.stop(hum, "toolnone")
	end
end

-- moves an existing tool to p (keeps Hot/Origin attributes)
function Core.giveTool(p, tool)
	if not p or not tool then
		return nil
	end
	if p.isBot then
		tool.Parent = p.inv
		Core.botRefreshHold(p)
	else
		local bp = p.player and p.player:FindFirstChildOfClass("Backpack")
		if bp and Core.alive(p) then
			tool.Parent = bp
		else
			p.stash = p.stash or Instance.new("Folder")
			p.stash.Name = "Stash_" .. p.id
			p.stash.Parent = Core.holdFolder()
			tool.Parent = p.stash
		end
	end
	return tool
end
function Core.giveItem(p, itemId, opts)
	if not Items[itemId] then
		return nil
	end
	local tool = Core.makeTool(itemId, opts)
	Core.giveTool(p, tool)
	return tool
end
-- detach a tool from whoever has it (parent nil); returns the tool
function Core.takeTool(tool)
	if not tool then
		return nil
	end
	local owner = Core.toolOwner(tool)
	tool.Parent = Core.holdFolder()
	if owner and owner.isBot then
		Core.botRefreshHold(owner)
	end
	return tool
end
function Core.clearItems(p)
	for _, t in ipairs(Core.items(p)) do
		t:Destroy()
	end
	if p.isBot then
		Core.botRefreshHold(p)
	end
end
-- owner of a tool (participant) if any
function Core.toolOwner(tool)
	if not tool or not tool.Parent then
		return nil
	end
	for _, p in pairs(Core.participants) do
		local par = tool.Parent
		if (p.isBot and (par == p.inv or par == p.model)) or (not p.isBot and p.player and (par == p.player:FindFirstChildOfClass("Backpack") or par == p.player.Character or par == p.stash)) then
			return p
		end
	end
	return nil
end

---------------------------------------------------------------- realistic NPC rigs
-- R15 joint table: {child, parent, motorName, attachment}
local R15_JOINTS = {
	{ "LowerTorso", "HumanoidRootPart", "Root", "RootRigAttachment" },
	{ "UpperTorso", "LowerTorso", "Waist", "WaistRigAttachment" },
	{ "Head", "UpperTorso", "Neck", "NeckRigAttachment" },
	{ "LeftUpperArm", "UpperTorso", "LeftShoulder", "LeftShoulderRigAttachment" },
	{ "LeftLowerArm", "LeftUpperArm", "LeftElbow", "LeftElbowRigAttachment" },
	{ "LeftHand", "LeftLowerArm", "LeftWrist", "LeftWristRigAttachment" },
	{ "RightUpperArm", "UpperTorso", "RightShoulder", "RightShoulderRigAttachment" },
	{ "RightLowerArm", "RightUpperArm", "RightElbow", "RightElbowRigAttachment" },
	{ "RightHand", "RightLowerArm", "RightWrist", "RightWristRigAttachment" },
	{ "LeftUpperLeg", "LowerTorso", "LeftHip", "LeftHipRigAttachment" },
	{ "LeftLowerLeg", "LeftUpperLeg", "LeftKnee", "LeftKneeRigAttachment" },
	{ "LeftFoot", "LeftLowerLeg", "LeftAnkle", "LeftAnkleRigAttachment" },
	{ "RightUpperLeg", "LowerTorso", "RightHip", "RightHipRigAttachment" },
	{ "RightLowerLeg", "RightUpperLeg", "RightKnee", "RightKneeRigAttachment" },
	{ "RightFoot", "RightLowerLeg", "RightAnkle", "RightAnkleRigAttachment" },
}
Core.R15_JOINTS = R15_JOINTS

-- CreateHumanoidModelFromDescription can return rigs without Motor6Ds in server Run mode:
-- build the 15 joints from the *RigAttachment pairs ourselves (before cloning).
function Core.ensureR15Joints(model)
	local made = 0
	for _, j in ipairs(R15_JOINTS) do
		local child, parent = model:FindFirstChild(j[1]), model:FindFirstChild(j[2])
		if child and parent then
			local existing = child:FindFirstChild(j[3])
			if not (existing and existing:IsA("Motor6D")) then
				local a1, a0 = child:FindFirstChild(j[4]), parent:FindFirstChild(j[4])
				if a1 and a0 then
					local m = Instance.new("Motor6D")
					m.Name = j[3]
					m.Part0, m.Part1 = parent, child
					m.C0, m.C1 = a0.CFrame, a1.CFrame
					m.Parent = child
					made += 1
				end
			end
		end
	end
	return made
end
function Core.countMotors(model)
	local n = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then
			n += 1
		end
	end
	return n
end

Core.SKIN_TONES = {
	Color3.fromRGB(255, 224, 196), Color3.fromRGB(241, 194, 160), Color3.fromRGB(234, 192, 134),
	Color3.fromRGB(224, 172, 105), Color3.fromRGB(198, 134, 66), Color3.fromRGB(161, 102, 64),
	Color3.fromRGB(141, 85, 36), Color3.fromRGB(105, 67, 40), Color3.fromRGB(255, 219, 172),
}
Core.HAIR_COLORS = {
	Color3.fromRGB(35, 25, 20), Color3.fromRGB(70, 45, 25), Color3.fromRGB(120, 80, 40), Color3.fromRGB(200, 160, 90),
	Color3.fromRGB(150, 60, 30), Color3.fromRGB(20, 20, 20), Color3.fromRGB(230, 210, 160),
}

-- REAL avatar assets (free Roblox-made catalog items) so NPCs look like real players, not grey blocks.
-- Loaded via HumanoidDescription; if loading fails (offline / blocked) we fall back to the part-built look.
Core.HAIR_IDS = { 376548738, 62234425, 376526888, 63690008, 376524487, 9244150641, 7193455510, 7193454569, 9244148336,
	2956239660, 376527350, 451221329, 1103003368 }
Core.FACE_IDS = {} -- 948/949 are 404 on assetdelivery; default face is used
Core.SHIRT_IDS = { 398635081, 144076436, 398634295, 382537702, 4047886060, 382538059, 398633584, 3670737444 }
Core.PANTS_IDS = { 382537569, 144076760, 398634487, 382537806, 382537950, 398635338, 129458426 }
Core.SUIT_PANTS = 129459077 -- black slacks for staff/guards
local descTemplates = {} -- key -> Model | false
local function descRig(key, hair, face, shirt, pants)
	if descTemplates[key] ~= nil then
		return descTemplates[key] or nil
	end
	local ok, model = pcall(function()
		local d = Instance.new("HumanoidDescription")
		if hair then d.HairAccessory = tostring(hair) end
		if face then d.Face = face end
		if shirt then d.Shirt = shirt end
		if pants then d.Pants = pants end
		return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	end)
	if ok and model and model:FindFirstChild("HumanoidRootPart") and model:FindFirstChildOfClass("Humanoid") then
		for _, c in ipairs(model:GetDescendants()) do
			if c:IsA("LocalScript") or c:IsA("Script") then c:Destroy() end
		end
		Core.ensureR15Joints(model)
		descTemplates[key] = model
		return model
	end
	descTemplates[key] = false
	return nil
end
Core.descRig = descRig

local templateCache = nil -- Model | false
local function baseTemplate()
	if templateCache ~= nil then
		return templateCache or nil
	end
	local ok, model = pcall(function()
		local d = Instance.new("HumanoidDescription")
		return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	end)
	if ok and model and model:FindFirstChild("HumanoidRootPart") and model:FindFirstChildOfClass("Humanoid") then
		for _, c in ipairs(model:GetDescendants()) do
			if c:IsA("LocalScript") or c:IsA("Script") or c:IsA("Accessory") or c:IsA("Shirt") or c:IsA("Pants") or c:IsA("ShirtGraphic") then
				c:Destroy()
			end
		end
		Core.ensureR15Joints(model)
		templateCache = model
		return model
	end
	warn("[Core] R15 rig unavailable (" .. tostring(model) .. "), using block NPCs")
	templateCache = false
	return nil
end
Core.baseTemplate = baseTemplate

local function weldTo(part0, part1, c0)
	local w = Instance.new("Weld")
	w.Part0 = part0
	w.Part1 = part1
	w.C0 = c0
	w.C1 = CFrame.new()
	w.Parent = part1
	return w
end

local function decoPart(name, size, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	return p
end

-- accessory built from parts: first part is the Handle, the rest are welded to it.
-- pieces = { {size=, color=, offset=CFrame (relative to handle), material=, shape=} }
-- attachOffset = CFrame of the handle relative to the host part (Head / UpperTorso)
function Core.makeAccessory(name, host, attachOffset, pieces)
	local acc = Instance.new("Accessory")
	acc.Name = name
	local handle
	for i, pc in ipairs(pieces) do
		local p = decoPart(i == 1 and "Handle" or (name .. "_" .. i), pc.size, pc.color, pc.material, pc.shape)
		if i == 1 then
			handle = p
			p.Parent = acc
		else
			p.Parent = handle
			p.CFrame = CFrame.new() -- set below via weld
			weldTo(handle, p, pc.offset or CFrame.new())
		end
	end
	if host and handle then
		handle.CFrame = host.CFrame * attachOffset
		local w = weldTo(host, handle, attachOffset)
		w.Name = "AccessoryWeld"
	end
	acc.Parent = host and host.Parent or nil
	return acc
end

local function setColor(model, partName, color)
	local p = model:FindFirstChild(partName)
	if p and p:IsA("BasePart") then
		p.Color = color
	end
end

-- hair styles from parts (welded to the head). head-local offsets scale with head size.
local function addHair(model, style, color)
	local head = model:FindFirstChild("Head")
	if not head or style == "bald" then
		return
	end
	local s = head.Size
	local w, hgt, d = s.X, s.Y, s.Z
	local pieces = {
		{ size = Vector3.new(w * 1.06, hgt * 0.32, d * 1.08), color = color, material = Enum.Material.SmoothPlastic }, -- crown
		{ size = Vector3.new(w * 1.06, hgt * 0.55, d * 0.22), color = color, offset = CFrame.new(0, -hgt * 0.22, d * 0.46) }, -- back
		{ size = Vector3.new(w * 0.14, hgt * 0.4, d * 0.9), color = color, offset = CFrame.new(-w * 0.49, -hgt * 0.15, d * 0.06) }, -- side L
		{ size = Vector3.new(w * 0.14, hgt * 0.4, d * 0.9), color = color, offset = CFrame.new(w * 0.49, -hgt * 0.15, d * 0.06) }, -- side R
	}
	if style == "long" then
		table.insert(pieces, { size = Vector3.new(w * 1.04, hgt * 1.1, d * 0.25), color = color, offset = CFrame.new(0, -hgt * 0.62, d * 0.5) })
	elseif style == "bun" then
		table.insert(pieces, { size = Vector3.new(w * 0.5, w * 0.5, w * 0.5), color = color, offset = CFrame.new(0, hgt * 0.15, d * 0.55), shape = Enum.PartType.Ball })
	elseif style == "fringe" then
		table.insert(pieces, { size = Vector3.new(w * 0.9, hgt * 0.16, d * 0.18), color = color, offset = CFrame.new(w * 0.05, -hgt * 0.1, -d * 0.48) * CFrame.Angles(0, 0, math.rad(-8)) })
	elseif style == "afro" then
		pieces[1] = { size = Vector3.new(w * 1.45, hgt * 0.95, d * 1.45), color = color, shape = Enum.PartType.Ball }
	end
	Core.makeAccessory("Hair", head, CFrame.new(0, hgt * 0.38, 0.02 * d), pieces)
end

-- torso overlays (vests, jackets, badges): parts welded to UpperTorso
local function torsoPiece(model, name, size, color, offset, material)
	local torso = model:FindFirstChild("UpperTorso")
	if not torso then
		return nil
	end
	local p = decoPart(name, size, color, material)
	p.Parent = model
	p.CFrame = torso.CFrame * offset
	weldTo(torso, p, offset)
	return p
end

-- outfits: guard | chef | waiter | dealer | receptionist | lifeguard | janitor | shopkeeper | vip | guest
function Core.dressRig(model, look)
	look = look or {}
	local rng = Core.rng
	local skin = look.skin or Core.SKIN_TONES[rng:NextInteger(1, #Core.SKIN_TONES)]
	local shirt = look.shirt or Color3.fromRGB(240, 240, 240)
	local pants = look.pants or Color3.fromRGB(50, 55, 70)
	local shoes = look.shoes or Color3.fromRGB(35, 30, 28)
	local longSleeves = look.longSleeves ~= false
	for _, n in ipairs({ "Head", "LeftHand", "RightHand" }) do
		setColor(model, n, skin)
	end
	if look.realShirt or look.realPants then
		-- real classic clothing covers the body; just keep skin + shoes natural
		for _, n in ipairs({ "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
			"LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot" }) do
			setColor(model, n, skin)
		end
	end
	if look.realShirt then
		-- skip flat colouring + tee/stripe overlays for guests in real clothes
	else
	setColor(model, "UpperTorso", shirt)
	setColor(model, "LowerTorso", look.belt and pants or shirt)
	setColor(model, "LeftUpperArm", shirt)
	setColor(model, "RightUpperArm", shirt)
	setColor(model, "LeftLowerArm", longSleeves and shirt or skin)
	setColor(model, "RightLowerArm", longSleeves and shirt or skin)
	setColor(model, "LeftUpperLeg", pants)
	setColor(model, "RightUpperLeg", pants)
	setColor(model, "LeftLowerLeg", look.shorts and skin or pants)
	setColor(model, "RightLowerLeg", look.shorts and skin or pants)
	setColor(model, "LeftFoot", shoes)
	setColor(model, "RightFoot", shoes)
	end
	if look.realPants and not look.realShirt then
		for _, n in ipairs({ "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot" }) do
			setColor(model, n, skin)
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
			d.Material = Enum.Material.SmoothPlastic
		end
	end
	if not look.realHair then
		addHair(model, look.hair or "short", look.hairColor or Core.HAIR_COLORS[rng:NextInteger(1, #Core.HAIR_COLORS)])
	end

	local torso = model:FindFirstChild("UpperTorso")
	local head = model:FindFirstChild("Head")
	local ts = torso and torso.Size or Vector3.new(2, 1.6, 1)
	local hs = head and head.Size or Vector3.new(1.2, 1.2, 1.2)
	local outfit = look.outfit or "guest"
	local gold = Color3.fromRGB(240, 200, 70)
	local black = Color3.fromRGB(25, 25, 30)
	local white = Color3.fromRGB(245, 245, 245)
	if outfit == "guard" then
		-- navy cap (crown + brim + gold band) as an Accessory, gold badge, black belt, shoulder epaulettes
		local navy = Color3.fromRGB(28, 40, 85)
		Core.makeAccessory("GuardCap", head, CFrame.new(0, hs.Y * 0.48, 0), {
			{ size = Vector3.new(hs.X * 1.08, hs.Y * 0.36, hs.Z * 1.1), color = navy },
			{ size = Vector3.new(hs.X * 0.95, hs.Y * 0.06, hs.Z * 0.45), color = black, offset = CFrame.new(0, -hs.Y * 0.16, -hs.Z * 0.68) },
			{ size = Vector3.new(hs.X * 1.1, hs.Y * 0.08, hs.Z * 1.12), color = gold, offset = CFrame.new(0, -hs.Y * 0.1, 0), material = Enum.Material.Metal },
			{ size = Vector3.new(hs.X * 0.22, hs.Y * 0.18, hs.Z * 0.05), color = gold, offset = CFrame.new(0, hs.Y * 0.03, -hs.Z * 0.56), material = Enum.Material.Metal },
		})
		torsoPiece(model, "Badge", Vector3.new(ts.X * 0.16, ts.Y * 0.2, 0.08), gold, CFrame.new(-ts.X * 0.24, ts.Y * 0.18, -ts.Z * 0.52), Enum.Material.Metal)
		torsoPiece(model, "Belt", Vector3.new(ts.X * 1.04, ts.Y * 0.1, ts.Z * 1.06), black, CFrame.new(0, -ts.Y * 0.47, 0))
		torsoPiece(model, "EpauletL", Vector3.new(ts.X * 0.22, 0.08, ts.Z * 0.6), gold, CFrame.new(-ts.X * 0.4, ts.Y * 0.5, 0))
		torsoPiece(model, "EpauletR", Vector3.new(ts.X * 0.22, 0.08, ts.Z * 0.6), gold, CFrame.new(ts.X * 0.4, ts.Y * 0.5, 0))
		torsoPiece(model, "Radio", Vector3.new(0.18, 0.35, 0.12), black, CFrame.new(ts.X * 0.28, ts.Y * 0.15, -ts.Z * 0.52))
	elseif outfit == "chef" then
		-- white double-breasted jacket with buttons + tall chef hat
		for i = 0, 2 do
			torsoPiece(model, "BtnL" .. i, Vector3.new(0.1, 0.1, 0.06), black, CFrame.new(-ts.X * 0.14, ts.Y * (0.25 - i * 0.22), -ts.Z * 0.51))
			torsoPiece(model, "BtnR" .. i, Vector3.new(0.1, 0.1, 0.06), black, CFrame.new(ts.X * 0.14, ts.Y * (0.25 - i * 0.22), -ts.Z * 0.51))
		end
		torsoPiece(model, "Collar", Vector3.new(ts.X * 0.55, ts.Y * 0.1, ts.Z * 1.02), white, CFrame.new(0, ts.Y * 0.47, 0))
		Core.makeAccessory("ChefHat", head, CFrame.new(0, hs.Y * 0.62, 0), {
			{ size = Vector3.new(hs.X * 0.95, hs.Y * 0.55, hs.Z * 0.95), color = white },
			{ size = Vector3.new(hs.X * 1.25, hs.X * 1.0, hs.Z * 1.25), color = white, offset = CFrame.new(0, hs.Y * 0.42, 0), shape = Enum.PartType.Ball },
		})
	elseif outfit == "waiter" or outfit == "dealer" or outfit == "receptionist" then
		-- white shirt + vest (front panels + back) + bow tie
		local vest = look.vest or (outfit == "dealer" and Color3.fromRGB(170, 20, 35) or black)
		torsoPiece(model, "VestL", Vector3.new(ts.X * 0.4, ts.Y * 0.95, 0.1), vest, CFrame.new(-ts.X * 0.3, -ts.Y * 0.02, -ts.Z * 0.5))
		torsoPiece(model, "VestR", Vector3.new(ts.X * 0.4, ts.Y * 0.95, 0.1), vest, CFrame.new(ts.X * 0.3, -ts.Y * 0.02, -ts.Z * 0.5))
		torsoPiece(model, "VestBack", Vector3.new(ts.X * 1.02, ts.Y * 0.95, 0.1), vest, CFrame.new(0, -ts.Y * 0.02, ts.Z * 0.5))
		torsoPiece(model, "BowL", Vector3.new(0.22, 0.16, 0.08), black, CFrame.new(-0.12, ts.Y * 0.4, -ts.Z * 0.53) * CFrame.Angles(0, 0, math.rad(15)))
		torsoPiece(model, "BowR", Vector3.new(0.22, 0.16, 0.08), black, CFrame.new(0.12, ts.Y * 0.4, -ts.Z * 0.53) * CFrame.Angles(0, 0, math.rad(-15)))
		if outfit == "receptionist" then
			torsoPiece(model, "NameTag", Vector3.new(ts.X * 0.18, ts.Y * 0.1, 0.06), gold, CFrame.new(ts.X * 0.25, ts.Y * 0.2, -ts.Z * 0.56), Enum.Material.Metal)
		end
	elseif outfit == "lifeguard" then
		torsoPiece(model, "Whistle", Vector3.new(0.15, 0.25, 0.1), Color3.fromRGB(250, 220, 40), CFrame.new(0, ts.Y * 0.05, -ts.Z * 0.53))
		Core.makeAccessory("Visor", head, CFrame.new(0, hs.Y * 0.36, -hs.Z * 0.42), {
			{ size = Vector3.new(hs.X * 1.0, 0.08, hs.Z * 0.45), color = Color3.fromRGB(250, 250, 250) },
		})
	elseif outfit == "janitor" then
		torsoPiece(model, "Apron", Vector3.new(ts.X * 0.8, ts.Y * 1.2, 0.08), Color3.fromRGB(70, 110, 140), CFrame.new(0, -ts.Y * 0.2, -ts.Z * 0.52))
	elseif outfit == "vip" then
		torsoPiece(model, "Lapel", Vector3.new(ts.X * 0.3, ts.Y * 0.9, 0.08), white, CFrame.new(0, 0, -ts.Z * 0.5))
		torsoPiece(model, "Tie", Vector3.new(0.14, ts.Y * 0.7, 0.08), Color3.fromRGB(170, 20, 35), CFrame.new(0, -ts.Y * 0.05, -ts.Z * 0.54))
		Core.makeAccessory("Shades", head, CFrame.new(0, hs.Y * 0.08, -hs.Z * 0.52), {
			{ size = Vector3.new(hs.X * 0.85, hs.Y * 0.16, 0.06), color = black, material = Enum.Material.Glass },
		})
	elseif outfit == "guest" then
		local accent = look.accent or Color3.fromRGB(255, 255, 255)
		local variant = look.variant or rng:NextInteger(1, 4)
		if look.realShirt and (variant == 1 or variant == 2) then
			variant = 4 -- real shirt already has a print; add shades + necklace instead of flat overlays
		end
		if variant == 3 and look.realHair then
			variant = 4 -- sun hat would clip through real hair
		end
		if variant == 1 then -- open shirt over a tee
			torsoPiece(model, "Tee", Vector3.new(ts.X * 0.34, ts.Y * 0.95, 0.06), accent, CFrame.new(0, 0, -ts.Z * 0.51))
		elseif variant == 2 then -- stripes
			for i = 0, 2 do
				torsoPiece(model, "Stripe" .. i, Vector3.new(ts.X * 1.03, ts.Y * 0.09, ts.Z * 1.04), accent, CFrame.new(0, ts.Y * (0.25 - i * 0.25), 0))
			end
		elseif variant == 3 then -- sun hat
			Core.makeAccessory("SunHat", head, CFrame.new(0, hs.Y * 0.5, 0), {
				{ size = Vector3.new(hs.X * 1.0, hs.Y * 0.3, hs.Z * 1.0), color = Color3.fromRGB(235, 215, 160), material = Enum.Material.Fabric },
				{ size = Vector3.new(hs.X * 1.9, 0.08, hs.Z * 1.9), color = Color3.fromRGB(235, 215, 160), offset = CFrame.new(0, -hs.Y * 0.14, 0), material = Enum.Material.Fabric },
				{ size = Vector3.new(hs.X * 1.02, hs.Y * 0.08, hs.Z * 1.02), color = accent, offset = CFrame.new(0, -hs.Y * 0.08, 0) },
			})
		else -- sunglasses + necklace
			Core.makeAccessory("Shades", head, CFrame.new(0, hs.Y * 0.08, -hs.Z * 0.52), {
				{ size = Vector3.new(hs.X * 0.85, hs.Y * 0.16, 0.06), color = black, material = Enum.Material.Glass },
			})
			torsoPiece(model, "Necklace", Vector3.new(ts.X * 0.4, 0.07, 0.06), accent, CFrame.new(0, ts.Y * 0.38, -ts.Z * 0.52))
		end
	end
	return model
end

local function blockRig(name)
	local model = Instance.new("Model")
	model.Name = name
	local root = decoPart("HumanoidRootPart", Vector3.new(2, 2, 1), Color3.new(1, 1, 1))
	root.Transparency = 1
	root.Massless = false
	root.CanCollide = true
	root.Parent = model
	local torso = decoPart("UpperTorso", Vector3.new(2, 2, 1), Color3.fromRGB(200, 200, 200))
	torso.Parent = model
	weldTo(root, torso, CFrame.new())
	local head = decoPart("Head", Vector3.new(1.2, 1.2, 1.2), Color3.fromRGB(240, 200, 160))
	head.Parent = model
	weldTo(torso, head, CFrame.new(0, 1.6, 0))
	model.PrimaryPart = root
	local hum = Instance.new("Humanoid")
	hum.RequiresNeck = false
	hum.HipHeight = 2
	hum.Parent = model
	return model
end

-- Core.makeRig(name, look) -> Model (unparented). look as in dressRig + displayName.
function Core.makeRig(name, look)
	local template = baseTemplate()
	local model
	look = look or {}
	-- pick real hair/face (+ real clothes for guests); deterministic per name so a bot keeps its look
	local h = 0
	for i = 1, #name do h = (h * 31 + string.byte(name, i)) % 1000003 end
	local outfit = look.outfit or "guest"
	local hairId = look.hairId or Core.HAIR_IDS[h % #Core.HAIR_IDS + 1]
	if outfit == "guard" or outfit == "chef" then
		hairId = nil -- cap / chef hat covers the head; real hair would poke through
	end
	local faceId = #Core.FACE_IDS > 0 and Core.FACE_IDS[(h // 7) % #Core.FACE_IDS + 1] or nil
	local shirtId, pantsId
	if outfit == "guest" then
		shirtId = look.shirtId or Core.SHIRT_IDS[(h // 3) % #Core.SHIRT_IDS + 1]
		pantsId = look.pantsId or Core.PANTS_IDS[(h // 5) % #Core.PANTS_IDS + 1]
	elseif outfit ~= "lifeguard" then
		pantsId = Core.SUIT_PANTS
	end
	local real = template and descRig(table.concat({ hairId or 0, faceId or 0, shirtId or 0, pantsId or 0 }, "_"), hairId, faceId, shirtId, pantsId)
	if real then
		model = real:Clone()
		Core.ensureR15Joints(model)
		look = table.clone(look)
		look.realHair = hairId ~= nil
		look.realShirt = shirtId ~= nil
		look.realPants = pantsId ~= nil
	elseif template then
		model = template:Clone()
		Core.ensureR15Joints(model) -- some clones still come back joint-less
	else
		model = blockRig(name)
	end
	model.Name = name
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.DisplayName = look and look.displayName or name
	hum.BreakJointsOnDeath = false
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	hum.NameDisplayDistance = 60
	pcall(function()
		hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	end)
	if not hum:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = hum
	end
	if template then
		Core.dressRig(model, look)
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		model.PrimaryPart = root
	end
	return model
end

---------------------------------------------------------------- misc
function Core.shuffle(list)
	local t = table.clone(list)
	for i = #t, 2, -1 do
		local j = Core.rng:NextInteger(1, i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end
function Core.pick(list)
	if #list == 0 then
		return nil
	end
	return list[Core.rng:NextInteger(1, #list)]
end
function Core.fmtTime(serverTime)
	-- mm:ss of round time for log texts
	local el = math.max(0, serverTime - (Core.roundStartServer or serverTime))
	return ("%d:%02d"):format(math.floor(el / 60), math.floor(el % 60))
end
function Core.itemName(id)
	return Items[id] and Items[id].name or tostring(id)
end
function Core.nameOf(id)
	local p = Core.participants[id]
	return p and p.name or ("#" .. tostring(id))
end

return Core
