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

local OfficeBuilder = {}

local FLOOR_Y = 1 -- 바닥 윗면 높이
local WALL_HEIGHT = 12

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

export type Desk = {
	index: number,
	model: Model,
	seat: Seat,
	behind: Vector3, -- 부장이 뒤에서 들여다볼 위치
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
	p(Vector3.new(6.4, 4.5, 0.3), v(x, 2.25, z - 1.7), { Color = COLORS.partition, Material = Enum.Material.Fabric })
	p(Vector3.new(0.3, 4.5, 3.6), v(x - 3.2, 2.25, z), { Color = COLORS.partition, Material = Enum.Material.Fabric })
	p(Vector3.new(0.3, 4.5, 3.6), v(x + 3.2, 2.25, z), { Color = COLORS.partition, Material = Enum.Material.Fabric })

	-- 의자 (Seat: 닿으면 앉아요. 앞쪽(-Z)을 보고 앉음)
	local seat = p(Vector3.new(2, 1, 2), v(x, 1, z + 2.6), {
		ClassName = "Seat",
		Name = "Seat",
		Color = COLORS.chair,
	}) :: Seat
	p(Vector3.new(2, 2.4, 0.3), v(x, 2.7, z + 3.5), { Color = COLORS.chair })

	return { index = index, model = model, seat = seat, behind = v(x, 0, z + 6.5) }
end

function OfficeBuilder.build(): Office
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
	local wall = { Color = COLORS.wall, Material = Enum.Material.Plaster }

	-- 바닥, 천장, 바깥 벽
	B:part(Vector3.new(62, 1, 46), Vector3.new(0, FLOOR_Y - 0.5, 0), { Color = COLORS.floor, Material = Enum.Material.Carpet })
	B:part(Vector3.new(62, 1, 46), v(0, WALL_HEIGHT + 0.5, 0), { Color = COLORS.wall })
	B:wall("X", -22.5, -31, 31, FLOOR_Y, WALL_HEIGHT, { { center = 0, width = 6, height = 8 } }, wall) -- 앞 (출입문)
	B:wall("X", 22.5, -31, 31, FLOOR_Y, WALL_HEIGHT, nil, wall) -- 뒤
	B:wall("Z", -30.5, -22, 22, FLOOR_Y, WALL_HEIGHT, nil, wall) -- 왼쪽
	B:wall("Z", 30.5, -22, 22, FLOOR_Y, WALL_HEIGHT, nil, wall) -- 오른쪽
	-- 출입문 바깥은 막아 둬요 (나가 버리지 않게)
	B:part(Vector3.new(8, WALL_HEIGHT, 1), v(0, WALL_HEIGHT / 2, -25), wall)
	B:part(Vector3.new(1, WALL_HEIGHT, 3), v(-4, WALL_HEIGHT / 2, -24), wall)
	B:part(Vector3.new(1, WALL_HEIGHT, 3), v(4, WALL_HEIGHT / 2, -24), wall)

	-- 창문 (앞 벽 안쪽에 붙은 유리)
	for _, x in { -22, -12, 12, 22 } do
		B:part(Vector3.new(7, 5, 0.2), v(x, 6, -21.9), {
			Color = Color3.fromRGB(170, 210, 240),
			Material = Enum.Material.Glass,
			Transparency = 0.3,
		})
	end

	-- 사훈 현수막과 벽시계 (직원들이 앉으면 정면에 보여요)
	local banner = B:part(Vector3.new(16, 2.5, 0.2), v(0, 10, -21.85), { Color = Color3.fromRGB(170, 30, 40) })
	Build.surfaceText(banner, Enum.NormalId.Back, "사훈: 열정! 도전! 혁신! 우리는 가족입니다", {
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
	B:part(Vector3.new(3, 3.5, 3), v(7, 1.75, 19.5), { Color = Color3.fromRGB(60, 30, 25), Material = Enum.Material.Leather }) -- 부장 의자 (옆으로 빼 둠)

	-- 화장실 (왼쪽 뒤) : 부장이 들어오지 않는 안전지대
	B:wall("Z", -20.5, 10, 22, FLOOR_Y, WALL_HEIGHT, { { center = 13, width = 4, height = 8 } }, wall)
	B:wall("X", 10.5, -30, -20, FLOOR_Y, WALL_HEIGHT, nil, wall)
	B:part(Vector3.new(9, 0.2, 11), v(-25.5, 0.1, 16.5), { Color = COLORS.tile, Material = Enum.Material.Marble })
	for _, z in { 15, 19.5 } do
		B:part(Vector3.new(0.3, 7, 4), v(-26, 3.5, z), { Color = Color3.fromRGB(150, 190, 200) }) -- 칸막이
		B:part(Vector3.new(2, 1.6, 2.4), v(-28.5, 0.8, z), { Color = Color3.fromRGB(245, 245, 245) }) -- 변기
	end
	local toiletSign = B:part(Vector3.new(0.2, 1.5, 3), v(-19.85, 9, 13), { Color = Color3.fromRGB(40, 90, 160) })
	Build.surfaceText(toiletSign, Enum.NormalId.Right, "🚻 화장실")
	local toiletZone = zone(B, "ToiletZone", Vector3.new(9, 10, 11), v(-25.5, 5, 16.5))

	-- 탕비실 (오른쪽 뒤)
	B:wall("Z", 20.5, 10, 22, FLOOR_Y, WALL_HEIGHT, { { center = 13, width = 4, height = 8 } }, wall)
	B:wall("X", 10.5, 20, 30, FLOOR_Y, WALL_HEIGHT, nil, wall)
	B:part(Vector3.new(2.5, 3, 9), v(28.5, 1.5, 16.5), { Color = Color3.fromRGB(230, 230, 230) }) -- 조리대
	B:part(Vector3.new(1.4, 2, 1.4), v(28.5, 4, 14), { Color = Color3.fromRGB(30, 30, 30) }) -- 커피머신
	B:part(Vector3.new(2.5, 7, 2.5), v(28.5, 3.5, 20.5), { Color = Color3.fromRGB(200, 200, 205), Material = Enum.Material.Metal }) -- 냉장고
	B:part(Vector3.new(1.2, 4, 1.2), v(22.5, 2, 21), { Color = Color3.fromRGB(240, 240, 250) }) -- 정수기
	local pantrySign = B:part(Vector3.new(0.2, 1.5, 3), v(19.85, 9, 13), { Color = COLORS.accent })
	Build.surfaceText(pantrySign, Enum.NormalId.Left, "☕ 탕비실")
	local pantryZone = zone(B, "PantryZone", Vector3.new(9, 10, 11), v(25.5, 5, 16.5))

	-- 장식: 화분, 프린터
	for _, position in { v(-28, 0, -20), v(28, 0, -20), v(-28, 0, 4), v(28, 0, 4) } do
		B:part(Vector3.new(1.6, 1.6, 1.6), position + Vector3.new(0, 0.8, 0), { Color = Color3.fromRGB(150, 90, 60) })
		B:part(Vector3.new(2.4, 2.4, 2.4), position + Vector3.new(0, 2.6, 0), {
			Shape = Enum.PartType.Ball,
			Color = Color3.fromRGB(70, 140, 70),
			Material = Enum.Material.Grass,
		})
	end
	B:part(Vector3.new(3, 2.5, 2.5), v(-27, 1.25, -8), { Color = Color3.fromRGB(220, 220, 225) }) -- 프린터

	-- 형광등
	for _, x in { -16, 0, 16 } do
		for _, z in { -12, 2, 14 } do
			local lamp = B:part(Vector3.new(6, 0.3, 1.2), v(x, WALL_HEIGHT - 0.2, z), {
				Color = Color3.fromRGB(245, 250, 255),
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
			local light = Instance.new("PointLight")
			light.Range = 22
			light.Brightness = 0.8
			light.Color = Color3.fromRGB(235, 245, 255)
			light.Parent = lamp
		end
	end

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
		v(17, 0, 13), -- 탕비실 문 앞 (안을 들여다봐요)
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
		setClock = setClock,
	}
end

return OfficeBuilder
