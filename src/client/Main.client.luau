-- Main.client.luau: boots the "Everybody Has a Secret" client. Loads shared modules (with timeouts), starts the
-- State listener, builds every UI module (each in pcall so one failure never kills the rest), then sends Ready.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local here = script.Parent
local U = require(here:WaitForChild("Util"))
local State = require(here:WaitForChild("State"))

-- no combat damage in this game: hide the health bar so the top-right stays clear (Backpack stays on for tools)
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)
-- Roblox chat window defaults to the top-left, right on top of our level badge + MENU button: move it top-right
pcall(function()
	local cw = game:GetService("TextChatService"):FindFirstChildOfClass("ChatWindowConfiguration")
	if cw then
		cw.HorizontalAlignment = Enum.HorizontalAlignment.Right
		cw.VerticalAlignment = Enum.VerticalAlignment.Top
	end
end)

-- shared data modules first (Zones/Sfx/Items/ShopConfig/Config); each has its own timeout
U.preload({ "Zones", "Sfx", "Items", "ShopConfig", "Config" })

-- start listening before building UI so no early payload is lost
State.start()

local order = {
	"Hud",
	"Notify",
	"SecretCard",
	"Navigation",
	"Actions",
	"Investigate",
	"Security",
	"Social",
	"Shop",
	"Reveal",
	"Tutorial",
	"Fx",
	"Favorite",
	"Arcade",
}
-- PlayerScripts clone in one at a time: wait for every sibling module first, or a fast start can skip whole UI modules
for _, name in ipairs(order) do
	here:WaitForChild(name, 20)
end
for _, name in ipairs(order) do
	local mod = here:FindFirstChild(name)
	if mod then
		local ok, err = pcall(function()
			local m = require(mod :: ModuleScript)
			if type(m) == "table" and type(m.init) == "function" then
				m.init()
			end
		end)
		if not ok then
			warn("[EHAS client] " .. name .. " failed to init: " .. tostring(err))
		end
	else
		warn("[EHAS client] missing module " .. name)
	end
end

-- PC shortcuts: T = secret, J = journal, M = map (Tab is Roblox's player list)
do
	local ContextActionService = game:GetService("ContextActionService")
	local Hud = require(here:WaitForChild("Hud"))
	local keys = {
		[Enum.KeyCode.T] = "Secret",
		[Enum.KeyCode.J] = "Journal",
		[Enum.KeyCode.M] = "Map",
	}
	ContextActionService:BindAction("EHAS_Hotkeys", function(_, st, input)
		if st == Enum.UserInputState.Begin then
			local which = keys[input.KeyCode]
			local fn = which and Hud.open[which]
			if fn then
				fn()
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.T, Enum.KeyCode.J, Enum.KeyCode.M)
end

-- tell the server we're ready to receive round state / secret
U.fire("Ready", {})

local _ = ReplicatedStorage
