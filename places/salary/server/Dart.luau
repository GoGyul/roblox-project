-- 🎈 풍선 다트 (뽑기 천국 가게)
--   [E] 풍선 다트 → 시작(1,000원) → 다트 3개. 조준점이 저절로 흔들려요 → 노린 풍선 위에서 [던지기]!
--   풍선 12개 뒤에는 경품이 숨어 있어요 (꽝, 돈, 티켓, 인형, 아주 드물게 전설 인형).
--
-- 🛡️ 경품 배치와 조준점 움직임은 서버가 정해요. 화면은 "던진 시각"만 보내고,
--   서버가 그 시각의 조준점 위치로 어떤 풍선에 맞았는지 계산해요. 경품은 터진 다음에만 알려 줘요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)

local Dart = {}

local RANGE = 10
local allowAction = RateLimit.new(0.35)

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

	remotes.Dart.OnServerInvoke = function(player: Player, action: any, clickTime: any)
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
			local aim = {
				a = math.random(130, 230) / 100, -- 가로 흔들림 빠르기
				b = math.random(150, 260) / 100, -- 세로 흔들림 빠르기
				p = math.random() * math.pi * 2,
				q = math.random() * math.pi * 2,
			}
			sessions[player] = {
				start = workspace:GetServerTimeNow() + 0.6,
				aim = aim,
				board = makeBoard(),
				popped = {},
				left = SalaryConfig.DART_COUNT,
			}
			return { ok = true, start = sessions[player].start, aim = aim }
		elseif action == "throw" then
			local session = sessions[player]
			if not session or session.left <= 0 then
				return { ok = false, message = "먼저 시작을 눌러 주세요." }
			end
			session.left -= 1
			local now = workspace:GetServerTimeNow()
			local t = if typeof(clickTime) == "number" and clickTime <= now + 0.05 and clickTime >= now - 0.6 then clickTime else now
			local x, y = SalaryConfig.dartAim(math.max(0, t - session.start), session.aim)
			local balloon = balloonAt(x, y)
			local result = { ok = true, x = x, y = y, left = session.left }
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
