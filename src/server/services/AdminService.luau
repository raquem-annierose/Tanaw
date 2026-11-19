--!strict
-- Chat commands for testing, only in DEV and STAGING (Config.Admin.UniverseIds). In PROD the
-- commands are never created, so they don't exist there at all.
--
-- Who may use them: anyone holding a role in Config.Admin.Roles in the NieRa Studios community,
-- or listed by UserId in Config.Admin.UserIds. The server checks this on every command, so a
-- player can't unlock them by changing their own client.
--
--   /fly              fly on/off (Space up, Ctrl down, or look up/down while moving)
--   /noclip           walk through walls on/off
--   /speed [number]   walk speed; no number = back to normal
--   /tp <player>      go to a player
--   /bring <player>   bring a player to you
--   /cmds             list the commands
--
-- Fly and noclip run on the admin's own client (it controls its character's physics);
-- the server only tells that client to switch them on or off.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local CommunityRoles = require(script.Parent.CommunityRoles)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DEFAULT_WALK_SPEED = 16

type Handler = (admin: Player, args: { string }) -> ()

local AdminService = {}

local admins: { [Player]: boolean } = {}
local flying: { [Player]: boolean } = {}
local noclip: { [Player]: boolean } = {}

local remote: RemoteEvent

local function enabledHere(): boolean
	if table.find(Config.Admin.UniverseIds, game.GameId) then
		return true
	end
	-- A Studio playtest of a file that was never published has GameId 0.
	return RunService:IsStudio() and game.GameId == 0
end

local function isAdmin(player: Player): boolean
	if table.find(Config.Admin.UserIds, player.UserId) then
		return true
	end
	return CommunityRoles.hasAny(player, Config.Admin.Roles)
end

local function notice(player: Player, text: string)
	remote:FireClient(player, "Notice", text)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Finds one player by the start of their username or display name (not case-sensitive).
local function findPlayer(query: string?): (Player?, string?)
	if not query or query == "" then
		return nil, "Type a player name."
	end
	local q = string.lower(query)
	local matches = {}
	for _, p in Players:GetPlayers() do
		if
			string.sub(string.lower(p.Name), 1, #q) == q
			or string.sub(string.lower(p.DisplayName), 1, #q) == q
		then
			table.insert(matches, p)
		end
	end
	if #matches == 1 then
		return matches[1], nil
	elseif #matches == 0 then
		return nil, `No player matches "{query}".`
	end
	return nil, `"{query}" matches more than one player. Type more of the name.`
end

local commands: { [string]: Handler } = {}

commands.fly = function(admin)
	flying[admin] = not flying[admin]
	remote:FireClient(admin, "Fly", flying[admin] == true)
	notice(admin, if flying[admin] then "Fly on. Space up, Ctrl down." else "Fly off.")
end

commands.noclip = function(admin)
	noclip[admin] = not noclip[admin]
	remote:FireClient(admin, "Noclip", noclip[admin] == true)
	notice(admin, if noclip[admin] then "Noclip on." else "Noclip off.")
end

commands.speed = function(admin, args)
	local humanoid = humanoidOf(admin)
	if not humanoid then
		return
	end
	local value = tonumber(args[1]) or DEFAULT_WALK_SPEED
	value = math.clamp(value, 1, Config.Admin.MaxWalkSpeed)
	humanoid.WalkSpeed = value
	notice(admin, `Walk speed {value}.`)
end

commands.tp = function(admin, args)
	local target, err = findPlayer(args[1])
	if not target then
		notice(admin, err or "")
		return
	end
	local from, to = rootOf(admin), rootOf(target)
	if from and to and admin.Character then
		admin.Character:PivotTo(to.CFrame * CFrame.new(0, 0, 4))
		notice(admin, `Went to {target.DisplayName}.`)
	end
end

commands.bring = function(admin, args)
	local target, err = findPlayer(args[1])
	if not target then
		notice(admin, err or "")
		return
	end
	local here, there = rootOf(admin), rootOf(target)
	if here and there and target.Character then
		target.Character:PivotTo(here.CFrame * CFrame.new(0, 0, -4))
		notice(admin, `Brought {target.DisplayName}.`)
	end
end

commands.cmds = function(admin)
	notice(admin, "/fly · /noclip · /speed [number] · /tp [name] · /bring [name]")
end

local function run(source: TextSource, text: string)
	local admin = Players:GetPlayerByUserId(source.UserId)
	if not admin or not admins[admin] then
		return
	end
	local words = string.split(text, " ")
	local first = table.remove(words, 1) or ""
	local name = string.lower((string.gsub(first, "^/", "")))
	local args = {}
	for _, word in words do
		if word ~= "" then
			table.insert(args, word)
		end
	end
	local handler = commands[name]
	if handler then
		handler(admin, args)
	end
end

local function onPlayerAdded(player: Player)
	admins[player] = isAdmin(player)
	player.CharacterAdded:Connect(function()
		-- A new character starts without fly or noclip.
		flying[player] = nil
		noclip[player] = nil
	end)
end

function AdminService.start()
	if not enabledHere() then
		return
	end
	remote = Remotes.admin()

	local folder = Instance.new("Folder")
	folder.Name = "TanawAdminCommands"
	for name in commands do
		local command = Instance.new("TextChatCommand")
		command.Name = name
		command.PrimaryAlias = `/{name}`
		-- Keep the list of admin commands out of everyone's chat autocomplete.
		command.AutocompleteVisible = false
		command.Triggered:Connect(run)
		command.Parent = folder
	end
	folder.Parent = TextChatService

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		admins[player] = nil
		flying[player] = nil
		noclip[player] = nil
	end)
end

return AdminService
