-- 💬 상호작용 [E] 안내창을 작게 (로블록스 기본 창은 너무 커서 직접 그려요)
--   모든 ProximityPrompt를 Custom 스타일로 바꾸고, 대상 위에 작은 알약 모양 안내를 띄워요.
--   [E] 키는 그대로 동작하고, 폰에서는 안내를 누르면(꾹 누르기 포함) 돼요.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Ui = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ui"))
local SalaryConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SalaryConfig"))
local Theme = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SalaryTheme"))

local Prompts = {}

local player = Players.LocalPlayer

-- 🤝 "수다 떨기 · 이대리" 옆에 친밀도 점수 (서버가 Friendship 속성으로 알려 줘요)
local function friendText(name: string): string
	local points = 0
	pcall(function()
		points = HttpService:JSONDecode(player:GetAttribute("Friendship") or "{}")[name] or 0
	end)
	return ` ({SalaryConfig.friendText(points)})`
end

local function makeCustom(instance: Instance)
	if instance:IsA("ProximityPrompt") then
		instance.Style = Enum.ProximityPromptStyle.Custom
		-- 🔒 OnlyFor 속성이 있으면 그 사람 화면에만 [E]가 떠요 (📦 택배 상자처럼 내 것만)
		local onlyFor = instance:GetAttribute("OnlyFor")
		if onlyFor ~= nil and onlyFor ~= player.UserId then
			instance.Enabled = false
		end
	end
end

function Prompts.start()
	for _, instance in workspace:GetDescendants() do
		makeCustom(instance)
	end
	workspace.DescendantAdded:Connect(makeCustom)

	-- 🤐 수다 중에는 다른 상호작용([E] 수다 떨기, [R] 감사팀이죠? 등)을 띄우지도, 누를 수도 없게 해요
	local function refreshBusy()
		ProximityPromptService.Enabled = player:GetAttribute("SalaryState") ~= "chat"
	end
	player:GetAttributeChangedSignal("SalaryState"):Connect(refreshBusy)
	refreshBusy()

	local playerGui = player:WaitForChild("PlayerGui")
	local shown: { [ProximityPrompt]: BillboardGui } = {}

	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt, inputType)
		if shown[prompt] then
			return
		end
		local adornee = prompt.Parent
		if not adornee or not (adornee:IsA("BasePart") or adornee:IsA("Attachment") or adornee:IsA("Model")) then
			return
		end
		local touch = inputType == Enum.ProximityPromptInputType.Touch
		local key = if touch then "👆" else (if inputType == Enum.ProximityPromptInputType.Gamepad then (string.gsub(prompt.GamepadKeyCode.Name, "^Button", "")) else prompt.KeyboardKeyCode.Name)

		local board = Instance.new("BillboardGui")
		board.Name = "SmallPrompt"
		board.Adornee = adornee
		board.AlwaysOnTop = true
		board.Active = true -- 폰에서 눌러지도록
		local isChat = prompt.ActionText == "말 걸기"
		board.Size = UDim2.fromOffset(if isChat then 210 else 170, 30)
		-- 같은 대상에 [E]·[R] 두 개가 뜨면 겹치지 않게 [E]가 아닌 건 위로
		board.StudsOffsetWorldSpace = Vector3.new(0, if prompt.KeyboardKeyCode == Enum.KeyCode.E then 2.2 elseif prompt.KeyboardKeyCode == Enum.KeyCode.F then 3.6 else 5, 0)
		board.Parent = playerGui

		local pill = Ui.make("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Color.surface,
			BackgroundTransparency = 0.04,
			AutoButtonColor = false,
			Text = "",
			Parent = board,
		}, { Ui.corner(15), Ui.stroke(Theme.Color.navy, 2) })
		local keyBox = Ui.make("TextLabel", {
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = Theme.Color.yellow,
			TextColor3 = Theme.Color.navy,
			Font = Enum.Font.GothamBlack,
			TextScaled = true,
			Text = key,
			Parent = pill,
		}, { Ui.corner(12) })
		local fill = Ui.make("Frame", { -- 꾹 누르기 진행
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Theme.Color.mint,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			Parent = pill,
		}, { Ui.corner(15) })
		local function promptText(): string
			return (if prompt.ObjectText ~= "" then `{prompt.ActionText} · {prompt.ObjectText}` else prompt.ActionText)
				.. (if prompt.ActionText == "말 걸기" then friendText(prompt.ObjectText) else "")
		end
		local textLabel = Ui.make("TextLabel", {
			Position = UDim2.fromOffset(32, 0),
			Size = UDim2.new(1, -38, 1, 0),
			BackgroundTransparency = 1,
			TextColor3 = Theme.Color.navy,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = promptText(),
			Parent = pill,
		})
		local _ = keyBox
		shown[prompt] = board

		-- 꾹 누르는 동안 노란색으로 차올라요
		local holding = false
		local holdStart = 0
		local connections = {}
		-- (동료의 [F]처럼 상황에 따라 글자가 바뀌는 안내는 떠 있는 동안에도 따라 바꿔요)
		table.insert(connections, prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
			textLabel.Text = promptText()
		end))
		table.insert(connections, prompt.PromptButtonHoldBegan:Connect(function()
			holding, holdStart = true, os.clock()
		end))
		table.insert(connections, prompt.PromptButtonHoldEnded:Connect(function()
			holding = false
			fill.Size = UDim2.fromScale(0, 1)
		end))
		table.insert(connections, RunService.RenderStepped:Connect(function()
			if holding and prompt.HoldDuration > 0 then
				fill.Size = UDim2.fromScale(math.clamp((os.clock() - holdStart) / prompt.HoldDuration, 0, 1), 1)
			end
		end))
		-- 폰·마우스: 안내를 누르면 [E]를 누른 것과 같아요
		table.insert(connections, pill.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldBegin()
			end
		end))
		table.insert(connections, pill.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldEnd()
			end
		end))
		board:SetAttribute("Bound", true)
		prompt.PromptHidden:Once(function()
			for _, connection in connections do
				connection:Disconnect()
			end
			board:Destroy()
			shown[prompt] = nil
		end)
	end)
end

return Prompts
