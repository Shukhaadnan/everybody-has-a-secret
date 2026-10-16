-- Navigation.luau: client-side zone detection (which workspace.Resort.Zones part holds your HumanoidRootPart),
-- zone-entry banner ("🎰 CASINO"), minimap (bottom-right above the jump button; tappable -> big map with names),
-- and the objective guide toward Zones.byId[hintZone].center: a 3D neon arrow over your head, a beacon at the
-- target and an edge-of-screen pointer with distance.
local RunService = game:GetService("RunService")

local U = require(script.Parent.Util)
local State = require(script.Parent.State)
local Hud = require(script.Parent.Hud)

local Nav = {}
Nav.zoneChanged = U.signal()

local gui: ScreenGui
local mini: Frame
local miniMap: Frame
local miniArrow: TextLabel
local miniZone: TextLabel
local miniDots: { [string]: Frame } = {}
local objDotMini: TextLabel
local bigBack: TextButton
local bigPanel: Frame
local bigMap: Frame
local bigArrow: TextLabel
local bigObj: TextLabel
local bigOpen = false
local banner: TextLabel
local pointer: Frame
local pointerArrow: TextLabel
local pointerDist: TextLabel

local bounds = { minX = -300, maxX = 300, minZ = -300, maxZ = 300 }
local rightReserve = 0 -- real px reserved by the action-button column

-------------------------------------------------------------------------------- zones
local zoneParts: { BasePart } = {}
local lastScan = 0
local function scanZones()
	lastScan = os.clock()
	local resort = workspace:FindFirstChild("Resort")
	local z = resort and resort:FindFirstChild("Zones")
	local list = {}
	if z then
		for _, d in ipairs(z:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(list, d)
			end
		end
	end
	-- smaller boxes win when zones overlap (e.g. HiddenRoom inside Underground)
	table.sort(list, function(a, b)
		return a.Size.X * a.Size.Y * a.Size.Z < b.Size.X * b.Size.Y * b.Size.Z
	end)
	zoneParts = list
end

local function zoneAt(pos: Vector3): string?
	for _, p in ipairs(zoneParts) do
		if p.Parent then
			local lp = p.CFrame:PointToObjectSpace(pos)
			local h = p.Size / 2
			if math.abs(lp.X) <= h.X and math.abs(lp.Y) <= h.Y + 2 and math.abs(lp.Z) <= h.Z then
				local id = p:GetAttribute("ZoneId")
				return type(id) == "string" and id or p.Name
			end
		end
	end
	return nil
end
Nav.zoneAt = zoneAt

local function displayFor(id: string): string
	local z = U.zone(id)
	local icon = z and z.icon or "📍"
	local name = z and z.name or nil
	if not name then
		for _, p in ipairs(zoneParts) do
			if (p:GetAttribute("ZoneId") or p.Name) == id then
				name = p:GetAttribute("DisplayName")
				break
			end
		end
	end
	return string.format("%s %s", icon, string.upper(tostring(name or id)))
end

local function showBanner(id: string)
	local z = U.zone(id)
	banner.Text = displayFor(id) .. ((z and z.restricted) and "  🔒" or "")
	banner.TextColor3 = (z and z.restricted) and U.C.bad or U.C.white
	banner.Visible = true
	banner.TextTransparency = 1
	banner.Position = UDim2.new(0.5, 0, 0.26, 20)
	U.tween(banner, 0.35, { TextTransparency = 0, Position = UDim2.fromScale(0.5, 0.26) }, Enum.EasingStyle.Back)
	local my = banner:GetAttribute("Gen") or 0
	my += 1
	banner:SetAttribute("Gen", my)
	task.delay(2.4, function()
		if banner:GetAttribute("Gen") == my then
			U.tween(banner, 0.5, { TextTransparency = 1 })
		end
	end)
end

-------------------------------------------------------------------------------- map math
local function computeBounds()
	local Z = U.mod("Zones")
	if not (Z and type(Z.list) == "table" and #Z.list > 0) then
		return
	end
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, z in ipairs(Z.list) do
		if typeof(z.center) == "Vector3" then
			minX = math.min(minX, z.center.X)
			maxX = math.max(maxX, z.center.X)
			minZ = math.min(minZ, z.center.Z)
			maxZ = math.max(maxZ, z.center.Z)
		end
	end
	if minX == math.huge then
		return
	end
	-- square bounds with padding so dots aren't on the edge
	local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
	local half = math.max(maxX - minX, maxZ - minZ) / 2 + 60
	bounds = { minX = cx - half, maxX = cx + half, minZ = cz - half, maxZ = cz + half }
end

local function toMap(pos: Vector3): Vector2
	local u = (pos.X - bounds.minX) / (bounds.maxX - bounds.minX)
	local v = (pos.Z - bounds.minZ) / (bounds.maxZ - bounds.minZ)
	return Vector2.new(math.clamp(u, 0.02, 0.98), math.clamp(v, 0.02, 0.98))
end

local function drawZones(holder: Frame, big: boolean)
	local Z = U.mod("Zones")
	if not (Z and type(Z.list) == "table") then
		return
	end
	for _, z in ipairs(Z.list) do
		if typeof(z.center) == "Vector3" and z.id ~= "Detention" then
			local m = toMap(z.center)
			local size = big and 56 or 30
			local dot = U.label(holder, tostring(z.icon or "•"), big and 34 or 18, {
				Name = z.id,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(m.X, m.Y),
				Size = UDim2.fromOffset(size, size),
				BackgroundTransparency = 0.15,
				BackgroundColor3 = z.restricted and Color3.fromRGB(120, 30, 40) or (z.outdoor and Color3.fromRGB(30, 110, 130) or Color3.fromRGB(70, 60, 130)),
				TextWrapped = false,
				ZIndex = 3,
			})
			U.round(dot)
			U.stroke(dot, z.restricted and U.C.bad or U.C.white, big and 2 or 1.5, 0.2)
			if big then
				local nm = U.label(holder, U.esc(z.name or z.id), 16, {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(m.X, 0, m.Y, 30),
					Size = UDim2.fromOffset(140, 20),
					Font = U.BOLD,
					ZIndex = 4,
				})
				U.textStroke(nm, 2)
				local btn = U.new("TextButton", {
					Text = "",
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = dot.Position,
					Size = UDim2.fromOffset(70, 70),
					ZIndex = 5,
					Parent = holder,
				})
				btn.Activated:Connect(function()
					U.sfx("Click", nil, 0.5)
					U.pulse(dot, 0.4)
					local desc = (z.restricted and "🔒 Restricted area — staff only!" or (z.outdoor and "☀️ Outdoors" or "🏨 Indoors"))
					State.emit("Toast", { text = string.format("%s %s · %s", tostring(z.icon or ""), tostring(z.name or z.id), desc), kind = "info" })
				end)
			else
				miniDots[z.id] = dot
			end
		end
	end
end

-------------------------------------------------------------------------------- objective guide (3D)
local arrowModel: Model? = nil
local beacon: BasePart? = nil
local function buildArrow(): Model
	local m = Instance.new("Model")
	m.Name = "EHAS_ObjectiveArrow"
	local col = U.C.gold
	local function part(cls: string, size: Vector3): BasePart
		local p = Instance.new(cls) :: BasePart
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = col
		p.Size = size
		p.Parent = m
		return p
	end
	local shaft = part("Part", Vector3.new(0.5, 0.25, 1.6))
	shaft.Name = "Shaft"
	local w1 = part("WedgePart", Vector3.new(0.25, 0.7, 1.1))
	w1.Name = "HeadL"
	local w2 = part("WedgePart", Vector3.new(0.25, 0.7, 1.1))
	w2.Name = "HeadR"
	m.PrimaryPart = shaft
	m.Parent = workspace.CurrentCamera
	return m
end

local function placeArrow(m: Model, base: CFrame)
	-- base: CFrame at the arrow's center looking toward the target (flat)
	local shaft = m:FindFirstChild("Shaft") :: BasePart
	local l = m:FindFirstChild("HeadL") :: BasePart
	local r = m:FindFirstChild("HeadR") :: BasePart
	shaft.CFrame = base * CFrame.new(0, 0, 0.3)
	-- two wedges lying flat, forming a triangle that points along -Z (look direction)
	-- WedgePart local Y (the tapering side) is rotated onto -X / +X so both tips meet at the center line
	l.CFrame = base * CFrame.new(-0.35, 0, -1.0) * CFrame.Angles(0, 0, math.rad(90))
	r.CFrame = base * CFrame.new(0.35, 0, -1.0) * CFrame.Angles(0, 0, math.rad(-90))
end

local function buildBeacon(): BasePart
	local p = Instance.new("Part")
	p.Name = "EHAS_Beacon"
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = U.C.gold
	p.Transparency = 0.65
	p.Size = Vector3.new(120, 3, 3)
	p.Parent = workspace.CurrentCamera
	return p
end

-------------------------------------------------------------------------------- big map
local function closeBig()
	if not bigOpen then
		return
	end
	bigOpen = false
	U.closedModal("Map")
	U.hideWindow(bigBack, bigPanel)
end

function Nav.openBig()
	if bigOpen then
		closeBig()
		return
	end
	U.openModal("Map", function()
		bigOpen = false
		bigBack.Visible = false
	end)
	bigOpen = true
	U.showWindow(bigBack, bigPanel)
end

-------------------------------------------------------------------------------- layout
function Nav.setRightReserve(px: number)
	rightReserve = px
	Nav.layout()
end

function Nav.layout()
	if not mini then
		return
	end
	local k = math.max(U.scale, 0.01)
	local jumpTop = U.jumpArea()
	local real: number
	local bottom: number
	local right: number
	if U.isTouch() then
		local vp = U.viewport()
		real = math.clamp(math.min(vp.X, vp.Y) * 0.3, 110, 230)
		bottom = jumpTop + 18
		right = 12 + rightReserve
		-- if the action column is empty, sit straight above the jump button
	else
		real = math.clamp(260 * k, 150, 260)
		bottom = 20
		right = 20 + rightReserve
	end
	local s = real / k
	mini.Size = UDim2.fromOffset(s, s + 30)
	mini.Position = UDim2.new(1, -right / k, 1, -bottom / k)
end

-------------------------------------------------------------------------------- init
function Nav.init()
	gui = U.screen("EHAS_Nav", 4)
	scanZones()
	computeBounds()

	-- zone banner
	banner = U.label(gui, "", 52, {
		Name = "ZoneBanner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.26),
		Size = UDim2.fromOffset(800, 70),
		Visible = false,
		TextWrapped = false,
	})
	U.textStroke(banner, 3)

	-- minimap
	mini = U.new("TextButton", {
		Name = "Minimap",
		Text = "",
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(1, 1),
		BackgroundColor3 = U.C.bg,
		BackgroundTransparency = 0.15,
		Size = UDim2.fromOffset(220, 250),
		Parent = gui,
	})
	U.corner(mini, 18)
	U.stroke(mini, U.C.gold, 3)
	miniZone = U.label(mini, "📍 ...", 18, {
		Position = UDim2.fromOffset(0, 2),
		Size = UDim2.new(1, 0, 0, 26),
		Font = U.BOLD,
		TextScaled = true,
		TextWrapped = false,
	})
	U.new("UITextSizeConstraint", { MaxTextSize = 20, Parent = miniZone })
	miniMap = U.frame(mini, {
		Name = "Map",
		Position = UDim2.fromOffset(8, 30),
		Size = UDim2.new(1, -16, 1, -38),
		BackgroundColor3 = Color3.fromRGB(70, 160, 200),
		ClipsDescendants = true,
	})
	U.corner(miniMap, 12)
	U.gradient(miniMap, Color3.fromRGB(110, 200, 120), Color3.fromRGB(60, 150, 210), 90)
	drawZones(miniMap, false)
	objDotMini = U.label(miniMap, "⭐", 22, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(28, 28),
		Visible = false,
		ZIndex = 6,
		TextWrapped = false,
	})
	miniArrow = U.label(miniMap, "▲", 24, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(28, 28),
		TextColor3 = U.C.gold,
		ZIndex = 7,
		TextWrapped = false,
	})
	U.textStroke(miniArrow, 2)
	U.label(mini, "🗺️", 22, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -4, 1, -2),
		Size = UDim2.fromOffset(30, 30),
		ZIndex = 8,
		TextWrapped = false,
	})
	mini.Activated:Connect(function()
		U.sfx("Click", nil, 0.6)
		Nav.openBig()
	end)

	-- big map window
	local b, p, c, body = U.window(gui, "🗺️ RESORT MAP", 880, 900, Color3.fromRGB(60, 170, 110))
	bigBack, bigPanel = b, p
	bigBack.Activated:Connect(closeBig)
	c.Activated:Connect(closeBig)
	bigMap = U.frame(body, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(70, 160, 200),
	})
	U.new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = bigMap })
	U.corner(bigMap, 16)
	U.gradient(bigMap, Color3.fromRGB(120, 210, 130), Color3.fromRGB(50, 140, 210), 90)
	drawZones(bigMap, true)
	bigObj = U.label(bigMap, "⭐", 40, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(48, 48), Visible = false, ZIndex = 8, TextWrapped = false })
	bigArrow = U.label(bigMap, "▲", 40, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(44, 44),
		TextColor3 = U.C.gold,
		ZIndex = 9,
		TextWrapped = false,
	})
	U.textStroke(bigArrow, 3)
	Hud.open.Map = Nav.openBig

	-- edge pointer
	pointer = U.frame(gui, {
		Name = "ObjPointer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(90, 90),
		BackgroundTransparency = 1,
		Visible = false,
	})
	pointerArrow = U.label(pointer, "➤", 54, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(60, 60),
		TextColor3 = U.C.gold,
		TextWrapped = false,
	})
	U.textStroke(pointerArrow, 3)
	pointerDist = U.label(pointer, "", 20, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.75, 0),
		Size = UDim2.fromOffset(140, 26),
		Font = U.BOLD,
		TextWrapped = false,
	})
	U.textStroke(pointerDist, 2)

	U.scaleChanged:Connect(Nav.layout)
	Nav.layout()

	-- zone tracking loop
	task.spawn(function()
		while true do
			if os.clock() - lastScan > 5 or #zoneParts == 0 then
				scanZones()
				if bounds.minX == -300 then
					computeBounds()
				end
			end
			local hrp = U.hrp()
			if hrp then
				local z = zoneAt(hrp.Position)
				if z ~= State.zone then
					local prev = State.zone
					State.zone = z
					if z then
						miniZone.Text = displayFor(z)
						if prev ~= nil or State.round.phase ~= "Lobby" then
							showBanner(z)
						end
					else
						miniZone.Text = "📍 Resort"
					end
					Nav.zoneChanged:Fire(z, prev)
					State.emit("Zone", z, prev)
				end
			end
			task.wait(0.3)
		end
	end)

	-- per-frame: minimap arrow, objective guide
	RunService.RenderStepped:Connect(function()
		local hrp = U.hrp()
		local cam = workspace.CurrentCamera
		if not (hrp and cam) then
			return
		end
		local m = toMap(hrp.Position)
		local look = hrp.CFrame.LookVector
		local rot = math.deg(math.atan2(look.X, -look.Z))
		miniArrow.Position = UDim2.fromScale(m.X, m.Y)
		miniArrow.Rotation = rot
		if bigOpen then
			bigArrow.Position = UDim2.fromScale(m.X, m.Y)
			bigArrow.Rotation = rot
		end

		local obj = State.activeObjective()
		local zone = obj and obj.hintZone and U.zone(obj.hintZone) or nil
		local phase = State.round.phase
		local active = zone ~= nil and typeof(zone.center) == "Vector3" and (phase == "Play" or phase == "Intro" or (State.secret and State.secret.tutorial and phase ~= "Reveal" and phase ~= "Rewards"))
			and not State.isDetained()
		if not active then
			pointer.Visible = false
			objDotMini.Visible = false
			bigObj.Visible = false
			if arrowModel then
				arrowModel.Parent = nil
			end
			if beacon then
				beacon.Parent = nil
			end
			return
		end
		local target = zone.center :: Vector3
		local here = State.zone == obj.hintZone
		local tm = toMap(target)
		objDotMini.Position = UDim2.fromScale(tm.X, tm.Y)
		objDotMini.Visible = true
		bigObj.Position = UDim2.fromScale(tm.X, tm.Y)
		bigObj.Visible = true
		local col = U.tierColor(obj.tier)

		-- 3D arrow above the head
		if not arrowModel then
			arrowModel = buildArrow()
		end
		if not beacon then
			beacon = buildBeacon()
		end
		local am = arrowModel :: Model
		local bc = beacon :: BasePart
		am.Parent = cam
		bc.Parent = cam
		for _, part in ipairs(am:GetChildren()) do
			if part:IsA("BasePart") then
				part.Color = col
				part.Transparency = here and 1 or 0.15
			end
		end
		local flat = Vector3.new(target.X - hrp.Position.X, 0, target.Z - hrp.Position.Z)
		local dist = flat.Magnitude
		if dist > 1 then
			local bob = math.sin(os.clock() * 3) * 0.25
			local origin = hrp.Position + Vector3.new(0, 4.4 + bob, 0) + flat.Unit * 1.2
			placeArrow(am, CFrame.lookAt(origin, origin + flat.Unit))
		end
		bc.Color = col
		bc.Transparency = here and 0.85 or (0.55 + math.sin(os.clock() * 2) * 0.1)
		bc.CFrame = CFrame.new(target + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.rad(90))

		-- screen pointer
		local k = math.max(U.scale, 0.01)
		local vp = cam.ViewportSize
		local sp, onScreen = cam:WorldToViewportPoint(target + Vector3.new(0, 6, 0))
		local inset = U.guiInset()
		local margin = 70
		pointerDist.Text = here and "📍 YOU'RE HERE" or string.format("%s %dm", tostring(zone.icon or "📍"), math.floor(dist))
		pointerDist.TextColor3 = col
		pointerArrow.TextColor3 = col
		pointer.Visible = not here or onScreen
		if onScreen and sp.Z > 0 and sp.X > margin and sp.X < vp.X - margin and sp.Y > margin and sp.Y < vp.Y - margin then
			pointerArrow.Text = "⬇"
			pointerArrow.Rotation = 0
			pointer.Position = UDim2.fromOffset(sp.X / k, (sp.Y - inset.Y) / k)
		else
			local center = vp / 2
			local d = Vector2.new(sp.X, sp.Y) - center
			if sp.Z < 0 then
				d = -d
			end
			if d.Magnitude < 1 then
				d = Vector2.new(0, -1)
			end
			local hx, hy = center.X - margin, center.Y - margin * 1.6
			local s = math.min(hx / math.max(math.abs(d.X), 1e-3), hy / math.max(math.abs(d.Y), 1e-3))
			local pos = center + d * s
			-- "➤" (U+27A4) doesn't render in the game font (only the distance text showed) -> use "⬆" rotated
			pointerArrow.Text = "⬆"
			pointerArrow.Rotation = math.deg(math.atan2(d.Y, d.X)) + 90
			pointer.Position = UDim2.fromOffset(pos.X / k, (pos.Y - inset.Y) / k)
		end
	end)

	State.sig("Phase"):Connect(function(phase)
		if phase == "Reveal" then
			closeBig()
		end
	end)
end

function Nav.mini(): Frame
	return mini
end

return Nav
