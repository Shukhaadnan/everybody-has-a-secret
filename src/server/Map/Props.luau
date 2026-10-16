--!nocheck
-- Props: reusable furniture / decor builders. cf = floor point CFrame, LookVector = the side a user faces from (front).
local U = require(script.Parent.Util)
local C, M = U.C, U.M
local rel, part = U.rel, U.part
local rad = math.rad

local P = {}

local NOCOL = { CanCollide = false }
local function nc(extra)
	local t = { CanCollide = false }
	if extra then
		for k, v in extra do
			t[k] = v
		end
	end
	return t
end

------------------------------------------------------------------ palms
-- tapered, slightly curved trunk + drooping two-segment fronds
function P.palm(parent, pos, h, rot, lean)
	h = h or 22
	rot = rot or 0
	lean = lean or 3
	local dir = Vector3.new(math.cos(rot), 0, math.sin(rot))
	local n = 6
	local prev = pos - Vector3.new(0, 1, 0)
	for i = 1, n do
		local t = i / n
		local p = pos + Vector3.new(0, h * t, 0) + dir * (lean * t * t)
		local d = 1.9 - 0.9 * t
		U.beam(parent, prev, p, d, (i % 2 == 0) and C.trunk or C.trunk2, M.Wood)
		prev = p
	end
	local top = prev
	U.ball(parent, top + Vector3.new(0, 0.3, 0), 2.2, C.leaf, M.Grass, NOCOL)
	for k = 0, 2 do
		local a = k * 2.1 + rot
		U.ball(parent, top + Vector3.new(math.cos(a) * 0.9, -0.7, math.sin(a) * 0.9), 0.9, C.woodDark, M.SmoothPlastic, NOCOL)
	end
	local fronds = 8
	for k = 0, fronds - 1 do
		local a = (k / fronds) * math.pi * 2 + rot * 0.7
		local base = CFrame.new(top + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, a, 0)
		local col = (k % 2 == 0) and C.leaf or C.leaf2
		local L1, L2 = 5.5, 5
		local c1 = base * CFrame.Angles(rad(12 + (k % 3) * 6), 0, 0)
		part(parent, Vector3.new(2, 0.18, L1), c1 * CFrame.new(0, 0, -L1 / 2), col, M.Grass, NOCOL)
		local c2 = c1 * CFrame.new(0, 0, -L1) * CFrame.Angles(rad(-38), 0, 0)
		-- tapering tip: wedge rotated so the triangle lies flat
		U.wedge(parent, Vector3.new(0.18, 2, L2), c2 * CFrame.new(0, 0, -L2 / 2) * CFrame.Angles(0, 0, math.pi / 2), col, M.Grass, NOCOL)
	end
	return top
end

------------------------------------------------------------------ outdoor
-- 8-panel striped parasol
function P.umbrella(parent, pos, c1, c2, h, r)
	h = h or 9
	r = r or 4.6
	U.vcyl(parent, pos.X, pos.Y, pos.Z, pos.Y + h, 0.35, C.white, M.Metal)
	U.vcyl(parent, pos.X, pos.Y, pos.Z, pos.Y + 0.4, 2, C.white, M.Marble)
	local apex = pos + Vector3.new(0, h + 0.2, 0)
	local drop = 1.8
	local slant = math.sqrt(r * r + drop * drop)
	local tilt = math.atan2(drop, r)
	for k = 0, 7 do
		local a = k * math.pi / 4
		local cf = CFrame.new(apex) * CFrame.Angles(0, a, 0) * CFrame.Angles(-tilt, 0, 0) * CFrame.new(0, 0, -slant / 2)
		part(parent, Vector3.new(2 * r * math.sin(math.pi / 8) + 0.25, 0.12, slant), cf, (k % 2 == 0) and c1 or c2, M.Fabric, nc({ CastShadow = true }))
	end
	U.ball(parent, apex + Vector3.new(0, 0.15, 0), 0.6, C.gold, M.Metal, NOCOL)
end

-- sun lounger
function P.lounger(parent, cf, color)
	rel(parent, cf, 0, 0.6, 0, 2.6, 0.5, 6.4, C.white, M.SmoothPlastic)
	rel(parent, cf, 0, 1.0, 0.8, 2.4, 0.35, 4.6, color, M.Fabric)
	part(parent, Vector3.new(2.4, 0.35, 2.4), cf * CFrame.new(0, 1.6, -2.4) * CFrame.Angles(rad(40), 0, 0), color, M.Fabric)
	part(parent, Vector3.new(1.6, 0.4, 0.8), cf * CFrame.new(0, 2.0, -2.9) * CFrame.Angles(rad(40), 0, 0), C.white, M.Fabric, NOCOL)
end

function P.bench(parent, cf, color)
	color = color or C.woodLight
	for i = -1, 1 do
		rel(parent, cf, 0, 1.9, i * 0.55, 6, 0.2, 0.45, color, M.Wood)
	end
	part(parent, Vector3.new(6, 1.4, 0.2), cf * CFrame.new(0, 2.9, 1.05) * CFrame.Angles(rad(-12), 0, 0), color, M.Wood)
	rel(parent, cf, -2.6, 0.95, 0.2, 0.3, 1.9, 1.9, C.darkSteel, M.Metal)
	rel(parent, cf, 2.6, 0.95, 0.2, 0.3, 1.9, 1.9, C.darkSteel, M.Metal)
end

function P.streetLamp(parent, pos, h, color)
	h = h or 12
	U.vcyl(parent, pos.X, pos.Y, pos.Z, pos.Y + 0.8, 1.6, C.darkSteel, M.Metal)
	U.vcyl(parent, pos.X, pos.Y + 0.8, pos.Z, pos.Y + h, 0.45, C.darkSteel, M.Metal)
	local glow = U.part(parent, Vector3.new(1.3, 1.6, 1.3), CFrame.new(pos + Vector3.new(0, h + 0.9, 0)), color or Color3.fromRGB(255, 236, 190), M.Neon, NOCOL)
	U.tag(glow, "ResortNeon")
	U.light(glow, Color3.fromRGB(255, 226, 180), 22, 1.1)
	U.part(parent, Vector3.new(2.2, 0.4, 2.2), CFrame.new(pos + Vector3.new(0, h + 1.9, 0)), C.gold, M.Metal, NOCOL)
	U.ball(parent, pos + Vector3.new(0, h + 2.3, 0), 0.5, C.gold, M.Metal, NOCOL)
end

-- planter box with shrub balls (cf at floor)
function P.planter(parent, cf, w, d, color)
	rel(parent, cf, 0, 1.2, 0, w, 2.4, d, color or C.cream, M.Concrete)
	rel(parent, cf, 0, 2.5, 0, w + 0.4, 0.3, d + 0.4, C.gold, M.Metal)
	rel(parent, cf, 0, 2.45, 0, w - 0.6, 0.2, d - 0.6, C.woodDark, M.Ground, NOCOL)
	local n = math.max(1, math.floor(w / 3))
	for i = 1, n do
		local x = -w / 2 + (i - 0.5) * w / n
		U.ball(parent, (cf * CFrame.new(x, 3.6, 0)).Position, math.min(3.4, d + 0.6), (i % 2 == 0) and C.leaf or C.leaf2, M.Grass, NOCOL)
	end
end

function P.bush(parent, pos, s)
	s = s or 1
	U.ball(parent, pos + Vector3.new(0, 1.4 * s, 0), 3.4 * s, C.leaf, M.Grass, NOCOL)
	U.ball(parent, pos + Vector3.new(1.3 * s, 1.1 * s, 0.6 * s), 2.6 * s, C.leaf2, M.Grass, NOCOL)
	U.ball(parent, pos + Vector3.new(-0.9 * s, 2.1 * s, -0.6 * s), 2.4 * s, Color3.fromRGB(255, 120, 170), M.Grass, NOCOL)
end

------------------------------------------------------------------ seating / tables
function P.chair(parent, cf, cushion, frame)
	frame = frame or C.woodDark
	for _, o in { { -0.85, -0.85 }, { 0.85, -0.85 }, { -0.85, 0.85 }, { 0.85, 0.85 } } do
		rel(parent, cf, o[1], 0.9, o[2], 0.25, 1.8, 0.25, frame, M.Wood)
	end
	rel(parent, cf, 0, 1.95, 0, 2.1, 0.3, 2.1, frame, M.Wood)
	rel(parent, cf, 0, 2.25, 0.05, 1.9, 0.3, 1.9, cushion or C.cream, M.Fabric)
	part(parent, Vector3.new(2.1, 2.6, 0.3), cf * CFrame.new(0, 3.4, 1) * CFrame.Angles(rad(-8), 0, 0), cushion or C.cream, M.Fabric)
end

function P.stool(parent, pos, color)
	U.vcyl(parent, pos.X, pos.Y, pos.Z, pos.Y + 0.2, 1.8, C.gold, M.Metal, { Reflectance = 0.15 })
	U.vcyl(parent, pos.X, pos.Y + 0.2, pos.Z, pos.Y + 3, 0.35, C.gold, M.Metal)
	U.vcyl(parent, pos.X, pos.Y + 3, pos.Z, pos.Y + 3.55, 1.9, color or C.red, M.Fabric)
end

function P.roundTable(parent, pos, d, h, top, cloth)
	h = h or 3
	U.vcyl(parent, pos.X, pos.Y, pos.Z, pos.Y + 0.25, d * 0.45, C.goldDark, M.Metal)
	U.vcyl(parent, pos.X, pos.Y + 0.25, pos.Z, pos.Y + h - 0.25, 0.45, C.goldDark, M.Metal)
	if cloth then
		U.vcyl(parent, pos.X, pos.Y + h - 1.4, pos.Z, pos.Y + h - 0.02, d + 0.3, cloth, M.Fabric)
	end
	return U.vcyl(parent, pos.X, pos.Y + h - 0.25, pos.Z, pos.Y + h, d, top or C.white, M.Marble, { Reflectance = 0.06 })
end

-- table + chairs + place settings + centrepiece
function P.diningSet(parent, pos, n, cloth, cushion)
	local d = 5
	local t = P.roundTable(parent, pos, d, 3, C.white, cloth or C.white)
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local off = Vector3.new(math.cos(a), 0, math.sin(a))
		local cpos = pos + off * 3.9
		P.chair(parent, CFrame.lookAt(cpos, cpos + off), cushion or C.coral)
		local plate = pos + off * 1.6 + Vector3.new(0, 3.05, 0)
		U.vcyl(parent, plate.X, plate.Y - 0.03, plate.Z, plate.Y + 0.05, 1.1, C.white, M.SmoothPlastic, NOCOL)
	end
	U.vcyl(parent, pos.X, pos.Y + 3, pos.Z, pos.Y + 3.9, 0.6, C.glass, M.Glass, nc({ Transparency = 0.3 }))
	U.ball(parent, pos + Vector3.new(0, 4.3, 0), 1.1, C.coral, M.Fabric, NOCOL)
	return t
end

function P.sofa(parent, cf, w, color, pillow)
	color = color or C.cream
	rel(parent, cf, 0, 0.6, 0, w - 0.2, 1, 3.0, C.woodDark, M.Wood)
	local seats = math.max(1, math.floor(w / 3))
	for i = 1, seats do
		local x = -w / 2 + 0.6 + (i - 0.5) * (w - 1.2) / seats
		rel(parent, cf, x, 1.45, -0.15, (w - 1.2) / seats - 0.1, 0.8, 2.6, color, M.Fabric)
	end
	rel(parent, cf, 0, 2.6, 1.25, w - 0.04, 3.2, 0.8, color, M.Fabric)
	rel(parent, cf, -w / 2 + 0.3, 1.9, 0, 0.6, 1.6, 3.2, color, M.Fabric)
	rel(parent, cf, w / 2 - 0.3, 1.9, 0, 0.6, 1.6, 3.2, color, M.Fabric)
	U.cyl(parent, cf * CFrame.new(-w / 2 + 0.3, 2.7, 0) * CFrame.Angles(0, math.pi / 2, 0), 3.2, 0.75, color, M.Fabric)
	U.cyl(parent, cf * CFrame.new(w / 2 - 0.3, 2.7, 0) * CFrame.Angles(0, math.pi / 2, 0), 3.2, 0.75, color, M.Fabric)
	if pillow then
		part(parent, Vector3.new(1.4, 1.4, 0.4), cf * CFrame.new(-w / 2 + 1.6, 2.6, 0.7) * CFrame.Angles(rad(-15), 0, rad(8)), pillow, M.Fabric, NOCOL)
		part(parent, Vector3.new(1.4, 1.4, 0.4), cf * CFrame.new(w / 2 - 1.6, 2.6, 0.7) * CFrame.Angles(rad(-15), 0, rad(-8)), pillow, M.Fabric, NOCOL)
	end
end

function P.coffeeTable(parent, cf, w, d)
	rel(parent, cf, 0, 0.9, 0, w - 0.6, 1.4, d - 0.6, C.woodDark, M.Wood)
	rel(parent, cf, 0, 1.75, 0, w, 0.3, d, C.marble, M.Marble, { Reflectance = 0.08 })
end

-- bed (cf = foot-of-bed floor point; headboard toward +Z of cf i.e. away from LookVector)
function P.bed(parent, cf, duvet)
	local W, L = 6, 7.5
	rel(parent, cf, 0, 0.8, 0, W, 1.2, L, C.woodDark, M.Wood)
	rel(parent, cf, 0, 1.9, 0, W - 0.3, 1, L - 0.3, C.white, M.Fabric)
	rel(parent, cf, 0, 2.45, -0.9, W - 0.1, 0.25, L - 2.2, duvet or C.teal, M.Fabric)
	rel(parent, cf, 0, 2.4, -L / 2 + 0.9, W - 0.05, 0.3, 1.2, C.gold, M.Fabric, NOCOL)
	rel(parent, cf, -1.4, 2.7, L / 2 - 1, 2.4, 0.7, 1.3, C.white, M.Fabric, NOCOL)
	rel(parent, cf, 1.4, 2.7, L / 2 - 1, 2.4, 0.7, 1.3, C.white, M.Fabric, NOCOL)
	rel(parent, cf, 0, 3.4, L / 2 + 0.25, W + 0.8, 5.2, 0.5, duvet or C.teal, M.Fabric)
	rel(parent, cf, 0, 6.1, L / 2 + 0.25, W + 1, 0.3, 0.7, C.gold, M.Metal)
end

-- nightstand / cabinet with drawer lines; returns body (Search host)
function P.cabinet(parent, cf, w, h, d, color, handle)
	local body = rel(parent, cf, 0, h / 2, 0, w, h, d, color or C.woodDark, M.Wood)
	local drawers = math.max(1, math.floor(h / 1.4))
	for i = 1, drawers do
		local y = (i - 0.5) * h / drawers
		rel(parent, cf, 0, y, -d / 2 - 0.05, w - 0.4, h / drawers - 0.25, 0.1, color and color:Lerp(Color3.new(1, 1, 1), 0.12) or C.wood, M.Wood, NOCOL)
		rel(parent, cf, 0, y, -d / 2 - 0.15, 0.8, 0.15, 0.12, handle or C.gold, M.Metal, NOCOL)
	end
	rel(parent, cf, 0, h + 0.08, 0, w + 0.2, 0.16, d + 0.2, C.marble, M.Marble, { Reflectance = 0.08 })
	return body
end

-- tall wardrobe (Hide host)
function P.wardrobe(parent, cf, color)
	local body = rel(parent, cf, 0, 4.5, 0, 5, 9, 2.6, color or C.woodLight, M.Wood)
	rel(parent, cf, 0, 4.5, -1.33, 0.08, 8.4, 0.08, C.woodDark, M.Wood, NOCOL)
	rel(parent, cf, -0.4, 4.5, -1.4, 0.15, 1.6, 0.15, C.gold, M.Metal, NOCOL)
	rel(parent, cf, 0.4, 4.5, -1.4, 0.15, 1.6, 0.15, C.gold, M.Metal, NOCOL)
	rel(parent, cf, 0, 9.1, 0, 5.4, 0.3, 3, C.gold, M.Metal)
	return body
end

-- table lamp on a surface point
function P.tableLamp(parent, pos, shade)
	U.vcyl(parent, pos.X, pos.Y, pos.Z, pos.Y + 0.2, 0.9, C.gold, M.Metal, NOCOL)
	U.vcyl(parent, pos.X, pos.Y + 0.2, pos.Z, pos.Y + 1.4, 0.2, C.gold, M.Metal, NOCOL)
	local s = U.vcyl(parent, pos.X, pos.Y + 1.3, pos.Z, pos.Y + 2.3, 1.4, shade or C.cream, M.Fabric, nc({ Transparency = 0.05 }))
	U.light(s, Color3.fromRGB(255, 220, 170), 12, 0.8)
	return s
end

function P.floorLamp(parent, pos, shade)
	U.vcyl(parent, pos.X, pos.Y, pos.Z, pos.Y + 0.25, 1.4, C.gold, M.Metal)
	U.vcyl(parent, pos.X, pos.Y + 0.25, pos.Z, pos.Y + 5.5, 0.25, C.gold, M.Metal)
	local s = U.vcyl(parent, pos.X, pos.Y + 5.2, pos.Z, pos.Y + 6.6, 1.8, shade or C.cream, M.Fabric, NOCOL)
	U.light(s, Color3.fromRGB(255, 220, 170), 16, 0.9)
end

-- crystal chandelier hanging from a ceiling point
function P.chandelier(parent, ceil, r)
	r = r or 3
	U.vcyl(parent, ceil.X, ceil.Y - 2.2, ceil.Z, ceil.Y, 0.2, C.gold, M.Metal, NOCOL)
	local hub = U.ball(parent, ceil - Vector3.new(0, 2.6, 0), 1.2, C.gold, M.Metal, nc({ Reflectance = 0.2 }))
	U.part(parent, Vector3.new(0.25, r * 2, r * 2), CFrame.new(ceil - Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.pi / 2), C.gold, M.Metal, nc({ Shape = Enum.PartType.Cylinder, Reflectance = 0.2 }))
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local p = ceil + Vector3.new(math.cos(a) * r, -2.5, math.sin(a) * r)
		local b = U.ball(parent, p, 0.6, Color3.fromRGB(255, 248, 230), M.Neon, NOCOL)
		U.tag(b, "ResortNeon")
		U.part(parent, Vector3.new(0.3, 1.2, 0.3), CFrame.new(p - Vector3.new(0, 1.1, 0)), C.glass, M.Glass, nc({ Transparency = 0.3 }))
	end
	local core = U.ball(parent, ceil - Vector3.new(0, 4, 0), 1, Color3.fromRGB(230, 245, 255), M.Glass, nc({ Transparency = 0.2 }))
	U.light(hub, Color3.fromRGB(255, 232, 196), 30, 1.3, false)
	return core
end

------------------------------------------------------------------ counters / kitchen
-- counter with stone top, kick plinth and gold trim; axis aligned; y = floor
function P.counter(parent, x1, z1, x2, z2, y, h, body, top)
	local b = U.box(parent, x1, y, z1, x2, y + h - 0.3, z2, body or C.woodDark, M.Wood)
	U.box(parent, x1 - 0.3, y + h - 0.3, z1 - 0.3, x2 + 0.3, y + h, z2 + 0.3, top or C.marble, M.Marble, { Reflectance = 0.1 })
	U.box(parent, x1 - 0.12, y + h - 0.75, z1 - 0.12, x2 + 0.12, y + h - 0.55, z2 + 0.12, C.gold, M.Metal, { CanCollide = false })
	return b
end

function P.fridge(parent, cf, color)
	local body = rel(parent, cf, 0, 4, 0, 3.6, 8, 3, color or C.steel, M.DiamondPlate)
	rel(parent, cf, 0, 5.2, -1.52, 3.5, 0.08, 0.06, C.darkSteel, M.Metal, NOCOL)
	rel(parent, cf, 1.4, 6.4, -1.65, 0.2, 1.8, 0.2, C.white, M.Metal, NOCOL)
	rel(parent, cf, 1.4, 3, -1.65, 0.2, 2.4, 0.2, C.white, M.Metal, NOCOL)
	return body
end

function P.stove(parent, cf)
	local b = rel(parent, cf, 0, 1.6, 0, 4, 3.2, 3, C.steel, M.Metal)
	rel(parent, cf, 0, 3.25, 0, 4, 0.1, 3, C.black, M.SmoothPlastic)
	for _, o in { { -1, -0.6 }, { 1, -0.6 }, { -1, 0.7 }, { 1, 0.7 } } do
		local p = (cf * CFrame.new(o[1], 3.35, o[2])).Position
		U.vcyl(parent, p.X, p.Y - 0.05, p.Z, p.Y + 0.1, 1.2, C.darkSteel, M.Metal, NOCOL)
	end
	rel(parent, cf, 0, 1.6, -1.52, 3.4, 1.6, 0.06, C.black, M.Glass, NOCOL)
	-- copper hood
	rel(parent, cf, 0, 9, 0.3, 4.6, 1.6, 3.4, C.steel, M.Metal, NOCOL)
	return b
end

------------------------------------------------------------------ casino
local slotSymbols = { "👾 PLAY", "🏁 RACE", "🎯 AIM", "🕹️ GO", "⭐ HI-SCORE", "🚀 BLAST" }
function P.slot(parent, cf, idx, color)
	color = color or C.red
	local body = rel(parent, cf, 0, 3.2, 0, 3.2, 6.4, 2.6, color, M.SmoothPlastic)
	rel(parent, cf, 0, 6.6, 0.2, 3.4, 0.4, 2.8, C.gold, M.Metal, { Reflectance = 0.15 })
	local topSign = rel(parent, cf, 0, 7.6, 0.2, 3, 1.6, 2.2, C.neonYellow, M.Neon, NOCOL)
	U.tag(topSign, "ResortNeon")
	local screen = rel(parent, cf, 0, 4.7, -1.32, 2.4, 1.6, 0.1, C.black, M.Glass, NOCOL)
	U.addGui(screen, Enum.NormalId.Front, slotSymbols[(idx - 1) % #slotSymbols + 1], { fg = C.neonYellow, font = Enum.Font.FredokaOne, pps = 40 })
	part(parent, Vector3.new(3.4, 0.3, 1.4), cf * CFrame.new(0, 3.2, -1.6) * CFrame.Angles(rad(-15), 0, 0), C.black, M.SmoothPlastic, NOCOL)
	U.vcyl(parent, (cf * CFrame.new(1.85, 0, 0)).Position.X, cf.Position.Y + 3.6, (cf * CFrame.new(1.85, 0, 0)).Position.Z, cf.Position.Y + 5.6, 0.25, C.steel, M.Metal, NOCOL)
	U.ball(parent, (cf * CFrame.new(1.85, 5.8, 0)).Position, 0.6, C.red, M.SmoothPlastic, NOCOL)
	P.stool(parent, (cf * CFrame.new(0, 0, -3)).Position, C.red)
	return body
end

function P.cardTable(parent, cf)
	local top = U.cyl(parent, cf * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.pi / 2), 0.4, 8, C.felt, M.Fabric)
	U.cyl(parent, cf * CFrame.new(0, 2.85, 0) * CFrame.Angles(0, 0, math.pi / 2), 0.5, 8.8, C.woodDark, M.Wood)
	U.cyl(parent, cf * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.pi / 2), 2.6, 1.6, C.woodDark, M.Wood)
	-- dealer side cut: chip rack
	rel(parent, cf, 0, 3.35, 2.8, 3, 0.3, 0.9, C.black, M.SmoothPlastic, NOCOL)
	for i = -2, 2 do
		local p = (cf * CFrame.new(i * 0.55, 3.55, 2.8)).Position
		U.vcyl(parent, p.X, p.Y - 0.1, p.Z, p.Y + 0.15, 0.45, ({ C.red, C.navy, C.felt, C.gold, C.purple })[i + 3], M.SmoothPlastic, NOCOL)
	end
	for i = -1, 1 do
		rel(parent, cf, i * 1.5, 3.23, -1.3, 0.7, 0.05, 1, C.white, M.SmoothPlastic, NOCOL)
	end
	for i = 0, 3 do
		local a = math.rad(200 + i * 47)
		local p = (cf * CFrame.new(math.cos(a) * 5.4, 0, math.sin(a) * 5.4 - 0.3)).Position
		P.stool(parent, p, C.red)
	end
	return top
end

------------------------------------------------------------------ misc
function P.crate(parent, cf, s, color)
	s = s or 3
	local b = rel(parent, cf, 0, s / 2, 0, s, s, s, color or C.woodLight, M.WoodPlanks)
	rel(parent, cf, 0, s / 2, 0, s + 0.1, 0.35, s + 0.1, C.woodDark, M.Wood, NOCOL)
	rel(parent, cf, 0, s / 2, 0, 0.35, s + 0.1, s + 0.1, C.woodDark, M.Wood, NOCOL)
	return b
end

function P.securityCam(parent, mountPos, target)
	local look = CFrame.lookAt(mountPos, target)
	U.part(parent, Vector3.new(0.4, 0.4, 1.2), look * CFrame.new(0, 0.5, 0.6), C.white, M.Metal, NOCOL)
	local body = U.part(parent, Vector3.new(1, 1, 2), look, C.white, M.SmoothPlastic, NOCOL)
	U.cyl(parent, look * CFrame.new(0, 0, -1.1) * CFrame.Angles(0, math.pi / 2, 0), 0.3, 0.8, C.black, M.Glass, NOCOL)
	local led = U.part(parent, Vector3.new(0.2, 0.2, 0.2), look * CFrame.new(0.35, 0.35, -0.95), Color3.fromRGB(255, 40, 40), M.Neon, NOCOL)
	U.tag(led, "ResortNeon")
	return body
end

function P.phone(parent, pos, yaw)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0)
	local base = rel(parent, cf, 0, 0.2, 0, 1.2, 0.4, 0.9, C.black, M.SmoothPlastic, NOCOL)
	rel(parent, cf, 0, 0.55, 0, 1.4, 0.3, 0.35, C.gold, M.Metal, NOCOL)
	return base
end

function P.computer(parent, cf, text)
	rel(parent, cf, 0, 0.1, 0, 1.2, 0.2, 1, C.black, M.Metal, NOCOL)
	rel(parent, cf, 0, 0.9, 0.2, 0.25, 1.4, 0.25, C.black, M.Metal, NOCOL)
	local mon = rel(parent, cf, 0, 2.1, 0, 3.2, 2, 0.25, C.black, M.SmoothPlastic, NOCOL)
	local scr = rel(parent, cf, 0, 2.1, -0.14, 3, 1.8, 0.05, Color3.fromRGB(30, 60, 90), M.Neon, NOCOL)
	U.addGui(scr, Enum.NormalId.Front, text or "LOGIN", { fg = C.neonBlue, font = Enum.Font.GothamBold, pps = 30, textH = 0.4 })
	rel(parent, cf, 0, 0.08, -1.4, 2.6, 0.15, 0.9, C.darkSteel, M.SmoothPlastic, NOCOL)
	return mon
end

function P.boat(parent, cf, hull, stripe)
	local body = rel(parent, cf, 0, 0, 0, 7, 2.6, 16, hull or C.white, M.SmoothPlastic)
	U.wedge(parent, Vector3.new(7, 2.6, 5), cf * CFrame.new(0, 0, -10.5), hull or C.white, M.SmoothPlastic)
	rel(parent, cf, 0, 0.3, 0, 7.1, 0.5, 16.1, stripe or C.navy, M.SmoothPlastic, NOCOL)
	rel(parent, cf, 0, 1.35, 1, 6.2, 0.2, 13, C.woodLight, M.WoodPlanks)
	rel(parent, cf, 0, 2.6, 3, 4.6, 2.4, 4, C.white, M.SmoothPlastic)
	rel(parent, cf, 0, 3.3, 0.6, 4.4, 1.4, 0.2, C.glass, M.Glass, nc({ Transparency = 0.4 }))
	rel(parent, cf, 0, 1.9, 6.4, 6.5, 1, 2, C.coral, M.Fabric)
	rel(parent, cf, 0, 1.5, 8.4, 2, 2.5, 1.2, C.darkSteel, M.Metal)
	return body
end
P.NOCOL = NOCOL

-- potted plant (shared with Util so every area uses the same pot style)
P.plant = U.plant

return P
