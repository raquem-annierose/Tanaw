--!strict
-- Time-of-day looks for the overlook (Umaga / Hapon / Gabi).
-- Colors follow Asset/community-roblox/inspiration/analysis/02-sky-day-night.md.

export type AtmosphereLook = {
	Density: number,
	Offset: number,
	Color: Color3,
	Decay: Color3,
	Glare: number,
	Haze: number,
}

export type Preset = {
	Id: string,
	Label: string,
	Icon: string,
	ClockTime: number,
	Brightness: number,
	OutdoorAmbient: Color3,
	Ambient: Color3,
	Atmosphere: AtmosphereLook,
	Tint: Color3,
	Saturation: number,
	CloudColor: Color3,
	CloudCover: number,
	-- String lights, fairy lights, tent glow.
	WarmLights: boolean,
	-- Lit windows across the city and houses.
	CityLights: boolean,
}

local Umaga: Preset = {
	Id = "Umaga",
	Label = "Umaga",
	Icon = "☀️",
	ClockTime = 9,
	Brightness = 2.6,
	OutdoorAmbient = Color3.fromRGB(140, 140, 150),
	Ambient = Color3.fromRGB(70, 70, 76),
	Atmosphere = {
		Density = 0.34,
		Offset = 0.15,
		Color = Color3.fromRGB(206, 214, 226),
		Decay = Color3.fromRGB(112, 128, 152),
		Glare = 0.1,
		Haze = 1.8,
	},
	Tint = Color3.fromRGB(255, 252, 246),
	Saturation = 0.05,
	CloudColor = Color3.fromRGB(255, 255, 255),
	CloudCover = 0.3,
	WarmLights = false,
	CityLights = false,
}

local Hapon: Preset = {
	Id = "Hapon",
	Label = "Hapon",
	Icon = "🌇",
	ClockTime = 17.75,
	Brightness = 2,
	OutdoorAmbient = Color3.fromRGB(150, 128, 140),
	Ambient = Color3.fromRGB(60, 50, 62),
	Atmosphere = {
		Density = 0.36,
		Offset = 0.05,
		Color = Color3.fromRGB(236, 150, 148),
		Decay = Color3.fromRGB(118, 104, 146),
		Glare = 0.25,
		Haze = 1.2,
	},
	Tint = Color3.fromRGB(255, 238, 232),
	Saturation = 0.08,
	CloudColor = Color3.fromRGB(255, 214, 214),
	CloudCover = 0.42,
	WarmLights = true,
	CityLights = false,
}

local Gabi: Preset = {
	Id = "Gabi",
	Label = "Gabi",
	Icon = "🌙",
	ClockTime = 19.6,
	Brightness = 1,
	OutdoorAmbient = Color3.fromRGB(74, 66, 102),
	Ambient = Color3.fromRGB(34, 30, 48),
	Atmosphere = {
		-- Thinner haze than day so the city lights show through.
		Density = 0.2,
		Offset = 0,
		Color = Color3.fromRGB(80, 66, 108),
		Decay = Color3.fromRGB(44, 44, 82),
		Glare = 0,
		Haze = 0.6,
	},
	Tint = Color3.fromRGB(226, 220, 255),
	Saturation = 0.1,
	CloudColor = Color3.fromRGB(122, 102, 142),
	CloudCover = 0.35,
	WarmLights = true,
	CityLights = true,
}

local TimeOfDay = {
	Default = "Hapon",
	Order = { "Umaga", "Hapon", "Gabi" },
	Presets = {
		Umaga = Umaga,
		Hapon = Hapon,
		Gabi = Gabi,
	} :: { [string]: Preset },
}

return TimeOfDay
