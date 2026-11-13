-- 메인 광장 클라이언트: 안내 문구와 이동 중 로딩 화면

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Ui = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ui"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local C = Ui.COLORS

-- 로딩 화면 만들기
local function makeLoadingScreen(text: string): ScreenGui
	return Ui.make("ScreenGui", {
		Name = "TeleportLoading",
		IgnoreGuiInset = true,
		DisplayOrder = 100,
		ResetOnSpawn = false,
	}, {
		Ui.make("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = C.panel,
		}, {
			Ui.make("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(600, 120),
				BackgroundTransparency = 1,
				Name = "Message",
				Text = text,
				TextColor3 = C.brass,
				Font = Enum.Font.GothamBlack,
				TextSize = 36,
			}),
		}),
	})
end

-- 텔레포트하는 동안(다음 장소가 열릴 때까지) 보여 줄 화면을 로블록스에 등록
TeleportService:SetTeleportGui(makeLoadingScreen("🎮 이동 중…"))

-- 서버가 출발 신호를 보내면 바로 로딩 화면 켜기
local loading = makeLoadingScreen("")
loading.Enabled = false
loading.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

Remotes:WaitForChild("Teleporting").OnClientEvent:Connect(function(gameName: string)
	loading.Frame.Message.Text = `{gameName}(으)로 이동 중…`
	loading.Enabled = true
end)
Remotes:WaitForChild("TeleportFailed").OnClientEvent:Connect(function()
	loading.Enabled = false
end)
Remotes:WaitForChild("Notify").OnClientEvent:Connect(Ui.toast)
