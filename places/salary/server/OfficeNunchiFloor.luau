-- 🏙️ (주)눈치물산 사무실 층 — 리뉴얼 평면 (신축 사옥: 통유리, 유리 회의실, 카페 라운지)
-- 건물 밖(공원·눈치 스트리트)은 OfficeNunchi가 예전처럼 짓고, 이 모듈은 건물 안(사무실 층 + 체력 단련실)만 지어요.
--
--   x -56                                         20                 56
--   ┌═══════════ 통유리 ═══[출입문 x 0 → 공원]════╦══════════════════┐ z -34
--   ║ [7] [1] [2] [8]            🖨️               ┊ 📊 유리 회의실     │
--   ║ [9] [3] [4] [10]                            ┊┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┤ z -18
--   ║ [11][5] [6] [12]                            ┊ ☕ 카페 라운지     │
--   ║        [김부장]                             ┊   (탕비실)        │
--   ├──────────────────────────[유리문 x 6]───────┘                   │ z 10
--   │🚪엘리베이터  안내 데스크      복 도 (📦 택배)          🏪 매점   │
--   ├──[x -46]──┬─────[x -22]─────┬────[x 6]──────┬─────[x 38]───────┤ z 20
--   │ 🚻 화장실  │ 🛋️ 휴게 라운지   │ 폰부스        │ 창고             │
--   └───────────┴──[x -16 🏋️]─────┴───────────────┴──────────────────┘ z 34
--                │ 🏋️ 체력 단련실 (별관) │
--
-- ═ ║ 는 바깥 통유리, ┊ 는 안쪽 유리 칸막이(부장님 눈에 그대로 보여요), 나머지는 흰 벽이에요.
-- 직원은 창을 보고 앉고(−Z), 부장님은 등 뒤에서 봐요. 책상 [1]~[6]이 게임에 쓰이는 자리예요.
-- 좌표는 "설계 좌표"이고 지을 때 S(1.25)를 곱해요 (실제 140×85칸). 건물 테두리는 예전(144×84)과 거의 같아서
-- 북쪽 출입문·공원·스트리트·체력 단련실 위치는 그대로예요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Build = require(ReplicatedStorage.Shared.Build)
local Theme = require(ReplicatedStorage.Shared.SalaryTheme)
local Meshes = require(script.Parent.Meshes)
local Npc = require(script.Parent.Npc)
local Ambience = require(script.Parent.Ambience)

local Floor = {}

local M = Theme.Mesh
local H = 22 -- 천장 높이
local S = 1.25
local HX, HZ = 56, 34
local DOOR_H = 11
local CORRIDOR_Z = 15

local GLASS_OUT = { Color = Color3.fromRGB(190, 214, 232), Material = Enum.Material.Glass, Transparency = 0.35 }
-- 안쪽 유리 칸막이는 CanQuery를 꺼서 부장님 시선(레이캐스트)이 통과해요 = 유리 너머가 그대로 보여요
local GLASS_IN = { Color = Color3.fromRGB(200, 222, 232), Material = Enum.Material.Glass, Transparency = 0.6, CanQuery = false }

local LAYOUT = {
	-- { 축, 고정 좌표, 시작, 끝, 재질("wall" | "out" | "in"), 문 { 중심, 폭 }... }
	walls = {
		{ "X", -HZ - 0.4, -HX - 1, HX + 1, "out", { 0, 6 } }, -- 북: 통유리 + 공원으로 나가는 출입문
		{ "Z", -HX - 0.4, -HZ, 10, "out" }, -- 서: 사무실 쪽 통유리
		{ "Z", -HX - 0.4, 10, HZ, "wall" }, -- 서: 복도·화장실 쪽
		{ "Z", HX + 0.4, -HZ, HZ, "wall" }, -- 동
		{ "X", HZ + 0.4, -HX - 1, HX + 1, "wall", { -16, 8 } }, -- 남 (🏋️ 체력 단련실 문, 실제 x -20)
		{ "X", 10, -HX, 20, "wall", { 6, 10 } }, -- 사무실 ↔ 복도
		{ "X", 20, -HX, HX, "wall", { -46, 7 }, { -22, 8 }, { 6, 8 }, { 38, 7 } }, -- 화장실 · 라운지 · 폰부스 · 창고
		{ "Z", -36, 20.4, HZ, "wall" },
		{ "Z", -8, 20.4, HZ, "wall" },
		{ "Z", 20, 20.4, HZ, "wall" },
		{ "Z", 20, -HZ, 10, "in", { -26, 7 }, { -6, 12 } }, -- 사무실 ↔ 회의실 · 카페 라운지 (유리)
		{ "X", -18, 20.4, HX, "in" }, -- 회의실 ↔ 카페 라운지 (유리)
	},
	deskRows = { -27, -17, -7 },
	deskColumns = { -30.5, -17 }, -- 게임에 쓰는 자리
	spareColumns = { -44, -3.5 }, -- 빈자리
	boss = { x = -24, z = 4.5 },
	gym = { cx = -20, hx = 32, hz = 24 }, -- 실제 좌표 (예전과 같은 자리)
}

function Floor.build(B, folder: Folder, company, helpers, C)
	local zone = helpers.zone
	local rv = helpers.v -- 실제 좌표
	local FLOOR_Y = helpers.FLOOR_Y
	local function v(x: number, y: number, z: number): Vector3 -- 설계 좌표 → 실제 좌표
		return rv(x * S, y, z * S)
	end
	local wallProps = { Color = C.wall, Material = Enum.Material.Plaster }
	local hidden = { Transparency = 1 }
	local dark = Color3.fromRGB(52, 56, 62)

	local function prop(kind: string, x: number, z: number, yaw: number, size: Vector3, options: any?, y: number?): BasePart
		local turned = math.abs(yaw) % 180 == 90
		local box = if turned then Vector3.new(size.Z, size.Y, size.X) else size
		local part = B:part(box, v(x, (y or 0) + size.Y / 2, z), { Color = M.surface })
		if Meshes.ready(kind) then
			part.Transparency = 1
			Meshes.place(B, kind, v(x, y or 0, z), yaw, options)
		end
		return part
	end
	local function decor(kind: string, x: number, z: number, yaw: number, options: any?, y: number?)
		if Meshes.ready(kind) then
			Meshes.place(B, kind, v(x, y or 0, z), yaw, options)
		end
	end
	local function sign(text: string, size: Vector3, position: Vector3, face: Enum.NormalId)
		local part = B:part(size, position, { Color = dark, CanCollide = false })
		Build.surfaceText(part, face, text, { Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1) })
	end

	---------------------------------------------------------------- 바닥 · 천장 · 벽
	local W, D = HX * 2 * S + 3, HZ * 2 * S + 3
	B:part(Vector3.new(W, 1, D), Vector3.new(0, FLOOR_Y - 0.5, 0), { Color = C.rug, Material = Enum.Material.Carpet })
	B:part(Vector3.new(W, 1, D), rv(0, H + 0.5, 0), { Color = C.wall })
	local oak = { Color = M.woodLight, Material = Enum.Material.WoodPlanks, CanCollide = false, CanQuery = false }
	local stone = { Color = Color3.fromRGB(222, 220, 214), Material = Enum.Material.Marble, CanCollide = false, CanQuery = false }
	B:part(Vector3.new(36 * S, 0.12, 28 * S), v(38, 0.1, -4), oak) -- 카페 라운지
	B:part(Vector3.new(28 * S, 0.12, 14 * S), v(-22, 0.1, 27), oak) -- 휴게 라운지
	B:part(Vector3.new(HX * 2 * S, 0.12, 10 * S), v(0, 0.1, CORRIDOR_Z), stone) -- 복도
	B:part(Vector3.new(20 * S, 0.12, 14 * S), v(-46, 0.1, 27), stone) -- 화장실
	B:part(Vector3.new(64 * S, 0.12, 14 * S), v(24, 0.1, 27), stone) -- 폰부스 · 창고
	for _, info in LAYOUT.walls do
		local doors = {}
		for i = 6, #info do
			table.insert(doors, { center = info[i][1] * S, width = info[i][2], height = DOOR_H })
		end
		local props = if info[5] == "out" then GLASS_OUT elseif info[5] == "in" then GLASS_IN else wallProps
		B:wall(info[1], info[2] * S, info[3] * S, info[4] * S, FLOOR_Y, H, doors, props)
	end
	-- 통유리 창틀 (북 · 서) + 안쪽 유리 칸막이 위아래 틀
	local frame = { Color = dark, Material = Enum.Material.Metal, CanCollide = false, CanQuery = false }
	for x = -HX, HX, 7 do
		if math.abs(x) > 3 then
			B:part(Vector3.new(0.5, H, 1.2), v(x, H / 2, -HZ - 0.4), frame)
		end
	end
	for z = -HZ, 10, 7 do
		B:part(Vector3.new(1.2, H, 0.5), v(-HX - 0.4, H / 2, z), frame)
	end
	B:part(Vector3.new(0.5, 0.5, 44 * S), v(20, DOOR_H + 0.3, -12), frame)
	B:part(Vector3.new(36 * S, 0.5, 0.5), v(38, DOOR_H + 0.3, -18), frame)
	for _, x in { -3.2 / S, 3.2 / S } do
		B:part(Vector3.new(0.5, DOOR_H, 1.2), v(x, DOOR_H / 2, -HZ - 0.4), frame) -- 출입문 틀
	end
	-- 사훈 · 벽시계 (사무실 남쪽 벽, 부장님 자리 뒤)
	local banner = B:part(Vector3.new(22, 2, 0.2), v(-24, 15, 9.55), { Color = C.accent, CanCollide = false })
	Build.surfaceText(banner, Enum.NormalId.Front, company.motto, { Font = Enum.Font.GothamBlack, TextColor3 = Color3.new(1, 1, 1) })
	local clockFace = B:part(Vector3.new(3, 3, 0.2), v(-44, 14, 9.55), { Color = C.wall, CanCollide = false })
	local setClock = Build.clockFace(clockFace, Enum.NormalId.Front)

	---------------------------------------------------------------- 사무실: 책상 12개 (게임용 6 + 빈자리 6)
	local desks = {}
	local index = 0
	for _, z in LAYOUT.deskRows do
		for _, x in LAYOUT.deskColumns do
			index += 1
			table.insert(desks, helpers.buildDesk(B, index, x * S, z * S))
		end
	end
	local spareDesks = {}
	for _, z in LAYOUT.deskRows do
		for _, x in LAYOUT.spareColumns do
			index += 1
			table.insert(spareDesks, helpers.buildDesk(B, index, x * S, z * S))
		end
	end
	-- 🧑‍💼 배경 직원 (빈자리 중 네 곳)
	local EXTRAS = {
		{ name = "서차장", skin = Color3.fromRGB(226, 194, 164), shirt = Color3.fromRGB(214, 222, 232), pants = Color3.fromRGB(52, 56, 66) },
		{ name = "문대리", skin = Color3.fromRGB(238, 208, 182), shirt = Color3.fromRGB(176, 190, 206), pants = Color3.fromRGB(60, 62, 70) },
		{ name = "강주임", skin = Color3.fromRGB(232, 200, 172), shirt = Color3.fromRGB(226, 222, 212), pants = Color3.fromRGB(70, 66, 62) },
		{ name = "윤사원", skin = Color3.fromRGB(240, 212, 188), shirt = Color3.fromRGB(196, 206, 196), pants = Color3.fromRGB(48, 52, 60) },
	}
	for i, extra in EXTRAS do
		local desk = spareDesks[if i <= 2 then i else i + 1] -- 창가 두 자리 + 가운데·뒷줄 한 자리씩
		if desk then
			task.defer(function()
				local model = Npc.create(extra.name, { skin = extra.skin, shirt = extra.shirt, pants = extra.pants }, folder)
				Npc.sit(model, desk.seat)
				Npc.setStatus(model, "⌨️")
			end)
		end
	end

	-- 김부장 자리 (뒷줄 의자 뒤)
	local BX, BZ = LAYOUT.boss.x, LAYOUT.boss.z
	Meshes.over(B, "BossDesk", v(BX, 0, BZ), 0, { skip = { Plate = true } }, function()
		B:part(Vector3.new(10, 2.5, 4), v(BX, 1.25, BZ), { Color = C.darkWood, Material = Enum.Material.Wood })
	end)
	local nameplate = B:part(Vector3.new(3.4, 0.8, 0.4), v(BX, 3.2, BZ - 1.6), { Color = Color3.fromRGB(40, 30, 20) })
	Build.surfaceText(nameplate, Enum.NormalId.Front, "부장 김부장", { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(230, 190, 90) })
	for _, dx in { -1.6, 1.6 } do
		B:part(Vector3.new(2.6, 1.8, 0.3), v(BX + dx / S, 3.9, BZ + 0.5), { Color = Color3.fromRGB(25, 25, 30) }) -- 모니터 2대
	end
	if Meshes.ready("RChair") then
		Meshes.place(B, "RChair", v(BX + 4.5, 0, BZ + 4.6), 150, { colors = { Seat = M.navy, Back = M.navy } })
	end

	-- 복합기 · 책장 · 화분
	local printer = prop("Printer", 14, -30, 180, Vector3.new(3, 3.4, 2.5))
	printer.Name = "Printer"
	prop("Bookshelf", 17.6, -12, -90, Vector3.new(5.2, 8.5, 1.6))
	prop("Bookshelf", 17.6, -17, -90, Vector3.new(5.2, 8.5, 1.6))
	for _, xz in { { -52, 7.4 }, { -38, 7.4 }, { 12, 7.4 }, { -53, -31 }, { 17, -31.5 } } do
		prop("Plant", xz[1], xz[2], 0, Vector3.new(1.8, 2, 1.8), { scale = 1.6 })
	end
	prop("TrashBin", 10.5, -29, 0, Vector3.new(1.4, 2, 1.4))

	---------------------------------------------------------------- 📊 유리 회의실 (동쪽 위)
	prop("DiningTable", 36, -26, 0, Vector3.new(17, 2.7, 3.6), { stretch = Vector3.new(17 / 6, 1, 1.06) })
	local meetingSeats = {}
	for _, x in { 31, 34.3, 37.7, 41 } do
		local seat = B:part(Vector3.new(2, 1, 2), v(x, 1, -26 + 3.2 / S), { ClassName = "Seat", Name = "MeetingSeat", Color = M.seat }) :: Seat
		if Meshes.ready("DiningChair") then
			seat.Transparency = 1
			Meshes.place(B, "DiningChair", v(x, 0, -26 + 3.2 / S), 0, { scale = 1.1 })
		end
		table.insert(meetingSeats, seat)
		prop("DiningChair", x, -26 - 3.2 / S, 180, Vector3.new(1.7, 3.6, 1.7), { scale = 1.1 })
	end
	local board = B:part(Vector3.new(0.3, 5.5, 10), v(HX - 0.2, 7.5, -26), { Color = Color3.fromRGB(240, 240, 238), CanCollide = false })
	Build.surfaceText(board, Enum.NormalId.Left, "4분기 전략 회의\n(조는 사람 없기!)", { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(40, 60, 140) })
	sign("회의실", Vector3.new(0.2, 1.2, 3.4), v(19.6, DOOR_H + 1.5, -26), Enum.NormalId.Left)
	local meetingZone = zone(B, "MeetingZone", Vector3.new(35 * S, 10, 15 * S), v(38, 5, -26))

	---------------------------------------------------------------- ☕ 카페 라운지 = 탕비실 (동쪽 가운데, 복도 쪽은 트여 있어요)
	-- 아일랜드 조리대 (라면 · 🎂 케이크 자리)
	local pantryCounter = B:part(Vector3.new(9, 3, 2.6), v(38, 1.5, -6), { Name = "PantryCounter", Color = M.surface })
	if Meshes.ready("Counter") then
		pantryCounter.Transparency = 1
		Meshes.place(B, "Counter", v(38, 0, -6), 0, { stretch = Vector3.new(9 / 8, 1, 1) })
	end
	for _, x in { 35.5, 38, 40.5 } do
		prop("DiningChair", x, -6 + 3.2 / S, 0, Vector3.new(1.7, 3.6, 1.7)) -- 바 의자
	end
	-- 벽 쪽 조리대 · 에스프레소 머신 · 냉장고 · 정수기
	prop("Counter", 54.7, -8, -90, Vector3.new(8, 3.1, 2.6))
	B:part(Vector3.new(1.4, 2, 1.4), v(54.7, 4, -10), { Color = M.metal, Material = Enum.Material.Metal }) -- 에스프레소 머신
	prop("Fridge", 54.5, -0.5, -90, Vector3.new(3, 7, 2.8))
	prop("WaterCooler", 54.9, 3.5, -90, Vector3.new(1.4, 5.5, 1.4))
	-- 소파 자리
	B:part(Vector3.new(0.12, 16, 16), nil, { CFrame = CFrame.new(v(29, 0.2, 3.5)) * CFrame.Angles(0, 0, math.rad(90)), Shape = Enum.PartType.Cylinder, Color = M.mintSoft, Material = Enum.Material.Carpet, CanCollide = false, CanQuery = false })
	prop("Sofa", 29, 7.6, 180, Vector3.new(6, 2.2, 2.6))
	prop("Sofa", 23.6, 3, 90, Vector3.new(5, 2.2, 2.6), { stretch = Vector3.new(5 / 6, 1, 1) })
	prop("RoundTable", 29, 3, 0, Vector3.new(2.6, 1.4, 2.6))
	prop("Plant", 22.2, 8.4, 0, Vector3.new(1.8, 2, 1.8), { scale = 1.5 })
	prop("Plant", 54, -16.2, 0, Vector3.new(1.8, 2, 1.8), { scale = 1.4 })
	-- 간식 테이블 (위에 과자 8개) + 올라가지 못하게 투명 덮개
	local SNACK_X, SNACK_Z = 46, 5
	prop("DiningTable", SNACK_X, SNACK_Z, 90, Vector3.new(7, 3, 5), { stretch = Vector3.new(7 / 6, 1.1, 5 / 3.4) })
	B:part(Vector3.new(5, 8, 7), v(SNACK_X, 7, SNACK_Z), { Name = "SnackTableGuard", Transparency = 1, CanQuery = false })
	local snackSign = B:part(Vector3.new(3, 0.9, 0.2), v(SNACK_X, 3.7, SNACK_Z + 3.6 / S), { Color = Color3.fromRGB(255, 240, 200) })
	Build.surfaceText(snackSign, Enum.NormalId.Back, "간식 (1인 1개)", { TextColor3 = Color3.fromRGB(80, 50, 30) })
	local snackSpots = {}
	for _, dz in { -2.4, -0.8, 0.8, 2.4 } do
		for _, dx in { -0.8, 0.8 } do
			table.insert(snackSpots, v(SNACK_X + dx / S, 3, SNACK_Z + dz / S))
		end
	end
	sign("CAFE LOUNGE", Vector3.new(0.2, 1.2, 5), v(19.6, DOOR_H + 1.5, -6), Enum.NormalId.Left)
	local pantryZone = zone(B, "PantryZone", Vector3.new(35 * S, 10, 27 * S), v(38, 5, -4))

	---------------------------------------------------------------- 복도: 엘리베이터 홀 · 안내 데스크 · 매점 키오스크
	local elevator = helpers.buildElevator(B, -HX * S, CORRIDOR_Z * S)
	if Meshes.ready("ElevatorDoor") then
		Meshes.place(B, "ElevatorDoor", v(-HX + 0.4, 0, CORRIDOR_Z) + Vector3.new(0, 0, 9), 90) -- 옆 호기 (장식)
	end
	prop("Reception", -40, 17, 0, Vector3.new(6.4, 2.8, 6.4))
	local logo = B:part(Vector3.new(12, 2, 0.2), v(-40, 13, 19.55), { Color = dark, CanCollide = false })
	Build.surfaceText(logo, Enum.NormalId.Front, "NUNCHI CORP.", { Font = Enum.Font.GothamBlack, TextColor3 = C.accent })
	local deliveryShelf = helpers.buildDeliveryShelf(B, -12 * S, 10 * S + 1.5)
	local packageBox = helpers.buildPackage(B, -18 * S, 10 * S + 2)
	local store = helpers.buildStore(B, 40 * S, 10 * S + 5.2, C.accent) -- 🏪 사내 매점 키오스크 (복도 동쪽, 남쪽을 보고 있어요)
	prop("Vending", 54.5, 17.4, -90, Vector3.new(3, 6.2, 2.4))
	prop("Plant", 52, 19, 0, Vector3.new(1.8, 2, 1.8), { scale = 1.4 })
	decor("NoticeBoard", 0, 19.5, 180, nil, 6)

	---------------------------------------------------------------- 🚻 화장실 (부장님이 안 들어오는 곳)
	local toiletSeats = {}
	for i, x in { -53, -48.5, -44 } do
		if i < 3 then
			B:part(Vector3.new(0.3, 7, 5), v(x + 2.25, 3.5, 31.6), { Color = Color3.fromRGB(70, 80, 95) }) -- 칸막이
		end
		Meshes.over(B, "Toilet", v(x, 0, 32.3), 180, nil, function()
			B:part(Vector3.new(2.2, 1, 2.6), v(x, 0.5, 32.2), { Color = C.white })
			B:part(Vector3.new(2.2, 2.4, 0.9), v(x, 1.8, 33.2), { Color = C.white })
		end)
		local seat = B:part(Vector3.new(2, 0.4, 2), v(x, 1.2, 32), { ClassName = "Seat", Name = "ToiletSeat", Color = C.white }) :: Seat
		if Meshes.ready("Toilet") then
			seat.Transparency = 1
		end
		table.insert(toiletSeats, seat)
	end
	prop("Washbasin", -37.6, 25.5, -90, Vector3.new(4, 3, 2))
	prop("Washbasin", -37.6, 25.5 + 4.4 / S, -90, Vector3.new(4, 3, 2))
	sign("화장실", Vector3.new(3, 1.2, 0.2), v(-46, DOOR_H + 1.5, 19.45), Enum.NormalId.Front)
	local toiletZone = zone(B, "ToiletZone", Vector3.new(19 * S, 10, 13 * S), v(-46, 5, 27))

	---------------------------------------------------------------- 🛋️ 휴게 라운지 · 폰부스 · 창고
	B:part(Vector3.new(0.12, 14, 14), nil, { CFrame = CFrame.new(v(-26, 0.2, 26)) * CFrame.Angles(0, 0, math.rad(90)), Shape = Enum.PartType.Cylinder, Color = M.coralSoft, Material = Enum.Material.Carpet, CanCollide = false, CanQuery = false })
	for i, info in { { -32, 30.5, 150 }, { -26, 31.5, 180 }, { -11, 26, -90 } } do
		prop("PodChair", info[1], info[2], info[3], Vector3.new(4, 4.2, 4), { scale = 1.05 })
		local _ = i
	end
	prop("Plant", -34, 22, 0, Vector3.new(1.8, 2, 1.8), { scale = 1.4 })
	sign("LOUNGE", Vector3.new(3.4, 1.2, 0.2), v(-22, DOOR_H + 1.5, 19.45), Enum.NormalId.Front)
	sign("FITNESS ▼", Vector3.new(4, 1.2, 0.2), v(-16, DOOR_H + 1.5, HZ - 0.2), Enum.NormalId.Front)
	for i = 0, 2 do
		local x = -3 + i * 8
		B:part(Vector3.new(5.2, 9, 5.2), v(x, 4.5, 30), { Color = M.mint, Material = Enum.Material.Fabric }) -- 폰부스
		B:part(Vector3.new(3.6, 7, 0.2), v(x, 4.2, 30 - 2.7 / S), { Color = Color3.fromRGB(200, 222, 232), Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false })
	end
	sign("PHONE BOOTH", Vector3.new(5, 1.2, 0.2), v(6, DOOR_H + 1.5, 19.45), Enum.NormalId.Front)
	prop("StoreShelf", 50, 33, 180, Vector3.new(6, 6, 1.6))
	prop("Locker", 26, 33, 180, Vector3.new(1.6, 6, 1.6))
	prop("Locker", 26 + 1.7 / S, 33, 180, Vector3.new(1.6, 6, 1.6))
	prop("CardboardBox", 42, 30, 12, Vector3.new(2.4, 2, 2.4))
	prop("CardboardBox", 38, 31.5, 0, Vector3.new(2.4, 2, 2.4))
	sign("창고", Vector3.new(3, 1.2, 0.2), v(38, DOOR_H + 1.5, 19.45), Enum.NormalId.Front)

	---------------------------------------------------------------- 🏋️ 체력 단련실 (남쪽 별관, 예전과 같은 자리)
	local G = { cx = LAYOUT.gym.cx, hx = LAYOUT.gym.hx, hz = LAYOUT.gym.hz, cz = 0 }
	local gymNear = HZ * S + 1
	G.cz = gymNear + G.hz
	local gymFar = G.cz + G.hz
	B:part(Vector3.new(G.hx * 2 + 2, 1, gymFar + 1 - gymNear), Vector3.new(G.cx, FLOOR_Y - 0.5, (gymNear + gymFar + 1) / 2), { Color = C.rug, Material = Enum.Material.Carpet })
	B:part(Vector3.new(G.hx * 2 + 2, 1, gymFar + 1 - gymNear), rv(G.cx, H + 0.5, (gymNear + gymFar + 1) / 2), { Color = C.wall })
	B:wall("Z", G.cx - G.hx - 0.5, gymNear, gymFar + 1, FLOOR_Y, H, nil, wallProps)
	B:wall("Z", G.cx + G.hx + 0.5, gymNear, gymFar + 1, FLOOR_Y, H, nil, wallProps)
	B:wall("X", gymFar + 0.5, G.cx - G.hx - 1, G.cx + G.hx + 1, FLOOR_Y, H, nil, wallProps)
	local gym = helpers.buildGym(B, { cx = G.cx, cz = G.cz, hx = G.hx, hz = G.hz, wallHeight = H, accent = C.accent })

	---------------------------------------------------------------- 조명 (긴 줄 조명)
	local lamps = {}
	local function lamp(x: number, z: number, alongX: boolean, length: number)
		local part = B:part(if alongX then Vector3.new(length, 0.3, 0.9) else Vector3.new(0.9, 0.3, length), v(x, H - 0.2, z), {
			Color = Color3.fromRGB(232, 230, 222),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		local light = Instance.new("PointLight")
		light.Range = 32
		light.Brightness = 0.3
		light.Color = Color3.fromRGB(255, 250, 240)
		light.Parent = part
		table.insert(lamps, part)
	end
	for x = -50, 14, 8 do
		for _, z in { -26, -12, 2 } do
			lamp(x, z, false, 12)
		end
	end
	for _, xz in { { 30, -26 }, { 46, -26 }, { 28, -6 }, { 38, -6 }, { 48, -6 }, { 30, 4 }, { 46, 4 }, { -46, 27 }, { -22, 27 }, { 6, 27 }, { 38, 27 } } do
		lamp(xz[1], xz[2], false, 9)
	end
	for x = -44, 44, 22 do
		lamp(x, CORRIDOR_Z, true, 12)
	end
	for _, part in gym.lamps do
		table.insert(lamps, part)
	end

	-- 🔊 배경 소리 자리 (ID는 SalaryConfig.Sounds)
	Ambience.loop("office", folder, v(-18, 9, -12), 85)
	Ambience.loop("corridor", folder, v(0, 9, CORRIDOR_Z), 70)
	Ambience.loop("pantry", folder, v(38, 7, -4), 34)

	-- 시작 지점: 공원 쪽 출입문 안 (예전과 같은 자리)
	B:part(Vector3.new(4, 1, 4), rv(0, -0.4, -HZ * S + 5), {
		ClassName = "SpawnLocation",
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Neutral = true,
		Duration = 0,
	})

	return {
		desks = desks,
		setClock = setClock,
		bossStand = v(BX, 0, BZ + 3.6),
		-- 🏢 사무실 방이 예전 큰 홀보다 좁아진 만큼 부장님 시야 거리와 걸음을 조금 줄여요
		bossScale = { range = 0.85, walkSpeed = 0.92 },
		entrance = rv(0, 0, -HZ * S + 2),
		-- 건물 안 순찰 지점 (공원·거리 지점은 OfficeNunchi가 덧붙여요). 화장실은 들어가지 않아요.
		waypoints = {
			v(BX, 0, 0.5), -- 부장 자리 앞
			v(-44, 0, -1),
			v(-3.5, 0, -1),
			v(-37, 0, -22), -- 책상 줄 사이
			v(-24, 0, -22),
			v(-10, 0, -22),
			v(-37, 0, -12),
			v(-10, 0, -12),
			v(-40, 0, -31.5), -- 창가 통로
			v(-24, 0, -31.5),
			v(-6, 0, -31.5),
			v(10, 0, -24), -- 동쪽 통로 (복합기 쪽)
			v(10, 0, -10),
			v(12, 0, 4),
			v(17, 0, -26), -- 회의실 문 앞
			v(24, 0, -6), -- 카페 라운지 안 (유리문 바로 안쪽)
			v(40, 0, 2),
			v(6, 0, 7.5), -- 복도 문 안쪽
			v(6, 0, CORRIDOR_Z), -- 복도
			v(-30, 0, CORRIDOR_Z),
			v(28, 0, CORRIDOR_Z),
			v(40, 0, 17.5), -- 매점 키오스크 앞
			v(-22, 0, 22.5), -- 휴게 라운지 문 (안을 들여다봐요)
			rv(G.cx, 0, gymNear + 8), -- 🏋️ 체력 단련실 (가끔 들여다봐요)
		},
		toiletZone = toiletZone,
		pantryZone = pantryZone,
		printer = printer,
		pantryCounter = pantryCounter,
		snackSpots = snackSpots,
		spots = { v(30, 0, 0.5), v(41, 0, -2.5), v(11, 0, -28), v(-12, 0, -31.5), v(-22, 0, 26), v(36, 0, 17.5) },
		toiletSeats = toiletSeats,
		meetingSeats = meetingSeats,
		meetingZone = meetingZone,
		gym = gym,
		gymRect = G,
		lamps = lamps,
		cakeSpots = { v(36, 3, -6), v(38, 3, -6), v(40, 3, -6) }, -- 아일랜드 조리대 위
		store = store,
		packageBox = packageBox,
		deliveryShelf = deliveryShelf,
		elevator = elevator,
		packageSpots = { v(-8, 0, -31.5), v(12, 0, -4), v(34, 0, 4), v(-30, 0, CORRIDOR_Z), v(-24, 0, 8), v(-22, 0, 23), v(18, 0, CORRIDOR_Z), v(44, 0, -12) },
		ceiling = H,
	}
end

return Floor
