-- 🧸 인형뽑기 (눈치 스트리트)
--   [E] 인형뽑기 → 화면에 기계 창(위에서 본 모습) → [시작] 500원
--   ① 집게가 좌우로 왕복 → [멈춤]  ② 앞뒤로 왕복 → [내리기]
--   → 집게 아래 인형이 걸리면: 들어 올리기(미끄러질 수 있음) → 출구까지 옮기기(떨어뜨릴 수 있음)
--   판정은 서버가 해요: 인형 배치·속도는 서버가 정하고, 집게 위치는 누른 시각으로 서버가 계산해요.
--   🛡️ 기계 근처에서만, 돈은 서버에서만 빠져요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)

local Claw = {}

local MACHINE_RANGE = 10
local allowAction = RateLimit.new(0.3)

-- hooks.charge(player, price) → (ok, message) : 돈 빼기
-- hooks.give(player, plushId) : 인형 지급
function Claw.start(office, remotes, hooks)
	if #office.clawMachines == 0 then
		return -- 눈치물산에만 있어요
	end
	local sessions: { [Player]: any } = {}

	for _, machine in office.clawMachines do
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = `인형뽑기 ({SalaryConfig.CLAW_PRICE}원)`
		prompt.ObjectText = "🧸 인형뽑기"
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.Parent = machine
		prompt.Triggered:Connect(function(player)
			remotes.ClawOpen:FireClient(player)
		end)
	end

	local function nearMachine(player: Player): boolean
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return false
		end
		for _, machine in office.clawMachines do
			if (root.Position - machine.Position).Magnitude <= MACHINE_RANGE then
				return true
			end
		end
		return false
	end

	-- 기계 안 인형 배치 만들기 (서로 너무 붙지 않게, 전설은 안쪽 깊숙이)
	local function makeLayout()
		local layout = {}
		local tries = 0
		while #layout < SalaryConfig.CLAW_PLUSH_COUNT and tries < 200 do
			tries += 1
			local plush = SalaryConfig.rollClawPlush()
			local x = math.random(10, 90) / 100
			local z = if plush.rarity == "legend" then math.random(76, 90) / 100 else math.random(10, 88) / 100
			local ok = true
			for _, other in layout do
				if (Vector2.new(x, z) - Vector2.new(other.x, other.z)).Magnitude < 0.17 then
					ok = false
					break
				end
			end
			if ok then
				table.insert(layout, { id = plush.id, x = x, z = z })
			end
		end
		return layout
	end

	-- 화면에서 누른 시각을 쓰되, 서버가 받은 시각과 너무 다르면 서버 시각으로
	local function pressTime(clickTime: any): number
		local now = workspace:GetServerTimeNow()
		if typeof(clickTime) == "number" and clickTime <= now + 0.05 and clickTime >= now - 0.6 then
			return clickTime
		end
		return now
	end

	remotes.Claw.OnServerInvoke = function(player: Player, action: any, clickTime: any)
		if not allowAction(player) then
			return { ok = false, message = "천천히 눌러 주세요." }
		end
		if action == "start" then
			if not nearMachine(player) then
				return { ok = false, message = "인형뽑기 기계 앞에서 해 주세요!" }
			end
			local ok, message = hooks.charge(player, SalaryConfig.CLAW_PRICE)
			if not ok then
				return { ok = false, message = message }
			end
			local session = {
				start = workspace:GetServerTimeNow() + 0.6, -- 화면에 뜰 시간을 조금 줘요
				periodX = math.random(13, 19) / 10, -- 좌우 왕복 시간
				periodZ = math.random(12, 17) / 10, -- 앞뒤 왕복 시간
				layout = makeLayout(),
				stopX = nil :: number?,
			}
			sessions[player] = session
			return { ok = true, start = session.start, periodX = session.periodX, periodZ = session.periodZ, layout = session.layout }
		elseif action == "stop" then
			-- ① 좌우 멈춤
			local session = sessions[player]
			if not session or session.stopX then
				return { ok = false, message = "먼저 시작을 눌러 주세요." }
			end
			session.stopX = math.max(session.start, pressTime(clickTime))
			return { ok = true, stopX = session.stopX }
		elseif action == "drop" then
			-- ② 앞뒤 멈추고 내리기 → 판정
			local session = sessions[player]
			if not session or not session.stopX then
				return { ok = false, message = "먼저 [멈춤]을 눌러 주세요." }
			end
			sessions[player] = nil
			local zStart = session.stopX + SalaryConfig.CLAW_GAP
			local dropTime = math.max(zStart, pressTime(clickTime))
			local x = SalaryConfig.clawPosition(session.stopX - session.start, session.periodX)
			local z = SalaryConfig.clawPosition(dropTime - zStart, session.periodZ)

			-- 집게 바로 아래(가장 가까운) 인형
			local target, distance = nil, math.huge
			for _, item in session.layout do
				local d = (Vector2.new(item.x, item.z) - Vector2.new(x, z)).Magnitude
				if d < distance then
					target, distance = item, d
				end
			end
			local result = { ok = true, x = x, z = z, outcome = "miss" }
			if target and distance <= SalaryConfig.CLAW_RADIUS then
				local plush = SalaryConfig.getPlush(target.id) :: SalaryConfig.PlushInfo
				local accuracy = 1 - distance / SalaryConfig.CLAW_RADIUS -- 1이면 정중앙
				local grip = (SalaryConfig.CLAW_GRIP[plush.rarity] or 0.5) * (0.6 + 0.4 * accuracy)
				local carry = SalaryConfig.CLAW_CARRY + 0.15 * accuracy
				-- ⚖️ 균형감: 미끄러질(놓칠) 확률이 줄어요 (최대 -30%)
				local steady = 1 - SalaryConfig.playerFitnessEffect(player, "claw")
				grip = 1 - (1 - grip) * steady
				carry = 1 - (1 - math.min(1, carry)) * steady
				result.plushId = plush.id
				result.accuracy = math.floor(accuracy * 100)
				if math.random() >= grip then
					result.outcome = "slip" -- 들어 올리다 미끄러짐
				elseif math.random() >= carry then
					result.outcome = "drop" -- 출구까지 옮기다 툭
				else
					result.outcome = "win"
					hooks.give(player, plush.id)
				end
			end
			return result
		end
		return { ok = false, message = "잘못된 요청이에요." }
	end

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
end

return Claw
