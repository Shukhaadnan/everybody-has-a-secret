-- Anim.luau — server-side default R15 animations for NPCs (bots, guards, staff). pcall-safe,
-- cached tracks per Animator, one locomotion clip at a time with crossfade.
local Anim = {}

Anim.ids = {
	wave = 507770239,
	point = 507770453,
	cheer = 507770677,
	laugh = 507770818,
	dance1 = 507771019,
	dance2 = 507776043,
	dance3 = 507777268,
	toolSlash = 522635514,
	toolLunge = 522638767,
	toolnone = 507768375, -- R15 default 'hold a tool' arm pose
	idle = 507766388,
	walk = 913402848,
	run = 913376220,
	jump = 507765000,
	fall = 507767968,
}
Anim.LOCO = { idle = true, walk = true, run = true, jump = true, fall = true }
Anim.FADE = 0.2

local animObjects = {}
local trackCache = setmetatable({}, { __mode = "k" })
local locoState = setmetatable({}, { __mode = "k" })

local function getAnimator(target)
	if typeof(target) ~= "Instance" then
		return nil
	end
	if target:IsA("Animator") then
		return target
	end
	local hum = target:IsA("Humanoid") and target or target:FindFirstChildOfClass("Humanoid")
	if not hum then
		return nil
	end
	local a = hum:FindFirstChildOfClass("Animator")
	if not a then
		a = Instance.new("Animator")
		a.Parent = hum
	end
	return a
end
Anim.getAnimator = getAnimator

function Anim.getTrack(target, name)
	local id = Anim.ids[name]
	local animator = getAnimator(target)
	if not id or not animator then
		return nil
	end
	local cache = trackCache[animator]
	if not cache then
		cache = {}
		trackCache[animator] = cache
	end
	local t = cache[name]
	if not t then
		local a = animObjects[name]
		if not a then
			a = Instance.new("Animation")
			a.AnimationId = "rbxassetid://" .. id
			animObjects[name] = a
		end
		t = animator:LoadAnimation(a)
		if name == "toolnone" then
			t.Priority = Enum.AnimationPriority.Action
		elseif name == "idle" then
			t.Priority = Enum.AnimationPriority.Idle
		elseif Anim.LOCO[name] then
			t.Priority = Enum.AnimationPriority.Movement
		else
			t.Priority = Enum.AnimationPriority.Action
		end
		cache[name] = t
	end
	return t
end

function Anim.play(target, name, speed, looped)
	local ok, t = pcall(function()
		local t = Anim.getTrack(target, name)
		if not t then
			return nil
		end
		if looped ~= nil then
			t.Looped = looped
		end
		if t.IsPlaying then
			t:Stop(0.05)
		end
		t:Play(0.12, 1, speed or 1)
		return t
	end)
	return ok and t or nil
end

function Anim.stop(target, name)
	pcall(function()
		local t = Anim.getTrack(target, name)
		if t and t.IsPlaying then
			t:Stop(Anim.FADE)
		end
	end)
end

function Anim.setLoco(target, state, speed)
	pcall(function()
		local animator = getAnimator(target)
		if not animator then
			return
		end
		local cur = locoState[animator]
		if cur == state then
			local t = Anim.getTrack(animator, state)
			if t and speed and math.abs(t.Speed - speed) > 0.05 then
				t:AdjustSpeed(speed)
			end
			return
		end
		if cur then
			local old = Anim.getTrack(animator, cur)
			if old and old.IsPlaying then
				old:Stop(Anim.FADE)
			end
		end
		locoState[animator] = state
		local t = Anim.getTrack(animator, state)
		if t then
			t.Looped = state ~= "jump"
			t:Play(Anim.FADE, 1, speed or 1)
		end
	end)
end

-- drive locomotion from the root's velocity (call every ~0.2 s)
function Anim.autoLoco(model)
	local root = model and model:FindFirstChild("HumanoidRootPart")
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		return
	end
	local v = root.AssemblyLinearVelocity
	local h = Vector3.new(v.X, 0, v.Z).Magnitude
	local st = hum:GetState()
	if st == Enum.HumanoidStateType.Freefall then
		Anim.setLoco(hum, "fall", 1)
	elseif st == Enum.HumanoidStateType.Jumping then
		Anim.setLoco(hum, "jump", 1)
	elseif h < 0.75 then
		Anim.setLoco(hum, "idle", 1)
	elseif h < 17 then
		Anim.setLoco(hum, "walk", math.clamp(h / 14.5, 0.5, 1.4))
	else
		Anim.setLoco(hum, "run", math.clamp(h / 18, 0.8, 1.6))
	end
end

return Anim
