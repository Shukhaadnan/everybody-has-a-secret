-- State.luau: single place that listens to every server->client remote, stores the latest data and
-- re-broadcasts it through local signals. UI modules read State.* on init and connect State.sig(name).
local U = require(script.Parent.Util)

local State = {}

State.round = { phase = "Lobby", endsAt = 0, round = 0, warning = false }
State.secret = nil :: any -- YourSecret payload (main/side kept up to date by SecretProgress)
State.incidents = {} :: { any }
State.evidence = {} :: { any }
State.allies = {} :: { [number]: boolean }
State.detainedUntil = 0
State.profile = nil :: any
State.monitor = nil :: any
State.reveal = nil :: any
State.rewards = nil :: any
State.zone = nil :: string?
State.events = {} :: { any } -- active event banners {id,title,icon,endsAt}
State.seenEvidence = 0

local sigs: { [string]: any } = {}
function State.sig(name: string): any
	local s = sigs[name]
	if not s then
		s = U.signal()
		sigs[name] = s
	end
	return s
end
function State.emit(name: string, ...)
	State.sig(name):Fire(...)
end

function State.remaining(): number
	return math.max(0, (tonumber(State.round.endsAt) or 0) - U.now())
end

function State.isDetained(): boolean
	return State.detainedUntil > U.now()
end

-- the objective we're currently steering the player toward: unfinished main, else unfinished side
function State.activeObjective(): (any, string?)
	local s = State.secret
	if not s then
		return nil, nil
	end
	for _, slot in ipairs({ "main", "side" }) do
		local o = s[slot]
		if type(o) == "table" and not o.done and not o.failed then
			return o, slot
		end
	end
	return nil, nil
end

local function rememberNames(rows: any)
	if type(rows) ~= "table" then
		return
	end
	for _, r in ipairs(rows) do
		if type(r) == "table" and type(r.userId) == "number" and type(r.name) == "string" then
			U.names[r.userId] = r.name
		end
	end
end

local started = false
function State.start()
	if started then
		return
	end
	started = true

	U.on("RoundState", function(p)
		local prev = State.round.phase
		State.round = {
			phase = tostring(p.phase or "Lobby"),
			endsAt = tonumber(p.endsAt) or 0,
			round = tonumber(p.round) or 0,
			warning = p.warning == true,
		}
		if State.round.phase ~= prev then
			-- the server ends every event at Reveal (Events.stopAll) without telling clients
			if State.round.phase ~= "Play" then
				State.events = {}
			end
			State.emit("Phase", State.round.phase, prev)
		end
		State.emit("RoundState", State.round)
	end)

	U.on("YourSecret", function(p)
		State.secret = p
		State.emit("YourSecret", p)
		State.emit("Secret", p)
	end)

	U.on("SecretProgress", function(p)
		local slot = p.slot == "side" and "side" or "main"
		if type(p.obj) ~= "table" then
			return
		end
		State.secret = State.secret or {}
		local old = State.secret[slot]
		State.secret[slot] = p.obj
		State.emit("SecretProgress", slot, p.obj, old)
		State.emit("Secret", State.secret)
	end)

	U.on("Incident", function(p)
		State.incidents = type(p.list) == "table" and p.list or {}
		State.emit("Incident", State.incidents)
	end)

	U.on("Evidence", function(p)
		local list = type(p.list) == "table" and p.list or {}
		local before = #State.evidence
		State.evidence = list
		State.emit("Evidence", list, #list - before)
	end)

	U.on("Allies", function(p)
		State.allies = {}
		if type(p.list) == "table" then
			for _, id in ipairs(p.list) do
				State.allies[id] = true
			end
		end
		State.emit("Allies", State.allies)
	end)

	U.on("Detained", function(p)
		State.detainedUntil = tonumber(p.untilTime) or 0
		State.emit("Detained", State.detainedUntil, p.reason)
	end)

	U.on("Profile", function(p)
		State.profile = p
		State.emit("Profile", p)
	end)

	U.on("Monitor", function(p)
		State.monitor = p
		State.emit("Monitor", p)
	end)

	U.on("Reveal", function(p)
		State.reveal = p
		rememberNames(p.rows)
		State.emit("Reveal", p)
	end)

	U.on("Rewards", function(p)
		State.rewards = p
		State.emit("Rewards", p)
	end)

	U.on("EventBanner", function(p)
		local dur = tonumber(p.duration) or 0
		if dur > 0 then
			-- replace same id
			for i = #State.events, 1, -1 do
				if State.events[i].id == p.id then
					table.remove(State.events, i)
				end
			end
			table.insert(State.events, {
				id = tostring(p.id or "?"),
				title = tostring(p.title or ""),
				icon = tostring(p.icon or "⚡"),
				endsAt = U.now() + dur,
			})
		end
		State.emit("EventBanner", p)
	end)

	U.on("Request", function(p)
		if type(p.fromUserId) == "number" and type(p.fromName) == "string" then
			U.names[p.fromUserId] = p.fromName
		end
		State.emit("Request", p)
	end)

	for _, name in ipairs({ "Toast", "ViewCam", "Keypad", "Sfx", "Photo" }) do
		U.on(name, function(p)
			State.emit(name, p)
		end)
	end
end

return State
