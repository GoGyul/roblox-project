-- 고결게임즈 메인 광장 짓기
--
--                [포탈 자리 1]
--                     │
--   [포탈 자리 2] ── 분수 + 고결게임즈 간판 ── [포탈 자리 3]
--                     │
--                 [시작 지점]
--
-- shared/Places.luau의 게임 목록 순서대로 포탈 자리에 포탈이 생기고,
-- 남은 자리에는 "준비 중" 아치가 서요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Build = require(ReplicatedStorage.Shared.Build)
local Places = require(ReplicatedStorage.Shared.Places)

local LobbyBuilder = {}

export type Portal = {
	game: Places.GameInfo,
	pad: BasePart,
	statusLabel: TextLabel,
}

local STONE = Color3.fromRGB(205, 195, 175)
local BRICK = Color3.fromRGB(150, 95, 70)
local GOLD = Color3.fromRGB(230, 185, 80)
local GROUND_Y = 1 -- 광장 바닥 윗면 높이

-- 포탈 자리: 광장 가운데를 바라보도록 서 있어요
local CENTER = Vector3.new(0, GROUND_Y, 0)
local SLOTS = {
	Vector3.new(0, GROUND_Y, -34), -- 북쪽 (시작 지점 정면)
	Vector3.new(-34, GROUND_Y, 0), -- 서쪽
	Vector3.new(34, GROUND_Y, 0), -- 동쪽
}

-- 자리의 기준 CFrame: 앞쪽(+Z)이 광장 가운데를 향해요
local function slotFrame(position: Vector3): CFrame
	return CFrame.lookAt(position, position + (position - CENTER))
end

local function lampPost(B, x: number, z: number)
	B:part(Vector3.new(0.8, 10, 0.8), Vector3.new(x, 6, z), { Color = Color3.fromRGB(40, 40, 45), Material = Enum.Material.Metal })
	local head = B:part(Vector3.new(1.6, 1.6, 1.6), Vector3.new(x, 11.8, z), {
		Color = Color3.fromRGB(255, 220, 150),
		Material = Enum.Material.Neon,
	})
	local light = Instance.new("PointLight")
	light.Color = head.Color
	light.Range = 24
	light.Brightness = 1.5
	light.Parent = head
end

local function bench(B, x: number, z: number, rotation: number)
	local wood = { Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.Wood }
	local base = CFrame.new(x, GROUND_Y, z) * CFrame.Angles(0, math.rad(rotation), 0)
	local seat = table.clone(wood)
	seat.CFrame = base * CFrame.new(0, 1.5, 0)
	B:part(Vector3.new(6, 0.5, 2), nil, seat)
	local back = table.clone(wood)
	back.CFrame = base * CFrame.new(0, 2.8, 0.9)
	B:part(Vector3.new(6, 2, 0.3), nil, back)
end

-- 아치 하나 (포탈이든 준비 중이든 공통)
local function arch(B, frame: CFrame, title: string, titleColor: Color3)
	local brick = { Color = BRICK, Material = Enum.Material.Brick }
	local function at(localPosition: Vector3, props)
		local p = table.clone(props)
		p.CFrame = frame * CFrame.new(localPosition)
		return p
	end
	B:part(Vector3.new(3, 15, 3), nil, at(Vector3.new(-7, 7.5, 0), brick))
	B:part(Vector3.new(3, 15, 3), nil, at(Vector3.new(7, 7.5, 0), brick))
	local beam = B:part(Vector3.new(17, 3, 3), nil, at(Vector3.new(0, 16.5, 0), brick))
	Build.surfaceText(beam, Enum.NormalId.Back, title, {
		Font = Enum.Font.GothamBlack,
		TextColor3 = titleColor,
	})
	return at
end

local function buildPortal(B, frame: CFrame, info: Places.GameInfo): Portal
	local at = arch(B, frame, `{info.emoji} {info.name}`, GOLD)

	local portal = B:part(Vector3.new(11, 15, 0.4), nil, at(Vector3.new(0, 7.5, 0), {
		Color = info.color,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
	}))
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(info.color)
	sparkles.LightEmission = 1
	sparkles.Rate = 25
	sparkles.Lifetime = NumberRange.new(1, 2)
	sparkles.Speed = NumberRange.new(1, 3)
	sparkles.SpreadAngle = Vector2.new(30, 30)
	sparkles.Size = NumberSequence.new(0.4, 0)
	sparkles.Parent = portal

	-- 출발 대기 발판 (포탈 바로 앞)
	local pad = B:part(Vector3.new(14, 0.2, 10), nil, at(Vector3.new(0, 0.1, 9), {
		Name = `Pad_{info.id}`,
		Color = info.color,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
	}))

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(360, 90)
	billboard.StudsOffset = Vector3.new(0, 7, 0)
	billboard.MaxDistance = 120
	billboard.Parent = pad
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.fromScale(1, 1)
	statusLabel.BackgroundColor3 = Color3.fromRGB(28, 22, 16)
	statusLabel.BackgroundTransparency = 0.25
	statusLabel.TextColor3 = Color3.fromRGB(245, 235, 215)
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextScaled = true
	statusLabel.Text = ""
	statusLabel.Parent = billboard
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = statusLabel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = statusLabel

	return { game = info, pad = pad, statusLabel = statusLabel }
end

local function buildComingSoon(B, frame: CFrame)
	arch(B, frame, "🚧 준비 중", Color3.fromRGB(200, 200, 200))
	-- 아치 안을 막는 나무 판자 (비스듬하게)
	for _, plank in { { y = 6, angle = 15 }, { y = 9, angle = -12 } } do
		B:part(Vector3.new(11, 1, 0.5), nil, {
			CFrame = frame * CFrame.new(0, plank.y, 0) * CFrame.Angles(0, 0, math.rad(plank.angle)),
			Color = Color3.fromRGB(150, 110, 70),
			Material = Enum.Material.WoodPlanks,
		})
	end
end

function LobbyBuilder.build(): { Portal }
	local old = workspace:FindFirstChild("Lobby")
	if old then
		old:Destroy()
	end
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") then
			descendant:Destroy()
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	folder.Parent = workspace
	local B = Build.new(folder, Vector3.zero)

	-- 광장 바닥과 시작 지점
	B:part(Vector3.new(100, 1, 100), Vector3.new(0, 0.5, 0), { Color = STONE, Material = Enum.Material.Cobblestone })
	B:part(Vector3.new(8, 1, 8), Vector3.new(0, 1.5, 34), {
		ClassName = "SpawnLocation",
		Neutral = true,
		Duration = 0,
		Color = Color3.fromRGB(120, 170, 220),
		Material = Enum.Material.SmoothPlastic,
	})

	-- 가운데 분수와 고결게임즈 간판
	B:part(Vector3.new(1, 14, 14), nil, {
		Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = STONE,
		Material = Enum.Material.Marble,
	})
	B:part(Vector3.new(0.4, 12, 12), nil, {
		Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(80, 160, 220),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
	})
	B:part(Vector3.new(1.5, 9, 1.5), Vector3.new(0, 6, 0), { Color = STONE, Material = Enum.Material.Marble })
	local sign = B:part(Vector3.new(14, 5, 1), Vector3.new(0, 13, 0), {
		Color = Color3.fromRGB(40, 32, 26),
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		Build.surfaceText(sign, face, "고결게임즈", {
			Font = Enum.Font.GothamBlack,
			TextColor3 = GOLD,
		})
	end

	-- 포탈들
	local portals: { Portal } = {}
	for index, position in SLOTS do
		local info = Places.Games[index]
		if info then
			table.insert(portals, buildPortal(B, slotFrame(position), info))
		else
			buildComingSoon(B, slotFrame(position))
		end
	end
	if #Places.Games > #SLOTS then
		warn(`포탈 자리는 {#SLOTS}개뿐이라 게임 {#Places.Games - #SLOTS}개는 광장에 표시되지 않았어요. LobbyBuilder의 SLOTS를 늘려 주세요.`)
	end

	-- 장식: 가로등, 벤치
	for _, position in { { -20, -20 }, { 20, -20 }, { -20, 20 }, { 20, 20 } } do
		lampPost(B, position[1], position[2])
	end
	bench(B, -12, 22, 0)
	bench(B, 12, 22, 0)

	return portals
end

return LobbyBuilder
