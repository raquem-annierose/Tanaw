--!strict
-- Shared look for the phone: colors, fonts and small builders used by every app.

local PhoneUi = {}

PhoneUi.WHITE = Color3.fromRGB(255, 255, 255)
-- Warm string-light color, same mood as the overlook.
PhoneUi.ACCENT = Color3.fromRGB(255, 200, 120)
PhoneUi.INK = Color3.fromRGB(16, 14, 22)
PhoneUi.FONT = Font.fromEnum(Enum.Font.BuilderSansBold)
PhoneUi.FONT_REGULAR = Font.fromEnum(Enum.Font.BuilderSans)

function PhoneUi.corner(parent: GuiObject, radius: UDim?)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(1, 0)
	c.Parent = parent
end

function PhoneUi.frame(name: string, parent: Instance): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 1
	f.Parent = parent
	return f
end

function PhoneUi.label(name: string, parent: Instance, text: string, textSize: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.FontFace = PhoneUi.FONT
	l.Text = text
	l.TextSize = textSize
	l.TextColor3 = PhoneUi.WHITE
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

function PhoneUi.button(name: string, parent: Instance): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b.Selectable = true
	b.Text = ""
	b.FontFace = PhoneUi.FONT
	b.TextColor3 = PhoneUi.WHITE
	b.Parent = parent
	return b
end

-- Top row of an app page: "‹" back button and the app's name.
function PhoneUi.header(page: Frame, title: string, onBack: () -> ())
	local back = PhoneUi.button("Back", page)
	back.Position = UDim2.fromOffset(8, 4)
	back.Size = UDim2.fromOffset(36, 36)
	back.BackgroundTransparency = 1
	back.Text = "‹"
	back.TextSize = 34
	back.Activated:Connect(onBack)

	local name = PhoneUi.label("Title", page, title, 22)
	name.Position = UDim2.fromOffset(44, 4)
	name.Size = UDim2.new(1, -60, 0, 36)
	name.TextXAlignment = Enum.TextXAlignment.Left
end

return PhoneUi
