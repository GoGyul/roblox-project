-- 서버 ↔ 클라이언트 통신 채널

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function event(name: string): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

local function func(name: string): RemoteFunction
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = folder
	return remote
end

local Remotes = {
	SetAction = event("SetAction"), -- 클라 → 서버: 자리에서 할 행동 고르기 (일하기/멍때리기/...)
	ClockIn = event("ClockIn"), -- 클라 → 서버: 🏢 출근하기 버튼
	MissionPuzzle = func("MissionPuzzle"),
	Decor = func("Decor"),
	VideoQuestion = event("VideoQuestion"), -- 서버 → 클라: 🎧 화상회의 질문 (ID, 질문, 보기 3개, 제한 초) / (0 = 질문 닫기)
	VideoAnswer = event("VideoAnswer"),
	ChatReact = event("ChatReact"), -- 서버 → 클라: 🗣️ 맞장구 고르기 (ID, 동료 이름, 보기 3개, 제한 초) / (0 = 닫기)
	ChatReactAnswer = event("ChatReactAnswer"), -- 클라 → 서버: 🗣️ 고른 맞장구 (ID, 보기 번호)
	ChatLine = event("ChatLine"), -- 서버 → 클라: 💬 수다 대사 한 줄 ("them" 동료 / "me" 나 / "sys" 안내, 동료 이름, 대사) → 수다 창에 보여요
	ElevatorRide = event("ElevatorRide"), -- 서버 → 클라: 🚪 엘리베이터 탑승 정보 / 결과 ("dodged"/"stare")
	ElevatorDodge = event("ElevatorDodge"), -- 클라 → 서버: 🚪 시선 피하기 (누른 시각)
	RoofAlert = event("RoofAlert"), -- 서버 → 클라: 🚪 띵! 부장님이 옥상으로 올라와요 (몇 초 뒤) -- 클라 → 서버: 🎧 대답 (질문 ID, 고른 번호) -- 클라 → 서버 → 답장: 🪑 ("buy"/"equip", 아이템 ID) / 🏆 ("title", 칭호 ID) -- 클라 → 서버 → 답장: 📋 프로젝트 퍼즐 ("open" / "answer", 답)
	Dinner = event("Dinner"), -- 🍻 회식: 서버 → 클라 ("start"/"line"), 클라 → 서버 ("pour"/"cheers")
	MoveCompany = event("MoveCompany"),
	CompanyNotice = event("CompanyNotice"), -- 서버 → 클라: 🏢 이직/좌천 안내 ("promoted"/"demoted", 직급 이름)
	StreetMenu = event("StreetMenu"), -- 서버 → 클라: 🏙️ 가게 메뉴 창 열기 (가게 ID)
	BuyStreet = func("BuyStreet"),
	ClawOpen = event("ClawOpen"), -- 서버 → 클라: 🧸 인형뽑기 창 열기
	Claw = func("Claw"), -- 클라 → 서버 → 답장: 🧸 인형뽑기 ("start" / "drop", 누른 시각)
	SetDeskPlush = event("SetDeskPlush"),
	WheelOpen = event("WheelOpen"), -- 서버 → 클라: 🎡 돌림판 창 열기
	PlaneOpen = event("PlaneOpen"), -- 서버 → 클라: ✈️ 종이비행기 창 열기
	PlaneThrow = func("PlaneThrow"),
	PlaneFlight = event("PlaneFlight"), -- 서버 → 모든 클라: ✈️ 종이비행기 비행 경로 (모두의 화면에 날아가요) -- 클라 → 서버 → 답장: ✈️ ("begin") → 바람 / ("throw", 각도, 힘%, 방향°)
	CertExam = func("CertExam"), -- 클라 → 서버 → 답장: 📚 ("start", 자격증 ID) / ("answer", 보기 번호)
	BuyCoupon = func("BuyCoupon"), -- 클라 → 서버 → 답장: 🎟️ 쿠폰 사서 바로 쓰기 (쿠폰 ID)
	DeskUpgrade = func("DeskUpgrade"), -- 클라 → 서버 → 답장: 🖥️ 책상 장비 업그레이드 (장비 ID)
	SensorAlert = event("SensorAlert"), -- 서버 → 클라: 🔔 인기척 센서 📳 (부장님과의 거리)
	OutfitAction = func("OutfitAction"), -- 클라 → 서버 → 답장: 👔 ("buy", ID) / ("equip", ID) / ("unequip", 칸)
	HoopOpen = event("HoopOpen"), -- 서버 → 클라: 🏀 농구 창 열기
	HoopPlay = func("HoopPlay"), -- 클라 → 서버 → 답장: 🏀 ("start") / ("shoot", 누른 시각)
	HoopShot = event("HoopShot"), -- 서버 → 모든 클라: 🏀 공이 날아가는 모습 (출발, 골대, 결과)
	SunsetMoment = event("SunsetMoment"), -- 서버 → 클라: 🌅 "오늘 하루도 고생했다…" 연출
	SunsetPhoto = event("SunsetPhoto"), -- 서버 → 클라: 📸 노을 사진 (몇 번째 장, 상금)
	ScopeOpen = event("ScopeOpen"), -- 서버 → 클라: 🔭 관찰 망원경 보기 열기
	ScopeSpot = func("ScopeSpot"), -- 클라 → 서버 → 답장: 🔭 (창문 번호, 장면 ID) 초점 맞췄어요
	GardenOpen = event("GardenOpen"), -- 서버 → 클라: 🌱 텃밭 창 열기
	GardenAction = func("GardenAction"), -- 클라 → 서버 → 답장: 🌱 (행동, 화분 번호, 씨앗 ID)
	ParkOpen = event("ParkOpen"), -- 서버 → 클라: 🌷 공원 화단 창 열기 (화단 번호, 화단 위치)
	ParkAction = func("ParkAction"), -- 클라 → 서버 → 답장: 🌷 (행동 "plant"/"water"/"feed"/"clear", 화단 번호, 꽃 ID)
	BuyFlower = func("BuyFlower"), -- 클라 → 서버 → 답장: 🏪 매점에서 🌷 꽃씨 / 🧪 거름 사기 (꽃 ID 또는 "fertilizer", 개수) → (성공, 메시지)
	PigeonBook = event("PigeonBook"), -- 서버 → 클라: 🐦 관찰 노트 열기
	PigeonScare = event("PigeonScare"), -- 서버 → 클라: 🐦 비둘기가 놀라서 날아감 (부장님이 곧 와요)
	PigeonSnackOpen = event("PigeonSnackOpen"), -- 서버 → 클라: 🍪 모이 통에서 뿌릴 과자 고르기 창 열기 (모이 통 위치)
	PigeonFeed = func("PigeonFeed"), -- 클라 → 서버 → 답장: 🍪 고른 과자 뿌리기 (과자 ID) → (성공, 메시지)
	BuyPigeonSnack = func("BuyPigeonSnack"), -- 클라 → 서버 → 답장: 🏪 매점에서 🍪 비둘기 과자 사기 (과자 ID, 개수) → (성공, 메시지)
	MinesPlay = func("MinesPlay"), -- 클라 → 서버 → 답장: 💣 ("start", 금액, 지뢰 수) / ("open", 칸 번호) / ("stop")
	BaseballPlay = func("BaseballPlay"), -- 클라 → 서버 → 답장: ⚾ ("start") / ("guess", "472") / ("quit")
	ShapesPlay = func("ShapesPlay"), -- 클라 → 서버 → 답장: 🧩 ("start") / ("submit", 조각별 칸 목록) / ("quit")
	MinesForfeit = event("MinesForfeit"), -- 서버 → 클라: 💣 폰 게임이 강제로 꺼졌어요 (지뢰 위치, 이유)
	WheelBet = func("WheelBet"), -- 클라 → 서버 → 답장: 🎡 ("bet", 금액, 숫자) / ("spin")
	GuardBribeOpen = event("GuardBribeOpen"), -- 서버 → 클라: 🎁 경비원 뇌물 창 열기 (경비원 ID, 이름)
	GuardBribe = func("GuardBribe"), -- 클라 → 서버 → 답장: 🎁 (경비원 ID, 선물 ID) → { ok, message, seconds } (🎒에 있는 선물을 드려요)
	BuyGuardGift = func("BuyGuardGift"), -- 클라 → 서버 → 답장: 🏪 매점에서 경비원 선물 사기 (선물 ID) → (성공, 메시지)
	BuySeed = func("BuySeed"), -- 클라 → 서버 → 답장: 🏪 매점에서 🌱 씨앗 사기 (씨앗 ID, 개수) → (성공, 메시지) (🎒에 보관 → 옥상 화분에 심어요)
	DartOpen = event("DartOpen"), -- 서버 → 클라: 🎯 풍선 다트 창 열기
	Dart = func("Dart"), -- 클라 → 서버 → 답장: 🎯 ("open" 풍선 벽 보기·이어 하기) / ("start" 돈 내기) / ("throw", 각도, 힘, 놓은 서버 시각)
	ArcadeOpen = event("ArcadeOpen"), -- 서버 → 클라: 🕹️ 오락실 창 열기 ("mole" / "memory" / "prizes")
	Arcade = func("Arcade"), -- 클라 → 서버 → 답장: 🕹️ ("start", 게임) / ("flip", 카드 번호) / ("finish", 기록) / ("exchange", 경품) -- 클라 → 서버: 🧸 책상에 인형 진열 켜기/끄기 -- 클라 → 서버 → 답장: 🏙️ 가게에서 사기 (가게 ID, 메뉴 ID) -- 클라 → 서버: 스카우트 제의 수락 (새 회사 사무실 서버로 이동)
	UseEnergy = event("UseEnergy"), -- 클라 → 서버: 에너지 드링크 마시기
	ToggleDeskItem = event("ToggleDeskItem"), -- 클라 → 서버: 🪑 산 사무용품을 책상에 놓기/치우기 (아이템 ID)
	BuyItem = func("BuyItem"), -- 클라 → 서버 → 답장: 매점에서 아이템 사기 (성공 여부, 메시지)
	TradeStock = func("TradeStock"), -- 클라 → 서버 → 답장: 화장실 주식 사고팔기 (회사, 수량: +살 때 / -팔 때)
	Broke = event("Broke"), -- 서버 → 클라: 💸 돈이 모자라요 (화면 가운데 크게 알려요)
	Notify = event("Notify"), -- 서버 → 클라: 안내 문구
	ElevatorMenu = event("ElevatorMenu"), -- 서버 → 클라: 🚪 엘리베이터 층 고르기 (지금 층 ID, { { id, 이름 } ... })
	Craft = func("Craft"), -- 클라 → 서버: 🎒 수면제 커피 만들기
	GiveMenu = event("GiveMenu"), -- 서버 → 클라: 👔 부장님께 무엇을 드릴까 ({ { id, 이름 } ... })
	GiveChoose = event("GiveChoose"), -- 클라 → 서버: 고른 것 ID
	CoworkerMenu = event("CoworkerMenu"), -- 서버 → 클라: 💬 동료에게 무엇을 할까 (제목, { { id, 이름 } ... })
	CoworkerChoose = event("CoworkerChoose"), -- 클라 → 서버: 고른 것 ID
	ElevatorGo = event("ElevatorGo"), -- 클라 → 서버: 🚪 고른 층 ID
	NoticeRead = event("NoticeRead"), -- 클라 → 서버: 🔔 알림 창을 열었어요 (모두 읽음)
	Unboxed = event("Unboxed"), -- 서버 → 클라: 📦 택배 뜯기 성공! (물건 이름) → 축하 팝업·소리
	SpeedChange = event("SpeedChange"), -- 서버 → 클라: ⚡ 오늘의 의심도 속도가 바뀜 (이유, 배율, 지금 속도)
	AuditPhoto = event("AuditPhoto"), -- 서버 → 클라: 🕶️ 감사관 카메라 ("aim"/"shot"/"miss"/"reveal"/"wrong", 장수)
	NearMiss = event("NearMiss"), -- 서버 → 클라: 아슬아슬 보너스 (금액, 콤보)
	Caught = event("Caught"),
	AwayAlert = event("AwayAlert"), -- 서버 → 클라: 🖥️ 컴퓨터 자동 감지 시스템 경보 (자리 부재 70%) -- 서버 → 클라: 적발! (부장 대사, 경고 수)
	Fired = event("Fired"), -- 서버 → 클라: 해고
	Payslip = event("Payslip"), -- 서버 → 클라: 월급명세서 (+ 승진 소식)
	Unlocked = event("Unlocked"), -- 서버 → 클라: 도감에 새 항목 (이모지, 이름)
	Bonus = event("Bonus"), -- 서버 → 클라: 보너스 팝업 (문구, 금액) — 수다 성공, 간식 완식
}

folder.Parent = ReplicatedStorage

return Remotes
