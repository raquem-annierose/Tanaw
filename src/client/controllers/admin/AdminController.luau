--!strict
-- Client side of the admin commands (see server AdminService): fly, noclip and chat notices.
--
-- The server decides who may use them and tells this client to switch an effect on or off;
-- this only runs what the server asked for. Both effects end when the character respawns.
--
-- Fly: moves toward where the camera looks while you walk (so looking up while moving climbs),
-- Space goes up and Ctrl goes down.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.core.Config)
local Remotes = require(ReplicatedStorage.Shared.core.Remotes)

local FLY_BIND = "TanawAdminFly"

local AdminController = {}

local player = Players.LocalPlayer
local flyParts: { Instance } = {}
local noclipConnection: RBXScriptConnection? = nil
local savedCollide: { [BasePart]: boolean } = {}

local function parts(): (Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	return humanoid, if root and root:IsA("BasePart") then root else nil
end

local function stopFly()
	RunService:UnbindFromRenderStep(FLY_BIND)
	for _, instance in flyParts do
		instance:Destroy()
	end
	flyParts = {}
	local humanoid = parts()
	if humanoid then
		humanoid.PlatformStand = false
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end

local function startFly()
	stopFly()
	local humanoid, root = parts()
	if not humanoid or not root then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "AdminFly"
	attachment.Parent = root

	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.MaxForce = math.huge
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = root

	local turn = Instance.new("AlignOrientation")
	turn.Mode = Enum.OrientationAlignmentMode.OneAttachment
	turn.Attachment0 = attachment
	turn.MaxTorque = math.huge
	turn.Responsiveness = 40
	turn.CFrame = root.CFrame.Rotation
	turn.Parent = root

	flyParts = { attachment, velocity, turn }
	humanoid.PlatformStand = true

	RunService:BindToRenderStep(FLY_BIND, Enum.RenderPriority.Camera.Value + 2, function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 1e-3 then
			return
		end
		flat = flat.Unit
		local right = Vector3.new(-flat.Z, 0, flat.X)

		-- How much the player is pushing forward / sideways, from any input device.
		local move = humanoid.MoveDirection
		local forward, side = move:Dot(flat), move:Dot(right)
		local direction = look * forward + camera.CFrame.RightVector * side

		local vertical = 0
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			vertical += 1
		end
		if
			UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		then
			vertical -= 1
		end
		direction += Vector3.yAxis * vertical

		if direction.Magnitude > 1 then
			direction = direction.Unit
		end
		velocity.VectorVelocity = direction * Config.Admin.FlySpeed
		turn.CFrame = CFrame.lookAlong(Vector3.zero, flat)
	end)
end

local function stopNoclip()
	if noclipConnection then
		noclipConnection:Disconnect()
		noclipConnection = nil
	end
	for part, collide in savedCollide do
		if part.Parent then
			part.CanCollide = collide
		end
	end
	savedCollide = {}
end

local function startNoclip()
	stopNoclip()
	-- Roblox turns some body parts' collision back on every step, so keep switching it off.
	noclipConnection = RunService.Stepped:Connect(function()
		local character = player.Character
		if not character then
			return
		end
		for _, part in character:GetDescendants() do
			if part:IsA("BasePart") and part.CanCollide then
				if savedCollide[part] == nil then
					savedCollide[part] = true
				end
				part.CanCollide = false
			end
		end
	end)
end

local function showNotice(text: string)
	local channels = TextChatService:FindFirstChild("TextChannels")
	local general = channels and channels:FindFirstChild("RBXSystem")
		or (channels and channels:FindFirstChild("RBXGeneral"))
	if general and general:IsA("TextChannel") then
		general:DisplaySystemMessage(`[Admin] {text}`)
	end
end

local function listen()
	-- The remote only exists where admin commands are on (DEV/STAGING).
	local remote = Remotes.waitForAdmin(15)
	if not remote then
		return
	end
	remote.OnClientEvent:Connect(function(kind: string, value: any)
		if kind == "Fly" then
			if value == true then
				startFly()
			else
				stopFly()
			end
		elseif kind == "Noclip" then
			if value == true then
				startNoclip()
			else
				stopNoclip()
			end
		elseif kind == "Notice" and typeof(value) == "string" then
			showNotice(value)
		end
	end)
end

function AdminController.start()
	player.CharacterAdded:Connect(function()
		stopFly()
		stopNoclip()
	end)
	-- Waiting for the remote must not hold up the other controllers.
	task.spawn(listen)
end

return AdminController
