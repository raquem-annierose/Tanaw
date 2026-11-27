--!strict
-- Menu definitions for the 6 hilltop street-food stalls in Overlook.Stalls.
-- Each stall has 2 signature items; players can hold at most 1 of each item
-- and consuming it (3 bites/sips) removes it from their inventory.

export type FoodKind = "Shake" | "MilkTea" | "Pizza" | "Skewer" | "Fries" | "Shawarma" | "Siomai"

export type MenuItem = {
	Id: string,
	Name: string,
	Description: string,
	Kind: FoodKind,
	IsDrink: boolean,
	PrimaryColor: Color3,
	AccentColor: Color3,
	Bites: number,
}

export type StallDef = {
	ModelName: string,
	Title: string,
	Tagline: string,
	Accent: Color3,
	Items: { MenuItem },
}

local STALLS: { StallDef } = {
	{
		ModelName = "Shake",
		Title = "Prutas Shake",
		Tagline = "Fresh blended fruit shakes",
		Accent = Color3.fromRGB(132, 196, 86),
		Items = {
			{
				Id = "MangoGrahamShake",
				Name = "Mango Graham Shake",
				Description = "Sweet ripe mango topped with crushed graham & cream",
				Kind = "Shake",
				IsDrink = true,
				PrimaryColor = Color3.fromRGB(255, 204, 72),
				AccentColor = Color3.fromRGB(232, 186, 128),
				Bites = 3,
			},
			{
				Id = "AvocadoShake",
				Name = "Avocado Cream Shake",
				Description = "Rich creamy avocado blended cold with condensed milk",
				Kind = "Shake",
				IsDrink = true,
				PrimaryColor = Color3.fromRGB(162, 208, 120),
				AccentColor = Color3.fromRGB(246, 244, 232),
				Bites = 3,
			},
		},
	},
	{
		ModelName = "Pizza",
		Title = "Pizza sa Taas",
		Tagline = "Hot oven-baked slices",
		Accent = Color3.fromRGB(224, 68, 56),
		Items = {
			{
				Id = "PepperoniSlice",
				Name = "Cheesy Pepperoni",
				Description = "Crispy crust loaded with melted cheese & pepperoni",
				Kind = "Pizza",
				IsDrink = false,
				PrimaryColor = Color3.fromRGB(246, 196, 84),
				AccentColor = Color3.fromRGB(186, 46, 42),
				Bites = 3,
			},
			{
				Id = "HawaiianSlice",
				Name = "Hawaiian Overload",
				Description = "Sweet golden pineapple & smoky ham on thick cheese",
				Kind = "Pizza",
				IsDrink = false,
				PrimaryColor = Color3.fromRGB(250, 208, 96),
				AccentColor = Color3.fromRGB(238, 146, 140),
				Bites = 3,
			},
		},
	},
	{
		ModelName = "MilkTea",
		Title = "Tsaa Tayo · Milk Tea",
		Tagline = "Brewed fresh with chewy pearls",
		Accent = Color3.fromRGB(226, 174, 114),
		Items = {
			{
				Id = "WintermelonTea",
				Name = "Wintermelon Pearl",
				Description = "Smooth caramel wintermelon tea with warm boba",
				Kind = "MilkTea",
				IsDrink = true,
				PrimaryColor = Color3.fromRGB(214, 174, 134),
				AccentColor = Color3.fromRGB(52, 34, 24),
				Bites = 3,
			},
			{
				Id = "OkinawaTea",
				Name = "Okinawa Brown Sugar",
				Description = "Roasted brown sugar milk tea with silky cream cap",
				Kind = "MilkTea",
				IsDrink = true,
				PrimaryColor = Color3.fromRGB(184, 132, 92),
				AccentColor = Color3.fromRGB(248, 242, 230),
				Bites = 3,
			},
		},
	},
	{
		ModelName = "Ihaw",
		Title = "Ihaw-Ihaw",
		Tagline = "Charcoal-grilled hilltop classics",
		Accent = Color3.fromRGB(244, 128, 36),
		Items = {
			{
				Id = "PorkBBQ",
				Name = "Pork BBQ Skewer",
				Description = "Sweet-savory marinated pork glazed over hot coals",
				Kind = "Skewer",
				IsDrink = false,
				PrimaryColor = Color3.fromRGB(154, 64, 34),
				AccentColor = Color3.fromRGB(218, 118, 48),
				Bites = 3,
			},
			{
				Id = "IsawStick",
				Name = "Classic Isaw Stick",
				Description = "Smoky grilled street-style skewer with spiced glaze",
				Kind = "Skewer",
				IsDrink = false,
				PrimaryColor = Color3.fromRGB(178, 92, 46),
				AccentColor = Color3.fromRGB(122, 54, 28),
				Bites = 3,
			},
		},
	},
	{
		ModelName = "FriesShawarma",
		Title = "Fries & Shawarma",
		Tagline = "Crispy bites & savory wraps",
		Accent = Color3.fromRGB(238, 186, 44),
		Items = {
			{
				Id = "CheeseFries",
				Name = "Cheese Overload Fries",
				Description = "Golden crispy fries drenched in warm cheddar sauce",
				Kind = "Fries",
				IsDrink = false,
				PrimaryColor = Color3.fromRGB(248, 202, 74),
				AccentColor = Color3.fromRGB(212, 48, 44),
				Bites = 3,
			},
			{
				Id = "BeefShawarma",
				Name = "Beef Shawarma Wrap",
				Description = "Spiced roasted beef & garlic sauce in warm pita",
				Kind = "Shawarma",
				IsDrink = false,
				PrimaryColor = Color3.fromRGB(228, 198, 154),
				AccentColor = Color3.fromRGB(132, 74, 46),
				Bites = 3,
			},
		},
	},
	{
		ModelName = "Siomai",
		Title = "Siomai sa Tanaw",
		Tagline = "Steaming hot with chili garlic",
		Accent = Color3.fromRGB(186, 36, 42),
		Items = {
			{
				Id = "PorkSiomai",
				Name = "Pork Siomai Cup",
				Description = "3 steamed pork dumplings with calamansi & soy",
				Kind = "Siomai",
				IsDrink = false,
				PrimaryColor = Color3.fromRGB(244, 212, 134),
				AccentColor = Color3.fromRGB(236, 236, 236),
				Bites = 3,
			},
			{
				Id = "ChiliBeefSiomai",
				Name = "Chili Beef Siomai",
				Description = "Savory beef siomai topped with crunchy chili garlic",
				Kind = "Siomai",
				IsDrink = false,
				PrimaryColor = Color3.fromRGB(238, 198, 122),
				AccentColor = Color3.fromRGB(196, 42, 34),
				Bites = 3,
			},
		},
	},
}

local byStall: { [string]: StallDef } = {}
local byItem: { [string]: MenuItem } = {}
for _, stall in STALLS do
	byStall[stall.ModelName] = stall
	for _, item in stall.Items do
		byItem[item.Id] = item
	end
end

local FoodStalls = {
	List = STALLS,
	ByStall = byStall,
	ByItem = byItem,
	PromptDistance = 12,
	OrderDistance = 20,
	BiteCooldown = 1.35,
}

return FoodStalls

