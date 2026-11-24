-- 🏙️ 눈치 스트리트 (회사 단지 남쪽 가게 거리): 가게 9칸 + 위층 건물
--   들어갈 수 있는 가게 4곳: ☕ 눈치 커피 · 🍰 달콤 디저트 · 🧸 뽑기 천국 · 🕹️ 오락실
--   구경만 되는 가게 5곳: 꽃집 · 서점 · 미용실 · 약국 · 문구점 (유리창 안 진열만 보여요)
--   가구는 street_shops_set 메시예요 (tools/blender/street_shops_set.py). 메시를 못 불러오면 상자 모양으로 대신 지어요.
--
--   가게 한 칸: 단지 좌표로 가운데 x, 유리 앞면 z 109, 뒷벽 z 127 (안쪽 폭 47 · 깊이 18 · 천장 13.5).
--   가게 안 가구는 "가게 좌표"로 놓아요 (시안 그림과 같은 좌표): 길에서 가게를 봤을 때 오른쪽이 +x, 길 쪽이 +z, 뒷벽이 z -9.
--   계산대·기계 같은 기능 파트(주문 [E], 뽑기, 돌림판…)는 보이지 않는 상자로 두고 메시를 겹쳐요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Build = require(ReplicatedStorage.Shared.Build)
local Theme = require(ReplicatedStorage.Shared.SalaryTheme)
local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local Meshes = require(script.Parent.Meshes)

local CampusStreet = {}

local M = Theme.Mesh
local CEILING = 13.5
local BLOCK = Color3.fromRGB(204, 196, 182)
local DARK = Color3.fromRGB(52, 56, 62)

-- F: Campus가 게임 모듈에 넘겨줄 표 (shops, clawMachines, wheel, dart, arcade를 여기서 채워요)
function CampusStreet.build(folder: Instance, ORIGIN: Vector3, F: any, HALF_X: number)
	local B = Build.new(folder, ORIGIN)
	local random = Random.new(11)
	local function P(size: Vector3, position: Vector3?, props: { [string]: any }?): BasePart
		local part = B:part(size, position, props)
		if part.Transparency >= 1 then
			part.CastShadow = false
		end
		return part
	end
	local function deco(size: Vector3, position: Vector3, color: Color3, material: Enum.Material?, extra: { [string]: any }?): BasePart
		local props: { [string]: any } = { Color = color, Material = material or Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false, CastShadow = false }
		for key, value in extra or {} do
			props[key] = value
		end
		return P(size, position, props)
	end
	local function text(part: BasePart, face: Enum.NormalId, message: string, color: Color3?)
		Build.surfaceText(part, face, message, { Font = Enum.Font.GothamBold, TextColor3 = color or Color3.new(1, 1, 1) })
	end
	-- 단지 좌표에 메시 하나 (앞 = 북쪽 길을 보게 하려면 yaw 180)
	local function mesh(kind: string, x: number, z: number, yaw: number?, options: any?, y: number?)
		if Meshes.ready(kind) then
			return Meshes.place(B, kind, Vector3.new(x, y or 0, z), yaw or 0, options)
		end
		return nil
	end

	---------------------------------------------------------------- 위층 건물
	P(Vector3.new(HALF_X * 2 - 20, 44, 26), Vector3.new(0, 36, 122), { Color = BLOCK, Material = Enum.Material.Concrete, CastShadow = false })
	P(Vector3.new(HALF_X * 2 - 20, 14, 7), Vector3.new(0, 7, 131.5), { Color = BLOCK, Material = Enum.Material.Concrete })

	---------------------------------------------------------------- 가게 한 칸의 "가게 좌표" 도구
	-- 가게 좌표 → 그 가게에 놓는 빌더 (가게 가운데 바닥이 원점, 180° 돌려서 +z가 길 쪽)
	local function sceneOf(x: number)
		local S = Build.new(folder, CFrame.new(ORIGIN + Vector3.new(x, 0, 118)) * CFrame.Angles(0, math.pi, 0))
		local scene = {}
		function scene.world(lx: number, ly: number, lz: number): Vector3
			return S:cf(CFrame.new(lx, ly, lz)).Position
		end
		-- 가구 하나: rot는 시안 스크립트와 같은 각도(-90이면 앞이 +x를 봐요). box를 주면 그 크기의 보이지 않는 충돌 상자도 놓아요.
		function scene.put(kind: string, lx: number, lz: number, rot: number?, options: any?, y: number?, box: Vector3?): { [string]: MeshPart }?
			local parts = nil
			if Meshes.ready(kind) then
				parts = Meshes.place(S, kind, Vector3.new(lx, y or 0, lz), -(rot or 0), options)
			end
			if box then
				local turned = math.abs(rot or 0) % 180 == 90
				local size = if turned then Vector3.new(box.Z, box.Y, box.X) else box
				S:part(size, Vector3.new(lx, (y or 0) + box.Y / 2, lz), { Transparency = if parts then 1 else 0, Color = M.surface, CastShadow = parts == nil })
			end
			return parts
		end
		-- 기능 파트 (주문·게임 [E]가 붙어요): 메시가 있으면 투명, 없으면 보이는 상자
		function scene.proxy(name: string, kind: string?, size: Vector3, lx: number, ly: number, lz: number, color: Color3?): BasePart
			local hidden = kind ~= nil and Meshes.ready(kind)
			return S:part(size, Vector3.new(lx, ly, lz), { Name = name, Color = color or M.woodLight, Transparency = if hidden then 1 else 0, CastShadow = not hidden })
		end
		function scene.part(size: Vector3, lx: number, ly: number, lz: number, props: { [string]: any }): BasePart
			return S:part(size, Vector3.new(lx, ly, lz), props)
		end
		function scene.deco(size: Vector3, lx: number, ly: number, lz: number, color: Color3, material: Enum.Material?, extra: { [string]: any }?): BasePart
			local props: { [string]: any } = { Color = color, Material = material or Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false, CastShadow = false }
			for key, value in extra or {} do
				props[key] = value
			end
			return S:part(size, Vector3.new(lx, ly, lz), props)
		end
		-- 길 쪽에서 읽는 작은 이름표
		function scene.label(lx: number, ly: number, lz: number, width: number, message: string)
			local sign = scene.deco(Vector3.new(width, 0.9, 0.2), lx, ly, lz, Color3.fromRGB(30, 30, 40))
			Build.surfaceText(sign, Enum.NormalId.Back, message, { Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 230, 120) })
		end
		-- 천장 조명 (전구에 실제 불빛)
		function scene.lamps(points: { { number } }, color: Color3?, brightness: number?)
			for _, point in points do
				local lamp = scene.put("PendantLamp", point[1], point[2], 0, nil, CEILING)
				local holder: BasePart = if lamp then lamp.Bulb else scene.deco(Vector3.new(1.4, 0.3, 1.4), point[1], CEILING - 0.3, point[2], Color3.fromRGB(255, 240, 214), Enum.Material.Neon)
				local glow = Instance.new("PointLight")
				glow.Range = 20
				glow.Brightness = brightness or 0.75
				glow.Color = color or Color3.fromRGB(255, 240, 214)
				glow.Shadows = false
				glow.Parent = holder
			end
		end
		function scene.rug(lx: number, lz: number, radius: number, color: Color3)
			local rug = scene.deco(Vector3.new(0.08, radius * 2, radius * 2), lx, 0.16, lz, color, Enum.Material.Fabric)
			rug.Shape = Enum.PartType.Cylinder
			rug.CFrame *= CFrame.Angles(0, 0, math.rad(90))
		end
		scene.look = Vector3.new(0, 0, -1) -- 점원이 보는 쪽 (길 = 북쪽)
		return scene
	end

	---------------------------------------------------------------- 가게 9칸의 뼈대 (앞면 · 간판 · 차양 · 안쪽 벽)
	local SHOPS: { any } = {
		{ name = "꽃집", accent = M.coral },
		{ name = "서점", accent = M.mintDark },
		{ name = "☕ 눈치 커피", accent = M.mintDark, id = "cafe", wall = Color3.fromRGB(236, 232, 222), wainscot = M.mintDark, floor = M.woodLight },
		{ name = "🍰 달콤 디저트", accent = M.blush, id = "dessert", wall = M.cakeCream, wainscot = M.blush, floor = M.woodLight },
		{ name = "🧸 뽑기 천국", accent = M.yellow, id = "claw", wall = Color3.fromRGB(236, 232, 222), wainscot = M.yellow, floor = M.cakeCream, tile = true },
		{ name = "🕹️ 오락실", accent = M.lilac, id = "arcade", wall = M.arcade, floor = M.ink, dark = true },
		{ name = "미용실", accent = M.yellow },
		{ name = "약국", accent = M.sky },
		{ name = "문구점", accent = M.coral },
	}
	local shopGlass = { Color = Color3.fromRGB(176, 206, 214), Material = Enum.Material.Glass, Transparency = 0.5 }
	local shopX: { [string]: number } = {}
	for i, shop in SHOPS do
		local x = -208 + (i - 1) * 52
		-- 간판 (위) · 줄무늬 차양 · 돌출 간판
		local board = deco(Vector3.new(40, 3.6, 1.0), Vector3.new(x, 15.9, 108.5), Color3.fromRGB(34, 36, 42))
		text(board, Enum.NormalId.Front, shop.name, Color3.fromRGB(255, 244, 226))
		deco(Vector3.new(41, 0.3, 1.1), Vector3.new(x, 13.95, 108.5), shop.accent)
		local signLight = Instance.new("PointLight")
		signLight.Range = 18
		signLight.Brightness = 0.45
		signLight.Parent = board
		if Meshes.ready("ShopAwning") then
			for _, dx in { -14.6, 0, 14.6 } do
				mesh("ShopAwning", x + dx, 108.7, 180, { stretch = Vector3.new(14.2 / 12, 1, 1), colors = { StripeA = shop.accent } }, 13.4)
			end
		else
			local awning = deco(Vector3.new(42, 0.4, 5), Vector3.new(x, 12.9, 106), shop.accent, Enum.Material.Fabric)
			awning.CFrame *= CFrame.Angles(math.rad(-14), 0, 0)
		end
		mesh("BladeSign", x - 23.4, 107.6, 90, { colors = { Board = shop.accent } }, 12.2)
		P(Vector3.new(47, 1.2, 0.8), Vector3.new(x, 12.9, 109), { Color = BLOCK, Material = Enum.Material.Concrete }) -- 유리 위 띠
		P(Vector3.new(47, 0.5, 0.8), Vector3.new(x, 0.25, 109), { Color = DARK, Material = Enum.Material.Metal, CanCollide = shop.id == nil }) -- 유리 아래 턱
		if not shop.id then
			-- 구경만 되는 가게: 유리 뒤 진열 공간(깊이 6) + 막힌 안쪽
			P(Vector3.new(47, 11.8, 0.5), Vector3.new(x, 6.4, 109), shopGlass)
			deco(Vector3.new(46.6, 0.12, 6), Vector3.new(x, 0.06, 112.3), M.woodLight, Enum.Material.WoodPlanks)
			deco(Vector3.new(46.6, 12.4, 0.3), Vector3.new(x, 6.2, 115.5), Color3.fromRGB(236, 232, 222))
			deco(Vector3.new(46.6, 3, 0.1), Vector3.new(x, 1.5, 115.3), shop.accent)
			P(Vector3.new(47, 14, 12.6), Vector3.new(x, 7, 122), { Color = BLOCK, Material = Enum.Material.Concrete })
			local glow = Instance.new("PointLight")
			glow.Range = 22
			glow.Brightness = 0.6
			glow.Color = Color3.fromRGB(255, 240, 214)
			glow.Parent = deco(Vector3.new(30, 0.2, 1), Vector3.new(x, 12.2, 112.3), Color3.fromRGB(255, 240, 214), Enum.Material.Neon)
			mesh("ShopPlanter", x - 12, 106.9, 180)
			mesh("ShopPlanter", x + 12, 106.9, 180)
			continue
		end
		shopX[shop.id] = x
		-- 앞면: 유리창 두 장 + 가운데 문 (폭 10 · 높이 10) + 문 위 유리
		for _, dx in { -14.25, 14.25 } do
			P(Vector3.new(18.5, 11.8, 0.5), Vector3.new(x + dx, 6.4, 109), shopGlass)
		end
		P(Vector3.new(10, 2.3, 0.5), Vector3.new(x, 11.15, 109), shopGlass)
		if Meshes.ready("ShopDoor") then
			mesh("ShopDoor", x, 109, 180)
		else
			for _, dx in { -5.1, 5.1 } do
				P(Vector3.new(0.4, 10, 0.7), Vector3.new(x + dx, 5, 109), { Color = DARK, Material = Enum.Material.Metal })
			end
		end
		-- 안: 바닥 · 뒷벽 · 옆벽 · 허리벽 · 천장
		deco(Vector3.new(46.8, 0.12, 18.6), Vector3.new(x, 0.06, 118.4), shop.floor, if shop.dark then Enum.Material.Carpet elseif shop.tile then Enum.Material.Marble else Enum.Material.WoodPlanks)
		P(Vector3.new(47, 14, 1), Vector3.new(x, 7, 127.5), { Color = shop.wall, Material = Enum.Material.Plaster })
		deco(Vector3.new(46.8, 0.3, 17.6), Vector3.new(x, 13.7, 118.2), if shop.dark then M.ink else shop.wall)
		for _, dx in { -23.42, 23.42 } do
			deco(Vector3.new(0.12, 13.5, 17.6), Vector3.new(x + dx, 6.8, 118.2), shop.wall, Enum.Material.Plaster)
		end
		if shop.wainscot then
			deco(Vector3.new(46.8, 3.2, 0.12), Vector3.new(x, 1.6, 126.94), shop.wainscot)
			for _, dx in { -23.34, 23.34 } do
				deco(Vector3.new(0.12, 3.2, 17.6), Vector3.new(x + dx, 1.6, 118.2), shop.wainscot)
			end
		end
		-- 가게 앞: 화분 두 개 + 입간판
		for _, dx in { -9.5, 9.5 } do
			mesh("ShopPlanter", x + dx, 106.9, 180)
			P(Vector3.new(6, 2.4, 1.5), Vector3.new(x + dx, 1.2, 106.9), { Transparency = 1 })
		end
		mesh("ABoard", x + 15.5, 105.4, 195)
	end

	---------------------------------------------------------------- ☕ 눈치 커피
	do
		local s = sceneOf(shopX.cafe)
		s.put("MenuBoard", 0, -8.9, 0, nil, 9.2)
		s.put("CafeBar", 0, -5.4)
		local cafeCounter = s.proxy("ShopCounter", "CafeBar", Vector3.new(12.2, 3.6, 2.9), 0, 1.8, -5.4, M.wood)
		s.put("EspressoMachine", -3.2, -5.5, 0, nil, 3.64)
		s.put("PastryCase", 3.0, -5.3, 0, nil, 3.64)
		for _, lx in { -9.5, 9.5 } do
			s.put("WallShelf", lx, -8.95, 0, nil, 7.2)
			s.put("WallShelf", lx, -8.95, 0, nil, 9.6)
		end
		-- 왼쪽: 벽 소파 + 탁자
		for _, lz in { -3.5, 3.0 } do
			s.put("BoothSofa", -21.8, lz, -90, nil, 0, Vector3.new(6, 2.4, 2.2))
			s.put("CafeTable", -18.2, lz, 0, nil, 0, Vector3.new(1.2, 2.7, 1.2))
			s.put("CafeChair", -15.6, lz, 90)
		end
		-- 오른쪽: 러그 위 둥근 탁자 세 개
		s.rug(14.5, 1.0, 7.5, M.mintDark)
		for _, xz in { { 10.5, -1.5 }, { 17.5, -0.5 }, { 13.5, 4.0 } } do
			s.put("CafeTable", xz[1], xz[2], 0, nil, 0, Vector3.new(1.2, 2.7, 1.2))
			s.put("CafeChair", xz[1] - 2.3, xz[2], -90)
			s.put("CafeChair", xz[1] + 2.3, xz[2], 90)
		end
		-- 창가 높은 자리
		s.deco(Vector3.new(9, 0.25, 1.6), -10.5, 3.3, 7.9, M.woodLight, Enum.Material.Wood)
		for _, lx in { -13, -10.5, -8 } do
			s.put("BarStool", lx, 6.4)
		end
		s.put("Plant", 21.5, -7.2, 0, { scale = 1.8 })
		s.put("Plant", -5.4, 7.6, 0, { scale = 1.5 })
		s.lamps({ { -4, -5 }, { 0, -5 }, { 4, -5 }, { -18.2, -3.5 }, { -18.2, 3.0 }, { 10.5, -1.5 }, { 17.5, -0.5 }, { 13.5, 4.0 } })
		F.shops.cafe = { counter = cafeCounter, clerkSpot = s.world(0, 0, -7.6), clerkLook = s.look }
	end

	---------------------------------------------------------------- 🍰 달콤 디저트
	do
		local s = sceneOf(shopX.dessert)
		s.put("DessertShowcase", -4.5, -5.6, 0, nil, 0, Vector3.new(8, 4, 2.6))
		s.put("DessertCounter", 4.2, -5.6)
		local dessertCounter = s.proxy("ShopCounter", "DessertCounter", Vector3.new(6.2, 3.5, 2.4), 4.2, 1.75, -5.6, M.blush)
		s.put("CakeStand", 3.0, -5.4, 0, nil, 3.53)
		s.put("MenuBoard", 0, -8.9, 0, nil, 9.4)
		s.put("WallShelf", -12, -8.95, 0, nil, 7.4)
		s.put("WallShelf", 12, -8.95, 0, nil, 7.4)
		s.put("CupcakeSign", -19.5, 4.5, 0, nil, 0, Vector3.new(3, 5.2, 3))
		local pinkSofa = { colors = { Seat = M.blush, Back = M.blush, Base = M.cakeCream } }
		local whiteTable = { colors = { Top = M.cakeCream, Base = M.gold } }
		local pinkChair = { colors = { Seat = M.blush, Back = M.blush, Frame = M.gold } }
		for _, lz in { -4.5, 1.5 } do
			s.put("BoothSofa", 21.8, lz, 90, pinkSofa, 0, Vector3.new(6, 2.4, 2.2))
			s.put("CafeTable", 18.2, lz, 0, whiteTable, 0, Vector3.new(1.2, 2.7, 1.2))
			s.put("CafeChair", 15.6, lz, -90, pinkChair)
		end
		s.rug(-12.5, 0.5, 6.2, M.blush)
		for _, xz in { { -14.5, -1.0 }, { -10.0, 2.5 } } do
			s.put("CafeTable", xz[1], xz[2], 0, whiteTable, 0, Vector3.new(1.2, 2.7, 1.2))
			s.put("CakeStand", xz[1], xz[2], 0, nil, 2.7)
			s.put("CafeChair", xz[1] - 2.3, xz[2], -90, pinkChair)
			s.put("CafeChair", xz[1] + 2.3, xz[2], 90, pinkChair)
		end
		s.put("Plant", 9.5, -7.4, 0, { scale = 1.8 })
		s.lamps({ { -7.5, -5.5 }, { -4.5, -5.5 }, { -1.5, -5.5 }, { 4.2, -5.5 }, { 18.2, -4.5 }, { 18.2, 1.5 }, { -14.5, -1.0 }, { -10.0, 2.5 } }, Color3.fromRGB(255, 232, 226))
		F.shops.dessert = { counter = dessertCounter, clerkSpot = s.world(4.2, 0, -7.9), clerkLook = s.look }
	end

	---------------------------------------------------------------- 🧸 뽑기 천국: 인형뽑기 4대 + 🎡 돌림판 + 🎯 풍선 다트 + 캡슐 뽑기
	do
		local s = sceneOf(shopX.claw)
		for i, color in { M.coral, M.sky, M.mint, M.lilac } do
			local lx = -20.5 + (i - 1) * 4.6
			s.put("ClawMachine", lx, -6.6, 0, { colors = { Base = color, Top = color } })
			table.insert(F.clawMachines, s.proxy("ClawMachine", "ClawMachine", Vector3.new(3.6, 7.4, 3.6), lx, 3.7, -6.6, color))
		end
		-- 🎡 돌림판: 뒷벽의 큰 원판(글씨·회전은 Wheel 모듈, 원판의 Left 면이 길 쪽) + 전구 테두리 + 안내대
		local WHEEL_Y = 8.2
		local wheelDisc = s.part(Vector3.new(0.5, 9, 9), 3.5, WHEEL_Y, -8.6, { Name = "WheelDisc", Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(3.5, WHEEL_Y, -8.6) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(40, 40, 50) })
		if not s.put("WheelFrame", 3.5, -8.4, 0, nil, WHEEL_Y) then
			s.deco(Vector3.new(0.8, 1.2, 0.8), 3.5, WHEEL_Y + 4.9, -8.1, Color3.fromRGB(230, 50, 50), Enum.Material.Neon) -- ▼ 바늘
		end
		local wheelKiosk = s.part(Vector3.new(5, 3.4, 1.6), 3.5, 1.7, -3.6, { Name = "WheelKiosk", Color = M.yellow })
		s.deco(Vector3.new(5.2, 0.25, 1.8), 3.5, 3.5, -3.6, M.woodLight, Enum.Material.Wood)
		s.label(3.5, 4.2, -2.75, 5, "🎡 다 같이 돌림판")
		F.wheel = { disc = wheelDisc, kiosk = wheelKiosk }
		-- 🎯 풍선 다트: 부스 안 뒷판에 풍선 장식 (실제 경품은 창에서 서버가 섞어요)
		local DART_X = 13.5
		s.put("DartBooth", DART_X, -6.8)
		local dartBoard = s.part(Vector3.new(6.2, 4.6, 0.4), DART_X, 5.6, -8.3, { Name = "DartBoard", Color = Color3.fromRGB(165, 205, 226), Material = Enum.Material.Wood })
		local balloonColors = {}
		for _, info in SalaryConfig.DartPrizes do
			table.insert(balloonColors, info.color)
		end
		for i, slot in SalaryConfig.DART_SLOTS do
			local bx = DART_X - 2.8 + slot.x / SalaryConfig.DART_FIELD_W * 5.6
			local by = 7.5 - (slot.y - 40) / 150 * 3.4
			s.deco(Vector3.new(0.85, 0.95, 0.8), bx, by, -7.8, balloonColors[i % #balloonColors + 1], nil, { Shape = Enum.PartType.Ball })
		end
		local dartCounter = s.proxy("DartCounter", "DartBooth", Vector3.new(7.2, 3.4, 1.4), DART_X, 1.7, -5.2, M.woodLight)
		s.label(DART_X, 4.3, -4.5, 5, "🎯 풍선 다트")
		F.dart = { board = dartBoard, counter = dartCounter }
		-- 캡슐 뽑기 (오른쪽 벽) · 인형 선반 (왼쪽 벽) · 네온 사인 · 가운데 쉼터
		for i, color in { M.sky, M.coral, M.mint, M.yellow } do
			s.put("GachaMachine", 22.3, -3.0 + (i - 1) * 2.3, 90, { colors = { Body = color } }, 0, Vector3.new(2, 5.4, 1.8))
		end
		s.put("PlushShelf", -22.6, 2.5, -90, nil, 0, Vector3.new(6, 5.4, 1.2))
		s.put("NeonSign", -8, -8.95, 0, nil, 10.8)
		s.rug(-6, 3.5, 5.0, M.yellow)
		s.put("BoothSofa", -6, 2.2, 180, { colors = { Seat = M.coral, Back = M.coral } }, 0, Vector3.new(6, 2.4, 2.2))
		s.put("GachaMachine", -11.5, 5.0, 0, { colors = { Body = M.lilac } }, 0, Vector3.new(2, 5.4, 1.8))
		s.lamps({ { -16, -2 }, { -8, -2 }, { 3.5, -1 }, { 13.5, -2 }, { -6, 5 }, { 16, 5 } })
	end

	---------------------------------------------------------------- 🕹️ 오락실: 오락기 6대 + 두더지 2대 + 경품 교환대 (어둡고 네온)
	do
		local s = sceneOf(shopX.arcade)
		local arcade: any = { machines = {} }
		for i, body in { M.arcade, M.red, M.mintDark, M.arcade, M.lilac, M.red } do
			local lx = -9.5 + (i - 1) * 3.7
			s.put("ArcadeCabinet", lx, -7.3, 0, { colors = { Body = body } }, 0, if i == 4 then nil else Vector3.new(3.2, 6.6, 2.8))
			s.put("BarStool", lx, -4.2, 0, { colors = { Seat = if i % 2 == 0 then M.neonPink else M.neonCyan } })
		end
		-- 🃏 카드 짝 맞추기 = 가운데 오락기 (4번째) / 🔨 두더지 잡기 = 왼쪽 두더지 기계
		arcade.machines.memory = s.proxy("ArcadeMachine", "ArcadeCabinet", Vector3.new(3.2, 6.6, 2.8), -9.5 + 3 * 3.7, 3.3, -7.3, M.sky)
		s.label(-9.5 + 3 * 3.7, 7.3, -6.6, 3.4, "🃏 카드 짝 맞추기")
		s.put("MoleMachine", -20.0, -6.8)
		arcade.machines.mole = s.proxy("ArcadeMachine", "MoleMachine", Vector3.new(4, 6.2, 3), -20.0, 3.1, -6.8, M.mintDark)
		s.label(-20.0, 6.9, -5.9, 3.6, "🔨 두더지 잡기")
		s.put("MoleMachine", -15.2, -6.8, 0, nil, 0, Vector3.new(4, 6.2, 3))
		-- 🎟️ 경품 교환대 (오른쪽) + 뒤 인형 선반
		s.put("PrizeCounter", 19.0, -2.0, 90)
		arcade.prizeCounter = s.proxy("PrizeCounter", "PrizeCounter", Vector3.new(2.3, 3.5, 6.2), 19.0, 1.75, -2.0, M.arcade)
		local prizeSign = s.deco(Vector3.new(0.2, 0.9, 4.6), 17.7, 4.2, -2.0, Color3.fromRGB(30, 30, 40))
		Build.surfaceText(prizeSign, Enum.NormalId.Left, "🎟️ 경품 교환", { Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 230, 120) })
		s.put("PlushShelf", 22.6, -2.0, 90, nil, 0, Vector3.new(6, 5.4, 1.2))
		-- 🏆 최고 기록판 (뒷벽 왼쪽 위, 서버가 글씨를 채워요. Front 면이 길 쪽을 보게 돌려 놓아요)
		arcade.board = s.part(Vector3.new(10, 4.2, 0.3), -17.6, 10.4, -8.8, { Name = "ArcadeBoard", CFrame = CFrame.new(-17.6, 10.4, -8.8) * CFrame.Angles(0, math.pi, 0), Color = Color3.fromRGB(20, 20, 30), CanCollide = false })
		s.put("NeonSign", 0, -8.95, 0, nil, 10.8)
		s.put("NeonSign", -23.3, 1.0, -90, nil, 8.6)
		s.put("ClawMachine", -20.5, 4.0, -90, { colors = { Base = M.lilac, Top = M.lilac } }, 0, Vector3.new(3.6, 7.4, 3.6))
		-- 네온 띠: 바닥 두 줄(분홍) + 뒷벽 위아래(하늘)
		for _, lz in { -2.6, 6.5 } do
			s.deco(Vector3.new(44, 0.06, 0.25), 0, 0.16, lz, M.neonPink, Enum.Material.Neon)
		end
		for _, ly in { 0.6, 13.0 } do
			s.deco(Vector3.new(46.5, 0.2, 0.1), 0, ly, -8.9, M.neonCyan, Enum.Material.Neon)
		end
		-- 불빛: 어두운 보랏빛 조명 몇 개 (전구는 안 보이게 천장에 숨겨요)
		for _, xz in { { -16, -3 }, { -4, -3 }, { 8, -3 }, { 18, 2 }, { -10, 4 }, { 6, 4 } } do
			local glow = Instance.new("PointLight")
			glow.Range = 20
			glow.Brightness = 0.7
			glow.Color = if xz[1] % 8 == 0 then Color3.fromRGB(150, 220, 255) else Color3.fromRGB(255, 150, 210)
			glow.Shadows = false
			glow.Parent = s.deco(Vector3.new(1, 0.2, 1), xz[1], CEILING - 0.2, xz[2], M.ink)
		end
		F.arcade = arcade
	end

	---------------------------------------------------------------- 구경만 되는 가게의 유리창 진열 (단지 좌표, 유리 바로 뒤 z 111~114)
	do
		local function shopAt(index: number): number
			return -208 + (index - 1) * 52
		end
		-- 꽃집: 화분과 꽃
		local x = shopAt(1)
		for i = 0, 5 do
			mesh("Plant", x - 18 + i * 7.2, 112.6, random:NextNumber(0, 360), { scale = 1.5 + (i % 3) * 0.3 })
		end
		mesh("FlowerBed", x - 8, 113.4, 180, { scale = 1.0 })
		mesh("FlowerBed", x + 10, 113.4, 180, { scale = 1.0 })
		-- 서점: 책장
		x = shopAt(2)
		for i = 0, 3 do
			mesh("Bookshelf", x - 17 + i * 11.3, 114.2, 180)
		end
		mesh("CafeTable", x - 2, 111.6, 0, { colors = { Top = M.woodDark } })
		-- 미용실: 의자와 선반
		x = shopAt(7)
		for i = 0, 2 do
			mesh("CafeChair", x - 12 + i * 12, 112.6, 180, { scale = 1.3, colors = { Seat = M.coral, Back = M.coral } })
			mesh("WallShelf", x - 12 + i * 12, 115.2, 180, nil, 6.5)
		end
		mesh("Plant", x + 19, 112.6, 0, { scale = 1.8 })
		-- 약국: 진열대와 계산대
		x = shopAt(8)
		mesh("StoreShelf", x - 14, 114.2, 180)
		mesh("StoreShelf", x - 6, 114.2, 180)
		mesh("StoreCounter", x + 8, 113.2, 180)
		mesh("Plant", x + 18, 112.6, 0, { scale = 1.6 })
		-- 문구점: 책장과 인형 선반
		x = shopAt(9)
		mesh("Bookshelf", x - 15, 114.2, 180)
		mesh("PlushShelf", x - 2, 114.2, 180)
		mesh("Bookshelf", x + 11, 114.2, 180)
		mesh("GachaMachine", x + 19, 112.8, 180, { colors = { Body = M.coral } })
	end

	---------------------------------------------------------------- 기둥 · 위층 창
	for i = 0, 9 do
		P(Vector3.new(5, 14, 27), Vector3.new(-234 + i * 52, 7, 122), { Color = BLOCK, Material = Enum.Material.Concrete })
	end
	for floor = 0, 3 do
		for x = -224, 224, 14 do
			deco(Vector3.new(9, 7, 0.4), Vector3.new(x, 23.5 + floor * 11, 108.9), Color3.fromRGB(120, 150, 172), Enum.Material.Glass)
		end
	end
end

return CampusStreet
