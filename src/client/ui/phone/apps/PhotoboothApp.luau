--!strict
-- Photobooth app: this visit's photos from the Mirror Photobooth, newest first. It opens by
-- itself when the player scans their photo's QR on the mirror (scan animation first), or from
-- its home screen icon. Tap a photo to see it big and save it to Roblox Captures (that's how it
-- reaches the player's real phone gallery) or delete it (tap twice to confirm).

local CaptureService = game:GetService("CaptureService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PhoneUi = require(script.Parent.Parent.PhoneUi)
local PhotoAlbum = require(script.Parent.Parent.PhotoAlbum)
local Photobooth = require(ReplicatedStorage.Shared.photobooth.Photobooth)
local QrCode = require(ReplicatedStorage.Shared.core.QrCode)
local QrScanner = require(script.Parent.Parent.QrScanner)
local Remotes = require(ReplicatedStorage.Shared.core.Remotes)

local COLORS = Photobooth.Colors
local CARD = Color3.fromRGB(255, 246, 252)
local CAPTION = Color3.fromRGB(110, 60, 120)
local OK_GREEN = Color3.fromRGB(150, 230, 160)
local ERROR_RED = Color3.fromRGB(255, 150, 150)
local GAP = 10

local PhotoboothApp = {}

-- A polaroid-style card with the photo and its caption.
local function card(parent: Instance, photo: PhotoAlbum.Photo, captionSize: number): Frame
	local c = PhoneUi.frame("Card", parent)
	c.BackgroundTransparency = 0
	c.BackgroundColor3 = CARD
	PhoneUi.corner(c, UDim.new(0, 10))
	local pad = math.max(4, math.floor(captionSize * 0.4))

	local window = PhoneUi.frame("Window", c)
	window.Position = UDim2.fromOffset(pad, pad)
	window.Size = UDim2.new(1, -pad * 2, 1, -pad - captionSize * 2)
	window.BackgroundTransparency = 0
	window.BackgroundColor3 = Color3.fromRGB(70, 74, 110)
	window.ClipsDescendants = true
	PhoneUi.corner(window, UDim.new(0, 6))
	PhotoAlbum.render(window, photo)

	local caption = PhoneUi.label("Caption", c, photo.caption, captionSize)
	caption.FontFace = PhoneUi.FONT_REGULAR
	caption.TextColor3 = CAPTION
	caption.AnchorPoint = Vector2.new(0, 1)
	caption.Position = UDim2.new(0, pad, 1, -math.floor(captionSize * 0.4))
	caption.Size = UDim2.new(1, -pad * 2, 0, captionSize + 4)
	return c
end

-- page: the app page; goHome: back to the home screen; openSelf: open the phone on this app.
function PhotoboothApp.build(page: Frame, goHome: () -> (), openSelf: () -> ())
	PhoneUi.header(page, "Photobooth", goHome)

	local intro = PhoneUi.label("Intro", page, "Your photos from the Mirror Photobooth", 14)
	intro.FontFace = PhoneUi.FONT_REGULAR
	intro.Position = UDim2.fromOffset(18, 44)
	intro.Size = UDim2.new(1, -36, 0, 18)
	intro.TextXAlignment = Enum.TextXAlignment.Left
	intro.TextTransparency = 0.2

	-- Gallery grid -----------------------------------------------------------------------------
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Gallery"
	scroll.Position = UDim2.fromOffset(14, 70)
	scroll.Size = UDim2.new(1, -28, 1, -116)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 3
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = page
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -GAP / 2, 0, 160)
	grid.CellPadding = UDim2.fromOffset(GAP, GAP)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll

	local empty = PhoneUi.label(
		"Empty",
		page,
		"No photos yet. Try the Mirror Photobooth on the SkyTerrace.",
		15
	)
	empty.Position = UDim2.fromOffset(24, 150)
	empty.Size = UDim2.new(1, -48, 0, 60)
	empty.TextWrapped = true
	empty.TextTruncate = Enum.TextTruncate.None

	local note = PhoneUi.label(
		"Note",
		page,
		`Up to {Photobooth.MaxPhotos} photos. When full, the oldest is replaced. Photos are lost when you leave the server.`,
		12
	)
	note.FontFace = PhoneUi.FONT_REGULAR
	note.AnchorPoint = Vector2.new(0, 1)
	note.Position = UDim2.new(0, 16, 1, -6)
	note.Size = UDim2.new(1, -32, 0, 34)
	note.TextWrapped = true
	note.TextTruncate = Enum.TextTruncate.None
	note.TextTransparency = 0.4

	-- Viewer: one photo big + save ------------------------------------------------------------
	local viewer = PhoneUi.frame("Viewer", page)
	viewer.Size = UDim2.fromScale(1, 1)
	viewer.BackgroundTransparency = 0
	viewer.BackgroundColor3 = COLORS.Ink
	viewer.Active = true
	viewer.ZIndex = 10
	viewer.Visible = false

	local back = PhoneUi.button("Back", viewer)
	back.Position = UDim2.fromOffset(8, 4)
	back.Size = UDim2.fromOffset(36, 36)
	back.BackgroundTransparency = 1
	back.Text = "‹"
	back.TextSize = 34
	back.ZIndex = 10
	local viewerTitle = PhoneUi.label("Title", viewer, "Photo", 22)
	viewerTitle.Position = UDim2.fromOffset(44, 4)
	viewerTitle.Size = UDim2.new(1, -60, 0, 36)
	viewerTitle.TextXAlignment = Enum.TextXAlignment.Left
	viewerTitle.ZIndex = 10

	-- Delete: first tap asks, second tap deletes.
	local delete = PhoneUi.button("Delete", viewer)
	delete.AnchorPoint = Vector2.new(1, 0)
	delete.Position = UDim2.new(1, -12, 0, 8)
	delete.Size = UDim2.fromOffset(84, 28)
	delete.BackgroundColor3 = PhoneUi.WHITE
	delete.BackgroundTransparency = 0.88
	delete.Text = "Delete"
	delete.TextSize = 14
	delete.TextColor3 = ERROR_RED
	delete.ZIndex = 10
	PhoneUi.corner(delete, UDim.new(0, 10))

	local slot = PhoneUi.frame("Slot", viewer)
	slot.AnchorPoint = Vector2.new(0.5, 0)
	slot.Position = UDim2.new(0.5, 0, 0, 48)
	slot.Size = UDim2.new(1, -40, 1, -170)
	slot.ZIndex = 10

	local save = PhoneUi.button("Save", viewer)
	save.AnchorPoint = Vector2.new(0.5, 1)
	save.Position = UDim2.new(0.5, 0, 1, -62)
	save.Size = UDim2.new(1, -40, 0, 44)
	save.BackgroundColor3 = COLORS.Pink
	save.Text = "Save to Captures"
	save.TextSize = 17
	save.TextColor3 = COLORS.Ink
	save.ZIndex = 10
	PhoneUi.corner(save, UDim.new(0, 14))

	local status = PhoneUi.label("Status", viewer, "", 13)
	status.FontFace = PhoneUi.FONT_REGULAR
	status.AnchorPoint = Vector2.new(0, 1)
	status.Position = UDim2.new(0, 20, 1, -12)
	status.Size = UDim2.new(1, -40, 0, 44)
	status.TextWrapped = true
	status.TextTruncate = Enum.TextTruncate.None
	status.ZIndex = 10

	local shown: PhotoAlbum.Photo? = nil
	local confirming = false

	local function resetDelete()
		confirming = false
		delete.Text = "Delete"
		delete.Size = UDim2.fromOffset(84, 28)
		delete.BackgroundColor3 = PhoneUi.WHITE
		delete.BackgroundTransparency = 0.88
		delete.TextColor3 = ERROR_RED
	end

	local function setZ(root: Instance, z: number)
		for _, d in root:GetDescendants() do
			if d:IsA("GuiObject") then
				d.ZIndex = z
			end
		end
		if root:IsA("GuiObject") then
			root.ZIndex = z
		end
	end

	local function openViewer(photo: PhotoAlbum.Photo)
		shown = photo
		resetDelete()
		slot:ClearAllChildren()
		local big = card(slot, photo, 16)
		big.AnchorPoint = Vector2.new(0.5, 0.5)
		big.Position = UDim2.fromScale(0.5, 0.5)
		big.Size = UDim2.fromScale(1, 1)
		local ratio = Instance.new("UIAspectRatioConstraint")
		ratio.AspectRatio = 0.78
		ratio.Parent = big
		setZ(big, 10)
		status.Text = ""
		save.Visible = photo.shot ~= nil
		if not photo.shot then
			status.TextColor3 = PhoneUi.WHITE
			status.Text = "This photo has no screenshot, so it can't be saved to Captures."
		end
		viewer.Visible = true
	end

	local function closeViewer()
		viewer.Visible = false
		shown = nil
		resetDelete()
		slot:ClearAllChildren()
	end
	back.Activated:Connect(closeViewer)

	delete.Activated:Connect(function()
		local photo = shown
		if not photo then
			return
		end
		if not confirming then
			confirming = true
			delete.Text = "Tap again to delete"
			delete.Size = UDim2.fromOffset(150, 28)
			delete.BackgroundColor3 = Color3.fromRGB(220, 70, 90)
			delete.BackgroundTransparency = 0
			delete.TextColor3 = PhoneUi.WHITE
			-- Goes back to normal if they don't tap again.
			task.delay(3, function()
				if confirming and shown == photo then
					resetDelete()
				end
			end)
			return
		end
		closeViewer()
		PhotoAlbum.remove(photo)
	end)

	local saving = false
	save.Activated:Connect(function()
		local photo = shown
		if saving or not photo or not photo.shot then
			return
		end
		saving = true
		local ok = pcall(function()
			CaptureService:PromptSaveCapturesToGallery({ photo.shot }, function(results: any)
				saving = false
				local saved = false
				if type(results) == "table" then
					for _, v in results do
						if v == true then
							saved = true
						end
					end
				end
				if saved then
					status.TextColor3 = OK_GREEN
					status.Text = "Saved to Roblox Captures. You can now save it to your phone."
				else
					status.TextColor3 = PhoneUi.WHITE
					status.Text = "Not saved."
				end
			end)
		end)
		if not ok then
			saving = false
			status.TextColor3 = ERROR_RED
			status.Text = "Couldn't save right now. Try again later."
		end
	end)

	local function refresh()
		for _, child in scroll:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local photos = PhotoAlbum.list()
		empty.Visible = #photos == 0
		for i, photo in photos do
			local tile = PhoneUi.button(`Photo{i}`, scroll)
			tile.LayoutOrder = i
			tile.BackgroundTransparency = 1
			local c = card(tile, photo, 11)
			c.Size = UDim2.fromScale(1, 1)
			tile.Activated:Connect(function()
				openViewer(photo)
			end)
		end
	end
	refresh()
	PhotoAlbum.Changed:Connect(refresh)

	-- Scan screen, with the photo's own QR (same as the mirror's).
	local scanner = QrScanner.build(page, {
		title = "SCAN ME",
		subtitle = "Mirror Photobooth",
		pattern = QrCode.pattern(1, Photobooth.QrSize),
		frameColor = COLORS.Pink,
		cardColor = Color3.fromRGB(255, 244, 252),
		titleColor = COLORS.Ink,
		subtitleColor = CAPTION,
		doneText = "Scanned!",
	})

	task.spawn(function()
		local remote = Remotes.photobooth()
		remote.OnClientEvent:Connect(function(kind: unknown, _booth: unknown, photoId: unknown)
			if kind ~= "Scanned" then
				return
			end
			local id = if typeof(photoId) == "number" then photoId else nil
			local photo = PhotoAlbum.claimPending(id)
			scanner.setPattern(QrCode.pattern(id or 1, Photobooth.QrSize))
			viewer.Visible = false
			openSelf()
			scanner.play(function()
				if photo then
					openViewer(photo)
				end
			end, 0.3) -- let the phone slide in first
		end)
	end)
end

return PhotoboothApp
