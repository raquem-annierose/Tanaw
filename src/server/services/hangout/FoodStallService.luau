--!strict
-- Street Food Stalls: decorates the 6 food stalls in Overlook.Stalls with aesthetic
-- chalkboard menus, adds counter order prompts, hands out custom 3D food/drink tools
-- (max 1 of each item per player), and removes each item once finished eating/drinking.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.core.Config)
local FoodModels = require(ReplicatedStorage.Shared.hangout.FoodModels)
local FoodStalls = require(ReplicatedStorage.Shared.hangout.FoodStalls)
local Remotes = require(ReplicatedStorage.Shared.core.Remotes)

type MenuItem = FoodStalls.MenuItem
type StallDef = FoodStalls.StallDef

local FONT_BOLD = Font.fromEnum(Enum.Font.BuilderSansBold)
local FONT_REG = Font.fromEnum(Enum.Font.BuilderSans)
local FONT_HAND = Font.fromEnum(Enum.Font.IndieFlower)

local FoodStallService = {}

local stallCounters: { [string]: BasePart } = {}

local function buildFoodTool(item: MenuItem): Tool
	local tool = Instance.new("Tool")
	tool.Name = item.Name
	tool.ToolTip = `{item.Bites} {if item.IsDrink then "sips" else "bites"} left`
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("FoodItemId", item.Id)

	local handle, pieces = FoodModels.buildParts(item)
	handle.Parent = tool
	for _, piece in pieces do
		piece.Parent = tool
		local w = Instance.new("WeldConstraint")
		w.Part0 = handle
		w.Part1 = piece
		w.Parent = piece
	end
	return tool
end

local function hasItem(player: Player, item: MenuItem): boolean
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	if backpack then
		for _, child in backpack:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("FoodItemId") == item.Id then
				return true
			end
		end
	end
	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("FoodItemId") == item.Id then
				return true
			end
		end
	end
	return false
end

local function decorateChalkboard(menuPart: BasePart, stall: StallDef)
	-- Apply on both Front and Back so the chalkboard menu always faces the customer
	-- regardless of which row the stall sits in.
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local existing = menuPart:FindFirstChild(`ChalkMenu_{face.Name}`)
		if existing then
			existing:Destroy()
		end

		local gui = Instance.new("SurfaceGui")
		gui.Name = `ChalkMenu_{face.Name}`
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 65
		gui.LightInfluence = 0.1
		gui.MaxDistance = 90
		gui.Parent = menuPart

		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(28, 25, 28)
		bg.BorderSizePixel = 0
		bg.Parent = gui

		local border = Instance.new("UIStroke")
		border.Color = stall.Accent
		border.Thickness = 5
		border.Transparency = 0.25
		border.Parent = bg

		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 12)
		pad.PaddingBottom = UDim.new(0, 10)
		pad.PaddingLeft = UDim.new(0, 22)
		pad.PaddingRight = UDim.new(0, 22)
		pad.Parent = bg

		local header = Instance.new("TextLabel")
		header.Size = UDim2.new(1, 0, 0, 34)
		header.BackgroundTransparency = 1
		header.FontFace = FONT_BOLD
		header.Text = `{string.upper(stall.Title)}  ·  MENU`
		header.TextSize = 26
		header.TextColor3 = stall.Accent
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.Parent = bg

		local divider = Instance.new("Frame")
		divider.Position = UDim2.fromOffset(0, 38)
		divider.Size = UDim2.new(1, 0, 0, 2)
		divider.BackgroundColor3 = Color3.fromRGB(255, 244, 226)
		divider.BackgroundTransparency = 0.65
		divider.BorderSizePixel = 0
		divider.Parent = bg

		for idx, item in stall.Items do
			local y = 48 + (idx - 1) * 66
			local itemName = Instance.new("TextLabel")
			itemName.Position = UDim2.fromOffset(0, y)
			itemName.Size = UDim2.new(0.75, 0, 0, 30)
			itemName.BackgroundTransparency = 1
			itemName.FontFace = FONT_HAND
			itemName.Text = `• {item.Name}`
			itemName.TextSize = 28
			itemName.TextColor3 = Color3.fromRGB(255, 248, 232)
			itemName.TextXAlignment = Enum.TextXAlignment.Left
			itemName.Parent = bg

			local badge = Instance.new("TextLabel")
			badge.AnchorPoint = Vector2.new(1, 0)
			badge.Position = UDim2.new(1, 0, 0, y + 4)
			badge.Size = UDim2.fromOffset(110, 24)
			badge.BackgroundTransparency = 1
			badge.FontFace = FONT_BOLD
			badge.Text = "FREE"
			badge.TextSize = 18
			badge.TextColor3 = stall.Accent
			badge.TextXAlignment = Enum.TextXAlignment.Right
			badge.Parent = bg

			local desc = Instance.new("TextLabel")
			desc.Position = UDim2.fromOffset(16, y + 30)
			desc.Size = UDim2.new(1, -16, 0, 22)
			desc.BackgroundTransparency = 1
			desc.FontFace = FONT_REG
			desc.Text = item.Description
			desc.TextSize = 16
			desc.TextColor3 = Color3.fromRGB(210, 202, 192)
			desc.TextXAlignment = Enum.TextXAlignment.Left
			desc.Parent = bg
		end
	end
end

local function makeAnchored(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Restyle the existing booth parts with warm artisan café materials and add
-- slatted wood paneling, a striped fabric awning, under-counter glow, framed
-- menu trim, and flanking potted greenery.
local function decorateBooth(stallModel: Instance, booth: Instance, stall: StallDef)
	local woodDark = Color3.fromRGB(72, 48, 34)
	local woodWarm = Color3.fromRGB(112, 78, 54)
	local woodCounter = Color3.fromRGB(134, 94, 62)
	local creamWall = Color3.fromRGB(204, 188, 168)
	local creamBase = Color3.fromRGB(212, 198, 180)

	for _, child in booth:GetChildren() do
		if not child:IsA("BasePart") then
			continue
		end
		if child.Name == "CounterTop" then
			child.Material = Enum.Material.WoodPlanks
			child.Color = woodCounter
		elseif child.Name == "Counter" then
			child.Material = Enum.Material.SmoothPlastic
			child.Color = creamBase
		elseif child.Name == "CounterStripe" then
			child.Material = Enum.Material.SmoothPlastic
			child.Color = stall.Accent
		elseif child.Name == "BackLow" or child.Name == "SideLow" then
			child.Material = Enum.Material.WoodPlanks
			child.Color = woodWarm
		elseif child.Name == "BackHigh" or child.Name == "SideHigh" then
			child.Material = Enum.Material.SmoothPlastic
			child.Color = creamWall
		elseif child.Name == "Post" then
			child.Material = Enum.Material.Wood
			child.Color = woodDark
		elseif child.Name == "Roof" then
			child.Material = Enum.Material.Wood
			child.Color = Color3.fromRGB(64, 44, 32)
		elseif child.Name == "Floor" then
			child.Material = Enum.Material.WoodPlanks
			child.Color = Color3.fromRGB(94, 68, 50)
		end
	end

	local oldDecor = stallModel:FindFirstChild("StallDecor")
	if oldDecor then
		oldDecor:Destroy()
	end
	local decor = Instance.new("Folder")
	decor.Name = "StallDecor"
	decor.Parent = stallModel

	local counterTop = booth:FindFirstChild("CounterTop")
	if counterTop and counterTop:IsA("BasePart") then
		local ctCF = counterTop.CFrame

		-- Vertical wooden café slats across the front of the counter.
		local slatCount = 19
		for i = 0, slatCount - 1 do
			local x = -7.0 + (i / (slatCount - 1)) * 14.0
			makeAnchored(
				decor,
				"CounterSlat",
				Vector3.new(0.16, 3.25, 0.1),
				ctCF * CFrame.new(x, -1.75, -0.84),
				woodWarm,
				Enum.Material.Wood
			)
		end

		-- Subtle warm accent trim tucked beneath the counter lip.
		local led = makeAnchored(
			decor,
			"UnderCounterGlow",
			Vector3.new(14.6, 0.08, 0.08),
			ctCF * CFrame.new(0, -0.14, -0.94),
			Color3.fromRGB(232, 190, 138),
			Enum.Material.SmoothPlastic
		)
		led.Transparency = 0.2

		-- Striped boutique fabric awning extending forward above the counter.
		local stripes = 10
		local totalW = 16.4
		local stripeW = totalW / stripes
		local awningCream = Color3.fromRGB(248, 242, 232)
		local awningCF = ctCF * CFrame.new(0, 6.25, -2.55) * CFrame.Angles(math.rad(-18), 0, 0)
		for i = 0, stripes - 1 do
			local sx = -totalW * 0.5 + stripeW * (i + 0.5)
			local isAccent = (i % 2 == 0)
			makeAnchored(
				decor,
				"AwningStripe",
				Vector3.new(stripeW + 0.02, 0.16, 2.5),
				awningCF * CFrame.new(sx, 0, 0),
				if isAccent then stall.Accent else awningCream,
				Enum.Material.Fabric
			)
		end

		-- Crisp front valence lip along the bottom edge of the awning.
		makeAnchored(
			decor,
			"AwningTrim",
			Vector3.new(totalW + 0.1, 0.24, 0.14),
			awningCF * CFrame.new(0, -0.14, -1.26),
			woodDark,
			Enum.Material.Wood
		)

		-- Cozy flanking wooden planter boxes with lush greenery on both sides of the stall.
		for _, sideX in { -7.95, 7.95 } do
			local potCF = ctCF * CFrame.new(sideX, -2.55, -1.35)
			local pot = makeAnchored(
				decor,
				"PlanterPot",
				Vector3.new(1.35, 1.3, 1.35),
				potCF,
				woodDark,
				Enum.Material.WoodPlanks
			)
			pot.CanCollide = true
			makeAnchored(
				decor,
				"PlanterRim",
				Vector3.new(1.5, 0.18, 1.5),
				potCF * CFrame.new(0, 0.65, 0),
				woodWarm,
				Enum.Material.Wood
			)
			local bush1 = makeAnchored(
				decor,
				"Foliage1",
				Vector3.new(1.35, 1.2, 1.35),
				potCF * CFrame.new(0, 1.15, 0),
				Color3.fromRGB(58, 112, 64),
				Enum.Material.Grass
			)
			bush1.Shape = Enum.PartType.Ball
			local bush2 = makeAnchored(
				decor,
				"Foliage2",
				Vector3.new(0.95, 0.95, 0.95),
				potCF * CFrame.new(0.22, 1.65, -0.15),
				Color3.fromRGB(76, 134, 74),
				Enum.Material.Grass
			)
			bush2.Shape = Enum.PartType.Ball
			local bloom = makeAnchored(
				decor,
				"PlanterAccent",
				Vector3.new(0.28, 0.28, 0.28),
				potCF * CFrame.new(-0.25, 1.75, -0.35),
				stall.Accent,
				Enum.Material.SmoothPlastic
			)
			bloom.Shape = Enum.PartType.Ball
		end
	end

	-- Wooden frame molding around the chalkboard menu.
	local menuPart = booth:FindFirstChild("Menu")
	if menuPart and menuPart:IsA("BasePart") then
		local mCF = menuPart.CFrame
		local mw, mh = menuPart.Size.X, menuPart.Size.Y
		makeAnchored(
			decor,
			"MenuFrameTop",
			Vector3.new(mw + 0.36, 0.18, 0.34),
			mCF * CFrame.new(0, mh * 0.5 + 0.08, 0),
			woodWarm,
			Enum.Material.Wood
		)
		makeAnchored(
			decor,
			"MenuFrameBot",
			Vector3.new(mw + 0.36, 0.18, 0.34),
			mCF * CFrame.new(0, -mh * 0.5 - 0.08, 0),
			woodWarm,
			Enum.Material.Wood
		)
		makeAnchored(
			decor,
			"MenuFrameL",
			Vector3.new(0.18, mh + 0.34, 0.34),
			mCF * CFrame.new(-mw * 0.5 - 0.09, 0, 0),
			woodWarm,
			Enum.Material.Wood
		)
		makeAnchored(
			decor,
			"MenuFrameR",
			Vector3.new(0.18, mh + 0.34, 0.34),
			mCF * CFrame.new(mw * 0.5 + 0.09, 0, 0),
			woodWarm,
			Enum.Material.Wood
		)
	end
end

local function setupStall(stallModel: Instance, stall: StallDef, remote: RemoteEvent)
	local booth = stallModel:FindFirstChild("Booth")
	if not booth then
		return
	end

	decorateBooth(stallModel, booth, stall)

	local menuPart = booth:FindFirstChild("Menu")
	if menuPart and menuPart:IsA("BasePart") then
		decorateChalkboard(menuPart, stall)
	end

	local counterTop = booth:FindFirstChild("CounterTop")
	if counterTop and counterTop:IsA("BasePart") then
		stallCounters[stall.ModelName] = counterTop

		local oldPrompt = counterTop:FindFirstChild("StallOrderPrompt")
		if oldPrompt then
			oldPrompt:Destroy()
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "StallOrderPrompt"
		prompt.ActionText = "View Menu"
		prompt.ObjectText = stall.Title
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = FoodStalls.PromptDistance
		prompt.RequiresLineOfSight = false
		prompt.Parent = counterTop

		prompt.Triggered:Connect(function(player: Player)
			remote:FireClient(player, "Open", stall.ModelName)
		end)
	end
end

local function isNearStall(player: Player, stallName: string): boolean
	local counter = stallCounters[stallName]
	if not counter then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil
		and root:IsA("BasePart")
		and (root.Position - counter.Position).Magnitude <= FoodStalls.OrderDistance
end

local function giveItem(player: Player, item: MenuItem, remote: RemoteEvent)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not humanoid or not backpack then
		return
	end

	local tool = buildFoodTool(item)
	local bitesLeft = item.Bites
	local lastBite = 0
	local finished = false

	tool.Activated:Connect(function()
		if finished then
			return
		end
		local now = os.clock()
		local holder = tool.Parent
		if now - lastBite < FoodStalls.BiteCooldown or not holder or not holder:IsA("Model") then
			return
		end
		lastBite = now
		bitesLeft -= 1

		-- Play the shared arm-to-mouth eating/drinking animation on all clients.
		holder:SetAttribute(Config.Cafe.SipAttribute, Workspace:GetServerTimeNow())

		local unit = if item.IsDrink then "sip" else "bite"
		if bitesLeft > 0 then
			local plural = if bitesLeft == 1 then unit else `{unit}s`
			tool.ToolTip = `{bitesLeft} {plural} left`
			remote:FireClient(player, "Notice", `{item.Name} — {bitesLeft} {plural} left`)
		else
			finished = true
			tool.ToolTip = "Finished!"
			remote:FireClient(player, "Notice", `Finished {item.Name}! Salamat!`)
			task.delay(1.05, function()
				if tool.Parent then
					tool:Destroy()
				end
			end)
		end
	end)

	tool.Parent = backpack
	humanoid:EquipTool(tool)
end

function FoodStallService.start()
	local remote = Remotes.foodStall()

	local overlook = Workspace:WaitForChild("Overlook", 10)
	local stallsFolder = overlook and overlook:FindFirstChild("Stalls")
	if stallsFolder then
		for _, stall in FoodStalls.List do
			local model = stallsFolder:FindFirstChild(stall.ModelName)
			if model then
				setupStall(model, stall, remote)
			end
		end
	end

	remote.OnServerEvent:Connect(
		function(player: Player, kind: unknown, stallName: unknown, itemId: unknown)
			if kind ~= "Order" or typeof(stallName) ~= "string" or typeof(itemId) ~= "string" then
				return
			end
			local stall = FoodStalls.ByStall[stallName]
			local item = FoodStalls.ByItem[itemId]
			if not stall or not item then
				return
			end
			-- Confirm the requested item actually belongs to this stall.
			local belongs = false
			for _, candidate in stall.Items do
				if candidate.Id == item.Id then
					belongs = true
					break
				end
			end
			if not belongs then
				return
			end
			if not isNearStall(player, stallName) then
				remote:FireClient(player, "Error", "Walk closer to the counter to order.")
				return
			end
			if hasItem(player, item) then
				remote:FireClient(
					player,
					"Error",
					`You already have {item.Name}! Finish it first to order another.`
				)
				return
			end

			giveItem(player, item, remote)
			remote:FireClient(player, "Ordered", item.Id)
		end
	)
end

return FoodStallService
