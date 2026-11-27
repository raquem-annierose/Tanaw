--!strict
-- Wishing Sky Lanterns: opens the scenic cliffside ledge next to SkyTerrace,
-- builds a cozy wooden viewing deck + safety railing + lantern stand,
-- filters player wishes through Roblox TextService, and broadcasts each released
-- lantern so everyone on the hilltop watches wishes drift over the city lights.

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

-- Shorten the +Z end of Overlook.Plateau.Barriers.Front so players can walk onto the
-- scenic cliffside Wishing Deck while keeping the rest of the overlook safely walled.
local function openLedgeBarrier()
	local overlook = Workspace:FindFirstChild("Overlook")
	local plateau = overlook and overlook:FindFirstChild("Plateau")
	local barriers = plateau and plateau:FindFirstChild("Barriers")
	local front = barriers and barriers:FindFirstChild("Front")
	if not front or not front:IsA("BasePart") then
		return
	end
	if front:GetAttribute("WishingLedgeAdjusted") then
		return
	end
	front:SetAttribute("WishingLedgeAdjusted", true)

	local trimStuds = 9.2
	local newLen = math.max(10, front.Size.X - trimStuds)
	-- Front's RightVector points toward -Z, so shifting +RightVector trims the +Z end
	-- right up to Z ≈ 68.2 (the corner of the Wishing Deck) with no side gap.
	front.Size = Vector3.new(newLen, front.Size.Y, front.Size.Z)
	front.CFrame = front.CFrame * CFrame.new(trimStuds * 0.5, 0, 0)
end

-- Cozy soft-glow display paper lantern (warm translucent shell + tiny inner neon core
-- so it looks gentle and photogenic without over-blooming).
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
		light.Brightness = 0.9
		light.Range = 14
		light.Shadows = false
		light.Parent = lamp
	end
end

-- Aligned parallel to SkyTerrace & Overlook.Plateau.Barriers (facing SkyLantern.ViewDirection).
local function buildViewingDeck(model: Model): CFrame
	local center = Vector3.new(31.2, 105.28, 74.2)
	local deckCF = CFrame.lookAt(center, center + SkyLantern.ViewDirection)
	local width = 9.6 -- local X (-X is SkyTerrace wall, +X is right cliff edge)
	local depth = 20.5 -- local Z (-Z is front city view, +Z is entrance)
	local halfW = width * 0.5
	local halfD = depth * 0.5

	local woodDeck = Color3.fromRGB(118, 84, 58)
	local woodTrim = Color3.fromRGB(74, 50, 34)

	-- Rustic wooden viewing deck aligned cleanly with SkyTerrace's wall.
	makePart(
		model,
		"ViewingDeck",
		Vector3.new(width, 0.32, depth),
		deckCF,
		woodDeck,
		Enum.Material.WoodPlanks
	)

	-- Foundation skirting underneath so the deck never looks floating on the slope edge.
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

	-- Tall invisible safety barriers right behind the front & right railings, overlapping
	-- Overlook.Plateau.Barriers.Front at the entrance corner so there is zero gap.
	makeBarrier(
		model,
		"LedgeFrontBarrier",
		Vector3.new(width + 2, 45, 1),
		deckCF * CFrame.new(0, 20, -halfD - 0.35)
	)
	makeBarrier(
		model,
		"LedgeRightBarrier",
		Vector3.new(1, 45, depth + 4),
		deckCF * CFrame.new(halfW + 0.35, 20, 1.0)
	)

	return deckCF
end

local function buildStand(remote: RemoteEvent)
	local existing = Workspace:FindFirstChild("SkyLanternStand")
	if existing then
		existing:Destroy()
	end

	openLedgeBarrier()

	local model = Instance.new("Model")
	model.Name = "SkyLanternStand"
	model.Parent = Workspace

	local deckCF = buildViewingDeck(model)

	-- Place the wooden Wishing Lanterns table neatly along the left side of the aligned
	-- deck (parallel to SkyTerrace's wall), leaving the front railing open for wishes.
	local standCF = deckCF * CFrame.new(-3.3, 0.16, -1.5) * CFrame.Angles(0, math.rad(-90), 0)

	local woodDark = Color3.fromRGB(84, 56, 38)
	local woodWarm = Color3.fromRGB(132, 92, 60)

	local tableTop = makePart(
		model,
		"TableTop",
		Vector3.new(4.6, 0.28, 2.1),
		standCF * CFrame.new(0, 2.9, 0),
		woodWarm,
		Enum.Material.WoodPlanks
	)
	model.PrimaryPart = tableTop

	for _, lx in { -1.95, 1.95 } do
		for _, lz in { -0.8, 0.8 } do
			makePart(
				model,
				"Leg",
				Vector3.new(0.26, 2.9, 0.26),
				standCF * CFrame.new(lx, 1.45, lz),
				woodDark,
				Enum.Material.Wood
			)
		end
	end

	makePart(
		model,
		"Shelf",
		Vector3.new(4.0, 0.16, 1.7),
		standCF * CFrame.new(0, 1.0, 0),
		woodDark,
		Enum.Material.WoodPlanks
	)

	-- Two slender wooden posts framing an elevated, easy-to-read wooden sign above the table.
	for _, px in { -1.75, 1.75 } do
		makePart(
			model,
			"SignPost",
			Vector3.new(0.18, 3.2, 0.18),
			standCF * CFrame.new(px, 4.5, -0.75),
			woodDark,
			Enum.Material.Wood
		)
	end

	local sign = makePart(
		model,
		"Sign",
		Vector3.new(3.7, 1.15, 0.16),
		standCF * CFrame.new(0, 5.55, -0.75),
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
	title.Size = UDim2.new(1, -16, 0.56, 0)
	title.Position = UDim2.fromOffset(8, 4)
	title.BackgroundTransparency = 1
	title.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
	title.Text = "Wishing Lanterns"
	title.TextColor3 = Color3.fromRGB(255, 232, 188)
	title.TextScaled = true
	title.Parent = gui

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -16, 0.34, 0)
	sub.Position = UDim2.new(0, 8, 0.6, 0)
	sub.BackgroundTransparency = 1
	sub.FontFace = Font.fromEnum(Enum.Font.BuilderSans)
	sub.Text = "Write a wish & let it fly"
	sub.TextColor3 = Color3.fromRGB(238, 212, 182)
	sub.TextScaled = true
	sub.Parent = gui

	local backGui = gui:Clone()
	backGui.Face = Enum.NormalId.Back
	backGui.Parent = sign

	-- Soft warm overhead glow under the sign.
	local lightAnchor = makePart(
		model,
		"SignLight",
		Vector3.new(0.3, 0.3, 0.3),
		standCF * CFrame.new(0, 4.7, 0),
		Color3.fromRGB(255, 208, 136),
		Enum.Material.Neon
	)
	lightAnchor.Transparency = 1
	lightAnchor.CanCollide = false
	local warmLight = Instance.new("PointLight")
	warmLight.Color = Color3.fromRGB(255, 198, 126)
	warmLight.Brightness = 1.4
	warmLight.Range = 18
	warmLight.Shadows = false
	warmLight.Parent = lightAnchor

	-- Three soft-glow display paper lanterns neatly spaced on the tabletop.
	addDisplayLantern(model, standCF * CFrame.new(-1.25, 3.6, 0.15), SkyLantern.Colors[1])
	addDisplayLantern(model, standCF * CFrame.new(0, 3.6, 0.15), SkyLantern.Colors[2])
	addDisplayLantern(model, standCF * CFrame.new(1.25, 3.6, 0.15), SkyLantern.Colors[4])

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Make a Wish"
	prompt.ObjectText = "Sky Lantern"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = tableTop

	prompt.Triggered:Connect(function(player: Player)
		remote:FireClient(player, "Open")
	end)
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
