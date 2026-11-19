-- 🧸 인형뽑기 (눈치 스트리트)
--   [E] 인형뽑기 → 화면에 기계 창 → [시작] 500원 → 집게가 좌우로 왕복 → [내리기]
--   판정은 서버가 해요: 시작할 때 노릴 인형과 위치를 서버가 정하고,
--   집게 위치는 "시작 후 지난 시간"으로 계산해요 (화면과 같은 식: SalaryConfig.clawPosition).
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

	remotes.Claw.OnServerInvoke = function(player: Player, action: any, clickTime: any)
		if not allowAction(player) then
			return { ok = false, message = "천천히 눌러 주세요." }
		end
		if action == "start" then
			if sessions[player] then
				return { ok = false, message = "이미 한 판 하는 중이에요!" }
			end
			if not nearMachine(player) then
				return { ok = false, message = "인형뽑기 기계 앞에서 해 주세요!" }
			end
			local ok, message = hooks.charge(player, SalaryConfig.CLAW_PRICE)
			if not ok then
				return { ok = false, message = message }
			end
			local plush = SalaryConfig.rollClawPlush()
			local session = {
				start = workspace:GetServerTimeNow() + 0.6, -- 화면에 뜰 시간을 조금 줘요
				period = math.random(14, 20) / 10, -- 한 번 왕복하는 데 걸리는 시간
				target = math.random(12, 88) / 100, -- 노릴 인형 위치
				plush = plush,
			}
			sessions[player] = session
			return { ok = true, start = session.start, period = session.period, target = session.target, plushId = plush.id }
		elseif action == "drop" then
			local session = sessions[player]
			if not session then
				return { ok = false, message = "먼저 시작을 눌러 주세요." }
			end
			sessions[player] = nil
			-- 화면에서 누른 순간의 시각을 써요 (인터넷 지연 보정). 이상하면 서버 시각으로
			local now = workspace:GetServerTimeNow()
			local t = if typeof(clickTime) == "number" and clickTime <= now + 0.05 and clickTime >= now - 0.6 then clickTime else now
			local position = SalaryConfig.clawPosition(math.max(0, t - session.start), session.period)
			local hit = math.abs(position - session.target) <= SalaryConfig.CLAW_HIT
			local caught = hit and math.random() < SalaryConfig.CLAW_GRIP
			if caught then
				hooks.give(player, session.plush.id)
			end
			return { ok = true, hit = hit, caught = caught, position = position, plushId = session.plush.id }
		end
		return { ok = false, message = "잘못된 요청이에요." }
	end

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
end

return Claw
