--!strict
-- Question balls on the SkyTerrace tables: click the ball (tag TableQuestions.Tag) and a random
-- conversation starter pops up above the table for everyone nearby. Runs on the server so
-- the whole table sees the same question.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local TableQuestions = require(ReplicatedStorage.Shared.TableQuestions)

local CREAM = Color3.fromRGB(255, 250, 244)
local INK = Color3.fromRGB(45, 32, 26)
local ACCENT = Color3.fromRGB(150, 105, 70)
local FONT = Font.fromEnum(Enum.Font.BuilderSansBold)
local CARD_SIZE = UDim2.fromScale(1, 1)

local QuestionBallService = {}

local rng = Random.new()
local recent: { number } = {}

-- Random question, avoiding the last few shown anywhere so tables don't repeat.
local function pickQuestion(): string
	local list = TableQuestions.List
	local memory = math.min(10, #list - 1)
	local index
	repeat
		index = rng:NextInteger(1, #list)
	until not table.find(recent, index)
	table.insert(recent, index)
	if #recent > memory then
		table.remove(recent, 1)
	end
	return list[index]
end

local function buildCard(ball: BasePart): (BillboardGui, Frame, TextLabel, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "QuestionCard"
	gui.Size = UDim2.fromScale(7, 2.6) -- studs
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.MaxDistance = 45
	gui.LightInfluence = 0
	gui.Enabled = false
	gui.Adornee = ball
	gui.Parent = ball

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = CARD_SIZE
	card.BackgroundColor3 = CREAM
	card.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.18, 0)
	corner.Parent = card
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 2
	stroke.Transparency = 0.6
	stroke.Parent = card

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Position = UDim2.fromScale(0.06, 0.08)
	header.Size = UDim2.fromScale(0.88, 0.22)
	header.BackgroundTransparency = 1
	header.FontFace = FONT
	header.TextScaled = true
	header.TextColor3 = ACCENT
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = "Tanong"
	header.Parent = card

	local question = Instance.new("TextLabel")
	question.Name = "Question"
	question.Position = UDim2.fromScale(0.06, 0.32)
	question.Size = UDim2.fromScale(0.88, 0.6)
	question.BackgroundTransparency = 1
	question.FontFace = FONT
	question.TextScaled = true
	question.TextWrapped = true
	question.TextColor3 = INK
	question.TextXAlignment = Enum.TextXAlignment.Left
	question.TextYAlignment = Enum.TextYAlignment.Top
	question.Parent = card
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 28
	limit.Parent = question

	return gui, card, header, question
end

local function setupBall(instance: Instance)
	if not instance:IsA("BasePart") or instance:FindFirstChild("QuestionCard") then
		return
	end
	local ball: BasePart = instance
	local gui, card, header, question = buildCard(ball)

	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 16
	click.Parent = ball

	local lastClick = 0
	local showId = 0
	click.MouseClick:Connect(function(player: Player)
		local now = os.clock()
		if now - lastClick < TableQuestions.Cooldown then
			return
		end
		lastClick = now

		question.Text = pickQuestion()
		header.Text = `Tanong ni {player.DisplayName}`
		gui.Enabled = true
		card.Size = UDim2.fromScale(0.6, 0.6)
		TweenService:Create(
			card,
			TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = CARD_SIZE }
		):Play()

		showId += 1
		local myId = showId
		task.delay(TableQuestions.ShowSeconds, function()
			if showId == myId then
				gui.Enabled = false
			end
		end)
	end)
end

function QuestionBallService.start()
	for _, ball in CollectionService:GetTagged(TableQuestions.Tag) do
		setupBall(ball)
	end
	CollectionService:GetInstanceAddedSignal(TableQuestions.Tag):Connect(setupBall)
end

return QuestionBallService
