-- 🍪 탕비실 간식 테이블
-- 매일 아침 접시에 담긴 과자를 테이블 위에 다시 놓아요. [E] 가져가기를 하면 테이블에서 사라져요.
-- 간식마다 여러 부품을 조합해서 모양을 만들어요 (사탕 껍질, 쿠키 초코칩, 도넛 스프링클 등).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)

local Snacks = {}

local WHITE = Color3.fromRGB(250, 250, 248)
local VERTICAL = CFrame.Angles(0, 0, math.rad(90)) -- 원기둥을 세워서(납작한 원판으로) 놓기

-- 부품 하나 만들기 (모델 안, base 기준 상대 위치)
local function piece(model: Model, base: CFrame, size: Vector3, offset: CFrame, color: Color3, props: { [string]: any }?): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = base * offset
	for key, value in props or {} do
		(part :: any)[key] = value
	end
	part.Parent = model
	return part
end

local function disc(model: Model, base: CFrame, diameter: number, thickness: number, y: number, color: Color3, props: { [string]: any }?): BasePart
	local options = props or {}
	options.Shape = Enum.PartType.Cylinder
	return piece(model, base, Vector3.new(thickness, diameter, diameter), CFrame.new(0, y, 0) * VERTICAL, color, options)
end

local function ball(model: Model, base: CFrame, diameter: number, offset: Vector3, color: Color3): BasePart
	return piece(model, base, Vector3.new(diameter, diameter, diameter), CFrame.new(offset), color, { Shape = Enum.PartType.Ball })
end

-- 간식별 모양 (base = 접시 윗면 가운데). 반환값: 상호작용 표시를 붙일 부품
local BUILDERS: { [string]: (Model, CFrame, SalaryConfig.SnackInfo) -> BasePart } = {
	candy = function(model, base, snack)
		local body = ball(model, base, 0.6, Vector3.new(0, 0.3, 0), snack.color)
		-- 양쪽으로 비틀린 포장지
		for _, side in { -1, 1 } do
			piece(model, base, Vector3.new(0.3, 0.35, 0.35), CFrame.new(0.42 * side, 0.3, 0) * CFrame.Angles(math.rad(45), 0, 0), Color3.fromRGB(255, 220, 235))
		end
		ball(model, base, 0.18, Vector3.new(0.12, 0.5, -0.15), WHITE) -- 반짝임
		return body
	end,
	cookie = function(model, base, snack)
		local body = disc(model, base, 1, 0.22, 0.11, snack.color)
		for _, offset in { Vector3.new(0.2, 0.24, 0.1), Vector3.new(-0.22, 0.24, -0.05), Vector3.new(0.02, 0.24, -0.28), Vector3.new(-0.05, 0.24, 0.28) } do
			ball(model, base, 0.14, offset, Color3.fromRGB(70, 40, 25)) -- 초코칩
		end
		return body
	end,
	chocobar = function(model, base, snack)
		local wrapper = piece(model, base, Vector3.new(1.3, 0.3, 0.55), CFrame.new(-0.15, 0.15, 0), Color3.fromRGB(200, 40, 50))
		piece(model, base, Vector3.new(1.31, 0.08, 0.56), CFrame.new(-0.15, 0.2, 0), Color3.fromRGB(240, 210, 90)) -- 금색 띠
		piece(model, base, Vector3.new(0.35, 0.28, 0.5), CFrame.new(0.65, 0.14, 0), snack.color) -- 뜯어서 보이는 초콜릿
		piece(model, base, Vector3.new(0.06, 0.3, 0.5), CFrame.new(0.55, 0.15, 0), Color3.fromRGB(150, 85, 45)) -- 초콜릿 칸
		return wrapper
	end,
	donut = function(model, base, snack)
		local body = disc(model, base, 1.1, 0.4, 0.2, Color3.fromRGB(215, 160, 95))
		disc(model, base, 1, 0.08, 0.42, snack.color) -- 분홍 아이싱
		disc(model, base, 0.32, 0.1, 0.45, Color3.fromRGB(120, 75, 40)) -- 가운데 구멍
		local sprinkleColors = { Color3.fromRGB(80, 170, 255), Color3.fromRGB(255, 230, 80), Color3.fromRGB(120, 220, 120), WHITE }
		for i = 1, 8 do
			local angle = i / 8 * math.pi * 2
			piece(model, base, Vector3.new(0.14, 0.04, 0.05), CFrame.new(math.cos(angle) * 0.33, 0.47, math.sin(angle) * 0.33) * CFrame.Angles(0, angle * 1.7, 0), sprinkleColors[(i % #sprinkleColors) + 1])
		end
		return body
	end,
	cake = function(model, base, snack)
		local sponge = piece(model, base, Vector3.new(1, 0.3, 1.2), CFrame.new(0, 0.15, 0), Color3.fromRGB(245, 215, 140))
		piece(model, base, Vector3.new(1, 0.1, 1.2), CFrame.new(0, 0.35, 0), WHITE) -- 크림층
		piece(model, base, Vector3.new(1, 0.25, 1.2), CFrame.new(0, 0.52, 0), Color3.fromRGB(245, 215, 140))
		piece(model, base, Vector3.new(1.02, 0.12, 1.22), CFrame.new(0, 0.7, 0), snack.color) -- 윗면 크림
		ball(model, base, 0.32, Vector3.new(0.1, 0.9, 0.15), Color3.fromRGB(220, 40, 50)) -- 딸기
		piece(model, base, Vector3.new(0.2, 0.05, 0.12), CFrame.new(0.1, 1.06, 0.15), Color3.fromRGB(70, 160, 70)) -- 꼭지
		return sponge
	end,
}

-- onTake(player, snack): 가져갈 수 있으면 true를 돌려줘요 (Employees가 판단)
function Snacks.start(office, onTake: (Player, SalaryConfig.SnackInfo) -> boolean)
	local folder = Instance.new("Folder")
	folder.Name = "Snacks"
	folder.Parent = office.folder

	local function placeSnack(snack: SalaryConfig.SnackInfo, spot: Vector3)
		local model = Instance.new("Model")
		model.Name = snack.id
		local base = CFrame.new(spot + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, math.rad(math.random(0, 359)), 0)

		disc(model, CFrame.new(spot), 1.4, 0.1, 0.05, WHITE) -- 접시
		local builder = BUILDERS[snack.id]
		local main = if builder then builder(model, base, snack) else piece(model, base, snack.size, CFrame.new(0, snack.size.Y / 2, 0), snack.color)

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(34, 34)
		billboard.StudsOffset = Vector3.new(0, 1.3, 0)
		billboard.MaxDistance = 24
		billboard.Parent = main
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Text = snack.emoji
		label.Parent = billboard

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "가져가기"
		prompt.ObjectText = `{snack.emoji} {snack.name} (+{snack.bonus}원, {snack.seconds}초)`
		prompt.MaxActivationDistance = 6
		prompt.RequiresLineOfSight = false
		prompt.Parent = main
		prompt.Triggered:Connect(function(player)
			if model.Parent and onTake(player, snack) then
				model:Destroy()
			end
		end)

		model.Parent = folder
	end

	local api = {}

	-- 테이블을 다시 채워요 (하루 시작할 때)
	function api.restock()
		folder:ClearAllChildren()
		local index = 0
		for _, snack in SalaryConfig.Snacks do
			for _ = 1, snack.count do
				index += 1
				local spot = office.snackSpots[index]
				if spot then
					placeSnack(snack, spot)
				end
			end
		end
	end

	api.restock()
	return api
end

return Snacks
