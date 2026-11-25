--!strict
-- Lock screen for a phone page whose feature isn't unlocked yet (see shared Unlocks). It covers
-- the page under the header (so the back button still works), shows why it's locked and a live
-- countdown, and disappears by itself once the feature unlocks.
--
--   LockedOverlay.attach(page, "Games")

local PhoneUi = require(script.Parent.PhoneUi)
local UnlockController =
	require(script.Parent.Parent.Parent.controllers.progression.UnlockController)
local Unlocks = require(game:GetService("ReplicatedStorage").Shared.progression.Unlocks)

local HEADER = 44
-- Under the QR scanner (20) so a scan plays first, above the page's own content.
local Z_INDEX = 15

local LockedOverlay = {}

function LockedOverlay.attach(page: Frame, featureId: string)
	local overlay = PhoneUi.button("Locked", page)
	overlay.Position = UDim2.fromOffset(0, HEADER)
	overlay.Size = UDim2.new(1, 0, 1, -HEADER)
	overlay.BackgroundColor3 = PhoneUi.INK
	overlay.BackgroundTransparency = 0
	overlay.AutoButtonColor = false
	overlay.ZIndex = Z_INDEX -- also swallows taps meant for the page underneath

	local lock = PhoneUi.label("Icon", overlay, "🔒", 54)
	lock.Position = UDim2.new(0, 0, 0.18, 0)
	lock.Size = UDim2.new(1, 0, 0, 64)

	local title = PhoneUi.label("Title", overlay, "Locked", 22)
	title.Position = UDim2.new(0, 0, 0.18, 70)
	title.Size = UDim2.new(1, 0, 0, 28)

	local message = PhoneUi.label("Message", overlay, "", 14)
	message.FontFace = PhoneUi.FONT_REGULAR
	message.Position = UDim2.new(0, 24, 0.18, 104)
	message.Size = UDim2.new(1, -48, 0, 40)
	message.TextWrapped = true
	message.TextTruncate = Enum.TextTruncate.None
	message.TextTransparency = 0.2

	local countdown = PhoneUi.label("Countdown", overlay, "", 40)
	countdown.Position = UDim2.new(0, 0, 0.18, 156)
	countdown.Size = UDim2.new(1, 0, 0, 46)
	countdown.TextColor3 = PhoneUi.ACCENT

	local bar = PhoneUi.frame("Bar", overlay)
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0.18, 210)
	bar.Size = UDim2.fromOffset(180, 6)
	bar.BackgroundTransparency = 0.8
	bar.BackgroundColor3 = PhoneUi.WHITE
	PhoneUi.corner(bar)
	local fill = PhoneUi.frame("Fill", bar)
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundTransparency = 0
	fill.BackgroundColor3 = PhoneUi.ACCENT
	PhoneUi.corner(fill)

	local feature = Unlocks.Features[featureId]
	local totalSeconds = if feature and feature.Requirement.Minutes
		then feature.Requirement.Minutes * 60
		else 0

	local function refresh()
		local status = UnlockController.status(featureId)
		overlay.Visible = not status.unlocked
		if status.unlocked then
			return
		end
		message.Text = status.message
		if status.remaining and totalSeconds > 0 then
			countdown.Text = Unlocks.formatTime(status.remaining)
			fill.Size = UDim2.fromScale(1 - status.remaining / totalSeconds, 1)
			bar.Visible = true
		else
			countdown.Text = if status.price then `{status.price} coins` else ""
			bar.Visible = false
		end
	end
	refresh()
	UnlockController.Changed:Connect(function(id: string)
		if id == featureId then
			refresh()
		end
	end)
	-- Tick the countdown while the page is showing.
	task.spawn(function()
		while overlay.Parent do
			if page.Visible and overlay.Visible then
				refresh()
			end
			task.wait(1)
		end
	end)
end

return LockedOverlay
