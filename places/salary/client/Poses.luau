-- 🕺 자세 연출
--
-- ■ 내 캐릭터(플레이어): 농땡이 행동에 맞게 몸과 팔을 움직이고 소품(폰, 컵 등)을 들어요.
--     예) 엎드려 낮잠 → 허리를 숙이고 팔을 책상에 올리고 고개를 숙여요.
-- ■ NPC(동료, 김부장): 여기서는 건드리지 않아요. (앉은 다리는 서버가 한 번만 설정 — 화면에서 건드리면 다리가 떨려요)
--
-- 애니메이션 파일 없이 관절 각도를 직접 바꾸는 방식이에요.
-- 관절마다 축 방향이 다르기 때문에(R15/R6, 옛 관절/새 관절), 각도를 "캐릭터 기준"으로 정하고
-- 각 관절의 부모 부품 기준으로 회전을 적용해요. 그래서 어떤 몸이든 같은 숫자로 움직여요.
--
-- 각도(도) 기준 — 캐릭터가 앞을 보고 서 있을 때:
--   허리/목: + 뒤로 젖힘, - 앞으로 숙임
--   어깨/팔꿈치: + 팔을 앞으로 듦
--   y: 좌우로 돌리기, z: 옆으로 기울이기
-- wave = {관절, 축, 크기, 빠르기, (시작 위치)}: 반복 움직임 (타자 치기, 고개 끄덕임 등)
--   크기를 음수로 하면 반대로 움직여요 (왼발·오른발 번갈아). 시작 위치(라디안)로 박자를 어긋나게 해요 (자전거 페달)
-- 🦵 다리(rHip·rKnee·lHip·lKnee)는 앉은 자세 위에 더해져요: 엉덩이 -90 + 무릎 +90 = 의자에서 다리를 쭉 펴고 선 자세
--   (🏋️ 체력 단련실 러닝머신·샌드백은 허리 높이의 안 보이는 의자에 "서" 있어요)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SalaryConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SalaryConfig"))

local Poses = {}

type Pose = {
	waist: number?,
	neck: number?,
	rShoulder: number?,
	rElbow: number?,
	lShoulder: number?,
	lElbow: number?,
	rHip: number?,
	rKnee: number?,
	lHip: number?,
	lKnee: number?,
	waves: { { any } }?,
	prop: string?,
}

-- 내 캐릭터의 농땡이 모션
local POSES: { [string]: Pose } = {
	work = { waist = -5, neck = -8, rShoulder = 45, rElbow = 35, lShoulder = 45, lElbow = 35, waves = { { "rElbow", "x", 3, 2.6 }, { "lElbow", "x", 3, 2.2 } } }, -- 천천히 타자 (빠르면 손이 떨리는 것처럼 보여요)
	blank = { waist = 6, neck = 18, waves = { { "neck", "y", 10, 0.6 } } },
	webtoon = { waist = -12, neck = -18, rShoulder = 40, rElbow = 40, lShoulder = 20, lElbow = 20, waves = { { "rElbow", "x", 3, 2 } } },
	phone = { waist = -10, neck = -30, rShoulder = 55, rElbow = 80, lShoulder = 55, lElbow = 80, prop = "phone", waves = { { "neck", "y", 4, 1.5 } } },
	shopping = { waist = -5, neck = -10, rShoulder = 42, rElbow = 30, lShoulder = 10, lElbow = 10, waves = { { "rShoulder", "z", 5, 3 } } },
	sleep = { waist = -50, neck = -30, rShoulder = 95, rElbow = 80, lShoulder = 95, lElbow = 80, waves = { { "waist", "x", 2, 0.8 } } },
	recline = { waist = 25, neck = 30, rShoulder = 160, rElbow = 120, lShoulder = 160, lElbow = 120, waves = { { "waist", "x", 2, 0.5 } } },
	snack = { neck = -10, rShoulder = 60, rElbow = 105, lShoulder = 20, lElbow = 30, prop = "snack", waves = { { "rElbow", "x", 10, 3 }, { "neck", "x", 4, 3 } } },
	returning = { waist = -8, neck = -10, rShoulder = 45, rElbow = 35, lShoulder = 45, lElbow = 35, waves = { { "neck", "y", 15, 14 } } },
	coffee = { rShoulder = 40, rElbow = 85, prop = "cup", waves = { { "rElbow", "x", 12, 1 } } },
	docs = { rShoulder = 20, rElbow = 70, lShoulder = 20, lElbow = 70, prop = "folder" },
	chat = { neck = 5, rShoulder = 35, rElbow = 50, waves = { { "rShoulder", "z", 15, 2 }, { "neck", "y", 8, 1 } } },
	candy = { neck = 12, rShoulder = 75, rElbow = 125, waves = { { "neck", "y", 8, 0.4 } }, prop = "lollipop" }, -- 사탕 물고 먼 산 보기
	video = { neck = -6, rShoulder = 60, rElbow = 120, lShoulder = 40, lElbow = 30, waves = { { "neck", "x", 6, 0.6 } } }, -- 헤드셋 누르며 끄덕끄덕
	rooftop = { neck = 12, rShoulder = 150, rElbow = 20, lShoulder = 150, lElbow = 20, waves = { { "rShoulder", "z", 8, 0.4 } } }, -- 기지개 쭉~
	lounger = { waist = 30, neck = 25, rShoulder = 150, rElbow = 110, lShoulder = 150, lElbow = 110, waves = { { "waist", "x", 2, 0.3 } } }, -- 머리 뒤로 손 깍지
	meeting = { waist = -6, neck = -24, rShoulder = 30, rElbow = 60, lShoulder = 30, lElbow = 60, waves = { { "neck", "x", 10, 0.7 } } }, -- 꾸벅꾸벅
	ramen = { neck = -15, rShoulder = 50, rElbow = 95, lShoulder = 30, lElbow = 60, prop = "bowl", waves = { { "rElbow", "x", 15, 4 } } },
	-- 🏋️ 체력 단련실 (SalaryConfig.GymMachines의 pose)
	treadmill = { -- 🏃 다리를 펴고 서서 팔다리를 번갈아 흔들며 달리기
		waist = -4, neck = -4, rElbow = 75, lElbow = 75, rHip = -90, lHip = -90, rKnee = 90, lKnee = 90,
		waves = { { "rHip", "x", 25, 1.6 }, { "lHip", "x", -25, 1.6 }, { "rShoulder", "x", -30, 1.6 }, { "lShoulder", "x", 30, 1.6 }, { "rKnee", "x", -15, 1.6, 1.6 }, { "lKnee", "x", 15, 1.6, 1.6 } },
	},
	bench = { -- 🏋️ 비스듬히 기대서 두 팔로 바벨 밀어 올리기
		waist = 10, neck = 8, rShoulder = 115, lShoulder = 115, rElbow = 45, lElbow = 45,
		waves = { { "rElbow", "x", 45, 0.6 }, { "lElbow", "x", 45, 0.6 }, { "rShoulder", "x", -12, 0.6 }, { "lShoulder", "x", -12, 0.6 } },
	},
	bike = { -- 🚴 핸들 잡고 페달 굴리기
		waist = -20, neck = 12, rShoulder = 70, lShoulder = 70, rElbow = 20, lElbow = 20,
		waves = { { "rHip", "x", 20, 1.2 }, { "lHip", "x", -20, 1.2 }, { "rKnee", "x", -25, 1.2, 1.57 }, { "lKnee", "x", 25, 1.2, 1.57 }, { "waist", "y", 4, 1.2 } },
	},
	row = { -- 🚣 다리 펴며 몸 젖히고 손잡이 당기기
		waist = 0, neck = 5, rShoulder = 75, lShoulder = 75, rElbow = 45, lElbow = 45, rKnee = 60, lKnee = 60,
		waves = { { "waist", "x", 20, 0.5 }, { "rElbow", "x", 45, 0.5 }, { "lElbow", "x", 45, 0.5 }, { "rKnee", "x", 30, 0.5 }, { "lKnee", "x", 30, 0.5 } },
	},
	stretch = { -- 🤸 매트에 앉아 다리 쭉 펴고 앞으로 숙이기 (천천히 꾸욱~)
		waist = -40, neck = -10, rShoulder = 70, lShoulder = 70, rElbow = 5, lElbow = 5, rKnee = 85, lKnee = 85,
		waves = { { "waist", "x", -12, 0.35 }, { "rShoulder", "x", 12, 0.35 }, { "lShoulder", "x", 12, 0.35 } },
	},
	balance = { -- ⚖️ 짐볼 위에 앉아 팔 벌리고 흔들흔들 균형 잡기
		waist = 0, neck = 0, rShoulder = 80, lShoulder = 80, rElbow = 5, lElbow = 5, rKnee = 30, lKnee = 30,
		waves = { { "waist", "z", 9, 0.8 }, { "rShoulder", "x", 10, 0.8 }, { "lShoulder", "x", -10, 0.8 }, { "neck", "z", -5, 0.8 } },
	},
	punch = { -- 🥊 서서 원투 원투! (팔을 번갈아 쭉)
		waist = -5, neck = -5, rShoulder = 85, lShoulder = 85, rElbow = 60, lElbow = 60, rHip = -85, lHip = -95, rKnee = 90, lKnee = 85,
		waves = { { "rElbow", "x", -50, 2 }, { "lElbow", "x", 50, 2 }, { "rShoulder", "x", 10, 2 }, { "lShoulder", "x", -10, 2 }, { "waist", "y", 12, 2 } },
	},
}

-- 관절 이름 → 움직이는 몸 부위 (R15 이름, R6 이름)
local JOINTS = {
	waist = { "UpperTorso", "Torso" },
	neck = { "Head" },
	rShoulder = { "RightUpperArm", "Right Arm" },
	rElbow = { "RightLowerArm" },
	lShoulder = { "LeftUpperArm", "Left Arm" },
	lElbow = { "LeftLowerArm" },
	rHip = { "RightUpperLeg", "Right Leg" },
	rKnee = { "RightLowerLeg" },
	lHip = { "LeftUpperLeg", "Left Leg" },
	lKnee = { "LeftLowerLeg" },
}

-- 손에 드는 소품 (R15 손 이름, R6 팔 이름)
local PROPS = {
	phone = { hands = { "RightHand", "Right Arm" }, size = Vector3.new(0.5, 0.9, 0.1), color = Color3.fromRGB(20, 20, 25), offset = CFrame.new(0, -0.3, -0.2) },
	cup = { hands = { "RightHand", "Right Arm" }, size = Vector3.new(0.5, 0.6, 0.5), color = Color3.fromRGB(245, 245, 240), offset = CFrame.new(0, -0.3, -0.25) },
	folder = { hands = { "RightHand", "Right Arm" }, size = Vector3.new(1, 1.3, 0.12), color = Color3.fromRGB(240, 200, 80), offset = CFrame.new(-0.5, -0.3, -0.35) },
	snack = { hands = { "RightHand", "Right Arm" }, size = Vector3.new(0.5, 0.25, 0.5), color = Color3.fromRGB(200, 150, 90), offset = CFrame.new(0, -0.3, -0.25) },
	bowl = { hands = { "LeftHand", "Left Arm" }, size = Vector3.new(1, 0.5, 1), color = Color3.fromRGB(200, 60, 40), offset = CFrame.new(0, -0.2, -0.4) },
	lollipop = { hands = { "RightHand", "Right Arm" }, size = Vector3.new(0.6, 0.6, 0.6), color = Color3.fromRGB(255, 110, 170), offset = CFrame.new(0, -0.5, -0.3), shape = Enum.PartType.Ball },
}

type Joint = { set: (CFrame) -> (), base: CFrame, angle: Vector3, kind: string }
type Rig = { joints: { [string]: Joint }, props: { [string]: BasePart }, kind: string }

local rigs: { [Model]: Rig } = setmetatable({}, { __mode = "k" }) :: any
local announced: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function findPart(model: Model, names: { string }): BasePart?
	for _, name in names do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

-- bodyPart를 움직이는 관절 찾기
--   옛 방식(Motor6D)을 먼저 찾고 → 없으면 새 방식(AnimationConstraint)
--   (처음에 잘 동작하던 순서예요)
local function findJoint(model: Model, bodyPart: BasePart): Joint?
	for _, item in model:GetDescendants() do
		if item:IsA("Motor6D") and item.Part1 == bodyPart then
			local motor = item
			return {
				kind = "Motor6D",
				base = motor.C0,
				angle = Vector3.zero,
				set = function(cframe)
					motor.C0 = cframe
				end,
			}
		end
	end
	for _, item in model:GetDescendants() do
		if item:IsA("AnimationConstraint") and item.Attachment0 and item.Attachment1 then
			local parentSide: Attachment? = nil
			if item.Attachment1.Parent == bodyPart then
				parentSide = item.Attachment0
			elseif item.Attachment0.Parent == bodyPart then
				parentSide = item.Attachment1
			end
			if parentSide then
				local attachment = parentSide
				return {
					kind = "AnimationConstraint",
					base = attachment.CFrame,
					angle = Vector3.zero,
					set = function(cframe)
						attachment.CFrame = cframe
					end,
				}
			end
		end
	end
	return nil
end

local function getRig(model: Model): Rig?
	local rig = rigs[model]
	if rig then
		return rig
	end
	if not model:FindFirstChild("Head") then
		return nil -- 아직 몸이 다 안 불러와졌어요 (다음 프레임에 다시)
	end
	local joints = {}
	for name, partNames in JOINTS do
		local bodyPart = findPart(model, partNames)
		local joint = bodyPart and findJoint(model, bodyPart)
		if joint then
			joints[name] = joint
		end
	end
	-- 허리·목·어깨는 꼭 있어야 해요 (팔꿈치·무릎은 R6엔 없어서 없어도 돼요)
	for _, required in { "waist", "neck", "rShoulder", "lShoulder" } do
		if not joints[required] then
			return nil
		end
	end
	local kind = `{if model:FindFirstChild("UpperTorso") then "R15" else "R6"} / {joints.waist.kind}`
	rig = { joints = joints, props = {}, kind = kind }
	rigs[model] = rig
	if model == Players.LocalPlayer.Character and not announced[model] then
		announced[model] = true
		print(`[Poses] 내 캐릭터 자세 연출 준비 완료 ✅ ({kind})`)
	end
	return rig
end

local function setProp(model: Model, rig: Rig, wanted: string?)
	for name, part in rig.props do
		part.Transparency = if name == wanted then 0 else 1
	end
	if wanted and not rig.props[wanted] then
		local spec = PROPS[wanted]
		-- 간식은 지금 들고 있는 간식 모양·색으로 ("snack_cake" 같은 이름)
		local snackId = string.match(wanted, "^snack_(.+)$")
		local snack = snackId and SalaryConfig.getSnack(snackId)
		if snack then
			spec = { hands = { "RightHand", "Right Arm" }, size = snack.size * 0.8, color = snack.color, offset = CFrame.new(0, -0.3, -0.25) }
		end
		if not spec then
			return
		end
		local hand = findPart(model, spec.hands)
		if hand then
			local part = Instance.new("Part")
			part.Name = `Prop_{wanted}`
			if spec.shape then
				part.Shape = spec.shape
			end
			part.Size = spec.size
			part.Color = spec.color
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			part.CFrame = hand.CFrame * spec.offset
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hand
			weld.Part1 = part
			weld.Parent = part
			part.Parent = model
			rig.props[wanted] = part
		end
	end
end

-- 캐릭터 기준 회전을 관절에 적용: 관절 위치는 그대로, 부모 부품 기준으로 회전
local function rotated(base: CFrame, angle: Vector3): CFrame
	local rotation = CFrame.Angles(math.rad(angle.X), math.rad(angle.Y), math.rad(angle.Z))
	return CFrame.new(base.Position) * rotation * base.Rotation
end

local function applyAngles(rig: Rig, targets: { [string]: Vector3 }, dt: number)
	local alpha = 1 - math.exp(-10 * dt) -- 부드럽게 따라가기
	for name, joint in rig.joints do
		local target = targets[name] or Vector3.zero
		joint.angle = joint.angle:Lerp(target, alpha)
		joint.set(rotated(joint.base, joint.angle))
	end
end

-- 😴 잘 때는 눈 감은 얼굴 + 머리 위 💤
local sleepState: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function setSleepFace(model: Model, sleeping: boolean)
	if sleepState[model] == sleeping then
		return
	end
	sleepState[model] = sleeping
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	-- 원래 얼굴(눈 뜬 그림)은 숨기고, 감은 눈을 그려요
	local face = head:FindFirstChild("face")
	if face and face:IsA("Decal") then
		face.Transparency = if sleeping then 1 else 0
	end
	local overlay = head:FindFirstChild("SleepFace")
	if sleeping and not overlay then
		overlay = Instance.new("SurfaceGui")
		overlay.Name = "SleepFace"
		overlay.Face = Enum.NormalId.Front
		overlay.LightInfluence = 1
		local eyes = Instance.new("TextLabel")
		eyes.Size = UDim2.fromScale(1, 0.5)
		eyes.Position = UDim2.fromScale(0, 0.18)
		eyes.BackgroundTransparency = 1
		eyes.Text = "-   -"
		eyes.TextScaled = true
		eyes.Font = Enum.Font.GothamBlack
		eyes.TextColor3 = Color3.fromRGB(30, 25, 25)
		eyes.Parent = overlay
		local mouth = Instance.new("TextLabel")
		mouth.Size = UDim2.fromScale(1, 0.3)
		mouth.Position = UDim2.fromScale(0, 0.62)
		mouth.BackgroundTransparency = 1
		mouth.Text = "o"
		mouth.TextScaled = true
		mouth.Font = Enum.Font.GothamBold
		mouth.TextColor3 = Color3.fromRGB(60, 30, 30)
		mouth.Parent = overlay
		overlay.Parent = head

		-- 💤 가 머리 위로 떠올라요
		local zzz = Instance.new("BillboardGui")
		zzz.Name = "SleepZzz"
		zzz.Size = UDim2.fromOffset(60, 40)
		zzz.StudsOffset = Vector3.new(1.2, 2.2, 0)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "💤"
		label.TextScaled = true
		label.Parent = zzz
		zzz.Parent = head
		local tween = TweenService:Create(zzz, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			StudsOffset = Vector3.new(1.6, 3, 0),
		})
		tween:Play()
	elseif not sleeping and overlay then
		overlay:Destroy()
		local zzz = head:FindFirstChild("SleepZzz")
		if zzz then
			zzz:Destroy()
		end
	end
end

-- 내 캐릭터: 농땡이 모션
local function applyPlayer(model: Model, poseName: string?, dt: number, t: number)
	local rig = getRig(model)
	if not rig then
		return
	end
	local pose = (poseName and POSES[poseName]) or {}
	local targets: { [string]: Vector3 } = {}
	for _, name in { "waist", "neck", "rShoulder", "rElbow", "lShoulder", "lElbow", "rHip", "rKnee", "lHip", "lKnee" } do
		targets[name] = Vector3.new((pose :: any)[name] or 0, 0, 0)
	end
	for _, wave in pose.waves or {} do
		local amount = math.sin(t * wave[4] * math.pi * 2 + (wave[5] or 0)) * wave[3]
		local axis = if wave[2] == "x" then Vector3.new(amount, 0, 0) elseif wave[2] == "y" then Vector3.new(0, amount, 0) else Vector3.new(0, 0, amount)
		targets[wave[1]] = (targets[wave[1]] or Vector3.zero) + axis
	end
	-- R6처럼 팔꿈치가 없으면 팔꿈치 각도의 절반을 어깨에 더해요
	for _, side in { "r", "l" } do
		if not rig.joints[`{side}Elbow`] then
			local elbow = targets[`{side}Elbow`] or Vector3.zero
			targets[`{side}Shoulder`] += elbow * 0.5
		end
	end
	applyAngles(rig, targets, dt)
	local prop = pose.prop
	if prop == "snack" then
		local held = Players.LocalPlayer:GetAttribute("HeldSnack")
		prop = if held and held ~= "" then `snack_{held}` else "snack"
	end
	setProp(model, rig, prop)
	setSleepFace(model, poseName == "sleep" or poseName == "recline")
end

function Poses.start()
	print("[Poses] 자세 연출 시작")
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		-- 내 캐릭터
		local me = Players.LocalPlayer
		local character = me.Character
		if character then
			-- 변기에 앉아 있으면 폰으로 주식 보는 자세
			local pose = if me:GetAttribute("OnToilet") then "phone" else me:GetAttribute("SalaryState")
			if pose == "gym" then
				-- 🏋️ 운동기구마다 자세가 달라요 (러닝머신·벤치프레스·자전거·로잉·샌드백)
				local machine = SalaryConfig.GymMachines[me:GetAttribute("GymMachine") or ""]
				pose = if machine then machine.pose else "rooftop"
			end
			applyPlayer(character, pose, dt, t)
		end
	end)
end

return Poses
