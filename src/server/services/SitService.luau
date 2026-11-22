--!strict
-- Pallet seats: adds a "Sit" prompt to every seat tagged "PoseSeat" in Studio and
-- picks a random sitting pose when someone sits. The pose is stored as a character
-- attribute so every client can show it (see client SitPoseController).
--
-- Seats have CanTouch off in Studio, so players only sit through the prompt, never by
-- walking over a pallet. Jump to stand up (Roblox default).
--
-- Chairs and stools: give the Seat the attribute Pose = "Chair". They use Roblox's normal
-- sitting pose (the random poses are for sitting on the floor / pallets), and their prompt sits
-- a little lower so it doesn't cover things on the table (like the question ball).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SitPoses = require(ReplicatedStorage.Shared.SitPoses)

local SitService = {}

local rng = Random.new()
-- Chair prompts move down by this many pixels (UIOffset; negative Y is down).
local CHAIR_PROMPT_DROP = -60

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
	prompt.ActionText = "Sit"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	-- Short range so it only shows when you're right at a pallet, not from the tier above.
	prompt.MaxActivationDistance = 6
	prompt.RequiresLineOfSight = false
	-- Only the closest seat shows a prompt, so a row of pallets doesn't stack up prompts.
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	local function isChair(): boolean
		return seat:GetAttribute("Pose") == "Chair"
	end
	local function applyStyle()
		prompt.UIOffset = if isChair() then Vector2.new(0, CHAIR_PROMPT_DROP) else Vector2.zero
	end
	applyStyle()
	seat:GetAttributeChangedSignal("Pose"):Connect(applyStyle)
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
				-- Chairs keep Roblox's own sitting pose (no attribute).
				if not isChair() then
					character:SetAttribute(SitPoses.Attribute, randomPose())
				end
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
