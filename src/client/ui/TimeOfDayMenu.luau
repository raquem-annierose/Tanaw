--!strict
-- Umaga / Tanghali / Hapon / Gabi toggle at the top center of the screen.
--
-- Top center stays clear of Roblox's own buttons (top-left), the player list (top-right) and
-- the mobile thumbstick/jump buttons (bottom). Buttons are large enough for touch and
-- selectable with a gamepad.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TimeOfDay = require(ReplicatedStorage.Shared.TimeOfDay)
local TimeOfDayController = require(script.Parent.Parent.controllers.TimeOfDayController)

local BUTTON_WIDTH = 112
local PADDING = 4

local SELECTED_BG = Color3.fromRGB(255, 255, 255)
local SELECTED_TEXT = Color3.fromRGB(30, 30, 36)
local IDLE_TEXT = Color3.fromRGB(255, 255, 255)

local TimeOfDayMenu = {}

local function corner(parent: Instance)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = parent
end

function TimeOfDayMenu.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "TimeOfDayMenu"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 10)
	bar.Size = UDim2.new(0, #TimeOfDay.Order * BUTTON_WIDTH + PADDING * 2, 0, 44)
	bar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	bar.BackgroundTransparency = 0.35
	corner(bar)
	bar.Parent = gui

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = Vector2.new(0, 36)
	sizeLimit.MaxSize = Vector2.new(math.huge, 48)
	sizeLimit.Parent = bar

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, PADDING)
	padding.PaddingRight = UDim.new(0, PADDING)
	padding.PaddingTop = UDim.new(0, PADDING)
	padding.PaddingBottom = UDim.new(0, PADDING)
	padding.Parent = bar

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = bar

	local buttons: { [string]: TextButton } = {}
	for order, id in TimeOfDay.Order do
		local preset = TimeOfDay.Presets[id]
		local button = Instance.new("TextButton")
		button.Name = id
		button.LayoutOrder = order
		button.Size = UDim2.new(0, BUTTON_WIDTH, 1, 0)
		button.BackgroundColor3 = SELECTED_BG
		button.BackgroundTransparency = 1
		button.AutoButtonColor = false
		button.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
		button.TextSize = 18
		button.Text = `{preset.Icon} {preset.Label}`
		button.TextColor3 = IDLE_TEXT
		button.Selectable = true
		corner(button)
		button.Activated:Connect(function()
			TimeOfDayController.set(id)
		end)
		button.Parent = bar
		buttons[id] = button
	end

	local function highlight(current: string?)
		for id, button in buttons do
			local selected = id == current
			button.BackgroundTransparency = if selected then 0 else 1
			button.TextColor3 = if selected then SELECTED_TEXT else IDLE_TEXT
		end
	end
	TimeOfDayController.Changed:Connect(highlight)
	highlight(TimeOfDayController.getCurrent())

	gui.Parent = playerGui
end

return TimeOfDayMenu
