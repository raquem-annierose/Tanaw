--!strict
-- Patong: a falling-block game in the phone.
--
-- Menu:        Single Player or Multiplayer.
-- Multiplayer: host a room, or join one hosted within Patong.JoinDistance studs of you. The host
--              taps Start once 2 or more players are in (PatongController / PatongService).
-- Game:        your board, the next piece, score and rows, and in versus the small boards of the
--              others. Clearing 2+ rows with one piece sends grey rows to another player; the red
--              bar left of the board shows rows coming your way. Last one still playing wins.
--
-- Controls: the buttons under the board (hold ◀ ▶ ▼ to repeat). Keyboard, while the game is on
-- screen: ←/→ or A/D move, ↓/S drop faster, ↑/W/X/C turn, Z turn back, Space drop.
-- Single player pauses while the phone is closed or another app is open; versus keeps going.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Patong = require(ReplicatedStorage.Shared.Patong)
local PatongController = require(script.Parent.Parent.Parent.controllers.PatongController)
local PatongGame = require(ReplicatedStorage.Shared.PatongGame)
local PhoneUi = require(script.Parent.PhoneUi)

type Board = PatongGame.PatongGame
-- "Left" | "Right" | "Down" | "Rotate" | "RotateBack" | "Drop"
type Control = string

local WIDTH = Patong.Width
local HEIGHT = Patong.Height
-- Layout of the game screen inside the app page (280 x 528).
local CELL = 19
local BOARD_X = 14
local BOARD_Y = 46
local SIDE_X = 212
local SIDE_WIDTH = 58
local CONTROLS_Y = 436
local PREVIEW_CELL = 12
local MINI_CELL = 3
-- Hold a button or key this long before it repeats, then repeat this often (seconds).
local REPEAT_DELAY = 0.17
local REPEAT_RATE = 0.05
local SOFT_DROP_RATE = 0.04
local ACTION = "PatongControls"

-- Piece colors from the overlook at dusk. Index = cell value (1-7 pieces, 8 garbage).
local COLORS: { Color3 } = {
	Color3.fromRGB(120, 200, 235), -- line: sky
	Color3.fromRGB(255, 200, 120), -- square: string lights
	Color3.fromRGB(176, 120, 220), -- T: dusk purple
	Color3.fromRGB(130, 210, 160), -- S: leaves
	Color3.fromRGB(240, 110, 120), -- Z: coral
	Color3.fromRGB(110, 140, 240), -- J: blue hour
	Color3.fromRGB(255, 150, 90), -- L: sunset orange
	Color3.fromRGB(120, 118, 134), -- garbage
}
local WARNING = Color3.fromRGB(240, 80, 90)
-- The landing shadow is the piece's color, mostly see-through. Its value is GHOST + piece.
local GHOST = 10

local KEYS: { [Enum.KeyCode]: Control } = {
	[Enum.KeyCode.Left] = "Left",
	[Enum.KeyCode.A] = "Left",
	[Enum.KeyCode.Right] = "Right",
	[Enum.KeyCode.D] = "Right",
	[Enum.KeyCode.Down] = "Down",
	[Enum.KeyCode.S] = "Down",
	[Enum.KeyCode.Up] = "Rotate",
	[Enum.KeyCode.W] = "Rotate",
	[Enum.KeyCode.X] = "Rotate",
	[Enum.KeyCode.C] = "Rotate",
	[Enum.KeyCode.Z] = "RotateBack",
	[Enum.KeyCode.Space] = "Drop",
}
-- Controls that repeat while held: first repeat delay, then the repeat rate.
local REPEATS: { [Control]: { first: number, rate: number } } = {
	Left = { first = REPEAT_DELAY, rate = REPEAT_RATE },
	Right = { first = REPEAT_DELAY, rate = REPEAT_RATE },
	Down = { first = SOFT_DROP_RATE, rate = SOFT_DROP_RATE },
}
local BUTTONS: { { control: Control, text: string } } = {
	{ control = "Left", text = "◀" },
	{ control = "Right", text = "▶" },
	{ control = "Down", text = "▼" },
	{ control = "Rotate", text = "TURN" },
	{ control = "Drop", text = "DROP" },
}

type Opponent = { cells: { Frame }, name: TextLabel }
type OverlayButton = { text: string, onClick: () -> () }

local PatongApp = {}

-- Set in build: runs when the app comes on or off screen.
local activeChanged: () -> () = function() end
local onScreen = false

-- A pill button like the Music app's, but full width.
local function wideButton(
	name: string,
	parent: Instance,
	text: string,
	primary: boolean
): TextButton
	local b = PhoneUi.button(name, parent)
	b.Size = UDim2.new(1, -32, 0, 46)
	b.Position = UDim2.fromOffset(16, 0)
	b.BackgroundColor3 = PhoneUi.WHITE
	b.BackgroundTransparency = if primary then 0 else 0.86
	b.TextColor3 = if primary then PhoneUi.INK else PhoneUi.WHITE
	b.TextSize = 17
	b.Text = text
	PhoneUi.corner(b)
	return b
end

local function heading(name: string, parent: Instance, text: string): TextLabel
	local l = PhoneUi.label(name, parent, text, 12)
	l.Size = UDim2.new(1, -32, 0, 20)
	l.Position = UDim2.fromOffset(16, 0)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTransparency = 0.45
	return l
end

local function note(name: string, parent: Instance, text: string): TextLabel
	local l = PhoneUi.label(name, parent, text, 14)
	l.Size = UDim2.new(1, -32, 0, 40)
	l.Position = UDim2.fromOffset(16, 0)
	l.FontFace = PhoneUi.FONT_REGULAR
	l.TextWrapped = true
	l.TextTransparency = 0.3
	return l
end

-- A grid of square cells inside `parent`; cells[(row - 1) * columns + column].
local function cellGrid(
	parent: Frame,
	columns: number,
	rows: number,
	size: number,
	gap: number
): { Frame }
	local cells = table.create(columns * rows)
	for row = 1, rows do
		for column = 1, columns do
			local c = PhoneUi.frame(`{column},{row}`, parent)
			c.Position = UDim2.fromOffset((column - 1) * size + gap, (row - 1) * size + gap)
			c.Size = UDim2.fromOffset(size - gap * 2, size - gap * 2)
			c.BackgroundColor3 = PhoneUi.WHITE
			table.insert(cells, c)
		end
	end
	return cells
end

local function paint(cell: Frame, value: number, emptyTransparency: number)
	if value == 0 then
		cell.BackgroundColor3 = PhoneUi.WHITE
		cell.BackgroundTransparency = emptyTransparency
	elseif value > GHOST then
		cell.BackgroundColor3 = COLORS[value - GHOST]
		cell.BackgroundTransparency = 0.72
	else
		cell.BackgroundColor3 = COLORS[value] or COLORS[Patong.Garbage]
		cell.BackgroundTransparency = 0
	end
end

-- Called by the phone: true while the phone is open on this app.
function PatongApp.setActive(active: boolean)
	if onScreen ~= active then
		onScreen = active
		activeChanged()
	end
end

-- page: this app's page. goHome: back to the home screen. bringUp: open the phone on this app
-- (used when the host starts a round).
function PatongApp.build(page: Frame, goHome: () -> (), bringUp: () -> ())
	local me = Players.LocalPlayer

	local screens: { [string]: Frame } = {}
	local currentScreen = "Menu"
	local mode = "Single"
	local board: Board? = nil
	-- Versus: server time the pieces start falling, and whether the round has ended.
	local startAt = 0
	local roundOver = false
	local best = 0
	local held: { [Control]: { elapsed: number, nextAt: number } } = {}
	local opponents: { [number]: Opponent } = {}
	local bound = false
	local browsing = false

	local back: () -> () = goHome
	PhoneUi.header(page, "Patong", function()
		back()
	end)

	local function newScreen(name: string): Frame
		local s = PhoneUi.frame(name, page)
		s.Size = UDim2.fromScale(1, 1)
		s.Visible = false
		screens[name] = s
		return s
	end

	-- Menu ------------------------------------------------------------------------------------
	local menu = newScreen("Menu")
	local bestLabel = note("Best", menu, "")
	bestLabel.Position = UDim2.fromOffset(16, 60)
	bestLabel.Size = UDim2.new(1, -32, 0, 24)
	local singleButton = wideButton("Single", menu, "Single Player", true)
	singleButton.Position = UDim2.fromOffset(16, 110)
	local multiButton = wideButton("Multi", menu, "Multiplayer", false)
	multiButton.Position = UDim2.fromOffset(16, 168)
	local multiNote = note(
		"MultiNote",
		menu,
		`Play with up to {Patong.MaxPlayers - 1} friends within {Patong.JoinDistance} studs of you.`
	)
	multiNote.Position = UDim2.fromOffset(16, 222)

	-- Lobby (rebuilt by renderLobby) ----------------------------------------------------------
	local lobby = newScreen("Lobby")
	local lobbyBody = PhoneUi.frame("Body", lobby)
	lobbyBody.Position = UDim2.fromOffset(0, 50)
	lobbyBody.Size = UDim2.new(1, 0, 1, -50)
	local lobbyLayout = Instance.new("UIListLayout")
	lobbyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	lobbyLayout.Padding = UDim.new(0, 8)
	lobbyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lobbyLayout.Parent = lobbyBody

	-- Game ------------------------------------------------------------------------------------
	local play = newScreen("Play")

	local boardFrame = PhoneUi.frame("Board", play)
	boardFrame.Position = UDim2.fromOffset(BOARD_X, BOARD_Y)
	boardFrame.Size = UDim2.fromOffset(WIDTH * CELL, HEIGHT * CELL)
	boardFrame.BackgroundTransparency = 0.35
	boardFrame.BackgroundColor3 = PhoneUi.INK
	boardFrame.ClipsDescendants = true
	PhoneUi.corner(boardFrame, UDim.new(0, 6))
	local cells = cellGrid(boardFrame, WIDTH, HEIGHT, CELL, 1)
	local shown: { number } = table.create(WIDTH * HEIGHT, -1)
	local wanted: { number } = table.create(WIDTH * HEIGHT, 0)

	-- Incoming garbage, left of the board.
	local garbageBar = PhoneUi.frame("Incoming", play)
	garbageBar.AnchorPoint = Vector2.new(0, 1)
	garbageBar.Position = UDim2.fromOffset(BOARD_X - 7, BOARD_Y + HEIGHT * CELL)
	garbageBar.Size = UDim2.fromOffset(4, 0)
	garbageBar.BackgroundTransparency = 0
	garbageBar.BackgroundColor3 = WARNING
	PhoneUi.corner(garbageBar)

	local side = PhoneUi.frame("Side", play)
	side.Position = UDim2.fromOffset(SIDE_X, BOARD_Y)
	side.Size = UDim2.fromOffset(SIDE_WIDTH, HEIGHT * CELL)

	local function sideLabel(name: string, y: number, text: string, size: number): TextLabel
		local l = PhoneUi.label(name, side, text, size)
		l.Position = UDim2.fromOffset(0, y)
		l.Size = UDim2.new(1, 0, 0, size + 2)
		l.TextXAlignment = Enum.TextXAlignment.Left
		return l
	end
	sideLabel("NextTitle", 0, "NEXT", 11).TextTransparency = 0.45
	local preview = PhoneUi.frame("Next", side)
	preview.Position = UDim2.fromOffset(0, 16)
	preview.Size = UDim2.fromOffset(4 * PREVIEW_CELL, 2 * PREVIEW_CELL)
	local previewCells: { Frame } = {}
	for i = 1, 4 do
		local c = PhoneUi.frame(`Cell{i}`, preview)
		c.Size = UDim2.fromOffset(PREVIEW_CELL - 2, PREVIEW_CELL - 2)
		c.BackgroundTransparency = 0
		previewCells[i] = c
	end
	sideLabel("ScoreTitle", 54, "SCORE", 11).TextTransparency = 0.45
	local scoreLabel = sideLabel("Score", 68, "0", 16)
	sideLabel("RowsTitle", 92, "ROWS", 11).TextTransparency = 0.45
	local rowsLabel = sideLabel("Rows", 106, "0", 16)

	local others = PhoneUi.frame("Others", side)
	others.Position = UDim2.fromOffset(0, 136)
	others.Size = UDim2.new(1, 0, 1, -136)
	local othersLayout = Instance.new("UIListLayout")
	othersLayout.SortOrder = Enum.SortOrder.LayoutOrder
	othersLayout.Padding = UDim.new(0, 6)
	othersLayout.Parent = others

	-- Message over the board: countdown, game over, winner.
	local overlay = PhoneUi.frame("Overlay", play)
	overlay.Position = boardFrame.Position
	overlay.Size = boardFrame.Size
	overlay.BackgroundTransparency = 0.3
	overlay.BackgroundColor3 = PhoneUi.INK
	overlay.Visible = false
	overlay.ZIndex = 2
	PhoneUi.corner(overlay, UDim.new(0, 6))
	local overlayTitle = PhoneUi.label("Title", overlay, "", 30)
	overlayTitle.Position = UDim2.fromOffset(8, 110)
	overlayTitle.Size = UDim2.new(1, -16, 0, 40)
	overlayTitle.TextWrapped = true
	local overlayText = note("Text", overlay, "")
	overlayText.Position = UDim2.fromOffset(8, 152)
	overlayText.Size = UDim2.new(1, -16, 0, 44)
	local overlayButtons: { TextButton } = {}
	local overlayActions: { [number]: (() -> ())? } = {}
	for i = 1, 2 do
		local b = wideButton(`Button{i}`, overlay, "", i == 1)
		b.Position = UDim2.fromOffset(16, 206 + (i - 1) * 54)
		b.Size = UDim2.new(1, -32, 0, 44)
		b.TextSize = 15
		b.Visible = false
		b.Activated:Connect(function()
			local action = overlayActions[i]
			if action then
				action()
			end
		end)
		overlayButtons[i] = b
	end
	-- The countdown number on the overlay, or 0 when it isn't counting down.
	local countdownShown = 0

	local function showOverlay(title: string, text: string, buttons: { OverlayButton })
		overlay.Visible = true
		overlayTitle.Text = title
		overlayText.Text = text
		for i, b in overlayButtons do
			local info = buttons[i]
			b.Visible = info ~= nil
			b.Text = if info then info.text else ""
			overlayActions[i] = if info then info.onClick else nil
		end
	end

	local function hideOverlay()
		overlay.Visible = false
		countdownShown = 0
	end

	-- Drawing ---------------------------------------------------------------------------------
	local lastNext = 0
	local function render()
		local b = board
		if not b then
			return
		end
		for row = 1, HEIGHT do
			for column = 1, WIDTH do
				wanted[(row - 1) * WIDTH + column] = b:cell(column, row)
			end
		end
		if not b.over then
			for _, c in b:pieceCells(b:ghostRow()) do
				wanted[(c[2] - 1) * WIDTH + c[1]] = GHOST + b.piece
			end
			for _, c in b:pieceCells() do
				wanted[(c[2] - 1) * WIDTH + c[1]] = b.piece
			end
		end
		for i, value in wanted do
			if shown[i] ~= value then
				shown[i] = value
				paint(cells[i], value, 0.94)
			end
		end

		scoreLabel.Text = tostring(b.score)
		rowsLabel.Text = tostring(b.lines)
		garbageBar.Size = UDim2.fromOffset(4, math.min(b.pendingGarbage, HEIGHT) * CELL)

		if b.nextPiece ~= lastNext then
			lastNext = b.nextPiece
			local shape = PatongGame.shapeCells(b.nextPiece)
			local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
			for _, c in shape do
				minX, maxX = math.min(minX, c[1]), math.max(maxX, c[1])
				minY, maxY = math.min(minY, c[2]), math.max(maxY, c[2])
			end
			local offsetX = (4 - (maxX - minX + 1)) * PREVIEW_CELL / 2
			local offsetY = (2 - (maxY - minY + 1)) * PREVIEW_CELL / 2
			for i, c in shape do
				local f = previewCells[i]
				f.Position = UDim2.fromOffset(
					offsetX + (c[1] - minX) * PREVIEW_CELL + 1,
					offsetY + (c[2] - minY) * PREVIEW_CELL + 1
				)
				f.BackgroundColor3 = COLORS[b.nextPiece]
			end
		end
	end

	local function clearOpponents()
		for _, child in others:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		table.clear(opponents)
	end

	-- Small boards for everyone else in the room.
	local function buildOpponents()
		clearOpponents()
		local room = PatongController.getRoom()
		if not room then
			return
		end
		for order, member in room.Members do
			if member.UserId == me.UserId then
				continue
			end
			local holder = PhoneUi.frame(tostring(member.UserId), others)
			holder.LayoutOrder = order
			holder.Size = UDim2.new(1, 0, 0, HEIGHT * MINI_CELL + 16)
			local name = PhoneUi.label("Name", holder, member.Name, 11)
			name.Size = UDim2.new(1, 0, 0, 14)
			name.TextXAlignment = Enum.TextXAlignment.Left
			local mini = PhoneUi.frame("Board", holder)
			mini.Position = UDim2.fromOffset(0, 16)
			mini.Size = UDim2.fromOffset(WIDTH * MINI_CELL, HEIGHT * MINI_CELL)
			mini.BackgroundTransparency = 0.35
			mini.BackgroundColor3 = PhoneUi.INK
			local miniCells = cellGrid(mini, WIDTH, HEIGHT, MINI_CELL, 0)
			for _, c in miniCells do
				c.BackgroundTransparency = 1
			end
			opponents[member.UserId] = { cells = miniCells, name = name }
		end
	end

	local function nameOf(userId: number): string
		if userId == me.UserId then
			return me.DisplayName
		end
		local opponent = opponents[userId]
		return if opponent then opponent.name.Text else "Someone"
	end

	-- Controls --------------------------------------------------------------------------------
	local function playable(): boolean
		local b = board
		if not b or b.over or roundOver then
			return false
		end
		return mode == "Single" or Workspace:GetServerTimeNow() >= startAt
	end

	local function perform(control: Control)
		local b = board
		if not b or not playable() then
			return
		end
		if control == "Left" then
			b:move(-1)
		elseif control == "Right" then
			b:move(1)
		elseif control == "Down" then
			b:softDrop()
		elseif control == "Rotate" then
			b:rotate(1)
		elseif control == "RotateBack" then
			b:rotate(-1)
		elseif control == "Drop" then
			b:hardDrop()
		end
		render()
	end

	local function press(control: Control)
		perform(control)
		local repeats = REPEATS[control]
		if repeats then
			held[control] = { elapsed = 0, nextAt = repeats.first }
		end
	end

	local function release(control: Control)
		held[control] = nil
	end

	local function runHeld(dt: number)
		for control, state in held do
			local repeats = REPEATS[control]
			if not repeats then
				continue
			end
			state.elapsed += dt
			while state.elapsed >= state.nextAt do
				perform(control)
				state.nextAt += repeats.rate
			end
		end
	end

	local controls = PhoneUi.frame("Controls", play)
	controls.Position = UDim2.fromOffset(BOARD_X, CONTROLS_Y)
	controls.Size = UDim2.new(1, -BOARD_X * 2, 0, 52)
	local controlsLayout = Instance.new("UIListLayout")
	controlsLayout.FillDirection = Enum.FillDirection.Horizontal
	controlsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	controlsLayout.Padding = UDim.new(0, 5)
	controlsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	controlsLayout.Parent = controls
	for order, info in BUTTONS do
		local b = PhoneUi.button(info.control, controls)
		b.LayoutOrder = order
		b.Size = UDim2.fromOffset(46, 52)
		b.BackgroundColor3 = PhoneUi.WHITE
		b.BackgroundTransparency = 0.86
		b.Text = info.text
		b.TextSize = if #info.text > 3 then 13 else 22
		PhoneUi.corner(b, UDim.new(0, 14))
		b.MouseButton1Down:Connect(function()
			b.BackgroundTransparency = 0.7
			press(info.control)
		end)
		local function up()
			b.BackgroundTransparency = 0.86
			release(info.control)
		end
		b.MouseButton1Up:Connect(up)
		b.MouseLeave:Connect(up)
	end

	local keyList: { Enum.KeyCode } = {}
	for key in KEYS do
		table.insert(keyList, key)
	end

	local function onKey(
		_: string,
		state: Enum.UserInputState,
		input: InputObject
	): Enum.ContextActionResult
		local control = KEYS[input.KeyCode]
		if not control then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			press(control)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			release(control)
		end
		return Enum.ContextActionResult.Sink
	end

	-- Keyboard controls only while the game is on screen; otherwise the keys move the character.
	-- Higher priority than the character controls, and sunk, so the character stays still.
	local function refreshBinding()
		local want = onScreen and currentScreen == "Play"
		if want and not bound then
			ContextActionService:BindActionAtPriority(
				ACTION,
				onKey,
				false,
				Enum.ContextActionPriority.High.Value,
				table.unpack(keyList)
			)
		elseif not want and bound then
			ContextActionService:UnbindAction(ACTION)
			table.clear(held)
		end
		bound = want
	end

	-- Screens ---------------------------------------------------------------------------------
	local renderLobby: () -> ()

	local function refreshBrowse()
		local want = onScreen and currentScreen == "Lobby" and PatongController.getRoom() == nil
		if want ~= browsing then
			browsing = want
			PatongController.browse(want)
		end
	end

	local function showScreen(name: string)
		currentScreen = name
		for id, s in screens do
			s.Visible = id == name
		end
		if name == "Menu" then
			bestLabel.Text = if best > 0 then `Best score: {best}` else ""
		elseif name == "Lobby" then
			renderLobby()
		end
		refreshBinding()
		refreshBrowse()
	end

	local function newBoard(seed: number)
		local b = PatongGame.new(seed)
		board = b
		roundOver = false
		lastNext = 0
		table.clear(held)
		table.clear(shown)
		b.onLock = function(_cleared: number, attack: number)
			if mode == "Versus" then
				PatongController.sendBoard(b:pack())
				if attack > 0 then
					PatongController.sendAttack(attack)
				end
			end
			if not b.over then
				return
			end
			best = math.max(best, b.score)
			if mode == "Single" then
				showOverlay("Game over", `Score {b.score}   Best {best}`, {
					{
						text = "Play again",
						onClick = function()
							newBoard(Random.new():NextInteger(1, 2 ^ 30))
							hideOverlay()
							render()
						end,
					},
					{
						text = "Menu",
						onClick = function()
							showScreen("Menu")
						end,
					},
				})
			else
				PatongController.sendOut()
				showOverlay("Out!", "Watching the others finish.", {
					{
						text = "Back to room",
						onClick = function()
							showScreen("Lobby")
						end,
					},
				})
			end
		end
	end

	local function startSingle()
		mode = "Single"
		clearOpponents()
		newBoard(Random.new():NextInteger(1, 2 ^ 30))
		hideOverlay()
		showScreen("Play")
		render()
	end

	local function rowFrame(name: string, order: number): Frame
		local row = PhoneUi.frame(name, lobbyBody)
		row.LayoutOrder = order
		row.Size = UDim2.new(1, -32, 0, 46)
		row.BackgroundTransparency = 0.9
		row.BackgroundColor3 = PhoneUi.WHITE
		PhoneUi.corner(row, UDim.new(0, 14))
		return row
	end

	local function rowText(row: Frame, text: string): TextLabel
		local l = PhoneUi.label("Name", row, text, 16)
		l.Position = UDim2.fromOffset(14, 0)
		l.Size = UDim2.new(1, -100, 1, 0)
		l.FontFace = PhoneUi.FONT_REGULAR
		l.TextXAlignment = Enum.TextXAlignment.Left
		return l
	end

	local function rowStatus(row: Frame, text: string): TextLabel
		local l = PhoneUi.label("Status", row, text, 13)
		l.AnchorPoint = Vector2.new(1, 0)
		l.Position = UDim2.new(1, -14, 0, 0)
		l.Size = UDim2.new(0, 80, 1, 0)
		l.TextXAlignment = Enum.TextXAlignment.Right
		l.TextColor3 = PhoneUi.ACCENT
		return l
	end

	local function inLobby(make: (parent: Frame) -> GuiObject, order: number)
		-- Wraps full-width items (made for the page) so the list layout can place them.
		local holder = PhoneUi.frame(`Item{order}`, lobbyBody)
		holder.LayoutOrder = order
		local item = make(holder)
		holder.Size = UDim2.new(1, 0, 0, item.Size.Y.Offset)
		item.Position = UDim2.fromOffset(16, 0)
	end

	renderLobby = function()
		for _, child in lobbyBody:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local room = PatongController.getRoom()
		if not room then
			inLobby(function(parent)
				local b = wideButton("Host", parent, "Host a room", true)
				b.Activated:Connect(PatongController.host)
				return b
			end, 1)
			inLobby(function(parent)
				return heading("Heading", parent, "ROOMS NEAR YOU")
			end, 2)
			local nearby = PatongController.getNearby()
			if #nearby == 0 then
				inLobby(function(parent)
					return note(
						"Empty",
						parent,
						`No rooms yet. Get within {Patong.JoinDistance} studs of a friend who is hosting.`
					)
				end, 3)
			end
			for i, info in nearby do
				local row = rowFrame(tostring(info.HostId), 2 + i)
				rowText(row, `{info.HostName}  {info.Count}/{Patong.MaxPlayers}`)
				if info.Playing then
					rowStatus(row, "Playing")
				elseif info.Count >= Patong.MaxPlayers then
					rowStatus(row, "Full")
				else
					local join = PhoneUi.button("Join", row)
					join.AnchorPoint = Vector2.new(1, 0.5)
					join.Position = UDim2.new(1, -8, 0.5, 0)
					join.Size = UDim2.fromOffset(64, 32)
					join.BackgroundColor3 = PhoneUi.WHITE
					join.TextColor3 = PhoneUi.INK
					join.TextSize = 14
					join.Text = "Join"
					PhoneUi.corner(join)
					join.Activated:Connect(function()
						PatongController.join(info.HostId)
					end)
				end
			end
			return
		end

		local isHost = room.HostId == me.UserId
		inLobby(function(parent)
			return heading("Heading", parent, `ROOM  {#room.Members}/{Patong.MaxPlayers}`)
		end, 1)
		for i, member in room.Members do
			local row = rowFrame(tostring(member.UserId), 1 + i)
			rowText(row, if member.UserId == me.UserId then `{member.Name} (you)` else member.Name)
			if member.UserId == room.HostId then
				rowStatus(row, "Host")
			end
		end
		local order = #room.Members + 2
		if room.Playing then
			inLobby(function(parent)
				return note("Status", parent, "A round is going on.")
			end, order)
		elseif isHost then
			local ready = #room.Members >= 2
			inLobby(function(parent)
				local b = wideButton(
					"Start",
					parent,
					if ready then "Start" else "Waiting for players…",
					ready
				)
				b.Activated:Connect(function()
					if ready then
						PatongController.startGame()
					end
				end)
				return b
			end, order)
		else
			inLobby(function(parent)
				return note("Status", parent, "Waiting for the host to start.")
			end, order)
		end
		inLobby(function(parent)
			local b = wideButton("Leave", parent, "Leave room", false)
			b.Activated:Connect(PatongController.leave)
			return b
		end, order + 1)
	end

	back = function()
		if currentScreen == "Menu" then
			goHome()
		elseif currentScreen == "Lobby" then
			if PatongController.getRoom() then
				PatongController.leave()
			end
			showScreen("Menu")
		elseif mode == "Single" then
			board = nil
			hideOverlay()
			showScreen("Menu")
		else
			-- Leaving a versus round you are still in counts as losing it.
			local b = board
			if b and not b.over and not roundOver then
				b.over = true
				PatongController.sendOut()
			end
			hideOverlay()
			showScreen("Lobby")
		end
	end

	singleButton.Activated:Connect(startSingle)
	multiButton.Activated:Connect(function()
		showScreen("Lobby")
	end)

	-- Multiplayer messages ----------------------------------------------------------------------
	PatongController.NearbyChanged:Connect(function()
		if currentScreen == "Lobby" then
			renderLobby()
		end
	end)
	PatongController.RoomChanged:Connect(function()
		if currentScreen == "Lobby" then
			renderLobby()
		end
		refreshBrowse()
	end)
	PatongController.GameMessage:Connect(function(kind: string, a: any, b: any)
		if kind == "Start" then
			mode = "Versus"
			buildOpponents()
			newBoard(a)
			startAt = b
			hideOverlay()
			showScreen("Play")
			render()
			bringUp()
		elseif kind == "Board" then
			local opponent = opponents[a]
			if opponent and typeof(b) == "string" then
				for i, cell in opponent.cells do
					paint(cell, (string.byte(b, i) or 48) - 48, 1)
				end
			end
		elseif kind == "Garbage" then
			local current = board
			if mode == "Versus" and current and not current.over and not roundOver then
				current:addGarbage(a)
			end
		elseif kind == "Out" then
			local opponent = opponents[a]
			if opponent then
				opponent.name.Text = `{opponent.name.Text} ✕`
				opponent.name.TextTransparency = 0.5
			end
		elseif kind == "Winner" and mode == "Versus" then
			roundOver = true
			local title = if a == me.UserId
				then "You win!"
				elseif a == 0 then "Round over"
				else `{nameOf(a)} wins!`
			showOverlay(title, "", {
				{
					text = "Back to room",
					onClick = function()
						showScreen("Lobby")
					end,
				},
			})
		end
	end)

	-- Game loop ---------------------------------------------------------------------------------
	RunService.Heartbeat:Connect(function(dt: number)
		local b = board
		if not b or b.over or roundOver then
			return
		end
		if mode == "Versus" then
			local left = startAt - Workspace:GetServerTimeNow()
			if left > 0 then
				local count = math.ceil(left)
				if count ~= countdownShown then
					showOverlay(tostring(count), "Get ready", {})
					countdownShown = count
				end
				return
			elseif countdownShown > 0 then
				hideOverlay()
			end
		elseif not onScreen then
			-- Single player waits while the app is closed.
			return
		end
		runHeld(dt)
		b:update(dt)
		if onScreen then
			render()
		end
	end)

	activeChanged = function()
		if not onScreen then
			table.clear(held)
		end
		refreshBinding()
		refreshBrowse()
		if onScreen and currentScreen == "Lobby" then
			renderLobby()
		end
	end

	showScreen("Menu")
end

return PatongApp
