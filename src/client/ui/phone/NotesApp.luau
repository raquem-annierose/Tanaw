--!strict
-- Notes app: write a note for the Freedom Wall on the SkyTerrace. It opens when the player
-- "scans" (clicks) the QR sign next to the wall; it isn't on the home screen dock.
-- The server filters the note and pins it on the wall (see FreedomWallService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FreedomWall = require(ReplicatedStorage.Shared.FreedomWall)
local PhoneUi = require(script.Parent.PhoneUi)
local QrScanner = require(script.Parent.QrScanner)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local PAPER = Color3.fromRGB(255, 246, 214)
local INK = Color3.fromRGB(45, 32, 26)
local OK_GREEN = Color3.fromRGB(150, 230, 160)
local ERROR_RED = Color3.fromRGB(255, 150, 150)

local NotesApp = {}

-- page: the app page; goHome: back to the home screen; openSelf: open the phone on this app.
function NotesApp.build(page: Frame, goHome: () -> (), openSelf: () -> ())
	PhoneUi.header(page, "Freedom Wall", goHome)

	local intro = PhoneUi.label("Intro", page, "Mag-iwan ng note sa wall 💌", 14)
	intro.FontFace = PhoneUi.FONT_REGULAR
	intro.Position = UDim2.fromOffset(18, 44)
	intro.Size = UDim2.new(1, -36, 0, 18)
	intro.TextXAlignment = Enum.TextXAlignment.Left
	intro.TextTransparency = 0.2

	-- Sticky-note paper with the text box.
	local paper = PhoneUi.frame("Paper", page)
	paper.Position = UDim2.fromOffset(16, 70)
	paper.Size = UDim2.new(1, -32, 0, 220)
	paper.BackgroundTransparency = 0
	paper.BackgroundColor3 = PAPER
	PhoneUi.corner(paper, UDim.new(0, 12))

	local box = Instance.new("TextBox")
	box.Name = "Input"
	box.Position = UDim2.fromOffset(14, 12)
	box.Size = UDim2.new(1, -28, 1, -40)
	box.BackgroundTransparency = 1
	box.ClearTextOnFocus = false
	box.MultiLine = true
	box.TextWrapped = true
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.TextYAlignment = Enum.TextYAlignment.Top
	box.FontFace = Font.fromEnum(Enum.Font.IndieFlower)
	box.TextSize = 22
	box.TextColor3 = INK
	box.PlaceholderText = "Ano'ng nasa isip mo?"
	box.PlaceholderColor3 = Color3.fromRGB(160, 140, 110)
	box.Text = ""
	box.Parent = paper

	local counter = PhoneUi.label("Counter", paper, `0/{FreedomWall.MaxLength}`, 13)
	counter.FontFace = PhoneUi.FONT_REGULAR
	counter.AnchorPoint = Vector2.new(1, 1)
	counter.Position = UDim2.new(1, -12, 1, -8)
	counter.Size = UDim2.fromOffset(80, 18)
	counter.TextXAlignment = Enum.TextXAlignment.Right
	counter.TextColor3 = Color3.fromRGB(140, 120, 96)

	box:GetPropertyChangedSignal("Text"):Connect(function()
		local text = box.Text
		local length = utf8.len(text) or #text
		if length > FreedomWall.MaxLength then
			-- Cut at a character boundary, not in the middle of an emoji.
			local cut = utf8.offset(text, FreedomWall.MaxLength + 1)
			box.Text = if cut then string.sub(text, 1, cut - 1) else text
			return
		end
		counter.Text = `{length}/{FreedomWall.MaxLength}`
	end)

	-- Anonymous switch.
	local anonymous = true
	local row = PhoneUi.button("Anonymous", page)
	row.Position = UDim2.fromOffset(16, 302)
	row.Size = UDim2.new(1, -32, 0, 44)
	row.BackgroundTransparency = 0.9
	row.BackgroundColor3 = PhoneUi.WHITE
	PhoneUi.corner(row, UDim.new(0, 12))

	local rowLabel = PhoneUi.label("Label", row, "Anonymous", 16)
	rowLabel.Position = UDim2.fromOffset(14, 0)
	rowLabel.Size = UDim2.new(1, -90, 1, 0)
	rowLabel.TextXAlignment = Enum.TextXAlignment.Left

	local track = PhoneUi.frame("Switch", row)
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.new(1, -12, 0.5, 0)
	track.Size = UDim2.fromOffset(46, 26)
	track.BackgroundTransparency = 0
	PhoneUi.corner(track)
	local knob = PhoneUi.frame("Knob", track)
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.Size = UDim2.fromOffset(22, 22)
	knob.BackgroundTransparency = 0
	knob.BackgroundColor3 = PhoneUi.WHITE
	PhoneUi.corner(knob)

	local function refreshSwitch()
		track.BackgroundColor3 = if anonymous
			then Color3.fromRGB(110, 210, 130)
			else Color3.fromRGB(120, 116, 130)
		knob.Position = if anonymous then UDim2.new(1, -24, 0.5, 0) else UDim2.new(0, 2, 0.5, 0)
		rowLabel.Text = if anonymous then "Anonymous" else "Ipakita ang pangalan ko"
	end
	refreshSwitch()
	row.Activated:Connect(function()
		anonymous = not anonymous
		refreshSwitch()
	end)

	local post = PhoneUi.button("Post", page)
	post.Position = UDim2.fromOffset(16, 358)
	post.Size = UDim2.new(1, -32, 0, 46)
	post.BackgroundColor3 = PhoneUi.ACCENT
	post.Text = "I-post sa wall"
	post.TextSize = 18
	post.TextColor3 = INK
	PhoneUi.corner(post, UDim.new(0, 14))

	local status = PhoneUi.label("Status", page, "", 14)
	status.FontFace = PhoneUi.FONT_REGULAR
	status.Position = UDim2.fromOffset(16, 410)
	status.Size = UDim2.new(1, -32, 0, 40)
	status.TextWrapped = true
	status.TextTruncate = Enum.TextTruncate.None

	local note = PhoneUi.label(
		"Note",
		page,
		`Mawawala ang note mo pag umalis ka ng server. Max {FreedomWall.MaxLength} characters.`,
		12
	)
	note.FontFace = PhoneUi.FONT_REGULAR
	note.AnchorPoint = Vector2.new(0, 1)
	note.Position = UDim2.new(0, 16, 1, -6)
	note.Size = UDim2.new(1, -32, 0, 34)
	note.TextWrapped = true
	note.TextTruncate = Enum.TextTruncate.None
	note.TextTransparency = 0.4

	-- Built last so the scan screen covers the page while it plays.
	local scanner = QrScanner.build(page)

	local remote = Remotes.freedomWall()
	local sending = false
	post.Activated:Connect(function()
		if sending then
			return
		end
		local text = box.Text
		if string.match(text, "%S") == nil then
			status.TextColor3 = ERROR_RED
			status.Text = "Sulat ka muna ng note."
			return
		end
		sending = true
		post.Text = "Pino-post..."
		status.Text = ""
		remote:FireServer("Post", text, anonymous)
	end)

	remote.OnClientEvent:Connect(function(kind: unknown, message: unknown)
		if kind == "Open" then
			intro.Text = "Mag-iwan ng note sa wall 💌"
			intro.TextColor3 = PhoneUi.WHITE
			openSelf()
			scanner.play(function()
				intro.Text = "✓ Na-scan: Freedom Wall · SkyTerrace"
				intro.TextColor3 = OK_GREEN
				box:CaptureFocus()
			end, 0.3) -- let the phone slide in first
		elseif kind == "Posted" then
			sending = false
			post.Text = "I-post sa wall"
			box.Text = ""
			status.TextColor3 = OK_GREEN
			status.Text = "Na-post na! Tingnan mo sa wall ✨"
		elseif kind == "Error" then
			sending = false
			post.Text = "I-post sa wall"
			status.TextColor3 = ERROR_RED
			status.Text = if typeof(message) == "string"
				then message
				else "May error, subukan ulit."
		end
	end)
end

return NotesApp
