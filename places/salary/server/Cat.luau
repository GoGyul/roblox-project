-- 🐱 사무실 고양이 '월급냥'
--   하루에 몇 번 출입문으로 놀러 와서 사무실을 어슬렁거려요.
--   [E] 쓰다듬기 → 의심도 감소 (힐링). 10번 쓰다듬으면 🐱 집사 자격!
--   😺 부장님 근처로 가면 부장님이 고양이에 정신이 팔려서 잠깐 감시를 멈춰요 → 농땡이 찬스!

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)

local Cat = {}

local SPEED = 7 -- 걷는 속도 (칸/초)
local ORANGE = Color3.fromRGB(240, 160, 70)
local WHITE = Color3.fromRGB(250, 245, 235)

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

-- 고양이 모양 만들기 (부품들을 PrimaryPart 하나에 용접)
local function buildCat(parent: Instance): (Model, BasePart, TextLabel)
	local model = Instance.new("Model")
	model.Name = "월급냥"
	local function piece(size: Vector3, offset: CFrame, color: Color3, props: { [string]: any }?): BasePart
		local p = Instance.new("Part")
		p.Size = size
		p.CFrame = offset
		p.Color = color
		p.Material = Enum.Material.Fabric
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		for key, value in props or {} do
			(p :: any)[key] = value
		end
		p.Parent = model
		return p
	end
	local body = piece(Vector3.new(1, 0.9, 1.8), CFrame.new(), ORANGE)
	body.Name = "Body"
	body.Anchored = true
	body.CanQuery = true
	model.PrimaryPart = body
	local parts = {
		piece(Vector3.new(0.85, 0.8, 0.8), CFrame.new(0, 0.45, -1.05), ORANGE), -- 머리
		piece(Vector3.new(0.6, 0.35, 0.1), CFrame.new(0, 0.35, -1.46), WHITE), -- 주둥이
		piece(Vector3.new(0.22, 0.35, 0.15), CFrame.new(-0.25, 0.95, -1.05), ORANGE), -- 귀
		piece(Vector3.new(0.22, 0.35, 0.15), CFrame.new(0.25, 0.95, -1.05), ORANGE),
		piece(Vector3.new(0.12, 0.12, 0.05), CFrame.new(-0.18, 0.55, -1.46), Color3.fromRGB(30, 30, 30)), -- 눈
		piece(Vector3.new(0.12, 0.12, 0.05), CFrame.new(0.18, 0.55, -1.46), Color3.fromRGB(30, 30, 30)),
		piece(Vector3.new(0.18, 0.18, 1.2), CFrame.new(0, 0.55, 1.25) * CFrame.Angles(math.rad(35), 0, 0), ORANGE), -- 꼬리
	}
	for _, x in { -0.32, 0.32 } do
		for _, z in { -0.6, 0.6 } do
			table.insert(parts, piece(Vector3.new(0.22, 0.45, 0.22), CFrame.new(x, -0.62, z), WHITE)) -- 다리
		end
	end
	for _, p in parts do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = p
		weld.Parent = p
	end
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(100, 22) -- 작게
	tag.StudsOffset = Vector3.new(0, 1.5, 0)
	tag.MaxDistance = 45
	tag.Parent = body
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.fromRGB(255, 220, 150)
	text.TextStrokeTransparency = 0.3
	text.Text = "🐱 월급냥"
	text.Parent = tag
	model.Parent = parent
	return model, body, text
end

-- hooks.pet(player) → 쓰다듬기 처리 (true면 성공)
-- hooks.occupiedDesks() → { { desk, player } } 사람이 쓰는 책상들
function Cat.start(office, boss, dayCycle, remotes, hooks)
	local state = {
		model = nil :: Model?,
		body = nil :: BasePart?,
		label = nil :: TextLabel?,
		sittingDesk = nil :: any, -- 지금 앉아 있는 책상
		token = 0,
		visits = {} :: { number }, -- 오늘 방문 시각(분)
		day = -1,
		lastDistract = 0,
	}
	local api = {}

	-- 🐾 이 책상 위에 고양이가 앉아 있나? (Employees가 일하기 시간을 멈출 때 물어봐요)
	function api.sittingOn(desk): boolean
		return state.sittingDesk == desk
	end

	-- 사무실 안에 있는 사람한테만 (옥상·공원·거리에 있으면 사무실 소식은 몰라요)
	local function notifyAll(message: string)
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and office.insideOffice(root.Position) then
				remotes.Notify:FireClient(player, message)
			end
		end
	end

	local function floorAt(position: Vector3): Vector3
		return Vector3.new(position.X, office.entrance.Y + 0.85, position.Z) -- 발이 바닥에 닿는 높이
	end

	-- target까지 걸어가기 (도중에 부장님 근처면 정신 팔리게)
	-- 한 점까지 직선으로 (길찾기가 나눠 준 짧은 구간만 걸어요)
	local function walkStraight(token: number, target: Vector3): boolean
		local body = state.body :: BasePart
		while state.token == token and body.Parent do
			local from = body.Position
			local flat = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
			if flat.Magnitude < 0.5 then
				return true
			end
			local dt = RunService.Heartbeat:Wait()
			if (body:GetAttribute("PauseUntil") or 0) > os.clock() then
				continue -- ✋ 누가 쓰다듬으려고 [E]를 누르는 중이면 그 자리에 멈춰 있어요
			end
			local step = math.min(flat.Magnitude, SPEED * dt)
			local nextPos = Vector3.new(from.X, target.Y, from.Z) + flat.Unit * step
			-- 머리(-Z)가 가는 방향을 보게 + 통통 튀는 걸음
			body.CFrame = CFrame.lookAt(nextPos, nextPos + flat.Unit) * CFrame.new(0, math.abs(math.sin(os.clock() * 12)) * 0.12, 0)
			-- 😺 부장님 근처
			if boss.active and boss.model.Parent and os.clock() - state.lastDistract > 25 then
				if (boss.root.Position - nextPos).Magnitude < 7 then
					state.lastDistract = os.clock()
					boss:distract(SalaryConfig.CAT_DISTRACT, nextPos)
					notifyAll(`😺 부장님이 월급냥한테 정신 팔렸어요! {SalaryConfig.CAT_DISTRACT}초 동안 감시 멈춤!`)
				end
			end
		end
		return false
	end

	-- 🐾 길찾기로 책상·벽·칸막이를 피해서 걸어가요 (고양이 크기에 맞춰서)
	local function walk(token: number, target: Vector3): boolean
		local body = state.body
		if not body then
			return false
		end
		local path = PathfindingService:CreatePath({
			AgentRadius = 1.2,
			AgentHeight = 2.5,
			AgentCanJump = false,
			WaypointSpacing = 3,
		})
		local ok = pcall(function()
			path:ComputeAsync(Vector3.new(body.Position.X, office.entrance.Y + 1, body.Position.Z), target)
		end)
		if not ok or path.Status ~= Enum.PathStatus.Success then
			return state.token == token -- 길이 없으면 그 자리에서 쉬어요 (벽을 뚫고 가지 않게)
		end
		for _, waypoint in path:GetWaypoints() do
			if not walkStraight(token, floorAt(waypoint.Position)) then
				return false
			end
		end
		return true
	end

	local function wait(token: number, seconds: number): boolean
		local finish = os.clock() + seconds
		while os.clock() < finish do
			if state.token ~= token then
				return false
			end
			task.wait(0.2)
		end
		return state.token == token
	end

	local function leave()
		state.token += 1
		state.sittingDesk = nil
		if state.model then
			state.model:Destroy()
		end
		state.model, state.body, state.label = nil, nil, nil
	end

	local function visit()
		leave()
		state.token += 1
		local token = state.token
		local model, body, label = buildCat(office.folder)
		state.model, state.body, state.label = model, body, label
		body.CFrame = CFrame.new(floorAt(office.entrance))
		notifyAll("🐱 사무실에 고양이 '월급냥'이 놀러 왔어요! [E]로 쓰다듬어 보세요")

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "쓰다듬기"
		prompt.ObjectText = "🐱 월급냥"
		prompt.HoldDuration = 1
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.Parent = body
		require(script.Parent.Npc).stopForPrompt(prompt, body, body, 2) -- ✋ 쓰다듬는 동안 멈춰 서요
		prompt.Triggered:Connect(function(player)
			if not hooks.pet(player) then
				return
			end
			label.Text = "🐱 골골골… 💕"
			task.delay(2, function()
				if label.Parent then
					label.Text = "🐱 월급냥"
				end
			end)
			-- 내 키보드 위에 앉아 있었으면 내려가요
			if state.sittingDesk then
				local owner = nil
				for _, entry in hooks.occupiedDesks() do
					if entry.desk == state.sittingDesk then
						owner = entry.player
					end
				end
				if owner == player then
					state.sittingDesk = nil
					remotes.Notify:FireClient(player, "🐱 월급냥이 키보드에서 내려갔어요. 다시 일할 수 있어요!")
				end
			end
		end)

		task.spawn(function()
			local leaveAt = os.clock() + SalaryConfig.CAT_STAY
			while state.token == token and os.clock() < leaveAt and dayCycle.phase == "work" do
				if not walk(token, floorAt(pick(office.waypoints))) then
					return
				end
				if not wait(token, math.random(15, 40) / 10) then
					return
				end
			end
			-- 집에 갈 시간
			if state.token == token then
				walk(token, floorAt(office.entrance))
				if state.token == token then
					leave()
				end
			end
		end)
	end

	-- 하루 스케줄: 근무 중에 CAT_VISITS번 (점심 빼고)
	task.spawn(function()
		while true do
			task.wait(0.5)
			if state.day ~= dayCycle.day then
				state.day = dayCycle.day
				table.clear(state.visits)
				if RunService:IsStudio() and SalaryConfig.TEST_CAT then
					table.insert(state.visits, SalaryConfig.START_MINUTE + 10)
				end
				for _ = 1, SalaryConfig.CAT_VISITS do
					local window = pick({ { 9 * 60 + 30, 11 * 60 + 30 }, { SalaryConfig.LUNCH_END + 10, 16 * 60 + 40 } })
					table.insert(state.visits, math.random(window[1], window[2]))
				end
				table.sort(state.visits)
			end
			if dayCycle.phase ~= "work" then
				if state.model then
					leave() -- 점심·퇴근엔 집에 가요
				end
				continue
			end
			if #state.visits > 0 and dayCycle.minute >= state.visits[1] then
				table.remove(state.visits, 1)
				if not state.model then
					visit()
				end
			end
		end
	end)

	return api
end

return Cat
