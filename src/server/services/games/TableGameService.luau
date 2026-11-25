--!strict
-- Table games in the Playground (Tic-Tac-Toe, Arm Wrestling, Bato-Bato Pick). Gives every table
-- model tagged TableGames.Tag its own GameTable and passes each player's moves to the table they
-- sit at. See shared TableGames for how to set up a table in Studio.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameTable = require(script.Parent.tablegames.GameTable)
local Remotes = require(ReplicatedStorage.Shared.core.Remotes)
local TableGames = require(ReplicatedStorage.Shared.games.TableGames)

-- Spam protection: ignore a player's messages closer together than this (seconds). Taps are
-- capped by the game itself, so this only needs to stop floods.
local MIN_INTERVAL = 0.02

local TableGameService = {}

local tables: { [Instance]: GameTable.GameTable } = {}
local lastMessage: { [Player]: number } = {}

function TableGameService.start()
	local remote = Remotes.tableGame()

	local function add(instance: Instance)
		if instance:IsA("Model") and not tables[instance] then
			local gameTable = GameTable.new(instance, remote)
			if gameTable then
				tables[instance] = gameTable
			end
		end
	end
	local function remove(instance: Instance)
		local gameTable = tables[instance]
		if gameTable then
			gameTable:destroy()
			tables[instance] = nil
		end
	end
	for _, instance in CollectionService:GetTagged(TableGames.Tag) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(TableGames.Tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TableGames.Tag):Connect(remove)

	remote.OnServerEvent:Connect(function(player: Player, kind: unknown, value: unknown)
		if typeof(kind) ~= "string" then
			return
		end
		local now = os.clock()
		if now - (lastMessage[player] or 0) < MIN_INTERVAL then
			return
		end
		lastMessage[player] = now
		for _, gameTable in tables do
			if gameTable:indexOf(player) then
				gameTable:action(player, kind, value)
				return
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		lastMessage[player] = nil
	end)
end

return TableGameService
