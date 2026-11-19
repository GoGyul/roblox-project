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
-- 🖥️ 자리 부재 게이지: 근무 중에 내 자리를 비우면(화장실, 흡연구역, 회의실, 탕비실…) 천천히 차올라요.
--   70%면 "컴퓨터 자동 감지 시스템" 경보, 100%면 경고 1회. 자리에 앉아 있으면 다시 줄어요.
SalaryConfig.AWAY_SECONDS = 90 -- 0% → 100%까지 걸리는 시간 (대리 출석 인형이 있으면 150초)
SalaryConfig.AWAY_RECOVER = 8 -- 자리에 앉아 있으면 1초에 줄어드는 양 (%)
SalaryConfig.AWAY_WARN = 70 -- 이 %가 되면 경보
SalaryConfig.COFFEE_GRACE = 40 -- 탕비실에서 이 시간까지는 커피 타는 척 가능
SalaryConfig.DOCS_SECONDS = 40 -- 서류 들고 바쁜 척 지속 시간
SalaryConfig.RAMEN_SECONDS = 15 -- 라면 먹는 시간
SalaryConfig.RAMEN_PER_DAY = 2 -- 하루에 끓일 수 있는 라면 수
SalaryConfig.CHAT_RANGE = 7 -- 수다가 이어지는 거리
SalaryConfig.CHAT_TOPIC_BONUS = 500 -- 수다 주제 하나를 끝까지 하면 받는 보너스
SalaryConfig.CHAT_LINE_SECONDS = 2.6 -- 수다 대사 한 줄이 보이는 시간 (짧을수록 수다 성공이 쉬워요)
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
	snack = {
		emoji = "🍪",
		name = "몰래 간식 먹기",
		income = 3,
		detect = 45,
		returnTime = 0.5,
		payLabel = "간식 섭취 수당",
		hint = "탕비실에서 가져온 간식을 몰래 먹어요. 다 먹으면 보너스! 먹던 양은 유지돼요.",
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
		hint = "부장도 못 들어오는 안전지대. 대신 🖥️ 자리 부재 게이지가 차올라요.",
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
	-- 돌아다니며 하는 농땡이 (자리에서 일어나서)
	docs = {
		emoji = "📄",
		name = "서류 들고 바쁜 척",
		income = 4,
		detect = 0,
		payLabel = "바쁜 척 수당",
		hint = "프린터에서 서류를 들면 40초 동안 어디를 돌아다녀도 안 들켜요.",
	},
	chat = {
		emoji = "💬",
		name = "동료와 수다",
		income = 10,
		detect = 25,
		noise = 0.2,
		payLabel = "수다 수당",
		hint = "자리에 앉아 있는 동료에게 말을 걸어요. 떨어지면 끝나요.",
	},
	candy = {
		emoji = "🍭",
		name = "흡연구역에서 사탕 물기",
		income = 9,
		detect = 25,
		payLabel = "흡연구역 사탕 수당",
		hint = "🌳 눈치물산 공원 흡연구역(※ 금연, 사탕만!)에 서 있으면 돼요. 자리를 오래 비우면 티 나요.",
	},
	meeting = {
		emoji = "📊",
		name = "회의하는 척 졸기",
		income = 12,
		detect = 20,
		payLabel = "회의 참석 수당",
		hint = "🏢 눈치물산 유리 회의실 의자에 앉으면 돼요. 유리벽이라 너무 대놓고 자면 티 나요.",
	},
	ramen = {
		emoji = "🍜",
		name = "탕비실 라면",
		income = 16,
		detect = 60,
		noise = 0.4,
		payLabel = "라면 수당",
		hint = "탕비실 조리대에서 끓여 먹어요. 냄새 때문에 부장이 올 수 있어요!",
	},
	fired = {
		emoji = "📦",
		name = "해고됨",
		income = 0,
		detect = 0,
	},
} :: { [string]: StateInfo }

-- 자리에서 고를 수 있는 행동 (숫자키 1~7, 직급이 오르면 하나씩 열려요)
SalaryConfig.DeskActions = { "work", "blank", "webtoon", "phone", "shopping", "sleep", "recline", "snack" }

---------------------------------------------------------------------------
-- 🍪 탕비실 간식 (매일 아침 다시 채워져요)
--   seconds: 다 먹는 데 걸리는 시간 / bonus: 다 먹으면 받는 돈 / count: 하루에 놓이는 개수
---------------------------------------------------------------------------
export type SnackInfo = {
	id: string,
	emoji: string,
	name: string,
	seconds: number,
	bonus: number,
	count: number,
	size: Vector3,
	color: Color3,
}

SalaryConfig.Snacks = {
	{ id = "candy", emoji = "🍬", name = "사탕", seconds = 4, bonus = 200, count = 3, size = Vector3.new(0.6, 0.4, 0.6), color = Color3.fromRGB(255, 120, 160) },
	{ id = "cookie", emoji = "🍪", name = "쿠키", seconds = 7, bonus = 400, count = 2, size = Vector3.new(0.9, 0.25, 0.9), color = Color3.fromRGB(200, 150, 90) },
	{ id = "chocobar", emoji = "🍫", name = "초코바", seconds = 10, bonus = 600, count = 1, size = Vector3.new(1.2, 0.3, 0.5), color = Color3.fromRGB(110, 60, 30) },
	{ id = "donut", emoji = "🍩", name = "도넛", seconds = 14, bonus = 900, count = 1, size = Vector3.new(1, 0.4, 1), color = Color3.fromRGB(240, 170, 200) },
	{ id = "cake", emoji = "🍰", name = "케이크 한 조각", seconds = 20, bonus = 1500, count = 1, size = Vector3.new(1.2, 0.9, 1.2), color = Color3.fromRGB(250, 240, 230) },
	-- 🎂 생일 케이크 이벤트 때만 나와요 (count = 0이라 매일 아침에는 안 놓여요)
	{ id = "birthday", emoji = "🎂", name = "생일 케이크", seconds = 25, bonus = 4000, count = 0, size = Vector3.new(1.3, 1, 1.3), color = Color3.fromRGB(255, 190, 210) },
} :: { SnackInfo }

---------------------------------------------------------------------------
-- 📈 화장실 주식 (게임 속 가짜 회사예요. 실제 주식과는 관계없어요)
--   volatility: 2초마다 움직이는 폭 (클수록 크게 오르내림)
---------------------------------------------------------------------------
export type StockInfo = {
	id: string,
	emoji: string,
	name: string,
	price: number, -- 시작 가격
	volatility: number,
	good: { string }, -- 오를 때 뉴스
	bad: { string }, -- 내릴 때 뉴스
}

SalaryConfig.Stocks = {
	{ id = "gogyeol", emoji = "📱", name = "고결전자", price = 1000, volatility = 0.025,
		good = { "고결전자, 접히는 키보드 출시!", "고결전자, 해외 수출 대박!" },
		bad = { "고결전자, 신제품 배터리 논란", "고결전자 공장에 정전 발생" } },
	{ id = "pantry", emoji = "🍜", name = "탕비실푸드", price = 500, volatility = 0.045,
		good = { "탕비실푸드, 신상 컵라면 품절 대란!", "직장인 간식 소비 역대 최고!" },
		bad = { "탕비실푸드 과자, 질소 과다 논란", "다이어트 열풍에 간식 매출 감소" } },
	{ id = "bujang", emoji = "👔", name = "김부장엔터", price = 2000, volatility = 0.06,
		good = { "김부장엔터, 회식 신사업 발표!", "김부장엔터 '라떼는' 굿즈 완판!" },
		bad = { "김부장엔터, 꼰대 논란으로 구독자 이탈", "김부장엔터 대표, 단톡방 실수" } },
	{ id = "overtime", emoji = "🌙", name = "야근물산", price = 300, volatility = 0.1,
		good = { "야근물산, 야식 배달 사업 대박!", "야근물산, 에너지드링크 판매 급증" },
		bad = { "정시 퇴근 캠페인에 야근물산 폭락!", "주 4일제 소식에 야근물산 휘청" } },
} :: { StockInfo }

SalaryConfig.STOCK_TICK = 2 -- 주가가 바뀌는 간격(초)
SalaryConfig.STOCK_NEWS_CHANCE = 0.08 -- 틱마다 뉴스가 터질 확률
SalaryConfig.STOCK_STARTER_GIFT = 3000 -- 처음 변기에 앉으면 주는 입문 지원금

function SalaryConfig.getStock(stockId: string): StockInfo?
	for _, stock in SalaryConfig.Stocks do
		if stock.id == stockId then
			return stock
		end
	end
	return nil
end

function SalaryConfig.getSnack(snackId: string): SnackInfo?
	for _, snack in SalaryConfig.Snacks do
		if snack.id == snackId then
			return snack
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- 📈 직급
--   xp: 이 직급이 되는 데 필요한 누적 경력(지금까지 받은 월급 합계)
--   basePay: 하루 기본급 / bonus: 농땡이 수입 배율 / quota: 하루 최소 업무(초)
---------------------------------------------------------------------------
SalaryConfig.Ranks = {
	{ name = "인턴", xp = 0, basePay = 3000, bonus = 1.0, quota = 60 },
	{ name = "사원", xp = 6000, basePay = 4000, bonus = 1.15, quota = 70 },
	{ name = "주임", xp = 20000, basePay = 5500, bonus = 1.3, quota = 80 },
	{ name = "대리", xp = 50000, basePay = 7000, bonus = 1.5, quota = 90 },
	{ name = "과장", xp = 100000, basePay = 9000, bonus = 1.75, quota = 100 },
	{ name = "차장", xp = 170000, basePay = 11500, bonus = 2.0, quota = 110 },
	{ name = "부장", xp = 260000, basePay = 14500, bonus = 2.3, quota = 120 },
	{ name = "이사", xp = 380000, basePay = 18000, bonus = 2.7, quota = 130 },
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
	{ id = "plant", emoji = "🌱", name = "책상 화분", price = 2000, description = "마음의 안정. 의심도가 25% 더 빨리 줄어요." },
	{ id = "tumbler", emoji = "🥤", name = "고급 텀블러", price = 3000, description = "탕비실에서 커피 타는 척 시간이 40초 → 90초." },
	{ id = "cover", emoji = "🖥️", name = "모니터 가리개", price = 6000, description = "화면 농땡이(웹툰, 폰, 쇼핑)가 30% 덜 들켜요." },
	{ id = "earphones", emoji = "🎧", name = "부장 레이더 이어폰", price = 9000, description = "발소리 감지 거리 증가 + 부장이 지금 감시 중인지 화면에 표시." },
	{ id = "dummy", emoji = "🧸", name = "대리 출석 인형", price = 12000, description = "자리에 인형을 앉혀 둬요. 자리 부재 게이지가 천천히 차요 (90초 → 150초)." },
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
	{ id = "mobile", emoji = "🚶", name = "움직이는 루팡", description = "서류, 수다, 라면을 모두 해 보기" },
	{ id = "stock_buffett", emoji = "🧻", name = "화장실 워런 버핏", description = "화장실 주식으로 누적 1만원 수익 내기" },
	{ id = "cake_thief", emoji = "🍰", name = "케이크 도둑", description = "케이크 한 조각을 끝까지 몰래 먹기" },
	{ id = "birthday_cake", emoji = "🎂", name = "생일 축하해요(?)", description = "남의 생일 케이크를 끝까지 먹기" },
	{ id = "drill_hero", emoji = "🚒", name = "모범 대피자", description = "소방 훈련 때 제시간에 집결지로 대피하기" },
	{ id = "audit_survivor", emoji = "🔍", name = "감사 생존자", description = "감사 기간에 한 번도 안 걸리고 퇴근하기" },
	{ id = "workshop_winner", emoji = "🌸", name = "무궁화 챔피언", description = "워크숍 무궁화꽃이 피었습니다 1등 하기" },
	{ id = "dinner_ace", emoji = "🍻", name = "회식 에이스", description = "회식에서 6점 이상 받기" },
	{ id = "company_nunchi", emoji = "🏢", name = "이직 성공", description = "과장이 돼서 (주)눈치물산으로 스카우트되기" },
	{ id = "lee_bribe", emoji = "☕", name = "커피 외교", description = "이과장에게 커피를 상납해서 고자질 막기" },
	{ id = "lee_dodge", emoji = "🫣", name = "눈치 싸움 승리", description = "이과장의 ❗를 보고 들키기 전에 일하는 척하기" },
	{ id = "chatterbox", emoji = "🗣️", name = "사내 수다왕", description = "수다 주제 15개 수집하기" },
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
	scoldCoworker = {
		"{name}! 또 자고 있나?!",
		"{name}! 휴대폰 내려놓게!",
		"{name}, 자네 요즘 왜 그래?",
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

---------------------------------------------------------------------------
-- 🎲 돌발 이벤트 (하루에 최대 1개)
--   allDay: 출근할 때 공지하고 하루 종일 / 아니면 근무 중 갑자기 일어나요
---------------------------------------------------------------------------
export type EventInfo = { id: string, emoji: string, name: string, allDay: boolean, description: string }

SalaryConfig.EVENT_CHANCE = 0.5 -- 2일차부터, 하루에 이벤트가 생길 확률
-- 🧪 스튜디오 테스트용: "audit", "blackout", "cake", "drill" 중 하나를 넣으면 매일 그 이벤트만 나와요 (게시해도 실제 게임엔 영향 없음)
SalaryConfig.TEST_EVENT = ""
SalaryConfig.Events = {
	{ id = "audit", emoji = "🔍", name = "감사 기간", allDay = true, description = "감사팀이 순찰해요. 대신 농땡이 수입 ×2!" },
	{ id = "blackout", emoji = "💡", name = "정전", allDay = false, description = "30초 동안 컴퓨터가 꺼져요. 어두워서 자도 안 들켜요!" },
	{ id = "cake", emoji = "🎂", name = "생일 케이크", allDay = false, description = "탕비실에 생일 케이크 3조각! 먼저 먹는 사람이 임자" },
	{ id = "drill", emoji = "🚒", name = "소방 훈련", allDay = false, description = "45초 안에 초록색 집결지로 대피! 안 하면 경고" },
	{ id = "workshop", emoji = "🌸", name = "워크숍 레크리에이션", allDay = false, description = "부장님이 술래인 무궁화꽃이 피었습니다! 골인하면 보너스" },
} :: { EventInfo }

SalaryConfig.AUDIT_INCOME = 2 -- 감사 기간 농땡이 수입 배율

---------------------------------------------------------------------------
-- 👀 눈치 빠른 이과장 (수요일·목요일 출근)
--   돌아다니다가 머리 위에 ❗가 뜨면 휙 뒤돌아봐요.
--   농땡이를 LEE_NOTICE초 이상 보면 부장님께 고자질 → 의심도 +LEE_TATTLE, 부장님이 바로 달려와요.
--   ☕ 커피를 상납하면 그날 고자질을 한 번 눈감아 줘요.
---------------------------------------------------------------------------
SalaryConfig.LEE_NOTICE = 1.2
SalaryConfig.LEE_TATTLE = 35
SalaryConfig.LEE_COOLDOWN = 25 -- 같은 사람을 다시 고자질하기까지 (초)
SalaryConfig.LEE_BRIBE_COST = 1000
SalaryConfig.LEE_IGNORE_RANK = 5 -- 과장부터는 이과장과 동급이라 고자질 안 당해요
SalaryConfig.TEST_LEE = false -- 🧪 true면 스튜디오에서 요일 상관없이 매일 출근 (실제 게임엔 영향 없음)

-- 오늘 이과장이 출근하나? (감사 기간과 겹치지 않게 Events도 이걸 봐요)
function SalaryConfig.leeWorksOn(weekdayName: string): boolean
	if SalaryConfig.TEST_LEE and game:GetService("RunService"):IsStudio() then
		return true
	end
	local company = SalaryConfig.currentCompany()
	return table.find(company.leeDays, weekdayName) ~= nil
end

---------------------------------------------------------------------------
-- 🏢 회사: 직급이 오르면 더 큰 회사로 스카우트돼요
--   서버는 처음 들어온 사람의 직급으로 회사를 정하고 사무실을 지어요.
--   지금 서버의 회사 ID는 ReplicatedStorage의 "SalaryCompany" 속성에 있어요.
---------------------------------------------------------------------------
export type CompanyInfo = {
	id: string,
	name: string,
	minRank: number, -- 이 직급부터 이 회사로 출근
	leeDays: { string }, -- 이과장이 출근하는 요일
	motto: string,
}

SalaryConfig.Companies = {
	{ id = "daechung", name = "(주)대충상사", minRank = 1, leeDays = { "수요일", "목요일" }, motto = "사훈: 열정! 도전! 혁신! 우리는 가족입니다" },
	{
		id = "nunchi",
		name = "(주)눈치물산",
		minRank = 5, -- 과장
		leeDays = {}, -- 이과장은 대충상사에 남았어요 (나도 이제 과장이라 동급!)
		motto = "사훈: 눈치가 곧 경쟁력! 칼퇴는 없다",
	},
} :: { CompanyInfo }

SalaryConfig.TEST_COMPANY = "" -- 🧪 스튜디오에서 "nunchi"를 넣으면 눈치물산 사무실로 시작 (실제 게임엔 영향 없음)

function SalaryConfig.getCompany(companyId: string): CompanyInfo
	for _, company in SalaryConfig.Companies do
		if company.id == companyId then
			return company
		end
	end
	return SalaryConfig.Companies[1]
end

-- 이 직급이면 어느 회사에 다니나 (조건을 만족하는 가장 높은 회사)
function SalaryConfig.companyForRank(rank: number): CompanyInfo
	local best = SalaryConfig.Companies[1]
	for _, company in SalaryConfig.Companies do
		if rank >= company.minRank then
			best = company
		end
	end
	return best
end

function SalaryConfig.currentCompany(): CompanyInfo
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	return SalaryConfig.getCompany(ReplicatedStorage:GetAttribute("SalaryCompany") or "daechung")
end
SalaryConfig.BLACKOUT_SECONDS = 30
SalaryConfig.DRILL_SECONDS = 45 -- 대피 제한 시간
SalaryConfig.DRILL_ROLLCALL_SECONDS = 20 -- 대피 후 인원 점검 (자유시간)
SalaryConfig.DRILL_BONUS = 800

-- 🌸 워크숍: 무궁화꽃이 피었습니다 (부장님이 술래, 결승선은 출입문 앞)
SalaryConfig.WORKSHOP_SECONDS = 60 -- 최대 게임 시간
SalaryConfig.WORKSHOP_SPEED = 6 -- 게임 중 걷는 속도 (평소 16)
SalaryConfig.WORKSHOP_BONUS = 2000 -- 골인 보너스
SalaryConfig.WORKSHOP_FIRST_BONUS = 1500 -- 1등 추가 보너스

-- 🍻 목요일 회식 (퇴근 후 미니게임)
SalaryConfig.DINNER_DAY = "목요일"
SalaryConfig.DINNER_DELAY = 7 -- 명세서 읽을 시간
SalaryConfig.DINNER_SECONDS = 40
SalaryConfig.DINNER_POINT = 300 -- 회식 점수 1점당 보너스
SalaryConfig.TEST_DINNER = false -- 🧪 true면 스튜디오에서 매일 회식 (실제 게임엔 영향 없음)

function SalaryConfig.getEvent(eventId: string): EventInfo?
	for _, event in SalaryConfig.Events do
		if event.id == eventId then
			return event
		end
	end
	return nil
end

return SalaryConfig
