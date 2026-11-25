--!strict
-- Freedom Wall: the QR sign (tag FreedomWall.QrTag) opens the phone's Notes app; posted notes
-- are filtered by Roblox and shown as sticky notes on the wall (tag FreedomWall.WallTag).
--
-- Notes live only in this server and are removed when their writer leaves (not saved yet,
-- see .claude/[0]/to-do/freedom-wall/plan.md). The wall's "ReserveRight" attribute (studs)
-- leaves room on the right of the board for the QR sign.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")

local FreedomWall = require(ReplicatedStorage.Shared.FreedomWall)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UnlockService = require(script.Parent.UnlockService)

local PIXELS_PER_STUD = 50
local HEADER = 64
local PAD = 16
local CORK = Color3.fromRGB(176, 132, 92)
local INK = Color3.fromRGB(45, 32, 26)
local FONT = Font.fromEnum(Enum.Font.BuilderSansBold)
local FONT_REGULAR = Font.fromEnum(Enum.Font.BuilderSans)
local HAND = Font.fromEnum(Enum.Font.IndieFlower)

local FreedomWallService = {}

-- One frame per wall (normally just one wall).
type Note = { userId: number, frames: { Frame } }

local rng = Random.new()
local boards: { Frame } = {}
local notes: { Note } = {} -- oldest first
local lastPost: { [Player]: number } = {}

local function corner(parent: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, text: string, font: Font, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.Text = text
	l.TextColor3 = color
	l.TextScaled = true
	l.TextWrapped = true
	l.Parent = parent
	return l
end

local function buildBoard(wall: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "FreedomWallGui"
	gui.Face = FreedomWall.WallFace
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS_PER_STUD
	gui.LightInfluence = 0.15
	gui.MaxDistance = 120
	gui.Parent = wall

	local reserve = wall:GetAttribute("ReserveRight")
	local reservePx = (if typeof(reserve) == "number" then reserve else 0) * PIXELS_PER_STUD

	local board = Instance.new("Frame")
	board.Name = "Board"
	board.Position = UDim2.fromOffset(PAD, PAD)
	board.Size = UDim2.new(1, -PAD * 2 - reservePx, 1, -PAD * 2)
	board.BackgroundColor3 = CORK
	corner(board, 18)
	board.Parent = gui
	local frameStroke = Instance.new("UIStroke")
	frameStroke.Color = Color3.fromRGB(92, 62, 40)
	frameStroke.Thickness = 8
	frameStroke.Parent = board

	local title = label(board, "FREEDOM WALL", FONT, Color3.fromRGB(255, 248, 236))
	title.Position = UDim2.fromOffset(20, 10)
	title.Size = UDim2.new(0.45, 0, 0, HEADER - 16)
	title.TextXAlignment = Enum.TextXAlignment.Left

	local hint = label(
		board,
		"Scan the QR code to leave a note",
		FONT_REGULAR,
		Color3.fromRGB(255, 236, 214)
	)
	hint.AnchorPoint = Vector2.new(1, 0)
	hint.Position = UDim2.new(1, -20, 0, 18)
	hint.Size = UDim2.new(0.5, 0, 0, HEADER - 30)
	hint.TextXAlignment = Enum.TextXAlignment.Right

	local area = Instance.new("Frame")
	area.Name = "Notes"
	area.BackgroundTransparency = 1
	area.Position = UDim2.fromOffset(14, HEADER)
	area.Size = UDim2.new(1, -28, 1, -HEADER - 12)
	area.Parent = board

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.2, -12, 0.333, -12)
	grid.CellPadding = UDim2.fromOffset(12, 12)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = area

	local empty = label(board, "No notes yet. Be the first!", FONT, Color3.fromRGB(255, 240, 220))
	empty.Name = "Empty"
	empty.Position = UDim2.fromOffset(14, HEADER)
	empty.Size = UDim2.new(1, -28, 0.4, 0)

	table.insert(boards, area)
end

local function noteFrame(text: string, author: string, color: Color3, order: number): Frame
	local note = Instance.new("Frame")
	note.Name = "Note"
	note.LayoutOrder = order
	note.BackgroundColor3 = color
	note.Rotation = rng:NextNumber(-4, 4)
	corner(note, 6)

	local pin = Instance.new("Frame")
	pin.Name = "Pin"
	pin.AnchorPoint = Vector2.new(0.5, 0.5)
	pin.Position = UDim2.new(0.5, 0, 0, 4)
	pin.Size = UDim2.fromOffset(16, 16)
	pin.BackgroundColor3 = Color3.fromRGB(220, 70, 80)
	corner(pin, 8)
	pin.Parent = note

	local body = label(note, text, HAND, INK)
	body.Name = "Text"
	body.Position = UDim2.new(0, 10, 0, 14)
	body.Size = UDim2.new(1, -20, 1, -40)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 26
	limit.Parent = body

	local by = label(note, `— {author}`, FONT, Color3.fromRGB(110, 84, 64))
	by.Name = "Author"
	by.AnchorPoint = Vector2.new(0, 1)
	by.Position = UDim2.new(0, 10, 1, -6)
	by.Size = UDim2.new(1, -20, 0, 18)
	by.TextXAlignment = Enum.TextXAlignment.Right
	return note
end

local function refreshEmpty()
	for _, area in boards do
		local board = area.Parent
		local empty = board and board:FindFirstChild("Empty")
		if empty and empty:IsA("GuiObject") then
			empty.Visible = #notes == 0
		end
	end
end

local function removeAt(index: number)
	local note = table.remove(notes, index)
	if note then
		for _, frame in note.frames do
			frame:Destroy()
		end
	end
end

local function removeFor(userId: number)
	for i = #notes, 1, -1 do
		if notes[i].userId == userId then
			removeAt(i)
		end
	end
	refreshEmpty()
end

local orderCounter = 0
local function addNote(player: Player, text: string, anonymous: boolean)
	-- Make room: the writer's own oldest note first, then the wall's oldest.
	local mine = 0
	for _, note in notes do
		if note.userId == player.UserId then
			mine += 1
		end
	end
	if mine >= FreedomWall.MaxPerPlayer then
		for i, note in notes do
			if note.userId == player.UserId then
				removeAt(i)
				break
			end
		end
	end
	while #notes >= FreedomWall.MaxNotes do
		removeAt(1)
	end

	-- Newest first on the wall.
	orderCounter -= 1
	local color = FreedomWall.NoteColors[rng:NextInteger(1, #FreedomWall.NoteColors)]
	local author = if anonymous then "anonymous" else player.DisplayName
	local frames = {}
	for _, area in boards do
		local frame = noteFrame(text, author, color, orderCounter)
		frame.Parent = area
		table.insert(frames, frame)
	end
	table.insert(notes, { userId = player.UserId, frames = frames })
	refreshEmpty()
end

local function filter(player: Player, text: string): string?
	local okChat, canChat = pcall(function()
		return TextChatService:CanUserChatAsync(player.UserId)
	end)
	if not okChat or not canChat then
		return nil
	end
	local ok, result = pcall(function()
		local filtered =
			TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	return if ok then result else nil
end

function FreedomWallService.start()
	local remote = Remotes.freedomWall()

	for _, wall in CollectionService:GetTagged(FreedomWall.WallTag) do
		if wall:IsA("BasePart") then
			buildBoard(wall)
		end
	end
	refreshEmpty()

	local function setupQr(instance: Instance)
		if not instance:IsA("BasePart") or instance:FindFirstChildOfClass("ClickDetector") then
			return
		end
		local click = Instance.new("ClickDetector")
		click.MaxActivationDistance = 20
		click.Parent = instance
		click.MouseClick:Connect(function(player: Player)
			remote:FireClient(player, "Open")
		end)
	end
	for _, qr in CollectionService:GetTagged(FreedomWall.QrTag) do
		setupQr(qr)
	end
	CollectionService:GetInstanceAddedSignal(FreedomWall.QrTag):Connect(setupQr)

	remote.OnServerEvent:Connect(
		function(player: Player, kind: unknown, text: unknown, anonymous: unknown)
			if kind ~= "Post" or typeof(text) ~= "string" then
				return
			end
			local unlock = UnlockService.status(player, FreedomWall.Feature)
			if not unlock.unlocked then
				remote:FireClient(player, "Error", unlock.message)
				return
			end
			local now = os.clock()
			local remaining = FreedomWall.Cooldown - (now - (lastPost[player] or -math.huge))
			if remaining > 0 then
				remote:FireClient(
					player,
					"Error",
					`Please wait. You can post again in {math.ceil(remaining)}s.`
				)
				return
			end
			local trimmed = string.gsub(string.gsub(text, "%s+", " "), "^%s*(.-)%s*$", "%1")
			if trimmed == "" then
				remote:FireClient(player, "Error", "Your note is empty.")
				return
			end
			if
				utf8.len(trimmed) == nil
				or (utf8.len(trimmed) :: number) > FreedomWall.MaxLength
			then
				remote:FireClient(player, "Error", `Max {FreedomWall.MaxLength} characters.`)
				return
			end
			lastPost[player] = now
			local filtered = filter(player, trimmed)
			if not filtered then
				lastPost[player] = nil
				remote:FireClient(player, "Error", "Couldn't post right now. Try again later.")
				return
			end
			addNote(player, filtered, anonymous == true)
			remote:FireClient(player, "Posted")
		end
	)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastPost[player] = nil
		removeFor(player.UserId)
	end)
end

return FreedomWallService
