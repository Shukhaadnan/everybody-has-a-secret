-- Tutorial.luau: first-time player overlay (when YourSecret.tutorial == true). Five steps:
--   1 Read your secret   2 Find the arcade (follow the arrow)   3 Play a game table (press the prompt)
--   4 Complete!          5 Reward   -> fires Action("TutorialDone").
-- Small coach panel at the bottom-center; never covers the middle of the screen.
local ProximityPromptService = game:GetService("ProximityPromptService")

local U = require(script.Parent.Util)
local State = require(script.Parent.State)
local Hud = require(script.Parent.Hud)

local Tutorial = {}

local gui: ScreenGui
local coach: Frame
local stepL: TextLabel
local textL: TextLabel
local dots: { Frame } = {}
local active = false
local step = 0
local skipBtn: TextButton

local STEPS = {
	{ "🔒", "Your SECRET", "Everybody has a secret mission. It's under 🔒 SECRET (bottom-left) if you forget." },
	{ "🕹️", "Find the ARCADE", "Follow the glowing arrow ⬆ and the ⭐ on your minimap." },
	{ "🎯", "Play a GAME TABLE", "Walk up to a game table, press the prompt, then hit STOP in the green!" },
	{ "✅", "COMPLETE!", "Secret done! In real rounds, secrets are sneakier... 🤫" },
	{ "💰", "REWARD", "Completing secrets gives coins & XP. Now — the real game begins!" },
}

local function setStep(n: number)
	if n <= step then
		return
	end
	step = n
	local s = STEPS[n]
	if not s then
		return
	end
	stepL.Text = string.format("%s  STEP %d/5 · %s", s[1], n, string.upper(s[2]))
	textL.Text = s[3]
	for i, d in ipairs(dots) do
		U.tween(d, 0.3, { BackgroundColor3 = i < n and U.C.good or (i == n and U.C.gold or U.C.panel2) })
	end
	U.pulse(coach, 0.08)
	U.sfx(n >= 4 and "Complete" or "Progress", nil, 0.7)
	if n == 1 then
		Hud.flash("Secret")
	elseif n == 4 then
		task.delay(2.5, function()
			setStep(5)
		end)
	elseif n == 5 then
		U.sfx("CoinGet")
		task.delay(4, function()
			Tutorial.finish()
		end)
	end
end

function Tutorial.finish()
	if not active then
		return
	end
	active = false
	U.fire("TutorialDone", {})
	U.tween(coach, 0.35, { Position = UDim2.new(0.5, 0, 1, 300) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.4, function()
		coach.Visible = false
	end)
end

function Tutorial.start()
	if active then
		return
	end
	active = true
	step = 0
	coach.Visible = true
	coach.Position = UDim2.new(0.5, 0, 1, 300)
	U.tween(coach, 0.45, { Position = UDim2.new(0.5, 0, 1, -16) }, Enum.EasingStyle.Back)
	setStep(1)
end

local function mainObj(): any
	local s = State.secret
	return s and type(s.main) == "table" and s.main or nil
end

function Tutorial.init()
	gui = U.screen("EHAS_Tutorial", 28, 0.62)
	coach = U.frame(gui, {
		Name = "Coach",
		-- bottom-center: between the thumbstick and the jump button, away from toasts/timer
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(560, 150),
		BackgroundColor3 = U.C.bg,
		Visible = false,
	})
	U.corner(coach, 18)
	U.stroke(coach, U.C.gold, 4)
	U.gradient(coach, Color3.fromRGB(60, 50, 110), Color3.fromRGB(24, 22, 46), 90)
	U.label(coach, "🎓 TUTORIAL", 16, {
		Position = UDim2.fromOffset(16, 6),
		Size = UDim2.new(1, -140, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = U.BOLD,
		TextColor3 = U.C.muted,
	})
	stepL = U.label(coach, "", 26, {
		Position = UDim2.fromOffset(16, 26),
		Size = UDim2.new(1, -32, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = U.C.gold,
		TextScaled = true,
	})
	U.new("UITextSizeConstraint", { MaxTextSize = 28, Parent = stepL })
	textL = U.label(coach, "", 20, {
		Position = UDim2.fromOffset(16, 62),
		Size = UDim2.new(1, -32, 0, 52),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = U.BOLD,
		TextScaled = true,
	})
	U.new("UITextSizeConstraint", { MaxTextSize = 22, Parent = textL })
	local dotRow = U.frame(coach, {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 16, 1, -26),
		Size = UDim2.new(1, -160, 0, 16),
	})
	U.list(dotRow, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	for i = 1, 5 do
		local d = U.frame(dotRow, { Size = UDim2.fromOffset(40, 12), BackgroundColor3 = U.C.panel2, LayoutOrder = i })
		U.round(d)
		dots[i] = d
	end
	skipBtn = U.button(coach, "SKIP", U.C.panel2, function()
		Tutorial.finish()
	end, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -10),
		Size = UDim2.fromOffset(110, 48),
		TextSize = 22,
	})

	local function layout()
		local vp = U.viewport()
		local hs = gui:FindFirstChild("HudScale")
		local k = math.max(hs and hs.Scale or U.scale, 0.01)
		-- phones: coach spans most of the width so its text can be big (desktop keeps 44%)
		local w = math.min(560, (vp.X * (U.isTouch() and 0.62 or 0.44)) / k)
		coach.Size = UDim2.fromOffset(w, 150)
	end
	U.scaleChanged:Connect(layout)
	layout()

	State.sig("YourSecret"):Connect(function(s)
		if s.tutorial == true then
			Tutorial.start()
		elseif active then
			-- a real secret arrived: tutorial is over
			Tutorial.finish()
		end
	end)
	-- 1 -> 2 when the player closes the secret card
	State.sig("SecretClosed"):Connect(function()
		if active and step == 1 then
			setStep(2)
		end
	end)
	-- 2 -> 3 when entering the hint zone (casino)
	State.sig("Zone"):Connect(function(z)
		local o = mainObj()
		if active and step <= 2 and z ~= nil and (z == (o and o.hintZone) or z == "Casino") then
			setStep(2)
			setStep(3)
		end
	end)
	-- 3: a prompt near the dealer appears -> highlight
	ProximityPromptService.PromptShown:Connect(function(p)
		-- only coach on the game-table / arcade prompts (it used to echo "Bribe (50 🪙)" or a door prompt)
		if active and step == 3 and (string.find(p.ActionText, "Play", 1, true) or p.ObjectText == "Game Table") then
			textL.Text = "Press  [" .. (U.isTouch() and "TAP" or p.KeyboardKeyCode.Name) .. "]  on the prompt: " .. p.ActionText
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function()
		if active and step == 3 then
			textL.Text = "Nice! Now hit STOP when the needle is in the green!"
		end
	end)
	-- 4 when the objective is done
	State.sig("SecretProgress"):Connect(function(slot, obj)
		if not active then
			return
		end
		if slot == "main" and obj.done then
			setStep(2)
			setStep(3)
			setStep(4)
		elseif slot == "main" and (tonumber(obj.step) or 0) >= 2 then
			setStep(3)
		end
	end)
	State.sig("Rewards"):Connect(function()
		if active then
			setStep(5)
		end
	end)
	-- round over before the tutorial secret was done: take the coach down for the reveal
	State.sig("Phase"):Connect(function(ph)
		if ph == "Reveal" and active and step < 4 then
			Tutorial.finish()
		end
	end)
	local _ = skipBtn
end

function Tutorial.isActive(): boolean
	return active
end

return Tutorial
