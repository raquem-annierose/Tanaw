--!strict
-- Shift lock for players without a keyboard.
--
-- On PC, Roblox's built-in shift lock handles this (Shift key, enabled through
-- StarterPlayer.EnableMouseLockOption). Mobile/tablet and console have no built-in version,
-- so this adds L3 for gamepads, and ui/ShiftLockButton adds an on-screen Lock button for touch
-- screens. While on, the character faces where the camera looks and the camera sits over the
-- shoulder.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local ACTION_NAME = "TanawShiftLock"
local BIND_NAME = "TanawShiftLockRotate"

local ShiftLockController = {}

local changedEvent = Instance.new("BindableEvent")
ShiftLockController.Changed = changedEvent.Event

local enabled = false
local humanoid: Humanoid? = nil
local rootPart: BasePart? = nil

local function apply()
	if humanoid then
		humanoid.AutoRotate = not enabled
		humanoid.CameraOffset = if enabled then Config.ShiftLock.CameraOffset else Vector3.zero
	end
end

function ShiftLockController.isEnabled(): boolean
	return enabled
end

function ShiftLockController.toggle()
	enabled = not enabled
	apply()
	changedEvent:Fire(enabled)
end

function ShiftLockController.start()
	local player = Players.LocalPlayer

	local function onCharacterAdded(character: Model)
		humanoid = character:WaitForChild("Humanoid") :: Humanoid
		rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
		-- Keep the player's choice across respawns.
		apply()
	end

	-- Gamepad only. Roblox's own touch button for this sits on top of the jump button on
	-- phones, so touch screens get ui/ShiftLockButton instead.
	ContextActionService:BindAction(ACTION_NAME, function(_, inputState: Enum.UserInputState)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		ShiftLockController.toggle()
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonL3)

	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)

	-- Camera + 1 = after the camera has moved this frame, so the character turns with it.
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		local camera = Workspace.CurrentCamera
		if not enabled or not camera or not rootPart or not humanoid or humanoid.Sit then
			return
		end

		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 1e-3 then
			return
		end
		rootPart.CFrame = CFrame.lookAlong(rootPart.Position, flat.Unit)
	end)
end

return ShiftLockController
