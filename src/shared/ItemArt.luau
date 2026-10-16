--!nocheck
-- ItemArt.luau (MAP owns): ItemArt.build(itemId) -> BasePart "Handle" with <= 12 welded child parts.
-- Everything is unanchored, CanCollide false, Massless. Built for the default Tool.Grip (identity):
-- the hand holds the Handle centre; in the R15 grip frame Handle +Z points up the forearm and +Y points forward.
-- Items are modelled in a "display frame" F = Handle * Rx(90°) where F.Y = up and F.LookVector (-Z) = forward.
local ItemArt = {}

local ROT = CFrame.Angles(math.pi / 2, 0, 0)
local rgb = Color3.fromRGB
local Mt = Enum.Material

local GOLD = rgb(222, 178, 60)
local GOLD_D = rgb(176, 132, 40)

local function newPart(shape)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	return p
end

-- builder context: handle + helpers in F space
local function begin(itemId, sizeF, color, mat, props)
	local h = newPart()
	h.Name = "Handle"
	-- F-size (x, y, z) -> handle size (x, z, y)
	h.Size = Vector3.new(sizeF.X, sizeF.Z, sizeF.Y)
	h.CFrame = CFrame.new()
	h.Color = color or rgb(200, 200, 200)
	h.Material = mat or Mt.SmoothPlastic
	if props then
		for k, v in props do
			h[k] = v
		end
	end
	h:SetAttribute("ItemId", itemId)
	local F = h.CFrame * ROT
	local n = 0
	local b = {}
	function b.add(size, cf, col, m, shape, extra)
		n += 1
		assert(n <= 12, "ItemArt: too many parts for " .. itemId)
		local p = newPart(shape)
		p.Name = "Part" .. n
		p.Size = size
		p.CFrame = F * cf
		p.Color = col or h.Color
		p.Material = m or Mt.SmoothPlastic
		if extra then
			for k, v in extra do
				p[k] = v
			end
		end
		local w = Instance.new("WeldConstraint")
		w.Part0 = h
		w.Part1 = p
		w.Parent = p
		p.Parent = h
		return p
	end
	-- vertical cylinder in F (axis = F.Y)
	function b.vcyl(len, d, cf, col, m, extra)
		return b.add(Vector3.new(len, d, d), cf * CFrame.Angles(0, 0, math.pi / 2), col, m, Enum.PartType.Cylinder, extra)
	end
	-- forward-facing cylinder (axis = F.Z)
	function b.zcyl(len, d, cf, col, m, extra)
		return b.add(Vector3.new(len, d, d), cf * CFrame.Angles(0, math.pi / 2, 0), col, m, Enum.PartType.Cylinder, extra)
	end
	function b.ball(d, pos, col, m, extra)
		return b.add(Vector3.new(d, d, d), CFrame.new(pos), col, m, Enum.PartType.Ball, extra)
	end
	function b.text(part, face, text, fg, font)
		local sg = Instance.new("SurfaceGui")
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 80
		sg.LightInfluence = 0.6
		local tl = Instance.new("TextLabel")
		tl.BackgroundTransparency = 1
		tl.Size = UDim2.fromScale(1, 1)
		tl.TextScaled = true
		tl.Font = font or Enum.Font.GothamBold
		tl.Text = text
		tl.TextColor3 = fg or Color3.new(1, 1, 1)
		tl.Parent = sg
		sg.Parent = part
		return sg
	end
	b.handle = h
	b.F = F
	return b
end

local function C(x, y, z)
	return CFrame.new(x, y, z)
end

------------------------------------------------------------------ builders
local B = {}

function B.GoldenStatue()
	local b = begin("GoldenStatue", Vector3.new(1.1, 0.4, 1.1), rgb(40, 34, 30), Mt.Marble, { Reflectance = 0.1 })
	local g = { Reflectance = 0.35 }
	b.add(Vector3.new(1.2, 0.08, 1.2), C(0, 0.24, 0), GOLD_D, Mt.Metal, nil, g)
	b.add(Vector3.new(0.24, 0.55, 0.26), C(-0.16, 0.56, 0), GOLD, Mt.Metal, nil, g)
	b.add(Vector3.new(0.24, 0.55, 0.26), C(0.16, 0.56, 0), GOLD, Mt.Metal, nil, g)
	b.add(Vector3.new(0.62, 0.7, 0.36), C(0, 1.18, 0), GOLD, Mt.Metal, nil, g)
	b.ball(0.48, Vector3.new(0, 1.8, 0), GOLD, Mt.Metal, g)
	b.add(Vector3.new(0.18, 0.66, 0.18), C(-0.42, 1.62, 0) * CFrame.Angles(0, 0, math.rad(-28)), GOLD, Mt.Metal, nil, g)
	b.add(Vector3.new(0.18, 0.66, 0.18), C(0.42, 1.62, 0) * CFrame.Angles(0, 0, math.rad(28)), GOLD, Mt.Metal, nil, g)
	local star = b.ball(0.34, Vector3.new(0.6, 2.05, 0), rgb(255, 236, 140), Mt.Neon)
	local _ = star
	b.vcyl(0.14, 0.5, C(0, 2.08, 0), GOLD_D, Mt.Metal, g) -- crown band
	b.add(Vector3.new(0.7, 0.12, 0.05), C(0, 0, -0.56), GOLD, Mt.Metal, nil, g) -- plaque
	return b.handle
end

function B.DiamondNecklace()
	local b = begin("DiamondNecklace", Vector3.new(0.32, 0.16, 0.16), GOLD, Mt.Metal, { Reflectance = 0.3 })
	local r = 0.62
	local cy = -r
	for k = 1, 8 do
		local a = math.rad(90 + 40 * k)
		if k ~= 4 and k ~= 5 then
			b.ball(0.2, Vector3.new(math.cos(a) * r, cy + math.sin(a) * r, 0), rgb(250, 248, 240), Mt.SmoothPlastic, { Reflectance = 0.2 })
		end
	end
	b.ball(0.16, Vector3.new(math.cos(math.rad(250)) * r, cy + math.sin(math.rad(250)) * r, 0), GOLD, Mt.Metal)
	b.ball(0.16, Vector3.new(math.cos(math.rad(290)) * r, cy + math.sin(math.rad(290)) * r, 0), GOLD, Mt.Metal)
	b.add(Vector3.new(0.3, 0.3, 0.1), C(0, cy - r - 0.05, 0) * CFrame.Angles(0, 0, math.rad(45)), GOLD, Mt.Metal, nil, { Reflectance = 0.3 })
	b.add(Vector3.new(0.36, 0.36, 0.36), C(0, cy - r - 0.36, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), rgb(170, 230, 255), Mt.Glass, nil, { Reflectance = 0.5, Transparency = 0.15 })
	b.ball(0.14, Vector3.new(0, cy - r - 0.36, -0.12), rgb(220, 250, 255), Mt.Neon)
	return b.handle
end

local function card(itemId, color, label, accent)
	local b = begin(itemId, Vector3.new(0.9, 1.4, 0.06), color, Mt.SmoothPlastic, { Reflectance = 0.1 })
	b.add(Vector3.new(0.9, 0.16, 0.07), C(0, 0.52, 0), accent, Mt.Metal)
	b.add(Vector3.new(0.26, 0.2, 0.08), C(-0.22, 0.18, 0), GOLD, Mt.Metal, nil, { Reflectance = 0.3 })
	b.add(Vector3.new(0.92, 0.18, 0.065), C(0, -0.48, 0), rgb(30, 30, 34), Mt.SmoothPlastic)
	local photo = b.add(Vector3.new(0.3, 0.36, 0.07), C(0.2, 0.18, 0), rgb(240, 236, 226), Mt.SmoothPlastic)
	local _ = photo
	local face = b.add(Vector3.new(0.8, 0.26, 0.07), C(0, -0.16, 0), color, Mt.SmoothPlastic)
	b.text(face, Enum.NormalId.Front, label, Color3.new(1, 1, 1))
	b.text(face, Enum.NormalId.Back, label, Color3.new(1, 1, 1))
	-- lanyard clip
	b.zcyl(0.08, 0.22, C(0, 0.78, 0), rgb(200, 200, 205), Mt.Metal)
	return b.handle
end

function B.VIPKeycard()
	return card("VIPKeycard", rgb(110, 40, 170), "♛ VIP", GOLD)
end

function B.SecurityCard()
	return card("SecurityCard", rgb(30, 100, 200), "SECURITY", rgb(220, 230, 255))
end

function B.MasterKey()
	local b = begin("MasterKey", Vector3.new(0.3, 0.3, 0.3), GOLD_D, Mt.Metal, { Reflectance = 0.3 })
	local g = { Reflectance = 0.35 }
	-- ornate bow: ring of 6 small balls + centre gem
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		b.ball(0.26, Vector3.new(math.cos(a) * 0.36, math.sin(a) * 0.36, 0), GOLD, Mt.Metal, g)
	end
	b.ball(0.2, Vector3.new(0, 0, 0), rgb(200, 30, 50), Mt.Glass, { Reflectance = 0.3 })
	b.vcyl(0.2, 0.3, C(0, 0.5, 0), GOLD_D, Mt.Metal, g) -- collar
	b.vcyl(1.5, 0.16, C(0, 1.3, 0), GOLD, Mt.Metal, g) -- shaft
	b.add(Vector3.new(0.34, 0.14, 0.1), C(0.2, 1.8, 0), GOLD, Mt.Metal, nil, g)
	b.add(Vector3.new(0.26, 0.12, 0.1), C(0.16, 1.98, 0), GOLD, Mt.Metal, nil, g)
	return b.handle
end

function B.CasinoChip()
	local b = begin("CasinoChip", Vector3.new(0.3, 0.3, 0.3), rgb(200, 30, 40), Mt.SmoothPlastic, { Transparency = 1 })
	local red = rgb(200, 30, 40)
	b.zcyl(0.18, 1.3, C(0, 0, 0), red, Mt.SmoothPlastic)
	local inner = b.zcyl(0.2, 0.86, C(0, 0, 0), rgb(250, 246, 236), Mt.SmoothPlastic)
	b.text(inner, Enum.NormalId.Right, "★", red, Enum.Font.FredokaOne)
	b.text(inner, Enum.NormalId.Left, "★", red, Enum.Font.FredokaOne)
	b.zcyl(0.205, 0.72, C(0, 0, 0), rgb(214, 172, 62), Mt.Metal, { Transparency = 0.6 })
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		b.add(Vector3.new(0.18, 0.12, 0.19), C(math.cos(a) * 0.56, math.sin(a) * 0.56, 0) * CFrame.Angles(0, 0, a + math.pi / 2), rgb(250, 246, 236), Mt.SmoothPlastic)
	end
	return b.handle
end

function B.Briefcase()
	local b = begin("Briefcase", Vector3.new(0.7, 0.14, 0.16), rgb(24, 24, 26), Mt.SmoothPlastic)
	local leather = rgb(92, 56, 34)
	b.add(Vector3.new(0.12, 0.3, 0.14), C(-0.38, -0.15, 0), rgb(24, 24, 26), Mt.SmoothPlastic)
	b.add(Vector3.new(0.12, 0.3, 0.14), C(0.38, -0.15, 0), rgb(24, 24, 26), Mt.SmoothPlastic)
	b.add(Vector3.new(2, 1.4, 0.5), C(0, -1.0, 0), leather, Mt.Fabric)
	b.add(Vector3.new(2.04, 0.08, 0.54), C(0, -0.62, 0), GOLD_D, Mt.Metal)
	b.add(Vector3.new(0.2, 0.18, 0.56), C(-0.6, -0.56, 0), GOLD, Mt.Metal, nil, { Reflectance = 0.3 })
	b.add(Vector3.new(0.2, 0.18, 0.56), C(0.6, -0.56, 0), GOLD, Mt.Metal, nil, { Reflectance = 0.3 })
	b.add(Vector3.new(0.08, 1.44, 0.54), C(-1.0, -1.0, 0), rgb(70, 42, 26), Mt.Fabric)
	b.add(Vector3.new(0.08, 1.44, 0.54), C(1.0, -1.0, 0), rgb(70, 42, 26), Mt.Fabric)
	b.add(Vector3.new(2.04, 0.08, 0.54), C(0, -1.7, 0), rgb(70, 42, 26), Mt.Fabric)
	return b.handle
end

function B.PhotoCamera()
	local b = begin("PhotoCamera", Vector3.new(1.3, 0.8, 0.5), rgb(36, 36, 40), Mt.SmoothPlastic)
	b.add(Vector3.new(1.32, 0.3, 0.52), C(0, -0.2, 0), rgb(150, 110, 70), Mt.Fabric) -- leather band
	b.zcyl(0.4, 0.62, C(0.1, 0, -0.42), rgb(24, 24, 26), Mt.Metal)
	b.zcyl(0.18, 0.7, C(0.1, 0, -0.66), rgb(200, 200, 205), Mt.Metal)
	b.zcyl(0.06, 0.48, C(0.1, 0, -0.74), rgb(60, 110, 160), Mt.Glass, { Reflectance = 0.5 })
	b.add(Vector3.new(0.4, 0.22, 0.3), C(-0.36, 0.5, 0), rgb(36, 36, 40), Mt.SmoothPlastic) -- viewfinder hump
	b.add(Vector3.new(0.28, 0.14, 0.06), C(0.38, 0.28, -0.26), rgb(240, 240, 250), Mt.Neon) -- flash
	b.vcyl(0.1, 0.18, C(0.46, 0.45, 0.05), rgb(200, 40, 40), Mt.SmoothPlastic) -- shutter
	b.vcyl(0.08, 0.24, C(-0.1, 0.44, 0.05), rgb(200, 200, 205), Mt.Metal) -- dial
	return b.handle
end

function B.StaffUniform()
	local navy = rgb(32, 52, 100)
	local b = begin("StaffUniform", Vector3.new(1.2, 1.0, 0.32), navy, Mt.Fabric)
	b.add(Vector3.new(1.24, 0.98, 0.18), C(0, -0.02, 0.24), rgb(30, 30, 36), Mt.Fabric) -- trousers underneath
	b.add(Vector3.new(0.34, 0.26, 0.06), C(-0.2, 0.38, -0.17) * CFrame.Angles(0, 0, math.rad(-35)), rgb(250, 250, 250), Mt.Fabric)
	b.add(Vector3.new(0.34, 0.26, 0.06), C(0.2, 0.38, -0.17) * CFrame.Angles(0, 0, math.rad(35)), rgb(250, 250, 250), Mt.Fabric)
	b.add(Vector3.new(0.1, 0.4, 0.04), C(0, 0.3, -0.17), rgb(178, 24, 36), Mt.Fabric) -- tie
	for k = 0, 2 do
		b.ball(0.07, Vector3.new(0, -0.0 - k * 0.2, -0.17), GOLD, Mt.Metal)
	end
	local badge = b.add(Vector3.new(0.34, 0.14, 0.04), C(0.34, 0.08, -0.17), GOLD, Mt.Metal, nil, { Reflectance = 0.3 })
	b.text(badge, Enum.NormalId.Front, "STAFF", rgb(30, 30, 30))
	b.add(Vector3.new(1.22, 0.06, 0.34), C(0, -0.32, 0), rgb(214, 172, 62), Mt.Fabric) -- gold piping fold
	return b.handle
end

function B.Crowbar()
	local red = rgb(190, 30, 30)
	local b = begin("Crowbar", Vector3.new(0.26, 0.8, 0.26), rgb(30, 30, 30), Mt.Fabric)
	b.vcyl(2.2, 0.18, C(0, 0.9, 0), red, Mt.Metal)
	b.vcyl(0.9, 0.18, C(0, -0.65, 0), red, Mt.Metal)
	b.add(Vector3.new(0.18, 0.5, 0.18), C(0.16, 2.12, 0) * CFrame.Angles(0, 0, math.rad(-40)), red, Mt.Metal)
	b.add(Vector3.new(0.18, 0.46, 0.18), C(0.44, 2.18, 0) * CFrame.Angles(0, 0, math.rad(-110)), red, Mt.Metal)
	b.add(Vector3.new(0.16, 0.3, 0.16), C(0.6, 2.0, 0) * CFrame.Angles(0, 0, math.rad(-170)), rgb(160, 160, 165), Mt.Metal)
	b.add(Vector3.new(0.26, 0.36, 0.08), C(0.05, -1.22, 0) * CFrame.Angles(0, 0, math.rad(18)), rgb(160, 160, 165), Mt.Metal)
	b.vcyl(0.06, 0.28, C(0, 0.42, 0), rgb(80, 80, 80), Mt.Metal)
	return b.handle
end

function B.TreasureMap()
	local paper = rgb(232, 208, 156)
	local b = begin("TreasureMap", Vector3.new(0.4, 1.2, 0.4), paper, Mt.Fabric, { Transparency = 1 })
	b.vcyl(1.5, 0.42, C(0, 0, 0), paper, Mt.Fabric)
	b.vcyl(0.1, 0.48, C(0, 0.72, 0), rgb(150, 100, 60), Mt.Wood)
	b.vcyl(0.1, 0.48, C(0, -0.72, 0), rgb(150, 100, 60), Mt.Wood)
	b.vcyl(0.16, 0.45, C(0, 0.1, 0), rgb(178, 24, 36), Mt.Fabric) -- ribbon
	b.add(Vector3.new(0.16, 0.12, 0.08), C(0.24, 0.02, 0) * CFrame.Angles(0, 0, math.rad(30)), rgb(178, 24, 36), Mt.Fabric)
	local flap = b.add(Vector3.new(0.9, 1.3, 0.04), C(-0.62, -0.06, -0.12) * CFrame.Angles(0, math.rad(-15), 0), paper, Mt.Fabric)
	b.text(flap, Enum.NormalId.Front, "✕", rgb(178, 24, 36), Enum.Font.FredokaOne)
	b.text(flap, Enum.NormalId.Back, "🗺", rgb(120, 80, 40))
	return b.handle
end

function B.SecretLetter()
	local paper = rgb(246, 238, 216)
	local b = begin("SecretLetter", Vector3.new(1.4, 0.9, 0.05), paper, Mt.SmoothPlastic)
	local edge = rgb(200, 186, 156)
	b.add(Vector3.new(0.86, 0.04, 0.055), C(-0.33, 0.22, 0) * CFrame.Angles(0, 0, math.rad(-33)), edge, Mt.SmoothPlastic)
	b.add(Vector3.new(0.86, 0.04, 0.055), C(0.33, 0.22, 0) * CFrame.Angles(0, 0, math.rad(33)), edge, Mt.SmoothPlastic)
	b.zcyl(0.08, 0.34, C(0, -0.02, -0.04), rgb(176, 20, 28), Mt.SmoothPlastic)
	b.zcyl(0.04, 0.22, C(0, -0.02, -0.08), rgb(140, 14, 20), Mt.SmoothPlastic)
	local stamp = b.add(Vector3.new(0.22, 0.26, 0.04), C(0.5, -0.24, 0.03), rgb(60, 140, 200), Mt.SmoothPlastic)
	local _ = stamp
	local back = b.add(Vector3.new(1.0, 0.24, 0.04), C(-0.12, -0.24, 0.03), paper, Mt.SmoothPlastic)
	b.text(back, Enum.NormalId.Back, "TOP SECRET", rgb(176, 20, 28))
	return b.handle
end

function B.Champagne()
	local glass = rgb(255, 150, 40) -- sparkling (orange) juice
	local b = begin("Champagne", Vector3.new(0.4, 0.4, 0.4), glass, Mt.Glass, { Transparency = 1 })
	b.vcyl(1.3, 0.56, C(0, 0, 0), glass, Mt.Glass, { Reflectance = 0.3 })
	b.ball(0.56, Vector3.new(0, 0.65, 0), glass, Mt.Glass, { Reflectance = 0.3 })
	b.vcyl(0.6, 0.24, C(0, 1.1, 0), glass, Mt.Glass, { Reflectance = 0.3 })
	b.vcyl(0.38, 0.27, C(0, 1.25, 0), GOLD, Mt.Foil)
	b.ball(0.24, Vector3.new(0, 1.46, 0), GOLD, Mt.Foil)
	local label = b.vcyl(0.46, 0.58, C(0, -0.05, 0), rgb(248, 240, 220), Mt.SmoothPlastic)
	local _ = label
	b.vcyl(0.08, 0.585, C(0, 0.2, 0), GOLD, Mt.Metal)
	b.vcyl(0.06, 0.6, C(0, -0.62, 0), rgb(16, 56, 30), Mt.Glass)
	return b.handle
end

function B.Pizza()
	local card = rgb(214, 170, 110)
	local b = begin("Pizza", Vector3.new(1.6, 0.2, 1.6), card, Mt.Cardboard)
	local lid = b.add(Vector3.new(1.6, 0.06, 1.6), C(0, 0.13, -0.8) * CFrame.Angles(math.rad(-80), 0, 0) * CFrame.new(0, 0, 0.8), card, Mt.Cardboard) -- open lid
	b.vcyl(0.08, 1.44, C(0, 0.13, 0), rgb(214, 150, 70), Mt.SmoothPlastic) -- crust
	b.vcyl(0.09, 1.2, C(0, 0.135, 0), rgb(250, 210, 90), Mt.SmoothPlastic) -- cheese
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		b.vcyl(0.1, 0.22, C(math.cos(a) * 0.38, 0.14, math.sin(a) * 0.38), rgb(180, 40, 30), Mt.SmoothPlastic)
	end
	b.add(Vector3.new(0.04, 0.1, 1.2), C(0, 0.15, 0) * CFrame.Angles(0, math.rad(30), 0), rgb(240, 200, 110), Mt.SmoothPlastic)
	b.text(lid, Enum.NormalId.Top, "PIZZA", rgb(200, 30, 30), Enum.Font.FredokaOne)
	b.text(lid, Enum.NormalId.Bottom, "🍕", rgb(200, 30, 30), Enum.Font.FredokaOne)
	return b.handle
end

function B.Flashlight()
	local body = rgb(40, 40, 46)
	local b = begin("Flashlight", Vector3.new(0.34, 0.34, 0.6), body, Mt.Metal)
	b.zcyl(1.4, 0.3, C(0, 0, -0.2), body, Mt.Metal)
	b.zcyl(0.4, 0.46, C(0, 0, -0.95), rgb(230, 190, 40), Mt.SmoothPlastic)
	local lens = b.zcyl(0.06, 0.38, C(0, 0, -1.17), rgb(255, 250, 220), Mt.Neon)
	b.zcyl(0.1, 0.34, C(0, 0, 0.55), rgb(230, 190, 40), Mt.SmoothPlastic)
	b.add(Vector3.new(0.1, 0.08, 0.2), C(0, 0.17, -0.45), rgb(200, 40, 40), Mt.SmoothPlastic)
	for k = 0, 2 do
		b.zcyl(0.05, 0.32, C(0, 0, 0.1 + k * 0.14), rgb(90, 90, 96), Mt.Metal)
	end
	local beam = Instance.new("SpotLight")
	beam.Name = "FlashlightBeam"
	beam.Face = Enum.NormalId.Right
	beam.Angle = 45
	beam.Range = 40
	beam.Brightness = 3
	beam.Enabled = false
	beam.Parent = lens
	return b.handle
end

function B.Unknown(itemId)
	local b = begin(itemId, Vector3.new(1, 1, 1), rgb(250, 120, 98), Mt.SmoothPlastic)
	b.add(Vector3.new(1.04, 1.04, 0.2), C(0, 0, 0), rgb(214, 172, 62), Mt.Metal)
	b.add(Vector3.new(0.2, 1.04, 1.04), C(0, 0, 0), rgb(214, 172, 62), Mt.Metal)
	b.ball(0.4, Vector3.new(0, 0.6, 0), rgb(214, 172, 62), Mt.Metal)
	return b.handle
end

ItemArt.IDS = {
	"GoldenStatue", "DiamondNecklace", "VIPKeycard", "SecurityCard", "MasterKey", "CasinoChip", "Briefcase", "PhotoCamera",
	"StaffUniform", "Crowbar", "TreasureMap", "SecretLetter", "Champagne", "Pizza", "Flashlight",
}

function ItemArt.build(itemId)
	local fn = B[itemId]
	if fn then
		return fn()
	end
	return B.Unknown(tostring(itemId))
end

return ItemArt
