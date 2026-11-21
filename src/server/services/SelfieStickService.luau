--!strict
-- Gives every player a selfie stick tool. Equipping it switches that player's camera to a
-- selfie view (see client SelfieController); everyone else just sees the stick in their hand.
--
-- The stick is built from parts here so it lives in code. Parts are named so the client can
-- find the phone: Handle (grip) → Stick → Phone at the far end.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local SelfieStickService = {}

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function buildTool(): Tool
	local length = Config.SelfieStick.StickLength

	local tool = Instance.new("Tool")
	tool.Name = Config.SelfieStick.ToolName
	tool.ToolTip = "Selfie!"
	tool.CanBeDropped = false
	tool.RequiresHandle = true

	-- Rubber grip in the hand. The stick runs along the handle's -Z (forward).
	local handle = part(
		"Handle",
		Vector3.new(0.3, 0.3, 0.8),
		Color3.fromRGB(30, 30, 34),
		Enum.Material.SmoothPlastic
	)
	handle.CFrame = CFrame.new()
	handle.Parent = tool

	local stick = part(
		"Stick",
		Vector3.new(0.1, 0.1, length),
		Color3.fromRGB(200, 200, 205),
		Enum.Material.Metal
	)
	stick.CFrame = CFrame.new(0, 0, -0.4 - length / 2)
	stick.Parent = tool
	weld(handle, stick)

	-- Phone faces back toward the player (its front is +Z, toward the handle).
	local phone = part(
		"Phone",
		Vector3.new(0.5, 0.9, 0.08),
		Color3.fromRGB(20, 20, 24),
		Enum.Material.SmoothPlastic
	)
	phone.CFrame = CFrame.new(0, 0.3, -0.4 - length)
	phone.Parent = tool
	weld(stick, phone)

	local clamp = part(
		"Clamp",
		Vector3.new(0.2, 0.3, 0.15),
		Color3.fromRGB(30, 30, 34),
		Enum.Material.SmoothPlastic
	)
	clamp.CFrame = CFrame.new(0, 0.05, -0.4 - length + 0.05)
	clamp.Parent = tool
	weld(stick, clamp)

	-- Raised up and out in front, the way you hold a selfie stick.
	tool.Grip = CFrame.Angles(math.rad(-35), 0, 0)

	return tool
end

local template: Tool? = nil

local function give(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack or not template or backpack:FindFirstChild(template.Name) then
		return
	end
	template:Clone().Parent = backpack
end

local function onPlayer(player: Player)
	-- The backpack is emptied on every respawn, so hand out a new stick each time.
	player.CharacterAdded:Connect(function()
		give(player)
	end)
	if player.Character then
		give(player)
	end
end

function SelfieStickService.start()
	-- Not using StarterPack: players who spawned before this ran would miss out.
	template = buildTool()
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
end

return SelfieStickService
