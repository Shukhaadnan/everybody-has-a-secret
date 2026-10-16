--!nocheck
-- Underground: maintenance tunnel under the hotel (x -84..84, z -40..-28), stair shafts from the two side lanes,
-- storage room, electrical room (breaker), hidden room (secret door + switch) and a back passage to electrical.
local Underground = {}

function Underground.build(ctx)
	local U, P = ctx.U, ctx.P
	local C, M = U.C, U.M
	local G = ctx.G
	local NOCOL = P.NOCOL
	local rgb = Color3.fromRGB
	local m = ctx.model("Underground")
	local UF = ctx.UF -- floor top (-12)
	local CEIL = -1
	local H = CEIL - UF
	local WALLC = rgb(176, 170, 160)
	local W = { frame = C.pipeYellow, base = C.concreteDark }

	------------------------------------------------------------------ shell
	U.box(m, -86, UF - 1, -68, 86, UF, -26, C.concrete, M.Concrete)
	U.slab(m, -86, -68, 86, -26, CEIL, 0, ctx.groundHoles, C.concreteDark, M.Concrete)
	-- painted walkway stripes in the tunnel
	U.box(m, -84, UF, -29.4, 84, UF + 0.05, -29, C.pipeYellow, M.SmoothPlastic, { CanCollide = false })
	U.box(m, -84, UF, -39, 84, UF + 0.05, -38.6, C.pipeYellow, M.SmoothPlastic, { CanCollide = false })
	-- main tunnel walls
	U.wall(m, -84, -28, 84, -28, UF, H, 1, WALLC, M.Concrete, { { c = -20, w = 16, h = 10.6 } }, W)
	U.wall(m, -84, -40, 84, -40, UF, H, 1, WALLC, M.Concrete, {
		{ c = -77, w = 10, h = H, frame = false },
		{ c = 73, w = 10, h = H, frame = false },
		{ c = -43, w = 8, h = 10.6 },
		{ c = 2, w = 8, h = 10.6, frame = false },
		{ c = 43, w = 8, h = 10.6 },
	}, W)
	U.wall(m, -84, -40, -84, -28, UF, H, 1, WALLC, M.Concrete, {}, W)
	U.wall(m, 84, -40, 84, -28, UF, H, 1, WALLC, M.Concrete, {}, W)
	-- stair shafts (walls up to the slab underside, stairs from the lanes)
	for _, sx in { -77, 73 } do
		U.wall(m, sx - 5.5, -66.5, sx - 5.5, -40, UF, CEIL - UF, 1, WALLC, M.Concrete, {}, {})
		U.wall(m, sx + 5.5, -66.5, sx + 5.5, -40, UF, CEIL - UF, 1, WALLC, M.Concrete, {}, {})
		U.box(m, sx - 6, UF, -67, sx + 6, CEIL, -66, WALLC, M.Concrete)
		U.stairs(m, Vector3.new(sx, UF, -40), Vector3.new(0, 0, -1), 10, 20, 0.81, 1.3, C.concreteDark, M.Concrete, C.pipeYellow)
		-- railings at ground level around the shaft (open on the south / entry side)
		U.rail(m, sx - 5, -40, sx - 5, -66, G, 3.6, { top = C.pipeYellow })
		U.rail(m, sx + 5, -40, sx + 5, -66, G, 3.6, { top = C.pipeYellow })
		U.rail(m, sx - 5, -40, sx + 5, -40, G, 3.6, { top = C.pipeYellow })
		local px = sx + ((sx < 0) and 7 or -7)
		U.signAt(m, "⬇ MAINTENANCE", Vector3.new(px, G + 6, -66.8), Vector3.new(0, 0, -1), 7, 1.2, { bg = C.pipeYellow, fg = C.black, font = Enum.Font.GothamBold, double = true })
		U.box(m, px - 0.2, G, -67.2, px + 0.2, G + 5.4, -66.8, C.darkSteel, M.Metal)
		local exitSign = U.part(m, Vector3.new(3, 1, 0.3), CFrame.new(sx, CEIL - 0.5, -39.3), C.neonGreen, M.Neon, NOCOL)
		U.tag(exitSign, "ResortNeon")
		U.addGui(exitSign, Enum.NormalId.Back, "EXIT ▲", { fg = C.white, font = Enum.Font.GothamBold, pps = 30 })
	end

	------------------------------------------------------------------ pipes + caged lights along the tunnel
	for _, z in { -29.2, -29.9 } do
		local col = (z == -29.2) and C.pipeRed or rgb(80, 130, 170)
		U.cyl(m, CFrame.new(0, CEIL - 1.2 - (z == -29.2 and 0 or 1.1), z), 166, 0.8, col, M.Metal)
	end
	U.cyl(m, CFrame.new(0, CEIL - 0.9, -38.9), 166, 1.2, C.steel, M.Metal)
	for x = -78, 78, 12 do
		U.box(m, x - 0.3, CEIL - 2.6, -29.6, x + 0.3, CEIL, -28.5, C.darkSteel, M.Metal, NOCOL)
	end
	for x = -72, 72, 12 do
		local lamp = U.part(m, Vector3.new(2.4, 0.5, 1), CFrame.new(x, CEIL - 0.3, -34), rgb(255, 236, 190), M.Neon, NOCOL)
		U.tag(lamp, "ResortNeon")
		U.part(m, Vector3.new(2.8, 0.7, 1.4), CFrame.new(x, CEIL - 0.3, -34), C.darkSteel, M.Metal, { CanCollide = false, Transparency = 0.6 })
		U.light(lamp, rgb(255, 226, 180), 18, 0.9)
	end
	-- valve wheels on the pipes
	for _, x in { -60, -6, 36 } do
		U.cyl(m, CFrame.new(x, CEIL - 1.2, -29.9) * CFrame.Angles(0, math.pi / 2, 0), 0.3, 1.8, C.red, M.Metal, NOCOL)
	end
	-- signs
	U.signAt(m, "MAINTENANCE TUNNEL B1", Vector3.new(-60, CEIL - 3, -28.6), Vector3.new(0, 0, -1), 12, 1.4, { bg = C.pipeYellow, fg = C.black, font = Enum.Font.GothamBold })
	U.signAt(m, "⚡ ELECTRICAL", Vector3.new(43, UF + 12.2, -40.6), Vector3.new(0, 0, 1), 7, 1, { bg = C.pipeYellow, fg = C.black, font = Enum.Font.GothamBold })
	U.signAt(m, "STORAGE", Vector3.new(-43, UF + 12.2, -40.6), Vector3.new(0, 0, 1), 6, 1, { bg = C.pipeYellow, fg = C.black, font = Enum.Font.GothamBold })
	-- crates and barrels along the tunnel
	for i, x in { -66, -24, 20, 60 } do
		P.crate(m, CFrame.new(x, UF, -37.6) * CFrame.Angles(0, i * 0.3, 0), 2.6, C.wood)
	end
	for _, x in { -64, 24, 58 } do
		U.vcyl(m, x, UF, -30.6, UF + 3.6, 2.4, (x > 0) and C.pipeRed or rgb(60, 110, 160), M.Metal)
	end
	local barrel = U.vcyl(m, -26, UF, -30.6, UF + 3.6, 2.4, rgb(60, 110, 160), M.Metal)
	U.interact(barrel, "Hide", "H_TunnelBarrel", "Underground", "Old Barrel")
	-- maintenance alcove (north): workbench + locker
	U.wall(m, -28, -28, -28, -18, UF, H, 1, WALLC, M.Concrete, {}, {})
	U.wall(m, -12, -28, -12, -18, UF, H, 1, WALLC, M.Concrete, {}, {})
	U.wall(m, -28, -18, -12, -18, UF, H, 1, WALLC, M.Concrete, {}, {})
	U.box(m, -28, CEIL, -28, -12, 0, -18, C.concreteDark, M.Concrete)
	U.box(m, -28, UF - 1, -28, -12, UF, -18, C.concrete, M.Concrete)
	local bench = P.counter(m, -26, -21, -16, -18.6, UF, 3.2, C.darkSteel, C.woodLight)
	U.interact(bench, "Search", "S_Workbench", "Underground", "Workbench", { Loot = "Crowbar" })
	U.box(m, -26, UF + 5, -18.6, -16, UF + 9, -18.4, rgb(150, 120, 80), M.WoodPlanks, NOCOL) -- pegboard
	for k = 0, 4 do
		U.box(m, -25 + k * 2, UF + 6, -18.8, -24.6 + k * 2, UF + 8, -18.6, C.steel, M.Metal, NOCOL)
	end
	local note = U.part(m, Vector3.new(1.4, 1, 0.08), CFrame.lookAt(Vector3.new(-14, UF + 5.4, -18.55), Vector3.new(-14, UF + 5.4, -25)), C.paper, M.SmoothPlastic, NOCOL)
	U.interact(note, "Note", "Note_ElectricalCode", "Underground", "Sticky Note", { Text = "Janitor's sticky note: \"Electrical room keypad = 3141. Breaker trips if you pull it — lights out for a minute!\"" })
	local mlocker = P.wardrobe(m, CFrame.lookAt(Vector3.new(-13.6, UF, -23), Vector3.new(-20, UF, -23)), rgb(90, 120, 150))
	U.interact(mlocker, "Hide", "H_MaintLocker", "Underground", "Maintenance Locker")
	U.downlight(m, -20, CEIL, -23, 16, 0.8)

	------------------------------------------------------------------ storage room x -56..-30, z -64..-40
	U.wall(m, -56, -64, -56, -40, UF, H, 1, WALLC, M.Concrete, {}, W)
	U.wall(m, -30, -64, -30, -40, UF, H, 1, WALLC, M.Concrete, {}, W)
	U.wall(m, -56, -64, -30, -64, UF, H, 1, WALLC, M.Concrete, {}, W)
	U.door(m, "x", -43, -40, UF, "Underground", "D_UGStorage", "none", "Storage", { color = C.darkSteel, mat = M.DiamondPlate })
	for k = 0, 2 do
		local z = -60 + k * 7
		U.box(m, -55.4, UF, z - 2.6, -51.4, UF + 9, z + 2.6, C.steel, M.Metal)
		for r = 0, 2 do
			U.box(m, -55.2, UF + 1.2 + r * 2.8, z - 2.2, -51.6, UF + 2.8 + r * 2.8, z + 2.2, ({ C.woodLight, C.sky, C.white })[(k + r) % 3 + 1], M.Cardboard, NOCOL)
		end
	end
	local sc1 = P.crate(m, CFrame.new(-36, UF, -60), 3.4)
	U.interact(sc1, "Search", "S_UGCrate1", "Underground", "Old Crate", { Loot = "Briefcase" })
	P.crate(m, CFrame.new(-36, UF + 3.4, -60) * CFrame.Angles(0, 0.4, 0), 2.6, C.wood)
	local sc2 = P.crate(m, CFrame.new(-41, UF, -60) * CFrame.Angles(0, 0.2, 0), 3)
	U.interact(sc2, "Search", "S_UGCrate2", "Underground", "Dusty Box")
	-- lost & found bin
	local lf = U.box(m, -37, UF, -52, -31, UF + 3, -48, rgb(60, 90, 140), M.SmoothPlastic)
	U.signAt(m, "LOST & FOUND", Vector3.new(-34, UF + 2, -47.9), Vector3.new(0, 0, 1), 4.6, 0.8, { bg = C.white, fg = C.navy, font = Enum.Font.GothamBold, transparent = true, thick = 0.1 })
	U.interact(lf, "Search", "S_LostFound", "Underground", "Lost & Found", { Loot = "SecretLetter" })
	U.downlight(m, -43, CEIL, -52, 22, 0.8)

	------------------------------------------------------------------ hidden room x -10..14, z -66..-46 (+ corridor)
	-- secret door looks like a concrete wall panel
	U.door(m, "x", 2, -40, UF, "HiddenRoom", "D_HiddenRoom", "secret", "Hidden Room", { color = WALLC, mat = M.Concrete, w = 8 })
	U.wall(m, -3, -46, -3, -40, UF, H, 1, WALLC, M.Concrete, {}, {})
	U.wall(m, 7, -46, 7, -40, UF, H, 1, WALLC, M.Concrete, {}, {})
	U.wall(m, -10, -46, 14, -46, UF, H, 1, rgb(92, 60, 40), M.WoodPlanks, { { c = 2, w = 10, h = H, frame = false } }, {})
	U.wall(m, -10, -66, 14, -66, UF, H, 1, rgb(92, 60, 40), M.WoodPlanks, {}, { base = C.gold, crown = C.gold })
	U.wall(m, -10, -66, -10, -46, UF, H, 1, rgb(92, 60, 40), M.WoodPlanks, {}, { base = C.gold, crown = C.gold })
	U.wall(m, 14, -66, 14, -46, UF, H, 1, rgb(92, 60, 40), M.WoodPlanks, { { c = -56, w = 8, h = 10.6 } }, { base = C.gold, crown = C.gold })
	-- switch in the tunnel: a red valve lever half hidden behind the pipes on the opposite wall
	local sw1 = U.box(m, 1.4, UF + 4, -29.1, 2.6, UF + 5.4, -28.5, C.red, M.Metal)
	U.box(m, 1.8, UF + 4.5, -29.6, 2.2, UF + 4.9, -29.0, C.gold, M.Metal, NOCOL)
	U.interact(sw1, "Switch", "Switch_Tunnel", "Underground", "Strange Lever", { Opens = "D_HiddenRoom" })
	-- room interior: rug, old desk, map wall, treasure, armchairs, lamps
	U.rug(m, -8, -64, 12, -48, UF, C.redDark, C.gold)
	local desk = P.counter(m, -6, -64.6, 4, -61.4, UF, 3.2, C.woodDark, C.woodDark)
	local _ = desk
	P.tableLamp(m, Vector3.new(-4.5, UF + 3.2, -63), C.gold)
	local mapBoard = U.sign(m, "🗺️ THE RESORT — SECRET PLANS\n\n✕ Golden Statue → tunnel\n✕ Boat at midnight", CFrame.lookAt(Vector3.new(-1, UF + 7.5, -65.4), Vector3.new(-1, UF + 7.5, -50)), 9, 5, { bg = rgb(232, 210, 160), fg = rgb(90, 50, 30), font = Enum.Font.GothamBold, mat = M.Fabric, thick = 0.1, frame = C.woodDark })
	local _2 = mapBoard
	-- red strings / pins on the plan board
	for k = 0, 3 do
		U.ball(m, Vector3.new(-4 + k * 2, UF + 6.5 + (k % 2), -65.3), 0.3, C.red, M.SmoothPlastic, NOCOL)
	end
	local chest = U.box(m, 8, UF, -64.6, 12, UF + 2.6, -61.6, C.woodDark, M.Wood)
	U.box(m, 7.8, UF + 2.6, -64.8, 12.2, UF + 3.2, -61.4, C.gold, M.Metal, NOCOL)
	U.interact(chest, "Search", "S_HiddenChest", "HiddenRoom", "Old Chest", { Loot = "TreasureMap" })
	for k = 0, 4 do
		U.vcyl(m, 9 + (k % 3) * 1.2, UF + 3.2, -63.6 + math.floor(k / 3) * 1.2, UF + 3.5 + k * 0.1, 0.9, C.gold, M.Metal, NOCOL)
	end
	local safe2 = U.box(m, -9.4, UF, -54, -6.6, UF + 3.6, -50, C.darkSteel, M.DiamondPlate)
	U.interact(safe2, "Search", "S_HiddenSafe", "HiddenRoom", "Hidden Safe", { Loot = "VIPKeycard" })
	P.chair(m, CFrame.lookAt(Vector3.new(4, UF, -56), Vector3.new(-2, UF, -60)), C.red)
	P.chair(m, CFrame.lookAt(Vector3.new(-1, UF, -59.4), Vector3.new(-1, UF, -63)), C.red)
	P.floorLamp(m, Vector3.new(12, UF, -48), C.gold)
	-- switch inside the hidden room opens the back passage to the electrical room
	local sw2 = U.box(m, 13.2, UF + 4, -50.6, 13.5, UF + 5.4, -49.4, C.gold, M.Metal)
	U.interact(sw2, "Switch", "Switch_Hidden", "HiddenRoom", "Candle Lever", { Opens = "D_HiddenBack" })
	U.door(m, "z", 14, -56, UF, "HiddenRoom", "D_HiddenBack", "secret", "Secret Passage", { color = rgb(92, 60, 40), mat = M.WoodPlanks })
	U.picture(m, CFrame.lookAt(Vector3.new(-9.4, UF + 7, -58), Vector3.new(0, UF + 7, -58)), 4, 5)
	U.downlight(m, 2, CEIL, -56, 22, 0.8)
	-- back passage x 14..30, z -60..-52
	U.wall(m, 14, -60, 30, -60, UF, H, 1, WALLC, M.Concrete, {}, {})
	U.wall(m, 14, -52, 30, -52, UF, H, 1, WALLC, M.Concrete, {}, {})

	------------------------------------------------------------------ electrical room x 30..56, z -64..-40
	U.wall(m, 30, -64, 30, -40, UF, H, 1, WALLC, M.Concrete, { { c = -56, w = 8, h = 10.6 } }, W)
	U.wall(m, 56, -64, 56, -40, UF, H, 1, WALLC, M.Concrete, {}, W)
	U.wall(m, 30, -64, 56, -64, UF, H, 1, WALLC, M.Concrete, {}, W)
	U.door(m, "x", 43, -40, UF, "ElectricalRoom", "D_Electrical", "code", "Electrical Room", { inside = "-", code = "3141", color = C.pipeYellow, mat = M.DiamondPlate, text = "⚡ DANGER" })
	-- breaker panel (PowerBox) + cabinets
	U.box(m, 38, UF + 2, -63.5, 48, UF + 9, -62.9, C.darkSteel, M.Metal)
	local breaker = U.box(m, 41, UF + 3, -62.9, 45, UF + 8, -62.3, rgb(140, 150, 160), M.DiamondPlate)
	U.interact(breaker, "PowerBox", "PowerBox_Main", "ElectricalRoom", "Main Breaker")
	U.addGui(breaker, Enum.NormalId.Front, "⚡ MAIN\nBREAKER", { fg = C.yellow, font = Enum.Font.GothamBold, pps = 30, textH = 0.4 })
	U.box(m, 46, UF + 5, -62.4, 46.6, UF + 7, -61.8, C.red, M.Metal, NOCOL) -- lever
	for k = 0, 3 do
		local led = U.part(m, Vector3.new(0.3, 0.3, 0.1), CFrame.new(39 + k * 0.6, UF + 8.4, -62.85), (k % 2 == 0) and C.neonGreen or C.red, M.Neon, NOCOL)
		U.tag(led, "ResortNeon")
	end
	for _, k in { 0, 3 } do
		U.box(m, 32 + k * 6, UF, -43, 36 + k * 6, UF + 8, -40.7, rgb(120, 130, 140), M.Metal)
	end
	U.box(m, 54, UF, -60, 55.4, UF + 8, -44, C.steel, M.Metal)
	-- cable trays + conduits
	U.box(m, 31, CEIL - 1.2, -62, 55, CEIL - 0.8, -60, C.darkSteel, M.Metal, NOCOL)
	for k = 0, 3 do
		U.beam(m, Vector3.new(39.5 + k * 1.2, CEIL - 0.8, -62), Vector3.new(39.5 + k * 1.2, UF + 9, -62.9), 0.3, ({ C.red, C.black, C.pipeYellow, C.navy })[k + 1], M.SmoothPlastic, NOCOL)
	end
	-- generator
	U.box(m, 46, UF, -56, 51, UF + 4.6, -46, rgb(70, 120, 80), M.Metal)
	U.cyl(m, CFrame.new(48.5, UF + 5.6, -48), 2, 1.2, C.darkSteel, M.Metal)
	local warn = U.part(m, Vector3.new(4, 4, 0.1), CFrame.lookAt(Vector3.new(50, UF + 6, -63.45), Vector3.new(50, UF + 6, -50)), C.yellow, M.SmoothPlastic, NOCOL)
	U.addGui(warn, Enum.NormalId.Front, "⚠\nHIGH\nVOLTAGE", { fg = C.black, font = Enum.Font.GothamBold, pps = 30 })
	U.downlight(m, 43, CEIL, -52, 22, 0.8)

	------------------------------------------------------------------ markers
	ctx.item("Underground", Vector3.new(50, UF, -34))
	ctx.item("Underground", Vector3.new(-48, UF, -48))
	ctx.item("ElectricalRoom", Vector3.new(36, UF, -56))
	ctx.item("HiddenRoom", Vector3.new(0, UF, -52))
	ctx.wander("Underground", Vector3.new(-40, UF, -34))
	ctx.wander("Underground", Vector3.new(40, UF, -34))
	ctx.wander("ElectricalRoom", Vector3.new(43, UF, -48))
end

return Underground
