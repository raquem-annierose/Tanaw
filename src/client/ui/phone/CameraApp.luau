--!strict
-- Camera app. Opening it hides the phone and shows camera controls at the bottom of the screen:
--   [X close]  [shutter]  [flip]
-- Selfie mode puts the selfie stick in the player's hand (server SelfieStickService) and the
-- selfie view takes over the camera (SelfieController). Camera mode is the normal camera.
-- The shutter takes a screenshot without any UI and asks to save it to Roblox's Captures.

local CaptureService = game:GetService("CaptureService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local PhoneUi = require(script.Parent.PhoneUi)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

type Mode = "Selfie" | "Camera"

local CameraApp = {}

local player = Players.LocalPlayer
local gui: ScreenGui? = nil
local modeLabel: TextLabel? = nil
local flash: Frame? = nil
local mode: Mode = "Selfie"
local isOpen = false
local onExit: (() -> ())? = nil
local remote: RemoteEvent? = nil
local hotbarWasOn = true

local function setSelfie(on: boolean)
	if remote then
		remote:FireServer("Selfie", on)
	end
end

local function setMode(new: Mode)
	mode = new
	setSelfie(new == "Selfie")
	if modeLabel then
		modeLabel.Text = if new == "Selfie" then "SELFIE" else "CAMERA"
	end
end

local function shoot()
	local f = flash
	if f then
		f.BackgroundTransparency = 0.2
		TweenService:Create(f, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	end
	local ok, err = pcall(function()
		CaptureService:TakeScreenshotCaptureAsync(function(result, capture)
			if result == Enum.ScreenshotCaptureResult.Success and capture then
				CaptureService:PromptSaveCapturesToGallery({ capture }, function() end)
			end
		end, { UICaptureMode = Enum.UICaptureMode.None })
	end)
	if not ok then
		warn(`[Phone] Screenshot failed: {err}`)
	end
end

-- Roblox's hotbar shows any tool in the hand, so it would show "Selfie Stick" right behind
-- the shutter. Hide it while the camera is open and put it back as it was afterwards.
local function setHotbarHidden(hidden: boolean)
	if hidden then
		hotbarWasOn = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	elseif hotbarWasOn then
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
	end
end

function CameraApp.open()
	if isOpen or not gui then
		return
	end
	isOpen = true
	gui.Enabled = true
	setHotbarHidden(true)
	setMode("Selfie")
end

function CameraApp.close()
	if not isOpen then
		return
	end
	isOpen = false
	if gui then
		gui.Enabled = false
	end
	setHotbarHidden(false)
	if mode == "Selfie" then
		setSelfie(false)
	end
	if onExit then
		onExit()
	end
end

function CameraApp.isOpen(): boolean
	return isOpen
end

local function roundButton(name: string, parent: Instance, text: string, size: number): TextButton
	local b = PhoneUi.button(name, parent)
	b.Size = UDim2.fromOffset(size, size)
	b.BackgroundColor3 = PhoneUi.INK
	b.BackgroundTransparency = 0.35
	b.Text = text
	b.TextSize = math.floor(size * 0.42)
	PhoneUi.corner(b)
	return b
end

-- exitCallback runs when the player closes the camera (the phone opens again).
function CameraApp.start(exitCallback: () -> ())
	onExit = exitCallback
	task.spawn(function()
		remote = Remotes.phone()
	end)

	local screen = Instance.new("ScreenGui")
	screen.Name = "PhoneCamera"
	screen.ResetOnSpawn = false
	screen.Enabled = false
	screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.DisplayOrder = 5

	local white = PhoneUi.frame("Flash", screen)
	white.Size = UDim2.fromScale(1, 1)
	white.BackgroundColor3 = PhoneUi.WHITE
	white.BackgroundTransparency = 1
	white.Active = false
	flash = white

	local bar = PhoneUi.frame("Controls", screen)
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -16)
	bar.Size = UDim2.fromOffset(260, 120)

	local pill = PhoneUi.label("Mode", bar, "SELFIE", 14)
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.fromScale(0.5, 0)
	pill.Size = UDim2.fromOffset(96, 26)
	pill.BackgroundColor3 = PhoneUi.INK
	pill.BackgroundTransparency = 0.35
	pill.TextColor3 = PhoneUi.ACCENT
	PhoneUi.corner(pill)
	modeLabel = pill

	-- The ✕ glyph isn't in Roblox's font (it shows as a box), so draw the X with two bars.
	local close = roundButton("Close", bar, "", 52)
	close.AnchorPoint = Vector2.new(0, 1)
	close.Position = UDim2.new(0, 0, 1, -10)
	for _, angle in { 45, -45 } do
		local stroke = PhoneUi.frame("X", close)
		stroke.AnchorPoint = Vector2.new(0.5, 0.5)
		stroke.Position = UDim2.fromScale(0.5, 0.5)
		stroke.Size = UDim2.fromOffset(22, 3)
		stroke.Rotation = angle
		stroke.BackgroundTransparency = 0
		stroke.BackgroundColor3 = PhoneUi.WHITE
		PhoneUi.corner(stroke)
	end
	close.Activated:Connect(CameraApp.close)

	-- Shutter: white disc inside a white ring.
	local shutter = PhoneUi.button("Shutter", bar)
	shutter.AnchorPoint = Vector2.new(0.5, 1)
	shutter.Position = UDim2.fromScale(0.5, 1)
	shutter.Size = UDim2.fromOffset(78, 78)
	shutter.BackgroundTransparency = 1
	PhoneUi.corner(shutter)
	local ring = Instance.new("UIStroke")
	ring.Color = PhoneUi.WHITE
	ring.Thickness = 4
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = shutter
	local disc = PhoneUi.frame("Disc", shutter)
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.Size = UDim2.fromOffset(62, 62)
	disc.BackgroundTransparency = 0
	disc.BackgroundColor3 = PhoneUi.WHITE
	PhoneUi.corner(disc)
	shutter.Activated:Connect(shoot)

	local flip = roundButton("Flip", bar, "🔄", 52)
	flip.AnchorPoint = Vector2.new(1, 1)
	flip.Position = UDim2.new(1, 0, 1, -10)
	flip.Activated:Connect(function()
		setMode(if mode == "Selfie" then "Camera" else "Selfie")
	end)

	-- If the stick goes away on its own (respawn, equipping another tool), fall back to the
	-- normal camera instead of leaving the app in a broken selfie mode.
	local function watchCharacter(character: Model)
		character.ChildRemoved:Connect(function(child: Instance)
			if isOpen and mode == "Selfie" and child.Name == Config.SelfieStick.ToolName then
				mode = "Camera"
				pill.Text = "CAMERA"
			end
		end)
	end
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(function(character: Model)
		watchCharacter(character)
		if isOpen then
			mode = "Camera"
			pill.Text = "CAMERA"
		end
	end)

	screen.Parent = player:WaitForChild("PlayerGui")
	gui = screen
end

return CameraApp
