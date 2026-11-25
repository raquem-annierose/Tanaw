--!strict
-- The roles each player holds in the NieRa Studios community, looked up once per player and
-- cached. Used by ChatTagService and AdminService.
--
-- A member can hold several roles. Players outside the community get an empty set.

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.core.Config)

local RETRIES = 3

export type RoleSet = { [string]: boolean }

local CommunityRoles = {}

local cache: { [Player]: RoleSet } = {}
local pending: { [Player]: { thread } } = {}

local function fetch(player: Player): RoleSet
	-- Shape: { IsMember = true, Roles = { { Id = ..., Name = "Owner", Rank = ... }, ... } }
	local result = GroupService:GetRolesInGroupAsync(player.UserId, Config.CommunityId)
	local names: RoleSet = {}
	if type(result) == "table" and type(result.Roles) == "table" then
		for _, role in result.Roles do
			if type(role) == "table" and type(role.Name) == "string" then
				names[role.Name] = true
			end
		end
	end
	return names
end

-- Returns the player's role names. Yields the first time; later calls are instant.
-- If Roblox's web API keeps failing, returns an empty set (no roles) for this call.
function CommunityRoles.get(player: Player): RoleSet
	local cached = cache[player]
	if cached then
		return cached
	end

	-- Another call is already looking this player up: wait for its answer.
	local waiting = pending[player]
	if waiting then
		table.insert(waiting, coroutine.running())
		return coroutine.yield()
	end
	pending[player] = {}

	local roles: RoleSet? = nil
	for attempt = 1, RETRIES do
		-- Calls a Roblox web API, which can fail now and then.
		local ok, result = pcall(fetch, player)
		if ok then
			roles = result
			break
		end
		task.wait(attempt * 2)
	end

	local answer: RoleSet = roles or {}
	if roles and player.Parent then
		cache[player] = roles
	end
	local waiters: { thread } = pending[player] or {}
	pending[player] = nil
	for _, thread in waiters do
		task.spawn(thread, answer)
	end
	return answer
end

-- True if the player holds any of `names`.
function CommunityRoles.hasAny(player: Player, names: { string }): boolean
	local roles = CommunityRoles.get(player)
	for _, name in names do
		if roles[name] then
			return true
		end
	end
	return false
end

Players.PlayerRemoving:Connect(function(player: Player)
	cache[player] = nil
end)

return CommunityRoles
