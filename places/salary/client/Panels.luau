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
-- keepClear = true면 양옆 정보창과 아래 행동 버튼줄을 피해서 그 사이 빈 곳에만 맞춰요
local function fitScale(width: number, height: number, keepClear: boolean?): number
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	-- 위쪽 로블록스 메뉴 막대 빼고 / keepClear면 아래 행동 버튼줄과 안내 문구(~120)는 비워 둬요 (양옆 정보창은 살짝만 비켜요)
	local availableHeight = if keepClear then (viewport.Y - 36 - 8 - 120) * 0.95 else (viewport.Y - 70) * 0.95
	local availableWidth = (viewport.X - (if keepClear then 300 else 0)) * 0.95
	return math.clamp(math.min(availableWidth / width, availableHeight / height), 0.4, 1)
end

local function sheet(width: number, height: number, keepClear: boolean?): Frame
	close()
	local frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = if keepClear then UDim2.new(0.5, 0, 0.5, -56) else UDim2.fromScale(0.5, 0.5), -- (위 8·아래 120 사이 가운데)
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = Color3.fromRGB(250, 250, 245),
		ZIndex = 30,
		Parent = gui,
	}, {
		Ui.corner(12),
		Ui.stroke(Color3.fromRGB(60, 60, 70), 3),
		Ui.padding(20),
		Ui.make("UIScale", { Scale = fitScale(width, height, keepClear) }),
	})

	-- 게임에 막 들어온 순간엔 화면 크기가 아직 정확하지 않아서 창이 너무 작게 계산될 수 있어요.
	-- 창이 열려 있는 동안 화면 크기를 계속 확인해서 다시 맞춰요.
	local uiScale = frame:FindFirstChildOfClass("UIScale") :: UIScale
	task.spawn(function()
		while frame.Parent do
			uiScale.Scale = fitScale(width, height, keepClear)
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

-- 🚪 옥상·눈치 스트리트 게임 창: 캐릭터가 그 자리(station)에서 range보다 멀어지거나, 쓰러지면 창을 저절로 닫아요
--   (닫히면 frame.Destroying이 불려서 각 창이 바꿔 둔 것(카메라·걸음 속도)을 되돌려요)
local function closeWhenAway(frame: GuiObject, station: any, range: number)
	if typeof(station) ~= "Vector3" then
		return -- (서버가 자리를 안 알려 줬으면 그냥 둬요)
	end
	task.spawn(function()
		while current == frame and frame.Parent do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not root or not humanoid or humanoid.Health <= 0 or (root.Position - station).Magnitude > range then
				if current == frame then
					close()
				end
				return
			end
			task.wait(0.25)
		end
	end)
end

-- 🖱️ 창 바깥(빈 화면)을 누르면 창이 닫혀요 (소지품·꾸미기·스탯·인형·도감·매점 같은 정보 창)
local function closeOnOutside(frame: GuiObject)
	local backdrop = Ui.make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 29, -- (창 바로 아래)
		Parent = gui,
	})
	backdrop.Activated:Connect(function()
		if current == frame then
			close()
		end
	end)
	frame.Destroying:Connect(function()
		backdrop:Destroy()
	end)
end

-- 📜 스크롤 막대를 잘 보이게 (모든 창의 목록에 자동 적용)
local function styleScroll(item: Instance)
	if item:IsA("ScrollingFrame") then
		item.ScrollBarImageColor3 = Color3.fromRGB(120, 95, 50)
		item.ScrollBarImageTransparency = 0.1
		item.ScrollBarThickness = math.max(item.ScrollBarThickness, 10)
	end
end
gui.DescendantAdded:Connect(styleScroll)

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

-- ❓ 자세한 설명은 이 작은 버튼 뒤에 숨겨 둬요: 누르면 창 안에 설명 팝업이 떴다가, 다시 누르면(팝업·X·❓) 닫혀요
--   body는 글자 또는 (열 때마다 새로 만드는) 함수 / window = 팝업을 띄울 창 (없으면 parent)
local function helpButton(parent: GuiObject, position: UDim2, title: string, body: string | () -> string, window: GuiObject?): TextButton
	local host = window or parent
	local popup: GuiObject? = nil
	local b = Ui.button({
		Position = position,
		Size = UDim2.fromOffset(28, 28),
		Text = "❓",
		TextSize = 15,
		BackgroundColor3 = Color3.fromRGB(225, 232, 248),
		ZIndex = 34,
		Parent = parent,
	})
	local function hide()
		if popup then
			popup:Destroy()
			popup = nil
		end
	end
	b.Activated:Connect(function()
		if popup and popup.Parent then
			hide()
			return
		end
		for _, child in host:GetChildren() do
			if child.Name == "HelpPopup" then
				child:Destroy() -- (다른 ❓ 팝업은 닫아요)
			end
		end
		local box = Ui.make("TextButton", {
			Name = "HelpPopup",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 38),
			Size = UDim2.new(1, -16, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Color3.fromRGB(255, 252, 238),
			AutoButtonColor = false,
			Text = "",
			ZIndex = 60,
			Parent = host,
		}, { Ui.corner(10), Ui.stroke(Color3.fromRGB(150, 130, 80), 2), Ui.padding(14) })
		popup = box
		box.Activated:Connect(hide)
		Ui.make("TextLabel", {
			Size = UDim2.new(1, -34, 0, 24),
			BackgroundTransparency = 1,
			Text = "❓ " .. title,
			TextColor3 = INK,
			Font = Enum.Font.GothamBlack,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 61,
			Parent = box,
		})
		local x = Ui.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 4, 0, -4),
			Size = UDim2.fromOffset(28, 28),
			Text = "X",
			TextSize = 15,
			Font = Enum.Font.GothamBlack,
			BackgroundColor3 = Color3.fromRGB(225, 225, 228),
			ZIndex = 62,
			Parent = box,
		})
		x.Activated:Connect(hide)
		Ui.make("TextLabel", {
			Position = UDim2.fromOffset(0, 30),
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = if type(body) == "function" then body() else body,
			RichText = true,
			TextColor3 = INK,
			Font = Enum.Font.GothamMedium,
			TextSize = 16,
			LineHeight = 1.15,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 61,
			Parent = box,
		})
	end)
	b.Destroying:Connect(hide)
	return b
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
--   탭: 🧰 사무용품 / 🎁 부장님 선물 / 👮 경비원 선물 / 🌱 씨앗(🎒 보관 → 옥상 텃밭) / 🐦 비둘기 과자(🎒 보관 → 옥상 모이 통) / 🎟️ 쿠폰 / 📚 자격증
function Panels.showShop(startTab: string?)
	local items = SalaryConfig.Items
	local gifts = SalaryConfig.StreetShops.store.items
	local coupons = SalaryConfig.Coupons
	local certs = SalaryConfig.Certificates
	local guardGifts = SalaryConfig.GuardBribes -- 👮 경비원 선물 (🎒에 보관)
	local rowsMax = math.max(#items, #gifts, #coupons, #certs, #guardGifts, math.ceil((30 + math.ceil(math.max(#SalaryConfig.GardenSeeds, #SalaryConfig.ParkFlowers + 1) / 2) * 59) / 64)) -- (🌱 씨앗은 [채소]/[꽃씨] 고르기 + 두 줄)
	-- 📐 창을 넓히고 글씨를 키웠어요 (목록이 길면 탭마다 스크롤)
	local _ = rowsMax
	local frame = sheet(720, 600)
	closeOnOutside(frame)
	line(frame, 0, 32, "🏪 사내 매점", { Font = Enum.Font.GothamBlack, TextSize = 26 })
	local balance = line(frame, 0, 32, "", {
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		Size = UDim2.new(1, -44, 0, 32), -- 오른쪽 위 닫기 버튼 자리는 비워 둬요
	})
	local message = line(frame, 0, 26, "", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -50),
		TextSize = 16,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	-- 탭
	local pages: { [string]: Frame } = {}
	local tabButtons: { [string]: TextButton } = {}
	local function page(id: string): Frame
		local f = Ui.make("ScrollingFrame", {
			Position = UDim2.fromOffset(0, 90),
			Size = UDim2.new(1, 0, 1, -170),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 10,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ZIndex = 31,
			Parent = frame,
		})
		pages[id] = f :: any
		return f :: any
	end
	local seedMode = "veg" -- 🌱 씨앗 탭 안: "veg" 🥬 채소 씨앗 / "flower" 🌷 꽃씨·거름
	local SEED_HINT = "🌱 🎒에 보관 → 옥상 텃밭 · 🏷️ 특가는 매일 바뀌어요"
	local FLOWER_HINT = "🌷 🎒에 보관 → 공원 화단"
	local function selectTab(id: string)
		for tabId, f in pages do
			f.Visible = tabId == id
			tabButtons[tabId].BackgroundColor3 = if tabId == id then Color3.fromRGB(255, 200, 80) else Color3.fromRGB(200, 200, 205)
		end
		message.Text = if id == "gifts" then "🎁 부장님께 [E]로 드려요" elseif id == "guard" then "👮 🎒에 보관 → 경비원에게 [E]" elseif id == "pigeon" then "🐦 🎒에 보관 → 옥상 모이 통 [E]" elseif id == "seeds" then (if seedMode == "flower" then FLOWER_HINT else SEED_HINT) elseif id == "coupons" then "🎟️ 사자마자 바로 써요" elseif id == "certs" then `📚 {SalaryConfig.CERT_QUESTIONS}문제 중 {SalaryConfig.CERT_PASS}개 맞히면 합격 · 하루 한 번` else ""
		message.TextColor3 = MUTED
	end
	-- (탭 7개: 680px 안에 글자 수만큼 폭을 나눠요 · 사이 간격 4px)
	local tabX = 0
	for _, info in { { "goods", "🧰 사무용품", 104 }, { "gifts", "🎁 부장님", 96 }, { "guard", "👮 경비원", 96 }, { "seeds", "🌱 씨앗", 84 }, { "pigeon", "🐦 비둘기", 96 }, { "coupons", "🎟️ 쿠폰", 84 }, { "certs", "📚 자격증", 96 } } do
		local b = Ui.button({
			Position = UDim2.fromOffset(tabX, 40),
			Size = UDim2.fromOffset(info[3], 42),
			Text = info[2],
			TextSize = 16,
			ZIndex = 31,
			Parent = frame,
		})
		tabX += info[3] + 4
		b.Activated:Connect(function()
			Sounds.play("click", 0.4)
			selectTab(info[1])
		end)
		tabButtons[info[1]] = b
	end

	local function row(parent: Frame, i: number, title: string, description: string): TextButton
		local y = (i - 1) * 84
		line(parent, y, 28, title, { Font = Enum.Font.GothamBold, TextSize = 20, Size = UDim2.new(1, -175, 0, 28) })
		line(parent, y + 30, 46, description, { TextSize = 16, TextColor3 = MUTED, Size = UDim2.new(1, -175, 0, 46) })
		return Ui.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, y + 14), -- (스크롤 막대 자리는 비워 둬요)
			Size = UDim2.fromOffset(150, 48),
			TextSize = 18,
			ZIndex = 32,
			Parent = parent,
		})
	end

	-- 🧰 사무용품
	local goods = page("goods")
	local rows = {}
	for i, item in items do
		local buy = row(goods, i, `{item.emoji} {item.name} · {comma(item.price)}원` .. (if item.days then ` · ⏳{item.days}일` else ""), item.description)
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
	-- 🎟️ 특수 쿠폰 (사자마자 바로 써요)
	local couponPage = page("coupons")
	for i, coupon in coupons do
		local buy = row(couponPage, i, `{coupon.emoji} {coupon.name} · {comma(coupon.price)}원`, coupon.description)
		buy.Text = "사서 쓰기"
		buy.Activated:Connect(function()
			local result = Remotes.BuyCoupon:InvokeServer(coupon.id)
			message.Text = result.message
			message.TextColor3 = if result.ok then Color3.fromRGB(40, 140, 70) else RED
			Sounds.play(if result.ok then "ping" else "bass", 0.6, 1.2)
		end)
	end
	-- 👮 경비원 선물 (사서 🎒에 보관 → 경비원 앞에서 [E]로 드려요)
	local guardPage = page("guard")
	for i, gift in guardGifts do
		local buy = row(guardPage, i, `{gift.emoji} {gift.name} · {comma(gift.price)}원`, `🙈 {SalaryConfig.gameDurationText(gift.minutes)} 동안 못 본 척`)
		buy.Text = "사기"
		buy.Activated:Connect(function()
			local ok, result = Remotes.BuyGuardGift:InvokeServer(gift.id)
			message.Text = result
			message.TextColor3 = if ok then Color3.fromRGB(40, 140, 70) else RED
			Sounds.play(if ok then "ping" else "bass", 0.6, 1.2)
		end)
	end
	-- 🌱 씨앗 (사서 🎒에 보관 → 옥상 화분에 심어요) · 두 줄로 칸칸이
	local seedPage = page("seeds")
	-- 위쪽 [🥬 채소 씨앗] [🌷 꽃씨·거름] 고르기 → 아래 칸칸이 (두 줄)
	local seedPanes: { [string]: Frame } = {}
	local seedModeButtons: { [string]: TextButton } = {}
	local function selectSeedMode(mode: string)
		seedMode = mode
		for paneId, pane in seedPanes do
			pane.Visible = paneId == mode
			seedModeButtons[paneId].BackgroundColor3 = if paneId == mode then Color3.fromRGB(150, 210, 120) else Color3.fromRGB(215, 215, 215)
		end
		message.Text = if mode == "flower" then FLOWER_HINT else SEED_HINT
		message.TextColor3 = MUTED
	end
	for k, info in { { "veg", "🥬 채소 씨앗 (옥상)" }, { "flower", "🌷 꽃씨·거름 (공원)" } } do
		seedPanes[info[1]] = Ui.make("Frame", {
			Position = UDim2.fromOffset(0, 42),
			Size = UDim2.new(1, -14, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, -- (스크롤 길이가 칸 수만큼 늘어나게)
			BackgroundTransparency = 1,
			ZIndex = 31,
			Parent = seedPage,
		})
		local b = Ui.button({
			Position = UDim2.fromOffset((k - 1) * 230, 0),
			Size = UDim2.fromOffset(222, 36),
			Text = info[2],
			TextSize = 16,
			ZIndex = 33,
			Parent = seedPage,
		})
		b.Activated:Connect(function()
			Sounds.play("click", 0.4)
			selectSeedMode(info[1])
		end)
		seedModeButtons[info[1]] = b
	end
	-- 칸 하나 (제목 · 설명 · [사기] [5개])
	local function seedCell(parent: Frame, i: number, color: Color3, description: string, onBuy: (number) -> ()): (TextLabel, TextButton, TextButton)
		local col, rowIndex = (i - 1) % 2, math.floor((i - 1) / 2)
		local cell = Ui.make("Frame", {
			Position = UDim2.fromOffset(col * 330, rowIndex * 86),
			Size = UDim2.fromOffset(320, 80),
			BackgroundColor3 = color,
			ZIndex = 32,
			Parent = parent,
		}, { Ui.corner(8), Ui.padding(7) })
		local title = line(cell, 0, 24, "", { Font = Enum.Font.GothamBold, TextSize = 18, ZIndex = 33, Size = UDim2.new(1, -86, 0, 24), TextScaled = true })
		Ui.make("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 11, Parent = title })
		line(cell, 26, 40, description, { TextSize = 14, ZIndex = 33, TextColor3 = MUTED, Size = UDim2.new(1, -86, 0, 40), TextWrapped = true })
		local buy = Ui.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(80, 30),
			Text = "사기",
			TextSize = 15,
			ZIndex = 34,
			Parent = cell,
		})
		local buy5 = Ui.button({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, 0, 1, 0),
			Size = UDim2.fromOffset(80, 30),
			Text = "5개",
			TextSize = 15,
			ZIndex = 34,
			Parent = cell,
		})
		for _, pair in { { buy, 1 }, { buy5, 5 } } do
			pair[1].Activated:Connect(function()
				onBuy(pair[2])
			end)
		end
		return title, buy, buy5
	end
	-- 🌷 꽃씨 + 🧪 거름 (🎒에 보관 → 눈치물산 공원 화단)
	local flowerTitles: { [string]: TextLabel } = {}
	local function buyFlower(itemId: string, count: number)
		local ok, result = Remotes.BuyFlower:InvokeServer(itemId, count)
		message.Text = result
		message.TextColor3 = if ok then Color3.fromRGB(40, 140, 70) else RED
		Sounds.play(if ok then "ping" else "bass", 0.6, 1.2)
	end
	for i, flower in SalaryConfig.ParkFlowers do
		local title = seedCell(seedPanes.flower, i, Color3.fromRGB(250, 236, 242), `{SalaryConfig.flowerCareText(flower)} · {flower.description}`, function(count: number)
			buyFlower(flower.id, count)
		end)
		flowerTitles[flower.id] = title
	end
	flowerTitles.fertilizer = seedCell(seedPanes.flower, #SalaryConfig.ParkFlowers + 1, Color3.fromRGB(232, 240, 250), "🌿 꽃봉오리에 1개씩", function(count: number)
		buyFlower("fertilizer", count)
	end)
	selectSeedMode("veg")
	local seedButtons = {}
	for i, seed in SalaryConfig.GardenSeeds do
		local col, rowIndex = (i - 1) % 2, math.floor((i - 1) / 2)
		local cell = Ui.make("Frame", {
			Position = UDim2.fromOffset(col * 330, rowIndex * 86),
			Size = UDim2.fromOffset(320, 80),
			BackgroundColor3 = Color3.fromRGB(238, 245, 232),
			ZIndex = 32,
			Parent = seedPanes.veg,
		}, { Ui.corner(8), Ui.padding(7) })
		local title = line(cell, 0, 24, "", { Font = Enum.Font.GothamBold, TextSize = 18, ZIndex = 33, Size = UDim2.new(1, -86, 0, 24), TextScaled = true })
		Ui.make("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 11, Parent = title })
		line(cell, 26, 40, `{SalaryConfig.seedGrowText(seed)} → 💰{comma(seed.sell)}원 {SalaryConfig.seedPerkText(seed)}`, { TextSize = 14, ZIndex = 33, TextColor3 = MUTED, Size = UDim2.new(1, -86, 0, 40), TextWrapped = true })
		local buy = Ui.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(80, 30),
			Text = "사기",
			TextSize = 15,
			ZIndex = 34,
			Parent = cell,
		})
		local buy5 = Ui.button({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, 0, 1, 0),
			Size = UDim2.fromOffset(80, 30),
			Text = "5개",
			TextSize = 15,
			ZIndex = 34,
			Parent = cell,
		})
		for _, pair in { { buy, 1 }, { buy5, 5 } } do
			pair[1].Activated:Connect(function()
				local ok, result = Remotes.BuySeed:InvokeServer(seed.id, pair[2])
				message.Text = result
				message.TextColor3 = if ok then Color3.fromRGB(40, 140, 70) else RED
				Sounds.play(if ok then "ping" else "bass", 0.6, 1.2)
			end)
		end
		seedButtons[seed.id] = { title = title, buy = buy, buy5 = buy5 }
	end
	-- 🐦 비둘기 과자 (사서 🎒에 보관 → 옥상 모이 통에서 골라 뿌려요)
	local pigeonPage = page("pigeon")
	local snackTitles: { [string]: TextLabel } = {}
	for i, snack in SalaryConfig.PigeonSnacks do
		local y = (i - 1) * 84
		snackTitles[snack.id] = line(pigeonPage, y, 28, "", { Font = Enum.Font.GothamBold, TextSize = 20, Size = UDim2.new(1, -200, 0, 28) })
		line(pigeonPage, y + 30, 46, `💕 친밀도 +{snack.friend} · 🐦 +{snack.flock}마리 · 🎁 선물 +{math.floor(snack.gift * 100)}%`, { TextSize = 15, TextColor3 = MUTED, Size = UDim2.new(1, -200, 0, 46) })
		for k, amount in { 1, 5 } do
			local b = Ui.button({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, if k == 1 then -100 else -14, 0, y + 14), -- (스크롤 막대 자리는 비워 둬요)
				Size = UDim2.fromOffset(80, 48),
				Text = if amount == 1 then "사기" else "5개",
				TextSize = 18,
				ZIndex = 32,
				Parent = pigeonPage,
			})
			b.Activated:Connect(function()
				local ok, result = Remotes.BuyPigeonSnack:InvokeServer(snack.id, amount)
				message.Text = result
				message.TextColor3 = if ok then Color3.fromRGB(40, 140, 70) else RED
				Sounds.play(if ok then "ping" else "bass", 0.6, 1.2)
			end)
		end
	end
	-- 📚 자격증 (응시 → 시험 창)
	local certPage = page("certs")
	local certButtons = {}
	for i, cert in certs do
		local buy = row(certPage, i, `{cert.emoji} {cert.name} · 응시료 {comma(cert.price)}원`, `🎖️ 경험치 +{comma(cert.xp)} · {cert.perk} · {Ranks[cert.rank].name}부터`)
		buy.Activated:Connect(function()
			Panels.showExam(cert.id)
		end)
		certButtons[cert.id] = buy
	end
	selectTab(startTab or "goods")

	-- 잔고와 버튼 상태를 계속 갱신
	task.spawn(function()
		while current == frame do
			local money = player:GetAttribute("TotalMoney") or 0
			balance.Text = `🏦 {comma(money)}원`
			local okCerts, myCerts = pcall(function()
				return HttpService:JSONDecode(player:GetAttribute("Certs") or "{}")
			end)
			myCerts = if okCerts and typeof(myCerts) == "table" then myCerts else {}
			local rank = player:GetAttribute("Rank") or 1
			-- 🌱 씨앗: 가격(🏷️ 특가) · 🎒 개수 · 🔒 직급
			local okSeeds, mySeeds = pcall(function()
				return HttpService:JSONDecode(player:GetAttribute("Seeds") or "{}")
			end)
			mySeeds = if okSeeds and typeof(mySeeds) == "table" then mySeeds else {}
			local day = player:GetAttribute("GardenToday") or 0
			for _, seed in SalaryConfig.GardenSeeds do
				local ui = seedButtons[seed.id]
				local price = SalaryConfig.seedPrice(seed, day)
				local have = mySeeds[seed.id] or 0
				local locked = seed.rank ~= nil and rank < seed.rank
				ui.title.Text = `{seed.emoji} {seed.name} {comma(price)}원` .. (if price < seed.price then " 🏷️특가" else "") .. (if have > 0 then ` · 🎒{have}` else "")
				ui.buy.Text = if locked then `🔒{Ranks[seed.rank].name}` else "사기"
				ui.buy.BackgroundColor3 = if locked then Color3.fromRGB(200, 200, 200) else Ui.COLORS.brass
				ui.buy.AutoButtonColor = not locked
				ui.buy5.Visible = not locked
			end
			-- 🌷 꽃씨 · 🧪 거름: 🎒 개수
			local okFlowers, myFlowers = pcall(function()
				return HttpService:JSONDecode(player:GetAttribute("FlowerSeeds") or "{}")
			end)
			myFlowers = if okFlowers and typeof(myFlowers) == "table" then myFlowers else {}
			for _, flower in SalaryConfig.ParkFlowers do
				local have = myFlowers[flower.id] or 0
				flowerTitles[flower.id].Text = `{flower.emoji} {flower.name} {comma(flower.price)}원` .. (if have > 0 then ` · 🎒{have}` else "")
			end
			-- 🐦 비둘기 과자: 🎒 개수
			local okSnacks, mySnacks = pcall(function()
				return HttpService:JSONDecode(player:GetAttribute("PigeonSnacks") or "{}")
			end)
			mySnacks = if okSnacks and typeof(mySnacks) == "table" then mySnacks else {}
			for _, snack in SalaryConfig.PigeonSnacks do
				local have = mySnacks[snack.id] or 0
				snackTitles[snack.id].Text = `{snack.emoji} {snack.name} · {comma(snack.price)}원` .. (if have > 0 then ` · 🎒{have}` else "")
			end
			local fertilizer = player:GetAttribute("Fertilizer") or 0
			flowerTitles.fertilizer.Text = `🧪 거름 {comma(SalaryConfig.FERTILIZER_PRICE)}원` .. (if fertilizer > 0 then ` · 🎒{fertilizer}` else "")
			for _, cert in certs do
				local b = certButtons[cert.id]
				b.Text = if myCerts[cert.id] then "합격 ✅" elseif rank < cert.rank then `🔒 {Ranks[cert.rank].name}` else "📝 응시"
				b.BackgroundColor3 = if myCerts[cert.id] then Color3.fromRGB(150, 220, 150) elseif rank < cert.rank then Color3.fromRGB(200, 200, 200) else Ui.COLORS.brass
			end
			for _, item in items do
				local buy = rows[item.id]
				local owned = not item.consumable and player:GetAttribute(`Item_{item.id}`) == true
				local locked = not owned and item.requires ~= nil and player:GetAttribute(`Item_{item.requires}`) ~= true
				local left = player:GetAttribute(`ItemDays_{item.id}`) or 0
				buy.Text = if owned and item.days then `연장 ({left}일 남음)` elseif owned then "보유 중 ✅" elseif locked then "🔒 인형 먼저" elseif item.consumable then `구매 ({player:GetAttribute("Energy") or 0}개)` else "구매"
				local renewable = owned and item.days ~= nil and left <= item.days
				buy.AutoButtonColor = (not owned or renewable) and not locked
				buy.BackgroundColor3 = if (owned and not renewable) or locked then Color3.fromRGB(200, 200, 200) else Ui.COLORS.brass
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
	plant = "👔 의심도 25% 더 빨리 줄어요",
	tumbler = "☕ 커피 타는 척 90초까지",
	cover = "🖥️ 화면 농땡이 30% 덜 들켜요",
	earphones = "👂 부장님 발소리·상태가 보여요",
	dummy = "🪑 자리 비울 때 대신 앉아요 (부재 150초)",
	dummy_pro = "🪑 타자까지! 부재 240초 · 감사관 사진 무효",
}

function Panels.showBag()
	local frame = sheet(600, 560)
	closeOnOutside(frame)
	line(frame, 0, 32, "🎒 내 소지품", { Font = Enum.Font.GothamBlack, TextSize = 26 })
	helpButton(frame, UDim2.new(1, -70, 0, 2), "소지품", "🧰 사무용품은 <b>사면 바로 효과</b>가 켜져요\n🪑 [책상에 놓기]/[서랍에 넣기]는 꾸미기예요 (치워도 효과는 그대로)\n🧍 단, 인형은 <b>의자에 앉혀 둬야</b> 효과가 있어요\n⏳ 사무용품은 기한이 지나면 사라져요 · 🏪 매점에서 연장\n⚡ 소모품(에너지 드링크)은 여기서 바로 써요")
	local list = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 1, -100),
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
			Size = UDim2.new(1, -12, 0, 68),
			BackgroundColor3 = if owned then Color3.fromRGB(235, 245, 235) else Color3.fromRGB(235, 235, 235),
			LayoutOrder = order,
			ZIndex = 32,
			Parent = list,
		}, { Ui.corner(8), Ui.padding(8) })
		-- (글씨를 키웠어요. 길면 살짝 줄여서 한 줄에 · 목록은 스크롤)
		local titleLabel = line(row, 0, 26, title, { Font = Enum.Font.GothamBold, TextSize = 19, ZIndex = 33, TextColor3 = if owned then INK else MUTED, Size = UDim2.new(1, if buttonText then -130 else 0, 0, 26), TextScaled = true })
		Ui.make("UITextSizeConstraint", { MaxTextSize = 19, MinTextSize = 12, Parent = titleLabel })
		local descLabel = line(row, 27, 24, description, { TextSize = 15, ZIndex = 33, TextColor3 = MUTED, Size = UDim2.new(1, if buttonText then -130 else 0, 0, 24), TextScaled = true })
		Ui.make("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 10, Parent = descLabel })
		if buttonText then
			local b = Ui.button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(120, 40),
				Text = buttonText,
				TextSize = 16,
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
	header("🧰 사무용품 · 🪑 책상 배치")
	for _, item in SalaryConfig.Items do
		if item.consumable then
			continue
		end
		local owned = player:GetAttribute(`Item_{item.id}`) == true
		local isDoll = item.id == "dummy" or item.id == "dummy_pro"
		local function label(): string
			local placed = player:GetAttribute(`Desk_{item.id}`) == true
			if isDoll then
				return if placed then "의자에서 치우기" else "의자에 앉히기"
			end
			return if placed then "서랍에 넣기" else "책상에 놓기"
		end
		local b = entry(
			`{item.emoji} {item.name} {if owned then `✅ ⏳ {player:GetAttribute(`ItemDays_{item.id}`) or 0}일` else "· 🏪 매점"}`,
			ITEM_HOW[item.id] or item.description,
			owned,
			if owned then label() else nil
		)
		if b then
			local toggle = b :: TextButton
			toggle.TextSize = 13
			toggle.Activated:Connect(function()
				Sounds.play("click", 0.4)
				Remotes.ToggleDeskItem:FireServer(item.id)
			end)
			-- 서버가 바꾼 뒤 이름표 갱신 (인형은 서로 바뀌어요)
			local function refresh()
				toggle.Text = label()
				toggle.BackgroundColor3 = if player:GetAttribute(`Desk_{item.id}`) == true then Color3.fromRGB(200, 200, 205) else Ui.COLORS.brass
			end
			refresh()
			local connection = player:GetAttributeChangedSignal(`Desk_{item.id}`):Connect(refresh)
			toggle.Destroying:Connect(function()
				connection:Disconnect()
			end)
		end
	end

	-- ⚡ 소모품과 들고 있는 것
	-- 👮 경비원 선물 (🏪 사내 매점에서 사서 보관)
	header("👮 경비원 선물")
	local okGifts, myGifts = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("GuardGifts") or "{}")
	end)
	myGifts = if okGifts and typeof(myGifts) == "table" then myGifts else {}
	local anyGift = false
	for _, gift in SalaryConfig.GuardBribes do
		local n = myGifts[gift.id] or 0
		if n > 0 then
			anyGift = true
			entry(`{gift.emoji} {gift.name} x{n}`, `👮 경비원에게 [E] · {SalaryConfig.gameDurationText(gift.minutes)} 못 본 척`, true)
		end
	end
	if not anyGift then
		entry("🎁 경비원 선물 없음", "🏪 매점 [👮 경비원] 탭", false)
	end

	-- 🌱 씨앗 (🏪 사내 매점에서 사서 보관 → 옥상 텃밭 화분에 심어요)
	header("🌱 씨앗")
	local okSeeds, mySeeds = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Seeds") or "{}")
	end)
	mySeeds = if okSeeds and typeof(mySeeds) == "table" then mySeeds else {}
	local anySeed = false
	for _, seed in SalaryConfig.GardenSeeds do
		local n = mySeeds[seed.id] or 0
		if n > 0 then
			anySeed = true
			entry(`{seed.emoji} {seed.name} 씨앗 x{n}`, `🌱 옥상 텃밭 · {SalaryConfig.seedGrowText(seed)} → 💰{comma(seed.sell)}원 {SalaryConfig.seedPerkText(seed)}`, true)
		end
	end
	if not anySeed then
		entry("🌱 씨앗 없음", "🏪 매점 [🌱 씨앗] 탭", false)
	end

	-- 🌷 꽃씨 · 🧪 거름 (🏪 사내 매점에서 사서 보관 → 눈치물산 공원 화단)
	header("🌷 꽃씨 · 🧪 거름")
	local okFlowers, myFlowers = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("FlowerSeeds") or "{}")
	end)
	myFlowers = if okFlowers and typeof(myFlowers) == "table" then myFlowers else {}
	local anyFlower = false
	for _, flower in SalaryConfig.ParkFlowers do
		local n = myFlowers[flower.id] or 0
		if n > 0 then
			anyFlower = true
			entry(`{flower.emoji} {flower.name} 꽃씨 x{n}`, `🌷 공원 화단 · {SalaryConfig.flowerCareText(flower)}`, true)
		end
	end
	if not anyFlower then
		entry("🌷 꽃씨 없음", "🏪 매점 [🌷 꽃씨·거름] 탭", false)
	end
	local fertilizer = player:GetAttribute("Fertilizer") or 0
	entry(`🧪 거름 x{fertilizer}`, "🌿 꽃봉오리에 1개씩", fertilizer > 0)

	-- 🐦 비둘기 과자 (🏪 사내 매점에서 사서 보관 → 옥상 모이 통)
	header("🐦 비둘기 과자")
	local okSnacks, mySnacks = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("PigeonSnacks") or "{}")
	end)
	mySnacks = if okSnacks and typeof(mySnacks) == "table" then mySnacks else {}
	local anySnack = false
	for _, snack in SalaryConfig.PigeonSnacks do
		local n = mySnacks[snack.id] or 0
		if n > 0 then
			anySnack = true
			entry(`{snack.emoji} {snack.name} x{n}`, `🐦 옥상 모이 통 · 💕+{snack.friend} · 🐦+{snack.flock}마리`, true)
		end
	end
	if not anySnack then
		entry("🍪 비둘기 과자 없음", "🏪 매점 [🐦 비둘기] 탭", false)
	end

	header("🖐️ 쓰는 물건")
	local energy = player:GetAttribute("Energy") or 0
	local energyActive = player:GetAttribute("EnergyActive") == true
	entry(
		`⚡ 에너지 드링크 x{energy}`,
		if energyActive then "✅ 오늘 복귀 시간 절반" else "오늘 하루 복귀 시간 절반",
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
		entry(`{snack.emoji} {snack.name} ({percent}% 먹음)`, "🪑 자리에서 [8]로 몰래 먹기", true)
	else
		entry("🍪 들고 있는 간식 없음", "탕비실·디저트집에서 가져와요", false)
	end
	local giftId = player:GetAttribute("HeldGiftId") or ""
	local gift = giftId ~= "" and SalaryConfig.getStreetItem("store", giftId)
	if gift then
		entry(`{gift.emoji} {gift.name}`, gift.description, true)
	else
		entry("🎁 들고 있는 선물 없음", "🏪 매점 [부장님 선물] 탭", false)
	end
	local buffs = player:GetAttribute("Buffs") or ""
	entry(if buffs ~= "" then `☕ 오늘 마신 음료 {buffs}` else "☕ 오늘 마신 음료 없음", "☕ 카페 음료 · 오늘 하루 효과", buffs ~= "")

	-- 🎟️ 모은 것
	header("📦 모은 것")
	local owned = HttpService:JSONDecode(player:GetAttribute("Plushies") or "{}")
	local kinds, total = 0, 0
	for _, count in owned do
		kinds += 1
		total += count
	end
	entry(`🧸 인형 {total}개 ({kinds}/{#SalaryConfig.Plushies}종)`, "책상에 3개까지 진열", total > 0, "보기", function()
		Panels.showPlushies(Panels.showBag) -- (◀ 뒤로 누르면 소지품으로 돌아와요)
	end)
	entry(`🎟️ 오락실 티켓 {player:GetAttribute("Tickets") or 0}장`, "🕹️ 오락실 경품 교환대", (player:GetAttribute("Tickets") or 0) > 0)
	-- 🏋️ 체력 스탯 (레벨마다 효과! [보기]에서 자세히)
	local fitness = SalaryConfig.playerFitness(player)
	local fitParts, fitTotal = {}, 0
	for _, stat in SalaryConfig.FitnessStats do
		local value = fitness[stat.id] or 0
		fitTotal += value
		table.insert(fitParts, `{stat.emoji} Lv.{SalaryConfig.fitnessLevel(value)}`)
	end
	entry(
		`🏋️ 체력  {table.concat(fitParts, " · ")}`,
		`오늘 운동 {player:GetAttribute("GymSets") or 0}/{SalaryConfig.GYM_DAILY_SETS}`,
		fitTotal > 0,
		"보기",
		function()
			Panels.showFitness(Panels.showBag) -- (◀ 뒤로 누르면 소지품으로 돌아와요)
		end
	)

	button(frame, 0, "닫기", close)
	Sounds.play("swoosh", 0.4)
end

---------------------------------------------------------------------------
-- 💪 체력 스탯 창: 스탯마다 레벨·진행 막대·지금 효과·다음 레벨 효과·키우는 기구
--   backTo가 있으면 [◀ 소지품으로] 버튼 (🎒에서 열었을 때)
---------------------------------------------------------------------------
function Panels.showFitness(backTo: (() -> ())?)
	-- 창 크기는 고정하고, 스탯 목록은 스크롤해서 봐요 (자세한 효과는 줄마다 ❓)
	local ROW_H = 78
	local frame = sheet(600, 560) -- (🎒 소지품 창과 같은 크기)
	closeOnOutside(frame)
	if backTo then
		button(frame, 0, "◀ 소지품으로", backTo)
	end
	line(frame, 0, 32, "💪 내 체력 스탯", { Font = Enum.Font.GothamBlack, TextSize = 26 })
	local todayText = line(frame, 0, 32, "", { TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBold, TextSize = 18, Size = UDim2.new(1, -44, 0, 32) })
	local statList = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 1, if backTo then -98 else -46),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 31,
		Parent = frame,
	}, { Ui.make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

	-- 스탯마다 키우는 기구 이름 (이름순으로 늘 같은 순서)
	local machineIds = {}
	for machineId in SalaryConfig.GymMachines do
		table.insert(machineIds, machineId)
	end
	table.sort(machineIds)
	local function machinesFor(statId: string): string
		local parts = {}
		for _, machineId in machineIds do
			local machine = SalaryConfig.GymMachines[machineId]
			if table.find(machine.stats, statId) then
				table.insert(parts, `{machine.emoji} {machine.name}`)
			end
		end
		return if #parts > 0 then table.concat(parts, " · ") else "-"
	end
	-- 짧은 효과 줄 ("📦 -15% · 🏀 +6%"): 효과 이름은 ❓ 안에서 보여 줘요
	local function shortEffects(statId: string, level: number): string
		local parts = {}
		for _, info in SalaryConfig.FitnessEffects[statId] or {} do
			local full = SalaryConfig.fitnessEffectLine(info, level) -- "{emoji} {label} {amount}"
			table.insert(parts, `{info.emoji} {string.sub(full, #info.emoji + #info.label + 3)}`)
		end
		return table.concat(parts, " · ")
	end
	local function statLevel(statId: string): (number, number)
		local points = SalaryConfig.playerFitness(player)[statId] or 0
		return SalaryConfig.fitnessLevel(points), points
	end
	-- ❓ 스탯 자세히: 효과 이름·지금/다음 레벨 값, 키우는 기구, 규칙
	local function detailText(stat): string
		local level, points = statLevel(stat.id)
		local maxed = level >= SalaryConfig.FITNESS_MAX_LEVEL
		local per = SalaryConfig.FITNESS_POINTS_PER_LEVEL
		local lines = { `<b>Lv.{level}</b> ({points}점)` .. (if maxed then " 🏆 최고 레벨!" else ` · 다음 레벨까지 {per - (points - level * per)}점`) }
		for _, info in SalaryConfig.FitnessEffects[stat.id] or {} do
			local nowText = SalaryConfig.fitnessEffectLine(info, level)
			if maxed then
				table.insert(lines, nowText)
			else
				local nextFull = SalaryConfig.fitnessEffectLine(info, level + 1)
				table.insert(lines, `{nowText} → <b>{string.sub(nextFull, #info.emoji + #info.label + 3)}</b>`)
			end
		end
		table.insert(lines, `🏋️ 기구: {machinesFor(stat.id)}`)
		table.insert(lines, `<font color="#6e6e78">게이지를 꽉 채우면 +1점 · {per}점마다 레벨 업 (최대 Lv.{SalaryConfig.FITNESS_MAX_LEVEL}) · 하루 {SalaryConfig.GYM_DAILY_SETS}번까지</font>`)
		return table.concat(lines, "\n")
	end

	local rows = {}
	for i, stat in SalaryConfig.FitnessStats do
		local row = Ui.make("Frame", {
			Size = UDim2.new(1, -12, 0, ROW_H),
			LayoutOrder = i,
			BackgroundColor3 = Color3.fromRGB(240, 242, 236),
			ZIndex = 32,
			Parent = statList,
		}, { Ui.corner(8), Ui.padding(8) })
		local title = line(row, 0, 28, "", { Font = Enum.Font.GothamBold, TextSize = 22, ZIndex = 33, Size = UDim2.new(1, -210, 0, 28) })
		-- 다음 레벨까지 진행 막대 (오른쪽 위, ❓ 왼쪽)
		local track = Ui.make("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -38, 0, 8),
			Size = UDim2.fromOffset(160, 14),
			BackgroundColor3 = Color3.fromRGB(205, 208, 215),
			ZIndex = 33,
			Parent = row,
		}, { Ui.corner(7) })
		local fill = Ui.make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(110, 200, 120), ZIndex = 34, Parent = track }, { Ui.corner(7) })
		helpButton(row, UDim2.new(1, -28, 0, 0), `{stat.emoji} {stat.name}`, function()
			return detailText(stat)
		end, frame)
		local now = line(row, 34, 26, "", { TextSize = 18, ZIndex = 33, TextColor3 = INK })
		rows[stat.id] = { title = title, fill = fill, now = now }
	end

	local function refresh()
		local fitness = SalaryConfig.playerFitness(player)
		local sets = player:GetAttribute("GymSets") or 0
		todayText.Text = if sets >= SalaryConfig.GYM_DAILY_SETS
			then `💦 오늘 운동 끝 {sets}/{SalaryConfig.GYM_DAILY_SETS}`
			else `오늘 운동 {sets}/{SalaryConfig.GYM_DAILY_SETS}`
		for _, stat in SalaryConfig.FitnessStats do
			local info = rows[stat.id]
			local points = fitness[stat.id] or 0
			local level = SalaryConfig.fitnessLevel(points)
			local maxed = level >= SalaryConfig.FITNESS_MAX_LEVEL
			local into = points - level * SalaryConfig.FITNESS_POINTS_PER_LEVEL -- 이번 레벨에서 모은 점수
			info.title.Text = `{stat.emoji} {stat.name} Lv.{level}` .. (if maxed then " 🏆" else "")
			info.fill.Size = UDim2.fromScale(if maxed then 1 else math.clamp(into / SalaryConfig.FITNESS_POINTS_PER_LEVEL, 0, 1), 1)
			info.now.Text = shortEffects(stat.id, level)
		end
	end
	refresh()
	task.spawn(function()
		while current == frame do
			task.wait(0.5)
			if current == frame then
				refresh()
			end
		end
	end)
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

-- 🛒 꾸미기 물건·장비는 [온라인 쇼핑] 농땡이 중에만 주문돼요 (쇼핑몰). 평소엔 산 물건 장착만.
local function isShopping(): boolean
	return player:GetAttribute("SalaryState") == "shopping"
end

function Panels.showDecor(startTab: string?)
	-- 🎒 소지품 창과 같은 크기 (쇼핑 중일 때만 HUD를 가리지 않게 빈 곳에 맞춰요)
	local frameWidth = if isShopping() then 720 else 600 -- 🛒 쇼핑몰은 옆으로 더 넓게
	local frame = if isShopping() then sheet(frameWidth, 580, true) else sheet(frameWidth, 560)
	closeOnOutside(frame)
	local titleText = line(frame, 0, 32, "🪑 내 자리 꾸미기", { Font = Enum.Font.GothamBlack, TextSize = 26 })
	local balance = line(frame, 0, 32, "", { TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBold, Size = UDim2.new(1, -44, 0, 32) })
	local scoreText = line(frame, 34, 22, "", { TextSize = 15, TextColor3 = MUTED })
	local message = line(frame, 0, 22, if isShopping() then "온라인 주문하면 택배로 바로 와요 📦 부장님 오면 [1] 일하기로 복귀!" else "🛒 새 물건은 내 자리에서 [온라인 쇼핑] 농땡이를 켜야 주문돼요!", {
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
	table.insert(tabs, { id = "gear", text = "⚙️ 장비" }) -- 🖥️ 책상 업그레이드 (실제 효과!)
	local tabButtons: { [string]: TextButton } = {}
	local list = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 108),
		Size = UDim2.new(1, 0, 1, -174),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 31,
		Parent = frame,
	}, { Ui.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local selected = startTab or "chair"
	local rowButtons: { [string]: TextButton } = {}

	local function row(order: number, title: string, description: string, onClick: () -> ()): TextButton
		local r = Ui.make("Frame", {
			Size = UDim2.new(1, -12, 0, 76),
			BackgroundColor3 = Color3.fromRGB(240, 240, 236),
			LayoutOrder = order,
			ZIndex = 32,
			Parent = list,
		}, { Ui.corner(8), Ui.padding(8) })
		line(r, 0, 28, title, { Font = Enum.Font.GothamBold, TextSize = 21, ZIndex = 33, Size = UDim2.new(1, -160, 0, 28) })
		local descLabel = line(r, 30, 28, description, { TextSize = 17, ZIndex = 33, TextColor3 = MUTED, Size = UDim2.new(1, -160, 0, 28), TextScaled = true })
		Ui.make("UITextSizeConstraint", { MaxTextSize = 17, MinTextSize = 11, Parent = descLabel }) -- (긴 설명은 살짝 줄여서 한 줄에)
		local b = Ui.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(150, 46),
			TextSize = 18,
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
		if selected == "gear" then
			local levels = decodeAttr("DeskUpgrades", {})
			for i, upgrade in SalaryConfig.DeskUpgrades do
				local level = levels[upgrade.id] or 0
				local now = upgrade.levels[level]
				local nextLevel = upgrade.levels[level + 1]
				local stars = string.rep("⭐", level) .. string.rep("⚪", #upgrade.levels - level)
				local description = (if now then `지금: {now.text}` else "지금: 기본") .. (if nextLevel then ` → 다음: {nextLevel.text}` else " · 🏆 최고 단계")
				rowButtons[upgrade.id] = row(i, `{upgrade.emoji} {upgrade.name} {stars}`, description, function()
					local result = Remotes.DeskUpgrade:InvokeServer(upgrade.id)
					message.Text = result.message
					message.TextColor3 = if result.ok then Color3.fromRGB(40, 140, 70) else RED
					Sounds.play(if result.ok then "ping" else "bass", 0.6, 1.2)
					task.wait(0.15)
					if current == frame and selected == "gear" then
						render()
					end
				end)
			end
		elseif selected == "title" then
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
			Position = UDim2.fromOffset((i - 1) * ((frameWidth - 40) / #tabs), 62),
			Size = UDim2.fromOffset((frameWidth - 40) / #tabs - 4, 40),
			Text = tab.text,
			TextSize = if frameWidth > 650 then 16 else 14,
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
			local shopping = isShopping()
			titleText.Text = if shopping then "🛒 루팡 쇼핑몰" else "🪑 내 자리 꾸미기"
			scoreText.Text = `🪑 인테리어 점수 {player:GetAttribute("DecorScore") or 0}점 · 칭호 {player:GetAttribute("TitleText") or ""}`
			local owned = decodeAttr("DecorOwned", {})
			local equipped = decodeAttr("DecorEquipped", {})
			local collection = decodeAttr("Collection", {})
			if selected == "gear" then
				local levels = decodeAttr("DeskUpgrades", {})
				for _, upgrade in SalaryConfig.DeskUpgrades do
					local b = rowButtons[upgrade.id]
					if b then
						local nextLevel = upgrade.levels[(levels[upgrade.id] or 0) + 1]
						b.Text = if not nextLevel then "🏆 최고" elseif shopping then `⬆️ {comma(nextLevel.price)}원` else "🛒 쇼핑 중에만"
						b.BackgroundColor3 = if not nextLevel then Color3.fromRGB(150, 220, 150) elseif shopping then Ui.COLORS.brass else Color3.fromRGB(200, 200, 200)
					end
				end
			elseif selected == "title" then
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
							b.Text = if option.id == wearing then "장착 중 ✅" elseif has then "장착" elseif shopping then `주문 {comma(option.price)}원` else "🛒 쇼핑 중에만"
							b.BackgroundColor3 = if option.id == wearing then Color3.fromRGB(150, 220, 150) elseif has or shopping then Ui.COLORS.brass else Color3.fromRGB(200, 200, 200)
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
	for _, stateId in { "toilet", "candy", "coffee", "meeting", "rooftop", "street", "lounger", "hiding", "gym", "docs", "chat", "ramen" } do
		table.insert(actions, stateId)
	end

	local total = #actions + #SalaryConfig.Achievements
	local found = 0
	-- 가로로 넓게: 왼쪽 = 농땡이 칸, 오른쪽 = 업적 목록
	local frame = sheet(900, 430)
	closeOnOutside(frame)
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
	-- 🤝 친한 동료 (❤️ 개수)
	local friendship = {}
	pcall(function()
		friendship = HttpService:JSONDecode(player:GetAttribute("Friendship") or "{}")
	end)
	local friends = {}
	for _, name in SalaryConfig.CoworkerNames do
		local level = SalaryConfig.friendLevel(friendship[name])
		if level > 0 then
			table.insert(friends, `{name} {string.rep("❤️", level)}`)
		end
	end
	line(left, 250, 40, if #friends > 0
		then "🤝 " .. table.concat(friends, " · ")
		else "🤝 수다를 끝까지 하고 맞장구를 잘 치면 동료와 친해져요 (❤️ 4개까지)", { TextSize = 13, TextColor3 = MUTED })

	title.Text = `📖 농땡이 도감 ({found}/{total})`
	button(frame, 0, "닫기", close)
end

---------------------------------------------------------------------------
-- 도구 버튼 (왼쪽 상태창 아래)
---------------------------------------------------------------------------
-- 💬 툴바 버튼에 마우스를 올리면 무슨 버튼인지 말풍선으로 알려 줘요
local TOOL_TIPS = {
	["📖 도감"] = "📖 도감 · 농땡이 기록, 업적, 수다 주제, 친한 동료",
	["🪑"] = "🪑 내 자리 꾸미기 · 산 물건 장착, 칭호 (새 물건은 🛒 온라인 쇼핑 중에)",
	["🎒"] = "🎒 내 소지품 · 사무용품, 경비원 선물, 간식, 체력 스탯",
	["🧸"] = "🧸 내 인형 · 눌러서 책상에 진열 (최대 3개)",
	["💪"] = "💪 체력 스탯 · 레벨과 효과, 오늘 운동 횟수",
	["👔"] = "👔 출근룩 · 옷 사고 입기",
}
local toolTip = Ui.make("TextLabel", {
	AutomaticSize = Enum.AutomaticSize.X,
	Size = UDim2.fromOffset(0, 26),
	BackgroundColor3 = Color3.fromRGB(25, 28, 36),
	BackgroundTransparency = 0.1,
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	Visible = false,
	ZIndex = 60,
	Parent = gui,
}, { Ui.corner(6), Ui.padding(6) })
local toolTipOwner: GuiObject? = nil
local function showToolTip(button: GuiObject, tip: string)
	if Hud.isPhone() then
		return -- 📱 폰은 마우스가 없어서 말풍선이 안 사라질 수 있어요 → 안 띄워요
	end
	toolTipOwner = button
	toolTip.Text = tip
	toolTip.Visible = true
	-- 화면 오른쪽 밖으로 안 나가게
	local viewport = if workspace.CurrentCamera then workspace.CurrentCamera.ViewportSize.X else 1280
	local x = math.min(button.AbsolutePosition.X, viewport - toolTip.AbsoluteSize.X - 8)
	toolTip.Position = UDim2.fromOffset(math.max(4, x), button.AbsolutePosition.Y + button.AbsoluteSize.Y + 6)
end
local function hideToolTip(button: GuiObject)
	if toolTipOwner == button then
		toolTip.Visible = false
		toolTipOwner = nil
	end
end

local function toolButton(label: string, width: number, onClick: () -> (), tip: string?): TextButton
	local b = Ui.button({
		Size = UDim2.fromOffset(width, 36),
		Text = label,
		TextSize = 15,
		Parent = Hud.toolbar,
	})
	b.Activated:Connect(function()
		hideToolTip(b)
		onClick()
	end)
	local tipText = tip or TOOL_TIPS[label]
	if tipText then
		b.MouseEnter:Connect(function()
			showToolTip(b, tipText :: string)
		end)
		b.MouseLeave:Connect(function()
			hideToolTip(b)
		end)
	end
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
toolButton("💪", 46, function()
	if current then
		close()
	else
		Panels.showFitness()
	end
end)
if SalaryConfig.OUTFIT_ENABLED then -- 🚧 출근룩 잠시 꺼 둠
	toolButton("👔", 46, function()
		if current then
			close()
		else
			Panels.showOutfit()
		end
	end)
end
local energyButton = toolButton("⚡ 0", 86, function()
	Remotes.UseEnergy:FireServer()
end, "⚡ 에너지 드링크 마시기 · 오늘 하루 일하는 척 복귀 시간 절반")
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
--   🌬️ 바람 보고 → 각도·힘·방향을 [-] [+]로 맞추기 → [던지기] (클릭 또는 Enter)
--   점선 미리보기는 바람 없을 때의 처음 부분만 보여 줘요 (바람 보정은 내 실력!)
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

-- 지난번에 맞춘 값 기억 (창을 다시 열어도 그대로)
local planeSettings = {
	angle = SalaryConfig.PLANE_ANGLE.default,
	power = SalaryConfig.PLANE_POWER.default,
	aim = SalaryConfig.PLANE_AIM.default,
}

-- 🗺️ 최근에 떨어진 곳 (창을 닫았다 열어도 기억) { forward, side, onBuilding }
local planeLandings: { { forward: number, side: number, onBuilding: boolean } } = {}
local PLANE_LANDINGS_KEPT = 5

function Panels.showPlane(station: any)
	local frame = sheet(360, 470)
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.Position = UDim2.new(1, -20, 0.5, 0)
	line(frame, 0, 30, "✈️ 종이비행기", { Font = Enum.Font.GothamBlack, TextSize = 24 })
	line(frame, 30, 16, `🎯 {SalaryConfig.PLANE_TARGET_DISTANCE}m 과녁 +{comma(SalaryConfig.PLANE_TARGET_PRIZE)}원 · 점선은 "바람 없을 때" 처음 부분만!`, { TextSize = 12, TextColor3 = MUTED })
	local windLabel = line(frame, 48, 22, "🌬️ 바람 확인 중…", { TextSize = 15, Font = Enum.Font.GothamBold })

	---------------------------------------------------------------- 🗺️ 위에서 본 지도 (아래 = 발사대, 위 = 도시 쪽)
	local MAP_W, MAP_H = 320, 120
	local MAP_FORWARD, MAP_SIDE = 220, 50 -- 지도에 보이는 범위 (앞으로 m, 좌우 ±m)
	local map = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.fromOffset(MAP_W, MAP_H),
		BackgroundColor3 = Color3.fromRGB(45, 60, 85),
		ClipsDescendants = true,
		ZIndex = 31,
		Parent = frame,
	}, { Ui.corner(8) })
	local function mapPoint(forward: number, side: number): UDim2
		return UDim2.fromOffset(MAP_W / 2 + side / MAP_SIDE * MAP_W / 2, MAP_H - 8 - forward / MAP_FORWARD * (MAP_H - 16))
	end
	-- 건너편 빌딩 옥상 (55m ~ 205m, 좌우 ±42m)
	local roofTop, roofBottom = mapPoint(205, -42), mapPoint(55, 42)
	Ui.make("Frame", {
		Position = roofTop,
		Size = UDim2.fromOffset(roofBottom.X.Offset - roofTop.X.Offset, roofBottom.Y.Offset - roofTop.Y.Offset),
		BackgroundColor3 = Color3.fromRGB(140, 150, 140),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ZIndex = 32,
		Parent = map,
	})
	for distance = 100, 200, 50 do
		local point = mapPoint(distance, -MAP_SIDE)
		Ui.make("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromOffset(4, point.Y.Offset),
			Size = UDim2.fromOffset(40, 12),
			BackgroundTransparency = 1,
			Text = `{distance}m`,
			TextColor3 = Color3.fromRGB(230, 230, 240),
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 33,
			Parent = map,
		})
	end
	Ui.make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = mapPoint(SalaryConfig.PLANE_TARGET_DISTANCE, 0),
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1,
		Text = "🎯",
		TextSize = 18,
		ZIndex = 33,
		Parent = map,
	})
	Ui.make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.fromOffset(20, 16),
		BackgroundTransparency = 1,
		Text = "✈️",
		TextSize = 13,
		Rotation = -45, -- ✈️ 이모지는 오른쪽 위를 보고 있어서, 똑바로 위(과녁 쪽)를 보게 돌려요
		ZIndex = 34,
		Parent = map,
	})
	-- 📍 떨어진 곳: 예전 것은 흐린 점, 방금 것은 빨간 X (길바닥이면 지도 가장자리에 붙여요)
	local landingDots = {}
	for i = 1, PLANE_LANDINGS_KEPT - 1 do
		landingDots[i] = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(6, 6),
			BackgroundColor3 = Color3.fromRGB(255, 200, 190),
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 34,
			Parent = map,
		}, { Ui.corner(3) })
	end
	local landingMark = Ui.make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		Text = "X",
		TextColor3 = Color3.fromRGB(255, 70, 60),
		TextStrokeTransparency = 0.2,
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		Visible = false,
		ZIndex = 36,
		Parent = map,
	})
	local mapNote = Ui.make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 2),
		Size = UDim2.fromOffset(150, 14),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(255, 220, 120),
		TextStrokeTransparency = 0.4,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 36,
		Parent = map,
	})
	local function landingPoint(landing): UDim2
		-- 지도 밖(길바닥·너무 멀리)이면 가장자리 안쪽으로 당겨서 보여 줘요
		return mapPoint(math.clamp(landing.forward, 0, MAP_FORWARD - 2), math.clamp(landing.side, -MAP_SIDE + 3, MAP_SIDE - 3))
	end
	local function drawLandings()
		local count = #planeLandings
		for i, dot in landingDots do
			local landing = planeLandings[count - i] -- (방금 것 바로 전부터 거꾸로)
			dot.Visible = landing ~= nil
			if landing then
				dot.Position = landingPoint(landing)
				dot.BackgroundTransparency = 0.25 + i * 0.12
				dot.BackgroundColor3 = if landing.onBuilding then Color3.fromRGB(255, 200, 190) else Color3.fromRGB(170, 170, 180)
			end
		end
		local latest = planeLandings[count]
		landingMark.Visible = latest ~= nil
		if latest then
			landingMark.Position = landingPoint(latest)
		end
	end
	drawLandings()
	if #planeLandings > 0 then
		mapNote.Text = "X = 지난번 떨어진 곳"
	end
	local DOTS = 8
	local mapDots = {}
	for i = 1, DOTS do
		mapDots[i] = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(5, 5),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 35,
			Parent = map,
		}, { Ui.corner(3) })
	end
	-- 3D 미리보기 점 (내 화면에만 보여요)
	local worldDots = Instance.new("Folder")
	worldDots.Name = "PlanePreview"
	worldDots.Parent = workspace
	local balls = {}
	for i = 1, DOTS do
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(0.35, 0.35, 0.35)
		ball.Material = Enum.Material.Neon
		ball.Color = Color3.fromRGB(255, 255, 255)
		ball.Anchored = true
		ball.CanCollide = false
		ball.CanQuery = false
		ball.CanTouch = false
		ball.Transparency = 1
		ball.Parent = worldDots
		balls[i] = ball
	end

	---------------------------------------------------------------- 각도 · 힘 · 방향 조절 ([-] [+])
	local function stepper(y: number, title: string, key: string, spec, format: (number) -> string, hint: string): ((() -> ()) -> ())
		line(frame, y, 30, title, { TextSize = 15, Font = Enum.Font.GothamBold, TextYAlignment = Enum.TextYAlignment.Center, Size = UDim2.fromOffset(64, 30) })
		local valueLabel = line(frame, y, 30, "", {
			Position = UDim2.fromOffset(116, y),
			Size = UDim2.fromOffset(90, 30),
			TextSize = 17,
			Font = Enum.Font.GothamBlack,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		})
		line(frame, y, 30, hint, {
			Position = UDim2.fromOffset(258, y),
			Size = UDim2.fromOffset(62, 30),
			TextSize = 11,
			TextColor3 = MUTED,
			TextYAlignment = Enum.TextYAlignment.Center,
		})
		local function refresh()
			valueLabel.Text = format(planeSettings[key])
		end
		local onChange: () -> () = function() end
		for _, info in { { 68, "-", -1 }, { 212, "+", 1 } } do
			local b = Ui.button({
				Position = UDim2.fromOffset(info[1], y),
				Size = UDim2.fromOffset(42, 30),
				Text = info[2],
				TextSize = 22,
				ZIndex = 31,
				Parent = frame,
			})
			b.MouseButton1Down:Connect(function()
				local before = planeSettings[key]
				planeSettings[key] = SalaryConfig.planeSnap(before + info[3] * spec.step, spec)
				if planeSettings[key] ~= before then
					Sounds.play("click", 0.3, 1 + info[3] * 0.1)
					refresh()
					onChange()
				end
			end)
		end
		refresh()
		return function(callback: () -> ())
			onChange = callback
		end
	end
	local onAngle = stepper(200, "📐 각도", "angle", SalaryConfig.PLANE_ANGLE, function(v)
		return `{v}°`
	end, "25° 근처가 제일 멀리")
	local onPower = stepper(234, "💪 힘", "power", SalaryConfig.PLANE_POWER, function(v)
		return `{v}%`
	end, "세게 = 멀리")
	local onAim = stepper(268, "↔️ 방향", "aim", SalaryConfig.PLANE_AIM, function(v)
		return if v == 0 then "가운데" elseif v < 0 then `왼쪽 {-v}°` else `오른쪽 {v}°`
	end, "옆바람 반대로!")
	local result = line(frame, 304, 68, "", { TextSize = 14, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center })

	local throwButton = Ui.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 50),
		Text = "✈️ 던지기 (Enter)",
		TextSize = 18,
		ZIndex = 31,
		Parent = frame,
	})

	-- 미리보기: 바람 없을 때 경로의 앞쪽 PLANE_PREVIEW만큼 (떨어지는 곳은 안 보여 줘요)
	local spot: any = nil -- 서버가 알려 준 발사 위치 { start, launch, roofY }
	local flying = false
	-- ⚖️ 균형감: 미리보기 점선이 길어져요 (최대 +60%, 창을 열 때 레벨로)
	local previewLength = math.min(1, SalaryConfig.PLANE_PREVIEW * (1 + SalaryConfig.playerFitnessEffect(player, "aim")))
	local function updatePreview()
		local forward, side, distance = SalaryConfig.planeLanding(planeSettings.angle, planeSettings.power / 100, planeSettings.aim, 0, 0)
		local start = if spot then spot.start else Vector3.new(0, 3.2, -1.5)
		local launch = if spot then spot.launch else Vector3.zero
		local roofY = if spot then spot.roofY else -8
		local finish = Vector3.new(launch.X + side, roofY, launch.Z - forward)
		local control = SalaryConfig.planeControl(start, finish, distance, planeSettings.angle)
		for i = 1, DOTS do
			local t = i / DOTS * previewLength
			local position = start:Lerp(control, t):Lerp(control:Lerp(finish, t), t)
			local dot = mapDots[i]
			dot.Position = mapPoint(launch.Z - position.Z, position.X - launch.X)
			dot.Visible = not flying
			balls[i].Position = position
			balls[i].Transparency = if spot and not flying then 0.2 else 1
		end
	end
	onAngle(updatePreview)
	onPower(updatePreview)
	onAim(updatePreview)
	updatePreview()

	-- 🎥 발사 시점: 발사대 뒤·위에서 건너편 빌딩 🎯 과녁 쪽을 봐요 (창이 닫히면 어떤 이유든 원래 카메라로)
	local cameraMoved = false
	local cameraTween: Tween? = nil
	local function launchView(r)
		local camera = workspace.CurrentCamera
		if cameraMoved or not camera or typeof(r.launch) ~= "Vector3" or typeof(r.target) ~= "Vector3" then
			return
		end
		local forward = if typeof(r.forward) == "Vector3" then r.forward else Vector3.new(0, 0, -1)
		local right = forward:Cross(Vector3.yAxis)
		local eye = r.launch - forward * 9 + right * 3 + Vector3.new(0, 7, 0)
		-- 오른쪽에 창이 있으니 과녁이 화면 왼쪽·가운데쯤 오게 살짝 오른쪽을 봐요
		local look = r.target + right * 14 + Vector3.new(0, 4, 0)
		cameraMoved = true
		camera.CameraType = Enum.CameraType.Scriptable
		cameraTween = TweenService:Create(camera, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = CFrame.lookAt(eye, look) })
		cameraTween:Play()
	end
	local function restoreCamera()
		if not cameraMoved then
			return
		end
		cameraMoved = false
		if cameraTween then
			cameraTween:Cancel()
			cameraTween = nil
		end
		local camera = workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Custom
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
	end

	-- 🌬️ 바람 받아 오기 (던질 때까지 같은 바람이에요)
	local function fetchWind()
		local r = Remotes.PlaneThrow:InvokeServer("begin")
		if current ~= frame then
			return
		end
		if not r.ok then
			windLabel.Text = r.message
			windLabel.TextColor3 = RED
			return
		end
		windLabel.Text = windText(r.wind)
		windLabel.TextColor3 = INK
		spot = { start = r.start, launch = r.launch, roofY = r.roofY }
		updatePreview()
		launchView(r)
	end

	local busy = false
	local function act()
		if busy or flying then
			return
		end
		busy = true
		local r = Remotes.PlaneThrow:InvokeServer("throw", planeSettings.angle, planeSettings.power, planeSettings.aim)
		busy = false
		if current ~= frame then
			return
		end
		if not r.ok then
			result.Text = r.message
			result.TextColor3 = RED
			return
		end
		flying = true
		updatePreview()
		throwButton.Text = "✈️ 슈웅~"
		Sounds.play("swoosh", 0.7, 1.2)
		result.Text = "✈️ 날아가는 중…"
		result.TextColor3 = MUTED
		task.delay(r.duration, function()
			-- 📍 떨어진 곳 기억 (창을 닫았어도 다음에 열면 지도에 보여요 · 되돌아온 건 빼요)
			if not r.boomerang and typeof(r.forward) == "number" and typeof(r.side) == "number" then
				table.insert(planeLandings, { forward = r.forward, side = r.side, onBuilding = r.onBuilding == true })
				while #planeLandings > PLANE_LANDINGS_KEPT do
					table.remove(planeLandings, 1)
				end
			end
			if current ~= frame then
				return
			end
			if r.boomerang then
				mapNote.Text = "🔄 되돌아와서 착지 없음"
			elseif r.onBuilding then
				mapNote.Text = if r.hitTarget then "🎯 X = 과녁 명중!" else "X = 방금 떨어진 곳"
			else
				mapNote.Text = "X = 길바닥 (옥상 밖)"
			end
			drawLandings()
			local lines = { r.label }
			if r.distance > 0 then
				table.insert(lines, `{math.floor(r.distance)}m` .. (if r.record then " · 🏆 내 최고 기록!" else ` · 내 최고 {r.best or 0}m`))
			end
			if r.prize > 0 then
				table.insert(lines, `+{comma(r.prize)}원 (오늘 상금 {r.prizesLeft}번 더)`)
			elseif r.hitTarget or (r.distance >= SalaryConfig.PlanePrizes[#SalaryConfig.PlanePrizes].distance) then
				table.insert(lines, "(오늘 상금은 다 받았어요)")
			end
			-- 다음 던지기 보정 힌트: 과녁보다 얼마나 짧았는지/넘어갔는지, 좌우로 얼마나
			if not r.hitTarget and not r.boomerang then
				local long = math.floor(math.abs(r.missLong) + 0.5)
				local side = math.floor(math.abs(r.missSide) + 0.5)
				local front = if long == 0 then "앞뒤 딱 맞음" elseif r.missLong < 0 then `{long}m 짧음` else `{long}m 넘어감`
				local lateral = if side == 0 then "좌우 딱 맞음" elseif r.missSide < 0 then `왼쪽 {side}m` else `오른쪽 {side}m`
				table.insert(lines, `🎯 과녁 기준: {front} · {lateral}`)
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
			flying = false
			throwButton.Text = "✈️ 한 번 더 (Enter)"
			fetchWind() -- 새 바람
		end)
	end
	throwButton.MouseButton1Down:Connect(act)
	local keyConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and current == frame and (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter) then
			act()
		end
	end)
	-- 창이 닫히면 정리
	frame.Destroying:Connect(function()
		keyConnection:Disconnect()
		worldDots:Destroy()
		restoreCamera() -- 🎥 닫기 버튼 · 다른 창 · 멀어짐 · 쓰러짐 모두 여기로 와요
	end)
	closeWhenAway(frame, station, 11) -- 🚪 발사대에서 11칸 넘게 멀어지면 닫혀요 (서버는 12칸까지 받아요)
	Sounds.play("swoosh", 0.4)
	task.spawn(fetchWind)
end
Remotes:WaitForChild("PlaneOpen").OnClientEvent:Connect(function(station)
	Panels.showPlane(station)
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

-- 🎒 내 씨앗 (씨앗 ID → 개수)
local function readSeeds(): { [string]: number }
	local ok, seeds = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Seeds") or "{}")
	end)
	return if ok and typeof(seeds) == "table" then seeds else {}
end

-- 화분 상태: "empty" / "dead" / "ripe" / "wilted" / "growing" (⚡ 쾌속 식물은 서버 시각으로 익어요)
local function slotState(slot): string
	return SalaryConfig.gardenState(slot, workspace:GetServerTimeNow())
end

-- 자란 정도 0~1 (⚡ 쾌속 식물은 물 준 뒤 남은 시간으로)
local function growRatio(slot, seed): number
	if seed.minutes and (slot.readyAt or 0) > 0 then
		local total = SalaryConfig.gameMinutesToSeconds(seed.minutes)
		return math.clamp(1 - (slot.readyAt - workspace:GetServerTimeNow()) / total, 0, 1)
	end
	return math.clamp(slot.growth / seed.days, 0, 1)
end

-- 🌱 화분 위 식물 그리기 (씨앗 kind마다 생김새가 달라요)
--   piece(크기, 위치, 색, 모양) / r = 자란 정도 0~1 / ripe = 다 자람 / leaf = 잎 색 (시들면 누렇게)
local function drawPlant(piece, seed, r: number, ripe: boolean, leaf: Color3)
	local kind = seed.kind or "fruit"
	local c = seed.color
	local stem = Color3.fromRGB(90, 140, 60)
	local wood = Color3.fromRGB(120, 85, 50)
	if kind == "leafy" or kind == "clover" then
		-- 🥬 동그란 잎 뭉치 / 🍀 낮게 깔린 잎 네 장
		if kind == "leafy" then
			local size = 0.6 + r * 1
			piece(Vector3.new(size, size * 0.7, size), Vector3.new(0, size * 0.35, 0), if ripe then c else leaf, Enum.PartType.Ball)
		else
			for k = 0, 3 do
				local angle = k * math.pi / 2
				local size = 0.3 + r * 0.35
				local p = piece(Vector3.new(size, 0.1, size), Vector3.new(math.cos(angle) * size * 0.55, 0.25 + r * 0.25, math.sin(angle) * size * 0.55), if ripe then c else leaf, Enum.PartType.Ball)
				p.Material = if ripe then Enum.Material.Neon else Enum.Material.SmoothPlastic
			end
			piece(Vector3.new(0.06, 0.25 + r * 0.25, 0.06), Vector3.new(0, (0.25 + r * 0.25) / 2, 0), stem)
		end
	elseif kind == "root" then
		-- 🥕 잎만 삐죽, 다 자라면 머리가 쏙
		for k = -1, 1 do
			piece(Vector3.new(0.12, 0.4 + r * 0.6, 0.12), Vector3.new(k * 0.15, (0.4 + r * 0.6) / 2, 0), leaf)
		end
		if ripe then
			piece(Vector3.new(0.45, 0.35, 0.45), Vector3.new(0, 0.1, 0), c, Enum.PartType.Ball)
		end
	elseif kind == "stalk" then
		-- 🌽 키 큰 줄기 + 옥수수
		local h = 0.8 + r * 2
		piece(Vector3.new(0.16, h, 0.16), Vector3.new(0, h / 2, 0), stem)
		for k = 1, 3 do
			piece(Vector3.new(0.7, 0.06, 0.2), Vector3.new((k % 2 * 2 - 1) * 0.3, h * k / 4, 0), leaf)
		end
		if ripe then
			piece(Vector3.new(0.3, 0.7, 0.3), Vector3.new(0.18, h * 0.7, 0), c)
		end
	elseif kind == "flower" then
		-- 🌹🌻 긴 줄기 + 꽃잎 (덜 자라면 꽃봉오리)
		local h = 0.6 + r * 1.3
		piece(Vector3.new(0.1, h, 0.1), Vector3.new(0, h / 2, 0), stem)
		piece(Vector3.new(0.5, 0.06, 0.2), Vector3.new(0.2, h * 0.45, 0), leaf)
		if ripe then
			for k = 1, 6 do
				local angle = k / 6 * math.pi * 2
				piece(Vector3.new(0.32, 0.32, 0.1), Vector3.new(math.cos(angle) * 0.28, h + math.sin(angle) * 0.28, 0), c, Enum.PartType.Ball)
			end
			piece(Vector3.new(0.3, 0.3, 0.14), Vector3.new(0, h, 0), Color3.fromRGB(110, 70, 30), Enum.PartType.Ball)
		else
			piece(Vector3.new(0.25, 0.35, 0.25), Vector3.new(0, h, 0), leaf, Enum.PartType.Ball)
		end
	elseif kind == "cactus" then
		-- 🌵 기둥 + 팔 (다 자라면 분홍 꽃)
		local h = 0.5 + r * 1.3
		piece(Vector3.new(0.4, h, 0.4), Vector3.new(0, h / 2, 0), c)
		if r >= 0.5 then
			piece(Vector3.new(0.25, 0.5, 0.25), Vector3.new(0.32, h * 0.6, 0), c)
			piece(Vector3.new(0.25, 0.4, 0.25), Vector3.new(-0.32, h * 0.45, 0), c)
		end
		if ripe then
			piece(Vector3.new(0.3, 0.2, 0.3), Vector3.new(0, h + 0.05, 0), Color3.fromRGB(255, 120, 180), Enum.PartType.Ball)
		end
	elseif kind == "tree" then
		-- 🍇 나무줄기 + 둥근 잎 (열매 주렁주렁)
		local h = 0.6 + r * 1.2
		piece(Vector3.new(0.22, h, 0.22), Vector3.new(0, h / 2, 0), wood)
		local crown = 0.8 + r * 0.9
		piece(Vector3.new(crown, crown * 0.8, crown), Vector3.new(0, h + crown * 0.25, 0), leaf, Enum.PartType.Ball)
		if ripe then
			for k = 1, 6 do
				local angle = k / 6 * math.pi * 2
				piece(Vector3.new(0.26, 0.4, 0.26), Vector3.new(math.cos(angle) * crown * 0.42, h, math.sin(angle) * crown * 0.42), c, Enum.PartType.Ball)
			end
		end
	elseif kind == "vine" then
		-- 🍉🎃 바닥에 덩굴 + 점점 커지는 큰 열매
		piece(Vector3.new(1.4, 0.12, 0.9), Vector3.new(-0.2, 0.06, 0), leaf, Enum.PartType.Ball)
		local size = 0.25 + r * 0.85
		local fruit = piece(Vector3.new(size * 1.2, size, size), Vector3.new(0.25, size / 2, 0), if r > 0.3 then c else leaf, Enum.PartType.Ball)
		fruit.Material = if ripe then Enum.Material.Glass else Enum.Material.SmoothPlastic
	elseif kind == "mushroom" then
		-- 🍄 하얀 기둥 + 갓
		local h = 0.2 + r * 0.5
		piece(Vector3.new(0.18, h, 0.18), Vector3.new(0, h / 2, 0), Color3.fromRGB(240, 235, 220))
		local cap = 0.3 + r * 0.5
		piece(Vector3.new(cap, cap * 0.45, cap), Vector3.new(0, h, 0), c, Enum.PartType.Ball)
	else
		-- 🍅🌶️🍓 덤불 + 열매
		local h = 0.6 + r * 1.1
		piece(Vector3.new(0.12, h, 0.12), Vector3.new(0, h / 2, 0), stem)
		local bush = 0.7 + r * 0.9
		piece(Vector3.new(bush, bush * 0.8, bush), Vector3.new(0, h, 0), leaf, Enum.PartType.Ball)
		if ripe then
			for k = 1, 5 do
				local angle = k / 5 * math.pi * 2
				local fruit = piece(Vector3.new(0.32, 0.32, 0.32), Vector3.new(math.cos(angle) * bush * 0.45, h - 0.1 + (k % 2) * 0.25, math.sin(angle) * bush * 0.45), c, Enum.PartType.Ball)
				fruit.Material = Enum.Material.Glass
			end
		end
	end
end

local gardenFolder = Instance.new("Folder")
gardenFolder.Name = "MyGarden"
gardenFolder.Parent = workspace
local renderVersion = 0
local function renderGarden()
	renderVersion += 1
	local version = renderVersion
	gardenFolder:ClearAllChildren()
	local ok, slots = pcall(function()
		return HttpService:JSONDecode(ReplicatedStorage:GetAttribute("GardenSlots") or "[]")
	end)
	if not ok or typeof(slots) ~= "table" then
		return
	end
	local garden, today = readGarden()
	local nextReady = math.huge -- ⚡ 쾌속 식물이 익는 시각에 다시 그려요
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
		if state == "growing" and seed.minutes and (slot.readyAt or 0) > 0 then
			nextReady = math.min(nextReady, slot.readyAt)
		end
		if state == "dead" then
			piece(Vector3.new(0.12, 0.9, 0.12), Vector3.new(0, 0.45, 0), Color3.fromRGB(110, 80, 50))
			piece(Vector3.new(0.5, 0.08, 0.3), Vector3.new(0.15, 0.85, 0), Color3.fromRGB(130, 100, 60))
		elseif state ~= "ripe" and slot.growth == 0 and not (seed.minutes and (slot.readyAt or 0) > 0) then
			-- 🌱 새싹
			piece(Vector3.new(0.08, 0.35, 0.08), Vector3.new(0, 0.18, 0), leaf)
			piece(Vector3.new(0.35, 0.06, 0.18), Vector3.new(-0.15, 0.36, 0), leaf)
			piece(Vector3.new(0.35, 0.06, 0.18), Vector3.new(0.15, 0.38, 0), leaf)
		else
			local ripe = state == "ripe"
			drawPlant(piece, seed, if ripe then 1 else growRatio(slot, seed), ripe, leaf)
		end
		-- 머리 위 표시: 다 자랐어요 / 목말라요
		local thirsty = not seed.noWater and slot.watered ~= today
		local mark = if state == "ripe" then `✨{seed.emoji}` elseif state == "dead" then "💀" elseif thirsty then "💧?" else nil
		if mark then
			local holder = piece(Vector3.new(0.2, 0.2, 0.2), Vector3.new(0, 2.8, 0), Color3.new(1, 1, 1))
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
	if nextReady < math.huge then
		-- ⚡ 쾌속 식물: 자라는 모습을 몇 번 더 그리고, 익는 순간 ✨
		task.delay(math.clamp(nextReady - workspace:GetServerTimeNow(), 1, 15) + 0.2, function()
			if renderVersion == version then
				renderGarden()
			end
		end)
	end
end
player:GetAttributeChangedSignal("Garden"):Connect(renderGarden)
player:GetAttributeChangedSignal("GardenToday"):Connect(renderGarden)
ReplicatedStorage:GetAttributeChangedSignal("GardenSlots"):Connect(renderGarden)
task.defer(renderGarden)

function Panels.showGarden(station: any)
	local frame = sheet(565, 560) -- (화분 6칸: 3칸씩 두 줄)
	closeWhenAway(frame, station, 11) -- 🚪 화분에서 11칸 넘게 멀어지면 닫혀요 (서버는 12칸까지 받아요)
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.Position = UDim2.new(1, -20, 0.5, 0)
	line(frame, 0, 30, "🌱 직장인 텃밭", { Font = Enum.Font.GothamBlack, TextSize = 24 })
	line(frame, 32, 20, "💧 매일 물 주기 · 퇴근하면 자라요", { TextSize = 13, TextColor3 = MUTED })
	helpButton(frame, UDim2.new(1, -70, 0, 1), "텃밭 규칙", "🏪 사내 매점 <b>[🌱 씨앗]</b> 탭에서 씨앗을 사면 🎒에 들어와요\n🌱 빈 화분에서 <b>[씨앗 심기]</b>\n💧 하루 한 번 물을 주고 퇴근하면 하루만큼 자라요\n🥀 하루 안 주면 시들고, <font color=\"#c83228\">이틀 안 주면 💀 말라 죽어요</font> (예민한 식물은 하루만 걸러도 💀)\n🧺 다 자라면 💰 팔거나 🎁 부장님 선물로 챙겨요\n⚡ 쾌속 식물은 물 주면 바로 자라요 · 🌵 선인장은 물이 필요 없어요")
	local message = line(frame, 0, 24, "", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local busy = false
	local cards = {}
	local timers: { { label: TextLabel, readyAt: number } } = {} -- ⏳ 쾌속 식물 남은 시간
	local picker: Frame? = nil
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

	-- 🌱 씨앗 고르기 창: 🎒에 있는 씨앗은 [심기], 없는 건 "🏪 매점에서"
	local function closePicker()
		if picker then
			picker:Destroy()
			picker = nil
		end
	end
	local function openPicker(index: number)
		closePicker()
		local box = Ui.make("Frame", {
			Position = UDim2.fromOffset(0, 58),
			Size = UDim2.fromOffset(CARD_W * 2 + 10, CARD_H * 2 + 10),
			BackgroundColor3 = Color3.fromRGB(245, 250, 240),
			ZIndex = 40,
			Parent = frame,
		}, { Ui.corner(10), Ui.padding(8), Ui.stroke(Color3.fromRGB(110, 170, 90), 2) })
		picker = box
		line(box, 0, 22, `🌱 {index}번 화분에 뭘 심을까요?`, { Font = Enum.Font.GothamBlack, TextSize = 16, ZIndex = 41 })
		local cancel = Ui.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(64, 22),
			Text = "◀ 취소",
			TextSize = 12,
			BackgroundColor3 = Color3.fromRGB(215, 215, 215),
			ZIndex = 41,
			Parent = box,
		})
		cancel.Activated:Connect(closePicker)
		local list = Ui.make("ScrollingFrame", {
			Position = UDim2.fromOffset(0, 28),
			Size = UDim2.new(1, 0, 1, -28),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 5,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ZIndex = 41,
			Parent = box,
		}, { Ui.make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
		local seeds = readSeeds()
		-- 가진 씨앗 먼저
		local sorted = table.clone(SalaryConfig.GardenSeeds)
		table.sort(sorted, function(a, b)
			local ha, hb = (seeds[a.id] or 0) > 0, (seeds[b.id] or 0) > 0
			if ha ~= hb then
				return ha
			end
			return (table.find(SalaryConfig.GardenSeeds, a) or 0) < (table.find(SalaryConfig.GardenSeeds, b) or 0)
		end)
		for k, seed in sorted do
			local n = seeds[seed.id] or 0
			local row = Ui.make("Frame", {
				Size = UDim2.new(1, -8, 0, 44),
				BackgroundColor3 = if n > 0 then Color3.fromRGB(225, 242, 215) else Color3.fromRGB(232, 232, 232),
				LayoutOrder = k,
				ZIndex = 42,
				Parent = list,
			}, { Ui.corner(6), Ui.padding(4) })
			line(row, 0, 18, `{seed.emoji} {seed.name}` .. (if n > 0 then ` 🎒x{n}` else ""), { Font = Enum.Font.GothamBold, TextSize = 14, ZIndex = 43, TextColor3 = if n > 0 then INK else MUTED, Size = UDim2.new(1, -84, 0, 18) })
			line(row, 18, 18, `{SalaryConfig.seedGrowText(seed)} → 💰{comma(seed.sell)}원 {SalaryConfig.seedPerkText(seed)}`, { TextSize = 11, ZIndex = 43, TextColor3 = MUTED, Size = UDim2.new(1, -84, 0, 18), TextScaled = true })
			local b = Ui.button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(80, 30),
				Text = if n > 0 then "🌱 심기" else "🏪 매점에서",
				TextSize = 12,
				BackgroundColor3 = if n > 0 then Color3.fromRGB(150, 210, 120) else Color3.fromRGB(210, 210, 210),
				AutoButtonColor = n > 0,
				ZIndex = 43,
				Parent = row,
			})
			b.Activated:Connect(function()
				if n <= 0 then
					message.Text = `🏪 매점에서 {seed.emoji} 씨앗을 사 와요`
					message.TextColor3 = MUTED
					return
				end
				closePicker()
				act("plant", index, seed.id)
			end)
		end
	end

	local function rebuild()
		for _, card in cards do
			card:Destroy()
		end
		table.clear(cards)
		table.clear(timers)
		local garden, today = readGarden()
		local seedKinds = 0
		for _, n in readSeeds() do
			if n > 0 then
				seedKinds += 1
			end
		end
		for i = 1, SalaryConfig.GARDEN_SLOTS do
			local slot = garden[i]
			local seed = SalaryConfig.getSeed(slot.seed)
			local state = slotState(slot)
			local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
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
			local function smallButton(x: number, y: number, w: number, text: string, color: Color3, onClick: () -> (), h: number?)
				local b = Ui.button({
					Position = UDim2.fromOffset(x, y),
					Size = UDim2.fromOffset(w, h or 32),
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
				label(0, 34, "➕", 28) -- (🪴 화분 이모지는 로블록스에서 네모로 보여요)
				label(36, 20, `{i}번 화분 · 비었어요`, 13, MUTED)
				smallButton(0, 70, CARD_W - 16, "🌱 씨앗 심기", Color3.fromRGB(170, 220, 140), function()
					openPicker(i)
				end, 40)
				if seedKinds > 0 then
					label(120, 24, `🎒 씨앗 {seedKinds}종`, 12, MUTED)
				end
			else
				local stageEmoji = if state == "dead" then "💀" elseif state == "ripe" then seed.emoji elseif slot.growth == 0 then "🌱" elseif state == "wilted" then "🥀" else "🌿"
				label(0, 34, stageEmoji, 28)
				label(36, 20, `{seed.emoji} {seed.name}`, 14)
				local pending = seed.minutes and (slot.readyAt or 0) > 0
				local statusText = if state == "dead"
					then "말라 죽었어요…"
					elseif state == "ripe" then "🧺 다 자랐어요!"
					elseif state == "wilted" then "🥀 시들었어요! 물 주세요"
					elseif pending then "⏳ 쑥쑥 자라는 중…"
					elseif seed.noWater then `🏜️ 물 필요 없어요 ({slot.growth}/{seed.days}일)`
					elseif slot.watered == today then `✅ 오늘 물 줌 ({slot.growth}/{seed.days}일)`
					elseif seed.minutes then "💧 물 주면 바로 자라요"
					else `💧 목말라요 ({slot.growth}/{seed.days}일)`
				local status = label(58, 32, statusText, 12, if state == "wilted" or state == "dead" then RED else MUTED)
				if pending and state ~= "ripe" and state ~= "dead" then
					table.insert(timers, { label = status, readyAt = slot.readyAt })
				end
				-- 자란 정도 막대
				local back = Ui.make("Frame", { Position = UDim2.fromOffset(0, 94), Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = Color3.fromRGB(215, 215, 210), ZIndex = 32, Parent = card }, { Ui.corner(4) })
				Ui.make("Frame", { Size = UDim2.fromScale(if state == "ripe" then 1 else growRatio(slot, seed), 1), BackgroundColor3 = Color3.fromRGB(110, 190, 90), ZIndex = 33, Parent = back }, { Ui.corner(4) })
				if state == "dead" then
					smallButton(0, 112, CARD_W - 16, "🧹 뽑고 비우기", Color3.fromRGB(225, 210, 195), function()
						act("clear", i)
					end)
				elseif state == "ripe" then
					local bonus = if seed.sunsetBonus and ReplicatedStorage:GetAttribute("Sunset") == true then ` 🌅x{seed.sunsetBonus}` else ""
					smallButton(0, 112, CARD_W - 16, `💰 팔기 +{comma(seed.sell)}원{bonus}`, Color3.fromRGB(255, 215, 110), function()
						act("sell", i)
					end)
					smallButton(0, 150, CARD_W - 16, "🎁 부장님 선물로 챙기기", Color3.fromRGB(200, 225, 255), function()
						act("gift", i)
					end)
				else
					local done = seed.noWater or slot.watered == today
					local waterButton = smallButton(0, 112, CARD_W - 16, if seed.noWater then "🌵 알아서 자라요" elseif done then "✅ 오늘은 충분해요" else "💧 물 주기", if done then Color3.fromRGB(215, 215, 215) else Color3.fromRGB(150, 205, 255), function()
						act("water", i)
					end)
					waterButton.AutoButtonColor = not done
					label(146, 22, `다 자라면 💰{comma(seed.sell)}원`, 11, MUTED)
					-- 🧹 뽑기 (두 번 눌러야 뽑혀요)
					local armed = false
					local clearButton
					clearButton = smallButton(0, 170, CARD_W - 16, "🧹 뽑기", Color3.fromRGB(230, 225, 215), function()
						if armed then
							act("clear", i)
						else
							armed = true
							clearButton.Text = "정말 뽑을까요? (한 번 더)"
							clearButton.BackgroundColor3 = Color3.fromRGB(255, 190, 170)
						end
					end, 24)
				end
			end
		end
	end
	rebuild()
	local function refresh()
		if current == frame then
			rebuild()
		end
	end
	local connections = {
		player:GetAttributeChangedSignal("Garden"):Connect(refresh),
		player:GetAttributeChangedSignal("GardenToday"):Connect(refresh),
		player:GetAttributeChangedSignal("Seeds"):Connect(refresh),
	}
	task.spawn(function()
		while current == frame do
			task.wait(0.5)
			-- ⏳ 쾌속 식물 남은 시간 → 익으면 다시 그려요
			local now = workspace:GetServerTimeNow()
			local ripened = false
			for _, timer in timers do
				local left = timer.readyAt - now
				if left <= 0 then
					ripened = true
				else
					timer.label.Text = `⏳ 수확까지 {math.ceil(left)}초`
				end
			end
			if ripened and current == frame then
				rebuild()
			end
		end
		for _, connection in connections do
			connection:Disconnect()
		end
	end)
	Sounds.play("swoosh", 0.4)
end
Remotes:WaitForChild("GardenOpen").OnClientEvent:Connect(function(station)
	Panels.showGarden(station)
end)

---------------------------------------------------------------------------
-- 🌷 내 공원 화단 (눈치물산): 화단 창 + 화단 위에 내 꽃 그리기 (내 화면에만 보여요)
---------------------------------------------------------------------------
local function readPark(): ({ any }, number)
	local ok, beds = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("ParkGarden") or "[]")
	end)
	beds = if ok and typeof(beds) == "table" then beds else {}
	for i = 1, SalaryConfig.PARK_BEDS do
		if typeof(beds[i]) ~= "table" then
			beds[i] = { flower = "", growth = 0, watered = -1, fedStage = -1 }
		end
	end
	return beds, player:GetAttribute("GardenToday") or 0
end

-- 🎒 내 꽃씨 (꽃 ID → 개수)
local function readFlowerSeeds(): { [string]: number }
	local ok, seeds = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("FlowerSeeds") or "{}")
	end)
	return if ok and typeof(seeds) == "table" then seeds else {}
end

-- 오늘 이 화단에 할 일 → (💧 물 필요, 🧪 거름 필요)
local function bedTodo(bed, flower, today: number): (boolean, boolean)
	if not flower or (bed.growth or 0) >= flower.days then
		return false, false
	end
	local needWater = bed.watered ~= today
	local needFeed = SalaryConfig.parkNeedsFeed(flower, bed.growth or 0) and bed.fedStage ~= bed.growth
	return needWater, needFeed
end

local UP = CFrame.Angles(0, 0, math.pi / 2) -- 원기둥(Cylinder)을 세워서 납작한 꽃잎 원반으로
local STEM = Color3.fromRGB(80, 150, 60)
local LEAF = Color3.fromRGB(70, 160, 70)

-- 🌸 활짝 핀 꽃 한 송이(또는 한 덤불) 그리기 — piece(크기, 위치, 색, 모양, 회전) / c = 꽃 색 / rng = 송이마다 조금씩 다르게
local function drawFlower(piece, flower, c: Color3, rng: Random)
	local shape = flower.shape
	local yaw = rng:NextNumber(0, math.pi * 2)
	if shape == "daisy" then
		local h = rng:NextNumber(0.5, 0.75)
		piece(Vector3.new(0.07, h, 0.07), Vector3.new(0, h / 2, 0), STEM)
		piece(Vector3.new(0.06, 0.62, 0.62), Vector3.new(0, h, 0), c, Enum.PartType.Cylinder, UP)
		piece(Vector3.new(0.24, 0.24, 0.24), Vector3.new(0, h + 0.04, 0), Color3.fromRGB(255, 200, 40), Enum.PartType.Ball)
	elseif shape == "cup" then
		local h = rng:NextNumber(0.7, 1)
		piece(Vector3.new(0.08, h, 0.08), Vector3.new(0, h / 2, 0), STEM)
		piece(Vector3.new(0.5, 0.06, 0.16), Vector3.new(0.12, h * 0.35, 0), LEAF, nil, CFrame.Angles(0, yaw, 0.5))
		piece(Vector3.new(0.36, 0.36, 0.36), Vector3.new(0, h, 0), c, Enum.PartType.Ball)
		piece(Vector3.new(0.3, 0.36, 0.36), Vector3.new(0, h + 0.16, 0), c, Enum.PartType.Cylinder, UP)
	elseif shape == "rose" then
		local h = rng:NextNumber(0.7, 1)
		piece(Vector3.new(0.08, h, 0.08), Vector3.new(0, h / 2, 0), Color3.fromRGB(50, 110, 50))
		piece(Vector3.new(0.5, 0.06, 0.2), Vector3.new(-0.12, h * 0.5, 0), LEAF, nil, CFrame.Angles(0, yaw, -0.4))
		piece(Vector3.new(0.44, 0.44, 0.44), Vector3.new(0, h, 0), c, Enum.PartType.Ball)
		piece(Vector3.new(0.26, 0.26, 0.26), Vector3.new(0, h + 0.17, 0), c:Lerp(Color3.new(0, 0, 0), 0.25), Enum.PartType.Ball)
	elseif shape == "sunflower" then
		local h = rng:NextNumber(1.9, 2.5)
		piece(Vector3.new(0.12, h, 0.12), Vector3.new(0, h / 2, 0), STEM)
		piece(Vector3.new(0.7, 0.06, 0.26), Vector3.new(0.2, h * 0.45, 0), LEAF, nil, CFrame.Angles(0, yaw, 0.3))
		local face = CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, 0.35) -- 해를 보며 살짝 위로
		piece(Vector3.new(0.1, 0.95, 0.95), Vector3.new(0, h, 0), c, Enum.PartType.Cylinder, face)
		piece(Vector3.new(0.14, 0.45, 0.45), Vector3.new(0, h, 0) + face.XVector * 0.04, Color3.fromRGB(110, 70, 30), Enum.PartType.Cylinder, face)
	elseif shape == "tree" then
		-- 🌸 작은 벚나무 (줄기 + 분홍 구름 + 바닥에 떨어진 꽃잎)
		local h = rng:NextNumber(1.8, 2.2)
		piece(Vector3.new(0.35, h, 0.35), Vector3.new(0, h / 2, 0), Color3.fromRGB(110, 75, 55))
		piece(Vector3.new(0.18, 0.9, 0.18), Vector3.new(0.3, h * 0.8, 0), Color3.fromRGB(110, 75, 55), nil, CFrame.Angles(0, yaw, -0.6))
		for k, info in { { 0, 0.25, 0, 1.9 }, { 0.6, 0, 0.3, 1.3 }, { -0.6, 0.05, -0.2, 1.35 }, { 0.1, 0.6, -0.4, 1.1 } } do
			local blossom = piece(Vector3.new(info[4], info[4], info[4]), Vector3.new(info[1], h + info[2], info[3]), if k % 2 == 0 then flower.colors[2] or c else c, Enum.PartType.Ball)
			blossom.Material = Enum.Material.Fabric
		end
		piece(Vector3.new(0.05, 2.2, 2.2), Vector3.new(0, 0.03, 0), flower.colors[2] or c, Enum.PartType.Cylinder, UP)
	elseif shape == "hydrangea" then
		-- 💐 둥근 덤불 + 꽃송이 공 네 개
		local bush = piece(Vector3.new(1.1, 1.1, 1.1), Vector3.new(0, 0.45, 0), Color3.fromRGB(60, 130, 60), Enum.PartType.Ball)
		bush.Material = Enum.Material.Grass
		for k = 1, 4 do
			local angle = yaw + k / 4 * math.pi * 2
			local ball = piece(Vector3.new(0.55, 0.55, 0.55), Vector3.new(math.cos(angle) * 0.32, 0.85 + (k % 2) * 0.12, math.sin(angle) * 0.32), c, Enum.PartType.Ball)
			ball.Material = Enum.Material.Fabric
		end
	elseif shape == "hibiscus" then
		-- 🌺 초록 덤불 + 크고 납작한 꽃 세 송이
		local bush = piece(Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 0.5, 0), Color3.fromRGB(50, 120, 55), Enum.PartType.Ball)
		bush.Material = Enum.Material.Grass
		for k = 1, 3 do
			local angle = yaw + k / 3 * math.pi * 2
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local tilt = CFrame.lookAt(Vector3.zero, out + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, math.pi / 2, 0) -- 원기둥 축이 바깥 위쪽을 봐요
			piece(Vector3.new(0.06, 0.62, 0.62), out * 0.5 + Vector3.new(0, 0.85, 0), c, Enum.PartType.Cylinder, tilt.Rotation)
			piece(Vector3.new(0.14, 0.14, 0.14), out * 0.56 + Vector3.new(0, 0.9, 0), Color3.fromRGB(255, 230, 90), Enum.PartType.Ball)
		end
	elseif shape == "pompom" then
		local h = rng:NextNumber(0.55, 0.8)
		piece(Vector3.new(0.08, h, 0.08), Vector3.new(0, h / 2, 0), STEM)
		piece(Vector3.new(0.45, 0.06, 0.18), Vector3.new(0.1, h * 0.4, 0), LEAF, nil, CFrame.Angles(0, yaw, 0.4))
		local pom = piece(Vector3.new(0.5, 0.5, 0.5), Vector3.new(0, h + 0.1, 0), c, Enum.PartType.Ball)
		pom.Material = Enum.Material.Fabric
	elseif shape == "mist" then
		-- 💮 연두 덤불 위에 하얀 점점이
		local bush = piece(Vector3.new(0.9, 0.9, 0.9), Vector3.new(0, 0.35, 0), Color3.fromRGB(120, 170, 100), Enum.PartType.Ball)
		bush.Material = Enum.Material.Grass
		for k = 1, 6 do
			local angle = yaw + k / 6 * math.pi * 2
			local radius = if k % 2 == 0 then 0.35 else 0.18
			local dot = piece(Vector3.new(0.22, 0.22, 0.22), Vector3.new(math.cos(angle) * radius, 0.78 + (k % 3) * 0.06, math.sin(angle) * radius), c, Enum.PartType.Ball)
			dot.Material = Enum.Material.Neon
		end
	else
		-- 💜 spike: 라벤더 꽃대 세 줄기
		for k = 1, 3 do
			local angle = yaw + k / 3 * math.pi * 2
			local spot = Vector3.new(math.cos(angle) * 0.16, 0, math.sin(angle) * 0.16)
			local h = rng:NextNumber(0.6, 0.9)
			piece(Vector3.new(0.05, h, 0.05), spot + Vector3.new(0, h / 2, 0), STEM)
			piece(Vector3.new(0.15, 0.5, 0.15), spot + Vector3.new(0, h + 0.2, 0), c)
		end
	end
end

-- 화단 위 꽃 자리 (cols × rows 격자 + 살짝 흔들기)
local function bedSpots(sx: number, sz: number, flower, rng: Random): { Vector3 }
	local shape = flower.shape
	local cols, rows = 5, 3
	if shape == "tree" then
		cols, rows = 2, 1
	elseif shape == "hydrangea" or shape == "hibiscus" or shape == "mist" then
		cols, rows = 4, 2
	elseif shape == "sunflower" or shape == "spike" then
		cols, rows = 5, 2
	end
	local spots = {}
	local w, d = sx - 1.2, sz - 1.2
	for row = 1, rows do
		for col = 1, cols do
			local x = if cols == 1 then 0 else -w / 2 + (col - 1) * w / (cols - 1)
			local z = if rows == 1 then 0 else -d / 2 + (row - 1) * d / (rows - 1)
			local jitter = if shape == "tree" then 0 else 0.18
			table.insert(spots, Vector3.new(x + rng:NextNumber(-jitter, jitter), 0, z + rng:NextNumber(-jitter, jitter)))
		end
	end
	return spots
end

local parkFolder = Instance.new("Folder")
parkFolder.Name = "MyParkGarden"
parkFolder.Parent = workspace
local function renderPark()
	parkFolder:ClearAllChildren()
	local ok, spots = pcall(function()
		return HttpService:JSONDecode(ReplicatedStorage:GetAttribute("ParkBeds") or "[]")
	end)
	if not ok or typeof(spots) ~= "table" then
		return
	end
	local beds, today = readPark()
	for i, spot in spots do
		local bed = beds[i]
		local flower = bed and SalaryConfig.getFlower(bed.flower)
		local top = Vector3.new(spot[1], spot[2], spot[3])
		local sx, sz = spot[4] or 6.8, spot[5] or 3.8
		local model = Instance.new("Model")
		model.Name = `ParkBed{i}`
		model.Parent = parkFolder
		local origin = top
		local function piece(size: Vector3, offset: Vector3, color: Color3, shape: Enum.PartType?, rotation: CFrame?)
			local p = Instance.new("Part")
			p.Shape = shape or Enum.PartType.Block
			p.Size = size
			p.Color = color
			p.Material = Enum.Material.SmoothPlastic
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.CFrame = CFrame.new(origin + offset) * (rotation or CFrame.identity)
			p.Parent = model
			return p
		end
		local mark: string? = nil
		if not flower then
			mark = `➕ 빈 화단 {i}`
		else
			local rng = Random.new(i * 97 + #bed.flower) -- 매번 같은 모양으로 (다시 그려도 안 흔들려요)
			local colors = flower.colors
			if (bed.growth or 0) >= flower.days then
				-- 🌸 활짝! 화단 가득
				for k, at in bedSpots(sx, sz, flower, rng) do
					origin = top + at
					drawFlower(piece, flower, colors[(k - 1) % #colors + 1], rng)
				end
				origin = top
			else
				local r = (bed.growth or 0) / flower.days
				for k, at in bedSpots(sx, sz, { shape = if flower.shape == "tree" then "hydrangea" else "spike" }, rng) do
					origin = top + at
					if (bed.growth or 0) == 0 then
						-- 🌱 새싹
						piece(Vector3.new(0.06, 0.3, 0.06), Vector3.new(0, 0.15, 0), LEAF)
						piece(Vector3.new(0.28, 0.05, 0.14), Vector3.new(0, 0.3, 0), LEAF, nil, CFrame.Angles(0, rng:NextNumber(0, math.pi), 0))
					else
						-- 🌿 쑥쑥 → 꽃봉오리 (꽃 색이 살짝 비쳐요)
						local h = 0.35 + r * 0.8
						piece(Vector3.new(0.08, h, 0.08), Vector3.new(0, h / 2, 0), STEM)
						piece(Vector3.new(0.34, 0.05, 0.14), Vector3.new(0, h * 0.5, 0), LEAF, nil, CFrame.Angles(0, rng:NextNumber(0, math.pi), 0))
						if r >= 0.5 then
							piece(Vector3.new(0.22, 0.22, 0.22), Vector3.new(0, h + 0.06, 0), colors[(k - 1) % #colors + 1]:Lerp(LEAF, 0.45), Enum.PartType.Ball)
						end
					end
				end
				origin = top
				local needWater, needFeed = bedTodo(bed, flower, today)
				mark = `{flower.emoji} {bed.growth or 0}/{flower.days}` .. (if needWater then " 💧?" else "") .. (if needFeed then " 🧪?" else "")
			end
		end
		if mark then
			local holder = piece(Vector3.new(0.2, 0.2, 0.2), Vector3.new(0, 2.6, 0), Color3.new(1, 1, 1))
			holder.Transparency = 1
			local board = Instance.new("BillboardGui")
			board.Size = UDim2.fromOffset(110, 24)
			board.MaxDistance = 35
			board.Parent = holder
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.Text = mark
			text.TextScaled = true
			text.Font = Enum.Font.GothamBold
			text.TextColor3 = Color3.new(1, 1, 1)
			text.TextStrokeTransparency = 0.3
			text.Parent = board
		end
	end
end
player:GetAttributeChangedSignal("ParkGarden"):Connect(renderPark)
player:GetAttributeChangedSignal("GardenToday"):Connect(renderPark)
ReplicatedStorage:GetAttributeChangedSignal("ParkBeds"):Connect(renderPark)
task.defer(renderPark)

function Panels.showParkBed(index: number, station: any)
	local frame = sheet(420, 540)
	closeWhenAway(frame, station, 12) -- 🚪 화단에서 12칸 넘게 멀어지면 닫혀요 (서버는 13칸까지 받아요)
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.Position = UDim2.new(1, -20, 0.5, 0)
	line(frame, 0, 28, `🌷 내 공원 화단 {index}`, { Font = Enum.Font.GothamBlack, TextSize = 22 })
	line(frame, 32, 20, "💧 매일 물 · 🧪 봉오리 땐 거름 · 활짝 피면 매일 수당", { TextSize = 13, TextColor3 = MUTED })
	helpButton(frame, UDim2.new(1, -70, 0, 0), "공원 화단 규칙", `🏪 사내 매점 <b>[🌱 씨앗] → [🌷 꽃씨·거름]</b>에서 꽃씨·🧪 거름을 사요\n🌷 화단 하나에 꽃 한 종류를 가득 피워요\n💧 매일 물을 주고 퇴근하면 한 단계 자라요 (🌿 꽃봉오리 땐 🧪 거름도 줘야 해요)\n😌 안 줘도 죽지 않고, 활짝 피면 영원히 안 시들어요\n💰 활짝 핀 화단마다 퇴근할 때 +{SalaryConfig.PARK_BED_BONUS}원\n🌈 {SalaryConfig.PARK_BEDS}곳 모두 활짝 + 꽃 {SalaryConfig.PARK_FULL_KINDS}종 이상이면 +{SalaryConfig.PARK_FULL_BONUS}원 더 (오늘 핀 꽃도 바로 쳐 줘요)`)
	local message = line(frame, 0, 24, "", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local busy = false
	local content: { Instance } = {}
	local picker: Frame? = nil
	local W = 380

	local function act(action: string, flowerId: string?)
		if busy then
			return
		end
		busy = true
		local result = Remotes.ParkAction:InvokeServer(action, index, flowerId)
		busy = false
		if current ~= frame then
			return
		end
		message.Text = result.message
		message.TextColor3 = if result.ok then Color3.fromRGB(40, 140, 70) else RED
		Sounds.play(if result.ok then "ping" else "bass", 0.4, if action == "water" then 1.4 else 1.1)
	end

	-- 🌷 꽃씨 고르기: 🎒에 있는 꽃씨는 [심기], 없는 건 "🏪 매점에서"
	local function closePicker()
		if picker then
			picker:Destroy()
			picker = nil
		end
	end
	local function openPicker()
		closePicker()
		local box = Ui.make("Frame", {
			Position = UDim2.fromOffset(0, 68),
			Size = UDim2.fromOffset(W, 390),
			BackgroundColor3 = Color3.fromRGB(252, 244, 248),
			ZIndex = 40,
			Parent = frame,
		}, { Ui.corner(10), Ui.padding(8), Ui.stroke(Color3.fromRGB(220, 130, 170), 2) })
		picker = box
		line(box, 0, 22, `🌷 {index}번 화단에 뭘 심을까요?`, { Font = Enum.Font.GothamBlack, TextSize = 16, ZIndex = 41 })
		local cancel = Ui.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(64, 22),
			Text = "◀ 취소",
			TextSize = 12,
			BackgroundColor3 = Color3.fromRGB(215, 215, 215),
			ZIndex = 41,
			Parent = box,
		})
		cancel.Activated:Connect(closePicker)
		local list = Ui.make("ScrollingFrame", {
			Position = UDim2.fromOffset(0, 28),
			Size = UDim2.new(1, 0, 1, -28),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 5,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ZIndex = 41,
			Parent = box,
		}, { Ui.make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
		local seeds = readFlowerSeeds()
		local sorted = table.clone(SalaryConfig.ParkFlowers)
		table.sort(sorted, function(a, b)
			local ha, hb = (seeds[a.id] or 0) > 0, (seeds[b.id] or 0) > 0
			if ha ~= hb then
				return ha
			end
			return (table.find(SalaryConfig.ParkFlowers, a) or 0) < (table.find(SalaryConfig.ParkFlowers, b) or 0)
		end)
		for k, flower in sorted do
			local n = seeds[flower.id] or 0
			local row = Ui.make("Frame", {
				Size = UDim2.new(1, -8, 0, 44),
				BackgroundColor3 = if n > 0 then Color3.fromRGB(250, 228, 238) else Color3.fromRGB(232, 232, 232),
				LayoutOrder = k,
				ZIndex = 42,
				Parent = list,
			}, { Ui.corner(6), Ui.padding(4) })
			line(row, 0, 18, `{flower.emoji} {flower.name}` .. (if n > 0 then ` 🎒x{n}` else ""), { Font = Enum.Font.GothamBold, TextSize = 14, ZIndex = 43, TextColor3 = if n > 0 then INK else MUTED, Size = UDim2.new(1, -84, 0, 18) })
			line(row, 18, 18, `{SalaryConfig.flowerCareText(flower)} · {flower.description}`, { TextSize = 11, ZIndex = 43, TextColor3 = MUTED, Size = UDim2.new(1, -84, 0, 18), TextScaled = true })
			local b = Ui.button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(80, 30),
				Text = if n > 0 then "🌷 심기" else "🏪 매점에서",
				TextSize = 12,
				BackgroundColor3 = if n > 0 then Color3.fromRGB(240, 160, 190) else Color3.fromRGB(210, 210, 210),
				AutoButtonColor = n > 0,
				ZIndex = 43,
				Parent = row,
			})
			b.Activated:Connect(function()
				if n <= 0 then
					message.Text = `🏪 매점에서 {flower.emoji} 꽃씨를 사 와요`
					message.TextColor3 = MUTED
					return
				end
				closePicker()
				act("plant", flower.id)
			end)
		end
	end

	local function rebuild()
		for _, item in content do
			item:Destroy()
		end
		table.clear(content)
		local beds, today = readPark()
		local bed = beds[index]
		local flower = SalaryConfig.getFlower(bed.flower)
		local state = SalaryConfig.parkBedState(bed)
		local fertilizer = player:GetAttribute("Fertilizer") or 0

		-- 🪴 이 화단 카드
		local card = Ui.make("Frame", {
			Position = UDim2.fromOffset(0, 68),
			Size = UDim2.fromOffset(W, 196),
			BackgroundColor3 = if state == "bloomed" then Color3.fromRGB(252, 236, 244) else Color3.fromRGB(240, 238, 232),
			ZIndex = 31,
			Parent = frame,
		}, { Ui.corner(10), Ui.padding(10) })
		table.insert(content, card)
		local function label(x: number, y: number, w: number, h: number, text: string, size: number, color: Color3?, align: Enum.TextXAlignment?)
			return Ui.make("TextLabel", {
				Position = UDim2.fromOffset(x, y),
				Size = UDim2.fromOffset(w, h),
				BackgroundTransparency = 1,
				Text = text,
				TextSize = size,
				TextWrapped = true,
				Font = Enum.Font.GothamBold,
				TextColor3 = color or INK,
				TextXAlignment = align or Enum.TextXAlignment.Left,
				ZIndex = 32,
				Parent = card,
			})
		end
		local function smallButton(x: number, y: number, w: number, h: number, text: string, color: Color3, onClick: () -> ())
			local b = Ui.button({
				Position = UDim2.fromOffset(x, y),
				Size = UDim2.fromOffset(w, h),
				Text = text,
				TextSize = 13,
				TextWrapped = true,
				BackgroundColor3 = color,
				ZIndex = 33,
				Parent = card,
			})
			b.Activated:Connect(onClick)
			return b
		end
		local CW = W - 20
		if not flower then
			label(0, 0, CW, 40, "➕", 30, nil, Enum.TextXAlignment.Center)
			label(0, 42, CW, 20, "빈 화단이에요", 13, MUTED, Enum.TextXAlignment.Center)
			smallButton(0, 74, CW, 44, "🌷 꽃씨 심기", Color3.fromRGB(240, 170, 200), openPicker)
			local kinds = 0
			for _, n in readFlowerSeeds() do
				if n > 0 then
					kinds += 1
				end
			end
			if kinds > 0 then
				label(0, 128, CW, 24, `🎒 꽃씨 {kinds}종`, 12, MUTED, Enum.TextXAlignment.Center)
			end
		else
			local bloomed = state == "bloomed"
			local stageEmoji = if bloomed then flower.emoji elseif bed.growth == 0 then "🌱" else "🌿"
			label(0, 0, 44, 40, stageEmoji, 30, nil, Enum.TextXAlignment.Center)
			label(50, 0, CW - 50, 22, `{flower.emoji} {flower.name}`, 16)
			label(50, 22, CW - 50, 18, if bloomed then "🌸 활짝 폈어요!" elseif SalaryConfig.parkNeedsFeed(flower, bed.growth) then `🌿 꽃봉오리 ({bed.growth}/{flower.days}일)` else `🌱 자라는 중 ({bed.growth}/{flower.days}일)`, 12, MUTED)
			-- 자란 정도 막대
			local back = Ui.make("Frame", { Position = UDim2.fromOffset(0, 46), Size = UDim2.fromOffset(CW, 8), BackgroundColor3 = Color3.fromRGB(215, 215, 210), ZIndex = 32, Parent = card }, { Ui.corner(4) })
			Ui.make("Frame", { Size = UDim2.fromScale(math.clamp(bed.growth / flower.days, 0, 1), 1), BackgroundColor3 = Color3.fromRGB(240, 130, 170), ZIndex = 33, Parent = back }, { Ui.corner(4) })
			if bloomed then
				label(0, 62, CW, 40, `💰 퇴근할 때마다 +{SalaryConfig.PARK_BED_BONUS}원`, 13, Color3.fromRGB(40, 140, 70))
			else
				local needWater, needFeed = bedTodo(bed, flower, today)
				local feedNow = SalaryConfig.parkNeedsFeed(flower, bed.growth)
				local waterText = if needWater then "💧 물 ❌" else "💧 물 ✅"
				local feedText = if not feedNow then (if flower.feeds > 0 then "🧪 거름 아직" else "🧪 거름 X") elseif needFeed then "🧪 거름 ❌" else "🧪 거름 ✅"
				label(0, 60, CW, 18, `📋 오늘 할 일: {waterText} · {feedText}`, 12)
				local waterButton = smallButton(0, 82, (CW - 8) / 2, 38, if needWater then "💧 물 주기" else "✅ 오늘 물 줌", if needWater then Color3.fromRGB(150, 205, 255) else Color3.fromRGB(215, 215, 215), function()
					act("water")
				end)
				waterButton.AutoButtonColor = needWater
				local feedButton = smallButton((CW - 8) / 2 + 8, 82, (CW - 8) / 2, 38, if needFeed then `🧪 거름 주기 (🎒{fertilizer})` elseif feedNow then "✅ 거름 줌" else "🧪 아직이에요", if needFeed then Color3.fromRGB(200, 230, 170) else Color3.fromRGB(215, 215, 215), function()
					act("feed")
				end)
				feedButton.AutoButtonColor = needFeed
				label(0, 124, CW, 18, if not needWater and not needFeed then "😊 오늘 끝! 퇴근하면 자라요" else "다 주면 퇴근할 때 자라요", 11, MUTED)
			end
			-- 🧹 뽑기 (두 번 눌러야 뽑혀요)
			local armed = false
			local clearButton
			clearButton = smallButton(0, 148, CW, 28, "🧹 뽑고 다른 꽃 심기", Color3.fromRGB(230, 225, 215), function()
				if armed then
					act("clear")
				else
					armed = true
					clearButton.Text = "정말 뽑을까요? 꽃이 사라져요 (한 번 더)"
					clearButton.BackgroundColor3 = Color3.fromRGB(255, 190, 170)
				end
			end)
		end

		-- 🏞️ 내 공원 한눈에 (화단 6곳)
		table.insert(content, line(frame, 272, 20, "🏞️ 내 공원 한눈에", { Font = Enum.Font.GothamBlack, TextSize = 15 }))
		local TILE_W = (W - 12) / 3
		for i = 1, SalaryConfig.PARK_BEDS do
			local b = beds[i]
			local f = SalaryConfig.getFlower(b.flower)
			local s = SalaryConfig.parkBedState(b)
			local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
			local needWater, needFeed = bedTodo(b, f, today)
			local text = if not f then `{i}. ➕ 비었어요` elseif s == "bloomed" then `{i}. {f.emoji} 활짝!` else `{i}. {f.emoji} {b.growth}/{f.days}` .. (if needWater then " 💧" else "") .. (if needFeed then " 🧪" else "")
			local tile = Ui.make("TextLabel", {
				Position = UDim2.fromOffset(col * (TILE_W + 6), 296 + row * 40),
				Size = UDim2.fromOffset(TILE_W, 34),
				BackgroundColor3 = if s == "bloomed" then Color3.fromRGB(250, 220, 235) elseif f then Color3.fromRGB(225, 240, 215) else Color3.fromRGB(232, 232, 232),
				Text = text,
				TextSize = 13,
				TextScaled = false,
				TextWrapped = true,
				Font = Enum.Font.GothamBold,
				TextColor3 = if f then INK else MUTED,
				ZIndex = 31,
				Parent = frame,
			}, { Ui.corner(6), if i == index then Ui.stroke(Color3.fromRGB(220, 90, 140), 2) else nil })
			table.insert(content, tile)
		end
		-- 💰 오늘 정원 수당 미리보기 + 규칙
		local pay, bloomedBeds, kinds, full = SalaryConfig.parkBonus(beds)
		local onNunchi = ReplicatedStorage:GetAttribute("SalaryCompany") == "nunchi"
		local bonusText = `💰 정원 수당: 활짝 {bloomedBeds}곳 x {SalaryConfig.PARK_BED_BONUS}원`
			.. (if full then ` + 🌈 {SalaryConfig.PARK_FULL_BONUS}원` else "")
			.. ` = {comma(pay)}원`
		table.insert(content, line(frame, 380, 20, bonusText, { TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = if onNunchi then Color3.fromRGB(40, 140, 70) else MUTED }))
		table.insert(content, line(frame, 404, 18, `🌈 정원 완성: {SalaryConfig.PARK_BEDS}곳 활짝 + 꽃 {SalaryConfig.PARK_FULL_KINDS}종 (지금 {kinds}종) → +{SalaryConfig.PARK_FULL_BONUS}원`, { TextSize = 12, TextColor3 = MUTED }))
		table.insert(content, line(frame, 426, 18, `🎒 🧪 거름 {fertilizer}개`, { TextSize = 12, TextColor3 = MUTED }))
	end
	rebuild()
	local function refresh()
		if current == frame then
			rebuild()
		end
	end
	local connections = {
		player:GetAttributeChangedSignal("ParkGarden"):Connect(refresh),
		player:GetAttributeChangedSignal("GardenToday"):Connect(refresh),
		player:GetAttributeChangedSignal("FlowerSeeds"):Connect(refresh),
		player:GetAttributeChangedSignal("Fertilizer"):Connect(refresh),
	}
	frame.Destroying:Connect(function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end)
	Sounds.play("swoosh", 0.4)
end
Remotes:WaitForChild("ParkOpen").OnClientEvent:Connect(function(index, station)
	if typeof(index) == "number" then
		Panels.showParkBed(index, station)
	end
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

local scopeStation: Vector3? = nil -- 🔭 망원경 자리 (서버가 열 때 알려 줘요 · 멀어지면 창을 닫는 기준)
function Panels.showScopeLog(fromScope: boolean?)
	local frame = sheet(600, 520)
	if fromScope then
		closeWhenAway(frame, scopeStation, 11) -- 🚪 망원경에서 열었을 때만: 멀어지면 닫혀요
		-- 🔭 망원경에서 열었으면 바로 다시 볼 수 있게
		button(frame, 0, "🔭 다시 엿보기", function()
			Panels.showScope()
		end)
	end
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

local scopeSavedSpeed: number? = nil -- 🔭 엿보기 전 걸음 속도 (여러 번 열어도 처음 값만 기억)
function Panels.showScope(station: any)
	if typeof(station) == "Vector3" then
		scopeStation = station
	end
	if current and current:GetAttribute("Scope") then
		return -- 이미 엿보는 중 ([E]를 또 눌러도 무시)
	end
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
	-- (작은 화면에서도 보이게 화면 아래쪽에 붙여요)
	local logButton = Ui.button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, -6, 1, -40), Size = UDim2.fromOffset(170, 46), Text = "📒 관찰 일지", TextSize = 17, ZIndex = 45, Parent = overlay })
	local quitButton = Ui.button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 6, 1, -40), Size = UDim2.fromOffset(170, 46), Text = "🔭 그만 보기 (Esc)", TextSize = 17, ZIndex = 45, Parent = overlay })
	-- ✕ 닫기 (오른쪽 위, 다른 창들과 같은 자리)
	local closeX = Ui.make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 20),
		Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = Color3.fromRGB(225, 225, 230),
		Text = "X",
		Font = Enum.Font.GothamBlack,
		TextSize = 24,
		TextColor3 = INK,
		ZIndex = 45,
		Parent = overlay,
	}, { Ui.corner(26) })
	closeX.Activated:Connect(close)
	logButton.Activated:Connect(function()
		Panels.showScopeLog(true)
	end)
	quitButton.Activated:Connect(close)

	-- 보는 동안 캐릭터는 제자리 (WASD는 렌즈를 움직여요)
	overlay:SetAttribute("Scope", true)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and scopeSavedSpeed == nil then
		scopeSavedSpeed = if humanoid.WalkSpeed > 0 then humanoid.WalkSpeed else 16
	end
	if humanoid then
		humanoid.WalkSpeed = 0
	end

	-- 둘러보기: pan = 렌즈 가운데가 보는 빌딩 위 좌표
	local pan = Vector2.new(FACADE_W / 2, FACADE_H / 2)
	local dragging = false
	local held: { [Enum.KeyCode]: boolean } = {}
	local connections = {}
	-- ⎋ Esc로도 그만 보기
	table.insert(connections, UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape and current == overlay then
			close()
		end
	end))
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
		if humanoid and humanoid.Parent and not (current and current:GetAttribute("Scope")) then
			humanoid.WalkSpeed = scopeSavedSpeed or 16
			scopeSavedSpeed = nil
		elseif not (humanoid and humanoid.Parent) then
			scopeSavedSpeed = nil -- (쓰러져서 캐릭터가 바뀌었으면 새 캐릭터 속도를 다음에 다시 기억해요)
		end
	end)
	-- 🚪 망원경에서 멀어지거나(엘리베이터 등) 쓰러지면 닫혀요 → 위 반복이 끝나면서 걸음 속도도 되돌려요
	closeWhenAway(overlay, scopeStation, 11)
	Sounds.play("swoosh", 0.5, 0.8)
end
Remotes:WaitForChild("ScopeOpen").OnClientEvent:Connect(function(station)
	Panels.showScope(station)
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

function Panels.showHoop(station: any)
	local frame = sheet(340, 380)
	closeWhenAway(frame, station, 12.5) -- 🚪 자유투 라인에서 12.5칸 넘게 멀어지면 닫혀요 (서버는 13칸까지 받아요 · 공 거치대 [E] 거리 포함)
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.Position = UDim2.new(1, -20, 0.5, 0)
	line(frame, 0, 30, "🏀 옥상 농구", { Font = Enum.Font.GothamBlack, TextSize = 24 })
	line(frame, 32, 20, "🎯 초록 +3 · 🟡 노랑 +2 · 🔥 연속 +1 · 🔊 공 소리 조심!", { TextSize = 12, TextColor3 = MUTED })
	local ballsText = line(frame, 58, 30, "", { TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center })
	local scoreText = line(frame, 92, 26, "", { TextSize = 18, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center })
	-- 슛 게이지
	local back = Ui.make("Frame", { Position = UDim2.fromOffset(0, 130), Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Color3.fromRGB(215, 218, 226), ZIndex = 31, Parent = frame }, { Ui.corner(6) })
	-- 💪 근력: 칸이 넓어져요 (최대 +20% · 판정은 서버가 같은 식으로)
	local hoopWiden = SalaryConfig.playerFitnessEffect(player, "hoop")
	local function zone(half: number, color: Color3, z: number)
		half *= 1 + hoopWiden
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
	local frozen = false -- 슛을 누른 순간 게이지를 그 자리에 멈춰요 (서버 답을 기다리지 않게)
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
		local okCall, r = pcall(function()
			return Remotes.HoopPlay:InvokeServer("start")
		end)
		r = if okCall and typeof(r) == "table" then r else { ok = false, message = "잠시 후 다시 해 주세요." }
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
		-- ⚡ 누른 순간 바로 멈추고 결과를 미리 보여 줘요 (판정은 서버가 같은 시각으로 다시 계산)
		frozen = true
		local predicted = SalaryConfig.hoopGauge(press - gaugeStart, shot + 1)
		marker.Position = UDim2.fromScale(predicted, 0.5)
		local guess = SalaryConfig.hoopResult(predicted, hoopWiden)
		result.Text = HOOP_TEXT[guess]
		result.TextColor3 = if guess == "swish" or guess == "make" then Color3.fromRGB(40, 140, 70) else RED
		Sounds.play("swoosh", 0.4, 1.3)
		local okCall, r = pcall(function()
			return Remotes.HoopPlay:InvokeServer("shoot", press)
		end)
		r = if okCall and typeof(r) == "table" then r else { ok = false, message = "잠시 후 다시 해 주세요." }
		busy = false
		frozen = false
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
				if current ~= frame or playing then
					return -- (그사이 새 판을 시작했으면 덮어쓰지 않아요)
				end
				local prizeText = if r.prize > 0 then `\n+{comma(r.prize)}원 (오늘 상금 {r.prizesLeft}번 더)` elseif score >= SalaryConfig.HoopPrizes[#SalaryConfig.HoopPrizes].score then "\n(오늘 상금은 다 받았어요)" else ""
				result.Text = `{r.label}\n최종 {score}점{prizeText}`
				result.TextColor3 = if r.prize > 0 then Color3.fromRGB(40, 140, 70) else INK
				mainButton.Text = "🏀 한 판 더 (Enter)"
			end)
		end
	end
	-- 버튼을 "뗄 때"가 아니라 "누르는 순간" 쏴요 (Activated는 손을 뗄 때라 늦어요)
	mainButton.MouseButton1Down:Connect(shoot)
	local keyConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and current == frame and (input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter) then
			shoot()
		end
	end)
	task.spawn(function()
		while current == frame do
			if playing and not frozen then
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
Remotes:WaitForChild("HoopOpen").OnClientEvent:Connect(function(station)
	Panels.showHoop(station)
end)

---------------------------------------------------------------------------
-- 👔 출근룩 쇼핑 (툴바 👔): 왼쪽 = 칸, 오른쪽 = 그 칸의 옷들
---------------------------------------------------------------------------
function Panels.showOutfit(slotIndex: number?)
	local frame = sheet(680, 480)
	local selected = slotIndex or 1
	line(frame, 0, 30, "👔 출근룩 쇼핑", { Font = Enum.Font.GothamBlack, TextSize = 24 })
	local info = line(frame, 32, 20, "", { TextSize = 13, TextColor3 = MUTED })
	local message = line(frame, 0, 22, "", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local tabs = {}
	local grid = Ui.make("Frame", { Position = UDim2.fromOffset(140, 60), Size = UDim2.new(1, -140, 1, -90), BackgroundTransparency = 1, ZIndex = 31, Parent = frame })
	local busy = false

	local function decode(attribute: string): { [string]: any }
		local ok, value = pcall(function()
			return HttpService:JSONDecode(player:GetAttribute(attribute) or "{}")
		end)
		return if ok and typeof(value) == "table" then value else {}
	end

	local render: () -> ()
	local function act(action: string, value: string)
		if busy then
			return
		end
		busy = true
		local result = Remotes.OutfitAction:InvokeServer(action, value)
		busy = false
		if current ~= frame then
			return
		end
		message.Text = result.message
		message.TextColor3 = if result.ok then Color3.fromRGB(40, 140, 70) else RED
		Sounds.play(if result.ok then "ping" else "bass", 0.4, 1.2)
		task.wait(0.15) -- (속성이 바뀔 때까지 잠깐)
		if current == frame then
			render()
		end
	end

	render = function()
		local owned = decode("OutfitOwned")
		local equipped = decode("OutfitEquipped")
		local total = 0
		for _, itemId in equipped do
			local option = SalaryConfig.getOutfit(itemId)
			total += if option then option.price else 0
		end
		info.Text = `💰 통장 {comma(player:GetAttribute("TotalMoney") or 0)}원 · 지금 입은 옷값 {comma(total)}원`
			.. (if total >= SalaryConfig.OUTFIT_LUXURY then " · 💸 명품 출근룩 (부장님 눈치 +0.05)" else "")
		for i, tab in tabs do
			tab.BackgroundColor3 = if i == selected then Color3.fromRGB(255, 210, 100) else Color3.fromRGB(225, 225, 230)
		end
		grid:ClearAllChildren()
		local slot = SalaryConfig.OutfitSlots[selected]
		for k, option in slot.options do
			local col, row = (k - 1) % 3, math.floor((k - 1) / 3)
			local isOwned = owned[option.id] == true
			local isOn = equipped[slot.id] == option.id
			local card = Ui.make("Frame", {
				Position = UDim2.fromOffset(col * 164, row * 190),
				Size = UDim2.fromOffset(156, 180),
				BackgroundColor3 = if isOn then Color3.fromRGB(230, 245, 225) elseif option.price >= 80000 then Color3.fromRGB(255, 245, 215) else Color3.fromRGB(242, 240, 236),
				ZIndex = 32,
				Parent = grid,
			}, { Ui.corner(10), Ui.padding(8) })
			local function text(y: number, h: number, value: string, size: number, color: Color3?)
				Ui.make("TextLabel", { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, Text = value, TextSize = size, TextWrapped = true, Font = Enum.Font.GothamBold, TextColor3 = color or INK, ZIndex = 33, Parent = card })
			end
			text(0, 40, option.emoji, 32)
			text(42, 20, option.name, 15)
			text(64, 18, `{comma(option.price)}원`, 14, if option.price >= 80000 then Color3.fromRGB(190, 130, 20) else MUTED)
			text(84, 40, option.description, 11, MUTED)
			local b = Ui.button({
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, 0),
				Size = UDim2.new(1, 0, 0, 34),
				Text = if isOn then "✅ 입는 중 (벗기)" elseif isOwned then "👕 입기" else `🛍️ 사기`,
				TextSize = 14,
				BackgroundColor3 = if isOn then Color3.fromRGB(200, 230, 200) elseif isOwned then Color3.fromRGB(190, 215, 255) else Color3.fromRGB(255, 205, 100),
				ZIndex = 33,
				Parent = card,
			})
			b.Activated:Connect(function()
				if isOn then
					act("unequip", slot.id)
				elseif isOwned then
					act("equip", option.id)
				else
					act("buy", option.id)
				end
			end)
		end
	end

	for i, slot in SalaryConfig.OutfitSlots do
		local tab = Ui.button({
			Position = UDim2.fromOffset(0, 60 + (i - 1) * 50),
			Size = UDim2.fromOffset(128, 44),
			Text = `{slot.emoji} {slot.name}`,
			TextSize = 15,
			ZIndex = 31,
			Parent = frame,
		})
		tab.Activated:Connect(function()
			selected = i
			Sounds.play("click", 0.3)
			render()
		end)
		tabs[i] = tab
	end
	render()
	Sounds.play("swoosh", 0.4)
end

-- 🔔 인기척 센서: 부장님이 가까이 오면 📳 화면이 부르르
Remotes:WaitForChild("SensorAlert").OnClientEvent:Connect(function(distance: number)
	Sounds.play("click", 0.7, 0.5)
	Hud.popup(`📳 인기척! 부장님이 {distance}칸 거리에…`, Color3.fromRGB(255, 160, 80), 2)
	local camera = workspace.CurrentCamera
	if camera then
		task.spawn(function()
			for i = 1, 8 do
				local shake = (if i % 2 == 0 then 1 else -1) * 0.25
				camera.CFrame *= CFrame.new(shake, 0, 0)
				task.wait(0.03)
			end
		end)
	end
end)

---------------------------------------------------------------------------
-- 📚 자격증 시험 창
---------------------------------------------------------------------------
function Panels.showExam(certId: string)
	local cert = SalaryConfig.getCertificate(certId)
	if not cert then
		return
	end
	local start = Remotes.CertExam:InvokeServer("start", certId)
	if not start.ok then
		Ui.toast(start.message)
		Sounds.play("bass", 0.4, 1.2)
		return
	end
	local frame = sheet(560, 470)
	line(frame, 0, 30, `📝 {cert.emoji} {cert.name} 시험`, { Font = Enum.Font.GothamBlack, TextSize = 24 })
	local progress = line(frame, 32, 20, "", { TextSize = 14, TextColor3 = MUTED })
	local question = line(frame, 62, 150, "", { TextSize = 20, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
	local status = line(frame, 0, 26, "", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -54),
		TextSize = 15,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local choiceButtons: { TextButton } = {}
	local current_q: any = start.question
	local busy = false
	local finished = false

	local function show(q)
		current_q = q
		progress.Text = `문제 {q.number}/{q.total} · 맞힌 개수 {q.right} · {SalaryConfig.CERT_PASS}개 이상이면 합격`
		question.Text = q.text
		for i, b in choiceButtons do
			b.Text = q.choices[i] or ""
			b.BackgroundColor3 = Ui.COLORS.brass
		end
	end

	for i = 1, 4 do
		local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
		local b = Ui.button({
			Position = UDim2.new(col * 0.5, if col == 0 then 0 else 6, 0, 222 + row * 64),
			Size = UDim2.new(0.5, -6, 0, 56),
			Text = "",
			TextSize = 18,
			ZIndex = 32,
			Parent = frame,
		})
		b.Activated:Connect(function()
			if busy or finished then
				return
			end
			busy = true
			local result = Remotes.CertExam:InvokeServer("answer", i)
			busy = false
			if current ~= frame or not result.ok then
				return
			end
			Sounds.play(if result.correct then "ping" else "bass", 0.5, 1.2)
			status.Text = if result.correct then "⭕ 정답!" elseif result.timeout then `⏰ 시간 초과! 정답: {result.answer}` else `❌ 오답! 정답: {result.answer}`
			status.TextColor3 = if result.correct then Color3.fromRGB(40, 140, 70) else RED
			if result.done then
				finished = true
				for _, other in choiceButtons do
					other.Visible = false
				end
				if result.passed then
					Sounds.play("ping", 0.9, 1.5)
					question.Text = `🎉 합격!! ({result.right}/{SalaryConfig.CERT_QUESTIONS})\n\n🎖️ 승진 경험치 +{comma(result.xp)}\n✨ 특전: {result.perk}`
					question.TextColor3 = Color3.fromRGB(40, 140, 70)
				else
					question.Text = `😢 불합격… ({result.right}/{SalaryConfig.CERT_QUESTIONS})\n\n응시료는 돌려받을 수 없어요.\n내일 다시 도전!`
					question.TextColor3 = RED
				end
				progress.Text = ""
			elseif result.question then
				task.wait(0.6)
				if current == frame then
					status.Text = ""
					show(result.question)
				end
			end
		end)
		choiceButtons[i] = b
	end
	show(start.question)
	button(frame, 0, "닫기", close)
	-- ⏱️ 남은 시간
	task.spawn(function()
		while current == frame and not finished do
			local left = math.max(0, (current_q.deadline or 0) - workspace:GetServerTimeNow())
			if status.Text == "" or string.find(status.Text, "⏱️", 1, true) == 1 then
				status.Text = `⏱️ {math.ceil(left)}초`
				status.TextColor3 = if left < 6 then RED else MUTED
			end
			task.wait(0.2)
		end
	end)
	Sounds.play("swoosh", 0.4)
end

-- 🐦 옥상 비둘기 관찰 노트: 📒 만난 비둘기 + 🎁 비둘기 보물 (목록은 스크롤)
Remotes:WaitForChild("PigeonBook").OnClientEvent:Connect(function(station)
	local function decode(name: string): { [string]: number }
		local ok, value = pcall(function()
			return HttpService:JSONDecode(player:GetAttribute(name) or "{}")
		end)
		return if ok and typeof(value) == "table" then value else {}
	end
	local seen = decode("Pigeons")
	local treasures = decode("PigeonTreasures")
	local feeds = player:GetAttribute("PigeonFeeds") or 0
	local levelIndex, level = SalaryConfig.pigeonLevel(feeds)
	local nextLevel = SalaryConfig.PigeonLevels[levelIndex + 1]
	local found = 0
	for _, kind in SalaryConfig.Pigeons do
		if (seen[kind.id] or 0) > 0 then
			found += 1
		end
	end
	local treasureFound = 0
	for _, treasure in SalaryConfig.PigeonTreasures do
		if (treasures[treasure.id] or 0) > 0 then
			treasureFound += 1
		end
	end
	local frame = sheet(640, 580)
	closeOnOutside(frame)
	line(frame, 0, 34, "📒 비둘기 관찰 노트", { Font = Enum.Font.GothamBlack, TextSize = 26 })
	local chance = math.floor(SalaryConfig.pigeonGiftChance(levelIndex, nil) * 100)
	line(frame, 38, 22, `💕 {level.name} · {feeds}점` .. (if nextLevel then ` (다음까지 {nextLevel.feeds - feeds}점)` else " 🏆") .. (if chance > 0 then ` · 🎁 {chance}%` else ""), { TextSize = 16, TextColor3 = MUTED })
	helpButton(
		frame,
		UDim2.new(1, -70, 0, 2),
		"비둘기 친밀도",
		`🍪 옥상 모이 통 [E]에서 과자를 뿌리면 💕 친밀도가 올라요\n🐦 지금 단계: <b>{level.name}</b> · 한 번에 {level.flock}마리` .. (if nextLevel then ` · 다음 단계까지 {nextLevel.feeds - feeds}점` else " · 최고 단계!") .. "\n" .. (if chance > 0
			then `🎁 과자를 주면 {chance}% 확률로 선물을 물어 와요 (좋은 과자일수록 +) · 하루 {SalaryConfig.PIGEON_GIFT_DAILY}번까지`
			else `🎁 '{SalaryConfig.PigeonLevels[2].name}' 단계부터 선물을 물어 와요`) .. "\n✨ 친해질수록 귀한 비둘기도 와요"
	)
	local list = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 1, -126),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 31,
		Parent = frame,
	}, { Ui.make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local order = 0
	local function row(text: string, props: { [string]: any }?)
		order += 1
		local options: { [string]: any } = { Size = UDim2.new(1, -14, 0, 30), LayoutOrder = order, ZIndex = 32, TextSize = 17, TextTruncate = Enum.TextTruncate.AtEnd }
		for key, value in props or {} do
			options[key] = value
		end
		line(list, 0, 30, text, options)
	end
	row(`🐦 만난 비둘기 ({found}/{#SalaryConfig.Pigeons})`, { Font = Enum.Font.GothamBlack, TextSize = 19 })
	for _, kind in SalaryConfig.Pigeons do
		local count = seen[kind.id] or 0
		if count > 0 then
			row(`{kind.emoji} {kind.name} x{count} — {kind.description}`)
		else
			local hint = if kind.minLevel > levelIndex then ` (💕 {SalaryConfig.PigeonLevels[kind.minLevel].name}부터)` else ""
			row(`❔ ??? 아직 못 만났어요{hint}`, { TextColor3 = MUTED })
		end
	end
	row("", { Size = UDim2.new(1, -14, 0, 8) })
	row(`🎁 비둘기 보물 ({treasureFound}/{#SalaryConfig.PigeonTreasures})`, { Font = Enum.Font.GothamBlack, TextSize = 19 })
	for _, treasure in SalaryConfig.PigeonTreasures do
		local count = treasures[treasure.id] or 0
		local worth = if treasure.kind == "money"
			then `💰 {comma(treasure.min)}~{comma(treasure.max)}원`
			elseif treasure.kind == "tickets" then `🎟️ 티켓 {treasure.min}~{treasure.max}장`
			elseif treasure.kind == "valuable" then `💰 사례금 {comma(treasure.value)}원 (다음부턴 {comma(math.floor(treasure.value * SalaryConfig.PIGEON_TREASURE_RESELL))}원)`
			else "😂 0원 (수집용)"
		if count > 0 then
			row(`{treasure.emoji} {treasure.name} x{count} · {worth}`)
			row(`      {treasure.description}`, { TextSize = 14, TextColor3 = MUTED, Size = UDim2.new(1, -14, 0, 20) })
		else
			row(`❔ ??? · {if treasure.rare then "✨ 아주 드물어요" elseif treasure.kind == "valuable" then "💍 귀중품" elseif treasure.kind == "joke" then "😂 장난 선물" else worth}`, { TextColor3 = MUTED })
		end
	end
	button(frame, 0, "알겠어요", close)
	Sounds.play("swoosh", 0.4)
	closeWhenAway(frame, station, 10) -- 🚪 모이 상자에서 멀어지면 노트가 닫혀요
end)

-- 🍪 모이 통 [E] → 뿌릴 과자 고르기 (🎒에 있는 과자만 [뿌리기])
Remotes:WaitForChild("PigeonSnackOpen").OnClientEvent:Connect(function(station)
	local snacks = SalaryConfig.PigeonSnacks
	local frame = sheet(440, 146 + #snacks * 58)
	line(frame, 0, 30, "🍪 어떤 과자를 뿌릴까요?", { Font = Enum.Font.GothamBlack, TextSize = 22 })
	local message = line(frame, 0, 22, "", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -50),
		TextSize = 15,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local ok, mySnacks = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("PigeonSnacks") or "{}")
	end)
	mySnacks = if ok and typeof(mySnacks) == "table" then mySnacks else {}
	local busy = false
	for i, snack in snacks do
		local y = 38 + (i - 1) * 58
		local have = mySnacks[snack.id] or 0
		line(frame, y, 24, `{snack.emoji} {snack.name} (🎒 {have}개)`, { Font = Enum.Font.GothamBold, TextSize = 18, Size = UDim2.new(1, -120, 0, 24), TextColor3 = if have > 0 then INK else MUTED })
		line(frame, y + 25, 20, `💕 +{snack.friend} · 🐦 +{snack.flock}마리 · 🎁 선물 +{math.floor(snack.gift * 100)}%`, { TextSize = 15, TextColor3 = MUTED, Size = UDim2.new(1, -120, 0, 20) })
		local b = Ui.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, y + 4),
			Size = UDim2.fromOffset(110, 38),
			Text = if have > 0 then "뿌리기" else "없음",
			TextSize = 16,
			ZIndex = 32,
			Parent = frame,
		})
		if have <= 0 then
			b.AutoButtonColor = false
			b.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
		end
		b.Activated:Connect(function()
			if busy or have <= 0 then
				return
			end
			busy = true
			local fed, result = Remotes.PigeonFeed:InvokeServer(snack.id)
			busy = false
			if current ~= frame then
				return
			end
			Sounds.play(if fed then "ping" else "bass", 0.6, 1.2)
			if fed then
				close()
			else
				message.Text = result
				message.TextColor3 = RED
			end
		end)
	end
	button(frame, 0, "닫기", close)
	Sounds.play("swoosh", 0.4)
	closeWhenAway(frame, station, 10) -- 🚪 모이 통에서 멀어지면 닫혀요
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
	line(frame, 34, 40, `[멈춤] → [내리기] · 한 판 {comma(SalaryConfig.CLAW_PRICE)}원`, {
		TextSize = 16,
		TextColor3 = MUTED,
	})
	helpButton(frame, UDim2.new(1, -70, 0, 2), "인형뽑기", "① 집게가 좌우로 움직일 때 <b>[멈춤]</b>\n② 앞뒤로 움직일 때 <b>[내리기]</b>\n🎯 인형 정중앙을 노려야 잘 잡혀요\n✨ 희귀한 인형일수록 미끄러워요 😅")
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

	-- 버튼을 "뗄 때"가 아니라 "누르는 순간" 멈춰요 (Activated는 손을 뗄 때라 늦게 느껴져요)
	actionButton.MouseButton1Down:Connect(function()
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
			-- ⚡ 누른 순간 그 자리에 바로 멈춰요 (판정은 서버가 같은 시각으로 다시 계산)
			claw.Position = toBox(
				SalaryConfig.clawPosition(stopX - session.start, session.periodX),
				SalaryConfig.clawPosition(math.max(0, now - stopX - SalaryConfig.CLAW_GAP), session.periodZ)
			)
			Sounds.play("click", 0.5, 1.4)
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
-- backTo: 다른 창(🎒 소지품 등)에서 열었으면 아래에 [◀ 뒤로] 버튼을 달아 그 창으로 돌아가요
function Panels.showPlushies(backTo: (() -> ())?)
	local plushRows = math.ceil(#SalaryConfig.Plushies / 3)
	local frame = sheet(600, 560) -- (🎒 소지품 창과 같은 크기)
	closeOnOutside(frame)
	local _ = plushRows
	if backTo then
		button(frame, 0, "◀ 소지품으로", backTo)
	end
	line(frame, 0, 32, "🧸 내 인형", { Font = Enum.Font.GothamBlack, TextSize = 26 })
	line(frame, 34, 22, `눌러서 책상에 진열 (최대 {SalaryConfig.DESK_PLUSH_MAX}개)`, { TextSize = 14, TextColor3 = MUTED })
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
-- 🕹️ 오락실 (판정은 서버. 두더지는 때린 시각만, 카드는 뒤집을 카드 번호만 보내요)
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

-- 🃏 카드 짝 맞추기: 카드 그림은 서버만 알아요. 누른 카드 번호를 보내면 서버가 그림과 짝 여부를 알려 줘요
local function showMemory()
	local info = SalaryConfig.ArcadeGames.memory
	local frame = sheet(460, 520)
	local _, status = arcadeHeader(frame, `{info.emoji} {info.name}`, info.description)
	local scoreText = line(frame, 74, 24, "", { TextSize = 17, Font = Enum.Font.GothamBold })
	local COLS = SalaryConfig.MEMORY_COLS
	local TOTAL = SalaryConfig.MEMORY_PAIRS * 2
	local CARD, GAP = 64, 6
	local gridWidth = COLS * CARD + (COLS - 1) * GAP
	local BACK = Color3.fromRGB(110, 80, 200)
	local FACE = Color3.fromRGB(255, 255, 255)
	local DONE = Color3.fromRGB(190, 240, 190)
	local cards: { TextButton } = {}
	for i = 1, TOTAL do
		local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
		cards[i] = Ui.make("TextButton", {
			Position = UDim2.new(0.5, -gridWidth / 2 + col * (CARD + GAP), 0, 102 + row * (CARD + GAP)),
			Size = UDim2.fromOffset(CARD, CARD),
			BackgroundColor3 = BACK,
			Text = "?",
			TextColor3 = Color3.fromRGB(230, 220, 255),
			Font = Enum.Font.GothamBlack,
			TextSize = 28,
			AutoButtonColor = false,
			ZIndex = 31,
			Parent = frame,
		}, { Ui.corner(10), Ui.stroke(Color3.fromRGB(70, 50, 140), 2) })
	end
	local startButton = arcadeButton(frame, 0, `▶ 시작 ({comma(SalaryConfig.ARCADE_PRICE)}원)`)
	local run: any = nil
	local found = 0
	local opened: { [number]: boolean } = {} -- 짝을 찾아서 열려 있는 카드
	local shown: { [number]: boolean } = {} -- 지금 앞면이 보이는 카드 (짝 확인 중 포함)
	local busy = false -- 서버 답을 기다리거나 틀린 카드를 보여 주는 중

	local function setCard(index: number, emoji: string?, state: string)
		local card = cards[index]
		if state == "back" then
			card.Text = "?"
			card.TextSize = 28
			card.TextColor3 = Color3.fromRGB(230, 220, 255)
			card.BackgroundColor3 = BACK
		else
			card.Text = emoji or "?"
			card.TextSize = 38
			card.TextColor3 = INK
			card.BackgroundColor3 = if state == "done" then DONE else FACE
		end
	end
	local function resetCards()
		for i = 1, TOTAL do
			setCard(i, nil, "back")
		end
		table.clear(opened)
		table.clear(shown)
	end

	local function finish(result)
		if run ~= result then
			return
		end
		run = nil
		busy = false
		showResult(status, Remotes.Arcade:InvokeServer("finish"))
		startButton.Text = `▶ 한 판 더 ({comma(SalaryConfig.ARCADE_PRICE)}원)`
	end

	for i, card in cards do
		card.MouseButton1Down:Connect(function()
			local result = run
			if not result or busy or opened[i] or shown[i] then
				return
			end
			if workspace:GetServerTimeNow() < result.start then
				return -- 아직 준비 중
			end
			busy = true
			card.BackgroundColor3 = Color3.fromRGB(200, 190, 240) -- 누른 느낌 먼저
			Sounds.play("click", 0.4, 1.3)
			local r = Remotes.Arcade:InvokeServer("flip", i)
			if current ~= frame or run ~= result then
				return
			end
			if not r.ok then
				busy = false
				if not shown[i] then
					setCard(i, nil, "back")
				end
				if r.message then
					status.Text = r.message
					status.TextColor3 = RED
				end
				return
			end
			shown[i] = true
			setCard(i, r.emoji, "face")
			if not r.first then
				busy = false -- 첫 번째 카드: 바로 다음 카드 고르기
				return
			end
			if r.matched then
				opened[i], opened[r.first] = true, true
				setCard(i, r.emoji, "done")
				setCard(r.first, r.emoji, "done")
				found = r.found
				status.Text = `✨ 짝 찾았다! +{SalaryConfig.MEMORY_PAIR_POINTS}`
				status.TextColor3 = Color3.fromRGB(40, 140, 70)
				Sounds.play("ping", 0.5, 1.2 + found * 0.05)
				busy = false
				if r.cleared then
					status.Text = "🎉 다 찾았어요! 남은 시간 보너스!"
					task.delay(0.4, finish, result)
				end
			else
				status.Text = "😵 아니네요… 위치를 기억해요!"
				status.TextColor3 = MUTED
				Sounds.play("bass", 0.3, 1.4)
				local first = r.first
				task.delay(SalaryConfig.MEMORY_PEEK, function()
					if current ~= frame or run ~= result then
						return
					end
					shown[i], shown[first] = nil, nil
					setCard(i, nil, "back")
					setCard(first, nil, "back")
					busy = false
				end)
			end
		end)
	end

	startButton.Activated:Connect(function()
		if run then
			return
		end
		local result = Remotes.Arcade:InvokeServer("start", "memory")
		if not result.ok then
			status.Text = result.message
			status.TextColor3 = RED
			return
		end
		resetCards()
		run, found, busy = result, 0, false
		status.Text = "준비~ 카드를 2장씩 뒤집어요!"
		status.TextColor3 = INK
		startButton.Text = "게임 중…"
		task.spawn(function()
			while current == frame and run == result do
				local elapsed = workspace:GetServerTimeNow() - result.start
				local left = math.max(0, math.ceil(SalaryConfig.MEMORY_SECONDS - elapsed))
				scoreText.Text = `짝 {found}/{SalaryConfig.MEMORY_PAIRS} · 남은 시간 {left}초`
				scoreText.TextColor3 = if left <= 10 then RED else INK
				if elapsed >= SalaryConfig.MEMORY_SECONDS + 0.2 then
					status.Text = "⏰ 시간 끝!"
					finish(result)
					break
				end
				task.wait(0.1)
			end
		end)
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
	elseif kind == "memory" then
		showMemory()
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
-- 🎯 끌어서 던지기 풍선 다트 (풍선 벽·경품은 서버가 정하고, 화면은 각도·힘·놓은 시각만 보내요)
--   판 아무 데나 누른 채 뒤로(아래로) 끌었다가 놓으면 반대쪽으로 슝! (새총처럼, 많이 당길수록 세게)
--   날아가는 길은 서버와 같은 공식(SalaryConfig.dartFlight)이라 화면에서 본 그대로 맞아요
---------------------------------------------------------------------------
local function showDart()
	local RunService = game:GetService("RunService")
	local FIELD_W, FIELD_H = SalaryConfig.DART_FIELD_W, SalaryConfig.DART_FIELD_H
	local ORIGIN = SalaryConfig.DART_ORIGIN
	local MIN_ANGLE = SalaryConfig.DART_MIN_ANGLE
	local frame = sheet(420, 480)
	line(frame, 0, 28, "🎯 풍선 다트", { Font = Enum.Font.GothamBlack, TextSize = 24 })
	line(frame, 32, 26, "아래로 끌었다 놓으면 슝!", {
		TextSize = 14,
		TextColor3 = MUTED,
	})
	helpButton(frame, UDim2.new(1, -70, 0, 0), "풍선 다트", "🖱️ 판을 누른 채 <b>아래로 끌었다 놓으면</b> 다트가 날아가요 (많이 당길수록 세게)\n🎈 맞힌 풍선에 써 있는 경품을 받아요\n🧸 인형 풍선은 가끔 전설 인형!\n🔁 닫았다 열어도 같은 풍선 벽이에요")
	-- 풍선 벽 (하늘색 판, 넘어가는 다트는 잘려 보여요)
	local field = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.fromOffset(FIELD_W, FIELD_H),
		BackgroundColor3 = Color3.fromRGB(165, 220, 255),
		ClipsDescendants = true,
		ZIndex = 31,
		Parent = frame,
	}, { Ui.stroke(Color3.fromRGB(150, 110, 70), 3) })
	Ui.make("Frame", { -- 아래 나무 받침대
		Position = UDim2.fromOffset(0, FIELD_H - 26),
		Size = UDim2.fromOffset(FIELD_W, 26),
		BackgroundColor3 = Color3.fromRGB(190, 140, 90),
		BorderSizePixel = 0,
		ZIndex = 32,
		Parent = field,
	})
	-- 고무줄·당긴 다트는 판 밖(아래)으로도 보여야 해서 안 잘리는 층에 그려요
	local overlay = Ui.make("Frame", {
		Position = field.Position,
		Size = field.Size,
		BackgroundTransparency = 1,
		ZIndex = 31,
		Parent = frame,
	})
	-- 누르고 끄는 곳 (판 전체)
	local grab = Ui.make("Frame", {
		Position = field.Position,
		Size = field.Size,
		BackgroundTransparency = 1,
		Active = true,
		ZIndex = 50,
		Parent = frame,
	})
	local status = line(frame, 356, 40, "풍선 벽 가져오는 중…", {
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local mainButton = Ui.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(260, 42),
		Text = "…",
		TextSize = 18,
		ZIndex = 31,
		Parent = frame,
	})

	-- 🪵 새총 기둥 두 개 + 고무줄 두 가닥
	local POST_L, POST_R = ORIGIN + Vector2.new(-22, -4), ORIGIN + Vector2.new(22, -4)
	for _, post in { POST_L, POST_R } do
		Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(post.X, post.Y),
			Size = UDim2.fromOffset(6, FIELD_H - post.Y),
			BackgroundColor3 = Color3.fromRGB(120, 80, 45),
			BorderSizePixel = 0,
			ZIndex = 41,
			Parent = overlay,
		}, { Ui.corner(3) })
	end
	local function makeBand(): Frame
		return Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(200, 60, 50),
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 42,
			Parent = overlay,
		})
	end
	local bandL, bandR = makeBand(), makeBand()
	-- 두 점 사이에 선 긋기
	local function setLine(bar: Frame, a: Vector2, b: Vector2, thickness: number)
		local middle = (a + b) / 2
		local delta = b - a
		bar.Position = UDim2.fromOffset(middle.X, middle.Y)
		bar.Size = UDim2.fromOffset(delta.Magnitude, thickness)
		bar.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	end

	-- 🎯 다트 (오른쪽 끝이 뾰족한 끝 → 날아가는 방향으로 돌려요)
	local DART_LEN = 34
	local dart = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(DART_LEN, 10),
		BackgroundTransparency = 1,
		ZIndex = 44,
		Parent = overlay,
	}, {
		Ui.make("Frame", { -- 깃털
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(8, 10),
			BackgroundColor3 = Color3.fromRGB(255, 200, 60),
			BorderSizePixel = 0,
			ZIndex = 44,
		}),
		Ui.make("Frame", { -- 몸통
			Position = UDim2.fromOffset(6, 3),
			Size = UDim2.fromOffset(22, 4),
			BackgroundColor3 = Color3.fromRGB(70, 70, 80),
			BorderSizePixel = 0,
			ZIndex = 45,
		}),
		Ui.make("Frame", { -- 뾰족한 끝
			Position = UDim2.fromOffset(DART_LEN - 7, 2),
			Size = UDim2.fromOffset(7, 6),
			BackgroundColor3 = Color3.fromRGB(220, 50, 50),
			BorderSizePixel = 0,
			ZIndex = 45,
		}, { Ui.corner(3) }),
	})
	-- tip = 뾰족한 끝 자리, direction = 향하는 방향
	local function placeDart(tip: Vector2, direction: Vector2)
		local unit = if direction.Magnitude > 0.001 then direction.Unit else Vector2.new(0, -1)
		local center = tip - unit * (DART_LEN / 2)
		dart.Position = UDim2.fromOffset(center.X, center.Y)
		dart.Rotation = math.deg(math.atan2(unit.Y, unit.X))
	end

	-- 겨냥 점선 (처음 조금만 보여 줘요 → 나머지 포물선은 감으로!)
	--   ⚖️ 균형감: 점선이 길어져요 (최대 +60% → 점 6개 → 10개)
	local GUIDE_DOTS, GUIDE_GAP = math.floor(6 * (1 + SalaryConfig.playerFitnessEffect(player, "aim")) + 0.5), 0.02
	local dots: { Frame } = {}
	for i = 1, GUIDE_DOTS do
		dots[i] = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(6, 6),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.1 + i / GUIDE_DOTS * 0.6,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 43,
			Parent = field,
		}, { Ui.corner(3) })
	end
	local powerLabel = Ui.make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromOffset(ORIGIN.X + 70, ORIGIN.Y - 4),
		Size = UDim2.fromOffset(90, 20),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = INK,
		TextStrokeColor3 = Color3.fromRGB(255, 255, 255),
		TextStrokeTransparency = 0.3,
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		Visible = false,
		ZIndex = 46,
		Parent = overlay,
	})

	-- 판 상태 (서버가 보내 준 그대로)
	local wall: { any } = {}
	local wallStart = 0
	local popped: { [number]: boolean } = {}
	local views: { Frame } = {}
	local mode = "loading" -- "loading" / "preview"(아직 돈 안 냄) / "playing" / "finished"
	local left = 0
	local total, totalTickets = 0, 0
	local busy = false
	local flight: any = nil -- 날아가는 중인 다트 { angle, power, release, predicted, result, done }
	local dragging = false
	local dragStart, dragNow = Vector2.zero, Vector2.zero
	local connections: { RBXScriptConnection } = {}

	local function ticketText(tickets: number): string
		return if tickets > 0 then ` · 🎟️ {tickets}장` else ""
	end
	local function setStatus(text: string, color: Color3?)
		status.Text = text
		status.TextColor3 = color or INK
	end
	local function idleText()
		if mode == "playing" then
			setStatus(`🎯 다트 {left}개 남음 · 이번 판 💰 {comma(total)}원{ticketText(totalTickets)}`)
		elseif mode == "preview" then
			setStatus("이번 풍선 벽이에요! 마음에 들면 시작")
		end
	end

	-- 🎈 풍선 그리기 (경품 글씨가 써 있어요)
	local function buildBalloons()
		for _, view in views do
			view:Destroy()
		end
		table.clear(views)
		for index, data in wall do
			local info = SalaryConfig.getDartPrize(data.id) or SalaryConfig.getDartPrize("none")
			local size = data.r * 2
			local view = Ui.make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(size, size * 1.1),
				BackgroundColor3 = info.color,
				Visible = not popped[index],
				ZIndex = 34,
				Parent = field,
			}, {
				Ui.corner(data.r),
				Ui.stroke(if info.jackpot then Color3.fromRGB(230, 60, 40) else Color3.fromRGB(255, 255, 255), if info.jackpot then 3 else 2),
				Ui.make("Frame", { -- 풍선 끈
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 1),
					Size = UDim2.fromOffset(2, 14),
					BackgroundColor3 = Color3.fromRGB(110, 110, 120),
					BorderSizePixel = 0,
					ZIndex = 33,
				}),
				Ui.make("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.9, 0.6),
					BackgroundTransparency = 1,
					Text = info.label,
					TextColor3 = Color3.fromRGB(40, 30, 30),
					Font = Enum.Font.GothamBlack,
					TextScaled = true,
					ZIndex = 35,
				}, { Ui.make("UITextSizeConstraint", { MaxTextSize = 16 }) }),
			})
			views[index] = view
		end
	end

	-- 🖱️ 끈 만큼 → (각도, 힘, 당긴 방향) — 당긴 반대쪽으로 날아가요
	local function aimFromDrag(): (number, number, Vector2)
		local scale = field.AbsoluteSize.X / FIELD_W
		if scale <= 0 then
			scale = 1
		end
		local pull = (dragNow - dragStart) / scale
		local power = math.clamp(pull.Magnitude / SalaryConfig.DART_DRAG_MAX, 0, 1)
		local angle = math.atan2(pull.Y, -pull.X) -- 아래로 당기면 위로 (π/2)
		if angle < 0 then
			angle = if angle < -math.pi / 2 then math.pi - MIN_ANGLE else MIN_ANGLE -- 위로 당기면 옆으로 눕혀요
		end
		return math.clamp(angle, MIN_ANGLE, math.pi - MIN_ANGLE), power, pull
	end

	-- 💥 펑! (조각이 튀고, 경품 글씨가 떠올라요)
	local function popEffect(position: Vector2, color: Color3, text: string, textColor: Color3)
		local flash = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(position.X, position.Y),
			Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.2,
			ZIndex = 46,
			Parent = field,
		}, { Ui.corner(40) })
		TweenService:Create(flash, TweenInfo.new(0.3), { Size = UDim2.fromOffset(80, 80), BackgroundTransparency = 1 }):Play()
		for i = 1, 8 do
			local angle = i / 8 * 2 * math.pi
			local shard = Ui.make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(position.X, position.Y),
				Size = UDim2.fromOffset(8, 6),
				Rotation = math.deg(angle),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				ZIndex = 45,
				Parent = field,
			})
			local away = position + Vector2.new(math.cos(angle), math.sin(angle)) * 34
			TweenService:Create(shard, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.fromOffset(away.X, away.Y + 10),
				BackgroundTransparency = 1,
			}):Play()
			task.delay(0.5, function()
				shard:Destroy()
			end)
		end
		local float = Ui.make("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(position.X, position.Y),
			Size = UDim2.fromOffset(200, 26),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = textColor,
			TextStrokeTransparency = 0.3,
			TextStrokeColor3 = Color3.fromRGB(255, 255, 255),
			Font = Enum.Font.GothamBlack,
			TextSize = 20,
			ZIndex = 47,
			Parent = field,
		})
		TweenService:Create(float, TweenInfo.new(1.1), {
			Position = UDim2.fromOffset(position.X, position.Y - 40),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		task.delay(1.15, function()
			flash:Destroy()
			float:Destroy()
		end)
	end

	-- 🏁 다트가 도착했을 때 (서버 결과 그대로)
	local function finishThrow(result: any)
		left = result.left
		total = result.total
		totalTickets = result.totalTickets
		if result.hit then
			local index = result.hit
			local data = wall[index]
			popped[index] = true
			local position = if data then SalaryConfig.dartBalloonPos(data, result.release + result.flightTime - wallStart) else ORIGIN
			if views[index] then
				views[index].Visible = false
			end
			local info = SalaryConfig.getDartPrize(if data then data.id else "none")
			local text, color = "💨 꽝!", MUTED
			if result.money > 0 then
				text, color = `+{comma(result.money)}원`, Color3.fromRGB(40, 140, 70)
			elseif result.tickets > 0 then
				text, color = `🎟️ +{result.tickets}장`, Color3.fromRGB(220, 80, 150)
			elseif result.name ~= "" then
				text, color = result.name, Color3.fromRGB(140, 80, 220)
			end
			popEffect(position, if info then info.color else Color3.fromRGB(200, 200, 200), text, color)
			Sounds.play("crunch", 0.8, 1.5) -- 펑!
			if result.money > 0 or result.tickets > 0 or result.name ~= "" then
				Sounds.play("ping", 0.5, if result.money >= 3000 then 1.4 else 1.1)
			else
				Sounds.play("bass", 0.3)
			end
			if result.id == "legend" then
				Hud.popup(`🎯 {result.name}`, Color3.fromRGB(255, 210, 80), 3)
			elseif result.id == "plush" and result.name ~= "" then
				Hud.popup(`🎯 {result.name}`, Color3.fromRGB(200, 160, 255), 2)
			elseif result.id == "jackpot" then
				Hud.popup(`🎯 대박 풍선! +{comma(result.money)}원`, Color3.fromRGB(255, 210, 80), 3)
			end
			setStatus(`💥 펑! {if text == "💨 꽝!" then "꽝이에요" else text} · 다트 {left}개 남음\n이번 판 💰 {comma(total)}원{ticketText(totalTickets)}`, Color3.fromRGB(40, 140, 70))
		else
			Sounds.play("bass", 0.3, 1.2)
			local why = if result.reason == "over" then "너무 세요! 풍선 위로 지나갔어요"
				elseif result.reason == "side" then "옆으로 빗나갔어요"
				else "힘이 모자라요! 풍선 아래로 떨어졌어요"
			setStatus(`😅 {why} · 다트 {left}개 남음\n이번 판 💰 {comma(total)}원{ticketText(totalTickets)}`, Color3.fromRGB(200, 110, 30))
		end
		task.wait(0.7)
		if current ~= frame then
			return
		end
		flight = nil
		busy = false
		dart.Visible = true
		if result.finished then
			mode = "finished"
			dart.Visible = false
			mainButton.Text = "🎯 새 풍선 벽 보기"
			setStatus(`🏁 끝! 이번 판 💰 {comma(total)}원{ticketText(totalTickets)}`, Color3.fromRGB(40, 140, 70))
		end
	end

	-- 서버가 보내 준 판 상태로 화면 맞추기
	local function load(state: any)
		wall = state.balloons or {}
		wallStart = state.start or workspace:GetServerTimeNow()
		table.clear(popped)
		for _, index in state.popped or {} do
			popped[index] = true
		end
		left = state.left or 0
		total = state.money or 0
		totalTickets = state.tickets or 0
		flight = nil
		mode = if state.paid then "playing" else "preview"
		buildBalloons()
		dart.Visible = true
		mainButton.Text = if mode == "playing" then "🎯 판을 끌어서 던져요!" else `▶ 시작 ({comma(SalaryConfig.DART_PRICE)}원)`
		idleText()
	end
	local function fetch()
		busy = true
		local result = Remotes.Dart:InvokeServer("open")
		busy = false
		if current ~= frame then
			return
		end
		if not result.ok then
			setStatus(result.message, RED)
			return
		end
		load(result)
	end

	mainButton.MouseButton1Down:Connect(function()
		if busy then
			return
		end
		if mode == "preview" then
			busy = true
			local result = Remotes.Dart:InvokeServer("start")
			busy = false
			if current ~= frame then
				return
			end
			if not result.ok then
				setStatus(result.message, RED)
				return
			end
			load(result)
			Sounds.play("ping", 0.4, 1.2)
		elseif mode == "finished" or mode == "loading" then
			fetch()
		end
	end)

	-- 🚀 놓으면 던지기: 화면은 바로 날리고(같은 공식으로 미리 계산), 서버 결과가 오면 그대로 마무리
	local function throw(angle: number, power: number)
		busy = true
		local release = workspace:GetServerTimeNow()
		local _, predicted = SalaryConfig.dartSimulate(wall, popped, angle, power, release - wallStart)
		local thisFlight = { angle = angle, power = power, release = release, predicted = predicted, result = nil, done = false }
		flight = thisFlight
		left = math.max(0, left - 1)
		Sounds.play("swoosh", 0.5, 1.3)
		task.spawn(function()
			local result = Remotes.Dart:InvokeServer("throw", angle, power, release)
			if current ~= frame or flight ~= thisFlight then
				return
			end
			if not result.ok then
				flight = nil
				busy = false
				left += 1
				setStatus(result.message, RED)
				return
			end
			-- 서버가 쓴 값으로 맞춰요 (보통은 똑같아요)
			thisFlight.angle, thisFlight.power, thisFlight.release = result.angle, result.power, result.release
			thisFlight.result = result
		end)
	end

	table.insert(connections, grab.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if mode == "preview" then
			setStatus("▶ 시작을 먼저 눌러 주세요!", RED)
			return
		end
		if mode ~= "playing" or busy or left <= 0 then
			return
		end
		dragging = true
		dragStart = Vector2.new(input.Position.X, input.Position.Y)
		dragNow = dragStart
	end))
	table.insert(connections, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			dragNow = Vector2.new(input.Position.X, input.Position.Y)
		end
	end))
	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		if not dragging or (input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch) then
			return
		end
		dragging = false
		local angle, power = aimFromDrag()
		if power < SalaryConfig.DART_MIN_POWER then
			setStatus("조금 더 길게 끌어 주세요! (많이 당길수록 세게 날아가요)", Color3.fromRGB(200, 110, 30))
			return
		end
		if mode == "playing" and not busy and left > 0 then
			throw(angle, power)
		end
	end))

	-- 🎞️ 매 프레임: 풍선 둥실둥실 + 다트 (가만히 / 당기는 중 / 날아가는 중)
	table.insert(connections, RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		for index, data in wall do
			local view = views[index]
			if view and not popped[index] then
				local position = SalaryConfig.dartBalloonPos(data, now - wallStart)
				view.Position = UDim2.fromOffset(position.X, position.Y)
			end
		end
		local aiming = dragging and not flight
		local angle, power, pull = 0, 0, Vector2.zero
		if aiming then
			angle, power, pull = aimFromDrag()
		end
		local showGuide = aiming and power >= SalaryConfig.DART_MIN_POWER
		for i, dot in dots do
			dot.Visible = showGuide
			if showGuide then
				local position = SalaryConfig.dartFlight(angle, power, i * GUIDE_GAP)
				dot.Position = UDim2.fromOffset(position.X, position.Y)
			end
		end
		powerLabel.Visible = aiming
		bandL.Visible = aiming
		bandR.Visible = aiming
		if flight then
			local endTime = if flight.result then flight.result.flightTime else flight.predicted
			local elapsed = now - flight.release
			local t = math.clamp(elapsed, 0, endTime)
			local position = SalaryConfig.dartFlight(flight.angle, flight.power, t)
			placeDart(position, SalaryConfig.dartFlight(flight.angle, flight.power, t + 0.01) - position)
			-- 판 밖으로 나가면 안 보여요 (위로 넘어가거나 아래로 떨어진 다트)
			dart.Visible = position.X > -10 and position.X < FIELD_W + 10 and position.Y > -10 and position.Y < FIELD_H + 10
			if elapsed >= endTime and flight.result and not flight.done then
				flight.done = true
				task.spawn(finishThrow, flight.result)
			end
		elseif aiming then
			local direction = Vector2.new(math.cos(angle), -math.sin(angle))
			local tip = ORIGIN - direction * math.min(pull.Magnitude, SalaryConfig.DART_DRAG_MAX) * 0.3
			placeDart(tip, direction)
			local tail = tip - direction * DART_LEN
			setLine(bandL, POST_L, tail, 3)
			setLine(bandR, POST_R, tail, 3)
			powerLabel.Text = if power < SalaryConfig.DART_MIN_POWER then "더 당겨요" else `힘 {math.floor(power * 100 + 0.5)}%`
		elseif mode ~= "finished" then
			placeDart(ORIGIN, Vector2.new(0, -1)) -- 가만히 위를 보고 있어요
		end
	end))
	frame.Destroying:Connect(function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end)

	placeDart(ORIGIN, Vector2.new(0, -1))
	Sounds.play("swoosh", 0.4)
	fetch()
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
	frame:SetAttribute("PhoneGame", true) -- (다른 폰 게임으로 바꿀 때 일하기로 돌아가지 않게)
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
		-- 다른 폰 게임 창으로 바꾼 거면 그대로 폰 게임 중이에요
		local replaced = current ~= nil and current:GetAttribute("PhoneGame") == true
		if not replaced and player:GetAttribute("SalaryAction") == "phone" then
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
	frame:SetAttribute("PhoneGame", true) -- (다른 폰 게임으로 바꿀 때 일하기로 돌아가지 않게)
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
		-- 다른 폰 게임 창으로 바꾼 거면 그대로 폰 게임 중이에요
		local replaced = current ~= nil and current:GetAttribute("PhoneGame") == true
		if not replaced and player:GetAttribute("SalaryAction") == "phone" then
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
	frame:SetAttribute("PhoneGame", true) -- (다른 폰 게임으로 바꿀 때 일하기로 돌아가지 않게)
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.Position = UDim2.new(1, -20, 0.5, 0)
	Hud.numberGame = true -- (숫자 키를 책상 행동 단축키 대신 여기서 써요)
	frame:SetAttribute("NumberGame", true)
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
		if not (current and current:GetAttribute("NumberGame")) then
			Hud.numberGame = false
		end
		if playing then
			Remotes.BaseballPlay:InvokeServer("quit")
		end
		-- 다른 폰 게임 창으로 바꾼 거면 그대로 폰 게임 중이에요
		local replaced = current ~= nil and current:GetAttribute("PhoneGame") == true
		if not replaced and player:GetAttribute("SalaryAction") == "phone" then
			Remotes.SetAction:FireServer("work")
		end
	end)
end

-- 🎁 경비원 뇌물 창: 선물을 고르면 그 경비원이 일정 시간 못 본 척해요 (좋은 선물일수록 오래)
Remotes:WaitForChild("GuardBribeOpen").OnClientEvent:Connect(function(guardId: string, guardName: string)
	local count = #SalaryConfig.GuardBribes
	local frame = sheet(400, 200 + count * 58) -- (아래 안내 문구가 버튼과 안 겹치게 여유)
	line(frame, 0, 30, "🎁 경비원에게 선물", { Font = Enum.Font.GothamBlack, TextSize = 22 })
	line(frame, 32, 20, `👮 {guardName} · 하루 한 번`, { TextSize = 14, TextColor3 = MUTED })
	helpButton(frame, UDim2.new(1, -70, 0, 0), "경비원 선물", "🏪 사내 매점 <b>[👮 경비원]</b> 탭에서 선물을 사면 🎒에 보관돼요\n🎁 선물을 받은 경비원은 그동안 <b>못 본 척</b> (의심도가 안 올라요)\n⏳ 좋은 선물일수록 오래가요\n📅 경비원마다 하루 한 번만 받아요")
	local message = line(frame, 0, 22, "", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -50),
		TextSize = 14,
		TextColor3 = MUTED,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local busy = false
	local okGifts, myGifts = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("GuardGifts") or "{}")
	end)
	myGifts = if okGifts and typeof(myGifts) == "table" then myGifts else {}
	for i, bribe in SalaryConfig.GuardBribes do
		local y = 60 + (i - 1) * 58
		local have = myGifts[bribe.id] or 0
		line(frame, y, 22, `{bribe.emoji} {bribe.name} (🎒 {have}개)`, { Font = Enum.Font.GothamBold, TextSize = 16, Size = UDim2.new(1, -130, 0, 22), TextColor3 = if have > 0 then INK else MUTED })
		line(frame, y + 22, 20, `🙈 {SalaryConfig.gameDurationText(bribe.minutes)} 동안 못 본 척`, { TextSize = 13, TextColor3 = MUTED, Size = UDim2.new(1, -130, 0, 20) })
		local buy = Ui.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, y + 4),
			Size = UDim2.fromOffset(120, 38),
			Text = if have > 0 then "🎁 드리기" else "🏪 매점에서",
			TextSize = 15,
			ZIndex = 32,
			Parent = frame,
		})
		buy.Activated:Connect(function()
			if busy then
				return
			end
			busy = true
			local result = Remotes.GuardBribe:InvokeServer(guardId, bribe.id)
			busy = false
			if current ~= frame then
				return
			end
			message.Text = result.message
			message.TextColor3 = if result.ok then Color3.fromRGB(40, 140, 70) else RED
			Sounds.play(if result.ok then "ping" else "bass", 0.6, 1.2)
			if result.ok then
				task.delay(1.2, function()
					if current == frame then
						close()
					end
				end)
			end
		end)
	end
	button(frame, 0, "닫기", close)
	Sounds.play("swoosh", 0.4)
end)

-- 🏙️ 눈치 스트리트 게임·가게, 🏪 사내 매점: 창을 연 자리에서 멀어지면 창을 닫아요
--   (기계·계산대 앞에서 [E]로 열기 때문에, 열 때 서 있던 곳을 기준으로 해요)
do
	local function guardHere(range: number)
		task.delay(0.3, function() -- (창이 다 만들어진 뒤에)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and current then
				closeWhenAway(current, root.Position, range)
			end
		end)
	end
	for _, info in { { "GuardBribeOpen", 12 }, { "StreetMenu", 14 }, { "ClawOpen", 12 }, { "ArcadeOpen", 12 }, { "WheelOpen", 12 }, { "DartOpen", 12 } } do
		local remoteName, range = info[1], info[2]
		Remotes:WaitForChild(remoteName).OnClientEvent:Connect(function()
			guardHere(range)
		end)
	end
end

-- 🛒 [온라인 쇼핑] 농땡이를 켜면 쇼핑몰(꾸미기 상점)이 자동으로 열리고, 그만두면 닫혀요
--   (쇼핑 중에 [5] 쇼핑을 다시 누르면 다시 열려요: Hud.onShoppingAgain)
--   🛒 쇼핑몰 창을 닫으면 폰 게임처럼 자연스럽게 [일하기]로 돌아가요 (다른 창으로 바꾼 거면 그대로)
do
	local mallFrame: Frame? = nil
	local function openMall()
		Panels.showDecor()
		local frame = current
		mallFrame = frame
		if frame then
			frame.Destroying:Connect(function()
				task.defer(function()
					local replaced = current ~= nil
					if not replaced and player:GetAttribute("SalaryAction") == "shopping" then
						Remotes.SetAction:FireServer("work")
					end
				end)
			end)
		end
	end
	Hud.onShoppingAgain = function()
		if isShopping() and current ~= mallFrame then
			openMall()
		end
	end
	local wasShopping = false
	player:GetAttributeChangedSignal("SalaryState"):Connect(function()
		local shopping = isShopping()
		if shopping and not wasShopping and not current then
			openMall()
		elseif not shopping and wasShopping and mallFrame and current == mallFrame then
			close() -- 일하기로 복귀하면 쇼핑 창도 쓱 닫아요
		end
		if not shopping then
			mallFrame = nil
		end
		wasShopping = shopping
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
