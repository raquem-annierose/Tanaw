--!strict
-- Ambient shooting stars across the night sky above the city lights view.
-- Runs purely on the client inside Workspace.CurrentCamera so it never modifies
-- the map or affects other players, and only appears when the sky has stars (Gabi).

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TimeOfDay = require(ReplicatedStorage.Shared.world.TimeOfDay)
local TimeOfDayController = require(script.Parent.TimeOfDayController)

-- Overlook anchor & direction facing the city lights vista.
local OVERLOOK_ORIGIN = Vector3.new(81, 91, 53)
local VIEW_FORWARD = Vector3.new(-0.988, 0, 0.155).Unit
local VIEW_RIGHT = VIEW_FORWARD:Cross(Vector3.yAxis).Unit

-- Sky canvas bounds (studs) framed in the upper half of the hangout's city view.
local DIST_MIN, DIST_MAX = 360, 620
local LATERAL_MIN, LATERAL_MAX = -460, 460
local HEIGHT_MIN, HEIGHT_MAX = 165, 340

-- Flight geometry and pacing (seconds).
local TRAVEL_MIN, TRAVEL_MAX = 220, 420
local DURATION_MIN, DURATION_MAX = 1.05, 1.75
local TRAIL_LIFETIME_MIN, TRAIL_LIFETIME_MAX = 0.55, 0.9
local FIRST_DELAY_MIN, FIRST_DELAY_MAX = 0.8, 1.8
local INTERVAL_MIN, INTERVAL_MAX = 2.2, 5.2
local TWIN_CHANCE = 0.28
local TWIN_DELAY_MIN, TWIN_DELAY_MAX = 0.3, 0.65

type Palette = {
	head: Color3,
	tail: Color3,
}

-- Curated palettes that harmonize with Gabi's indigo sky and warm café lights.
local PALETTES: { Palette } = {
	{ head = Color3.fromRGB(255, 250, 232), tail = Color3.fromRGB(255, 212, 152) }, -- warm gold
	{ head = Color3.fromRGB(255, 255, 255), tail = Color3.fromRGB(190, 224, 255) }, -- moonlit ice
	{ head = Color3.fromRGB(248, 240, 255), tail = Color3.fromRGB(198, 176, 255) }, -- soft lavender
	{ head = Color3.fromRGB(255, 244, 242), tail = Color3.fromRGB(255, 198, 212) }, -- blush starlight
}

type ActiveStar = {
	part: Part,
	trail: Trail,
	sparkles: ParticleEmitter?,
	startPos: Vector3,
	endPos: Vector3,
	arcLift: number,
	baseSize: number,
	elapsed: number,
	duration: number,
	tailFade: number,
	finishing: boolean,
}

local ShootingStarController = {}

local rng = Random.new()
local activeStars: { ActiveStar } = {}
local container: Folder? = nil
local isNight = false
local nextSpawnIn = 0
local pendingTwin: { delay: number, starPos: Vector3, velocityDir: Vector3, palette: Palette }? =
	nil

local function getContainer(): Folder?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	if container and container.Parent == camera then
		return container
	end
	local existing = camera:FindFirstChild("ShootingStars")
	if existing and existing:IsA("Folder") then
		container = existing
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "ShootingStars"
	folder.Parent = camera
	container = folder
	return folder
end

local function isStarryPreset(id: string?): boolean
	local preset = id and TimeOfDay.Presets[id]
	if preset then
		return preset.StarCount > 0
	end
	return false
end

local function createStarVisual(
	parent: Instance,
	startPos: Vector3,
	palette: Palette,
	sizeScale: number
): (Part, Trail, ParticleEmitter?)
	local headSize = rng:NextNumber(3.2, 5.0) * sizeScale

	local part = Instance.new("Part")
	part.Name = "ShootingStar"
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.Color = palette.head
	part.Size = Vector3.new(headSize, headSize, headSize)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Position = startPos
	part.Parent = parent

	local halfWidth = headSize * 0.8
	local att0 = Instance.new("Attachment")
	att0.Position = Vector3.new(0, halfWidth, 0)
	att0.Parent = part

	local att1 = Instance.new("Attachment")
	att1.Position = Vector3.new(0, -halfWidth, 0)
	att1.Parent = part

	local trail = Instance.new("Trail")
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.FaceCamera = true
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Brightness = 2.5
	trail.MinLength = 0.05
	trail.Lifetime = rng:NextNumber(TRAIL_LIFETIME_MIN, TRAIL_LIFETIME_MAX)
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, palette.head),
		ColorSequenceKeypoint.new(0.35, palette.tail),
		ColorSequenceKeypoint.new(1, palette.tail),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.25, 0.58),
		NumberSequenceKeypoint.new(0.65, 0.18),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.25),
		NumberSequenceKeypoint.new(0.75, 0.72),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Parent = part

	local sparkles: ParticleEmitter? = nil
	if not GuiService.ReducedMotionEnabled then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(palette.head, palette.tail)
		emitter.LightEmission = 1
		emitter.LightInfluence = 0
		emitter.Brightness = 2
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.35 * sizeScale),
			NumberSequenceKeypoint.new(0.5, 0.65 * sizeScale),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.6, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = NumberRange.new(0.35, 0.6)
		emitter.Rate = 18
		emitter.Speed = NumberRange.new(1, 5)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Parent = part
		sparkles = emitter
	end

	return part, trail, sparkles
end

local function pickRandomDirection(): Vector3
	-- Varied diagonal trajectories across the sky (left, right, steeper, gentler, slight depth).
	local horizSign = if rng:NextNumber() < 0.5 then 1 else -1
	local diveAngle = math.rad(rng:NextNumber(14, 52))
	local depthAngle = math.rad(rng:NextNumber(-28, 28))

	local horizontal = (VIEW_RIGHT * (math.cos(depthAngle) * horizSign) + VIEW_FORWARD * math.sin(
		depthAngle
	)).Unit
	return (horizontal * math.cos(diveAngle) - Vector3.yAxis * math.sin(diveAngle)).Unit
end

local function spawnStar(
	overrideStart: Vector3?,
	overrideDir: Vector3?,
	overridePalette: Palette?,
	sizeScale: number?
)
	local folder = getContainer()
	if not folder then
		return
	end

	local startPos: Vector3
	if overrideStart then
		startPos = overrideStart
	else
		local dist = rng:NextNumber(DIST_MIN, DIST_MAX)
		local lateral = rng:NextNumber(LATERAL_MIN, LATERAL_MAX)
		local height = rng:NextNumber(HEIGHT_MIN, HEIGHT_MAX)
		startPos = OVERLOOK_ORIGIN
			+ VIEW_FORWARD * dist
			+ VIEW_RIGHT * lateral
			+ Vector3.new(0, height, 0)
	end

	local dir = overrideDir or pickRandomDirection()
	local travel = rng:NextNumber(TRAVEL_MIN, TRAVEL_MAX)
	local endPos = startPos + dir * travel

	local palette = overridePalette or PALETTES[rng:NextInteger(1, #PALETTES)]
	local scale = sizeScale or 1
	local part, trail, sparkles = createStarVisual(folder, startPos, palette, scale)

	table.insert(activeStars, {
		part = part,
		trail = trail,
		sparkles = sparkles,
		startPos = startPos,
		endPos = endPos,
		arcLift = rng:NextNumber(8, 22),
		baseSize = part.Size.X,
		elapsed = 0,
		duration = rng:NextNumber(DURATION_MIN, DURATION_MAX),
		tailFade = trail.Lifetime + 0.1,
		finishing = false,
	})

	-- Occasionally queue a softer twin shooting star along a nearby similar path.
	if not overrideStart and not pendingTwin and rng:NextNumber() < TWIN_CHANCE then
		local offset = VIEW_RIGHT * rng:NextNumber(-55, 55)
			+ Vector3.new(0, rng:NextNumber(-35, 40), 0)
			+ VIEW_FORWARD * rng:NextNumber(-30, 30)
		pendingTwin = {
			delay = rng:NextNumber(TWIN_DELAY_MIN, TWIN_DELAY_MAX),
			starPos = startPos + offset,
			velocityDir = dir,
			palette = palette,
		}
	end
end

local function update(dt: number)
	if isNight then
		nextSpawnIn -= dt
		if nextSpawnIn <= 0 then
			spawnStar(nil, nil, nil, nil)
			nextSpawnIn = rng:NextNumber(INTERVAL_MIN, INTERVAL_MAX)
		end

		if pendingTwin then
			pendingTwin.delay -= dt
			if pendingTwin.delay <= 0 then
				local twin = pendingTwin
				pendingTwin = nil
				spawnStar(twin.starPos, twin.velocityDir, twin.palette, 0.78)
			end
		end
	end

	for i = #activeStars, 1, -1 do
		local star = activeStars[i]
		star.elapsed += dt

		if not star.finishing then
			local alpha = math.clamp(star.elapsed / star.duration, 0, 1)
			local eased = 1 - (1 - alpha) * (1 - alpha) * 0.35 - (1 - alpha) * 0.65
			local arc = math.sin(alpha * math.pi) * star.arcLift
			local pos = star.startPos:Lerp(star.endPos, eased) + Vector3.new(0, arc, 0)
			star.part.Position = pos

			-- Smooth fade-in (first 12%) and fade-out (last 28%) so nothing pops.
			local visibility: number
			if alpha < 0.12 then
				visibility = alpha / 0.12
			elseif alpha > 0.72 then
				visibility = (1 - alpha) / 0.28
			else
				visibility = 1
			end
			visibility = math.clamp(visibility, 0, 1)

			star.part.Transparency = 1 - visibility
			local currentSize = math.max(0.25, star.baseSize * (0.5 + 0.5 * visibility))
			star.part.Size = Vector3.new(currentSize, currentSize, currentSize)

			if alpha >= 1 then
				star.finishing = true
				star.elapsed = 0
				star.part.Transparency = 1
				star.trail.Enabled = false
				if star.sparkles then
					star.sparkles.Enabled = false
				end
			end
		else
			if star.elapsed >= star.tailFade then
				star.part:Destroy()
				table.remove(activeStars, i)
			end
		end
	end
end

local function onTimeOfDayChanged(id: string)
	local nowNight = isStarryPreset(id)
	if nowNight == isNight then
		return
	end
	isNight = nowNight
	pendingTwin = nil
	if isNight then
		nextSpawnIn = rng:NextNumber(FIRST_DELAY_MIN, FIRST_DELAY_MAX)
	end
end

function ShootingStarController.start()
	isNight = isStarryPreset(TimeOfDayController.getCurrent())
	if isNight then
		nextSpawnIn = rng:NextNumber(FIRST_DELAY_MIN, FIRST_DELAY_MAX)
	end
	TimeOfDayController.Changed:Connect(onTimeOfDayChanged)
	RunService.RenderStepped:Connect(update)
end

return ShootingStarController
