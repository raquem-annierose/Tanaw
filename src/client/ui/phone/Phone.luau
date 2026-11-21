--!strict
-- Every player's in-game phone. A 📱 button on the right edge of the screen opens it.
--
-- Home screen: clock, date and the apps:
--   Camera  - selfie / normal camera with a shutter that saves to Roblox Captures (CameraApp)
--   Music   - Tanaw Radio song, volume and mute (MusicApp)
--   Emotes  - wave, dance, ... (EmotesApp)
-- The white bar at the bottom goes back home; the 📱 button closes the phone.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CameraApp = require(script.Parent.CameraApp)
local EmotesApp = require(script.Parent.EmotesApp)
local MusicApp = require(script.Parent.MusicApp)
local PhoneUi = require(script.Parent.PhoneUi)

local PHONE_SIZE = Vector2.new(300, 620)
local BEZEL = 10
local STATUS_HEIGHT = 44
local HOME_BAR_HEIGHT = 28
-- Gap between the phone and the right edge of the screen (room for the 📱 button).
local RIGHT_GAP = 80
local OPEN_TIME = 0.35

local DAYS = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
local MONTHS = {
	"January",
	"February",
	"March",
	"April",
	"May",
	"June",
	"July",
	"August",
	"September",
	"October",
	"November",
	"December",
}

type AppInfo = {
	Id: string,
	Label: string,
	Icon: string,
	Top: Color3,
	Bottom: Color3,
}

local APPS: { AppInfo } = {
	{
		Id = "Camera",
		Label = "Camera",
		Icon = "📷",
		Top = Color3.fromRGB(80, 80, 92),
		Bottom = Color3.fromRGB(34, 34, 40),
	},
	{
		Id = "Music",
		Label = "Music",
		Icon = "🎵",
		Top = Color3.fromRGB(255, 110, 140),
		Bottom = Color3.fromRGB(200, 50, 100),
	},
	{
		Id = "Emotes",
		Label = "Emotes",
		Icon = "💃",
		Top = Color3.fromRGB(255, 200, 120),
		Bottom = Color3.fromRGB(236, 130, 70),
	},
}

local Phone = {}

local isOpen = false
local phoneFrame: Frame? = nil
local pages: { [string]: Frame } = {}
local openTween: Tween? = nil

local function gradient(parent: GuiObject, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = parent
end

local function showPage(id: string)
	for pageId, page in pages do
		page.Visible = pageId == id
	end
end

local function goHome()
	showPage("Home")
end

local function slide(open: boolean)
	local frame = phoneFrame
	if not frame then
		return
	end
	if openTween then
		openTween:Cancel()
	end
	local target = if open
		then UDim2.new(1, -RIGHT_GAP, 0.5, 0)
		else UDim2.new(1, -RIGHT_GAP, 1.6, 0)
	if open then
		frame.Visible = true
	end
	local tween = TweenService:Create(
		frame,
		TweenInfo.new(OPEN_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Position = target }
	)
	openTween = tween
	tween.Completed:Connect(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed and not open then
			frame.Visible = false
		end
	end)
	tween:Play()
end

function Phone.open()
	if CameraApp.isOpen() then
		CameraApp.close()
		return
	end
	isOpen = true
	slide(true)
end

function Phone.close()
	isOpen = false
	slide(false)
end

function Phone.toggle()
	if isOpen then
		Phone.close()
	else
		Phone.open()
	end
end

local function openApp(id: string)
	if id == "Camera" then
		Phone.close()
		CameraApp.open()
	else
		showPage(id)
	end
end

local function buildHome(page: Frame)
	local clock = PhoneUi.label("Clock", page, "", 72)
	clock.Position = UDim2.fromOffset(0, 24)
	clock.Size = UDim2.new(1, 0, 0, 80)

	local date = PhoneUi.label("Date", page, "", 18)
	date.Position = UDim2.fromOffset(0, 104)
	date.Size = UDim2.new(1, 0, 0, 22)
	date.FontFace = PhoneUi.FONT_REGULAR

	local function tick()
		local now = os.date("*t")
		clock.Text = string.format("%d:%02d", now.hour % 12 == 0 and 12 or now.hour % 12, now.min)
		date.Text = `{DAYS[now.wday]}, {MONTHS[now.month]} {now.day}`
	end
	tick()
	task.spawn(function()
		while true do
			task.wait(10)
			tick()
		end
	end)

	-- App dock near the bottom, frosted like an iPhone dock.
	local dock = PhoneUi.frame("Dock", page)
	dock.AnchorPoint = Vector2.new(0.5, 1)
	dock.Position = UDim2.new(0.5, 0, 1, -12)
	dock.Size = UDim2.new(1, -24, 0, 104)
	dock.BackgroundTransparency = 0.75
	dock.BackgroundColor3 = PhoneUi.WHITE
	PhoneUi.corner(dock, UDim.new(0, 30))

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 18)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = dock

	for order, app in APPS do
		local holder = PhoneUi.frame(app.Id, dock)
		holder.LayoutOrder = order
		holder.Size = UDim2.fromOffset(64, 84)

		local icon = PhoneUi.button("Icon", holder)
		icon.Size = UDim2.fromOffset(64, 64)
		icon.BackgroundColor3 = PhoneUi.WHITE
		icon.Text = app.Icon
		icon.TextSize = 32
		PhoneUi.corner(icon, UDim.new(0, 16))
		gradient(icon, app.Top, app.Bottom)
		icon.Activated:Connect(function()
			openApp(app.Id)
		end)

		local name = PhoneUi.label("Label", holder, app.Label, 13)
		name.Position = UDim2.fromOffset(-8, 66)
		name.Size = UDim2.fromOffset(80, 16)
	end
end

function Phone.start()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "Phone"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 4

	-- 📱 button on the right edge, clear of the jump button (bottom right) and player list.
	local toggle = PhoneUi.button("PhoneButton", gui)
	toggle.AnchorPoint = Vector2.new(1, 0.5)
	toggle.Position = UDim2.new(1, -12, 0.5, 0)
	toggle.Size = UDim2.fromOffset(52, 52)
	toggle.BackgroundColor3 = PhoneUi.INK
	toggle.BackgroundTransparency = 0.3
	toggle.Text = "📱"
	toggle.TextSize = 26
	PhoneUi.corner(toggle)
	local toggleStroke = Instance.new("UIStroke")
	toggleStroke.Color = PhoneUi.WHITE
	toggleStroke.Transparency = 0.8
	toggleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	toggleStroke.Parent = toggle
	toggle.Activated:Connect(Phone.toggle)

	-- Phone body (bezel) -------------------------------------------------------------------------
	local body = PhoneUi.frame("Phone", gui)
	body.AnchorPoint = Vector2.new(1, 0.5)
	body.Position = UDim2.new(1, -RIGHT_GAP, 1.6, 0)
	body.Size = UDim2.fromOffset(PHONE_SIZE.X, PHONE_SIZE.Y)
	body.BackgroundTransparency = 0
	body.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
	body.Visible = false
	body.Active = true
	PhoneUi.corner(body, UDim.new(0, 46))
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(120, 116, 130)
	edge.Thickness = 2
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = body
	phoneFrame = body

	-- Shrink the phone on small screens so it always fits.
	local scale = Instance.new("UIScale")
	scale.Parent = body
	local function fit()
		local camera = Workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 720
		scale.Scale = math.clamp((height - 60) / PHONE_SIZE.Y, 0.5, 1)
	end
	fit()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	-- Screen with a Tanaw blue-hour wallpaper -----------------------------------------------------
	local screen = PhoneUi.frame("Screen", body)
	screen.Position = UDim2.fromOffset(BEZEL, BEZEL)
	screen.Size = UDim2.new(1, -BEZEL * 2, 1, -BEZEL * 2)
	screen.BackgroundTransparency = 0
	screen.BackgroundColor3 = PhoneUi.WHITE
	screen.ClipsDescendants = true
	PhoneUi.corner(screen, UDim.new(0, 38))
	local wallpaper = Instance.new("UIGradient")
	wallpaper.Rotation = 90
	wallpaper.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 28, 70)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(96, 56, 128)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(214, 96, 132)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 168, 112)),
	})
	wallpaper.Parent = screen

	-- Status bar: time, island, signal/battery.
	local island = PhoneUi.frame("Island", screen)
	island.AnchorPoint = Vector2.new(0.5, 0)
	island.Position = UDim2.new(0.5, 0, 0, 10)
	island.Size = UDim2.fromOffset(86, 24)
	island.BackgroundTransparency = 0
	island.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	PhoneUi.corner(island)

	local statusTime = PhoneUi.label("Time", screen, "", 14)
	statusTime.Position = UDim2.fromOffset(22, 12)
	statusTime.Size = UDim2.fromOffset(60, 20)
	statusTime.TextXAlignment = Enum.TextXAlignment.Left

	local statusRight = PhoneUi.label("Status", screen, "Tanaw  ▂▄▆  🔋", 12)
	statusRight.AnchorPoint = Vector2.new(1, 0)
	statusRight.Position = UDim2.new(1, -18, 0, 12)
	statusRight.Size = UDim2.fromOffset(100, 20)
	statusRight.TextXAlignment = Enum.TextXAlignment.Right

	task.spawn(function()
		while true do
			local now = os.date("*t")
			statusTime.Text =
				string.format("%d:%02d", now.hour % 12 == 0 and 12 or now.hour % 12, now.min)
			task.wait(10)
		end
	end)

	-- Pages ------------------------------------------------------------------------------------
	local content = PhoneUi.frame("Pages", screen)
	content.Position = UDim2.fromOffset(0, STATUS_HEIGHT)
	content.Size = UDim2.new(1, 0, 1, -STATUS_HEIGHT - HOME_BAR_HEIGHT)

	local function newPage(id: string, dim: boolean): Frame
		local page = PhoneUi.frame(id, content)
		page.Size = UDim2.fromScale(1, 1)
		page.Visible = false
		if dim then
			-- Darker backdrop inside apps so text stays readable over the wallpaper.
			page.BackgroundTransparency = 0.35
			page.BackgroundColor3 = PhoneUi.INK
		end
		pages[id] = page
		return page
	end

	buildHome(newPage("Home", false))
	MusicApp.build(newPage("Music", true), goHome)
	EmotesApp.build(newPage("Emotes", true), goHome)
	showPage("Home")

	-- Home bar: tap to go back to the home screen.
	local homeBar = PhoneUi.button("HomeBar", screen)
	homeBar.AnchorPoint = Vector2.new(0.5, 1)
	homeBar.Position = UDim2.new(0.5, 0, 1, 0)
	homeBar.Size = UDim2.new(1, 0, 0, HOME_BAR_HEIGHT)
	homeBar.BackgroundTransparency = 1
	local pill = PhoneUi.frame("Pill", homeBar)
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.fromScale(0.5, 0.5)
	pill.Size = UDim2.fromOffset(110, 5)
	pill.BackgroundTransparency = 0
	pill.BackgroundColor3 = PhoneUi.WHITE
	PhoneUi.corner(pill)
	homeBar.Activated:Connect(goHome)

	CameraApp.start(function()
		goHome()
		Phone.open()
	end)

	gui.Parent = playerGui
end

return Phone
