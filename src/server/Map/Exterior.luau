--!nocheck
-- Exterior: Plaza (fountain + spawn), paved paths, promenade, gardens, lamps, palms, direction signs.
local Exterior = {}

function Exterior.build(ctx)
	local U, P = ctx.U, ctx.P
	local C, M = U.C, U.M
	local m = ctx.model("Exterior")
	local G = ctx.G
	local NOCOL = P.NOCOL
	local rgb = Color3.fromRGB

	------------------------------------------------------------------ ground: lawn base + paving
	-- Lawn base: solid Grass slab y 0..LAWN over the whole resort core (hides terrain, no z-fight), holes for
	-- the two underground stair shafts and the pool basin. Paving sits on it from LAWN to G (1.2 thick).
	local LAWN = ctx.LAWN
	U.slab(m, -195, -125, 195, 80, 0, LAWN, ctx.groundHoles, rgb(104, 178, 84), M.Grass) -- granite curb below closes the gap to the carve edge
	local function pave(x1, z1, x2, z2, col, mat, holes)
		U.slab(m, x1, z1, x2, z2, LAWN, G, holes, col or C.paving, mat or M.Slate)
	end
	pave(-60, -10, 60, 50, C.paving, M.Slate) -- plaza
	pave(-10, 50, 10, 80, C.paving2, M.Slate) -- plaza → promenade path
	pave(-90, -100, -60, -10, C.paving, M.Slate, ctx.groundHoles) -- hotel/casino lane (west shaft)
	pave(60, -100, 90, -10, C.paving, M.Slate, ctx.groundHoles) -- hotel/restaurant lane (east shaft)
	pave(-185, -115, 190, -100, C.concrete, M.Concrete) -- service road
	pave(-147, -20, -113, 80, C.paving2, M.Cobblestone) -- shop street
	pave(-185, -20, -147, 2, C.paving, M.Slate)
	pave(-113, -20, -88, 2, C.paving, M.Slate)
	pave(-90, -10, -60, 0, C.paving, M.Slate)
	pave(-88, 0, -60, 80, C.paving, M.Slate)
	pave(-113, 30, -88, 50, C.paving2, M.Cobblestone)
	pave(90, -20, 170, 0, C.paving, M.Slate) -- restaurant terrace
	pave(60, -10, 90, 0, C.paving, M.Slate)
	pave(170, -100, 190, 0, C.concrete, M.Concrete) -- delivery yard
	pave(60, 0, 185, 80, C.white, M.Marble, { ctx.poolHole }) -- pool deck
	-- promenade (beyond the lawn base, sits on terrain)
	U.box(m, -190, 0, 80, 190, G, 95, C.woodLight, M.WoodPlanks)
	-- decorative inlay strips on the plaza (rings + radial)
	U.cyl(m, CFrame.new(0, G + 0.02, 22) * CFrame.Angles(0, 0, math.pi / 2), 0.1, 42, C.paving2, M.Slate, NOCOL)
	U.cyl(m, CFrame.new(0, G + 0.05, 22) * CFrame.Angles(0, 0, math.pi / 2), 0.1, 40.6, C.cream, M.Marble, NOCOL)
	-- promenade edge: low wall + gold rail along the beach side (gaps for ramps)
	local ramps = { -150, -50, 0, 50, 150 }
	local gaps = { -150, -100, -50, 0, 50, 100, 150 }
	local cur = -190
	for _, rx in gaps do
		U.box(m, cur, G, 94.4, rx - 7, G + 1.6, 95.6, C.white, M.SmoothPlastic)
		U.box(m, cur, G + 1.6, 94.2, rx - 7, G + 1.9, 95.8, C.gold, M.Metal)
		cur = rx + 7
	end
	U.box(m, cur, G, 94.4, 190, G + 1.6, 95.6, C.white, M.SmoothPlastic)
	U.box(m, cur, G + 1.6, 94.2, 190, G + 1.9, 95.8, C.gold, M.Metal)
	-- sea wall face below the promenade
	U.box(m, -190, -3, 95, 190, G, 96, C.stone, M.Granite)
	-- garden curb around the raised resort platform
	for _, b in { { -196, -126, 196, -125 }, { -196, -125, -195, 80 }, { 195, -125, 196, 80 }, { -196, 80, -190, 81 }, { 190, 80, 196, 81 } } do
		U.box(m, b[1], -3, b[2], b[3], LAWN + 0.6, b[4], C.stone, M.Granite)
	end
	-- ramps down to the sand (wooden boardwalk wedges)
	for _, rx in ramps do
		local gy = U.groundY(rx, 112, 2)
		local drop = G - (gy - 0.6)
		local run = math.max(10, drop / math.tan(math.rad(18)))
		U.wedge(m, Vector3.new(12, drop, run), CFrame.new(rx, G - drop / 2, 96 + run / 2) * CFrame.Angles(0, math.pi, 0), C.woodLight, M.WoodPlanks)
		U.box(m, rx - 6.6, G - 0.2, 95.6, rx - 6, G + 2.6, 96.6, C.white, M.SmoothPlastic)
		U.box(m, rx + 6, G - 0.2, 95.6, rx + 6.6, G + 2.6, 96.6, C.white, M.SmoothPlastic)
	end

	------------------------------------------------------------------ fountain (plaza centre)
	local FX, FZ = 0, 22
	U.vcyl(m, FX, G, FZ, G + 2.4, 24, C.marble, M.Marble, { Reflectance = 0.08 })
	U.vcyl(m, FX, G + 2.4, FZ, G + 2.8, 25, C.gold, M.Metal, { Reflectance = 0.15 })
	U.vcyl(m, FX, G + 1.6, FZ, G + 2.2, 22, C.turquoise, M.Glass, { Transparency = 0.25, CanCollide = false, Reflectance = 0.1 })
	U.vcyl(m, FX, G, FZ, G + 6.5, 4, C.marble, M.Marble)
	U.vcyl(m, FX, G + 6.5, FZ, G + 7.2, 12, C.marble, M.Marble, { Reflectance = 0.08 })
	U.vcyl(m, FX, G + 7.2, FZ, G + 7.4, 11, C.turquoise, M.Glass, { Transparency = 0.25, CanCollide = false })
	U.vcyl(m, FX, G + 7.2, FZ, G + 11, 2, C.gold, M.Metal, { Reflectance = 0.2 })
	U.vcyl(m, FX, G + 11, FZ, G + 11.6, 6, C.gold, M.Metal, { Reflectance = 0.2 })
	local spout = U.ball(m, Vector3.new(FX, G + 12.4, FZ), 1.6, C.gold, M.Metal, { Reflectance = 0.25 })
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(rgb(200, 245, 255))
	pe.LightEmission = 0.4
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.2) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	pe.Lifetime = NumberRange.new(1.2, 1.6)
	pe.Rate = 60
	pe.Speed = NumberRange.new(9, 12)
	pe.SpreadAngle = Vector2.new(25, 25)
	pe.Acceleration = Vector3.new(0, -24, 0)
	pe.Parent = spout
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local l = U.part(m, Vector3.new(0.6, 0.6, 0.3), CFrame.new(FX + math.cos(a) * 11.5, G + 1.2, FZ + math.sin(a) * 11.5) * CFrame.Angles(0, -a + math.pi / 2, 0), C.neonBlue, M.Neon, NOCOL)
		U.tag(l, "ResortNeon")
	end
	local fl = U.part(m, Vector3.new(1, 1, 1), CFrame.new(FX, G + 1.4, FZ), C.turquoise, M.SmoothPlastic, { Transparency = 1, CanCollide = false })
	U.light(fl, C.turquoise, 18, 1.2)
	-- flower ring around the fountain base
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		U.ball(m, Vector3.new(FX + math.cos(a) * 13.2, G + 0.6, FZ + math.sin(a) * 13.2), 1.6, (k % 2 == 0) and C.pink or C.yellow, M.Grass, NOCOL)
	end

	------------------------------------------------------------------ spawn
	local spawn = U.newPart("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(9, 1, 9)
	spawn.CFrame = CFrame.new(0, G + 0.5, 44)
	spawn.Color = C.marble
	spawn.Material = M.Marble
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Enabled = true
	spawn.Parent = ctx.markers
	U.vcyl(m, 0, G, 44, G + 0.7, 13, C.gold, M.Metal, { Reflectance = 0.15 })
	U.vcyl(m, 0, G + 0.7, 44, G + 0.85, 11.8, C.tealDeep, M.SmoothPlastic, NOCOL)
	for i = 1, 12 do
		local a = (i - 1) / 12 * math.pi * 2
		ctx.mark("SpawnPlaza_" .. i, Vector3.new(FX + math.cos(a) * 19, G, FZ + math.sin(a) * 19))
	end
	ctx.mark("VIPArrive", Vector3.new(-50, G, 20))
	ctx.mark("PoliceArrive", Vector3.new(50, G, 20))

	------------------------------------------------------------------ plaza decor
	for _, x in { -40, -24, 24, 40 } do
		P.palm(m, Vector3.new(x, G - 0.5, -4), 22 + (x % 3), math.rad(80 + x), 2.5)
		U.vcyl(m, x, G - 0.2, -4, G + 0.6, 4.4, C.white, M.Marble)
	end
	for _, x in { -56, -20, 20, 56 } do
		P.streetLamp(m, Vector3.new(x, G, 46))
	end
	for _, x in { -56, 56 } do
		P.streetLamp(m, Vector3.new(x, G, -6))
	end
	for _, s in { { -22, 34, 1 }, { 22, 34, -1 }, { -22, 10, 1 }, { 22, 10, -1 } } do
		P.bench(m, CFrame.lookAt(Vector3.new(s[1], G, s[2]), Vector3.new(0, G, 22)) * CFrame.Angles(0, math.pi, 0))
	end
	for _, z in { 0, 44 } do
		P.planter(m, CFrame.new(-31, G, z), 8, 3, C.cream)
		P.planter(m, CFrame.new(31, G, z), 8, 3, C.cream)
	end
	-- welcome arch over the plaza → promenade path
	for _, x in { -9, 9 } do
		U.column(m, x, G, 52, G + 14, 1.8, C.white, C.gold)
	end
	U.box(m, -10.5, G + 14, 51, 10.5, G + 15.6, 53, C.white, M.Marble)
	U.box(m, -11, G + 15.6, 50.6, 11, G + 16, 53.4, C.gold, M.Metal)
	U.signAt(m, "🌴 RESORT PLAZA 🌴", Vector3.new(0, G + 14.8, 50.9), Vector3.new(0, 0, -1), 16, 1.4, { bg = C.white, fg = C.tealDeep, font = Enum.Font.FredokaOne, transparent = true, thick = 0.1 })
	U.signAt(m, "🏖️ TO THE BEACH 🏖️", Vector3.new(0, G + 14.8, 53.1), Vector3.new(0, 0, 1), 16, 1.4, { bg = C.white, fg = C.tealDeep, font = Enum.Font.FredokaOne, transparent = true, thick = 0.1 })

	-- direction signpost
	local function signpost(pos, entries)
		U.vcyl(m, pos.X, G, pos.Z, G + 11, 0.5, C.woodDark, M.Wood)
		U.ball(m, pos + Vector3.new(0, 11.2, 0), 0.8, C.gold, M.Metal, NOCOL)
		for i, e in entries do
			local dir = (e[2] - pos) * Vector3.new(1, 0, 1)
			dir = dir.Unit
			local y = G + 10.2 - (i - 1) * 1.6
			local cf = CFrame.lookAt(pos + Vector3.new(0, y - pos.Y, 0), pos + Vector3.new(0, y - pos.Y, 0) + dir) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.new(0, 0, 0)
			local board = U.part(m, Vector3.new(0.25, 1.2, 5.4), cf * CFrame.new(0, 0, 0) + dir * 2.8, e[3], M.Wood, NOCOL)
			local o = { fg = C.white, font = Enum.Font.GothamBold, pps = 30, textW = 0.95, textH = 0.8, stroke = 0.5 }
			U.addGui(board, Enum.NormalId.Right, e[1], o)
			U.addGui(board, Enum.NormalId.Left, e[1], o)
		end
	end
	signpost(Vector3.new(8, G, 46), {
		{ "ARCADE", Vector3.new(-130, G, -40), C.red },
		{ "SHOPS", Vector3.new(-130, G, 40), C.coral },
		{ "POOL", Vector3.new(130, G, 40), C.teal },
		{ "RESTAURANT", Vector3.new(130, G, -40), C.woodDark },
		{ "BEACH & DOCK", Vector3.new(0, G, 140), C.sky },
	})

	------------------------------------------------------------------ lawns between plaza and promenade
	for _, side in { -1, 1 } do
		local cx = side * 35
		for k = 0, 2 do
			local x = cx - 16 + k * 16
			P.palm(m, Vector3.new(x, LAWN, 65 + (k % 2) * 6), 20 + k * 2, math.rad(k * 70 + side * 30), 3)
		end
		P.bush(m, Vector3.new(cx - 8, LAWN, 58))
		P.bush(m, Vector3.new(cx + 8, LAWN, 74), 1.2)
		P.bush(m, Vector3.new(cx + 18, LAWN, 58), 0.9)
		P.bush(m, Vector3.new(cx - 20, LAWN, 74), 1.1)
		-- flower beds
		for k = 0, 5 do
			U.ball(m, Vector3.new(cx - 22 + k * 9, LAWN + 0.4, 53), 1.8, ({ C.pink, C.yellow, C.coral })[k % 3 + 1], M.Grass, NOCOL)
		end
	end
	-- promenade lamps + benches + palms in planters
	for x = -180, 180, 30 do
		P.streetLamp(m, Vector3.new(x, G, 93), 11)
	end
	for x = -165, 165, 30 do
		if math.abs(x) > 20 then
			P.bench(m, CFrame.lookAt(Vector3.new(x, G, 92), Vector3.new(x, G, 200)) * CFrame.Angles(0, math.pi, 0), C.woodLight)
		end
	end
	-- side gardens (hotel ↔ casino / restaurant) with palms
	for _, z in { -90, -70, -30 } do
		P.palm(m, Vector3.new(-75, G - 0.5, z), 20, math.rad(z), 2)
		U.vcyl(m, -75, G - 0.2, z, G + 0.6, 4.4, C.white, M.Marble)
		P.palm(m, Vector3.new(75, G - 0.5, z), 21, math.rad(-z), 2)
		U.vcyl(m, 75, G - 0.2, z, G + 0.6, 4.4, C.white, M.Marble)
	end
	for _, x in { -150, -60, -20, 60, 150, 180 } do
		P.streetLamp(m, Vector3.new(x, G, -113.5), 10)
	end
	-- back-of-house dumpster area (search + hide)
	local dump = U.box(m, 182, G, -96, 188, G + 5, -88, rgb(40, 110, 70), M.Metal)
	U.box(m, 181.8, G + 5, -96.2, 188.2, G + 5.4, -87.8, rgb(30, 80, 50), M.Metal, NOCOL)
	U.interact(dump, "Hide", "H_Dumpster", "Kitchen", "Dumpster")
	local bins = P.crate(m, CFrame.new(-60, G, -108), 3, C.wood)
	U.interact(bins, "Search", "S_BackCrates", "Plaza", "Hotel Supply Crates")
	ctx.wander("Plaza", Vector3.new(-14, G, 30))
	ctx.wander("Plaza", Vector3.new(16, G, 6))
	ctx.wander("Plaza", Vector3.new(0, G, 70))
	ctx.item("Plaza", Vector3.new(-28, G, 22))
	ctx.guard(3, 1, Vector3.new(20, G, 46))
	ctx.guard(3, 2, Vector3.new(80, G, 40))
	ctx.guard(3, 3, Vector3.new(125, G, 14))
	ctx.guard(3, 4, Vector3.new(120, G, -6))
	ctx.guard(3, 5, Vector3.new(85, G, -30))
	ctx.guard(3, 6, Vector3.new(40, G, 0))
end

return Exterior
