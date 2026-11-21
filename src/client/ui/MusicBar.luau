--!strict
-- "Now playing" card in the top-right of the Roblox top bar, above the player list:
--   [equalizer] TANAW RADIO / song title   [volume slider] [mute]
-- Drag (or tap) the slider to set this player's volume. Gamepad: select the slider and press
-- left/right.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MusicController = require(script.Parent.Parent.controllers.MusicController)

local HEIGHT = 40
local TEXT_WIDTH = 140
local SLIDER_WIDTH = 72
local GAMEPAD_STEP = 0.1

local WHITE = Color3.fromRGB(255, 255, 255)
-- Warm string-light color, same mood as the overlook.
local ACCENT = Color3.fromRGB(255, 200, 120)

local MusicBar = {}

local function corner(parent: Instance, radius: UDim?)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(1, 0)
	c.Parent = parent
end

local function frame(name: string, parent: Instance): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function label(name: string, parent: Instance): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.TextColor3 = WHITE
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

function MusicBar.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "MusicBar"
	gui.ResetOnSpawn = false
	-- Lives in the top bar strip, clear of Roblox's own buttons.
	gui.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Card ------------------------------------------------------------------------------------
	local card = frame("Card", gui)
	card.AnchorPoint = Vector2.new(1, 0.5)
	card.Position = UDim2.new(1, 0, 0.5, 0)
	card.AutomaticSize = Enum.AutomaticSize.X
	card.Size = UDim2.new(0, 0, 0, HEIGHT)
	card.BackgroundColor3 = Color3.fromRGB(16, 14, 22)
	card.BackgroundTransparency = 0.3
	corner(card)

	local stroke = Instance.new("UIStroke")
	stroke.Color = WHITE
	stroke.Transparency = 0.85
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = card

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 4)
	padding.Parent = card

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = card

	-- Equalizer --------------------------------------------------------------------------------
	local eqButton = frame("Equalizer", card)
	eqButton.LayoutOrder = 1
	eqButton.Size = UDim2.new(0, 30, 0, 30)
	eqButton.BackgroundColor3 = ACCENT
	eqButton.BackgroundTransparency = 0.8
	corner(eqButton)

	local bars: { Frame } = {}
	for i = 1, 3 do
		local bar = frame(`Bar{i}`, eqButton)
		bar.AnchorPoint = Vector2.new(0.5, 1)
		bar.Position = UDim2.new(0.5, (i - 2) * 6, 0.5, 7)
		bar.Size = UDim2.new(0, 3, 0, 4)
		bar.BackgroundColor3 = ACCENT
		corner(bar)
		bars[i] = bar
	end

	-- Title ------------------------------------------------------------------------------------
	local text = frame("Text", card)
	text.LayoutOrder = 2
	text.Size = UDim2.new(0, TEXT_WIDTH, 1, 0)
	text.BackgroundTransparency = 1

	local caption = label("Caption", text)
	caption.Position = UDim2.new(0, 0, 0, 6)
	caption.Size = UDim2.new(1, 0, 0, 12)
	caption.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
	caption.TextSize = 11
	caption.Text = "TANAW RADIO"
	caption.TextTransparency = 0.45

	local title = label("Title", text)
	title.Position = UDim2.new(0, 0, 0, 19)
	title.Size = UDim2.new(1, 0, 0, 18)
	title.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
	title.TextSize = 15

	-- Volume slider ----------------------------------------------------------------------------
	-- The hit area is taller than the track so it's easy to grab on touch screens.
	local slider = Instance.new("TextButton")
	slider.Name = "Volume"
	slider.LayoutOrder = 3
	slider.Size = UDim2.new(0, SLIDER_WIDTH, 1, 0)
	slider.BackgroundTransparency = 1
	slider.Text = ""
	slider.AutoButtonColor = false
	slider.Selectable = true
	slider.Parent = card

	local track = frame("Track", slider)
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, 0, 0.5, 0)
	track.Size = UDim2.new(1, 0, 0, 4)
	track.BackgroundColor3 = WHITE
	track.BackgroundTransparency = 0.8
	corner(track)

	local fill = frame("Fill", track)
	fill.BackgroundColor3 = ACCENT
	corner(fill)

	local knob = frame("Knob", track)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.new(0, 12, 0, 12)
	knob.BackgroundColor3 = WHITE
	corner(knob)

	-- Mute button -------------------------------------------------------------------------------
	local muteButton = Instance.new("TextButton")
	muteButton.Name = "Mute"
	muteButton.LayoutOrder = 4
	muteButton.Size = UDim2.new(0, 32, 0, 32)
	muteButton.BackgroundColor3 = WHITE
	muteButton.BackgroundTransparency = 0.9
	muteButton.AutoButtonColor = true
	muteButton.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
	muteButton.TextSize = 16
	muteButton.TextColor3 = WHITE
	muteButton.Selectable = true
	corner(muteButton)
	muteButton.Parent = card

	-- Behaviour ---------------------------------------------------------------------------------
	local isMuted = false

	local function refresh(songTitle: string?, level: number, muted: boolean)
		isMuted = muted
		title.Text = songTitle or "Naglo-load…"
		title.TextTransparency = if muted then 0.4 else 0
		local shown = if muted then 0 else level
		fill.Size = UDim2.new(shown, 0, 1, 0)
		knob.Position = UDim2.new(shown, 0, 0.5, 0)
		eqButton.BackgroundTransparency = if muted then 0.92 else 0.8
		muteButton.Text = if muted then "🔇" else "🔊"
	end
	MusicController.Changed:Connect(refresh)
	refresh(MusicController.getCurrent())

	muteButton.Activated:Connect(function()
		MusicController.toggleMute()
	end)

	local dragging: InputObject? = nil

	local function setFromX(x: number)
		local left = track.AbsolutePosition.X
		local width = math.max(track.AbsoluteSize.X, 1)
		MusicController.setLevel((x - left) / width)
	end

	slider.InputBegan:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = input
			setFromX(input.Position.X)
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if not dragging then
			return
		end
		local isMouseDrag = dragging.UserInputType == Enum.UserInputType.MouseButton1
			and input.UserInputType == Enum.UserInputType.MouseMovement
		if isMouseDrag or input == dragging then
			setFromX(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input == dragging then
			dragging = nil
		end
	end)

	-- Gamepad: left/right on the selected slider.
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if GuiService.SelectedObject ~= slider then
			return
		end
		local _, level, muted = MusicController.getCurrent()
		local current = if muted then 0 else level
		if input.KeyCode == Enum.KeyCode.DPadRight then
			MusicController.setLevel(current + GAMEPAD_STEP)
		elseif input.KeyCode == Enum.KeyCode.DPadLeft then
			MusicController.setLevel(current - GAMEPAD_STEP)
		end
	end)

	-- Equalizer bars bounce while music is audible, and lie flat when muted.
	local clock = 0
	RunService.RenderStepped:Connect(function(dt: number)
		clock += dt
		for i, bar in bars do
			local height = 4
			if not isMuted then
				height = 5 + 9 * math.abs(math.sin(clock * (2.2 + i * 0.9) + i * 1.3))
			end
			bar.Size = UDim2.new(0, 3, 0, height)
		end
	end)

	gui.Parent = playerGui
end

return MusicBar
