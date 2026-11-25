-- 💾 저장 기능 (DataStore)
-- 플레이어가 나가도 직급, 경력, 통장, 아이템, 도감이 남아 있게 로블록스 서버에 저장해요.
--
-- ⚠️ 스튜디오에서 테스트할 때는 저장이 되려면 설정이 필요해요:
--    File → Experience Settings → Security → "Enable Studio Access to API Services" 켜기
--    꺼져 있으면 저장 없이 그냥 플레이돼요 (오류로 멈추지 않아요).

local DataStoreService = game:GetService("DataStoreService")

local Profiles = {}

local STORE_NAME = "SalaryLupin_v1"

export type Profile = {
	version: number,
	rank: number, -- SalaryConfig.Ranks 번호
	xp: number, -- 누적 경력 (지금까지 받은 월급 합계, 매점에서 써도 안 줄어요)
	money: number, -- 통장 잔고
	warnings: number,
	items: { [string]: boolean }, -- 산 아이템
	energy: number, -- 에너지 드링크 개수
	collection: { [string]: boolean }, -- 도감: "action_낮잠" 같은 행동 + 업적 ID
	stocks: { [string]: number }, -- 가진 주식 수
	stockCost: { [string]: number }, -- 주식 산 값 합계 (수익률 계산용)
	stockGift: boolean, -- 입문 지원금을 받았나
	unsettled: number, -- 퇴근 전에 나가서 아직 통장에 안 들어간 돈 (다음 입장 때 정산)
	plushies: { [string]: number }, -- 🧸 뽑은 인형 (ID → 개수)
	deskPlushies: { string }, -- 🧸 책상에 진열한 인형 (최대 3개)
	tickets: number, -- 🎟️ 오락실 티켓
	lastCompany: string, -- 🏢 지난번에 다닌 회사 (바뀌면 이직/좌천 안내)
	missionsDone: { [string]: boolean }, -- 📋 성공한 긴급 프로젝트 종류
	lastHongsamDay: number, -- 🎁 홍삼 선물을 마지막으로 드린 날
	decorOwned: { [string]: boolean }, -- 🪑 산 꾸미기 아이템
	decorEquipped: { [string]: string }, -- 🪑 칸(slot)별 장착한 아이템 ID
	title: string, -- 🏆 장착한 칭호 ID
	catPets: number, -- 🐱 월급냥 쓰다듬은 횟수
	elevatorNinja: number, -- 🚪 부장님 엘리베이터에서 눈 안 마주친 횟수
	planeBest: number, -- ✈️ 종이비행기 최고 기록 (m)
	garden: { { seed: string, growth: number, watered: number, missed: number, readyAt: number? } }, -- 🌱 옥상 텃밭 (칸마다, readyAt = ⚡쾌속 식물이 익는 os.time)
	seeds: { [string]: number }, -- 🌱 🎒에 보관 중인 씨앗 (씨앗 ID → 개수, 🏪 사내 매점에서 사요)
	harvests: number, -- 🌱 수확한 횟수
	parkBeds: { { flower: string, growth: number, watered: number, fedStage: number } }, -- 🌷 눈치물산 공원 화단 (화단마다, fedStage = 🧪 거름 준 단계)
	flowerSeeds: { [string]: number }, -- 🌷 🎒 꽃씨 (꽃 ID → 개수)
	fertilizer: number, -- 🧪 🎒 거름 개수
	scenes: { [string]: boolean }, -- 🔭 관찰 일지에 기록한 장면
	sunsetPhotos: number, -- 🌅 노을 사진 앨범 (하루 한 장)
	deskUpgrades: { [string]: number }, -- 🖥️ 책상 장비 단계 (장비 ID → 단계)
	certs: { [string]: boolean }, -- 📚 딴 자격증
	daily: { [string]: any }, -- 📅 하루 한 번 제한 기록 (내 근무일 기준, 서버를 옮겨도 유지)
	outfitOwned: { [string]: boolean }, -- 👔 산 출근룩
	guardGifts: { [string]: number }, -- 🎁 🎒에 보관 중인 경비원 선물 (선물 ID → 개수)
	deskHidden: { [string]: boolean },
	itemUntil: { [string]: number }, -- ⏳ 사무용품 사용 기한 (이 근무일 수가 되면 끝나요) -- 🪑 책상에서 치워 둔 사무용품 (아이템 ID → true)
	outfitEquipped: { [string]: string }, -- 👔 칸별로 입은 출근룩 ID
	pigeonFeeds: number, -- 🐦 옥상 비둘기 친밀도 점수 (과자 줄 때마다 +1~3, 안 주면 조금씩 줄어요 · 예전엔 모이 준 횟수)
	pigeons: { [string]: number }, -- 🐦 만난 비둘기 (종류 → 만난 횟수)
	pigeonSnacks: { [string]: number }, -- 🍪 🎒 비둘기 과자 (과자 ID → 개수, 🏪 사내 매점에서 사요)
	pigeonTreasures: { [string]: number }, -- 🎁 비둘기가 물어 온 선물 (선물 ID → 주운 횟수) → 📒 관찰 노트 🐦 비둘기 보물
	arcadeBest: { [string]: number }, -- 🕹️ 게임별 내 최고 점수
	friendship: { [string]: number }, -- 🤝 동료 친밀도 (동료 이름 → 점수)
	fitness: { strength: number, stamina: number, agility: number, flexibility: number, balance: number }, -- 🏋️ 체력 단련실에서 키운 스탯 (10점마다 Lv.1 → 효과는 SalaryConfig.FitnessEffects)
	orders: { { id: number, kind: string, itemId: string, day: number, arrived: boolean? } }, -- 🚚 쇼핑몰 주문 (다음 근무일에 📦 택배 보관함으로 와요)
	orderSeq: number, -- 🚚 주문 번호 (하나씩 늘어나요)
	notices: { { e: string, t: string, k: string?, day: number, min: number, read: boolean? } }, -- 🔔 알림 (최근 30개)
	stats: { days: number, nearMiss: number, caught: number, fired: number, stockProfit: number },
}

function Profiles.default(): Profile
	return {
		version = 1,
		rank = 1,
		xp = 0,
		money = 0,
		warnings = 0,
		items = {},
		energy = 0,
		collection = {},
		stocks = {},
		stockCost = {},
		stockGift = false,
		unsettled = 0,
		plushies = {},
		deskPlushies = {},
		tickets = 0,
		lastCompany = "",
		missionsDone = {},
		lastHongsamDay = -100,
		decorOwned = {},
		decorEquipped = {},
		title = "newbie",
		catPets = 0,
		elevatorNinja = 0,
		planeBest = 0,
		garden = {},
		seeds = {},
		harvests = 0,
		parkBeds = {},
		flowerSeeds = {},
		fertilizer = 0,
		scenes = {},
		sunsetPhotos = 0,
		deskUpgrades = {},
		certs = {},
		daily = {},
		outfitOwned = {},
		guardGifts = {},
		deskHidden = {},
		itemUntil = {},
		outfitEquipped = {},
		pigeonFeeds = 0,
		pigeons = {},
		pigeonSnacks = {},
		pigeonTreasures = {},
		arcadeBest = {},
		friendship = {},
		fitness = { strength = 0, stamina = 0, agility = 0, flexibility = 0, balance = 0 },
		orders = {},
		orderSeq = 0,
		notices = {},
		stats = { days = 0, nearMiss = 0, caught = 0, fired = 0, stockProfit = 0 },
	}
end

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Profiles] DataStore를 열 수 없어요. 저장 없이 진행합니다:", result)
	end
end

local function key(player: Player): string
	return `player_{player.UserId}`
end

-- 예전 저장 데이터에 없는 항목은 기본값으로 채워요
local function fillDefaults(profile: any): Profile
	local base = Profiles.default()
	for field, value in base do
		if profile[field] == nil then
			profile[field] = value
		end
	end
	for field, value in base.stats do
		if profile.stats[field] == nil then
			profile.stats[field] = value
		end
	end
	for field, value in base.fitness do -- 🏋️ 나중에 스탯이 늘어나도 0부터
		if profile.fitness[field] == nil then
			profile.fitness[field] = value
		end
	end
	return profile
end

-- 불러오기. 두 번째 값 canSave가 false면 저장하지 않아요
-- (불러오기에 실패했는데 저장해 버리면 진짜 데이터를 빈 데이터로 덮어쓸 수 있어서)
function Profiles.load(player: Player): (Profile, boolean)
	if require(game:GetService("ReplicatedStorage").Shared.SalarySimulation).enabled() then
		return Profiles.default(), false
	end
	if not store then
		return Profiles.default(), false
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return (store :: DataStore):GetAsync(key(player))
		end)
		if ok then
			if typeof(result) == "table" then
				return fillDefaults(result), true
			end
			return Profiles.default(), true -- 처음 온 플레이어
		end
		warn(`[Profiles] 불러오기 실패 ({attempt}/3):`, result)
		task.wait(1)
	end
	return Profiles.default(), false
end

function Profiles.save(player: Player, profile: Profile): boolean
	if require(game:GetService("ReplicatedStorage").Shared.SalarySimulation).enabled() then
		return false
	end
	if not store then
		return false
	end
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync(key(player), profile)
	end)
	if not ok then
		warn("[Profiles] 저장 실패:", err)
	end
	return ok
end

return Profiles
