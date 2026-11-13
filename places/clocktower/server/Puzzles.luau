-- 퍼즐 로직: 탑 안의 물건마다 [E] 상호작용을 달고, 풀었을 때 무슨 일이 일어나는지 정해요.
-- 퍼즐 진행 상황(state)은 서버 전체가 공유해요. (같은 서버의 플레이어는 한 팀)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(script.Parent.Inventory)
local Remotes = require(script.Parent.Remotes)
local TowerBuilder = require(script.Parent.TowerBuilder)

local Puzzles = {}

-- 정답들 (서버에만 있어요)
local DRAWER_CODE = "375" -- 1층 멈춘 시계 세 개
local SAFE_CODE = "1892" -- 2층 과거 칠판
local BELL_HOUR = 9 -- 1층 과거 일기장

local state = {
	drawerOpened = false,
	seedPlanted = false,
	safeOpened = false,
	gears = {} :: { [string]: boolean },
	hour = 12,
	solved = false,
}

---------------------------------------------------------------------------
-- 도우미
---------------------------------------------------------------------------
local function notify(player: Player, text: string)
	Remotes.Notify:FireClient(player, text)
end

local function showNote(player: Player, title: string, body: string)
	Remotes.ShowNote:FireClient(player, title, body)
end

local function prompt(part: BasePart, action: string, object: string, callback: (Player) -> ()): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.MaxActivationDistance = 9
	p.RequiresLineOfSight = false
	p.Parent = part
	p.Triggered:Connect(callback)
	return p
end

-- 비밀번호 자물쇠: 정답 확인은 항상 서버에서
local locks = {}

local function codeLock(id: string, part: BasePart, title: string, code: string, onSolved: (Player) -> ())
	locks[id] = { part = part, code = code, onSolved = onSolved, solved = false }
	return function(player: Player)
		if not locks[id].solved then
			Remotes.OpenCodeLock:FireClient(player, id, #code, title)
		end
	end
end

Remotes.SubmitCode.OnServerInvoke = function(player: Player, id: any, code: any)
	if typeof(id) ~= "string" or typeof(code) ~= "string" then
		return false
	end
	local lock = locks[id]
	if not lock or lock.solved then
		return false
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - lock.part.Position).Magnitude > 15 then
		return false
	end
	if code ~= lock.code then
		return false
	end
	lock.solved = true
	lock.onSolved(player)
	return true
end

---------------------------------------------------------------------------
-- 시작
---------------------------------------------------------------------------
function Puzzles.start(tower)
	local present, past = tower.refs.present, tower.refs.past
	local spinning: { { model: Model, base: CFrame, speed: number } } = {}

	-- 과거의 기계장치는 처음부터 돌아가요
	for _, gear in past.gearSlots do
		table.insert(spinning, gear)
	end

	---------------------------------------------------------------- 1층
	-- 현재: 멈춘 시계 세 개 (3시, 7시, 5시) → 서랍 비밀번호 375
	present.wallClocks[1](3, 0)
	present.wallClocks[2](7, 0)
	present.wallClocks[3](5, 0)
	present.bigClock(state.hour, 0)

	prompt(present.note, "읽기", "구겨진 쪽지", function(player)
		showNote(
			player,
			"구겨진 쪽지",
			"서랍 비밀번호는 잊어버리지 않도록\n멈춰 버린 시계들에게 맡겨 두었다.\n\n왼쪽부터 차례대로."
		)
	end)

	local drawerPrompt
	drawerPrompt = prompt(present.drawer, "열기", "잠긴 서랍", codeLock("drawer", present.drawer, "서랍 자물쇠", DRAWER_CODE, function(player)
		state.drawerOpened = true
		drawerPrompt.ObjectText = "빈 서랍"
		Inventory.give(player, "watch")
		showNote(
			player,
			"회중시계를 얻었다!",
			"뚜껑에 시계공의 이름이 새겨진 낡은 회중시계다.\n태엽을 감자 주변의 공기가 일렁인다.\n\n[T] 키 (또는 화면 위 버튼)로 과거와 현재를 오갈 수 있다."
		)
	end))
	drawerPrompt.Triggered:Connect(function(player)
		if state.drawerOpened then
			notify(player, "서랍은 비어 있다.")
		end
	end)

	prompt(past.drawer, "열기", "서랍", function(player)
		notify(player, "반짝이는 새 서랍이다. 안에는 시계 수리 도구만 가지런히 놓여 있다.")
	end)

	prompt(present.rubble, "살펴보기", "무너진 들보", function(player)
		notify(player, "무너진 들보가 계단 문을 막고 있다. 이 문이 멀쩡하던 시절도 있었을 텐데…")
	end)

	prompt(past.diary, "읽기", "시계공의 일기", function(player)
		showNote(
			player,
			"시계공의 일기",
			"매일 아침 9시 정각, 탑의 종을 울리는 것이 나의 일이다.\n이 탑의 시계가 멈추는 날엔 마을의 시간도 함께 멈추겠지.\n\n중요한 물건은 2층 금고에 넣어 두었다.\n번호는 칠판에 적어 두었으니 잊을 일은 없을 것이다."
		)
	end)

	---------------------------------------------------------------- 2층
	prompt(present.seed, "줍기", "오래된 씨앗 봉투", function(player)
		Inventory.give(player, "seed")
		notify(player, "오래된 씨앗을 얻었다. 아직 싹을 틔울 수 있을까?")
		present.seed:Destroy()
	end)

	local presentPotPrompt = prompt(present.pot, "살펴보기", "말라 버린 화분", function(player)
		notify(player, "흙이 바싹 말라 갈라진 화분이다. 여기서는 아무것도 자랄 것 같지 않다.")
	end)

	local function growTree()
		local B = tower.builders.present
		local y = TowerBuilder.floorY(2)
		local bark = { Color = Color3.fromRGB(95, 65, 40), Material = Enum.Material.Wood }
		local leaf = { Color = Color3.fromRGB(70, 130, 60), Material = Enum.Material.Grass }

		presentPotPrompt:Destroy()
		present.pot:Destroy()
		B:part(Vector3.new(2.5, 16, 2.5), Vector3.new(-10, y + 8, -10), bark)
		-- 밟고 올라갈 수 있는 가지 세 개 → 높은 선반으로
		B:part(Vector3.new(4, 1, 4), Vector3.new(-6, y + 3, -10), leaf)
		B:part(Vector3.new(4, 1, 4), Vector3.new(-10, y + 6.5, -6), leaf)
		B:part(Vector3.new(4, 1, 4), Vector3.new(-14, y + 10, -10), leaf)
		B:part(Vector3.new(9, 9, 9), Vector3.new(-10, y + 16, -10), {
			Shape = Enum.PartType.Ball,
			Color = leaf.Color,
			Material = Enum.Material.Grass,
			CanCollide = false,
			CanQuery = false,
		})

		-- 과거 화분에는 새싹
		tower.builders.past:part(Vector3.new(0.4, 1, 0.4), Vector3.new(-10, y + 2.6, -10), {
			Color = Color3.fromRGB(90, 170, 70),
		})
	end

	prompt(past.pot, "살펴보기", "흙이 담긴 화분", function(player)
		if state.seedPlanted then
			notify(player, "씨앗을 심어 두었다. 시간이 많이 흐르면 크게 자라겠지.")
		elseif Inventory.take(player, "seed") then
			state.seedPlanted = true
			growTree()
			notify(player, "씨앗을 심었다. …50년 뒤에는 어떻게 되어 있을까?")
		else
			notify(player, "기름진 흙이 담긴 화분이다. 무언가 심을 수 있을 것 같다.")
		end
	end)

	prompt(present.gearSmall, "줍기", "작은 톱니바퀴", function(player)
		Inventory.give(player, "gearSmall")
		notify(player, "작은 톱니바퀴를 얻었다!")
		present.gearSmall:Destroy()
	end)

	local safePrompt
	safePrompt = prompt(present.safe, "열기", "녹슨 금고", codeLock("safe", present.safe, "금고 다이얼", SAFE_CODE, function(player)
		state.safeOpened = true
		safePrompt.ObjectText = "빈 금고"
		Inventory.give(player, "gearMedium")
		notify(player, "끼이익… 금고가 열렸다. 중간 톱니바퀴를 얻었다!")
	end))
	safePrompt.Triggered:Connect(function(player)
		if state.safeOpened then
			notify(player, "금고는 비어 있다.")
		end
	end)

	prompt(past.safe, "열기", "새 금고", function(player)
		notify(player, "주인이 아끼는 새 금고다. 지금 열어 봐야 아직 아무것도 들어 있지 않을 것 같다.")
	end)

	prompt(past.lockedDoor, "열기", "잠긴 문", function(player)
		notify(player, "단단히 잠겨 있다. 이 시절에는 위층으로 올라갈 수 없는 것 같다.")
	end)

	---------------------------------------------------------------- 3층
	prompt(past.oil, "줍기", "기름통", function(player)
		Inventory.give(player, "oil")
		notify(player, "기름통을 얻었다. 녹슨 것에 쓰면 좋겠다.")
		past.oil:Destroy()
	end)

	local rustyPrompt
	rustyPrompt = prompt(present.rustyGear, "줍기", "녹슨 큰 톱니바퀴", function(player)
		if Inventory.take(player, "oil") then
			Inventory.give(player, "gearLarge")
			notify(player, "기름을 붓자 톱니바퀴가 바닥에서 떨어졌다! 큰 톱니바퀴를 얻었다.")
			rustyPrompt:Destroy()
			present.rustyGear:Destroy()
		else
			notify(player, "녹이 슬어 바닥에 꽉 붙어 있다. 기름칠을 하면 떨어질지도…")
		end
	end)

	prompt(present.memo, "읽기", "벽의 메모", function(player)
		showNote(
			player,
			"시계공의 마지막 메모",
			"탑의 시계를 다시 움직이려면\n\n1. 빠진 톱니바퀴 세 개를 제자리에 끼울 것\n2. 시침을 내가 매일 종을 치던 시각에 맞출 것\n3. 레버를 당길 것"
		)
	end)

	local function gearCount(): number
		local count = 0
		for _ in state.gears do
			count += 1
		end
		return count
	end

	prompt(present.mechanism, "톱니바퀴 끼우기", "멈춘 기계장치", function(player)
		local inserted = 0
		for _, slot in TowerBuilder.GEAR_SLOTS do
			if not state.gears[slot.id] and Inventory.take(player, slot.id) then
				state.gears[slot.id] = true
				inserted += 1
				local info = present.gearSlots[slot.id]
				local model, base = tower.builders.present:gear(info.position, info.radius, Color3.fromRGB(150, 120, 60))
				info.model, info.base = model, base
			end
		end
		local count = gearCount()
		if count == 3 then
			notify(player, "톱니바퀴 세 개가 모두 맞물렸다! 이제 시침을 맞추고 레버를 당겨 보자.")
		elseif inserted > 0 then
			notify(player, `톱니바퀴를 끼웠다. ({count}/3)`)
		else
			notify(player, `빈 축이 보인다. 크기가 다른 톱니바퀴가 필요하다. ({count}/3)`)
		end
	end)

	prompt(past.mechanism, "살펴보기", "돌아가는 기계장치", function(player)
		notify(player, "작은 것, 중간 것, 큰 것. 톱니바퀴 세 개가 맞물려 힘차게 돌고 있다.")
	end)

	prompt(present.clockHandle, "돌리기", "시침 손잡이", function(player)
		if state.solved then
			return
		end
		state.hour = state.hour % 12 + 1
		present.bigClock(state.hour, 0)
		notify(player, `시침을 {state.hour}시에 맞췄다.`)
	end)

	prompt(past.clockHandle, "돌리기", "시침 손잡이", function(player)
		notify(player, "시계가 잘 돌아가고 있다. 괜히 건드리지 말자.")
	end)

	local leverPrompt = prompt(present.leverHandle, "당기기", "레버", function(player)
		if state.solved then
			return
		end
		if gearCount() < 3 then
			notify(player, "덜컹… 톱니바퀴가 빠져 있어서 아무것도 움직이지 않는다.")
		elseif state.hour ~= BELL_HOUR then
			notify(player, "기계가 잠깐 움직이다 멈췄다. 시계가 엉뚱한 시각을 가리키는 것 같다.")
		else
			state.solved = true
			present.leverHandle.CFrame *= CFrame.Angles(math.rad(60), 0, 0)
			for _, slot in TowerBuilder.GEAR_SLOTS do
				table.insert(spinning, present.gearSlots[slot.id])
			end
			for _, other in Players:GetPlayers() do
				local startTime = other:GetAttribute("StartTime") or workspace:GetServerTimeNow()
				Remotes.Escaped:FireClient(other, workspace:GetServerTimeNow() - startTime)
			end
		end
	end)
	leverPrompt.HoldDuration = 0.5

	prompt(past.leverHandle, "당기기", "레버", function(player)
		notify(player, "레버는 이미 당겨져 있다. 시계가 힘차게 돌아가고 있다.")
	end)

	---------------------------------------------------------------- 움직이는 것들
	-- 톱니바퀴 회전
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for _, gear in spinning do
			gear.model:PivotTo(gear.base * CFrame.Angles(0, 0, t * gear.speed))
		end
	end)

	-- 과거의 시계들은 살아 있어요 (실제 시간으로 움직임)
	task.spawn(function()
		while true do
			local now = os.date("!*t")
			local hour, minute = now.hour + 9, now.min -- 한국 시간
			past.wallClocks[1](hour, minute)
			past.wallClocks[2](hour + 3, minute)
			past.wallClocks[3](hour - 2, minute)
			past.bigClock(hour, minute)
			task.wait(1)
		end
	end)
end

return Puzzles
