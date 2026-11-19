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
local ChatTopics = require(ReplicatedStorage.Shared.ChatTopics)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)
local Teleport = require(ReplicatedStorage.Shared.Teleport)
local Npc = require(script.Parent.Npc)
local Profiles = require(script.Parent.Profiles)
local Snacks = require(script.Parent.Snacks)
local StockMarket = require(script.Parent.StockMarket)

local States = SalaryConfig.States
local Ranks = SalaryConfig.Ranks
local Employees = {}

-- 플레이어가 앉을 자리 순서 (5번 = 뒷줄 가운데: 부장 바로 앞!)
local DESK_PRIORITY = { 5, 4, 6, 2, 1, 3 }
local TICK = 0.1
local AUTOSAVE_SECONDS = 60
local GAME_MINUTES_PER_SECOND = (SalaryConfig.END_MINUTE - SalaryConfig.START_MINUTE) / SalaryConfig.DAY_SECONDS
local PAYSLIP_ORDER = { "work", "blank", "webtoon", "phone", "shopping", "sleep", "recline", "toilet", "candy", "coffee", "meeting", "docs", "chat", "ramen" }
local MOBILE_STATES = { "docs", "chat", "ramen" }
local MAX_TRADE = 1000 -- 한 번에 사고팔 수 있는 최대 주식 수

-- 🛡️ 요청 속도 제한 (해킹 툴로 연타하는 걸 막아요)
local allowAction = RateLimit.new(0.15)
local allowBuy = RateLimit.new(0.3)
local allowEnergy = RateLimit.new(1)
local allowTrade = RateLimit.new(0.15)
local allowMove = RateLimit.new(5)

type DayRecord = {
	earned: { [string]: number }, -- 상태별 번 돈
	seconds: { [string]: number }, -- 상태별 보낸 시간
	nearMiss: number, -- 아슬아슬 보너스 합계
	caught: number, -- 오늘 적발 횟수
	chatBonus: number, -- 수다 완주 보너스 합계
	chatTopics: number, -- 오늘 끝까지 나눈 수다 주제 수
	snackBonus: number, -- 간식 완식 보너스 합계
	eventBonus: number, -- 돌발 이벤트 보너스 합계 (소방 훈련 대피 등)
	snacksEaten: number,
	stockProfit: number, -- 오늘 주식으로 번(잃은) 돈 (통장에 바로 반영돼서 명세서 합계엔 안 들어가요)
	settled: boolean, -- 오늘 번 돈을 이미 통장에 넣었나 (퇴근 명세서 또는 해고)
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
	away: number, -- 🖥️ 자리 부재 게이지 (0~100)
	awayWarned: boolean, -- 자동 감지 경보를 보냈나
	leeWatch: number, -- 👀 이과장이 내 농땡이를 본 시간 (초)
	leeBribed: boolean, -- ☕ 오늘 커피를 상납했나 (고자질 1번 막아 줘요)
	leeCooldownUntil: number, -- 이 시각 전에는 다시 고자질 안 해요
	incomeRate: number, -- 지금 1초에 버는 돈
	bossMood: number, -- 🍻 회식 결과: 다음 날 의심도 배율 (1보다 작으면 너그러움)
	bossMoodDay: number, -- 그 배율이 적용되는 날
	coffeeTime: number,
	energyActive: boolean, -- 오늘 에너지 드링크를 마셨나
	activity: { kind: string, untilTime: number?, coworker: any? }?, -- 돌아다니며 하는 농땡이
	chatToken: any?, -- 진행 중인 수다 대화 (바뀌면 대화가 멈춰요)
	heldSnack: { id: string, progress: number }?, -- 들고 있는 간식과 먹은 양(초)
	ramenToday: number,
	fired: boolean,
	today: DayRecord,
}

local function newDay(): DayRecord
	return { earned = {}, seconds = {}, nearMiss = 0, caught = 0, chatBonus = 0, chatTopics = 0, snackBonus = 0, eventBonus = 0, snacksEaten = 0, stockProfit = 0, settled = false }
end

local function inZone(zone: BasePart, position: Vector3): boolean
	local offset = zone.CFrame:PointToObjectSpace(position)
	return math.abs(offset.X) <= zone.Size.X / 2 and math.abs(offset.Y) <= zone.Size.Y / 2 and math.abs(offset.Z) <= zone.Size.Z / 2
end

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

function Employees.start(office, boss, dayCycle, remotes, coworkers, events, lee)
	local data: { [Player]: EmployeeData } = {}
	local deskOwner: { [number]: Player } = {}

	---------------------------------------------------------------- 도우미
	local function rankOf(d: EmployeeData)
		return Ranks[d.profile.rank]
	end

	local function hasItem(d: EmployeeData, itemId: string): boolean
		return d.profile.items[itemId] == true
	end

	-- 🖥️ 자리 부재 게이지가 0 → 100%까지 차는 시간
	local function awayLimit(d: EmployeeData): number
		return if hasItem(d, "dummy") then 150 else SalaryConfig.AWAY_SECONDS
	end

	-- 오늘 지금까지 번 돈 (기본급 빼고, 아직 통장에 안 들어간 돈)
	local function runningTotal(d: EmployeeData): number
		local total = 0
		for _, amount in d.today.earned do
			total += amount
		end
		return total + d.today.nearMiss + d.today.chatBonus + d.today.snackBonus + d.today.eventBonus - d.today.caught * SalaryConfig.CAUGHT_PENALTY
	end

	local function getHumanoid(player: Player): Humanoid?
		local character = player.Character
		return character and character:FindFirstChildOfClass("Humanoid")
	end

	local function isSeated(player: Player, d: EmployeeData): boolean
		local humanoid = getHumanoid(player)
		return humanoid ~= nil and d.desk.seat.Occupant == humanoid
	end

	-- 화장실 변기에 앉아 있나?
	local function isOnToilet(player: Player): boolean
		local humanoid = getHumanoid(player)
		if not humanoid then
			return false
		end
		for _, seat in office.toiletSeats do
			if seat.Occupant == humanoid then
				return true
			end
		end
		return false
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
		local todayMoney = runningTotal(d)
		local profile = d.profile
		local nextRank = Ranks[profile.rank + 1]

		player:SetAttribute("SalaryState", d.state)
		player:SetAttribute("IncomeRate", math.floor(d.incomeRate * 10 + 0.5) / 10)
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
		player:SetAttribute("OnToilet", isOnToilet(player))
		player:SetAttribute("AwayGauge", math.floor(d.away))
		player:SetAttribute("LeeWatch", math.clamp(d.leeWatch / SalaryConfig.LEE_NOTICE, 0, 1))
		player:SetAttribute("LeeBribed", d.leeBribed)
		local held = d.heldSnack
		local heldInfo = held and SalaryConfig.getSnack(held.id)
		player:SetAttribute("HeldSnack", if heldInfo then heldInfo.id else "")
		player:SetAttribute("SnackProgress", if held and heldInfo then math.clamp(held.progress / heldInfo.seconds, 0, 1) else 0)
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

	-- 가진 주식도 바뀔 때만 보내요
	local function publishStocks(player: Player, d: EmployeeData)
		player:SetAttribute("StockHoldings", HttpService:JSONEncode(d.profile.stocks))
		player:SetAttribute("StockCost", HttpService:JSONEncode(d.profile.stockCost))
		player:SetAttribute("StockProfitTotal", math.floor(d.profile.stats.stockProfit))
	end

	local pendingSaves = 0
	local function save(player: Player, d: EmployeeData)
		if not d.canSave then
			return
		end
		-- 하루 중간에 나가도 오늘 번 돈이 사라지지 않게 "정산 대기" 금액으로 같이 저장해요.
		-- 다음에 들어오면 통장에 넣어 줘요.
		local unsettled = if d.today.settled or d.fired then 0 else runningTotal(d)
		d.profile.unsettled = math.max(0, math.floor(unsettled))
		pendingSaves += 1
		Profiles.save(player, d.profile)
		pendingSaves -= 1
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
				coworkers.remove(index) -- 동료를 내보내고 그 자리에 앉아요
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
			away = 0,
			awayWarned = false,
			leeWatch = 0,
			leeBribed = false,
			leeCooldownUntil = 0,
			bossMood = 1,
			incomeRate = 0,
			bossMoodDay = 0,
			coffeeTime = 0,
			energyActive = false,
			activity = nil,
			heldSnack = nil,
			ramenToday = 0,
			fired = false,
			today = newDay(),
		}
		data[player] = d
		player:SetAttribute("DeskIndex", desk.index)

		-- 지난번에 퇴근 전에 나갔다면, 그때까지 번 돈을 정산해 줘요
		local unsettled = profile.unsettled or 0
		if unsettled > 0 then
			profile.money += unsettled
			profile.xp += unsettled
			profile.unsettled = 0
			task.delay(3, function()
				if player.Parent then
					remotes.Bonus:FireClient(player, "💾 지난번 조퇴 전까지 번 돈 정산!", unsettled)
				end
			end)
		end

		-- 첫 플레이어가 들어오면, 그 사람이 마지막으로 일한 다음 날부터 하루를 시작해요
		-- (광장에 다녀와도 다시 월요일이 되지 않게)
		if not dayCycle.started then
			dayCycle.started = true
			dayCycle.day = profile.stats.days
			dayCycle:run()
		end
		publish(player, d)
		publishCollection(player, d)
		publishStocks(player, d)

		-- 🏢 회사 확인: 이 서버 사무실과 내 직급의 회사가 다르면 알려 줘요
		local here = SalaryConfig.getCompany(office.companyId)
		local mine = SalaryConfig.companyForRank(profile.rank)
		if here.id == "nunchi" then
			unlockAchievement(player, d, "company_nunchi")
			publishCollection(player, d)
		end
		if mine.id ~= here.id then
			task.delay(4, function()
				if player.Parent then
					remotes.Notify:FireClient(player, `🏢 오늘은 같이 온 동료를 따라 {here.name} 사무실로 출근했어요. (내 회사: {mine.name})`)
				end
			end)
		end
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
			endActivity(d)
			save(player, d)
			deskOwner[d.desk.index] = nil
			data[player] = nil
		end
	end)

	-- 서버가 꺼질 때 모두 저장
	game:BindToClose(function()
		for player, d in data do
			task.spawn(save, player, d)
		end
		-- 나가는 사람 저장이 끝날 때까지 서버가 꺼지지 않게 기다려요 (최대 25초)
		local waited = 0
		while pendingSaves > 0 and waited < 25 do
			waited += task.wait(0.5)
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
		if not allowAction(player) then
			return
		end
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
		if actionId == "snack" and not d.heldSnack then
			remotes.Notify:FireClient(player, "🍪 탕비실 간식 테이블에서 간식을 먼저 가져오세요!")
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
		if not allowBuy(player) then
			return false, "천천히 눌러 주세요."
		end
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
		if not allowEnergy(player) then
			return
		end
		local d = data[player]
		if not d or d.energyActive or d.profile.energy <= 0 or dayCycle.phase == "offwork" then
			return
		end
		d.profile.energy -= 1
		d.energyActive = true
		remotes.Notify:FireClient(player, "⚡ 꿀꺽! 오늘 하루 복귀 속도 2배!")
	end)

	---------------------------------------------------------------- 📈 화장실 주식
	local market = StockMarket.start()

	remotes.TradeStock.OnServerInvoke = function(player: Player, stockId: any, quantity: any): (boolean, string)
		if not allowTrade(player) then
			return false, "천천히 주문해 주세요."
		end
		local d = data[player]
		local stock = typeof(stockId) == "string" and SalaryConfig.getStock(stockId)
		-- 숫자가 아니거나, NaN·무한대거나, 0이거나, 한 번에 너무 많이 사면 거절
		-- (팔 때는 "전부 팔기"가 큰 수를 보내요. 가진 만큼만 팔려서 괜찮아요)
		if
			not d
			or not stock
			or typeof(quantity) ~= "number"
			or quantity ~= quantity
			or math.abs(quantity) == math.huge
			or quantity == 0
			or quantity > MAX_TRADE
		then
			return false, "잘못된 주문이에요."
		end
		if not isOnToilet(player) then
			return false, "🚽 주식은 변기에 앉아서만 할 수 있어요!"
		end
		if d.fired or dayCycle.phase == "offwork" then
			return false, "지금은 장이 닫혔어요."
		end
		local price = market.price(stock.id) :: number
		local profile = d.profile
		local owned = profile.stocks[stock.id] or 0
		quantity = math.floor(quantity)

		if quantity > 0 then
			local cost = price * quantity
			if profile.money < cost then
				return false, `통장 잔고가 부족해요. (필요 {cost}원)`
			end
			profile.money -= cost
			profile.stocks[stock.id] = owned + quantity
			profile.stockCost[stock.id] = (profile.stockCost[stock.id] or 0) + cost
			publishStocks(player, d)
			publish(player, d)
			return true, `{stock.emoji} {stock.name} {quantity}주 매수! (-{cost}원)`
		else
			local sellCount = math.min(owned, -quantity)
			if sellCount <= 0 then
				return false, "팔 주식이 없어요."
			end
			local revenue = price * sellCount
			local averageCost = (profile.stockCost[stock.id] or 0) / owned
			local profit = revenue - averageCost * sellCount
			profile.money += revenue
			profile.stocks[stock.id] = owned - sellCount
			profile.stockCost[stock.id] = math.max(0, (profile.stockCost[stock.id] or 0) - averageCost * sellCount)
			if profile.stocks[stock.id] == 0 then
				profile.stocks[stock.id] = nil
				profile.stockCost[stock.id] = nil
			end
			profile.stats.stockProfit += profit
			d.today.stockProfit += profit
			if profile.stats.stockProfit >= 10000 then
				unlockAchievement(player, d, "stock_buffett")
				publishCollection(player, d)
			end
			publishStocks(player, d)
			publish(player, d)
			task.spawn(save, player, d)
			local sign = if profit >= 0 then "+" else ""
			return true, `{stock.emoji} {stock.name} {sellCount}주 매도! 손익 {sign}{math.floor(profit)}원`
		end
	end

	---------------------------------------------------------------- 🍪 간식
	local snacks = Snacks.start(office, function(player: Player, snack): boolean
		local d = data[player]
		if not d or d.fired or dayCycle.phase == "offwork" then
			return false
		end
		if d.heldSnack then
			remotes.Notify:FireClient(player, "🍪 간식은 한 번에 하나만! 들고 있는 것부터 먹어요.")
			return false
		end
		d.heldSnack = { id = snack.id, progress = 0 }
		remotes.Notify:FireClient(player, `{snack.emoji} {snack.name}을(를) 슬쩍 챙겼다! 자리에서 [8]로 몰래 먹어요.`)
		return true
	end)

	local function finishSnack(player: Player, d: EmployeeData)
		local held = d.heldSnack
		local snack = held and SalaryConfig.getSnack(held.id)
		if not snack then
			return
		end
		d.heldSnack = nil
		d.deskAction = "work" -- 다 먹었으면 바로 일하는 척 (복귀 시간 없음)
		d.today.snackBonus += snack.bonus
		d.today.snacksEaten += 1
		remotes.Bonus:FireClient(player, `{snack.emoji} {snack.name} 완식!`, snack.bonus)
		if snack.id == "cake" then
			unlockAchievement(player, d, "cake_thief")
			publishCollection(player, d)
		elseif snack.id == "birthday" then
			unlockAchievement(player, d, "birthday_cake")
			publishCollection(player, d)
		end
	end

	---------------------------------------------------------------- 돌아다니며 하는 농땡이
	local function endActivity(d: EmployeeData)
		local activity = d.activity
		if activity and activity.kind == "chat" and activity.coworker then
			coworkers.setChatting(activity.coworker, false)
		end
		d.activity = nil
		d.chatToken = nil
	end

	local function canStartActivity(player: Player, d: EmployeeData?): boolean
		return d ~= nil and not d.fired and dayCycle.phase ~= "offwork" and not isSeated(player, d)
	end

	-- 📄 프린터에서 서류 들기
	local docsPrompt = Instance.new("ProximityPrompt")
	docsPrompt.ActionText = "서류 들기"
	docsPrompt.ObjectText = "📄 프린터"
	docsPrompt.RequiresLineOfSight = false
	docsPrompt.MaxActivationDistance = 7
	docsPrompt.Parent = office.printer
	docsPrompt.Triggered:Connect(function(player)
		local d = data[player]
		if not canStartActivity(player, d) then
			return
		end
		local employee = d :: EmployeeData
		endActivity(employee)
		employee.activity = { kind = "docs", untilTime = os.clock() + SalaryConfig.DOCS_SECONDS }
		remotes.Notify:FireClient(player, `📄 서류를 들었다! {SalaryConfig.DOCS_SECONDS}초 동안은 바빠 보여요.`)
	end)

	-- 🍜 탕비실 조리대에서 라면 끓이기
	local ramenPrompt = Instance.new("ProximityPrompt")
	ramenPrompt.ActionText = "라면 끓이기"
	ramenPrompt.ObjectText = "🍜 조리대"
	ramenPrompt.HoldDuration = 3
	ramenPrompt.RequiresLineOfSight = false
	ramenPrompt.MaxActivationDistance = 7
	ramenPrompt.Parent = office.pantryCounter
	ramenPrompt.Triggered:Connect(function(player)
		local d = data[player]
		if not canStartActivity(player, d) then
			return
		end
		local employee = d :: EmployeeData
		if employee.ramenToday >= SalaryConfig.RAMEN_PER_DAY then
			remotes.Notify:FireClient(player, "🍜 오늘 라면은 그만… 배불러요.")
			return
		end
		employee.ramenToday += 1
		endActivity(employee)
		employee.activity = { kind = "ramen", untilTime = os.clock() + SalaryConfig.RAMEN_SECONDS }
		remotes.Notify:FireClient(player, "🍜 후루룩! 냄새 때문에 부장님이 올 수도 있어요!")
	end)

	-- 💬 동료와 수다 (동료 NPC의 "수다 떨기"를 누르면 Coworkers가 여기로 알려 줘요)
	-- 주제를 하나 골라 동료 대사는 말풍선으로, 내 대사는 화면 아래로 주고받아요.
	-- 끝까지 하면 보너스 + 수다 도감 기록, 그리고 다음 주제로 이어져요.
	local function runConversation(player: Player, d: EmployeeData, coworker)
		local token = {}
		d.chatToken = token
		local function stillChatting(): boolean
			local activity = d.activity
			return d.chatToken == token
				and data[player] == d
				and activity ~= nil
				and activity.kind == "chat"
				and activity.coworker == coworker
				and not coworker.removed
		end

		while stillChatting() do
			local topic = ChatTopics.pick(coworker.name, d.profile.collection)
			for _, line in topic.lines do
				if not stillChatting() then
					return
				end
				if ChatTopics.isPlayerLine(line) then
					remotes.Notify:FireClient(player, `🗨️ 나: {ChatTopics.stripPlayer(line)}`)
				else
					Npc.say(coworker.model, line, SalaryConfig.CHAT_LINE_SECONDS + 0.3)
				end
				task.wait(SalaryConfig.CHAT_LINE_SECONDS)
			end
			if not stillChatting() then
				return
			end

			-- 주제 하나 완주!
			d.today.chatBonus += SalaryConfig.CHAT_TOPIC_BONUS
			d.today.chatTopics += 1
			unlock(player, d, `chat_{topic.id}`, "💬", topic.title) -- 처음 들은 주제면 "도감 등록!" 알림
			local collected = 0
			for entryId in d.profile.collection do
				if string.sub(entryId, 1, 5) == "chat_" then
					collected += 1
				end
			end
			if collected >= 15 then
				unlockAchievement(player, d, "chatterbox")
			end
			publishCollection(player, d)
			remotes.Bonus:FireClient(player, `💬 수다 성공! "{topic.title}"`, SalaryConfig.CHAT_TOPIC_BONUS)
			task.wait(1.5)
		end
	end

	local function startChat(player: Player, coworker)
		local d = data[player]
		if not canStartActivity(player, d) then
			return
		end
		local employee = d :: EmployeeData
		endActivity(employee)
		employee.activity = { kind = "chat", coworker = coworker }
		coworkers.setChatting(coworker, true)
		task.spawn(runConversation, player, employee, coworker)
	end
	Employees.startChat = startChat

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
		d.today.settled = true -- 해고되면 오늘 번 돈은 없어요
		unlockAchievement(player, d, "fired")
		publishCollection(player, d)
		task.spawn(save, player, d)
	end

	local function caught(player: Player, d: EmployeeData, customLine: string?)
		d.profile.warnings += 1
		d.profile.stats.caught += 1
		d.today.caught += 1
		d.combo = 1
		d.suspicion = 0
		local wasEating = d.state == "snack" or (d.state == "returning" and d.deskAction == "snack")
		if wasEating and d.heldSnack then
			d.heldSnack = nil
			remotes.Notify:FireClient(player, "🍪 간식을 압수당했다…")
		end
		d.deskAction = "work"
		d.returnUntil = nil
		-- 자리 비움 시간도 처음부터 (안 그러면 화장실에서 연달아 적발돼 바로 해고돼요)
		d.toiletTime, d.coffeeTime = 0, 0
		d.away, d.awayWarned = 0, false
		local humanoid = getHumanoid(player)
		if humanoid and humanoid.SeatPart and isOnToilet(player) then
			-- 부장님이 화장실 문을 두드려요: 변기에서 일으켜 세워요
			for _, child in humanoid.SeatPart:GetChildren() do
				if child:IsA("Weld") and child.Name == "SeatWeld" then
					child:Destroy()
				end
			end
			humanoid.Sit = false
		end
		endActivity(d)
		unlockAchievement(player, d, "caught")
		publishCollection(player, d)
		local line = customLine or pick(SalaryConfig.BossLines.caught)
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
		for player, d in data do
			local noise = States[d.state].noise or 0
			if noise > chance then
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local atDesk = d.state ~= "chat" and d.state ~= "ramen"
				loudest = if atDesk or not root then d.desk.behind else root.Position + Vector3.new(0, -3, 0)
				chance = noise
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

		-- 0. 남의 책상 의자에 앉았으면 일으켜 세워요 (변기는 괜찮아요)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local seatPart = humanoid and humanoid.SeatPart
		if humanoid and seatPart and seatPart.Name == "Seat" and seatPart ~= d.desk.seat then
			for _, child in seatPart:GetChildren() do
				if child:IsA("Weld") and child.Name == "SeatWeld" then
					child:Destroy()
				end
			end
			humanoid.Sit = false
			remotes.Notify:FireClient(player, "🙅 여기는 다른 사람 자리예요! ⭐ 표시된 내 자리에 앉아요.")
		end

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
			if d.activity then
				endActivity(d) -- 자리에 앉으면 돌아다니던 농땡이는 끝
			end
		else
			d.deskAction = "work" -- 일어나면 다시 앉을 때는 일하는 상태
			d.returnUntil = nil
			local activity = d.activity
			local inPantry = inZone(office.pantryZone, root.Position)
			-- 끝난 활동 정리
			if activity then
				local expired = activity.untilTime ~= nil and now >= activity.untilTime
				local leftPantry = activity.kind == "ramen" and not inPantry
				local tooFar = activity.kind == "chat"
					and (activity.coworker.removed or (activity.coworker.root.Position - root.Position).Magnitude > SalaryConfig.CHAT_RANGE)
				if expired or leftPantry or tooFar then
					if activity.kind == "docs" and expired then
						remotes.Notify:FireClient(player, "📄 서류 들고 너무 오래 돌아다녔어요. 이제 수상해 보여요!")
					end
					endActivity(d)
					activity = nil
				end
			end

			local onMeetingSeat = seatPart ~= nil and seatPart.Name == "MeetingSeat" and humanoid ~= nil and humanoid.SeatPart == seatPart
			if onMeetingSeat then
				d.state = "meeting" -- 📊 유리 회의실에서 회의하는 척 졸기
			elseif inZone(office.toiletZone, root.Position) then
				d.state = "toilet"
				d.toiletTime += dt
			elseif office.candyZone and inZone(office.candyZone, root.Position) then
				d.state = "candy" -- 🍭 공원 흡연구역에서 사탕 물기 (화장실처럼 자리 비움 시간이 쌓여요)
				d.toiletTime += dt
			elseif activity and activity.kind == "ramen" then
				d.state = "ramen"
			elseif inPantry then
				d.state = "coffee"
				d.coffeeTime += dt
			elseif activity then
				d.state = activity.kind -- "docs" 또는 "chat"
			else
				d.state = "roam"
			end
		end
		local info = States[d.state]
		if d.state ~= previous then
			updateBubble(player, d.state)
			if info.payLabel and d.state ~= "work" then
				unlock(player, d, `action_{d.state}`, info.emoji, info.name)
				local allMobile = true
				for _, mobileState in MOBILE_STATES do
					if not d.profile.collection[`action_{mobileState}`] then
						allMobile = false
					end
				end
				if allMobile then
					unlockAchievement(player, d, "mobile")
				end
				publishCollection(player, d)
			end
		end

		-- 처음 변기에 앉으면 주식 입문 지원금
		if d.state == "toilet" and not d.profile.stockGift and isOnToilet(player) then
			d.profile.stockGift = true
			d.profile.money += SalaryConfig.STOCK_STARTER_GIFT
			remotes.Bonus:FireClient(player, "🧻 화장실 증권 입문 지원금!", SalaryConfig.STOCK_STARTER_GIFT)
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
		if events:is("audit") and d.state ~= "work" then
			multiplier *= SalaryConfig.AUDIT_INCOME -- 🔍 감사 기간: 위험한 만큼 농땡이 수입 ×2
		end
		local blackout = events:is("blackout")
		if blackout and (d.state == "work" or info.screen) then
			multiplier = 0 -- 💡 정전: 컴퓨터가 꺼져서 일도, 화면 농땡이도 돈이 안 나와요
		end
		d.incomeRate = info.income * multiplier -- 화면에 "+N원/초"로 보여 줘요
		local income = info.income * multiplier * dt
		d.today.earned[d.state] = (d.today.earned[d.state] or 0) + income
		d.today.seconds[d.state] = (d.today.seconds[d.state] or 0) + dt
		if d.state == "work" and not blackout then
			d.workSeconds += dt
		end
		if d.state == "snack" then
			local held = d.heldSnack
			local snack = held and SalaryConfig.getSnack(held.id)
			if held and snack then
				held.progress += dt
				if held.progress >= snack.seconds then
					finishSnack(player, d)
				end
			else
				d.deskAction = "work"
			end
		end

		-- 2.5 🖥️ 자리 부재 게이지 (컴퓨터 자동 감지 시스템)
		--   근무 중 자리를 비우면 차오르고, 앉아 있으면 줄어요.
		--   소방 훈련·워크숍(나가야 하니까)·정전(컴퓨터가 꺼짐)·점심시간엔 멈춰요.
		local gaugeOn = dayCycle.phase == "work" and not events:is("drill") and not events:is("workshop") and not blackout
		if gaugeOn and not isSeated(player, d) then
			d.away = math.min(100, d.away + 100 / awayLimit(d) * dt)
			if d.away >= SalaryConfig.AWAY_WARN and not d.awayWarned then
				d.awayWarned = true
				remotes.AwayAlert:FireClient(player)
			end
			if d.away >= 100 then
				caught(player, d, "자동 감지 시스템에 걸렸어! 자리 비우고 어디 갔었어?!")
			end
		elseif not isSeated(player, d) then
			-- 게이지가 멈춘 시간 (점심 등): 그대로 둬요
		else
			d.away = math.max(0, d.away - SalaryConfig.AWAY_RECOVER * dt)
			if d.away < SalaryConfig.AWAY_WARN - 20 then
				d.awayWarned = false
			end
		end
		if d.fired then
			return
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
			if blackout and (d.state == "sleep" or d.state == "recline") then
				rate = 0 -- 💡 어두워서 자는 게 안 보여요
			end
			if d.bossMoodDay == dayCycle.day then
				rate *= d.bossMood -- 🍻 어제 회식 결과
			end
			local raised = false
			if rate > 0 then
				local seen, distance = boss:canSee(character)
				if seen and blackout and distance > boss.range * 0.5 then
					seen = false -- 어두워서 멀리는 안 보여요
				end
				if not seen then
					seen, distance = events:auditorSees(character) -- 🔍 감사팀
				end
				if seen then
					local closeness = math.clamp(1.5 - distance / boss.range, 0.5, 1.5)
					d.suspicion += rate * closeness * dt
					raised = true
				end
			end

			-- 👀 이과장: 농땡이를 LEE_NOTICE초 보면 고자질
			-- (과장부터는 동급이라 이과장이 고자질하지 않아요)
			local leeSees = d.profile.rank < SalaryConfig.LEE_IGNORE_RANK and lee:sees(character)
			if leeSees and rate > 0 then
				d.leeWatch += dt
				if d.leeWatch >= SalaryConfig.LEE_NOTICE and now >= d.leeCooldownUntil then
					d.leeWatch = 0
					d.leeCooldownUntil = now + SalaryConfig.LEE_COOLDOWN
					if d.leeBribed then
						d.leeBribed = false
						lee:say("…☕ 커피 값으로 못 본 걸로 할게요~", 3)
						remotes.Notify:FireClient(player, "☕ 이과장이 커피 덕분에 눈감아 줬어요! (오늘 커피 효과 끝)")
						unlockAchievement(player, d, "lee_bribe")
						publishCollection(player, d)
					else
						d.suspicion += SalaryConfig.LEE_TATTLE
						raised = true
						lee:say(`부장님~ {player.DisplayName} 씨 또 놀아요~`, 3)
						boss:callTo(root.Position)
						remotes.Notify:FireClient(player, "😱 이과장이 고자질했어요! 부장님이 이쪽으로 와요!")
					end
				end
			elseif leeSees and d.leeWatch > 0 then
				-- 들키기 직전에 일하는 척 성공!
				d.leeWatch = 0
				unlockAchievement(player, d, "lee_dodge")
				publishCollection(player, d)
			elseif not leeSees then
				d.leeWatch = 0
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

	---------------------------------------------------------------- ☕ 이과장 커피 상납
	lee.onBribe = function(player: Player): boolean
		local d = data[player]
		if not d or d.fired then
			return false
		end
		if d.leeBribed then
			remotes.Notify:FireClient(player, "☕ 오늘은 이미 커피를 드렸어요.")
			return false
		end
		if d.profile.money < SalaryConfig.LEE_BRIBE_COST then
			remotes.Notify:FireClient(player, `☕ 커피 살 돈이 없어요… ({SalaryConfig.LEE_BRIBE_COST}원 필요)`)
			return false
		end
		d.profile.money -= SalaryConfig.LEE_BRIBE_COST
		d.leeBribed = true
		remotes.Notify:FireClient(player, "☕ 커피 상납 완료! 오늘 이과장 고자질을 한 번 막아 줘요.")
		publish(player, d)
		return true
	end

	---------------------------------------------------------------- 🏢 스카우트 제의 수락 → 새 회사 사무실로
	remotes.MoveCompany.OnServerEvent:Connect(function(player)
		if not allowMove(player) then
			return
		end
		local d = data[player]
		if not d then
			return
		end
		local target = SalaryConfig.companyForRank(d.profile.rank)
		if target.id == office.companyId then
			remotes.Notify:FireClient(player, "🏢 이미 지금 회사에 다니고 있어요.")
			return
		end
		remotes.Notify:FireClient(player, `📦 {target.name}(으)로 짐 싸서 이동 중…`)
		save(player, d) -- 이동하기 전에 꼭 저장 (새 서버가 이 저장을 읽어서 사무실을 정해요)
		-- 같은 게임(월급루팡)의 새 전용 서버로 → 들어가면 내 직급에 맞는 사무실이 지어져요
		local ok, message = Teleport.send(game.PlaceId, { player }, true)
		if not ok and message then
			remotes.Notify:FireClient(player, message)
		end
	end)

	---------------------------------------------------------------- 🌸 워크숍
	events.canJoinWorkshop = function(player: Player): boolean
		local d = data[player]
		return d ~= nil and not d.fired
	end
	events.onWorkshopFinish = function(player: Player, place: number)
		local d = data[player]
		if not d then
			return
		end
		local bonus = SalaryConfig.WORKSHOP_BONUS + (if place == 1 then SalaryConfig.WORKSHOP_FIRST_BONUS else 0)
		d.today.eventBonus += bonus
		remotes.Bonus:FireClient(player, if place == 1 then "🌸 무궁화 1등!" else `🌸 골인! ({place}등)`, bonus)
		if place == 1 then
			unlockAchievement(player, d, "workshop_winner")
			publishCollection(player, d)
		end
	end

	---------------------------------------------------------------- 🍻 회식 (Dinner 모듈이 불러요)
	function Employees.dinnerParticipants(): { Player }
		local list = {}
		for player, d in data do
			if not d.fired then
				table.insert(list, player)
			end
		end
		return list
	end
	function Employees.dinnerReward(player: Player, score: number)
		local d = data[player]
		if not d then
			return
		end
		local mood = if score >= 6 then 0.75 elseif score >= 3 then 0.9 elseif score <= -2 then 1.15 else 1
		d.bossMood = mood
		d.bossMoodDay = dayCycle.day + 1
		local bonus = math.max(0, score) * SalaryConfig.DINNER_POINT
		if bonus > 0 then
			d.profile.money += bonus
			d.profile.xp += bonus
			remotes.Bonus:FireClient(player, `🍻 회식 점수 {score}점!`, bonus)
		end
		if score >= 6 then
			unlockAchievement(player, d, "dinner_ace")
			publishCollection(player, d)
		end
		remotes.Dinner:FireClient(player, "end", score, mood)
		publish(player, d)
		task.spawn(save, player, d)
	end

	---------------------------------------------------------------- 🎲 돌발 이벤트 연결
	events.snacks = snacks
	events.notifyAll = function(message: string)
		for player in data do
			remotes.Notify:FireClient(player, message)
		end
	end
	-- 🚒 소방 훈련 인원 점검: 집결지에 있으면 보너스, 없으면 경고
	events.onDrillCheck = function(isInZone: (Vector3) -> boolean)
		for player, d in data do
			if d.fired then
				continue
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and isInZone(root.Position) then
				d.today.eventBonus += SalaryConfig.DRILL_BONUS
				remotes.Bonus:FireClient(player, "🚒 모범 대피!", SalaryConfig.DRILL_BONUS)
				unlockAchievement(player, d, "drill_hero")
				publishCollection(player, d)
			else
				caught(player, d, "소방 훈련에 안 나왔어요?! 시말서 쓰세요!")
			end
		end
	end

	---------------------------------------------------------------- 하루 일정
	dayCycle:on("dayStart", function(weekday)
		boss:startDay(weekday)
		snacks.restock()
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
			endActivity(d)
			d.ramenToday = 0
			d.heldSnack = nil
			d.leeWatch, d.leeBribed = 0, false
			d.away, d.awayWarned = 0, false
			if d.bossMoodDay == dayCycle.day and d.bossMood ~= 1 then
				remotes.Notify:FireClient(
					player,
					if d.bossMood < 1
						then `🍻 어제 회식 덕분에 부장님이 너그러워요! (의심도 {math.floor((1 - d.bossMood) * 100 + 0.5)}% 덜 올라요)`
						else "🍻 어제 회식 때 서운하셨는지 부장님이 예민해요… (의심도 더 올라요)"
				)
			end
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
			endActivity(d)
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
			if d.today.snackBonus > 0 then
				table.insert(lines, { label = `간식 완식 보너스 ({d.today.snacksEaten}개)`, amount = d.today.snackBonus })
			end
			if d.today.chatBonus > 0 then
				table.insert(lines, { label = `수다 완주 보너스 ({d.today.chatTopics}개)`, amount = d.today.chatBonus })
			end
			if d.today.eventBonus > 0 then
				table.insert(lines, { label = "돌발 이벤트 보너스", amount = d.today.eventBonus })
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
			d.today.settled = true
			profile.stats.days += 1

			-- 업적
			if d.today.caught == 0 and events.todayId == "audit" then
				unlockAchievement(player, d, "audit_survivor")
			end
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
				stockProfit = math.floor(d.today.stockProfit),
				promotedTo = promotedTo,
				-- 🏢 새 직급이면 더 큰 회사에서 스카우트 제의가 와요
				moveTo = if not fired and SalaryConfig.companyForRank(profile.rank).id ~= office.companyId
					then SalaryConfig.companyForRank(profile.rank).name
					else nil,
				rankName = Ranks[profile.rank].name,
			})
			publish(player, d)
			task.spawn(save, player, d)
		end
	end)
end

return Employees
