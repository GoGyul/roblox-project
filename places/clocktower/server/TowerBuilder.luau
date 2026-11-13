-- 시계탑 짓기: 3층짜리 탑을 "현재"와 "과거" 두 벌 지어요.
--
--   3층 기계실   ─┐ (서쪽 계단)
--   2층 서재/온실 ─┤
--                 └ (동쪽 계단)
--   1층 작업실
--
-- 방 하나는 안쪽 40×40, 높이 19. 각 층 바닥 높이 = floorY(n)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(ReplicatedStorage.Shared.Build)

local TowerBuilder = {}

local function floorY(n: number): number
	return (n - 1) * 20 + 1
end
TowerBuilder.floorY = floorY

local PALETTES = {
	present = {
		wall = Color3.fromRGB(88, 82, 78),
		floor = Color3.fromRGB(70, 58, 48),
		wood = Color3.fromRGB(76, 58, 44),
		metal = Color3.fromRGB(110, 86, 60),
		metalMaterial = Enum.Material.CorrodedMetal,
		paper = Color3.fromRGB(190, 180, 150),
		light = Color3.fromRGB(170, 190, 255),
		lightBrightness = 0.9,
	},
	past = {
		wall = Color3.fromRGB(196, 156, 116),
		floor = Color3.fromRGB(150, 100, 62),
		wood = Color3.fromRGB(128, 82, 46),
		metal = Color3.fromRGB(205, 168, 80),
		metalMaterial = Enum.Material.Metal,
		paper = Color3.fromRGB(245, 238, 215),
		light = Color3.fromRGB(255, 205, 140),
		lightBrightness = 1.6,
	},
}

local function door(z: number): Build.Door
	return { center = z, width = 6, height = 9 }
end

---------------------------------------------------------------------------
-- 뼈대: 바닥, 벽, 지붕, 계단
---------------------------------------------------------------------------

-- side = 1 이면 동쪽(+X), -1 이면 서쪽(-X). y0층에서 y0+20층으로 올라가는 계단실
local function buildStairwell(B, pal, side: number, y0: number)
	local s = side
	local wall = { Color = pal.wall, Material = Enum.Material.Brick }
	local stair = { Color = pal.wood, Material = Enum.Material.WoodPlanks }

	B:part(Vector3.new(9, 1, 44), Vector3.new(25.5 * s, y0 - 0.5, 0), stair) -- 바닥
	B:part(Vector3.new(1, 39, 44), Vector3.new(29.5 * s, y0 + 19.5, 0), wall) -- 바깥 벽
	B:part(Vector3.new(9, 39, 1), Vector3.new(25.5 * s, y0 + 19.5, 21.5), wall)
	B:part(Vector3.new(9, 39, 1), Vector3.new(25.5 * s, y0 + 19.5, -21.5), wall)
	B:part(Vector3.new(9, 1, 44), Vector3.new(25.5 * s, y0 + 39.5, 0), wall) -- 지붕

	-- 계단: z=+10에서 시작해 -Z 방향으로 한 칸에 1씩 올라가요
	for i = 1, 20 do
		B:part(Vector3.new(8, i, 1), Vector3.new(25 * s, y0 + i / 2, 10.5 - i), stair)
	end
	B:part(Vector3.new(8, 20, 11), Vector3.new(25 * s, y0 + 10, -15.5), stair) -- 위층 참

	B:lamp(Vector3.new(25 * s, y0 + 38.5, 0), pal.light, pal.lightBrightness)
end

local function buildShell(B, pal)
	local wall = { Color = pal.wall, Material = Enum.Material.Brick }
	local floor = { Color = pal.floor, Material = Enum.Material.WoodPlanks }

	-- 층별 문 위치: 1층 동쪽(계단 아래) / 2층 동쪽(계단 위), 서쪽(계단 아래) / 3층 서쪽(계단 위)
	local doors = {
		{ east = { door(14) }, west = {} },
		{ east = { door(-14) }, west = { door(14) } },
		{ east = {}, west = { door(-14) } },
	}

	for n = 1, 3 do
		local y = floorY(n)
		B:part(Vector3.new(42, 1, 42), Vector3.new(0, y - 0.5, 0), floor)
		B:wall("X", -20.5, -21, 21, y, 19, nil, wall) -- 북쪽
		B:wall("X", 20.5, -21, 21, y, 19, nil, wall) -- 남쪽
		B:wall("Z", 20.5, -20, 20, y, 19, doors[n].east, wall) -- 동쪽
		B:wall("Z", -20.5, -20, 20, y, 19, doors[n].west, wall) -- 서쪽
		B:lamp(Vector3.new(0, y + 18.5, 0), pal.light, pal.lightBrightness)
	end
	B:part(Vector3.new(42, 1, 42), Vector3.new(0, floorY(3) + 19.5, 0), wall) -- 지붕

	buildStairwell(B, pal, 1, floorY(1))
	buildStairwell(B, pal, -1, floorY(2))
end

---------------------------------------------------------------------------
-- 1층: 시계공의 작업실
---------------------------------------------------------------------------
local function buildFloor1(B, era: string, pal, refs)
	local y = floorY(1)
	local wood = { Color = pal.wood, Material = Enum.Material.Wood }

	-- 책상과 서랍
	B:part(Vector3.new(8, 3, 4), Vector3.new(-10, y + 1.5, 6), wood)
	refs.drawer = B:part(Vector3.new(3, 1, 0.3), Vector3.new(-10, y + 2, 8.15), {
		Color = pal.metal,
		Material = pal.metalMaterial,
	})

	-- 북쪽 벽의 시계 세 개
	refs.wallClocks = {}
	for i, x in { -8, 0, 8 } do
		local face = B:part(Vector3.new(4, 4, 0.3), Vector3.new(x, y + 9, -19.85), wood)
		refs.wallClocks[i] = Build.clockFace(face, Enum.NormalId.Back)
	end

	-- 장식: 작업대, 책장
	B:part(Vector3.new(10, 3, 4), Vector3.new(10, y + 1.5, -15), wood)
	B:gear(Vector3.new(8, y + 4, -15), 1, pal.metal, pal.metalMaterial)
	B:gear(Vector3.new(12, y + 3.8, -15), 0.8, pal.metal, pal.metalMaterial)
	B:part(Vector3.new(1.5, 10, 8), Vector3.new(-19, y + 5, -8), wood)

	if era == "present" then
		-- 구겨진 쪽지
		refs.note = B:part(Vector3.new(1.2, 0.1, 1.6), Vector3.new(-8, y + 3.05, 6), { Color = pal.paper })

		-- 계단 문을 막은 무너진 들보
		refs.rubble = B:part(Vector3.new(2, 9, 6), Vector3.new(20.5, y + 4.5, 14), wood)
		B:part(Vector3.new(1.2, 1.2, 11), nil, {
			CFrame = CFrame.new(18.6, y + 4, 14) * CFrame.Angles(math.rad(40), 0, 0),
			Color = pal.wood,
			Material = Enum.Material.Wood,
		})
		B:part(Vector3.new(1, 1, 9), nil, {
			CFrame = CFrame.new(18.8, y + 2.5, 13) * CFrame.Angles(math.rad(-30), math.rad(10), 0),
			Color = pal.wood,
			Material = Enum.Material.Wood,
		})

		-- 시작 지점 (현재 1층)
		B:part(Vector3.new(6, 1, 6), Vector3.new(0, y + 0.5, 12), {
			ClassName = "SpawnLocation",
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			Neutral = true,
			Duration = 0,
		})
	else
		-- 시계공의 일기장
		refs.diary = B:part(Vector3.new(1.5, 0.4, 2), Vector3.new(-12, y + 3.2, 6), {
			Color = Color3.fromRGB(110, 40, 30),
		})
	end
end

---------------------------------------------------------------------------
-- 2층: 서재 겸 온실
---------------------------------------------------------------------------
local function buildFloor2(B, era: string, pal, refs)
	local y = floorY(2)
	local wood = { Color = pal.wood, Material = Enum.Material.Wood }

	-- 화분 (과거: 흙이 담김 / 현재: 말라 갈라짐)
	refs.pot = B:part(Vector3.new(3, 2, 3), Vector3.new(-10, y + 1, -10), {
		Color = if era == "past" then Color3.fromRGB(180, 90, 60) else Color3.fromRGB(120, 85, 70),
		Material = Enum.Material.Slate,
	})
	if era == "past" then
		B:part(Vector3.new(2.6, 0.2, 2.6), Vector3.new(-10, y + 2.05, -10), {
			Color = Color3.fromRGB(70, 45, 30),
			Material = Enum.Material.Ground,
		})
	end

	-- 손이 닿지 않는 높은 선반
	B:part(Vector3.new(8, 1, 4), Vector3.new(-10, y + 12, -18), wood)
	if era == "present" then
		refs.gearSmall = B:part(Vector3.new(0.4, 2, 2), nil, {
			Shape = Enum.PartType.Cylinder,
			CFrame = CFrame.new(-10, y + 13.5, -18) * CFrame.Angles(0, math.rad(90), 0),
			Color = Color3.fromRGB(200, 160, 70),
			Material = Enum.Material.Metal,
		})
	end

	-- 씨앗 선반
	B:part(Vector3.new(6, 0.5, 2), Vector3.new(10, y + 4, -19), wood)
	if era == "present" then
		refs.seed = B:part(Vector3.new(1, 1.4, 0.3), Vector3.new(10, y + 4.95, -19), {
			Color = Color3.fromRGB(170, 140, 90),
		})
	end

	-- 남쪽 벽 칠판
	local board = B:part(Vector3.new(12, 6, 0.3), Vector3.new(0, y + 8, 19.85), {
		Color = Color3.fromRGB(35, 60, 45),
	})
	if era == "past" then
		Build.surfaceText(board, Enum.NormalId.Front, "금고 번호를 잊지 말 것!\n1 8 9 2")
	else
		Build.surfaceText(board, Enum.NormalId.Front, "금고 번호를 잊지 말 것!\n1 8 ▒ ▒", {
			TextTransparency = 0.55,
		})
	end

	-- 금고
	refs.safe = B:part(Vector3.new(4, 4, 4), Vector3.new(13, y + 2, 10), {
		Color = pal.metal,
		Material = pal.metalMaterial,
	})

	-- 3층으로 가는 서쪽 문
	if era == "past" then
		refs.lockedDoor = B:part(Vector3.new(1, 9, 6), Vector3.new(-20.5, y + 4.5, 14), wood)
	else
		-- 썩어서 쓰러진 문짝
		B:part(Vector3.new(4, 0.4, 6), nil, {
			CFrame = CFrame.new(-17, y + 0.6, 14) * CFrame.Angles(0, 0, math.rad(8)),
			Color = pal.wood,
			Material = Enum.Material.Wood,
		})
	end

	-- 장식: 책상
	B:part(Vector3.new(6, 3, 3), Vector3.new(10, y + 1.5, 4), wood)
end

---------------------------------------------------------------------------
-- 3층: 기계실
---------------------------------------------------------------------------
local GEAR_SLOTS = {
	{ id = "gearSmall", x = -7, radius = 2, speed = 1.6 },
	{ id = "gearMedium", x = 0, radius = 2.6, speed = -1.25 },
	{ id = "gearLarge", x = 7, radius = 3.2, speed = 1.0 },
}
TowerBuilder.GEAR_SLOTS = GEAR_SLOTS

local function buildFloor3(B, era: string, pal, refs)
	local y = floorY(3)
	local wood = { Color = pal.wood, Material = Enum.Material.Wood }
	local gearColor = Color3.fromRGB(205, 165, 75)

	-- 커다란 기계장치 틀
	refs.mechanism = B:part(Vector3.new(22, 12, 1), Vector3.new(0, y + 8, -19.5), {
		Color = Color3.fromRGB(60, 50, 45),
		Material = pal.metalMaterial,
	})
	refs.gearSlots = {}
	for _, slot in GEAR_SLOTS do
		local position = Vector3.new(slot.x, y + 8, -18.6)
		if era == "past" then
			-- 과거: 톱니바퀴 세 개가 맞물려 돌아가고 있어요
			local model, base = B:gear(position, slot.radius, gearColor)
			table.insert(refs.gearSlots, { model = model, base = base, speed = slot.speed })
		else
			-- 현재: 빈 축만 남아 있어요
			B:part(Vector3.new(0.6, 0.8, 0.8), nil, {
				Shape = Enum.PartType.Cylinder,
				CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(90), 0),
				Color = Color3.fromRGB(40, 35, 30),
			})
			refs.gearSlots[slot.id] = { position = position, radius = slot.radius, speed = slot.speed }
		end
	end

	-- 동쪽 벽의 큰 시계판과 시침 손잡이
	local face = B:part(Vector3.new(0.3, 10, 10), Vector3.new(19.85, y + 9, 0), wood)
	refs.bigClock = Build.clockFace(face, Enum.NormalId.Left)
	refs.clockHandle = B:part(Vector3.new(1, 1, 3), Vector3.new(19.2, y + 3, 0), {
		Color = pal.metal,
		Material = pal.metalMaterial,
	})

	-- 레버
	B:part(Vector3.new(2, 1, 2), Vector3.new(-12, y + 0.5, 10), { Color = Color3.fromRGB(50, 45, 40) })
	refs.leverHandle = B:part(Vector3.new(0.4, 3.5, 0.4), nil, {
		CFrame = CFrame.new(-12, y + 2.5, 10) * CFrame.Angles(math.rad(if era == "past" then 30 else -30), 0, 0),
		Color = Color3.fromRGB(170, 40, 40),
	})

	-- 작업대
	B:part(Vector3.new(8, 3, 3), Vector3.new(10, y + 1.5, 12), wood)

	if era == "past" then
		refs.oil = B:part(Vector3.new(1.2, 1.6, 1.2), Vector3.new(10, y + 3.8, 12), {
			Color = Color3.fromRGB(170, 50, 40),
			Material = Enum.Material.Metal,
		})
	else
		-- 바닥에 녹슬어 붙은 큰 톱니바퀴
		refs.rustyGear = B:part(Vector3.new(0.4, 5, 5), nil, {
			Shape = Enum.PartType.Cylinder,
			CFrame = CFrame.new(8, y + 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(140, 75, 40),
			Material = Enum.Material.CorrodedMetal,
		})
		-- 서쪽 벽의 메모
		refs.memo = B:part(Vector3.new(0.1, 2, 1.6), Vector3.new(-19.9, y + 5, -8), { Color = pal.paper })
	end
end

---------------------------------------------------------------------------

export type Tower = {
	folder: Folder,
	builders: { [string]: any },
	refs: { [string]: { [string]: any } },
}

function TowerBuilder.build(): Tower
	local old = workspace:FindFirstChild("Tower")
	if old then
		old:Destroy()
	end
	-- 템플릿의 기본 스폰 지점 제거 (탑 안에서 시작해야 하니까)
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") then
			descendant:Destroy()
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = "Tower"
	folder.Parent = workspace

	local builders, refs = {}, {}
	for era, offset in { present = Vector3.zero, past = Config.ERA_OFFSET } do
		local eraFolder = Instance.new("Folder")
		eraFolder.Name = era
		eraFolder.Parent = folder

		local B = Build.new(eraFolder, offset)
		local pal = PALETTES[era]
		local eraRefs = {}
		buildShell(B, pal)
		buildFloor1(B, era, pal, eraRefs)
		buildFloor2(B, era, pal, eraRefs)
		buildFloor3(B, era, pal, eraRefs)

		builders[era] = B
		refs[era] = eraRefs
	end

	return { folder = folder, builders = builders, refs = refs }
end

return TowerBuilder
