--!strict
-- Faces the player toward the view every time they spawn.
--
-- Roblox doesn't turn the camera to match the spawn, so a new player could start out looking
-- at the stalls instead of the city. On every spawn this turns the character to the front face
-- of the SpawnLocation it landed on, then puts the camera behind the character. Rotate the
-- SpawnLocation in Studio to change where players look when they join.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.core.Config)

local SpawnViewController = {}

local function nearestSpawn(position: Vector3): SpawnLocation?
	local best: SpawnLocation? = nil
	local bestDistance = Config.SpawnView.MaxSpawnDistance
	for _, instance in Workspace:GetDescendants() do
		if instance:IsA("SpawnLocation") then
			local distance = (instance.Position - position).Magnitude
			if distance < bestDistance then
				best = instance
				bestDistance = distance
			end
		end
	end
	return best
end

local function faceView(character: Model)
	local rootPart = character:WaitForChild("HumanoidRootPart", 10)
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	-- Let Roblox's camera finish its own setup for the new character first.
	RunService.RenderStepped:Wait()
	RunService.RenderStepped:Wait()

	local spawnLocation = nearestSpawn(rootPart.Position)
	if not spawnLocation then
		return
	end
	local look = spawnLocation.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return
	end
	local direction = flat.Unit

	rootPart.CFrame = CFrame.lookAlong(rootPart.Position, direction)

	-- The default camera keeps whatever angle it is given and only fixes the distance.
	local camera = Workspace.CurrentCamera
	if camera then
		local focus = rootPart.Position + Vector3.new(0, 1.5, 0)
		local from = focus
			- direction * Config.SpawnView.CameraDistance
			+ Vector3.new(0, Config.SpawnView.CameraHeight, 0)
		camera.CFrame = CFrame.lookAt(from, focus)
	end
end

function SpawnViewController.start()
	local player = Players.LocalPlayer
	if player.Character then
		task.spawn(faceView, player.Character)
	end
	player.CharacterAdded:Connect(faceView)
end

return SpawnViewController
