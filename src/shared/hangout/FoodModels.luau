--!strict
-- Shared 3D food & drink model builder used by both FoodStallService (for held Tools)
-- and FoodStallController (for live 3D ViewportFrame previews in the store menu).

local FoodStalls = require(script.Parent.FoodStalls)

type MenuItem = FoodStalls.MenuItem

local FoodModels = {}

local function part(name: string, size: Vector3, color: Color3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CFrame = cf
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function cylinder(name: string, height: number, width: number, color: Color3, y: number): Part
	local p = part(
		name,
		Vector3.new(height, width, width),
		color,
		CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90))
	)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function FoodModels.buildParts(item: MenuItem): (Part, { Part })
	local handle = part("Handle", Vector3.new(0.4, 0.4, 0.4), Color3.new(1, 1, 1), CFrame.new())
	handle.Transparency = 1

	local pieces: { Part } = {}

	if item.Kind == "Shake" then
		local cup = cylinder("Cup", 1.1, 0.72, item.PrimaryColor, 0)
		cup.Transparency = 0.08
		local top =
			part("Cream", Vector3.new(0.66, 0.34, 0.66), item.AccentColor, CFrame.new(0, 0.62, 0))
		top.Shape = Enum.PartType.Ball
		local lid = cylinder("Lid", 0.08, 0.76, Color3.fromRGB(248, 248, 248), 0.56)
		lid.Transparency = 0.35
		local straw = cylinder("Straw", 0.95, 0.1, Color3.fromRGB(255, 248, 236), 0.95)
		straw.CFrame = CFrame.new(0.1, 0.95, 0) * CFrame.Angles(0, 0, math.rad(82))
		pieces = { cup, top, lid, straw }
	elseif item.Kind == "MilkTea" then
		local cup = cylinder("Cup", 1.1, 0.7, item.PrimaryColor, 0)
		cup.Transparency = 0.1
		local pearls = cylinder("Pearls", 0.28, 0.66, Color3.fromRGB(42, 26, 20), -0.4)
		local foam = cylinder("Foam", 0.18, 0.68, item.AccentColor, 0.46)
		local lid = cylinder("Lid", 0.08, 0.74, Color3.fromRGB(246, 246, 246), 0.58)
		lid.Transparency = 0.3
		local straw = cylinder("Straw", 0.95, 0.12, Color3.fromRGB(48, 36, 32), 0.95)
		straw.CFrame = CFrame.new(0.12, 0.95, 0) * CFrame.Angles(0, 0, math.rad(80))
		pieces = { cup, pearls, foam, lid, straw }
	elseif item.Kind == "Pizza" then
		local plate = cylinder("Plate", 0.06, 1.35, Color3.fromRGB(246, 244, 238), -0.05)
		local crust = part(
			"Crust",
			Vector3.new(1.05, 0.14, 0.22),
			Color3.fromRGB(204, 146, 78),
			CFrame.new(0, 0.05, 0.45)
		)
		local cheese = part(
			"Cheese",
			Vector3.new(0.95, 0.1, 0.9),
			item.PrimaryColor,
			CFrame.new(0, 0.04, -0.05)
		)
		local t1 = cylinder("Top1", 0.04, 0.24, item.AccentColor, 0.1)
		t1.CFrame = CFrame.new(-0.2, 0.1, 0.05) * CFrame.Angles(0, 0, math.rad(90))
		local t2 = cylinder("Top2", 0.04, 0.24, item.AccentColor, 0.1)
		t2.CFrame = CFrame.new(0.2, 0.1, -0.15) * CFrame.Angles(0, 0, math.rad(90))
		local t3 = cylinder("Top3", 0.04, 0.22, item.AccentColor, 0.1)
		t3.CFrame = CFrame.new(0.02, 0.1, 0.22) * CFrame.Angles(0, 0, math.rad(90))
		pieces = { plate, crust, cheese, t1, t2, t3 }
	elseif item.Kind == "Skewer" then
		local stick = cylinder("Stick", 1.9, 0.07, Color3.fromRGB(224, 194, 142), 0.45)
		local m1 =
			part("Meat1", Vector3.new(0.36, 0.34, 0.28), item.PrimaryColor, CFrame.new(0, 0.45, 0))
		local m2 =
			part("Meat2", Vector3.new(0.38, 0.34, 0.3), item.AccentColor, CFrame.new(0, 0.82, 0))
		local m3 =
			part("Meat3", Vector3.new(0.34, 0.32, 0.26), item.PrimaryColor, CFrame.new(0, 1.18, 0))
		pieces = { stick, m1, m2, m3 }
	elseif item.Kind == "Fries" then
		local box =
			part("Carton", Vector3.new(0.74, 0.82, 0.44), item.AccentColor, CFrame.new(0, 0.05, 0))
		pieces = { box }
		for i = -2, 2 do
			local fry = part(
				`Fry{i}`,
				Vector3.new(0.11, 0.62 + (math.abs(i) % 2) * 0.14, 0.11),
				item.PrimaryColor,
				CFrame.new(i * 0.13, 0.56, (i % 2) * 0.06) * CFrame.Angles(0, 0, math.rad(i * -4))
			)
			table.insert(pieces, fry)
		end
	elseif item.Kind == "Shawarma" then
		local foil = cylinder("Foil", 0.65, 0.54, Color3.fromRGB(228, 232, 236), -0.18)
		local pita = cylinder("Pita", 0.72, 0.5, item.PrimaryColor, 0.36)
		local filling =
			part("Filling", Vector3.new(0.42, 0.22, 0.42), item.AccentColor, CFrame.new(0, 0.72, 0))
		filling.Shape = Enum.PartType.Ball
		local lettuce = part(
			"Lettuce",
			Vector3.new(0.36, 0.14, 0.36),
			Color3.fromRGB(118, 184, 86),
			CFrame.new(0.08, 0.78, 0.04)
		)
		pieces = { foil, pita, filling, lettuce }
	else -- Siomai
		local cup = cylinder("Cup", 0.62, 0.74, Color3.fromRGB(244, 240, 232), -0.05)
		local s1 = part(
			"Siomai1",
			Vector3.new(0.32, 0.28, 0.32),
			item.PrimaryColor,
			CFrame.new(-0.15, 0.34, -0.08)
		)
		local s2 = part(
			"Siomai2",
			Vector3.new(0.32, 0.28, 0.32),
			item.PrimaryColor,
			CFrame.new(0.15, 0.34, -0.08)
		)
		local s3 = part(
			"Siomai3",
			Vector3.new(0.32, 0.28, 0.32),
			item.PrimaryColor,
			CFrame.new(0, 0.34, 0.16)
		)
		local chili =
			part("Chili", Vector3.new(0.2, 0.08, 0.2), item.AccentColor, CFrame.new(0, 0.49, 0.12))
		local pick = cylinder("Toothpick", 0.75, 0.05, Color3.fromRGB(232, 206, 158), 0.62)
		pick.CFrame = CFrame.new(0.12, 0.62, 0) * CFrame.Angles(0, 0, math.rad(72))
		pieces = { cup, s1, s2, s3, chili, pick }
	end

	return handle, pieces
end

return FoodModels
