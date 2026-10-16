--!nocheck
-- Beach: terrain sand + ocean (built by MapBuilder), promenade ramps (Exterior), umbrellas, loungers, lifeguard tower,
-- dig spots, volleyball, beach shop on a raised boardwalk deck, wooden dock with boats, hidden cove.
local Beach = {}

function Beach.build(ctx)
	local U, P = ctx.U, ctx.P
	local C, M = U.C, U.M
	local G = ctx.G
	local NOCOL = P.NOCOL
	local rgb = Color3.fromRGB
	local m = ctx.model("Beach")

	local function gy(x, z)
		return U.groundY(x, z, 2)
	end

	------------------------------------------------------------------ umbrellas, loungers, towels (on the sand)
	local cols = { { C.coral, C.white }, { C.teal, C.white }, { C.yellow, C.white }, { C.pink, C.white }, { C.sky, C.white } }
	local spots = { -170, -130, -75, -25, 25, 70, 135, 170 }
	for i, x in spots do
		local z = 116 + (i % 2) * 8
		local y = gy(x, z)
		local c = cols[(i - 1) % #cols + 1]
		P.umbrella(m, Vector3.new(x, y - 0.4, z), c[1], c[2], 9.4)
		local ly = gy(x + 4, z + 2)
		P.lounger(m, CFrame.lookAt(Vector3.new(x + 4, ly - 0.3, z + 1), Vector3.new(x + 4, ly - 0.3, z + 20)) * CFrame.Angles(0, math.pi, 0), c[1])
		local ty = gy(x - 4, z + 2)
		U.box(m, x - 5.6, ty + 0.05, z - 1, x - 2.6, ty + 0.2, z + 5, c[1], M.Fabric, { CanCollide = false, CastShadow = false })
		U.box(m, x - 5.5, ty + 0.06, z + 1, x - 2.7, ty + 0.21, z + 1.8, C.white, M.Fabric, { CanCollide = false, CastShadow = false })
	end
	-- palms along the back of the beach
	for i, x in { -182, -158, -122, -78, -62, -12, 12, 62, 84, 120, 160, 182 } do
		local z = 100 + (i % 3) * 3
		P.palm(m, Vector3.new(x, gy(x, z) - 0.5, z), 18 + (i % 4) * 2, math.rad(80 + i * 23), 4)
	end
	-- beach balls + sandcastle
	for i, p in { { -110, 132 }, { 40, 135 }, { 150, 128 } } do
		U.ball(m, Vector3.new(p[1], gy(p[1], p[2]) + 0.9, p[2]), 2, ({ C.red, C.yellow, C.sky })[i], M.SmoothPlastic)
	end
	do
		local x, z = -50, 132
		local y = gy(x, z)
		U.vcyl(m, x, y - 0.4, z, y + 1.4, 5, C.sand, M.Sand)
		for k = 0, 3 do
			local a = k * math.pi / 2
			U.vcyl(m, x + math.cos(a) * 2.2, y + 1.4, z + math.sin(a) * 2.2, y + 3, 1.2, C.sand, M.Sand, NOCOL)
		end
		U.vcyl(m, x, y + 1.4, z, y + 3.8, 1.8, C.sand, M.Sand, NOCOL)
		U.wedge(m, Vector3.new(0.1, 0.8, 1), CFrame.new(x + 0.5, y + 4.6, z), C.red, M.Fabric, NOCOL)
	end
	-- volleyball net
	do
		local x, z = 0, 128
		local y = gy(x, z)
		for _, dx in { -10, 10 } do
			U.vcyl(m, x + dx, y - 1, z, y + 8.5, 0.4, C.white, M.Metal)
		end
		U.box(m, x - 10, y + 6, z - 0.05, x + 10, y + 8.2, z + 0.05, C.white, M.Fabric, { CanCollide = false, Transparency = 0.4 })
		U.box(m, x - 10, y + 8.1, z - 0.1, x + 10, y + 8.3, z + 0.1, C.white, M.Fabric, NOCOL)
	end
	-- lifeguard tower (walk-under hut on stilts)
	do
		local x, z = -12, 140
		local y = gy(x, z)
		for _, o in { { -2.5, -2.5 }, { 2.5, -2.5 }, { -2.5, 2.5 }, { 2.5, 2.5 } } do
			U.vcyl(m, x + o[1], y - 1, z + o[2], y + 8, 0.6, C.white, M.Wood)
		end
		U.box(m, x - 3.5, y + 8, z - 3.5, x + 3.5, y + 8.6, z + 3.5, C.white, M.WoodPlanks)
		U.box(m, x - 3, y + 8.6, z - 3, x + 3, y + 13, z + 3, C.red, M.WoodPlanks)
		U.box(m, x - 3.1, y + 10.6, z - 3.1, x + 3.1, y + 12.4, z + 3.1, C.glass, M.Glass, { Transparency = 0.5 })
		U.wedge(m, Vector3.new(7.6, 2, 3.8), CFrame.new(x, y + 14, z + 1.9) * CFrame.Angles(0, math.pi, 0), C.white, M.SmoothPlastic)
		U.wedge(m, Vector3.new(7.6, 2, 3.8), CFrame.new(x, y + 14, z - 1.9), C.white, M.SmoothPlastic)
		U.signAt(m, "LIFEGUARD", Vector3.new(x, y + 9.6, z + 3.1), Vector3.new(0, 0, 1), 5, 1, { bg = C.red, fg = C.white, font = Enum.Font.GothamBold, transparent = true, thick = 0.1 })
		U.beam(m, Vector3.new(x - 1, y, z - 8), Vector3.new(x - 1, y + 8.2, z - 3.5), 0.3, C.white, M.Wood)
		U.beam(m, Vector3.new(x + 1, y, z - 8), Vector3.new(x + 1, y + 8.2, z - 3.5), 0.3, C.white, M.Wood)
	end
	------------------------------------------------------------------ dig spots
	for i, p in { { -145, 134 }, { -85, 126 }, { 55, 130 }, { 160, 138 } } do
		local y = gy(p[1], p[2])
		local mound = U.vcyl(m, p[1], y - 0.3, p[2], y + 0.5, 4, rgb(214, 190, 140), M.Sand)
		U.interact(mound, "Dig", "Dig_" .. i, "Beach", "Dig Spot")
		-- little marker: shell + stick
		U.vcyl(m, p[1] + 1.4, y, p[2] + 1, y + 2.4, 0.2, C.woodDark, M.Wood, NOCOL)
		U.ball(m, Vector3.new(p[1] - 1, y + 0.55, p[2] - 0.8), 0.6, C.peach, M.SmoothPlastic, NOCOL)
	end
	ctx.item("Beach", Vector3.new(-30, gy(-30, 120), 120))
	ctx.item("Beach", Vector3.new(120, gy(120, 124), 124))
	ctx.wander("Beach", Vector3.new(-60, gy(-60, 118), 118))
	ctx.wander("Beach", Vector3.new(30, gy(30, 120), 120))
	ctx.wander("Beach", Vector3.new(150, gy(150, 118), 118))

	------------------------------------------------------------------ hidden cove (east end, behind rocks)
	do
		local x, z = 186, 140
		local y = gy(x, z)
		local crate = P.crate(m, CFrame.new(x, y - 0.2, z) * CFrame.Angles(0, 0.4, 0), 3, C.woodDark)
		U.interact(crate, "Search", "S_CoveCrate", "Beach", "Washed-up Crate")
		local barrel = U.vcyl(m, x - 5, y - 0.3, z + 4, y + 3.3, 2.6, C.woodDark, M.WoodPlanks)
		U.interact(barrel, "Hide", "H_CoveBarrel", "Beach", "Old Barrel")
		ctx.item("Beach", Vector3.new(x - 3, y, z - 4))
		U.signAt(m, "☠ KEEP OUT", Vector3.new(176, y + 3, 128), Vector3.new(-1, 0, -0.3).Unit, 4, 1.4, { bg = C.woodDark, fg = C.white, font = Enum.Font.GothamBold, mat = M.Wood, double = true })
		U.vcyl(m, 176.2, y - 1, 128.4, y + 2.4, 0.3, C.woodDark, M.Wood)
	end

	------------------------------------------------------------------ BEACH SHOP (raised deck level with the promenade)
	local sm = ctx.model("BeachShop")
	local bx1, bx2, bz1, bz2 = -114, -86, 96, 124
	U.box(sm, bx1, G - 1, bz1, bx2, G, bz2, C.woodLight, M.WoodPlanks)
	for _, x in { bx1 + 1, (bx1 + bx2) / 2, bx2 - 1 } do
		for _, z in { bz1 + 6, bz2 - 1 } do
			U.vcyl(sm, x, -4, z, G - 1, 1, C.woodDark, M.Wood)
		end
	end
	-- deck railings (open toward the promenade)
	U.rail(sm, bx1, bz2, bx2, bz2, G, 3.4, { top = C.woodDark, glass = C.white })
	U.rail(sm, bx1, bz1 + 0.6, bx1, bz2, G, 3.4, { top = C.woodDark, glass = C.white })
	U.rail(sm, bx2, bz1 + 0.6, bx2, bz2, G, 3.4, { top = C.woodDark, glass = C.white })
	-- hut
	local hx1, hx2, hz1, hz2 = -110, -90, 104, 120
	U.wall(sm, hx1, hz2, hx2, hz2, G, 10, 0.6, C.sky, M.WoodPlanks, {}, {})
	U.wall(sm, hx1, hz1, hx1, hz2, G, 10, 0.6, C.sky, M.WoodPlanks, {}, {})
	U.wall(sm, hx2, hz1, hx2, hz2, G, 10, 0.6, C.sky, M.WoodPlanks, {}, {})
	U.wall(sm, hx1, hz1, hx2, hz1, G, 10, 0.6, C.sky, M.WoodPlanks, { { c = -100, w = 14, h = 6, b = 3.6 } }, { frame = C.white })
	U.box(sm, hx1 - 2, G + 10, hz1 - 3, hx2 + 2, G + 10.6, hz2 + 1, C.white, M.SmoothPlastic)
	for k = 0, 7 do
		local x = hx1 - 2 + (k + 0.5) * ((hx2 - hx1 + 4) / 8)
		U.part(sm, Vector3.new((hx2 - hx1 + 4) / 8, 0.2, 4.4), CFrame.new(x, G + 9.6, hz1 - 4.6) * CFrame.Angles(math.rad(-22), 0, 0), (k % 2 == 0) and C.coral or C.white, M.Fabric, NOCOL)
	end
	local counter = P.counter(sm, -106, hz1 + 0.4, -94, hz1 + 3, G, 3.6, C.white, C.woodLight)
	U.interact(counter, "Shop", "Shop_Beach", "BeachShop", "Beach Shop", { ShopId = "Beach" })
	U.signAt(sm, "🏄 SURF & SUN SHOP", Vector3.new(-100, G + 11.6, hz1 - 2.4), Vector3.new(0, 0, -1), 16, 2, { bg = C.white, fg = C.coral, font = Enum.Font.FredokaOne, thick = 0.3, frame = C.coral })
	-- stock: surfboards, rings, balls, shelves
	for k = 0, 3 do
		U.part(sm, Vector3.new(2.2, 8.6, 0.4), CFrame.new(hx1 + 2 + k * 2.8, G + 4.4, hz2 - 0.8) * CFrame.Angles(math.rad(-6), 0, 0), ({ C.coral, C.yellow, C.teal, C.pink })[k + 1], M.SmoothPlastic, NOCOL)
	end
	U.box(sm, hx2 - 3, G, hz1 + 6, hx2 - 0.4, G + 6, hz2 - 2, C.white, M.Wood)
	for r = 0, 2 do
		for k = 0, 3 do
			U.ball(sm, Vector3.new(hx2 - 1.7, G + 1.2 + r * 2, hz1 + 7 + k * 2.2), 1.3, ({ C.coral, C.yellow, C.sky, C.mint })[(k + r) % 4 + 1], M.SmoothPlastic, NOCOL)
		end
	end
	local cooler = U.box(sm, -104, G, hz2 - 4, -100, G + 2.4, hz2 - 1.4, C.sky, M.SmoothPlastic)
	U.box(sm, -104.1, G + 2.4, hz2 - 4.1, -99.9, G + 2.8, hz2 - 1.3, C.white, M.SmoothPlastic, NOCOL)
	U.interact(cooler, "Search", "S_BeachCooler", "BeachShop", "Cooler", { Loot = "Champagne" })
	local lamp = U.part(sm, Vector3.new(1, 1, 1), CFrame.new(-100, G + 9.2, 112), C.yellow, M.SmoothPlastic, { Transparency = 1, CanCollide = false })
	U.light(lamp, rgb(255, 224, 170), 18, 0.9)
	P.umbrella(sm, Vector3.new(-90, G, 99), C.coral, C.white, 8, 3.6)
	P.umbrella(sm, Vector3.new(-110, G, 99), C.teal, C.white, 8, 3.6)
	ctx.item("BeachShop", Vector3.new(-96, G, 116))
	ctx.wander("BeachShop", Vector3.new(-100, G, 100))

	------------------------------------------------------------------ DOCK
	local dm = ctx.model("Dock")
	local DX = 100
	local DZ1, DZ2 = 96, 190
	U.box(dm, DX - 5, G - 1, DZ1, DX + 5, G, DZ2, C.woodLight, M.WoodPlanks)
	-- plank seams + side beams
	U.box(dm, DX - 5.3, G - 1.4, DZ1, DX - 5, G - 0.2, DZ2, C.woodDark, M.Wood)
	U.box(dm, DX + 5, G - 1.4, DZ1, DX + 5.3, G - 0.2, DZ2, C.woodDark, M.Wood)
	for z = DZ1 + 8, DZ2, 12 do
		for _, dx in { -4.6, 4.6 } do
			U.vcyl(dm, DX + dx, -12, z, G + 2.6, 1, C.woodDark, M.Wood)
			U.ball(dm, Vector3.new(DX + dx, G + 2.8, z), 1.1, C.woodDark, M.Wood, NOCOL)
		end
		-- rope between posts
		if z + 12 <= DZ2 then
			for _, dx in { -4.6, 4.6 } do
				U.beam(dm, Vector3.new(DX + dx, G + 2.2, z), Vector3.new(DX + dx, G + 2.2, z + 12), 0.2, rgb(220, 200, 150), M.Fabric, NOCOL)
			end
		end
	end
	for k = 0, 2 do
		P.streetLamp(dm, Vector3.new(DX + 4, G, 120 + k * 30), 9)
	end
	-- steps down to the floating T-pier
	local LOW = ctx.PIER
	local nSteps = 8
	local rise = (G - LOW) / nSteps
	for i = 1, nSteps do
		local top = G - i * rise
		U.box(dm, DX - 5, top - 1, DZ2 + (i - 1) * 1.4, DX + 5, top, DZ2 + i * 1.4, C.woodLight, M.WoodPlanks)
	end
	for _, dx in { -5.3, 5.3 } do
		U.beam(dm, Vector3.new(DX + dx, G + 3, DZ2), Vector3.new(DX + dx, LOW + 3, DZ2 + nSteps * 1.4), 0.3, C.woodDark, M.Wood, NOCOL)
	end
	local TZ1, TZ2 = DZ2 + nSteps * 1.4, DZ2 + nSteps * 1.4 + 10
	U.box(dm, DX - 22, LOW - 1, TZ1, DX + 22, LOW, TZ2, C.woodLight, M.WoodPlanks)
	for _, x in { DX - 21, DX - 10, DX + 10, DX + 21 } do
		for _, z in { TZ1 + 1, TZ2 - 1 } do
			U.vcyl(dm, x, -12, z, LOW + 2, 0.9, C.woodDark, M.Wood)
		end
	end
	-- life ring + crates + fishing gear
	U.part(dm, Vector3.new(0.5, 3, 3), CFrame.new(DX - 5.6, G + 1.6, 140) * CFrame.Angles(0, 0, 0), C.red, M.SmoothPlastic, { CanCollide = false, Shape = Enum.PartType.Cylinder })
	local dcrate = P.crate(dm, CFrame.new(DX + 16, LOW, TZ1 + 3), 3, C.wood)
	U.interact(dcrate, "Search", "S_DockCrate", "Dock", "Fishing Crate")
	local net = U.box(dm, DX - 18, LOW, TZ1 + 1, DX - 14, LOW + 1.4, TZ1 + 4, rgb(120, 140, 120), M.Fabric)
	U.interact(net, "Hide", "H_DockNets", "Dock", "Pile of Nets")
	-- boats
	local BY = ctx.BOATY
	local yacht = P.boat(dm, CFrame.new(DX - 12, BY, TZ2 + 6) * CFrame.Angles(0, math.pi / 2, 0), C.white, C.navy)
	U.interact(yacht, "Boat", "Boat_Yacht", "Dock", "Speedboat")
	P.boat(dm, CFrame.new(DX + 13, BY, TZ2 + 6) * CFrame.Angles(0, -math.pi / 2, 0), C.white, C.coral)
	P.boat(dm, CFrame.new(DX - 14, BY, 168) * CFrame.Angles(0, math.pi, 0), C.sky, C.white)
	local dsign = CFrame.lookAt(Vector3.new(DX, G + 8.6, DZ1 + 1), Vector3.new(DX, G + 8.6, DZ1 - 10))
	for _, dx in { -5, 5 } do
		U.vcyl(dm, DX + dx, G, DZ1 + 1, G + 10, 0.6, C.woodDark, M.Wood)
	end
	U.sign(dm, "⚓ MARINA DOCK", dsign, 10, 1.8, { bg = C.navy, fg = C.white, font = Enum.Font.FredokaOne, double = true, frame = C.woodDark })
	local dcam = P.securityCam(dm, Vector3.new(DX + 5.6, G + 9, 122), Vector3.new(DX, LOW, TZ1))
	U.vcyl(dm, DX + 5.6, G - 1, 122.6, G + 9, 0.4, C.darkSteel, M.Metal)
	U.interact(dcam, "Camera", "Cam_Dock", "Dock", "Security Camera", { CamId = "Cam_Dock" })
	ctx.mark("BoatDock", Vector3.new(DX, LOW, TZ2 - 3))
	ctx.item("Dock", Vector3.new(DX + 2, G, 170))
	ctx.wander("Dock", Vector3.new(DX, G, 140))
	ctx.wander("Dock", Vector3.new(DX + 8, LOW, TZ1 + 4))

	-- distant decor: small islet with palms + lighthouse
	return { islet = Vector3.new(-60, 0, 330) }
end

return Beach
