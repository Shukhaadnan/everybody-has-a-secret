--!nocheck
-- Arcade.luau: the skill minigame for arcade machines / game tables (replaces the old slots & cards, which were
-- gambling). A needle sweeps a bar; tap STOP (or press Space / click) when it's in the green zone. FREE to play;
-- the server decides the result from its own clock, the client only draws the needle and sends "stop".
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local U = require(script.Parent.Util)

local Arcade = {}

local gui: ScreenGui
local panel: Frame
local titleL: TextLabel
local bar: Frame
local zone: Frame
local sweet: Frame
local needle: Frame
local resultL: TextLabel
local hintL: TextLabel
local stopBtn: TextButton

local run = nil -- { t0, period, center, width, stopped }
local conn: RBXScriptConnection? = nil

local function pos(e: number, period: number): number
	local ph = (e / period) % 2
	return ph < 1 and ph or 2 - ph
end

local function hide(after: number?)
	task.delay(after or 0, function()
		if run and not run.stopped then
			return -- a new run started meanwhile
		end
		if panel.Visible then
			U.popOut(panel)
		end
	end)
end

local function stop()
	if not run or run.stopped then
		return
	end
	run.stopped = true
	if conn then
		conn:Disconnect()
		conn = nil
	end
	U.fire("ArcadeStop", {})
	U.sfx("Click", nil, 0.8)
	hintL.Text = "..."
end

local function start(p)
	run = { t0 = os.clock(), period = tonumber(p.period) or 1, center = tonumber(p.center) or 0.5, width = tonumber(p.width) or 0.15 }
	titleL.Text = tostring(p.title or "🕹️ ARCADE")
	zone.Size = UDim2.fromScale(run.width, 1)
	zone.Position = UDim2.fromScale(run.center, 0.5)
	sweet.Size = UDim2.fromScale(1 / 3, 1)
	resultL.Text = ""
	hintL.Text = string.format("Stop in the green zone! Win %d 🪙 (center = %d 🪙)", tonumber(p.hit) or 0, tonumber(p.perfect) or 0)
	needle.Position = UDim2.fromScale(0, 0.5)
	U.popIn(panel, 0.7)
	U.sfx("SlotSpin", nil, 0.5)
	if conn then
		conn:Disconnect()
	end
	local myRun = run
	conn = RunService.RenderStepped:Connect(function()
		if run ~= myRun or myRun.stopped then
			return
		end
		local e = os.clock() - myRun.t0
		needle.Position = UDim2.fromScale(pos(e, myRun.period), 0.5)
		if e > 7 then
			stop()
		end
	end)
end

local function result(p)
	if not run then
		return
	end
	run.stopped = true
	if p.perfect then
		resultL.Text = string.format("⭐ PERFECT! +%d 🪙", tonumber(p.payout) or 0)
		resultL.TextColor3 = U.C.gold
	elseif p.hit then
		resultL.Text = string.format("✅ NICE! +%d 🪙", tonumber(p.payout) or 0)
		resultL.TextColor3 = U.C.good
	else
		resultL.Text = "❌ MISSED! Try again"
		resultL.TextColor3 = U.C.bad
	end
	hintL.Text = ""
	U.pulse(resultL, 0.3)
	hide(1.3)
end

function Arcade.init()
	gui = U.screen("EHAS_Arcade", 30, 0.6)
	panel = U.frame(gui, {
		Name = "Arcade",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(560, 230),
		BackgroundColor3 = U.C.bg,
		BackgroundTransparency = 0.08,
		Visible = false,
	})
	U.corner(panel, 20)
	U.stroke(panel, U.C.gold, 3)
	titleL = U.label(panel, "🕹️ ARCADE", 30, {
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 36),
		TextColor3 = U.C.gold,
	})
	U.textStroke(titleL, 2)
	bar = U.frame(panel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.new(1, -60, 0, 40),
		BackgroundColor3 = U.C.dark,
		ClipsDescendants = false,
	})
	U.corner(bar, 10)
	U.stroke(bar, U.C.line, 2)
	zone = U.frame(bar, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = U.C.good,
		BackgroundTransparency = 0.15,
	})
	U.corner(zone, 6)
	sweet = U.frame(zone, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = U.C.gold,
	})
	U.corner(sweet, 4)
	needle = U.frame(bar, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 8, 1, 18),
		BackgroundColor3 = U.C.white,
		ZIndex = 3,
	})
	U.corner(needle, 4)
	U.stroke(needle, U.C.dark, 2)
	resultL = U.label(panel, "", 32, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 100),
		Size = UDim2.new(1, -20, 0, 40),
	})
	U.textStroke(resultL, 2)
	hintL = U.label(panel, "", 18, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 104),
		Size = UDim2.new(1, -20, 0, 26),
		Font = U.BOLD,
		TextColor3 = U.C.muted,
	})
	stopBtn = U.button(panel, "STOP!", U.C.bad, stop, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(220, 62),
		TextSize = 32,
	})

	-- keyboard / click anywhere also stops (phones use the big button)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not (run and not run.stopped and panel.Visible) then
			return
		end
		local k = input.KeyCode
		if k == Enum.KeyCode.Space or k == Enum.KeyCode.ButtonA then
			stop()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and not processed then
			stop()
		end
	end)

	U.on("Arcade", function(p)
		if p.start then
			start(p)
		elseif p.result then
			result(p)
		end
	end)
end

return Arcade
