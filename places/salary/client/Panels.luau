-- 가운데 뜨는 창: 입사 안내, 월급명세서(+승진), 해고 통지, 🏪 사내 매점, 📖 도감

local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SalaryConfig = require(Shared:WaitForChild("SalaryConfig"))
local ChatTopics = require(Shared:WaitForChild("ChatTopics"))
local Ui = require(Shared:WaitForChild("Ui"))
local Hud = require(script.Parent.Hud)
local Sounds = require(Shared:WaitForChild("Sounds"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local gui = Ui.gui
local comma = Hud.comma
local States = SalaryConfig.States
local Ranks = SalaryConfig.Ranks

local INK = Color3.fromRGB(30, 30, 40)
local MUTED = Color3.fromRGB(110, 110, 120)
local RED = Color3.fromRGB(200, 50, 40)

local Panels = {}
local current: Frame? = nil

local function close()
	if current then
		current:Destroy()
		current = nil
	end
end

-- 창이 화면보다 크면 화면에 맞게 줄여요 (작은 창, 노트북, 폰 대비)
local function fitScale(width: number, height: number): number
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local availableHeight = (viewport.Y - 70) * 0.95 -- 위쪽 로블록스 메뉴 막대 빼고
	local availableWidth = viewport.X * 0.95
	return math.clamp(math.min(availableWidth / width, availableHeight / height), 0.4, 1)
end

local function sheet(width: number, height: number): Frame
	close()
	local frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = Color3.fromRGB(250, 250, 245),
		ZIndex = 30,
		Parent = gui,
	}, {
		Ui.corner(12),
		Ui.stroke(Color3.fromRGB(60, 60, 70), 3),
		Ui.padding(20),
		Ui.make("UIScale", { Scale = fitScale(width, height) }),
	})

	-- 게임에 막 들어온 순간엔 화면 크기가 아직 정확하지 않아서 창이 너무 작게 계산될 수 있어요.
	-- 창이 열려 있는 동안 화면 크기를 계속 확인해서 다시 맞춰요.
	local uiScale = frame:FindFirstChildOfClass("UIScale") :: UIScale
	task.spawn(function()
		while frame.Parent do
			uiScale.Scale = fitScale(width, height)
			task.wait(0.3)
		end
	end)

	-- 오른쪽 위 ✕ 닫기
	local closeButton = Ui.make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 10, 0, -10),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = Color3.fromRGB(225, 225, 228),
		Text = "X", -- ✕ 기호는 로블록스 글꼴에 없어서 네모로 보여요
		TextColor3 = Color3.fromRGB(60, 60, 70),
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		ZIndex = 33,
		Parent = frame,
	}, { Ui.corner(18) })
	closeButton.Activated:Connect(function()
		if current == frame then
			close()
		end
	end)

	current = frame
	return frame
end

local function line(parent: Instance, y: number, height: number, content: string, props: { [string]: any }?): TextLabel
	local options = {
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		Text = content,
		TextColor3 = INK,
		Font = Enum.Font.GothamMedium,
		TextSize = 17,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 31,
		Parent = parent,
	}
	for key, value in props or {} do
		options[key] = value
	end
	return Ui.make("TextLabel", options)
end

local function button(parent: Instance, x: number, label: string, onClick: () -> ())
	local b = Ui.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, x, 1, 0),
		Size = UDim2.fromOffset(170, 42),
		Text = label,
		ZIndex = 31,
		Parent = parent,
	})
	b.Activated:Connect(onClick)
end

local function goLobby()
	Remotes.ReturnToLobby:FireServer()
end

---------------------------------------------------------------------------
-- 입사 안내
---------------------------------------------------------------------------
-- 2페이지로 나눠서 글씨를 크게 보여 줘요 (한 장에 다 넣으면 화면에 맞추느라 너무 작아져요)
local WELCOME_PAGES = {
	{
		title = "📢 (주)고결상사 입사를 환영합니다!",
		lines = {
			"💰 목표: 일은 최소로, 월급은 최대로!",
			"🪑 자리에 앉아 숫자키 [1]~[8]로 농땡이를 골라요",
			"👔 김부장에게 들키면 의심도 ⬆️, 100%면 🚨 적발",
			"👀 부장 머리 위를 보세요: 🖥️ 안전 / 👀 위험",
			"⚠️ 하루 업무는 꼭 채우기! 경고 3번이면 📦 해고",
		},
	},
	{
		title = "💡 월급루팡 꿀팁",
		lines = {
			"😅 아슬아슬하게 복귀하면 보너스 + 콤보",
			"🚶 서류 들기 · 동료와 수다 · 탕비실 라면",
			"🍪 탕비실 간식을 챙겨서 자리에서 [8]로 몰래 먹기",
			"🚽 화장실 변기에 앉으면 📈 주식 거래 (가짜 주식)",
			"📈 승진하면 새 농땡이! 🏪 사내 매점(창가 계산대) · 📖 도감도 있어요",
			"🙈 진짜 회사라면? [B] 화면 숨기기",
		},
	},
}

function Panels.showWelcome(page: number?)
	local index = page or 1
	local info = WELCOME_PAGES[index]
	local frame = sheet(700, 430)
	line(frame, 0, 40, info.title, { Font = Enum.Font.GothamBlack, TextSize = 30 })
	line(frame, 0, 40, `{index}/{#WELCOME_PAGES}`, {
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = MUTED,
		TextSize = 18,
		Size = UDim2.new(1, -46, 0, 40),
	})
	for i, text in info.lines do
		line(frame, 56 + (i - 1) * 46, 40, text, { TextSize = 22, Font = Enum.Font.GothamMedium })
	end
	if index < #WELCOME_PAGES then
		if index > 1 then
			button(frame, -95, "◀ 이전", function()
				Panels.showWelcome(index - 1)
			end)
		end
		button(frame, if index > 1 then 95 else 0, "다음 ▶", function()
			Panels.showWelcome(index + 1)
		end)
	else
		button(frame, -95, "◀ 이전", function()
			Panels.showWelcome(index - 1)
		end)
		button(frame, 95, "출근하기!", close)
	end
end


---------------------------------------------------------------------------
-- 월급명세서
---------------------------------------------------------------------------
Remotes:WaitForChild("Payslip").OnClientEvent:Connect(function(slip)
	Sounds.play("swoosh", 0.5)
	if slip.promotedTo then
		Sounds.play("ping", 0.7, 1.3)
	end
	local rows = #slip.lines
	local extra = (if slip.promotedTo then 70 else 0) + (if slip.moveTo then 76 else 0)
	local frame = sheet(470, 280 + rows * 26 + extra)
	line(frame, 0, 30, `🧾 급여명세서 · {slip.day}일차 ({slip.weekday})`, { Font = Enum.Font.GothamBlack, TextSize = 22 })

	local y = 42
	for _, item in slip.lines do
		line(frame, y, 24, item.label)
		line(frame, y, 24, `{comma(item.amount)}원`, {
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = if item.amount < 0 then RED else INK,
		})
		y += 26
	end
	Ui.make("Frame", {
		Position = UDim2.fromOffset(0, y + 4),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = Color3.fromRGB(60, 60, 70),
		ZIndex = 31,
		Parent = frame,
	})
	line(frame, y + 12, 26, "실수령액", { Font = Enum.Font.GothamBlack, TextSize = 20 })
	line(frame, y + 12, 26, `{comma(slip.dayTotal)}원`, {
		Font = Enum.Font.GothamBlack,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local status = `🏦 통장 잔고 {comma(slip.total)}원 · 경고 {slip.warnings}/{SalaryConfig.MAX_WARNINGS}`
	if slip.stockProfit and slip.stockProfit ~= 0 then
		status ..= `\n📈 오늘 화장실 주식 손익 {if slip.stockProfit > 0 then "+" else ""}{comma(slip.stockProfit)}원 (통장에 바로 반영됨)`
	end
	if not slip.quotaOk then
		status ..= `\n📄 업무 미달! ({slip.workSeconds}/{slip.quota}초) 경고 +1`
	end
	if slip.targetOk == false then
		status ..= `\n💰 실적 미달! ({comma(slip.earned)}/{comma(slip.target)}원) 경고 +1`
	end
	if slip.fired then
		status ..= `\n📦 경고 누적으로 해고… 통장 0원, {slip.rankName}(으)로 강등돼 재입사해요.`
	end
	line(frame, y + 46, 80, status, { TextSize = 15, TextColor3 = MUTED })

	if slip.promotedTo then
		local banner = Ui.make("Frame", {
			Position = UDim2.fromOffset(0, y + 110),
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundColor3 = Color3.fromRGB(255, 230, 150),
			ZIndex = 31,
			Parent = frame,
		}, { Ui.corner(10) })
		line(banner, 6, 46, `🎉 인사 발령: {slip.promotedTo}(으)로 승진!\n기본급과 농땡이 수입이 올랐어요.`, {
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 32,
		})
		Hud.popup(`🎉 {slip.promotedTo} 승진!`, Color3.fromRGB(255, 210, 80), 3)
	end

	-- 🏢 스카우트 제의 (더 큰 회사로 이직)
	if slip.moveTo then
		local top = y + 110 + (if slip.promotedTo then 70 else 0)
		local offer = Ui.make("Frame", {
			Position = UDim2.fromOffset(0, top),
			Size = UDim2.new(1, 0, 0, 66),
			BackgroundColor3 = Color3.fromRGB(200, 235, 240),
			ZIndex = 31,
			Parent = frame,
		}, { Ui.corner(10) })
		line(offer, 4, 26, `📦 {slip.moveTo}에서 스카우트 제의가 왔어요!`, {
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 32,
		})
		local accept = Ui.button({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 30),
			Size = UDim2.fromOffset(220, 32),
			Text = "🏢 새 회사로 출근하기",
			TextSize = 16,
			ZIndex = 32,
			Parent = offer,
		})
		accept.Activated:Connect(function()
			accept.Text = "📦 짐 싸는 중…"
			Remotes.MoveCompany:FireServer()
		end)
	end

	button(frame, -95, "🏛️ 광장으로", goLobby)
	button(frame, 95, "닫기 (출근 준비)", close)
end)

---------------------------------------------------------------------------
-- 해고 통지
---------------------------------------------------------------------------
Remotes:WaitForChild("Fired").OnClientEvent:Connect(function(bossLine: string, rankName: string)
	Sounds.play("bass", 0.7, 0.6)
	local frame = sheet(480, 320)
	line(frame, 0, 40, "📦 해고 통지", { Font = Enum.Font.GothamBlack, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center })
	line(
		frame,
		52,
		170,
		`김부장: "{bossLine}"\n\n경고 {SalaryConfig.MAX_WARNINGS}회 누적으로 해고되었습니다.\n짐 싸서 나가… 오늘은 더 이상 돈을 벌 수 없어요.\n\n내일 아침 통장 0원, {rankName}(으)로 재입사해요.\n(산 아이템과 도감은 그대로예요)`,
		{ TextXAlignment = Enum.TextXAlignment.Center }
	)
	button(frame, -95, "🏛️ 광장으로", goLobby)
	button(frame, 95, "닫기", close)
end)

---------------------------------------------------------------------------
-- 🏪 매점
---------------------------------------------------------------------------
-- 🏪 사내 매점 (사무실의 매점 계산대에서 [E] 주문하기로 열려요)
--   탭 두 개: 🧰 사무용품(화분·텀블러·이어폰…) / 🎁 부장님 선물(홍삼·꽃다발·초콜릿)
function Panels.showShop(startTab: string?)
	local items = SalaryConfig.Items
	local gifts = SalaryConfig.StreetShops.store.items
	local rowsMax = math.max(#items, #gifts)
	local frame = sheet(560, 170 + rowsMax * 64)
	line(frame, 0, 30, "🏪 사내 매점", { Font = Enum.Font.GothamBlack, TextSize = 24 })
	local balance = line(frame, 0, 30, "", {
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamBold,
		Size = UDim2.new(1, -44, 0, 30), -- 오른쪽 위 닫기 버튼 자리는 비워 둬요
	})
	local message = line(frame, 76 + rowsMax * 64 + 6, 22, "", { TextSize = 15, TextColor3 = MUTED })

	-- 탭
	local pages: { [string]: Frame } = {}
	local tabButtons: { [string]: TextButton } = {}
	local function page(id: string): Frame
		local f = Ui.make("Frame", {
			Position = UDim2.fromOffset(0, 80),
			Size = UDim2.new(1, 0, 0, rowsMax * 64),
			BackgroundTransparency = 1,
			ZIndex = 31,
			Parent = frame,
		})
		pages[id] = f
		return f
	end
	local function selectTab(id: string)
		for tabId, f in pages do
			f.Visible = tabId == id
			tabButtons[tabId].BackgroundColor3 = if tabId == id then Color3.fromRGB(255, 200, 80) else Color3.fromRGB(200, 200, 205)
		end
		message.Text = if id == "gifts" then "🎁 산 선물은 부장님께 다가가 [E] 말 걸기로 드려요" else ""
		message.TextColor3 = MUTED
	end
	for i, info in { { "goods", "🧰 사무용품" }, { "gifts", "🎁 부장님 선물" } } do
		local b = Ui.button({
			Position = UDim2.fromOffset((i - 1) * 150, 36),
			Size = UDim2.fromOffset(140, 34),
			Text = info[2],
			TextSize = 16,
			ZIndex = 31,
			Parent = frame,
		})
		b.Activated:Connect(function()
			Sounds.play("click", 0.4)
			selectTab(info[1])
		end)
		tabButtons[info[1]] = b
	end

	local function row(parent: Frame, i: number, title: string, description: string): TextButton
		local y = (i - 1) * 64
		line(parent, y, 22, title, { Font = Enum.Font.GothamBold })
		line(parent, y + 22, 36, description, { TextSize = 14, TextColor3 = MUTED, Size = UDim2.new(1, -120, 0, 36) })
		return Ui.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, y + 8),
			Size = UDim2.fromOffset(110, 40),
			TextSize = 16,
			ZIndex = 32,
			Parent = parent,
		})
	end

	-- 🧰 사무용품
	local goods = page("goods")
	local rows = {}
	for i, item in items do
		local buy = row(goods, i, `{item.emoji} {item.name} · {comma(item.price)}원`, item.description)
		buy.Activated:Connect(function()
			local ok, result = Remotes.BuyItem:InvokeServer(item.id)
			message.Text = result
			message.TextColor3 = if ok then Color3.fromRGB(40, 140, 70) else RED
		end)
		rows[item.id] = buy
	end

	-- 🎁 부장님 선물
	local giftPage = page("gifts")
	for i, item in gifts do
		local buy = row(giftPage, i, `{item.emoji} {item.name} · {comma(item.price)}원`, item.description)
		buy.Text = "사기"
		buy.Activated:Connect(function()
			local ok, result = Remotes.BuyStreet:InvokeServer("store", item.id)
			message.Text = result
			message.TextColor3 = if ok then Color3.fromRGB(40, 140, 70) else RED
			if ok then
				Sounds.play("ping", 0.6, 1.2)
			end
		end)
	end
	selectTab(startTab or "goods")

	-- 잔고와 버튼 상태를 계속 갱신
	task.spawn(function()
		while current == frame do
			local money = player:GetAttribute("TotalMoney") or 0
			balance.Text = `🏦 {comma(money)}원`
			for _, item in items do
				local buy = rows[item.id]
				local owned = not item.consumable and player:GetAttribute(`Item_{item.id}`) == true
				buy.Text = if owned then "보유 중 ✅" elseif item.consumable then `구매 ({player:GetAttribute("Energy") or 0}개)` else "구매"
				buy.AutoButtonColor = not owned
				buy.BackgroundColor3 = if owned then Color3.fromRGB(200, 200, 200) else Ui.COLORS.brass
			end
			task.wait(0.3)
		end
	end)

	button(frame, 0, "닫기", close)
	Sounds.play("swoosh", 0.4)
end

---------------------------------------------------------------------------
-- 🎒 소지품: 가진 물건과 쓰는 법 한눈에
---------------------------------------------------------------------------
-- 사무용품마다 "어떻게 쓰는지" 설명 (모두 사면 자동으로 효과가 켜져요)
local ITEM_HOW = {
	plant = "책상 위에 놓여 있어요. 부장님 의심도가 25% 더 빨리 줄어요.",
	tumbler = "책상 위에 있어요. 탕비실에서 커피 타는 척을 90초까지 버텨요.",
	cover = "모니터를 감싸요. 웹툰·폰·쇼핑 같은 화면 농땡이가 30% 덜 들켜요.",
	earphones = "책상 위에 있어요. 부장님 발소리를 멀리서 듣고, 화면 위에 부장님 상태가 보여요.",
	dummy = "내가 자리를 비우면 의자에 앉아 있어요. 자리 부재 게이지가 천천히 차요 (150초).",
}

function Panels.showBag()
	local frame = sheet(600, 560)
	line(frame, 0, 32, "🎒 내 소지품", { Font = Enum.Font.GothamBlack, TextSize = 26 })
	line(frame, 34, 22, "사무용품은 사면 자동으로 효과가 켜져요 (내 책상 위에 보여요). 소모품은 여기서 써요!", { TextSize = 14, TextColor3 = MUTED })
	local list = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 1, -122),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 31,
		Parent = frame,
	}, { Ui.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local order = 0
	local function header(textValue: string)
		order += 1
		line(list, 0, 26, textValue, { Size = UDim2.new(1, -10, 0, 26), Font = Enum.Font.GothamBlack, TextSize = 18, LayoutOrder = order, ZIndex = 32 })
	end
	local function entry(title: string, description: string, owned: boolean, buttonText: string?, onClick: (() -> ())?): TextButton?
		order += 1
		local row = Ui.make("Frame", {
			Size = UDim2.new(1, -10, 0, 54),
			BackgroundColor3 = if owned then Color3.fromRGB(235, 245, 235) else Color3.fromRGB(235, 235, 235),
			LayoutOrder = order,
			ZIndex = 32,
			Parent = list,
		}, { Ui.corner(8), Ui.padding(6) })
		line(row, 0, 20, title, { Font = Enum.Font.GothamBold, TextSize = 16, ZIndex = 33, TextColor3 = if owned then INK else MUTED })
		line(row, 20, 22, description, { TextSize = 13, ZIndex = 33, TextColor3 = MUTED, Size = UDim2.new(1, if buttonText then -110 else 0, 0, 22) })
		if buttonText then
			local b = Ui.button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(100, 34),
				Text = buttonText,
				TextSize = 15,
				ZIndex = 34,
				Parent = row,
			})
			if onClick then
				b.Activated:Connect(onClick)
			end
			return b
		end
		return nil
	end

	-- 🧰 사무용품 (자동 효과)
	header("🧰 사무용품 (자동 효과)")
	for _, item in SalaryConfig.Items do
		if item.consumable then
			continue
		end
		local owned = player:GetAttribute(`Item_{item.id}`) == true
		entry(`{item.emoji} {item.name} {if owned then "✅ 보유 중" else "· 🏪 사내 매점에서 구매"}`, ITEM_HOW[item.id] or item.description, owned)
	end

	-- ⚡ 소모품과 들고 있는 것
	header("🖐️ 쓰는 물건")
	local energy = player:GetAttribute("Energy") or 0
	local energyActive = player:GetAttribute("EnergyActive") == true
	entry(
		`⚡ 에너지 드링크 x{energy}`,
		if energyActive then "오늘 마셨어요! 복귀 시간 절반 효과 중" else "마시면 오늘 하루 일하는 척 복귀 시간이 절반!",
		energy > 0 or energyActive,
		if energy > 0 and not energyActive then "마시기" else nil,
		function()
			Remotes.UseEnergy:FireServer()
			Sounds.play("ping", 0.5, 1.2)
			close()
		end
	)
	local snack = SalaryConfig.getSnack(player:GetAttribute("HeldSnack") or "")
	if snack then
		local percent = math.floor((player:GetAttribute("SnackProgress") or 0) * 100)
		entry(`{snack.emoji} {snack.name} ({percent}% 먹음)`, "내 자리에 앉아서 [8] 간식 먹기로 몰래 먹어요. 다 먹으면 보너스!", true)
	else
		entry("🍪 들고 있는 간식 없음", "탕비실 간식 테이블이나 눈치 스트리트 디저트집에서 가져와요", false)
	end
	local giftId = player:GetAttribute("HeldGiftId") or ""
	local gift = giftId ~= "" and SalaryConfig.getStreetItem("store", giftId)
	if gift then
		entry(`{gift.emoji} {gift.name}`, "부장님께 다가가서 [E] 말 걸기 → 선물 드리기! " .. gift.description, true)
	else
		entry("🎁 들고 있는 선물 없음", "🏪 사내 매점 '부장님 선물' 탭에서 사요 (홍삼 = 경고 -1)", false)
	end
	local buffs = player:GetAttribute("Buffs") or ""
	entry(if buffs ~= "" then `☕ 오늘 마신 음료 {buffs}` else "☕ 오늘 마신 음료 없음", "눈치 스트리트 카페 음료는 오늘 하루 효과가 있어요", buffs ~= "")

	-- 🎟️ 모은 것
	header("📦 모은 것")
	local owned = HttpService:JSONDecode(player:GetAttribute("Plushies") or "{}")
	local kinds, total = 0, 0
	for _, count in owned do
		kinds += 1
		total += count
	end
	entry(`🧸 인형 {total}개 ({kinds}/{#SalaryConfig.Plushies}종)`, "🧸 버튼에서 보고, 책상에 3개까지 진열할 수 있어요", total > 0, "보기", function()
		Panels.showPlushies()
	end)
	entry(`🎟️ 오락실 티켓 {player:GetAttribute("Tickets") or 0}장`, "눈치 스트리트 오락실 경품 교환대에서 써요", (player:GetAttribute("Tickets") or 0) > 0)

	button(frame, 0, "닫기", close)
	Sounds.play("swoosh", 0.4)
end

---------------------------------------------------------------------------
-- 🪑 내 자리 꾸미기 + 🏆 칭호 (온라인 주문 → 바로 배송)
---------------------------------------------------------------------------
local function decodeAttr(name: string, fallback: any): any
	local ok, value = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute(name) or "")
	end)
	return if ok and typeof(value) == "table" then value else fallback
end

function Panels.showDecor(startTab: string?)
	local frame = sheet(640, 600)
	line(frame, 0, 32, "🪑 내 자리 꾸미기", { Font = Enum.Font.GothamBlack, TextSize = 26 })
	local balance = line(frame, 0, 32, "", { TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBold, Size = UDim2.new(1, -44, 0, 32) })
	local scoreText = line(frame, 34, 22, "", { TextSize = 15, TextColor3 = MUTED })
	local message = line(frame, 0, 22, "온라인 주문하면 택배로 바로 와요 📦 꾸민 자리는 다른 사람도 볼 수 있어요!", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -56),
		TextSize = 14,
		TextColor3 = MUTED,
	})

	-- 탭: 칸 5개 + 칭호
	local tabs = {}
	for _, slot in SalaryConfig.DecorSlots do
		table.insert(tabs, { id = slot.id, text = `{slot.emoji} {slot.name}` })
	end
	table.insert(tabs, { id = "title", text = "🏆 칭호" })
	local tabButtons: { [string]: TextButton } = {}
	local list = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 104),
		Size = UDim2.new(1, 0, 1, -170),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 31,
		Parent = frame,
	}, { Ui.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local selected = startTab or "chair"
	local rowButtons: { [string]: TextButton } = {}

	local function row(order: number, title: string, description: string, onClick: () -> ()): TextButton
		local r = Ui.make("Frame", {
			Size = UDim2.new(1, -10, 0, 56),
			BackgroundColor3 = Color3.fromRGB(240, 240, 236),
			LayoutOrder = order,
			ZIndex = 32,
			Parent = list,
		}, { Ui.corner(8), Ui.padding(6) })
		line(r, 0, 22, title, { Font = Enum.Font.GothamBold, TextSize = 16, ZIndex = 33, Size = UDim2.new(1, -130, 0, 22) })
		line(r, 22, 22, description, { TextSize = 13, ZIndex = 33, TextColor3 = MUTED, Size = UDim2.new(1, -130, 0, 22) })
		local b = Ui.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(120, 36),
			TextSize = 14,
			ZIndex = 34,
			Parent = r,
		})
		b.Activated:Connect(onClick)
		return b
	end

	local function request(action: string, id: string)
		local result = Remotes.Decor:InvokeServer(action, id)
		message.Text = result.message
		message.TextColor3 = if result.ok then Color3.fromRGB(40, 140, 70) else RED
		if result.ok then
			Sounds.play("ping", 0.6, 1.2)
		end
	end

	local function render()
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		table.clear(rowButtons)
		for id, b in tabButtons do
			b.BackgroundColor3 = if id == selected then Color3.fromRGB(255, 200, 80) else Color3.fromRGB(205, 205, 210)
		end
		if selected == "title" then
			for i, title in SalaryConfig.Titles do
				local requirement = ""
				if title.achievement then
					for _, achievement in SalaryConfig.Achievements do
						if achievement.id == title.achievement then
							requirement = `업적 "{achievement.emoji} {achievement.name}": {achievement.description}`
						end
					end
				else
					requirement = "기본 칭호"
				end
				rowButtons[title.id] = row(i, title.text, requirement, function()
					request("title", title.id)
				end)
			end
		else
			for _, slot in SalaryConfig.DecorSlots do
				if slot.id == selected then
					for i, option in slot.options do
						rowButtons[option.id] = row(i, `{option.emoji} {option.name}` .. (if option.price > 0 then ` · {comma(option.price)}원` else " · 기본"), option.description, function()
							local owned = decodeAttr("DecorOwned", {})
							request(if option.price == 0 or owned[option.id] then "equip" else "buy", option.id)
						end)
					end
				end
			end
		end
	end

	for i, tab in tabs do
		local b = Ui.button({
			Position = UDim2.fromOffset((i - 1) * 99, 62),
			Size = UDim2.fromOffset(94, 34),
			Text = tab.text,
			TextSize = 14,
			ZIndex = 31,
			Parent = frame,
		})
		b.Activated:Connect(function()
			selected = tab.id
			Sounds.play("click", 0.4)
			render()
		end)
		tabButtons[tab.id] = b
	end
	render()

	-- 버튼 글씨 갱신 (구매 / 장착 / 장착 중 / 잠김)
	task.spawn(function()
		while current == frame do
			balance.Text = `🏦 {comma(player:GetAttribute("TotalMoney") or 0)}원`
			scoreText.Text = `🪑 인테리어 점수 {player:GetAttribute("DecorScore") or 0}점 · 칭호 {player:GetAttribute("TitleText") or ""}`
			local owned = decodeAttr("DecorOwned", {})
			local equipped = decodeAttr("DecorEquipped", {})
			local collection = decodeAttr("Collection", {})
			if selected == "title" then
				local myTitle = player:GetAttribute("Title") or "newbie"
				for _, title in SalaryConfig.Titles do
					local b = rowButtons[title.id]
					if b then
						local unlocked = title.achievement == nil or collection[title.achievement] == true
						b.Text = if title.id == myTitle then "장착 중 ✅" elseif unlocked then "장착" else "🔒 잠김"
						b.BackgroundColor3 = if title.id == myTitle then Color3.fromRGB(150, 220, 150) elseif unlocked then Ui.COLORS.brass else Color3.fromRGB(200, 200, 200)
					end
				end
			else
				for _, slot in SalaryConfig.DecorSlots do
					if slot.id ~= selected then
						continue
					end
					local wearing = equipped[slot.id] or slot.options[1].id
					for _, option in slot.options do
						local b = rowButtons[option.id]
						if b then
							local has = option.price == 0 or owned[option.id] == true
							b.Text = if option.id == wearing then "장착 중 ✅" elseif has then "장착" else `주문 {comma(option.price)}원`
							b.BackgroundColor3 = if option.id == wearing then Color3.fromRGB(150, 220, 150) else Ui.COLORS.brass
						end
					end
				end
			end
			task.wait(0.3)
		end
	end)

	button(frame, 0, "닫기", close)
	Sounds.play("swoosh", 0.4)
end

-- 👀 남의 자리 구경 (책상 명패 [E])
local function showDeskVisit(owner: Player)
	local frame = sheet(480, 420)
	line(frame, 0, 32, `👀 {owner.DisplayName} 님 자리`, { Font = Enum.Font.GothamBlack, TextSize = 24 })
	line(frame, 38, 26, `{owner:GetAttribute("TitleText") or "🌱 신입 루팡"}`, { Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = Color3.fromRGB(200, 140, 0) })
	line(frame, 66, 24, `🪑 인테리어 점수 {owner:GetAttribute("DecorScore") or 0}점 · 직급 {(SalaryConfig.Ranks[owner:GetAttribute("Rank") or 1] or SalaryConfig.Ranks[1]).name}`, { TextSize = 16 })
	local ok, equipped = pcall(function()
		return HttpService:JSONDecode(owner:GetAttribute("DecorEquipped") or "{}")
	end)
	local lines = {}
	for _, slot in SalaryConfig.DecorSlots do
		local id = (ok and equipped[slot.id]) or slot.options[1].id
		local option = SalaryConfig.getDecor(id)
		if option then
			table.insert(lines, `{slot.emoji} {slot.name}: {option.emoji} {option.name}`)
		end
	end
	line(frame, 104, 200, table.concat(lines, "\n"), { TextSize = 17 })
	button(frame, 0, "닫기", close)
	Sounds.play("swoosh", 0.4)
end

-- 👀 "자리 구경" 안내는 내 자리 명패엔 안 뜨고, 내가 자리에 앉아 있을 땐 옆자리 것도 숨겨요 (화면이 거슬리지 않게)
local deskPrompts: { [ProximityPrompt]: boolean } = {}
local function watchPrompt(instance: Instance)
	if instance:IsA("ProximityPrompt") and instance:GetAttribute("OwnerId") then
		deskPrompts[instance] = true
	end
end
task.spawn(function()
	local office = workspace:WaitForChild("Office", 60)
	if not office then
		return
	end
	for _, instance in office:GetDescendants() do
		watchPrompt(instance)
	end
	office.DescendantAdded:Connect(watchPrompt)
	while true do
		local seated = player:GetAttribute("Seated") == true
		for prompt in deskPrompts do
			if prompt.Parent then
				prompt.Enabled = prompt:GetAttribute("OwnerId") ~= player.UserId and not seated
			else
				deskPrompts[prompt] = nil
			end
		end
		task.wait(0.3)
	end
end)

-- 🪑 [E] 앉기: 이미 앉아 있으면 숨기고, 책상 의자는 내 자리에만 떠요
task.spawn(function()
	local sitPrompts: { [ProximityPrompt]: boolean } = {}
	local function watchSit(instance: Instance)
		if instance:IsA("ProximityPrompt") and instance.Name == "SitPrompt" then
			sitPrompts[instance] = true
		end
	end
	for _, instance in workspace:GetDescendants() do
		watchSit(instance)
	end
	workspace.DescendantAdded:Connect(watchSit)
	while true do
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local sitting = humanoid ~= nil and humanoid.SeatPart ~= nil
		for prompt in sitPrompts do
			local seat = prompt.Parent
			if seat and seat:IsA("Seat") then
				local mine = seat.Name ~= "Seat" or seat:GetAttribute("OwnerId") == player.UserId
				prompt.Enabled = mine and not sitting and seat.Occupant == nil
			else
				sitPrompts[prompt] = nil
			end
		end
		task.wait(0.2)
	end
end)

game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
	local ownerId = prompt:GetAttribute("OwnerId")
	if ownerId then
		local owner = Players:GetPlayerByUserId(ownerId)
		if owner then
			showDeskVisit(owner)
		end
	end
end)

---------------------------------------------------------------------------
-- 📖 도감
---------------------------------------------------------------------------
function Panels.showCollection()
	local ok, collection = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Collection") or "{}")
	end)
	if not ok or typeof(collection) ~= "table" then
		collection = {}
	end

	-- 농땡이 행동 목록 (일하기 제외)
	local actions = {}
	for _, actionId in SalaryConfig.DeskActions do
		if actionId ~= "work" then
			table.insert(actions, actionId)
		end
	end
	for _, stateId in { "toilet", "candy", "coffee", "meeting", "rooftop", "lounger", "hiding", "docs", "chat", "ramen" } do
		table.insert(actions, stateId)
	end

	local total = #actions + #SalaryConfig.Achievements
	local found = 0
	-- 가로로 넓게: 왼쪽 = 농땡이 칸, 오른쪽 = 업적 목록
	local frame = sheet(900, 430)
	local title = line(frame, 0, 30, "📖 농땡이 도감", { Font = Enum.Font.GothamBlack, TextSize = 24 })

	local left = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(0.5, -10, 0, 300),
		BackgroundTransparency = 1,
		ZIndex = 31,
		Parent = frame,
	})
	line(left, 0, 20, "😴 농땡이 행동", { Font = Enum.Font.GothamBold, TextSize = 16 })
	local grid = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 1, -26),
		BackgroundTransparency = 1,
		ZIndex = 31,
		Parent = left,
	}, {
		Ui.make("UIGridLayout", { CellSize = UDim2.fromOffset(98, 60), CellPadding = UDim2.fromOffset(6, 6) }),
	})
	for _, stateId in actions do
		local info = States[stateId]
		local has = collection[`action_{stateId}`] == true
		if has then
			found += 1
		end
		Ui.make("TextLabel", {
			BackgroundColor3 = if has then Color3.fromRGB(255, 240, 200) else Color3.fromRGB(225, 225, 228),
			Text = if has then `{info.emoji}\n{info.name}` else "❓\n???",
			TextColor3 = if has then INK else MUTED,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextWrapped = true,
			ZIndex = 32,
			Parent = grid,
		}, { Ui.corner(8) })
	end

	local right = Ui.make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 40),
		Size = UDim2.new(0.5, -10, 0, 300),
		BackgroundTransparency = 1,
		ZIndex = 31,
		Parent = frame,
	})
	line(right, 0, 20, "🏆 업적", { Font = Enum.Font.GothamBold, TextSize = 16 })
	local list = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 1, -26),
		CanvasSize = UDim2.fromOffset(0, #SalaryConfig.Achievements * 30),
		ScrollBarThickness = 6,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 31,
		Parent = right,
	})
	for i, achievement in SalaryConfig.Achievements do
		local has = collection[achievement.id] == true
		if has then
			found += 1
		end
		line(list, (i - 1) * 30, 28, if has
			then `✅ {achievement.emoji} {achievement.name} — {achievement.description}`
			else `🔒 ??? — {achievement.description}`, {
			Size = UDim2.new(1, -10, 0, 28),
			TextSize = 14,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = if has then INK else MUTED,
			ZIndex = 32,
		})
	end

	-- 수다 주제 수집 현황 (왼쪽 아래)
	local heardTopics = 0
	for _, topic in ChatTopics.Topics do
		if collection[`chat_{topic.id}`] == true then
			heardTopics += 1
		end
	end
	found += heardTopics
	total += #ChatTopics.Topics
	line(left, 226, 22, `💬 수다 주제 {heardTopics}/{#ChatTopics.Topics}`, { Font = Enum.Font.GothamBold, TextSize = 16 })
	line(left, 250, 40, "동료마다 전용 주제가 있어요. 수다를 끝까지 들으면 기록돼요!", { TextSize = 13, TextColor3 = MUTED })

	title.Text = `📖 농땡이 도감 ({found}/{total})`
	button(frame, 0, "닫기", close)
end

---------------------------------------------------------------------------
-- 도구 버튼 (왼쪽 상태창 아래)
---------------------------------------------------------------------------
local function toolButton(label: string, width: number, onClick: () -> ()): TextButton
	local b = Ui.button({
		Size = UDim2.fromOffset(width, 36),
		Text = label,
		TextSize = 15,
		Parent = Hud.toolbar,
	})
	b.Activated:Connect(onClick)
	return b
end

-- (🛒 매점 버튼은 없앴어요: 사무실의 🏪 사내 매점 계산대에서 [E]로 사요)
toolButton("📖 도감", 76, function()
	if current then
		close()
	else
		Panels.showCollection()
	end
end)
toolButton("🪑", 46, function()
	if current then
		close()
	else
		Panels.showDecor()
	end
end)
toolButton("🎒", 46, function()
	if current then
		close()
	else
		Panels.showBag()
	end
end)
toolButton("🧸", 46, function()
	if current then
		close()
	else
		Panels.showPlushies()
	end
end)
local energyButton = toolButton("⚡ 0", 86, function()
	Remotes.UseEnergy:FireServer()
end)
task.spawn(function()
	while true do
		local count = player:GetAttribute("Energy") or 0
		local active = player:GetAttribute("EnergyActive") == true
		energyButton.Text = if active then "⚡ 효과 중" else `⚡ 마시기 {count}`
		energyButton.Visible = count > 0 or active
		task.wait(0.5)
	end
end)

---------------------------------------------------------------------------
-- 👤 인물 소개 카드 (지금은 이과장. 나중에 사장님 같은 새 인물도 같은 틀로)
---------------------------------------------------------------------------
type Person = { title: string, subtitle: string, lines: { string } }

local PEOPLE: { [string]: Person } = {
	nunchi = {
		title = "🏢 (주)눈치물산 첫 출근!",
		subtitle = "대리님, 스카우트를 환영합니다",
		lines = {
			"🪑 칸막이가 낮아요. 부장님 눈에 더 잘 띄어요!",
			"📊 유리 회의실 의자에 앉으면 '회의하는 척 졸기' (안전한 편)",
			"🌳 출입문 밖 공원 · 🍭 흡연구역(금연! 사탕만!)에서 농땡이",
			"🏙️ 공원 정문 밖 눈치 스트리트: ☕ 카페 · 🍰 디저트 · 🧸 인형뽑기 · 🕹️ 오락실 (근무 중 외출 OK, 자리 부재 주의!)",
			"😎 이과장은 대충상사에 남았어요! 감시에서 해방",
			"💰 직급이 높아서 농땡이 수입도 커요",
		},
	},
	lee = {
		title = "👀 눈치 빠른 이과장",
		subtitle = "(주)대충상사 수요일·목요일 출근 · 보라색 조끼 · 과장부터는 고자질 안 해요",
		lines = {
			"📱 휴대폰 볼 때는 아무것도 안 봐요",
			"❗ 머리 위에 뜨면 곧 휙 뒤돌아봐요!",
			"🗣️ 농땡이를 들키면 부장님께 고자질 (의심도 +35, 부장님 출동)",
			`☕ [E] 커피 상납({comma(SalaryConfig.LEE_BRIBE_COST)}원)하면 그날 한 번 눈감아 줘요`,
		},
	},
}

local function showCard(person: Person)
	local frame = sheet(620, 110 + #person.lines * 40 + 60)
	line(frame, 0, 34, person.title, { Font = Enum.Font.GothamBlack, TextSize = 26 })
	line(frame, 36, 22, person.subtitle, { TextSize = 15, TextColor3 = MUTED, TextWrapped = true })
	for i, text in person.lines do
		line(frame, 70 + (i - 1) * 40, 36, text, { TextSize = 17, TextWrapped = true })
	end
	button(frame, 0, "알겠어요", close)
	Sounds.play("swoosh", 0.4)
end

function Panels.showPerson(personId: string)
	local person = PEOPLE[personId]
	if person then
		showCard(person)
	end
end

-- 📦 이직 / 좌천 안내 (회사 사무실이 바뀐 이유)
Remotes:WaitForChild("CompanyNotice").OnClientEvent:Connect(function(kind: string, rankName: string)
	if kind == "promoted" then
		Sounds.play("ping", 0.7, 1.3)
		showCard({
			title = "📦 이직 안내: (주)눈치물산",
			subtitle = `{rankName}(으)로 승진해서 더 큰 회사에 스카우트됐어요! 🎉`,
			lines = {
				"🏢 (주)대충상사 → (주)눈치물산 (대리부터 출근하는 회사)",
				"💰 직급·통장·아이템·도감·인형은 그대로 이어져요",
				"🌳 넓은 사무실 + 공원 + 🏙️ 눈치 스트리트가 열렸어요",
				"📉 해고돼서 주임 이하가 되면 대충상사로 돌아가요",
			},
		})
	elseif kind == "demoted" then
		Sounds.play("bass", 0.6, 0.8)
		showCard({
			title = "📉 좌천 안내: (주)대충상사",
			subtitle = `{rankName}(으)로 강등돼서 예전 회사로 돌아왔어요…`,
			lines = {
				"🏢 (주)눈치물산 → (주)대충상사",
				"📈 다시 대리로 승진하면 눈치물산으로 돌아갈 수 있어요",
				"👀 여기는 이과장이 수·목에 출근해요. 조심!",
			},
		})
	end
end)

-- 시계 옆 "👀 이과장" 버튼: 출근한 날에만 보이고, 누르면 소개 카드
local leeChip = Ui.button({
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(1, 18, 0, -10), -- 시계 창 오른쪽 바깥 (창 안쪽 여백 10 고려)
	Size = UDim2.fromOffset(104, 34),
	Text = "👀 이과장",
	TextSize = 15,
	Visible = false,
	Parent = Hud.clockPanel,
})
leeChip.Activated:Connect(function()
	if current then
		close()
	else
		Panels.showPerson("lee")
	end
end)

-- 🕶️ 감사 기간 소개 카드 (지금 내 사진 수·남은 지목 기회까지 보여 줘요)
local function auditPerson(): Person
	local revealed = ReplicatedStorage:GetAttribute("SalaryEventStage") == "revealed"
	local photos = math.max(0, player:GetAttribute("AuditPhotos") or 0)
	local emptyPhotos = player:GetAttribute("AuditEmptyPhotos") or 0
	local accuseLeft = player:GetAttribute("AccuseLeft") or SalaryConfig.AUDIT_WRONG_MAX
	return {
		title = "🕶️ 위장 감사관",
		subtitle = if revealed
			then "✅ 정체가 밝혀졌어요! 오늘 감사는 끝 · 농땡이 수입 ×2는 계속"
			else `동료 중 한 명이 몰래 감사관 · 📸 {photos}/{SalaryConfig.AUDIT_REPORT_AT} · 🪑 {emptyPhotos}/{SalaryConfig.AUDIT_EMPTY_REPORT_AT} · 지목 기회 {accuseLeft}번`,
		lines = {
			"🔎 단서: 농땡이 절대 안 함 · 자주 돌아다님 · 📝 메모",
			`📷 농땡이를 보면 카메라를 들어요 → {SalaryConfig.AUDIT_PHOTO_WINDUP}초 안에 일하기! (도망가면 🪑 빈자리가 찍혀요)`,
			"📸 찍히는 곳: 내 자리 · 🚽 화장실 · 📊 회의실 · 💬 수다 (어슬렁·탕비실은 OK)",
			`⚖️ 농땡이 사진 {SalaryConfig.AUDIT_REPORT_AT}장 또는 🪑 빈자리 {SalaryConfig.AUDIT_EMPTY_REPORT_AT}장 → 퇴근 때 감봉 + 경고 1개 (한 번만)`,
			`[R] "감사팀이죠?" 맞히면 감사 끝 · 모두의 사진 폐기 · +{comma(SalaryConfig.AUDIT_REVEAL_BONUS)}원`,
			`😠 틀리면 의심도 +{SalaryConfig.AUDIT_WRONG_SUSPICION} · 의심도 속도 +{string.format("%.2f", SalaryConfig.SpeedFactors.accuseWrong.delta)}`,
			`💰 대신 오늘 농땡이 수입 ×{SalaryConfig.AUDIT_INCOME}!`,
		},
	}
end

---------------------------------------------------------------------------
-- ✈️ 옥상 종이비행기
--   [준비] → 🌬️ 바람 보고 → ① 각도 멈추기 → ② 힘 멈추기 (클릭 또는 Enter)
---------------------------------------------------------------------------
-- 종이비행기 비행 (모든 사람 화면에 똑같이 날아가요)
Remotes:WaitForChild("PlaneFlight").OnClientEvent:Connect(function(info)
	local plane = Instance.new("Model")
	plane.Name = "PaperPlane"
	local function wing(offset: CFrame, size: Vector3): WedgePart
		local w = Instance.new("WedgePart")
		w.Size = size
		w.Color = Color3.fromRGB(252, 252, 250)
		w.Material = Enum.Material.SmoothPlastic
		w.Anchored = true
		w.CanCollide = false
		w.CanQuery = false
		w.CanTouch = false
		w:SetAttribute("Offset", offset)
		w.Parent = plane
		return w
	end
	-- 두 날개 (쐐기 모양을 마주 붙여 화살촉처럼)
	local parts = {
		wing(CFrame.new(-0.35, 0, 0) * CFrame.Angles(0, 0, math.rad(-12)), Vector3.new(0.05, 0.7, 2.2)),
		wing(CFrame.new(0.35, 0, 0) * CFrame.Angles(0, 0, math.rad(12)), Vector3.new(0.05, 0.7, 2.2)),
		wing(CFrame.new(0, -0.2, 0.15), Vector3.new(0.05, 0.4, 1.8)),
	}
	plane.Parent = workspace
	local trail = Instance.new("Attachment")
	trail.Parent = parts[3]
	local function bezier(t: number): Vector3
		local a = info.start:Lerp(info.control, t)
		local b = info.control:Lerp(info.finish, t)
		return a:Lerp(b, t)
	end
	local started = os.clock()
	local connection
	connection = game:GetService("RunService").RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - started) / info.duration, 0, 1)
		local eased = 1 - (1 - t) ^ 1.6 -- 처음엔 빠르게, 나중엔 사뿐히
		local position = bezier(eased)
		local ahead = bezier(math.min(1, eased + 0.02))
		local direction = ahead - position
		local cf = if direction.Magnitude > 0.01 then CFrame.lookAt(position, position + direction) else CFrame.new(position)
		-- 살짝 흔들흔들
		cf *= CFrame.Angles(0, 0, math.sin(os.clock() * 7) * 0.25 * (1 - t))
		for _, part in parts do
			part.CFrame = cf * (part:GetAttribute("Offset") :: CFrame) * CFrame.Angles(0, math.pi, 0)
		end
		if t >= 1 then
			connection:Disconnect()
			task.delay(8, function()
				plane:Destroy()
			end)
		end
	end)
end)

local function windText(wind): string
	local forward = wind.forward
	local side = wind.side
	local f = if forward > 0.05 then `⬆️ 뒷바람 {string.format("%.1f", forward)}` elseif forward < -0.05 then `⬇️ 맞바람 {string.format("%.1f", -forward)}` else "바람 없음"
	local s = if side > 0.05 then `➡️ 오른쪽 {string.format("%.1f", side)}` elseif side < -0.05 then `⬅️ 왼쪽 {string.format("%.1f", -side)}` else "옆바람 없음"
	return `🌬️ {f} · {s}`
end

function Panels.showPlane()
	local frame = sheet(360, 400)
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.Position = UDim2.new(1, -20, 0.5, 0)
	line(frame, 0, 30, "✈️ 종이비행기", { Font = Enum.Font.GothamBlack, TextSize = 24 })
	line(frame, 32, 20, `🎯 {SalaryConfig.PLANE_TARGET_DISTANCE}m 과녁 명중 +{comma(SalaryConfig.PLANE_TARGET_PRIZE)}원 · 25° 근처가 가장 멀리 가요`, { TextSize = 12, TextColor3 = MUTED })
	local windLabel = line(frame, 56, 24, "🌬️ 바람: [준비]를 누르면 알 수 있어요", { TextSize = 15, Font = Enum.Font.GothamBold })

	-- 게이지 두 개
	local function gauge(y: number, title: string): (TextLabel, Frame, Frame)
		local label = line(frame, y, 20, title, { TextSize = 14, Font = Enum.Font.GothamBold })
		local back = Ui.make("Frame", {
			Position = UDim2.fromOffset(0, y + 22),
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundColor3 = Color3.fromRGB(220, 222, 230),
			ZIndex = 31,
			Parent = frame,
		}, { Ui.corner(6) })
		local marker = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(0, 6, 1, 8),
			BackgroundColor3 = Color3.fromRGB(40, 40, 50),
			ZIndex = 33,
			Parent = back,
		}, { Ui.corner(3) })
		return label, back, marker
	end
	local angleLabel, angleBack, angleMarker = gauge(90, "① 각도")
	-- 25° 근처 (가장 멀리 가는 곳) 표시
	Ui.make("Frame", {
		Position = UDim2.fromScale((20 - 5) / 55, 0),
		Size = UDim2.fromScale(10 / 55, 1),
		BackgroundColor3 = Color3.fromRGB(150, 220, 150),
		ZIndex = 32,
		Parent = angleBack,
	}, { Ui.corner(6) })
	local powerLabel, powerBack, powerMarker = gauge(150, "② 힘")
	Ui.make("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(150, 200, 255), Color3.fromRGB(255, 120, 100)),
		Parent = powerBack,
	})
	local result = line(frame, 210, 60, "", { TextSize = 15, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center })

	local stage = "idle" -- idle → angle → power → flying
	local angleStart, powerStart = 0, 0
	local lockedAngle: number? = nil
	local busy = false

	local mainButton = Ui.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 50),
		Text = "✈️ 준비 (Enter)",
		TextSize = 18,
		ZIndex = 31,
		Parent = frame,
	})

	local function act()
		if busy then
			return
		end
		if stage == "idle" then
			busy = true
			local r = Remotes.PlaneThrow:InvokeServer("begin")
			busy = false
			if current ~= frame then
				return
			end
			if not r.ok then
				result.Text = r.message
				result.TextColor3 = RED
				return
			end
			windLabel.Text = windText(r.wind)
			windLabel.TextColor3 = INK
			angleStart = r.angleStart
			lockedAngle = nil
			angleLabel.Text = "① 각도"
			powerLabel.Text = "② 힘"
			powerMarker.Position = UDim2.fromScale(0, 0.5)
			result.Text = "바람을 보고 각도를 멈춰요!"
			result.TextColor3 = MUTED
			stage = "angle"
			mainButton.Text = "① 각도 멈추기 (Enter)"
			Sounds.play("swoosh", 0.3)
		elseif stage == "angle" then
			local press = workspace:GetServerTimeNow()
			stage = "wait"
			busy = true
			local r = Remotes.PlaneThrow:InvokeServer("angle", press)
			busy = false
			if current ~= frame then
				return
			end
			if not r.ok then
				result.Text = r.message
				result.TextColor3 = RED
				stage = "idle"
				mainButton.Text = "✈️ 준비 (Enter)"
				return
			end
			lockedAngle = r.angle
			angleMarker.Position = UDim2.fromScale((r.angle - 5) / 55, 0.5)
			angleLabel.Text = `① 각도 {math.floor(r.angle + 0.5)}°`
			powerStart = r.powerStart
			stage = "power"
			mainButton.Text = "② 힘 멈추기 (Enter)"
			Sounds.play("click", 0.4, 1.1)
		elseif stage == "power" then
			local press = workspace:GetServerTimeNow()
			stage = "flying"
			busy = true
			local r = Remotes.PlaneThrow:InvokeServer("power", press)
			busy = false
			if current ~= frame then
				return
			end
			if not r.ok then
				result.Text = r.message
				result.TextColor3 = RED
				stage = "idle"
				mainButton.Text = "✈️ 준비 (Enter)"
				return
			end
			powerMarker.Position = UDim2.fromScale((r.power - 0.2) / 0.8, 0.5)
			powerLabel.Text = `② 힘 {math.floor(r.power * 100 + 0.5)}%`
			mainButton.Text = "✈️ 슈웅~"
			Sounds.play("swoosh", 0.7, 1.2)
			result.Text = "✈️ 날아가는 중…"
			result.TextColor3 = MUTED
			task.delay(r.duration, function()
				if current ~= frame then
					return
				end
				local lines = { r.label }
				if r.distance > 0 then
					table.insert(lines, `{math.floor(r.distance)}m` .. (if r.record then " · 🏆 내 최고 기록!" else ` · 내 최고 {r.best or 0}m`))
				end
				if r.prize > 0 then
					table.insert(lines, `+{comma(r.prize)}원 (오늘 상금 {r.prizesLeft}번 더)`)
				elseif r.hitTarget or (r.distance >= SalaryConfig.PlanePrizes[#SalaryConfig.PlanePrizes].distance) then
					table.insert(lines, "(오늘 상금은 다 받았어요)")
				end
				result.Text = table.concat(lines, "\n")
				result.TextColor3 = if r.hitTarget then Color3.fromRGB(40, 140, 70) elseif r.boomerang then RED else INK
				if r.hitTarget then
					Sounds.play("ping", 0.9, 1.5)
				elseif r.hitBoss then
					Sounds.play("caught", 0.6, 1.2)
				else
					Sounds.play("ping", 0.4, 1.1)
				end
				stage = "idle"
				mainButton.Text = "✈️ 한 번 더 (Enter)"
			end)
		end
	end
	mainButton.Activated:Connect(act)
	local keyConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and current == frame and (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter) then
			act()
		end
	end)

	-- 게이지 움직이기 (서버와 같은 식)
	task.spawn(function()
		while current == frame do
			local now = workspace:GetServerTimeNow()
			if stage == "angle" then
				local angle = SalaryConfig.planeAngle(math.max(0, now - angleStart))
				angleMarker.Position = UDim2.fromScale((angle - 5) / 55, 0.5)
				angleLabel.Text = `① 각도 {math.floor(angle + 0.5)}°`
			elseif stage == "power" then
				local power = SalaryConfig.planePower(math.max(0, now - powerStart))
				powerMarker.Position = UDim2.fromScale((power - 0.2) / 0.8, 0.5)
				powerLabel.Text = `② 힘 {math.floor(power * 100 + 0.5)}%`
			end
			task.wait()
		end
		keyConnection:Disconnect()
	end)
	local _ = lockedAngle
	Sounds.play("swoosh", 0.4)
end
Remotes:WaitForChild("PlaneOpen").OnClientEvent:Connect(function()
	Panels.showPlane()
end)

---------------------------------------------------------------------------
-- 🌱 옥상 텃밭: 내 화분 창 + 화분 위에 내 식물 그리기 (내 화면에만 보여요)
---------------------------------------------------------------------------
local function readGarden(): ({ any }, number)
	local ok, garden = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Garden") or "[]")
	end)
	garden = if ok and typeof(garden) == "table" then garden else {}
	for i = 1, SalaryConfig.GARDEN_SLOTS do
		if typeof(garden[i]) ~= "table" then
			garden[i] = { seed = "", growth = 0, watered = -1, missed = 0 }
		end
	end
	return garden, player:GetAttribute("GardenToday") or 0
end

-- 화분 상태: "empty" / "dead" / "ripe" / "wilted" / "growing"
local function slotState(slot): string
	local seed = SalaryConfig.getSeed(slot.seed)
	if not seed then
		return "empty"
	elseif slot.missed >= 2 then
		return "dead"
	elseif slot.growth >= seed.days then
		return "ripe"
	elseif slot.missed == 1 then
		return "wilted"
	end
	return "growing"
end

-- 🪴 화분 위 식물 그리기
local gardenFolder = Instance.new("Folder")
gardenFolder.Name = "MyGarden"
gardenFolder.Parent = workspace
local function renderGarden()
	gardenFolder:ClearAllChildren()
	local ok, slots = pcall(function()
		return HttpService:JSONDecode(ReplicatedStorage:GetAttribute("GardenSlots") or "[]")
	end)
	if not ok or typeof(slots) ~= "table" then
		return
	end
	local garden, today = readGarden()
	for i, pos in slots do
		local slot = garden[i]
		local seed = slot and SalaryConfig.getSeed(slot.seed)
		if not seed then
			continue
		end
		local base = Vector3.new(pos[1], pos[2], pos[3])
		local state = slotState(slot)
		local function piece(size: Vector3, offset: Vector3, color: Color3, shape: Enum.PartType?)
			local p = Instance.new("Part")
			p.Size = size
			p.Shape = shape or Enum.PartType.Block
			p.Color = color
			p.Material = Enum.Material.SmoothPlastic
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Position = base + offset
			p.Parent = gardenFolder
			return p
		end
		local leaf = if state == "wilted" then Color3.fromRGB(150, 140, 70) else Color3.fromRGB(80, 170, 70)
		local ratio = math.clamp(slot.growth / seed.days, 0, 1)
		if state == "dead" then
			piece(Vector3.new(0.12, 0.9, 0.12), Vector3.new(0, 0.45, 0), Color3.fromRGB(110, 80, 50))
			piece(Vector3.new(0.5, 0.08, 0.3), Vector3.new(0.15, 0.85, 0), Color3.fromRGB(130, 100, 60))
		elseif slot.growth == 0 then
			-- 🌱 새싹
			piece(Vector3.new(0.08, 0.35, 0.08), Vector3.new(0, 0.18, 0), leaf)
			piece(Vector3.new(0.35, 0.06, 0.18), Vector3.new(-0.15, 0.36, 0), leaf)
			piece(Vector3.new(0.35, 0.06, 0.18), Vector3.new(0.15, 0.38, 0), leaf)
		else
			local height = 0.6 + ratio * 1.1
			piece(Vector3.new(0.12, height, 0.12), Vector3.new(0, height / 2, 0), Color3.fromRGB(90, 140, 60))
			local bush = 0.7 + ratio * 0.9
			piece(Vector3.new(bush, bush * 0.8, bush), Vector3.new(0, height, 0), leaf, Enum.PartType.Ball)
			if state == "ripe" then
				-- 🍅 열매 주렁주렁 (상추는 큼직한 잎)
				if seed.id == "lettuce" then
					piece(Vector3.new(1.6, 1, 1.6), Vector3.new(0, height, 0), seed.color, Enum.PartType.Ball)
				else
					for k = 1, 5 do
						local angle = k / 5 * math.pi * 2
						local fruit = piece(Vector3.new(0.32, 0.32, 0.32), Vector3.new(math.cos(angle) * bush * 0.45, height - 0.1 + (k % 2) * 0.25, math.sin(angle) * bush * 0.45), seed.color, Enum.PartType.Ball)
						fruit.Material = Enum.Material.Glass
					end
				end
			end
		end
		-- 머리 위 표시: 다 자랐어요 / 목말라요
		local mark = if state == "ripe" then `✨{seed.emoji}` elseif state == "dead" then "💀" elseif slot.watered ~= today then "💧?" else nil
		if mark then
			local holder = piece(Vector3.new(0.2, 0.2, 0.2), Vector3.new(0, 2.6, 0), Color3.new(1, 1, 1))
			holder.Transparency = 1
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromOffset(46, 24)
			gui.MaxDistance = 40
			gui.Parent = holder
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.Text = mark
			text.TextScaled = true
			text.Font = Enum.Font.GothamBold
			text.TextColor3 = Color3.new(1, 1, 1)
			text.TextStrokeTransparency = 0.3
			text.Parent = gui
		end
	end
end
player:GetAttributeChangedSignal("Garden"):Connect(renderGarden)
player:GetAttributeChangedSignal("GardenToday"):Connect(renderGarden)
ReplicatedStorage:GetAttributeChangedSignal("GardenSlots"):Connect(renderGarden)
task.defer(renderGarden)

function Panels.showGarden()
	local frame = sheet(380, 560)
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.Position = UDim2.new(1, -20, 0.5, 0)
	line(frame, 0, 30, "🌱 직장인 텃밭", { Font = Enum.Font.GothamBlack, TextSize = 24 })
	line(frame, 32, 20, "심고 → 매일 💧 물 주기 → 퇴근하면 자라요 → 🧺 수확 (이틀 안 주면 💀)", { TextSize = 12, TextColor3 = MUTED })
	local message = line(frame, 0, 24, "", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local busy = false
	local cards = {}
	local CARD_W, CARD_H = 165, 210

	local function act(action: string, index: number, seedId: string?)
		if busy then
			return
		end
		busy = true
		local result = Remotes.GardenAction:InvokeServer(action, index, seedId)
		busy = false
		if current ~= frame then
			return
		end
		message.Text = result.message
		message.TextColor3 = if result.ok then Color3.fromRGB(40, 140, 70) else RED
		Sounds.play(if result.ok then "ping" else "bass", 0.4, if action == "water" then 1.4 else 1.1)
	end

	local function rebuild()
		for _, card in cards do
			card:Destroy()
		end
		table.clear(cards)
		local garden, today = readGarden()
		for i = 1, SalaryConfig.GARDEN_SLOTS do
			local slot = garden[i]
			local seed = SalaryConfig.getSeed(slot.seed)
			local state = slotState(slot)
			local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
			local card = Ui.make("Frame", {
				Position = UDim2.fromOffset(col * (CARD_W + 10), 58 + row * (CARD_H + 10)),
				Size = UDim2.fromOffset(CARD_W, CARD_H),
				BackgroundColor3 = if state == "ripe" then Color3.fromRGB(235, 250, 225) elseif state == "dead" then Color3.fromRGB(235, 225, 215) else Color3.fromRGB(240, 238, 232),
				ZIndex = 31,
				Parent = frame,
			}, { Ui.corner(10), Ui.padding(8) })
			table.insert(cards, card)
			local function label(y: number, h: number, text: string, size: number, color: Color3?)
				return Ui.make("TextLabel", {
					Position = UDim2.fromOffset(0, y),
					Size = UDim2.new(1, 0, 0, h),
					BackgroundTransparency = 1,
					Text = text,
					TextSize = size,
					TextWrapped = true,
					Font = Enum.Font.GothamBold,
					TextColor3 = color or INK,
					ZIndex = 32,
					Parent = card,
				})
			end
			local function smallButton(x: number, y: number, w: number, text: string, color: Color3, onClick: () -> ())
				local b = Ui.button({
					Position = UDim2.fromOffset(x, y),
					Size = UDim2.fromOffset(w, 32),
					Text = text,
					TextSize = 12,
					TextWrapped = true,
					BackgroundColor3 = color,
					ZIndex = 33,
					Parent = card,
				})
				b.Activated:Connect(onClick)
				return b
			end
			if not seed then
				label(0, 34, "🪴", 28)
				label(36, 20, `{i}번 화분 · 비었어요`, 13, MUTED)
				for k, option in SalaryConfig.GardenSeeds do
					local cx, cy = ((k - 1) % 2) * 76, 62 + math.floor((k - 1) / 2) * 38
					smallButton(cx, cy, 72, `{option.emoji} {option.price}원\n{option.days}일`, Color3.fromRGB(210, 235, 200), function()
						act("plant", i, option.id)
					end)
				end
				label(140, 50, "씨앗을 골라 심어요", 11, MUTED)
			else
				local stageEmoji = if state == "dead" then "💀" elseif state == "ripe" then seed.emoji elseif slot.growth == 0 then "🌱" elseif state == "wilted" then "🥀" else "🌿"
				label(0, 34, stageEmoji, 28)
				label(36, 20, `{seed.emoji} {seed.name}`, 14)
				local statusText = if state == "dead"
					then "말라 죽었어요…"
					elseif state == "ripe" then "🧺 다 자랐어요!"
					elseif state == "wilted" then "🥀 시들었어요! 오늘 꼭 물을"
					elseif slot.watered == today then `✅ 오늘 물 줌 ({slot.growth}/{seed.days}일)`
					else `💧 목말라요 ({slot.growth}/{seed.days}일)`
				label(58, 32, statusText, 12, if state == "wilted" or state == "dead" then RED else MUTED)
				-- 자란 정도 막대
				local back = Ui.make("Frame", { Position = UDim2.fromOffset(0, 94), Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = Color3.fromRGB(215, 215, 210), ZIndex = 32, Parent = card }, { Ui.corner(4) })
				Ui.make("Frame", { Size = UDim2.fromScale(math.clamp(slot.growth / seed.days, 0, 1), 1), BackgroundColor3 = Color3.fromRGB(110, 190, 90), ZIndex = 33, Parent = back }, { Ui.corner(4) })
				if state == "dead" then
					smallButton(0, 112, CARD_W - 16, "🧹 뽑고 비우기", Color3.fromRGB(225, 210, 195), function()
						act("clear", i)
					end)
				elseif state == "ripe" then
					smallButton(0, 112, CARD_W - 16, `💰 팔기 +{comma(seed.sell)}원`, Color3.fromRGB(255, 215, 110), function()
						act("sell", i)
					end)
					smallButton(0, 150, CARD_W - 16, "🎁 부장님 선물로 챙기기", Color3.fromRGB(200, 225, 255), function()
						act("gift", i)
					end)
				else
					local watered = slot.watered == today
					local waterButton = smallButton(0, 112, CARD_W - 16, if watered then "✅ 오늘은 충분해요" else "💧 물 주기", if watered then Color3.fromRGB(215, 215, 215) else Color3.fromRGB(150, 205, 255), function()
						act("water", i)
					end)
					waterButton.AutoButtonColor = not watered
					label(150, 40, `다 자라면 {comma(seed.sell)}원 · {seed.description}`, 11, MUTED)
				end
			end
		end
	end
	rebuild()
	local connections = {
		player:GetAttributeChangedSignal("Garden"):Connect(function()
			if current == frame then
				rebuild()
			end
		end),
		player:GetAttributeChangedSignal("GardenToday"):Connect(function()
			if current == frame then
				rebuild()
			end
		end),
	}
	task.spawn(function()
		while current == frame do
			task.wait(0.5)
		end
		for _, connection in connections do
			connection:Disconnect()
		end
	end)
	Sounds.play("swoosh", 0.4)
end
Remotes:WaitForChild("GardenOpen").OnClientEvent:Connect(function()
	Panels.showGarden()
end)

---------------------------------------------------------------------------
-- 🔭 건너편 빌딩 관찰 일지
--   동그란 렌즈로 (주)야근물산 창문을 둘러봐요: 🖱️ 드래그 / ⌨️ WASD·방향키
--   창문에 장면이 보이면 렌즈 가운데(+)에 맞추고 잠깐 기다리면 📒 기록!
---------------------------------------------------------------------------
local function readScenes(): { [string]: boolean }
	local ok, scenes = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Scenes") or "{}")
	end)
	return if ok and typeof(scenes) == "table" then scenes else {}
end

local RARITY_TEXT = { common = "흔함", rare = "희귀", legend = "전설" }

function Panels.showScopeLog()
	local frame = sheet(600, 520)
	local found = readScenes()
	local count = 0
	for _ in found do
		count += 1
	end
	line(frame, 0, 30, `📒 건너편 빌딩 관찰 일지 ({count}/{#SalaryConfig.ScopeScenes})`, { Font = Enum.Font.GothamBlack, TextSize = 22 })
	line(frame, 32, 20, "시간대마다 보이는 장면이 달라요 (오전 · 점심 · 오후)", { TextSize = 13, TextColor3 = MUTED })
	for i, scene in SalaryConfig.ScopeScenes do
		local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
		local text = if found[scene.id]
			then `✅ {scene.emoji} {scene.name}`
			else `❔ ??? ({RARITY_TEXT[scene.rarity]})`
		line(frame, 60 + row * 40, 38, text, {
			Position = UDim2.fromOffset(col * 285, 60 + row * 40),
			Size = UDim2.fromOffset(280, 38),
			TextSize = 14,
			Font = Enum.Font.GothamBold,
			TextColor3 = if found[scene.id] then INK elseif scene.rarity == "legend" then Color3.fromRGB(190, 140, 30) else MUTED,
		})
	end
	Sounds.play("swoosh", 0.4)
end

function Panels.showScope()
	close()
	local overlay = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(5, 5, 10),
		BackgroundTransparency = 0.25,
		ZIndex = 30,
		Parent = gui,
	})
	current = overlay
	local LENS = 440
	local lens = Ui.make("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromOffset(LENS, LENS),
		BackgroundColor3 = Color3.fromRGB(150, 185, 225),
		ZIndex = 31,
		Parent = overlay,
	}, { Ui.corner(LENS), Ui.make("UIScale", { Scale = fitScale(LENS + 60, LENS + 160) }) })
	-- 건너편 빌딩 앞면
	local COLS, ROWS = SalaryConfig.SCOPE_COLUMNS, SalaryConfig.SCOPE_ROWS
	local WIN_W, WIN_H, GAP, TOP = 130, 105, 24, 80
	local FACADE_W = COLS * WIN_W + (COLS + 1) * GAP
	local FACADE_H = TOP + ROWS * WIN_H + (ROWS + 1) * GAP
	local facade = Ui.make("Frame", {
		Size = UDim2.fromOffset(FACADE_W, FACADE_H),
		BackgroundColor3 = Color3.fromRGB(120, 125, 140),
		ZIndex = 32,
		Parent = lens,
	})
	Ui.make("TextLabel", {
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundColor3 = Color3.fromRGB(40, 40, 50),
		Text = "(주)야근물산",
		TextColor3 = Color3.fromRGB(255, 130, 100),
		Font = Enum.Font.GothamBlack,
		TextSize = 34,
		ZIndex = 33,
		Parent = facade,
	})
	local windows = {}
	for w = 1, COLS * ROWS do
		local col, row = (w - 1) % COLS, math.floor((w - 1) / COLS)
		local x, y = GAP + col * (WIN_W + GAP), TOP + GAP + row * (WIN_H + GAP)
		local win = Ui.make("Frame", {
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(WIN_W, WIN_H),
			BackgroundColor3 = if (w % 3 == 0) then Color3.fromRGB(255, 240, 190) else Color3.fromRGB(190, 215, 235),
			ZIndex = 33,
			Parent = facade,
		}, { Ui.stroke(Color3.fromRGB(70, 75, 90), 3) })
		-- 블라인드 줄무늬
		for k = 1, 3 do
			Ui.make("Frame", { Position = UDim2.fromOffset(0, k * 24), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Color3.fromRGB(160, 170, 185), BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 34, Parent = win })
		end
		local emoji = Ui.make("TextLabel", { Size = UDim2.new(1, 0, 0, 72), BackgroundTransparency = 1, Text = "", TextSize = 46, Font = Enum.Font.GothamBold, ZIndex = 35, Parent = win })
		local caption = Ui.make("TextLabel", { Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Text = "", TextSize = 13, TextWrapped = true, Font = Enum.Font.GothamBold, TextColor3 = INK, ZIndex = 35, Parent = win })
		windows[w] = { frame = win, emoji = emoji, caption = caption, x = x, y = y }
	end
	-- 렌즈 가운데 + 표시
	for _, size in { Vector2.new(40, 3), Vector2.new(3, 40) } do
		Ui.make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size.X, size.Y), BackgroundColor3 = Color3.fromRGB(255, 60, 60), BorderSizePixel = 0, ZIndex = 40, Parent = lens })
	end
	Ui.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 41, Parent = lens }, { Ui.corner(LENS), Ui.stroke(Color3.fromRGB(20, 20, 25), 14) })

	-- 아래 안내 + 초점 막대 + 버튼
	local focusBack = Ui.make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.47, LENS / 2 + 12), Size = UDim2.fromOffset(260, 10), BackgroundColor3 = Color3.fromRGB(60, 60, 70), ZIndex = 31, Parent = overlay }, { Ui.corner(5) })
	local focusFill = Ui.make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(255, 210, 80), ZIndex = 32, Parent = focusBack }, { Ui.corner(5) })
	local status = Ui.make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.47, LENS / 2 + 28),
		Size = UDim2.fromOffset(600, 26),
		BackgroundTransparency = 1,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.4,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		Text = "",
		ZIndex = 31,
		Parent = overlay,
	})
	local logButton = Ui.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(0.5, -6, 0.47, LENS / 2 + 60), Size = UDim2.fromOffset(150, 40), Text = "📒 관찰 일지", TextSize = 16, ZIndex = 31, Parent = overlay })
	local quitButton = Ui.button({ AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0.5, 6, 0.47, LENS / 2 + 60), Size = UDim2.fromOffset(150, 40), Text = "🔭 그만 보기", TextSize = 16, ZIndex = 31, Parent = overlay })
	logButton.Activated:Connect(function()
		Panels.showScopeLog()
	end)
	quitButton.Activated:Connect(close)

	-- 보는 동안 캐릭터는 제자리 (WASD는 렌즈를 움직여요)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local oldSpeed = if humanoid then humanoid.WalkSpeed else 16
	if humanoid then
		humanoid.WalkSpeed = 0
	end

	-- 둘러보기: pan = 렌즈 가운데가 보는 빌딩 위 좌표
	local pan = Vector2.new(FACADE_W / 2, FACADE_H / 2)
	local dragging = false
	local held: { [Enum.KeyCode]: boolean } = {}
	local connections = {}
	table.insert(connections, lens.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end))
	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
		held[input.KeyCode] = nil
	end))
	table.insert(connections, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			pan -= Vector2.new(input.Delta.X, input.Delta.Y)
		end
	end))
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed then
			held[input.KeyCode] = true
		end
	end))

	local focusTime = 0
	local focusKey = ""
	local spotted: { [string]: boolean } = {} -- 이번에 이미 확인한 (창문·장면·끝시각)
	local busy = false
	local lastTick = os.clock()
	task.spawn(function()
		while current == overlay do
			local dt = os.clock() - lastTick
			lastTick = os.clock()
			-- 키보드로 둘러보기
			local move = Vector2.zero
			if held[Enum.KeyCode.A] or held[Enum.KeyCode.Left] then move -= Vector2.new(1, 0) end
			if held[Enum.KeyCode.D] or held[Enum.KeyCode.Right] then move += Vector2.new(1, 0) end
			if held[Enum.KeyCode.W] or held[Enum.KeyCode.Up] then move -= Vector2.new(0, 1) end
			if held[Enum.KeyCode.S] or held[Enum.KeyCode.Down] then move += Vector2.new(0, 1) end
			pan += move * 420 * dt
			pan = Vector2.new(math.clamp(pan.X, 0, FACADE_W), math.clamp(pan.Y, 0, FACADE_H))
			facade.Position = UDim2.fromOffset(LENS / 2 - pan.X, LENS / 2 - pan.Y)

			-- 지금 보이는 장면들 그리기
			local ok, showing = pcall(function()
				return HttpService:JSONDecode(ReplicatedStorage:GetAttribute("ScopeScenes") or "[]")
			end)
			showing = if ok and typeof(showing) == "table" then showing else {}
			local now = workspace:GetServerTimeNow()
			local found = readScenes()
			local byWindow = {}
			for _, item in showing do
				if item.u > now then
					byWindow[item.w] = item
				end
			end
			for w, win in windows do
				local item = byWindow[w]
				local scene = item and SalaryConfig.getScopeScene(item.s)
				win.emoji.Text = if scene then scene.emoji else ""
				win.caption.Text = if scene and found[scene.id] then `✅ {scene.name}` elseif scene then "???" else ""
				win.frame.BackgroundColor3 = if scene then Color3.fromRGB(255, 250, 225) elseif w % 3 == 0 then Color3.fromRGB(255, 240, 190) else Color3.fromRGB(190, 215, 235)
			end

			-- 렌즈 가운데에 있는 창문
			local aimed = nil
			for w, win in windows do
				if pan.X >= win.x and pan.X <= win.x + WIN_W and pan.Y >= win.y and pan.Y <= win.y + WIN_H then
					aimed = w
				end
			end
			local item = aimed and byWindow[aimed]
			local count = 0
			for _ in found do
				count += 1
			end
			if item then
				local key = `{item.w}:{item.s}:{item.u}`
				if key ~= focusKey then
					focusKey = key
					focusTime = 0
				end
				if not spotted[key] and not busy then
					focusTime += dt
					status.Text = "🔍 초점 맞추는 중…"
					if focusTime >= SalaryConfig.SCOPE_FOCUS then
						spotted[key] = true
						busy = true
						task.spawn(function()
							local result = Remotes.ScopeSpot:InvokeServer(item.w, item.s)
							busy = false
							if current ~= overlay or not result.ok then
								if result and result.message and current == overlay then
									status.Text = result.message
								end
								return
							end
							if result.first then
								Sounds.play("ping", 0.8, if result.rarity == "legend" then 1.6 else 1.3)
								Hud.popup(`📒 새 장면! {result.emoji} {result.name} +{comma(result.reward)}원`, if result.rarity == "legend" then Color3.fromRGB(255, 210, 80) else Color3.fromRGB(150, 230, 150), 3)
								Ui.toast(`{result.emoji} {result.name} — {result.description}`)
							else
								Sounds.play("click", 0.4, 1.2)
								Hud.popup(`📒 이미 기록한 장면: {result.emoji} {result.name}`, Color3.fromRGB(220, 220, 220), 2)
							end
						end)
					end
				else
					status.Text = `📒 관찰 일지 {count}/{#SalaryConfig.ScopeScenes} · 다른 창문도 둘러봐요`
				end
			else
				focusKey = ""
				focusTime = 0
				status.Text = `📒 관찰 일지 {count}/{#SalaryConfig.ScopeScenes} · 🖱️ 드래그 / ⌨️ WASD로 둘러보기`
			end
			focusFill.Size = UDim2.fromScale(math.clamp(focusTime / SalaryConfig.SCOPE_FOCUS, 0, 1), 1)
			task.wait()
		end
		for _, connection in connections do
			connection:Disconnect()
		end
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = oldSpeed
		end
	end)
	Sounds.play("swoosh", 0.5, 0.8)
end
Remotes:WaitForChild("ScopeOpen").OnClientEvent:Connect(function()
	Panels.showScope()
end)

---------------------------------------------------------------------------
-- 🌅 노을 타임 (옥상에 있을 때만 내 화면 하늘이 주황빛으로)
---------------------------------------------------------------------------
do
	local Lighting = game:GetService("Lighting")
	local SUNSET_CLOCK = 17.55
	local tint: ColorCorrectionEffect? = nil
	local sun: Part? = nil
	local applied = false
	local savedClock = 13
	task.spawn(function()
		while true do
			task.wait(0.5)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local onRoof = root ~= nil and root.Position.Y > 280
			local want = onRoof and ReplicatedStorage:GetAttribute("Sunset") == true and ReplicatedStorage:GetAttribute("SalaryEvent") ~= "blackout"
			if want and not applied then
				applied = true
				savedClock = Lighting.ClockTime
				TweenService:Create(Lighting, TweenInfo.new(3), { ClockTime = SUNSET_CLOCK }):Play()
				tint = Instance.new("ColorCorrectionEffect")
				tint.Name = "SunsetTint"
				tint.TintColor = Color3.fromRGB(255, 255, 255)
				tint.Parent = Lighting
				TweenService:Create(tint :: ColorCorrectionEffect, TweenInfo.new(3), { TintColor = Color3.fromRGB(255, 212, 175), Saturation = 0.18, Contrast = 0.05 }):Play()
				-- 지평선 위 커다란 해
				local s = Instance.new("Part")
				s.Shape = Enum.PartType.Ball
				s.Size = Vector3.new(36, 36, 36)
				s.Color = Color3.fromRGB(255, 140, 60)
				s.Material = Enum.Material.Neon
				s.Anchored = true
				s.CanCollide = false
				s.CanQuery = false
				s.CastShadow = false
				s.Position = Vector3.new(-120, 312, -260)
				s.Parent = workspace
				sun = s
				TweenService:Create(s, TweenInfo.new(60, Enum.EasingStyle.Linear), { Position = Vector3.new(-120, 296, -260) }):Play() -- 천천히 지는 해
			elseif not want and applied then
				applied = false
				if math.abs(Lighting.ClockTime - SUNSET_CLOCK) < 0.01 then
					TweenService:Create(Lighting, TweenInfo.new(2), { ClockTime = savedClock }):Play()
				end
				if tint then
					local old = tint
					TweenService:Create(old, TweenInfo.new(2), { TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0 }):Play()
					task.delay(2.1, function()
						old:Destroy()
					end)
					tint = nil
				end
				if sun then
					sun:Destroy()
					sun = nil
				end
			end
		end
	end)
end

-- 🌅 "오늘 하루도 고생했다…" 연출 (영화처럼 위아래 검은 띠)
Remotes:WaitForChild("SunsetMoment").OnClientEvent:Connect(function()
	local layer = Ui.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 60, Parent = gui })
	local bars = {}
	for _, top in { true, false } do
		local bar = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0, if top then 0 else 1),
			Position = UDim2.fromScale(0, if top then 0 else 1),
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			ZIndex = 60,
			Parent = layer,
		})
		table.insert(bars, bar)
		TweenService:Create(bar, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Size = UDim2.new(1, 0, 0.12, 0) }):Play()
	end
	local title = Ui.make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(700, 60),
		BackgroundTransparency = 1,
		Text = "🌅 오늘 하루도 고생했다…",
		TextColor3 = Color3.fromRGB(255, 225, 190),
		TextStrokeTransparency = 0.5,
		TextTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 34,
		ZIndex = 61,
		Parent = layer,
	})
	local sub = Ui.make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.49),
		Size = UDim2.fromOffset(700, 30),
		BackgroundTransparency = 1,
		Text = `의심도가 사르르 녹았어요 · 오늘의 의심도 속도 {string.format("%.2f", SalaryConfig.SUNSET_DELTA)}`,
		TextColor3 = Color3.fromRGB(255, 240, 220),
		TextStrokeTransparency = 0.6,
		TextTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 18,
		ZIndex = 61,
		Parent = layer,
	})
	Sounds.play("ping", 0.5, 0.8)
	task.delay(0.8, function()
		TweenService:Create(title, TweenInfo.new(1.5), { TextTransparency = 0 }):Play()
		task.wait(0.8)
		TweenService:Create(sub, TweenInfo.new(1.2), { TextTransparency = 0 }):Play()
	end)
	task.delay(5.5, function()
		TweenService:Create(title, TweenInfo.new(1.2), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(sub, TweenInfo.new(1.2), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		for _, bar in bars do
			TweenService:Create(bar, TweenInfo.new(1.2), { Size = UDim2.new(1, 0, 0, 0) }):Play()
		end
		task.wait(1.3)
		layer:Destroy()
	end)
end)

-- 📸 노을 사진: 찰칵! → 폴라로이드
Remotes:WaitForChild("SunsetPhoto").OnClientEvent:Connect(function(first: boolean, count: number, prize: number)
	local flash = Ui.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.05, ZIndex = 62, Parent = gui })
	TweenService:Create(flash, TweenInfo.new(0.7), { BackgroundTransparency = 1 }):Play()
	task.delay(0.8, function()
		flash:Destroy()
	end)
	Sounds.play("click", 0.8, 0.7)
	local card = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 1.3),
		Size = UDim2.fromOffset(260, 310),
		Rotation = -4,
		BackgroundColor3 = Color3.fromRGB(252, 250, 244),
		ZIndex = 63,
		Parent = gui,
	}, { Ui.corner(4), Ui.stroke(Color3.fromRGB(200, 195, 185), 2) })
	local photo = Ui.make("Frame", {
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.new(1, -28, 0, 220),
		ZIndex = 64,
		Parent = card,
	})
	Ui.make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 90, 170)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 140, 90)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 205, 120)),
		}),
		Parent = photo,
	})
	Ui.make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromOffset(120, 80), BackgroundTransparency = 1, Text = "🌅", TextSize = 70, ZIndex = 65, Parent = photo })
	Ui.make("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Text = "🏢🏢🏬🏢🏙️🏢", TextSize = 22, ZIndex = 65, Parent = photo })
	Ui.make("TextLabel", {
		Position = UDim2.fromOffset(10, 240),
		Size = UDim2.new(1, -20, 0, 30),
		BackgroundTransparency = 1,
		Text = `{player.DisplayName}의 {count}번째 노을`,
		TextColor3 = Color3.fromRGB(70, 60, 50),
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		ZIndex = 64,
		Parent = card,
	})
	Ui.make("TextLabel", {
		Position = UDim2.fromOffset(10, 268),
		Size = UDim2.new(1, -20, 0, 24),
		BackgroundTransparency = 1,
		Text = if first then `🖼️ 앨범에 저장! +{comma(prize)}원` else "(오늘 사진은 이미 앨범에 있어요)",
		TextColor3 = if first then Color3.fromRGB(40, 140, 70) else Color3.fromRGB(130, 125, 120),
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		ZIndex = 64,
		Parent = card,
	})
	TweenService:Create(card, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	task.delay(4.5, function()
		TweenService:Create(card, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromScale(0.5, 1.3) }):Play()
		task.wait(0.6)
		card:Destroy()
	end)
end)

---------------------------------------------------------------------------
-- 🏀 옥상 농구
---------------------------------------------------------------------------
-- 공이 날아가는 모습 (모든 사람 화면에)
Remotes:WaitForChild("HoopShot").OnClientEvent:Connect(function(info)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(1, 1, 1)
	ball.Color = Color3.fromRGB(230, 110, 40)
	ball.Material = Enum.Material.SmoothPlastic
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.Position = info.from
	ball.Parent = workspace
	local rim: Vector3 = info.rim
	local floorY = rim.Y - 10 + 0.5
	local toBoard = Vector3.new(0, 0, 1) -- 골대 판 쪽
	-- 어디로 가나
	local target = rim
	if info.result == "make" then
		target = rim + Vector3.new(0.55, 0.15, 0)
	elseif info.result == "rim" then
		target = rim + Vector3.new(if math.random() < 0.5 then -1.1 else 1.1, 0.2, -0.3)
	elseif info.result == "miss" then
		target = rim + Vector3.new(math.random(-25, 25) / 10, -1.5, if math.random() < 0.5 then -1.8 else 0.6)
	end
	-- 경로 단계들: (끝 위치, 걸리는 시간, 포물선 높이)
	local steps = { { target, 0.95, 7 } }
	if info.result == "swish" or info.result == "make" then
		table.insert(steps, { rim + Vector3.new(0, -2.6, 0), 0.35, 0 }) -- 그물 통과 슉
		table.insert(steps, { Vector3.new(rim.X, floorY, rim.Z) - toBoard * 1.5, 0.3, 0 })
		table.insert(steps, { Vector3.new(rim.X, floorY, rim.Z) - toBoard * 5, 0.6, 2 })
	elseif info.result == "rim" then
		local away = target + (target - rim) * 2.5 - toBoard * 2
		table.insert(steps, { Vector3.new(away.X, floorY, away.Z), 0.7, 2.5 }) -- 땡! 튕겨 나감
		table.insert(steps, { Vector3.new(away.X, floorY, away.Z) - toBoard * 4, 0.6, 1.2 })
	else
		table.insert(steps, { Vector3.new(target.X, floorY, target.Z - 2), 0.5, 0 })
		table.insert(steps, { Vector3.new(target.X, floorY, target.Z - 7), 0.7, 1.5 })
	end
	task.spawn(function()
		for index, step in steps do
			local from = ball.Position
			local to: Vector3, duration: number, arc: number = step[1], step[2], step[3]
			local started = os.clock()
			while true do
				local t = math.clamp((os.clock() - started) / duration, 0, 1)
				ball.Position = from:Lerp(to, t) + Vector3.new(0, math.sin(t * math.pi) * arc, 0)
				ball.Orientation += Vector3.new(8, 0, 0)
				if t >= 1 then
					break
				end
				task.wait()
			end
			if index == 1 and (info.result == "rim") then
				Sounds.play("click", 0.6, 0.6) -- 땡!
			end
		end
		task.wait(2.5)
		ball:Destroy()
	end)
end)

local HOOP_TEXT = { swish = "🎯 클린슛!", make = "🏀 골인!", rim = "😫 림 맞고 튕김…", miss = "💨 에어볼…" }

function Panels.showHoop()
	local frame = sheet(340, 380)
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.Position = UDim2.new(1, -20, 0.5, 0)
	line(frame, 0, 30, "🏀 옥상 농구", { Font = Enum.Font.GothamBlack, TextSize = 24 })
	line(frame, 32, 20, "🎯 초록 +3 · 🟡 노랑 +2 · 🔥 연속 +1 · 🔊 공 소리 조심!", { TextSize = 12, TextColor3 = MUTED })
	local ballsText = line(frame, 58, 30, "", { TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center })
	local scoreText = line(frame, 92, 26, "", { TextSize = 18, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center })
	-- 슛 게이지
	local back = Ui.make("Frame", { Position = UDim2.fromOffset(0, 130), Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Color3.fromRGB(215, 218, 226), ZIndex = 31, Parent = frame }, { Ui.corner(6) })
	local function zone(half: number, color: Color3, z: number)
		Ui.make("Frame", {
			Position = UDim2.fromScale(SalaryConfig.HOOP_TARGET - half, 0),
			Size = UDim2.fromScale(half * 2, 1),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = back,
		})
	end
	zone(SalaryConfig.HOOP_RIM, Color3.fromRGB(250, 190, 120), 32)
	zone(SalaryConfig.HOOP_GOOD, Color3.fromRGB(250, 225, 110), 33)
	zone(SalaryConfig.HOOP_PERFECT, Color3.fromRGB(110, 210, 110), 34)
	local marker = Ui.make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0, 6, 1, 10), BackgroundColor3 = Color3.fromRGB(30, 30, 40), ZIndex = 36, Parent = back }, { Ui.corner(3) })
	local result = line(frame, 172, 70, "", { TextSize = 16, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center })
	local mainButton = Ui.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 0, 0, 50), Text = "", TextSize = 18, ZIndex = 31, Parent = frame })

	local playing = false
	local busy = false
	local shot = 0
	local gaugeStart = 0
	local score, streak = 0, 0
	local history: { string } = {}
	local function refresh()
		local balls = {}
		for i = 1, SalaryConfig.HOOP_SHOTS do
			balls[i] = history[i] or "🏀"
		end
		ballsText.Text = table.concat(balls, " ")
		scoreText.Text = `점수 {score}` .. (if streak >= 2 then `  🔥 {streak}연속` else "")
	end
	local function start()
		busy = true
		local r = Remotes.HoopPlay:InvokeServer("start")
		busy = false
		if current ~= frame then
			return
		end
		if not r.ok then
			result.Text = r.message
			result.TextColor3 = RED
			return
		end
		playing, shot, score, streak = true, 0, 0, 0
		table.clear(history)
		gaugeStart = r.gaugeStart
		result.Text = "초록에 멈추면 🎯 클린슛!"
		result.TextColor3 = MUTED
		mainButton.Text = "🏀 슛! (Enter)"
		Sounds.play("swoosh", 0.4)
		refresh()
	end
	local function shoot()
		if busy then
			return
		end
		if not playing then
			start()
			return
		end
		if workspace:GetServerTimeNow() < gaugeStart then
			return -- 공 받는 중
		end
		local press = workspace:GetServerTimeNow()
		busy = true
		local r = Remotes.HoopPlay:InvokeServer("shoot", press)
		busy = false
		if current ~= frame then
			return
		end
		if not r.ok then
			result.Text = r.message
			result.TextColor3 = RED
			return
		end
		shot, score, streak, gaugeStart = r.shot, r.score, r.streak, r.gaugeStart
		marker.Position = UDim2.fromScale(r.gauge, 0.5)
		history[shot] = if r.result == "swish" then "🎯" elseif r.result == "make" then "✅" else "❌"
		result.Text = HOOP_TEXT[r.result] .. (if r.points > 0 then ` +{r.points}` else "")
		result.TextColor3 = if r.points > 0 then Color3.fromRGB(40, 140, 70) else RED
		Sounds.play(if r.points > 0 then "ping" else "bass", 0.5, if r.result == "swish" then 1.5 else 1.1)
		refresh()
		if r.done then
			playing = false
			task.delay(1.2, function()
				if current ~= frame then
					return
				end
				local prizeText = if r.prize > 0 then `\n+{comma(r.prize)}원 (오늘 상금 {r.prizesLeft}번 더)` elseif score >= SalaryConfig.HoopPrizes[#SalaryConfig.HoopPrizes].score then "\n(오늘 상금은 다 받았어요)" else ""
				result.Text = `{r.label}\n최종 {score}점{prizeText}`
				result.TextColor3 = if r.prize > 0 then Color3.fromRGB(40, 140, 70) else INK
				mainButton.Text = "🏀 한 판 더 (Enter)"
			end)
		end
	end
	mainButton.Activated:Connect(shoot)
	local keyConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and current == frame and (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter) then
			shoot()
		end
	end)
	task.spawn(function()
		while current == frame do
			if playing then
				local now = workspace:GetServerTimeNow()
				if now >= gaugeStart then
					marker.Position = UDim2.fromScale(SalaryConfig.hoopGauge(now - gaugeStart, shot + 1), 0.5)
					marker.BackgroundTransparency = 0
				else
					marker.BackgroundTransparency = 0.6 -- 공 받는 중
				end
			end
			task.wait()
		end
		keyConnection:Disconnect()
	end)
	mainButton.Text = "🏀 시작 (Enter)"
	refresh()
	start()
end
Remotes:WaitForChild("HoopOpen").OnClientEvent:Connect(function()
	Panels.showHoop()
end)

-- 🐦 옥상 비둘기 관찰 노트
Remotes:WaitForChild("PigeonBook").OnClientEvent:Connect(function()
	local ok, seen = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Pigeons") or "{}")
	end)
	seen = if ok and typeof(seen) == "table" then seen else {}
	local feeds = player:GetAttribute("PigeonFeeds") or 0
	local levelIndex, level = SalaryConfig.pigeonLevel(feeds)
	local nextLevel = SalaryConfig.PigeonLevels[levelIndex + 1]
	local lines = {}
	local found = 0
	for _, kind in SalaryConfig.Pigeons do
		local count = seen[kind.id] or 0
		if count > 0 then
			found += 1
			table.insert(lines, `{kind.emoji} {kind.name} ×{count} — {kind.description}`)
		else
			local hint = if kind.minLevel > levelIndex then ` (💕 {SalaryConfig.PigeonLevels[kind.minLevel].name}부터)` else ""
			table.insert(lines, `❔ ??? 아직 못 만났어요{hint}`)
		end
	end
	showCard({
		title = `📒 비둘기 관찰 노트 ({found}/{#SalaryConfig.Pigeons})`,
		subtitle = `💕 친밀도: {level.name} (모이 {feeds}번 · 한 번에 {level.flock}마리)`
			.. (if nextLevel then ` · 다음 단계까지 {nextLevel.feeds - feeds}번` else " · 최고 단계!"),
		lines = lines,
	})
end)

-- 🐦 비둘기가 놀라서 날아갔어요 = 부장님이 곧 와요!
Remotes:WaitForChild("PigeonScare").OnClientEvent:Connect(function()
	Sounds.play("swoosh", 0.8, 1.6)
	Hud.popup("🐦 푸드덕!! 누가 올라온다!", Color3.fromRGB(255, 200, 80), 2.5)
end)

-- 시계 옆 "🕶️ 감사관" 버튼: 감사 기간에만 보여요 (이과장 출근일엔 감사가 없어서 같은 자리)
local auditChip = Ui.button({
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(1, 18, 0, -10),
	Size = UDim2.fromOffset(104, 34),
	Text = "🕶️ 감사관",
	TextSize = 15,
	Visible = false,
	Parent = Hud.clockPanel,
})
auditChip.Activated:Connect(function()
	if current then
		close()
	else
		showCard(auditPerson())
	end
end)
local auditIntroDay = nil
local function onAuditChanged()
	local isAudit = ReplicatedStorage:GetAttribute("SalaryEvent") == "audit"
	auditChip.Visible = isAudit
	auditChip.Text = if ReplicatedStorage:GetAttribute("SalaryEventStage") == "revealed" then "✅ 감사 끝" else "🕶️ 감사관"
	local day = ReplicatedStorage:GetAttribute("SalaryDay")
	if isAudit and auditIntroDay ~= day then
		auditIntroDay = day -- 감사 기간이 시작된 날 한 번 자동으로 보여 줘요
		task.spawn(function()
			task.wait(1.5)
			while current ~= nil do
				task.wait(0.5)
			end
			if ReplicatedStorage:GetAttribute("SalaryEvent") == "audit" then
				showCard(auditPerson())
			end
		end)
	end
end
ReplicatedStorage:GetAttributeChangedSignal("SalaryEvent"):Connect(onAuditChanged)
ReplicatedStorage:GetAttributeChangedSignal("SalaryEventStage"):Connect(onAuditChanged)
onAuditChanged()

-- 처음 출근한 날에는 소개 카드를 자동으로 한 번 띄워요 (다른 창이 열려 있으면 닫힌 뒤에)
local leeIntroShown = false
local function onLeePresent()
	local present = ReplicatedStorage:GetAttribute("LeePresent") == true
	leeChip.Visible = present
	if present and not leeIntroShown then
		leeIntroShown = true
		task.spawn(function()
			task.wait(1.5) -- 새 날이 시작되며 창이 닫히는 것과 겹치지 않게
			while current ~= nil do
				task.wait(0.5)
			end
			if ReplicatedStorage:GetAttribute("LeePresent") == true then
				Panels.showPerson("lee")
			end
		end)
	end
end
ReplicatedStorage:GetAttributeChangedSignal("LeePresent"):Connect(onLeePresent)
onLeePresent()

-- 🏢 눈치물산 사무실이면 들어올 때 회사 소개 카드를 한 번 (이과장 카드보다 먼저)
task.spawn(function()
	task.wait(2)
	if ReplicatedStorage:GetAttribute("SalaryCompany") == "nunchi" then
		while current ~= nil do
			task.wait(0.5)
		end
		Panels.showPerson("nunchi")
	end
end)

---------------------------------------------------------------------------
-- 🍻 목요일 회식 (판정은 서버가 해요. 여기서는 보여 주고 버튼만 보내요)
---------------------------------------------------------------------------
local dinnerLine: TextLabel? = nil

local function showDinner(seconds: number)
	local frame = sheet(500, 380)
	local endsAt = os.clock() + seconds
	line(frame, 0, 34, "🍻 목요일 회식", { Font = Enum.Font.GothamBlack, TextSize = 26 })
	line(frame, 36, 44, "🍶 부장님 잔이 거의 비었을 때 채워요 (너무 일찍 채우면 감점)\n🥂 \"건배사!\"가 뜨면 바로 [위하여!]", {
		TextSize = 15,
		TextColor3 = MUTED,
	})
	-- 부장님 잔 (위로 갈수록 가득)
	local glassBox = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.fromOffset(90, 150),
		BackgroundColor3 = Color3.fromRGB(225, 235, 240),
		ZIndex = 31,
		Parent = frame,
	}, { Ui.corner(10), Ui.stroke(Color3.fromRGB(120, 140, 150), 2) })
	local fill = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(250, 220, 120),
		ZIndex = 32,
		Parent = glassBox,
	}, { Ui.corner(10) })
	line(frame, 246, 22, "부장님 잔", { Size = UDim2.fromOffset(90, 22), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center })
	local scoreText = line(frame, 92, 30, "", { Position = UDim2.fromOffset(110, 92), Size = UDim2.new(1, -110, 0, 30), Font = Enum.Font.GothamBlack, TextSize = 22 })
	local timeText = line(frame, 124, 24, "", { Position = UDim2.fromOffset(110, 124), Size = UDim2.new(1, -110, 0, 24), TextSize = 16, TextColor3 = MUTED })
	local talk = line(frame, 156, 70, "🎤 부장님: \"자~ 한 주 고생했어!\"", {
		Position = UDim2.fromOffset(110, 156),
		Size = UDim2.new(1, -110, 0, 70),
		TextSize = 18,
		Font = Enum.Font.GothamBold,
	})
	dinnerLine = talk

	local predictedGlassUntil = 0 -- 이 시각까지는 잔을 가득 찬 것으로 먼저 보여 줘요
	local function bigButton(x: number, text: string, action: string): TextButton
		local b = Ui.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, x, 1, 0),
			Size = UDim2.fromOffset(200, 54),
			Text = text,
			TextSize = 22,
			ZIndex = 31,
			Parent = frame,
		})
		b.Activated:Connect(function()
			Sounds.play("click", 0.5)
			Remotes.Dinner:FireServer(action)
			-- ⚡ 서버 답을 기다리지 않고 화면부터 바로 반응 (판정은 서버가 해요)
			if action == "pour" then
				local before = player:GetAttribute("DinnerGlass") or 1
				predictedGlassUntil = os.clock() + 0.6
				talk.Text = if before < 0.35 then "🎤 센스 있네~ 😊" elseif before >= 0.7 then "🎤 아직 남았잖아… 😑" else "🎤 (콸콸콸)"
				Sounds.play("swoosh", 0.4, 1.4)
			elseif action == "cheers" then
				talk.Text = if player:GetAttribute("DinnerCheers") then "🎤 위하여~! 🥂" else "🎤 혼자 건배…?"
			end
			-- 눌린 느낌
			b.Size = UDim2.fromOffset(190, 50)
			TweenService:Create(b, TweenInfo.new(0.12), { Size = UDim2.fromOffset(200, 54) }):Play()
		end)
		return b
	end
	bigButton(-108, "🍶 따르기", "pour")
	local cheersButton = bigButton(108, "🥂 위하여!", "cheers")

	task.spawn(function()
		while current == frame do
			local glass = if os.clock() < predictedGlassUntil then 1 else (player:GetAttribute("DinnerGlass") or 1)
			fill.Size = UDim2.fromScale(1, math.clamp(glass, 0, 1))
			fill.BackgroundColor3 = if glass < 0.35 then Color3.fromRGB(240, 110, 90) else Color3.fromRGB(250, 220, 120)
			scoreText.Text = `점수 {player:GetAttribute("DinnerScore") or 0}점`
			timeText.Text = `남은 시간 {math.max(0, math.ceil(endsAt - os.clock()))}초`
			local cheers = player:GetAttribute("DinnerCheers") == true
			cheersButton.BackgroundColor3 = if cheers and math.floor(os.clock() * 6) % 2 == 0 then Color3.fromRGB(255, 120, 120) else Ui.COLORS.brass
			task.wait(0.05)
		end
	end)
end

Remotes:WaitForChild("Dinner").OnClientEvent:Connect(function(kind: string, a: any, b: any)
	if kind == "start" then
		Sounds.play("swoosh", 0.5)
		Hud.popup("🍻 목요일 회식!", Color3.fromRGB(255, 200, 120), 2.5)
		showDinner(a)
	elseif kind == "line" then
		if dinnerLine and dinnerLine.Parent then
			dinnerLine.Text = `🎤 {a}`
		end
	elseif kind == "end" then
		local score, mood = a, b
		local result = if mood < 1 then "😊 부장님 기분 최고! 내일은 의심도가 덜 올라요."
			elseif mood > 1 then "😠 부장님이 서운해해요… 내일은 의심도가 더 올라요."
			else "😐 무난한 회식이었어요."
		if dinnerLine and dinnerLine.Parent then
			dinnerLine.Text = `🍻 회식 끝! {score}점\n{result}`
		end
		Ui.toast(`🍻 회식 끝! {score}점 · {result}`)
	end
end)

---------------------------------------------------------------------------
-- 🏙️ 눈치 스트리트 가게 메뉴 (계산대에서 [E] 주문하기)
---------------------------------------------------------------------------
local function showStreetShop(shopId: string)
	local shop = SalaryConfig.StreetShops[shopId]
	if not shop then
		return
	end
	local items = shop.items
	local frame = sheet(560, 130 + #items * 64)
	line(frame, 0, 30, shop.name, { Font = Enum.Font.GothamBlack, TextSize = 24 })
	local balance = line(frame, 0, 30, "", {
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamBold,
		Size = UDim2.new(1, -44, 0, 30),
	})
	local message = line(frame, 30 + #items * 64 + 14, 22, if shopId == "store" then "🎁 산 선물은 부장님께 다가가 [E] 말 걸기로 드려요" else "근무 중이라면 빨리 사서 돌아가요! 🖥️ 자리 부재 게이지가 차고 있어요", { TextSize = 15, TextColor3 = MUTED })
	for i, item in items do
		local y = 40 + (i - 1) * 64
		line(frame, y, 22, `{item.emoji} {item.name} · {comma(item.price)}원`, { Font = Enum.Font.GothamBold })
		line(frame, y + 22, 36, item.description, { TextSize = 14, TextColor3 = MUTED, Size = UDim2.new(1, -120, 0, 36) })
		local buy = Ui.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, y + 8),
			Size = UDim2.fromOffset(110, 40),
			Text = if item.gift then "사기" elseif item.snack then "포장하기" else "마시기",
			TextSize = 16,
			ZIndex = 31,
			Parent = frame,
		})
		buy.Activated:Connect(function()
			local ok, result = Remotes.BuyStreet:InvokeServer(shopId, item.id)
			message.Text = result
			message.TextColor3 = if ok then Color3.fromRGB(40, 140, 70) else RED
			if ok then
				Sounds.play("ping", 0.6, 1.2)
			end
		end)
	end
	task.spawn(function()
		while current == frame do
			balance.Text = `🏦 {comma(player:GetAttribute("TotalMoney") or 0)}원`
			task.wait(0.3)
		end
	end)
	Sounds.play("swoosh", 0.4)
end

Remotes:WaitForChild("StreetMenu").OnClientEvent:Connect(function(shopId: string)
	if shopId == "store" then
		Panels.showShop() -- 🏪 사내 매점은 사무용품 + 선물 탭
	else
		showStreetShop(shopId)
	end
end)

---------------------------------------------------------------------------
-- 🧸 인형뽑기 기계 (판정은 서버가 해요. 화면은 같은 식으로 집게를 움직여 보여 줘요)
---------------------------------------------------------------------------
local function rarityText(plush): string
	local rarity = SalaryConfig.PlushRarity[plush.rarity]
	return if rarity then rarity.name else ""
end

local function showClaw()
	local BOX = 300 -- 기계 안 (위에서 본 모습) 크기
	local frame = sheet(520, 560)
	line(frame, 0, 32, "🧸 인형뽑기", { Font = Enum.Font.GothamBlack, TextSize = 26 })
	line(frame, 34, 40, `① 좌우로 움직일 때 [멈춤] → ② 앞뒤로 움직일 때 [내리기]! 한 판 {comma(SalaryConfig.CLAW_PRICE)}원\n정중앙을 노려야 잘 잡혀요. 희귀할수록 미끄러워요 😅`, {
		TextSize = 14,
		TextColor3 = MUTED,
	})
	local box = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 82),
		Size = UDim2.fromOffset(BOX, BOX),
		BackgroundColor3 = Color3.fromRGB(215, 235, 250),
		ClipsDescendants = false,
		ZIndex = 31,
		Parent = frame,
	}, { Ui.corner(10), Ui.stroke(Color3.fromRGB(120, 150, 180), 3) })
	Ui.make("TextLabel", { -- 상자 위쪽 = 기계 안쪽
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Text = "⬆️ 안쪽 (전설 인형은 깊숙이!)",
		TextSize = 12,
		TextColor3 = MUTED,
		Font = Enum.Font.GothamMedium,
		ZIndex = 32,
		Parent = box,
	})
	-- 출구 (왼쪽 아래 바깥)
	local chute = Ui.make("TextLabel", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(0, -8, 1, 0),
		Size = UDim2.fromOffset(56, 40),
		BackgroundColor3 = Color3.fromRGB(60, 60, 70),
		TextColor3 = Color3.new(1, 1, 1),
		Text = "출구\n⬇️",
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		ZIndex = 32,
		Parent = box,
	}, { Ui.corner(8) })

	-- 0~1 좌표 → 상자 안 위치 (z가 클수록 위쪽 = 안쪽)
	local function toBox(x: number, z: number): UDim2
		return UDim2.fromOffset(x * BOX, (1 - z) * BOX)
	end

	-- 집게 (가운데 십자 + 잡히는 범위 원)
	local clawSize = SalaryConfig.CLAW_RADIUS * 2 * BOX
	local claw = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = toBox(0, 0),
		Size = UDim2.fromOffset(clawSize, clawSize),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.6,
		ZIndex = 35,
		Parent = box,
	}, { Ui.corner(clawSize), Ui.stroke(Color3.fromRGB(230, 60, 60), 3) })
	Ui.make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "+",
		TextScaled = true,
		TextColor3 = Color3.fromRGB(230, 60, 60),
		ZIndex = 36,
		Parent = claw,
	})

	local status = line(frame, 0, 40, "▶ 시작을 눌러 주세요!", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -62),
		TextSize = 17,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local function bigButton(x: number, text: string): TextButton
		return Ui.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, x, 1, 0),
			Size = UDim2.fromOffset(210, 52),
			Text = text,
			TextSize = 20,
			ZIndex = 31,
			Parent = frame,
		})
	end
	local startButton = bigButton(-110, `▶ 시작 ({comma(SalaryConfig.CLAW_PRICE)}원)`)
	local actionButton = bigButton(110, "⏸ 멈춤")

	local plushLabels: { [any]: TextLabel } = {}
	local session: any = nil
	local stage = "idle" -- idle → x(좌우) → z(앞뒤) → busy(판정·연출)
	local stopX: number? = nil

	local function clearLayout()
		for _, label in plushLabels do
			label:Destroy()
		end
		table.clear(plushLabels)
	end

	local function drawLayout(layout)
		clearLayout()
		for _, item in layout do
			local plush = SalaryConfig.getPlush(item.id)
			if not plush then
				continue
			end
			local legend = plush.rarity == "legend"
			plushLabels[item] = Ui.make("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = toBox(item.x, item.z),
				Size = UDim2.fromOffset(40, 40),
				BackgroundColor3 = if legend then Color3.fromRGB(255, 220, 120) else Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = if legend then 0.2 else 1,
				Text = plush.emoji,
				TextScaled = true,
				ZIndex = 33,
				Parent = box,
			}, { Ui.corner(20) })
		end
	end

	startButton.Activated:Connect(function()
		if stage == "busy" or stage == "x" or stage == "z" then
			return
		end
		Sounds.play("click", 0.5)
		local result = Remotes.Claw:InvokeServer("start")
		if not result.ok then
			status.Text = result.message
			status.TextColor3 = RED
			return
		end
		session, stopX = result, nil
		drawLayout(result.layout)
		claw.Size = UDim2.fromOffset(clawSize, clawSize)
		stage = "x"
		actionButton.Text = "⏸ 멈춤"
		status.Text = "① 좌우로 움직이는 중… 원하는 인형 줄에서 [멈춤]!"
		status.TextColor3 = INK
	end)

	actionButton.Activated:Connect(function()
		if stage == "x" then
			local now = workspace:GetServerTimeNow()
			if now < session.start then
				return
			end
			stage = "z"
			stopX = now
			actionButton.Text = "⬇️ 내리기"
			status.Text = "② 앞뒤로 움직이는 중… 인형 바로 위에서 [내리기]!"
			Sounds.play("click", 0.5, 1.2)
			task.spawn(function()
				local result = Remotes.Claw:InvokeServer("stop", now)
				if result.ok then
					stopX = result.stopX
				end
			end)
		elseif stage == "z" and stopX then
			local now = workspace:GetServerTimeNow()
			if now < stopX + SalaryConfig.CLAW_GAP then
				return
			end
			stage = "busy"
			local result = Remotes.Claw:InvokeServer("drop", now)
			if not result.ok then
				stage = "idle"
				status.Text = result.message
				status.TextColor3 = RED
				return
			end
			-- 집게가 판정된 위치로 가서 내려가요
			claw.Position = toBox(result.x, result.z)
			Sounds.play("swoosh", 0.4)
			TweenService:Create(claw, TweenInfo.new(0.5), { Size = UDim2.fromOffset(clawSize * 0.6, clawSize * 0.6) }):Play()
			task.wait(0.6)
			local caughtLabel: TextLabel? = nil
			for item, label in plushLabels do
				if item.id == result.plushId and math.abs(item.x - result.x) < 0.2 and math.abs(item.z - result.z) < 0.2 then
					caughtLabel = label
				end
			end
			local plush = result.plushId and SalaryConfig.getPlush(result.plushId)
			TweenService:Create(claw, TweenInfo.new(0.4), { Size = UDim2.fromOffset(clawSize, clawSize) }):Play()
			if result.outcome == "miss" or not plush or not caughtLabel then
				status.Text = "빈손… 😢 집게 아래에 인형이 없었어요"
				status.TextColor3 = RED
			else
				local label = caughtLabel :: TextLabel
				-- 들어 올리기
				TweenService:Create(label, TweenInfo.new(0.4), { Size = UDim2.fromOffset(52, 52) }):Play()
				task.wait(0.5)
				if result.outcome == "slip" then
					TweenService:Create(label, TweenInfo.new(0.25), { Size = UDim2.fromOffset(40, 40) }):Play()
					Sounds.play("bass", 0.4, 1.4)
					status.Text = `앗! {plush.emoji} 들어 올리다 미끄러졌어요… (정확도 {result.accuracy}%)`
					status.TextColor3 = RED
				else
					-- 출구로 옮기기 (떨어뜨리면 중간에 툭)
					local goal = UDim2.fromOffset(-30, BOX - 10)
					local halfway = UDim2.new(0, (label.Position.X.Offset - 30) / 2, 0, (label.Position.Y.Offset + BOX - 10) / 2)
					local target = if result.outcome == "drop" then halfway else goal
					TweenService:Create(label, TweenInfo.new(0.8), { Position = target }):Play()
					TweenService:Create(claw, TweenInfo.new(0.8), { Position = target }):Play()
					task.wait(0.85)
					if result.outcome == "drop" then
						TweenService:Create(label, TweenInfo.new(0.25), { Size = UDim2.fromOffset(40, 40) }):Play()
						Sounds.play("bass", 0.4, 1.4)
						status.Text = `아까워! {plush.emoji} 출구 앞에서 툭 떨어뜨렸어요 😭`
						status.TextColor3 = RED
					else
						Sounds.play("ping", 0.7, 1.3)
						status.Text = `🎉 {plush.emoji} {plush.name} 획득! ({rarityText(plush)})`
						status.TextColor3 = Color3.fromRGB(40, 140, 70)
						Hud.popup(`🧸 {plush.emoji} {plush.name} 획득!`, Color3.fromRGB(255, 210, 80), 2.5)
						label.Visible = false
					end
				end
			end
			startButton.Text = `▶ 한 판 더 ({comma(SalaryConfig.CLAW_PRICE)}원)`
			actionButton.Text = "⏸ 멈춤"
			stage = "idle"
		end
	end)

	-- 집게 움직이기 (서버와 같은 식)
	task.spawn(function()
		while current == frame do
			if session and stage == "x" then
				local x = SalaryConfig.clawPosition(math.max(0, workspace:GetServerTimeNow() - session.start), session.periodX)
				claw.Position = toBox(x, 0)
			elseif session and stage == "z" and stopX then
				local x = SalaryConfig.clawPosition(stopX - session.start, session.periodX)
				local z = SalaryConfig.clawPosition(math.max(0, workspace:GetServerTimeNow() - stopX - SalaryConfig.CLAW_GAP), session.periodZ)
				claw.Position = toBox(x, z)
			end
			task.wait()
		end
	end)
	local _ = chute
	Sounds.play("swoosh", 0.4)
end

Remotes:WaitForChild("ClawOpen").OnClientEvent:Connect(showClaw)

---------------------------------------------------------------------------
-- 🧸 내 인형 (눌러서 책상에 진열)
---------------------------------------------------------------------------
function Panels.showPlushies()
	local plushRows = math.ceil(#SalaryConfig.Plushies / 3)
	local frame = sheet(540, 90 + plushRows * 92)
	line(frame, 0, 32, "🧸 내 인형", { Font = Enum.Font.GothamBlack, TextSize = 26 })
	line(frame, 34, 22, `눌러서 책상에 진열하기 (최대 {SalaryConfig.DESK_PLUSH_MAX}개) · 눈치 스트리트 인형뽑기에서 뽑아요`, { TextSize = 14, TextColor3 = MUTED })
	local cards = {}
	for i, plush in SalaryConfig.Plushies do
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
		local rarity = SalaryConfig.PlushRarity[plush.rarity]
		local card = Ui.make("TextButton", {
			Position = UDim2.fromOffset(col * 170, 64 + row * 92),
			Size = UDim2.fromOffset(160, 84),
			BackgroundColor3 = Color3.fromRGB(240, 240, 238),
			AutoButtonColor = true,
			Text = "",
			ZIndex = 31,
			Parent = frame,
		}, { Ui.corner(10), Ui.stroke(rarity and rarity.color or MUTED, 2) })
		local icon = line(card, 6, 40, plush.emoji, { Size = UDim2.new(1, 0, 0, 40), TextSize = 34, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 32 })
		local label = line(card, 48, 30, "", { Size = UDim2.new(1, 0, 0, 30), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 32 })
		card.Activated:Connect(function()
			Remotes.SetDeskPlush:FireServer(plush.id)
			Sounds.play("click", 0.4)
		end)
		cards[plush.id] = { card = card, icon = icon, label = label, plush = plush, rarity = rarity }
	end
	task.spawn(function()
		while current == frame do
			local owned = HttpService:JSONDecode(player:GetAttribute("Plushies") or "{}")
			local onDesk = HttpService:JSONDecode(player:GetAttribute("DeskPlushies") or "[]")
			for id, info in cards do
				local count = owned[id]
				local shown = table.find(onDesk, id) ~= nil
				if count then
					info.icon.Text = info.plush.emoji
					info.label.Text = `{info.plush.name} x{count}\n{if shown then "📌 책상에 진열 중" else (info.rarity and info.rarity.name or "")}`
				else
					info.icon.Text = "❓"
					info.label.Text = `???\n{info.rarity and info.rarity.name or ""}`
				end
				info.card.BackgroundColor3 = if shown then Color3.fromRGB(200, 240, 200) elseif count then Color3.fromRGB(250, 250, 248) else Color3.fromRGB(220, 220, 220)
			end
			task.wait(0.3)
		end
	end)
	Sounds.play("swoosh", 0.4)
end

---------------------------------------------------------------------------
-- 🕹️ 오락실 (판정은 서버. 화면은 서버가 정한 일정대로 보여 주고, 누른 시각만 보내요)
---------------------------------------------------------------------------
local function arcadeHeader(frame: Frame, title: string, description: string): (TextLabel, TextLabel)
	line(frame, 0, 32, title, { Font = Enum.Font.GothamBlack, TextSize = 26 })
	local tickets = line(frame, 0, 32, "", { TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBold, Size = UDim2.new(1, -44, 0, 32) })
	line(frame, 34, 40, description, { TextSize = 14, TextColor3 = MUTED })
	local status = line(frame, 0, 30, "", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -60),
		TextSize = 18,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	task.spawn(function()
		while frame.Parent do
			tickets.Text = `🎟️ {player:GetAttribute("Tickets") or 0}장`
			task.wait(0.3)
		end
	end)
	return tickets, status
end

local function arcadeButton(frame: Frame, x: number, text: string): TextButton
	return Ui.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, x, 1, 0),
		Size = UDim2.fromOffset(220, 52),
		Text = text,
		TextSize = 20,
		ZIndex = 31,
		Parent = frame,
	})
end

local function showResult(status: TextLabel, result)
	if not result.ok then
		status.Text = result.message
		status.TextColor3 = RED
		return
	end
	Sounds.play("ping", 0.7, 1.2)
	status.Text = `점수 {result.score}점 → 🎟️ +{result.tickets}장` .. (if result.isBest then "  🏆 내 최고 기록!" else `  (내 최고 {result.best})`)
	status.TextColor3 = Color3.fromRGB(40, 140, 70)
end

local function showMole()
	local info = SalaryConfig.ArcadeGames.mole
	local frame = sheet(520, 520)
	local _, status = arcadeHeader(frame, `{info.emoji} {info.name}`, info.description)
	local scoreText = line(frame, 76, 26, "", { TextSize = 18, Font = Enum.Font.GothamBold })
	local holes = {}
	for i = 1, 9 do
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
		local hole = Ui.make("TextButton", {
			Position = UDim2.new(0.5, (col - 1) * 130 - 60, 0, 108 + row * 96),
			Size = UDim2.fromOffset(120, 88),
			BackgroundColor3 = Color3.fromRGB(120, 85, 55),
			Text = "",
			TextSize = 46,
			AutoButtonColor = false,
			ZIndex = 31,
			Parent = frame,
		}, { Ui.corner(44) })
		holes[i] = hole
	end
	local startButton = arcadeButton(frame, 0, `▶ 시작 ({comma(SalaryConfig.ARCADE_PRICE)}원)`)
	local run: any = nil
	local hits = {}
	local score = 0
	local EMOJI = { normal = "🐹", gold = "⭐", boss = "👔" }
	local POINTS = { normal = 1, gold = 3, boss = -2 }

	local function visibleMole(hole: number): number?
		if not run then
			return nil
		end
		local now = workspace:GetServerTimeNow() - run.start
		for index, mole in run.moles do
			if mole.hole == hole and not hits[index] and now >= mole.t and now <= mole.t + mole.life then
				return index
			end
		end
		return nil
	end

	for i, hole in holes do
		hole.Activated:Connect(function()
			local index = visibleMole(i)
			if not index then
				return
			end
			hits[index] = workspace:GetServerTimeNow()
			local mole = run.moles[index]
			score = math.max(0, score + POINTS[mole.kind])
			Sounds.play(if mole.kind == "boss" then "bass" else "click", 0.6, if mole.kind == "gold" then 1.5 else 1)
		end)
	end

	startButton.Activated:Connect(function()
		if run then
			return
		end
		local result = Remotes.Arcade:InvokeServer("start", "mole")
		if not result.ok then
			status.Text = result.message
			status.TextColor3 = RED
			return
		end
		run, hits, score = result, {}, 0
		status.Text = "준비~"
		status.TextColor3 = INK
		startButton.Text = "게임 중…"
		task.spawn(function()
			while current == frame and run == result do
				local elapsed = workspace:GetServerTimeNow() - result.start
				scoreText.Text = `점수 {score}점 · 남은 시간 {math.max(0, math.ceil(SalaryConfig.MOLE_SECONDS - elapsed))}초`
				for i, hole in holes do
					local index = visibleMole(i)
					hole.Text = if index then EMOJI[result.moles[index].kind] else ""
					hole.BackgroundColor3 = if index then Color3.fromRGB(160, 115, 75) else Color3.fromRGB(120, 85, 55)
				end
				if elapsed >= SalaryConfig.MOLE_SECONDS + 0.2 then
					local list = {}
					for index, t in hits do
						table.insert(list, { index, t })
					end
					run = nil
					showResult(status, Remotes.Arcade:InvokeServer("finish", list))
					startButton.Text = `▶ 한 판 더 ({comma(SalaryConfig.ARCADE_PRICE)}원)`
					break
				end
				task.wait()
			end
		end)
	end)
	Sounds.play("swoosh", 0.4)
end

local function showTiming()
	local info = SalaryConfig.ArcadeGames.timing
	local frame = sheet(520, 360)
	local _, status = arcadeHeader(frame, `{info.emoji} {info.name}`, info.description)
	local roundText = line(frame, 80, 26, "", { TextSize = 18, Font = Enum.Font.GothamBold })
	local bar = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 120),
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = Color3.fromRGB(60, 60, 70),
		ZIndex = 31,
		Parent = frame,
	}, { Ui.corner(8) })
	local good = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromScale(SalaryConfig.TIMING_GOOD * 2, 1),
		BackgroundColor3 = Color3.fromRGB(90, 190, 110),
		ZIndex = 32,
		Parent = bar,
	})
	local perfect = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(SalaryConfig.TIMING_PERFECT / (SalaryConfig.TIMING_GOOD * 2) * 2, 1),
		BackgroundColor3 = Color3.fromRGB(255, 220, 90),
		ZIndex = 33,
		Parent = good,
	})
	local marker = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0, 0, 0, -6),
		Size = UDim2.new(0, 6, 1, 12),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		ZIndex = 34,
		Parent = bar,
	})
	local _ = perfect
	local startButton = arcadeButton(frame, -115, `▶ 시작 ({comma(SalaryConfig.ARCADE_PRICE)}원)`)
	local stopButton = arcadeButton(frame, 115, "🛑 멈춰!")
	local run: any = nil
	local presses = {}
	local roundStart = 0
	local score = 0
	local frozen: any = nil -- 방금 멈춘 결과 (다음 라운드 시작 전까지 그대로 보여 줘요)

	local function round(): number
		return #presses + 1
	end

	startButton.Activated:Connect(function()
		if run then
			return
		end
		local result = Remotes.Arcade:InvokeServer("start", "timing")
		if not result.ok then
			status.Text = result.message
			status.TextColor3 = RED
			return
		end
		run, presses, score, roundStart, frozen = result, {}, 0, result.start, nil
		status.Text = ""
		startButton.Text = "게임 중…"
		task.spawn(function()
			while current == frame and run == result do
				local r = result.rounds[round()]
				if frozen and workspace:GetServerTimeNow() < roundStart then
					-- 쉬는 시간: 멈춘 자리와 그 라운드 목표를 그대로 보여 줘요
					good.Position = UDim2.fromScale(frozen.target, 0)
					marker.Position = UDim2.new(frozen.position, 0, 0, -6)
					marker.BackgroundColor3 = frozen.color
				elseif r then
					frozen = nil
					marker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					good.Position = UDim2.fromScale(r.target, 0)
					local position = SalaryConfig.clawPosition(math.max(0, workspace:GetServerTimeNow() - roundStart), r.period)
					marker.Position = UDim2.new(position, 0, 0, -6)
					roundText.Text = `라운드 {round()}/{SalaryConfig.TIMING_ROUNDS} · 점수 {score}점`
				end
				task.wait()
			end
		end)
	end)

	stopButton.Activated:Connect(function()
		if not run then
			return
		end
		local now = workspace:GetServerTimeNow()
		local r = run.rounds[round()]
		if not r or now < roundStart then
			return -- 다음 라운드 준비 중
		end
		local position = SalaryConfig.clawPosition(now - roundStart, r.period)
		local gap = math.abs(position - r.target)
		local color
		if gap <= SalaryConfig.TIMING_PERFECT then
			score += 3
			status.Text = "🌟 퍼펙트! +3"
			color = Color3.fromRGB(255, 220, 90)
			Sounds.play("ping", 0.6, 1.5)
		elseif gap <= SalaryConfig.TIMING_GOOD then
			score += 1
			status.Text = "👍 굿! +1"
			color = Color3.fromRGB(90, 200, 110)
			Sounds.play("ping", 0.5, 1.1)
		else
			status.Text = "😵 미스!"
			color = Color3.fromRGB(230, 70, 70)
			Sounds.play("bass", 0.4, 1.3)
		end
		frozen = { position = position, target = r.target, color = color }
		roundText.Text = `라운드 {round()}/{SalaryConfig.TIMING_ROUNDS} · 점수 {score}점 · 다음 라운드 준비…`
		status.TextColor3 = INK
		table.insert(presses, now)
		roundStart = now + SalaryConfig.TIMING_PAUSE
		if #presses >= SalaryConfig.TIMING_ROUNDS then
			local finished = run
			run = nil
			task.wait(0.5)
			if finished then
				showResult(status, Remotes.Arcade:InvokeServer("finish", presses))
			end
			startButton.Text = `▶ 한 판 더 ({comma(SalaryConfig.ARCADE_PRICE)}원)`
		end
	end)
	Sounds.play("swoosh", 0.4)
end

local function showPrizes()
	local prizes = SalaryConfig.ArcadePrizes
	local frame = sheet(560, 130 + #prizes * 64)
	arcadeHeader(frame, "🎟️ 경품 교환", "게임 점수로 받은 티켓을 경품으로 바꿔요")
	local message = line(frame, 0, 22, "", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		TextSize = 15,
		TextColor3 = MUTED,
	})
	for i, prize in prizes do
		local y = 80 + (i - 1) * 64
		line(frame, y, 22, `{prize.emoji} {prize.name} · 🎟️ {prize.tickets}장`, { Font = Enum.Font.GothamBold })
		line(frame, y + 22, 36, prize.description, { TextSize = 14, TextColor3 = MUTED, Size = UDim2.new(1, -120, 0, 36) })
		local b = Ui.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, y + 8),
			Size = UDim2.fromOffset(110, 40),
			Text = "교환",
			TextSize = 16,
			ZIndex = 31,
			Parent = frame,
		})
		b.Activated:Connect(function()
			local result = Remotes.Arcade:InvokeServer("exchange", prize.id)
			message.Text = result.message
			message.TextColor3 = if result.ok then Color3.fromRGB(40, 140, 70) else RED
			if result.ok then
				Sounds.play("ping", 0.7, 1.3)
			end
		end)
	end
	Sounds.play("swoosh", 0.4)
end

Remotes:WaitForChild("ArcadeOpen").OnClientEvent:Connect(function(kind: string)
	if kind == "mole" then
		showMole()
	elseif kind == "timing" then
		showTiming()
	elseif kind == "prizes" then
		showPrizes()
	end
end)

---------------------------------------------------------------------------
-- 🎡 다 같이 돌림판 (결과는 서버가 정하고, 모든 화면이 같은 각도로 돌아요)
---------------------------------------------------------------------------
local SEGMENT_ANGLE = 360 / #SalaryConfig.WHEEL_SEGMENTS

local function currentWheelRotation(): number
	local from = ReplicatedStorage:GetAttribute("WheelFrom") or 0
	local to = ReplicatedStorage:GetAttribute("WheelTo") or 0
	local start = ReplicatedStorage:GetAttribute("WheelSpinStart") or 0
	return SalaryConfig.wheelRotation(from, to, workspace:GetServerTimeNow() - start) -- 다 돌면 끝 각도에 멈춰 있어요
end

-- 뒷벽 큰 돌림판도 내 화면에서 돌려요 (서버가 정한 각도라 모두에게 똑같이 보여요)
task.spawn(function()
	local spin: Frame? = nil
	while true do
		if not spin or not spin.Parent then
			local office = workspace:FindFirstChild("Office")
			local disc = office and office:FindFirstChild("WheelDisc")
			local gui = disc and disc:FindFirstChild("WheelGui")
			spin = gui and gui:FindFirstChild("Spin") :: Frame?
		end
		if spin then
			spin.Rotation = currentWheelRotation()
			task.wait()
		else
			task.wait(2)
		end
	end
end)

local function showWheel()
	local frame = sheet(560, 580)
	line(frame, 0, 32, "🎡 돌림판", { Font = Enum.Font.GothamBlack, TextSize = 26 })
	local phaseText = line(frame, 34, 24, "금액을 고르고 숫자에 건 다음 [🎡 돌리기]!", { TextSize = 16, Font = Enum.Font.GothamBold })
	local historyText = line(frame, 34, 24, "", { TextSize = 14, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(1, -44, 0, 24) })

	-- 작은 돌림판 (내가 돌린 판)
	local WHEEL = 210
	local holder = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 70),
		Size = UDim2.fromOffset(WHEEL, WHEEL),
		BackgroundColor3 = Color3.fromRGB(40, 40, 50),
		ZIndex = 31,
		Parent = frame,
	}, { Ui.corner(WHEEL) })
	local spin = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 32,
		Parent = holder,
	})
	for i, number in SalaryConfig.WHEEL_SEGMENTS do
		local angle = math.rad((i - 1) * SEGMENT_ANGLE)
		Ui.make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + 0.41 * math.sin(angle), 0.5 - 0.41 * math.cos(angle)),
			Size = UDim2.fromOffset(24, 24),
			Rotation = (i - 1) * SEGMENT_ANGLE,
			BackgroundColor3 = SalaryConfig.WHEEL_COLORS[number],
			TextColor3 = Color3.new(1, 1, 1),
			Font = Enum.Font.GothamBlack,
			TextScaled = true,
			Text = tostring(number),
			ZIndex = 33,
			Parent = spin,
		}, { Ui.corner(6) })
	end
	Ui.make("TextLabel", { -- ▼ 바늘
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(26, 22),
		BackgroundTransparency = 1,
		Text = "▼",
		TextScaled = true,
		TextColor3 = Color3.fromRGB(230, 50, 50),
		ZIndex = 34,
		Parent = holder,
	})
	local resultText = Ui.make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.4, 0.4),
		BackgroundColor3 = Color3.fromRGB(30, 30, 40),
		TextColor3 = Color3.fromRGB(255, 220, 120),
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		Text = "🎡",
		ZIndex = 35,
		Parent = holder,
	}, { Ui.corner(60) })

	-- 베팅 금액 고르기
	local amount = SalaryConfig.WHEEL_BETS[1]
	local amountButtons = {}
	for i, value in SalaryConfig.WHEEL_BETS do
		local b = Ui.button({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, (i - 2) * 130, 0, 292),
			Size = UDim2.fromOffset(120, 36),
			Text = `{comma(value)}원`,
			TextSize = 16,
			ZIndex = 31,
			Parent = frame,
		})
		b.Activated:Connect(function()
			amount = value
			Sounds.play("click", 0.4)
		end)
		amountButtons[value] = b
	end

	local message = line(frame, 0, 24, "💰 금액 하나, 🎯 숫자 하나를 고르고 [🎡 돌리기]! 멈춘 숫자를 맞히면 건 돈 × (숫자+1)", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -58),
		TextSize = 14,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local choiceText = line(frame, 0, 26, "", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -84),
		TextSize = 17,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local selectedNumber: number? = nil
	local numberButtons: { [number]: TextButton } = {}
	for i, number in SalaryConfig.WHEEL_NUMBERS do
		local count = 0
		for _, n in SalaryConfig.WHEEL_SEGMENTS do
			if n == number then
				count += 1
			end
		end
		local b = Ui.button({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, (i - 3) * 100, 0, 340),
			Size = UDim2.fromOffset(92, 64),
			BackgroundColor3 = SalaryConfig.WHEEL_COLORS[number],
			TextColor3 = Color3.new(1, 1, 1),
			Text = `{number}\n×{number + 1} · {count * 4}%`,
			TextSize = 15,
			ZIndex = 31,
			Parent = frame,
		})
		numberButtons[number] = b
		b.Activated:Connect(function()
			selectedNumber = number -- 같은 걸 또 눌러도 그대로 선택돼 있어요
			Sounds.play("click", 0.4)
		end)
	end

	-- 🎡 돌리기
	local spinState: any = nil -- 내가 돌린 판 { from, to, spinStart, number, win, stake }
	local history = {}
	local spinButton = Ui.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(260, 52),
		Text = "🎡 돌리기!",
		TextSize = 22,
		ZIndex = 31,
		Parent = frame,
	})
	spinButton.Activated:Connect(function()
		if spinState then
			return
		end
		if not selectedNumber then
			message.Text = "🎯 먼저 숫자를 골라 주세요!"
			message.TextColor3 = RED
			return
		end
		local result = Remotes.WheelBet:InvokeServer("spin", amount, selectedNumber)
		if not result.ok then
			message.Text = result.message
			message.TextColor3 = RED
			return
		end
		Sounds.play("swoosh", 0.5)
		spinState = result
		resultText.Text = "🌀"
		phaseText.Text = "🌀 돌아가는 중… 두근두근"
		task.delay(SalaryConfig.WHEEL_SPIN_SECONDS, function()
			if current ~= frame then
				return
			end
			resultText.Text = tostring(result.number)
			table.insert(history, 1, tostring(result.number))
			if #history > 8 then
				table.remove(history)
			end
			historyText.Text = "최근: " .. table.concat(history, " ")
			if result.win > 0 then
				Sounds.play("ping", 0.8, 1.4)
				phaseText.Text = `🎉 {result.number} 당첨! +{comma(result.win)}원`
				phaseText.TextColor3 = Color3.fromRGB(40, 140, 70)
				Hud.popup(`🎡 {result.number} 당첨! +{comma(result.win)}원`, Color3.fromRGB(255, 210, 80), 3)
			else
				Sounds.play("bass", 0.5, 1.2)
				phaseText.Text = `😢 {result.number}에 멈췄어요… (-{comma(result.stake)}원)`
				phaseText.TextColor3 = RED
			end
			spinState = nil
		end)
	end)

	task.spawn(function()
		while current == frame do
			if spinState then
				spin.Rotation = SalaryConfig.wheelRotation(spinState.from, spinState.to, workspace:GetServerTimeNow() - spinState.spinStart)
			end
			for value, b in amountButtons do
				b.BackgroundColor3 = if value == amount then Color3.fromRGB(255, 200, 80) else Color3.fromRGB(200, 200, 205)
			end
			spinButton.Text = if spinState then "🌀 돌아가는 중…" else "🎡 돌리기!"
			-- 고른 숫자는 흰 테두리로, 고른 내용은 아래에 보여 줘요
			for number, b in numberButtons do
				local stroke = b:FindFirstChild("PickStroke") :: UIStroke?
				if number == selectedNumber and not stroke then
					Ui.make("UIStroke", { Name = "PickStroke", ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(40, 40, 50), Thickness = 4, Parent = b }) -- (Border: 글자 말고 버튼 테두리에)
				elseif number ~= selectedNumber and stroke then
					stroke:Destroy()
				end
			end
			choiceText.Text = if selectedNumber
				then `선택: 🎯 {selectedNumber} · 💰 {comma(amount)}원 → 맞히면 {comma(amount * (selectedNumber + 1))}원!`
				else `선택: 💰 {comma(amount)}원 · 🎯 숫자를 골라 주세요`
			task.wait()
		end
	end)
	Sounds.play("swoosh", 0.4)
end

Remotes:WaitForChild("WheelOpen").OnClientEvent:Connect(showWheel)

---------------------------------------------------------------------------
-- 🎈 풍선 다트 (서버가 경품과 조준점 움직임을 정하고, 화면은 던진 시각만 보내요)
---------------------------------------------------------------------------
local function showDart()
	local W, H = 420, 300
	local frame = sheet(520, 560)
	line(frame, 0, 32, "🎈 풍선 다트", { Font = Enum.Font.GothamBlack, TextSize = 26 })
	line(frame, 34, 40, `{comma(SalaryConfig.DART_PRICE)}원에 다트 {SalaryConfig.DART_COUNT}개! 흔들리는 조준점이 풍선 위에 올 때 [던지기]\n풍선 속엔 꽝, 돈, 티켓, 인형… 아주 가끔 전설 인형도!`, {
		TextSize = 14,
		TextColor3 = MUTED,
	})
	local board = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 82),
		Size = UDim2.fromOffset(W, H),
		BackgroundColor3 = Color3.fromRGB(240, 230, 210),
		ZIndex = 31,
		Parent = frame,
	}, { Ui.corner(10), Ui.stroke(Color3.fromRGB(150, 110, 70), 3) })
	local colors = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 200, 60), Color3.fromRGB(90, 180, 255), Color3.fromRGB(120, 220, 120) }
	local balloons = {}
	local function resetBalloons()
		for _, b in balloons do
			b:Destroy()
		end
		table.clear(balloons)
		for row = 0, SalaryConfig.DART_ROWS - 1 do
			for col = 0, SalaryConfig.DART_COLS - 1 do
				local index = row * SalaryConfig.DART_COLS + col + 1
				balloons[index] = Ui.make("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale((col + 0.5) / SalaryConfig.DART_COLS, (row + 0.5) / SalaryConfig.DART_ROWS),
					Size = UDim2.fromOffset(SalaryConfig.DART_HIT_X * 2 * W, SalaryConfig.DART_HIT_Y * 2 * H),
					BackgroundColor3 = colors[(row + col) % #colors + 1],
					TextColor3 = Color3.fromRGB(40, 30, 30),
					Font = Enum.Font.GothamBold,
					TextScaled = true,
					Text = "",
					ZIndex = 32,
					Parent = board,
				}, { Ui.corner(40) })
			end
		end
	end
	resetBalloons()
	local crosshair = Ui.make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1,
		Text = "+",
		TextScaled = true,
		TextColor3 = Color3.fromRGB(220, 30, 30),
		Visible = false,
		ZIndex = 36,
		Parent = board,
	})
	local status = line(frame, 0, 40, "▶ 시작을 눌러 주세요!", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -62),
		TextSize = 17,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local function bigButton(x: number, text: string): TextButton
		return Ui.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, x, 1, 0),
			Size = UDim2.fromOffset(210, 52),
			Text = text,
			TextSize = 20,
			ZIndex = 31,
			Parent = frame,
		})
	end
	local startButton = bigButton(-110, `▶ 시작 ({comma(SalaryConfig.DART_PRICE)}원)`)
	local throwButton = bigButton(110, "🎯 던지기")
	local run: any = nil
	local throwing = false
	local PRIZE_EMOJI = { legend = "🌟" }
	for _, prize in SalaryConfig.DartPrizes do
		PRIZE_EMOJI[prize.id] = prize.emoji
	end

	startButton.Activated:Connect(function()
		if run or throwing then
			return
		end
		local result = Remotes.Dart:InvokeServer("start")
		if not result.ok then
			status.Text = result.message
			status.TextColor3 = RED
			return
		end
		resetBalloons()
		run = result
		crosshair.Visible = true
		throwButton.Text = `🎯 던지기 ({SalaryConfig.DART_COUNT})`
		status.Text = "조준점이 풍선 위에 올 때 던져요!"
		status.TextColor3 = INK
	end)

	throwButton.Activated:Connect(function()
		if not run or throwing then
			return
		end
		local now = workspace:GetServerTimeNow()
		if now < run.start then
			return
		end
		throwing = true
		Sounds.play("swoosh", 0.4, 1.3)
		local result = Remotes.Dart:InvokeServer("throw", now)
		throwing = false
		if not result.ok then
			status.Text = result.message
			status.TextColor3 = RED
			return
		end
		-- 다트 자국
		Ui.make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(result.x, result.y),
			Size = UDim2.fromOffset(22, 22),
			BackgroundTransparency = 1,
			Text = "📍",
			TextScaled = true,
			ZIndex = 37,
			Parent = board,
		})
		local balloon = result.balloon and balloons[result.balloon]
		if balloon then
			Sounds.play(if result.prizeId == "none" then "bass" else "ping", 0.6, 1.3)
			balloon.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			balloon.BackgroundTransparency = 0.3
			balloon.Text = PRIZE_EMOJI[result.prizeId] or "?"
			status.Text = `💥 펑! {result.prizeName}`
			status.TextColor3 = if result.prizeId == "none" then MUTED else Color3.fromRGB(40, 140, 70)
			if result.prizeId == "legend" then
				Hud.popup(`🎈 {result.prizeName}`, Color3.fromRGB(255, 210, 80), 3)
			end
		else
			status.Text = "빗나갔어요! 벽에 콕 😅"
			status.TextColor3 = RED
		end
		throwButton.Text = `🎯 던지기 ({result.left})`
		if result.left <= 0 then
			run = nil
			crosshair.Visible = false
			-- 남은 풍선 속 공개
			for index, prizeId in result.reveal or {} do
				local b = balloons[index]
				if b and b.Text == "" then
					b.Text = PRIZE_EMOJI[prizeId] or ""
					b.BackgroundTransparency = 0.6
				end
			end
			startButton.Text = `▶ 한 판 더 ({comma(SalaryConfig.DART_PRICE)}원)`
		end
	end)

	task.spawn(function()
		while current == frame do
			if run then
				local x, y = SalaryConfig.dartAim(math.max(0, workspace:GetServerTimeNow() - run.start), run.aim)
				crosshair.Position = UDim2.fromScale(x, y)
			end
			task.wait()
		end
	end)
	Sounds.play("swoosh", 0.4)
end

Remotes:WaitForChild("DartOpen").OnClientEvent:Connect(showDart)

---------------------------------------------------------------------------
-- 🧩 긴급 프로젝트 퍼즐 (타자·계산·기억·순서) — 문제와 정답은 서버에 있어요
---------------------------------------------------------------------------
local PUZZLE_KINDS = { typing = true, math = true, memory = true, order = true, quiz = true }

local function currentMissionStep()
	local mission = SalaryConfig.Missions[player:GetAttribute("MissionId") or ""]
	if not mission or player:GetAttribute("MissionStatus") ~= "active" then
		return nil
	end
	return mission.steps[player:GetAttribute("MissionStep") or 0]
end

function Panels.showPuzzle()
	local opened = Remotes.MissionPuzzle:InvokeServer("open")
	if not opened.ok then
		Ui.toast(opened.message)
		return
	end
	local kind = opened.kind
	local frame = sheet(520, if kind == "quiz" then 470 else 400)
	local titles = { typing = "⌨️ 보고서 타자", math = "🧮 엑셀 계산", memory = "🧠 주문번호 기억", order = "📊 슬라이드 순서", quiz = "🧠 퀴즈" }
	line(frame, 0, 32, titles[kind] or "🧩 퍼즐", { Font = Enum.Font.GothamBlack, TextSize = 26 })
	local info = line(frame, 36, 24, "", { TextSize = 15, TextColor3 = MUTED })
	local big = line(frame, 70, 70, "", { TextSize = 36, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Center })
	local status = line(frame, 0, 26, "", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -60),
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local function showResult(result)
		if not result.ok then
			status.Text = result.message
			status.TextColor3 = RED
			return false
		end
		if result.done then
			if result.correct then
				Sounds.play("ping", 0.7, 1.3)
				Ui.toast("🧩 통과! 다음 단계로")
			else
				Ui.toast(result.message)
			end
			close()
			return true
		end
		if result.correct == false then
			Sounds.play("bass", 0.4, 1.3)
			status.Text = result.message
			status.TextColor3 = RED
		elseif result.correct then
			Sounds.play("ping", 0.5, 1.2)
			status.Text = "✅ 정답!"
			status.TextColor3 = Color3.fromRGB(40, 140, 70)
		end
		return false
	end

	if kind == "typing" or kind == "math" or kind == "memory" then
		local box = Ui.make("TextBox", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 160),
			Size = UDim2.fromOffset(360, 50),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			TextColor3 = INK,
			Font = Enum.Font.GothamBold,
			TextSize = 24,
			PlaceholderText = if kind == "typing" then "위 문장을 똑같이 입력" else "숫자 입력",
			Text = "",
			ClearTextOnFocus = false,
			ZIndex = 32,
			Parent = frame,
		}, { Ui.corner(8), Ui.stroke(Color3.fromRGB(150, 150, 160), 2) })
		local submit = Ui.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.fromOffset(220, 50),
			Text = "제출 (Enter)",
			TextSize = 20,
			ZIndex = 31,
			Parent = frame,
		})
		local function show(data)
			if data.text then
				big.Text = data.text
				info.Text = `{data.index}/{data.total}`
			end
		end
		if kind == "typing" then
			info.Text = "오타 없이 똑같이 쳐요! (띄어쓰기도 똑같이)"
		elseif kind == "math" then
			info.Text = "하나라도 틀리면 새 문제로 처음부터!"
		end
		show(opened)
		local busy = false
		local function send()
			if busy then
				return
			end
			busy = true
			local result = Remotes.MissionPuzzle:InvokeServer("answer", box.Text)
			busy = false
			if showResult(result) then
				return
			end
			if result.ok then
				show(result)
				box.Text = ""
				box:CaptureFocus()
			end
		end
		submit.Activated:Connect(send)
		box.FocusLost:Connect(function(enter)
			if enter then
				send()
			end
		end)
		if kind == "memory" then
			-- 처음 몇 초만 번호를 보여 주고, 그 뒤엔 통화(일하기) 버티기 → 입력
			task.spawn(function()
				while current == frame do
					local left = (opened.showUntil or 0) - workspace:GetServerTimeNow()
					if opened.code and left > 0 then
						big.Text = opened.code
						info.Text = `📞 주문번호를 외워요! {math.ceil(left)}초`
						box.Visible = false
					else
						big.Text = "☎️ * * * * *"
						info.Text = `통화 중: [1] 일하기 상태로 버텨요! ({player:GetAttribute("MissionProgress") or ""})`
						box.Visible = true
					end
					task.wait(0.1)
				end
			end)
		else
			box:CaptureFocus()
		end
	elseif kind == "quiz" then
		-- 🧠 문제 + 보기 4개 (2×2). 틀리면 잠깐 잠기고 다른 문제로 바뀌어요
		info.Text = "천천히 생각해서 골라요! " .. SalaryConfig.QUIZ_MAX_WRONG .. "번 연속 틀리면 프로젝트 실패"
		big.Position = UDim2.fromOffset(0, 64)
		big.Size = UDim2.new(1, 0, 0, 156)
		big.TextSize = 22 -- (5줄짜리 문제도 들어가게)
		big.TextWrapped = true
		big.TextYAlignment = Enum.TextYAlignment.Center
		big.TextXAlignment = Enum.TextXAlignment.Center
		local data = opened
		local busy = false
		local choiceButtons: { TextButton } = {}
		local function render(newData)
			data = newData
			big.Text = data.text
			for i, b in choiceButtons do
				b.Text = data.choices[i] or ""
			end
		end
		for i = 1, 4 do
			local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
			local b = Ui.button({
				Position = UDim2.new(col * 0.5, if col == 0 then 0 else 6, 0, 226 + row * 70),
				Size = UDim2.new(0.5, -6, 0, 60),
				Text = "",
				TextSize = 22,
				ZIndex = 32,
				Parent = frame,
			})
			b.Activated:Connect(function()
				if busy or workspace:GetServerTimeNow() < (data.lockUntil or 0) then
					return
				end
				busy = true
				Sounds.play("click", 0.4)
				local result = Remotes.MissionPuzzle:InvokeServer("answer", i)
				busy = false
				if showResult(result) then
					return
				end
				if result.ok and result.text then
					render(result)
				end
			end)
			table.insert(choiceButtons, b)
		end
		render(opened)
		-- 🔒 잠긴 동안엔 보기를 흐리게 + 남은 초
		task.spawn(function()
			while current == frame do
				local left = (data.lockUntil or 0) - workspace:GetServerTimeNow()
				for _, b in choiceButtons do
					b.AutoButtonColor = left <= 0
					b.BackgroundTransparency = if left > 0 then 0.6 else 0
				end
				if left > 0 then
					status.Text = `🔒 {math.ceil(left)}초 뒤에 새 문제를 풀 수 있어요`
					status.TextColor3 = RED
				elseif status.Text:sub(1, 4) == "🔒" then
					status.Text = ""
				end
				task.wait(0.1)
			end
		end)
	elseif kind == "order" then
		info.Text = "슬라이드 1번부터 6번까지 순서대로 눌러요!"
		local clicked = {}
		local buttons = {}
		local function render(numbers)
			for _, b in buttons do
				b:Destroy()
			end
			table.clear(buttons)
			table.clear(clicked)
			for i, n in numbers do
				local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
				local b = Ui.button({
					Position = UDim2.new(0, col * 160 + 10, 0, 90 + row * 90),
					Size = UDim2.fromOffset(140, 80),
					Text = `📊 {n}`,
					TextSize = 28,
					ZIndex = 32,
					Parent = frame,
				})
				b.Activated:Connect(function()
					if table.find(clicked, n) then
						return
					end
					table.insert(clicked, n)
					b.BackgroundColor3 = Color3.fromRGB(150, 220, 150)
					Sounds.play("click", 0.4)
					if #clicked == #numbers then
						local result = Remotes.MissionPuzzle:InvokeServer("answer", clicked)
						if showResult(result) then
							return
						end
						if result.numbers then
							render(result.numbers)
						end
					end
				end)
				table.insert(buttons, b)
			end
		end
		render(opened.numbers)
	end
	Sounds.play("swoosh", 0.4)
end

---------------------------------------------------------------------------
-- 💣 폰 게임: 지뢰 피하기 (화면 오른쪽에 작게 → 가운데로 부장님이 오는지 볼 수 있어요)
--   창이 열려 있는 동안 = 📱 폰 게임 농땡이. 닫으면 (게임 중이면 자동 스톱) 일하기로 복귀
---------------------------------------------------------------------------
local GREEN = Color3.fromRGB(40, 140, 70)

-- 📱 [폰 게임] 농땡이가 서버에 반영될 때까지 잠깐 기다려요 (바로 시작하면 "폰 게임 중일 때만…"이 떴어요)
local function waitForPhone(timeout: number): boolean
	local finish = os.clock() + timeout
	while os.clock() < finish do
		if player:GetAttribute("SalaryAction") == "phone" then
			return true
		end
		task.wait(0.1)
	end
	return player:GetAttribute("SalaryAction") == "phone"
end

local minesOnForfeit: ((mines: { number }, lost: number, payout: number?) -> ())? = nil

function Panels.showMines()
	Remotes.SetAction:FireServer("phone") -- 📱 게임을 골랐으니 이제 농땡이 시작!
	local frame = sheet(380, 560)
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.Position = UDim2.new(1, -20, 0.5, 0)
	line(frame, 0, 30, "💣 지뢰 피하기", { Font = Enum.Font.GothamBlack, TextSize = 24 })
	local info = line(frame, 32, 22, "빈칸을 열수록 받을 돈 ⬆️ · 지뢰를 밟으면 건 돈을 잃어요", { TextSize = 13, TextColor3 = MUTED })

	local bet = SalaryConfig.MINES_BETS[1]
	local mines = SalaryConfig.MINES_COUNTS[2] or SalaryConfig.MINES_COUNTS[1]
	local playing = false
	local busy = false
	local total = 0
	local money: TextLabel -- (아래에서 만들어요. 버튼들이 먼저 참조해서 미리 선언)

	-- 💰 금액 / 💣 지뢰 수 고르기 (하나만 선택)
	local betButtons, mineButtons = {}, {}
	local function paintChoices()
		local rank = player:GetAttribute("Rank") or 1
		for value, b in betButtons do
			local needRank = SalaryConfig.MINES_BET_RANK[value] or 1
			local locked = rank < needRank
			b.Text = if locked then `🔒 {SalaryConfig.Ranks[needRank].name}` else `{comma(value)}원`
			b.BackgroundColor3 = if locked
				then Color3.fromRGB(160, 160, 165)
				elseif value == bet then Color3.fromRGB(255, 200, 80)
				else Color3.fromRGB(215, 215, 220)
			b.AutoButtonColor = not playing and not locked
		end
		for value, b in mineButtons do
			b.BackgroundColor3 = if value == mines then Color3.fromRGB(240, 120, 110) else Color3.fromRGB(215, 215, 220)
			b.AutoButtonColor = not playing
		end
	end
	for i, value in SalaryConfig.MINES_BETS do
		local b = Ui.button({
			Position = UDim2.fromOffset((i - 1) * 86, 60),
			Size = UDim2.fromOffset(80, 34),
			Text = `{comma(value)}원`,
			TextSize = 15,
			ZIndex = 31,
			Parent = frame,
		})
		b.Activated:Connect(function()
			if playing then
				return
			end
			local needRank = SalaryConfig.MINES_BET_RANK[value] or 1
			if (player:GetAttribute("Rank") or 1) < needRank then
				money.Text = `🔒 {comma(value)}원은 {SalaryConfig.Ranks[needRank].name}부터 걸 수 있어요`
				money.TextColor3 = RED
				Sounds.play("bass", 0.3, 1.2)
				return
			end
			bet = value
			paintChoices()
			Sounds.play("click", 0.3)
		end)
		betButtons[value] = b
	end
	for i, value in SalaryConfig.MINES_COUNTS do
		local b = Ui.button({
			Position = UDim2.fromOffset((i - 1) * 86, 100),
			Size = UDim2.fromOffset(80, 34),
			Text = `💣 {value}개`,
			TextSize = 15,
			ZIndex = 31,
			Parent = frame,
		})
		b.Activated:Connect(function()
			if not playing then
				mines = value
				paintChoices()
				Sounds.play("click", 0.3)
			end
		end)
		mineButtons[value] = b
	end

	money = line(frame, 438, 26, "", { TextSize = 16, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center })
	local mainButton: TextButton

	-- 5×5 칸
	local GRID = SalaryConfig.MINES_GRID
	local CELL_W, CELL_H, GAP = 62, 52, 5
	local cells: { TextButton } = {}
	local function resetCells()
		for _, cell in cells do
			cell.Text = "❔"
			cell.BackgroundColor3 = Color3.fromRGB(70, 80, 100)
			cell.TextColor3 = Color3.new(1, 1, 1)
		end
	end
	local function showMines(list: { number }, boomIndex: number?)
		for _, index in list do
			local cell = cells[index]
			if cell then
				cell.Text = if index == boomIndex then "💥" else "💣"
				cell.BackgroundColor3 = if index == boomIndex then Color3.fromRGB(220, 60, 50) else Color3.fromRGB(150, 70, 70)
			end
		end
	end
	local function refreshButton()
		if playing then
			mainButton.Text = `✋ 스톱 ({comma(total)}원 받기)`
			mainButton.BackgroundColor3 = Color3.fromRGB(90, 190, 110)
		else
			mainButton.Text = `▶ 시작 ({comma(bet)}원 · 💣 {mines}개)`
			mainButton.BackgroundColor3 = Color3.fromRGB(255, 200, 80)
		end
		paintChoices()
	end
	local function finish(message: string, color: Color3)
		playing = false
		money.Text = message
		money.TextColor3 = color
		refreshButton()
	end

	for i = 1, GRID * GRID do
		local col, row = (i - 1) % GRID, math.floor((i - 1) / GRID)
		local cell = Ui.button({
			Position = UDim2.fromOffset(col * (CELL_W + GAP), 146 + row * (CELL_H + GAP)),
			Size = UDim2.fromOffset(CELL_W, CELL_H),
			Text = "❔",
			TextSize = 15,
			TextWrapped = true,
			ZIndex = 31,
			Parent = frame,
		})
		cell.Activated:Connect(function()
			if not playing or busy or cell.Text ~= "❔" then
				return
			end
			busy = true
			local result = Remotes.MinesPlay:InvokeServer("open", i)
			busy = false
			if current ~= frame then
				return
			end
			if not result.ok then
				money.Text = result.message
				money.TextColor3 = RED
				return
			end
			if result.boom then
				Sounds.play("caught", 0.6, 0.8)
				showMines(result.mines, i)
				finish(`💥 지뢰! -{comma(result.lost)}원`, RED)
				return
			end
			-- 빈칸: 이 칸에서 늘어난 돈을 보여 줘요
			Sounds.play("ping", 0.4, 1 + math.min(result.count, 20) * 0.04)
			cell.Text = `+{comma(result.gain)}`
			cell.BackgroundColor3 = Color3.fromRGB(90, 190, 110)
			total = result.total
			if result.done then
				showMines(result.mines or {})
				Sounds.play("ping", 0.8, 1.5)
				finish(`🎉 {result.reason} +{comma(result.payout)}원 (x{string.format("%.2f", result.multiplier)})`, GREEN)
				return
			end
			money.Text = `💰 스톱하면 {comma(total)}원 (x{string.format("%.2f", result.multiplier)}) · 다음 칸 +{comma(result.nextGain)}원`
			money.TextColor3 = INK
			refreshButton()
		end)
		cells[i] = cell
	end

	mainButton = Ui.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 48),
		Text = "",
		TextSize = 18,
		ZIndex = 31,
		Parent = frame,
	})
	mainButton.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		if playing then
			local result = Remotes.MinesPlay:InvokeServer("stop")
			busy = false
			if current ~= frame then
				return
			end
			if result.ok then
				showMines(result.mines or {})
				Sounds.play("ping", 0.6, 1.3)
				finish(`✋ 스톱! +{comma(result.payout)}원 받았어요`, GREEN)
			else
				money.Text = result.message
				money.TextColor3 = RED
			end
		else
			local result = Remotes.MinesPlay:InvokeServer("start", bet, mines)
			busy = false
			if current ~= frame then
				return
			end
			if result.ok then
				resetCells()
				playing = true
				total = result.total
				Sounds.play("swoosh", 0.4)
				money.Text = `💰 지금 스톱하면 {comma(total)}원 · 첫 칸 +{comma(result.nextGain)}원`
				money.TextColor3 = INK
				refreshButton()
			else
				money.Text = result.message
				money.TextColor3 = RED
			end
		end
	end)

	-- 📵 적발·다른 행동 등으로 폰 게임이 꺼지면 판이 날아가요
	minesOnForfeit = function(list: { number }, lost: number, payout: number?)
		if current ~= frame then
			return
		end
		showMines(list)
		if payout then
			finish(`✋ 일하기로 복귀! 자동 스톱 +{comma(payout)}원`, GREEN)
		else
			finish(`📵 폰 게임이 꺼졌어요… -{comma(lost)}원`, RED)
		end
	end

	resetCells()
	refreshButton()
	money.Text = "💰 금액과 💣 지뢰 수를 고르고 [시작]!"
	money.TextColor3 = MUTED
	local _ = info
	Sounds.play("swoosh", 0.4)

	-- 창이 닫히면: 게임 중이었으면 자동 스톱 → 아직 폰 게임 중이면 일하기로 복귀
	task.spawn(function()
		local openedAt = os.clock()
		while current == frame do
			-- 폰 게임 농땡이가 아니게 되면 (적발·다른 행동·자리 이탈) 창도 닫아요
			if os.clock() - openedAt > 3.5 and player:GetAttribute("SalaryAction") ~= "phone" then
				task.wait(1.5) -- (📵 메시지를 잠깐 보여 주고)
				if current == frame then
					close()
				end
				break
			end
			task.wait(0.2)
		end
		if playing then
			playing = false
			Remotes.MinesPlay:InvokeServer("stop")
		end
		if player:GetAttribute("SalaryAction") == "phone" then
			Remotes.SetAction:FireServer("work")
		end
	end)
end

Remotes:WaitForChild("MinesForfeit").OnClientEvent:Connect(function(list: { number }, lost: number, payout: number?)
	if minesOnForfeit then
		minesOnForfeit(list, lost, payout)
	end
	if payout then
		Ui.toast(`✋ 일하기로 복귀하면서 💣 지뢰 피하기 자동 스톱 · +{comma(payout)}원`)
	else
		Ui.toast(`📵 폰 게임이 꺼져서 건 돈 {comma(lost)}원을 잃었어요`)
	end
end)

---------------------------------------------------------------------------
-- 🧩 폰 게임: 도형 맞추기 (화면 오른쪽에 작게)
--   조각을 고르고 → 판의 칸을 누르면 조각의 맨 위 왼쪽 칸이 거기에 놓여요 (조각은 돌릴 수 없어요)
--   놓인 조각을 누르면 다시 집어요. 모두 채우면 자동 제출!
---------------------------------------------------------------------------
local PIECE_COLORS = {
	Color3.fromRGB(240, 110, 100),
	Color3.fromRGB(110, 170, 240),
	Color3.fromRGB(120, 200, 120),
	Color3.fromRGB(245, 195, 80),
	Color3.fromRGB(190, 130, 230),
	Color3.fromRGB(90, 200, 200),
	Color3.fromRGB(240, 150, 200),
}

function Panels.showShapes()
	Remotes.SetAction:FireServer("phone") -- 📱 게임을 골랐으니 이제 농땡이 시작!
	local frame = sheet(400, 610)
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.Position = UDim2.new(1, -20, 0.5, 0)
	local title = line(frame, 0, 30, "🧩 도형 맞추기", { Font = Enum.Font.GothamBlack, TextSize = 24 })
	local timerText = line(frame, 32, 22, "", { TextSize = 14, Font = Enum.Font.GothamBold })
	local message = line(frame, 0, 24, "", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -54),
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	local INNER_W = 360
	local CELL, GAP = 40, 3
	local MINI = 12
	local boardHolder = Ui.make("Frame", { Position = UDim2.fromOffset(0, 60), Size = UDim2.fromOffset(INNER_W, 6 * (CELL + GAP)), BackgroundTransparency = 1, ZIndex = 31, Parent = frame })
	local tray = Ui.make("Frame", { Position = UDim2.fromOffset(0, 60 + 6 * (CELL + GAP) + 8), Size = UDim2.fromOffset(INNER_W, 160), BackgroundTransparency = 1, ZIndex = 31, Parent = frame })

	-- 상태
	local boardSet: { [string]: boolean } = {}
	local boardCells: { [string]: TextButton } = {}
	local pieces: { { { number } } } = {} -- 지금 돌린 모양
	local placed: { [number]: { { number } }? } = {} -- 조각 번호 → 판 위 칸들
	local occupant: { [string]: number } = {} -- 칸 → 조각 번호
	local selected: number? = nil
	local hover: { number }? = nil
	local playing = false
	local busy = false
	local endsAt = 0
	local trayButtons: { TextButton } = {}

	local function cellKey(x: number, y: number): string
		return `{x},{y}`
	end
	local function cellsAt(pieceIndex: number, anchor: { number }): { { number } }
		-- 조각의 맨 위 왼쪽 칸(정렬 첫 칸)이 anchor에 오도록
		local shape = pieces[pieceIndex]
		local first = shape[1]
		local out = {}
		for _, c in shape do
			table.insert(out, { anchor[1] + c[1] - first[1], anchor[2] + c[2] - first[2] })
		end
		return out
	end
	local function fits(pieceIndex: number, cells: { { number } }): boolean
		for _, c in cells do
			local k = cellKey(c[1], c[2])
			if not boardSet[k] or (occupant[k] and occupant[k] ~= pieceIndex) then
				return false
			end
		end
		return true
	end

	local function paintBoard()
		for k, cell in boardCells do
			local owner = occupant[k]
			cell.BackgroundColor3 = if owner then PIECE_COLORS[(owner - 1) % #PIECE_COLORS + 1] else Color3.fromRGB(215, 215, 222)
			cell.Text = ""
		end
		-- 고른 조각을 마우스 위치에 미리 보여 줘요 (초록 = 놓을 수 있음, 빨강 = 안 됨)
		if playing and selected and hover then
			local cells = cellsAt(selected, hover)
			local ok = fits(selected, cells)
			for _, c in cells do
				local cell = boardCells[cellKey(c[1], c[2])]
				if cell and not occupant[cellKey(c[1], c[2])] then
					cell.BackgroundColor3 = if ok then Color3.fromRGB(150, 225, 150) else Color3.fromRGB(240, 150, 140)
				end
			end
		end
	end

	local function paintTray()
		for i, b in trayButtons do
			b.Visible = placed[i] == nil
			local stroke = b:FindFirstChild("PickStroke") :: UIStroke?
			if stroke then
				stroke.Enabled = selected == i
			end
			-- 조각 모양 다시 그리기 (돌리면 바뀌어요)
			local mini = b:FindFirstChild("Mini")
			if mini then
				mini:ClearAllChildren()
				local maxX, maxY = 0, 0
				for _, c in pieces[i] do
					maxX, maxY = math.max(maxX, c[1]), math.max(maxY, c[2])
				end
				local offsetX = (80 - (maxX + 1) * (MINI + 1)) / 2
				local offsetY = (66 - (maxY + 1) * (MINI + 1)) / 2
				for _, c in pieces[i] do
					Ui.make("Frame", {
						Position = UDim2.fromOffset(offsetX + c[1] * (MINI + 1), offsetY + c[2] * (MINI + 1)),
						Size = UDim2.fromOffset(MINI, MINI),
						BackgroundColor3 = PIECE_COLORS[(i - 1) % #PIECE_COLORS + 1],
						BorderSizePixel = 0,
						ZIndex = 33,
						Parent = mini,
					})
				end
			end
		end
	end


	local function pickUp(pieceIndex: number)
		local cells = placed[pieceIndex]
		if cells then
			for _, c in cells do
				occupant[cellKey(c[1], c[2])] = nil
			end
			placed[pieceIndex] = nil
		end
		selected = pieceIndex
		paintTray()
		paintBoard()
	end

	local function submit()
		busy = true
		local list = {}
		for i = 1, #pieces do
			list[i] = placed[i]
		end
		local result = Remotes.ShapesPlay:InvokeServer("submit", list)
		busy = false
		if current ~= frame then
			return
		end
		if not result.ok then
			message.Text = result.message
			message.TextColor3 = RED
			return
		end
		playing = false
		if result.solved then
			Sounds.play("ping", 0.8, 1.5)
			if result.prize > 0 then
				message.Text = `🎉 성공! {result.seconds}초 · 상금 +{comma(result.prize)}원 (오늘 {result.prizesLeft}번 더)`
			else
				message.Text = `🎉 성공! {result.seconds}초 · (오늘 상금은 다 받았어요)`
			end
			message.TextColor3 = Color3.fromRGB(40, 140, 70)
		else
			message.Text = result.message
			message.TextColor3 = RED
		end
	end

	local function placeAt(anchor: { number })
		if not playing or busy then
			return
		end
		local k = cellKey(anchor[1], anchor[2])
		if not selected then
			-- 놓인 조각을 누르면 다시 집어요
			if occupant[k] then
				pickUp(occupant[k])
				Sounds.play("click", 0.3, 0.9)
			end
			return
		end
		local cells = cellsAt(selected, anchor)
		if not fits(selected, cells) then
			if occupant[k] then
				pickUp(occupant[k]) -- 다른 조각 위를 누르면 그 조각으로 바꿔 들어요
			else
				Sounds.play("bass", 0.3, 1.4)
			end
			return
		end
		for _, c in cells do
			occupant[cellKey(c[1], c[2])] = selected
		end
		placed[selected] = cells
		Sounds.play("click", 0.4, 1.1)
		-- 다음 안 놓은 조각을 자동으로 골라요
		selected = nil
		for i = 1, #pieces do
			if not placed[i] then
				selected = i
				break
			end
		end
		paintTray()
		paintBoard()
		if not selected then
			submit() -- 다 놓았어요!
		end
	end

	local mainButton: TextButton
	local function startPuzzle()
		local result = Remotes.ShapesPlay:InvokeServer("start")
		if current ~= frame then
			return
		end
		if not result.ok then
			message.Text = result.message
			message.TextColor3 = RED
			return
		end
		-- 판 다시 그리기
		boardHolder:ClearAllChildren()
		for _, b in trayButtons do
			b:Destroy()
		end
		table.clear(trayButtons)
		table.clear(boardSet)
		table.clear(boardCells)
		table.clear(occupant)
		table.clear(placed)
		pieces = result.pieces
		local maxX, maxY = 0, 0
		for _, c in result.board do
			maxX, maxY = math.max(maxX, c[1]), math.max(maxY, c[2])
		end
		local offsetX = (INNER_W - (maxX + 1) * (CELL + GAP)) / 2
		for _, c in result.board do
			local x, y = c[1], c[2]
			local k = cellKey(x, y)
			boardSet[k] = true
			local cell = Ui.make("TextButton", {
				Position = UDim2.fromOffset(offsetX + x * (CELL + GAP), y * (CELL + GAP)),
				Size = UDim2.fromOffset(CELL, CELL),
				BackgroundColor3 = Color3.fromRGB(215, 215, 222),
				AutoButtonColor = false,
				Text = "",
				ZIndex = 32,
				Parent = boardHolder,
			}, { Ui.corner(5) })
			cell.MouseEnter:Connect(function()
				hover = { x, y }
				paintBoard()
			end)
			cell.MouseLeave:Connect(function()
				if hover and hover[1] == x and hover[2] == y then
					hover = nil
					paintBoard()
				end
			end)
			cell.Activated:Connect(function()
				placeAt({ x, y })
			end)
			boardCells[k] = cell
		end
		-- 조각 보관함 (한 줄에 4개)
		for i = 1, #pieces do
			local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
			local b = Ui.make("TextButton", {
				Position = UDim2.fromOffset(col * 90, row * 76),
				Size = UDim2.fromOffset(80, 66),
				BackgroundColor3 = Color3.fromRGB(240, 240, 244),
				AutoButtonColor = true,
				Text = "",
				ZIndex = 32,
				Parent = tray,
			}, {
				Ui.corner(8),
				Ui.make("UIStroke", { Name = "PickStroke", ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(40, 40, 50), Thickness = 3, Enabled = false }),
				Ui.make("Frame", { Name = "Mini", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 33 }),
			})
			b.Activated:Connect(function()
				if playing and selected ~= i then
					selected = i
					Sounds.play("click", 0.3)
					paintTray()
					paintBoard()
				end
			end)
			trayButtons[i] = b
		end
		selected = 1
		hover = nil
		playing = true
		endsAt = result.endsAt
		title.Text = `🧩 도형 맞추기 · {result.name}`
		message.Text = "조각 고르기 → 판에 놓기 (조각은 돌릴 수 없어요 · 놓은 조각을 누르면 다시 집어요)"
		message.TextColor3 = MUTED
		Sounds.play("swoosh", 0.4)
		paintTray()
		paintBoard()
	end

	-- 아래 버튼: ↩️ 다 빼기 / ▶ 새 퍼즐
	local resetButton = Ui.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(0.5, -5, 0, 46),
		Text = "↩️ 다 빼기",
		TextSize = 17,
		ZIndex = 31,
		Parent = frame,
	})
	resetButton.Activated:Connect(function()
		if not playing or busy then
			return
		end
		table.clear(occupant)
		table.clear(placed)
		selected = 1
		Sounds.play("swoosh", 0.3)
		paintTray()
		paintBoard()
	end)
	mainButton = Ui.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.new(0.5, -5, 0, 46),
		Text = "▶ 새 퍼즐",
		TextSize = 17,
		ZIndex = 31,
		Parent = frame,
	})
	mainButton.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		startPuzzle()
		busy = false
	end)

	message.Text = "📱 폰 켜는 중…"
	message.TextColor3 = MUTED
	task.spawn(function()
		if waitForPhone(3) and current == frame and not playing then
			busy = true
			startPuzzle()
			busy = false
		elseif current == frame then
			message.Text = "🪑 내 자리에 앉아서 [📱 폰 게임]을 골라 주세요"
			message.TextColor3 = RED
		end
	end)

	-- ⏱️ 타이머 + 창이 닫히면 정리 (폰 게임 농땡이가 끝나면 창도 닫혀요)
	task.spawn(function()
		local openedAt = os.clock() + 2 -- (폰 켜는 시간 여유)
		while current == frame do
			if playing then
				local left = math.max(0, endsAt - workspace:GetServerTimeNow())
				local prizeNow = #pieces * SalaryConfig.SHAPES_PRIZE_PER_PIECE + math.floor(left) * SalaryConfig.SHAPES_PRIZE_PER_SECOND
				timerText.Text = `⏱️ {math.ceil(left)}초 남음 · 지금 성공하면 +{comma(prizeNow)}원`
				timerText.TextColor3 = if left < 15 then RED else INK
				if left <= 0 then
					playing = false
					message.Text = "⏰ 시간 초과! [▶ 새 퍼즐]로 다시 도전"
					message.TextColor3 = RED
					Remotes.ShapesPlay:InvokeServer("quit")
				end
			else
				timerText.Text = ""
			end
			if os.clock() - openedAt > 1.5 and player:GetAttribute("SalaryAction") ~= "phone" then
				task.wait(0.5)
				if current == frame then
					close()
				end
				break
			end
			task.wait(0.1)
		end
		if playing then
			Remotes.ShapesPlay:InvokeServer("quit")
		end
		if player:GetAttribute("SalaryAction") == "phone" then
			Remotes.SetAction:FireServer("work")
		end
	end)
end

---------------------------------------------------------------------------
-- ⚾ 폰 게임: 숫자 야구 (화면 오른쪽에 작게)
--   숫자 버튼(또는 키보드 1~9) → [확인](Enter) · 지우기(Backspace)
---------------------------------------------------------------------------
local DIGIT_KEYS = {
	[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4, [Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8, [Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.KeypadOne] = 1, [Enum.KeyCode.KeypadTwo] = 2, [Enum.KeyCode.KeypadThree] = 3,
	[Enum.KeyCode.KeypadFour] = 4, [Enum.KeyCode.KeypadFive] = 5, [Enum.KeyCode.KeypadSix] = 6,
	[Enum.KeyCode.KeypadSeven] = 7, [Enum.KeyCode.KeypadEight] = 8, [Enum.KeyCode.KeypadNine] = 9,
}

function Panels.showBaseball()
	Remotes.SetAction:FireServer("phone") -- 📱 게임을 골랐으니 이제 농땡이 시작!
	local frame = sheet(360, 600)
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.Position = UDim2.new(1, -20, 0.5, 0)
	Hud.numberGame = true -- (숫자 키를 책상 행동 단축키 대신 여기서 써요)
	local DIGITS = SalaryConfig.BASEBALL_DIGITS
	local MAX = SalaryConfig.BASEBALL_MAX_TRIES
	local INNER_W = 320

	line(frame, 0, 30, "⚾ 숫자 야구", { Font = Enum.Font.GothamBlack, TextSize = 24 })
	local info = line(frame, 32, 20, "", { TextSize = 13, TextColor3 = MUTED })

	-- 입력 칸
	local slots: { TextLabel } = {}
	local slotW = 56
	local slotsX = (INNER_W - (DIGITS * slotW + (DIGITS - 1) * 8)) / 2
	for i = 1, DIGITS do
		slots[i] = Ui.make("TextLabel", {
			Position = UDim2.fromOffset(slotsX + (i - 1) * (slotW + 8), 56),
			Size = UDim2.fromOffset(slotW, 54),
			BackgroundColor3 = Color3.fromRGB(235, 235, 240),
			TextColor3 = INK,
			Font = Enum.Font.GothamBlack,
			TextSize = 30,
			Text = "",
			ZIndex = 31,
			Parent = frame,
		}, { Ui.corner(8), Ui.make("UIStroke", { Color = Color3.fromRGB(150, 150, 160), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
	end
	local message = line(frame, 116, 20, "", { TextSize = 13, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center })

	local input: { number } = {}
	local history: { TextLabel } = {}
	local playing = false
	local busy = false
	local tries = 0
	local digitButtons: { [number]: TextButton } = {}

	local function refresh()
		for i = 1, DIGITS do
			slots[i].Text = if input[i] then tostring(input[i]) else ""
		end
		for n, b in digitButtons do
			local used = table.find(input, n) ~= nil
			b.BackgroundColor3 = if used then Color3.fromRGB(190, 190, 195) else Color3.fromRGB(70, 80, 100)
			b.TextColor3 = if used then Color3.fromRGB(120, 120, 125) else Color3.new(1, 1, 1)
		end
		local prize = SalaryConfig.BaseballPrizes[tries + 1] or 0
		info.Text = if playing
			then `1~9 서로 다른 숫자 {DIGITS}개 · {tries}/{MAX}번째 · 다음에 맞히면 +{comma(prize)}원`
			else `1~9 서로 다른 숫자 {DIGITS}개를 {MAX}번 안에 맞혀요`
	end

	local function addHistory(text: string, color: Color3)
		local label = line(frame, 326 + #history * 19, 19, text, { TextSize = 14, Font = Enum.Font.GothamBold, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Center })
		table.insert(history, label)
	end

	local mainButton: TextButton
	local function setMain(text: string)
		mainButton.Text = text
	end

	local function startGame()
		local result = Remotes.BaseballPlay:InvokeServer("start")
		if current ~= frame then
			return
		end
		if not result.ok then
			message.Text = result.message
			message.TextColor3 = RED
			return
		end
		for _, label in history do
			label:Destroy()
		end
		table.clear(history)
		table.clear(input)
		tries = 0
		playing = true
		message.Text = "⚾ 스트라이크: 숫자·자리 맞음 · 🟢 볼: 숫자만 맞음"
		message.TextColor3 = MUTED
		setMain("✅ 확인 (Enter)")
		Sounds.play("swoosh", 0.4)
		refresh()
	end

	local function submit()
		if busy then
			return
		end
		if not playing then
			busy = true
			startGame()
			busy = false
			return
		end
		if #input < DIGITS then
			message.Text = `숫자 {DIGITS}개를 골라 주세요`
			message.TextColor3 = RED
			return
		end
		local guess = ""
		for _, n in input do
			guess ..= tostring(n)
		end
		busy = true
		local result = Remotes.BaseballPlay:InvokeServer("guess", guess)
		busy = false
		if current ~= frame then
			return
		end
		if not result.ok then
			message.Text = result.message
			message.TextColor3 = RED
			return
		end
		tries = result.tries
		table.clear(input)
		local hint = if result.strikes == 0 and result.balls == 0
			then "❌ 아웃"
			else `⚾ {result.strikes}스트라이크  🟢 {result.balls}볼`
		if result.solved then
			addHistory(`{result.tries}.  {result.guess}  →  🎉 홈런!`, Color3.fromRGB(40, 140, 70))
			playing = false
			Sounds.play("ping", 0.8, 1.5)
			message.Text = if result.prize > 0
				then `🎉 {result.tries}번 만에 정답! +{comma(result.prize)}원 (오늘 {result.prizesLeft}번 더)`
				else `🎉 {result.tries}번 만에 정답! (오늘 상금은 다 받았어요)`
			message.TextColor3 = Color3.fromRGB(40, 140, 70)
			setMain("▶ 새 게임 (Enter)")
		else
			addHistory(`{result.tries}.  {result.guess}  →  {hint}`, INK)
			Sounds.play("click", 0.4, if result.strikes > 0 then 1.3 else 0.9)
			if result.failed then
				playing = false
				Sounds.play("bass", 0.5, 1)
				message.Text = `😢 기회를 다 썼어요. 정답은 {result.answer}`
				message.TextColor3 = RED
				setMain("▶ 새 게임 (Enter)")
			end
		end
		refresh()
	end

	local function press(n: number)
		if not playing or #input >= DIGITS or table.find(input, n) then
			return
		end
		table.insert(input, n)
		Sounds.play("click", 0.3, 1 + n * 0.03)
		refresh()
	end
	local function backspace()
		if playing and #input > 0 then
			table.remove(input)
			refresh()
		end
	end

	-- 숫자 패드 (3×3) + 지우기
	local KEY_W, KEY_H, KEY_GAP = 72, 40, 6
	local padX = (INNER_W - (3 * KEY_W + 2 * KEY_GAP)) / 2
	for n = 1, 9 do
		local col, row = (n - 1) % 3, math.floor((n - 1) / 3)
		local b = Ui.button({
			Position = UDim2.fromOffset(padX + col * (KEY_W + KEY_GAP), 140 + row * (KEY_H + KEY_GAP)),
			Size = UDim2.fromOffset(KEY_W, KEY_H),
			Text = tostring(n),
			TextSize = 20,
			ZIndex = 31,
			Parent = frame,
		})
		b.Activated:Connect(function()
			press(n)
		end)
		digitButtons[n] = b
	end
	local eraseButton = Ui.button({
		Position = UDim2.fromOffset(padX, 140 + 3 * (KEY_H + KEY_GAP)),
		Size = UDim2.fromOffset(3 * KEY_W + 2 * KEY_GAP, KEY_H),
		Text = "⬅️ 지우기 (Backspace)",
		TextSize = 15,
		ZIndex = 31,
		Parent = frame,
	})
	eraseButton.Activated:Connect(backspace)

	mainButton = Ui.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 46),
		Text = "",
		TextSize = 18,
		ZIndex = 31,
		Parent = frame,
	})
	mainButton.Activated:Connect(submit)

	local keyConnection = UserInputService.InputBegan:Connect(function(input2, gameProcessed)
		if gameProcessed or current ~= frame then
			return
		end
		local n = DIGIT_KEYS[input2.KeyCode]
		if n then
			press(n)
		elseif input2.KeyCode == Enum.KeyCode.Backspace then
			backspace()
		elseif input2.KeyCode == Enum.KeyCode.Return or input2.KeyCode == Enum.KeyCode.KeypadEnter then
			submit()
		end
	end)

	setMain("▶ 새 게임 (Enter)")
	message.Text = "📱 폰 켜는 중…"
	message.TextColor3 = MUTED
	refresh()
	task.spawn(function()
		if waitForPhone(3) and current == frame and not playing then
			busy = true
			startGame()
			busy = false
		elseif current == frame then
			message.Text = "🪑 내 자리에 앉아서 [📱 폰 게임]을 골라 주세요"
			message.TextColor3 = RED
		end
	end)

	-- 창이 닫히면 정리 (폰 게임 농땡이가 끝나면 창도 닫혀요)
	task.spawn(function()
		local openedAt = os.clock()
		while current == frame do
			if os.clock() - openedAt > 3.5 and player:GetAttribute("SalaryAction") ~= "phone" then
				task.wait(0.5)
				if current == frame then
					close()
				end
				break
			end
			task.wait(0.2)
		end
		keyConnection:Disconnect()
		Hud.numberGame = false
		if playing then
			Remotes.BaseballPlay:InvokeServer("quit")
		end
		if player:GetAttribute("SalaryAction") == "phone" then
			Remotes.SetAction:FireServer("work")
		end
	end)
end

Hud.onPhoneGame = function(gameId: string)
	if gameId == "mines" then
		Panels.showMines()
	elseif gameId == "shapes" then
		Panels.showShapes()
	elseif gameId == "baseball" then
		Panels.showBaseball()
	end
end

-- 📋 프로젝트 카드의 "🧩 풀기" 버튼 (퍼즐 단계일 때만)
local puzzleButton = Ui.button({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, 4),
	Size = UDim2.fromOffset(150, 36),
	Text = "🧩 풀기",
	TextSize = 18,
	Visible = false,
	Parent = Hud.missionPanel,
})
puzzleButton.Activated:Connect(function()
	if current then
		close()
	end
	Panels.showPuzzle()
end)
task.spawn(function()
	while true do
		local step = currentMissionStep()
		puzzleButton.Visible = step ~= nil and PUZZLE_KINDS[step.kind] == true
		task.wait(0.3)
	end
end)

-- 새 날이 시작되면 열려 있던 창은 자동으로 닫아요
ReplicatedStorage:GetAttributeChangedSignal("SalaryPhase"):Connect(function()
	if ReplicatedStorage:GetAttribute("SalaryPhase") == "work" and current then
		close()
	end
end)

return Panels
