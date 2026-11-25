--!strict
-- Selfie camera: while this player holds the selfie stick (phone Camera app, selfie mode), the
-- camera sits at the phone on the end of the stick and looks back at their face, with the view
-- behind them. Putting the stick away goes back to the normal camera. Walk or turn to change
-- the angle.
--
-- The stick itself is made on the server (SelfieStickService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.core.Config)

local RENDER_STEP = "TanawSelfieCamera"
-- How far the camera sits behind the phone screen, so the phone itself isn't in the shot.
local LENS_OFFSET = 0.1

local SelfieController = {}

local player = Players.LocalPlayer
local active = false
local savedFov = 70
local hidden: { BasePart } = {}

local function stop()
	if not active then
		return
	end
	active = false
	RunService:UnbindFromRenderStep(RENDER_STEP)
	for _, p in hidden do
		p.LocalTransparencyModifier = 0
	end
	table.clear(hidden)

	local camera = Workspace.CurrentCamera
	camera.FieldOfView = savedFov
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local function start(tool: Tool)
	local phone = tool:WaitForChild("Phone", 5)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not phone or not phone:IsA("BasePart") or not head or not head:IsA("BasePart") then
		return
	end
	if tool.Parent ~= character then
		-- Unequipped while we were waiting.
		return
	end

	stop()
	active = true

	-- Hide the stick for this player only, so it doesn't block the shot. Others still see it.
	for _, name in { "Phone", "Clamp", "Stick" } do
		local p = tool:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			p.LocalTransparencyModifier = 1
			table.insert(hidden, p)
		end
	end

	local camera = Workspace.CurrentCamera
	savedFov = camera.FieldOfView
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = Config.SelfieStick.FieldOfView

	RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 1, function()
		if not phone.Parent or not head.Parent then
			stop()
			return
		end
		local target = head.Position + Vector3.new(0, 0.2, 0)
		local lens = phone.Position + (phone.Position - target).Unit * LENS_OFFSET
		camera.CFrame = CFrame.lookAt(lens, target)
	end)
end

local function watchCharacter(character: Model)
	stop()
	character.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Tool") and child.Name == Config.SelfieStick.ToolName then
			start(child)
		end
	end)
	character.ChildRemoved:Connect(function(child: Instance)
		if child:IsA("Tool") and child.Name == Config.SelfieStick.ToolName then
			stop()
		end
	end)
end

function SelfieController.start()
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end

return SelfieController
