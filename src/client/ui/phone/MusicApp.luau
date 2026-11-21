--!strict
-- Music app: what Tanaw Radio is playing, plus this player's volume slider and mute.
-- Drag (or tap) the slider. Gamepad: select the slider and press left/right.

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local MusicController = require(script.Parent.Parent.Parent.controllers.MusicController)
local PhoneUi = require(script.Parent.PhoneUi)

local GAMEPAD_STEP = 0.1

local MusicApp = {}

function MusicApp.build(page: Frame, goHome: () -> ())
	PhoneUi.header(page, "Music", goHome)

	-- "Album art": sunset card with a bouncing equalizer.
	local art = PhoneUi.frame("Art", page)
	art.AnchorPoint = Vector2.new(0.5, 0)
	art.Position = UDim2.new(0.5, 0, 0, 56)
	art.Size = UDim2.fromOffset(200, 200)
	art.BackgroundTransparency = 0
	art.BackgroundColor3 = PhoneUi.WHITE
	PhoneUi.corner(art, UDim.new(0, 24))
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(44, 40, 96)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(190, 84, 140)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 170, 110)),
	})
	gradient.Parent = art

	local bars: { Frame } = {}
	for i = 1, 5 do
		local bar = PhoneUi.frame(`Bar{i}`, art)
		bar.AnchorPoint = Vector2.new(0.5, 1)
		bar.Position = UDim2.new(0.5, (i - 3) * 22, 1, -40)
		bar.Size = UDim2.fromOffset(12, 10)
		bar.BackgroundTransparency = 0
		bar.BackgroundColor3 = PhoneUi.WHITE
		PhoneUi.corner(bar)
		bars[i] = bar
	end

	local caption = PhoneUi.label("Caption", page, "TANAW RADIO", 13)
	caption.Position = UDim2.fromOffset(24, 272)
	caption.Size = UDim2.new(1, -48, 0, 16)
	caption.TextColor3 = PhoneUi.ACCENT
	caption.TextXAlignment = Enum.TextXAlignment.Left

	local title = PhoneUi.label("Song", page, "", 22)
	title.Position = UDim2.fromOffset(24, 290)
	title.Size = UDim2.new(1, -48, 0, 28)
	title.TextXAlignment = Enum.TextXAlignment.Left

	-- Volume slider. The hit area is taller than the track so it's easy to grab on touch.
	local slider = PhoneUi.button("Volume", page)
	slider.Position = UDim2.fromOffset(24, 336)
	slider.Size = UDim2.new(1, -48, 0, 32)
	slider.BackgroundTransparency = 1

	local track = PhoneUi.frame("Track", slider)
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.fromScale(0, 0.5)
	track.Size = UDim2.new(1, 0, 0, 6)
	track.BackgroundTransparency = 0.75
	track.BackgroundColor3 = PhoneUi.WHITE
	PhoneUi.corner(track)

	local fill = PhoneUi.frame("Fill", track)
	fill.BackgroundTransparency = 0
	fill.BackgroundColor3 = PhoneUi.ACCENT
	PhoneUi.corner(fill)

	local knob = PhoneUi.frame("Knob", track)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(18, 18)
	knob.BackgroundTransparency = 0
	knob.BackgroundColor3 = PhoneUi.WHITE
	PhoneUi.corner(knob)

	local mute = PhoneUi.button("Mute", page)
	mute.AnchorPoint = Vector2.new(0.5, 0)
	mute.Position = UDim2.new(0.5, 0, 0, 384)
	mute.Size = UDim2.fromOffset(64, 64)
	mute.BackgroundColor3 = PhoneUi.WHITE
	mute.BackgroundTransparency = 0.85
	mute.TextSize = 28
	PhoneUi.corner(mute)

	local isMuted = false
	local function refresh(songTitle: string?, level: number, muted: boolean)
		isMuted = muted
		title.Text = songTitle or "Loading…"
		title.TextTransparency = if muted then 0.4 else 0
		local shown = if muted then 0 else level
		fill.Size = UDim2.fromScale(shown, 1)
		knob.Position = UDim2.fromScale(shown, 0.5)
		mute.Text = if muted then "🔇" else "🔊"
	end
	MusicController.Changed:Connect(refresh)
	refresh(MusicController.getCurrent())

	mute.Activated:Connect(function()
		MusicController.toggleMute()
	end)

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

	-- Equalizer bounces while music is audible and the app is on screen.
	local clock = 0
	RunService.RenderStepped:Connect(function(dt: number)
		if not page.Visible then
			return
		end
		clock += dt
		for i, bar in bars do
			local height = 10
			if not isMuted then
				height = 14 + 60 * math.abs(math.sin(clock * (1.8 + i * 0.7) + i * 1.3))
			end
			bar.Size = UDim2.fromOffset(12, height)
		end
	end)
end

return MusicApp
