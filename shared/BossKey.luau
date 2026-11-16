-- 🙈 화면 숨기기 (보스 키)
--
-- 현실에서 몰래 게임하다가 누가 오면 [B]! 게임 화면을 "일하는 것처럼 보이는 화면"으로 덮어요.
--   [B]          : 숨기기 / 돌아오기
--   [Shift + B]  : 위장 화면 바꾸기 (터미널 → 스프레드시트 → 디자인 툴)
--   화면 구석 🙈 버튼으로도 숨길 수 있어요 (돌아올 땐 [B] 또는 화면 아무 곳 더블클릭)
--
-- 숨긴 동안에는 LocalPlayer의 "ScreenHidden" 속성이 true예요.
-- 각 게임은 이 값을 보고 게임 키 입력을 무시해요 (실수로 행동이 나가지 않게).
-- 클라이언트 전용 모듈이에요.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local BossKey = {}

local player = Players.LocalPlayer
local MODES = { "terminal", "sheet", "design" }
local MODE_NAMES = { terminal = "🖥️ 터미널", sheet = "📊 스프레드시트", design = "🎨 디자인 툴" }

local function make(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

local function label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Color3.fromRGB(200, 200, 200),
	}
	for key, value in props do
		defaults[key] = value
	end
	return make("TextLabel", defaults)
end

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

---------------------------------------------------------------------------
-- 🖥️ 터미널: 빌드·테스트 로그가 계속 올라가요
---------------------------------------------------------------------------
local LOG_LINES = {
	"[INFO] Compiling module report_q4 ...",
	"[INFO] Resolving dependencies (238 packages)",
	"[ OK ] tests/sales_summary.spec  (42 passed)",
	"[ OK ] tests/inventory_sync.spec (18 passed)",
	"[WARN] Deprecated option 'legacyExport' will be removed",
	"[INFO] Uploading artifacts to staging-01 ... done",
	"[INFO] Migrating table monthly_kpi (row 12,480 / 51,200)",
	"[ OK ] Lint finished: 0 errors, 3 warnings",
	"[INFO] Generating PDF: 4분기_실적보고서.pdf",
	"[INFO] Running integration suite (stage 3/5)",
	"[ OK ] Cache warmed (1.2s)",
	"[INFO] Syncing data from ERP ... 64%",
	"[INFO] Backup snapshot created: snap_20261116_1402",
	"[ OK ] Build succeeded in 38.4s",
}

local function buildTerminal(parent: Instance)
	local root = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(12, 12, 12), Parent = parent })
	local titleBar = make("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Color3.fromRGB(40, 40, 44), Parent = root })
	label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 1, -6), Text = "Terminal — build_report.sh", Font = Enum.Font.Gotham, TextSize = 14, Parent = titleBar })

	local body = make("Frame", {
		Position = UDim2.fromOffset(14, 40),
		Size = UDim2.new(1, -28, 1, -54),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = root,
	}, {
		make("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local order = 0
	local function addLine(text: string, color: Color3)
		order += 1
		label({ Size = UDim2.new(1, 0, 0, 20), Text = text, TextColor3 = color, LayoutOrder = order, Parent = body })
		local lines = {}
		for _, child in body:GetChildren() do
			if child:IsA("TextLabel") then
				table.insert(lines, child)
			end
		end
		if #lines > 60 then
			table.sort(lines, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			lines[1]:Destroy()
		end
	end

	addLine("C:\\work\\project> ./build_report.sh --env=prod", Color3.fromRGB(230, 230, 230))
	task.spawn(function()
		while root.Parent do
			if root.Visible then
				local line = pick(LOG_LINES)
				local color = if string.find(line, "OK") then Color3.fromRGB(110, 210, 120)
					elseif string.find(line, "WARN") then Color3.fromRGB(230, 200, 90)
					else Color3.fromRGB(200, 200, 200)
				addLine(`{os.date("%H:%M:%S")}  {line}`, color)
			end
			task.wait(0.15 + math.random() * 0.5)
		end
	end)
	return root
end

---------------------------------------------------------------------------
-- 📊 스프레드시트: 숫자가 빽빽한 보고서
---------------------------------------------------------------------------
local function buildSheet(parent: Instance)
	local root = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 255, 255), Parent = parent })
	local top = make("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Color3.fromRGB(70, 90, 120), Parent = root })
	label({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 1, -8),
		Text = "2026_4분기_매출보고서_최종_진짜최종(2).xlsx",
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 14,
		Parent = top,
	})
	local formula = make("Frame", { Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = Color3.fromRGB(243, 243, 243), Parent = root })
	label({ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 1, -6), Text = "F14    fx   =SUMIFS(D:D, B:B, \"영업2팀\", C:C, \">=2026-10-01\")", TextColor3 = Color3.fromRGB(60, 60, 60), Parent = formula })

	local COLUMNS = { "", "A", "B", "C", "D", "E", "F", "G", "H" }
	local TEAMS = { "영업1팀", "영업2팀", "마케팅", "기획", "개발", "인사", "총무" }
	local grid = make("Frame", { Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 1, -62), BackgroundTransparency = 1, ClipsDescendants = true, Parent = root })
	local cells: { TextLabel } = {}
	local rowHeight = 22
	for row = 0, 40 do
		for col, letter in COLUMNS do
			local isHeader = row == 0 or col == 1
			local text = ""
			if row == 0 then
				text = letter
			elseif col == 1 then
				text = tostring(row)
			elseif col == 2 then
				text = string.format("2026-%02d-%02d", 10 + (row % 3), (row % 28) + 1)
			elseif col == 3 then
				text = TEAMS[(row % #TEAMS) + 1]
			else
				text = string.format("%d,%03d", math.random(1, 99), math.random(0, 999))
			end
			local cell = label({
				Position = UDim2.new((col - 1) / #COLUMNS, 0, 0, row * rowHeight),
				Size = UDim2.new(1 / #COLUMNS, 0, 0, rowHeight),
				BackgroundTransparency = 0,
				BackgroundColor3 = if isHeader then Color3.fromRGB(235, 235, 235) else Color3.new(1, 1, 1),
				BorderColor3 = Color3.fromRGB(218, 218, 218),
				BorderSizePixel = 1,
				Text = " " .. text,
				Font = Enum.Font.Gotham,
				TextSize = 13,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextXAlignment = if isHeader then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(40, 40, 40),
				Parent = grid,
			})
			if not isHeader and col > 3 then
				table.insert(cells, cell)
			end
		end
	end
	-- 숫자가 가끔 바뀌어서 "작업 중"처럼 보여요
	task.spawn(function()
		while root.Parent do
			if root.Visible and #cells > 0 then
				pick(cells).Text = string.format(" %d,%03d", math.random(1, 99), math.random(0, 999))
			end
			task.wait(0.6 + math.random())
		end
	end)
	return root
end

---------------------------------------------------------------------------
-- 🎨 디자인 툴: 도구 막대, 캔버스, 레이어 패널 (특정 회사 프로그램이 아닌 일반적인 모양)
---------------------------------------------------------------------------
local function buildDesign(parent: Instance)
	local root = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(38, 38, 40), Parent = parent })
	local top = make("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Color3.fromRGB(28, 28, 30), Parent = root })
	label({
		Position = UDim2.fromOffset(12, 7),
		Size = UDim2.new(1, -24, 1, -7),
		Text = "파일   편집   이미지   레이어   선택   필터   보기        브랜딩_시안_v12_최종_수정.png @ 66.7%",
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(190, 190, 195),
		Parent = top,
	})

	-- 왼쪽 도구 막대
	local tools = make("Frame", { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(0, 44, 1, -30), BackgroundColor3 = Color3.fromRGB(50, 50, 53), Parent = root }, {
		make("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
		make("UIPadding", { PaddingTop = UDim.new(0, 10) }),
	})
	for _, icon in { "↖", "▭", "◯", "✎", "T", "✂", "◐", "✋", "🔍" } do
		label({ Size = UDim2.fromOffset(30, 30), Text = icon, TextSize = 18, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Parent = tools })
	end

	-- 오른쪽 레이어 패널
	local layers = make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 30), Size = UDim2.new(0, 240, 1, -30), BackgroundColor3 = Color3.fromRGB(50, 50, 53), Parent = root }, {
		make("UIListLayout", { Padding = UDim.new(0, 2) }),
		make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8) }),
	})
	label({ Size = UDim2.new(1, -8, 0, 24), Text = "레이어", Font = Enum.Font.GothamBold, TextSize = 14, Parent = layers })
	for _, name in { "👁 로고_최종", "👁 슬로건 텍스트", "👁 그라데이션 오버레이", "👁 메인 비주얼", "👁 배경_수정본", "👁 가이드라인 (숨김)" } do
		label({ Size = UDim2.new(1, -8, 0, 28), Text = name, Font = Enum.Font.Gotham, TextSize = 13, TextYAlignment = Enum.TextYAlignment.Center, BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(60, 60, 64), Parent = layers })
	end

	-- 가운데 캔버스 (도형 몇 개)
	local canvas = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, -98, 0.5, 15),
		Size = UDim2.new(0.55, 0, 0.7, 0),
		BackgroundColor3 = Color3.fromRGB(250, 248, 242),
		Parent = root,
	})
	make("Frame", { Position = UDim2.fromScale(0.08, 0.1), Size = UDim2.fromScale(0.84, 0.45), BackgroundColor3 = Color3.fromRGB(255, 140, 90), Parent = canvas }, {
		make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 120, 110), Color3.fromRGB(250, 200, 90)) }),
	})
	make("Frame", { Position = UDim2.fromScale(0.62, 0.18), Size = UDim2.fromScale(0.22, 0.3), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.3, Parent = canvas }, {
		make("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	label({ Position = UDim2.fromScale(0.08, 0.62), Size = UDim2.fromScale(0.84, 0.12), Text = "BRAND NEW DAY", Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.fromRGB(40, 40, 50), Parent = canvas })
	label({ Position = UDim2.fromScale(0.08, 0.76), Size = UDim2.fromScale(0.84, 0.06), Text = "2027 S/S Campaign — draft for review", Font = Enum.Font.Gotham, TextScaled = true, TextColor3 = Color3.fromRGB(120, 120, 130), Parent = canvas })
	-- 선택 테두리 (편집 중인 느낌)
	make("Frame", { Position = UDim2.fromScale(0.06, 0.6), Size = UDim2.fromScale(0.88, 0.16), BackgroundTransparency = 1, Parent = canvas }, {
		make("UIStroke", { Color = Color3.fromRGB(60, 140, 255), Thickness = 1.5 }),
	})
	return root
end

---------------------------------------------------------------------------
-- 켜고 끄기
---------------------------------------------------------------------------
function BossKey.start()
	local gui = make("ScreenGui", {
		Name = "BossKeyScreen",
		IgnoreGuiInset = true,
		DisplayOrder = 10000,
		ResetOnSpawn = false,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local screens = {
		terminal = buildTerminal(gui),
		sheet = buildSheet(gui),
		design = buildDesign(gui),
	}
	local modeIndex = 1
	local hidden = false
	local savedCoreGui: { [Enum.CoreGuiType]: boolean } = {}

	local function showMode()
		for index, mode in MODES do
			screens[mode].Visible = index == modeIndex
		end
	end
	showMode()

	-- 숨기기 버튼 (화면 구석에 작게)
	local buttonGui = make("ScreenGui", { Name = "BossKeyButton", DisplayOrder = 9999, ResetOnSpawn = false, Parent = player:WaitForChild("PlayerGui") })
	local hideButton = make("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -10, 1, -10),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Color3.fromRGB(30, 30, 35),
		BackgroundTransparency = 0.3,
		Text = "🙈",
		TextSize = 24,
		Parent = buttonGui,
	}, { make("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local tip = label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -60, 1, -18),
		Size = UDim2.fromOffset(240, 28),
		Text = "화면 숨기기 [B] · 위장 바꾸기 [Shift+B]",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.4,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center,
		Visible = false,
		Parent = buttonGui,
	})
	hideButton.MouseEnter:Connect(function()
		tip.Visible = true
	end)
	hideButton.MouseLeave:Connect(function()
		tip.Visible = false
	end)

	local function setHidden(value: boolean)
		hidden = value
		gui.Enabled = value
		buttonGui.Enabled = not value
		player:SetAttribute("ScreenHidden", value)
		ProximityPromptService.Enabled = not value
		-- 채팅, 플레이어 목록 같은 로블록스 기본 화면도 잠깐 숨겨요
		for _, coreType in { Enum.CoreGuiType.Chat, Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.EmotesMenu } do
			pcall(function()
				if value then
					savedCoreGui[coreType] = StarterGui:GetCoreGuiEnabled(coreType)
					StarterGui:SetCoreGuiEnabled(coreType, false)
				elseif savedCoreGui[coreType] ~= nil then
					StarterGui:SetCoreGuiEnabled(coreType, savedCoreGui[coreType])
				end
			end)
		end
	end

	hideButton.Activated:Connect(function()
		setHidden(true)
	end)

	-- 들어오고 잠시 뒤 한 번 안내해요
	task.delay(4, function()
		if not hidden then
			tip.Text = "🙈 몰래 하는 중이라면? [B] 화면 숨기기 · [Shift+B] 위장 바꾸기"
			tip.Size = UDim2.fromOffset(420, 28)
			tip.Visible = true
			task.wait(7)
			tip.Visible = false
			tip.Size = UDim2.fromOffset(240, 28)
			tip.Text = "화면 숨기기 [B] · 위장 바꾸기 [Shift+B]"
		end
	end)

	-- 위장 화면을 더블클릭해도 돌아와요 (키보드가 없는 경우 대비)
	local lastClick = 0
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if hidden and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			local now = os.clock()
			if now - lastClick < 0.35 then
				setHidden(false)
			end
			lastClick = now
			return
		end
		if gameProcessed or input.KeyCode ~= Enum.KeyCode.B then
			return
		end
		local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		if shift then
			modeIndex = modeIndex % #MODES + 1
			showMode()
			if not hidden then
				tip.Text = `위장 화면: {MODE_NAMES[MODES[modeIndex]]} · [B]로 숨기기`
				tip.Visible = true
				task.delay(2, function()
					tip.Visible = false
					tip.Text = "화면 숨기기 [B] · 위장 바꾸기 [Shift+B]"
				end)
			end
		else
			setHidden(not hidden)
		end
	end)

	-- 숨긴 동안에는 캐릭터 조작도 꺼요 (키보드로 걸어가 버리지 않게)
	-- 캐릭터 조작 모듈은 따로(백그라운드에서) 가져와요. 여기서 기다리면 다른 기능 시작이 막혀요!
	local controls = nil
	task.spawn(function()
		pcall(function()
			local playerScripts = player:WaitForChild("PlayerScripts", 10)
			local playerModule = playerScripts and playerScripts:WaitForChild("PlayerModule", 10)
			if playerModule then
				controls = (require(playerModule :: any) :: any):GetControls()
			end
		end)
	end)
	player:GetAttributeChangedSignal("ScreenHidden"):Connect(function()
		if controls then
			if player:GetAttribute("ScreenHidden") then
				controls:Disable()
			else
				controls:Enable()
			end
		end
	end)
end

return BossKey
