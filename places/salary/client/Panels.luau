-- 가운데 뜨는 창: 입사 안내, 월급명세서(+승진), 해고 통지, 🛒 매점, 📖 도감

local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
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
			"👔 김부장에게 들키면 의심도 ↑, 100%면 🚨 적발",
			"👀 부장 머리 위를 보세요: 🖥️ 안전 / 👀 위험",
			"⚠️ 하루 업무는 꼭 채우기! 경고 3번이면 📦 해고",
		},
	},
	{
		title = "💡 월급루팡 꿀팁",
		lines = {
			"😮‍💨 아슬아슬하게 복귀하면 보너스 + 콤보",
			"🚶 서류 들기 · 동료와 수다 · 탕비실 라면",
			"🍪 탕비실 간식을 챙겨서 자리에서 [8]로 몰래 먹기",
			"🚽 화장실 변기에 앉으면 📈 주식 거래 (가짜 주식)",
			"📈 승진하면 새 농땡이! 🛒 매점 · 📖 도감도 있어요",
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
	button(frame, 95, "다음 날 기다리기", close)
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
-- 🛒 매점
---------------------------------------------------------------------------
function Panels.showShop()
	local items = SalaryConfig.Items
	local frame = sheet(560, 130 + #items * 64)
	line(frame, 0, 30, "🛒 사내 매점", { Font = Enum.Font.GothamBlack, TextSize = 24 })
	local balance = line(frame, 0, 30, "", {
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamBold,
		Size = UDim2.new(1, -44, 0, 30), -- 오른쪽 위 닫기 버튼 자리는 비워 둬요
	})
	local message = line(frame, 30 + #items * 64 + 14, 22, "", { TextSize = 15, TextColor3 = MUTED })

	local rows = {}
	for i, item in items do
		local y = 40 + (i - 1) * 64
		line(frame, y, 22, `{item.emoji} {item.name} · {comma(item.price)}원`, { Font = Enum.Font.GothamBold })
		line(frame, y + 22, 36, item.description, { TextSize = 14, TextColor3 = MUTED, Size = UDim2.new(1, -120, 0, 36) })
		local buy = Ui.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, y + 8),
			Size = UDim2.fromOffset(110, 40),
			TextSize = 16,
			ZIndex = 31,
			Parent = frame,
		})
		buy.Activated:Connect(function()
			local ok, result = Remotes.BuyItem:InvokeServer(item.id)
			message.Text = result
			message.TextColor3 = if ok then Color3.fromRGB(40, 140, 70) else RED
		end)
		rows[item.id] = buy
	end

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
end

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
	for _, stateId in { "toilet", "candy", "coffee", "meeting", "docs", "chat", "ramen" } do
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

toolButton("🛒 매점", 76, function()
	if current then
		close()
	else
		Panels.showShop()
	end
end)
toolButton("📖 도감", 76, function()
	if current then
		close()
	else
		Panels.showCollection()
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
			"🌳 출입문 밖 공원 · 🍭 흡연구역(※ 금연, 사탕만!)에서 농땡이",
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
	local frame = sheet(520, 110 + #person.lines * 40 + 60)
	line(frame, 0, 34, person.title, { Font = Enum.Font.GothamBlack, TextSize = 26 })
	line(frame, 36, 22, person.subtitle, { TextSize = 15, TextColor3 = MUTED })
	for i, text in person.lines do
		line(frame, 70 + (i - 1) * 40, 36, text, { TextSize = 18 })
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
		end)
		return b
	end
	bigButton(-108, "🍶 따르기", "pour")
	local cheersButton = bigButton(108, "🥂 위하여!", "cheers")

	task.spawn(function()
		while current == frame do
			local glass = player:GetAttribute("DinnerGlass") or 1
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
	local message = line(frame, 30 + #items * 64 + 14, 22, "근무 중이라면 빨리 사서 돌아가요! 🖥️ 자리 부재 게이지가 차고 있어요", { TextSize = 15, TextColor3 = MUTED })
	for i, item in items do
		local y = 40 + (i - 1) * 64
		line(frame, y, 22, `{item.emoji} {item.name} · {comma(item.price)}원`, { Font = Enum.Font.GothamBold })
		line(frame, y + 22, 36, item.description, { TextSize = 14, TextColor3 = MUTED, Size = UDim2.new(1, -120, 0, 36) })
		local buy = Ui.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, y + 8),
			Size = UDim2.fromOffset(110, 40),
			Text = if item.snack then "포장하기" else "마시기",
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

Remotes:WaitForChild("StreetMenu").OnClientEvent:Connect(showStreetShop)

---------------------------------------------------------------------------
-- 🧸 인형뽑기 기계 (판정은 서버가 해요. 화면은 같은 식으로 집게를 움직여 보여 줘요)
---------------------------------------------------------------------------
local function rarityText(plush): string
	local rarity = SalaryConfig.PlushRarity[plush.rarity]
	return if rarity then rarity.name else ""
end

local function showClaw()
	local frame = sheet(520, 400)
	line(frame, 0, 32, "🧸 인형뽑기", { Font = Enum.Font.GothamBlack, TextSize = 26 })
	line(frame, 34, 40, `집게가 노리는 인형 바로 위에 왔을 때 [내리기]! 한 판 {comma(SalaryConfig.CLAW_PRICE)}원\n(딱 맞춰도 가끔 미끄러져요 😅)`, {
		TextSize = 14,
		TextColor3 = MUTED,
	})
	local box = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 82),
		Size = UDim2.new(1, 0, 0, 170),
		BackgroundColor3 = Color3.fromRGB(215, 235, 250),
		ZIndex = 31,
		Parent = frame,
	}, { Ui.corner(10), Ui.stroke(Color3.fromRGB(120, 150, 180), 2) })
	-- 집게 (줄 + ▼)
	local claw = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromOffset(30, 60),
		BackgroundTransparency = 1,
		ZIndex = 33,
		Parent = box,
	})
	local rope = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0, 3, 0, 30),
		BackgroundColor3 = Color3.fromRGB(120, 120, 130),
		ZIndex = 33,
		Parent = claw,
	})
	local hook = Ui.make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 26),
		Size = UDim2.fromOffset(30, 30),
		BackgroundTransparency = 1,
		Text = "▼",
		TextScaled = true,
		TextColor3 = Color3.fromRGB(90, 90, 100),
		ZIndex = 34,
		Parent = claw,
	})
	local prize = Ui.make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(48, 48),
		BackgroundTransparency = 1,
		TextScaled = true,
		Text = "🎁",
		ZIndex = 32,
		Parent = box,
	})
	local status = line(frame, 262, 52, "▶ 시작을 눌러 주세요!", { TextSize = 18, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center })

	local session: any = nil
	local dropping = false
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
	local dropButton = bigButton(110, "⬇️ 내리기")

	startButton.Activated:Connect(function()
		if session or dropping then
			return
		end
		Sounds.play("click", 0.5)
		local result = Remotes.Claw:InvokeServer("start")
		if not result.ok then
			status.Text = result.message
			status.TextColor3 = RED
			return
		end
		local plush = SalaryConfig.getPlush(result.plushId)
		session = result
		rope.Size = UDim2.new(0, 3, 0, 30)
		hook.Position = UDim2.new(0.5, 0, 0, 26)
		prize.Text = if plush then plush.emoji else "🎁"
		prize.Position = UDim2.new(0.06 + result.target * 0.88, 0, 1, -8)
		status.Text = if plush then `노리는 인형: {plush.emoji} {plush.name} ({rarityText(plush)})` else ""
		status.TextColor3 = if plush and plush.rarity == "legend" then Color3.fromRGB(220, 140, 0) else INK
	end)

	dropButton.Activated:Connect(function()
		if not session or dropping then
			return
		end
		dropping = true
		local result = Remotes.Claw:InvokeServer("drop", workspace:GetServerTimeNow())
		session = nil
		if not result.ok then
			dropping = false
			status.Text = result.message
			return
		end
		-- 집게를 판정된 위치에 두고 내려가는 연출
		claw.Position = UDim2.fromScale(0.06 + result.position * 0.88, 0)
		TweenService:Create(rope, TweenInfo.new(0.5), { Size = UDim2.new(0, 3, 0, 100) }):Play()
		TweenService:Create(hook, TweenInfo.new(0.5), { Position = UDim2.new(0.5, 0, 0, 96) }):Play()
		Sounds.play("swoosh", 0.4)
		task.wait(0.7)
		local plush = SalaryConfig.getPlush(result.plushId)
		if result.caught and plush then
			Sounds.play("ping", 0.7, 1.3)
			status.Text = `🎉 {plush.emoji} {plush.name} 획득! ({rarityText(plush)})`
			status.TextColor3 = Color3.fromRGB(40, 140, 70)
			Hud.popup(`🧸 {plush.emoji} {plush.name} 획득!`, Color3.fromRGB(255, 210, 80), 2.5)
		elseif result.hit then
			status.Text = "앗! 잡았는데 미끄러졌다… 😭"
			status.TextColor3 = RED
		else
			status.Text = "빗나갔어요… 조금만 더 정확하게!"
			status.TextColor3 = RED
		end
		startButton.Text = `▶ 한 판 더 ({comma(SalaryConfig.CLAW_PRICE)}원)`
		dropping = false
	end)

	task.spawn(function()
		while current == frame do
			if session and not dropping then
				local elapsed = workspace:GetServerTimeNow() - session.start
				local position = SalaryConfig.clawPosition(math.max(0, elapsed), session.period)
				claw.Position = UDim2.fromScale(0.06 + position * 0.88, 0)
			end
			task.wait()
		end
	end)
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
					info.icon.Text = "❔"
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
		run, presses, score, roundStart = result, {}, 0, result.start
		status.Text = ""
		startButton.Text = "게임 중…"
		task.spawn(function()
			while current == frame and run == result do
				local r = result.rounds[round()]
				if r then
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
		if gap <= SalaryConfig.TIMING_PERFECT then
			score += 3
			status.Text = "🌟 퍼펙트! +3"
			Sounds.play("ping", 0.6, 1.5)
		elseif gap <= SalaryConfig.TIMING_GOOD then
			score += 1
			status.Text = "👍 굿! +1"
			Sounds.play("ping", 0.5, 1.1)
		else
			status.Text = "😵 미스!"
			Sounds.play("bass", 0.4, 1.3)
		end
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

-- 새 날이 시작되면 열려 있던 창은 자동으로 닫아요
ReplicatedStorage:GetAttributeChangedSignal("SalaryPhase"):Connect(function()
	if ReplicatedStorage:GetAttribute("SalaryPhase") == "work" and current then
		close()
	end
end)

return Panels
