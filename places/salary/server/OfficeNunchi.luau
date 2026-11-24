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
--   (위 그림은 예전 평면이에요. 지금 평면은 OfficeNunchiFloor.luau에 있어요.)
--   사무실은 유리 타워 12층이고, 🌳 공원과 🏙️ 눈치 스트리트는 회사 단지(Campus)에 있어요. 엘리베이터로 오가요.
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
local Campus = require(script.Parent.Campus)

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

	---------------------------------------------------------------- 🏙️ 회사 단지 (Campus): 공원 · 눈치 스트리트 · 타워 1층 로비
	--   예전엔 사무실 문 밖이 바로 공원이었지만, 이제 사무실은 유리 타워 12층이고 단지는 엘리베이터로 내려가요.
	local campus = Campus.build(folder, helpers, company.id)
	local shops = table.clone(campus.shops) -- ☕ 눈치 커피 · 🍰 디저트 · (대충상사 상가의) ☕ 골목 커피 · 🍢 분식

	---------------------------------------------------------------- 🚒 집결지(=🏁 워크숍 결승선)
	-- 12층이라 밖으로 못 나가요: 사무실 동쪽 통로 창가에 모여요 (워크숍도 이 통로에서 해요)
	local assemblyZone, assemblyPoint, setAssemblyVisible = helpers.makeAssembly(B, 10, -33.75)

	shops.store = storeSpot -- 🏪 사내 매점 (뒤쪽 오른쪽 방)
	-- 📦 택배 상자 · 택배 보관함 · 🚪 엘리베이터 · 시작 지점은 건물 안이라 OfficeNunchiFloor가 지었어요
	local packageBox, deliveryShelf, elevator = F.packageBox, F.deliveryShelf, F.elevator

	-- 부장 순찰 지점 (복도) — 책상 열 사이(x ±12), 책상 줄 사이(z -8), 바깥 통로(x ±36), 창가(z -30)
	local waypoints, spots, packageSpots = F.waypoints, F.spots, F.packageSpots -- (부장님은 12층에만 있어요. 단지는 경비원 담당)

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
		workshopStart = v(10, 0, 7.5), -- 🌸 복도 문 앞에서 출발 → 창가 결승선
		-- 👮 경비원: 경비실 앞(정문 옆) + 공원·거리 순찰 지점 (나무·벤치·분수·회식 테이블·흡연구역을 피해서)
		guardPost = campus.guardPost,
		-- 🛍️ 눈치 스트리트 위에 있나 (공원 정문 밖 거리, 가게 안 포함)
		inStreet = campus.contains, -- 🛍️ 단지(공원·눈치 스트리트·로비)에 있나
		guardPatrol = campus.guardPatrol,
		workshopBoss = v(10, 0, -39.5), -- 부장님은 창가에서 술래
		workshopLook = Vector3.new(0, 0, 1), -- 술래가 직원들을 볼 때 방향
		candyZone = campus.candyZone,
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
		clawMachines = campus.clawMachines, -- 🧸 인형뽑기 기계
		wheel = campus.wheel, -- 🎡 다 같이 돌림판
		dart = campus.dart, -- 🎯 풍선 다트
		arcade = campus.arcade, -- 🕹️ 오락실 (게임기, 경품 교환대, 기록판)
		dinnerSeats = campus.dinnerSeats, -- 🍻 회식은 공원 식탁에서
		parkBeds = campus.parkBeds, -- 🌷 내 공원 화단 (흙 Part 6개)
		dinnerBoss = campus.dinnerBoss, -- 부장님은 식탁 끝 상석
		dinnerLook = Vector3.new(1, 0, 0),
		setClock = setClock,
	}
end

return OfficeNunchi
