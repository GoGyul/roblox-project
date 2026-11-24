-- 🏙️ (주)눈치물산 사무실 (대리부터 출근)
-- 대충상사보다 훨씬 넓고(가로 144, 세로 84) 고급스러워요. 배치도 완전히 달라요.
--
--   ┌──────────── 통유리창 · 사훈 · 벽시계 · 회사 로고 ────────────┐  z -42 (출입문 x 0)
--   │ 📊 유리 회의실 │          [출입문] [안내데스크]  │ 🚻 화장실    │
--   │ x -72~-52     │                                 │ x 52~72     │
--   │ z -42~-24.5 ──┘  [책상1]   [책상2]   [책상3]     └── z -42~-22 │  앞줄 z -20
--   │                    🪑        🪑        🪑                       │
--   │🚪엘리베이터 🖨️    [책상4]   [책상5]   [책상6]                    │  뒷줄 z 2
--   │──────────────┐     🪑        🪑        🪑       ┌──────────────│
--   │ ☕ 카페 라운지 │                                 │ 🏪 사내 매점  │
--   │ x -72~-44.5   │        [김부장 자리] (z 22)      │ x 49~72     │
--   │ z 11.5~42     │                                 │ z 19~42     │
--   └──────────────┴──[문 x -20]── 원목 벽 ─────────────┴──────────────┘  z 42
--                  │ 🏋️ 체력 단련실 (별관) │  x -40~0 / z 43~73
--                  └──────────────────────┘
--   책상 x -24 / 0 / 24. 출입문 밖(z -43 ~ -96)은 🌳 공원, 그 너머(z -96 ~ -144)는 🏙️ 눈치 스트리트
--
-- 반환하는 값(Office)은 대충상사와 똑같은 모양이라, 부장·동료·이벤트 코드는 그대로 동작해요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Build = require(ReplicatedStorage.Shared.Build)
local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local Theme = require(ReplicatedStorage.Shared.SalaryTheme)
local Meshes = require(script.Parent.Meshes)
-- 🧊 월드 색: 차분한 색(Theme.Mesh)이 있으면 그걸, 없으면 기본 색을 써요 (질감 B안)
local TC: any = setmetatable({}, {
	__index = function(_, key)
		return (Theme.Mesh :: any)[key] or (Theme.Color :: any)[key]
	end,
})
local Floor = require(script.Parent.OfficeNunchiFloor)

local OfficeNunchi = {}

local HW = 72 -- 가로 절반 (벽 안쪽) — 📐 바닥 넓이 약 2배로 넓혔어요 (예전 52)
local HD = 42 -- 세로 절반 (예전 30)
local WALL_HEIGHT = 14

local M = Theme.Mesh -- 🧊 질감 B안: 채도를 낮춘 월드 색
local C = {
	floor = Color3.fromRGB(198, 199, 200),
	rug = M.carpet,
	wall = M.wall,
	wood = M.wood,
	darkWood = M.woodDark,
	accent = M.mintDark,
	glass = M.skySoft,
	sofa = M.coral,
	white = Color3.fromRGB(240, 239, 236),
	tile = Color3.fromRGB(214, 218, 222),
	plant = M.grass,
	pot = M.surface,
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
		if Meshes.ready("Plant") then
			Meshes.place(B, "Plant", position, 0, { scale = 1.6 * s })
			B:part(Vector3.new(1.8, 1.8, 1.8) * s, position + Vector3.new(0, 0.9 * s, 0), { Transparency = 1 })
			return
		end
		B:part(Vector3.new(2, 1.8, 1.8) * s, position + Vector3.new(0, 1 * s, 0), { Color = C.pot, Shape = Enum.PartType.Cylinder, Orientation = Vector3.new(0, 0, 90) })
		B:part(Vector3.new(3, 3, 3) * s, position + Vector3.new(0, 3.2 * s, 0), { Shape = Enum.PartType.Ball, Color = C.plant, Material = Enum.Material.Grass })
	end

	---------------------------------------------------------------- 🏢 건물 안: 리뉴얼 평면 (OfficeNunchiFloor.luau가 지어요)
	--   사무실 · 유리 회의실 · 카페 라운지 · 복도 · 화장실 · 라운지 · 체력 단련실. 건물 테두리와 북쪽 출입문은 예전과 같은 자리예요.
	local F = Floor.build(B, folder, company, helpers, C)
	local desks, lamps, gym, printer = F.desks, F.lamps, F.gym, F.printer
	local pantryCounter, snackSpots, pantryZone = F.pantryCounter, F.snackSpots, F.pantryZone
	local toiletSeats, toiletZone = F.toiletSeats, F.toiletZone
	local meetingSeats, meetingZone = F.meetingSeats, F.meetingZone
	local setClock, storeSpot = F.setClock, F.store
	local GYM_X, GYM_HX, GYM_HZ, GYM_Z = F.gymRect.cx, F.gymRect.hx, F.gymRect.hz, F.gymRect.cz

	---------------------------------------------------------------- 🌳 1층 잔디 공원 (출입문 밖, z -43 ~ -96)
	-- 📐 건물이 앞쪽으로 12칸 커져서 공원·스트리트도 통째로 12칸 앞(-Z)으로 옮겼어요
	local PARK_FAR = -96
	local parkCenterZ = (-HD - 1 + PARK_FAR) / 2
	local parkDepth = -HD - 1 - PARK_FAR
	B:part(Vector3.new(HW * 2 + 2, 1, parkDepth), Vector3.new(0, FLOOR_Y - 0.5, parkCenterZ), { Color = TC.grass, Material = Enum.Material.Grass })
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
	local outsideSign = B:part(Vector3.new(22, 2.6, 0.4), v(0, 13.6, -HD - 2.2), { Color = Color3.fromRGB(30, 35, 45), CanCollide = false }) -- (통유리 벽 앞으로 뺐어요)
	Build.surfaceText(outsideSign, Enum.NormalId.Front, "👁️ (주)눈치물산 NUNCHI CORP.", {
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.accent,
	})
	-- 밝은 웹툰 오피스 외관: 입구 캐노피와 컬러 밴드로 거대한 흰 벽을 나눠요.
	B:part(Vector3.new(22, 0.7, 6), v(0, 9.2, -HD - 3), { Color = TC.mint, Material = Enum.Material.SmoothPlastic })
	B:part(Vector3.new(18, 0.2, 5.4), v(0, 8.8, -HD - 3), { Color = TC.skySoft, Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false })
	for _, x in { -9, 9 } do
		B:part(Vector3.new(0.7, 8, 0.7), v(x, 4, -HD - 4.5), { Color = TC.surface, Material = Enum.Material.Metal })
		B:part(Vector3.new(2.6, 1.2, 2.6), v(x, 0.6, -HD - 5.5), { Color = TC.wood, Material = Enum.Material.WoodPlanks })
		B:part(Vector3.new(3.2, 2.2, 3.2), v(x, 2.2, -HD - 5.5), { Shape = Enum.PartType.Ball, Color = TC.grass, Material = Enum.Material.Grass, CanCollide = false })
	end
	-- 🏢 신축 사옥 외관: 1층(사무실) 위로 유리 타워가 올라가요. 공원이 온통 그늘지지 않게 그림자는 꺼 둬요.
	local TOWER_BASE, TOWER_H = 23.6, 68
	local towerGlass = Color3.fromRGB(138, 166, 188)
	local tower = B:part(Vector3.new(HW * 2 + 2, TOWER_H, HD * 2 + 2), v(0, TOWER_BASE + TOWER_H / 2, 0), { Color = towerGlass, Material = Enum.Material.Glass, Reflectance = 0.15, CastShadow = false })
	local _ = tower
	local steel = { Color = Color3.fromRGB(52, 56, 62), Material = Enum.Material.Metal, CanCollide = false, CanQuery = false, CastShadow = false }
	for y = TOWER_BASE, TOWER_BASE + TOWER_H, 11 do -- 층 사이 띠
		B:part(Vector3.new(HW * 2 + 2.6, 1, 0.5), v(0, y, -HD - 1.2), steel)
	end
	for x = -HW, HW, 12 do -- 세로 창틀
		B:part(Vector3.new(0.5, TOWER_H, 0.4), v(x, TOWER_BASE + TOWER_H / 2, -HD - 1.2), steel)
	end
	B:part(Vector3.new(HW * 2 + 3, 2.4, HD * 2 + 3), v(0, TOWER_BASE + TOWER_H + 1.2, 0), { Color = Color3.fromRGB(226, 226, 222), Material = Enum.Material.Concrete, CastShadow = false }) -- 옥상 테두리
	local towerLogo = B:part(Vector3.new(30, 5, 0.5), v(0, TOWER_BASE + TOWER_H - 6, -HD - 1.5), { Color = Color3.fromRGB(30, 35, 45), CanCollide = false, CastShadow = false })
	Build.surfaceText(towerLogo, Enum.NormalId.Front, "NUNCHI CORP.", { Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1) })
	-- 산책길과 분수: 중앙 길에 작은 광장을 더해 넓은 잔디가 비어 보이지 않게 해요.
	B:part(Vector3.new(8, 0.1, 28), v(0, 0.05, -57), { Color = Color3.fromRGB(236, 222, 199), Material = Enum.Material.Pavement, CanCollide = false })
	B:part(Vector3.new(28, 0.1, 8), v(0, 0.055, -72), { Color = Color3.fromRGB(236, 222, 199), Material = Enum.Material.Pavement, CanCollide = false })
	-- ⛲ 분수 광장 (공원 A안): 원형 광장 + 메시 분수. 메시가 없으면 예전 파트 분수예요.
	local parkMesh = Meshes.ready("Fountain", "Tree", "Bench", "LampPost", "FlowerBed", "Stall", "Parasol")
	B:part(Vector3.new(0.12, 24, 24), nil, { CFrame = CFrame.new(v(0, 0.07, -72)) * CFrame.Angles(0, 0, math.rad(90)), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(233, 226, 214), Material = Enum.Material.Pavement, CanCollide = false })
	if parkMesh then
		Meshes.place(B, "Fountain", v(0, 0, -72), 0, { scale = 1.4 })
		B:part(Vector3.new(1.4, 10.6, 10.6), nil, { CFrame = CFrame.new(v(0, 0.7, -72)) * CFrame.Angles(0, 0, math.rad(90)), Shape = Enum.PartType.Cylinder, Transparency = 1 })
		-- 줄무늬 매대와 파라솔 테이블 (지나다닐 수 있어요)
		Meshes.place(B, "Stall", v(-50, 0, -80), 90)
		Meshes.place(B, "Parasol", v(50, 0, -57), 0)
	else
		B:part(Vector3.new(1.1, 11, 11), nil, { CFrame = CFrame.new(v(0, 0.55, -72)) * CFrame.Angles(0, 0, math.rad(90)), Shape = Enum.PartType.Cylinder, Color = TC.surface, Material = Enum.Material.Marble })
		B:part(Vector3.new(0.25, 9.4, 9.4), nil, { CFrame = CFrame.new(v(0, 1.2, -72)) * CFrame.Angles(0, 0, math.rad(90)), Shape = Enum.PartType.Cylinder, Color = TC.sky, Material = Enum.Material.Glass, Transparency = 0.12, CanCollide = false })
		B:part(Vector3.new(1.1, 3.6, 3.6), nil, { CFrame = CFrame.new(v(0, 1.85, -72)) * CFrame.Angles(0, 0, math.rad(90)), Shape = Enum.PartType.Cylinder, Color = TC.woodLight, Material = Enum.Material.Marble })
		B:part(Vector3.new(2.5, 0.8, 2.5), v(0, 3.1, -72), { Color = TC.surfaceSoft, Material = Enum.Material.Marble })
		B:part(Vector3.new(0.35, 4.6, 4.6), nil, { CFrame = CFrame.new(v(0, 3.65, -72)) * CFrame.Angles(0, 0, math.rad(90)), Shape = Enum.PartType.Cylinder, Color = TC.sky, Material = Enum.Material.Glass, Transparency = 0.15, CanCollide = false })
		for _, offset in { Vector3.new(1.45, 4.4, 0), Vector3.new(-1.45, 4.4, 0), Vector3.new(0, 4.4, 1.45), Vector3.new(0, 4.4, -1.45) } do
			B:part(Vector3.new(0.22, 2.4, 0.22), v(offset.X, offset.Y, -72 + offset.Z), { Color = TC.sky, Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false })
		end
	end
	-- 낮은 꽃 띠와 컬러 포인트. 충돌을 끄고 주요 이동 경로는 비워 둬요.
	for _, info in { { -20, -52, TC.coral }, { 20, -52, TC.yellow }, { -22, -88, TC.sky }, { 22, -88, TC.coral } } do
		local x, z, color = info[1], info[2], info[3]
		if parkMesh then
			Meshes.place(B, "FlowerBed", v(x, 0, z), 0, { scale = 1.3, colors = { Flowercoral = color } })
			continue
		end
		B:part(Vector3.new(10, 0.35, 3), v(x, 0.18, z), { Color = TC.woodLight, Material = Enum.Material.WoodPlanks, CanCollide = false })
		for dx = -3, 3, 2 do
			B:part(Vector3.new(1.1, 1.1, 1.1), v(x + dx, 0.8, z), { Shape = Enum.PartType.Ball, Color = color, Material = Enum.Material.Grass, CanCollide = false })
		end
	end
	-- 나무: 한 덩어리 구 대신 높이가 다른 잎 덩어리를 겹쳐 웹툰식 실루엣을 만들어요.
	for _, xz in { { -40, -52 }, { -44, -70 }, { -36, -88 }, { 40, -52 }, { -22, -82 }, { 20, -58 }, { -24, -60 }, { 14, -88 }, { 46, -64 }, { -10, -92 }, { -62, -62 }, { 62, -58 }, { -60, -88 }, { 60, -90 } } do
		if parkMesh then
			Meshes.place(B, "Tree", v(xz[1], 0, xz[2]), (xz[1] * 37 + xz[2] * 11) % 360, { scale = 1.5 + ((xz[1] + xz[2]) % 3) * 0.12 })
			B:part(Vector3.new(1.6, 6, 1.6), v(xz[1], 3, xz[2]), { Transparency = 1 })
			continue
		end
		B:part(Vector3.new(1.6, 8, 1.6), v(xz[1], 4, xz[2]), { Color = Color3.fromRGB(110, 75, 45), Material = Enum.Material.Wood })
		for _, leaf in { { 0, 0, 0, 6.8 }, { -2.2, -0.4, 0.4, 4.8 }, { 2.1, -0.2, -0.5, 5.2 }, { 0.2, 1.8, 0.2, 4.6 } } do
			B:part(Vector3.new(leaf[4], leaf[4], leaf[4]), v(xz[1] + leaf[1], 9.2 + leaf[2], xz[2] + leaf[3]), {
				Shape = Enum.PartType.Ball,
				Color = if leaf[1] > 0 then Color3.fromRGB(112, 190, 117) else Color3.fromRGB(80, 163, 96),
				Material = Enum.Material.Grass,
				CanCollide = false,
			})
		end
	end
	-- 곡선 슬랫 벤치: 작은 판을 호처럼 배열해 통짜 상자와 전혀 다른 윤곽을 만들어요.
	for _, side in { -1, 1 } do
		local centerX = side * 10
		if parkMesh then
			Meshes.place(B, "Bench", v(centerX, 0, -62), -side * 90, { scale = 1.4 })
			B:part(Vector3.new(2, 1.9, 5.8), v(centerX, 0.95, -62), { Transparency = 1 })
			continue
		end
		for segment = -3, 3 do
			local dz = segment * 0.85
			local curve = math.abs(segment) * 0.16
			local yaw = math.rad(-side * segment * 5)
			B:part(Vector3.new(2.2, 0.24, 1.05), nil, {
				CFrame = CFrame.new(v(centerX + side * curve, 1.55, -62 + dz)) * CFrame.Angles(0, yaw, 0),
				Color = TC.wood,
				Material = Enum.Material.WoodPlanks,
			})
			B:part(Vector3.new(0.28, 1.05, 1.02), nil, {
				CFrame = CFrame.new(v(centerX + side * (1.08 + curve), 2.2, -62 + dz)) * CFrame.Angles(0, yaw, math.rad(-side * 8)),
				Color = TC.woodLight,
				Material = Enum.Material.WoodPlanks,
			})
		end
		for _, dz in { -2.1, 2.1 } do
			B:part(Vector3.new(1.8, 1.4, 0.28), v(centerX, 0.72, -62 + dz), { Color = TC.navy, Material = Enum.Material.Metal })
			B:part(Vector3.new(0.55, 0.28, 0.7), v(centerX - side * 0.55, 0.14, -62 + dz), { Color = TC.navy, Material = Enum.Material.Metal })
		end
	end
	-- 가로등
	for _, xz in { { -16, -52 }, { 16, -52 }, { -16, -82 }, { 16, -82 } } do
		if parkMesh then
			local post = Meshes.place(B, "LampPost", v(xz[1], 0, xz[2]), 0, { scale = 1.6 })
			local glow = Instance.new("PointLight")
			glow.Range = 18
			glow.Brightness = 0.6
			glow.Parent = post.Bulb
			B:part(Vector3.new(0.6, 9, 0.6), v(xz[1], 4.5, xz[2]), { Transparency = 1 })
			continue
		end
		B:part(Vector3.new(0.5, 9, 0.5), v(xz[1], 4.5, xz[2]), { Color = Color3.fromRGB(40, 40, 45), Material = Enum.Material.Metal })
		local bulb = B:part(Vector3.new(1.2, 1.2, 1.2), v(xz[1], 9.4, xz[2]), { Shape = Enum.PartType.Ball, Color = Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon })
		local light = Instance.new("PointLight")
		light.Range = 18
		light.Brightness = 0.6
		light.Parent = bulb
	end

	-- 🌷 내 공원 화단 6곳 (8×5칸, 돌 테두리): 꽃은 각자 화면에 "내 것"으로 그려져요 (ParkGarden 모듈)
	--   나무·벤치·분수·가로등·회식 테이블·흡연구역·경비실·경비원 순찰 지점·돌길을 피해서 놓았어요
	--   ① 왼쪽 나무 사이 (-32,-62) ② 오른쪽 나무 사이 (32,-62) ③④ 건물 앞 양쪽 구석 (±58,-48) ⑤⑥ 양옆 울타리 쪽 (±60,-76)
	local parkBeds = {}
	for _, xz in { { -32, -62 }, { 32, -62 }, { -58, -48 }, { 58, -48 }, { -60, -76 }, { 60, -76 } } do
		local x, z = xz[1], xz[2]
		local stone = { Color = Color3.fromRGB(170, 160, 145), Material = Enum.Material.Cobblestone }
		for _, side in { -1, 1 } do
			B:part(Vector3.new(8, 0.7, 0.6), v(x, 0.35, z + side * 2.2), stone) -- 앞뒤 테두리
			B:part(Vector3.new(0.6, 0.7, 3.8), v(x + side * 3.7, 0.35, z), stone) -- 양옆 테두리
		end
		for _, dx in { -3.7, 3.7 } do -- 모서리 나무 기둥
			for _, dz in { -2.2, 2.2 } do
				B:part(Vector3.new(0.8, 0.9, 0.8), v(x + dx, 0.45, z + dz), { Color = C.wood, Material = Enum.Material.Wood })
			end
		end
		local soil = B:part(Vector3.new(6.8, 0.5, 3.8), v(x, 0.25, z), { Name = "ParkBed", Color = Color3.fromRGB(105, 75, 50), Material = Enum.Material.Ground })
		table.insert(parkBeds, soil)
	end
	-- 안내판 (출입문 오른쪽 옆, 워크숍 결승선보다 뒤라 길을 안 막아요)
	B:part(Vector3.new(0.3, 3, 0.3), v(9, 1.5, -44.5), { Color = C.darkWood, Material = Enum.Material.Wood })
	local parkSign = B:part(Vector3.new(3.6, 1.6, 0.25), v(9, 3.4, -44.5), { Color = Color3.fromRGB(245, 235, 210), Material = Enum.Material.Wood })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		Build.surfaceText(parkSign, face, "🌷 내 공원 화단 [E]", { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 70, 110) })
	end

	-- 🍻 회식 테이블 (공원 왼쪽): 긴 식탁 + 양쪽 벤치 의자 8개 + 가운데 불판
	local dinnerX, dinnerZ = -30, -74
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
	local candyX, candyZ = 40, -84
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

	---------------------------------------------------------------- 🏙️ 눈치 스트리트 (공원 정문 밖 상가 거리, z -96 ~ -144)
	local STREET_FAR = -144
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
	B:part(Vector3.new(HW * 2 + 2, 0.1, 14), v(0, 0.05, -112), { Color = Color3.fromRGB(55, 55, 60), Material = Enum.Material.Asphalt, CanCollide = false })
	for x = -66, 66, 8 do -- 차선
		B:part(Vector3.new(4, 0.12, 0.4), v(x, 0.07, -112), { Color = Color3.fromRGB(240, 210, 80), CanCollide = false })
	end
	for x = -4, 4, 2 do -- 정문 앞 횡단보도
		B:part(Vector3.new(1, 0.13, 13), v(x, 0.07, -112), { Color = Color3.fromRGB(245, 245, 245), CanCollide = false })
	end
	-- 거리 양옆과 뒤는 높은 건물 벽 (밖으로 못 나가요)
	for _, info in {
		{ Vector3.new(1, 16, streetDepth), v(-HW - 0.5, 8, streetCenterZ) },
		{ Vector3.new(1, 16, streetDepth), v(HW + 0.5, 8, streetCenterZ) },
		{ Vector3.new(HW * 2 + 2, 16, 1), v(0, 8, STREET_FAR - 0.5) },
	} do
		B:part(info[1], info[2], { Color = TC.cream, Material = Enum.Material.Brick })
		B:part(Vector3.new(info[1].X, 30, info[1].Z), info[2] + Vector3.new(0, 23, 0), { Transparency = 1 })
	end
	-- 🏬 가게 위층과 거리 양옆 건물: 낮은 담장 대신 실제 상가 거리처럼 보이게 (그림자는 꺼 둬요)
	local facade = { Color = Color3.fromRGB(198, 190, 174), Material = Enum.Material.Concrete, CastShadow = false }
	local window = { Color = Color3.fromRGB(120, 150, 172), Material = Enum.Material.Glass, CanCollide = false, CanQuery = false, CastShadow = false }
	B:part(Vector3.new(HW * 2 + 2, 34, 18), v(0, 13 + 17, STREET_FAR + 9), facade) -- 가게 위층 (2~4층)
	for floor = 0, 2 do
		for x = -60, 60, 12 do
			B:part(Vector3.new(8, 6, 0.3), v(x, 19 + floor * 10, STREET_FAR + 18.1), window)
		end
		B:part(Vector3.new(HW * 2 + 2.4, 0.8, 0.5), v(0, 14.4 + floor * 10, STREET_FAR + 18.2), { Color = Color3.fromRGB(150, 142, 128), Material = Enum.Material.Concrete, CanCollide = false, CastShadow = false })
	end
	for _, side in { -1, 1 } do
		B:part(Vector3.new(20, 56, streetDepth), v(side * (HW + 11), 28, streetCenterZ), { Color = if side < 0 then Color3.fromRGB(176, 170, 160) else Color3.fromRGB(160, 168, 176), Material = Enum.Material.Concrete, CastShadow = false })
		for y = 22, 50, 9 do
			B:part(Vector3.new(0.3, 5, streetDepth * 0.82), v(side * (HW + 0.9), y, streetCenterZ), window)
		end
	end
	-- 막힌 뒷벽을 상가 파사드처럼 보이게 하는 창과 컬러 패널
	for x = -60, 60, 15 do
		B:part(Vector3.new(10, 5, 0.25), v(x, 9, STREET_FAR), { Color = TC.skySoft, Material = Enum.Material.Glass, Transparency = 0.25, CanCollide = false })
		B:part(Vector3.new(11, 0.7, 0.35), v(x, 13, STREET_FAR + 0.05), { Color = if x % 30 == 0 then TC.coral else TC.mint, CanCollide = false })
	end
	-- 가로등
	for x = -60, 60, 20 do
		B:part(Vector3.new(0.5, 9, 0.5), v(x, 4.5, -103), { Color = Color3.fromRGB(40, 40, 45), Material = Enum.Material.Metal })
		local bulb = B:part(Vector3.new(1.2, 1.2, 1.2), v(x, 9.4, -103), { Shape = Enum.PartType.Ball, Color = Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon })
		local light = Instance.new("PointLight")
		light.Range = 18
		light.Brightness = 0.6
		light.Parent = bulb
	end

	-- 가게 건물 (뒤쪽에 4칸, 앞이 뚫려 있어 거리 쪽을 봐요)
	local SHOP_FRONT, SHOP_BACK = -126, STREET_FAR
	local shops = {}
	local function shopBuilding(cx: number, title: string, wallColor: Color3, awning: Color3, noCounter: boolean?): BasePart?
		local depth = SHOP_FRONT - SHOP_BACK
		local cz = (SHOP_FRONT + SHOP_BACK) / 2
		B:part(Vector3.new(22, 12, 1), v(cx, 6, SHOP_BACK + 0.5), { Color = wallColor, Material = Enum.Material.Plaster }) -- 뒷벽
		for _, dx in { -11, 11 } do
			B:part(Vector3.new(1, 12, depth), v(cx + dx, 6, cz), { Color = wallColor, Material = Enum.Material.Plaster }) -- 옆벽
		end
		B:part(Vector3.new(23, 1, depth + 1), v(cx, 12.5, cz), { Color = wallColor }) -- 지붕
		-- 가게 안 천장 조명: 지붕과 위층 건물에 가려 햇빛이 안 들어서, 조명이 없으면 안이 캄캄해요
		for _, dx in { -5.5, 5.5 } do
			for _, dz in { -4, 4 } do
				local lamp = B:part(Vector3.new(4, 0.25, 1.2), v(cx + dx, 11.85, cz + dz), { Color = Color3.fromRGB(240, 238, 228), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
				local light = Instance.new("PointLight")
				light.Range = 22
				light.Brightness = 1.1
				light.Color = Color3.fromRGB(255, 246, 228)
				light.Shadows = false
				light.Parent = lamp
			end
		end
		B:part(Vector3.new(21, 0.1, depth - 1), v(cx, 0.08, cz), { Color = Color3.fromRGB(235, 225, 210), Material = Enum.Material.WoodPlanks, CanCollide = false })
		B:part(Vector3.new(23, 0.4, 4), v(cx, 9.4, SHOP_FRONT - 1.6), { Color = awning, Material = Enum.Material.Fabric, Orientation = Vector3.new(-15, 0, 0) }) -- 차양
		local sign = B:part(Vector3.new(16, 2, 0.4), v(cx, 11, SHOP_FRONT + 0.3), { Color = Color3.fromRGB(35, 30, 30) })
		Build.surfaceText(sign, Enum.NormalId.Front, title, { Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 235, 200) })
		if noCounter then
			return nil
		end
		-- 계산대 (가운데 안쪽)
		local counter = B:part(Vector3.new(10, 3.5, 2), v(cx, 1.75, -136), { Name = "ShopCounter", Color = Color3.fromRGB(120, 85, 60), Material = Enum.Material.Wood })
		return counter
	end

	-- ☕ 눈치 커피
	local cafeCounter = shopBuilding(-39, "☕ 눈치 커피", TC.mintSoft, TC.mint)
	B:part(Vector3.new(1.4, 2, 1.4), v(-42, 4.5, -136), { Color = Color3.fromRGB(190, 190, 195), Material = Enum.Material.Metal }) -- 커피머신
	B:part(Vector3.new(8, 3, 0.4), v(-39, 6.5, -143), { Color = Color3.fromRGB(30, 30, 30) }) -- 메뉴판
	for _, dx in { -6, 6 } do -- 손님 테이블
		B:part(Vector3.new(3, 0.3, 3), v(-39 + dx, 2.6, -130), { Color = Color3.fromRGB(240, 240, 235) })
		B:part(Vector3.new(0.4, 2.5, 0.4), v(-39 + dx, 1.25, -130), { Color = Color3.fromRGB(40, 40, 45) })
	end
	shops.cafe = { counter = cafeCounter, clerkSpot = v(-39, 0, -139) }

	-- 🍰 달콤 디저트
	local dessertCounter = shopBuilding(-13, "🍰 달콤 디저트", TC.coralSoft, TC.coral)
	B:part(Vector3.new(6, 1.6, 1.6), v(-13, 4.3, -136), { Color = Color3.fromRGB(220, 240, 250), Material = Enum.Material.Glass, Transparency = 0.4 }) -- 진열장
	for i, color in { Color3.fromRGB(255, 170, 200), Color3.fromRGB(180, 230, 170), Color3.fromRGB(220, 160, 80), Color3.fromRGB(255, 240, 240), Color3.fromRGB(190, 170, 255) } do
		B:part(Vector3.new(0.7, 0.5, 0.7), v(-15.6 + i * 0.9, 3.9, -136), { Color = color, CanCollide = false })
	end
	shops.dessert = { counter = dessertCounter, clerkSpot = v(-13, 0, -139) }

	-- 🧸 뽑기 가게: 인형뽑기 1대 + 🎡 다 같이 돌림판 + 🎯 풍선 다트
	shopBuilding(13, "🧸 뽑기 천국", TC.yellowSoft, TC.yellow, true)
	local clawMachines = {}
	do
		local mx, mz = 5.2, -137
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
		CFrame = CFrame.new(v(wheelX, 6.6, -143.1)) * CFrame.Angles(0, math.rad(90), 0), -- 원판 면이 가게 앞쪽(+Z)을 봐요
		Color = Color3.fromRGB(40, 40, 50),
	})
	B:part(Vector3.new(0.8, 1.2, 0.8), v(wheelX, 11.5, -142.6), { Color = Color3.fromRGB(230, 50, 50), Material = Enum.Material.Neon }) -- ▼ 바늘
	local wheelKiosk = B:part(Vector3.new(5, 3.5, 1.6), v(wheelX, 1.75, -137.5), { Name = "WheelKiosk", Color = Color3.fromRGB(250, 200, 80) })
	local wheelSign = B:part(Vector3.new(5, 0.9, 0.2), v(wheelX, 4, -136.6), { Color = Color3.fromRGB(30, 30, 40) })
	Build.surfaceText(wheelSign, Enum.NormalId.Front, "🎡 다 같이 돌림판", { Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 230, 120) })

	-- 🎯 풍선 다트 벽 (뒷벽 오른쪽): 창 속 풍선 자리(DART_SLOTS) 그대로 알록달록 풍선 장식 (실제 경품은 창에서 서버가 섞어요)
	local dartX = 19.8
	local dartBoard = B:part(Vector3.new(6.2, 5, 0.4), v(dartX, 6.2, -143.1), { Name = "DartBoard", Color = Color3.fromRGB(165, 220, 255), Material = Enum.Material.Wood })
	local balloonColors = {}
	for _, info in SalaryConfig.DartPrizes do
		table.insert(balloonColors, info.color)
	end
	for i, slot in SalaryConfig.DART_SLOTS do
		local x = dartX - 2.8 + slot.x / SalaryConfig.DART_FIELD_W * 5.6
		local y = 8.4 - (slot.y - 40) / 150 * 3.6
		B:part(Vector3.new(0.85, 0.95, 0.8), v(x, y, -142.6), {
			Shape = Enum.PartType.Ball,
			Color = balloonColors[i % #balloonColors + 1],
			CanCollide = false,
		})
		B:part(Vector3.new(0.05, 0.6, 0.05), v(x, y - 0.75, -142.75), { Color = Color3.fromRGB(110, 110, 120), CanCollide = false }) -- 풍선 끈
	end
	local dartCounter = B:part(Vector3.new(5, 3.5, 1.6), v(dartX, 1.75, -137.5), { Name = "DartCounter", Color = Color3.fromRGB(120, 200, 255) })
	local dartSign = B:part(Vector3.new(5, 0.9, 0.2), v(dartX, 4, -136.6), { Color = Color3.fromRGB(30, 30, 40) })
	Build.surfaceText(dartSign, Enum.NormalId.Front, "🎯 풍선 다트", { Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 230, 120) })

	-- 🕹️ 오락실: 게임기 2대 + 경품 교환대 + 최고 기록판
	shopBuilding(39, "🕹️ 오락실", Color3.fromRGB(60, 60, 110), Color3.fromRGB(150, 80, 230), true)
	B:part(Vector3.new(21, 0.12, 17), v(39, 0.1, -135), { Color = Color3.fromRGB(40, 30, 70), Material = Enum.Material.Carpet, CanCollide = false })
	local arcade = { machines = {} :: { [string]: BasePart } }
	for _, info in { { "mole", 33, "🔨 두더지 잡기", Color3.fromRGB(230, 90, 60) }, { "memory", 39, "🃏 카드 짝 맞추기", Color3.fromRGB(60, 170, 230) } } do
		local gameId, mx = info[1], info[2]
		local cabinet = B:part(Vector3.new(3.2, 6, 2.6), v(mx, 3, -138.5), { Name = "ArcadeMachine", Color = info[4] })
		B:part(Vector3.new(2.6, 2, 0.1), v(mx, 4.2, -137.15), { Color = Color3.fromRGB(120, 255, 200), Material = Enum.Material.Neon })
		B:part(Vector3.new(3.2, 0.3, 1.2), v(mx, 2.9, -136.8), { Color = Color3.fromRGB(40, 40, 45) }) -- 조작판
		local title = B:part(Vector3.new(3.2, 0.9, 0.2), v(mx, 6.5, -137.1), { Color = Color3.fromRGB(30, 30, 40) })
		Build.surfaceText(title, Enum.NormalId.Front, info[3], { Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 230, 120) })
		arcade.machines[gameId] = cabinet
	end
	-- 경품 교환대 (오른쪽) + 뒤쪽 선반의 경품들
	arcade.prizeCounter = B:part(Vector3.new(4.5, 3.5, 2), v(46, 1.75, -136), { Name = "PrizeCounter", Color = Color3.fromRGB(250, 200, 80) })
	local prizeSign = B:part(Vector3.new(4.5, 0.9, 0.2), v(46, 4, -134.9), { Color = Color3.fromRGB(30, 30, 40) })
	Build.surfaceText(prizeSign, Enum.NormalId.Front, "🎟️ 경품 교환", { Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 230, 120) })
	B:part(Vector3.new(5, 0.3, 1.5), v(46, 5, -141.5), { Color = Color3.fromRGB(120, 85, 60) }) -- 선반
	for i, plush in { SalaryConfig.Plushies[1], SalaryConfig.Plushies[8], SalaryConfig.Plushies[10] } do
		B:part(Vector3.new(0.9, 0.9, 0.9), v(44.5 + (i - 1) * 1.5, 5.6, -141.5), { Shape = Enum.PartType.Ball, Color = plush.color, CanCollide = false })
	end
	-- 🏆 최고 기록판 (뒷벽, 서버가 글씨를 채워요)
	arcade.board = B:part(Vector3.new(12, 4.5, 0.3), v(36, 9, -142.8), { Name = "ArcadeBoard", Color = Color3.fromRGB(20, 20, 30) })

	---------------------------------------------------------------- 🚒 집결지(=🏁 워크숍 결승선)와 시작 지점
	-- 소방 훈련 때는 건물 밖 공원으로 대피해요
	local assemblyZone, assemblyPoint, setAssemblyVisible = helpers.makeAssembly(B, 0, -HD - 9)

	shops.store = storeSpot -- 🏪 사내 매점 (뒤쪽 오른쪽 방)
	-- 📦 택배 상자 · 택배 보관함 · 🚪 엘리베이터 · 시작 지점은 건물 안이라 OfficeNunchiFloor가 지었어요
	local packageBox, deliveryShelf, elevator = F.packageBox, F.deliveryShelf, F.elevator

	-- 부장 순찰 지점 (복도) — 책상 열 사이(x ±12), 책상 줄 사이(z -8), 바깥 통로(x ±36), 창가(z -30)
	local waypoints = table.clone(F.waypoints) -- 건물 안 지점 + 아래 바깥 지점
	for _, point in {
		v(0, 0, -56), -- 🌳 공원 (가끔 나가 봐요)
		v(28, 0, -76), -- 흡연구역 근처
		v(-20, 0, -112), -- 🏙️ 눈치 스트리트 (근무 중 외출 감시!)
		v(20, 0, -112),
	} do
		table.insert(waypoints, point)
	end
	local spots = table.clone(F.spots)
	table.insert(spots, v(-6, 0, -60)) -- 공원
	local packageSpots = table.clone(F.packageSpots)
	table.insert(packageSpots, v(0, 0, -62)) -- 공원

	return {
		folder = folder,
		desks = desks,
		bossStand = F.bossStand,
		bossScale = F.bossScale,
		bossLook = Vector3.new(0, 0, -1),
		entrance = F.entrance,
		waypoints = waypoints,
		toiletZone = toiletZone,
		pantryZone = pantryZone,
		printer = printer,
		pantryCounter = pantryCounter,
		snackSpots = snackSpots,
		spots = spots,
		toiletSeats = toiletSeats,
		meetingSeats = meetingSeats,
		meetingZone = meetingZone,
		gymSeats = gym.seats, -- 🏋️ 체력 단련실
		gymZone = gym.zone,
		companyId = company.id,
		lamps = lamps,
		assemblyZone = assemblyZone,
		assemblyPoint = assemblyPoint,
		setAssemblyVisible = setAssemblyVisible,
		cakeSpots = F.cakeSpots,
		workshopStart = v(0, 0, PARK_FAR + 6), -- 🌸 공원 맨 끝에서 출발
		-- 👮 경비원: 경비실 앞(정문 옆) + 공원·거리 순찰 지점 (나무·벤치·분수·회식 테이블·흡연구역을 피해서)
		guardPost = v(26, 0, -87.5),
		-- 🛍️ 눈치 스트리트 위에 있나 (공원 정문 밖 거리, 가게 안 포함)
		inStreet = function(position: Vector3): boolean
			return position.Z < PARK_FAR - 0.5 and position.Z > STREET_FAR - 1 and math.abs(position.X) <= HW + 1 and position.Y < FLOOR_Y + 20 and position.Y > FLOOR_Y - 10
		end,
		guardPatrol = {
			v(0, 0, -50), v(-28, 0, -50), v(30, 0, -48), v(-52, 0, -56), v(-50, 0, -78), v(-14, 0, -72),
			v(20, 0, -72), v(52, 0, -72), v(10, 0, -84),
			v(-40, 0, -104), v(0, 0, -104), v(40, 0, -104), v(-30, 0, -120), v(30, 0, -120),
		},
		workshopBoss = v(0, 0, -HD - 4), -- 부장님은 건물 출입문 바로 앞에서 술래
		workshopLook = Vector3.new(0, 0, -1), -- 술래가 직원들을 볼 때 방향 (공원 쪽)
		candyZone = candyZone,
		shops = shops, -- 🏙️ 눈치 스트리트 가게들 + 🏪 사내 매점 (계산대, 사장님 자리)
		packageBox = packageBox,
		deliveryShelf = deliveryShelf,
		elevator = elevator,
		insideOffice = function(position: Vector3): boolean
			-- 건물 안만 (출입문 밖 공원·눈치 스트리트, 하늘 위 옥상은 밖)
			if position.Y >= FLOOR_Y + 20 then
				return false
			end
			if math.abs(position.X) <= HW + 1 and position.Z >= -HD - 0.5 and position.Z <= HD + 1 then
				return true
			end
			-- 🏋️ 체력 단련실 별관도 건물 안
			return math.abs(position.X - GYM_X) <= GYM_HX + 1 and position.Z > HD and position.Z <= GYM_Z + GYM_HZ + 1
		end,
		packageSpots = packageSpots,
		clawMachines = clawMachines, -- 🧸 인형뽑기 기계
		wheel = { disc = wheelDisc, kiosk = wheelKiosk }, -- 🎡 다 같이 돌림판
		dart = { board = dartBoard, counter = dartCounter }, -- 🎯 풍선 다트
		arcade = arcade, -- 🕹️ 오락실 (게임기, 경품 교환대, 기록판)
		dinnerSeats = dinnerSeats, -- 🍻 회식은 공원 식탁에서
		parkBeds = parkBeds, -- 🌷 내 공원 화단 (흙 Part 6개)
		dinnerBoss = v(dinnerX - 7.6, 0, dinnerZ), -- 부장님은 식탁 끝 상석
		dinnerLook = Vector3.new(1, 0, 0),
		setClock = setClock,
	}
end

return OfficeNunchi
