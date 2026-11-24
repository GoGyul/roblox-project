-- 🏙️ 회사 단지 (대충상사 + 눈치물산이 함께 쓰는 바깥 공간)
--   북쪽 큰길(버스 정류장·지하철 출구)에서 출근 → 가운데 큰 중앙 공원 → 서쪽 대충상사 상가 건물 / 동쪽 눈치물산 유리 타워 → 남쪽 눈치 스트리트
--   단지 좌표: x 동서(-240~240), z 남북(-150 큰길 ~ 135 스트리트), y 0 = 땅 윗면. 공원은 x ±130 / z -110~70 (260×180칸).
--   사무실 층은 여기 없어요. 건물 로비의 엘리베이터·계단으로 오가는 따로 떨어진 공간이에요.
--
--   두 회사 서버 모두 같은 단지를 지어요 (사무실을 지을 때 OfficeDaechung·OfficeNunchi가 Campus.build를 불러요).
--   공원 기능(회식 식탁·사탕 쉼터·내 화단)과 눈치 스트리트 가게(커피·디저트·뽑기·돌림판·다트·오락실),
--   대충상사 상가 1층 가게(편의점·커피·분식), 두 회사 로비가 모두 여기 있고, build가 돌려주는 값으로 게임 모듈에 이어져요.
--   엘리베이터·계단·출근 자리는 Arrival 모듈이 붙여요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Build = require(ReplicatedStorage.Shared.Build)
local Theme = require(ReplicatedStorage.Shared.SalaryTheme)
local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local Meshes = require(script.Parent.Meshes)
local CampusDaechung = require(script.Parent.CampusDaechung)

local Campus = {}

Campus.ORIGIN = Vector3.new(0, 1, 900) -- 단지 한가운데 근처(분수 광장 남쪽)의 땅 윗면
-- 대충상사 상가 건물 자리: 건물 앞면(가게·입구가 난 면)의 가운데. 건물은 서쪽에 서서 동쪽(공원)을 봐요.
--   Arrival의 건물 좌표(앞면이 z 0, 길이 +z)를 90° 돌려서 +z가 단지의 동쪽(+x)이 되게 해요.
Campus.DAECHUNG_SITE = CFrame.new(Campus.ORIGIN + Vector3.new(-152, 0, -50)) * CFrame.Angles(0, math.rad(90), 0)

local M = Theme.Mesh
local HALF_X, NORTH, SOUTH = 245, -152, 137

-- 단지 좌표 → 월드 좌표
function Campus.point(x: number, y: number, z: number): Vector3
	return Campus.ORIGIN + Vector3.new(x, y, z)
end

-- 대충상사 건물 좌표(앞면 가운데 기준, +z가 건물 앞) → 월드 좌표
function Campus.daechungPoint(x: number, y: number, z: number): Vector3
	return Campus.DAECHUNG_SITE:PointToWorldSpace(Vector3.new(x, y, z))
end

-- 단지 땅 위에 있나 (건물 1층·가게 안 포함)
function Campus.contains(position: Vector3): boolean
	local offset = position - Campus.ORIGIN
	return math.abs(offset.X) <= HALF_X + 2 and offset.Z >= NORTH - 2 and offset.Z <= SOUTH + 2 and offset.Y > -20 and offset.Y < 120
end

-- 👀 창밖 시선을 피할 수 있는 곳인가: 건물 안(상가 1층·타워 로비·눈치 스트리트 가게) 또는 지붕·나무 밑
local cover: { { number } } = {} -- { x, z, 반지름 } (단지 좌표, build가 채워요)
function Campus.hidden(position: Vector3): boolean
	local offset = position - Campus.ORIGIN
	local x, z = offset.X, offset.Z
	if z >= 108.5 or ((x <= -152 or x >= 152) and z >= -111 and z <= 11) then
		return true -- 건물 안
	end
	for _, spot in cover do
		local dx, dz = x - spot[1], z - spot[2]
		if dx * dx + dz * dz <= spot[3] * spot[3] then
			return true
		end
	end
	return false
end

-- 건물 안인가 (상가 1층·타워 로비·눈치 스트리트 가게)
function Campus.indoor(position: Vector3): boolean
	local offset = position - Campus.ORIGIN
	return offset.Z >= 108.5 or ((offset.X <= -152 or offset.X >= 152) and offset.Z >= -111 and offset.Z <= 11)
end

-- 💰 단지 산책 수입 배율: 위험할수록 많이 벌어요
--   건물 안 0.7 (안전) · 지붕/나무 밑 1.0 · 탁 트인 곳 1.6 (👀 창가의 부장님 눈에 보여요)
function Campus.incomeScale(position: Vector3): (number, string)
	if Campus.indoor(position) then
		return 0.7, "indoor"
	elseif Campus.hidden(position) then
		return 1, "shade"
	end
	return 1.6, "open"
end

-- 처음 출근하는 자리: 북쪽 큰길 버스 정류장 앞, 공원(남쪽)을 보고
Campus.SPAWN = CFrame.lookAt(Campus.point(20, 3, -112), Campus.point(0, 3, -20))

-- 지어 둔 단지 (없으면 nil)
local built: any = nil
function Campus.get(): any
	return built
end

-- helpers: OfficeBuilder가 넘겨주는 도구 (zone, buildStore, decorateStore, v, FLOOR_Y) / companyId: 이 서버의 회사
function Campus.build(parent: Instance, helpers: any, companyId: string)
	if built then
		return built
	end
	local F: any = { shops = {}, clawMachines = {} }
	built = F
	local folder = Instance.new("Folder")
	folder.Name = "Campus"
	folder.Parent = parent
	local B = Build.new(folder, Campus.ORIGIN)
	local random = Random.new(7)
	local function P(size: Vector3, position: Vector3, props: { [string]: any }?): BasePart
		return B:part(size, position, props)
	end
	local function deco(size: Vector3, position: Vector3, color: Color3, material: Enum.Material?, extra: { [string]: any }?): BasePart
		local props: { [string]: any } = { Color = color, Material = material or Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false }
		for key, value in extra or {} do
			props[key] = value
		end
		return P(size, position, props)
	end
	local function text(part: BasePart, face: Enum.NormalId, message: string, color: Color3?)
		Build.surfaceText(part, face, message, { Font = Enum.Font.GothamBold, TextColor3 = color or Color3.new(1, 1, 1) })
	end
	local function mesh(kind: string, x: number, z: number, yaw: number?, options: any?, y: number?)
		if Meshes.ready(kind) then
			return Meshes.place(B, kind, Vector3.new(x, y or 0, z), yaw or 0, options)
		end
		return nil
	end
	local function shade(x: number, z: number, radius: number)
		table.insert(cover, { x, z, radius })
	end
	local function lampPost(x: number, z: number)
		local post = mesh("LampPost", x, z, 0, { scale = 2 })
		if post then
			local glow = Instance.new("PointLight")
			glow.Range = 26
			glow.Brightness = 0.45
			glow.Color = Theme.Color.yellowSoft
			glow.Parent = post.Bulb
		end
		P(Vector3.new(0.8, 10, 0.8), Vector3.new(x, 5, z), { Transparency = 1 })
	end

	---------------------------------------------------------------- 땅 · 길
	local PAVE = Color3.fromRGB(190, 186, 176)
	-- (윗면을 살짝 낮춰서, 건물 안 바닥(윗면 0)과 같은 면에 겹쳐 떨리지 않게 해요)
	P(Vector3.new(HALF_X * 2 + 20, 1, SOUTH - NORTH + 20), Vector3.new(0, -0.54, (NORTH + SOUTH) / 2), { Color = PAVE, Material = Enum.Material.Pavement })
	P(Vector3.new(260, 0.24, 180), Vector3.new(0, 0.08, -20), { Color = Color3.fromRGB(110, 158, 104), Material = Enum.Material.Grass }) -- 잔디
	local asphalt = { Color = Color3.fromRGB(66, 68, 72), Material = Enum.Material.Asphalt, CanCollide = false, CanQuery = false }
	P(Vector3.new(HALF_X * 2, 0.12, 26), Vector3.new(0, 0.02, -138), asphalt) -- 북쪽 큰길
	P(Vector3.new(HALF_X * 2, 0.12, 14), Vector3.new(0, 0.02, 98), asphalt) -- 눈치 스트리트 찻길
	for x = -230, 230, 22 do
		deco(Vector3.new(10, 0.05, 0.6), Vector3.new(x, 0.1, -138), Color3.fromRGB(226, 186, 70))
	end
	for _, cx in { -150, 0, 150 } do
		for k = -3, 3 do
			deco(Vector3.new(1.8, 0.05, 22), Vector3.new(cx + k * 3.4, 0.1, -138), Color3.fromRGB(236, 236, 232)) -- 횡단보도
		end
	end
	-- 공원 길: 둥근 광장 + 십자 큰길 + 바깥 순환로 (겹치는 길은 높이를 조금씩 달리해요)
	local PATH = Color3.fromRGB(226, 214, 190)
	local plaza = deco(Vector3.new(0.16, 52, 52), Vector3.new(0, 0.28, -20), PATH, Enum.Material.Pavement)
	plaza.Shape = Enum.PartType.Cylinder
	plaza.CFrame *= CFrame.Angles(0, 0, math.rad(90))
	for i, info in {
		{ Vector3.new(250, 0.1, 8), Vector3.new(0, 0.22, -20) },
		{ Vector3.new(8, 0.1, 172), Vector3.new(0, 0.23, -20) },
		{ Vector3.new(200, 0.1, 6), Vector3.new(0, 0.24, -92) },
		{ Vector3.new(200, 0.1, 6), Vector3.new(0, 0.24, 52) },
		{ Vector3.new(6, 0.1, 150), Vector3.new(-100, 0.25, -20) },
		{ Vector3.new(6, 0.1, 150), Vector3.new(100, 0.25, -20) },
	} do
		deco(info[1], info[2], PATH, Enum.Material.Pavement)
		local _ = i
	end
	-- 못 나가게 막는 투명 벽
	for _, info in {
		{ Vector3.new(1, 80, SOUTH - NORTH + 4), Vector3.new(-HALF_X - 1, 40, (NORTH + SOUTH) / 2) },
		{ Vector3.new(1, 80, SOUTH - NORTH + 4), Vector3.new(HALF_X + 1, 40, (NORTH + SOUTH) / 2) },
		{ Vector3.new(HALF_X * 2 + 4, 80, 1), Vector3.new(0, 40, NORTH - 1) },
		{ Vector3.new(HALF_X * 2 + 4, 80, 1), Vector3.new(0, 40, SOUTH + 1) },
	} do
		P(info[1], info[2], { Transparency = 1 })
	end

	---------------------------------------------------------------- 큰길: 버스 정류장 · 버스 · 차 · 지하철 출구
	local DARK = Color3.fromRGB(70, 76, 84)
	for _, cx in { -130, 20, 170 } do
		for _, dx in { -7, 7 } do
			for _, dz in { -1.6, 1.6 } do
				P(Vector3.new(0.4, 9, 0.4), Vector3.new(cx + dx, 4.5, -118 + dz), { Color = DARK, Material = Enum.Material.Metal })
			end
		end
		deco(Vector3.new(16, 0.4, 5), Vector3.new(cx, 9.2, -118), DARK, Enum.Material.Metal)
		deco(Vector3.new(14, 6.5, 0.2), Vector3.new(cx, 4.6, -119.6), Color3.fromRGB(190, 214, 226), Enum.Material.Glass, { Transparency = 0.5 })
		local sign = deco(Vector3.new(2.6, 2.6, 0.3), Vector3.new(cx + 9.4, 9, -117), Color3.fromRGB(60, 110, 190))
		text(sign, Enum.NormalId.Back, "버스")
		P(Vector3.new(0.3, 8, 0.3), Vector3.new(cx + 9.4, 4, -117), { Color = Color3.fromRGB(60, 110, 190), Material = Enum.Material.Metal })
		shade(cx, -118, 8.5) -- 정류장 지붕
		mesh("Bench", cx, -117.6, 180, { scale = 1.3 })
		P(Vector3.new(5.4, 1.8, 1.6), Vector3.new(cx, 0.9, -117.6), { Transparency = 1 })
	end
	local function car(x: number, z: number, color: Color3, long: number, tall: number)
		P(Vector3.new(long, tall, 7.4), Vector3.new(x, 1.2 + tall / 2, z), { Color = color })
		deco(Vector3.new(long * 0.8, tall * 0.42, 7.6), Vector3.new(x, 1.4 + tall * 0.62, z), Color3.fromRGB(50, 62, 74), Enum.Material.Glass)
		for _, dx in { -long * 0.32, long * 0.32 } do
			for _, dz in { -3.4, 3.4 } do
				local wheel = deco(Vector3.new(1, 2.8, 2.8), Vector3.new(x + dx, 1.4, z + dz), Color3.fromRGB(40, 40, 44))
				wheel.Shape = Enum.PartType.Cylinder
				wheel.CFrame *= CFrame.Angles(0, math.rad(90), 0)
			end
		end
	end
	car(-14, -131, Color3.fromRGB(70, 150, 110), 34, 9) -- 버스
	car(-86, -131, Color3.fromRGB(226, 226, 222), 16, 4.4)
	car(66, -145, Color3.fromRGB(70, 110, 170), 16, 4.4)
	car(196, -131, Color3.fromRGB(190, 84, 72), 16, 4.4)
	-- 출근 자리 앞 길 안내판 (북쪽에서 내려오는 사람이 읽어요: 왼쪽이 동쪽)
	local guide = deco(Vector3.new(26, 3.4, 0.5), Vector3.new(20, 8, -99), Color3.fromRGB(44, 62, 92))
	text(guide, Enum.NormalId.Front, "◀ (주)눈치물산 타워    중앙 공원 ▼    (주)대충상사 · 상가 ▶")
	for _, dx in { -12, 12 } do
		P(Vector3.new(0.5, 9.6, 0.5), Vector3.new(20 + dx, 4.8, -99), { Color = DARK, Material = Enum.Material.Metal })
	end
	-- 지하철 출구
	deco(Vector3.new(12, 0.6, 20), Vector3.new(96, 9, -112), DARK, Enum.Material.Metal)
	for _, dx in { -5.8, 5.8 } do
		P(Vector3.new(0.6, 4, 20), Vector3.new(96 + dx, 2, -112), { Color = DARK, Material = Enum.Material.Metal })
	end
	P(Vector3.new(11, 4, 0.6), Vector3.new(96, 2, -121.7), { Color = DARK, Material = Enum.Material.Metal })
	deco(Vector3.new(10.4, 0.2, 18), Vector3.new(96, 0.4, -112.4), Color3.fromRGB(40, 42, 46))
	shade(96, -112, 10)
	local subway = deco(Vector3.new(9, 2.4, 0.4), Vector3.new(96, 10.6, -102.4), Color3.fromRGB(60, 110, 190))
	text(subway, Enum.NormalId.Back, "지하철 눈치단지역")

	---------------------------------------------------------------- 눈치물산 유리 타워 (동쪽, 지금은 겉모습만)
	local TOWER_H = 170
	local TOWER_GLASS = Color3.fromRGB(132, 164, 190)
	local LOBBY_H = 20
	P(Vector3.new(80, TOWER_H - 22, 120), Vector3.new(192, 22 + (TOWER_H - 22) / 2, -50), { Color = TOWER_GLASS, Material = Enum.Material.Glass, Reflectance = 0.15, CastShadow = false })
	-- 1층: 가운데가 로비(x 152~196 / z -80~-20), 나머지는 막힌 덩어리
	for _, info in { { Vector3.new(80, 22, 30), Vector3.new(192, 11, -95) }, { Vector3.new(80, 22, 30), Vector3.new(192, 11, -5) }, { Vector3.new(36, 22, 60), Vector3.new(214, 11, -50) } } do
		P(info[1], info[2], { Color = TOWER_GLASS, Material = Enum.Material.Glass, Reflectance = 0.1 })
	end
	P(Vector3.new(44, 2, 60), Vector3.new(174, 21, -50), { Color = M.surface })
	P(Vector3.new(44, 0.2, 60), Vector3.new(174, 0.1, -50), { Color = Color3.fromRGB(214, 212, 206), Material = Enum.Material.Marble })
	local lobbyGlass = { Color = Color3.fromRGB(190, 214, 232), Material = Enum.Material.Glass, Transparency = 0.45 }
	P(Vector3.new(0.5, LOBBY_H, 24), Vector3.new(152.2, LOBBY_H / 2, -68), lobbyGlass)
	P(Vector3.new(0.5, LOBBY_H, 24), Vector3.new(152.2, LOBBY_H / 2, -32), lobbyGlass)
	P(Vector3.new(0.5, LOBBY_H - 12, 12), Vector3.new(152.2, 12 + (LOBBY_H - 12) / 2, -50), lobbyGlass) -- 문 위 유리 (문은 폭 12 · 높이 12)
	for _, z in { -56.2, -43.8 } do
		P(Vector3.new(0.7, 12, 0.5), Vector3.new(152.2, 6, z), { Color = Color3.fromRGB(52, 56, 62), Material = Enum.Material.Metal })
	end
	for _, info in { { Vector3.new(43.6, LOBBY_H, 0.3), Vector3.new(174, LOBBY_H / 2, -79.8) }, { Vector3.new(43.6, LOBBY_H, 0.3), Vector3.new(174, LOBBY_H / 2, -20.2) }, { Vector3.new(0.3, LOBBY_H, 59.4), Vector3.new(195.8, LOBBY_H / 2, -50) } } do
		deco(info[1], info[2], M.wall, Enum.Material.Plaster)
	end
	deco(Vector3.new(0.2, 6, 59), Vector3.new(195.6, 3, -50), M.woodLight, Enum.Material.Wood) -- 뒷벽 원목 띠
	for _, x in { 162, 176, 190 } do
		for _, z in { -66, -34 } do
			local lamp = deco(Vector3.new(6, 0.2, 2), Vector3.new(x, LOBBY_H - 0.15, z), Color3.fromRGB(236, 234, 226), Enum.Material.Neon)
			local light = Instance.new("PointLight")
			light.Range = 26
			light.Brightness = 0.4
			light.Color = Color3.fromRGB(255, 248, 232)
			light.Parent = lamp
		end
	end
	mesh("Reception", 184, -50, -90)
	P(Vector3.new(6.4, 2.8, 6.4), Vector3.new(184, 1.4, -50), { Transparency = 1 })
	local lobbyLogo = deco(Vector3.new(0.3, 3, 22), Vector3.new(195.4, 13, -50), Color3.fromRGB(30, 35, 45))
	text(lobbyLogo, Enum.NormalId.Left, "NUNCHI CORP.", M.mint)
	-- 엘리베이터 두 대 (뒷벽): 북쪽 것을 타요
	mesh("ElevatorDoor", 195.3, -68, -90)
	mesh("ElevatorDoor", 195.3, -32, -90)
	local towerElevator = P(Vector3.new(0.4, 8.3, 5), Vector3.new(195.2, 4.15, -68), { Color = M.line, Material = Enum.Material.Metal, Transparency = if Meshes.ready("ElevatorDoor") then 1 else 0 })
	local towerFloors = deco(Vector3.new(0.15, 5, 3.4), Vector3.new(195.3, 6.5, -61.6), Color3.fromRGB(44, 62, 92))
	text(towerFloors, Enum.NormalId.Left, "옥상 정원\n12F (주)눈치물산\n2~11F 입주사\n1F 로비")
	for _, z in { -74, -26 } do
		mesh("Sofa", 160, z, if z < -50 then 0 else 180)
		P(Vector3.new(6, 2.6, 2.6), Vector3.new(160, 1.3, z), { Transparency = 1 })
		mesh("Plant", 168, z, 0, { scale = 1.6 })
	end
	F.nunchi = {
		elevatorDoor = towerElevator,
		lobbyElevator = CFrame.new(Campus.point(189, 3, -68)) * CFrame.Angles(0, math.rad(90), 0), -- 엘리베이터 앞, 로비를 보고
	}
	local steel = { CastShadow = false }
	local STEEL = Color3.fromRGB(52, 56, 62)
	for z = -110, 10, 12 do
		local door = z == -50 -- 로비 문 위로는 2층부터
		deco(Vector3.new(0.6, if door then TOWER_H - 22 else TOWER_H, 0.8), Vector3.new(151.6, if door then 22 + (TOWER_H - 22) / 2 else TOWER_H / 2, z), STEEL, Enum.Material.Metal, steel)
	end
	for y = 22, TOWER_H, 11 do
		deco(Vector3.new(0.6, 1, 120), Vector3.new(151.6, y, -50), STEEL, Enum.Material.Metal, steel)
		deco(Vector3.new(80, 1, 0.6), Vector3.new(192, y, 10.4), STEEL, Enum.Material.Metal, steel)
	end
	for x = 152, 232, 10 do
		deco(Vector3.new(0.8, TOWER_H, 0.6), Vector3.new(x, TOWER_H / 2, 10.4), STEEL, Enum.Material.Metal, steel)
	end
	deco(Vector3.new(10, 1, 40), Vector3.new(146, 21.5, -50), STEEL, Enum.Material.Metal) -- 입구 캐노피
	deco(Vector3.new(82, 4, 122), Vector3.new(192, TOWER_H + 2, -50), Color3.fromRGB(226, 226, 222), Enum.Material.Concrete, steel)
	local logo = deco(Vector3.new(0.8, 9, 46), Vector3.new(151.2, TOWER_H - 14, -50), Color3.fromRGB(30, 35, 45), nil, steel)
	text(logo, Enum.NormalId.Left, "NUNCHI CORP.")
	local gate = deco(Vector3.new(0.4, 2.6, 16), Vector3.new(150.9, 13, -50), Color3.fromRGB(30, 35, 45))
	text(gate, Enum.NormalId.Left, "(주)눈치물산 · 12F")
	for _, z in { -62, -38 } do -- 입구 앞 화분
		mesh("Planter", 144, z, 90, { colors = { Box = M.stone } })
		P(Vector3.new(1.8, 1.3, 6), Vector3.new(144, 0.65, z), { Transparency = 1 })
	end
	-- 사옥 앞 광장 (타워 남쪽): 푸드트럭 두 대와 파라솔 자리
	for i, info in { { 170, Color3.fromRGB(190, 108, 92) }, { 200, Color3.fromRGB(88, 150, 132) } } do
		local x = info[1]
		P(Vector3.new(20, 9, 9), Vector3.new(x, 6, 48), { Color = info[2] })
		P(Vector3.new(6, 6, 8.6), Vector3.new(x + 12.6, 4.5, 48), { Color = info[2] })
		deco(Vector3.new(12, 4, 0.4), Vector3.new(x - 1, 7, 43.3), Color3.fromRGB(250, 246, 236))
		deco(Vector3.new(12, 0.4, 5), Vector3.new(x - 1, 10.4, 41.4), Color3.fromRGB(250, 246, 236)).CFrame *= CFrame.Angles(math.rad(18), 0, 0)
		local board = deco(Vector3.new(8, 1.6, 0.3), Vector3.new(x - 1, 9.6, 43.2), Color3.fromRGB(30, 35, 45))
		text(board, Enum.NormalId.Front, if i == 1 then "오늘의 푸드트럭 · 타코" else "오늘의 푸드트럭 · 닭강정")
	end
	for _, x in { 176, 196, 216 } do
		mesh("Parasol", x, 32, x, { scale = 1.5 })
		shade(x, 32, 5.5)
	end
	-- 🚚 타코 트럭 창구: 점심시간에만 팔아요 (Street 모듈이 사장님과 [E] 주문을 붙여요)
	local truckCounter = P(Vector3.new(10, 0.5, 1.6), Vector3.new(169, 4.4, 43), { Name = "ShopCounter", Color = Color3.fromRGB(250, 246, 236) })
	P(Vector3.new(0.4, 4.2, 0.4), Vector3.new(164.4, 2.1, 42.6), { Color = DARK, Material = Enum.Material.Metal })
	local truckSign = deco(Vector3.new(4.6, 5.4, 0.3), Vector3.new(158, 3.2, 41.5), Color3.fromRGB(44, 62, 92))
	truckSign.CFrame *= CFrame.Angles(math.rad(-12), 0, 0)
	text(truckSign, Enum.NormalId.Front, "🚚 점심 한정\n12시~1시\n🌮 든든 타코\n🍗 닭강정 컵")
	F.shops.truck = { counter = truckCounter, clerkSpot = Campus.point(156, 0, 45.5), clerkLook = Vector3.new(0, 0, -1) }

	---------------------------------------------------------------- 중앙 공원
	-- ⛲ 분수 광장 (한가운데)
	mesh("Fountain", 0, -20, 0, { scale = 2 })
	local basin = P(Vector3.new(2, 15, 15), Vector3.new(0, 1, -20), { Transparency = 1, Shape = Enum.PartType.Cylinder })
	basin.CFrame *= CFrame.Angles(0, 0, math.rad(90))
	for k = 0, 7 do
		local angle = math.rad(22.5 + 45 * k)
		local x, z = 19 * math.cos(angle), -20 + 19 * math.sin(angle)
		mesh("Bench", x, z, 270 - math.deg(angle), { scale = 1.2 })
		P(Vector3.new(2, 1.8, 2), Vector3.new(x, 0.9, z), { Transparency = 1 })
	end
	for k = 0, 3 do
		local angle = math.rad(45 + 90 * k)
		lampPost(27 * math.cos(angle), -20 + 27 * math.sin(angle))
	end
	-- 연못과 다리 (북서)
	local pond = deco(Vector3.new(0.5, 46, 46), Vector3.new(-60, 0.2, -62), Color3.fromRGB(128, 184, 214), Enum.Material.Glass)
	pond.Shape = Enum.PartType.Cylinder
	pond.CFrame *= CFrame.Angles(0, 0, math.rad(90))
	local rim = deco(Vector3.new(0.4, 50, 50), Vector3.new(-60, 0.18, -62), Color3.fromRGB(206, 202, 194), Enum.Material.Concrete)
	rim.Shape = Enum.PartType.Cylinder
	rim.CFrame *= CFrame.Angles(0, 0, math.rad(90))
	P(Vector3.new(7, 0.6, 52), Vector3.new(-60, 1.6, -62), { Color = M.woodLight, Material = Enum.Material.WoodPlanks }) -- 다리
	for _, dx in { -3.4, 3.4 } do
		P(Vector3.new(0.3, 2.4, 52), Vector3.new(-60 + dx, 3, -62), { Color = M.wood, Material = Enum.Material.Wood })
	end
	for _, dz in { -27.5, 27.5 } do
		P(Vector3.new(7, 0.6, 4), nil, { CFrame = CFrame.new(-60, 0.8, -62 + dz) * CFrame.Angles(math.rad(if dz < 0 then -22 else 22), 0, 0), Color = M.woodLight, Material = Enum.Material.WoodPlanks })
	end
	-- 잔디 광장과 야외무대 (북동)
	P(Vector3.new(36, 1.6, 18), Vector3.new(64, 0.8, -84), { Color = M.wood, Material = Enum.Material.WoodPlanks })
	for _, dx in { -17, 17 } do
		for _, dz in { -8.5, 8.5 } do
			P(Vector3.new(0.8, 15, 0.8), Vector3.new(64 + dx, 9, -84 + dz), { Color = STEEL, Material = Enum.Material.Metal })
		end
	end
	P(Vector3.new(38, 0.8, 20), Vector3.new(64, 16.8, -84), { Color = STEEL, Material = Enum.Material.Metal })
	shade(64, -84, 12)
	P(Vector3.new(36, 5, 0.5), Vector3.new(64, 4, -92.6), { Color = M.navy })
	for _, info in { { 48, -58, 10 }, { 76, -54, -15 }, { 92, -66, 20 } } do -- 돗자리
		local mat = deco(Vector3.new(7, 0.1, 5), Vector3.new(info[1], 0.26, info[2]), M.coral, Enum.Material.Fabric)
		mat.CFrame *= CFrame.Angles(0, math.rad(info[3]), 0)
	end
	-- 🍭 사탕 쉼터 (남서 숲속 정자, 예전 "흡연구역"): 여기 있으면 사탕 타임
	mesh("Pergola", -70, 30, 0, { scale = 1.7 })
	mesh("Bench", -70, 33.5, 180, { scale = 1.3 })
	P(Vector3.new(16, 0.7, 13), Vector3.new(-70, 0.35, 30), { Transparency = 1 })
	shade(-70, 30, 9)
	local candySign = deco(Vector3.new(8, 1.6, 0.2), Vector3.new(-70, 9.6, 23.4), Color3.fromRGB(255, 240, 245))
	text(candySign, Enum.NormalId.Front, "🍭 사탕 쉼터 (금연! 사탕만 허용)", Color3.fromRGB(200, 60, 120))
	P(Vector3.new(0.4, 3, 0.4), Vector3.new(-70, 2.2, 29), { Color = Color3.fromRGB(180, 180, 185), Material = Enum.Material.Metal })
	deco(Vector3.new(1.6, 1.4, 1.6), Vector3.new(-70, 4.3, 29), Color3.fromRGB(220, 240, 250), Enum.Material.Glass, { Transparency = 0.3 })
	for i, color in { Color3.fromRGB(255, 120, 160), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 220, 90) } do
		deco(Vector3.new(0.45, 0.45, 0.45), Vector3.new(-70.4 + i * 0.25, 4.1, 29), color, nil, { Shape = Enum.PartType.Ball })
	end
	F.candyZone = helpers.zone(B, "CandyZone", Vector3.new(16, 10, 13), Vector3.new(-70, 5.6, 30))
	-- 🌷 텃밭 정원 (남쪽 가운데): 앞줄 6칸은 "내 공원 화단"(꽃은 각자 화면에 그려져요, ParkGarden 모듈), 뒷줄은 화분
	F.parkBeds = {}
	local stoneEdge = { Color = Color3.fromRGB(170, 160, 145), Material = Enum.Material.Cobblestone }
	for i = 0, 5 do
		local x = -28 + i * 11.2
		for _, side in { -1, 1 } do
			P(Vector3.new(8, 0.7, 0.6), Vector3.new(x, 0.45, 26 + side * 2.2), stoneEdge)
			P(Vector3.new(0.6, 0.7, 3.8), Vector3.new(x + side * 3.7, 0.45, 26), stoneEdge)
		end
		table.insert(F.parkBeds, P(Vector3.new(6.8, 0.5, 3.8), Vector3.new(x, 0.35, 26), { Name = "ParkBed", Color = Color3.fromRGB(105, 75, 50), Material = Enum.Material.Ground }))
		mesh("Planter", x, 38, 0, { scale = 1.3, colors = { Box = M.woodLight } })
		P(Vector3.new(7.6, 1.6, 2.2), Vector3.new(x, 0.8, 38), { Transparency = 1 })
	end
	P(Vector3.new(0.3, 3, 0.3), Vector3.new(-36, 1.5, 21), { Color = M.woodDark, Material = Enum.Material.Wood })
	local bedSign = deco(Vector3.new(4.4, 1.6, 0.25), Vector3.new(-36, 3.6, 21), Color3.fromRGB(245, 235, 210), Enum.Material.Wood)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		text(bedSign, face, "🌷 내 공원 화단 [E]", Color3.fromRGB(200, 70, 110))
	end
	-- 🍻 야외 식탁 (남동): 차양 아래 긴 식탁 세 줄. 가운데가 회식 자리예요 (의자 8개, 부장님은 서쪽 끝 상석)
	F.dinnerSeats = {}
	for i = 0, 2 do
		local x = 52 + i * 22
		mesh("Pergola", x, 30, 0, { scale = 1.45, colors = { Canopy = M.coralSoft } })
		shade(x, 30, 7.5)
		P(Vector3.new(12, 0.4, 4), Vector3.new(x, 3.2, 30), { Color = M.woodLight, Material = Enum.Material.WoodPlanks })
		for _, dx in { -5, 5 } do
			P(Vector3.new(0.6, 2.4, 3.4), Vector3.new(x + dx, 1.8, 30), { Color = M.woodDark, Material = Enum.Material.Wood })
		end
		for _, side in { -1, 1 } do
			local z = 30 + side * 2.9
			P(Vector3.new(12, 0.3, 1.6), Vector3.new(x, 1.6, z), { Color = M.wood, Material = Enum.Material.WoodPlanks })
			if i == 1 then
				for _, dx in { -4.5, -1.5, 1.5, 4.5 } do
					-- 의자는 식탁 쪽을 보고 앉아요 (앞쪽이 -Z라서, 북쪽 긴 의자는 180° 돌려요)
					local seat = P(Vector3.new(1.8, 0.4, 1.4), nil, {
						ClassName = "Seat",
						Name = "DinnerSeat",
						CFrame = CFrame.new(x + dx, 1.95, z) * (if side < 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity),
						Color = M.wood,
						Material = Enum.Material.WoodPlanks,
					})
					table.insert(F.dinnerSeats, seat)
				end
			end
		end
		P(Vector3.new(13.8, 0.6, 11), Vector3.new(x, 0.3, 30), { Transparency = 1 })
	end
	deco(Vector3.new(2.4, 0.5, 1.4), Vector3.new(74, 3.65, 30), Color3.fromRGB(40, 40, 45), Enum.Material.Metal) -- 불판
	deco(Vector3.new(2, 0.1, 1.1), Vector3.new(74, 3.95, 30), Color3.fromRGB(255, 90, 40), Enum.Material.Neon)
	F.dinnerBoss = Campus.point(74 - 8.4, 0, 30)
	F.dinnerLook = Vector3.new(1, 0, 0)
	-- 꽃밭 · 가로등 · 순환로 벤치
	for _, xz in { { -40, -6 }, { 40, -6 }, { -40, -36 }, { 40, -36 }, { 0, -64 }, { 0, 16 }, { -112, -92 }, { 112, 52 } } do
		mesh("FlowerBed", xz[1], xz[2], 0, { scale = 1.6 })
	end
	for x = -110, 110, 44 do
		lampPost(x, -96)
		lampPost(x, 56)
	end
	for z = -80, 40, 40 do
		for _, x in { -104, 104 } do
			lampPost(x, z)
			mesh("Bench", x * 0.93, z + 10, if x < 0 then 90 else -90, { scale = 1.2 })
			P(Vector3.new(2, 1.8, 5), Vector3.new(x * 0.93, 0.9, z + 10), { Transparency = 1 })
		end
	end
	-- 나무: 가장자리는 줄지어, 남서쪽은 숲으로, 안쪽은 드문드문 (길·광장·시설 자리는 비워요)
	local spots: { { number } } = {}
	for x = -120, 120, 20 do
		table.insert(spots, { x, -104 })
		table.insert(spots, { x, 64 })
	end
	for z = -90, 60, 22 do
		table.insert(spots, { -124, z })
		table.insert(spots, { 124, z })
	end
	for _ = 1, 24 do
		table.insert(spots, { -112 + random:NextNumber(0, 62), 4 + random:NextNumber(0, 54) })
	end
	for _ = 1, 34 do
		table.insert(spots, { random:NextNumber(-110, 110), random:NextNumber(-98, 58) })
	end
	local kept: { { number } } = {}
	for _, spot in spots do
		local x, z = spot[1], spot[2]
		local clear = math.sqrt(x * x + (z + 20) ^ 2) > 34 and math.abs(x) > 7 and math.abs(z + 20) > 7 and math.sqrt((x + 60) ^ 2 + (z + 62) ^ 2) > 30
		clear = clear and math.abs(math.abs(x) - 100) > 6 and math.abs(z + 92) > 6 and math.abs(z - 52) > 6
		clear = clear and not (40 < x and x < 90 and -98 < z and z < -44) and not (-36 < x and x < 40 and 18 < z and z < 46)
		clear = clear and not (40 < x and x < 110 and 20 < z and z < 42) and not (-84 < x and x < -56 and 20 < z and z < 42)
		clear = clear and not (math.abs(x - 20) < 14 and z < -94) -- 출근 자리 앞은 틔워 둬요
		if clear then
			for _, other in kept do
				if math.abs(other[1] - x) < 9 and math.abs(other[2] - z) < 9 then
					clear = false
					break
				end
			end
		end
		if clear then
			table.insert(kept, spot)
			local scale = random:NextNumber(1.5, 2.3)
			mesh("Tree", x, z, random:NextNumber(0, 360), { scale = scale })
			shade(x, z, 2.6 * scale) -- 나무 그늘
			P(Vector3.new(1.6, 6 * scale, 1.6), Vector3.new(x, 3 * scale, z), { Transparency = 1 })
		end
	end
	for _ = 1, 26 do
		local x, z = random:NextNumber(-122, 122), random:NextNumber(-102, 62)
		if math.sqrt(x * x + (z + 20) ^ 2) > 30 and math.abs(x) > 8 and math.abs(z + 20) > 8 then
			mesh("Bush", x, z, random:NextNumber(0, 360), { scale = random:NextNumber(1.3, 2.1) })
		end
	end

	---------------------------------------------------------------- 골목 상가 (대충상사 남쪽): 포장마차 세 칸
	for i, x in { -222, -196, -170 } do
		mesh("Stall", x, 40, 0, { scale = 1.9, colors = { Awning = ({ M.coral, M.yellow, M.mint })[i] } })
		shade(x, 39, 6)
		P(Vector3.new(12, 4.6, 3.6), Vector3.new(x, 2.3, 40), { Transparency = 1 })
	end

	---------------------------------------------------------------- 눈치 스트리트 (남쪽): 가게 9칸 겉모습 + 위층
	local BLOCK = Color3.fromRGB(204, 196, 182)
	P(Vector3.new(HALF_X * 2 - 20, 44, 26), Vector3.new(0, 36, 122), { Color = BLOCK, Material = Enum.Material.Concrete, CastShadow = false })
	P(Vector3.new(HALF_X * 2 - 20, 14, 7), Vector3.new(0, 7, 131.5), { Color = BLOCK, Material = Enum.Material.Concrete })
	-- 가게 한 칸: 안쪽 x ±23.5 / z 109(유리 앞면) ~ 128(뒷벽). open = 들어갈 수 있는 가게
	local SHOPS = {
		{ "꽃집", M.coral }, { "서점", M.mintDark },
		{ "☕ 눈치 커피", M.mintDark, "cafe" }, { "🍰 달콤 디저트", M.coral, "dessert" }, { "🧸 뽑기 천국", M.yellow, "claw" }, { "🕹️ 오락실", Color3.fromRGB(104, 100, 160), "arcade" },
		{ "미용실", M.yellow }, { "약국", M.sky }, { "문구점", M.coral },
	}
	local shopGlass = { Color = Color3.fromRGB(176, 206, 214), Material = Enum.Material.Glass, Transparency = 0.45 }
	local shopX: { [string]: number } = {}
	for i, shop in SHOPS do
		local x = -208 + (i - 1) * 52
		local board = deco(Vector3.new(40, 4, 1.2), Vector3.new(x, 15.6, 108.4), shop[2])
		text(board, Enum.NormalId.Front, shop[1])
		local awning = deco(Vector3.new(42, 0.4, 5), Vector3.new(x, 12.9, 106), shop[2], Enum.Material.Fabric)
		awning.CFrame *= CFrame.Angles(math.rad(-14), 0, 0)
		local light = Instance.new("PointLight")
		light.Range = 20
		light.Brightness = 0.5
		light.Parent = board
		P(Vector3.new(47, 1.2, 0.8), Vector3.new(x, 12.9, 109), { Color = BLOCK, Material = Enum.Material.Concrete }) -- 유리 위 띠
		if not shop[3] then
			P(Vector3.new(47, 12.3, 0.5), Vector3.new(x, 6.15, 109), shopGlass)
			deco(Vector3.new(46.6, 12.3, 13), Vector3.new(x, 6.15, 116.2), Color3.fromRGB(236, 232, 222)) -- 가게 안 (구경만)
			P(Vector3.new(47, 14, 6), Vector3.new(x, 7, 125.5), { Color = BLOCK, Material = Enum.Material.Concrete })
			continue
		end
		shopX[shop[3]] = x
		-- 앞면: 유리창 두 장 + 가운데 문 자리(폭 10 · 높이 10) + 문 위 유리
		for _, dx in { -14.25, 14.25 } do
			P(Vector3.new(18.5, 12.3, 0.5), Vector3.new(x + dx, 6.15, 109), shopGlass)
		end
		P(Vector3.new(10, 2.3, 0.5), Vector3.new(x, 11.15, 109), shopGlass)
		for _, dx in { -5.1, 5.1 } do
			P(Vector3.new(0.4, 10, 0.7), Vector3.new(x + dx, 5, 109), { Color = DARK, Material = Enum.Material.Metal })
		end
		-- 안: 바닥 · 뒷벽 · 천장 · 조명 (햇빛이 안 들어서 조명이 없으면 캄캄해요)
		local dark = shop[3] == "arcade"
		local wallColor = if dark then Color3.fromRGB(60, 60, 110) else Color3.fromRGB(240, 238, 230)
		deco(Vector3.new(46.8, 0.12, 18.6), Vector3.new(x, 0.06, 118.4), if dark then Color3.fromRGB(40, 30, 70) else M.woodLight, if dark then Enum.Material.Carpet else Enum.Material.WoodPlanks)
		P(Vector3.new(47, 14, 1), Vector3.new(x, 7, 127.5), { Color = wallColor, Material = Enum.Material.Plaster })
		deco(Vector3.new(46.8, 0.3, 17.6), Vector3.new(x, 13.7, 118.2), wallColor)
		for _, dx in { -23.42, 23.42 } do
			deco(Vector3.new(0.12, 13.5, 17.6), Vector3.new(x + dx, 6.8, 118.2), wallColor)
		end
		for _, dx in { -12, 0, 12 } do
			for _, dz in { 114, 122 } do
				local lamp = deco(Vector3.new(5, 0.25, 1.2), Vector3.new(x + dx, 13.45, dz), Color3.fromRGB(240, 238, 228), Enum.Material.Neon)
				local glow = Instance.new("PointLight")
				glow.Range = 22
				glow.Brightness = 0.9
				glow.Color = Color3.fromRGB(255, 246, 228)
				glow.Shadows = false
				glow.Parent = lamp
			end
		end
	end
	local function counter(x: number, name: string, size: Vector3, color: Color3, material: Enum.Material?): BasePart
		return P(size, Vector3.new(x, size.Y / 2, 121), { Name = name, Color = color, Material = material or Enum.Material.SmoothPlastic })
	end
	local function label(x: number, y: number, z: number, width: number, message: string)
		local sign = deco(Vector3.new(width, 0.9, 0.2), Vector3.new(x, y, z), Color3.fromRGB(30, 30, 40))
		Build.surfaceText(sign, Enum.NormalId.Front, message, { Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 230, 120) })
	end
	local function tables(x: number)
		for _, dx in { -15, 15 } do
			mesh("RoundTable", x + dx, 115, 0)
			P(Vector3.new(2.4, 1.4, 2.4), Vector3.new(x + dx, 0.7, 115), { Transparency = 1 })
			mesh("DiningChair", x + dx - 2.8, 115, -90)
			mesh("DiningChair", x + dx + 2.8, 115, 90)
		end
	end
	local shopLook = Vector3.new(0, 0, -1) -- 점원은 문(북쪽)을 봐요
	do -- ☕ 눈치 커피
		local x = shopX.cafe
		local cafeCounter = counter(x, "ShopCounter", Vector3.new(10, 3.5, 2), Color3.fromRGB(120, 85, 60), Enum.Material.Wood)
		deco(Vector3.new(1.4, 2, 1.4), Vector3.new(x - 3, 4.5, 121), Color3.fromRGB(190, 190, 195), Enum.Material.Metal) -- 커피머신
		local menu = deco(Vector3.new(10, 3, 0.3), Vector3.new(x, 8, 126.8), Color3.fromRGB(30, 30, 30))
		text(menu, Enum.NormalId.Front, "☕ NUNCHI COFFEE")
		tables(x)
		F.shops.cafe = { counter = cafeCounter, clerkSpot = Campus.point(x, 0, 124), clerkLook = shopLook }
	end
	do -- 🍰 달콤 디저트
		local x = shopX.dessert
		local dessertCounter = counter(x, "ShopCounter", Vector3.new(10, 3.5, 2), Color3.fromRGB(120, 85, 60), Enum.Material.Wood)
		deco(Vector3.new(6, 1.6, 1.6), Vector3.new(x, 4.3, 121), Color3.fromRGB(220, 240, 250), Enum.Material.Glass, { Transparency = 0.4 }) -- 진열장
		for i, color in { Color3.fromRGB(255, 170, 200), Color3.fromRGB(180, 230, 170), Color3.fromRGB(220, 160, 80), Color3.fromRGB(255, 240, 240), Color3.fromRGB(190, 170, 255) } do
			deco(Vector3.new(0.7, 0.5, 0.7), Vector3.new(x - 2.7 + i * 0.9, 3.9, 121), color)
		end
		tables(x)
		F.shops.dessert = { counter = dessertCounter, clerkSpot = Campus.point(x, 0, 124), clerkLook = shopLook }
	end
	do -- 🧸 뽑기 천국: 인형뽑기 2대 + 🎡 다 같이 돌림판 + 🎯 풍선 다트
		local x = shopX.claw
		for i, color in { Color3.fromRGB(255, 120, 170), Color3.fromRGB(120, 190, 255) } do
			local mx, mz = x - 22 + i * 5.5, 123
			local cabinet = P(Vector3.new(3.4, 3, 3.4), Vector3.new(mx, 1.5, mz), { Name = "ClawMachine", Color = color })
			P(Vector3.new(3.4, 3.6, 3.4), Vector3.new(mx, 4.8, mz), { Color = Color3.fromRGB(220, 240, 255), Material = Enum.Material.Glass, Transparency = 0.6 })
			deco(Vector3.new(3.6, 0.6, 3.6), Vector3.new(mx, 6.9, mz), color, Enum.Material.Neon)
			deco(Vector3.new(0.15, 1.4, 0.15), Vector3.new(mx, 5.9, mz), Color3.fromRGB(200, 200, 205), Enum.Material.Metal) -- 집게 줄
			deco(Vector3.new(0.7, 0.3, 0.7), Vector3.new(mx, 5.1, mz), Color3.fromRGB(200, 200, 205), Enum.Material.Metal) -- 집게
			for j = 1, 7 do -- 안에 쌓인 인형들
				local plush = SalaryConfig.Plushies[(j + i) % #SalaryConfig.Plushies + 1]
				deco(Vector3.new(0.8, 0.8, 0.8), Vector3.new(mx + random:NextNumber(-1, 1), 3.4 + (j % 2) * 0.5, mz + random:NextNumber(-1, 1)), plush.color, nil, { Shape = Enum.PartType.Ball })
			end
			table.insert(F.clawMachines, cabinet)
		end
		-- 🎡 돌림판 (뒷벽에 세운 큰 원판, 글씨·회전은 Wheel 모듈이 그려요. 원판의 Left 면이 문 쪽을 봐요)
		local wheelDisc = P(Vector3.new(0.6, 9, 9), nil, { Name = "WheelDisc", Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(x + 1, 6.8, 126.6) * CFrame.Angles(0, math.rad(-90), 0), Color = Color3.fromRGB(40, 40, 50) })
		deco(Vector3.new(0.8, 1.2, 0.8), Vector3.new(x + 1, 11.7, 126.1), Color3.fromRGB(230, 50, 50), Enum.Material.Neon) -- ▼ 바늘
		local wheelKiosk = counter(x + 1, "WheelKiosk", Vector3.new(5, 3.5, 1.6), Color3.fromRGB(250, 200, 80))
		label(x + 1, 4, 120.1, 5, "🎡 다 같이 돌림판")
		F.wheel = { disc = wheelDisc, kiosk = wheelKiosk }
		-- 🎯 풍선 다트 벽: 알록달록 풍선 장식 (실제 경품은 창에서 서버가 섞어요)
		local dartX = x + 14
		local dartBoard = P(Vector3.new(6.2, 5, 0.4), Vector3.new(dartX, 6.2, 126.7), { Name = "DartBoard", Color = Color3.fromRGB(165, 220, 255), Material = Enum.Material.Wood })
		local balloonColors = {}
		for _, info in SalaryConfig.DartPrizes do
			table.insert(balloonColors, info.color)
		end
		for i, slot in SalaryConfig.DART_SLOTS do
			local bx = dartX + 2.8 - slot.x / SalaryConfig.DART_FIELD_W * 5.6
			local by = 8.4 - (slot.y - 40) / 150 * 3.6
			deco(Vector3.new(0.85, 0.95, 0.8), Vector3.new(bx, by, 126.2), balloonColors[i % #balloonColors + 1], nil, { Shape = Enum.PartType.Ball })
			deco(Vector3.new(0.05, 0.6, 0.05), Vector3.new(bx, by - 0.75, 126.35), Color3.fromRGB(110, 110, 120))
		end
		local dartCounter = counter(dartX, "DartCounter", Vector3.new(5, 3.5, 1.6), Color3.fromRGB(120, 200, 255))
		label(dartX, 4, 120.1, 5, "🎯 풍선 다트")
		F.dart = { board = dartBoard, counter = dartCounter }
	end
	do -- 🕹️ 오락실: 게임기 2대 + 경품 교환대 + 최고 기록판
		local x = shopX.arcade
		local arcade: any = { machines = {} }
		for i, info in { { "mole", "🔨 두더지 잡기", Color3.fromRGB(230, 90, 60) }, { "memory", "🃏 카드 짝 맞추기", Color3.fromRGB(60, 170, 230) } } do
			local mx = x - 18 + i * 7
			arcade.machines[info[1]] = P(Vector3.new(3.2, 6, 2.6), Vector3.new(mx, 3, 124.5), { Name = "ArcadeMachine", Color = info[3] })
			deco(Vector3.new(2.6, 2, 0.1), Vector3.new(mx, 4.2, 123.15), Color3.fromRGB(120, 255, 200), Enum.Material.Neon)
			P(Vector3.new(3.2, 0.3, 1.2), Vector3.new(mx, 2.9, 122.8), { Color = Color3.fromRGB(40, 40, 45) }) -- 조작판
			label(mx, 6.5, 123.1, 3.2, info[2])
		end
		arcade.prizeCounter = counter(x + 12, "PrizeCounter", Vector3.new(4.5, 3.5, 2), Color3.fromRGB(250, 200, 80))
		label(x + 12, 4, 119.9, 4.5, "🎟️ 경품 교환")
		deco(Vector3.new(5, 0.3, 1.5), Vector3.new(x + 12, 5, 126.2), Color3.fromRGB(120, 85, 60)) -- 선반
		for i, plush in { SalaryConfig.Plushies[1], SalaryConfig.Plushies[8], SalaryConfig.Plushies[10] } do
			deco(Vector3.new(0.9, 0.9, 0.9), Vector3.new(x + 10.5 + (i - 1) * 1.5, 5.6, 126.2), plush.color, nil, { Shape = Enum.PartType.Ball })
		end
		arcade.board = P(Vector3.new(12, 4.5, 0.3), Vector3.new(x - 6, 10, 126.8), { Name = "ArcadeBoard", Color = Color3.fromRGB(20, 20, 30), CanCollide = false }) -- 🏆 최고 기록판 (서버가 글씨를 채워요)
		F.arcade = arcade
	end
	for i = 0, 9 do
		P(Vector3.new(5, 14, 27), Vector3.new(-234 + i * 52, 7, 122), { Color = BLOCK, Material = Enum.Material.Concrete })
	end
	for floor = 0, 3 do
		for x = -224, 224, 14 do
			deco(Vector3.new(9, 7, 0.4), Vector3.new(x, 23.5 + floor * 11, 108.9), Color3.fromRGB(120, 150, 172), Enum.Material.Glass, steel)
		end
	end
	for x = -200, 200, 50 do
		lampPost(x, 88)
	end

	---------------------------------------------------------------- 단지 바깥 도시 (멀리 보이는 건물들, 그림자 없음)
	for _, info in {
		{ -150, -210, 120, 60, 110, Color3.fromRGB(176, 170, 160) }, { 10, -216, 140, 60, 150, Color3.fromRGB(160, 168, 176) }, { 170, -208, 110, 60, 96, Color3.fromRGB(186, 178, 168) },
		{ -276, -60, 50, 140, 70, Color3.fromRGB(170, 166, 158) }, { 278, -40, 50, 160, 120, Color3.fromRGB(158, 166, 176) }, { -276, 90, 50, 110, 90, Color3.fromRGB(176, 172, 166) }, { 278, 100, 50, 90, 76, Color3.fromRGB(182, 176, 166) },
	} do
		deco(Vector3.new(info[3], info[5], info[4]), Vector3.new(info[1], info[5] / 2, info[2]), info[6], Enum.Material.Concrete, steel)
	end

	---------------------------------------------------------------- 🏬 대충상사 상가 건물 (서쪽) + 1층 가게 계산대
	local SITE = Campus.DAECHUNG_SITE
	F.daechung = CampusDaechung.build(folder, SITE)
	local DB = Build.new(folder, SITE) -- 건물 기준 좌표 (앞면 z 0, 앞쪽 +z)
	local frontLook = -SITE.LookVector -- 건물 앞(문 쪽)
	local function world(x: number, y: number, z: number): Vector3
		return SITE:PointToWorldSpace(Vector3.new(x, y, z))
	end
	-- ☕ 커피집 · 🍢 분식집 계산대 (문을 보고 있어요. 점원과 [E] 주문은 Street 모듈이 붙여요)
	local function shopCounter(x: number, title: string, menu: string)
		local z = -11
		local part = DB:part(Vector3.new(6, 3.4, 2), Vector3.new(x, 1.7, z), { Name = "ShopCounter", Color = M.woodLight, Material = Enum.Material.Wood })
		if Meshes.ready("StoreCounter") then
			part.Transparency = 1
			Meshes.place(DB, "StoreCounter", Vector3.new(x, 0, z), 0)
		end
		if Meshes.ready("StoreShelf") then
			Meshes.place(DB, "StoreShelf", Vector3.new(x + 6, 0, z - 7), 0, { scale = 0.9 })
		end
		local board = DB:part(Vector3.new(9, 1.4, 0.2), Vector3.new(x - 2, 10.2, z - 7.7), { Color = M.navy, CanCollide = false })
		Build.surfaceText(board, Enum.NormalId.Back, title, { Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1) })
		local list = DB:part(Vector3.new(9, 3, 0.2), Vector3.new(x - 2, 7.8, z - 7.7), { Color = M.cream, CanCollide = false })
		Build.surfaceText(list, Enum.NormalId.Back, menu, { Font = Enum.Font.GothamMedium, TextColor3 = M.navy })
		return { counter = part, clerkSpot = world(x, 0, z - 2.2), clerkLook = frontLook }
	end
	F.shops.cafe1f = shopCounter(14, "골목 커피", "믹스커피 500\n유자차 700\n비타민 음료 900")
	F.shops.bunsik = shopCounter(39, "대충 분식", "떡볶이 600\n김밥 1,000\n라볶이 세트 1,800")
	-- 🏪 편의점: 진열대는 늘 있고, 계산대(=대충상사의 매점)는 대충상사 서버에만 있어요. 눈치물산은 12층 복도에 사내 매점이 있어요.
	local SB = Build.new(folder, SITE * CFrame.new(0, -helpers.FLOOR_Y, 0)) -- (helpers.v가 바닥 높이를 더해 주니 그만큼 빼 둬요)
	helpers.decorateStore(SB, {
		center = Vector2.new(-12, -9.5),
		size = Vector2.new(23, 19),
		wallX = -22.7,
		z1 = -15,
		z2 = -4,
		fridge = Vector2.new(-22, -17.2),
		signPosition = helpers.v(-0.7, 10, -10),
		signFace = Enum.NormalId.Left,
	})
	if companyId == "daechung" then
		local store = helpers.buildStore(SB, -12, -11, M.mintDark)
		store.clerkSpot = SB:cf(CFrame.new(store.clerkSpot)).Position
		store.clerkLook = frontLook
		F.daechungStore = store
	end

	---------------------------------------------------------------- 👮 단지 경비원 (Guard 모듈이 만들어요): 대충상사 입구 옆 초소 + 순찰 지점
	--   두 건물 앞 → 공원 큰길 → 분수 광장 → 순환로 → 눈치 스트리트를 돌아요. 근무 시간에 단지에서 놀다 눈에 띄면 의심도가 올라요.
	--   넓은 단지를 세 구역으로 나눠 한 명씩 맡아요. 구역 사이로 빠져나갈 틈이 있어요.
	F.guardPost = world(-70, 0, 6)
	F.guardPatrol = { -- 👮 박씨: 대충상사 건물 앞 · 로비 · 가게 · 공원 서쪽
		world(-40, 0, 8), world(-10, 0, 8), world(20, 0, 6), world(52, 0, 8),
		world(-45, 0, -6), world(-12, 0, -5), world(14, 0, -5), world(42, 0, -5),
		Campus.point(-100, 0, -92), Campus.point(-100, 0, -20), Campus.point(-100, 0, 52), Campus.point(-134, 0, 40),
	}
	F.guards = {
		{ id = "park", name = "경비원 박씨", post = F.guardPost, patrol = F.guardPatrol },
		{ -- 👮 최씨: 공원 한가운데 (큰길 · 분수 광장 · 북쪽 길 · 남쪽 텃밭 · 식탁)
			id = "park2", name = "경비원 최씨", post = Campus.point(-12, 0, -106),
			patrol = {
				Campus.point(0, 0, -92), Campus.point(0, 0, -56), Campus.point(-34, 0, -20), Campus.point(-64, 0, -20),
				Campus.point(0, 0, 14), Campus.point(0, 0, 52), Campus.point(40, 0, 52), Campus.point(63, 0, 40),
				Campus.point(34, 0, -20), Campus.point(64, 0, -20), Campus.point(50, 0, -92),
			},
		},
		{ -- 👮 정씨: 눈치물산 타워 앞 · 로비 · 푸드트럭 광장 · 눈치 스트리트
			id = "park3", name = "경비원 정씨", post = Campus.point(140, 0, 16),
			patrol = {
				Campus.point(140, 0, -50), Campus.point(164, 0, -50), Campus.point(140, 0, -90), Campus.point(100, 0, -92),
				Campus.point(100, 0, -20), Campus.point(100, 0, 52), Campus.point(150, 0, 34),
				Campus.point(104, 0, 102), Campus.point(52, 0, 102), Campus.point(0, 0, 102), Campus.point(-52, 0, 102), Campus.point(-104, 0, 102),
			},
		},
	}
	F.contains = Campus.contains
	F.commuteSpawn = Campus.SPAWN

	---------------------------------------------------------------- 👀 창밖 시선: 부장님이 내려다보는 창 (WindowWatch 모듈이 켜고 꺼요)
	--   대충상사는 상가 3층 창, 눈치물산은 타워 12층 창. 평소엔 안 보여요.
	local daechungWindow = DB:part(Vector3.new(22, 10, 0.5), Vector3.new(0, 51, 0.6), { Material = Enum.Material.Neon, Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
	local nunchiWindow = P(Vector3.new(0.5, 10, 36), Vector3.new(150.8, 138, -50), { Material = Enum.Material.Neon, Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
	F.windows = {
		daechung = { part = daechungWindow, position = daechungWindow.Position },
		nunchi = { part = nunchiWindow, position = nunchiWindow.Position },
	}

	return F
end

return Campus
