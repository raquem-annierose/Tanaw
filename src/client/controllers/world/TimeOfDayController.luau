--!strict
-- Changes the sky and lights for this player only (Umaga / Tanghali / Hapon / Gabi).
--
-- Lighting changes made on the client are local, so every player can pick their own time
-- without affecting anyone else. Lights are found by CollectionService tags set in Studio:
--   "WarmLight" - string lights, fairy lights, tent glow
--   "CityLight" - lit windows in the city and houses (hidden by day)

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local TimeOfDay = require(ReplicatedStorage.Shared.world.TimeOfDay)

type Preset = TimeOfDay.Preset

local TRANSITION_SECONDS = 2.5
local WARM_TAG = "WarmLight"
local CITY_TAG = "CityLight"

local TimeOfDayController = {}

local changedEvent = Instance.new("BindableEvent")
TimeOfDayController.Changed = changedEvent.Event

local currentId: string? = nil
local warmOn = false
local cityOn = false
local clockTween: Tween? = nil

local function getColorCorrection(): ColorCorrectionEffect
	local existing = Lighting:FindFirstChild("OverlookColor")
	if existing and existing:IsA("ColorCorrectionEffect") then
		return existing
	end
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "OverlookColor"
	effect.Parent = Lighting
	return effect
end

local function applyWarm(instance: Instance)
	if instance:IsA("BasePart") then
		instance.Material = if warmOn then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
	for _, child in instance:GetChildren() do
		if child:IsA("Light") then
			child.Enabled = warmOn
		end
	end
end

local function applyCity(instance: Instance)
	if instance:IsA("BasePart") then
		instance.Transparency = if cityOn then 0 else 1
	end
end

local function setLights(preset: Preset)
	warmOn = preset.WarmLights
	cityOn = preset.CityLights
	for _, instance in CollectionService:GetTagged(WARM_TAG) do
		applyWarm(instance)
	end
	for _, instance in CollectionService:GetTagged(CITY_TAG) do
		applyCity(instance)
	end
end

local function tween(instance: Instance, info: TweenInfo, goals: { [string]: any })
	TweenService:Create(instance, info, goals):Play()
end

-- Moves the clock forward (wrapping past midnight) so time always moves the natural way.
local function tweenClock(target: number, info: TweenInfo)
	if clockTween then
		clockTween:Cancel()
	end
	local from = Lighting.ClockTime
	local to = if target >= from then target else target + 24
	local value = Instance.new("NumberValue")
	value.Value = from
	value.Changed:Connect(function(v: number)
		Lighting.ClockTime = v % 24
	end)
	local t = TweenService:Create(value, info, { Value = to })
	t.Completed:Connect(function()
		Lighting.ClockTime = target
		value:Destroy()
	end)
	clockTween = t
	t:Play()
end

function TimeOfDayController.getCurrent(): string?
	return currentId
end

function TimeOfDayController.set(id: string, instant: boolean?)
	local preset = TimeOfDay.Presets[id]
	if not preset or id == currentId then
		return
	end
	currentId = id

	-- Players who turn on Reduced Motion in Roblox settings get an instant change.
	local seconds = if instant or GuiService.ReducedMotionEnabled then 0 else TRANSITION_SECONDS
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	if seconds == 0 then
		Lighting.ClockTime = preset.ClockTime
	else
		tweenClock(preset.ClockTime, info)
	end
	tween(Lighting, info, {
		Brightness = preset.Brightness,
		OutdoorAmbient = preset.OutdoorAmbient,
		Ambient = preset.Ambient,
	})

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		local a = preset.Atmosphere
		tween(atmosphere, info, {
			Density = a.Density,
			Offset = a.Offset,
			Color = a.Color,
			Decay = a.Decay,
			Glare = a.Glare,
			Haze = a.Haze,
		})
	end

	tween(getColorCorrection(), info, { TintColor = preset.Tint, Saturation = preset.Saturation })

	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky then
		tween(sky, info, { SunAngularSize = preset.SunSize })
		-- StarCount is a whole number, so it switches instead of tweening.
		if seconds == 0 then
			sky.StarCount = preset.StarCount
		else
			task.delay(seconds / 2, function()
				if currentId == id then
					sky.StarCount = preset.StarCount
				end
			end)
		end
	end

	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		tween(clouds, info, { Color = preset.CloudColor, Cover = preset.CloudCover })
	end

	-- Lights switch halfway through, when the sky is changing the most.
	if seconds == 0 then
		setLights(preset)
	else
		task.delay(seconds / 2, function()
			if currentId == id then
				setLights(preset)
			end
		end)
	end

	changedEvent:Fire(id)
end

function TimeOfDayController.start()
	-- Lights that stream in later (StreamingEnabled) get the current state too.
	CollectionService:GetInstanceAddedSignal(WARM_TAG):Connect(applyWarm)
	CollectionService:GetInstanceAddedSignal(CITY_TAG):Connect(applyCity)
	TimeOfDayController.set(TimeOfDay.Default, true)
end

return TimeOfDayController
