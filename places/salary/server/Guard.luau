-- 👮 경비원 (사무실 밖 담당: 🌳 공원·🏙️ 눈치 스트리트 / 🚪 옥상)
--   부장님은 사무실에만 있어요. 사무실 밖은 경비원이 근무 시간 내내 상주하며 순찰해요 (점심·퇴근 뒤엔 경비실 앞에서 쉬어요)
--   💤 옥상 경비원은 가끔 경비실에서 CCTV를 보며 쉬어요 (그동안은 감시 안 함 → 리듬을 읽어요!)
--   🔊 소리(옥상 농구공 등)가 나면 그쪽으로 확인하러 와요 (api.investigate)
--   🔦 경비원 시야(부채꼴)에 농땡이가 보이면 의심도가 차요 → 들키면 멈춰 서서 나만 계속 노려봐요
--   나무·건물·가게 벽 뒤로 숨어서 GUARD_STARE_GRACE초 동안 안 보이면 다시 순찰해요
--   🌸 워크숍·🚨 소방 훈련처럼 다 같이 밖에 나가는 이벤트 중에는 감시하지 않아요
--
-- Guard.new(opts) → api
--   api.sees(character) → 보이나, 거리, 노려보는 중인가, 시야 거리 (Employees가 의심도 계산할 때 물어봐요)
--   api.investigate(position) / api.model / api.near(position, 거리) / api.watching()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local Npc = require(script.Parent.Npc)
local Boss = require(script.Parent.Boss)
local Walker = require(script.Parent.Walker)

local Guard = {}

local LOOK = {
	skin = Color3.fromRGB(215, 175, 140),
	shirt = Color3.fromRGB(40, 55, 95), -- 경비 제복 (진한 파랑)
	pants = Color3.fromRGB(30, 35, 50),
}

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

-- 🏠 작은 경비실 (정문 옆)
local function buildBooth(parent: Instance, post: Vector3)
	local folder = Instance.new("Folder")
	folder.Name = "GuardBooth"
	folder.Parent = parent
	local function part(size: Vector3, cframe: CFrame, color: Color3, props: { [string]: any }?): BasePart
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = cframe
		p.Color = color
		p.Anchored = true
		p.Material = Enum.Material.SmoothPlastic
		for key, value in props or {} do
			(p :: any)[key] = value
		end
		p.Parent = folder
		return p
	end
	-- post = 경비원이 서는 자리 (경비실 앞). 경비실은 그 뒤(-Z)
	local base = post + Vector3.new(0, 0, -4.5)
	local wall = Color3.fromRGB(225, 225, 215)
	part(Vector3.new(5, 0.4, 5), CFrame.new(base + Vector3.new(0, 0.2, 0)), Color3.fromRGB(150, 150, 150), { Material = Enum.Material.Concrete })
	part(Vector3.new(5, 6, 0.4), CFrame.new(base + Vector3.new(0, 3.2, -2.3)), wall) -- 뒷벽
	for _, dx in { -2.3, 2.3 } do
		part(Vector3.new(0.4, 6, 5), CFrame.new(base + Vector3.new(dx, 3.2, 0)), wall) -- 옆벽
	end
	part(Vector3.new(5, 2.4, 0.4), CFrame.new(base + Vector3.new(0, 1.4, 2.3)), wall) -- 앞 허리벽
	part(Vector3.new(4.2, 3, 0.2), CFrame.new(base + Vector3.new(0, 4.1, 2.3)), Color3.fromRGB(170, 210, 230), { Material = Enum.Material.Glass, Transparency = 0.5 }) -- 창문
	part(Vector3.new(5.8, 0.5, 5.8), CFrame.new(base + Vector3.new(0, 6.45, 0)), Color3.fromRGB(40, 55, 95)) -- 지붕
	local sign = part(Vector3.new(4, 1, 0.2), CFrame.new(base + Vector3.new(0, 5.9, 2.55)), Color3.fromRGB(30, 35, 45))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(400, 100)
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 120)
	label.Text = "👮 경비실"
	label.Parent = gui
	-- 경비실 앞 경광등 (감시 중이면 빨갛게 깜빡)
	local beacon = part(Vector3.new(0.7, 0.7, 0.7), CFrame.new(base + Vector3.new(1.8, 7, 1.8)), Color3.fromRGB(80, 80, 90), { Shape = Enum.PartType.Ball, CanCollide = false })
	return beacon
end

-- opts: folder, post(경비실 앞 서는 자리), patrol(순찰 지점들), area(position) → 이 경비원 담당 구역인가,
--       dayCycle, events, remotes, name, lines(들켰을 때 대사), rest(💤 쉬는 시간 쓸까), range, fov
function Guard.new(opts)
	local post: Vector3 = opts.post
	local dayCycle, events, remotes = opts.dayCycle, opts.events, opts.remotes
	local beacon = buildBooth(opts.folder, post)

	local model = Npc.create(opts.name or "경비원", LOOK, opts.folder)
	model.Name = "Guard"
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.WalkSpeed = SalaryConfig.GUARD_WALK_SPEED
	-- 경비 모자 (머리 위 납작한 원통 + 챙)
	local head = model:FindFirstChild("Head") :: BasePart
	if head then
		local function hatPart(size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?)
			local p = Instance.new("Part")
			p.Size = size
			p.Color = color
			p.CanCollide = false
			p.CanQuery = false
			p.Massless = true
			p.Material = Enum.Material.SmoothPlastic
			if shape then
				p.Shape = shape
			end
			p.CFrame = head.CFrame * offset
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = p
			weld.Parent = p
			p.Parent = model
		end
		hatPart(Vector3.new(0.5, 1.35, 1.35), CFrame.new(0, 0.75, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(35, 45, 80), Enum.PartType.Cylinder)
		hatPart(Vector3.new(1.1, 0.12, 0.55), CFrame.new(0, 0.55, -0.75), Color3.fromRGB(20, 20, 25))
		hatPart(Vector3.new(0.35, 0.3, 0.06), CFrame.new(0, 0.85, -0.68), Color3.fromRGB(255, 210, 80)) -- 모자 배지
	end
	model:PivotTo(CFrame.lookAt(post + Vector3.new(0, 3, 0), post + Vector3.new(0, 3, 10)))
	root:SetNetworkOwner(nil)
	Npc.setStatus(model, "👮")

	local guard = {
		active = true,
		watching = false,
		model = model,
		head = head,
		root = root,
		range = opts.range or SalaryConfig.GUARD_RANGE,
		fovCos = math.cos(math.rad(opts.fov or SalaryConfig.GUARD_FOV)),
		stareAt = nil :: Model?,
		stareUntil = 0,
		resting = false, -- 💤 경비실에서 쉬는 중
		investigateAt = nil :: Vector3?, -- 🔊 소리 난 곳
	}
	local lines = opts.lines or { "거기! 근무 시간에 어디 가요?", "사원증 좀 봅시다~ 어느 부서예요?", "어허, 내가 다 보고 있어요!" }

	-- 지금 근무하나? (근무 시간에만, 다 같이 밖에 나가는 이벤트는 빼고)
	local function onDuty(): boolean
		if dayCycle.phase ~= "work" then
			return false
		end
		if events and (events:is("workshop") or events:is("drill")) then
			return false
		end
		return true
	end

	local function staring(): boolean
		return guard.stareAt ~= nil and (guard.stareAt :: Model).Parent ~= nil and os.clock() < guard.stareUntil and guard.watching and onDuty()
	end

	local api = {}
	api.model = model
	function api.watching(): boolean
		return guard.watching
	end
	-- 이 위치 가까이에 경비원이 있나 (🐦 비둘기 알람)
	function api.near(position: Vector3, distance: number): boolean
		return model.Parent ~= nil and (root.Position - position).Magnitude <= distance
	end
	-- 보이나, 거리, 노려보는 중인가
	function api.sees(character: Model): (boolean, number, boolean, number)
		if not guard.watching or not onDuty() then
			return false, math.huge, false, guard.range -- (워크숍·훈련이 막 시작됐으면 바로 감시 끝)
		end
		local characterRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not characterRoot or not opts.area(characterRoot.Position) then
			return false, math.huge, false, guard.range -- 내 담당 구역이 아니에요
		end
		local seen, distance = Boss.canSee(guard, character)
		if seen then
			if not staring() then
				guard.stareAt = character
				Npc.setStatus(model, "🚨")
				Npc.say(model, pick(lines), 3)
				local player = Players:GetPlayerFromCharacter(character)
				if player then
					remotes.Notify:FireClient(player, "👮 경비원한테 딱 걸렸어요! 가려지는 곳으로 숨어서 시야에서 벗어나요")
				end
			end
			if guard.stareAt == character then
				guard.stareUntil = os.clock() + SalaryConfig.GUARD_STARE_GRACE
			end
		end
		return seen, distance, seen and guard.stareAt == character, guard.range
	end
	-- 🔊 소리 난 곳으로 확인하러 가요 (쉬는 중이어도 일어나요)
	function api.investigate(position: Vector3)
		if not guard.watching and not guard.resting then
			return
		end
		guard.investigateAt = position
	end

	-- 노려보는 동안: 제자리에 서서 그 사람만 봐요
	local function holdStare()
		if not staring() then
			return
		end
		while staring() and model.Parent do
			humanoid:MoveTo(root.Position)
			local targetRoot = guard.stareAt and (guard.stareAt :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
			if targetRoot then
				local flat = Vector3.new(targetRoot.Position.X - root.Position.X, 0, targetRoot.Position.Z - root.Position.Z)
				if flat.Magnitude > 0.1 then
					root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
				end
			end
			task.wait(0.1)
		end
		guard.stareAt = nil
		if model.Parent then
			Npc.setStatus(model, "🔦")
			Npc.say(model, "흠… 어디 갔지?", 2)
		end
	end

	local function interrupted(): boolean
		return staring() or not onDuty() or guard.investigateAt ~= nil
	end

	local function lookAround(times: number)
		for _ = 1, times do
			holdStare()
			if not guard.watching or guard.investigateAt then
				return
			end
			local angle = math.rad(math.random(0, 359))
			root.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)))
			task.wait(math.random(8, 14) / 10)
		end
	end

	local function walk(target: Vector3)
		Walker.walkTo(humanoid, root, target, interrupted)
	end

	-- 💤 경비실에서 CCTV 보며 쉬기 (그동안 감시 안 해요)
	local function rest()
		walk(post)
		if interrupted() then
			return
		end
		guard.resting = true
		guard.watching = false
		guard.stareAt = nil
		Npc.setStatus(model, "💤")
		Npc.say(model, pick({ "잠깐 CCTV 좀 보고 올까…", "아이고 다리야, 좀 쉬자.", "커피 한 잔만…" }), 2.5)
		root.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.new(0, 0, -1)) -- 경비실 안쪽을 봐요
		local untilTime = os.clock() + math.random(SalaryConfig.GUARD_REST[1], SalaryConfig.GUARD_REST[2])
		while os.clock() < untilTime and onDuty() and not guard.investigateAt do
			task.wait(0.25)
		end
		guard.resting = false
		if onDuty() then
			guard.watching = true
			Npc.setStatus(model, "🔦")
			Npc.say(model, if guard.investigateAt then "응? 무슨 소리지?" else "자~ 다시 순찰!", 2)
		end
	end

	-- 🚶 순찰 (상시 상주)
	task.spawn(function()
		while model.Parent do
			local duty = onDuty()
			guard.watching = duty
			if not duty then
				-- 근무 시간이 아니면 경비실 앞에서 쉬어요
				guard.stareAt = nil
				guard.investigateAt = nil
				Npc.setStatus(model, "☕")
				if (root.Position - post).Magnitude > 3 then
					Walker.walkTo(humanoid, root, post, onDuty)
				end
				task.wait(1)
				continue
			end
			Npc.setStatus(model, "🔦")
			local ok, err = pcall(function()
				holdStare()
				local noise = guard.investigateAt
				if noise then
					guard.investigateAt = nil
					Npc.setStatus(model, "❓")
					walk(noise)
					holdStare()
					lookAround(3)
					return
				end
				if opts.rest and math.random() < SalaryConfig.GUARD_REST_CHANCE then
					rest()
					return
				end
				-- 가끔은 경비실 앞에서 한참 지켜봐요
				local target = if math.random() < 0.2 then post else pick(opts.patrol)
				walk(target)
				holdStare()
				lookAround(if target == post then 4 else 2)
			end)
			if not ok then
				warn("[경비원] " .. tostring(err))
				task.wait(1)
			end
		end
	end)

	-- 🚨 경광등: 누굴 노려볼 때 빨갛게 깜빡
	task.spawn(function()
		local on = false
		while model.Parent and beacon.Parent do
			if staring() then
				on = not on
				beacon.Color = if on then Color3.fromRGB(255, 50, 50) else Color3.fromRGB(120, 20, 20)
				beacon.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
			else
				beacon.Color = Color3.fromRGB(80, 80, 90)
				beacon.Material = Enum.Material.SmoothPlastic
			end
			task.wait(0.3)
		end
	end)

	return api
end

-- 🌳 공원·눈치 스트리트 경비원 (눈치물산만, 밖 공간이 있는 회사)
function Guard.start(office, dayCycle, events, remotes)
	if not office.guardPatrol or not office.guardPost then
		return nil -- 밖 공간이 없는 회사(대충상사)에는 공원 경비원이 없어요
	end
	return Guard.new({
		folder = office.folder,
		post = office.guardPost,
		patrol = office.guardPatrol,
		area = function(position: Vector3): boolean
			-- 건물 안도, 하늘 위 옥상도 아닌 땅 위 (공원·거리)
			return not office.insideOffice(position) and math.abs(position.Y - office.entrance.Y) < 20
		end,
		dayCycle = dayCycle,
		events = events,
		remotes = remotes,
		name = "경비원 박씨",
	})
end

return Guard
