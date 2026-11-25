--!nonstrict
-- Announcements, countdowns and polls that an admin starts from the admin panel. Runs for every
-- player. The server sends them through the LiveEvents remote (see AdminPanelService); all text
-- in them was filtered on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.core.Remotes)

local LiveEventsController = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local liveEvents: RemoteEvent

local function makeGui(name, order)
	local g = Instance.new("ScreenGui")
	g.Name = name
	g.ResetOnSpawn = false
	g.DisplayOrder = order
	g.IgnoreGuiInset = true
	g.Parent = playerGui
	return g
end

local announceGui = makeGui("Announcements", 200)

---------------------------------------------------------------------
-- Announcements
---------------------------------------------------------------------
local queue = {}
local showing = false

local function show(text, author, duration)
	local banner = Instance.new("Frame")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, -160)
	banner.Size = UDim2.new(0.7, 0, 0, 0)
	banner.AutomaticSize = Enum.AutomaticSize.Y
	banner.BackgroundColor3 = Color3.fromRGB(24, 26, 33)
	banner.BorderSizePixel = 0
	banner.Parent = announceGui

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = banner

	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(88, 125, 255)
	s.Thickness = 2
	s.Parent = banner

	local size = Instance.new("UISizeConstraint")
	size.MinSize = Vector2.new(240, 0)
	size.MaxSize = Vector2.new(620, math.huge)
	size.Parent = banner

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = banner

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.Parent = banner

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 18)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.TextColor3 = Color3.fromRGB(120, 150, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "📢  ANNOUNCEMENT  •  " .. author
	title.LayoutOrder = 1
	title.Parent = banner

	local body = Instance.new("TextLabel")
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.Font = Enum.Font.GothamMedium
	body.TextSize = 18
	body.TextWrapped = true
	body.TextColor3 = Color3.fromRGB(240, 242, 248)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.Text = text
	body.LayoutOrder = 2
	body.Parent = banner

	TweenService
		:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0, 70),
		})
		:Play()
	task.wait(duration + 0.4)
	local out =
		TweenService:Create(banner, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -160) })
	out:Play()
	out.Completed:Wait()
	banner:Destroy()
end

local function pump()
	if showing then
		return
	end
	showing = true
	while #queue > 0 do
		local item = table.remove(queue, 1)
		show(item[1], item[2], item[3])
	end
	showing = false
end

local function onAnnounce(text, author, duration)
	if type(text) ~= "string" then
		return
	end
	table.insert(queue, { text, tostring(author or "Admin"), tonumber(duration) or 8 })
	task.spawn(pump)
end

---------------------------------------------------------------------
-- Countdown sounds (played only on this device)
---------------------------------------------------------------------
local function playSound(id, volume)
	if type(id) ~= "string" or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.Name = "CountdownSound"
	s.SoundId = id
	s.Volume = volume
	s.Parent = SoundService
	s.Ended:Connect(function()
		s:Destroy()
	end)
	s:Play()
	-- Safety net, also for sounds that never load.
	task.delay(30, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

---------------------------------------------------------------------
-- Countdown
---------------------------------------------------------------------
local countdownGui = makeGui("Countdown", 180)
local cd = {}
do
	cd.frame = Instance.new("Frame")
	cd.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	cd.frame.Position = UDim2.fromScale(0.5, 0.3)
	cd.frame.Size = UDim2.new(0.9, 0, 0, 230)
	cd.frame.BackgroundTransparency = 1
	cd.frame.Visible = false
	cd.frame.Parent = countdownGui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 230)
	limit.Parent = cd.frame

	cd.title = Instance.new("TextLabel")
	cd.title.BackgroundTransparency = 1
	cd.title.Size = UDim2.new(1, 0, 0, 40)
	cd.title.Font = Enum.Font.GothamBold
	cd.title.TextSize = 28
	cd.title.TextColor3 = Color3.new(1, 1, 1)
	cd.title.Parent = cd.frame
	local ts = Instance.new("UIStroke")
	ts.Thickness = 2
	ts.Transparency = 0.3
	ts.Parent = cd.title

	cd.number = Instance.new("TextLabel")
	cd.number.BackgroundTransparency = 1
	cd.number.Position = UDim2.new(0, 0, 0, 44)
	cd.number.Size = UDim2.new(1, 0, 0, 170)
	cd.number.Font = Enum.Font.GothamBlack
	cd.number.TextScaled = true
	cd.number.TextColor3 = Color3.new(1, 1, 1)
	cd.number.Parent = cd.frame
	local ns = Instance.new("UIStroke")
	ns.Thickness = 4
	ns.Transparency = 0.2
	ns.Parent = cd.number
	local nl = Instance.new("UITextSizeConstraint")
	nl.MaxTextSize = 150
	nl.Parent = cd.number
	cd.scale = Instance.new("UIScale")
	cd.scale.Parent = cd.number
end

local cdToken = 0

local function stopCountdown()
	cdToken += 1
	cd.frame.Visible = false
end

local function startCountdown(data)
	if type(data) ~= "table" or type(data.endsAt) ~= "number" then
		return
	end
	cdToken += 1
	local token = cdToken
	local endsAt = data.endsAt
	cd.title.Text = tostring(data.title or "Starting in")
	cd.number.Text = ""
	cd.frame.Visible = true
	task.spawn(function()
		local lastShown
		while token == cdToken do
			local remaining = endsAt - Workspace:GetServerTimeNow()
			if remaining <= 0 then
				break
			end
			local n = math.ceil(remaining)
			if n ~= lastShown then
				lastShown = n
				cd.number.Text = tostring(n)
				cd.number.TextColor3 = n <= 3 and Color3.fromRGB(255, 80, 80) or Color3.new(1, 1, 1)
				cd.scale.Scale = 1.35
				TweenService:Create(
					cd.scale,
					TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Scale = 1 }
				):Play()
				if n <= 10 and type(data.tick) == "string" and data.tick ~= "" then
					playSound(data.tick, 0.6)
				end
			end
			task.wait(0.05)
		end
		if token ~= cdToken then
			return
		end
		cd.title.Text = ""
		cd.number.Text = tostring(data.final or "GO!")
		cd.number.TextColor3 = Color3.fromRGB(80, 255, 140)
		cd.scale.Scale = 0.6
		TweenService:Create(
			cd.scale,
			TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
		if type(data.go) == "string" and data.go ~= "" then
			playSound(data.go, 0.9)
		end
		task.wait(2.2)
		if token == cdToken then
			cd.frame.Visible = false
		end
	end)
end

---------------------------------------------------------------------
-- Polls (everyone can vote)
---------------------------------------------------------------------
local pollGui = makeGui("Poll", 170)

local pollUI = {}
local pollState =
	{ id = nil, rows = {}, myVote = nil, dismissed = nil, token = 0, finished = false }

do
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(1, 0.5)
	f.Position = UDim2.new(1, -12, 0.45, 0)
	f.Size = UDim2.new(0.85, 0, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.BackgroundColor3 = Color3.fromRGB(20, 24, 38)
	f.BackgroundTransparency = 0.05
	f.BorderSizePixel = 0
	f.Visible = false
	f.Parent = pollGui
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0, 14)
	fc.Parent = f
	local fs = Instance.new("UIStroke")
	fs.Color = Color3.fromRGB(88, 125, 255)
	fs.Thickness = 2
	fs.Parent = f
	local fz = Instance.new("UISizeConstraint")
	fz.MaxSize = Vector2.new(320, math.huge)
	fz.MinSize = Vector2.new(220, 0)
	fz.Parent = f
	local fp = Instance.new("UIPadding")
	fp.PaddingTop, fp.PaddingBottom = UDim.new(0, 12), UDim.new(0, 12)
	fp.PaddingLeft, fp.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	fp.Parent = f
	local fl = Instance.new("UIListLayout")
	fl.Padding = UDim.new(0, 8)
	fl.SortOrder = Enum.SortOrder.LayoutOrder
	fl.Parent = f

	local head = Instance.new("Frame")
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, 24)
	head.LayoutOrder = 1
	head.Parent = f
	pollUI.timer = Instance.new("TextLabel")
	pollUI.timer.BackgroundTransparency = 1
	pollUI.timer.Size = UDim2.new(1, -34, 1, 0)
	pollUI.timer.Font = Enum.Font.GothamBold
	pollUI.timer.TextSize = 13
	pollUI.timer.TextColor3 = Color3.fromRGB(120, 150, 255)
	pollUI.timer.TextXAlignment = Enum.TextXAlignment.Left
	pollUI.timer.Text = "📊 POLL"
	pollUI.timer.Parent = head
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, 0, 0.5, 0)
	close.Size = UDim2.fromOffset(28, 28)
	close.BackgroundColor3 = Color3.fromRGB(44, 48, 66)
	close.Text = "✕"
	close.Font = Enum.Font.GothamBold
	close.TextSize = 14
	close.TextColor3 = Color3.new(1, 1, 1)
	close.Parent = head
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(1, 0)
	cc.Parent = close
	close.MouseButton1Click:Connect(function()
		pollState.dismissed = pollState.id
		f.Visible = false
	end)

	pollUI.question = Instance.new("TextLabel")
	pollUI.question.BackgroundTransparency = 1
	pollUI.question.Size = UDim2.new(1, 0, 0, 0)
	pollUI.question.AutomaticSize = Enum.AutomaticSize.Y
	pollUI.question.Font = Enum.Font.GothamBold
	pollUI.question.TextSize = 17
	pollUI.question.TextWrapped = true
	pollUI.question.TextColor3 = Color3.fromRGB(240, 242, 248)
	pollUI.question.TextXAlignment = Enum.TextXAlignment.Left
	pollUI.question.LayoutOrder = 2
	pollUI.question.Parent = f

	pollUI.options = Instance.new("Frame")
	pollUI.options.BackgroundTransparency = 1
	pollUI.options.Size = UDim2.new(1, 0, 0, 0)
	pollUI.options.AutomaticSize = Enum.AutomaticSize.Y
	pollUI.options.LayoutOrder = 3
	pollUI.options.Parent = f
	local ol = Instance.new("UIListLayout")
	ol.Padding = UDim.new(0, 6)
	ol.SortOrder = Enum.SortOrder.LayoutOrder
	ol.Parent = pollUI.options

	pollUI.footer = Instance.new("TextLabel")
	pollUI.footer.BackgroundTransparency = 1
	pollUI.footer.Size = UDim2.new(1, 0, 0, 16)
	pollUI.footer.Font = Enum.Font.Gotham
	pollUI.footer.TextSize = 12
	pollUI.footer.TextColor3 = Color3.fromRGB(150, 160, 190)
	pollUI.footer.TextXAlignment = Enum.TextXAlignment.Left
	pollUI.footer.LayoutOrder = 4
	pollUI.footer.Parent = f
	pollUI.frame = f
end

local function paintPoll(counts, winner)
	local total = 0
	for _, c in counts do
		total += c
	end
	for i, r in pollState.rows do
		local c = counts[i] or 0
		local frac = total > 0 and c / total or 0
		TweenService:Create(r.fill, TweenInfo.new(0.3), { Size = UDim2.new(frac, 0, 1, 0) }):Play()
		r.count.Text = c .. "  •  " .. math.floor(frac * 100 + 0.5) .. "%"
		local mine = pollState.myVote == i
		r.stroke.Color = (winner == i) and Color3.fromRGB(24, 224, 130)
			or (mine and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(70, 80, 120))
		r.stroke.Thickness = (mine or winner == i) and 2 or 1
		r.fill.BackgroundColor3 = (winner == i) and Color3.fromRGB(24, 200, 120)
			or Color3.fromRGB(60, 100, 230)
	end
end

local function startPoll(data)
	if type(data) ~= "table" or type(data.options) ~= "table" then
		return
	end
	pollState.token += 1
	local token = pollState.token
	pollState.id = data.id
	pollState.myVote = nil
	pollState.dismissed = nil
	pollState.finished = false
	pollState.rows = {}
	for _, c in pollUI.options:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	pollUI.question.Text = tostring(data.question or "")
	pollUI.footer.Text = "Tap an option to vote"
	for i, name in data.options do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, 0, 0, 44)
		b.BackgroundColor3 = Color3.fromRGB(34, 40, 62)
		b.AutoButtonColor = false
		b.Text = ""
		b.LayoutOrder = i
		b.ClipsDescendants = true
		b.Parent = pollUI.options
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 10)
		bc.Parent = b
		local bs = Instance.new("UIStroke")
		bs.Color = Color3.fromRGB(70, 80, 120)
		bs.Parent = b
		local fill = Instance.new("Frame")
		fill.Size = UDim2.new(0, 0, 1, 0)
		fill.BackgroundColor3 = Color3.fromRGB(60, 100, 230)
		fill.BackgroundTransparency = 0.45
		fill.BorderSizePixel = 0
		fill.Parent = b
		local nm = Instance.new("TextLabel")
		nm.BackgroundTransparency = 1
		nm.Size = UDim2.new(1, -90, 1, 0)
		nm.Position = UDim2.new(0, 10, 0, 0)
		nm.Font = Enum.Font.GothamMedium
		nm.TextSize = 15
		nm.TextColor3 = Color3.new(1, 1, 1)
		nm.TextXAlignment = Enum.TextXAlignment.Left
		nm.TextTruncate = Enum.TextTruncate.AtEnd
		nm.Text = tostring(name)
		nm.Parent = b
		local ct = Instance.new("TextLabel")
		ct.BackgroundTransparency = 1
		ct.Size = UDim2.new(0, 84, 1, 0)
		ct.Position = UDim2.new(1, -90, 0, 0)
		ct.Font = Enum.Font.Gotham
		ct.TextSize = 12
		ct.TextColor3 = Color3.fromRGB(200, 210, 235)
		ct.TextXAlignment = Enum.TextXAlignment.Right
		ct.Parent = b
		pollState.rows[i] = { fill = fill, count = ct, stroke = bs }
		b.MouseButton1Click:Connect(function()
			if pollState.finished or pollState.id ~= data.id then
				return
			end
			pollState.myVote = i
			if liveEvents then
				liveEvents:FireServer("Vote", data.id, i)
			end
			paintPoll(data.counts or {}, nil)
			pollUI.footer.Text = "Voted: " .. tostring(name) .. " (tap another to change)"
		end)
	end
	data.counts = data.counts or {}
	paintPoll(data.counts, nil)
	pollUI.frame.Visible = true
	task.spawn(function()
		while token == pollState.token and not pollState.finished do
			local left = math.max(0, math.ceil((data.endsAt or 0) - Workspace:GetServerTimeNow()))
			pollUI.timer.Text = "📊 POLL  •  " .. left .. "s left"
			task.wait(0.5)
		end
	end)
end

local function endPoll(data)
	if type(data) ~= "table" or data.id ~= pollState.id then
		return
	end
	pollState.finished = true
	local token = pollState.token
	paintPoll(data.counts or {}, data.winner)
	pollUI.timer.Text = "📊 POLL RESULTS"
	if data.winner and data.options then
		pollUI.footer.Text = "Winner: " .. tostring(data.options[data.winner])
	elseif data.tie then
		pollUI.footer.Text = "It's a tie!"
	else
		pollUI.footer.Text = "Nobody voted."
	end
	if pollState.dismissed ~= data.id then
		pollUI.frame.Visible = true
		task.delay(9, function()
			if token == pollState.token then
				pollUI.frame.Visible = false
			end
		end)
	end
end

local function handlePoll(kind, data)
	if kind == "start" then
		startPoll(data)
	elseif kind == "update" then
		if type(data) == "table" and data.id == pollState.id and not pollState.finished then
			paintPoll(data.counts or {}, nil)
		end
	elseif kind == "end" then
		endPoll(data)
	end
end

function LiveEventsController.start()
	task.spawn(function()
		liveEvents = Remotes.liveEvents()
		liveEvents.OnClientEvent:Connect(function(kind, a, b, c)
			if kind == "Announce" then
				onAnnounce(a, b, c)
			elseif kind == "Countdown" then
				if a == "start" then
					startCountdown(b)
				else
					stopCountdown()
				end
			elseif kind == "Poll" and type(a) == "string" then
				handlePoll(a, b)
			end
		end)
	end)
end

return LiveEventsController
