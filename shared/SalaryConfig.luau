-- 💼 월급루팡 시뮬레이터 설정
-- 숫자를 바꾸면 게임 밸런스가 바뀌어요. 서버와 클라이언트가 함께 읽어요.

local SalaryConfig = {}

---------------------------------------------------------------------------
-- 하루 시간
---------------------------------------------------------------------------
SalaryConfig.DAY_SECONDS = 420 -- 09:00 ~ 18:00 이 실제로는 7분
SalaryConfig.START_MINUTE = 9 * 60
SalaryConfig.END_MINUTE = 18 * 60
SalaryConfig.LUNCH_START = 12 * 60
SalaryConfig.LUNCH_END = 13 * 60
SalaryConfig.PAYSLIP_SECONDS = 15 -- 퇴근 후 다음 날 출근까지

---------------------------------------------------------------------------
-- 돈과 규칙
---------------------------------------------------------------------------
SalaryConfig.BASE_PAY = 3000 -- 하루 기본급
SalaryConfig.WORK_QUOTA = 60 -- 하루에 최소 이만큼(초)은 일해야 업무 평가 통과
SalaryConfig.MAX_WARNINGS = 3 -- 경고 3번이면 해고
SalaryConfig.CAUGHT_PENALTY = 1000 -- 적발 1번당 감봉
SalaryConfig.QUOTA_PENALTY = 2000 -- 업무 미달 감봉
SalaryConfig.NEAR_MISS_BONUS = 300 -- 아슬아슬 보너스 (콤보만큼 곱해짐)
SalaryConfig.NEAR_MISS_WINDOW = 2.5 -- 복귀한 뒤 몇 초 안에 부장이 보면 아슬아슬
SalaryConfig.MAX_COMBO = 5
SalaryConfig.TOILET_LIMIT = 60 -- 화장실에 이보다 오래 있으면 자리 비움이 티 남
SalaryConfig.COFFEE_GRACE = 40 -- 탕비실에서 이 시간까지는 커피 타는 척 가능
SalaryConfig.SUSPICION_DECAY = 8 -- 들키지 않을 때 의심도가 초당 줄어드는 양

---------------------------------------------------------------------------
-- 상태 (자리에서 하는 행동 + 장소에 따른 상태)
--   income: 초당 버는 돈
--   detect: 부장에게 보일 때 의심도가 초당 오르는 양 (0이면 안전)
--   returnTime: 이 행동에서 "일하기"로 돌아오는 데 걸리는 시간
--   noise: 부장이 소리를 듣고 조사하러 올 확률에 더해지는 값
--   unlockRank: 이 직급부터 쓸 수 있어요 (Ranks 번호)
--   screen: 화면을 보는 농땡이 (모니터 가리개 효과를 받아요)
---------------------------------------------------------------------------
export type StateInfo = {
	emoji: string,
	name: string,
	income: number,
	detect: number,
	returnTime: number?,
	noise: number?,
	payLabel: string?,
	hint: string?,
	unlockRank: number?,
	screen: boolean?,
}

SalaryConfig.States = {
	work = {
		emoji = "💼",
		name = "일하기",
		income = 2,
		detect = 0,
		returnTime = 0,
		payLabel = "성실 근무 수당",
		hint = "안전하지만 쥐꼬리. 업무 평가는 채워야 해요.",
	},
	blank = {
		emoji = "😶",
		name = "멍때리기",
		income = 5,
		detect = 25,
		returnTime = 0,
		payLabel = "멍때리기 수당",
		hint = "생각하는 척. 잘 안 들키고 바로 복귀 가능.",
	},
	phone = {
		emoji = "📱",
		name = "폰 게임",
		income = 9,
		detect = 55,
		returnTime = 1,
		noise = 0.25,
		screen = true,
		payLabel = "폰게임 수당",
		hint = "게임 소리에 부장이 다가올 수 있어요. 복귀 1초.",
	},
	webtoon = {
		emoji = "📺",
		name = "웹툰 정주행",
		income = 7,
		detect = 40,
		returnTime = 0.5,
		screen = true,
		unlockRank = 2,
		payLabel = "웹툰 정주행 수당",
		hint = "조용해서 소리로 들킬 일은 없어요. 복귀 0.5초.",
	},
	shopping = {
		emoji = "🛒",
		name = "온라인 쇼핑",
		income = 11,
		detect = 50,
		returnTime = 1,
		screen = true,
		unlockRank = 3,
		payLabel = "장바구니 수당",
		hint = "마우스 클릭만 하니 일하는 것처럼 보이기도 해요. 복귀 1초.",
	},
	sleep = {
		emoji = "😴",
		name = "엎드려 낮잠",
		income = 14,
		detect = 70,
		returnTime = 2,
		noise = 0.35,
		payLabel = "낮잠 수당",
		hint = "고수입! 코 고는 소리 주의. 일어나는 데 2초.",
	},
	recline = {
		emoji = "🛌",
		name = "의자 젖히고 꿀잠",
		income = 20,
		detect = 85,
		returnTime = 3,
		noise = 0.45,
		unlockRank = 4,
		payLabel = "꿀잠 수당",
		hint = "대리의 특권. 최고 수입이지만 일어나는 데 3초!",
	},
	returning = {
		emoji = "😳",
		name = "복귀 중",
		income = 0,
		detect = 70,
	},
	toilet = {
		emoji = "🚽",
		name = "화장실",
		income = 8,
		detect = 0,
		payLabel = "화장실 체류 수당",
		hint = "부장도 못 들어오는 안전지대. 대신 오래 있으면 자리 비움이 티 나요.",
	},
	coffee = {
		emoji = "☕",
		name = "커피 타임",
		income = 4,
		detect = 30,
		payLabel = "커피 수당",
		hint = "잠깐은 커피 타는 척 가능. 너무 오래 있으면 의심받아요.",
	},
	roam = {
		emoji = "🚶",
		name = "어슬렁",
		income = 0,
		detect = 15,
	},
	fired = {
		emoji = "📦",
		name = "해고됨",
		income = 0,
		detect = 0,
	},
} :: { [string]: StateInfo }

-- 자리에서 고를 수 있는 행동 (숫자키 1~7, 직급이 오르면 하나씩 열려요)
SalaryConfig.DeskActions = { "work", "blank", "webtoon", "phone", "shopping", "sleep", "recline" }

---------------------------------------------------------------------------
-- 📈 직급
--   xp: 이 직급이 되는 데 필요한 누적 경력(지금까지 받은 월급 합계)
--   basePay: 하루 기본급 / bonus: 농땡이 수입 배율 / quota: 하루 최소 업무(초)
---------------------------------------------------------------------------
SalaryConfig.Ranks = {
	{ name = "인턴", xp = 0, basePay = 3000, bonus = 1.0, quota = 60 },
	{ name = "사원", xp = 15000, basePay = 4000, bonus = 1.15, quota = 70 },
	{ name = "주임", xp = 40000, basePay = 5500, bonus = 1.3, quota = 80 },
	{ name = "대리", xp = 80000, basePay = 7000, bonus = 1.5, quota = 90 },
	{ name = "과장", xp = 140000, basePay = 9000, bonus = 1.75, quota = 100 },
	{ name = "차장", xp = 220000, basePay = 11500, bonus = 2.0, quota = 110 },
	{ name = "부장", xp = 330000, basePay = 14500, bonus = 2.3, quota = 120 },
	{ name = "이사", xp = 480000, basePay = 18000, bonus = 2.7, quota = 130 },
	-- 👑 사장: 3단계 엔딩에서 공개
}

---------------------------------------------------------------------------
-- 🛒 매점 아이템
--   consumable = true 면 여러 개 사서 하루에 하나씩 써요
---------------------------------------------------------------------------
export type ItemInfo = {
	id: string,
	emoji: string,
	name: string,
	price: number,
	description: string,
	consumable: boolean?,
}

SalaryConfig.Items = {
	{ id = "plant", emoji = "🪴", name = "책상 화분", price = 2000, description = "마음의 안정. 의심도가 25% 더 빨리 줄어요." },
	{ id = "tumbler", emoji = "🥤", name = "고급 텀블러", price = 3000, description = "탕비실에서 커피 타는 척 시간이 40초 → 90초." },
	{ id = "cover", emoji = "🖥️", name = "모니터 가리개", price = 6000, description = "화면 농땡이(웹툰, 폰, 쇼핑)가 30% 덜 들켜요." },
	{ id = "earphones", emoji = "🎧", name = "부장 레이더 이어폰", price = 9000, description = "발소리 감지 거리 증가 + 부장이 지금 감시 중인지 화면에 표시." },
	{ id = "dummy", emoji = "🧸", name = "대리 출석 인형", price = 12000, description = "자리에 인형을 앉혀 둬요. 화장실 체류 한도 60초 → 150초." },
	{ id = "energy", emoji = "⚡", name = "에너지 드링크", price = 1500, consumable = true, description = "마시면 그날 하루 일하는 척 복귀 시간 절반!" },
} :: { ItemInfo }

function SalaryConfig.getItem(itemId: string): ItemInfo?
	for _, item in SalaryConfig.Items do
		if item.id == itemId then
			return item
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- 📖 업적 (도감에는 농땡이 행동 + 업적이 함께 기록돼요)
---------------------------------------------------------------------------
SalaryConfig.Achievements = {
	{ id = "near_miss", emoji = "😮‍💨", name = "아슬아슬 입문", description = "처음으로 아슬아슬 보너스 받기" },
	{ id = "combo_max", emoji = "🔥", name = "곡예사", description = "아슬아슬 콤보 x5 달성" },
	{ id = "caught", emoji = "📝", name = "시말서 데뷔", description = "처음으로 적발되기" },
	{ id = "fired", emoji = "📦", name = "짐 싸는 법", description = "처음으로 해고되기" },
	{ id = "toilet_long", emoji = "🚽", name = "화장실 장기 투숙객", description = "화장실에 한 번에 50초 이상 있기" },
	{ id = "lunch_nap", emoji = "🍚", name = "점심엔 역시 낮잠", description = "점심시간에 낮잠 자기" },
	{ id = "perfect_day", emoji = "😇", name = "완벽한 하루", description = "적발 0회 + 업무 완료 + 아슬아슬 1회 이상" },
	{ id = "rich", emoji = "🏦", name = "통장 부자", description = "통장 잔고 10만원 달성" },
	{ id = "rank_daeri", emoji = "🎖️", name = "대리님", description = "대리로 승진하기" },
	{ id = "rank_isa", emoji = "🏅", name = "이사님", description = "이사로 승진하기" },
}

---------------------------------------------------------------------------
-- 요일별 부장님 기분
---------------------------------------------------------------------------
SalaryConfig.Weekdays = {
	{ name = "월요일", walkSpeed = 9, fov = 65, range = 44, mood = "월요병으로 예민함 😠" },
	{ name = "화요일", walkSpeed = 8, fov = 58, range = 40, mood = "평범한 하루" },
	{ name = "수요일", walkSpeed = 8, fov = 58, range = 40, mood = "실적 압박 중" },
	{ name = "목요일", walkSpeed = 8, fov = 55, range = 40, mood = "회식 생각 중" },
	{ name = "금요일", walkSpeed = 7, fov = 50, range = 36, mood = "불금이라 느슨함 😌" },
}

---------------------------------------------------------------------------
-- 김부장 대사
---------------------------------------------------------------------------
SalaryConfig.BossLines = {
	patrol = {
		"요즘 젊은 친구들은 말이야…",
		"내가 자네 나이 땐 말이야~",
		"보고서는 언제 되나?",
		"다들 열정이 없어, 열정이!",
		"우리 회사는 가족 같은 회사야.",
		"오늘 회식 어때? 다들 시간 되지?",
		"커피 한 잔 타 줄 사람~?",
		"이번 분기 실적이 말이야…",
	},
	investigate = {
		"음? 무슨 소리지?",
		"거기 누구 코 고는 소리 아냐?",
		"방금 게임 소리 났는데…",
	},
	caught = {
		"자네… 지금 뭐 하는 건가?!",
		"이거 시말서감이야!",
		"월급이 아깝다, 아까워!",
		"회사가 놀이터야?!",
		"자네 인사고과 각오하게.",
	},
	lunch = "점심 먹고 오겠네. 다들 열심히 하고 있어~",
	back = "자, 오후 업무 시작이야!",
}

SalaryConfig.CoworkerNames = { "이대리", "박사원", "최주임", "정과장", "한인턴" }

return SalaryConfig
