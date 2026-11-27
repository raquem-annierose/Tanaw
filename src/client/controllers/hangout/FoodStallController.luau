--!strict
-- Street Food Stalls (client): opens a cozy store menu when you interact with any of
-- the 6 food stalls, shows whether you already have each item in your inventory, and
-- displays subtle bite/sip feedback as you eat or drink.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local FoodStalls = require(ReplicatedStorage.Shared.hangout.FoodStalls)
local Remotes = require(ReplicatedStorage.Shared.core.Remotes)

type MenuItem = FoodStalls.MenuItem
type StallDef = FoodStalls.StallDef

local FONT_BOLD = Font.fromEnum(Enum.Font.BuilderSansBold)
local FONT_REG = Font.fromEnum(Enum.Font.BuilderSans)

local FoodStallController = {}

local player = Players.LocalPlayer
local remoteEvent: RemoteEvent? = nil

local backdrop: Frame? = nil
local cardStroke: UIStroke? = nil
local accentBar: Frame? = nil
local titleLabel: TextLabel? = nil
local taglineLabel: TextLabel? = nil
local itemsContainer: Frame? = nil
local errorLabel: TextLabel? = nil
local toastLabel: TextLabel? = nil
local currentStallName: string? = nil

local function corner(parent: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function borderStroke(
	parent: GuiObject,
	color: Color3,
	thickness: number,
	transparency: number
): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency
	stroke.Parent = parent
	return stroke
end

local function playerHasItem(itemId: string): boolean
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	if backpack then
		for _, child in backpack:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("FoodItemId") == itemId then
				return true
			end
		end
	end
	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("FoodItemId") == itemId then
				return true
			end
		end
	end
	return false
end

local function showToast(message: string)
	if not toastLabel then
		return
	end
	local label = toastLabel
	label.Text = message
	label.TextTransparency = 1
	label.Visible = true
	TweenService:Create(
		label,
		TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ TextTransparency = 0 }
	):Play()

	task.delay(2.2, function()
		if label.Text ~= message then
			return
		end
		local fade = TweenService:Create(
			label,
			TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
			{ TextTransparency = 1 }
		)
		fade.Completed:Connect(function()
			if label.Text == message then
				label.Visible = false
			end
		end)
		fade:Play()
	end)
end

local function closeMenu()
	currentStallName = nil
	if backdrop then
		backdrop.Visible = false
	end
end

local function renderStall(stall: StallDef)
	if
		not itemsContainer
		or not titleLabel
		or not taglineLabel
		or not accentBar
		or not cardStroke
	then
		return
	end
	titleLabel.Text = stall.Title
	taglineLabel.Text = stall.Tagline
	accentBar.BackgroundColor3 = stall.Accent
	cardStroke.Color = stall.Accent

	if errorLabel then
		errorLabel.Text = ""
	end

	for _, child in itemsContainer:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	for idx, item in stall.Items do
		local owned = playerHasItem(item.Id)

		local row = Instance.new("Frame")
		row.Name = item.Id
		row.Position = UDim2.fromOffset(0, (idx - 1) * 86)
		row.Size = UDim2.new(1, 0, 0, 76)
		row.BackgroundColor3 = Color3.fromRGB(34, 29, 52)
		corner(row, 13)
		borderStroke(row, Color3.fromRGB(120, 108, 152), 1, 0.65)
		row.Parent = itemsContainer

		-- Small color swatch representing the food/drink.
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0, 0.5)
		dot.Position = UDim2.new(0, 14, 0.5, 0)
		dot.Size = UDim2.fromOffset(14, 42)
		dot.BackgroundColor3 = item.PrimaryColor
		corner(dot, 7)
		dot.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Position = UDim2.fromOffset(38, 12)
		nameLabel.Size = UDim2.new(1, -148, 0, 22)
		nameLabel.BackgroundTransparency = 1
		nameLabel.FontFace = FONT_BOLD
		nameLabel.Text = item.Name
		nameLabel.TextSize = 17
		nameLabel.TextColor3 = Color3.fromRGB(255, 248, 236)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = row

		local descLabel = Instance.new("TextLabel")
		descLabel.Position = UDim2.fromOffset(38, 35)
		descLabel.Size = UDim2.new(1, -148, 0, 30)
		descLabel.BackgroundTransparency = 1
		descLabel.FontFace = FONT_REG
		descLabel.Text = item.Description
		descLabel.TextSize = 13
		descLabel.TextWrapped = true
		descLabel.TextColor3 = Color3.fromRGB(196, 188, 214)
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextYAlignment = Enum.TextYAlignment.Top
		descLabel.Parent = row

		local btn = Instance.new("TextButton")
		btn.AnchorPoint = Vector2.new(1, 0.5)
		btn.Position = UDim2.new(1, -12, 0.5, 0)
		btn.Size = UDim2.fromOffset(92, 36)
		btn.BackgroundColor3 = if owned then Color3.fromRGB(52, 46, 74) else stall.Accent
		btn.FontFace = FONT_BOLD
		btn.Text = if owned then "In Bag ✓" else "Get"
		btn.TextSize = 14
		btn.TextColor3 = if owned then Color3.fromRGB(192, 184, 212) else Color3.fromRGB(28, 20, 16)
		btn.AutoButtonColor = not owned
		corner(btn, 10)
		btn.Parent = row

		btn.MouseButton1Click:Connect(function()
			if not remoteEvent or playerHasItem(item.Id) then
				return
			end
			btn.Text = "..."
			remoteEvent:FireServer("Order", stall.ModelName, item.Id)
		end)
	end
end

local function openMenu(stallName: string)
	local stall = FoodStalls.ByStall[stallName]
	if not stall or not backdrop then
		return
	end
	currentStallName = stallName
	renderStall(stall)
	backdrop.Visible = true
end

local function buildUi()
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "FoodStallUi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 17
	gui.Parent = playerGui

	-- Subtle bite/sip feedback toast near the bottom of the screen.
	local toast = Instance.new("TextLabel")
	toast.Name = "FoodToast"
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -82)
	toast.Size = UDim2.new(0.75, 0, 0, 28)
	toast.BackgroundTransparency = 1
	toast.FontFace = FONT_BOLD
	toast.Text = ""
	toast.TextSize = 17
	toast.TextColor3 = Color3.fromRGB(255, 244, 218)
	toast.TextStrokeColor3 = Color3.fromRGB(24, 18, 32)
	toast.TextStrokeTransparency = 0.3
	toast.Visible = false
	toast.Parent = gui
	toastLabel = toast

	local bg = Instance.new("Frame")
	bg.Name = "Backdrop"
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(10, 8, 20)
	bg.BackgroundTransparency = 0.45
	bg.Visible = false
	bg.Parent = gui
	backdrop = bg

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(420, 326)
	card.BackgroundColor3 = Color3.fromRGB(24, 20, 38)
	card.BackgroundTransparency = 0.05
	corner(card, 18)
	cardStroke = borderStroke(card, Color3.fromRGB(246, 196, 118), 1.5, 0.45)
	card.Parent = bg

	local bar = Instance.new("Frame")
	bar.Name = "AccentBar"
	bar.Position = UDim2.fromOffset(24, 18)
	bar.Size = UDim2.fromOffset(42, 4)
	bar.BackgroundColor3 = Color3.fromRGB(246, 196, 118)
	bar.BorderSizePixel = 0
	corner(bar, 2)
	bar.Parent = card
	accentBar = bar

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 28)
	padding.PaddingBottom = UDim.new(0, 18)
	padding.PaddingLeft = UDim.new(0, 24)
	padding.PaddingRight = UDim.new(0, 24)
	padding.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -36, 0, 28)
	title.BackgroundTransparency = 1
	title.FontFace = FONT_BOLD
	title.Text = "Food Stall"
	title.TextSize = 23
	title.TextColor3 = Color3.fromRGB(255, 244, 224)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = card
	titleLabel = title

	local closeBtn = Instance.new("TextButton")
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.Position = UDim2.new(1, 0, 0, -2)
	closeBtn.Size = UDim2.fromOffset(30, 30)
	closeBtn.BackgroundColor3 = Color3.fromRGB(44, 38, 66)
	closeBtn.FontFace = FONT_BOLD
	closeBtn.Text = "×"
	closeBtn.TextSize = 20
	closeBtn.TextColor3 = Color3.fromRGB(220, 212, 236)
	corner(closeBtn, 15)
	closeBtn.Parent = card

	closeBtn.MouseButton1Click:Connect(closeMenu)

	local tag = Instance.new("TextLabel")
	tag.Position = UDim2.fromOffset(0, 30)
	tag.Size = UDim2.new(1, 0, 0, 20)
	tag.BackgroundTransparency = 1
	tag.FontFace = FONT_REG
	tag.Text = ""
	tag.TextSize = 14
	tag.TextColor3 = Color3.fromRGB(196, 188, 216)
	tag.TextXAlignment = Enum.TextXAlignment.Left
	tag.Parent = card
	taglineLabel = tag

	local items = Instance.new("Frame")
	items.Name = "Items"
	items.Position = UDim2.fromOffset(0, 62)
	items.Size = UDim2.new(1, 0, 0, 170)
	items.BackgroundTransparency = 1
	items.Parent = card
	itemsContainer = items

	local err = Instance.new("TextLabel")
	err.Position = UDim2.fromOffset(0, 236)
	err.Size = UDim2.new(1, 0, 0, 18)
	err.BackgroundTransparency = 1
	err.FontFace = FONT_REG
	err.Text = ""
	err.TextSize = 13
	err.TextColor3 = Color3.fromRGB(255, 168, 152)
	err.TextXAlignment = Enum.TextXAlignment.Left
	err.Parent = card
	errorLabel = err

	local hint = Instance.new("TextLabel")
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.new(0, 0, 1, 0)
	hint.Size = UDim2.new(1, 0, 0, 18)
	hint.BackgroundTransparency = 1
	hint.FontFace = FONT_REG
	hint.Text = "Click while holding an item to eat or sip • Max 1 per item"
	hint.TextSize = 12
	hint.TextColor3 = Color3.fromRGB(158, 150, 180)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = card

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if
			not gameProcessed
			and input.KeyCode == Enum.KeyCode.Escape
			and backdrop
			and backdrop.Visible
		then
			closeMenu()
		end
	end)
end

function FoodStallController.start()
	buildUi()
	local remote = Remotes.foodStall()
	remoteEvent = remote

	remote.OnClientEvent:Connect(function(kind: unknown, arg1: unknown)
		if kind == "Open" and typeof(arg1) == "string" then
			openMenu(arg1)
		elseif kind == "Ordered" and typeof(arg1) == "string" then
			local item = FoodStalls.ByItem[arg1]
			if item then
				showToast(`Got {item.Name}! Click to {if item.IsDrink then "sip" else "eat"}.`)
			end
			if currentStallName then
				local stall = FoodStalls.ByStall[currentStallName]
				if stall then
					renderStall(stall)
				end
			end
		elseif kind == "Notice" and typeof(arg1) == "string" then
			showToast(arg1)
		elseif kind == "Error" and typeof(arg1) == "string" then
			if errorLabel then
				errorLabel.Text = arg1
			end
		end
	end)
end

return FoodStallController
