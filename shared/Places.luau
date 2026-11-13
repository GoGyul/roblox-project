-- 고결게임즈 장소(Place) 목록
--
-- 광장에 새 게임을 추가하려면 아래 Games 목록에 한 줄(블록)만 추가하면 돼요.
-- 광장에 포탈이 자동으로 생겨요. (포탈 자리는 최대 3개)
--
-- placeId는 Publish한 뒤 Creator Hub(create.roblox.com)에서 확인해서 0 대신 적어 주세요.
-- 0으로 남아 있으면 텔레포트하지 않고 안내 문구만 보여 줘요.

export type GameInfo = {
	id: string, -- 코드에서 쓰는 이름 (영어)
	name: string, -- 포탈 간판에 보이는 이름
	emoji: string,
	placeId: number,
	maxPlayers: number, -- 한 팀 최대 인원
	color: Color3, -- 포탈 색
}

local Places = {}

Places.LOBBY = 74293322423189 -- 🏛️ 고결게임즈 메인 광장 (시작 장소)

Places.Games = {
	{
		id = "clocktower",
		name = "멈춘 시계탑",
		emoji = "🕰️",
		placeId = 135673855098330,
		maxPlayers = 4,
		color = Color3.fromRGB(255, 190, 90),
	},
	{
		id = "salary",
		name = "월급루팡",
		emoji = "💼",
		placeId = 131519518238691,
		maxPlayers = 1, -- 혼자 하는 게임: 한 명씩 자기 사무실로
		color = Color3.fromRGB(120, 200, 255),
	},
	-- 새 게임 예시:
	-- {
	-- 	id = "newgame",
	-- 	name = "새 게임 이름",
	-- 	emoji = "🎮",
	-- 	placeId = 0,
	-- 	maxPlayers = 6,
	-- 	color = Color3.fromRGB(120, 200, 255),
	-- },
} :: { GameInfo }

return Places
