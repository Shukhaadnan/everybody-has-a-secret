-- Investigate.luau: Evidence journal (cards by kind with icons, suspects, incident filter, badge + new-evidence pulse)
-- and Accuse menu (pick incident -> pick suspect from a grid of all participants incl. bots -> confirm -> Action Accuse).
local U = require(script.Parent.Util)
local State = require(script.Parent.State)
local Hud = require(script.Parent.Hud)

local Investigate = {}

local KIND = {
	Footage = { "📹", Color3.fromRGB(255, 90, 110) },
	Footprints = { "👣", Color3.fromRGB(200, 160, 110) },
	Dropped = { "🧤", Color3.fromRGB(255, 170, 60) },
	Missing = { "❓", Color3.fromRGB(255, 220, 80) },
	Witness = { "👁️", Color3.fromRGB(120, 200, 255) },
	AccessLog = { "🔑", Color3.fromRGB(150, 230, 120) },
	BrokenDoor = { "🚪", Color3.fromRGB(255, 120, 60) },
	Transaction = { "💳", Color3.fromRGB(80, 230, 200) },
	Photo = { "📸", Color3.fromRGB(230, 130, 255) },
}
Investigate.KIND = KIND

local gui: ScreenGui
-- journal
local jBack: TextButton
local jPanel: Frame
local jBody: Frame
local jFilterRow: ScrollingFrame
local jList: ScrollingFrame
local jOpen = false
local filter: string? = nil -- incident id, "none" or nil(all)
local unseen = 0

-- accuse
local aBack: TextButton
local aPanel: Frame
local aBody: Frame
local aOpen = false
local pick = { incident = nil :: any, target = nil :: any }

local function incidentTitle(id: string?): string
	if not id then
		return "General"
	end
	for _, i in ipairs(State.incidents) do
		if i.id == id then
			return tostring(i.title or id)
		end
	end
	return tostring(id)
end

-------------------------------------------------------------------------------- journal
local function chip(parent: Instance, text: string, active: boolean, order: number, fn: () -> ())
	local b = U.button(parent, text, active and U.C.gold or U.C.panel2, fn, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 48),
		TextSize = 20,
		LayoutOrder = order,
		TextWrapped = false,
		TextColor3 = active and U.C.dark or U.C.white,
	})
	U.pad(b, 14, 4)
	return b
end

local function evidenceCard(e: any, order: number, fresh: boolean)
	local k = KIND[e.kind] or { "📄", U.C.muted }
	local card = U.frame(jList, {
		Name = "Ev",
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = U.C.panel,
	})
	U.corner(card, 14)
	local st = U.stroke(card, k[2], fresh and 5 or 2)
	U.pad(card, 12, 10)
	local icon = U.label(card, k[1], 40, { Size = UDim2.fromOffset(56, 56), BackgroundTransparency = 0, BackgroundColor3 = U.C.dark, TextWrapped = false })
	U.corner(icon, 12)
	U.stroke(icon, k[2], 2)
	local right = U.frame(card, {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(68, 0),
		Size = UDim2.new(1, -68, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	U.list(right, Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Left)
	U.label(right, string.format("<b>%s</b>  <font color=\"#b0bae0\">· %s · %s</font>", string.upper(tostring(e.kind or "Clue")), U.esc(U.zoneName(e.zone)), U.ago(e.time)), 18, {
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = U.BOLD,
		TextColor3 = k[2],
		LayoutOrder = 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextWrapped = false,
	})
	U.label(right, U.esc(e.text), 22, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
	})
	if e.incident then
		U.label(right, "🧩 " .. U.esc(incidentTitle(e.incident)), 18, {
			Size = UDim2.new(1, 0, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = U.BOLD,
			TextColor3 = U.C.gold,
			LayoutOrder = 3,
		})
	end
	if type(e.suspects) == "table" and #e.suspects > 0 then
		local row = U.frame(right, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 4 })
		U.list(row, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
		U.label(row, "Suspects:", 18, { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 36), Font = U.BOLD, TextColor3 = U.C.muted, TextWrapped = false })
		for i, id in ipairs(e.suspects) do
			local s = U.button(row, "👤 " .. U.esc(U.nameOf(id)), Color3.fromRGB(110, 40, 60), function()
				Investigate.openAccuse(e.incident, id)
			end, {
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 36),
				TextSize = 18,
				LayoutOrder = i,
				TextWrapped = false,
			})
			U.pad(s, 10, 2)
		end
	end
	if fresh then
		task.delay(0.1, function()
			U.tween(st, 1.2, { Thickness = 2 })
		end)
	end
end

local function renderJournal(freshCount: number?)
	if not jList then
		return
	end
	U.clear(jFilterRow)
	U.clear(jList)
	-- filters
	local o = 0
	local function addChip(label: string, val: string?)
		o += 1
		chip(jFilterRow, label, filter == val, o, function()
			filter = val
			renderJournal()
		end)
	end
	addChip("📚 All (" .. #State.evidence .. ")", nil)
	for _, inc in ipairs(State.incidents) do
		local n = 0
		for _, e in ipairs(State.evidence) do
			if e.incident == inc.id then
				n += 1
			end
		end
		addChip((inc.solved and "✅ " or "🧩 ") .. tostring(inc.title) .. " (" .. n .. ")", inc.id)
	end
	-- cards, newest first
	local list = {}
	for i, e in ipairs(State.evidence) do
		if filter == nil or e.incident == filter then
			table.insert(list, { e = e, i = i })
		end
	end
	table.sort(list, function(a, b)
		local ta, tb = tonumber(a.e.time) or 0, tonumber(b.e.time) or 0
		if ta ~= tb then
			return ta > tb
		end
		return a.i > b.i
	end)
	local newest = freshCount or 0
	for idx, it in ipairs(list) do
		evidenceCard(it.e, idx, idx <= newest)
	end
	if #list == 0 then
		U.label(jList, "No evidence yet.\n🔍 Search rooms, check cameras 📹, take photos 📸\nand watch what other guests do!", 26, {
			Size = UDim2.new(1, 0, 0, 160),
			TextColor3 = U.C.muted,
		})
	end
	-- incidents summary
	if #State.incidents > 0 and filter == nil then
		U.label(jList, "🚨 INCIDENTS", 24, {
			LayoutOrder = -100,
			Size = UDim2.new(1, 0, 0, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = U.C.security,
		})
		for i, inc in ipairs(State.incidents) do
			U.label(jList, string.format("%s %s  <font color=\"#b0bae0\">· %s · %s</font>", inc.solved and "✅" or "❗", U.esc(inc.title), U.esc(U.zoneName(inc.zone)), U.ago(inc.time)), 22, {
				LayoutOrder = -100 + i,
				Size = UDim2.new(1, -8, 0, 32),
				TextXAlignment = Enum.TextXAlignment.Left,
				Font = U.BOLD,
			})
		end
	end
end

local function closeJournal()
	if not jOpen then
		return
	end
	jOpen = false
	U.closedModal("Journal")
	U.hideWindow(jBack, jPanel)
end

function Investigate.openJournal()
	if jOpen then
		closeJournal()
		return
	end
	U.openModal("Journal", function()
		jOpen = false
		jBack.Visible = false
	end)
	jOpen = true
	local fresh = unseen
	unseen = 0
	Hud.setBadge("Journal", 0)
	renderJournal(fresh)
	U.showWindow(jBack, jPanel)
end

-------------------------------------------------------------------------------- accuse
local function closeAccuse()
	if not aOpen then
		return
	end
	aOpen = false
	U.closedModal("Accuse")
	U.hideWindow(aBack, aPanel)
end

local renderAccuse: (step: number) -> ()

local function stepTitle(t: string)
	U.label(aBody, t, 28, { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 1, TextColor3 = U.C.gold })
end

renderAccuse = function(step: number)
	U.clear(aBody)
	U.list(aBody, Enum.FillDirection.Vertical, 10)
	if step == 1 then
		stepTitle("1️⃣  WHICH CRIME?")
		local sc = U.scroll(aBody, { Size = UDim2.new(1, 0, 1, -50), LayoutOrder = 2 })
		U.list(sc, Enum.FillDirection.Vertical, 8)
		local any = false
		for i, inc in ipairs(State.incidents) do
			if not inc.solved then
				any = true
				local n = 0
				for _, e in ipairs(State.evidence) do
					if e.incident == inc.id then
						n += 1
					end
				end
				U.button(sc, string.format("🧩 %s\n<font size=\"18\" color=\"#b0bae0\">%s · %d clue%s · %s</font>", U.esc(inc.title), U.esc(U.zoneName(inc.zone)), n, n == 1 and "" or "s", U.ago(inc.time)), Color3.fromRGB(70, 50, 120), function()
					pick.incident = inc
					renderAccuse(2)
				end, { Size = UDim2.new(1, -10, 0, 86), LayoutOrder = i, TextSize = 26 })
			end
		end
		if not any then
			U.label(sc, "No crimes reported yet.\nWhen something goes missing, it shows up here. 🕵️", 26, {
				Size = UDim2.new(1, 0, 0, 120),
				TextColor3 = U.C.muted,
			})
		end
	elseif step == 2 then
		stepTitle("2️⃣  WHO DID IT?  · " .. U.esc(pick.incident and pick.incident.title or ""))
		-- suspect hints from evidence
		local hits: { [number]: number } = {}
		for _, e in ipairs(State.evidence) do
			if pick.incident and e.incident == pick.incident.id and type(e.suspects) == "table" then
				for _, id in ipairs(e.suspects) do
					hits[id] = (hits[id] or 0) + 1
				end
			end
		end
		local sc = U.scroll(aBody, { Size = UDim2.new(1, 0, 1, -116), LayoutOrder = 2 })
		U.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(150, 176),
			CellPadding = UDim2.fromOffset(10, 10),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = sc,
		})
		U.pad(sc, 4, 6)
		local people = U.participants(false)
		table.sort(people, function(a, b)
			local ha, hb = hits[a.id] or 0, hits[b.id] or 0
			if ha ~= hb then
				return ha > hb
			end
			return a.name < b.name
		end)
		for i, p in ipairs(people) do
			local cell = U.new("TextButton", {
				Text = "",
				AutoButtonColor = true,
				BackgroundColor3 = U.C.panel,
				LayoutOrder = i,
				Parent = sc,
			})
			U.corner(cell, 14)
			U.stroke(cell, (hits[p.id] or 0) > 0 and U.C.bad or U.C.line, (hits[p.id] or 0) > 0 and 4 or 2)
			local av = U.avatar(cell, p.id, 92, State.allies[p.id] and U.C.good or U.C.white)
			av.AnchorPoint = Vector2.new(0.5, 0)
			av.Position = UDim2.new(0.5, 0, 0, 10)
			av.Active = false
			local nm = U.label(cell, U.esc(p.name), 20, {
				Position = UDim2.fromOffset(4, 108),
				Size = UDim2.new(1, -8, 0, 30),
				TextScaled = true,
				Font = U.BOLD,
			})
			U.new("UITextSizeConstraint", { MaxTextSize = 20, Parent = nm })
			local sub = (hits[p.id] or 0) > 0 and string.format("🔍 in %d clue%s", hits[p.id], hits[p.id] == 1 and "" or "s")
				or (State.allies[p.id] and "🤝 ally" or (p.isBot and "guest" or "player"))
			U.label(cell, sub, 16, {
				Position = UDim2.fromOffset(4, 140),
				Size = UDim2.new(1, -8, 0, 24),
				TextColor3 = (hits[p.id] or 0) > 0 and U.C.bad or U.C.muted,
				Font = U.BOLD,
			})
			cell.Activated:Connect(function()
				U.sfx("Click", nil, 0.6)
				pick.target = p
				renderAccuse(3)
			end)
		end
		U.button(aBody, "◀ BACK", U.C.panel2, function()
			renderAccuse(1)
		end, { Size = UDim2.new(1, 0, 0, 56), LayoutOrder = 3, TextSize = 24 })
	else
		stepTitle("3️⃣  ARE YOU SURE?")
		local box = U.frame(aBody, { BackgroundColor3 = U.C.panel, Size = UDim2.new(1, 0, 0, 260), LayoutOrder = 2 })
		U.corner(box, 18)
		U.stroke(box, U.C.bad, 3)
		local av = U.avatar(box, pick.target.id, 130, U.C.bad)
		av.AnchorPoint = Vector2.new(0.5, 0)
		av.Position = UDim2.new(0.5, 0, 0, 14)
		U.label(box, string.format("Accuse <b>%s</b>\nof <font color=\"#ffc83d\">%s</font>?", U.esc(pick.target.name), U.esc(pick.incident.title)), 28, {
			Position = UDim2.fromOffset(10, 150),
			Size = UDim2.new(1, -20, 0, 90),
		})
		U.label(aBody, "✅ Right = big coin reward   ❌ Wrong = penalty!", 22, {
			Size = UDim2.new(1, 0, 0, 30),
			TextColor3 = U.C.muted,
			Font = U.BOLD,
			LayoutOrder = 3,
		})
		local row = U.frame(aBody, { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 80), LayoutOrder = 4 })
		U.button(row, "◀ BACK", U.C.panel2, function()
			renderAccuse(2)
		end, { Size = UDim2.new(0.35, -6, 1, 0) })
		U.button(row, "⚖️ ACCUSE!", U.C.bad, function()
			U.fire("Accuse", { targetId = pick.target.id, incident = pick.incident.id })
			U.sfx("VineBoom")
			closeAccuse()
		end, { Position = UDim2.new(0.35, 6, 0, 0), Size = UDim2.new(0.65, -6, 1, 0), TextSize = 34 })
	end
end

function Investigate.openAccuse(incidentId: string?, targetId: number?)
	if aOpen and not incidentId then
		closeAccuse()
		return
	end
	U.openModal("Accuse", function()
		aOpen = false
		aBack.Visible = false
	end)
	aOpen = true
	pick.incident, pick.target = nil, nil
	local step = 1
	if incidentId then
		for _, inc in ipairs(State.incidents) do
			if inc.id == incidentId then
				pick.incident = inc
				step = 2
			end
		end
	end
	if step == 2 and targetId then
		pick.target = { id = targetId, name = U.nameOf(targetId), isBot = targetId < 0 }
		step = 3
	end
	renderAccuse(step)
	U.showWindow(aBack, aPanel)
end

function Investigate.init()
	gui = U.screen("EHAS_Investigate", 22)

	local b, p, c, body = U.window(gui, "🔍 EVIDENCE JOURNAL", 760, 900, Color3.fromRGB(60, 200, 230))
	jBack, jPanel, jBody = b, p, body
	jBack.Activated:Connect(closeJournal)
	c.Activated:Connect(closeJournal)
	jFilterRow = U.scroll(jBody, {
		Size = UDim2.new(1, 0, 0, 60),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 4,
	})
	U.list(jFilterRow, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	jList = U.scroll(jBody, { Position = UDim2.fromOffset(0, 68), Size = UDim2.new(1, 0, 1, -68) })
	U.list(jList, Enum.FillDirection.Vertical, 10)

	local ab, ap, ac, abody = U.window(gui, "⚖️ ACCUSE A SUSPECT", 760, 900, U.C.bad)
	aBack, aPanel, aBody = ab, ap, abody
	aBack.Activated:Connect(closeAccuse)
	ac.Activated:Connect(closeAccuse)

	Hud.open.Journal = Investigate.openJournal
	Hud.open.Accuse = function()
		Investigate.openAccuse(nil, nil)
	end

	State.sig("Evidence"):Connect(function(_list, delta)
		if delta > 0 then
			if jOpen then
				renderJournal(delta)
			else
				unseen += delta
				Hud.setBadge("Journal", unseen)
				Hud.flash("Journal")
			end
		elseif jOpen then
			renderJournal()
		end
	end)
	State.sig("Incident"):Connect(function()
		local open = 0
		for _, inc in ipairs(State.incidents) do
			if not inc.solved then
				open += 1
			end
		end
		Hud.setBadge("Accuse", open)
		if jOpen then
			renderJournal()
		end
	end)
	State.sig("Phase"):Connect(function(phase)
		if phase == "Lobby" or phase == "Intro" then
			unseen = 0
			filter = nil
			Hud.setBadge("Journal", 0)
			Hud.setBadge("Accuse", 0)
		end
		if phase == "Reveal" then
			closeJournal()
			closeAccuse()
		end
	end)
end

return Investigate
