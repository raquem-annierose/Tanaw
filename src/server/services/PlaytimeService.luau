--!strict
-- Playtime ranking. Counts how long each player stays in Tanaw (AFK counts too) and keeps the
-- all-time total in an OrderedDataStore (Config.Playtime.StoreName), keyed by UserId, in seconds.
-- Parts tagged Config.Playtime.BoardTag in Studio show the top players on a sign, and the player
-- list (Tab) shows everyone's all-time minutes, most first (leaderstats).
--
-- Top 3 avatars: put an invisible anchored part where each should stand (bottom face on the floor,
-- front face the way they look), tag it Config.Playtime.TopNpcTag and give it a number attribute
-- "Rank" (1, 2 or 3). The avatar there changes when someone new reaches that rank, and dances
-- (Config.Playtime.TopDances).
--
-- The experience owner (community owner, or the user for a user-owned place) still has their time
-- saved but is left off the board and the Top 3 spots.
--
-- New time is only ever added (IncrementAsync) every SaveInterval seconds and when the player
-- leaves, never overwritten, so two servers can't erase each other's time.
--
-- Studio playtests can only save if the experience allows it: Game Settings > Security >
-- "Enable Studio Access to API Services". Without it, the board says it can't load.

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local Config = require(ReplicatedStorage.Shared.Config)
local Emotes = require(ReplicatedStorage.Shared.Emotes)
local NpcService = require(script.Parent.NpcService)

local Settings = Config.Playtime
local GUI_NAME = "PlaytimeBoard"
local MEDALS = {
	Color3.fromRGB(255, 205, 90), -- 1st
	Color3.fromRGB(215, 220, 232), -- 2nd
	Color3.fromRGB(226, 150, 100), -- 3rd
}
local INK = Color3.fromRGB(16, 14, 22)
local WHITE = Color3.fromRGB(255, 255, 255)
local ACCENT = Color3.fromRGB(255, 200, 120)

type Entry = { userId: number, seconds: number }
type Row = { rank: TextLabel, name: TextLabel, time: TextLabel }
type Board = { status: TextLabel, rows: { Row } }
-- A Top 3 spot: who stands there now (0 = nobody) and their avatar once loaded.
type Podium = { rank: number, userId: number, model: Model? }

local PlaytimeService = {}

local store: OrderedDataStore? = nil
-- Seconds counted for each player that aren't saved yet, and the os.clock() they were counted to.
local unsaved: { [Player]: number } = {}
local countedTo: { [Player]: number } = {}
-- Each player's saved total (seconds) as far as this server knows, and their player list value.
local saved: { [Player]: number } = {}
local stats: { [Player]: IntValue } = {}
local warnedSave = false
local boards: { [BasePart]: Board } = {}
local podiums: { [BasePart]: Podium } = {}
-- Display names by UserId, so the board doesn't look them up every refresh.
local names: { [number]: string } = {}
local top: { Entry }? = nil
-- The owner's UserId, left off the ranking. nil until looked up (retried each refresh).
local ownerId: number? = nil

local function lookUpOwner()
	if ownerId then
		return
	end
	if game.CreatorType == Enum.CreatorType.User then
		ownerId = game.CreatorId
		return
	end
	local ok, info = pcall(function()
		return GroupService:GetGroupInfoAsync(Config.CommunityId)
	end)
	if ok and type(info) == "table" and type(info.Owner) == "table" then
		ownerId = tonumber(info.Owner.Id)
	end
end

local function formatTime(seconds: number): string
	local minutes = seconds // 60
	local hours = minutes // 60
	local days = hours // 24
	if days > 0 then
		return `{days}d {hours % 24}h`
	elseif hours > 0 then
		return `{hours}h {minutes % 60}m`
	end
	return `{minutes}m`
end

local function catchUp(player: Player)
	local now = os.clock()
	local last = countedTo[player]
	if last then
		unsaved[player] = (unsaved[player] or 0) + (now - last)
	end
	countedTo[player] = now
end

local function save(player: Player)
	catchUp(player)
	local seconds = math.floor(unsaved[player] or 0)
	local s = store
	if not s or seconds < 1 then
		return
	end
	local ok, result = pcall(function(): any
		return s:IncrementAsync(tostring(player.UserId), seconds)
	end)
	if ok then
		unsaved[player] = (unsaved[player] or 0) - seconds
		-- The new total, including time other servers added.
		if typeof(result) == "number" and countedTo[player] then
			saved[player] = result
		end
	elseif not warnedSave then
		warnedSave = true
		warn(`[Playtime] Could not save playtime (is API access on?): {result}`)
	end
end

-- Player list value: saved total plus time not saved yet, in whole minutes.
local function updateStat(player: Player)
	local stat = stats[player]
	if not stat then
		return
	end
	local counting = os.clock() - (countedTo[player] or os.clock())
	stat.Value = ((saved[player] or 0) + (unsaved[player] or 0) + counting) // 60
end

local function load(player: Player)
	local s = store
	if not s then
		return
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function(): any
			return s:GetAsync(tostring(player.UserId))
		end)
		if ok then
			-- A save that finished first already set the newer total.
			if countedTo[player] and saved[player] == nil then
				saved[player] = if typeof(result) == "number" then result else 0
				updateStat(player)
			end
			return
		end
		task.wait(attempt * 2)
	end
end

-- All-time seconds in Tanaw for a player in this server: the saved total plus this visit's time
-- not saved yet. Until the saved total loads (or if it can't), only this visit counts.
function PlaytimeService.totalSeconds(player: Player): number?
	local last = countedTo[player]
	if not last then
		return nil
	end
	return (saved[player] or 0) + (unsaved[player] or 0) + (os.clock() - last)
end

-- Board -----------------------------------------------------------------------------------------

local function label(name: string, parent: Instance, text: string): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.FontFace = Font.fromEnum(Enum.Font.BuilderSansBold)
	l.Text = text
	l.TextColor3 = WHITE
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local function buildBoard(part: BasePart): Board
	local existing = part:FindFirstChild(GUI_NAME)
	if existing then
		existing:Destroy()
	end

	local face = part:GetAttribute("Face")
	local gui = Instance.new("SurfaceGui")
	gui.Name = GUI_NAME
	gui.Face = if typeof(face) == "string" and (Enum.NormalId :: any)[face]
		then (Enum.NormalId :: any)[face]
		else Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	-- Lit like a screen, so it stays readable at night.
	gui.LightInfluence = 0
	gui.Parent = part

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = INK
	panel.BackgroundTransparency = 0.1
	panel.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.04, 0)
	padding.PaddingBottom = UDim.new(0.04, 0)
	padding.Parent = panel

	local title = label("Title", panel, "TOP TAMBAY")
	title.Size = UDim2.fromScale(1, 0.1)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextColor3 = ACCENT
	local subtitle = label("Subtitle", panel, "Most time spent in Tanaw")
	subtitle.Position = UDim2.fromScale(0, 0.1)
	subtitle.Size = UDim2.fromScale(1, 0.05)
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	subtitle.TextTransparency = 0.4
	subtitle.FontFace = Font.fromEnum(Enum.Font.BuilderSans)

	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0, 0.19)
	list.Size = UDim2.fromScale(1, 0.81)
	list.Parent = panel

	local status = label("Status", list, "Loading…")
	status.Size = UDim2.fromScale(1, 0.08)
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.TextTransparency = 0.4

	local rows: { Row } = {}
	local rowHeight = 1 / Settings.TopCount
	for i = 1, Settings.TopCount do
		local row = Instance.new("Frame")
		row.Name = `Row{i}`
		row.BackgroundColor3 = WHITE
		row.BackgroundTransparency = if i % 2 == 1 then 0.94 else 1
		row.Position = UDim2.fromScale(0, (i - 1) * rowHeight)
		row.Size = UDim2.fromScale(1, rowHeight)
		row.Visible = false
		row.Parent = list
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = row

		local rank = label("Rank", row, `{i}`)
		rank.Position = UDim2.fromScale(0.03, 0.18)
		rank.Size = UDim2.fromScale(0.1, 0.64)
		rank.TextColor3 = MEDALS[i] or WHITE
		local name = label("Name", row, "")
		name.Position = UDim2.fromScale(0.14, 0.2)
		name.Size = UDim2.fromScale(0.56, 0.6)
		name.FontFace = Font.fromEnum(Enum.Font.BuilderSans)
		local time = label("Time", row, "")
		time.Position = UDim2.fromScale(0.7, 0.2)
		time.Size = UDim2.fromScale(0.27, 0.6)
		time.TextXAlignment = Enum.TextXAlignment.Right
		time.TextColor3 = MEDALS[i] or WHITE

		rows[i] = { rank = rank, name = name, time = time }
	end

	return { status = status, rows = rows }
end

local function draw(board: Board)
	local entries = top
	board.status.Visible = entries == nil or #entries == 0
	board.status.Text = if entries == nil
		then "Can't load the ranking right now."
		else "No one yet. Stay a while!"
	for i, row in board.rows do
		local entry = entries and entries[i]
		local frame = row.rank.Parent :: Frame
		frame.Visible = entry ~= nil
		if entry then
			row.name.Text = names[entry.userId] or "…"
			row.time.Text = formatTime(entry.seconds)
		end
	end
end

local function lookUpNames(entries: { Entry })
	local missing = {}
	for _, entry in entries do
		if not names[entry.userId] then
			table.insert(missing, entry.userId)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync(missing)
	end)
	if ok then
		for _, info in infos do
			names[info.Id] = info.DisplayName
		end
	end
end

local function updatePodium(spot: BasePart, podium: Podium)
	local entries = top
	if not entries then
		-- Couldn't load the ranking: keep whoever is there.
		return
	end
	local entry = entries[podium.rank]
	local userId = if entry then entry.userId else 0
	local tag = if entry then `#{podium.rank} {names[userId] or ""}` else ""
	if userId == podium.userId then
		if podium.model then
			NpcService.setLabel(podium.model, tag)
		end
		return
	end

	podium.userId = userId
	if podium.model then
		podium.model:Destroy()
		podium.model = nil
	end
	if userId == 0 then
		return
	end
	task.spawn(function()
		local dance = Emotes.ById[Settings.TopDances[podium.rank] or ""]
		local model =
			NpcService.spawnAvatar(spot, userId, tag, if dance then dance.AnimationId else nil)
		if not model then
			return
		end
		-- The rank changed hands again (or the spot was removed) while the avatar loaded.
		if podiums[spot] ~= podium or podium.userId ~= userId then
			model:Destroy()
			return
		end
		model.Name = `Top{podium.rank}Npc`
		podium.model = model
	end)
end

local function addPodium(instance: Instance)
	if not instance:IsA("BasePart") or podiums[instance] then
		return
	end
	local rank = instance:GetAttribute("Rank")
	if typeof(rank) ~= "number" or rank < 1 or rank > Settings.TopCount then
		warn(`[Playtime] {instance:GetFullName()} needs a Rank attribute (1-{Settings.TopCount})`)
		return
	end
	local podium: Podium = { rank = rank, userId = 0, model = nil }
	podiums[instance] = podium
	updatePodium(instance, podium)
end

local function removePodium(instance: Instance)
	local podium = if instance:IsA("BasePart") then podiums[instance] else nil
	if podium then
		podiums[instance :: BasePart] = nil
		if podium.model then
			podium.model:Destroy()
		end
	end
end

local function refresh()
	local s = store
	local entries: { Entry }? = nil
	if s then
		lookUpOwner()
		local ok, result = pcall(function()
			-- One extra, in case the owner is in the top and gets skipped.
			local pages = s:GetSortedAsync(false, Settings.TopCount + 1)
			local list: { Entry } = {}
			for _, item in pages:GetCurrentPage() do
				local userId = tonumber(item.key) or 0
				if userId ~= ownerId and #list < Settings.TopCount then
					table.insert(list, { userId = userId, seconds = item.value })
				end
			end
			return list
		end)
		if ok then
			entries = result
			lookUpNames(result)
		end
	end
	top = entries
	for _, board in boards do
		draw(board)
	end
	for spot, podium in podiums do
		updatePodium(spot, podium)
	end
end

local function addBoard(instance: Instance)
	if instance:IsA("BasePart") and not boards[instance] then
		local board = buildBoard(instance)
		boards[instance] = board
		draw(board)
	end
end

local function removeBoard(instance: Instance)
	if instance:IsA("BasePart") then
		boards[instance] = nil
	end
end

function PlaytimeService.start()
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(Settings.StoreName)
	end)
	if ok then
		store = result
	else
		warn(`[Playtime] No DataStore, playtime won't be saved: {result}`)
	end

	local function onJoin(player: Player)
		countedTo[player] = os.clock()
		unsaved[player] = 0

		local leaderstats = player:FindFirstChild("leaderstats")
		if not leaderstats then
			local folder = Instance.new("Folder")
			folder.Name = "leaderstats"
			folder.Parent = player
			leaderstats = folder
		end
		local stat = Instance.new("IntValue")
		stat.Name = Settings.StatName
		stat.Parent = leaderstats
		stats[player] = stat

		load(player)
	end
	for _, player in Players:GetPlayers() do
		task.spawn(onJoin, player)
	end
	Players.PlayerAdded:Connect(onJoin)
	Players.PlayerRemoving:Connect(function(player: Player)
		save(player)
		unsaved[player] = nil
		countedTo[player] = nil
		saved[player] = nil
		stats[player] = nil
	end)

	-- Server shutting down: save everyone before it closes (Roblox allows about 30 seconds).
	game:BindToClose(function()
		local pending = 0
		for player in countedTo do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
	end)

	for _, instance in CollectionService:GetTagged(Settings.BoardTag) do
		addBoard(instance)
	end
	CollectionService:GetInstanceAddedSignal(Settings.BoardTag):Connect(addBoard)
	CollectionService:GetInstanceRemovedSignal(Settings.BoardTag):Connect(removeBoard)
	for _, instance in CollectionService:GetTagged(Settings.TopNpcTag) do
		addPodium(instance)
	end
	CollectionService:GetInstanceAddedSignal(Settings.TopNpcTag):Connect(addPodium)
	CollectionService:GetInstanceRemovedSignal(Settings.TopNpcTag):Connect(removePodium)

	task.spawn(function()
		while true do
			refresh()
			task.wait(Settings.RefreshInterval)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Settings.SaveInterval)
			for player in countedTo do
				save(player)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Settings.StatInterval)
			for player in stats do
				updateStat(player)
			end
		end
	end)
end

return PlaytimeService
