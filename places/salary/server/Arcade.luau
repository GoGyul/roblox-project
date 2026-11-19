-- 🕹️ 오락실 (눈치 스트리트)
--   🔨 두더지 잡기 / 🎯 타이밍 스톱 → 점수만큼 🎟️ 티켓 → 경품 교환대에서 바꾸기
--   🏆 뒷벽 기록판: 게임별 역대 최고 점수 TOP 5 (모든 서버 공통, OrderedDataStore)
--
-- 🛡️ 판정은 서버가 해요:
--   두더지: 언제 어느 구멍에서 나올지 서버가 미리 정해서 보내고, 화면은 "몇 번 두더지를 언제 때렸는지"만 보내요.
--           서버가 그 시각에 그 두더지가 정말 나와 있었는지 확인해요.
--   타이밍: 라운드마다 목표 칸과 속도를 서버가 정하고, 화면은 "멈춘 시각"만 보내요. 막대 위치는 서버가 계산해요.

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

local function makeTimingSchedule()
	local rounds = {}
	for i = 1, SalaryConfig.TIMING_ROUNDS do
		table.insert(rounds, {
			target = math.random(15, 85) / 100,
			period = 1.7 - (i - 1) * 0.22, -- 점점 빨라져요
		})
	end
	return rounds
end

---------------------------------------------------------------------------
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

local function scoreTiming(session, presses: any): number
	if typeof(presses) ~= "table" then
		return 0
	end
	local now = workspace:GetServerTimeNow()
	local roundStart = session.start
	local score = 0
	for i, round in session.rounds do
		local t = presses[i]
		if typeof(t) ~= "number" or t < roundStart or t > now + 0.05 then
			break -- 순서가 이상하면 거기서 끝
		end
		local position = SalaryConfig.clawPosition(t - roundStart, round.period)
		local gap = math.abs(position - round.target)
		if gap <= SalaryConfig.TIMING_PERFECT then
			score += 3
		elseif gap <= SalaryConfig.TIMING_GOOD then
			score += 1
		end
		roundStart = t + SalaryConfig.TIMING_PAUSE
	end
	return score
end

---------------------------------------------------------------------------
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
	local localBest: { [string]: { [string]: number } } = { mole = {}, timing = {} } -- 게임 → 이름 → 점수
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
		for _, gameId in { "mole", "timing" } do
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
		for _, part in { arcade.machines.mole, arcade.machines.timing, arcade.prizeCounter } do
			if (root.Position - part.Position).Magnitude <= RANGE then
				return true
			end
		end
		return false
	end

	remotes.Arcade.OnServerInvoke = function(player: Player, action: any, a: any, b: any)
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
				session.rounds = makeTimingSchedule()
				session.expires = session.start + 60
			end
			sessions[player] = session
			return { ok = true, gameId = info.id, start = session.start, moles = session.moles, rounds = session.rounds }
		elseif action == "finish" then
			local session = sessions[player]
			sessions[player] = nil
			if not session or workspace:GetServerTimeNow() > session.expires then
				return { ok = false, message = "게임 시간이 지났어요. 다시 해 주세요." }
			end
			local score = if session.gameId == "mole" then scoreMole(session, a) else scoreTiming(session, a)
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
