--!strict
-- This visit's photobooth photos, on this player's client only (lost when they leave).
-- PhotoboothController hands over the photo at DONE (pending); scanning its QR on the mirror
-- moves it into the album (PhotoboothApp). No requires, so both sides can use it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Photobooth = require(ReplicatedStorage.Shared.photobooth.Photobooth)

export type Photo = {
	-- The real screenshot (ScreenshotCapture), if Roblox could take one. Shown with
	-- Content.fromObject and the only thing that can be saved to Captures.
	shot: any,
	-- Frozen avatar copy (not parented), shown in a ViewportFrame when there's no screenshot.
	model: Model?,
	view: CFrame,
	fov: number,
	caption: string,
	id: number?,
}

local PhotoAlbum = {}

local pending: Photo? = nil
local photos: { Photo } = {} -- newest first
local changed = Instance.new("BindableEvent")
PhotoAlbum.Changed = changed.Event

local function drop(photo: Photo)
	if photo.model then
		photo.model:Destroy()
	end
end

-- The photo just taken, waiting for its QR to be scanned. Replaces an older one.
function PhotoAlbum.setPending(photo: Photo)
	if pending and pending ~= photo then
		drop(pending)
	end
	pending = photo
end

-- Moves the pending photo into the album. Returns it (nil if there was none).
function PhotoAlbum.claimPending(id: number?): Photo?
	local photo = pending
	if not photo then
		return nil
	end
	pending = nil
	photo.id = id
	table.insert(photos, 1, photo)
	while #photos > Photobooth.MaxPhotos do
		drop(table.remove(photos) :: Photo)
	end
	changed:Fire()
	return photo
end

-- Deletes a photo from the album.
function PhotoAlbum.remove(photo: Photo)
	local index = table.find(photos, photo)
	if index then
		table.remove(photos, index)
		drop(photo)
		changed:Fire()
	end
end

function PhotoAlbum.list(): { Photo }
	return photos
end

-- Draws a photo into `parent` (fills it): the screenshot, or the avatar copy as a fallback.
function PhotoAlbum.render(parent: GuiObject, photo: Photo): GuiObject
	if photo.shot then
		local image = Instance.new("ImageLabel")
		image.Name = "Photo"
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromScale(1, 1)
		image.ScaleType = Enum.ScaleType.Crop
		image.ImageContent = Content.fromObject(photo.shot)
		image.Parent = parent
		return image
	end
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Photo"
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Ambient = Color3.fromRGB(200, 186, 214)
	viewport.LightColor = Color3.fromRGB(255, 240, 248)
	local camera = Instance.new("Camera")
	camera.CFrame = photo.view
	camera.FieldOfView = photo.fov
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport.LightDirection = (photo.view.LookVector + Vector3.new(0, -0.6, 0)).Unit
	if photo.model then
		photo.model:Clone().Parent = viewport
	end
	viewport.Parent = parent
	return viewport
end

return PhotoAlbum
