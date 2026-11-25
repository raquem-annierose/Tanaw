--!nonstrict
-- Admin panel, server side: levels, actions, bans, name tags, logs, polls and countdowns.
--
-- Who gets the panel: AdminAuth.panelLevel (now only the community Owner). The panel UI
-- (ServerStorage.AdminPanelUi) is copied only into those players' PlayerGui, and every action is
-- checked again here, so a player can't give themselves powers by changing their client.
--
-- Everyone gets announcements, countdowns and polls through the LiveEvents remote
-- (client: LiveEventsController).
--
-- Every text an admin shows to other players goes through Roblox's text filter.
-- Saved data (names in Config.AdminPanel): bans, name tags, each admin's panel prefs, and a log of
-- admin actions from every server. Bans also use Roblox's Ban API (Players:BanAsync).

local DataStoreService = game:GetService("DataStoreService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local AdminAuth = require(script.Parent.AdminAuth)
local Config = require(ReplicatedStorage.Shared.core.Config)
local Remotes = require(ReplicatedStorage.Shared.core.Remotes)

local PanelConfig = Config.AdminPanel
local UI_TEMPLATE = "AdminPanelUi"
local UI_HOLDER = "TanawAdminPanel"

local AdminPanelService = {}

-- Made in start(), before any DataStore call, so clients never wait on them.
local remote: RemoteFunction
local liveEvents: RemoteEvent

---------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------
local function str(v, max)
	if type(v) ~= "string" then
		return ""
	end
	v = string.sub(v, 1, max or 200)
	return string.match(v, "^%s*(.-)%s*$") or ""
end

local function num(v, min, max)
	v = tonumber(v)
	if not v or v ~= v then
		return nil
	end
	return math.clamp(v, min, max)
end

local function limitChars(s, n)
	local len = utf8.len(s)
	if not len then
		return ""
	end
	if len <= n then
		return s
	end
	return string.sub(s, 1, (utf8.offset(s, n + 1) or (#s + 1)) - 1)
end

-- Every admin text that other players see goes through Roblox's text filter (Roblox's rules
-- apply to staff too). Returns nil if the filter fails, so unfiltered text is never shown.
local function filterText(admin, text)
	if text == "" then
		return ""
	end
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, admin.UserId):GetNonChatStringForBroadcastAsync()
	end)
	if ok and type(result) == "string" then
		return result
	end
	warn("[AdminPanel] Text filter failed: " .. tostring(result))
	return nil
end

local function getRoot(p)
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end

local function getHum(p)
	return p.Character and p.Character:FindFirstChildOfClass("Humanoid")
end

local function parseColor(hex)
	hex = tostring(hex or "")
	local r, g, b =
		tonumber(string.sub(hex, 1, 2), 16),
		tonumber(string.sub(hex, 3, 4), 16),
		tonumber(string.sub(hex, 5, 6), 16)
	if r and g and b and #hex == 6 then
		return Color3.fromRGB(r, g, b)
	end
	return Color3.new(1, 1, 1)
end

---------------------------------------------------------------------
-- Bans (DataStore)
---------------------------------------------------------------------
local banStore = DataStoreService:GetDataStore(PanelConfig.BanStore)
local banIndex = {} -- ["userId"] = { name, reason, by, time, expires }
local lastBanRefresh = -math.huge

local function refreshBans(force)
	if not force and os.clock() - lastBanRefresh < 30 then
		return
	end
	lastBanRefresh = os.clock()
	local ok, data = pcall(function()
		return banStore:GetAsync("Index")
	end)
	if ok then
		if type(data) == "table" then
			banIndex = data
		end
	else
		warn("[AdminPanel] Could not load bans (is API access enabled?): " .. tostring(data))
	end
end

local function mutateBans(fn)
	local ok, result = pcall(function()
		return banStore:UpdateAsync("Index", function(old)
			old = type(old) == "table" and old or {}
			fn(old)
			return old
		end)
	end)
	if ok and type(result) == "table" then
		banIndex = result
	else
		fn(banIndex)
		warn("[AdminPanel] Ban only saved for this server: " .. tostring(result))
	end
end

local function banMessage(info)
	local msg = "You are banned from this game.\nReason: " .. (info.reason or "No reason given")
	if info.expires then
		msg ..= "\nExpires in " .. math.max(1, math.ceil((info.expires - os.time()) / 60)) .. " minute(s)."
	else
		msg ..= "\nThis ban is permanent."
	end
	return msg
end

local function checkBan(player)
	refreshBans(false)
	local key = tostring(player.UserId)
	local info = banIndex[key]
	if not info then
		return false
	end
	if info.expires and os.time() >= info.expires then
		mutateBans(function(t)
			t[key] = nil
		end)
		return false
	end
	player:Kick(banMessage(info))
	return true
end

---------------------------------------------------------------------
-- Roles (DataStore)
---------------------------------------------------------------------
local roleStore = DataStoreService:GetDataStore(PanelConfig.RoleStore)
local roleData = { roles = {}, assign = {} } -- roles[id] = {name, icon, color, level}; assign["userId"] = id
local lastRoleRefresh = -math.huge

local function makeId(existing, name)
	local base = string.lower(name):gsub("%W", "")
	if base == "" then
		base = "role"
	end
	local id = base
	while existing[id] do
		id = base .. math.random(100, 999)
	end
	return id
end

local function normalize(data)
	if type(data) ~= "table" then
		data = {}
	end
	if type(data.roles) ~= "table" then
		data.roles = {}
	end
	if type(data.assign) ~= "table" then
		data.assign = {}
	end
	if not data.seeded and next(data.roles) == nil then
		data.seeded = true
		for _, r in PanelConfig.DefaultRoles do
			data.roles[makeId(data.roles, r.name)] =
				{ name = r.name, icon = r.icon, color = r.color, level = r.level }
		end
	end
	-- Tanaw: panel roles are name tags only, they never give admin power.
	for _, r in data.roles do
		if type(r) == "table" then
			r.level = 0
		end
	end
	return data
end

local function refreshRoles(force)
	if not force and os.clock() - lastRoleRefresh < 30 then
		return
	end
	lastRoleRefresh = os.clock()
	local ok, data = pcall(function()
		return roleStore:GetAsync("Data")
	end)
	if ok then
		roleData = normalize(data)
	else
		roleData = normalize(roleData)
		warn("[AdminPanel] Could not load roles (is API access enabled?): " .. tostring(data))
	end
end

local function mutateRoles(fn)
	local ok, result = pcall(function()
		return roleStore:UpdateAsync("Data", function(old)
			old = normalize(old)
			fn(old)
			return old
		end)
	end)
	if ok and type(result) == "table" then
		roleData = normalize(result)
	else
		fn(roleData)
		warn("[AdminPanel] Role change only saved for this server: " .. tostring(result))
	end
end

local function roleOf(userId)
	local id = roleData.assign[tostring(userId)]
	if id then
		return roleData.roles[id], id
	end
	return nil
end
-- Per-admin preferences (theme, UI size)
local prefStore = DataStoreService:GetDataStore(PanelConfig.PrefStore)
local prefs = {} -- [player] = { theme, scale }
local prefSavePending = {}

local function loadPrefs(player)
	if prefs[player] then
		return prefs[player]
	end
	local ok, data = pcall(function()
		return prefStore:GetAsync(tostring(player.UserId))
	end)
	prefs[player] = (ok and type(data) == "table") and data or {}
	return prefs[player]
end

---------------------------------------------------------------------
-- Permission levels
---------------------------------------------------------------------
local levels = {}

-- 0 = no panel. Only community roles decide this (AdminAuth); name tags never add a level.
local function getLevel(player)
	local level = levels[player]
	if level == nil then
		level = AdminAuth.panelLevel(player)
		levels[player] = level
	end
	return level
end

local function canTarget(admin, target)
	return target == admin or getLevel(target) < getLevel(admin)
end

---------------------------------------------------------------------
-- Role tags + attributes
---------------------------------------------------------------------
local function applyRoleAttributes(player)
	local role = roleOf(player.UserId)
	player:SetAttribute("AdminRole", role and role.name or nil)
	player:SetAttribute("AdminRoleIcon", role and role.icon or nil)
	player:SetAttribute("AdminRoleColor", role and role.color or nil)
end

local function applyTag(player)
	local char = player.Character
	local head = char and char:WaitForChild("Head", 5)
	if not head then
		return
	end
	local old = head:FindFirstChild("AdminRoleTag")
	if old then
		old:Destroy()
	end
	if not PanelConfig.ShowRoleTags then
		return
	end
	local role = roleOf(player.UserId)
	if not role then
		return
	end

	local bb = Instance.new("BillboardGui")
	bb.Name = "AdminRoleTag"
	bb.Adornee = head
	bb.Size = UDim2.fromOffset(220, 24)
	bb.StudsOffset = Vector3.new(0, 2.7, 0)
	bb.MaxDistance = 90
	bb.ResetOnSpawn = false

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.GothamBold
	text.TextSize = 16
	text.Text = (role.icon or "") .. " " .. (role.name or "")
	text.TextColor3 = parseColor(role.color)
	text.TextStrokeTransparency = 0.35
	text.Parent = bb

	bb.Parent = head
end

local function refreshPlayerRole(player)
	applyRoleAttributes(player)
	task.spawn(applyTag, player)
end

---------------------------------------------------------------------
-- Logs
---------------------------------------------------------------------
local logs = {}

-- Saved log: each server adds its new lines to AdminLog_v1 (one key per UTC day) once a minute
-- and when it closes, so admins can see what happened on every server.
local logStore = DataStoreService:GetDataStore(PanelConfig.LogStore)
local pendingLogs = {}
local MAX_SAVED_LOGS = 500
local thisServer = string.sub(game.JobId, 1, 8)

local function dayKey(t)
	return os.date("!%Y-%m-%d", t)
end

local function log(admin, text)
	table.insert(logs, string.format("[%s UTC] %s: %s", os.date("!%H:%M:%S"), admin.Name, text))
	while #logs > PanelConfig.MaxLogs do
		table.remove(logs, 1)
	end
	if #pendingLogs < MAX_SAVED_LOGS then
		table.insert(pendingLogs, {
			t = os.time(),
			by = admin.UserId,
			name = admin.Name,
			text = limitChars(text, 200),
			server = thisServer,
		})
	end
	print("[AdminPanel] " .. admin.Name .. ": " .. text)
end

local function flushLogs()
	if #pendingLogs == 0 then
		return
	end
	local batch = pendingLogs
	pendingLogs = {}
	local byDay = {}
	for _, e in batch do
		local k = dayKey(e.t)
		byDay[k] = byDay[k] or {}
		table.insert(byDay[k], e)
	end
	for k, entries in byDay do
		local ok, err = pcall(function()
			logStore:UpdateAsync(k, function(old)
				old = type(old) == "table" and old or {}
				for _, e in entries do
					table.insert(old, e)
				end
				while #old > MAX_SAVED_LOGS do
					table.remove(old, 1)
				end
				return old
			end)
		end)
		if not ok then
			warn("[AdminPanel] Could not save the admin log: " .. tostring(err))
			for _, e in entries do
				if #pendingLogs < MAX_SAVED_LOGS then
					table.insert(pendingLogs, e)
				end
			end
		end
	end
end

---------------------------------------------------------------------
-- Player lookup
---------------------------------------------------------------------
local function findPlayers(admin, query)
	query = string.lower(query)
	local result = {}
	if query == "" then
		return result
	end
	if query == "all" or query == "others" then
		for _, p in Players:GetPlayers() do
			if query == "all" or p ~= admin then
				table.insert(result, p)
			end
		end
		return result
	end
	if query == "me" then
		return { admin }
	end
	for _, p in Players:GetPlayers() do
		if string.lower(p.Name) == query or string.lower(p.DisplayName) == query then
			return { p }
		end
	end
	for _, p in Players:GetPlayers() do
		if
			string.sub(string.lower(p.Name), 1, #query) == query
			or string.sub(string.lower(p.DisplayName), 1, #query) == query
		then
			return { p }
		end
	end
	return result
end

-- Resolves one player, online or not. Returns userId, name, onlinePlayer, errorMessage
local function resolveUser(admin, query)
	local lowered = string.lower(query)
	if lowered == "" or lowered == "all" or lowered == "others" then
		return nil, nil, nil, "Pick one specific player."
	end
	local online = findPlayers(admin, query)[1]
	if online then
		return online.UserId, online.Name, online
	end
	local asId = tonumber(query)
	if asId then
		local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, asId)
		return asId, ok and n or ("User " .. asId)
	end
	local ok, id = pcall(Players.GetUserIdFromNameAsync, Players, query)
	if not ok then
		return nil, nil, nil, "Player not found."
	end
	return id, query
end

-- Runs fn(target) on every player matched by `query`, returns (ok, message).
local function applyTo(admin, query, protected, verb, fn)
	local targets = findPlayers(admin, str(query, 50))
	if #targets == 0 then
		return false, "No player found."
	end
	local done = {}
	for _, t in targets do
		local skipSelf = protected and #targets > 1 and t == admin
		if not skipSelf and (not protected or canTarget(admin, t)) then
			if pcall(fn, t) then
				table.insert(done, t)
			end
		end
	end
	if #done == 0 then
		return false, "You can't do that to that player."
	end
	local who = #done == 1 and done[1].Name or (#done .. " players")
	log(admin, verb .. " " .. who)
	return true, verb .. " " .. who .. "."
end

local shuttingDown = false

---------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------
local actions = {}
local function define(name, level, fn)
	actions[name] = { level = level, fn = fn }
end

-- Moderation -------------------------------------------------------
define("kick", 1, function(admin, query, reason)
	reason = filterText(admin, str(reason, 100))
	if not reason then
		return false, "Couldn't check the reason text. Try again."
	end
	if reason == "" then
		reason = "You were kicked by an admin."
	end
	return applyTo(admin, query, true, "Kicked", function(t)
		t:Kick(reason)
	end)
end)

define("ban", 2, function(admin, query, reason, minutes)
	local userId, name, online, err = resolveUser(admin, str(query, 50))
	if not userId then
		return false, err
	end
	reason = filterText(admin, str(reason, 100))
	if not reason then
		return false, "Couldn't check the reason text. Try again."
	end
	if reason == "" then
		reason = "No reason given"
	end
	minutes = math.ceil(num(minutes, 0, 525600 * 5) or 0)

	if online and (online == admin or not canTarget(admin, online)) then
		return false, "You can't ban that player."
	end
	if
		userId == admin.UserId
		or (game.CreatorType == Enum.CreatorType.User and userId == game.CreatorId)
	then
		return false, "You can't ban that player."
	end

	local info = {
		name = name,
		reason = reason,
		by = admin.Name,
		time = os.time(),
		expires = minutes > 0 and (os.time() + minutes * 60) or nil,
	}

	-- Roblox's Ban API: removes them from every server right away and keeps them out (alt
	-- accounts too). It only applies on live servers; in Studio the panel's own list below and
	-- the check on join still work.
	local apiOk, apiErr = pcall(function()
		Players:BanAsync({
			UserIds = { userId },
			ApplyToUniverse = true,
			Duration = minutes > 0 and minutes * 60 or -1,
			DisplayReason = reason,
			PrivateReason = "Admin panel, by " .. admin.Name .. " (" .. admin.UserId .. ")",
			ExcludeAltAccounts = false,
		})
	end)
	if not apiOk then
		warn("[AdminPanel] Ban API failed, using the panel's ban list only: " .. tostring(apiErr))
	end

	mutateBans(function(t)
		t[tostring(userId)] = info
	end)
	if online and online.Parent then
		online:Kick(banMessage(info))
	end
	log(
		admin,
		"Banned "
			.. name
			.. (minutes > 0 and (" for " .. minutes .. " min") or " permanently")
			.. " ("
			.. reason
			.. ")"
	)
	return true, "Banned " .. name .. "."
end)

define("unban", 2, function(admin, query)
	query = str(query, 50)
	if query == "" then
		return false, "Enter a name or UserId."
	end
	local lowered = string.lower(query)
	refreshBans(true)
	local key
	for k, info in banIndex do
		if k == lowered or string.lower(info.name or "") == lowered then
			key = k
			break
		end
	end
	local userId = key and tonumber(key)
	local name = key and (banIndex[key].name or key)
	if not userId then
		-- Not on the panel's list: may still be a Ban API ban (e.g. made in the Creator Hub).
		local id, n = resolveUser(admin, query)
		if not id then
			return false, "That player isn't banned."
		end
		userId, name = id, n
	end
	local apiOk, apiErr = pcall(function()
		Players:UnbanAsync({ UserIds = { userId }, ApplyToUniverse = true })
	end)
	if not apiOk then
		warn("[AdminPanel] Ban API unban failed: " .. tostring(apiErr))
		if not key then
			return false, "Couldn't unban (Ban API error). Try again."
		end
	end
	if key then
		mutateBans(function(t)
			t[key] = nil
		end)
	end
	log(admin, "Unbanned " .. name)
	return true, "Unbanned " .. name .. "."
end)

define("banlist", 2, function()
	refreshBans(true)
	local list = {}
	for key, info in banIndex do
		local expires = "Permanent"
		if info.expires then
			expires = "Expires in "
				.. math.max(1, math.ceil((info.expires - os.time()) / 60))
				.. " min"
		end
		table.insert(list, {
			userId = key,
			name = info.name or key,
			reason = info.reason or "",
			by = info.by or "?",
			expires = expires,
		})
	end
	table.sort(list, function(a, b)
		return string.lower(a.name) < string.lower(b.name)
	end)
	return true, list
end)

define("logs", 1, function()
	-- Saved log of every server (today and yesterday, UTC), plus this server's unsaved lines.
	local entries, loaded = {}, false
	for _, k in { dayKey(os.time()), dayKey(os.time() - 86400) } do
		local ok, saved = pcall(function()
			return logStore:GetAsync(k)
		end)
		if ok then
			loaded = true
			if type(saved) == "table" then
				for _, e in saved do
					table.insert(entries, e)
				end
			end
		end
	end
	local out = {}
	if not loaded then
		for i = #logs, 1, -1 do
			table.insert(out, logs[i])
		end
		return true, out
	end
	for _, e in pendingLogs do
		table.insert(entries, e)
	end
	table.sort(entries, function(a, b)
		return (tonumber(a.t) or 0) > (tonumber(b.t) or 0)
	end)
	for i = 1, math.min(#entries, 150) do
		local e = entries[i]
		local where = (e.server and e.server ~= thisServer)
				and (" (server " .. tostring(e.server) .. ")")
			or ""
		table.insert(
			out,
			string.format(
				"[%s UTC] %s: %s%s",
				os.date("!%m-%d %H:%M", tonumber(e.t) or 0),
				tostring(e.name),
				tostring(e.text),
				where
			)
		)
	end
	return true, out
end)

-- Teleport ---------------------------------------------------------
define("goto", 1, function(admin, query)
	local targets = findPlayers(admin, str(query, 50))
	if #targets ~= 1 then
		return false, "Pick a single player."
	end
	local t = targets[1]
	local root = getRoot(t)
	if not root or not admin.Character then
		return false, "Character not available."
	end
	admin.Character:PivotTo(root.CFrame * CFrame.new(0, 0, 5))
	log(admin, "Teleported to " .. t.Name)
	return true, "Teleported to " .. t.Name .. "."
end)

define("bring", 1, function(admin, query)
	local root = getRoot(admin)
	if not root then
		return false, "Your character isn't loaded."
	end
	local i = 0
	return applyTo(admin, query, true, "Brought", function(t)
		i += 1
		local angle = i * (math.pi * 2 / 8)
		t.Character:PivotTo(root.CFrame * CFrame.new(math.cos(angle) * 6, 0, math.sin(angle) * 6))
	end)
end)

-- Player tools -----------------------------------------------------
define("freeze", 1, function(admin, query)
	return applyTo(admin, query, true, "Froze", function(t)
		assert(getRoot(t)).Anchored = true
	end)
end)

define("unfreeze", 1, function(admin, query)
	return applyTo(admin, query, false, "Unfroze", function(t)
		assert(getRoot(t)).Anchored = false
	end)
end)
define("respawn", 1, function(admin, query)
	return applyTo(admin, query, true, "Respawned", function(t)
		t:LoadCharacter()
	end)
end)

define("speed", 1, function(admin, query, value)
	local v = num(value, 0, 500)
	if not v then
		return false, "Enter a number first."
	end
	return applyTo(admin, query, false, "Set speed to " .. v .. " for", function(t)
		assert(getHum(t)).WalkSpeed = v
	end)
end)

define("invisible", 1, function(admin, query, on)
	on = on == true
	return applyTo(admin, query, false, on and "Made invisible" or "Made visible", function(t)
		for _, d in assert(t.Character, "no character"):GetDescendants() do
			if (d:IsA("BasePart") and d.Name ~= "HumanoidRootPart") or d:IsA("Decal") then
				if on then
					if d:GetAttribute("AdminOrigTransparency") == nil then
						d:SetAttribute("AdminOrigTransparency", d.Transparency)
					end
					d.Transparency = 1
				else
					local orig = d:GetAttribute("AdminOrigTransparency")
					if orig ~= nil then
						d.Transparency = orig
						d:SetAttribute("AdminOrigTransparency", nil)
					end
				end
			end
		end
	end)
end)

local jails = {}

define("jail", 2, function(admin, query)
	return applyTo(admin, query, true, "Jailed", function(t)
		local root = assert(getRoot(t))
		if jails[t] then
			jails[t]:Destroy()
		end
		local model = Instance.new("Model")
		model.Name = "AdminJail_" .. t.Name
		local pos = root.Position
		local function wall(size, offset)
			local part = Instance.new("Part")
			part.Size = size
			part.Anchored = true
			part.CanCollide = true
			part.Material = Enum.Material.ForceField
			part.Color = Color3.fromRGB(255, 80, 80)
			part.Position = pos + offset
			part.Parent = model
		end
		wall(Vector3.new(10, 1, 10), Vector3.new(0, -3.6, 0))
		wall(Vector3.new(10, 1, 10), Vector3.new(0, 7.5, 0))
		wall(Vector3.new(10, 10, 1), Vector3.new(0, 2, 5))
		wall(Vector3.new(10, 10, 1), Vector3.new(0, 2, -5))
		wall(Vector3.new(1, 10, 10), Vector3.new(5, 2, 0))
		wall(Vector3.new(1, 10, 10), Vector3.new(-5, 2, 0))
		model.Parent = Workspace
		jails[t] = model
		Debris:AddItem(model, 25)
	end)
end)

define("unjail", 2, function(admin, query)
	return applyTo(admin, query, false, "Freed", function(t)
		local j = jails[t]
		assert(j and j.Parent, "not jailed")
		j:Destroy()
		jails[t] = nil
	end)
end)

-- Preferences -------------------------------------------------------
define("setprefs", 1, function(admin, theme, scale)
	local p = loadPrefs(admin)
	theme = str(theme, 24)
	if theme ~= "" and string.match(theme, "^[%w ]+$") then
		p.theme = theme
	end
	local sc = num(scale, 0.6, 1.5)
	if sc then
		p.scale = sc
	end
	if not prefSavePending[admin] then
		prefSavePending[admin] = true
		task.delay(3, function()
			prefSavePending[admin] = nil
			pcall(function()
				prefStore:SetAsync(tostring(admin.UserId), p)
			end)
		end)
	end
	return true
end)

-- Server -----------------------------------------------------------
define("announce", 2, function(admin, text, duration)
	text = str(text, 250)
	if text == "" then
		return false, "Type an announcement first."
	end
	text = filterText(admin, text)
	if not text then
		return false, "Couldn't check the text. Try again."
	end
	local d = num(duration, 3, 30) or 8
	liveEvents:FireAllClients("Announce", text, admin.DisplayName, d)
	log(admin, "Announced: " .. text)
	return true, "Announcement sent."
end)

define("shutdown", 3, function(admin, reason)
	reason = filterText(admin, str(reason, 100)) or ""
	shuttingDown = true
	log(admin, "Shut down the server")
	local msg = "This server was closed by an admin."
		.. (reason ~= "" and ("\nReason: " .. reason) or "")
	for _, p in Players:GetPlayers() do
		p:Kick(msg)
	end
	return true, "Shutting down..."
end)

-- Roles ------------------------------------------------------------
local function roleList()
	local list = {}
	for id, r in roleData.roles do
		table.insert(list, {
			id = id,
			name = r.name,
			icon = r.icon,
			color = r.color,
			level = tonumber(r.level) or 0,
		})
	end
	table.sort(list, function(a, b)
		if a.level ~= b.level then
			return a.level > b.level
		end
		return string.lower(a.name) < string.lower(b.name)
	end)
	return list
end

define("roles", 2, function()
	refreshRoles(false)
	return true, roleList()
end)

define("setrole", 2, function(admin, query, roleId)
	local adminLevel = getLevel(admin)
	roleId = str(roleId, 40)

	local role
	if roleId ~= "" then
		role = roleData.roles[roleId]
		if not role then
			return false, "That role doesn't exist."
		end
		if adminLevel < 3 and (tonumber(role.level) or 0) >= adminLevel then
			return false, "You can only give roles below your own level."
		end
	end

	local userId, name, online, err = resolveUser(admin, str(query, 50))
	if not userId then
		return false, err
	end
	if adminLevel < 3 then
		if userId == admin.UserId then
			return false, "You can't change your own role."
		end
		if online and not canTarget(admin, online) then
			return false, "You can't change that player's role."
		end
		local current = roleOf(userId)
		if current and (tonumber(current.level) or 0) >= adminLevel then
			return false, "You can't change that player's role."
		end
	end

	local key = tostring(userId)
	mutateRoles(function(t)
		t.assign[key] = roleId ~= "" and roleId or nil
	end)
	if online then
		refreshPlayerRole(online)
	end

	if role then
		log(admin, "Gave role " .. role.name .. " to " .. name)
		return true, "Gave " .. role.name .. " to " .. name .. "."
	end
	log(admin, "Removed the role of " .. name)
	return true, "Removed the role of " .. name .. "."
end)

define("createrole", 3, function(admin, name, icon, color)
	name = str(name, 24)
	if name == "" then
		return false, "Enter a role name."
	end
	icon = limitChars(str(icon, 16), 3)
	if icon == "" then
		icon = "⭐"
	end
	-- Role names and icons show above heads, so they go through the filter.
	name, icon = filterText(admin, name), filterText(admin, icon)
	if not name or not icon then
		return false, "Couldn't check the text. Try again."
	end
	color = string.upper((string.gsub(str(color, 8), "#", "")))
	if not string.match(color, "^%x%x%x%x%x%x$") then
		color = "FFFFFF"
	end

	-- Tanaw: panel roles are name tags only (level 0).
	mutateRoles(function(t)
		t.roles[makeId(t.roles, name)] = { name = name, icon = icon, color = color, level = 0 }
	end)
	log(admin, "Created role " .. name)
	return true, "Created role " .. name .. "."
end)

define("deleterole", 3, function(admin, roleId)
	roleId = str(roleId, 40)
	local role = roleData.roles[roleId]
	if not role then
		return false, "That role doesn't exist."
	end
	local name = role.name
	mutateRoles(function(t)
		t.roles[roleId] = nil
		for userId, id in t.assign do
			if id == roleId then
				t.assign[userId] = nil
			end
		end
	end)
	for _, p in Players:GetPlayers() do
		refreshPlayerRole(p)
	end
	log(admin, "Deleted role " .. name)
	return true, "Deleted role " .. name .. "."
end)

-- Teleport locations: Parts/Models inside Workspace.AdminTeleports, else SpawnLocations
local function collectLocations()
	local list = {}
	local folder = Workspace:FindFirstChild("AdminTeleports")
	if folder then
		for _, o in folder:GetChildren() do
			if o:IsA("BasePart") or o:IsA("Model") then
				table.insert(list, {
					name = o.Name,
					desc = tostring(o:GetAttribute("Description") or "Teleport location"),
					inst = o,
				})
			end
		end
	end
	if #list == 0 then
		for _, o in Workspace:GetDescendants() do
			if o:IsA("SpawnLocation") and #list < 8 then
				table.insert(list, { name = o.Name, desc = "Spawn point", inst = o })
			end
		end
	end
	return list
end

define("tplocations", 1, function()
	local out = {}
	for _, l in collectLocations() do
		table.insert(out, { name = l.name, desc = l.desc })
	end
	return true, out
end)

define("tploc", 1, function(admin, query, locName)
	locName = str(locName, 60)
	local found
	for _, l in collectLocations() do
		if l.name == locName then
			found = l.inst
			break
		end
	end
	if not found then
		return false, "Location not found."
	end
	local cf = found:IsA("Model") and found:GetPivot() or found.CFrame
	local i = 0
	return applyTo(admin, query, true, "Teleported to " .. locName .. ":", function(t)
		local n = i
		i += 1
		assert(t.Character, "no character"):PivotTo(
			cf * CFrame.new((n % 4) * 4, 4, math.floor(n / 4) * 4)
		)
	end)
end)

---------------------------------------------------------------------
-- NEW: Countdown
---------------------------------------------------------------------
local countdown = nil -- { token, endsAt, payload }

define("countdown", 2, function(admin, seconds, title, finalText)
	local secs = math.floor(num(seconds, 1, 600) or 10)
	title = filterText(admin, str(title, 60))
	finalText = filterText(admin, str(finalText, 30))
	if not title or not finalText then
		return false, "Couldn't check the text. Try again."
	end
	if title == "" then
		title = "Starting in"
	end
	if finalText == "" then
		finalText = "GO!"
	end
	local endsAt = Workspace:GetServerTimeNow() + secs
	local token = {}
	local payload = {
		endsAt = endsAt,
		title = title,
		final = finalText,
		tick = PanelConfig.CountdownTickSound or "",
		go = PanelConfig.CountdownGoSound or "",
	}
	countdown = { token = token, endsAt = endsAt, payload = payload }
	Workspace:SetAttribute("AdminCountdownEndsAt", endsAt) -- your own scripts can read this
	liveEvents:FireAllClients("Countdown", "start", payload)
	task.delay(secs + 3, function()
		if countdown and countdown.token == token then
			countdown = nil
			Workspace:SetAttribute("AdminCountdownEndsAt", nil)
		end
	end)
	log(admin, "Started a " .. secs .. "s countdown (" .. title .. ")")
	return true, "Countdown started (" .. secs .. "s)."
end)

define("cancelcountdown", 2, function(admin)
	if not countdown then
		return false, "No countdown is running."
	end
	countdown = nil
	Workspace:SetAttribute("AdminCountdownEndsAt", nil)
	liveEvents:FireAllClients("Countdown", "cancel", 0)
	log(admin, "Cancelled the countdown")
	return true, "Countdown cancelled."
end)

---------------------------------------------------------------------
-- NEW: Polls
---------------------------------------------------------------------
local poll = nil -- active poll
local lastPoll = nil -- result of the last finished poll
local pollCounter = 0
local pollDirty = false
local lastVote = {}

local function pollCounts(p)
	local counts = table.create(#p.options, 0)
	for _, idx in p.votes do
		if counts[idx] then
			counts[idx] += 1
		end
	end
	return counts
end

local function pollPayload(p)
	return {
		id = p.id,
		question = p.question,
		options = p.options,
		endsAt = p.endsAt,
		counts = pollCounts(p),
	}
end

local function finishPoll(p)
	if poll ~= p then
		return
	end
	poll = nil
	local counts = pollCounts(p)
	local total, best, bestIdx, tie = 0, -1, 0, false
	for i, c in counts do
		total += c
		if c > best then
			best, bestIdx, tie = c, i, false
		elseif c == best then
			tie = true
		end
	end
	local result = {
		id = p.id,
		question = p.question,
		options = p.options,
		counts = counts,
		total = total,
		winner = (total > 0 and not tie) and bestIdx or nil,
		tie = total > 0 and tie or false,
	}
	lastPoll = result
	liveEvents:FireAllClients("Poll", "end", result)
	local msg
	if total == 0 then
		msg = "📊 Poll ended - nobody voted."
	elseif tie then
		msg = "📊 Poll ended - it's a tie!"
	else
		msg = '📊 Poll ended - "'
			.. p.options[bestIdx]
			.. '" won with '
			.. best
			.. " of "
			.. total
			.. " vote(s)."
	end
	liveEvents:FireAllClients("Announce", msg, "Poll", 7)
end

define("startpoll", 2, function(admin, question, options, seconds)
	question = str(question, 120)
	if question == "" then
		return false, "Type a question first."
	end
	if type(options) ~= "table" then
		return false, "Add at least two options."
	end
	local opts = {}
	for i = 1, 6 do
		local o = options[i]
		if type(o) == "string" then
			o = limitChars(str(o, 80), 40)
			if o ~= "" then
				table.insert(opts, o)
			end
		end
	end
	if #opts < 2 then
		return false, "Add at least two options."
	end
	question = filterText(admin, question)
	if not question then
		return false, "Couldn't check the text. Try again."
	end
	for i, o in opts do
		local clean = filterText(admin, o)
		if not clean then
			return false, "Couldn't check the text. Try again."
		end
		opts[i] = clean
	end
	if poll then
		return false, "A poll is already running. End it first."
	end
	local secs = math.floor(num(seconds, 5, 600) or 30)
	pollCounter += 1
	local p = {
		id = pollCounter,
		question = question,
		options = opts,
		votes = {}, -- [userId] = option index
		endsAt = Workspace:GetServerTimeNow() + secs,
	}
	poll = p
	lastPoll = nil
	liveEvents:FireAllClients("Poll", "start", pollPayload(p))
	task.delay(secs, function()
		finishPoll(p)
	end)
	log(admin, "Started poll: " .. question)
	return true, "Poll started."
end)

define("endpoll", 2, function(admin)
	if not poll then
		return false, "No poll is running."
	end
	finishPoll(poll)
	log(admin, "Ended the poll early")
	return true, "Poll ended."
end)

define("pollstatus", 2, function()
	if poll then
		return true,
			{
				active = true,
				question = poll.question,
				options = poll.options,
				counts = pollCounts(poll),
				remaining = math.max(0, math.ceil(poll.endsAt - Workspace:GetServerTimeNow())),
			}
	end
	if lastPoll then
		return true,
			{
				active = false,
				question = lastPoll.question,
				options = lastPoll.options,
				counts = lastPoll.counts,
				winner = lastPoll.winner,
				tie = lastPoll.tie,
				total = lastPoll.total,
			}
	end
	return true, { active = false }
end)

-- Everyone (not just admins) can vote; the server counts one vote per player.
local function onVote(player, pollId, idx)
	local p = poll
	if not p or pollId ~= p.id then
		return
	end
	if type(idx) ~= "number" or idx ~= idx then
		return
	end
	idx = math.floor(idx)
	if idx < 1 or idx > #p.options then
		return
	end
	local now = os.clock()
	if lastVote[player] and now - lastVote[player] < 0.25 then
		return
	end
	lastVote[player] = now
	p.votes[player.UserId] = idx
	if not pollDirty then
		pollDirty = true
		task.delay(0.8, function()
			pollDirty = false
			if poll == p then
				liveEvents:FireAllClients("Poll", "update", { id = p.id, counts = pollCounts(p) })
			end
		end)
	end
end

---------------------------------------------------------------------
-- Remote handler
---------------------------------------------------------------------
local lastCall = {}

local function onInvoke(player, action, ...)
	if type(action) ~= "string" then
		return false, "Bad request."
	end

	local level = getLevel(player)

	if action == "init" then
		if level < 1 then
			return true, { level = 0 }
		end
		local pr = loadPrefs(player)
		return true,
			{
				level = level,
				toggleKey = PanelConfig.ToggleKey,
				topbarAlign = PanelConfig.TopbarAlign,
				prefs = { theme = pr.theme, scale = pr.scale },
			}
	end

	local def = actions[action]
	if not def or level < def.level then
		return false, "You don't have permission to do that."
	end

	local now = os.clock()
	if lastCall[player] and now - lastCall[player] < 0.05 then
		return false, "Slow down."
	end
	lastCall[player] = now

	local ok, a, b = pcall(def.fn, player, ...)
	if not ok then
		warn("[AdminPanel] Error in '" .. action .. "': " .. tostring(a))
		return false, "Something went wrong."
	end
	return a, b
end

---------------------------------------------------------------------
-- Player setup
---------------------------------------------------------------------
local setUp = {}

-- Copies the panel UI into an admin's PlayerGui. Other players never receive its code.
local function giveUi(player)
	local template = ServerStorage:FindFirstChild(UI_TEMPLATE)
	if not template then
		warn("[AdminPanel] ServerStorage." .. UI_TEMPLATE .. " is missing")
		return
	end
	local playerGui = player:WaitForChild("PlayerGui", 30)
	if not playerGui or playerGui:FindFirstChild(UI_HOLDER) then
		return
	end
	-- A holder that survives respawns, so the panel keeps its state.
	local holder = Instance.new("ScreenGui")
	holder.Name = UI_HOLDER
	holder.ResetOnSpawn = false
	template:Clone().Parent = holder
	holder.Parent = playerGui
end

local function setup(player)
	if setUp[player] then
		return
	end
	setUp[player] = true

	player.CharacterAdded:Connect(function()
		task.spawn(applyTag, player)
	end)

	if shuttingDown then
		player:Kick("This server is shutting down.")
		return
	end
	if checkBan(player) then
		return
	end
	refreshRoles(false)
	applyRoleAttributes(player)
	task.spawn(applyTag, player)
	if getLevel(player) >= 1 then
		task.spawn(giveUi, player)
	end
	-- Late joiners still see a countdown or poll that is running.
	task.delay(5, function()
		if not player.Parent then
			return
		end
		if countdown and Workspace:GetServerTimeNow() < countdown.endsAt + 3 then
			liveEvents:FireClient(player, "Countdown", "start", countdown.payload)
		end
		if poll then
			liveEvents:FireClient(player, "Poll", "start", pollPayload(poll))
		end
	end)
end

-- Publishes each player's ping so the panel can show it (GetNetworkPing is server-only).
local function publishPings()
	while true do
		for _, p in Players:GetPlayers() do
			local ok, ping = pcall(function()
				return p:GetNetworkPing()
			end)
			if ok and type(ping) == "number" then
				p:SetAttribute("AdminPing", math.floor(ping * 2000))
			end
		end
		task.wait(3)
	end
end

function AdminPanelService.start()
	-- Remotes first: nothing below may yield before they exist.
	remote = Remotes.adminPanel()
	liveEvents = Remotes.liveEvents()
	remote.OnServerInvoke = onInvoke
	liveEvents.OnServerEvent:Connect(function(player, kind, ...)
		if kind == "Vote" then
			onVote(player, ...)
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		setUp[p] = nil
		levels[p] = nil
		lastCall[p] = nil
		lastVote[p] = nil
		prefs[p] = nil
		if jails[p] then
			jails[p]:Destroy()
			jails[p] = nil
		end
	end)

	task.spawn(function()
		-- Load bans and name tags before checking anyone who joins.
		refreshBans(true)
		refreshRoles(true)
		Players.PlayerAdded:Connect(setup)
		for _, p in Players:GetPlayers() do
			task.spawn(setup, p)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(60)
			flushLogs()
		end
	end)
	game:BindToClose(flushLogs)
	task.spawn(publishPings)
end

return AdminPanelService
