--!strict
-- The Mirror Photobooth on this player's screen (the server, PhotoboothService, decides who is
-- using it). After the prompt: walk to the photo spot and face the mirror, movement off, the
-- camera frames the whole avatar, a pose bar shows emotes, 3-2-1, flash, then a photo preview
-- with RETAKE / DONE. Everything goes back to how it was in one cleanup().
--
-- The "photo" is a frozen copy of the avatar in a ViewportFrame, seen through the same camera
-- as the booth view. Clones keep the pose because a ViewportFrame without a WorldModel doesn't
-- re-solve the joints: every part stays where it was at the flash.

local CaptureService = game:GetService("CaptureService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local EmoteController = require(script.Parent.EmoteController)
local Emotes = require(ReplicatedStorage.Shared.Emotes)
local MovementController = require(script.Parent.MovementController)
local Phone = require(script.Parent.Parent.ui.phone.Phone)
local PhotoAlbum = require(script.Parent.Parent.ui.phone.PhotoAlbum)
local Photobooth = require(ReplicatedStorage.Shared.Photobooth)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local FONT = Font.fromEnum(Enum.Font.BuilderSansBold)
local FONT_REGULAR = Font.fromEnum(Enum.Font.BuilderSans)
local COLORS = Photobooth.Colors
local WHITE = Color3.new(1, 1, 1)
local CAMERA_TWEEN = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TURN_SECONDS = 0.3

type Saved = {
	cameraType: Enum.CameraType,
	cameraSubject: Instance?,
	fov: number,
	walkSpeed: number,
	jumpPower: number,
	jumpHeight: number,
	autoRotate: boolean,
	backpack: boolean,
	-- Other ScreenGuis this hid (time of day menu, admin button...), to show again.
	hiddenGuis: { ScreenGui },
}

type Session = {
	booth: Model,
	character: Model,
	humanoid: Humanoid,
	saved: Saved,
	connections: { RBXScriptConnection },
	-- Booth camera, also used for the photo.
	view: CFrame?,
	fov: number,
	-- Bumped when a countdown starts or the session ends, to stop old countdown loops.
	countdownId: number,
	photo: Model?,
	-- The real screenshot (ScreenshotCapture) and whether the screenshot attempt finished.
	shot: any,
	shotReady: boolean,
}

local PhotoboothController = {}

local player = Players.LocalPlayer
local remote: RemoteEvent? = nil
local session: Session? = nil

-- UI, made in build().
local gui: ScreenGui
local countLabel: TextLabel
local countScale: UIScale
local flash: Frame
local poseBar: Frame
local hint: TextLabel
local preview: Frame
local viewport: ViewportFrame
local shotImage: ImageLabel
local toastLabel: TextLabel

local function send(kind: string, booth: Model)
	if remote then
		remote:FireServer(kind, booth)
	end
end

-- Roblox's touch / keyboard controls, if this place has a PlayerModule (Tanaw's doesn't always;
-- never wait for it, or the booth stalls). WalkSpeed / JumpHeight 0 keep the player still anyway.
local function controls(): any
	local ok, module = pcall(function()
		local scripts = player:FindFirstChild("PlayerScripts")
		local playerModule = scripts and scripts:FindFirstChild("PlayerModule")
		return playerModule and (require(playerModule :: ModuleScript) :: any):GetControls()
	end)
	return if ok then module else nil
end

-- Stops the walk / run animation so the photo isn't mid-step (Roblox's Animate script names
-- its tracks after the Animation instances: WalkAnim, RunAnim).
local function stopWalking(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	for _, track in animator:GetPlayingAnimationTracks() do
		local name = track.Animation and track.Animation.Name
		if name == "WalkAnim" or name == "RunAnim" then
			track:Stop(0.2)
		end
	end
end

local function playSound(id: string)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = 0.6
	SoundService:PlayLocalSound(sound)
	task.delay(3, function()
		sound:Destroy()
	end)
end

local function corner(parent: GuiObject, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function pill(name: string, parent: Instance, text: string, primary: boolean): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = true
	b.Selectable = true
	b.BorderSizePixel = 0
	b.AutomaticSize = Enum.AutomaticSize.X
	b.Size = UDim2.fromOffset(0, 40)
	b.BackgroundColor3 = if primary then COLORS.Pink else COLORS.Panel
	b.BackgroundTransparency = if primary then 0 else 0.15
	b.FontFace = FONT
	b.Text = text
	b.TextSize = 17
	b.TextColor3 = if primary then COLORS.Ink else COLORS.Text
	corner(b, UDim.new(1, 0))
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = b
	b.Parent = parent
	return b
end

local function toast(text: string)
	toastLabel.Text = text
	toastLabel.Visible = true
	toastLabel.TextTransparency = 0
	toastLabel.BackgroundTransparency = 0.15
	local shownText = text
	task.delay(3, function()
		if toastLabel.Text ~= shownText then
			return
		end
		local fade = TweenInfo.new(0.4)
		TweenService:Create(toastLabel, fade, { TextTransparency = 1, BackgroundTransparency = 1 })
			:Play()
		task.wait(0.4)
		if toastLabel.Text == shownText then
			toastLabel.Visible = false
		end
	end)
end

-- DONE: the photo waits in the album until its QR on the mirror is scanned (PhotoboothApp).
local function keepPhoto(s: Session)
	if not s.photo and not s.shot then
		return
	end
	local caption = preview:FindFirstChild("Caption", true)
	local model = s.photo
	if model then
		-- Out of the preview viewport, which cleanup() clears.
		model.Parent = nil
	end
	PhotoAlbum.setPending({
		shot = s.shot,
		model = model,
		view = s.view or Workspace.CurrentCamera.CFrame,
		fov = s.fov,
		caption = if caption and caption:IsA("TextLabel") then caption.Text else "Tanaw",
		id = nil,
	})
	s.photo = nil
	s.shot = nil
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "Photobooth"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 6

	-- Big countdown number in the middle.
	countLabel = Instance.new("TextLabel")
	countLabel.Name = "Count"
	countLabel.BackgroundTransparency = 1
	countLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	countLabel.Position = UDim2.fromScale(0.5, 0.42)
	countLabel.Size = UDim2.fromOffset(420, 180)
	countLabel.FontFace = FONT
	countLabel.TextSize = 150
	countLabel.TextColor3 = WHITE
	countLabel.Text = ""
	countLabel.Visible = false
	local countStroke = Instance.new("UIStroke")
	countStroke.Color = COLORS.Pink
	countStroke.Thickness = 5
	countStroke.Parent = countLabel
	countScale = Instance.new("UIScale")
	countScale.Parent = countLabel
	countLabel.Parent = gui

	flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = WHITE
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 10
	flash.Parent = gui

	local safe = Instance.new("Frame")
	safe.Name = "Safe"
	safe.BackgroundTransparency = 1
	safe.Size = UDim2.fromScale(1, 1)
	safe.Parent = gui
	local safePad = Instance.new("UIPadding")
	safePad.PaddingTop = UDim.new(0, GuiService.TopbarInset.Height + 8)
	safePad.PaddingBottom = UDim.new(0, 16)
	safePad.PaddingLeft = UDim.new(0, 16)
	safePad.PaddingRight = UDim.new(0, 16)
	safePad.Parent = safe

	hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.fromScale(0.5, 0)
	hint.AutomaticSize = Enum.AutomaticSize.X
	hint.Size = UDim2.fromOffset(0, 36)
	hint.BackgroundColor3 = COLORS.Ink
	hint.BackgroundTransparency = 0.25
	hint.FontFace = FONT
	hint.TextSize = 18
	hint.TextColor3 = COLORS.Text
	hint.Text = ""
	hint.Visible = false
	corner(hint, UDim.new(1, 0))
	local hintPad = Instance.new("UIPadding")
	hintPad.PaddingLeft = UDim.new(0, 18)
	hintPad.PaddingRight = UDim.new(0, 18)
	hintPad.Parent = hint
	hint.Parent = safe

	toastLabel = hint:Clone()
	toastLabel.Name = "Toast"
	toastLabel.Position = UDim2.new(0.5, 0, 0, 44)
	toastLabel.Parent = safe

	-- Pose bar: emotes + leave, at the bottom.
	poseBar = Instance.new("Frame")
	poseBar.Name = "PoseBar"
	poseBar.AnchorPoint = Vector2.new(0.5, 1)
	poseBar.Position = UDim2.fromScale(0.5, 1)
	poseBar.Size = UDim2.new(1, 0, 0, 96)
	poseBar.BackgroundTransparency = 1
	poseBar.Visible = false
	poseBar.Parent = safe
	local poseLayout = Instance.new("UIListLayout")
	poseLayout.FillDirection = Enum.FillDirection.Horizontal
	poseLayout.Wraps = true
	poseLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	poseLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	poseLayout.Padding = UDim.new(0, 8)
	poseLayout.SortOrder = Enum.SortOrder.LayoutOrder
	poseLayout.Parent = poseBar
	for i, emote in Emotes.List do
		local b = pill(emote.Id, poseBar, emote.Label, false)
		b.LayoutOrder = i
		b.Activated:Connect(function()
			EmoteController.play(emote.Id)
		end)
	end
	local leave = pill("Leave", poseBar, "Leave", false)
	leave.LayoutOrder = 100
	leave.BackgroundColor3 = COLORS.Ink
	leave.Activated:Connect(function()
		local s = session
		if s then
			send("Leave", s.booth)
			PhotoboothController.cleanup()
		end
	end)

	-- Preview: the photo as a card + RETAKE / DONE.
	preview = Instance.new("Frame")
	preview.Name = "Preview"
	preview.AnchorPoint = Vector2.new(0.5, 0.5)
	preview.Position = UDim2.fromScale(0.5, 0.5)
	preview.Size = UDim2.fromScale(0.8, 0.82)
	preview.BackgroundTransparency = 1
	preview.Visible = false
	preview.Parent = safe
	local previewLayout = Instance.new("UIListLayout")
	previewLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	previewLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	previewLayout.Padding = UDim.new(0, 12)
	previewLayout.SortOrder = Enum.SortOrder.LayoutOrder
	previewLayout.Parent = preview

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.LayoutOrder = 1
	card.Size = UDim2.new(1, 0, 1, -60)
	card.BackgroundColor3 = Color3.fromRGB(255, 246, 252)
	card.BorderSizePixel = 0
	corner(card, UDim.new(0, 14))
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 0.78
	ratio.Parent = card
	card.Parent = preview

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Position = UDim2.fromOffset(10, 10)
	backdrop.Size = UDim2.new(1, -20, 1, -54)
	backdrop.BackgroundColor3 = WHITE
	backdrop.BorderSizePixel = 0
	corner(backdrop, UDim.new(0, 8))
	local backGradient = Instance.new("UIGradient")
	backGradient.Rotation = 90
	backGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 74, 110)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(150, 130, 150)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(196, 170, 160)),
	})
	backGradient.Parent = backdrop
	backdrop.Parent = card

	viewport = Instance.new("ViewportFrame")
	viewport.Name = "Photo"
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(200, 186, 214)
	viewport.LightColor = Color3.fromRGB(255, 240, 248)
	viewport.Parent = backdrop

	-- The real screenshot, cropped to the card.
	shotImage = Instance.new("ImageLabel")
	shotImage.Name = "Shot"
	shotImage.Size = UDim2.fromScale(1, 1)
	shotImage.BackgroundTransparency = 1
	shotImage.ScaleType = Enum.ScaleType.Crop
	shotImage.Visible = false
	corner(shotImage, UDim.new(0, 8))
	shotImage.Parent = backdrop

	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.AnchorPoint = Vector2.new(0, 1)
	caption.Position = UDim2.new(0, 10, 1, -8)
	caption.Size = UDim2.new(1, -20, 0, 30)
	caption.BackgroundTransparency = 1
	caption.FontFace = FONT_REGULAR
	caption.TextSize = 18
	caption.TextColor3 = Color3.fromRGB(110, 60, 120)
	caption.Text = "Tanaw"
	caption.Parent = card

	local buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.LayoutOrder = 2
	buttons.Size = UDim2.new(1, 0, 0, 44)
	buttons.BackgroundTransparency = 1
	buttons.Parent = preview
	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.FillDirection = Enum.FillDirection.Horizontal
	buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buttonLayout.Padding = UDim.new(0, 12)
	buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
	buttonLayout.Parent = buttons
	local retake = pill("Retake", buttons, "RETAKE", false)
	retake.LayoutOrder = 1
	local done = pill("Done", buttons, "DONE", true)
	done.LayoutOrder = 2

	retake.Activated:Connect(function()
		local s = session
		if not s or not preview.Visible then
			return
		end
		preview.Visible = false
		if s.photo then
			s.photo:Destroy()
			s.photo = nil
		end
		hint.Text = "Get ready! Strike a pose"
		hint.Visible = true
		poseBar.Visible = true
		send("Retake", s.booth)
	end)
	done.Activated:Connect(function()
		local s = session
		if not s or not preview.Visible then
			return
		end
		keepPhoto(s)
		send("Done", s.booth)
		PhotoboothController.cleanup()
		toast("Click the QR code on the mirror to get your photo")
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function PhotoboothController.cleanup()
	local s = session
	if not s then
		return
	end
	session = nil
	s.countdownId += 1
	for _, connection in s.connections do
		connection:Disconnect()
	end
	if s.photo then
		s.photo:Destroy()
	end
	viewport:ClearAllChildren()

	countLabel.Visible = false
	flash.BackgroundTransparency = 1
	poseBar.Visible = false
	preview.Visible = false
	hint.Visible = false

	local camera = Workspace.CurrentCamera
	camera.CameraType = s.saved.cameraType
	camera.FieldOfView = s.saved.fov
	if s.humanoid.Parent then
		camera.CameraSubject = s.humanoid
	elseif s.saved.cameraSubject then
		camera.CameraSubject = s.saved.cameraSubject
	end

	local humanoid = s.humanoid
	humanoid.WalkSpeed = s.saved.walkSpeed
	humanoid.JumpPower = s.saved.jumpPower
	humanoid.JumpHeight = s.saved.jumpHeight
	humanoid.AutoRotate = s.saved.autoRotate
	MovementController.setPaused(false)
	local c = controls()
	if c then
		c:Enable()
	end

	for _, other in s.saved.hiddenGuis do
		other.Enabled = true
	end
	if s.saved.backpack then
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
	end
	Phone.setHidden(false)
	-- (The booth's prompt is shown / hidden by PhotoboothDisplay from the booth's state.)
end

-- Booth camera at the CameraSpot (high on the mirror, like a real booth's lens), aimed so the
-- avatar from head to feet sits in the middle with some room around it.
local function frame(s: Session)
	local spot = s.booth:FindFirstChild("CameraSpot")
	if not spot or not spot:IsA("BasePart") then
		return
	end
	local eye = spot.Position
	local boxCf, size = s.character:GetBoundingBox()
	local top = boxCf.Position + Vector3.new(0, size.Y / 2, 0)
	local bottom = boxCf.Position - Vector3.new(0, size.Y / 2, 0)
	local toTop = (top - eye).Unit
	local toBottom = (bottom - eye).Unit
	local span = math.deg(math.acos(math.clamp(toTop:Dot(toBottom), -1, 1)))
	local fov = math.clamp(
		span * Photobooth.FrameMargin,
		Photobooth.MinFieldOfView,
		Photobooth.MaxFieldOfView
	)
	s.view = CFrame.lookAt(eye, eye + (toTop + toBottom).Unit)
	s.fov = fov

	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(camera, CAMERA_TWEEN, { CFrame = s.view, FieldOfView = fov }):Play()
end

-- Walks to the photo spot (snaps there if it takes too long), then turns to the mirror.
local function goToSpot(s: Session): boolean
	local spot = s.booth:FindFirstChild("PhotoSpot")
	local root = s.character:FindFirstChild("HumanoidRootPart")
	if not spot or not spot:IsA("BasePart") or not root or not root:IsA("BasePart") then
		return false
	end
	local target = Vector3.new(spot.Position.X, root.Position.Y, spot.Position.Z)
	local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
	if (flat - Vector3.new(target.X, 0, target.Z)).Magnitude > 0.6 then
		local arrived = false
		local done = s.humanoid.MoveToFinished:Once(function()
			arrived = true
		end)
		s.humanoid:MoveTo(target)
		local started = os.clock()
		while not arrived and os.clock() - started < Photobooth.WalkTimeout do
			task.wait()
			if session ~= s then
				done:Disconnect()
				return false
			end
		end
		done:Disconnect()
		if not arrived then
			s.character:PivotTo(CFrame.new(target) * root.CFrame.Rotation)
		end
	end
	if session ~= s then
		return false
	end

	-- Stop and turn smoothly to face the mirror.
	s.humanoid:Move(Vector3.zero)
	s.humanoid.WalkSpeed = 0
	s.humanoid.JumpPower = 0
	s.humanoid.JumpHeight = 0
	s.humanoid.AutoRotate = false
	stopWalking(s.humanoid)
	local look = Vector3.new(spot.CFrame.LookVector.X, 0, spot.CFrame.LookVector.Z).Unit
	local from = root.CFrame
	local goal = CFrame.lookAt(root.Position, root.Position + look)
	local t = 0
	while t < TURN_SECONDS do
		t += task.wait()
		if session ~= s or not root.Parent then
			return false
		end
		local alpha = TweenService:GetValue(
			math.min(t / TURN_SECONDS, 1),
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		)
		root.CFrame = from:Lerp(goal, alpha)
	end
	root.CFrame = goal
	root.AssemblyLinearVelocity = Vector3.zero
	return true
end

local function begin(booth: Model)
	if session then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end
	local camera = Workspace.CurrentCamera
	local s: Session = {
		booth = booth,
		character = character,
		humanoid = humanoid,
		saved = {
			cameraType = camera.CameraType,
			cameraSubject = camera.CameraSubject,
			fov = camera.FieldOfView,
			walkSpeed = humanoid.WalkSpeed,
			jumpPower = humanoid.JumpPower,
			jumpHeight = humanoid.JumpHeight,
			autoRotate = humanoid.AutoRotate,
			backpack = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack),
			hiddenGuis = {},
		},
		connections = {},
		view = nil,
		fov = 70,
		countdownId = 0,
		photo = nil,
		shot = nil,
		shotReady = false,
	}
	session = s

	local function stop()
		if session == s then
			PhotoboothController.cleanup()
		end
	end
	table.insert(s.connections, humanoid.Died:Connect(stop))
	table.insert(
		s.connections,
		character.AncestryChanged:Connect(function()
			if not character.Parent then
				stop()
			end
		end)
	)

	Phone.setHidden(true)
	-- A clean view: hide the game's other screens (the photobooth's own UI stays).
	for _, other in player:WaitForChild("PlayerGui"):GetChildren() do
		if other:IsA("ScreenGui") and other ~= gui and other.Enabled then
			other.Enabled = false
			table.insert(s.saved.hiddenGuis, other)
		end
	end
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	local c = controls()
	if c then
		c:Disable()
	end
	MovementController.setPaused(true)
	EmoteController.stop()

	hint.Text = "Get ready! Strike a pose"
	hint.Visible = true

	task.spawn(function()
		if not goToSpot(s) then
			return
		end
		frame(s)
		poseBar.Visible = true
		send("Ready", booth)
	end)
end

-- The photo: a real screenshot of the booth camera's view (no UI), shown with
-- Content.fromObject. If Roblox can't take one (e.g. captures are off), a frozen copy of the
-- avatar in a ViewportFrame is used instead.
local function capture(s: Session)
	s.shot = nil
	s.shotReady = false
	local ok = pcall(function()
		CaptureService:TakeScreenshotCaptureAsync(function(result, shot)
			if session ~= s then
				return
			end
			if result == Enum.ScreenshotCaptureResult.Success and shot then
				s.shot = shot
			end
			s.shotReady = true
		end, { UICaptureMode = Enum.UICaptureMode.None })
	end)
	if not ok then
		s.shotReady = true
	end

	local character = s.character
	local wasArchivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = wasArchivable
	for _, d in clone:GetDescendants() do
		if
			d:IsA("LuaSourceContainer")
			or d:IsA("Sound")
			or d:IsA("BillboardGui")
			or d:IsA("ProximityPrompt")
			or d:IsA("ForceField")
		then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("Humanoid") then
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
	clone.Name = "Photo"

	viewport:ClearAllChildren()
	local cam = Instance.new("Camera")
	cam.CFrame = s.view or Workspace.CurrentCamera.CFrame
	cam.FieldOfView = s.fov
	cam.Parent = viewport
	viewport.CurrentCamera = cam
	viewport.LightDirection = (cam.CFrame.LookVector + Vector3.new(0, -0.6, 0)).Unit
	clone.Parent = viewport
	s.photo = clone

	local caption = preview:FindFirstChild("Caption", true)
	if caption and caption:IsA("TextLabel") then
		caption.Text = `Tanaw  •  {DateTime.now():FormatLocalTime("ll", "en-us")}`
	end
end

local function countdown(s: Session, endsAt: number)
	s.countdownId += 1
	local id = s.countdownId
	hint.Text = "Smile!"
	hint.Visible = true
	poseBar.Visible = true
	preview.Visible = false
	local reduced = GuiService.ReducedMotionEnabled

	local function show(text: string, size: number)
		countLabel.Text = text
		countLabel.TextSize = size
		countLabel.Visible = true
		countLabel.TextTransparency = 0
		countScale.Scale = if reduced then 1 else 1.5
		if not reduced then
			TweenService:Create(
				countScale,
				TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
		end
		TweenService:Create(
			countLabel,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.55),
			{ TextTransparency = 1 }
		):Play()
	end

	task.spawn(function()
		local last = -1
		while true do
			if session ~= s or s.countdownId ~= id then
				return
			end
			local left = endsAt - Workspace:GetServerTimeNow()
			if left <= 0 then
				break
			end
			local n = math.ceil(left)
			if n ~= last then
				last = n
				show(tostring(n), 150)
				playSound(Photobooth.Sounds.Tick)
			end
			task.wait()
		end

		-- Capture: freeze the avatar first (the flash covers the screen right after).
		capture(s)
		show("CAPTURE!", 90)
		playSound(Photobooth.Sounds.Shutter)
		flash.BackgroundTransparency = 0
		TweenService:Create(flash, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
		poseBar.Visible = false
		hint.Visible = false
		send("Captured", s.booth)
	end)
end

local function showPreview(s: Session)
	-- Wait a moment for the screenshot.
	local started = os.clock()
	while not s.shotReady and os.clock() - started < 2 do
		task.wait()
	end
	if session ~= s then
		return
	end
	if s.shot then
		shotImage.ImageContent = Content.fromObject(s.shot)
		shotImage.Visible = true
		viewport.Visible = false
	elseif s.photo then
		shotImage.Visible = false
		viewport.Visible = true
	else
		return
	end
	countLabel.Visible = false
	EmoteController.stop()
	preview.Visible = true
	local scale = preview:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = preview
	if GuiService.ReducedMotionEnabled then
		scale.Scale = 1
	else
		scale.Scale = 0.85
		TweenService:Create(
			scale,
			TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	end
end

local function onMessage(kind: string, a: any, b: any)
	if kind == "Error" then
		if typeof(a) == "string" then
			toast(a)
		end
		return
	end
	if typeof(a) ~= "Instance" or not a:IsA("Model") then
		return
	end
	local booth = a
	if kind == "Start" then
		begin(booth)
		return
	end
	local s = session
	if not s or s.booth ~= booth then
		return
	end
	if kind == "Countdown" and typeof(b) == "number" then
		countdown(s, b)
	elseif kind == "Preview" then
		showPreview(s)
	elseif kind == "End" then
		if b == "Done" then
			-- The preview timed out (counts as Done).
			keepPhoto(s)
		end
		PhotoboothController.cleanup()
		if b == "Timeout" then
			toast(Photobooth.Messages.Timeout)
		end
	end
end

function PhotoboothController.start()
	build()
	-- Waits for the server's remote, so don't hold up the other controllers.
	task.spawn(function()
		local r = Remotes.photobooth()
		remote = r
		r.OnClientEvent:Connect(onMessage)
	end)
end

return PhotoboothController
