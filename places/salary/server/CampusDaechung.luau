-- 🏬 대충상사 상가 건물 (회사 단지 서쪽): 4층 상가 + 1층 로비 + 계단실 + 가게 세 칸(편의점·커피·분식)
--   좌표는 건물 기준이에요: 건물 앞면이 z 0, 앞쪽(공원 쪽)이 +z. Campus가 SITE로 돌려서 단지에 놓아요.
--   가게 계산대·점원은 Campus와 Street 모듈이, 엘리베이터·계단 동작은 Arrival이 붙여요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Build = require(ReplicatedStorage.Shared.Build)
local Theme = require(ReplicatedStorage.Shared.SalaryTheme)
local Meshes = require(script.Parent.Meshes)

local CampusDaechung = {}

local M = Theme.Mesh
local FLOOR_H = 21 -- 한 층 높이
local FACADE = Color3.fromRGB(198, 186, 164)
local BAND = Color3.fromRGB(150, 140, 124)
local GLASS = Color3.fromRGB(120, 150, 172)
local DARK = Color3.fromRGB(70, 76, 84)

function CampusDaechung.build(folder: Instance, SITE: CFrame)
	local B = Build.new(folder, SITE)
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
		if not Meshes.ready("ShopDoor") then
			for _, dx in { -4.1, 4.1 } do
				P(Vector3.new(0.3, 10, 0.5), Vector3.new(x + dx, 5, -0.2), { Color = DARK, Material = Enum.Material.Metal }) -- 문틀
			end
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
	-- 가게 앞: 줄무늬 차양 · 돌출 간판 · 열린 유리문 · 화분 · 입간판 (street_shops_set 메시)
	for _, shop in SHOPS do
		local x = shop.x
		mesh("ShopAwning", x, 12.3, 0.4, 0, { stretch = Vector3.new(20 / 12, 1, 0.9), colors = { StripeA = shop.color } })
		mesh("BladeSign", x - 11.6, 10.6, 0.5, -90, { colors = { Board = shop.color } })
		mesh("ShopDoor", x, 0, -0.2, 0, { stretch = Vector3.new(0.76, 1, 0.75) })
		mesh("ShopPlanter", x + 8, 0, 2.4, 0, { scale = 0.9 })
		P(Vector3.new(5.4, 2.4, 1.4), Vector3.new(x + 8, 1.2, 2.4), { Transparency = 1 })
		mesh("ABoard", x - 7, 0, 3.6, -15)
	end
	local function lamp(x: number, z: number, color: Color3?)
		local parts = mesh("PendantLamp", x, SHOP_H, z, 0)
		if parts then
			local glow = Instance.new("PointLight")
			glow.Range = 16
			glow.Brightness = 0.6
			glow.Color = color or Color3.fromRGB(255, 240, 214)
			glow.Shadows = false
			glow.Parent = parts.Bulb
		end
	end
	-- 🏪 편의점: 입구 옆 캡슐 뽑기 (장식)
	mesh("GachaMachine", -21.6, 0, -2.6, 90, { colors = { Body = M.mint } })
	mesh("GachaMachine", -21.6, 0, -5.0, 90, { colors = { Body = M.coral } })
	-- ☕ 골목 커피: 계산대(바)는 Campus가 놓아요. 창가 탁자 두 개 · 벽 선반 · 화분 · 조명
	for _, tx in { 6.5, 21.5 } do
		mesh("CafeTable", tx, 0, -4.2, 0)
		P(Vector3.new(1.2, 2.7, 1.2), Vector3.new(tx, 1.35, -4.2), { Transparency = 1 })
		mesh("CafeChair", tx - 2.2, 0, -4.2, 90)
		mesh("CafeChair", tx + 2.2, 0, -4.2, -90)
	end
	mesh("WallShelf", 24.9, 7.2, -12, -90)
	mesh("Plant", 4.2, 0, -17, 0, { scale = 1.6 })
	deco(Vector3.new(22.8, 3, 0.12), Vector3.new(14, 1.5, -18.86), M.mintDark) -- 허리벽
	for _, xz in { { 11.5, -11 }, { 16.5, -11 }, { 6.5, -4.2 }, { 21.5, -4.2 } } do
		lamp(xz[1], xz[2])
	end
	-- 🍢 대충 분식: 식탁 두 개 · 벽 쪽 간이 자리 · 빨간 조명
	local redChair = { colors = { Seat = M.red, Back = M.red } }
	for _, tz in { -4.5, -10.5 } do
		mesh("DiningTable", 49, 0, tz, 90, { scale = 0.8 })
		P(Vector3.new(2.8, 2.2, 4.8), Vector3.new(49, 1.1, tz), { Transparency = 1 })
		mesh("CafeChair", 46.2, 0, tz, 90, redChair)
		mesh("CafeChair", 51.8, 0, tz, -90, redChair)
		lamp(49, tz, Color3.fromRGB(255, 226, 200))
	end
	deco(Vector3.new(1.5, 0.25, 8), Vector3.new(31.5, 3.3, -6.5), M.woodLight, Enum.Material.Wood) -- 벽 쪽 간이 자리
	for _, tz in { -3.5, -6.5, -9.5 } do
		mesh("BarStool", 33.4, 0, tz, 0, { colors = { Seat = M.red } })
	end
	deco(Vector3.new(22.8, 3, 0.12), Vector3.new(42, 1.5, -18.86), M.red) -- 허리벽
	lamp(39, -11, Color3.fromRGB(255, 226, 200))
	-- 옥상 난간 · 물탱크
	deco(Vector3.new(120, 3, 1), Vector3.new(0, top + 1.5, -0.5), FACADE, Enum.Material.Concrete)
	deco(Vector3.new(10, 7, 10), Vector3.new(26, top + 7.5, -12), Color3.fromRGB(220, 178, 70), Enum.Material.Metal).Shape = Enum.PartType.Cylinder

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
		deco(Vector3.new(0.2, 0.2, length), Vector3.new(railX, yMid + 3, zMid), DARK, Enum.Material.Metal).CFrame = B:cf(CFrame.new(railX, yMid + 3, zMid) * CFrame.Angles(-direction * slope, 0, 0))
		for _, t in { 0.05, 0.5, 0.95 } do
			deco(Vector3.new(0.18, 3, 0.18), Vector3.new(railX, yLow + RISE * t + 1.5, zLow + direction * RUN * t), DARK, Enum.Material.Metal)
		end
	end
	flight(-50.6, -22, 0, -1)
	P(Vector3.new(10, 0.4, 2), Vector3.new(-48, RISE - 0.2, -30), concrete):SetAttribute("Walk", true) -- 계단참 (걸어 올라가는 곳: 올라타기 막기에서 빼요)
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
		lobbyElevator = SITE * CFrame.new(-47, 3, -10) * CFrame.Angles(0, math.rad(-90), 0), -- (벽에서 떨어진 로비 가운데쯤: 화면이 벽에 안 묻히게)
		lobbyStairs = SITE * CFrame.new(-48, 3, -17.5) * CFrame.Angles(0, math.rad(180), 0), -- 계단실 입구 앞 (로비를 보고)
		elevatorDoor = elevatorDoor,
		stairTrigger = stairTrigger,
		soft = soft,
	}
end

return CampusDaechung
