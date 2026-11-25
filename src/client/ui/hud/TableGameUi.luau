--!strict
-- Panel for the Playground table games, shown while this player sits at a game table
-- (server: TableGameService). First "waiting for someone to sit across", then the game:
--   Tic-Tac-Toe     tap a cell on your turn (Seat1 is X, Seat2 is O)
--   Arm Wrestling   tap the big button as fast as you can; the bar shows who is winning
--   Bato-Bato Pick  pick ✊ ✋ ✌️ before the timer runs out, best of 3
-- Jump to stand up and leave.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local PhoneUi = require(script.Parent.Parent.phone.PhoneUi)
local Remotes = require(ReplicatedStorage.Shared.core.Remotes)
local TableGames = require(ReplicatedStorage.Shared.games.TableGames)

local PANEL_SIZE = Vector2.new(300, 386)
local WAITING_HEIGHT = 130
-- The players' row under the title: avatars, names and the score.
local VERSUS_Y = 46
local VERSUS_HEIGHT = 62
local AVATAR_SIZE = 44
local SIDE_WIDTH = 96
local BODY_Y = 142
local X_COLOR = PhoneUi.ACCENT
local O_COLOR = Color3.fromRGB(120, 200, 235)
local THEM_COLOR = Color3.fromRGB(226, 96, 140)

type State = { [string]: any }

local TableGameUi = {}

local function cornered(object: GuiObject, radius: number)
	PhoneUi.corner(object, UDim.new(0, radius))
end

-- A player's avatar headshot (loads by itself, no request needed).
local function headshot(userId: number): string
	return `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`
end

function TableGameUi.start()
	local me = Players.LocalPlayer
	local remote: RemoteEvent? = nil
	local state: State? = nil
	local myIndex = 0
	-- Bato-Bato Pick: what I picked this round.
	local myPick: string? = nil

	local function send(...: any)
		if remote then
			remote:FireServer(...)
		end
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "TableGame"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 3
	gui.Enabled = false

	local panel = PhoneUi.frame("Panel", gui)
	-- Left side, so the character in the middle and the phone on the right stay visible.
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.new(0, 16, 0.5, 0)
	panel.Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y)
	panel.BackgroundTransparency = 0.12
	panel.BackgroundColor3 = PhoneUi.INK
	panel.Active = true
	cornered(panel, 26)
	local edge = Instance.new("UIStroke")
	edge.Color = PhoneUi.WHITE
	edge.Transparency = 0.85
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = panel

	-- Smaller on short screens (phones in landscape).
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local function fit()
		local camera = Workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 720
		scale.Scale = math.clamp(height * 0.6 / PANEL_SIZE.Y, 0.55, 1)
	end
	fit()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	local title = PhoneUi.label("Title", panel, "", 22)
	title.Position = UDim2.fromOffset(16, 14)
	title.Size = UDim2.new(1, -32, 0, 26)

	-- Who plays who: your avatar on the left, the opponent's on the right, the score between.
	local versus = PhoneUi.frame("Versus", panel)
	versus.Position = UDim2.fromOffset(16, VERSUS_Y)
	versus.Size = UDim2.new(1, -32, 0, VERSUS_HEIGHT)

	local function side(name: string, onRight: boolean): (ImageLabel, UIStroke, TextLabel)
		local x = if onRight then 1 else 0
		local offset = if onRight then -SIDE_WIDTH / 2 else SIDE_WIDTH / 2
		local avatar = Instance.new("ImageLabel")
		avatar.Name = `{name}Avatar`
		avatar.AnchorPoint = Vector2.new(0.5, 0)
		avatar.Position = UDim2.new(x, offset, 0, 0)
		avatar.Size = UDim2.fromOffset(AVATAR_SIZE, AVATAR_SIZE)
		avatar.BackgroundColor3 = PhoneUi.WHITE
		avatar.BackgroundTransparency = 0.85
		avatar.Parent = versus
		PhoneUi.corner(avatar)
		local ring = Instance.new("UIStroke")
		ring.Thickness = 2.5
		ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ring.Parent = avatar

		local label = PhoneUi.label(`{name}Name`, versus, "", 12)
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.new(x, offset, 0, AVATAR_SIZE + 4)
		label.Size = UDim2.fromOffset(SIDE_WIDTH, 14)
		return avatar, ring, label
	end
	local myAvatar, myRing, myName = side("My", false)
	local theirAvatar, theirRing, theirName = side("Their", true)
	local score = PhoneUi.label("Score", versus, "", 26)
	score.AnchorPoint = Vector2.new(0.5, 0)
	score.Position = UDim2.new(0.5, 0, 0, 8)
	score.Size = UDim2.fromOffset(90, 30)

	local status = PhoneUi.label("Status", panel, "", 17)
	status.Position = UDim2.fromOffset(16, VERSUS_Y + VERSUS_HEIGHT + 4)
	status.Size = UDim2.new(1, -32, 0, 22)
	status.TextColor3 = PhoneUi.ACCENT

	local hint = PhoneUi.label("Hint", panel, "Jump to leave", 12)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -10)
	hint.Size = UDim2.new(1, -32, 0, 16)
	hint.FontFace = PhoneUi.FONT_REGULAR
	hint.TextTransparency = 0.5

	local bodies: { [string]: Frame } = {}
	local function body(name: string): Frame
		local f = PhoneUi.frame(name, panel)
		f.Position = UDim2.fromOffset(0, BODY_Y)
		f.Size = UDim2.new(1, 0, 1, -BODY_Y - 30)
		f.Visible = false
		bodies[name] = f
		return f
	end

	-- Waiting ---------------------------------------------------------------------------------
	local waiting = body("Waiting")
	waiting.Position = UDim2.fromOffset(0, 44)
	waiting.Size = UDim2.new(1, 0, 0, WAITING_HEIGHT - 44 - 30)
	local waitingText = PhoneUi.label("Text", waiting, "Waiting for someone to sit across…", 16)
	waitingText.Size = UDim2.fromScale(1, 1)
	waitingText.FontFace = PhoneUi.FONT_REGULAR
	waitingText.TextWrapped = true
	local waitingPad = Instance.new("UIPadding")
	waitingPad.PaddingLeft = UDim.new(0, 24)
	waitingPad.PaddingRight = UDim.new(0, 24)
	waitingPad.Parent = waitingText

	-- Tic-Tac-Toe -----------------------------------------------------------------------------
	local tic = body("TicTacToe")
	local grid = PhoneUi.frame("Grid", tic)
	grid.AnchorPoint = Vector2.new(0.5, 0)
	grid.Position = UDim2.new(0.5, 0, 0, 4)
	grid.Size = UDim2.fromOffset(196, 196)
	local cells: { TextButton } = {}
	for i = 1, 9 do
		local row, column = (i - 1) // 3, (i - 1) % 3
		local cell = PhoneUi.button(`Cell{i}`, grid)
		cell.Position = UDim2.fromOffset(column * 67, row * 67)
		cell.Size = UDim2.fromOffset(62, 62)
		cell.BackgroundColor3 = PhoneUi.WHITE
		cell.BackgroundTransparency = 0.9
		cell.TextSize = 40
		cornered(cell, 14)
		cell.Activated:Connect(function()
			send("Move", i)
		end)
		cells[i] = cell
	end

	-- Arm Wrestling ---------------------------------------------------------------------------
	local arm = body("ArmWrestle")
	local bar = PhoneUi.frame("Bar", arm)
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 10)
	bar.Size = UDim2.fromOffset(260, 22)
	bar.BackgroundTransparency = 0
	bar.BackgroundColor3 = THEM_COLOR
	cornered(bar, 11)
	local fill = PhoneUi.frame("Fill", bar)
	fill.Size = UDim2.fromScale(0.5, 1)
	fill.BackgroundTransparency = 0
	fill.BackgroundColor3 = PhoneUi.ACCENT
	cornered(fill, 11)
	local middle = PhoneUi.frame("Middle", bar)
	middle.AnchorPoint = Vector2.new(0.5, 0.5)
	middle.Position = UDim2.fromScale(0.5, 0.5)
	middle.Size = UDim2.new(0, 2, 1, 8)
	middle.BackgroundTransparency = 0.3
	middle.BackgroundColor3 = PhoneUi.WHITE
	local youLabel = PhoneUi.label("You", arm, "You", 13)
	youLabel.Position = UDim2.fromOffset(20, 36)
	youLabel.Size = UDim2.fromOffset(120, 16)
	youLabel.TextXAlignment = Enum.TextXAlignment.Left
	youLabel.TextColor3 = PhoneUi.ACCENT
	local themLabel = PhoneUi.label("Them", arm, "", 13)
	themLabel.AnchorPoint = Vector2.new(1, 0)
	themLabel.Position = UDim2.new(1, -20, 0, 36)
	themLabel.Size = UDim2.fromOffset(120, 16)
	themLabel.TextXAlignment = Enum.TextXAlignment.Right
	themLabel.TextColor3 = THEM_COLOR

	local tap = PhoneUi.button("Tap", arm)
	tap.AnchorPoint = Vector2.new(0.5, 0)
	tap.Position = UDim2.new(0.5, 0, 0, 66)
	tap.Size = UDim2.fromOffset(220, 120)
	tap.BackgroundColor3 = PhoneUi.WHITE
	tap.TextColor3 = PhoneUi.INK
	tap.TextSize = 40
	tap.Text = "TAP!"
	cornered(tap, 28)
	local tapScale = Instance.new("UIScale")
	tapScale.Parent = tap
	tap.MouseButton1Down:Connect(function()
		send("Tap")
		tapScale.Scale = 0.94
		TweenService:Create(tapScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)

	-- Bato-Bato Pick --------------------------------------------------------------------------
	local rps = body("BatoBatoPick")
	local reveal = PhoneUi.label("Reveal", rps, "", 46)
	reveal.Position = UDim2.fromOffset(0, 0)
	reveal.Size = UDim2.new(1, 0, 0, 64)
	local choiceRow = PhoneUi.frame("Choices", rps)
	choiceRow.AnchorPoint = Vector2.new(0.5, 0)
	choiceRow.Position = UDim2.new(0.5, 0, 0, 80)
	choiceRow.Size = UDim2.fromOffset(264, 100)
	local choiceLayout = Instance.new("UIListLayout")
	choiceLayout.FillDirection = Enum.FillDirection.Horizontal
	choiceLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	choiceLayout.Padding = UDim.new(0, 8)
	choiceLayout.SortOrder = Enum.SortOrder.LayoutOrder
	choiceLayout.Parent = choiceRow
	local choiceButtons: { [string]: TextButton } = {}
	for order, choice in TableGames.BatoBatoPick.Choices do
		local b = PhoneUi.button(choice, choiceRow)
		b.LayoutOrder = order
		b.Size = UDim2.fromOffset(82, 100)
		b.BackgroundColor3 = PhoneUi.WHITE
		b.BackgroundTransparency = 0.88
		cornered(b, 18)
		local icon = PhoneUi.label("Icon", b, TableGames.BatoBatoPick.Icons[choice], 40)
		icon.Position = UDim2.fromOffset(0, 10)
		icon.Size = UDim2.new(1, 0, 0, 52)
		local name = PhoneUi.label("Name", b, choice, 14)
		name.Position = UDim2.fromOffset(0, 66)
		name.Size = UDim2.new(1, 0, 0, 20)
		b.Activated:Connect(function()
			local s = state
			if s and s.Phase == "Picking" and not myPick then
				myPick = choice
				send("Pick", choice)
			end
		end)
		choiceButtons[choice] = b
	end

	-- Drawing ---------------------------------------------------------------------------------
	local function nameOf(index: number): string
		local s = state
		if s then
			for _, info in s.Players do
				if info.Index == index then
					return info.Name
				end
			end
		end
		return "?"
	end

	local function outcome(winner: number): string
		if winner == 0 then
			return "Draw!"
		end
		return if winner == myIndex then "You win!" else `{nameOf(winner)} wins!`
	end

	-- Status line; also called every few frames for timers.
	local function drawStatus()
		local s = state
		if not s or s.Phase == "Waiting" then
			return
		end
		local them = 3 - myIndex
		local now = Workspace:GetServerTimeNow()
		local text = ""
		if s.Game == "TicTacToe" then
			if s.Phase == "Result" then
				text = outcome(s.Winner)
			else
				text = if s.Turn == myIndex
					then `Your turn ({if myIndex == 1 then "X" else "O"})`
					else `{nameOf(them)}'s turn`
			end
		elseif s.Game == "ArmWrestle" then
			if s.Phase == "Countdown" then
				text = `Get ready… {math.max(1, math.ceil(s.StartAt - now))}`
			elseif s.Phase == "Playing" then
				text = "Tap as fast as you can!"
			else
				text = outcome(s.Winner)
			end
		elseif s.Game == "BatoBatoPick" then
			if s.Phase == "Picking" then
				local left = math.max(0, math.ceil(s.Deadline - now))
				if myPick then
					text = if s.Picked[them]
						then "Both picked!"
						else `Waiting for {nameOf(them)}…`
				else
					text = `Pick one! {left}`
				end
			elseif s.Phase == "Reveal" then
				text = if s.RoundWinner == 0
					then "Same! Again."
					elseif s.RoundWinner == myIndex then "You win the round!"
					else `{nameOf(them)} wins the round`
			else
				text = outcome(s.Winner)
			end
		end
		status.Text = text
	end

	local function draw()
		local s = state
		if not s then
			return
		end
		myIndex = 0
		for _, info in s.Players do
			if info.UserId == me.UserId then
				myIndex = info.Index
			end
		end
		local them = 3 - myIndex
		title.Text = s.Title

		local shown = if s.Phase == "Waiting" then "Waiting" else s.Game
		for name, f in bodies do
			f.Visible = name == shown
		end
		-- Short panel while waiting, full size once the game is on.
		local isWaiting = s.Phase == "Waiting"
		panel.Size =
			UDim2.fromOffset(PANEL_SIZE.X, if isWaiting then WAITING_HEIGHT else PANEL_SIZE.Y)
		versus.Visible = not isWaiting
		if isWaiting then
			status.Text = ""
			return
		end

		local scores = s.Scores
		score.Text = `{scores[myIndex]} – {scores[them]}`
		local theirId = 0
		for _, info in s.Players do
			if info.Index == them then
				theirId = info.UserId
			end
		end
		myAvatar.Image = headshot(me.UserId)
		theirAvatar.Image = headshot(theirId)
		-- Tic-Tac-Toe: rings in your mark's color, and the mark next to the name.
		local isTic = s.Game == "TicTacToe"
		local myColor = if isTic
			then (if myIndex == 1 then X_COLOR else O_COLOR)
			else PhoneUi.ACCENT
		local theirColor = if isTic then (if them == 1 then X_COLOR else O_COLOR) else THEM_COLOR
		myRing.Color = myColor
		theirRing.Color = theirColor
		myName.Text = if isTic then `You ({if myIndex == 1 then "X" else "O"})` else "You"
		theirName.Text = if isTic
			then `{nameOf(them)} ({if them == 1 then "X" else "O"})`
			else nameOf(them)
		myName.TextColor3 = myColor
		theirName.TextColor3 = theirColor

		if s.Game == "TicTacToe" then
			local line = s.Line or {}
			for i, cell in cells do
				local mark = s.Board[i]
				cell.Text = if mark == 1 then "X" elseif mark == 2 then "O" else ""
				cell.TextColor3 = if mark == 1 then X_COLOR else O_COLOR
				local winning = table.find(line, i) ~= nil
				cell.BackgroundColor3 = if winning then PhoneUi.ACCENT else PhoneUi.WHITE
				cell.BackgroundTransparency = if winning then 0.55 else 0.9
			end
		elseif s.Game == "ArmWrestle" then
			local mine = if myIndex == 1 then s.Position else -s.Position
			TweenService
				:Create(fill, TweenInfo.new(0.1), { Size = UDim2.fromScale((1 + mine) / 2, 1) })
				:Play()
			themLabel.Text = nameOf(them)
			tap.BackgroundTransparency = if s.Phase == "Playing" then 0 else 0.7
		elseif s.Game == "BatoBatoPick" then
			if s.Phase == "Picking" and not s.Picked[myIndex] then
				myPick = nil
			end
			local icons = TableGames.BatoBatoPick.Icons
			if s.Picks then
				reveal.Text = `{icons[s.Picks[myIndex]] or "?"}  vs  {icons[s.Picks[them]] or "?"}`
			else
				reveal.Text = if s.Picked[them] then "?  vs  ✔" else "?  vs  ?"
			end
			for choice, b in choiceButtons do
				local chosen = myPick == choice
				b.BackgroundColor3 = if chosen then PhoneUi.ACCENT else PhoneUi.WHITE
				b.BackgroundTransparency = if chosen
					then 0.5
					elseif myPick or s.Phase ~= "Picking" then 0.95
					else 0.88
			end
		end
		drawStatus()
	end

	task.spawn(function()
		local r = Remotes.tableGame()
		remote = r
		r.OnClientEvent:Connect(function(kind: string, value: any)
			if kind == "State" then
				state = value
				gui.Enabled = true
				draw()
			elseif kind == "Closed" then
				state = nil
				myPick = nil
				gui.Enabled = false
			end
		end)
	end)

	-- Timers (countdown, pick time).
	task.spawn(function()
		while true do
			task.wait(0.2)
			if gui.Enabled then
				drawStatus()
			end
		end
	end)

	gui.Parent = me:WaitForChild("PlayerGui")
end

return TableGameUi
