--!strict
-- Decorative QR codes (not scannable by real phones, on purpose: see the Freedom Wall and
-- photobooth plans). Used by the Freedom Wall sign, the photobooth mirror and the phone's scanner.

export type Pattern = { { boolean } }

local QrCode = {}

-- Rows of cells (true = dark): the three finder squares plus random cells from `seed`, so the
-- same seed always gives the same code.
function QrCode.pattern(seed: number, size: number): Pattern
	local n = size
	local rng = Random.new(seed)
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

-- Draws the pattern as frames inside `parent` (sized in scale, so it fills any square parent).
-- Returns the holder frame; destroy it to remove the code.
function QrCode.render(parent: Instance, pattern: Pattern, ink: Color3): Frame
	local holder = Instance.new("Frame")
	holder.Name = "QrCells"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Size = UDim2.fromScale(1, 1)
	local n = #pattern
	local cell = 1 / n
	for i, row in pattern do
		-- One frame per run of dark cells in a row, so there are fewer frames.
		local j = 1
		while j <= n do
			if row[j] then
				local start = j
				while j + 1 <= n and row[j + 1] do
					j += 1
				end
				local f = Instance.new("Frame")
				f.Name = "Px"
				f.BorderSizePixel = 0
				f.BackgroundColor3 = ink
				f.Position = UDim2.fromScale((start - 1) * cell, (i - 1) * cell)
				-- A hair wider so runs in neighbouring rows don't show seams.
				f.Size = UDim2.new((j - start + 1) * cell, 1, cell, 1)
				f.Parent = holder
			end
			j += 1
		end
	end
	holder.Parent = parent
	return holder
end

return QrCode
