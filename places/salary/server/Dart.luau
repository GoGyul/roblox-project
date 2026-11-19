-- 🎈 풍선 다트 (뽑기 천국 가게)
--   [E] 풍선 다트 → 시작(1,000원) → 다트 3개. 노릴 풍선을 직접 콕 누르면 던져요!
--   🤚 손이 살짝 떨려서 다트는 고른 풍선 근처 어딘가에 꽂혀요 (DART_SCATTER: 던질수록 더 많이 빗나가요)
--   풍선 12개 뒤에는 경품이 숨어 있어요 (꽝, 돈, 티켓, 인형, 아주 드물게 전설 인형). → 고르기 + 운 게임
--
-- 🛡️ 경품 배치와 손 떨림은 서버가 정해요. 화면은 "몇 번 풍선을 노렸는지"만 보내고,
--   서버가 떨림을 더한 자리로 어떤 풍선에 맞았는지 계산해요. 경품은 터진 다음에만 알려 줘요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)

local Dart = {}

local RANGE = 10
local allowAction = RateLimit.new(0.15) -- (화면이 던지는 중엔 또 못 던지게 막아 줘요)

local function shuffle<T>(list: { T })
	for i = #list, 2, -1 do
		local j = math.random(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

-- 이번 판 풍선 12개에 경품 섞기
local function makeBoard(): { string }
	local prizes = {}
	for _, prize in SalaryConfig.DartPrizes do
		for _ = 1, prize.count do
			table.insert(prizes, prize.id)
		end
	end
	if math.random() < SalaryConfig.DART_LEGEND_CHANCE then
		local index = table.find(prizes, "none")
		if index then
			prizes[index] = "legend"
		end
	end
	shuffle(prizes)
	return prizes
end

local function balloonAt(x: number, y: number): number?
	local cols, rows = SalaryConfig.DART_COLS, SalaryConfig.DART_ROWS
	for row = 0, rows - 1 do
		for col = 0, cols - 1 do
			local cx, cy = (col + 0.5) / cols, (row + 0.5) / rows
			if math.abs(x - cx) <= SalaryConfig.DART_HIT_X and math.abs(y - cy) <= SalaryConfig.DART_HIT_Y then
				return row * cols + col + 1
			end
		end
	end
	return nil
end

-- hooks.charge(player, amount) → (ok, message)
-- hooks.prize(player, prizeId) → 보여 줄 경품 이름 (돈·티켓·인형 지급)
function Dart.start(office, remotes, hooks)
	local dart = office.dart
	if not dart then
		return -- 눈치물산에만 있어요
	end
	local sessions: { [Player]: any } = {}

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = `풍선 다트 ({SalaryConfig.DART_PRICE}원)`
	prompt.ObjectText = "🎈 풍선 다트"
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = dart.counter
	prompt.Triggered:Connect(function(player)
		remotes.DartOpen:FireClient(player)
	end)

	local function near(player: Player): boolean
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return root ~= nil and (root.Position - dart.counter.Position).Magnitude <= RANGE
	end

	remotes.Dart.OnServerInvoke = function(player: Player, action: any, target: any)
		if not allowAction(player) then
			return { ok = false, message = "천천히 던져 주세요." }
		end
		if action == "start" then
			if not near(player) then
				return { ok = false, message = "풍선 다트 앞에서 해 주세요!" }
			end
			local ok, message = hooks.charge(player, SalaryConfig.DART_PRICE)
			if not ok then
				return { ok = false, message = message }
			end
			sessions[player] = {
				board = makeBoard(),
				popped = {},
				left = SalaryConfig.DART_COUNT,
			}
			return { ok = true, left = SalaryConfig.DART_COUNT }
		elseif action == "throw" then
			local session = sessions[player]
			if not session or session.left <= 0 then
				return { ok = false, message = "먼저 시작을 눌러 주세요." }
			end
			-- 🛡️ 노린 풍선 번호 검사 (없는 번호·이미 터진 풍선은 다트를 안 써요)
			local cols, rows = SalaryConfig.DART_COLS, SalaryConfig.DART_ROWS
			if typeof(target) ~= "number" or target % 1 ~= 0 or target < 1 or target > cols * rows then
				return { ok = false, message = "풍선을 골라 주세요." }
			end
			if session.popped[target] then
				return { ok = false, message = "이미 터진 풍선이에요! 다른 풍선을 골라요." }
			end
			-- 🤚 손 떨림: 몇 번째 다트인지에 따라 반지름이 커져요 (원 안 아무 데나 고르게)
			local throwIndex = SalaryConfig.DART_COUNT - session.left + 1
			session.left -= 1
			local radius = SalaryConfig.DART_SCATTER[throwIndex] or SalaryConfig.DART_SCATTER[#SalaryConfig.DART_SCATTER]
			local spread = radius * math.sqrt(math.random())
			local angle = math.random() * math.pi * 2
			local col, row = (target - 1) % cols, math.floor((target - 1) / cols)
			local x = math.clamp((col + 0.5) / cols + math.cos(angle) * spread, 0.01, 0.99)
			local y = math.clamp((row + 0.5) / rows + math.sin(angle) * spread * SalaryConfig.DART_ASPECT, 0.01, 0.99)
			local balloon = balloonAt(x, y)
			local result = { ok = true, x = x, y = y, target = target, left = session.left }
			if balloon and not session.popped[balloon] then
				session.popped[balloon] = true
				local prizeId = session.board[balloon]
				result.balloon = balloon
				result.prizeId = prizeId
				result.prizeName = hooks.prize(player, prizeId)
			end
			if session.left <= 0 then
				-- 다 던졌으면 남은 풍선 속도 공개 (뭐가 있었는지 구경)
				result.reveal = session.board
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
