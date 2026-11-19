-- 🏙️ (주)눈치물산 사무실 (대리부터 출근)
-- 대충상사보다 훨씬 넓고(가로 104, 세로 60) 고급스러워요. 배치도 완전히 달라요.
--
--   ┌──────────── 통유리창 · 사훈 · 벽시계 · 회사 로고 ────────────┐
--   │ 📊 유리 회의실 │          [출입문] [안내데스크]  │ 🚻 화장실    │
--   │  (앞쪽 왼쪽)   │                                 │ (앞쪽 오른쪽) │
--   │──────────────┘  [책상1]   [책상2]   [책상3]     └──────────────│
--   │                    🪑        🪑        🪑                       │
--   │  🖨️ 프린터         [책상4]   [책상5]   [책상6]                    │
--   │──────────────┐     🪑        🪑        🪑                       │
--   │ ☕ 카페 라운지 │                                    🛋️ 휴게 라운지 │
--   │  (뒤쪽 왼쪽)   │        [김부장 자리] (원목 책상)     (뒤쪽 오른쪽) │
--   └──────────────┴──────────── 원목 벽 ─────────────────────────────┘
--
-- 반환하는 값(Office)은 대충상사와 똑같은 모양이라, 부장·동료·이벤트 코드는 그대로 동작해요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Build = require(ReplicatedStorage.Shared.Build)
local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)

local OfficeNunchi = {}

local HW = 52 -- 가로 절반 (벽 안쪽)
local HD = 30 -- 세로 절반
local WALL_HEIGHT = 14

local C = {
	floor = Color3.fromRGB(205, 205, 200), -- 밝은 대리석
	rug = Color3.fromRGB(60, 70, 85), -- 업무 공간 카펫
	wall = Color3.fromRGB(246, 246, 248),
	wood = Color3.fromRGB(120, 80, 50),
	darkWood = Color3.fromRGB(80, 50, 30),
	accent = Color3.fromRGB(40, 160, 170),
	glass = Color3.fromRGB(190, 225, 240),
	sofa = Color3.fromRGB(70, 90, 110),
	white = Color3.fromRGB(250, 250, 250),
	tile = Color3.fromRGB(225, 230, 235),
	plant = Color3.fromRGB(60, 140, 70),
	pot = Color3.fromRGB(230, 230, 225),
}

-- helpers: OfficeBuilder가 넘겨줘요 (v, zone, buildDesk, makeAssembly, FLOOR_Y)
function OfficeNunchi.build(B, folder: Folder, company, helpers)
	local v = helpers.v
	local zone = helpers.zone
	local FLOOR_Y = helpers.FLOOR_Y
	local wall = { Color = C.wall, Material = Enum.Material.Plaster }
	local glass = {
		Color = C.glass,
		Material = Enum.Material.Glass,
		Transparency = 0.55,
		CanQuery = false, -- 유리라서 부장님 시선이 통과해요
	}

	local function plant(position: Vector3, size: number?)
		local s = size or 1
		B:part(Vector3.new(2, 1.8, 1.8) * s, position + Vector3.new(0, 1 * s, 0), { Color = C.pot, Shape = Enum.PartType.Cylinder, Orientation = Vector3.new(0, 0, 90) })
		B:part(Vector3.new(3, 3, 3) * s, position + Vector3.new(0, 3.2 * s, 0), { Shape = Enum.PartType.Ball, Color = C.plant, Material = Enum.Material.Grass })
	end

	---------------------------------------------------------------- 바닥, 천장, 벽
	B:part(Vector3.new(HW * 2 + 2, 1, HD * 2 + 2), Vector3.new(0, FLOOR_Y - 0.5, 0), { Color = C.floor, Material = Enum.Material.Marble })
	B:part(Vector3.new(HW * 2 + 2, 1, HD * 2 + 2), v(0, WALL_HEIGHT + 0.5, 0), { Color = C.wall })
	-- 업무 공간 카펫
	B:part(Vector3.new(56, 0.1, 34), v(0, 0.05, -4), { Color = C.rug, Material = Enum.Material.Carpet, CanCollide = false })
	B:wall("X", -HD - 0.5, -HW - 1, HW + 1, FLOOR_Y, WALL_HEIGHT, { { center = 0, width = 6, height = 9 } }, wall) -- 앞 (출입문)
	B:wall("X", HD + 0.5, -HW - 1, HW + 1, FLOOR_Y, WALL_HEIGHT, nil, wall) -- 뒤
	B:wall("Z", -HW - 0.5, -HD, HD, FLOOR_Y, WALL_HEIGHT, nil, wall) -- 왼쪽
	B:wall("Z", HW + 0.5, -HD, HD, FLOOR_Y, WALL_HEIGHT, nil, wall) -- 오른쪽
	-- 출입문 바깥은 🌳 잔디 공원이에요 (아래에서 지어요)

	-- 통유리창 (앞 벽 안쪽)
	for x = -46, 46, 10 do
		if math.abs(x) > 6 then
			B:part(Vector3.new(9, 8, 0.2), v(x, 5, -HD + 0.1), {
				Color = Color3.fromRGB(170, 210, 240),
				Material = Enum.Material.Glass,
				Transparency = 0.25,
			})
		end
	end
	-- 뒷벽 원목 패널
	B:part(Vector3.new(60, WALL_HEIGHT - 2, 0.3), v(0, WALL_HEIGHT / 2, HD - 0.2), { Color = C.wood, Material = Enum.Material.WoodPlanks })

	-- 사훈, 벽시계, 회사 로고 (앞 벽 창문 위)
	local banner = B:part(Vector3.new(20, 2.5, 0.2), v(0, 11.5, -HD + 0.15), { Color = C.accent })
	Build.surfaceText(banner, Enum.NormalId.Back, company.motto, {
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(255, 255, 255),
	})
	local clockFace = B:part(Vector3.new(3, 3, 0.2), v(-16, 11.5, -HD + 0.15), { Color = C.wall })
	local setClock = Build.clockFace(clockFace, Enum.NormalId.Back)
	local logo = B:part(Vector3.new(8, 2, 0.2), v(18, 11.5, -HD + 0.15), { Color = Color3.fromRGB(30, 35, 45) })
	Build.surfaceText(logo, Enum.NormalId.Back, "👁️ NUNCHI CORP.", {
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.accent,
	})

	-- 안내 데스크 (출입문 옆)
	B:part(Vector3.new(8, 3, 2.5), v(12, 1.5, -HD + 5), { Color = C.white, Material = Enum.Material.Marble })
	B:part(Vector3.new(8.2, 0.3, 2.7), v(12, 3.1, -HD + 5), { Color = C.darkWood, Material = Enum.Material.Wood })

	---------------------------------------------------------------- 직원 책상 6개 (넓은 간격)
	local desks = {}
	local index = 0
	for _, z in { -14, -1 } do
		for _, x in { -14, 0, 14 } do
			index += 1
			table.insert(desks, helpers.buildDesk(B, index, x, z))
		end
	end

	---------------------------------------------------------------- 김부장 자리 (뒤쪽 가운데, 원목 책상)
	B:part(Vector3.new(10, 2.5, 4), v(0, 1.25, 21), { Color = C.darkWood, Material = Enum.Material.Wood })
	local nameplate = B:part(Vector3.new(3.4, 0.8, 0.4), v(0, 2.9, 18.9), { Color = Color3.fromRGB(40, 30, 20) })
	Build.surfaceText(nameplate, Enum.NormalId.Front, "부장 김부장", {
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(230, 190, 90),
	})
	B:part(Vector3.new(2.6, 1.8, 0.3), v(-1.6, 3.4, 22), { Color = Color3.fromRGB(25, 25, 30) }) -- 모니터 2대
	B:part(Vector3.new(2.6, 1.8, 0.3), v(1.6, 3.4, 22), { Color = Color3.fromRGB(25, 25, 30) })
	B:part(Vector3.new(3, 3.8, 3), v(8, 1.9, 26), {
		Color = Color3.fromRGB(50, 25, 20),
		Material = Enum.Material.Leather,
		CanCollide = false,
	}) -- 부장 의자 (장식)
	plant(v(-7, 0, 26))

	---------------------------------------------------------------- 📊 유리 회의실 (앞쪽 왼쪽, x -52~-36 / z -30~-16)
	B:wall("Z", -36, -HD, -16, FLOOR_Y, 9, { { center = -22, width = 4, height = 7.5 } }, glass)
	B:wall("X", -16, -HW, -36, FLOOR_Y, 9, nil, glass)
	B:part(Vector3.new(16, 0.1, 14), v(-44, 0.05, -23), { Color = Color3.fromRGB(90, 80, 70), Material = Enum.Material.Carpet, CanCollide = false })
	B:part(Vector3.new(9, 2.5, 4), v(-44, 1.25, -24), { Color = C.darkWood, Material = Enum.Material.Wood }) -- 회의 탁자
	local board = B:part(Vector3.new(10, 4.5, 0.2), v(-44, 6, -HD + 0.4), { Color = C.white })
	Build.surfaceText(board, Enum.NormalId.Back, "📊 4분기 전략 회의\n(조는 사람 없기!)", {
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(40, 60, 140),
	})
	local meetingSeats = {}
	for _, x in { -48, -44, -40 } do
		local seat = B:part(Vector3.new(2, 1, 2), v(x, 1, -20), {
			ClassName = "Seat",
			Name = "MeetingSeat",
			Color = Color3.fromRGB(35, 40, 50),
		}) :: Seat
		B:part(Vector3.new(2, 2.6, 0.3), v(x, 2.8, -19.1), { Color = Color3.fromRGB(35, 40, 50), Material = Enum.Material.Leather })
		table.insert(meetingSeats, seat)
	end
	local meetingSign = B:part(Vector3.new(0.2, 1.2, 3), v(-35.35, 8, -22), { Color = C.accent })
	Build.surfaceText(meetingSign, Enum.NormalId.Right, "📊 회의실")
	plant(v(-50, 0, -18), 0.8)
	local meetingZone = zone(B, "MeetingZone", Vector3.new(16, 10, 14), v(-44, 5, -23))

	---------------------------------------------------------------- 🚻 화장실 (앞쪽 오른쪽, x 36~52 / z -30~-14)
	B:wall("Z", 36.5, -HD, -14, FLOOR_Y, WALL_HEIGHT, { { center = -22, width = 4, height = 8 } }, wall)
	B:wall("X", -13.5, 36, HW, FLOOR_Y, WALL_HEIGHT, nil, wall)
	B:part(Vector3.new(16, 0.2, 16), v(44, 0.1, -22), { Color = C.tile, Material = Enum.Material.Marble })
	local toiletSeats = {}
	for i, x in { 40, 44, 48 } do
		if i < 3 then
			B:part(Vector3.new(0.3, 7, 5), v(x + 2, 3.5, -16.5), { Color = Color3.fromRGB(70, 80, 95) }) -- 칸막이
		end
		B:part(Vector3.new(2.2, 1, 2.6), v(x, 0.5, -15.6), { Color = C.white }) -- 변기 몸통
		B:part(Vector3.new(2.2, 2.4, 0.9), v(x, 1.8, -14.5), { Color = C.white }) -- 물탱크
		local seat = B:part(Vector3.new(2, 0.4, 2), v(x, 1.2, -15.8), {
			ClassName = "Seat",
			Name = "ToiletSeat",
			Color = C.white,
		}) :: Seat
		table.insert(toiletSeats, seat)
	end
	-- 세면대와 큰 거울 (오른쪽 벽)
	for _, z in { -27, -23 } do
		B:part(Vector3.new(2.5, 3, 2.2), v(50.75, 1.5, z), { Color = C.white, Material = Enum.Material.Marble })
	end
	B:part(Vector3.new(0.2, 3, 8), v(51.9, 5.5, -25), { Color = C.glass, Material = Enum.Material.Glass, Reflectance = 0.3 })
	local toiletSign = B:part(Vector3.new(0.2, 1.5, 3), v(35.85, 9, -22), { Color = Color3.fromRGB(40, 90, 160) })
	Build.surfaceText(toiletSign, Enum.NormalId.Left, "🚻 화장실")
	local toiletZone = zone(B, "ToiletZone", Vector3.new(16, 10, 16), v(44, 5, -22))

	---------------------------------------------------------------- ☕ 카페 라운지 = 탕비실 (뒤쪽 왼쪽, x -52~-30 / z 5.5~30) — 넓혔어요
	B:wall("Z", -30.5, 5.5, HD, FLOOR_Y, WALL_HEIGHT, { { center = 12, width = 5, height = 8 } }, wall)
	B:wall("X", 5.5, -HW, -30, FLOOR_Y, WALL_HEIGHT, nil, wall)
	B:part(Vector3.new(22, 0.2, 24.5), v(-41, 0.1, 17.75), { Color = Color3.fromRGB(170, 120, 80), Material = Enum.Material.WoodPlanks })
	local pantryCounter = B:part(Vector3.new(2.5, 3, 12), v(-50.75, 1.5, 19.5), {
		Name = "PantryCounter",
		Color = Color3.fromRGB(40, 40, 45),
		Material = Enum.Material.Granite,
	}) -- 조리대 (라면)
	B:part(Vector3.new(1.4, 2, 1.4), v(-50.75, 4, 24.5), { Color = Color3.fromRGB(180, 180, 185), Material = Enum.Material.Metal }) -- 에스프레소 머신
	B:part(Vector3.new(1.6, 0.6, 1.6), v(-50.75, 3.3, 21), { Color = Color3.fromRGB(60, 60, 65) }) -- 인덕션
	B:part(Vector3.new(2.5, 7, 2.5), v(-50.75, 3.5, 28), { Color = Color3.fromRGB(200, 200, 205), Material = Enum.Material.Metal }) -- 냉장고
	-- 간식 테이블 (가운데, 위에 과자 8개)
	B:part(Vector3.new(5, 3, 7), v(-40, 1.5, 17), { Color = C.white, Material = Enum.Material.Marble })
	-- 테이블 위로 못 올라가게 투명한 덮개 (간식은 [E]로 옆에서 가져가요)
	B:part(Vector3.new(5, 8, 7), v(-40, 7, 17), { Name = "SnackTableGuard", Transparency = 1, CanQuery = false })
	local snackSign = B:part(Vector3.new(3, 0.9, 0.2), v(-40, 3.7, 13.4), { Color = Color3.fromRGB(255, 240, 200) })
	Build.surfaceText(snackSign, Enum.NormalId.Front, "🍪 간식 (1인 1개)", { TextColor3 = Color3.fromRGB(80, 50, 30) })
	local snackSpots = {}
	for _, z in { 14.6, 16.2, 17.8, 19.4 } do
		for _, x in { -40.8, -39.2 } do
			table.insert(snackSpots, v(x, 3, z))
		end
	end
	-- 바 테이블과 스툴
	B:part(Vector3.new(6, 3.5, 1.5), v(-40, 1.75, 27.5), { Color = C.darkWood, Material = Enum.Material.Wood })
	for _, x in { -42, -40, -38 } do
		B:part(Vector3.new(2.4, 1.2, 1.2), v(x, 1.2, 25.8), { Color = Color3.fromRGB(40, 40, 45), Shape = Enum.PartType.Cylinder, Orientation = Vector3.new(0, 0, 90) })
	end
	local pantrySign = B:part(Vector3.new(0.2, 1.5, 4), v(-29.85, 9, 12), { Color = Color3.fromRGB(110, 70, 40) })
	Build.surfaceText(pantrySign, Enum.NormalId.Right, "☕ 카페 라운지")
	local pantryZone = zone(B, "PantryZone", Vector3.new(22, 10, 24.5), v(-41, 5, 17.75))

	---------------------------------------------------------------- 🏪 사내 매점 (뒤쪽 오른쪽, x 33.5~52 / z 11.5~30): 문이 있는 큰 별도 공간
	B:wall("Z", 33.5, 11.5, HD, FLOOR_Y, WALL_HEIGHT, { { center = 20, width = 4.5, height = 8 } }, wall)
	B:wall("X", 11.5, 33.5, HW, FLOOR_Y, WALL_HEIGHT, nil, wall)
	local storeSpot = helpers.buildStore(B, 43, 18.5, C.accent)
	helpers.decorateStore(B, {
		center = Vector2.new(42.75, 20.75),
		size = Vector2.new(18, 18),
		wallX = 51.3,
		z1 = 20,
		z2 = 29.5,
		fridge = Vector2.new(51, 14),
		signPosition = v(32.85, 9, 20),
		signFace = Enum.NormalId.Left,
	})
	plant(v(36, 0, 28))

	-- 장식: 화분, 프린터
	for _, position in { v(-30, 0, -27), v(19, 0, -28), v(-26, 0, 3), v(30, 0, 7), v(-24, 0, 27), v(24, 0, 27) } do
		plant(position)
	end
	local printer = B:part(Vector3.new(3, 2.5, 2.5), v(-30, 1.25, -4), { Name = "Printer", Color = Color3.fromRGB(230, 230, 235) })
	B:part(Vector3.new(2.6, 0.6, 1.8), v(-30, 2.8, -4), { Color = Color3.fromRGB(60, 60, 65) })

	---------------------------------------------------------------- 조명 (따뜻한 펜던트 조명)
	local lamps = {}
	for _, x in { -44, -28, -14, 0, 14, 28, 44 } do
		for _, z in { -22, -8, 6, 20 } do
			local lamp = B:part(Vector3.new(5, 0.3, 1.4), v(x, WALL_HEIGHT - 0.8, z), {
				Color = Color3.fromRGB(255, 245, 225),
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
			B:part(Vector3.new(0.1, 0.6, 0.1), v(x, WALL_HEIGHT - 0.35, z), { Color = Color3.fromRGB(40, 40, 40), CanCollide = false }) -- 매다는 줄
			local light = Instance.new("PointLight")
			light.Range = 22
			light.Brightness = 0.4
			light.Color = Color3.fromRGB(255, 240, 215)
			light.Parent = lamp
			table.insert(lamps, lamp)
		end
	end

	---------------------------------------------------------------- 🌳 1층 잔디 공원 (출입문 밖, z -31 ~ -84)
	local PARK_FAR = -84
	local parkCenterZ = (-HD - 1 + PARK_FAR) / 2
	local parkDepth = -HD - 1 - PARK_FAR
	B:part(Vector3.new(HW * 2 + 2, 1, parkDepth), Vector3.new(0, FLOOR_Y - 0.5, parkCenterZ), { Color = Color3.fromRGB(95, 165, 75), Material = Enum.Material.Grass })
	-- 공원 울타리: 보이는 낮은 산울타리 + 못 넘어가게 투명한 높은 벽
	for _, info in {
		-- 맨 끝 울타리는 가운데에 정문(폭 10)을 뚫어 눈치 스트리트로 이어져요
		{ Vector3.new(HW - 4, 3, 1.5), v(-(HW + 6) / 2 - 0.5, 1.5, PARK_FAR) },
		{ Vector3.new(HW - 4, 3, 1.5), v((HW + 6) / 2 + 0.5, 1.5, PARK_FAR) },
		{ Vector3.new(1.5, 3, parkDepth), v(-HW - 0.5, 1.5, parkCenterZ) },
		{ Vector3.new(1.5, 3, parkDepth), v(HW + 0.5, 1.5, parkCenterZ) },
	} do
		B:part(info[1], info[2], { Color = Color3.fromRGB(50, 110, 50), Material = Enum.Material.Grass })
		B:part(Vector3.new(info[1].X, 40, info[1].Z), info[2] + Vector3.new(0, 18.5, 0), { Transparency = 1 })
	end
	-- 건물 바깥 간판
	local outsideSign = B:part(Vector3.new(18, 2.5, 0.3), v(0, 11, -HD - 1.2), { Color = Color3.fromRGB(30, 35, 45) })
	Build.surfaceText(outsideSign, Enum.NormalId.Front, "👁️ (주)눈치물산 NUNCHI CORP.", {
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.accent,
	})
	-- 돌길과 분수
	B:part(Vector3.new(6, 0.1, 22), v(0, 0.05, -42), { Color = Color3.fromRGB(175, 170, 160), Material = Enum.Material.Slate, CanCollide = false })
	B:part(Vector3.new(10, 1.4, 10), v(0, 0.7, -60), { Color = Color3.fromRGB(190, 190, 185), Material = Enum.Material.Concrete })
	B:part(Vector3.new(8.6, 0.2, 8.6), v(0, 1.45, -60), { Color = Color3.fromRGB(90, 160, 220), Material = Enum.Material.Glass, Transparency = 0.2, CanCollide = false })
	B:part(Vector3.new(1.2, 4, 1.2), v(0, 2.5, -60), { Color = Color3.fromRGB(200, 200, 195), Material = Enum.Material.Marble })
	-- 나무
	for _, xz in { { -40, -40 }, { -44, -58 }, { -36, -76 }, { 40, -40 }, { -22, -70 }, { 20, -46 }, { -24, -48 }, { 14, -76 }, { 46, -52 }, { -10, -80 } } do
		B:part(Vector3.new(1.6, 8, 1.6), v(xz[1], 4, xz[2]), { Color = Color3.fromRGB(110, 75, 45), Material = Enum.Material.Wood })
		B:part(Vector3.new(8, 8, 8), v(xz[1], 9.5, xz[2]), { Shape = Enum.PartType.Ball, Color = Color3.fromRGB(70, 150, 70), Material = Enum.Material.Grass })
	end
	-- 벤치
	for _, x in { -9, 9 } do
		B:part(Vector3.new(2, 0.4, 6), v(x, 1.6, -50), { Color = C.wood, Material = Enum.Material.WoodPlanks })
		B:part(Vector3.new(0.4, 1.4, 6), v(x + (if x > 0 then 1 else -1), 2.4, -50), { Color = C.wood, Material = Enum.Material.WoodPlanks })
		B:part(Vector3.new(1.6, 1.4, 0.4), v(x, 0.7, -52.5), { Color = Color3.fromRGB(40, 40, 45) })
		B:part(Vector3.new(1.6, 1.4, 0.4), v(x, 0.7, -47.5), { Color = Color3.fromRGB(40, 40, 45) })
	end
	-- 가로등
	for _, xz in { { -16, -40 }, { 16, -40 }, { -16, -70 }, { 16, -70 } } do
		B:part(Vector3.new(0.5, 9, 0.5), v(xz[1], 4.5, xz[2]), { Color = Color3.fromRGB(40, 40, 45), Material = Enum.Material.Metal })
		local bulb = B:part(Vector3.new(1.2, 1.2, 1.2), v(xz[1], 9.4, xz[2]), { Shape = Enum.PartType.Ball, Color = Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon })
		local light = Instance.new("PointLight")
		light.Range = 18
		light.Brightness = 0.6
		light.Parent = bulb
	end

	-- 🍻 회식 테이블 (공원 왼쪽): 긴 식탁 + 양쪽 벤치 의자 8개 + 가운데 불판
	local dinnerX, dinnerZ = -30, -62
	B:part(Vector3.new(14, 0.4, 4), v(dinnerX, 2.6, dinnerZ), { Color = C.wood, Material = Enum.Material.WoodPlanks })
	for _, dx in { -6, 6 } do
		B:part(Vector3.new(0.6, 2.4, 3.4), v(dinnerX + dx, 1.2, dinnerZ), { Color = C.darkWood, Material = Enum.Material.Wood })
	end
	B:part(Vector3.new(2.4, 0.5, 1.4), v(dinnerX, 3.05, dinnerZ), { Color = Color3.fromRGB(40, 40, 45), Material = Enum.Material.Metal }) -- 불판
	B:part(Vector3.new(2, 0.1, 1.1), v(dinnerX, 3.35, dinnerZ), { Color = Color3.fromRGB(255, 90, 40), Material = Enum.Material.Neon, CanCollide = false })
	local dinnerSeats = {}
	for _, side in { -1, 1 } do
		local z = dinnerZ + side * 2.6
		B:part(Vector3.new(14, 0.3, 1.6), v(dinnerX, 0.9, z), { Color = C.wood, Material = Enum.Material.WoodPlanks }) -- 벤치 판
		for _, dx in { -4.5, -1.5, 1.5, 4.5 } do
			-- 의자는 식탁 쪽을 보고 앉아요 (앞쪽이 -Z라서, 북쪽 벤치는 180° 돌려요)
			local facing = if side < 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity
			local seat = B:part(Vector3.new(1.8, 0.4, 1.4), nil, {
				ClassName = "Seat",
				Name = "DinnerSeat",
				CFrame = CFrame.new(v(dinnerX + dx, 1.25, z)) * facing,
				Color = C.wood,
				Material = Enum.Material.WoodPlanks,
			}) :: Seat
			table.insert(dinnerSeats, seat)
		end
	end
	for _, dx in { -9, 9 } do -- 등불
		B:part(Vector3.new(0.4, 7, 0.4), v(dinnerX + dx, 3.5, dinnerZ), { Color = Color3.fromRGB(40, 40, 45) })
		local lantern = B:part(Vector3.new(1, 1.2, 1), v(dinnerX + dx, 7.4, dinnerZ), { Color = Color3.fromRGB(255, 200, 120), Material = Enum.Material.Neon })
		local glow = Instance.new("PointLight")
		glow.Range = 16
		glow.Brightness = 0.8
		glow.Color = Color3.fromRGB(255, 200, 140)
		glow.Parent = lantern
	end

	-- 🍭 흡연구역 (※ 금연! 사탕만 허용) — 공원 오른쪽 안쪽
	local candyX, candyZ = 40, -72
	B:part(Vector3.new(14, 0.15, 12), v(candyX, 0.08, candyZ), { Color = Color3.fromRGB(160, 160, 165), Material = Enum.Material.Concrete, CanCollide = false })
	for _, dx in { -6.5, 6.5 } do
		for _, dz in { -5.5, 5.5 } do
			B:part(Vector3.new(0.5, 8, 0.5), v(candyX + dx, 4, candyZ + dz), { Color = Color3.fromRGB(60, 60, 65), Material = Enum.Material.Metal })
		end
	end
	B:part(Vector3.new(14.5, 0.4, 12.5), v(candyX, 8.2, candyZ), { Color = Color3.fromRGB(200, 220, 230), Material = Enum.Material.Glass, Transparency = 0.4 })
	local candySign = B:part(Vector3.new(7, 1.6, 0.2), v(candyX, 6.6, candyZ + 5.9), { Color = Color3.fromRGB(255, 240, 245) })
	Build.surfaceText(candySign, Enum.NormalId.Back, "🍭 흡연구역 (금연! 사탕만 허용)", {
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(200, 60, 120),
	})
	-- 사탕 통 (가운데 스탠드)
	B:part(Vector3.new(0.4, 3, 0.4), v(candyX, 1.5, candyZ), { Color = Color3.fromRGB(180, 180, 185), Material = Enum.Material.Metal })
	B:part(Vector3.new(1.6, 1.4, 1.6), v(candyX, 3.6, candyZ), { Color = Color3.fromRGB(220, 240, 250), Material = Enum.Material.Glass, Transparency = 0.3 })
	for i, color in { Color3.fromRGB(255, 120, 160), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 220, 90) } do
		B:part(Vector3.new(0.45, 0.45, 0.45), v(candyX - 0.4 + i * 0.25, 3.4, candyZ), { Shape = Enum.PartType.Ball, Color = color, CanCollide = false })
	end
	local candyZone = zone(B, "CandyZone", Vector3.new(14, 10, 12), v(candyX, 5, candyZ))

	---------------------------------------------------------------- 🏙️ 눈치 스트리트 (공원 정문 밖 상가 거리, z -84 ~ -132)
	local STREET_FAR = -132
	local streetCenterZ = (PARK_FAR + STREET_FAR) / 2
	local streetDepth = PARK_FAR - STREET_FAR
	-- 정문 아치
	for _, x in { -5.5, 5.5 } do
		B:part(Vector3.new(1.2, 10, 1.2), v(x, 5, PARK_FAR), { Color = Color3.fromRGB(60, 65, 75), Material = Enum.Material.Metal })
	end
	local gateSign = B:part(Vector3.new(12.2, 1.8, 0.6), v(0, 10.6, PARK_FAR), { Color = Color3.fromRGB(30, 35, 45) })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		Build.surfaceText(gateSign, face, "🏙️ 눈치 스트리트", { Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 220, 120) })
	end
	-- 바닥: 보도 → 차도 → 보도
	B:part(Vector3.new(HW * 2 + 2, 1, streetDepth), Vector3.new(0, FLOOR_Y - 0.5, streetCenterZ), { Color = Color3.fromRGB(190, 185, 175), Material = Enum.Material.Concrete })
	B:part(Vector3.new(HW * 2 + 2, 0.1, 14), v(0, 0.05, -100), { Color = Color3.fromRGB(55, 55, 60), Material = Enum.Material.Asphalt, CanCollide = false })
	for x = -46, 46, 8 do -- 차선
		B:part(Vector3.new(4, 0.12, 0.4), v(x, 0.07, -100), { Color = Color3.fromRGB(240, 210, 80), CanCollide = false })
	end
	for x = -4, 4, 2 do -- 정문 앞 횡단보도
		B:part(Vector3.new(1, 0.13, 13), v(x, 0.07, -100), { Color = Color3.fromRGB(245, 245, 245), CanCollide = false })
	end
	-- 거리 양옆과 뒤는 높은 건물 벽 (밖으로 못 나가요)
	for _, info in {
		{ Vector3.new(1, 16, streetDepth), v(-HW - 0.5, 8, streetCenterZ) },
		{ Vector3.new(1, 16, streetDepth), v(HW + 0.5, 8, streetCenterZ) },
		{ Vector3.new(HW * 2 + 2, 16, 1), v(0, 8, STREET_FAR - 0.5) },
	} do
		B:part(info[1], info[2], { Color = Color3.fromRGB(150, 145, 140), Material = Enum.Material.Brick })
		B:part(Vector3.new(info[1].X, 30, info[1].Z), info[2] + Vector3.new(0, 23, 0), { Transparency = 1 })
	end
	-- 가로등
	for x = -40, 40, 20 do
		B:part(Vector3.new(0.5, 9, 0.5), v(x, 4.5, -91), { Color = Color3.fromRGB(40, 40, 45), Material = Enum.Material.Metal })
		local bulb = B:part(Vector3.new(1.2, 1.2, 1.2), v(x, 9.4, -91), { Shape = Enum.PartType.Ball, Color = Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon })
		local light = Instance.new("PointLight")
		light.Range = 18
		light.Brightness = 0.6
		light.Parent = bulb
	end

	-- 가게 건물 (뒤쪽에 4칸, 앞이 뚫려 있어 거리 쪽을 봐요)
	local SHOP_FRONT, SHOP_BACK = -114, STREET_FAR
	local shops = {}
	local function shopBuilding(cx: number, title: string, wallColor: Color3, awning: Color3, noCounter: boolean?): BasePart?
		local depth = SHOP_FRONT - SHOP_BACK
		local cz = (SHOP_FRONT + SHOP_BACK) / 2
		B:part(Vector3.new(22, 12, 1), v(cx, 6, SHOP_BACK + 0.5), { Color = wallColor, Material = Enum.Material.Plaster }) -- 뒷벽
		for _, dx in { -11, 11 } do
			B:part(Vector3.new(1, 12, depth), v(cx + dx, 6, cz), { Color = wallColor, Material = Enum.Material.Plaster }) -- 옆벽
		end
		B:part(Vector3.new(23, 1, depth + 1), v(cx, 12.5, cz), { Color = wallColor }) -- 지붕
		B:part(Vector3.new(21, 0.1, depth - 1), v(cx, 0.08, cz), { Color = Color3.fromRGB(235, 225, 210), Material = Enum.Material.WoodPlanks, CanCollide = false })
		B:part(Vector3.new(23, 0.4, 4), v(cx, 9.4, SHOP_FRONT - 1.6), { Color = awning, Material = Enum.Material.Fabric, Orientation = Vector3.new(-15, 0, 0) }) -- 차양
		local sign = B:part(Vector3.new(16, 2, 0.4), v(cx, 11, SHOP_FRONT + 0.3), { Color = Color3.fromRGB(35, 30, 30) })
		Build.surfaceText(sign, Enum.NormalId.Front, title, { Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 235, 200) })
		if noCounter then
			return nil
		end
		-- 계산대 (가운데 안쪽)
		local counter = B:part(Vector3.new(10, 3.5, 2), v(cx, 1.75, -124), { Name = "ShopCounter", Color = Color3.fromRGB(120, 85, 60), Material = Enum.Material.Wood })
		return counter
	end

	-- ☕ 눈치 커피
	local cafeCounter = shopBuilding(-39, "☕ 눈치 커피", Color3.fromRGB(110, 80, 60), Color3.fromRGB(40, 120, 80))
	B:part(Vector3.new(1.4, 2, 1.4), v(-42, 4.5, -124), { Color = Color3.fromRGB(190, 190, 195), Material = Enum.Material.Metal }) -- 커피머신
	B:part(Vector3.new(8, 3, 0.4), v(-39, 6.5, -131), { Color = Color3.fromRGB(30, 30, 30) }) -- 메뉴판
	for _, dx in { -6, 6 } do -- 손님 테이블
		B:part(Vector3.new(3, 0.3, 3), v(-39 + dx, 2.6, -118), { Color = Color3.fromRGB(240, 240, 235) })
		B:part(Vector3.new(0.4, 2.5, 0.4), v(-39 + dx, 1.25, -118), { Color = Color3.fromRGB(40, 40, 45) })
	end
	shops.cafe = { counter = cafeCounter, clerkSpot = v(-39, 0, -127) }

	-- 🍰 달콤 디저트
	local dessertCounter = shopBuilding(-13, "🍰 달콤 디저트", Color3.fromRGB(250, 215, 225), Color3.fromRGB(230, 110, 150))
	B:part(Vector3.new(6, 1.6, 1.6), v(-13, 4.3, -124), { Color = Color3.fromRGB(220, 240, 250), Material = Enum.Material.Glass, Transparency = 0.4 }) -- 진열장
	for i, color in { Color3.fromRGB(255, 170, 200), Color3.fromRGB(180, 230, 170), Color3.fromRGB(220, 160, 80), Color3.fromRGB(255, 240, 240), Color3.fromRGB(190, 170, 255) } do
		B:part(Vector3.new(0.7, 0.5, 0.7), v(-15.6 + i * 0.9, 3.9, -124), { Color = color, CanCollide = false })
	end
	shops.dessert = { counter = dessertCounter, clerkSpot = v(-13, 0, -127) }

	-- 🧸 뽑기 가게: 인형뽑기 1대 + 🎡 다 같이 돌림판 + 🎈 풍선 다트
	shopBuilding(13, "🧸 뽑기 천국", Color3.fromRGB(255, 220, 120), Color3.fromRGB(240, 90, 90), true)
	local clawMachines = {}
	do
		local mx, mz = 5.2, -125
		local color = Color3.fromRGB(255, 120, 170)
		local cabinet = B:part(Vector3.new(3.4, 3, 3.4), v(mx, 1.5, mz), { Name = "ClawMachine", Color = color })
		B:part(Vector3.new(3.4, 3.6, 3.4), v(mx, 4.8, mz), { Color = Color3.fromRGB(220, 240, 255), Material = Enum.Material.Glass, Transparency = 0.6 })
		B:part(Vector3.new(3.6, 0.6, 3.6), v(mx, 6.9, mz), { Color = color, Material = Enum.Material.Neon })
		B:part(Vector3.new(0.15, 1.4, 0.15), v(mx, 5.9, mz), { Color = Color3.fromRGB(200, 200, 205), Material = Enum.Material.Metal, CanCollide = false }) -- 집게 줄
		B:part(Vector3.new(0.7, 0.3, 0.7), v(mx, 5.1, mz), { Color = Color3.fromRGB(200, 200, 205), Material = Enum.Material.Metal, CanCollide = false }) -- 집게
		for j = 1, 7 do -- 안에 쌓인 인형들
			local plush = SalaryConfig.Plushies[j % #SalaryConfig.Plushies + 1]
			B:part(Vector3.new(0.8, 0.8, 0.8), v(mx + math.random(-10, 10) / 10, 3.4 + (j % 2) * 0.5, mz + math.random(-10, 10) / 10), {
				Shape = Enum.PartType.Ball,
				Color = plush.color,
				CanCollide = false,
			})
		end
		table.insert(clawMachines, cabinet)
	end

	-- 🎡 돌림판 (뒷벽에 세운 큰 원판, 글씨·회전은 Wheel 모듈이 그려요)
	local wheelX = 11.3
	local wheelDisc = B:part(Vector3.new(0.6, 9, 9), nil, {
		Name = "WheelDisc",
		Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.new(v(wheelX, 6.6, -131.1)) * CFrame.Angles(0, math.rad(90), 0), -- 원판 면이 가게 앞쪽(+Z)을 봐요
		Color = Color3.fromRGB(40, 40, 50),
	})
	B:part(Vector3.new(0.8, 1.2, 0.8), v(wheelX, 11.5, -130.6), { Color = Color3.fromRGB(230, 50, 50), Material = Enum.Material.Neon }) -- ▼ 바늘
	local wheelKiosk = B:part(Vector3.new(5, 3.5, 1.6), v(wheelX, 1.75, -125.5), { Name = "WheelKiosk", Color = Color3.fromRGB(250, 200, 80) })
	local wheelSign = B:part(Vector3.new(5, 0.9, 0.2), v(wheelX, 4, -124.6), { Color = Color3.fromRGB(30, 30, 40) })
	Build.surfaceText(wheelSign, Enum.NormalId.Front, "🎡 다 같이 돌림판", { Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 230, 120) })

	-- 🎈 풍선 다트판 (뒷벽 오른쪽)
	local dartX = 19.8
	local dartBoard = B:part(Vector3.new(6.2, 5, 0.4), v(dartX, 6.2, -131.1), { Name = "DartBoard", Color = Color3.fromRGB(240, 230, 210), Material = Enum.Material.Wood })
	local balloonColors = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 200, 60), Color3.fromRGB(90, 180, 255), Color3.fromRGB(120, 220, 120) }
	for row = 0, SalaryConfig.DART_ROWS - 1 do
		for col = 0, SalaryConfig.DART_COLS - 1 do
			B:part(Vector3.new(1.1, 1.3, 0.8), v(dartX - 2.25 + col * 1.5, 7.8 - row * 1.6, -130.6), {
				Shape = Enum.PartType.Ball,
				Color = balloonColors[(row + col) % #balloonColors + 1],
				CanCollide = false,
			})
		end
	end
	local dartCounter = B:part(Vector3.new(5, 3.5, 1.6), v(dartX, 1.75, -125.5), { Name = "DartCounter", Color = Color3.fromRGB(120, 200, 255) })
	local dartSign = B:part(Vector3.new(5, 0.9, 0.2), v(dartX, 4, -124.6), { Color = Color3.fromRGB(30, 30, 40) })
	Build.surfaceText(dartSign, Enum.NormalId.Front, "🎈 풍선 다트", { Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 230, 120) })

	-- 🕹️ 오락실: 게임기 2대 + 경품 교환대 + 최고 기록판
	shopBuilding(39, "🕹️ 오락실", Color3.fromRGB(60, 60, 110), Color3.fromRGB(150, 80, 230), true)
	B:part(Vector3.new(21, 0.12, 17), v(39, 0.1, -123), { Color = Color3.fromRGB(40, 30, 70), Material = Enum.Material.Carpet, CanCollide = false })
	local arcade = { machines = {} :: { [string]: BasePart } }
	for _, info in { { "mole", 33, "🔨 두더지 잡기", Color3.fromRGB(230, 90, 60) }, { "timing", 39, "🎯 타이밍 스톱", Color3.fromRGB(60, 170, 230) } } do
		local gameId, mx = info[1], info[2]
		local cabinet = B:part(Vector3.new(3.2, 6, 2.6), v(mx, 3, -126.5), { Name = "ArcadeMachine", Color = info[4] })
		B:part(Vector3.new(2.6, 2, 0.1), v(mx, 4.2, -125.15), { Color = Color3.fromRGB(120, 255, 200), Material = Enum.Material.Neon })
		B:part(Vector3.new(3.2, 0.3, 1.2), v(mx, 2.9, -124.8), { Color = Color3.fromRGB(40, 40, 45) }) -- 조작판
		local title = B:part(Vector3.new(3.2, 0.9, 0.2), v(mx, 6.5, -125.1), { Color = Color3.fromRGB(30, 30, 40) })
		Build.surfaceText(title, Enum.NormalId.Front, info[3], { Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 230, 120) })
		arcade.machines[gameId] = cabinet
	end
	-- 경품 교환대 (오른쪽) + 뒤쪽 선반의 경품들
	arcade.prizeCounter = B:part(Vector3.new(4.5, 3.5, 2), v(46, 1.75, -124), { Name = "PrizeCounter", Color = Color3.fromRGB(250, 200, 80) })
	local prizeSign = B:part(Vector3.new(4.5, 0.9, 0.2), v(46, 4, -122.9), { Color = Color3.fromRGB(30, 30, 40) })
	Build.surfaceText(prizeSign, Enum.NormalId.Front, "🎟️ 경품 교환", { Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 230, 120) })
	B:part(Vector3.new(5, 0.3, 1.5), v(46, 5, -129.5), { Color = Color3.fromRGB(120, 85, 60) }) -- 선반
	for i, plush in { SalaryConfig.Plushies[1], SalaryConfig.Plushies[8], SalaryConfig.Plushies[10] } do
		B:part(Vector3.new(0.9, 0.9, 0.9), v(44.5 + (i - 1) * 1.5, 5.6, -129.5), { Shape = Enum.PartType.Ball, Color = plush.color, CanCollide = false })
	end
	-- 🏆 최고 기록판 (뒷벽, 서버가 글씨를 채워요)
	arcade.board = B:part(Vector3.new(12, 4.5, 0.3), v(36, 9, -130.8), { Name = "ArcadeBoard", Color = Color3.fromRGB(20, 20, 30) })

	---------------------------------------------------------------- 🚒 집결지(=🏁 워크숍 결승선)와 시작 지점
	-- 소방 훈련 때는 건물 밖 공원으로 대피해요
	local assemblyZone, assemblyPoint, setAssemblyVisible = helpers.makeAssembly(B, 0, -HD - 9)

	shops.store = storeSpot -- 🏪 사내 매점 (뒤쪽 오른쪽 방)
	-- 📦 택배 상자 (출입문 옆)
	local packageBox = helpers.buildPackage(B, -8, -27)
	-- 🚪 엘리베이터 (왼쪽 벽: 회의실과 카페 라운지 사이)
	local elevator = helpers.buildElevator(B, -HW, -5)
	B:part(Vector3.new(4, 1, 4), v(0, -0.4, -HD + 5), {
		ClassName = "SpawnLocation",
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Neutral = true,
		Duration = 0,
	})

	-- 부장 순찰 지점 (복도)
	local waypoints = {
		v(0, 0, 15), -- 부장 자리 앞
		v(-24, 0, 6),
		v(-24, 0, -7),
		v(-24, 0, -24),
		v(-7, 0, -7.5), -- 책상 줄 사이
		v(7, 0, -7.5),
		v(0, 0, -24), -- 창가
		v(18, 0, -22),
		v(24, 0, -7),
		v(24, 0, 6),
		v(-7, 0, 6), -- 뒷줄 의자 뒤
		v(7, 0, 6),
		v(-27, 0, 12), -- 카페 라운지 문 앞
		v(-32, 0, -10), -- 회의실·프린터 쪽
		v(32, 0, -10), -- 화장실 쪽
		v(30, 0, 20), -- 매점 문 앞
		v(0, 0, -44), -- 🌳 공원 (가끔 나가 봐요)
		v(28, 0, -64), -- 흡연구역 근처
		v(-20, 0, -100), -- 🏙️ 눈치 스트리트 (근무 중 외출 감시!)
		v(20, 0, -100),
	}

	return {
		folder = folder,
		desks = desks,
		bossStand = v(0, 0, 25), -- 부장 책상 뒤
		bossLook = Vector3.new(0, 0, -1),
		entrance = v(0, 0, -HD + 2),
		waypoints = waypoints,
		toiletZone = toiletZone,
		pantryZone = pantryZone,
		printer = printer,
		pantryCounter = pantryCounter,
		snackSpots = snackSpots,
		spots = { v(-44, 0, 14), v(-27, 0, -4), v(-14, 0, -26), v(14, 0, -26), v(42, 0, 25), v(-6, 0, -48) },
		toiletSeats = toiletSeats,
		meetingSeats = meetingSeats,
		meetingZone = meetingZone,
		companyId = company.id,
		lamps = lamps,
		assemblyZone = assemblyZone,
		assemblyPoint = assemblyPoint,
		setAssemblyVisible = setAssemblyVisible,
		cakeSpots = { v(-50.6, 3, 14.5), v(-50.6, 3, 16), v(-50.6, 3, 17.5) },
		workshopStart = v(0, 0, PARK_FAR + 6), -- 🌸 공원 맨 끝에서 출발
		workshopBoss = v(0, 0, -HD - 4), -- 부장님은 건물 출입문 바로 앞에서 술래
		workshopLook = Vector3.new(0, 0, -1), -- 술래가 직원들을 볼 때 방향 (공원 쪽)
		candyZone = candyZone,
		shops = shops, -- 🏙️ 눈치 스트리트 가게들 + 🏪 사내 매점 (계산대, 사장님 자리)
		packageBox = packageBox,
		elevator = elevator,
		insideOffice = function(position: Vector3): boolean
			-- 건물 안만 (출입문 밖 공원·눈치 스트리트, 하늘 위 옥상은 밖)
			return math.abs(position.X) <= HW + 1 and position.Z >= -HD - 0.5 and position.Z <= HD + 1 and position.Y < FLOOR_Y + 20
		end,
		packageSpots = { v(-8, 0, -24), v(-40, 0, 24), v(42, 0, 26), v(0, 0, -50), v(-44, 0, -22), v(30, 0, -8), v(0, 0, 16), v(44, 0, -24) },
		clawMachines = clawMachines, -- 🧸 인형뽑기 기계
		wheel = { disc = wheelDisc, kiosk = wheelKiosk }, -- 🎡 다 같이 돌림판
		dart = { board = dartBoard, counter = dartCounter }, -- 🎈 풍선 다트
		arcade = arcade, -- 🕹️ 오락실 (게임기, 경품 교환대, 기록판)
		dinnerSeats = dinnerSeats, -- 🍻 회식은 공원 식탁에서
		dinnerBoss = v(dinnerX - 8.5, 0, dinnerZ), -- 부장님은 식탁 끝 상석
		dinnerLook = Vector3.new(1, 0, 0),
		setClock = setClock,
	}
end

return OfficeNunchi
