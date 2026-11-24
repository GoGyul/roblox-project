-- NPC 사람 만들기 (김부장, 동료 직원)
-- 로블록스 기본 아바타 몸에 색만 입혀서 만들고, 머리 위에 상태 이모지와 말풍선을 달아요.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local Npc = {}

---------------------------------------------------------------------------
-- 🚀 NPC가 하늘로 날아가지 않게
--   원인: NPC가 플레이어(누운 의자·해먹 위 등)나 다른 NPC와 몸이 겹치면
--         물리 엔진이 서로를 밀어내면서 위로 튕겨 올려요.
--   1) NPC는 플레이어·다른 NPC와 부딪히지 않아요 (통과해서 지나가요)
--   2) 지킴이: 위로 튀는 속도는 없애고, 바닥에서 너무 떠 있으면 바닥으로 내려 줘요
---------------------------------------------------------------------------
local NPC_GROUP = "SalaryNpc"
local CHARACTER_GROUP = "SalaryCharacter"
local FLOAT_LIMIT = 7 -- 바닥에서 이만큼(스터드) 넘게 떠 있으면 내려 줘요
local STAND_HEIGHT = 3 -- 서 있을 때 몸통 중심의 바닥 위 높이

pcall(function()
	PhysicsService:RegisterCollisionGroup(NPC_GROUP)
	PhysicsService:RegisterCollisionGroup(CHARACTER_GROUP)
end)
PhysicsService:CollisionGroupSetCollidable(NPC_GROUP, CHARACTER_GROUP, false)
PhysicsService:CollisionGroupSetCollidable(NPC_GROUP, NPC_GROUP, false)

-- 🪑 NPC만 부딪히는 투명 천장 (책상·탁자 위로 못 올라오게): 플레이어·고양이·다른 물건과는 안 부딪혀요
local NPC_BLOCK_GROUP = "SalaryNpcBlock"
pcall(function()
	PhysicsService:RegisterCollisionGroup(NPC_BLOCK_GROUP)
end)
PhysicsService:CollisionGroupSetCollidable(NPC_BLOCK_GROUP, "Default", false)
PhysicsService:CollisionGroupSetCollidable(NPC_BLOCK_GROUP, CHARACTER_GROUP, false)
PhysicsService:CollisionGroupSetCollidable(NPC_BLOCK_GROUP, NPC_BLOCK_GROUP, false)
PhysicsService:CollisionGroupSetCollidable(NPC_BLOCK_GROUP, NPC_GROUP, true)

-- folder 안의 낮은 가구(바닥 높이 floorLevels 기준 윗면이 1.5~5.5칸) 위에 NPC 전용 투명 천장을 씌워요
--   로블록스 캐릭터는 낮은 턱을 저절로 올라서는데, 부장님·동료가 끼었을 때 책상 위로 올라가 버려서 막아요
function Npc.guardFurniture(folder: Instance, floorLevels: { number })
	local guards = Instance.new("Folder")
	guards.Name = "NpcFurnitureGuards"
	guards.Parent = folder
	local count = 0
	for _, part in folder:GetDescendants() do
		if not part:IsA("BasePart") or part:IsA("Seat") or part:IsA("VehicleSeat") or part:IsDescendantOf(guards) then
			continue
		end
		if not part.CanCollide or part.Transparency >= 1 or part.Parent == nil then
			continue
		end
		if part.CFrame.UpVector.Y < 0.99 then
			continue -- (눕혀 놓은 원기둥 같은 건 건너뛰어요)
		end
		local size = part.Size
		if size.Y < 0.5 or size.Y > 6 or size.X > 40 or size.Z > 40 then
			continue -- 바닥·벽·카펫은 빼고
		end
		local top = part.Position.Y + size.Y / 2
		local onFloor = false
		for _, floorY in floorLevels do
			local height = top - floorY
			if height >= 1.5 and height <= 5.5 then
				onFloor = true
			end
		end
		if not onFloor then
			continue
		end
		local guard = Instance.new("Part")
		guard.Name = "NpcGuard"
		guard.Size = Vector3.new(size.X + 0.4, 6, size.Z + 0.4)
		guard.CFrame = part.CFrame * CFrame.new(0, size.Y / 2 + 3, 0)
		guard.Anchored = true
		guard.Transparency = 1
		guard.CanQuery = false
		guard.CanTouch = false
		guard.CastShadow = false
		guard.CollisionGroup = NPC_BLOCK_GROUP
		guard.Parent = guards
		count += 1
	end
	return count
end

local function setGroup(instance: Instance, group: string)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = group
	end
end

-- 플레이어 캐릭터는 CHARACTER_GROUP으로
local function watchCharacter(character: Model)
	for _, part in character:GetDescendants() do
		setGroup(part, CHARACTER_GROUP)
	end
	character.DescendantAdded:Connect(function(part)
		setGroup(part, CHARACTER_GROUP)
	end)
end
local function watchPlayer(player: Player)
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end
Players.PlayerAdded:Connect(watchPlayer)
for _, player in Players:GetPlayers() do
	watchPlayer(player)
end

local tracked: { [Model]: boolean } = {}
local groundParams = RaycastParams.new()
groundParams.CollisionGroup = NPC_GROUP -- (플레이어·NPC 몸은 바닥으로 안 쳐요)
groundParams.RespectCanCollide = true

task.spawn(function()
	while true do
		task.wait(0.25)
		for model in tracked do
			if not model.Parent then
				tracked[model] = nil
				continue
			end
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if not root or not humanoid or root.Anchored or humanoid.SeatPart then
				continue
			end
			local velocity = root.AssemblyLinearVelocity
			if velocity.Y > 8 then
				root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
				root.AssemblyAngularVelocity = Vector3.zero
			end
			groundParams.FilterDescendantsInstances = { model }
			local hit = workspace:Raycast(root.Position, Vector3.new(0, -500, 0), groundParams)
			if hit and root.Position.Y - hit.Position.Y > FLOAT_LIMIT then
				local look = root.CFrame.LookVector
				local flat = Vector3.new(look.X, 0, look.Z)
				if flat.Magnitude < 0.1 then
					flat = Vector3.new(0, 0, -1)
				end
				local landing = Vector3.new(root.Position.X, hit.Position.Y + STAND_HEIGHT, root.Position.Z)
				model:PivotTo(CFrame.lookAt(landing, landing + flat))
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end
end)

export type Look = {
	skin: Color3,
	shirt: Color3,
	pants: Color3,
}

-- 👔 직장인 옷차림: 색만 칠한 기본 몸에 머리카락·셔츠 깃·넥타이·사원증·벨트·구두를 붙여요.
--   이름으로 정해지는 값이라 같은 사람은 늘 같은 모습이에요. 모두 장식이라 부딪히지 않아요.
local HAIR_COLORS = { Color3.fromRGB(34, 30, 28), Color3.fromRGB(58, 44, 36), Color3.fromRGB(24, 24, 28), Color3.fromRGB(88, 66, 48), Color3.fromRGB(120, 120, 124) }
local TIE_COLORS = { Color3.fromRGB(150, 40, 46), Color3.fromRGB(44, 62, 110), Color3.fromRGB(60, 96, 76), Color3.fromRGB(70, 70, 78) }

local function dress(model: Model, name: string, look: Look)
	local seed = 0
	for i = 1, #name do
		seed += string.byte(name, i) * i
	end
	local function attach(bodyName: string, size: Vector3, offset: CFrame, color: Color3, round: boolean?): Part?
		local body = model:FindFirstChild(bodyName) :: BasePart?
		if not body then
			return nil
		end
		local part = Instance.new("Part")
		part.Name = "Outfit"
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CollisionGroup = NPC_GROUP
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if round then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = part
		end
		part.CFrame = body.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
		return part
	end
	local boss = string.find(name, "부장", 1, true) ~= nil
	-- 머리카락 (윗머리 + 뒷머리). 부장님은 희끗한 머리예요.
	local hair = if boss then HAIR_COLORS[5] else HAIR_COLORS[seed % 4 + 1]
	attach("Head", Vector3.new(1.34, 0.8, 1.34), CFrame.new(0, 0.36, 0.04), hair, true)
	attach("Head", Vector3.new(1.26, 0.9, 0.5), CFrame.new(0, 0.05, 0.42), hair, true)
	if seed % 3 == 0 and not boss then
		attach("Head", Vector3.new(1.3, 0.5, 0.5), CFrame.new(0, 0.42, -0.42), hair, true) -- 앞머리
	end
	-- 셔츠 깃 · 넥타이 (부장님과 절반쯤의 직원) · 사원증
	local white = Color3.fromRGB(240, 240, 238)
	attach("UpperTorso", Vector3.new(1.1, 0.2, 0.7), CFrame.new(0, 0.72, -0.02), white)
	if boss or seed % 2 == 0 then
		local tie = TIE_COLORS[seed % #TIE_COLORS + 1]
		attach("UpperTorso", Vector3.new(0.26, 0.24, 0.1), CFrame.new(0, 0.56, -0.53), tie)
		attach("UpperTorso", Vector3.new(0.22, 1.0, 0.08), CFrame.new(0, -0.02, -0.54), tie)
	else
		attach("UpperTorso", Vector3.new(0.05, 0.9, 0.05), CFrame.new(0.14, 0.2, -0.53) * CFrame.Angles(0, 0, math.rad(8)), Color3.fromRGB(40, 90, 160)) -- 사원증 줄
		attach("UpperTorso", Vector3.new(0.05, 0.9, 0.05), CFrame.new(-0.14, 0.2, -0.53) * CFrame.Angles(0, 0, math.rad(-8)), Color3.fromRGB(40, 90, 160))
		attach("UpperTorso", Vector3.new(0.36, 0.46, 0.06), CFrame.new(0, -0.42, -0.55), white)
	end
	-- 벨트 · 구두
	attach("LowerTorso", Vector3.new(2.04, 0.16, 1.04), CFrame.new(0, 0.16, 0), Color3.fromRGB(30, 28, 28))
	for _, foot in { "LeftFoot", "RightFoot" } do
		attach(foot, Vector3.new(1.04, 0.34, 1.2), CFrame.new(0, 0, -0.08), Color3.fromRGB(34, 30, 28))
	end
	local _ = look
end

function Npc.create(name: string, look: Look, parent: Instance): Model
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = look.skin
	description.TorsoColor = look.shirt
	description.LeftArmColor = look.shirt
	description.RightArmColor = look.shirt
	description.LeftLegColor = look.pants
	description.RightLegColor = look.pants

	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = name
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	-- 애니메이션이 없는 NPC는 넘어지면 잘 못 일어나요 → 넘어지는 상태를 꺼 둬요
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	-- NPC는 점프를 못 해요 (부장님·동료·이과장·감사팀·가게 사장님 모두)
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	-- 걸어 다니다가 빈 의자(플레이어 자리 등)에 닿아도 저절로 앉지 않게 해요.
	-- 앉힐 때는 Npc.sit이 잠깐 켜 줘요.
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
	-- 팔다리가 의자·책상에 부딪혀 덜덜 떨지 않게, 몸통 중심(HumanoidRootPart)만 충돌해요
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = NPC_GROUP -- 🚀 플레이어·다른 NPC와 부딪혀 튕기지 않게
			if part.Name ~= "HumanoidRootPart" then
				part.CanCollide = false
			end
		end
	end
	tracked[model] = true
	pcall(dress, model, name, look) -- 👔 옷차림 (실패해도 NPC는 그대로 만들어져요)

	-- 머리 위 표시: 이름 / 상태 이모지 / 말풍선
	local head = model:WaitForChild("Head") :: BasePart
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Bubble"
	billboard.Size = UDim2.fromOffset(190, 78) -- (예전 260×110: 너무 커서 줄였어요)
	billboard.StudsOffset = Vector3.new(0, 2.8, 0)
	billboard.MaxDistance = 60
	billboard.Parent = head

	local function label(labelName: string, y: number, height: number, textSize: number): TextLabel
		local text = Instance.new("TextLabel")
		text.Name = labelName
		text.AnchorPoint = Vector2.new(0.5, 0)
		text.Position = UDim2.new(0.5, 0, 0, y)
		text.Size = UDim2.new(1, 0, 0, height)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBold
		text.TextSize = textSize
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0.3
		text.TextWrapped = true
		text.Text = ""
		text.Parent = billboard
		return text
	end
	local speech = label("Speech", 0, 32, 13)
	speech.BackgroundTransparency = 0.1
	speech.BackgroundColor3 = Color3.new(1, 1, 1)
	speech.TextColor3 = Color3.fromRGB(30, 30, 30)
	speech.TextStrokeTransparency = 1
	speech.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = speech
	label("Status", 34, 26, 21)
	label("NameTag", 60, 16, 12).Text = name

	model.Parent = parent
	return model
end

-- 머리 위 이모지 바꾸기
function Npc.setStatus(model: Model, emoji: string)
	local bubble = model:FindFirstChild("Bubble", true)
	if bubble then
		(bubble :: any).Status.Text = emoji
	end
end

-- 말풍선 띄우기 (seconds 뒤에 사라짐)
function Npc.say(model: Model, text: string, seconds: number?)
	local bubble = model:FindFirstChild("Bubble", true)
	if not bubble then
		return
	end
	local speech = (bubble :: any).Speech :: TextLabel
	speech.Text = text
	speech.Visible = true
	local myText = text
	task.delay(seconds or 3, function()
		if speech.Text == myText then
			speech.Visible = false
		end
	end)
end

-- 기울어졌으면 똑바로 세우기 (바라보는 방향은 유지)
function Npc.standUpright(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or root.CFrame.UpVector.Y > 0.8 then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.SeatPart then
		return -- 앉아 있을 땐 건드리지 않아요 (의자까지 같이 돌아가 버려요)
	end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(0, 0, -1)
	end
	local position = root.Position + Vector3.new(0, 1, 0)
	model:PivotTo(CFrame.lookAt(position, position + flat))
	root.AssemblyAngularVelocity = Vector3.zero
end

-- 🦵 앉은 다리 자세 (서버에서 한 번만 설정해요 — 화면 쪽에서 건드리면 서버와 싸워서 다리가 떨려요)
local LEG_ANGLES = { RightUpperLeg = 90, LeftUpperLeg = 90, RightLowerLeg = -90, LeftLowerLeg = -90 }
local legBases: { [Instance]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

-- bodyPart를 움직이는 관절: Motor6D면 C0, AnimationConstraint면 부모 쪽 Attachment
local function legJoint(model: Model, bodyPart: BasePart): (Instance?, string?)
	for _, item in model:GetDescendants() do
		if item:IsA("Motor6D") and item.Part1 == bodyPart then
			return item, "C0"
		end
	end
	for _, item in model:GetDescendants() do
		if item:IsA("AnimationConstraint") and item.Attachment0 and item.Attachment1 then
			if item.Attachment1.Parent == bodyPart then
				return item.Attachment0, "CFrame"
			elseif item.Attachment0.Parent == bodyPart then
				return item.Attachment1, "CFrame"
			end
		end
	end
	return nil, nil
end

function Npc.setSitPose(model: Model, sitting: boolean)
	for partName, angle in LEG_ANGLES do
		local bodyPart = model:FindFirstChild(partName)
		if bodyPart and bodyPart:IsA("BasePart") then
			local joint, property = legJoint(model, bodyPart)
			if joint and property then
				local base = legBases[joint] or (joint :: any)[property]
				legBases[joint] = base
				local rotation = CFrame.Angles(math.rad(if sitting then angle else 0), 0, 0)
				;(joint :: any)[property] = CFrame.new(base.Position) * rotation * base.Rotation
			end
		end
	end
end

-- 의자에서 확실히 일어나기 (의자 고정을 풀고 점프)
function Npc.stand(model: Model, seat: Seat)
	Npc.setSitPose(model, false)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	for _, child in seat:GetChildren() do
		if child:IsA("Weld") and child.Name == "SeatWeld" then
			child:Destroy()
		end
	end
	humanoid.Sit = false -- (점프는 못 하니까 의자 고정만 풀고 일어나요)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false) -- 다시 "아무 의자에나 앉기" 금지
end

-- 의자에 앉히기
function Npc.sit(model: Model, seat: Seat)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true) -- 이 의자에만 앉도록 잠깐 허용
	-- 다른 의자에 붙어 있으면 먼저 떼요 (안 그러면 순간이동할 때 그 의자까지 끌려가요)
	local current = humanoid.SeatPart
	if current and current ~= seat then
		for _, child in current:GetChildren() do
			if child:IsA("Weld") and child.Name == "SeatWeld" then
				child:Destroy()
			end
		end
	end
	model:PivotTo(seat.CFrame + Vector3.new(0, 3, 0))
	seat:Sit(humanoid)
	Npc.setSitPose(model, true)
end

return Npc
