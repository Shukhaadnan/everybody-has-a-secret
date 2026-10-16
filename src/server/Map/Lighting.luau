--!nocheck
-- Lighting: bright tropical afternoon. Called once by MapBuilder.Build().
local Lighting = game:GetService("Lighting")

local L = {}

local function get(className, name)
	local inst = Lighting:FindFirstChild(name)
	if not inst or not inst:IsA(className) then
		if inst then
			inst:Destroy()
		end
		inst = Instance.new(className)
		inst.Name = name
		inst.Parent = Lighting
	end
	return inst
end

function L.apply()
	-- v2 (Oct 8, sir: "make the brightness and shaders better to look more appealing"):
	-- warm late-afternoon sun with long soft shadows, clearer air (less grey haze), richer colour, glossy
	-- marble/glass reflections, soft bloom on lamps/neon, visible sun rays and a deep blue sky.
	Lighting.ClockTime = 16.2
	Lighting.GeographicLatitude = 24
	Lighting.Brightness = 3.2
	Lighting.Ambient = Color3.fromRGB(96, 92, 98)
	Lighting.OutdoorAmbient = Color3.fromRGB(138, 136, 150)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 226, 190)
	Lighting.ColorShift_Bottom = Color3.fromRGB(70, 90, 130)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ExposureCompensation = 0.15
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.18
	Lighting.FogEnd = 100000
	pcall(function()
		Lighting.Technology = Enum.Technology.Future
	end)

	local sky = get("Sky", "ResortSky")
	sky.SunAngularSize = 16
	sky.MoonAngularSize = 8
	sky.StarCount = 1000
	sky.CelestialBodiesShown = true

	local atm = get("Atmosphere", "ResortAtmosphere")
	atm.Density = 0.22
	atm.Offset = 0.12
	atm.Color = Color3.fromRGB(199, 222, 245)
	atm.Decay = Color3.fromRGB(92, 140, 205)
	atm.Glare = 0.35
	atm.Haze = 0.6

	local bloom = get("BloomEffect", "ResortBloom")
	bloom.Intensity = 0.55
	bloom.Size = 28
	bloom.Threshold = 1.35

	local cc = get("ColorCorrectionEffect", "ResortColor")
	cc.Brightness = 0.02
	cc.Contrast = 0.16
	cc.Saturation = 0.22
	cc.TintColor = Color3.fromRGB(255, 244, 230)

	local rays = get("SunRaysEffect", "ResortSunRays")
	rays.Intensity = 0.1
	rays.Spread = 0.75

	local dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if dof then
		dof.Enabled = false
	end

	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if not clouds then
		clouds = Instance.new("Clouds")
		clouds.Parent = workspace.Terrain
	end
	clouds.Cover = 0.5
	clouds.Density = 0.7
	clouds.Color = Color3.fromRGB(255, 250, 245)
end

return L
