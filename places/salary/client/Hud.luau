-- 화면 표시: 시계, 돈과 직급, 의심도, 경고, 업무 진척도, 행동 버튼, 부장 발소리, 내 자리 표시

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SalaryConfig = require(Shared:WaitForChild("SalaryConfig"))
local Ui = require(Shared:WaitForChild("Ui"))

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

local saveText = text({
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 1, -8),
	Size = UDim2.fromOffset(300, 18),
	TextSize = 13,
	TextColor3 = Color3.fromRGB(200, 120, 110),
	TextStrokeTransparency = 0.5,
	Text = "💾 저장 꺼짐 (나가면 진행이 사라져요)",
	Visible = false,
	Parent = gui,
})

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
	Ui.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
})

local KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
}
local buttons: { [string]: TextButton } = {}

local function chooseAction(actionId: string)
	Remotes.SetAction:FireServer(actionId)
end

local function buttonText(index: number, actionId: string, unlocked: boolean): string
	local info = States[actionId]
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
		chooseAction(actionId)
	end)
	buttons[actionId] = button
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not actionPanel.Visible then
		return
	end
	local index = table.find(KEYS, input.KeyCode)
	if index and SalaryConfig.DeskActions[index] then
		chooseAction(SalaryConfig.DeskActions[index])
	end
end)

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

RunService.RenderStepped:Connect(function()
	-- 시계
	local minute = ReplicatedStorage:GetAttribute("SalaryMinute") or SalaryConfig.START_MINUTE
	local phase = ReplicatedStorage:GetAttribute("SalaryPhase")
	clockText.Text = string.format("🕘 %02d:%02d · %s%s", minute // 60, minute % 60, ReplicatedStorage:GetAttribute("SalaryWeekday") or "", phaseName(phase))
	moodText.Text = `부장님 상태: {ReplicatedStorage:GetAttribute("SalaryMood") or "?"}`

	-- 직급과 경력
	local rankIndex = player:GetAttribute("Rank") or 1
	local rank = Ranks[rankIndex] or Ranks[1]
	rankText.Text = `🪪 {rank.name} {player.DisplayName}`
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
	warningText.Text = `경고 {string.rep("🟥", warnings)}{string.rep("⬜", math.max(0, SalaryConfig.MAX_WARNINGS - warnings))} ({warnings}/{SalaryConfig.MAX_WARNINGS})`
	local combo = player:GetAttribute("Combo") or 1
	comboText.Text = if combo > 1 then `🔥 아슬아슬 콤보 x{combo}` else ""

	-- 행동 버튼
	local seated = player:GetAttribute("Seated") == true
	local fired = player:GetAttribute("Fired") == true
	actionPanel.Visible = seated and not fired and phase ~= "offwork"
	local current = player:GetAttribute("SalaryAction") or "work"
	for i, actionId in SalaryConfig.DeskActions do
		local button = buttons[actionId]
		local unlocked = (States[actionId].unlockRank or 1) <= rankIndex
		local selected = actionId == current
		button.Text = buttonText(i, actionId, unlocked)
		button.BackgroundColor3 = if not unlocked then COLORS.locked elseif selected then C.brass else COLORS.idle
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
	Hud.popup(`😮‍💨 아슬아슬! +{comma(bonus)}원 (콤보 x{combo})`, COLORS.good, 2)
end)

Remotes:WaitForChild("Caught").OnClientEvent:Connect(function(line: string, warnings: number)
	flash.BackgroundTransparency = 0.4
	TweenService:Create(flash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
	Hud.popup(`🚨 적발! "{line}"`, COLORS.bad, 3)
	Ui.toast(`경고 {warnings}/{SalaryConfig.MAX_WARNINGS} · 시말서 감봉 -{comma(SalaryConfig.CAUGHT_PENALTY)}원`)
end)

Remotes:WaitForChild("Unlocked").OnClientEvent:Connect(function(emoji: string, name: string)
	Ui.toast(`📖 도감 등록! {emoji} {name}`)
end)

Remotes:WaitForChild("Notify").OnClientEvent:Connect(Ui.toast)

return Hud
