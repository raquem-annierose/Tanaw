--!strict
-- Wishing Sky Lanterns: opens a clean archway through SkyTerrace's side wall onto
-- the scenic cliffside Wishing Deck, places 2 side-by-side Wishing Lantern tables
-- so 2 players can make wishes together, filters wishes through Roblox TextService,
-- and broadcasts each released lantern to all players.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.core.Remotes)
local SkyLantern = require(ReplicatedStorage.Shared.world.SkyLantern)

local SkyLanternService = {}

local lastRelease: { [Player]: number } = {}

local function filterWish(player: Player, text: string): string?
	local okChat, canChat = pcall(function()
		return TextChatService:CanUserChatAsync(player.UserId)
	end)
	if not okChat or not canChat then
		return nil
	end
	local ok, result = pcall(function()
		local filtered =
			TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	return if ok then result else nil
end

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function makeBarrier(parent: Instance, name: string, size: Vector3, cf: CFrame)
	local b = makePart(parent, name, size, cf, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	b.Transparency = 1
	b.CanCollide = true
	b.CanQuery = false
	b.CanTouch = false
	b.CastShadow = false
end

-- Splits a long horizontal beam (StoneWall.Core or Railing.HandRailSide) around the
-- doorway interval [gapStartWorld, gapEndWorld] so both sides stay cleanly intact.
local function splitBeamForDoorway(beam: BasePart, gapStartWorld: Vector3, gapEndWorld: Vector3)
	if beam:GetAttribute("WishingDoorSplit") then
		return
	end
	beam:SetAttribute("WishingDoorSplit", true)

	local parent = beam.Parent
	if not parent then
		return
	end

	local halfLen = beam.Size.X * 0.5
	local x1 = beam.CFrame:PointToObjectSpace(gapStartWorld).X
	local x2 = beam.CFrame:PointToObjectSpace(gapEndWorld).X
	local gapMin = math.clamp(math.min(x1, x2), -halfLen, halfLen)
	local gapMax = math.clamp(math.max(x1, x2), -halfLen, halfLen)

	local function spawnSegment(segMin: number, segMax: number)
		local len = segMax - segMin
		if len < 0.25 then
			return
		end
		local clone = beam:Clone()
		clone:SetAttribute("WishingDoorSplit", true)
		clone.Size = Vector3.new(len, beam.Size.Y, beam.Size.Z)
		clone.CFrame = beam.CFrame * CFrame.new((segMin + segMax) * 0.5, 0, 0)
		clone.Parent = parent
	end

	spawnSegment(-halfLen, gapMin)
	spawnSegment(gapMax, halfLen)
	beam:Destroy()
end

-- Opens a clean pathway through SkyTerrace's low stone wall & railing right between
-- the two pergola posts so players walk directly from SkyTerrace onto the Wishing Deck.
local function openSkyTerraceArchway(deckCF: CFrame, doorMinZ: number, doorMaxZ: number)
	local overlook = Workspace:FindFirstChild("Overlook")
	local skyTerrace = overlook and overlook:FindFirstChild("SkyTerrace")
	local patio = skyTerrace and skyTerrace:FindFirstChild("Patio")
	if not patio then
		return
	end

	local gapStartWorld = (deckCF * CFrame.new(-5.8, 1.5, doorMinZ)).Position
	local gapEndWorld = (deckCF * CFrame.new(-5.8, 1.5, doorMaxZ)).Position

	local stoneWall = patio:FindFirstChild("StoneWall")
	if stoneWall then
		for _, child in stoneWall:GetChildren() do
			if not child:IsA("BasePart") then
				continue
			end
			if child.Name == "Core" and child.Size.X > 20 then
				splitBeamForDoorway(child, gapStartWorld, gapEndWorld)
			else
				local localPos = deckCF:PointToObjectSpace(child.Position)
				if
					localPos.X >= -7.4
					and localPos.X <= -4.0
					and localPos.Z >= doorMinZ - 0.1
					and localPos.Z <= doorMaxZ + 0.1
					and child.Position.Y >= 104.2
				then
					child:Destroy()
				end
			end
		end
	end

	local railing = patio:FindFirstChild("Railing")
	if railing then
		for _, child in railing:GetChildren() do
			if not child:IsA("BasePart") then
				continue
			end
			if child.Name == "HandRailSide" and child.Size.X > 20 then
				splitBeamForDoorway(child, gapStartWorld, gapEndWorld)
			elseif child.Name == "Post" then
				local localPos = deckCF:PointToObjectSpace(child.Position)
				if
					localPos.X >= -7.4
					and localPos.X <= -4.0
					and localPos.Z >= doorMinZ - 0.1
					and localPos.Z <= doorMaxZ + 0.1
				then
					child:Destroy()
				end
			end
		end
	end

	-- Split SkyTerrace's invisible side barrier ONLY across the archway opening so
	-- players can walk straight through while the rest of SkyTerrace stays walled.
	local barriers = skyTerrace and skyTerrace:FindFirstChild("Barriers")
	local sideA = barriers and barriers:FindFirstChild("SideA")
	if sideA and sideA:IsA("BasePart") and sideA.Size.X > 20 then
		splitBeamForDoorway(sideA, gapStartWorld, gapEndWorld)
	end
end

-- Cozy soft-glow display paper lantern.
local function addDisplayLantern(parent: Instance, cf: CFrame, color: SkyLantern.LanternColor)
	local body = makePart(
		parent,
		"DisplayLantern",
		Vector3.new(1.05, 0.85, 0.85),
		cf * CFrame.Angles(0, 0, math.rad(90)),
		color.Paper,
		Enum.Material.SmoothPlastic
	)
	body.Shape = Enum.PartType.Cylinder
	body.Transparency = 0.22
	body.CanCollide = false
	body.CastShadow = false

	local core = makePart(
		parent,
		"DisplayCore",
		Vector3.new(0.32, 0.42, 0.32),
		cf * CFrame.new(0, -0.1, 0),
		color.Glow,
		Enum.Material.Neon
	)
	core.Shape = Enum.PartType.Ball
	core.CanCollide = false
	core.CastShadow = false

	local rim = makePart(
		parent,
		"DisplayRim",
		Vector3.new(0.1, 0.86, 0.86),
		cf * CFrame.new(0, -0.52, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(78, 52, 34),
		Enum.Material.Wood
	)
	rim.Shape = Enum.PartType.Cylinder
	rim.CanCollide = false
end

local function addRailPost(parent: Instance, postCF: CFrame, withLamp: boolean)
	local woodDark = Color3.fromRGB(74, 50, 34)
	makePart(
		parent,
		"RailPost",
		Vector3.new(0.36, 3.6, 0.36),
		postCF * CFrame.new(0, 1.8, 0),
		woodDark,
		Enum.Material.Wood
	)
	if withLamp then
		local lamp = makePart(
			parent,
			"PostLamp",
			Vector3.new(0.42, 0.52, 0.42),
			postCF * CFrame.new(0, 3.85, 0),
			Color3.fromRGB(255, 214, 148),
			Enum.Material.Neon
		)
		lamp.Transparency = 0.15
		lamp.CanCollide = false
		lamp.CastShadow = false

		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 198, 128)
		light.Brightness = 0.85
		light.Range = 14
		light.Shadows = false
		light.Parent = lamp
	end
end

-- Aligned parallel to SkyTerrace (facing SkyLantern.ViewDirection), accessed cleanly
-- through the SkyTerrace archway with full railings around the 3 outer edges.
local function buildViewingDeck(model: Model): CFrame
	local center = Vector3.new(31.2, 105.28, 74.2)
	local deckCF = CFrame.lookAt(center, center + SkyLantern.ViewDirection)
	local width = 9.8 -- local X (-X is SkyTerrace wall, +X is right cliff edge)
	local depth = 20.5 -- local Z (-Z is front city view, +Z is back edge)
	local halfW = width * 0.5
	local halfD = depth * 0.5

	-- Doorway opening along SkyTerrace's side wall (between the two pergola posts).
	local doorMinZ = -0.6
	local doorMaxZ = 6.2
	local doorCenterZ = (doorMinZ + doorMaxZ) * 0.5
	local doorWidth = doorMaxZ - doorMinZ

	openSkyTerraceArchway(deckCF, doorMinZ, doorMaxZ)

	local woodDeck = Color3.fromRGB(118, 84, 58)
	local woodTrim = Color3.fromRGB(74, 50, 34)

	-- Rustic wooden viewing deck aligned flush with SkyTerrace's stone wall.
	makePart(
		model,
		"ViewingDeck",
		Vector3.new(width, 0.32, depth),
		deckCF,
		woodDeck,
		Enum.Material.WoodPlanks
	)

	-- Seamless wooden threshold bridge connecting SkyTerrace patio floor to the deck.
	makePart(
		model,
		"EntryBridge",
		Vector3.new(2.8, 0.36, doorWidth + 0.4),
		deckCF * CFrame.new(-halfW - 1.1, 0.12, doorCenterZ),
		woodDeck,
		Enum.Material.WoodPlanks
	)

	-- Warm glowing wooden lantern posts flanking the SkyTerrace entryway.
	addRailPost(model, deckCF * CFrame.new(-halfW - 0.5, 0.16, doorMinZ - 0.1), true)
	addRailPost(model, deckCF * CFrame.new(-halfW - 0.5, 0.16, doorMaxZ + 0.1), true)

	-- Foundation skirting underneath so the deck never looks floating on the slope.
	makePart(
		model,
		"DeckBase",
		Vector3.new(width - 0.5, 2.4, depth - 0.5),
		deckCF * CFrame.new(0, -1.35, 0),
		woodTrim,
		Enum.Material.Wood
	)

	-- Front railing (local Z = -halfD, facing the city lights).
	local frontZ = -halfD + 0.25
	local frontXs = { -halfW + 0.25, -halfW * 0.33, halfW * 0.33, halfW - 0.25 }
	for idx, x in frontXs do
		addRailPost(model, deckCF * CFrame.new(x, 0.16, frontZ), idx == 1 or idx == #frontXs)
	end
	for _, railH in { 1.6, 3.3 } do
		makePart(
			model,
			"FrontRail",
			Vector3.new(width, 0.2, 0.24),
			deckCF * CFrame.new(0, 0.16 + railH, frontZ),
			woodTrim,
			Enum.Material.Wood
		)
	end

	-- Right-side railing (local X = +halfW, along the cliff drop-off).
	local rightX = halfW - 0.25
	for _, z in { -halfD + 4.2, -halfD + 8.3, -halfD + 12.4, -halfD + 16.5, halfD - 0.25 } do
		addRailPost(model, deckCF * CFrame.new(rightX, 0.16, z), z > halfD - 1)
	end
	for _, railH in { 1.6, 3.3 } do
		makePart(
			model,
			"RightRail",
			Vector3.new(0.24, 0.2, depth),
			deckCF * CFrame.new(rightX, 0.16 + railH, 0),
			woodTrim,
			Enum.Material.Wood
		)
	end

	-- Back railing (local Z = +halfD, cleanly enclosing the old non-stair edge).
	local backZ = halfD - 0.25
	for idx, x in { -halfW + 0.25, -halfW * 0.33, halfW * 0.33 } do
		addRailPost(model, deckCF * CFrame.new(x, 0.16, backZ), idx == 1)
	end
	for _, railH in { 1.6, 3.3 } do
		makePart(
			model,
			"BackRail",
			Vector3.new(width, 0.2, 0.24),
			deckCF * CFrame.new(0, 0.16 + railH, backZ),
			woodTrim,
			Enum.Material.Wood
		)
	end

	-- Invisible safety barriers behind all 3 outer railings so players can enjoy the view safely.
	makeBarrier(
		model,
		"LedgeFrontBarrier",
		Vector3.new(width + 2, 45, 1),
		deckCF * CFrame.new(0, 20, -halfD - 0.35)
	)
	makeBarrier(
		model,
		"LedgeRightBarrier",
		Vector3.new(1, 45, depth + 2),
		deckCF * CFrame.new(halfW + 0.35, 20, 0)
	)
	makeBarrier(
		model,
		"LedgeBackBarrier",
		Vector3.new(width + 2, 45, 1),
		deckCF * CFrame.new(0, 20, halfD + 0.35)
	)

	return deckCF
end

local function buildLanternTable(
	model: Model,
	standCF: CFrame,
	tableIndex: number,
	remote: RemoteEvent
): Part
	local woodDark = Color3.fromRGB(84, 56, 38)
	local woodWarm = Color3.fromRGB(132, 92, 60)

	local tableTop = makePart(
		model,
		`TableTop_{tableIndex}`,
		Vector3.new(4.4, 0.26, 2.0),
		standCF * CFrame.new(0, 2.9, 0),
		woodWarm,
		Enum.Material.WoodPlanks
	)

	for _, lx in { -1.85, 1.85 } do
		for _, lz in { -0.75, 0.75 } do
			makePart(
				model,
				"Leg",
				Vector3.new(0.24, 2.9, 0.24),
				standCF * CFrame.new(lx, 1.45, lz),
				woodDark,
				Enum.Material.Wood
			)
		end
	end

	makePart(
		model,
		"Shelf",
		Vector3.new(3.8, 0.16, 1.6),
		standCF * CFrame.new(0, 1.0, 0),
		woodDark,
		Enum.Material.WoodPlanks
	)

	for _, px in { -1.65, 1.65 } do
		makePart(
			model,
			"SignPost",
			Vector3.new(0.16, 3.0, 0.16),
			standCF * CFrame.new(px, 4.4, -0.7),
			woodDark,
			Enum.Material.Wood
		)
	end

	local sign = makePart(
		model,
		"Sign",
		Vector3.new(3.5, 1.1, 0.16),
		standCF * CFrame.new(0, 5.4, -0.7),
		Color3.fromRGB(62, 42, 30),
		Enum.Material.Wood
	)
	sign.CanCollide = false

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 80
	gui.LightInfluence = 0.08
	gui.MaxDistance = 80
	gui.Parent = sign

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -14, 0.56, 0)
	title.Position = UDim2.fromOffset(7, 4)
	title.BackgroundTransparency = 1
	title.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
	title.Text = "Wishing Lanterns"
	title.TextColor3 = Color3.fromRGB(255, 232, 188)
	title.TextScaled = true
	title.Parent = gui

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -14, 0.34, 0)
	sub.Position = UDim2.new(0, 7, 0.6, 0)
	sub.BackgroundTransparency = 1
	sub.FontFace = Font.fromEnum(Enum.Font.BuilderSans)
	sub.Text = "Write a wish & let it fly"
	sub.TextColor3 = Color3.fromRGB(238, 212, 182)
	sub.TextScaled = true
	sub.Parent = gui

	local backGui = gui:Clone()
	backGui.Face = Enum.NormalId.Back
	backGui.Parent = sign

	local lightAnchor = makePart(
		model,
		"SignLight",
		Vector3.new(0.2, 0.2, 0.2),
		standCF * CFrame.new(0, 4.6, 0),
		Color3.fromRGB(255, 208, 136),
		Enum.Material.Neon
	)
	lightAnchor.Transparency = 1
	lightAnchor.CanCollide = false
	local warmLight = Instance.new("PointLight")
	warmLight.Color = Color3.fromRGB(255, 198, 126)
	warmLight.Brightness = 1.1
	warmLight.Range = 16
	warmLight.Shadows = false
	warmLight.Parent = lightAnchor

	addDisplayLantern(model, standCF * CFrame.new(-1.15, 3.55, 0.15), SkyLantern.Colors[1])
	addDisplayLantern(model, standCF * CFrame.new(0, 3.55, 0.15), SkyLantern.Colors[2])
	addDisplayLantern(model, standCF * CFrame.new(1.15, 3.55, 0.15), SkyLantern.Colors[3])

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Make a Wish"
	prompt.ObjectText = `Sky Lantern #{tableIndex}`
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = tableTop

	prompt.Triggered:Connect(function(player: Player)
		remote:FireClient(player, "Open")
	end)

	return tableTop
end

local function buildStand(remote: RemoteEvent)
	local existing = Workspace:FindFirstChild("SkyLanternStand")
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "SkyLanternStand"
	model.Parent = Workspace

	local deckCF = buildViewingDeck(model)

	-- Place 2 Wishing Lantern tables neatly along the right railing side of the deck
	-- facing the SkyTerrace entryway so 2 friends can make wishes at the same time,
	-- while keeping the pathway and the entire front city-lights railing wide open.
	local table1 = buildLanternTable(
		model,
		deckCF * CFrame.new(3.35, 0.16, -5.2) * CFrame.Angles(0, math.rad(90), 0),
		1,
		remote
	)
	buildLanternTable(
		model,
		deckCF * CFrame.new(3.35, 0.16, 2.2) * CFrame.Angles(0, math.rad(90), 0),
		2,
		remote
	)
	model.PrimaryPart = table1
end

local function computeLaunchOrigin(player: Player): Vector3
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position + SkyLantern.ViewDirection * 3.2 + Vector3.new(0, 1.4, 0)
	end
	return SkyLantern.StandPosition + SkyLantern.ViewDirection * 2.5 + Vector3.new(0, 4.5, 0)
end

function SkyLanternService.start()
	local remote = Remotes.skyLantern()
	buildStand(remote)

	remote.OnServerEvent:Connect(
		function(
			player: Player,
			kind: unknown,
			wish: unknown,
			colorIndex: unknown,
			anonymous: unknown
		)
			if kind ~= "Release" or typeof(wish) ~= "string" then
				return
			end

			local now = os.clock()
			local remaining = SkyLantern.Cooldown - (now - (lastRelease[player] or -math.huge))
			if remaining > 0 then
				remote:FireClient(
					player,
					"Error",
					`Take a breath — you can light another lantern in {math.ceil(remaining)}s.`
				)
				return
			end

			local trimmed = string.gsub(string.gsub(wish, "%s+", " "), "^%s*(.-)%s*$", "%1")
			if trimmed == "" then
				remote:FireClient(player, "Error", "Write a short wish or message first.")
				return
			end
			if utf8.len(trimmed) == nil or (utf8.len(trimmed) :: number) > SkyLantern.MaxLength then
				remote:FireClient(
					player,
					"Error",
					`Please keep your wish within {SkyLantern.MaxLength} characters.`
				)
				return
			end

			local chosenColor = 1
			if typeof(colorIndex) == "number" then
				local rounded = math.floor(colorIndex)
				if rounded >= 1 and rounded <= #SkyLantern.Colors then
					chosenColor = rounded
				end
			end

			lastRelease[player] = now
			local filtered = filterWish(player, trimmed)
			if not filtered then
				lastRelease[player] = nil
				remote:FireClient(
					player,
					"Error",
					"Couldn't send your wish right now. Please try again."
				)
				return
			end

			local payload: SkyLantern.SpawnPayload = {
				wish = filtered,
				author = if anonymous == true then "anonymous" else player.DisplayName,
				colorIndex = chosenColor,
				origin = computeLaunchOrigin(player),
				userId = player.UserId,
			}
			remote:FireClient(player, "Released")
			remote:FireAllClients("Spawn", payload)
		end
	)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastRelease[player] = nil
	end)
end

return SkyLanternService
