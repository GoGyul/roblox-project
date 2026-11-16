-- 가운데 뜨는 창: 입사 안내, 월급명세서(+승진), 해고 통지, 🛒 매점, 📖 도감

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SalaryConfig = require(Shared:WaitForChild("SalaryConfig"))
local ChatTopics = require(Shared:WaitForChild("ChatTopics"))
local Ui = require(Shared:WaitForChild("Ui"))
local Hud = require(script.Parent.Hud)

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

	-- 오른쪽 위 ✕ 닫기
	local closeButton = Ui.make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 10, 0, -10),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = Color3.fromRGB(225, 225, 228),
		Text = "✕",
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
function Panels.showWelcome()
	local frame = sheet(600, 560)
	line(frame, 0, 34, "📢 (주)고결상사 입사를 환영합니다!", { Font = Enum.Font.GothamBlack, TextSize = 26 })
	line(
		frame,
		44,
		440,
		table.concat({
			"목표: 💰 일은 최소로, 월급은 최대로! 그리고 승진!",
			"",
			"• 자리에 앉아 숫자키로 행동을 고르세요. 농땡이일수록 돈을 많이 벌어요.",
			"• 👔 김부장에게 농땡이가 보이면 의심도가 올라요. 100%가 되면 적발!",
			"• 큰 농땡이는 일하는 척으로 돌아오는 데 시간이 걸려요.",
			"• 부장 머리 위: 🖥️ 모니터 보는 중(안전) / 👀 감시 중(위험)",
			"• 아슬아슬하게 복귀하면 보너스! 연속이면 콤보!",
			"• 🚽 화장실은 안전지대, ☕ 탕비실은 잠깐 안전해요.",
			"• 🚶 돌아다니며 농땡이: 📄 프린터에서 서류 들기, 💬 동료와 수다, 🍜 탕비실 라면",
			"• 🍪 탕비실 간식 테이블에서 과자를 챙겨 자리에서 [8]로 몰래 먹기!",
			"• 🚽 화장실 변기에 앉으면 📈 화장실 주식 거래! (게임 속 가짜 주식)",
			"• 🙈 진짜 회사에서 몰래 하는 중이라면? [B] 화면 숨기기 / [Shift+B] 위장 화면 바꾸기",
			"• 👥 동료도 몰래 농땡이를 쳐요. 부장이 동료를 혼낼 때가 기회!",
			"• 하루 최소 업무는 채워야 해요. 경고 3번이면 📦 해고.",
			"• 📈 월급이 쌓이면 승진! 직급이 오르면 새 농땡이가 열려요.",
			"• 🛒 매점에서 루팡 아이템을 사고, 📖 도감을 채워 보세요.",
		}, "\n")
	)
	button(frame, 0, "출근하기", close)
end

---------------------------------------------------------------------------
-- 월급명세서
---------------------------------------------------------------------------
Remotes:WaitForChild("Payslip").OnClientEvent:Connect(function(slip)
	local rows = #slip.lines
	local extra = if slip.promotedTo then 70 else 0
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

	button(frame, -95, "🏛️ 광장으로", goLobby)
	button(frame, 95, "다음 날 기다리기", close)
end)

---------------------------------------------------------------------------
-- 해고 통지
---------------------------------------------------------------------------
Remotes:WaitForChild("Fired").OnClientEvent:Connect(function(bossLine: string, rankName: string)
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
	local balance = line(frame, 0, 30, "", { TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBold })
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
	for _, stateId in { "toilet", "coffee", "docs", "chat", "ramen" } do
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

-- 새 날이 시작되면 열려 있던 창은 자동으로 닫아요
ReplicatedStorage:GetAttributeChangedSignal("SalaryPhase"):Connect(function()
	if ReplicatedStorage:GetAttribute("SalaryPhase") == "work" and current then
		close()
	end
end)

return Panels
