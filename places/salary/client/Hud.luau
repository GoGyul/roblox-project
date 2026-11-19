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
Ui.setToastStyle(460, 15, 8) -- 📢 아래쪽 알림을 작게 (예전 620폭·글씨 20)

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
Hud.clockPanel = clockPanel -- Panels가 옆에 "👀 이과장" 버튼을 붙여요
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

-- 🏢 출근하기 (하루가 시작되기 전, 이 버튼을 눌러야 9시가 돼요)
local clockIn = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.58),
	Size = UDim2.fromOffset(380, 170),
	BackgroundColor3 = Color3.fromRGB(28, 22, 16),
	BackgroundTransparency = 0.1,
	Visible = false,
	ZIndex = 20,
	Parent = gui,
}, { Ui.corner(14), Ui.stroke(C.brass, 2) })
local clockInTitle = text({
	Position = UDim2.fromOffset(0, 12),
	Size = UDim2.new(1, 0, 0, 30),
	TextSize = 24,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 21,
	Parent = clockIn,
})
local clockInInfo = text({
	Position = UDim2.fromOffset(0, 44),
	Size = UDim2.new(1, 0, 0, 22),
	TextSize = 15,
	TextColor3 = Color3.fromRGB(200, 200, 210),
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 21,
	Parent = clockIn,
})
local clockInButton = Ui.button({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.fromOffset(260, 64),
	Text = "🏢 출근하기!",
	TextSize = 26,
	ZIndex = 21,
	Parent = clockIn,
})
clockInButton.Activated:Connect(function()
	if player:GetAttribute("ClockedIn") then
		return
	end
	Sounds.play("click", 0.6)
	Remotes.ClockIn:FireServer()
end)

local function updateClockIn()
	local waiting = ReplicatedStorage:GetAttribute("SalaryWaiting") == true
	clockIn.Visible = waiting
	if not waiting then
		return
	end
	local day = ReplicatedStorage:GetAttribute("SalaryDay") or 0
	local nextWeekday = SalaryConfig.Weekdays[day % #SalaryConfig.Weekdays + 1]
	clockInTitle.Text = `🌅 {day + 1}일차 · {nextWeekday.name} 아침`
	local count = ReplicatedStorage:GetAttribute("ClockInCount") or ""
	local left = ReplicatedStorage:GetAttribute("ClockInLeft") or -1
	local done = player:GetAttribute("ClockedIn") == true
	if done then
		clockInButton.Text = "✅ 출근 완료!"
		clockInButton.BackgroundColor3 = Color3.fromRGB(110, 110, 120)
		clockInInfo.Text = if left >= 0 then `동료 기다리는 중 ({count}) · {left}초 뒤 자동 출근` else `동료 기다리는 중 ({count})`
	else
		clockInButton.Text = "🏢 출근하기!"
		clockInButton.BackgroundColor3 = C.brass
		clockInInfo.Text = if left >= 0 then `준비 {count} · {left}초 뒤 출근해요!` else `부장님 기분: {nextWeekday.mood}`
	end
end

-- 📋 긴급 프로젝트 카드 (오른쪽, 돈 창 아래)
local missionPanel = panel({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 150),
	Size = UDim2.fromOffset(290, 196),
	Visible = false,
})
Hud.missionPanel = missionPanel -- Panels가 "🧩 풀기" 버튼을 붙여요
local missionTitle = text({ Size = UDim2.new(1, 0, 0, 24), TextSize = 19, TextColor3 = C.brass, Parent = missionPanel })
local missionTime = text({ Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 20), TextSize = 15, Parent = missionPanel })
local missionSteps = text({
	Position = UDim2.fromOffset(0, 48),
	Size = UDim2.new(1, 0, 1, -48),
	TextSize = 14,
	TextWrapped = true,
	RichText = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	Parent = missionPanel,
})
local lastMissionStatus = ""
local nextRingAt = 0

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
local STATUS_HEIGHT = 276
local statusPanel = panel({
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0, 12, 0, 8),
	Size = UDim2.fromOffset(250, STATUS_HEIGHT),
})
local stateText = text({ Size = UDim2.new(1, 0, 0, 26), TextSize = 22, TextScaled = true, Parent = statusPanel })
Ui.make("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 12, Parent = stateText }) -- 길면 글씨를 줄여서 한 줄에
local suspicionLabel, suspicionFill = bar(statusPanel, 34, "")
suspicionLabel.RichText = true
local workLabel, workFill = bar(statusPanel, 74, "")
local awayLabel, awayFill = bar(statusPanel, 114, "") -- 🖥️ 자리 부재 게이지
local targetLabel, targetFill = bar(statusPanel, 154, "") -- 💰 하루 실적 목표 (사원부터)
local warningText = text({ Position = UDim2.fromOffset(0, 196), Size = UDim2.new(1, 0, 0, 22), Parent = statusPanel })
local comboText = text({
	Position = UDim2.fromOffset(0, 222),
	Size = UDim2.new(1, 0, 0, 20),
	TextSize = 15,
	TextColor3 = COLORS.good,
	Parent = statusPanel,
})

-- 🔥 콤보 줄을 누르면 설명창 (다시 누르거나 ✕, 15초 뒤 닫혀요)
local comboButton = Ui.make("TextButton", {
	Position = UDim2.fromOffset(0, 220),
	Size = UDim2.new(1, 0, 0, 24),
	BackgroundTransparency = 1,
	Text = "",
	ZIndex = 5,
	Parent = statusPanel,
})
local comboInfo = panel({
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0, 12 + 250 + 8, 0, 8),
	Size = UDim2.fromOffset(300, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Visible = false,
	ZIndex = 20,
})
local comboInfoText = text({
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	TextSize = 14,
	TextWrapped = true,
	RichText = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 21,
	Parent = comboInfo,
})
local comboInfoClose = Ui.make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 4, 0, -4),
	Size = UDim2.fromOffset(24, 24),
	BackgroundTransparency = 1,
	Text = "X", -- (✕ 기호는 로블록스 글꼴에 없어서 네모로 보여요)
	TextColor3 = C.text,
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	ZIndex = 22,
	Parent = comboInfo,
})
local comboInfoOpenedAt = 0
local infoMode = "combo" -- "combo" 🔥 콤보 설명 / "speed" ⏩ 오늘의 의심도 속도

-- ⏩ 오늘의 의심도 속도 글자 (x1.00이면 회색, 빠르면 빨강, 느리면 초록)
local function speedText(speed: number): string
	local color = if speed > 1.001 then "#FF7A7A" elseif speed < 0.999 then "#7CE08A" else "#B8B8C0"
	local arrow = if speed > 1.001 then "⬆️" elseif speed < 0.999 then "⬇️" else ""
	return `<font color="{color}">⏩x{string.format("%.2f", speed)}{arrow}</font>`
end

local function refreshSpeedInfo()
	local speed = player:GetAttribute("SuspicionSpeed") or 1
	local ok, log = pcall(function()
		return game:GetService("HttpService"):JSONDecode(player:GetAttribute("SpeedLog") or "[]")
	end)
	local lines = {}
	for _, entry in (if ok and typeof(log) == "table" then log else {}) do
		local delta = entry.delta or 0
		local color = if delta > 0 then "#FF7A7A" else "#7CE08A"
		table.insert(lines, `{entry.label}  <font color="{color}"><b>{if delta > 0 then "+" else ""}{string.format("%.2f", delta)}</b></font>`)
	end
	comboInfoText.Text = `<font size="18"><b>⏩ 오늘의 의심도 속도 </b></font>` .. `<font size="18">{speedText(speed)}</font>\n`
		.. `부장님께 들킬 때 의심도가 차는 속도예요. 매일 아침 x1.00으로 리셋!\n`
		.. `<font color="#9A9AA5">사건마다 더하고 빼요 (최저 x{string.format("%.2f", SalaryConfig.SPEED_MIN)} ~ 최고 x{string.format("%.2f", SalaryConfig.SPEED_MAX)})</font>\n\n`
		.. `<b>📋 오늘 바뀐 이유</b>\n`
		.. (if #lines > 0 then table.concat(lines, "\n") else "<font color=\"#9A9AA5\">아직 없어요 (기준 x1.00)</font>")
		.. `\n\n<font color="#FF7A7A"><b>⬆️ 빨라져요:</b></font> 적발, 엉뚱한 동료 의심, 감사관 사진, 이과장 고자질, 화상회의·엘리베이터·프로젝트 실패, 월요일`
		.. `\n<font color="#7CE08A"><b>⬇️ 느려져요:</b></font> 프로젝트 성공, 감사관 색출, 💐·🍫 선물, 엘리베이터 무사 통과, 워크숍 1등, 모범 대피, 금요일`
		.. `\n<font color="#9A9AA5">🍻 회식·🎁 홍삼은 다음 날 아침에 반영돼요</font>`
end

local function refreshComboInfo()
	if infoMode == "speed" then
		refreshSpeedInfo()
		return
	end
	local combo = player:GetAttribute("Combo") or 1
	local left = player:GetAttribute("NearMissLeft") or SalaryConfig.NEAR_MISS_DAILY_MAX
	local nextBonus = SalaryConfig.NEAR_MISS_BONUS * combo
	comboInfoText.Text = `<font size="18"><b>🔥 아슬아슬 콤보 x{combo}</b></font>\n`
		.. `다음 보너스: <b>+{comma(nextBonus)}원</b> · 오늘 <b>{left}번</b> 남음\n\n`
		.. `<b>😅 아슬아슬이 터지는 법</b>\n`
		.. `① 딴짓하다 일하기로 복귀하자마자({SalaryConfig.NEAR_MISS_WINDOW}초 안에) 부장님이 가까이서 볼 때\n`
		.. `② 의심도가 {SalaryConfig.NEAR_MISS_DANGER} 넘게 찼다가 안 걸리고 {SalaryConfig.NEAR_MISS_SAFE} 밑으로 내려올 때\n\n`
		.. `<b>💰 보너스</b> = {comma(SalaryConfig.NEAR_MISS_BONUS)}원 × 콤보 (최대 x{SalaryConfig.MAX_COMBO})\n`
		.. `하루 {SalaryConfig.NEAR_MISS_DAILY_MAX}번까지, 한 번 받으면 {SalaryConfig.NEAR_MISS_COOLDOWN}초 쉬어요. 퇴근 때 지급!\n\n`
		.. `<font color="#FF7A7A">🚨 적발되면 콤보 x1로! (다음 날도 x1부터)</font>`
end
local function toggleComboInfo(show: boolean)
	comboInfo.Visible = show
	if show then
		refreshComboInfo()
		comboInfoOpenedAt = os.clock()
		Sounds.play("click", 0.4)
		local openedAt = comboInfoOpenedAt
		task.delay(15, function()
			if comboInfoOpenedAt == openedAt then
				comboInfo.Visible = false
			end
		end)
	end
end
comboButton.Activated:Connect(function()
	local same = infoMode == "combo"
	infoMode = "combo"
	toggleComboInfo(not (comboInfo.Visible and same))
end)
-- ⏩ 의심도 줄을 누르면 오늘의 의심도 속도 설명
local speedButton = Ui.make("TextButton", {
	Position = UDim2.fromOffset(0, 32),
	Size = UDim2.new(1, 0, 0, 36),
	BackgroundTransparency = 1,
	Text = "",
	ZIndex = 5,
	Parent = statusPanel,
})
speedButton.Activated:Connect(function()
	local same = infoMode == "speed"
	infoMode = "speed"
	toggleComboInfo(not (comboInfo.Visible and same))
end)
comboInfoClose.Activated:Connect(function()
	toggleComboInfo(false)
end)

-- 매점 / 도감 / 드링크 버튼은 Panels가 이 줄에 넣어요
Hud.toolbar = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0, 12, 0, 8 + STATUS_HEIGHT + 8),
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
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
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

local videoPopupRef: Frame? = nil -- 🎧 질문 팝업이 떠 있으면 숫자 키는 대답에 써요
local function videoPopupOpen(): boolean
	return videoPopupRef ~= nil and videoPopupRef.Visible
end

local KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}
local buttons: { [string]: TextButton } = {}

-- 📱 [폰 게임]을 누르면 바로 농땡이가 아니라, 행동 버튼 바로 위에 "무슨 게임?" 고르는 창이 떠요
--   게임을 골라야 농땡이 시작 (Panels가 Hud.onPhoneGame을 채워요)
Hud.onPhoneGame = nil :: ((gameId: string) -> ())?
local hoveredPhoneGame: string? = nil -- 게임 칸에 마우스를 올리면 설명을 위쪽 안내 줄에 보여 줘요
local PICK_SIZE = 64 -- 게임 하나 = 작은 정사각형 칸
local phonePicker = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, -6),
	Size = UDim2.fromOffset(#SalaryConfig.PhoneGames * (PICK_SIZE + 6) + 6, PICK_SIZE + 30),
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.1,
	Visible = false,
	ZIndex = 20,
	Parent = actionPanel,
}, { Ui.corner(8), Ui.stroke(C.brass) })
text({
	Position = UDim2.fromOffset(0, 3),
	Size = UDim2.new(1, 0, 0, 18),
	Text = "📱 무슨 게임?",
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 21,
	Parent = phonePicker,
})
for i, phoneGame in SalaryConfig.PhoneGames do
	local pick = Ui.button({
		Position = UDim2.fromOffset(6 + (i - 1) * (PICK_SIZE + 6), 24),
		Size = UDim2.fromOffset(PICK_SIZE, PICK_SIZE),
		Text = `<font size="24">{phoneGame.emoji}</font>\n{phoneGame.name}`,
		RichText = true,
		TextSize = 11,
		TextWrapped = true,
		ZIndex = 21,
		Parent = phonePicker,
	})
	pick.MouseEnter:Connect(function()
		hoveredPhoneGame = phoneGame.description
	end)
	pick.MouseLeave:Connect(function()
		if hoveredPhoneGame == phoneGame.description then
			hoveredPhoneGame = nil
		end
	end)
	pick.Activated:Connect(function()
		phonePicker.Visible = false
		hoveredPhoneGame = nil
		Sounds.play("click", 0.4)
		if Hud.onPhoneGame then
			Hud.onPhoneGame(phoneGame.id)
		else
			Remotes.SetAction:FireServer("phone")
		end
	end)
end

local function chooseAction(actionId: string)
	if actionId == "phone" then
		phonePicker.Visible = not phonePicker.Visible
		return
	end
	phonePicker.Visible = false
	Remotes.SetAction:FireServer(actionId)
end

-- 버튼은 아이콘 위주로 작게: 큰 이모지 + [번호] + 수입 (자세한 설명은 마우스를 올리면 위에 떠요)
local function buttonText(index: number, actionId: string, unlocked: boolean): string
	local info = States[actionId]
	if actionId == "snack" then
		local snack = SalaryConfig.getSnack(player:GetAttribute("HeldSnack") or "")
		if not snack then
			return `<font size="22">🍪</font>\n[{index}] 없음`
		end
		local percent = math.floor((player:GetAttribute("SnackProgress") or 0) * 100)
		return `<font size="22">{snack.emoji}</font>\n[{index}] {percent}%`
	end
	if not unlocked then
		return `<font size="22">🔒</font>\n[{index}]`
	end
	return `<font size="22">{info.emoji}</font>\n[{index}] +{info.income}`
end

-- 자세한 설명 (마우스를 올렸을 때 / 지금 고른 행동)
local function actionDetail(actionId: string): string
	local info = States[actionId]
	if actionId == "snack" then
		local snack = SalaryConfig.getSnack(player:GetAttribute("HeldSnack") or "")
		return if snack then `{snack.emoji} {snack.name} 몰래 먹기 · 다 먹으면 +{snack.bonus}원` else "🍪 간식은 탕비실·디저트집에서 가져와요"
	end
	local returnText = if (info.returnTime or 0) > 0 then ` · 복귀 {info.returnTime}초` else ""
	return `{info.emoji} {info.name} · +{info.income}원/초{returnText} — {info.hint or ""}`
end
local hoveredAction: string? = nil
local layoutDirty = false -- 보이는 버튼 수가 바뀌면 다시 배치

for i, actionId in SalaryConfig.DeskActions do
	local button = Ui.button({
		Size = UDim2.fromOffset(BUTTON_WIDTH, 88),
		Text = buttonText(i, actionId, true),
		TextSize = 13,
		TextWrapped = true,
		RichText = true,
		LayoutOrder = i,
		BackgroundColor3 = COLORS.idle,
		TextColor3 = C.text,
		Parent = buttonRow,
	})
	button.Activated:Connect(function()
		Sounds.play("click", 0.4)
		chooseAction(actionId)
	end)
	button.MouseEnter:Connect(function()
		hoveredAction = actionId
	end)
	button.MouseLeave:Connect(function()
		if hoveredAction == actionId then
			hoveredAction = nil
		end
	end)
	buttons[actionId] = button
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not actionPanel.Visible or player:GetAttribute("ScreenHidden") or videoPopupOpen() or Hud.inElevator or Hud.numberGame then
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
for _, frame in { clockPanel, moneyPanel, statusPanel, Hud.toolbar, actionPanel, missionPanel } do
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
	-- 📋 프로젝트 카드는 돈 창 바로 아래
	scales[missionPanel].Scale = small
	missionPanel.Position = UDim2.new(1, if compact then -6 else -12, 0, (if compact then 4 else 8) + math.floor(moneyPanel.AbsoluteSize.Y) + 8)

	scales[statusPanel].Scale = small
	if compact then
		statusPanel.AnchorPoint = Vector2.new(0, 0)
		statusPanel.Position = UDim2.new(0, 6, 0, 4)
		Hud.toolbar.Position = UDim2.new(0, 6, 0, 4 + math.floor(STATUS_HEIGHT * small) + 4)
	else
		-- 시계·돈 창과 같은 높이(맨 위)에 맞춰요
		statusPanel.AnchorPoint = Vector2.new(0, 0)
		statusPanel.Position = UDim2.new(0, 12, 0, 8)
		Hud.toolbar.Position = UDim2.new(0, 12, 0, 8 + STATUS_HEIGHT + 8)
	end
	scales[Hud.toolbar].Scale = if compact then 0.85 else 1

	-- 행동 버튼
	--   폰: 4개씩 2줄 큰 버튼, 조이스틱·점프 버튼과 겹치지 않게 위로
	--   PC: 화면 크기와 상관없이 1줄 작은 버튼, 맨 아래에 붙여서 게임 화면을 덜 가리게
	local phone = Hud.isPhone()
	-- 보이는 버튼(잠긴 행동은 숨겨요) 개수에 맞춰서 배치
	local visibleCount = 0
	for _, button in buttons do
		if button.Visible then
			visibleCount += 1
		end
	end
	visibleCount = math.max(visibleCount, 1)
	local columns = if phone then math.min(5, visibleCount) else visibleCount
	local rows = math.ceil(visibleCount / columns)
	local cellWidth = if phone then 66 else 62
	local cellHeight = if phone then 58 else 54
	grid.FillDirectionMaxCells = columns
	grid.CellSize = UDim2.fromOffset(cellWidth, cellHeight)
	local width = columns * cellWidth + (columns - 1) * 6
	local height = rows * cellHeight + (rows - 1) * 6
	buttonRow.Size = UDim2.new(1, 0, 0, height)
	actionPanel.Size = UDim2.fromOffset(width, 22 + height)
	actionPanel.Position = UDim2.new(0.5, 0, 1, if phone then -90 else -6)
	scales[actionPanel].Scale = math.clamp((viewport.X - 24) / width, 0.5, 1)
	hintText.Size = UDim2.new(0, math.max(width, 720), 0, 18) -- 버튼 줄보다 넓게 (설명이 잘리지 않게)
	hintText.TextSize = if phone then 14 else 13
	buttonRow.Position = UDim2.fromOffset(0, 22)
	for _, button in buttons do
		button.TextSize = if phone then 13 else 12
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
	if ReplicatedStorage:GetAttribute("SalaryWaiting") then
		return " 🌅 출근 전"
	end
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
		message = `🔍 감사 기간 · 동료 중에 위장 감사관이! 📸 조심 · 수상하면 [R] · 농땡이 수입 ×{SalaryConfig.AUDIT_INCOME}`
		if changed then
			Sounds.play("bass", 0.5, 1.2)
			Hud.popup("🔍 오늘은 감사 기간!", COLORS.warn, 3)
		end
	elseif eventId == "audit" and stage == "revealed" then
		message = `🕶️ 감사관 정체 폭로! 감사 끝 · 농땡이 수입 ×{SalaryConfig.AUDIT_INCOME}은 계속`
		color = COLORS.good
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
	elseif eventId == "workshop" and (stage == "ready" or stage == "chant" or stage == "look") then
		local status = player:GetAttribute("WorkshopStatus")
		if status == "out" then
			message = "🌸 탈락… 움직였어요! 구경하면서 응원해요"
			color = Color3.fromRGB(200, 200, 210)
		elseif status == "finished" then
			message = "🏁 골인! 보너스 획득!"
			color = COLORS.good
		elseif stage == "ready" then
			message = `🌸 무궁화꽃이 피었습니다! 초록 결승선(출입문 앞)까지! {left}초 뒤 시작`
			color = Color3.fromRGB(255, 180, 210)
		elseif stage == "chant" then
			message = `🌸 무궁화~ 꽃이~ 피었습니다~ 지금 움직여요! ({left}초)`
			color = COLORS.good
		else
			message = "👀 멈춰!! 움직이면 탈락!"
			color = COLORS.bad
		end
		if changed and stage == "look" then
			Sounds.play("bass", 0.6, 1.4)
		elseif changed and stage == "ready" then
			Hud.popup("🌸 워크숍 레크리에이션!", Color3.fromRGB(255, 180, 210), 3)
		end
	end
	eventText.Visible = message ~= nil
	if message then
		eventText.Text = message
		eventText.TextColor3 = color
	end
end

-- 📋 긴급 프로젝트 카드 갱신
local function updateMission()
	local missionId = player:GetAttribute("MissionId") or ""
	local status = player:GetAttribute("MissionStatus") or ""
	local mission = SalaryConfig.Missions[missionId]
	missionPanel.Visible = mission ~= nil and (status == "active" or status == "success" or status == "fail")
	if status ~= lastMissionStatus then
		if status == "active" then
			Sounds.play("bass", 0.6, 1.3)
			Hud.popup(`📋 긴급 프로젝트! {mission and mission.name or ""}`, COLORS.warn, 3)
		elseif status == "success" then
			Sounds.play("ping", 0.8, 1.3)
			Hud.popup("📋 프로젝트 성공! 🎉", COLORS.good, 3)
		elseif status == "fail" then
			Sounds.play("bass", 0.5, 0.8)
			Hud.popup("📋 프로젝트 실패…", COLORS.bad, 2.5)
		end
		lastMissionStatus = status
	end
	if not mission or not missionPanel.Visible then
		return
	end
	local step = player:GetAttribute("MissionStep") or 1
	local left = math.max(0, math.ceil((player:GetAttribute("MissionEndsAt") or 0) - workspace:GetServerTimeNow()))
	missionTitle.Text = `📋 {mission.emoji} {mission.name}`
	if status == "success" then
		missionTime.Text = "✅ 성공!"
		missionTime.TextColor3 = COLORS.good
	elseif status == "fail" then
		missionTime.Text = "❌ 실패…"
		missionTime.TextColor3 = COLORS.bad
	else
		missionTime.Text = `⏰ 남은 시간 {left}초 · 성공하면 경고 -1`
		missionTime.TextColor3 = if left <= 15 then COLORS.bad else C.text
	end
	local lines = {}
	local progress = player:GetAttribute("MissionProgress") or ""
	for i, stepInfo in mission.steps do
		local stepText = stepInfo.text
		if i < step or status == "success" then
			table.insert(lines, `<font color="#7CE08A">✅ {stepText}</font>`)
		elseif i == step and status == "active" then
			table.insert(lines, `<b>▶ {stepText}</b>` .. (if progress ~= "" then `  <font color="#FFD266">{progress}</font>` else ""))
		else
			table.insert(lines, `<font color="#9A9AA5">· {stepText}</font>`)
		end
	end
	missionSteps.Text = table.concat(lines, "\n")
	-- 📞 전화 벨소리
	local current = mission.steps[step]
	if status == "active" and current and current.kind == "answer" and os.clock() >= nextRingAt then
		nextRingAt = os.clock() + 0.5
		Sounds.play("ping", 0.6, 1.8)
	end
end

RunService.RenderStepped:Connect(function()
	updateEvent()
	updateMission()
	updateClockIn()
	-- 👀 이과장 경고
	local leeWatch = player:GetAttribute("LeeWatch") or 0
	leeText.Visible = leeWatch > 0
	if leeWatch > 0 then
		local filled = math.ceil(leeWatch * 5)
		leeText.Text = `👀 이과장이 보고 있어요! 얼른 일하는 척! {string.rep("🟥", filled)}{string.rep("⬜", 5 - filled)}`
	end
	-- 시계
	local minute = ReplicatedStorage:GetAttribute("SalaryMinute") or SalaryConfig.START_MINUTE
	local phase = ReplicatedStorage:GetAttribute("SalaryPhase")
	clockText.Text = string.format("🕘 %02d:%02d · %s%s", minute // 60, minute % 60, ReplicatedStorage:GetAttribute("SalaryWeekday") or "", phaseName(phase))
	moodText.Text = `{SalaryConfig.currentCompany().name} · 부장님: {ReplicatedStorage:GetAttribute("SalaryMood") or "?"}`

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
	-- 지금 1초에 얼마 버는지 (농땡이 종류 + 직급 배율 + 이벤트까지 계산된 값)
	local rate = player:GetAttribute("IncomeRate") or 0
	local rateText = if rate > 0 then `  <font color="#7CE08A">+{rate}원/초</font>` else `  <font color="#9A9AA5">+0원/초</font>`
	stateText.RichText = true
	stateText.Text = `{info.emoji} {info.name}` .. rateText .. (if player:GetAttribute("EnergyActive") then "  ⚡" else "")

	local suspicion = player:GetAttribute("Suspicion") or 0
	suspicionLabel.Text = `🔍 부장님 의심도 {suspicion}%  ` .. speedText(player:GetAttribute("SuspicionSpeed") or 1)
	suspicionFill.Size = UDim2.fromScale(math.clamp(suspicion / 100, 0, 1), 1)
	suspicionFill.BackgroundColor3 = if suspicion >= 70 then COLORS.bad elseif suspicion >= 35 then COLORS.warn else COLORS.good

	-- 💰 하루 실적 목표
	local target = player:GetAttribute("DailyTarget") or 0
	local earnedToday = player:GetAttribute("TodayMoney") or 0
	if target > 0 then
		targetLabel.Text = if earnedToday >= target then `💰 오늘 실적 {comma(earnedToday)}/{comma(target)}원 ✅` else `💰 오늘 실적 {comma(earnedToday)}/{comma(target)}원 (못 채우면 경고)`
		targetFill.Size = UDim2.fromScale(math.clamp(earnedToday / target, 0, 1), 1)
		targetFill.BackgroundColor3 = if earnedToday >= target then COLORS.good else COLORS.warn
	else
		targetLabel.Text = "💰 실적 목표는 사원부터 (지금은 자유!)"
		targetFill.Size = UDim2.fromScale(0, 1)
	end

	-- 🖥️ 자리 부재 게이지
	local away = player:GetAttribute("AwayGauge") or 0
	local powerOut = ReplicatedStorage:GetAttribute("SalaryEvent") == "blackout" and ReplicatedStorage:GetAttribute("SalaryEventStage") == "active"
	awayLabel.Text = if powerOut then `🖥️ 자리 부재 {away}% (💡 정전: 컴퓨터 꺼짐, 기록 초기화)`
		elseif away >= SalaryConfig.AWAY_WARN then `🖥️ 자리 부재 {away}% ⚠️ 얼른 자리로!`
		else `🖥️ 자리 부재 {away}% (꽉 차면 경고)`
	awayFill.Size = UDim2.fromScale(math.clamp(away / 100, 0, 1), 1)
	awayFill.BackgroundColor3 = if away >= SalaryConfig.AWAY_WARN then COLORS.bad elseif away >= 40 then COLORS.warn else COLORS.good

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
		local outcome = if onEdge then "못 채우면 해고예요!!" else "못 채우면 경고 1개!"
		if work < quota then
			Sounds.play("caught", 0.4)
			Ui.toast(`⏰ 퇴근 1시간 전! 업무가 {quota - work}초 남았어요. {outcome}`)
		end
		local target = player:GetAttribute("DailyTarget") or 0
		local earned = player:GetAttribute("TodayMoney") or 0
		if target > 0 and earned < target then
			Sounds.play("caught", 0.4)
			Ui.toast(`💰 퇴근 1시간 전! 오늘 실적이 {comma(target - earned)}원 모자라요. {outcome}`)
		end
	end
	local combo = player:GetAttribute("Combo") or 1
	local comboLine = `🔥 콤보 x{combo} ❓` -- (누르면 설명창)
	local photos = player:GetAttribute("AuditPhotos") or -1
	if photos >= 0 then
		-- 🕶️ 감사관에게 찍힌 사진: 농땡이 📸 n/2 · 빈자리 🪑 n/3 (하나라도 차면 감사 보고서)
		local empty = player:GetAttribute("AuditEmptyPhotos") or 0
		local photoText = if player:GetAttribute("AuditReported") == true
			then "📸 보고서 확정"
			else `📸 {photos}/{SalaryConfig.AUDIT_REPORT_AT} 🪑 {empty}/{SalaryConfig.AUDIT_EMPTY_REPORT_AT}`
		comboLine = photoText .. "  " .. comboLine
	end
	if comboInfo.Visible then
		refreshComboInfo()
	end
	local heldSnack = SalaryConfig.getSnack(player:GetAttribute("HeldSnack") or "")
	if heldSnack then
		local percent = math.floor((player:GetAttribute("SnackProgress") or 0) * 100)
		comboLine = `{heldSnack.emoji} {heldSnack.name} {percent}%  ` .. comboLine
	end
	local buffs = player:GetAttribute("Buffs") or ""
	if buffs ~= "" then
		comboLine = `오늘 버프 {buffs}  ` .. comboLine -- 🏙️ 카페 음료
	end
	local gift = player:GetAttribute("HeldGift") or ""
	if gift ~= "" then
		comboLine = `선물 {gift}  ` .. comboLine -- 🎁 부장님께 드릴 선물
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
		-- 🔒 아직 못 쓰는 행동은 숨겨요 (간식은 들고 있을 때만)
		local show = unlocked
		if button.Visible ~= show then
			button.Visible = show
			layoutDirty = true
		end
		button.Text = buttonText(i, actionId, unlocked)
		button.BackgroundColor3 = if not unlocked then COLORS.locked elseif selected then C.brass else COLORS.idle
		button.BackgroundTransparency = if selected then 0.05 else 0.3 -- 살짝 비쳐서 게임 화면을 덜 가려요
		button.TextColor3 = if selected then C.ink else C.text
	end
	if hoveredPhoneGame then
		hintText.Text = hoveredPhoneGame -- 📱 게임 칸에 마우스를 올렸을 때 설명
	elseif hoveredAction then
		hintText.Text = actionDetail(hoveredAction)
	elseif stateId == "returning" then
		hintText.Text = "😳 허둥지둥 일하는 척 복귀 중…"
	else
		hintText.Text = actionDetail(current)
	end
	if layoutDirty then
		layoutDirty = false
		applyLayout()
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
	local radarText = player:GetAttribute("BossRadar") or ""
	if radarText ~= "" then
		-- 🔭 옥상 망원경으로 보는 중
		footstepText.Visible = true
		footstepText.Text = radarText
		footstepText.TextColor3 = Color3.fromRGB(150, 210, 255)
	elseif bossRoot and myRoot then
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

-- 가운데 알림 (적발, 아슬아슬, 📸 찰칵…)
--   여러 개가 한꺼번에 나오면 먼저 나온 게 위로 밀려 올라가서 글자가 겹치지 않아요
local POPUP_GAP = 30 -- 줄 간격
local popupStack: { TextLabel } = {} -- 아래(최신) → 위(오래된) 순서
local function layoutPopups()
	for i, label in popupStack do
		TweenService:Create(label, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 0.62, -(i - 1) * POPUP_GAP),
		}):Play()
	end
end

function Hud.popup(message: string, color: Color3, seconds: number)
	local label = text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.62, 12),
		Size = UDim2.fromOffset(640, 28),
		Text = message,
		TextSize = 21, -- (예전 30: 너무 커서 줄였어요)
		TextColor3 = color,
		TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 45,
		Parent = gui,
	})
	table.insert(popupStack, 1, label)
	-- 너무 많이 쌓이면 가장 오래된 것부터 정리
	while #popupStack > 5 do
		local oldest = table.remove(popupStack)
		if oldest then
			oldest:Destroy()
		end
	end
	layoutPopups()
	-- 최소 2초는 또렷하게 보여 주고, 그다음 0.6초 동안 흐려지며 사라져요
	local hold = math.max(seconds, 2)
	task.delay(hold, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
	task.delay(hold + 0.6, function()
		local index = table.find(popupStack, label)
		if index then
			table.remove(popupStack, index)
			layoutPopups()
		end
		label:Destroy()
	end)
end

Remotes:WaitForChild("NearMiss").OnClientEvent:Connect(function(bonus: number, combo: number, left: number?, label: string?)
	Sounds.play("ping", 0.6, 1 + combo * 0.1)
	local leftText = if left == nil then "" elseif left > 0 then ` · 오늘 {left}번 남음` else " · 오늘은 끝!"
	Hud.popup(`😅 {label or "아슬아슬!"} +{comma(bonus)}원 (콤보 x{combo}{leftText})`, COLORS.good, 2)
end)

-- ⏩ 오늘의 의심도 속도가 바뀌었어요
Remotes:WaitForChild("SpeedChange").OnClientEvent:Connect(function(label: string, delta: number, speed: number)
	local faster = delta > 0
	Sounds.play(if faster then "bass" else "ping", 0.4, if faster then 1.3 else 1.4)
	Hud.popup(
		`⏩ 의심도 속도 {if faster then "+" else ""}{string.format("%.2f", delta)} → x{string.format("%.2f", speed)}  ({label})`,
		if faster then COLORS.bad else COLORS.good,
		2.5
	)
end)

-- 🕶️ 위장 감사관 카메라
Remotes:WaitForChild("AuditPhoto").OnClientEvent:Connect(function(kind: string, count: number)
	local max = if kind == "empty" then SalaryConfig.AUDIT_EMPTY_REPORT_AT else SalaryConfig.AUDIT_REPORT_AT
	if kind == "aim" then
		Sounds.play("click", 0.6, 0.7)
		Hud.popup(`📷 누가 카메라를 들었다…! {SalaryConfig.AUDIT_PHOTO_WINDUP}초 안에 일하는 척!`, COLORS.warn, 2.5)
	elseif kind == "shot" or kind == "empty" then
		Sounds.play("caught", 0.5, 1.6)
		flash.BackgroundColor3 = Color3.new(1, 1, 1) -- 📸 하얀 플래시
		flash.BackgroundTransparency = 0.15
		local tween = TweenService:Create(flash, TweenInfo.new(0.9), { BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Once(function()
			flash.BackgroundColor3 = COLORS.bad
		end)
		Hud.popup(
			if kind == "empty"
				then `🪑 찰칵! 도망간 빈자리가 찍혔어요 ({count}/{max})`
				else `📸 찰칵! 감사관에게 찍혔어요 ({count}/{max})`,
			COLORS.bad,
			2.5
		)
		if count < max then
			Ui.toast(
				(if kind == "empty" then `🪑 빈자리 사진 {count}/{max}` else `📸 농땡이 사진 {count}/{max}`)
					.. ` · {max}장이면 퇴근 때 감봉 + 경고! 누가 찍었는지 찾아서 [R]`
			)
		end
	elseif kind == "miss" then
		Sounds.play("ping", 0.4, 1.3)
		Hud.popup("😅 휴, 사진 피했다!", COLORS.good, 2.5)
	elseif kind == "reveal" then
		Sounds.play("ping", 0.7, 1.1)
		Hud.popup("🕶️ 감사관 정체 폭로! 감사 끝 · 📸 사진 폐기", COLORS.good, 3)
	elseif kind == "wrong" then
		Sounds.play("bass", 0.5, 1)
		Hud.popup(`😠 엉뚱한 사람이었어요! 의심도 +{SalaryConfig.AUDIT_WRONG_SUSPICION}`, COLORS.bad, 2.5)
		Ui.toast(if count > 0 then `🙊 오늘 {count}번 더 의심할 수 있어요` else "🙊 오늘은 더 의심할 수 없어요")
	end
end)

Remotes:WaitForChild("Caught").OnClientEvent:Connect(function(line: string, warnings: number)
	Sounds.play("caught", 0.8)
	Sounds.play("bass", 0.5, 0.8)
	flash.BackgroundTransparency = 0.4
	TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	Hud.popup(`🚨 적발! "{line}"`, COLORS.bad, 3)
	Ui.toast(`경고 {warnings}/{SalaryConfig.MAX_WARNINGS} · 시말서 감봉 -{comma(SalaryConfig.caughtPenalty(player:GetAttribute("Rank") or 1))}원`)
	if warnings == SalaryConfig.MAX_WARNINGS - 1 then
		task.delay(2, function()
			Hud.popup("⚠️ 한 번만 더 걸리면 해고!", COLORS.bad, 3.5)
		end)
	end
end)

-- 🎧 화상회의 질문 팝업 (6초 안에 그럴듯한 대답 고르기)
local videoPopup = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 180),
	Size = UDim2.fromOffset(460, 210),
	BackgroundColor3 = Color3.fromRGB(28, 32, 44),
	BackgroundTransparency = 0.05,
	Visible = false,
	ZIndex = 40,
	Parent = gui,
}, { Ui.corner(12), Ui.stroke(Color3.fromRGB(90, 160, 255), 2), Ui.padding(12) })
local videoTitle = text({ Size = UDim2.new(1, 0, 0, 22), TextSize = 16, TextColor3 = Color3.fromRGB(140, 190, 255), ZIndex = 41, Parent = videoPopup })
local videoQuestion = text({ Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 30), TextSize = 20, TextWrapped = true, ZIndex = 41, Parent = videoPopup })
local videoTimer = Ui.make("Frame", {
	Position = UDim2.fromOffset(0, 58),
	Size = UDim2.new(1, 0, 0, 6),
	BackgroundColor3 = Color3.fromRGB(90, 160, 255),
	BorderSizePixel = 0,
	ZIndex = 41,
	Parent = videoPopup,
})
videoPopupRef = videoPopup
local videoButtons = {}
local videoId = 0
local videoDeadline = 0
for i = 1, 3 do
	local b = Ui.button({
		Position = UDim2.fromOffset(0, 70 + (i - 1) * 42),
		Size = UDim2.new(1, 0, 0, 38),
		TextSize = 16,
		ZIndex = 41,
		Parent = videoPopup,
	})
	b.Activated:Connect(function()
		if videoId ~= 0 then
			Remotes.VideoAnswer:FireServer(videoId, i)
			Sounds.play("click", 0.5)
			videoId = 0
			videoPopup.Visible = false
		end
	end)
	videoButtons[i] = b
end
Remotes:WaitForChild("VideoQuestion").OnClientEvent:Connect(function(id: number, question: string?, options: { string }?, seconds: number?)
	if id == 0 or not question or not options then
		videoId = 0
		videoPopup.Visible = false
		return
	end
	videoId = id
	videoDeadline = os.clock() + (seconds or 6)
	videoTitle.Text = "🎧 화상회의 중… 질문이 들어왔어요! [1]·[2]·[3]"
	videoQuestion.Text = `🗣️ "{question}"`
	for i, b in videoButtons do
		b.Text = `[{i}] {options[i]}`
	end
	videoPopup.Visible = true
	Sounds.play("ping", 0.7, 1.6)
end)
-- 숫자 키로도 대답 (질문이 떠 있을 때만, 행동 단축키보다 먼저)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or videoId == 0 then
		return
	end
	local index = table.find({ Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }, input.KeyCode)
	if index then
		Remotes.VideoAnswer:FireServer(videoId, index)
		Sounds.play("click", 0.5)
		videoId = 0
		videoPopup.Visible = false
	end
end)
RunService.Heartbeat:Connect(function()
	if videoPopup.Visible then
		local left = math.max(0, videoDeadline - os.clock())
		videoTimer.Size = UDim2.new(left / 6, 0, 0, 6)
		videoTimer.BackgroundColor3 = if left < 2 then COLORS.bad else Color3.fromRGB(90, 160, 255)
	end
end)

-- 🚪 어색한 엘리베이터 (부장님과 단둘이 타면 미니게임)
--   📱 폰 보기 [1] / 🙂 앞 보기 [2] 버튼
--   👀 쳐다보면 → 📱 폰 / 🗣️ 말 걸면 → 🙂 앞 보기 (틀리면 무조건 경고)
local elevatorGui = Ui.make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 45,
	Parent = gui,
})
for _, anchorY in { 0, 1 } do -- 영화처럼 위아래 검은 띠
	Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, anchorY),
		Position = UDim2.fromScale(0, anchorY),
		Size = UDim2.new(1, 0, 0.1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		ZIndex = 45,
		Parent = elevatorGui,
	})
end
local elevatorTitle = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.02, 0),
	Size = UDim2.fromOffset(600, 34),
	TextSize = 26,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 46,
	Parent = elevatorGui,
})
-- 가운데 게임 판
local elevatorBoard = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(520, 300),
	BackgroundColor3 = Color3.fromRGB(20, 22, 30),
	BackgroundTransparency = 0.1,
	ZIndex = 46,
	Parent = elevatorGui,
}, { Ui.corner(14), Ui.stroke(Color3.fromRGB(255, 200, 80), 2), Ui.padding(12) })
local elevatorRules = text({
	Size = UDim2.new(1, 0, 0, 44),
	TextSize = 16,
	TextWrapped = true,
	RichText = true,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 47,
	Parent = elevatorBoard,
})
-- 부장님 상태 (크게)
local bossState = text({
	Position = UDim2.fromOffset(0, 50),
	Size = UDim2.new(1, 0, 0, 70),
	TextSize = 40,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 47,
	Parent = elevatorBoard,
})
local bossHint = text({
	Position = UDim2.fromOffset(0, 122),
	Size = UDim2.new(1, 0, 0, 26),
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 47,
	Parent = elevatorBoard,
})
-- 내 행동 = 버튼 두 개 (지금 하고 있는 쪽이 밝게 켜져요)
local phoneButton = Ui.button({
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 0, 1, 0),
	Size = UDim2.new(0.5, -6, 0, 84),
	TextSize = 24,
	ZIndex = 47,
	Parent = elevatorBoard,
})
local frontButton = Ui.button({
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, 0, 1, 0),
	Size = UDim2.new(0.5, -6, 0, 84),
	TextSize = 24,
	ZIndex = 47,
	Parent = elevatorBoard,
})
local elevatorRide: any = nil
local phoneOn = false
local function showMyState()
	phoneButton.Text = (if phoneOn then "✅ " else "") .. "📱 폰 보기\n[1]"
	frontButton.Text = (if phoneOn then "" else "✅ ") .. "🙂 앞 보기\n[2]"
	phoneButton.BackgroundColor3 = if phoneOn then Color3.fromRGB(90, 160, 255) else Color3.fromRGB(60, 62, 72)
	frontButton.BackgroundColor3 = if phoneOn then Color3.fromRGB(60, 62, 72) else Color3.fromRGB(255, 200, 80)
	phoneButton.TextColor3 = if phoneOn then Color3.new(1, 1, 1) else Color3.fromRGB(170, 170, 170)
	frontButton.TextColor3 = if phoneOn then Color3.fromRGB(170, 170, 170) else Color3.fromRGB(30, 30, 30)
end
local function choose(phone: boolean)
	if not elevatorRide or not elevatorRide.withBoss or phoneOn == phone then
		return
	end
	phoneOn = phone
	showMyState()
	Remotes.ElevatorDodge:FireServer(phoneOn, workspace:GetServerTimeNow())
	Sounds.play("click", 0.5, if phoneOn then 1.3 else 0.9)
end
phoneButton.Activated:Connect(function()
	choose(true)
end)
frontButton.Activated:Connect(function()
	choose(false)
end)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not elevatorRide then
		return
	end
	if input.KeyCode == Enum.KeyCode.One then
		choose(true)
	elseif input.KeyCode == Enum.KeyCode.Two then
		choose(false)
	elseif input.KeyCode == Enum.KeyCode.F then -- (예전처럼 F로 바꾸기도 돼요)
		choose(not phoneOn)
	end
end)

local KIND_TEXT = {
	look = { warn = "⚠️ 부장님이 고개를 돌리려 해요!", now = "👀 쳐다봐요!", need = "→ 📱 폰을 봐야 해요!" },
	talk = { warn = "⚠️ 부장님이 헛기침을 해요…", now = "🗣️ 말을 걸어요!", need = "→ 🙂 앞을 봐야 해요!" },
}

Remotes:WaitForChild("ElevatorRide").OnClientEvent:Connect(function(info)
	if info.result == "ok" then
		bossHint.Text = if info.kind == "look" then "📱 (폰 화면만 뚫어져라…) 휴, 안 마주쳤다!" else "🙂 \"네, 부장님!\" 휴, 잘 넘겼다!"
		bossHint.TextColor3 = COLORS.good
		Sounds.play("ping", 0.5, 1.3)
		return
	elseif info.result == "fail" then
		bossHint.Text = (if info.kind == "look" then "😳 눈이 마주쳤다…!" else "😡 \"어른이 말하는데 폰을 봐?!\"") .. ` 의심도 +{info.suspicion or 0}`
		bossHint.TextColor3 = COLORS.bad
		Sounds.play("caught", 0.6)
		flash.BackgroundTransparency = 0.5
		TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
		return
	end
	elevatorRide = info
	Hud.inElevator = true -- 🚪 숫자 키는 폰/앞 보기에 써요
	phoneOn = false
	showMyState()
	elevatorGui.Visible = true
	elevatorBoard.Visible = info.withBoss
	elevatorRules.Text = "<b>👀 쳐다보면</b> → 📱 폰 보기     <b>🗣️ 말 걸면</b> → 🙂 앞 보기\n<font color=\"#FF7A7A\">틀릴 때마다 의심도 +"
		.. SalaryConfig.ELEVATOR_FAIL
		.. "</font>"
	bossState.Text = "😐"
	bossHint.Text = "부장님이랑 단둘이 탔다… 어색하다."
	bossHint.TextColor3 = COLORS.warn
	Sounds.play("ping", 0.5, 0.8)
	task.spawn(function()
		while elevatorRide == info do
			local elapsed = workspace:GetServerTimeNow() - info.start
			local left = math.max(0, math.ceil(info.duration - math.max(0, elapsed)))
			elevatorTitle.Text = (if info.toRoof then "🚪 ▲ 옥상으로 올라가는 중" else "🚪 ▼ 사무실로 내려가는 중") .. ` ({left}초)`
			if info.withBoss then
				if elapsed < 0 then
					bossState.Text = `😐 준비… {math.ceil(-elapsed)}`
				else
					-- 지금 부장님이 뭘 하려는지
					local shown = false
					for _, event in info.events do
						local texts = KIND_TEXT[event.kind]
						if elapsed >= event.t - info.warn and elapsed < event.t then
							bossState.Text = texts.warn
							bossState.TextColor3 = COLORS.warn
							bossHint.Text = texts.need
							bossHint.TextColor3 = COLORS.warn
							shown = true
						elseif elapsed >= event.t and elapsed < event.t + 0.7 then
							bossState.Text = texts.now
							bossState.TextColor3 = COLORS.bad
							shown = true
						end
					end
					if not shown then
						bossState.Text = "😐 (층 숫자만 쳐다보는 중)"
						bossState.TextColor3 = Color3.new(1, 1, 1)
					end
				end
			end
			if elapsed >= info.duration then
				break
			end
			task.wait()
		end
		if elevatorRide == info then
			elevatorRide = nil
			Hud.inElevator = false
			elevatorGui.Visible = false
			Sounds.play("ping", 0.6, 1.1)
		end
	end)
end)

-- 🚪 띵! 부장님이 옥상으로 올라와요
Remotes:WaitForChild("RoofAlert").OnClientEvent:Connect(function(seconds: number)
	Sounds.play("ping", 0.8, 0.9)
	task.delay(0.3, function()
		Sounds.play("ping", 0.8, 0.7)
	end)
	Hud.popup(`🚪 띵… 엘리베이터가 올라와요! {seconds}초 뒤 도착`, COLORS.bad, 3)
	Ui.toast("🚪 부장님이 옥상으로 올라와요! 보이면 의심도가 차요. 물탱크·실외기 뒤에 숨어요 (부장님이 돌아다녀요)")
end)

-- 🖥️ 컴퓨터 자동 감지 시스템 경보 (자리 부재 70%)
Remotes:WaitForChild("AwayAlert").OnClientEvent:Connect(function()
	for i = 0, 2 do
		task.delay(i * 0.35, function()
			Sounds.play("ping", 0.7, 0.7)
		end)
	end
	flash.BackgroundTransparency = 0.6
	TweenService:Create(flash, TweenInfo.new(1), { BackgroundTransparency = 1 }):Play()
	Hud.popup("🖥️ 장시간 입력 없음 감지!", COLORS.bad, 3)
	Ui.toast("🖥️ 컴퓨터 자동 감지 시스템: 장시간 일을 안 하고 있는 걸 발견했습니다! 빠르게 자리로 복귀하세요!")
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
