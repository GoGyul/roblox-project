-- 화면 표시: 시계, 돈과 직급, 의심도, 경고, 업무 진척도, 행동 버튼, 부장 발소리, 내 자리 표시

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SalaryConfig = require(Shared:WaitForChild("SalaryConfig"))
local Ui = require(Shared:WaitForChild("Ui"))
local Sounds = require(Shared:WaitForChild("Sounds"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local gui = Ui.gui
local C = Ui.COLORS
local States = SalaryConfig.States
local Ranks = SalaryConfig.Ranks

local Hud = {}

Hud.COLORS = {
	panel = Color3.fromRGB(25, 30, 40),
	good = Color3.fromRGB(90, 200, 120),
	warn = Color3.fromRGB(240, 190, 60),
	bad = Color3.fromRGB(230, 70, 60),
	locked = Color3.fromRGB(45, 45, 50),
	idle = Color3.fromRGB(70, 75, 90),
}
local COLORS = Hud.COLORS

function Hud.comma(n: number): string
	local digits = tostring(math.floor(math.abs(n)))
	local formatted = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return (if n < 0 then "-" else "") .. formatted
end
local comma = Hud.comma

local function panel(props: { [string]: any }): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or COLORS.panel
	props.BackgroundTransparency = props.BackgroundTransparency or 0.15
	props.Parent = props.Parent or gui
	return Ui.make("Frame", props, { Ui.corner(10), Ui.padding(10), Ui.stroke(C.brass) })
end

function Hud.text(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		TextColor3 = C.text,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for key, value in props do
		defaults[key] = value
	end
	return Ui.make("TextLabel", defaults)
end
local text = Hud.text

local function bar(parent: Instance, y: number, title: string): (TextLabel, Frame)
	local label = text({ Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 20), Text = title, TextSize = 15, Parent = parent })
	local back = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, y + 22),
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundColor3 = Color3.fromRGB(60, 60, 70),
		Parent = parent,
	}, { Ui.corner(6) })
	local fill = Ui.make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = COLORS.good,
		Parent = back,
	}, { Ui.corner(6) })
	return label, fill
end

---------------------------------------------------------------------------
-- 위쪽: 시계 + 부장 기분 + 발소리
---------------------------------------------------------------------------
local clockPanel = panel({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 8),
	Size = UDim2.fromOffset(300, 62),
})
local clockText = text({ Size = UDim2.new(1, 0, 0, 24), TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, Parent = clockPanel })
local moodText = text({
	Position = UDim2.fromOffset(0, 26),
	Size = UDim2.new(1, 0, 0, 18),
	TextSize = 14,
	TextColor3 = Color3.fromRGB(200, 200, 210),
	TextXAlignment = Enum.TextXAlignment.Center,
	Parent = clockPanel,
})

local footstepText = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 78),
	Size = UDim2.fromOffset(420, 30),
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeTransparency = 0.3,
	Visible = false,
	Parent = gui,
})

-- 🎲 돌발 이벤트 안내 (발소리 표시 아래)
local eventText = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 110),
	Size = UDim2.fromOffset(560, 30),
	TextSize = 21,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeTransparency = 0.3,
	Visible = false,
	Parent = gui,
})

-- 👀 이과장이 내 농땡이를 보고 있을 때 경고 (게이지가 다 차면 고자질!)
local leeText = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 142),
	Size = UDim2.fromOffset(460, 30),
	TextSize = 22,
	TextColor3 = Color3.fromRGB(255, 120, 120),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeTransparency = 0.2,
	Visible = false,
	Parent = gui,
})

---------------------------------------------------------------------------
-- 오른쪽 위: 직급, 경력, 돈
---------------------------------------------------------------------------
local moneyPanel = panel({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 8),
	Size = UDim2.fromOffset(250, 136),
})
local rankText = text({ Size = UDim2.new(1, 0, 0, 22), TextSize = 19, TextColor3 = C.brass, Parent = moneyPanel })
local xpLabel, xpFill = bar(moneyPanel, 24, "")
local todayText = text({ Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 0, 22), TextSize = 19, TextColor3 = COLORS.warn, Parent = moneyPanel })
local totalText = text({ Position = UDim2.fromOffset(0, 88), Size = UDim2.new(1, 0, 0, 18), TextSize = 15, Parent = moneyPanel })

---------------------------------------------------------------------------
-- 왼쪽: 내 상태, 의심도, 업무, 경고
---------------------------------------------------------------------------
local statusPanel = panel({
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.42, 0),
	Size = UDim2.fromOffset(250, 196),
})
local stateText = text({ Size = UDim2.new(1, 0, 0, 26), TextSize = 22, Parent = statusPanel })
local suspicionLabel, suspicionFill = bar(statusPanel, 34, "")
local workLabel, workFill = bar(statusPanel, 74, "")
local warningText = text({ Position = UDim2.fromOffset(0, 116), Size = UDim2.new(1, 0, 0, 22), Parent = statusPanel })
local comboText = text({
	Position = UDim2.fromOffset(0, 142),
	Size = UDim2.new(1, 0, 0, 20),
	TextSize = 15,
	TextColor3 = COLORS.good,
	Parent = statusPanel,
})

-- 매점 / 도감 / 드링크 버튼은 Panels가 이 줄에 넣어요
Hud.toolbar = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0, 12, 0.42, 108),
	Size = UDim2.fromOffset(250, 40),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	Ui.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
})

-- 💾 저장이 꺼져 있을 때만 왼쪽 아래 작은 아이콘 (마우스를 올리거나 누르면 설명)
local saveText = Ui.make("TextButton", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 10, 1, -10),
	Size = UDim2.fromOffset(34, 34),
	BackgroundColor3 = Color3.fromRGB(60, 30, 30),
	BackgroundTransparency = 0.2,
	Text = "💾",
	TextSize = 18,
	AutoButtonColor = false,
	Visible = false,
	ZIndex = 60, -- 행동 버튼보다 위에 (설명 말풍선이 가려지지 않게)
	Parent = gui,
}, { Ui.corner(17), Ui.stroke(Color3.fromRGB(220, 90, 80), 2) })
local saveTip = text({
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromOffset(42, 30),
	Size = UDim2.fromOffset(330, 28),
	BackgroundTransparency = 0.15,
	BackgroundColor3 = Color3.fromRGB(30, 25, 25),
	TextSize = 14,
	Text = "  저장 꺼짐: 나가면 오늘 진행이 사라져요 (스튜디오 테스트 중)",
	Visible = false,
	ZIndex = 61,
	Parent = saveText,
})
Ui.corner(8).Parent = saveTip
saveText.MouseEnter:Connect(function()
	saveTip.Visible = true
end)
saveText.MouseLeave:Connect(function()
	saveTip.Visible = false
end)
saveText.Activated:Connect(function()
	saveTip.Visible = not saveTip.Visible
end)

---------------------------------------------------------------------------
-- 아래: 행동 버튼 (자리에 앉아 있을 때만)
---------------------------------------------------------------------------
local BUTTON_WIDTH = 104
local actionCount = #SalaryConfig.DeskActions
local actionPanel = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.fromOffset(actionCount * BUTTON_WIDTH + (actionCount - 1) * 6, 116),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = gui,
})
-- 서 있을 때 안내 (농땡이 메뉴는 내 자리에 앉아야 나와요)
local standHint = text({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(520, 28),
	TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeTransparency = 0.3,
	Text = "🪑 ⭐ 내 자리에 앉으면 농땡이 메뉴가 나와요",
	Visible = false,
	Parent = gui,
})


local hintText = text({
	Size = UDim2.new(1, 0, 0, 22),
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeTransparency = 0.4,
	Parent = actionPanel,
})
local buttonRow = Ui.make("Frame", {
	Position = UDim2.fromOffset(0, 28),
	Size = UDim2.new(1, 0, 0, 88),
	BackgroundTransparency = 1,
	Parent = actionPanel,
}, {
	Ui.make("UIGridLayout", {
		Name = "Grid",
		CellSize = UDim2.fromOffset(BUTTON_WIDTH, 88),
		CellPadding = UDim2.fromOffset(6, 6),
		FillDirectionMaxCells = actionCount,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

local KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
}
local buttons: { [string]: TextButton } = {}

local function chooseAction(actionId: string)
	Remotes.SetAction:FireServer(actionId)
end

local function buttonText(index: number, actionId: string, unlocked: boolean): string
	local info = States[actionId]
	if actionId == "snack" then
		local snack = SalaryConfig.getSnack(player:GetAttribute("HeldSnack") or "")
		if not snack then
			return `[{index}] 🍪 간식\n탕비실에서\n가져오기`
		end
		local percent = math.floor((player:GetAttribute("SnackProgress") or 0) * 100)
		return `[{index}] {snack.emoji} {snack.name}\n먹기 {percent}%\n+{snack.bonus}원`
	end
	if not unlocked then
		return `[{index}] 🔒\n{info.name}\n{Ranks[info.unlockRank :: number].name}부터`
	end
	local returnText = if (info.returnTime or 0) > 0 then `\n복귀 {info.returnTime}초` else ""
	return `[{index}] {info.emoji} {info.name}\n+{info.income}원/초{returnText}`
end

for i, actionId in SalaryConfig.DeskActions do
	local button = Ui.button({
		Size = UDim2.fromOffset(BUTTON_WIDTH, 88),
		Text = buttonText(i, actionId, true),
		TextSize = 13,
		TextWrapped = true,
		LayoutOrder = i,
		BackgroundColor3 = COLORS.idle,
		TextColor3 = C.text,
		Parent = buttonRow,
	})
	button.Activated:Connect(function()
		Sounds.play("click", 0.4)
		chooseAction(actionId)
	end)
	buttons[actionId] = button
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not actionPanel.Visible or player:GetAttribute("ScreenHidden") then
		return
	end
	local index = table.find(KEYS, input.KeyCode)
	if index and SalaryConfig.DeskActions[index] then
		chooseAction(SalaryConfig.DeskActions[index])
	end
end)

---------------------------------------------------------------------------
-- 📱 화면 크기에 따라 배치 바꾸기
--   큰 화면(PC): 원래 배치
--   작은 화면(폰·작은 창): 패널을 줄이고, 행동 버튼은 2줄로 위쪽에, 서로 겹치지 않게
---------------------------------------------------------------------------
local scales = {}
for _, frame in { clockPanel, moneyPanel, statusPanel, Hud.toolbar, actionPanel } do
	scales[frame] = Ui.make("UIScale", { Parent = frame })
end

-- 작은 화면인가? (패널을 줄여요)
function Hud.isCompact(): boolean
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return Hud.isPhone() or viewport.X < 1000 or viewport.Y < 560
end

-- 폰처럼 터치만 되는 기기인가? (행동 버튼을 2줄 큰 버튼으로)
function Hud.isPhone(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function applyLayout()
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local compact = Hud.isCompact()
	local grid = buttonRow:FindFirstChild("Grid") :: UIGridLayout
	local small = if compact then 0.7 else 1

	scales[clockPanel].Scale = small
	clockPanel.Position = UDim2.new(0.5, 0, 0, if compact then 4 else 8)
	footstepText.Position = UDim2.new(0.5, 0, 0, if compact then 50 else 78)
	footstepText.TextSize = if compact then 17 else 22
	eventText.Position = UDim2.new(0.5, 0, 0, if compact then 74 else 110)
	eventText.TextSize = if compact then 16 else 21
	leeText.Position = UDim2.new(0.5, 0, 0, if compact then 96 else 142)
	leeText.TextSize = if compact then 17 else 22

	scales[moneyPanel].Scale = small
	moneyPanel.Position = UDim2.new(1, if compact then -6 else -12, 0, if compact then 4 else 8)

	scales[statusPanel].Scale = small
	if compact then
		statusPanel.AnchorPoint = Vector2.new(0, 0)
		statusPanel.Position = UDim2.new(0, 6, 0, 60)
		Hud.toolbar.Position = UDim2.new(0, 6, 0, 60 + math.floor(196 * small) + 4)
	else
		statusPanel.AnchorPoint = Vector2.new(0, 0.5)
		statusPanel.Position = UDim2.new(0, 12, 0.42, 0)
		Hud.toolbar.Position = UDim2.new(0, 12, 0.42, 108)
	end
	scales[Hud.toolbar].Scale = if compact then 0.85 else 1

	-- 행동 버튼
	--   폰: 4개씩 2줄 큰 버튼, 조이스틱·점프 버튼과 겹치지 않게 위로
	--   PC: 화면 크기와 상관없이 1줄 작은 버튼, 맨 아래에 붙여서 게임 화면을 덜 가리게
	local phone = Hud.isPhone()
	local columns = if phone then 4 else actionCount
	local rows = math.ceil(actionCount / columns)
	local cellWidth = if phone then 100 else 92
	local cellHeight = if phone then 64 else 60
	grid.FillDirectionMaxCells = columns
	grid.CellSize = UDim2.fromOffset(cellWidth, cellHeight)
	local width = columns * cellWidth + (columns - 1) * 6
	local height = rows * cellHeight + (rows - 1) * 6
	buttonRow.Size = UDim2.new(1, 0, 0, height)
	actionPanel.Size = UDim2.fromOffset(width, 22 + height)
	actionPanel.Position = UDim2.new(0.5, 0, 1, if phone then -90 else -6)
	scales[actionPanel].Scale = math.clamp((viewport.X - 24) / width, 0.5, 1)
	hintText.Size = UDim2.new(1, 0, 0, 18)
	hintText.TextSize = if phone then 14 else 13
	buttonRow.Position = UDim2.fromOffset(0, 22)
	for _, button in buttons do
		button.TextSize = if phone then 12 else 11
	end

	local bottomGap = if phone then 90 else 6
	local barHeight = (22 + height) * scales[actionPanel].Scale
	standHint.Position = UDim2.new(0.5, 0, 1, if phone then -100 else -24)
	standHint.TextSize = if compact then 15 else 17
	-- 안내 문구는 행동 버튼 위로
	Ui.setToastPosition(UDim2.new(0.5, 0, 1, -(bottomGap + barHeight + 10)))
end

applyLayout()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyLayout)
end
-- 막 들어왔을 땐 화면 크기가 정확하지 않을 수 있어서, 잠시 뒤 한 번 더 맞춰요
for _, delay in { 0.5, 1.5, 3 } do
	task.delay(delay, applyLayout)
end

---------------------------------------------------------------------------
-- 내 자리 표시 (자리에서 일어났을 때 어디로 돌아갈지)
---------------------------------------------------------------------------
local deskMarker: BillboardGui? = nil
local function updateDeskMarker(seated: boolean)
	local deskIndex = player:GetAttribute("DeskIndex")
	if not deskMarker and deskIndex then
		local office = workspace:FindFirstChild("Office")
		local desk = office and office:FindFirstChild(`Desk{deskIndex}`)
		local seat = desk and desk:FindFirstChild("Seat")
		if seat then
			deskMarker = Ui.make("BillboardGui", {
				Size = UDim2.fromOffset(120, 36),
				StudsOffset = Vector3.new(0, 5, 0),
				AlwaysOnTop = true,
				Parent = seat,
			}, {
				text({ Size = UDim2.fromScale(1, 1), Text = "⭐ 내 자리", TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.2 }),
			})
		end
	end
	if deskMarker then
		deskMarker.Enabled = not seated
	end
end

---------------------------------------------------------------------------
-- 매 프레임 갱신
---------------------------------------------------------------------------
local BOSS_STATUS_TEXT = {
	["👀"] = "👀 감시 중!",
	["🖥️"] = "🖥️ 모니터 보는 중",
	["👞"] = "👞 순찰 중",
	["❓"] = "❓ 소리 조사 중!",
	["😡"] = "😡 잔소리 중",
	["🍚"] = "🍚 점심",
}

local function phaseName(phase: string?): string
	if phase == "lunch" then
		return " 🍚 점심시간"
	elseif phase == "offwork" then
		return " 🏠 퇴근"
	end
	return ""
end

-- ⚠️ 해고 직전(경고 2/3)이면 화면 테두리가 빨갛게 깜빡여요
local dangerBorder = Ui.make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 49,
	Parent = gui,
}, { Ui.stroke(COLORS.bad, 8) })
local dangerStroke = dangerBorder:FindFirstChildOfClass("UIStroke") :: UIStroke
local quotaWarnedDay: any = nil -- 퇴근 전 업무 미달 알림을 보낸 날
local lastEventKey = "" -- 이벤트가 바뀌는 순간에만 연출하려고 기억해 둬요
local nextAlarmAt = 0

-- 🎲 돌발 이벤트 안내 줄
local function updateEvent()
	local eventId = ReplicatedStorage:GetAttribute("SalaryEvent") or ""
	local stage = ReplicatedStorage:GetAttribute("SalaryEventStage") or ""
	local endsAt = ReplicatedStorage:GetAttribute("SalaryEventEndsAt") or 0
	local left = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
	local key = `{eventId}:{stage}`
	local changed = key ~= lastEventKey
	lastEventKey = key

	local message, color = nil, COLORS.warn
	if eventId == "audit" and stage == "active" then
		message = `🔍 감사 기간 · 검은 정장 감사팀 조심! · 농땡이 수입 ×{SalaryConfig.AUDIT_INCOME}`
		if changed then
			Sounds.play("bass", 0.5, 1.2)
			Hud.popup("🔍 오늘은 감사 기간!", COLORS.warn, 3)
		end
	elseif eventId == "blackout" and stage == "active" then
		message = `💡 정전! 컴퓨터 꺼짐 · 지금은 자도 안 들켜요 ({left}초)`
		color = Color3.fromRGB(150, 190, 255)
		if changed then
			Sounds.play("bass", 0.7, 0.6)
			Hud.popup("💡 정전!", color, 2.5)
		end
	elseif eventId == "cake" and stage == "active" then
		message = "🎂 탕비실 조리대에 생일 케이크! (먼저 먹는 사람이 임자)"
		color = Color3.fromRGB(255, 180, 210)
		if changed then
			Sounds.play("ping", 0.6, 1.4)
			Hud.popup("🎂 생일 케이크 도착!", color, 2.5)
		end
	elseif eventId == "drill" and stage == "active" then
		local blink = math.floor(os.clock() * 3) % 2 == 0
		message = `🚨 소방 훈련! 초록색 집결지(출입문 앞)로 대피! {left}초 · 점프로 일어나기`
		color = if blink then COLORS.bad else Color3.new(1, 1, 1)
		if changed then
			Hud.popup("🚨 소방 훈련! 대피하세요!", COLORS.bad, 3)
		end
		if os.clock() >= nextAlarmAt then
			nextAlarmAt = os.clock() + 0.6
			Sounds.play("ping", 0.5, 2) -- 삐- 삐- 경보음
		end
	elseif eventId == "drill" and stage == "rollcall" then
		message = `🚒 인원 점검 중… 부장님 감시 쉬는 중 ({left}초)`
		color = COLORS.good
	end
	eventText.Visible = message ~= nil
	if message then
		eventText.Text = message
		eventText.TextColor3 = color
	end
end

RunService.RenderStepped:Connect(function()
	updateEvent()
	-- 👀 이과장 경고
	local leeWatch = player:GetAttribute("LeeWatch") or 0
	leeText.Visible = leeWatch > 0
	if leeWatch > 0 then
		local filled = math.ceil(leeWatch * 5)
		leeText.Text = `👀 이과장이 보고 있어요! 얼른 일하는 척! {string.rep("■", filled)}{string.rep("□", 5 - filled)}`
	end
	-- 시계
	local minute = ReplicatedStorage:GetAttribute("SalaryMinute") or SalaryConfig.START_MINUTE
	local phase = ReplicatedStorage:GetAttribute("SalaryPhase")
	clockText.Text = string.format("🕘 %02d:%02d · %s%s", minute // 60, minute % 60, ReplicatedStorage:GetAttribute("SalaryWeekday") or "", phaseName(phase))
	moodText.Text = `부장님 상태: {ReplicatedStorage:GetAttribute("SalaryMood") or "?"}`

	-- 직급과 경력
	local rankIndex = player:GetAttribute("Rank") or 1
	local rank = Ranks[rankIndex] or Ranks[1]
	rankText.Text = `👔 {rank.name} {player.DisplayName}`
	local xp = player:GetAttribute("XP") or 0
	local nextXp = player:GetAttribute("NextXP") or 0
	if nextXp > 0 then
		local nextRank = Ranks[rankIndex + 1]
		xpLabel.Text = `📈 {nextRank.name} 승진까지 {comma(math.max(0, nextXp - xp))}`
		xpFill.Size = UDim2.fromScale(math.clamp((xp - rank.xp) / (nextXp - rank.xp), 0, 1), 1)
	else
		xpLabel.Text = "📈 최고 직급! (사장 자리는 아직…)"
		xpFill.Size = UDim2.fromScale(1, 1)
	end
	xpFill.BackgroundColor3 = C.brass

	-- 돈
	todayText.Text = `💰 오늘 {comma(player:GetAttribute("TodayMoney") or 0)}원`
	totalText.Text = `🏦 통장 {comma(player:GetAttribute("TotalMoney") or 0)}원`
	saveText.Visible = player:GetAttribute("CanSave") == false

	-- 상태
	local stateId = player:GetAttribute("SalaryState") or "work"
	local info = States[stateId] or States.work
	stateText.Text = `{info.emoji} {info.name}` .. (if player:GetAttribute("EnergyActive") then "  ⚡" else "")

	local suspicion = player:GetAttribute("Suspicion") or 0
	suspicionLabel.Text = `🔍 부장님 의심도 {suspicion}%`
	suspicionFill.Size = UDim2.fromScale(math.clamp(suspicion / 100, 0, 1), 1)
	suspicionFill.BackgroundColor3 = if suspicion >= 70 then COLORS.bad elseif suspicion >= 35 then COLORS.warn else COLORS.good

	local work = player:GetAttribute("WorkSeconds") or 0
	local quota = player:GetAttribute("WorkQuota") or SalaryConfig.WORK_QUOTA
	workLabel.Text = if work >= quota then "📄 오늘 업무 완료! ✅" else `📄 오늘 업무 {work}/{quota}초 (못 채우면 경고)`
	workFill.Size = UDim2.fromScale(math.clamp(work / quota, 0, 1), 1)

	local warnings = player:GetAttribute("Warnings") or 0
	local onEdge = warnings >= SalaryConfig.MAX_WARNINGS - 1 and player:GetAttribute("Fired") ~= true
	warningText.Text = `경고 {string.rep("🟥", warnings)}{string.rep("⬜", math.max(0, SalaryConfig.MAX_WARNINGS - warnings))} ({warnings}/{SalaryConfig.MAX_WARNINGS})`
		.. (if onEdge then " 한 번 더면 해고!" else "")
	warningText.TextColor3 = if onEdge then COLORS.bad else C.text
	dangerBorder.Visible = onEdge and phase ~= "offwork"
	if dangerBorder.Visible then
		dangerStroke.Transparency = 0.35 + 0.35 * math.sin(os.clock() * 4)
	end

	-- 퇴근 1시간 전인데 업무를 못 채웠으면 미리 알려 줘요 (못 채우면 경고가 쌓여요)
	local day = ReplicatedStorage:GetAttribute("SalaryDay")
	if phase == "work" and minute >= SalaryConfig.END_MINUTE - 60 and quotaWarnedDay ~= day and player:GetAttribute("Fired") ~= true then
		quotaWarnedDay = day
		if work < quota then
			Sounds.play("caught", 0.4)
			local outcome = if onEdge then "못 채우면 해고예요!!" else "못 채우면 경고 1개!"
			Ui.toast(`⏰ 퇴근 1시간 전! 업무가 {quota - work}초 남았어요. {outcome}`)
		end
	end
	local combo = player:GetAttribute("Combo") or 1
	local comboLine = if combo > 1 then `🔥 콤보 x{combo}` else ""
	local heldSnack = SalaryConfig.getSnack(player:GetAttribute("HeldSnack") or "")
	if heldSnack then
		local percent = math.floor((player:GetAttribute("SnackProgress") or 0) * 100)
		comboLine = `{heldSnack.emoji} {heldSnack.name} {percent}%  ` .. comboLine
	end
	comboText.Text = comboLine

	-- 행동 버튼
	local seated = player:GetAttribute("Seated") == true
	local fired = player:GetAttribute("Fired") == true
	actionPanel.Visible = seated and not fired and phase ~= "offwork"
	standHint.Visible = not seated and not fired and phase ~= "offwork" and player:GetAttribute("OnToilet") ~= true
	local current = player:GetAttribute("SalaryAction") or "work"
	for i, actionId in SalaryConfig.DeskActions do
		local button = buttons[actionId]
		local unlocked = (States[actionId].unlockRank or 1) <= rankIndex
		if actionId == "snack" then
			unlocked = (player:GetAttribute("HeldSnack") or "") ~= "" -- 간식을 들고 있어야 먹을 수 있어요
		end
		local selected = actionId == current
		button.Text = buttonText(i, actionId, unlocked)
		button.BackgroundColor3 = if not unlocked then COLORS.locked elseif selected then C.brass else COLORS.idle
		button.BackgroundTransparency = if selected then 0.05 else 0.3 -- 살짝 비쳐서 게임 화면을 덜 가려요
		button.TextColor3 = if selected then C.ink else C.text
	end
	if stateId == "returning" then
		hintText.Text = "😳 허둥지둥 일하는 척 복귀 중…"
	else
		hintText.Text = States[current].hint or ""
	end
	updateDeskMarker(seated)

	-- 부장 발소리 (이어폰이 있으면 더 멀리서 듣고, 지금 뭐 하는지도 알 수 있어요)
	local hasEarphones = player:GetAttribute("Item_earphones") == true
	local hearRange = if hasEarphones then 45 else 30
	local office = workspace:FindFirstChild("Office")
	local bossModel = office and office:FindFirstChild("김부장")
	local bossRoot = bossModel and bossModel:FindFirstChild("HumanoidRootPart") :: BasePart?
	local character = player.Character
	local myRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if bossRoot and myRoot then
		local distance = (bossRoot.Position - myRoot.Position).Magnitude
		footstepText.Visible = distance < hearRange
		if distance < 14 then
			footstepText.Text = "👞👞 부장님이 바로 근처에!!"
			footstepText.TextColor3 = COLORS.bad
		else
			footstepText.Text = "👞 저벅저벅… 발소리가 들린다"
			footstepText.TextColor3 = COLORS.warn
		end
		if hasEarphones then
			local status = bossModel:FindFirstChild("Status", true) :: TextLabel?
			local statusText = status and BOSS_STATUS_TEXT[status.Text]
			if statusText then
				footstepText.Text ..= `  🎧 {statusText}`
			end
		end
	else
		footstepText.Visible = false
	end
end)

---------------------------------------------------------------------------
-- 이벤트 연출
---------------------------------------------------------------------------
local flash = Ui.make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = COLORS.bad,
	BackgroundTransparency = 1,
	ZIndex = 50,
	Parent = gui,
})

function Hud.popup(message: string, color: Color3, seconds: number)
	local label = text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(640, 50),
		Text = message,
		TextSize = 30,
		TextColor3 = color,
		TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 45,
		Parent = gui,
	})
	TweenService:Create(label, TweenInfo.new(seconds), { Position = UDim2.fromScale(0.5, 0.52), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(seconds, function()
		label:Destroy()
	end)
end

Remotes:WaitForChild("NearMiss").OnClientEvent:Connect(function(bonus: number, combo: number)
	Sounds.play("ping", 0.6, 1 + combo * 0.1)
	Hud.popup(`😮‍💨 아슬아슬! +{comma(bonus)}원 (콤보 x{combo})`, COLORS.good, 2)
end)

Remotes:WaitForChild("Caught").OnClientEvent:Connect(function(line: string, warnings: number)
	Sounds.play("caught", 0.8)
	Sounds.play("bass", 0.5, 0.8)
	flash.BackgroundTransparency = 0.4
	TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	Hud.popup(`🚨 적발! "{line}"`, COLORS.bad, 3)
	Ui.toast(`경고 {warnings}/{SalaryConfig.MAX_WARNINGS} · 시말서 감봉 -{comma(SalaryConfig.CAUGHT_PENALTY)}원`)
	if warnings == SalaryConfig.MAX_WARNINGS - 1 then
		task.delay(2, function()
			Hud.popup("⚠️ 한 번만 더 걸리면 해고!", COLORS.bad, 3.5)
		end)
	end
end)

Remotes:WaitForChild("Bonus").OnClientEvent:Connect(function(message: string, amount: number)
	Sounds.play("ping", 0.6, 1.2)
	Sounds.play("swoosh", 0.3)
	Hud.popup(`{message} +{comma(amount)}원`, Color3.fromRGB(255, 210, 80), 2.5)
end)

Remotes:WaitForChild("Unlocked").OnClientEvent:Connect(function(emoji: string, name: string)
	Ui.toast(`📖 도감 등록! {emoji} {name}`)
end)

Remotes:WaitForChild("Notify").OnClientEvent:Connect(Ui.toast)

---------------------------------------------------------------------------
-- 🔊 상황별 소리
---------------------------------------------------------------------------
Sounds.startMusic()
local typingLoop = Sounds.loop("typing", 0.12)
local lastCrunch = 0
local lastPhase = ReplicatedStorage:GetAttribute("SalaryPhase")
RunService.Heartbeat:Connect(function()
	local state = player:GetAttribute("SalaryState")
	local hidden = player:GetAttribute("ScreenHidden") == true
	-- 일하는 중엔 타자 소리, 화면을 숨기면 조용히
	if typingLoop then
		local shouldType = state == "work" and player:GetAttribute("Seated") == true and not hidden
		if typingLoop.Playing ~= shouldType then
			typingLoop.Playing = shouldType
		end
	end
	-- 간식 먹는 중엔 바삭바삭
	if state == "snack" and not hidden and os.clock() - lastCrunch > 0.7 then
		lastCrunch = os.clock()
		Sounds.play("crunch", 0.35, 0.9 + math.random() * 0.3)
	end
	-- 점심 시작/끝 알림음
	local phase = ReplicatedStorage:GetAttribute("SalaryPhase")
	if phase ~= lastPhase then
		if phase == "lunch" then
			Sounds.play("ping", 0.6, 0.8)
		elseif phase == "work" and lastPhase == "lunch" then
			Sounds.play("bass", 0.5)
		end
		lastPhase = phase
	end
end)

return Hud
