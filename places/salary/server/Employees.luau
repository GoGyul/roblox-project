-- 직원(플레이어) 관리: 자리 배정, 지금 상태, 돈 벌기, 의심도, 적발, 해고,
--                     월급명세서, 승진, 매점, 도감, 저장
--
-- 0.1초마다 플레이어마다:
--   1. 지금 상태 정하기 (자리에서 고른 행동 / 화장실 / 탕비실 / 어슬렁)
--   2. 상태에 맞게 돈 벌기 (직급이 높을수록 배율 ↑)
--   3. 부장에게 보이면 의심도 올리기 → 100이면 적발
--   4. 방금 복귀했는데 부장이 봤다면 → 아슬아슬 보너스
--
-- 오래 남아야 하는 정보(직급, 통장, 아이템, 도감)는 profile에,
-- 오늘 하루만 쓰는 정보는 today에 들어 있어요.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local Deck = require(ReplicatedStorage.Shared.Deck)
local videoDeck = Deck.new(function()
	return #SalaryConfig.VideoQuestions
end)
local ChatTopics = require(ReplicatedStorage.Shared.ChatTopics)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)
local Teleport = require(ReplicatedStorage.Shared.Teleport)
local Npc = require(script.Parent.Npc)
local Profiles = require(script.Parent.Profiles)
local Snacks = require(script.Parent.Snacks)
local StockMarket = require(script.Parent.StockMarket)

local States = SalaryConfig.States
local Ranks = SalaryConfig.Ranks
local Employees = {}

-- 플레이어가 앉을 자리 순서 (5번 = 뒷줄 가운데: 부장 바로 앞!)
local DESK_PRIORITY = { 5, 4, 6, 2, 1, 3 }
local TICK = 0.1
local AUTOSAVE_SECONDS = 60
local GAME_MINUTES_PER_SECOND = (SalaryConfig.END_MINUTE - SalaryConfig.START_MINUTE) / SalaryConfig.DAY_SECONDS
-- (명세서에 없는 상태로 번 돈은 통장에 안 들어가요! 새 농땡이를 만들면 여기에 꼭 추가)
local PAYSLIP_ORDER = { "work", "blank", "webtoon", "phone", "shopping", "sleep", "recline", "snack", "video", "toilet", "candy", "coffee", "meeting", "rooftop", "street", "lounger", "hiding", "gym", "docs", "chat", "ramen" }
local MOBILE_STATES = { "docs", "chat", "ramen" }
local MAX_TRADE = 1000 -- 한 번에 사고팔 수 있는 최대 주식 수

-- 🛡️ 요청 속도 제한 (해킹 툴로 연타하는 걸 막아요)
local allowAction = RateLimit.new(0.15)
local allowBuy = RateLimit.new(0.3)
local allowEnergy = RateLimit.new(1)
local allowTrade = RateLimit.new(0.15)
local allowMove = RateLimit.new(5)
local allowDeskPlush = RateLimit.new(0.3)

type DayRecord = {
	earned: { [string]: number }, -- 상태별 번 돈
	seconds: { [string]: number }, -- 상태별 보낸 시간
	nearMiss: number, -- 아슬아슬 보너스 합계
	caught: number, -- 오늘 적발 횟수
	chatBonus: number, -- 수다 완주 보너스 합계
	chatTopics: number, -- 오늘 끝까지 나눈 수다 주제 수
	snackBonus: number, -- 간식 완식 보너스 합계
	eventBonus: number, -- 돌발 이벤트 보너스 합계 (소방 훈련 대피 등)
	snacksEaten: number,
	stockProfit: number, -- 오늘 주식으로 번(잃은) 돈 (통장에 바로 반영돼서 명세서 합계엔 안 들어가요)
	settled: boolean, -- 오늘 번 돈을 이미 통장에 넣었나 (퇴근 명세서 또는 해고)
	nearMissCount: number?,
	photos: number?, -- 📸 농땡이하다 감사관에게 찍힌 사진
	emptyPhotos: number?, -- 🪑 경고 뒤 도망쳐서 빈자리가 찍힌 사진 (따로 세요)
	accuseWrong: number?, -- 🕶️ 엉뚱한 동료를 감사관으로 의심한 횟수
	shapesPrizes: number?, -- 🧩 오늘 도형 맞추기 상금 받은 횟수
	baseballPrizes: number?, -- ⚾ 오늘 숫자 야구 상금 받은 횟수
	planePrizes: number?, -- ✈️ 오늘 종이비행기 상금 받은 횟수
	hoopPrizes: number?, -- 🏀 오늘 옥상 농구 상금 받은 횟수
}

type EmployeeData = {
	profile: Profiles.Profile,
	canSave: boolean,
	desk: any,
	deskAction: string, -- 자리에서 고른 행동
	returnUntil: number?, -- 복귀 중이면 끝나는 시각
	state: string,
	suspicion: number,
	workSeconds: number,
	combo: number,
	lastReturnEnd: number?,
	nearMissUsed: boolean,
	slackSince: number?, -- 🕵️ 농땡이로 돈 벌기 시작한 시각 (부장님 감시 확률)
	hunchWarned: boolean?, -- 🤨 오래 농땡이 경고를 보냈나
	pigeonFedToday: boolean?, -- 🐦 오늘 비둘기에게 모이를 줬나 (안 주면 친밀도가 조금 줄어요)
	photoAimUntil: number?, -- 📷 감사관이 카메라를 든 상태 (이 시각에 찰칵)
	sunsetDay: number?, -- 🌅 노을 힐링을 받은 날 (하루 한 번)
	hideTime: number?, -- 📦 상자 속에 있은 시간
	pardonDay: number?, -- 📜 시말서 면제권 쓴 날
	halfDay: number?, -- 🏖️ 반차권 쓴 날
	coffeePassDay: number?, -- ☕ 커피 정기권 쓴 날
	examDay: number?, -- 📚 오늘 시험을 봤나 (하루 한 번)
	exam: any?, -- 📚 보고 있는 시험 { certId, questions, current, right, deadline }
	sensorCooldownUntil: number?, -- 🔔 인기척 센서 다음 진동까지
	hideCooldownUntil: number?, -- 📦 튀어나온 뒤 다시 숨을 수 있는 시각
	sunsetPhotoDay: number?, -- 📸 노을 사진 상금을 받은 날
	photoCooldownUntil: number?,
	photoWatcher: any?, -- 카메라를 든 감사관
	suspicionDanger: boolean?, -- 의심도가 NEAR_MISS_DANGER를 넘었었나 (안 걸리고 내려오면 아슬아슬 탈출)
	hongsamDay: number?, -- 🎁 오늘 홍삼을 드린 날 (하루 한 번)
	lastNearMiss: number?, -- 마지막 아슬아슬 보너스 시각 (쿨타임)
	toiletTime: number,
	away: number, -- 🖥️ 자리 부재 게이지 (0~100)
	awayWarned: boolean, -- 자동 감지 경보를 보냈나
	leeWatch: number, -- 👀 이과장이 내 농땡이를 본 시간 (초)
	leeBribed: boolean, -- ☕ 오늘 커피를 상납했나 (고자질 1번 막아 줘요)
	guardCalmFrom: number?, -- 👮 경비원 보고로 적발된 시각 (os.clock, 한동안 경비원 의심도 쉬어요)
	homeOffice: boolean, -- 🏢 들어올 때 내 회사 사무실이었나 (진급하면 출근할 때 새 회사로 자동 이동)
	moving: boolean, -- 📦 지금 새 회사로 이동 중
	leeCooldownUntil: number, -- 이 시각 전에는 다시 고자질 안 해요
	incomeRate: number, -- 지금 1초에 버는 돈
	buffs: { [string]: boolean }, -- 🏙️ 오늘 마신 카페 음료 (americano, latte, smoothie)
	heldGift: string?, -- 🎁 들고 있는 부장님 선물 (hongsam, flowers, choco)
	flowerDay: number, -- 💐 꽃다발 효과가 있는 날
	ready: boolean, -- 🏢 오늘 출근하기를 눌렀나
	videoQ: { id: number, correct: number, deadline: number }?, -- 🎧 지금 받은 화상회의 질문
	videoNext: number, -- 다음 질문 시각
	videoStreak: number, -- 연속으로 잘 대답한 횟수
	petCooldown: number, -- 🐱 다음에 쓰다듬을 수 있는 시각
	roofCaughtVisit: number, -- 🚪 옥상 순찰에 마지막으로 걸린 순찰 번호
	speed: number, -- ⚡ 오늘의 의심도 속도 (매일 1로 리셋, 사건마다 곱해져요)
	speedLog: { { label: string, delta: number } }, -- 오늘 속도가 바뀐 이유들
	nextDayFactors: { { label: string, delta: number } }, -- 내일 아침에 적용될 것 (회식, 홍삼)
	bossMood: number, -- 🍻 회식 결과: 다음 날 의심도 배율 (1보다 작으면 너그러움)
	bossMoodDay: number, -- 그 배율이 적용되는 날
	coffeeTime: number,
	energyActive: boolean, -- 오늘 에너지 드링크를 마셨나
	activity: { kind: string, untilTime: number?, coworker: any? }?, -- 돌아다니며 하는 농땡이
	chatToken: any?, -- 진행 중인 수다 대화 (바뀌면 대화가 멈춰요)
	chatReact: { id: number, deadline: number, order: { number }, choice: number? }?, -- 🗣️ 지금 떠 있는 맞장구 보기
	chatRecent: { string }?, -- 💬 최근에 나눈 주제 (같은 주제가 연달아 안 나오게)
	whisperCooldownUntil: number?, -- 🤫 친한 동료 귓속말 다음 가능 시각
	whisperGap: number?, -- 🤫 지난 틱의 부장님과의 거리 (다가오는 중인지 보려고)
	heldSnack: { id: string, progress: number }?, -- 들고 있는 간식과 먹은 양(초)
	ramenToday: number,
	gymMachine: string?, -- 🏋️ 지금 쓰는 운동기구 ID (SalaryConfig.GymMachines)
	gymSeconds: number?, -- 🏋️ 다음 스탯 +1까지 쌓인 운동 시간 (기구에서 내려도 유지)
	fired: boolean,
	today: DayRecord,
}

local function newDay(): DayRecord
	return { earned = {}, seconds = {}, nearMiss = 0, nearMissCount = 0, photos = 0, emptyPhotos = 0, accuseWrong = 0, caught = 0, chatBonus = 0, chatTopics = 0, snackBonus = 0, eventBonus = 0, snacksEaten = 0, stockProfit = 0, settled = false }
end

local function inZone(zone: BasePart, position: Vector3): boolean
	local offset = zone.CFrame:PointToObjectSpace(position)
	return math.abs(offset.X) <= zone.Size.X / 2 and math.abs(offset.Y) <= zone.Size.Y / 2 and math.abs(offset.Z) <= zone.Size.Z / 2
end

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

function Employees.start(office, boss, dayCycle, remotes, coworkers, events, lee)
	-- 지금 사무실 건물 안에 있나? (사무실에서 벌어지는 일 알림은 안에 있는 사람만)
	function Employees.inOffice(player: Player): boolean
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return root ~= nil and office.insideOffice(root.Position)
	end
	Employees.hooks = {} :: { printer: ((Player) -> boolean)?, caught: ((Player) -> ())? } -- Missions가 채워요
	local data: { [Player]: EmployeeData } = {}
	local videoFail: (Player, EmployeeData, string) -> () -- 🎧 아래에서 정의
	local endActivity: (EmployeeData) -> () -- 아래에서 정의 (나갈 때 정리에서도 써요)

	-- 📅 하루 한 번 제한 기록: 내 근무일(profile.stats.days) 기준이라 다시 들어오거나 서버를 옮겨도 그대로예요
	local function daily(d: EmployeeData): { [string]: any }
		local profile = d.profile
		if typeof(profile.daily) ~= "table" or profile.daily.day ~= profile.stats.days then
			profile.daily = { day = profile.stats.days }
		end
		return profile.daily
	end
	local deskOwner: { [number]: Player } = {}

	---------------------------------------------------------------- 도우미
	local function rankOf(d: EmployeeData)
		return Ranks[d.profile.rank]
	end

	local function hasItem(d: EmployeeData, itemId: string): boolean
		if d.profile.items[itemId] ~= true then
			return false
		end
		local untilDay = d.profile.itemUntil[itemId]
		return untilDay == nil or d.profile.stats.days < untilDay
	end

	-- ⏳ 남은 사용 기한 (오늘 포함 며칠). 기한이 없는 물건은 nil
	local function itemDaysLeft(d: EmployeeData, itemId: string): number?
		local untilDay = d.profile.itemUntil[itemId]
		if d.profile.items[itemId] ~= true or untilDay == nil then
			return nil
		end
		return math.max(0, untilDay - d.profile.stats.days)
	end

	-- ⏳ 기한이 끝난 사무용품 정리 (돌아온 날·퇴근 정산 뒤). 끝난 물건 이름 목록을 돌려줘요
	local function expireItems(d: EmployeeData): { string }
		local profile = d.profile
		local ended = {}
		for itemId, owned in profile.items do
			local item = SalaryConfig.getItem(itemId)
			if owned ~= true or not item or item.consumable or not item.days then
				continue
			end
			local untilDay = profile.itemUntil[itemId]
			if untilDay == nil then
				profile.itemUntil[itemId] = profile.stats.days + item.days -- 예전에 산 물건: 오늘부터 기한 시작
			elseif profile.stats.days >= untilDay then
				profile.items[itemId] = nil
				profile.itemUntil[itemId] = nil
				profile.deskHidden[itemId] = nil
				if itemId == "dummy_pro" then
					profile.deskHidden.dummy = nil -- 마네킹이 끝나면 서랍에 있던 인형이 다시 의자에 앉아요
				end
				table.insert(ended, `{item.emoji} {item.name}`)
			end
		end
		return ended
	end

	-- 🪑 산 사무용품이 지금 책상에 놓여 있나 (치워 두면 안 보여요)
	--   🧸/👔 인형은 의자에 앉혀 둬야 효과가 있어요. 다른 사무용품은 치워도 효과는 그대로예요.
	local function onDesk(d: EmployeeData, itemId: string): boolean
		return hasItem(d, itemId) and d.profile.deskHidden[itemId] ~= true
	end

	-- 👔 의자에 앉아 있는 인형 (최고급 마네킹이 우선)
	local function seatedDoll(d: EmployeeData): string?
		if onDesk(d, "dummy_pro") then
			return "dummy_pro"
		elseif onDesk(d, "dummy") then
			return "dummy"
		end
		return nil
	end

	-- 📚 자격증이 있나
	local function hasCert(d: EmployeeData, certId: string): boolean
		return d.profile.certs[certId] == true
	end
	-- 오늘 채워야 하는 업무 시간 (📈 PMP면 -10%)
	local function quotaOf(d: EmployeeData): number
		return math.floor(rankOf(d).quota * (if hasCert(d, "pmp") then 0.9 else 1))
	end

	-- 🖥️ 책상 장비 효과 값 (안 샀으면 0)
	local function upgradeValue(d: EmployeeData, upgradeId: string): number
		local level = d.profile.deskUpgrades[upgradeId] or 0
		local upgrade = SalaryConfig.getDeskUpgrade(upgradeId)
		local info = upgrade and upgrade.levels[level]
		return if info then info.value else 0
	end

	-- 🖥️ 자리 부재 게이지가 0 → 100%까지 차는 시간
	local function awayLimit(d: EmployeeData): number
		local doll = seatedDoll(d)
		return if doll == "dummy_pro"
			then SalaryConfig.AWAY_SECONDS_DUMMY_PRO
			elseif doll == "dummy" then SalaryConfig.AWAY_SECONDS_DUMMY
			else SalaryConfig.AWAY_SECONDS
	end

	-- 📸 오늘 감사 보고서(처벌)가 정해졌나? 농땡이 사진 2장 이상 또는 빈자리 사진 3장 이상
	local function auditReported(d: EmployeeData): boolean
		return (d.today.photos or 0) >= SalaryConfig.AUDIT_REPORT_AT or (d.today.emptyPhotos or 0) >= SalaryConfig.AUDIT_EMPTY_REPORT_AT
	end

	-- 오늘 지금까지 번 돈 (기본급 빼고, 아직 통장에 안 들어간 돈)
	local function runningTotal(d: EmployeeData): number
		local total = 0
		for _, amount in d.today.earned do
			total += amount
		end
		local auditReport = if auditReported(d) then SalaryConfig.caughtPenalty(d.profile.rank) else 0
		return total + d.today.nearMiss + d.today.chatBonus + d.today.snackBonus + d.today.eventBonus - d.today.caught * SalaryConfig.caughtPenalty(d.profile.rank) - auditReport
	end

	local function getHumanoid(player: Player): Humanoid?
		local character = player.Character
		return character and character:FindFirstChildOfClass("Humanoid")
	end

	local function isSeated(player: Player, d: EmployeeData): boolean
		local humanoid = getHumanoid(player)
		return humanoid ~= nil and d.desk.seat.Occupant == humanoid
	end

	-- 화장실 변기에 앉아 있나?
	local function isOnToilet(player: Player): boolean
		local humanoid = getHumanoid(player)
		if not humanoid then
			return false
		end
		for _, seat in office.toiletSeats do
			if seat.Occupant == humanoid then
				return true
			end
		end
		return false
	end

	-- 도감에 새 항목 기록 (처음일 때만 알림)
	local function unlock(player: Player, d: EmployeeData, entryId: string, emoji: string, name: string)
		if d.profile.collection[entryId] then
			return
		end
		d.profile.collection[entryId] = true
		remotes.Unlocked:FireClient(player, emoji, name)
	end

	local function unlockAchievement(player: Player, d: EmployeeData, achievementId: string)
		for _, achievement in SalaryConfig.Achievements do
			if achievement.id == achievementId then
				unlock(player, d, achievementId, achievement.emoji, achievement.name)
				return
			end
		end
	end

	-- 머리 위 이모지
	local function updateBubble(player: Player, state: string)
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if not head then
			return
		end
		local bubble = head:FindFirstChild("StateBubble") :: BillboardGui?
		if not bubble then
			bubble = Instance.new("BillboardGui")
			bubble.Name = "StateBubble"
			bubble.Size = UDim2.fromOffset(60, 40)
			bubble.StudsOffset = Vector3.new(0, 2.4, 0)
			bubble.MaxDistance = 80
			local label = Instance.new("TextLabel")
			label.Name = "Emoji"
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.TextScaled = true
			label.Parent = bubble
			bubble.Parent = head
		end
		((bubble :: BillboardGui):FindFirstChild("Emoji") :: TextLabel).Text = States[state].emoji
	end

	-- 클라이언트 화면에 보여 줄 값들을 속성으로 내보내요
	local function publish(player: Player, d: EmployeeData)
		local todayMoney = runningTotal(d)
		local profile = d.profile
		local nextRank = Ranks[profile.rank + 1]

		player:SetAttribute("SalaryState", d.state)
		player:SetAttribute("IncomeRate", math.floor(d.incomeRate * 10 + 0.5) / 10)
		player:SetAttribute("SalaryAction", d.deskAction)
		player:SetAttribute("Suspicion", math.floor(d.suspicion))
		player:SetAttribute("Warnings", profile.warnings)
		player:SetAttribute("TodayMoney", math.floor(todayMoney))
		player:SetAttribute("TotalMoney", math.floor(profile.money))
		player:SetAttribute("WorkSeconds", math.floor(d.workSeconds))
		player:SetAttribute("WorkQuota", quotaOf(d))
		player:SetAttribute("HalfDay", daily(d).halfday == true) -- 🏖️ 반차 중
		player:SetAttribute("DailyTarget", SalaryConfig.dailyTarget(profile.rank))
		player:SetAttribute("Combo", d.combo)
		player:SetAttribute("AccuseLeft", math.max(0, SalaryConfig.AUDIT_WRONG_MAX - (d.today.accuseWrong or 0))) -- 🕶️ 감사관 카드
		local showPhotos = events:is("audit") or (d.today.photos or 0) > 0 or (d.today.emptyPhotos or 0) > 0
		player:SetAttribute("AuditPhotos", if showPhotos then d.today.photos or 0 else -1) -- 📸 (-1이면 안 보여요)
		player:SetAttribute("AuditEmptyPhotos", d.today.emptyPhotos or 0) -- 🪑
		player:SetAttribute("AuditReported", auditReported(d))
		player:SetAttribute("NearMissLeft", math.max(0, SalaryConfig.NEAR_MISS_DAILY_MAX - (d.today.nearMissCount or 0))) -- 🔥 콤보 설명창
		player:SetAttribute("Seated", isSeated(player, d))
		player:SetAttribute("Fired", d.fired)
		player:SetAttribute("Rank", profile.rank)
		player:SetAttribute("XP", math.floor(profile.xp))
		player:SetAttribute("NextXP", if nextRank then nextRank.xp else 0)
		player:SetAttribute("Energy", profile.energy)
		player:SetAttribute("EnergyActive", d.energyActive)
		player:SetAttribute("CanSave", d.canSave)
		player:SetAttribute("OnToilet", isOnToilet(player))
		player:SetAttribute("AwayGauge", math.floor(d.away))
		player:SetAttribute("GymMachine", if d.state == "gym" then d.gymMachine or "" else "") -- 🏋️ 운동 자세 (Poses)
		local buffText = ""
		for _, item in SalaryConfig.StreetShops.cafe.items do
			if d.buffs[item.id] then
				buffText ..= item.emoji
			end
		end
		player:SetAttribute("Buffs", buffText)
		local gift = d.heldGift and SalaryConfig.getStreetItem("store", d.heldGift)
		local veggie = d.heldGift and string.match(d.heldGift, "^veggie_(.+)$")
		local veggieSeed = veggie and SalaryConfig.getSeed(veggie)
		player:SetAttribute("HeldGift", if gift then gift.emoji elseif veggieSeed then veggieSeed.emoji else "")
		player:SetAttribute("HeldGiftId", d.heldGift or "")
		player:SetAttribute("LeeWatch", math.clamp(d.leeWatch / SalaryConfig.LEE_NOTICE, 0, 1))
		player:SetAttribute("LeeBribed", d.leeBribed)
		local held = d.heldSnack
		local heldInfo = held and SalaryConfig.getSnack(held.id)
		player:SetAttribute("HeldSnack", if heldInfo then heldInfo.id else "")
		player:SetAttribute("SnackProgress", if held and heldInfo then math.clamp(held.progress / heldInfo.seconds, 0, 1) else 0)
		for _, item in SalaryConfig.Items do
			if not item.consumable then
				player:SetAttribute(`Item_{item.id}`, hasItem(d, item.id))
				player:SetAttribute(`Desk_{item.id}`, onDesk(d, item.id))
				player:SetAttribute(`ItemDays_{item.id}`, itemDaysLeft(d, item.id) or 0)
			end
		end
	end

	-- 도감은 자주 안 바뀌니 바뀔 때만 따로 보내요
	local function publishCollection(player: Player, d: EmployeeData)
		player:SetAttribute("Collection", HttpService:JSONEncode(d.profile.collection))
		player:SetAttribute("Pigeons", HttpService:JSONEncode(d.profile.pigeons)) -- 🐦 관찰 노트
		player:SetAttribute("PigeonFeeds", d.profile.pigeonFeeds)
		player:SetAttribute("Garden", HttpService:JSONEncode(d.profile.garden)) -- 🌱 텃밭 (화면이 화분을 그려요)
		player:SetAttribute("GardenToday", d.profile.stats.days)
		player:SetAttribute("Scenes", HttpService:JSONEncode(d.profile.scenes)) -- 🔭 관찰 일지
		if Employees.hooks.collectionChanged then
			Employees.hooks.collectionChanged(player, d) -- 🏆 새 업적으로 칭호가 풀리면 명패도 갱신
		end
		player:SetAttribute("DeskUpgrades", HttpService:JSONEncode(d.profile.deskUpgrades)) -- 🖥️ 책상 장비
		player:SetAttribute("Certs", HttpService:JSONEncode(d.profile.certs)) -- 📚 딴 자격증
		player:SetAttribute("Friendship", HttpService:JSONEncode(d.profile.friendship or {})) -- 🤝 동료 친밀도
		player:SetAttribute("Fitness", HttpService:JSONEncode(d.profile.fitness)) -- 🏋️ 체력 스탯
	end

	-- ⚡ 오늘의 의심도 속도 바꾸기 (합연산: delta > 0 이면 빨라지고, < 0 이면 느려져요)
	--   quiet: 화면 팝업 없이 (아침 출근 때 한꺼번에 적용할 때)
	local function adjustSpeed(player: Player, d: EmployeeData, key: string, quiet: boolean?, overrideDelta: number?, overrideLabel: string?)
		local info = SalaryConfig.SpeedFactors[key]
		local delta = overrideDelta or (info and info.delta) or 0
		local label = overrideLabel or (info and info.label) or key
		if math.abs(delta) < 0.001 then
			return
		end
		-- (소수점 오차가 쌓이지 않게 0.01 단위로 맞춰요)
		d.speed = math.clamp(math.floor((d.speed + delta) * 100 + 0.5) / 100, SalaryConfig.SPEED_MIN, SalaryConfig.SPEED_MAX)
		table.insert(d.speedLog, { label = label, delta = delta })
		player:SetAttribute("SuspicionSpeed", d.speed)
		player:SetAttribute("SpeedLog", HttpService:JSONEncode(d.speedLog))
		if not quiet then
			remotes.SpeedChange:FireClient(player, label, delta, d.speed)
		end
	end
	Employees.adjustSpeed = adjustSpeed

	-- 내일 아침에 적용할 속도 변화 예약 (🍻 회식, 🎁 홍삼)
	local function reserveSpeed(d: EmployeeData, key: string, overrideDelta: number?)
		local info = SalaryConfig.SpeedFactors[key]
		table.insert(d.nextDayFactors, { label = info.label, delta = overrideDelta or info.delta })
	end

	-- 가진 주식도 바뀔 때만 보내요
	-- 🧸 인형: 가진 인형과 책상 진열 목록 (바뀔 때만 보내요)
	local function publishPlushies(player: Player, d: EmployeeData)
		player:SetAttribute("Plushies", HttpService:JSONEncode(d.profile.plushies))
		player:SetAttribute("DeskPlushies", HttpService:JSONEncode(d.profile.deskPlushies))
		player:SetAttribute("Tickets", d.profile.tickets) -- 🎟️ 오락실 티켓도 같이
	end

	-- 🧸 책상 위에 진열한 인형 만들기 (모니터 양옆과 왼쪽 앞)
	local DESK_SPOTS = { Vector3.new(-3.6, 0, 0.2), Vector3.new(3.6, 0, 0.2), Vector3.new(-2.9, 0, 1.4) } -- (액자·소품과 안 겹치게)
	local function buildDeskPlushies(d: EmployeeData)
		local deskModel = d.desk.model
		local folder = deskModel:FindFirstChild("Plushies")
		if folder then
			folder:Destroy()
		end
		folder = Instance.new("Folder")
		folder.Name = "Plushies"
		folder.Parent = deskModel
		local seat = d.desk.seat
		local top = seat.Position + Vector3.new(0, 1.5, -SalaryConfig.DESK_SEAT_OFFSET) -- 책상 윗면 가운데
		for i, plushId in d.profile.deskPlushies do
			local plush = SalaryConfig.getPlush(plushId)
			local spot = DESK_SPOTS[i]
			if not plush or not spot then
				continue
			end
			local base = top + spot
			local function ball(size: number, offset: Vector3, color: Color3): BasePart
				local part = Instance.new("Part")
				part.Shape = Enum.PartType.Ball
				part.Size = Vector3.new(size, size, size)
				part.Position = base + offset
				part.Color = color
				part.Material = Enum.Material.Fabric
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CanTouch = false
				part.Parent = folder
				return part
			end
			ball(0.8, Vector3.new(0, 0.4, 0), plush.color) -- 몸
			local head = ball(0.6, Vector3.new(0, 1, 0), plush.color) -- 머리
			ball(0.25, Vector3.new(-0.2, 1.3, 0), plush.color) -- 귀
			ball(0.25, Vector3.new(0.2, 1.3, 0), plush.color)
			local tag = Instance.new("BillboardGui")
			tag.Size = UDim2.fromOffset(28, 28)
			tag.StudsOffset = Vector3.new(0, 0.9, 0)
			tag.MaxDistance = 25
			tag.Parent = head
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.TextScaled = true
			label.Text = plush.emoji
			label.Parent = tag
		end
	end

	-- 🧰 산 사무용품을 책상 위에 보여 줘요 (효과가 켜져 있다는 표시)
	--   🌱 화분 · 🥤 텀블러 · 🖥️ 모니터 가리개 · 🎧 이어폰 · 🧸 대리 출석 인형(자리 비우면 의자에 앉아 있어요)
	local function buildDeskItems(d: EmployeeData)
		local deskModel = d.desk.model
		local old = deskModel:FindFirstChild("Items")
		if old then
			old:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = "Items"
		folder.Parent = deskModel
		local seat = d.desk.seat
		local top = seat.Position + Vector3.new(0, 1.5, -SalaryConfig.DESK_SEAT_OFFSET) -- 책상 윗면 가운데
		local function part(size: Vector3, position: Vector3, color: Color3, props: { [string]: any }?): BasePart
			local p = Instance.new("Part")
			p.Size = size
			p.Position = position
			p.Color = color
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Material = Enum.Material.SmoothPlastic
			for key, value in props or {} do
				(p :: any)[key] = value
			end
			p.Parent = folder
			return p
		end
		if onDesk(d, "plant") then
			part(Vector3.new(0.7, 0.7, 0.7), top + Vector3.new(3.4, 0.35, 1.1), Color3.fromRGB(200, 120, 70))
			part(Vector3.new(1, 1, 1), top + Vector3.new(3.4, 1.1, 1.1), Color3.fromRGB(70, 160, 70), { Shape = Enum.PartType.Ball, Material = Enum.Material.Grass })
		end
		if onDesk(d, "tumbler") then
			part(Vector3.new(0.45, 0.8, 0.45), top + Vector3.new(2.4, 0.4, 1.2), Color3.fromRGB(80, 170, 220), { Shape = Enum.PartType.Cylinder, Orientation = Vector3.new(0, 0, 90) })
		end
		if onDesk(d, "cover") then
			-- 모니터 양옆을 감싸는 가리개
			for _, dx in { -1.5, 1.5 } do
				part(Vector3.new(0.15, 2, 0.9), top + Vector3.new(dx, 1.1, -0.85), Color3.fromRGB(40, 40, 50))
			end
			part(Vector3.new(3.15, 0.15, 0.9), top + Vector3.new(0, 2.15, -0.85), Color3.fromRGB(40, 40, 50))
		end
		if onDesk(d, "earphones") then
			part(Vector3.new(0.9, 0.12, 0.25), top + Vector3.new(-1.6, 0.06, 1.3), Color3.fromRGB(30, 30, 35))
			for _, dx in { -2.0, -1.2 } do
				part(Vector3.new(0.3, 0.3, 0.3), top + Vector3.new(dx, 0.15, 1.3), Color3.fromRGB(230, 60, 60), { Shape = Enum.PartType.Ball })
			end
		end
		local doll = seatedDoll(d)
		if doll then
			-- 🧸 대리 출석 인형 / 👔 최고급 마네킹: 내가 자리를 비우면 의자에 앉아 있어요
			local base = seat.Position + Vector3.new(0, 0.5, 0)
			local pieces: { BasePart } = {}
			local arms: { { part: BasePart, hand: BasePart, home: Vector3 } } = {}
			local function add(p: BasePart): BasePart
				table.insert(pieces, p)
				return p
			end
			if doll == "dummy_pro" then
				-- 정장 차림 마네킹: 몸·셔츠·넥타이·머리·머리카락·안경·다리, 키보드 쪽으로 뻗은 두 팔
				local suit = Color3.fromRGB(35, 40, 60)
				local skin = Color3.fromRGB(235, 205, 175)
				add(part(Vector3.new(1.9, 2, 1.1), base + Vector3.new(0, 1.1, 0.1), suit, { Material = Enum.Material.Fabric }))
				add(part(Vector3.new(0.6, 1.5, 0.05), base + Vector3.new(0, 1.3, -0.47), Color3.fromRGB(245, 245, 245)))
				add(part(Vector3.new(0.22, 1.1, 0.06), base + Vector3.new(0, 1.25, -0.5), Color3.fromRGB(190, 40, 50)))
				add(part(Vector3.new(1.25, 1.25, 1.25), base + Vector3.new(0, 2.75, 0.05), skin, { Shape = Enum.PartType.Ball, Material = Enum.Material.SmoothPlastic }))
				add(part(Vector3.new(1.3, 0.45, 1.3), base + Vector3.new(0, 3.25, 0.12), Color3.fromRGB(40, 30, 25), { Material = Enum.Material.Fabric }))
				add(part(Vector3.new(0.95, 0.12, 0.05), base + Vector3.new(0, 2.85, -0.6), Color3.fromRGB(20, 20, 20)))
				for _, dx in { -0.45, 0.45 } do
					add(part(Vector3.new(0.7, 0.55, 1.6), base + Vector3.new(dx, 0.2, -0.6), suit, { Material = Enum.Material.Fabric })) -- 허벅지
					add(part(Vector3.new(0.3, 0.3, 0.05), base + Vector3.new(dx * 0.65, 2.85, -0.62), Color3.fromRGB(60, 60, 70))) -- 안경알
				end
				for _, dx in { -1.05, 1.05 } do
					local home = base + Vector3.new(dx * 0.85, 1.45, -1.05)
					local arm = add(part(Vector3.new(0.45, 0.45, 1.9), home, suit, { Material = Enum.Material.Fabric }))
					local hand = add(part(Vector3.new(0.4, 0.3, 0.4), home + Vector3.new(0, -0.05, -1.05), skin)) -- 손
					table.insert(arms, { part = arm, hand = hand, home = home })
				end
			else
				add(part(Vector3.new(1.6, 1.8, 1), base + Vector3.new(0, 1, 0), Color3.fromRGB(80, 110, 160), { Material = Enum.Material.Fabric }))
				add(part(Vector3.new(1.2, 1.2, 1.2), base + Vector3.new(0, 2.5, 0), Color3.fromRGB(240, 210, 180), { Shape = Enum.PartType.Ball, Material = Enum.Material.Fabric }))
			end
			local away = false
			local function refresh()
				away = seat.Occupant == nil
				for _, piece in pieces do
					piece.Transparency = if away then 0 else 1
				end
			end
			refresh()
			local connection
			connection = seat:GetPropertyChangedSignal("Occupant"):Connect(function()
				if not folder.Parent then
					connection:Disconnect()
					return
				end
				refresh()
			end)
			folder.Destroying:Connect(function()
				connection:Disconnect() -- 다시 지을 때 예전 연결이 쌓이지 않게
			end)
			if #arms > 0 then
				-- ⌨️ 타닥타닥: 두 팔(손 포함)이 번갈아 키보드를 두드려요
				task.spawn(function()
					local tick = 0
					while folder.Parent do
						task.wait(0.14)
						if away then
							tick += 1
							for index, arm in arms do
								local up = if (tick + index) % 2 == 0 then 0.18 else 0
								arm.part.Position = arm.home + Vector3.new(0, up, 0)
								arm.hand.Position = arm.home + Vector3.new(0, up - 0.05, -1.05)
							end
						end
					end
				end)
			end
		end
	end

	-- 🎁 🎒 경비원 선물 개수
	local function publishGuardGifts(player: Player, d: EmployeeData)
		player:SetAttribute("GuardGifts", HttpService:JSONEncode(d.profile.guardGifts))
	end

	local function publishStocks(player: Player, d: EmployeeData)
		player:SetAttribute("StockHoldings", HttpService:JSONEncode(d.profile.stocks))
		player:SetAttribute("StockCost", HttpService:JSONEncode(d.profile.stockCost))
		player:SetAttribute("StockProfitTotal", math.floor(d.profile.stats.stockProfit))
	end

	local pendingSaves = 0
	local function save(player: Player, d: EmployeeData)
		if not d.canSave then
			return
		end
		-- 하루 중간에 나가도 오늘 번 돈이 사라지지 않게 "정산 대기" 금액으로 같이 저장해요.
		-- 다음에 들어오면 통장에 넣어 줘요.
		local unsettled = if d.today.settled or d.fired then 0 else runningTotal(d)
		d.profile.unsettled = math.max(0, math.floor(unsettled))
		pendingSaves += 1
		Profiles.save(player, d.profile)
		pendingSaves -= 1
	end

	local function seatPlayer(player: Player, d: EmployeeData)
		local character = player.Character
		local humanoid = getHumanoid(player)
		if not (character and humanoid) or humanoid.Health <= 0 then
			return
		end
		local seat = d.desk.seat
		if humanoid.SeatPart == seat then
			return -- 이미 내 자리에 앉아 있어요
		end
		-- ⚠️ 의자에 앉은 채로 캐릭터를 순간이동하면, 붙어 있는 의자까지 같이 끌려가요!
		--    (아침마다 의자가 위로 떠오르던 버그) → 먼저 의자 고정을 풀어요
		if humanoid.SeatPart then
			for _, child in humanoid.SeatPart:GetChildren() do
				if child:IsA("Weld") and child.Name == "SeatWeld" then
					child:Destroy()
				end
			end
			humanoid.Sit = false
			task.wait(0.1)
		end
		if not seat.Occupant then
			seat.CFrame = d.desk.seatHome -- 혹시 밀려나 있던 의자도 제자리로
		end
		character:PivotTo(seat.CFrame + Vector3.new(0, 3, 0))
		task.wait(0.1)
		seat:Sit(humanoid)
	end

	---------------------------------------------------------------- 자리 배정 / 입장 / 퇴장
	local function assignDesk(player: Player)
		for _, index in DESK_PRIORITY do
			if not deskOwner[index] then
				deskOwner[index] = player
				coworkers.remove(index) -- 동료를 내보내고 그 자리에 앉아요
				office.desks[index].seat:SetAttribute("OwnerId", player.UserId) -- 🪑 [E] 앉기는 주인만
				return office.desks[index]
			end
		end
		return nil
	end

	local function onPlayerAdded(player: Player)
		local profile, canSave = Profiles.load(player)
		if not player.Parent then
			return -- 불러오는 동안 나가 버림
		end
		local desk = assignDesk(player)
		if not desk then
			remotes.Notify:FireClient(player, "사무실 자리가 꽉 찼어요!")
			return
		end
		local d: EmployeeData = {
			profile = profile,
			canSave = canSave,
			desk = desk,
			deskAction = "work",
			returnUntil = nil,
			state = "work",
			suspicion = 0,
			workSeconds = 0,
			combo = 1,
			lastReturnEnd = nil,
			nearMissUsed = true,
			toiletTime = 0,
			away = 0,
			awayWarned = false,
			leeWatch = 0,
			leeBribed = false,
			homeOffice = false,
			moving = false,
			leeCooldownUntil = 0,
			bossMood = 1,
			speed = 1,
			speedLog = {},
			nextDayFactors = {},
			ready = false,
			videoQ = nil,
			videoNext = 0,
			videoStreak = 0,
			petCooldown = 0,
			roofCaughtVisit = 0,
			incomeRate = 0,
			buffs = {},
			heldGift = nil,
			flowerDay = -1,
			bossMoodDay = 0,
			coffeeTime = 0,
			energyActive = false,
			activity = nil,
			heldSnack = nil,
			ramenToday = 0,
			fired = false,
			today = newDay(),
		}
		data[player] = d
		player:SetAttribute("DeskIndex", desk.index)

		-- 🧪 스튜디오 테스트용 용돈 (저장이 꺼져 있을 때만: 진짜 저장 데이터에 섞이지 않게)
		if RunService:IsStudio() and not canSave and SalaryConfig.TEST_MONEY > 0 then
			profile.money = math.max(profile.money, SalaryConfig.TEST_MONEY)
		end
		if RunService:IsStudio() and not canSave and (SalaryConfig.TEST_RANK or 0) > 0 then
			profile.rank = math.max(profile.rank, SalaryConfig.TEST_RANK)
			profile.xp = math.max(profile.xp, SalaryConfig.Ranks[profile.rank].xp)
		end

		-- 지난번에 퇴근 전에 나갔다면, 그때까지 번 돈을 정산해 줘요
		local unsettled = profile.unsettled or 0
		if unsettled > 0 then
			profile.money += unsettled
			profile.xp += unsettled
			profile.unsettled = 0
			task.delay(3, function()
				if player.Parent then
					remotes.Bonus:FireClient(player, "💾 지난번 조퇴 전까지 번 돈 정산!", unsettled)
				end
			end)
		end

		-- 첫 플레이어가 들어오면, 그 사람이 마지막으로 일한 다음 날부터 하루를 시작해요
		-- (광장에 다녀와도 다시 월요일이 되지 않게)
		if not dayCycle.started then
			dayCycle.started = true
			dayCycle.day = profile.stats.days
			task.defer(function()
				dayCycle:run() -- 다른 모듈도 모두 준비된 뒤에 하루 시작
			end)
		end
		do
			local ended = expireItems(d) -- ⏳ 쉬는 동안 기한이 끝난 물건 정리
			if #ended > 0 then
				task.delay(5, function()
					if player.Parent then
						remotes.Notify:FireClient(player, `⏳ 사용 기한 끝: {table.concat(ended, ", ")} — 🏪 사내 매점에서 다시 살 수 있어요`)
					end
				end)
			end
		end
		publish(player, d)
		publishGuardGifts(player, d) -- 🎁 🎒 경비원 선물
		publishCollection(player, d)
		publishStocks(player, d)
		publishPlushies(player, d)
		buildDeskPlushies(d)
		buildDeskItems(d)
		if Employees.hooks.joined then
			Employees.hooks.joined(player, d) -- 🪑 내 자리 꾸미기 + 🏆 칭호
		end

		-- 🏢 회사 확인: 이 서버 사무실과 내 직급의 회사가 다르면 알려 줘요
		local here = SalaryConfig.getCompany(office.companyId)
		local mine = SalaryConfig.companyForRank(profile.rank)
		if here.id == "nunchi" then
			unlockAchievement(player, d, "company_nunchi")
			publishCollection(player, d)
		end
		-- 📦 회사가 바뀌었으면 왜 바뀌었는지 안내 (내 회사 사무실에 왔을 때만)
		d.homeOffice = mine.id == here.id
		if mine.id == here.id then
			local last = profile.lastCompany
			local notice = nil
			if here.id == "nunchi" and last ~= "nunchi" then
				notice = "promoted"
			elseif here.id == "daechung" and last == "nunchi" then
				notice = "demoted"
			end
			profile.lastCompany = here.id
			if notice then
				task.delay(1, function()
					if player.Parent then
						remotes.CompanyNotice:FireClient(player, notice, Ranks[profile.rank].name)
					end
				end)
			end
		end
		if mine.id ~= here.id then
			task.delay(4, function()
				if player.Parent then
					remotes.Notify:FireClient(player, `🏢 오늘은 같이 온 동료를 따라 {here.name} 사무실로 출근했어요. (내 회사: {mine.name})`)
				end
			end)
		end
		if not canSave then
			remotes.Notify:FireClient(player, "💾 지금은 저장 기능이 꺼져 있어요. (스튜디오라면 API 접근 설정 확인)")
		end

		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart")
			task.wait(0.5)
			if dayCycle.phase ~= "offwork" then
				seatPlayer(player, d)
			end
		end)
		if player.Character and dayCycle.phase ~= "offwork" then
			task.spawn(seatPlayer, player, d)
		end
	end


	Players.PlayerRemoving:Connect(function(player)
		local d = data[player]
		if d then
			endActivity(d)
			save(player, d)
			if Employees.hooks.left then
				Employees.hooks.left(player, d)
			end
			for _, folderName in { "Plushies", "Items" } do
				local folder = d.desk.model:FindFirstChild(folderName)
				if folder then
					folder:Destroy() -- 내 인형·물건도 같이 퇴근
				end
			end
			deskOwner[d.desk.index] = nil
			d.desk.seat:SetAttribute("OwnerId", nil)
			data[player] = nil
		end
	end)

	-- 서버가 꺼질 때 모두 저장
	game:BindToClose(function()
		for player, d in data do
			task.spawn(save, player, d)
		end
		-- 나가는 사람 저장이 끝날 때까지 서버가 꺼지지 않게 기다려요 (최대 25초)
		local waited = 0
		while pendingSaves > 0 and waited < 25 do
			waited += task.wait(0.5)
		end
	end)

	-- 자동 저장
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player, d in data do
				task.spawn(save, player, d)
			end
		end
	end)

	---------------------------------------------------------------- 행동 고르기
	remotes.SetAction.OnServerEvent:Connect(function(player, actionId)
		local d = data[player]
		if not allowAction(player) then
			return
		end
		if not d or d.fired or typeof(actionId) ~= "string" or not table.find(SalaryConfig.DeskActions, actionId) then
			return
		end
		if not isSeated(player, d) or dayCycle.phase == "offwork" then
			return
		end
		local info = States[actionId]
		if (info.unlockRank or 1) > d.profile.rank then
			remotes.Notify:FireClient(player, `🔒 {Ranks[info.unlockRank :: number].name}부터 할 수 있어요.`)
			return
		end
		if actionId == "snack" and not d.heldSnack then
			remotes.Notify:FireClient(player, "🍪 탕비실 간식 테이블에서 간식을 먼저 가져오세요!")
			return
		end
		if actionId == d.deskAction and not d.returnUntil then
			return
		end

		if actionId == "work" then
			-- 농땡이 → 일하기: 행동마다 복귀 시간이 걸려요 (에너지 드링크면 절반)
			local returnTime = (States[d.deskAction].returnTime or 0) * (if d.energyActive then 0.5 else 1)
				* (1 - upgradeValue(d, "chair")) -- 🪑 좋은 의자는 빨리 돌아와요
			if d.returnUntil then
				return -- 이미 복귀 중
			elseif returnTime > 0 then
				d.returnUntil = os.clock() + returnTime
			else
				d.deskAction = "work"
				if d.state ~= "work" then
					d.lastReturnEnd = os.clock()
					d.nearMissUsed = false
				end
			end
		else
			d.returnUntil = nil
			d.deskAction = actionId
		end
	end)

	---------------------------------------------------------------- 매점
	---------------------------------------------------------------- 🎁 경비원 선물: 🏪 매점에서 사서 🎒에 보관
	remotes.BuyGuardGift.OnServerInvoke = function(player: Player, giftId: any): (boolean, string)
		if not allowBuy(player) then
			return false, "천천히 눌러 주세요."
		end
		local d = data[player]
		local gift = typeof(giftId) == "string" and SalaryConfig.getGuardBribe(giftId)
		if not d or not gift then
			return false, "알 수 없는 상품이에요."
		end
		local store = office.shops.store
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if store and (not root or (root.Position - store.counter.Position).Magnitude > 12) then
			return false, "🏪 사내 매점 계산대 앞에서 사 주세요!"
		end
		if d.profile.money < gift.price then
			return false, "통장 잔고가 부족해요. 😢"
		end
		d.profile.money -= gift.price
		d.profile.guardGifts[gift.id] = (d.profile.guardGifts[gift.id] or 0) + 1
		publish(player, d)
		publishGuardGifts(player, d)
		task.spawn(save, player, d)
		return true, `{gift.emoji} {gift.name} 구매! 🎒 소지품에 넣었어요 (경비원 앞에서 [E]로 드려요)`
	end
	-- 경비원에게 줄 때 🎒에서 하나 꺼내요 (없으면 false)
	function Employees.useGuardGift(player: Player, giftId: string): boolean
		local d = data[player]
		local count = d and d.profile.guardGifts[giftId] or 0
		if not d or count <= 0 then
			return false
		end
		d.profile.guardGifts[giftId] = if count > 1 then count - 1 else nil
		publishGuardGifts(player, d)
		task.spawn(save, player, d)
		return true
	end

	remotes.BuyItem.OnServerInvoke = function(player: Player, itemId: any): (boolean, string)
		if not allowBuy(player) then
			return false, "천천히 눌러 주세요."
		end
		local d = data[player]
		local item = typeof(itemId) == "string" and SalaryConfig.getItem(itemId)
		if not d or not item then
			return false, "알 수 없는 상품이에요."
		end
		-- 🛡️ 이제 사무실의 🏪 사내 매점 계산대 앞에서만 살 수 있어요
		local store = office.shops.store
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if store and (not root or (root.Position - store.counter.Position).Magnitude > 12) then
			return false, "🏪 사내 매점 계산대 앞에서 사 주세요!"
		end
		local renewing = not item.consumable and hasItem(d, item.id)
		if renewing and not item.days then
			return false, "이미 가지고 있어요."
		end
		if renewing and (itemDaysLeft(d, item.id) or 0) > (item.days :: number) then
			return false, "⏳ 기한이 아직 넉넉해요. 조금 쓰다가 연장해 주세요!"
		end
		if not renewing and item.requires and not hasItem(d, item.requires) then -- (연장은 이전 단계가 끝났어도 OK)
			local need = SalaryConfig.getItem(item.requires)
			return false, `{if need then need.emoji .. " " .. need.name else "이전 단계"}부터 먼저 사 주세요!`
		end
		if d.profile.money < item.price then
			return false, "통장 잔고가 부족해요. 😢"
		end
		d.profile.money -= item.price
		if item.consumable then
			d.profile.energy += 1
		else
			-- ⏳ 기한: 처음 사면 오늘부터 days일, 쓰는 중에 또 사면 그만큼 늘어나요
			local base = if renewing then d.profile.itemUntil[item.id] or d.profile.stats.days else d.profile.stats.days
			d.profile.items[item.id] = true
			d.profile.itemUntil[item.id] = if item.days then base + item.days else nil
			if renewing then
				publish(player, d)
				task.spawn(save, player, d)
				return true, `{item.emoji} {item.name} 기한 연장! (남은 기한 {itemDaysLeft(d, item.id)}일)`
			end
			d.profile.deskHidden[item.id] = nil
			if item.id == "dummy" and onDesk(d, "dummy_pro") then
				d.profile.deskHidden.dummy = true -- 마네킹이 앉아 있으면 인형은 서랍에
			end
			if item.id == "dummy_pro" then
				d.profile.deskHidden.dummy = true -- 의자 하나에 인형 하나: 옛 인형은 서랍으로
			end
		end
		publish(player, d)
		buildDeskItems(d)
		task.spawn(save, player, d)
		return true, if item.consumable
			then `{item.emoji} {item.name} 구매 완료! 🎒 소지품이나 ⚡ 버튼으로 마셔요.`
			else `{item.emoji} {item.name} 구매 완료! 내 책상 위에 놓였어요 (⏳ {item.days or 0}일 사용)`
	end

	remotes.UseEnergy.OnServerEvent:Connect(function(player)
		if not allowEnergy(player) then
			return
		end
		local d = data[player]
		if not d or d.energyActive or d.profile.energy <= 0 or dayCycle.phase == "offwork" then
			return
		end
		d.profile.energy -= 1
		d.energyActive = true
		remotes.Notify:FireClient(player, "⚡ 꿀꺽! 오늘 하루 복귀 속도 2배!")
	end)

	---------------------------------------------------------------- 📈 화장실 주식
	local market = StockMarket.start()

	remotes.TradeStock.OnServerInvoke = function(player: Player, stockId: any, quantity: any): (boolean, string)
		if not allowTrade(player) then
			return false, "천천히 주문해 주세요."
		end
		local d = data[player]
		local stock = typeof(stockId) == "string" and SalaryConfig.getStock(stockId)
		-- 숫자가 아니거나, NaN·무한대거나, 0이거나, 한 번에 너무 많이 사면 거절
		-- (팔 때는 "전부 팔기"가 큰 수를 보내요. 가진 만큼만 팔려서 괜찮아요)
		if
			not d
			or not stock
			or typeof(quantity) ~= "number"
			or quantity ~= quantity
			or math.abs(quantity) == math.huge
			or quantity == 0
			or quantity > MAX_TRADE
		then
			return false, "잘못된 주문이에요."
		end
		if not isOnToilet(player) then
			return false, "🚽 주식은 변기에 앉아서만 할 수 있어요!"
		end
		if d.fired or dayCycle.phase == "offwork" then
			return false, "지금은 장이 닫혔어요."
		end
		local price = market.price(stock.id) :: number
		local profile = d.profile
		local owned = profile.stocks[stock.id] or 0
		quantity = math.floor(quantity)

		if quantity > 0 then
			local cost = price * quantity
			if profile.money < cost then
				return false, `통장 잔고가 부족해요. (필요 {cost}원)`
			end
			profile.money -= cost
			profile.stocks[stock.id] = owned + quantity
			profile.stockCost[stock.id] = (profile.stockCost[stock.id] or 0) + cost
			publishStocks(player, d)
			publish(player, d)
			return true, `{stock.emoji} {stock.name} {quantity}주 매수! (-{cost}원)`
		else
			local sellCount = math.min(owned, -quantity)
			if sellCount <= 0 then
				return false, "팔 주식이 없어요."
			end
			local revenue = price * sellCount
			local averageCost = (profile.stockCost[stock.id] or 0) / owned
			local profit = revenue - averageCost * sellCount
			profile.money += revenue
			profile.stocks[stock.id] = owned - sellCount
			profile.stockCost[stock.id] = math.max(0, (profile.stockCost[stock.id] or 0) - averageCost * sellCount)
			if profile.stocks[stock.id] == 0 then
				profile.stocks[stock.id] = nil
				profile.stockCost[stock.id] = nil
			end
			profile.stats.stockProfit += profit
			d.today.stockProfit += profit
			if profile.stats.stockProfit >= 10000 then
				unlockAchievement(player, d, "stock_buffett")
				publishCollection(player, d)
			end
			publishStocks(player, d)
			publish(player, d)
			task.spawn(save, player, d)
			local sign = if profit >= 0 then "+" else ""
			return true, `{stock.emoji} {stock.name} {sellCount}주 매도! 손익 {sign}{math.floor(profit)}원`
		end
	end

	---------------------------------------------------------------- 🍪 간식
	local snacks = Snacks.start(office, function(player: Player, snack): boolean
		local d = data[player]
		if not d or d.fired or dayCycle.phase == "offwork" then
			return false
		end
		if d.heldSnack then
			remotes.Notify:FireClient(player, "🍪 간식은 한 번에 하나만! 들고 있는 것부터 먹어요.")
			return false
		end
		d.heldSnack = { id = snack.id, progress = 0 }
		remotes.Notify:FireClient(player, `{snack.emoji} {snack.name}을(를) 슬쩍 챙겼다! 자리에서 [8]로 몰래 먹어요.`)
		return true
	end)

	local function finishSnack(player: Player, d: EmployeeData)
		local held = d.heldSnack
		local snack = held and SalaryConfig.getSnack(held.id)
		if not snack then
			return
		end
		d.heldSnack = nil
		d.deskAction = "work" -- 다 먹었으면 바로 일하는 척 (복귀 시간 없음)
		d.today.snackBonus += snack.bonus
		d.today.snacksEaten += 1
		remotes.Bonus:FireClient(player, `{snack.emoji} {snack.name} 완식!`, snack.bonus)
		if snack.id == "cake" then
			unlockAchievement(player, d, "cake_thief")
			publishCollection(player, d)
		elseif snack.street then
			unlockAchievement(player, d, "dessert_lover")
			publishCollection(player, d)
		elseif snack.id == "birthday" then
			unlockAchievement(player, d, "birthday_cake")
			publishCollection(player, d)
		end
	end

	---------------------------------------------------------------- 돌아다니며 하는 농땡이
	endActivity = function(d: EmployeeData)
		local activity = d.activity
		if activity and activity.kind == "chat" and activity.coworker then
			coworkers.setChatting(activity.coworker, false)
		end
		d.activity = nil
		d.chatToken = nil
	end

	local function canStartActivity(player: Player, d: EmployeeData?): boolean
		return d ~= nil and not d.fired and dayCycle.phase ~= "offwork" and not isSeated(player, d)
	end

	-- 📄 프린터에서 서류 들기
	local docsPrompt = Instance.new("ProximityPrompt")
	docsPrompt.ActionText = "서류 들기"
	docsPrompt.ObjectText = "📄 프린터"
	docsPrompt.RequiresLineOfSight = false
	docsPrompt.MaxActivationDistance = 7
	docsPrompt.Parent = office.printer
	docsPrompt.Triggered:Connect(function(player)
		if Employees.hooks.printer and Employees.hooks.printer(player) then
			remotes.Notify:FireClient(player, "🖨️ 지이잉… 출력 완료!")
			return -- 📋 긴급 프로젝트 출력 (서류 들기 대신)
		end
		local d = data[player]
		if not canStartActivity(player, d) then
			return
		end
		local employee = d :: EmployeeData
		endActivity(employee)
		employee.activity = { kind = "docs", untilTime = os.clock() + SalaryConfig.DOCS_SECONDS }
		remotes.Notify:FireClient(player, `📄 서류를 들었다! {SalaryConfig.DOCS_SECONDS}초 동안은 바빠 보여요.`)
	end)

	-- 🍜 탕비실 조리대에서 라면 끓이기
	local ramenPrompt = Instance.new("ProximityPrompt")
	ramenPrompt.ActionText = "라면 끓이기"
	ramenPrompt.ObjectText = "🍜 조리대"
	ramenPrompt.HoldDuration = 3
	ramenPrompt.RequiresLineOfSight = false
	ramenPrompt.MaxActivationDistance = 7
	ramenPrompt.Parent = office.pantryCounter
	ramenPrompt.Triggered:Connect(function(player)
		local d = data[player]
		if not canStartActivity(player, d) then
			return
		end
		local employee = d :: EmployeeData
		if employee.ramenToday >= SalaryConfig.RAMEN_PER_DAY then
			remotes.Notify:FireClient(player, "🍜 오늘 라면은 그만… 배불러요.")
			return
		end
		employee.ramenToday += 1
		endActivity(employee)
		employee.activity = { kind = "ramen", untilTime = os.clock() + SalaryConfig.RAMEN_SECONDS }
		remotes.Notify:FireClient(player, "🍜 후루룩! 냄새 때문에 부장님이 올 수도 있어요!")
	end)

	-- 💬 동료와 수다 (동료 NPC의 "수다 떨기"를 누르면 Coworkers가 여기로 알려 줘요)
	-- 주제를 하나 골라 동료 대사는 말풍선으로, 내 대사는 화면 아래로 주고받아요.
	-- 끝까지 하면 보너스 + 수다 도감 기록, 그리고 다음 주제로 이어져요.
	-- 🤝 친밀도: 점수 바꾸기 (❤️ 개수가 바뀌면 알려 줘요)
	local function friendPoints(d: EmployeeData, name: string): number
		return (d.profile.friendship or {})[name] or 0
	end
	local function addFriendship(player: Player, d: EmployeeData, name: string, delta: number)
		d.profile.friendship = d.profile.friendship or {}
		local before = friendPoints(d, name)
		local after = math.clamp(before + delta, 0, SalaryConfig.FRIEND_MAX)
		d.profile.friendship[name] = after
		local oldLevel, newLevel = SalaryConfig.friendLevel(before), SalaryConfig.friendLevel(after)
		if newLevel > oldLevel then
			local perk = if newLevel == SalaryConfig.FRIEND_STAMP_LEVEL
				then " · 단짝! 결재 도장 2개 몫"
				elseif newLevel == SalaryConfig.FRIEND_WHISPER_LEVEL then " · 부장님이 오면 귓속말로 알려 줘요"
				else ` · 수다 보너스 +{math.floor(newLevel * SalaryConfig.FRIEND_BONUS_PER_LEVEL * 100 + 0.5)}%`
			remotes.Notify:FireClient(player, `🤝 {name}와(과) 더 친해졌어요! {SalaryConfig.friendHearts(after)}{perk}`)
			if newLevel >= #SalaryConfig.FRIEND_LEVELS then
				unlockAchievement(player, d, "bestie")
			end
		elseif newLevel < oldLevel then
			remotes.Notify:FireClient(player, `💔 {name}와(과) 사이가 조금 멀어졌어요… {SalaryConfig.friendHearts(after)}`)
		end
		publishCollection(player, d)
	end

	-- 💬 동료와 수다 (동료 NPC의 "수다 떨기"를 누르면 Coworkers가 여기로 알려 줘요)
	-- 주제를 하나 골라 동료 대사는 말풍선으로, 내 대사는 화면 아래로 주고받아요.
	-- 🗣️ 맞장구 고르기가 나오면 화면에 보기 3개 (좋은 대답 = 보너스↑·친밀도↑ / 무난 = 그대로 / 눈치 없는 대답 = 삐져서 수다 끝)
	-- 끝까지 하면 보너스 + 수다 도감 기록, 그리고 다음 주제로 이어져요.
	local chatReactCounter = 0
	local function runConversation(player: Player, d: EmployeeData, coworker)
		local token = {}
		d.chatToken = token
		local function stillChatting(): boolean
			local activity = d.activity
			return d.chatToken == token
				and data[player] == d
				and activity ~= nil
				and activity.kind == "chat"
				and activity.coworker == coworker
				and not coworker.removed
		end
		local function closeReact()
			if d.chatReact then
				d.chatReact = nil
				remotes.ChatReact:FireClient(player, 0)
			end
		end

		-- 🗣️ 맞장구 하나: "good" / "neutral" / "bad" / "timeout" / nil(수다가 끝났어요)
		local function askReaction(reaction): string?
			chatReactCounter += 1
			local id = chatReactCounter
			-- 보기 순서를 섞어요 (order[화면 번호] = 원래 번호)
			local order = {}
			for i = 1, #reaction.react do
				order[i] = i
			end
			for i = #order, 2, -1 do
				local j = math.random(1, i)
				order[i], order[j] = order[j], order[i]
			end
			local options = {}
			for i, original in order do
				options[i] = reaction.react[original]
			end
			local seconds = SalaryConfig.CHAT_REACT_SECONDS
			d.chatReact = { id = id, deadline = os.clock() + seconds, order = order }
			remotes.ChatReact:FireClient(player, id, coworker.name, options, seconds)
			while true do
				task.wait(0.1)
				local current = d.chatReact
				if not stillChatting() or current == nil or current.id ~= id then
					if current and current.id == id then
						closeReact()
					else
						remotes.ChatReact:FireClient(player, 0)
					end
					return nil
				end
				if current.choice then
					d.chatReact = nil
					local original = order[current.choice]
					remotes.Notify:FireClient(player, `🗨️ 나: {reaction.react[original]}`, SalaryConfig.CHAT_LINE_SECONDS)
					return if original == reaction.good then "good" elseif original == reaction.bad then "bad" else "neutral"
				end
				if os.clock() > current.deadline + 0.3 then
					closeReact()
					return "timeout"
				end
			end
		end

		while stillChatting() do
			if not d.chatRecent then
				d.chatRecent = {}
			end
			local recent = d.chatRecent :: { string }
			local topic = ChatTopics.pick(coworker.name, d.profile.collection, recent)
			table.insert(recent, topic.id)
			if #recent > 25 then
				table.remove(recent, 1)
			end
			local goodCount = 0
			for _, line in topic.lines do
				if not stillChatting() then
					return
				end
				if ChatTopics.isReaction(line) then
					local result = askReaction(line)
					if result == nil then
						return -- 들키거나 멀어지거나 동료가 떠나서 수다가 끝났어요 (창은 닫혔어요)
					elseif result == "good" then
						goodCount += 1
						Npc.say(coworker.model, line.yay or pick(ChatTopics.GoodReplies), SalaryConfig.CHAT_LINE_SECONDS)
						remotes.Notify:FireClient(player, `🗣️ 찰떡 맞장구! 이번 수다 보너스 +{SalaryConfig.CHAT_REACT_BONUS}원 · 🤝 친밀도 +{SalaryConfig.FRIEND_GOOD}`, SalaryConfig.CHAT_LINE_SECONDS)
						addFriendship(player, d, coworker.name, SalaryConfig.FRIEND_GOOD) -- (❤️가 늘면 그 알림이 위 알림을 덮어요)
					elseif result == "bad" then
						-- 😤 눈치 없는 대답 → 동료가 삐져서 수다 끝 (이번 주제 보너스 없음)
						Npc.say(coworker.model, line.sulk or pick(ChatTopics.SulkLines), 3)
						Npc.setStatus(coworker.model, "😤")
						addFriendship(player, d, coworker.name, -SalaryConfig.FRIEND_BAD)
						remotes.Notify:FireClient(player, `😤 {coworker.name}이(가) 삐졌어요! 수다 끝 (보너스 없음 · 🤝 친밀도 -{SalaryConfig.FRIEND_BAD})`, 3)
						task.wait(1.5)
						if stillChatting() then
							endActivity(d)
						end
						return
					elseif result == "timeout" then
						Npc.say(coworker.model, pick(ChatTopics.TimeoutLines), SalaryConfig.CHAT_LINE_SECONDS)
					end
					-- (무난한 대답은 그냥 다음 줄로)
				elseif ChatTopics.isPlayerLine(line) then
					remotes.Notify:FireClient(player, `🗨️ 나: {ChatTopics.stripPlayer(line)}`, SalaryConfig.CHAT_LINE_SECONDS) -- 다음 대사 전에 사라져요
				else
					Npc.say(coworker.model, line, SalaryConfig.CHAT_LINE_SECONDS)
				end
				task.wait(SalaryConfig.CHAT_LINE_SECONDS)
			end
			if not stillChatting() then
				return
			end

			-- 주제 하나 완주! (❤️ 하나마다 +10%, 좋은 맞장구마다 +)
			local level = SalaryConfig.friendLevel(friendPoints(d, coworker.name))
			local bonus = math.floor((SalaryConfig.CHAT_TOPIC_BONUS + goodCount * SalaryConfig.CHAT_REACT_BONUS) * (1 + level * SalaryConfig.FRIEND_BONUS_PER_LEVEL))
			d.today.chatBonus += bonus
			d.today.chatTopics += 1
			unlock(player, d, `chat_{topic.id}`, "💬", topic.title) -- 처음 들은 주제면 "도감 등록!" 알림
			local collected = 0
			for entryId in d.profile.collection do
				if string.sub(entryId, 1, 5) == "chat_" then
					collected += 1
				end
			end
			if collected >= SalaryConfig.CHATTERBOX_TOPICS then
				unlockAchievement(player, d, "chatterbox")
			end
			addFriendship(player, d, coworker.name, SalaryConfig.FRIEND_TOPIC) -- (안에서 도감도 다시 보내요)
			remotes.Bonus:FireClient(player, `💬 수다 성공! "{topic.title}"`, bonus)
			task.wait(1.5)
		end
	end

	local function startChat(player: Player, coworker)
		local d = data[player]
		if not canStartActivity(player, d) then
			return
		end
		local employee = d :: EmployeeData
		endActivity(employee)
		employee.activity = { kind = "chat", coworker = coworker }
		coworkers.setChatting(coworker, true)
		remotes.Notify:FireClient(player, `💬 {coworker.name}와(과) 수다 시작! 🤝 {SalaryConfig.friendHearts(friendPoints(employee, coworker.name))}`, SalaryConfig.CHAT_LINE_SECONDS)
		task.spawn(runConversation, player, employee, coworker)
	end
	Employees.startChat = startChat

	---------------------------------------------------------------- 📚 자격증 시험
	local function examQuestion(exam): any
		local q = exam.questions[exam.current]
		return {
			text = q.text,
			choices = q.choices,
			number = exam.current,
			total = #exam.questions,
			deadline = exam.deadline,
			right = exam.right,
		}
	end
	remotes.CertExam.OnServerInvoke = function(player: Player, action: any, value: any)
		local d = data[player]
		if not d or not allowBuy(player) then
			return { ok = false, message = "천천히!" }
		end
		if action == "start" then
			local cert = SalaryConfig.getCertificate(if typeof(value) == "string" then value else "")
			if not cert then
				return { ok = false, message = "없는 자격증이에요." }
			end
			if hasCert(d, cert.id) then
				return { ok = false, message = "이미 딴 자격증이에요! ✅" }
			end
			if d.profile.rank < cert.rank then
				return { ok = false, message = `🔒 {Ranks[cert.rank].name}부터 응시할 수 있어요.` }
			end
			if d.exam and d.exam.certId == cert.id then
				-- 창이 닫혀도 보던 시험은 이어서 (응시료를 또 내지 않아요)
				if workspace:GetServerTimeNow() > d.exam.deadline then
					d.exam.deadline = workspace:GetServerTimeNow() + SalaryConfig.CERT_TIME -- (창을 닫았다 열어 시간을 늘리진 못해요)
				end
				return { ok = true, question = examQuestion(d.exam) }
			end
			if d.fired then
				return { ok = false, message = "지금은 응시할 수 없어요." }
			end
			if daily(d).exam then
				return { ok = false, message = "📚 시험은 하루 한 번! 내일 다시 도전해요." }
			end
			if d.profile.money < cert.price then
				return { ok = false, message = `통장 잔고가 부족해요. 😢 (응시료 {cert.price}원)` }
			end
			d.profile.money -= cert.price
			daily(d).exam = true
			-- 퀴즈 문제은행에서 서로 다른 문제 뽑기 (보기 순서는 섞어요)
			local pool = {}
			for i = 1, #SalaryConfig.QuizQuestions do
				table.insert(pool, i)
			end
			local questions = {}
			for _ = 1, SalaryConfig.CERT_QUESTIONS do
				local index = table.remove(pool, math.random(1, #pool))
				local source = SalaryConfig.QuizQuestions[index]
				local order = {}
				for k = 1, #source.choices do
					table.insert(order, k)
				end
				for k = #order, 2, -1 do
					local j = math.random(1, k)
					order[k], order[j] = order[j], order[k]
				end
				local choices, correct = {}, 1
				for slot, original in order do
					choices[slot] = source.choices[original]
					if original == source.answer then
						correct = slot
					end
				end
				table.insert(questions, { text = source.q, choices = choices, correct = correct })
			end
			d.exam = { certId = cert.id, questions = questions, current = 1, right = 0, deadline = workspace:GetServerTimeNow() + SalaryConfig.CERT_TIME }
			publish(player, d)
			task.spawn(save, player, d)
			return { ok = true, question = examQuestion(d.exam) }
		elseif action == "answer" then
			local exam = d.exam
			if not exam then
				return { ok = false, message = "진행 중인 시험이 없어요." }
			end
			local q = exam.questions[exam.current]
			local inTime = workspace:GetServerTimeNow() <= exam.deadline + 1
			local correct = inTime and value == q.correct
			if correct then
				exam.right += 1
			end
			local reply = { ok = true, correct = correct, timeout = not inTime, answer = q.choices[q.correct] }
			exam.current += 1
			if exam.current > #exam.questions then
				-- 채점!
				d.exam = nil
				local cert = SalaryConfig.getCertificate(exam.certId)
				reply.done = true
				reply.right = exam.right
				reply.passed = exam.right >= SalaryConfig.CERT_PASS
				if reply.passed and cert then
					d.profile.certs[cert.id] = true
					d.profile.xp += cert.xp
					reply.xp = cert.xp
					reply.perk = cert.perk
					unlockAchievement(player, d, "cert_first")
					local all = true
					for _, c in SalaryConfig.Certificates do
						if not d.profile.certs[c.id] then
							all = false
						end
					end
					if all then
						unlockAchievement(player, d, "cert_all")
					end
					publishCollection(player, d)
					for _, other in Players:GetPlayers() do
						remotes.Notify:FireClient(other, `📚 {player.DisplayName} 님이 {cert.emoji} {cert.name} 합격!`)
					end
				end
				publish(player, d)
				task.spawn(save, player, d)
			else
				exam.deadline = workspace:GetServerTimeNow() + SalaryConfig.CERT_TIME
				reply.question = examQuestion(exam)
			end
			return reply
		end
		return { ok = false, message = "잘못된 요청이에요." }
	end

	---------------------------------------------------------------- 🎟️ 특수 쿠폰 (사자마자 바로 써요)
	local tripToken = 0
	remotes.BuyCoupon.OnServerInvoke = function(player: Player, couponId: any)
		local d = data[player]
		if not allowBuy(player) then
			return { ok = false, message = "천천히!" }
		end
		local coupon = d and SalaryConfig.getCoupon(if typeof(couponId) == "string" then couponId else "")
		if not d or not coupon or d.fired then
			return { ok = false, message = "지금은 쓸 수 없어요." }
		end
		if d.profile.money < coupon.price then
			return { ok = false, message = `통장 잔고가 부족해요. 😢 ({coupon.price}원 필요)` }
		end
		local message = ""
		if coupon.id == "pardon" then
			if d.profile.warnings <= 0 then
				return { ok = false, message = "📜 지울 경고가 없어요!" }
			end
			if daily(d).pardon then
				return { ok = false, message = "📜 시말서 면제권은 하루 1장만!" }
			end
			daily(d).pardon = true
			d.profile.warnings -= 1
			message = `📜 경고 -1! (남은 경고 {d.profile.warnings}/{SalaryConfig.MAX_WARNINGS})`
		elseif coupon.id == "trip" then
			if dayCycle.phase ~= "work" or not boss.active then
				return { ok = false, message = "✈️ 부장님이 지금 사무실에 없어요." }
			end
			tripToken += 1
			local myToken = tripToken
			boss:goTrip()
			local bossToken = boss.token -- (그사이 소방 훈련·워크숍·점심이 시작되면 부장님 일정이 바뀌어요)
			unlockAchievement(player, d, "coupon_trip")
			publishCollection(player, d)
			for other in data do
				remotes.Notify:FireClient(other, `✈️ {player.DisplayName} 님 덕분에 부장님이 {SalaryConfig.TRIP_SECONDS}초 동안 출장! 지금이 기회~`)
			end
			task.delay(SalaryConfig.TRIP_SECONDS, function()
				-- (그사이 점심·퇴근이 됐으면 원래 일정대로)
				if tripToken == myToken and boss.token == bossToken and dayCycle.phase == "work" and not boss.active then -- (훈련·워크숍·점심이면 boss.token이 바뀌어 있어요)
					boss:backFromLunch()
					for other in data do
						remotes.Notify:FireClient(other, "✈️ 부장님이 출장에서 돌아왔어요! 일하는 척!")
					end
				end
			end)
			message = "✈️ 부장님 출장 출발!"
		elseif coupon.id == "halfday" then
			if dayCycle.phase == "offwork" then
				return { ok = false, message = "🏖️ 벌써 퇴근 시간이에요." }
			end
			if daily(d).halfday then
				return { ok = false, message = "🏖️ 오늘은 이미 반차 중이에요." }
			end
			daily(d).halfday = true
			d.suspicionDanger = false -- (반차로 의심도가 0이 된 건 "아슬아슬 탈출"이 아니에요)
			d.nearMissUsed = true
			d.photoAimUntil = nil
			d.workSeconds = math.max(d.workSeconds, quotaOf(d)) -- 업무 할당량은 채운 걸로
			d.suspicion = 0
			unlockAchievement(player, d, "coupon_halfday")
			publishCollection(player, d)
			message = "🏖️ 반차 시작! 오늘 남은 시간은 마음껏 (농땡이 수입은 없어요)"
		elseif coupon.id == "coffee_pass" then
			if daily(d).coffee then
				return { ok = false, message = "☕ 오늘 정기권은 이미 있어요." }
			end
			daily(d).coffee = true -- (퇴근 후에 사면 다음 근무일에 적용돼요)
			message = "☕ 커피 정기권! 오늘 이과장은 몇 번이든 눈감아 줘요"
		end
		d.profile.money -= coupon.price
		publish(player, d)
		task.spawn(save, player, d)
		return { ok = true, message = message }
	end

	---------------------------------------------------------------- 🖥️ 책상 장비 업그레이드
	remotes.DeskUpgrade.OnServerInvoke = function(player: Player, upgradeId: any)
		local d = data[player]
		if not allowBuy(player) then
			return { ok = false, message = "천천히!" }
		end
		local upgrade = d and SalaryConfig.getDeskUpgrade(if typeof(upgradeId) == "string" then upgradeId else "")
		if not d or not upgrade then
			return { ok = false, message = "없는 장비예요." }
		end
		if d.fired then
			return { ok = false, message = "지금은 살 수 없어요." }
		end
		if d.state ~= "shopping" then
			return { ok = false, message = "🛒 [온라인 쇼핑] 농땡이 중에만 주문할 수 있어요! 내 자리에서 쇼핑을 켜 봐요" } -- 🛒 장비도 쇼핑몰에서
		end
		local level = d.profile.deskUpgrades[upgrade.id] or 0
		local nextLevel = upgrade.levels[level + 1]
		if not nextLevel then
			return { ok = false, message = "이미 최고 단계예요! 🏆" }
		end
		if d.profile.money < nextLevel.price then
			return { ok = false, message = `통장 잔고가 부족해요. 😢 ({nextLevel.price}원 필요)` }
		end
		d.profile.money -= nextLevel.price
		d.profile.deskUpgrades[upgrade.id] = level + 1
		unlockAchievement(player, d, "upgrade_first")
		local maxed = true
		for _, u in SalaryConfig.DeskUpgrades do
			if (d.profile.deskUpgrades[u.id] or 0) < #u.levels then
				maxed = false
			end
		end
		if maxed then
			unlockAchievement(player, d, "upgrade_max")
		end
		publishCollection(player, d)
		publish(player, d)
		task.spawn(save, player, d)
		return { ok = true, message = `⚙️ {upgrade.emoji} {upgrade.name} {level + 1}단계! {nextLevel.text}` }
	end

	---------------------------------------------------------------- 🕶️ [R] "감사팀이죠?"
	coworkers.onAccuse = function(player: Player, coworker)
		local d = data[player]
		if not d or d.fired or not events:is("audit") or events.auditRevealed then
			return
		end
		if (d.today.accuseWrong or 0) >= SalaryConfig.AUDIT_WRONG_MAX then
			remotes.Notify:FireClient(player, "🙊 오늘은 더 의심했다간 사내 평판이 바닥나요… (내일 다시)")
			return
		end
		if events:isDisguisedAuditor(coworker) then
			-- 🎉 정답! 감사 끝 + 모두의 사진 폐기 + 보너스
			events:revealAuditor(player)
			d.today.eventBonus += SalaryConfig.AUDIT_REVEAL_BONUS
			remotes.Bonus:FireClient(player, "🕶️ 감사관 색출!", SalaryConfig.AUDIT_REVEAL_BONUS)
			unlockAchievement(player, d, "audit_reveal")
			adjustSpeed(player, d, "auditReveal")
			publishCollection(player, d)
			for other, od in data do
				od.today.photos = 0
				od.today.emptyPhotos = 0
				od.photoAimUntil = nil
				remotes.AuditPhoto:FireClient(other, "reveal", 0)
			end
		else
			-- 😠 엉뚱한 사람을 의심했어요
			d.today.accuseWrong = (d.today.accuseWrong or 0) + 1
			d.suspicion = math.min(99, d.suspicion + SalaryConfig.AUDIT_WRONG_SUSPICION)
			adjustSpeed(player, d, "accuseWrong")
			Npc.say(coworker.model, pick({ "네? 저 그냥 일하는 사람인데요…😠", "감사팀이요? 제가요? 하…", "저 이 회사 7년 차예요." }), 3)
			local left = SalaryConfig.AUDIT_WRONG_MAX - d.today.accuseWrong
			remotes.AuditPhoto:FireClient(player, "wrong", left)
		end
		publish(player, d)
	end

	---------------------------------------------------------------- 적발과 해고
	local function fire(player: Player, d: EmployeeData)
		d.fired = true
		d.state = "fired"
		updateBubble(player, "fired")
		local profile = d.profile
		profile.stats.fired += 1
		-- 해고: 통장 0원 + 직급 한 단계 강등
		profile.money = 0
		profile.rank = math.max(1, profile.rank - 1)
		profile.xp = Ranks[profile.rank].xp
		profile.warnings = 0
		d.today.settled = true -- 해고되면 오늘 번 돈은 없어요
		unlockAchievement(player, d, "fired")
		publishCollection(player, d)
		task.spawn(save, player, d)
	end

	-- noScold: 사무실 부장님이 혼내러 걸어오지 않아요 (엘리베이터·옥상처럼 다른 곳에서 걸렸을 때)
	local function caught(player: Player, d: EmployeeData, customLine: string?, noScold: boolean?)
		adjustSpeed(player, d, "caught")
		d.profile.warnings += 1
		d.profile.stats.caught += 1
		d.today.caught += 1
		d.combo = 1
		d.suspicion = 0
		d.suspicionDanger = false -- 걸렸으니 탈출 아님
		local wasEating = d.state == "snack" or (d.state == "returning" and d.deskAction == "snack")
		if wasEating and d.heldSnack then
			d.heldSnack = nil
			remotes.Notify:FireClient(player, "🍪 간식을 압수당했다…")
		end
		if Employees.hooks.caught then
			Employees.hooks.caught(player) -- 📋 긴급 프로젝트 중이면 실패
		end
		d.deskAction = "work"
		d.returnUntil = nil
		-- 자리 비움 시간도 처음부터 (안 그러면 화장실에서 연달아 적발돼 바로 해고돼요)
		d.toiletTime, d.coffeeTime = 0, 0
		d.away, d.awayWarned = 0, false
		local humanoid = getHumanoid(player)
		if humanoid and humanoid.SeatPart and isOnToilet(player) then
			-- 부장님이 화장실 문을 두드려요: 변기에서 일으켜 세워요
			for _, child in humanoid.SeatPart:GetChildren() do
				if child:IsA("Weld") and child.Name == "SeatWeld" then
					child:Destroy()
				end
			end
			humanoid.Sit = false
		end
		endActivity(d)
		unlockAchievement(player, d, "caught")
		publishCollection(player, d)
		local line = customLine or pick(SalaryConfig.BossLines.caught)
		if player.Character and not noScold then
			boss:scold(player.Character, line)
		end

		if d.profile.warnings >= SalaryConfig.MAX_WARNINGS then
			fire(player, d)
			remotes.Fired:FireClient(player, line, Ranks[d.profile.rank].name)
		else
			remotes.Caught:FireClient(player, line, d.profile.warnings)
		end
	end

	-- 👮 경비원 보고로 적발된 뒤: GUARD_CATCH_CALM초는 0, 그 뒤 GUARD_CATCH_RAMP초 동안 0.3 → 1.0
	local function guardCalm(d: EmployeeData, now: number): number
		local from = d.guardCalmFrom
		if not from then
			return 1
		end
		local elapsed = now - from
		if elapsed < SalaryConfig.GUARD_CATCH_CALM then
			return 0
		end
		local ramp = (elapsed - SalaryConfig.GUARD_CATCH_CALM) / SalaryConfig.GUARD_CATCH_RAMP
		if ramp >= 1 then
			d.guardCalmFrom = nil
			return 1
		end
		return 0.3 + 0.7 * ramp
	end

	-- 🚨 의심도 100: 사무실 안이면 부장님이 직접, 사무실 밖(옥상·공원·거리)이면 👮 경비원이 📻 무전으로 보고해요
	--   (부장님은 사무실을 떠나지 않아요)
	local function guardOrBossCatch(player: Player, d: EmployeeData, root: BasePart)
		if office.insideOffice(root.Position) then
			caught(player, d)
			return
		end
		local onRoof = Employees.hooks.onRoof ~= nil and Employees.hooks.onRoof(root.Position)
		local where = if onRoof then "옥상" else "밖"
		if boss.active and boss.model.Parent then
			boss:say(`(📻 무전) 뭐? {player.DisplayName} 씨가 {where}에서 놀고 있다고?!`, 4)
		end
		caught(player, d, `📻 경비원 보고: "{where}에서 근무 시간에 놀고 있었습니다!" → 부장님: "당장 자리로 와!!"`, true)
		-- 😮‍💨 연달아 또 걸리지 않게: 한동안은 경비원 의심도가 안 오르고, 그 뒤 천천히 다시 올라가요
		d.guardCalmFrom = os.clock()
	end

	---------------------------------------------------------------- 소음 (부장이 조사하러 올 곳)
	-- 👔 부장님이 이번엔 누구를 확인하러 갈까?
	--   소음(자기·라면 등) + 🕵️ 농땡이로 돈 버는 중이면 확률이 더 붙고, 오래 할수록 계속 올라가요
	boss.noiseSource = function(): (Vector3?, number)
		local loudest, chance = nil, 0
		local now = os.clock()
		for player, d in data do
			if d.fired or daily(d).halfday then
				continue -- (해고·🏖️ 반차 중인 사람은 확인하러 가지 않아요)
			end
			local noise = States[d.state].noise or 0
			if d.slackSince then
				local slackFor = now - d.slackSince
				noise += SalaryConfig.BOSS_SLACK_WATCH + slackFor * SalaryConfig.BOSS_SLACK_RAMP
			end
			noise = math.min(noise, SalaryConfig.BOSS_SLACK_MAX)
			if d.state == "phone" then
				noise *= SalaryConfig.PHONE_GAME_WATCH -- 📱 폰 게임 중엔 부장님이 잘 안 와요
			end
			if d.slackSince and now - d.slackSince >= SalaryConfig.SLACK_FORCE_VISIT then
				noise = 1 -- 🤨 너무 오래 안 보였어요: 이번엔 반드시 확인하러 와요
			end
			if noise > chance then
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local seated = isSeated(player, d)
				local target: Vector3? = nil
				if seated or not root then
					target = d.desk.behind -- 자리에서 딴짓: 등 뒤로 와서 모니터를 봐요
				elseif office.insideOffice(root.Position) then
					target = root.Position + Vector3.new(0, -3, 0) -- 사무실 안(탕비실·화장실·회의실…): 그 자리로
				end
				-- (옥상·거리처럼 사무실 밖은 사무실 부장님이 못 따라가요)
				if target then
					loudest = target
					chance = noise
				end
			end
		end
		return loudest, chance
	end

	---------------------------------------------------------------- 🎧 화상회의 질문 대답
	videoFail = function(player: Player, d: EmployeeData, message: string)
		d.videoQ = nil
		d.videoStreak = 0
		d.videoNext = os.clock() + math.random(SalaryConfig.VIDEO_GAP[1], SalaryConfig.VIDEO_GAP[2])
		d.suspicion += SalaryConfig.VIDEO_FAIL
		adjustSpeed(player, d, "videoFail")
		remotes.VideoQuestion:FireClient(player, 0)
		remotes.Notify:FireClient(player, message .. ` (의심도 +{SalaryConfig.VIDEO_FAIL}, 부장님이 와요!)`)
		boss:callTo(d.desk.behind)
	end

	-- 🗣️ 맞장구 대답 (runConversation이 기다리고 있다가 처리해요)
	remotes.ChatReactAnswer.OnServerEvent:Connect(function(player, id, choice)
		local d = data[player]
		local react = d and d.chatReact
		if not react or react.id ~= id or react.choice ~= nil then
			return
		end
		if typeof(choice) ~= "number" or choice ~= math.floor(choice) or not react.order[choice] then
			return
		end
		if os.clock() > react.deadline + 0.3 then
			return -- 시간 초과 (조금은 봐줘요: 통신 지연)
		end
		react.choice = choice
	end)

	remotes.VideoAnswer.OnServerEvent:Connect(function(player, id, choice)
		local d = data[player]
		if not d or not d.videoQ or d.videoQ.id ~= id or typeof(choice) ~= "number" then
			return
		end
		if os.clock() > d.videoQ.deadline then
			return -- 시간 초과는 틱에서 처리
		end
		if choice == d.videoQ.correct then
			d.videoQ = nil
			d.videoStreak += 1
			d.videoNext = os.clock() + math.random(SalaryConfig.VIDEO_GAP[1], SalaryConfig.VIDEO_GAP[2])
			local videoBonus = math.floor(SalaryConfig.VIDEO_BONUS * (if hasCert(d, "toeic") then 1.5 else 1)) -- 🌍 토익: ×1.5
			d.today.eventBonus += videoBonus
			remotes.Bonus:FireClient(player, if hasCert(d, "toeic") then "🎧 유창한 영어 대답!" else "🎧 그럴듯한 대답!", videoBonus)
			if d.videoStreak >= 5 then
				unlockAchievement(player, d, "video_pro")
				publishCollection(player, d)
			end
		else
			videoFail(player, d, `😱 "{player.DisplayName} 씨… 지금 뭐라고요?"`)
		end
	end)

	---------------------------------------------------------------- 매 틱 계산
	local function tick(player: Player, d: EmployeeData, dt: number)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if d.fired or not (character and root) then
			return
		end
		local now = os.clock()

		-- 0. 남의 책상 의자에 앉았으면 일으켜 세워요 (변기는 괜찮아요)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local seatPart = humanoid and humanoid.SeatPart
		if humanoid and seatPart and seatPart.Name == "Seat" and seatPart ~= d.desk.seat then
			for _, child in seatPart:GetChildren() do
				if child:IsA("Weld") and child.Name == "SeatWeld" then
					child:Destroy()
				end
			end
			humanoid.Sit = false
			remotes.Notify:FireClient(player, "🙅 여기는 다른 사람 자리예요! ⭐ 표시된 내 자리에 앉아요.")
		end

		-- 1. 지금 상태
		local previous = d.state
		if isSeated(player, d) then
			d.toiletTime, d.coffeeTime = 0, 0
			if d.returnUntil and now >= d.returnUntil then
				d.returnUntil = nil
				d.deskAction = "work"
				d.lastReturnEnd = now
				d.nearMissUsed = false
			end
			d.state = if d.returnUntil then "returning" else d.deskAction
			if d.activity then
				endActivity(d) -- 자리에 앉으면 돌아다니던 농땡이는 끝
			end
		else
			d.deskAction = "work" -- 일어나면 다시 앉을 때는 일하는 상태
			d.returnUntil = nil
			local activity = d.activity
			local inPantry = inZone(office.pantryZone, root.Position)
			-- 끝난 활동 정리
			if activity then
				local expired = activity.untilTime ~= nil and now >= activity.untilTime
				local leftPantry = activity.kind == "ramen" and not inPantry
				local tooFar = activity.kind == "chat"
					and (activity.coworker.removed or (activity.coworker.root.Position - root.Position).Magnitude > SalaryConfig.CHAT_RANGE)
				if expired or leftPantry or tooFar then
					if activity.kind == "docs" and expired then
						remotes.Notify:FireClient(player, "📄 서류 들고 너무 오래 돌아다녔어요. 이제 수상해 보여요!")
					end
					endActivity(d)
					activity = nil
				end
			end

			local onMeetingSeat = seatPart ~= nil and seatPart.Name == "MeetingSeat" and humanoid ~= nil and humanoid.SeatPart == seatPart
			local onLounger = seatPart ~= nil and seatPart.Name == "Lounger" and humanoid ~= nil and humanoid.SeatPart == seatPart
			local inHideBox = seatPart ~= nil and seatPart.Name == "HideSeat" and humanoid ~= nil and humanoid.SeatPart == seatPart
			local onGymSeat = seatPart ~= nil and seatPart.Name == "GymSeat" and humanoid ~= nil and humanoid.SeatPart == seatPart
			if inHideBox then
				d.state = "hiding" -- 📦 옥상 상자 속 (밖에서 안 보여요)
				d.hideTime = (d.hideTime or 0) + dt
				local tooSoon = now < (d.hideCooldownUntil or 0)
				if tooSoon or d.hideTime >= SalaryConfig.HIDE_MAX then
					-- 답답해서 못 참고 튀어나와요
					d.hideTime = 0
					if not tooSoon then
						d.hideCooldownUntil = now + SalaryConfig.HIDE_COOLDOWN
					end
					for _, child in (seatPart :: BasePart):GetChildren() do
						if child:IsA("Weld") and child.Name == "SeatWeld" then
							child:Destroy()
						end
					end
					(humanoid :: Humanoid).Sit = false
					(humanoid :: Humanoid).Jump = true
					remotes.Notify:FireClient(
						player,
						if tooSoon
							then `📦 아직 숨이 차요… {math.ceil((d.hideCooldownUntil :: number) - now)}초 뒤에 다시 숨을 수 있어요`
							else `📦 너무 답답해서 상자 밖으로 튀어나왔어요! ({SalaryConfig.HIDE_COOLDOWN}초 동안은 못 들어가요)`
					)
				end
			else
				d.hideTime = 0
			end
			if inHideBox then
				-- (위에서 정했어요)
			elseif onMeetingSeat then
				d.state = "meeting" -- 📊 유리 회의실에서 회의하는 척 졸기
			elseif onLounger then
				d.state = "lounger" -- 🏖️ 옥상 선베드 일광욕
			elseif onGymSeat then
				d.state = "gym" -- 🏋️ 체력 단련실 운동기구에서 땀 흘리기
				d.gymMachine = (seatPart :: BasePart):GetAttribute("Machine")
			elseif Employees.hooks.onRoof and Employees.hooks.onRoof(root.Position) then
				d.state = "rooftop" -- 🌬️ 옥상 바람 쐬기
			elseif inZone(office.toiletZone, root.Position) then
				d.state = "toilet"
				d.toiletTime += dt
			elseif office.candyZone and inZone(office.candyZone, root.Position) then
				d.state = "candy" -- 🍭 공원 흡연구역에서 사탕 물기 (화장실처럼 자리 비움 시간이 쌓여요)
				d.toiletTime += dt
			elseif activity and activity.kind == "ramen" then
				d.state = "ramen"
			elseif inPantry then
				d.state = "coffee"
				d.coffeeTime += dt
			elseif activity then
				d.state = activity.kind -- "docs" 또는 "chat"
			elseif office.inStreet and office.inStreet(root.Position) then
				d.state = "street" -- 🛍️ 눈치 스트리트 구경 (옥상처럼 돈이 쌓여요, 👮 경비원 주의)
			else
				d.state = "roam"
			end
		end
		local info = States[d.state]
		-- 🕵️‍ 농땡이로 돈 버는 중이면 시작 시각을 기억해요 (오래 할수록 부장님이 확인하러 올 확률 ↑)
		if d.state ~= "work" and d.state ~= "returning" and (info.income or 0) > 0 then
			d.slackSince = d.slackSince or now
		else
			d.slackSince = nil
		end
		if d.state ~= previous then
			updateBubble(player, d.state)
			if info.payLabel and d.state ~= "work" then
				unlock(player, d, `action_{d.state}`, info.emoji, info.name)
				local allMobile = true
				for _, mobileState in MOBILE_STATES do
					if not d.profile.collection[`action_{mobileState}`] then
						allMobile = false
					end
				end
				if allMobile then
					unlockAchievement(player, d, "mobile")
				end
				publishCollection(player, d)
			end
		end

		-- 처음 변기에 앉으면 주식 입문 지원금
		if d.state == "toilet" and not d.profile.stockGift and isOnToilet(player) then
			d.profile.stockGift = true
			d.profile.money += SalaryConfig.STOCK_STARTER_GIFT
			remotes.Bonus:FireClient(player, "🧻 화장실 증권 입문 지원금!", SalaryConfig.STOCK_STARTER_GIFT)
		end

		-- 업적 체크
		if d.state == "toilet" and d.toiletTime >= 50 then
			unlockAchievement(player, d, "toilet_long")
		end
		if dayCycle.phase == "lunch" and (d.state == "sleep" or d.state == "recline") then
			unlockAchievement(player, d, "lunch_nap")
		end

		-- 1.5 🎧 화상회의 하는 척: 가끔 질문이 와요
		if d.state == "video" and dayCycle.phase == "work" and not daily(d).halfday then
			if not d.videoQ and now >= d.videoNext then
				if d.videoNext == 0 then
					d.videoNext = now + math.random(SalaryConfig.VIDEO_GAP[1], SalaryConfig.VIDEO_GAP[2]) -- 막 시작했으면 조금 있다가
				else
					local question = SalaryConfig.VideoQuestions[videoDeck()] -- 🃏 다 볼 때까지 안 겹쳐요
					local order = { 1, 2, 3 }
					for i = #order, 2, -1 do
						local j = math.random(1, i)
						order[i], order[j] = order[j], order[i]
					end
					local options = {}
					for _, index in order do
						table.insert(options, question[2][index])
					end
					local id = math.random(1, 1000000000)
					d.videoQ = { id = id, correct = table.find(order, 1) :: number, deadline = now + SalaryConfig.VIDEO_ANSWER }
					local text = string.gsub(question[1], "{name}", player.DisplayName)
					remotes.VideoQuestion:FireClient(player, id, text, options, SalaryConfig.VIDEO_ANSWER)
				end
			elseif d.videoQ and now > d.videoQ.deadline then
				videoFail(player, d, "🎧 대답을 못 했어요! 회의에서 멍때리다 걸렸어요…")
			end
		elseif d.videoQ or d.videoNext ~= 0 then
			-- 회의에서 나가면 질문도 끝
			if d.videoQ then
				remotes.VideoQuestion:FireClient(player, 0)
			end
			d.videoQ, d.videoNext = nil, 0
		end

		-- 😺 월급냥이 부장님 정신을 빼놓은 사이에 농땡이!
		if boss.distractedUntil and now < boss.distractedUntil and d.state ~= "work" and (States[d.state].income or 0) > 0 then
			unlockAchievement(player, d, "cat_distract")
		end

		-- 2. 돈 벌기 (농땡이는 직급 배율을 받아요)
		local onHalfDay = daily(d).halfday == true -- 🏖️ 반차: 쉬는 중 (수입 없음, 안 들킴)
		local multiplier = if onHalfDay then 0 elseif d.state == "work" then 1 else rankOf(d).bonus
		if events:is("audit") and d.state ~= "work" then
			multiplier *= SalaryConfig.AUDIT_INCOME -- 🔍 감사 기간: 위험한 만큼 농땡이 수입 ×2
		end
		local blackout = events:is("blackout")
		if blackout and (d.state == "work" or info.screen) then
			multiplier = 0 -- 💡 정전: 컴퓨터가 꺼져서 일도, 화면 농땡이도 돈이 안 나와요
		end
		local baseIncome = info.income + (if d.state == "work" and hasCert(d, "computer") then 1 else 0) -- 💻 컴활: 일하기 +1
		d.incomeRate = baseIncome * multiplier -- 화면에 "+N원/초"로 보여 줘요
		local income = baseIncome * multiplier * dt
		d.today.earned[d.state] = (d.today.earned[d.state] or 0) + income
		d.today.seconds[d.state] = (d.today.seconds[d.state] or 0) + dt
		local catOnKeyboard = Employees.hooks.catOn ~= nil and Employees.hooks.catOn(d.desk) -- 🐾 월급냥이 키보드 위에!
		-- 📄 오늘 업무: 내 자리에 앉아만 있으면 쌓여요 (일하기든, 앉아서 하는 농땡이든) → 자연스럽게 자리로 돌아오게
		if isSeated(player, d) and not catOnKeyboard then
			d.workSeconds += dt * (if d.buffs.americano then SalaryConfig.AMERICANO_WORK else 1) -- ☕ 아메리카노
		end
		if d.state == "snack" then
			local held = d.heldSnack
			local snack = held and SalaryConfig.getSnack(held.id)
			if held and snack then
				held.progress += dt
				if held.progress >= snack.seconds then
					finishSnack(player, d)
				end
			else
				d.deskAction = "work"
			end
		end

		-- 2.6 🏋️ 체력 단련: 운동기구를 쓰는 동안 GYM_STAT_SECONDS초마다 그 기구의 스탯 +1 (서버에서만 계산)
		if d.state == "gym" then
			local machine = SalaryConfig.GymMachines[d.gymMachine or ""]
			if machine then
				d.gymSeconds = (d.gymSeconds or 0) + dt
				if (d.gymSeconds :: number) >= SalaryConfig.GYM_STAT_SECONDS then
					d.gymSeconds = (d.gymSeconds :: number) - SalaryConfig.GYM_STAT_SECONDS
					local fitness = d.profile.fitness
					local gains = {}
					for _, statId in machine.stats do
						fitness[statId] = (fitness[statId] or 0) + 1
						local stat = SalaryConfig.getFitnessStat(statId)
						if stat then
							table.insert(gains, `{stat.emoji} {stat.name} +1`)
						end
					end
					player:SetAttribute("Fitness", HttpService:JSONEncode(fitness))
					remotes.Notify:FireClient(player, `{machine.emoji} {table.concat(gains, " · ")}`)
					-- 🔮 다음 업데이트: 체력 스탯 효과는 여기(또는 fitness를 읽는 곳)에 연결해요
					--   예) 💪 근력 → ?, 🔋 지구력 → 자리 부재 게이지?, ⚡ 민첩성 → 복귀 시간? (아직 아무 효과 없음)
				end
			end
		end

		-- 2.5 🖥️ 자리 부재 게이지 (컴퓨터 자동 감지 시스템)
		--   근무 중 자리를 비우면 차오르고, 앉아 있으면 줄어요.
		--   소방 훈련·워크숍(나가야 하니까)·점심시간엔 멈춰요.
		--   💡 정전 때는 내 컴퓨터가 꺼져서 기록이 날아가요 → 0%로 초기화
		local gaugeOn = dayCycle.phase == "work" and not events:is("drill") and not events:is("workshop") and not blackout and not onHalfDay
		if blackout then
			d.away, d.awayWarned = 0, false -- 컴퓨터 꺼짐: 기록 초기화
		elseif gaugeOn and not isSeated(player, d) then
			local smoothie = if d.buffs.smoothie then SalaryConfig.SMOOTHIE_AWAY else 1 -- 🍹 에너지 스무디
			d.away = math.min(100, d.away + 100 / awayLimit(d) * smoothie * dt)
			if d.away >= SalaryConfig.AWAY_WARN and not d.awayWarned then
				d.awayWarned = true
				remotes.AwayAlert:FireClient(player)
			end
			if d.away >= 100 then
				caught(player, d, "자동 감지 시스템에 걸렸어! 자리 비우고 어디 갔었어?!")
			end
		elseif not isSeated(player, d) then
			-- 게이지가 멈춘 시간 (점심 등): 그대로 둬요
		else
			d.away = math.max(0, d.away - SalaryConfig.AWAY_RECOVER * dt)
			if d.away < SalaryConfig.AWAY_WARN - 20 then
				d.awayWarned = false
			end
		end
		if d.fired then
			return
		end

		-- 3. 의심도 (점심시간에는 부장이 없어서 안전)
		local decay = SalaryConfig.SUSPICION_DECAY * (if hasItem(d, "plant") then 1.25 else 1)
			* (if ReplicatedStorage:GetAttribute("Sunset") == true and Employees.hooks.onRoof and Employees.hooks.onRoof(root.Position) then SalaryConfig.SUNSET_DECAY else 1) -- 🌅 노을 보며 힐링
			* (if d.buffs.latte then SalaryConfig.LATTE_DECAY else 1) -- 🥛 바닐라 라떼
		if dayCycle.phase == "work" and boss.active then
			local rate = info.detect
			local coffeeGrace = if hasItem(d, "tumbler") then 90 else SalaryConfig.COFFEE_GRACE
			if d.state == "coffee" and d.coffeeTime <= coffeeGrace then
				rate = 0 -- 아직은 커피 타는 중으로 보여요
			end
			if info.screen then
				rate *= 1 - upgradeValue(d, "monitor") -- 🖥️ 좋은 모니터
			end
			if info.screen and hasItem(d, "cover") then
				rate *= 0.7
			end
			if blackout then
				rate = 0 -- 💡 정전: 깜깜해서 무슨 농땡이를 해도 안 보여요 (케이크·간식·폰·수다 전부)
			end
			if d.state == "phone" then
				rate *= SalaryConfig.PHONE_GAME_SUSPICION -- 📱 폰 게임은 느긋하게 (10배 느리게)
			end
			if onHalfDay then
				rate = 0 -- 🏖️ 반차 중엔 아무도 뭐라 안 해요
			end
			rate *= d.speed -- ⚡ 오늘의 의심도 속도 (회식·꽃다발·적발·감사관 의심… 다 여기에 들어 있어요)
			local raised = false
			if rate > 0 then
				local seen, distance = boss:canSee(character)
				if seen and blackout and distance > boss.range * 0.5 then
					seen = false -- 어두워서 멀리는 안 보여요
				end
				if seen and isSeated(player, d) and distance > boss.range - upgradeValue(d, "partition") then
					seen = false -- 🧱 높은 파티션 덕분에 멀리서는 안 보여요
				end
				local roofMultiplier = 1
				if seen and not office.insideOffice(root.Position) then
					-- 👀 사무실 밖(공원·거리 등)에서 들켰어요: 부장님이 멈춰 서서 나만 노려봐요 + 의심도 더 빨리
					boss:stare(character)
					if boss.stareAt == character then
						roofMultiplier = SalaryConfig.OUTSIDE_STARE_MULTIPLIER
					end
				end
				local sightRange = boss.range
				if not seen and Employees.hooks.guardSees then
					-- 👮 사무실 밖(옥상·공원·거리) 경비원: 보이면 멈춰 서서 나를 계속 노려봐요
					local guardStaring
					seen, distance, guardStaring, sightRange = Employees.hooks.guardSees(character)
					if seen then
						roofMultiplier = (if guardStaring then SalaryConfig.GUARD_STARE_MULTIPLIER else SalaryConfig.GUARD_DETECT_MULTIPLIER) * guardCalm(d, now)
					end
				end
				if seen then
					local closeness = math.clamp(1.5 - distance / (sightRange or boss.range), 0.5, 1.5)
					d.suspicion += rate * closeness * roofMultiplier * SalaryConfig.SUSPICION_SPEED * dt
					raised = true
				end
			end

			-- 🔔 인기척 센서: 자리에서 농땡이 중에 부장님이 가까이 오면 📳
			local sensorRange = upgradeValue(d, "sensor")
			if sensorRange > 0 and d.state ~= "work" and d.state ~= "returning" and isSeated(player, d) and now >= (d.sensorCooldownUntil or 0) then
				local bossRoot = boss.root
				if bossRoot and boss.model.Parent then
					local gap = (bossRoot.Position - root.Position).Magnitude
					if gap <= sensorRange then
						d.sensorCooldownUntil = now + SalaryConfig.SENSOR_COOLDOWN
						remotes.SensorAlert:FireClient(player, math.floor(gap))
					end
				end
			end

			-- 🤫 친한 동료(❤️❤️❤️ 이상)가 근처에 있으면 부장님이 다가올 때 "쉿! 부장님 와요"
			--   (위장 감사관은 안 알려 줘요 😏 · 쿨타임 있음)
			do
				local bossRoot = boss.root
				local gap = if bossRoot and boss.model.Parent then (bossRoot.Position - root.Position).Magnitude else nil
				local approaching = gap ~= nil and d.whisperGap ~= nil and gap < d.whisperGap - 0.05
				d.whisperGap = gap
				if approaching and rate > 0 and d.state ~= "work" and d.state ~= "returning"
					and (gap :: number) <= SalaryConfig.FRIEND_WHISPER_BOSS and now >= (d.whisperCooldownUntil or 0)
				then
					local friendship = d.profile.friendship or {}
					for _, c in coworkers.list() do
						if not c.auditor and not c.borrowed
							and SalaryConfig.friendLevel(friendship[c.name]) >= SalaryConfig.FRIEND_WHISPER_LEVEL
							and (c.root.Position - root.Position).Magnitude <= SalaryConfig.FRIEND_WHISPER_NEAR
						then
							d.whisperCooldownUntil = now + SalaryConfig.FRIEND_WHISPER_COOLDOWN
							Npc.say(c.model, "쉿! 부장님 와요!", 2)
							remotes.Notify:FireClient(player, `🤫 {c.name}: "쉿! 부장님 와요!" (친한 동료의 귓속말)`, 3)
							break
						end
					end
				end
			end

			-- 📸 감사관: 농땡이를 보면 📷 카메라를 들고 → 그때도 농땡이 중이면 찰칵!
			--   (내 자리 농땡이 + 화장실·회의실·수다만! 어슬렁·탕비실 등은 봐줘요. 일하기를 누르면 허둥지둥 복귀 중도 안전)
			if events:is("audit") and not onHalfDay then
				local deskSlacking = rate > 0
					and d.state ~= "work"
					and d.state ~= "returning"
					and (isSeated(player, d) or SalaryConfig.AUDIT_PHOTO_STATES[d.state] == true) -- 🚽📊💬도 찍혀요
				local watcher = if deskSlacking then events:auditWatcher(character) else nil
				if d.photoAimUntil then
					if now >= d.photoAimUntil then
						d.photoAimUntil = nil
						d.photoCooldownUntil = now + SalaryConfig.AUDIT_PHOTO_COOLDOWN
						-- 카메라를 이미 겨눴으니, 그때까지 농땡이 중이면 찰칵!
						--   일하기(허둥지둥 복귀 포함)만 안전. 자리를 떠서 도망가면 🪑 빈자리가 찍혀요
						local working = d.state == "work" or d.state == "returning"
						-- (어디 있는지로 판단해요: 정전·반차로 들킬 걱정이 없어진 것과 자리를 뜬 건 달라요)
						local fled = not working and not isSeated(player, d) and SalaryConfig.AUDIT_PHOTO_STATES[d.state] ~= true
						-- 👔 최고급 마네킹이 앉아 있으면 감사관이 빈자리를 나로 착각해요
						local fooled = fled and not events.auditRevealed and seatedDoll(d) == "dummy_pro"
						if fooled and d.photoWatcher then
							Npc.say(d.photoWatcher.model, "음, 열심히 일하는군… 찰칵.", 1.5)
							remotes.AuditPhoto:FireClient(player, "miss", d.today.photos or 0)
							remotes.Notify:FireClient(player, "👔 감사관이 마네킹을 나로 착각했어요! 빈자리 사진 무효")
						elseif (deskSlacking or fled) and not events.auditRevealed and d.photoWatcher then
							watcher = d.photoWatcher
							local wasReported = auditReported(d)
							local count
							if fled then
								d.today.emptyPhotos = (d.today.emptyPhotos or 0) + 1
								count = d.today.emptyPhotos
								Npc.say(watcher.model, "빈자리라… 찰칵.", 1.5)
							else
								d.today.photos = (d.today.photos or 0) + 1
								count = d.today.photos
								Npc.say(watcher.model, "찰칵.", 1.5)
							end
							remotes.AuditPhoto:FireClient(player, if fled then "empty" else "shot", count)
							adjustSpeed(player, d, "auditPhoto")
							if not wasReported and auditReported(d) then
								remotes.Notify:FireClient(
									player,
									(if fled then `🪑 빈자리 사진 {count}장!` else `📸 농땡이 사진 {count}장!`)
										.. ` 감사 보고서가 올라가요 → 퇴근 때 감봉 -{SalaryConfig.caughtPenalty(d.profile.rank)}원 + 경고 1개 (감사관 정체를 밝히면 폐기!)`
								)
							end
						else
							remotes.AuditPhoto:FireClient(player, "miss", d.today.photos or 0)
						end
					end
				elseif watcher and now >= (d.photoCooldownUntil or 0) and not auditReported(d) then -- (처벌이 정해지면 그날은 그만 찍어요)
					d.photoAimUntil = now + SalaryConfig.AUDIT_PHOTO_WINDUP
					d.photoWatcher = watcher
					events:auditAim(watcher, SalaryConfig.AUDIT_CAMERA_SHOW) -- 📷는 잠깐만 (눈치껏 봐야 해요)
					remotes.AuditPhoto:FireClient(player, "aim", d.today.photos or 0)
				end
			end

			-- 👀 이과장: 농땡이를 LEE_NOTICE초 보면 고자질
			-- (과장부터는 동급이라 이과장이 고자질하지 않아요)
			local leeSees = d.profile.rank < SalaryConfig.LEE_IGNORE_RANK and lee:sees(character)
			if leeSees and rate > 0 then
				d.leeWatch += dt
				if d.leeWatch >= SalaryConfig.LEE_NOTICE and now >= d.leeCooldownUntil then
					d.leeWatch = 0
					d.leeCooldownUntil = now + SalaryConfig.LEE_COOLDOWN
					if onHalfDay then
						-- 🏖️ 반차 중이에요
					elseif daily(d).coffee then
						lee:say("…☕ 정기권 고객님이시네~ 못 본 걸로!", 3) -- 🎟️ 커피 정기권: 오늘은 몇 번이든
						unlockAchievement(player, d, "lee_bribe")
						publishCollection(player, d)
					elseif d.leeBribed then
						d.leeBribed = false
						lee:say("…☕ 커피 값으로 못 본 걸로 할게요~", 3)
						remotes.Notify:FireClient(player, "☕ 이과장이 커피 덕분에 눈감아 줬어요! (오늘 커피 효과 끝)")
						unlockAchievement(player, d, "lee_bribe")
						publishCollection(player, d)
					else
						d.suspicion += SalaryConfig.LEE_TATTLE
						adjustSpeed(player, d, "leeTattle")
						raised = true
						lee:say(`부장님~ {player.DisplayName} 씨 또 놀아요~`, 3)
						boss:callTo(root.Position)
						remotes.Notify:FireClient(player, "😱 이과장이 고자질했어요! 부장님이 이쪽으로 와요!")
					end
				end
			elseif leeSees and d.leeWatch > 0 then
				-- 들키기 직전에 일하는 척 성공!
				d.leeWatch = 0
				unlockAchievement(player, d, "lee_dodge")
				publishCollection(player, d)
			elseif not leeSees then
				d.leeWatch = 0
			end
			-- 🤨 쉬지 않고 오래 농땡이: 안 보여도 "요즘 저 친구 뭐 하지?" 의심도가 슬금슬금
			if d.slackSince and not onHalfDay and not blackout and now - d.slackSince >= SalaryConfig.SLACK_HUNCH_AFTER then
				local hunch = SalaryConfig.SLACK_HUNCH_RATE * d.speed * SalaryConfig.SUSPICION_SPEED * 3
					* (if d.state == "phone" then SalaryConfig.PHONE_GAME_SUSPICION else 1)
				d.suspicion += hunch * dt
				raised = true
				if not d.hunchWarned then
					d.hunchWarned = true
					remotes.Notify:FireClient(player, "🤨 너무 오래 자리를 비운 느낌… 부장님이 슬슬 수상해해요! (일하기로 잠깐 돌아가면 괜찮아요)")
				end
			elseif not d.slackSince then
				d.hunchWarned = false
			end
			if not raised then
				d.suspicion = math.max(0, d.suspicion - decay * dt)
			end

			-- 4. 아슬아슬 보너스
			--   (하루 NEAR_MISS_DAILY_MAX번까지, 한 번 받으면 NEAR_MISS_COOLDOWN초 쉬어요)
			--   ① 복귀하자마자 부장님이 봤을 때  ② 의심도가 NEAR_MISS_DANGER 넘게 찼다가 안 걸리고 NEAR_MISS_SAFE 밑으로 내려왔을 때
			local function nearMissReady(): boolean
				return (d.today.nearMissCount or 0) < SalaryConfig.NEAR_MISS_DAILY_MAX
					and now - (d.lastNearMiss or -999) >= SalaryConfig.NEAR_MISS_COOLDOWN
			end
			local function awardNearMiss(label: string)
				d.lastNearMiss = now
				d.today.nearMissCount = (d.today.nearMissCount or 0) + 1
				local bonus = SalaryConfig.NEAR_MISS_BONUS * d.combo
				d.today.nearMiss += bonus
				d.profile.stats.nearMiss += 1
				remotes.NearMiss:FireClient(player, bonus, d.combo, SalaryConfig.NEAR_MISS_DAILY_MAX - d.today.nearMissCount, label)
				unlockAchievement(player, d, "near_miss")
				if d.combo >= SalaryConfig.MAX_COMBO then
					unlockAchievement(player, d, "combo_max")
				end
				publishCollection(player, d)
				d.combo = math.min(d.combo + 1, SalaryConfig.MAX_COMBO)
			end
			if
				d.state == "work"
				and not d.nearMissUsed
				and d.lastReturnEnd
				and now - d.lastReturnEnd <= SalaryConfig.NEAR_MISS_WINDOW
				and nearMissReady()
			then
				local seen, distance = boss:canSee(character)
				if seen and distance < 35 then -- (사무실이 넓어져서 25 → 35)
					d.nearMissUsed = true
					awardNearMiss("아슬아슬!")
				end
			end
			-- ② 의심도 탈출
			if d.suspicion >= SalaryConfig.NEAR_MISS_DANGER and d.suspicion < 100 then
				d.suspicionDanger = true
			elseif d.suspicionDanger and d.suspicion <= SalaryConfig.NEAR_MISS_SAFE then
				d.suspicionDanger = false
				if nearMissReady() then
					awardNearMiss("아슬아슬 탈출!")
				end
			end

			if d.suspicion >= 100 then
				guardOrBossCatch(player, d, root)
			end
		elseif dayCycle.phase == "work" and not onHalfDay and not blackout and Employees.hooks.guardSees and not office.insideOffice(root.Position) then
			-- 🎟️ 부장님이 출장 중이어도 경비원은 그대로 근무해요 (사무실 밖만)
			local rate = (info.detect or 0) * d.speed * (if d.state == "phone" then SalaryConfig.PHONE_GAME_SUSPICION else 1)
			local seen, distance, guardStaring, sightRange = false, math.huge, false, SalaryConfig.GUARD_RANGE
			if rate > 0 then
				seen, distance, guardStaring, sightRange = Employees.hooks.guardSees(character)
			end
			if seen then
				local closeness = math.clamp(1.5 - distance / (sightRange or SalaryConfig.GUARD_RANGE), 0.5, 1.5)
				local multiplier = (if guardStaring then SalaryConfig.GUARD_STARE_MULTIPLIER else SalaryConfig.GUARD_DETECT_MULTIPLIER) * guardCalm(d, now)
				d.suspicion += rate * closeness * multiplier * SalaryConfig.SUSPICION_SPEED * dt
				if d.suspicion >= 100 then
					guardOrBossCatch(player, d, root)
				end
			else
				d.suspicion = math.max(0, d.suspicion - decay * dt)
			end
		else
			d.suspicion = math.max(0, d.suspicion - decay * dt)
		end
	end

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < TICK then
			return
		end
		local step = accumulator
		accumulator = 0
		for player, d in data do
			if dayCycle.phase ~= "offwork" then
				tick(player, d, step)
			end
			publish(player, d)
		end
	end)

	---------------------------------------------------------------- ☕ 이과장 커피 상납
	lee.onBribe = function(player: Player): boolean
		local d = data[player]
		if not d or d.fired then
			return false
		end
		if d.leeBribed then
			remotes.Notify:FireClient(player, "☕ 오늘은 이미 커피를 드렸어요.")
			return false
		end
		if d.profile.money < SalaryConfig.LEE_BRIBE_COST then
			remotes.Notify:FireClient(player, `☕ 커피 살 돈이 없어요… ({SalaryConfig.LEE_BRIBE_COST}원 필요)`)
			return false
		end
		d.profile.money -= SalaryConfig.LEE_BRIBE_COST
		d.leeBribed = true
		remotes.Notify:FireClient(player, "☕ 커피 상납 완료! 오늘 이과장 고자질을 한 번 막아 줘요.")
		publish(player, d)
		return true
	end

	---------------------------------------------------------------- 🏢 스카우트 제의 수락 → 새 회사 사무실로
	---------------------------------------------------------------- 🪑 책상 배치: 산 사무용품을 놓기/치우기
	local allowDesk = RateLimit.new(0.3)
	remotes.ToggleDeskItem.OnServerEvent:Connect(function(player, itemId)
		if not allowDesk(player) then
			return
		end
		local d = data[player]
		local item = typeof(itemId) == "string" and SalaryConfig.getItem(itemId)
		if not d or not item or item.consumable or not hasItem(d, item.id) then
			return
		end
		local hidden = d.profile.deskHidden
		if hidden[item.id] then
			hidden[item.id] = nil
			-- 의자에는 인형 하나만: 다른 인형은 치워요
			if item.id == "dummy" then
				hidden.dummy_pro = if hasItem(d, "dummy_pro") then true else nil
			elseif item.id == "dummy_pro" then
				hidden.dummy = if hasItem(d, "dummy") then true else nil
			end
		else
			hidden[item.id] = true
		end
		publish(player, d)
		buildDeskItems(d)
		local isDoll = item.id == "dummy" or item.id == "dummy_pro"
		remotes.Notify:FireClient(
			player,
			if hidden[item.id]
				then `{item.emoji} {item.name}을(를) 서랍에 넣었어요.` .. (if isDoll then " (자리 비움 효과 꺼짐)" else " (효과는 그대로!)")
				else `{item.emoji} {item.name}을(를) 책상에 놓았어요.`
		)
	end)

	local function moveCompany(player: Player, d: EmployeeData): boolean
		local target = SalaryConfig.companyForRank(d.profile.rank)
		if target.id == office.companyId or d.moving then
			return false
		end
		d.moving = true
		remotes.Notify:FireClient(player, `📦 {target.name}(으)로 짐 싸서 이동 중…`)
		save(player, d) -- 이동하기 전에 꼭 저장 (새 서버가 이 저장을 읽어서 사무실을 정해요)
		-- 같은 게임(월급루팡)의 새 전용 서버로 → 들어가면 내 직급에 맞는 사무실이 지어져요
		local ok, message = Teleport.send(game.PlaceId, { player }, true)
		if ok then
			-- 텔레포트가 나중에 실패하면 (서버 혼잡 등) 다시 출근할 수 있게 풀어 줘요
			task.delay(20, function()
				if player.Parent and data[player] == d and d.moving then
					d.moving = false
					remotes.Notify:FireClient(player, "📦 이동이 늦어지고 있어요. [출근하기]를 다시 눌러 주세요.")
				end
			end)
		else
			d.moving = false
			if message then
				remotes.Notify:FireClient(player, message)
			end
		end
		return ok
	end
	remotes.MoveCompany.OnServerEvent:Connect(function(player)
		if not allowMove(player) then
			return
		end
		local d = data[player]
		if not d then
			return
		end
		if SalaryConfig.companyForRank(d.profile.rank).id == office.companyId then
			remotes.Notify:FireClient(player, "🏢 이미 지금 회사에 다니고 있어요.")
			return
		end
		moveCompany(player, d)
	end)

	---------------------------------------------------------------- 🏢 출근하기
	-- 하루가 시작되기 전, 모두 [출근하기]를 누를 때까지 기다려요.
	-- 여럿이면: 누군가 누른 뒤 CLOCKIN_WAIT초가 지나면 나머지를 기다리지 않아요 (자리 비운 사람 때문에 멈추지 않게)
	dayCycle.readyGate = function()
		for player, d in data do
			d.ready = false
			player:SetAttribute("ClockedIn", false)
		end
		local firstReadyAt: number? = nil
		while true do
			task.wait(0.25)
			local total, ready = 0, 0
			for _, d in data do
				total += 1
				if d.ready then
					ready += 1
				end
			end
			ReplicatedStorage:SetAttribute("ClockInCount", `{ready}/{total}`)
			if total > 0 and ready == total then
				break
			end
			if ready > 0 then
				firstReadyAt = firstReadyAt or os.clock()
				ReplicatedStorage:SetAttribute("ClockInLeft", math.max(0, math.ceil(SalaryConfig.CLOCKIN_WAIT - (os.clock() - (firstReadyAt :: number)))))
				if os.clock() - (firstReadyAt :: number) >= SalaryConfig.CLOCKIN_WAIT then
					break
				end
			else
				firstReadyAt = nil
				ReplicatedStorage:SetAttribute("ClockInLeft", -1)
			end
		end
		ReplicatedStorage:SetAttribute("ClockInLeft", -1)
	end
	remotes.ClockIn.OnServerEvent:Connect(function(player)
		local d = data[player]
		if d and dayCycle.waiting then
			-- 📦 내 회사에 다니다가 진급/좌천으로 회사가 바뀌었으면 → 출근할 때 새 회사로 이동
			-- (친구를 따라 다른 회사 서버에 온 경우는 그대로 같이 일해요)
			-- (해고로 직급이 내려간 다음 날도 출근 전엔 아직 fired 표시가 남아 있어서 fired는 보지 않아요 · 스튜디오는 텔레포트가 안 돼서 건너뛰어요)
			if d.homeOffice and not RunService:IsStudio() and SalaryConfig.companyForRank(d.profile.rank).id ~= office.companyId then
				if allowMove(player) and moveCompany(player, d) then
					return
				end
			end
			if d.moving then
				return
			end
			d.ready = true
			player:SetAttribute("ClockedIn", true)
		end
	end)

	---------------------------------------------------------------- 🌸 워크숍
	events.canJoinWorkshop = function(player: Player): boolean
		local d = data[player]
		return d ~= nil and not d.fired
	end
	events.onWorkshopFinish = function(player: Player, place: number)
		local d = data[player]
		if not d then
			return
		end
		local bonus = SalaryConfig.WORKSHOP_BONUS + (if place == 1 then SalaryConfig.WORKSHOP_FIRST_BONUS else 0)
		d.today.eventBonus += bonus
		remotes.Bonus:FireClient(player, if place == 1 then "🌸 무궁화 1등!" else `🌸 골인! ({place}등)`, bonus)
		if place == 1 then
			adjustSpeed(player, d, "workshopWin")
			unlockAchievement(player, d, "workshop_winner")
			publishCollection(player, d)
		end
	end

	---------------------------------------------------------------- 🏙️ 눈치 스트리트 가게에서 사기 (Street 모듈이 불러요)
	function Employees.buyStreet(player: Player, shopId: string, itemId: string): (boolean, string)
		local d = data[player]
		local item = SalaryConfig.getStreetItem(shopId, itemId)
		if not d or d.fired or not item then
			return false, "지금은 살 수 없어요."
		end
		if d.profile.money < item.price then
			return false, `통장 잔고가 부족해요. 😢 ({item.price}원 필요)`
		end
		if item.gift then
			if d.heldGift then
				return false, "🎁 들고 있는 선물부터 부장님께 드려요! (한 번에 하나만)"
			end
			d.heldGift = item.id
		elseif item.snack then
			if d.heldSnack then
				return false, "🍪 들고 있는 간식부터 먹어요! (한 번에 하나만)"
			end
			d.heldSnack = { id = item.snack, progress = 0 }
		else
			if d.buffs[item.id] then
				return false, `{item.emoji} 오늘은 이미 마셨어요! 내일 또 와요.`
			end
			d.buffs[item.id] = true
			unlockAchievement(player, d, "street_cafe")
			publishCollection(player, d)
		end
		d.profile.money -= item.price
		publish(player, d)
		task.spawn(save, player, d)
		if item.gift then
			return true, `{item.emoji} {item.name} 포장 완료! 부장님께 다가가 [E]로 드려요.`
		end
		if item.snack then
			return true, `{item.emoji} {item.name} 포장 완료! 자리에서 [8]로 몰래 먹어요.`
		end
		return true, `{item.emoji} {item.name} 꿀꺽! {item.description}`
	end

	---------------------------------------------------------------- 🧸 인형뽑기 (Claw 모듈이 불러요)
	function Employees.chargeClaw(player: Player, price: number): (boolean, string)
		local d = data[player]
		if not d or d.fired then
			return false, "지금은 할 수 없어요."
		end
		if d.profile.money < price then
			return false, `통장 잔고가 부족해요. 😢 ({price}원 필요)`
		end
		d.profile.money -= price
		publish(player, d)
		return true, ""
	end

	function Employees.givePlush(player: Player, plushId: string)
		local d = data[player]
		local plush = SalaryConfig.getPlush(plushId)
		if not d or not plush then
			return
		end
		d.profile.plushies[plushId] = (d.profile.plushies[plushId] or 0) + 1
		unlockAchievement(player, d, "first_plush")
		if plush.rarity == "legend" then
			unlockAchievement(player, d, "legend_plush")
		end
		if plushId == "dragon" then
			unlockAchievement(player, d, "dragon_plush")
		end
		local all = true
		for _, info in SalaryConfig.Plushies do
			if not d.profile.plushies[info.id] then
				all = false
			end
		end
		if all then
			unlockAchievement(player, d, "plush_all")
		end
		publishCollection(player, d)
		publishPlushies(player, d)
		task.spawn(save, player, d)
	end

	---------------------------------------------------------------- 🕹️ 오락실 (Arcade 모듈이 불러요)
	-- 점수 → 티켓 지급, 최고 기록 갱신. (최고 점수, 새 기록인지) 를 돌려줘요
	function Employees.rewardArcade(player: Player, gameId: string, score: number, tickets: number): (number, boolean)
		local d = data[player]
		if not d then
			return score, false
		end
		local profile = d.profile
		profile.tickets += tickets
		local best = profile.arcadeBest[gameId] or 0
		local isBest = score > best
		if isBest then
			profile.arcadeBest[gameId] = score
			best = score
		end
		unlockAchievement(player, d, "arcade_first")
		if (gameId == "mole" and score >= 30) or (gameId == "memory" and score >= 24) then
			unlockAchievement(player, d, "arcade_champ")
		end
		publishCollection(player, d)
		publishPlushies(player, d)
		task.spawn(save, player, d)
		return best, isBest
	end

	---------------------------------------------------------------- 🎡 돌림판 / 🎯 풍선 다트 (Wheel, Dart 모듈이 불러요)
	-- 🎡 돌림판 베팅 취소 → 건 돈 그대로 돌려주기
	function Employees.refundMoney(player: Player, amount: number)
		local d = data[player]
		if d then
			d.profile.money += amount
			publish(player, d)
		end
	end

	-- 📱 폰 게임 농땡이 중인가? (내 자리에 앉아서 [폰 게임]을 고른 상태)
	function Employees.isPhoneGaming(player: Player): boolean
		local d = data[player]
		return d ~= nil
			and not d.fired
			and dayCycle.phase ~= "offwork"
			and d.deskAction == "phone"
			and d.returnUntil == nil
			and isSeated(player, d)
	end

	-- 지금 직급 번호 (없으면 1)
	function Employees.rankOf(player: Player): number
		local d = data[player]
		return if d then d.profile.rank else 1
	end

	-- 📱 폰 게임 상태: "playing" 게임 중 / "returning" 내가 일하기를 눌러 복귀 중 / "off" 적발·자리 이탈 등
	function Employees.phoneGameStatus(player: Player): string
		local d = data[player]
		if not d or d.fired or d.deskAction ~= "phone" or not isSeated(player, d) then
			return "off"
		end
		if dayCycle.phase == "offwork" then
			return "returning" -- 🕕 퇴근 시간: 하던 판은 자동 스톱 (돈을 잃지 않게)
		end
		return if d.returnUntil then "returning" else "playing"
	end

	-- 🧩 도형 맞추기 상금 (하루 SHAPES_DAILY_PRIZES번까지) → (준 돈, 오늘 남은 횟수)
	function Employees.payShapes(player: Player, amount: number): (number, number)
		local d = data[player]
		if not d then
			return 0, 0
		end
		local used = daily(d).shapesPrizes or 0
		if used >= SalaryConfig.SHAPES_DAILY_PRIZES then
			return 0, 0
		end
		daily(d).shapesPrizes = used + 1
		d.profile.money += amount
		publish(player, d)
		task.spawn(save, player, d)
		return amount, SalaryConfig.SHAPES_DAILY_PRIZES - daily(d).shapesPrizes
	end

	-- ⚾ 숫자 야구 상금 (하루 BASEBALL_DAILY_PRIZES번까지) → (준 돈, 오늘 남은 횟수)
	function Employees.payBaseball(player: Player, amount: number): (number, number)
		local d = data[player]
		if not d then
			return 0, 0
		end
		local used = daily(d).baseballPrizes or 0
		if used >= SalaryConfig.BASEBALL_DAILY_PRIZES then
			return 0, 0
		end
		daily(d).baseballPrizes = used + 1
		d.profile.money += amount
		publish(player, d)
		task.spawn(save, player, d)
		return amount, SalaryConfig.BASEBALL_DAILY_PRIZES - daily(d).baseballPrizes
	end

	-- 💣 폰 게임 당첨금 → 통장으로 바로 (도박이라 경력·실적 목표에는 안 들어가요)
	function Employees.payPhoneGame(player: Player, amount: number, multiplier: number)
		local d = data[player]
		if not d or amount <= 0 then
			return
		end
		d.profile.money += amount
		if multiplier >= 10 then
			for _, other in Players:GetPlayers() do
				remotes.Notify:FireClient(other, `💣 {player.DisplayName} 님이 지뢰 피하기 x{string.format("%.1f", multiplier)} 대박! +{amount}원`)
			end
		end
		publish(player, d)
		task.spawn(save, player, d)
	end

	function Employees.payWheel(player: Player, amount: number, number: number)
		local d = data[player]
		if not d then
			return
		end
		d.profile.money += amount -- 도박 당첨금은 경력(승진)에는 안 들어가요
		if number == 20 then
			unlockAchievement(player, d, "wheel_20")
			publishCollection(player, d)
			for _, other in Players:GetPlayers() do
				remotes.Notify:FireClient(other, `🎡 {player.DisplayName} 님이 돌림판 20 대박! +{amount}원`)
			end
		end
		publish(player, d)
		task.spawn(save, player, d)
	end

	-- 🎯 풍선 다트: 터뜨린 풍선 경품을 지급 → 화면에 보여 줄 이름들 (같은 순서)
	--   prizeIds 예) { "won300" } / { "jackpot" } / { "legend" } (꽝은 빈 이름)
	function Employees.dartPrize(player: Player, prizeIds: { string }): { string }
		local names = {}
		local d = data[player]
		if not d then
			return names
		end
		local money, tickets, gotPlush = 0, 0, false
		for i, prizeId in prizeIds do
			local info = SalaryConfig.getDartPrize(prizeId)
			names[i] = ""
			if prizeId == "legend" then
				local legends = {}
				for _, plush in SalaryConfig.Plushies do
					if plush.rarity == "legend" then
						table.insert(legends, plush)
					end
				end
				local plush = legends[math.random(1, #legends)]
				Employees.givePlush(player, plush.id)
				unlockAchievement(player, d, "dart_legend")
				gotPlush = true
				names[i] = `🌟 전설 인형 {plush.emoji} {plush.name}!!`
			elseif info and info.money then
				money += info.money
				names[i] = info.name
				if info.jackpot then
					for _, other in Players:GetPlayers() do
						remotes.Notify:FireClient(other, `🎯 {player.DisplayName} 님이 풍선 다트 대박 풍선을 터뜨렸어요! +{info.money}원`)
					end
				end
			elseif info and info.tickets then
				tickets += info.tickets
				names[i] = info.name
			elseif info and info.plush then
				local plush = SalaryConfig.rollClawPlush()
				Employees.givePlush(player, plush.id)
				gotPlush = true
				names[i] = `🧸 {plush.emoji} {plush.name}`
			end
		end
		if money > 0 then
			d.profile.money += money -- 도박 당첨금이라 경력(승진)에는 안 들어가요
			publish(player, d)
		end
		if tickets > 0 then
			d.profile.tickets += tickets
			publishPlushies(player, d)
		end
		if gotPlush then
			publishCollection(player, d) -- (인형은 givePlush가 저장해요. 🏆 전설 업적도 바로 보이게)
		end
		if money > 0 or tickets > 0 then
			task.spawn(save, player, d)
		end
		return names
	end

	-- 🎟️ 경품 교환
	function Employees.exchangeArcade(player: Player, prizeId: string): (boolean, string)
		local d = data[player]
		local prize = nil
		for _, info in SalaryConfig.ArcadePrizes do
			if info.id == prizeId then
				prize = info
			end
		end
		if not d or not prize then
			return false, "없는 경품이에요."
		end
		if d.profile.tickets < prize.tickets then
			return false, `🎟️ 티켓이 부족해요. ({prize.tickets}장 필요, 지금 {d.profile.tickets}장)`
		end
		local message = ""
		if prize.id == "coffee" then
			if d.buffs.americano then
				return false, "☕ 오늘은 이미 아메리카노를 마셨어요!"
			end
			d.buffs.americano = true
			message = "☕ 아메리카노 꿀꺽! 오늘 업무 시간이 1.3배 빨리 채워져요"
		elseif prize.id == "plush" then
			local plush = SalaryConfig.rollClawPlush()
			d.profile.tickets -= prize.tickets
			Employees.givePlush(player, plush.id)
			return true, `🧸 {plush.emoji} {plush.name} 획득!`
		elseif prize.id == "dragon" then
			d.profile.tickets -= prize.tickets
			Employees.givePlush(player, "dragon")
			return true, "🐲 용용이 입양 완료! 🧸 버튼에서 책상에 진열해 보세요"
		end
		d.profile.tickets -= prize.tickets
		publishPlushies(player, d)
		publish(player, d)
		task.spawn(save, player, d)
		return true, message
	end

	-- 책상 진열 켜기/끄기 (가진 인형만, 최대 3개)
	remotes.SetDeskPlush.OnServerEvent:Connect(function(player, plushId)
		local d = data[player]
		if not d or not allowDeskPlush(player) or typeof(plushId) ~= "string" then
			return
		end
		if not SalaryConfig.getPlush(plushId) or not d.profile.plushies[plushId] then
			return
		end
		local list = d.profile.deskPlushies
		local index = table.find(list, plushId)
		if index then
			table.remove(list, index)
		elseif #list < SalaryConfig.DESK_PLUSH_MAX then
			table.insert(list, plushId)
		else
			remotes.Notify:FireClient(player, `🧸 책상에는 {SalaryConfig.DESK_PLUSH_MAX}개까지만 놓을 수 있어요. 하나를 먼저 내려요.`)
			return
		end
		buildDeskPlushies(d)
		publishPlushies(player, d)
		task.spawn(save, player, d)
	end)

	---------------------------------------------------------------- 🐱 사무실 고양이 (Cat 모듈이 불러요)
	Employees.catHooks = {
		-- [E] 쓰다듬기: 의심도 감소 (사람마다 쿨타임)
		pet = function(player: Player): boolean
			local d = data[player]
			if not d then
				return false
			end
			local now = os.clock()
			if now < d.petCooldown then
				remotes.Notify:FireClient(player, `🐱 월급냥이 귀찮아해요… {math.ceil(d.petCooldown - now)}초 뒤에 다시`)
				return false
			end
			d.petCooldown = now + SalaryConfig.CAT_PET_COOLDOWN
			d.suspicion = math.max(0, d.suspicion - SalaryConfig.CAT_PET_RELIEF)
			d.profile.catPets += 1
			remotes.Notify:FireClient(player, `😺 골골골… 힐링! 의심도 -{SalaryConfig.CAT_PET_RELIEF} (쓰다듬은 횟수 {d.profile.catPets})`)
			if d.profile.catPets >= 10 then
				unlockAchievement(player, d, "cat_lover")
				publishCollection(player, d)
			end
			publish(player, d)
			return true
		end,
		-- 사람이 앉아 일하는 책상들 (월급냥이 키보드 위에 앉을 곳)
		occupiedDesks = function()
			local list = {}
			for player, d in data do
				if not d.fired then
					table.insert(list, { desk = d.desk, player = player })
				end
			end
			return list
		end,
	}

	---------------------------------------------------------------- 🏢 옥상 / 🚪 엘리베이터 (Rooftop 모듈이 불러요)
	---------------------------------------------------------------- 🌱 옥상 텃밭 (RoofGarden 모듈이 불러요)
	local function ensureGarden(profile)
		for i = 1, SalaryConfig.GARDEN_SLOTS do
			if typeof(profile.garden[i]) ~= "table" then
				profile.garden[i] = { seed = "", growth = 0, watered = -1, missed = 0 }
			end
		end
	end
	-- action: "plant"(씨앗 ID) / "water" / "sell" / "gift" / "clear"
	function Employees.gardenAction(player: Player, action: string, slotIndex: number, arg: any): (boolean, string)
		local d = data[player]
		if not d then
			return false, "잠시 후 다시 해 주세요."
		end
		local profile = d.profile
		ensureGarden(profile)
		local slot = profile.garden[slotIndex]
		if not slot then
			return false, "그 화분은 없어요."
		end
		local today = profile.stats.days
		local seed = SalaryConfig.getSeed(slot.seed)
		local message = ""
		if action == "plant" then
			if slot.seed ~= "" then
				return false, "이미 뭔가 자라고 있어요."
			end
			local newSeed = SalaryConfig.getSeed(if typeof(arg) == "string" then arg else "")
			if not newSeed then
				return false, "씨앗을 골라 주세요."
			end
			if profile.money < newSeed.price then
				return false, `통장 잔고가 부족해요. 😢 ({newSeed.price}원 필요)`
			end
			profile.money -= newSeed.price
			profile.garden[slotIndex] = { seed = newSeed.id, growth = 0, watered = -1, missed = 0 }
			message = `🌱 {newSeed.emoji} {newSeed.name} 씨앗을 심었어요! 매일 💧 물을 주면 {newSeed.days}일 뒤 수확`
		elseif action == "water" then
			if not seed or slot.missed >= 2 then
				return false, "물 줄 식물이 없어요."
			end
			if slot.growth >= seed.days then
				return false, "다 자랐어요! 🧺 수확하세요."
			end
			if slot.watered == today then
				return false, "💧 오늘은 이미 물을 줬어요. 내일 또 와요!"
			end
			slot.watered = today
			message = `💧 {seed.emoji} {seed.name}에 물을 줬어요! 퇴근하면 자라요`
		elseif action == "sell" or action == "gift" then
			if not seed or slot.growth < seed.days or slot.missed >= 2 then
				return false, "아직 수확할 수 없어요."
			end
			if action == "gift" then
				if d.heldGift then
					return false, "🎁 들고 있는 선물부터 부장님께 드려요! (한 번에 하나만)"
				end
				d.heldGift = `veggie_{seed.id}`
				message = `🎁 {seed.emoji} {seed.name}을(를) 챙겼어요! 부장님께 [E] 드리면 오늘의 의심도 속도 {SalaryConfig.GARDEN_GIFT_DELTA}`
			else
				profile.money += seed.sell -- (텃밭 수익은 경력·실적 목표에는 안 들어가요)
				message = `💰 {seed.emoji} {seed.name}을(를) 팔았어요! +{seed.sell}원`
			end
			profile.harvests += 1
			unlockAchievement(player, d, "garden_first")
			if seed.id == "strawberry" then
				unlockAchievement(player, d, "garden_strawberry")
			end
			profile.garden[slotIndex] = { seed = "", growth = 0, watered = -1, missed = 0 }
		elseif action == "clear" then
			if slot.seed == "" then
				return false, "빈 화분이에요."
			end
			profile.garden[slotIndex] = { seed = "", growth = 0, watered = -1, missed = 0 }
			message = "🧹 화분을 비웠어요."
		else
			return false, "잘못된 요청이에요."
		end
		publishCollection(player, d)
		publish(player, d)
		task.spawn(save, player, d)
		return true, message
	end

	-- 퇴근할 때 자라요: 오늘 물을 줬으면 +1일, 안 줬으면 시들고(1) → 이틀 연속이면 말라 죽어요(2)
	local function growGarden(d: EmployeeData)
		local profile = d.profile
		ensureGarden(profile)
		local today = profile.stats.days
		for _, slot in profile.garden do
			local seed = SalaryConfig.getSeed(slot.seed)
			if seed and slot.missed < 2 and slot.growth < seed.days then
				if slot.watered == today then
					slot.growth += 1
					slot.missed = 0
				else
					slot.missed += 1
				end
			end
		end
	end

	Employees.roofHooks = {
		useGuardGift = function(player: Player, giftId: string): boolean
			return Employees.useGuardGift(player, giftId)
		end,
		-- 🏀 옥상 농구 상금 (하루 HOOP_DAILY_PRIZES번까지) → (준 돈, 남은 횟수)
		hoopPrize = function(player: Player, amount: number): (number, number)
			local d = data[player]
			if not d then
				return 0, 0
			end
			local used = daily(d).hoopPrizes or 0
			if used >= SalaryConfig.HOOP_DAILY_PRIZES then
				return 0, 0
			end
			daily(d).hoopPrizes = used + 1
			d.profile.money += amount
			publish(player, d)
			task.spawn(save, player, d)
			return amount, SalaryConfig.HOOP_DAILY_PRIZES - daily(d).hoopPrizes
		end,
		-- 🌅 노을을 충분히 감상했어요 (하루 한 번) → 의심도 0 + 오늘의 의심도 속도 ↓
		sunsetWatched = function(player: Player): boolean
			local d = data[player]
			if not d or d.fired or daily(d).sunset then
				return false
			end
			daily(d).sunset = true
			d.suspicion = 0
			adjustSpeed(player, d, "sunset", false, SalaryConfig.SUNSET_DELTA, "🌅 노을 보며 힐링")
			unlockAchievement(player, d, "sunset_watch")
			publishCollection(player, d)
			publish(player, d)
			return true
		end,
		-- 📸 노을 사진 → (오늘 첫 장인가, 앨범 장수, 상금)
		sunsetPhoto = function(player: Player): (boolean, number, number)
			local d = data[player]
			if not d then
				return false, 0, 0
			end
			unlockAchievement(player, d, "sunset_photo")
			if daily(d).sunsetPhoto then
				publishCollection(player, d)
				return false, d.profile.sunsetPhotos, 0
			end
			daily(d).sunsetPhoto = true
			d.profile.sunsetPhotos += 1
			d.profile.money += SalaryConfig.SUNSET_PHOTO_PRIZE
			if d.profile.sunsetPhotos >= 5 then
				unlockAchievement(player, d, "sunset_album")
			end
			publishCollection(player, d)
			publish(player, d)
			task.spawn(save, player, d)
			return true, d.profile.sunsetPhotos, SalaryConfig.SUNSET_PHOTO_PRIZE
		end,
		-- 🔭 관찰 일지에 장면 기록 → (처음인가, 보상)
		sceneFound = function(player: Player, sceneId: string): (boolean, number)
			local d = data[player]
			local scene = SalaryConfig.getScopeScene(sceneId)
			if not d or not scene or d.profile.scenes[sceneId] then
				return false, 0
			end
			d.profile.scenes[sceneId] = true
			local reward = SalaryConfig.ScopeRewards[scene.rarity] or 0
			d.profile.money += reward
			local count = 0
			for _ in d.profile.scenes do
				count += 1
			end
			unlockAchievement(player, d, "scope_first")
			if count >= 10 then
				unlockAchievement(player, d, "scope_ten")
			end
			if count >= #SalaryConfig.ScopeScenes then
				unlockAchievement(player, d, "scope_all")
			end
			publishCollection(player, d)
			publish(player, d)
			task.spawn(save, player, d)
			return true, reward
		end,
		gardenAction = function(player: Player, action: string, slotIndex: number, arg: any): (boolean, string)
			return Employees.gardenAction(player, action, slotIndex, arg)
		end,
		-- ✈️ 종이비행기 상금 (하루 PLANE_DAILY_PRIZES번까지) → (준 돈, 오늘 남은 횟수)
		planePrize = function(player: Player, amount: number): (number, number)
			local d = data[player]
			if not d then
				return 0, 0
			end
			local used = daily(d).planePrizes or 0
			if used >= SalaryConfig.PLANE_DAILY_PRIZES then
				return 0, 0
			end
			daily(d).planePrizes = used + 1
			d.profile.money += amount
			publish(player, d)
			task.spawn(save, player, d)
			return amount, SalaryConfig.PLANE_DAILY_PRIZES - daily(d).planePrizes
		end,
		-- ✈️ 되돌아온 종이비행기가 👮 옥상 경비원 머리에 꽂혔어요! (경비원이 부장님께 일러요)
		planeBossHit = function(player: Player)
			local d = data[player]
			if not d or d.fired then
				return
			end
			unlockAchievement(player, d, "plane_boss")
			publishCollection(player, d)
			d.suspicion = math.min(99, d.suspicion + SalaryConfig.PLANE_BOSS_HIT_SUSPICION)
			remotes.Notify:FireClient(player, `🤕 경비원: "이거 누구 보고서예요?! 부장님께 말씀드려야겠네~" 의심도 +{SalaryConfig.PLANE_BOSS_HIT_SUSPICION}`)
			publish(player, d)
		end,
		-- ✈️ 내 최고 기록 → (새 기록인가, 최고 기록)
		planeBest = function(player: Player, distance: number): (boolean, number)
			local d = data[player]
			if not d then
				return false, 0
			end
			local rounded = math.floor(distance)
			if rounded > d.profile.planeBest then
				d.profile.planeBest = rounded
				task.spawn(save, player, d)
				return true, rounded
			end
			return false, d.profile.planeBest
		end,
		-- 🐦 비둘기 모이 값
		charge = function(player: Player, price: number): (boolean, string)
			return Employees.chargeClaw(player, price)
		end,
		-- 🐦 모이를 줬어요 → 친밀도 +1
		pigeonFed = function(player: Player): number
			local d = data[player]
			if not d then
				return 0
			end
			d.profile.pigeonFeeds += 1
			d.pigeonFedToday = true
			unlockAchievement(player, d, "pigeon_friend")
			publishCollection(player, d)
			publish(player, d)
			task.spawn(save, player, d)
			return d.profile.pigeonFeeds
		end,
		-- 🐦 비둘기를 만났어요 → 관찰 노트 (처음이면 true)
		pigeonSeen = function(player: Player, pigeonId: string): boolean
			local d = data[player]
			if not d then
				return false
			end
			local first = (d.profile.pigeons[pigeonId] or 0) == 0
			d.profile.pigeons[pigeonId] = (d.profile.pigeons[pigeonId] or 0) + 1
			if pigeonId == "white" then
				unlockAchievement(player, d, "pigeon_white")
			elseif pigeonId == "crown" or pigeonId == "rainbow" then
				unlockAchievement(player, d, "pigeon_legend")
			end
			local all = true
			for _, kind in SalaryConfig.Pigeons do
				if (d.profile.pigeons[kind.id] or 0) == 0 then
					all = false
				end
			end
			if all then
				unlockAchievement(player, d, "pigeon_all")
			end
			publishCollection(player, d)
			publish(player, d)
			return first
		end,
		-- 🚪 엘리베이터 미니게임 실패 → 의심도 + (100이 되면 적발)
		stare = function(player: Player, line: string)
			local d = data[player]
			if not d or d.fired then
				return
			end
			if daily(d).halfday then
				return -- 🏖️ 반차 중
			end
			d.suspicion += SalaryConfig.ELEVATOR_FAIL
			adjustSpeed(player, d, "elevatorFail")
			publish(player, d)
			if d.suspicion >= 100 then
				caught(player, d, line, true)
			end
		end,
		ninja = function(player: Player): number
			local d = data[player]
			if not d then
				return 0
			end
			d.profile.elevatorNinja += 1
			adjustSpeed(player, d, "elevatorNinja")
			task.spawn(save, player, d)
			return d.profile.elevatorNinja
		end,
		unlock = function(player: Player, achievementId: string)
			local d = data[player]
			if d then
				unlockAchievement(player, d, achievementId)
				publishCollection(player, d)
			end
		end,
	}

	---------------------------------------------------------------- 🪑 내 자리 꾸미기 (Decor 모듈이 불러요)
	Employees.decorApi = {
		hooks = Employees.hooks,
		get = function(player: Player): EmployeeData?
			return data[player]
		end,
		list = function()
			return data
		end,
		charge = function(player: Player, price: number): (boolean, string)
			return Employees.chargeClaw(player, price)
		end,
		unlock = function(player: Player, d: EmployeeData, achievementId: string)
			unlockAchievement(player, d, achievementId)
			publishCollection(player, d)
		end,
		save = function(player: Player, d: EmployeeData)
			task.spawn(save, player, d)
		end,
	}

	---------------------------------------------------------------- 📋 긴급 프로젝트 / 🎁 선물 (Missions 모듈이 불러요)
	Employees.missionApi = {
		get = function(player: Player): EmployeeData?
			return data[player]
		end,
		isSeated = function(player: Player): boolean
			local d = data[player]
			return d ~= nil and isSeated(player, d)
		end,
		-- 성공 보상: 경고가 있으면 -1, 없으면 보너스
		-- 📚 자격증 특전: 🏯 한국사 = 퀴즈 오답 한 번 더 / 📊 엑셀 = 제한 시간 +20초
		quizBonus = function(player: Player): number
			local d = data[player]
			return if d and hasCert(d, "history") then 1 else 0
		end,
		-- 🤝 이 동료와 친밀도 ❤️ 개수 (결재 도장 단짝 보너스)
		friendLevel = function(player: Player, name: string): number
			local d = data[player]
			return if d then SalaryConfig.friendLevel(friendPoints(d, name)) else 0
		end,
		timeBonus = function(player: Player): number
			local d = data[player]
			return if d and hasCert(d, "excel") then 20 else 0
		end,
		-- 📋 프로젝트 실패 → 부장님 눈이 더 날카로워져요
		failed = function(player: Player)
			local d = data[player]
			if d and not d.fired then
				adjustSpeed(player, d, "missionFail")
			end
		end,
		reward = function(player: Player, missionId: string): string
			local d = data[player]
			if not d then
				return ""
			end
			local profile = d.profile
			local text
			if profile.warnings > 0 then
				profile.warnings -= 1
				text = `경고 -1! (남은 경고 {profile.warnings}/{SalaryConfig.MAX_WARNINGS})`
			else
				d.today.eventBonus += SalaryConfig.MISSION_BONUS
				text = `보너스 +{SalaryConfig.MISSION_BONUS}원 (퇴근 때 지급)`
			end
			profile.missionsDone[missionId] = true
			adjustSpeed(player, d, "missionSuccess")
			unlockAchievement(player, d, "mission_clear")
			local all = true
			for id, mission in SalaryConfig.Missions do
				if not mission.company and not profile.missionsDone[id] then
					all = false -- (회사 전용 미션은 빼고 세요)
				end
			end
			if all then
				unlockAchievement(player, d, "mission_master")
			end
			publishCollection(player, d)
			publish(player, d)
			task.spawn(save, player, d)
			return text
		end,
		-- 🎁 들고 있는 선물을 부장님께 드리기 → (드렸는지, 부장님 대사, 안내 문구)
		giveGift = function(player: Player): (boolean, string, string)
			local d = data[player]
			if not d or not d.heldGift then
				return false, "", ""
			end
			local giftId = d.heldGift :: string
			local profile = d.profile
			if giftId == "hongsam" then
				-- 🎁 하루에 한 번만 (예전엔 '5일에 한 번'이었는데, 서버가 바뀌면 날짜가 꼬여서 하루 단위로 바꿨어요)
				if daily(d).hongsam then
					return false, "허허, 오늘 벌써 받았잖아~ 내일 줘.", "🎁 홍삼은 하루에 한 번만 통해요."
				end
				daily(d).hongsam = true
				profile.lastHongsamDay = dayCycle.day
				d.heldGift = nil
				local text
				if profile.warnings > 0 then
					profile.warnings -= 1
					unlockAchievement(player, d, "gift_hongsam")
					publishCollection(player, d)
					text = `🎁 경고 -1! (남은 경고 {profile.warnings}/{SalaryConfig.MAX_WARNINGS})`
				else
					reserveSpeed(d, "hongsam")
					text = `🎁 경고가 없어서 대신 내일 의심도 속도 {SalaryConfig.SpeedFactors.hongsam.delta}`
				end
				publish(player, d)
				task.spawn(save, player, d)
				return true, "어허, 뭘 이런 걸 다~ 😊 (홍삼 최고지)", text
			elseif giftId == "flowers" then
				d.heldGift = nil
				adjustSpeed(player, d, "flowers")
				publish(player, d)
				return true, "오~ 꽃이네? 사무실이 환해졌어 💐", `💐 오늘 의심도 속도 {SalaryConfig.SpeedFactors.flowers.delta}`
			elseif string.match(giftId, "^veggie_") then
				-- 🥬 직접 기른 채소 → 오늘의 의심도 속도 ↓
				local seed = SalaryConfig.getSeed(string.match(giftId, "^veggie_(.+)$") or "")
				d.heldGift = nil
				adjustSpeed(player, d, "veggie", false, SalaryConfig.GARDEN_GIFT_DELTA, `{if seed then seed.emoji else "🥬"} 직접 기른 채소 선물`)
				unlockAchievement(player, d, "garden_gift")
				publishCollection(player, d)
				publish(player, d)
				local name = if seed then seed.name else "채소"
				return true, `오~ {name}? 직접 길렀다고? 건강하네! 🌱`, `🥬 오늘의 의심도 속도 {SalaryConfig.GARDEN_GIFT_DELTA}`
			elseif giftId == "choco" then
				d.heldGift = nil
				d.suspicion = math.max(0, d.suspicion - SalaryConfig.CHOCO_SUSPICION)
				adjustSpeed(player, d, "choco")
				publish(player, d)
				return true, "초콜릿? 당 떨어졌는데 잘됐네 🍫", `🍫 의심도 -{SalaryConfig.CHOCO_SUSPICION}`
			end
			return false, "", ""
		end,
	}

	---------------------------------------------------------------- 🍻 회식 (Dinner 모듈이 불러요)
	function Employees.dinnerParticipants(): { Player }
		local list = {}
		for player, d in data do
			if not d.fired then
				table.insert(list, player)
			end
		end
		return list
	end
	function Employees.dinnerReward(player: Player, score: number)
		local d = data[player]
		if not d then
			return
		end
		local mood = if score >= 6 then 0.75 elseif score >= 3 then 0.9 elseif score <= -2 then 1.15 else 1
		d.bossMood = mood
		d.bossMoodDay = dayCycle.day + 1
		if mood ~= 1 then
			reserveSpeed(d, "dinner", mood - 1) -- 🍻 내일 아침 의심도 속도에 반영 (0.75 → -0.25)
		end
		local bonus = math.max(0, score) * SalaryConfig.DINNER_POINT
		if bonus > 0 then
			d.profile.money += bonus
			d.profile.xp += bonus
			remotes.Bonus:FireClient(player, `🍻 회식 점수 {score}점!`, bonus)
		end
		if score >= 6 then
			unlockAchievement(player, d, "dinner_ace")
			publishCollection(player, d)
		end
		remotes.Dinner:FireClient(player, "end", score, mood)
		publish(player, d)
		task.spawn(save, player, d)
	end

	---------------------------------------------------------------- 🎲 돌발 이벤트 연결
	events.snacks = snacks
	events.notifyAll = function(message: string, officeOnly: boolean?)
		for player in data do
			if officeOnly and not Employees.inOffice(player) then
				continue -- 사무실 밖(옥상·공원·거리)에 있으면 사무실 소식은 안 보내요
			end
			remotes.Notify:FireClient(player, message)
		end
	end
	-- 🚒 소방 훈련 인원 점검: 집결지에 있으면 보너스, 없으면 경고
	events.onDrillCheck = function(isInZone: (Vector3) -> boolean)
		for player, d in data do
			if d.fired then
				continue
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and isInZone(root.Position) then
				d.today.eventBonus += SalaryConfig.DRILL_BONUS
				remotes.Bonus:FireClient(player, "🚒 모범 대피!", SalaryConfig.DRILL_BONUS)
				adjustSpeed(player, d, "drill")
				unlockAchievement(player, d, "drill_hero")
				publishCollection(player, d)
			elseif daily(d).halfday then
				-- 🏖️ 반차 중이라 훈련 열외
			else
				caught(player, d, "소방 훈련에 안 나왔어요?! 시말서 쓰세요!")
			end
		end
	end

	---------------------------------------------------------------- 하루 일정
	dayCycle:on("dayStart", function(weekday)
		boss:startDay(weekday)
		snacks.restock()
		local isMonday = weekday == SalaryConfig.Weekdays[1]
		for player, d in data do
			if d.fired then
				d.fired = false
				d.profile.daily = nil -- (해고된 날은 근무일이 안 늘어서, 하루 한 번 기록을 새로 시작해요)
				remotes.Notify:FireClient(player, `📋 {Ranks[d.profile.rank].name}(으)로 재입사를 환영합니다… 이번엔 잘 좀 해 봐요.`)
			elseif isMonday and dayCycle.day > 1 and d.profile.warnings > 0 then
				d.profile.warnings = 0
				remotes.Notify:FireClient(player, "📅 새로운 한 주! 경고가 초기화됐어요.")
			end
			d.today = newDay()
			d.suspicion, d.workSeconds, d.combo = 0, 0, 1
			d.suspicionDanger = false
			d.deskAction, d.state, d.returnUntil = "work", "work", nil
			d.energyActive = false
			endActivity(d)
			d.ramenToday = 0
			d.heldSnack = nil
			d.leeWatch, d.leeBribed = 0, false
			d.away, d.awayWarned = 0, false
			d.buffs = {} -- 카페 음료 효과는 하루만
			-- 🐦 어제 모이를 안 줬으면 비둘기 친밀도가 조금 줄어요
			if d.profile.pigeonFeeds > 0 and not d.pigeonFedToday and dayCycle.day > 1 then
				d.profile.pigeonFeeds = math.max(0, d.profile.pigeonFeeds - SalaryConfig.PIGEON_DECAY)
				publishCollection(player, d)
			end
			d.pigeonFedToday = false

			-- ⚡ 오늘의 의심도 속도: 기준 x1로 리셋 → 요일 + 어제 예약(회식·홍삼) 적용
			d.speed = 1
			d.speedLog = {}
			local weekdaySpeed = SalaryConfig.WeekdaySpeed[weekday.name]
			if weekdaySpeed then
				adjustSpeed(player, d, "weekday", true, weekdaySpeed.delta, weekdaySpeed.label)
			end
			-- 👔 너무 비싼 출근룩은 부장님 눈에 띄어요
			local outfitValue = 0
			for _, itemId in d.profile.outfitEquipped do
				local option = SalaryConfig.getOutfit(itemId)
				outfitValue += if option then option.price else 0
			end
			if SalaryConfig.OUTFIT_ENABLED and outfitValue >= SalaryConfig.OUTFIT_LUXURY then
				adjustSpeed(player, d, "luxury", true, SalaryConfig.OUTFIT_LUXURY_DELTA, "👔 명품 출근룩 (월급 많이 받나 봐?)")
			end
			for _, reserved in d.nextDayFactors do
				adjustSpeed(player, d, "reserved", true, reserved.delta, reserved.label)
			end
			d.nextDayFactors = {}
			player:SetAttribute("SuspicionSpeed", d.speed)
			player:SetAttribute("SpeedLog", HttpService:JSONEncode(d.speedLog))
			if d.speed ~= 1 then
				local reasons = {}
				for _, entry in d.speedLog do
					table.insert(reasons, `{entry.label} {if entry.delta > 0 then "+" else ""}{string.format("%.2f", entry.delta)}`)
				end
				remotes.Notify:FireClient(player, `⚡ 오늘의 의심도 속도 x{string.format("%.2f", d.speed)} ({table.concat(reasons, ", ")})`)
			end
			updateBubble(player, "work")
			task.spawn(seatPlayer, player, d)
			remotes.Notify:FireClient(player, `🏢 {weekday.name} 출근! 오늘 부장님은 "{weekday.mood}"`)

		end
	end)

	dayCycle:on("lunchStart", function()
		boss:goLunch()
		for player in data do
			remotes.Notify:FireClient(player, "🍚 점심시간! 부장님이 나갔어요. 1시까지는 마음껏!")
		end
	end)

	dayCycle:on("lunchEnd", function()
		boss:backFromLunch()
		for player in data do
			remotes.Notify:FireClient(player, "⚠️ 1시! 부장님이 돌아왔어요!")
		end
	end)

	dayCycle:on("dayEnd", function()
		boss:leaveWork()
		for player, d in data do
			endActivity(d)
			if d.fired then
				continue
			end
			local profile = d.profile
			local rank = rankOf(d)

			-- 명세서 항목
			local basePay = math.floor(rank.basePay * (if hasCert(d, "mba") then 1.1 else 1)) -- 🎓 MBA: 기본급 +10%
			local lines = { { label = `기본급 ({rank.name})` .. (if hasCert(d, "mba") then " 🎓" else ""), amount = basePay } }
			for _, stateId in PAYSLIP_ORDER do
				local amount = d.today.earned[stateId] or 0
				if amount >= 1 then
					local minutes = math.floor((d.today.seconds[stateId] or 0) * GAME_MINUTES_PER_SECOND)
					table.insert(lines, { label = `{States[stateId].payLabel} ({minutes}분)`, amount = math.floor(amount) })
				end
			end
			if d.today.nearMiss > 0 then
				table.insert(lines, { label = "아슬아슬 보너스", amount = d.today.nearMiss })
			end
			if d.today.snackBonus > 0 then
				table.insert(lines, { label = `간식 완식 보너스 ({d.today.snacksEaten}개)`, amount = d.today.snackBonus })
			end
			if d.today.chatBonus > 0 then
				table.insert(lines, { label = `수다 완주 보너스 ({d.today.chatTopics}개)`, amount = d.today.chatBonus })
			end
			if d.today.eventBonus > 0 then
				table.insert(lines, { label = "돌발 이벤트 보너스", amount = d.today.eventBonus })
			end
			if d.today.caught > 0 then
				table.insert(lines, { label = `시말서 감봉 ({d.today.caught}회)`, amount = -d.today.caught * SalaryConfig.caughtPenalty(profile.rank) })
			end
			if auditReported(d) then
				table.insert(lines, {
					label = `📸 감사 보고서 (농땡이 {d.today.photos or 0}장 · 🪑빈자리 {d.today.emptyPhotos or 0}장, 경고 +1)`,
					amount = -SalaryConfig.caughtPenalty(profile.rank),
				})
				profile.warnings += 1 -- 📸 감사 보고서 = 경고 (3개면 해고)
			end
			local quota = quotaOf(d) -- (승진·해고로 직급이 바뀌기 전 기준)
			local quotaOk = d.workSeconds >= quota
			if not quotaOk then
				table.insert(lines, { label = "업무 미달 감봉", amount = -SalaryConfig.quotaPenalty(profile.rank) })
				profile.warnings += 1
			end
			-- 💰 하루 실적 목표 (사원부터): 기본급 빼고 오늘 번 돈 + 보너스 − 시말서 감봉
			local target = SalaryConfig.dailyTarget(profile.rank)
			local earned = math.floor(runningTotal(d))
			local targetOk = target <= 0 or earned >= target or daily(d).halfday == true -- 🏖️ 반차는 통과
			if not targetOk then
				table.insert(lines, { label = `실적 미달 감봉 ({earned}/{target}원)`, amount = -math.floor(target * SalaryConfig.TARGET_PENALTY_RATE) })
				profile.warnings += 1
			end

			local dayTotal = 0
			for _, line in lines do
				dayTotal += line.amount
			end
			profile.money = math.max(0, profile.money + dayTotal)
			profile.xp += math.max(0, dayTotal)
			d.today.settled = true
			growGarden(d) -- 🌱 오늘 물 준 화분이 자라요
			profile.stats.days += 1
			-- ⏳ 기한이 끝난 사무용품은 오늘로 끝 (내일 출근 때부터 효과 없음)
			local ended = expireItems(d)
			if #ended > 0 then
				buildDeskItems(d)
				task.delay(6, function()
					if player.Parent then
						remotes.Notify:FireClient(player, `⏳ 사용 기한 끝: {table.concat(ended, ", ")} — 🏪 사내 매점에서 다시 살 수 있어요`)
					end
				end)
			end

			-- 업적
			if d.today.caught == 0 and not auditReported(d) and events.todayId == "audit" then
				unlockAchievement(player, d, "audit_survivor")
			end
			if d.today.caught == 0 and quotaOk and d.today.nearMiss > 0 then
				unlockAchievement(player, d, "perfect_day")
			end
			if profile.money >= 100000 then
				unlockAchievement(player, d, "rich")
			end

			-- 해고 또는 승진
			local fired = profile.warnings >= SalaryConfig.MAX_WARNINGS
			local promotedTo: string? = nil
			if fired then
				fire(player, d)
			else
				while Ranks[profile.rank + 1] and profile.xp >= Ranks[profile.rank + 1].xp do
					profile.rank += 1
					promotedTo = Ranks[profile.rank].name
				end
				if promotedTo then
					profile.warnings = 0 -- 승진하면 경고도 깨끗하게
					if profile.rank >= 4 then
						unlockAchievement(player, d, "rank_daeri")
					end
					if profile.rank >= 8 then
						unlockAchievement(player, d, "rank_isa")
					end
				end
			end
			publishCollection(player, d)

			remotes.Payslip:FireClient(player, {
				day = dayCycle.day,
				weekday = dayCycle:weekday().name,
				lines = lines,
				dayTotal = dayTotal,
				total = math.floor(profile.money),
				warnings = profile.warnings,
				quotaOk = quotaOk,
				targetOk = targetOk,
				target = target,
				earned = earned,
				workSeconds = math.floor(d.workSeconds),
				quota = quota,
				fired = fired,
				stockProfit = math.floor(d.today.stockProfit),
				promotedTo = promotedTo,
				-- 🏢 새 직급이면 더 큰 회사에서 스카우트 제의가 와요
				moveTo = if not fired and SalaryConfig.companyForRank(profile.rank).id ~= office.companyId
					then SalaryConfig.companyForRank(profile.rank).name
					else nil,
				rankName = Ranks[profile.rank].name,
			})
			publish(player, d)
			task.spawn(save, player, d)
		end
	end)

	---------------------------------------------------------------- 플레이어 받기 (반드시 맨 마지막!)
	-- 위의 "하루 일정"(출근하면 부장님 등장) 같은 기능을 모두 연결한 다음에 플레이어를 받아요.
	-- 먼저 받으면 첫날 출근 신호를 놓쳐서 부장님이 점심 끝날 때까지 안 나오는 버그가 있었어요.
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return Employees
