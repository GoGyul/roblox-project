-- 서버 시작점: 시계탑을 짓고, 시간 전환과 퍼즐을 켭니다.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(script.Remotes) -- 가장 먼저 만들어 둬야 클라이언트가 찾을 수 있어요
local Inventory = require(script.Inventory)
local TowerBuilder = require(script.TowerBuilder)
local TimeTravel = require(script.TimeTravel)
local Puzzles = require(script.Puzzles)
local Places = require(ReplicatedStorage.Shared.Places)
local Teleport = require(ReplicatedStorage.Shared.Teleport)

-- 광장으로 돌아가기 (탈출 성공 화면의 버튼)
Remotes.ReturnToLobby.OnServerEvent:Connect(function(player)
	local ok, message = Teleport.send(Places.LOBBY, { player }, false)
	if not ok and message then
		Remotes.Notify:FireClient(player, message)
	end
end)

-- 실내 분위기
Lighting.Ambient = Color3.fromRGB(60, 55, 50)
Lighting.OutdoorAmbient = Color3.fromRGB(60, 55, 50)
Lighting.ClockTime = 19

local tower = TowerBuilder.build()
TimeTravel.start(tower.folder)
Puzzles.start(tower)

local function onPlayerAdded(player: Player)
	Inventory.setup(player)
	player:SetAttribute("Era", "present")
	player:SetAttribute("StartTime", workspace:GetServerTimeNow())

	-- 다시 태어나면 현재 1층에서 시작
	player.CharacterAdded:Connect(function()
		player:SetAttribute("Era", "present")
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

print("🕰️ 멈춘 시계탑 준비 완료!")
