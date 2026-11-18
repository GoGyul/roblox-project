-- 💼 월급루팡 시뮬레이터 서버 시작점
-- 사무실을 짓고 → 김부장을 만들고 → 직원 관리와 하루 흐름을 켭니다.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 🛡️ 이 코드가 맞는 장소에서 실행되는지 확인 (다른 장소에 잘못 게시하는 실수 방지)
require(ReplicatedStorage.Shared.PlaceGuard).check("salary")

local Remotes = require(script.Remotes) -- 가장 먼저 (클라이언트가 찾을 수 있게)
local OfficeBuilder = require(script.OfficeBuilder)
local Boss = require(script.Boss)
local DayCycle = require(script.DayCycle)
local Employees = require(script.Employees)
local Coworkers = require(script.Coworkers)
local Places = require(ReplicatedStorage.Shared.Places)
local Teleport = require(ReplicatedStorage.Shared.Teleport)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)

-- 사무실 조명 (너무 밝으면 캐릭터가 하얗게 빛나 보여요)
Lighting.ClockTime = 13
Lighting.Brightness = 1.5
Lighting.Ambient = Color3.fromRGB(115, 115, 120)
Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 125)
Lighting.ExposureCompensation = -0.25
-- 템플릿에 들어 있는 빛 번짐(Bloom) 효과를 약하게
for _, effect in Lighting:GetDescendants() do
	if effect:IsA("BloomEffect") then
		effect.Intensity = 0.15
		effect.Threshold = 2.5
	end
end

local office = OfficeBuilder.build()
local boss = Boss.new(office)
local dayCycle = DayCycle.new()

-- 동료가 "수다 떨기"를 받으면 Employees가 처리해요
local coworkers = Coworkers.start(office, boss, dayCycle, Remotes, function(player, coworker)
	Employees.startChat(player, coworker)
end)
Employees.start(office, boss, dayCycle, Remotes, coworkers)
boss:run()
-- 하루 흐름은 첫 플레이어의 저장된 날짜를 불러온 뒤 시작해요 (Employees가 시작시켜요)

-- 벽시계는 게임 속 시간을 보여 줘요
task.spawn(function()
	while true do
		local minute = dayCycle.minute
		office.setClock(math.floor(minute / 60), math.floor(minute % 60))
		task.wait(0.5)
	end
end)

-- 광장으로 돌아가기
local allowReturn = RateLimit.new(5) -- 순간이동 요청 연타 방지
Remotes.ReturnToLobby.OnServerEvent:Connect(function(player)
	if not allowReturn(player) then
		return
	end
	local ok, message = Teleport.send(Places.LOBBY, { player }, false)
	if not ok and message then
		Remotes.Notify:FireClient(player, message)
	end
end)

print("💼 월급루팡 시뮬레이터 준비 완료!")
