-- 💼 월급루팡 시뮬레이터 클라이언트 시작점
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")

-- 혼자 하는 게임이라 오른쪽 위 플레이어 목록은 숨겨요 (직급 패널을 가려서)
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
end)

-- 광장에서 텔레포트해 왔다면, 로딩 화면을 잠깐 보여 주다가 사라지게 해요
local arrivingGui = TeleportService:GetArrivingTeleportGui()
if arrivingGui then
	arrivingGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	task.delay(2, function()
		arrivingGui:Destroy()
	end)
end

require(script.Hud)
require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BossKey")).start()
require(script.Poses).start()
require(script.StockPanel).start()
local Panels = require(script.Panels)
Panels.showWelcome()
