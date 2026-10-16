--!nocheck
-- West: Shop Street (Clothing, Souvenir, Jewelry on the west side; General Store + café garden on the east side).
local West = {}

function West.build(ctx)
	local U, P = ctx.U, ctx.P
	local C, M = U.C, U.M
	local G = ctx.G
	local NOCOL = P.NOCOL
	local rgb = Color3.fromRGB

	-- generic boutique. front = +1 (door faces +X) or -1 (faces -X). Returns interior info.
	local function shop(model, x1, z1, x2, z2, front, o)
		local H = o.h or 14
		local fx = front > 0 and x2 or x1
		local bx = front > 0 and x1 or x2
		local zc = (z1 + z2) / 2
		U.box(model, x1, ctx.LAWN, z1, x2, G + 0.2, z2, o.floor or C.woodLight, o.floorMat or M.WoodPlanks)
		local frame = { frame = o.trim or C.white, glass = C.glass, mullion = 3.6 }
		local INT = { frame = C.white, base = C.woodDark, crown = C.white }
		-- front with big display windows either side of the door
		U.wall(model, fx, z1, fx, z2, G, H, 1, o.wall, M.SmoothPlastic, {
			{ c = zc, w = 8, h = 10.6, b = 0.2 },
			{ c = (z1 + zc - 4) / 2, w = (zc - 4 - z1) - 2.4, b = 1.6, h = 8, glass = true },
			{ c = (z2 + zc + 4) / 2, w = (z2 - zc - 4) - 2.4, b = 1.6, h = 8, glass = true },
		}, frame)
		U.wall(model, bx, z1, bx, z2, G, H, 1, o.wall, M.SmoothPlastic, o.backDoor and { { c = zc, w = 8, h = 10.6, b = 0.2 } } or {}, { frame = C.white })
		if o.backDoor then
			U.door(model, "z", bx, zc, G + 0.2, o.backDoor.zone, o.backDoor.id, o.backDoor.lock, o.backDoor.label, { inside = front > 0 and "+" or "-", color = C.white, mat = M.SmoothPlastic, text = "STAFF" })
		end
		U.wall(model, x1, z1, x2, z1, G, H, 1, o.wall, M.SmoothPlastic, {}, INT)
		U.wall(model, x1, z2, x2, z2, G, H, 1, o.wall, M.SmoothPlastic, {}, INT)
		-- roof + cornice
		U.box(model, x1 - 0.5, G + H, z1 - 0.5, x2 + 0.5, G + H + 0.8, z2 + 0.5, C.white, M.SmoothPlastic)
		U.box(model, x1 - 0.8, G + H + 0.8, z1 - 0.8, x2 + 0.8, G + H + 1.2, z2 + 0.8, o.trim or C.gold, M.Metal)
		-- striped awning (sloped panels) over the front
		local n = math.floor((z2 - z1 - 2) / 2.5)
		local w = (z2 - z1 - 2) / n
		for k = 0, n - 1 do
			local z = z1 + 1 + (k + 0.5) * w
			U.part(model, Vector3.new(5.4, 0.2, w), CFrame.new(fx + front * 2.6, G + 11.6, z) * CFrame.Angles(0, 0, -math.rad(20) * front), (k % 2 == 0) and o.awning or C.white, M.Fabric, NOCOL)
		end
		for k = 0, n - 1 do
			local z = z1 + 1 + (k + 0.5) * w
			U.wedge(model, Vector3.new(0.2, 0.8, w), CFrame.new(fx + front * 5.1, G + 10.2, z) * CFrame.Angles(0, 0, 0) * CFrame.Angles(math.pi, 0, 0), (k % 2 == 0) and o.awning or C.white, M.Fabric, NOCOL)
		end
		-- name board above the awning
		local sp = Vector3.new(fx + front * 0.75, G + H - 0.5, zc)
		U.sign(model, o.name, CFrame.lookAt(sp, sp + Vector3.new(front, 0, 0)), z2 - z1 - 4, 2.2, { bg = o.signBg or C.white, fg = o.signFg or C.tealDeep, font = Enum.Font.FredokaOne, thick = 0.3, pps = 25, frame = o.trim or C.gold })
		-- interior lighting
		for k = 1, 2 do
			U.downlight(model, (x1 + x2) / 2, G + H, z1 + (z2 - z1) * k / 3, 20, 0.85)
		end
		-- flower boxes under the display windows
		for _, s in { -1, 1 } do
			local z = zc + s * ((z2 - z1) / 4 + 1)
			P.planter(model, CFrame.new(fx + front * 1.4, G, z) * CFrame.Angles(0, math.pi / 2, 0), (z2 - z1) / 2 - 7, 1.4, o.wall)
		end
		return { fx = fx, bx = bx, zc = zc, H = H }
	end

	------------------------------------------------------------------ street furniture
	local sm = ctx.model("ShopStreet")
	-- central planted median with palms + benches
	for k = 0, 3 do
		local z = 4 + k * 20
		P.palm(sm, Vector3.new(-130, G - 0.5, z), 19 + k, math.rad(k * 77), 2)
		U.vcyl(sm, -130, G - 0.3, z, G + 0.8, 5.6, C.white, M.Marble)
		U.vcyl(sm, -130, G + 0.8, z, G + 0.9, 4.6, rgb(96, 70, 50), M.Ground, NOCOL)
		if k < 3 then
			P.bench(sm, CFrame.lookAt(Vector3.new(-133.5, G, z + 10), Vector3.new(-160, G, z + 10)) * CFrame.Angles(0, math.pi, 0), C.woodLight)
			P.bench(sm, CFrame.lookAt(Vector3.new(-126.5, G, z + 10), Vector3.new(-100, G, z + 10)) * CFrame.Angles(0, math.pi, 0), C.woodLight)
		end
	end
	for k = 0, 2 do
		P.streetLamp(sm, Vector3.new(-143, G, 10 + k * 28), 11)
		P.streetLamp(sm, Vector3.new(-117, G, 24 + k * 24), 11)
	end
	-- bunting across the street
	for k = 0, 3 do
		local z = 2 + k * 22
		local a, b = Vector3.new(-145.6, G + 13, z), Vector3.new(-114.4, G + 13, z)
		for f = 0, 10 do
			local p = a:Lerp(b, (f + 0.5) / 11) - Vector3.new(0, math.sin((f + 0.5) / 11 * math.pi) * 1.6, 0)
			U.wedge(sm, Vector3.new(0.1, 1.3, 1.1), CFrame.new(p) * CFrame.Angles(0, math.pi / 2, math.pi), ({ C.coral, C.yellow, C.teal, C.pink })[f % 4 + 1], M.Fabric, NOCOL)
		end
	end
	-- entrance arch
	for _, x in { -143.5, -116.5 } do
		U.column(sm, x, G, 78, G + 15, 1.6, C.white, C.gold)
	end
	U.box(sm, -145, G + 15, 77, -115, G + 17, 79, C.white, M.Marble)
	U.box(sm, -145.4, G + 17, 76.6, -114.6, G + 17.4, 79.4, C.gold, M.Metal)
	U.signAt(sm, "🛍️ SHOP STREET", Vector3.new(-130, G + 16, 79.1), Vector3.new(0, 0, 1), 18, 1.6, { bg = C.white, fg = C.coral, font = Enum.Font.FredokaOne, transparent = true, thick = 0.1 })
	U.signAt(sm, "🛍️ SHOP STREET", Vector3.new(-130, G + 16, 76.9), Vector3.new(0, 0, -1), 18, 1.6, { bg = C.white, fg = C.coral, font = Enum.Font.FredokaOne, transparent = true, thick = 0.1 })
	local scam = P.securityCam(sm, Vector3.new(-117, G + 13, 46), Vector3.new(-140, G, 20))
	U.interact(scam, "Camera", "Cam_ShopStreet", "ShopStreet", "Security Camera", { CamId = "Cam_ShopStreet" })
	-- hidden phone booth
	local booth = Vector3.new(-117, G, 6)
	U.box(sm, booth.X - 2, G, booth.Z - 2, booth.X + 2, G + 0.3, booth.Z + 2, C.red, M.SmoothPlastic)
	U.box(sm, booth.X - 2, G + 8, booth.Z - 2, booth.X + 2, G + 8.8, booth.Z + 2, C.red, M.SmoothPlastic)
	for _, o in { { -1.8, -1.8 }, { 1.8, -1.8 }, { -1.8, 1.8 }, { 1.8, 1.8 } } do
		U.box(sm, booth.X + o[1] - 0.2, G + 0.3, booth.Z + o[2] - 0.2, booth.X + o[1] + 0.2, G + 8, booth.Z + o[2] + 0.2, C.red, M.SmoothPlastic)
	end
	U.box(sm, booth.X + 1.7, G + 0.3, booth.Z - 1.6, booth.X + 1.9, G + 8, booth.Z + 1.6, C.red, M.SmoothPlastic)
	local sphone = P.phone(sm, Vector3.new(booth.X + 1.2, G + 4.5, booth.Z), math.pi / 2)
	U.interact(sphone, "Phone", "Phone_StreetBooth", "ShopStreet", "Pay Phone")
	ctx.wander("ShopStreet", Vector3.new(-137, G, 30))
	ctx.wander("ShopStreet", Vector3.new(-123, G, 60))
	ctx.item("ShopStreet", Vector3.new(-122, G, 14))
	ctx.npc("Shopkeeper", Vector3.new(-165, G, 13))

	------------------------------------------------------------------ Clothing (west side, z 2..24)
	local cm = ctx.model("Shops")
	local cl = shop(cm, -180, 2, -147, 24, 1, { name = "PALM COUTURE", wall = rgb(255, 228, 222), awning = C.coral, trim = C.gold, signFg = C.coral, backDoor = { zone = "ShopStreet", id = "D_ClothingBack", lock = "key:MasterKey", label = "Stock Room Exit" } })
	local ccounter = P.counter(cm, -170, 4, -166, 12, G + 0.2, 3.6, C.white, C.marble)
	U.interact(ccounter, "Shop", "Shop_Clothing", "ShopStreet", "Clothing Shop", { ShopId = "Clothing" })
	for r = 0, 1 do
		local z = 15 + r * 5
		U.beam(cm, Vector3.new(-174, G + 6.5, z), Vector3.new(-156, G + 6.5, z), 0.2, C.gold, M.Metal, NOCOL)
		for _, x in { -174, -156 } do
			U.vcyl(cm, x, G + 0.2, z, G + 6.6, 0.3, C.gold, M.Metal)
		end
		for k = 0, 6 do
			local col = ({ C.coral, C.teal, C.white, C.yellow, C.lavender, C.navy, C.mint })[(k + r * 3) % 7 + 1]
			U.box(cm, -172.4 + k * 2.4, G + 3.2, z - 0.15, -170.8 + k * 2.4, G + 6.2, z + 0.15, col, M.Fabric, NOCOL)
		end
	end
	for k = 0, 1 do
		local mx = -153
		local mz = 6 + k * 14
		U.vcyl(cm, mx, G + 0.2, mz, G + 0.5, 1.6, C.gold, M.Metal)
		U.vcyl(cm, mx, G + 0.5, mz, G + 3.5, 0.2, C.gold, M.Metal)
		U.box(cm, mx - 0.6, G + 3.5, mz - 0.9, mx + 0.6, G + 6.2, mz + 0.9, k == 0 and C.coral or C.teal, M.Fabric)
		U.ball(cm, Vector3.new(mx, G + 6.9, mz), 1.2, C.white, M.SmoothPlastic)
	end
	local fitting = P.wardrobe(cm, CFrame.lookAt(Vector3.new(-177.6, G + 0.2, 20), Vector3.new(-160, G + 0.2, 20)), C.coral)
	U.interact(fitting, "Hide", "H_FittingRoom", "ShopStreet", "Fitting Room")
	U.picture(cm, CFrame.lookAt(Vector3.new(-179.4, G + 8, 5.2), Vector3.new(-160, G + 8, 5.2)), 3.5, 5)
	ctx.item("ShopStreet", Vector3.new(-160, G + 0.2, 8))

	------------------------------------------------------------------ Souvenir (west side, z 28..50)
	local sv = shop(cm, -180, 28, -147, 50, 1, { name = "ISLAND SOUVENIRS", wall = rgb(214, 240, 236), awning = C.teal, trim = C.gold, signFg = C.teal })
	local scounter = P.counter(cm, -170, 30, -166, 38, G + 0.2, 3.6, C.woodLight, C.marble)
	U.interact(scounter, "Shop", "Shop_Souvenir", "ShopStreet", "Souvenir Shop", { ShopId = "Souvenir" })
	for r = 0, 2 do
		U.box(cm, -179.4, G + 1 + r * 3, 30, -177.4, G + 1.3 + r * 3, 48, C.woodLight, M.Wood)
		for k = 0, 7 do
			local z = 31 + k * 2.2
			local col = ({ C.coral, C.yellow, C.sky, C.pink, C.mint })[(k + r) % 5 + 1]
			if (k + r) % 3 == 0 then
				U.ball(cm, Vector3.new(-178.4, G + 2.1 + r * 3, z), 1.4, col, M.SmoothPlastic, NOCOL)
			else
				U.vcyl(cm, -178.4, G + 1.3 + r * 3, z, G + 2.6 + r * 3, 1, col, M.Glass, NOCOL)
			end
		end
	end
	U.box(cm, -179.4, G + 0.2, 30, -177.4, G + 10, 30.4, C.woodLight, M.Wood)
	-- postcard spinner + surfboards
	U.vcyl(cm, -158, G + 0.2, 44, G + 6, 0.3, C.steel, M.Metal)
	for k = 0, 3 do
		U.box(cm, -158.8, G + 2 + k, 43.2, -157.2, G + 2.9 + k, 44.8, ({ C.sky, C.coral, C.yellow, C.mint })[k + 1], M.SmoothPlastic, NOCOL)
	end
	for k = 0, 2 do
		U.part(cm, Vector3.new(0.4, 8, 2.2), CFrame.new(-151.5, G + 4.4, 30.5 + k * 2.6) * CFrame.Angles(0, 0, math.rad(8)), ({ C.coral, C.teal, C.yellow })[k + 1], M.SmoothPlastic, NOCOL)
	end
	local tmap = U.box(cm, -160, G + 0.2, 32, -156, G + 3, 35, C.woodDark, M.Wood)
	U.interact(tmap, "Search", "S_SouvenirChest", "ShopStreet", "Pirate Chest", { Loot = "TreasureMap" })
	U.box(cm, -160.2, G + 3, 31.8, -155.8, G + 3.6, 35.2, C.gold, M.Metal, NOCOL)
	local _ = sv

	------------------------------------------------------------------ Jewelry (west side, z 54..78)
	local jm = ctx.model("JewelryShop")
	local jw = shop(jm, -180, 54, -147, 78, 1, { name = "💎 DIAMOND & PEARL", wall = C.white, awning = C.navy, trim = C.gold, signBg = C.navy, signFg = C.gold, floor = C.marble, floorMat = M.Marble })
	local _2 = jw
	U.rug(jm, -170, 58, -150, 74, G + 0.2, C.navy, C.gold)
	-- glass display cases with gems
	for k = 0, 2 do
		local z = 58 + k * 6
		U.box(jm, -164, G + 0.2, z, -158, G + 3, z + 3, C.woodDark, M.Wood)
		U.box(jm, -164, G + 3, z, -158, G + 4.4, z + 3, C.glass, M.Glass, { Transparency = 0.6 })
		for g = 0, 2 do
			U.part(jm, Vector3.new(0.6, 0.6, 0.6), CFrame.new(-162.5 + g * 1.5, G + 3.3, z + 1.5) * CFrame.Angles(math.rad(45), 0, math.rad(45)), ({ C.sky, C.pink, C.mint })[g + 1], M.Glass, { CanCollide = false, Reflectance = 0.3 })
		end
	end
	-- necklace pedestal case (Pedestal)
	U.vcyl(jm, -155, G + 0.2, 72, G + 3.6, 3, C.white, M.Marble, { Reflectance = 0.06 })
	local nped = U.vcyl(jm, -155, G + 3.6, 72, G + 4, 3.4, C.gold, M.Metal, { Reflectance = 0.2 })
	U.interact(nped, "Pedestal", "Ped_DiamondNecklace", "JewelryShop", "Diamond Necklace", { ItemId = "DiamondNecklace" })
	nped.Name = "NecklacePedestal"
	local js = U.part(jm, Vector3.new(1, 1, 1), CFrame.new(-155, G + 13.4, 72), C.gold, M.Metal, NOCOL)
	U.spot(js, rgb(230, 240, 255), 16, 3, Enum.NormalId.Bottom, 35)
	local jcounter = P.counter(jm, -174, 58, -170, 70, G + 0.2, 3.6, C.navy, C.marble)
	U.interact(jcounter, "Shop", "Shop_Jewelry", "JewelryShop", "Jewelry Counter", { ShopId = "Jewelry" })
	local jdrawer = P.cabinet(jm, CFrame.lookAt(Vector3.new(-178, G + 0.2, 74), Vector3.new(-170, G + 0.2, 74)), 3, 4, 2.4, C.navy)
	U.interact(jdrawer, "Search", "S_JewelryDrawer", "JewelryShop", "Display Drawer")
	local jcam = P.securityCam(jm, Vector3.new(-148.5, G + 12.5, 55.5), Vector3.new(-165, G, 70))
	U.interact(jcam, "Camera", "Cam_Jewelry", "JewelryShop", "Security Camera", { CamId = "Cam_Jewelry" })
	local jalarm = U.box(jm, -179.4, G + 5, 60, -179.2, G + 6, 61, C.red, M.SmoothPlastic, NOCOL)
	U.interact(jalarm, "Alarm", "Alarm_Jewelry", "JewelryShop", "Silent Alarm")
	P.chandelier(jm, Vector3.new(-163, G + 14, 66), 2.4)
	ctx.item("JewelryShop", Vector3.new(-152, G + 0.2, 58))
	ctx.wander("JewelryShop", Vector3.new(-153, G + 0.2, 64))

	------------------------------------------------------------------ General Store (east side, z 2..30)
	local gs = shop(cm, -113, 2, -88, 30, -1, { name = "PALM MART", wall = rgb(255, 244, 200), awning = C.yellow, trim = C.gold, signFg = rgb(200, 120, 20), backDoor = { zone = "ShopStreet", id = "D_GeneralBack", lock = "none", label = "Back Door" } })
	local _3 = gs
	local gcounter = P.counter(cm, -100, 4, -96, 10, G + 0.2, 3.6, C.yellow, C.marble)
	U.interact(gcounter, "Shop", "Shop_General", "ShopStreet", "General Store", { ShopId = "General" })
	for r = 0, 1 do
		local x = -106 + r * 6
		U.box(cm, x - 0.8, G + 0.2, 14, x + 0.8, G + 6, 27, C.white, M.SmoothPlastic)
		for lv = 0, 2 do
			for k = 0, 5 do
				local col = ({ C.coral, C.sky, C.yellow, C.mint, C.pink, C.orange })[(k + lv + r) % 6 + 1]
				for _, s in { -1, 1 } do
					U.box(cm, x + s * 0.8, G + 0.8 + lv * 1.9, 14.4 + k * 2.1, x + s * 1.6, G + 2.2 + lv * 1.9, 15.9 + k * 2.1, col, M.SmoothPlastic, NOCOL)
				end
			end
		end
	end
	local gcrate = P.crate(cm, CFrame.new(-91, G + 0.2, 27), 2.6, C.woodLight)
	U.interact(gcrate, "Search", "S_GeneralStock", "ShopStreet", "Stock Boxes", { Loot = "Flashlight" })
	-- ice cream cart in the café garden (z 50..76)
	U.box(cm, -113, ctx.LAWN, 50, -88, G, 76, C.paving, M.Slate)
	for _, pos in { Vector3.new(-106, G, 56), Vector3.new(-96, G, 66), Vector3.new(-106, G, 70) } do
		P.roundTable(cm, pos, 4, 3, C.white)
		P.chair(cm, CFrame.lookAt(pos + Vector3.new(0, 0, -3.4), pos), C.yellow)
		P.chair(cm, CFrame.lookAt(pos + Vector3.new(0, 0, 3.4), pos), C.yellow)
		P.umbrella(cm, pos + Vector3.new(0, 3, 0), C.yellow, C.white, 6.5, 4)
	end
	local cart = CFrame.new(-94, G, 54)
	U.rel(cm, cart, 0, 2.4, 0, 6, 3, 3, C.pink, M.SmoothPlastic)
	U.rel(cm, cart, 0, 4.0, 0, 6.2, 0.2, 3.2, C.white, M.SmoothPlastic)
	for _, x in { -2.5, 2.5 } do
		U.cyl(cm, cart * CFrame.new(x, 0.9, 1.7), 0.3, 1.8, C.black, M.SmoothPlastic, NOCOL)
	end
	P.umbrella(cm, Vector3.new(-94, G + 4, 54), C.pink, C.white, 4, 3)
	U.signAt(cm, "🍦 GELATO", Vector3.new(-94, G + 2.6, 55.6), Vector3.new(0, 0, 1), 4, 1.2, { bg = C.white, fg = C.pink, font = Enum.Font.FredokaOne, transparent = true, thick = 0.1 })
	P.palm(cm, Vector3.new(-90, G - 0.5, 74), 20, 1, 2)
	ctx.item("ShopStreet", Vector3.new(-99, G, 72))

	ctx.ambience("ShopStreet", Vector3.new(-130, G + 4, 35), 30, 80)
	ctx.ambience("JewelryShop", Vector3.new(-163, G + 4, 66), 12, 40)
end

return West
