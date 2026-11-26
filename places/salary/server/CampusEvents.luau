-- 🎪 단지 행사: 날마다 단지가 조금씩 달라져요 (하루가 시작될 때 정해요)
--   🚚 요일별 푸드트럭: 요일마다 메뉴 두 가지 (SalaryConfig.StreetShops.truck 의 days)
--   🛍️ 금요일 플리마켓: 야외무대 앞에 좌판 세 개. 한 번 500원에 뽑기 (좌판마다 하루 한 번)
--   🌧️ 비 오는 날: 창밖 시선이 쉬고 경비원 시야가 줄어요. 대신 탁 트인 곳 수당이 없어요
--   🌸 벚꽃 주간: 4주에 한 번, 그 주 내내 나무가 분홍빛. 단지 산책 수입이 조금 올라요
--   비와 벚꽃은 ReplicatedStorage 속성(CampusRain · CampusBlossom)으로 알려요 → 화면(Weather)이 비·꽃잎을 그려요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local Theme = require(ReplicatedStorage.Shared.SalaryTheme)
local Campus = require(script.Parent.Campus)

local CampusEvents = {}

local BLOSSOM = { Color3.fromRGB(244, 190, 206), Color3.fromRGB(250, 214, 224) }

-- hooks: { charge = Employees.chargeClaw, prize = Employees.dartPrize }
function CampusEvents.start(office, dayCycle, remotes, hooks)
	local campus = Campus.get()
	if not campus then
		return
	end
	local random = Random.new()
	local leafColors: { [BasePart]: Color3 } = {}
	for _, leaf in campus.treeLeaves do
		leafColors[leaf] = leaf.Color
	end
	local fleaUsed: { [Player]: { [number]: boolean } } = {}

	-- 🛍️ 플리마켓 좌판 [E]
	for _, stall in campus.fleaStalls do
		local index = stall:GetAttribute("Stall")
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = `뽑기 ({SalaryConfig.FLEA_PRICE}원)`
		prompt.ObjectText = "🛍️ 플리마켓 좌판"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Parent = stall
		prompt.Triggered:Connect(function(player)
			fleaUsed[player] = fleaUsed[player] or {}
			if fleaUsed[player][index] then
				remotes.Notify:FireClient(player, "🛍️ 이 좌판은 오늘 이미 구경했어요. 다른 좌판으로!")
				return
			end
			local ok, message = hooks.charge(player, SalaryConfig.FLEA_PRICE)
			if not ok then
				remotes.Notify:FireClient(player, message)
				return
			end
			fleaUsed[player][index] = true
			local total = 0
			for _, entry in SalaryConfig.FLEA_PRIZES do
				total += entry[2]
			end
			local roll, prizeId = random:NextNumber(0, total), "none"
			for _, entry in SalaryConfig.FLEA_PRIZES do
				roll -= entry[2]
				if roll <= 0 then
					prizeId = entry[1]
					break
				end
			end
			local names = hooks.prize(player, { prizeId })
			remotes.Notify:FireClient(player, if prizeId == "none" then "🛍️ 잡동사니만 한가득… 꽝!" else `🛍️ 득템! {names[1] or ""}`, 3)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		fleaUsed[player] = nil
	end)

	local function menuText(weekdayName: string): (string, string)
		local names, lines = {}, {}
		for _, item in SalaryConfig.StreetShops.truck.items do
			if not item.days or table.find(item.days, weekdayName) then
				table.insert(names, item.name)
				table.insert(lines, `{item.emoji} {item.name} {item.price}`)
			end
		end
		return table.concat(names, " · "), table.concat(lines, "\n")
	end

	local function beginDay(weekday)
		local day = dayCycle.day
		local week = math.floor((day - 1) / #SalaryConfig.Weekdays)
		local blossom = week % SalaryConfig.BLOSSOM_EVERY == 1
		local rain = day > 1 and random:NextNumber() < SalaryConfig.RAIN_CHANCE
		local flea = weekday.name == "금요일"
		if RunService:IsStudio() and SalaryConfig.TEST_CAMPUS_EVENT ~= "" then -- 🧪 스튜디오 확인용
			rain = SalaryConfig.TEST_CAMPUS_EVENT == "rain"
			blossom = SalaryConfig.TEST_CAMPUS_EVENT == "blossom"
			flea = SalaryConfig.TEST_CAMPUS_EVENT == "flea" or flea
		end
		ReplicatedStorage:SetAttribute("CampusRain", rain)
		ReplicatedStorage:SetAttribute("CampusBlossom", blossom)
		-- 🌸 나무 색
		local i = 0
		for leaf, original in leafColors do
			i += 1
			leaf.Color = if blossom then BLOSSOM[i % 2 + 1] else original
		end
		-- 🛍️ 플리마켓 꺼내기 / 치우기
		campus.fleaFolder.Parent = if flea then office.folder else nil
		table.clear(fleaUsed)
		-- 🚚 오늘의 푸드트럭 간판
		local names, lines = menuText(weekday.name)
		for _, label in campus.truckLabels do
			label.Text = `오늘의 푸드트럭 · {names}`
		end
		if campus.truckMenuLabel then
			campus.truckMenuLabel.Text = `🚚 점심 한정\n{SalaryConfig.clockText(SalaryConfig.LUNCH_START)}~{SalaryConfig.clockText(SalaryConfig.LUNCH_END)}\n{lines}`
		end
		-- 알림
		local notes = { `🚚 오늘의 푸드트럭(점심): {names}` }
		if flea then
			table.insert(notes, "🛍️ 금요 플리마켓이 야외무대 앞에 열렸어요!")
		end
		if rain then
			table.insert(notes, "🌧️ 비 오는 날: 부장님이 창밖을 안 봐요. 대신 탁 트인 곳 수당도 없어요")
		end
		if blossom then
			table.insert(notes, `🌸 벚꽃 주간! 단지 산책 수입 +{math.floor((SalaryConfig.BLOSSOM_INCOME - 1) * 100 + 0.5)}%`)
		end
		task.delay(4, function()
			for _, player in Players:GetPlayers() do
				for _, note in notes do
					remotes.Notify:FireClient(player, note, 4)
				end
			end
		end)
	end
	dayCycle:on("dayStart", beginDay)
	-- 하루 중간에 켜졌을 때(첫날)도 간판은 맞춰 둬요
	local names, lines = menuText(dayCycle:weekday().name)
	for _, label in campus.truckLabels do
		label.Text = `오늘의 푸드트럭 · {names}`
	end
	if campus.truckMenuLabel then
		campus.truckMenuLabel.Text = `🚚 점심 한정\n{SalaryConfig.clockText(SalaryConfig.LUNCH_START)}~{SalaryConfig.clockText(SalaryConfig.LUNCH_END)}\n{lines}`
	end
	local _ = Theme
end

return CampusEvents
