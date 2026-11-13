-- 서버와 클라이언트가 함께 쓰는 설정값

local Config = {}

-- 과거 시대의 탑은 현재 탑에서 이만큼 떨어진 곳에 똑같은 모양으로 지어져요.
-- 시간 전환 = 캐릭터를 이 거리만큼 순간이동시키는 것
Config.ERA_OFFSET = Vector3.new(300, 0, 0)

Config.EraNames = {
	present = "현재",
	past = "과거 · 50년 전",
}

-- 아이템 ID → 화면에 보이는 이름
Config.Items = {
	watch = "회중시계",
	seed = "오래된 씨앗",
	gearSmall = "작은 톱니바퀴",
	gearMedium = "중간 톱니바퀴",
	gearLarge = "큰 톱니바퀴",
	oil = "기름통",
}

-- 인벤토리에 보여 줄 순서
Config.ItemOrder = { "watch", "seed", "oil", "gearSmall", "gearMedium", "gearLarge" }

Config.TOGGLE_KEY = Enum.KeyCode.T
Config.TOGGLE_COOLDOWN = 1

return Config
