-- Security.luau: Security monitor UI (camera list -> ViewCam, footage list with DELETE, logs, DISABLE CAM),
-- CCTV camera view (Scriptable camera, scanlines, REC dot, timestamp, CLOSE -> CloseMonitor) and the 4-digit Keypad.
local RunService = game:GetService("RunService")

local U = require(script.Parent.Util)
local State = require(script.Parent.State)

local Security = {}

local gui: ScreenGui
local mBack: TextButton
local mPanel: Frame
local mBody: Frame
local mOpen = false
local tab = "Cams"

local cctv: Frame
local cctvTitle: TextLabel
local cctvClock: TextLabel
local recDot: Frame
local viewing = false
local savedCam: { type: Enum.CameraType, subject: Instance?, cf: CFrame, fov: number }? = nil

-------------------------------------------------------------------------------- CCTV view
local function restoreCamera()
	local cam = workspace.CurrentCamera
	if cam and savedCam then
		cam.CameraType = savedCam.type == Enum.CameraType.Scriptable and Enum.CameraType.Custom or savedCam.type
		-- after a respawn the saved Humanoid is destroyed: follow the new character instead
		local subj = savedCam.subject
		if not (subj and subj:IsDescendantOf(workspace)) then
			subj = U.player.Character and U.player.Character:FindFirstChildOfClass("Humanoid")
		end
		cam.CameraSubject = subj
		cam.FieldOfView = savedCam.fov
	elseif cam then
		cam.CameraType = Enum.CameraType.Custom
	end
	savedCam = nil
end

local function stopView(notify: boolean)
	if not viewing then
		return
	end
	viewing = false
	RunService:UnbindFromRenderStep("EHAS_CCTV")
	restoreCamera()
	U.tween(cctv, 0.2, { BackgroundTransparency = 1 })
	cctv.Visible = false
	if notify then
		U.fire("CloseMonitor", {})
	end
end

local function startView(camId: string, cf: CFrame)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	-- monitor list hides while watching (it's a modal); remember to reopen
	if mOpen then
		mOpen = false
		U.closedModal("Monitor")
		mBack.Visible = false
	end
	if not viewing then
		savedCam = { type = cam.CameraType, subject = cam.CameraSubject, cf = cam.CFrame, fov = cam.FieldOfView }
	end
	viewing = true
	local name = camId
	local m = State.monitor
	if m and type(m.cams) == "table" then
		for _, c in ipairs(m.cams) do
			if c.id == camId then
				name = tostring(c.name or camId)
			end
		end
	end
	cctvTitle.Text = "📹 CAM · " .. string.upper(U.esc(name))
	cctv.Visible = true
	cctv.BackgroundTransparency = 0
	cctv.BackgroundColor3 = Color3.new(1, 1, 1)
	U.tween(cctv, 0.25, { BackgroundTransparency = 1 })
	U.sfx("Click")
	local t0 = os.clock()
	RunService:BindToRenderStep("EHAS_CCTV", Enum.RenderPriority.Camera.Value + 2, function()
		local c = workspace.CurrentCamera
		if not c then
			return
		end
		c.CameraType = Enum.CameraType.Scriptable
		c.FieldOfView = 70
		-- slow pan like a real security cam
		local sway = math.sin((os.clock() - t0) * 0.35) * math.rad(10)
		c.CFrame = cf * CFrame.Angles(0, sway, 0)
		local tm = os.date("!*t", math.floor(U.now()))
		cctvClock.Text = string.format("%02d:%02d:%02d  ● LIVE", tm.hour, tm.min, tm.sec)
		recDot.BackgroundTransparency = (math.floor(os.clock() * 2) % 2 == 0) and 0 or 0.8
	end)
end

local function buildCCTV()
	cctv = U.frame(gui, {
		Name = "CCTV",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 5,
	})
	-- scanlines
	local lines = U.frame(cctv, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, ClipsDescendants = true })
	for i = 0, 40 do
		U.frame(lines, {
			Position = UDim2.fromScale(0, i / 40),
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.82,
			ZIndex = 5,
		})
	end
	local tint = U.frame(cctv, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(30, 120, 60), BackgroundTransparency = 0.88, ZIndex = 5 })
	local _ = tint
	-- corner brackets
	for _, a in ipairs({ Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) }) do
		local f = U.frame(cctv, {
			AnchorPoint = a,
			Position = UDim2.new(a.X, a.X == 0 and 30 or -30, a.Y, a.Y == 0 and 30 or -30),
			Size = UDim2.fromOffset(70, 70),
			BackgroundTransparency = 1,
			ZIndex = 6,
		})
		U.stroke(f, Color3.new(1, 1, 1), 4, 0.2)
	end
	recDot = U.frame(cctv, {
		Position = UDim2.fromOffset(60, 60),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Color3.fromRGB(255, 30, 30),
		ZIndex = 7,
	})
	U.round(recDot)
	local rec = U.label(cctv, "REC", 30, {
		Position = UDim2.fromOffset(96, 54),
		Size = UDim2.fromOffset(100, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = U.BOLD,
		ZIndex = 7,
	})
	U.textStroke(rec, 2)
	cctvTitle = U.label(cctv, "📹 CAM", 30, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 100),
		Size = UDim2.fromOffset(600, 40),
		Font = U.BOLD,
		ZIndex = 7,
	})
	U.textStroke(cctvTitle, 2)
	cctvClock = U.label(cctv, "00:00:00", 28, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -60, 1, -60),
		Size = UDim2.fromOffset(360, 40),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = U.BOLD,
		ZIndex = 7,
	})
	U.textStroke(cctvClock, 2)
	local row = U.frame(cctv, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 60, 1, -60),
		Size = UDim2.fromOffset(460, 80),
		BackgroundTransparency = 1,
		ZIndex = 7,
	})
	U.list(row, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left)
	U.button(row, "✖ CLOSE", U.C.bad, function()
		stopView(true)
	end, { Size = UDim2.fromOffset(200, 80), ZIndex = 8, LayoutOrder = 1 })
	U.button(row, "📺 CAMERAS", U.C.panel2, function()
		-- back to the camera list without leaving the monitor
		viewing = false
		RunService:UnbindFromRenderStep("EHAS_CCTV")
		restoreCamera()
		cctv.Visible = false
		Security.openMonitor()
	end, { Size = UDim2.fromOffset(230, 80), ZIndex = 8, LayoutOrder = 2 })
end

-------------------------------------------------------------------------------- monitor
local render: () -> ()

local function tabButton(parent: Instance, name: string, label: string, order: number)
	U.button(parent, label, tab == name and U.C.gold or U.C.panel2, function()
		tab = name
		render()
	end, {
		Size = UDim2.new(1 / 3, -6, 1, 0),
		LayoutOrder = order,
		TextSize = 24,
		TextColor3 = tab == name and U.C.dark or U.C.white,
	})
end

render = function()
	U.clear(mBody)
	local m = State.monitor or {}
	local tabs = U.frame(mBody, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56) })
	U.list(tabs, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	tabButton(tabs, "Cams", "📹 Cameras", 1)
	tabButton(tabs, "Footage", "🎞️ Footage", 2)
	tabButton(tabs, "Logs", "📋 Logs", 3)
	local sc = U.scroll(mBody, { Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 1, -66) })
	U.list(sc, Enum.FillDirection.Vertical, 8)
	if tab == "Cams" then
		local cams = type(m.cams) == "table" and m.cams or {}
		for i, c in ipairs(cams) do
			local row = U.frame(sc, { BackgroundColor3 = U.C.panel, Size = UDim2.new(1, -8, 0, 76), LayoutOrder = i })
			U.corner(row, 12)
			U.stroke(row, c.online and U.C.good or U.C.bad, 2)
			U.label(row, string.format("%s %s", c.online and "🟢" or "🔴", U.esc(c.name or c.id)), 24, {
				Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(1, -330, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextScaled = true,
			})
			U.button(row, "👁 VIEW", Color3.fromRGB(40, 140, 200), function()
				if c.online ~= false then
					U.fire("ViewCam", { camId = c.id })
				else
					U.sfx("Locked")
				end
			end, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, m.canDisable and -168 or -10, 0.5, 0),
				Size = UDim2.fromOffset(150, 60),
				TextSize = 24,
				BackgroundTransparency = c.online == false and 0.6 or 0,
			})
			if m.canDisable then
				U.button(row, c.online and "⛔ DISABLE" or "OFF", U.C.bad, function()
					if c.online then
						U.fire("DisableCam", { camId = c.id })
					end
				end, {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -10, 0.5, 0),
					Size = UDim2.fromOffset(150, 60),
					TextSize = 22,
					BackgroundTransparency = c.online and 0 or 0.6,
				})
			end
		end
		if #cams == 0 then
			U.label(sc, "No cameras found.", 24, { TextColor3 = U.C.muted })
		end
	elseif tab == "Footage" then
		local list = type(m.footage) == "table" and m.footage or {}
		for i, f in ipairs(list) do
			local row = U.frame(sc, { BackgroundColor3 = U.C.panel, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = i })
			U.corner(row, 12)
			U.stroke(row, f.deleted and U.C.muted or Color3.fromRGB(255, 90, 110), 2)
			U.pad(row, 12, 10)
			U.label(row, string.format("%s %s  <font color=\"#b0bae0\">%s</font>", f.deleted and "🗑️" or "🎞️", f.deleted and "<s>" .. U.esc(f.text) .. "</s>" or U.esc(f.text), U.ago(f.time)), 22, {
				Size = UDim2.new(1, (m.canDelete and not f.deleted) and -170 or 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTransparency = f.deleted and 0.4 or 0,
			})
			if m.canDelete and not f.deleted then
				U.button(row, "🗑 DELETE", U.C.bad, function()
					U.fire("DeleteFootage", { id = f.id })
					U.sfx("Whoosh", nil, 0.5)
				end, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, 0),
					Size = UDim2.fromOffset(160, 56),
					TextSize = 22,
				})
			end
		end
		if #list == 0 then
			U.label(sc, "No recorded footage yet.", 24, { TextColor3 = U.C.muted })
		end
		if not m.canDelete then
			U.label(sc, "🔒 You need access to delete footage.", 20, { TextColor3 = U.C.muted, LayoutOrder = 999, Font = U.BOLD })
		end
	else
		local logs = type(m.logs) == "table" and m.logs or {}
		for i = #logs, 1, -1 do
			local l = logs[i]
			U.label(sc, string.format("<font color=\"#7fd8ff\">[%s]</font> %s", U.ago(l.time), U.esc(l.text)), 22, {
				Size = UDim2.new(1, -8, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = U.BOLD,
				LayoutOrder = #logs - i + 1,
			})
		end
		if #logs == 0 then
			U.label(sc, "Access log is empty.", 24, { TextColor3 = U.C.muted })
		end
	end
end

local function closeMonitor(sendClose: boolean)
	if not mOpen then
		return
	end
	mOpen = false
	U.closedModal("Monitor")
	U.hideWindow(mBack, mPanel)
	if sendClose then
		U.fire("CloseMonitor", {})
	end
end

function Security.openMonitor()
	U.openModal("Monitor", function()
		mOpen = false
		mBack.Visible = false
		-- closed by another window (journal/shop/secret): stop server refreshes re-opening the monitor
		if not viewing then
			U.fire("CloseMonitor", {})
		end
	end)
	if not mOpen then
		mOpen = true
		U.showWindow(mBack, mPanel)
	end
	render()
end

-------------------------------------------------------------------------------- keypad
local kBack: TextButton
local kPanel: Frame
local kDisplay: TextLabel
local kOpen = false
local kDoor: string? = nil
local kCode = ""

local function closeKeypad()
	if not kOpen then
		return
	end
	kOpen = false
	U.closedModal("Keypad")
	U.hideWindow(kBack, kPanel)
end

local function updDisplay()
	local s = ""
	for i = 1, 4 do
		s ..= (i <= #kCode) and string.sub(kCode, i, i) or "•"
		if i < 4 then
			s ..= " "
		end
	end
	kDisplay.Text = s
end

local function press(key: string)
	if key == "C" then
		kCode = ""
	elseif key == "OK" then
		if #kCode == 4 and kDoor then
			U.fire("EnterCode", { doorId = kDoor, code = kCode })
			kDisplay.TextColor3 = U.C.gold
			task.delay(0.25, closeKeypad)
		else
			U.sfx("Locked")
			local p = kPanel
			for i = 1, 4 do
				p.Position = UDim2.new(0.5, (i % 2 == 0) and 10 or -10, 0.5, 0)
				task.wait(0.04)
			end
			p.Position = UDim2.fromScale(0.5, 0.5)
		end
	elseif #kCode < 4 then
		kCode ..= key
	end
	updDisplay()
end

function Security.openKeypad(doorId: string)
	kDoor = doorId
	kCode = ""
	updDisplay()
	kDisplay.TextColor3 = U.C.good
	U.openModal("Keypad", function()
		kOpen = false
		kBack.Visible = false
	end)
	kOpen = true
	U.showWindow(kBack, kPanel)
end

local function buildKeypad()
	local b, p, c, body = U.window(gui, "🔢 ENTER CODE", 420, 700, Color3.fromRGB(80, 200, 140))
	kBack, kPanel = b, p
	kBack.Activated:Connect(closeKeypad)
	c.Activated:Connect(closeKeypad)
	kDisplay = U.label(body, "• • • •", 60, {
		Size = UDim2.new(1, 0, 0, 84),
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(8, 20, 12),
		TextColor3 = U.C.good,
		Font = Enum.Font.Code,
	})
	U.corner(kDisplay, 12)
	U.stroke(kDisplay, U.C.good, 2)
	local grid = U.frame(body, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 1, -96) })
	U.new("UIGridLayout", {
		CellSize = UDim2.new(1 / 3, -8, 0.25, -8),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	local keys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "OK" }
	for i, k in ipairs(keys) do
		local col = (k == "C") and U.C.bad or ((k == "OK") and U.C.good or U.C.panel2)
		U.button(grid, k, col, function()
			press(k)
		end, { LayoutOrder = i, TextSize = 40 })
	end
end

function Security.init()
	gui = U.screen("EHAS_Security", 24)
	buildCCTV()
	local b, p, c, body = U.window(gui, "🖥️ SECURITY MONITOR", 780, 900, Color3.fromRGB(80, 200, 255))
	mBack, mPanel, mBody = b, p, body
	mBack.Activated:Connect(function()
		closeMonitor(true)
	end)
	c.Activated:Connect(function()
		closeMonitor(true)
	end)
	buildKeypad()

	State.sig("Monitor"):Connect(function()
		if viewing then
			return -- data refresh while watching; list updates when we return
		end
		if mOpen then
			-- refresh in place and keep the scroll position (no jump to the top under the player's thumb)
			local sc = mBody:FindFirstChildOfClass("ScrollingFrame")
			local y = sc and sc.CanvasPosition.Y or 0
			render()
			local sc2 = mBody:FindFirstChildOfClass("ScrollingFrame")
			if sc2 then
				task.defer(function()
					sc2.CanvasPosition = Vector2.new(0, y)
				end)
			end
		else
			Security.openMonitor()
		end
	end)
	State.sig("ViewCam"):Connect(function(p)
		if typeof(p.cframe) == "CFrame" then
			startView(tostring(p.camId or "?"), p.cframe)
		end
	end)
	State.sig("Keypad"):Connect(function(p)
		if p.doorId then
			Security.openKeypad(tostring(p.doorId))
		end
	end)
	State.sig("Detained"):Connect(function(untilTime)
		if untilTime > U.now() then
			stopView(true)
			closeMonitor(false)
			closeKeypad()
		end
	end)
	State.sig("Phase"):Connect(function(phase)
		if phase ~= "Play" then
			stopView(false)
			closeMonitor(false)
			closeKeypad()
		end
	end)
	U.player.CharacterAdded:Connect(function()
		stopView(false)
	end)
end

function Security.isViewing(): boolean
	return viewing
end

return Security
