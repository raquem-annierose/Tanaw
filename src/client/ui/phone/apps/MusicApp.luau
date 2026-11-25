--!strict
-- Music app: the song playing on Tanaw Radio, how far into it we are, and this player's
-- controls: Mute, Skip (vote to skip for everyone, shows who asked) and Volume.
-- Drag (or tap) the volume slider. Gamepad: select the slider and press left/right.

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MusicController =
	require(script.Parent.Parent.Parent.Parent.controllers.music.MusicController)
local PhoneUi = require(script.Parent.Parent.PhoneUi)

local GAMEPAD_STEP = 0.1
local SIDE = 24

local MusicApp = {}

local function formatTime(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

local function pill(name: string, parent: Instance, text: string, primary: boolean): TextButton
	local b = PhoneUi.button(name, parent)
	b.Size = UDim2.fromOffset(78, 40)
	b.BackgroundColor3 = PhoneUi.WHITE
	b.BackgroundTransparency = if primary then 0 else 0.86
	b.TextColor3 = if primary then PhoneUi.INK else PhoneUi.WHITE
	b.TextSize = 15
	b.Text = text
	PhoneUi.corner(b)
	return b
end

function MusicApp.build(page: Frame, goHome: () -> ())
	PhoneUi.header(page, "Music", goHome)

	-- Cover: plain sunset gradient with a small wordmark.
	local art = PhoneUi.frame("Art", page)
	art.AnchorPoint = Vector2.new(0.5, 0)
	art.Position = UDim2.new(0.5, 0, 0, 56)
	art.Size = UDim2.fromOffset(196, 196)
	art.BackgroundTransparency = 0
	art.BackgroundColor3 = PhoneUi.WHITE
	PhoneUi.corner(art, UDim.new(0, 20))
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(44, 40, 96)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(190, 84, 140)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 170, 110)),
	})
	gradient.Parent = art
	local wordmark = PhoneUi.label("Wordmark", art, "tanaw radio", 14)
	wordmark.Position = UDim2.new(0, 14, 1, -30)
	wordmark.Size = UDim2.new(1, -28, 0, 18)
	wordmark.TextXAlignment = Enum.TextXAlignment.Left
	wordmark.TextTransparency = 0.15

	local title = PhoneUi.label("Song", page, "", 20)
	title.Position = UDim2.fromOffset(SIDE, 266)
	title.Size = UDim2.new(1, -SIDE * 2, 0, 24)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local source = PhoneUi.label("Source", page, "", 14)
	source.Position = UDim2.fromOffset(SIDE, 290)
	source.Size = UDim2.new(1, -SIDE * 2, 0, 18)
	source.FontFace = PhoneUi.FONT_REGULAR
	source.TextXAlignment = Enum.TextXAlignment.Left
	source.TextTransparency = 0.4

	-- Progress through the song.
	local progress = PhoneUi.frame("Progress", page)
	progress.Position = UDim2.fromOffset(SIDE, 320)
	progress.Size = UDim2.new(1, -SIDE * 2, 0, 3)
	progress.BackgroundTransparency = 0.8
	progress.BackgroundColor3 = PhoneUi.WHITE
	PhoneUi.corner(progress)
	local played = PhoneUi.frame("Played", progress)
	played.BackgroundTransparency = 0
	played.BackgroundColor3 = PhoneUi.WHITE
	PhoneUi.corner(played)

	local elapsed = PhoneUi.label("Elapsed", page, "0:00", 11)
	elapsed.Position = UDim2.fromOffset(SIDE, 328)
	elapsed.Size = UDim2.fromOffset(60, 14)
	elapsed.FontFace = PhoneUi.FONT_REGULAR
	elapsed.TextXAlignment = Enum.TextXAlignment.Left
	elapsed.TextTransparency = 0.4

	local total = PhoneUi.label("Total", page, "0:00", 11)
	total.AnchorPoint = Vector2.new(1, 0)
	total.Position = UDim2.new(1, -SIDE, 0, 328)
	total.Size = UDim2.fromOffset(60, 14)
	total.FontFace = PhoneUi.FONT_REGULAR
	total.TextXAlignment = Enum.TextXAlignment.Right
	total.TextTransparency = 0.4

	-- Controls row: [Mute] [Next] (+ [Live] while off the radio).
	local controls = PhoneUi.frame("Controls", page)
	controls.Position = UDim2.fromOffset(SIDE, 352)
	controls.Size = UDim2.new(1, -SIDE * 2, 0, 40)
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.HorizontalAlignment = Enum.HorizontalAlignment.Center
	row.Padding = UDim.new(0, 10)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = controls

	local mute = pill("Mute", controls, "Mute", false)
	mute.LayoutOrder = 1
	local skip = pill("Skip", controls, "Skip", true)
	skip.LayoutOrder = 2
	skip.Size = UDim2.fromOffset(110, 40)

	mute.Activated:Connect(MusicController.toggleMute)
	skip.Activated:Connect(MusicController.voteSkip)

	-- Who asked to skip, e.g. "ywro wants to skip".
	local skipStatus = PhoneUi.label("SkipStatus", page, "", 12)
	skipStatus.Position = UDim2.fromOffset(SIDE, 396)
	skipStatus.Size = UDim2.new(1, -SIDE * 2, 0, 16)
	skipStatus.FontFace = PhoneUi.FONT_REGULAR
	skipStatus.TextColor3 = PhoneUi.ACCENT

	local function refreshSkip(state: MusicController.SkipState)
		if state.Votes == 0 then
			skip.Text = "Skip"
			skipStatus.Text = ""
		else
			skip.Text = if state.Voted
				then `Voted {state.Votes}/{state.Needed}`
				else `Skip {state.Votes}/{state.Needed}`
			skipStatus.Text = if state.Votes == 1
				then `{state.By} wants to skip`
				else `{state.By} and {state.Votes - 1} more want to skip`
		end
		-- Voted: outlined look; tap again to take the vote back.
		skip.BackgroundTransparency = if state.Voted then 0.86 else 0
		skip.TextColor3 = if state.Voted then PhoneUi.WHITE else PhoneUi.INK
	end
	MusicController.SkipChanged:Connect(refreshSkip)
	refreshSkip(MusicController.getSkip())

	-- Volume.
	local volumeCaption = PhoneUi.label("VolumeCaption", page, "Volume", 12)
	volumeCaption.Position = UDim2.fromOffset(SIDE, 418)
	volumeCaption.Size = UDim2.fromOffset(80, 14)
	volumeCaption.FontFace = PhoneUi.FONT_REGULAR
	volumeCaption.TextXAlignment = Enum.TextXAlignment.Left
	volumeCaption.TextTransparency = 0.4

	-- The hit area is taller than the track so it's easy to grab on touch.
	local slider = PhoneUi.button("Volume", page)
	slider.Position = UDim2.fromOffset(SIDE, 432)
	slider.Size = UDim2.new(1, -SIDE * 2, 0, 28)
	slider.BackgroundTransparency = 1

	local track = PhoneUi.frame("Track", slider)
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.fromScale(0, 0.5)
	track.Size = UDim2.new(1, 0, 0, 4)
	track.BackgroundTransparency = 0.8
	track.BackgroundColor3 = PhoneUi.WHITE
	PhoneUi.corner(track)

	local fill = PhoneUi.frame("Fill", track)
	fill.BackgroundTransparency = 0
	fill.BackgroundColor3 = PhoneUi.ACCENT
	PhoneUi.corner(fill)

	local knob = PhoneUi.frame("Knob", track)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(16, 16)
	knob.BackgroundTransparency = 0
	knob.BackgroundColor3 = PhoneUi.WHITE
	PhoneUi.corner(knob)

	source.Text = "Tanaw Radio · Live"

	local function refresh(songTitle: string?, level: number, muted: boolean)
		title.Text = songTitle or "Loading…"
		title.TextTransparency = if muted then 0.4 else 0
		local shown = if muted then 0 else level
		fill.Size = UDim2.fromScale(shown, 1)
		knob.Position = UDim2.fromScale(shown, 0.5)
		mute.Text = if muted then "Unmute" else "Mute"
	end
	MusicController.Changed:Connect(refresh)
	refresh(MusicController.getCurrent())

	local dragging: InputObject? = nil
	local function setFromX(x: number)
		local width = math.max(track.AbsoluteSize.X, 1)
		MusicController.setLevel((x - track.AbsolutePosition.X) / width)
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

	-- Progress only updates while the app is on screen.
	RunService.RenderStepped:Connect(function()
		if not page.Visible then
			return
		end
		local position, length = MusicController.getProgress()
		played.Size =
			UDim2.fromScale(if length > 0 then math.clamp(position / length, 0, 1) else 0, 1)
		elapsed.Text = formatTime(position)
		total.Text = formatTime(length)
	end)
end

return MusicApp
