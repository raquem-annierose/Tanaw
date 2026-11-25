--!strict
-- NPCs that wear a real Roblox user's avatar, e.g. the Hiraya cashier.
--
-- In Studio, put an invisible anchored part where the NPC should stand: its bottom face on the
-- floor and its front face (LookVector) the way the NPC should look. Tag it "AvatarNpc" and give it:
--   UserId (number)  whose avatar to wear
--   Label  (string)  optional tag shown above the head, e.g. "Cashier"
-- The avatar is loaded when the server starts, so outfit changes show up on the next server.
--
-- Other services can stand an avatar on a spot too (spawnAvatar), e.g. the playtime Top 3.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local TAG = "AvatarNpc"
-- Roblox's default R15 idle, so the NPC breathes instead of standing frozen.
local IDLE_ANIMATION = "rbxassetid://507766388"
local LOAD_TRIES = 3
local LABEL_DISTANCE = 40

local NpcService = {}

local function loadAvatar(userId: number): Model?
	for attempt = 1, LOAD_TRIES do
		local ok, result = pcall(Players.CreateHumanoidModelFromUserId, Players, userId)
		if ok then
			return result
		end
		warn(`[NpcService] could not load avatar {userId} (try {attempt}): {result}`)
		task.wait(2 * attempt)
	end
	return nil
end

local function playLoop(humanoid: Humanoid, animationId: string)
	local animator: Animator
	local existing = humanoid:FindFirstChildOfClass("Animator")
	if existing then
		animator = existing
	else
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	local track = animator:LoadAnimation(animation)
	track.Looped = true
	track:Play()
end

-- Small pill-shaped tag above the head (Humanoid name tags don't show on these NPCs).
local function addLabel(head: BasePart, text: string)
	local gui = Instance.new("BillboardGui")
	gui.Name = "NpcLabel"
	-- Wide enough for long names; the pill inside is only as wide as its text.
	gui.Size = UDim2.fromOffset(240, 28)
	gui.StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y / 2 + 1.2, 0)
	gui.MaxDistance = LABEL_DISTANCE
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0

	local pill = Instance.new("TextLabel")
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.fromScale(0.5, 0.5)
	pill.Size = UDim2.fromScale(0, 1)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	pill.BackgroundTransparency = 0.35
	pill.Font = Enum.Font.GothamBold
	pill.Text = text
	pill.TextColor3 = Color3.fromRGB(255, 255, 255)
	pill.TextSize = 16
	pill.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = pill

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = pill

	gui.Parent = head
end

-- Changes (or adds, or with "" removes) the tag above an NPC's head.
function NpcService.setLabel(model: Model, text: string)
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local gui = head:FindFirstChild("NpcLabel")
	local pill = gui and gui:FindFirstChildOfClass("TextLabel")
	if text == "" then
		if gui then
			gui:Destroy()
		end
	elseif pill then
		pill.Text = text
	else
		addLabel(head, text)
	end
end

-- Loads userId's avatar and stands it on `spot` (see the top of this file), next to the spot in
-- the Explorer, looping `animationId` (default: idle). Yields while the avatar loads. Returns nil
-- if it couldn't load.
function NpcService.spawnAvatar(
	spot: BasePart,
	userId: number,
	label: string?,
	animationId: number?
): Model?
	local model = loadAvatar(userId)
	if not model then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		model:Destroy()
		return nil
	end

	model.Name = `{spot.Name}Npc`
	model.PrimaryPart = root
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	root.Anchored = true

	-- Stand with the feet on the spot's bottom face.
	local lift = if humanoid.RigType == Enum.HumanoidRigType.R15
		then humanoid.HipHeight + root.Size.Y / 2
		else 3
	model:PivotTo(spot.CFrame * CFrame.new(0, -spot.Size.Y / 2 + lift, 0))
	if label then
		NpcService.setLabel(model, label)
	end
	model.Parent = spot.Parent

	playLoop(humanoid, if animationId then `rbxassetid://{animationId}` else IDLE_ANIMATION)
	return model
end

local function spawnNpc(spot: Instance)
	if not spot:IsA("BasePart") then
		return
	end
	local userId = spot:GetAttribute("UserId")
	if typeof(userId) ~= "number" then
		warn(`[NpcService] {spot:GetFullName()} has no UserId attribute`)
		return
	end
	local label = spot:GetAttribute("Label")
	NpcService.spawnAvatar(spot, userId, if typeof(label) == "string" then label else nil)
end

function NpcService.start()
	for _, spot in CollectionService:GetTagged(TAG) do
		task.spawn(spawnNpc, spot)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(spawnNpc)
end

return NpcService
