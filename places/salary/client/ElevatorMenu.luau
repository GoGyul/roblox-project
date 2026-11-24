-- 🚪 엘리베이터 층 고르기 창
--   엘리베이터 [E] → 서버가 갈 수 있는 층 목록을 보내 줘요 → 버튼(또는 숫자 키)으로 고르면 서버에 알려요.
--   엘리베이터에서 멀어지거나 8초가 지나면 저절로 닫혀요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ui = require(Shared:WaitForChild("Ui"))
local Theme = require(Shared:WaitForChild("SalaryTheme"))

local ElevatorMenu = {}

local player = Players.LocalPlayer
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }
local CLOSE_DISTANCE = 14
local CLOSE_SECONDS = 8

function ElevatorMenu.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local go = remotes:WaitForChild("ElevatorGo") :: RemoteEvent

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

	remotes:WaitForChild("ElevatorMenu").OnClientEvent:Connect(function(from: string, list)
		options = list
		title.Text = "🚪 몇 층으로 갈까요?"
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
		local _ = from
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

return ElevatorMenu
