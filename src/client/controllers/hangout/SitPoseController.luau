--!strict
-- Shows the sitting pose of every seated player (including other players).
--
-- The server puts the pose name on the character as an attribute. Each frame, right after
-- Roblox's animations run (PreSimulation), this sets the R15 joints to that pose.
-- Joint Transform changes don't replicate, so every client applies them for everyone.
-- Avatars use either Motor6D or (with Roblox's newer avatar joints) AnimationConstraint;
-- both have a Transform property, so both are handled.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SitPoses = require(ReplicatedStorage.Shared.hangout.SitPoses)

-- Motor6D or AnimationConstraint -> target Transform
type JointMap = { [Instance]: CFrame }

local SitPoseController = {}

local active: { [Model]: JointMap? } = {}

local function toCFrame(degrees: Vector3): CFrame
	return CFrame.Angles(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
end

local function buildJointMap(character: Model, poseId: string): JointMap?
	local pose = SitPoses.Poses[poseId]
	if not pose then
		return nil
	end
	local map: JointMap = {}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") or descendant:IsA("AnimationConstraint") then
			local degrees = pose.Joints[descendant.Name]
			if degrees then
				map[descendant] = toCFrame(degrees)
			end
		end
	end
	return if next(map) then map else nil
end

local function refresh(character: Model)
	local poseId = character:GetAttribute(SitPoses.Attribute)
	if typeof(poseId) == "string" then
		active[character] = buildJointMap(character, poseId)
	else
		active[character] = nil
	end
end

local function watchCharacter(character: Model)
	refresh(character)
	character:GetAttributeChangedSignal(SitPoses.Attribute):Connect(function()
		refresh(character)
	end)
	character.Destroying:Connect(function()
		active[character] = nil
	end)
end

local function watchPlayer(player: Player)
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end

function SitPoseController.start()
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	RunService.PreSimulation:Connect(function()
		for character, joints in active do
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			-- Only pose characters that are actually sitting.
			if character.Parent and joints and humanoid and humanoid.Sit then
				for joint, transform in joints do
					(joint :: any).Transform = transform
				end
			else
				active[character] = nil
			end
		end
	end)
end

return SitPoseController
