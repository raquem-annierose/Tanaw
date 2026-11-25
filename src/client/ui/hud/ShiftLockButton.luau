--!strict
-- On-screen Lock / Unlock button for touch screens, just above Roblox's jump button.
--
-- Roblox puts its own context-action touch buttons in a fixed spot around the jump button, and
-- on phones that spot covers the jump button. This button follows wherever the jump button is,
-- also after the device rotates, and only shows while Roblox's touch controls are on screen.

local Players = game:GetService("Players")

local ShiftLockController =
	require(script.Parent.Parent.Parent.controllers.player.ShiftLockController)

local GAP = 10 -- pixels between this button and the top of the jump button
local SIZE_SCALE = 0.7 -- this button's size compared with the jump button

local IDLE_BG = Color3.fromRGB(0, 0, 0)
local IDLE_TEXT = Color3.fromRGB(255, 255, 255)
local ON_BG = Color3.fromRGB(255, 255, 255)
local ON_TEXT = Color3.fromRGB(30, 30, 36)

local ShiftLockButton = {}

function ShiftLockButton.start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "ShiftLockButton"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local button = Instance.new("TextButton")
	button.Name = "Lock"
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.AutoButtonColor = false
	button.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
	button.Selectable = false
	button.Parent = gui

	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 2
	stroke.Transparency = 0.4
	stroke.Parent = button

	local function showState(on: boolean)
		button.Text = if on then "Unlock" else "Lock"
		button.BackgroundColor3 = if on then ON_BG else IDLE_BG
		button.BackgroundTransparency = if on then 0.1 else 0.5
		button.TextColor3 = if on then ON_TEXT else IDLE_TEXT
	end
	showState(ShiftLockController.isEnabled())
	ShiftLockController.Changed:Connect(showState)
	button.Activated:Connect(ShiftLockController.toggle)

	local touchGui: ScreenGui? = nil
	local jumpButton: GuiObject? = nil
	local watching: { RBXScriptConnection } = {}

	local function place()
		local jump = jumpButton
		local touch = touchGui
		if not jump or not touch or not jump:IsDescendantOf(playerGui) then
			gui.Enabled = false
			return
		end
		gui.Enabled = touch.Enabled and jump.Visible

		-- Same screen area as Roblox's touch controls, so their pixel positions line up.
		gui.ScreenInsets = touch.ScreenInsets
		gui.IgnoreGuiInset = touch.IgnoreGuiInset

		local size = math.floor(jump.AbsoluteSize.X * SIZE_SCALE)
		local offset = gui.AbsolutePosition
		local centerX = jump.AbsolutePosition.X + jump.AbsoluteSize.X / 2 - offset.X
		local top = jump.AbsolutePosition.Y - offset.Y
		button.Size = UDim2.fromOffset(size, size)
		button.Position = UDim2.fromOffset(centerX, top - GAP)
		button.TextSize = math.max(12, math.floor(size * 0.28))
	end

	local function follow(jump: GuiObject, touch: ScreenGui)
		for _, connection in watching do
			connection:Disconnect()
		end
		jumpButton = jump
		touchGui = touch
		watching = {
			jump:GetPropertyChangedSignal("AbsolutePosition"):Connect(place),
			jump:GetPropertyChangedSignal("AbsoluteSize"):Connect(place),
			jump:GetPropertyChangedSignal("Visible"):Connect(place),
			jump.AncestryChanged:Connect(place),
			touch:GetPropertyChangedSignal("Enabled"):Connect(place),
		}
		place()
	end

	-- Roblox makes the jump button only once touch input is used, and remakes it when the
	-- screen size changes, so keep watching for new ones.
	local function check(instance: Instance)
		if instance.Name ~= "JumpButton" or not instance:IsA("GuiObject") then
			return
		end
		local touch = instance:FindFirstAncestor("TouchGui")
		if touch and touch:IsA("ScreenGui") then
			follow(instance, touch)
		end
	end
	for _, instance in playerGui:GetDescendants() do
		check(instance)
	end
	playerGui.DescendantAdded:Connect(check)
	gui:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)

	gui.Parent = playerGui
end

return ShiftLockButton
