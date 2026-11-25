--!strict
-- The Mirror Photobooth as everyone sees it: the touch screen follows the booth's State
-- attribute (set by PhotoboothService), and the RGB LED frame, ring light and screen glow
-- animate slowly. Runs on every client, only for booths that are streamed in and nearby.
--
-- The Idle screen ("Touch Here to Start") is built in Studio inside
-- TouchDisplay.Display.Screen.Idle; the other states are added here.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Photobooth = require(ReplicatedStorage.Shared.photobooth.Photobooth)
local QrCode = require(ReplicatedStorage.Shared.core.QrCode)

local FONT = Font.fromEnum(Enum.Font.BuilderSansBold)
local FONT_REGULAR = Font.fromEnum(Enum.Font.BuilderSans)
local COLORS = Photobooth.Colors
-- Lights only animate this close to the camera, at this many updates a second.
local ANIMATE_DISTANCE = 160
local ANIMATE_RATE = 1 / 15
-- One full trip around the color wheel, seconds.
local HUE_PERIOD = 14

type Display = {
	model: Model,
	gui: SurfaceGui,
	idle: GuiObject,
	message: TextLabel,
	sub: TextLabel,
	count: TextLabel,
	countScale: UIScale,
	flash: Frame,
	-- The photo's QR (State "Qr"): white card, the code inside, the hint under it.
	qrCard: Frame,
	qrCode: Frame,
	qrHint: TextLabel,
	qrShown: number?,
	leds: { BasePart },
	ring: { PointLight },
	countdownId: number,
}

local PhotoboothDisplay = {}

local displays: { [Model]: Display } = {}

local function label(parent: Instance, name: string, font: Font): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.FontFace = font
	l.TextColor3 = COLORS.Text
	l.TextScaled = true
	l.TextWrapped = true
	l.Text = ""
	l.Visible = false
	l.Parent = parent
	return l
end

local function runCountdown(d: Display)
	d.countdownId += 1
	local id = d.countdownId
	local endsAt = d.model:GetAttribute("CountdownEnd")
	if typeof(endsAt) ~= "number" then
		return
	end
	local reduced = GuiService.ReducedMotionEnabled
	task.spawn(function()
		local last = -1
		while d.countdownId == id do
			local left = endsAt - Workspace:GetServerTimeNow()
			if left <= 0 then
				break
			end
			local n = math.ceil(left)
			if n ~= last then
				last = n
				d.count.Text = tostring(n)
				d.count.Visible = true
				d.countScale.Scale = if reduced then 1 else 1.4
				if not reduced then
					TweenService:Create(
						d.countScale,
						TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
						{ Scale = 1 }
					):Play()
				end
			end
			task.wait()
		end
		if d.countdownId ~= id then
			return
		end
		d.count.Visible = false
		d.flash.BackgroundTransparency = 0
		TweenService:Create(d.flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	end)
end

-- The prompt is hidden while the mirror shows the QR or "Thank You!" (it would cover the QR and
-- take the click), and for the player using the booth.
local function refreshPrompt(d: Display, state: unknown, ownerName: string)
	local prompt = d.model:FindFirstChild("PhotoboothPrompt", true)
	if not prompt or not prompt:IsA("ProximityPrompt") then
		return
	end
	local inSession = state == "Preparing" or state == "Countdown" or state == "Preview"
	local mine = inSession and ownerName == Players.LocalPlayer.DisplayName
	prompt.Enabled = not (state == "Qr" or state == "Thanks" or mine)
end

local function refresh(d: Display)
	local state = d.model:GetAttribute("State")
	local owner = d.model:GetAttribute("OwnerName")
	local ownerName = if typeof(owner) == "string" then owner else ""
	refreshPrompt(d, state, ownerName)

	d.idle.Visible = state == "Idle" or state == nil
	d.message.Visible = false
	d.sub.Visible = false
	d.sub.Position = UDim2.fromScale(0.5, 0.53)
	d.count.Visible = false
	d.qrCard.Visible = false
	d.qrHint.Visible = false
	if state ~= "Countdown" then
		d.countdownId += 1
	end

	local function say(text: string, sub: string?)
		d.message.Text = text
		d.message.Visible = true
		if sub and sub ~= "" then
			d.sub.Text = sub
			d.sub.Visible = true
		end
	end

	if state == "Preparing" then
		say(Photobooth.Screen.Preparing, ownerName)
	elseif state == "Countdown" then
		runCountdown(d)
	elseif state == "Preview" then
		say(Photobooth.Screen.Preview, `{Photobooth.Screen.InUse:gsub("\n", " ")}`)
	elseif state == "Qr" then
		local id = d.model:GetAttribute("PhotoId")
		if typeof(id) == "number" and d.qrShown ~= id then
			d.qrShown = id
			d.qrCode:ClearAllChildren()
			QrCode.render(d.qrCode, QrCode.pattern(id, Photobooth.QrSize), COLORS.Ink)
		end
		d.qrCard.Visible = true
		d.qrHint.Visible = true
		if ownerName ~= "" then
			d.sub.Text = ownerName
			d.sub.Position = UDim2.fromScale(0.5, 0.17)
			d.sub.Visible = true
		end
	elseif state == "Thanks" then
		say(Photobooth.Screen.Thanks, if ownerName ~= "" then ownerName else nil)
	end
end

local function setup(instance: Instance)
	if not instance:IsA("Model") or displays[instance] then
		return
	end
	local display = instance:FindFirstChild("TouchDisplay")
	local gui = display and display:FindFirstChild("Display")
	local screen = gui and gui:FindFirstChild("Screen")
	local idle = screen and screen:FindFirstChild("Idle")
	if
		not gui
		or not gui:IsA("SurfaceGui")
		or not screen
		or not idle
		or not idle:IsA("GuiObject")
	then
		return
	end

	local message = label(screen, "Message", FONT)
	message.Position = UDim2.fromScale(0.5, 0.4)
	message.Size = UDim2.fromScale(0.8, 0.18)
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Pink
	stroke.Thickness = 3
	stroke.Parent = message

	local sub = label(screen, "Sub", FONT_REGULAR)
	sub.Position = UDim2.fromScale(0.5, 0.53)
	sub.Size = UDim2.fromScale(0.8, 0.06)
	sub.TextColor3 = COLORS.Lilac

	local count = label(screen, "Count", FONT)
	count.Position = UDim2.fromScale(0.5, 0.42)
	count.Size = UDim2.fromScale(0.9, 0.34)
	local countStroke = stroke:Clone()
	countStroke.Thickness = 5
	countStroke.Parent = count
	local countScale = Instance.new("UIScale")
	countScale.Parent = count

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 5
	local flashCorner = screen:FindFirstChildOfClass("UICorner")
	if flashCorner then
		flashCorner:Clone().Parent = flash
	end
	flash.Parent = screen

	-- QR card: square, a bit above the middle (the screen is tall and narrow).
	local qrCard = Instance.new("Frame")
	qrCard.Name = "QrCard"
	qrCard.AnchorPoint = Vector2.new(0.5, 0.5)
	qrCard.Position = UDim2.fromScale(0.5, 0.4)
	qrCard.Size = UDim2.fromScale(0.78, 0.78)
	qrCard.BackgroundColor3 = Color3.new(1, 1, 1)
	qrCard.BorderSizePixel = 0
	qrCard.Visible = false
	qrCard.ZIndex = 3
	local qrRatio = Instance.new("UIAspectRatioConstraint")
	qrRatio.AspectRatio = 1
	qrRatio.DominantAxis = Enum.DominantAxis.Width
	qrRatio.Parent = qrCard
	local qrCorner = Instance.new("UICorner")
	qrCorner.CornerRadius = UDim.new(0.06, 0)
	qrCorner.Parent = qrCard
	local qrStroke = Instance.new("UIStroke")
	qrStroke.Color = COLORS.Pink
	qrStroke.Thickness = 4
	qrStroke.Parent = qrCard
	qrCard.Parent = screen
	local qrCode = Instance.new("Frame")
	qrCode.Name = "Code"
	qrCode.AnchorPoint = Vector2.new(0.5, 0.5)
	qrCode.Position = UDim2.fromScale(0.5, 0.5)
	qrCode.Size = UDim2.fromScale(0.84, 0.84)
	qrCode.BackgroundTransparency = 1
	qrCode.Parent = qrCard

	local qrHint = label(screen, "QrHint", FONT)
	qrHint.Text = Photobooth.Screen.Qr
	qrHint.Position = UDim2.fromScale(0.5, 0.64)
	qrHint.Size = UDim2.fromScale(0.84, 0.12)

	local leds: { BasePart } = {}
	local ring: { PointLight } = {}
	for _, d in instance:GetDescendants() do
		if d:IsA("BasePart") and d:HasTag(Photobooth.LedTag) then
			table.insert(leds, d)
		elseif d:IsA("PointLight") then
			table.insert(ring, d)
		end
	end

	local d: Display = {
		model = instance,
		gui = gui,
		idle = idle,
		message = message,
		sub = sub,
		count = count,
		countScale = countScale,
		flash = flash,
		qrCard = qrCard,
		qrCode = qrCode,
		qrHint = qrHint,
		qrShown = nil,
		leds = leds,
		ring = ring,
		countdownId = 0,
	}
	displays[instance] = d
	instance:GetAttributeChangedSignal("State"):Connect(function()
		refresh(d)
	end)
	instance:GetAttributeChangedSignal("PhotoId"):Connect(function()
		refresh(d)
	end)
	instance:GetAttributeChangedSignal("OwnerName"):Connect(function()
		refresh(d)
	end)
	-- The server adds the prompt; it may arrive after this runs.
	instance.DescendantAdded:Connect(function(added: Instance)
		if added:IsA("ProximityPrompt") then
			refresh(d)
		end
	end)
	instance.Destroying:Connect(function()
		displays[instance] = nil
	end)
	refresh(d)
end

local function removed(instance: Instance)
	if instance:IsA("Model") then
		displays[instance] = nil
	end
end

function PhotoboothDisplay.start()
	for _, instance in CollectionService:GetTagged(Photobooth.Tag) do
		setup(instance)
	end
	CollectionService:GetInstanceAddedSignal(Photobooth.Tag):Connect(setup)
	CollectionService:GetInstanceRemovedSignal(Photobooth.Tag):Connect(removed)

	-- Slow RGB frame, gentle ring light pulse and screen glow, a few times a second.
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < ANIMATE_RATE or next(displays) == nil then
			return
		end
		acc = 0
		local t = Workspace:GetServerTimeNow()
		local cameraPos = Workspace.CurrentCamera.CFrame.Position
		for model, d in displays do
			local pivot = model:GetPivot().Position
			if (pivot - cameraPos).Magnitude <= ANIMATE_DISTANCE then
				local base = (t / HUE_PERIOD) % 1
				for i, part in d.leds do
					part.Color = Color3.fromHSV((base + i * 0.05) % 1, 0.55, 1)
				end
				local pulse = math.sin(t * 1.6)
				for _, light in d.ring do
					local full = if light.Name == "RingGlow" then 0.8 else 0.6
					light.Brightness = full + pulse * 0.2
				end
				d.gui.Brightness = 1.4 + pulse * 0.15
			end
		end
	end)
end

return PhotoboothDisplay
