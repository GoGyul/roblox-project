-- 👔 부장님께 드릴 것 고르기 창
--   부장님 [E] → 드릴 수 있는 것이 여러 개면 서버가 목록을 보내 줘요 → 버튼(또는 숫자 키)으로 고르면 서버에 알려요.
--   부장님에게서 멀어지거나 8초가 지나면 저절로 닫혀요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ui = require(Shared:WaitForChild("Ui"))
local Theme = require(Shared:WaitForChild("SalaryTheme"))

local GiveMenu = {}

local player = Players.LocalPlayer
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five }
local CLOSE_DISTANCE = 14
local CLOSE_SECONDS = 8

function GiveMenu.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local go = remotes:WaitForChild("GiveChoose") :: RemoteEvent -- (지금 열린 창이 대답을 보낼 곳: 부장님 / 동료)
	local bossGo = go
	local coworkerGo = remotes:WaitForChild("CoworkerChoose") :: RemoteEvent

	local frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromOffset(300, 200),
		BackgroundColor3 = Theme.Color.surface,
		BackgroundTransparency = 0.02,
		Visible = false,
		ZIndex = 60,
		Parent = Ui.gui,
	}, { Ui.corner(20), Ui.stroke(Theme.Color.navy, 3), Ui.padding(14) })
	local title = Ui.make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextColor3 = Theme.Color.navy,
		Text = "",
		ZIndex = 61,
		Parent = frame,
	})
	local buttons: { TextButton } = {}
	local options: { { id: string, name: string } } = {}
	local token = 0

	local function close()
		token += 1
		frame.Visible = false
	end
	local function pick(index: number)
		local option = options[index]
		if frame.Visible and option then
			go:FireServer(option.id)
			close()
		end
	end
	-- 오른쪽 위 X 닫기 (아무것도 안 고르고 창만 닫아요)
	local closeButton = Ui.make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 8, 0, -8),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = Theme.Color.coralSoft,
		Text = "X",
		TextColor3 = Theme.Color.navy,
		Font = Enum.Font.GothamBlack,
		TextSize = 16,
		ZIndex = 63,
		Parent = frame,
	}, { Ui.corner(15) })
	closeButton.Activated:Connect(function()
		if frame.Visible then
			go:FireServer("close") -- (서버에 알려서, 멈춰 서 있던 NPC가 다시 움직이게 해요)
			close()
		end
	end)
	for i = 1, #KEYS do
		local button = Ui.button({
			Position = UDim2.fromOffset(0, 32 + (i - 1) * 46),
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = Theme.Color.skySoft,
			TextColor3 = Theme.Color.navy,
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			Text = "",
			ZIndex = 61,
			Parent = frame,
		})
		button.Activated:Connect(function()
			pick(i)
		end)
		buttons[i] = button
	end

	local function open(heading: string, list, answer: RemoteEvent)
		go = answer
		options = list
		title.Text = heading
		for i, button in buttons do
			local option = options[i]
			button.Visible = option ~= nil
			if option then
				button.Text = `[{i}]  {option.name}`
			end
		end
		frame.Size = UDim2.fromOffset(300, 32 + #options * 46 + 26)
		frame.Visible = true
		token += 1
		local mine = token
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local origin = root and root.Position
		task.spawn(function()
			local opened = os.clock()
			while token == mine and os.clock() - opened < CLOSE_SECONDS do
				task.wait(0.2)
				local now = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if origin and now and (now.Position - origin).Magnitude > CLOSE_DISTANCE then
					break
				end
			end
			if token == mine then
				close()
			end
		end)
	end
	remotes:WaitForChild("GiveMenu").OnClientEvent:Connect(function(_from: string, list)
		open("👔 부장님께 무엇을 드릴까요?", list, bossGo)
	end)
	-- 💬 동료 [E] 말 걸기: 수다 · 간식 주기 · 신고 · 도와주기 · 감사팀 지목 중에서 골라요
	remotes:WaitForChild("CoworkerMenu").OnClientEvent:Connect(function(heading: string, list)
		open(`💬 {heading}`, list, coworkerGo)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not frame.Visible then
			return
		end
		for i, key in KEYS do
			if input.KeyCode == key then
				pick(i)
			end
		end
	end)
end

return GiveMenu
