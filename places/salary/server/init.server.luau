-- 💼 월급루팡 시뮬레이터 서버 시작점
-- 사무실을 짓고 → 김부장을 만들고 → 직원 관리와 하루 흐름을 켭니다.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- 사무실을 짓기 전에 캐릭터가 생기면 허공에서 떨어지니까, 다 지을 때까지 기다려요
Players.CharacterAutoLoads = false

-- 🛡️ 이 코드가 맞는 장소에서 실행되는지 확인 (다른 장소에 잘못 게시하는 실수 방지)
require(ReplicatedStorage.Shared.PlaceGuard).check("salary")

local Remotes = require(script.Remotes) -- 가장 먼저 (클라이언트가 찾을 수 있게)
local OfficeBuilder = require(script.OfficeBuilder)
local Boss = require(script.Boss)
local DayCycle = require(script.DayCycle)
local Employees = require(script.Employees)
local Coworkers = require(script.Coworkers)
local Events = require(script.Events)
local Lee = require(script.Lee)
local Dinner = require(script.Dinner)
local Street = require(script.Street)
local Claw = require(script.Claw)
local Arcade = require(script.Arcade)
local Wheel = require(script.Wheel)
local Dart = require(script.Dart)
local Missions = require(script.Missions)
local Decor = require(script.Decor)
local Outfit = require(script.Outfit)
local Cat = require(script.Cat)
local Rooftop = require(script.Rooftop)
local SeatPrompts = require(script.SeatPrompts)
local PhoneGames = require(script.PhoneGames)
local Profiles = require(script.Profiles)
local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local Places = require(ReplicatedStorage.Shared.Places)
local Teleport = require(ReplicatedStorage.Shared.Teleport)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)

-- 사무실 조명 (너무 밝으면 캐릭터가 하얗게 빛나 보여요)
Lighting.ClockTime = 13.5
-- 🧊 질감 B안: 그림자가 지는 차분한 실내 조명 (조명 방식 Technology는 Studio의 Lighting 속성에서 Future로 바꿔요)
Lighting.Brightness = 1.3 -- (너무 밝아서 낮췄어요)
Lighting.Ambient = Color3.fromRGB(58, 60, 66)
Lighting.OutdoorAmbient = Color3.fromRGB(92, 98, 106)
Lighting.ExposureCompensation = -0.75
Lighting.EnvironmentDiffuseScale = 0.4
Lighting.EnvironmentSpecularScale = 0.3
Lighting.GlobalShadows = true
do
	local grade = Lighting:FindFirstChild("SalaryGrade") or Instance.new("ColorCorrectionEffect")
	grade.Name = "SalaryGrade"
	grade.Saturation = -0.12
	grade.Contrast = 0.06
	grade.TintColor = Color3.fromRGB(255, 250, 244)
	grade.Parent = Lighting
end

local colorGrade = Lighting:FindFirstChild("SalaryColorGrade") :: ColorCorrectionEffect?
if not colorGrade then
	colorGrade = Instance.new("ColorCorrectionEffect")
	colorGrade.Name = "SalaryColorGrade"
	colorGrade.Parent = Lighting
end
colorGrade.Brightness = 0.015
colorGrade.Contrast = 0.14
colorGrade.Saturation = 0.12
colorGrade.TintColor = Color3.fromRGB(255, 250, 242)

local atmosphere = Lighting:FindFirstChild("SalaryAtmosphere") :: Atmosphere?
if not atmosphere then
	atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "SalaryAtmosphere"
	atmosphere.Parent = Lighting
end
atmosphere.Color = Color3.fromRGB(205, 232, 244)
atmosphere.Decay = Color3.fromRGB(126, 164, 180)
atmosphere.Density = 0.16
atmosphere.Haze = 0.7
atmosphere.Glare = 0.05
-- 템플릿에 들어 있는 빛 번짐(Bloom) 효과를 약하게
for _, effect in Lighting:GetDescendants() do
	if effect:IsA("BloomEffect") then
		effect.Intensity = 0.15
		effect.Threshold = 2.5
	end
end

-- 🏢 어느 회사 사무실을 지을까? → 처음 들어온 사람의 직급으로 정해요
local firstPlayer = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local firstProfile = Profiles.load(firstPlayer)
local company = SalaryConfig.companyForRank(firstProfile.rank)
if RunService:IsStudio() and SalaryConfig.TEST_COMPANY ~= "" then
	company = SalaryConfig.getCompany(SalaryConfig.TEST_COMPANY)
end
ReplicatedStorage:SetAttribute("SalaryCompany", company.id)
print(`🏢 오늘의 사무실: {company.name}`)

local office = OfficeBuilder.build(company.id)
require(script.OfficeSkin).apply(office) -- 🧊 벽·바닥·천장에 메시 키트를 입혀요
local boss = Boss.new(office)
local dayCycle = DayCycle.new()

-- 동료가 "수다 떨기"를 받으면 Employees가 처리해요
local coworkers = Coworkers.start(office, boss, dayCycle, Remotes, function(player, coworker)
	-- 📋 긴급 프로젝트 결재 도장이 필요하면 수다 대신 도장
	if Employees.hooks and Employees.hooks.coworker and Employees.hooks.coworker(player, coworker) then
		return
	end
	Employees.startChat(player, coworker)
end)
local events = Events.new(office, boss, dayCycle, Remotes, coworkers) -- 🎲 돌발 이벤트
local lee = Lee.new(office, dayCycle) -- 👀 눈치 빠른 이과장 (수·목 출근)
Employees.start(office, boss, dayCycle, Remotes, coworkers, events, lee)
Street.start(office, Remotes, Employees.buyStreet) -- 🏙️ 눈치 스트리트 가게 (눈치물산만)
Claw.start(office, Remotes, { charge = Employees.chargeClaw, give = Employees.givePlush }) -- 🧸 인형뽑기
Decor.start(Remotes, Employees.decorApi) -- 🪑 내 자리 꾸미기 + 🏆 칭호
require(script.Delivery).start(office, dayCycle, Remotes, Employees.deliveryApi) -- 📦 택배 보관함 (쇼핑몰 주문이 다음 날 도착)
if SalaryConfig.OUTFIT_ENABLED then
	Outfit.start(Remotes, Employees.decorApi) -- 👔 출근룩 (Decor 다음에: 들어올 때 훅을 이어 붙여요)
end
local cat = Cat.start(office, boss, dayCycle, Remotes, Employees.catHooks) -- 🐱 사무실 고양이 월급냥
Employees.hooks.catOn = cat.sittingOn
local rooftop = Rooftop.start(office, boss, dayCycle, Remotes, Employees.roofHooks, events) -- 🏢 옥상 + 🚪 엘리베이터
require(script.Arrival).start(office, Remotes) -- 🚏 건물 앞 거리 + 1층 로비 + 계단 (리뉴얼 대충상사)
require(script.ParkGarden).start(office.parkBeds, Remotes, { action = Employees.parkAction }) -- 🌷 내 공원 화단 (눈치물산만)
-- 🪑 부장님·동료가 책상·탁자 위로 올라가지 않게 (사무실 바닥 높이 1, 옥상 300)
require(script.Npc).guardFurniture(office.folder, { 1, 300 })
SeatPrompts.start(Remotes) -- 🪑 의자마다 [E] 앉기
PhoneGames.start(Remotes, { -- 📱 폰 게임 (💣 지뢰 피하기)
	charge = Employees.chargeClaw,
	payout = Employees.payPhoneGame,
	isPlaying = Employees.isPhoneGaming,
	status = Employees.phoneGameStatus,
	rank = Employees.rankOf,
	shapesPrize = Employees.payShapes,
	baseballPrize = Employees.payBaseball,
})
Employees.hooks.onRoof = rooftop.onRoof
local parkGuard = require(script.Guard).start(office, dayCycle, events, Remotes, Employees.useGuardGift) -- 👮 공원·거리 경비원 (눈치물산만)
-- 👮 사무실 밖 경비원들 (옥상 + 공원): 보이나, 거리, 노려보는 중인가
Employees.hooks.guardSees = function(character: Model): (boolean, number, boolean, number)
	local seen, distance, staring, range = rooftop.sees(character)
	if seen then
		return seen, distance, staring, range
	end
	if parkGuard then
		return parkGuard.sees(character)
	end
	return false, math.huge, false, SalaryConfig.GUARD_RANGE
end
Missions.start(office, boss, dayCycle, Remotes, Employees.missionApi, Employees.hooks, coworkers) -- 📋 긴급 프로젝트 + 🎁 선물
Wheel.start(office, Remotes, { charge = Employees.chargeClaw, payout = Employees.payWheel }) -- 🎡 돌림판
Dart.start(office, Remotes, { charge = Employees.chargeClaw, prize = Employees.dartPrize }) -- 🎯 끌어서 던지기 풍선 다트
Arcade.start(office, Remotes, { -- 🕹️ 오락실
	charge = Employees.chargeClaw,
	reward = Employees.rewardArcade,
	exchange = Employees.exchangeArcade,
})

local Npc = require(script.Npc)
Dinner.start(dayCycle, Remotes, { -- 🍻 목요일 회식
	participants = Employees.dinnerParticipants,
	reward = Employees.dinnerReward,
	-- 눈치물산: 공원 식탁에 플레이어와 동료들을 앉히고 부장님은 상석에
	stage = function(players: { Player })
		local seats = office.dinnerSeats
		if #seats == 0 then
			return -- 대충상사는 화면 미니게임만
		end
		boss:joinDinner(office.dinnerBoss, office.dinnerLook)
		local index = 0
		for _, player in players do
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			index += 1
			local seat = seats[index]
			if humanoid and seat then
				if humanoid.SeatPart then
					for _, child in humanoid.SeatPart:GetChildren() do
						if child:IsA("Weld") and child.Name == "SeatWeld" then
							child:Destroy()
						end
					end
				end
				humanoid.Sit = false
				task.spawn(function()
					task.wait(0.1)
					player.Character:PivotTo(seat.CFrame + Vector3.new(0, 3, 0))
					task.wait(0.1)
					seat:Sit(humanoid)
				end)
			end
		end
		for _, c in coworkers.borrowAll() do
			index += 1
			local seat = seats[index]
			if seat then
				Npc.sit(c.model, seat)
				Npc.setStatus(c.model, "🍻")
			end
		end
	end,
	unstage = function()
		if #office.dinnerSeats == 0 then
			return
		end
		boss:leaveDinner()
		coworkers.returnAll(true)
	end,
	bossSay = function(text: string)
		if boss.model.Parent then
			boss:say(text, 3)
		end
	end,
})
boss:run()

-- 사무실이 다 지어졌으니 캐릭터를 만들어요
Players.CharacterAutoLoads = true
for _, player in Players:GetPlayers() do
	if not player.Character then
		task.spawn(function()
			player:LoadCharacter()
		end)
	end
end
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
