-- Social.luau — requests (TeamUp / Follow / Trade / Give) with Accept/Decline, alliances,
-- give coins, talk counting (within 8 studs for 3 s), follow tracking with "spotted" approximation,
-- and the "talked-to" memory used by makeEnter (convince someone to go somewhere).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Bus = require(script.Parent.Bus)
local Core = require(script.Parent.Core)

local Social = {}
Social.requests = {} -- requestId -> {from, to, kind, detail, expires, toolRef}
Social.allies = {} -- pid -> {pid=true}
Social.talkAcc = {} -- "a:b" (a<b) -> seconds together
Social.talked = {} -- pid -> {otherPid = clock of last completed talk}
Social.follow = {} -- followerId -> {targetId -> {secs, spottedAt}}
Social.watchers = {} -- followerId -> {targetId=true} (who to track; set by Secrets for follow conds)

local KINDS = { TeamUp = true, Follow = true, Trade = true, Give = true }

local function pairKey(a, b)
	if a < b then
		return a .. ":" .. b
	end
	return b .. ":" .. a
end

---------------------------------------------------------------- alliances
function Social.areAllies(a, b)
	return Social.allies[a] ~= nil and Social.allies[a][b] == true
end
local function sendAllies(p)
	if p.isBot then
		return
	end
	local list = {}
	for id in pairs(Social.allies[p.id] or {}) do
		if Core.participants[id] then
			table.insert(list, id)
		end
	end
	Core.send(p, "Allies", { list = list })
end
function Social.ally(a, b)
	Social.allies[a.id] = Social.allies[a.id] or {}
	Social.allies[b.id] = Social.allies[b.id] or {}
	Social.allies[a.id][b.id] = true
	Social.allies[b.id][a.id] = true
	sendAllies(a)
	sendAllies(b)
	Bus.fire("Allied", a, b)
end

---------------------------------------------------------------- requests
-- returns requestId or nil, reason
function Social.request(from, to, kind, detail)
	if not from or not to or from == to or not KINDS[kind] then
		return nil, "invalid"
	end
	if not Core.inPlay() then
		return nil, "not in play"
	end
	if Core.dist(from, to) > 40 then
		Core.toast(from, "Get closer to them first.", "bad")
		return nil, "far"
	end
	-- real senders: one request per target every 5 s (no popup spam on the target's screen)
	if not from.isBot then
		Social.lastReq = Social.lastReq or {}
		local rk = tostring(from.id) .. ">" .. tostring(to.id)
		if (Social.lastReq[rk] or 0) > os.clock() - 5 then
			Core.toast(from, "Wait a moment before asking again.", "info")
			return nil, "cooldown"
		end
		Social.lastReq[rk] = os.clock()
	end
	-- one pending request per pair
	for id, r in pairs(Social.requests) do
		if r.from == from.id and r.to == to.id then
			Social.requests[id] = nil
		end
	end
	local req = { from = from.id, to = to.id, kind = kind, detail = detail, expires = os.clock() + Config.RequestTimeout }
	if kind == "Give" or kind == "Trade" then
		local tool = Core.equipped(from) or (detail and Core.findItem(from, detail)) or Core.items(from)[1]
		if not tool then
			Core.toast(from, "Hold the item you want to give.", "bad")
			return nil, "no item"
		end
		req.tool = tool
		req.itemId = tool:GetAttribute("ItemId")
		req.detail = ("%s %s"):format(kind == "Give" and "wants to give you" or "wants to trade you", Core.itemName(req.itemId))
	elseif kind == "TeamUp" then
		req.detail = detail or "wants to team up with you"
	elseif kind == "Follow" then
		req.detail = detail or "wants you to follow them"
	end
	local id = HttpService:GenerateGUID(false):sub(1, 12)
	Social.requests[id] = req
	if to.isBot then
		task.delay(Core.rng:NextNumber(1, 3), function()
			if Social.requests[id] and Core.M.Bots then
				Social.respond(to, id, Core.M.Bots.decideRequest(to, from, req))
			end
		end)
	else
		Core.send(to, "Request", { requestId = id, fromUserId = from.id, fromName = from.name, kind = kind, detail = req.detail })
	end
	Core.toast(from, ("📨 Request sent to %s."):format(to.name), "social", "Click")
	Bus.fire("RequestSent", from, to, kind)
	return id
end

local function transferTool(from, to, tool)
	if not tool or not tool.Parent or Core.toolOwner(tool) ~= from then
		return false
	end
	if Core.itemCount(to) >= Config.MaxCarry then
		Core.toast(to, "Your hands are full.", "bad")
		Core.toast(from, to.name .. "'s hands are full.", "bad")
		return false
	end
	local id = tool:GetAttribute("ItemId")
	Core.takeTool(tool)
	Core.giveTool(to, tool)
	Core.toast(to, ("🎁 %s gave you the %s."):format(from.name, Core.itemName(id)), "social", "Progress")
	Core.toast(from, ("🎁 You gave %s the %s."):format(to.name, Core.itemName(id)), "social")
	Bus.fire("ItemGiven", from, to, id, tool)
	Bus.fire("ItemObtained", to, id, "gift", tool)
	return true
end
Social.transferTool = transferTool

function Social.respond(p, requestId, accept)
	local req = Social.requests[requestId]
	if not req or req.to ~= p.id then
		return false
	end
	Social.requests[requestId] = nil
	local from = Core.participants[req.from]
	if not from then
		return false
	end
	if not accept then
		Core.toast(from, ("❌ %s declined."):format(p.name), "social")
		Bus.fire("RequestDeclined", from, p, req.kind)
		return true
	end
	if os.clock() > req.expires then
		Core.toast(p, "That request expired.", "info")
		return false
	end
	if req.kind == "TeamUp" then
		Social.ally(from, p)
		Core.toast(from, ("🤝 %s teamed up with you."):format(p.name), "social", "Progress")
		Core.toast(p, ("🤝 You teamed up with %s. (Nothing forces either of you to keep it...)"):format(from.name), "social")
	elseif req.kind == "Follow" then
		Core.toast(from, ("👣 %s agreed to follow you."):format(p.name), "social")
		if p.isBot then
			p.botFollow = { id = from.id, untilT = os.clock() + 45 }
		end
	elseif req.kind == "Give" then
		if Core.dist(from, p) > 20 then
			Core.toast(p, "Too far away to hand it over.", "bad")
			return false
		end
		transferTool(from, p, req.tool)
	elseif req.kind == "Trade" then
		if Core.dist(from, p) > 20 then
			Core.toast(p, "Too far away to trade.", "bad")
			return false
		end
		-- trade: receiver gives their equipped/first item back
		local back = Core.equipped(p) or Core.items(p)[1]
		local ok = transferTool(from, p, req.tool)
		if ok and back and back ~= req.tool then
			transferTool(p, from, back)
			Bus.fire("Traded", from, p)
		end
	end
	Bus.fire("RequestAccepted", from, p, req.kind)
	return true
end

function Social.giveCoins(from, to, amount)
	if not from or not to or from == to then
		return false
	end
	if not Core.inPlay() then
		return false
	end
	amount = math.floor(amount)
	if amount < 1 or amount > Config.GiveCoinsMax then
		return false
	end
	if Core.dist(from, to) > 25 then
		Core.toast(from, "Get closer to give coins.", "bad")
		return false
	end
	if not Core.addCoins(from, -amount) then
		Core.toast(from, "Not enough coins.", "bad")
		return false
	end
	Core.addCoins(to, amount)
	Core.toast(from, ("💸 You gave %s %d coins."):format(to.name, amount), "social", "CoinGet")
	Core.toast(to, ("💰 %s gave you %d coins!"):format(from.name, amount), "social", "CoinGet")
	if Core.M.Security then
		Core.M.Security.log(("%s — coin transfer: %d coins between two guests"):format(Core.fmtTime(Core.now()), amount), "Transaction", Core.shuffle({ from.id, to.id }), nil, from.zone)
	end
	Bus.fire("CoinsGiven", from, to, amount)
	return true
end

---------------------------------------------------------------- talk + follow tracking
-- spotted: target faces the follower within SpotRange (server approximation via root LookVector)
function Social.isSpotted(target, follower)
	local tr, fr = Core.root(target), Core.root(follower)
	if not tr or not fr then
		return false
	end
	if follower.hidden or Core.isDisguised(follower) then
		return false
	end
	local to = fr.Position - tr.Position
	local d = to.Magnitude
	if d > Config.SpotRange or d < 0.1 then
		return false
	end
	local look = tr.CFrame.LookVector
	-- real players: use the camera look attribute if the client reports it? never trusted -> root only
	return look:Dot(to.Unit) >= Config.SpotDot
end

function Social.setFollowWatch(followerId, targetId, on)
	Social.watchers[followerId] = Social.watchers[followerId] or {}
	Social.watchers[followerId][targetId] = on or nil
end

local function tick(dt)
	if not Core.inPlay() then
		return
	end
	local list = Core.list(true)
	-- talking
	for i = 1, #list do
		local a = list[i]
		local pa = Core.pos(a)
		if pa and not a.hidden and not Core.isDetained(a) then
			for j = i + 1, #list do
				local b = list[j]
				local pb = Core.pos(b)
				local k = pairKey(a.id, b.id)
				if pb and not b.hidden and not Core.isDetained(b) and (pa - pb).Magnitude <= Config.TalkRadius then
					local acc = (Social.talkAcc[k] or 0) + dt
					Social.talkAcc[k] = acc
					if acc >= Config.TalkSeconds and acc - dt < Config.TalkSeconds then
						local now = os.clock()
						Social.talked[a.id] = Social.talked[a.id] or {}
						Social.talked[b.id] = Social.talked[b.id] or {}
						local firstA = Social.talked[a.id][b.id] == nil
						Social.talked[a.id][b.id] = now
						Social.talked[b.id][a.id] = now
						Bus.fire("Talked", a, b)
						Bus.fire("Talked", b, a)
						if firstA then
							for _, x in ipairs({ a, b }) do
								if not x.isBot and Core.M.Progress then
									Core.M.Progress.addStat(x.player, "talks", 1)
								end
							end
						end
					end
				else
					Social.talkAcc[k] = nil
				end
			end
		end
	end
	-- follow tracking (only for watched pairs)
	for fid, targets in pairs(Social.watchers) do
		local f = Core.participants[fid]
		if f and f.inRound then
			for tid in pairs(targets) do
				local t = Core.participants[tid]
				if t and t.inRound then
					Social.follow[fid] = Social.follow[fid] or {}
					local st = Social.follow[fid][tid] or { secs = 0, spottedAt = 0 }
					Social.follow[fid][tid] = st
					local d = Core.dist(f, t)
					if Social.isSpotted(t, f) and d <= Config.SpotRange then
						if os.clock() - st.spottedAt > 4 then
							st.spottedAt = os.clock()
							st.secs = math.max(0, st.secs - Config.SpotPenalty)
							Core.toast(f, ("👀 %s looked right at you! (-%d s)"):format(t.name, Config.SpotPenalty), "bad", "Detected")
							Bus.fire("Spotted", f, t, st.secs)
						end
					elseif d >= Config.FollowMin and d <= Config.FollowMax and not Core.isDetained(f) then
						st.secs += dt
						Bus.fire("Following", f, t, st.secs)
					end
				end
			end
		end
	end
end

function Social.talkedRecently(a, b, window)
	local t = Social.talked[a] and Social.talked[a][b]
	return t ~= nil and (os.clock() - t) <= (window or Config.ConvinceWindow)
end

function Social.resetRound()
	Social.requests = {}
	Social.lastReq = {}
	Social.allies = {}
	Social.talkAcc = {}
	Social.talked = {}
	Social.follow = {}
	Social.watchers = {}
	for _, p in ipairs(Core.realPlayers()) do
		sendAllies(p)
	end
end

function Social.init()
	Core.onAction("SocialRequest", function(player, args, p)
		local tid = Core.vInt(args.targetId, -9, 2 ^ 53)
		local kind = Core.vStr(args.kind, 16)
		if not p or not tid or not kind or not KINDS[kind] then
			return
		end
		local detail = type(args.detail) == "string" and args.detail:sub(1, 40) or nil
		local to = Core.participants[tid]
		if to and to.inRound then
			Social.request(p, to, kind, detail)
		end
	end)
	Core.onAction("Respond", function(player, args, p)
		local rid = Core.vStr(args.requestId, 40)
		if p and rid and type(args.accept) == "boolean" then
			Social.respond(p, rid, args.accept)
		end
	end)
	Core.onAction("GiveCoins", function(player, args, p)
		local tid = Core.vInt(args.targetId, -9, 2 ^ 53)
		local amt = Core.vInt(args.amount, 1, Config.GiveCoinsMax)
		local to = tid and Core.participants[tid]
		if p and to and amt then
			Social.giveCoins(p, to, amt)
		end
	end)
	Core.onAction("Emote", function(player, args, p)
		local name = Core.vStr(args.name, 16)
		if p and name and (name == "wave" or name == "point" or name == "cheer" or name == "laugh" or name == "dance1" or name == "dance2" or name == "dance3") then
			Bus.fire("Emote", p, name)
		end
	end)
	Bus.on("ParticipantRemoving", function(p)
		Social.allies[p.id] = nil
		for _, set in pairs(Social.allies) do
			set[p.id] = nil
		end
		Social.watchers[p.id] = nil
		Social.follow[p.id] = nil
		for id, r in pairs(Social.requests) do
			if r.from == p.id or r.to == p.id then
				Social.requests[id] = nil
			end
		end
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.5)
			local now = os.clock()
			local dt = now - last
			last = now
			local ok, err = pcall(tick, dt)
			if not ok then
				warn("[Social] " .. tostring(err))
			end
			for id, r in pairs(Social.requests) do
				if now > r.expires then
					Social.requests[id] = nil
				end
			end
		end
	end)
end

return Social
