--!strict
-- Freedom Wall on the SkyTerrace: players "scan" the QR sign (click it), write a short note
-- in the phone's Notes app and post it. Notes show on the wall for everyone, filtered by
-- Roblox. For now a note only stays while its writer is in the server (not saved yet).

local QrCode = require(script.Parent.QrCode)

local FreedomWall = {
	-- CollectionService tags set in Studio.
	WallTag = "FreedomWall", -- the wall part; notes go on its SurfaceGui
	QrTag = "FreedomWallQR", -- the QR sign; clicking it opens the Notes app
	-- Which face of the wall part shows the notes.
	WallFace = Enum.NormalId.Left,

	-- Unlock needed to post (shared Unlocks).
	Feature = "FreedomWall",

	MaxLength = 120,
	-- Seconds a player must wait between posts.
	Cooldown = 45,
	-- Notes one player can have on the wall at once (their oldest goes first).
	MaxPerPlayer = 2,
	-- Notes on the wall at once (the oldest goes first).
	MaxNotes = 15,

	-- Sticky note colors.
	NoteColors = {
		Color3.fromRGB(255, 236, 150),
		Color3.fromRGB(255, 196, 210),
		Color3.fromRGB(190, 230, 255),
		Color3.fromRGB(200, 240, 190),
		Color3.fromRGB(255, 214, 170),
		Color3.fromRGB(222, 204, 255),
	},

	-- Size of the decorative QR code (cells per side).
	QrSize = 21,
}

-- The decorative QR pattern (rows of cells, true = dark). Fixed seed, so the QR sign in Studio
-- and the phone's scanner show the same code.
function FreedomWall.qrPattern(): QrCode.Pattern
	return QrCode.pattern(2026, FreedomWall.QrSize)
end

return FreedomWall
