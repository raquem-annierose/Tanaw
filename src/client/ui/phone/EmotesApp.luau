--!strict
-- Emotes app: a grid of emotes. Tap one to play it, tap it again (or walk) to stop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmoteController = require(script.Parent.Parent.Parent.controllers.EmoteController)
local Emotes = require(ReplicatedStorage.Shared.Emotes)
local PhoneUi = require(script.Parent.PhoneUi)

local EmotesApp = {}

function EmotesApp.build(page: Frame, goHome: () -> ())
	PhoneUi.header(page, "Emotes", goHome)

	local grid = PhoneUi.frame("Grid", page)
	grid.Position = UDim2.fromOffset(16, 52)
	grid.Size = UDim2.new(1, -32, 1, -60)

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.5, -6, 0, 64)
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local buttons: { [string]: TextButton } = {}
	for order, emote in Emotes.List do
		local b = PhoneUi.button(emote.Id, grid)
		b.LayoutOrder = order
		b.BackgroundColor3 = PhoneUi.WHITE
		b.BackgroundTransparency = 0.85
		b.TextSize = 18
		b.Text = `{emote.Icon}  {emote.Label}`
		PhoneUi.corner(b, UDim.new(0, 18))
		b.Activated:Connect(function()
			EmoteController.play(emote.Id)
		end)
		buttons[emote.Id] = b
	end

	local hint = PhoneUi.label("Hint", page, "Walk or tap again to stop", 13)
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -8)
	hint.Size = UDim2.new(1, -32, 0, 16)
	hint.FontFace = PhoneUi.FONT_REGULAR
	hint.TextTransparency = 0.35

	local function highlight(current: string?)
		for id, b in buttons do
			local on = id == current
			b.BackgroundColor3 = if on then PhoneUi.ACCENT else PhoneUi.WHITE
			b.BackgroundTransparency = if on then 0.1 else 0.85
			b.TextColor3 = if on then PhoneUi.INK else PhoneUi.WHITE
		end
	end
	EmoteController.Changed:Connect(highlight)
	highlight(EmoteController.getCurrent())
end

return EmotesApp
