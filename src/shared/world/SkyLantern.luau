--!strict
-- Shared settings and warm palettes for the hilltop Wishing Sky Lanterns.

export type LanternColor = {
	Name: string,
	Paper: Color3,
	Glow: Color3,
	Ember: Color3,
}

export type SpawnPayload = {
	wish: string,
	author: string,
	colorIndex: number,
	origin: Vector3,
	userId: number,
}

local SkyLantern = {
	-- Scenic cliffside ledge next to SkyTerrace facing the city lights (-X).
	StandPosition = Vector3.new(30, 105.42, 76.2),
	ViewDirection = Vector3.new(-0.988, 0, 0.155).Unit,
	MaxLength = 80,
	Cooldown = 60,
	MaxActive = 12,
	Colors = {
		{
			Name = "Warm Lantern",
			Paper = Color3.fromRGB(255, 236, 196),
			Glow = Color3.fromRGB(255, 206, 134),
			Ember = Color3.fromRGB(255, 244, 214),
		},
		{
			Name = "Candlelit Gold",
			Paper = Color3.fromRGB(255, 224, 174),
			Glow = Color3.fromRGB(255, 192, 114),
			Ember = Color3.fromRGB(255, 236, 194),
		},
		{
			Name = "Soft Ivory",
			Paper = Color3.fromRGB(255, 246, 226),
			Glow = Color3.fromRGB(255, 224, 170),
			Ember = Color3.fromRGB(255, 250, 236),
		},
		{
			Name = "Moonlit Cream",
			Paper = Color3.fromRGB(255, 242, 214),
			Glow = Color3.fromRGB(255, 216, 156),
			Ember = Color3.fromRGB(255, 248, 228),
		},
	} :: { LanternColor },
}

return SkyLantern
