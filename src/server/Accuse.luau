-- Accuse.luau — accusations per incident. Correct = coins + xp; incorrect = -25 coins, +suspicion,
-- 60 s cooldown (never elimination). Correct accusation solves the incident publicly (who stole it is
-- announced, the item stays in play). Bus "Accused" feeds secrets (accuse / convinceAccuse / fooled).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Bus = require(script.Parent.Bus)
local Core = require(script.Parent.Core)

local Accuse = {}
Accuse.history = {} -- {accuser, target, incident, correct, time}
Accuse.accusedCount = {} -- pid -> times accused this round

-- A correct accusation pays once per culprit per accuser per round (anti-farm). No pay between allies,
-- none on a Swipe whose victim is allied with the thief or the accuser (staged swipes), and none to a
-- Swipe victim whose thief was already paid for catching them (mutual swipe pairs). It still solves.
function Accuse.shouldPay(accuser, target, inc)
	accuser.paidCulprits = accuser.paidCulprits or {}
	if accuser.paidCulprits[target.id] then
		return false
	end
	local Social = Core.M.Social
	if Social and Social.areAllies(accuser.id, target.id) then
		return false
	end
	if inc.kind == "Swipe" and inc.victim then
		-- staged swipe between friends: the victim is allied with the thief, or with the accuser
		if Social and (Social.areAllies(inc.victim, target.id) or Social.areAllies(inc.victim, accuser.id)) then
			return false
		end
		-- mutual swipe pair: the thief was already paid for catching this victim
		if inc.victim == accuser.id and target.paidCulprits and target.paidCulprits[accuser.id] then
			return false
		end
	end
	return true
end

-- returns result table or nil, reason
function Accuse.accuse(accuser, targetId, incidentId)
	if not Core.inPlay() then
		return nil, "not in play"
	end
	local Evidence = Core.M.Evidence
	local inc = Evidence and Evidence.byIncident[incidentId]
	if not inc then
		return nil, "no incident"
	end
	local target = Core.participants[targetId]
	if not target or target == accuser or not target.inRound then
		return nil, "bad target"
	end
	local now = os.clock()
	if accuser.accuseReadyAt > now then
		Core.toast(accuser, ("⚖️ Investigation cooldown: %d s"):format(math.ceil(accuser.accuseReadyAt - now)), "bad", "Locked")
		return nil, "cooldown"
	end
	if inc.solved then
		Core.toast(accuser, "That incident is already solved.", "info")
		return nil, "solved"
	end
	accuser.accusedIncidents = accuser.accusedIncidents or {}
	if accuser.accusedIncidents[incidentId] then
		Core.toast(accuser, "You already made an accusation for this incident.", "info")
		return nil, "dup"
	end
	accuser.accusedIncidents[incidentId] = true
	accuser.accuseReadyAt = now + Config.AccuseCooldown
	local correct = inc.culprit ~= nil and inc.culprit == targetId
	Accuse.accusedCount[targetId] = (Accuse.accusedCount[targetId] or 0) + 1
	local rec = { accuser = accuser.id, target = targetId, incident = incidentId, correct = correct, time = Core.now() }
	table.insert(Accuse.history, rec)
	local Progress = Core.M.Progress
	if correct then
		inc.solved = true
		inc.solvedBy = accuser.id
		local pay = Accuse.shouldPay(accuser, target, inc)
		rec.paid = pay
		if pay then
			accuser.paidCulprits[target.id] = true
			Core.addCoins(accuser, Config.AccuseRightCoins, "correct accusation!")
			if not accuser.isBot and Progress then
				Progress.addXP(accuser.player, Config.AccuseRightXP)
				Progress.addStat(accuser.player, "correctAccusations", 1)
				Progress.addStat(accuser.player, "investigationSuccesses", 1)
			end
			accuser.roundXP = (accuser.roundXP or 0) + Config.AccuseRightXP
		else
			Core.toast(accuser, ("✅ Correct! No reward for catching %s again (or a staged swipe)."):format(target.name), "info")
		end
		accuser.accuseReadyAt = now + 10 -- a correct call shouldn't block the next investigation long
		target.suspicion += 2
		Core.toastAll(("⚖️ %s correctly accused %s: %s"):format(accuser.name, target.name, inc.title), "event", "VineBoom")
		Core.toast(target, ("😱 %s figured you out!"):format(accuser.name), "bad", "Bruh")
		if Evidence then
			Evidence.broadcastIncidents()
		end
	else
		Core.addCoins(accuser, -Config.AccuseWrongCoins, "wrong accusation", true)
		accuser.suspicion += Config.AccuseWrongSuspicion
		if not accuser.isBot and Progress then
			Progress.addStat(accuser.player, "wrongAccusations", 1)
		end
		Core.toast(accuser, ("❌ Wrong! %s didn't do it. (-%d 🪙, %d s cooldown)"):format(target.name, Config.AccuseWrongCoins, Config.AccuseCooldown), "bad", "Fail")
		Core.toast(target, ("😤 %s wrongly accused you."):format(accuser.name), "social")
		-- the real culprit fooled someone
		local culprit = inc.culprit and Core.participants[inc.culprit]
		if culprit and not culprit.isBot and Progress then
			Progress.addStat(culprit.player, "playersFooled", 1)
		end
	end
	Bus.fire("Accused", accuser, target, inc, correct)
	return rec
end

function Accuse.resetRound()
	Accuse.history = {}
	Accuse.accusedCount = {}
	for _, p in pairs(Core.participants) do
		p.accuseReadyAt = 0
		p.accusedIncidents = {}
		p.paidCulprits = {}
	end
end

function Accuse.init()
	Core.onAction("Accuse", function(player, args, p)
		local tid = Core.vInt(args.targetId, -9, 2 ^ 53)
		local inc = Core.vStr(args.incident, 32)
		if p and tid and inc and p.inRound then
			Accuse.accuse(p, tid, inc)
		end
	end)
end

return Accuse
