--!strict
-- Talon: a one-button runner in the phone (Games folder). A little round lantern-buddy runs by
-- itself over the Tanaw sunset; tap (or Space / ↑ / W) to jump over spikes and onto blocks. Hold
-- to keep jumping as soon as you land. The run speeds up over time.
--
-- Menu:        Single Player or Multiplayer · Race.
-- Single:      endless run; distance is the score, the best run is kept for this session.
--              Pauses while the phone is closed or another app is open.
-- Race:        host or join a room near you (TalonController / TalonService). Everyone runs the
--              same course; the others show as ghosts and dots on the progress bar. Hitting
--              something sends you back to the start. First across the finish line wins.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PhoneUi = require(script.Parent.PhoneUi)
local Talon = require(ReplicatedStorage.Shared.Talon)
local TalonController = require(script.Parent.Parent.Parent.controllers.TalonController)

type Obstacle = Talon.Obstacle
type Ghost = { frame: Frame, name: TextLabel, dot: Frame, target: number, shown: number }

local ACTION = "TalonJump"
local KEYS = { Enum.KeyCode.Space, Enum.KeyCode.Up, Enum.KeyCode.W }

-- Layout inside the app page (280 x 528).
local VIEW_X, VIEW_Y = 12, 72
local VIEW_W, VIEW_H = 256, 320
local GROUND = Talon.Ground
local PLAYER_X = 56
local PLAYER = 24
local PX_PER_METER = Talon.PixelsPerMeter
local PROGRESS_INTERVAL = 0.15
local RESPAWN_DELAY = 0.6

local SKY_TOP = Color3.fromRGB(58, 44, 110)
local SKY_BOTTOM = Color3.fromRGB(240, 128, 140)
local GROUND_COLOR = Color3.fromRGB(56, 40, 48)
local GROUND_EDGE = Color3.fromRGB(255, 200, 120)
local SPIKE_COLOR = Color3.fromRGB(255, 236, 214)
local BLOCK_COLOR = Color3.fromRGB(120, 84, 160)
local BUDDY = Color3.fromRGB(255, 184, 92)
local INK = Color3.fromRGB(45, 32, 26)
local GHOST_COLORS = {
	Color3.fromRGB(140, 200, 255),
	Color3.fromRGB(160, 240, 170),
	Color3.fromRGB(255, 150, 200),
}

local TalonApp = {}

local onScreen = false
local activeChanged: () -> () = function() end

-- Called by the phone: true while the phone is open on this app.
function TalonApp.setActive(active: boolean)
	if onScreen ~= active then
		onScreen = active
		activeChanged()
	end
end

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

local function buddyFace(parent: Frame)
	for _, ex in { 0.36, 0.68 } do
		local eye = PhoneUi.frame("Eye", parent)
		eye.AnchorPoint = Vector2.new(0.5, 0.5)
		eye.Position = UDim2.fromScale(ex, 0.42)
		eye.Size = UDim2.fromOffset(4, 6)
		eye.BackgroundTransparency = 0
		eye.BackgroundColor3 = INK
		PhoneUi.corner(eye)
	end
	local mouth = PhoneUi.frame("Mouth", parent)
	mouth.AnchorPoint = Vector2.new(0.5, 0.5)
	mouth.Position = UDim2.fromScale(0.52, 0.68)
	mouth.Size = UDim2.fromOffset(6, 3)
	mouth.BackgroundTransparency = 0
	mouth.BackgroundColor3 = INK
	PhoneUi.corner(mouth)
end

-- page: this app's page. goHome: back to the home screen. bringUp: open the phone on this app
-- (used when the host starts a race).
function TalonApp.build(page: Frame, goHome: () -> (), bringUp: () -> ())
	local me = Players.LocalPlayer
	PhoneUi.header(page, "Talon", goHome)

	local screens: { [string]: Frame } = {}
	local currentScreen = "Menu"
	local function newScreen(name: string): Frame
		local s = PhoneUi.frame(name, page)
		s.Size = UDim2.fromScale(1, 1)
		s.Visible = false
		screens[name] = s
		return s
	end

	-- Menu ---------------------------------------------------------------------------------
	local menu = newScreen("Menu")
	local menuTitle = PhoneUi.label("Title", menu, "Talon", 44)
	menuTitle.Position = UDim2.fromOffset(0, 70)
	menuTitle.Size = UDim2.new(1, 0, 0, 50)
	local menuSub = PhoneUi.label("Sub", menu, "Isang pindot lang: talon!", 15)
	menuSub.FontFace = PhoneUi.FONT_REGULAR
	menuSub.Position = UDim2.fromOffset(0, 120)
	menuSub.Size = UDim2.new(1, 0, 0, 20)
	menuSub.TextTransparency = 0.25
	local singleButton = wideButton("Single", menu, "Single Player", true)
	singleButton.Position = UDim2.fromOffset(16, 190)
	local raceButton = wideButton("Race", menu, "Multiplayer · Race", false)
	raceButton.Position = UDim2.fromOffset(16, 246)
	local menuBest = PhoneUi.label("Best", menu, "", 14)
	menuBest.FontFace = PhoneUi.FONT_REGULAR
	menuBest.Position = UDim2.fromOffset(0, 304)
	menuBest.Size = UDim2.new(1, 0, 0, 20)
	local raceNote = PhoneUi.label(
		"Note",
		menu,
		`Race: paunahan sa finish line ({Talon.RaceMeters} m). Pag natamaan, balik sa simula!`,
		13
	)
	raceNote.FontFace = PhoneUi.FONT_REGULAR
	raceNote.Position = UDim2.fromOffset(24, 340)
	raceNote.Size = UDim2.new(1, -48, 0, 40)
	raceNote.TextWrapped = true
	raceNote.TextTruncate = Enum.TextTruncate.None
	raceNote.TextTransparency = 0.35

	-- Lobby --------------------------------------------------------------------------------
	local lobby = newScreen("Lobby")
	local lobbyBody = Instance.new("ScrollingFrame")
	lobbyBody.Name = "Body"
	lobbyBody.Position = UDim2.fromOffset(0, 48)
	lobbyBody.Size = UDim2.new(1, 0, 1, -52)
	lobbyBody.BackgroundTransparency = 1
	lobbyBody.BorderSizePixel = 0
	lobbyBody.ScrollBarThickness = 3
	lobbyBody.AutomaticCanvasSize = Enum.AutomaticSize.Y
	lobbyBody.CanvasSize = UDim2.new()
	lobbyBody.Parent = lobby
	local lobbyLayout = Instance.new("UIListLayout")
	lobbyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	lobbyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lobbyLayout.Padding = UDim.new(0, 8)
	lobbyLayout.Parent = lobbyBody

	-- Play ---------------------------------------------------------------------------------
	local play = newScreen("Play")

	local scoreLabel = PhoneUi.label("Score", play, "0 m", 16)
	scoreLabel.Position = UDim2.fromOffset(VIEW_X + 4, 44)
	scoreLabel.Size = UDim2.fromOffset(120, 22)
	scoreLabel.TextXAlignment = Enum.TextXAlignment.Left

	local bestLabel = PhoneUi.label("Best", play, "Best 0 m", 14)
	bestLabel.FontFace = PhoneUi.FONT_REGULAR
	bestLabel.AnchorPoint = Vector2.new(1, 0)
	bestLabel.Position = UDim2.new(1, -VIEW_X - 4, 0, 46)
	bestLabel.Size = UDim2.fromOffset(120, 20)
	bestLabel.TextXAlignment = Enum.TextXAlignment.Right
	bestLabel.TextTransparency = 0.25

	-- Race progress bar (replaces the best label in a race).
	local track = PhoneUi.frame("Progress", play)
	track.Position = UDim2.fromOffset(VIEW_X + 96, 54)
	track.Size = UDim2.fromOffset(VIEW_W - 120, 6)
	track.BackgroundTransparency = 0.75
	track.BackgroundColor3 = PhoneUi.WHITE
	PhoneUi.corner(track)
	local flag = PhoneUi.label("Flag", track, "🏁", 14)
	flag.AnchorPoint = Vector2.new(0, 0.5)
	flag.Position = UDim2.new(1, 2, 0.5, 0)
	flag.Size = UDim2.fromOffset(18, 18)
	local myDot = PhoneUi.frame("Me", track)
	myDot.AnchorPoint = Vector2.new(0.5, 0.5)
	myDot.Size = UDim2.fromOffset(12, 12)
	myDot.BackgroundTransparency = 0
	myDot.BackgroundColor3 = BUDDY
	myDot.ZIndex = 2
	PhoneUi.corner(myDot)

	local view = PhoneUi.button("View", play)
	view.Position = UDim2.fromOffset(VIEW_X, VIEW_Y)
	view.Size = UDim2.fromOffset(VIEW_W, VIEW_H)
	view.BackgroundColor3 = PhoneUi.WHITE
	view.ClipsDescendants = true
	PhoneUi.corner(view, UDim.new(0, 16))
	local sky = Instance.new("UIGradient")
	sky.Rotation = 90
	sky.Color = ColorSequence.new(SKY_TOP, SKY_BOTTOM)
	sky.Parent = view

	-- Far city skyline: two identical tiles that loop.
	local skyline = PhoneUi.frame("Skyline", view)
	skyline.Size = UDim2.fromOffset(VIEW_W * 2, VIEW_H)
	for tile = 0, 1 do
		local x = 0
		local layoutRng = Random.new(7)
		while x < VIEW_W do
			local w = layoutRng:NextInteger(14, 30)
			local h = layoutRng:NextInteger(24, 90)
			local b = PhoneUi.frame("Building", skyline)
			b.BackgroundTransparency = 0.15
			b.BackgroundColor3 = Color3.fromRGB(90, 62, 118)
			b.Position = UDim2.fromOffset(tile * VIEW_W + x, GROUND - h)
			b.Size = UDim2.fromOffset(w, h)
			for _ = 1, math.floor(h / 18) do
				local win = PhoneUi.frame("Window", b)
				win.BackgroundTransparency = 0.1
				win.BackgroundColor3 = GROUND_EDGE
				win.Position = UDim2.fromOffset(
					layoutRng:NextInteger(2, math.max(2, w - 5)),
					layoutRng:NextInteger(4, h - 6)
				)
				win.Size = UDim2.fromOffset(3, 3)
			end
			x += w + layoutRng:NextInteger(2, 8)
		end
	end

	local ground = PhoneUi.frame("Ground", view)
	ground.Position = UDim2.fromOffset(0, GROUND)
	ground.Size = UDim2.new(1, 0, 0, VIEW_H - GROUND)
	ground.BackgroundTransparency = 0
	ground.BackgroundColor3 = GROUND_COLOR
	local edge = PhoneUi.frame("Edge", ground)
	edge.Size = UDim2.new(1, 0, 0, 3)
	edge.BackgroundTransparency = 0
	edge.BackgroundColor3 = GROUND_EDGE

	local world = PhoneUi.frame("World", view)
	world.Size = UDim2.fromScale(1, 1)
	local ghostLayer = PhoneUi.frame("Ghosts", view)
	ghostLayer.Size = UDim2.fromScale(1, 1)
	ghostLayer.ZIndex = 2

	local buddy = PhoneUi.frame("Buddy", view)
	buddy.AnchorPoint = Vector2.new(0.5, 1)
	buddy.BackgroundTransparency = 0
	buddy.BackgroundColor3 = BUDDY
	buddy.ZIndex = 3
	PhoneUi.corner(buddy, UDim.new(0.45, 0))
	local glow = Instance.new("UIStroke")
	glow.Color = Color3.fromRGB(255, 230, 170)
	glow.Thickness = 2
	glow.Parent = buddy
	buddyFace(buddy)

	local flash = PhoneUi.frame("Flash", view)
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
	flash.BackgroundTransparency = 1
	flash.ZIndex = 4

	local toast = PhoneUi.label("Toast", view, "", 18)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 16)
	toast.Size = UDim2.new(1, -20, 0, 24)
	toast.ZIndex = 4
	toast.TextStrokeTransparency = 0.5

	-- Card for start / pause / countdown / results.
	local card = PhoneUi.frame("Card", view)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.42)
	card.Size = UDim2.fromOffset(214, 156)
	card.BackgroundTransparency = 0.15
	card.BackgroundColor3 = PhoneUi.INK
	card.ZIndex = 5
	card.Active = true -- taps on the card don't fall through to the view
	PhoneUi.corner(card, UDim.new(0, 16))
	local cardTitle = PhoneUi.label("Title", card, "", 24)
	cardTitle.Position = UDim2.fromOffset(0, 14)
	cardTitle.Size = UDim2.new(1, 0, 0, 30)
	cardTitle.ZIndex = 5
	local cardText = PhoneUi.label("Text", card, "", 13)
	cardText.FontFace = PhoneUi.FONT_REGULAR
	cardText.Position = UDim2.fromOffset(12, 48)
	cardText.Size = UDim2.new(1, -24, 0, 44)
	cardText.TextWrapped = true
	cardText.TextTruncate = Enum.TextTruncate.None
	cardText.ZIndex = 5
	local cardButton = PhoneUi.button("Go", card)
	cardButton.AnchorPoint = Vector2.new(0.5, 1)
	cardButton.Position = UDim2.new(0.5, 0, 1, -12)
	cardButton.Size = UDim2.fromOffset(160, 38)
	cardButton.BackgroundColor3 = PhoneUi.ACCENT
	cardButton.TextColor3 = INK
	cardButton.TextSize = 16
	cardButton.ZIndex = 5
	PhoneUi.corner(cardButton, UDim.new(0, 12))

	local jumpButton = PhoneUi.button("Jump", play)
	jumpButton.Position = UDim2.fromOffset(VIEW_X, VIEW_Y + VIEW_H + 12)
	jumpButton.Size = UDim2.fromOffset(VIEW_W, 64)
	jumpButton.BackgroundColor3 = PhoneUi.WHITE
	jumpButton.BackgroundTransparency = 0.85
	jumpButton.Text = "TALON!"
	jumpButton.TextSize = 22
	PhoneUi.corner(jumpButton, UDim.new(0, 16))

	local menuButton = PhoneUi.button("Menu", play)
	menuButton.Position = UDim2.fromOffset(VIEW_X, VIEW_Y + VIEW_H + 84)
	menuButton.Size = UDim2.fromOffset(VIEW_W, 22)
	menuButton.BackgroundTransparency = 1
	menuButton.Text = "‹ Menu"
	menuButton.TextSize = 13
	menuButton.TextTransparency = 0.3

	-- State --------------------------------------------------------------------------------
	local mode = "Single" -- "Single" | "Race"
	-- "Ready" | "Countdown" | "Playing" | "Paused" | "Dead" | "Respawn" | "Finished" | "Over"
	local state = "Ready"
	local distance = 0
	local speed = Talon.StartSpeed
	local y = GROUND
	local vy = 0
	local grounded = true
	local holding = false
	local squash = 0
	local best = 0
	local course: { Obstacle } = {}
	local shown: { [Obstacle]: GuiObject } = {}
	local singleRng = Random.new()
	local nextSpawn = 0
	local finishX = 0
	local startAt = 0
	local respawnAt = 0
	local lastProgress = 0
	local toastUntil = 0
	local ghosts: { [number]: Ghost } = {}
	local cardAction: (() -> ())? = nil

	local function showToast(text: string, seconds: number)
		toast.Text = text
		toastUntil = os.clock() + seconds
	end

	local function showCard(title: string, text: string, button: string?, action: (() -> ())?)
		cardTitle.Text = title
		cardText.Text = text
		cardButton.Visible = button ~= nil
		cardButton.Text = button or ""
		cardAction = action
		card.Visible = true
	end

	local function hideCard()
		card.Visible = false
		cardAction = nil
	end

	local function clearCourse()
		for _, frame in shown do
			frame:Destroy()
		end
		table.clear(shown)
		table.clear(course)
	end

	local function clearGhosts()
		for _, ghost in ghosts do
			ghost.frame:Destroy()
			ghost.dot:Destroy()
		end
		table.clear(ghosts)
	end

	local function makeFrame(o: Obstacle): GuiObject
		if o.kind == "spike" then
			local f = PhoneUi.frame("Spike", world)
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Size = UDim2.fromOffset(Talon.Spike, Talon.Spike)
			f.Rotation = 45
			f.BackgroundTransparency = 0
			f.BackgroundColor3 = SPIKE_COLOR
			return f
		elseif o.kind == "block" then
			local f = PhoneUi.frame("Block", world)
			f.Size = UDim2.fromOffset(o.w, o.bottom - o.top)
			f.BackgroundTransparency = 0
			f.BackgroundColor3 = BLOCK_COLOR
			PhoneUi.corner(f, UDim.new(0, 4))
			local top = PhoneUi.frame("Top", f)
			top.Size = UDim2.new(1, 0, 0, 3)
			top.BackgroundTransparency = 0
			top.BackgroundColor3 = GROUND_EDGE
			return f
		end
		-- Finish line: checkered post with a flag.
		local f = PhoneUi.frame("Finish", world)
		f.Size = UDim2.fromOffset(o.w, GROUND - 40)
		for i = 0, math.floor((GROUND - 40) / 8) do
			for j = 0, 1 do
				if (i + j) % 2 == 0 then
					local sq = PhoneUi.frame("Sq", f)
					sq.BackgroundTransparency = 0
					sq.BackgroundColor3 = PhoneUi.WHITE
					sq.Position = UDim2.fromOffset(j * 6, i * 8)
					sq.Size = UDim2.fromOffset(6, 8)
				end
			end
		end
		local banner = PhoneUi.label("Flag", f, "🏁 FINISH", 14)
		banner.AnchorPoint = Vector2.new(0.5, 1)
		banner.Position = UDim2.new(0.5, 0, 0, -2)
		banner.Size = UDim2.fromOffset(90, 18)
		banner.TextStrokeTransparency = 0.5
		return f
	end

	local function placeBuddy()
		buddy.Size = UDim2.fromOffset(PLAYER * (1 + squash * 0.35), PLAYER * (1 - squash * 0.3))
		buddy.Position = UDim2.fromOffset(PLAYER_X + PLAYER / 2, y)
	end

	local function render(dt: number)
		-- Obstacles near the view get a frame; the rest don't.
		for _, o in course do
			local sx = o.x - distance
			local visible = sx + o.w > -40 and sx < VIEW_W + 40
			local frame = shown[o]
			if visible then
				if not frame then
					frame = makeFrame(o)
					shown[o] = frame
				end
				local f = frame :: GuiObject
				if o.kind == "spike" then
					f.Position = UDim2.fromOffset(sx + o.w / 2, GROUND)
				elseif o.kind == "block" then
					f.Position = UDim2.fromOffset(sx, o.top)
				else
					f.Position = UDim2.fromOffset(sx, 40)
				end
			elseif frame then
				frame:Destroy()
				shown[o] = nil
			end
		end
		skyline.Position = UDim2.fromOffset(-((distance * 0.2) % VIEW_W), 0)
		placeBuddy()

		local meters = math.floor(distance / PX_PER_METER)
		if mode == "Race" then
			scoreLabel.Text = `{meters}/{Talon.RaceMeters} m`
			myDot.Position = UDim2.fromScale(math.clamp(distance / finishX, 0, 1), 0.5)
			for _, ghost in ghosts do
				if ghost.target < ghost.shown - 200 then
					ghost.shown = ghost.target -- they respawned
				else
					ghost.shown += (ghost.target - ghost.shown) * math.min(1, dt * 8)
				end
				local gx = PLAYER_X + (ghost.shown - distance)
				ghost.frame.Visible = gx > -30 and gx < VIEW_W + 30
				ghost.frame.Position = UDim2.fromOffset(gx + PLAYER / 2, GROUND)
				ghost.dot.Position = UDim2.fromScale(math.clamp(ghost.target / finishX, 0, 1), 0.5)
			end
		else
			scoreLabel.Text = `{meters} m`
		end
		toast.Visible = os.clock() < toastUntil
	end

	local function resetRun()
		distance = 0
		speed = Talon.StartSpeed
		y = GROUND
		vy = 0
		grounded = true
		squash = 0
	end

	-- Single player ----------------------------------------------------------------------------
	local function startSingle()
		mode = "Single"
		clearCourse()
		clearGhosts()
		resetRun()
		nextSpawn = 0
		singleRng = Random.new()
		state = "Playing"
		hideCard()
	end

	local function showSingleReady()
		mode = "Single"
		clearCourse()
		clearGhosts()
		resetRun()
		state = "Ready"
		render(0)
		showCard("Talon", "Tumalon sa mga tinik at blocks. Gaano ka kalayo?", "Simula", startSingle)
	end

	-- Screens ------------------------------------------------------------------------------
	local bound = false
	local browsing = false
	local renderLobby: () -> ()
	local jump: () -> ()

	local function onKey(_: string, inputState: Enum.UserInputState): Enum.ContextActionResult
		if inputState == Enum.UserInputState.Begin then
			holding = true
			jump()
		elseif
			inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel
		then
			holding = false
		end
		return Enum.ContextActionResult.Sink
	end

	local function refreshBinding()
		local want = onScreen and currentScreen == "Play"
		if want and not bound then
			ContextActionService:BindActionAtPriority(
				ACTION,
				onKey,
				false,
				Enum.ContextActionPriority.High.Value,
				table.unpack(KEYS)
			)
		elseif not want and bound then
			ContextActionService:UnbindAction(ACTION)
			holding = false
		end
		bound = want
	end

	local function refreshBrowse()
		local want = onScreen and currentScreen == "Lobby" and TalonController.getRoom() == nil
		if want ~= browsing then
			browsing = want
			TalonController.browse(want)
		end
	end

	local function showScreen(name: string)
		currentScreen = name
		for id, s in screens do
			s.Visible = id == name
		end
		if name == "Menu" then
			menuBest.Text = if best > 0 then `Best (single): {best} m` else ""
		elseif name == "Lobby" then
			renderLobby()
		elseif name == "Play" then
			local race = mode == "Race"
			track.Visible = race
			bestLabel.Visible = not race
			menuButton.Visible = not race
		end
		refreshBinding()
		refreshBrowse()
	end

	-- Jump / start / resume ------------------------------------------------------------------
	jump = function()
		if mode == "Single" then
			if state == "Ready" or state == "Dead" then
				startSingle()
				return
			elseif state == "Paused" then
				state = "Playing"
				hideCard()
				return
			end
		end
		if state == "Playing" and grounded then
			vy = -Talon.JumpSpeed
			grounded = false
			squash = -0.6
		end
	end

	-- Race -----------------------------------------------------------------------------------
	local function backToRoom()
		hideCard()
		showScreen("Lobby")
	end

	local function startRace(seed: number, at: number)
		mode = "Race"
		clearCourse()
		clearGhosts()
		local raceCourse, finish = Talon.raceCourse(seed)
		for _, o in raceCourse do
			table.insert(course, o)
		end
		finishX = finish
		startAt = at
		resetRun()
		state = "Countdown"
		lastProgress = 0

		local room = TalonController.getRoom()
		local members: { TalonController.Member } = if room then room.Members else {}
		local index = 0
		for _, member in members do
			if member.UserId ~= me.UserId then
				index += 1
				local color = GHOST_COLORS[(index - 1) % #GHOST_COLORS + 1]
				local frame = PhoneUi.frame("Ghost", ghostLayer)
				frame.AnchorPoint = Vector2.new(0.5, 1)
				frame.Size = UDim2.fromOffset(PLAYER, PLAYER)
				frame.BackgroundTransparency = 0.45
				frame.BackgroundColor3 = color
				PhoneUi.corner(frame, UDim.new(0.45, 0))
				buddyFace(frame)
				local name = PhoneUi.label("Name", frame, member.Name, 11)
				name.AnchorPoint = Vector2.new(0.5, 1)
				name.Position = UDim2.new(0.5, 0, 0, -2)
				name.Size = UDim2.fromOffset(80, 14)
				name.TextStrokeTransparency = 0.5
				local dot = PhoneUi.frame("Dot", track)
				dot.AnchorPoint = Vector2.new(0.5, 0.5)
				dot.Size = UDim2.fromOffset(8, 8)
				dot.BackgroundTransparency = 0
				dot.BackgroundColor3 = color
				PhoneUi.corner(dot)
				ghosts[member.UserId] =
					{ frame = frame, name = name, dot = dot, target = 0, shown = 0 }
			end
		end

		showScreen("Play")
		showCard("3", "Paunahan sa finish line!", nil, nil)
		render(0)
		bringUp()
	end

	local function finishRace()
		state = "Finished"
		TalonController.sendProgress(finishX)
		TalonController.sendFinish()
		showCard("🏁 Tapos!", "Sandali, tinitingnan kung sino ang nauna…", nil, nil)
	end

	local function raceHit()
		state = "Respawn"
		respawnAt = os.clock() + RESPAWN_DELAY
		flash.BackgroundTransparency = 0.35
		showToast("Balik sa simula! 💥", 1.2)
	end

	-- Game loop ------------------------------------------------------------------------------
	local function hits(left: number, right: number): Obstacle?
		local top = y - PLAYER + 4
		for _, o in course do
			if
				o.kind ~= "finish"
				and right > o.x
				and left < o.x + o.w
				and y > o.top + 1
				and top < o.bottom
			then
				if o.kind == "spike" then
					-- Spikes are triangles: only the middle reaches the top.
					local centre = o.x + o.w / 2
					local nearest = math.clamp(centre, left, right)
					if y > o.top + math.abs(nearest - centre) then
						return o
					end
				elseif not (grounded and math.abs(y - o.top) < 0.5) then
					return o
				end
			end
		end
		return nil
	end

	local function step(dt: number)
		if flash.BackgroundTransparency < 1 then
			flash.BackgroundTransparency = math.min(1, flash.BackgroundTransparency + dt * 2.5)
		end
		if state == "Countdown" then
			local left = startAt - Workspace:GetServerTimeNow()
			if left > 0 then
				cardTitle.Text = tostring(math.ceil(left))
			else
				state = "Playing"
				hideCard()
				showToast("TALON! 🏃", 0.8)
			end
		elseif state == "Respawn" and os.clock() >= respawnAt then
			resetRun()
			state = "Playing"
			TalonController.sendProgress(0)
		end
		if state ~= "Playing" then
			render(dt)
			return
		end

		dt = math.min(dt, 1 / 30)
		speed = math.min(Talon.MaxSpeed, speed + Talon.SpeedGain * dt)
		distance += speed * dt

		if mode == "Single" then
			while nextSpawn < distance + VIEW_W + 80 do
				nextSpawn = Talon.addPattern(singleRng, math.max(nextSpawn, VIEW_W + 60), course)
			end
			for i = #course, 1, -1 do
				local o = course[i]
				if o.x + o.w < distance - 100 then
					local frame = shown[o]
					if frame then
						frame:Destroy()
						shown[o] = nil
					end
					table.remove(course, i)
				end
			end
		end

		-- Vertical movement and landing on the ground or a block top.
		local left = PLAYER_X + distance + 3
		local right = PLAYER_X + distance + PLAYER - 3
		local prevY = y
		vy += Talon.Gravity * dt
		y += vy * dt
		local support = GROUND
		for _, o in course do
			if o.kind == "block" and right > o.x and left < o.x + o.w and prevY <= o.top + 4 then
				support = math.min(support, o.top)
			end
		end
		if vy >= 0 and y >= support then
			if not grounded then
				squash = 0.7
			end
			y = support
			vy = 0
			grounded = true
		else
			grounded = false
		end
		squash += (0 - squash) * math.min(1, dt * 12)

		if hits(left, right) then
			if mode == "Single" then
				state = "Dead"
				local meters = math.floor(distance / PX_PER_METER)
				local isBest = meters > best
				best = math.max(best, meters)
				bestLabel.Text = `Best {best} m`
				flash.BackgroundTransparency = 0.35
				showCard(
					if isBest then "Bagong best! 🎉" else "Ay! 💥",
					`Umabot ka ng {meters} m.`,
					"Ulit",
					startSingle
				)
			else
				raceHit()
			end
		elseif mode == "Race" and right >= finishX then
			distance = finishX - PLAYER_X - PLAYER
			finishRace()
		elseif holding and grounded then
			jump()
		end

		if
			mode == "Race"
			and state == "Playing"
			and os.clock() - lastProgress > PROGRESS_INTERVAL
		then
			lastProgress = os.clock()
			TalonController.sendProgress(distance)
		end
		render(dt)
	end

	-- Lobby ----------------------------------------------------------------------------------
	local function inLobby(make: (parent: Frame) -> GuiObject, order: number)
		local holder = PhoneUi.frame(`Item{order}`, lobbyBody)
		holder.LayoutOrder = order
		local item = make(holder)
		holder.Size = UDim2.new(1, 0, 0, item.Size.Y.Offset)
		item.Position = UDim2.fromOffset(16, 0)
	end

	local function row(name: string, order: number, text: string, status: string?): Frame
		local r = PhoneUi.frame(name, lobbyBody)
		r.LayoutOrder = order
		r.Size = UDim2.new(1, -32, 0, 46)
		r.BackgroundTransparency = 0.9
		r.BackgroundColor3 = PhoneUi.WHITE
		PhoneUi.corner(r, UDim.new(0, 14))
		local l = PhoneUi.label("Name", r, text, 16)
		l.Position = UDim2.fromOffset(14, 0)
		l.Size = UDim2.new(1, -100, 1, 0)
		l.FontFace = PhoneUi.FONT_REGULAR
		l.TextXAlignment = Enum.TextXAlignment.Left
		if status then
			local s = PhoneUi.label("Status", r, status, 13)
			s.AnchorPoint = Vector2.new(1, 0)
			s.Position = UDim2.new(1, -14, 0, 0)
			s.Size = UDim2.new(0, 80, 1, 0)
			s.TextXAlignment = Enum.TextXAlignment.Right
			s.TextColor3 = PhoneUi.ACCENT
		end
		return r
	end

	local function text(name: string, parent: Instance, value: string, size: number): TextLabel
		local l = PhoneUi.label(name, parent, value, size)
		l.Size = UDim2.new(1, -32, 0, if size > 12 then 40 else 20)
		l.FontFace = if size > 12 then PhoneUi.FONT_REGULAR else PhoneUi.FONT
		l.TextWrapped = true
		l.TextTruncate = Enum.TextTruncate.None
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextTransparency = if size > 12 then 0.3 else 0.45
		return l
	end

	renderLobby = function()
		for _, child in lobbyBody:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local room = TalonController.getRoom()
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end
		if not room then
			inLobby(function(parent)
				local b = wideButton("Host", parent, "Mag-host ng race", true)
				b.Activated:Connect(TalonController.host)
				return b
			end, nextOrder())
			inLobby(function(parent)
				return text("Heading", parent, "MGA ROOM MALAPIT SA'YO", 12)
			end, nextOrder())
			local nearby = TalonController.getNearby()
			if #nearby == 0 then
				inLobby(function(parent)
					return text(
						"Empty",
						parent,
						`Wala pa. Lumapit ({Talon.JoinDistance} studs) sa kaibigang nagho-host.`,
						14
					)
				end, nextOrder())
			end
			for _, info in nearby do
				local status = if info.Playing
					then "Naglalaro"
					elseif info.Count >= Talon.MaxPlayers then "Puno"
					else nil
				local r = row(
					tostring(info.HostId),
					nextOrder(),
					`{info.HostName}  {info.Count}/{Talon.MaxPlayers}`,
					status
				)
				if not status then
					local join = PhoneUi.button("Join", r)
					join.AnchorPoint = Vector2.new(1, 0.5)
					join.Position = UDim2.new(1, -8, 0.5, 0)
					join.Size = UDim2.fromOffset(64, 32)
					join.BackgroundColor3 = PhoneUi.WHITE
					join.TextColor3 = PhoneUi.INK
					join.TextSize = 14
					join.Text = "Join"
					PhoneUi.corner(join)
					join.Activated:Connect(function()
						TalonController.join(info.HostId)
					end)
				end
			end
		else
			inLobby(function(parent)
				return text("Heading", parent, `RACE ROOM  {#room.Members}/{Talon.MaxPlayers}`, 12)
			end, nextOrder())
			for _, member in room.Members do
				row(
					tostring(member.UserId),
					nextOrder(),
					if member.UserId == me.UserId then `{member.Name} (ikaw)` else member.Name,
					if member.UserId == room.HostId then "Host" else nil
				)
			end
			if room.Playing then
				inLobby(function(parent)
					return text("Status", parent, "May race na nagaganap.", 14)
				end, nextOrder())
			elseif room.HostId == me.UserId then
				local ready = #room.Members >= 2
				inLobby(function(parent)
					local b = wideButton(
						"Start",
						parent,
						if ready then "Simulan ang race" else "Hinihintay ang players…",
						ready
					)
					b.Activated:Connect(function()
						if ready then
							TalonController.startRace()
						end
					end)
					return b
				end, nextOrder())
			else
				inLobby(function(parent)
					return text("Status", parent, "Hinihintay ang host na mag-start.", 14)
				end, nextOrder())
			end
			inLobby(function(parent)
				local b = wideButton("Leave", parent, "Umalis sa room", false)
				b.Activated:Connect(TalonController.leave)
				return b
			end, nextOrder())
		end
		inLobby(function(parent)
			local b = wideButton("Back", parent, "‹ Menu", false)
			b.Activated:Connect(function()
				if TalonController.getRoom() then
					TalonController.leave()
				end
				showScreen("Menu")
			end)
			return b
		end, nextOrder())
	end

	-- Wiring ---------------------------------------------------------------------------------
	singleButton.Activated:Connect(function()
		showSingleReady()
		showScreen("Play")
	end)
	raceButton.Activated:Connect(function()
		showScreen("Lobby")
	end)
	menuButton.Activated:Connect(function()
		if mode == "Single" and state == "Playing" then
			state = "Paused"
		end
		showScreen("Menu")
	end)
	for _, button in { view, jumpButton } do
		button.MouseButton1Down:Connect(function()
			holding = true
			jump()
		end)
		button.MouseButton1Up:Connect(function()
			holding = false
		end)
		button.MouseLeave:Connect(function()
			holding = false
		end)
	end
	cardButton.Activated:Connect(function()
		holding = false
		local action = cardAction
		if action then
			action()
		end
	end)

	TalonController.NearbyChanged:Connect(function()
		if currentScreen == "Lobby" then
			renderLobby()
		end
	end)
	TalonController.RoomChanged:Connect(function()
		if currentScreen == "Lobby" then
			renderLobby()
		end
		refreshBrowse()
	end)
	TalonController.RaceMessage:Connect(function(kind: string, a: any, b: any)
		if kind == "Start" and typeof(a) == "number" and typeof(b) == "number" then
			startRace(a, b)
		elseif kind == "Progress" and mode == "Race" then
			local ghost = ghosts[a]
			if ghost and typeof(b) == "number" then
				ghost.target = b
			end
		elseif kind == "Winner" and mode == "Race" then
			state = "Over"
			local won = a == me.UserId
			local title = if won
				then "🏆 Panalo ka!"
				elseif a == 0 then "Walang nanalo"
				else "🏁 Tapos na!"
			local body = if won
				then "Ikaw ang unang nakarating sa finish line!"
				elseif a == 0 then "Naubos ang oras ng race."
				else `Nauna si {b} sa finish line.`
			showCard(title, body, "Bumalik sa room", backToRoom)
		end
	end)

	activeChanged = function()
		refreshBinding()
		refreshBrowse()
		if not onScreen and mode == "Single" and state == "Playing" then
			state = "Paused"
			showCard(
				"Naka-pause",
				`{math.floor(distance / PX_PER_METER)} m na. Tuloy?`,
				"Ituloy",
				function()
					state = "Playing"
					hideCard()
				end
			)
		end
	end

	RunService.RenderStepped:Connect(function(dt: number)
		if onScreen and currentScreen == "Play" then
			step(dt)
		end
	end)

	showScreen("Menu")
end

return TalonApp
