-- Progress.luau — XP / levels / titles, stats, daily (3/day, UTC midnight) and weekly challenges,
-- OrderedDataStore leaderboards, and the `Profile` remote payload.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Bus = require(script.Parent.Bus)
local Core = require(script.Parent.Core)

local Progress = {}
local Data -- set in init

local function dayIndex(t)
	return math.floor((t or os.time()) / 86400)
end
local function weekIndex(t)
	-- weeks start Monday 00:00 UTC (epoch day 0 was a Thursday -> +3)
	return math.floor((dayIndex(t) + 3) / 7)
end
Progress.dayIndex = dayIndex
Progress.weekIndex = weekIndex

-- deterministic pick of challenges per day/week (same for everyone, different each day)
local function pickChallenges(pool, count, seed)
	local r = Random.new(seed)
	local idx = {}
	for i = 1, #pool do
		idx[i] = i
	end
	for i = #idx, 2, -1 do
		local j = r:NextInteger(1, i)
		idx[i], idx[j] = idx[j], idx[i]
	end
	local out = {}
	for i = 1, math.min(count, #idx) do
		local c = pool[idx[i]]
		table.insert(out, { id = c.id, cur = 0, done = false, claimed = false })
	end
	return out
end

local function poolById(pool, id)
	for _, c in ipairs(pool) do
		if c.id == id then
			return c
		end
	end
	return nil
end

function Progress.refreshChallenges(prof, now)
	local d = dayIndex(now)
	if prof.daily.day ~= d then
		prof.daily = { day = d, list = pickChallenges(Config.DailyPool, Config.DailyCount, d * 31 + 7) }
	end
	local w = weekIndex(now)
	if prof.weekly.week ~= w then
		prof.weekly = { week = w, list = pickChallenges(Config.WeeklyPool, Config.WeeklyCount, w * 131 + 3) }
	end
end

function Progress.levelInfo(prof)
	return prof.level, prof.xp, Config.xpForLevel(prof.level), Config.titleForLevel(prof.level)
end

function Progress.hasDoubleXP(player, prof)
	if prof.passes and prof.passes.DoubleXP then
		return true
	end
	return (prof.xpBoostUntil or 0) > os.time()
end

-- returns gained (after multipliers), leveledUp
function Progress.addXP(player, amount, prof)
	prof = prof or (Data and Data.get(player))
	if not prof or amount <= 0 then
		return 0, false
	end
	if Progress.hasDoubleXP(player, prof) then
		amount *= 2
	end
	amount = math.floor(amount)
	prof.xp += amount
	local leveled = false
	while prof.level < Config.MaxLevel and prof.xp >= Config.xpForLevel(prof.level) do
		prof.xp -= Config.xpForLevel(prof.level)
		prof.level += 1
		leveled = true
	end
	if prof.level >= Config.MaxLevel then
		prof.xp = math.min(prof.xp, Config.xpForLevel(prof.level))
	end
	prof.battlePass.xp += amount
	prof.battlePass.tier = math.floor(prof.battlePass.xp / 500)
	if leveled and player then
		Data.refreshLeaderstats(player)
		Bus.fire("ProfileChanged", player) -- refresh the overhead "Lv N" tag (it stayed at the old level)
		Core.toast(Core.byPlayer[player], ("LEVEL UP! Level %d — %s"):format(prof.level, Config.titleForLevel(prof.level)), "good", "LevelUp")
	end
	return amount, leveled
end

local function bumpChallenges(player, prof, stat, n)
	for _, group in ipairs({ { prof.daily.list, Config.DailyPool, "Daily" }, { prof.weekly.list, Config.WeeklyPool, "Weekly" } }) do
		for _, ch in ipairs(group[1]) do
			local def = poolById(group[2], ch.id)
			if def and def.stat == stat and not ch.done then
				ch.cur = math.min(def.max, ch.cur + n)
				if ch.cur >= def.max then
					ch.done = true
					ch.claimed = true
					prof.coins += def.reward
					if def.cosmetic then
						prof.owned[def.cosmetic] = true
					end
					if player then
						Data.refreshLeaderstats(player)
						local p = Core.byPlayer[player]
						Core.toast(p, ("%s challenge complete: %s  +%d 🪙%s"):format(group[3], def.text, def.reward,
							def.cosmetic and (" + " .. def.cosmetic:gsub("^%a+_", "")) or ""), "good", "Complete")
					end
				end
			end
		end
	end
end

function Progress.addStat(player, stat, n, prof)
	prof = prof or (Data and Data.get(player))
	if not prof then
		return
	end
	n = n or 1
	prof.stats[stat] = (prof.stats[stat] or 0) + n
	Progress.refreshChallenges(prof)
	bumpChallenges(player, prof, stat, n)
	prof.dirty = true
	if player then
		Progress.sendProfileSoon(player)
	end
end

---------------------------------------------------------------- Profile payload
function Progress.payload(player, prof)
	prof = prof or Data.get(player)
	if not prof then
		return nil
	end
	Progress.refreshChallenges(prof)
	local function chList(list, pool)
		local out = {}
		for _, ch in ipairs(list) do
			local def = poolById(pool, ch.id)
			if def then
				table.insert(out, { id = ch.id, text = def.text, cur = ch.cur, max = def.max, done = ch.done, reward = def.reward })
			end
		end
		return out
	end
	local stats = {}
	for k, v in pairs(prof.stats) do
		stats[k] = v
	end
	local owned = {}
	for k, v in pairs(prof.owned) do
		owned[k] = v
	end
	return {
		coins = prof.coins,
		level = prof.level,
		xp = prof.xp,
		xpNext = Config.xpForLevel(prof.level),
		title = Config.titleForLevel(prof.level),
		stats = stats,
		daily = chList(prof.daily.list, Config.DailyPool),
		weekly = chList(prof.weekly.list, Config.WeeklyPool),
		owned = owned,
		equipped = table.clone(prof.equipped),
		vip = prof.passes.VIP == true,
		doubleXP = Progress.hasDoubleXP(player, prof),
		firstTime = not prof.tutorialDone,
		battlePass = table.clone(prof.battlePass),
		saving = prof.canSave == true,
	}
end

function Progress.sendProfile(player)
	local pl = player
	local payload = Progress.payload(pl)
	if payload then
		Core.send(pl, "Profile", payload)
	end
end

local pendingSend = {}
function Progress.sendProfileSoon(player)
	if pendingSend[player] then
		return
	end
	pendingSend[player] = true
	task.delay(0.25, function()
		pendingSend[player] = nil
		if player.Parent then
			Progress.sendProfile(player)
		end
	end)
end

---------------------------------------------------------------- leaderboards
Progress.boards = {}
function Progress.submitLeaderboards(player, prof)
	for boardName, stat in pairs(Config.Leaderboards) do
		local v = prof.stats[stat] or 0
		if v > 0 then
			task.spawn(function()
				pcall(function()
					local ods = Progress.boards[boardName] or DataStoreService:GetOrderedDataStore("EHAS_LB_" .. boardName)
					Progress.boards[boardName] = ods
					ods:SetAsync(tostring(player.UserId), v)
				end)
			end)
		end
	end
end

-- top N per board: {boardName = {{userId, value}}} (pcall, empty on failure)
function Progress.topBoards(n)
	local out = {}
	for boardName in pairs(Config.Leaderboards) do
		out[boardName] = {}
		pcall(function()
			local ods = Progress.boards[boardName] or DataStoreService:GetOrderedDataStore("EHAS_LB_" .. boardName)
			Progress.boards[boardName] = ods
			local pages = ods:GetSortedAsync(false, n or 10)
			for _, e in ipairs(pages:GetCurrentPage()) do
				table.insert(out[boardName], { userId = tonumber(e.key), value = e.value })
			end
		end)
	end
	return out
end

function Progress.init()
	Data = Core.M.Data
	Bus.on("ProfileLoaded", function(player, prof)
		Progress.refreshChallenges(prof)
		Progress.sendProfileSoon(player)
	end)
	Bus.on("ProfileChanged", function(player)
		Progress.sendProfileSoon(player)
	end)
	Bus.on("ProfileSaving", function(player, prof)
		Progress.submitLeaderboards(player, prof)
	end)
	Players.PlayerRemoving:Connect(function(pl)
		pendingSend[pl] = nil
	end)
end

return Progress
