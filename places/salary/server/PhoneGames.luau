-- 📱 폰 게임 (자리에서 [폰 게임] 농땡이 중에만)
--   💣 지뢰 피하기: 지뢰 위치는 서버만 알아요 (화면에는 연 칸만 알려 줘요)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)

local PhoneGames = {}

type Round = {
	bet: number,
	mines: number,
	mineSet: { [number]: boolean },
	opened: { [number]: boolean },
	count: number,
}

-- hooks: charge(player, 금액) → (ok, 메시지) / payout(player, 금액, 배당) / isPlaying(player) → 폰 게임 농땡이 중인가
--        status(player) → "playing" / "returning"(일하기로 복귀 중) / "off"
function PhoneGames.start(remotes, hooks)
	local rounds: { [Player]: Round } = {}
	local lastRequest: { [Player]: number } = {}
	local CELLS = SalaryConfig.MINES_GRID * SalaryConfig.MINES_GRID

	local function minesList(round: Round): { number }
		local list = {}
		for index in round.mineSet do
			table.insert(list, index)
		end
		return list
	end

	-- 스톱 / 최대 배당 → 돈 받기
	local function cashOut(player: Player, round: Round): number
		rounds[player] = nil
		local payout = SalaryConfig.minesPayout(round.bet, round.count, round.mines)
		hooks.payout(player, payout, SalaryConfig.minesMultiplier(round.count, round.mines))
		return payout
	end

	remotes.MinesPlay.OnServerInvoke = function(player: Player, action: any, a: any, b: any)
		local now = os.clock()
		if now - (lastRequest[player] or 0) < 0.12 then
			return { ok = false, message = "천천히!" }
		end
		lastRequest[player] = now
		if not hooks.isPlaying(player) then
			return { ok = false, message = "📱 자리에서 폰 게임 중일 때만 할 수 있어요." }
		end
		local round = rounds[player]

		if action == "start" then
			if round then
				return { ok = false, message = "이미 게임 중이에요!" }
			end
			if typeof(a) ~= "number" or not table.find(SalaryConfig.MINES_BETS, a) then
				return { ok = false, message = "💰 금액을 골라 주세요." }
			end
			local needRank = SalaryConfig.MINES_BET_RANK[a] or 1
			if hooks.rank(player) < needRank then
				return { ok = false, message = `🔒 {a}원은 {SalaryConfig.Ranks[needRank].name}부터 걸 수 있어요.` }
			end
			if typeof(b) ~= "number" or not table.find(SalaryConfig.MINES_COUNTS, b) then
				return { ok = false, message = "💣 지뢰 수를 골라 주세요." }
			end
			local paid, message = hooks.charge(player, a)
			if not paid then
				return { ok = false, message = message }
			end
			local mineSet = {}
			local placed = 0
			while placed < b do
				local index = math.random(1, CELLS)
				if not mineSet[index] then
					mineSet[index] = true
					placed += 1
				end
			end
			rounds[player] = { bet = a, mines = b, mineSet = mineSet, opened = {}, count = 0 }
			return {
				ok = true,
				total = a,
				nextGain = SalaryConfig.minesPayout(a, 1, b) - a,
			}
		elseif action == "open" then
			if not round then
				return { ok = false, message = "먼저 [시작]을 눌러 주세요." }
			end
			if typeof(a) ~= "number" or a ~= math.floor(a) or a < 1 or a > CELLS or round.opened[a] then
				return { ok = false, message = "그 칸은 열 수 없어요." }
			end
			if round.mineSet[a] then
				-- 💥 지뢰!
				rounds[player] = nil
				return { ok = true, boom = true, index = a, mines = minesList(round), lost = round.bet }
			end
			local before = SalaryConfig.minesPayout(round.bet, round.count, round.mines)
			round.opened[a] = true
			round.count += 1
			local total = SalaryConfig.minesPayout(round.bet, round.count, round.mines)
			local result = {
				ok = true,
				boom = false,
				index = a,
				gain = total - before,
				total = total,
				count = round.count,
				multiplier = SalaryConfig.minesMultiplier(round.count, round.mines),
			}
			local allOpened = round.count >= CELLS - round.mines
			local capped = SalaryConfig.minesMultiplier(round.count, round.mines) >= SalaryConfig.MINES_MAX_MULT
			if allOpened or capped then
				-- 🎉 다 열었거나 최대 배당 → 자동 스톱
				result.done = true
				result.payout = cashOut(player, round)
				result.mines = minesList(round)
				result.reason = if capped then "최대 배당 달성!" else "빈칸을 전부 찾았어요!"
			else
				result.nextGain = SalaryConfig.minesPayout(round.bet, round.count + 1, round.mines) - total
			end
			return result
		elseif action == "stop" then
			if not round then
				return { ok = false, message = "진행 중인 게임이 없어요." }
			end
			local mines = minesList(round)
			local payout = cashOut(player, round)
			return { ok = true, done = true, payout = payout, mines = mines, reason = "스톱!" }
		end
		return { ok = false, message = "잘못된 요청이에요." }
	end

	-- 폰 게임 농땡이가 끝났는데 판이 남아 있으면
	--   ✋ 내가 [일하기]를 눌러 복귀 중 → 자동 스톱 (모은 돈 받기)
	--   🚨 적발·다른 행동·자리 이탈 → 건 돈을 잃어요
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player, round in rounds do
				if not player.Parent then
					rounds[player] = nil
					continue
				end
				local status = hooks.status(player)
				if status == "returning" then
					local mines = minesList(round)
					local payout = cashOut(player, round)
					remotes.MinesForfeit:FireClient(player, mines, round.bet, payout)
				elseif status ~= "playing" then
					rounds[player] = nil
					remotes.MinesForfeit:FireClient(player, minesList(round), round.bet, nil)
				end
			end
		end
	end)

	---------------------------------------------------------------- 🧩 도형 맞추기
	type ShapeRound = { index: number, startedAt: number, limit: number, pieces: { { { number } } } }
	local shapeRounds: { [Player]: ShapeRound } = {}
	local lastPuzzle: { [Player]: number } = {}

	local function key(cells: { { number } }): string
		local parts = {}
		for _, c in SalaryConfig.normalizeCells(cells) do
			table.insert(parts, `{c[1]},{c[2]}`)
		end
		return table.concat(parts, ";")
	end

	-- 이 조각을 그대로 놓은 모양이 맞나? (돌리기·뒤집기 없음)
	local function sameShape(original: { { number } }, placed: { { number } }): boolean
		return #original == #placed and key(original) == key(placed)
	end

	remotes.ShapesPlay.OnServerInvoke = function(player: Player, action: any, placements: any)
		local now = os.clock()
		if now - (lastRequest[player] or 0) < 0.12 then
			return { ok = false, message = "천천히!" }
		end
		lastRequest[player] = now
		if not hooks.isPlaying(player) then
			return { ok = false, message = "📱 자리에서 폰 게임 중일 때만 할 수 있어요." }
		end

		if action == "start" then
			-- 방금 한 퍼즐은 빼고 랜덤
			local index = math.random(1, #SalaryConfig.ShapePuzzles)
			if #SalaryConfig.ShapePuzzles > 1 then
				while index == lastPuzzle[player] do
					index = math.random(1, #SalaryConfig.ShapePuzzles)
				end
			end
			lastPuzzle[player] = index
			local board, pieces, name = SalaryConfig.getShapePuzzle(index)
			-- 조각은 정답 모양 그대로(돌리지 않고), 순서만 섞어서 줘요
			local given = {}
			for _, piece in pieces do
				table.insert(given, SalaryConfig.normalizeCells(piece))
			end
			for i = #given, 2, -1 do
				local j = math.random(1, i)
				given[i], given[j] = given[j], given[i]
			end
			local limit = SalaryConfig.SHAPES_TIME_BASE + #given * SalaryConfig.SHAPES_TIME_PER_PIECE
			local startedAt = workspace:GetServerTimeNow()
			shapeRounds[player] = { index = index, startedAt = startedAt, limit = limit, pieces = given }
			return { ok = true, name = name, board = board, pieces = given, endsAt = startedAt + limit, limit = limit }
		elseif action == "submit" then
			local round = shapeRounds[player]
			if not round then
				return { ok = false, message = "먼저 [시작]을 눌러 주세요." }
			end
			local elapsed = workspace:GetServerTimeNow() - round.startedAt
			if elapsed > round.limit + 1 then
				shapeRounds[player] = nil
				return { ok = true, solved = false, message = "⏰ 시간 초과! 다시 도전해 보세요." }
			end
			-- placements: 조각 번호 → 판 위 칸들 { {x, y}, … }
			if typeof(placements) ~= "table" or #placements ~= #round.pieces then
				return { ok = false, message = "조각을 모두 놓아 주세요." }
			end
			local board = SalaryConfig.getShapePuzzle(round.index)
			local boardSet = {}
			for _, c in board do
				boardSet[`{c[1]},{c[2]}`] = true
			end
			local used = {}
			local filled = 0
			for i, cells in placements do
				if typeof(cells) ~= "table" or not sameShape(round.pieces[i], cells) then
					return { ok = false, message = "모양이 맞지 않는 조각이 있어요." }
				end
				for _, c in cells do
					if typeof(c) ~= "table" or typeof(c[1]) ~= "number" or typeof(c[2]) ~= "number" then
						return { ok = false, message = "잘못된 요청이에요." }
					end
					local cellKey = `{c[1]},{c[2]}`
					if not boardSet[cellKey] or used[cellKey] then
						return { ok = false, message = "판 밖이거나 겹친 조각이 있어요." }
					end
					used[cellKey] = true
					filled += 1
				end
			end
			if filled ~= #board then
				return { ok = false, message = "아직 빈칸이 있어요." }
			end
			-- 🎉 성공! 빨리 풀수록 상금 ↑
			shapeRounds[player] = nil
			local left = math.max(0, math.floor(round.limit - elapsed))
			local prize = #round.pieces * SalaryConfig.SHAPES_PRIZE_PER_PIECE + left * SalaryConfig.SHAPES_PRIZE_PER_SECOND
			local paid, prizesLeft = hooks.shapesPrize(player, prize)
			return { ok = true, solved = true, seconds = math.floor(elapsed), prize = paid, prizesLeft = prizesLeft }
		elseif action == "quit" then
			shapeRounds[player] = nil
			return { ok = true }
		end
		return { ok = false, message = "잘못된 요청이에요." }
	end

	---------------------------------------------------------------- ⚾ 숫자 야구
	local baseballRounds: { [Player]: { answer: { number }, tries: number } } = {}
	local baseballStartAt: { [Player]: number } = {}

	remotes.BaseballPlay.OnServerInvoke = function(player: Player, action: any, guess: any)
		local now = os.clock()
		if now - (lastRequest[player] or 0) < 0.12 then
			return { ok = false, message = "천천히!" }
		end
		lastRequest[player] = now
		if not hooks.isPlaying(player) then
			return { ok = false, message = "📱 자리에서 폰 게임 중일 때만 할 수 있어요." }
		end
		local digits = SalaryConfig.BASEBALL_DIGITS

		if action == "start" then
			-- (새 게임 연타로 첫 판 대박만 노리는 걸 막아요)
			if os.clock() < (baseballStartAt[player] or 0) then
				return { ok = false, message = "⚾ 숨 좀 돌리고… 잠시 뒤에 새 게임!" }
			end
			baseballStartAt[player] = os.clock() + 4
			-- 1~9 중 서로 다른 숫자 뽑기
			local pool = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
			local answer = {}
			for _ = 1, digits do
				table.insert(answer, table.remove(pool, math.random(1, #pool)))
			end
			baseballRounds[player] = { answer = answer, tries = 0 }
			return { ok = true, digits = digits, maxTries = SalaryConfig.BASEBALL_MAX_TRIES }
		elseif action == "guess" then
			local round = baseballRounds[player]
			if not round then
				return { ok = false, message = "먼저 [새 게임]을 눌러 주세요." }
			end
			if typeof(guess) ~= "string" or #guess ~= digits or not string.match(guess, "^[1-9]+$") then
				return { ok = false, message = `1~9 숫자 {digits}개를 넣어 주세요.` }
			end
			local picked = {}
			local seen = {}
			for i = 1, digits do
				local n = tonumber(string.sub(guess, i, i)) :: number
				if seen[n] then
					return { ok = false, message = "같은 숫자는 한 번만 쓸 수 있어요." }
				end
				seen[n] = true
				picked[i] = n
			end
			round.tries += 1
			local strikes, balls = 0, 0
			for i, n in picked do
				if round.answer[i] == n then
					strikes += 1
				elseif table.find(round.answer, n) then
					balls += 1
				end
			end
			local result = { ok = true, guess = guess, strikes = strikes, balls = balls, tries = round.tries }
			if strikes == digits then
				-- 🎉 맞혔어요!
				baseballRounds[player] = nil
				local prize = SalaryConfig.BaseballPrizes[round.tries] or 0
				local paid, left = hooks.baseballPrize(player, prize)
				result.solved = true
				result.prize = paid
				result.prizesLeft = left
			elseif round.tries >= SalaryConfig.BASEBALL_MAX_TRIES then
				-- 기회를 다 썼어요
				baseballRounds[player] = nil
				result.failed = true
				result.answer = table.concat(round.answer)
			end
			return result
		elseif action == "quit" then
			baseballRounds[player] = nil
			return { ok = true }
		end
		return { ok = false, message = "잘못된 요청이에요." }
	end

	Players.PlayerRemoving:Connect(function(player)
		rounds[player] = nil
		baseballRounds[player] = nil
		baseballStartAt[player] = nil
		shapeRounds[player] = nil
		lastPuzzle[player] = nil
		lastRequest[player] = nil
	end)
end

return PhoneGames
