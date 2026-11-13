-- 직원(플레이어) 관리: 자리 배정, 지금 상태, 돈 벌기, 의심도, 적발, 해고,
--                     월급명세서, 승진, 매점, 도감, 저장
--
-- 0.1초마다 플레이어마다:
--   1. 지금 상태 정하기 (자리에서 고른 행동 / 화장실 / 탕비실 / 어슬렁)
--   2. 상태에 맞게 돈 벌기 (직급이 높을수록 배율 ↑)
--   3. 부장에게 보이면 의심도 올리기 → 100이면 적발
--   4. 방금 복귀했는데 부장이 봤다면 → 아슬아슬 보너스
--
-- 오래 남아야 하는 정보(직급, 통장, 아이템, 도감)는 profile에,
-- 오늘 하루만 쓰는 정보는 today에 들어 있어요.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local Npc = require(script.Parent.Npc)
local Profiles = require(script.Parent.Profiles)

local States = SalaryConfig.States
local Ranks = SalaryConfig.Ranks
local Employees = {}

-- 플레이어가 앉을 자리 순서 (5번 = 뒷줄 가운데: 부장 바로 앞!)
local DESK_PRIORITY = { 5, 4, 6, 2, 1, 3 }
local TICK = 0.1
local AUTOSAVE_SECONDS = 60
local GAME_MINUTES_PER_SECOND = (SalaryConfig.END_MINUTE - SalaryConfig.START_MINUTE) / SalaryConfig.DAY_SECONDS
local PAYSLIP_ORDER = { "work", "blank", "webtoon", "phone", "shopping", "sleep", "recline", "toilet", "coffee" }

type DayRecord = {
	earned: { [string]: number }, -- 상태별 번 돈
	seconds: { [string]: number }, -- 상태별 보낸 시간
	nearMiss: number, -- 아슬아슬 보너스 합계
	caught: number, -- 오늘 적발 횟수
}

type EmployeeData = {
	profile: Profiles.Profile,
	canSave: boolean,
	desk: any,
	deskAction: string, -- 자리에서 고른 행동
	returnUntil: number?, -- 복귀 중이면 끝나는 시각
	state: string,
	suspicion: number,
	workSeconds: number,
	combo: number,
	lastReturnEnd: number?,
	nearMissUsed: boolean,
	toiletTime: number,
	coffeeTime: number,
	energyActive: boolean, -- 오늘 에너지 드링크를 마셨나
	fired: boolean,
	today: DayRecord,
}

local function newDay(): DayRecord
	return { earned = {}, seconds = {}, nearMiss = 0, caught = 0 }
end

local function inZone(zone: BasePart, position: Vector3): boolean
	local offset = zone.CFrame:PointToObjectSpace(position)
	return math.abs(offset.X) <= zone.Size.X / 2 and math.abs(offset.Y) <= zone.Size.Y / 2 and math.abs(offset.Z) <= zone.Size.Z / 2
end

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

local function randomLook()
	local shirts = {
		Color3.fromRGB(240, 240, 240),
		Color3.fromRGB(170, 200, 230),
		Color3.fromRGB(230, 200, 170),
		Color3.fromRGB(120, 120, 130),
		Color3.fromRGB(200, 170, 200),
	}
	return {
		skin = Color3.fromRGB(math.random(210, 240), math.random(170, 200), math.random(140, 170)),
		shirt = pick(shirts),
		pants = Color3.fromRGB(50, 50, 60),
	}
end

function Employees.start(office, boss, dayCycle, remotes)
	local data: { [Player]: EmployeeData } = {}
	local deskOwner: { [number]: Player } = {}
	local coworkers: { [number]: Model } = {}

	---------------------------------------------------------------- 동료 NPC
	for i, desk in office.desks do
		local coworker = Npc.create(SalaryConfig.CoworkerNames[(i - 1) % #SalaryConfig.CoworkerNames + 1], randomLook(), office.folder)
		Npc.setStatus(coworker, "⌨️")
		Npc.sit(coworker, desk.seat)
		coworkers[i] = coworker
	end

	---------------------------------------------------------------- 도우미
	local function rankOf(d: EmployeeData)
		return Ranks[d.profile.rank]
	end

	local function hasItem(d: EmployeeData, itemId: string): boolean
		return d.profile.items[itemId] == true
	end

	local function getHumanoid(player: Player): Humanoid?
		local character = player.Character
		return character and character:FindFirstChildOfClass("Humanoid")
	end

	local function isSeated(player: Player, d: EmployeeData): boolean
		local humanoid = getHumanoid(player)
		return humanoid ~= nil and d.desk.seat.Occupant == humanoid
	end

	-- 도감에 새 항목 기록 (처음일 때만 알림)
	local function unlock(player: Player, d: EmployeeData, entryId: string, emoji: string, name: string)
		if d.profile.collection[entryId] then
			return
		end
		d.profile.collection[entryId] = true
		remotes.Unlocked:FireClient(player, emoji, name)
	end

	local function unlockAchievement(player: Player, d: EmployeeData, achievementId: string)
		for _, achievement in SalaryConfig.Achievements do
			if achievement.id == achievementId then
				unlock(player, d, achievementId, achievement.emoji, achievement.name)
				return
			end
		end
	end

	-- 머리 위 이모지
	local function updateBubble(player: Player, state: string)
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		if not head then
			return
		end
		local bubble = head:FindFirstChild("StateBubble") :: BillboardGui?
		if not bubble then
			bubble = Instance.new("BillboardGui")
			bubble.Name = "StateBubble"
			bubble.Size = UDim2.fromOffset(60, 40)
			bubble.StudsOffset = Vector3.new(0, 2.4, 0)
			bubble.MaxDistance = 80
			local label = Instance.new("TextLabel")
			label.Name = "Emoji"
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.TextScaled = true
			label.Parent = bubble
			bubble.Parent = head
		end
		((bubble :: BillboardGui):FindFirstChild("Emoji") :: TextLabel).Text = States[state].emoji
	end

	-- 클라이언트 화면에 보여 줄 값들을 속성으로 내보내요
	local function publish(player: Player, d: EmployeeData)
		local todayMoney = 0
		for _, amount in d.today.earned do
			todayMoney += amount
		end
		todayMoney += d.today.nearMiss - d.today.caught * SalaryConfig.CAUGHT_PENALTY
		local profile = d.profile
		local nextRank = Ranks[profile.rank + 1]

		player:SetAttribute("SalaryState", d.state)
		player:SetAttribute("SalaryAction", d.deskAction)
		player:SetAttribute("Suspicion", math.floor(d.suspicion))
		player:SetAttribute("Warnings", profile.warnings)
		player:SetAttribute("TodayMoney", math.floor(todayMoney))
		player:SetAttribute("TotalMoney", math.floor(profile.money))
		player:SetAttribute("WorkSeconds", math.floor(d.workSeconds))
		player:SetAttribute("WorkQuota", rankOf(d).quota)
		player:SetAttribute("Combo", d.combo)
		player:SetAttribute("Seated", isSeated(player, d))
		player:SetAttribute("Fired", d.fired)
		player:SetAttribute("Rank", profile.rank)
		player:SetAttribute("XP", math.floor(profile.xp))
		player:SetAttribute("NextXP", if nextRank then nextRank.xp else 0)
		player:SetAttribute("Energy", profile.energy)
		player:SetAttribute("EnergyActive", d.energyActive)
		player:SetAttribute("CanSave", d.canSave)
		for _, item in SalaryConfig.Items do
			if not item.consumable then
				player:SetAttribute(`Item_{item.id}`, hasItem(d, item.id))
			end
		end
	end

	-- 도감은 자주 안 바뀌니 바뀔 때만 따로 보내요
	local function publishCollection(player: Player, d: EmployeeData)
		player:SetAttribute("Collection", HttpService:JSONEncode(d.profile.collection))
	end

	local function save(player: Player, d: EmployeeData)
		if d.canSave then
			Profiles.save(player, d.profile)
		end
	end

	local function seatPlayer(player: Player, d: EmployeeData)
		local character = player.Character
		local humanoid = getHumanoid(player)
		if not (character and humanoid) or humanoid.Health <= 0 then
			return
		end
		character:PivotTo(d.desk.seat.CFrame + Vector3.new(0, 3, 0))
		task.wait(0.1)
		d.desk.seat:Sit(humanoid)
	end

	---------------------------------------------------------------- 자리 배정 / 입장 / 퇴장
	local function assignDesk(player: Player)
		for _, index in DESK_PRIORITY do
			if not deskOwner[index] then
				deskOwner[index] = player
				local coworker = coworkers[index]
				if coworker then
					-- 동료를 내보내고 의자를 비워요
					for _, child in office.desks[index].seat:GetChildren() do
						if child:IsA("Weld") and child.Name == "SeatWeld" then
							child:Destroy()
						end
					end
					coworker:Destroy()
					coworkers[index] = nil
				end
				return office.desks[index]
			end
		end
		return nil
	end

	local function onPlayerAdded(player: Player)
		local profile, canSave = Profiles.load(player)
		if not player.Parent then
			return -- 불러오는 동안 나가 버림
		end
		local desk = assignDesk(player)
		if not desk then
			remotes.Notify:FireClient(player, "사무실 자리가 꽉 찼어요!")
			return
		end
		local d: EmployeeData = {
			profile = profile,
			canSave = canSave,
			desk = desk,
			deskAction = "work",
			returnUntil = nil,
			state = "work",
			suspicion = 0,
			workSeconds = 0,
			combo = 1,
			lastReturnEnd = nil,
			nearMissUsed = true,
			toiletTime = 0,
			coffeeTime = 0,
			energyActive = false,
			fired = false,
			today = newDay(),
		}
		data[player] = d
		player:SetAttribute("DeskIndex", desk.index)
		publish(player, d)
		publishCollection(player, d)
		if not canSave then
			remotes.Notify:FireClient(player, "💾 지금은 저장 기능이 꺼져 있어요. (스튜디오라면 API 접근 설정 확인)")
		end

		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart")
			task.wait(0.5)
			if dayCycle.phase ~= "offwork" then
				seatPlayer(player, d)
			end
		end)
		if player.Character and dayCycle.phase ~= "offwork" then
			task.spawn(seatPlayer, player, d)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local d = data[player]
		if d then
			save(player, d)
			deskOwner[d.desk.index] = nil
			data[player] = nil
		end
	end)

	-- 서버가 꺼질 때 모두 저장
	game:BindToClose(function()
		for player, d in data do
			save(player, d)
		end
	end)

	-- 자동 저장
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player, d in data do
				task.spawn(save, player, d)
			end
		end
	end)

	---------------------------------------------------------------- 행동 고르기
	remotes.SetAction.OnServerEvent:Connect(function(player, actionId)
		local d = data[player]
		if not d or d.fired or typeof(actionId) ~= "string" or not table.find(SalaryConfig.DeskActions, actionId) then
			return
		end
		if not isSeated(player, d) or dayCycle.phase == "offwork" then
			return
		end
		local info = States[actionId]
		if (info.unlockRank or 1) > d.profile.rank then
			remotes.Notify:FireClient(player, `🔒 {Ranks[info.unlockRank :: number].name}부터 할 수 있어요.`)
			return
		end
		if actionId == d.deskAction and not d.returnUntil then
			return
		end

		if actionId == "work" then
			-- 농땡이 → 일하기: 행동마다 복귀 시간이 걸려요 (에너지 드링크면 절반)
			local returnTime = (States[d.deskAction].returnTime or 0) * (if d.energyActive then 0.5 else 1)
			if d.returnUntil then
				return -- 이미 복귀 중
			elseif returnTime > 0 then
				d.returnUntil = os.clock() + returnTime
			else
				d.deskAction = "work"
				if d.state ~= "work" then
					d.lastReturnEnd = os.clock()
					d.nearMissUsed = false
				end
			end
		else
			d.returnUntil = nil
			d.deskAction = actionId
		end
	end)

	---------------------------------------------------------------- 매점
	remotes.BuyItem.OnServerInvoke = function(player: Player, itemId: any): (boolean, string)
		local d = data[player]
		local item = typeof(itemId) == "string" and SalaryConfig.getItem(itemId)
		if not d or not item then
			return false, "알 수 없는 상품이에요."
		end
		if not item.consumable and hasItem(d, item.id) then
			return false, "이미 가지고 있어요."
		end
		if d.profile.money < item.price then
			return false, "통장 잔고가 부족해요. 😢"
		end
		d.profile.money -= item.price
		if item.consumable then
			d.profile.energy += 1
		else
			d.profile.items[item.id] = true
		end
		publish(player, d)
		task.spawn(save, player, d)
		return true, `{item.emoji} {item.name} 구매 완료!`
	end

	remotes.UseEnergy.OnServerEvent:Connect(function(player)
		local d = data[player]
		if not d or d.energyActive or d.profile.energy <= 0 or dayCycle.phase == "offwork" then
			return
		end
		d.profile.energy -= 1
		d.energyActive = true
		remotes.Notify:FireClient(player, "⚡ 꿀꺽! 오늘 하루 복귀 속도 2배!")
	end)

	---------------------------------------------------------------- 적발과 해고
	local function fire(player: Player, d: EmployeeData)
		d.fired = true
		d.state = "fired"
		updateBubble(player, "fired")
		local profile = d.profile
		profile.stats.fired += 1
		-- 해고: 통장 0원 + 직급 한 단계 강등
		profile.money = 0
		profile.rank = math.max(1, profile.rank - 1)
		profile.xp = Ranks[profile.rank].xp
		profile.warnings = 0
		unlockAchievement(player, d, "fired")
		publishCollection(player, d)
		task.spawn(save, player, d)
	end

	local function caught(player: Player, d: EmployeeData)
		d.profile.warnings += 1
		d.profile.stats.caught += 1
		d.today.caught += 1
		d.combo = 1
		d.suspicion = 0
		d.deskAction = "work"
		d.returnUntil = nil
		unlockAchievement(player, d, "caught")
		publishCollection(player, d)
		local line = pick(SalaryConfig.BossLines.caught)
		if player.Character then
			boss:scold(player.Character, line)
		end

		if d.profile.warnings >= SalaryConfig.MAX_WARNINGS then
			fire(player, d)
			remotes.Fired:FireClient(player, line, Ranks[d.profile.rank].name)
		else
			remotes.Caught:FireClient(player, line, d.profile.warnings)
		end
	end

	---------------------------------------------------------------- 소음 (부장이 조사하러 올 곳)
	boss.noiseSource = function(): (Vector3?, number)
		local loudest, chance = nil, 0
		for _, d in data do
			local noise = States[d.state].noise or 0
			if noise > chance then
				loudest, chance = d.desk.behind, noise
			end
		end
		return loudest, chance
	end

	---------------------------------------------------------------- 매 틱 계산
	local function tick(player: Player, d: EmployeeData, dt: number)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if d.fired or not (character and root) then
			return
		end
		local now = os.clock()

		-- 1. 지금 상태
		local previous = d.state
		if isSeated(player, d) then
			d.toiletTime, d.coffeeTime = 0, 0
			if d.returnUntil and now >= d.returnUntil then
				d.returnUntil = nil
				d.deskAction = "work"
				d.lastReturnEnd = now
				d.nearMissUsed = false
			end
			d.state = if d.returnUntil then "returning" else d.deskAction
		else
			d.deskAction = "work" -- 일어나면 다시 앉을 때는 일하는 상태
			d.returnUntil = nil
			if inZone(office.toiletZone, root.Position) then
				d.state = "toilet"
				d.toiletTime += dt
			elseif inZone(office.pantryZone, root.Position) then
				d.state = "coffee"
				d.coffeeTime += dt
			else
				d.state = "roam"
			end
		end
		local info = States[d.state]
		if d.state ~= previous then
			updateBubble(player, d.state)
			if info.payLabel and d.state ~= "work" then
				unlock(player, d, `action_{d.state}`, info.emoji, info.name)
				publishCollection(player, d)
			end
		end

		-- 업적 체크
		if d.state == "toilet" and d.toiletTime >= 50 then
			unlockAchievement(player, d, "toilet_long")
		end
		if dayCycle.phase == "lunch" and (d.state == "sleep" or d.state == "recline") then
			unlockAchievement(player, d, "lunch_nap")
		end

		-- 2. 돈 벌기 (농땡이는 직급 배율을 받아요)
		local multiplier = if d.state == "work" then 1 else rankOf(d).bonus
		local income = info.income * multiplier * dt
		d.today.earned[d.state] = (d.today.earned[d.state] or 0) + income
		d.today.seconds[d.state] = (d.today.seconds[d.state] or 0) + dt
		if d.state == "work" then
			d.workSeconds += dt
		end

		-- 3. 의심도 (점심시간에는 부장이 없어서 안전)
		local decay = SalaryConfig.SUSPICION_DECAY * (if hasItem(d, "plant") then 1.25 else 1)
		if dayCycle.phase == "work" and boss.active then
			local rate = info.detect
			local coffeeGrace = if hasItem(d, "tumbler") then 90 else SalaryConfig.COFFEE_GRACE
			if d.state == "coffee" and d.coffeeTime <= coffeeGrace then
				rate = 0 -- 아직은 커피 타는 중으로 보여요
			end
			if info.screen and hasItem(d, "cover") then
				rate *= 0.7
			end
			local raised = false
			if rate > 0 then
				local seen, distance = boss:canSee(character)
				if seen then
					local closeness = math.clamp(1.5 - distance / boss.range, 0.5, 1.5)
					d.suspicion += rate * closeness * dt
					raised = true
				end
			end
			local toiletLimit = if hasItem(d, "dummy") then 150 else SalaryConfig.TOILET_LIMIT
			if d.state == "toilet" and d.toiletTime > toiletLimit then
				d.suspicion += 6 * dt -- 자리가 너무 오래 비어 있어요
				raised = true
			end
			if not raised then
				d.suspicion = math.max(0, d.suspicion - decay * dt)
			end

			-- 4. 아슬아슬 보너스
			if d.state == "work" and not d.nearMissUsed and d.lastReturnEnd and now - d.lastReturnEnd <= SalaryConfig.NEAR_MISS_WINDOW then
				local seen, distance = boss:canSee(character)
				if seen and distance < 25 then
					d.nearMissUsed = true
					local bonus = SalaryConfig.NEAR_MISS_BONUS * d.combo
					d.today.nearMiss += bonus
					d.profile.stats.nearMiss += 1
					remotes.NearMiss:FireClient(player, bonus, d.combo)
					unlockAchievement(player, d, "near_miss")
					if d.combo >= SalaryConfig.MAX_COMBO then
						unlockAchievement(player, d, "combo_max")
					end
					publishCollection(player, d)
					d.combo = math.min(d.combo + 1, SalaryConfig.MAX_COMBO)
				end
			end

			if d.suspicion >= 100 then
				caught(player, d)
			end
		else
			d.suspicion = math.max(0, d.suspicion - decay * dt)
		end
	end

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < TICK then
			return
		end
		local step = accumulator
		accumulator = 0
		for player, d in data do
			if dayCycle.phase ~= "offwork" then
				tick(player, d, step)
			end
			publish(player, d)
		end
	end)

	---------------------------------------------------------------- 하루 일정
	dayCycle:on("dayStart", function(weekday)
		boss:startDay(weekday)
		local isMonday = weekday == SalaryConfig.Weekdays[1]
		for player, d in data do
			if d.fired then
				d.fired = false
				remotes.Notify:FireClient(player, `📋 {Ranks[d.profile.rank].name}(으)로 재입사를 환영합니다… 이번엔 잘 좀 해 봐요.`)
			elseif isMonday and dayCycle.day > 1 and d.profile.warnings > 0 then
				d.profile.warnings = 0
				remotes.Notify:FireClient(player, "📅 새로운 한 주! 경고가 초기화됐어요.")
			end
			d.today = newDay()
			d.suspicion, d.workSeconds, d.combo = 0, 0, 1
			d.deskAction, d.state, d.returnUntil = "work", "work", nil
			d.energyActive = false
			updateBubble(player, "work")
			task.spawn(seatPlayer, player, d)
			remotes.Notify:FireClient(player, `🏢 {weekday.name} 출근! 오늘 부장님은 "{weekday.mood}"`)
		end
	end)

	dayCycle:on("lunchStart", function()
		boss:goLunch()
		for player in data do
			remotes.Notify:FireClient(player, "🍚 점심시간! 부장님이 나갔어요. 1시까지는 마음껏!")
		end
	end)

	dayCycle:on("lunchEnd", function()
		boss:backFromLunch()
		for player in data do
			remotes.Notify:FireClient(player, "⚠️ 1시! 부장님이 돌아왔어요!")
		end
	end)

	dayCycle:on("dayEnd", function()
		boss:leaveWork()
		for player, d in data do
			if d.fired then
				continue
			end
			local profile = d.profile
			local rank = rankOf(d)

			-- 명세서 항목
			local lines = { { label = `기본급 ({rank.name})`, amount = rank.basePay } }
			for _, stateId in PAYSLIP_ORDER do
				local amount = d.today.earned[stateId] or 0
				if amount >= 1 then
					local minutes = math.floor((d.today.seconds[stateId] or 0) * GAME_MINUTES_PER_SECOND)
					table.insert(lines, { label = `{States[stateId].payLabel} ({minutes}분)`, amount = math.floor(amount) })
				end
			end
			if d.today.nearMiss > 0 then
				table.insert(lines, { label = "아슬아슬 보너스", amount = d.today.nearMiss })
			end
			if d.today.caught > 0 then
				table.insert(lines, { label = `시말서 감봉 ({d.today.caught}회)`, amount = -d.today.caught * SalaryConfig.CAUGHT_PENALTY })
			end
			local quotaOk = d.workSeconds >= rank.quota
			if not quotaOk then
				table.insert(lines, { label = "업무 미달 감봉", amount = -SalaryConfig.QUOTA_PENALTY })
				profile.warnings += 1
			end

			local dayTotal = 0
			for _, line in lines do
				dayTotal += line.amount
			end
			profile.money = math.max(0, profile.money + dayTotal)
			profile.xp += math.max(0, dayTotal)
			profile.stats.days += 1

			-- 업적
			if d.today.caught == 0 and quotaOk and d.today.nearMiss > 0 then
				unlockAchievement(player, d, "perfect_day")
			end
			if profile.money >= 100000 then
				unlockAchievement(player, d, "rich")
			end

			-- 해고 또는 승진
			local fired = profile.warnings >= SalaryConfig.MAX_WARNINGS
			local promotedTo: string? = nil
			if fired then
				fire(player, d)
			else
				while Ranks[profile.rank + 1] and profile.xp >= Ranks[profile.rank + 1].xp do
					profile.rank += 1
					promotedTo = Ranks[profile.rank].name
				end
				if promotedTo then
					profile.warnings = 0 -- 승진하면 경고도 깨끗하게
					if profile.rank >= 4 then
						unlockAchievement(player, d, "rank_daeri")
					end
					if profile.rank >= 8 then
						unlockAchievement(player, d, "rank_isa")
					end
				end
			end
			publishCollection(player, d)

			remotes.Payslip:FireClient(player, {
				day = dayCycle.day,
				weekday = dayCycle:weekday().name,
				lines = lines,
				dayTotal = dayTotal,
				total = math.floor(profile.money),
				warnings = profile.warnings,
				quotaOk = quotaOk,
				workSeconds = math.floor(d.workSeconds),
				quota = rank.quota,
				fired = fired,
				promotedTo = promotedTo,
				rankName = Ranks[profile.rank].name,
			})
			publish(player, d)
			task.spawn(save, player, d)
		end
	end)
end

return Employees
