--!strict
-- A live mirror on the photobooth glass: players see themselves (and the terrace behind them)
-- before they even press the prompt.
--
-- How: a ViewportFrame on the booth's SurfaceGui shows copies of the world reflected across
-- the glass. The viewport camera sits at this player's real camera and looks straight into the
-- glass; the ViewportFrame is sized and moved inside the (clipped) screen so the glass works
-- like a window into the reflected world (an off-axis view, so it stays right from any angle).
--
-- Static parts in front of the glass are copied once. Characters nearby are copied and their
-- parts follow the real ones every frame. A reflected part keeps its shape by flipping its own
-- X axis (fine for the symmetric parts avatars and props are made of).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Photobooth = require(ReplicatedStorage.Shared.photobooth.Photobooth)

local SETTINGS = Photobooth.Mirror
-- Small gap so copies standing on the glass don't flicker against it.
local MAX_HALF_FOV = math.rad(60)
local CHARACTER_SCAN = 0.5
local INDEX_ATTRIBUTE = "MirrorIndex"

type Copy = {
	clone: Model,
	pairs: { { source: BasePart, copy: BasePart } },
	dirty: boolean,
	connections: { RBXScriptConnection },
}

type Mirror = {
	booth: Model,
	glass: BasePart,
	gui: SurfaceGui,
	group: CanvasGroup,
	sky: Frame,
	skyGradient: UIGradient,
	view: ViewportFrame,
	camera: Camera,
	world: Model,
	characters: { [Model]: Copy },
	built: boolean,
}

local PhotoboothMirror = {}

local mirrors: { [Model]: Mirror } = {}

-- Reflection of a CFrame across the plane through `point` with unit normal `n`.
local function reflect(cf: CFrame, point: Vector3, n: Vector3): CFrame
	local function flip(v: Vector3): Vector3
		return v - 2 * v:Dot(n) * n
	end
	local p = cf.Position
	local position = p - 2 * (p - point):Dot(n) * n
	return CFrame.fromMatrix(position, -flip(cf.XVector), flip(cf.YVector), flip(cf.ZVector))
end

local STRIP = {
	"LuaSourceContainer",
	"Sound",
	"Light",
	"ParticleEmitter",
	"Beam",
	"Trail",
	"ProximityPrompt",
	"ClickDetector",
	"BillboardGui",
	"SurfaceGui",
	"ForceField",
	"Fire",
	"Smoke",
	"Sparkles",
}

local function scrub(root: Instance)
	for _, d in root:GetDescendants() do
		for _, className in STRIP do
			if d:IsA(className) then
				d:Destroy()
				break
			end
		end
	end
end

local function partOf(instance: Instance, model: Instance): boolean
	return instance == model or instance:IsDescendantOf(model)
end

-- Copies the static parts in front of the glass, once.
local function buildWorld(m: Mirror)
	local glassCf = m.glass.CFrame
	local n = glassCf.LookVector
	local region = CFrame.fromMatrix(
		m.glass.Position + n * (SETTINGS.RegionDepth / 2) + glassCf.UpVector * 6,
		glassCf.RightVector,
		glassCf.UpVector,
		-n
	)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local found = Workspace:GetPartBoundsInBox(
		region,
		Vector3.new(SETTINGS.RegionWidth, SETTINGS.RegionHeight, SETTINGS.RegionDepth),
		params
	)

	local stanchions = m.booth:FindFirstChild("Stanchions")
	local candidates: { { part: BasePart, distance: number } } = {}
	for _, part in found do
		local inBooth = partOf(part, m.booth)
		local keep = part.Transparency < 0.98
			and (not inBooth or (stanchions ~= nil and partOf(part, stanchions)))
			and (part.Position - m.glass.Position):Dot(n) > -0.5
			and part.Size.Magnitude < 400
			and not part:FindFirstAncestorOfClass("Tool")
		if keep then
			table.insert(
				candidates,
				{ part = part, distance = (part.Position - m.glass.Position).Magnitude }
			)
		end
	end
	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)

	local point = m.glass.Position
	for i = 1, math.min(#candidates, SETTINGS.MaxParts) do
		local source = candidates[i].part
		local wasArchivable = source.Archivable
		source.Archivable = true
		local ok, copy = pcall(function()
			return source:Clone()
		end)
		source.Archivable = wasArchivable
		if ok and copy then
			for _, child in copy:GetChildren() do
				-- Nested parts are copied on their own if they're in the region.
				if child:IsA("BasePart") then
					child:Destroy()
				end
			end
			scrub(copy)
			copy.Anchored = true
			copy.CFrame = reflect(source.CFrame, point, n)
			copy.Parent = m.world
		end
	end
end

local function dropCharacter(m: Mirror, character: Model)
	local c = m.characters[character]
	if not c then
		return
	end
	m.characters[character] = nil
	for _, connection in c.connections do
		connection:Disconnect()
	end
	c.clone:Destroy()
end

local function copyCharacter(m: Mirror, character: Model): Copy?
	local sources: { BasePart } = {}
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(sources, d)
			d:SetAttribute(INDEX_ATTRIBUTE, #sources)
		end
	end
	local wasArchivable = character.Archivable
	character.Archivable = true
	local ok, clone = pcall(function()
		return character:Clone()
	end)
	character.Archivable = wasArchivable
	if not ok or not clone then
		return nil
	end
	scrub(clone)
	local list = {}
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			local index = d:GetAttribute(INDEX_ATTRIBUTE)
			local source = if typeof(index) == "number" then sources[index] else nil
			if source then
				table.insert(list, { source = source, copy = d })
			end
		elseif d:IsA("Humanoid") then
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
	clone.Parent = m.view
	return { clone = clone, pairs = list, dirty = false, connections = {} }
end

local function trackCharacter(m: Mirror, character: Model)
	local c = copyCharacter(m, character)
	if not c then
		return
	end
	m.characters[character] = c
	-- Tools and accessories coming and going: copy again (once per burst).
	local function markDirty()
		c.dirty = true
	end
	table.insert(c.connections, character.DescendantAdded:Connect(markDirty))
	table.insert(c.connections, character.DescendantRemoving:Connect(markDirty))
end

-- Sky color behind everything, roughly following the time of day.
local function skyColors(): (Color3, Color3)
	local t = Lighting.ClockTime
	if t >= 7 and t < 17 then
		return Color3.fromRGB(120, 170, 225), Color3.fromRGB(200, 225, 245)
	elseif t >= 17 and t < 19.5 then
		return Color3.fromRGB(70, 74, 130), Color3.fromRGB(220, 130, 150)
	elseif t >= 5 and t < 7 then
		return Color3.fromRGB(90, 100, 150), Color3.fromRGB(240, 180, 150)
	end
	return Color3.fromRGB(14, 16, 34), Color3.fromRGB(46, 36, 70)
end

local function setup(instance: Instance)
	if not instance:IsA("Model") or mirrors[instance] then
		return
	end
	local glass = instance:FindFirstChild("TouchDisplay")
	local gui = glass and glass:FindFirstChild("Display")
	local screen = gui and gui:FindFirstChild("Screen")
	if not glass or not glass:IsA("BasePart") or not gui or not gui:IsA("SurfaceGui") then
		return
	end

	-- Clipped to the screen's capsule shape.
	local group = Instance.new("CanvasGroup")
	group.Name = "Reflection"
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.ZIndex = 1
	local screenCorner = screen and screen:FindFirstChildOfClass("UICorner")
	if screenCorner then
		screenCorner:Clone().Parent = group
	end

	local sky = Instance.new("Frame")
	sky.Name = "Sky"
	sky.Size = UDim2.fromScale(1, 1)
	sky.BackgroundColor3 = Color3.new(1, 1, 1)
	sky.BorderSizePixel = 0
	local skyGradient = Instance.new("UIGradient")
	skyGradient.Rotation = 90
	skyGradient.Parent = sky
	sky.Parent = group

	local view = Instance.new("ViewportFrame")
	view.Name = "View"
	view.AnchorPoint = Vector2.new(0.5, 0.5)
	view.BackgroundTransparency = 1
	view.Parent = group
	local camera = Instance.new("Camera")
	camera.Parent = view
	view.CurrentCamera = camera
	local world = Instance.new("Model")
	world.Name = "World"
	world.Parent = view

	group.Parent = gui
	if screen and screen:IsA("GuiObject") then
		screen.ZIndex = 2
	end

	mirrors[instance] = {
		booth = instance,
		glass = glass,
		gui = gui,
		group = group,
		sky = sky,
		skyGradient = skyGradient,
		view = view,
		camera = camera,
		world = world,
		characters = {},
		built = false,
	}
end

local function remove(instance: Instance)
	local m = if instance:IsA("Model") then mirrors[instance] else nil
	if m then
		for character in m.characters do
			dropCharacter(m, character)
		end
		m.group:Destroy()
		mirrors[m.booth] = nil
	end
end

-- Keeps the character copies in step with who is near the glass.
local function scanCharacters(m: Mirror)
	local point = m.glass.Position
	local n = m.glass.CFrame.LookVector
	local present: { [Model]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and root and root:IsA("BasePart") then
			local offset = root.Position - point
			if offset.Magnitude <= SETTINGS.CharacterRange and offset:Dot(n) > 0 then
				present[character] = true
				local c = m.characters[character]
				if c and c.dirty then
					dropCharacter(m, character)
				end
				if not m.characters[character] then
					trackCharacter(m, character)
				end
			end
		end
	end
	for character in m.characters do
		if not present[character] or not character.Parent then
			dropCharacter(m, character)
		end
	end
end

local function render(m: Mirror, cameraCf: CFrame)
	local glassCf = m.glass.CFrame
	local n = glassCf.LookVector
	local r = glassCf.RightVector
	local up = glassCf.UpVector
	local eye = cameraCf.Position
	local offset = eye - m.glass.Position
	local distance = offset:Dot(n)
	if distance < 0.3 or offset.Magnitude > SETTINGS.RenderDistance then
		m.group.Visible = false
		return
	end
	m.group.Visible = true

	-- Eye position across the glass, in the SurfaceGui's directions (x = -RightVector on a
	-- Front face, y = up).
	local ex = offset:Dot(-r)
	local ey = offset:Dot(up)
	local halfW = m.glass.Size.X / 2
	local halfH = m.glass.Size.Y / 2
	local reach = math.max(math.abs(ex) + halfW, math.abs(ey) + halfH)
	local halfFov = math.min(math.atan(reach / distance), MAX_HALF_FOV)
	local side = 2 * distance * math.tan(halfFov)

	local pps = m.gui.PixelsPerStud
	m.view.Size = UDim2.fromOffset(side * pps, side * pps)
	m.view.Position = UDim2.fromOffset((halfW + ex) * pps, (halfH - ey) * pps)
	m.camera.FieldOfView = math.deg(2 * halfFov)
	m.camera.CFrame = CFrame.fromMatrix(eye, -r, up, n)

	local point = m.glass.Position
	for _, c in m.characters do
		for _, pair in c.pairs do
			pair.copy.CFrame = reflect(pair.source.CFrame, point, n)
		end
	end
end

local function updateLook(m: Mirror)
	local top, bottom = skyColors()
	m.skyGradient.Color = ColorSequence.new(top, bottom)
	m.view.Ambient = Lighting.OutdoorAmbient:Lerp(Color3.new(1, 1, 1), 0.35)
	local sun = Lighting:GetSunDirection()
	local n = m.glass.CFrame.LookVector
	m.view.LightDirection = -(sun - 2 * sun:Dot(n) * n)
	local day = Lighting.ClockTime >= 6.5 and Lighting.ClockTime < 18
	m.view.LightColor = if day then Color3.fromRGB(255, 244, 230) else Color3.fromRGB(120, 110, 150)
end

function PhotoboothMirror.start()
	for _, instance in CollectionService:GetTagged(Photobooth.Tag) do
		setup(instance)
	end
	CollectionService:GetInstanceAddedSignal(Photobooth.Tag):Connect(setup)
	CollectionService:GetInstanceRemovedSignal(Photobooth.Tag):Connect(remove)

	local sinceScan = 0
	RunService:BindToRenderStep(
		"TanawPhotoboothMirror",
		Enum.RenderPriority.Camera.Value + 5,
		function(dt: number)
			if next(mirrors) == nil then
				return
			end
			local cameraCf = Workspace.CurrentCamera.CFrame
			sinceScan += dt
			local scan = sinceScan >= CHARACTER_SCAN
			if scan then
				sinceScan = 0
			end
			for _, m in mirrors do
				local near = (cameraCf.Position - m.glass.Position).Magnitude
					<= SETTINGS.RenderDistance
				if near and not m.built then
					m.built = true
					buildWorld(m)
					updateLook(m)
				end
				if near then
					if scan then
						scanCharacters(m)
						updateLook(m)
					end
					render(m, cameraCf)
				else
					m.group.Visible = false
				end
			end
		end
	)
end

return PhotoboothMirror
