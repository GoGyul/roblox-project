-- 클라이언트 시작점: 화면 UI를 켭니다.
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

-- 광장에서 텔레포트해 왔다면, 로딩 화면을 잠깐 더 보여 주다가 사라지게 해요
local arrivingGui = TeleportService:GetArrivingTeleportGui()
if arrivingGui then
	arrivingGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	task.delay(2, function()
		arrivingGui:Destroy()
	end)
end

require(script.Hud)
require(script.Panels)
