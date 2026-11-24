-- 🎯 끌어서 던지기 풍선 다트 (뽑기 천국 가게)
--   [E] 풍선 다트 → 이번 풍선 벽을 먼저 구경 → 시작(1,000원) → 다트 3개
--   풍선마다 경품이 다 보여요: 💰 50·100·200·300원 (가끔 3,000원 대박!), 🎟️ 티켓, 🧸 인형, 💨 꽝
--   다트를 뒤로 끌었다 놓으면 포물선으로 날아가요 (힘·각도는 SalaryConfig.dartFlight)
--
-- 🛡️ 풍선 벽(경품·자리·흔들림)은 서버가 만들고 들고 있어요.
--   화면은 "각도, 힘, 놓은 시각"만 보내고, 서버가 같은 공식(SalaryConfig.dartSimulate)으로
--   어느 풍선에 맞았는지 다시 계산해서 경품을 주고 결과를 돌려줘요 (화면은 그대로 애니메이션만).
--   숨긴 건 🧸 인형 풍선이 🦄 전설 인형일지 뿐이에요 (터질 때 서버가 정해요).
--   창을 닫아도 판은 그대로 남아 있어요 → 다시 열면 이어서 던져요 (돈을 또 내지 않아요).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)

local Dart = {}

local RANGE = 10
local allowAction = RateLimit.new(0.15)

local function shuffle<T>(list: { T })
	for i = #list, 2, -1 do
		local j = math.random(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

local function between(low: number, high: number): number
	return low + math.random() * (high - low)
end

-- 🎲 경품 목록 섞기 (🧸 인형 풍선은 DART_PLUSH_CHANCE 확률로만, 아니면 꽝)
local function shuffledPrizes(list: { string }): { string }
	local ids = table.clone(list)
	for i, id in ids do
		if id == "plush" and math.random() >= SalaryConfig.DART_PLUSH_CHANCE then
			ids[i] = "none"
		end
	end
	shuffle(ids)
	return ids
end

-- 🎲 새 풍선 벽 만들기: 가까운 자리엔 작은 경품, 먼 자리엔 큰 경품
--   먼 자리 하나는 🎰 대박 자리 (작고 빨리 흔들려요)
local function makeWall(): { any }
	local farSlots = {}
	for index, slot in SalaryConfig.DART_SLOTS do
		if slot.far then
			table.insert(farSlots, index)
		end
	end
	local jackpotSlot = farSlots[math.random(1, #farSlots)]
	local nearIds = shuffledPrizes(SalaryConfig.DART_NEAR_PRIZES)
	local farIds = shuffledPrizes(SalaryConfig.DART_FAR_PRIZES)
	local balloons = {}
	for index, slot in SalaryConfig.DART_SLOTS do
		if index == jackpotSlot then
			balloons[index] = {
				id = if math.random() < SalaryConfig.DART_JACKPOT_CHANCE then "jackpot" else "won300",
				x = slot.x,
				y = slot.y,
				r = 16,
				amp = 12,
				period = between(1.6, 2),
				phase = between(0, 2 * math.pi),
			}
		else
			local pool = if slot.far then farIds else nearIds
			balloons[index] = {
				id = table.remove(pool) or "none",
				x = slot.x + between(-6, 6),
				y = slot.y + between(-5, 5),
				r = 20,
				amp = between(5, 8),
				period = between(2.4, 3.4),
				phase = between(0, 2 * math.pi),
			}
		end
	end
	return balloons
end

-- 화면에서 놓은 시각을 쓰되, 서버가 받은 시각과 너무 다르면 서버 시각으로 (다른 게임과 같은 규칙)
local function releaseTime(clientTime: any): number
	local now = workspace:GetServerTimeNow()
	if typeof(clientTime) == "number" and clientTime <= now + 0.05 and clientTime >= now - 0.35 then
		return clientTime
	end
	return now
end

-- 🛡️ 숫자 검사 (NaN·무한대 거르기)
local function finite(value: any): boolean
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- hooks.charge(player, amount) → (ok, message)
-- hooks.prize(player, prizeIds) → 화면에 보여 줄 이름들 (같은 순서, 돈·티켓·인형 지급)
function Dart.start(office, remotes, hooks)
	local dart = office.dart
	if not dart then
		return -- 눈치물산에만 있어요
	end
	-- sessions[player] = { balloons, start, popped, left, paid, money, tickets }
	--   paid = false: 아직 구경만 하는 판 (닫았다 열어도 같은 판이라 마음에 들 때까지 새로 섞을 순 없어요)
	local sessions: { [Player]: any } = {}

	-- 🪪 사원증 등급: 직급이 모자라면 구경만
	local function badgeOk(player: Player): boolean
		local need = SalaryConfig.BADGE.dart
		if ((player:GetAttribute("Rank") :: number?) or 1) >= need then
			return true
		end
		remotes.Notify:FireClient(player, `🪪 사원증 등급이 모자라요! 🎯 풍선 다트는 {SalaryConfig.Ranks[need].name}부터 이용할 수 있어요.`)
		return false
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = `풍선 다트 ({SalaryConfig.DART_PRICE}원)`
	prompt.ObjectText = "🎯 풍선 다트"
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = dart.counter
	prompt.Triggered:Connect(function(player)
		if not badgeOk(player) then
			return
		end
		remotes.DartOpen:FireClient(player)
	end)

	local function near(player: Player): boolean
		if ((player:GetAttribute("Rank") :: number?) or 1) < SalaryConfig.BADGE.dart then
			return false -- 🪪 사원증 등급이 모자라요 (창을 안 거치고 보낸 요청도 막아요)
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return root ~= nil and (root.Position - dart.counter.Position).Magnitude <= RANGE
	end

	-- 화면에 보낼 판 상태 (풍선 경품은 원래 다 보여요)
	local function view(session: any): any
		local popped = {}
		for index in session.popped do
			table.insert(popped, index)
		end
		return {
			ok = true,
			balloons = session.balloons,
			start = session.start,
			popped = popped,
			left = session.left,
			paid = session.paid,
			money = session.money,
			tickets = session.tickets,
		}
	end

	remotes.Dart.OnServerInvoke = function(player: Player, action: any, angle: any, power: any, clientTime: any)
		if not allowAction(player) then
			return { ok = false, message = "천천히 던져 주세요." }
		end
		if action == "open" then
			-- 하던 판이 있으면 그대로 이어서, 없으면 새 판을 구경시켜 줘요 (돈은 시작할 때 내요)
			local session = sessions[player]
			if not session then
				if not near(player) then
					return { ok = false, message = "풍선 다트 앞에서 해 주세요!" }
				end
				session = {
					balloons = makeWall(),
					start = workspace:GetServerTimeNow(),
					popped = {},
					left = 0,
					paid = false,
					money = 0,
					tickets = 0,
				}
				sessions[player] = session
			end
			return view(session)
		elseif action == "start" then
			local session = sessions[player]
			if not session then
				return { ok = false, message = "창을 다시 열어 주세요." }
			end
			if session.paid then
				return view(session) -- 이미 낸 판 (두 번 안 받아요)
			end
			if not near(player) then
				return { ok = false, message = "풍선 다트 앞에서 해 주세요!" }
			end
			local ok, message = hooks.charge(player, SalaryConfig.DART_PRICE)
			if not ok then
				return { ok = false, message = message }
			end
			session.paid = true
			session.left = SalaryConfig.DART_COUNT
			return view(session)
		elseif action == "throw" then
			local session = sessions[player]
			if not session or not session.paid or session.left <= 0 then
				return { ok = false, message = "먼저 시작을 눌러 주세요." }
			end
			-- 🛡️ 각도·힘 검사 (이상한 값은 다트를 안 써요)
			local minAngle = SalaryConfig.DART_MIN_ANGLE
			if not finite(angle) or not finite(power) or angle < minAngle - 0.001 or angle > math.pi - minAngle + 0.001 or power < SalaryConfig.DART_MIN_POWER - 0.001 or power > 1.001 then
				return { ok = false, message = "다시 던져 주세요." }
			end
			angle = math.clamp(angle, minAngle, math.pi - minAngle)
			power = math.clamp(power, SalaryConfig.DART_MIN_POWER, 1)
			local release = releaseTime(clientTime)
			session.left -= 1
			local hit, flightTime, landing, reason = SalaryConfig.dartSimulate(session.balloons, session.popped, angle, power, release - session.start)
			local result: any = {
				ok = true,
				angle = angle,
				power = power,
				release = release, -- (화면은 이 시각 기준으로 날아가는 모습을 그려요)
				flightTime = flightTime,
				landing = { x = landing.X, y = landing.Y },
				reason = reason,
				money = 0,
				tickets = 0,
				name = "",
			}
			if hit then
				session.popped[hit] = true
				local id = session.balloons[hit].id
				if id == "plush" and math.random() < SalaryConfig.DART_LEGEND_CHANCE then
					id = "legend" -- 🦄 인형 풍선 속에서 아주 가끔 전설 인형!
				end
				local names = hooks.prize(player, { id })
				local info = SalaryConfig.getDartPrize(session.balloons[hit].id)
				result.hit = hit
				result.id = id
				result.money = if info and info.money then info.money else 0
				result.tickets = if info and info.tickets then info.tickets else 0
				result.name = names[1] or ""
				session.money += result.money
				session.tickets += result.tickets
			end
			result.left = session.left
			result.total = session.money
			result.totalTickets = session.tickets
			-- 다 던졌거나 풍선이 다 터지면 판 끝
			local remaining = 0
			for index in session.balloons do
				if not session.popped[index] then
					remaining += 1
				end
			end
			if session.left <= 0 or remaining == 0 then
				result.left = 0
				result.finished = true
				sessions[player] = nil
			end
			return result
		end
		return { ok = false, message = "잘못된 요청이에요." }
	end

	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
end

return Dart
