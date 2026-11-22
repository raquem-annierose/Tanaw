--!strict
-- Concert searchlights at the SkyTerrace stage: models tagged "Searchlight" sweep their beams
-- across the sky and slowly cycle through colors so players notice them from afar.
--
-- Each model has a "Moving" model (Head, Rim, Lens) that turns around the Head's position.
-- Motion runs on each client (smooth, no network traffic) and is driven by server time so
-- every player sees the beams in the same place. Beams only show when the warm lights are
-- on (Hapon / Gabi), like the string lights.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TimeOfDay = require(ReplicatedStorage.Shared.TimeOfDay)
local TimeOfDayController = require(script.Parent.TimeOfDayController)

local TAG = "Searchlight"
local SWEEP_DEG = 55 -- left/right swing from the centre direction
local TILT_MIN, TILT_MAX = 50, 80 -- degrees above the horizon
local SWEEP_SPEED = 0.32
local TILT_SPEED = 0.21
local HUE_SPEED = 0.035
local TILT_PERIOD_OFFSET = 1.7

type Searchlight = {
	pivot: Vector3,
	baseYaw: number,
	phase: number,
	parts: { [BasePart]: CFrame }, -- offset from the head frame
	beams: { Beam },
	lights: { Light },
	lens: BasePart?,
}

local SearchlightController = {}

local lights: { [Model]: Searchlight } = {}

local function warmOn(): boolean
	local id = TimeOfDayController.getCurrent()
	local preset = id and TimeOfDay.Presets[id]
	if preset then
		return preset.WarmLights
	end
	return true
end

local function add(instance: Instance)
	if not instance:IsA("Model") or lights[instance] then
		return
	end
	local moving = instance:FindFirstChild("Moving")
	local head = moving and moving:FindFirstChild("Head")
	if not moving or not head or not head:IsA("BasePart") then
		return
	end
	-- Head frame: at the head's centre, looking where the lens points (lens +X).
	local lens = moving:FindFirstChild("Lens")
	local look = if lens and lens:IsA("BasePart")
		then lens.CFrame.RightVector
		else Vector3.new(0, 1, 0)
	local pivot = head.Position
	local headFrame = CFrame.lookAt(pivot, pivot + look)
	local flat = Vector3.new(look.X, 0, look.Z)
	local baseYaw = if flat.Magnitude > 1e-3 then math.atan2(-flat.X, -flat.Z) else 0

	local entry: Searchlight = {
		pivot = pivot,
		baseYaw = baseYaw,
		phase = (instance:GetAttribute("Phase") :: number?) or 0,
		parts = {},
		beams = {},
		lights = {},
		lens = if lens and lens:IsA("BasePart") then lens else nil,
	}
	for _, d in moving:GetDescendants() do
		if d:IsA("BasePart") then
			entry.parts[d] = headFrame:ToObjectSpace(d.CFrame)
		elseif d:IsA("Beam") then
			table.insert(entry.beams, d)
		elseif d:IsA("Light") then
			table.insert(entry.lights, d)
		end
	end
	lights[instance] = entry
end

local function update()
	local t = workspace:GetServerTimeNow()
	local on = warmOn()
	for model, light in lights do
		if not model.Parent then
			lights[model] = nil
			continue
		end
		local p = light.phase * math.pi * 2
		local yaw = light.baseYaw + math.rad(SWEEP_DEG) * math.sin(t * SWEEP_SPEED + p)
		local tiltT = (math.sin(t * TILT_SPEED + p * TILT_PERIOD_OFFSET) + 1) / 2
		local tilt = math.rad(TILT_MIN + (TILT_MAX - TILT_MIN) * tiltT)
		local frame = CFrame.new(light.pivot) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(tilt, 0, 0)
		for part, offset in light.parts do
			part.CFrame = frame * offset
		end

		local color = Color3.fromHSV((t * HUE_SPEED + light.phase) % 1, 0.65, 1)
		local sequence = ColorSequence.new(color)
		for _, beam in light.beams do
			beam.Enabled = on
			beam.Color = sequence
		end
		for _, l in light.lights do
			l.Color = color
		end
		if light.lens then
			light.lens.Color = color
		end
	end
end

function SearchlightController.start()
	for _, instance in CollectionService:GetTagged(TAG) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance: Instance)
		if instance:IsA("Model") then
			lights[instance] = nil
		end
	end)
	RunService.RenderStepped:Connect(update)
end

return SearchlightController
