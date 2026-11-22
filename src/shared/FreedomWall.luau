--!strict
-- Freedom Wall on the SkyTerrace: players "scan" the QR sign (click it), write a short note
-- in the phone's Notes app and post it. Notes show on the wall for everyone, filtered by
-- Roblox. For now a note only stays while its writer is in the server (not saved yet).

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

-- The decorative QR pattern (rows of cells, true = dark): the three finder squares plus random
-- cells from a fixed seed, so the QR sign in Studio and the phone's scanner show the same code.
function FreedomWall.qrPattern(): { { boolean } }
	local n = FreedomWall.QrSize
	local rng = Random.new(2026)
	local function inFinder(i: number, j: number, fi: number, fj: number): boolean?
		local di, dj = i - fi, j - fj
		if di < 0 or dj < 0 or di > 6 or dj > 6 then
			return nil
		end
		if di == 0 or dj == 0 or di == 6 or dj == 6 then
			return true
		end
		return di >= 2 and di <= 4 and dj >= 2 and dj <= 4
	end
	local function fixed(i: number, j: number): boolean?
		for _, corner in { { 0, 0 }, { 0, n - 7 }, { n - 7, 0 } } do
			local r = inFinder(i, j, corner[1], corner[2])
			if r ~= nil then
				return r
			end
		end
		-- White separators around the finder squares.
		if (i == 7 and (j < 8 or j > n - 9)) or (j == 7 and (i < 8 or i > n - 9)) then
			return false
		end
		return nil
	end
	local rows = {}
	for i = 0, n - 1 do
		local row = {}
		for j = 0, n - 1 do
			local f = fixed(i, j)
			row[j + 1] = if f ~= nil then f else rng:NextNumber() < 0.5
		end
		rows[i + 1] = row
	end
	return rows
end

return FreedomWall
