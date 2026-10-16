-- Config.luau (SERVER owns; CLIENT may read). PURE data + tiny helpers, no Instances,
-- so it also loads under luau.exe for offline tests.
-- Quick self-tests may override any numeric/bool key via workspace attributes "Cfg_<Key>"
-- (Main calls Config.applyOverrides(function(k) return workspace:GetAttribute("Cfg_"..k) end)).
local Config = {}

---------------------------------------------------------------- round timings (seconds)
Config.LobbyTime = 10 -- lobby wait (starts once >= MinPlayers real players are present)
Config.MinPlayers = 1
Config.IntroTime = 8
Config.PlayTime = 360 -- 6 min (shorter rounds keep phone players; sir agreed Oct 8)
Config.FinalWarning = 60 -- "THE ROUND IS ENDING" at 1:00 left
Config.RevealTime = 20
Config.RewardsTime = 6
Config.EventsMin = 1
Config.EventsMax = 3
Config.FirstEventAfter = 90 -- events start after 1:30 of play
Config.EventGapMin = 60 -- min seconds between event starts
Config.BeginnerRounds = 3 -- after the tutorial: this many rounds with ONE easy secret (no side secret, no Hard/Legendary story roles)

---------------------------------------------------------------- participants / bots
Config.MaxPlayers = 24
Config.FillTo = 10 -- bots fill the server up to this many participants
Config.BotCount = 9 -- max bots
Config.BotNames = { "Guest_Mia", "Guest_Leo", "Guest_Zoe", "Guest_Max", "Guest_Ava", "Guest_Kai", "Guest_Ivy", "Guest_Sam", "Guest_Nia" }
Config.BotWalkSpeed = 14
Config.BotAccuseCorrectChance = 0.6 -- when the bot holds evidence for that incident
Config.BotThinkInterval = 0.5

---------------------------------------------------------------- movement / security
Config.PlayerWalkSpeed = 16
Config.GuardPatrolSpeed = 10
Config.GuardChaseSpeed = 18
Config.GuardCount = 3
Config.GuardSightRange = 45
Config.GuardCatchRange = 4.5
Config.GuardGiveUpTime = 25 -- lose interest after this long without catching
Config.CameraRange = 60
Config.CameraConeDeg = 70 -- full cone angle
Config.CameraScanInterval = 0.5
Config.CameraDetectCooldown = 12 -- per player per camera: footage once per 12 s
Config.DisableCamTime = 60
Config.OutageTime = 60
Config.DisguiseTime = 60
Config.DetentionTime = 20
Config.LockdownTime = 45
Config.PrankTime = 25 -- guards walk to a pranked phone

---------------------------------------------------------------- social / secret verification
Config.TalkRadius = 8
Config.TalkSeconds = 3
Config.FollowMin = 10
Config.FollowMax = 40
Config.SpotRange = 25
Config.SpotDot = 0.8 -- target LookVector · dir-to-follower above this (≈ 37°) = spotted
Config.SpotPenalty = 6 -- seconds of follow progress lost when spotted
Config.ConvinceWindow = 90 -- makeEnter: target must enter within 90 s after talking with you
Config.RequestTimeout = 20

---------------------------------------------------------------- economy
Config.StartCoins = 100
Config.GiveCoinsMax = 500
Config.BribeCost = 50
Config.SlotCost = 0 -- arcade machines are FREE (skill game, no gambling)
Config.CardsCost = 0
Config.ArcadeRoundCap = 80 -- max coins one player can win at the arcade per round
Config.FoodCost = 5
Config.ShopItemCost = 15
Config.JackpotMultiplier = 6
Config.MaxRerollsPerRound = 2
Config.RerollCoinCost = 150 -- used while the Robux SecretReroll ProductId is still 0
Config.VipCoinBonus = 0.1 -- VIP game pass: +10% coins on round rewards

-- tier rewards (side secret = SideFactor of the tier reward)
Config.Tiers = { "Easy", "Medium", "Hard", "Legendary" }
Config.TierReward = {
	Easy = { coins = 60, xp = 40 },
	Medium = { coins = 120, xp = 80 },
	Hard = { coins = 220, xp = 150 },
	Legendary = { coins = 400, xp = 300 },
}
Config.TierColor = { -- RGB (pure data; client builds Color3)
	Easy = { 80, 220, 110 },
	Medium = { 255, 205, 60 },
	Hard = { 255, 80, 80 },
	Legendary = { 190, 90, 255 },
}
Config.SideFactor = 0.5
Config.ParticipationCoins = 20
Config.ParticipationXP = 25
Config.MvpCoins = 50
Config.MvpXP = 40

-- accusations
Config.AccuseCooldown = 60
Config.AccuseRightCoins = 100
Config.AccuseRightXP = 80
Config.AccuseWrongCoins = 25 -- lost
Config.AccuseWrongSuspicion = 1
Config.AccuseRange = 9999 -- accusations are made from the journal, no range check

---------------------------------------------------------------- levels / titles
Config.MaxLevel = 100
Config.LevelTitles = {
	{ level = 1, title = "Rookie" },
	{ level = 5, title = "Guest" },
	{ level = 10, title = "Suspect" },
	{ level = 15, title = "Insider" },
	{ level = 25, title = "Detective" },
	{ level = 35, title = "Agent" },
	{ level = 50, title = "Mastermind" },
	{ level = 75, title = "Phantom" },
	{ level = 100, title = "Legend" },
}

-- XP needed to go from level n to n+1
function Config.xpForLevel(n: number): number
	n = math.max(1, math.floor(n))
	return 100 + (n - 1) * 35 + math.floor((n - 1) ^ 1.5 * 4)
end

function Config.titleForLevel(level: number): string
	local t = "Rookie"
	for _, row in ipairs(Config.LevelTitles) do
		if level >= row.level then
			t = row.title
		end
	end
	return t
end

---------------------------------------------------------------- challenges
-- stat keys are the same ones Progress.addStat uses
Config.DailyPool = {
	{ id = "d_complete3", text = "Complete 3 secrets", stat = "secretsCompleted", max = 3, reward = 80 },
	{ id = "d_play5", text = "Play 5 rounds", stat = "roundsPlayed", max = 5, reward = 60 },
	{ id = "d_accuse1", text = "Make a correct accusation", stat = "correctAccusations", max = 1, reward = 70 },
	{ id = "d_hard1", text = "Finish a Hard secret", stat = "hardCompleted", max = 1, reward = 90 },
	{ id = "d_evidence5", text = "Find 5 pieces of evidence", stat = "evidenceFound", max = 5, reward = 60 },
	{ id = "d_steal1", text = "Steal an item", stat = "itemsStolen", max = 1, reward = 60 },
	{ id = "d_talk10", text = "Talk to 10 guests", stat = "talks", max = 10, reward = 50 },
	{ id = "d_side3", text = "Complete 3 side secrets", stat = "sideCompleted", max = 3, reward = 70 },
	{ id = "d_search10", text = "Search 10 containers", stat = "searches", max = 10, reward = 50 },
	{ id = "d_photo2", text = "Take 2 photos", stat = "photos", max = 2, reward = 50 },
}
Config.WeeklyPool = {
	{ id = "w_complete20", text = "Complete 20 secrets", stat = "secretsCompleted", max = 20, reward = 400, cosmetic = "Hat_DetectiveCap" },
	{ id = "w_accuse5", text = "Correctly identify 5 players", stat = "correctAccusations", max = 5, reward = 350, cosmetic = "Title_SharpEye" },
	{ id = "w_legend3", text = "Complete 3 Legendary secrets", stat = "legendaryCompleted", max = 3, reward = 500, cosmetic = "Trail_Phantom" },
	{ id = "w_play30", text = "Play 30 rounds", stat = "roundsPlayed", max = 30, reward = 300 },
	{ id = "w_steal10", text = "Steal 10 items", stat = "itemsStolen", max = 10, reward = 300 },
	{ id = "w_fool5", text = "Fool 5 players (they accused wrong)", stat = "playersFooled", max = 5, reward = 350 },
}
Config.DailyCount = 3
Config.WeeklyCount = 3

---------------------------------------------------------------- data
Config.DataStoreName = "EHAS_v1"
Config.AutosaveInterval = 60
Config.Leaderboards = {
	Masterminds = "secretsCompleted",
	Detectives = "correctAccusations",
	Thieves = "theftsCompleted",
	Social = "socialCompleted",
}

---------------------------------------------------------------- items
Config.ItemOrder = {
	"GoldenStatue", "DiamondNecklace", "VIPKeycard", "SecurityCard", "MasterKey", "CasinoChip", "Briefcase",
	"PhotoCamera", "StaffUniform", "Crowbar", "TreasureMap", "SecretLetter", "Champagne", "Pizza", "Flashlight",
}
-- random Search loot weights (fixed `Loot` attribute overrides)
Config.SearchLoot = {
	{ id = "Flashlight", w = 10 },
	{ id = "Champagne", w = 6 },
	{ id = "Pizza", w = 6 },
	{ id = "CasinoChip", w = 8 },
	{ id = "StaffUniform", w = 5 },
	{ id = "Crowbar", w = 4 },
	{ id = "PhotoCamera", w = 5 },
	{ id = "TreasureMap", w = 4 },
	{ id = "SecretLetter", w = 3 },
	{ id = "MasterKey", w = 2 },
	{ id = "SecurityCard", w = 2 },
	{ id = "VIPKeycard", w = 2 },
	{ id = "_coins", w = 12 }, -- a few coins
	{ id = "_nothing", w = 30 },
}
Config.SearchRefill = 90 -- a container can be searched again after this long
Config.MaxCarry = 4 -- max item tools a participant can hold

---------------------------------------------------------------- events
Config.Events = {
	SecurityLockdown = { title = "SECURITY LOCKDOWN", desc = "Restricted doors are sealed and guards are on alert.", icon = "🚨", duration = 45 },
	PowerOutage = { title = "POWER OUTAGE", desc = "Lights and cameras are down! Perfect cover...", icon = "⚡", duration = 60 },
	Storm = { title = "STORM", desc = "Outdoor areas are dangerous. Get inside!", icon = "🌧️", duration = 60 },
	CasinoJackpot = { title = "ARCADE FRENZY", desc = "Arcade prizes are doubled for 60 seconds!", icon = "🕹️", duration = 60 },
	VIPArrival = { title = "VIP ARRIVAL", desc = "A VIP has arrived at the Plaza with a mysterious briefcase.", icon = "👑", duration = 120 },
	KitchenFire = { title = "KITCHEN FIRE", desc = "The kitchen is on fire! Stay out!", icon = "🔥", duration = 45 },
	PoliceInvestigation = { title = "POLICE INVESTIGATION", desc = "Police are here. Guards are twice as fast, cameras can't be disabled.", icon = "🕵️", duration = 60 },
	BoatArrival = { title = "BOAT ARRIVAL", desc = "A boat is waiting at the dock... for 90 seconds.", icon = "🚤", duration = 90 },
}
Config.EventOrder = { "SecurityLockdown", "PowerOutage", "Storm", "CasinoJackpot", "VIPArrival", "KitchenFire", "PoliceInvestigation", "BoatArrival" }

---------------------------------------------------------------- remote rate limit
Config.ActionRate = 10 -- per second per player
Config.InteractRange = 15

---------------------------------------------------------------- overrides
function Config.applyOverrides(getter: (string) -> any)
	local applied = {}
	for k, v in pairs(Config) do
		local t = type(v)
		if t == "number" or t == "boolean" then
			local ok, o = pcall(getter, k)
			if ok and o ~= nil and type(o) == t then
				Config[k] = o
				table.insert(applied, k)
			end
		end
	end
	return applied
end

return Config
