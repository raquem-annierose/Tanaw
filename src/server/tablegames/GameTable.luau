--!strict
-- One table game in the Playground: a Model tagged TableGames.Tag (see shared TableGames).
-- Adds a "Play" prompt to both seats, starts the table's game when both seats are taken, and
-- stops it as soon as someone stands up.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableGames = require(ReplicatedStorage.Shared.TableGames)
local Types = require(script.Parent.Types)

local GAMES: { [string]: { start: (Types.Context) -> Types.Match } } = {
	TicTacToe = require(script.Parent.TicTacToe),
	ArmWrestle = require(script.Parent.ArmWrestle),
	BatoBatoPick = require(script.Parent.BatoBatoPick),
}

local GameTable = {}
GameTable.__index = GameTable

type Fields = {
	model: Model,
	gameId: string,
	title: string,
	seats: { Seat },
	prompts: { ProximityPrompt },
	-- Who sits in Seat1 / Seat2.
	players: { [number]: Player },
	match: Types.Match?,
	-- Bumped whenever the players change, so an old match stops.
	token: number,
	remote: RemoteEvent,
	connections: { RBXScriptConnection },
}

export type GameTable = typeof(setmetatable({} :: Fields, GameTable))

local function findSeat(model: Model, name: string): Seat?
	local seat = model:FindFirstChild(name, true)
	return if seat and seat:IsA("Seat") then seat else nil
end

function GameTable.new(model: Model, remote: RemoteEvent): GameTable?
	local gameId = model:GetAttribute(TableGames.GameAttribute)
	if typeof(gameId) ~= "string" or not GAMES[gameId] then
		warn(
			`[TableGame] {model:GetFullName()} needs a Game attribute (TicTacToe, ArmWrestle, BatoBatoPick)`
		)
		return nil
	end
	local seat1, seat2 = findSeat(model, "Seat1"), findSeat(model, "Seat2")
	if not seat1 or not seat2 then
		warn(`[TableGame] {model:GetFullName()} needs two Seats named Seat1 and Seat2`)
		return nil
	end

	local self = setmetatable({
		model = model,
		gameId = gameId,
		title = TableGames.Titles[gameId],
		seats = { seat1, seat2 },
		prompts = {},
		players = {},
		match = nil,
		token = 0,
		remote = remote,
		connections = {},
	}, GameTable)

	for _, seat in self.seats do
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PlayPrompt"
		prompt.ActionText = "Play"
		prompt.ObjectText = self.title
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = TableGames.PromptDistance
		prompt.RequiresLineOfSight = false
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
		prompt.Parent = seat
		table.insert(self.prompts, prompt)

		table.insert(
			self.connections,
			prompt.Triggered:Connect(function(player: Player)
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 and not humanoid.Sit and not seat.Occupant then
					seat:Sit(humanoid)
				end
			end)
		)
		table.insert(
			self.connections,
			seat:GetPropertyChangedSignal("Occupant"):Connect(function()
				self:refresh()
			end)
		)
	end

	self:refresh()
	return self
end

function GameTable.indexOf(self: GameTable, player: Player): number?
	for index, seated in self.players do
		if seated == player then
			return index
		end
	end
	return nil
end

-- Sends `state` to both players, plus the table's game and who sits where.
function GameTable.publish(self: GameTable, state: Types.State)
	local seated = {}
	for index, player in self.players do
		table.insert(seated, { Index = index, UserId = player.UserId, Name = player.DisplayName })
	end
	state.Game = self.gameId
	state.Title = self.title
	state.Players = seated
	for _, player in self.players do
		if player.Parent then
			self.remote:FireClient(player, "State", state)
		end
	end
end

function GameTable.refresh(self: GameTable)
	local seated: { [number]: Player } = {}
	for index, seat in self.seats do
		local occupant = seat.Occupant
		local player = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
		if player then
			seated[index] = player
		end
		self.prompts[index].Enabled = occupant == nil
	end
	if seated[1] == self.players[1] and seated[2] == self.players[2] then
		return
	end

	for _, old in self.players do
		if old ~= seated[1] and old ~= seated[2] and old.Parent then
			self.remote:FireClient(old, "Closed")
		end
	end
	self.players = seated
	self.token += 1
	self.match = nil

	if seated[1] and seated[2] then
		local token = self.token
		self.match = GAMES[self.gameId].start({
			publish = function(state: Types.State)
				if self.token == token then
					self:publish(state)
				end
			end,
			alive = function(): boolean
				return self.token == token
			end,
		})
	else
		self:publish({ Phase = "Waiting" })
	end
end

function GameTable.action(self: GameTable, player: Player, kind: string, value: unknown)
	local index = self:indexOf(player)
	local match = self.match
	if index and match then
		match.action(index, kind, value)
	end
end

function GameTable.destroy(self: GameTable)
	self.token += 1
	self.match = nil
	for _, player in self.players do
		if player.Parent then
			self.remote:FireClient(player, "Closed")
		end
	end
	table.clear(self.players)
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
	for _, prompt in self.prompts do
		prompt:Destroy()
	end
end

return GameTable
