-- 🕺 자세 연출: 지금 하는 행동에 맞게 캐릭터의 몸과 팔을 움직여요.
--
-- 애니메이션 파일 없이 "관절(Motor6D) 각도"를 직접 바꾸는 방식이에요.
--   예) 낮잠 → 허리를 앞으로 숙이고, 팔을 책상 위에 올리고, 고개를 숙여요.
--
-- 대상: 플레이어(SalaryState 속성), 동료와 김부장(모델의 Pose 속성)
-- 클라이언트에서만 바꾸는 거라 서버 판정(의심도 등)에는 영향이 없어요.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Poses = {}

-- 각도는 도(degree). X축 회전 기준:
--   허리/목: +는 뒤로 젖힘, -는 앞으로 숙임
--   어깨/팔꿈치: +는 팔을 앞으로 듦
-- wave = {관절, 축, 크기, 빠르기}: 반복 움직임 (타자 치기, 손 흔들기 등)
type Pose = {
	waist: number?,
	neck: number?,
	rShoulder: number?,
	rElbow: number?,
	lShoulder: number?,
	lElbow: number?,
	waves: { { any } }?,
	prop: string?,
}

local POSES: { [string]: Pose } = {
	work = { waist = -5, neck = -8, rShoulder = 45, rElbow = 35, lShoulder = 45, lElbow = 35, waves = { { "rElbow", "x", 6, 12 }, { "lElbow", "x", 6, 10 } } },
	blank = { waist = 6, neck = 18, waves = { { "neck", "y", 10, 0.6 } } },
	phone = { waist = -10, neck = -30, rShoulder = 55, rElbow = 80, lShoulder = 55, lElbow = 80, prop = "phone", waves = { { "neck", "y", 4, 1.5 } } },
	webtoon = { waist = -12, neck = -18, rShoulder = 40, rElbow = 40, lShoulder = 20, lElbow = 20, waves = { { "rElbow", "x", 3, 2 } } },
	shopping = { waist = -5, neck = -10, rShoulder = 42, rElbow = 30, lShoulder = 10, lElbow = 10, waves = { { "rShoulder", "z", 5, 3 } } },
	sleep = { waist = -50, neck = -30, rShoulder = 95, rElbow = 80, lShoulder = 95, lElbow = 80, waves = { { "waist", "x", 2, 0.8 } } },
	recline = { waist = 25, neck = 30, rShoulder = 160, rElbow = 120, lShoulder = 160, lElbow = 120, waves = { { "waist", "x", 2, 0.5 } } },
	returning = { waist = -8, neck = -10, rShoulder = 45, rElbow = 35, lShoulder = 45, lElbow = 35, waves = { { "neck", "y", 15, 14 } } },
	coffee = { rShoulder = 40, rElbow = 85, prop = "cup", waves = { { "rElbow", "x", 12, 1 } } },
	docs = { rShoulder = 35, rElbow = 60, lShoulder = 35, lElbow = 60, prop = "folder" },
	chat = { neck = 5, rShoulder = 35, rElbow = 50, waves = { { "rShoulder", "z", 15, 2 }, { "neck", "y", 8, 1 } } },
	ramen = { neck = -15, rShoulder = 50, rElbow = 95, lShoulder = 30, lElbow = 60, prop = "bowl", waves = { { "rElbow", "x", 15, 4 } } },
	snack = { neck = -10, rShoulder = 60, rElbow = 105, lShoulder = 20, lElbow = 30, prop = "snack", waves = { { "rElbow", "x", 10, 3 }, { "neck", "x", 4, 3 } } },
	scold = { waist = -5, rShoulder = 85, rElbow = 5, waves = { { "rShoulder", "x", 8, 6 } } },
	walk = {},
}

-- 관절 이름 → 그 관절이 움직이는 몸 부위(R15)
local JOINTS = {
	waist = "UpperTorso",
	neck = "Head",
	rShoulder = "RightUpperArm",
	rElbow = "RightLowerArm",
	lShoulder = "LeftUpperArm",
	lElbow = "LeftLowerArm",
}

-- 손에 드는 소품
local PROPS = {
	phone = { hand = "RightHand", size = Vector3.new(0.5, 0.9, 0.1), color = Color3.fromRGB(20, 20, 25), offset = CFrame.new(0, -0.3, -0.2) },
	cup = { hand = "RightHand", size = Vector3.new(0.5, 0.6, 0.5), color = Color3.fromRGB(245, 245, 240), offset = CFrame.new(0, -0.3, -0.25) },
	folder = { hand = "RightHand", size = Vector3.new(1.4, 1.8, 0.15), color = Color3.fromRGB(240, 200, 80), offset = CFrame.new(-0.6, -0.4, -0.4) },
	snack = { hand = "RightHand", size = Vector3.new(0.5, 0.25, 0.5), color = Color3.fromRGB(200, 150, 90), offset = CFrame.new(0, -0.3, -0.25) },
	bowl = { hand = "LeftHand", size = Vector3.new(1, 0.5, 1), color = Color3.fromRGB(200, 60, 40), offset = CFrame.new(0, -0.2, -0.4) },
}

-- 관절 하나: 옛 방식(Motor6D의 C0)이든 새 방식(AnimationConstraint의 Attachment0)이든
-- "기준 CFrame에 회전을 곱한다"는 건 똑같아요.
type Joint = { set: (CFrame) -> (), base: CFrame, angle: Vector3 }

type Rig = {
	joints: { [string]: Joint },
	props: { [string]: BasePart },
}

local rigs: { [Model]: Rig | false } = setmetatable({}, { __mode = "k" }) :: any
local warned: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- bodyPart를 움직이는 관절 찾기
local function findJoint(model: Model, bodyPart: BasePart): Joint?
	for _, item in model:GetDescendants() do
		if item:IsA("Motor6D") and item.Part1 == bodyPart then
			local motor = item
			return {
				base = motor.C0,
				angle = Vector3.zero,
				set = function(cframe)
					motor.C0 = cframe
				end,
			}
		end
	end
	-- 새 관절 방식 (Avatar Joint Upgrade)
	for _, item in model:GetDescendants() do
		if item:IsA("AnimationConstraint") and item.Attachment1 and item.Attachment1.Parent == bodyPart and item.Attachment0 then
			local attachment = item.Attachment0
			return {
				base = attachment.CFrame,
				angle = Vector3.zero,
				set = function(cframe)
					attachment.CFrame = cframe
				end,
			}
		end
	end
	return nil
end

local function getRig(model: Model): Rig?
	local cached = rigs[model]
	if cached ~= nil then
		return if cached then cached else nil
	end
	if not model:FindFirstChild("UpperTorso") then
		if model:FindFirstChildOfClass("Humanoid") and model:FindFirstChild("Torso") then
			warn(`[Poses] {model.Name}: R6 아바타라 자세 연출을 할 수 없어요. (게임 설정 → Avatar → R15로 바꿔 주세요)`)
			rigs[model] = false
		end
		return nil -- 아직 몸이 다 안 불러와졌을 수도 있어요 (다음 프레임에 다시 시도)
	end
	local joints = {}
	for name, partName in JOINTS do
		local bodyPart = model:FindFirstChild(partName)
		local joint = bodyPart and bodyPart:IsA("BasePart") and findJoint(model, bodyPart)
		if not joint then
			-- 몸이 아직 다 안 불러와졌을 수 있어서 다음에 다시 시도해요 (경고는 한 번만)
			if not warned[model] then
				warned[model] = true
				warn(`[Poses] {model.Name}: {partName}의 관절을 아직 찾지 못했어요.`)
			end
			return nil
		end
		joints[name] = joint
	end
	local rig = { joints = joints, props = {} }
	rigs[model] = rig
	if warned[model] or model == Players.LocalPlayer.Character then
		print(`[Poses] {model.Name}: 관절 연결 완료 ✅`)
	end
	return rig
end

local function setProp(model: Model, rig: Rig, wanted: string?)
	for name, part in rig.props do
		part.Transparency = if name == wanted then 0 else 1
	end
	if wanted and not rig.props[wanted] then
		local spec = PROPS[wanted]
		local hand = model:FindFirstChild(spec.hand) :: BasePart?
		if hand then
			local part = Instance.new("Part")
			part.Name = `Prop_{wanted}`
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

local function apply(model: Model, poseName: string?, dt: number, t: number)
	local rig = getRig(model)
	if not rig then
		return
	end
	local pose = (poseName and POSES[poseName]) or {}
	local alpha = 1 - math.exp(-10 * dt) -- 부드럽게 따라가기

	for name, joint in rig.joints do
		local target = Vector3.new((pose :: any)[name] or 0, 0, 0)
		for _, wave in pose.waves or {} do
			if wave[1] == name then
				local amount = math.sin(t * wave[4] * math.pi * 2) * wave[3]
				target += if wave[2] == "x" then Vector3.new(amount, 0, 0) elseif wave[2] == "y" then Vector3.new(0, amount, 0) else Vector3.new(0, 0, amount)
			end
		end
		joint.angle = joint.angle:Lerp(target, alpha)
		local a = joint.angle
		joint.set(joint.base * CFrame.Angles(math.rad(a.X), math.rad(a.Y), math.rad(a.Z)))
	end
	setProp(model, rig, pose.prop)
end

function Poses.start()
	print("[Poses] 자세 연출 시작")
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		-- 플레이어들
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character then
				-- 변기에 앉아 있으면 폰으로 주식 보는 자세
				local pose = if player:GetAttribute("OnToilet") then "phone" else player:GetAttribute("SalaryState")
				apply(character, pose, dt, t)
			end
		end
		-- 동료와 김부장
		local office = workspace:FindFirstChild("Office")
		if office then
			for _, model in office:GetChildren() do
				if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
					apply(model, model:GetAttribute("Pose"), dt, t)
				end
			end
		end
	end)
end

return Poses
