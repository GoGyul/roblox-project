-- 📊 인사평가 (주간) + 🙊 동료 고자질
--
-- 한 주(월~금) 동안 동료 NPC 3명과 점수로 경쟁해요. 금요일 퇴근 때 순위를 발표해요.
--   내 점수 = 실적 40 + 근태 20 + 태도 20 (하루하루의 평균) + 동료평가 20 (금요일의 친밀도)
--   경쟁자는 성격(성실형·견제형·아부형·농땡이형·열정형)마다 하루 점수가 달라요.
--
-- 동료 [E] 말 걸기 하나로 통일했어요. 할 수 있는 일이 여러 개일 때만 고르는 창이 떠요:
--   💬 수다     (고를 게 이것뿐이면 창 없이 바로 수다)
--   🍪 붙잡기   고자질하러 가는 동료에게는 [E]가 바로 "간식으로 붙잡기"가 돼요
--   🙏 도와주기 도움을 청한 동료의 일을 거들어요 (친밀도 ↑ · 오늘 실적 점수 조금 ↓)
--   📢 신고     딴짓 중인 경쟁자를 부장님께 일러요 (그 동료 점수 ↓ · 친밀도 크게 ↓ · 하루 한 번)
--   🎁 간식     들고 있는 간식이나 🎒 포장 커피를 줘요 (가진 게 있어야 해요 · 동료마다 하루 한 번 · 목요일엔 2배)
--
-- 🙊 NPC가 먼저 거는 일은 하루 2번까지예요 (고자질 1번 · 도움 요청 1번). 너무 잦으면 피곤하니까요.
--   고자질은 나와 사이가 나쁜 경쟁자만 하고, 사이가 보통이면 내가 1~2등일 때만 가끔 해요.
--   👀 예고 → 부장님께 걸어감 → 도착했을 때 내가 자리에서 일하고 있으면 허위 신고가 돼요.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local Npc = require(script.Parent.Npc)
local Walker = require(script.Parent.Walker)

local Review = {}

local GIFT_LINES = { "어머, 이런 걸 다~ 고마워요!", "오, 마침 출출했는데! 잘 먹을게요.", "센스 있네요~ 고마워요 🙂" }
local HELD_LINES = { "…이번만이에요.", "흠… 못 본 걸로 할게요.", "(오물오물) …아무것도 못 봤어요." }

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

local function round1(value: number): number
	return math.floor(value * 10 + 0.5) / 10
end

-- ctx: Employees가 넘겨 주는 것들 (data, friendPoints, addFriendship, daily, isWorking, charge, takeBag, tattled, …)
function Review.start(ctx)
	local office, boss, dayCycle, remotes, coworkers = ctx.office, ctx.boss, ctx.dayCycle, ctx.remotes, ctx.coworkers
	local data = ctx.data
	local testing = RunService:IsStudio() and SalaryConfig.TEST_REVIEW == true
	local allNames = SalaryConfig.coworkerNames(office.companyId) -- 이 사무실의 동료 전부 (기본 5명 + 회사별 직원)
	local api = {}

	-- 오늘 NPC가 먼저 걸 일 (플레이어마다): 고자질 한 번 · 도움 요청 한 번
	local plans: { [Player]: { tattle: any?, help: any?, scolded: { [string]: boolean } } } = {}
	local tattling: any? = nil -- 지금 고자질하러 가는 중 (사무실에 한 명만)
	local helping: { [string]: { player: Player, untilTime: number } } = {} -- 도움을 청한 동료 이름 → 누구에게, 언제까지

	local function notify(player: Player, text: string, seconds: number?)
		remotes.Notify:FireClient(player, text, seconds)
	end

	local function weekOf(): number
		return math.floor((math.max(1, dayCycle.day) - 1) / #SalaryConfig.Weekdays)
	end

	local function typeOf(name: string)
		return SalaryConfig.ReviewTypes[SalaryConfig.ReviewPeople[name] or "steady"] or SalaryConfig.ReviewTypes.steady
	end

	local function findCoworker(name: string): any?
		for _, c in coworkers.list() do
			if c.name == name then
				return c
			end
		end
		return nil
	end

	local function pickRivals(): { any }
		local pool = table.clone(coworkers.names())
		for _, name in allNames do -- (자리에 없는 동료로라도 3명을 채워요)
			if #pool >= SalaryConfig.REVIEW_RIVALS then
				break
			end
			if not table.find(pool, name) then
				table.insert(pool, name)
			end
		end
		for i = #pool, 2, -1 do
			local j = math.random(1, i)
			pool[i], pool[j] = pool[j], pool[i]
		end
		local rivals = {}
		for i = 1, math.min(SalaryConfig.REVIEW_RIVALS, #pool) do
			table.insert(rivals, { name = pool[i], sum = 0, mod = 0, adj = 0, tattled = false })
		end
		return rivals
	end

	-- 이번 주 평가 기록 (없거나 지난주 것이면 새로 시작해요)
	local function ensure(d): any
		local profile = d.profile
		local r = profile.review
		local week = weekOf()
		if typeof(r) ~= "table" or r.week ~= week or typeof(r.rivals) ~= "table" then
			local last = if typeof(r) == "table" then r.last else nil
			r = {
				week = week,
				rivals = pickRivals(),
				sum = 0, -- 내 하루 점수 합 (실적 + 근태 + 태도)
				days = 0, -- 점수를 받은 날 수
				mod = 0, -- 주간 보정 (단짝이 실적을 나눠 줌 등)
				perf = 0,
				attend = 0,
				attitude = 0,
				stolen = false,
				shared = false,
				news = {},
				last = last,
			}
			profile.review = r
		end
		return r
	end

	-- 📊 과장부터 인사평가 대상이에요
	local function eligible(d): boolean
		return d.profile.rank >= SalaryConfig.REVIEW_MIN_RANK
	end

	local function rivalOf(r, name: string): any?
		for _, rv in r.rivals do
			if rv.name == name then
				return rv
			end
		end
		return nil
	end

	local function addNews(r, text: string)
		table.insert(r.news, 1, text)
		while #r.news > 4 do
			table.remove(r.news)
		end
	end

	-- 동료평가: 사무실 동료 모두가 친밀도에 따라 한 표씩
	local function peerScore(d): number
		local total = 0
		for _, name in allNames do
			total += SalaryConfig.reviewVote(ctx.friendPoints(d, name))
		end
		return total / math.max(1, #allNames) * 5 -- (한 표 평균 × 5 = 20점 만점: 동료 수가 회사마다 달라도 같게)
	end

	local function myScore(r, d): number?
		if r.days <= 0 then
			return nil
		end
		return r.sum / r.days + peerScore(d) + r.mod
	end

	local function rivalScore(r, rv): number
		local base = if r.days > 0 then rv.sum / r.days else typeOf(rv.name).base
		return base + rv.mod + rv.adj / math.max(1, r.days + 1) -- (오늘 깎인 점수는 평균에 섞였을 때만큼만 미리 보여 줘요)
	end

	-- 지금 내 순위 (아직 점수가 없으면 nil), 전체 인원
	local function myRank(r, d): (number?, number)
		local mine = myScore(r, d)
		if not mine then
			return nil, #r.rivals + 1
		end
		local rank = 1
		for _, rv in r.rivals do
			if rivalScore(r, rv) > mine then
				rank += 1
			end
		end
		return rank, #r.rivals + 1
	end

	local function publish(player: Player, d)
		if not eligible(d) then
			-- (아직 대상이 아니에요: 창에는 안내와 동료 친밀도만 보여 줘요)
			player:SetAttribute("Review", HttpService:JSONEncode({
				locked = true,
				minRank = SalaryConfig.Ranks[SalaryConfig.REVIEW_MIN_RANK].name,
				weekday = (math.max(1, dayCycle.day) - 1) % #SalaryConfig.Weekdays + 1,
			}))
			return
		end
		local r = ensure(d)
		local rank, count = myRank(r, d)
		local rivals = {}
		for _, rv in r.rivals do
			table.insert(rivals, {
				name = rv.name,
				kind = typeOf(rv.name).label,
				score = round1(rivalScore(r, rv)),
				tattled = rv.tattled == true,
			})
		end
		local mine = myScore(r, d)
		player:SetAttribute("Review", HttpService:JSONEncode({
			weekday = (math.max(1, dayCycle.day) - 1) % #SalaryConfig.Weekdays + 1,
			days = r.days,
			rank = rank,
			count = count,
			score = if mine then round1(mine) else nil,
			perf = if r.days > 0 then round1(r.perf / r.days) else nil,
			attend = if r.days > 0 then round1(r.attend / r.days) else nil,
			attitude = if r.days > 0 then round1(r.attitude / r.days) else nil,
			peer = round1(peerScore(d)),
			mod = r.mod,
			rivals = rivals,
			news = r.news,
			last = r.last,
			reported = ctx.daily(d).reported == true,
		}))
	end
	api.publish = function(player: Player)
		local d = data[player]
		if d then
			publish(player, d)
		end
	end

	---------------------------------------------------------------- 📅 하루 시작: 오늘 NPC가 걸 일 정하기
	local function rollMinute(avoid: number?): number
		for _ = 1, 8 do
			local minute = math.random(SalaryConfig.REVIEW_TATTLE_FROM, SalaryConfig.REVIEW_TATTLE_UNTIL - 60)
			if minute >= SalaryConfig.LUNCH_START - 20 and minute < SalaryConfig.LUNCH_END + 10 then
				minute = SalaryConfig.LUNCH_END + 10 + math.random(0, 60)
			end
			if not avoid or math.abs(minute - avoid) >= 60 then
				return minute
			end
		end
		return SalaryConfig.LUNCH_END + 30
	end

	function api.dayStart(player: Player, d, weekday)
		local r = ensure(d)
		for _, rv in r.rivals do
			rv.adj = 0
		end
		local plan = { tattle = nil :: any?, help = nil :: any?, scolded = {} }
		plans[player] = plan

		-- 🙊 오늘 고자질할 사람 (많아야 한 명 · 인사평가 대상인 과장부터만 견제당해요)
		local rank = myRank(r, d)
		local leeScale = if SalaryConfig.leeWorksOn(weekday.name) then SalaryConfig.REVIEW_TATTLE_LEE_DAY else 1
		local order = table.clone(r.rivals)
		for i = #order, 2, -1 do
			local j = math.random(1, i)
			order[i], order[j] = order[j], order[i]
		end
		for _, rv in order do
			local points = ctx.friendPoints(d, rv.name)
			local chance = 0
			if points <= SalaryConfig.FRIEND_ENEMY then
				chance = SalaryConfig.REVIEW_TATTLE_CHANCE.enemy
			elseif points <= SalaryConfig.FRIEND_HOSTILE then
				chance = SalaryConfig.REVIEW_TATTLE_CHANCE.hostile
			elseif points < SalaryConfig.FRIEND_LEVELS[1] and rank ~= nil and rank <= 2 then
				chance = SalaryConfig.REVIEW_TATTLE_CHANCE.neutral -- 사이가 보통이어도 내가 앞서면 견제해요
			end
			chance *= typeOf(rv.name).tattle * leeScale
			if testing then
				chance = 1
			end
			if eligible(d) and math.random() < chance then
				plan.tattle = { name = rv.name, minute = if testing then SalaryConfig.START_MINUTE + 25 else rollMinute(nil), done = false }
				break
			end
		end

		-- 🙏 오늘 도움을 청할 사람 (많아야 한 명 · 고자질꾼 말고 · 앙숙은 부탁하지 않아요)
		if testing or math.random() < SalaryConfig.REVIEW_HELP_CHANCE then
			local candidates = {}
			for _, name in coworkers.names() do
				if (not plan.tattle or plan.tattle.name ~= name) and ctx.friendPoints(d, name) > SalaryConfig.FRIEND_ENEMY then
					table.insert(candidates, name)
				end
			end
			if #candidates > 0 then
				plan.help = {
					name = pick(candidates),
					minute = if testing then SalaryConfig.START_MINUTE + 70 else rollMinute(plan.tattle and plan.tattle.minute),
					done = false,
				}
			end
		end

		-- 🤝 유지비: 65점 이상인데 사흘 넘게 말도 선물도 없었으면 하루 1점씩 줄어요
		local friendDay = d.profile.friendDay
		if typeof(friendDay) == "table" then
			for _, name in allNames do
				local points = ctx.friendPoints(d, name)
				local last = friendDay[name] or d.profile.stats.days
				if points >= SalaryConfig.FRIEND_DECAY_FROM and d.profile.stats.days - last >= SalaryConfig.FRIEND_DECAY_DAYS then
					ctx.addFriendship(player, d, name, -1, "decay")
				end
			end
		end
		publish(player, d)
	end

	---------------------------------------------------------------- 🧾 퇴근: 오늘 점수 매기기 (금요일이면 순위 발표)
	-- info = { earned, target, basePay, quotaOk, halfday, audit, bossAway }
	-- → 급여명세서에 더할 줄들, 추가 승진 경험치, 명세서에 보여 줄 안내 (없으면 nil)
	function api.settle(player: Player, d, info): ({ { label: string, amount: number } }, number, string?)
		if not eligible(d) then
			return {}, 0, nil -- (과장 전에는 평가가 없어요)
		end
		local r = ensure(d)
		local today = d.today :: any
		local lines = {}
		local note: string? = nil

		-- 실적 (40)
		local target = if info.target > 0 then info.target else info.basePay * 0.8
		local ratio = math.max(0, info.earned) / math.max(1, target)
		local atTarget = SalaryConfig.REVIEW_PERF_AT_TARGET
		local perf = if ratio >= 1
			then atTarget + (40 - atTarget) * math.clamp((ratio - 1) / (SalaryConfig.REVIEW_PERF_FULL - 1), 0, 1)
			else atTarget * ratio
		if info.halfday then
			perf = math.max(perf, atTarget) -- 🏖️ 반차는 목표를 채운 걸로 쳐요
		end
		if today.reviewHelp then
			perf = math.max(0, perf - SalaryConfig.REVIEW_HELP_COST)
		end
		-- 근태 (20)
		local attend = 20
			- (if today.reviewLate then SalaryConfig.REVIEW_LATE else 0)
			- (if today.reviewLunchLate then SalaryConfig.REVIEW_LUNCH_LATE else 0)
			- (if not info.quotaOk then SalaryConfig.REVIEW_QUOTA_FAIL else 0)
		attend = math.max(0, attend)
		-- 태도 (20)
		local attitude = 20
			- today.caught * SalaryConfig.REVIEW_CAUGHT
			- (today.reviewTattled or 0) * SalaryConfig.REVIEW_TATTLED
			- (if info.audit then 4 else 0)
		if attitude < 20 and ctx.daily(d).bossCoffee then
			attitude += SalaryConfig.REVIEW_BOSS_COFFEE
		end
		attitude = math.clamp(attitude, 0, 20)

		-- 🗡️ 앙숙인 경쟁자가 내 실적을 자기 것처럼 보고해요 (한 주에 한 번)
		if not r.stolen then
			for _, rv in r.rivals do
				if ctx.friendPoints(d, rv.name) <= SalaryConfig.FRIEND_ENEMY and math.random() < SalaryConfig.REVIEW_STEAL_CHANCE then
					r.stolen = true
					perf = math.max(0, perf - SalaryConfig.REVIEW_STEAL)
					rv.adj += SalaryConfig.REVIEW_STEAL
					addNews(r, `🗡️ {rv.name}이(가) 내 실적을 자기 것처럼 보고했어요 (나 -{SalaryConfig.REVIEW_STEAL} · {rv.name} +{SalaryConfig.REVIEW_STEAL})`)
					ctx.pushNotice(player, "🗡️", `{rv.name}이(가) 내 실적을 가로챘어요… (사이가 나쁘면 이런 일이 생겨요)`, "review")
					break
				end
			end
		end

		r.days += 1
		r.sum += perf + attend + attitude
		r.perf += perf
		r.attend += attend
		r.attitude += attitude

		-- 경쟁자들의 오늘 점수
		for _, rv in r.rivals do
			local kind = typeOf(rv.name)
			local value = kind.base + (math.random() * 2 - 1) * kind.swing + kind.grow * (r.days - 1)
				+ (if info.bossAway then kind.bossAway else 0) + rv.adj
			rv.adj = 0
			rv.sum += math.clamp(value, 30, 98)
		end
		-- 🙊 경쟁자끼리도 서로 일러요 (가끔)
		if #r.rivals >= 2 and math.random() < 0.25 then
			local a = math.random(1, #r.rivals)
			local b = (a + math.random(1, #r.rivals - 1) - 1) % #r.rivals + 1
			r.rivals[b].sum -= 3
			addNews(r, `🙊 {r.rivals[a].name}이(가) {r.rivals[b].name}의 딴짓을 부장님께 일렀대요 ({r.rivals[b].name} -3)`)
		end

		local xp = 0
		if dayCycle:weekday().name == "금요일" then
			-- 📊 발표
			if r.days < SalaryConfig.REVIEW_MIN_DAYS then
				r.last = { week = r.week, excluded = true }
				note = `📊 인사평가: 이번 주는 근무일이 모자라 평가에서 빠졌어요. (최소 {SalaryConfig.REVIEW_MIN_DAYS}일)`
			else
				-- 🤝 단짝인 경쟁자는 실적을 나눠 줘요
				if not r.shared then
					for _, rv in r.rivals do
						if ctx.friendPoints(d, rv.name) >= SalaryConfig.FRIEND_LEVELS[4] then
							r.shared = true
							r.mod += SalaryConfig.REVIEW_SHARE
							addNews(r, `🤝 {rv.name}이(가) 보고서에 내 이름을 같이 올려 줬어요 (+{SalaryConfig.REVIEW_SHARE})`)
							break
						end
					end
				end
				local board = { { name = player.DisplayName, score = round1(myScore(r, d) :: number), me = true } }
				for _, rv in r.rivals do
					table.insert(board, { name = rv.name, score = round1(rivalScore(r, rv)), me = false })
				end
				table.sort(board, function(x, y)
					if x.score ~= y.score then
						return x.score > y.score
					end
					return x.me -- (동점이면 내가 앞)
				end)
				local rank = 1
				for i, row in board do
					if row.me then
						rank = i
					end
				end
				-- (경쟁자가 3명보다 적으면 꼴찌 벌칙은 맨 끝 등수에만)
				local rewardIndex = if rank == #board and #board >= 3 then #SalaryConfig.ReviewRewards else math.min(rank, #SalaryConfig.ReviewRewards - 1)
				local reward = SalaryConfig.ReviewRewards[rewardIndex]
				local pay = math.floor(info.basePay * reward.pay)
				xp = math.floor(info.basePay * reward.xp)
				if pay ~= 0 then
					table.insert(lines, { label = `{reward.label} {if pay > 0 then "성과급" else "감봉"} ({rank}등/{#board}명)`, amount = pay })
				end
				if reward.speed ~= 0 then
					table.insert(d.nextDayFactors, { label = reward.label, delta = reward.speed })
				end
				r.last = { week = r.week, rank = rank, count = #board, pay = pay, xp = xp, speed = reward.speed, board = board }
				note = `📊 인사평가 {rank}등 / {#board}명`
					.. (if xp > 0 then ` · 승진 경험치 +{xp}` else "")
					.. (if reward.speed ~= 0 then ` · 다음 근무일 의심도 속도 {if reward.speed > 0 then "+" else ""}{string.format("%.2f", reward.speed)}` else "")
				ctx.pushNotice(player, "📊", `이번 주 인사평가 {rank}등! (📊 버튼에서 순위표를 볼 수 있어요)`, "review")
			end
			r.news = {}
		end
		publish(player, d)
		return lines, xp, note
	end

	---------------------------------------------------------------- 🤝 경쟁자가 부장님께 혼났어요 (Coworkers가 알려 줘요)
	coworkers.onScolded = function(c)
		for player, plan in plans do
			local d = data[player]
			if d and eligible(d) and not plan.scolded[c.name] then
				local r = ensure(d)
				local rv = rivalOf(r, c.name)
				if rv then
					plan.scolded[c.name] = true -- (하루 한 번만 반영)
					rv.adj -= SalaryConfig.REVIEW_RIVAL_SCOLDED
					publish(player, d)
				end
			end
		end
	end

	---------------------------------------------------------------- 🙊 고자질
	local function backToDesk(c)
		if c.removed then
			return
		end
		c.humanoid.WalkSpeed = 16
		c.model:SetAttribute("Pose", "walk")
		Npc.setStatus(c.model, "🚶")
		Walker.walkTo(c.humanoid, c.root, c.desk.behind, function()
			return c.removed
		end)
		if c.removed then
			return
		end
		c.desk.seat.Disabled = false
		Npc.sit(c.model, c.desk.seat)
		c.atDesk = true
		c.prompt.Enabled = true
		c.borrowed = false
		c.model:SetAttribute("Pose", "work")
		Npc.setStatus(c.model, "⌨️")
	end

	local function runTattle(player: Player, d, c, rv)
		local job = { c = c, player = player, held = false, walking = false }
		tattling = job
		local function finish()
			if tattling == job then
				tattling = nil
			end
		end

		-- 🤝 단짝이 근처에 있으면 대신 막아 줘요
		for _, other in coworkers.list() do
			if other ~= c and other.atDesk and not other.borrowed and not other.auditor
				and ctx.friendPoints(d, other.name) >= SalaryConfig.FRIEND_LEVELS[4]
				and math.random() < SalaryConfig.REVIEW_BLOCK_CHANCE
			then
				Npc.say(c.model, "부장님께 말씀드려야…", 2)
				task.wait(1.2)
				Npc.say(other.model, `에이~ {player.DisplayName} 씨 방금까지 일했어요!`, 3)
				notify(player, `🤝 {other.name}이(가) {c.name}의 고자질을 막아 줬어요! (단짝의 의리)`, 4)
				finish()
				return
			end
		end

		c.borrowed = true -- (평소 행동을 멈춰요)
		c.slacking = false
		Npc.setStatus(c.model, "👀")
		Npc.say(c.model, "…부장님께 말씀드려야겠네.", 3)
		notify(player, `👀 {c.name}이(가) 고자질하러 가요! 자리에 앉아 일하면 허위 신고가 되고, 간식이 있으면 가는 길에 [E]로 붙잡을 수도 있어요.`, 5)
		task.wait(SalaryConfig.REVIEW_TATTLE_WARN)
		if c.removed then
			finish()
			return
		end
		c.atDesk = false
		c.prompt.Enabled = false
		Npc.stand(c.model, c.desk.seat)
		task.wait(0.4)
		Npc.standUpright(c.model)
		c.desk.seat.Disabled = true
		c.model:SetAttribute("Pose", "walk")
		c.humanoid.WalkSpeed = 8
		job.walking = true

		local deadline = os.clock() + 25
		local function near(): boolean
			return (boss.root.Position - c.root.Position).Magnitude <= 9
		end
		local function stopped(): boolean
			return job.held or c.removed or not boss.active or dayCycle.phase ~= "work" or os.clock() > deadline
		end
		while not stopped() and not near() do
			local startedAt = os.clock()
			Walker.walkTo(c.humanoid, c.root, boss.root.Position, function()
				return stopped() or near() or os.clock() - startedAt > 4 -- (부장님이 움직이니까 4초마다 길을 다시 찾아요)
			end)
			task.wait(0.05)
		end
		job.walking = false
		if c.removed then
			finish()
			return
		end

		local r = ensure(d)
		if job.held then
			Npc.say(c.model, pick(HELD_LINES), 3)
		elseif not near() or not boss.active or not player.Parent or data[player] ~= d then
			Npc.say(c.model, "…에이, 됐다.", 2)
		elseif ctx.isWorking(player, d) then
			-- 허위 신고
			Npc.say(c.model, `부장님~ {player.DisplayName} 씨가 또…`, 2)
			task.wait(1)
			boss:say(`{c.name}, 멀쩡히 일하고 있구만! 자네나 잘하게.`, 3)
			rv.adj -= SalaryConfig.REVIEW_RIVAL_FALSE
			ctx.addFriendship(player, d, c.name, SalaryConfig.FRIEND_FALSE_TATTLE, "event")
			addNews(r, `😏 {c.name}의 허위 신고가 들통났어요 ({c.name} -{SalaryConfig.REVIEW_RIVAL_FALSE})`)
			notify(player, `😏 허위 신고! {c.name}이(가) 부장님께 한 소리 들었어요. ({c.name} 평가 -{SalaryConfig.REVIEW_RIVAL_FALSE})`, 4)
		else
			Npc.say(c.model, `부장님~ {player.DisplayName} 씨 또 놀아요~`, 3)
			rv.tattled = true
			local today = d.today :: any
			today.reviewTattled = (today.reviewTattled or 0) + 1
			ctx.tattled(player, d, c.name)
			addNews(r, `🙊 {c.name}이(가) 나를 고자질했어요 (이제 신고해도 다른 동료들이 뭐라 안 해요)`)
			notify(player, `😱 {c.name}이(가) 고자질했어요! 부장님이 이쪽으로 와요!`, 4)
		end
		publish(player, d)
		backToDesk(c)
		finish()
	end

	local function tryTattle(player: Player, d, plan)
		local c = findCoworker(plan.name)
		if not c or not c.atDesk or c.chatting or c.slacking or c.borrowed or c.auditor then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or ctx.isWorking(player, d) or ctx.onHalfDay(d) or d.commute then
			return
		end
		local slacking = d.state ~= "work" and d.state ~= "returning" and d.state ~= "hiding"
		local seen = slacking and office.insideOffice(root.Position) and (root.Position - c.root.Position).Magnitude <= SalaryConfig.REVIEW_TATTLE_RANGE
		local emptySeat = d.away >= SalaryConfig.REVIEW_TATTLE_AWAY
		if not seen and not emptySeat then
			return
		end
		local r = ensure(d)
		local rv = rivalOf(r, plan.name)
		if not rv then
			plan.done = true
			return
		end
		plan.done = true
		task.spawn(runTattle, player, d, c, rv)
	end

	---------------------------------------------------------------- 🙏 도움 요청
	local function tryHelp(player: Player, d, plan)
		local c = findCoworker(plan.name)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not c or not root or not c.atDesk or c.chatting or c.slacking or c.borrowed or c.auditor or helping[c.name] then
			return
		end
		if not office.insideOffice(root.Position) then
			return
		end
		plan.done = true
		helping[c.name] = { player = player, untilTime = os.clock() + SalaryConfig.REVIEW_HELP_SECONDS }
		Npc.setStatus(c.model, "🙏")
		Npc.say(c.model, `{player.DisplayName} 씨, 이것 좀 도와줄 수 있어요?`, 4)
		notify(player, `🙏 {c.name}이(가) 도움을 청해요. 가서 [E] 말 걸기 → 도와주기를 고르면 친밀도 +{SalaryConfig.FRIEND_HELP} (오늘 실적 점수 -{SalaryConfig.REVIEW_HELP_COST}) · 모른 척해도 괜찮아요.`, 5)
	end

	---------------------------------------------------------------- 동료에게 하는 행동 ([E] 말 걸기 메뉴에서 골라요)
	local function report(player: Player, d, c)
		local r = ensure(d)
		local rv = rivalOf(r, c.name)
		if not rv then
			notify(player, `📢 {c.name}은(는) 이번 주 평가 경쟁자가 아니에요. (신고해도 순위가 안 바뀌어요)`)
			return
		end
		local daily = ctx.daily(d)
		if daily.reported then
			notify(player, "📢 신고는 하루에 한 번만 할 수 있어요. (너무 잦으면 부장님이 나를 이상하게 봐요)")
			return
		end
		if not boss.active or boss.scolding or dayCycle.phase ~= "work" then
			notify(player, "📢 지금은 부장님이 들어 줄 수 없어요.")
			return
		end
		if not c.slacking then
			return
		end
		daily.reported = true
		c.slacking = false
		c.model:SetAttribute("Pose", "work")
		Npc.setStatus(c.model, "😰")
		local line = string.gsub(pick(SalaryConfig.BossLines.scoldCoworker), "{name}", c.name)
		boss:scold(c.model, line)
		rv.adj -= SalaryConfig.REVIEW_RIVAL_REPORTED
		local plan = plans[player]
		if plan then
			plan.scolded[c.name] = true
		end
		local revenge = rv.tattled == true
		ctx.addFriendship(player, d, c.name, if revenge then SalaryConfig.FRIEND_REPORT_REVENGE else SalaryConfig.FRIEND_REPORT, "event")
		local witnesses = 0
		if not revenge then
			for _, other in coworkers.list() do
				if other ~= c and other.atDesk and not other.borrowed then
					ctx.addFriendship(player, d, other.name, SalaryConfig.FRIEND_WITNESS, "quiet")
					witnesses += 1
				end
			end
		end
		addNews(r, `📢 내가 {c.name}의 딴짓을 신고했어요 ({c.name} -{SalaryConfig.REVIEW_RIVAL_REPORTED})`)
		notify(player, `📢 신고 완료! {c.name} 평가 -{SalaryConfig.REVIEW_RIVAL_REPORTED}`
			.. (if revenge then " · 먼저 고자질한 사람이라 다들 그러려니 해요" elseif witnesses > 0 then ` · 지켜본 동료 {witnesses}명 친밀도 {SalaryConfig.FRIEND_WITNESS}` else ""), 5)
		publish(player, d)
	end

	local function gift(player: Player, d, c)
		local daily = ctx.daily(d)
		daily.gifts = if typeof(daily.gifts) == "table" then daily.gifts else {}
		if daily.gifts[c.name] then
			notify(player, `🎁 {c.name}에게는 오늘 이미 드렸어요. (동료마다 하루 한 번)`)
			return
		end
		local what = ctx.takeGift(player, d)
		if not what then
			notify(player, "🎁 줄 것이 없어요. 탕비실·디저트집에서 간식을 들고 오거나, 카페에서 포장 커피를 사 오세요.", 4)
			return
		end
		daily.gifts[c.name] = true
		local thursday = dayCycle:weekday().name == "목요일"
		local gain = SalaryConfig.FRIEND_GIFT * (if thursday then 2 else 1)
		Npc.say(c.model, pick(GIFT_LINES), 3)
		ctx.addFriendship(player, d, c.name, gain, "event")
		notify(player, `🎁 {c.name}에게 {what} 선물! 친밀도 +{gain}` .. (if thursday then " (평가 전날이라 2배)" else ""), 4)
	end

	-- 🍪 고자질하러 가는 동료에게 [E] → 가진 간식·커피로 붙잡기 (급하니까 메뉴 없이 바로)
	coworkers.onHold = function(player: Player, c): boolean
		local job = tattling
		if not job or job.c ~= c then
			return false
		end
		local d = data[player]
		if not d or d.fired then
			return true
		end
		if job.player ~= player then
			notify(player, `👀 {c.name}은(는) 다른 사람 일로 바빠요.`)
		elseif job.walking and not job.held then
			local what = ctx.takeGift(player, d)
			if what then
				job.held = true
				ctx.addFriendship(player, d, c.name, SalaryConfig.FRIEND_HOLD, "event")
				notify(player, `🍪 {c.name}을(를) {what}(으)로 붙잡았어요! 고자질 취소 · 친밀도 +{SalaryConfig.FRIEND_HOLD}`, 4)
			else
				notify(player, "🍪 줄 간식이 없어요! 자리에 앉아 일하는 척하면 허위 신고가 돼요.", 4)
			end
		end
		return true
	end

	-- 💬 동료 [E] 말 걸기 → 할 수 있는 일이 여러 개면 고르는 창을 띄워요 (수다뿐이면 바로 수다)
	--   → true면 창을 띄웠어요 (false면 부른 쪽이 바로 수다를 시작해요)
	local pending: { [Player]: { c: any, untilTime: number } } = {}
	function api.menu(player: Player, c): boolean
		local d = data[player]
		if not d or d.fired or c.removed or dayCycle.phase == "offwork" then
			return false
		end
		-- (걸어 다니는 중에는 수다는 못 하고, 감사 기간의 "감사팀이죠?"만 할 수 있어요)
		local options = {}
		if c.atDesk and not c.chatting then
			table.insert(options, { id = "chat", name = "💬 수다 떨기" })
		end
		local ask = helping[c.name]
		if ask and ask.player == player and os.clock() < ask.untilTime then
			table.insert(options, { id = "help", name = `🙏 업무 도와주기 (친밀도 +{SalaryConfig.FRIEND_HELP})` })
		end
		local gifts = ctx.daily(d).gifts
		if not c.chatting and ctx.hasGift(d) and not (typeof(gifts) == "table" and gifts[c.name]) then
			table.insert(options, { id = "gift", name = "🎁 간식 주기" })
		end
		if eligible(d) and c.slacking and boss.active and dayCycle.phase == "work" and rivalOf(ensure(d), c.name) and not ctx.daily(d).reported then
			table.insert(options, { id = "report", name = "📢 부장님께 신고" })
		end
		-- 📄 차장부터: 친한 동료에게 오늘 업무를 조금 떠넘길 수 있어요 (하루 한 번)
		if d.profile.rank >= SalaryConfig.DELEGATE_RANK and c.atDesk and not c.chatting and dayCycle.phase == "work"
			and not ctx.daily(d).delegated and ctx.friendPoints(d, c.name) >= SalaryConfig.DELEGATE_FRIEND
		then
			table.insert(options, { id = "delegate", name = `📄 업무 떠넘기기 (친밀도 {SalaryConfig.DELEGATE_FRIEND_COST})` })
		end
		if coworkers.auditMode() then
			table.insert(options, { id = "accuse", name = "🕶️ 감사팀이죠?" })
		end
		if #options == 0 then
			-- (걸어가는 중이라 수다는 못 해요: 대답만 하고 가던 길을 가요)
			Npc.say(c.model, "지금은 좀 바빠서요~ 자리에서 얘기해요!", 2)
			notify(player, `💬 {c.name}은(는) 볼일 보러 가는 중이에요. 자리에 돌아오면 수다를 떨 수 있어요. (간식은 지금도 줄 수 있어요)`, 3)
			return true
		elseif #options == 1 and options[1].id == "chat" then
			return false -- 수다뿐이면 창 없이 바로 수다
		end
		pending[player] = { c = c, untilTime = os.clock() + 10 }
		Npc.pause(c.humanoid, c.root, player, 8, 14) -- ✋ 고르는 동안 그 자리에 서 있어요
		remotes.CoworkerMenu:FireClient(player, `{c.name}에게 무엇을 할까요?`, options)
		return true
	end

	remotes.CoworkerChoose.OnServerEvent:Connect(function(player: Player, choice: any)
		local wait = pending[player]
		pending[player] = nil
		if wait then
			Npc.resume(wait.c.humanoid, player) -- ✋ 골랐으니 다시 움직여요
		end
		local d = data[player]
		if not wait or not d or d.fired or os.clock() > wait.untilTime or typeof(choice) ~= "string" then
			return
		end
		local c = wait.c
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if c.removed or not root or (root.Position - c.root.Position).Magnitude > 14 or dayCycle.phase == "offwork" then
			return
		end
		if choice == "chat" then
			if c.atDesk and not c.chatting and not c.borrowed then
				ctx.chat(player, c)
			end
		elseif choice == "help" then
			local ask = helping[c.name]
			if ask and ask.player == player and os.clock() < ask.untilTime then
				helping[c.name] = nil
				local today = d.today :: any
				today.reviewHelp = true
				Npc.say(c.model, "살았다… 고마워요!", 3)
				Npc.setStatus(c.model, "⌨️")
				ctx.addFriendship(player, d, c.name, SalaryConfig.FRIEND_HELP, "event")
				notify(player, `🙏 {c.name}의 일을 도와줬어요! 친밀도 +{SalaryConfig.FRIEND_HELP} · 오늘 실적 점수 -{SalaryConfig.REVIEW_HELP_COST}`, 4)
			end
		elseif choice == "gift" then
			if not c.chatting and not c.borrowed then
				gift(player, d, c)
			end
		elseif choice == "report" then
			if c.slacking then
				report(player, d, c)
			else
				notify(player, `📢 {c.name}이(가) 그새 일하는 척을 해요. 늦었어요!`)
			end
		elseif choice == "delegate" then
			local daily = ctx.daily(d)
			if d.profile.rank >= SalaryConfig.DELEGATE_RANK and not daily.delegated and c.atDesk and dayCycle.phase == "work"
				and ctx.friendPoints(d, c.name) >= SalaryConfig.DELEGATE_FRIEND
			then
				daily.delegated = true
				local seconds = ctx.delegate(player, d)
				Npc.say(c.model, "네…? 아, 네. 제가 할게요…", 3)
				ctx.addFriendship(player, d, c.name, SalaryConfig.DELEGATE_FRIEND_COST, "quiet")
				notify(player, `📄 {c.name}에게 업무를 떠넘겼어요! 오늘 업무 +{seconds}초 · 친밀도 {SalaryConfig.DELEGATE_FRIEND_COST} (하루 한 번)`, 4)
			end
		elseif choice == "accuse" then
			if coworkers.auditMode() and coworkers.onAccuse then
				coworkers.onAccuse(player, c)
			end
		end
	end)

	-- 고자질하러 걸어가는 동안에만 [E] 글자를 "간식으로 붙잡기"로 바꿔요 (그 밖엔 "말 걸기")
	local function refreshPrompt(c)
		local job = tattling
		local holding = job ~= nil and job.c == c and job.walking and not job.held
		local text = if holding then "🍪 간식으로 붙잡기" else "말 걸기"
		if c.prompt.ActionText ~= text then
			c.prompt.ActionText = text
		end
		if job and job.c == c and not c.removed then
			c.prompt.Enabled = holding
		elseif not c.atDesk and not c.removed then
			-- 돌아다니는 동료에게도 말을 걸 수 있어요 (간식 주기 · 감사 기간의 "감사팀이죠?" / 수다는 자리에서만)
			c.prompt.Enabled = not c.borrowed and dayCycle.phase ~= "offwork"
		end
	end

	---------------------------------------------------------------- 돌아가는 부분
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.clock()
			for name, ask in helping do
				if now >= ask.untilTime or not ask.player.Parent then
					helping[name] = nil
				end
			end
			for _, c in coworkers.list() do
				refreshPrompt(c)
			end
			for player, d in data do
				if player:GetAttribute("Review") == nil then
					publish(player, d) -- (하루 중간에 들어온 사람도 순위표를 볼 수 있게)
				end
			end
			for player, plan in plans do
				local d = data[player]
				if not player.Parent or not d then
					plans[player] = nil
					continue
				end
				if d.fired or dayCycle.phase ~= "work" then
					continue
				end
				local minute = dayCycle.minute
				local calm = boss.active and not boss.scolding and not ctx.eventBusy()
				local tattle = plan.tattle
				if tattle and not tattle.done then
					if minute > SalaryConfig.REVIEW_TATTLE_UNTIL then
						tattle.done = true
					elseif minute >= tattle.minute and calm and not tattling then
						tryTattle(player, d, tattle)
					end
				end
				local help = plan.help
				if help and not help.done then
					if minute > SalaryConfig.REVIEW_TATTLE_UNTIL then
						help.done = true
					elseif minute >= help.minute and not ctx.eventBusy() and not (tattling and tattling.player == player) then
						tryHelp(player, d, help)
					end
				end
			end
		end
	end)

	return api
end

return Review
