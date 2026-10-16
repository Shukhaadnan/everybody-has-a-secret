-- Round.luau — the round state machine (Lobby → Intro → Play → Reveal → Rewards → loop), player join /
-- leave / respawn handling, zone tracking + speed, the RoundState remote and the end-of-round rewards.
-- The tick is wrapped in pcall by Main so one error never kills the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Bus = require(script.Parent.Bus)
local Core = require(script.Parent.Core)

local Round = {}
Round.phaseEndsClock = 0
Round.warned = false
Round.lastReveal = nil
Round.lastRewards = {} -- userId -> payload (late Ready re-send)
Round.forceSkip = false -- SelfTest: jump to the next phase
Round.paused = false -- SelfTest: freeze the state machine while it pokes services

local function plazaSpot(i)
	local spawns = Core.markers("SpawnPlaza_")
	if #spawns > 0 then
		local idx = i or Core.rng:NextInteger(1, #spawns)
		-- wrap-around (more participants than markers): shift each extra ring 3 studs so nobody stacks
		return spawns[(idx - 1) % #spawns + 1].Position + Vector3.new(((idx - 1) // #spawns) * 3, 0, 0)
	end
	local ls = Core.marker("LobbySpawn")
	if ls then
		return ls.Position
	end
	return Core.zonePoint("Plaza") or Vector3.new(0, 10, 0)
end
Round.plazaSpot = plazaSpot

---------------------------------------------------------------- RoundState
function Round.statePayload()
	local endsAt = Core.now() + math.max(0, Round.phaseEndsClock - os.clock())
	return {
		phase = Core.phase,
		endsAt = endsAt,
		round = Core.round,
		warning = Core.phase == "Play" and Round.warned,
	}
end
function Round.broadcastState()
	Core.broadcast("RoundState", Round.statePayload())
	workspace:SetAttribute("Phase", Core.phase)
	workspace:SetAttribute("PhaseEndsAt", Round.statePayload().endsAt)
end

local function setPhase(phase, duration)
	Core.phase = phase
	Round.phaseEndsClock = os.clock() + duration
	if phase == "Play" then
		Core.roundStartClock = os.clock()
		Core.roundEndsAt = Core.now() + duration
		Round.warned = false
	end
	Round.broadcastState()
	Bus.fire("PhaseChanged", phase, duration)
end
Round.setPhase = setPhase

---------------------------------------------------------------- players
local function onCharacter(p, char)
	task.defer(function()
		if not char.Parent then
			return
		end
		-- new character while still flagged hidden (respawn without Died): clear it
		if p.hidden and Core.M.Interact then
			p.hideFrom = nil
			pcall(Core.M.Interact.unhide, p)
		end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = Config.PlayerWalkSpeed
			hum.Died:Connect(function()
				local Interact = Core.M.Interact
				-- died/reset while hiding: free the hide spot and clear the hidden state (no snap-back later)
				if p.hidden and Interact then
					p.hideFrom = nil
					pcall(Interact.unhide, p)
				end
				-- drop carried hot items back to their origin (never lose story items to a reset)
				for _, t in ipairs(Core.items(p)) do
					if t:GetAttribute("Hot") and Interact then
						pcall(Interact.returnToOrigin, t)
					elseif t.Parent ~= p.stash and Core.participants[p.id] == p then
						-- keep objective items through a death/reset (Roblox clears the Backpack on respawn)
						p.stash = p.stash or Instance.new("Folder")
						p.stash.Name = "Stash_" .. p.id
						p.stash.Parent = Core.holdFolder()
						t.Parent = p.stash
					end
				end
			end)
		end
		if Core.isDetained(p) and Core.M.Security then
			Core.teleport(p, Core.M.Security.cellPos())
		elseif not Core.inPlay() then
			Core.teleport(p, plazaSpot())
		end
		-- restore carried items kept in the stash while dead / before the first spawn
		if p.stash and #p.stash:GetChildren() > 0 then
			local bp = p.player:FindFirstChildOfClass("Backpack") or p.player:WaitForChild("Backpack", 5)
			if bp and char.Parent then
				for _, t in ipairs(p.stash:GetChildren()) do
					t.Parent = bp
				end
			end
		end
		if Core.M.Shop then
			pcall(Core.M.Shop.applyCosmetics, p.player)
		end
	end)
end

function Round.onPlayerAdded(player)
	local p = Core.addPlayer(player)
	player.CharacterAdded:Connect(function(char)
		onCharacter(p, char)
	end)
	if player.Character then
		onCharacter(p, player.Character)
	end
	-- trim bots only between rounds: despawning one mid-round wipes its secret / evidence / accusations
	if Core.M.Bots and (Core.phase == "Lobby" or Core.phase == "Rewards") then
		Core.M.Bots.rebalance()
	end
	-- joined mid-round: join right away with a solo secret (once profile is loaded)
	if Core.phase == "Play" or Core.phase == "Intro" then
		task.spawn(function()
			local t0 = os.clock()
			local Data = Core.M.Data
			while player.Parent and Data and not Data.get(player) and os.clock() - t0 < 15 do
				task.wait(0.25)
			end
			if player.Parent and (Core.phase == "Play" or Core.phase == "Intro") and not p.inRound then
				p.inRound = true
				if Core.M.Secrets then
					pcall(Core.M.Secrets.assignLate, p)
				end
			end
		end)
	end
	return p
end

function Round.onPlayerRemoving(player)
	local p = Core.byPlayer[player]
	if p then
		-- hot items go back to where they came from
		local Interact = Core.M.Interact
		for _, t in ipairs(Core.items(p)) do
			if t:GetAttribute("Hot") and Interact then
				pcall(Interact.returnToOrigin, t)
			end
		end
		Core.removeParticipant(p.id)
	end
	Round.lastRewards[player.UserId] = nil
	task.defer(function()
		if Core.M.Bots then
			Core.M.Bots.rebalance()
		end
	end)
end

-- full state for a client that just finished loading
function Round.sendAll(player)
	local p = Core.byPlayer[player]
	Core.send(player, "RoundState", Round.statePayload())
	if not p then
		return
	end
	local Secrets = Core.M.Secrets
	if Secrets and Secrets.get(p) and (Core.phase == "Intro" or Core.phase == "Play") then
		Secrets.sendSecret(p)
	end
	local Evidence = Core.M.Evidence
	if Evidence then
		Evidence.sendIncidents(p)
		Evidence.sendJournal(p)
	end
	if Core.M.Progress then
		Core.M.Progress.sendProfile(player)
	end
	if Core.phase == "Reveal" and Round.lastReveal then
		Core.send(player, "Reveal", Round.lastReveal)
	elseif Core.phase == "Rewards" and Round.lastRewards[player.UserId] then
		Core.send(player, "Rewards", Round.lastRewards[player.UserId])
	end
	if Core.M.Events then
		for _, e in ipairs(Core.M.Events.activeList()) do
			Core.send(player, "EventBanner", e)
		end
	end
	if Core.isDetained(p) then
		Core.send(player, "Detained", { untilTime = Core.now() + (p.detainedUntil - os.clock()), reason = "detained by security" })
	end
end

---------------------------------------------------------------- zone + speed tracker
local function trackZones()
	for _, p in pairs(Core.participants) do
		local pos = Core.pos(p)
		if pos then
			local z = Core.zoneAt(pos)
			if z ~= p.zone then
				local old = p.zone
				p.zone = z
				if z then
					Bus.fire("ZoneChanged", p, z, old)
				end
			end
		end
		Core.updateSpeed(p)
	end
end

---------------------------------------------------------------- phase transitions
local function gatherAll()
	local i = 0
	for _, p in ipairs(Core.list(false)) do
		i += 1
		if p.isBot then
			Core.teleport(p, plazaSpot(i))
		elseif p.player and p.player.Character then
			Core.teleport(p, plazaSpot(i))
		end
	end
end

local function cleanupWorld()
	local M = Core.M
	if M.Events then
		pcall(M.Events.stopAll)
	end
	if M.Security then
		pcall(M.Security.resetRound)
	end
	for _, p in pairs(Core.participants) do
		pcall(Core.clearItems, p)
		p.inRound = false
		p.suspicion = 0
		p.roundCoins = 0
		p.roundXP = 0
		p.stolenThisRound = nil
		p.hiddenThisRound = nil
		p.wantedUntil = 0
	end
	if M.Interact then
		pcall(M.Interact.resetRound)
	end
	if M.Evidence then
		pcall(M.Evidence.reset)
	end
	if M.Social then
		pcall(M.Social.resetRound)
	end
	if M.Accuse then
		pcall(M.Accuse.resetRound)
	end
	if M.Bots then
		pcall(M.Bots.resetPositions)
	end
end
Round.cleanupWorld = cleanupWorld

function Round.startIntro()
	cleanupWorld()
	Core.round += 1
	Round.lastReveal = nil
	Round.lastRewards = {}
	for _, p in pairs(Core.participants) do
		p.inRound = Core.alive(p) or p.isBot or (p.player ~= nil)
	end
	pcall(gatherAll) -- a teleport error must not leave the phase uncommitted (round would re-start every tick)
	local M = Core.M
	if M.Interact then
		pcall(M.Interact.spawnLoot)
	end
	local forced = {}
	if M.Secrets then
		local ok, err = pcall(M.Secrets.assignAll)
		if not ok then
			warn("[Round] secret assignment failed: " .. tostring(err))
		end
		forced = M.Secrets.forcedEvents or {}
		pcall(M.Secrets.startRound)
	end
	if M.Events then
		pcall(M.Events.planRound, forced, Config.PlayTime)
	end
	setPhase("Intro", Config.IntroTime)
	Core.toastAll(("🌴 Round %d — read your secret. Trust no one."):format(Core.round), "event", "SecretGet")
end

function Round.startPlay()
	setPhase("Play", Config.PlayTime)
	Core.toastAll("🔒 Go! Complete your secret without getting caught.", "event", "Whoosh")
end

local function rewardOne(p, r, Data, Progress)
	if p.isBot then
		p.coins += r.coins
	elseif p.player and Data then
		local prof = Data.get(p.player)
		if prof then
			-- VIP pass: +10% coins on round rewards (as sold in ShopConfig.Passes.VIP)
			if prof.passes and prof.passes.VIP and r.coins > 0 then
				r.breakdown = r.breakdown or {}
				local bonus = math.max(1, math.floor(r.coins * (Config.VipCoinBonus or 0.1)))
				r.coins += bonus
				table.insert(r.breakdown, { label = "VIP bonus (+10%)", coins = bonus, xp = 0 })
			end
			Core.addCoins(p, r.coins)
			local gained, leveled = Progress.addXP(p.player, r.xp, prof)
			gained = tonumber(gained) or r.xp
			if gained > r.xp then
				r.breakdown = r.breakdown or {}
				table.insert(r.breakdown, { label = "2x XP", coins = 0, xp = gained - r.xp })
			end
			if r.st and r.st.tutorial then
				prof.tutorialDone = true
			end
			prof.dirty = true
			Data.refreshLeaderstats(p.player)
			local payload = {
				coins = r.coins,
				xp = math.max(gained, r.xp),
				level = prof.level,
				leveledUp = leveled == true,
				title = Config.titleForLevel(prof.level),
				breakdown = r.breakdown,
			}
			-- key by UserId for real players; SelfTest passes a Folder stand-in, which falls back to p.id
			local uid = p.player:IsA("Player") and p.player.UserId or p.id
			Round.lastRewards[uid] = payload
			pcall(Progress.submitLeaderboards, p.player, prof)
		end
	end
end
Round.rewardOne = rewardOne

local function applyRewards(results)
	local Data, Progress = Core.M.Data, Core.M.Progress
	for pid, r in pairs(results) do
		local p = Core.participants[pid]
		if p then
			-- one bad profile must never stop (or repeat) everyone else's payout
			local ok, err = pcall(rewardOne, p, r, Data, Progress)
			if not ok then
				warn("[Round] reward for " .. tostring(p.name) .. ": " .. tostring(err))
			end
		end
	end
end

function Round.startReveal()
	local M = Core.M
	if M.Events then
		pcall(M.Events.stopAll)
	end
	if M.Security then
		pcall(M.Security.releaseAll)
	end
	local res
	if M.Secrets then
		local ok, r = pcall(M.Secrets.finalizeRound)
		if ok then
			res = r
		else
			warn("[Round] finalize failed: " .. tostring(r))
		end
	end
	res = res or { rows = {}, mvp = 0, story = "", results = {} }
	Round.lastReveal = { rows = res.rows, mvp = res.mvp, story = res.story }
	Round.lastResults = res
	setPhase("Reveal", Config.RevealTime) -- commit first: an error below can never re-run the payout
	local okR, errR = pcall(applyRewards, res.results or {})
	if not okR then
		warn("[Round] rewards: " .. tostring(errR))
	end
	Core.broadcast("Reveal", Round.lastReveal)
	Core.sfxAll("VineBoom")
	Bus.fire("RoundRevealed", res)
end

function Round.startRewards()
	setPhase("Rewards", Config.RewardsTime)
	for _, p in ipairs(Core.realPlayers()) do
		local pay = p.player and Round.lastRewards[p.player.UserId]
		if pay then
			Core.send(p, "Rewards", pay)
		end
		if Core.M.Progress and p.player then
			Core.M.Progress.sendProfile(p.player)
		end
	end
end

function Round.startLobby()
	cleanupWorld()
	if Core.M.Bots then
		pcall(Core.M.Bots.rebalance) -- bots are only trimmed between rounds
	end
	setPhase("Lobby", Config.LobbyTime)
	pcall(gatherAll)
end

---------------------------------------------------------------- tick
function Round.tick()
	pcall(trackZones)
	if Round.paused then
		return
	end
	local now = os.clock()
	local phase = Core.phase
	local due = now >= Round.phaseEndsClock or Round.forceSkip
	Round.forceSkip = false
	if phase == "Lobby" then
		if #Core.realPlayers() < Config.MinPlayers and not workspace:GetAttribute("RunSelfTest") then
			-- keep waiting, but keep the timer visibly full
			if Round.phaseEndsClock - now < Config.LobbyTime - 0.5 then
				setPhase("Lobby", Config.LobbyTime)
			end
			return
		end
		if due then
			-- a newcomer whose save is still loading would miss the tutorial: hold the lobby up to 6 s
			local D = Core.M.Data
			for _, rp in ipairs(Core.realPlayers()) do
				if D and rp.player and not D.get(rp.player) and (Round.lobbyHold or 0) < 24 then
					Round.lobbyHold = (Round.lobbyHold or 0) + 1 -- 24 ticks * 0.25 s = 6 s max
					return
				end
			end
			Round.lobbyHold = 0
			Round.startIntro()
		end
	elseif phase == "Intro" then
		if due then
			Round.startPlay()
		end
	elseif phase == "Play" then
		if Core.M.Events then
			local okE, errE = pcall(Core.M.Events.tick, Core.elapsed())
			if not okE then
				warn("[Round] events tick: " .. tostring(errE))
			end
		end
		local left = Round.phaseEndsClock - now
		if not Round.warned and left <= Config.FinalWarning then
			Round.warned = true
			Round.broadcastState()
			Core.toastAll("⏰ ONE MINUTE LEFT — finish your secrets!", "event", "Countdown")
		end
		-- everyone left? end early
		if #Core.realPlayers() == 0 and not workspace:GetAttribute("RunSelfTest") then
			due = true
		end
		if due then
			Round.startReveal()
		end
	elseif phase == "Reveal" then
		if due then
			Round.startRewards()
		end
	elseif phase == "Rewards" then
		if due then
			Round.startLobby()
		end
	end
end

function Round.init()
	Players.PlayerAdded:Connect(Round.onPlayerAdded)
	for _, pl in ipairs(Players:GetPlayers()) do
		task.spawn(Round.onPlayerAdded, pl)
	end
	Players.PlayerRemoving:Connect(Round.onPlayerRemoving)
	Core.onAction("Ready", function(player)
		Round.sendAll(player)
	end)
	setPhase("Lobby", Config.LobbyTime)
	-- players whose Ready arrived during the map build: send them the full state once
	for _, pl in ipairs(Players:GetPlayers()) do
		task.defer(function()
			pcall(Round.sendAll, pl)
		end)
	end
end

function Round.run()
	task.spawn(function()
		while true do
			local ok, err = pcall(Round.tick)
			if not ok then
				warn("[Round] tick error: " .. tostring(err))
			end
			task.wait(0.25)
		end
	end)
end

return Round
