--!strict
-- Talking to the cashier. Pressing the Order prompt (see CafeService) moves the camera in front of
-- the NPC's face and a small dialog with Yes / No shows to their right, like a game conversation.
-- Yes tells the server; it decides whether to hand over the drink. Either answer (or the
-- timeout) puts the camera and controls back.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- Camera framing: this far in front of the NPC's face, and how far to slide the view so the
-- NPC sits left of center with room for the dialog on the right.
local CAMERA_DISTANCE = 5.5
local CAMERA_LIFT = 0.2
local SIDE_SHIFT = 1.4
local CAMERA_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local CafeController = {}

local player = Players.LocalPlayer

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function button(text: string, order: number, primary: boolean): TextButton
	local b = Instance.new("TextButton")
	b.Name = text
	b.LayoutOrder = order
	b.Size = UDim2.fromOffset(96, 38)
	b.AutoButtonColor = true
	b.BackgroundColor3 = if primary
		then Color3.fromRGB(45, 32, 26)
		else Color3.fromRGB(230, 222, 212)
	b.TextColor3 = if primary then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(45, 32, 26)
	b.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
	b.TextSize = 18
	b.Text = text
	b.Selectable = true
	corner(b, UDim.new(1, 0))
	return b
end

local function build(): (ScreenGui, TextLabel, TextButton, TextButton)
	local gui = Instance.new("ScreenGui")
	gui.Name = "CafeDialog"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

	-- Right of the NPC, who is framed just left of center.
	local panel = Instance.new("Frame")
	panel.Name = "Bubble"
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.fromScale(0.56, 0.42)
	panel.Size = UDim2.fromOffset(250, 128)
	panel.BackgroundColor3 = Color3.fromRGB(255, 250, 244)
	corner(panel, UDim.new(0, 16))
	panel.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(45, 32, 26)
	stroke.Thickness = 2
	stroke.Transparency = 0.6
	stroke.Parent = panel

	local name = Instance.new("TextLabel")
	name.Name = "Speaker"
	name.Position = UDim2.fromOffset(16, 10)
	name.Size = UDim2.new(1, -32, 0, 18)
	name.BackgroundTransparency = 1
	name.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
	name.TextSize = 14
	name.TextColor3 = Color3.fromRGB(150, 105, 70)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Parent = panel

	local question = Instance.new("TextLabel")
	question.Position = UDim2.fromOffset(16, 30)
	question.Size = UDim2.new(1, -32, 0, 34)
	question.BackgroundTransparency = 1
	question.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
	question.TextSize = 20
	question.TextWrapped = true
	question.TextColor3 = Color3.fromRGB(45, 32, 26)
	question.TextXAlignment = Enum.TextXAlignment.Left
	question.Text = Config.Cafe.Question
	question.Parent = panel

	local row = Instance.new("Frame")
	row.Position = UDim2.new(0, 16, 1, -50)
	row.Size = UDim2.new(1, -32, 0, 38)
	row.BackgroundTransparency = 1
	row.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	local yes = button("Yes", 1, true)
	-- Frees the mouse while the dialog is up, even with shift lock on, so the buttons can be clicked.
	yes.Modal = true
	yes.Parent = row
	local no = button("No", 2, false)
	no.Parent = row

	return gui, name, yes, no
end

-- Roblox's own movement controls, so the player stands still while talking.
local function controls(): any
	local ok, module = pcall(function()
		local playerModule = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
		return playerModule and (require(playerModule :: ModuleScript) :: any):GetControls()
	end)
	return if ok then module else nil
end

local function npcHead(spot: BasePart): BasePart?
	local model = spot.Parent and spot.Parent:FindFirstChild(`{spot.Name}Npc`)
	local head = model and model:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head else nil
end

-- Runs every frame while talking: keeps the player's own avatar hidden (it stands between the
-- camera and the NPC, and Roblox's camera scripts keep un-hiding it).
local HIDE_STEP = "TanawCafeHide"

local function setCharacterHidden(hidden: boolean)
	local character = player.Character
	if not character then
		return
	end
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

function CafeController.start()
	local gui, speaker, yes, no = build()
	gui.Parent = player:WaitForChild("PlayerGui")

	local talking = false
	local shownAt = 0
	local tween: Tween? = nil
	-- The humanoid we froze and its speed before, to put back.
	local frozen: Humanoid? = nil
	local savedSpeed = 16

	local function close()
		if not talking then
			return
		end
		talking = false
		gui.Enabled = false
		if tween then
			tween:Cancel()
			tween = nil
		end
		RunService:UnbindFromRenderStep(HIDE_STEP)
		setCharacterHidden(false)
		ProximityPromptService.Enabled = true

		local camera = Workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		if frozen then
			frozen.WalkSpeed = savedSpeed
			frozen = nil
		end
		local c = controls()
		if c then
			c:Enable()
		end
	end

	local function open(spot: BasePart)
		talking = true
		local label = spot:GetAttribute("Label")
		speaker.Text = if typeof(label) == "string" and label ~= "" then label else spot.Name
		gui.Enabled = true
		-- Hide the "Order" prompt while the dialog is up.
		ProximityPromptService.Enabled = false

		local head = npcHead(spot)
		if head then
			local face = head.Position
			local eye = face
				+ spot.CFrame.LookVector * CAMERA_DISTANCE
				+ Vector3.new(0, CAMERA_LIFT, 0)
			local view = CFrame.lookAt(eye, face)
			local camera = Workspace.CurrentCamera
			camera.CameraType = Enum.CameraType.Scriptable
			local move = TweenService:Create(camera, CAMERA_TWEEN, {
				CFrame = CFrame.lookAt(eye, face + view.RightVector * SIDE_SHIFT),
			})
			tween = move
			move:Play()
			RunService:BindToRenderStep(HIDE_STEP, Enum.RenderPriority.Last.Value, function()
				setCharacterHidden(true)
			end)
		end

		-- Stand still. Disabling Roblox's controls isn't enough on its own: MovementController
		-- keeps easing toward the last direction, so the speed goes to 0 as well.
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			frozen = humanoid
			savedSpeed = humanoid.WalkSpeed
			humanoid.WalkSpeed = 0
		end
		local c = controls()
		if c then
			c:Disable()
		end

		local at = os.clock()
		shownAt = at
		task.delay(Config.Cafe.AnswerTimeout, function()
			if shownAt == at then
				close()
			end
		end)
	end

	player.CharacterAdded:Connect(close)

	-- Waits for the server's remote, so don't hold up the other controllers.
	-- Open right away on this device instead of waiting for the server, so the camera moves the
	-- moment the prompt is pressed. The server sees the same press and remembers it asked.
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		local spot = prompt.Parent
		if
			not talking
			and prompt.Name == "OrderPrompt"
			and spot
			and spot:IsA("BasePart")
			and spot:HasTag(Config.Cafe.Tag)
		then
			open(spot)
		end
	end)

	task.spawn(function()
		local remote = Remotes.cafe()
		yes.Activated:Connect(function()
			close()
			remote:FireServer("Accept")
		end)
		no.Activated:Connect(close)
	end)
end

return CafeController
