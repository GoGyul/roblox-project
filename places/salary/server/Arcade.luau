-- 🕹️ 오락실 (눈치 스트리트)
--   🔨 두더지 잡기 / 🃏 카드 짝 맞추기 → 점수만큼 🎟️ 티켓 → 경품 교환대에서 바꾸기
--   🏆 뒷벽 기록판: 게임별 역대 최고 점수 TOP 5 (모든 서버 공통, OrderedDataStore)
--
-- 🛡️ 판정은 서버가 해요:
--   두더지: 언제 어느 구멍에서 나올지 서버가 미리 정해서 보내고, 화면은 "몇 번 두더지를 언제 때렸는지"만 보내요.
--           서버가 그 시각에 그 두더지가 정말 나와 있었는지 확인해요.
--   카드: 16장 배치는 서버만 알아요. 화면은 "몇 번 카드를 뒤집을래요"만 보내고,
--         서버가 그 카드 그림과 짝이 맞았는지를 알려 줘요. 점수도 서버가 센 짝 수로 계산해요.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)
local Build = require(ReplicatedStorage.Shared.Build)

local Arcade = {}

local RANGE = 10
local LATE_SLACK = 0.3 -- 인터넷 지연으로 늦게 도착한 클릭 봐주기 (초)
local allowAction = RateLimit.new(0.3)
local allowFlip = RateLimit.new(0.1) -- 카드 뒤집기는 빠르게 두 장씩 눌러요

---------------------------------------------------------------------------
-- 게임 일정 만들기 (서버가 정해요)
---------------------------------------------------------------------------
local function makeMoleSchedule()
	local moles = {}
	local t = 0.6
	while t < SalaryConfig.MOLE_SECONDS - 0.8 do
		local progress = t / SalaryConfig.MOLE_SECONDS
		local roll = math.random()
		table.insert(moles, {
			t = t,
			hole = math.random(1, 9),
			life = 1.05 - 0.35 * progress, -- 뒤로 갈수록 빨리 들어가요
			kind = if roll < 0.1 then "gold" elseif roll < 0.22 then "boss" else "normal",
		})
		t += math.random(32, 65) / 100
	end
	return moles
end

-- 🃏 카드 16장 섞기 (그림 8개 × 2장)
local function makeMemoryLayout(): { string }
	local pool = table.clone(SalaryConfig.MemoryEmoji)
	local cards = {}
	for _ = 1, SalaryConfig.MEMORY_PAIRS do
		local emoji = table.remove(pool, math.random(1, #pool))
		table.insert(cards, emoji)
		table.insert(cards, emoji)
	end
	for i = #cards, 2, -1 do
		local j = math.random(1, i)
		cards[i], cards[j] = cards[j], cards[i]
	end
	return cards
end

-------------------------------------------------------------------------
-- 점수 계산 (화면이 보낸 기록을 검사하면서)
---------------------------------------------------------------------------
local MOLE_POINTS = { normal = 1, gold = 3, boss = -2 }

local function scoreMole(session, hits: any): number
	if typeof(hits) ~= "table" then
		return 0
	end
	local now = workspace:GetServerTimeNow()
	local used = {}
	local score = 0
	for _, hit in hits do
		if typeof(hit) ~= "table" then
			continue
		end
		local index, t = hit[1], hit[2]
		if typeof(index) ~= "number" or typeof(t) ~= "number" or used[index] then
			continue
		end
		local mole = session.moles[index]
		if not mole or t > now + 0.05 then
			continue
		end
		local appear = session.start + mole.t
		if t >= appear - 0.05 and t <= appear + mole.life + LATE_SLACK then
			used[index] = true
			score += MOLE_POINTS[mole.kind] or 0
		end
	end
	return math.max(0, score)
end

-- 🃏 찾은 짝 × 2점 + 다 찾았으면 남은 시간 보너스
local function scoreMemory(session): number
	local score = session.found * SalaryConfig.MEMORY_PAIR_POINTS
	if session.clearedAt then
		local left = session.start + SalaryConfig.MEMORY_SECONDS - session.clearedAt
		score += math.max(0, math.floor(left / SalaryConfig.MEMORY_BONUS_EVERY))
	end
	return score
end

-- 🃏 카드 한 장 뒤집기 → 화면에 보낼 답장
local function flipCard(session, index: any)
	local now = workspace:GetServerTimeNow()
	if now < session.start - 0.1 or now > session.start + SalaryConfig.MEMORY_SECONDS + LATE_SLACK then
		return { ok = false, message = "시간이 끝났어요!" }
	end
	if session.clearedAt then
		return { ok = false, message = "벌써 다 찾았어요!" }
	end
	if now < (session.lockUntil or 0) then
		return { ok = false, busy = true } -- 틀린 카드 보여 주는 중
	end
	local total = SalaryConfig.MEMORY_PAIRS * 2
	if typeof(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > total then
		return { ok = false, message = "없는 카드예요." }
	end
	if session.open[index] or session.pending == index then
		return { ok = false, busy = true } -- 이미 뒤집힌 카드
	end
	local emoji = session.cards[index]
	local first = session.pending
	if not first then
		session.pending = index
		return { ok = true, index = index, emoji = emoji }
	end
	-- 두 번째 카드: 짝 확인
	session.pending = nil
	local matched = session.cards[first] == emoji
	if matched then
		session.open[first] = true
		session.open[index] = true
		session.found += 1
		if session.found >= SalaryConfig.MEMORY_PAIRS then
			session.clearedAt = now
		end
	else
		session.lockUntil = now + SalaryConfig.MEMORY_PEEK - 0.15 -- 화면 쪽 기다림보다 살짝 짧게 (지연 봐주기)
	end
	return {
		ok = true,
		index = index,
		emoji = emoji,
		first = first,
		matched = matched,
		found = session.found,
		cleared = session.clearedAt ~= nil,
	}
end

-------------------------------------------------------------------------
-- hooks.charge(player, price) → (ok, message)
-- hooks.reward(player, gameId, score, tickets) → (best: number, isBest: boolean)
-- hooks.exchange(player, prizeId) → (ok, message)
function Arcade.start(office, remotes, hooks)
	local arcade = office.arcade
	if not arcade then
		return -- 눈치물산에만 있어요
	end
	local sessions: { [Player]: any } = {}

	-- 🏆 기록판 (모든 서버 공통 TOP 5. 스튜디오처럼 저장이 안 되면 이 서버 기록만)
	local stores = {}
	for gameId in SalaryConfig.ArcadeGames do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(`SalaryArcade_{gameId}`)
		end)
		stores[gameId] = if ok then store else nil
	end
	local localBest: { [string]: { [string]: number } } = { mole = {}, memory = {} } -- 게임 → 이름 → 점수
	local nameCache: { [number]: string } = {}
	local function nameOf(userId: number): string
		if nameCache[userId] then
			return nameCache[userId]
		end
		local ok, name = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		nameCache[userId] = if ok then name else "???"
		return nameCache[userId]
	end

	local boardLabel = Build.surfaceText(arcade.board, Enum.NormalId.Front, "🏆 최고 기록 불러오는 중…", {
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(255, 230, 120),
		TextScaled = true,
	})
	local function refreshBoard()
		local lines = { "🏆 오락실 최고 기록" }
		for _, gameId in { "mole", "memory" } do
			local info = SalaryConfig.ArcadeGames[gameId]
			local entries = {}
			local store = stores[gameId]
			local ok = false
			if store then
				ok = pcall(function()
					local page = store:GetSortedAsync(false, 5):GetCurrentPage()
					for _, entry in page do
						table.insert(entries, `{nameOf(tonumber(entry.key) or 0)} {entry.value}`)
					end
				end)
			end
			if not ok then
				local list = {}
				for name, score in localBest[gameId] do
					table.insert(list, { name = name, score = score })
				end
				table.sort(list, function(a, b)
					return a.score > b.score
				end)
				for i = 1, math.min(5, #list) do
					table.insert(entries, `{list[i].name} {list[i].score}`)
				end
			end
			table.insert(lines, `{info.emoji} {info.name}: ` .. (if #entries > 0 then table.concat(entries, " · ") else "아직 기록 없음"))
		end
		boardLabel.Text = table.concat(lines, "\n")
	end
	task.spawn(function()
		while true do
			refreshBoard()
			task.wait(60)
		end
	end)

	-- 게임기와 경품 교환대 [E]
	for gameId, machine in arcade.machines do
		local info = SalaryConfig.ArcadeGames[gameId]
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = `{info.name} ({SalaryConfig.ARCADE_PRICE}원)`
		prompt.ObjectText = "🕹️ 오락실"
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.Parent = machine
		prompt.Triggered:Connect(function(player)
			local need = SalaryConfig.BADGE.arcade -- 🪪 사원증 등급
			if ((player:GetAttribute("Rank") :: number?) or 1) < need then
				remotes.Notify:FireClient(player, `🪪 사원증 등급이 모자라요! 🕹️ 오락실은 {SalaryConfig.Ranks[need].name}부터 이용할 수 있어요.`)
				return
			end
			remotes.ArcadeOpen:FireClient(player, gameId)
		end)
	end
	local prizePrompt = Instance.new("ProximityPrompt")
	prizePrompt.ActionText = "경품 교환"
	prizePrompt.ObjectText = "🎟️ 티켓"
	prizePrompt.MaxActivationDistance = 7
	prizePrompt.RequiresLineOfSight = false
	prizePrompt.Parent = arcade.prizeCounter
	prizePrompt.Triggered:Connect(function(player)
		remotes.ArcadeOpen:FireClient(player, "prizes")
	end)

	local function near(player: Player): boolean
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return false
		end
		for _, part in { arcade.machines.mole, arcade.machines.memory, arcade.prizeCounter } do
			if (root.Position - part.Position).Magnitude <= RANGE then
				return true
			end
		end
		return false
	end

	remotes.Arcade.OnServerInvoke = function(player: Player, action: any, a: any)
		-- 🃏 카드 뒤집기 (빠르게 연달아 누르니까 따로 검사해요)
		if action == "flip" then
			if not allowFlip(player) then
				return { ok = false, busy = true }
			end
			local session = sessions[player]
			if not session or session.gameId ~= "memory" then
				return { ok = false, message = "먼저 시작을 눌러 주세요." }
			end
			return flipCard(session, a)
		end
		if not allowAction(player) then
			return { ok = false, message = "천천히 눌러 주세요." }
		end
		if action == "start" then
			local info = typeof(a) == "string" and SalaryConfig.ArcadeGames[a]
			if not info then
				return { ok = false, message = "없는 게임이에요." }
			end
			if not near(player) then
				return { ok = false, message = "오락실 게임기 앞에서 해 주세요!" }
			end
			local ok, message = hooks.charge(player, SalaryConfig.ARCADE_PRICE)
			if not ok then
				return { ok = false, message = message }
			end
			local session = { gameId = info.id, start = workspace:GetServerTimeNow() + 1 }
			if info.id == "mole" then
				session.moles = makeMoleSchedule()
				session.expires = session.start + SalaryConfig.MOLE_SECONDS + 10
			else
				session.cards = makeMemoryLayout() -- 🃏 서버만 알아요 (화면에는 안 보내요)
				session.open = {}
				session.found = 0
				session.expires = session.start + SalaryConfig.MEMORY_SECONDS + 10
			end
			sessions[player] = session
			return { ok = true, gameId = info.id, start = session.start, moles = session.moles }
		elseif action == "finish" then
			local session = sessions[player]
			sessions[player] = nil
			if not session or workspace:GetServerTimeNow() > session.expires then
				return { ok = false, message = "게임 시간이 지났어요. 다시 해 주세요." }
			end
			local score = if session.gameId == "mole" then scoreMole(session, a) else scoreMemory(session)
			local tickets = SalaryConfig.arcadeTickets(session.gameId, score)
			local best, isBest = hooks.reward(player, session.gameId, score, tickets)
			if isBest then
				localBest[session.gameId][player.DisplayName] = best
				local store = stores[session.gameId]
				if store then
					task.spawn(function()
						pcall(function()
							store:UpdateAsync(tostring(player.UserId), function(old)
								return math.max(old or 0, best)
							end)
						end)
						refreshBoard()
					end)
				else
					refreshBoard()
				end
			end
			return { ok = true, score = score, tickets = tickets, best = best, isBest = isBest }
		elseif action == "exchange" then
			if not near(player) then
				return { ok = false, message = "경품 교환대 앞에서 해 주세요!" }
			end
			if typeof(a) ~= "string" then
				return { ok = false, message = "없는 경품이에요." }
			end
			local ok, message = hooks.exchange(player, a)
			return { ok = ok, message = message }
		end
		return { ok = false, message = "잘못된 요청이에요." }
	end

	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
end

return Arcade
