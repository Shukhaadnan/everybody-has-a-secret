-- Data.luau — player profiles + DataStore "EHAS_v1".
-- Rules: pcall everything; UpdateAsync with a per-profile seq so a late write never overwrites a newer
-- save; if the load FAILS (not "no data") saving is disabled for that session so a temporary outage
-- can't wipe a real save; save on leave + autosave + BindToClose. leaderstats Coins + Level.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Bus = require(script.Parent.Bus)

local Data = {}
Data.profiles = {} -- Player -> profile
Data.storeOk = nil -- nil unknown / true / false
local store
local inflight = 0 -- leave-saves still writing (BindToClose waits for them)

local function defaultStats()
	return {
		secretsCompleted = 0, secretsFailed = 0, mainCompleted = 0, sideCompleted = 0,
		correctAccusations = 0, wrongAccusations = 0, coinsEarned = 0, roundsPlayed = 0,
		easyCompleted = 0, mediumCompleted = 0, hardCompleted = 0, legendaryCompleted = 0,
		playersFooled = 0, itemsStolen = 0, timesCaught = 0, investigationSuccesses = 0,
		theftsCompleted = 0, socialCompleted = 0, evidenceFound = 0, talks = 0, searches = 0, photos = 0,
		roundsWon = 0,
	}
end
Data.defaultStats = defaultStats

function Data.newProfile()
	return {
		version = 1,
		seq = 0,
		coins = Config.StartCoins,
		xp = 0,
		level = 1,
		stats = defaultStats(),
		owned = { Victory_Cheer = true },
		equipped = { Hat = nil, Trail = nil, Title = nil, NameFx = nil, Mask = nil, Victory = "Victory_Cheer" },
		daily = { day = -1, list = {} },
		weekly = { week = -1, list = {} },
		purchases = {}, -- PurchaseId -> true (idempotent ProcessReceipt)
		purchaseOrder = {}, -- FIFO of ids so the table stays small
		passes = {}, -- VIP / DoubleXP cached grants
		products = {}, -- one-time products bought (StarterPack)
		xpBoostUntil = 0, -- os.time()
		tutorialDone = false,
		recent = {}, -- recent objective template ids
		battlePass = { season = 1, xp = 0, tier = 0 },
		firstJoin = os.time(),
	}
end

-- merge saved data into defaults (forward compatible)
local function reconcile(saved)
	local p = Data.newProfile()
	if type(saved) ~= "table" then
		return p
	end
	for k, v in pairs(saved) do
		if k == "stats" and type(v) == "table" then
			for sk, sv in pairs(v) do
				if type(sv) == "number" then
					p.stats[sk] = sv
				end
			end
		elseif k == "equipped" and type(v) == "table" then
			for sk, sv in pairs(v) do
				p.equipped[sk] = sv
			end
		elseif p[k] ~= nil and type(p[k]) == type(v) then
			p[k] = v
		elseif p[k] == nil then
			p[k] = v
		end
	end
	return p
end
Data.reconcile = reconcile

local function getStore()
	if store then
		return store
	end
	local ok, s = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = s
	else
		Data.storeOk = false
	end
	return store
end

local function key(userId)
	return "u_" .. tostring(userId)
end

-- low-level (also used by SelfTest with a fake key): returns ok, data|err
function Data.loadKey(k)
	local s = getStore()
	if not s then
		return false, "no store"
	end
	local lastErr
	for attempt = 1, 3 do
		local ok, res = pcall(function()
			return s:GetAsync(k)
		end)
		if ok then
			Data.storeOk = true
			return true, res
		end
		lastErr = res
		if attempt < 3 then
			task.wait(1 + attempt)
		end
	end
	Data.storeOk = false
	return false, lastErr
end

-- write with UpdateAsync; refuses when the stored seq is newer than ours, or EQUAL but written by
-- another server (server hop: both loaded N and both write N+1). Each write carries a unique wid so a
-- retry that finds its own earlier attempt already stored counts as saved.
local writeCounter = 0
function Data.saveKey(k, snapshot)
	local s = getStore()
	if not s then
		return false, "no store"
	end
	writeCounter += 1
	snapshot.wid = tostring(game.JobId) .. ":" .. tostring(writeCounter)
	local lastErr
	for attempt = 1, 3 do
		local rejected = false
		local ok, err = pcall(function()
			s:UpdateAsync(k, function(old)
				rejected = false
				if type(old) == "table" and type(old.seq) == "number" then
					if old.seq == snapshot.seq and old.wid == snapshot.wid then
						return nil -- our own earlier attempt already landed
					end
					if old.seq >= snapshot.seq then
						rejected = true
						return nil -- keep the stored (newer / other server's) save
					end
				end
				return snapshot
			end)
		end)
		if ok then
			if rejected then
				return false, "stale (a newer save exists)"
			end
			return true
		end
		lastErr = err
		if attempt < 3 then
			task.wait(1 + attempt)
		end
	end
	return false, lastErr
end

function Data.removeKey(k)
	local s = getStore()
	if not s then
		return false
	end
	return pcall(function()
		s:RemoveAsync(k)
	end)
end

---------------------------------------------------------------- leaderstats
local function makeLeaderstats(player, prof)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		ls.Parent = player
	end
	local c = ls:FindFirstChild("Coins") or Instance.new("IntValue")
	c.Name = "Coins"
	c.Value = prof.coins
	c.Parent = ls
	local l = ls:FindFirstChild("Level") or Instance.new("IntValue")
	l.Name = "Level"
	l.Value = prof.level
	l.Parent = ls
end
function Data.refreshLeaderstats(player)
	local prof = Data.profiles[player]
	local ls = player:FindFirstChild("leaderstats")
	if prof and ls then
		if ls:FindFirstChild("Coins") then
			ls.Coins.Value = prof.coins
		end
		if ls:FindFirstChild("Level") then
			ls.Level.Value = prof.level
		end
	end
end

---------------------------------------------------------------- profile api
function Data.get(player)
	return Data.profiles[player]
end

function Data.addCoins(player, n)
	local prof = Data.profiles[player]
	if not prof then
		return false
	end
	if prof.coins + n < 0 then
		return false
	end
	prof.coins += n
	prof.dirty = true
	Data.refreshLeaderstats(player)
	Bus.fire("ProfileChanged", player)
	return true
end

function Data.load(player)
	local prof
	-- unpublished Studio places throw on DataStore access -> load fails -> fresh profile, never saved
	local ok, saved = Data.loadKey(key(player.UserId))
	if not ok and RunService:IsStudio() then
		warn("[Data] DataStore unavailable in Studio (publish + enable API access to persist)")
	end
	if ok then
		prof = reconcile(saved)
		prof.canSave = true
		prof.isNew = saved == nil
	else
		warn(("[Data] load failed for %s (%s): saving disabled this session"):format(player.Name, tostring(saved)))
		prof = Data.newProfile()
		prof.canSave = false
		prof.isNew = false
		prof.loadFailed = true
	end
	if not player.Parent then
		return nil
	end
	Data.profiles[player] = prof
	makeLeaderstats(player, prof)
	Bus.fire("ProfileLoaded", player, prof)
	if prof.loadFailed and not RunService:IsStudio() then
		task.delay(4, function()
			local Core = require(script.Parent.Core)
			Core.toast(player, "⚠️ Couldn't load your save — progress this session won't be saved. Rejoin to retry.", "bad")
		end)
	end
	return prof
end

local function snapshot(prof)
	local s = {}
	for k, v in pairs(prof) do
		if k ~= "canSave" and k ~= "isNew" and k ~= "loadFailed" and k ~= "dirty" and k ~= "saving" then
			s[k] = v
		end
	end
	return s
end
Data.snapshot = snapshot

function Data.save(player, prof)
	prof = prof or Data.profiles[player]
	if not prof or not prof.canSave then
		return false
	end
	prof.seq += 1
	local snap = snapshot(prof)
	local ok, err = Data.saveKey(key(player.UserId), snap)
	if ok then
		prof.dirty = false
	else
		warn(("[Data] save failed for %s: %s"):format(player.Name, tostring(err)))
	end
	return ok
end

function Data.init()
	Players.PlayerAdded:Connect(function(pl)
		Data.load(pl)
	end)
	for _, pl in ipairs(Players:GetPlayers()) do
		if not Data.profiles[pl] then
			task.spawn(Data.load, pl)
		end
	end
	Players.PlayerRemoving:Connect(function(pl)
		local prof = Data.profiles[pl]
		if not prof then
			return
		end
		-- snapshot first, then drop the profile, then write
		Bus.fire("ProfileSaving", pl, prof)
		prof.seq += 1
		local snap = snapshot(prof)
		local canSave = prof.canSave
		Data.profiles[pl] = nil
		if canSave then
			inflight += 1
			local okC, ok, err = pcall(Data.saveKey, key(pl.UserId), snap)
			inflight -= 1
			if not (okC and ok) then
				warn("[Data] leave-save failed: " .. tostring(okC and err or ok))
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for pl, prof in pairs(Data.profiles) do
				if prof.canSave and pl.Parent then
					task.spawn(Data.save, pl, prof)
				end
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for pl, prof in pairs(Data.profiles) do
			if prof.canSave then
				pending += 1
				task.spawn(function()
					Data.save(pl, prof)
					pending -= 1
				end)
			end
		end
		local t0 = os.clock()
		task.wait(1) -- let PlayerRemoving leave-saves (players kicked by the shutdown) start and register
		while (pending > 0 or inflight > 0) and os.clock() - t0 < 25 do
			task.wait(0.2)
		end
	end)
end

return Data
