--!strict
-- Smooth movement for every input (keyboard, mobile thumbstick, gamepad).
--
-- Roblox starts and stops the character instantly. Each frame, Roblox's PlayerModule calls
-- Humanoid:Move at RenderPriority.Input with the direction the player is pressing. Right after
-- that, this reads that direction from Humanoid.MoveDirection and replaces it with an eased
-- version, so walking speeds up and slows down smoothly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.core.Config)

local BIND_NAME = "TanawSmoothMovement"
local STOP_THRESHOLD = 0.01

local MovementController = {}

-- While paused, this leaves the character alone (e.g. the photobooth walks it to a spot).
local paused = false

function MovementController.setPaused(on: boolean)
	paused = on
end

function MovementController.start()
	local player = Players.LocalPlayer

	local humanoid: Humanoid? = nil
	local smoothed = Vector3.zero

	local function onCharacterAdded(character: Model)
		humanoid = character:WaitForChild("Humanoid") :: Humanoid
		smoothed = Vector3.zero
	end

	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)

	-- Input + 1 = right after Roblox's ControlModule has applied its own Move for this frame.
	RunService:BindToRenderStep(
		BIND_NAME,
		Enum.RenderPriority.Input.Value + 1,
		function(deltaTime: number)
			if paused or not humanoid or humanoid.Health <= 0 or humanoid.Sit then
				smoothed = Vector3.zero
				return
			end

			-- What the player is pressing this frame, already turned into a world direction.
			local target = humanoid.MoveDirection

			-- Nothing pressed and already stopped: leave Roblox alone.
			if target.Magnitude < STOP_THRESHOLD and smoothed.Magnitude < STOP_THRESHOLD then
				smoothed = Vector3.zero
				return
			end

			local rate = if target.Magnitude >= smoothed.Magnitude
				then Config.Movement.Acceleration
				else Config.Movement.Deceleration
			local alpha = 1 - math.exp(-rate * deltaTime)
			smoothed = smoothed:Lerp(target, alpha)

			humanoid:Move(smoothed, false)
		end
	)
end

return MovementController
