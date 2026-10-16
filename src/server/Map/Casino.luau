--!nocheck
-- Casino: x[-175,-90] z[-100,-20]. Main floor (slots, card tables, roulette, prize counter, cashier window),
-- VIP lounge (keycard), Back Room (code), cashier cage.
local Casino = {}

function Casino.build(ctx)
	local U, P = ctx.U, ctx.P
	local C, M = U.C, U.M
	local m = ctx.model("Casino")
	local G = ctx.G
	local NOCOL = P.NOCOL
	local rgb = Color3.fromRGB
	local X1, X2, Z1, Z2 = -175, -90, -100, -20
	local H = 21.8
	local TOP = G + H
	local WALL = rgb(250, 238, 222)
	local INT = { frame = C.gold, base = C.redDark, crown = C.gold }
	local EXT = { frame = C.gold, glass = rgb(150, 190, 230), mullion = 4 }
	local function win(c, w, b, h)
		return { c = c, w = w or 8, b = b or 3, h = h or 12, glass = true }
	end

	------------------------------------------------------------------ shell
	U.box(m, X1, 0, -70, X2, G, Z2, C.redDark, M.Fabric) -- carpeted main floor
	U.box(m, X1, 0, Z1, -135, G, -70, C.purpleDark, M.Fabric)
	U.box(m, -135, 0, Z1, X2, G, -70, rgb(110, 100, 92), M.WoodPlanks)
	U.skirt(m, X1 - 0.6, Z1 - 0.6, X2 + 0.6, Z2 + 0.6)
	-- carpet pattern: gold diamonds in a grid
	for x = -165, -100, 13 do
		for z = -62, -28, 11 do
			U.part(m, Vector3.new(1.6, 0.06, 1.6), CFrame.new(x, G + 0.03, z) * CFrame.Angles(0, math.rad(45), 0), C.gold, M.Fabric, { CanCollide = false, CastShadow = false })
		end
	end
	U.wall(m, X1, Z2, X2, Z2, G, H, 1.2, WALL, M.SmoothPlastic, { win(-165), win(-150), { c = -130, w = 16, h = 13 }, win(-110), win(-98, 6) }, EXT)
	U.wall(m, X1, Z1, X2, Z1, G, H, 1.2, WALL, M.SmoothPlastic, { { c = -160, w = 8, h = 11 }, win(-120, 6, 6, 6) }, EXT)
	U.wall(m, X1, Z1, X1, Z2, G, H, 1.2, WALL, M.SmoothPlastic, { win(-30), win(-45), win(-60), win(-85, 8, 6, 8) }, EXT)
	U.wall(m, X2, Z1, X2, Z2, G, H, 1.2, WALL, M.SmoothPlastic, { win(-28, 6), { c = -40, w = 8, h = 11 }, win(-55), win(-85, 8, 6, 8) }, EXT)
	-- interior walls
	U.wall(m, X1, -70, X2, -70, G, H, 1, rgb(96, 20, 40), M.SmoothPlastic, { { c = -155, w = 8, h = 11 }, { c = -122, w = 8, h = 11 }, { c = -100, w = 12, h = 4.4, b = 3.0, glass = true } }, INT)
	U.wall(m, -135, Z1, -135, -70, G, H, 1, rgb(96, 20, 40), M.SmoothPlastic, {}, INT)
	U.wall(m, -110, Z1, -110, -70, G, H, 1, C.concreteDark, M.Concrete, { { c = -85, w = 8, h = 11 } }, INT)
	-- roof
	U.box(m, X1 - 0.6, TOP, Z1 - 0.6, X2 + 0.6, TOP + 1, Z2 + 0.6, C.white, M.SmoothPlastic)
	U.box(m, X1 - 1, TOP + 1, Z1 - 1, X2 + 1, TOP + 3, Z1 + 0.2, WALL, M.SmoothPlastic)
	U.box(m, X1 - 1, TOP + 1, Z2 - 0.2, X2 + 1, TOP + 3, Z2 + 1, WALL, M.SmoothPlastic)
	U.box(m, X1 - 1, TOP + 1, Z1 + 0.2, X1 + 0.2, TOP + 3, Z2 - 0.2, WALL, M.SmoothPlastic)
	U.box(m, X2 - 0.2, TOP + 1, Z1 + 0.2, X2 + 1, TOP + 3, Z2 - 0.2, WALL, M.SmoothPlastic)
	U.box(m, X1 - 1.3, TOP + 3, Z2 - 0.3, X2 + 1.3, TOP + 3.5, Z2 + 1.3, C.gold, M.Metal, { Reflectance = 0.15 })
	-- gold horizontal band on the facade
	U.box(m, X1 - 0.8, G + 15.8, Z2 - 0.2, X2 + 0.8, G + 16.6, Z2 + 0.8, C.gold, M.Metal, { Reflectance = 0.15 })

	------------------------------------------------------------------ facade: neon sign + marquee canopy
	local signCF = CFrame.lookAt(Vector3.new(-130, TOP + 6.5, -18.4), Vector3.new(-130, TOP + 6.5, 0))
	U.part(m, Vector3.new(40, 8.6, 0.8), signCF * CFrame.new(0, 0, 0.6), C.purpleDark, M.SmoothPlastic)
	local neon = U.part(m, Vector3.new(38, 7, 0.3), signCF, C.neonPink, M.Neon, NOCOL)
	U.tag(neon, "ResortNeon")
	U.addGui(neon, Enum.NormalId.Front, "★ PALM ARCADE ★", { fg = C.white, font = Enum.Font.FredokaOne, pps = 20, stroke = 0.2, strokeColor = C.purpleDark })
	U.light(neon, C.neonPink, 30, 1.2)
	for k = 0, 12 do
		local x = -149 + k * (38 / 12)
		for _, y in { TOP + 2.1, TOP + 10.9 } do
			local b = U.ball(m, Vector3.new(x, y, -18.1), 0.6, C.neonYellow, M.Neon, NOCOL)
			U.tag(b, "ResortNeon")
		end
	end
	U.box(m, -129.5, TOP, -20, -130.5, TOP + 2.2, -18.6, C.gold, M.Metal)
	-- marquee canopy
	U.box(m, -141, G + 13.4, -20, -119, G + 14.6, -8, C.purpleDark, M.SmoothPlastic)
	U.box(m, -141.3, G + 14.6, -20, -118.7, G + 15.2, -7.7, C.gold, M.Metal, { Reflectance = 0.15 })
	for _, x in { -139.5, -120.5 } do
		U.column(m, x, G, -9.5, G + 13.4, 1.4, C.white, C.gold)
	end
	for k = 0, 10 do
		local b = U.ball(m, Vector3.new(-140 + k * 2, G + 13.2, -7.9), 0.45, C.neonYellow, M.Neon, NOCOL)
		U.tag(b, "ResortNeon")
	end
	for k = 0, 2 do
		U.downlight(m, -136 + k * 6, G + 13.4, -14, 16, 0.8)
	end
	U.rug(m, -134, -20, -126, -2, G, C.red, C.gold)
	for _, x in { -136, -124 } do
		for _, z in { -14, -6 } do
			U.vcyl(m, x, G, z, G + 3, 0.35, C.gold, M.Metal)
			U.ball(m, Vector3.new(x, G + 3.2, z), 0.6, C.gold, M.Metal, NOCOL)
		end
		U.beam(m, Vector3.new(x, G + 2.5, -14), Vector3.new(x, G + 2.5, -6), 0.25, C.red, M.Fabric, NOCOL)
	end
	P.palm(m, Vector3.new(-146, G - 0.5, -14), 20, 0.5, 2)
	P.palm(m, Vector3.new(-114, G - 0.5, -14), 21, 2.4, 2)
	U.signAt(m, "ARCADE", Vector3.new(-90.4, G + 13, -40), Vector3.new(1, 0, 0), 8, 1.6, { bg = C.purpleDark, fg = C.neonYellow, font = Enum.Font.FredokaOne, thick = 0.2 })

	------------------------------------------------------------------ main floor
	-- slot banks (6)
	local slotCols = { C.red, C.purple, rgb(30, 110, 200), C.red, C.purple, rgb(30, 110, 200) }
	local idx = 0
	for row = 0, 1 do
		for k = 0, 2 do
			idx += 1
			local pos = Vector3.new(row == 0 and -99 or -103, G, -64 + k * 5)
			local face = Vector3.new(row == 0 and 1 or -1, 0, 0)
			local slot = P.slot(m, CFrame.lookAt(pos, pos + face), idx, slotCols[idx])
			U.interact(slot, "Slot", "Slot_" .. idx, "Casino", "Arcade Machine")
		end
	end
	-- back-to-back panel between the two slot rows
	U.box(m, -101.6, G, -66.8, -100.4, G + 9, -51.2, C.purpleDark, M.SmoothPlastic)
	local slotSign = U.part(m, Vector3.new(0.3, 2, 14), CFrame.new(-101, G + 10.2, -59), C.neonYellow, M.Neon, NOCOL)
	U.tag(slotSign, "ResortNeon")
	U.addGui(slotSign, Enum.NormalId.Left, "GAMES", { fg = C.purpleDark, font = Enum.Font.FredokaOne, pps = 20 })
	U.addGui(slotSign, Enum.NormalId.Right, "GAMES", { fg = C.purpleDark, font = Enum.Font.FredokaOne, pps = 20 })
	-- card tables (2)
	for i, pos in { Vector3.new(-148, G, -36), Vector3.new(-148, G, -56) } do
		local t = P.cardTable(m, CFrame.lookAt(pos, pos + Vector3.new(0, 0, i == 1 and -1 or 1)))
		U.interact(t, "Cards", "Cards_" .. i, "Casino", "Game Table")
		local lamp = U.part(m, Vector3.new(6, 0.8, 3), CFrame.new(pos + Vector3.new(0, 12, 0)), C.felt, M.Glass, { CanCollide = false, Transparency = 0.1 })
		U.vcyl(m, pos.X, G + 12.4, pos.Z, TOP, 0.15, C.gold, M.Metal, NOCOL)
		U.spot(lamp, rgb(255, 236, 200), 16, 2, Enum.NormalId.Bottom, 80)
	end
	ctx.npc("Dealer", Vector3.new(-148, G, -31))
	-- roulette (decor)
	local rx, rz = -117, -60
	U.box(m, rx - 7, G, rz - 3, rx + 7, G + 2.8, rz + 3, C.woodDark, M.Wood)
	U.box(m, rx - 7.2, G + 2.8, rz - 3.2, rx + 7.2, G + 3.1, rz + 3.2, C.felt, M.Fabric)
	U.cyl(m, CFrame.new(rx - 4, G + 3.4, rz) * CFrame.Angles(0, 0, math.pi / 2), 0.6, 5, C.woodDark, M.Wood)
	U.cyl(m, CFrame.new(rx - 4, G + 3.6, rz) * CFrame.Angles(0, 0, math.pi / 2), 0.5, 4, C.red, M.SmoothPlastic, NOCOL)
	U.cyl(m, CFrame.new(rx - 4, G + 3.7, rz) * CFrame.Angles(0, 0, math.pi / 2), 0.5, 2.4, C.gold, M.Metal, NOCOL)
	for k = 0, 11 do
		U.box(m, rx - 1 + (k % 6) * 1.2, G + 3.1, rz - 2 + math.floor(k / 6) * 1.6, rx - 0.1 + (k % 6) * 1.2, G + 3.15, rz - 0.6 + math.floor(k / 6) * 1.6, (k % 2 == 0) and C.red or C.black, M.SmoothPlastic, NOCOL)
	end
	-- prize counter (west)
	P.counter(m, -172, -66, -167, -42, G, 4, C.purpleDark, C.marble)
	local prize = U.box(m, -167.6, G + 4, -56, -166.6, G + 4.6, -52, C.gold, M.Metal, NOCOL)
	U.interact(prize, "Prize", "Prize_Counter", "Casino", "Prize Counter")
	U.box(m, -174.4, G, -68, -172.6, G + 12, -40, C.woodDark, M.Wood)
	for row = 0, 2 do
		U.box(m, -172.6, G + 4.6 + row * 2.6, -68, -171, G + 4.9 + row * 2.6, -40, C.gold, M.Metal)
		for k = 0, 5 do
			local z = -65 + k * 4.4
			local col = ({ C.pink, C.sky, C.yellow, C.mint, C.lavender, C.coral })[(k + row) % 6 + 1]
			if (k + row) % 2 == 0 then
				U.ball(m, Vector3.new(-171.8, G + 5.8 + row * 2.6, z), 1.8, col, M.Fabric, NOCOL)
			else
				U.box(m, -172.4, G + 4.9 + row * 2.6, z - 0.8, -171.2, G + 6.5 + row * 2.6, z + 0.8, col, M.SmoothPlastic, NOCOL)
			end
		end
	end
	local prizeSign = U.part(m, Vector3.new(0.3, 2.4, 16), CFrame.new(-173.2, G + 14, -54), C.neonGreen, M.Neon, NOCOL)
	U.tag(prizeSign, "ResortNeon")
	U.addGui(prizeSign, Enum.NormalId.Right, "PRIZE COUNTER", { fg = rgb(20, 60, 30), font = Enum.Font.FredokaOne, pps = 20 })
	ctx.npc("Cashier", Vector3.new(-100, G, -76))
	-- cashier window (counter in the glass gap of the -70 wall)
	local cashier = P.counter(m, -106, -71.8, -94, -68.6, G, 3.2, C.woodDark, C.marble)
	U.interact(cashier, "Cashier", "Cashier_Casino", "Casino", "Prize Desk")
	U.signAt(m, "PRIZE DESK", Vector3.new(-100, G + 9.3, -69.35), Vector3.new(0, 0, 1), 8, 1.4, { bg = C.gold, fg = C.purpleDark, font = Enum.Font.FredokaOne })
	-- casino bar lounge (north-west corner)
	U.rug(m, -172, -36, -158, -22, G, C.purple, C.gold)
	P.sofa(m, CFrame.lookAt(Vector3.new(-170.5, G, -29), Vector3.new(-150, G, -29)), 10, C.purple, C.gold)
	P.coffeeTable(m, CFrame.new(-165, G, -29), 3, 5)
	-- pillars with neon rings
	for _, c in { { -140, -46 }, { -112, -46 }, { -140, -30 }, { -112, -30 } } do
		U.column(m, c[1], G, c[2], TOP, 2.4, C.gold, C.white)
		local ring = U.cyl(m, CFrame.new(c[1], G + 12, c[2]) * CFrame.Angles(0, 0, math.pi / 2), 0.5, 3.2, C.neonPink, M.Neon, NOCOL)
		U.tag(ring, "ResortNeon")
	end
	-- chandeliers + red carpet aisle
	for _, c in { { -130, -32 }, { -130, -58 }, { -160, -46 } } do
		P.chandelier(m, Vector3.new(c[1], TOP, c[2]), 3.4)
	end
	U.rug(m, -134, -66, -126, -20.6, G, C.red, C.gold)
	local cam = P.securityCam(m, Vector3.new(-92, G + 18, -22), Vector3.new(-140, G, -55))
	U.interact(cam, "Camera", "Cam_Casino", "Casino", "Security Camera", { CamId = "Cam_Casino" })
	for _, p in { { -172, -22 }, { -93, -67 }, { -93, -23 }, { -110, -67 } } do
		P.plant(m, Vector3.new(p[1], G, p[2]), 1)
	end
	ctx.item("Casino", Vector3.new(-160, G, -64))
	ctx.item("Casino", Vector3.new(-118, G, -26))
	ctx.wander("Casino", Vector3.new(-130, G, -36))
	ctx.wander("Casino", Vector3.new(-104, G, -44))
	ctx.wander("Casino", Vector3.new(-160, G, -48))

	------------------------------------------------------------------ VIP lounge
	U.door(m, "x", -155, -70, G, "CasinoVIP", "D_CasinoVIP", "key:VIPKeycard", "VIP Lounge", { inside = "-", text = "VIP", color = C.purpleDark, mat = M.Fabric, textColor = C.gold })
	local vipSign = U.part(m, Vector3.new(8, 2, 0.3), CFrame.new(-155, G + 13, -69.3), C.gold, M.Neon, NOCOL)
	U.tag(vipSign, "ResortNeon")
	U.addGui(vipSign, Enum.NormalId.Front, "♛ VIP LOUNGE", { fg = C.purpleDark, font = Enum.Font.FredokaOne, pps = 25 })
	U.rug(m, -172, -97, -138, -73, G, C.purple, C.gold)
	local vt = P.cardTable(m, CFrame.lookAt(Vector3.new(-155, G, -88), Vector3.new(-155, G, -80)))
	vt.Color = rgb(70, 20, 110)
	P.sofa(m, CFrame.lookAt(Vector3.new(-171.6, G, -80), Vector3.new(-150, G, -80)), 9, C.purple, C.gold)
	P.sofa(m, CFrame.lookAt(Vector3.new(-139, G, -96.5), Vector3.new(-139, G, -80)), 7, C.purple, C.gold)
	local vipSafe = U.box(m, -173.8, G, -98.8, -170, G + 4, -95, C.darkSteel, M.DiamondPlate)
	U.cyl(m, CFrame.new(-169.9, G + 2, -96.9), 0.2, 1.2, C.gold, M.Metal, NOCOL)
	U.interact(vipSafe, "Search", "S_VIPSafe", "CasinoVIP", "VIP Safe", { Loot = "CasinoChip" })
	local champ = U.box(m, -152, G, -99, -144, G + 3.4, -97, C.woodDark, M.Wood)
	U.interact(champ, "Search", "S_VIPBar", "CasinoVIP", "Juice Bar", { Loot = "Champagne" })
	for k = 0, 2 do
		U.vcyl(m, -151 + k * 3, G + 3.4, -98, G + 5.2, 0.6, rgb(30, 80, 40), M.Glass, NOCOL)
	end
	P.chandelier(m, Vector3.new(-155, TOP, -85), 3)
	local vcam = P.securityCam(m, Vector3.new(-136.5, G + 16, -72), Vector3.new(-160, G, -90))
	U.interact(vcam, "Camera", "Cam_VIP", "CasinoVIP", "Security Camera", { CamId = "Cam_VIP" })
	U.picture(m, CFrame.lookAt(Vector3.new(-174.3, G + 10, -88), Vector3.new(-150, G + 10, -88)), 6, 4)
	ctx.item("CasinoVIP", Vector3.new(-162, G, -76))
	ctx.wander("CasinoVIP", Vector3.new(-150, G, -78))

	------------------------------------------------------------------ Back room (+ cashier cage)
	U.door(m, "x", -122, -70, G, "CasinoBackRoom", "D_CasinoBack", "code", "Back Room", { inside = "-", code = "8264", text = "STAFF", color = C.darkSteel, mat = M.Metal })
	U.door(m, "x", -160, -100, G, "CasinoVIP", "D_CasinoVIPExit", "security", "VIP Exit", { inside = "+", color = C.purpleDark })
	local vault = U.box(m, -134, G, -99.4, -126, G + 10, -96, C.steel, M.DiamondPlate)
	U.cyl(m, CFrame.new(-130, G + 5, -95.9) * CFrame.Angles(0, math.pi / 2, 0), 0.3, 5, C.darkSteel, M.Metal, NOCOL)
	U.interact(vault, "Search", "S_CasinoVault", "CasinoBackRoom", "Token Vault", { Loot = "CasinoChip" })
	local desk = P.counter(m, -126, -88, -116, -84, G, 3.2, C.woodDark, C.woodLight)
	local backPc = P.computer(m, CFrame.lookAt(Vector3.new(-121, G + 3.2, -86), Vector3.new(-121, G + 3.2, -92)), "ARCADE OS")
	U.interact(backPc, "Computer", "PC_Casino", "CasinoBackRoom", "Arcade Computer", { Role = "Casino" })
	local _ = desk
	P.chair(m, CFrame.lookAt(Vector3.new(-121, G, -91), Vector3.new(-121, G, -86)), C.navy)
	local bcrates = P.crate(m, CFrame.new(-114, G, -96), 3.4)
	U.interact(bcrates, "Search", "S_CasinoCrates", "CasinoBackRoom", "Supply Crates", { Loot = "Crowbar" })
	P.crate(m, CFrame.new(-114, G + 3.4, -96) * CFrame.Angles(0, 0.5, 0), 2.4, C.wood)
	local bcl = P.wardrobe(m, CFrame.lookAt(Vector3.new(-133, G, -80), Vector3.new(-120, G, -80)), C.steel)
	U.interact(bcl, "Hide", "H_CasinoLocker", "CasinoBackRoom", "Staff Locker")
	-- cashier cage
	U.box(m, -109.4, G, -99.4, -91, G + 3, -96.5, C.woodDark, M.Wood)
	for k = 0, 4 do
		U.box(m, -108 + k * 3.6, G + 3, -98.6, -105.6 + k * 3.6, G + 3.8, -97, ({ C.gold, C.red, C.navy, C.felt, C.purple })[k + 1], M.SmoothPlastic, NOCOL)
	end
	local cdrawer = P.cabinet(m, CFrame.lookAt(Vector3.new(-93, G, -84), Vector3.new(-100, G, -84)), 3, 3.6, 2.4, C.steel, C.darkSteel)
	U.interact(cdrawer, "Search", "S_CashierDrawer", "CasinoBackRoom", "Cash Drawer", { Loot = "CasinoChip" })
	U.downlight(m, -122, TOP, -84, 22, 0.8)
	U.downlight(m, -100, TOP, -86, 18, 0.7)
	U.signAt(m, "BACK ROOM — STAFF ONLY", Vector3.new(-122, G + 13, -69.35), Vector3.new(0, 0, 1), 10, 1.2, { bg = C.darkSteel, fg = C.white, font = Enum.Font.GothamBold })
	ctx.item("CasinoBackRoom", Vector3.new(-128, G, -78))

	-- ambience emitter centre
	ctx.ambience("Casino", Vector3.new(-130, G + 6, -45), 30, 90)
	ctx.ambience("CasinoVIP", Vector3.new(-155, G + 6, -85), 15, 50)
	ctx.ambience("CasinoBackRoom", Vector3.new(-115, G + 6, -85), 15, 50)
	ctx.guard(2, 1, Vector3.new(-130, G, -24))
	ctx.guard(2, 2, Vector3.new(-160, G, -60))
	ctx.guard(2, 3, Vector3.new(-118, G, -64))
	ctx.guard(2, 4, Vector3.new(-130, G, 10))
	ctx.guard(2, 5, Vector3.new(-137, G, 60))
	ctx.guard(2, 6, Vector3.new(-100, G, 40))
end

return Casino
