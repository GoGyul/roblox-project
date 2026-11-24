-- 🚏 도착 동선 (리뉴얼 대충상사): 건물 앞 거리 + 1층 로비 + 엘리베이터·계단
--   처음 접속하면 버스 정류장 앞에서 시작해요 → 건물 입구 → 로비 → 엘리베이터(빠름) 또는 계단(느리지만 부장님을 안 만나요) → 3층
--   그 뒤로 다시 태어날 땐 3층 엘리베이터 앞이에요 (사무실의 SpawnLocation).
--   거리와 로비는 사무실에서 멀리 떨어진 곳(BASE)에 지어요. 옥상처럼 순간이동으로 오가요.
--   엘리베이터 [E]를 누르면 층 고르기 창(옥상 / 3층 / 1층)이 떠요. 3층 계단실의 계단 문으로도 내려가요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Build = require(ReplicatedStorage.Shared.Build)
local Theme = require(ReplicatedStorage.Shared.SalaryTheme)
local Meshes = require(script.Parent.Meshes)
local Rooftop = require(script.Parent.Rooftop)
local Ambience = require(script.Parent.Ambience)
local OfficeDaechung = require(script.Parent.OfficeDaechung)

local Arrival = {}

local BASE = OfficeDaechung.STREET_BASE -- 거리 바닥 윗면 기준점 (건물 남쪽 벽이 z 0, 길은 +z 쪽)
local M = Theme.Mesh
local FLOOR_H = 21 -- 한 층 높이
local ELEVATOR_SECONDS = 2.5
local STAIRS_SECONDS = 7 -- 계단은 느려요 (대신 부장님과 마주칠 일이 없어요)

local FACADE = Color3.fromRGB(198, 186, 164)
local BAND = Color3.fromRGB(150, 140, 124)
local GLASS = Color3.fromRGB(120, 150, 172)
local DARK = Color3.fromRGB(70, 76, 84)

local function build(folder: Folder)
	local B = Build.new(folder, BASE)
	local function P(size: Vector3, position: Vector3, props: { [string]: any }?): BasePart
		return B:part(size, position, props)
	end
	local soft = { CanCollide = false, CanQuery = false }
	local function deco(size: Vector3, position: Vector3, color: Color3, material: Enum.Material?): BasePart
		return P(size, position, { Color = color, Material = material or Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false })
	end
	local function text(part: BasePart, face: Enum.NormalId, message: string, color: Color3?)
		Build.surfaceText(part, face, message, { Font = Enum.Font.GothamBold, TextColor3 = color or Color3.new(1, 1, 1) })
	end
	local function mesh(kind: string, x: number, y: number, z: number, yaw: number, options: any?)
		if Meshes.ready(kind) then
			return Meshes.place(B, kind, Vector3.new(x, y, z), yaw, options)
		end
		return nil
	end

	---------------------------------------------------------------- 길
	P(Vector3.new(224, 1, 15), Vector3.new(0, -0.5, 7.5), { Color = Color3.fromRGB(186, 180, 168), Material = Enum.Material.Pavement }) -- 인도
	P(Vector3.new(224, 1, 32), Vector3.new(0, -0.7, 31), { Color = Color3.fromRGB(66, 68, 72), Material = Enum.Material.Asphalt }) -- 차도
	P(Vector3.new(224, 1, 15), Vector3.new(0, -0.5, 54.5), { Color = Color3.fromRGB(186, 180, 168), Material = Enum.Material.Pavement }) -- 건너편 인도
	for x = -100, 100, 18 do
		deco(Vector3.new(9, 0.05, 0.5), Vector3.new(x, -0.18, 31), Color3.fromRGB(226, 186, 70)) -- 중앙선
	end
	for k = -3, 3 do
		deco(Vector3.new(1.6, 0.05, 26), Vector3.new(-45 + k * 3.2, -0.18, 31), Color3.fromRGB(232, 232, 228)) -- 횡단보도
	end
	-- 못 나가게 막는 투명 벽 (길 양끝 · 건너편)
	for _, info in { { Vector3.new(1, 60, 64), Vector3.new(-112, 30, 31) }, { Vector3.new(1, 60, 64), Vector3.new(112, 30, 31) }, { Vector3.new(226, 60, 1), Vector3.new(0, 30, 62.5) } } do
		P(info[1], info[2], { Transparency = 1 })
	end

	---------------------------------------------------------------- 건물 (4층 상가, 1층 서쪽 모퉁이가 로비)
	local top = FLOOR_H * 4
	-- 상가 쪽 몸통: 1층 가게 세 칸(각 x ±11.5 / z -19~0 / 높이 13.5)만 비워 두고 지어요
	local SHOP_H = 13.5
	local SHOPS = { { x = -12, color = M.mintDark, name = "편의점" }, { x = 14, color = M.coral, name = "커피" }, { x = 42, color = M.yellow, name = "분식" } }
	local body = { Color = FACADE, Material = Enum.Material.Concrete }
	P(Vector3.new(90, top - SHOP_H, 40), Vector3.new(15, SHOP_H + (top - SHOP_H) / 2, -20), body) -- 2층부터 위
	P(Vector3.new(89, SHOP_H, 21), Vector3.new(15.5, SHOP_H / 2, -29.5), body) -- 가게 뒤 (로비 벽과 면이 겹쳐 떨리지 않게 x -29부터)
	for _, span in { { -29, -23.5 }, { -0.5, 2.5 }, { 25.5, 30.5 }, { 53.5, 60 } } do -- 가게 사이 벽 (맨 왼쪽은 로비 벽 바로 옆부터)
		P(Vector3.new(span[2] - span[1], SHOP_H, 19), Vector3.new((span[1] + span[2]) / 2, SHOP_H / 2, -9.5), body)
	end
	P(Vector3.new(30, top - 14.5, 40), Vector3.new(-45, 14.5 + (top - 14.5) / 2, -20), { Color = FACADE, Material = Enum.Material.Concrete }) -- 로비 위
	for k = 1, 4 do
		deco(Vector3.new(120.6, 1.2, 0.6), Vector3.new(0, FLOOR_H * k, 0.2), BAND, Enum.Material.Concrete)
	end
	for k = 1, 3 do
		for x = -52, 52, 13 do
			local lit = k == 2 and (x == -26 or x == 0 or x == 13) -- 3층(대충상사)에 불 켜진 창
			deco(Vector3.new(9.5, 10, 0.3), Vector3.new(x, FLOOR_H * k + 9, 0.1), if lit then Color3.fromRGB(255, 240, 200) else GLASS, if lit then Enum.Material.Neon else Enum.Material.Glass)
			deco(Vector3.new(10.3, 0.5, 0.5), Vector3.new(x, FLOOR_H * k + 3.8, 0.25), M.cream)
			deco(Vector3.new(0.3, 10, 0.4), Vector3.new(x, FLOOR_H * k + 9, 0.25), M.cream)
		end
		for _, x in { -45.5, -6.5, 32.5 } do
			deco(Vector3.new(3.2, 2.4, 1.6), Vector3.new(x, FLOOR_H * k + 1.6, 0.9), Color3.fromRGB(214, 214, 208), Enum.Material.Metal) -- 실외기
		end
	end
	-- 1층 가게 세 칸: 모두 들어갈 수 있어요 (계산대·점원은 OfficeDaechung과 Street 모듈이 놓아요)
	local shopGlass = { Color = Color3.fromRGB(176, 206, 214), Material = Enum.Material.Glass, Transparency = 0.55 }
	local inside = Color3.fromRGB(240, 239, 234)
	for _, shop in SHOPS do
		local x = shop.x
		local board = deco(Vector3.new(22, 3.4, 0.8), Vector3.new(x, 16.2, 0.5), shop.color)
		text(board, Enum.NormalId.Back, shop.name)
		-- 바닥 (이게 없으면 가게에 들어가다 아래로 떨어져요)
		P(Vector3.new(23, 1, 19), Vector3.new(x, -0.5, -9.5), { Color = Color3.fromRGB(226, 224, 216), Material = Enum.Material.Marble })
		-- 앞면: 유리창 두 장 + 가운데 문 자리(폭 6) + 문 위 유리
		P(Vector3.new(7.5, 12, 0.4), Vector3.new(x - 7.75, 6, -0.2), shopGlass)
		P(Vector3.new(7.5, 12, 0.4), Vector3.new(x + 7.75, 6, -0.2), shopGlass)
		P(Vector3.new(8, 2, 0.4), Vector3.new(x, 11, -0.2), shopGlass) -- 문 위 유리 (문은 폭 8 · 높이 10)
		P(Vector3.new(23, 1.5, 0.9), Vector3.new(x, 12.75, -0.5), { Color = FACADE, Material = Enum.Material.Concrete })
		for _, dx in { -4.1, 4.1 } do
			P(Vector3.new(0.3, 10, 0.5), Vector3.new(x + dx, 5, -0.2), { Color = DARK, Material = Enum.Material.Metal }) -- 문틀
		end
		-- 안쪽: 흰 벽·천장, 조명
		-- (건물 앞면 z 0까지 닿으면 유리·외벽과 같은 면에서 떨려서, 앞쪽 1칸은 비워요. 높이도 천장 덩어리에서 살짝 띄워요)
		deco(Vector3.new(0.1, SHOP_H - 0.2, 17.9), Vector3.new(x - 11.44, SHOP_H / 2 - 0.1, -9.95), inside)
		deco(Vector3.new(0.1, SHOP_H - 0.2, 17.9), Vector3.new(x + 11.44, SHOP_H / 2 - 0.1, -9.95), inside)
		deco(Vector3.new(22.8, SHOP_H - 0.2, 0.1), Vector3.new(x, SHOP_H / 2 - 0.1, -18.94), inside)
		deco(Vector3.new(22.8, 0.1, 17.9), Vector3.new(x, SHOP_H - 0.12, -9.95), inside)
		for _, dx in { -5, 5 } do
			local lamp = deco(Vector3.new(1.4, 0.2, 9), Vector3.new(x + dx, SHOP_H - 0.25, -9.5), Color3.fromRGB(236, 236, 230), Enum.Material.Neon)
			local light = Instance.new("PointLight")
			light.Range = 20
			light.Brightness = 0.45
			light.Parent = lamp
		end
		local openSign = deco(Vector3.new(3, 1, 0.15), Vector3.new(x, 11, 0.1), shop.color)
		text(openSign, Enum.NormalId.Back, "영업중")
	end
	-- ☕ 커피집: 창가 테이블 두 개 / 🍢 분식집: 식탁 두 개와 의자
	for _, tx in { 6, 22 } do
		mesh("RoundTable", tx, 0, -4.5, 0)
		P(Vector3.new(2.4, 1.4, 2.4), Vector3.new(tx, 0.7, -4.5), { Transparency = 1 })
		mesh("DiningChair", tx, 0, -7.2, 180)
	end
	for _, tz in { -5, -11 } do
		mesh("DiningTable", 49, 0, tz, 90, { scale = 0.8 })
		P(Vector3.new(2.8, 2.2, 4.8), Vector3.new(49, 1.1, tz), { Transparency = 1 })
		mesh("DiningChair", 46, 0, tz, -90)
		mesh("DiningChair", 52, 0, tz, 90)
	end
	-- 옥상 난간 · 물탱크
	deco(Vector3.new(120, 3, 1), Vector3.new(0, top + 1.5, -0.5), FACADE, Enum.Material.Concrete)
	deco(Vector3.new(10, 7, 10), Vector3.new(26, top + 7.5, -12), Color3.fromRGB(220, 178, 70), Enum.Material.Metal).Shape = Enum.PartType.Cylinder
	-- 옆 건물
	for _, info in { { -87, 50, 60, Color3.fromRGB(176, 170, 160) }, { 87, 50, 104, Color3.fromRGB(160, 168, 176) } } do
		P(Vector3.new(info[2], info[3], 40), Vector3.new(info[1], info[3] / 2, -20), { Color = info[4], Material = Enum.Material.Concrete })
		for y = 10, info[3] - 4, 11 do
			deco(Vector3.new(info[2] * 0.86, 5, 0.3), Vector3.new(info[1], y, 0.1), GLASS, Enum.Material.Glass)
		end
	end

	---------------------------------------------------------------- 건물 입구 (서쪽) · 캐노피 · 층별 안내
	P(Vector3.new(9, 14.5, 1), Vector3.new(-55.5, 7.25, -0.5), { Color = FACADE, Material = Enum.Material.Concrete })
	P(Vector3.new(10, 14.5, 1), Vector3.new(-35, 7.25, -0.5), { Color = FACADE, Material = Enum.Material.Concrete })
	P(Vector3.new(11, 2.5, 1), Vector3.new(-45.5, 13.25, -0.5), { Color = FACADE, Material = Enum.Material.Concrete })
	deco(Vector3.new(13, 0.8, 5), Vector3.new(-45.5, 14.4, 2.5), DARK, Enum.Material.Metal)
	for _, x in { -51.5, -39.5 } do
		P(Vector3.new(0.4, 14, 0.4), Vector3.new(x, 7, 4.6), { Color = DARK, Material = Enum.Material.Metal })
	end
	local directory = deco(Vector3.new(4, 13, 0.6), Vector3.new(-57, 27, 0.5), Color3.fromRGB(44, 62, 92))
	text(directory, Enum.NormalId.Back, "4F 세무사\n3F (주)대충상사\n2F 치과\n1F 상가\nB1 헬스")

	---------------------------------------------------------------- 거리 소품
	for _, x in { -78, -22, 6, 34, 62 } do
		mesh("Tree", x, 0, 12.5, x * 7, { scale = 1.5 })
		P(Vector3.new(1.4, 5, 1.4), Vector3.new(x, 2.5, 12.5), { Transparency = 1 })
	end
	for _, x in { -64, -8, 48 } do
		local post = mesh("LampPost", x, 0, 13.2, 0, { scale = 2.2 })
		if post then
			local glow = Instance.new("PointLight")
			glow.Range = 22
			glow.Brightness = 0.4
			glow.Color = Theme.Color.yellowSoft
			glow.Parent = post.Bulb
		end
	end
	-- 전봇대
	P(Vector3.new(1, 44, 1), Vector3.new(20, 22, 13.8), { Color = Color3.fromRGB(120, 112, 100), Material = Enum.Material.Wood })
	deco(Vector3.new(9, 0.5, 0.5), Vector3.new(20, 40, 13.8), Color3.fromRGB(120, 112, 100), Enum.Material.Wood)
	for _, dx in { -4, 0, 4 } do
		deco(Vector3.new(224, 0.12, 0.12), Vector3.new(0, 40.3 + dx * 0.05, 13.8 + dx * 0.02), Color3.fromRGB(40, 40, 44))
	end
	-- 버스 정류장
	for _, x in { -33, -21 } do
		for _, z in { 9.4, 12 } do
			P(Vector3.new(0.3, 8, 0.3), Vector3.new(x, 4, z), { Color = DARK, Material = Enum.Material.Metal })
		end
	end
	deco(Vector3.new(13, 0.3, 3.4), Vector3.new(-27, 8.2, 10.7), DARK, Enum.Material.Metal)
	deco(Vector3.new(12, 6, 0.12), Vector3.new(-27, 4.4, 9.4), Color3.fromRGB(190, 214, 226), Enum.Material.Glass).Transparency = 0.5
	local busSign = deco(Vector3.new(2.4, 2.4, 0.3), Vector3.new(-18.5, 9, 12.5), Color3.fromRGB(60, 110, 190))
	text(busSign, Enum.NormalId.Back, "버스")
	P(Vector3.new(0.3, 8, 0.3), Vector3.new(-18.5, 4, 12.5), { Color = Color3.fromRGB(60, 110, 190), Material = Enum.Material.Metal })
	mesh("Bench", -27, 0, 10.4, 0, { scale = 1.3 })
	P(Vector3.new(5.4, 1.8, 1.6), Vector3.new(-27, 0.9, 10.4), { Transparency = 1 })
	-- 세워 둔 차
	P(Vector3.new(16, 3.2, 7), Vector3.new(46, 2.6, 19.5), { Color = Color3.fromRGB(226, 226, 222), Material = Enum.Material.SmoothPlastic })
	P(Vector3.new(9, 2.8, 6.4), Vector3.new(45.4, 5.4, 19.5), { Color = Color3.fromRGB(50, 62, 74), Material = Enum.Material.Glass })
	for _, dx in { -5, 5 } do
		for _, dz in { -3.2, 3.2 } do
			local wheel = deco(Vector3.new(1, 2.6, 2.6), Vector3.new(46 + dx, 1.3, 19.5 + dz), Color3.fromRGB(40, 40, 44))
			wheel.Shape = Enum.PartType.Cylinder
			wheel.CFrame *= CFrame.Angles(0, math.rad(90), 0)
		end
	end

	---------------------------------------------------------------- 1층 로비 (x -60~-30 / z -20~0, 천장 14)
	local wallPaint = { Color = M.wall, Material = Enum.Material.Plaster }
	P(Vector3.new(30, 0.2, 20), Vector3.new(-45, 0.1, -10), { Color = Color3.fromRGB(196, 192, 184), Material = Enum.Material.Marble })
	P(Vector3.new(30, 0.5, 20), Vector3.new(-45, 14.25, -10), { Color = M.surface })
	P(Vector3.new(1, 14, 20), Vector3.new(-60.5, 7, -10), wallPaint)
	P(Vector3.new(1, 13.4, 20), Vector3.new(-29.5, 6.7, -10), wallPaint) -- (위쪽 상가 덩어리 밑면 13.5보다 낮게: 면이 겹치면 떨려요)
	-- 북쪽 벽: 가운데(x -53~-43)는 계단실로 뚫려 있어요
	P(Vector3.new(7, 14, 1), Vector3.new(-56.5, 7, -20.5), wallPaint)
	P(Vector3.new(13, 14, 1), Vector3.new(-36.5, 7, -20.5), wallPaint)
	P(Vector3.new(10, 4.5, 1), Vector3.new(-48, 11.75, -20.5), wallPaint)
	for _, info in { { Vector3.new(0.12, 4, 19.8), Vector3.new(-59.92, 2, -10) }, { Vector3.new(0.12, 4, 19.8), Vector3.new(-30.08, 2, -10) }, { Vector3.new(6.8, 4, 0.12), Vector3.new(-56.5, 2, -19.92) }, { Vector3.new(12.8, 4, 0.12), Vector3.new(-36.5, 2, -19.92) } } do
		deco(info[1], info[2], M.sage) -- 허리 높이 페인트 띠
	end
	for _, x in { -52, -38 } do
		for _, z in { -15, -6 } do
			local lamp = deco(Vector3.new(5.4, 0.2, 1.4), Vector3.new(x, 13.9, z), Color3.fromRGB(226, 224, 214), Enum.Material.Neon)
			local light = Instance.new("PointLight")
			light.Range = 22
			light.Brightness = 0.35
			light.Color = Color3.fromRGB(255, 248, 232)
			light.Parent = lamp
		end
	end
	-- 엘리베이터 (서쪽 벽)
	mesh("ElevatorDoor", -59.5, 0, -12, 90)
	local elevatorDoor = P(Vector3.new(0.4, 8.3, 5), Vector3.new(-59.8, 4.15, -12), { Color = M.line, Material = Enum.Material.Metal, Transparency = if Meshes.ready("ElevatorDoor") then 1 else 0 })
	local floors = deco(Vector3.new(0.15, 5, 3.4), Vector3.new(-59.9, 6.5, -6.4), Color3.fromRGB(44, 62, 92))
	text(floors, Enum.NormalId.Right, "4F 세무사\n3F (주)대충상사\n2F 치과\nB1 헬스")
	-- 경비실 창구 · 우편함 · 게시판 · 자판기 · 화분
	mesh("StoreCounter", -36, 0, -17.4, 0)
	P(Vector3.new(6.3, 3.2, 2.3), Vector3.new(-36, 1.6, -17.4), { Transparency = 1 })
	local guardSign = deco(Vector3.new(4, 1, 0.2), Vector3.new(-36, 9, -19.8), DARK)
	text(guardSign, Enum.NormalId.Back, "경비실")
	for row = 0, 3 do
		for column = 0, 4 do
			deco(Vector3.new(0.5, 1.2, 1.5), Vector3.new(-30.3, 4 + row * 1.4, -13 + column * 1.7), Color3.fromRGB(170, 176, 180), Enum.Material.Metal)
		end
	end
	mesh("NoticeBoard", -30.2, 6.5, -3.4, -90)
	mesh("Vending", -57.6, 0, -18.4, 0)
	P(Vector3.new(3, 6.2, 2.4), Vector3.new(-57.6, 3.1, -18.4), { Transparency = 1 })
	mesh("Plant", -57.8, 0, -2.4, 0, { scale = 1.5 })
	mesh("TrashBin", -54.6, 0, -19, 0)
	---------------------------------------------------------------- 계단실 (로비 북쪽 벽 뒤, x -53~-43 / z -31~-21)
	-- 꺾여 올라가는 계단: 서쪽 반은 북쪽으로 올라가 계단참에 닿고, 동쪽 반은 되돌아 2층으로 이어져요.
	-- 실제로 걸어 올라갈 수 있고, 계단참에 닿으면 3층으로 이어져요.
	local concrete = { Color = Color3.fromRGB(176, 176, 172), Material = Enum.Material.Concrete }
	P(Vector3.new(10, 0.2, 11), Vector3.new(-48, 0.1, -25.5), concrete) -- (로비 바닥(z -20)과 틈 없이 딱 맞닿게)
	P(Vector3.new(1, 14.5, 11), Vector3.new(-53.5, 7.25, -26), wallPaint)
	P(Vector3.new(1, 14.5, 11), Vector3.new(-42.5, 7.25, -26), wallPaint)
	P(Vector3.new(12, 14.5, 1), Vector3.new(-48, 7.25, -31.5), wallPaint)
	P(Vector3.new(10, 0.5, 10.5), Vector3.new(-48, 14.25, -25.75), { Color = M.surface })
	local RUN, RISE = 7, 5.6
	local slope = math.atan(RISE / RUN)
	local length = math.sqrt(RUN * RUN + RISE * RISE)
	local function flight(x: number, zLow: number, yLow: number, direction: number)
		-- direction -1 = 북쪽(-z)으로 올라가요, 1 = 남쪽(+z)으로 올라가요
		local zMid, yMid = zLow + direction * RUN / 2, yLow + RISE / 2
		P(Vector3.new(4.6, 0.5, length), nil, { CFrame = CFrame.new(Vector3.new(x, yMid + 0.1, zMid)) * CFrame.Angles(-direction * slope, 0, 0), Color = concrete.Color, Material = concrete.Material }) -- 경사 바닥판 (이 위를 걸어요)
		for k = 0, 7 do
			deco(Vector3.new(4.6, 0.7, 0.9), Vector3.new(x, yLow + 0.7 * k + 0.35, zLow + direction * (k + 0.5) * RUN / 8), concrete.Color, concrete.Material) -- 디딤판
		end
		local railX = x + (if x < -48 then 2.2 else -2.2)
		deco(Vector3.new(0.2, 0.2, length), Vector3.new(railX, yMid + 3, zMid), DARK, Enum.Material.Metal).CFrame = CFrame.new(Vector3.new(railX, yMid + 3, zMid) + BASE) * CFrame.Angles(-direction * slope, 0, 0)
		for _, t in { 0.05, 0.5, 0.95 } do
			deco(Vector3.new(0.18, 3, 0.18), Vector3.new(railX, yLow + RISE * t + 1.5, zLow + direction * RUN * t), DARK, Enum.Material.Metal)
		end
	end
	flight(-50.6, -22, 0, -1)
	P(Vector3.new(10, 0.4, 2), Vector3.new(-48, RISE - 0.2, -30), concrete) -- 계단참
	flight(-45.4, -29, RISE, 1)
	P(Vector3.new(4.8, 9, 0.6), Vector3.new(-45.4, 10, -21.4), { Transparency = 1 }) -- 2층 쪽은 막아 둬요
	local floorMark = deco(Vector3.new(0.15, 1.6, 2.4), Vector3.new(-53, 9.5, -27), DARK)
	text(floorMark, Enum.NormalId.Right, "1F ▲ 3F")
	local stairLight = deco(Vector3.new(1.2, 0.2, 4), Vector3.new(-48, 13.9, -26), Color3.fromRGB(226, 224, 214), Enum.Material.Neon)
	local stairGlow = Instance.new("PointLight")
	stairGlow.Range = 18
	stairGlow.Brightness = 0.35
	stairGlow.Parent = stairLight
	local stairSign = deco(Vector3.new(4, 1, 0.2), Vector3.new(-48, 10.6, -19.9), Color3.fromRGB(40, 110, 80))
	text(stairSign, Enum.NormalId.Back, "계단")
	local stairTrigger = P(Vector3.new(4.6, 3, 1), Vector3.new(-50.6, 1.5, -21.4), { Transparency = 1, CanCollide = false }) -- 계단 첫 단 앞: [E] 3층으로 올라가기

	return {
		spawn = CFrame.lookAt(BASE + Vector3.new(-27, 3, 12.6), BASE + Vector3.new(-45, 3, 0)), -- 버스 정류장 앞, 건물 입구를 보고
		lobbyElevator = CFrame.new(BASE + Vector3.new(-55, 3, -12)) * CFrame.Angles(0, math.rad(-90), 0),
		lobbyStairs = CFrame.new(BASE + Vector3.new(-48, 3, -17.5)) * CFrame.Angles(0, math.rad(180), 0), -- 계단실 입구 앞 (로비를 보고)
		elevatorDoor = elevatorDoor,
		stairTrigger = stairTrigger,
		soft = soft,
	}
end

function Arrival.start(office, remotes)
	if office.companyId ~= "daechung" or not office.stairSpot then
		return -- 리뉴얼한 대충상사에만 있어요
	end
	local folder = Instance.new("Folder")
	folder.Name = "Arrival"
	folder.Parent = workspace
	local place = build(folder)
	Ambience.loop("street", folder, BASE + Vector3.new(0, 6, 20), 140) -- 🚗 거리 소리
	Ambience.loop("lobby", folder, BASE + Vector3.new(-45, 7, -10), 34) -- 로비 소리

	local traveling: { [Player]: boolean } = {}
	local function travel(player: Player, target: CFrame, seconds: number, message: string)
		if traveling[player] then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not humanoid or humanoid.Health <= 0 then
			return
		end
		traveling[player] = true
		remotes.Notify:FireClient(player, message)
		humanoid.Sit = false
		local speed = humanoid.WalkSpeed
		humanoid.WalkSpeed = 0
		task.delay(seconds, function()
			traveling[player] = nil
			if character.Parent and humanoid.Health > 0 then
				if humanoid.WalkSpeed == 0 then
					humanoid.WalkSpeed = speed
				end
				character:PivotTo(target)
				if string.find(message, "엘리베이터", 1, true) then
					Ambience.ding(target.Position) -- 🔔 띵
				end
			end
		end)
	end
	local function prompt(part: BasePart, action: string, object: string, hold: number, onTrigger: (Player) -> ())
		local p = Instance.new("ProximityPrompt")
		p.ActionText = action
		p.ObjectText = object
		p.HoldDuration = hold
		p.MaxActivationDistance = 9
		p.RequiresLineOfSight = false
		p.Parent = part
		p.Triggered:Connect(onTrigger)
	end

	local officeElevator = CFrame.new(office.elevator.exit + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.rad(-90), 0)
	local officeStairs = CFrame.new(office.stairSpot + Vector3.new(-3, 3, 0)) * CFrame.Angles(0, math.rad(90), 0) -- 계단 문 앞 (방 안쪽을 보고)

	-- 🚪 엘리베이터: [E] → 층 고르기 창 → 고른 층으로 (3층↔옥상은 예전처럼 Rooftop이 태워요: 부장님과 마주칠 수 있어요)
	local FLOOR_NAMES = { roof = "옥상", office = "3층 (주)대충상사", lobby = "1층 로비" }
	local FLOOR_ORDER = { "roof", "office", "lobby" }
	local pending: { [Player]: { from: string, at: number } } = {}
	local function openMenu(player: Player, from: string)
		pending[player] = { from = from, at = os.clock() }
		local options = {}
		for _, id in FLOOR_ORDER do
			if id ~= from then
				table.insert(options, { id = id, name = FLOOR_NAMES[id] })
			end
		end
		remotes.ElevatorMenu:FireClient(player, from, options)
	end
	local function near(player: Player, position: Vector3, range: number): boolean
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return root ~= nil and (root.Position - position).Magnitude <= range
	end
	local function rideRoof(player: Player, toRoof: boolean)
		if Rooftop.ride then
			Rooftop.ride(player, toRoof)
		end
	end
	remotes.ElevatorGo.OnServerEvent:Connect(function(player, destination)
		local request = pending[player]
		pending[player] = nil
		if not request or os.clock() - request.at > 20 or typeof(destination) ~= "string" or not FLOOR_NAMES[destination] or destination == request.from then
			return
		end
		local from = request.from
		-- 🛡️ 아직 그 엘리베이터 앞에 있는지 다시 확인해요
		if from == "office" and not near(player, office.elevator.exit, 18) then
			return
		elseif from == "lobby" and not near(player, place.lobbyElevator.Position, 18) then
			return
		end
		if from == "office" and destination == "roof" then
			rideRoof(player, true)
		elseif from == "roof" and destination == "office" then
			rideRoof(player, false)
		elseif from == "office" and destination == "lobby" then
			travel(player, place.lobbyElevator, ELEVATOR_SECONDS, "🚪 엘리베이터를 타고 1층으로 내려가요...")
		elseif from == "lobby" and destination == "office" then
			travel(player, officeElevator, ELEVATOR_SECONDS, "🚪 엘리베이터를 타고 3층으로 올라가요...")
		elseif from == "lobby" and destination == "roof" then
			travel(player, officeElevator, ELEVATOR_SECONDS, "🚪 엘리베이터를 타고 올라가요... (3층을 지나 옥상으로)")
			task.wait(ELEVATOR_SECONDS + 0.4)
			if near(player, office.elevator.exit, 14) then
				rideRoof(player, true)
			end
		elseif from == "roof" and destination == "lobby" then
			rideRoof(player, false) -- 3층에 닿을 때까지 기다려요
			if near(player, office.elevator.exit, 14) then
				travel(player, place.lobbyElevator, 1, "🚪 3층을 지나 1층으로 내려가요...")
			end
		end
	end)
	Rooftop.onElevator = function(player: Player, from: string): boolean
		openMenu(player, from)
		return true
	end
	prompt(place.elevatorDoor, "타기", "엘리베이터", 0, function(player)
		openMenu(player, "lobby")
	end)

	-- 🚶 계단: 계단 앞에서 [E] (부장님을 안 만나는 대신 엘리베이터보다 오래 걸려요)
	prompt(place.stairTrigger, "3층으로 올라가기", "계단", 0.4, function(player)
		travel(player, officeStairs, STAIRS_SECONDS, "🚶 계단으로 3층까지 올라가요... (헉헉)")
	end)

	-- 3층 계단실: 동쪽 벽의 방화문 (계단은 문 뒤에 있어요) → [E] 1층으로 내려가기
	local spot = office.stairSpot
	local function piece(size: Vector3, offset: Vector3, color: Color3, material: Enum.Material, collide: boolean): Part
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = collide
		part.Size = size
		part.Color = color
		part.Material = material
		part.CFrame = CFrame.new(spot + offset)
		part.Parent = office.folder
		return part
	end
	local frameColor, doorColor = Color3.fromRGB(70, 76, 84), Color3.fromRGB(138, 146, 152)
	local door = piece(Vector3.new(0.3, 10, 5.6), Vector3.new(3.0, 5, 0), doorColor, Enum.Material.Metal, true)
	door.Name = "StairsDoor"
	piece(Vector3.new(0.5, 10.6, 0.4), Vector3.new(2.95, 5.3, -3.0), frameColor, Enum.Material.Metal, false) -- 문틀
	piece(Vector3.new(0.5, 10.6, 0.4), Vector3.new(2.95, 5.3, 3.0), frameColor, Enum.Material.Metal, false)
	piece(Vector3.new(0.5, 0.5, 6.4), Vector3.new(2.95, 10.4, 0), frameColor, Enum.Material.Metal, false)
	piece(Vector3.new(0.1, 2.6, 1.4), Vector3.new(2.82, 6.6, 1.2), Color3.fromRGB(170, 196, 206), Enum.Material.Glass, false) -- 문에 난 작은 창
	piece(Vector3.new(0.3, 0.2, 1.2), Vector3.new(2.72, 4, -1.7), frameColor, Enum.Material.Metal, false) -- 손잡이
	local doorSign = piece(Vector3.new(0.2, 1.2, 3.6), Vector3.new(2.9, 11.6, 0), Color3.fromRGB(40, 110, 80), Enum.Material.SmoothPlastic, false)
	Build.surfaceText(doorSign, Enum.NormalId.Left, "계단", { Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1) })
	prompt(door, "1층으로 내려가기", "계단", 0.4, function(player)
		travel(player, place.lobbyStairs, STAIRS_SECONDS - 1, "🚶 계단으로 1층까지 내려가요...")
	end)

	-- 처음 접속했을 때 한 번만 거리에서 시작해요
	local arrived: { [Player]: boolean } = {}
	local function onCharacter(player: Player, character: Model)
		if arrived[player] then
			return
		end
		arrived[player] = true
		task.wait(0.6) -- 다른 모듈이 캐릭터를 자리 잡게 한 뒤에
		if character.Parent then
			character:PivotTo(place.spawn)
			remotes.Notify:FireClient(player, "🚏 출근길! 건물로 들어가 엘리베이터나 계단으로 3층 (주)대충상사에 올라가세요.")
		end
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		arrived[player] = nil
		traveling[player] = nil
		pending[player] = nil
	end)
end

return Arrival
