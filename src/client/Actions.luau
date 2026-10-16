-- Actions.luau: context action buttons stacked above Roblox's jump button (bottom-right):
--   📸 PHOTO  — only while holding a Tool with attribute ItemId == "PhotoCamera" -> Action TakePhoto
--   🫳 DROP   — while holding any Tool -> Action DropItem
--   🙈 HIDE   — while a "Hide" interactable's ProximityPrompt is shown (presses that prompt)
-- Real tap size 64 px on touch (house rule 56-72; 95+ looked far too big on a phone); at most 2 per column, extra columns grow leftwards; the minimap moves left to make room.
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local U = require(script.Parent.Util)
local State = require(script.Parent.State)
local Nav = require(script.Parent.Navigation)

local Actions = {}

local gui: ScreenGui
local btns: { [string]: TextButton } = {}
local order = { "Hide", "Photo", "Drop" }
local hidePrompt: ProximityPrompt? = nil
local lastPhoto = 0
local watched = setmetatable({}, { __mode = "k" }) -- hide prompts whose ActionText we already follow

-- a Hide spot carries 3 prompts (Hide / Stash / Search): only the one the server named "Hide" counts
local function isHidePrompt(p: ProximityPrompt): boolean
	local part = p.Parent
	if not part then
		return false
	end
	return p.Name == "Hide" and part:GetAttribute("Kind") == "Hide"
end

-- the server flips that prompt's ActionText to "Leave" while you're inside
local function hideLabel()
	local p = hidePrompt
	btns.Hide.Text = (p and p.ActionText == "Leave") and "🚪\nLEAVE" or "🙈\nHIDE"
end

local function pressPrompt(p: ProximityPrompt)
	-- InputHoldBegin/End are client-callable and work for both tap and hold prompts
	pcall(function()
		p:InputHoldBegin()
	end)
	task.delay(math.max(0.05, p.HoldDuration + 0.05), function()
		pcall(function()
			p:InputHoldEnd()
		end)
	end)
end

local function doPhoto()
	if os.clock() - lastPhoto < 1.5 then
		return
	end
	lastPhoto = os.clock()
	U.fire("TakePhoto", {})
end

local function doDrop()
	if U.heldTool() then
		U.fire("DropItem", {})
	end
end

local function doHide()
	if hidePrompt and hidePrompt.Parent then
		pressPrompt(hidePrompt)
	end
end

local function layout()
	local k = math.max(U.scale, 0.01)
	local touch = U.isTouch()
	local real = touch and 64 or math.clamp(80 * k, 64, 80)
	local gap = 8
	local jumpTop = U.jumpArea()
	local baseBottom = touch and (jumpTop + 14) or 20
	local baseRight = touch and 14 or 20
	local visible = {}
	for _, n in ipairs(order) do
		if btns[n].Visible then
			table.insert(visible, n)
		end
	end
	for i, n in ipairs(visible) do
		local col = (i - 1) // 2
		local row = (i - 1) % 2
		local b = btns[n]
		b.Size = UDim2.fromOffset(real / k, real / k)
		b.Position = UDim2.new(1, -(baseRight + col * (real + gap)) / k, 1, -(baseBottom + row * (real + gap)) / k)
	end
	local cols = math.ceil(#visible / 2)
	Nav.setRightReserve(cols > 0 and (cols * (real + gap)) or 0)
end

local function setVisible(name: string, on: boolean)
	local b = btns[name]
	if b.Visible == on then
		return
	end
	if on then
		b.Visible = true
		U.popIn(b, 0.4)
	else
		b.Visible = false
	end
	layout()
end

local function refreshTool()
	local t = U.heldTool()
	local detained = State.isDetained()
	setVisible("Drop", t ~= nil and not detained)
	setVisible("Photo", t ~= nil and t:GetAttribute("ItemId") == "PhotoCamera" and not detained)
end

local function watchCharacter(char: Model)
	char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then
			refreshTool()
		end
	end)
	char.ChildRemoved:Connect(function(c)
		if c:IsA("Tool") then
			refreshTool()
		end
	end)
	char:GetAttributeChangedSignal("Hidden"):Connect(function()
		btns.Hide.Text = char:GetAttribute("Hidden") and "🚪\nLEAVE" or "🙈\nHIDE"
	end)
	refreshTool()
end

local function makeButton(name: string, text: string, color: Color3, fn: () -> ()): TextButton
	local b = U.button(gui, text, color, fn, {
		Name = name,
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(96, 96),
		TextScaled = true,
		Visible = false,
	})
	local c = b:FindFirstChildOfClass("UICorner")
	if c then
		c.CornerRadius = UDim.new(1, 0)
	end
	local st = b:FindFirstChildOfClass("UIStroke")
	if st then
		st.Color = U.C.white
		st.Thickness = 3
		st.Transparency = 0.1
	end
	U.pad(b, 8, 8)
	U.gradient(b, Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 190), 90)
	btns[name] = b
	return b
end

function Actions.init()
	gui = U.screen("EHAS_Actions", 6)
	makeButton("Photo", "📸\nPHOTO", Color3.fromRGB(60, 150, 230), doPhoto)
	makeButton("Drop", "🫳\nDROP", Color3.fromRGB(230, 120, 40), doDrop)
	makeButton("Hide", "🙈\nHIDE", Color3.fromRGB(90, 80, 200), doHide)

	-- keyboard shortcuts for PC: F = photo, G = drop (Backspace is Roblox's own unequip)
	ContextActionService:BindAction("EHAS_Photo", function(_, state)
		if state == Enum.UserInputState.Begin and btns.Photo.Visible then
			doPhoto()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F)
	ContextActionService:BindAction("EHAS_Drop", function(_, state)
		if state == Enum.UserInputState.Begin and btns.Drop.Visible then
			doDrop()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.G)
	if not U.isTouch() then
		btns.Photo.Text = "📸\nPHOTO [F]"
		btns.Drop.Text = "🫳\nDROP [G]"
	end

	ProximityPromptService.PromptShown:Connect(function(p)
		if isHidePrompt(p) then
			hidePrompt = p
			hideLabel()
			if not watched[p] then
				watched[p] = true
				p:GetPropertyChangedSignal("ActionText"):Connect(function()
					if hidePrompt == p then
						hideLabel()
					end
				end)
			end
			setVisible("Hide", not State.isDetained())
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(p)
		if p == hidePrompt then
			hidePrompt = nil
			setVisible("Hide", false)
		end
	end)

	if U.player.Character then
		watchCharacter(U.player.Character)
	end
	U.player.CharacterAdded:Connect(watchCharacter)
	State.sig("Detained"):Connect(function()
		refreshTool()
		if State.isDetained() then
			setVisible("Hide", false)
		end
	end)
	U.scaleChanged:Connect(layout)
	UserInputService.LastInputTypeChanged:Connect(function()
		layout()
		Nav.layout()
	end)
	layout()
end

return Actions
