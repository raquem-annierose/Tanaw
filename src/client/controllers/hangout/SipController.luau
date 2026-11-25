--!strict
-- Plays the bubble tea sip on every character (including other players). The server stores the
-- time of the sip on the character (Config.Cafe.SipAttribute, see CafeService). For
-- Config.Cafe.SipSeconds this bends the right arm so the cup comes up to the mouth and tips the
-- head back a little, on top of the normal "holding a tool" pose.
--
-- Like SitPoseController, it changes joint Transforms right after Roblox's animations run
-- (PreSimulation). Those changes don't replicate, so every client does it for everyone.
-- Works with Motor6D and AnimationConstraint joints. R6 avatars don't sip.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.core.Config)

-- Extra rotation (degrees) at the top of the sip, added on top of Roblox's tool-hold pose.
-- Found by measuring in a playtest: the cup sits upright in front of the chest with the straw
-- tip at the mouth, and the head dips slightly toward it.
local SIP_POSE: { [string]: Vector3 } = {
	RightShoulder = Vector3.new(-135, 10, 70),
	RightElbow = Vector3.new(120, 0, 0),
	RightWrist = Vector3.new(5, 0, 0),
	Neck = Vector3.new(-6, 0, 0),
}
-- Share of the sip spent raising / lowering the cup (the rest is drinking).
local EASE = 0.3

local SipController = {}

type Sip = { startedAt: number, joints: { [Instance]: CFrame } }

local active: { [Model]: Sip } = {}

local function findJoints(character: Model): { [Instance]: CFrame }
	local joints: { [Instance]: CFrame } = {}
	for _, d in character:GetDescendants() do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			local degrees = SIP_POSE[d.Name]
			if degrees then
				joints[d] =
					CFrame.Angles(math.rad(degrees.X), math.rad(degrees.Y), math.rad(degrees.Z))
			end
		end
	end
	return joints
end

-- 0 → 1 while raising, 1 while drinking, 1 → 0 while lowering (smooth).
local function weight(t: number): number
	local x = if t < EASE then t / EASE elseif t > 1 - EASE then (1 - t) / EASE else 1
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function watchCharacter(character: Model)
	character:GetAttributeChangedSignal(Config.Cafe.SipAttribute):Connect(function()
		local at = character:GetAttribute(Config.Cafe.SipAttribute)
		if typeof(at) ~= "number" then
			return
		end
		local joints = findJoints(character)
		if next(joints) then
			active[character] = { startedAt = at, joints = joints }
		end
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

function SipController.start()
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)

	RunService.PreSimulation:Connect(function()
		local now = Workspace:GetServerTimeNow()
		for character, sip in active do
			local t = (now - sip.startedAt) / Config.Cafe.SipSeconds
			if t >= 1 or not character.Parent then
				active[character] = nil
				continue
			end
			if t < 0 then
				continue
			end
			local w = weight(t)
			for joint, full in sip.joints do
				local j = joint :: any
				j.Transform = j.Transform * CFrame.new():Lerp(full, w)
			end
		end
	end)
end

return SipController
