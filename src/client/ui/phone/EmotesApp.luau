--!strict
-- Emotes app: a plain settings-style list, grouped into Gestures and Dances.
-- Tap a row to play it; the playing row shows "Playing". Tap it again (or walk) to stop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmoteController = require(script.Parent.Parent.Parent.controllers.EmoteController)
local Emotes = require(ReplicatedStorage.Shared.Emotes)
local PhoneUi = require(script.Parent.PhoneUi)

local ROW_HEIGHT = 44

local EmotesApp = {}

type Row = { button: TextButton, label: TextLabel, status: TextLabel }

function EmotesApp.build(page: Frame, goHome: () -> ())
	PhoneUi.header(page, "Emotes", goHome)

	local list = PhoneUi.frame("List", page)
	list.Position = UDim2.fromOffset(16, 52)
	list.Size = UDim2.new(1, -32, 1, -60)

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = list

	local rows: { [string]: Row } = {}
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	for _, group in Emotes.Groups do
		local heading = PhoneUi.label(`{group}Heading`, list, string.upper(group), 12)
		heading.LayoutOrder = nextOrder()
		heading.Size = UDim2.new(1, 0, 0, 22)
		heading.TextXAlignment = Enum.TextXAlignment.Left
		heading.TextYAlignment = Enum.TextYAlignment.Bottom
		heading.TextTransparency = 0.45
		local inset = Instance.new("UIPadding")
		inset.PaddingLeft = UDim.new(0, 14)
		inset.Parent = heading

		local card = PhoneUi.frame(group, list)
		card.LayoutOrder = nextOrder()
		card.AutomaticSize = Enum.AutomaticSize.Y
		card.Size = UDim2.fromScale(1, 0)
		card.BackgroundTransparency = 0.9
		card.BackgroundColor3 = PhoneUi.WHITE
		card.ClipsDescendants = true
		PhoneUi.corner(card, UDim.new(0, 14))

		local cardLayout = Instance.new("UIListLayout")
		cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
		cardLayout.Parent = card

		local first = true
		for index, emote in Emotes.List do
			if emote.Group ~= group then
				continue
			end
			if not first then
				-- Hairline between rows, inset from the left like iOS lists.
				local line = PhoneUi.frame("Separator", card)
				line.LayoutOrder = index * 2 - 1
				line.Size = UDim2.new(1, 0, 0, 1)
				local hair = PhoneUi.frame("Hair", line)
				hair.Position = UDim2.fromOffset(14, 0)
				hair.Size = UDim2.new(1, -14, 1, 0)
				hair.BackgroundTransparency = 0.88
				hair.BackgroundColor3 = PhoneUi.WHITE
			end
			first = false

			local button = PhoneUi.button(emote.Id, card)
			button.LayoutOrder = index * 2
			button.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
			button.BackgroundTransparency = 1
			button.BackgroundColor3 = PhoneUi.WHITE

			local label = PhoneUi.label("Name", button, emote.Label, 16)
			label.Position = UDim2.fromOffset(14, 0)
			label.Size = UDim2.new(1, -110, 1, 0)
			label.FontFace = PhoneUi.FONT_REGULAR
			label.TextXAlignment = Enum.TextXAlignment.Left

			local status = PhoneUi.label("Status", button, "", 13)
			status.AnchorPoint = Vector2.new(1, 0)
			status.Position = UDim2.new(1, -14, 0, 0)
			status.Size = UDim2.new(0, 90, 1, 0)
			status.TextXAlignment = Enum.TextXAlignment.Right
			status.TextColor3 = PhoneUi.ACCENT

			button.MouseButton1Down:Connect(function()
				button.BackgroundTransparency = 0.9
			end)
			local function unpress()
				button.BackgroundTransparency = 1
			end
			button.MouseButton1Up:Connect(unpress)
			button.MouseLeave:Connect(unpress)
			button.Activated:Connect(function()
				EmoteController.play(emote.Id)
			end)

			rows[emote.Id] = { button = button, label = label, status = status }
		end
	end

	local function highlight(current: string?)
		for id, row in rows do
			local on = id == current
			row.label.FontFace = if on then PhoneUi.FONT else PhoneUi.FONT_REGULAR
			row.label.TextColor3 = if on then PhoneUi.ACCENT else PhoneUi.WHITE
			row.status.Text = if on then "Playing" else ""
		end
	end
	EmoteController.Changed:Connect(highlight)
	highlight(EmoteController.getCurrent())
end

return EmotesApp
