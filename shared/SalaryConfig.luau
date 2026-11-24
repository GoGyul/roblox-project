-- 💼 월급루팡 시뮬레이터 설정
-- 숫자를 바꾸면 게임 밸런스가 바뀌어요. 서버와 클라이언트가 함께 읽어요.

local SalaryConfig = {}

---------------------------------------------------------------------------
-- 하루 시간
---------------------------------------------------------------------------
SalaryConfig.DAY_SECONDS = 420 -- 09:00 ~ 18:00 이 실제로는 7분 (콘텐츠가 많아져서 다시 7분)
SalaryConfig.START_MINUTE = 9 * 60
SalaryConfig.DESK_SEAT_OFFSET = 3.3 -- 📐 의자가 책상 가운데에서 뒤로 떨어진 거리 (책상 깊이 4)
SalaryConfig.END_MINUTE = 18 * 60
SalaryConfig.LUNCH_START = 12 * 60
SalaryConfig.LUNCH_END = 13 * 60
SalaryConfig.PAYSLIP_SECONDS = 15 -- 퇴근 후 명세서 보는 시간 (그다음 🏢 출근하기 대기)
SalaryConfig.CLOCKIN_WAIT = 20 -- 여럿이 할 때: 누군가 출근하기를 누르고 이만큼 지나면 나머지를 기다리지 않고 출근

---------------------------------------------------------------------------
-- 돈과 규칙
---------------------------------------------------------------------------
SalaryConfig.BASE_PAY = 3000 -- 하루 기본급
SalaryConfig.WORK_QUOTA = 75 -- 하루에 최소 이만큼(초)은 내 자리에 앉아 있어야 업무 평가 통과 (직급별 quota가 우선)
SalaryConfig.MAX_WARNINGS = 3 -- 경고 3번이면 해고
SalaryConfig.CAUGHT_PENALTY = 1000 -- 적발 1번당 감봉 (기본값. 실제로는 직급별 Ranks[].penalty를 써요)

SalaryConfig.TARGET_PENALTY_RATE = 0.3 -- 실적 미달 감봉 = 목표 × 이 비율

-- 이 직급의 하루 실적 목표 (0이면 없음)
function SalaryConfig.dailyTarget(rank: number): number
	local info = SalaryConfig.Ranks[rank]
	return if info and info.target then info.target else 0
end

-- 이 직급에서 업무 미달 감봉액
function SalaryConfig.quotaPenalty(rank: number): number
	local info = SalaryConfig.Ranks[rank]
	return if info and info.quotaPenalty then info.quotaPenalty else SalaryConfig.QUOTA_PENALTY
end

-- 이 직급에서 적발 1번당 감봉액
function SalaryConfig.caughtPenalty(rank: number): number
	local info = SalaryConfig.Ranks[rank]
	return if info and info.penalty then info.penalty else SalaryConfig.CAUGHT_PENALTY
end
SalaryConfig.QUOTA_PENALTY = 2000 -- 업무 미달 감봉
-- 👔 농땡이로 돈 버는 중이면 부장님이 확인하러 올 확률 (부장님이 다음 행동을 고를 때마다)
--   = 행동 소음 + BOSS_SLACK_WATCH + 농땡이한 초 × BOSS_SLACK_RAMP (최대 BOSS_SLACK_MAX)
--   예) 막 시작: 25%,  10초째: 25 + 30 = 55%,  20초부터: 85%
SalaryConfig.BOSS_SLACK_WATCH = 0.25
SalaryConfig.BOSS_SLACK_RAMP = 0.03 -- 1초마다 +3%
SalaryConfig.BOSS_SLACK_MAX = 0.85
-- 🤨 쉬지 않고 오래 농땡이를 치면 안 보여도 수상해져요 (평생 농땡이 방지)
--   SLACK_HUNCH_AFTER초가 지나면 의심도가 초당 SLACK_HUNCH_RATE씩 (오늘의 의심도 속도 반영) 차오르고
--   SLACK_FORCE_VISIT초가 지나면 부장님이 반드시 확인하러 와요. 일하기로 잠깐 돌아가면 처음부터
SalaryConfig.SLACK_HUNCH_AFTER = 45
SalaryConfig.SLACK_HUNCH_RATE = 1.5
SalaryConfig.SLACK_FORCE_VISIT = 70
-- ⚡ 오늘의 의심도 속도: 매일 아침 x1로 리셋 → 사건이 생길 때마다 더하거나 빼요 (합연산, x0.70 ~ x2.50)
--   왼쪽 상태창 "의심도" 줄에 ⏩x1.20처럼 보이고, 누르면 오늘 바뀐 이유 목록이 떠요.
SalaryConfig.SPEED_MIN = 0.7 -- 아무리 잘해도 이 밑으로는 안 내려가요
SalaryConfig.SPEED_MAX = 2.5 -- 아무리 찍혀도 이 위로는 안 올라가요
SalaryConfig.SpeedFactors = {
	-- 빨라지는 것 (위험!)
	caught = { delta = 0.15, label = "🚨 적발" },
	accuseWrong = { delta = 0.20, label = "😠 엉뚱한 동료를 감사관으로 의심" },
	auditPhoto = { delta = 0.05, label = "📸 감사관에게 찍힘" },
	leeTattle = { delta = 0.10, label = "👀 이과장 고자질" },
	videoFail = { delta = 0.10, label = "🎧 화상회의 대답 실패" },
	elevatorFail = { delta = 0.10, label = "🚪 엘리베이터에서 실수" },
	missionFail = { delta = 0.10, label = "📋 긴급 프로젝트 실패" },
	-- 느려지는 것 (부장님 신뢰 ↑)
	auditReveal = { delta = -0.15, label = "🕶️ 감사관 색출" },
	missionSuccess = { delta = -0.15, label = "📋 긴급 프로젝트 성공" },
	flowers = { delta = -0.15, label = "💐 꽃다발 선물" },
	choco = { delta = -0.05, label = "🍫 초콜릿 선물" },
	elevatorNinja = { delta = -0.05, label = "🚪 엘리베이터 무사 통과" },
	workshopWin = { delta = -0.10, label = "🌸 워크숍 1등" },
	drill = { delta = -0.05, label = "🚒 모범 대피" },
	-- 다음 날 아침에 적용 (예약)
	hongsam = { delta = -0.15, label = "🎁 어제 홍삼 선물" },
	dinner = { delta = 0, label = "🍻 어제 회식" }, -- (회식 점수에 따라: -0.25 / -0.10 / +0.15)
} :: { [string]: { delta: number, label: string } }
-- 요일마다 기준이 살짝 달라요
SalaryConfig.WeekdaySpeed = {
	["월요일"] = { delta = 0.10, label = "😠 월요병 부장님" },
	["금요일"] = { delta = -0.10, label = "😌 불금이라 느슨한 부장님" },
} :: { [string]: { delta: number, label: string } }
SalaryConfig.SUSPICION_SPEED = 1 / 3 -- 👀 부장님·감사팀에게 보일 때 의심도가 차는 속도 (전체 배율, 1/3 = 3배 느리게)
SalaryConfig.NEAR_MISS_BONUS = 200 -- 아슬아슬 보너스 (콤보만큼 곱해짐: 200, 400, … 최대 1,000)
SalaryConfig.NEAR_MISS_DAILY_MAX = 5 -- 하루에 아슬아슬 보너스를 받을 수 있는 횟수 (하루 최대 3,000원)
SalaryConfig.NEAR_MISS_COOLDOWN = 30 -- 한 번 받은 뒤 다음 아슬아슬까지 최소 (초)
SalaryConfig.NEAR_MISS_WINDOW = 2.5 -- 복귀한 뒤 몇 초 안에 부장이 보면 아슬아슬
SalaryConfig.NEAR_MISS_DANGER = 70 -- 의심도가 이만큼 넘게 찼다가
SalaryConfig.NEAR_MISS_SAFE = 20 -- 안 걸리고 이 밑으로 내려오면 "아슬아슬 탈출!" (콤보 +1)
SalaryConfig.MAX_COMBO = 5
-- 🖥️ 자리 부재 게이지: 근무 중에 내 자리를 비우면(화장실, 흡연구역, 회의실, 탕비실…) 천천히 차올라요.
--   70%면 "컴퓨터 자동 감지 시스템" 경보, 100%면 경고 1회. 자리에 앉아 있으면 다시 줄어요.
SalaryConfig.AWAY_SECONDS = 110 -- (단지가 넓어져서 90 → 110) 0% → 100%까지 걸리는 시간
SalaryConfig.AWAY_SECONDS_DUMMY = 150 -- 🧸 대리 출석 인형을 앉혀 두면
SalaryConfig.AWAY_SECONDS_DUMMY_PRO = 240 -- 👔 최고급 마네킹을 앉혀 두면
SalaryConfig.AWAY_RECOVER = 6 -- (8 → 6: 잠깐 앉았다 바로 또 나가기 어렵게) 자리에 앉아 있으면 1초에 줄어드는 양 (%)
SalaryConfig.AWAY_LATE_FROM = 16 * 60 + 30 -- 🕟 이 시각부터는 다들 슬슬 풀어져서 (퇴근 전 농땡이 타임)
SalaryConfig.AWAY_LATE_SCALE = 0.5 -- 자리 부재 게이지가 이 배율로 천천히 차요 (절반 속도)
SalaryConfig.AWAY_WARN = 70 -- 이 %가 되면 경보
SalaryConfig.COFFEE_GRACE = 40 -- 탕비실에서 이 시간까지는 커피 타는 척 가능
SalaryConfig.DOCS_SECONDS = 40 -- 서류 들고 바쁜 척 지속 시간
SalaryConfig.RAMEN_SECONDS = 15 -- 라면 먹는 시간
SalaryConfig.RAMEN_PER_DAY = 2 -- 하루에 끓일 수 있는 라면 수
SalaryConfig.CHAT_RANGE = 7 -- 수다가 이어지는 거리
SalaryConfig.CHAT_TOPIC_BONUS = 500 -- 수다 주제 하나를 끝까지 하면 받는 보너스
SalaryConfig.CHAT_REACTS_PER_DAY = 2 -- 💬 맞장구를 이만큼 하면 "오늘 대화 끝" (같은 동료와는 하루 한 번)
SalaryConfig.CHAT_LINE_SECONDS = 2.2 -- 수다 대사 한 줄이 보이는 시간 (짧을수록 수다 성공이 쉬워요)
SalaryConfig.CHAT_REACT_SECONDS = 4 -- 🗣️ 맞장구 고르기 제한 시간
SalaryConfig.CHAT_REACT_BONUS = 200 -- 🗣️ 좋은 맞장구 하나마다 이번 주제 보너스 +
SalaryConfig.CHATTERBOX_TOPICS = 30 -- 🗣️ 사내 수다왕 업적: 수다 주제 몇 개 수집 (주제가 100개 넘게 늘어서 15 → 30)

-- 🤝 동료 친밀도 (동료 이름마다 점수, 저장돼요)
SalaryConfig.FRIEND_LEVELS = { 6, 16, 30, 50 } -- ❤️ 1~4개가 되는 점수
SalaryConfig.FRIEND_MAX = 60 -- 점수 최대
SalaryConfig.FRIEND_TOPIC = 2 -- 수다 주제를 끝까지 하면 +
SalaryConfig.FRIEND_GOOD = 1 -- 좋은 맞장구 +
SalaryConfig.FRIEND_BAD = 3 -- 눈치 없는 맞장구 - (삐져요)
SalaryConfig.FRIEND_BONUS_PER_LEVEL = 0.1 -- ❤️ 하나마다 수다 보너스 +10%
SalaryConfig.FRIEND_WHISPER_LEVEL = 3 -- ❤️❤️❤️부터 "쉿! 부장님 와요" 귓속말
SalaryConfig.FRIEND_WHISPER_BOSS = 30 -- 부장님이 내게서 이 거리 안으로 다가오면
SalaryConfig.FRIEND_WHISPER_NEAR = 16 -- 친한 동료가 내 근처(이 거리 안)에 있을 때만
SalaryConfig.FRIEND_WHISPER_COOLDOWN = 45 -- 귓속말 쿨타임 (초)
SalaryConfig.FRIEND_STAMP_LEVEL = 4 -- ❤️❤️❤️❤️ 단짝: 결재 도장 2개 몫

-- 친밀도 점수 → ❤️ 개수 (0~4)
function SalaryConfig.friendLevel(points: number?): number
	local level = 0
	for i, need in SalaryConfig.FRIEND_LEVELS do
		if (points or 0) >= need then
			level = i
		end
	end
	return level
end

-- ❤️❤️🖤🖤 모양
function SalaryConfig.friendHearts(points: number?): string
	local level = SalaryConfig.friendLevel(points)
	return string.rep("❤️", level) .. string.rep("🖤", #SalaryConfig.FRIEND_LEVELS - level)
end
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
		unlockRank = 2, -- 🛒 사원부터 (꾸미기 쇼핑몰도 여기서 열려요)
		payLabel = "장바구니 수당",
		hint = "마우스 클릭만 하니 일하는 것처럼 보이기도 해요. 복귀 1초.",
	},
	sleep = {
		emoji = "😴",
		name = "엎드려 낮잠",
		income = 14,
		detect = 45, -- (밸런스: 70 → 45)
		returnTime = 1.2, -- (2 → 1.2)
		noise = 0.25, -- (0.35 → 0.25)
		payLabel = "낮잠 수당",
		hint = "고수입! 코 고는 소리 주의. 일어나는 데 1.2초.",
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
	rooftop = {
		emoji = "🌬️",
		name = "옥상에서 바람 쐬기",
		income = 9,
		detect = 25,
		payLabel = "옥상 바람 수당",
		hint = "🚪 엘리베이터로 옥상에! 👮 옥상 경비원 눈만 피하면 돼요. 자리 부재 게이지는 차요.",
	},
	street = {
		emoji = "🛍️",
		name = "단지 산책",
		income = 9,
		detect = 25,
		payLabel = "단지 산책 수당",
		hint = "🏙️ 회사 단지에 있으면 돼요 (엘리베이터로 1층). 건물 안 0.8배 · 그늘이나 우리 회사 창에서 안 보이는 곳 1배 · 창에서 보이는 탁 트인 곳 1.4배! 자리를 오래 비우면 티 나요, 👮 경비원도 조심!",
	},
	hiding = {
		emoji = "📦",
		name = "상자 속에 숨기",
		income = 3,
		detect = 25,
		payLabel = "숨바꼭질 수당",
		hint = "📦 옥상 큰 상자 속에 쏙! 밖에서는 안 보여요. 대신 답답해서 오래는 못 있어요.",
	},
	lounger = {
		emoji = "🏖️",
		name = "옥상 선베드 일광욕",
		income = 15,
		detect = 45,
		payLabel = "일광욕 수당",
		hint = "옥상 선베드에 누우면 최고의 휴식. 부장님이 올라오면 바로 들켜요!",
	},
	video = {
		emoji = "🎧",
		name = "화상회의 하는 척",
		income = 10,
		detect = 15,
		returnTime = 0.5,
		unlockRank = 2,
		payLabel = "회의 참석(?) 수당",
		hint = "사원부터. 회의 중인 척이라 잘 안 들켜요. 대신 가끔 질문이 오면 6초 안에 대답!",
	},
	recline = {
		emoji = "🛌",
		name = "의자 젖히고 꿀잠",
		income = 20,
		detect = 55, -- (밸런스: 85 → 55)
		returnTime = 1.8, -- (3 → 1.8)
		noise = 0.3, -- (0.45 → 0.3)
		unlockRank = 4,
		payLabel = "꿀잠 수당",
		hint = "대리의 특권. 최고 수입이지만 일어나는 데 1.8초!",
	},
	returning = {
		emoji = "😳",
		name = "복귀 중",
		income = 0,
		detect = 45, -- 허둥지둥 일어나는 중도 덜 수상하게 (70 → 45)
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
		detect = 7.5, -- 그냥 걸어 다니는 건 덜 수상해요 (예전 15)
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
		name = "사탕 쉼터에서 사탕 물기",
		income = 11,
		detect = 25,
		payLabel = "사탕 쉼터 수당",
		hint = "🌳 단지 공원 남서쪽 숲속 정자 \"사탕 쉼터\"(금연! 사탕만!)에 서 있으면 돼요. 자리를 오래 비우면 티 나요.",
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
	gym = {
		emoji = "🏋️",
		name = "체력 단련실에서 운동",
		income = 10,
		detect = 25,
		payLabel = "체력 단련 수당",
		hint = "🏋️ 체력 단련실 운동기구에 [E]! 땀 흘리는 동안 돈도 벌고 체력 스탯도 올라요. 자리 부재 게이지는 차요.",
	},
	fired = {
		emoji = "📦",
		name = "해고됨",
		income = 0,
		detect = 0,
	},
} :: { [string]: StateInfo }

---------------------------------------------------------------------------
-- 🏋️ 체력 단련실 (두 회사 모두 사무실 뒤쪽 별관)
--   운동기구 의자(GymSeat)에 [E] → "gym" 상태 (돈 + 자리 부재 게이지)
--   GYM_STAT_SECONDS초 운동할 때마다 그 기구가 키우는 스탯이 +1 (profile.fitness)
--   pose: 내 캐릭터 운동 자세 (client/Poses.luau)
--   💪 스탯 FITNESS_POINTS_PER_LEVEL점마다 Lv.1 (최대 Lv.FITNESS_MAX_LEVEL) → 레벨만큼 효과 (아래 FitnessEffects)
--   📅 스탯이 오르는 건 하루 GYM_DAILY_SETS번까지 (그다음은 그냥 농땡이로 운동해요)
---------------------------------------------------------------------------
SalaryConfig.GYM_STAT_SECONDS = 15 -- 🏋️ 운동 게이지가 꽉 차는 시간 (초): 다 차야 스탯 +1, 중간에 내리면 처음부터
SalaryConfig.GYM_DAILY_SETS = 3 -- 📅 하루에 스탯이 오르는 운동 횟수 (게이지 꽉 채우기)
SalaryConfig.FITNESS_POINTS_PER_LEVEL = 10 -- 스탯 10점마다 레벨 +1
SalaryConfig.FITNESS_MAX_LEVEL = 10
-- 이 기구가 올려 주는 스탯 글자 ("🔋 지구력 · 💪 근력")
function SalaryConfig.gymStatText(machineId: string): string
	local machine = SalaryConfig.GymMachines[machineId]
	if not machine then
		return ""
	end
	local parts = {}
	for _, statId in machine.stats do
		local stat = SalaryConfig.getFitnessStat(statId)
		if stat then
			table.insert(parts, `{stat.emoji} {stat.name}`)
		end
	end
	return table.concat(parts, " · ")
end
SalaryConfig.FitnessStats = {
	{ id = "strength", emoji = "💪", name = "근력" },
	{ id = "stamina", emoji = "🔋", name = "지구력" },
	{ id = "agility", emoji = "⚡", name = "민첩성" },
	{ id = "flexibility", emoji = "🤸", name = "유연성" },
	{ id = "balance", emoji = "⚖️", name = "균형감" },
}
function SalaryConfig.getFitnessStat(statId: string)
	for _, stat in SalaryConfig.FitnessStats do
		if stat.id == statId then
			return stat
		end
	end
	return nil
end
SalaryConfig.GymMachines = {
	treadmill = { emoji = "🏃", name = "러닝머신", pose = "treadmill", stats = { "stamina" } },
	bench = { emoji = "🏋️", name = "벤치프레스", pose = "bench", stats = { "strength" } },
	bike = { emoji = "🚴", name = "실내 자전거", pose = "bike", stats = { "stamina" } },
	rowing = { emoji = "🚣", name = "로잉머신", pose = "row", stats = { "stamina", "strength" } }, -- 전신 운동이라 두 개!
	sandbag = { emoji = "🥊", name = "샌드백", pose = "punch", stats = { "agility" } },
	stretch = { emoji = "🤸", name = "스트레칭 매트", pose = "stretch", stats = { "flexibility" } },
	balance = { emoji = "⚖️", name = "밸런스 볼", pose = "balance", stats = { "balance" } },
} :: { [string]: { emoji: string, name: string, pose: string, stats: { string } } }

-- 💪 스탯 레벨 (점수 10점마다 Lv.1, 최대 Lv.10)
function SalaryConfig.fitnessLevel(points: number?): number
	return math.clamp(math.floor((tonumber(points) or 0) / SalaryConfig.FITNESS_POINTS_PER_LEVEL), 0, SalaryConfig.FITNESS_MAX_LEVEL)
end

-- 🏋️ 스탯 효과: 최대 레벨(10)에서 max만큼, 레벨에 비례해요 (Lv.3 = max의 30%)
--   kind: "plusPct"(+%) / "minusPct"(-%) / "plusSec"(+초) → 화면 글자 모양
--   서버(판정)와 화면(설명·조준선)이 같은 숫자를 써요
SalaryConfig.FitnessEffects = {
	strength = {
		{ id = "carry", emoji = "📦", label = "택배 느려짐", max = 0.5, kind = "minusPct" }, -- 택배 들고 느려지는 정도
		{ id = "hoop", emoji = "🏀", label = "농구 성공 범위", max = 0.2, kind = "plusPct" }, -- 슛 게이지 초록·노랑·주황 칸 넓이
	},
	stamina = {
		{ id = "away", emoji = "🖥️", label = "자리 부재 게이지 버티기", max = 0.4, kind = "plusPct" }, -- 게이지가 꽉 차는 시간
		{ id = "hunch", emoji = "🤨", label = "오래 농땡이 눈치", max = 30, kind = "plusSec" }, -- SLACK_HUNCH_AFTER에 더해요
	},
	agility = {
		{ id = "return", emoji = "⏪", label = "복귀 시간", max = 0.3, kind = "minusPct" },
		{ id = "walk", emoji = "🏃", label = "걷는 속도", max = 0.1, kind = "plusPct" },
	},
	flexibility = {
		{ id = "hide", emoji = "📦", label = "상자 숨기", max = 15, kind = "plusSec" }, -- HIDE_MAX에 더해요
		{ id = "sleep", emoji = "😴", label = "졸기·의자 젖히기 들킴", max = 0.2, kind = "minusPct" },
	},
	balance = {
		{ id = "claw", emoji = "🧸", label = "인형 뽑기 미끄러짐", max = 0.3, kind = "minusPct" },
		{ id = "aim", emoji = "🎯", label = "다트·✈️ 비행기 조준선", max = 0.6, kind = "plusPct" },
	},
} :: { [string]: { { id: string, emoji: string, label: string, max: number, kind: string } } }
-- 레벨이 오를 때 한 줄 알림 ("💪 근력 Lv.3! 택배가 가벼워졌어요")
SalaryConfig.FitnessLevelUpText = {
	strength = "📦 택배 가볍게 · 🏀 슛 정확",
	stamina = "🖥️ 자리 비우기 더 오래",
	agility = "🏃 더 빨리 걷고 복귀",
	flexibility = "📦 숨기 더 오래 · 😴 덜 들킴",
	balance = "🎯 손이 더 정확해요",
}
-- 효과 id → (스탯 id, 효과 정보)
local FITNESS_EFFECT_BY_ID: { [string]: { statId: string, info: any } } = {}
for statId, list in SalaryConfig.FitnessEffects do
	for _, info in list do
		FITNESS_EFFECT_BY_ID[info.id] = { statId = statId, info = info }
	end
end

-- 이 레벨에서 효과 값 (예: carry Lv.3 → 0.15)
function SalaryConfig.fitnessEffect(effectId: string, level: number?): number
	local entry = FITNESS_EFFECT_BY_ID[effectId]
	if not entry then
		return 0
	end
	return entry.info.max * math.clamp(tonumber(level) or 0, 0, SalaryConfig.FITNESS_MAX_LEVEL) / SalaryConfig.FITNESS_MAX_LEVEL
end

-- 효과 하나를 글자로 ("📦 택배 느려짐 -15%")
local function fitnessNumberText(value: number): string
	if math.abs(value - math.floor(value + 0.5)) < 0.01 then
		return tostring(math.floor(value + 0.5))
	end
	return string.format("%.1f", value)
end
function SalaryConfig.fitnessEffectLine(info: { emoji: string, label: string, max: number, kind: string }, level: number?): string
	local value = info.max * math.clamp(tonumber(level) or 0, 0, SalaryConfig.FITNESS_MAX_LEVEL) / SalaryConfig.FITNESS_MAX_LEVEL
	local amount = if info.kind == "plusSec" then `+{fitnessNumberText(value)}초`
		elseif info.kind == "minusPct" then `-{fitnessNumberText(value * 100)}%`
		else `+{fitnessNumberText(value * 100)}%`
	return `{info.emoji} {info.label} {amount}`
end
-- 스탯 하나의 효과 전부 ("📦 택배 느려짐 -15% · 🏀 농구 성공 범위 +6%")
function SalaryConfig.fitnessEffectText(statId: string, level: number?): string
	local parts = {}
	for _, info in SalaryConfig.FitnessEffects[statId] or {} do
		table.insert(parts, SalaryConfig.fitnessEffectLine(info, level))
	end
	return table.concat(parts, " · ")
end

-- 플레이어의 체력 스탯 (서버가 넣어 주는 "Fitness" 속성 JSON) → 없는 칸은 0
local HttpService = game:GetService("HttpService")
function SalaryConfig.playerFitness(player: Player): { [string]: number }
	local ok, value = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Fitness") or "{}")
	end)
	local result = {}
	for _, stat in SalaryConfig.FitnessStats do
		result[stat.id] = if ok and typeof(value) == "table" then tonumber(value[stat.id]) or 0 else 0
	end
	return result
end
function SalaryConfig.playerFitnessLevel(player: Player, statId: string): number
	return SalaryConfig.fitnessLevel(SalaryConfig.playerFitness(player)[statId])
end
-- 스탯 표(profile.fitness 같은 것)로 효과 값 (없는 칸은 0)
function SalaryConfig.fitnessEffectFor(fitness: { [string]: any }?, effectId: string): number
	local entry = FITNESS_EFFECT_BY_ID[effectId]
	if not entry or typeof(fitness) ~= "table" then
		return 0
	end
	return SalaryConfig.fitnessEffect(effectId, SalaryConfig.fitnessLevel(tonumber((fitness :: any)[entry.statId]) or 0))
end
-- 플레이어 레벨로 효과 값 (서버·화면 어디서나)
function SalaryConfig.playerFitnessEffect(player: Player, effectId: string): number
	return SalaryConfig.fitnessEffectFor(SalaryConfig.playerFitness(player), effectId)
end
-- ⚡ 걷는 속도: base(보통 16) × (1 + 민첩성 보너스)
function SalaryConfig.walkSpeed(player: Player, base: number?): number
	return (base or 16) * (1 + SalaryConfig.playerFitnessEffect(player, "walk"))
end
-- 📦 택배 들고 걷는 속도: 느려지는 만큼을 💪 근력으로 줄이고, ⚡ 민첩성 보너스도 곱해요
function SalaryConfig.carrySpeed(player: Player, slowSpeed: number): number
	local slowdown = math.max(0, 16 - slowSpeed) * (1 - SalaryConfig.playerFitnessEffect(player, "carry"))
	return SalaryConfig.walkSpeed(player, 16 - slowdown)
end

-- 자리에서 고를 수 있는 행동 (숫자키 1~9, 직급이 오르면 하나씩 열려요)
---------------------------------------------------------------------------
-- 📱 폰 게임: [폰 게임] 버튼 → 게임을 골라야 농땡이 시작 (창을 닫으면 일하기로 복귀)
---------------------------------------------------------------------------
SalaryConfig.PhoneGames = {
	{ id = "mines", emoji = "💣", name = "지뢰 피하기", description = "5×5 칸에서 지뢰를 피해 돈을 모아요. 언제든 스톱!" },
	{ id = "baseball", emoji = "⚾", name = "숫자 야구", description = "서로 다른 숫자 3개를 맞혀요. 스트라이크·볼 힌트로 추리! 적게 물어볼수록 상금 ↑" },
	{ id = "shapes", emoji = "🧩", name = "도형 맞추기", description = "조각들을 끼워서 하트·집·화살표… 모양을 꽉 채워요. 시간 안에 성공하면 상금!" },
}

-- ⚾ 숫자 야구: 1~9 중 서로 다른 숫자 BASEBALL_DIGITS개를 맞혀요
--   ⚾ 스트라이크 = 숫자와 자리 모두 맞음 · 🟢 볼 = 숫자만 맞음 · ❌ 아웃 = 하나도 없음
--   BASEBALL_MAX_TRIES번 안에 맞히면 성공! 적게 물어볼수록 상금이 커요 (하루 BASEBALL_DAILY_PRIZES번까지 상금)
SalaryConfig.BASEBALL_DIGITS = 3
SalaryConfig.BASEBALL_MAX_TRIES = 9
SalaryConfig.BASEBALL_DAILY_PRIZES = 8
-- 몇 번째에 맞혔나 → 상금 (보통 5~6번이면 맞혀요)
SalaryConfig.BaseballPrizes = { 1500, 1200, 900, 680, 500, 360, 260, 180, 120 }

-- 🧩 도형 맞추기: 판(모양)을 조각 n개로 나눈 퍼즐 30개 중 하나가 랜덤으로 나와요
--   판 모양: 사각형·십자가·L자·계단·T자·집·화살표·하트·U자·마름모·번개·고리…
--   조각은 돌리거나 뒤집을 수 없어요 (보이는 모양 그대로). 모든 칸을 빈틈없이 채우면 성공!
--   ⏱️ 제한 시간 = SHAPES_TIME_BASE + 조각 수 × SHAPES_TIME_PER_PIECE (초)
--   💰 상금 = 조각 수 × SHAPES_PRIZE_PER_PIECE + 남은 초 × SHAPES_PRIZE_PER_SECOND
--      (하루 SHAPES_DAILY_PRIZES번까지만 상금. 통장으로 바로, 경력·실적 목표에는 안 들어가요)
SalaryConfig.SHAPES_TIME_BASE = 25
SalaryConfig.SHAPES_TIME_PER_PIECE = 12
SalaryConfig.SHAPES_PRIZE_PER_PIECE = 180
SalaryConfig.SHAPES_PRIZE_PER_SECOND = 12
SalaryConfig.SHAPES_DAILY_PRIZES = 8
-- board: 채워야 할 칸 "x,y;x,y…" / pieces: 조각들 "조각1 칸들|조각2 칸들|…" (모두 정답에 쓰이는 모양 그대로)
SalaryConfig.ShapePuzzles = {
	{ name = "사각형 5×5", board = "0,0;0,1;0,2;0,3;0,4;1,0;1,1;1,2;1,3;1,4;2,0;2,1;2,2;2,3;2,4;3,0;3,1;3,2;3,3;3,4;4,0;4,1;4,2;4,3;4,4", pieces = "0,1;1,0;1,1;2,0;2,1|0,0;0,1;1,0;1,1|0,0;1,0;2,0;3,0;4,0|0,1;1,1;2,0;2,1|0,0;1,0;1,1;2,0|0,0;0,1;1,1" },
	{ name = "사각형 5×5", board = "0,0;0,1;0,2;0,3;0,4;1,0;1,1;1,2;1,3;1,4;2,0;2,1;2,2;2,3;2,4;3,0;3,1;3,2;3,3;3,4;4,0;4,1;4,2;4,3;4,4", pieces = "0,0;0,1;1,0;2,0;3,0|0,1;0,2;1,0;1,1;1,2|0,1;1,0;1,1;2,1;3,1|0,0;1,0;2,0;3,0|0,0;0,1;1,0|0,0;0,1;0,2" },
	{ name = "직사각형 6×4", board = "0,0;0,1;0,2;0,3;1,0;1,1;1,2;1,3;2,0;2,1;2,2;2,3;3,0;3,1;3,2;3,3;4,0;4,1;4,2;4,3;5,0;5,1;5,2;5,3", pieces = "0,0;0,1;0,2;0,3|0,0;1,0;1,1;1,2|0,1;1,0;1,1;2,1|0,0;0,1;0,2;0,3;1,0|0,0;0,1;1,1|0,0;0,1;1,0;1,1" },
	{ name = "십자가", board = "0,2;0,3;1,2;1,3;2,0;2,1;2,2;2,3;2,4;2,5;3,0;3,1;3,2;3,3;3,4;3,5;4,2;4,3;5,2;5,3", pieces = "0,0;0,1;0,2;1,0|0,0;0,1;1,0;2,0|0,0;1,0;1,1;1,2|0,0;1,0;2,0;2,1|0,0;0,1;1,0;1,1" },
	{ name = "십자가", board = "0,2;0,3;1,2;1,3;2,0;2,1;2,2;2,3;2,4;2,5;3,0;3,1;3,2;3,3;3,4;3,5;4,2;4,3;5,2;5,3", pieces = "0,1;1,0;1,1|0,1;0,2;1,0;1,1;1,2|0,0;1,0;1,1;2,0;2,1|0,0;0,1;1,0;1,1|0,0;0,1;1,0" },
	{ name = "십자가", board = "0,2;0,3;1,2;1,3;2,0;2,1;2,2;2,3;2,4;2,5;3,0;3,1;3,2;3,3;3,4;3,5;4,2;4,3;5,2;5,3", pieces = "0,0;0,1;1,1|0,0;0,1;1,0|0,1;1,1;2,1;3,0;3,1|0,0;1,0;2,0;3,0;3,1|0,0;0,1;1,0;1,1" },
	{ name = "L자", board = "0,0;0,1;0,2;0,3;0,4;1,0;1,1;1,2;1,3;1,4;2,0;2,1;2,2;2,3;2,4;3,3;3,4;4,3;4,4", pieces = "0,0;1,0;2,0;2,1|0,0;0,1;1,0;1,1|0,0;1,0;2,0;3,0|0,0;0,1;1,1|0,0;1,0;1,1;1,2" },
	{ name = "L자", board = "0,0;0,1;0,2;0,3;0,4;1,0;1,1;1,2;1,3;1,4;2,0;2,1;2,2;2,3;2,4;3,3;3,4;4,3;4,4", pieces = "0,0;0,1;1,0;1,1|0,2;1,0;1,1;1,2|0,0;0,1;1,0;2,0|0,0;1,0;2,0|0,1;0,2;1,0;1,1" },
	{ name = "계단", board = "0,0;0,1;0,2;0,3;0,4;1,0;1,1;1,2;1,3;1,4;2,1;2,2;2,3;2,4;3,2;3,3;3,4;4,3;4,4", pieces = "0,1;1,0;1,1|0,0;1,0;1,1;1,2;2,1;2,2|0,0;0,1;0,2;0,3;1,2;1,3|0,1;1,1;2,0;2,1" },
	{ name = "계단", board = "0,0;0,1;0,2;0,3;0,4;1,0;1,1;1,2;1,3;1,4;2,1;2,2;2,3;2,4;3,2;3,3;3,4;4,3;4,4", pieces = "0,0;0,1;0,2;1,0;1,1;2,1|0,0;0,1;1,0;2,0|0,0;0,1;1,1|0,0;0,1;1,0;1,1;2,0;2,1" },
	{ name = "모서리 깎은 판", board = "0,1;0,2;0,3;0,4;1,0;1,1;1,2;1,3;1,4;1,5;2,0;2,1;2,2;2,3;2,4;2,5;3,0;3,1;3,2;3,3;3,4;3,5;4,0;4,1;4,2;4,3;4,4;4,5;5,1;5,2;5,3;5,4", pieces = "0,1;1,0;1,1|0,0;1,0;1,1;1,2;2,1|0,0;0,1;0,2;0,3;1,1|0,1;1,0;1,1;1,2;1,3|0,0;0,1;0,2|0,0;0,1;1,1;2,0;2,1|0,0;0,1;1,0;1,1;2,0;2,1" },
	{ name = "모서리 깎은 판", board = "0,1;0,2;0,3;0,4;1,0;1,1;1,2;1,3;1,4;1,5;2,0;2,1;2,2;2,3;2,4;2,5;3,0;3,1;3,2;3,3;3,4;3,5;4,0;4,1;4,2;4,3;4,4;4,5;5,1;5,2;5,3;5,4", pieces = "0,0;1,0;1,1;2,1|0,0;1,0;2,0;2,1|0,0;1,0;1,1;1,2;1,3|0,0;0,1;1,0;1,1;2,0|0,0;0,1;1,0;1,1|0,0;0,1;0,2;1,0;1,1|0,0;1,0;2,0;2,1;3,0" },
	{ name = "T자", board = "0,0;0,1;1,0;1,1;2,0;2,1;2,2;2,3;2,4;2,5;3,0;3,1;3,2;3,3;3,4;3,5;4,0;4,1;5,0;5,1", pieces = "0,0;0,1;1,1|0,0;0,1;1,0;1,1|0,0;0,1;1,0;2,0|0,0;0,1;0,2;0,3;0,4|0,0;1,0;1,1;1,2" },
	{ name = "T자", board = "0,0;0,1;1,0;1,1;2,0;2,1;2,2;2,3;2,4;2,5;3,0;3,1;3,2;3,3;3,4;3,5;4,0;4,1;5,0;5,1", pieces = "0,0;0,1;0,2;1,1|0,0;1,0;1,1|0,0;0,1;0,2;0,3|0,0;0,1;0,2|0,0;0,1;1,0;1,1;2,0;2,1" },
	{ name = "T자", board = "0,0;0,1;1,0;1,1;2,0;2,1;2,2;2,3;2,4;2,5;3,0;3,1;3,2;3,3;3,4;3,5;4,0;4,1;5,0;5,1", pieces = "0,0;0,1;1,0;2,0|0,0;0,1;1,0;1,1;2,0|0,0;1,0;2,0|0,2;1,0;1,1;1,2|0,0;0,1;0,2;0,3" },
	{ name = "집", board = "0,2;1,1;1,2;1,3;1,4;1,5;2,0;2,1;2,2;2,3;2,4;2,5;3,0;3,1;3,2;3,3;3,4;3,5;4,1;4,2;4,3;4,4;4,5;5,2", pieces = "0,0;0,1;0,2;0,3;1,3|0,1;1,0;1,1;2,0;2,1|0,1;1,0;1,1;2,1|0,0;0,1;1,0;1,1;1,2|0,0;1,0;1,1;1,2;1,3" },
	{ name = "집", board = "0,2;1,1;1,2;1,3;1,4;1,5;2,0;2,1;2,2;2,3;2,4;2,5;3,0;3,1;3,2;3,3;3,4;3,5;4,1;4,2;4,3;4,4;4,5;5,2", pieces = "0,0;0,1;0,2;1,0;1,1;1,2|0,0;0,1;0,2;1,0;2,0|0,2;1,0;1,1;1,2|0,2;1,1;1,2;2,0;2,1;2,2|0,0;0,1;1,1" },
	{ name = "집", board = "0,2;1,1;1,2;1,3;1,4;1,5;2,0;2,1;2,2;2,3;2,4;2,5;3,0;3,1;3,2;3,3;3,4;3,5;4,1;4,2;4,3;4,4;4,5;5,2", pieces = "0,0;1,0;2,0|0,0;0,1;1,0;1,1;2,0;2,1|0,1;1,0;1,1;2,0|0,0;0,1;1,0;1,1;1,2;2,1|0,0;0,1;0,2;1,0;2,0" },
	{ name = "화살표", board = "0,2;0,3;1,2;1,3;2,2;2,3;3,2;3,3;4,0;4,1;4,2;4,3;4,4;4,5;5,1;5,2;5,3;5,4;6,2;6,3", pieces = "0,0;0,1;0,2;1,1|0,0;0,1;1,1|0,0;1,0;1,1;1,2;2,0;2,1|0,0;1,0;1,1;2,0|0,0;1,0;1,1" },
	{ name = "화살표", board = "0,2;0,3;1,2;1,3;2,2;2,3;3,2;3,3;4,0;4,1;4,2;4,3;4,4;4,5;5,1;5,2;5,3;5,4;6,2;6,3", pieces = "0,2;1,0;1,1;1,2;1,3|0,0;1,0;2,0;3,0|0,0;0,1;1,0|0,0;0,1;0,2;1,1;1,2|0,0;1,0;2,0" },
	{ name = "하트", board = "0,1;0,2;1,0;1,1;1,2;1,3;2,0;2,1;2,2;2,3;2,4;3,1;3,2;3,3;3,4;3,5;4,0;4,1;4,2;4,3;4,4;5,0;5,1;5,2;5,3;6,1;6,2", pieces = "0,0;0,1;1,0;1,1|0,1;0,2;1,0;1,1;1,2|0,0;1,0;1,1|0,0;0,1;0,2;1,1;1,2|0,0;1,0;2,0|0,0;1,0;1,1;1,2|0,0;0,1;1,0" },
	{ name = "하트", board = "0,1;0,2;1,0;1,1;1,2;1,3;2,0;2,1;2,2;2,3;2,4;3,1;3,2;3,3;3,4;3,5;4,0;4,1;4,2;4,3;4,4;5,0;5,1;5,2;5,3;6,1;6,2", pieces = "0,0;1,0;1,1;2,0|0,0;0,1;1,1|0,0;0,1;1,0;1,1|0,2;1,1;1,2;2,0;2,1;2,2|0,0;0,1;0,2;1,1;1,2|0,0;1,0;2,0;3,0;4,0" },
	{ name = "하트", board = "0,1;0,2;1,0;1,1;1,2;1,3;2,0;2,1;2,2;2,3;2,4;3,1;3,2;3,3;3,4;3,5;4,0;4,1;4,2;4,3;4,4;5,0;5,1;5,2;5,3;6,1;6,2", pieces = "0,0;0,1;1,0;1,1|0,1;1,1;1,2;2,0;2,1|0,0;1,0;1,1;2,1|0,0;0,1;1,0;1,1;1,2;2,1|0,1;1,0;1,1;2,1|0,0;1,0;1,1;2,0" },
	{ name = "U자", board = "0,0;0,1;0,2;0,3;0,4;1,0;1,1;1,2;1,3;1,4;2,3;2,4;3,3;3,4;4,0;4,1;4,2;4,3;4,4;5,0;5,1;5,2;5,3;5,4", pieces = "0,1;1,0;1,1;2,0;2,1|0,0;0,1;0,2;1,0;1,1;1,2|0,0;0,1;0,2;0,3|0,0;0,1;1,0;1,1;2,0;2,1|0,0;0,1;0,2" },
	{ name = "U자", board = "0,0;0,1;0,2;0,3;0,4;1,0;1,1;1,2;1,3;1,4;2,3;2,4;3,3;3,4;4,0;4,1;4,2;4,3;4,4;5,0;5,1;5,2;5,3;5,4", pieces = "0,0;0,1;0,2;1,1;1,2|0,0;0,1;0,2;1,0;1,1|0,1;1,0;1,1;2,1;3,1|0,0;1,0;2,0;3,0|0,0;0,1;1,0;1,1;1,2" },
	{ name = "마름모", board = "0,3;1,2;1,3;1,4;2,1;2,2;2,3;2,4;2,5;3,0;3,1;3,2;3,3;3,4;3,5;4,1;4,2;4,3;4,4;4,5;5,2;5,3;5,4;6,3", pieces = "0,1;1,0;1,1;2,1|0,0;0,1;1,1;1,2;2,2|0,2;1,1;1,2;2,0;2,1|0,2;1,1;1,2;2,0;2,1;3,0|0,0;1,0;1,1;2,0" },
	{ name = "마름모", board = "0,3;1,2;1,3;1,4;2,1;2,2;2,3;2,4;2,5;3,0;3,1;3,2;3,3;3,4;3,5;4,1;4,2;4,3;4,4;4,5;5,2;5,3;5,4;6,3", pieces = "0,2;1,1;1,2;2,0;2,1;2,2|0,0;0,1;1,0;1,1;1,2;2,1|0,1;1,1;1,2;2,0;2,1|0,1;1,0;1,1|0,0;0,1;0,2;1,1" },
	{ name = "번개", board = "0,0;0,1;1,0;1,1;2,0;2,1;2,2;2,3;3,0;3,1;3,2;3,3;4,2;4,3;4,4;4,5;5,2;5,3;5,4;5,5;6,4;6,5;7,4;7,5", pieces = "0,0;1,0;2,0;2,1|0,0;1,0;2,0;3,0|0,2;1,0;1,1;1,2;2,2;3,2|0,0;0,1;1,1;2,1|0,0;0,1;1,0;1,1;2,0;2,1" },
	{ name = "번개", board = "0,0;0,1;1,0;1,1;2,0;2,1;2,2;2,3;3,0;3,1;3,2;3,3;4,2;4,3;4,4;4,5;5,2;5,3;5,4;5,5;6,4;6,5;7,4;7,5", pieces = "0,2;1,0;1,1;1,2|0,0;1,0;1,1|0,0;1,0;2,0|0,1;1,0;1,1;2,0;2,1|0,0;0,1;1,1;2,1;2,2|0,0;1,0;2,0;2,1" },
	{ name = "고리", board = "0,0;0,1;0,2;0,3;0,4;0,5;1,0;1,1;1,2;1,3;1,4;1,5;2,0;2,1;2,4;2,5;3,0;3,1;3,4;3,5;4,0;4,1;4,2;4,3;4,4;4,5;5,0;5,1;5,2;5,3;5,4;5,5", pieces = "0,0;0,1;0,2;0,3;0,4|0,0;0,1;1,0|0,0;0,1;1,0;1,1;2,1|0,0;1,0;2,0;2,1|0,0;0,1;0,2;0,3|0,1;1,0;1,1|0,1;1,1;2,0;2,1|0,0;0,1;1,1;2,1" },
}

-- "x,y;x,y" → { {x, y}, … }
function SalaryConfig.parseCells(text: string): { { number } }
	local cells = {}
	for pair in string.gmatch(text, "[^;]+") do
		local x, y = string.match(pair, "(%-?%d+),(%-?%d+)")
		table.insert(cells, { tonumber(x) :: number, tonumber(y) :: number })
	end
	return cells
end

-- 퍼즐 하나 → 판 칸들 + 조각 목록
function SalaryConfig.getShapePuzzle(index: number): ({ { number } }, { { { number } } }, string)
	local puzzle = SalaryConfig.ShapePuzzles[index]
	local pieces = {}
	for pieceText in string.gmatch(puzzle.pieces, "[^|]+") do
		table.insert(pieces, SalaryConfig.parseCells(pieceText))
	end
	return SalaryConfig.parseCells(puzzle.board), pieces, puzzle.name
end

-- 조각 칸들을 왼쪽 위(0,0)에 붙이고 정렬 (모양 비교용)
function SalaryConfig.normalizeCells(cells: { { number } }): { { number } }
	local minX, minY = math.huge, math.huge
	for _, c in cells do
		minX = math.min(minX, c[1])
		minY = math.min(minY, c[2])
	end
	local out = {}
	for _, c in cells do
		table.insert(out, { c[1] - minX, c[2] - minY })
	end
	table.sort(out, function(a, b)
		return if a[2] == b[2] then a[1] < b[1] else a[2] < b[2]
	end)
	return out
end

-- 시계 방향으로 90° 돌리기 (돌린 뒤 다시 왼쪽 위로)
function SalaryConfig.rotateCells(cells: { { number } }): { { number } }
	local out = {}
	for _, c in cells do
		table.insert(out, { -c[2], c[1] })
	end
	return SalaryConfig.normalizeCells(out)
end

-- 💣 지뢰 피하기
--   배팅 금액 + 지뢰 수를 고르고 시작 → 빈칸을 열 때마다 받을 돈이 커져요 → [스톱]하면 그 돈을 받아요
--   지뢰를 밟으면 건 돈을 잃어요. (당첨금은 통장으로 바로, 경력·실적 목표에는 안 들어가요)
--   💡 밸런스: 받을 돈 = 건 돈 × 배당
--      배당 = (1 - 수수료) × "지금까지 지뢰를 안 밟을 확률"의 역수  → 오래 할수록 기대값이 아주 살짝 손해 (도박은 결국 회사가 이겨요)
--      예) 지뢰 3개: 1칸 x1.10 · 3칸 x1.45 · 5칸 x1.96 · 8칸 x3.28 · 10칸 x4.90 · 12칸 x7.80
--          지뢰 5개: 1칸 x1.21 · 3칸 x1.96 · 5칸 x3.32 · 8칸 x8.33 · 10칸 x17.16
--          지뢰 24개: 1칸 x24 (한 방!)   ·   지뢰 1개: 칸마다 아주 조금씩 (안전하지만 짜요)
--      배당은 최대 MINES_MAX_MULT배까지 (닿으면 자동 스톱)
-- 📱 폰 게임은 느긋하게 즐기도록: 의심도는 훨씬 천천히, 부장님도 잘 안 와요
SalaryConfig.PHONE_GAME_SUSPICION = 0.35 -- 들킬 때 의심도 차는 속도 배율 (0.35 = 약 3배 느리게)
SalaryConfig.PHONE_GAME_WATCH = 0.4 -- 부장님이 확인하러 올 확률 배율 (막 시작 10% → 20초 넘으면 최대 34%)
SalaryConfig.MINES_GRID = 5
SalaryConfig.MINES_COUNTS = { 1, 3, 5, 24 }
SalaryConfig.MINES_BETS = { 100, 500, 1000, 5000 }
-- 이 금액은 이 직급부터 걸 수 있어요 (Ranks 번호: 1 인턴 · 2 사원 · 3 주임 · 4 대리 · 5 과장 …)
SalaryConfig.MINES_BET_RANK = { [100] = 1, [500] = 2, [1000] = 3, [5000] = 5 }
SalaryConfig.MINES_EDGE = 0.03 -- 수수료 3%
SalaryConfig.MINES_MAX_MULT = 24

-- 빈칸을 opened개 열었을 때 배당 (0개면 1배 = 건 돈 그대로)
function SalaryConfig.minesMultiplier(opened: number, mines: number): number
	if opened <= 0 then
		return 1
	end
	local cells = SalaryConfig.MINES_GRID * SalaryConfig.MINES_GRID
	local inverse = 1
	for i = 0, opened - 1 do
		inverse *= (cells - i) / (cells - mines - i)
	end
	return math.min((1 - SalaryConfig.MINES_EDGE) * inverse, SalaryConfig.MINES_MAX_MULT)
end

-- 받을 돈 (원 단위로 내림)
function SalaryConfig.minesPayout(bet: number, opened: number, mines: number): number
	return math.floor(bet * SalaryConfig.minesMultiplier(opened, mines))
end

SalaryConfig.DeskActions = { "work", "blank", "webtoon", "phone", "shopping", "sleep", "recline", "snack", "video" }

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
	street: boolean?, -- 🏙️ 눈치 스트리트 디저트집에서 산 간식
}

SalaryConfig.Snacks = {
	{ id = "candy", emoji = "🍬", name = "사탕", seconds = 4, bonus = 200, count = 3, size = Vector3.new(0.6, 0.4, 0.6), color = Color3.fromRGB(255, 120, 160) },
	{ id = "cookie", emoji = "🍪", name = "쿠키", seconds = 7, bonus = 400, count = 2, size = Vector3.new(0.9, 0.25, 0.9), color = Color3.fromRGB(200, 150, 90) },
	{ id = "chocobar", emoji = "🍫", name = "초코바", seconds = 10, bonus = 600, count = 1, size = Vector3.new(1.2, 0.3, 0.5), color = Color3.fromRGB(110, 60, 30) },
	{ id = "donut", emoji = "🍩", name = "도넛", seconds = 14, bonus = 900, count = 1, size = Vector3.new(1, 0.4, 1), color = Color3.fromRGB(240, 170, 200) },
	{ id = "cake", emoji = "🍰", name = "케이크 한 조각", seconds = 20, bonus = 1500, count = 1, size = Vector3.new(1.2, 0.9, 1.2), color = Color3.fromRGB(250, 240, 230) },
	-- 🎂 생일 케이크 이벤트 때만 나와요 (count = 0이라 매일 아침에는 안 놓여요)
	-- 🏙️ 디저트집에서 사는 간식 (count = 0이라 탕비실엔 안 놓여요)
	{ id = "macaron", emoji = "🧁", name = "마카롱", seconds = 8, bonus = 1800, count = 0, size = Vector3.new(0.7, 0.45, 0.7), color = Color3.fromRGB(255, 170, 200), street = true },
	{ id = "croffle", emoji = "🥐", name = "크로플", seconds = 14, bonus = 4000, count = 0, size = Vector3.new(1.2, 0.35, 0.9), color = Color3.fromRGB(220, 160, 80), street = true },
	{ id = "strawcake", emoji = "🍓", name = "딸기 생크림 케이크", seconds = 20, bonus = 7000, count = 0, size = Vector3.new(1.2, 1, 1.2), color = Color3.fromRGB(255, 240, 240), street = true },
	-- 🍢 대충 분식에서 사는 간식 (count = 0이라 탕비실엔 안 놓여요)
	{ id = "tteokbokki", emoji = "🍢", name = "떡볶이", seconds = 8, bonus = 1100, count = 0, size = Vector3.new(0.9, 0.5, 0.9), color = Color3.fromRGB(214, 70, 50), street = true },
	{ id = "gimbap", emoji = "🍙", name = "김밥", seconds = 12, bonus = 1900, count = 0, size = Vector3.new(1.3, 0.4, 0.6), color = Color3.fromRGB(40, 50, 40), street = true },
	{ id = "rabokki", emoji = "🍜", name = "라볶이 세트", seconds = 18, bonus = 3400, count = 0, size = Vector3.new(1.3, 0.6, 1.3), color = Color3.fromRGB(226, 110, 60), street = true },
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
--   basePay: 하루 기본급 (출근만 해도 받는 돈 → 60% 너프: 진급은 농땡이 실력 위주로) / bonus: 농땡이 수입 배율 / quota: 하루 최소 업무(초) = 내 자리에 앉아 있던 시간 (일하기·앉아서 농땡이 모두, 근무 시간은 약 370초)
---------------------------------------------------------------------------
SalaryConfig.Ranks = {
	-- penalty: 적발(경고) 1번당 시말서 감봉 — 직급이 높을수록 책임도 커요 (대략 기본급의 1/3)
	-- quotaPenalty: 업무 시간 미달 감봉 — 이것도 직급이 높을수록 커요 (대략 기본급의 1/2)
	-- target: 💰 하루 실적 목표 (기본급 빼고 그날 번 돈 + 보너스). 못 채우면 경고 +1 + 목표의 30% 감봉. 인턴은 없음
	{ name = "인턴", xp = 0, basePay = 1200, bonus = 1.0, quota = 75, penalty = 1000, quotaPenalty = 2000, target = 0 },
	{ name = "사원", xp = 6000, basePay = 1600, bonus = 1.15, quota = 85, penalty = 1300, quotaPenalty = 2500, target = 1150 },
	{ name = "주임", xp = 20000, basePay = 2200, bonus = 1.3, quota = 90, penalty = 1800, quotaPenalty = 3200, target = 1700 },
	{ name = "대리", xp = 50000, basePay = 2800, bonus = 1.5, quota = 100, penalty = 2400, quotaPenalty = 4000, target = 2300 },
	{ name = "과장", xp = 100000, basePay = 3600, bonus = 1.75, quota = 105, penalty = 3000, quotaPenalty = 5000, target = 2850 },
	{ name = "차장", xp = 170000, basePay = 4600, bonus = 2.0, quota = 115, penalty = 3800, quotaPenalty = 6200, target = 3450 },
	{ name = "부장", xp = 260000, basePay = 5800, bonus = 2.3, quota = 120, penalty = 4800, quotaPenalty = 7500, target = 4300 },
	{ name = "이사", xp = 380000, basePay = 7200, bonus = 2.7, quota = 130, penalty = 6000, quotaPenalty = 9000, target = 5150 },
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
	requires: string?, -- 이 아이템을 먼저 가지고 있어야 살 수 있어요 (업그레이드)
	days: number?, -- ⏳ 사용 기한 (근무일 수, 산 날 포함). 다시 사면 기한이 늘어나요
}

SalaryConfig.Items = {
	{ id = "plant", emoji = "🌱", name = "책상 화분", price = 2000, days = 7, description = "마음의 안정. 의심도가 25% 더 빨리 줄어요." },
	{ id = "tumbler", emoji = "🥤", name = "고급 텀블러", price = 3000, days = 7, description = "탕비실에서 커피 타는 척 시간이 40초 → 90초." },
	{ id = "cover", emoji = "🖥️", name = "모니터 가리개", price = 6000, days = 5, description = "화면 농땡이(웹툰, 폰, 쇼핑)가 30% 덜 들켜요." },
	{ id = "earphones", emoji = "🎧", name = "부장 레이더 이어폰", price = 9000, days = 5, description = "발소리 감지 거리 증가 + 부장이 지금 감시 중인지 화면에 표시." },
	{ id = "dummy", emoji = "🧸", name = "대리 출석 인형", price = 12000, days = 5, description = "자리에 인형을 앉혀 둬요. 자리 부재 게이지가 천천히 차요 (110초 → 150초)." },
	{ id = "dummy_pro", emoji = "👔", name = "최고급 대리 출석 마네킹", price = 60000, requires = "dummy", days = 5, description = "정장 입고 타자까지 치는 마네킹. 부재 게이지 240초 + 감사관의 빈자리 사진도 속여요! (인형 필요)" },
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
	{ id = "audit_survivor", emoji = "🔍", name = "감사 생존자", description = "감사 기간에 한 번도 안 걸리고, 감사 보고서 없이 퇴근하기" },
	{ id = "cert_first", emoji = "📚", name = "자기계발러", description = "자격증 처음 따기" },
	{ id = "cert_all", emoji = "🎓", name = "스펙 괴물", description = "자격증 6개 모두 따기" },
	{ id = "coupon_trip", emoji = "✈️", name = "부장님 잘 다녀오세요", description = "쿠폰으로 부장님 출장 보내기" },
	{ id = "coupon_halfday", emoji = "🏖️", name = "반차의 맛", description = "반차권 쓰기" },
	{ id = "upgrade_first", emoji = "⚙️", name = "장비빨", description = "책상 장비 처음 업그레이드하기" },
	{ id = "upgrade_max", emoji = "🏆", name = "풀옵션 책상", description = "책상 장비를 모두 최고 단계로" },
	{ id = "outfit_first", emoji = "👔", name = "출근룩 개시", description = "출근룩 아이템 처음 사기" },
	{ id = "outfit_full", emoji = "🛍️", name = "풀착장", description = "출근룩 모든 칸을 채워 입기" },
	{ id = "outfit_crown", emoji = "👑", name = "사무실의 왕", description = "왕관 쓰고 출근하기" },
	{ id = "hoop_first", emoji = "🏀", name = "옥상 농구 데뷔", description = "옥상 농구에서 첫 골 넣기" },
	{ id = "hoop_perfect", emoji = "🔥", name = "5연속 골인", description = "한 판에 공 5개를 모두 넣기" },
	{ id = "hoop_swish", emoji = "🎯", name = "클린슛 마스터", description = "한 판을 전부 🎯 클린슛으로 끝내기" },
	{ id = "sunset_watch", emoji = "🌅", name = "오늘 하루도 고생했다", description = "옥상에서 노을 감상하기" },
	{ id = "sunset_photo", emoji = "📸", name = "노을 맛집", description = "옥상 포토존에서 노을 사진 찍기" },
	{ id = "sunset_album", emoji = "🖼️", name = "노을 앨범", description = "서로 다른 날 노을 사진 5장 모으기" },
	{ id = "scope_first", emoji = "🔭", name = "관찰자", description = "건너편 빌딩에서 첫 장면 발견하기" },
	{ id = "scope_ten", emoji = "📒", name = "프로 관찰러", description = "관찰 일지 10장면 채우기" },
	{ id = "scope_all", emoji = "🕵️", name = "건너편 빌딩 전문가", description = "관찰 일지 20장면 모두 채우기" },
	{ id = "garden_first", emoji = "🌱", name = "옥상 농부", description = "매점 씨앗을 옥상 텃밭에 심어 처음 수확하기" },
	{ id = "garden_strawberry", emoji = "🍓", name = "딸기 농장주", description = "딸기 수확하기" },
	{ id = "garden_gift", emoji = "🥬", name = "유기농 아부", description = "직접 기른 채소를 부장님께 선물하기" },
	{ id = "garden_clover", emoji = "🍀", name = "행운의 농부", description = "네잎클로버 수확에서 행운 대박 터뜨리기" },
	{ id = "garden_pumpkin", emoji = "🎃", name = "왕호박 농부", description = "6일 걸리는 호박을 끝까지 길러 수확하기" },
	{ id = "garden_master", emoji = "🚜", name = "주말농장 사장님", description = "텃밭에서 30번 수확하기" },
	{ id = "park_gardener", emoji = "🌷", name = "공원 정원사", description = "눈치물산 공원 화단을 모두 꽃피우기" },
	{ id = "park_rainbow", emoji = "🌈", name = "무지개 정원", description = "공원 화단 6곳에 서로 다른 꽃 6종을 피우기" },
	{ id = "plane_first", emoji = "✈️", name = "종이비행기 조종사", description = "옥상에서 종이비행기 처음 날리기" },
	{ id = "plane_target", emoji = "🎯", name = "명중!", description = "종이비행기를 건너편 빌딩 🎯 과녁에 꽂기" },
	{ id = "plane_boss", emoji = "🤕", name = "보고서 반송", description = "되돌아온 종이비행기가 옥상 경비원 머리에 꽂히기" },
	{ id = "pigeon_friend", emoji = "🐦", name = "비둘기 친구", description = "옥상에서 비둘기에게 처음 과자 주기" },
	{ id = "pigeon_white", emoji = "🕊️", name = "평화주의자", description = "흰 비둘기 만나기" },
	{ id = "pigeon_legend", emoji = "👑", name = "전설의 비둘기", description = "왕관 비둘기나 무지개 비둘기 만나기" },
	{ id = "pigeon_all", emoji = "📒", name = "비둘기 박사", description = "비둘기 관찰 노트 완성하기" },
	{ id = "pigeon_gift", emoji = "🎁", name = "비둘기의 보은", description = "비둘기가 물어 온 선물 처음 줍기" },
	{ id = "pigeon_gem", emoji = "💎", name = "보석 물어 온 비둘기", description = "비둘기가 물어 온 💎 커다란 보석 줍기" },
	{ id = "pigeon_socks", emoji = "🧦", name = "양말 컬렉터", description = "비둘기의 장난 선물(양말·빈 캔·낙엽) 모두 모으기" },
	{ id = "audit_reveal", emoji = "🕶️", name = "감사관 색출", description = "동료로 위장한 감사관의 정체를 밝혀내기" },
	{ id = "workshop_winner", emoji = "🌸", name = "무궁화 챔피언", description = "워크숍 무궁화꽃이 피었습니다 1등 하기" },
	{ id = "dinner_ace", emoji = "🍻", name = "회식 에이스", description = "회식에서 6점 이상 받기" },
	{ id = "first_plush", emoji = "🧸", name = "첫 인형", description = "인형뽑기에서 처음으로 인형 뽑기" },
	{ id = "legend_plush", emoji = "🦄", name = "전설의 집게손", description = "전설 등급 인형 뽑기 (유니콘 또는 김부장 인형)" },
	{ id = "plush_all", emoji = "📚", name = "인형 수집가", description = "인형 10종을 모두 모으기 (오락실 한정 포함)" },
	{ id = "arcade_first", emoji = "🕹️", name = "오락실 데뷔", description = "오락실 게임 처음 해 보기" },
	{ id = "arcade_champ", emoji = "🏆", name = "오락실 챔피언", description = "두더지 30점 또는 카드 짝 맞추기 24점 이상" },
	{ id = "mission_clear", emoji = "📋", name = "프로젝트 해결사", description = "긴급 프로젝트 성공하기" },
	{ id = "mission_master", emoji = "🏅", name = "프로젝트 마스터", description = "긴급 프로젝트 4종(회의 발표 빼고)을 모두 성공하기" },
	{ id = "gift_hongsam", emoji = "🎁", name = "아부의 달인", description = "홍삼 선물세트로 경고 지우기" },
	{ id = "wheel_20", emoji = "🎡", name = "대박 돌림판", description = "돌림판 20에 걸어서 맞히기" },
	{ id = "dart_legend", emoji = "🎈", name = "풍선 속 전설", description = "풍선 다트에서 🧸 인형 풍선을 터뜨려 전설 인형 받기" },
	{ id = "dragon_plush", emoji = "🐲", name = "용용이 입양", description = "티켓으로 오락실 한정 인형 용용이 받기" },
	{ id = "video_pro", emoji = "🎧", name = "회의의 달인", description = "화상회의 질문에 연속 5번 잘 대답하기" },
	{ id = "cat_lover", emoji = "🐱", name = "집사 자격", description = "사무실 고양이 월급냥을 10번 쓰다듬기" },
	{ id = "cat_distract", emoji = "😺", name = "고양이 작전", description = "월급냥이 부장님 정신을 빼놓는 순간 농땡이 치기" },
	{ id = "rooftop_first", emoji = "🌬️", name = "옥상 입성", description = "엘리베이터 타고 옥상에 처음 가기" },
	{ id = "elevator_ninja", emoji = "😎", name = "엘리베이터 닌자", description = "부장님과 탄 엘리베이터에서 눈 안 마주치기 3번" },
	{ id = "elevator_awkward", emoji = "😳", name = "어색함의 극치", description = "엘리베이터에서 부장님과 눈 마주치기" },
	{ id = "interior_first", emoji = "🪑", name = "첫 인테리어", description = "내 자리 꾸미기 아이템 처음 사기" },
	{ id = "interior_master", emoji = "🏰", name = "인테리어 장인", description = "인테리어 점수 150점 달성" },
	{ id = "throne", emoji = "👑", name = "왕좌의 주인", description = "사장님 왕좌 의자 사기" },
	{ id = "street_cafe", emoji = "☕", name = "카페인 수혈", description = "눈치 스트리트 카페에서 음료 사 마시기" },
	{ id = "dessert_lover", emoji = "🍰", name = "디저트 탐방", description = "디저트집 디저트를 자리에서 끝까지 몰래 먹기" },
	{ id = "company_nunchi", emoji = "🏢", name = "이직 성공", description = "대리가 돼서 (주)눈치물산으로 스카우트되기" },
	{ id = "lee_bribe", emoji = "☕", name = "커피 외교", description = "이과장에게 커피를 상납해서 고자질 막기" },
	{ id = "lee_dodge", emoji = "🙈", name = "눈치 싸움 승리", description = "이과장의 ❗를 보고 들키기 전에 일하는 척하기" },
	{ id = "chatterbox", emoji = "🗣️", name = "사내 수다왕", description = "수다 주제 30개 수집하기" },
	{ id = "bestie", emoji = "🤝", name = "사내 단짝", description = "동료 한 명과 친밀도 ❤️ 4개 달성" },
	{ id = "near_miss", emoji = "😅", name = "아슬아슬 입문", description = "처음으로 아슬아슬 보너스 받기" },
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
	{ name = "월요일", walkSpeed = 13, fov = 70, range = 62, mood = "월요병으로 예민함 😠" },
	{ name = "화요일", walkSpeed = 11, fov = 63, range = 56, mood = "평범한 하루" },
	{ name = "수요일", walkSpeed = 11, fov = 63, range = 56, mood = "실적 압박 중" },
	{ name = "목요일", walkSpeed = 11, fov = 60, range = 56, mood = "회식 생각 중" },
	{ name = "금요일", walkSpeed = 10, fov = 55, range = 50, mood = "불금이라 느슨함 😌" },
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
	{ id = "audit", emoji = "🔍", name = "감사 기간", allDay = true, description = "감사관이 동료로 위장해 농땡이를 📸 찍어요! 수상한 동료에게 [R]. 대신 농땡이 수입 ×2!" },
	{ id = "blackout", emoji = "💡", name = "정전", allDay = false, description = "30초 동안 컴퓨터가 꺼져요. 어두워서 자도 안 들켜요!" },
	{ id = "cake", emoji = "🎂", name = "생일 케이크", allDay = false, description = "탕비실에 생일 케이크 3조각! 먼저 먹는 사람이 임자" },
	{ id = "drill", emoji = "🚒", name = "소방 훈련", allDay = false, description = "45초 안에 초록색 집결지로 대피! 안 하면 경고" },
	{ id = "workshop", emoji = "🌸", name = "워크숍 레크리에이션", allDay = false, description = "부장님이 술래인 무궁화꽃이 피었습니다! 골인하면 보너스" },
} :: { EventInfo }

SalaryConfig.AUDIT_INCOME = 2 -- 감사 기간 농땡이 수입 배율

-- 🕶️ 위장 감사관 + 📸 증거 사진
--   감사 기간엔 동료 중 한 명이 몰래 감사관이에요. (검은 정장 감사팀은 동료가 아무도 없을 때만 나와요)
--   단서: 절대 농땡이를 안 해요 · 자주 돌아다녀요 · 가끔 📝 메모 · 혼잣말이 수상해요
--   감사관이 '내 자리에서' 농땡이하는 걸 보면 📷 카메라를 들고(AUDIT_PHOTO_WINDUP초) → 그때도 자리에서 농땡이 중이면 📸 찰칵!
--   + 화장실·회의실·수다도 찍혀요 (어슬렁·탕비실 등 나머지 자리 밖은 봐줘요)
--   처벌(하루 한 번): 농땡이 사진 AUDIT_REPORT_AT장 이상 또는 🪑 빈자리 사진 AUDIT_EMPTY_REPORT_AT장 이상
--   → 퇴근 때 "감사 보고서" 감봉(시말서 1번만큼) + 경고 1개. 처벌이 정해지면 그날은 더 안 찍어요
--   수상한 동료에게 [R] "감사팀이죠?" → 맞히면 정체 폭로! 감사 끝 + 모두의 사진 폐기 + 보너스
--                                     → 틀리면 의심도 +AUDIT_WRONG_SUSPICION (하루 AUDIT_WRONG_MAX번까지)
SalaryConfig.AUDIT_PHOTO_MAX = 3 -- (안 써요)
SalaryConfig.AUDIT_REPORT_AT = 2 -- 📸 자리·화장실·회의실·수다에서 농땡이하다 찍힌 사진이 이만큼이면 처벌
SalaryConfig.AUDIT_EMPTY_REPORT_AT = 3 -- 🪑 경고 뒤 도망가서 찍힌 빈자리 사진이 이만큼이면 처벌
--   🪑 카메라를 든 뒤 일하기로 안 돌아오고 자리를 떠서 도망가면 '빈자리'가 찍혀요 (농땡이 사진과 따로 세요)
SalaryConfig.AUDIT_PHOTO_WINDUP = 5 -- 📷 경고 뒤 이 시간 안에 일하기로 돌아오면 안 찍혀요
SalaryConfig.AUDIT_CAMERA_SHOW = 2 -- 감사관 머리 위 📷가 떠 있는 시간 (짧을수록 정체 찾기 어려워요)
SalaryConfig.AUDIT_PHOTO_STATES = { toilet = true, meeting = true, chat = true } -- 자리 밖이어도 찍히는 농땡이 (🚽 화장실, 📊 회의실, 💬 수다)
SalaryConfig.AUDIT_PHOTO_COOLDOWN = 20 -- 한 사람을 다시 찍기까지 (초)
SalaryConfig.AUDIT_REVEAL_BONUS = 3000
SalaryConfig.AUDIT_WRONG_SUSPICION = 20
SalaryConfig.AUDIT_WRONG_MAX = 2
SalaryConfig.AuditorMumbles = {
	"흠… 이건 적어 둬야겠군.",
	"메모, 메모…",
	"(펜을 딸깍딸깍)",
	"이 부서 분위기가… 흥미롭네요.",
	"근무 태도라… 흠.",
	"(뭔가를 수첩에 적는다)",
}

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
		minRank = 4, -- 대리부터 (승진하면 자동으로 이직)
		leeDays = {}, -- 이과장은 대충상사에 남았어요 (나도 이제 과장이라 동급!)
		motto = "사훈: 눈치가 곧 경쟁력! 칼퇴는 없다",
	},
} :: { CompanyInfo }

SalaryConfig.TEST_MONEY = 0 -- 🧪 스튜디오에서 통장을 최소 이만큼 채워 줘요 (가게·인형뽑기 테스트용, 실제 게임엔 영향 없음)
SalaryConfig.TEST_RANK = 4 -- 🧪 스튜디오에서 직급을 최소 이만큼으로 (2 = 사원, 0이면 끔. 저장이 꺼져 있을 때만)
SalaryConfig.TEST_CAMPUS_EVENT = "" -- 🧪 스튜디오에서 "rain" · "blossom" · "flea"를 넣으면 그 단지 행사를 바로 볼 수 있어요
SalaryConfig.TEST_COMPANY = "daechung" -- 🧪 스튜디오에서 "nunchi"를 넣으면 눈치물산 사무실로 시작 (실제 게임엔 영향 없음)
SalaryConfig.TEST_DELIVERY = false -- 🧪 true면 스튜디오에서 들어오자마자 📦 택배 하나가 도착해 있어요 (🔔 알림 테스트, 실제 게임엔 영향 없음)

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
SalaryConfig.DINNER_SECONDS = 20
SalaryConfig.DINNER_POINT = 500 -- 회식 점수 1점당 보너스 (짧아진 만큼 1점이 더 귀해요)
SalaryConfig.TEST_DINNER = false -- 🧪 true면 스튜디오에서 매일 회식 (실제 게임엔 영향 없음)

function SalaryConfig.getEvent(eventId: string): EventInfo?
	for _, event in SalaryConfig.Events do
		if event.id == eventId then
			return event
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- 🏙️ 눈치 스트리트 (눈치물산 공원 뒤 상가 거리) — 근무 중에도 갈 수 있지만 자리 부재 게이지가 차요!
--   buff: 사면 바로 마시고 오늘 하루 효과 (같은 음료는 하루 한 번)
--   snack: 들고 가서 자리에서 [8] 몰래 먹기 (간식 시스템과 같아요)
---------------------------------------------------------------------------
export type StreetItem = { id: string, emoji: string, name: string, price: number, description: string, snack: string?, gift: boolean?, food: boolean?, days: { string }? } -- food = 마시는 게 아니라 먹는 것 (버튼·문구가 "먹기"로 나와요)
export type StreetShop = { id: string, name: string, clerk: string, items: { StreetItem }, lunchOnly: boolean? }

SalaryConfig.StreetShops = {
	-- 🏪 사내 매점 (두 회사 모두 사무실 안에 있어요): 부장님께 드릴 선물
	store = {
		id = "store",
		name = "🏪 사내 매점",
		clerk = "매점 아주머니",
		items = {
			{ id = "hongsam", emoji = "🎁", name = "홍삼 선물세트", price = 8000, gift = true, description = "부장님께 [E] 드리면 경고 -1! (하루에 한 번만)" },
			{ id = "flowers", emoji = "💐", name = "꽃다발", price = 3000, gift = true, description = "부장님께 드리면 오늘의 의심도 속도 -0.15" },
			{ id = "choco", emoji = "🍫", name = "초콜릿", price = 800, gift = true, description = "부장님께 드리면 지금 의심도 -25" },
		},
	},
	cafe = {
		id = "cafe",
		name = "☕ 눈치 커피",
		clerk = "카페 사장님",
		items = {
			{ id = "americano", emoji = "☕", name = "아메리카노", price = 1500, description = "오늘 하루 업무 시간이 1.3배 빨리 채워져요" },
			{ id = "latte", emoji = "🥛", name = "바닐라 라떼", price = 2000, description = "오늘 하루 의심도가 25% 더 빨리 줄어요" },
			{ id = "smoothie", emoji = "🍹", name = "에너지 스무디", price = 3000, description = "오늘 하루 자리 부재 게이지가 30% 천천히 차요" },
		},
	},
	dessert = {
		id = "dessert",
		name = "🍰 달콤 디저트",
		clerk = "디저트 사장님",
		items = {
			{ id = "macaron", emoji = "🧁", name = "마카롱", price = 1200, snack = "macaron", description = "자리에서 몰래 다 먹으면 +1,800원 (8초)" },
			{ id = "croffle", emoji = "🥐", name = "크로플", price = 2500, snack = "croffle", description = "자리에서 몰래 다 먹으면 +4,000원 (14초)" },
			{ id = "strawcake", emoji = "🍓", name = "딸기 생크림 케이크", price = 4000, snack = "strawcake", description = "자리에서 몰래 다 먹으면 +7,000원 (20초)" },
		},
	},
	-- ☕ 골목 커피 (대충상사 건물 1층): 눈치 커피의 절반쯤 되는 효과를 3분의 1 값에
	cafe1f = {
		id = "cafe1f",
		name = "☕ 골목 커피",
		clerk = "커피집 사장님",
		items = {
			{ id = "mixcoffee", emoji = "☕", name = "믹스커피", price = 500, description = "오늘 하루 업무 시간이 1.15배 빨리 채워져요" },
			{ id = "yuja", emoji = "🍵", name = "유자차", price = 700, description = "오늘 하루 의심도가 12% 더 빨리 줄어요" },
			{ id = "vitamin", emoji = "🧃", name = "비타민 음료", price = 900, description = "오늘 하루 자리 부재 게이지가 15% 천천히 차요" },
		},
	},
	-- 🍢 대충 분식 (대충상사 건물 1층): 탕비실 공짜 간식보다 많이 남지만, 먹는 동안 들키기 쉬워요
	bunsik = {
		id = "bunsik",
		name = "🍢 대충 분식",
		clerk = "분식집 이모",
		items = {
			{ id = "tteokbokki", emoji = "🍢", name = "떡볶이", price = 600, snack = "tteokbokki", description = "자리에서 몰래 다 먹으면 +1,100원 (8초)" },
			{ id = "gimbap", emoji = "🍙", name = "김밥", price = 1000, snack = "gimbap", description = "자리에서 몰래 다 먹으면 +1,900원 (12초)" },
			{ id = "rabokki", emoji = "🍜", name = "라볶이 세트", price = 1800, snack = "rabokki", description = "자리에서 몰래 다 먹으면 +3,400원 (18초)" },
		},
	},
	-- 🚚 푸드트럭 (눈치물산 타워 앞 광장): 점심시간에만 열어요. 커피 효과와 겹쳐서 받을 수 있어요
	truck = {
		id = "truck",
		name = "🚚 푸드트럭",
		clerk = "푸드트럭 사장님",
		lunchOnly = true,
		items = {
			-- days: 이 요일에만 팔아요 (요일마다 두 가지씩)
			{ id = "taco", emoji = "🌮", name = "든든 타코", price = 800, food = true, days = { "월요일", "수요일" }, description = "든든한 점심! 오늘 남은 하루 농땡이 수입 +25%" },
			{ id = "gangjeong", emoji = "🍗", name = "닭강정 컵", price = 800, food = true, days = { "화요일", "목요일" }, description = "기분 좋은 점심! 오늘 남은 하루 의심도가 40% 더 빨리 줄어요" },
			{ id = "cupbap", emoji = "🍚", name = "스팸 컵밥", price = 800, food = true, days = { "월요일", "목요일" }, description = "밥심으로 일해요! 오늘 남은 업무 시간이 1.5배 빨리 채워져요" },
			{ id = "hotdog", emoji = "🌭", name = "핫도그", price = 800, food = true, days = { "화요일", "금요일" }, description = "들고 다니며 먹어요! 오늘 남은 하루 자리 부재 게이지가 20% 천천히 차요" },
			{ id = "burger", emoji = "🍔", name = "수제 버거", price = 1000, food = true, days = { "수요일", "금요일" }, description = "스트레스가 싹! 먹는 순간 의심도 -30" },
		},
	},
} :: { [string]: StreetShop }

SalaryConfig.TACO_INCOME = 1.25 -- 🌮 타코: 농땡이 수입 배율
SalaryConfig.CUPBAP_WORK = 1.5 -- 🍚 컵밥: 업무 시간 배율
SalaryConfig.HOTDOG_AWAY = 0.8 -- 🌭 핫도그: 자리 부재 게이지 속도 배율
SalaryConfig.BURGER_SUSPICION = 30 -- 🍔 버거: 먹는 순간 의심도 -
SalaryConfig.GANGJEONG_DECAY = 1.4 -- 🍗 닭강정: 의심도 줄어드는 속도 배율 (라떼·유자차와 곱해져요)

-- 🪪 사원증 등급: 이 직급부터 쓸 수 있는 단지 시설 (Ranks 번호: 1 인턴 · 2 사원 · 3 주임 · 4 대리)
--   공원 시설·커피·디저트·인형뽑기는 누구나. 눈치물산 타워는 대리부터 (회사 자체가 대리부터예요)
SalaryConfig.BADGE = { dart = 2, arcade = 3, wheel = 4 }

-- 🎪 단지 행사: 날마다 단지가 조금씩 달라져요
SalaryConfig.RAIN_CHANCE = 0.18 -- 🌧️ 비 오는 날 확률: 창밖 시선이 쉬고 경비원 시야가 줄지만, 탁 트인 곳 수당(1.4배)도 없어요
SalaryConfig.RAIN_GUARD_RANGE = 0.75 -- 비 오는 날 경비원 시야 배율
SalaryConfig.BLOSSOM_EVERY = 4 -- 🌸 벚꽃 주간: 이 주(5일)마다 한 번, 그 주 내내
SalaryConfig.BLOSSOM_INCOME = 1.15 -- 벚꽃 주간 단지 산책 수입 배율 (건물 안 제외)
SalaryConfig.FLEA_PRICE = 500 -- 🛍️ 금요일 플리마켓 뽑기 한 번
SalaryConfig.FLEA_PRIZES = { -- { 풍선 다트 경품 id, 비중 }
	{ "none", 30 }, { "won100", 18 }, { "won300", 22 }, { "tickets", 16 }, { "plush", 12 }, { "jackpot", 2 },
}

-- 🚏 출근 시간: 아침마다 단지 버스 정류장에서 시작해 내 자리까지 가요 (시각은 게임 속 분)
SalaryConfig.COMMUTE_EARLY = 9 * 60 + 40 -- 이때까지 앉으면 칼출근 보너스
SalaryConfig.COMMUTE_LATE = 9 * 60 + 50 -- 이때까지 못 앉으면 지각
SalaryConfig.COMMUTE_BONUS = 0.25 -- 칼출근 보너스 = 기본급의 25%
SalaryConfig.COMMUTE_EARLY_DELTA = -0.05 -- 칼출근: 오늘의 의심도 속도
SalaryConfig.COMMUTE_LATE_DELTA = 0.15 -- 지각: 오늘의 의심도 속도

-- 🍚 점심시간: 12:45에 "곧 1시" 알림, 13:20까지 단지에 남아 있으면 지각
SalaryConfig.LUNCH_WARN = 12 * 60 + 45
SalaryConfig.LUNCH_LATE = 13 * 60 + 20 -- (단지나 옥상에 남아 있으면)
SalaryConfig.LUNCH_LATE_SUSPICION = 30 -- 점심 지각: 의심도 +

-- 👀 창밖 시선: 부장님이 가끔 창가에서 단지를 내려다봐요. 지붕·나무 밑·건물 안이면 안 보여요
SalaryConfig.WINDOW_GAP = { 45, 80 } -- 다음 번까지 쉬는 시간 (초)
SalaryConfig.WINDOW_WARN = 3 -- "창가로 와요" 예고 (초)
SalaryConfig.WINDOW_SECONDS = 7 -- 내려다보는 시간 (초). 이 동안 사무실 안은 안 봐요
SalaryConfig.WINDOW_MULTIPLIER = 1.2 -- 보이는 동안 의심도 배율 (7초 내내 서 있으면 의심도 약 +70: 한 번 놓쳐도 바로 적발은 아니에요)
SalaryConfig.STREET_HUNCH_EXTRA = 30 -- 🏙️ 단지 산책은 "오래 농땡이 눈치"가 이만큼(초) 늦게 와요 (오가는 길이 머니까)

SalaryConfig.MIXCOFFEE_WORK = 1.15 -- 믹스커피: 업무 시간 배율
SalaryConfig.YUJA_DECAY = 1.12 -- 유자차: 의심도 줄어드는 속도 배율
SalaryConfig.VITAMIN_AWAY = 0.85 -- 비타민 음료: 자리 부재 게이지 속도 배율
SalaryConfig.AMERICANO_WORK = 1.3 -- 아메리카노: 업무 시간 배율
SalaryConfig.LATTE_DECAY = 1.25 -- 바닐라 라떼: 의심도 줄어드는 속도 배율
SalaryConfig.SMOOTHIE_AWAY = 0.7 -- 에너지 스무디: 자리 부재 게이지 속도 배율

function SalaryConfig.getStreetItem(shopId: string, itemId: string): StreetItem?
	local shop = SalaryConfig.StreetShops[shopId]
	if not shop then
		return nil
	end
	for _, item in shop.items do
		if item.id == itemId then
			return item
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- 🧸 인형뽑기 (눈치 스트리트)
--   한 판 CLAW_PRICE원. 좌우 → 앞뒤 두 번 멈춰서 원하는 인형 위에 집게를 내려요.
--   걸려도 들어 올리다 미끄러지거나 옮기다 떨어질 수 있어요 (희귀할수록 미끄러워요).
--   뽑은 인형은 책상에 3개까지 진열할 수 있어요.
---------------------------------------------------------------------------
export type PlushInfo = { id: string, emoji: string, name: string, rarity: string, color: Color3 }

SalaryConfig.Plushies = {
	{ id = "bear", emoji = "🐻", name = "곰돌이", rarity = "common", color = Color3.fromRGB(160, 110, 70) },
	{ id = "bunny", emoji = "🐰", name = "토끼", rarity = "common", color = Color3.fromRGB(245, 240, 240) },
	{ id = "puppy", emoji = "🐶", name = "강아지", rarity = "common", color = Color3.fromRGB(230, 200, 150) },
	{ id = "kitty", emoji = "🐱", name = "고양이", rarity = "common", color = Color3.fromRGB(250, 200, 120) },
	{ id = "penguin", emoji = "🐧", name = "펭귄", rarity = "rare", color = Color3.fromRGB(45, 45, 55) },
	{ id = "fox", emoji = "🦊", name = "여우", rarity = "rare", color = Color3.fromRGB(240, 130, 50) },
	{ id = "panda", emoji = "🐼", name = "판다", rarity = "rare", color = Color3.fromRGB(245, 245, 245) },
	{ id = "unicorn", emoji = "🦄", name = "유니콘", rarity = "legend", color = Color3.fromRGB(255, 200, 240) },
	{ id = "bujang", emoji = "👔", name = "김부장 인형", rarity = "legend", color = Color3.fromRGB(70, 70, 80) },
	-- 🕹️ 오락실 경품으로만 받을 수 있어요 (인형뽑기엔 안 나와요)
	{ id = "dragon", emoji = "🐲", name = "용용이 (오락실 한정)", rarity = "special", color = Color3.fromRGB(110, 200, 120) },
} :: { PlushInfo }

SalaryConfig.PlushRarity = {
	common = { name = "일반", weight = 70, color = Color3.fromRGB(150, 150, 160) },
	rare = { name = "희귀", weight = 25, color = Color3.fromRGB(80, 150, 255) },
	legend = { name = "전설", weight = 5, color = Color3.fromRGB(255, 180, 40) },
	special = { name = "오락실 한정", weight = 0, color = Color3.fromRGB(200, 90, 230) },
}

SalaryConfig.CLAW_PRICE = 500
-- 🕹️ 조작: ① 집게가 좌우로 움직일 때 [멈춤] → ② 앞뒤로 움직일 때 [내리기]
--   기계 안에는 인형 CLAW_PLUSH_COUNT개가 흩어져 있고, 집게 바로 아래 인형만 잡혀요 (위에서 본 0~1 좌표)
SalaryConfig.CLAW_PLUSH_COUNT = 6
SalaryConfig.CLAW_RADIUS = 0.07 -- 집게 중심과 인형 중심 거리가 이 안이어야 집게가 걸려요
SalaryConfig.CLAW_GAP = 0.4 -- [멈춤] 뒤 앞뒤 움직임이 시작되기까지 (초)
-- 들어 올릴 때 버티는 확률 (정중앙일수록 잘 잡혀요: 정확도에 따라 60~100%가 곱해져요)
SalaryConfig.CLAW_GRIP = { common = 0.8, rare = 0.6, legend = 0.4 }
SalaryConfig.CLAW_CARRY = 0.85 -- 출구까지 옮기다 떨어뜨리지 않을 기본 확률 (정확할수록 높아요)
SalaryConfig.DESK_PLUSH_MAX = 3

function SalaryConfig.getPlush(plushId: string): PlushInfo?
	for _, plush in SalaryConfig.Plushies do
		if plush.id == plushId then
			return plush
		end
	end
	return nil
end

-- 집게 위치 (0 ~ 1 ~ 0 왕복). 서버와 화면이 같은 식을 써서 보이는 대로 판정돼요
function SalaryConfig.clawPosition(elapsed: number, period: number): number
	local f = (elapsed / period) % 1
	return if f < 0.5 then f * 2 else 2 - f * 2
end

-- 인형뽑기에서 나올 인형 하나 고르기 (등급 확률 → 그 등급 안에서 무작위)
function SalaryConfig.rollClawPlush(): PlushInfo
	local total = 0
	for _, rarity in SalaryConfig.PlushRarity do
		total += rarity.weight
	end
	local roll = math.random() * total
	local chosen = "common"
	for id, rarity in SalaryConfig.PlushRarity do
		if rarity.weight <= 0 then
			continue
		end
		roll -= rarity.weight
		if roll <= 0 then
			chosen = id
			break
		end
	end
	local pool = {}
	for _, plush in SalaryConfig.Plushies do
		if plush.rarity == chosen then
			table.insert(pool, plush)
		end
	end
	return pool[math.random(1, #pool)]
end

---------------------------------------------------------------------------
-- 🕹️ 오락실 (눈치 스트리트): 한 판 ARCADE_PRICE원 → 점수만큼 🎟️ 티켓 → 경품 교환
---------------------------------------------------------------------------
SalaryConfig.ARCADE_PRICE = 300
SalaryConfig.ArcadeGames = {
	mole = { id = "mole", emoji = "🔨", name = "두더지 잡기", description = "20초 동안 튀어나오는 두더지를 콕! ⭐ 황금 두더지 +3, 👔 부장님 두더지는 때리면 -2" },
	memory = { id = "memory", emoji = "🃏", name = "카드 짝 맞추기", description = "카드 2장씩 뒤집어서 같은 그림을 찾아요! 짝 하나 2점, 다 찾으면 남은 시간 보너스" },
}
SalaryConfig.MOLE_SECONDS = 20
-- 🃏 카드 짝 맞추기: 4×4 = 16장 (8쌍). 배치는 서버만 알아요
SalaryConfig.MEMORY_COLS = 4
SalaryConfig.MEMORY_PAIRS = 8
SalaryConfig.MEMORY_SECONDS = 45
SalaryConfig.MEMORY_PAIR_POINTS = 2 -- 짝 하나에 2점
SalaryConfig.MEMORY_BONUS_EVERY = 2 -- 다 찾으면 남은 시간 2초마다 +1점
SalaryConfig.MEMORY_PEEK = 0.6 -- 틀린 두 장을 보여 주는 시간 (초, 이 동안은 못 뒤집어요)
-- 카드 그림 (판마다 이 중 8개를 골라요. 로블록스에서 네모로 안 보이는 옛날 이모지만)
SalaryConfig.MemoryEmoji = { "☕", "📎", "💼", "📌", "📁", "🍩", "🍕", "🎧", "📱", "⏰", "🔑", "💡", "📊", "🍜" }

-- 점수 → 티켓
function SalaryConfig.arcadeTickets(gameId: string, score: number): number
	-- 두더지·카드 둘 다 2점에 1장 (카드: 다 찾고 15초쯤 남기면 11장 정도)
	return math.max(0, math.floor(score / 2))
end

export type ArcadePrize = { id: string, emoji: string, name: string, tickets: number, description: string }
SalaryConfig.ArcadePrizes = {
	{ id = "coffee", emoji = "☕", name = "아메리카노 쿠폰", tickets = 30, description = "바로 마셔요: 오늘 업무 시간 1.3배 빨리" },
	{ id = "plush", emoji = "🧸", name = "랜덤 인형", tickets = 80, description = "인형뽑기에서 나오는 인형 중 하나 (전설 포함!)" },
	{ id = "dragon", emoji = "🐲", name = "용용이 (오락실 한정 인형)", tickets = 250, description = "여기서만 받을 수 있는 인형" },
} :: { ArcadePrize }

---------------------------------------------------------------------------
-- 🎡 돌림판 (뽑기 천국 가게): 숫자에 걸고 [돌리기]! 직접 돌려서 4초 만에 결과
--   멈춘 숫자에 건 돈 × (숫자 + 1)을 받아요
--   예) 10에 1,000원 → 10에 멈추면 11,000원 받아요. 오래 하면 조금씩 손해 보게 맞춰 놨어요.
---------------------------------------------------------------------------
SalaryConfig.WHEEL_SEGMENTS = { 1, 3, 1, 5, 1, 3, 1, 10, 1, 5, 1, 3, 20, 3, 1, 5, 1, 3, 1, 10, 1, 5, 3, 1, 1 } -- 25칸 (1×12, 3×6, 5×4, 10×2, 20×1)
SalaryConfig.WHEEL_NUMBERS = { 1, 3, 5, 10, 20 }
SalaryConfig.WHEEL_BETS = { 500, 1000, 5000 }
SalaryConfig.WHEEL_MAX_ROUND = 20000 -- 한 판에 걸 수 있는 최대 금액
SalaryConfig.WHEEL_SPIN_SECONDS = 4 -- 돌아가는 시간 (자리 부재 게이지가 차니까 짧게)
SalaryConfig.WHEEL_COLORS = {
	[1] = Color3.fromRGB(150, 150, 160),
	[3] = Color3.fromRGB(80, 180, 100),
	[5] = Color3.fromRGB(70, 140, 230),
	[10] = Color3.fromRGB(170, 90, 220),
	[20] = Color3.fromRGB(250, 190, 40),
}

-- 돌림판 회전 각도 (시계 방향 도). 서버가 정한 시작·끝 각도로 모든 화면이 똑같이 돌아요
function SalaryConfig.wheelRotation(from: number, to: number, elapsed: number): number
	local t = math.clamp(elapsed / SalaryConfig.WHEEL_SPIN_SECONDS, 0, 1)
	local eased = 1 - (1 - t) ^ 4 -- 처음엔 빠르게, 끝엔 천천히
	return from + (to - from) * eased
end

---------------------------------------------------------------------------
-- 🎯 끌어서 던지기 풍선 다트 (뽑기 천국 가게): DART_PRICE원에 다트 DART_COUNT개
--   벽에 풍선 10개가 둥실둥실. 풍선마다 경품이 써 있어요 (💰 금액 / 🎟️ 티켓 / 🧸 인형 / 💨 꽝)
--   다트를 뒤로 끌었다 놓으면 반대쪽으로 날아가요 (새총처럼). 많이 당길수록 세게!
--   중력 때문에 포물선으로 날아가요: 너무 약하면 못 미치고, 너무 세면 벽을 넘어가요.
--   날아가다 처음 닿은 풍선이 펑! (앞 풍선이 뒤 풍선을 가로막을 수도 있어요)
--
-- 📐 좌표: 다트판 안의 화면 칸 (가로 DART_FIELD_W × 세로 DART_FIELD_H, 왼쪽 위가 0,0, 아래로 갈수록 y가 커져요)
--   서버와 화면이 똑같은 공식(dartFlight, dartBalloonPos, dartSimulate)을 써요
--   → 화면은 미리 날려 보여 주고, 서버는 같은 계산으로 맞았는지 확인해요 (서버 결과가 진짜)
--
-- ⚖️ 밸런스 (모의 계산: 남은 풍선 중 제일 비싼 걸 노리고, 손 떨림(각도·힘)만 다르게 판마다 100판씩)
--   풍선 10개 = 가까운 자리 5 + 먼 자리 5. 가까운 풍선은 쉽고(세게 쏘면 거의 일직선), 먼 풍선은 높거나 옆이라
--   거의 끝까지 당겨야 닿아요 → 힘 조절을 잘해야 해요 (먼 풍선 명중률: 처음 30%대 / 보통 50% / 잘하면 70%)
--   - 가까운 자리: 100 · 50 · 🎟️10장 · 꽝 · 꽝 (DART_NEAR_PRIZES)
--   - 먼 자리: 300 · 200 · 100 · 🧸(DART_PLUSH_CHANCE, 아니면 꽝) (DART_FAR_PRIZES)
--     + 그중 한 곳은 🎰 대박 자리: DART_JACKPOT_CHANCE 확률로 3,000원 (아니면 300원). 작고 빨리 흔들려요
--   - 한 판(1,000원) 평균 돈: 처음 하는 사람 약 650원 / 보통 약 860원 / 잘하는 사람 약 1,020원 (+ 티켓·가끔 인형)
--     → 보통은 조금 손해, 잘하면 살짝 이득. 대박 풍선은 다섯 판에 한 번꼴로 나오고 맞히기 어려워요
--   (🧸 인형 풍선은 DART_LEGEND_CHANCE 확률로 🦄 전설 인형!)
---------------------------------------------------------------------------
SalaryConfig.DART_PRICE = 1000
SalaryConfig.DART_COUNT = 3
SalaryConfig.DART_FIELD_W = 380
SalaryConfig.DART_FIELD_H = 290
SalaryConfig.DART_ORIGIN = Vector2.new(190, 266) -- 다트가 날아가기 시작하는 곳 (아래 가운데)
SalaryConfig.DART_SPEED = 640 -- 힘 100%일 때 처음 속도 (칸/초) → 똑바로 위로 쏘면 약 228칸까지 올라가요
SalaryConfig.DART_GRAVITY = 900 -- 아래로 당기는 힘 (칸/초²)
SalaryConfig.DART_MIN_POWER = 0.2 -- 이것보다 덜 당기면 안 던져요
SalaryConfig.DART_MIN_ANGLE = math.rad(8) -- 거의 옆으로 눕힌 각도까지만 (0 = 오른쪽, 90도 = 위)
SalaryConfig.DART_DRAG_MAX = 120 -- 화면에서 이만큼(칸) 당기면 힘 100%
SalaryConfig.DART_MAX_TIME = 3 -- 이만큼 날아도 아무 데도 안 닿으면 끝
SalaryConfig.DART_STEP = 1 / 120 -- 맞았는지 확인하는 간격 (초)
SalaryConfig.DART_TIP = 3 -- 다트 끝 두께 (풍선 반지름에 더해요)
SalaryConfig.DART_OVER_Y = -30 -- 다트판 위로 이만큼 넘어가면 "벽을 넘어갔어요"
SalaryConfig.DART_JACKPOT_CHANCE = 0.2 -- 🎰 대박 자리에 3,000원 풍선이 나올 확률 (아니면 300원)
SalaryConfig.DART_PLUSH_CHANCE = 0.4 -- 🧸 인형 풍선이 들어갈 확률 (아니면 꽝)
SalaryConfig.DART_LEGEND_CHANCE = 0.08 -- 🧸 인형 풍선을 터뜨렸을 때 🦄 전설 인형이 나올 확률

-- 풍선 종류 (label = 풍선에 쓰는 글씨, color = 풍선 색 → 색만 봐도 값어치를 알 수 있어요)
SalaryConfig.DartPrizes = {
	{ id = "none", emoji = "💨", name = "꽝", label = "꽝", color = Color3.fromRGB(205, 205, 212) },
	{ id = "won50", emoji = "💰", name = "50원", label = "50", color = Color3.fromRGB(160, 215, 255), money = 50 },
	{ id = "won100", emoji = "💰", name = "100원", label = "100", color = Color3.fromRGB(100, 160, 255), money = 100 },
	{ id = "won200", emoji = "💰", name = "200원", label = "200", color = Color3.fromRGB(100, 205, 115), money = 200 },
	{ id = "won300", emoji = "💰", name = "300원", label = "300", color = Color3.fromRGB(255, 150, 60), money = 300 },
	{ id = "jackpot", emoji = "💰", name = "3,000원 대박", label = "3000", color = Color3.fromRGB(255, 205, 40), money = 3000, jackpot = true },
	{ id = "tickets", emoji = "🎟️", name = "티켓 10장", label = "🎟️10", color = Color3.fromRGB(255, 160, 200), tickets = 10 },
	{ id = "plush", emoji = "🧸", name = "랜덤 인형", label = "🧸", color = Color3.fromRGB(190, 150, 255), plush = true },
}
-- 자리별 풍선 (판마다 섞어요. "plush"는 DART_PLUSH_CHANCE로 들어가고 아니면 꽝)
SalaryConfig.DART_NEAR_PRIZES = { "won100", "won50", "tickets", "none", "none" } -- 가까운 자리 5곳
SalaryConfig.DART_FAR_PRIZES = { "won300", "won200", "won100", "plush" } -- 먼 자리 4곳 (+ 🎰 대박 자리 1곳)

-- 풍선 자리 10곳: 다트 출발점에서 본 각도(도)와 거리 → 서로 다른 방향이라 대부분 바로 노릴 수 있어요
--   far = 먼 자리 (그중 하나가 🎰 대박 자리)
SalaryConfig.DART_SLOTS = {}
for i, info in { { 34, 150 }, { 47, 205 }, { 60, 140 }, { 73, 215 }, { 86, 150 }, { 99, 220 }, { 112, 140 }, { 125, 205 }, { 138, 150 }, { 151, 195 } } do
	local angle, distance = math.rad(info[1]), info[2]
	SalaryConfig.DART_SLOTS[i] = {
		x = math.floor(SalaryConfig.DART_ORIGIN.X + math.cos(angle) * distance + 0.5),
		y = math.floor(SalaryConfig.DART_ORIGIN.Y - math.sin(angle) * distance + 0.5),
		far = distance > 180,
	}
end

function SalaryConfig.getDartPrize(id: string): any
	for _, info in SalaryConfig.DartPrizes do
		if info.id == id then
			return info
		end
	end
	return nil
end

-- 🎯 다트가 던진 뒤 t초에 어디 있는지 (angle = 라디안, 0 = 오른쪽 · π/2 = 위 / power = 0~1)
function SalaryConfig.dartFlight(angle: number, power: number, t: number): Vector2
	local speed = SalaryConfig.DART_SPEED * power
	local origin = SalaryConfig.DART_ORIGIN
	return Vector2.new(
		origin.X + math.cos(angle) * speed * t,
		origin.Y - math.sin(angle) * speed * t + 0.5 * SalaryConfig.DART_GRAVITY * t * t
	)
end

-- 🎈 풍선이 판 시작 뒤 t초에 어디 있는지 (위아래로 둥실 + 옆으로 살랑)
--   balloon = { x, y, r, amp, period, phase }
function SalaryConfig.dartBalloonPos(balloon: any, t: number): Vector2
	local wave = 2 * math.pi * t / balloon.period + balloon.phase
	local drift = 2 * math.pi * t / (balloon.period * 1.6) + balloon.phase * 2
	return Vector2.new(balloon.x + balloon.amp * 0.5 * math.sin(drift), balloon.y + balloon.amp * math.sin(wave))
end

-- 💥 한 번 던지기 계산: releaseT = 판 시작 뒤 몇 초에 놓았는지
--   → (맞은 풍선 번호 또는 nil, 날아간 시간, 멈춘 곳, 빗나간 이유 "short"/"over"/"side"/nil)
--   빗나간 이유는 제일 가까이 스친 풍선 기준: 풍선 위로 지나감 = "over"(너무 셈) / 아래 = "short"(약함) / 옆 = "side"
function SalaryConfig.dartSimulate(balloons: { any }, popped: { [number]: boolean }, angle: number, power: number, releaseT: number): (number?, number, Vector2, string?)
	local step = SalaryConfig.DART_STEP
	local width, height = SalaryConfig.DART_FIELD_W, SalaryConfig.DART_FIELD_H
	local steps = math.floor(SalaryConfig.DART_MAX_TIME / step)
	local position = SalaryConfig.DART_ORIGIN
	local closestGap = math.huge
	local closestOffset = Vector2.new(0, 1)
	local function missReason(): string
		if math.abs(closestOffset.X) > math.abs(closestOffset.Y) then
			return "side" -- 옆으로 빗나갔어요
		end
		return if closestOffset.Y < 0 then "over" else "short" -- 위로 지나감 = 너무 셈 / 아래 = 힘이 모자람
	end
	for n = 1, steps do
		local t = n * step
		position = SalaryConfig.dartFlight(angle, power, t)
		for index, balloon in balloons do
			if not popped[index] then
				local center = SalaryConfig.dartBalloonPos(balloon, releaseT + t)
				local offset = position - center
				local gap = offset.Magnitude - (balloon.r + SalaryConfig.DART_TIP)
				if gap < 0 then
					return index, t, position, nil
				end
				if gap < closestGap then
					closestGap = gap
					closestOffset = offset
				end
			end
		end
		if position.Y < SalaryConfig.DART_OVER_Y then
			return nil, t, position, "over" -- 너무 세서 벽을 넘어갔어요
		elseif position.Y > height + 20 or position.X < -20 or position.X > width + 20 then
			return nil, t, position, missReason()
		end
	end
	return nil, SalaryConfig.DART_MAX_TIME, position, missReason()
end

---------------------------------------------------------------------------
-- 📋 긴급 프로젝트 (하루 한 번, 사람마다 따로) — 실패해도 손해는 없지만 아주 어려워요!
--   성공하면 경고 -1 (경고가 없으면 보너스). 적발되면 그 자리에서 실패.
--   단계 종류(kind):
--     typing  ⌨️ 내 자리에서 보고서 문장 타자 (오타 나면 그 문장 다시)
--     math    🧮 내 자리에서 계산 문제 연속 (하나라도 틀리면 처음부터 새 문제)
--     memory  🧠 거래처 주문번호 기억 → 통화(일하기) 버티기 → 번호 입력 (틀리면 실패)
--     quiz    🧠 퀴즈 (QuizQuestions 30문제 중 하나, 틀리면 잠깐 잠기고 다른 문제) — 모든 프로젝트에 꼭 있어요
--     order   📊 (예전) 회의실 의자에서 슬라이드 번호 순서대로 누르기
--     printer 🖨️ 프린터 [E] / boss 👔 부장님 [E] / stamps 🖊️ 동료 결재 도장 [E] / boxes 📦 흩어진 택배 줍기
---------------------------------------------------------------------------
export type MissionStep = { kind: string, text: string, count: number?, place: string? }
export type MissionInfo = { id: string, emoji: string, name: string, seconds: number, steps: { MissionStep }, company: string? }

SalaryConfig.MISSION_WINDOWS = { { 10 * 60, 10 * 60 + 25 }, { 13 * 60 + 5, 15 * 60 } } -- 시작 시각 (점심과 겹치지 않게)
SalaryConfig.MISSION_LAST_START = 15 * 60 + 10 -- 이 시각을 넘기면 오늘 프로젝트는 건너뛰어요 (퇴근 전에 끝낼 수 없어서)
SalaryConfig.MISSION_BONUS = 3000 -- 경고가 없을 때 성공 보너스
SalaryConfig.MEMORY_SHOW = 3 -- 주문번호를 보여 주는 시간 (초)
SalaryConfig.MEMORY_HOLD = 12 -- 번호를 기억한 채 일하기로 버텨야 하는 시간 (초)
SalaryConfig.BOX_SPEEDS = { 12, 9, 7 } -- 택배를 하나씩 들 때마다 느려져요 (평소 16)
SalaryConfig.SHOP_DAILY_ORDERS = 2 -- 🚚 쇼핑몰 주문은 하루(근무일) 2번까지 → 다음 근무일에 📦 택배 보관함으로 와요
SalaryConfig.NOTICE_MAX = 30 -- 🔔 알림은 최근 30개까지 저장 (창에는 20개)

SalaryConfig.TypingPhrases = {
	"3분기 매출 보고",
	"전년 대비 성장률",
	"고객 만족도 개선",
	"비용 절감 방안",
	"신규 거래처 확보",
	"업무 효율 극대화",
	"차기 분기 목표",
	"시장 점유율 분석",
	"품질 관리 강화",
	"협업 체계 구축",
}

---------------------------------------------------------------------------
-- 🧠 퀴즈 (긴급 프로젝트마다 꼭 하나 풀어야 완수!)
--   30문제 중 하나가 랜덤으로 나와요. 보기 4개 (순서는 매번 섞여요).
--   틀리면 바로 다른 문제로 바뀌어요 (찍기 방지)
--   QUIZ_MAX_WRONG번 연속으로 틀리면 프로젝트 실패!
--   answer = choices 안에서 정답의 번호 (1부터)
---------------------------------------------------------------------------
export type QuizQuestion = { q: string, choices: { string }, answer: number }
SalaryConfig.QUIZ_WRONG_LOCK = 0 -- (기다리는 시간 없이 바로 다음 문제)
SalaryConfig.QUIZ_MAX_WRONG = 2 -- 이만큼 연속으로 틀리면 프로젝트 실패
SalaryConfig.QuizQuestions = {
	{ q = "규칙을 찾아요.\n4 → 17,  6 → 37,  9 → 82,  7 → ?", choices = { "49", "50", "51", "56" }, answer = 2 },
	{ q = "규칙을 찾아요.\n2  3  6\n4  5  20\n3  7  ?", choices = { "10", "18", "21", "24" }, answer = 3 },
	{ q = "🔺 + 🔺 = 10\n🔺 + 🟦 = 13\n🟦 + ⭐ = 12\n⭐ = ?", choices = { "3", "4", "5", "7" }, answer = 2 },
	{ q = "🍎 + 🍎 + 🍎 = 30\n🍌 + 🍌 + 🍎 = 18\n🍇 + 🍌 = 7\n🍎 + 🍌 × 🍇 = ?", choices = { "42", "17", "22", "26" }, answer = 3 },
	{ q = "시계가 3시 15분을 가리킬 때\n시침과 분침 사이의 각도는?", choices = { "0°", "7.5°", "15°", "30°" }, answer = 2 },
	{ q = "화살표가 도는 규칙을 찾아요.\n⬆️  ↗️  ↘️  ⬅️  ?", choices = { "⬇️", "↙️", "➡️", "⬆️" }, answer = 3 },
	{ q = "다음 빈칸에 올 것은?\n1, 11, 21, 1211, 111221, ?", choices = { "1112221", "312211", "221111", "13112221" }, answer = 2 },
	{ q = "다음 빈칸에 올 수는?\n61, 52, 63, 94, 46, ?", choices = { "81", "77", "18", "28" }, answer = 3 },
	{ q = "⚖️ 🍎🍎 = 🍌🍌🍌\n⚖️ 🍌🍌 = 🍇🍇🍇🍇\n🍎 하나는 🍇 몇 개?", choices = { "2개", "3개", "4개", "6개" }, answer = 2 },
	{ q = "다음 빈칸에 올 수는?\n2, 12, 30, 56, ?", choices = { "72", "80", "90", "110" }, answer = 3 },
	{ q = "다음 빈칸에 올 수는?\n1, 4, 27, 256, ?", choices = { "625", "1024", "3025", "3125" }, answer = 4 },
	{ q = "1쪽부터 100쪽까지 쪽번호를 적을 때\n숫자 9는 모두 몇 번 쓸까요?", choices = { "10번", "11번", "19번", "20번" }, answer = 4 },
	{ q = "거울에 비친 시계가 2시 30분으로 보여요.\n실제 시각은?", choices = { "2시 30분", "3시 30분", "9시 30분", "10시 30분" }, answer = 3 },
	{ q = "다음 빈칸에 올 수는?\n1, 10, 3, 9, 5, 8, 7, ?", choices = { "6", "7", "9", "11" }, answer = 2 },
	{ q = "🔷의 규칙을 찾아요.\n3 🔷 4 = 11\n5 🔷 2 = 13\n6 🔷 3 = 21\n7 🔷 4 = ?", choices = { "28", "31", "25", "33" }, answer = 2 },
	{ q = "규칙을 찾아요.\n2  5  8\n3  4  9\n6  3  ?", choices = { "9", "12", "15", "18" }, answer = 2 },
	{ q = "다음 빈칸에 올 수는?\n2, 4, 7, 12, 19, 30, ?", choices = { "41", "42", "43", "45" }, answer = 3 },
	{ q = "다음 빈칸에 올 수는?\n1, 2, 5, 14, 41, ?", choices = { "121", "122", "123", "124" }, answer = 2 },
	{ q = "다음 빈칸에 올 수는?\n3, 4, 8, 17, 33, ?", choices = { "50", "57", "58", "66" }, answer = 3 },
	{ q = "다음 빈칸에 올 수는?\n4, 6, 12, 14, 28, 30, ?", choices = { "32", "56", "60", "62" }, answer = 3 },
	{ q = "규칙을 찾아요.\n⭐ 1개 → 2개 → 4개\n🔺 1개 → 3개 → 9개\n🟦 1개 → 4개 → ?개", choices = { "7", "8", "12", "16" }, answer = 4 },
	{ q = "어제의 내일의 모레가 일요일이에요.\n오늘은 무슨 요일?", choices = { "목요일", "금요일", "토요일", "수요일" }, answer = 2 },
	{ q = "A: \"B는 거짓말쟁이야.\"\nB: \"C는 거짓말쟁이야.\"\nC: \"A와 B 둘 다 거짓말쟁이야.\"\n진실만 말하는 사람은?", choices = { "A", "B", "C", "A와 C" }, answer = 2 },
	{ q = "큰 정육면체 겉면을 빨갛게 칠하고\n작은 정육면체 27개로 잘랐어요.\n두 면만 빨간 조각은 몇 개?", choices = { "6개", "8개", "12개", "24개" }, answer = 3 },
	{ q = "A 혼자 6시간, B 혼자 3시간 걸리는 일.\n둘이 같이 하면 몇 시간?", choices = { "1.5시간", "2시간", "3시간", "4.5시간" }, answer = 2 },
	{ q = "출근할 땐 시속 60km, 퇴근할 땐 시속 40km.\n같은 길일 때 평균 속력은?", choices = { "45km", "48km", "50km", "52km" }, answer = 2 },
	{ q = "동전 2개를 던졌더니\n적어도 하나는 앞면이래요.\n둘 다 앞면일 확률은?", choices = { "1/2", "1/3", "1/4", "2/3" }, answer = 2 },
	{ q = "두 자리 수의 각 자리 합은 9예요.\n십의 자리와 일의 자리를 바꾸면\n27이 커져요. 원래 수는?", choices = { "27", "36", "45", "63" }, answer = 2 },
	{ q = "⚪⚪⚫ = 1\n⚪⚫⚪ = 2\n⚪⚫⚫ = 3\n⚫⚪⚪ = 4\n⚫⚫⚪ = ?", choices = { "5", "6", "7", "8" }, answer = 2 },
	{ q = "다음 빈칸에 올 수는?\n5, 10, 8, 16, 14, 28, ?", choices = { "24", "26", "30", "56" }, answer = 2 },
	-- 🧮 계산 문제 (엑셀 지옥 등 모든 퀴즈에 섞여 나와요)
	{ q = "사과 3개 + 배 2개 = 2,300원\n사과 1개 + 배 2개 = 1,500원\n사과 1개는?", choices = { "300원", "400원", "500원", "600원" }, answer = 2 },
	{ q = "원가 8,000원에 25% 이익을 붙여 정가를 정하고\n정가에서 10% 할인해 팔았어요. 이익은?", choices = { "500원", "800원", "1,000원", "1,200원" }, answer = 3 },
	{ q = "엑셀에서\nA1 = 7\nA2 = A1 × 2 − 3\nA3 = A2 × 2 − 3\nA3 = ?", choices = { "17", "19", "21", "25" }, answer = 2 },
	{ q = "1부터 50까지 홀수를 모두 더하면?", choices = { "600", "625", "650", "1275" }, answer = 2 },
	{ q = "시급 9,860원, 하루 6시간씩 주 5일 일하면\n일주일 급여는?", choices = { "285,800원", "295,800원", "296,800원", "305,800원" }, answer = 2 },
	{ q = "어떤 수에 6을 곱하고 18을 뺐더니 42예요.\n어떤 수는?", choices = { "8", "9", "10", "12" }, answer = 3 },
	{ q = "의자를 한 줄에 7개씩 놓으면 4개가 남고\n8개씩 놓으면 마지막 줄만 3자리가 비어요.\n의자는 최소 몇 개?", choices = { "45개", "53개", "61개", "67개" }, answer = 2 },
	{ q = "3명이 하루 4시간씩 6일 걸리는 일을\n4명이 하루 6시간씩 하면 며칠?", choices = { "2일", "3일", "4일", "4.5일" }, answer = 2 },
	{ q = "10,000원짜리 주식이 첫날 20% 오르고\n다음 날 20% 내렸어요. 지금 가격은?", choices = { "9,600원", "10,000원", "9,800원", "10,400원" }, answer = 1 },
	{ q = "1 + 2 + 3 + … + 40 = ?", choices = { "780", "800", "820", "840" }, answer = 3 },
	{ q = "엑셀에서\nSUM(3, 5, 7) × AVERAGE(2, 4, 6) = ?", choices = { "45", "60", "75", "90" }, answer = 2 },
	{ q = "12와 18의\n최소공배수 + 최대공약수 = ?", choices = { "36", "42", "48", "54" }, answer = 2 },
	{ q = "물 240g에 소금 60g을 녹였어요.\n소금물의 농도는?", choices = { "20%", "25%", "15%", "18%" }, answer = 1 },
	{ q = "시속 72km로 3시간 20분 달리면\n몇 km를 갈까요?", choices = { "220km", "230km", "240km", "250km" }, answer = 3 },
	{ q = "다음 빈칸에 올 수는?\n3, 7, 15, 31, 63, ?", choices = { "95", "126", "127", "128" }, answer = 3 },
	{ q = "x + y = 20\nx − y = 6\nx × y = ?", choices = { "84", "91", "96", "99" }, answer = 2 },
	{ q = "정가 50,000원 가방을 30% 할인하고\n할인가에서 쿠폰으로 10%를 더 깎았어요.\n최종 가격은?", choices = { "30,000원", "31,500원", "32,000원", "35,000원" }, answer = 2 },
	{ q = "직원 5명의 평균 나이는 32살.\n새 직원이 오니 평균이 31살이 됐어요.\n새 직원은 몇 살?", choices = { "25살", "26살", "27살", "28살" }, answer = 2 },
	{ q = "2×2×2×2×2 + 3×3×3 − 4×4 = ?", choices = { "41", "43", "45", "47" }, answer = 2 },
	{ q = "보고서 135쪽을 A는 1시간에 25쪽,\nB는 1시간에 20쪽 검토해요.\n둘이 같이 하면 몇 시간?", choices = { "2.5시간", "3시간", "3.5시간", "4시간" }, answer = 2 },
} :: { QuizQuestion }

SalaryConfig.Missions = {
	report = {
		id = "report",
		emoji = "📄",
		name = "3분기 보고서",
		seconds = 110,
		steps = {
			{ kind = "typing", text = "⌨️ 자리에서 보고서 1문장 타자 (🧩 풀기)", count = 1 },
			{ kind = "quiz", text = "🧠 자리에서 보고서 검토 퀴즈 (🧩 풀기)" },
			{ kind = "printer", text = "🖨️ 프린터에서 출력 [E]" },
			{ kind = "boss", text = "👔 부장님께 제출 [E]" },
		},
	},
	boxes = {
		id = "boxes",
		emoji = "📦",
		name = "택배 대란",
		seconds = 100,
		steps = {
			{ kind = "boxes", text = "📦 사무실 곳곳 택배 2개 줍기 (들수록 느려져요)", count = 2 },
			{ kind = "quiz", text = "🧠 자리에서 송장 확인 퀴즈 (🧩 풀기)" },
			{ kind = "boss", text = "👔 부장님께 전달 [E]" },
		},
	},
	excel = {
		id = "excel",
		emoji = "🧮",
		name = "엑셀 지옥",
		seconds = 100,
		steps = {
			{ kind = "math", text = "🧮 자리에서 계산 1문제 (틀리면 새 문제)", count = 1 },
			{ kind = "quiz", text = "🧠 자리에서 수식 검증 퀴즈 (🧩 풀기)" },
			{ kind = "printer", text = "🖨️ 프린터에서 출력 [E]" },
			{ kind = "boss", text = "👔 부장님께 제출 [E]" },
		},
	},
	claim = {
		id = "claim",
		emoji = "📞",
		name = "거래처 클레임",
		seconds = 110,
		steps = {
			{ kind = "answer", text = "📳 6초 안에 내 자리에 앉아서 전화 받기" },
			{ kind = "memory", text = "🧠 주문번호 기억 → 12초 일하며 통화 → 번호 입력 (🧩 풀기)" },
			{ kind = "quiz", text = "🧠 자리에서 보상 계산 퀴즈 (🧩 풀기)" },
			{ kind = "boss", text = "👔 부장님께 보고 [E]" },
		},
	},
	meeting = {
		id = "meeting",
		emoji = "📊",
		name = "임원 회의 발표",
		seconds = 100,
		steps = {
			{ kind = "quiz", text = "🧠 회의실 의자에서 임원 질문 퀴즈 (🧩 풀기)", place = "meeting" },
			{ kind = "stamps", text = "🖊️ 동료 1명에게 확인 도장 [E]", count = 1 },
			{ kind = "boss", text = "👔 부장님께 보고 [E]" },
		},
		company = "nunchi",
	},
} :: { [string]: MissionInfo }

SalaryConfig.TEST_MISSION = "" -- 🧪 스튜디오에서 이 프로젝트가 9시 15분쯤 바로 시작 ("report"/"boxes"/"excel"/"claim"/"meeting", ""면 끔)

SalaryConfig.GIFT_HONGSAM_DAYS = 1 -- (안 써요) 홍삼 선물세트는 하루에 한 번만 통해요
SalaryConfig.FLOWER_DETECT = 0.85 -- 꽃다발: 오늘 의심도 배율
SalaryConfig.CHOCO_SUSPICION = 25 -- 초콜릿: 의심도 감소량

---------------------------------------------------------------------------
-- 🪑 내 자리 꾸미기 (🛒 온라인 쇼핑 중 주문 → 다음 근무일 📦 택배 보관함 → 내 자리에서 뜯기)
--   칸(slot)마다 하나씩 장착. 모두 다른 사람 눈에도 보여요.
--   인테리어 점수 = 장착한 물건 가격 합 ÷ 1,000 (책상 명패에 자랑)
---------------------------------------------------------------------------
export type DecorOption = { id: string, emoji: string, name: string, price: number, description: string }
export type DecorSlot = { id: string, emoji: string, name: string, options: { DecorOption } }

SalaryConfig.DecorSlots = {
	{
		id = "chair",
		emoji = "🪑",
		name = "의자",
		options = {
			{ id = "chair_basic", emoji = "🪑", name = "기본 사무 의자", price = 0, description = "회사에서 준 삐걱거리는 의자" },
			{ id = "chair_gaming", emoji = "🎮", name = "게이밍 의자", price = 15000, description = "빨강·검정 레이싱 의자. 머리 받침까지!" },
			{ id = "chair_massage", emoji = "💆", name = "안마 의자", price = 35000, description = "갈색 가죽 + 두툼한 팔걸이. 회사에서 이걸?" },
			{ id = "chair_throne", emoji = "👑", name = "사장님 왕좌", price = 120000, description = "황금 왕좌와 왕관. 부장님이 보면 기절" },
		},
	},
	{
		id = "monitor",
		emoji = "🖥️",
		name = "모니터",
		options = {
			{ id = "monitor_basic", emoji = "🖥️", name = "기본 모니터", price = 0, description = "평범한 회사 모니터" },
			{ id = "monitor_dual", emoji = "🖥️", name = "듀얼 모니터", price = 20000, description = "한쪽은 일, 한쪽은 웹툰 (공식)" },
			{ id = "monitor_wide", emoji = "📺", name = "커브드 와이드", price = 40000, description = "양옆으로 휘어진 초광각 모니터" },
			{ id = "monitor_rgb", emoji = "🌈", name = "RGB 게이밍 모니터", price = 70000, description = "테두리가 무지개색으로 빛나요" },
		},
	},
	{
		id = "photo",
		emoji = "🖼️",
		name = "액자",
		options = {
			{ id = "photo_none", emoji = "🚫", name = "액자 없음", price = 0, description = "허전한 책상" },
			{ id = "photo_passion", emoji = "🔥", name = "\"열정!\" 액자", price = 3000, description = "부장님이 좋아하실 것 같은 문구" },
			{ id = "photo_goal", emoji = "🏃", name = "\"목표: 칼퇴\" 액자", price = 4000, description = "진짜 목표" },
			{ id = "photo_cat", emoji = "🐱", name = "고양이 사진", price = 6000, description = "보기만 해도 힐링" },
			{ id = "photo_idol", emoji = "⭐", name = "최애 포스터", price = 9000, description = "출근할 이유" },
			{ id = "photo_art", emoji = "🖼️", name = "명화 (짝퉁)", price = 25000, description = "모나리자… 같은 무언가" },
		},
	},
	{
		id = "desk",
		emoji = "🎨",
		name = "책상 색",
		options = {
			{ id = "desk_wood", emoji = "🟫", name = "기본 원목", price = 0, description = "회사 기본" },
			{ id = "desk_white", emoji = "⚪", name = "화이트", price = 5000, description = "깔끔한 미니멀" },
			{ id = "desk_black", emoji = "⚫", name = "블랙", price = 5000, description = "시크한 개발자 감성" },
			{ id = "desk_pink", emoji = "🌸", name = "핑크", price = 8000, description = "사무실에 봄이 왔어요" },
			{ id = "desk_gold", emoji = "✨", name = "황금 책상", price = 80000, description = "번쩍번쩍. 이걸 왜 사요?" },
		},
	},
	{
		id = "gadget",
		emoji = "💡",
		name = "소품",
		options = {
			{ id = "gadget_none", emoji = "🚫", name = "소품 없음", price = 0, description = "" },
			{ id = "gadget_cactus", emoji = "🌵", name = "미니 선인장", price = 4000, description = "물 안 줘도 되는 동료" },
			{ id = "gadget_figure", emoji = "🦸", name = "히어로 피규어", price = 10000, description = "오늘도 나를 지켜 줘" },
			{ id = "gadget_lamp", emoji = "💡", name = "무드등", price = 12000, description = "따뜻하게 빛나요 (정전 때 특히 예뻐요)" },
			{ id = "gadget_fish", emoji = "🐟", name = "미니 어항", price = 18000, description = "금붕어 '월급이'가 살아요" },
		},
	},
} :: { DecorSlot }

function SalaryConfig.getDecor(optionId: string): (DecorOption?, DecorSlot?)
	for _, slot in SalaryConfig.DecorSlots do
		for _, option in slot.options do
			if option.id == optionId then
				return option, slot
			end
		end
	end
	return nil, nil
end

---------------------------------------------------------------------------
-- 🏆 칭호: 업적을 깨면 열려요. 머리 위와 책상 명패에 보여요.
---------------------------------------------------------------------------
export type TitleInfo = { id: string, text: string, achievement: string? }
SalaryConfig.Titles = {
	{ id = "newbie", text = "🌱 신입 루팡" },
	{ id = "lunch_nap", text = "😴 낮잠 장인", achievement = "lunch_nap" },
	{ id = "caught", text = "📝 시말서 단골", achievement = "caught" },
	{ id = "chatterbox", text = "🗣️ 사내 수다왕", achievement = "chatterbox" },
	{ id = "cake_thief", text = "🍰 케이크 도둑", achievement = "cake_thief" },
	{ id = "combo_max", text = "🔥 곡예사", achievement = "combo_max" },
	{ id = "stock_buffett", text = "🧻 화장실 워런 버핏", achievement = "stock_buffett" },
	{ id = "lee_dodge", text = "🙈 눈치 백단", achievement = "lee_dodge" },
	{ id = "fired", text = "📦 짐 싸 본 사람", achievement = "fired" },
	{ id = "rich", text = "🏦 통장 부자", achievement = "rich" },
	{ id = "perfect_day", text = "😇 완벽한 하루", achievement = "perfect_day" },
	{ id = "dinner_ace", text = "🍻 회식 에이스", achievement = "dinner_ace" },
	{ id = "workshop_winner", text = "🌸 무궁화 챔피언", achievement = "workshop_winner" },
	{ id = "gift_hongsam", text = "🎁 아부의 달인", achievement = "gift_hongsam" },
	{ id = "mission_master", text = "🏅 프로젝트 마스터", achievement = "mission_master" },
	{ id = "legend_plush", text = "🦄 전설의 집게손", achievement = "legend_plush" },
	{ id = "plush_all", text = "📚 인형 수집가", achievement = "plush_all" },
	{ id = "arcade_champ", text = "🏆 오락실 챔피언", achievement = "arcade_champ" },
	{ id = "wheel_20", text = "🎡 대박 인생", achievement = "wheel_20" },
	{ id = "rank_daeri", text = "🎖️ 대리님", achievement = "rank_daeri" },
	{ id = "rank_isa", text = "🏅 이사님", achievement = "rank_isa" },
	{ id = "interior_master", text = "🏰 인테리어 장인", achievement = "interior_master" },
	{ id = "throne", text = "👑 왕좌의 주인", achievement = "throne" },
	{ id = "video_pro", text = "🎧 회의의 달인", achievement = "video_pro" },
	{ id = "cat_lover", text = "🐱 고양이 집사", achievement = "cat_lover" },
	{ id = "elevator_ninja", text = "😎 엘리베이터 닌자", achievement = "elevator_ninja" },
	{ id = "elevator_awkward", text = "😳 어색함 장인", achievement = "elevator_awkward" },
} :: { TitleInfo }

function SalaryConfig.getTitle(titleId: string): TitleInfo?
	for _, title in SalaryConfig.Titles do
		if title.id == titleId then
			return title
		end
	end
	return nil
end

SalaryConfig.INTERIOR_MASTER_SCORE = 150

---------------------------------------------------------------------------
-- 🎧 화상회의 하는 척: 가끔 질문이 와요 → VIDEO_ANSWER초 안에 그럴듯한 대답을 골라야 해요
--   첫 번째 보기가 정답이에요 (서버가 섞어서 보내요). {name}은 플레이어 이름으로 바뀌어요.
--   틀리거나 시간 초과 → 의심도 +VIDEO_FAIL + 부장님이 내 자리로 와요
---------------------------------------------------------------------------
SalaryConfig.VIDEO_ANSWER = 6
SalaryConfig.VIDEO_GAP = { 12, 22 } -- 질문 간격 (초)
SalaryConfig.VIDEO_FAIL = 40
SalaryConfig.VIDEO_BONUS = 300
SalaryConfig.VideoQuestions = {
	{ "{name} 씨, 이번 분기 목표 어떻게 생각해요?", { "공격적으로 가야 한다고 봅니다!", "(음소거 상태로 코 고는 소리)", "잠깐만요, 웹툰 다음 화가…" } },
	{ "자료 공유 화면 보이세요?", { "네, 잘 보입니다!", "아니요, 쇼핑몰 보는 중이라…", "……(아무 말 없음)" } },
	{ "{name} 씨 의견은요?", { "앞선 의견에 전적으로 동의합니다", "점심이요? 짜장면이요", "죄송해요, 졸았어요" } },
	{ "다음 회의는 언제가 좋을까요?", { "편하신 시간에 맞추겠습니다", "영원히 안 했으면…", "퇴근 후에 하죠 (거짓말)" } },
	{ "방금 제 말 들으셨어요?", { "네, 핵심은 일정 조율이죠", "어… 네? 뭐라고요?", "(카메라에 고양이만 보임)" } },
	{ "예산 문제는 어떻게 할까요?", { "우선순위부터 다시 정리하겠습니다", "로또를 사죠", "부장님 카드로…" } },
	{ "마지막으로 질문 있는 분?", { "없습니다! 깔끔했습니다", "언제 끝나요?", "(마이크 켜진 채 라면 후루룩)" } },
	{ "{name} 씨 카메라 좀 켜 주세요", { "네, 지금 켜겠습니다!", "지금 잠옷이라서요…", "카메라가 고장 났어요 (거짓말)" } },
	{ "이 안건 찬성하세요?", { "네, 적극 찬성합니다", "빨리 끝나는 쪽이요", "(대답 없이 퇴장)" } },
	{ "고객 피드백 정리됐나요?", { "오늘 중으로 공유드리겠습니다", "고객이요? 누구요?", "피드백은 마음속에…" } },
}

---------------------------------------------------------------------------
-- 🐱 사무실 고양이 '월급냥': 하루에 몇 번 사무실에 놀러 와요
--   [E] 쓰다듬기 → 의심도 -CAT_PET_RELIEF (사람마다 쿨타임)
--   부장님 근처로 가면 부장님이 CAT_DISTRACT초 동안 정신이 팔려요 (감시 멈춤!)
---------------------------------------------------------------------------
SalaryConfig.CAT_VISITS = 3 -- 하루 방문 횟수
SalaryConfig.CAT_STAY = 75 -- 한 번 놀다 가는 시간 (초)
SalaryConfig.CAT_PET_RELIEF = 20
SalaryConfig.CAT_PET_COOLDOWN = 25
SalaryConfig.CAT_DISTRACT = 6
SalaryConfig.CAT_DESK_SIT = 15
SalaryConfig.TEST_CAT = false -- 🧪 true면 스튜디오에서 9시 10분쯤 바로 와요

---------------------------------------------------------------------------
-- 🚪 어색한 엘리베이터 → 🏢 옥상
--   사무실 엘리베이터 [E] → 엘리베이터 안 (몇 초) → 옥상 도착 / 옥상 엘리베이터 → 사무실
--   😱 근무 중엔 ELEVATOR_BOSS_CHANCE 확률로 부장님과 단둘이 타요 → 미니게임!
--     📱 폰 보기 [1] / 🙂 앞 보기 [2] 버튼으로 골라요. (부장님 행동은 딱 2번)
--     👀 부장님이 쳐다보면 → 📱 폰을 보고 있어야 해요 (눈 마주치면 안 돼요)
--     🗣️ 부장님이 말을 걸면 → 🙂 앞을 보고 있어야 해요 (어른이 말하는데 폰을 봐?)
--     ⚠️ 예고는 ELEVATOR_WARN초뿐. 틀릴 때마다 의심도 +ELEVATOR_FAIL (100이 되면 적발)
---------------------------------------------------------------------------
SalaryConfig.ELEVATOR_RIDE = 8 -- 부장님이랑 탈 때 (초)
SalaryConfig.ELEVATOR_RIDE_ALONE = 4 -- 혼자 탈 때
SalaryConfig.ELEVATOR_BOSS_CHANCE = 0.2

-- 🔊 공간 소리 ID (Ambience 모듈이 써요). ""로 비워 두면 그 소리는 안 나요.
--   크리에이터 스토어(오디오)에서 골라 "rbxassetid://숫자" 형태로 넣으세요.
SalaryConfig.Sounds = {
	office = "", -- 사무실 배경: 에어컨 웅웅 + 키보드 소리 (반복)
	corridor = "", -- 복도 배경: 조용한 형광등 소리 (반복)
	pantry = "", -- 탕비실: 냉장고·정수기 소리 (반복)
	lobby = "", -- 1층 로비 배경 (반복)
	street = "", -- 건물 앞 거리: 차 소리·사람 소리 (반복)
	elevatorDing = "rbxasset://sounds/electronicpingshort.wav", -- 엘리베이터 도착 "띵" (로블록스 기본 소리)
}
SalaryConfig.SoundVolume = { office = 0.3, corridor = 0.2, pantry = 0.25, lobby = 0.25, street = 0.4 }
SalaryConfig.ELEVATOR_EVENTS = { 1, 1 } -- 부장님이 쳐다보거나 말 거는 횟수 (최소, 최대) → 딱 한 번만
SalaryConfig.ELEVATOR_WARN = 3 -- ⚠️ 예고 후 실제로 쳐다보거나 말 걸기까지 (초): 고를 시간 3초
SalaryConfig.ELEVATOR_GRACE = 0.2 -- 인터넷 지연 봐주기 (초)
SalaryConfig.ELEVATOR_FAIL = 35 -- 틀릴 때마다 오르는 의심도
SalaryConfig.ElevatorTalkLines = { "어이, 자네.", "흠흠.", "요즘 어때?" } -- 짧게!

-- 🐦 옥상 비둘기 친구
--   🍪 🏪 사내 매점 [🐦 비둘기] 탭에서 과자를 사서 🎒에 넣어 둬요
--   🍞 모이 통 [E] → 과자 고르기 → 비둘기들이 날아와 PIGEON_STAY초 동안 콕콕 쪼아 먹어요 (과자 1개 사용)
--   ⚠️ 👮 옥상 경비원이 PIGEON_GUARD_RANGE 안으로 다가오면 비둘기들이 먼저 놀라서 푸드덕 날아가요 (살아 있는 근접 알람)
--   💕 친밀도(과자 줄 때마다 +1~3점)가 오를수록 더 많이, 더 희귀한 비둘기가 와요. 하루 동안 과자를 안 주면 친밀도가 조금 줄어요
--   🎁 비둘기의 보은: 친해지면 가끔 비둘기가 선물을 물어 와요 (좋은 과자일수록 자주, 좋은 걸로)
--   📒 비둘기 관찰 노트에 만난 비둘기와 🐦 비둘기 보물이 기록돼요
SalaryConfig.PIGEON_STAY = 60
SalaryConfig.PIGEON_MAX_FLOCK = 9
SalaryConfig.PIGEON_DECAY = 1 -- 과자를 안 준 하루마다 줄어드는 친밀도
SalaryConfig.PIGEON_SNACK_MAX = 20 -- 🎒 과자는 한 종류에 이만큼까지
-- 🍪 비둘기 과자 (🏪 매점에서 사요)
--   friend: 친밀도 +점수 / flock: 더 오는 비둘기 수 / luck: 희귀 비둘기·좋은 선물 운 / gift: 선물 확률 +
SalaryConfig.PigeonSnacks = {
	{ id = "cookie", emoji = "🍪", name = "쿠키 부스러기", price = 150, friend = 1, flock = 0, luck = 0, gift = 0, description = "책상 서랍에서 나온 부스러기. 일단 먹긴 해요" },
	{ id = "pretzel", emoji = "🥨", name = "프레첼 조각", price = 300, friend = 1, flock = 1, luck = 0.5, gift = 0.05, description = "짭짤해서 비둘기들이 은근 좋아해요" },
	{ id = "popcorn", emoji = "🍿", name = "버터 팝콘", price = 550, friend = 2, flock = 1, luck = 1, gift = 0.1, description = "고소한 냄새에 옆 건물 비둘기까지 와요" },
	{ id = "shrimp", emoji = "🍘", name = "새우 과자", price = 900, friend = 2, flock = 2, luck = 1.5, gift = 0.15, description = "새우깡 같은 과자. 손이 가요 부리가 가요~" },
	{ id = "croissant", emoji = "🥐", name = "버터 크루아상", price = 1600, friend = 3, flock = 3, luck = 2.5, gift = 0.25, description = "빵집 고급 크루아상. 비둘기계의 오마카세" },
}
function SalaryConfig.getPigeonSnack(snackId: string): any
	for _, snack in SalaryConfig.PigeonSnacks do
		if snack.id == snackId then
			return snack
		end
	end
	return nil
end
-- 🎁 비둘기의 보은: 과자를 줄 때마다 선물 확률 = 친밀도 단계 확률 + 과자 확률 (하루 PIGEON_GIFT_DAILY번까지)
--   선물은 PIGEON_GIFT_DELAY초 뒤 비둘기가 물고 와서 모이 통 근처에 떨어뜨려요 → [E] 줍기 (나만 주울 수 있어요)
SalaryConfig.PIGEON_GIFT_DAILY = 1 -- (과자는 하루 한 번이라 선물도 하루 한 번)
SalaryConfig.PIGEON_GIFT_CHANCE = { 0, 0.3, 0.45, 0.6, 0.75 } -- 친밀도 단계별 (낯가림 단계에선 아직 안 줘요 · 하루 한 번이라 넉넉하게)
SalaryConfig.PIGEON_GIFT_MAX_CHANCE = 0.95
SalaryConfig.PIGEON_GIFT_DELAY = { 20, 50 } -- 과자를 주고 몇 초 뒤에 오나 (최소, 최대)
SalaryConfig.PIGEON_GIFT_WAIT = 120 -- 내가 옥상에 없으면 이만큼 더 기다려 줘요 (그래도 없으면 다음 기회에)
SalaryConfig.PIGEON_GIFT_LIFETIME = 150 -- 떨어진 선물이 남아 있는 시간 (초)
SalaryConfig.PIGEON_TREASURE_RESELL = 0.5 -- 🐦 비둘기 보물: 두 번째부터는 중고로 팔아서 이 비율만큼
-- 🐦 선물 목록 (weight: 기본 가중치 / perLuck: 운 1마다 더해지는 가중치)
--   kind = "money" 바로 돈 · "tickets" 🎟️ 오락실 티켓 · "valuable" 귀중품(처음엔 주인에게 사례금, 다음부턴 중고로 팔아요) · "joke" 장난(0원, 수집용)
--   운 = (친밀도 단계 - 1) + 과자의 luck
SalaryConfig.PigeonTreasures = {
	{ id = "coin", emoji = "💰", name = "반짝이는 동전", kind = "money", min = 30, max = 150, weight = 40, perLuck = -4, description = "자판기 밑에서 주워 왔나 봐요" },
	{ id = "bill", emoji = "💵", name = "꼬깃꼬깃 지폐", kind = "money", min = 300, max = 800, weight = 16, perLuck = 1.5, description = "누가 옥상에서 흘린 비상금?!" },
	{ id = "ticket", emoji = "🎟️", name = "오락실 티켓 뭉치", kind = "tickets", min = 2, max = 5, weight = 14, perLuck = 0, description = "오락실 앞 비둘기들의 전리품" },
	{ id = "sock", emoji = "🧦", name = "짝 잃은 양말", kind = "joke", weight = 12, perLuck = -1, description = "냄새는 묻지 마세요…" },
	{ id = "can", emoji = "🥫", name = "빈 캔", kind = "joke", weight = 10, perLuck = -1, description = "분리수거는 비둘기도 하는 시대" },
	{ id = "leaf", emoji = "🍂", name = "마른 낙엽", kind = "joke", weight = 8, perLuck = -0.8, description = "비둘기 눈엔 이게 보물이래요" },
	{ id = "key", emoji = "🔑", name = "잃어버린 열쇠", kind = "valuable", value = 600, weight = 6, perLuck = 1.5, description = "경비실 비상 열쇠 같은데…?" },
	{ id = "ring", emoji = "💍", name = "반짝 반지", kind = "valuable", value = 1800, weight = 3, perLuck = 1.2, description = "옆 회사 대리님의 프러포즈 반지?!" },
	{ id = "watch", emoji = "⌚", name = "손목시계", kind = "valuable", value = 3000, weight = 2, perLuck = 1, description = "아직 째깍째깍 잘 가요" },
	{ id = "gem", emoji = "💎", name = "커다란 보석", kind = "valuable", value = 10000, weight = 0.4, perLuck = 0.5, rare = true, description = "비둘기가 어디서 이런 걸…? 전설의 보은" },
}
function SalaryConfig.getPigeonTreasure(treasureId: string): any
	for _, treasure in SalaryConfig.PigeonTreasures do
		if treasure.id == treasureId then
			return treasure
		end
	end
	return nil
end
-- 선물 확률 (친밀도 단계, 과자)
function SalaryConfig.pigeonGiftChance(levelIndex: number, snack: any): number
	local base = SalaryConfig.PIGEON_GIFT_CHANCE[levelIndex] or 0
	if base <= 0 then
		return 0
	end
	return math.min(SalaryConfig.PIGEON_GIFT_MAX_CHANCE, base + (if snack then snack.gift else 0))
end
-- 선물 뽑기 (친밀도 단계, 과자) → 선물
function SalaryConfig.rollPigeonTreasure(levelIndex: number, snack: any): any
	local luck = (levelIndex - 1) + (if snack then snack.luck else 0)
	local total = 0
	local pool = {}
	for _, treasure in SalaryConfig.PigeonTreasures do
		local weight = math.max(0, treasure.weight + treasure.perLuck * luck)
		if weight > 0 then
			total += weight
			table.insert(pool, { treasure = treasure, weight = weight })
		end
	end
	local roll = math.random() * total
	for _, entry in pool do
		roll -= entry.weight
		if roll <= 0 then
			return entry.treasure
		end
	end
	return SalaryConfig.PigeonTreasures[1]
end
-- 친밀도 단계: 친밀도 점수 → 이름과 한 번에 오는 비둘기 수 (예전엔 모이 준 횟수 = 점수)
SalaryConfig.PigeonLevels = {
	{ feeds = 0, name = "낯가림", flock = 3 },
	{ feeds = 3, name = "눈인사", flock = 4 },
	{ feeds = 7, name = "단골", flock = 5 },
	{ feeds = 12, name = "절친", flock = 6 },
	{ feeds = 20, name = "비둘기 대장", flock = 7 },
}
function SalaryConfig.pigeonLevel(feeds: number): (number, { feeds: number, name: string, flock: number })
	local index = 1
	for i, level in SalaryConfig.PigeonLevels do
		if feeds >= level.feeds then
			index = i
		end
	end
	return index, SalaryConfig.PigeonLevels[index]
end
-- weight: 기본 확률 가중치 / perLevel: 친밀도 단계마다 더해지는 가중치 / minLevel: 이 단계부터 나와요
SalaryConfig.Pigeons = {
	{ id = "gray", emoji = "🐦", name = "회색 비둘기", rarity = "common", weight = 60, perLevel = 0, minLevel = 1, body = Color3.fromRGB(130, 135, 150), head = Color3.fromRGB(95, 100, 120), description = "어디에나 있는 동네 터줏대감" },
	{ id = "spotted", emoji = "🐦", name = "얼룩 비둘기", rarity = "common", weight = 25, perLevel = 0, minLevel = 1, body = Color3.fromRGB(230, 225, 215), head = Color3.fromRGB(90, 80, 75), description = "흰 바탕에 갈색 얼룩, 은근 멋쟁이" },
	{ id = "chubby", emoji = "🐦", name = "뚱뚱한 비둘기", rarity = "uncommon", weight = 10, perLevel = 2, minLevel = 2, body = Color3.fromRGB(150, 140, 160), head = Color3.fromRGB(110, 100, 125), scale = 1.35, description = "모이를 너무 많이 먹었어요" },
	{ id = "white", emoji = "🕊️", name = "흰 비둘기", rarity = "rare", weight = 4, perLevel = 2, minLevel = 2, body = Color3.fromRGB(250, 250, 250), head = Color3.fromRGB(245, 245, 245), description = "평화의 상징. 오늘은 칼퇴 각?" },
	{ id = "crown", emoji = "👑", name = "왕관 비둘기", rarity = "legend", weight = 1, perLevel = 1, minLevel = 3, body = Color3.fromRGB(110, 140, 190), head = Color3.fromRGB(90, 120, 175), crown = true, description = "비둘기계의 사장님. 위엄이 넘쳐요" },
	{ id = "rainbow", emoji = "🌈", name = "무지개 비둘기", rarity = "legend", weight = 0, perLevel = 1, minLevel = 4, rainbow = true, body = Color3.fromRGB(255, 120, 120), head = Color3.fromRGB(120, 180, 255), description = "절친에게만 나타난다는 전설의 비둘기" },
}

-- 🏀 옥상 농구: 한 판 = 공 HOOP_SHOTS개
--   슛 게이지를 초록(🎯 클린슛)에 멈추면 +3, 노랑(골인)이면 +2, 연속 성공이면 +1 보너스 · 슛할수록 게이지가 빨라져요
--   🔊 공 튀는 소리(새 판·놓친 공)가 나면 👮 옥상 경비원이 농구대 쪽으로 확인하러 와요
SalaryConfig.HOOP_SHOTS = 5
SalaryConfig.HOOP_DAILY_PRIZES = 6
SalaryConfig.HOOP_TARGET = 0.72 -- 게이지에서 가장 좋은 곳
SalaryConfig.HOOP_PERFECT = 0.035 -- 여기까지 🎯 클린슛
SalaryConfig.HOOP_GOOD = 0.09 -- 여기까지 골인
SalaryConfig.HOOP_RIM = 0.15 -- 여기까지 림 맞고 튕김 (실패)
SalaryConfig.HoopPrizes = {
	{ score = 15, prize = 1200, label = "🔥 옥상의 슈퍼스타!" },
	{ score = 10, prize = 600, label = "🏀 슛 감 좋은데?" },
	{ score = 6, prize = 230, label = "👍 나쁘지 않아요" },
}
-- 슛 게이지 (t = 게이지가 움직이기 시작한 뒤 지난 초, shot = 몇 번째 공): 서버와 화면이 같은 식
function SalaryConfig.hoopGauge(t: number, shot: number): number
	return 0.5 + 0.5 * math.sin(t * (2.4 + 0.45 * (shot - 1)) - 1.2)
end
-- 결과: "swish" / "make" / "rim" / "miss"
--   widen: 💪 근력 보너스 (0.2면 모든 칸이 20% 넓어져요)
function SalaryConfig.hoopResult(value: number, widen: number?): string
	local off = math.abs(value - SalaryConfig.HOOP_TARGET)
	local scale = 1 + (widen or 0)
	if off <= SalaryConfig.HOOP_PERFECT * scale then
		return "swish"
	elseif off <= SalaryConfig.HOOP_GOOD * scale then
		return "make"
	elseif off <= SalaryConfig.HOOP_RIM * scale then
		return "rim"
	end
	return "miss"
end

-- 🌅 노을 타임 (SUNSET_START ~ 퇴근): 옥상 하늘이 주황빛으로 물들어요
--   옥상에서 SUNSET_WATCH초 감상하면 "오늘 하루도 고생했다…" → 의심도 0 + 오늘의 의심도 속도 SUNSET_DELTA (하루 한 번)
--   노을 시간엔 옥상에서 의심도가 SUNSET_DECAY배 빨리 내려가요
--   📸 포토존에서 노을 사진 (하루 한 장씩 앨범에 모여요)
--   😅 대신 부장님도 노을 보러 자주 올라와요 (SUNSET_VISIT_AFTER초 안에)
SalaryConfig.SUNSET_START = 17 * 60
SalaryConfig.SUNSET_WATCH = 12
SalaryConfig.SUNSET_DELTA = -0.1
SalaryConfig.SUNSET_DECAY = 3
SalaryConfig.SUNSET_VISIT_AFTER = { 10, 20 }
SalaryConfig.SUNSET_PHOTO_PRIZE = 450 -- 그날 첫 노을 사진

-- 🔭 건너편 빌딩 관찰 일지: 옥상 오른쪽 관찰 망원경 → (주)야근물산 창문들을 둘러봐요
--   창문에 장면이 잠깐씩 나타났다 사라져요 (시간대마다 다른 장면!) → 렌즈 가운데에 SCOPE_FOCUS초 맞추면 📒 기록
--   처음 발견한 장면만 보상 (흔함 / 희귀 / 전설)
SalaryConfig.SCOPE_COLUMNS = 5
SalaryConfig.SCOPE_ROWS = 4
SalaryConfig.SCOPE_FOCUS = 1.2
SalaryConfig.SCOPE_ACTIVE = { 3, 5 } -- 동시에 장면이 보이는 창문 수 (최소, 최대)
SalaryConfig.SCOPE_SHOW = { 6, 12 } -- 장면 하나가 보이는 시간 (초)
SalaryConfig.ScopeRewards = { common = 230, rare = 750, legend = 1500 }
-- times: 나오는 시간대 ("morning" 9~12시 · "lunch" 12~13시 · "afternoon" 13~18시) / weight: 잘 나오는 정도
SalaryConfig.ScopeScenes = {
	{ id = "sleeper", emoji = "😴💤", name = "엎드려 자는 대리", rarity = "common", weight = 10, times = { "morning", "afternoon" }, description = "우리랑 똑같네…" },
	{ id = "ramen", emoji = "🍜🥢", name = "몰래 컵라면", rarity = "common", weight = 10, times = { "lunch", "afternoon" }, description = "냄새가 여기까지 날 것 같아요" },
	{ id = "gamer", emoji = "🎮🖥️", name = "게임하는 팀장", rarity = "common", weight = 8, times = { "morning", "afternoon" }, description = "보스전 중이라 일 못 함" },
	{ id = "interview", emoji = "📞🤫", name = "몰래 이직 통화", rarity = "common", weight = 8, times = { "morning", "afternoon" }, description = '"네, 다음 주 면접 가능합니다…"' },
	{ id = "yoga", emoji = "🧘", name = "요가하는 인턴", rarity = "common", weight = 7, times = { "morning", "lunch" }, description = "책상 위에서 다운독 자세" },
	{ id = "cat", emoji = "🐈📦", name = "몰래 데려온 고양이", rarity = "common", weight = 7, times = { "morning", "lunch", "afternoon" }, description = "저 회사에도 냥이가?!" },
	{ id = "late", emoji = "🏃💦", name = "지각해서 뛰어오는 직원", rarity = "common", weight = 9, times = { "morning" }, description = "9시 1분… 아슬아슬!" },
	{ id = "boxes", emoji = "📦📦😵", name = "택배에 파묻힌 사원", rarity = "common", weight = 6, times = { "morning", "afternoon" }, description = "택배 대란은 저기도 있구나" },
	{ id = "nap", emoji = "🪑🪑😪", name = "의자 붙여 낮잠", rarity = "common", weight = 9, times = { "lunch" }, description = "점심시간의 정석" },
	{ id = "selfie", emoji = "🤳✨", name = "셀카 찍는 부장님", rarity = "common", weight = 6, times = { "afternoon" }, description = "각도 잡는 중… 진지해요" },
	{ id = "cleanup", emoji = "🧹🧽", name = "대청소하는 날", rarity = "common", weight = 5, times = { "afternoon" }, description = "오늘은 일 대신 청소" },
	{ id = "chicken", emoji = "🍗🍺", name = "회의실 치킨 파티", rarity = "rare", weight = 3, times = { "afternoon" }, description = "회의록: 양념 vs 후라이드" },
	{ id = "cake", emoji = "🎂🎉", name = "깜짝 생일 파티", rarity = "rare", weight = 3, times = { "lunch", "afternoon" }, description = "주인공만 모르는 중" },
	{ id = "confess", emoji = "💌😳", name = "몰래 고백 쪽지", rarity = "rare", weight = 3, times = { "morning", "afternoon" }, description = "사내 연애 현장 포착!" },
	{ id = "window", emoji = "🧗🧽", name = "창문 닦는 아저씨", rarity = "rare", weight = 3, times = { "morning", "afternoon" }, description = "눈이 마주쳤다… 손을 흔들어 줘요" },
	{ id = "fire", emoji = "🔥🖨️", name = "복사기 불났다", rarity = "rare", weight = 2, times = { "afternoon" }, description = "다들 소화기 찾는 중" },
	{ id = "dance", emoji = "💃🕺", name = "혼자 춤추는 사장님", rarity = "legend", weight = 1, times = { "afternoon" }, description = "아무도 안 보는 줄 알고…" },
	{ id = "dino", emoji = "🦖👔", name = "공룡 옷 출근", rarity = "legend", weight = 1, times = { "morning" }, description = "벌칙인지 패션인지 알 수 없어요" },
	{ id = "ghost", emoji = "👻🌑", name = "수상한 그림자", rarity = "legend", weight = 1, times = { "morning", "lunch" }, description = "불 꺼진 방에 누가…?" },
	{ id = "spy", emoji = "🔭👀", name = "이쪽을 엿보는 저쪽 감사관", rarity = "legend", weight = 1, times = { "morning", "afternoon" }, description = "저쪽도 망원경으로 우리를 보고 있었다!!" },
}
function SalaryConfig.getScopeScene(sceneId: string): any
	for _, scene in SalaryConfig.ScopeScenes do
		if scene.id == sceneId then
			return scene
		end
	end
	return nil
end

-- 📚 자격증 (🏪 사내 매점 📚 자격증 탭)
--   응시료를 내고 시험(퀴즈 CERT_QUESTIONS문제 중 CERT_PASS문제 이상)을 보면 합격!
--   합격하면 🎖️ 승진 경험치 + 영구 특전. 시험은 하루 한 번 (떨어지면 응시료만 날아가요)
--   (도박·주식으로 번 돈이 승진으로 이어지는 유일한 길! 대신 자격증마다 한 번만)
SalaryConfig.CERT_QUESTIONS = 3
SalaryConfig.CERT_PASS = 2
SalaryConfig.CERT_TIME = 25 -- 문제당 제한 시간 (초)
SalaryConfig.Certificates = {
	{ id = "computer", emoji = "💻", name = "컴활 2급", price = 15000, xp = 3000, rank = 1, perk = "💼 일하기 수입 +1원/초" },
	{ id = "toeic", emoji = "🌍", name = "토익 800", price = 30000, xp = 6000, rank = 2, perk = "🎧 화상회의 대답 보너스 ×1.5" },
	{ id = "history", emoji = "🏯", name = "한국사 1급", price = 50000, xp = 10000, rank = 3, perk = "🧠 긴급 프로젝트 퀴즈 오답 한 번 더 봐줘요" },
	{ id = "excel", emoji = "📊", name = "엑셀 마스터", price = 80000, xp = 16000, rank = 4, perk = "📋 긴급 프로젝트 제한 시간 +20초" },
	{ id = "pmp", emoji = "📈", name = "PMP 자격증", price = 150000, xp = 30000, rank = 5, perk = "⏱️ 업무 할당량 -10%" },
	{ id = "mba", emoji = "🎓", name = "MBA 학위", price = 300000, xp = 60000, rank = 6, perk = "💰 기본급 +10%" },
}
function SalaryConfig.getCertificate(certId: string): any
	for _, cert in SalaryConfig.Certificates do
		if cert.id == certId then
			return cert
		end
	end
	return nil
end

-- 🎟️ 특수 쿠폰 (🏪 사내 매점 🎟️ 쿠폰 탭): 사자마자 바로 써요
SalaryConfig.TRIP_SECONDS = 60
SalaryConfig.Coupons = {
	{ id = "pardon", emoji = "📜", name = "시말서 면제권", price = 50000, description = "경고 1개를 지워요 (하루 1장)" },
	{ id = "trip", emoji = "✈️", name = "부장님 출장 보내기", price = 30000, description = "부장님이 60초 동안 사무실을 비워요 (사무실 모두에게 좋아요!)" },
	{ id = "halfday", emoji = "🏖️", name = "반차권", price = 40000, description = "오늘 남은 시간은 쉬어요: 안 들켜요 · 업무·실적 목표 통과 (농땡이 수입은 없어요)" },
	{ id = "coffee_pass", emoji = "☕", name = "커피 정기권", price = 10000, description = "오늘 하루 이과장이 몇 번이든 눈감아 줘요" },
}
function SalaryConfig.getCoupon(couponId: string): any
	for _, coupon in SalaryConfig.Coupons do
		if coupon.id == couponId then
			return coupon
		end
	end
	return nil
end

-- 🖥️ 책상 업그레이드 (🪑 꾸미기 창의 ⚙️ 장비 탭): 단계별로 영구 효과, 저장돼요
--   value: 의자 = 복귀 시간 줄이는 비율 / 모니터 = 화면 농땡이 들킴 줄이는 비율
--          파티션 = 내 자리에서 부장님 시야 거리 줄이는 칸 수 / 인기척 센서 = 부장님이 이 칸 안에 오면 📳
SalaryConfig.DeskUpgrades = {
	{ id = "chair", emoji = "🪑", name = "의자", levels = {
		{ price = 10000, value = 0.10, text = "복귀 시간 -10%" },
		{ price = 50000, value = 0.20, text = "복귀 시간 -20%" },
		{ price = 200000, value = 0.30, text = "복귀 시간 -30%" },
	} },
	{ id = "monitor", emoji = "🖥️", name = "모니터", levels = {
		{ price = 10000, value = 0.05, text = "화면 농땡이 들킴 -5%" },
		{ price = 50000, value = 0.10, text = "화면 농땡이 들킴 -10%" },
		{ price = 200000, value = 0.15, text = "화면 농땡이 들킴 -15%" },
	} },
	{ id = "partition", emoji = "🧱", name = "파티션", levels = {
		{ price = 20000, value = 2, text = "내 자리에서 부장님 시야 -2칸" },
		{ price = 80000, value = 4, text = "내 자리에서 부장님 시야 -4칸" },
		{ price = 300000, value = 6, text = "내 자리에서 부장님 시야 -6칸" },
	} },
	{ id = "sensor", emoji = "🔔", name = "인기척 센서", levels = {
		{ price = 30000, value = 16, text = "부장님이 16칸 안에 오면 📳 진동" },
		{ price = 100000, value = 24, text = "부장님이 24칸 안에 오면 📳 진동" },
	} },
}
SalaryConfig.SENSOR_COOLDOWN = 8
function SalaryConfig.getDeskUpgrade(upgradeId: string): any
	for _, upgrade in SalaryConfig.DeskUpgrades do
		if upgrade.id == upgradeId then
			return upgrade
		end
	end
	return nil
end

-- 👔 출근룩 (캐릭터에 직접 입혀요, 다른 사람 눈에도 보여요)
--   칸(slot)마다 하나씩 착용. 산 옷은 저장돼요.
--   💸 착용한 옷값 합이 OUTFIT_LUXURY원 이상이면 출근할 때 부장님이 눈치채요 → 오늘의 의심도 속도 +OUTFIT_LUXURY_DELTA
--   pieces: 붙일 부위(part)에 만들 조각들 (offset = 부위 중심 기준, 앞쪽이 -Z)
SalaryConfig.OUTFIT_ENABLED = false -- 🚧 출근룩 잠시 꺼 둠 (true로 바꾸면 다시 켜져요. 산 옷 기록은 그대로 저장돼 있어요)
if not SalaryConfig.OUTFIT_ENABLED then
	-- 출근룩을 꺼 둔 동안은 출근룩 업적도 도감에서 숨겨요 (깰 방법이 없으니까)
	for i = #SalaryConfig.Achievements, 1, -1 do
		if string.sub(SalaryConfig.Achievements[i].id, 1, 7) == "outfit_" then
			table.remove(SalaryConfig.Achievements, i)
		end
	end
end
SalaryConfig.OUTFIT_LUXURY = 100000
SalaryConfig.OUTFIT_LUXURY_DELTA = 0.05
local GOLD = Color3.fromRGB(255, 200, 60)
local BLACK = Color3.fromRGB(25, 25, 30)
SalaryConfig.OutfitSlots = {
	{
		id = "glasses",
		emoji = "👓",
		name = "안경",
		options = {
			{ id = "glasses_round", emoji = "👓", name = "뿔테 안경", price = 2000, description = "일 잘하는 사람처럼 보여요", part = "Head", pieces = {
				{ size = Vector3.new(1.1, 0.07, 0.07), offset = CFrame.new(0, 0.2, -0.62), color = BLACK },
				{ size = Vector3.new(0.4, 0.3, 0.04), offset = CFrame.new(-0.26, 0.15, -0.63), color = Color3.fromRGB(200, 230, 255), transparency = 0.6 },
				{ size = Vector3.new(0.4, 0.3, 0.04), offset = CFrame.new(0.26, 0.15, -0.63), color = Color3.fromRGB(200, 230, 255), transparency = 0.6 },
			} },
			{ id = "glasses_sun", emoji = "🕶️", name = "선글라스", price = 6000, description = "눈을 감고 자도 아무도 몰라요 (기분만)", part = "Head", pieces = {
				{ size = Vector3.new(1.15, 0.08, 0.08), offset = CFrame.new(0, 0.22, -0.62), color = BLACK },
				{ size = Vector3.new(0.44, 0.3, 0.05), offset = CFrame.new(-0.26, 0.14, -0.64), color = BLACK, material = Enum.Material.Glass },
				{ size = Vector3.new(0.44, 0.3, 0.05), offset = CFrame.new(0.26, 0.14, -0.64), color = BLACK, material = Enum.Material.Glass },
			} },
			{ id = "glasses_heart", emoji = "💗", name = "하트 선글라스", price = 15000, description = "사무실의 인싸", part = "Head", pieces = {
				{ size = Vector3.new(1.15, 0.08, 0.08), offset = CFrame.new(0, 0.22, -0.62), color = Color3.fromRGB(255, 90, 150) },
				{ size = Vector3.new(0.42, 0.34, 0.05), offset = CFrame.new(-0.26, 0.14, -0.64) * CFrame.Angles(0, 0, math.rad(45)), color = Color3.fromRGB(255, 80, 140), material = Enum.Material.Neon, transparency = 0.2 },
				{ size = Vector3.new(0.42, 0.34, 0.05), offset = CFrame.new(0.26, 0.14, -0.64) * CFrame.Angles(0, 0, math.rad(-45)), color = Color3.fromRGB(255, 80, 140), material = Enum.Material.Neon, transparency = 0.2 },
			} },
		},
	},
	{
		id = "tie",
		emoji = "👔",
		name = "넥타이",
		options = {
			{ id = "tie_red", emoji = "🔴", name = "빨간 넥타이", price = 3000, description = "열정! 도전! (농땡이)", part = "UpperTorso", pieces = {
				{ size = Vector3.new(0.26, 0.2, 0.1), offset = CFrame.new(0, 0.62, -0.53), color = Color3.fromRGB(200, 40, 40) },
				{ size = Vector3.new(0.24, 1.05, 0.05), offset = CFrame.new(0, 0, -0.52), color = Color3.fromRGB(210, 45, 45) },
			} },
			{ id = "tie_blue", emoji = "🔵", name = "파란 넥타이", price = 3000, description = "신뢰감 +10 (체감)", part = "UpperTorso", pieces = {
				{ size = Vector3.new(0.26, 0.2, 0.1), offset = CFrame.new(0, 0.62, -0.53), color = Color3.fromRGB(40, 80, 190) },
				{ size = Vector3.new(0.24, 1.05, 0.05), offset = CFrame.new(0, 0, -0.52), color = Color3.fromRGB(50, 90, 200) },
			} },
			{ id = "tie_gold", emoji = "✨", name = "황금 넥타이", price = 40000, description = "빛나는 존재감. 부장님 눈에도 잘 띄어요", part = "UpperTorso", pieces = {
				{ size = Vector3.new(0.26, 0.2, 0.1), offset = CFrame.new(0, 0.62, -0.53), color = GOLD, material = Enum.Material.Neon },
				{ size = Vector3.new(0.24, 1.05, 0.05), offset = CFrame.new(0, 0, -0.52), color = GOLD, material = Enum.Material.Neon },
			} },
		},
	},
	{
		id = "hat",
		emoji = "🧢",
		name = "모자",
		options = {
			{ id = "hat_cap", emoji = "🧢", name = "야구 모자", price = 5000, description = "캐주얼 프라이데이", part = "Head", pieces = {
				{ size = Vector3.new(1.3, 0.55, 1.3), offset = CFrame.new(0, 0.62, 0.02), color = Color3.fromRGB(40, 90, 170), shape = Enum.PartType.Ball },
				{ size = Vector3.new(1.0, 0.08, 0.65), offset = CFrame.new(0, 0.48, -0.72), color = Color3.fromRGB(40, 90, 170) },
			} },
			{ id = "hat_fedora", emoji = "🎩", name = "중절모", price = 18000, description = "퇴근길 재즈바 느낌", part = "Head", pieces = {
				{ size = Vector3.new(0.7, 1.15, 1.15), offset = CFrame.new(0, 0.85, 0) * CFrame.Angles(0, 0, math.rad(90)), color = BLACK, shape = Enum.PartType.Cylinder },
				{ size = Vector3.new(0.08, 1.9, 1.9), offset = CFrame.new(0, 0.52, 0) * CFrame.Angles(0, 0, math.rad(90)), color = BLACK, shape = Enum.PartType.Cylinder },
				{ size = Vector3.new(0.15, 1.17, 1.17), offset = CFrame.new(0, 0.62, 0) * CFrame.Angles(0, 0, math.rad(90)), color = Color3.fromRGB(150, 30, 30), shape = Enum.PartType.Cylinder },
			} },
			{ id = "hat_crown", emoji = "👑", name = "왕관", price = 150000, description = "사장님도 이건 없어요", part = "Head", pieces = {
				{ size = Vector3.new(0.4, 1.25, 1.25), offset = CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)), color = GOLD, shape = Enum.PartType.Cylinder, material = Enum.Material.Neon },
				{ size = Vector3.new(0.18, 0.35, 0.18), offset = CFrame.new(0, 1.15, -0.55), color = GOLD, material = Enum.Material.Neon },
				{ size = Vector3.new(0.18, 0.35, 0.18), offset = CFrame.new(-0.52, 1.15, -0.18), color = GOLD, material = Enum.Material.Neon },
				{ size = Vector3.new(0.18, 0.35, 0.18), offset = CFrame.new(0.52, 1.15, -0.18), color = GOLD, material = Enum.Material.Neon },
				{ size = Vector3.new(0.14, 0.14, 0.14), offset = CFrame.new(0, 0.82, -0.63), color = Color3.fromRGB(230, 40, 60), shape = Enum.PartType.Ball, material = Enum.Material.Neon },
			} },
		},
	},
	{
		id = "ears",
		emoji = "🎧",
		name = "귀",
		options = {
			{ id = "ears_phones", emoji = "🎧", name = "헤드폰", price = 8000, description = "회의 중 아니에요, 집중 중이에요", part = "Head", pieces = {
				{ size = Vector3.new(1.35, 0.12, 0.25), offset = CFrame.new(0, 0.7, 0), color = BLACK },
				{ size = Vector3.new(0.22, 0.5, 0.45), offset = CFrame.new(-0.66, 0.1, 0), color = BLACK },
				{ size = Vector3.new(0.22, 0.5, 0.45), offset = CFrame.new(0.66, 0.1, 0), color = BLACK },
			} },
			{ id = "ears_white", emoji = "🖤", name = "노캔 헤드폰", price = 25000, description = "부장님 잔소리 차단 (안 됨)", part = "Head", pieces = {
				{ size = Vector3.new(1.35, 0.12, 0.28), offset = CFrame.new(0, 0.7, 0), color = Color3.fromRGB(240, 240, 240) },
				{ size = Vector3.new(0.24, 0.55, 0.5), offset = CFrame.new(-0.67, 0.1, 0), color = Color3.fromRGB(245, 245, 245) },
				{ size = Vector3.new(0.24, 0.55, 0.5), offset = CFrame.new(0.67, 0.1, 0), color = Color3.fromRGB(245, 245, 245) },
				{ size = Vector3.new(0.05, 0.25, 0.25), offset = CFrame.new(-0.79, 0.1, 0), color = Color3.fromRGB(120, 200, 255), material = Enum.Material.Neon },
				{ size = Vector3.new(0.05, 0.25, 0.25), offset = CFrame.new(0.79, 0.1, 0), color = Color3.fromRGB(120, 200, 255), material = Enum.Material.Neon },
			} },
		},
	},
	{
		id = "watch",
		emoji = "⌚",
		name = "시계",
		options = {
			{ id = "watch_digital", emoji = "⌚", name = "전자시계", price = 4000, description = "퇴근 카운트다운 전용", part = "LeftHand", pieces = {
				{ size = Vector3.new(0.38, 0.14, 0.38), offset = CFrame.new(0, 0.18, 0), color = BLACK },
				{ size = Vector3.new(0.2, 0.15, 0.2), offset = CFrame.new(0.1, 0.18, 0), color = Color3.fromRGB(120, 255, 140), material = Enum.Material.Neon },
			} },
			{ id = "watch_gold", emoji = "🕰️", name = "명품 금시계", price = 50000, description = "월급 몇 달 치… 반짝반짝", part = "LeftHand", pieces = {
				{ size = Vector3.new(0.4, 0.15, 0.4), offset = CFrame.new(0, 0.18, 0), color = GOLD, material = Enum.Material.Neon },
				{ size = Vector3.new(0.22, 0.16, 0.22), offset = CFrame.new(0.1, 0.18, 0), color = Color3.fromRGB(250, 250, 255), material = Enum.Material.Glass },
			} },
		},
	},
	{
		id = "bag",
		emoji = "💼",
		name = "가방",
		options = {
			{ id = "bag_brief", emoji = "💼", name = "서류 가방", price = 10000, description = "안에는 간식만 있어요", part = "RightHand", pieces = {
				{ size = Vector3.new(0.35, 1.1, 1.5), offset = CFrame.new(0, -0.75, 0), color = Color3.fromRGB(100, 60, 35), material = Enum.Material.Leather },
				{ size = Vector3.new(0.12, 0.25, 0.5), offset = CFrame.new(0, -0.08, 0), color = Color3.fromRGB(70, 40, 25) },
			} },
			{ id = "bag_luxury", emoji = "👜", name = "명품 가방", price = 80000, description = "로고가 너무 커요", part = "RightHand", pieces = {
				{ size = Vector3.new(0.38, 1.0, 1.4), offset = CFrame.new(0, -0.72, 0), color = Color3.fromRGB(150, 110, 70), material = Enum.Material.Leather },
				{ size = Vector3.new(0.4, 0.3, 0.3), offset = CFrame.new(0, -0.6, 0), color = GOLD, material = Enum.Material.Neon },
				{ size = Vector3.new(0.12, 0.25, 0.5), offset = CFrame.new(0, -0.1, 0), color = GOLD },
			} },
		},
	},
	{
		id = "aura",
		emoji = "✨",
		name = "오라",
		options = {
			{ id = "aura_sparkle", emoji = "✨", name = "반짝이", price = 30000, description = "어딜 가든 반짝반짝", part = "UpperTorso", pieces = {}, particles = Color3.fromRGB(255, 240, 160) },
			{ id = "aura_money", emoji = "💸", name = "부자 오라", price = 100000, description = "초록빛 돈 냄새가 나요", part = "UpperTorso", pieces = {}, particles = Color3.fromRGB(110, 230, 120), light = Color3.fromRGB(110, 230, 120) },
			{ id = "aura_rainbow", emoji = "🌈", name = "무지개 오라", price = 150000, description = "월급루팡계의 전설", part = "UpperTorso", pieces = {}, particles = Color3.fromRGB(255, 120, 200), rainbow = true, light = Color3.fromRGB(200, 150, 255) },
		},
	},
}
function SalaryConfig.getOutfit(itemId: string): (any, any)
	for _, slot in SalaryConfig.OutfitSlots do
		for _, option in slot.options do
			if option.id == itemId then
				return option, slot
			end
		end
	end
	return nil, nil
end

-- 🌱 옥상 텃밭 (내 화분 GARDEN_SLOTS칸, 저장돼요)
--   🏪 사내 매점 [🌱 씨앗] 탭에서 씨앗 사기 → 🎒 소지품에 보관 → 옥상 화분에 심기 (화분에선 돈 안 내요)
--   → 하루에 한 번 💧 물 주기 → (물 준 날 수가 다 차면) 🧺 수확 → 💰 팔기 또는 🎁 부장님 선물
--   물을 하루 안 주면 🥀 시들고, 이틀 연속 안 주면 💀 말라 죽어요 (뽑고 다시 심어야 해요)
--   (하루 = 내가 출근해서 퇴근한 하루. 퇴근할 때 자라요)
--   씨앗 특징 (없으면 평범한 식물)
--     minutes = 쾌속 식물: 물 주고 게임 시간 N분 뒤 바로 수확 (퇴근을 안 기다려요)
--     noWater = 물을 안 줘도 퇴근할 때마다 자라고 안 시들어요 / thirsty = 하루만 물을 걸러도 💀
--     regrow = 수확해도 안 뽑혀요! N일 뒤 또 열려요 (나무)
--     sunsetBonus = 🌅 노을 시간에 팔면 N배 / luck = { chance, prize } 확률로 대박 / giftDelta = 부장님 선물 효과
--     rank = 이 직급부터 살 수 있어요 / kind = 화분 위 생김새 (leafy·root·fruit·stalk·flower·cactus·tree·vine·mushroom·clover)
--   ⚖️ 밸런스 (화분 한 칸 하루 순이익 = (판매가 - 씨앗값) / 일수, 예전 4종 150~275원 기준)
--     🥬150 🥕170 🌶️175 🍅217 🌹217 🌵150(물 X) 🌻183(노을 373) 🍀≈200(기댓값) 🌽250 🍓275 🍉350(물 필수) 🎃367
--     🍄 버섯은 한 번에 +50원이지만 물 주고 약 1분 반이면 다시 심을 수 있어요 (계속 지켜보면 하루 ~200원)
--     🍇 포도나무는 첫 수확은 손해(-400)지만 그 뒤로 2일마다 800원 = 하루 400원 (오래 키울수록 이득)
--   🏷️ 오늘의 특가: 내 근무일마다 씨앗 하나가 SEED_DEAL_RATE 가격 (SalaryConfig.seedDealId)
SalaryConfig.GARDEN_SLOTS = 6 -- (텃밭을 넓혀서 4 → 6칸)
SalaryConfig.GARDEN_GIFT_DELTA = -0.1 -- 🎁 직접 기른 채소 선물: 오늘의 의심도 속도 (씨앗마다 giftDelta로 바꿀 수 있어요)
SalaryConfig.SEED_MAX = 99 -- 🎒 씨앗 한 종류당 최대 보관 개수
SalaryConfig.SEED_DEAL_RATE = 0.7 -- 🏷️ 오늘의 특가 = 30% 할인
SalaryConfig.GardenSeeds = {
	-- ⚠️ lettuce·pepper·tomato·strawberry ID는 예전 저장 화분이 써요. 바꾸지 마세요!
	{ id = "mushroom", emoji = "🍄", name = "느타리버섯", price = 80, days = 1, minutes = 120, sell = 130, kind = "mushroom", color = Color3.fromRGB(190, 160, 130), description = "⚡ 쾌속! 물 주고 2시간이면 쏙" },
	{ id = "lettuce", emoji = "🥬", name = "상추", price = 100, days = 1, sell = 250, kind = "leafy", color = Color3.fromRGB(110, 200, 90), description = "하루면 쑥쑥! 초보 농부용" },
	{ id = "carrot", emoji = "🥕", name = "당근", price = 180, days = 2, sell = 520, kind = "root", color = Color3.fromRGB(255, 140, 40), description = "땅속에서 몰래 자라요 (월급루팡처럼)" },
	{ id = "pepper", emoji = "🌶️", name = "고추", price = 200, days = 2, sell = 550, kind = "fruit", color = Color3.fromRGB(220, 40, 40), description = "맵게 잘 자라요" },
	{ id = "clover", emoji = "🍀", name = "네잎클로버", price = 300, days = 2, sell = 350, kind = "clover", color = Color3.fromRGB(60, 200, 90), luck = { chance = 0.1, prize = 4000 }, description = "🎰 10% 확률로 행운 대박 4,000원!" },
	{ id = "cactus", emoji = "🌵", name = "선인장", price = 250, days = 3, sell = 700, kind = "cactus", color = Color3.fromRGB(70, 160, 80), noWater = true, description = "🏜️ 물 안 줘도 알아서 자라요 (바쁜 직장인용)" },
	{ id = "tomato", emoji = "🍅", name = "방울토마토", price = 350, days = 3, sell = 1000, kind = "fruit", color = Color3.fromRGB(240, 70, 50), description = "주렁주렁 열려요" },
	{ id = "corn", emoji = "🌽", name = "옥수수", price = 400, days = 3, sell = 1150, kind = "stalk", color = Color3.fromRGB(250, 210, 60), rank = 2, description = "키가 쑥쑥! 옥상 위로 삐죽" },
	{ id = "rose", emoji = "🌹", name = "장미", price = 450, days = 3, sell = 1100, kind = "flower", color = Color3.fromRGB(220, 30, 60), rank = 2, giftDelta = -0.2, description = "💘 부장님 선물 효과 2배 (의심도 속도 -0.2)" },
	{ id = "sunflower", emoji = "🌻", name = "해바라기", price = 400, days = 3, sell = 950, kind = "flower", color = Color3.fromRGB(255, 200, 30), rank = 2, sunsetBonus = 1.6, description = "🌅 노을 시간에 팔면 1.6배!" },
	{ id = "strawberry", emoji = "🍓", name = "딸기", price = 600, days = 4, sell = 1700, kind = "fruit", color = Color3.fromRGB(255, 60, 90), description = "정성이 많이 들지만 달콤하게 비싸요" },
	{ id = "watermelon", emoji = "🍉", name = "수박", price = 700, days = 4, sell = 2100, kind = "vine", color = Color3.fromRGB(60, 150, 60), rank = 3, thirsty = true, description = "💦 물귀신! 하루만 걸러도 말라 죽어요" },
	{ id = "grape", emoji = "🍇", name = "포도나무", price = 1200, days = 5, sell = 800, kind = "tree", color = Color3.fromRGB(130, 60, 170), rank = 3, regrow = 2, description = "🔁 한 번 심으면 2일마다 또 열려요" },
	{ id = "pumpkin", emoji = "🎃", name = "호박", price = 1000, days = 6, sell = 3200, kind = "vine", color = Color3.fromRGB(255, 130, 20), rank = 4, description = "느리지만 엄청 커요! 끈기의 상징" },
}
function SalaryConfig.getSeed(seedId: string): any
	for _, seed in SalaryConfig.GardenSeeds do
		if seed.id == seedId then
			return seed
		end
	end
	return nil
end
-- 🏷️ 오늘의 특가 씨앗 ID (내 근무일 수로 돌아가요)
function SalaryConfig.seedDealId(day: number): string
	local seeds = SalaryConfig.GardenSeeds
	return seeds[(math.floor(day) * 5) % #seeds + 1].id
end
-- 오늘 씨앗 가격 (특가면 할인)
function SalaryConfig.seedPrice(seed: any, day: number): number
	if SalaryConfig.seedDealId(day) == seed.id then
		return math.floor(seed.price * SalaryConfig.SEED_DEAL_RATE / 10) * 10
	end
	return seed.price
end
-- "2일" / "물 주고 2시간"
function SalaryConfig.seedGrowText(seed: any): string
	if seed.minutes then
		return `물 주고 {SalaryConfig.gameDurationText(seed.minutes)}`
	end
	return `{seed.days}일`
end
-- 씨앗 특징 한 줄 (없으면 "")
function SalaryConfig.seedPerkText(seed: any): string
	local parts = {}
	if seed.minutes then
		table.insert(parts, "⚡쾌속")
	end
	if seed.noWater then
		table.insert(parts, "🏜️물 X")
	end
	if seed.thirsty then
		table.insert(parts, "💦물 필수")
	end
	if seed.regrow then
		table.insert(parts, `🔁{seed.regrow}일마다`)
	end
	if seed.sunsetBonus then
		table.insert(parts, `🌅x{seed.sunsetBonus}`)
	end
	if seed.luck then
		table.insert(parts, "🎰대박")
	end
	if seed.giftDelta then
		table.insert(parts, "💘선물")
	end
	return table.concat(parts, " ")
end
-- 화분 상태: "empty" / "dead" / "ripe" / "wilted" / "growing" (now = 서버 os.time / 클라 GetServerTimeNow)
function SalaryConfig.gardenState(slot: any, now: number): string
	local seed = SalaryConfig.getSeed(slot.seed)
	if not seed then
		return "empty"
	end
	local missed = slot.missed or 0
	if not seed.noWater and missed >= (if seed.thirsty then 1 else 2) then
		return "dead"
	elseif (slot.growth or 0) >= seed.days or (seed.minutes and (slot.readyAt or 0) > 0 and now >= slot.readyAt) then
		return "ripe"
	elseif not seed.noWater and missed >= 1 then
		return "wilted"
	end
	return "growing"
end

-- 🌷 내 공원 화단 (눈치물산 공원, 대리부터 · 화단 PARK_BEDS곳, 사람마다 저장돼요)
--   🏪 사내 매점 [🌱 씨앗] 탭 → [🌷 꽃씨·거름] 에서 꽃씨와 🧪 거름 사기 → 🎒 보관
--   공원 화단 [E] → 꽃씨 심기 → 매일 💧 물 주기 (하루 한 번) → 퇴근하면 한 단계 자라요
--   🧪 거름: 꽃마다 마지막 feeds단계(꽃봉오리 때)엔 거름도 한 번 줘야 자라요 (단계마다 1개, 준 건 그 단계 동안 유지)
--   물을 안 준 날은 그냥 멈춰요 (안 죽어요!) · 활짝 피면 영원히 안 시들어요 · 🧹 뽑으면 다시 심을 수 있어요
--   💰 공원 정원 수당 (눈치물산에서 퇴근할 때마다): 핀 화단 1곳마다 PARK_BED_BONUS원
--      + 🌈 정원 완성 (화단 전부 활짝 + 꽃 PARK_FULL_KINDS종 이상) PARK_FULL_BONUS원
--   shape = 화단 위 생김새 (cup·daisy·rose·sunflower·tree·hydrangea·hibiscus·pompom·mist·spike)
--   colors = 꽃 색 (여러 개면 섞어서 피어요)
SalaryConfig.PARK_BEDS = 6
SalaryConfig.PARK_BED_BONUS = 15 -- (보너스일 뿐이라 작게)
SalaryConfig.PARK_FULL_BONUS = 60
SalaryConfig.PARK_FULL_KINDS = 3
SalaryConfig.FERTILIZER_PRICE = 100 -- 🧪 거름 1개
SalaryConfig.FERTILIZER_MAX = 99
SalaryConfig.FLOWER_SEED_MAX = 99 -- 🎒 꽃씨 한 종류당 최대
SalaryConfig.ParkFlowers = {
	{ id = "daisy", emoji = "🌼", name = "데이지", price = 150, days = 2, feeds = 0, shape = "daisy", colors = { Color3.fromRGB(250, 250, 245) }, description = "거름 없이도 피는 초보용 꽃" },
	{ id = "tulip", emoji = "🌷", name = "튤립", price = 200, days = 2, feeds = 1, shape = "cup", colors = { Color3.fromRGB(240, 60, 90), Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 140, 190) }, description = "알록달록 세 가지 색으로 피어요" },
	{ id = "babybreath", emoji = "💮", name = "안개꽃", price = 250, days = 2, feeds = 1, shape = "mist", colors = { Color3.fromRGB(255, 255, 255) }, description = "몽글몽글 하얀 구름 같아요" },
	{ id = "lavender", emoji = "💜", name = "라벤더", price = 300, days = 3, feeds = 1, shape = "spike", colors = { Color3.fromRGB(150, 110, 210) }, description = "보랏빛 힐링 (향기는 상상으로)" },
	{ id = "sunflower", emoji = "🌻", name = "해바라기", price = 350, days = 3, feeds = 1, shape = "sunflower", colors = { Color3.fromRGB(255, 200, 30) }, description = "키가 커서 멀리서도 잘 보여요" },
	{ id = "mum", emoji = "🏵️", name = "국화", price = 400, days = 3, feeds = 1, shape = "pompom", colors = { Color3.fromRGB(255, 180, 40), Color3.fromRGB(255, 230, 120) }, description = "동글동글 가을 감성" },
	{ id = "rose", emoji = "🌹", name = "장미", price = 450, days = 3, feeds = 2, shape = "rose", colors = { Color3.fromRGB(210, 25, 50) }, description = "새빨간 장미 정원 (가시 조심)" },
	{ id = "hydrangea", emoji = "💐", name = "수국", price = 550, days = 4, feeds = 2, shape = "hydrangea", colors = { Color3.fromRGB(120, 160, 240), Color3.fromRGB(180, 130, 230), Color3.fromRGB(255, 160, 200) }, description = "파랑·보라·분홍 꽃송이 덤불" },
	{ id = "hibiscus", emoji = "🌺", name = "히비스커스", price = 650, days = 4, feeds = 2, shape = "hibiscus", colors = { Color3.fromRGB(255, 70, 90), Color3.fromRGB(255, 140, 60) }, description = "휴가 가고 싶어지는 열대 꽃" },
	{ id = "cherry", emoji = "🌸", name = "벚꽃 나무", price = 1000, days = 4, feeds = 3, shape = "tree", colors = { Color3.fromRGB(255, 190, 215), Color3.fromRGB(255, 225, 235) }, description = "작은 벚나무가 화단 가득 (공원의 주인공)" },
}
function SalaryConfig.getFlower(flowerId: string): any
	for _, flower in SalaryConfig.ParkFlowers do
		if flower.id == flowerId then
			return flower
		end
	end
	return nil
end
-- 화단 상태: "empty" / "growing" / "bloomed"
function SalaryConfig.parkBedState(bed: any): string
	local flower = typeof(bed) == "table" and SalaryConfig.getFlower(bed.flower or "")
	if not flower then
		return "empty"
	end
	return if (bed.growth or 0) >= flower.days then "bloomed" else "growing"
end
-- 지금 단계(growth)에 🧪 거름이 필요한가 (마지막 feeds단계)
function SalaryConfig.parkNeedsFeed(flower: any, growth: number): boolean
	return growth < flower.days and growth >= flower.days - (flower.feeds or 0)
end
-- "💧2일 · 🧪1번"
function SalaryConfig.flowerCareText(flower: any): string
	return `💧{flower.days}일` .. (if (flower.feeds or 0) > 0 then ` · 🧪{flower.feeds}번` else " · 🧪없이")
end
-- 💰 공원 정원 수당 → (총액, 핀 화단 수, 꽃 종류 수, 정원 완성인가)
function SalaryConfig.parkBonus(beds: any): (number, number, number, boolean)
	local bloomed, kinds = 0, {}
	local kindCount = 0
	for i = 1, SalaryConfig.PARK_BEDS do
		local bed = typeof(beds) == "table" and beds[i]
		if bed and SalaryConfig.parkBedState(bed) == "bloomed" then
			bloomed += 1
			if not kinds[bed.flower] then
				kinds[bed.flower] = true
				kindCount += 1
			end
		end
	end
	local full = bloomed >= SalaryConfig.PARK_BEDS and kindCount >= SalaryConfig.PARK_FULL_KINDS
	return bloomed * SalaryConfig.PARK_BED_BONUS + (if full then SalaryConfig.PARK_FULL_BONUS else 0), bloomed, kindCount, full
end

-- ✈️ 옥상 종이비행기
--   발사대 [E] → 🌬️ 바람 확인 → 각도·힘·방향을 [-] [+]로 맞추기 → [던지기] 슈웅~
--   미리보기 점선은 바람 없을 때의 "처음 조금"만 보여 줘요. 바람만큼 직접 보정하는 게 실력!
--   멀리 날릴수록 상금, 건너편 빌딩 옥상의 🎯 과녁에 꽂히면 대박! (하루 PLANE_DAILY_PRIZES번까지 상금)
--   😱 맞바람이 세면 가끔 되돌아와요… 근처에 👮 옥상 경비원이 있으면 머리에 꽂혀요!
SalaryConfig.PLANE_COOLDOWN = 5 -- 한 번 날리고 다음까지 (초)
SalaryConfig.PLANE_DAILY_PRIZES = 10
SalaryConfig.PLANE_TARGET_DISTANCE = 130 -- 🎯 과녁까지 거리 (스터드 = m)
SalaryConfig.PLANE_TARGET_RADIUS = 5
SalaryConfig.PLANE_TARGET_PRIZE = 1800
SalaryConfig.PLANE_BOOMERANG_CHANCE = 0.3 -- 맞바람이 셀 때(-0.5 이하) 되돌아올 확률
SalaryConfig.PLANE_BOSS_HIT_SUSPICION = 30 -- ✈️ 경비원 머리에 꽂히면 의심도 +
-- 거리 상금 (가장 먼 것부터)
SalaryConfig.PlanePrizes = {
	{ distance = 170, prize = 230, label = "🚀 엄청 멀리!" },
	{ distance = 120, prize = 120, label = "✈️ 멀리 날았어요" },
	{ distance = 80, prize = 45, label = "🛫 괜찮은 비행" },
}
-- 조절 범위 (서버가 이 범위·칸에 맞춰 다시 맞춰요)
SalaryConfig.PLANE_ANGLE = { min = 5, max = 60, step = 5, default = 25 } -- 각도 (°)
SalaryConfig.PLANE_POWER = { min = 20, max = 100, step = 5, default = 60 } -- 힘 (%)
SalaryConfig.PLANE_AIM = { min = -12, max = 12, step = 1, default = 0 } -- 방향 (°, -왼쪽 / +오른쪽)
SalaryConfig.PLANE_PREVIEW = 0.35 -- 미리보기 점선: 비행 경로의 앞쪽 이만큼만
SalaryConfig.PLANE_GUST = 0.03 -- 돌풍: 날아간 거리가 ±3% 흔들려요
SalaryConfig.PLANE_GUST_SIDE = 1.5 -- 돌풍: 옆으로 ±1.5m

-- 범위 안으로 자르고 칸(step)에 맞추기
function SalaryConfig.planeSnap(value: any, spec: { min: number, max: number, step: number, default: number }): number
	if typeof(value) ~= "number" or value ~= value then
		return spec.default
	end
	local snapped = spec.min + math.floor((value - spec.min) / spec.step + 0.5) * spec.step
	return math.clamp(snapped, spec.min, spec.max)
end
-- 날아간 거리와 옆으로 밀린 거리 (wind: 앞바람(+)/맞바람(-) forward, 옆바람 side, 각각 -1 ~ 1)
--   종이비행기는 25° 근처로 날릴 때 가장 멀리 가요
function SalaryConfig.planeFlight(angle: number, power: number, windForward: number, windSide: number): (number, number)
	local angleFactor = math.clamp(1 - ((angle - 25) / 38) ^ 2, 0.15, 1)
	local distance = 185 * power * angleFactor * (1 + 0.28 * windForward)
	local drift = windSide * distance * 0.16
	return distance, drift
end
-- 떨어지는 곳: (앞으로 간 거리, 옆으로 간 거리(+오른쪽), 날아간 거리). power는 0~1, aim은 방향(°)
function SalaryConfig.planeLanding(angle: number, power: number, aim: number, windForward: number, windSide: number): (number, number, number)
	local distance, drift = SalaryConfig.planeFlight(angle, power, windForward, windSide)
	local yaw = math.rad(aim)
	return distance * math.cos(yaw), distance * math.sin(yaw) + drift, distance
end
-- 비행 곡선의 가운데 점 (서버 비행 경로와 화면 미리보기가 같은 식)
function SalaryConfig.planeControl(start: Vector3, finish: Vector3, distance: number, angle: number): Vector3
	local lift = distance * math.tan(math.rad(angle)) * 0.3
	return start:Lerp(finish, 0.45) + Vector3.new(0, lift + 4, 0)
end

-- 🏢 옥상: 부장님은 사무실에만 있어요. 옥상은 👮 옥상 경비원이 근무 시간 내내 순찰해요
SalaryConfig.HIDE_MAX = 25 -- 📦 상자 속에 숨어 있을 수 있는 시간 (초)
SalaryConfig.HIDE_COOLDOWN = 15 -- 튀어나온 뒤 다시 들어가기까지 (초)
-- 👀 사무실 밖(공원·거리)에서 부장님 눈에 띄면: 멈춰 서서 나만 계속 노려봐요 (사무 공간이 아니라 더 수상해요)
--   가려지는 곳으로 숨어서 BOSS_STARE_GRACE초 동안 안 보이면 다시 하던 일로
SalaryConfig.BOSS_STARE_GRACE = 4
SalaryConfig.OUTSIDE_STARE_MULTIPLIER = 1.3 -- 노려보는 동안 의심도 속도 배율 (옥상·사무실 밖)
-- 👮 경비원 (🌳 공원·🏙️ 거리 / 🚪 옥상): 근무 시간 내내 상주하며 순찰, 시야에 걸리면 멈춰 서서 노려봐요
--   의심도가 100이 되면 경비원이 📻 무전으로 부장님께 보고 → 적발 (부장님은 사무실을 떠나지 않아요)
SalaryConfig.GUARD_RANGE = 42 -- 보이는 거리 (공원)
SalaryConfig.ROOF_GUARD_RANGE = 36 -- 보이는 거리 (옥상)
SalaryConfig.GUARD_FOV = 55 -- 시야 반각 (°)
SalaryConfig.GUARD_WALK_SPEED = 9
SalaryConfig.GUARD_STARE_GRACE = 4 -- 숨어서 이만큼(초) 안 보이면 다시 순찰
SalaryConfig.GUARD_DETECT_MULTIPLIER = 0.7 -- 경비원한테 보일 때 의심도 속도 배율 (예전 1.0 → 30% 낮춤)
SalaryConfig.GUARD_STARE_MULTIPLIER = 0.91
SalaryConfig.GUARD_TALK_SECONDS = 25 -- 🎁 경비원에게 [E]로 말을 걸고(선물 창) 이야기하는 동안 최대 이만큼(초)은 의심도 안 올라요
SalaryConfig.GUARD_TALK_GRACE = 3 -- 👮 경비원이 처음 발견하고 말하는 동안(초)은 의심도가 안 올라요 (도망갈 틈)
SalaryConfig.GUARD_CATCH_CALM = 30 -- 🚨 경비원 보고로 적발된 뒤 이만큼(초)은 경비원 의심도가 안 올라요
SalaryConfig.GUARD_CATCH_RAMP = 30 -- 그 뒤 이만큼(초) 동안 30% → 100%로 천천히 다시 올라가요 -- 경비원이 노려보는 중일 때 (예전 1.3 → 30% 낮춤)
SalaryConfig.GUARD_REST_CHANCE = 0.1 -- 💤 옥상 경비원: 순찰 한 바퀴마다 경비실에서 쉴 확률
SalaryConfig.GUARD_REST = { 8, 12 } -- 💤 쉬는 시간 (초): 이때가 옥상 콘텐츠를 즐길 찬스!
-- 🎁 경비원 뇌물: 경비원에게 [E] 선물 드리기 → 그 경비원이 일정 시간 동안 나를 못 본 척 (의심도 안 올라요)
--   🏪 사내 매점에서 미리 사서 🎒 소지품에 보관 → 경비원 앞에서 [E]로 골라 드려요
--   좋은 선물일수록 오래 눈감아 줘요. 경비원마다 하루 GUARD_BRIBE_DAILY번만 받아요 (공원 경비원 · 옥상 경비원 따로)
--   minutes = 게임 시계 기준 (게임 1시간 ≈ 실제 47초). seconds는 아래에서 자동 계산
SalaryConfig.GUARD_BRIBE_DAILY = 1
SalaryConfig.GuardBribes = {
	{ id = "drink", emoji = "🥤", name = "시원한 음료수", price = 1000, minutes = 120, line = "어이쿠, 시원하네~ 잠깐 딴 데 볼게요." },
	{ id = "donut", emoji = "🍩", name = "도넛 한 상자", price = 2500, minutes = 210, line = "이거 그 유명한 집 도넛? 흠흠, 난 아무것도 못 봤어요." },
	{ id = "chicken", emoji = "🍗", name = "치킨 쿠폰", price = 5000, minutes = 330, line = "오늘 저녁은 치킨이다! 한동안 안 보일 거예요~" },
	{ id = "ticket", emoji = "🎫", name = "주말 영화 예매권", price = 9000, minutes = 480, line = "영화를 좋아하는 걸 어떻게 알고! 오늘은 푹 쉬다 가요~" },
}
-- ⏰ 게임 시간(분) ↔ 실제 초
function SalaryConfig.gameMinutesToSeconds(minutes: number): number
	return minutes * SalaryConfig.DAY_SECONDS / (SalaryConfig.END_MINUTE - SalaryConfig.START_MINUTE)
end
function SalaryConfig.secondsToGameMinutes(seconds: number): number
	return seconds * (SalaryConfig.END_MINUTE - SalaryConfig.START_MINUTE) / SalaryConfig.DAY_SECONDS
end
-- "1시간 30분" / "45분" 처럼
function SalaryConfig.gameDurationText(minutes: number): string
	local m = math.max(0, math.ceil(minutes))
	local h = m // 60
	m = m % 60
	if h > 0 and m > 0 then
		return `{h}시간 {m}분`
	elseif h > 0 then
		return `{h}시간`
	end
	return `{m}분`
end
for _, bribe in SalaryConfig.GuardBribes do
	bribe.seconds = SalaryConfig.gameMinutesToSeconds(bribe.minutes)
end
function SalaryConfig.getGuardBribe(bribeId: string): any
	for _, bribe in SalaryConfig.GuardBribes do
		if bribe.id == bribeId then
			return bribe
		end
	end
	return nil
end
SalaryConfig.PIGEON_GUARD_RANGE = 16 -- 🐦 경비원이 이만큼 가까이 오면 비둘기들이 푸드덕 (근접 알람)
SalaryConfig.TELESCOPE_SECONDS = 15 -- 🔭 망원경으로 부장님 위치 보기
SalaryConfig.TEST_ELEVATOR = false -- 🧪 true면 스튜디오에서 엘리베이터에 부장님이 항상 타요

return SalaryConfig
