--!nocheck
-- MapBuilder: builds the whole "Grand Palm Resort" under workspace.Resort at runtime.
-- MapBuilder.Build() -> returns when done and sets workspace:SetAttribute("MapReady", true).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local U = require(script.Parent.Util)
local P = require(script.Parent.Props)
local Hotel = require(script.Parent.Hotel)
local Exterior = require(script.Parent.Exterior)
local Casino = require(script.Parent.Casino)
local East = require(script.Parent.East)
local West = require(script.Parent.West)
local Beach = require(script.Parent.Beach)
local Underground = require(script.Parent.Underground)
local MapLighting = require(script.Parent.Lighting)

local MapBuilder = {}
MapBuilder.built = false

-- world constants (shared with sub-builders through ctx)
local G = 4.2 -- ground walk level (top of paving / ground floors)
local LAWN = 3.0 -- top of the lawn base slab
local UF = -12 -- underground floor top
local WL = -2 -- sea level (terrain water surface)
local PIER = 0.6 -- floating pier deck top
local BOATY = -1.4 -- boat hull centre

local function shaftHole(sx)
	return { sx - 5, -66, sx + 5, -40 }
end
local POOL_HOLE = { 100, 22, 150, 62 }

local function safeRequire(name)
	local mod = ReplicatedStorage:FindFirstChild(name)
	if not mod then
		return nil
	end
	local ok, res = pcall(require, mod)
	return ok and res or nil
end

------------------------------------------------------------------ terrain
local function buildTerrain()
	local T = workspace.Terrain
	local Mt = Enum.Material
	pcall(function()
		T:Clear()
	end)
	pcall(function()
		T.WaterColor = Color3.fromRGB(32, 178, 196)
		T.WaterTransparency = 0.55
		T.WaterReflectance = 0.6
		T.WaterWaveSize = 0.12
		T.WaterWaveSpeed = 8
		T:SetMaterialColor(Mt.Sand, Color3.fromRGB(236, 216, 168))
		T:SetMaterialColor(Mt.Grass, Color3.fromRGB(98, 172, 78))
		T:SetMaterialColor(Mt.LeafyGrass, Color3.fromRGB(98, 172, 78))
		T:SetMaterialColor(Mt.Rock, Color3.fromRGB(150, 140, 126))
		T.GrassLength = 0.55
	end)
	local function fill(cx, cy, cz, sx, sy, sz, mat)
		pcall(function()
			T:FillBlock(CFrame.new(cx, cy, cz), Vector3.new(sx, sy, sz), mat)
		end)
	end
	-- ocean (big) then land
	fill(0, (WL - 40) / 2, 260, 900, 40 + WL, 360, Mt.Water)
	fill(-330, (WL - 40) / 2, -60, 240, 40 + WL, 680, Mt.Water)
	fill(330, (WL - 40) / 2, -60, 240, 40 + WL, 680, Mt.Water)
	fill(0, (WL - 40) / 2, -330, 900, 40 + WL, 180, Mt.Water)
	-- island grass body (x ±212, z -236..96), top y = 0
	fill(0, -15, -70, 424, 30, 332, Mt.Grass)
	-- beach: sand strips sloping from the sea wall into the sea
	for z = 96, 236, 4 do
		local top
		if z <= 150 then
			top = 1.4 - (z - 96) * 0.055
		else
			top = -1.6 - (z - 150) * 0.22
		end
		local bottom = -40
		fill(0, (top + bottom) / 2, z + 2, 432, top - bottom, 4, Mt.Sand)
	end
	-- sandy shoulders round the island sides (beach wraps the corners)
	for _, sx in { -1, 1 } do
		for k = 0, 8 do
			local x = sx * (214 + k * 4)
			local top = 0.5 - k * 0.9
			fill(x + sx * 2, (top - 40) / 2, -60, 4, top + 40, 320, Mt.Sand)
		end
	end
	-- hills behind the resort (north backdrop)
	local hills = { { -150, -190, 34 }, { -70, -205, 44 }, { 20, -200, 38 }, { 110, -195, 46 }, { 185, -175, 30 }, { -205, -150, 26 } }
	for _, h in hills do
		pcall(function()
			T:FillBall(Vector3.new(h[1], -h[3] * 0.35, h[2]), h[3], Mt.Grass)
			T:FillBall(Vector3.new(h[1] + 6, h[3] * 0.25, h[2] - 8), h[3] * 0.55, Mt.Rock)
		end)
	end
	-- islet out at sea
	pcall(function()
		T:FillBall(Vector3.new(-120, -14, 330), 26, Mt.Sand)
		T:FillBall(Vector3.new(-120, -10, 330), 16, Mt.Grass)
	end)
	-- carve the resort core (every building/paving sits on Parts; the underground needs empty space)
	fill(0, -14, -24, 392, 52, 208, Mt.Air)
end

------------------------------------------------------------------ zone metadata (must match src/shared/Zones.luau)
local ZONE_BOXES = {
	Plaza = { { -60, 0, -10, 60, 22, 80 } },
	Lobby = { { -24, 4, -70, 24, 19.6, -10 }, { 24, 4, -60, 60, 19.6, -10 } },
	Reception = { { -24, 4, -100, 24, 19.6, -70 } },
	GuestRooms = { { -60, 20.4, -100, 60, 36.6, -10 } },
	Balcony = { { -30, 20.4, -10, 30, 34, 4 } },
	Rooftop = { { -61, 36.6, -101, 61, 56, -9 } },
	HotelBar = { { -60, 4, -50, -24, 19.6, -10 } },
	Restaurant = { { 90, 4, -70, 145, 20, -20 }, { 90, 0, -20, 170, 20, 0 } },
	PrivateDining = { { 90, 4, -100, 120, 20, -70 } },
	Kitchen = { { 120, 4, -100, 170, 20, -70 }, { 145, 4, -70, 170, 20, -20 }, { 170, 0, -100, 192, 20, 0 } },
	Housekeeping = { { -60, 4, -100, -24, 19.6, -50 }, { -72, 0, -116, -30, 18, -100 } },
	SecurityRoom = { { 24, 4, -100, 60, 19.6, -60 } },
	Detention = { { 46, 4, -100, 60, 15, -86 } },
	Casino = { { -175, 4, -70, -90, 26, -20 }, { -141, 0, -20, -119, 18, -6 } },
	CasinoVIP = { { -175, 4, -100, -135, 26, -70 } },
	CasinoBackRoom = { { -135, 4, -100, -90, 26, -70 } },
	Pool = { { 60, -2, 0, 186, 24, 80 } },
	ChangingRooms = { { 162, 4, 6, 182, 15, 36 } },
	PoolBar = { { 158, 4, 44, 186, 18, 80 } },
	Beach = { { -196, -8, 80, 196, 30, 175 } },
	Dock = { { 76, -8, 96, 124, 22, 228 } },
	BeachShop = { { -114, 0, 94, -86, 20, 124 } },
	ShopStreet = { { -185, 0, -20, -88, 24, 80 } },
	JewelryShop = { { -180, 4, 54, -147, 20, 78 } },
	Underground = { { -86, -13, -68, 86, -1, -18 } },
	ElectricalRoom = { { 30, -13, -64, 56, -1, -40 } },
	HiddenRoom = { { -10, -13, -66, 14, -1, -40 }, { 14, -13, -60, 30, -1, -52 } },
}
MapBuilder.ZONE_BOXES = ZONE_BOXES

------------------------------------------------------------------ Build
function MapBuilder.Build()
	if MapBuilder.built then
		return workspace:FindFirstChild("Resort")
	end
	MapBuilder.built = true
	local t0 = os.clock()
	U.count = 0
	U.markerCount = 0
	U.interactCounts = {}
	U.ids = {}

	local old = workspace:FindFirstChild("Resort")
	if old then
		old:Destroy()
	end

	MapLighting.apply()
	buildTerrain()

	local resort = Instance.new("Model")
	resort.Name = "Resort"
	pcall(function()
		resort.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	local zones = Instance.new("Model")
	zones.Name = "Zones"
	pcall(function()
		zones.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	zones.Parent = resort
	local markers = Instance.new("Folder")
	markers.Name = "Markers"
	markers.Parent = resort
	local ambience = Instance.new("Folder")
	ambience.Name = "Ambience"
	ambience.Parent = resort

	local ZonesData = safeRequire("Zones")
	local Sfx = safeRequire("Sfx") or {}

	local models = {}
	local counters = { ItemSpawn = 0, BotWander = 0 }
	local ctx = {
		U = U,
		P = P,
		G = G,
		LAWN = LAWN,
		UF = UF,
		WL = WL,
		PIER = PIER,
		BOATY = BOATY,
		markers = markers,
		poolHole = POOL_HOLE,
		groundHoles = { shaftHole(-77), shaftHole(73), POOL_HOLE },
		npcRoles = {},
	}
	function ctx.model(name)
		if models[name] then
			return models[name]
		end
		local m = Instance.new("Model")
		m.Name = name
		pcall(function()
			m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		end)
		m.Parent = resort
		models[name] = m
		return m
	end
	-- floorPos = point ON the walkable floor; markers sit 3 studs above it
	function ctx.mark(name, floorPos, attrs)
		return U.marker(markers, name, floorPos + Vector3.new(0, 3, 0), attrs)
	end
	function ctx.item(zone, floorPos)
		counters.ItemSpawn += 1
		return ctx.mark("ItemSpawn_" .. counters.ItemSpawn, floorPos, { Zone = zone })
	end
	function ctx.wander(zone, floorPos)
		counters.BotWander += 1
		return ctx.mark("BotWander_" .. counters.BotWander, floorPos, { Zone = zone })
	end
	function ctx.npc(role, floorPos)
		ctx.npcRoles[role] = true
		return ctx.mark("NPC_" .. role, floorPos, { Role = role })
	end
	function ctx.guard(n, k, floorPos)
		return ctx.mark(("GuardPath_%d_%d"):format(n, k), floorPos)
	end
	function ctx.ambience(zoneId, pos, minD, maxD)
		local key = ({
			Casino = "Ambient_Hotel",
			CasinoVIP = "Ambient_Hotel",
			CasinoBackRoom = "Ambient_Hotel",
			Beach = "Ambient_Beach",
			Dock = "Ambient_Beach",
			BeachShop = "Ambient_Beach",
			Underground = "Ambient_Underground",
			ElectricalRoom = "Ambient_Underground",
			HiddenRoom = "Ambient_Underground",
			SecurityRoom = "Ambient_Security",
			Detention = "Ambient_Security",
			Pool = "Ambient_Pool",
			ChangingRooms = "Ambient_Pool",
			PoolBar = "Ambient_Pool",
		})[zoneId] or "Ambient_Hotel"
		local def = Sfx[key]
		if not def or not def.id or def.id == "" then
			return nil
		end
		local holder = ambience:FindFirstChild(zoneId)
		if not holder then
			holder = U.newPart("Part")
			holder.Name = zoneId
			holder.Size = Vector3.new(1, 1, 1)
			holder.CFrame = CFrame.new(pos)
			holder.Transparency = 1
			holder.CanCollide = false
			holder.CanQuery = false
			holder.CanTouch = false
			holder.Parent = ambience
		end
		local s = Instance.new("Sound")
		s.Name = key
		s.SoundId = def.id
		s.Volume = def.vol or 0.4
		s.Looped = true
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = minD or 20
		s.RollOffMaxDistance = maxD or 80
		s.Parent = holder
		return s
	end

	------------------------------------------------------------------ build all areas
	local function run(name, fn)
		local ok, err = pcall(fn, ctx)
		if not ok then
			warn("[MapBuilder] " .. name .. " failed: " .. tostring(err))
		end
	end
	run("Exterior", Exterior.build)
	run("Hotel", Hotel.build)
	run("Casino", Casino.build)
	run("East", East.build)
	run("West", West.build)
	run("Beach", Beach.build)
	run("Underground", Underground.build)

	------------------------------------------------------------------ hotel-area ambience + zone parts
	ctx.ambience("Lobby", Vector3.new(0, G + 6, -40), 25, 70)
	ctx.ambience("Reception", Vector3.new(0, G + 6, -85), 12, 40)
	ctx.ambience("HotelBar", Vector3.new(-42, G + 6, -30), 15, 50)
	ctx.ambience("Housekeeping", Vector3.new(-42, G + 6, -75), 15, 45)
	ctx.ambience("SecurityRoom", Vector3.new(40, G + 6, -80), 15, 45)
	ctx.ambience("Detention", Vector3.new(53, G + 6, -93), 8, 30)
	ctx.ambience("GuestRooms", Vector3.new(0, 27, -60), 25, 70)
	ctx.ambience("Balcony", Vector3.new(0, 25, -3), 15, 50)
	ctx.ambience("Rooftop", Vector3.new(0, 42, -60), 30, 90)
	ctx.ambience("Plaza", Vector3.new(0, G + 6, 22), 30, 90)
	ctx.ambience("Beach", Vector3.new(0, 4, 125), 60, 220)
	ctx.ambience("Dock", Vector3.new(100, 6, 160), 25, 80)
	ctx.ambience("BeachShop", Vector3.new(-100, 8, 110), 12, 50)
	ctx.ambience("Underground", Vector3.new(0, UF + 5, -34), 30, 100)
	ctx.ambience("ElectricalRoom", Vector3.new(43, UF + 5, -52), 10, 40)
	ctx.ambience("HiddenRoom", Vector3.new(2, UF + 5, -56), 10, 40)

	local meta = {}
	if ZonesData and ZonesData.byId then
		meta = ZonesData.byId
	end
	for id, boxes in ZONE_BOXES do
		local zm = meta[id] or { name = id, outdoor = false, restricted = false }
		for _, b in boxes do
			U.zone(zones, id, zm, b[1], b[2], b[3], b[4], b[5], b[6])
		end
	end

	------------------------------------------------------------------ BotWander top-up / sanity
	resort.Parent = workspace
	workspace:SetAttribute("MapParts", U.count)
	workspace:SetAttribute("MapReady", true)
	local kinds = {}
	for k, v in U.interactCounts do
		table.insert(kinds, k .. "=" .. v)
	end
	table.sort(kinds)
	print(("MAP BUILT %d parts, %d markers, %.2fs | %s"):format(U.count, U.markerCount, os.clock() - t0, table.concat(kinds, " ")))
	return resort
end

return MapBuilder
