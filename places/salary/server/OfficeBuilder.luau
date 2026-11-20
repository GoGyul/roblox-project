-- 사무실 짓기 (위에서 본 모습, 위쪽이 창문 쪽 -Z) — 📐 홀 2배·방 1.5배로 넓혔어요
--   가로 x -64~64 / 세로 z -31.5(앞, 창문·출입문)~31.5(뒤)
--
--   ┌──────────────── 창문 · 사훈 · 벽시계 ────────────────┐
--   │ 사내매점 │              [출입문]                      │
--   │  (방)    │   [책상1]      [책상2]      [책상3]         │  ← 직원들은 창문 쪽을 보고 앉아요 (z -14)
--   ├──────────┘     🪑           🪑           🪑           │
--   │🚪엘리베이터 🖨️ [책상4]      [책상5]      [책상6]  ┌──────┤  (플레이어는 보통 5번, z 5)
--   ├──────────┐     🪑           🪑           🪑     │ 탕비실│
--   │  화장실  │            [김부장 자리]             │       │  ← 부장은 직원들 등 뒤에 앉아요 (z 19)
--   └──────────┴──[문 x -22]───────────────────────────┴───────┘
--              │ 🏋️ 체력 단련실 (별관)  │  ← 뒷벽 문으로 들어가요: x -40~-4 / z 32~60
--              └────────────────────────┘

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Build = require(ReplicatedStorage.Shared.Build)
local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local OfficeNunchi = require(script.Parent.OfficeNunchi)

local OfficeBuilder = {}

local FLOOR_Y = 1 -- 바닥 윗면 높이
local WALL_HEIGHT = 12
local HALF_WIDTH = 64 -- 사무실 가로 절반 (벽 안쪽) — 📐 넓혔어요 (예전 46)
local HALF_DEPTH = 31.5 -- 사무실 세로 절반 (앞·뒤 벽 가운데) — 📐 넓혔어요 (예전 22.5)

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
	gymSeats: { Seat }, -- 🏋️ 체력 단련실 운동기구 (GymSeat)
	gymZone: BasePart,
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
	shops: { [string]: { counter: BasePart, clerkSpot: Vector3 } }, -- 🏙️ 눈치 스트리트 가게 + 🏪 사내 매점
	packageBox: BasePart, -- 📦 (장식) 출입문 옆 택배 상자
	elevator: { door: BasePart, exit: Vector3 }, -- 🚪 옥상 가는 엘리베이터
	insideOffice: (Vector3) -> boolean, -- 사무실 건물 안인가? (옥상·공원·거리는 밖)
	packageSpots: { Vector3 }, -- 📦 긴급 프로젝트 "택배 대란" 상자가 놓일 수 있는 곳 (바닥)
	clawMachines: { BasePart }, -- 🧸 인형뽑기 기계
	arcade: any?, -- 🕹️ 오락실 (눈치물산만)
	wheel: any?, -- 🎡 돌림판 (눈치물산만)
	dart: any?, -- 🎯 풍선 다트 (눈치물산만)
	dinnerSeats: { Seat }, -- 🍻 회식 자리 (없으면 화면 미니게임만)
	parkBeds: { BasePart }?, -- 🌷 내 공원 화단 흙 (눈치물산만)
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

-- 의자가 책상 가운데에서 뒤로 얼마나 떨어져 있나 (Employees의 책상 위 소품 위치도 이 값을 써요)
local DESK_SEAT_OFFSET = SalaryConfig.DESK_SEAT_OFFSET

local function buildDesk(B, index: number, x: number, z: number): Desk
	local model = Instance.new("Model")
	model.Name = `Desk{index}`
	model.Parent = B.parent
	local function p(size: Vector3, position: Vector3, props: { [string]: any })
		local options = table.clone(props)
		options.Parent = model
		return B:part(size, position, options)
	end

	-- 📐 책상을 넓혔어요 (예전 6×3 → 8.4×4): 꾸미기·소품·인형을 올릴 자리가 넉넉해요
	local top = p(Vector3.new(8.4, 2.5, 4), v(x, 1.25, z), { Name = "DeskTop", Color = COLORS.desk, Material = Enum.Material.Wood })
	-- 모니터
	local monitor = p(Vector3.new(2.6, 1.8, 0.3), v(x, 3.6, z - 1.2), { Name = "Monitor", Color = COLORS.monitor })
	local screen = p(Vector3.new(2.3, 1.5, 0.05), v(x, 3.6, z - 1.02), {
		Color = COLORS.screen,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
	})
	screen.Name = "Screen"
	p(Vector3.new(1.6, 0.1, 0.6), v(x, 2.55, z + 0.5), { Color = Color3.fromRGB(60, 60, 60) }) -- 키보드
	p(Vector3.new(0.4, 0.08, 0.6), v(x + 1.3, 2.54, z + 0.5), { Color = Color3.fromRGB(70, 70, 75) }) -- 마우스
	-- 파티션 (앞, 양옆)
	local h = partitionHeight
	p(Vector3.new(8.8, h, 0.3), v(x, h / 2, z - 2.2), { Color = COLORS.partition, Material = Enum.Material.Fabric })
	p(Vector3.new(0.3, h, 4.6), v(x - 4.4, h / 2, z), { Color = COLORS.partition, Material = Enum.Material.Fabric })
	p(Vector3.new(0.3, h, 4.6), v(x + 4.4, h / 2, z), { Color = COLORS.partition, Material = Enum.Material.Fabric })

	-- 의자 (Seat: 닿으면 앉아요. 앞쪽(-Z)을 보고 앉음)
	local seat = p(Vector3.new(2, 1, 2), v(x, 1, z + DESK_SEAT_OFFSET), {
		ClassName = "Seat",
		Name = "Seat",
		Color = COLORS.chair,
	}) :: Seat
	local chairBack = p(Vector3.new(2, 2.4, 0.3), v(x, 2.7, z + DESK_SEAT_OFFSET + 0.9), { Name = "ChairBack", Color = COLORS.chair })

	-- seatHome: 의자 원래 자리 (혹시 밀려나면 되돌려요)
	-- top/monitor/chairBack + 기본 색: 🪑 내 자리 꾸미기가 바꿨다가 되돌릴 때 써요
	return {
		index = index,
		model = model,
		seat = seat,
		seatHome = seat.CFrame,
		behind = v(x, 0, z + DESK_SEAT_OFFSET + 3.9),
		top = top,
		monitor = monitor,
		chairBack = chairBack,
		base = {
			deskColor = top.Color,
			deskMaterial = top.Material,
			chairColor = seat.Color,
		},
	}
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

-- 🏪 사내 매점 (계산대 + 간판 + 진열대) → Street 모듈이 매점 아주머니와 [E] 주문을 붙여요
local function buildStore(B, x: number, z: number, accent: Color3): { counter: BasePart, clerkSpot: Vector3 }
	local counter = B:part(Vector3.new(6, 3.5, 2), v(x, 1.75, z), { Name = "StoreCounter", Color = Color3.fromRGB(240, 235, 225) })
	B:part(Vector3.new(6.2, 0.3, 2.2), v(x, 3.6, z), { Color = accent })
	local sign = B:part(Vector3.new(6, 1.2, 0.3), v(x, 6.5, z - 2.8), { Color = Color3.fromRGB(30, 35, 45) })
	Build.surfaceText(sign, Enum.NormalId.Back, "🏪 사내 매점", { Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 230, 120) })
	-- 뒤쪽 진열대와 선물 상자들
	B:part(Vector3.new(6, 4, 1), v(x, 2, z - 3.6), { Color = Color3.fromRGB(150, 110, 80), Material = Enum.Material.Wood })
	for i, color in { Color3.fromRGB(200, 40, 50), Color3.fromRGB(255, 150, 190), Color3.fromRGB(110, 70, 40), Color3.fromRGB(240, 200, 60) } do
		B:part(Vector3.new(1, 0.9, 0.8), v(x - 3 + i * 1.2, 4.45, z - 3.6), { Color = color })
	end
	return { counter = counter, clerkSpot = v(x, 0, z - 2.2) }
end

-- 🏪 매점 방 꾸미기: 바닥 타일, 벽 진열대(과자·음료), 음료 냉장고, 문 위 간판
--   wallX: 진열대를 붙일 벽 쪽 x / z1~z2: 진열대 길이 / center·size: 방 바닥 / sign: 문 밖 간판 위치와 면
local function decorateStore(B, info)
	B:part(Vector3.new(info.size.X, 0.12, info.size.Y), v(info.center.X, 0.07, info.center.Y), {
		Color = Color3.fromRGB(235, 232, 220),
		Material = Enum.Material.Marble,
		CanCollide = false,
	})
	local length = math.abs(info.z2 - info.z1)
	local midZ = (info.z1 + info.z2) / 2
	B:part(Vector3.new(1.3, 5, length), v(info.wallX, 2.5, midZ), { Color = Color3.fromRGB(150, 110, 80), Material = Enum.Material.Wood })
	local colors = { Color3.fromRGB(220, 60, 60), Color3.fromRGB(250, 200, 60), Color3.fromRGB(90, 170, 240), Color3.fromRGB(120, 210, 120), Color3.fromRGB(240, 150, 200) }
	local inward = if info.wallX < 0 then 1 else -1 -- 진열대 앞쪽(방 안쪽) 방향
	for shelf = 0, 2 do
		for i = 0, math.floor(length / 1.3) - 1 do
			B:part(Vector3.new(0.6, 0.8, 0.9), v(info.wallX + inward * 0.5, 1.2 + shelf * 1.5, math.min(info.z1, info.z2) + 0.8 + i * 1.3), {
				Color = colors[(i + shelf) % #colors + 1],
				CanCollide = false,
			})
		end
	end
	-- 음료 냉장고 (유리문)
	B:part(Vector3.new(2.4, 7, 2.4), v(info.fridge.X, 3.5, info.fridge.Y), { Color = Color3.fromRGB(230, 235, 240), Material = Enum.Material.Metal })
	B:part(Vector3.new(0.15, 6, 2), v(info.fridge.X + inward * 1.25, 3.6, info.fridge.Y), { Color = Color3.fromRGB(170, 220, 255), Material = Enum.Material.Glass, Transparency = 0.3 })
	-- 문 밖 간판
	local sign = B:part(Vector3.new(0.2, 1.5, 4), info.signPosition, { Color = Color3.fromRGB(230, 120, 60) })
	Build.surfaceText(sign, info.signFace, "🏪 사내 매점")
end

-- 🚪 엘리베이터 문 (왼쪽 벽에 붙어요, 사무실 쪽 +X를 봐요) → Rooftop 모듈이 [E]를 붙여요
local function buildElevator(B, wallX: number, z: number): { door: BasePart, exit: Vector3 }
	local metal = { Color = Color3.fromRGB(170, 175, 185), Material = Enum.Material.Metal }
	B:part(Vector3.new(0.5, 9, 6.4), v(wallX + 0.25, 4.5, z), { Color = Color3.fromRGB(110, 115, 125), Material = Enum.Material.Metal }) -- 틀
	local door = B:part(Vector3.new(0.3, 8, 5), v(wallX + 0.55, 4, z), { Name = "ElevatorDoor", Color = metal.Color, Material = metal.Material, Reflectance = 0.15 })
	B:part(Vector3.new(0.32, 8, 0.08), v(wallX + 0.56, 4, z), { Color = Color3.fromRGB(80, 85, 95) }) -- 가운데 틈
	local panel = B:part(Vector3.new(0.2, 1.2, 0.6), v(wallX + 0.4, 4.2, z + 3.6), { Color = Color3.fromRGB(40, 40, 45) }) -- 호출 버튼
	B:part(Vector3.new(0.22, 0.35, 0.35), v(wallX + 0.45, 4.4, z + 3.6), { Color = Color3.fromRGB(255, 200, 80), Material = Enum.Material.Neon, Shape = Enum.PartType.Ball })
	local sign = B:part(Vector3.new(0.2, 1.2, 5), v(wallX + 0.45, 9.6, z), { Color = Color3.fromRGB(30, 35, 45) })
	Build.surfaceText(sign, Enum.NormalId.Right, "🚪 엘리베이터 · 옥상 ▲", { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 220, 120) })
	local _ = panel
	return { door = door, exit = v(wallX + 4, 0, z) }
end

-- 📦 택배 상자 (긴급 프로젝트 "급한 택배"에서 들고 가요)
local function buildPackage(B, x: number, z: number): BasePart
	local box = B:part(Vector3.new(2.2, 2, 2.2), v(x, 1, z), { Name = "PackageBox", Color = Color3.fromRGB(190, 140, 90), Material = Enum.Material.Cardboard })
	B:part(Vector3.new(2.25, 0.3, 2.25), v(x, 1.6, z), { Color = Color3.fromRGB(220, 200, 150), CanCollide = false }) -- 테이프
	return box
end

-- 🏋️ 체력 단련실 안쪽 꾸미기 (방 벽·문은 회사마다 따로 짓고, 안은 여기서 똑같이 채워요)
--   cx, cz: 방 바닥 가운데 / hx, hz: 방 안쪽 가로·세로 절반 / wallHeight: 천장 높이
--   문은 -Z 쪽(사무실 쪽), 큰 거울은 +Z 벽. 운동기구 5대는 모두 거울을 보고 써요.
--   운동기구마다 Seat(이름 "GymSeat", 속성 Machine)가 있어요 → [E] 앉기(SeatPrompts) → Employees가 "gym" 상태로
--   🧍 서서 하는 운동(러닝머신·샌드백)은 보이지 않는 의자를 허리 높이에 둬요 (Poses가 다리를 쭉 펴 줘요)
local STAND_SEAT_HEIGHT = 1.6 -- 서서 하는 운동: 발판 윗면에서 의자 윗면까지 (다리 길이쯤)
local function buildGym(B, info): { seats: { Seat }, zone: BasePart, lamps: { BasePart }, spot: Vector3 }
	local cx, cz, hx, hz = info.cx, info.cz, info.hx, info.hz
	local wallHeight = info.wallHeight
	local accent = info.accent or Color3.fromRGB(230, 120, 60)
	local function at(x: number, y: number, z: number): Vector3
		return v(cx + x, y, cz + z)
	end
	local function turned(x: number, y: number, z: number, rx: number, ry: number, rz: number): CFrame
		return CFrame.new(at(x, y, z)) * CFrame.Angles(rx, ry, rz)
	end
	local black = Color3.fromRGB(35, 35, 40)
	local silver = Color3.fromRGB(180, 185, 195)
	local function metal(size: Vector3, position: Vector3, props: { [string]: any }?): BasePart
		local options = { Color = silver, Material = Enum.Material.Metal }
		for key, value in props or {} do
			options[key] = value
		end
		return B:part(size, position, options)
	end
	local FACE = CFrame.Angles(0, math.pi, 0) -- 의자 앞쪽이 거울(+Z)을 봐요
	local seats = {}
	local function gymSeat(machineId: string, cframe: CFrame, size: Vector3, props: { [string]: any }?): Seat
		local machine = SalaryConfig.GymMachines[machineId]
		local options: { [string]: any } = {
			ClassName = "Seat",
			Name = "GymSeat",
			CFrame = cframe,
			Color = black,
			Material = Enum.Material.Leather,
		}
		for key, value in props or {} do
			options[key] = value
		end
		local seat = B:part(size, nil, options) :: Seat
		seat:SetAttribute("Machine", machineId)
		seat:SetAttribute("PromptText", `{machine.emoji} {machine.name}`)
		table.insert(seats, seat)
		return seat
	end

	-- 바닥: 고무 매트 + 가운데 노란 안전선
	B:part(Vector3.new(hx * 2, 0.12, hz * 2), at(0, 0.06, 0), { Color = Color3.fromRGB(55, 58, 64), Material = Enum.Material.Rubber, CanCollide = false })
	B:part(Vector3.new(hx * 2 - 4, 0.14, 0.4), at(0, 0.07, -5), { Color = Color3.fromRGB(240, 200, 60), CanCollide = false })

	-- 거울 벽 (+Z) + 위에 표어
	B:part(Vector3.new(hx * 2 - 6, 7, 0.2), at(0, 4.6, hz - 0.15), {
		Color = Color3.fromRGB(205, 225, 240),
		Material = Enum.Material.Glass,
		Reflectance = 0.45,
		CanQuery = false,
	})
	local motto = B:part(Vector3.new(20, 2.2, 0.2), at(0, wallHeight - 2, hz - 0.2), { Color = Color3.fromRGB(190, 35, 45) })
	Build.surfaceText(motto, Enum.NormalId.Front, "💪 체력은 국력! 칼퇴도 체력에서 나온다", { Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 230, 120) })
	-- 옆벽 포스터 2장
	local posterL = B:part(Vector3.new(0.2, 3, 6), at(-hx + 0.15, 6.5, -4), { Color = Color3.fromRGB(30, 35, 45) })
	Build.surfaceText(posterL, Enum.NormalId.Right, "🏃 땀은 배신하지 않는다\n(월급은 배신해도)", { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 255, 255) })
	local posterR = B:part(Vector3.new(0.2, 3, 6), at(hx - 0.15, 6.5, -4), { Color = accent })
	Build.surfaceText(posterR, Enum.NormalId.Left, "🍗 운동 끝나고 먹는 치킨은\n0칼로리", { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 255, 255) })
	-- 문 밖(사무실 쪽) 간판
	local sign = B:part(Vector3.new(7, 1.5, 0.2), at(0, 10.2, -hz - 1.15), { Color = Color3.fromRGB(30, 35, 45) })
	Build.surfaceText(sign, Enum.NormalId.Front, "🏋️ 체력 단련실", { Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 220, 120) })

	-- 💧 정수기 (문 옆 왼쪽 구석)
	B:part(Vector3.new(1.4, 3.4, 1.4), at(-hx + 1.2, 1.7, -hz + 2.5), { Color = Color3.fromRGB(240, 240, 245) })
	B:part(Vector3.new(1.6, 1.1, 1.1), nil, {
		Shape = Enum.PartType.Cylinder,
		CFrame = turned(-hx + 1.2, 4.2, -hz + 2.5, 0, 0, math.rad(90)),
		Color = Color3.fromRGB(120, 190, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
	}) -- 물통
	B:part(Vector3.new(0.3, 0.3, 0.3), at(-hx + 1.95, 2.6, -hz + 2.5), { Color = Color3.fromRGB(60, 140, 230) }) -- 꼭지
	-- 🧺 수건 선반 (문 옆 오른쪽 구석)
	B:part(Vector3.new(1.4, 3, 4), at(hx - 0.7, 1.5, -hz + 3), { Color = Color3.fromRGB(150, 110, 80), Material = Enum.Material.Wood })
	for i, color in { Color3.fromRGB(250, 250, 250), Color3.fromRGB(120, 190, 240), Color3.fromRGB(250, 170, 190) } do
		for layer = 0, 1 do
			B:part(Vector3.new(1.1, 0.35, 1.1), at(hx - 0.7, 3.18 + layer * 0.36, -hz + 1.8 + (i - 1) * 1.2), { Color = color, Material = Enum.Material.Fabric, CanCollide = false })
		end
	end
	-- 덤벨 거치대 (오른쪽 벽 안쪽, 장식)
	B:part(Vector3.new(1.6, 2.4, 6), at(hx - 0.8, 1.2, hz - 5), { Color = black, Material = Enum.Material.Metal })
	for i = 0, 4 do
		local z = hz - 7.4 + i * 1.2
		metal(Vector3.new(1.2, 0.25, 0.25), at(hx - 0.8, 2.75, z), { Shape = Enum.PartType.Cylinder, CanCollide = false })
		for _, dx in { -0.5, 0.5 } do
			B:part(Vector3.new(0.3, 0.5 + i * 0.08, 0.5 + i * 0.08), at(hx - 0.8 + dx, 2.75, z), { Shape = Enum.PartType.Cylinder, Color = black, CanCollide = false })
		end
	end
	-- 짐볼 (왼쪽 뒤 구석)
	B:part(Vector3.new(2.6, 2.6, 2.6), at(-hx + 1.6, 1.3, hz - 1.6), { Shape = Enum.PartType.Ball, Color = Color3.fromRGB(80, 150, 230) })

	-- 운동기구 자리 (가로로 5대, 거울을 봐요)
	local slots = { -0.8 * hx, -0.4 * hx, 0, 0.4 * hx, 0.8 * hx }

	-- 🏃 러닝머신 (서서 달려요)
	do
		local mx = slots[1]
		B:part(Vector3.new(3.4, 0.6, 7), at(mx, 0.3, 0), { Color = black })
		B:part(Vector3.new(2.8, 0.1, 6.4), at(mx, 0.65, -0.2), { Color = Color3.fromRGB(20, 20, 22), Material = Enum.Material.Rubber })
		for _, side in { -1, 1 } do
			B:part(Vector3.new(0.3, 0.2, 7), at(mx + side * 1.55, 0.7, 0), { Color = accent })
			metal(Vector3.new(0.3, 4, 0.3), at(mx + side * 1.5, 2.6, 3.2))
			metal(Vector3.new(0.25, 0.25, 2.6), at(mx + side * 1.5, 3.8, 2)) -- 손잡이
		end
		local console = B:part(Vector3.new(3.4, 1.1, 0.6), nil, { CFrame = turned(mx, 4.6, 3.2, math.rad(25), 0, 0), Color = black })
		B:part(Vector3.new(2, 0.6, 0.05), nil, { CFrame = console.CFrame * CFrame.new(0, 0, -0.32), Color = Color3.fromRGB(90, 230, 200), Material = Enum.Material.Neon, CanCollide = false })
		B:part(Vector3.new(0.15, 1.2, 1), at(mx + 1.62, 3.3, 1.6), { Color = Color3.fromRGB(250, 250, 250), Material = Enum.Material.Fabric, CanCollide = false }) -- 걸어 둔 수건
		gymSeat("treadmill", CFrame.new(at(mx, 0.7 + STAND_SEAT_HEIGHT - 0.1, -0.6)) * FACE, Vector3.new(1.6, 0.2, 1.6), { Transparency = 1, CanCollide = false })
	end

	-- 🏋️ 벤치프레스 (뒤로 비스듬히 기댄 인클라인 벤치 + 바벨 거치대)
	do
		local mx = slots[2]
		local seatCFrame = CFrame.new(at(mx, 1.6, -0.3)) * FACE * CFrame.Angles(math.rad(30), 0, 0)
		local red = Color3.fromRGB(170, 40, 45)
		gymSeat("bench", seatCFrame, Vector3.new(1.8, 0.5, 2.2), { Color = red })
		B:part(Vector3.new(1.8, 3.4, 0.4), nil, { CFrame = seatCFrame * CFrame.new(0, 1.6, 1.15), Color = red, Material = Enum.Material.Leather }) -- 등받이
		metal(Vector3.new(0.5, 0.2, 4.6), at(mx, 0.1, -1.2), { Color = black })
		metal(Vector3.new(0.4, 1.3, 0.4), at(mx, 0.65, -0.3), { Color = black })
		metal(Vector3.new(0.4, 2.2, 0.4), at(mx, 1.1, -2.4), { Color = black })
		for _, side in { -1, 1 } do
			metal(Vector3.new(0.35, 6.2, 0.35), at(mx + side * 2.4, 3.1, -1.6)) -- 거치대 기둥
			metal(Vector3.new(0.35, 0.2, 0.6), at(mx + side * 2.4, 5.6, -1.4)) -- 걸이
			B:part(Vector3.new(0.35, 1.9, 1.9), at(mx + side * 2.85, 5.8, -1.6), { Shape = Enum.PartType.Cylinder, Color = black, CanCollide = false }) -- 원판
		end
		metal(Vector3.new(6.4, 0.25, 0.25), at(mx, 5.8, -1.6), { Shape = Enum.PartType.Cylinder, CanCollide = false }) -- 바벨
	end

	-- 🚴 실내 자전거
	do
		local mx = slots[3]
		B:part(Vector3.new(0.6, 0.3, 4.4), at(mx, 0.15, 0), { Color = black })
		for _, dz in { -2, 2 } do
			B:part(Vector3.new(2.6, 0.3, 0.5), at(mx, 0.15, dz), { Color = black })
		end
		metal(Vector3.new(0.5, 2.2, 2.2), at(mx, 1.6, 1.5), { Shape = Enum.PartType.Cylinder }) -- 바퀴
		B:part(Vector3.new(0.7, 1.1, 1.1), at(mx, 1.6, 1.5), { Shape = Enum.PartType.Cylinder, Color = accent })
		metal(Vector3.new(0.4, 2.2, 0.4), at(mx, 1.2, -0.7), { Color = black }) -- 안장 기둥
		metal(Vector3.new(0.4, 3.6, 0.4), at(mx, 1.8, 2.8), { Color = black }) -- 핸들 기둥
		metal(Vector3.new(2.4, 0.25, 0.25), at(mx, 3.7, 2.6), { Shape = Enum.PartType.Cylinder, CanCollide = false }) -- 핸들
		B:part(Vector3.new(1.2, 0.8, 0.15), at(mx, 4.1, 2.95), { Color = Color3.fromRGB(90, 230, 200), Material = Enum.Material.Neon })
		B:part(Vector3.new(1.6, 0.2, 0.2), at(mx, 1.1, 0.4), { Color = black, CanCollide = false }) -- 크랭크
		for _, side in { -1, 1 } do
			B:part(Vector3.new(0.5, 0.15, 0.8), at(mx + side * 0.8, 1.1, 0.4), { Color = black, CanCollide = false }) -- 페달
		end
		gymSeat("bike", CFrame.new(at(mx, 2.5, -0.7)) * FACE, Vector3.new(1.4, 0.4, 1.6))
	end

	-- 🚣 로잉머신 (낮은 레일 위 미끄러지는 의자 + 앞쪽 바람 바퀴)
	do
		local mx = slots[4]
		metal(Vector3.new(0.6, 0.3, 8), at(mx, 0.45, -0.5))
		for _, dz in { -4.3, 3.3 } do
			B:part(Vector3.new(2, 0.3, 0.5), at(mx, 0.15, dz), { Color = black })
		end
		B:part(Vector3.new(1.8, 1.8, 1.4), at(mx, 1.2, 3.5), { Color = black })
		B:part(Vector3.new(1.9, 1.5, 1.5), at(mx, 1.2, 3.5), { Shape = Enum.PartType.Cylinder, Color = accent }) -- 바람 바퀴 덮개
		for _, side in { -1, 1 } do
			B:part(Vector3.new(0.8, 0.2, 1.1), nil, { CFrame = turned(mx + side * 0.55, 1, 2.2, math.rad(-35), 0, 0), Color = black }) -- 발판
		end
		B:part(Vector3.new(1.8, 0.2, 0.2), at(mx, 1.4, 2.7), { Shape = Enum.PartType.Cylinder, Color = black, CanCollide = false }) -- 손잡이
		gymSeat("rowing", CFrame.new(at(mx, 0.85, -1.2)) * FACE, Vector3.new(1.4, 0.5, 1.4))
	end

	-- 🥊 샌드백 (천장에 매달린 빨간 샌드백 앞에 서서 펀치!)
	do
		local mx = slots[5]
		B:part(Vector3.new(4, 0.14, 5), at(mx, 0.13, 0), { Color = Color3.fromRGB(50, 90, 160), Material = Enum.Material.Rubber, CanCollide = false })
		metal(Vector3.new(2, 0.3, 2), at(mx, wallHeight - 0.15, 1.6), { Color = black })
		local chain = wallHeight - 6.3
		metal(Vector3.new(0.2, chain, 0.2), at(mx, 6 + chain / 2, 1.6), { CanCollide = false })
		B:part(Vector3.new(4, 2, 2), nil, {
			Name = "Sandbag",
			Shape = Enum.PartType.Cylinder,
			CFrame = turned(mx, 4, 1.6, 0, 0, math.rad(90)),
			Color = Color3.fromRGB(190, 40, 40),
			Material = Enum.Material.Leather,
		})
		gymSeat("sandbag", CFrame.new(at(mx, STAND_SEAT_HEIGHT - 0.1, -0.4)) * FACE, Vector3.new(1.6, 0.2, 1.6), { Transparency = 1, CanCollide = false })
	end

	-- 🤸 스트레칭 매트 (입구 쪽 왼편, 바닥에 앉아서) · ⚖️ 밸런스 볼 (입구 쪽 오른편, 공 위에 앉아서)
	--   (가운데 입구 길은 비워 둬요)
	do
		local mx, mz = -0.62 * hx, -hz + 8
		B:part(Vector3.new(3, 0.12, 6.5), at(mx, 0.16, mz), { Color = Color3.fromRGB(150, 90, 200), Material = Enum.Material.Rubber, CanCollide = false }) -- 요가 매트
		B:part(Vector3.new(3, 0.5, 0.5), at(mx, 0.35, mz + 3.4), { Shape = Enum.PartType.Cylinder, Orientation = Vector3.new(0, 90, 0), Color = Color3.fromRGB(120, 70, 170), Material = Enum.Material.Rubber, CanCollide = false }) -- 말아 둔 매트 끝
		gymSeat("stretch", CFrame.new(at(mx, 0.45, mz + 1.2)) * FACE, Vector3.new(2, 0.3, 2), { Transparency = 1, CanCollide = false })
		local signPart = B:part(Vector3.new(2.6, 0.9, 0.1), at(mx, 0.6, mz - 3.4), { Color = Color3.fromRGB(250, 245, 255), CanCollide = false })
		Build.surfaceText(signPart, Enum.NormalId.Back, "🤸 스트레칭", { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(120, 70, 170) })
	end
	do
		local mx, mz = 0.62 * hx, -hz + 8
		B:part(Vector3.new(3.2, 3.2, 3.2), at(mx, 1.6, mz), { Shape = Enum.PartType.Ball, Color = Color3.fromRGB(240, 120, 60), Material = Enum.Material.Rubber })
		B:part(Vector3.new(3.6, 0.1, 3.6), at(mx, 0.12, mz), { Shape = Enum.PartType.Cylinder, Orientation = Vector3.new(0, 0, 90), Color = Color3.fromRGB(70, 70, 80), CanCollide = false }) -- 받침 매트
		gymSeat("balance", CFrame.new(at(mx, 3.3, mz)) * FACE, Vector3.new(1.6, 0.2, 1.6), { Transparency = 1, CanCollide = false })
	end

	-- 조명 (정전 때 같이 꺼지게 lamps로 돌려줘요)
	local lamps = {}
	for _, x in { -hx * 2 / 3, 0, hx * 2 / 3 } do -- (넓어진 방이라 조명 6개)
		for _, z in { -hz / 2, hz / 2 } do
			local lamp = B:part(Vector3.new(6, 0.3, 1.4), at(x, wallHeight - 0.2, z), {
				Color = Color3.fromRGB(245, 250, 255),
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
			local light = Instance.new("PointLight")
			light.Range = 22
			light.Brightness = 0.5
			light.Color = Color3.fromRGB(235, 245, 255)
			light.Parent = lamp
			table.insert(lamps, lamp)
		end
	end

	local gymZone = zone(B, "GymZone", Vector3.new(hx * 2, 10, hz * 2), at(0, 5, 0))
	return { seats = seats, zone = gymZone, lamps = lamps, spot = at(0, 0, -hz + 4) }
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
			buildStore = buildStore,
			decorateStore = decorateStore,
			buildElevator = buildElevator,
			buildPackage = buildPackage,
			buildGym = buildGym,
			FLOOR_Y = FLOOR_Y,
		})
	end

	local wall = { Color = COLORS.wall, Material = Enum.Material.Plaster }

	-- 바닥, 천장, 바깥 벽 (가로 128칸 × 세로 63칸: 가운데 사무실 + 구석에 화장실·탕비실·매점)
	local floorDepth = HALF_DEPTH * 2 + 1
	B:part(Vector3.new(HALF_WIDTH * 2 + 2, 1, floorDepth), Vector3.new(0, FLOOR_Y - 0.5, 0), { Color = COLORS.floor, Material = Enum.Material.Carpet })
	B:part(Vector3.new(HALF_WIDTH * 2 + 2, 1, floorDepth), v(0, WALL_HEIGHT + 0.5, 0), { Color = COLORS.wall })
	B:wall("X", -HALF_DEPTH, -HALF_WIDTH - 1, HALF_WIDTH + 1, FLOOR_Y, WALL_HEIGHT, { { center = 0, width = 6, height = 8 } }, wall) -- 앞 (출입문)
	-- 🏋️ 체력 단련실 별관 (뒷벽 너머, 안쪽 x -51~7 / z 32~76 — 화장실·탕비실·부장님 자리와 안 겹쳐요)
	local GYM_X, GYM_HX, GYM_HZ = -22, 29, 22 -- 📐 1.6배로 넓혔어요 (36×28 → 58×44)
	local GYM_Z = HALF_DEPTH + 0.5 + GYM_HZ
	B:wall("X", HALF_DEPTH, -HALF_WIDTH - 1, HALF_WIDTH + 1, FLOOR_Y, WALL_HEIGHT, { { center = GYM_X, width = 8, height = 9 } }, wall) -- 뒤 (🏋️ 체력 단련실 문)
	B:wall("Z", -HALF_WIDTH - 0.5, -HALF_DEPTH + 0.5, HALF_DEPTH - 0.5, FLOOR_Y, WALL_HEIGHT, nil, wall) -- 왼쪽
	B:wall("Z", HALF_WIDTH + 0.5, -HALF_DEPTH + 0.5, HALF_DEPTH - 0.5, FLOOR_Y, WALL_HEIGHT, nil, wall) -- 오른쪽
	-- 출입문 바깥은 막아 둬요 (나가 버리지 않게)
	B:part(Vector3.new(8, WALL_HEIGHT, 1), v(0, WALL_HEIGHT / 2, -HALF_DEPTH - 2.5), wall)
	B:part(Vector3.new(1, WALL_HEIGHT, 3), v(-4, WALL_HEIGHT / 2, -HALF_DEPTH - 1.5), wall)
	B:part(Vector3.new(1, WALL_HEIGHT, 3), v(4, WALL_HEIGHT / 2, -HALF_DEPTH - 1.5), wall)

	-- 🏋️ 체력 단련실 별관: 바닥·천장·벽 3개 (사무실 뒷벽과 이어져서 밖은 막혀 있어요)
	local gymFar = GYM_Z + GYM_HZ -- 안쪽 뒷벽
	local gymNear = HALF_DEPTH + 0.5 -- 사무실 뒷벽 안쪽 면 (z 32)
	B:part(Vector3.new(GYM_HX * 2 + 2, 1, gymFar + 1 - gymNear), Vector3.new(GYM_X, FLOOR_Y - 0.5, (gymNear + gymFar + 1) / 2), { Color = COLORS.floor, Material = Enum.Material.Carpet })
	B:part(Vector3.new(GYM_HX * 2 + 2, 1, gymFar + 1 - gymNear), v(GYM_X, WALL_HEIGHT + 0.5, (gymNear + gymFar + 1) / 2), { Color = COLORS.wall })
	B:wall("Z", GYM_X - GYM_HX - 0.5, gymNear, gymFar + 1, FLOOR_Y, WALL_HEIGHT, nil, wall)
	B:wall("Z", GYM_X + GYM_HX + 0.5, gymNear, gymFar + 1, FLOOR_Y, WALL_HEIGHT, nil, wall)
	B:wall("X", gymFar + 0.5, GYM_X - GYM_HX - 1, GYM_X + GYM_HX + 1, FLOOR_Y, WALL_HEIGHT, nil, wall)
	local gym = buildGym(B, { cx = GYM_X, cz = GYM_Z, hx = GYM_HX, hz = GYM_HZ, wallHeight = WALL_HEIGHT, accent = COLORS.accent })

	-- 창문 (앞 벽 안쪽에 붙은 유리)
	local frontInner = -HALF_DEPTH + 0.5 -- 앞 벽 안쪽 면 (z -31)
	for _, x in { -56, -39, -22, 22, 39, 56 } do
		B:part(Vector3.new(7, 5, 0.2), v(x, 6, frontInner + 0.1), {
			Color = Color3.fromRGB(170, 210, 240),
			Material = Enum.Material.Glass,
			Transparency = 0.3,
		})
	end

	-- 사훈 현수막과 벽시계 (직원들이 앉으면 정면에 보여요)
	local banner = B:part(Vector3.new(16, 2.5, 0.2), v(0, 10, frontInner + 0.15), { Color = Color3.fromRGB(170, 30, 40) })
	Build.surfaceText(banner, Enum.NormalId.Back, company.motto, {
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(255, 230, 120),
	})
	local clockFace = B:part(Vector3.new(3, 3, 0.2), v(-12, 10, frontInner + 0.15), { Color = COLORS.wall })
	local setClock = Build.clockFace(clockFace, Enum.NormalId.Back)

	-- 직원 책상 6개 (앞줄 z -14, 뒷줄 z 5 / 칸 x -20·0·20 — 사이사이 6칸 넘게 띄워요)
	local desks = {}
	local index = 0
	for _, z in { -14, 5 } do
		for _, x in { -20, 0, 20 } do
			index += 1
			table.insert(desks, buildDesk(B, index, x, z))
		end
	end

	-- 김부장 자리 (직원들 등 뒤, z 19 — 뒷줄 의자 등받이(z 9.35)와 8칸 띄웠어요)
	local BOSS_Z = 19
	B:part(Vector3.new(8, 2.5, 3.5), v(0, 1.25, BOSS_Z), { Color = Color3.fromRGB(110, 70, 40), Material = Enum.Material.Wood })
	local nameplate = B:part(Vector3.new(3, 0.8, 0.4), v(0, 2.9, BOSS_Z - 1.6), { Color = Color3.fromRGB(40, 30, 20) })
	Build.surfaceText(nameplate, Enum.NormalId.Front, "부장 김부장", {
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(230, 190, 90),
	})
	B:part(Vector3.new(2.6, 1.8, 0.3), v(0, 3.4, BOSS_Z + 0.8), { Color = COLORS.monitor })
	B:part(Vector3.new(3, 3.5, 3), v(7, 1.75, BOSS_Z + 4.5), {
		Color = Color3.fromRGB(60, 30, 25),
		Material = Enum.Material.Leather,
		CanCollide = false, -- 부장이 지나다니다 끼지 않게 (장식)
	}) -- 부장 의자

	-- 🚻 화장실 (왼쪽 뒤, x -64~-47 / z 12~31) : 부장이 들어오지 않는 안전지대
	B:wall("Z", -46.5, 11, HALF_DEPTH - 0.5, FLOOR_Y, WALL_HEIGHT, { { center = 16.5, width = 5, height = 8 } }, wall)
	B:wall("X", 11.5, -HALF_WIDTH, -46, FLOOR_Y, WALL_HEIGHT, nil, wall)
	B:part(Vector3.new(17, 0.2, 19), v(-55.5, 0.1, 21.5), { Color = COLORS.tile, Material = Enum.Material.Marble })
	local toiletSeats = {}
	for i, x in { -61, -56, -51 } do
		-- 칸막이와 문 없는 칸 (안쪽 벽에 붙은 변기)
		if i < 3 then
			B:part(Vector3.new(0.3, 7, 5), v(x + 2.5, 3.5, 28.5), { Color = Color3.fromRGB(150, 190, 200) })
		end
		B:part(Vector3.new(2.2, 1, 2.6), v(x, 0.5, 29.4), { Color = Color3.fromRGB(245, 245, 245) }) -- 변기 몸통
		B:part(Vector3.new(2.2, 2.4, 0.9), v(x, 1.8, 30.5), { Color = Color3.fromRGB(240, 240, 240) }) -- 물탱크
		local seat = B:part(Vector3.new(2, 0.4, 2), v(x, 1.2, 29.2), {
			ClassName = "Seat",
			Name = "ToiletSeat",
			Color = Color3.fromRGB(250, 250, 250),
		}) :: Seat
		table.insert(toiletSeats, seat)
	end
	-- 세면대 (바깥 벽에 붙은 거울)
	for _, z in { 15, 19 } do
		B:part(Vector3.new(2, 3, 2.5), v(-63, 1.5, z), { Color = Color3.fromRGB(235, 235, 240) })
		B:part(Vector3.new(0.2, 2.5, 2.2), v(-63.9, 5, z), { Color = Color3.fromRGB(190, 220, 235), Material = Enum.Material.Glass }) -- 거울
	end
	local toiletSign = B:part(Vector3.new(0.2, 1.5, 3), v(-45.85, 9, 16.5), { Color = Color3.fromRGB(40, 90, 160) })
	Build.surfaceText(toiletSign, Enum.NormalId.Right, "🚻 화장실")
	local toiletZone = zone(B, "ToiletZone", Vector3.new(17, 10, 19), v(-55.5, 5, 21.5))

	-- ☕ 탕비실 (오른쪽 뒤, x 42~64 / z 5.5~31)
	B:wall("Z", 41.5, 5, HALF_DEPTH - 0.5, FLOOR_Y, WALL_HEIGHT, { { center = 13, width = 6, height = 8 } }, wall)
	B:wall("X", 5, 41, HALF_WIDTH, FLOOR_Y, WALL_HEIGHT, nil, wall)
	B:part(Vector3.new(22, 0.2, 25.5), v(53, 0.1, 18.25), { Color = Color3.fromRGB(225, 215, 195), Material = Enum.Material.Wood })
	local pantryCounter = B:part(Vector3.new(2.5, 3, 12.5), v(62.75, 1.5, 19), {
		Name = "PantryCounter",
		Color = Color3.fromRGB(230, 230, 230),
	}) -- 조리대 (라면) z 12.75~25.25
	B:part(Vector3.new(1.4, 2, 1.4), v(62.75, 4, 14.25), { Color = Color3.fromRGB(30, 30, 30) }) -- 커피머신
	B:part(Vector3.new(1.6, 0.6, 1.6), v(62.75, 3.3, 22.75), { Color = Color3.fromRGB(60, 60, 65) }) -- 전기레인지
	B:part(Vector3.new(2.5, 7, 2.5), v(62.75, 3.5, 29.5), { Color = Color3.fromRGB(200, 200, 205), Material = Enum.Material.Metal }) -- 냉장고
	B:part(Vector3.new(1.2, 4, 1.2), v(43.5, 2, 30), { Color = Color3.fromRGB(240, 240, 250) }) -- 정수기
	-- 식탁과 의자
	B:part(Vector3.new(5, 2.5, 3), v(50, 1.25, 28), { Color = Color3.fromRGB(200, 170, 130), Material = Enum.Material.Wood })
	for _, x in { 48.5, 51.5 } do
		B:part(Vector3.new(1.5, 1.5, 1.5), v(x, 0.75, 25.7), { Color = Color3.fromRGB(120, 90, 60) })
	end
	local pantrySign = B:part(Vector3.new(0.2, 1.5, 3), v(40.85, 9, 13), { Color = COLORS.accent })
	Build.surfaceText(pantrySign, Enum.NormalId.Left, "☕ 탕비실")
	local pantryZone = zone(B, "PantryZone", Vector3.new(22, 10, 25.5), v(53, 5, 18.25))

	-- 간식 테이블 (탕비실 가운데, 위에 과자 8개)
	B:part(Vector3.new(5, 3, 7), v(51.5, 1.5, 15), { Color = Color3.fromRGB(170, 120, 80), Material = Enum.Material.Wood })
	-- 테이블 위로 못 올라가게 투명한 덮개 (간식은 [E]로 옆에서 가져가요)
	B:part(Vector3.new(5, 8, 7), v(51.5, 7, 15), { Name = "SnackTableGuard", Transparency = 1, CanQuery = false })
	local snackSign = B:part(Vector3.new(3, 0.9, 0.2), v(51.5, 3.7, 11.4), { Color = Color3.fromRGB(255, 240, 200) })
	Build.surfaceText(snackSign, Enum.NormalId.Front, "🍪 간식 (1인 1개)", { TextColor3 = Color3.fromRGB(80, 50, 30) })
	local snackSpots = {}
	for _, z in { 12.6, 14.2, 15.8, 17.4 } do
		for _, x in { 50.7, 52.3 } do
			table.insert(snackSpots, v(x, 3, z)) -- 테이블 윗면 위치
		end
	end

	-- 장식: 화분 (구석마다), 프린터 (왼쪽 통로)
	for _, position in { v(-42, 0, -29), v(62, 0, -29), v(-62, 0, 7), v(62, 0, 2) } do
		B:part(Vector3.new(1.6, 1.6, 1.6), position + Vector3.new(0, 0.8, 0), { Color = Color3.fromRGB(150, 90, 60) })
		B:part(Vector3.new(2.4, 2.4, 2.4), position + Vector3.new(0, 2.6, 0), {
			Shape = Enum.PartType.Ball,
			Color = Color3.fromRGB(70, 140, 70),
			Material = Enum.Material.Grass,
		})
	end
	local printer = B:part(Vector3.new(3, 2.5, 2.5), v(-38, 1.25, -3), { Name = "Printer", Color = Color3.fromRGB(220, 220, 225) }) -- 프린터 (서류)
	B:part(Vector3.new(2.6, 0.6, 1.8), v(-38, 2.8, -3), { Color = Color3.fromRGB(60, 60, 65) })

	-- 형광등 (넓어진 만큼 7×4줄)
	local lamps = {}
	for _, x in { -55, -36, -18, 0, 18, 36, 55 } do
		for _, z in { -22, -8, 6, 20 } do
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
	for _, lamp in gym.lamps do
		table.insert(lamps, lamp) -- 🏋️ 체력 단련실 조명도 정전 때 꺼져요
	end

	-- 🚒 소방 훈련 집결지 (출입문 안쪽, 훈련 때만 초록색으로 보여요)
	local assemblyZone, assemblyPoint, setAssemblyVisible = makeAssembly(B, 0, -28)

	-- 🏪 사내 매점 방 (앞쪽 왼쪽, x -64~-46 / z -31~-13): 화장실·탕비실처럼 문이 있는 별도 공간
	B:wall("Z", -45.5, -HALF_DEPTH + 0.5, -12.5, FLOOR_Y, WALL_HEIGHT, { { center = -19, width = 5, height = 8 } }, wall)
	B:wall("X", -12.5, -HALF_WIDTH, -45.5, FLOOR_Y, WALL_HEIGHT, nil, wall)
	local store = buildStore(B, -54.5, -21.5, COLORS.accent)
	decorateStore(B, {
		center = Vector2.new(-55, -22),
		size = Vector2.new(18, 18),
		wallX = -63.3,
		z1 = -26,
		z2 = -15,
		fridge = Vector2.new(-63, -29.5),
		signPosition = v(-44.85, 9, -19),
		signFace = Enum.NormalId.Right,
	})
	-- 📦 택배 상자 (출입문 옆)
	local packageBox = buildPackage(B, 7, -28.5)
	-- 🚪 엘리베이터 (왼쪽 벽 가운데: 매점 방(z -12.5)과 화장실(z 11.5) 사이)
	local elevator = buildElevator(B, -HALF_WIDTH, -1)

	-- 시작 지점 (출입문 안쪽)
	B:part(Vector3.new(4, 1, 4), v(0, -0.4, -28), {
		ClassName = "SpawnLocation",
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Neutral = true,
		Duration = 0,
	})

	-- 부장 순찰 지점 (복도) — 책상 칸은 x -24.55~-15.45 / -4.55~4.55 / 15.45~24.55, 줄은 z -16.35~-9.65 / 2.65~9.35
	local waypoints = {
		v(0, 0, 14), -- 부장 자리 앞
		v(-10, 0, 14), -- 뒷줄 의자 뒤
		v(10, 0, 14),
		v(-20, 0, 13.5),
		v(20, 0, 13.5),
		v(-10, 0, 6), -- 책상 칸 사이 (뒷줄)
		v(10, 0, 6),
		v(-10, 0, -3.5), -- 책상 줄 사이
		v(10, 0, -3.5),
		v(-10, 0, -13), -- 책상 칸 사이 (앞줄)
		v(10, 0, -13),
		v(-30, 0, -24), -- 창가
		v(0, 0, -22),
		v(30, 0, -24),
		v(-32, 0, 8), -- 왼쪽 통로
		v(-32, 0, -3.5),
		v(-32, 0, -14),
		v(32, 0, 8), -- 오른쪽 통로
		v(32, 0, -3.5),
		v(32, 0, -14),
		v(38, 0, 13), -- 탕비실 문 앞 (안을 들여다봐요)
		v(-52, 0, -1), -- 왼쪽 끝 (프린터·엘리베이터 쪽)
		v(54, 0, -6), -- 오른쪽 끝
		v(-22, 0, 44), -- 🏋️ 체력 단련실 (가끔 들여다봐요)
	}

	return {
		folder = folder,
		desks = desks,
		bossStand = v(0, 0, BOSS_Z + 3.6), -- 부장 책상 뒤 (책상 너머로 직원들 등을 내려다봐요)
		bossLook = Vector3.new(0, 0, -1),
		entrance = v(0, 0, -30),
		waypoints = waypoints,
		toiletZone = toiletZone,
		pantryZone = pantryZone,
		printer = printer,
		pantryCounter = pantryCounter,
		snackSpots = snackSpots,
		spots = { v(59, 0, 14), v(-38, 0, -6), v(-22, 0, -27), v(22, 0, -27), v(59, 0, 24), v(-50, 0, -16) },
		toiletSeats = toiletSeats,
		meetingSeats = {}, -- 대충상사엔 회의실이 없어요
		meetingZone = nil,
		gymSeats = gym.seats, -- 🏋️ 체력 단련실
		gymZone = gym.zone,
		companyId = company.id,
		lamps = lamps,
		assemblyZone = assemblyZone,
		assemblyPoint = assemblyPoint,
		setAssemblyVisible = setAssemblyVisible,
		cakeSpots = { v(62.6, 3, 17.5), v(62.6, 3, 19), v(62.6, 3, 20.5) },
		workshopStart = v(0, 0, 13.3), -- 뒷줄 의자(z 9.35)와 부장 책상(z 17.25) 사이
		workshopBoss = v(0, 0, -30), -- 출입문 앞
		workshopLook = Vector3.new(0, 0, 1),
		candyZone = nil,
		shops = { store = store }, -- 🏪 사내 매점
		packageBox = packageBox,
		elevator = elevator,
		insideOffice = function(position: Vector3): boolean
			if position.Y >= FLOOR_Y + 20 then
				return false
			end
			if math.abs(position.X) <= HALF_WIDTH + 1 and math.abs(position.Z) <= HALF_DEPTH + 1 then
				return true
			end
			-- 🏋️ 체력 단련실 별관도 건물 안
			return math.abs(position.X - GYM_X) <= GYM_HX + 1 and position.Z > HALF_DEPTH and position.Z <= GYM_Z + GYM_HZ + 1
		end,
		packageSpots = { v(10, 0, -24), v(-53, 0, -15), v(55, 0, 22), v(-34, 0, 4), v(0, 0, 13.5), v(-55, 0, 18), v(30, 0, -20), v(-10, 0, -3.5) },
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
