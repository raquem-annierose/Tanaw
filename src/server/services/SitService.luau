--!strict
-- Pallet seats: adds an "Umupo" prompt to every seat tagged "PoseSeat" in Studio and
-- picks a random sitting pose when someone sits. The pose is stored as a character
-- attribute so every client can show it (see client SitPoseController).
--
-- Seats have CanTouch off in Studio, so players only sit through the prompt, never by
-- walking over a pallet. Jump to stand up (Roblox default).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SitPoses = require(ReplicatedStorage.Shared.SitPoses)

local SitService = {}

local rng = Random.new()

local function randomPose(): string
	return SitPoses.Order[rng:NextInteger(1, #SitPoses.Order)]
end

local function setupSeat(instance: Instance)
	if not instance:IsA("Seat") then
		return
	end
	local seat: Seat = instance

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SitPrompt"
	prompt.ActionText = "Umupo"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	-- Only the closest seat shows a prompt, so a row of pallets doesn't stack up prompts.
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Parent = seat

	prompt.Triggered:Connect(function(player: Player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or humanoid.Sit or seat.Occupant then
			return
		end
		seat:Sit(humanoid)
	end)

	local seatedCharacter: Model? = nil
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if seatedCharacter then
			seatedCharacter:SetAttribute(SitPoses.Attribute, nil)
			seatedCharacter = nil
		end
		local occupant = seat.Occupant
		if occupant then
			local character = occupant.Parent
			if character and character:IsA("Model") then
				character:SetAttribute(SitPoses.Attribute, randomPose())
				seatedCharacter = character
			end
		end
		prompt.Enabled = occupant == nil
	end)
end

function SitService.start()
	for _, seat in CollectionService:GetTagged(SitPoses.SeatTag) do
		setupSeat(seat)
	end
	CollectionService:GetInstanceAddedSignal(SitPoses.SeatTag):Connect(setupSeat)
end

return SitService
