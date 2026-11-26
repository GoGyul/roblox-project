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
local Theme = require(Shared:WaitForChild("SalaryTheme"))

Ui.setTheme(Theme.UI, {
	corner = Theme.corner,
	buttonCorner = 14,
	stroke = Theme.Color.navy,
})

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local gui = Ui.gui
local C = Ui.COLORS
local States = SalaryConfig.States
local Ranks = SalaryConfig.Ranks

local Hud = {}

-- 폰처럼 터치만 되는 기기인가? (맨 위에 둬요: 아래에서 버튼을 만들 때부터 써요)
function Hud.isPhone(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

Hud.COLORS = {
	panel = Theme.Color.surface,
	good = Theme.Color.mint,
	warn = Theme.Color.yellow,
	bad = Theme.Color.coral,
	locked = Color3.fromRGB(214, 222, 228),
	idle = Theme.Color.skySoft,
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
	props.BackgroundTransparency = props.BackgroundTransparency or 0.04
	props.Parent = props.Parent or gui
	return Ui.make("Frame", props, { Ui.corner(18), Ui.padding(12), Ui.stroke(Theme.Color.navy, 2) })
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
		BackgroundColor3 = Color3.fromRGB(223, 230, 234),
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
	TextColor3 = Theme.Color.muted,
	TextXAlignment = Enum.TextXAlignment.Center,
	Parent = clockPanel,
})

-- 화면 가운데에 배경 없이 뜨는 글씨는 벽·바닥 색에 묻히지 않게 짙은 남색 테두리를 둘러요
local function outline(label: TextLabel)
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual -- 상자가 아니라 글씨에 테두리
	edge.Color = Theme.Color.navy
	edge.Thickness = 2.5
	edge.LineJoinMode = Enum.LineJoinMode.Round
	edge.Parent = label
end

local footstepText = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 78),
	Size = UDim2.fromOffset(420, 30),
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeTransparency = 1, -- (테두리는 outline()이 그려요)
	Visible = false,
	Parent = gui,
})
outline(footstepText)

-- 🎲 돌발 이벤트 안내 (발소리 표시 아래)
local eventText = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 110),
	Size = UDim2.fromOffset(560, 30),
	TextSize = 21,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeTransparency = 1, -- (테두리는 outline()이 그려요)
	Visible = false,
	Parent = gui,
})
outline(eventText)

-- 👀 이과장이 내 농땡이를 보고 있을 때 경고 (게이지가 다 차면 고자질!)
local leeText = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 142),
	Size = UDim2.fromOffset(460, 30),
	TextSize = 22,
	TextColor3 = Color3.fromRGB(255, 120, 120),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeTransparency = 1, -- (테두리는 outline()이 그려요)
	Visible = false,
	Parent = gui,
})
outline(leeText)

-- 🏢 출근하기 (하루가 시작되기 전, 이 버튼을 눌러야 9시가 돼요)
local clockIn = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.58),
	Size = UDim2.fromOffset(420, 196),
	BackgroundColor3 = Theme.Color.surface,
	BackgroundTransparency = 0.02,
	Visible = false,
	ZIndex = 20,
	Parent = gui,
}, { Ui.corner(22), Ui.stroke(Theme.Color.navy, 3) })
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
	TextColor3 = Theme.Color.muted,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 21,
	Parent = clockIn,
})
-- 출근 방식 두 가지: 🚏 걸어서(단지 버스 정류장에서 시작, 칼출근 보너스) / 🪑 바로 자리로(보너스 없음)
local clockInHint = text({
	Position = UDim2.fromOffset(0, 68),
	Size = UDim2.new(1, 0, 0, 20),
	TextSize = 13,
	TextColor3 = Theme.Color.muted,
	TextXAlignment = Enum.TextXAlignment.Center,
	Text = "걸어서 출근하면 8시 30분에 출발! 9시 10분까지 앉으면 칼출근 보너스 (9시 20분 넘으면 지각)",
	ZIndex = 21,
	Parent = clockIn,
})
local clockInButton = Ui.button({
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 14, 1, -14),
	Size = UDim2.fromOffset(192, 78),
	Text = "🚏 걸어서 출근\n(보너스)",
	TextSize = 20,
	ZIndex = 21,
	Parent = clockIn,
})
local clockInDeskButton = Ui.button({
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -14, 1, -14),
	Size = UDim2.fromOffset(192, 78),
	BackgroundColor3 = Theme.Color.skySoft,
	TextColor3 = Theme.Color.navy,
	Text = "🪑 바로 자리로\n(보너스 없음)",
	TextSize = 20,
	ZIndex = 21,
	Parent = clockIn,
})
local function sendClockIn(mode: string)
	if player:GetAttribute("ClockedIn") then
		return
	end
	Sounds.play("click", 0.6)
	Remotes.ClockIn:FireServer(mode)
end
clockInButton.Activated:Connect(function()
	sendClockIn("walk")
end)
clockInDeskButton.Activated:Connect(function()
	sendClockIn("desk")
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
		local walk = player:GetAttribute("ClockInWalk") == true
		clockInButton.Text = if walk then "✅ 걸어서 출근" else "🚏 걸어서 출근\n(보너스)"
		clockInDeskButton.Text = if walk then "🪑 바로 자리로\n(보너스 없음)" else "✅ 바로 자리로"
		clockInButton.BackgroundColor3 = Color3.fromRGB(110, 110, 120)
		clockInDeskButton.BackgroundColor3 = Color3.fromRGB(110, 110, 120)
		clockInInfo.Text = if left >= 0 then `동료 기다리는 중 ({count}) · {left}초 뒤 자동 출근` else `동료 기다리는 중 ({count})`
	else
		clockInButton.Text = "🚏 걸어서 출근\n(보너스)"
		clockInDeskButton.Text = "🪑 바로 자리로\n(보너스 없음)"
		clockInButton.BackgroundColor3 = C.brass
		clockInDeskButton.BackgroundColor3 = Theme.Color.skySoft
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
local rankText = text({ Size = UDim2.new(1, -18, 0, 22), TextSize = 19, TextScaled = true, RichText = true, TextColor3 = C.brass, Parent = moneyPanel })
Ui.make("UITextSizeConstraint", { MaxTextSize = 19, MinTextSize = 10, Parent = rankText }) -- (🏆 칭호까지 한 줄에: 길면 글씨를 줄여요)
local xpLabel, xpFill = bar(moneyPanel, 24, "")
local todayText = text({ Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 0, 22), TextSize = 19, TextColor3 = COLORS.warn, Parent = moneyPanel })
local totalText = text({ Position = UDim2.fromOffset(0, 88), Size = UDim2.new(1, 0, 0, 18), TextSize = 15, Parent = moneyPanel })

---------------------------------------------------------------------------
-- 🔔 알림 종 (직급 창 왼쪽): 서버가 Employees.pushNotice로 남긴 한 줄 알림 → "Notices" 속성(JSON)
--   안 읽은 게 있으면 빨간 숫자. 누르면 알림 목록(최신 20개)이 열리고 모두 읽음이 돼요.
---------------------------------------------------------------------------
local NOTICE_SHOWN = 20
local bellButton = Ui.button({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12 - 250 - 6, 0, 8),
	Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.15,
	Text = "🔔",
	TextSize = 24,
	Parent = gui,
})
Ui.stroke(Theme.Color.navy, 2).Parent = bellButton
local bellBadge = Ui.make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(1, -4, 0, 4),
	Size = UDim2.fromOffset(22, 22),
	BackgroundColor3 = Theme.Color.coral,
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBlack,
	TextSize = 13,
	Text = "!",
	Visible = false,
	ZIndex = 3,
	Parent = bellButton,
}, { Ui.corner(11) })
local noticeWindow = panel({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 150),
	Size = UDim2.fromOffset(320, 330),
	Visible = false,
	ZIndex = 25,
})
text({ Size = UDim2.new(1, -30, 0, 24), TextSize = 19, TextColor3 = C.brass, Text = "🔔 알림", ZIndex = 26, Parent = noticeWindow })
local noticeClose = Ui.make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 4, 0, -4),
	Size = UDim2.fromOffset(28, 28),
	BackgroundTransparency = 1,
	Text = "X", -- (✕ 기호는 로블록스 글꼴에 없어요)
	TextColor3 = C.text,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	ZIndex = 27,
	Parent = noticeWindow,
})
local noticeList = Ui.make("ScrollingFrame", {
	Position = UDim2.fromOffset(0, 30),
	Size = UDim2.new(1, 0, 1, -30),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	ZIndex = 26,
	Parent = noticeWindow,
}, { Ui.make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })

local function readNotices(): { any }
	local ok, list = pcall(function()
		return game:GetService("HttpService"):JSONDecode(player:GetAttribute("Notices") or "[]")
	end)
	return if ok and typeof(list) == "table" then list else {}
end

local function renderNotices()
	for _, child in noticeList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local list = readNotices()
	local shown = 0
	for i = #list, 1, -1 do -- 최신 것부터
		local notice = list[i]
		if typeof(notice) ~= "table" then
			continue
		end
		shown += 1
		if shown > NOTICE_SHOWN then
			break
		end
		local minute = tonumber(notice.min) or 0
		local stamp = `{notice.day or 1}일차 {string.format("%02d:%02d", math.floor(minute / 60), math.floor(minute % 60))}`
		local row = Ui.make("Frame", {
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = if notice.read then Theme.Color.surfaceSoft else Theme.Color.yellowSoft,
			BackgroundTransparency = 0,
			LayoutOrder = shown,
			ZIndex = 27,
			Parent = noticeList,
		}, { Ui.corner(6), Ui.padding(6), Ui.make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) })
		text({
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = 15,
			TextWrapped = true,
			Text = `{notice.e or "🔔"} {notice.t or ""}`,
			LayoutOrder = 1,
			ZIndex = 28,
			Parent = row,
		})
		text({
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 13),
			TextSize = 11,
			TextColor3 = Theme.Color.muted,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = stamp,
			ZIndex = 28,
			Parent = row,
		})
	end
	if shown == 0 then
		text({ Size = UDim2.new(1, 0, 0, 40), TextSize = 15, TextColor3 = Theme.Color.muted, Text = "아직 알림이 없어요", ZIndex = 27, Parent = noticeList })
	end
end

local function refreshBell()
	local unread = 0
	for _, notice in readNotices() do
		if typeof(notice) == "table" and notice.read ~= true then
			unread += 1
		end
	end
	bellBadge.Visible = unread > 0
	bellBadge.Text = if unread > 9 then "9+" else tostring(unread)
	if noticeWindow.Visible then
		renderNotices()
		if unread > 0 then
			Remotes:WaitForChild("NoticeRead"):FireServer() -- 열어 둔 채 새 알림이 와도 읽음
		end
	end
end

local function toggleNotices(open: boolean?)
	local show = if open == nil then not noticeWindow.Visible else open
	noticeWindow.Visible = show
	if show then
		renderNotices()
		Remotes:WaitForChild("NoticeRead"):FireServer()
		Sounds.play("click", 0.4)
	end
end
bellButton.Activated:Connect(function()
	toggleNotices()
end)
noticeClose.Activated:Connect(function()
	toggleNotices(false)
end)
player:GetAttributeChangedSignal("Notices"):Connect(function()
	local before = bellBadge.Visible and bellBadge.Text or ""
	refreshBell()
	if bellBadge.Visible and bellBadge.Text ~= before and not noticeWindow.Visible then
		Sounds.play("ping", 0.4, 1.4) -- 🔔 새 알림
	end
end)
refreshBell()

---------------------------------------------------------------------------
-- 왼쪽: 내 상태, 의심도, 업무, 경고
---------------------------------------------------------------------------
local STATUS_HEIGHT = 284 -- (아래에 🎒 들고 있는 것·버프 줄)
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
workLabel.TextScaled = true -- 직급이 높아 숫자가 길어져도 패널 밖으로 안 나가게
Ui.make("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 10, Parent = workLabel })
local awayLabel, awayFill = bar(statusPanel, 114, "") -- 🖥️ 자리 부재 게이지
local targetLabel, targetFill = bar(statusPanel, 154, "") -- 💰 하루 실적 목표 (사원부터)
local warningText = text({ Position = UDim2.fromOffset(0, 196), Size = UDim2.new(1, 0, 0, 22), Parent = statusPanel })
local comboText = text({
	Position = UDim2.fromOffset(0, 222),
	Size = UDim2.new(1, 0, 0, 20),
	TextSize = 15,
	TextScaled = true, -- 길어지면 글씨를 줄여서 패널 밖으로 안 나가게
	TextColor3 = COLORS.good,
	Parent = statusPanel,
})
Ui.make("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 9, Parent = comboText })
-- 🎒 들고 있는 것·버프 (선물·카페 음료·간식): 콤보 줄 아래 따로 한 줄
local extrasText = text({
	Position = UDim2.fromOffset(0, 244),
	Size = UDim2.new(1, 0, 0, 18),
	TextSize = 14,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(255, 220, 140),
	Parent = statusPanel,
})
Ui.make("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 9, Parent = extrasText })

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
local infoMode = "combo" -- "combo" 🔥 콤보 설명 / "speed" ⏩ 오늘의 의심도 속도 / "income" 💸 초당 수입 내역

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

-- 💸 지금 초당 수입 내역: 기본 수입에 무엇이 곱해지고 더해졌는지
local function refreshIncomeInfo()
	local ok, info = pcall(function()
		return game:GetService("HttpService"):JSONDecode(player:GetAttribute("IncomeParts") or "{}")
	end)
	info = if ok and typeof(info) == "table" then info else {}
	local rate = player:GetAttribute("IncomeRate") or 0
	local base = info.base or 0
	local lines = { `{info.name or "지금 행동"} 기본  <b>+{base}원/초</b>` }
	local running = base
	for _, part in (if typeof(info.parts) == "table" then info.parts else {}) do
		local label, kind, value = part[1], part[2], part[3]
		if kind == "+" then
			running += value
			table.insert(lines, `{label}  <font color="#7CE08A"><b>+{value}원</b></font>`)
		elseif kind == "×" then
			running *= value
			local color = if value >= 1 then "#7CE08A" else "#FF7A7A"
			table.insert(lines, `{label}  <font color="{color}"><b>×{value}</b></font>`)
		else
			running = 0
			table.insert(lines, `{label}  <font color="#FF7A7A"><b>수입 없음</b></font>`)
		end
	end
	local gap = rate - base
	local summary = if gap > 0.05 then `<font color="#7CE08A">기본보다 +{math.floor(gap * 10 + 0.5) / 10}원 더 벌어요</font>`
		elseif gap < -0.05 then `<font color="#FF7A7A">기본보다 {math.floor(gap * 10 + 0.5) / 10}원 덜 벌어요</font>`
		else `<font color="#9A9AA5">기본 그대로예요</font>`
	comboInfoText.Text = `<font size="18"><b>💸 지금 초당 수입 +{rate}원/초</b></font>\n`
		.. summary .. "\n\n"
		.. `<b>📋 계산</b>\n` .. table.concat(lines, "\n")
		.. (if #(info.parts or {}) == 0 then "\n<font color=\"#9A9AA5\">붙은 효과가 없어요</font>" else "")
		.. `\n\n<font color="#7CE08A"><b>⬆️ 늘어나요:</b></font> 직급(농땡이만), 재입사 회차, 감사 기간(사무실 안 농땡이 ×2), 🌮 타코, 💻 컴활(일하기 +1), 단지 산책 장소·🌸 벚꽃`
		.. `\n<font color="#FF7A7A"><b>⬇️ 0이 돼요:</b></font> 🏖️ 반차, 🚏 출근길, 💡 정전(일하기·화면 농땡이)`
		.. `\n<font color="#9A9AA5">일하기는 직급 배율을 안 받아요. 명세서의 보너스(아슬아슬·수다·회의 등)는 여기 말고 따로 쌓여요</font>`
end

-- 📄 오늘 업무 게이지 설명
local function refreshWorkInfo()
	local work = math.floor(player:GetAttribute("WorkSeconds") or 0)
	local quota = player:GetAttribute("WorkQuota") or SalaryConfig.WORK_QUOTA
	local rank = SalaryConfig.Ranks[player:GetAttribute("Rank") or 1] or SalaryConfig.Ranks[1]
	comboInfoText.Text = `<font size="18"><b>📄 오늘 업무 {work}/{quota}초</b></font>\n`
		.. (if work >= quota then `<font color="#7CE08A"><b>✅ 오늘 업무 완료! 이제 마음껏 농땡이~</b></font>\n\n` else `퇴근까지 <b>{quota - work}초</b> 더 채워야 해요\n\n`)
		.. `<b>🪑 업무가 쌓이는 법</b>\n`
		.. `<b>내 자리에 앉아 있기만 하면</b> 1초에 1초씩 쌓여요!\n`
		.. `일하기든, 앉아서 하는 농땡이(멍때리기·웹툰·폰·쇼핑·꿀잠·간식…)든 똑같아요\n`
		.. `<font color="#9A9AA5">옥상·거리·화장실·탕비실·체력 단련실처럼 자리를 비우면 안 쌓여요</font>\n`
		.. `<font color="#7CE08A">☕ 아메리카노를 마시면 더 빨리 쌓여요</font>\n\n`
		.. `<b>📏 기준</b> {rank.name}: 하루 <b>{quota}초</b> (직급이 오를수록 늘어나요)\n`
		.. `<font color="#FF7A7A">🚨 퇴근 때 못 채웠으면 경고 1개 + 감봉 -{comma(rank.quotaPenalty or 0)}원</font>`
end

local function refreshComboInfo()
	if infoMode == "income" then
		refreshIncomeInfo()
		return
	end
	if infoMode == "speed" then
		refreshSpeedInfo()
		return
	elseif infoMode == "work" then
		refreshWorkInfo()
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
-- 💸 맨 위 행동 줄(예: "😶 멍때리기 +27원/초")을 누르면 초당 수입 내역
local incomeButton = Ui.make("TextButton", {
	Size = UDim2.new(1, 0, 0, 30),
	BackgroundTransparency = 1,
	Text = "",
	ZIndex = 5,
	Parent = statusPanel,
})
incomeButton.Activated:Connect(function()
	local same = infoMode == "income"
	infoMode = "income"
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
-- 📄 업무 줄을 누르면 업무 게이지 설명
local workButton = Ui.make("TextButton", {
	Position = UDim2.fromOffset(0, 72),
	Size = UDim2.new(1, 0, 0, 36),
	BackgroundTransparency = 1,
	Text = "",
	ZIndex = 5,
	Parent = statusPanel,
})
workButton.Activated:Connect(function()
	local same = infoMode == "work"
	infoMode = "work"
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
	-- 버튼을 바둑판으로: 한 줄에 네 개씩 아래로 줄을 바꿔요 (예전엔 가로 한 줄이라 메뉴를 펼치면 화면을 가로질렀어요)
	Ui.make("UIGridLayout", {
		CellSize = UDim2.fromOffset(58, 30),
		CellPadding = UDim2.fromOffset(6, 6),
		FillDirection = Enum.FillDirection.Horizontal,
		FillDirectionMaxCells = 4,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
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
	BackgroundColor3 = Theme.Color.surface,
	BackgroundTransparency = 0.06,
	TextStrokeTransparency = 1,
	Text = "🪑 ⭐ 내 자리에 앉으면 농땡이 메뉴가 나와요",
	Visible = false,
	Parent = gui,
})
Ui.corner(14).Parent = standHint
Ui.stroke(Theme.Color.navy, 2).Parent = standHint


local hintText = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0),
	Size = UDim2.new(1, 0, 0, 22),
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Center,
	BackgroundColor3 = Theme.Color.surface,
	BackgroundTransparency = 0.06,
	TextStrokeTransparency = 1,
	Parent = actionPanel,
})
Ui.corner(11).Parent = hintText
Ui.make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = hintText }) -- (글자 양옆 여백)
Ui.stroke(Theme.Color.navy, 1.5).Parent = hintText
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
-- 오른쪽 위 X 닫기 (게임을 안 고르고 창만 닫아요)
local phonePickerClose = Ui.make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 8, 0, -8),
	Size = UDim2.fromOffset(24, 24),
	BackgroundColor3 = Theme.Color.coralSoft,
	Text = "X",
	TextColor3 = Theme.Color.navy,
	Font = Enum.Font.GothamBlack,
	TextSize = 13,
	ZIndex = 22,
	Parent = phonePicker,
}, { Ui.corner(12) })
phonePickerClose.Activated:Connect(function()
	phonePicker.Visible = false
	hoveredPhoneGame = nil
end)
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

Hud.onShoppingAgain = nil :: (() -> ())? -- 🛒 쇼핑 중에 [쇼핑]을 또 누르면 쇼핑몰 다시 열기 (Panels가 채워요)
Hud.onWebtoonAgain = nil :: (() -> ())? -- 📺 웹툰 보는 중에 [웹툰]을 또 누르면 웹툰 창 다시 열기 (Webtoon이 채워요)
local function chooseAction(actionId: string)
	if actionId == "webtoon" and player:GetAttribute("SalaryState") == "webtoon" and Hud.onWebtoonAgain then
		Hud.onWebtoonAgain()
		return
	end
	if actionId == "shopping" and player:GetAttribute("SalaryState") == "shopping" and Hud.onShoppingAgain then
		Hud.onShoppingAgain()
		return
	end
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
		return if Hud.isPhone() then `<font size="20">{snack.emoji}</font>\n{percent}%` else `<font size="22">{snack.emoji}</font>\n[{index}] {percent}%`
	end
	if not unlocked then
		return `<font size="22">🔒</font>\n[{index}]`
	end
	if Hud.isPhone() then
		return `<font size="20">{info.emoji}</font>\n+{info.income}` -- 📱 숫자 키가 없으니 번호는 빼요
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
	if Hud.isPhone() then
		return `{info.emoji} {info.name} · +{info.income}원/초{returnText}` -- 📱 짧게
	end
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
	if gameProcessed or not actionPanel.Visible or player:GetAttribute("ScreenHidden") or videoPopupOpen() or Hud.inElevator or Hud.numberGame or Hud.chatReactOpen then
		return
	end
	local index = table.find(KEYS, input.KeyCode)
	if index and SalaryConfig.DeskActions[index] then
		chooseAction(SalaryConfig.DeskActions[index])
	end
end)

---------------------------------------------------------------------------
-- 📱 폰 전용 상단 띠: 큰 창 세 개(상태·시계·직급) 대신 얇은 칩 한 줄(세로 화면은 두 줄)
--   👔 직급 칩을 누르면 원래 창 세 개가 자세히 보기로 펼쳐져요 (다시 누르면 접혀요)
--   PC에서는 만들기만 하고 숨겨 둬요.
---------------------------------------------------------------------------
local phone = { detail = false, bottom = 0 } -- (지역 변수 개수를 아끼려고 표 하나에 모아요)
phone.strip = Ui.make("Frame", { Size = UDim2.fromScale(1, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 30, Parent = gui })
function phone.chip(withBar: boolean, button: boolean?): (GuiObject, TextLabel | TextButton, Frame?)
	local frame = Ui.make(if button then "TextButton" else "Frame", {
		Size = UDim2.fromOffset(90, 30),
		BackgroundColor3 = COLORS.panel,
		BackgroundTransparency = 0.06,
		ZIndex = 30,
		Parent = phone.strip,
	}, { Ui.corner(10), Ui.stroke(Theme.Color.navy, 1.5) })
	if button then
		local asButton = frame :: TextButton
		asButton.Text = ""
		asButton.AutoButtonColor = true
	end
	local label = text({
		Position = UDim2.fromOffset(7, 0),
		Size = UDim2.new(1, -14, 1, if withBar then -6 else 0),
		TextSize = 13,
		TextScaled = true,
		RichText = true,
		ZIndex = 31,
		Parent = frame,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8, Parent = label })
	local fill: Frame? = nil
	if withBar then
		local back = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 7, 1, -4),
			Size = UDim2.new(1, -14, 0, 4),
			BackgroundColor3 = Color3.fromRGB(223, 230, 234),
			ZIndex = 31,
			Parent = frame,
		}, { Ui.corner(2) })
		fill = Ui.make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = COLORS.good, ZIndex = 32, Parent = back }, { Ui.corner(2) })
	end
	return frame, label, fill
end
phone.clock, phone.clockLabel = phone.chip(false)
phone.susp, phone.suspLabel, phone.suspFill = phone.chip(true)
phone.work, phone.workLabel, phone.workFill = phone.chip(true)
phone.money, phone.moneyLabel = phone.chip(false)
phone.rank, phone.rankLabel = phone.chip(false, true)
phone.rankLabel.TextXAlignment = Enum.TextXAlignment.Center
-- 🔦 순찰 남은 시간 (PC·폰 공통)
phone.patrolText = text({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 172),
	Size = UDim2.fromOffset(460, 30),
	TextSize = 22,
	TextColor3 = Color3.fromRGB(255, 226, 120),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextStrokeTransparency = 1,
	Visible = false,
	Parent = gui,
})
outline(phone.patrolText)

-- 화면이 좁으면 창을 통째로 줄여서 글자·버튼이 화면 밖으로 잘리지 않게 해요 (출근 선택·수다·화상회의 창 등)
function Hud.fitWidth(frame: GuiObject, width: number)
	local scale = Ui.make("UIScale", { Parent = frame })
	local function fit()
		scale.Scale = math.clamp((gui.AbsoluteSize.X - 16) / width, 0.5, 1)
	end
	fit()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
end
Hud.fitWidth(clockIn, 420)

---------------------------------------------------------------------------
-- 📱 화면 크기에 따라 배치 바꾸기
--   큰 화면(PC): 원래 배치
--   작은 화면(폰·작은 창): 패널을 줄이고, 행동 버튼은 2줄로 위쪽에, 서로 겹치지 않게
---------------------------------------------------------------------------
local scales = {}
for _, frame in { clockPanel, moneyPanel, statusPanel, Hud.toolbar, actionPanel, missionPanel, bellButton, noticeWindow } do
	scales[frame] = Ui.make("UIScale", { Parent = frame })
end

-- 작은 화면인가? (패널을 줄여요)
Hud.smallMode = false -- 🗕 [H]로 켜는 "작은 화면 표시": 큰 화면에서도 창들을 70% 크기로 줄여 게임 화면을 넓게 봐요
function Hud.isCompact(): boolean
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return Hud.smallMode or Hud.isPhone() or viewport.X < 1000 or viewport.Y < 560
end

local function applyLayout()
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local compact = Hud.isCompact()
	local grid = buttonRow:FindFirstChild("Grid") :: UIGridLayout
	local small = if compact then 0.7 else 1
	local phoneMode = Hud.isPhone()
	local guiSize = gui.AbsoluteSize
	if guiSize.X < 50 then
		guiSize = viewport -- (막 들어왔을 때는 아직 0일 수 있어요)
	end
	local landscape = guiSize.X > guiSize.Y and guiSize.X >= 560

	-- 📱 폰: 상단 띠 배치 (가로 = Roblox 버튼 오른쪽 한 줄 / 세로·좁은 화면 = 직급 칩은 위, 나머지는 두 줄)
	phone.strip.Visible = phoneMode
	if phoneMode then
		local inset = game:GetService("GuiService"):GetGuiInset().Y -- Roblox 상단 버튼 줄 높이 (우리 화면은 그 아래에서 시작해요)
		-- (Roblox 버튼과 같은 높이에 맞춰요: 버튼 줄의 가운데는 상단 여백의 57%쯤)
		local barY = if inset >= 34 then -inset + math.floor(inset * 0.57) - 14 else 4
		local barX = if inset >= 34 then 215 else 6 -- (왼쪽 위는 Roblox 버튼 자리)
		local barWidth = guiSize.X - barX - 8
		local gap = 5
		if barWidth >= 86 + 118 + 78 + 2 * 60 + 4 * gap then
			-- 한 줄: 시각 · 의심 · 업무 · 돈 · 직급 (가운데 두 칩이 남는 폭을 나눠 가져요, 너무 길어지지는 않게)
			local flexible = math.min(150, math.floor((barWidth - 86 - 118 - 78 - 4 * gap) / 2))
			local x = guiSize.X - 8 - (86 + 118 + 78 + 2 * flexible + 4 * gap) -- 오른쪽 끝에 붙여요
			for _, item in { { phone.clock, 86 }, { phone.susp, flexible }, { phone.work, flexible }, { phone.money, 118 }, { phone.rank, 78 } } do
				item[1].Position = UDim2.fromOffset(x, barY)
				item[1].Size = UDim2.fromOffset(item[2], 28)
				x += item[2] + gap
			end
			phone.bottom = math.max(0, barY + 28) + 4
		else
			-- 두 줄: (위) 직급 칩은 Roblox 버튼 오른쪽 / (1줄) 시각 + 의심 / (2줄) 업무 + 돈
			local top = 4
			if inset >= 34 and barWidth >= 80 then
				phone.rank.Position = UDim2.fromOffset(barX, barY)
				phone.rank.Size = UDim2.fromOffset(math.min(barWidth, 130), 30)
			else
				phone.rank.Position = UDim2.fromOffset(6, top)
				phone.rank.Size = UDim2.fromOffset(guiSize.X - 12, 28)
				top += 32
			end
			local full = guiSize.X - 12
			phone.clock.Position = UDim2.fromOffset(6, top)
			phone.clock.Size = UDim2.fromOffset(96, 30)
			phone.susp.Position = UDim2.fromOffset(6 + 96 + gap, top)
			phone.susp.Size = UDim2.fromOffset(full - 96 - gap, 30)
			phone.work.Position = UDim2.fromOffset(6, top + 34)
			phone.work.Size = UDim2.fromOffset(full - 130 - gap, 30)
			phone.money.Position = UDim2.fromOffset(6 + full - 130, top + 34)
			phone.money.Size = UDim2.fromOffset(130, 30)
			phone.bottom = top + 34 + 30 + 4
		end
	end
	-- 큰 창 세 개는 폰에서는 "자세히 보기"를 켰을 때만
	local showPanels = not phoneMode or phone.detail
	statusPanel.Visible = showPanels
	clockPanel.Visible = showPanels
	moneyPanel.Visible = showPanels

	local top = if compact then 0.7 else 0.88 -- (시계·직급 창은 큰 화면에서도 조금 작게)
	scales[clockPanel].Scale = top
	-- 🎲 돌발 이벤트 안내 줄은 화면 맨 위(시계 창 위)에 띄워요: 화면 가운데를 가리지 않게.
	--    안내 줄이 떠 있는 동안만 시계 창과 그 아래 글씨들이 한 줄만큼 내려가요.
	local banner = if eventText.Visible then (if compact then 22 else 28) else 0
	eventText.Position = UDim2.new(0.5, 0, 0, if compact then 2 else 4)
	eventText.TextSize = if compact then 15 else 19
	eventText.Size = UDim2.fromOffset(560, 30)
	eventText.TextWrapped = false
	clockPanel.Position = UDim2.new(0.5, 0, 0, (if compact then 4 else 8) + banner)
	local below = (if compact then 4 else 8) + banner + math.floor(clockPanel.AbsoluteSize.Y) + 6 -- 시계 창 바로 아래
	if phoneMode then
		-- 📱 돌발 이벤트 안내는 띠 바로 아래 두 줄까지 (양옆 버튼 자리는 비워요), 발소리·이과장 경고는 그 아래
		banner = if eventText.Visible then 36 else 0
		eventText.Position = UDim2.new(0.5, 0, 0, phone.bottom)
		eventText.Size = UDim2.fromOffset(math.min(guiSize.X - 100, 520), 34)
		eventText.TextWrapped = true
		eventText.TextSize = 13
		below = phone.bottom + banner
		if phone.detail then
			below += 56 -- (자세히 보기의 시계 창 아래로)
		end
	end
	footstepText.Position = UDim2.new(0.5, 0, 0, below)
	footstepText.TextSize = if compact then 17 else 22
	leeText.Position = UDim2.new(0.5, 0, 0, below + (if compact then 22 else 30))
	leeText.TextSize = if compact then 17 else 22
	if phoneMode then
		footstepText.TextSize = 15
		leeText.TextSize = 14
	end

	scales[moneyPanel].Scale = top
	moneyPanel.Position = UDim2.new(1, if compact then -6 else -12, 0, if compact then 4 else 8)
	-- 🔔 알림 종은 직급 창 바로 왼쪽, 알림 창은 직급 창 아래
	scales[bellButton].Scale = small
	bellButton.Position = UDim2.new(1, (if compact then -6 else -12) - math.floor(moneyPanel.AbsoluteSize.X) - 6, 0, if compact then 4 else 8)
	scales[noticeWindow].Scale = small
	noticeWindow.Position = UDim2.new(1, if compact then -6 else -12, 0, (if compact then 4 else 8) + math.floor(moneyPanel.AbsoluteSize.Y) + 8)
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
	local toolbarLayout = Hud.toolbar:FindFirstChildOfClass("UIGridLayout")
	Hud.toolbar.Size = UDim2.fromOffset(250, 40)
	if toolbarLayout then
		toolbarLayout.FillDirectionMaxCells = 4 -- (PC: 상태 창 폭에 맞춰 네 개씩)
	end
	if phoneMode then
		-- 📱 자세히 보기: 띠 아래에 창 세 개를 펼쳐요 (가로 = 왼쪽·가운데·오른쪽 / 세로 = 왼쪽·오른쪽 위아래)
		local y = phone.bottom
		statusPanel.Position = UDim2.new(0, 6, 0, y)
		moneyPanel.Position = UDim2.new(1, -48, 0, y)
		clockPanel.Position = if landscape then UDim2.new(0.5, 0, 0, y) else UDim2.new(1, -48 - 105, 0, y + math.floor(moneyPanel.AbsoluteSize.Y) + 6)
		-- 🔔 알림 종은 오른쪽 세로 줄 맨 위, 알림 창·프로젝트 카드는 그 왼쪽
		scales[bellButton].Scale = 0.8
		bellButton.Position = UDim2.new(1, -6, 0, y + 2)
		noticeWindow.Position = UDim2.new(1, -48, 0, y + 2)
		missionPanel.Position = UDim2.new(1, -48, 0, y + 2 + (if phone.detail then math.floor(moneyPanel.AbsoluteSize.Y) + 6 else 0))
		-- 메뉴 버튼은 띠 아래 왼쪽
		Hud.toolbar.Position = UDim2.new(0, 6, 0, y + 2 + (if phone.detail then math.floor(STATUS_HEIGHT * small) + 4 else 0))
		local toolbarWidth = math.floor((guiSize.X - 60) / 0.85)
		Hud.toolbar.Size = UDim2.fromOffset(toolbarWidth, 40)
		if toolbarLayout then
			toolbarLayout.FillDirectionMaxCells = math.max(4, math.floor((toolbarWidth + 6) / 64)) -- 📱 화면 폭만큼
		end
	end

	-- 행동 버튼
	--   폰: 4개씩 2줄 큰 버튼, 조이스틱·점프 버튼과 겹치지 않게 위로
	--   PC: 화면 크기와 상관없이 1줄 작은 버튼, 맨 아래에 붙여서 게임 화면을 덜 가리게
	-- 보이는 버튼(잠긴 행동은 숨겨요) 개수에 맞춰서 배치
	local visibleCount = 0
	for _, button in buttons do
		if button.Visible then
			visibleCount += 1
		end
	end
	visibleCount = math.max(visibleCount, 1)
	local columns = visibleCount
	local cellWidth = if phoneMode then 48 else 62
	local cellHeight = if phoneMode then 48 else 54
	-- 📱 폰: 가로 화면은 조이스틱과 점프 버튼 사이, 세로 화면은 조작 버튼 위에. 한 줄에 안 들어가면 줄을 늘려요
	local available = if landscape then guiSize.X - 2 * 175 else guiSize.X - 12
	if phoneMode then
		columns = math.clamp(math.floor((available + 5) / (cellWidth + 5)), 3, visibleCount)
	end
	local rows = math.ceil(visibleCount / columns)
	grid.FillDirectionMaxCells = columns
	grid.CellSize = UDim2.fromOffset(cellWidth, cellHeight)
	local cellGap = if phoneMode then 5 else 6
	grid.CellPadding = UDim2.fromOffset(cellGap, cellGap)
	local width = columns * cellWidth + (columns - 1) * cellGap
	local height = rows * cellHeight + (rows - 1) * cellGap
	buttonRow.Size = UDim2.new(1, 0, 0, height)
	actionPanel.Size = UDim2.fromOffset(width, 22 + height)
	local bottomGap = if not phoneMode then 6 elseif landscape then 6 else 170 -- (세로 화면은 조이스틱·점프·달리기 버튼 위)
	actionPanel.Position = UDim2.new(0.5, 0, 1, -bottomGap)
	scales[actionPanel].Scale = math.clamp(((if phoneMode then guiSize.X else viewport.X) - 12) / width, 0.5, 1)
	if phoneMode then
		-- 📱 설명은 버튼 위 짧은 칩 한 줄
		hintText.AutomaticSize = Enum.AutomaticSize.X
		hintText.Size = UDim2.fromOffset(0, 20)
		hintText.TextSize = 12
	else
		-- 흰 띠는 글자 길이에 딱 맞게 (예전엔 720폭 고정이라 양옆이 휑했어요)
		hintText.AutomaticSize = Enum.AutomaticSize.X
		hintText.Size = UDim2.fromOffset(0, 20)
		hintText.TextSize = 16 -- (작다는 의견이 있어 키웠어요)
	end
	buttonRow.Position = UDim2.fromOffset(0, 22)
	for _, button in buttons do
		button.TextSize = 12
	end

	local barHeight = (22 + height) * scales[actionPanel].Scale
	standHint.Position = UDim2.new(0.5, 0, 1, if phoneMode then -(bottomGap + 2) else -24)
	standHint.TextSize = if phoneMode then 13 elseif compact then 15 else 17
	standHint.Size = if phoneMode then UDim2.fromOffset(math.min(guiSize.X - 12, 320), 26) else UDim2.fromOffset(520, 28)
	-- 안내 문구는 행동 버튼 위로
	Ui.setToastPosition(UDim2.new(0.5, 0, 1, -(bottomGap + barHeight + 10)))
end

---------------------------------------------------------------------------
-- 🗕 시계 창 · 직급 창 접기: 오른쪽 위 [–]를 누르면 첫 줄만 남기고 접어요 ([+]로 다시 펴기)
--   접으면 시계 창은 "시각 · 요일"만, 직급 창은 "직급 이름"만 보여요. 접은 상태는 나갈 때까지 유지돼요.
---------------------------------------------------------------------------
local function foldable(frame: Frame, keep: GuiObject, fullSize: UDim2, foldedSize: UDim2)
	local folded = false
	local toggle = Ui.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 8, 0, -8),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Theme.Color.surfaceSoft,
		TextColor3 = Theme.Color.navy,
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		Text = "–",
		ZIndex = 5,
		Parent = frame,
	})
	local hiddenByFold: { [GuiObject]: boolean } = {}
	toggle.Activated:Connect(function()
		folded = not folded
		Sounds.play("click", 0.4)
		toggle.Text = if folded then "+" else "–"
		frame.Size = if folded then foldedSize else fullSize
		frame:SetAttribute("Folded", folded) -- (다른 모듈이 이 창에 붙인 버튼도 접힌 동안은 숨기게)
		for _, child in frame:GetChildren() do
			-- 첫 줄(keep)·접기 버튼·창 밖에 붙은 버튼(이과장·감사관 소개 등)은 그대로 둬요
			if child:IsA("GuiObject") and child ~= keep and child ~= toggle and child.Position.X.Scale < 1 then
				if folded then
					if child.Visible then
						hiddenByFold[child] = true
						child.Visible = false
					end
				elseif hiddenByFold[child] then
					hiddenByFold[child] = nil
					child.Visible = true
				end
			end
		end
		task.defer(applyLayout) -- (알림 종·프로젝트 카드가 직급 창 크기에 맞춰 따라와요)
	end)
end
foldable(clockPanel, clockText, UDim2.fromOffset(300, 62), UDim2.fromOffset(300, 48))
foldable(moneyPanel, rankText, UDim2.fromOffset(250, 136), UDim2.fromOffset(250, 46))
foldable(missionPanel, missionTitle, UDim2.fromOffset(290, 196), UDim2.fromOffset(290, 48)) -- 📋 긴급 프로젝트 카드도 접을 수 있어요

Hud.relayout = function()
	task.defer(applyLayout)
end
applyLayout()
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout) -- 📱 폰을 돌리면 다시 배치
phone.rank.Activated:Connect(function()
	phone.detail = not phone.detail
	Sounds.play("click", 0.4)
	applyLayout()
	task.defer(applyLayout) -- (창이 보인 뒤의 크기로 한 번 더 맞춰요)
end)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyLayout)
	-- 🗕 [H] 화면 표시 크게/작게 (글자를 치는 중에는 동작하지 않아요)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.H then
			return
		end
		Hud.smallMode = not Hud.smallMode
		applyLayout()
		Hud.popup(if Hud.smallMode then "🗕 화면 표시를 작게 했어요 · [H]로 되돌리기" else "🗖 화면 표시를 원래 크기로 · [H]로 작게", COLORS.good, 2)
	end)
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
		message = `🔍 감사 기간 · 동료 중에 위장 감사관이! 📸 조심 · 수상하면 [E] 말 걸기 · 농땡이 수입 ×{SalaryConfig.AUDIT_INCOME}`
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
	if eventText.Visible ~= (message ~= nil) then
		eventText.Visible = message ~= nil
		Hud.relayout() -- (안내 줄이 생기거나 사라지면 시계 창 자리를 다시 맞춰요)
	end
	if message then
		if Hud.isPhone() then
			message = (string.gsub(message, "%[E%] ", "")) -- 📱 키보드 안내는 빼요
		end
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
	local frozenLeft = player:GetAttribute("MissionFrozenLeft")
	if typeof(frozenLeft) == "number" then
		left = frozenLeft -- ⏸️ 점심·이벤트로 시간이 멈춘 동안은 숫자가 움직이지 않아요
	end
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
	-- 🏆 내 칭호는 머리 위 대신 여기에 (머리 위 글씨가 내 화면을 가려서)
	local myTitle = SalaryConfig.getTitle(player:GetAttribute("Title") or "")
	rankText.Text = `👔 {rank.name} {player.DisplayName}` .. (if myTitle then ` <font size="13" color="#8A6A1F">· {myTitle.text}</font>` else "")
	local xp = player:GetAttribute("XP") or 0
	local nextXp = player:GetAttribute("NextXP") or 0
	if nextXp > 0 then
		local nextRank = Ranks[rankIndex + 1]
		xpLabel.Text = `📈 {nextRank.name} 승진까지 {comma(math.max(0, nextXp - xp))}`
		xpFill.Size = UDim2.fromScale(math.clamp((xp - rank.xp) / (nextXp - rank.xp), 0, 1), 1)
	else
		xpLabel.Text = "👑 최고 직급! 전설의 루팡"
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
	workLabel.Text = if work >= quota then "📄 오늘 업무 완료! ✅ ❓" else `📄 업무 {work}/{quota}초 · 🪑앉으면 ⬆️ ❓`
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
	if player:GetAttribute("HalfDay") == true then
		comboLine = "🏖️ 반차 중  " .. comboLine -- 🎟️ 반차권
	end
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
	-- 들고 있는 것·버프는 아래 줄로 (한 줄에 다 넣으면 패널 밖으로 삐져나와요)
	local extras = {}
	local gift = player:GetAttribute("HeldGift") or ""
	if gift ~= "" then
		table.insert(extras, `선물 {gift}`) -- 🎁 부장님께 드릴 선물
	end
	local buffs = player:GetAttribute("Buffs") or ""
	if buffs ~= "" then
		table.insert(extras, `버프 {buffs}`) -- 🏙️ 카페 음료
	end
	-- 🎁 경비원 매수: 남은 시간
	for _, info in { { "park", "👮박씨" }, { "park2", "👮한씨" }, { "park3", "👮정씨" }, { "roof", "👮옥상" } } do
		local untilTime = player:GetAttribute(`GuardBribe_{info[1]}`)
		if typeof(untilTime) == "number" then
			local left = math.ceil(untilTime - workspace:GetServerTimeNow())
			if left > 0 then
				table.insert(extras, `{info[2]} 못 본 척 {SalaryConfig.gameDurationText(SalaryConfig.secondsToGameMinutes(left))}`)
			end
		end
	end
	-- 🧺 점심 옥상 피크닉: 돗자리에 앉아 있는 동안 진행, 끝나면 그날 내내 ✅
	if player:GetAttribute("PicnicDone") then
		table.insert(extras, "🧺 피크닉 ✅")
	elseif typeof(player:GetAttribute("PicnicSit")) == "number" then
		table.insert(extras, `🧺 피크닉 {player:GetAttribute("PicnicSit")}/{SalaryConfig.PICNIC_SECONDS}초`)
	end
	local heldSnack = SalaryConfig.getSnack(player:GetAttribute("HeldSnack") or "")
	if heldSnack then
		local percent = math.floor((player:GetAttribute("SnackProgress") or 0) * 100)
		table.insert(extras, `{heldSnack.emoji} {heldSnack.name} {percent}%`)
	end
	comboText.Text = comboLine
	extrasText.Text = table.concat(extras, " · ")

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
		button.BackgroundTransparency = if selected then 0 else 0.08
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

	-- 🔦 순찰 중: 남은 시간 (이과장 경고 줄 바로 아래)
	local patrolUntil = player:GetAttribute("PatrolUntil")
	local patrolLeft = if typeof(patrolUntil) == "number" then patrolUntil - workspace:GetServerTimeNow() else 0
	phone.patrolText.Visible = patrolLeft > 0
	if patrolLeft > 0 then
		phone.patrolText.Position = leeText.Position + UDim2.fromOffset(0, leeText.TextSize + 12)
		phone.patrolText.TextSize = leeText.TextSize
		phone.patrolText.Text = `🔦 순찰 중 {math.ceil(patrolLeft)}초 · 딴짓하는 직원에게 말 걸기`
	end

	-- 📱 폰 상단 띠
	if phone.strip.Visible then
		local weekday = ReplicatedStorage:GetAttribute("SalaryWeekday") or ""
		local nextChar = utf8.offset(weekday, 2)
		phone.clockLabel.Text = string.format("🕘 %02d:%02d %s", minute // 60, minute % 60, if nextChar then string.sub(weekday, 1, nextChar - 1) else weekday)
		local speedNow = player:GetAttribute("SuspicionSpeed") or 1
		phone.suspLabel.Text = `🔍 의심 {suspicion}%` .. (if math.abs(speedNow - 1) > 0.005 then "  " .. speedText(speedNow) else "")
		phone.suspFill.Size = suspicionFill.Size
		phone.suspFill.BackgroundColor3 = suspicionFill.BackgroundColor3
		phone.workLabel.Text = if work >= quota then "📄 업무 완료 ✅" else `📄 업무 {work}/{quota}`
		phone.workFill.Size = workFill.Size
		phone.moneyLabel.Text = `💰 {comma(earnedToday)}원 <font color="#3FAE6A">+{rate}/초</font>`
		phone.rankLabel.Text = `👔 {rank.name} {if phone.detail then "–" else "+"}`
	end

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
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 45,
		Parent = gui,
	})
	outline(label)
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
			local edge = label:FindFirstChildOfClass("UIStroke")
			if edge then
				TweenService:Create(edge, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			end
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

-- 🛍️ 샀어요!: 화면 가운데에 크게 (창 아래 작은 초록 글씨만으로는 놓치기 쉬워요. "돈이 모자라요"와 같은 자리·같은 모양)
local boughtBanner: Frame? = nil
function Hud.bought(text: string)
	Sounds.play("ping", 0.6, 1.25)
	if boughtBanner then
		boughtBanner:Destroy()
	end
	local banner = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(460, 76),
		BackgroundColor3 = Color3.fromRGB(22, 58, 40),
		BackgroundTransparency = 0.08,
		ZIndex = 300,
		Parent = gui,
	}, { Ui.corner(14), Ui.stroke(Theme.Color.mint, 2) })
	boughtBanner = banner
	Ui.make("TextLabel", {
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Text = "🛍️ 구매 완료!",
		TextColor3 = Color3.fromRGB(224, 255, 236),
		Font = Enum.Font.GothamBlack,
		TextSize = 23,
		ZIndex = 301,
		Parent = banner,
	})
	Ui.make("TextLabel", {
		Position = UDim2.fromOffset(12, 40),
		Size = UDim2.new(1, -24, 0, 26),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = Color3.fromRGB(190, 240, 210),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextScaled = true, -- (긴 문구는 한 줄에 맞게 줄여요)
		ZIndex = 301,
		Parent = banner,
	}, { Ui.make("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 10 }) })
	local scale = Ui.make("UIScale", { Scale = 0.8, Parent = banner })
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(2.2, function()
		if boughtBanner == banner then
			boughtBanner = nil
		end
		banner:Destroy()
	end)
end

-- 💸 돈이 모자라요: 화면 가운데에 크게, 통장 금액도 빨갛게 깜빡 (창 안의 작은 글씨만으로는 놓치기 쉬워요)
local brokeBanner: Frame? = nil
Remotes:WaitForChild("Broke").OnClientEvent:Connect(function(need: number?)
	Sounds.play("bass", 0.7, 0.9)
	if brokeBanner then
		brokeBanner:Destroy()
	end
	local money = player:GetAttribute("TotalMoney") or 0
	local banner = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(340, if need then 72 else 48),
		BackgroundColor3 = Color3.fromRGB(60, 24, 28),
		BackgroundTransparency = 0.08,
		ZIndex = 300,
		Parent = gui,
	}, { Ui.corner(14), Ui.stroke(Theme.Color.coral, 2) })
	brokeBanner = banner
	Ui.make("TextLabel", {
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Text = "💸 돈이 모자라요!",
		TextColor3 = Color3.fromRGB(255, 226, 220),
		Font = Enum.Font.GothamBlack,
		TextSize = 23,
		ZIndex = 301,
		Parent = banner,
	})
	if need then
		Ui.make("TextLabel", {
			Position = UDim2.fromOffset(0, 40),
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			Text = `필요 {comma(need)}원 · 통장 {comma(money)}원 ({comma(math.max(0, need - money))}원 부족)`,
			TextColor3 = Color3.fromRGB(255, 200, 190),
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			ZIndex = 301,
			Parent = banner,
		})
	end
	-- 살짝 튀어나왔다가 2.2초 뒤 사라져요
	local scale = Ui.make("UIScale", { Scale = 0.8, Parent = banner })
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	-- 통장 금액 깜빡
	local original = totalText.TextColor3
	task.spawn(function()
		for _ = 1, 3 do
			totalText.TextColor3 = Theme.Color.coral
			task.wait(0.18)
			totalText.TextColor3 = original
			task.wait(0.14)
		end
	end)
	task.delay(2.2, function()
		if brokeBanner == banner then
			brokeBanner = nil
		end
		banner:Destroy()
	end)
end)

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
					.. ` · {max}장이면 퇴근 때 감봉 + 경고! 누가 찍었는지 찾아서 [E] 말 걸기`
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
Hud.fitWidth(videoPopup, 460)
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
		-- (같은 키를 책상 행동 단축키가 다시 쓰지 않게, 이번 입력이 다 처리된 뒤에 닫아요)
		task.defer(function()
			videoPopup.Visible = false
		end)
	end
end)
RunService.Heartbeat:Connect(function()
	if videoPopup.Visible then
		local left = math.max(0, videoDeadline - os.clock())
		videoTimer.Size = UDim2.new(left / 6, 0, 0, 6)
		videoTimer.BackgroundColor3 = if left < 2 then COLORS.bad else Color3.fromRGB(90, 160, 255)
	end
end)

-- 💬 수다 창: 수다 중에는 동료·내 대사가 여기에 차례로 보이고 (최근 3줄), 맞장구 보기 3개도 같은 창에 떠요
--   떠 있는 동안 숫자 키 1~3은 맞장구에 써요 (Hud.chatReactOpen)
Hud.chatReactOpen = false
local CHAT_LOG_LINES = 3
local chatReactBar = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 150),
	Size = UDim2.fromOffset(560, 134),
	BackgroundColor3 = Theme.Color.surface,
	BackgroundTransparency = 0.02,
	Visible = false,
	ZIndex = 40,
	Parent = gui,
}, { Ui.corner(20), Ui.stroke(Theme.Color.navy, 3), Ui.padding(12) })
Hud.fitWidth(chatReactBar, 560)
local chatReactTitle = text({ Size = UDim2.new(1, 0, 0, 20), TextSize = 15, TextColor3 = Theme.Color.navy, ZIndex = 41, Parent = chatReactBar })
-- 대사 기록 (위가 오래된 것, 아래가 방금 한 말)
local chatLogLabels: { TextLabel } = {}
local chatLog: { string } = {}
for i = 1, CHAT_LOG_LINES do
	chatLogLabels[i] = text({
		Position = UDim2.fromOffset(0, 24 + (i - 1) * 25),
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 17,
		RichText = true,
		TextScaled = true,
		ZIndex = 41,
		Parent = chatReactBar,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 17, MinTextSize = 11, Parent = chatLogLabels[i] })
end
local function renderChatLog()
	for i, label in chatLogLabels do
		local entry = chatLog[#chatLog - CHAT_LOG_LINES + i]
		label.Text = entry or ""
		label.TextTransparency = if i == CHAT_LOG_LINES then 0 else 0.35 -- (방금 한 말이 제일 진하게)
	end
end
local REACT_TOP = 24 + CHAT_LOG_LINES * 25 + 4
local CHAT_PAD = 12 * 2 + 6 -- 창 안쪽 여백(위아래 12씩) + 맨 아랫줄이 테두리에 잘리지 않게 여유
local chatReactTimer = Ui.make("Frame", {
	Position = UDim2.fromOffset(0, REACT_TOP),
	Size = UDim2.new(1, 0, 0, 5),
	BackgroundColor3 = Theme.Color.mint,
	BorderSizePixel = 0,
	ZIndex = 41,
	Parent = chatReactBar,
})
local chatReactButtons = {}
local chatReactId = 0
local chatReactDeadline = 0
local chatReactSeconds = 4
local chatName = "동료"
local chatEnded = false -- 👋 "오늘 대화 끝": 창은 남아 있다가 ✕·바깥 클릭·잠시 뒤에 닫혀요
local chatEndToken = 0
-- ✕ 닫기 (오늘 대화가 끝났을 때만 보여요)
local chatCloseButton = Ui.make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, -2),
	Size = UDim2.fromOffset(26, 24),
	BackgroundColor3 = Theme.Color.coral,
	Text = "X",
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBlack,
	TextSize = 14,
	Visible = false,
	ZIndex = 42,
	Parent = chatReactBar,
}, { Ui.corner(6) })
local function hideChatDialog()
	chatEnded = false
	chatCloseButton.Visible = false
	chatReactBar.Visible = false
	table.clear(chatLog)
	renderChatLog()
end
chatCloseButton.Activated:Connect(hideChatDialog)
local function setReactVisible(on: boolean)
	chatReactTimer.Visible = on
	for _, b in chatReactButtons do
		b.Visible = on
	end
	chatReactBar.Size = UDim2.fromOffset(560, (if on then REACT_TOP + 70 else REACT_TOP) + CHAT_PAD)
	chatReactTitle.Text = if on then `💬 {chatName}와(과) 수다 · 🗣️ 맞장구! [1]·[2]·[3]` elseif chatEnded then `💬 {chatName}와(과) 오늘 대화 끝 👋` else `💬 {chatName}와(과) 수다 중`
end
local function closeChatReact()
	chatReactId = 0
	Hud.chatReactOpen = false
	setReactVisible(false)
	-- 수다가 이어지는 중이면(또는 "오늘 대화 끝"을 보여 주는 중이면) 창은 남겨 둬요
	chatReactBar.Visible = (chatEnded or player:GetAttribute("SalaryState") == "chat") and #chatLog > 0
end
local function answerChatReact(index: number)
	if chatReactId == 0 then
		return
	end
	Remotes.ChatReactAnswer:FireServer(chatReactId, index)
	Sounds.play("click", 0.5)
	chatReactId = 0
	-- (같은 키를 다른 단축키가 다시 쓰지 않게, 이번 입력이 다 처리된 뒤에 닫아요)
	task.defer(closeChatReact)
end
for i = 1, 3 do
	local b = Ui.button({
		Position = UDim2.new((i - 1) / 3, if i == 1 then 0 else 3, 0, REACT_TOP + 12),
		Size = UDim2.new(1 / 3, -4, 0, 50),
		TextSize = 15,
		TextWrapped = true,
		ZIndex = 41,
		Parent = chatReactBar,
	})
	b.Activated:Connect(function()
		answerChatReact(i)
	end)
	chatReactButtons[i] = b
end
Remotes:WaitForChild("ChatReact").OnClientEvent:Connect(function(id: number, name: string?, options: { string }?, seconds: number?)
	if id == 0 or not options then
		closeChatReact()
		return
	end
	chatReactId = id
	chatReactSeconds = seconds or 4
	chatReactDeadline = os.clock() + chatReactSeconds
	chatName = name or chatName
	for i, b in chatReactButtons do
		b.Text = `[{i}] {options[i] or ""}`
	end
	setReactVisible(true)
	chatReactBar.Visible = true
	Hud.chatReactOpen = true
	Sounds.play("ping", 0.5, 1.8)
end)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or chatReactId == 0 then
		return
	end
	local index = table.find({ Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }, input.KeyCode)
	if index then
		answerChatReact(index)
	end
end)
RunService.Heartbeat:Connect(function()
	if chatReactBar.Visible then
		local left = math.max(0, chatReactDeadline - os.clock())
		chatReactTimer.Size = UDim2.new(left / chatReactSeconds, 0, 0, 5)
		chatReactTimer.BackgroundColor3 = if left < 1.5 then COLORS.bad else Color3.fromRGB(255, 190, 90)
		if left <= 0 and chatReactId ~= 0 then
			closeChatReact() -- 시간 초과 (서버도 알아서 처리해요)
		end
	end
end)
-- 💬 대사 한 줄 받기
Remotes:WaitForChild("ChatLine").OnClientEvent:Connect(function(kind: string, name: string, line: string)
	if chatName ~= name or (chatEnded and kind ~= "end") then
		table.clear(chatLog) -- 다른 동료와(또는 새로) 수다 시작
		chatEnded = false
		chatCloseButton.Visible = false
	end
	chatName = name
	local entry = if kind == "me"
		then `<font color="#287EAF"><b>나:</b></font> {line}`
		elseif kind == "sys" then `<font color="#237F70"><b>{line}</b></font>`
		elseif kind == "end" then `<font color="#C64E50"><b>{line}</b></font>`
		else `<font color="#A85B16"><b>{name}:</b></font> {line}`
	if kind == "end" then
		-- 👋 오늘 대화 끝: 창은 그대로 두고 ✕ / 바깥 클릭 / 8초 뒤에 닫혀요
		chatEnded = true
		chatCloseButton.Visible = true
		chatEndToken += 1
		local myToken = chatEndToken
		task.delay(8, function()
			if chatEnded and chatEndToken == myToken then
				hideChatDialog()
			end
		end)
	end
	table.insert(chatLog, entry)
	if #chatLog > 12 then
		table.remove(chatLog, 1)
	end
	renderChatLog()
	setReactVisible(chatReactId ~= 0)
	chatReactBar.Visible = true
end)
-- 다른 곳(화면 빈 곳)을 누르면 "오늘 대화 끝" 창을 닫아요
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if chatEnded and not gameProcessed and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		hideChatDialog()
	end
end)
-- 수다가 끝나면(다른 행동을 하면) 창을 닫고 기록도 지워요
player:GetAttributeChangedSignal("SalaryState"):Connect(function()
	if player:GetAttribute("SalaryState") ~= "chat" and chatReactId == 0 and not chatEnded then
		hideChatDialog() -- (들키거나 멀어져서 끊긴 거예요. "오늘 대화 끝"은 남겨 둬요)
	end
end)
-- 죽거나 다시 태어나면 닫아요
player.CharacterAdded:Connect(function()
	closeChatReact()
	hideChatDialog()
end)

-- 🏋️ 운동 게이지 (체력 단련실 기구 위에 있을 때만, 화면 아래쪽)
--   꽉 차면 그 기구의 스탯 +1 · 중간에 내리면 처음부터
--   (위쪽 시계 아래는 👞 부장님 발소리·이벤트 경고 자리라 가리지 않게 아래로)
do
	local gymPill = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -140),
		Size = UDim2.fromOffset(390, 40),
		BackgroundColor3 = Color3.fromRGB(20, 22, 30),
		BackgroundTransparency = 0.15,
		Visible = false,
		ZIndex = 40,
		Parent = gui,
	}, { Ui.corner(10), Ui.stroke(Color3.fromRGB(255, 200, 80), 1.5) })
	local gymLabel = text({
		Position = UDim2.fromOffset(6, 2),
		Size = UDim2.new(1, -12, 0, 18),
		TextSize = 14,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 41,
		Parent = gymPill,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 9, Parent = gymLabel })
	local gymTrack = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -5),
		Size = UDim2.new(1, -20, 0, 10),
		BackgroundColor3 = Color3.fromRGB(60, 62, 72),
		ZIndex = 41,
		Parent = gymPill,
	}, { Ui.corner(5) })
	local gymFill = Ui.make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(110, 210, 120),
		ZIndex = 42,
		Parent = gymTrack,
	}, { Ui.corner(5) })
	local shown = 0
	RunService.RenderStepped:Connect(function(dt)
		local machineId = player:GetAttribute("GymMachine") or ""
		local machine = SalaryConfig.GymMachines[machineId]
		local onGym = player:GetAttribute("SalaryState") == "gym" and machine ~= nil
		gymPill.Visible = onGym
		if not onGym then
			shown = 0
			return
		end
		-- 📅 오늘 스탯이 오르는 운동을 다 했으면 게이지 대신 안내 (운동은 계속 농땡이로 OK)
		local sets = player:GetAttribute("GymSets") or 0
		if sets >= SalaryConfig.GYM_DAILY_SETS then
			shown = 0
			gymFill.Size = UDim2.fromScale(0, 1)
			gymTrack.Visible = false
			gymLabel.Size = UDim2.new(1, 0, 1, 0)
			gymLabel.Position = UDim2.fromOffset(0, 0)
			gymLabel.Text = `💦 오늘 운동 끝 ({sets}/{SalaryConfig.GYM_DAILY_SETS})`
			return
		end
		gymTrack.Visible = true
		gymLabel.Size = UDim2.new(1, 0, 0, 18)
		gymLabel.Position = UDim2.fromOffset(0, 2)
		-- 서버 값(1초에 몇 번)을 부드럽게 따라가요
		local target = player:GetAttribute("GymProgress") or 0
		if target < shown - 0.3 then
			shown = target -- 꽉 차서 처음부터
		else
			shown += (target - shown) * math.min(1, dt * 8)
		end
		gymFill.Size = UDim2.fromScale(math.clamp(shown, 0, 1), 1)
		gymLabel.Text = `{machine.emoji} {math.floor(math.clamp(target, 0, 1) * 100)}% → {SalaryConfig.gymStatText(machineId)} +1 · {sets}/{SalaryConfig.GYM_DAILY_SETS}`
	end)
end

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
-- 이동 안내는 시계 바로 아래 작은 알약 모양으로 (다른 UI를 가리지 않게)
local elevatorPill = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 152), -- (가운데 이벤트 문구(74~130)와 겹치지 않게 그 아래로)
	Size = UDim2.fromOffset(300, 32),
	BackgroundColor3 = Theme.Color.surface,
	BackgroundTransparency = 0.04,
	ZIndex = 45,
	Parent = elevatorGui,
}, { Ui.corner(16), Ui.stroke(Theme.Color.navy, 2) })
local elevatorTitle = text({
	Size = UDim2.fromScale(1, 1),
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 46,
	Parent = elevatorPill,
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
Hud.fitWidth(elevatorBoard, 520)
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
			elevatorTitle.Text = (if info.toRoof then "🚪 ▲ 옥상으로 올라가는 중" elseif info.fromLobby then "🚪 ▲ 사무실로 올라가는 중" else "🚪 ▼ 사무실로 내려가는 중") .. ` ({left}초)`
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
						elseif elapsed >= event.t and elapsed < event.t + 1.5 then -- (결과는 조금 더 오래 보여 줘요)
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
	Ui.toast("🚪 부장님이 옥상에 와요! 물탱크·실외기 뒤에 숨어요")
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
	Ui.toast("🖥️ 빨리 자리로 복귀하세요!")
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
-- 📦 택배 뜯기 성공! → 축하 팝업 + 소리
Remotes:WaitForChild("Unboxed").OnClientEvent:Connect(function(label: string)
	Hud.popup(`🎉 📦 택배 개봉! {label}`, Color3.fromRGB(255, 215, 90), 3)
	Sounds.play("swoosh", 0.5)
	task.delay(0.15, function()
		Sounds.play("ping", 0.7, 1.3)
	end)
end)

---------------------------------------------------------------------------
-- 🔊 상황별 소리
---------------------------------------------------------------------------
Sounds.startMusic()
local typingLoop: Sound? = nil -- ⌨️ 일하기 중 반복 타자 소리는 거슬려서 껐어요 (다시 켜려면 Sounds.loop("typing", 0.12))
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
