--!nocheck
-- East side: Restaurant (dining, private dining, kitchen + freezer, staff entrance, delivery) x[90,170] z[-100,-20]
-- and Pool area (pool, loungers, lifeguard chair, changing rooms, pool bar, equipment shed) x[60,185] z[0,80].
local East = {}

function East.build(ctx)
	local U, P = ctx.U, ctx.P
	local C, M = U.C, U.M
	local G = ctx.G
	local NOCOL = P.NOCOL
	local rgb = Color3.fromRGB
	local m = ctx.model("Restaurant")

	------------------------------------------------------------------ RESTAURANT shell
	local X1, X2, Z1, Z2 = 90, 170, -100, -20
	local H = 16
	local TOP = G + H
	local WALL = rgb(252, 244, 232)
	local EXT = { frame = C.woodDark, glass = C.glass, mullion = 4 }
	local INT = { frame = C.white, base = C.woodDark, crown = C.white }
	local KIT = { frame = C.steel }
	local function win(c, w, b, h)
		return { c = c, w = w or 8, b = b or 2, h = h or 10, glass = true }
	end
	U.box(m, X1, 0, -70, 145, G, Z2, C.woodLight, M.WoodPlanks) -- dining
	U.box(m, X1, 0, Z1, 120, G, -70, C.woodDark, M.WoodPlanks) -- private dining
	U.box(m, 120, 0, Z1, X2, G, -70, rgb(222, 222, 216), M.Slate) -- kitchen
	U.box(m, 145, 0, -70, X2, G, Z2, rgb(222, 222, 216), M.Slate) -- kitchen + freezer
	U.skirt(m, X1 - 0.6, Z1 - 0.6, X2 + 0.6, Z2 + 0.6)
	-- checkerboard accent in front of the pass
	for k = 0, 7 do
		U.box(m, 121 + k * 3, G, -73.9 + 0, 124 + k * 3, G + 0.05, -70.9, (k % 2 == 0) and C.black or C.white, M.Marble, { CanCollide = false })
	end
	U.wall(m, X1, Z2, X2, Z2, G, H, 1.2, WALL, M.SmoothPlastic, { win(97, 8), win(107, 8), { c = 117, w = 12, h = 11 }, win(127, 8), win(137, 8) }, EXT)
	U.wall(m, X1, Z1, X2, Z1, G, H, 1.2, WALL, M.SmoothPlastic, { win(105, 10, 4, 6), { c = 150, w = 12, h = 11 } }, EXT)
	U.wall(m, X1, Z1, X1, Z2, G, H, 1.2, WALL, M.SmoothPlastic, { win(-30), win(-42), win(-54), win(-85, 10, 4, 6) }, EXT)
	U.wall(m, X2, Z1, X2, Z2, G, H, 1.2, WALL, M.SmoothPlastic, { { c = -85, w = 8, h = 11 } }, KIT)
	-- interior
	U.wall(m, X1, -70, 145, -70, G, H, 1, WALL, M.SmoothPlastic, { { c = 105, w = 8, h = 11 }, { c = 132, w = 14, h = 4.4, b = 3.0 } }, INT)
	U.wall(m, 120, Z1, 120, -70, G, H, 1, WALL, M.SmoothPlastic, {}, INT)
	U.wall(m, 145, -70, 145, Z2, G, H, 1, WALL, M.SmoothPlastic, { { c = -58, w = 8, h = 11 } }, INT)
	U.wall(m, 145, -45, X2, -45, G, H, 1, C.steel, M.DiamondPlate, { { c = 157, w = 8, h = 11 } }, KIT)
	-- roof + parapet + awning
	U.box(m, X1 - 0.6, TOP, Z1 - 0.6, X2 + 0.6, TOP + 1, Z2 + 0.6, C.white, M.SmoothPlastic)
	U.box(m, X1 - 1, TOP + 1, Z2 - 0.4, X2 + 1, TOP + 3, Z2 + 0.6, WALL, M.SmoothPlastic)
	U.box(m, X1 - 1.2, TOP + 3, Z2 - 0.6, X2 + 1.2, TOP + 3.4, Z2 + 0.8, C.gold, M.Metal)
	local rsign = CFrame.lookAt(Vector3.new(117, TOP + 1.8, Z2 + 0.7), Vector3.new(117, TOP + 1.8, 10))
	U.sign(m, "LA PALMA  •  RESTAURANT", rsign, 34, 2.4, { bg = WALL, fg = C.tealDeep, font = Enum.Font.FredokaOne, transparent = true, thick = 0.1, pps = 20 })
	-- striped awning over the terrace door
	for k = 0, 7 do
		local x = 107 + k * 2.5 + 1.25
		U.part(m, Vector3.new(2.5, 0.2, 6.5), CFrame.new(x, G + 13.2, Z2 + 3) * CFrame.Angles(math.rad(-18), 0, 0), (k % 2 == 0) and C.teal or C.white, M.Fabric, NOCOL)
	end

	------------------------------------------------------------------ dining room
	for i, pos in { Vector3.new(100, G, -32), Vector3.new(100, G, -52), Vector3.new(114, G, -42), Vector3.new(128, G, -32), Vector3.new(128, G, -52), Vector3.new(114, G, -60) } do
		P.diningSet(m, pos, 4, C.white, (i % 2 == 0) and C.teal or C.coral)
	end
	-- host stand (Food) + menu board
	local host = P.counter(m, 136, -36, 142, -32, G, 3.6, C.woodDark, C.marble)
	local hostTop = U.box(m, 137, G + 3.6, -35.5, 141, G + 3.8, -32.5, C.gold, M.Metal, NOCOL)
	U.interact(hostTop, "Food", "Food_Restaurant", "Restaurant", "Order Food")
	local _ = host
	local rphone = P.phone(m, Vector3.new(140.5, G + 3.8, -35), 0)
	U.interact(rphone, "Phone", "Phone_Restaurant", "Restaurant", "Host Phone")
	U.signAt(m, "TODAY: 🍕 Pizza  🦞 Lobster  🍹 Mango Punch", Vector3.new(144.35, G + 9, -32), Vector3.new(-1, 0, 0), 9, 4, { bg = C.black, fg = C.white, font = Enum.Font.GothamBold, frame = C.woodDark })
	for _, z in { -30, -50 } do
		P.chandelier(m, Vector3.new(114, TOP, z), 2.6)
	end
	for _, c in { { 92.5, -22.5 }, { 142.5, -22.5 }, { 92.5, -67.5 } } do
		P.plant(m, Vector3.new(c[1], G, c[2]), 1)
	end
	U.picture(m, CFrame.lookAt(Vector3.new(90.7, G + 9, -42), Vector3.new(110, G + 9, -42)), 5, 4)
	local rcam = P.securityCam(m, Vector3.new(144, G + 14, -22), Vector3.new(105, G, -60))
	U.interact(rcam, "Camera", "Cam_Restaurant", "Restaurant", "Security Camera", { CamId = "Cam_Restaurant" })
	U.signAt(m, "KITCHEN — STAFF", Vector3.new(144.35, G + 12.6, -58), Vector3.new(-1, 0, 0), 7, 1.2, { bg = C.steel, fg = C.black, font = Enum.Font.GothamBold })
	ctx.item("Restaurant", Vector3.new(121, G, -24))
	ctx.wander("Restaurant", Vector3.new(121, G, -46))
	ctx.wander("Restaurant", Vector3.new(107, G, -24))

	------------------------------------------------------------------ private dining
	U.door(m, "x", 105, -70, G, "PrivateDining", "D_PrivateDining", "code", "Private Dining", { inside = "-", code = "1955", text = "PRIVATE", color = C.woodDark })
	U.rug(m, 93, -97, 117, -74, G, C.redDark, C.gold)
	U.box(m, 99, G + 2.7, -91, 111, G + 3, -81, C.woodDark, M.Wood)
	for _, o in { { 99.6, -90.4 }, { 110.4, -90.4 }, { 99.6, -81.6 }, { 110.4, -81.6 } } do
		U.vcyl(m, o[1], G, o[2], G + 2.7, 0.6, C.woodDark, M.Wood)
	end
	for k = 0, 2 do
		P.chair(m, CFrame.lookAt(Vector3.new(101 + k * 4, G, -93.4), Vector3.new(101 + k * 4, G, -86)), C.red)
		P.chair(m, CFrame.lookAt(Vector3.new(101 + k * 4, G, -78.6), Vector3.new(101 + k * 4, G, -86)), C.red)
	end
	for k = 0, 2 do
		U.vcyl(m, 101 + k * 4, G + 3, -86, G + 3.1, 1.2, C.white, M.SmoothPlastic, NOCOL)
	end
	local candle = U.vcyl(m, 105, G + 3, -86, G + 4.4, 0.3, C.cream, M.SmoothPlastic, NOCOL)
	U.light(candle, rgb(255, 190, 120), 10, 1)
	local side = P.cabinet(m, CFrame.lookAt(Vector3.new(118, G, -86), Vector3.new(110, G, -86)), 6, 3, 2, C.woodDark)
	U.interact(side, "Search", "S_PDSideboard", "PrivateDining", "Sideboard", { Loot = "SecretLetter" })
	P.chandelier(m, Vector3.new(105, TOP, -86), 2.4)
	U.picture(m, CFrame.lookAt(Vector3.new(105, G + 9, -99.3), Vector3.new(105, G + 9, -90)), 7, 4)
	ctx.item("PrivateDining", Vector3.new(95, G, -76))

	------------------------------------------------------------------ kitchen
	U.door(m, "z", 145, -58, G, "Kitchen", "D_KitchenStaff", "none", "Kitchen (staff)", { color = C.steel, mat = M.Metal, text = "STAFF" })
	-- pass counter in the glass gap of the -70 wall
	P.counter(m, 125, -71.4, 139, -68.6, G, 3.4, C.steel, C.steel)
	for k = 0, 2 do
		U.vcyl(m, 128 + k * 4, G + 3.4, -70, G + 3.5, 1.4, C.white, M.SmoothPlastic, NOCOL)
	end
	-- cooking line along the south wall
	for k = 0, 2 do
		P.stove(m, CFrame.lookAt(Vector3.new(126 + k * 5, G, -97.8), Vector3.new(126 + k * 5, G, -90)))
	end
	P.counter(m, 142, -99.4, 147, -96, G, 3.4, C.steel, C.steel)
	-- prep island
	P.counter(m, 128, -86, 142, -80, G, 3.4, C.steel, C.white)
	for k = 0, 3 do
		U.box(m, 129 + k * 3.2, G + 3.4, -84, 131 + k * 3.2, G + 3.5, -82, C.woodLight, M.Wood, NOCOL)
	end
	-- hanging pans rack
	U.box(m, 128, G + 10.6, -83.3, 142, G + 10.9, -82.7, C.steel, M.Metal, NOCOL)
	for k = 0, 5 do
		U.cyl(m, CFrame.new(129 + k * 2.4, G + 9.4, -83) * CFrame.Angles(0, math.pi / 2, 0), 0.2, 1.6, rgb(184, 115, 51), M.Metal, NOCOL)
	end
	-- fridges
	local fr1 = P.fridge(m, CFrame.lookAt(Vector3.new(167.6, G, -78), Vector3.new(160, G, -78)))
	U.interact(fr1, "Search", "S_KitchenFridge", "Kitchen", "Fridge", { Loot = "Pizza" })
	P.fridge(m, CFrame.lookAt(Vector3.new(167.6, G, -74), Vector3.new(160, G, -74)))
	local pantry = P.cabinet(m, CFrame.lookAt(Vector3.new(122.4, G, -78), Vector3.new(130, G, -78)), 6, 7, 2.4, C.white, C.steel)
	U.interact(pantry, "Search", "S_KitchenPantry", "Kitchen", "Pantry")
	local bin = U.vcyl(m, 148, G, -66, G + 3.6, 3, rgb(60, 120, 80), M.SmoothPlastic)
	U.interact(bin, "Hide", "H_KitchenBin", "Kitchen", "Big Trash Bin")
	local clip = U.part(m, Vector3.new(1.2, 1.6, 0.1), CFrame.lookAt(Vector3.new(145.6, G + 6, -63), Vector3.new(150, G + 6, -63)), C.paper, M.SmoothPlastic, NOCOL)
	U.interact(clip, "Note", "Note_PrivateDiningCode", "Kitchen", "Clipboard", { Text = "Kitchen clipboard: \"VIP dinner tonight. Private Dining door code is 1955. — Chef\"" })
	-- staff entrance (east) + delivery door (south)
	U.door(m, "z", 170, -85, G, "Kitchen", "D_StaffEntrance", "none", "Staff Entrance", { color = C.steel, mat = M.Metal })
	U.door(m, "x", 150, -100, G, "Kitchen", "D_Delivery", "key:MasterKey", "Delivery Door", { inside = "+", color = rgb(170, 176, 182), mat = M.DiamondPlate, w = 11.6, text = "DELIVERIES" })
	local dcr = P.crate(m, CFrame.new(176, G, -60), 3.4, C.woodLight)
	U.interact(dcr, "Search", "S_DeliveryCrates", "Kitchen", "Delivery Crates")
	P.crate(m, CFrame.new(176, G + 3.4, -60) * CFrame.Angles(0, 0.4, 0), 2.6, C.wood)
	P.crate(m, CFrame.new(180, G, -64) * CFrame.Angles(0, 0.2, 0), 3, C.wood)
	-- delivery van
	local vcf = CFrame.new(181, G, -30)
	U.rel(m, vcf, 0, 4.4, 0, 8, 6.6, 16, C.white, M.SmoothPlastic)
	U.rel(m, vcf, 0, 3.4, -9.5, 8, 4.6, 3, C.white, M.SmoothPlastic)
	U.rel(m, vcf, 0, 5.2, -10.6, 7, 2, 0.2, C.glass, M.Glass, { Transparency = 0.3 })
	for _, o in { { -4, -6 }, { 4, -6 }, { -4, 6 }, { 4, 6 } } do
		U.cyl(m, vcf * CFrame.new(o[1], 1.4, o[2]), 1, 2.8, C.black, M.SmoothPlastic)
	end
	U.sign(m, "🐟 FRESH SEAFOOD CO.", vcf * CFrame.new(-4.05, 5, 0) * CFrame.Angles(0, -math.pi / 2, 0), 12, 3, { bg = C.white, fg = C.tealDeep, font = Enum.Font.FredokaOne, transparent = true, thick = 0.1 })
	-- freezer
	U.door(m, "x", 157, -45, G, "Kitchen", "D_Freezer", "none", "Freezer", { color = C.steel, mat = M.DiamondPlate, text = "❄ FREEZER" })
	U.box(m, 145.5, G, -44.5, 169.4, G + 0.1, -20.6, rgb(210, 236, 250), M.Ice, { CanCollide = false })
	for k = 0, 2 do
		U.box(m, 166, G, -42 + k * 7, 169.4, G + 9, -37 + k * 7, C.steel, M.Metal)
		for r = 0, 2 do
			U.box(m, 165.8, G + 1 + r * 2.8, -41.6 + k * 7, 166, G + 2.6 + r * 2.8, -37.4 + k * 7, rgb(200, 230, 250), M.Ice, NOCOL)
		end
	end
	local fcr = P.crate(m, CFrame.new(150, G, -24), 3, rgb(200, 220, 235))
	U.interact(fcr, "Search", "S_FreezerCrate", "Kitchen", "Frozen Crate")
	local fl = U.part(m, Vector3.new(2, 0.3, 2), CFrame.new(157, TOP - 0.2, -32), rgb(200, 235, 255), M.Neon, NOCOL)
	U.tag(fl, "ResortNeon")
	U.light(fl, rgb(190, 225, 255), 20, 1)
	for _, x in { 130, 155 } do
		U.downlight(m, x, TOP, -85, 24, 0.9)
	end
	U.downlight(m, 157, TOP, -58, 18, 0.8)
	local kcam = P.securityCam(m, Vector3.new(121, G + 14, -72), Vector3.new(150, G, -90))
	U.interact(kcam, "Camera", "Cam_Kitchen", "Kitchen", "Security Camera", { CamId = "Cam_Kitchen" })
	-- fire spot (disabled fire + smoke under Markers.FireSpot)
	local fire = ctx.mark("FireSpot", Vector3.new(131, G, -95))
	local f = Instance.new("Fire")
	f.Enabled = false
	f.Size = 8
	f.Heat = 12
	f.Parent = fire
	local smoke = Instance.new("ParticleEmitter")
	smoke.Enabled = false
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(rgb(90, 90, 90))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 8) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(3, 5)
	smoke.Rate = 20
	smoke.Speed = NumberRange.new(4, 6)
	smoke.Parent = fire
	ctx.npc("Chef", Vector3.new(132, G, -90))
	ctx.item("Kitchen", Vector3.new(160, G, -90))
	ctx.item("Kitchen", Vector3.new(156, G, -30))
	ctx.wander("Kitchen", Vector3.new(150, G, -80))

	------------------------------------------------------------------ terrace (umbrella tables)
	for i, x in { 98, 106, 130, 150 } do
		local pos = Vector3.new(x, G, -10)
		P.roundTable(m, pos, 4, 3, C.white)
		P.chair(m, CFrame.lookAt(pos + Vector3.new(-3.4, 0, 0), pos), C.white)
		P.chair(m, CFrame.lookAt(pos + Vector3.new(3.4, 0, 0), pos), C.white)
		P.umbrella(m, pos + Vector3.new(0, 3, 0), (i % 2 == 0) and C.teal or C.coral, C.white, 6.5, 4)
	end
	P.planter(m, CFrame.new(130, G, -1.6), 26, 2.4, C.white)

	------------------------------------------------------------------ POOL
	local pm = ctx.model("Pool")
	local PX1, PZ1, PX2, PZ2 = 100, 22, 150, 62
	local floorTop = G - 4.2
	-- basin floor + footing, walls tiled
	U.box(pm, PX1, -3, PZ1, PX2, floorTop, PZ2, C.poolTile, M.Slate)
	local wallT = 0.8
	U.box(pm, PX1, floorTop, PZ1, PX2, G, PZ1 + wallT, C.poolTile, M.Slate)
	U.box(pm, PX1, floorTop, PZ2 - wallT, PX2, G, PZ2, C.poolTile, M.Slate)
	U.box(pm, PX1, floorTop, PZ1 + wallT, PX1 + wallT, G, PZ2 - wallT, C.poolTile, M.Slate)
	U.box(pm, PX2 - wallT, floorTop, PZ1 + wallT, PX2, G, PZ2 - wallT, C.poolTile, M.Slate)
	-- mosaic lane lines on the floor
	for k = 1, 3 do
		U.box(pm, PX1 + 4, floorTop, PZ1 + k * 10 - 0.5, PX2 - 4, floorTop + 0.06, PZ1 + k * 10 + 0.5, C.tealDeep, M.Slate, NOCOL)
	end
	-- steps in (west end) — 5 steps of 0.84
	U.stairs(pm, Vector3.new(PX1 + wallT + 7, floorTop, 42), Vector3.new(-1, 0, 0), 10, 5, 0.84, 1.4, C.white, M.Marble)
	-- water
	U.box(pm, PX1 + wallT, floorTop, PZ1 + wallT, PX2 - wallT, G - 0.7, PZ2 - wallT, C.turquoise, M.Glass, {
		Transparency = 0.45,
		CanCollide = false,
		CastShadow = false,
		Reflectance = 0.15,
	}).Name = "PoolWater"
	-- coping
	for _, b in { { PX1 - 1.4, PZ1 - 1.4, PX2 + 1.4, PZ1 }, { PX1 - 1.4, PZ2, PX2 + 1.4, PZ2 + 1.4 }, { PX1 - 1.4, PZ1, PX1, PZ2 }, { PX2, PZ1, PX2 + 1.4, PZ2 } } do
		U.box(pm, b[1], G, b[2], b[3], G + 0.25, b[4], C.white, M.Marble, { Reflectance = 0.06 })
	end
	for k = 0, 9 do
		local l = U.part(pm, Vector3.new(1.2, 0.8, 0.2), CFrame.new(PX1 + 5 + k * 4.4, floorTop + 2, PZ1 + wallT + 0.1), C.white, M.Neon, NOCOL)
		U.tag(l, "ResortNeon")
		if k % 3 == 0 then
			U.light(l, C.turquoise, 16, 1)
		end
	end
	-- ladder at east end
	for _, z in { 40, 44 } do
		U.beam(pm, Vector3.new(PX2 - wallT - 0.4, floorTop + 1, z), Vector3.new(PX2 - wallT - 0.4, G + 2.4, z), 0.3, C.steel, M.Metal)
		U.beam(pm, Vector3.new(PX2 - wallT - 0.4, G + 2.4, z), Vector3.new(PX2 + 0.6, G + 2.4, z), 0.3, C.steel, M.Metal)
	end
	-- floating ring + inflatable
	U.part(pm, Vector3.new(0.8, 4, 4), CFrame.new(128, G - 0.6, 35) * CFrame.Angles(0, 0, math.pi / 2), C.coral, M.SmoothPlastic, { CanCollide = false, Shape = Enum.PartType.Cylinder })
	U.part(pm, Vector3.new(0.9, 2.2, 2.2), CFrame.new(128, G - 0.55, 35) * CFrame.Angles(0, 0, math.pi / 2), C.turquoise, M.Glass, { CanCollide = false, Shape = Enum.PartType.Cylinder, Transparency = 0.4 })
	U.part(pm, Vector3.new(0.8, 3.6, 3.6), CFrame.new(116, G - 0.6, 52) * CFrame.Angles(0, 0, math.pi / 2), C.yellow, M.SmoothPlastic, { CanCollide = false, Shape = Enum.PartType.Cylinder })
	-- loungers + umbrellas along both long sides
	for k = 0, 5 do
		local x = 104 + k * 8.5
		P.lounger(pm, CFrame.lookAt(Vector3.new(x, G, 14.5), Vector3.new(x, G, 30)) * CFrame.Angles(0, math.pi, 0), (k % 2 == 0) and C.teal or C.coral)
		P.lounger(pm, CFrame.lookAt(Vector3.new(x, G, 69.5), Vector3.new(x, G, 50)) * CFrame.Angles(0, math.pi, 0), (k % 2 == 0) and C.coral or C.yellow)
		if k % 2 == 1 then
			P.umbrella(pm, Vector3.new(x + 4.25, G, 11), C.teal, C.white)
			P.umbrella(pm, Vector3.new(x + 4.25, G, 73), C.coral, C.white)
		end
	end
	local bag = U.box(pm, 108, G, 7.6, 110.4, G + 1.8, 9, C.coral, M.Fabric)
	U.interact(bag, "Search", "S_PoolBeachBag", "Pool", "Beach Bag", { Loot = "PhotoCamera" })
	-- lifeguard chair
	local lx, lz = 155, 42
	for _, o in { { -1.6, -1.6 }, { 1.6, -1.6 }, { -1.6, 1.6 }, { 1.6, 1.6 } } do
		U.beam(pm, Vector3.new(lx + o[1] * 1.3, G, lz + o[2] * 1.3), Vector3.new(lx + o[1] * 0.8, G + 7, lz + o[2] * 0.8), 0.4, C.white, M.Wood)
	end
	U.box(pm, lx - 2, G + 7, lz - 2, lx + 2, G + 7.4, lz + 2, C.white, M.Wood)
	U.box(pm, lx - 1.6, G + 7.4, lz + 1.2, lx + 1.6, G + 10.4, lz + 1.6, C.red, M.Wood)
	P.umbrella(pm, Vector3.new(lx, G + 7.4, lz + 1.6), C.red, C.white, 5, 3)
	U.signAt(pm, "LIFEGUARD", Vector3.new(lx, G + 5.5, lz - 1.8), Vector3.new(-1, 0, 0), 3, 0.8, { bg = C.red, fg = C.white, font = Enum.Font.GothamBold, double = true })
	ctx.npc("Lifeguard", Vector3.new(lx - 4, G, lz - 4))
	-- palms around the deck
	for _, c in { { 82, 8 }, { 82, 74 }, { 96, 76 }, { 156, 76 }, { 156, 8 }, { 92, 30 }, { 92, 54 } } do
		P.palm(pm, Vector3.new(c[1], G - 0.5, c[2]), 19 + (c[1] % 5), math.rad(c[1] * 3 + c[2]), 3)
		U.vcyl(pm, c[1], G - 0.2, c[2], G + 0.6, 4.4, C.white, M.Marble)
	end
	local pcam = P.securityCam(pm, Vector3.new(158, G + 12, 4), Vector3.new(125, G, 45))
	U.vcyl(pm, 158, G, 4, G + 12, 0.5, C.darkSteel, M.Metal)
	U.interact(pcam, "Camera", "Cam_Pool", "Pool", "Security Camera", { CamId = "Cam_Pool" })
	U.signAt(pm, "🏊 INFINITY POOL", Vector3.new(90, G + 8, 4), Vector3.new(-1, 0, -0.3).Unit, 10, 2, { bg = C.teal, fg = C.white, font = Enum.Font.FredokaOne, double = true, frame = C.gold })
	U.vcyl(pm, 90, G, 4.6, G + 7, 0.4, C.white, M.Metal)
	ctx.item("Pool", Vector3.new(96, G, 66))
	ctx.item("Pool", Vector3.new(152, G, 20))
	ctx.wander("Pool", Vector3.new(96, G, 18))
	ctx.wander("Pool", Vector3.new(125, G, 18))
	ctx.wander("Pool", Vector3.new(140, G, 67))

	------------------------------------------------------------------ changing rooms x[160,182] z[6,36]
	local cm = ctx.model("ChangingRooms")
	local CX1, CX2, CZ1, CZ2 = 162, 182, 6, 36
	local CH = 11
	U.box(cm, CX1, G, CZ1, CX2, G + 0.2, CZ2, C.white, M.Slate)
	U.wall(cm, CX1, CZ1, CX2, CZ1, G, CH, 0.8, C.mint, M.SmoothPlastic, {}, {})
	U.wall(cm, CX1, CZ2, CX2, CZ2, G, CH, 0.8, C.mint, M.SmoothPlastic, {}, {})
	U.wall(cm, CX2, CZ1, CX2, CZ2, G, CH, 0.8, C.mint, M.SmoothPlastic, { { c = 21, w = 10, h = 2, b = 7.4, glass = true } }, {})
	U.wall(cm, CX1, CZ1, CX1, CZ2, G, CH, 0.8, C.mint, M.SmoothPlastic, { { c = 13, w = 8, h = 10.4 }, { c = 29, w = 8, h = 10.4 } }, { frame = C.white })
	U.wall(cm, CX1, 21, CX2, 21, G, CH, 0.6, C.white, M.SmoothPlastic, {}, {})
	U.box(cm, CX1 - 0.6, G + CH, CZ1 - 0.6, CX2 + 0.6, G + CH + 0.8, CZ2 + 0.6, C.white, M.SmoothPlastic)
	U.door(cm, "z", CX1, 13, G + 0.2, "ChangingRooms", "D_ChangingA", "none", "Changing Room A", { color = C.white, mat = M.SmoothPlastic, text = "A", h = 10.2 })
	U.door(cm, "z", CX1, 29, G + 0.2, "ChangingRooms", "D_ChangingB", "none", "Changing Room B", { color = C.white, mat = M.SmoothPlastic, text = "B", h = 10.2 })
	U.signAt(cm, "CHANGING ROOMS", Vector3.new(CX1 - 0.5, G + CH - 1.2, 21), Vector3.new(-1, 0, 0), 12, 1.2, { bg = C.teal, fg = C.white, font = Enum.Font.GothamBold })
	for i, zc in { 9, 32 } do
		-- booth with curtain (Hide)
		local s = (i == 1) and 1 or -1
		U.box(cm, 176, G + 0.2, zc + s * 2.4, 181.6, G + 8, zc + s * 2.7, C.white, M.SmoothPlastic)
		U.box(cm, 175.7, G + 8, zc - 2.6, 176.1, G + 8.3, zc + 2.6, C.gold, M.Metal, NOCOL)
		local curtain = U.box(cm, 175.8, G + 1, zc - 2.4, 176.05, G + 8, zc + 2.4, ({ C.coral, C.teal })[i], M.Fabric, { CanCollide = false })
		U.interact(curtain, "Hide", "H_ChangingBooth" .. i, "ChangingRooms", "Changing Booth")
		local bz1 = (i == 1) and 18.6 or 21.6
		U.box(cm, 164, G + 0.2, bz1, 170, G + 2.2, bz1 + 1.8, C.woodLight, M.Wood)
		local lk = U.box(cm, 172, G + 0.2, (i == 1) and 18 or 23.4, 175.6, G + 7.8, (i == 1) and 20.4 or 26, rgb(110, 170, 200), M.Metal)
		U.interact(lk, "Search", "S_PoolLocker" .. i, "ChangingRooms", "Locker", i == 1 and { Loot = "StaffUniform" } or nil)
		U.downlight(cm, 172, G + CH, zc + (i == 1 and 4 or -4), 16, 0.7)
	end
	ctx.item("ChangingRooms", Vector3.new(168, G + 0.2, 14))
	local dnote = U.part(cm, Vector3.new(1.2, 0.06, 0.9), CFrame.new(166, G + 2.23, 19.5) * CFrame.Angles(0, 0.3, 0), C.paper, M.SmoothPlastic, NOCOL)
	U.interact(dnote, "Note", "Note_CasinoCode", "ChangingRooms", "Forgotten Note", { Text = "An arcade worker's note left on the bench: \"Back room keypad changed to 8264. Don't tell the guests!\"" })
	ctx.wander("ChangingRooms", Vector3.new(166, G + 0.2, 28))

	------------------------------------------------------------------ pool bar x[160,182] z[46,74] — open tiki bar
	local bm = ctx.model("PoolBar")
	local bx, bz = 171, 60
	U.box(bm, bx - 11, G, bz - 13, bx + 11, G + 0.3, bz + 13, C.woodLight, M.WoodPlanks)
	-- U-shaped bar
	P.counter(bm, bx - 6, bz - 7, bx - 3, bz + 7, G + 0.3, 3.8, rgb(150, 110, 70), C.woodLight)
	P.counter(bm, bx - 3, bz - 7, bx + 6, bz - 4, G + 0.3, 3.8, rgb(150, 110, 70), C.woodLight)
	P.counter(bm, bx - 3, bz + 4, bx + 6, bz + 7, G + 0.3, 3.8, rgb(150, 110, 70), C.woodLight)
	local ptop = U.box(bm, bx - 5.8, G + 4.1, bz - 2, bx - 3.2, G + 4.3, bz + 2, C.gold, M.Metal, NOCOL)
	U.interact(ptop, "Food", "Food_PoolBar", "PoolBar", "Order a Smoothie")
	for _, c in { { -9, -11 }, { 9, -11 }, { -9, 11 }, { 9, 11 } } do
		U.vcyl(bm, bx + c[1], G + 0.3, bz + c[2], G + 11, 1, C.trunk, M.Wood)
	end
	-- thatched pyramid roof (4 wedges) + peak
	-- tiered round thatch roof
	for k, d in { 30, 24, 17, 10, 4 } do
		local y0 = G + 11 + (k - 1) * 1.3
		U.vcyl(bm, bx, y0, bz, y0 + 1.5, d, (k % 2 == 0) and rgb(186, 150, 84) or rgb(206, 170, 100), M.Grass)
	end
	U.box(bm, bx - 13, G + 10.6, bz - 13, bx + 13, G + 11, bz + 13, rgb(170, 130, 70), M.Wood)
	for k = 0, 3 do
		P.stool(bm, Vector3.new(bx - 8, G + 0.3, bz - 6 + k * 4), C.teal)
	end
	U.box(bm, bx + 7.5, G + 0.3, bz - 6, bx + 9.5, G + 3.5, bz + 6, C.woodDark, M.Wood)
	for k = 0, 5 do
		U.vcyl(bm, bx + 8.5, G + 3.5, bz - 5 + k * 2, G + 5, 0.6, ({ C.yellow, C.coral, C.mint, C.pink })[k % 4 + 1], M.Glass, NOCOL)
	end
	local tikiSign = U.part(bm, Vector3.new(0.3, 2, 10), CFrame.new(bx - 13.2, G + 9.6, bz), C.yellow, M.Neon, NOCOL)
	U.tag(tikiSign, "ResortNeon")
	U.addGui(tikiSign, Enum.NormalId.Left, "🍹 TIKI POOL BAR", { fg = C.tealDeep, font = Enum.Font.FredokaOne, pps = 25 })
	U.box(bm, bx - 13.1, G + 9.4, bz - 0.2, bx - 12.9, G + 10.6, bz + 0.2, C.woodDark, M.Wood, NOCOL)
	local tl = U.part(bm, Vector3.new(1, 1, 1), CFrame.new(bx, G + 10, bz), C.yellow, M.SmoothPlastic, { Transparency = 1, CanCollide = false })
	U.light(tl, rgb(255, 210, 150), 22, 1)
	ctx.item("PoolBar", Vector3.new(bx - 9.5, G + 0.3, bz + 9))
	ctx.wander("PoolBar", Vector3.new(bx - 10, G, bz))

	------------------------------------------------------------------ pool equipment shed x[60,74] z[60,76] (west of deck)
	local sx, sz = 66, 68
	U.box(pm, sx - 5, G, sz - 6, sx + 5, G + 0.2, sz + 6, C.concrete, M.Concrete)
	U.wall(pm, sx - 5, sz - 6, sx + 5, sz - 6, G, 12, 0.6, C.white, M.WoodPlanks, {}, {})
	U.wall(pm, sx - 5, sz + 6, sx + 5, sz + 6, G, 12, 0.6, C.white, M.WoodPlanks, {}, {})
	U.wall(pm, sx - 5, sz - 6, sx - 5, sz + 6, G, 12, 0.6, C.white, M.WoodPlanks, {}, {})
	U.wall(pm, sx + 5, sz - 6, sx + 5, sz + 6, G, 12, 0.6, C.white, M.WoodPlanks, { { c = sz, w = 7.6, h = 10.6 } }, { frame = C.teal })
	U.box(pm, sx - 6, G + 12, sz - 7, sx + 6, G + 12.4, sz + 7, C.teal, M.SmoothPlastic)
	U.wedge(pm, Vector3.new(14, 2, 12), CFrame.new(sx, G + 13.4, sz) * CFrame.Angles(0, -math.pi / 2, 0), C.teal, M.SmoothPlastic)
	U.door(pm, "z", sx + 5, sz, G + 0.2, "Pool", "D_PoolShed", "key:MasterKey", "Pool Equipment", { inside = "-", w = 7.2, h = 10.4, color = C.teal, mat = M.WoodPlanks, text = "EQUIPMENT" })
	local shedBox = P.crate(pm, CFrame.new(sx - 2, G + 0.2, sz - 3), 2.6, C.sky)
	U.interact(shedBox, "Search", "S_PoolShed", "Pool", "Pool Supplies", { Loot = "Flashlight" })
	U.vcyl(pm, sx - 2, G + 0.2, sz + 3, G + 3.2, 2.4, C.sky, M.SmoothPlastic)
	U.beam(pm, Vector3.new(sx + 2, G + 0.4, sz + 4), Vector3.new(sx + 3, G + 8, sz + 4.6), 0.25, C.steel, M.Metal)

	ctx.ambience("Pool", Vector3.new(125, G + 4, 42), 25, 80)
	ctx.ambience("ChangingRooms", Vector3.new(172, G + 4, 21), 10, 40)
	ctx.ambience("PoolBar", Vector3.new(171, G + 4, 60), 12, 50)
	ctx.ambience("Restaurant", Vector3.new(115, G + 4, -45), 20, 70)
	ctx.ambience("PrivateDining", Vector3.new(105, G + 4, -86), 10, 40)
	ctx.ambience("Kitchen", Vector3.new(145, G + 4, -75), 15, 60)
end

return East
