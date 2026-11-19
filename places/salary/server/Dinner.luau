-- 🍻 목요일 회식 (퇴근 후 40초 미니게임)
--   🍶 부장님 잔이 비기 전에 채워요. 거의 비었을 때 채우면 +1, 아직 많이 남았는데 채우면 -1, 잔이 비면 -1
--   🥂 "건배사!"가 뜨면 1.6초 안에 [위하여!] → +2 (아무 때나 누르면 -1)
--   점수가 좋으면 보너스 + 다음 날 부장님이 너그러워져요 (의심도가 덜 올라요)
--
-- 판정은 모두 서버가 해요. 클라이언트는 버튼만 보내요 (점수를 조작할 수 없게).
-- 화면에 보여 줄 값은 플레이어 속성으로: DinnerGlass(0~1), DinnerScore, DinnerCheers(건배 타이밍인지)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)

local Dinner = {}

local CHEERS_WINDOW = 1.6
local allowAction = RateLimit.new(0.25)

local LINES = {
	good = { "센스 있네~ 😊", "역시 우리 ○○ 씨!", "캬~ 타이밍 좋고!" },
	early = { "아직 남았잖아… 😑", "천천히 마시자고~", "벌써 따르면 어떡해!" },
	empty = { "잔이 비었잖아! 😠", "어허, 잔이 비었는데?", "내 잔 안 보여?" },
	cheersGood = { "위하여~! 🥂", "좋아 좋아! 🥂" },
	cheersBad = { "혼자 건배…?", "아직 건배사 안 했는데?" },
}

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

-- hooks.participants(): { Player } — 회식에 참여하는 사람 (해고된 사람 빼고)
-- hooks.reward(player, score) — 끝나면 점수로 보상
-- hooks.stage(players) / hooks.unstage() — 공원 식탁에 앉히기 / 정리 (회식 장소가 있는 회사만)
-- hooks.bossSay(text) — 부장님 말풍선
function Dinner.start(dayCycle, remotes, hooks)
	local sessions: { [Player]: any } = {}
	local cheersOpen = false
	local running = false

	local function say(player: Player, kind: string)
		local text = string.gsub(pick(LINES[kind]), "○○", player.DisplayName)
		remotes.Dinner:FireClient(player, "line", text)
	end

	local function newDrain(): number
		return math.random(70, 140) / 1000 -- 1초에 잔의 7~14%를 마셔요
	end

	local function run()
		running = true
		table.clear(sessions)
		for _, player in hooks.participants() do
			sessions[player] = { glass = 1, score = 0, empty = false, drain = newDrain(), cheered = false }
			remotes.Dinner:FireClient(player, "start", SalaryConfig.DINNER_SECONDS)
		end
		if next(sessions) == nil then
			running = false
			return
		end
		local seated = {}
		for player in sessions do
			table.insert(seated, player)
		end
		hooks.stage(seated)
		hooks.bossSay("자~ 한 주 고생했어! 오늘은 내가 쏜다! 🍻")

		-- 건배사 두 번 (최소 10초 간격)
		local first = math.random(8, 16)
		local cheersTimes = { first, math.random(first + 10, SalaryConfig.DINNER_SECONDS - 5) }
		local elapsed = 0
		local cheersUntil = 0
		while elapsed < SalaryConfig.DINNER_SECONDS do
			local dt = task.wait(0.1)
			elapsed += dt

			-- 건배사 타이밍
			if #cheersTimes > 0 and elapsed >= cheersTimes[1] then
				table.remove(cheersTimes, 1)
				cheersOpen = true
				cheersUntil = elapsed + CHEERS_WINDOW
				hooks.bossSay("자~ 다들 잔 들고! 건배사!")
				for player, session in sessions do
					session.cheered = false
					remotes.Dinner:FireClient(player, "line", "🎤 부장님: \"자~ 다들 잔 들고! 건배사!\"")
				end
			elseif cheersOpen and elapsed >= cheersUntil then
				cheersOpen = false
			end

			for player, session in sessions do
				if not player.Parent then
					sessions[player] = nil
					continue
				end
				session.glass = math.max(0, session.glass - session.drain * dt)
				if session.glass <= 0 and not session.empty then
					session.empty = true
					session.score -= 1
					say(player, "empty")
				end
				player:SetAttribute("DinnerGlass", math.floor(session.glass * 100) / 100)
				player:SetAttribute("DinnerScore", session.score)
				player:SetAttribute("DinnerCheers", cheersOpen)
			end
		end

		cheersOpen = false
		running = false
		hooks.bossSay("오늘 즐거웠어! 내일 지각하지 말고~")
		task.delay(3, hooks.unstage)
		for player, session in sessions do
			if player.Parent then
				player:SetAttribute("DinnerCheers", false)
				hooks.reward(player, session.score)
			end
		end
		table.clear(sessions)
	end

	-- 클라이언트 버튼: "pour"(따르기) / "cheers"(위하여!)
	remotes.Dinner.OnServerEvent:Connect(function(player, action)
		if not running or not allowAction(player) then
			return
		end
		local session = sessions[player]
		if not session then
			return
		end
		if action == "pour" then
			if session.glass < 0.35 then
				session.score += 1
				say(player, "good")
			elseif session.glass >= 0.7 then
				session.score -= 1
				say(player, "early")
			end
			session.glass = 1
			session.empty = false
			session.drain = newDrain()
		elseif action == "cheers" then
			if cheersOpen and not session.cheered then
				session.cheered = true
				session.score += 2
				say(player, "cheersGood")
			elseif not cheersOpen then
				session.score -= 1
				say(player, "cheersBad")
			end
		end
		player:SetAttribute("DinnerScore", session.score)
	end)

	-- 목요일 퇴근하면 (명세서를 잠깐 보여 준 뒤) 회식 시작
	dayCycle:on("dayEnd", function()
		local isDinnerDay = dayCycle:weekday().name == SalaryConfig.DINNER_DAY
		if RunService:IsStudio() and SalaryConfig.TEST_DINNER then
			isDinnerDay = true
		end
		if not isDinnerDay then
			return
		end
		-- 다음 날까지 기다리는 시간을 늘려요 (이 줄은 기다리기 전에 바로 실행돼야 해요)
		dayCycle.extraOffwork = SalaryConfig.DINNER_DELAY + SalaryConfig.DINNER_SECONDS + 5
		task.wait(SalaryConfig.DINNER_DELAY)
		run()
	end)
end

return Dinner
