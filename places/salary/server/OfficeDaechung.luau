-- 🏢 (주)대충상사 사무실 — 리뉴얼 평면 (낡은 상가 건물 3층의 중소기업)
-- 큰 홀 하나였던 예전 맵(128×63)을, 복도와 방으로 나뉜 한 층(설계 96×60, 실제는 1.25배인 120×75)으로 다시 지어요.
-- 아래 그림과 좌표는 "설계 좌표"예요.
--
--   x -48                                  22                 48
--   ┌──────────── 창문 · 사훈 ──────────────┬──────────────────┐ z -30
--   │ [7] [1] [2] [3]      🖨️ 복합기         │ 회의실           │
--   │  🪑  🪑  🪑  🪑                        ├──────────────────┤ z -16
--   │ [8] [4] [5] [6]                       🚪 비품실 (매점은 1층) │
--   │  🪑  🪑  🪑  🪑       🕐               ├──────────────────┤ z -4
--   │        [김부장]        락커            │ ☕ 탕비실         │
--   ├──────────────────────[유리문 x 15]─────┴───[입구 x 31]────┤ z 12
--   │🚪엘리베이터          복 도 (📦 택배 보관함)        자판기 │
--   ├───[x -38]───┬───[x -18]──┬────[x 10]────────┬──[x 34]────┤ z 24
--   │ 🚻 화장실    │ 문서고      │ 🛋️ 휴게실         │ 계단실      │
--   └─────────────┴────────────┴──────────────────┴──[x 38]────┘ z 34
--                                               │ 🏋️ 체력 단련실 (별관) │ x 9~67 / z 31~75
--
-- 직원은 창을 보고 앉고(−Z), 부장님은 등 뒤에서 봐요. 예전과 같은 규칙이에요.
-- 책상 [1]~[6]이 게임에 쓰이는 자리이고 [7][8]은 빈자리(배경)예요.
-- 돌려주는 값(Office)은 예전과 같은 모양이라 부장·동료·이벤트 코드는 그대로 동작해요.
-- 좌표는 아래 LAYOUT 표에 모았어요. 맵을 고칠 땐 여기만 바꾸면 돼요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Build = require(ReplicatedStorage.Shared.Build)
local Theme = require(ReplicatedStorage.Shared.SalaryTheme)
local Meshes = require(script.Parent.Meshes)
local Npc = require(script.Parent.Npc)
local Ambience = require(script.Parent.Ambience)
local Campus = require(script.Parent.Campus)

local OfficeDaechung = {}

-- 🚏 건물 앞 거리·1층의 기준점 (거리 바닥 윗면, 건물 남쪽 벽이 z 0). Arrival 모듈이 이 자리에 거리와 로비를 지어요.

local M = Theme.Mesh
local H = 20 -- 천장 높이 (카메라가 답답하지 않게 높여요)
local S = 1.25 -- 📐 평면 전체 배율: 아래 좌표는 모두 "설계 좌표"이고, 지을 때 이 배율을 곱해요 (가구 크기는 그대로 → 통로가 넓어져요)
local HX, HZ = 48, 30 -- 층 절반 크기 (설계 좌표). HZ는 북쪽(창가) 벽
local HZS = 34 -- 남쪽 벽 (복도를 넓히면서 남쪽 방들을 4만큼 밀었어요)
local DOOR_H = 10.5 -- 문 높이 (예전 8)
local CORRIDOR_Z = 18 -- 복도 가운데 (복도는 z 12~24, 실제 폭 15칸. 예전엔 12~20, 10칸)

local LAYOUT = {
	-- 벽: { 축, 고정 좌표, 시작, 끝, 문 { 중심, 폭 }... }  ("X" = 동서로 뻗은 벽, "Z" = 남북으로 뻗은 벽)
	walls = {
		{ "X", -HZ - 0.5, -HX - 1, HX + 1 }, -- 북 (창가)
		{ "X", HZS + 0.5, -HX - 1, HX + 1, { 38, 8 } }, -- 남 (🏋️ 체력 단련실 문)
		{ "Z", -HX - 0.5, -HZ, HZS }, -- 서
		{ "Z", HX + 0.5, -HZ, HZS }, -- 동
		{ "Z", 22, -HZ, 12, { -23, 6 }, { -10, 6 } }, -- 사무실 ↔ 회의실 · 매점
		{ "X", 12, -HX, 22, { 15, 8.5 } }, -- 사무실 유리문 (부장님 자리에서 떨어진 동쪽)
		{ "X", 12, 22, HX, { 31, 8.5 } }, -- 탕비실 입구
		{ "X", 24, -HX, HX, { -38, 6 }, { -18, 6 }, { 10, 7 }, { 34, 6.5 } }, -- 화장실 · 문서고 · 휴게실 · 계단실
		{ "X", -16, 22.5, HX },
		{ "X", -4, 22.5, HX },
		{ "Z", -28, 24.5, HZS },
		{ "Z", -8, 24.5, HZS },
		{ "Z", 28, 24.5, HZS },
	},
	deskRows = { -21, -9 }, -- 책상 줄 (z)
	deskColumns = { -26.5, -13, 0.5 }, -- 게임에 쓰는 자리 (x)
	spareColumn = -40, -- 빈자리 (x)
	boss = { x = -13, z = 4 },
	elevator = { z = 18 }, -- 서쪽 벽 (복도 가운데)
	gym = { cx = 38, hx = 29, hz = 22 }, -- cx는 설계 좌표, 크기는 실제 칸
	store = { x = 38, z = -11.5 },
	lamps = {
		{ -42, -24 }, { -30, -24 }, { -18, -24 }, { -6, -24 }, { 6, -24 }, { 16, -24 },
		{ -42, -12 }, { -30, -12 }, { -18, -12 }, { -6, -12 }, { 6, -12 }, { 16, -12 },
		{ -42, 0 }, { -30, 0 }, { -18, 0 }, { -6, 0 }, { 6, 0 }, { 16, 0 },
		{ 35, -23 }, { 35, -10 }, { 35, 4 }, -- 회의실 · 매점 · 탕비실
		{ -38, 25 }, { -18, 25 }, { 10, 25 }, { 38, 25 }, -- 남쪽 방들
	},
	corridorLamps = { -40, -24, -8, 8, 24, 40 }, -- 복도 (z CORRIDOR_Z)
}

function OfficeDaechung.build(B, folder: Folder, company, helpers)
	local zone = helpers.zone
	local rv = helpers.v -- 실제 좌표
	local function v(x: number, y: number, z: number): Vector3 -- 설계 좌표 → 실제 좌표
		return rv(x * S, y, z * S)
	end
	local COLORS = helpers.colors
	local FLOOR_Y = helpers.FLOOR_Y
	local wall = { Color = COLORS.wall, Material = Enum.Material.Plaster }
	local hidden = { Transparency = 1 }

	-- 가구 하나 놓기: 메시가 있으면 메시 + 보이지 않는 충돌 상자, 없으면 회색 상자.
	-- size는 가구 기준(가로, 높이, 깊이)이고 앞은 +Z예요.
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
		local part = B:part(size, position, { Color = M.navy, CanCollide = false })
		Build.surfaceText(part, face, text, { Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1) })
	end

	---------------------------------------------------------------- 바닥 · 천장 · 벽
	B:part(Vector3.new(HX * 2 * S + 3, 1, (HZ + HZS) * S + 3), Vector3.new(0, FLOOR_Y - 0.5, (HZS - HZ) / 2 * S), { Color = COLORS.floor, Material = Enum.Material.Carpet })
	B:part(Vector3.new(HX * 2 * S + 3, 1, (HZ + HZS) * S + 3), v(0, H + 0.5, (HZS - HZ) / 2), { Color = COLORS.wall })
	local vinyl = { Color = Color3.fromRGB(206, 196, 174), Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false }
	B:part(Vector3.new(HX * 2 * S, 0.12, 12 * S), v(0, 0.1, CORRIDOR_Z), vinyl) -- 복도
	B:part(Vector3.new(26 * S, 0.12, 16 * S), v(35, 0.1, 4), vinyl) -- 탕비실
	B:part(Vector3.new(76 * S, 0.12, 10 * S), v(10, 0.1, 29), vinyl) -- 문서고 · 휴게실 · 계단실
	B:part(Vector3.new(20 * S, 0.12, 10 * S), v(-38, 0.1, 29), { Color = COLORS.tile or M.surfaceSoft, Material = Enum.Material.Marble, CanCollide = false, CanQuery = false }) -- 화장실
	for _, info in LAYOUT.walls do
		local doors = {}
		for i = 5, #info do
			table.insert(doors, { center = info[i][1] * S, width = info[i][2], height = DOOR_H })
		end
		B:wall(info[1], info[2] * S, info[3] * S, info[4] * S, FLOOR_Y, H, doors, wall)
	end
	-- 창문 (북쪽 벽) + 블라인드
	for x = -42, 42, 12 do
		B:part(Vector3.new(10 * S, 9.4, 0.2), v(x, 8.2, -HZ + 0.1), { Color = Color3.fromRGB(190, 214, 232), Material = Enum.Material.Glass, Transparency = 0.2 })
		B:part(Vector3.new(10 * S + 0.4, 0.25, 0.7), v(x, 3.4, -HZ + 0.35), { Color = M.woodLight, Material = Enum.Material.Wood, CanCollide = false })
		for k = 0, 5 do
			B:part(Vector3.new(10 * S, 0.06, 0.3), v(x, 12.7 - k * 0.34, -HZ + 0.35), { Color = M.cream, CanCollide = false, CanQuery = false })
		end
	end
	-- 사훈 현수막 (창 위) · 벽시계 (동쪽 벽)
	local banner = B:part(Vector3.new(18, 1.6, 0.2), v(-13, 15.2, -HZ + 0.15), { Color = Color3.fromRGB(150, 36, 42), CanCollide = false })
	Build.surfaceText(banner, Enum.NormalId.Back, company.motto, { Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 230, 120) })
	local clockFace = B:part(Vector3.new(0.2, 3, 3), v(21.35, 10, 2), { Color = COLORS.wall, CanCollide = false })
	local setClock = Build.clockFace(clockFace, Enum.NormalId.Left)

	---------------------------------------------------------------- 사무실: 책상
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
		index += 1
		table.insert(spareDesks, helpers.buildDesk(B, index, LAYOUT.spareColumn * S, z * S)) -- 게임 판정에는 안 쓰는 자리
	end
	-- 🧑‍💼 플레이어 자리가 아닌 책상에 앉는 직원들
	local EXTRAS = {
		{ name = "오차장", skin = Color3.fromRGB(226, 194, 164), shirt = Color3.fromRGB(214, 222, 232), pants = Color3.fromRGB(52, 56, 66) },
		{ name = "유사원", skin = Color3.fromRGB(238, 208, 182), shirt = Color3.fromRGB(196, 178, 160), pants = Color3.fromRGB(70, 66, 62) },
	}
	-- (Coworkers가 이 자리에 동료를 만들어요: 다른 동료처럼 말 걸기·친밀도·인사평가가 돼요)
	local extraDesks = {}
	for i, desk in spareDesks do
		local extra = EXTRAS[i]
		if extra then
			table.insert(extraDesks, { desk = desk, name = extra.name, look = { skin = extra.skin, shirt = extra.shirt, pants = extra.pants } })
		end
	end

	-- 김부장 자리 (뒷줄 의자 뒤)
	local BX, BZ = LAYOUT.boss.x, LAYOUT.boss.z
	Meshes.over(B, "BossDesk", v(BX, 0, BZ), 0, { skip = { Plate = true } }, function()
		B:part(Vector3.new(10, 0.6, 4), v(BX, 2.4, BZ), { Color = M.wood, Material = Enum.Material.Wood })
		for _, dx in { -4.2, 4.2 } do
			B:part(Vector3.new(0.5, 2.2, 3.2), v(BX + dx, 1.1, BZ), { Color = M.navy, Material = Enum.Material.Metal })
		end
	end)
	local nameplate = B:part(Vector3.new(3, 0.8, 0.4), v(BX, 3.2, BZ - 1.6), { Color = Color3.fromRGB(40, 30, 20) })
	Build.surfaceText(nameplate, Enum.NormalId.Front, "부장 김부장", { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(230, 190, 90) })
	B:part(Vector3.new(2.6, 1.8, 0.3), v(BX + 2.6, 3.9, BZ + 0.6), { Color = COLORS.monitor })
	if Meshes.ready("Chair") then
		-- 부장님 의자: 책상 바로 뒤, 책상을 보고 (수면제 커피를 마시면 여기 앉아 자요)
		Meshes.place(B, if Meshes.ready("RChair") then "RChair" else "Chair", v(BX, 0, BZ + 2.3), 180, { colors = { Seat = M.navy, Back = M.navy } })
	end

	-- 복합기 · 락커 · 정수기 · 화분 · 게시판
	local printer = prop("Printer", 16, -3, -90, Vector3.new(3, 3.4, 2.5))
	printer.Name = "Printer"
	for i = 0, 6 do
		prop("Locker", -45 + i * 1.7 / S, 10.9, 180, Vector3.new(1.6, 6, 1.6))
	end
	prop("WaterCooler", 8, 10.9, 180, Vector3.new(1.4, 5.5, 1.4))
	prop("TrashBin", 12.5, -1, 0, Vector3.new(1.4, 2, 1.4))
	prop("CardboardBox", 18.5, -7.5, 15, Vector3.new(2.4, 2, 2.4))
	for _, xz in { { 20, 10 }, { 19.5, -27.5 }, { -46, -27.3 } } do
		prop("Plant", xz[1], xz[2], 0, Vector3.new(1.8, 2, 1.8), { scale = 1.4 })
	end
	decor("NoticeBoard", -24, 11.5, 180, nil, 5.6)

	---------------------------------------------------------------- 회의실 (동쪽 위)
	prop("DiningTable", 35, -23, 0, Vector3.new(11, 2.7, 3.4), { stretch = Vector3.new(11 / 6, 1, 1) })
	for _, x in { 31, 35, 39 } do
		prop("DiningChair", x, -23 - 3 / S, 180, Vector3.new(1.7, 3.6, 1.7))
		prop("DiningChair", x, -23 + 3 / S, 0, Vector3.new(1.7, 3.6, 1.7))
	end
	decor("NoticeBoard", 47.4, -23, -90, nil, 5.6)
	sign("회의실", Vector3.new(0.2, 1.2, 3), v(21.35, DOOR_H + 1.4, -23), Enum.NormalId.Left)

	---------------------------------------------------------------- 비품실 (동쪽 가운데, 예전 매점 자리)
	prop("StoreShelf", 46.6, -10, -90, Vector3.new(6, 6, 1.6))
	prop("Locker", 24.2, -14.9, 0, Vector3.new(1.6, 6, 1.6))
	prop("Locker", 24.2 + 1.7 / S, -14.9, 0, Vector3.new(1.6, 6, 1.6))
	prop("CardboardBox", 30, -7, 0, Vector3.new(2.4, 2, 2.4))
	prop("CardboardBox", 33, -6.6, 15, Vector3.new(2.4, 2, 2.4))
	prop("CardboardBox", 31.4, -6.8, 8, Vector3.new(2.4, 2, 2.4), nil, 2)
	sign("비품실", Vector3.new(0.2, 1.2, 3), v(21.35, DOOR_H + 1.4, -10), Enum.NormalId.Left)

	---------------------------------------------------------------- 🏪 매점 = 1층 편의점 (건물 앞 거리, Arrival이 가게 벽과 문을 지어요)
	-- 가게 안: 거리 기준 x -23.5~-0.5 / z -19~0. 문은 남쪽(길 쪽)이고 계산대가 문을 봐요.
	-- 가게는 회사 단지(Campus)의 상가 건물 1층에 있어요. 단지를 지으면서 공원·가게 거리의 시설도 함께 받아 와요.
	local campus = Campus.build(folder, helpers, company.id)
	local shops = table.clone(campus.shops) -- ☕ 골목 커피 · 🍢 분식 · 눈치 스트리트의 ☕ 커피 · 🍰 디저트
	shops.store = campus.mallStore -- 🏪 1층 편의점

	---------------------------------------------------------------- ☕ 탕비실 (동쪽 아래)
	local pantryCounter = B:part(Vector3.new(2.5, 3, 10), v(46.75, 1.5, 3), { Name = "PantryCounter", Color = M.surface }) -- 조리대 (라면) z -2~8
	if Meshes.ready("Counter") then
		pantryCounter.Transparency = 1
		Meshes.place(B, "Counter", v(46.75, 0, 3), -90, { stretch = Vector3.new(10 / 8, 1, 1) })
	end
	B:part(Vector3.new(1.4, 2, 1.4), v(46.75, 4, -0.8), { Color = M.navy }) -- 커피머신
	B:part(Vector3.new(1.6, 0.4, 1.6), v(46.75, 3.3, 6.6), { Color = M.navySoft }) -- 전기레인지
	prop("Fridge", 46.4, 10.2, -90, Vector3.new(3, 7, 2.8))
	prop("WaterCooler", 23.4, 9.5, 90, Vector3.new(1.4, 5.5, 1.4))
	prop("DiningTable", 38.5, 8, 0, Vector3.new(5.1, 2.4, 2.9), { scale = 0.85 })
	for _, x in { 37.3, 39.7 } do
		prop("DiningChair", x, 8 - 2.8 / S, 180, Vector3.new(1.7, 3.6, 1.7))
	end
	prop("TrashBin", 23.6, -2.6, 0, Vector3.new(1.4, 2, 1.4))
	-- 간식 테이블 (위에 과자 8개) + 올라가지 못하게 투명 덮개
	local SNACK_X, SNACK_Z = 30, 2.5
	prop("DiningTable", SNACK_X, SNACK_Z, 90, Vector3.new(7, 3, 5), { stretch = Vector3.new(7 / 6, 1.1, 5 / 3.4) })
	B:part(Vector3.new(5, 8, 7), v(SNACK_X, 7, SNACK_Z), { Name = "SnackTableGuard", Transparency = 1, CanQuery = false })
	local snackSign = B:part(Vector3.new(3, 0.9, 0.2), v(SNACK_X, 3.7, SNACK_Z + 3.6), { Color = Color3.fromRGB(255, 240, 200) })
	Build.surfaceText(snackSign, Enum.NormalId.Back, "간식 (1인 1개)", { TextColor3 = Color3.fromRGB(80, 50, 30) })
	local snackSpots = {}
	for _, dz in { -2.4, -0.8, 0.8, 2.4 } do
		for _, dx in { -0.8, 0.8 } do
			table.insert(snackSpots, v(SNACK_X + dx, 3, SNACK_Z + dz))
		end
	end
	sign("탕비실", Vector3.new(3, 1.2, 0.2), v(31, DOOR_H + 1.4, 12.65), Enum.NormalId.Back)
	local pantryZone = zone(B, "PantryZone", Vector3.new(25 * S, 10, 15 * S), v(35, 5, 4))

	---------------------------------------------------------------- 복도
	local elevator = helpers.buildElevator(B, -HX * S, LAYOUT.elevator.z * S)
	local deliveryShelf = helpers.buildDeliveryShelf(B, 2 * S, 12 * S + 1.4)
	local packageBox = helpers.buildPackage(B, -3 * S, 12 * S + 1.9)
	prop("Vending", 46.5, CORRIDOR_Z, -90, Vector3.new(3, 6.2, 2.4))
	prop("TrashBin", 43.5, 13.4, 0, Vector3.new(1.4, 2, 1.4))
	prop("Plant", -46, 23, 0, Vector3.new(1.8, 2, 1.8), { scale = 1.3 })
	decor("NoticeBoard", -24, 23.4, 180, nil, 5.6)

	---------------------------------------------------------------- 🚻 화장실 (부장님이 안 들어오는 곳)
	local toiletSeats = {}
	for i, x in { -45, -40.5, -36 } do
		if i < 3 then
			B:part(Vector3.new(0.3, 7, 5), v(x + 2.25, 3.5, 31.3), { Color = Color3.fromRGB(150, 160, 166) }) -- 칸막이
		end
		Meshes.over(B, "Toilet", v(x, 0, 32.2), 180, nil, function()
			B:part(Vector3.new(2.2, 1, 2.6), v(x, 0.5, 32.1), { Color = M.surface })
			B:part(Vector3.new(2.2, 2.4, 0.9), v(x, 1.8, 33.2), { Color = M.surface })
		end)
		local seat = B:part(Vector3.new(2, 0.4, 2), v(x, 1.2, 31.9), { ClassName = "Seat", Name = "ToiletSeat", Color = M.surface }) :: Seat
		if Meshes.ready("Toilet") then
			seat.Transparency = 1
		end
		table.insert(toiletSeats, seat)
	end
	prop("Washbasin", -29.6, 29.5, -90, Vector3.new(4, 3, 2))
	sign("화장실", Vector3.new(3, 1.2, 0.2), v(-38, DOOR_H + 1.4, 23.35), Enum.NormalId.Front)
	local toiletZone = zone(B, "ToiletZone", Vector3.new(19 * S, 10, 9 * S), v(-38, 5, 29))

	---------------------------------------------------------------- 문서고 · 🛋️ 휴게실 · 계단실
	prop("StoreShelf", -18, 33, 180, Vector3.new(6, 6, 1.6))
	prop("CardboardBox", -11, 31.5, 0, Vector3.new(2.4, 2, 2.4))
	prop("CardboardBox", -25.5, 31.8, 20, Vector3.new(2.4, 2, 2.4))
	sign("문서고", Vector3.new(3, 1.2, 0.2), v(-18, DOOR_H + 1.4, 23.35), Enum.NormalId.Front)
	prop("Sofa", 3, 32.3, 180, Vector3.new(6, 2.2, 2.6))
	prop("Sofa", 25.6, 29, -90, Vector3.new(5, 2.2, 2.6), { stretch = Vector3.new(5 / 6, 1, 1) })
	prop("RoundTable", 4, 28.4, 0, Vector3.new(2.6, 1.4, 2.6))
	prop("Plant", -6, 32.4, 0, Vector3.new(1.8, 2, 1.8), { scale = 1.3 })
	sign("휴게실", Vector3.new(3, 1.2, 0.2), v(10, DOOR_H + 1.4, 23.35), Enum.NormalId.Front)
	sign("체력 단련실 ↓", Vector3.new(4, 1.2, 0.2), v(34, DOOR_H + 1.4, 23.35), Enum.NormalId.Front)

	---------------------------------------------------------------- 🏋️ 체력 단련실 (남쪽 별관, 계단실 문으로 들어가요)
	local G = { cx = LAYOUT.gym.cx * S, hx = LAYOUT.gym.hx, hz = LAYOUT.gym.hz, cz = 0 }
	local gymNear = HZS * S + 1
	G.cz = gymNear + G.hz
	local gymFar = G.cz + G.hz
	B:part(Vector3.new(G.hx * 2 + 2, 1, gymFar + 1 - gymNear), Vector3.new(G.cx, FLOOR_Y - 0.5, (gymNear + gymFar + 1) / 2), { Color = COLORS.floor, Material = Enum.Material.Carpet })
	B:part(Vector3.new(G.hx * 2 + 2, 1, gymFar + 1 - gymNear), rv(G.cx, H + 0.5, (gymNear + gymFar + 1) / 2), { Color = COLORS.wall })
	B:wall("Z", G.cx - G.hx - 0.5, gymNear, gymFar + 1, FLOOR_Y, H, nil, wall)
	B:wall("Z", G.cx + G.hx + 0.5, gymNear, gymFar + 1, FLOOR_Y, H, nil, wall)
	B:wall("X", gymFar + 0.5, G.cx - G.hx - 1, G.cx + G.hx + 1, FLOOR_Y, H, nil, wall)
	B:wall("X", HZS * S + 0.5, HX * S + 1, G.cx + G.hx + 1, FLOOR_Y, H, nil, wall) -- 건물 밖으로 나온 부분의 앞벽
	local gym = helpers.buildGym(B, { cx = G.cx, cz = G.cz, hx = G.hx, hz = G.hz, wallHeight = H, accent = COLORS.accent })

	---------------------------------------------------------------- 형광등
	local lamps = {}
	local function lamp(x: number, z: number, alongX: boolean)
		local part = B:part(if alongX then Vector3.new(5.4, 0.3, 1.4) else Vector3.new(1.4, 0.3, 5.4), v(x, H - 0.2, z), {
			Color = Color3.fromRGB(226, 224, 214),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		local light = Instance.new("PointLight")
		light.Range = 30 -- 천장이 높아진 만큼 멀리 비춰요
		light.Brightness = 0.32 -- (조명이 서로 겹쳐 너무 밝아서 낮췄어요)
		light.Color = Color3.fromRGB(255, 248, 232)
		light.Parent = part
		table.insert(lamps, part)
	end
	for _, xz in LAYOUT.lamps do
		lamp(xz[1], xz[2], false)
	end
	for _, x in LAYOUT.corridorLamps do
		lamp(x, CORRIDOR_Z, true)
	end
	for _, part in gym.lamps do
		table.insert(lamps, part)
	end

	-- 🔊 배경 소리 자리 (ID는 SalaryConfig.Sounds)
	Ambience.loop("office", folder, v(-13, 8, -10), 70)
	Ambience.loop("corridor", folder, v(0, 8, CORRIDOR_Z), 60)
	Ambience.loop("pantry", folder, v(35, 6, 4), 26)

	-- 🚒 소방 훈련 집결지 = 🌸 워크숍 결승선 (창가 통로)
	local assemblyZone, assemblyPoint, setAssemblyVisible = helpers.makeAssembly(B, BX * S, -26.5 * S)

	-- 시작 지점: 엘리베이터에서 내려 복도를 보고 서요
	B:part(Vector3.new(4, 1, 4), nil, {
		ClassName = "SpawnLocation",
		CFrame = CFrame.new(v(-43, -0.4, LAYOUT.elevator.z)) * CFrame.Angles(0, math.rad(-90), 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Neutral = true,
		Duration = 0,
	})

	-- 부장 순찰 지점 (길찾기로 문을 지나 다녀요). 화장실은 들어가지 않아요.
	local waypoints = {
		v(BX, 0, -1), -- 부장 자리 앞 (뒷줄 의자 뒤)
		v(-26.5, 0, -2),
		v(0.5, 0, -2),
		v(-40, 0, -2),
		v(-20, 0, -14.5), -- 책상 줄 사이
		v(-6.5, 0, -14.5),
		v(-33, 0, -14.5),
		v(-20, 0, -27), -- 창가
		v(-6.5, 0, -27),
		v(8, 0, -26),
		v(10, 0, -20), -- 동쪽 통로 (복합기 쪽)
		v(10, 0, -8),
		v(14, 0, 4),
		v(18.5, 0, -10), -- 매점 문 앞
		v(18.5, 0, -23), -- 회의실 문 앞
		v(15, 0, 9), -- 유리문 안쪽
		v(15, 0, CORRIDOR_Z), -- 복도
		v(-9, 0, CORRIDOR_Z),
		v(-30, 0, CORRIDOR_Z),
		v(20, 0, CORRIDOR_Z),
		v(31, 0, 14.5), -- 탕비실 입구 (안을 들여다봐요)
		v(10, 0, 26.5), -- 휴게실 문 (안을 들여다봐요)
		rv(38 * S, 0, HZS * S + 8), -- 🏋️ 체력 단련실 (가끔 들여다봐요)
	}

	return {
		folder = folder,
		desks = desks,
		extraDesks = extraDesks,
		bossStand = v(BX, 0, BZ + 3.6),
		bossChair = v(BX, 0, BZ + 2.3), -- 부장님 의자 자리
		bossLook = Vector3.new(0, 0, -1),
		-- 🏢 사무실이 좁아진 만큼 부장님의 시야 거리와 걸음을 줄여, 다가오는 데 걸리는 시간을 예전과 비슷하게 맞춰요
		bossScale = { range = 0.8, walkSpeed = 0.9 }, -- (평면을 1.25배로 넓히면서 0.7 / 0.85 에서 조금 풀었어요)
		entrance = v(-44, 0, LAYOUT.elevator.z),
		stairSpot = v(45.5, 0, 30), -- 계단실 동쪽 벽의 계단 문 앞 (Arrival이 1층 로비로 가는 계단을 붙여요)
		waypoints = waypoints,
		toiletZone = toiletZone,
		pantryZone = pantryZone,
		printer = printer,
		pantryCounter = pantryCounter,
		snackSpots = snackSpots,
		spots = { v(36, 0, 6), v(12.5, 0, -3), v(-20, 0, -27), v(8, 0, -27), v(41, 0, 0.5), v(32, 0, -8), v(9, 0, 29) },
		toiletSeats = toiletSeats,
		meetingSeats = {}, -- 회의실은 아직 장식이에요
		meetingZone = nil,
		gymSeats = gym.seats,
		gymZone = gym.zone,
		companyId = company.id,
		lamps = lamps,
		assemblyZone = assemblyZone,
		assemblyPoint = assemblyPoint,
		setAssemblyVisible = setAssemblyVisible,
		cakeSpots = { v(46.6, 3, 1.5), v(46.6, 3, 3), v(46.6, 3, 4.5) },
		workshopStart = v(BX, 0, 9.3), -- 부장 책상 뒤 (남쪽 벽 앞)
		workshopBoss = v(BX, 0, -28.4), -- 창가
		workshopLook = Vector3.new(0, 0, 1),
		candyZone = campus.candyZone, -- 🍭 공원 사탕 쉼터
		shops = shops, -- 🏪 편의점 · ☕ 커피 · 🍢 분식 (상가 1층) + 눈치 스트리트 가게
		storeName = "1층 편의점", -- 구매 안내 문구에 쓰여요
		-- 👮 단지 경비원 · 🛍️ 단지에 있나 (옥상처럼 농땡이 수입이 쌓여요: "street" 상태, 초당 9원)
		guardPost = campus.guardPost,
		guards = campus.guards, -- 👮 구역별 경비원 세 명
		streetScale = function(position: Vector3)
			return Campus.incomeScale(position, company.id)
		end, -- 💰 단지 산책 수입 배율 (건물 안 < 그늘 < 탁 트인 곳)
		commuteSpawn = campus.commuteSpawn,
		commuteLobby = campus.daechung.elevatorDoor.Position, -- 🧭 출근길 안내: 우리 회사 로비 엘리베이터 -- 🚏 아침 출근길 시작 자리 (단지 버스 정류장)
		guardPatrol = campus.guardPatrol,
		inStreet = campus.contains,
		packageBox = packageBox,
		deliveryShelf = deliveryShelf,
		elevator = elevator,
		insideOffice = function(position: Vector3): boolean
			if position.Y >= FLOOR_Y + 20 then
				return false
			end
			if math.abs(position.X) <= HX * S + 1.5 and position.Z >= -HZ * S - 1.5 and position.Z <= HZS * S + 1.5 then
				return true
			end
			return math.abs(position.X - G.cx) <= G.hx + 1 and position.Z > HZS * S and position.Z <= G.cz + G.hz + 1
		end,
		packageSpots = { v(10, 0, -2), v(-45.5, 0, 2), v(34, 0, 9.5), v(-34, 0, CORRIDOR_Z), v(-22, 0, 9), v(-38, 0, 26.5), v(30, 0, -27), v(-20, 0, -14.5), v(22, 0, CORRIDOR_Z) },
		clawMachines = campus.clawMachines, -- 🧸 눈치 스트리트 (단지 공용)
		wheel = campus.wheel,
		dart = campus.dart,
		arcade = campus.arcade,
		parkBeds = campus.parkBeds, -- 🌷 공원 화단
		dinnerSeats = campus.dinnerSeats, -- 🍻 회식은 공원 식탁에서
		dinnerBoss = campus.dinnerBoss,
		dinnerLook = campus.dinnerLook,
		setClock = setClock,
	}
end

return OfficeDaechung
