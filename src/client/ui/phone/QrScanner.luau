--!strict
-- Quick "scan the QR" animation shown on top of a phone page: a camera view with a scan box,
-- the QR sign slides and focuses into the box, the box snaps green with a flash, then the
-- scanner slides away to reveal the page (about one second). Players with Reduced Motion on
-- skip straight to the page.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local PhoneUi = require(script.Parent.PhoneUi)
local QrCode = require(ReplicatedStorage.Shared.QrCode)

local BOX = 176
local BOX_Y = 0.46
local CELL = 6
local BRACKET = 30
local BRACKET_WIDTH = 4
local GREEN = Color3.fromRGB(90, 220, 120)
local QR_INK = Color3.fromRGB(28, 24, 30)

local QrScanner = {}

-- What the scanned sign looks like. pattern can be changed later with setPattern (e.g. one QR
-- per photo).
export type Options = {
	title: string,
	subtitle: string,
	pattern: QrCode.Pattern,
	frameColor: Color3,
	cardColor: Color3,
	titleColor: Color3,
	subtitleColor: Color3,
	doneText: string?,
}

export type Scanner = {
	-- startDelay: seconds to hold the camera view before aiming (e.g. while the phone slides in).
	play: (onDone: () -> (), startDelay: number?) -> (),
	setPattern: (pattern: QrCode.Pattern) -> (),
}

local function tween(
	instance: Instance,
	seconds: number,
	style: Enum.EasingStyle,
	goals: { [string]: any }
): Tween
	local t = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style, Enum.EasingDirection.Out),
		goals
	)
	t:Play()
	return t
end

-- The QR sign as seen through the camera: frame, card, the same QR as the real sign. Returns the
-- sign, its focus haze and the QR frame (to redraw the code).
local function buildSign(parent: Frame, options: Options): (Frame, Frame, Frame)
	local qrPixels = #options.pattern * CELL
	local width = qrPixels + 32
	local height = qrPixels + 76

	local sign = PhoneUi.frame("Sign", parent)
	sign.Size = UDim2.fromOffset(width, height)
	sign.BackgroundTransparency = 0
	sign.BackgroundColor3 = options.frameColor
	PhoneUi.corner(sign, UDim.new(0, 8))
	-- Anchor on the QR's centre so the QR lines up with the scan box.
	sign.AnchorPoint = Vector2.new(0.5, (30 + qrPixels / 2) / height)

	local card = PhoneUi.frame("Card", sign)
	card.Position = UDim2.fromOffset(6, 6)
	card.Size = UDim2.new(1, -12, 1, -12)
	card.BackgroundTransparency = 0
	card.BackgroundColor3 = options.cardColor
	PhoneUi.corner(card, UDim.new(0, 6))

	local title = PhoneUi.label("Title", card, options.title, 13)
	title.TextColor3 = options.titleColor
	title.Position = UDim2.fromOffset(0, 4)
	title.Size = UDim2.new(1, 0, 0, 18)

	local qr = PhoneUi.frame("QR", card)
	qr.AnchorPoint = Vector2.new(0.5, 0)
	qr.Position = UDim2.new(0.5, 0, 0, 24)
	qr.Size = UDim2.fromOffset(qrPixels, qrPixels)
	qr.BackgroundTransparency = 0
	qr.BackgroundColor3 = PhoneUi.WHITE
	QrCode.render(qr, options.pattern, QR_INK)

	local sub = PhoneUi.label("Sub", card, options.subtitle, 12)
	sub.FontFace = PhoneUi.FONT_REGULAR
	sub.TextColor3 = options.subtitleColor
	sub.AnchorPoint = Vector2.new(0, 1)
	sub.Position = UDim2.new(0, 0, 1, -8)
	sub.Size = UDim2.new(1, 0, 0, 16)

	-- Out-of-focus haze over the sign; fades out as the camera "focuses".
	local blur = PhoneUi.frame("Blur", sign)
	blur.Size = UDim2.fromScale(1, 1)
	blur.BackgroundTransparency = 0.3
	blur.BackgroundColor3 = Color3.fromRGB(70, 56, 48)
	blur.ZIndex = 2
	PhoneUi.corner(blur, UDim.new(0, 8))
	return sign, blur, qr
end

local function bracketPiece(parent: Frame, anchor: Vector2, size: Vector2): Frame
	local f = PhoneUi.frame("Bracket", parent)
	f.AnchorPoint = anchor
	f.Position = UDim2.fromScale(anchor.X, anchor.Y)
	f.Size = UDim2.fromOffset(size.X, size.Y)
	f.BackgroundTransparency = 0
	f.BackgroundColor3 = PhoneUi.WHITE
	PhoneUi.corner(f, UDim.new(0, 2))
	return f
end

function QrScanner.build(page: Frame, options: Options): Scanner
	local overlay = PhoneUi.frame("Scanner", page)
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundTransparency = 0
	overlay.BackgroundColor3 = Color3.fromRGB(30, 24, 26)
	overlay.ClipsDescendants = true
	overlay.ZIndex = 20
	overlay.Visible = false
	overlay.Active = true
	-- The camera view: the dim terrace behind the sign.
	local feed = Instance.new("UIGradient")
	feed.Rotation = 90
	feed.Color = ColorSequence.new(Color3.fromRGB(132, 100, 84), Color3.fromRGB(46, 36, 40))
	feed.Parent = overlay

	local sign, blur, qr = buildSign(overlay, options)
	local signScale = Instance.new("UIScale")
	signScale.Parent = sign

	-- Darken everything outside the scan box.
	local shade = Color3.fromRGB(0, 0, 0)
	local half = BOX / 2
	local function dim(position: UDim2, size: UDim2)
		local d = PhoneUi.frame("Dim", overlay)
		d.Position = position
		d.Size = size
		d.BackgroundTransparency = 0.45
		d.BackgroundColor3 = shade
	end
	dim(UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, BOX_Y, -half))
	dim(UDim2.new(0, 0, BOX_Y, half), UDim2.new(1, 0, 1 - BOX_Y, -half))
	dim(UDim2.new(0, 0, BOX_Y, -half), UDim2.new(0.5, -half, 0, BOX))
	dim(UDim2.new(0.5, half, BOX_Y, -half), UDim2.new(0.5, -half, 0, BOX))

	local box = PhoneUi.frame("Box", overlay)
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, BOX_Y)
	box.Size = UDim2.fromOffset(BOX, BOX)
	local boxScale = Instance.new("UIScale")
	boxScale.Parent = box
	local brackets: { Frame } = {}
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		table.insert(brackets, bracketPiece(box, corner, Vector2.new(BRACKET, BRACKET_WIDTH)))
		table.insert(brackets, bracketPiece(box, corner, Vector2.new(BRACKET_WIDTH, BRACKET)))
	end

	local line = PhoneUi.frame("ScanLine", box)
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Size = UDim2.new(1, -20, 0, 3)
	line.BackgroundTransparency = 0
	line.BackgroundColor3 = PhoneUi.ACCENT
	local lineFade = Instance.new("UIGradient")
	lineFade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	lineFade.Parent = line

	local title = PhoneUi.label("Title", overlay, "QR SCAN", 16)
	title.Position = UDim2.fromOffset(0, 10)
	title.Size = UDim2.new(1, 0, 0, 22)

	local hint = PhoneUi.label("Hint", overlay, "", 14)
	hint.FontFace = PhoneUi.FONT_REGULAR
	hint.Position = UDim2.new(0, 0, BOX_Y, half + 18)
	hint.Size = UDim2.new(1, 0, 0, 20)

	local flash = PhoneUi.frame("Flash", overlay)
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = PhoneUi.WHITE
	flash.BackgroundTransparency = 1
	flash.ZIndex = 5

	local runId = 0

	local function play(onDone: () -> (), startDelay: number?)
		runId += 1
		local myRun = runId
		if GuiService.ReducedMotionEnabled then
			overlay.Visible = false
			onDone()
			return
		end

		-- Reset.
		overlay.Position = UDim2.fromScale(0, 0)
		overlay.Visible = true
		flash.BackgroundTransparency = 1
		hint.Text = "Point the camera at the QR code"
		hint.TextColor3 = PhoneUi.WHITE
		for _, b in brackets do
			b.BackgroundColor3 = PhoneUi.WHITE
		end
		boxScale.Scale = 1
		blur.BackgroundTransparency = 0.25
		sign.Position = UDim2.new(0.5, 80, BOX_Y, 120)
		sign.Rotation = 14
		signScale.Scale = 0.72
		line.Position = UDim2.fromScale(0.5, 0.08)
		line.Visible = true
		local sweep = TweenService:Create(
			line,
			TweenInfo.new(0.32, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = UDim2.fromScale(0.5, 0.92) }
		)
		sweep:Play()

		task.spawn(function()
			if startDelay and startDelay > 0 then
				task.wait(startDelay)
				if myRun ~= runId then
					return
				end
			end
			-- Aim: the sign swings into the box, overshoots a little, then settles.
			tween(
				sign,
				0.42,
				Enum.EasingStyle.Quad,
				{ Position = UDim2.new(0.5, -6, BOX_Y, 6), Rotation = -3 }
			)
			tween(signScale, 0.42, Enum.EasingStyle.Quad, { Scale = 1.06 })
			tween(blur, 0.5, Enum.EasingStyle.Quad, { BackgroundTransparency = 1 })
			task.wait(0.42)
			if myRun ~= runId then
				return
			end
			tween(
				sign,
				0.16,
				Enum.EasingStyle.Sine,
				{ Position = UDim2.fromScale(0.5, BOX_Y), Rotation = 0 }
			)
			tween(signScale, 0.16, Enum.EasingStyle.Sine, { Scale = 1 })
			task.wait(0.2)
			if myRun ~= runId then
				return
			end

			-- Detected.
			sweep:Cancel()
			line.Visible = false
			for _, b in brackets do
				b.BackgroundColor3 = GREEN
			end
			hint.Text = options.doneText or "Scanned!"
			hint.TextColor3 = GREEN
			boxScale.Scale = 1.1
			tween(boxScale, 0.2, Enum.EasingStyle.Back, { Scale = 1 })
			flash.BackgroundTransparency = 0.45
			tween(flash, 0.25, Enum.EasingStyle.Quad, { BackgroundTransparency = 1 })
			task.wait(0.35)
			if myRun ~= runId then
				return
			end

			-- Slide away to the page underneath.
			tween(overlay, 0.28, Enum.EasingStyle.Quint, { Position = UDim2.fromScale(-1, 0) })
			task.wait(0.28)
			if myRun ~= runId then
				return
			end
			overlay.Visible = false
			onDone()
		end)
	end

	local function setPattern(pattern: QrCode.Pattern)
		local old = qr:FindFirstChild("QrCells")
		if old then
			old:Destroy()
		end
		QrCode.render(qr, pattern, QR_INK)
	end

	return { play = play, setPattern = setPattern }
end

return QrScanner
