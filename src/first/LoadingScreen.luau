--!strict
-- Full-screen loading screen with a progress bar.
--
-- Runs from ReplicatedFirst, before every other script, so it covers the screen while the
-- hilltop, the city in the distance and the player's character load. With StreamingEnabled the
-- city (Surroundings/City and Surroundings/MidGround, both Persistent) can arrive a moment after joining; this keeps it
-- hidden until it's there, then fades into the spawn view. It never waits longer than
-- MAX_WAIT_SECONDS, so a slow connection still gets into the game.
--
-- ReplicatedStorage may not have arrived yet when this runs, so settings live here instead of
-- in Shared/Config.

local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BACKGROUND_IMAGE = "rbxassetid://98549300498503"
local TITLE = "Tanaw"
local SUBTITLE = "Café & City Lights"

local MAX_WAIT_SECONDS = 30
local ASSET_WAIT_SECONDS = 10
local FADE_SECONDS = 0.8
-- How long the city must stop growing before it counts as loaded.
local SETTLE_SECONDS = 0.5

local BACKDROP = Color3.fromRGB(28, 20, 48) -- shown until the image has downloaded
local BAR_TRACK = Color3.fromRGB(0, 0, 0)
local BAR_FILL = Color3.fromRGB(255, 214, 140) -- warm string-light glow
local TEXT = Color3.fromRGB(255, 255, 255)

local LoadingScreen = {}

type Ui = {
	gui: ScreenGui,
	background: ImageLabel,
	fill: Frame,
	percent: TextLabel,
	status: TextLabel,
}

local function round(parent: Instance, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent
end

local function label(name: string, text: string, size: number, weight: Enum.FontWeight): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.TextColor3 = TEXT
	l.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", weight)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Size = UDim2.new(1, 0, 0, size + 4)
	local shadow = Instance.new("UIStroke")
	shadow.Color = Color3.fromRGB(0, 0, 0)
	shadow.Transparency = 0.6
	shadow.Thickness = 1.5
	shadow.Parent = l
	return l
end

local function build(): Ui
	local gui = Instance.new("ScreenGui")
	gui.Name = "LoadingScreen"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.DisplayOrder = 1000
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local background = Instance.new("ImageLabel")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = BACKDROP
	background.BorderSizePixel = 0
	background.Image = BACKGROUND_IMAGE
	background.ScaleType = Enum.ScaleType.Crop
	background.Parent = gui

	-- Darker toward the bottom so the text and bar stay readable over the art.
	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shade.BorderSizePixel = 0
	shade.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.55, 1),
		NumberSequenceKeypoint.new(1, 0.35),
	})
	gradient.Parent = shade

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -40)
	panel.Size = UDim2.new(0.8, 0, 0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundTransparency = 1
	panel.Parent = gui
	local width = Instance.new("UISizeConstraint")
	width.MaxSize = Vector2.new(560, math.huge)
	width.Parent = panel
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = panel

	local title = label("Title", TITLE, 44, Enum.FontWeight.ExtraBold)
	title.LayoutOrder = 1
	title.Parent = panel

	local subtitle = label("Subtitle", SUBTITLE, 20, Enum.FontWeight.SemiBold)
	subtitle.LayoutOrder = 2
	subtitle.Parent = panel

	local spacer = Instance.new("Frame")
	spacer.Name = "Spacer"
	spacer.LayoutOrder = 3
	spacer.BackgroundTransparency = 1
	spacer.Size = UDim2.new(1, 0, 0, 10)
	spacer.Parent = panel

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.LayoutOrder = 4
	track.Size = UDim2.new(1, 0, 0, 12)
	track.BackgroundColor3 = BAR_TRACK
	track.BackgroundTransparency = 0.45
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	round(track, UDim.new(1, 0))
	track.Parent = panel

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = BAR_FILL
	fill.BorderSizePixel = 0
	round(fill, UDim.new(1, 0))
	fill.Parent = track

	local row = Instance.new("Frame")
	row.Name = "StatusRow"
	row.LayoutOrder = 5
	row.Size = UDim2.new(1, 0, 0, 22)
	row.BackgroundTransparency = 1
	row.Parent = panel

	local status = label("Status", "Loading…", 16, Enum.FontWeight.Medium)
	status.Size = UDim2.new(0.75, 0, 1, 0)
	status.Parent = row

	local percent = label("Percent", "0%", 16, Enum.FontWeight.Bold)
	percent.AnchorPoint = Vector2.new(1, 0)
	percent.Position = UDim2.fromScale(1, 0)
	percent.Size = UDim2.new(0.25, 0, 1, 0)
	percent.TextXAlignment = Enum.TextXAlignment.Right
	percent.Parent = row

	return {
		gui = gui,
		background = background,
		fill = fill,
		percent = percent,
		status = status,
	}
end

-- Waits until `check` passes or `timeout` seconds go by. Returns whether it passed.
local function waitFor(check: () -> boolean, timeout: number): boolean
	local deadline = os.clock() + timeout
	while not check() do
		if os.clock() >= deadline then
			return false
		end
		task.wait(0.1)
	end
	return true
end

-- Waits until `model` stops getting new parts for SETTLE_SECONDS.
local function waitForSettled(model: Instance, timeout: number)
	local count = #model:GetDescendants()
	local stableSince = os.clock()
	waitFor(function()
		local now = #model:GetDescendants()
		if now ~= count then
			count = now
			stableSince = os.clock()
		end
		return os.clock() - stableSince >= SETTLE_SECONDS
	end, timeout)
end

local function fadeOut(gui: ScreenGui, seconds: number)
	if seconds <= 0 then
		return
	end
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	for _, item in gui:GetDescendants() do
		if item:IsA("ImageLabel") then
			TweenService:Create(item, info, { ImageTransparency = 1, BackgroundTransparency = 1 })
				:Play()
		elseif item:IsA("TextLabel") then
			TweenService:Create(item, info, { TextTransparency = 1 }):Play()
		elseif item:IsA("Frame") then
			TweenService:Create(item, info, { BackgroundTransparency = 1 }):Play()
		elseif item:IsA("UIStroke") then
			TweenService:Create(item, info, { Transparency = 1 }):Play()
		end
	end
	task.wait(seconds)
end

function LoadingScreen.run()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	-- Turn phones to landscape now, so the loading screen is already sideways. Roblox only
	-- applies StarterGui.ScreenOrientation (also LandscapeSensor) a bit later in the join.
	playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
	local ui = build()
	ui.gui.Parent = playerGui
	ReplicatedFirst:RemoveDefaultLoadingScreen()

	-- The bar eases toward `target` and never goes backwards.
	local target = 0
	local shown = 0
	local function progress(value: number, status: string?)
		target = math.max(target, math.clamp(value, 0, 1))
		if status then
			ui.status.Text = status
		end
	end
	local render = RunService.RenderStepped:Connect(function(deltaTime: number)
		shown += (target - shown) * math.min(1, deltaTime * 6)
		if target - shown < 0.002 then
			shown = target
		end
		ui.fill.Size = UDim2.fromScale(shown, 1)
		ui.percent.Text = `{math.floor(shown * 100 + 0.5)}%`
	end)

	local started = os.clock()
	local function remaining(): number
		return math.max(0, MAX_WAIT_SECONDS - (os.clock() - started))
	end

	-- Show the art as soon as it downloads, without holding up the rest.
	task.spawn(function()
		ContentProvider:PreloadAsync({ ui.background })
	end)

	-- 1. The game's starting content.
	progress(0.05, "Loading…")
	waitFor(function()
		return game:IsLoaded()
	end, remaining())

	-- 2. The hilltop and the city in the distance.
	progress(0.25, "Setting up the view…")
	local surroundings: Instance? = nil
	waitFor(function()
		surroundings = Workspace:FindFirstChild("Surroundings")
		return Workspace:FindFirstChild("Overlook") ~= nil and surroundings ~= nil
	end, remaining())
	progress(0.35)
	if surroundings then
		for _, name in { "MidGround", "City" } do
			local model = (surroundings :: Instance):WaitForChild(name, remaining())
			if model then
				waitForSettled(model, remaining())
			end
		end
	end
	progress(0.6)

	-- 3. Textures, meshes and sounds that are still downloading.
	progress(0.6, "Turning on the city lights…")
	local queued = math.max(ContentProvider.RequestQueueSize, 1)
	waitFor(function()
		local left = ContentProvider.RequestQueueSize
		progress(0.6 + 0.25 * (1 - math.min(left, queued) / queued))
		return left == 0
	end, math.min(ASSET_WAIT_SECONDS, remaining()))
	progress(0.85)

	-- 4. The player's character, plus a moment for the camera to face the view.
	progress(0.85, "Almost there…")
	waitFor(function()
		local character = player.Character
		return character ~= nil and character:FindFirstChild("HumanoidRootPart") ~= nil
	end, remaining())
	task.wait(0.4)
	progress(1)

	waitFor(function()
		return shown >= 0.995
	end, 1)
	render:Disconnect()
	ui.fill.Size = UDim2.fromScale(1, 1)
	ui.percent.Text = "100%"

	-- Players who turn on Reduced Motion in Roblox settings skip the fade.
	fadeOut(ui.gui, if GuiService.ReducedMotionEnabled then 0 else FADE_SECONDS)
	ui.gui:Destroy()
end

return LoadingScreen
