--!strict
-- Wishing Sky Lanterns (client): clean heartfelt wish modal + touching 3-stage
-- lantern kindling, graceful drift over the city lights, and automatic cleanup
-- once each lantern floats far into the sky.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.core.Remotes)
local SkyLantern = require(ReplicatedStorage.Shared.world.SkyLantern)

local VIEW_FORWARD = SkyLantern.ViewDirection
local VIEW_RIGHT = VIEW_FORWARD:Cross(Vector3.yAxis).Unit

local KINDLE_SECONDS = 2.4
local FLOAT_SECONDS = 15.0
local FADE_SECONDS = 4.0
local MAX_FLIGHT_DISTANCE = 135

local FONT_BOLD = Font.fromEnum(Enum.Font.BuilderSansBold)
local FONT_REG = Font.fromEnum(Enum.Font.BuilderSans)
local FONT_HAND = Font.fromEnum(Enum.Font.IndieFlower)

type ActiveLantern = {
	model: Model,
	body: Part,
	cap: Part,
	rim: Part,
	flame: Part,
	light: PointLight,
	embers: ParticleEmitter,
	wishLabel: TextLabel,
	authorLabel: TextLabel,
	origin: Vector3,
	driftForward: number,
	driftSide: number,
	riseSpeed: number,
	swayPhase: number,
	swayAmp: number,
	elapsed: number,
	fadeStart: number?,
}

local SkyLanternController = {}

local player = Players.LocalPlayer
local rng = Random.new()
local activeLanterns: { ActiveLantern } = {}
local container: Folder? = nil

local modalBackdrop: Frame? = nil
local wishInput: TextBox? = nil
local counterLabel: TextLabel? = nil
local statusLabel: TextLabel? = nil
local sendButton: TextButton? = nil
local toastLabel: TextLabel? = nil
local isAnonymous = false
local isSending = false
local remoteEvent: RemoteEvent? = nil

local function corner(parent: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function borderStroke(
	parent: GuiObject,
	color: Color3,
	thickness: number,
	transparency: number
): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency
	stroke.Parent = parent
	return stroke
end

local function getContainer(): Folder
	if container and container.Parent == Workspace then
		return container
	end
	local existing = Workspace:FindFirstChild("FloatingSkyLanterns")
	if existing and existing:IsA("Folder") then
		container = existing
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "FloatingSkyLanterns"
	folder.Parent = Workspace
	container = folder
	return folder
end

local function showToast(message: string)
	if not toastLabel then
		return
	end
	local label = toastLabel
	label.Text = message
	label.TextTransparency = 1
	label.Visible = true
	TweenService:Create(
		label,
		TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ TextTransparency = 0 }
	):Play()

	task.delay(4.4, function()
		if label.Text ~= message then
			return
		end
		local fade = TweenService:Create(
			label,
			TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
			{ TextTransparency = 1 }
		)
		fade.Completed:Connect(function()
			if label.Text == message then
				label.Visible = false
			end
		end)
		fade:Play()
	end)
end

local function setModalOpen(open: boolean)
	if not modalBackdrop then
		return
	end
	modalBackdrop.Visible = open
	if open then
		isSending = false
		if statusLabel then
			statusLabel.Text = ""
		end
		if sendButton then
			sendButton.Text = "Light & Release"
		end
		if wishInput then
			wishInput.Text = ""
			wishInput:CaptureFocus()
		end
	else
		if wishInput then
			wishInput:ReleaseFocus()
		end
	end
end

local function buildUi()
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "SkyLanternUi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 18
	gui.Parent = playerGui

	-- Subtle poetic floating toast near the bottom of the screen when a wish is released.
	local toast = Instance.new("TextLabel")
	toast.Name = "WishToast"
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, -78)
	toast.Size = UDim2.new(0.8, 0, 0, 34)
	toast.BackgroundTransparency = 1
	toast.FontFace = FONT_HAND
	toast.Text = ""
	toast.TextSize = 26
	toast.TextColor3 = Color3.fromRGB(255, 240, 210)
	toast.TextStrokeColor3 = Color3.fromRGB(24, 16, 36)
	toast.TextStrokeTransparency = 0.35
	toast.Visible = false
	toast.Parent = gui
	toastLabel = toast

	-- Soft dim backdrop behind the wish modal.
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(10, 8, 20)
	backdrop.BackgroundTransparency = 0.45
	backdrop.Visible = false
	backdrop.Parent = gui
	modalBackdrop = backdrop

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(410, 294)
	card.BackgroundColor3 = Color3.fromRGB(24, 20, 38)
	card.BackgroundTransparency = 0.05
	corner(card, 18)
	borderStroke(card, Color3.fromRGB(255, 214, 152), 1.5, 0.48)
	card.Parent = backdrop

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 22)
	padding.PaddingBottom = UDim.new(0, 20)
	padding.PaddingLeft = UDim.new(0, 24)
	padding.PaddingRight = UDim.new(0, 24)
	padding.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 28)
	title.BackgroundTransparency = 1
	title.FontFace = FONT_BOLD
	title.Text = "Light a Sky Lantern"
	title.TextSize = 23
	title.TextColor3 = Color3.fromRGB(255, 238, 204)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = card

	local subtitle = Instance.new("TextLabel")
	subtitle.Position = UDim2.fromOffset(0, 30)
	subtitle.Size = UDim2.new(1, 0, 0, 34)
	subtitle.BackgroundTransparency = 1
	subtitle.FontFace = FONT_REG
	subtitle.Text = "Write a quiet wish or message, then watch it drift over the city lights."
	subtitle.TextSize = 14
	subtitle.TextWrapped = true
	subtitle.TextColor3 = Color3.fromRGB(204, 196, 222)
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextYAlignment = Enum.TextYAlignment.Top
	subtitle.Parent = card

	local inputBox = Instance.new("TextBox")
	inputBox.Name = "WishInput"
	inputBox.Position = UDim2.fromOffset(0, 74)
	inputBox.Size = UDim2.new(1, 0, 0, 78)
	inputBox.BackgroundColor3 = Color3.fromRGB(34, 29, 52)
	inputBox.TextColor3 = Color3.fromRGB(255, 248, 236)
	inputBox.PlaceholderColor3 = Color3.fromRGB(152, 144, 174)
	inputBox.PlaceholderText = "I wish for peaceful nights, good friends, and..."
	inputBox.FontFace = FONT_REG
	inputBox.TextSize = 16
	inputBox.Text = ""
	inputBox.MultiLine = true
	inputBox.TextWrapped = true
	inputBox.ClearTextOnFocus = false
	inputBox.TextXAlignment = Enum.TextXAlignment.Left
	inputBox.TextYAlignment = Enum.TextYAlignment.Top
	corner(inputBox, 12)
	borderStroke(inputBox, Color3.fromRGB(134, 118, 172), 1, 0.5)
	inputBox.Parent = card
	wishInput = inputBox

	local inputPad = Instance.new("UIPadding")
	inputPad.PaddingTop = UDim.new(0, 10)
	inputPad.PaddingBottom = UDim.new(0, 10)
	inputPad.PaddingLeft = UDim.new(0, 12)
	inputPad.PaddingRight = UDim.new(0, 12)
	inputPad.Parent = inputBox

	-- Row right under the input: Anonymous toggle pill on the left, character counter on the right.
	local metaRow = Instance.new("Frame")
	metaRow.Position = UDim2.fromOffset(0, 160)
	metaRow.Size = UDim2.new(1, 0, 0, 28)
	metaRow.BackgroundTransparency = 1
	metaRow.Parent = card

	local anonBtn = Instance.new("TextButton")
	anonBtn.Name = "AnonToggle"
	anonBtn.Position = UDim2.fromOffset(0, 0)
	anonBtn.Size = UDim2.fromOffset(154, 28)
	anonBtn.BackgroundColor3 = Color3.fromRGB(36, 31, 56)
	anonBtn.FontFace = FONT_REG
	anonBtn.Text = "Send anonymously"
	anonBtn.TextSize = 13
	anonBtn.TextColor3 = Color3.fromRGB(206, 198, 224)
	anonBtn.AutoButtonColor = false
	corner(anonBtn, 14)
	local anonStroke = borderStroke(anonBtn, Color3.fromRGB(255, 214, 152), 1.2, 0.85)
	anonBtn.Parent = metaRow

	anonBtn.MouseButton1Click:Connect(function()
		isAnonymous = not isAnonymous
		anonBtn.Text = if isAnonymous then "✓ Send anonymously" else "Send anonymously"
		anonBtn.BackgroundColor3 = if isAnonymous
			then Color3.fromRGB(54, 44, 72)
			else Color3.fromRGB(36, 31, 56)
		anonBtn.TextColor3 = if isAnonymous
			then Color3.fromRGB(255, 236, 198)
			else Color3.fromRGB(206, 198, 224)
		anonStroke.Transparency = if isAnonymous then 0.25 else 0.85
	end)

	local counter = Instance.new("TextLabel")
	counter.AnchorPoint = Vector2.new(1, 0.5)
	counter.Position = UDim2.new(1, 0, 0.5, 0)
	counter.Size = UDim2.fromOffset(80, 20)
	counter.BackgroundTransparency = 1
	counter.FontFace = FONT_REG
	counter.Text = `0 / {SkyLantern.MaxLength}`
	counter.TextSize = 13
	counter.TextColor3 = Color3.fromRGB(168, 160, 188)
	counter.TextXAlignment = Enum.TextXAlignment.Right
	counter.Parent = metaRow
	counterLabel = counter

	inputBox:GetPropertyChangedSignal("Text"):Connect(function()
		local len = utf8.len(inputBox.Text) or #inputBox.Text
		if counterLabel then
			counterLabel.Text = `{len} / {SkyLantern.MaxLength}`
			counterLabel.TextColor3 = if len > SkyLantern.MaxLength
				then Color3.fromRGB(255, 134, 134)
				else Color3.fromRGB(168, 160, 188)
		end
	end)

	local status = Instance.new("TextLabel")
	status.Position = UDim2.fromOffset(0, 192)
	status.Size = UDim2.new(1, 0, 0, 18)
	status.BackgroundTransparency = 1
	status.FontFace = FONT_REG
	status.Text = ""
	status.TextSize = 13
	status.TextColor3 = Color3.fromRGB(255, 168, 152)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Parent = card
	statusLabel = status

	-- Action buttons row.
	local cancelBtn = Instance.new("TextButton")
	cancelBtn.AnchorPoint = Vector2.new(0, 1)
	cancelBtn.Position = UDim2.new(0, 0, 1, 0)
	cancelBtn.Size = UDim2.new(0.35, -6, 0, 40)
	cancelBtn.BackgroundColor3 = Color3.fromRGB(46, 40, 68)
	cancelBtn.FontFace = FONT_REG
	cancelBtn.Text = "Cancel"
	cancelBtn.TextSize = 15
	cancelBtn.TextColor3 = Color3.fromRGB(220, 214, 236)
	corner(cancelBtn, 12)
	cancelBtn.Parent = card

	cancelBtn.MouseButton1Click:Connect(function()
		setModalOpen(false)
	end)

	local releaseBtn = Instance.new("TextButton")
	releaseBtn.AnchorPoint = Vector2.new(1, 1)
	releaseBtn.Position = UDim2.new(1, 0, 1, 0)
	releaseBtn.Size = UDim2.new(0.65, -6, 0, 40)
	releaseBtn.BackgroundColor3 = Color3.fromRGB(246, 196, 118)
	releaseBtn.FontFace = FONT_BOLD
	releaseBtn.Text = "Light & Release"
	releaseBtn.TextSize = 16
	releaseBtn.TextColor3 = Color3.fromRGB(36, 24, 14)
	corner(releaseBtn, 12)
	releaseBtn.Parent = card
	sendButton = releaseBtn

	releaseBtn.MouseButton1Click:Connect(function()
		if isSending or not remoteEvent or not wishInput then
			return
		end
		local text = wishInput.Text
		if string.gsub(text, "%s+", "") == "" then
			if statusLabel then
				statusLabel.Text = "Write a short wish or message first."
			end
			return
		end
		isSending = true
		releaseBtn.Text = "Lighting…"
		if statusLabel then
			statusLabel.Text = ""
		end
		-- Always use a subtle warm-light lantern shade that blends naturally with the night sky.
		remoteEvent:FireServer("Release", text, 1, isAnonymous)
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if
			not gameProcessed
			and input.KeyCode == Enum.KeyCode.Escape
			and modalBackdrop
			and modalBackdrop.Visible
		then
			setModalOpen(false)
		end
	end)
end

local function destroyLantern(index: number)
	local entry = table.remove(activeLanterns, index)
	if entry then
		entry.model:Destroy()
	end
end

local function spawnLanternVisual(payload: SkyLantern.SpawnPayload)
	while #activeLanterns >= SkyLantern.MaxActive do
		destroyLantern(1)
	end

	-- Soft warm-ivory / candlelit-gold tone so lanterns look natural and never clash with the sky.
	local palette = SkyLantern.Colors[rng:NextInteger(1, #SkyLantern.Colors)]
	local model = Instance.new("Model")
	model.Name = "SkyLantern"
	model.Parent = getContainer()

	local origin = payload.origin

	-- Translucent warm paper lantern body.
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Cylinder
	body.Size = Vector3.new(2.2, 1.85, 1.85)
	body.Material = Enum.Material.Neon
	body.Color = palette.Paper
	body.Transparency = 0.85
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.CastShadow = false
	body.Parent = model

	-- Soft rounded top cap for classic paper-lantern silhouette.
	local cap = Instance.new("Part")
	cap.Name = "Cap"
	cap.Shape = Enum.PartType.Ball
	cap.Size = Vector3.new(1.85, 0.9, 1.85)
	cap.Material = Enum.Material.Neon
	cap.Color = palette.Paper
	cap.Transparency = 0.85
	cap.Anchored = true
	cap.CanCollide = false
	cap.CanQuery = false
	cap.CanTouch = false
	cap.CastShadow = false
	cap.Parent = model

	-- Dark bamboo ring at the base.
	local rim = Instance.new("Part")
	rim.Name = "Rim"
	rim.Shape = Enum.PartType.Cylinder
	rim.Size = Vector3.new(0.16, 1.78, 1.78)
	rim.Material = Enum.Material.Wood
	rim.Color = Color3.fromRGB(82, 54, 34)
	rim.Transparency = 0.4
	rim.Anchored = true
	rim.CanCollide = false
	rim.CanQuery = false
	rim.CanTouch = false
	rim.CastShadow = false
	rim.Parent = model

	-- Inner warm flame core.
	local flame = Instance.new("Part")
	flame.Name = "Flame"
	flame.Shape = Enum.PartType.Ball
	flame.Size = Vector3.new(0.5, 0.7, 0.5)
	flame.Material = Enum.Material.Neon
	flame.Color = Color3.fromRGB(255, 244, 204)
	flame.Transparency = 0.8
	flame.Anchored = true
	flame.CanCollide = false
	flame.CanQuery = false
	flame.CanTouch = false
	flame.CastShadow = false
	flame.Parent = model

	local light = Instance.new("PointLight")
	light.Color = palette.Glow
	light.Brightness = 0
	light.Range = 20
	light.Shadows = false
	light.Parent = flame

	-- Gentle warm rising ember sparkles.
	local embers = Instance.new("ParticleEmitter")
	embers.Color = ColorSequence.new(palette.Ember, palette.Glow)
	embers.LightEmission = 1
	embers.LightInfluence = 0
	embers.Brightness = 1.8
	embers.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.6, 0.08),
		NumberSequenceKeypoint.new(1, 0),
	})
	embers.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	embers.Lifetime = NumberRange.new(0.9, 1.9)
	embers.Rate = 6
	embers.Speed = NumberRange.new(0.6, 1.5)
	embers.EmissionDirection = Enum.NormalId.Top
	embers.SpreadAngle = Vector2.new(28, 28)
	embers.Parent = flame

	-- Floating heartfelt wish text drifting gently above the lantern.
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WishTag"
	billboard.Adornee = body
	billboard.Size = UDim2.fromOffset(260, 74)
	billboard.StudsOffset = Vector3.new(0, 2.35, 0)
	billboard.MaxDistance = 140
	billboard.AlwaysOnTop = false
	billboard.Parent = body

	local wishLabel = Instance.new("TextLabel")
	wishLabel.Size = UDim2.new(1, 0, 0.68, 0)
	wishLabel.BackgroundTransparency = 1
	wishLabel.FontFace = FONT_HAND
	wishLabel.Text = `"{payload.wish}"`
	wishLabel.TextSize = 21
	wishLabel.TextWrapped = true
	wishLabel.TextColor3 = Color3.fromRGB(255, 248, 232)
	wishLabel.TextStrokeColor3 = Color3.fromRGB(28, 18, 34)
	wishLabel.TextStrokeTransparency = 0.25
	wishLabel.TextTransparency = 1
	wishLabel.Parent = billboard

	local authorLabel = Instance.new("TextLabel")
	authorLabel.Position = UDim2.fromScale(0, 0.68)
	authorLabel.Size = UDim2.new(1, 0, 0.32, 0)
	authorLabel.BackgroundTransparency = 1
	authorLabel.FontFace = FONT_REG
	authorLabel.Text = `— {payload.author}`
	authorLabel.TextSize = 13
	authorLabel.TextColor3 = Color3.fromRGB(255, 226, 186)
	authorLabel.TextStrokeColor3 = Color3.fromRGB(28, 18, 34)
	authorLabel.TextStrokeTransparency = 0.35
	authorLabel.TextTransparency = 1
	authorLabel.Parent = billboard

	table.insert(activeLanterns, {
		model = model,
		body = body,
		cap = cap,
		rim = rim,
		flame = flame,
		light = light,
		embers = embers,
		wishLabel = wishLabel,
		authorLabel = authorLabel,
		origin = origin,
		driftForward = rng:NextNumber(4.4, 6.4),
		driftSide = rng:NextNumber(-2.2, 2.2),
		riseSpeed = rng:NextNumber(3.6, 4.9),
		swayPhase = rng:NextNumber(0, math.pi * 2),
		swayAmp = rng:NextNumber(1.0, 2.0),
		elapsed = 0,
		fadeStart = nil,
	})

	if payload.userId == player.UserId then
		showToast("Your wish is drifting into the night sky…")
	end
end

local function updateLanterns(dt: number)
	for i = #activeLanterns, 1, -1 do
		local l = activeLanterns[i]
		l.elapsed += dt
		local t = l.elapsed

		local pos: Vector3
		local tiltX: number
		local tiltZ: number
		local glowFactor: number
		local textAlpha: number

		if t < KINDLE_SECONDS then
			-- Stage 1: Quiet kindling & holding as warm air fills the lantern.
			local k = math.clamp(t / KINDLE_SECONDS, 0, 1)
			local smooth = k * k * (3 - 2 * k)
			local breath = math.sin(t * 2.4) * 0.14
			pos = l.origin + Vector3.new(0, breath + smooth * 0.55, 0)
			tiltX = math.sin(t * 1.4 + l.swayPhase) * math.rad(3)
			tiltZ = math.cos(t * 1.2 + l.swayPhase) * math.rad(3)
			glowFactor = smooth
			textAlpha = math.clamp((k - 0.25) / 0.75, 0, 1)
		else
			-- Stage 2 & 3: Graceful lift-off, gentle sway, and drift over the city lights.
			local f = t - KINDLE_SECONDS
			local ramp = math.min(f / 3.8, 1)
			local liftIntegral = f - (2.0 * (1 - (1 - ramp) * (1 - ramp))) * 0.5
			if liftIntegral < 0 then
				liftIntegral = 0
			end

			local height = 0.55 + liftIntegral * l.riseSpeed
			local forward = liftIntegral * l.driftForward
			local side = liftIntegral * l.driftSide + math.sin(f * 0.55 + l.swayPhase) * l.swayAmp

			pos = l.origin + VIEW_FORWARD * forward + VIEW_RIGHT * side + Vector3.new(0, height, 0)

			tiltX = math.sin(f * 0.8 + l.swayPhase) * math.rad(6)
			tiltZ = math.cos(f * 0.65 + l.swayPhase) * math.rad(5)

			-- Start dissolving once the lantern floats too far away OR reaches FLOAT_SECONDS.
			local distFromOrigin = (pos - l.origin).Magnitude
			if
				not l.fadeStart and (distFromOrigin >= MAX_FLIGHT_DISTANCE or f >= FLOAT_SECONDS)
			then
				l.fadeStart = t
				l.embers.Enabled = false
			end

			if l.fadeStart then
				local fadeProgress = math.clamp((t - l.fadeStart) / FADE_SECONDS, 0, 1)
				if fadeProgress >= 1 then
					destroyLantern(i)
					continue
				end
				glowFactor = 1 - fadeProgress
				textAlpha = 0
			else
				glowFactor = 1
				textAlpha = 1 - math.clamp((f - 10) / 4.5, 0, 1)
			end
		end

		local flicker = 0.92 + 0.08 * math.sin(t * 9.5 + l.swayPhase)
		local cf = CFrame.new(pos) * CFrame.Angles(tiltX, 0, tiltZ)

		l.body.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
		l.cap.CFrame = cf * CFrame.new(0, 1.05, 0)
		l.rim.CFrame = cf * CFrame.new(0, -1.12, 0) * CFrame.Angles(0, 0, math.rad(90))
		l.flame.CFrame = cf * CFrame.new(0, -0.55, 0)

		l.body.Transparency = 1 - glowFactor * 0.86
		l.cap.Transparency = 1 - glowFactor * 0.84
		l.rim.Transparency = 1 - glowFactor * 0.95
		l.flame.Transparency = 1 - glowFactor * 0.95
		l.light.Brightness = 2.0 * glowFactor * flicker

		l.wishLabel.TextTransparency = 1 - textAlpha
		l.wishLabel.TextStrokeTransparency = 0.25 + (1 - textAlpha) * 0.75
		l.authorLabel.TextTransparency = 1 - textAlpha
		l.authorLabel.TextStrokeTransparency = 0.35 + (1 - textAlpha) * 0.65
	end
end

function SkyLanternController.start()
	buildUi()
	local remote = Remotes.skyLantern()
	remoteEvent = remote

	remote.OnClientEvent:Connect(function(kind: unknown, arg1: unknown)
		if kind == "Open" then
			setModalOpen(true)
		elseif kind == "Released" then
			setModalOpen(false)
		elseif kind == "Error" and typeof(arg1) == "string" then
			isSending = false
			if sendButton then
				sendButton.Text = "Light & Release"
			end
			if statusLabel then
				statusLabel.Text = arg1
			end
		elseif kind == "Spawn" and typeof(arg1) == "table" then
			spawnLanternVisual(arg1 :: SkyLantern.SpawnPayload)
		end
	end)

	RunService.RenderStepped:Connect(updateLanterns)
end

return SkyLanternController
