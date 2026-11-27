--!strict
-- Street Food Stalls: decorates the 6 food stalls in Overlook.Stalls with aesthetic
-- chalkboard menus, adds counter order prompts, hands out custom 3D food/drink tools
-- (max 1 of each item per player), and removes each item once finished eating/drinking.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.core.Config)
local FoodStalls = require(ReplicatedStorage.Shared.hangout.FoodStalls)
local Remotes = require(ReplicatedStorage.Shared.core.Remotes)

type MenuItem = FoodStalls.MenuItem
type StallDef = FoodStalls.StallDef

local FONT_BOLD = Font.fromEnum(Enum.Font.BuilderSansBold)
local FONT_REG = Font.fromEnum(Enum.Font.BuilderSans)
local FONT_HAND = Font.fromEnum(Enum.Font.IndieFlower)

local FoodStallService = {}

local stallCounters: { [string]: BasePart } = {}

local function part(name: string, size: Vector3, color: Color3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CFrame = cf
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function cylinder(name: string, height: number, width: number, color: Color3, y: number): Part
	local p = part(
		name,
		Vector3.new(height, width, width),
		color,
		CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90))
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function weldPieces(tool: Tool, handle: Part, pieces: { Part })
	for _, piece in pieces do
		piece.Parent = tool
		local w = Instance.new("WeldConstraint")
		w.Part0 = handle
		w.Part1 = piece
		w.Parent = piece
	end
end

local function buildFoodTool(item: MenuItem): Tool
	local tool = Instance.new("Tool")
	tool.Name = item.Name
	tool.ToolTip = `{item.Bites} {if item.IsDrink then "sips" else "bites"} left`
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("FoodItemId", item.Id)

	local handle = part("Handle", Vector3.new(0.4, 0.4, 0.4), Color3.new(1, 1, 1), CFrame.new())
	handle.Transparency = 1
	handle.Parent = tool

	local pieces: { Part } = {}

	if item.Kind == "Shake" then
		local cup = cylinder("Cup", 1.1, 0.72, item.PrimaryColor, 0)
		cup.Transparency = 0.08
		local top =
			part("Cream", Vector3.new(0.66, 0.34, 0.66), item.AccentColor, CFrame.new(0, 0.62, 0))
		top.Shape = Enum.PartType.Ball
		local lid = cylinder("Lid", 0.08, 0.76, Color3.fromRGB(248, 248, 248), 0.56)
		lid.Transparency = 0.35
		local straw = cylinder("Straw", 0.95, 0.1, Color3.fromRGB(255, 248, 236), 0.95)
		straw.CFrame = CFrame.new(0.1, 0.95, 0) * CFrame.Angles(0, 0, math.rad(82))
		pieces = { cup, top, lid, straw }
	elseif item.Kind == "MilkTea" then
		local cup = cylinder("Cup", 1.1, 0.7, item.PrimaryColor, 0)
		cup.Transparency = 0.1
		local pearls = cylinder("Pearls", 0.28, 0.66, Color3.fromRGB(42, 26, 20), -0.4)
		local foam = cylinder("Foam", 0.18, 0.68, item.AccentColor, 0.46)
		local lid = cylinder("Lid", 0.08, 0.74, Color3.fromRGB(246, 246, 246), 0.58)
		lid.Transparency = 0.3
		local straw = cylinder("Straw", 0.95, 0.12, Color3.fromRGB(48, 36, 32), 0.95)
		straw.CFrame = CFrame.new(0.12, 0.95, 0) * CFrame.Angles(0, 0, math.rad(80))
		pieces = { cup, pearls, foam, lid, straw }
	elseif item.Kind == "Pizza" then
		local plate = cylinder("Plate", 0.06, 1.35, Color3.fromRGB(246, 244, 238), -0.05)
		local crust = part(
			"Crust",
			Vector3.new(1.05, 0.14, 0.22),
			Color3.fromRGB(204, 146, 78),
			CFrame.new(0, 0.05, 0.45)
		)
		local cheese = part(
			"Cheese",
			Vector3.new(0.95, 0.1, 0.9),
			item.PrimaryColor,
			CFrame.new(0, 0.04, -0.05)
		)
		local t1 = cylinder("Top1", 0.04, 0.24, item.AccentColor, 0.1)
		t1.CFrame = CFrame.new(-0.2, 0.1, 0.05) * CFrame.Angles(0, 0, math.rad(90))
		local t2 = cylinder("Top2", 0.04, 0.24, item.AccentColor, 0.1)
		t2.CFrame = CFrame.new(0.2, 0.1, -0.15) * CFrame.Angles(0, 0, math.rad(90))
		local t3 = cylinder("Top3", 0.04, 0.22, item.AccentColor, 0.1)
		t3.CFrame = CFrame.new(0.02, 0.1, 0.22) * CFrame.Angles(0, 0, math.rad(90))
		pieces = { plate, crust, cheese, t1, t2, t3 }
	elseif item.Kind == "Skewer" then
		local stick = cylinder("Stick", 1.9, 0.07, Color3.fromRGB(224, 194, 142), 0.45)
		local m1 =
			part("Meat1", Vector3.new(0.36, 0.34, 0.28), item.PrimaryColor, CFrame.new(0, 0.45, 0))
		local m2 =
			part("Meat2", Vector3.new(0.38, 0.34, 0.3), item.AccentColor, CFrame.new(0, 0.82, 0))
		local m3 =
			part("Meat3", Vector3.new(0.34, 0.32, 0.26), item.PrimaryColor, CFrame.new(0, 1.18, 0))
		pieces = { stick, m1, m2, m3 }
	elseif item.Kind == "Fries" then
		local box =
			part("Carton", Vector3.new(0.74, 0.82, 0.44), item.AccentColor, CFrame.new(0, 0.05, 0))
		pieces = { box }
		for i = -2, 2 do
			local fry = part(
				`Fry{i}`,
				Vector3.new(0.11, 0.62 + (math.abs(i) % 2) * 0.14, 0.11),
				item.PrimaryColor,
				CFrame.new(i * 0.13, 0.56, (i % 2) * 0.06) * CFrame.Angles(0, 0, math.rad(i * -4))
			)
			table.insert(pieces, fry)
		end
	elseif item.Kind == "Shawarma" then
		local foil = cylinder("Foil", 0.65, 0.54, Color3.fromRGB(228, 232, 236), -0.18)
		local pita = cylinder("Pita", 0.72, 0.5, item.PrimaryColor, 0.36)
		local filling =
			part("Filling", Vector3.new(0.42, 0.22, 0.42), item.AccentColor, CFrame.new(0, 0.72, 0))
		filling.Shape = Enum.PartType.Ball
		local lettuce = part(
			"Lettuce",
			Vector3.new(0.36, 0.14, 0.36),
			Color3.fromRGB(118, 184, 86),
			CFrame.new(0.08, 0.78, 0.04)
		)
		pieces = { foil, pita, filling, lettuce }
	else -- Siomai
		local cup = cylinder("Cup", 0.62, 0.74, Color3.fromRGB(244, 240, 232), -0.05)
		local s1 = part(
			"Siomai1",
			Vector3.new(0.32, 0.28, 0.32),
			item.PrimaryColor,
			CFrame.new(-0.15, 0.34, -0.08)
		)
		local s2 = part(
			"Siomai2",
			Vector3.new(0.32, 0.28, 0.32),
			item.PrimaryColor,
			CFrame.new(0.15, 0.34, -0.08)
		)
		local s3 = part(
			"Siomai3",
			Vector3.new(0.32, 0.28, 0.32),
			item.PrimaryColor,
			CFrame.new(0, 0.34, 0.16)
		)
		local chili =
			part("Chili", Vector3.new(0.2, 0.08, 0.2), item.AccentColor, CFrame.new(0, 0.49, 0.12))
		local pick = cylinder("Toothpick", 0.75, 0.05, Color3.fromRGB(232, 206, 158), 0.62)
		pick.CFrame = CFrame.new(0.12, 0.62, 0) * CFrame.Angles(0, 0, math.rad(72))
		pieces = { cup, s1, s2, s3, chili, pick }
	end

	weldPieces(tool, handle, pieces)
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

local function setupStall(stallModel: Instance, stall: StallDef, remote: RemoteEvent)
	local booth = stallModel:FindFirstChild("Booth")
	if not booth then
		return
	end

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
