-- NPC 사람 만들기 (김부장, 동료 직원)
-- 로블록스 기본 아바타 몸에 색만 입혀서 만들고, 머리 위에 상태 이모지와 말풍선을 달아요.

local Players = game:GetService("Players")

local Npc = {}

export type Look = {
	skin: Color3,
	shirt: Color3,
	pants: Color3,
}

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
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.CanCollide = false
		end
	end

	-- 머리 위 표시: 이름 / 상태 이모지 / 말풍선
	local head = model:WaitForChild("Head") :: BasePart
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Bubble"
	billboard.Size = UDim2.fromOffset(260, 110)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
	billboard.MaxDistance = 90
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
	local speech = label("Speech", 0, 44, 18)
	speech.BackgroundTransparency = 0.1
	speech.BackgroundColor3 = Color3.new(1, 1, 1)
	speech.TextColor3 = Color3.fromRGB(30, 30, 30)
	speech.TextStrokeTransparency = 1
	speech.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = speech
	label("Status", 48, 36, 30)
	label("NameTag", 84, 22, 16).Text = name

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
	model:PivotTo(seat.CFrame + Vector3.new(0, 3, 0))
	seat:Sit(humanoid)
	Npc.setSitPose(model, true)
end

return Npc
