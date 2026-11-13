-- 💼 월급루팡 시뮬레이터 서버 시작점
-- 사무실을 짓고 → 김부장을 만들고 → 직원 관리와 하루 흐름을 켭니다.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(script.Remotes) -- 가장 먼저 (클라이언트가 찾을 수 있게)
local OfficeBuilder = require(script.OfficeBuilder)
local Boss = require(script.Boss)
local DayCycle = require(script.DayCycle)
local Employees = require(script.Employees)
local Places = require(ReplicatedStorage.Shared.Places)
local Teleport = require(ReplicatedStorage.Shared.Teleport)

-- 밝은 사무실 조명
Lighting.ClockTime = 13
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(150, 150, 155)
Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 155)

local office = OfficeBuilder.build()
local boss = Boss.new(office)
local dayCycle = DayCycle.new()

Employees.start(office, boss, dayCycle, Remotes)
boss:run()
dayCycle:run()

-- 벽시계는 게임 속 시간을 보여 줘요
task.spawn(function()
	while true do
		local minute = dayCycle.minute
		office.setClock(math.floor(minute / 60), math.floor(minute % 60))
		task.wait(0.5)
	end
end)

-- 광장으로 돌아가기
Remotes.ReturnToLobby.OnServerEvent:Connect(function(player)
	local ok, message = Teleport.send(Places.LOBBY, { player }, false)
	if not ok and message then
		Remotes.Notify:FireClient(player, message)
	end
end)

print("💼 월급루팡 시뮬레이터 준비 완료!")
