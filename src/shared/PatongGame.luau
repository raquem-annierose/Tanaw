--!strict
-- One Patong board: the falling piece, the stack, score, rows cleared and incoming garbage.
-- Only the game rules: no UI and no networking. PatongApp drives it and draws it.
--
-- Rows are numbered from the top. Two hidden rows sit above the visible board; new pieces appear
-- there. The game is over when a new piece has no room.
--
-- Pieces come from a shuffled bag of all 7, made from `seed`, so in versus every player gets the
-- same pieces in the same order.

local Patong = require(script.Parent.Patong)

local WIDTH = Patong.Width
local HIDDEN = 2
local ROWS = Patong.Height + HIDDEN
-- Seconds a piece can rest on the stack before it locks, and how many moves can restart that wait.
local LOCK_DELAY = 0.5
local MAX_LOCK_RESETS = 15
-- Points for clearing 1-4 rows at once, times the level.
local CLEAR_POINTS = { 100, 300, 500, 800 }

-- { column offset, row offset } pairs, 0-based from the top-left of the piece's box.
type Cells = { { number } }

-- The 7 pieces in an n x n box.
local SHAPES: { { size: number, cells: Cells } } = {
	{ size = 4, cells = { { 0, 1 }, { 1, 1 }, { 2, 1 }, { 3, 1 } } }, -- line
	{ size = 2, cells = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } }, -- square
	{ size = 3, cells = { { 1, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 } } }, -- T
	{ size = 3, cells = { { 1, 0 }, { 2, 0 }, { 0, 1 }, { 1, 1 } } }, -- S
	{ size = 3, cells = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 2, 1 } } }, -- Z
	{ size = 3, cells = { { 0, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 } } }, -- J
	{ size = 3, cells = { { 2, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 } } }, -- L
}

-- ROTATIONS[piece][turn + 1]: the piece's cells after `turn` clockwise quarter turns.
local ROTATIONS: { { Cells } } = {}
for id, shape in SHAPES do
	local turns: { Cells } = { shape.cells }
	for turn = 2, 4 do
		local rotated: Cells = {}
		for _, cell in turns[turn - 1] do
			table.insert(rotated, { shape.size - 1 - cell[2], cell[1] })
		end
		turns[turn] = rotated
	end
	ROTATIONS[id] = turns
end

-- Shifts tried in order when a turned piece doesn't fit where it is (so it can turn by a wall).
local KICKS = { { 0, 0 }, { -1, 0 }, { 1, 0 }, { 0, -1 }, { -2, 0 }, { 2, 0 } }

local PatongGame = {}
PatongGame.__index = PatongGame

type Fields = {
	-- grid[row][column]: 0 = empty, 1-7 = piece, Patong.Garbage = garbage.
	grid: { { number } },
	piece: number,
	turn: number,
	-- Column and row of the top-left of the falling piece's box.
	x: number,
	y: number,
	nextPiece: number,
	-- The piece put aside with hold (0 = none), and whether hold can be used for this piece.
	held: number,
	canHold: boolean,
	bag: { number },
	rng: Random,
	holeRng: Random,
	fallTimer: number,
	lockTimer: number,
	lockResets: number,
	pendingGarbage: number,
	score: number,
	lines: number,
	level: number,
	over: boolean,
	-- Called after each piece locks with (rows cleared, rows to send to an opponent).
	onLock: ((cleared: number, attack: number) -> ())?,
}

export type PatongGame = typeof(setmetatable({} :: Fields, PatongGame))

-- The cells of a piece before turning, for the "next" preview.
function PatongGame.shapeCells(piece: number): Cells
	return SHAPES[piece].cells
end

function PatongGame.new(seed: number): PatongGame
	local grid = {}
	for row = 1, ROWS do
		grid[row] = table.create(WIDTH, 0)
	end
	local self = setmetatable({
		grid = grid,
		piece = 1,
		turn = 0,
		x = 1,
		y = 1,
		nextPiece = 1,
		held = 0,
		canHold = true,
		bag = {},
		rng = Random.new(seed),
		holeRng = Random.new(),
		fallTimer = 0,
		lockTimer = 0,
		lockResets = 0,
		pendingGarbage = 0,
		score = 0,
		lines = 0,
		level = 1,
		over = false,
		onLock = nil,
	}, PatongGame)
	self.nextPiece = self:draw()
	self:spawn()
	return self
end

function PatongGame.draw(self: PatongGame): number
	if #self.bag == 0 then
		self.bag = { 1, 2, 3, 4, 5, 6, 7 }
		self.rng:Shuffle(self.bag)
	end
	return table.remove(self.bag) :: number
end

function PatongGame.fits(self: PatongGame, turn: number, x: number, y: number): boolean
	for _, cell in ROTATIONS[self.piece][turn + 1] do
		local column, row = x + cell[1], y + cell[2]
		if column < 1 or column > WIDTH or row < 1 or row > ROWS then
			return false
		end
		if self.grid[row][column] ~= 0 then
			return false
		end
	end
	return true
end

-- Puts `piece` at the top as the falling piece.
function PatongGame.place(self: PatongGame, piece: number)
	self.piece = piece
	self.turn = 0
	self.x = (WIDTH - SHAPES[self.piece].size) // 2 + 1
	self.y = HIDDEN
	self.fallTimer = 0
	self.lockTimer = 0
	self.lockResets = 0
	if not self:fits(0, self.x, self.y) then
		self.over = true
	end
end

function PatongGame.spawn(self: PatongGame)
	local piece = self.nextPiece
	self.nextPiece = self:draw()
	self:place(piece)
end

-- Hold: puts the falling piece aside and takes the held one (or the next one, the first time).
-- Once per piece: it works again after the next piece locks.
function PatongGame.hold(self: PatongGame): boolean
	if self.over or not self.canHold then
		return false
	end
	self.canHold = false
	local current = self.piece
	if self.held == 0 then
		self.held = current
		self:spawn()
	else
		local held = self.held
		self.held = current
		self:place(held)
	end
	return true
end

-- After a move or turn while resting on the stack, wait the full lock delay again (a few times).
function PatongGame.moved(self: PatongGame)
	if self.lockTimer > 0 and self.lockResets < MAX_LOCK_RESETS then
		self.lockTimer = 0
		self.lockResets += 1
	end
end

function PatongGame.move(self: PatongGame, dx: number): boolean
	if self.over or not self:fits(self.turn, self.x + dx, self.y) then
		return false
	end
	self.x += dx
	self:moved()
	return true
end

-- dir: 1 = clockwise, -1 = counter-clockwise.
function PatongGame.rotate(self: PatongGame, dir: number): boolean
	if self.over then
		return false
	end
	local turn = (self.turn + dir) % 4
	for _, kick in KICKS do
		local x, y = self.x + kick[1], self.y + kick[2]
		if self:fits(turn, x, y) then
			self.turn, self.x, self.y = turn, x, y
			self:moved()
			return true
		end
	end
	return false
end

function PatongGame.softDrop(self: PatongGame): boolean
	if self.over or not self:fits(self.turn, self.x, self.y + 1) then
		return false
	end
	self.y += 1
	self.score += 1
	self.fallTimer = 0
	return true
end

-- The row the falling piece's box would land on.
function PatongGame.ghostRow(self: PatongGame): number
	local y = self.y
	while self:fits(self.turn, self.x, y + 1) do
		y += 1
	end
	return y
end

function PatongGame.hardDrop(self: PatongGame)
	if self.over then
		return
	end
	local y = self:ghostRow()
	self.score += (y - self.y) * 2
	self.y = y
	self:lock()
end

function PatongGame.addGarbage(self: PatongGame, rows: number)
	self.pendingGarbage += rows
end

-- Pushes the stack up and adds the pending garbage rows at the bottom, each with the same gap.
function PatongGame.riseGarbage(self: PatongGame)
	local count = math.min(self.pendingGarbage, ROWS)
	self.pendingGarbage = 0
	local hole = self.holeRng:NextInteger(1, WIDTH)
	for _ = 1, count do
		local top = table.remove(self.grid, 1) :: { number }
		for _, value in top do
			if value ~= 0 then
				-- The stack was pushed off the top.
				self.over = true
			end
		end
		local row = table.create(WIDTH, Patong.Garbage)
		row[hole] = 0
		table.insert(self.grid, row)
	end
end

function PatongGame.lock(self: PatongGame)
	local allHidden = true
	for _, cell in ROTATIONS[self.piece][self.turn + 1] do
		local column, row = self.x + cell[1], self.y + cell[2]
		self.grid[row][column] = self.piece
		if row > HIDDEN then
			allHidden = false
		end
	end

	local cleared = 0
	local row = ROWS
	while row >= 1 do
		if table.find(self.grid[row], 0) then
			row -= 1
		else
			-- Full: drop it. The rows above shift down, so check this row number again.
			table.remove(self.grid, row)
			table.insert(self.grid, 1, table.create(WIDTH, 0))
			cleared += 1
		end
	end

	local attack = 0
	if cleared > 0 then
		self.score += CLEAR_POINTS[cleared] * self.level
		self.lines += cleared
		self.level = 1 + self.lines // 10
		-- Clearing rows first cancels garbage that is on its way to you.
		attack = Patong.Attack[cleared]
		local cancel = math.min(attack, self.pendingGarbage)
		attack -= cancel
		self.pendingGarbage -= cancel
	else
		if allHidden then
			-- Locked entirely above the visible board.
			self.over = true
		end
		if self.pendingGarbage > 0 then
			self:riseGarbage()
		end
	end

	if not self.over then
		self.canHold = true
		self:spawn()
	end
	if self.onLock then
		self.onLock(cleared, attack)
	end
end

function PatongGame.fallInterval(self: PatongGame): number
	return math.max(0.05, 0.8 * 0.85 ^ (self.level - 1))
end

function PatongGame.update(self: PatongGame, dt: number)
	if self.over then
		return
	end
	if self:fits(self.turn, self.x, self.y + 1) then
		self.lockTimer = 0
		self.fallTimer += dt
		local interval = self:fallInterval()
		while self.fallTimer >= interval and self:fits(self.turn, self.x, self.y + 1) do
			self.fallTimer -= interval
			self.y += 1
		end
	else
		self.fallTimer = 0
		self.lockTimer += dt
		if self.lockTimer >= LOCK_DELAY then
			self:lock()
		end
	end
end

-- Value of a visible cell of the stack (row 1 = top visible row). Doesn't include the falling piece.
function PatongGame.cell(self: PatongGame, column: number, row: number): number
	return self.grid[row + HIDDEN][column]
end

-- The falling piece's visible cells as { column, row } pairs. With `atRow`, as if its box were at
-- that row (for the landing shadow).
function PatongGame.pieceCells(self: PatongGame, atRow: number?): Cells
	local y = atRow or self.y
	local cells: Cells = {}
	for _, cell in ROTATIONS[self.piece][self.turn + 1] do
		local row = y + cell[2] - HIDDEN
		if row >= 1 then
			table.insert(cells, { self.x + cell[1], row })
		end
	end
	return cells
end

-- The visible stack as one string, a digit per cell, row by row from the top. Sent to opponents.
function PatongGame.pack(self: PatongGame): string
	local digits = table.create(WIDTH * Patong.Height)
	for row = HIDDEN + 1, ROWS do
		for _, value in self.grid[row] do
			table.insert(digits, tostring(value))
		end
	end
	return table.concat(digits)
end

return PatongGame
