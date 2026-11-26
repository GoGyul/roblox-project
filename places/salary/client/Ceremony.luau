-- 📜 승진식 + 👑 엔딩 연출
--
-- 퇴근 정산에서 승진하면 월급명세서 위에 "사령장"이 먼저 떠요.
--   사령장: 이전 직급 → 새 직급, 달라지는 것(기본급·배율·업무·목표·새로 열리는 것), 도장 쾅, 색종이
--   [감사합니다] → 닫히고 아래에 있던 명세서가 보여요.
-- 사장으로 취임한 날은 사령장 다음에 엔딩 "전설의 루팡"이 이어져요. (처음 한 번만. 그 뒤에도 계속 근무)
--
-- 🧪 스튜디오에서 미리 보기: SalaryConfig.TEST_CEREMONY = "promote" · "ending" · "retire"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SalaryConfig = require(Shared:WaitForChild("SalaryConfig"))
local Ui = require(Shared:WaitForChild("Ui"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Theme = require(Shared:WaitForChild("SalaryTheme"))

local player = Players.LocalPlayer
local gui = Ui.gui
local Ranks = SalaryConfig.Ranks
local States = SalaryConfig.States

local Ceremony = {}

local PAPER = Color3.fromRGB(255, 250, 235)
local INK = Theme.Color.navy
local GOLD = Color3.fromRGB(176, 132, 40)
local STAMP = Color3.fromRGB(214, 60, 50)

local function comma(n: number): string
	local digits = tostring(math.floor(math.abs(n)))
	local formatted = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return formatted
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local options = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = INK,
		TextSize = 16,
		TextWrapped = true,
		ZIndex = 92,
		Parent = parent,
	}
	for key, value in props do
		options[key] = value
	end
	return Ui.make("TextLabel", options)
end

-- 화면이 작으면 통째로 줄여서 폰에서도 잘리지 않게
local function fit(frame: Frame, width: number, height: number)
	local scale = Ui.make("UIScale", { Parent = frame })
	local function apply()
		local size = gui.AbsoluteSize
		scale.Scale = math.clamp(math.min((size.X - 24) / width, (size.Y - 24) / height), 0.4, 1)
	end
	apply()
	local connection = gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
	frame.Destroying:Connect(function()
		connection:Disconnect()
	end)
end

-- 🎊 색종이: 위에서 아래로 떨어져요
local function confetti(parent: Frame, count: number)
	local pieces = { "🎉", "🎊", "✨", "👏", "🥳", "💐" }
	for i = 1, count do
		local piece = label(parent, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(math.random(), 0, 0, -30),
			Size = UDim2.fromOffset(34, 34),
			Text = pieces[(i - 1) % #pieces + 1],
			TextSize = 26,
			ZIndex = 96,
		})
		task.delay(math.random() * 1.2, function()
			if piece.Parent then
				TweenService:Create(piece, TweenInfo.new(2.2 + math.random() * 1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
					Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.1, 0, 1, 40),
					Rotation = math.random(-180, 180),
				}):Play()
			end
		end)
	end
end

-- 새 직급에서 달라지는 것 (설정에서 그대로 읽어요)
local function changes(fromRank: number, toRank: number): { string }
	local before, after = Ranks[fromRank], Ranks[toRank]
	local lines = {
		`💰 기본급 {comma(before.basePay)} → {comma(after.basePay)}원`,
		`📈 농땡이 수입 ×{before.bonus} → ×{after.bonus}`,
		`📄 하루 업무 {before.quota} → {after.quota}초`,
	}
	if after.target > 0 then
		table.insert(lines, if before.target > 0 then `🎯 하루 실적 목표 {comma(before.target)} → {comma(after.target)}원` else `🎯 하루 실적 목표가 생겨요: {comma(after.target)}원`)
	end
	-- 새로 열리는 것 (건너뛴 직급이 있으면 그것까지)
	for rank = fromRank + 1, toRank do
		for _, actionId in SalaryConfig.DeskActions do
			local info = States[actionId]
			if info and info.unlockRank == rank then
				table.insert(lines, `🔓 새 농땡이: {info.emoji} {info.name}`)
			end
		end
		for _, company in SalaryConfig.Companies do
			if company.minRank == rank and rank > 1 then
				table.insert(lines, `🏢 {company.name}에서 스카우트 제의`)
			end
		end
		if rank == SalaryConfig.REVIEW_MIN_RANK then
			table.insert(lines, "📊 인사평가 대상이 돼요 (금요일 순위 발표)")
		end
		if rank == SalaryConfig.PATROL_RANK then
			table.insert(lines, "🔦 순찰을 나갈 수 있어요 (이제 내가 잡는 쪽!)")
		end
		if rank == SalaryConfig.JUNIOR_RANK then
			table.insert(lines, "🐣 후배가 배정돼요 (일 시키기 · 챙겨 주기)")
		end
		if rank == SalaryConfig.DELEGATE_RANK then
			table.insert(lines, "🫳 동료에게 업무를 부탁할 수 있어요")
		end
	end
	return lines
end

---------------------------------------------------------------------------
-- 엔딩 화면: 👑 전설의 루팡 (사장 취임) / 🏝️ 조기 은퇴 (사표) / 회사 물려주기 (엔딩 없이 재입사만)
---------------------------------------------------------------------------
local function showEnding(ending)
	local retire = ending.id == "retire"
	local handover = ending.id == "handover"
	local screen = Ui.make("TextButton", { -- (버튼으로 만들어서 뒤쪽 화면이 눌리지 않게)
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(12, 16, 26),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 100,
		Parent = gui,
	})
	TweenService:Create(screen, TweenInfo.new(1.2), { BackgroundTransparency = 0.04 }):Play()
	local stage = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 420),
		BackgroundTransparency = 1,
		ZIndex = 101,
		Parent = screen,
	})
	fit(stage, 560, 420)

	local story = {
		`입사 {comma(ending.days)}일째.`,
		`부장님께 걸린 횟수 {comma(ending.caught)}번 · 아슬아슬하게 넘긴 횟수 {comma(ending.nearMiss)}번`
			.. (if ending.fired > 0 then ` · 해고 {comma(ending.fired)}번` else ""),
		"그리고 오늘, 사장이 되었습니다.",
		"아무도 모릅니다.\n당신이 한 번도 열심히 일한 적 없다는 걸.",
	}
	if retire then
		story = {
			`입사 {comma(ending.days)}일째. 통장에는 {comma(ending.money or 0)}원.`,
			`{ending.rankName or "사원"}의 책상 위에 사표 한 장을 올려놓았습니다.`,
			"부장님은 말리지 않았습니다.",
			"사실 당신이 무슨 일을 하는 사람인지\n끝까지 몰랐거든요.",
		}
	elseif handover then
		story = {
			`입사 {comma(ending.days)}일째.`,
			"사장 자리를 물려주고 회사를 나섰습니다.",
			"그런데 집에 있으니 좀이 쑤십니다.",
			"월급루팡은 역시,\n월급이 있어야 루팡이니까요.",
		}
	end
	local y = 0
	for index, sentence in story do
		local line = label(stage, {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, if index == 4 then 56 else 30),
			Text = sentence,
			TextSize = if index == 4 then 20 else 18,
			TextColor3 = Color3.fromRGB(226, 230, 240),
			TextTransparency = 1,
			ZIndex = 102,
		})
		y += if index == 4 then 70 else 40
		task.delay(1 + (index - 1) * 2.2, function()
			if line.Parent then
				Sounds.play("click", 0.3, 0.8)
				TweenService:Create(line, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
			end
		end)
	end

	local reveal = 1 + #story * 2.2 + 0.6
	local crown = label(stage, {
		Position = UDim2.fromOffset(0, y + 4),
		Size = UDim2.new(1, 0, 0, 56),
		Text = if retire then "🏝️ 조기 은퇴" elseif handover then "🔁 다시, 신입" else "👑 전설의 루팡",
		Font = Enum.Font.GothamBlack,
		TextSize = 44,
		TextColor3 = Color3.fromRGB(255, 214, 110),
		TextTransparency = 1,
		ZIndex = 102,
	})
	local grade = label(stage, {
		Position = UDim2.fromOffset(0, y + 66),
		Size = UDim2.new(1, 0, 0, 28),
		Text = if retire or handover
			then `{(ending.rebirths or 1) + 1}회차 인턴으로 재입사 · 농땡이 수입 +{ending.bonusPercent or 0}%`
			else `등급 {ending.grade} — {ending.gradeLabel}`,
		TextSize = 20,
		TextColor3 = Color3.fromRGB(255, 236, 180),
		TextTransparency = 1,
		ZIndex = 102,
	})
	local reward = label(stage, {
		Position = UDim2.fromOffset(0, y + 98),
		Size = UDim2.new(1, 0, 0, 24),
		Text = if retire then "🏆 칭호 「🏝️ 자유인」 · 「🔁 경력직 신입」 획득 (📖 도감에서 달 수 있어요)"
			elseif handover then "🏆 칭호 「🔁 경력직 신입」 획득 · 도감·꾸미기·친밀도는 그대로예요"
			else "🏆 칭호 「👑 전설의 루팡」 획득 (📖 도감에서 달 수 있어요)",
		TextSize = 15,
		TextColor3 = Color3.fromRGB(190, 200, 220),
		TextTransparency = 1,
		ZIndex = 102,
	})
	local continueButton = Ui.button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, y + 140),
		Size = UDim2.fromOffset(260, 46),
		Text = if retire or handover then "🌱 인턴으로 출근하기" else "👔 내일도 출근하기",
		TextSize = 18,
		Visible = false,
		ZIndex = 103,
		Parent = stage,
	})
	task.delay(reveal, function()
		if not screen.Parent then
			return
		end
		Sounds.play("ping", 0.8, 0.9)
		Sounds.play("bass", 0.5, 1.2)
		confetti(screen :: any, 36)
		for _, item in { crown, grade, reward } do
			TweenService:Create(item, TweenInfo.new(1), { TextTransparency = 0 }):Play()
		end
		task.wait(2)
		if continueButton.Parent then
			continueButton.Visible = true
		end
	end)
	continueButton.Activated:Connect(function()
		Sounds.play("click", 0.4)
		screen:Destroy()
	end)
end

---------------------------------------------------------------------------
-- 📜 사령장
---------------------------------------------------------------------------
function Ceremony.show(slip)
	if not slip.promotedTo or not slip.promotedRank or not slip.promotedFromRank then
		return
	end
	local lines = changes(slip.promotedFromRank, slip.promotedRank)
	local height = 318 + #lines * 24

	local dim = Ui.make("TextButton", { -- (뒤쪽 명세서가 눌리지 않게)
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 14, 24),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 90,
		Parent = gui,
	})
	TweenService:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency = 0.35 }):Play()

	local card = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 40),
		Size = UDim2.fromOffset(440, height),
		BackgroundColor3 = PAPER,
		ZIndex = 91,
		Parent = dim,
	}, { Ui.corner(14), Ui.stroke(GOLD, 3), Ui.padding(18) })
	fit(card, 440, height)
	TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()

	label(card, { Size = UDim2.new(1, 0, 0, 40), Text = "사 령 장", Font = Enum.Font.GothamBlack, TextSize = 32, TextColor3 = GOLD })
	label(card, { Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 22), Text = `{player.DisplayName} 귀하`, TextSize = 16 })
	label(card, {
		Position = UDim2.fromOffset(0, 76),
		Size = UDim2.new(1, 0, 0, 40),
		Text = `{slip.promotedFrom}  →  {slip.promotedTo}`,
		Font = Enum.Font.GothamBlack,
		TextSize = 30,
	})
	label(card, {
		Position = UDim2.fromOffset(0, 122),
		Size = UDim2.new(1, 0, 0, 40),
		Text = `위 사람을 {SalaryConfig.currentCompany().name} {slip.promotedTo}(으)로 임명합니다.\n— {slip.day}일차 인사 발령 —`,
		TextSize = 14,
		TextColor3 = Theme.Color.muted,
	})

	-- 달라지는 것
	local list = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 172),
		Size = UDim2.new(1, 0, 0, #lines * 24 + 12),
		BackgroundColor3 = Color3.fromRGB(250, 240, 210),
		ZIndex = 92,
		Parent = card,
	}, { Ui.corner(10) })
	for index, text in lines do
		label(list, {
			Position = UDim2.fromOffset(12, 6 + (index - 1) * 24),
			Size = UDim2.new(1, -24, 0, 22),
			Text = text,
			Font = Enum.Font.GothamMedium,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = false,
			TextScaled = false,
			ZIndex = 93,
		})
	end

	-- 🔴 도장 쾅
	local stamp = label(card, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -44, 0, 96),
		Size = UDim2.fromOffset(74, 74),
		BackgroundTransparency = 1,
		Text = "대표\n이사",
		Font = Enum.Font.GothamBlack,
		TextSize = 17,
		TextColor3 = STAMP,
		Rotation = -14,
		Visible = false,
		ZIndex = 94,
	})
	Ui.corner(37).Parent = stamp
	Ui.stroke(STAMP, 4).Parent = stamp
	local stampScale = Ui.make("UIScale", { Scale = 2.4, Parent = stamp })

	local closeButton = Ui.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(220, 44),
		Text = "감사합니다! 🎉",
		TextSize = 18,
		ZIndex = 93,
		Parent = card,
	})

	Sounds.play("swoosh", 0.6)
	task.delay(0.7, function()
		if stamp.Parent then
			stamp.Visible = true
			TweenService:Create(stampScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 1 }):Play()
			task.wait(0.18)
			Sounds.play("bass", 0.7, 1.3)
			Sounds.play("ping", 0.7, 1.2)
			confetti(dim :: any, 28)
		end
	end)

	closeButton.Activated:Connect(function()
		Sounds.play("click", 0.4)
		dim:Destroy()
		if slip.ending then
			showEnding(slip.ending)
		end
	end)
end

Ceremony.showEnding = showEnding -- (📮 사표 창이 은퇴 엔딩을 띄울 때 써요)

-- 🧪 스튜디오 미리 보기 (실제 게임엔 영향 없음)
function Ceremony.preview()
	local mode = SalaryConfig.TEST_CEREMONY
	if not RunService:IsStudio() or mode == nil or mode == "" then
		return
	end
	task.delay(8, function()
		if mode == "retire" then
			showEnding({ id = "retire", days = 64, caught = 9, nearMiss = 210, fired = 0, money = 312400, rankName = Ranks[5].name, rebirths = 1, bonusPercent = 5 })
			return
		end
		local top = #Ranks
		local slip = {
			day = 87,
			promotedTo = if mode == "ending" then Ranks[top].name else Ranks[5].name,
			promotedFrom = if mode == "ending" then Ranks[top - 1].name else Ranks[4].name,
			promotedRank = if mode == "ending" then top else 5,
			promotedFromRank = if mode == "ending" then top - 1 else 4,
			ending = if mode == "ending"
				then { id = "legend", grade = "S", gradeLabel = "아무도 몰랐다", days = 87, caught = 12, nearMiss = 301, fired = 1, xp = 530000 }
				else nil,
		}
		Ceremony.show(slip)
	end)
end

return Ceremony
