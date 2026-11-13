-- 맵을 코드로 짓기 위한 도구 모음
-- Build.new(부모, 오프셋)으로 만든 빌더는 모든 위치에 오프셋을 더해 줘요.
-- 그래서 같은 코드로 "현재" 탑과 "과거" 탑을 다른 위치에 지을 수 있어요.

local Build = {}
Build.__index = Build

export type Door = { center: number, width: number, height: number }

function Build.new(parent: Instance, offset: Vector3)
	return setmetatable({ parent = parent, offset = offset }, Build)
end

-- 상대 좌표 CFrame → 실제 월드 CFrame
function Build:cf(relative: CFrame): CFrame
	return CFrame.new(self.offset) * relative
end

-- 파트 하나 만들기. props.CFrame을 주면 회전된 파트도 만들 수 있어요 (상대 좌표).
function Build:part(size: Vector3, position: Vector3?, props: { [string]: any }?): BasePart
	local options = props or {}
	local part = Instance.new(options.ClassName or "Part") :: BasePart
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.fromRGB(150, 150, 150)
	part.Size = size
	part.CFrame = self:cf(options.CFrame or CFrame.new(position :: Vector3))
	for key, value in options do
		if key ~= "ClassName" and key ~= "CFrame" and key ~= "Parent" then
			(part :: any)[key] = value
		end
	end
	part.Parent = options.Parent or self.parent
	return part
end

-- 문 구멍이 뚫린 벽 만들기
-- axis "X": z = fixed 위치에서 X 방향으로 뻗은 벽 / axis "Z": x = fixed 위치에서 Z 방향으로 뻗은 벽
function Build:wall(
	axis: "X" | "Z",
	fixed: number,
	from: number,
	to: number,
	y0: number,
	height: number,
	doors: { Door }?,
	props: { [string]: any }?
)
	local function segment(a: number, b: number, yBottom: number, yTop: number)
		if b - a <= 0.01 or yTop - yBottom <= 0.01 then
			return
		end
		local length, h = b - a, yTop - yBottom
		local mid = (a + b) / 2
		if axis == "Z" then
			self:part(Vector3.new(1, h, length), Vector3.new(fixed, yBottom + h / 2, mid), props)
		else
			self:part(Vector3.new(length, h, 1), Vector3.new(mid, yBottom + h / 2, fixed), props)
		end
	end

	local sorted = table.clone(doors or {})
	table.sort(sorted, function(a, b)
		return a.center < b.center
	end)

	local cursor = from
	for _, door in sorted do
		local a, b = door.center - door.width / 2, door.center + door.width / 2
		segment(cursor, a, y0, y0 + height) -- 문 왼쪽 벽
		segment(a, b, y0 + door.height, y0 + height) -- 문 위쪽 벽
		cursor = b
	end
	segment(cursor, to, y0, y0 + height)
end

-- 톱니바퀴 모델 (Z축을 향해 서 있는 원판 + 톱니)
-- 반환값: 모델, 회전 기준이 되는 월드 CFrame
function Build:gear(position: Vector3, radius: number, color: Color3, material: Enum.Material?): (Model, CFrame)
	local model = Instance.new("Model")
	model.Name = "Gear"
	local thickness = 0.6
	local props = { Color = color, Material = material or Enum.Material.Metal, Parent = model }

	local disk = table.clone(props)
	disk.Shape = Enum.PartType.Cylinder
	disk.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(90), 0)
	self:part(Vector3.new(thickness, radius * 2, radius * 2), nil, disk)

	local teeth = math.max(6, math.floor(radius * 4))
	for i = 1, teeth do
		local tooth = table.clone(props)
		tooth.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, (i / teeth) * math.pi * 2) * CFrame.new(0, radius + 0.3, 0)
		self:part(Vector3.new(0.8, 1, thickness), nil, tooth)
	end

	local base = self:cf(CFrame.new(position))
	model.WorldPivot = base
	model.Parent = self.parent
	return model, base
end

-- 파트 한 면에 시계판 그리기. 반환값: setTime(시, 분) 함수
function Build.clockFace(part: BasePart, face: Enum.NormalId): (number, number) -> ()
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(400, 400)
	gui.LightInfluence = 0.6
	gui.Parent = part

	local dial = Instance.new("Frame")
	dial.AnchorPoint = Vector2.new(0.5, 0.5)
	dial.Position = UDim2.fromScale(0.5, 0.5)
	dial.Size = UDim2.fromScale(0.94, 0.94)
	dial.BackgroundColor3 = Color3.fromRGB(240, 228, 200)
	dial.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = dial
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 12
	stroke.Color = Color3.fromRGB(150, 110, 50)
	stroke.Parent = dial

	for hour = 1, 12 do
		local angle = hour / 12 * math.pi * 2
		local number = Instance.new("TextLabel")
		number.AnchorPoint = Vector2.new(0.5, 0.5)
		number.Position = UDim2.fromScale(0.5 + 0.39 * math.sin(angle), 0.5 - 0.39 * math.cos(angle))
		number.Size = UDim2.fromScale(0.14, 0.14)
		number.BackgroundTransparency = 1
		number.Text = tostring(hour)
		number.TextScaled = true
		number.Font = Enum.Font.Antique
		number.TextColor3 = Color3.fromRGB(40, 30, 20)
		number.Parent = dial
	end

	-- GUI는 자기 중심을 기준으로 회전하므로, 정사각형 컨테이너를 돌리고 그 위쪽 절반에 바늘을 그려요
	local function hand(width: number, length: number): Frame
		local pivot = Instance.new("Frame")
		pivot.AnchorPoint = Vector2.new(0.5, 0.5)
		pivot.Position = UDim2.fromScale(0.5, 0.5)
		pivot.Size = UDim2.fromScale(length * 2, length * 2)
		pivot.BackgroundTransparency = 1
		pivot.Parent = dial

		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 1)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromScale(width / (length * 2), 0.5)
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = Color3.fromRGB(30, 25, 20)
		bar.Parent = pivot
		return pivot
	end

	local hourHand = hand(0.045, 0.25)
	local minuteHand = hand(0.025, 0.38)

	local center = Instance.new("Frame")
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	center.Position = UDim2.fromScale(0.5, 0.5)
	center.Size = UDim2.fromScale(0.07, 0.07)
	center.BackgroundColor3 = Color3.fromRGB(150, 110, 50)
	center.Parent = dial
	local centerCorner = Instance.new("UICorner")
	centerCorner.CornerRadius = UDim.new(0.5, 0)
	centerCorner.Parent = center

	return function(hour: number, minute: number)
		hourHand.Rotation = ((hour % 12) + minute / 60) * 30
		minuteHand.Rotation = minute * 6
	end
end

-- 파트 한 면에 글씨 쓰기 (칠판 등)
function Build.surfaceText(part: BasePart, face: Enum.NormalId, text: string, props: { [string]: any }?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0.6
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.Fantasy
	label.TextColor3 = Color3.fromRGB(235, 235, 220)
	for key, value in props or {} do
		(label :: any)[key] = value
	end
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.1, 0)
	padding.PaddingBottom = UDim.new(0.1, 0)
	padding.Parent = label
	label.Parent = gui
	return label
end

-- 방 조명
function Build:lamp(position: Vector3, color: Color3, brightness: number)
	local lamp = self:part(Vector3.new(2, 0.5, 2), position, {
		Material = Enum.Material.Neon,
		Color = color,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = 45
	light.Shadows = true
	light.Parent = lamp
	return lamp
end

return Build
