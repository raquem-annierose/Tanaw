--!strict
-- Shared types for the table games (GameTable and each game).

export type State = { [string]: any }

-- What a game gets from its table.
export type Context = {
	-- Sends the game's state to both players. The table adds Game, Title and Players.
	publish: (state: State) -> (),
	-- False once the match is over (someone stood up). Loops in the game must stop then.
	alive: () -> boolean,
}

-- A running game.
export type Match = {
	-- An action from the player in seat `index` (1 or 2). Check `value`: it comes from a client.
	action: (index: number, kind: string, value: unknown) -> (),
}

return {}
