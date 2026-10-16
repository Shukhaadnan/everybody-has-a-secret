-- Main.server.luau — boot: Config overrides → remotes → MapBuilder.Build (MAP builder) → wait MapReady →
-- services (each init in pcall) → NPCs → round loop.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage:WaitForChild("Config"))

-- quick-test overrides: workspace attribute "Cfg_<Key>" (number/bool) overrides Config.<Key>
local applied = Config.applyOverrides(function(k)
	return workspace:GetAttribute("Cfg_" .. k)
end)
if #applied > 0 then
	print("[EHAS] Config overrides: " .. table.concat(applied, ", "))
end

local Core = require(script.Parent.Core)
Core.initRemotes()
Core.initActions()
-- clients that finish loading during the map build: answer Ready once Round exists (Round.init re-registers it)
Core.onAction("Ready", function(player)
	if Core.M.Round then
		Core.M.Round.sendAll(player)
	end
end)
workspace:SetAttribute("ServerReady", false)

---------------------------------------------------------------- map
task.spawn(function()
	-- DEV EDIT build: if the map was baked into the place in Studio (Resort has Baked=true), keep it
	-- as-is (so hand edits survive) and skip the code build.
	local baked = workspace:FindFirstChild("Resort")
	if baked and baked:GetAttribute("Baked") then
		workspace:SetAttribute("MapReady", true)
		print("[EHAS] using baked (hand-edited) map")
		return
	end
	local mapFolder = script.Parent:FindFirstChild("Map")
	local mb = mapFolder and mapFolder:FindFirstChild("MapBuilder")
	if mb then
		local ok, err = pcall(function()
			require(mb).Build()
		end)
		if not ok then
			warn("[EHAS] MapBuilder.Build failed: " .. tostring(err))
		end
	else
		warn("[EHAS] Map/MapBuilder not found — running without a built map")
	end
	-- MapBuilder sets MapReady itself; make sure we never wait forever
	if not workspace:GetAttribute("MapReady") and not workspace:FindFirstChild("Resort") then
		workspace:SetAttribute("MapReady", true)
	end
end)

local t0 = os.clock()
while not workspace:GetAttribute("MapReady") and os.clock() - t0 < 90 do
	task.wait(0.2)
end
if not workspace:GetAttribute("MapReady") then
	warn("[EHAS] MapReady never set (90 s) — starting anyway")
end
Core.indexZones()

---------------------------------------------------------------- services
local order = { "Data", "Progress", "Shop", "Evidence", "Interact", "Security", "Events", "Social", "Accuse", "Secrets", "Bots", "Round", "Analytics" }
for _, name in ipairs(order) do
	local ok, mod = pcall(require, script.Parent:FindFirstChild(name))
	if ok then
		Core.M[name] = mod
	else
		warn(("[EHAS] require %s failed: %s"):format(name, tostring(mod)))
	end
end
for _, name in ipairs(order) do
	local mod = Core.M[name]
	if mod and mod.init then
		local ok, err = pcall(mod.init)
		if not ok then
			warn(("[EHAS] %s.init failed: %s"):format(name, tostring(err)))
		end
	end
end

-- NPCs (staff witnesses, guards, bot guests)
local M = Core.M
if M.Evidence then
	local ok, err = pcall(M.Evidence.spawnStaff)
	if not ok then
		warn("[EHAS] staff spawn: " .. tostring(err))
	end
end
if M.Security then
	local ok, err = pcall(M.Security.spawnGuards)
	if not ok then
		warn("[EHAS] guard spawn: " .. tostring(err))
	end
end
if M.Bots then
	local ok, err = pcall(M.Bots.rebalance)
	if not ok then
		warn("[EHAS] bot spawn: " .. tostring(err))
	end
end

-- shared reference so SelfTest (separate Script) can reach every service
_G.EHAS = Core
workspace:SetAttribute("ServerReady", true)
print(("[EHAS] server ready — %d players, %d participants"):format(#Players:GetPlayers(), #Core.list(false)))

if M.Round then
	M.Round.run()
end
