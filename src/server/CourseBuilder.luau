-- 오비 코스를 코드로 만들어 줍니다.
-- 코스는 +Z 방향으로 쭉 이어지고, 구간마다 체크포인트가 있어요.

local RunService = game:GetService("RunService")

local CourseBuilder = {}

local HEIGHT = 30 -- 코스 높이 (아래 바닥은 용암)

local COLORS = {
	platform = Color3.fromRGB(110, 170, 255),
	checkpoint = Color3.fromRGB(80, 220, 120),
	kill = Color3.fromRGB(255, 50, 50),
	moving = Color3.fromRGB(255, 200, 70),
	spinner = Color3.fromRGB(180, 130, 255),
	finish = Color3.fromRGB(255, 215, 0),
	lava = Color3.fromRGB(255, 90, 20),
}

local function makePart(parent: Instance, props: { [string]: any }, className: string?): BasePart
	local part = Instance.new(className or "Part") :: BasePart
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

local function addLabel(part: BasePart, text: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(220, 50)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.MaxDistance = 100
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Parent = billboard
end

export type Course = {
	checkpoints: { BasePart },
	killParts: { BasePart },
	finish: BasePart,
}

function CourseBuilder.build(): Course
	-- 이전 코스 지우기
	local old = workspace:FindFirstChild("Course")
	if old then
		old:Destroy()
	end

	-- 템플릿에 들어 있는 기본 스폰 지점은 지워요 (용암 위에서 태어나면 안 되니까)
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") then
			descendant:Destroy()
		end
	end

	local folder = Instance.new("Folder")
	folder.Name = "Course"
	folder.Parent = workspace

	local checkpoints: { BasePart } = {}
	local killParts: { BasePart } = {}
	local movers: { (t: number) -> () } = {}

	local z = 0 -- 지금까지 만든 코스의 끝 위치

	local function addCheckpoint(y: number)
		local index = #checkpoints + 1
		local props = {
			Name = "Checkpoint" .. index,
			Size = Vector3.new(14, 1, 14),
			Position = Vector3.new(0, y, z + 7),
			Color = COLORS.checkpoint,
			Material = Enum.Material.Neon,
		}
		local part
		if index == 1 then
			-- 첫 체크포인트는 스폰 지점
			part = makePart(folder, props, "SpawnLocation") :: SpawnLocation
			part.Neutral = true
			part.Duration = 0
		else
			part = makePart(folder, props)
		end
		addLabel(part, if index == 1 then "출발!" else `체크포인트 {index}`)
		table.insert(checkpoints, part)
		z += 14
	end

	local function addKill(props: { [string]: any }): BasePart
		props.Color = COLORS.kill
		props.Material = Enum.Material.Neon
		local part = makePart(folder, props)
		table.insert(killParts, part)
		return part
	end

	---------------------------------------------------------------
	-- 스테이지 1: 출발
	addCheckpoint(HEIGHT)

	-- 구간 1: 점프 발판
	for _ = 1, 5 do
		z += 6
		makePart(folder, {
			Size = Vector3.new(6, 1, 6),
			Position = Vector3.new(0, HEIGHT, z + 3),
			Color = COLORS.platform,
		})
		z += 6
	end
	z += 6
	addCheckpoint(HEIGHT)

	---------------------------------------------------------------
	-- 구간 2: 빨간 막대 넘기 (닿으면 죽어요)
	local walkLength = 60
	makePart(folder, {
		Size = Vector3.new(8, 1, walkLength),
		Position = Vector3.new(0, HEIGHT, z + walkLength / 2),
		Color = COLORS.platform,
	})
	for i = 1, 5 do
		addKill({
			Size = Vector3.new(8, 1.5, 1),
			Position = Vector3.new(0, HEIGHT + 1.25, z + i * 10),
		})
	end
	z += walkLength
	addCheckpoint(HEIGHT)

	---------------------------------------------------------------
	-- 구간 3: 좌우로 움직이는 발판
	for i = 1, 4 do
		z += 4
		local base = Vector3.new(0, HEIGHT, z + 3.5)
		local part = makePart(folder, {
			Size = Vector3.new(7, 1, 7),
			Position = base,
			Color = COLORS.moving,
		})
		local speed, amplitude, phase = 1.5, 10, i * 1.3
		table.insert(movers, function(t)
			local x = math.sin(t * speed + phase) * amplitude
			local velocity = math.cos(t * speed + phase) * amplitude * speed
			part.CFrame = CFrame.new(base + Vector3.new(x, 0, 0))
			-- 속도를 같이 설정해야 위에 탄 플레이어가 함께 움직여요
			part.AssemblyLinearVelocity = Vector3.new(velocity, 0, 0)
		end)
		z += 7
	end
	z += 4
	addCheckpoint(HEIGHT)

	---------------------------------------------------------------
	-- 구간 4: 회전하는 막대
	local radius = 16
	local center = Vector3.new(0, HEIGHT, z + radius)
	makePart(folder, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, radius * 2, radius * 2),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Color = COLORS.spinner,
	})
	local bar = addKill({
		Size = Vector3.new(radius * 2 - 2, 1.5, 1.2),
		Position = center + Vector3.new(0, 1.25, 0),
	})
	local spinSpeed = 1.3
	table.insert(movers, function(t)
		bar.CFrame = CFrame.new(center + Vector3.new(0, 1.25, 0)) * CFrame.Angles(0, t * spinSpeed, 0)
	end)
	z += radius * 2 + 4
	addCheckpoint(HEIGHT)

	---------------------------------------------------------------
	-- 구간 5: 지그재그로 올라가는 계단
	local y = HEIGHT
	for i = 1, 6 do
		y += 3
		z += 4
		makePart(folder, {
			Size = Vector3.new(5, 1, 5),
			Position = Vector3.new(if i % 2 == 0 then 4 else -4, y, z + 2.5),
			Color = COLORS.platform,
		})
		z += 5
	end
	z += 5

	-- 골인 지점
	local finish = makePart(folder, {
		Name = "Finish",
		Size = Vector3.new(16, 1, 16),
		Position = Vector3.new(0, y, z + 8),
		Color = COLORS.finish,
		Material = Enum.Material.Neon,
	})
	addLabel(finish, "🏆 골인!")

	---------------------------------------------------------------
	-- 바닥(Baseplate)을 용암으로
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Color = COLORS.lava
		baseplate.Material = Enum.Material.Neon
		table.insert(killParts, baseplate)
	end

	-- 움직이는 것들을 매 프레임 갱신
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for _, update in movers do
			update(t)
		end
	end)

	return {
		checkpoints = checkpoints,
		killParts = killParts,
		finish = finish,
	}
end

return CourseBuilder
