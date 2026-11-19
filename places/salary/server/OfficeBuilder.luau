-- 사무실 짓기 (위에서 본 모습, 위쪽이 창문 쪽 -Z)
--
--   ┌──────────── 창문 · 사훈 · 벽시계 ────────────┐
--   │                 [출입문]                      │
--   │    [책상1]      [책상2]      [책상3]          │  ← 직원들은 창문 쪽을 보고 앉아요
--   │      🪑           🪑           🪑             │
--   │    [책상4]      [책상5]      [책상6]          │     (플레이어는 보통 5번)
--   │      🪑           🪑           🪑             │
--   ├──────┐                             ┌─────────┤
--   │화장실 │        [김부장 자리]         │ 탕비실   │  ← 부장은 직원들 등 뒤에 앉아요
--   └──────┴─────────────────────────────┴─────────┘

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Build = require(ReplicatedStorage.Shared.Build)
local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local OfficeNunchi = require(script.Parent.OfficeNunchi)

local OfficeBuilder = {}

local FLOOR_Y = 1 -- 바닥 윗면 높이
local WALL_HEIGHT = 12
local HALF_WIDTH = 38 -- 사무실 가로 절반 (벽 안쪽)

local COLORS = {
	floor = Color3.fromRGB(150, 150, 155),
	wall = Color3.fromRGB(235, 232, 225),
	desk = Color3.fromRGB(200, 180, 150),
	partition = Color3.fromRGB(120, 140, 160),
	chair = Color3.fromRGB(40, 40, 45),
	monitor = Color3.fromRGB(25, 25, 30),
	screen = Color3.fromRGB(90, 150, 220),
	tile = Color3.fromRGB(210, 225, 230),
	accent = Color3.fromRGB(230, 120, 60),
}

-- 🏢 회사마다 다른 인테리어 (여기 없는 색은 위 기본색을 써요)
--   partitionHeight: 책상 칸막이 높이. 낮을수록 부장님 눈에 잘 띄어요!
local THEMES = {
	daechung = { partitionHeight = 4.5, colors = {} },
	nunchi = {
		partitionHeight = 2.6, -- 요즘 회사는 칸막이가 낮아요 (= 숨기 어려움)
		colors = {
			floor = Color3.fromRGB(75, 85, 100),
			wall = Color3.fromRGB(245, 246, 248),
			desk = Color3.fromRGB(235, 235, 232),
			partition = Color3.fromRGB(80, 165, 165),
			accent = Color3.fromRGB(40, 160, 170),
		},
	},
}
local partitionHeight = 4.5

export type Desk = {
	index: number,
	model: Model,
	seat: Seat,
	behind: Vector3, -- 부장이 뒤에서 들여다볼 위치
	seatHome: CFrame, -- 의자 원래 위치
}

export type Office = {
	folder: Folder,
	desks: { Desk },
	bossStand: Vector3, -- 부장 자리 (서서 직원들을 내려다보는 곳)
	bossLook: Vector3, -- 부장 자리에서 바라보는 방향
	entrance: Vector3,
	waypoints: { Vector3 },
	toiletZone: BasePart,
	pantryZone: BasePart,
	printer: BasePart,
	pantryCounter: BasePart,
	spots: { Vector3 }, -- 동료들이 들르는 곳 (탕비실, 프린터, 창가)
	snackSpots: { Vector3 }, -- 간식이 놓이는 자리 (테이블 윗면)
	toiletSeats: { Seat }, -- 변기 (앉으면 주식 거래)
	meetingSeats: { Seat }, -- 📊 유리 회의실 의자 (눈치물산만, 없으면 빈 목록)
	meetingZone: BasePart?,
	companyId: string,
	lamps: { BasePart }, -- 형광등 (정전 때 꺼져요)
	assemblyZone: BasePart, -- 🚒 소방 훈련 집결지
	assemblyPoint: Vector3,
	setAssemblyVisible: (boolean) -> (),
	cakeSpots: { Vector3 }, -- 🎂 생일 케이크 조각이 놓이는 곳 (탕비실 조리대)
	workshopStart: Vector3, -- 🌸 무궁화꽃 출발선 가운데 (결승선은 집결지)
	workshopBoss: Vector3, -- 술래(부장님) 자리
	workshopLook: Vector3, -- 술래가 직원들을 볼 때 방향
	candyZone: BasePart?, -- 🍭 흡연구역(사탕) — 눈치물산 공원에만
	shops: { [string]: { counter: BasePart, clerkSpot: Vector3 } }, -- 🏙️ 눈치 스트리트 가게
	clawMachines: { BasePart }, -- 🧸 인형뽑기 기계
	arcade: any?, -- 🕹️ 오락실 (눈치물산만)
	wheel: any?, -- 🎡 돌림판 (눈치물산만)
	dart: any?, -- 🎈 풍선 다트 (눈치물산만)
	dinnerSeats: { Seat }, -- 🍻 회식 자리 (없으면 화면 미니게임만)
	dinnerBoss: Vector3?,
	dinnerLook: Vector3?,
	setClock: (number, number) -> (),
}

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, FLOOR_Y + y, z)
end

local function zone(B, name: string, size: Vector3, position: Vector3): BasePart
	return B:part(size, position, {
		Name = name,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
end

local function buildDesk(B, index: number, x: number, z: number): Desk
	local model = Instance.new("Model")
	model.Name = `Desk{index}`
	model.Parent = B.parent
	local function p(size: Vector3, position: Vector3, props: { [string]: any })
		local options = table.clone(props)
		options.Parent = model
		return B:part(size, position, options)
	end

	p(Vector3.new(6, 2.5, 3), v(x, 1.25, z), { Color = COLORS.desk, Material = Enum.Material.Wood })
	-- 모니터
	p(Vector3.new(2.6, 1.8, 0.3), v(x, 3.6, z - 0.8), { Color = COLORS.monitor })
	local screen = p(Vector3.new(2.3, 1.5, 0.05), v(x, 3.6, z - 0.62), {
		Color = COLORS.screen,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
	})
	screen.Name = "Screen"
	p(Vector3.new(1.6, 0.1, 0.6), v(x, 2.55, z + 0.3), { Color = Color3.fromRGB(60, 60, 60) }) -- 키보드
	-- 파티션 (앞, 양옆)
	local h = partitionHeight
	p(Vector3.new(6.4, h, 0.3), v(x, h / 2, z - 1.7), { Color = COLORS.partition, Material = Enum.Material.Fabric })
	p(Vector3.new(0.3, h, 3.6), v(x - 3.2, h / 2, z), { Color = COLORS.partition, Material = Enum.Material.Fabric })
	p(Vector3.new(0.3, h, 3.6), v(x + 3.2, h / 2, z), { Color = COLORS.partition, Material = Enum.Material.Fabric })

	-- 의자 (Seat: 닿으면 앉아요. 앞쪽(-Z)을 보고 앉음)
	local seat = p(Vector3.new(2, 1, 2), v(x, 1, z + 2.6), {
		ClassName = "Seat",
		Name = "Seat",
		Color = COLORS.chair,
	}) :: Seat
	p(Vector3.new(2, 2.4, 0.3), v(x, 2.7, z + 3.5), { Color = COLORS.chair })

	-- seatHome: 의자 원래 자리 (혹시 밀려나면 되돌려요)
	return { index = index, model = model, seat = seat, seatHome = seat.CFrame, behind = v(x, 0, z + 6.5) }
end

-- 🚒 소방 훈련 집결지 (훈련 때만 초록색으로 보여요). 회사마다 위치만 달라요.
local function makeAssembly(B, x: number, z: number): (BasePart, Vector3, (boolean) -> ())
	local assemblyPoint = v(x, 0, z)
	local assemblyZone = zone(B, "AssemblyZone", Vector3.new(12, 10, 8), v(x, 5, z - 0.5))
	local assemblyMarker = B:part(Vector3.new(12, 0.1, 6), v(x, 0.06, z), {
		Name = "AssemblyMarker",
		Color = Color3.fromRGB(60, 200, 90),
		Material = Enum.Material.Neon,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local assemblyBoard = Instance.new("BillboardGui")
	-- 크기를 칸(stud) 단위로: 멀리서 보면 작아져서 부장님(술래)을 가리지 않아요
	assemblyBoard.Size = UDim2.fromScale(8, 1.8)
	assemblyBoard.StudsOffset = Vector3.new(0, 12, 0) -- 부장님 머리보다 한참 위
	assemblyBoard.AlwaysOnTop = true
	assemblyBoard.Enabled = false
	assemblyBoard.Parent = assemblyMarker
	local assemblyLabel = Instance.new("TextLabel")
	assemblyLabel.Size = UDim2.fromScale(1, 1)
	assemblyLabel.BackgroundColor3 = Color3.fromRGB(40, 150, 70)
	assemblyLabel.TextColor3 = Color3.new(1, 1, 1)
	assemblyLabel.Font = Enum.Font.GothamBlack
	assemblyLabel.TextScaled = true
	assemblyLabel.Text = "🚨 비상 집결지"
	assemblyLabel.Parent = assemblyBoard
	local function setAssemblyVisible(visible: boolean, text: string?)
		assemblyMarker.Transparency = if visible then 0.4 else 1
		assemblyBoard.Enabled = visible
		assemblyLabel.Text = text or "🚨 비상 집결지"
	end
	return assemblyZone, assemblyPoint, setAssemblyVisible :: any
end

function OfficeBuilder.build(companyId: string?): Office
	local company = SalaryConfig.getCompany(companyId or "daechung")
	local theme = THEMES[company.id] or THEMES.daechung
	for key, color in theme.colors do
		COLORS[key] = color
	end
	partitionHeight = theme.partitionHeight
	local old = workspace:FindFirstChild("Office")
	if old then
		old:Destroy()
	end
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") then
			descendant:Destroy()
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = "Office"
	folder.Parent = workspace
	local B = Build.new(folder, Vector3.zero)

	-- 🏙️ 눈치물산은 완전히 다른(더 크고 고급스러운) 사무실이에요 → OfficeNunchi.luau
	if company.id == "nunchi" then
		return OfficeNunchi.build(B, folder, company, {
			v = v,
			zone = zone,
			buildDesk = buildDesk,
			makeAssembly = makeAssembly,
			FLOOR_Y = FLOOR_Y,
		})
	end

	local wall = { Color = COLORS.wall, Material = Enum.Material.Plaster }

	-- 바닥, 천장, 바깥 벽 (가로 76칸: 가운데 사무실 + 양쪽 끝 화장실·탕비실)
	B:part(Vector3.new(HALF_WIDTH * 2 + 2, 1, 46), Vector3.new(0, FLOOR_Y - 0.5, 0), { Color = COLORS.floor, Material = Enum.Material.Carpet })
	B:part(Vector3.new(HALF_WIDTH * 2 + 2, 1, 46), v(0, WALL_HEIGHT + 0.5, 0), { Color = COLORS.wall })
	B:wall("X", -22.5, -HALF_WIDTH - 1, HALF_WIDTH + 1, FLOOR_Y, WALL_HEIGHT, { { center = 0, width = 6, height = 8 } }, wall) -- 앞 (출입문)
	B:wall("X", 22.5, -HALF_WIDTH - 1, HALF_WIDTH + 1, FLOOR_Y, WALL_HEIGHT, nil, wall) -- 뒤
	B:wall("Z", -HALF_WIDTH - 0.5, -22, 22, FLOOR_Y, WALL_HEIGHT, nil, wall) -- 왼쪽
	B:wall("Z", HALF_WIDTH + 0.5, -22, 22, FLOOR_Y, WALL_HEIGHT, nil, wall) -- 오른쪽
	-- 출입문 바깥은 막아 둬요 (나가 버리지 않게)
	B:part(Vector3.new(8, WALL_HEIGHT, 1), v(0, WALL_HEIGHT / 2, -25), wall)
	B:part(Vector3.new(1, WALL_HEIGHT, 3), v(-4, WALL_HEIGHT / 2, -24), wall)
	B:part(Vector3.new(1, WALL_HEIGHT, 3), v(4, WALL_HEIGHT / 2, -24), wall)

	-- 창문 (앞 벽 안쪽에 붙은 유리)
	for _, x in { -32, -22, -12, 12, 22, 32 } do
		B:part(Vector3.new(7, 5, 0.2), v(x, 6, -21.9), {
			Color = Color3.fromRGB(170, 210, 240),
			Material = Enum.Material.Glass,
			Transparency = 0.3,
		})
	end

	-- 사훈 현수막과 벽시계 (직원들이 앉으면 정면에 보여요)
	local banner = B:part(Vector3.new(16, 2.5, 0.2), v(0, 10, -21.85), { Color = Color3.fromRGB(170, 30, 40) })
	Build.surfaceText(banner, Enum.NormalId.Back, company.motto, {
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(255, 230, 120),
	})
	local clockFace = B:part(Vector3.new(3, 3, 0.2), v(-17, 10, -21.85), { Color = COLORS.wall })
	local setClock = Build.clockFace(clockFace, Enum.NormalId.Back)

	-- 직원 책상 6개
	local desks = {}
	local index = 0
	for _, z in { -10, 2 } do
		for _, x in { -12, 0, 12 } do
			index += 1
			table.insert(desks, buildDesk(B, index, x, z))
		end
	end

	-- 김부장 자리 (직원들 등 뒤)
	B:part(Vector3.new(8, 2.5, 3.5), v(0, 1.25, 16), { Color = Color3.fromRGB(110, 70, 40), Material = Enum.Material.Wood })
	local nameplate = B:part(Vector3.new(3, 0.8, 0.4), v(0, 2.9, 14.4), { Color = Color3.fromRGB(40, 30, 20) })
	Build.surfaceText(nameplate, Enum.NormalId.Front, "부장 김부장", {
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(230, 190, 90),
	})
	B:part(Vector3.new(2.6, 1.8, 0.3), v(0, 3.4, 16.8), { Color = COLORS.monitor })
	B:part(Vector3.new(3, 3.5, 3), v(7, 1.75, 20.5), {
		Color = Color3.fromRGB(60, 30, 25),
		Material = Enum.Material.Leather,
		CanCollide = false, -- 부장이 지나다니다 끼지 않게 (장식)
	}) -- 부장 의자

	-- 🚻 화장실 (왼쪽 뒤, x -38~-24 / z 6~22) : 부장이 들어오지 않는 안전지대
	B:wall("Z", -24.5, 6, 22, FLOOR_Y, WALL_HEIGHT, { { center = 10, width = 4, height = 8 } }, wall)
	B:wall("X", 6.5, -HALF_WIDTH, -24, FLOOR_Y, WALL_HEIGHT, nil, wall)
	B:part(Vector3.new(13, 0.2, 15), v(-31.5, 0.1, 14.5), { Color = COLORS.tile, Material = Enum.Material.Marble })
	local toiletSeats = {}
	for i, x in { -35.5, -31.5, -27.5 } do
		-- 칸막이와 문 없는 칸 (안쪽 벽에 붙은 변기)
		if i < 3 then
			B:part(Vector3.new(0.3, 7, 5), v(x + 2, 3.5, 19.5), { Color = Color3.fromRGB(150, 190, 200) })
		end
		B:part(Vector3.new(2.2, 1, 2.6), v(x, 0.5, 20.4), { Color = Color3.fromRGB(245, 245, 245) }) -- 변기 몸통
		B:part(Vector3.new(2.2, 2.4, 0.9), v(x, 1.8, 21.5), { Color = Color3.fromRGB(240, 240, 240) }) -- 물탱크
		local seat = B:part(Vector3.new(2, 0.4, 2), v(x, 1.2, 20.2), {
			ClassName = "Seat",
			Name = "ToiletSeat",
			Color = Color3.fromRGB(250, 250, 250),
		}) :: Seat
		table.insert(toiletSeats, seat)
	end
	-- 세면대
	for _, z in { 9, 12.5 } do
		B:part(Vector3.new(2, 3, 2.5), v(-37, 1.5, z), { Color = Color3.fromRGB(235, 235, 240) })
		B:part(Vector3.new(0.2, 2.5, 2.2), v(-37.9, 5, z), { Color = Color3.fromRGB(190, 220, 235), Material = Enum.Material.Glass }) -- 거울
	end
	local toiletSign = B:part(Vector3.new(0.2, 1.5, 3), v(-23.85, 9, 10), { Color = Color3.fromRGB(40, 90, 160) })
	Build.surfaceText(toiletSign, Enum.NormalId.Right, "🚻 화장실")
	local toiletZone = zone(B, "ToiletZone", Vector3.new(13, 10, 15), v(-31.5, 5, 14.5))

	-- ☕ 탕비실 (오른쪽 뒤, x 19~38 / z 1.5~22) — 넓혔어요
	B:wall("Z", 19.5, 1.5, 22, FLOOR_Y, WALL_HEIGHT, { { center = 8, width = 5, height = 8 } }, wall)
	B:wall("X", 1.5, 19, HALF_WIDTH, FLOOR_Y, WALL_HEIGHT, nil, wall)
	B:part(Vector3.new(19, 0.2, 21), v(28.75, 0.1, 11.75), { Color = Color3.fromRGB(225, 215, 195), Material = Enum.Material.Wood })
	local pantryCounter = B:part(Vector3.new(2.5, 3, 12.5), v(36.75, 1.5, 12.25), {
		Name = "PantryCounter",
		Color = Color3.fromRGB(230, 230, 230),
	}) -- 조리대 (라면)
	B:part(Vector3.new(1.4, 2, 1.4), v(36.75, 4, 7.5), { Color = Color3.fromRGB(30, 30, 30) }) -- 커피머신
	B:part(Vector3.new(1.6, 0.6, 1.6), v(36.75, 3.3, 16), { Color = Color3.fromRGB(60, 60, 65) }) -- 전기레인지
	B:part(Vector3.new(2.5, 7, 2.5), v(36.75, 3.5, 20.5), { Color = Color3.fromRGB(200, 200, 205), Material = Enum.Material.Metal }) -- 냉장고
	B:part(Vector3.new(1.2, 4, 1.2), v(21, 2, 21), { Color = Color3.fromRGB(240, 240, 250) }) -- 정수기
	-- 식탁과 의자
	B:part(Vector3.new(5, 2.5, 3), v(27, 1.25, 19.5), { Color = Color3.fromRGB(200, 170, 130), Material = Enum.Material.Wood })
	for _, x in { 25.5, 28.5 } do
		B:part(Vector3.new(1.5, 1.5, 1.5), v(x, 0.75, 17.2), { Color = Color3.fromRGB(120, 90, 60) })
	end
	local pantrySign = B:part(Vector3.new(0.2, 1.5, 3), v(18.85, 9, 8), { Color = COLORS.accent })
	Build.surfaceText(pantrySign, Enum.NormalId.Left, "☕ 탕비실")
	local pantryZone = zone(B, "PantryZone", Vector3.new(19, 10, 21), v(28.75, 5, 11.75))

	-- 간식 테이블 (탕비실 가운데, 위에 과자 8개)
	B:part(Vector3.new(5, 3, 7), v(28, 1.5, 9), { Color = Color3.fromRGB(170, 120, 80), Material = Enum.Material.Wood })
	-- 테이블 위로 못 올라가게 투명한 덮개 (간식은 [E]로 옆에서 가져가요)
	B:part(Vector3.new(5, 8, 7), v(28, 7, 9), { Name = "SnackTableGuard", Transparency = 1, CanQuery = false })
	local snackSign = B:part(Vector3.new(3, 0.9, 0.2), v(28, 3.7, 5.4), { Color = Color3.fromRGB(255, 240, 200) })
	Build.surfaceText(snackSign, Enum.NormalId.Front, "🍪 간식 (1인 1개)", { TextColor3 = Color3.fromRGB(80, 50, 30) })
	local snackSpots = {}
	for _, z in { 6.6, 8.2, 9.8, 11.4 } do
		for _, x in { 27.2, 28.8 } do
			table.insert(snackSpots, v(x, 3, z)) -- 테이블 윗면 위치
		end
	end

	-- 장식: 화분, 프린터
	for _, position in { v(-36, 0, -20), v(36, 0, -20), v(-36, 0, 3), v(36, 0, 3) } do
		B:part(Vector3.new(1.6, 1.6, 1.6), position + Vector3.new(0, 0.8, 0), { Color = Color3.fromRGB(150, 90, 60) })
		B:part(Vector3.new(2.4, 2.4, 2.4), position + Vector3.new(0, 2.6, 0), {
			Shape = Enum.PartType.Ball,
			Color = Color3.fromRGB(70, 140, 70),
			Material = Enum.Material.Grass,
		})
	end
	local printer = B:part(Vector3.new(3, 2.5, 2.5), v(-27, 1.25, -8), { Name = "Printer", Color = Color3.fromRGB(220, 220, 225) }) -- 프린터 (서류)
	B:part(Vector3.new(2.6, 0.6, 1.8), v(-27, 2.8, -8), { Color = Color3.fromRGB(60, 60, 65) })

	-- 형광등
	local lamps = {}
	for _, x in { -31, -16, 0, 16, 31 } do
		for _, z in { -12, 2, 14 } do
			local lamp = B:part(Vector3.new(6, 0.3, 1.2), v(x, WALL_HEIGHT - 0.2, z), {
				Color = Color3.fromRGB(245, 250, 255),
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
			local light = Instance.new("PointLight")
			light.Range = 22
			light.Brightness = 0.45
			light.Color = Color3.fromRGB(235, 245, 255)
			light.Parent = lamp
			table.insert(lamps, lamp)
		end
	end

	-- 🚒 소방 훈련 집결지 (출입문 안쪽, 훈련 때만 초록색으로 보여요)
	local assemblyZone, assemblyPoint, setAssemblyVisible = makeAssembly(B, 0, -19)

	-- 시작 지점 (출입문 안쪽)
	B:part(Vector3.new(4, 1, 4), v(0, -0.4, -19), {
		ClassName = "SpawnLocation",
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Neutral = true,
		Duration = 0,
	})

	-- 부장 순찰 지점 (복도)
	local waypoints = {
		v(0, 0, 11), -- 부장 자리 앞
		v(-17, 0, 7),
		v(-17, 0, -4),
		v(-17, 0, -17),
		v(-6, 0, -3.5), -- 책상 줄 사이
		v(6, 0, -3.5),
		v(0, 0, -17), -- 창가
		v(17, 0, -17),
		v(17, 0, -4),
		v(17, 0, 7),
		v(-6, 0, 8.5), -- 뒷줄 의자 뒤
		v(6, 0, 8.5),
		v(16, 0, 8), -- 탕비실 문 앞 (안을 들여다봐요)
		v(-28, 0, -4), -- 왼쪽 끝 (프린터 쪽)
		v(28, 0, -4), -- 오른쪽 끝
	}

	return {
		folder = folder,
		desks = desks,
		bossStand = v(0, 0, 19.6), -- 부장 책상 뒤 (책상 너머로 직원들 등을 내려다봐요)
		bossLook = Vector3.new(0, 0, -1),
		entrance = v(0, 0, -21),
		waypoints = waypoints,
		toiletZone = toiletZone,
		pantryZone = pantryZone,
		printer = printer,
		pantryCounter = pantryCounter,
		snackSpots = snackSpots,
		spots = { v(34, 0, 8), v(-24, 0, -8), v(-12, 0, -18), v(12, 0, -18), v(34, 0, 17) },
		toiletSeats = toiletSeats,
		meetingSeats = {}, -- 대충상사엔 회의실이 없어요
		meetingZone = nil,
		companyId = company.id,
		lamps = lamps,
		assemblyZone = assemblyZone,
		assemblyPoint = assemblyPoint,
		setAssemblyVisible = setAssemblyVisible,
		cakeSpots = { v(36.6, 3, 10), v(36.6, 3, 11.5), v(36.6, 3, 13) },
		workshopStart = v(0, 0, 10), -- 뒷줄 의자와 부장 책상 사이
		workshopBoss = v(0, 0, -21), -- 출입문 앞
		workshopLook = Vector3.new(0, 0, 1),
		candyZone = nil,
		shops = {},
		clawMachines = {},
		arcade = nil,
		wheel = nil,
		dart = nil,
		dinnerSeats = {}, -- 대충상사는 회식 장소가 없어서 화면 미니게임만
		dinnerBoss = nil,
		dinnerLook = nil,
		setClock = setClock,
	}
end

return OfficeBuilder
