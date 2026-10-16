-- Fx.luau: client-side world FX and audio.
--   * Power outage (workspace attribute "PowerOut"): local darkness via ColorCorrection + exposure, flashlight
--     SpotLights on any character holding a Tool with ItemId "Flashlight".
--   * Storm (workspace attribute "Storm"): rain ParticleEmitter that follows the camera, gray tint, thunder flashes.
--   * Zone ambience crossfade: workspace.Resort.Ambience.<ZoneId> sounds if the map provides them,
--     otherwise local Sfx Ambient_* loops picked per zone.
--   * Round music per phase (Music_Lobby / Music_Reveal), Sfx remote (positional when pos is given).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local U = require(script.Parent.Util)
local State = require(script.Parent.State)
local Nav = require(script.Parent.Navigation)

local Fx = {}

local function tw(obj: Instance, t: number, props: any)
	local x = TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), props)
	x:Play()
	return x
end

-------------------------------------------------------------------------------- outage
local outCC: ColorCorrectionEffect
local baseExposure = Lighting.ExposureCompensation
local outageOn = false

local function setOutage(on: boolean)
	if on == outageOn then
		return
	end
	outageOn = on
	if on then
		baseExposure = Lighting.ExposureCompensation
		tw(outCC, 1.2, { Brightness = -0.28, Contrast = 0.15, Saturation = -0.45, TintColor = Color3.fromRGB(150, 170, 230) })
		tw(Lighting, 1.2, { ExposureCompensation = baseExposure - 1.4 })
		U.sfx("Thunder", nil, 0.4)
	else
		tw(outCC, 1.5, { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) })
		tw(Lighting, 1.5, { ExposureCompensation = baseExposure })
	end
end

local function updateFlashlights()
	local chars = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(chars, p.Character)
		end
	end
	local bots = U.botsFolder()
	if bots then
		for _, m in ipairs(bots:GetChildren()) do
			if m:IsA("Model") then
				table.insert(chars, m)
			end
		end
	end
	for _, ch in ipairs(chars) do
		for _, t in ipairs(ch:GetChildren()) do
			if t:IsA("Tool") and t:GetAttribute("ItemId") == "Flashlight" then
				local h = t:FindFirstChild("Handle")
				if h and h:IsA("BasePart") then
					local l = h:FindFirstChild("EHAS_Flash") :: SpotLight?
					if not l then
						local sl = Instance.new("SpotLight")
						sl.Name = "EHAS_Flash"
						sl.Face = Enum.NormalId.Front
						sl.Angle = 50
						sl.Range = 55
						sl.Color = Color3.fromRGB(255, 244, 214)
						sl.Shadows = (ch == U.player.Character) -- only your own light casts shadows (phone GPU)
						sl.Parent = h
						l = sl
					end
					local light = l :: SpotLight
					light.Brightness = outageOn and 6 or 2
					light.Enabled = true
					-- aim along the character's look direction
					local root = ch:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root then
						local look = h.CFrame:VectorToObjectSpace(root.CFrame.LookVector)
						local ax, ay, az = math.abs(look.X), math.abs(look.Y), math.abs(look.Z)
						if az >= ax and az >= ay then
							light.Face = look.Z < 0 and Enum.NormalId.Front or Enum.NormalId.Back
						elseif ax >= ay then
							light.Face = look.X > 0 and Enum.NormalId.Right or Enum.NormalId.Left
						else
							light.Face = look.Y > 0 and Enum.NormalId.Top or Enum.NormalId.Bottom
						end
					end
				end
			end
		end
	end
end

-------------------------------------------------------------------------------- storm
local stormCC: ColorCorrectionEffect
local rainPart: Part? = nil
local stormOn = false
local stormGen = 0 -- each storm start owns one thunder loop (off->on within one wait must not double it)
local stormConn: RBXScriptConnection? = nil
local rainSound: Sound? = nil

local function makeRain(): Part
	local p = Instance.new("Part")
	p.Name = "EHAS_Rain"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(110, 1, 110)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Rain"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(200, 220, 255))
	e.LightEmission = 0.2
	e.Transparency = NumberSequence.new(0.35)
	e.Size = NumberSequence.new(0.12)
	e.Squash = NumberSequence.new(3.5)
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Speed = NumberRange.new(90, 110)
	e.Acceleration = Vector3.new(0, -40, 0)
	e.Lifetime = NumberRange.new(0.7, 0.9)
	e.Rate = 700
	e.SpreadAngle = Vector2.new(4, 4)
	e.Parent = p
	local s = Instance.new("ParticleEmitter")
	s.Name = "Mist"
	s.Texture = "rbxasset://textures/particles/smoke_main.dds"
	s.Color = ColorSequence.new(Color3.fromRGB(170, 180, 200))
	s.Transparency = NumberSequence.new(0.9)
	s.Size = NumberSequence.new(14)
	s.EmissionDirection = Enum.NormalId.Bottom
	s.Speed = NumberRange.new(10, 20)
	s.Lifetime = NumberRange.new(2, 3)
	s.Rate = 6
	s.Parent = p
	return p
end

local function setStorm(on: boolean)
	if on == stormOn then
		return
	end
	stormOn = on
	if on then
		tw(stormCC, 2, { Brightness = -0.08, Saturation = -0.35, TintColor = Color3.fromRGB(190, 200, 215) })
		if not rainPart then
			rainPart = makeRain()
		end
		local rp = rainPart :: Part
		rp.Parent = workspace.CurrentCamera
		stormConn = RunService.RenderStepped:Connect(function()
			local cam = workspace.CurrentCamera
			if cam then
				local pos = cam.CFrame.Position
				-- indoors? (roof above the camera) -> thin the rain
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				local ignore: { Instance } = { cam }
				if U.player.Character then
					table.insert(ignore, U.player.Character)
				end
				params.FilterDescendantsInstances = ignore
				rp.CFrame = CFrame.new(pos + Vector3.new(0, 26, 0))
				local e = rp:FindFirstChild("Rain") :: ParticleEmitter
				local roof = workspace:Raycast(pos, Vector3.new(0, 60, 0), params)
				e.Rate = roof and 0 or 700
			end
		end)
		local t = U.soundTemplate("Ambient_Beach")
		if t and not rainSound then
			local s = t:Clone()
			s.Name = "EHAS_RainLoop"
			s.Looped = true
			s.Volume = 0
			s.PlaybackSpeed = 0.8
			s.Parent = SoundService
			s:Play()
			tw(s, 2, { Volume = t.Volume * 0.8 })
			rainSound = s
		end
		stormGen += 1
		local gen = stormGen
		task.spawn(function()
			while stormOn and stormGen == gen do
				task.wait(math.random(8, 18))
				if not stormOn or stormGen ~= gen then
					break
				end
				U.sfx("Thunder", nil, 0.8)
				stormCC.Brightness = 0.45
				tw(stormCC, 0.6, { Brightness = -0.08 })
			end
		end)
	else
		tw(stormCC, 2, { Brightness = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) })
		if stormConn then
			stormConn:Disconnect()
			stormConn = nil
		end
		if rainPart then
			rainPart.Parent = nil
		end
		if rainSound then
			local s = rainSound
			rainSound = nil
			tw(s, 2, { Volume = 0 }).Completed:Connect(function()
				s:Destroy()
			end)
		end
	end
end

-------------------------------------------------------------------------------- ambience
local AMBIENT_FOR = {
	Casino = "Ambient_Hotel", -- arcade (the old casino ambience had slot machine sounds)
	CasinoVIP = "Ambient_Hotel",
	CasinoBackRoom = "Ambient_Hotel",
	Beach = "Ambient_Beach",
	Dock = "Ambient_Beach",
	BeachShop = "Ambient_Beach",
	Underground = "Ambient_Underground",
	ElectricalRoom = "Ambient_Underground",
	HiddenRoom = "Ambient_Underground",
	SecurityRoom = "Ambient_Security",
	Detention = "Ambient_Security",
	Pool = "Ambient_Pool",
	ChangingRooms = "Ambient_Pool",
	PoolBar = "Ambient_Pool",
}
local localLoops: { [string]: Sound } = {}
local currentAmb: string? = nil
local mapAmbBase: { [Sound]: number } = {}

local function ambienceFolder(): Instance?
	local r = workspace:FindFirstChild("Resort")
	return r and r:FindFirstChild("Ambience") or nil
end

local function soundsIn(inst: Instance?): { Sound }
	local out = {}
	if not inst then
		return out
	end
	if inst:IsA("Sound") then
		table.insert(out, inst)
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("Sound") then
			table.insert(out, d)
		end
	end
	return out
end

local function crossfadeMap(folder: Instance, zone: string?)
	for _, child in ipairs(folder:GetChildren()) do
		local on = child.Name == zone
		for _, s in ipairs(soundsIn(child)) do
			if mapAmbBase[s] == nil then
				mapAmbBase[s] = s.Volume
			end
			if on then
				s.Looped = true
				if not s.IsPlaying then
					s:Play()
				end
			end
			tw(s, 2, { Volume = on and mapAmbBase[s] or 0 })
		end
	end
end

local function crossfadeLocal(name: string?)
	if name == currentAmb then
		return
	end
	currentAmb = name
	for n, s in pairs(localLoops) do
		if n ~= name then
			tw(s, 2, { Volume = 0 })
		end
	end
	if not name then
		return
	end
	local s = localLoops[name]
	if not s then
		local t = U.soundTemplate(name)
		if not t then
			return
		end
		local snd = t:Clone()
		snd.Name = "EHAS_Amb_" .. name
		snd.Looped = true
		snd.Volume = 0
		snd.Parent = SoundService
		snd:Play()
		localLoops[name] = snd
		s = snd
	end
	local tmpl = U.soundTemplate(name)
	local target = (tmpl and tmpl.Volume or 0.4) * 0.7
	if not s.IsPlaying then
		s:Play()
	end
	tw(s, 2, { Volume = target })
end

local function onZone(zone: string?)
	local folder = ambienceFolder()
	local hasMapSound = false
	if folder and zone then
		local z = folder:FindFirstChild(zone)
		hasMapSound = #soundsIn(z) > 0
	end
	if folder then
		crossfadeMap(folder, hasMapSound and zone or nil)
	end
	if hasMapSound then
		crossfadeLocal(nil)
	else
		crossfadeLocal(zone and (AMBIENT_FOR[zone] or "Ambient_Hotel") or "Ambient_Hotel")
	end
end

-------------------------------------------------------------------------------- music
local music: Sound? = nil
local musicName: string? = nil
local function playMusic(name: string?)
	if name == musicName then
		return
	end
	musicName = name
	if music then
		local m = music
		music = nil
		tw(m, 1.5, { Volume = 0 }).Completed:Connect(function()
			m:Destroy()
		end)
	end
	if not name then
		return
	end
	local t = U.soundTemplate(name)
	if not t then
		return
	end
	local s = t:Clone()
	s.Name = "EHAS_Music"
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	s:Play()
	tw(s, 1.5, { Volume = t.Volume * 0.6 })
	music = s
end

local function musicFor(phase: string)
	if phase == "Lobby" then
		playMusic("Music_Lobby")
	elseif phase == "Reveal" or phase == "Rewards" then
		playMusic("Music_Reveal")
	else
		playMusic(nil)
	end
end

-------------------------------------------------------------------------------- init
function Fx.init()
	outCC = Instance.new("ColorCorrectionEffect")
	outCC.Name = "EHAS_Outage"
	outCC.Parent = Lighting
	stormCC = Instance.new("ColorCorrectionEffect")
	stormCC.Name = "EHAS_Storm"
	stormCC.Parent = Lighting

	local function readAttrs()
		setOutage(workspace:GetAttribute("PowerOut") == true)
		setStorm(workspace:GetAttribute("Storm") == true)
	end
	workspace:GetAttributeChangedSignal("PowerOut"):Connect(readAttrs)
	workspace:GetAttributeChangedSignal("Storm"):Connect(readAttrs)
	readAttrs()

	task.spawn(function()
		while true do
			pcall(updateFlashlights)
			task.wait(0.25)
		end
	end)

	Nav.zoneChanged:Connect(function(z)
		onZone(z)
	end)
	task.delay(3, function()
		if currentAmb == nil then
			onZone(State.zone)
		end
	end)

	State.sig("Phase"):Connect(musicFor)
	musicFor(State.round.phase)

	State.sig("Sfx"):Connect(function(p)
		if type(p.name) == "string" then
			U.sfx(p.name, typeof(p.pos) == "Vector3" and p.pos or nil)
		end
	end)
	State.sig("EventBanner"):Connect(function(p)
		if p.id == "Jackpot" or string.find(string.lower(tostring(p.id or "")), "jackpot", 1, true) then
			U.sfx("Jackpot")
		end
	end)
end

return Fx
