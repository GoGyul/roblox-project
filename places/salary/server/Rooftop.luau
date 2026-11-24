-- 🏢 옥상 + 🚪 어색한 엘리베이터
--   사무실 엘리베이터 [E] → 엘리베이터 안 → 옥상 도착 (옥상 엘리베이터 [E] → 사무실)
--   😱 근무 중엔 가끔 부장님과 같이 타요: 부장님이 이쪽을 볼 때(👀 예고) 시선을 피해야 해요 → 못 피하면 의심도 +
--   🌬️ 옥상: 바람 쐬기 / 🏖️ 선베드 일광욕 / 🔭 망원경(부장님 위치 보기) / 물탱크·실외기 뒤에 숨기
--   👮 옥상 경비원이 근무 시간 내내 순찰해요 (부장님은 사무실에만). 💤 가끔 경비실에서 쉬는 틈을 노려요
--   📐 옥상은 예전보다 가로·세로 1.4배 넓어요 (ROOF_SCALE)
--
-- 옥상과 엘리베이터 칸은 사무실 훨씬 위 하늘에 지어요 (사무실 천장에 가려서 안 보여요).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)
local Build = require(ReplicatedStorage.Shared.Build)
local Npc = require(script.Parent.Npc)
local Guard = require(script.Parent.Guard)
local Walker = require(script.Parent.Walker)
local RoofPigeons = require(script.Parent.RoofPigeons)
local RoofPlane = require(script.Parent.RoofPlane)
local RoofGarden = require(script.Parent.RoofGarden)
local RoofScope = require(script.Parent.RoofScope)
local RoofHoop = require(script.Parent.RoofHoop)
local Theme = require(ReplicatedStorage.Shared.SalaryTheme)
-- 🧊 월드 색: 차분한 색(Theme.Mesh)이 있으면 그걸, 없으면 기본 색을 써요 (질감 B안)
local TC: any = setmetatable({}, {
	__index = function(_, key)
		return (Theme.Mesh :: any)[key] or (Theme.Color :: any)[key]
	end,
})
local Meshes = require(script.Parent.Meshes)

local Rooftop = {}
Rooftop.onElevator = nil :: ((Player, string) -> boolean)? -- 엘리베이터 [E]를 가로채는 훅 (true면 여기서 안 태워요)
Rooftop.ride = nil :: ((Player, boolean, boolean?) -> ())? -- (플레이어, 옥상행인가, 1층 로비에서 타나)

local ROOF = Vector3.new(0, 300, 0) -- 옥상 바닥 윗면 가운데
local ROOF_SCALE = 1.4 -- 📐 옥상을 넓혔어요 (가로·세로 1.4배 = 넓이 약 2배). 물건 묶음들도 이만큼 바깥쪽으로 퍼져요
local ROOF_W, ROOF_D = 70 * ROOF_SCALE, 50 * ROOF_SCALE
-- 예전 좌표(x, z)를 넓어진 옥상 좌표로
local function spread(x: number, y: number, z: number): Vector3
	return ROOF + Vector3.new(x * ROOF_SCALE, y, z * ROOF_SCALE)
end
local CABIN_BASE = Vector3.new(260, 300, 0) -- 엘리베이터 칸들 (한 사람당 하나씩)
local BOSS_LOOK = { skin = Color3.fromRGB(225, 190, 160), shirt = Color3.fromRGB(70, 70, 85), pants = Color3.fromRGB(40, 40, 50) }
local allowDodge = RateLimit.new(0.08) -- (화면도 0.12초 간격으로만 보내요)

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

---------------------------------------------------------------------------
-- 옥상 짓기
---------------------------------------------------------------------------
local function buildRoof(folder: Instance, companyId: string)
	local B = Build.new(folder, Vector3.zero)
	-- 📐 물건 묶음 단위로 옮겨요: group(묶음 중심)을 부르면 그 묶음은 통째로 넓어진 자리로 (모양은 그대로)
	local shift = Vector3.zero
	local function group(cx: number, cz: number)
		shift = Vector3.new(cx * (ROOF_SCALE - 1), 0, cz * (ROOF_SCALE - 1))
	end
	local function at(x: number, y: number, z: number): Vector3
		return ROOF + Vector3.new(x, y, z) + shift
	end
	local fancy = companyId == "nunchi"
	-- 🧊 힐링 가든(옥상 B안) 메시 소품. 못 불러왔으면 예전 파트로 지어요.
	Meshes.preload(Meshes.ALL)
	local useMesh = Meshes.ready("Planter", "Tree", "Sunbed", "PodChair", "Bench", "Fountain", "FlowerBed", "Stone", "LampPost")
	local hidden = { Transparency = 1 }
	-- 바닥과 난간
	B:part(Vector3.new(ROOF_W, 2, ROOF_D), at(0, -1, 0), { Color = if fancy then TC.woodLight else Color3.fromRGB(78, 128, 104), Material = if fancy then Enum.Material.WoodPlanks else Enum.Material.Concrete }) -- (대충상사: 초록 방수 페인트 바닥)
	-- 중앙 라운지 데크와 산책 띠가 흩어진 옥상 콘텐츠를 하나의 공간으로 묶어요.
	B:part(Vector3.new(36, 0.14, 16), at(0, 0.08, 0), { Color = Color3.fromRGB(160, 216, 150), Material = Enum.Material.Grass, CanCollide = false }) -- 가운데 잔디
	B:part(Vector3.new(ROOF_W - 8, 0.15, 3), at(0, 0.09, 10), { Color = TC.mintSoft, Material = Enum.Material.Grass, CanCollide = false })
	for _, x in { -22, -11, 0, 11, 22 } do
		if useMesh then
			Meshes.place(B, "Planter", at(x, 0, 10), 0, { scale = 0.85, colors = { Box = TC.woodLight } })
			B:part(Vector3.new(5, 1.2, 1.6), at(x, 0.6, 10), hidden)
			continue
		end
		B:part(Vector3.new(5, 1.2, 2.4), at(x, 0.6, 10), { Color = TC.wood, Material = Enum.Material.WoodPlanks })
		for _, dx in { -1.4, 0, 1.4 } do
			B:part(Vector3.new(1.1, 1.1, 1.1), at(x + dx, 1.45, 10), { Shape = Enum.PartType.Ball, Color = if x % 2 == 0 then TC.coral else TC.yellow, Material = Enum.Material.Grass, CanCollide = false })
		end
	end
	for _, info in {
		{ Vector3.new(ROOF_W, 3.5, 0.6), at(0, 1.75, -ROOF_D / 2) },
		{ Vector3.new(ROOF_W, 3.5, 0.6), at(0, 1.75, ROOF_D / 2) },
		{ Vector3.new(0.6, 3.5, ROOF_D), at(-ROOF_W / 2, 1.75, 0) },
		{ Vector3.new(0.6, 3.5, ROOF_D), at(ROOF_W / 2, 1.75, 0) },
	} do
		B:part(info[1], info[2], { Color = if fancy then Color3.fromRGB(200, 205, 210) else Color3.fromRGB(196, 190, 178), Material = if fancy then Enum.Material.Metal else Enum.Material.Concrete })
		if not fancy then -- 난간벽 위 철제 손잡이
			B:part(Vector3.new(math.max(info[1].X, 0.25), 0.25, math.max(info[1].Z, 0.25)), info[2] + Vector3.new(0, 2.6, 0), { Color = Color3.fromRGB(70, 76, 84), Material = Enum.Material.Metal, CanCollide = false })
		end
		B:part(Vector3.new(info[1].X, 30, info[1].Z), info[2] + Vector3.new(0, 15, 0), { Transparency = 1 }) -- 못 넘어가게
	end
	-- 🚪 엘리베이터 탑 (왼쪽)
	group(-30, 0)
	B:part(Vector3.new(8, 10, 9), at(-30, 5, 0), { Color = Color3.fromRGB(190, 190, 195), Material = Enum.Material.Concrete })
	local door = B:part(Vector3.new(0.3, 8, 5), at(-25.85, 4, 0), { Name = "RoofElevatorDoor", Color = Color3.fromRGB(170, 175, 185), Material = Enum.Material.Metal, Reflectance = 0.15 })
	if not fancy then
		-- 옥탑 위: TV 안테나와 위성 접시 (장식)
		local steel = { Color = Color3.fromRGB(150, 154, 160), Material = Enum.Material.Metal, CanCollide = false }
		B:part(Vector3.new(0.2, 7, 0.2), at(-31.5, 13.5, -2), steel)
		for k = 0, 3 do
			B:part(Vector3.new(0.12, 0.12, 3 - k * 0.5), at(-31.5, 14 + k * 0.8, -2), steel)
		end
		B:part(Vector3.new(0.3, 2.6, 2.6), nil, { CFrame = CFrame.new(at(-28, 11.4, 2.5)) * CFrame.Angles(0, math.rad(35), math.rad(60)), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(226, 226, 222), Material = Enum.Material.Metal, CanCollide = false })
		B:part(Vector3.new(0.2, 1.4, 0.2), at(-28, 10.7, 2.5), steel)
	end
	local sign = B:part(Vector3.new(0.2, 1.2, 5), at(-25.8, 9, 0), { Color = Color3.fromRGB(30, 35, 45) })
	Build.surfaceText(sign, Enum.NormalId.Right, "🚪 사무실로 ▼", { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 220, 120) })
	-- 🛢️ 물탱크 (숨기 좋아요) + 실외기들
	group(16, -12)
	B:part(Vector3.new(7, 7, 7), at(16, 3.5, -12), { Shape = Enum.PartType.Cylinder, Orientation = Vector3.new(0, 0, 90), Color = (if fancy then Color3.fromRGB(80, 150, 200) else Color3.fromRGB(220, 178, 70)), Material = Enum.Material.Metal })
	local tankLabel = B:part(Vector3.new(0.2, 1.4, 3.5), at(12.4, 4, -12), { Color = (if fancy then Color3.fromRGB(80, 150, 200) else Color3.fromRGB(196, 150, 50)) })
	Build.surfaceText(tankLabel, Enum.NormalId.Left, "💧 물탱크", { TextColor3 = Color3.new(1, 1, 1) })
	for _, xz in { { 0, -20 }, { -12, 18 }, { 28, 10 }, { -30, -16 }, { -2, 2 } } do
		group(xz[1], xz[2])
		B:part(Vector3.new(4, 3, 3), at(xz[1], 1.5, xz[2]), { Color = Color3.fromRGB(215, 215, 210), Material = Enum.Material.Metal }) -- 실외기
		B:part(Vector3.new(0.1, 2, 2), at(xz[1] + 2.05, 1.6, xz[2]), { Color = Color3.fromRGB(60, 60, 65), Shape = Enum.PartType.Cylinder })
	end
	-- 🙈 숨을 곳 더 (부장님 시선을 가려요)
	-- 📦 택배 상자 더미 (오른쪽)
	local cardboard = Color3.fromRGB(200, 160, 110)
	group(22, 3)
	for _, info in {
		{ Vector3.new(3, 2.4, 3), at(22, 1.2, 2) },
		{ Vector3.new(2.6, 2.2, 2.6), at(24.7, 1.1, 3.3) },
		{ Vector3.new(2.6, 2.2, 2.6), at(22.3, 3.5, 2.2) },
		{ Vector3.new(2.2, 1.8, 2.2), at(19.9, 0.9, 4.4) },
		{ Vector3.new(2.4, 2, 2.4), at(24.2, 3.3, 3) },
	} do
		B:part(info[1], info[2], { Color = cardboard, Material = Enum.Material.Cardboard })
	end
	-- 🧺 빨래 건조대 + 이불 (가운데, 펄럭이는 이불 뒤에 숨기)
	group(6.5, 5)
	for _, x in { 3, 10 } do
		B:part(Vector3.new(0.25, 5.4, 0.25), at(x, 2.7, 5), { Color = Color3.fromRGB(190, 190, 195), Material = Enum.Material.Metal })
	end
	B:part(Vector3.new(7.3, 0.2, 0.2), at(6.5, 5.3, 5), { Color = Color3.fromRGB(190, 190, 195), Material = Enum.Material.Metal })
	for _, info in { { 4.7, Color3.fromRGB(245, 245, 240) }, { 8.3, Color3.fromRGB(170, 210, 240) } } do
		B:part(Vector3.new(3.2, 4.2, 0.12), at(info[1], 3.2, 5), { Color = info[2], Material = Enum.Material.Fabric })
	end
	-- 🌳 큰 화분 나무 (왼쪽 앞) + 넓어진 자리에 하나 더 (오른쪽 뒤)
	for _, info in { { -18, -10 }, { 30, 18 } } do
		local tx, tz = info[1], info[2]
		group(tx, tz)
		if useMesh then
			Meshes.place(B, "Tree", at(tx, 0, tz), tx * 20, { scale = 1.3 })
			B:part(Vector3.new(2.2, 4.4, 2.2), at(tx, 2.2, tz), hidden)
			continue
		end
		B:part(Vector3.new(2.2, 2.6, 2.6), at(tx, 1.1, tz), { Shape = Enum.PartType.Cylinder, Orientation = Vector3.new(0, 0, 90), Color = Color3.fromRGB(170, 100, 70), Material = Enum.Material.Brick })
		B:part(Vector3.new(0.7, 4, 0.7), at(tx, 4, tz), { Color = Color3.fromRGB(110, 80, 50), Material = Enum.Material.Wood })
		B:part(Vector3.new(6, 5, 6), at(tx, 7.4, tz), { Shape = Enum.PartType.Ball, Color = Color3.fromRGB(70, 150, 70), Material = Enum.Material.Grass })
	end
	-- 🏗️ 환기 덕트 (가운데 앞)
	group(10, -9)
	B:part(Vector3.new(8, 3, 2.6), at(10, 1.5, -9), { Color = Color3.fromRGB(175, 180, 185), Material = Enum.Material.DiamondPlate })
	for _, x in { 7.5, 12.5 } do
		B:part(Vector3.new(1.8, 1, 1.8), at(x, 3.5, -9), { Shape = Enum.PartType.Cylinder, Orientation = Vector3.new(0, 0, 90), Color = Color3.fromRGB(120, 125, 130), Material = Enum.Material.Metal })
	end
	-- 📦 들어가서 숨는 큰 상자 (안에 숨을 자리가 있어요 → [E] 숨기)
	local function hideBox(center: Vector3)
		local W, H, T = 3.8, 4.8, 0.2
		for _, info in {
			{ Vector3.new(W, H, T), center + Vector3.new(0, H / 2, -W / 2) },
			{ Vector3.new(W, H, T), center + Vector3.new(0, H / 2, W / 2) },
			{ Vector3.new(T, H, W), center + Vector3.new(-W / 2, H / 2, 0) },
			{ Vector3.new(T, H, W), center + Vector3.new(W / 2, H / 2, 0) },
		} do
			local wall = B:part(info[1], info[2], { Color = cardboard, Material = Enum.Material.Cardboard })
			local _ = wall
		end
		-- 뚜껑 (반쯤 열린 날개, 통과할 수 있어요)
		B:part(Vector3.new(W, T, W / 2), nil, { CFrame = CFrame.new(center + Vector3.new(0, H + 0.4, -W / 4)) * CFrame.Angles(math.rad(25), 0, 0), Color = cardboard, Material = Enum.Material.Cardboard, CanCollide = false })
		B:part(Vector3.new(W, T, W / 2), nil, { CFrame = CFrame.new(center + Vector3.new(0, H, W / 4)), Color = cardboard, Material = Enum.Material.Cardboard, CanCollide = false })
		local label = B:part(Vector3.new(2.6, 1, 0.05), center + Vector3.new(0, H * 0.6, -W / 2 - 0.13), { Color = Color3.fromRGB(230, 200, 150) })
		Build.surfaceText(label, Enum.NormalId.Front, "📦 취급주의", { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(150, 40, 30) })
		B:part(Vector3.new(2, 0.4, 2), center + Vector3.new(0, 0.3, 0), { ClassName = "Seat", Name = "HideSeat", Color = cardboard, Transparency = 1 })
	end
	-- 넓어진 옥상: 숨는 상자 3개 (경비원 순찰을 피해 들어가요)
	for _, xz in { { 26, -17 }, { -17, -2 }, { 2, 14 } } do
		group(xz[1], xz[2])
		hideBox(at(xz[1], 0, xz[2]))
	end

	-- 🏖️ 선베드 + 파라솔
	group(11, 17)
	local loungerSeats = {}
	for i, x in { 2, 8, 14, 20 } do
		local seat = B:part(Vector3.new(2, 0.5, 4.5), nil, {
			ClassName = "Seat",
			Name = "Lounger",
			CFrame = CFrame.new(at(x, 0.9, 16)),
			Color = if i % 2 == 0 then TC.sky else TC.surface,
			Material = Enum.Material.Fabric,
		})
		if useMesh then
			seat.Transparency = 1
			Meshes.place(B, "Sunbed", at(x, 0, 17), 180, { colors = { Pillow = if i % 2 == 0 then TC.sky else TC.coral } })
		else
			B:part(Vector3.new(2, 0.4, 1.8), nil, { CFrame = CFrame.new(at(x, 1.6, 18.6)) * CFrame.Angles(math.rad(-50), 0, 0), Color = if i % 2 == 0 then TC.sky else TC.coralSoft, Material = Enum.Material.Fabric })
			-- 선베드 아래 프레임과 짧은 다리까지 보여 가구처럼 읽히게 해요.
			B:part(Vector3.new(2.25, 0.18, 4.8), at(x, 0.6, 16), { Color = TC.navy, Material = Enum.Material.Metal })
			for _, dz in { -1.7, 1.7 } do
				for _, dx in { -0.85, 0.85 } do
					B:part(Vector3.new(0.22, 0.65, 0.22), at(x + dx, 0.32, 16 + dz), { Color = TC.navy, Material = Enum.Material.Metal })
				end
			end
		end
		table.insert(loungerSeats, seat)
	end
	for _, x in { 5, 17 } do
		B:part(Vector3.new(0.3, 6, 0.3), at(x, 3, 18), { Color = Color3.fromRGB(200, 200, 200) })
		B:part(Vector3.new(0.6, 6, 6), at(x, 6.2, 18), { Shape = Enum.PartType.Cylinder, Orientation = Vector3.new(0, 0, 90), Color = Color3.fromRGB(250, 120, 90), Material = Enum.Material.Fabric })
	end
	-- 라운지 전체를 묶는 가벼운 퍼걸러. 기둥은 선베드 바깥에 둬 이동을 방해하지 않아요.
	for _, x in { 0, 22 } do
		for _, z in { 13, 21 } do
			B:part(Vector3.new(0.45, 7, 0.45), at(x, 3.5, z), { Color = TC.surface, Material = Enum.Material.Metal })
		end
	end
	for _, z in { 13, 21 } do
		B:part(Vector3.new(22.5, 0.4, 0.5), at(11, 7, z), { Color = TC.mintDark, Material = Enum.Material.Metal })
	end
	for x = 1, 21, 4 do
		B:part(Vector3.new(0.35, 0.35, 8), at(x, 7, 17), { Color = TC.woodLight, Material = Enum.Material.WoodPlanks, CanCollide = false })
	end
	-- 천막 천과 꼬마전구를 더해 구조물이 실제 휴게 공간으로 보이게 해요.
	for x = 3, 19, 4 do
		B:part(Vector3.new(3.4, 0.12, 7.4), nil, {
			CFrame = CFrame.new(at(x, 6.82 + (x % 8) * 0.025, 17)) * CFrame.Angles(0, 0, math.rad(if x % 8 < 4 then 4 else -4)),
			Color = if x % 8 < 4 then TC.surface else TC.yellowSoft,
			Material = Enum.Material.Fabric,
			CanCollide = false,
		})
	end
	for x = 1, 21, 2 do
		local bulb = B:part(Vector3.new(0.32, 0.32, 0.32), at(x, 6.35, 13.15), { Shape = Enum.PartType.Ball, Color = TC.yellow, Material = Enum.Material.Neon, CanCollide = false })
		local light = Instance.new("PointLight")
		light.Range = 6
		light.Brightness = 0.3
		light.Color = TC.yellowSoft
		light.Parent = bulb
	end
	-- 독립 라운지 포드: 등판·옆판·차양을 꺾어 만든 반개방 캡슐 좌석.
	local podX, podZ = -7, 17
	if useMesh then
		Meshes.place(B, "PodChair", at(podX, 0, podZ), 180, { scale = 1.15 })
	else
		B:part(Vector3.new(5.2, 0.55, 4.4), at(podX, 0.6, podZ), { Color = TC.surface, Material = Enum.Material.SmoothPlastic })
		B:part(Vector3.new(5.2, 4.8, 0.45), nil, { CFrame = CFrame.new(at(podX, 3, podZ + 2)) * CFrame.Angles(math.rad(-8), 0, 0), Color = TC.surface, Material = Enum.Material.SmoothPlastic })
		for _, side in { -1, 1 } do
			B:part(Vector3.new(0.42, 4.2, 4.2), nil, { CFrame = CFrame.new(at(podX + side * 2.45, 2.4, podZ + 0.2)) * CFrame.Angles(0, 0, math.rad(side * 8)), Color = TC.surface, Material = Enum.Material.SmoothPlastic })
		end
		B:part(Vector3.new(5, 0.42, 4.2), nil, { CFrame = CFrame.new(at(podX, 5.05, podZ + 0.2)) * CFrame.Angles(math.rad(7), 0, 0), Color = TC.surface, Material = Enum.Material.SmoothPlastic })
		B:part(Vector3.new(4.1, 0.7, 2.4), at(podX, 1.05, podZ), { Color = TC.yellow, Material = Enum.Material.Fabric })
		B:part(Vector3.new(4.1, 2, 0.6), nil, { CFrame = CFrame.new(at(podX, 2.15, podZ + 1.25)) * CFrame.Angles(math.rad(-10), 0, 0), Color = TC.coralSoft, Material = Enum.Material.Fabric })
	end
	-- 🌱 텃밭 상자와 벤치, 꼬마전구
	group(-11, -20)
	local gardenBoxes = {}
	-- 📐 텃밭을 넓혔어요: 큰 화단 3개 (화분 6칸) + 잔디 깔개 + 낮은 울타리
	B:part(Vector3.new(21, 0.1, 6), at(-11, 0.05, -20), { Color = Color3.fromRGB(95, 160, 80), Material = Enum.Material.Grass, CanCollide = false })
	for _, side in { -1, 1 } do
		B:part(Vector3.new(21.4, 0.6, 0.25), at(-11, 0.3, -20 + side * 3.1), { Color = Color3.fromRGB(235, 225, 200), Material = Enum.Material.WoodPlanks, CanCollide = false })
	end
	for _, x in { -17, -11, -5 } do
		B:part(Vector3.new(6, 1.2, 3), at(x, 0.6, -20), { Color = Color3.fromRGB(130, 90, 60), Material = Enum.Material.WoodPlanks })
		local soil = B:part(Vector3.new(5.6, 0.3, 2.6), at(x, 1.3, -20), { Name = "GardenSoil", Color = Color3.fromRGB(110, 80, 55), Material = Enum.Material.Ground })
		table.insert(gardenBoxes, soil)
	end
	local gardenSign = B:part(Vector3.new(3.4, 1, 0.15), at(-11, 2.3, -21.4), { Color = Color3.fromRGB(80, 60, 40) })
	Build.surfaceText(gardenSign, Enum.NormalId.Back, "🌱 직장인 텃밭", { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 255, 170) })
	group(-6, 20)
	local roofBench = B:part(Vector3.new(6, 0.5, 1.8), at(-6, 1.3, 20), { Color = Color3.fromRGB(150, 110, 75), Material = Enum.Material.WoodPlanks }) -- 벤치
	if useMesh then
		roofBench.Transparency = 1
		Meshes.place(B, "Bench", at(-6, 0, 20), 180, { scale = 1.4 })
	end
	-- ⛲ 분수와 화단, 디딤돌, 가로등 (지나다닐 수 있어요: 경비원 순찰 길을 막지 않게 가운데 기둥만 막아요)
	if useMesh then
		group(-12, -9)
		Meshes.place(B, "Fountain", at(-12, 0, -9), 0)
		B:part(Vector3.new(1.2, 3.2, 1.2), at(-12, 1.6, -9), hidden)
		Meshes.place(B, "FlowerBed", at(-12, 0, -15.5), 0)
		Meshes.place(B, "FlowerBed", at(-4.5, 0, -6), 60, { colors = { Flowercoral = TC.sky } })
		for i, offset in { Vector3.new(4, 0, 3), Vector3.new(6, 0, 5.5), Vector3.new(8.5, 0, 7.5), Vector3.new(11, 0, 10) } do
			Meshes.place(B, "Stone", at(-12, 0, -9) + offset, i * 40)
		end
		for _, xz in { { 14, -22 }, { -22, 8 } } do
			group(xz[1], xz[2])
			local post = Meshes.place(B, "LampPost", at(xz[1], 0, xz[2]), 0, { scale = 1.2 })
			local glow = Instance.new("PointLight")
			glow.Range = 14
			glow.Brightness = 0.5
			glow.Color = TC.yellowSoft
			glow.Parent = post.Bulb
		end
	end
	group(0, 22)
	for i = 0, 12 do
		local bulb = B:part(Vector3.new(0.4, 0.4, 0.4), at(-30 + i * 5, 7, 22), { Shape = Enum.PartType.Ball, Color = Color3.fromRGB(255, 220, 140), Material = Enum.Material.Neon, CanCollide = false })
		local _ = bulb
	end
	-- 🔭 망원경 (앞쪽 난간)
	group(-2, -23)
	B:part(Vector3.new(0.2, 3, 0.2), at(-2, 1.5, -23), { Color = Color3.fromRGB(60, 60, 65) })
	local telescope = B:part(Vector3.new(0.6, 0.6, 2.4), nil, {
		Name = "Telescope",
		CFrame = CFrame.new(at(-2, 3.2, -23)) * CFrame.Angles(math.rad(10), 0, 0),
		Color = Color3.fromRGB(230, 200, 80),
		Material = Enum.Material.Metal,
	})
	if not fancy then
		-- 초록 방수 바닥의 이음선과 물 빠지는 배수구 (장식)
		group(0, 0)
		for x = -42, 42, 14 do
			B:part(Vector3.new(0.15, 0.04, ROOF_D - 2), at(x, 0.03, 0), { Color = Color3.fromRGB(62, 104, 84), CanCollide = false, CanQuery = false })
		end
		for _, xz in { { -44, -30 }, { 44, 30 }, { 44, -30 } } do
			B:part(Vector3.new(1.6, 0.06, 1.6), at(xz[1], 0.04, xz[2]), { Color = Color3.fromRGB(60, 62, 66), Material = Enum.Material.DiamondPlate, CanCollide = false, CanQuery = false })
		end
		-- 장독대 (물탱크 옆, 장식)
		group(16, -12)
		for i, info in { { 21.6, -8.6, 2.2 }, { 23.4, -9.6, 1.7 }, { 21.9, -10.6, 1.4 } } do
			local jar = B:part(Vector3.new(info[3], info[3] * 0.9, info[3] * 0.9), at(info[1], info[3] * 0.45, info[2]), { Shape = Enum.PartType.Ball, Color = Color3.fromRGB(96, 62, 44), CanCollide = false })
			B:part(Vector3.new(0.18, info[3] * 0.62, info[3] * 0.62), nil, { CFrame = CFrame.new(at(info[1], info[3] * 0.88, info[2])) * CFrame.Angles(0, 0, math.rad(90)), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(70, 46, 34), CanCollide = false })
			local _ = jar, i
		end
		group(0, 0)
	end
	-- 🏙️ 주변 빌딩 숲 (아래로 보이는 도시)
	for i = 1, 26 do
		local angle = (i / 26) * math.pi * 2
		local distance = math.random(80, 160) -- (옥상이 넓어져서 더 멀리)
		local height = math.random(30, 110)
		local width = math.random(10, 22)
		local base = ROOF + Vector3.new(math.cos(angle) * distance, -height / 2 - 6, math.sin(angle) * distance)
		B:part(Vector3.new(width, height, width), base, {
			Color = pick({ Color3.fromRGB(150, 160, 175), Color3.fromRGB(120, 130, 150), Color3.fromRGB(180, 180, 175), Color3.fromRGB(90, 100, 120) }),
			Material = Enum.Material.Concrete,
			CanCollide = false,
			CanQuery = false,
		})
	end
	group(0, 0)
	return {
		door = door,
		spawn = spread(-30, 0, 0) + Vector3.new(8, 0, 0), -- 엘리베이터 문 바로 앞
		telescope = telescope,
		loungers = loungerSeats,
		gardenBoxes = gardenBoxes,
		guardPost = ROOF + Vector3.new(44, 0, -26), -- 오른쪽 앞 구석 (경비실은 그 뒤 난간 쪽)
		-- 👮 경비원 순찰 지점 (숨을 곳 뒤까지 둘러봐요)
		patrol = {
			spread(-10, 0, 0), spread(10, 0, 0), spread(22, 0, -18), spread(22, 0, 8), spread(5, 0, -18), spread(-18, 0, 15),
			spread(10, 0, 12), spread(28, 0, -2), spread(-6, 0, -12), spread(-28, 0, -10), spread(-24, 0, 20), spread(16, 0, 20),
		},
	}
end

-- 엘리베이터 칸 하나 짓기 (탈 때마다 하나씩)
local function buildCabin(folder: Instance, center: Vector3, toRoof: boolean, fromLobby: boolean?): Model
	local model = Instance.new("Model")
	model.Name = "ElevatorCabin"
	model.Parent = folder
	local B = Build.new(model, Vector3.zero)
	local wall = { Color = Color3.fromRGB(200, 195, 185), Material = Enum.Material.Metal }
	B:part(Vector3.new(8, 1, 8), center + Vector3.new(0, -0.5, 0), { Color = Color3.fromRGB(110, 90, 70), Material = Enum.Material.Wood })
	B:part(Vector3.new(8, 1, 8), center + Vector3.new(0, 10.5, 0), wall)
	B:part(Vector3.new(1, 10, 8), center + Vector3.new(-4.5, 5, 0), wall)
	B:part(Vector3.new(1, 10, 8), center + Vector3.new(4.5, 5, 0), wall)
	B:part(Vector3.new(8, 10, 1), center + Vector3.new(0, 5, 4.5), { Color = Color3.fromRGB(180, 210, 230), Material = Enum.Material.Glass, Reflectance = 0.4 }) -- 뒤쪽 거울
	B:part(Vector3.new(8, 10, 1), center + Vector3.new(0, 5, -4.5), { Color = Color3.fromRGB(170, 175, 185), Material = Enum.Material.Metal }) -- 문
	local display = B:part(Vector3.new(2, 0.8, 0.1), center + Vector3.new(0, 8.6, -3.95), { Color = Color3.fromRGB(20, 20, 25) })
	Build.surfaceText(display, Enum.NormalId.Back, if toRoof then "▲ 옥상" elseif fromLobby then "▲ 사무실" else "▼ 사무실", { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 120, 60) })
	local lamp = B:part(Vector3.new(3, 0.2, 3), center + Vector3.new(0, 9.9, 0), { Color = Color3.fromRGB(255, 245, 220), Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 1.2
	light.Parent = lamp
	return model
end

---------------------------------------------------------------------------
-- hooks (Employees가 채워 줘요):
--   stare(player)      : 엘리베이터에서 눈 마주침 → 의심도 +
--   ninja(player) → n  : 부장님 엘리베이터를 무사히 넘긴 횟수 +1
--   unlock(player, id) : 업적
function Rooftop.start(office, boss, dayCycle, remotes, hooks, events)
	local folder = Instance.new("Folder")
	folder.Name = "Rooftop"
	folder.Parent = office.folder
	local roof = buildRoof(folder, office.companyId)
	local riding: { [Player]: any } = {}
	local cabinSlot = 0
	local api = {}

	-- 🌬️ 옥상 위에 있나?
	function api.onRoof(position: Vector3): boolean
		local offset = position - ROOF
		return math.abs(offset.X) <= ROOF_W / 2 and math.abs(offset.Z) <= ROOF_D / 2 and offset.Y > -3 and offset.Y < 25
	end

	-- 👮 옥상 경비원: 부장님은 사무실에만! 옥상은 경비원이 근무 시간 내내 순찰해요 (💤 가끔 경비실에서 쉬어요)
	local roofGuard = Guard.new({
		folder = folder,
		post = roof.guardPost,
		patrol = roof.patrol,
		area = function(position: Vector3): boolean
			return api.onRoof(position)
		end,
		dayCycle = dayCycle,
		events = events,
		remotes = remotes,
		name = "옥상 경비원 최씨",
		id = "roof",
		useGift = hooks.useGuardGift,
		lines = { "거기! 근무 시간에 옥상에서 뭐 해요?", "어느 부서예요? 부장님께 말씀드릴까?", "내가 다 보고 있어요~ 옥상은 내 구역!" },
		rest = true,
		range = SalaryConfig.ROOF_GUARD_RANGE,
	})
	local PIGEON_SPOT = spread(-10, 0, 8)

	-- 🐦 비둘기 친구 (벤치 앞 공터)
	local pigeons = RoofPigeons.start(folder, PIGEON_SPOT, remotes, {
		snackCount = hooks.pigeonSnackCount, -- 🍪 🎒 과자
		useSnack = hooks.useSnack,
		fedToday = hooks.pigeonFedToday, -- 🐦 오늘 이미 과자를 줬나 (하루 한 번)
		fed = hooks.pigeonFed,
		seen = hooks.pigeonSeen,
		giftRoll = hooks.pigeonGiftRoll, -- 🎁 비둘기의 보은
		giftMissed = hooks.pigeonGiftMissed,
		giftPicked = hooks.pigeonGiftPicked,
		giftDropped = hooks.pigeonGiftDropped, -- 🔔 알림
		workDay = function(): number
			return dayCycle.day
		end,
		guardNear = function()
			return roofGuard.near(PIGEON_SPOT, SalaryConfig.PIGEON_GUARD_RANGE)
		end,
		onRoof = function(position: Vector3)
			return api.onRoof(position)
		end,
	})
	-- 🐦 경비원이 다가오면 비둘기들이 먼저 푸드덕 (한 번 다가올 때마다 한 번)
	task.spawn(function()
		local wasNear = false
		while folder.Parent do
			task.wait(0.5)
			local near = roofGuard.watching() and roofGuard.near(PIGEON_SPOT, SalaryConfig.PIGEON_GUARD_RANGE)
			if near and not wasNear then
				pigeons.scare()
			end
			wasNear = near
		end
	end)

	---------------------------------------------------------------- 🌅 노을 타임
	local function isSunset(): boolean
		return dayCycle.phase == "work" and not dayCycle.waiting and dayCycle.minute >= SalaryConfig.SUNSET_START
	end
	-- 📸 노을 포토존 (앞쪽 왼편 난간)
	local photoFrame = Instance.new("Part")
	photoFrame.Name = "SunsetPhotoZone"
	photoFrame.Size = Vector3.new(4, 3, 0.3)
	photoFrame.CFrame = CFrame.new(spread(-20, 3.2, -23.6))
	photoFrame.Color = Color3.fromRGB(255, 190, 120)
	photoFrame.Material = Enum.Material.Wood
	photoFrame.Anchored = true
	photoFrame.CanCollide = false
	photoFrame.Parent = folder
	local hole = Instance.new("Part") -- 액자 안쪽 (뻥 뚫린 느낌)
	hole.Size = Vector3.new(3.2, 2.2, 0.32)
	hole.CFrame = photoFrame.CFrame
	hole.Transparency = 1
	hole.Anchored = true
	hole.CanCollide = false
	hole.Parent = folder
	Build.surfaceText(photoFrame, Enum.NormalId.Back, "📸 노을 포토존", { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(90, 40, 20) })
	local photoPrompt = Instance.new("ProximityPrompt")
	photoPrompt.ActionText = "노을 사진 찍기"
	photoPrompt.ObjectText = "📸 포토존 (17시부터)"
	photoPrompt.MaxActivationDistance = 8
	photoPrompt.RequiresLineOfSight = false
	photoPrompt.Enabled = false
	photoPrompt.Parent = photoFrame
	photoPrompt.Triggered:Connect(function(player)
		if not isSunset() then
			return
		end
		local first, count, prize = hooks.sunsetPhoto(player)
		remotes.SunsetPhoto:FireClient(player, first, count, prize)
	end)

	task.spawn(function()
		local watched: { [Player]: number } = {}
		local announcedDay = -1
		while true do
			task.wait(0.5)
			local sunset = isSunset()
			if ReplicatedStorage:GetAttribute("Sunset") ~= sunset then
				ReplicatedStorage:SetAttribute("Sunset", sunset)
			end
			photoPrompt.Enabled = sunset
			if not sunset then
				table.clear(watched)
				continue
			end
			if announcedDay ~= dayCycle.day then
				announcedDay = dayCycle.day
				for _, player in Players:GetPlayers() do
					remotes.Notify:FireClient(player, "🌅 창밖이 주황빛으로 물들어요… 옥상에서 노을을 보면 하루의 피로가 싹!")
				end
			end
			-- 옥상에서 SUNSET_WATCH초 감상하면 힐링 (하루 한 번)
			for _, player in Players:GetPlayers() do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and api.onRoof(root.Position) then
					watched[player] = (watched[player] or 0) + 0.5
					if watched[player] >= SalaryConfig.SUNSET_WATCH and watched[player] < SalaryConfig.SUNSET_WATCH + 0.5 then
						if hooks.sunsetWatched(player) then
							remotes.SunsetMoment:FireClient(player)
						end
					end
				else
					watched[player] = nil
				end
			end
		end
	end)

	-- 🏀 옥상 농구 (뒤쪽 왼편 구석) — 공 소리에 👮 경비원이 확인하러 와요
	RoofHoop.start(folder, spread(-26, 0, 22), remotes, {
		prize = hooks.hoopPrize,
		unlock = hooks.unlock,
		noise = function()
			roofGuard.investigate(spread(-26, 0, 22) + Vector3.new(0, 0, -6)) -- 🔊 공 소리 → 경비원이 농구대 쪽으로 확인하러 와요
		end,
	})

	-- 🔭 건너편 빌딩 관찰 일지 (오른쪽 난간)
	RoofScope.start(folder, spread(32, 0, -6), dayCycle, remotes, { found = hooks.sceneFound })

	-- 🌱 텃밭 (내 화분 6칸)
	RoofGarden.start(roof.gardenBoxes, remotes, { action = hooks.gardenAction })

	-- ✈️ 종이비행기 (앞 난간, 도시 쪽으로)
	RoofPlane.start(folder, spread(8, 0, -21), remotes, {
		onRoof = function(position: Vector3)
			return api.onRoof(position)
		end,
		bossModel = function()
			-- ✈️ 되돌아온 비행기는 근무 중인 경비원이 발사대 근처(20)에 있을 때만 머리에 꽂혀요
			if roofGuard.watching() and roofGuard.near(spread(8, 0, -21), 20) then
				return roofGuard.model
			end
			return nil
		end,
		prize = hooks.planePrize,
		bossHit = hooks.planeBossHit,
		unlock = hooks.unlock,
		best = hooks.planeBest,
	})
	-- 👮 옥상 경비원이 보고 있나: 보이나, 거리, 노려보는 중인가
	function api.sees(character: Model): (boolean, number, boolean, number)
		return roofGuard.sees(character)
	end

	local function notify(player: Player, message: string)
		remotes.Notify:FireClient(player, message)
	end

	---------------------------------------------------------------- 🚪 엘리베이터 타기
	-- 화면이 알려 준 "📱 폰 보기 / 🙂 앞 보기" 전환 기록으로, 이벤트 순간의 상태를 서버가 판정해요
	local function phoneAt(session, t: number): boolean
		local phone = false
		for _, change in session.toggles do
			if change.t <= t then
				phone = change.phone
			end
		end
		return phone
	end

	local function ride(player: Player, toRoof: boolean, fromLobby: boolean?)
		if riding[player] then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not (character and humanoid and root) or humanoid.Health <= 0 then
			return
		end
		-- 앉아 있으면 먼저 일어나요 (의자째 끌려가지 않게)
		if humanoid.SeatPart then
			for _, child in humanoid.SeatPart:GetChildren() do
				if child:IsA("Weld") and child.Name == "SeatWeld" then
					child:Destroy()
				end
			end
			humanoid.Sit = false
		end
		cabinSlot = (cabinSlot % 8) + 1
		local center = CABIN_BASE + Vector3.new(0, 0, cabinSlot * 20)
		local cabin = buildCabin(folder, center, toRoof, fromLobby)
		local testing = RunService:IsStudio() and SalaryConfig.TEST_ELEVATOR
		local withBoss = dayCycle.phase == "work" and boss.active and (testing or math.random() < SalaryConfig.ELEVATOR_BOSS_CHANCE)
		local duration = if withBoss then SalaryConfig.ELEVATOR_RIDE else SalaryConfig.ELEVATOR_RIDE_ALONE
		local session = { events = {}, toggles = {}, start = workspace:GetServerTimeNow() + (if withBoss then 2.5 else 0.5), failed = false }
		riding[player] = session

		task.wait(0.1)
		character:PivotTo(CFrame.lookAt(center + Vector3.new(1.6, 3, 1), center + Vector3.new(1.6, 3, -5)))
		local walkSpeed = if humanoid.WalkSpeed > 0 then humanoid.WalkSpeed else 16 -- (📦 택배 들고 느려진 것도 그대로 기억)
		humanoid.WalkSpeed = 0

		local fake: Model? = nil
		if withBoss then
			local model = Npc.create("김부장", BOSS_LOOK, cabin)
			model.Name = "BossDouble" -- (사무실의 진짜 부장님과 헷갈리지 않게)
			local froot = model:FindFirstChild("HumanoidRootPart") :: BasePart
			model:PivotTo(CFrame.lookAt(center + Vector3.new(-1.6, 3, 1), center + Vector3.new(-1.6, 3, -5)))
			froot.Anchored = true
			Npc.setStatus(model, "😐")
			fake = model
			-- 이벤트: 👀 쳐다보기 / 🗣️ 말 걸기 딱 한 번 (예고 ELEVATOR_WARN초 뒤에 판정 → 고를 시간 넉넉하게)
			local count = math.random(SalaryConfig.ELEVATOR_EVENTS[1], SalaryConfig.ELEVATOR_EVENTS[2])
			local t = SalaryConfig.ELEVATOR_WARN - 2.8 -- (아래에서 2.8~3.8초를 더해요: 첫 예고가 탑승 0.5~1.5초 뒤에 떠요)
			for _ = 1, count do
				t += math.random(28, 38) / 10
				if t > duration - 0.6 then
					break
				end
				table.insert(session.events, { t = t, kind = if math.random() < 0.55 then "look" else "talk" })
			end
		end
		remotes.ElevatorRide:FireClient(player, {
			start = session.start,
			duration = duration,
			toRoof = toRoof,
			fromLobby = fromLobby == true, -- 1층 로비에서 올라가는 중 (안내 문구용)
			withBoss = withBoss,
			events = session.events,
			warn = SalaryConfig.ELEVATOR_WARN,
		})

		-- 😐 부장님 미니게임 판정
		if withBoss and fake then
			local model = fake :: Model
			local froot = model:FindFirstChild("HumanoidRootPart") :: BasePart
			for _, event in session.events do
				local at = session.start + event.t
				while workspace:GetServerTimeNow() < at + SalaryConfig.ELEVATOR_GRACE do
					task.wait(0.03)
				end
				if not player.Parent or not model.Parent then
					break
				end
				local phone = phoneAt(session, at + SalaryConfig.ELEVATOR_GRACE)
				if event.kind == "look" then
					froot.CFrame = CFrame.lookAt(froot.Position, froot.Position + Vector3.new(1, 0, 0)) -- 휙! 이쪽을 봐요
					Npc.setStatus(model, "👀")
				else
					Npc.setStatus(model, "🗣️")
					Npc.say(model, pick(SalaryConfig.ElevatorTalkLines), 2.5)
				end
				local ok = if event.kind == "look" then phone else not phone
				if ok then
					remotes.ElevatorRide:FireClient(player, { result = "ok", kind = event.kind })
				else
					session.failed = true
					local line = if event.kind == "look" then "…(눈 마주침)" else "폰을 봐?!"
					Npc.say(model, line, 1.5)
					remotes.ElevatorRide:FireClient(player, { result = "fail", kind = event.kind, suspicion = SalaryConfig.ELEVATOR_FAIL })
					hooks.unlock(player, "elevator_awkward")
					hooks.stare(player, line) -- 의심도 +, 100이 되면 적발
				end
				task.wait(0.7)
				if model.Parent then
					froot.CFrame = CFrame.lookAt(froot.Position, froot.Position + Vector3.new(0, 0, -1))
					Npc.setStatus(model, "😐")
				end
			end
		end

		-- 도착!
		while workspace:GetServerTimeNow() < session.start + duration do
			task.wait(0.1)
		end
		riding[player] = nil
		if character.Parent then
			local destination = if toRoof then roof.spawn else office.elevator.exit
			character:PivotTo(CFrame.new(destination + Vector3.new(0, 3, 0)))
			-- (타는 동안 택배 미션이 끝나 속도가 바뀌었으면 그대로, 아니면 원래 속도로)
			humanoid.WalkSpeed = if humanoid.WalkSpeed > 0 then humanoid.WalkSpeed else walkSpeed
		end
		cabin:Destroy()
		if toRoof then
			hooks.unlock(player, "rooftop_first")
			notify(player, "🌬️ 옥상 도착! 👮 옥상 경비원 눈에 띄지 않게 조심! (💤 경비실에서 쉴 때가 찬스, 상자·물탱크 뒤에 숨어요)")
		end
		if withBoss and not session.failed then
			local count = hooks.ninja(player)
			notify(player, `😅 휴… 부장님과의 엘리베이터를 무사히 넘겼어요! (엘리베이터 닌자 {count}/3)`)
			if count >= 3 then
				hooks.unlock(player, "elevator_ninja")
			end
		end
	end

	-- [F] 📱 폰 보기 ↔ 🙂 앞 보기 (바꾼 시각과 상태를 기록해요)
	remotes.ElevatorDodge.OnServerEvent:Connect(function(player, phone, clickTime)
		local session = riding[player]
		if not session or not allowDodge(player) or typeof(phone) ~= "boolean" then
			return
		end
		local now = workspace:GetServerTimeNow()
		local t = if typeof(clickTime) == "number" and clickTime <= now + 0.05 and clickTime >= now - 0.6 then clickTime else now
		table.insert(session.toggles, { t = t, phone = phone })
	end)

	Rooftop.ride = ride -- 🚪 다른 모듈(Arrival의 층 선택)이 엘리베이터를 태울 때 써요
	local function elevatorPrompt(part: BasePart, toRoof: boolean)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = if toRoof then "옥상 가기" else "사무실로"
		prompt.ObjectText = "🚪 엘리베이터"
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
		prompt.Triggered:Connect(function(player)
			-- 💡 정전 중엔 엘리베이터도 멈춰요
			if events and events:is("blackout") then
				remotes.Notify:FireClient(player, "💡 정전이라 엘리베이터가 멈췄어요! 불이 들어오면 타세요.")
				return
			end
			-- 🚪 층 선택 창이 있으면(리뉴얼 대충상사) 그쪽에서 목적지를 고르게 해요
			if Rooftop.onElevator and Rooftop.onElevator(player, if toRoof then "office" else "roof") then
				return
			end
			task.spawn(ride, player, toRoof)
		end)
	end
	elevatorPrompt(office.elevator.door, true)
	elevatorPrompt(roof.door, false)

	---------------------------------------------------------------- 🔭 망원경: 부장님 위치 보기
	local function bossArea(): string
		if not boss.model.Parent then
			return "자리에 없음 (외출 중)"
		end
		local position = boss.root.Position
		if not office.insideOffice(position) then
			return "🌳 사무실 밖 (공원·거리 순찰 중)"
		end
		local spots = {
			{ office.bossStand, "부장님 자리" },
			{ office.pantryZone.Position, "탕비실 근처" },
			{ office.toiletZone.Position, "화장실 근처" },
			{ office.entrance, "출입문 근처" },
			{ office.printer.Position, "프린터 근처" },
			{ office.elevator.exit, "엘리베이터 앞 (!!)" },
		}
		if office.meetingZone then
			table.insert(spots, { office.meetingZone.Position, "회의실 근처" })
		end
		if office.shops and office.shops.store and office.insideOffice(office.shops.store.counter.Position) then -- (매점이 건물 1층으로 나간 대충상사에선 빼요)
			table.insert(spots, { office.shops.store.counter.Position, "매점 근처" })
		end
		local best, bestDistance = "직원 책상 사이", 18 -- (사무실이 넓어져서 14 → 18)
		for _, spot in spots do
			local distance = (Vector3.new(spot[1].X, 0, spot[1].Z) - Vector3.new(position.X, 0, position.Z)).Magnitude
			if distance < bestDistance then
				best, bestDistance = spot[2], distance
			end
		end
		local doing = if os.clock() < boss.distractedUntil then "😻 고양이 보는 중" elseif boss.scolding then "😡 누구 혼내는 중" elseif boss.watching then "👀 감시 중" else "😌 한눈 파는 중"
		return `{best} · {doing}`
	end
	local radar: { [Player]: number } = {}
	local telescopePrompt = Instance.new("ProximityPrompt")
	telescopePrompt.ActionText = "망원경 보기"
	telescopePrompt.ObjectText = "🔭 망원경"
	telescopePrompt.MaxActivationDistance = 7
	telescopePrompt.RequiresLineOfSight = false
	telescopePrompt.Parent = roof.telescope
	telescopePrompt.Triggered:Connect(function(player)
		radar[player] = os.clock() + SalaryConfig.TELESCOPE_SECONDS
		notify(player, `🔭 사무실 창문 너머로… 부장님이 보여요! ({SalaryConfig.TELESCOPE_SECONDS}초 동안 위쪽에 표시)`)
	end)

	-- 🔭 망원경 표시 갱신
	task.spawn(function()
		while true do
			task.wait(1)
			for player, untilTime in radar do
				if not player.Parent or os.clock() > untilTime then
					radar[player] = nil
					if player.Parent then
						player:SetAttribute("BossRadar", "")
					end
				else
					local ok, area = pcall(bossArea)
					player:SetAttribute("BossRadar", `🔭 부장님: {if ok then area else "?"} ({math.ceil(untilTime - os.clock())}초)`)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		riding[player] = nil
		radar[player] = nil
	end)

	return api
end

return Rooftop
