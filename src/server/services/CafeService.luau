--!strict
-- Café ordering. Parts tagged Config.Cafe.Tag (the Hiraya cashier spot) get an "Order" prompt.
-- Using it asks the player the question (see client CafeController); saying yes hands them a
-- bubble tea. The server only gives one if it really asked that player and they're still close.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CafeService = {}

type Asked = { spot: BasePart, at: number }
local asked: { [Player]: Asked } = {}

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
	-- Cylinders run along X, so turn them upright.
	local p = part(
		name,
		Vector3.new(height, width, width),
		color,
		CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90))
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function buildTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = Config.Cafe.ToolName
	tool.ToolTip = "Salamat!"
	tool.CanBeDropped = false
	tool.RequiresHandle = true

	local handle = part("Handle", Vector3.new(0.4, 0.4, 0.4), Color3.new(1, 1, 1), CFrame.new())
	handle.Transparency = 1
	handle.Parent = tool

	local pieces = {
		cylinder("Cup", 1.1, 0.7, Color3.fromRGB(205, 165, 125), 0),
		cylinder("Pearls", 0.28, 0.66, Color3.fromRGB(45, 28, 22), -0.4),
		cylinder("Lid", 0.08, 0.74, Color3.fromRGB(245, 245, 245), 0.58),
		cylinder("Straw", 0.9, 0.1, Color3.fromRGB(240, 120, 150), 0.95),
	}
	pieces[1].Transparency = 0.1
	pieces[3].Transparency = 0.3
	pieces[4].CFrame = CFrame.new(0.12, 0.95, 0) * CFrame.Angles(0, 0, math.rad(80))
	for _, piece in pieces do
		piece.Parent = tool
		local w = Instance.new("WeldConstraint")
		w.Part0 = handle
		w.Part1 = piece
		w.Parent = piece
	end

	return tool
end

local template: Tool? = nil

local function hasTea(player: Player): boolean
	local name = Config.Cafe.ToolName
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	return (backpack ~= nil and backpack:FindFirstChild(name) ~= nil)
		or (character ~= nil and character:FindFirstChild(name) ~= nil)
end

local function isNear(player: Player, spot: BasePart, distance: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil
		and root:IsA("BasePart")
		and (root.Position - spot.Position).Magnitude <= distance
end

local function give(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not template or not humanoid or hasTea(player) then
		return
	end
	local tea = template:Clone()
	tea.Parent = player:FindFirstChildOfClass("Backpack")
	humanoid:EquipTool(tea)
end

local function addPrompt(spot: Instance)
	if not spot:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OrderPrompt"
	prompt.ActionText = "Order"
	prompt.ObjectText = spot.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Cafe.PromptDistance
	-- The counter sits between the player and the cashier.
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player: Player)
		-- The player's own client already opened the dialog; just remember we asked.
		asked[player] = { spot = spot, at = os.clock() }
	end)
	prompt.Parent = spot
end

local function onEvent(player: Player, action: unknown)
	local ask = asked[player]
	if action ~= "Accept" or not ask then
		return
	end
	asked[player] = nil
	if os.clock() - ask.at > Config.Cafe.AnswerTimeout then
		return
	end
	if not isNear(player, ask.spot, Config.Cafe.AcceptDistance) then
		return
	end
	give(player)
end

function CafeService.start()
	template = buildTool()
	Remotes.cafe().OnServerEvent:Connect(onEvent)
	for _, spot in CollectionService:GetTagged(Config.Cafe.Tag) do
		addPrompt(spot)
	end
	CollectionService:GetInstanceAddedSignal(Config.Cafe.Tag):Connect(addPrompt)
	Players.PlayerRemoving:Connect(function(player: Player)
		asked[player] = nil
	end)
end

return CafeService
