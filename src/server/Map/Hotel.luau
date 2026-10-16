--!nocheck
-- Hotel: 2 floors + rooftop. Ground: Lobby (+stair hall), Reception, HotelBar, Housekeeping (+storage), SecurityRoom (+Detention).
-- Floor 2: GuestRooms (hallway, 4 rooms, suite, lounge), Balcony. Rooftop: helipad, lounge, hot tub.
local Hotel = {}

function Hotel.build(ctx)
	local U, P = ctx.U, ctx.P
	local C, M = U.C, U.M
	local m = ctx.model("Hotel")
	local NOCOL = P.NOCOL
	local rgb = Color3.fromRGB

	local G, F2, RF = 4.2, 21, 38
	local GW = 15.6 -- ground wall height (4 -> 19.6)
	local UW = 16.2 -- upper wall height (20.4 -> 36.6)
	local EXT = { frame = C.white, glass = C.glass, mullion = 4 }
	local EXT_GOLD = { frame = C.gold, glass = C.glass, mullion = 4 }
	local INT = { frame = C.white, base = C.woodDark, crown = C.white }
	local WALL, IWALL = C.cream, C.cream2
	local function win(c, w, b, h)
		return { c = c, w = w or 8, b = b or 2.5, h = h or 9, glass = true }
	end
	local function door(c, w, h, b)
		return { c = c, w = w or 8, h = h or 11, b = b or 0 }
	end

	------------------------------------------------------------------ floors (ground)
	U.box(m, -24, 0, -70, 24, G, -10, C.marble, M.Marble, { Reflectance = 0.06 })
	U.box(m, -60, 0, -50, -24, G, -10, C.wood, M.WoodPlanks)
	U.box(m, -60, 0, -100, -24, G, -50, rgb(214, 214, 206), M.SmoothPlastic)
	U.box(m, -24, 0, -100, 24, G, -70, C.woodLight, M.WoodPlanks)
	U.box(m, 24, 0, -60, 60, G, -10, C.marble, M.Marble, { Reflectance = 0.06 })
	U.box(m, 24, 0, -100, 60, G, -60, rgb(126, 134, 146), M.SmoothPlastic)
	-- lobby floor inlay: gold ring + teal medallion around the statue dais
	U.cyl(m, CFrame.new(0, G + 0.03, -38) * CFrame.Angles(0, 0, math.pi / 2), 0.1, 20, C.gold, M.Metal, { CanCollide = false, Reflectance = 0.1 })
	U.cyl(m, CFrame.new(0, G + 0.06, -38) * CFrame.Angles(0, 0, math.pi / 2), 0.1, 18.6, C.marble, M.Marble, { CanCollide = false })
	-- red carpet from the entrance to the desk
	U.rug(m, -4, -60, 4, -49, G, C.red, C.gold)
	U.rug(m, -4, -27, 4, -10.2, G, C.red, C.gold)

	U.skirt(m, -60.6, -100.6, 60.6, -9.4)
	------------------------------------------------------------------ exterior walls (ground)
	U.wall(m, -60, -10, 60, -10, 4, GW, 1.2, WALL, M.SmoothPlastic, {
		win(-53), door(-42), win(-30), win(-18), { c = 0, w = 16, h = 12.5 }, win(18), door(34), win(46), win(54, 6),
	}, EXT_GOLD)
	U.wall(m, -60, -100, 60, -100, 4, GW, 1.2, WALL, M.SmoothPlastic, {
		door(-50), win(-34, 6, 5.5, 5), win(0, 10, 4, 7), win(36, 8, 5, 6), win(52, 6, 4, 6),
	}, EXT)
	U.wall(m, -60, -100, -60, -10, 4, GW, 1.2, WALL, M.SmoothPlastic, { win(-30, 12), win(-20, 6), win(-80, 8, 4, 6) }, EXT)
	U.wall(m, 60, -100, 60, -10, 4, GW, 1.2, WALL, M.SmoothPlastic, { win(-35, 12), win(-20, 6), win(-80, 8, 4, 6), door(-70) }, EXT)

	------------------------------------------------------------------ interior walls (ground)
	U.wall(m, -24, -100, -24, -10, 4, GW, 1, IWALL, M.SmoothPlastic, { door(-60), { c = -30, w = 12, h = 12 } }, INT)
	U.wall(m, -60, -50, -24, -50, 4, GW, 1, IWALL, M.SmoothPlastic, {}, INT)
	U.wall(m, -42, -100, -42, -50, 4, GW, 1, IWALL, M.SmoothPlastic, { door(-75) }, INT)
	U.wall(m, 24, -100, 24, -10, 4, GW, 1, IWALL, M.SmoothPlastic, { { c = -30, w = 14, h = 12 } }, INT)
	U.wall(m, 24, -60, 60, -60, 4, GW, 1, IWALL, M.SmoothPlastic, { door(36) }, INT)
	U.wall(m, -24, -70, 24, -70, 4, GW, 1, C.tealDeep, M.SmoothPlastic, { door(16) }, INT)
	-- detention cell: solid side wall + bars front
	U.wall(m, 46, -100, 46, -86, 4, GW, 1, rgb(180, 184, 190), M.Concrete, {}, {})
	U.box(m, 46, 14.8, -86.5, 60, 19.6, -85.5, rgb(180, 184, 190), M.Concrete)
	for x = 46.6, 49, 0.8 do
		U.vcyl(m, x, 4, -86, 14.8, 0.3, C.darkSteel, M.Metal)
	end
	for x = 57.4, 59.6, 0.8 do
		U.vcyl(m, x, 4, -86, 14.8, 0.3, C.darkSteel, M.Metal)
	end
	U.box(m, 46, 14.6, -86.3, 60, 14.9, -85.7, C.darkSteel, M.Metal)

	------------------------------------------------------------------ ground doors
	U.door(m, "z", -24, -60, G, "Housekeeping", "D_Housekeeping", "key:MasterKey", "Housekeeping", { inside = "-", text = "STAFF ONLY", color = C.wood })
	U.door(m, "z", -42, -75, G, "Housekeeping", "D_HKStorage", "none", "Storage Room", { inside = "-", text = "STORAGE", color = C.woodLight })
	U.door(m, "x", -50, -100, G, "Housekeeping", "D_HKBack", "key:MasterKey", "Service Door", { inside = "+", color = C.white, mat = M.SmoothPlastic })
	U.door(m, "x", 16, -70, G, "Reception", "D_Reception", "code", "Reception Office", { inside = "-", code = "0427", text = "OFFICE", color = C.woodDark })
	U.door(m, "x", 36, -60, G, "SecurityRoom", "D_Security", "security", "Security Room", { inside = "-", text = "SECURITY", color = C.darkSteel, mat = M.DiamondPlate, textColor = C.neonBlue })
	U.door(m, "z", 60, -70, G, "SecurityRoom", "D_SecurityBack", "security", "Security Exit", { inside = "-", color = C.darkSteel, mat = M.DiamondPlate })
	U.door(m, "x", 53, -86, G, "Detention", "D_Detention", "security", "Detention Cell", { color = C.darkSteel, mat = M.Metal, transparency = 0.2, text = "HOLDING" })

	------------------------------------------------------------------ floor 2 slab + finishes
	local hole = { 44, -41.3, 52, -12 }
	U.slab(m, -60.6, -100.6, 60.6, -9.4, 19.6, 20.4, { hole }, C.white, M.SmoothPlastic)
	U.box(m, -60, 20.4, -100, 60, F2, -58, C.woodLight, M.WoodPlanks)
	U.box(m, -60, 20.4, -58, 24, F2, -48, C.marble, M.Marble, { Reflectance = 0.05 })
	U.slab(m, 24, -58, 60, -9.4, 20.4, F2, { hole }, C.marble, M.Marble, { Reflectance = 0.05 })
	U.box(m, -60, 20.4, -48, -20, F2, -10, C.wood, M.WoodPlanks)
	U.box(m, -20, 20.4, -48, 24, F2, -9.4, C.marble, M.Marble, { Reflectance = 0.05 })
	-- gold band at the floor line + cornice
	for _, b in {
		{ -60.9, 19.4, -100.9, 60.9, 21.2, -100.3 }, { -60.9, 19.4, -9.7, -30, 21.2, -9.1 }, { 30, 19.4, -9.7, 60.9, 21.2, -9.1 },
		{ -60.9, 19.4, -100.9, -60.3, 21.2, -9.1 }, { 60.3, 19.4, -100.9, 60.9, 21.2, -9.1 },
	} do
		U.box(m, b[1], b[2], b[3], b[4], b[5], b[6], C.gold, M.Metal, { Reflectance = 0.15 })
	end

	------------------------------------------------------------------ floor 2 walls
	local UB = 3.6 -- window sill offset from wall base 20.4
	U.wall(m, -60, -10, 60, -10, 20.4, UW, 1.2, WALL, M.SmoothPlastic, {
		win(-50, 8, UB, 8), win(-34, 8, UB, 8), win(-12, 8, UB, 8), { c = 0, w = 10, h = 11, b = 0.6 }, win(12, 8, UB, 8), win(32, 8, UB, 8), win(48, 8, UB, 8),
	}, EXT)
	U.wall(m, -60, -100, 60, -100, 20.4, UW, 1.2, WALL, M.SmoothPlastic, { win(-45, 10, UB, 8), win(-15, 10, UB, 8), win(15, 10, UB, 8), win(45, 10, UB, 8) }, EXT)
	U.wall(m, -60, -100, -60, -10, 20.4, UW, 1.2, WALL, M.SmoothPlastic, { win(-29, 10, UB, 8), win(-79, 10, UB, 8) }, EXT)
	U.wall(m, 60, -100, 60, -10, 20.4, UW, 1.2, WALL, M.SmoothPlastic, { win(-29, 10, UB, 8), win(-79, 10, UB, 8) }, EXT)
	U.wall(m, -60, -58, 60, -58, 20.4, UW, 1, IWALL, M.SmoothPlastic, { door(-45, 8, 11, 0.6), door(-15, 8, 11, 0.6), door(15, 8, 11, 0.6), door(45, 8, 11, 0.6) }, INT)
	for _, x in { -30, 0, 30 } do
		U.wall(m, x, -100, x, -58, 20.4, UW, 1, IWALL, M.SmoothPlastic, {}, INT)
	end
	U.wall(m, -60, -48, 24, -48, 20.4, UW, 1, IWALL, M.SmoothPlastic, { door(-40, 8, 11, 0.6), { c = 2, w = 20, h = 12, b = 0.6 } }, INT)
	U.wall(m, -20, -48, -20, -10, 20.4, UW, 1, IWALL, M.SmoothPlastic, {}, INT)

	local roomColors = { C.teal, C.coral, rgb(120, 150, 200), rgb(196, 160, 90) }
	for i, cx in { -45, -15, 15, 45 } do
		local lock = (i == 2) and "none" or "key:MasterKey"
		U.door(m, "x", cx, -58, F2, "GuestRooms", "D_Room20" .. i, lock, "Room 20" .. i, { inside = "-", text = "20" .. i, color = C.wood })
		-- gold room number plaque next to the door
		U.sign(m, "20" .. i, CFrame.lookAt(Vector3.new(cx + 5.4, F2 + 6, -57.35), Vector3.new(cx + 5.4, F2 + 6, -50)), 1.6, 1, { bg = C.gold, fg = C.black, font = Enum.Font.GothamBold, thick = 0.15 })
	end
	U.door(m, "x", -40, -48, F2, "GuestRooms", "D_Suite205", "key:MasterKey", "Royal Suite", { inside = "+", text = "SUITE 205", color = C.woodDark })
	U.door(m, "x", 0, -10, F2, "Balcony", "D_Balcony", "none", "Balcony", { color = C.glass, mat = M.Glass, transparency = 0.45, w = 9.6 })

	------------------------------------------------------------------ roof slab + parapet
	U.slab(m, -60.6, -100.6, 60.6, -9.4, 36.6, RF, { { 34, -44, 42, -16 } }, C.paving, M.Slate)
	U.box(m, -60.9, 36.4, -100.9, 60.9, 37.2, -9.1, C.gold, M.Metal, { Reflectance = 0.12, CanCollide = false })
	for _, b in { { -60.6, -100.6, 60.6, -99.4 }, { -60.6, -10.6, 60.6, -9.4 }, { -60.6, -99.4, -59.4, -10.6 }, { 59.4, -99.4, 60.6, -10.6 } } do
		U.box(m, b[1], RF, b[2], b[3], RF + 3.2, b[4], WALL, M.SmoothPlastic)
		U.box(m, b[1] - 0.2, RF + 3.2, b[2] - 0.2, b[3] + 0.2, RF + 3.6, b[4] + 0.2, C.gold, M.Metal, { Reflectance = 0.15 })
	end
	-- corner pilasters full height
	for _, c in { { -60, -100 }, { 60, -100 }, { -60, -10 }, { 60, -10 } } do
		U.box(m, c[1] - 1.4, 4, c[2] - 1.4, c[1] + 1.4, RF + 4.2, c[2] + 1.4, C.white, M.Marble, { Reflectance = 0.05 })
		U.box(m, c[1] - 1.8, RF + 4.2, c[2] - 1.8, c[1] + 1.8, RF + 4.8, c[2] + 1.8, C.gold, M.Metal)
	end
	-- big hotel sign on the front parapet
	local signCF = CFrame.lookAt(Vector3.new(0, RF + 7.2, -9.6), Vector3.new(0, RF + 7.2, 10))
	U.part(m, Vector3.new(44, 7.4, 0.6), signCF * CFrame.new(0, 0, 0.5), C.gold, M.Metal, { Reflectance = 0.2 })
	U.sign(m, "GRAND PALM RESORT", signCF, 42, 6.4, { bg = C.tealDeep, fg = C.yellow, font = Enum.Font.FredokaOne, pps = 20, stroke = 0.3, thick = 0.4 })
	U.box(m, -2, RF + 3.6, -10.6, 2, RF + 3.8, -9.6, C.gold, M.Metal)

	------------------------------------------------------------------ entrance portico + balcony
	U.box(m, -30, 19.6, -9.4, 30, F2, 4, C.white, M.SmoothPlastic)
	U.box(m, -30.3, 19.4, 3.7, 30.3, 21.2, 4.3, C.gold, M.Metal, { Reflectance = 0.15 })
	U.box(m, -29, F2, -9.4, 29, F2 + 0.15, 3, C.woodLight, M.WoodPlanks)
	for _, x in { -27, -11, 11, 27 } do
		U.column(m, x, 4, 1.5, 19.6, 2.2, C.white, C.gold)
	end
	U.rail(m, -30, 3.6, 30, 3.6, F2, 3.6)
	U.rail(m, -29.6, -9.4, -29.6, 3.6, F2, 3.6)
	U.rail(m, 29.6, -9.4, 29.6, 3.6, F2, 3.6)
	for _, x in { -22, 22 } do
		P.lounger(m, CFrame.lookAt(Vector3.new(x, F2, -4), Vector3.new(x, F2, 5)), C.teal)
		P.plant(m, Vector3.new(x + (x > 0 and 5 or -5), F2, -7.5), 0.9)
	end
	P.roundTable(m, Vector3.new(-12, F2, -3), 3, 3, C.white)
	P.chair(m, CFrame.lookAt(Vector3.new(-15, F2, -3), Vector3.new(-12, F2, -3)), C.coral)
	P.chair(m, CFrame.lookAt(Vector3.new(-9, F2, -3), Vector3.new(-12, F2, -3)), C.coral)
	ctx.item("Balcony", Vector3.new(12, F2, -2))
	ctx.wander("Balcony", Vector3.new(0, F2, -3))
	-- entrance sign + downlights in the portico ceiling
	U.signAt(m, "HOTEL", Vector3.new(0, 18.2, -9.1), Vector3.new(0, 0, 1), 12, 2.4, { bg = C.tealDeep, fg = C.gold, font = Enum.Font.FredokaOne, pps = 25, frame = C.gold })
	for _, x in { -18, 0, 18 } do
		U.downlight(m, x, 19.6, -3, 18, 0.7)
	end

	------------------------------------------------------------------ LOBBY
	-- columns
	for _, c in { { -14, -20 }, { 14, -20 }, { -14, -56 }, { 14, -56 } } do
		U.column(m, c[1], G, c[2], 19.6, 2.4, C.marble, C.gold)
	end
	-- statue dais (Pedestal)
	U.vcyl(m, 0, G, -38, G + 0.5, 12, C.marbleDark, M.Marble, { Reflectance = 0.06 })
	U.vcyl(m, 0, G + 0.5, -38, G + 1, 9, C.marble, M.Marble, { Reflectance = 0.06 })
	U.vcyl(m, 0, G + 1, -38, G + 1.4, 4.4, C.gold, M.Metal, { Reflectance = 0.2 })
	U.vcyl(m, 0, G + 1.4, -38, G + 4.8, 3.2, C.white, M.Marble, { Reflectance = 0.06 })
	local ped = U.vcyl(m, 0, G + 4.8, -38, G + 5.3, 4, C.gold, M.Metal, { Reflectance = 0.2 })
	U.interact(ped, "Pedestal", "Ped_GoldenStatue", "Lobby", "Golden Statue", { ItemId = "GoldenStatue" })
	ped.Name = "StatuePedestal"
	U.signAt(m, "THE GOLDEN STATUE", Vector3.new(0, G + 2.6, -36.35), Vector3.new(0, 0, 1), 3, 0.7, { bg = C.gold, fg = C.black, font = Enum.Font.GothamBold, thick = 0.1 })
	-- velvet rope posts around the dais
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2 + math.pi / 6
		local p1 = Vector3.new(math.cos(a) * 7.6, G, -38 + math.sin(a) * 7.6)
		U.vcyl(m, p1.X, G, p1.Z, G + 3, 0.35, C.gold, M.Metal)
		U.ball(m, p1 + Vector3.new(0, 3.2, 0), 0.6, C.gold, M.Metal, NOCOL)
		local a2 = (k + 1) / 6 * math.pi * 2 + math.pi / 6
		if k ~= 1 then -- gap toward the front
			local p2 = Vector3.new(math.cos(a2) * 7.6, G, -38 + math.sin(a2) * 7.6)
			U.beam(m, p1 + Vector3.new(0, 2.5, 0), p2 + Vector3.new(0, 2.5, 0), 0.25, C.red, M.Fabric, NOCOL)
		end
	end
	-- spotlights on the statue
	local spot = U.part(m, Vector3.new(1, 1, 1), CFrame.new(0, 19.2, -38), C.gold, M.Metal, NOCOL)
	U.spot(spot, rgb(255, 236, 190), 24, 3, Enum.NormalId.Bottom, 40)
	-- reception desk (curved look: main counter + rounded ends)
	local desk = P.counter(m, -12, -64, 12, -61, G, 4.2, C.tealDeep, C.marble)
	for _, x in { -12, 12 } do
		U.vcyl(m, x, G, -62.5, G + 3.9, 3, C.tealDeep, M.SmoothPlastic)
		U.vcyl(m, x, G + 3.9, -62.5, G + 4.2, 3.6, C.marble, M.Marble)
	end
	U.box(m, -11, G + 1, -61.2, 11, G + 1.25, -60.85, C.gold, M.Metal, NOCOL)
	U.signAt(m, "RECEPTION", Vector3.new(0, G + 2.4, -60.75), Vector3.new(0, 0, 1), 9, 1.4, { bg = C.tealDeep, fg = C.gold, font = Enum.Font.GothamBold, transparent = true, thick = 0.1 })
	local bell = U.ball(m, Vector3.new(4, G + 4.45, -62.5), 0.6, C.gold, M.Metal, NOCOL)
	bell.Name = "DeskBell"
	local lphone = P.phone(m, Vector3.new(-4, G + 4.2, -62.5), 0)
	U.interact(lphone, "Phone", "Phone_Lobby", "Lobby", "Front Desk Phone")
	P.computer(m, CFrame.lookAt(Vector3.new(0, G + 4.2, -63), Vector3.new(0, G + 4.2, -70)), "WELCOME")
	-- back wall sign + key wall decoration
	U.signAt(m, "WELCOME TO THE GRAND PALM", Vector3.new(-1, 15.5, -69.35), Vector3.new(0, 0, 1), 22, 2.6, { bg = C.tealDeep, fg = C.gold, font = Enum.Font.FredokaOne, transparent = true, thick = 0.1 })
	-- elevator (ground)
	local function elevatorPanel(pos, look, id, to, label, zone)
		local cf = CFrame.lookAt(pos, pos + look)
		U.part(m, Vector3.new(7.4, 11.2, 0.3), cf * CFrame.new(0, 0, 0.2), C.gold, M.Metal, { Reflectance = 0.2 })
		local panel = U.part(m, Vector3.new(6.4, 10, 0.3), cf, C.steel, M.Metal, { Reflectance = 0.25 })
		U.part(m, Vector3.new(0.1, 10, 0.32), cf, C.darkSteel, M.Metal, NOCOL)
		local arrow = U.part(m, Vector3.new(1.6, 0.8, 0.2), cf * CFrame.new(0, 6, 0), C.neonYellow, M.Neon, NOCOL)
		U.tag(arrow, "ResortNeon")
		U.addGui(arrow, Enum.NormalId.Front, label, { fg = C.black, font = Enum.Font.GothamBold, pps = 30 })
		U.interact(panel, "Elevator", id, zone, "Elevator", { To = to })
		return panel
	end
	elevatorPanel(Vector3.new(-16, G + 5, -69.15), Vector3.new(0, 0, 1), "Elev_G", "Elev_2A", "▲ 2", "Lobby")
	-- lounge seating
	for _, s in { { -18, -46, 1 }, { 18, -46, -1 } } do
		local x, z, side = s[1], s[2], s[3]
		U.rug(m, x - 5, z - 7, x + 5, z + 7, G, side > 0 and C.teal or C.coral, C.gold)
		P.sofa(m, CFrame.lookAt(Vector3.new(x - 2.6 * side, G, z), Vector3.new(x + 10 * side, G, z)) , 8, C.cream, side > 0 and C.coral or C.teal)
		P.coffeeTable(m, CFrame.new(x + 1.8 * side, G, z), 3, 5)
		P.chair(m, CFrame.lookAt(Vector3.new(x + 1.8 * side, G, z - 5.2), Vector3.new(x + 1.8 * side, G, z)), C.teal)
		P.floorLamp(m, Vector3.new(x - 3 * side, G, z + 5.6))
	end
	P.plant(m, Vector3.new(-21, G, -13), 1.2)
	P.plant(m, Vector3.new(21, G, -13), 1.2)
	P.plant(m, Vector3.new(-21, G, -67), 1)
	P.plant(m, Vector3.new(21, G, -66), 1)
	U.picture(m, CFrame.lookAt(Vector3.new(-23.4, 11, -44), Vector3.new(0, 11, -44)), 6, 4)
	U.picture(m, CFrame.lookAt(Vector3.new(23.4, 11, -50), Vector3.new(0, 11, -50)), 5, 4)
	-- notice board (Board)
	local boardCF = CFrame.lookAt(Vector3.new(-23.3, 9.5, -52), Vector3.new(0, 9.5, -52))
	U.part(m, Vector3.new(6.6, 4.6, 0.3), boardCF * CFrame.new(0, 0, 0.1), C.woodDark, M.Wood)
	local board = U.sign(m, "📌 NOTICE BOARD\nIncidents & news", boardCF * CFrame.new(0, 0, -0.1), 6, 4, { bg = rgb(186, 140, 90), fg = C.white, mat = M.Fabric, font = Enum.Font.GothamBold, thick = 0.12 })
	U.interact(board, "Board", "Board_Lobby", "Lobby", "Notice Board")
	-- chandeliers
	for _, z in { -22, -38, -54 } do
		P.chandelier(m, Vector3.new(0, 19.6, z), z == -38 and 3.6 or 2.8)
	end
	for _, c in { { -18, -14 }, { 18, -14 }, { -18, -62 }, { 18, -62 } } do
		U.downlight(m, c[1], 19.6, c[2], 18, 0.6)
	end
	-- lobby camera
	local cam = P.securityCam(m, Vector3.new(22.5, 17.5, -11.5), Vector3.new(0, 5, -45))
	U.interact(cam, "Camera", "Cam_Lobby", "Lobby", "Security Camera", { CamId = "Cam_Lobby" })
	-- stair hall: grand staircase to floor 2
	U.stairs(m, Vector3.new(48, G, -14), Vector3.new(0, 0, -1), 8, 21, 0.8, 1.3, C.marble, M.Marble, C.gold)
	for _, x in { 44.4, 51.6 } do
		U.beam(m, Vector3.new(x, G + 3.4, -13.4), Vector3.new(x, F2 + 3.4, -41), 0.35, C.gold, M.Metal)
		for k = 0, 5 do
			local zz = -14 - k * 5
			local top = G + 3.4 + (-14 - zz) / 27.3 * 16.8
			U.vcyl(m, x, G + (-14 - zz) / 1.3 * 0.8, zz, top, 0.2, C.gold, M.Metal, NOCOL)
		end
	end
	-- wall under the stair runner (hides the stair's open side to the east wall)
	P.plant(m, Vector3.new(30, G, -14), 1.1)
	P.plant(m, Vector3.new(30, G, -56), 1)
	P.sofa(m, CFrame.lookAt(Vector3.new(26.8, G, -47), Vector3.new(40, G, -47)), 7, C.teal, C.cream)
	U.picture(m, CFrame.lookAt(Vector3.new(24.6, 11, -47), Vector3.new(40, 11, -47)), 6, 4)
	U.signAt(m, "▲ GUEST ROOMS  •  ROOFTOP", Vector3.new(48, 16.4, -10.7), Vector3.new(0, 0, -1), 10, 1.4, { bg = C.tealDeep, fg = C.gold, font = Enum.Font.GothamBold })
	U.signAt(m, "SECURITY  —  AUTHORIZED STAFF ONLY", Vector3.new(36, 16.5, -59.4), Vector3.new(0, 0, 1), 12, 1.4, { bg = C.navy, fg = C.white, font = Enum.Font.GothamBold })
	P.chandelier(m, Vector3.new(36, 19.6, -30), 2.4)

	ctx.npc("Receptionist", Vector3.new(0, G, -66.5))
	ctx.npc("DoorGuard", Vector3.new(40, G, -55))
	ctx.npc("Janitor", Vector3.new(-30, G, -60))
	ctx.mark("DetentionCell", Vector3.new(53, G, -94))
	ctx.mark("DetentionExit", Vector3.new(36, G, -52))
	ctx.item("Lobby", Vector3.new(-18, G, -40))
	ctx.item("Lobby", Vector3.new(34, G, -20))
	ctx.wander("Lobby", Vector3.new(-8, G, -28))
	ctx.wander("Lobby", Vector3.new(10, G, -50))
	ctx.wander("Lobby", Vector3.new(34, G, -34))
	ctx.guard(1, 1, Vector3.new(0, G, -16))
	ctx.guard(1, 2, Vector3.new(-18, G, -55))
	ctx.guard(1, 3, Vector3.new(-40, G, -22))
	ctx.guard(1, 4, Vector3.new(-18, G, -22))
	ctx.guard(1, 5, Vector3.new(34, G, -48))
	ctx.guard(1, 6, Vector3.new(34, G, -18))

	------------------------------------------------------------------ HOTEL BAR
	P.counter(m, -56, -45, -32, -41.5, G, 4.2, C.woodDark, C.marble)
	local barTop = U.box(m, -36, G + 4.2, -44.5, -33, G + 4.4, -42, C.marble, M.Marble, NOCOL)
	U.interact(barTop, "Food", "Food_HotelBar", "HotelBar", "Order a Drink")
	-- back shelf with bottles
	U.box(m, -57, G, -49.5, -31, G + 3.6, -47.5, C.woodDark, M.Wood)
	for row = 0, 1 do
		U.box(m, -57, G + 6 + row * 2.6, -49.5, -31, G + 6.25 + row * 2.6, -47.8, C.gold, M.Metal)
		for k = 0, 10 do
			local x = -56 + k * 2.3
			local col = ({ rgb(60, 140, 70), rgb(160, 80, 40), C.glass, rgb(140, 30, 50), rgb(230, 200, 120) })[(k + row) % 5 + 1]
			U.vcyl(m, x, G + 6.25 + row * 2.6, -48.6, G + 7.9 + row * 2.6, 0.6, col, M.Glass, { CanCollide = false, Transparency = 0.15 })
		end
	end
	local barNeon = U.part(m, Vector3.new(10, 2.2, 0.3), CFrame.new(-44, G + 13, -49.3), C.neonPink, M.Neon, NOCOL)
	U.tag(barNeon, "ResortNeon")
	U.addGui(barNeon, Enum.NormalId.Front, "SUNSET BAR", { fg = C.white, font = Enum.Font.FredokaOne, pps = 25 })
	U.light(barNeon, C.neonPink, 14, 0.8)
	for k = 0, 5 do
		P.stool(m, Vector3.new(-53 + k * 3.8, G, -39.3), C.teal)
	end
	for _, x in { -52, -42, -32 } do
		U.vcyl(m, x, 15, -43, 19.6, 0.12, C.gold, M.Metal, NOCOL)
		local shade = U.vcyl(m, x, 14, -43, 15.2, 2, C.gold, M.Metal, { CanCollide = false, Reflectance = 0.2 })
		U.light(shade, rgb(255, 214, 160), 12, 0.9)
	end
	local napkinTable
	for i, c in { { -52, -26 }, { -40, -18 }, { -30, -18 } } do
		local t = P.roundTable(m, Vector3.new(c[1], G, c[2]), 4, 3, C.marble)
		P.chair(m, CFrame.lookAt(Vector3.new(c[1] - 3.2, G, c[2]), Vector3.new(c[1], G, c[2])), C.coral)
		P.chair(m, CFrame.lookAt(Vector3.new(c[1] + 3.2, G, c[2]), Vector3.new(c[1], G, c[2])), C.coral)
		if i == 2 then
			napkinTable = t
		end
	end
	local napkin = U.part(m, Vector3.new(1, 0.08, 1), CFrame.new(-40, G + 3.04, -18) * CFrame.Angles(0, 0.4, 0), C.paper, M.Fabric, NOCOL)
	U.interact(napkin, "Note", "Note_ReceptionCode", "HotelBar", "Napkin", { Text = "Scribbled on a napkin: \"Reception office code — 0427. Don't forget again! — R.\"" })
	local barPhone = P.phone(m, Vector3.new(-54, G + 4.2, -43.2), 0)
	U.interact(barPhone, "Phone", "Phone_HotelBar", "HotelBar", "Bar Phone")
	local barBin = P.cabinet(m, CFrame.lookAt(Vector3.new(-26.5, G, -46), Vector3.new(-40, G, -46)), 3, 3.4, 2.2, C.woodDark)
	U.interact(barBin, "Search", "S_BarCabinet", "HotelBar", "Drinks Fridge", { Loot = "Champagne" })
	U.picture(m, CFrame.lookAt(Vector3.new(-59.3, 11, -40), Vector3.new(0, 11, -40)), 5, 4)
	P.plant(m, Vector3.new(-57, G, -13), 1)
	ctx.npc("Bartender", Vector3.new(-44, G, -46.3))
	ctx.item("HotelBar", Vector3.new(-48, G, -20))
	ctx.wander("HotelBar", Vector3.new(-45, G, -32))

	------------------------------------------------------------------ HOUSEKEEPING (+ storage x<-42)
	for k = 0, 2 do
		local x = -38 + k * 5
		U.rel(m, CFrame.new(x, G, -97.6), 0, 2.4, 0, 4.4, 4.8, 3.6, C.white, M.SmoothPlastic)
		U.cyl(m, CFrame.new(x, G + 2.6, -95.75) * CFrame.Angles(0, math.pi / 2, 0), 0.2, 2.6, C.glass, M.Glass, NOCOL)
		U.cyl(m, CFrame.new(x, G + 2.6, -95.78) * CFrame.Angles(0, math.pi / 2, 0), 0.15, 3, C.steel, M.Metal, NOCOL)
	end
	-- towel shelves
	U.box(m, -41.4, G, -66, -39.4, G + 8, -54, C.woodLight, M.Wood)
	for row = 0, 2 do
		for k = 0, 3 do
			U.box(m, -39.3, G + 1.2 + row * 2.4, -65 + k * 3, -38.4, G + 2.4 + row * 2.4, -63 + k * 3, ({ C.white, C.teal, C.coral })[row + 1], M.Fabric, NOCOL)
		end
	end
	-- laundry carts
	local cart = U.box(m, -32, G + 0.8, -88, -28, G + 4, -84, C.white, M.Fabric)
	U.box(m, -32.2, G + 3.8, -88.2, -27.8, G + 4.2, -83.8, C.steel, M.Metal, NOCOL)
	for _, o in { { -31.6, -87.6 }, { -28.4, -87.6 }, { -31.6, -84.4 }, { -28.4, -84.4 } } do
		U.ball(m, Vector3.new(o[1], G + 0.4, o[2]), 0.8, C.black, M.SmoothPlastic, NOCOL)
	end
	U.interact(cart, "Hide", "H_LaundryCart", "Housekeeping", "Laundry Cart")
	local lockerA = U.box(m, -29, G, -54, -25, G + 8, -51.6, rgb(90, 140, 170), M.Metal)
	U.interact(lockerA, "Search", "S_StaffLockers", "Housekeeping", "Staff Lockers", { Loot = "SecurityCard" })
	for k = 0, 1 do
		U.box(m, -28.8 + k * 2, G + 0.2, -51.65, -27.2 + k * 2, G + 7.8, -51.5, rgb(110, 160, 190), M.Metal, NOCOL)
	end
	-- storage room
	for k = 0, 2 do
		local z = -96 + k * 8
		U.box(m, -59.4, G, z - 3, -55.4, G + 9, z + 3, C.woodLight, M.Wood)
		for row = 0, 2 do
			U.box(m, -59.2, G + 1 + row * 2.8, z - 2.6, -55.6, G + 1.2 + row * 2.8, z + 2.6, C.woodDark, M.Wood, NOCOL)
		end
	end
	local box1 = P.crate(m, CFrame.new(-46, G, -58), 3)
	U.interact(box1, "Search", "S_StorageBox1", "Housekeeping", "Storage Box")
	local box2 = P.crate(m, CFrame.new(-51, G, -63) * CFrame.Angles(0, 0.3, 0), 2.6, C.wood)
	U.interact(box2, "Search", "S_StorageBox2", "Housekeeping", "Storage Box", { Loot = "Flashlight" })
	P.crate(m, CFrame.new(-46, G + 3, -58) * CFrame.Angles(0, 0.4, 0), 2, C.woodLight)
	local closet = P.wardrobe(m, CFrame.lookAt(Vector3.new(-43.9, G, -86), Vector3.new(-50, G, -86)), C.white)
	U.interact(closet, "Hide", "H_StorageCloset", "Housekeeping", "Supply Closet")
	U.signAt(m, "HOUSEKEEPING", Vector3.new(-33, 15, -50.6), Vector3.new(0, 0, -1), 9, 1.4, { bg = C.teal, fg = C.white, font = Enum.Font.GothamBold })
	U.downlight(m, -33, 19.6, -75, 22, 0.8)
	U.downlight(m, -51, 19.6, -75, 22, 0.8)
	ctx.item("Housekeeping", Vector3.new(-50, G, -80))
	ctx.wander("Housekeeping", Vector3.new(-34, G, -70))

	------------------------------------------------------------------ RECEPTION OFFICE
	P.counter(m, -8, -92, 8, -88, G, 3.2, C.woodDark, C.marble)
	P.chair(m, CFrame.lookAt(Vector3.new(0, G, -94.5), Vector3.new(0, G, -88)), C.teal)
	local rcomp = P.computer(m, CFrame.lookAt(Vector3.new(0, G + 3.2, -90), Vector3.new(0, G + 3.2, -96)), "GUEST LIST")
	U.interact(rcomp, "Computer", "PC_Reception", "Reception", "Reception Computer", { Role = "Reception" })
	local keyBoard = U.part(m, Vector3.new(8, 5, 0.4), CFrame.lookAt(Vector3.new(-12, 11, -99.2), Vector3.new(-12, 11, -90)), C.woodDark, M.Wood)
	for r = 0, 2 do
		for k = 0, 4 do
			U.part(m, Vector3.new(0.4, 0.8, 0.15), CFrame.new(-15 + k * 1.5, 12.4 - r * 1.4, -98.9), C.gold, M.Metal, NOCOL)
		end
	end
	U.interact(keyBoard, "Search", "S_KeyBoard", "Reception", "Key Board", { Loot = "MasterKey" })
	local filing = P.cabinet(m, CFrame.lookAt(Vector3.new(14, G, -98), Vector3.new(14, G, -90)), 3, 5, 2.4, C.steel, C.darkSteel)
	U.interact(filing, "Search", "S_FilingCabinet", "Reception", "Filing Cabinet", { Loot = "SecretLetter" })
	local rDrawer = P.cabinet(m, CFrame.lookAt(Vector3.new(19, G, -98), Vector3.new(19, G, -90)), 3, 3, 2.4, C.woodDark)
	U.interact(rDrawer, "Search", "S_ReceptionDrawer", "Reception", "Desk Drawer")
	P.sofa(m, CFrame.lookAt(Vector3.new(-19.6, G, -84), Vector3.new(0, G, -84)), 7, C.teal, C.cream)
	P.plant(m, Vector3.new(21, G, -73), 1)
	U.picture(m, CFrame.lookAt(Vector3.new(23.4, 12, -84), Vector3.new(0, 12, -84)), 6, 3.6)
	U.downlight(m, 0, 19.6, -84, 22, 0.8)
	ctx.item("Reception", Vector3.new(10, G, -80))

	------------------------------------------------------------------ SECURITY ROOM
	-- monitor wall 3x3
	local camNames = { "LOBBY", "ARCADE", "VIP", "JEWELRY", "POOL", "RESTAURANT", "HALLWAY 2F", "DOCK", "SHOPS" }
	U.box(m, 25, 7.5, -99.4, 45, 18.5, -98.8, C.black, M.SmoothPlastic)
	for r = 0, 2 do
		for k = 0, 2 do
			local i = r * 3 + k + 1
			local scr = U.part(m, Vector3.new(6, 3.2, 0.2), CFrame.lookAt(Vector3.new(28.6 + k * 6.4, 16.6 - r * 3.6, -98.7), Vector3.new(28.6 + k * 6.4, 16.6 - r * 3.6, -90)), rgb(20, 40, 70), M.Glass, NOCOL)
			U.addGui(scr, Enum.NormalId.Front, "● REC  CAM " .. i .. "\n" .. camNames[i], { fg = rgb(140, 220, 255), font = Enum.Font.GothamBold, pps = 30, textH = 0.6, brightness = 1.5 })
		end
	end
	P.counter(m, 26, -96, 46, -92.5, G, 3.2, C.darkSteel, C.black)
	local scomp = P.computer(m, CFrame.lookAt(Vector3.new(34, G + 3.2, -94), Vector3.new(34, G + 3.2, -88)), "SECURITY")
	U.interact(scomp, "Computer", "PC_Security", "SecurityRoom", "Security Console", { Role = "Security" })
	P.computer(m, CFrame.lookAt(Vector3.new(40, G + 3.2, -94), Vector3.new(40, G + 3.2, -88)), "DOORS")
	local alarm = U.vcyl(m, 29, G + 3.2, -94, G + 3.7, 1.2, C.red, M.SmoothPlastic, NOCOL)
	U.vcyl(m, 29, G + 3.2, -94, G + 3.35, 1.8, C.yellow, M.SmoothPlastic, NOCOL)
	U.interact(alarm, "Alarm", "Alarm_Security", "SecurityRoom", "Alarm Button")
	P.chair(m, CFrame.lookAt(Vector3.new(34, G, -90), Vector3.new(34, G, -96)), C.navy)
	P.chair(m, CFrame.lookAt(Vector3.new(40, G, -90), Vector3.new(40, G, -96)), C.navy)
	local sLocker = U.box(m, 55, G, -85.4, 59.4, G + 8, -76.4, rgb(70, 90, 120), M.Metal)
	for k = 0, 2 do
		U.box(m, 54.9, G + 0.2, -85 + k * 3, 55, G + 7.8, -82.8 + k * 3, rgb(90, 112, 146), M.Metal, NOCOL)
	end
	U.interact(sLocker, "Search", "S_SecurityLockers", "SecurityRoom", "Guard Lockers", { Loot = "Flashlight" })
	local evid = P.cabinet(m, CFrame.lookAt(Vector3.new(27, G, -66), Vector3.new(34, G, -66)), 3, 4.4, 2.4, C.steel, C.darkSteel)
	U.interact(evid, "Search", "S_EvidenceCabinet", "SecurityRoom", "Evidence Cabinet")
	U.box(m, 47, G, -99.4, 59.4, G + 1.8, -96.6, C.steel, M.Metal) -- cell bench
	U.signAt(m, "SECURITY CONTROL", Vector3.new(35, 19, -98.6), Vector3.new(0, 0, 1), 12, 1.2, { bg = C.navy, fg = C.neonBlue, font = Enum.Font.GothamBold, transparent = true })
	U.downlight(m, 34, 19.6, -78, 24, 0.8)
	U.downlight(m, 53, 19.6, -93, 14, 0.6)
	ctx.item("SecurityRoom", Vector3.new(44, G, -70))

	------------------------------------------------------------------ FLOOR 2: guest rooms
	for i, cx in { -45, -15, 15, 45 } do
		local col = roomColors[i]
		P.bed(m, CFrame.lookAt(Vector3.new(cx, F2, -95), Vector3.new(cx, F2, -80)), col)
		local ns1 = P.cabinet(m, CFrame.lookAt(Vector3.new(cx - 5.4, F2, -97.6), Vector3.new(cx - 5.4, F2, -90)), 2.4, 2.4, 2, C.woodDark)
		local ns2 = P.cabinet(m, CFrame.lookAt(Vector3.new(cx + 5.4, F2, -97.6), Vector3.new(cx + 5.4, F2, -90)), 2.4, 2.4, 2, C.woodDark)
		P.tableLamp(m, Vector3.new(cx - 5.4, F2 + 2.56, -97.6), C.cream)
		P.tableLamp(m, Vector3.new(cx + 5.4, F2 + 2.56, -98.1), C.cream)
		U.interact(ns1, "Search", "S_Room20" .. i .. "_NS", "GuestRooms", "Nightstand")
		if i % 2 == 1 then
			local wr = P.wardrobe(m, CFrame.lookAt(Vector3.new(cx + 12.4, F2, -72), Vector3.new(cx, F2, -72)), C.woodLight)
			U.interact(wr, "Hide", "H_Room20" .. i .. "_Wardrobe", "GuestRooms", "Wardrobe")
			local ph = P.phone(m, Vector3.new(cx + 5.4, F2 + 2.56, -96.9), 0)
			U.interact(ph, "Phone", "Phone_Room20" .. i, "GuestRooms", "Room Phone")
		else
			local suitcase = U.box(m, cx + 9, F2, -70, cx + 12.5, F2 + 2.4, -67.6, col, M.SmoothPlastic)
			U.box(m, cx + 10.2, F2 + 2.4, -69, cx + 11.3, F2 + 2.8, -68.6, C.black, M.SmoothPlastic, NOCOL)
			U.interact(suitcase, "Search", "S_Room20" .. i .. "_Suitcase", "GuestRooms", "Suitcase", i == 4 and { Loot = "Briefcase" } or nil)
		end
		-- desk + chair under the side wall, rug, art, light
		P.counter(m, cx - 13.6, -76, cx - 11, -68, F2, 3, C.woodDark, C.marble)
		P.chair(m, CFrame.lookAt(Vector3.new(cx - 9.2, F2, -72), Vector3.new(cx - 13, F2, -72)), col)
		U.rug(m, cx - 7, -88, cx + 7, -78, F2, col:Lerp(C.white, 0.4), C.gold)
		U.picture(m, CFrame.lookAt(Vector3.new(cx, F2 + 9.6, -99.3), Vector3.new(cx, F2 + 9.6, -90)), 7, 2.4)
		U.downlight(m, cx, 36.6, -80, 22, 0.75)
		P.plant(m, Vector3.new(cx + 11.5, F2, -96.5), 0.8)
		ctx.item("GuestRooms", Vector3.new(cx - 6, F2, -66))
	end
	ctx.wander("GuestRooms", Vector3.new(-15, F2, -78))
	-- suite 205
	P.bed(m, CFrame.lookAt(Vector3.new(-50, F2, -42), Vector3.new(-50, F2, -20)), C.purple)
	local minibar = P.cabinet(m, CFrame.lookAt(Vector3.new(-23, F2, -44), Vector3.new(-30, F2, -44)), 3, 3.2, 2.4, C.woodDark)
	U.interact(minibar, "Search", "S_SuiteMinibar", "GuestRooms", "Minibar", { Loot = "Champagne" })
	local safe = U.box(m, -58.8, F2, -24, -56, F2 + 3, -21, C.darkSteel, M.DiamondPlate)
	U.cyl(m, CFrame.new(-55.9, F2 + 1.6, -22.5), 0.2, 1, C.gold, M.Metal, NOCOL)
	U.interact(safe, "Search", "S_SuiteSafe", "GuestRooms", "Room Safe", { Loot = "VIPKeycard" })
	P.sofa(m, CFrame.lookAt(Vector3.new(-36, F2, -14), Vector3.new(-36, F2, -30)), 8, C.cream, C.purple)
	P.coffeeTable(m, CFrame.new(-36, F2, -20), 5, 3)
	U.rug(m, -44, -26, -28, -12, F2, C.lavender, C.gold)
	local wr5 = P.wardrobe(m, CFrame.lookAt(Vector3.new(-23, F2, -32), Vector3.new(-30, F2, -32)), C.white)
	U.interact(wr5, "Hide", "H_SuiteWardrobe", "GuestRooms", "Wardrobe")
	U.picture(m, CFrame.lookAt(Vector3.new(-50, F2 + 9.5, -47.4), Vector3.new(-50, F2 + 9.5, -30)), 7, 2.4)
	P.chandelier(m, Vector3.new(-40, 36.6, -28), 2.4)
	-- hallway
	U.rug(m, -58.5, -56.5, 22, -49.5, F2, C.red, C.gold)
	U.signAt(m, "GUEST ROOMS 201 – 205", Vector3.new(40, F2 + 11, -57.4), Vector3.new(0, 0, 1), 12, 1.4, { bg = C.tealDeep, fg = C.gold, font = Enum.Font.GothamBold })
	U.signAt(m, "BALCONY", Vector3.new(0, F2 + 12.4, -10.7), Vector3.new(0, 0, -1), 6, 1.1, { bg = C.tealDeep, fg = C.gold, font = Enum.Font.GothamBold })
	for _, x in { -52, -30, 0, 30 } do
		U.downlight(m, x, 36.6, -53, 18, 0.6)
	end
	for _, x in { -30, 0 } do
		P.counter(m, x - 2.5, -57.4, x + 2.5, -55.8, F2, 3, C.woodDark, C.marble)
		P.tableLamp(m, Vector3.new(x - 1.4, F2 + 3, -56.6), C.cream)
		U.picture(m, CFrame.lookAt(Vector3.new(x, F2 + 8, -57.4), Vector3.new(x, F2 + 8, -50)), 4, 3)
	end
	local cam2 = P.securityCam(m, Vector3.new(58.5, 34.5, -57), Vector3.new(-20, F2, -53))
	U.interact(cam2, "Camera", "Cam_Hallway", "GuestRooms", "Security Camera", { CamId = "Cam_Hallway" })
	-- lounge
	elevatorPanel(Vector3.new(-19.15, F2 + 5, -38), Vector3.new(1, 0, 0), "Elev_2A", "Elev_G", "▼ G", "GuestRooms")
	elevatorPanel(Vector3.new(-19.15, F2 + 5, -24), Vector3.new(1, 0, 0), "Elev_2B", "Elev_R", "▲ R", "GuestRooms")
	U.rug(m, -6, -40, 14, -22, F2, C.teal, C.gold)
	P.sofa(m, CFrame.lookAt(Vector3.new(4, F2, -40), Vector3.new(4, F2, -20)), 10, C.cream, C.coral)
	P.coffeeTable(m, CFrame.new(4, F2, -31), 6, 3.4)
	P.chair(m, CFrame.lookAt(Vector3.new(-3, F2, -30), Vector3.new(4, F2, -31)), C.coral)
	P.chair(m, CFrame.lookAt(Vector3.new(11, F2, -30), Vector3.new(4, F2, -31)), C.coral)
	-- grand piano
	U.box(m, 13, F2 + 2.6, -24, 20, F2 + 3.6, -17, C.black, M.SmoothPlastic, { Reflectance = 0.2 })
	U.vcyl(m, 16.5, F2 + 2.6, -17, F2 + 3.6, 7, C.black, M.SmoothPlastic, { Reflectance = 0.2 })
	for _, o in { { 13.6, -23.4 }, { 19.4, -23.4 }, { 16.5, -15 } } do
		U.vcyl(m, o[1], F2, o[2], F2 + 2.6, 0.5, C.black, M.SmoothPlastic)
	end
	U.box(m, 13, F2 + 3.2, -25, 20, F2 + 3.4, -24, C.white, M.SmoothPlastic, NOCOL)
	P.plant(m, Vector3.new(21.5, F2, -45), 1.1)
	P.plant(m, Vector3.new(-16.5, F2, -13), 1.1)
	P.chandelier(m, Vector3.new(2, 36.6, -30), 3)
	ctx.item("GuestRooms", Vector3.new(8, F2, -16))
	ctx.wander("GuestRooms", Vector3.new(0, F2, -53))
	ctx.wander("GuestRooms", Vector3.new(30, F2, -50))
	-- landing: railings around the stair hole + stair to roof
	U.rail(m, 44, -41.3, 44, -12, F2, 3.6)
	U.rail(m, 52, -41.3, 52, -12, F2, 3.6)
	U.rail(m, 44, -12, 52, -12, F2, 3.6)
	U.stairs(m, Vector3.new(38, F2, -16), Vector3.new(0, 0, -1), 8, 20, 0.85, 1.4, C.marble, M.Marble, C.gold)
	for _, x in { 34.4, 41.6 } do
		U.beam(m, Vector3.new(x, F2 + 3.4, -16.6), Vector3.new(x, RF + 3.4, -43.6), 0.35, C.gold, M.Metal)
	end
	U.signAt(m, "▲ ROOFTOP", Vector3.new(30, F2 + 9, -10.7), Vector3.new(0, 0, -1), 6, 1.2, { bg = C.tealDeep, fg = C.gold, font = Enum.Font.GothamBold })
	P.plant(m, Vector3.new(57, F2, -45), 1)
	P.plant(m, Vector3.new(56, F2, -14), 1)

	------------------------------------------------------------------ ROOFTOP
	-- railings round the roof stair hole
	U.rail(m, 34, -44, 34, -16, RF, 3.6)
	U.rail(m, 42, -44, 42, -16, RF, 3.6)
	U.rail(m, 34, -16, 42, -16, RF, 3.6)
	-- helipad
	U.vcyl(m, -30, RF, -62, RF + 0.4, 34, C.concreteDark, M.Concrete)
	U.vcyl(m, -30, RF + 0.4, -62, RF + 0.5, 30, rgb(80, 82, 86), M.Concrete, NOCOL)
	U.vcyl(m, -30, RF + 0.5, -62, RF + 0.55, 22, C.yellow, M.SmoothPlastic, NOCOL)
	U.vcyl(m, -30, RF + 0.55, -62, RF + 0.6, 20.6, rgb(80, 82, 86), M.Concrete, NOCOL)
	U.box(m, -34, RF + 0.6, -67, -32.4, RF + 0.65, -57, C.white, M.SmoothPlastic, NOCOL)
	U.box(m, -27.6, RF + 0.6, -67, -26, RF + 0.65, -57, C.white, M.SmoothPlastic, NOCOL)
	U.box(m, -32.4, RF + 0.6, -62.8, -27.6, RF + 0.65, -61.2, C.white, M.SmoothPlastic, NOCOL)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local l = U.ball(m, Vector3.new(-30 + math.cos(a) * 16.4, RF + 0.6, -62 + math.sin(a) * 16.4), 0.7, C.neonYellow, M.Neon, NOCOL)
		U.tag(l, "ResortNeon")
	end
	-- lounge deck
	U.box(m, 0, RF, -96, 56, RF + 0.3, -50, C.woodLight, M.WoodPlanks)
	-- hot tub
	U.vcyl(m, 30, RF + 0.3, -74, RF + 2.8, 14, C.white, M.Marble, { Reflectance = 0.06 })
	U.vcyl(m, 30, RF + 2.4, -74, RF + 2.65, 12.4, C.turquoise, M.Glass, { CanCollide = false, Transparency = 0.25 })
	U.vcyl(m, 30, RF + 2.8, -74, RF + 3, 14.4, C.gold, M.Metal, NOCOL)
	local tubLight = U.ball(m, Vector3.new(30, RF + 1.6, -74), 1, C.turquoise, M.Neon, NOCOL)
	U.light(tubLight, C.turquoise, 14, 1)
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		P.lounger(m, CFrame.lookAt(Vector3.new(30 + math.cos(a) * 13, RF + 0.3, -74 + math.sin(a) * 13), Vector3.new(30, RF + 0.3, -74)) * CFrame.Angles(0, math.pi, 0), C.coral)
	end
	P.umbrella(m, Vector3.new(14, RF + 0.3, -60), C.coral, C.white)
	P.umbrella(m, Vector3.new(48, RF + 0.3, -92), C.teal, C.white)
	P.sofa(m, CFrame.lookAt(Vector3.new(10, RF + 0.3, -92), Vector3.new(10, RF + 0.3, -80)), 10, C.cream, C.coral)
	P.coffeeTable(m, CFrame.new(10, RF + 0.3, -85), 6, 3)
	-- rooftop bar counter
	P.counter(m, 44, -60, 56, -56, RF + 0.3, 4, C.tealDeep, C.marble)
	for k = 0, 2 do
		P.stool(m, Vector3.new(46 + k * 4, RF + 0.3, -53.5), C.coral)
	end
	for _, c in { { 2, -94 }, { 54, -94 }, { 2, -52 }, { -56, -14 }, { 56, -14 }, { -56, -96 } } do
		local onDeck = c[1] >= 0 and c[1] <= 56 and c[2] >= -96 and c[2] <= -50
		P.plant(m, Vector3.new(c[1], RF + (onDeck and 0.3 or 0), c[2]), 1.2)
	end
	-- string lights from posts
	local posts = { Vector3.new(1, RF, -51), Vector3.new(57, RF, -51), Vector3.new(57, RF, -97), Vector3.new(1, RF, -97) }
	for i, pp in posts do
		U.vcyl(m, pp.X, RF, pp.Z, RF + 10, 0.4, C.darkSteel, M.Metal)
		local nx = posts[i % 4 + 1]
		U.beam(m, pp + Vector3.new(0, 10, 0), nx + Vector3.new(0, 10, 0), 0.08, C.black, M.SmoothPlastic, NOCOL)
		for k = 1, 5 do
			local bp = pp:Lerp(nx, k / 6) + Vector3.new(0, 9.7, 0)
			local b = U.ball(m, bp, 0.45, C.neonYellow, M.Neon, NOCOL)
			U.tag(b, "ResortNeon")
		end
	end
	-- elevator kiosk
	U.box(m, -22, RF, -36, -10, RF + 11, -26, C.cream, M.SmoothPlastic)
	U.box(m, -22.4, RF + 11, -36.4, -9.6, RF + 11.6, -25.6, C.gold, M.Metal)
	elevatorPanel(Vector3.new(-16, RF + 5, -25.75), Vector3.new(0, 0, 1), "Elev_R", "Elev_2B", "▼ 2", "Rooftop")
	U.signAt(m, "ROOFTOP LOUNGE", Vector3.new(-16, RF + 9.6, -25.7), Vector3.new(0, 0, 1), 10, 1.4, { bg = C.tealDeep, fg = C.gold, font = Enum.Font.FredokaOne, thick = 0.2 })
	ctx.item("Rooftop", Vector3.new(20, RF + 0.3, -90))
	ctx.item("Rooftop", Vector3.new(-40, RF, -30))
	ctx.wander("Rooftop", Vector3.new(14, RF + 0.3, -68))
	ctx.wander("Rooftop", Vector3.new(-30, RF + 0.4, -62))
end

return Hotel
