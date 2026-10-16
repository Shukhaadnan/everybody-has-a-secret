--!nocheck
-- Analytics.luau: Creator Hub analytics (Analytics → Funnels / Economy / Custom).
-- Onboarding funnel (where NEW players quit), a per-round funnel, coin sources/sinks and key moments.
-- Everything is pcall'd: a throttled or failing AnalyticsService call can never break gameplay.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Bus = require(script.Parent.Bus)
local Core = require(script.Parent.Core)

local AS = nil
pcall(function()
	AS = game:GetService("AnalyticsService")
end)

local Analytics = {}
Analytics.log = {} -- last calls (SelfTest / debugging)
local LOG_MAX = 60

local function realPlayer(x)
	if typeof(x) == "Instance" and x:IsA("Player") then
		return x
	end
	if type(x) == "table" and not x.isBot and typeof(x.player) == "Instance" and x.player:IsA("Player") then
		return x.player
	end
	return nil
end
Analytics.realPlayer = realPlayer

local function record(kind, ...)
	table.insert(Analytics.log, { kind, ... })
	if #Analytics.log > LOG_MAX then
		table.remove(Analytics.log, 1)
	end
end

local function call(method, ...)
	if not AS then
		return false
	end
	local args = table.pack(...)
	local ok = pcall(function()
		AS[method](AS, table.unpack(args, 1, args.n))
	end)
	return ok
end

---------------------------------------------------------------- onboarding funnel (once per player)
Analytics.ONBOARDING = {
	"Joined",
	"Got first secret",
	"First interaction",
	"Main secret done",
	"Saw the reveal",
	"Started round 2",
	"Finished round 3",
}
local stepDone = {} -- userId -> { [step] = true }

function Analytics.onboard(who, step)
	local pl = realPlayer(who)
	if not pl or type(step) ~= "number" or not Analytics.ONBOARDING[step] then
		return false
	end
	local s = stepDone[pl.UserId]
	if not s then
		s = {}
		stepDone[pl.UserId] = s
	end
	if s[step] then
		return false
	end
	s[step] = true
	record("onboard", pl.UserId, step)
	call("LogOnboardingFunnelStepEvent", pl, step, Analytics.ONBOARDING[step])
	return true
end

---------------------------------------------------------------- per-round funnel
Analytics.ROUND = { "Round started", "First interaction", "Main secret done", "Saw the reveal" }
local roundStep = {} -- userId -> { round = n, [step] = true }

function Analytics.roundStep(who, step)
	local pl = realPlayer(who)
	if not pl or not Analytics.ROUND[step] then
		return false
	end
	local r = roundStep[pl.UserId]
	if not r or r.round ~= Core.round then
		r = { round = Core.round }
		roundStep[pl.UserId] = r
	end
	if r[step] then
		return false
	end
	r[step] = true
	record("round", pl.UserId, step)
	call("LogFunnelStepEvent", pl, "Round", ("%d-%d"):format(Core.round or 0, pl.UserId), step, Analytics.ROUND[step])
	return true
end

---------------------------------------------------------------- economy
local function coinsOf(pl)
	local D = Core.M.Data
	local prof = D and D.get(pl)
	return prof and tonumber(prof.coins) or 0
end

-- n > 0 source, n < 0 sink. kind = "Gameplay" | "Shop" | "IAP" | "Onboarding" | "ContextualPurchase" ...
function Analytics.coins(who, n, kind, sku)
	local pl = realPlayer(who)
	n = tonumber(n) or 0
	if not pl or n == 0 then
		return false
	end
	local flow = n > 0 and Enum.AnalyticsEconomyFlowType.Source or Enum.AnalyticsEconomyFlowType.Sink
	local tt = Enum.AnalyticsEconomyTransactionType[kind or "Gameplay"] or Enum.AnalyticsEconomyTransactionType.Gameplay
	sku = tostring(sku or "other"):gsub("[^%w_ ]", ""):sub(1, 40)
	record("coins", pl.UserId, n, sku)
	call("LogEconomyEvent", pl, flow, "Coins", math.abs(n), coinsOf(pl), tt.Name, sku ~= "" and sku or "other")
	return true
end

-- Core.addCoins reasons -> clean SKU names
local REASON_SKU = {
	["correct accusation!"] = "AccuseRight",
	["wrong accusation"] = "AccuseWrong",
	bribe = "Bribe",
	found = "Search",
	["buried treasure!"] = "Treasure",
	["PERFECT!"] = "Arcade",
	arcade = "Arcade",
	["token cashed in"] = "TokenCashIn",
	["Photo Camera"] = "PhotoCamera",
	["token traded"] = "TokenTrade",
	["Gold Token"] = "GoldToken",
	["secret reroll"] = "Reroll",
}
function Analytics.onCoins(p, n, reason)
	if p == nil or p.isBot then
		return
	end
	local sku = reason and (REASON_SKU[reason] or reason) or (n > 0 and "RoundReward" or "Purchase")
	local kind = "Gameplay"
	if n < 0 and (sku == "PhotoCamera" or sku == "GoldToken" or sku == "Purchase") then
		kind = "Shop"
	end
	Analytics.coins(p, n, kind, sku)
end

---------------------------------------------------------------- custom events
function Analytics.event(who, name, value)
	local pl = realPlayer(who)
	if not pl then
		return false
	end
	record("event", pl.UserId, name)
	call("LogCustomEvent", pl, name, tonumber(value) or 1)
	return true
end

---------------------------------------------------------------- wiring
function Analytics.init()
	Core.coinHooks = Core.coinHooks or {}
	table.insert(Core.coinHooks, Analytics.onCoins)

	Bus.on("ProfileLoaded", function(player, prof)
		Analytics.onboard(player, 1)
		local played = prof and prof.stats and tonumber(prof.stats.roundsPlayed) or 0
		if played >= 1 then
			-- returning player: earlier steps are history, don't count them as drop-offs
			for i = 2, math.min(5, 1 + played) do
				Analytics.onboard(player, i)
			end
		end
	end)
	Bus.on("PhaseChanged", function(phase)
		if phase ~= "Play" then
			return
		end
		local D = Core.M.Data
		for _, p in pairs(Core.participants) do
			if p.inRound and not p.isBot and p.player then
				Analytics.onboard(p, 2)
				Analytics.roundStep(p, 1)
				local prof = D and D.get(p.player)
				local played = prof and prof.stats and tonumber(prof.stats.roundsPlayed) or 0
				if played >= 1 then
					Analytics.onboard(p, 6)
				end
			end
		end
	end)
	Bus.on("Interacted", function(p)
		Analytics.onboard(p, 3)
		Analytics.roundStep(p, 2)
	end)
	Bus.on("SecretCompleted", function(p, slot, o)
		if slot == "main" then
			Analytics.onboard(p, 4)
			Analytics.roundStep(p, 3)
		end
		if o and o.bonus then
			Analytics.event(p, "BonusSecretDone", 1)
		end
		Analytics.event(p, "SecretDone_" .. tostring(o and o.tier or "Easy"), 1)
	end)
	Bus.on("SecretFailed", function(p)
		Analytics.event(p, "SecretFailed", 1)
	end)
	Bus.on("RoundRevealed", function()
		local D = Core.M.Data
		for _, p in pairs(Core.participants) do
			if p.inRound and not p.isBot and p.player then
				Analytics.onboard(p, 5)
				Analytics.roundStep(p, 4)
				-- stats are added in finalizeRound, which runs before RoundRevealed
				local prof = D and D.get(p.player)
				local played = prof and prof.stats and tonumber(prof.stats.roundsPlayed) or 0
				if played >= 3 then
					Analytics.onboard(p, 7)
				end
			end
		end
	end)
	Bus.on("Detained", function(p)
		Analytics.event(p, "Detained", 1)
	end)
	Bus.on("Accused", function(accuser, _, _, correct)
		Analytics.event(accuser, correct and "AccuseRight" or "AccuseWrong", 1)
	end)
	Bus.on("CasinoWin", function(p, payout)
		Analytics.event(p, "ArcadeWin", payout)
	end)
	Players.PlayerRemoving:Connect(function(pl)
		stepDone[pl.UserId] = nil
		roundStep[pl.UserId] = nil
	end)
end

-- shop purchases bypass Core.addCoins (they edit prof.coins directly): Shop calls this
function Analytics.shopBuy(player, id, price)
	Analytics.coins(player, -(tonumber(price) or 0), "Shop", id)
end

local _ = Config
return Analytics
