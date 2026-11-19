-- 📋 긴급 프로젝트 (하루 한 번, 사람마다 따로) — 실패해도 손해는 없지만 아주 어려워요!
--   부장님이 "○○ 씨! 긴급 프로젝트야!" → 제한 시간 안에 단계를 모두 끝내면 경고 -1 (경고가 없으면 보너스)
--   적발되면 그 자리에서 실패. 단계 종류는 SalaryConfig.Missions 위 설명을 봐요.
--
-- 🧩 퍼즐(타자·계산·기억·순서)은 서버가 문제를 내고 정답을 갖고 있어요. 화면은 답만 보내요.
-- 👔 부장님 [E] 말 걸기: 프로젝트 제출 / 🎁 들고 있는 선물 드리기
-- 화면에는 플레이어 속성으로: MissionId, MissionStep, MissionEndsAt, MissionProgress, MissionStatus

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)

local Missions = {}

local TALK_RANGE = 8
local ANSWER_SECONDS = 6 -- 📳 전화: 이 안에 자리에 앉아야 받아요
local IDLE_LINES = { "뭐야? 일이나 해!", "할 말 있어? 없으면 자리로~", "바쁜데 왜?" }
local allowPuzzle = RateLimit.new(0.2)

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

local function shuffle<T>(list: { T }): { T }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = math.random(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

-- 🧮 계산 문제 (두세 자리 덧셈·뺄셈·곱셈)
local function makeMath(count: number)
	local problems = {}
	for _ = 1, count do
		local roll = math.random(1, 3)
		local a, b, op, answer
		if roll == 1 then
			a, b, op = math.random(120, 899), math.random(110, 899), "+"
			answer = a + b
		elseif roll == 2 then
			a, b, op = math.random(400, 999), math.random(100, 399), "-"
			answer = a - b
		else
			a, b, op = math.random(12, 39), math.random(3, 9), "×"
			answer = a * b
		end
		table.insert(problems, { text = `{a} {op} {b} = ?`, answer = answer })
	end
	return problems
end

-- api: Employees.missionApi (get, isSeated, reward, giveGift)
-- hooks: Employees.hooks (printer, caught, coworker 를 여기서 채워요)
function Missions.start(office, boss, dayCycle, remotes, api, hooks, coworkers)
	-- 사람마다: { day, startMinute, mission, step, endsAt, progress, status, puzzle, ... }
	local states: { [Player]: any } = {}
	local boxes: { [Player]: { BasePart } } = {}

	local function currentStep(state)
		return state.mission and state.mission.steps[state.step]
	end

	local function publish(player: Player, state)
		player:SetAttribute("MissionId", if state.mission then state.mission.id else "")
		player:SetAttribute("MissionStep", state.step or 0)
		player:SetAttribute("MissionEndsAt", state.endsAt or 0)
		player:SetAttribute("MissionProgress", state.progressText or "")
		player:SetAttribute("MissionStatus", state.status or "")
	end

	local function setSpeed(player: Player, speed: number)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = speed
		end
	end

	local function clearBoxes(player: Player)
		for _, box in boxes[player] or {} do
			box:Destroy()
		end
		boxes[player] = nil
	end

	local function finish(player: Player, state, success: boolean, reason: string?)
		if state.status ~= "active" then
			return
		end
		clearBoxes(player)
		if state.slowed then
			setSpeed(player, 16)
			state.slowed = false
		end
		state.status = if success then "success" else "fail"
		state.progressText = ""
		state.puzzle = nil
		if success then
			local text = api.reward(player, state.mission.id)
			if boss.model.Parent then
				boss:say(`오~ {player.DisplayName} 씨 일 잘하네! 👍`, 3)
			end
			remotes.Notify:FireClient(player, `📋 {state.mission.name} 성공! {text}`)
		else
			remotes.Notify:FireClient(player, `📋 {state.mission.name} 실패… {reason or ""}`)
			if boss.model.Parent and boss.active then
				boss:say("에휴… 다음엔 잘해 봐.", 3)
			end
		end
		publish(player, state)
		task.delay(6, function()
			if states[player] == state then
				state.mission = nil
				state.status = "done"
				publish(player, state)
			end
		end)
	end

	-- 📦 흩어진 택배 놓기 (사무실 곳곳 중 무작위)
	local function spawnBoxes(player: Player, state, count: number)
		clearBoxes(player)
		boxes[player] = {}
		for i, spot in shuffle(office.packageSpots) do
			if i > count then
				break
			end
			local box = Instance.new("Part")
			box.Name = "MissionBox"
			box.Size = Vector3.new(1.8, 1.6, 1.8)
			box.Position = spot + Vector3.new(0, 0.8, 0)
			box.Color = Color3.fromRGB(190, 140, 90)
			box.Material = Enum.Material.Cardboard
			box.Anchored = true
			box.CanCollide = false
			box.Parent = office.folder
			local tag = Instance.new("BillboardGui")
			tag.Size = UDim2.fromOffset(160, 30)
			tag.StudsOffset = Vector3.new(0, 2.2, 0)
			tag.AlwaysOnTop = true
			tag.MaxDistance = 200
			tag.Parent = box
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(255, 220, 120)
			label.TextStrokeTransparency = 0.3
			label.Font = Enum.Font.GothamBold
			label.Text = `📦 {player.DisplayName}`
			label.Parent = tag
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "택배 줍기"
			prompt.ObjectText = `📦 {player.DisplayName} 님 택배`
			prompt.MaxActivationDistance = 6
			prompt.RequiresLineOfSight = false
			prompt.Parent = box
			prompt.Triggered:Connect(function(who)
				if who ~= player or states[player] ~= state or state.status ~= "active" then
					return
				end
				box:Destroy()
				state.progress += 1
				state.slowed = true
				setSpeed(player, SalaryConfig.BOX_SPEEDS[math.min(state.progress, #SalaryConfig.BOX_SPEEDS)])
				state.progressText = `{state.progress}/{count}개`
				if state.progress >= count then
					state.advanceNow = true
				end
				publish(player, state)
			end)
			table.insert(boxes[player], box)
		end
	end

	local function advance(player: Player, state)
		state.step += 1
		state.progress = 0
		state.progressText = ""
		state.puzzle = nil
		state.advanceNow = false
		local step = currentStep(state)
		if not step then
			finish(player, state, true)
			return
		end
		if step.kind == "stamps" then
			-- 결재 도장 받을 동료를 정해요 (지금 사무실에 있는 동료 중에서)
			local names = shuffle(coworkers.names())
			state.stamps = {}
			for i = 1, math.min(step.count or 1, #names) do
				table.insert(state.stamps, names[i])
			end
			if #state.stamps == 0 then
				advance(player, state) -- 동료가 아무도 없으면 건너뛰어요
				return
			end
			state.progressText = "남은 도장: " .. table.concat(state.stamps, ", ")
		elseif step.kind == "boxes" then
			spawnBoxes(player, state, step.count or 3)
			state.progressText = `0/{step.count or 3}개`
		elseif step.kind == "answer" then
			state.ringUntil = workspace:GetServerTimeNow() + ANSWER_SECONDS
		end
		publish(player, state)
	end

	-- 오늘의 프로젝트 정하기 (출근할 때 / 처음 들어왔을 때)
	local function schedule(player: Player)
		local windows = {}
		for _, window in SalaryConfig.MISSION_WINDOWS do
			if window[2] > dayCycle.minute + 5 then
				table.insert(windows, window)
			end
		end
		local state = { day = dayCycle.day, status = "", step = 0 }
		if RunService:IsStudio() and SalaryConfig.Missions[SalaryConfig.TEST_MISSION] then
			state.startMinute = math.ceil(dayCycle.minute) + 15 -- 🧪 테스트: 바로 시작
		elseif #windows > 0 then
			local window = pick(windows)
			state.startMinute = math.random(math.max(window[1], math.ceil(dayCycle.minute) + 5), window[2])
		end
		states[player] = state
		publish(player, state)
	end

	local function startMission(player: Player, state)
		local choices = {}
		for _, mission in SalaryConfig.Missions do
			if not mission.company or mission.company == office.companyId then
				table.insert(choices, mission)
			end
		end
		state.mission = pick(choices)
		if RunService:IsStudio() and SalaryConfig.Missions[SalaryConfig.TEST_MISSION] then
			state.mission = SalaryConfig.Missions[SalaryConfig.TEST_MISSION]
		end
		state.status = "active"
		state.startedAt = workspace:GetServerTimeNow()
		state.endsAt = state.startedAt + state.mission.seconds
		state.step = 0
		if boss.model.Parent then
			boss:say(`{player.DisplayName} 씨! 긴급 프로젝트야! {state.mission.emoji} {state.mission.name}!`, 4)
		end
		remotes.Notify:FireClient(player, `📋 긴급 프로젝트: {state.mission.emoji} {state.mission.name}! {state.mission.seconds}초 안에 끝내면 경고 -1`)
		advance(player, state)
	end

	---------------------------------------------------------------- 상호작용
	-- 🖨️ 프린터 (Employees의 프린터 [E]가 먼저 물어봐요)
	hooks.printer = function(player: Player): boolean
		local state = states[player]
		local step = state and state.status == "active" and currentStep(state)
		if step and step.kind == "printer" then
			advance(player, state)
			return true
		end
		return false
	end

	-- 🖊️ 동료 결재 도장 (동료 [E] 수다 떨기가 먼저 물어봐요)
	hooks.coworker = function(player: Player, coworker): boolean
		local state = states[player]
		local step = state and state.status == "active" and currentStep(state)
		if not step or step.kind ~= "stamps" then
			return false
		end
		local index = table.find(state.stamps, coworker.name)
		if not index then
			remotes.Notify:FireClient(player, `🖊️ {coworker.name}: "저 말고 {table.concat(state.stamps, ", ")}한테 받아요~"`)
			return true
		end
		table.remove(state.stamps, index)
		remotes.Notify:FireClient(player, `🖊️ {coworker.name}: "쾅! 결재 도장 찍었어요"`)
		if #state.stamps == 0 then
			advance(player, state)
		else
			state.progressText = "남은 도장: " .. table.concat(state.stamps, ", ")
			publish(player, state)
		end
		return true
	end

	-- 🚨 적발되면 실패
	hooks.caught = function(player: Player)
		local state = states[player]
		if state and state.status == "active" then
			finish(player, state, false, "부장님한테 걸려서 프로젝트가 날아갔어요!")
		end
	end

	-- 👔 부장님께 말 걸기: 제출 / 선물
	local bossPrompt = Instance.new("ProximityPrompt")
	bossPrompt.ActionText = "말 걸기 (제출·선물)"
	bossPrompt.ObjectText = "👔 김부장"
	bossPrompt.MaxActivationDistance = TALK_RANGE
	bossPrompt.RequiresLineOfSight = false
	bossPrompt.Parent = boss.root
	bossPrompt.Triggered:Connect(function(player)
		if not boss.active then
			return
		end
		local state = states[player]
		local step = state and state.status == "active" and currentStep(state)
		if step and step.kind == "boss" then
			advance(player, state)
			return
		end
		local gave, line, text = api.giveGift(player)
		if line ~= "" then
			boss:say(line, 3)
		end
		if text ~= "" then
			remotes.Notify:FireClient(player, text)
		end
		if not gave and line == "" then
			boss:say(pick(IDLE_LINES), 2)
		end
	end)

	---------------------------------------------------------------- 🧩 퍼즐
	-- 이 퍼즐은 어디서 풀어야 하나?
	local function puzzlePlaceOk(player: Player, d, kind: string): (boolean, string?)
		if kind == "order" then
			return d.state == "meeting", "📊 회의실 의자에 앉아서 풀어요!"
		end
		return api.isSeated(player), "⌨️ 내 자리에 앉아서 풀어요!"
	end

	remotes.MissionPuzzle.OnServerInvoke = function(player: Player, action: any, answer: any)
		if not allowPuzzle(player) then
			return { ok = false, message = "천천히!" }
		end
		local state = states[player]
		local step = state and state.status == "active" and currentStep(state)
		local d = api.get(player)
		if not step or not d then
			return { ok = false, message = "지금은 풀 퍼즐이 없어요." }
		end
		local kind = step.kind
		if kind ~= "typing" and kind ~= "math" and kind ~= "memory" and kind ~= "order" then
			return { ok = false, message = "지금 단계는 퍼즐이 아니에요." }
		end
		local placeOk, placeMessage = puzzlePlaceOk(player, d, kind)
		if not placeOk then
			return { ok = false, message = placeMessage }
		end

		if action == "open" then
			-- 문제 만들기 (이미 있으면 그대로)
			if not state.puzzle then
				if kind == "typing" then
					state.puzzle = { kind = kind, items = table.move(shuffle(SalaryConfig.TypingPhrases), 1, step.count or 3, 1, {}), index = 1 }
				elseif kind == "math" then
					state.puzzle = { kind = kind, problems = makeMath(step.count or 8), index = 1 }
				elseif kind == "memory" then
					state.puzzle = { kind = kind, code = tostring(math.random(10000, 99999)), shownAt = workspace:GetServerTimeNow(), held = 0 }
				elseif kind == "order" then
					local numbers = {}
					for i = 1, step.count or 6 do
						table.insert(numbers, i)
					end
					state.puzzle = { kind = kind, numbers = shuffle(numbers) }
				end
			end
			local puzzle = state.puzzle
			if kind == "typing" then
				return { ok = true, kind = kind, text = puzzle.items[puzzle.index], index = puzzle.index, total = #puzzle.items }
			elseif kind == "math" then
				return { ok = true, kind = kind, text = puzzle.problems[puzzle.index].text, index = puzzle.index, total = #puzzle.problems }
			elseif kind == "memory" then
				-- 번호는 처음 몇 초만 보여 줘요
				local showing = workspace:GetServerTimeNow() - puzzle.shownAt < SalaryConfig.MEMORY_SHOW
				return {
					ok = true,
					kind = kind,
					code = if showing then puzzle.code else nil,
					showUntil = puzzle.shownAt + SalaryConfig.MEMORY_SHOW,
					hold = SalaryConfig.MEMORY_HOLD,
				}
			else
				return { ok = true, kind = kind, numbers = puzzle.numbers }
			end
		elseif action == "answer" then
			local puzzle = state.puzzle
			if not puzzle then
				return { ok = false, message = "먼저 퍼즐을 열어 주세요." }
			end
			if kind == "typing" then
				local typed = if typeof(answer) == "string" then answer else ""
				typed = string.gsub(string.gsub(typed, "^%s+", ""), "%s+$", "")
				if typed ~= puzzle.items[puzzle.index] then
					return { ok = true, correct = false, message = "❌ 오타! 다시 쳐요", text = puzzle.items[puzzle.index], index = puzzle.index, total = #puzzle.items }
				end
				puzzle.index += 1
				state.progressText = `{puzzle.index - 1}/{#puzzle.items}문장`
				if puzzle.index > #puzzle.items then
					advance(player, state)
					return { ok = true, correct = true, done = true }
				end
				publish(player, state)
				return { ok = true, correct = true, text = puzzle.items[puzzle.index], index = puzzle.index, total = #puzzle.items }
			elseif kind == "math" then
				if tonumber(answer) ~= puzzle.problems[puzzle.index].answer then
					-- 하나라도 틀리면 새 문제로 처음부터
					puzzle.problems = makeMath(#puzzle.problems)
					puzzle.index = 1
					state.progressText = `0/{#puzzle.problems}문제`
					publish(player, state)
					return { ok = true, correct = false, message = "❌ 틀렸어요! 새 문제로 처음부터", text = puzzle.problems[1].text, index = 1, total = #puzzle.problems }
				end
				puzzle.index += 1
				state.progressText = `{puzzle.index - 1}/{#puzzle.problems}문제`
				if puzzle.index > #puzzle.problems then
					advance(player, state)
					return { ok = true, correct = true, done = true }
				end
				publish(player, state)
				return { ok = true, correct = true, text = puzzle.problems[puzzle.index].text, index = puzzle.index, total = #puzzle.problems }
			elseif kind == "memory" then
				if puzzle.held < SalaryConfig.MEMORY_HOLD then
					return { ok = true, correct = false, message = `☎️ 아직 통화 중! {math.ceil(SalaryConfig.MEMORY_HOLD - puzzle.held)}초 더 일하며 버텨요` }
				end
				if tostring(answer) ~= puzzle.code then
					finish(player, state, false, `주문번호를 틀렸어요! (정답 {puzzle.code})`)
					return { ok = true, correct = false, done = true, message = `❌ 정답은 {puzzle.code}… 거래처가 화났어요` }
				end
				advance(player, state)
				return { ok = true, correct = true, done = true }
			elseif kind == "order" then
				local sorted = typeof(answer) == "table" and #answer == #puzzle.numbers
				if sorted then
					for i, n in answer do
						if n ~= i then
							sorted = false
							break
						end
					end
				end
				if not sorted then
					puzzle.numbers = shuffle(puzzle.numbers)
					return { ok = true, correct = false, message = "❌ 순서가 틀렸어요! 다시 섞었어요", numbers = puzzle.numbers }
				end
				advance(player, state)
				return { ok = true, correct = true, done = true }
			end
		end
		return { ok = false, message = "잘못된 요청이에요." }
	end

	---------------------------------------------------------------- 매 틱 확인
	task.spawn(function()
		while true do
			local dt = task.wait(0.2)
			bossPrompt.Enabled = boss.active
			for _, player in Players:GetPlayers() do
				local d = api.get(player)
				if not d then
					continue
				end
				local state = states[player]
				if not state or state.day ~= dayCycle.day then
					schedule(player)
					state = states[player]
				end
				if d.fired or dayCycle.phase == "offwork" then
					if state.status == "active" then
						finish(player, state, false, "퇴근 시간이 됐어요.")
					end
					continue
				end
				if state.status == "" and state.startMinute and dayCycle.phase == "work" and dayCycle.minute >= state.startMinute then
					startMission(player, state)
				end
				if state.status ~= "active" then
					continue
				end
				local now = workspace:GetServerTimeNow()
				if now > state.endsAt then
					finish(player, state, false, "시간 초과!")
					continue
				end
				if state.advanceNow then
					advance(player, state)
					continue
				end
				local step = currentStep(state)
				if step.kind == "answer" then
					local left = math.max(0, math.ceil(state.ringUntil - now))
					state.progressText = `📳 따르릉! {left}초`
					if api.isSeated(player) then
						advance(player, state)
						continue
					elseif now > state.ringUntil then
						finish(player, state, false, "전화가 끊겼어요…")
						continue
					end
				elseif step.kind == "memory" and state.puzzle then
					-- 번호를 본 뒤에는 자리에서 일하기 상태로 버텨야 해요 (딴짓하면 거래처가 끊어요)
					local puzzle = state.puzzle
					if now - puzzle.shownAt >= SalaryConfig.MEMORY_SHOW and puzzle.held < SalaryConfig.MEMORY_HOLD then
						if d.state ~= "work" then
							finish(player, state, false, "통화 중에 딴짓하다 거래처가 끊었어요!")
							continue
						end
						puzzle.held += dt
						state.progressText = `통화 {math.floor(puzzle.held)}/{SalaryConfig.MEMORY_HOLD}초`
					elseif puzzle.held >= SalaryConfig.MEMORY_HOLD then
						state.progressText = "번호 입력하기! (🧩 풀기)"
					end
				end
				publish(player, state)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		clearBoxes(player)
		states[player] = nil
	end)
end

return Missions
