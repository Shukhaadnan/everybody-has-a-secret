-- Favorite.luau: asks the player to favorite the game right after a big moment
-- (round rewards where they completed their MAIN secret, or levelled up), or after 10 minutes of play.
-- At most once per session, never in the first 60 s, and not if they already favorited it.
local Players = game:GetService("Players")
local AvatarEditorService = game:GetService("AvatarEditorService")

local State = require(script.Parent.State)

local Favorite = {}

local MIN_PLAY = 60
local TIMER = 10 * 60
local joinedAt = os.clock()
local asked = false

-- Pure: was this rewards payload a big moment? (unit-tested in SelfTest via the shared copy of this rule)
function Favorite.isBigMoment(p: any): boolean
	if type(p) ~= "table" then
		return false
	end
	if p.leveledUp == true then
		return true
	end
	for _, row in ipairs(type(p.breakdown) == "table" and p.breakdown or {}) do
		if type(row) == "table" and type(row.label) == "string" and row.label:sub(1, 11) == "Main secret" then
			return true
		end
	end
	return false
end

local function alreadyFavorited(): boolean
	local ok, res = pcall(function()
		return AvatarEditorService:GetFavorite(game.PlaceId, Enum.AvatarItemType.Asset)
	end)
	return ok and res == true
end

function Favorite.ask(reason: string)
	if asked or game.PlaceId == 0 then
		return
	end
	if os.clock() - joinedAt < MIN_PLAY then
		return
	end
	asked = true
	task.delay(2.5, function() -- let the reward screen land first
		if alreadyFavorited() then
			return
		end
		local ok, err = pcall(function()
			AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
		end)
		if not ok then
			warn("[EHAS client] favorite prompt failed: " .. tostring(err))
		end
		print("[EHAS client] asked to favorite (" .. reason .. ")")
	end)
end

function Favorite.init()
	local _ = Players
	State.sig("Rewards"):Connect(function(p)
		if Favorite.isBigMoment(p) then
			Favorite.ask("big moment")
		end
	end)
	task.delay(TIMER, Favorite.ask, "timer")
end

return Favorite
