-- Nav.luau — PathfindingService walker for NPCs (bots + guards + VIP). One coroutine-free
-- state machine per agent, stepped by the owner's loop: Nav.goTo(agent, pos) then Nav.step(agent)
-- every ~0.2 s. Falls back to straight MoveTo when no path can be computed, and re-paths when stuck.
local PathfindingService = game:GetService("PathfindingService")

local Nav = {}

-- agent = { model=Model, hum=Humanoid, root=BasePart, target=Vector3?, waypoints={}, wi=int, lastPos, stuckT, repathAt }
function Nav.new(model)
	return {
		model = model,
		hum = model:FindFirstChildOfClass("Humanoid"),
		root = model:FindFirstChild("HumanoidRootPart"),
		target = nil,
		waypoints = nil,
		wi = 1,
		lastPos = nil,
		stuck = 0,
		arrived = true,
		path = PathfindingService:CreatePath({
			AgentRadius = 2,
			AgentHeight = 5,
			AgentCanJump = true,
			WaypointSpacing = 6,
			Costs = { Water = 20 },
		}),
	}
end

local function flatDist(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

function Nav.goTo(agent, pos, arriveDist)
	if not pos or not agent.root then
		return
	end
	if agent.target and (agent.target - pos).Magnitude < 2 and not agent.arrived then
		return -- already heading there
	end
	agent.target = pos
	agent.arriveDist = arriveDist or 4
	agent.arrived = false
	agent.waypoints = nil
	agent.wi = 1
	agent.stuck = 0
	agent.computing = true
	local ok = pcall(function()
		agent.path:ComputeAsync(agent.root.Position, pos)
	end)
	agent.computing = false
	if agent.target ~= pos then
		return -- superseded while computing
	end
	if ok and agent.path.Status == Enum.PathStatus.Success then
		agent.waypoints = agent.path:GetWaypoints()
		agent.wi = math.min(2, #agent.waypoints)
	else
		agent.waypoints = { { Position = pos, Action = Enum.PathWaypointAction.Walk } }
		agent.wi = 1
	end
end

-- direct chase: skip pathfinding when close and in line of sight
function Nav.chase(agent, pos)
	if not agent.hum or not pos then
		return
	end
	agent.target = pos
	agent.arrived = false
	agent.waypoints = { { Position = pos, Action = Enum.PathWaypointAction.Walk } }
	agent.wi = 1
	agent.hum:MoveTo(pos)
end

function Nav.stop(agent)
	agent.target = nil
	agent.waypoints = nil
	agent.arrived = true
	if agent.hum and agent.root then
		agent.hum:MoveTo(agent.root.Position)
	end
end

-- returns "arrived" | "moving" | "idle"
function Nav.step(agent, dt)
	if not agent.root or not agent.hum or not agent.root.Parent then
		return "idle"
	end
	if agent.arrived or not agent.target then
		return "idle"
	end
	if agent.computing then
		return "moving"
	end
	local pos = agent.root.Position
	if flatDist(pos, agent.target) <= (agent.arriveDist or 4) and math.abs(pos.Y - agent.target.Y) < 8 then
		agent.arrived = true
		agent.hum:MoveTo(pos)
		return "arrived"
	end
	local wps = agent.waypoints
	if not wps or #wps == 0 then
		agent.hum:MoveTo(agent.target)
		return "moving"
	end
	local wp = wps[agent.wi]
	if wp and flatDist(pos, wp.Position) < 3 then
		agent.wi += 1
		wp = wps[agent.wi]
	end
	if not wp then
		agent.hum:MoveTo(agent.target)
	else
		if wp.Action == Enum.PathWaypointAction.Jump then
			agent.hum.Jump = true
		end
		agent.hum:MoveTo(wp.Position)
	end
	-- stuck detection
	if agent.lastPos and (agent.lastPos - pos).Magnitude < 0.3 then
		agent.stuck += dt or 0.2
	else
		agent.stuck = 0
	end
	agent.lastPos = pos
	if agent.stuck > 2.5 then
		agent.stuck = 0
		agent.hum.Jump = true
		local t = agent.target
		agent.target = nil
		task.spawn(Nav.goTo, agent, t, agent.arriveDist)
	end
	return "moving"
end

return Nav
