--!nocheck
-- Util: tiny part-building toolkit for the runtime map (MAP builder).
-- Every Instance.new("Part"/"WedgePart"/"SpawnLocation") goes through U.newPart so U.count is exact.
local CollectionService = game:GetService("CollectionService")

local U = {}
U.count = 0
U.interactCounts = {}
U.ids = {}
U.markerCount = 0

local M = Enum.Material
U.M = M

local rgb = Color3.fromRGB
U.C = {
	cream = rgb(247, 240, 224),
	teal = rgb(24, 118, 124),
	tealDeep = rgb(16, 78, 90),
	coral = rgb(250, 122, 98),
	terracotta = rgb(196, 110, 72),
	cream2 = rgb(236, 226, 204),
	white = rgb(250, 250, 247),
	gold = rgb(214, 172, 62),
	goldDark = rgb(170, 128, 40),
	marble = rgb(238, 234, 228),
	marbleDark = rgb(196, 188, 178),
	wood = rgb(150, 100, 62),
	woodDark = rgb(92, 60, 38),
	woodLight = rgb(205, 165, 112),
	red = rgb(178, 24, 36),
	redDark = rgb(120, 16, 26),
	turquoise = rgb(52, 214, 210),
	poolTile = rgb(150, 228, 238),
	sand = rgb(232, 212, 160),
	stone = rgb(206, 198, 186),
	paving = rgb(224, 214, 192),
	paving2 = rgb(196, 182, 158),
	trunk = rgb(146, 108, 70),
	trunk2 = rgb(122, 88, 56),
	leaf = rgb(56, 160, 72),
	leaf2 = rgb(84, 186, 80),
	glass = rgb(170, 216, 240),
	steel = rgb(178, 184, 190),
	darkSteel = rgb(72, 78, 86),
	black = rgb(28, 28, 34),
	navy = rgb(28, 42, 86),
	purple = rgb(96, 36, 150),
	purpleDark = rgb(48, 18, 78),
	felt = rgb(22, 116, 64),
	pink = rgb(255, 110, 180),
	neonPink = rgb(255, 64, 170),
	neonBlue = rgb(64, 190, 255),
	neonYellow = rgb(255, 222, 70),
	neonGreen = rgb(90, 255, 140),
	orange = rgb(255, 150, 50),
	yellow = rgb(255, 214, 80),
	mint = rgb(150, 228, 196),
	lavender = rgb(196, 170, 236),
	peach = rgb(255, 196, 160),
	sky = rgb(120, 196, 245),
	grass = rgb(92, 170, 76),
	concrete = rgb(150, 150, 146),
	concreteDark = rgb(104, 104, 102),
	pipeRed = rgb(170, 52, 40),
	pipeYellow = rgb(214, 170, 40),
	paper = rgb(250, 246, 228),
}
local C = U.C

local SMOOTH = Enum.SurfaceType.Smooth

function U.newPart(className)
	local p = Instance.new(className or "Part")
	p.Anchored = true
	p.TopSurface = SMOOTH
	p.BottomSurface = SMOOTH
	U.count += 1
	return p
end

local function apply(p, props)
	if props then
		for k, v in props do
			p[k] = v
		end
	end
end

local function fix(v)
	return Vector3.new(math.max(v.X, 0.05), math.max(v.Y, 0.05), math.max(v.Z, 0.05))
end

-- generic part
function U.part(parent, size, cf, color, mat, props)
	local p = U.newPart("Part")
	p.Size = fix(size)
	p.CFrame = cf
	p.Color = color or C.cream
	p.Material = mat or M.SmoothPlastic
	apply(p, props)
	p.Parent = parent
	return p
end

function U.wedge(parent, size, cf, color, mat, props)
	local p = U.newPart("WedgePart")
	p.Size = fix(size)
	p.CFrame = cf
	p.Color = color or C.cream
	p.Material = mat or M.SmoothPlastic
	apply(p, props)
	p.Parent = parent
	return p
end

-- axis aligned box from two corners
function U.box(parent, x1, y1, z1, x2, y2, z2, color, mat, props)
	local ax, bx = math.min(x1, x2), math.max(x1, x2)
	local ay, by = math.min(y1, y2), math.max(y1, y2)
	local az, bz = math.min(z1, z2), math.max(z1, z2)
	return U.part(parent, Vector3.new(bx - ax, by - ay, bz - az), CFrame.new((ax + bx) / 2, (ay + by) / 2, (az + bz) / 2), color, mat, props)
end

-- part relative to a base CFrame
function U.rel(parent, base, x, y, z, sx, sy, sz, color, mat, props)
	return U.part(parent, Vector3.new(sx, sy, sz), base * CFrame.new(x, y, z), color, mat, props)
end

-- cylinder along the CFrame's X axis
function U.cyl(parent, cf, length, diameter, color, mat, props)
	local p = U.part(parent, Vector3.new(length, diameter, diameter), cf, color, mat, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- vertical cylinder from y1 to y2 at x,z
function U.vcyl(parent, x, y1, z, y2, d, color, mat, props)
	return U.cyl(parent, CFrame.new(x, (y1 + y2) / 2, z) * CFrame.Angles(0, 0, math.pi / 2), math.abs(y2 - y1), d, color, mat, props)
end

-- cylinder between two points
function U.beam(parent, a, b, d, color, mat, props)
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude
	if flat < 1e-3 * math.max(len, 1) then
		return U.cyl(parent, CFrame.new(mid) * CFrame.Angles(0, 0, math.pi / 2), len, d, color, mat, props)
	end
	local cf = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0)
	return U.cyl(parent, cf, len, d, color, mat, props)
end

function U.ball(parent, pos, d, color, mat, props)
	local p = U.part(parent, Vector3.new(d, d, d), CFrame.new(pos), color, mat, props)
	p.Shape = Enum.PartType.Ball
	return p
end

function U.tag(inst, tag)
	CollectionService:AddTag(inst, tag)
	return inst
end

function U.light(part, color, range, brightness, shadows)
	local l = Instance.new("PointLight")
	l.Color = color or Color3.fromRGB(255, 236, 200)
	l.Range = range or 16
	l.Brightness = brightness or 1.2
	l.Shadows = shadows or false
	l.Parent = part
	U.tag(part, "ResortLight")
	return l
end

function U.spot(part, color, range, brightness, face, angle)
	local l = Instance.new("SpotLight")
	l.Color = color or Color3.fromRGB(255, 240, 210)
	l.Range = range or 20
	l.Brightness = brightness or 2
	l.Face = face or Enum.NormalId.Bottom
	l.Angle = angle or 70
	l.Parent = part
	U.tag(part, "ResortLight")
	return l
end

function U.neon(part)
	part.Material = M.Neon
	U.tag(part, "ResortNeon")
	return part
end

------------------------------------------------------------------ text / signs
local function addGui(part, face, text, opts)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = opts.pps or 40
	sg.LightInfluence = opts.lightInfluence or 0
	sg.Brightness = opts.brightness or 1.2
	sg.MaxDistance = opts.maxDistance or 400
	sg.ClipsDescendants = true
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.AnchorPoint = Vector2.new(0.5, 0.5)
	tl.Position = UDim2.fromScale(0.5, 0.5)
	tl.Size = UDim2.fromScale(opts.textW or 0.92, opts.textH or 0.8)
	tl.Font = opts.font or Enum.Font.FredokaOne
	tl.Text = text
	tl.TextScaled = true
	tl.TextWrapped = true
	tl.TextColor3 = opts.fg or C.white
	tl.TextStrokeColor3 = opts.strokeColor or Color3.new(0, 0, 0)
	tl.TextStrokeTransparency = opts.stroke or 0.6
	tl.Parent = sg
	sg.Parent = part
	return sg
end
U.addGui = addGui

-- sign board whose Front face (LookVector) shows the text
function U.sign(parent, text, cf, w, h, opts)
	opts = opts or {}
	local p = U.part(parent, Vector3.new(w, h, opts.thick or 0.4), cf, opts.bg or C.tealDeep, opts.mat or M.SmoothPlastic, {
		CanCollide = opts.collide or false,
		Transparency = opts.transparent and 1 or 0,
		CastShadow = false,
	})
	p.Name = "Sign"
	addGui(p, Enum.NormalId.Front, text, opts)
	if opts.double then
		addGui(p, Enum.NormalId.Back, text, opts)
	end
	if opts.frame then
		-- thin gold frame behind the board
		U.part(parent, Vector3.new(w + 0.5, h + 0.5, (opts.thick or 0.4) * 0.6), cf, opts.frame, M.Metal, { CanCollide = false })
	end
	return p
end

-- sign facing a horizontal direction (dir = where the reader stands)
function U.signAt(parent, text, pos, dir, w, h, opts)
	return U.sign(parent, text, CFrame.lookAt(pos, pos + dir), w, h, opts)
end

------------------------------------------------------------------ walls
-- Axis aligned wall from (x1,z1) to (x2,z2) (same x or same z). y0 = base, h = height, t = thickness.
-- openings = { {c = absolute center along the wall, w = width, h = height, b = bottom offset, glass = bool, frame = bool} }
-- opts = { glass = Color3, frame = Color3 (window/door frame colour), base = Color3 (baseboard), crown = Color3 (crown moulding),
--          noFrames = bool, mullion = spacing }
function U.wall(parent, x1, z1, x2, z2, y0, h, t, color, mat, openings, opts)
	opts = opts or {}
	local alongX = math.abs(z2 - z1) < 1e-3
	local lo, hi
	local fixedC
	if alongX then
		lo, hi = math.min(x1, x2), math.max(x1, x2)
		fixedC = z1
	else
		lo, hi = math.min(z1, z2), math.max(z1, z2)
		fixedC = x1
	end
	-- box in wall-local coords: along a..b, height ya..yb, thickness th
	local function wbox(a, b, ya, yb, th, col, m, props)
		if b - a < 0.05 or yb - ya < 0.05 then
			return nil
		end
		if alongX then
			return U.box(parent, a, ya, fixedC - th / 2, b, yb, fixedC + th / 2, col, m, props)
		else
			return U.box(parent, fixedC - th / 2, ya, a, fixedC + th / 2, yb, b, col, m, props)
		end
	end
	local function solid(a, b)
		wbox(a, b, y0, y0 + h, t, color, mat)
		if b - a > 0.3 then
			-- trims stop 0.03 short of the segment ends (and their tops/bottoms are offset) so no end cap is coplanar
			if opts.base then
				wbox(a + 0.03, b - 0.03, y0 + 0.01, y0 + 0.8, t + 0.24, opts.base, M.Wood)
			end
			if opts.crown then
				wbox(a + 0.03, b - 0.03, y0 + h - 0.7, y0 + h - 0.1, t + 0.3, opts.crown, M.SmoothPlastic)
			end
		end
	end
	local ops = table.clone(openings or {})
	table.sort(ops, function(a, b)
		return a.c < b.c
	end)
	local frameCol = opts.frame or C.white
	local cur = lo
	for _, o in ops do
		local a = math.max(lo, o.c - o.w / 2)
		local b = math.min(hi, o.c + o.w / 2)
		local bot = o.b or 0
		solid(cur, a)
		local top = y0 + bot + o.h
		wbox(a, b, top, y0 + h, t, color, mat)
		if opts.crown and y0 + h - top > 0.8 then
			wbox(a + 0.03, b - 0.03, y0 + h - 0.7, y0 + h - 0.1, t + 0.3, opts.crown, M.SmoothPlastic)
		end
		if bot > 0 then
			wbox(a, b, y0, y0 + bot, t, color, mat)
		end
		if not opts.noFrames and o.frame ~= false then
			-- frame: jambs + head (+ sill for windows), protruding 0.15 each side
			local ft = t + 0.3
			wbox(a - 0.35, a + 0.05, y0 + bot + 0.01, top + 0.33, ft, frameCol, M.SmoothPlastic, { CastShadow = false })
			wbox(b - 0.05, b + 0.35, y0 + bot + 0.01, top + 0.33, ft, frameCol, M.SmoothPlastic, { CastShadow = false })
			wbox(a - 0.37, b + 0.37, top - 0.05, top + 0.35, ft - 0.04, frameCol, M.SmoothPlastic, { CastShadow = false })
			if bot > 0 then
				wbox(a - 0.5, b + 0.5, y0 + bot - 0.3, y0 + bot + 0.05, t + 0.7, frameCol, M.SmoothPlastic, { CastShadow = false })
			end
		end
		if o.glass then
			local g = wbox(a, b, y0 + bot, top, 0.3, opts.glass or C.glass, M.Glass, { Transparency = 0.55, CastShadow = false, Reflectance = 0.15 })
			if g then
				g.Name = "Window"
			end
			-- mullions
			local sp = opts.mullion or 5
			local n = math.floor((b - a) / sp)
			if n >= 1 and not opts.noFrames then
				for k = 1, n do
					local mc = a + (b - a) * k / (n + 1)
					wbox(mc - 0.12, mc + 0.12, y0 + bot, top, 0.5, frameCol, M.SmoothPlastic, { CastShadow = false })
				end
			end
			if o.h > 7 and not opts.noFrames then
				local ty = y0 + bot + o.h * 0.72
				wbox(a, b, ty - 0.1, ty + 0.1, 0.5, frameCol, M.SmoothPlastic, { CastShadow = false })
			end
		end
		cur = math.max(cur, b)
	end
	solid(cur, hi)
end

-- evenly spaced window openings between lo and hi, skipping ranges { {a,b}, ... }
function U.windows(lo, hi, spacing, w, b, h, skips)
	local list = {}
	local n = math.floor((hi - lo) / spacing)
	local start = lo + ((hi - lo) - (n - 1) * spacing) / 2
	for i = 0, n - 1 do
		local c = start + i * spacing
		local ok = true
		for _, s in skips or {} do
			if c + w / 2 > s[1] - 1 and c - w / 2 < s[2] + 1 then
				ok = false
			end
		end
		if ok then
			table.insert(list, { c = c, w = w, b = b, h = h, glass = true })
		end
	end
	return list
end

------------------------------------------------------------------ slabs with holes
-- holes = { {x1,z1,x2,z2}, ... }; builds the rectangle minus holes with few parts
function U.slab(parent, x1, z1, x2, z2, y1, y2, holes, color, mat, props)
	local xs, zs = { x1, x2 }, { z1, z2 }
	for _, hl in holes or {} do
		for _, v in { hl[1], hl[3] } do
			if v > x1 and v < x2 then
				table.insert(xs, v)
			end
		end
		for _, v in { hl[2], hl[4] } do
			if v > z1 and v < z2 then
				table.insert(zs, v)
			end
		end
	end
	table.sort(xs)
	table.sort(zs)
	local function inHole(cx, cz)
		for _, hl in holes or {} do
			if cx > math.min(hl[1], hl[3]) and cx < math.max(hl[1], hl[3]) and cz > math.min(hl[2], hl[4]) and cz < math.max(hl[2], hl[4]) then
				return true
			end
		end
		return false
	end
	local parts = {}
	for j = 1, #zs - 1 do
		local za, zb = zs[j], zs[j + 1]
		if zb - za > 0.01 then
			local runStart = nil
			for i = 1, #xs do
				local solid = false
				if i < #xs and xs[i + 1] - xs[i] > 0.01 then
					solid = not inHole((xs[i] + xs[i + 1]) / 2, (za + zb) / 2)
				end
				if solid and not runStart then
					runStart = xs[i]
				elseif not solid and runStart then
					if i <= #xs then
						table.insert(parts, U.box(parent, runStart, y1, za, xs[i], y2, zb, color, mat, props))
					end
					runStart = nil
				end
			end
		end
	end
	return parts
end

------------------------------------------------------------------ stairs
-- base = bottom-front-centre at the lower floor height; dir = unit axis vector of ascent
function U.stairs(parent, base, dir, width, n, rise, run, color, mat, nosing)
	for i = 1, n do
		local h = i * rise
		local center = base + dir * ((i - 0.5) * run) + Vector3.new(0, h / 2, 0)
		local size = if math.abs(dir.X) > 0.5 then Vector3.new(run, h, width) else Vector3.new(width, h, run)
		U.part(parent, size, CFrame.new(center), color, mat)
		if nosing and i % 2 == 0 then
			local ncen = base + dir * ((i - 1) * run + 0.18) + Vector3.new(0, h + 0.01, 0)
			local nsize = if math.abs(dir.X) > 0.5 then Vector3.new(0.4, 0.06, width - 0.1) else Vector3.new(width - 0.1, 0.06, 0.4)
			U.part(parent, nsize, CFrame.new(ncen), nosing, M.Metal, { CanCollide = false })
		end
	end
end

------------------------------------------------------------------ railings
-- glass railing with gold handrail between two points on the same y
function U.rail(parent, x1, z1, x2, z2, y, h, opts)
	opts = opts or {}
	h = h or 3.5
	local alongX = math.abs(z2 - z1) < 1e-3
	local t = 0.25
	if alongX then
		U.box(parent, x1, y, z1 - t / 2, x2, y + h - 0.3, z1 + t / 2, opts.glass or C.glass, M.Glass, { Transparency = 0.6, CastShadow = false })
		U.box(parent, x1, y + h - 0.3, z1 - 0.3, x2, y + h, z1 + 0.3, opts.top or C.gold, M.Metal)
	else
		U.box(parent, x1 - t / 2, y, z1, x1 + t / 2, y + h - 0.3, z2, opts.glass or C.glass, M.Glass, { Transparency = 0.6, CastShadow = false })
		U.box(parent, x1 - 0.3, y + h - 0.3, z1, x1 + 0.3, y + h, z2, opts.top or C.gold, M.Metal)
	end
end


------------------------------------------------------------------ detail helpers
-- classical round column: square plinth, torus base, shaft, capital, abacus
function U.column(parent, x, y1, z, y2, d, color, capColor)
	capColor = capColor or C.gold
	local h = y2 - y1
	U.box(parent, x - d * 0.75, y1, z - d * 0.75, x + d * 0.75, y1 + 0.6, z + d * 0.75, color, M.Marble, { Reflectance = 0.08 })
	U.vcyl(parent, x, y1 + 0.6, z, y1 + 1.2, d * 1.3, capColor, M.Metal, { Reflectance = 0.15 })
	U.vcyl(parent, x, y1 + 1.2, z, y2 - 1.2, d, color, M.Marble, { Reflectance = 0.08 })
	U.vcyl(parent, x, y2 - 1.2, z, y2 - 0.6, d * 1.3, capColor, M.Metal, { Reflectance = 0.15 })
	U.box(parent, x - d * 0.75, y2 - 0.6, z - d * 0.75, x + d * 0.75, y2, z + d * 0.75, color, M.Marble, { Reflectance = 0.08 })
	return h
end

-- door frame (jambs + header) around an opening; axis "x" = wall along X
function U.doorFrame(parent, axis, c, fixed, y0, w, h, t, color)
	color = color or C.white
	local ft = t + 0.3
	local function b(a1, a2, ya, yb)
		if axis == "x" then
			U.box(parent, a1, ya, fixed - ft / 2, a2, yb, fixed + ft / 2, color, M.SmoothPlastic, { CastShadow = false })
		else
			U.box(parent, fixed - ft / 2, ya, a1, fixed + ft / 2, yb, a2, color, M.SmoothPlastic, { CastShadow = false })
		end
	end
	b(c - w / 2 - 0.45, c - w / 2 + 0.02, y0, y0 + h + 0.45)
	b(c + w / 2 - 0.02, c + w / 2 + 0.45, y0, y0 + h + 0.45)
	b(c - w / 2 - 0.45, c + w / 2 + 0.45, y0 + h - 0.02, y0 + h + 0.45)
end

-- framed picture: cf faces the viewer (LookVector toward viewer)
local artSets = {
	{ Color3.fromRGB(255, 160, 110), Color3.fromRGB(250, 110, 140), Color3.fromRGB(255, 220, 140) },
	{ Color3.fromRGB(60, 170, 200), Color3.fromRGB(30, 100, 140), Color3.fromRGB(240, 220, 170) },
	{ Color3.fromRGB(120, 200, 140), Color3.fromRGB(40, 120, 90), Color3.fromRGB(250, 240, 200) },
	{ Color3.fromRGB(250, 200, 90), Color3.fromRGB(230, 120, 60), Color3.fromRGB(70, 40, 90) },
}
U.artIndex = 0
function U.picture(parent, cf, w, h, frameColor)
	U.part(parent, Vector3.new(w + 0.5, h + 0.5, 0.18), cf, frameColor or C.gold, M.Metal, { CanCollide = false, Reflectance = 0.12 })
	local canvas = U.part(parent, Vector3.new(w, h, 0.1), cf * CFrame.new(0, 0, -0.08), C.paper, M.Fabric, { CanCollide = false })
	U.artIndex += 1
	local set = artSets[(U.artIndex % #artSets) + 1]
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 25
	sg.LightInfluence = 1
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BorderSizePixel = 0
	bg.BackgroundColor3 = Color3.new(1, 1, 1)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(set[1], set[2])
	grad.Rotation = 90
	grad.Parent = bg
	bg.Parent = sg
	-- sun / island shapes
	local sun = Instance.new("Frame")
	sun.AnchorPoint = Vector2.new(0.5, 0.5)
	sun.Position = UDim2.fromScale(0.65, 0.38)
	sun.Size = UDim2.fromScale(0.3, 0.3 * w / h)
	sun.BackgroundColor3 = set[3]
	sun.BorderSizePixel = 0
	local cr = Instance.new("UICorner")
	cr.CornerRadius = UDim.new(0.5, 0)
	cr.Parent = sun
	sun.Parent = bg
	local hill = Instance.new("Frame")
	hill.AnchorPoint = Vector2.new(0.5, 0)
	hill.Position = UDim2.fromScale(0.35, 0.68)
	hill.Size = UDim2.fromScale(0.9, 0.6)
	hill.BackgroundColor3 = set[2]:Lerp(Color3.new(0, 0, 0), 0.35)
	hill.BorderSizePixel = 0
	local cr2 = Instance.new("UICorner")
	cr2.CornerRadius = UDim.new(0.5, 0)
	cr2.Parent = hill
	hill.Parent = bg
	sg.Parent = canvas
	return canvas
end

-- recessed ceiling downlight (ceilingY = underside of the ceiling)
function U.downlight(parent, x, ceilingY, z, range, brightness)
	U.vcyl(parent, x, ceilingY - 0.2, z, ceilingY + 0.02, 1.8, C.goldDark, M.Metal, { CanCollide = false, CastShadow = false })
	local l = U.vcyl(parent, x, ceilingY - 0.25, z, ceilingY - 0.15, 1.3, Color3.fromRGB(255, 246, 225), M.Neon, { CanCollide = false, CastShadow = false })
	U.tag(l, "ResortNeon")
	U.light(l, Color3.fromRGB(255, 236, 205), range or 22, brightness or 0.9)
	return l
end

-- layered rug with border (y = floor top)
function U.rug(parent, x1, z1, x2, z2, y, color, border)
	U.box(parent, x1, y, z1, x2, y + 0.08, z2, border or C.gold, M.Fabric, { CanCollide = false, CastShadow = false })
	U.box(parent, x1 + 0.7, y, z1 + 0.7, x2 - 0.7, y + 0.13, z2 - 0.7, color, M.Fabric, { CanCollide = false, CastShadow = false })
end

-- potted plant (pos = floor point)
function U.plant(parent, pos, s, potColor)
	s = s or 1
	local x, y, z = pos.X, pos.Y, pos.Z
	U.vcyl(parent, x, y, z, y + 2.2 * s, 2.2 * s, potColor or C.white, M.Marble, { Reflectance = 0.05 })
	U.vcyl(parent, x, y + 2.2 * s, z, y + 2.45 * s, 2.5 * s, C.goldDark, M.Metal, { CanCollide = false })
	U.ball(parent, Vector3.new(x, y + 3.6 * s, z), 2.8 * s, C.leaf, M.Grass, { CanCollide = false })
	U.ball(parent, Vector3.new(x + 0.6 * s, y + 4.6 * s, z - 0.4 * s), 2 * s, C.leaf2, M.Grass, { CanCollide = false })
end

-- foundation skirt hugging the outside of a building rectangle (top 4.0, below the 4.2 walk level)
function U.skirt(parent, x1, z1, x2, z2, color)
	color = color or C.stone
	local t = 0.4
	U.box(parent, x1 - t, 0, z1 - t, x2 + t, 4, z1, color, M.Concrete)
	U.box(parent, x1 - t, 0, z2, x2 + t, 4, z2 + t, color, M.Concrete)
	U.box(parent, x1 - t, 0, z1, x1, 4, z2, color, M.Concrete)
	U.box(parent, x2, 0, z1, x2 + t, 4, z2, color, M.Concrete)
end

------------------------------------------------------------------ gameplay hooks
function U.interact(part, kind, id, zone, label, extra)
	assert(not U.ids[id], "duplicate Interact id " .. id)
	U.ids[id] = true
	CollectionService:AddTag(part, "Interact")
	part:SetAttribute("Kind", kind)
	part:SetAttribute("Id", id)
	part:SetAttribute("Zone", zone)
	part:SetAttribute("Label", label)
	if extra then
		for k, v in extra do
			part:SetAttribute(k, v)
		end
	end
	if part.Name == "Part" or part.Name == "Sign" then
		part.Name = id
	end
	U.interactCounts[kind] = (U.interactCounts[kind] or 0) + 1
	return part
end

-- door slab inside a wall opening. axis "x" = wall runs along X (door faces ±Z)
function U.door(parent, axis, x, z, floorY, zone, id, lock, label, opts)
	opts = opts or {}
	local w, h = opts.w or 7.6, opts.h or 10.6
	local size = if axis == "x" then Vector3.new(w, h, 0.6) else Vector3.new(0.6, h, w)
	local p = U.part(parent, size, CFrame.new(x, floorY + h / 2, z), opts.color or C.woodDark, opts.mat or M.Wood, {
		Transparency = opts.transparency or 0,
	})
	local extra = { Lock = lock or "none" }
	if opts.code then
		extra.Code = opts.code
	end
	if opts.inside then
		extra.Inside = opts.inside -- "+"/"-": side of the door plane the room is on (opens free from inside)
	end
	U.interact(p, "Door", id, zone, label, extra)
	if opts.text then
		local o = { fg = opts.textColor or C.gold, pps = 30, textH = 0.18, textW = 0.8, stroke = 0.4 }
		addGui(p, Enum.NormalId.Front, opts.text, o)
		addGui(p, Enum.NormalId.Back, opts.text, o)
	end
	return p
end

function U.zone(parent, id, meta, x1, y1, z1, x2, y2, z2)
	local p = U.box(parent, x1, y1, z1, x2, y2, z2, C.white, M.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	p.Name = id
	p:SetAttribute("ZoneId", id)
	p:SetAttribute("DisplayName", meta.name)
	p:SetAttribute("Outdoor", meta.outdoor)
	p:SetAttribute("Restricted", meta.restricted)
	return p
end

function U.marker(folder, name, pos, attrs, className)
	local p = U.newPart(className or "Part")
	p.Size = Vector3.new(2, 2, 2)
	p.CFrame = CFrame.new(pos)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Name = name
	if attrs then
		for k, v in attrs do
			p:SetAttribute(k, v)
		end
	end
	p.Parent = folder
	U.markerCount += 1
	return p
end

------------------------------------------------------------------ terrain height
local terrainParams = RaycastParams.new()
terrainParams.FilterType = Enum.RaycastFilterType.Include
terrainParams.IgnoreWater = true
function U.groundY(x, z, fallback)
	terrainParams.FilterDescendantsInstances = { workspace.Terrain }
	local r = workspace:Raycast(Vector3.new(x, 120, z), Vector3.new(0, -220, 0), terrainParams)
	if r then
		return r.Position.Y
	end
	return fallback or 2
end

return U
