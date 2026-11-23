--!nonstrict
-- Admin panel UI (F2 / crown button in the top bar), plus FPS and ping pills for admins.
--
-- Lives in ServerStorage; AdminPanelService copies it into an admin's PlayerGui only, so other
-- players never get this code. The server checks every action again, so changing this script
-- can't give anyone extra powers.
--
-- Want your own logos? Replace any value in ICONS below with an image like
-- "rbxassetid://1234567890" and it is used instead of the emoji.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local remote = Remotes.adminPanel()
local playerGui = player:WaitForChild("PlayerGui")

---------------------------------------------------------------------
-- Theme / icons
---------------------------------------------------------------------
local C = {
	bg = Color3.fromRGB(6, 14, 38),
	side = Color3.fromRGB(5, 11, 30),
	panel = Color3.fromRGB(10, 22, 58),
	item = Color3.fromRGB(16, 34, 86),
	line = Color3.fromRGB(30, 78, 168),
	accent = Color3.fromRGB(28, 124, 255),
	accent2 = Color3.fromRGB(0, 212, 255),
	danger = Color3.fromRGB(226, 38, 72),
	good = Color3.fromRGB(18, 200, 126),
	warn = Color3.fromRGB(245, 166, 35),
	text = Color3.fromRGB(255, 255, 255),
	sub = Color3.fromRGB(150, 176, 226),
}

local LEVEL_NAMES = { "Moderator", "Admin", "Owner" }
local LEVEL_ICONS = { "🛡️", "⚔️", "👑" }
local LEVEL_COLORS = {
	Color3.fromRGB(79, 163, 255),
	Color3.fromRGB(255, 140, 66),
	Color3.fromRGB(255, 201, 77),
}

local ICONS = {
	logo = "👑",
	home = "🏠",
	players = "👥",
	events = "🎉",
	roles = "🎭",
	server = "🎮",
	announce = "📢",
	bans = "🛡️",
	logs = "📄",
	settings = "⚙️",
	countdown = "⏱️",
	sounds = "🔊",
	poll = "📊",
	morph = "🧬",
}

---------------------------------------------------------------------
-- UI helpers
---------------------------------------------------------------------
local function new(class, props, children)
	local inst = Instance.new(class)
	for k, v in props do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 8) })
end

local function pad(l, t, r, b)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, l),
		PaddingTop = UDim.new(0, t or l),
		PaddingRight = UDim.new(0, r or l),
		PaddingBottom = UDim.new(0, b or t or l),
	})
end

local function stroke(color, thickness, transparency)
	return new("UIStroke", {
		Color = color or C.line,
		Thickness = thickness or 1,
		Transparency = transparency or 0.3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function gradient(parent, a, b, rotation)
	return new(
		"UIGradient",
		{ Color = ColorSequence.new(a, b), Rotation = rotation or 90, Parent = parent }
	)
end

local function isImage(s)
	return type(s) == "string"
		and (
			string.find(s, "rbxassetid://", 1, true) ~= nil
			or string.find(s, "rbxthumb://", 1, true) ~= nil
		)
end

local function thumb(userId)
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId)
end

local function hexColor(h)
	h = string.gsub(tostring(h or ""), "#", "")
	if #h ~= 6 then
		return C.accent
	end
	local r, g, b =
		tonumber(string.sub(h, 1, 2), 16),
		tonumber(string.sub(h, 3, 4), 16),
		tonumber(string.sub(h, 5, 6), 16)
	if not (r and g and b) then
		return C.accent
	end
	return Color3.fromRGB(r, g, b)
end

-- Emoji or image icon (works with rbxassetid:// strings)
local function icon(parent, glyph, size, props)
	props = props or {}
	if isImage(glyph) then
		return new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = glyph,
			Size = UDim2.fromOffset(size, size),
			Position = props.Position or UDim2.new(),
			LayoutOrder = props.LayoutOrder or 0,
			Parent = parent,
		})
	end
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = glyph,
		Font = Enum.Font.GothamBold,
		TextSize = math.floor(size * 0.8),
		TextColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(size, size),
		Position = props.Position or UDim2.new(),
		LayoutOrder = props.LayoutOrder or 0,
		Parent = parent,
	})
end

local function label(parent, text, size, props)
	props = props or {}
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		Font = props.Font or Enum.Font.Gotham,
		TextSize = props.TextSize or 13,
		TextColor3 = props.Color or C.sub,
		TextXAlignment = props.Align or Enum.TextXAlignment.Left,
		TextYAlignment = props.YAlign or Enum.TextYAlignment.Center,
		TextWrapped = props.Wrap ~= false,
		TextTruncate = props.Truncate or Enum.TextTruncate.None,
		Size = size,
		Position = props.Position or UDim2.new(),
		AutomaticSize = props.AutomaticSize or Enum.AutomaticSize.None,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = parent,
	})
end

local function textOn(color)
	local lum = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	return lum > 0.62 and Color3.fromRGB(20, 24, 34) or Color3.new(1, 1, 1)
end

local function button(parent, text, color, callback, props)
	props = props or {}
	local base = color or C.item
	local b = new("TextButton", {
		Text = text,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = textOn(base),
		BackgroundColor3 = base,
		AutoButtonColor = false,
		Size = props.Size or UDim2.new(0, 120, 0, 34),
		Position = props.Position or UDim2.new(),
		LayoutOrder = props.LayoutOrder or 0,
		Parent = parent,
	}, { corner(9), stroke(base:Lerp(Color3.new(1, 1, 1), 0.45), 1, 0.55) })
	new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 205)),
		Rotation = 90,
		Parent = b,
	})
	b.MouseEnter:Connect(function()
		TweenService
			:Create(
				b,
				TweenInfo.new(0.12),
				{ BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), 0.2) }
			)
			:Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = base }):Play()
	end)
	b.MouseButton1Click:Connect(callback)
	return b
end

local function textbox(parent, placeholder, size, props)
	props = props or {}
	local multi = props.MultiLine == true
	return new("TextBox", {
		PlaceholderText = placeholder,
		Text = "",
		PlaceholderColor3 = C.sub,
		TextColor3 = C.text,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		ClearTextOnFocus = false,
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.15,
		Size = size,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = multi and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
		MultiLine = multi,
		TextWrapped = multi,
		Position = props.Position or UDim2.new(),
		LayoutOrder = props.LayoutOrder or 0,
		Parent = parent,
	}, { corner(9), pad(10, multi and 10 or 0), stroke(C.line, 1, 0.35) })
end

local function scroller(parent)
	return new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.line,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = parent,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		pad(0, 0, 8, 6),
	})
end

local function card(parent, order, title)
	local f = new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order or 0,
		Parent = parent,
	}, {
		corner(12),
		stroke(C.accent, 1.2, 0.5),
		pad(14, 12),
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	new("UIGradient", {
		Color = ColorSequence.new(
			C.panel:Lerp(C.accent, 0.07),
			C.panel:Lerp(Color3.new(0, 0, 0), 0.25)
		),
		Rotation = 90,
		Parent = f,
	})
	if title then
		label(f, title, UDim2.new(1, 0, 0, 20), {
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			Color = C.text,
			LayoutOrder = 0,
		})
	end
	return f
end

-- Row that wraps onto new lines when there isn't enough room (responsive forms)
local function wrapRow(parent, order)
	return new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order or 0,
		Parent = parent,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = true,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

-- Grid of fixed-size cells that re-flows to the available width
local function grid(parent, order, cellW, cellH)
	return new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order or 0,
		Parent = parent,
	}, {
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(cellW, cellH),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

local function clearChildren(parent)
	for _, c in parent:GetChildren() do
		if not c:IsA("UIListLayout") and not c:IsA("UIGridLayout") and not c:IsA("UIPadding") then
			c:Destroy()
		end
	end
end

---------------------------------------------------------------------
-- Themes
---------------------------------------------------------------------
local THEMES = {
	{
		name = "Neon",
		c = {
			bg = "060E26",
			side = "050B1E",
			panel = "0A163A",
			item = "102256",
			line = "1E4EA8",
			accent = "1C7CFF",
			accent2 = "00D4FF",
			text = "FFFFFF",
			sub = "96B0E2",
		},
	},
	{
		name = "Midnight",
		c = {
			bg = "161820",
			side = "11131A",
			panel = "202330",
			item = "2C303F",
			line = "3A3F52",
			accent = "5E81FF",
			accent2 = "9662FF",
			text = "F0F2F9",
			sub = "929AAF",
		},
	},
	{
		name = "Ocean",
		c = {
			bg = "0E1A24",
			side = "0A131B",
			panel = "15283A",
			item = "1E3A52",
			line = "2B5272",
			accent = "2DA8F0",
			accent2 = "28D9C0",
			text = "EAF6FF",
			sub = "88A9C2",
		},
	},
	{
		name = "Forest",
		c = {
			bg = "121A15",
			side = "0D130F",
			panel = "1B2A21",
			item = "25392D",
			line = "36533F",
			accent = "2FB878",
			accent2 = "8FCB2A",
			text = "EAF7EF",
			sub = "8DB09C",
		},
	},
	{
		name = "Sunset",
		c = {
			bg = "1F1416",
			side = "170E10",
			panel = "2D1B1F",
			item = "3B262B",
			line = "573640",
			accent = "F26A47",
			accent2 = "F2A93B",
			text = "FFF1EC",
			sub = "C79A92",
		},
	},
	{
		name = "Rose",
		c = {
			bg = "1E1219",
			side = "160D13",
			panel = "2C1A25",
			item = "3B2433",
			line = "573449",
			accent = "F0488C",
			accent2 = "B46EF0",
			text = "FFEEF6",
			sub = "C795B1",
		},
	},
	{
		name = "Cyber",
		c = {
			bg = "0A0A14",
			side = "06060D",
			panel = "13132A",
			item = "1C1C3D",
			line = "2E2E66",
			accent = "00C8D8",
			accent2 = "E025B8",
			text = "E8FBFF",
			sub = "7F8BC9",
		},
	},
	{
		name = "Mono",
		c = {
			bg = "1A1A1A",
			side = "121212",
			panel = "252525",
			item = "303030",
			line = "444444",
			accent = "7C7C7C",
			accent2 = "AAAAAA",
			text = "FFFFFF",
			sub = "9A9A9A",
		},
	},
	{
		name = "Light",
		c = {
			bg = "EEF1F6",
			side = "E0E5EE",
			panel = "FFFFFF",
			item = "E6EAF2",
			line = "C9D1E0",
			accent = "3B6EF5",
			accent2 = "8B5CF6",
			text = "1B2230",
			sub = "66708A",
		},
	},
	{
		name = "Dracula",
		c = {
			bg = "1E1F29",
			side = "191A23",
			panel = "282A36",
			item = "343746",
			line = "44475A",
			accent = "A57FF0",
			accent2 = "F068B8",
			text = "F8F8F2",
			sub = "8A91B5",
		},
	},
	{
		name = "Nord",
		c = {
			bg = "232831",
			side = "1D222A",
			panel = "2E3440",
			item = "3B4252",
			line = "4C566A",
			accent = "6FA9BC",
			accent2 = "7794B8",
			text = "ECEFF4",
			sub = "8F9BB3",
		},
	},
	{
		name = "Lavender",
		c = {
			bg = "1A1726",
			side = "130F1D",
			panel = "251F38",
			item = "322A4B",
			line = "483E6B",
			accent = "9370F0",
			accent2 = "D67BEB",
			text = "F3EEFF",
			sub = "A59BC9",
		},
	},
	{
		name = "Crimson",
		c = {
			bg = "1A1012",
			side = "130B0D",
			panel = "291619",
			item = "361F23",
			line = "54303A",
			accent = "D92D30",
			accent2 = "F0607E",
			text = "FFEFEF",
			sub = "BF8F94",
		},
	},
	{
		name = "Gold",
		c = {
			bg = "1B1810",
			side = "14120B",
			panel = "292317",
			item = "372F1E",
			line = "524626",
			accent = "E8A800",
			accent2 = "F5D04A",
			text = "FFF8E1",
			sub = "B8AA7F",
		},
	},
	{
		name = "Mint",
		c = {
			bg = "101A19",
			side = "0B1312",
			panel = "172826",
			item = "203735",
			line = "2E524F",
			accent = "20B8A4",
			accent2 = "6FE09A",
			text = "E8FFFB",
			sub = "86B5AE",
		},
	},
	{
		name = "Coffee",
		c = {
			bg = "1C1512",
			side = "15100D",
			panel = "2A201B",
			item = "382C25",
			line = "52413A",
			accent = "B87A45",
			accent2 = "D9A872",
			text = "F7EBDD",
			sub = "B79F8C",
		},
	},
	{
		name = "AMOLED",
		c = {
			bg = "000000",
			side = "000000",
			panel = "0E0E12",
			item = "18181F",
			line = "2A2A36",
			accent = "5E81FF",
			accent2 = "9662FF",
			text = "FFFFFF",
			sub = "8A8FA3",
		},
	},
	{
		name = "Candy",
		c = {
			bg = "201826",
			side = "17101D",
			panel = "2E2238",
			item = "3C2D4A",
			line = "5A4570",
			accent = "F060B4",
			accent2 = "5EC8F0",
			text = "FFF0FA",
			sub = "C7A6D6",
		},
	},
	{
		name = "Matrix",
		c = {
			bg = "050B07",
			side = "030805",
			panel = "0B1A10",
			item = "112A19",
			line = "1D4A2B",
			accent = "00C850",
			accent2 = "86D400",
			text = "D6FFE6",
			sub = "5FA877",
		},
	},
}

local currentTheme = "Neon"
local function applyTheme(name)
	for _, t in THEMES do
		if t.name == name then
			for key, hex in t.c do
				C[key] = hexColor(hex)
			end
			currentTheme = name
			return true
		end
	end
	return false
end

local prefs: { [string]: any } = {} -- { theme, scale } saved on the server for this admin
local requestRebuild -- assigned at the bottom
local current -- the live UI handle
local onVisibility -- set by the top bar button

---------------------------------------------------------------------
-- The whole UI lives in build() so it can be rebuilt when your level changes
---------------------------------------------------------------------
local function build(LEVEL, cfg, startOpen, startPage)
	local conns = {}
	local alive = true
	local function track(c)
		table.insert(conns, c)
		return c
	end

	local gui = new("ScreenGui", {
		Name = "AdminPanelUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 100,
		Parent = playerGui,
	})

	-- Everything lives inside `root`, which is scaled to fit the device (phones get a smaller UI).
	local root = new("Frame", {
		Name = "Root",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local rootScale = new("UIScale", { Scale = 1, Parent = root })
	local function updateRootScale()
		local vp = gui.AbsoluteSize
		if vp.X < 10 then
			vp = Vector2.new(1280, 720)
		end
		local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		local base = math.min(vp.X / 1000, vp.Y / 640)
		local s = math.clamp(base, touch and 0.72 or 0.55, 1) * (prefs.scale or 1)
		rootScale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end

	-- Toast ------------------------------------------------------------
	local toast = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = C.good,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextWrapped = true,
		Text = "",
		Visible = false,
		ZIndex = 100,
		Parent = root,
	}, {
		corner(10),
		pad(16, 10),
		stroke(Color3.new(0, 0, 0), 1, 0.6),
		new("UISizeConstraint", { MaxSize = Vector2.new(460, 300) }),
	})
	local toastId = 0

	local function notify(msg, isError)
		toastId += 1
		local id = toastId
		toast.Text = (isError and "⚠️  " or "✅  ") .. tostring(msg)
		toast.BackgroundColor3 = isError and C.danger or C.good
		toast.Visible = true
		task.delay(3, function()
			if toastId == id then
				toast.Visible = false
			end
		end)
	end

	local function act(action, ...)
		local ok, success, result = pcall(remote.InvokeServer, remote, action, ...)
		if not ok then
			notify("Request failed.", true)
			return false
		end
		if type(result) == "string" then
			notify(result, not success)
		end
		return success, result
	end

	-- Window -----------------------------------------------------------
	local WHITE = Color3.new(1, 1, 1)
	local HEADER_H = 80
	local main = new("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.96, 0.92),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Visible = false,
		Parent = root,
	}, {
		corner(18),
		new(
			"UISizeConstraint",
			{ MinSize = Vector2.new(300, 240), MaxSize = Vector2.new(1040, 660) }
		),
	})
	gradient(main, C.bg:Lerp(C.accent, 0.08), C.bg:Lerp(Color3.new(0, 0, 0), 0.25), 90)
	do
		local ms = stroke(C.accent2, 2, 0.05)
		ms.Parent = main
		new(
			"UIGradient",
			{ Color = ColorSequence.new(C.accent2, C.accent), Rotation = 35, Parent = ms }
		)
	end
	local pop = new("UIScale", { Scale = 1, Parent = main })
	updateRootScale()
	track(gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateRootScale))

	-- Header (logo, title, user card, server info, settings, close) ---------
	local levelColor = LEVEL_COLORS[LEVEL] or C.accent
	local header = new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER_H),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Parent = main,
	}, { corner(18) })
	gradient(header, C.panel:Lerp(C.accent, 0.16), C.side, 0)
	local headerFill = new("Frame", {
		Position = UDim2.new(0, 0, 1, -20),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		Parent = header,
	})
	gradient(headerFill, C.panel:Lerp(C.accent, 0.16), C.side, 0)
	new("Frame", {
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = C.accent,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = header,
	})

	icon(header, ICONS.logo, 46, { Position = UDim2.new(0, 16, 0.5, -23) })
	local titleBox = new("Frame", {
		Position = UDim2.new(0, 72, 0, 0),
		Size = UDim2.new(0, 330, 1, 0),
		BackgroundTransparency = 1,
		Parent = header,
	})
	local title = label(titleBox, "", UDim2.new(1, 0, 0, 38), {
		Font = Enum.Font.GothamBlack,
		TextSize = 30,
		Color = C.text,
		Position = UDim2.new(0, 0, 0, 10),
		Wrap = false,
	})
	title.RichText = true
	title.Text =
		string.format('<i>ADMIN</i> <font color="#%s"><i>PANEL</i></font>', C.accent:ToHex())
	local subtitle =
		label(titleBox, "Control  •  Manage  •  Keep Your Game Safe", UDim2.new(1, 0, 0, 18), {
			TextSize = 13,
			Color = C.sub,
			Position = UDim2.new(0, 2, 0, 48),
			Wrap = false,
		})

	local closeBtn = button(header, "✕", C.item, function()
		main.Visible = false
	end, { Size = UDim2.fromOffset(38, 38) })
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.Position = UDim2.new(1, -16, 0.5, 0)
	closeBtn.TextSize = 16
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(1, 0)

	local gearBtn = button(
		header,
		"⚙️",
		C.item,
		function() end,
		{ Size = UDim2.fromOffset(44, 44) }
	)
	gearBtn.AnchorPoint = Vector2.new(1, 0.5)
	gearBtn.Position = UDim2.new(1, -64, 0.5, 0)
	gearBtn.TextSize = 22

	local serverPill = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -118, 0.5, 0),
		Size = UDim2.fromOffset(158, 46),
		BackgroundColor3 = C.item,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = header,
	}, { corner(10), stroke(C.accent, 1, 0.45) })
	new("Frame", {
		Position = UDim2.new(0, 12, 0.5, -6),
		Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Color3.fromRGB(24, 224, 130),
		BorderSizePixel = 0,
		Parent = serverPill,
	}, { corner(6) })
	local jobShort = game.JobId ~= "" and string.sub(game.JobId, 1, 5) or "Studio"
	label(serverPill, "Server: " .. jobShort, UDim2.new(1, -40, 0, 18), {
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Color = C.text,
		Position = UDim2.new(0, 36, 0, 6),
		Wrap = false,
	})
	local serverPlayers = label(serverPill, "", UDim2.new(1, -40, 0, 18), {
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Color = C.text,
		Position = UDim2.new(0, 36, 0, 23),
		Wrap = false,
	})

	local userCard = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -286, 0.5, 0),
		Size = UDim2.fromOffset(176, 54),
		BackgroundTransparency = 1,
		Parent = header,
	})
	new("ImageLabel", {
		Position = UDim2.new(0, 0, 0.5, -24),
		Size = UDim2.fromOffset(48, 48),
		BackgroundColor3 = C.item,
		Image = thumb(player.UserId),
		Parent = userCard,
	}, { corner(24), stroke(levelColor, 2, 0.1) })
	label(userCard, player.Name, UDim2.new(1, -56, 0, 20), {
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		Color = C.text,
		Position = UDim2.new(0, 56, 0, 8),
		Wrap = false,
		Truncate = Enum.TextTruncate.AtEnd,
	})
	label(
		userCard,
		(LEVEL_ICONS[LEVEL] or "") .. " " .. (LEVEL_NAMES[LEVEL] or "Admin"),
		UDim2.new(1, -56, 0, 16),
		{
			TextSize = 12,
			Color = levelColor,
			Position = UDim2.new(0, 56, 0, 29),
			Wrap = false,
		}
	)

	task.spawn(function()
		while alive do
			serverPlayers.Text = "Players: " .. #Players:GetPlayers() .. " / " .. Players.MaxPlayers
			task.wait(2)
		end
	end)

	-- Sidebar ------------------------------------------------------------
	local SIDE_W = 190
	local sidebar = new("Frame", {
		Position = UDim2.new(0, 0, 0, HEADER_H),
		Size = UDim2.new(0, SIDE_W, 1, -HEADER_H),
		BackgroundColor3 = C.side,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Parent = main,
	}, { corner(18) })
	-- square off the top and right edges of the sidebar
	new("Frame", {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundColor3 = C.side,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Parent = sidebar,
	})
	new("Frame", {
		Size = UDim2.new(0, 24, 1, 0),
		Position = UDim2.new(1, -24, 0, 0),
		BackgroundColor3 = C.side,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		Parent = sidebar,
	})
	new("Frame", {
		Size = UDim2.new(0, 1, 1, 0),
		Position = UDim2.new(1, -1, 0, 0),
		BackgroundColor3 = C.accent,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Parent = sidebar,
	})

	local navList = new("ScrollingFrame", {
		Position = UDim2.new(0, 10, 0, 14),
		Size = UDim2.new(1, -20, 1, -54),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.line,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = sidebar,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local keyName = cfg.toggleKey or "F2"
	local hint = label(sidebar, "", UDim2.new(1, -16, 0, 26), {
		Position = UDim2.new(0, 8, 1, -34),
		Align = Enum.TextXAlignment.Center,
		TextSize = 11,
		Color = C.sub,
	})

	-- Body ---------------------------------------------------------------
	local body = new("Frame", {
		Position = UDim2.new(0, SIDE_W, 0, HEADER_H),
		Size = UDim2.new(1, -SIDE_W, 1, -HEADER_H),
		BackgroundTransparency = 1,
		Parent = main,
	})

	-- Slim page title bar (hidden on the Overview page, like the design)
	local topbar = new("Frame", {
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = body,
	})
	local pageTitle = label(topbar, "", UDim2.new(1, -30, 0, 24), {
		Font = Enum.Font.GothamBold,
		TextSize = 19,
		Color = C.text,
		Position = UDim2.new(0, 16, 0, 6),
		Wrap = false,
		Truncate = Enum.TextTruncate.AtEnd,
	})
	local pageSub = label(topbar, "", UDim2.new(1, -30, 0, 16), {
		TextSize = 12,
		Position = UDim2.new(0, 16, 0, 30),
		Wrap = false,
		Truncate = Enum.TextTruncate.AtEnd,
	})
	local pagesHolder = new("Frame", {
		Position = UDim2.new(0, 12, 0, 12),
		Size = UDim2.new(1, -24, 1, -22),
		BackgroundTransparency = 1,
		Parent = body,
	})

	-- Dragging (grab the header) ---------------------------------------------
	do
		local dragging, dragStart, startPos
		header.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				dragging = true
				dragStart = input.Position
				startPos = main.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
					end
				end)
			end
		end)
		track(UserInputService.InputChanged:Connect(function(input)
			if
				dragging
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				local d = (input.Position - dragStart) / (pop.Scale * rootScale.Scale)
				main.Position = UDim2.new(
					startPos.X.Scale,
					startPos.X.Offset + d.X,
					startPos.Y.Scale,
					startPos.Y.Offset + d.Y
				)
			end
		end))
	end

	-- Pop-up dialog (reason boxes, option pickers) ---------------------------------
	local modal = new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		Visible = false,
		ZIndex = 60,
		Parent = main,
	}, { corner(18) })
	local dlg = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 340, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.panel,
		BorderSizePixel = 0,
		Parent = modal,
	}, {
		corner(14),
		stroke(C.accent2, 1.5, 0.2),
		pad(16),
		new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UISizeConstraint", { MaxSize = Vector2.new(400, 420) }),
	})
	local function closeModal()
		modal.Visible = false
	end
	modal.MouseButton1Click:Connect(closeModal)

	-- spec: { title, sub, fields = {placeholder,...}, options = {{text, value, color}}, okText, onSubmit(...), onPick(value) }
	local function openModal(spec)
		for _, c in dlg:GetChildren() do
			if c:GetAttribute("dyn") then
				c:Destroy()
			end
		end
		local order = 0
		local function add(inst)
			order += 1
			inst.LayoutOrder = order
			inst:SetAttribute("dyn", true)
			return inst
		end
		add(
			label(
				dlg,
				spec.title,
				UDim2.new(1, 0, 0, 24),
				{ Font = Enum.Font.GothamBold, TextSize = 18, Color = C.text, Wrap = false }
			)
		)
		if spec.sub then
			add(
				label(
					dlg,
					spec.sub,
					UDim2.new(1, 0, 0, 0),
					{ AutomaticSize = Enum.AutomaticSize.Y, TextSize = 12 }
				)
			)
		end
		local boxes = {}
		for _, placeholder in spec.fields or {} do
			table.insert(boxes, add(textbox(dlg, placeholder, UDim2.new(1, 0, 0, 36))))
		end
		if spec.options then
			local holder = add(new("ScrollingFrame", {
				Size = UDim2.new(1, 0, 0, math.min(#spec.options, 6) * 40),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 3,
				ScrollBarImageColor3 = C.line,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				Parent = dlg,
			}, {
				new(
					"UIListLayout",
					{ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }
				),
			}))
			for i, o in spec.options do
				button(holder, o.text, o.color or C.item, function()
					closeModal()
					spec.onPick(o.value)
				end, { Size = UDim2.new(1, -6, 0, 34), LayoutOrder = i })
			end
		end
		local brow = add(
			new(
				"Frame",
				{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), Parent = dlg }
			)
		)
		if spec.onSubmit then
			button(brow, "Cancel", C.item, closeModal, { Size = UDim2.new(0.5, -4, 1, 0) })
			button(brow, spec.okText or "Confirm", spec.okColor or C.accent, function()
				local values = {}
				for i, b in boxes do
					values[i] = b.Text
				end
				closeModal()
				spec.onSubmit(table.unpack(values))
			end, { Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new(0.5, 4, 0, 0) })
		else
			button(brow, "Cancel", C.item, closeModal, { Size = UDim2.new(1, 0, 1, 0) })
		end
		modal.Visible = true
		if boxes[1] then
			task.defer(function()
				boxes[1]:CaptureFocus()
			end)
		end
	end

	-- Navigation -----------------------------------------------------------
	local pages, navItems, navOrder = {}, {}, 0
	local onShow = {}
	local currentPage
	local NAV_NAMES = { Home = "Overview", Server = "Server", Bans = "Moderation" }
	local showPage

	showPage = function(name)
		currentPage = name
		for pageName, frame in pages do
			local active = pageName == name
			frame.Visible = active
			local nav = navItems[pageName]
			TweenService
				:Create(
					nav.button,
					TweenInfo.new(0.15),
					{ BackgroundTransparency = active and 0 or 1 }
				)
				:Play()
			nav.label.TextColor3 = active and Color3.new(1, 1, 1) or C.sub
			nav.stroke.Transparency = active and 0.2 or 1
		end
		local overview = name == "Home"
		topbar.Visible = not overview
		pagesHolder.Position = overview and UDim2.new(0, 12, 0, 12) or UDim2.new(0, 12, 0, 54)
		pagesHolder.Size = overview and UDim2.new(1, -24, 1, -22) or UDim2.new(1, -24, 1, -64)
		pageTitle.Text = NAV_NAMES[name] or name
		pageSub.Text = navItems[name].subtitle
		if onShow[name] then
			task.spawn(onShow[name])
		end
	end
	gearBtn.MouseButton1Click:Connect(function()
		if pages["Settings"] then
			showPage("Settings")
		end
	end)

	local function addPage(name, iconKey, pageSubtitle, minLevel, hidden)
		if LEVEL < minLevel then
			return nil
		end
		navOrder += 1
		local frame = new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = pagesHolder,
		})
		pages[name] = frame

		local item = new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			Visible = not hidden,
			LayoutOrder = navOrder,
			Parent = navList,
		}, { corner(10) })
		local itemStroke = stroke(Color3.new(1, 1, 1), 1, 1)
		itemStroke.Parent = item
		gradient(item, C.accent:Lerp(Color3.new(1, 1, 1), 0.1), C.accent:Lerp(C.accent2, 0.35), 0)
		local ic =
			icon(item, ICONS[iconKey] or "•", 24, { Position = UDim2.new(0, 12, 0.5, -12) })
		local nm = label(item, NAV_NAMES[name] or name, UDim2.new(1, -54, 1, 0), {
			Font = Enum.Font.GothamMedium,
			TextSize = 15,
			Color = C.sub,
			Position = UDim2.new(0, 50, 0, 0),
			Wrap = false,
		})
		item.MouseButton1Click:Connect(function()
			showPage(name)
		end)
		item.MouseEnter:Connect(function()
			if currentPage ~= name then
				TweenService:Create(item, TweenInfo.new(0.12), { BackgroundTransparency = 0.85 })
					:Play()
			end
		end)
		item.MouseLeave:Connect(function()
			if currentPage ~= name then
				TweenService:Create(item, TweenInfo.new(0.12), { BackgroundTransparency = 1 })
					:Play()
			end
		end)
		navItems[name] =
			{ button = item, icon = ic, label = nm, stroke = itemStroke, subtitle = pageSubtitle }
		return frame
	end

	-- Responsive layout ------------------------------------------------------
	local function relayout()
		local w = main.AbsoluteSize.X / rootScale.Scale
		local compact = w < 700
		local sbW = compact and 64 or SIDE_W
		sidebar.Size = UDim2.new(0, sbW, 1, -HEADER_H)
		body.Position = UDim2.new(0, sbW, 0, HEADER_H)
		body.Size = UDim2.new(1, -sbW, 1, -HEADER_H)
		hint.Text = compact and keyName or ("Press " .. keyName .. " to toggle")
		for _, n in navItems do
			n.label.Visible = not compact
			n.icon.Position = compact and UDim2.new(0.5, -12, 0.5, -12)
				or UDim2.new(0, 12, 0.5, -12)
		end
		subtitle.Visible = w >= 560
		serverPill.Visible = w >= 700
		userCard.Visible = w >= 880
		title.TextSize = w >= 480 and 30 or 22
		titleBox.Size = UDim2.new(0, w >= 480 and 330 or 200, 1, 0)
	end
	track(main:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout))

	---------------------------------------------------------------------
	-- Fly / Noclip (local to the admin)
	---------------------------------------------------------------------
	local FLY_SPEED = 70
	local flying, flyConn, flyObjs = false, nil, {}
	local noclipConn
	local flyBtn, noclipBtn

	local function stopFly()
		flying = false
		if flyConn then
			flyConn:Disconnect()
			flyConn = nil
		end
		for _, o in flyObjs do
			o:Destroy()
		end
		table.clear(flyObjs)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.PlatformStand = false
		end
		if flyBtn then
			flyBtn.Text = "🕊️ Fly: Off"
		end
	end

	local function startFly()
		local char = player.Character
		local flyRoot = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not flyRoot or not hum then
			notify("Your character isn't loaded.", true)
			return
		end
		flying = true
		hum.PlatformStand = true

		local att = new("Attachment", { Name = "AdminFlyAttachment", Parent = flyRoot })
		local lv = new("LinearVelocity", {
			Attachment0 = att,
			MaxForce = math.huge,
			VelocityConstraintMode = Enum.VelocityConstraintMode.Vector,
			RelativeTo = Enum.ActuatorRelativeTo.World,
			VectorVelocity = Vector3.zero,
			Parent = flyRoot,
		})
		local ao = new("AlignOrientation", {
			Mode = Enum.OrientationAlignmentMode.OneAttachment,
			Attachment0 = att,
			MaxTorque = math.huge,
			Responsiveness = 40,
			Parent = flyRoot,
		})
		flyObjs = { att, lv, ao }

		flyConn = RunService.RenderStepped:Connect(function()
			local cam = Workspace.CurrentCamera
			if not cam then
				return
			end
			local dir = Vector3.zero
			if not UserInputService:GetFocusedTextBox() then
				local k = Enum.KeyCode
				if UserInputService:IsKeyDown(k.W) then
					dir += cam.CFrame.LookVector
				end
				if UserInputService:IsKeyDown(k.S) then
					dir -= cam.CFrame.LookVector
				end
				if UserInputService:IsKeyDown(k.D) then
					dir += cam.CFrame.RightVector
				end
				if UserInputService:IsKeyDown(k.A) then
					dir -= cam.CFrame.RightVector
				end
				if UserInputService:IsKeyDown(k.E) or UserInputService:IsKeyDown(k.Space) then
					dir += Vector3.yAxis
				end
				if UserInputService:IsKeyDown(k.Q) or UserInputService:IsKeyDown(k.LeftControl) then
					dir -= Vector3.yAxis
				end
			end
			if UserInputService.TouchEnabled and hum.MoveDirection.Magnitude > 0 then
				dir += hum.MoveDirection
			end
			lv.VectorVelocity = dir.Magnitude > 0 and dir.Unit * FLY_SPEED or Vector3.zero

			local look = cam.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.01 then
				ao.CFrame = CFrame.lookAt(Vector3.zero, flat)
			end
		end)
		if flyBtn then
			flyBtn.Text = "🕊️ Fly: On"
		end
	end

	local function toggleFly()
		if flying then
			stopFly()
		else
			startFly()
		end
	end

	local function toggleNoclip()
		if noclipConn then
			noclipConn:Disconnect()
			noclipConn = nil
			if noclipBtn then
				noclipBtn.Text = "👻 Noclip: Off"
			end
			return
		end
		noclipConn = RunService.Stepped:Connect(function()
			local char = player.Character
			if char then
				for _, part in char:GetDescendants() do
					if part:IsA("BasePart") and part.CanCollide then
						part.CanCollide = false
					end
				end
			end
		end)
		if noclipBtn then
			noclipBtn.Text = "👻 Noclip: On"
		end
	end

	track(player.CharacterAdded:Connect(function()
		if flying then
			stopFly()
		end
	end))

	---------------------------------------------------------------------
	-- Shared state
	---------------------------------------------------------------------
	local selected = nil -- "all" or a player's Name

	---------------------------------------------------------------------
	-- PAGE: Home  (Overview dashboard)
	---------------------------------------------------------------------
	do
		local page = addPage("Home", "home", "Overview of this server", 1)
		-- fixed layout (the page itself never scrolls; Quick Actions and the Player List scroll inside their cards)
		local sc = new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = page,
		})

		local COL_GREEN = Color3.fromRGB(24, 224, 130)
		local COL_RED = Color3.fromRGB(255, 59, 83)
		local PURPLE = Color3.fromRGB(122, 60, 240)
		local PINK = Color3.fromRGB(226, 30, 140)
		local TEAL = Color3.fromRGB(14, 150, 196)

		-- A dashboard card with an icon + title row. Returns card, headerRow
		local function panelCard(parent, order, glyph, titleText)
			local f = card(parent, order)
			local hdr = new("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 28),
				LayoutOrder = 0,
				Parent = f,
			})
			icon(hdr, glyph, 22, { Position = UDim2.new(0, 0, 0.5, -11) })
			label(hdr, titleText, UDim2.new(1, -34, 1, 0), {
				Font = Enum.Font.GothamBold,
				TextSize = 16,
				Color = C.text,
				Position = UDim2.new(0, 32, 0, 0),
				Wrap = false,
			})
			return f, hdr
		end

		local function vlist(parent, order, size)
			return new("Frame", {
				BackgroundTransparency = 1,
				Size = size or UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = order,
				Parent = parent,
			}, {
				new(
					"UIListLayout",
					{ Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }
				),
			})
		end

		-- Two columns that stack on small screens ---------------------------------
		local cols = new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			LayoutOrder = 1,
			Parent = sc,
		}, {
			new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Wraps = true,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Top,
			}),
		})
		local left = vlist(cols, 1, UDim2.new(1, -312, 1, 0))
		local right = vlist(cols, 2, UDim2.new(0, 300, 1, 0))
		left.AutomaticSize = Enum.AutomaticSize.None
		right.AutomaticSize = Enum.AutomaticSize.None

		---------------------------------------------------------------------
		-- Server Stats
		---------------------------------------------------------------------
		local statCard = panelCard(left, 1, "📊", "Server Stats")
		statCard.AutomaticSize = Enum.AutomaticSize.None
		statCard.Size = UDim2.new(1, 0, 0, 148)
		local statGrid = new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1,
			Parent = statCard,
		}, {
			new("UIGridLayout", {
				CellSize = UDim2.new(0.25, -6, 0, 88),
				CellPadding = UDim2.fromOffset(8, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		local statLabels = {}
		local function stat(key, glyph, statTitle, order, tint)
			local f = new("Frame", {
				BackgroundColor3 = WHITE,
				BorderSizePixel = 0,
				LayoutOrder = order,
				Parent = statGrid,
			}, { corner(10), stroke(tint, 1, 0.55) })
			gradient(f, C.item:Lerp(tint, 0.22), C.item:Lerp(Color3.new(0, 0, 0), 0.2), 90)
			icon(f, glyph, 26, { Position = UDim2.new(0.5, -13, 0, 9) })
			statLabels[key] = label(f, "-", UDim2.new(1, 0, 0, 26), {
				Font = Enum.Font.GothamBold,
				TextSize = 22,
				Color = C.text,
				Align = Enum.TextXAlignment.Center,
				Position = UDim2.new(0, 0, 0, 38),
				Wrap = false,
			})
			label(f, statTitle, UDim2.new(1, 0, 0, 16), {
				TextSize = 12,
				Align = Enum.TextXAlignment.Center,
				Position = UDim2.new(0, 0, 0, 66),
				Wrap = false,
			})
		end
		stat("total", "👥", "Total Players", 1, C.accent)
		stat("alive", "🧍", "Alive", 2, COL_GREEN)
		stat("dead", "💀", "Eliminated", 3, COL_RED)
		stat("uptime", "⏱️", "Server Uptime", 4, C.accent)

		---------------------------------------------------------------------
		-- Player List
		---------------------------------------------------------------------
		local plCard, plHeader = panelCard(left, 2, "👥", "Player List")
		plCard.AutomaticSize = Enum.AutomaticSize.None
		plCard.Size = UDim2.new(1, 0, 1, -158)
		local search = textbox(plHeader, "Search player...", UDim2.fromOffset(190, 30), {})
		search.AnchorPoint = Vector2.new(1, 0.5)
		search.Position = UDim2.new(1, 0, 0.5, 0)
		search.TextSize = 12

		local colHead = new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			LayoutOrder = 1,
			Parent = plCard,
		})
		local function headLabel(text, pos, w)
			local l = label(
				colHead,
				text,
				UDim2.new(w, 0, 1, 0),
				{ TextSize = 12, Position = pos, Wrap = false }
			)
			return l
		end
		headLabel("Player", UDim2.new(0, 50, 0, 0), 0.3)
		local headStatus = headLabel("Status", UDim2.new(0.36, 0, 0, 0), 0.15)
		local headPing = headLabel("Ping", UDim2.new(0.52, 0, 0, 0), 0.1)
		headLabel("Actions", UDim2.new(1, -194, 0, 0), 0.3)

		local listHolder = new("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, -66),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = C.line,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = plCard,
		}, {
			new(
				"UIListLayout",
				{ Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }
			),
		})

		local rows = {}
		local viewing -- Player currently being spectated
		local targetLabel -- assigned below

		local function stopViewing()
			viewing = nil
			local cam = Workspace.CurrentCamera
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if cam and hum then
				cam.CameraSubject = hum
			end
		end
		local function toggleView(p)
			if viewing == p or p == player then
				stopViewing()
				notify("Camera back on you.")
				return
			end
			local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			local cam = Workspace.CurrentCamera
			if not hum or not cam then
				notify("That player has no character right now.", true)
				return
			end
			viewing = p
			cam.CameraSubject = hum
			notify("Viewing " .. p.Name .. " - press View again to stop.")
		end
		track(player.CharacterAdded:Connect(function()
			viewing = nil
		end))

		local function refreshSelection()
			for p, r in rows do
				r.stroke.Transparency = (selected == p.Name) and 0.05 or 1
				r.frame.BackgroundTransparency = (selected == p.Name) and 0.15 or 0.5
			end
			if targetLabel then
				if selected and selected ~= "all" then
					targetLabel.Text = "Target: " .. selected
					targetLabel.TextColor3 = C.accent2
				else
					targetLabel.Text = "Target: none - click a player in the list"
					targetLabel.TextColor3 = C.sub
				end
			end
		end

		local function smallBtn(parent, text, color, order, width, callback)
			local b = button(
				parent,
				text,
				color,
				callback,
				{ Size = UDim2.fromOffset(width, 28), LayoutOrder = order }
			)
			b.TextSize = 12
			return b
		end

		local function askKick(name)
			openModal({
				title = "Kick " .. name,
				fields = { "Reason (optional)" },
				okText = "Kick",
				okColor = C.danger,
				onSubmit = function(reason)
					act("kick", name, reason)
				end,
			})
		end
		local function askBan(name)
			openModal({
				title = "Ban " .. name,
				fields = { "Reason (optional)", "Minutes (0 = forever)" },
				okText = "Ban",
				okColor = PURPLE,
				onSubmit = function(reason, minutes)
					act("ban", name, reason, tonumber(minutes) or 0)
				end,
			})
		end

		local function createRow(p)
			if rows[p] then
				return
			end
			local frame = new("TextButton", {
				Text = "",
				AutoButtonColor = false,
				Size = UDim2.new(1, -6, 0, 46),
				BackgroundColor3 = C.item,
				BackgroundTransparency = 0.5,
				BorderSizePixel = 0,
				Parent = listHolder,
			}, { corner(10) })
			local st = stroke(C.accent2, 1.5, 1)
			st.Parent = frame
			new("ImageLabel", {
				Position = UDim2.new(0, 8, 0.5, -17),
				Size = UDim2.fromOffset(34, 34),
				BackgroundColor3 = C.bg,
				Image = thumb(p.UserId),
				Parent = frame,
			}, { corner(17), stroke(levelColor, 1.5, 0.4) })
			local nameLbl = label(frame, p.Name, UDim2.new(0.34, -50, 0, 18), {
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				Color = C.text,
				Position = UDim2.new(0, 50, 0, 6),
				Wrap = false,
				Truncate = Enum.TextTruncate.AtEnd,
			})
			local subLbl = label(frame, "Player", UDim2.new(0.34, -50, 0, 14), {
				TextSize = 11,
				Position = UDim2.new(0, 50, 0, 25),
				Wrap = false,
				Truncate = Enum.TextTruncate.AtEnd,
			})
			local statusLbl = label(frame, "", UDim2.new(0.16, 0, 1, 0), {
				TextSize = 12,
				Color = C.text,
				Position = UDim2.new(0.36, 0, 0, 0),
				Wrap = false,
			})
			statusLbl.RichText = true
			local pingLbl = label(frame, "-", UDim2.new(0.12, 0, 1, 0), {
				TextSize = 12,
				Color = C.text,
				Position = UDim2.new(0.52, 0, 0, 0),
				Wrap = false,
			})
			local actions = new("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(186, 28),
				BackgroundTransparency = 1,
				Parent = frame,
			}, {
				new("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					Padding = UDim.new(0, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			})
			smallBtn(actions, "👁 View", C.accent, 1, 62, function()
				toggleView(p)
			end)
			smallBtn(actions, "👤 Kick", C.danger, 2, 56, function()
				askKick(p.Name)
			end)
			if LEVEL >= 2 then
				smallBtn(actions, "🚫 Ban", PURPLE, 3, 56, function()
					askBan(p.Name)
				end)
			end
			frame.MouseButton1Click:Connect(function()
				selected = p.Name
				refreshSelection()
			end)
			rows[p] = {
				frame = frame,
				stroke = st,
				name = nameLbl,
				sub = subLbl,
				status = statusLbl,
				ping = pingLbl,
				statusHex = nil,
			}
		end

		local function updateRows()
			local total, dead = 0, 0
			local q = string.lower(search.Text)
			local compactRows = listHolder.AbsoluteSize.X / rootScale.Scale < 520
			for p, r in rows do
				total += 1
				local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
				local isDead = hum ~= nil and hum.Health <= 0
				if isDead then
					dead += 1
				end
				local col = isDead and COL_RED or COL_GREEN
				r.status.Text = string.format(
					'<font color="#%s">●</font> %s',
					col:ToHex(),
					isDead and "Eliminated" or "Alive"
				)
				local ping = p:GetAttribute("AdminPing")
				r.ping.Text = ping and (ping .. " ms") or "-"
				local roleIcon = p:GetAttribute("AdminRoleIcon")
				r.name.Text = p.Name .. (roleIcon and ("  " .. roleIcon) or "")
				r.sub.Text = p:GetAttribute("AdminRole")
					or (p == player and (LEVEL_NAMES[LEVEL] or "Admin") or "Player")
				r.status.Visible = not compactRows
				r.ping.Visible = not compactRows
				r.frame.Visible = q == ""
					or string.find(string.lower(p.Name), q, 1, true) ~= nil
					or string.find(string.lower(p.DisplayName), q, 1, true) ~= nil
			end
			headStatus.Visible = not compactRows
			headPing.Visible = not compactRows
			statLabels.total.Text = tostring(total)
			statLabels.dead.Text = tostring(dead)
			statLabels.alive.Text = tostring(total - dead)
			local t = math.floor(Workspace.DistributedGameTime)
			statLabels.uptime.Text = t >= 3600
					and string.format("%d:%02d:%02d", t // 3600, (t % 3600) // 60, t % 60)
				or string.format("%02d:%02d", t // 60, t % 60)
		end

		for _, p in Players:GetPlayers() do
			createRow(p)
		end
		track(Players.PlayerAdded:Connect(function(p)
			createRow(p)
			task.defer(updateRows)
		end))
		track(Players.PlayerRemoving:Connect(function(p)
			local r = rows[p]
			if r then
				r.frame:Destroy()
				rows[p] = nil
			end
			if viewing == p then
				stopViewing()
			end
			if selected == p.Name then
				selected = nil
				refreshSelection()
			end
			task.defer(updateRows)
		end))
		track(search:GetPropertyChangedSignal("Text"):Connect(updateRows))
		updateRows()

		task.spawn(function()
			while alive do
				if page.Visible then
					updateRows()
				end
				task.wait(1)
			end
		end)

		---------------------------------------------------------------------
		-- Quick Actions (right column)
		---------------------------------------------------------------------
		local qaCard = panelCard(right, 1, "⚡", "Quick Actions")
		qaCard.AutomaticSize = Enum.AutomaticSize.None
		qaCard.Size = UDim2.new(1, 0, 1, 0)
		targetLabel = label(
			qaCard,
			"",
			UDim2.new(1, 0, 0, 16),
			{ TextSize = 11, LayoutOrder = 1, Wrap = false }
		)
		-- everything inside Quick Actions scrolls
		local qaScroll = new("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, -62),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = C.line,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = qaCard,
		}, {
			new(
				"UIListLayout",
				{ Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }
			),
			pad(0, 0, 8, 4),
		})
		local qaGrid = new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1,
			Parent = qaScroll,
		}, {
			new("UIGridLayout", {
				CellSize = UDim2.new(1 / 3, -6, 0, 78),
				CellPadding = UDim2.fromOffset(8, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})

		local function tile(order, glyph, text, color, callback)
			local b = new("TextButton", {
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = WHITE,
				BorderSizePixel = 0,
				LayoutOrder = order,
				Parent = qaGrid,
			}, { corner(10), stroke(color:Lerp(WHITE, 0.4), 1, 0.35) })
			local g = gradient(b, color:Lerp(WHITE, 0.15), color:Lerp(Color3.new(0, 0, 0), 0.3), 90)
			icon(b, glyph, 28, { Position = UDim2.new(0.5, -14, 0, 10) })
			label(b, text, UDim2.new(1, -6, 0, 18), {
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				Color = WHITE,
				Align = Enum.TextXAlignment.Center,
				Position = UDim2.new(0, 3, 1, -26),
				Wrap = false,
			})
			b.MouseEnter:Connect(function()
				g.Color =
					ColorSequence.new(color:Lerp(WHITE, 0.3), color:Lerp(Color3.new(0, 0, 0), 0.15))
			end)
			b.MouseLeave:Connect(function()
				g.Color =
					ColorSequence.new(color:Lerp(WHITE, 0.15), color:Lerp(Color3.new(0, 0, 0), 0.3))
			end)
			b.MouseButton1Click:Connect(callback)
			return b
		end

		-- returns the selected player's name, or nil (and tells the admin why)
		local function needTarget(minLevel)
			if LEVEL < minLevel then
				notify("Your admin level isn't high enough for that.", true)
				return nil
			end
			if not selected or selected == "all" then
				notify("Click a player in the Player List first.", true)
				return nil
			end
			return selected
		end

		tile(1, "👤", "Kick Player", C.danger, function()
			local t = needTarget(1)
			if t then
				askKick(t)
			end
		end)
		tile(2, "🚫", "Ban Player", PURPLE, function()
			local t = needTarget(2)
			if t then
				askBan(t)
			end
		end)
		tile(3, "✅", "Unban Player", Color3.fromRGB(16, 150, 100), function()
			if LEVEL < 2 then
				notify("Your admin level isn't high enough for that.", true)
				return
			end
			openModal({
				title = "Unban a player",
				fields = { "Username or UserId" },
				okText = "Unban",
				okColor = C.good,
				onSubmit = function(who)
					act("unban", who)
				end,
			})
		end)
		tile(6, "🔄", "Reset Player", TEAL, function()
			local t = needTarget(1)
			if t then
				act("respawn", t)
			end
		end)
		tile(8, "📍", "Teleport", Color3.fromRGB(20, 120, 230), function()
			local t = needTarget(1)
			if not t then
				return
			end
			local options = {
				{ text = "📍  Go to " .. t, value = "goto" },
				{ text = "🧲  Bring " .. t .. " to me", value = "bring" },
			}
			local okLoc, locs = act("tplocations")
			if okLoc and type(locs) == "table" then
				for _, l in locs do
					table.insert(
						options,
						{ text = "➤  Send to " .. l.name, value = "loc:" .. l.name }
					)
				end
			end
			openModal({
				title = "Teleport " .. t,
				options = options,
				onPick = function(kind)
					if string.sub(kind, 1, 4) == "loc:" then
						act("tploc", t, string.sub(kind, 5))
					else
						act(kind, t)
					end
				end,
			})
		end)
		tile(9, "💬", "Custom Message", PINK, function()
			if LEVEL < 2 then
				notify("Announcements need Admin level.", true)
				return
			end
			openModal({
				title = "Message everyone",
				fields = { "Type your message..." },
				okText = "Send",
				onSubmit = function(text)
					act("announce", text, 8)
				end,
			})
		end)

		---------------------------------------------------------------------
		-- Quick Actions (scroll down): Server Message / Game Controls / Your Tools
		---------------------------------------------------------------------
		local function qaHeading(order, text)
			return label(qaScroll, text, UDim2.new(1, 0, 0, 16), {
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				Color = C.sub,
				LayoutOrder = order,
				Wrap = false,
			})
		end

		-- Server message
		qaHeading(2, "💬  SERVER MESSAGE")
		local msgBox = textbox(
			qaScroll,
			"Type your message here...",
			UDim2.new(1, 0, 0, 76),
			{ MultiLine = true, LayoutOrder = 3 }
		)
		msgBox.TextSize = 12
		button(qaScroll, "➤ Send to everyone", C.accent, function()
			if LEVEL < 2 then
				notify("Announcements need Admin level.", true)
				return
			end
			if act("announce", msgBox.Text, 8) then
				msgBox.Text = ""
			end
		end, { Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 4 })

		-- Your tools (fly / noclip / god / heal ...)
		qaHeading(7, "🧰  YOUR TOOLS")
		local toolsGrid = new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 8,
			Parent = qaScroll,
		}, {
			new("UIGridLayout", {
				CellSize = UDim2.new(0.5, -4, 0, 34),
				CellPadding = UDim2.fromOffset(8, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		flyBtn = button(toolsGrid, "🕊️ Fly: Off", C.accent, toggleFly, { LayoutOrder = 1 })
		noclipBtn =
			button(toolsGrid, "👻 Noclip: Off", C.accent, toggleNoclip, { LayoutOrder = 2 })
		button(toolsGrid, "🙈 Go Invisible", C.item, function()
			act("invisible", "me", true)
		end, { LayoutOrder = 5 })
		button(toolsGrid, "👁️ Be Visible", C.item, function()
			act("invisible", "me", false)
		end, { LayoutOrder = 6 })
		label(
			qaScroll,
			"Fly: WASD to move, Space / E up, Q / Ctrl down. On mobile, use the joystick.",
			UDim2.new(1, 0, 0, 0),
			{
				AutomaticSize = Enum.AutomaticSize.Y,
				TextSize = 11,
				LayoutOrder = 9,
			}
		)

		onShow.Home = function()
			updateRows()
		end

		-- stack / side-by-side depending on width
		local function layoutCols()
			local w = sc.AbsoluteSize.X / rootScale.Scale
			if w >= 700 then
				left.Size = UDim2.new(1, -312, 1, 0)
				right.Size = UDim2.new(0, 300, 1, 0)
				statCard.Visible = true
				plCard.Size = UDim2.new(1, 0, 1, -158)
			else
				-- small screens: player list on top, quick actions below (no page scrolling)
				left.Size = UDim2.new(1, 0, 0.42, -5)
				right.Size = UDim2.new(1, 0, 0.58, -5)
				statCard.Visible = false
				plCard.Size = UDim2.new(1, 0, 1, 0)
			end
			local narrow = w < 560
			qaGrid:FindFirstChildOfClass("UIGridLayout").CellSize = UDim2.new(1 / 3, -6, 0, 78)
			statGrid:FindFirstChildOfClass("UIGridLayout").CellSize = narrow
					and UDim2.new(0.5, -4, 0, 88)
				or UDim2.new(0.25, -6, 0, 88)
		end
		track(sc:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutCols))
		layoutCols()
		refreshSelection()

		-- remember so destroy() can restore the camera
		page:SetAttribute("HasViewer", true)
		table.insert(conns, { Disconnect = stopViewing })
	end

	---------------------------------------------------------------------
	-- PAGE: Players
	---------------------------------------------------------------------
	do
		local page = addPage("Players", "players", "Moderate and manage players", 1)

		local left = new("Frame", {
			BackgroundColor3 = C.panel,
			BorderSizePixel = 0,
			Parent = page,
		}, { corner(12), stroke(C.line, 1, 0.55) })
		local search = textbox(
			left,
			"🔍  Search players",
			UDim2.new(1, -16, 0, 32),
			{ Position = UDim2.new(0, 8, 0, 8) }
		)
		local list = new("ScrollingFrame", {
			Position = UDim2.new(0, 8, 0, 48),
			Size = UDim2.new(1, -16, 1, -56),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Parent = left,
		}, {
			new(
				"UIListLayout",
				{ Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }
			),
		})

		local right = scroller(page)

		local function layout()
			local w = page.AbsoluteSize.X / rootScale.Scale
			if w < 470 then
				-- narrow screens: list on top, actions below
				left.Size = UDim2.new(1, 0, 0, 120)
				right.Position = UDim2.new(0, 0, 0, 128)
				right.Size = UDim2.new(1, 0, 1, -128)
			else
				local lw = math.clamp(math.floor(w * 0.3), 140, 210)
				left.Size = UDim2.new(0, lw, 1, 0)
				right.Position = UDim2.new(0, lw + 10, 0, 0)
				right.Size = UDim2.new(1, -(lw + 10), 1, 0)
			end
		end
		track(page:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout))
		onShow.Players = layout
		layout()

		-- Target card
		local tc = card(right, 1)
		local trow = new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 52),
			LayoutOrder = 1,
			Parent = tc,
		})
		local tAvatar = new("ImageLabel", {
			Size = UDim2.fromOffset(48, 48),
			BackgroundColor3 = C.item,
			Image = "",
			Parent = trow,
		}, { corner(24) })
		local tName = label(trow, "No target selected", UDim2.new(1, -60, 0, 22), {
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			Color = C.text,
			Position = UDim2.new(0, 58, 0, 4),
			Wrap = false,
			Truncate = Enum.TextTruncate.AtEnd,
		})
		local tSub = label(trow, "Pick a player from the list", UDim2.new(1, -60, 0, 18), {
			TextSize = 12,
			Position = UDim2.new(0, 58, 0, 28),
			Wrap = false,
			Truncate = Enum.TextTruncate.AtEnd,
		})
		local reasonBox =
			textbox(tc, "Reason (for kick / ban)", UDim2.new(1, 0, 0, 34), { LayoutOrder = 2 })
		local valueBox = textbox(
			tc,
			"Number: speed / jump / ban minutes / prank seconds",
			UDim2.new(1, 0, 0, 34),
			{ LayoutOrder = 3 }
		)

		local function updateTarget()
			if selected == nil then
				tName.Text = "No target selected"
				tSub.Text = "Pick a player from the list"
				tAvatar.Image = ""
			elseif selected == "all" then
				tName.Text = "Everyone"
				tSub.Text = "Actions apply to every player you outrank"
				tAvatar.Image = ""
			else
				local p = Players:FindFirstChild(selected)
				if p then
					tName.Text = p.DisplayName
					local r = p:GetAttribute("AdminRole")
					tSub.Text = "@"
						.. p.Name
						.. (
							r
								and ("  •  " .. (p:GetAttribute("AdminRoleIcon") or "") .. " " .. r)
							or ""
						)
					tAvatar.Image = thumb(p.UserId)
				else
					selected = nil
					updateTarget()
				end
			end
		end

		-- Player list
		local rebuildList
		local function setSelected(value)
			selected = value
			updateTarget()
			rebuildList()
		end

		rebuildList = function()
			for _, c in list:GetChildren() do
				if c:IsA("TextButton") then
					c:Destroy()
				end
			end
			local q = string.lower(search.Text)
			local order = 0

			local function addRow(text, value, userId, roleIcon)
				order += 1
				local b = new("TextButton", {
					LayoutOrder = order,
					Size = UDim2.new(1, 0, 0, 36),
					BackgroundColor3 = selected == value and C.accent or C.item,
					AutoButtonColor = false,
					Text = "",
					Parent = list,
				}, { corner(8) })
				if userId then
					new("ImageLabel", {
						Size = UDim2.fromOffset(26, 26),
						Position = UDim2.new(0, 6, 0.5, -13),
						BackgroundColor3 = C.bg,
						Image = thumb(userId),
						Parent = b,
					}, { corner(13) })
				else
					icon(b, "🌐", 22, { Position = UDim2.new(0, 8, 0.5, -11) })
				end
				label(b, text, UDim2.new(1, roleIcon and -66 or -42, 1, 0), {
					Color = C.text,
					Position = UDim2.new(0, 38, 0, 0),
					Wrap = false,
					Truncate = Enum.TextTruncate.AtEnd,
				})
				if roleIcon then
					icon(b, roleIcon, 16, { Position = UDim2.new(1, -24, 0.5, -8) })
				end
				b.MouseButton1Click:Connect(function()
					setSelected(value)
				end)
			end

			if q == "" then
				addRow("Everyone", "all", nil, nil)
			end
			local plist = Players:GetPlayers()
			table.sort(plist, function(a, b)
				return string.lower(a.Name) < string.lower(b.Name)
			end)
			for _, p in plist do
				if
					q == ""
					or string.find(string.lower(p.Name), q, 1, true)
					or string.find(string.lower(p.DisplayName), q, 1, true)
				then
					local text = p.Name == p.DisplayName and p.Name or p.DisplayName
					addRow(text, p.Name, p.UserId, p:GetAttribute("AdminRoleIcon"))
				end
			end
		end

		local function watch(p)
			track(p:GetAttributeChangedSignal("AdminRole"):Connect(function()
				rebuildList()
				updateTarget()
			end))
		end
		for _, p in Players:GetPlayers() do
			watch(p)
		end
		track(Players.PlayerAdded:Connect(function(p)
			watch(p)
			rebuildList()
		end))
		track(Players.PlayerRemoving:Connect(function(p)
			if selected == p.Name then
				selected = nil
				updateTarget()
			end
			task.defer(rebuildList)
		end))
		track(search:GetPropertyChangedSignal("Text"):Connect(rebuildList))
		rebuildList()

		-- Command categories: tiles like Quick Actions. Click one to see its commands.
		local BLACK = Color3.new(0, 0, 0)

		local catTiles = grid(right, 10, 132, 84)
		local catView = new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 11,
			Visible = false,
			Parent = right,
		}, {
			new(
				"UIListLayout",
				{ Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }
			),
		})
		local catHeader = new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 36),
			LayoutOrder = 1,
			Parent = catView,
		})
		local catTitle = label(catHeader, "", UDim2.new(1, -104, 1, 0), {
			Font = Enum.Font.GothamBold,
			TextSize = 17,
			Color = C.text,
			Position = UDim2.new(0, 104, 0, 0),
			Wrap = false,
		})

		local cats = {}
		local openCategory, closeCategory
		button(catHeader, "← Back", C.item, function()
			closeCategory()
		end, { Size = UDim2.fromOffset(94, 34) })

		local function makeTile(order, glyph, text, color, callback)
			local b = new("TextButton", {
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = WHITE,
				BorderSizePixel = 0,
				LayoutOrder = order,
				Parent = catTiles,
			}, { corner(12), stroke(color:Lerp(WHITE, 0.4), 1, 0.35) })
			local g = gradient(b, color:Lerp(WHITE, 0.15), color:Lerp(BLACK, 0.3), 90)
			icon(b, glyph, 30, { Position = UDim2.new(0.5, -15, 0, 12) })
			label(b, text, UDim2.new(1, -8, 0, 20), {
				Font = Enum.Font.GothamMedium,
				TextSize = 12,
				Color = WHITE,
				Align = Enum.TextXAlignment.Center,
				Position = UDim2.new(0, 4, 1, -28),
				Wrap = false,
			})
			b.MouseEnter:Connect(function()
				g.Color = ColorSequence.new(color:Lerp(WHITE, 0.3), color:Lerp(BLACK, 0.15))
			end)
			b.MouseLeave:Connect(function()
				g.Color = ColorSequence.new(color:Lerp(WHITE, 0.15), color:Lerp(BLACK, 0.3))
			end)
			b.MouseButton1Click:Connect(callback)
			return b
		end

		local tileOrder = 0
		-- A category tile that opens a list of command buttons. Returns the grid to fill (nil if your level is too low)
		local function category(name, glyph, color, minLevel)
			if LEVEL < minLevel then
				return nil
			end
			local g = grid(catView, 2, 124, 36)
			g.Visible = false
			local entry = { name = name, glyph = glyph, grid = g }
			table.insert(cats, entry)
			tileOrder += 1
			makeTile(tileOrder, glyph, name, color, function()
				openCategory(entry)
			end)
			return g
		end
		openCategory = function(entry)
			for _, c in cats do
				c.grid.Visible = c == entry
			end
			catTitle.Text = entry.glyph .. "  " .. entry.name
			catTiles.Visible = false
			catView.Visible = true
		end
		closeCategory = function()
			catView.Visible = false
			catTiles.Visible = true
		end

		local btnOrder = 0
		local function tb(g, text, color, minLevel, action, getArgs)
			if not g or LEVEL < minLevel then
				return
			end
			btnOrder += 1
			button(g, text, color, function()
				if not selected then
					notify("Select a player first.", true)
					return
				end
				if getArgs then
					act(action, selected, getArgs())
				else
					act(action, selected)
				end
			end, { Size = UDim2.fromOffset(124, 36), LayoutOrder = btnOrder })
		end

		-- Moderation ------------------------------------------------------------
		local mod = category("Moderation", "🛡️", C.danger, 1)
		tb(mod, "🚪 Kick", C.danger, 1, "kick", function()
			return reasonBox.Text
		end)
		tb(mod, "🔨 Ban", C.danger, 2, "ban", function()
			return reasonBox.Text, tonumber(valueBox.Text) or 0
		end)
		tb(mod, "♻️ Respawn", C.item, 1, "respawn")
		tb(mod, "🧊 Freeze", C.item, 1, "freeze")
		tb(mod, "☀️ Unfreeze", C.item, 1, "unfreeze")
		tb(mod, "⛓️ Jail", C.warn, 2, "jail")
		tb(mod, "🔓 Unjail", C.item, 2, "unjail")

		-- Teleport --------------------------------------------------------------
		local tele = category("Teleport", "📍", C.accent, 1)
		tb(tele, "📍 Go To", C.accent, 1, "goto")
		tb(tele, "🧲 Bring", C.accent, 1, "bring")

		-- Character -------------------------------------------------------------
		local chr = category("Character", "🧍", C.good, 1)
		tb(chr, "🙈 Invisible", C.item, 1, "invisible", function()
			return true
		end)
		tb(chr, "👁️ Visible", C.item, 1, "invisible", function()
			return false
		end)
		tb(chr, "⚡ Set Speed", C.item, 1, "speed", function()
			return tonumber(valueBox.Text)
		end)
		tb(chr, "↩️ Reset Speed", C.item, 1, "speed", function()
			return 16
		end)
	end

	---------------------------------------------------------------------
	-- PAGE: Roles
	---------------------------------------------------------------------
	do
		local page = addPage("Roles", "roles", "Name tags above players' heads", 2)
		if page then
			local sc = scroller(page)

			local assign = card(sc, 1, "Give a role")
			label(
				assign,
				"Type a username or UserId (they can be offline), or pick a player in the Players tab first and it fills in automatically.",
				UDim2.new(1, 0, 0, 0),
				{
					AutomaticSize = Enum.AutomaticSize.Y,
					TextSize = 12,
					LayoutOrder = 1,
				}
			)
			local targetBox =
				textbox(assign, "Username or UserId", UDim2.new(1, 0, 0, 34), { LayoutOrder = 2 })
			button(assign, "✖ Remove this player's role", C.item, function()
				act("setrole", targetBox.Text, "")
			end, { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 3 })

			label(
				sc,
				"Level 0 = tag only   •   1 = Moderator   •   2 = Admin   •   3 = Owner",
				UDim2.new(1, 0, 0, 18),
				{
					TextSize = 12,
					LayoutOrder = 2,
				}
			)
			local roleGrid = grid(sc, 3, 206, 112)

			local function loadRoles()
				local ok, list = act("roles")
				if not ok or type(list) ~= "table" then
					return
				end
				clearChildren(roleGrid)
				for i, r in list do
					local col = hexColor(r.color)
					local f = new("Frame", {
						BackgroundColor3 = C.panel,
						BorderSizePixel = 0,
						LayoutOrder = i,
						Parent = roleGrid,
					}, { corner(12), stroke(col, 1.5, 0.45) })
					new("Frame", {
						Size = UDim2.new(1, 0, 0, 4),
						BackgroundColor3 = col,
						BorderSizePixel = 0,
						Parent = f,
					}, { corner(2) })
					icon(f, r.icon, 26, { Position = UDim2.new(0, 12, 0, 14) })
					label(f, r.name, UDim2.new(1, -90, 0, 20), {
						Font = Enum.Font.GothamBold,
						TextSize = 15,
						Color = col,
						Position = UDim2.new(0, 46, 0, 14),
						Wrap = false,
						Truncate = Enum.TextTruncate.AtEnd,
					})
					label(f, "Name tag", UDim2.new(1, -56, 0, 16), {
						TextSize = 11,
						Position = UDim2.new(0, 46, 0, 34),
						Wrap = false,
					})
					button(f, "🎁 Give role", col:Lerp(C.bg, 0.45), function()
						act("setrole", targetBox.Text, r.id)
					end, {
						Size = UDim2.new(1, -24, 0, 30),
						Position = UDim2.new(0, 12, 1, -40),
					})

					if LEVEL >= 3 then
						local del
						local armedUntil = 0
						del = button(
							f,
							"🗑",
							C.danger,
							function()
								if os.clock() > armedUntil then
									armedUntil = os.clock() + 3
									del.Text = "Sure?"
									task.delay(3.1, function()
										if del.Parent and os.clock() >= armedUntil then
											del.Text = "🗑"
										end
									end)
								else
									act("deleterole", r.id)
									loadRoles()
								end
							end,
							{ Size = UDim2.fromOffset(44, 24), Position = UDim2.new(1, -52, 0, 12) }
						)
						del.TextSize = 12
					end
				end
			end

			if LEVEL >= 3 then
				local create = card(sc, 4, "Create a new role")
				local row = wrapRow(create, 1)
				local nameBox =
					textbox(row, "Role name", UDim2.fromOffset(150, 34), { LayoutOrder = 1 })
				local iconBox =
					textbox(row, "Icon 🔥", UDim2.fromOffset(80, 34), { LayoutOrder = 2 })
				local colorBox =
					textbox(row, "Color FF8800", UDim2.fromOffset(110, 34), { LayoutOrder = 3 })
				button(row, "➕ Create Role", C.good, function()
					if act("createrole", nameBox.Text, iconBox.Text, colorBox.Text) then
						nameBox.Text, iconBox.Text, colorBox.Text = "", "", ""
						loadRoles()
					end
				end, { Size = UDim2.fromOffset(130, 34), LayoutOrder = 5 })
			end

			onShow.Roles = function()
				if selected and selected ~= "all" then
					targetBox.Text = selected
				end
				loadRoles()
			end
		end
	end

	---------------------------------------------------------------------
	-- PAGE: Server
	---------------------------------------------------------------------
	do
		local page = addPage("Server", "server", "Shut down this server", 2)
		if page then
			local sc = scroller(page)

			if LEVEL >= 3 then
				local danger = card(sc, 3, "Danger zone")
				local row = wrapRow(danger, 1)
				local sBox = textbox(
					row,
					"Reason (optional)",
					UDim2.fromOffset(200, 34),
					{ LayoutOrder = 1 }
				)
				local confirmUntil = 0
				local sBtn
				sBtn = button(row, "⛔ Shutdown Server", C.danger, function()
					if os.clock() > confirmUntil then
						confirmUntil = os.clock() + 3
						sBtn.Text = "Click to confirm"
						task.delay(3.1, function()
							if sBtn.Parent and os.clock() >= confirmUntil then
								sBtn.Text = "⛔ Shutdown Server"
							end
						end)
					else
						confirmUntil = 0
						act("shutdown", sBox.Text)
					end
				end, { Size = UDim2.fromOffset(160, 34), LayoutOrder = 2 })
			end
		end
	end

	---------------------------------------------------------------------
	-- PAGE: Announce
	---------------------------------------------------------------------
	do
		local page = addPage("Announce", "announce", "Send a banner message to everyone", 2)
		if page then
			local sc = scroller(page)
			local c1 = card(sc, 1, "Message")
			local box = textbox(
				c1,
				"Type your announcement...",
				UDim2.new(1, 0, 0, 110),
				{ MultiLine = true, LayoutOrder = 1 }
			)

			label(c1, "Quick templates", UDim2.new(1, 0, 0, 16), { TextSize = 12, LayoutOrder = 2 })
			local tpl = wrapRow(c1, 3)
			local templates = {
				{
					"🔧 Restart soon",
					"The server will restart soon. Please finish what you're doing!",
				},
				{ "🎉 Event", "An event is starting now. Join in and have fun!" },
				{ "👋 Welcome", "Welcome to the game! Please be kind and follow the rules." },
				{
					"⚠️ Rules",
					"Please follow the rules or you may be removed from the server.",
				},
			}
			for i, t in templates do
				button(tpl, t[1], C.item, function()
					box.Text = t[2]
				end, { Size = UDim2.fromOffset(130, 32), LayoutOrder = i })
			end

			local send = wrapRow(c1, 4)
			label(
				send,
				"Show for (seconds)",
				UDim2.fromOffset(130, 34),
				{ Color = C.text, LayoutOrder = 1, Wrap = false }
			)
			local dur = textbox(send, "8", UDim2.fromOffset(70, 34), { LayoutOrder = 2 })
			button(send, "📢 Send to Everyone", C.accent, function()
				if act("announce", box.Text, tonumber(dur.Text) or 8) then
					box.Text = ""
				end
			end, { Size = UDim2.fromOffset(170, 34), LayoutOrder = 3 })
		end
	end

	---------------------------------------------------------------------
	-- PAGE: Countdown
	---------------------------------------------------------------------
	do
		local page = addPage("Countdown", "countdown", "Show a big countdown to everyone", 2)
		if page then
			local sc = scroller(page)
			local c1 = card(sc, 1, "Start a countdown")
			label(
				c1,
				"Everyone sees a big number on their screen. Great for match starts, events and giveaways.",
				UDim2.new(1, 0, 0, 0),
				{
					AutomaticSize = Enum.AutomaticSize.Y,
					TextSize = 12,
					LayoutOrder = 1,
				}
			)
			local cdTitleBox = textbox(
				c1,
				"Title (default: Starting in)",
				UDim2.new(1, 0, 0, 34),
				{ LayoutOrder = 2 }
			)
			local finalBox = textbox(
				c1,
				"Message at zero (default: GO!)",
				UDim2.new(1, 0, 0, 34),
				{ LayoutOrder = 3 }
			)

			local secRow = wrapRow(c1, 4)
			label(
				secRow,
				"Seconds",
				UDim2.fromOffset(70, 34),
				{ Color = C.text, LayoutOrder = 1, Wrap = false }
			)
			local secBox = textbox(secRow, "10", UDim2.fromOffset(80, 34), { LayoutOrder = 2 })
			secBox.Text = "10"
			for i, s in { 3, 5, 10, 30, 60 } do
				button(secRow, s .. "s", C.item, function()
					secBox.Text = tostring(s)
				end, { Size = UDim2.fromOffset(52, 34), LayoutOrder = 2 + i })
			end

			local go = wrapRow(c1, 5)
			button(go, "▶ Start Countdown", C.accent, function()
				act("countdown", tonumber(secBox.Text) or 10, cdTitleBox.Text, finalBox.Text)
			end, { Size = UDim2.fromOffset(170, 34), LayoutOrder = 1 })
			button(go, "✖ Cancel", C.danger, function()
				act("cancelcountdown")
			end, { Size = UDim2.fromOffset(110, 34), LayoutOrder = 2 })

			local info = card(sc, 2, "For your own game scripts")
			label(
				info,
				"While a countdown is running, Workspace has an attribute called AdminCountdownEndsAt (a Workspace:GetServerTimeNow() timestamp). Your game can wait for it to pass to start a round.",
				UDim2.new(1, 0, 0, 0),
				{
					AutomaticSize = Enum.AutomaticSize.Y,
					TextSize = 12,
					LayoutOrder = 1,
				}
			)
		end
	end

	---------------------------------------------------------------------
	-- PAGE: Poll
	---------------------------------------------------------------------
	do
		local page = addPage("Poll", "poll", "Ask everyone a question and count the votes", 2)
		if page then
			local sc = scroller(page)
			local refresh

			local form = card(sc, 1, "Create a poll")
			local qBox = textbox(
				form,
				"Question (e.g. Which map next?)",
				UDim2.new(1, 0, 0, 36),
				{ LayoutOrder = 1 }
			)
			local optBoxes = {}
			for i = 1, 4 do
				optBoxes[i] = textbox(
					form,
					"Option " .. i .. (i > 2 and " (optional)" or ""),
					UDim2.new(1, 0, 0, 34),
					{ LayoutOrder = 1 + i }
				)
			end
			local row = wrapRow(form, 6)
			label(
				row,
				"Seconds",
				UDim2.fromOffset(70, 34),
				{ Color = C.text, LayoutOrder = 1, Wrap = false }
			)
			local durBox = textbox(row, "30", UDim2.fromOffset(80, 34), { LayoutOrder = 2 })
			durBox.Text = "30"
			button(row, "📊 Start Poll", C.accent, function()
				local opts = {}
				for i, b in optBoxes do
					opts[i] = b.Text
				end
				if act("startpoll", qBox.Text, opts, tonumber(durBox.Text) or 30) then
					refresh()
				end
			end, { Size = UDim2.fromOffset(130, 34), LayoutOrder = 3 })
			button(row, "⏹ End Now", C.danger, function()
				act("endpoll")
				refresh()
			end, { Size = UDim2.fromOffset(110, 34), LayoutOrder = 4 })

			local res = card(sc, 2, "Results")
			local status = label(res, "", UDim2.new(1, 0, 0, 0), {
				AutomaticSize = Enum.AutomaticSize.Y,
				TextSize = 12,
				LayoutOrder = 1,
			})
			local holder = new("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
				Parent = res,
			}, {
				new(
					"UIListLayout",
					{ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }
				),
			})

			refresh = function()
				local ok, data = act("pollstatus")
				if not ok or type(data) ~= "table" then
					return
				end
				clearChildren(holder)
				if not data.options then
					status.Text =
						"No poll yet. Create one above - every player gets a voting panel on their screen."
					return
				end
				local total = 0
				for _, c in data.counts do
					total += c
				end
				if data.active then
					status.Text = "🟢 Running - "
						.. data.remaining
						.. "s left  •  "
						.. total
						.. " vote(s)\n"
						.. data.question
				else
					local verdict = data.tie and "It was a tie."
						or (
							data.winner and ("Winner: " .. data.options[data.winner])
							or "Nobody voted."
						)
					status.Text = "🏁 Finished  •  "
						.. total
						.. " vote(s)  •  "
						.. verdict
						.. "\n"
						.. data.question
				end
				for i, opt in data.options do
					local c = data.counts[i] or 0
					local frac = total > 0 and c / total or 0
					local isWinner = not data.active and data.winner == i
					local r = new("Frame", {
						Size = UDim2.new(1, 0, 0, 38),
						BackgroundColor3 = C.item,
						BorderSizePixel = 0,
						LayoutOrder = i,
						Parent = holder,
					}, { corner(8) })
					new("Frame", {
						Size = UDim2.new(frac, 0, 1, 0),
						BackgroundColor3 = isWinner and C.good or C.accent,
						BackgroundTransparency = 0.45,
						BorderSizePixel = 0,
						Parent = r,
					}, { corner(8) })
					label(r, opt, UDim2.new(1, -110, 1, 0), {
						Font = Enum.Font.GothamBold,
						Color = C.text,
						Position = UDim2.new(0, 12, 0, 0),
						Wrap = false,
						Truncate = Enum.TextTruncate.AtEnd,
					})
					label(
						r,
						c .. "  •  " .. math.floor(frac * 100 + 0.5) .. "%",
						UDim2.new(0, 96, 1, 0),
						{
							Color = C.text,
							Align = Enum.TextXAlignment.Right,
							Position = UDim2.new(1, -106, 0, 0),
							Wrap = false,
						}
					)
				end
			end

			onShow.Poll = refresh
			task.spawn(function()
				while alive do
					task.wait(1)
					if page.Visible then
						refresh()
					end
				end
			end)
		end
	end

	---------------------------------------------------------------------
	-- PAGE: Bans
	---------------------------------------------------------------------
	do
		local page = addPage("Bans", "bans", "Ban and unban players", 2)
		if page then
			local sc = scroller(page)

			local form = card(sc, 1, "Ban a player")
			local row = wrapRow(form, 1)
			local userBox =
				textbox(row, "Username or UserId", UDim2.fromOffset(170, 34), { LayoutOrder = 1 })
			local reasonBox = textbox(row, "Reason", UDim2.fromOffset(190, 34), { LayoutOrder = 2 })
			local minBox = textbox(
				row,
				"Minutes (0 = forever)",
				UDim2.fromOffset(150, 34),
				{ LayoutOrder = 3 }
			)
			label(
				form,
				"You can ban players who aren't in the server.",
				UDim2.new(1, 0, 0, 16),
				{ TextSize = 12, LayoutOrder = 2 }
			)

			local listCard = card(sc, 2, "Banned players")
			local listHolder = new("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
				Parent = listCard,
			}, {
				new(
					"UIListLayout",
					{ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }
				),
			})

			local function refresh()
				local ok, data = act("banlist")
				if not ok or type(data) ~= "table" then
					return
				end
				clearChildren(listHolder)
				if #data == 0 then
					label(
						listHolder,
						"Nobody is banned. 🎉",
						UDim2.new(1, 0, 0, 24),
						{ LayoutOrder = 1 }
					)
				end
				for i, b in data do
					local r = new("Frame", {
						Size = UDim2.new(1, 0, 0, 54),
						BackgroundColor3 = C.item,
						BorderSizePixel = 0,
						LayoutOrder = i,
						Parent = listHolder,
					}, { corner(8) })
					label(r, b.name .. "  (" .. b.userId .. ")", UDim2.new(1, -96, 0, 20), {
						Font = Enum.Font.GothamBold,
						Color = C.text,
						Position = UDim2.new(0, 12, 0, 7),
						Wrap = false,
						Truncate = Enum.TextTruncate.AtEnd,
					})
					label(
						r,
						b.reason .. "  •  " .. b.expires .. "  •  by " .. b.by,
						UDim2.new(1, -96, 0, 18),
						{
							TextSize = 11,
							Position = UDim2.new(0, 12, 0, 28),
							Wrap = false,
							Truncate = Enum.TextTruncate.AtEnd,
						}
					)
					local ub = button(r, "Unban", C.good, function()
						if act("unban", b.userId) then
							r:Destroy()
						end
					end, { Size = UDim2.fromOffset(70, 30) })
					ub.AnchorPoint = Vector2.new(1, 0.5)
					ub.Position = UDim2.new(1, -10, 0.5, 0)
				end
			end

			button(row, "🔨 Ban", C.danger, function()
				if act("ban", userBox.Text, reasonBox.Text, tonumber(minBox.Text) or 0) then
					userBox.Text, reasonBox.Text, minBox.Text = "", "", ""
					refresh()
				end
			end, { Size = UDim2.fromOffset(90, 34), LayoutOrder = 4 })
			button(
				row,
				"🔄 Refresh",
				C.item,
				refresh,
				{ Size = UDim2.fromOffset(100, 34), LayoutOrder = 5 }
			)

			onShow.Bans = refresh
		end
	end

	---------------------------------------------------------------------
	-- PAGE: Logs
	---------------------------------------------------------------------
	do
		local page = addPage("Logs", "logs", "What admins did on this server", 1)
		local sc = scroller(page)
		local top = wrapRow(sc, 1)
		local holder = new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = sc,
		}, {
			new(
				"UIListLayout",
				{ Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }
			),
		})

		local function refresh()
			local ok, data = act("logs")
			if not ok or type(data) ~= "table" then
				return
			end
			clearChildren(holder)
			if #data == 0 then
				label(
					holder,
					"No admin actions yet this session.",
					UDim2.new(1, 0, 0, 24),
					{ LayoutOrder = 1 }
				)
			end
			for i, line in data do
				new("TextLabel", {
					BackgroundColor3 = C.panel,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Text = line,
					Font = Enum.Font.Gotham,
					TextSize = 12,
					TextColor3 = C.text,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					LayoutOrder = i,
					Parent = holder,
				}, { corner(8), pad(10, 8) })
			end
		end
		button(top, "🔄 Refresh", C.item, refresh, { Size = UDim2.fromOffset(110, 34) })
		onShow.Logs = refresh
	end

	---------------------------------------------------------------------
	-- PAGE: Settings (themes + interface size)
	---------------------------------------------------------------------
	do
		local page = addPage("Settings", "settings", "Themes and interface size", 1, true)
		local sc = scroller(page)

		local sizeCard = card(sc, 1, "Interface size")
		label(
			sizeCard,
			"The panel auto-fits your screen (phones, tablets, PC). Use these to make it a bit smaller or bigger.",
			UDim2.new(1, 0, 0, 0),
			{
				AutomaticSize = Enum.AutomaticSize.Y,
				TextSize = 12,
				LayoutOrder = 1,
			}
		)
		local sizeRow = wrapRow(sizeCard, 2)
		local sizes = { { "Small", 0.8 }, { "Normal", 1 }, { "Large", 1.2 } }
		for i, opt in sizes do
			local isCurrent = math.abs((prefs.scale or 1) - opt[2]) < 0.01
			button(
				sizeRow,
				(isCurrent and "✓ " or "") .. opt[1],
				isCurrent and C.accent or C.item,
				function()
					prefs.scale = opt[2]
					updateRootScale()
					act("setprefs", currentTheme, opt[2])
					task.defer(requestRebuild)
				end,
				{ Size = UDim2.fromOffset(110, 34), LayoutOrder = i }
			)
		end

		local themeCard = card(sc, 2, "Themes")
		local tg = grid(themeCard, 1, 150, 84)
		for i, t in THEMES do
			local col = t.c
			local isCurrent = t.name == currentTheme
			local b = new("TextButton", {
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = hexColor(col.panel),
				LayoutOrder = i,
				Parent = tg,
			}, {
				corner(10),
				stroke(
					isCurrent and hexColor(col.accent) or hexColor(col.line),
					isCurrent and 2.5 or 1,
					isCurrent and 0 or 0.35
				),
			})
			local keys = { "bg", "accent", "accent2", "text" }
			for j, key in keys do
				new("Frame", {
					Size = UDim2.fromOffset(20, 20),
					Position = UDim2.new(0, 10 + (j - 1) * 24, 0, 12),
					BackgroundColor3 = hexColor(col[key]),
					BorderSizePixel = 0,
					Parent = b,
				}, { corner(10), stroke(hexColor(col.line), 1, 0.4) })
			end
			label(b, (isCurrent and "✓ " or "") .. t.name, UDim2.new(1, -20, 0, 22), {
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				Color = hexColor(col.text),
				Position = UDim2.new(0, 10, 1, -32),
				Wrap = false,
			})
			b.MouseButton1Click:Connect(function()
				applyTheme(t.name)
				prefs.theme = t.name
				act("setprefs", t.name, prefs.scale or 1)
				task.defer(requestRebuild)
			end)
		end

		local about = card(sc, 3, "About")
		label(
			about,
			"Toggle key: "
				.. keyName
				.. "   •   Your level: "
				.. LEVEL
				.. " ("
				.. (LEVEL_NAMES[LEVEL] or "Admin")
				.. ")   •   Theme: "
				.. currentTheme,
			UDim2.new(1, 0, 0, 0),
			{
				AutomaticSize = Enum.AutomaticSize.Y,
				TextSize = 12,
				LayoutOrder = 1,
			}
		)
	end

	---------------------------------------------------------------------
	-- Open / close
	---------------------------------------------------------------------
	local function setOpen(open)
		if open then
			main.Visible = true
			relayout()
			pop.Scale = 0.92
			TweenService:Create(
				pop,
				TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
			if currentPage and onShow[currentPage] then
				task.spawn(onShow[currentPage])
			end
		else
			main.Visible = false
		end
		if onVisibility then
			onVisibility(main.Visible)
		end
	end
	closeBtn.MouseButton1Click:Connect(function()
		setOpen(false)
	end)
	track(main:GetPropertyChangedSignal("Visible"):Connect(function()
		if onVisibility then
			onVisibility(main.Visible)
		end
	end))

	local okKey, toggleKey = pcall(function()
		return Enum.KeyCode[keyName]
	end)
	track(UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if okKey and toggleKey and input.KeyCode == toggleKey then
			setOpen(not main.Visible)
		end
	end))

	relayout()
	showPage((startPage and pages[startPage]) and startPage or "Home")
	if startOpen then
		setOpen(true)
	end

	-- Cleanup handle
	return {
		isOpen = function()
			return main.Visible
		end,
		toggle = function()
			setOpen(not main.Visible)
		end,
		page = function()
			return currentPage
		end,
		destroy = function()
			alive = false
			for _, c in conns do
				c:Disconnect()
			end
			stopFly()
			if noclipConn then
				noclipConn:Disconnect()
			end
			gui:Destroy()
		end,
	}
end

---------------------------------------------------------------------
-- Roblox top bar button (lives inside the top bar)
---------------------------------------------------------------------
local topbarGui, topbarBtn
local topbarAlign = "Left"
local function setupTopbarButton(align)
	if topbarGui then
		return
	end
	topbarAlign = align == "Right" and "Right" or "Left"
	local GuiService = game:GetService("GuiService")
	local GAP = 8

	topbarGui = new("ScreenGui", {
		Name = "AdminPanelTopbar",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 99,
		Parent = playerGui,
	})
	topbarBtn = new("TextButton", {
		Name = "AdminButton",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Color3.fromRGB(18, 18, 21),
		BackgroundTransparency = 0.3,
		Parent = topbarGui,
	}, { corner(22), stroke(Color3.fromRGB(255, 255, 255), 1, 0.9) })
	local topCorner = topbarBtn:FindFirstChildOfClass("UICorner")
	local logo = icon(topbarBtn, ICONS.logo, 26, { Position = UDim2.new(0.5, -13, 0.5, -13) })
	local glow = stroke(C.accent2, 2, 1)
	glow.Parent = topbarBtn

	-- GuiService.TopbarInset is the free space INSIDE Roblox's top bar (Roblox's own icons are
	-- outside it and it moves when menus open), so the button always sits in the bar, vertically centred.
	local function place()
		local size, x, y = 44, 12 + 44 + GAP, 7
		local ok, inset = pcall(function()
			return GuiService.TopbarInset
		end)
		if ok and inset and inset.Height > 10 then
			if inset.Height >= 56 then
				size = 44
				y = inset.Min.Y + 12 -- Roblox's own icons are 44px tall, 12px below the top edge
			else
				size = math.clamp(math.floor(inset.Height) - 8, 28, 44)
				y = inset.Min.Y + math.floor((inset.Height - size) / 2)
			end
			if topbarAlign == "Right" then
				-- the FPS + ping pills (shown to every player) occupy the far right end
				x = inset.Max.X - GAP - (82 * 2 + GAP) - GAP - size
			else
				x = inset.Min.X + GAP
			end
		end
		topbarBtn.Size = UDim2.fromOffset(size, size)
		topbarBtn.Position = UDim2.fromOffset(x, y)
		topCorner.CornerRadius = UDim.new(0, size / 2)
		local g = math.floor(size * 0.6)
		logo.Size = UDim2.fromOffset(g, g)
		logo.Position = UDim2.new(0.5, -g / 2, 0.5, -g / 2)
		if logo:IsA("TextLabel") then
			logo.TextSize = math.floor(g * 0.8)
		end
	end
	place()
	pcall(function()
		GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)
	end)
	pcall(function()
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
	end)

	topbarBtn.MouseEnter:Connect(function()
		TweenService:Create(topbarBtn, TweenInfo.new(0.12), { BackgroundTransparency = 0.05 })
			:Play()
	end)
	topbarBtn.MouseLeave:Connect(function()
		TweenService:Create(topbarBtn, TweenInfo.new(0.12), { BackgroundTransparency = 0.3 }):Play()
	end)
	topbarBtn.MouseButton1Click:Connect(function()
		if current then
			current.toggle()
		end
	end)
	onVisibility = function(open)
		TweenService:Create(glow, TweenInfo.new(0.15), { Transparency = open and 0.1 or 1 }):Play()
		TweenService:Create(topbarBtn, TweenInfo.new(0.15), {
			BackgroundColor3 = open and C.accent:Lerp(Color3.new(0, 0, 0), 0.5)
				or Color3.fromRGB(18, 18, 21),
		}):Play()
	end
end

---------------------------------------------------------------------
-- Start up + react to level changes (e.g. someone gives you a role)
---------------------------------------------------------------------
local lastCfg
local lastLevel

local function rebuild(level, cfg)
	if cfg then
		lastCfg = cfg
	end
	lastLevel = level
	local wasOpen, page = false, nil
	if current then
		wasOpen = current.isOpen()
		page = current.page()
		current.destroy()
		current = nil
	end
	if level >= 1 and lastCfg then
		current = build(level, lastCfg, wasOpen, page)
		setupTopbarButton(lastCfg.topbarAlign)
		topbarGui.Enabled = true
	elseif topbarGui then
		topbarGui.Enabled = false
	end
end

-- Used when the theme / size changes: rebuild but keep the panel open on the same tab.
requestRebuild = function()
	if lastLevel then
		rebuild(lastLevel)
	end
end

local ok, success, data = pcall(remote.InvokeServer, remote, "init")
if ok and success and type(data) == "table" and type(data.level) == "number" then
	if type(data.prefs) == "table" then
		prefs = data.prefs
		if prefs.theme then
			applyTheme(prefs.theme)
		end
	end
	rebuild(data.level, data)
else
	warn("[AdminPanel] Could not reach the server: " .. tostring(success))
end

---------------------------------------------------------------------
-- FPS + ping pills in the top bar (only admins get this script)
---------------------------------------------------------------------
do
	local GuiService = game:GetService("GuiService")
	local GAP, PILL_W = 8, 82
	local GREEN, ORANGE, RED =
		Color3.fromRGB(24, 224, 130), Color3.fromRGB(245, 166, 35), Color3.fromRGB(255, 59, 83)

	local statsGui = Instance.new("ScreenGui")
	statsGui.Name = "AdminStats"
	statsGui.ResetOnSpawn = false
	statsGui.DisplayOrder = 98
	statsGui.IgnoreGuiInset = true
	statsGui.Parent = playerGui
	local function makePill(name)
		local f = Instance.new("Frame")
		f.Name = name
		f.Size = UDim2.fromOffset(PILL_W, 44)
		f.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
		f.BackgroundTransparency = 0.3
		f.Parent = statsGui
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 22)
		c.Parent = f
		local st = Instance.new("UIStroke")
		st.Color = Color3.new(1, 1, 1)
		st.Transparency = 0.9
		st.Parent = f
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Font = Enum.Font.GothamBold
		l.TextSize = 14
		l.TextColor3 = GREEN
		l.Parent = f
		return f, l, c
	end
	local pingPill, pingLabel, pingCorner = makePill("PingCounter")
	local fpsPill, fpsLabel, fpsCorner = makePill("FpsCounter")
	pingLabel.Text = "-- ms"
	fpsLabel.Text = "-- FPS"

	local function updatePing()
		local ping = player:GetAttribute("AdminPing")
		if type(ping) == "number" then
			pingLabel.Text = ping .. " ms"
			pingLabel.TextColor3 = ping <= 100 and GREEN or (ping <= 200 and ORANGE or RED)
		else
			pingLabel.Text = "-- ms"
		end
	end
	updatePing()
	player:GetAttributeChangedSignal("AdminPing"):Connect(updatePing)

	local frames, acc = 0, 0
	RunService.RenderStepped:Connect(function(dt)
		frames += 1
		acc += dt
		if acc >= 0.5 then
			local fps = math.floor(frames / acc + 0.5)
			frames, acc = 0, 0
			fpsLabel.Text = fps .. " FPS"
			fpsLabel.TextColor3 = fps >= 50 and GREEN or (fps >= 30 and ORANGE or RED)
		end
	end)

	-- sit at the right end of the free space inside Roblox's top bar (same row as the other icons)
	local function place()
		statsGui.Enabled = playerGui:FindFirstChild("AdminPanelTopbar") ~= nil
		local size, y, right = 44, 12, statsGui.AbsoluteSize.X
		local room = true
		local insetOk, inset = pcall(function()
			return GuiService.TopbarInset
		end)
		if insetOk and inset and inset.Height > 10 then
			if inset.Height >= 56 then
				y = inset.Min.Y + 12
			else
				size = math.clamp(math.floor(inset.Height) - 8, 28, 44)
				y = inset.Min.Y + math.floor((inset.Height - size) / 2)
			end
			right = inset.Max.X
			-- leave space for the admin panel button when this player is an admin and it sits on the left
			local adminGui = playerGui:FindFirstChild("AdminPanelTopbar")
			local reserved = (adminGui and adminGui.Enabled) and (size + GAP) or 0
			room = inset.Width >= reserved + PILL_W * 2 + GAP * 3
		end
		fpsPill.Visible = room
		pingPill.Visible = room
		for _, pair in { { fpsPill, fpsCorner }, { pingPill, pingCorner } } do
			pair[1].Size = UDim2.fromOffset(PILL_W, size)
			pair[2].CornerRadius = UDim.new(0, size / 2)
		end
		fpsPill.Position = UDim2.fromOffset(right - PILL_W - GAP, y)
		pingPill.Position = UDim2.fromOffset(right - PILL_W * 2 - GAP * 2, y)
	end
	place()
	pcall(function()
		GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)
	end)
	playerGui.ChildAdded:Connect(function()
		task.defer(place)
	end)
	task.spawn(function()
		while true do
			task.wait(2)
			place()
		end
	end)
end
