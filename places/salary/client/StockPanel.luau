-- 📈 화장실 증권 창: 변기에 앉으면 화면에 떠요 (게임 속 가짜 주식)
-- 큰 글씨로 가격·보유 주식·손익을 보여 주고, 맨 위에 내 주식 전체 요약이 있어요.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SalaryConfig = require(Shared:WaitForChild("SalaryConfig"))
local Ui = require(Shared:WaitForChild("Ui"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Hud = require(script.Parent.Hud)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local comma = Hud.comma
local text = Hud.text

local UP = Color3.fromRGB(255, 95, 85) -- 한국 증시처럼 오르면 빨강
local DOWN = Color3.fromRGB(95, 155, 255) -- 내리면 파랑
local MUTED = Color3.fromRGB(185, 190, 205)
local WIDTH = 600
local ROW_HEIGHT = 132
local HEADER = 128
local FOOTER = 56
local BARS = 30

local StockPanel = {}

local function decode(source: Instance, attribute: string): { [string]: any }
	local ok, value = pcall(function()
		return HttpService:JSONDecode(source:GetAttribute(attribute) or "{}")
	end)
	return if ok and typeof(value) == "table" then value else {}
end

local function signed(n: number): string
	return `{if n >= 0 then "+" else ""}{comma(n)}`
end

---------------------------------------------------------------------------
-- 창 만들기
---------------------------------------------------------------------------
local frame = Ui.make("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.55, 0),
	Size = UDim2.fromOffset(WIDTH, HEADER + #SalaryConfig.Stocks * ROW_HEIGHT + FOOTER),
	BackgroundColor3 = Color3.fromRGB(18, 22, 30),
	BackgroundTransparency = 0.03,
	Visible = false,
	ZIndex = 20,
	Parent = Ui.gui,
}, { Ui.corner(14), Ui.padding(14), Ui.stroke(Color3.fromRGB(90, 160, 255), 2) })
local scale = Ui.make("UIScale", { Parent = frame })

text({ Size = UDim2.new(1, 0, 0, 30), TextSize = 26, Text = "📈 화장실 증권", ZIndex = 21, Parent = frame })
local balanceText = text({
	Size = UDim2.new(1, 0, 0, 30),
	TextSize = 20,
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = Color3.fromRGB(255, 220, 120),
	ZIndex = 21,
	Parent = frame,
})
-- 내 주식 전체 요약
local summaryText = text({
	Position = UDim2.fromOffset(0, 36),
	Size = UDim2.new(1, 0, 0, 26),
	TextSize = 19,
	ZIndex = 21,
	Parent = frame,
})
local newsText = text({
	Position = UDim2.fromOffset(0, 66),
	Size = UDim2.new(1, 0, 0, 48),
	TextSize = 18,
	TextWrapped = true,
	TextColor3 = Color3.fromRGB(255, 230, 150),
	ZIndex = 21,
	Parent = frame,
})

local messageText: TextLabel

local function trade(stockId: string, quantity: number)
	Sounds.play("click", 0.4)
	local ok, message = Remotes.TradeStock:InvokeServer(stockId, quantity)
	messageText.Text = message
	messageText.TextColor3 = if ok then Color3.fromRGB(140, 230, 160) else Color3.fromRGB(255, 140, 130)
	if ok then
		Sounds.play("ping", 0.4, if quantity > 0 then 1.1 else 0.9)
	end
end

local function tradeButton(parent: Instance, x: number, label: string, onClick: () -> ())
	local b = Ui.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, x, 0, 70),
		Size = UDim2.fromOffset(96, 36),
		Text = label,
		TextSize = 17,
		ZIndex = 22,
		Parent = parent,
	})
	b.Activated:Connect(onClick)
end

local rows = {}
for i, stock in SalaryConfig.Stocks do
	local row = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, HEADER + (i - 1) * ROW_HEIGHT - 8),
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT - 8),
		BackgroundColor3 = Color3.fromRGB(32, 38, 50),
		ZIndex = 21,
		Parent = frame,
	}, { Ui.corner(10), Ui.padding(8) })

	text({ Size = UDim2.fromOffset(255, 24), TextSize = 20, Text = `{stock.emoji} {stock.name}`, ZIndex = 22, Parent = row })
	local priceText = text({ Position = UDim2.fromOffset(0, 26), Size = UDim2.fromOffset(255, 30), TextSize = 24, ZIndex = 22, Parent = row })
	local ownedText = text({ Position = UDim2.fromOffset(0, 60), Size = UDim2.fromOffset(250, 22), TextSize = 17, TextColor3 = MUTED, ZIndex = 22, Parent = row })
	local profitText = text({ Position = UDim2.fromOffset(0, 82), Size = UDim2.fromOffset(250, 22), TextSize = 17, ZIndex = 22, Parent = row })

	-- 미니 그래프 (최근 가격 막대)
	local chart = Ui.make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 2),
		Size = UDim2.fromOffset(290, 60),
		BackgroundColor3 = Color3.fromRGB(24, 28, 38),
		ZIndex = 22,
		Parent = row,
	}, { Ui.corner(6) })
	local bars = {}
	for b = 1, BARS do
		bars[b] = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new((b - 1) / BARS, 0, 1, 0),
			Size = UDim2.new(1 / BARS, -1, 0, 2),
			BorderSizePixel = 0,
			ZIndex = 23,
			Parent = chart,
		})
	end

	tradeButton(row, -204, "+1주", function()
		trade(stock.id, 1)
	end)
	tradeButton(row, -102, "+10주", function()
		trade(stock.id, 10)
	end)
	tradeButton(row, 0, "전부 팔기", function()
		trade(stock.id, -999999)
	end)

	rows[stock.id] = { price = priceText, owned = ownedText, profit = profitText, bars = bars }
end

messageText = text({
	Position = UDim2.new(0, 0, 1, -50),
	Size = UDim2.new(1, 0, 0, 24),
	TextSize = 17,
	Text = "",
	ZIndex = 21,
	Parent = frame,
})
local footerText = text({
	Position = UDim2.new(0, 0, 1, -24),
	Size = UDim2.new(1, 0, 0, 22),
	TextSize = 15,
	TextColor3 = MUTED,
	ZIndex = 21,
	Parent = frame,
})

---------------------------------------------------------------------------
-- 갱신
---------------------------------------------------------------------------
local function refresh()
	local prices = decode(ReplicatedStorage, "StockPrices")
	local history = decode(ReplicatedStorage, "StockHistory")
	local holdings = decode(player, "StockHoldings")
	local costs = decode(player, "StockCost")

	balanceText.Text = `🏦 통장 {comma(player:GetAttribute("TotalMoney") or 0)}원`
	newsText.Text = ReplicatedStorage:GetAttribute("StockNews") or ""

	local totalValue, totalCost = 0, 0
	for _, stock in SalaryConfig.Stocks do
		local row = rows[stock.id]
		local price = prices[stock.id] or stock.price
		local points = history[stock.id] or { price }
		local first = points[1] or price
		local change = if first > 0 then (price - first) / first * 100 else 0
		local color = if change >= 0 then UP else DOWN
		row.price.Text = `{comma(price)}원  {if change >= 0 then "▲" else "▼"}{string.format("%.1f", math.abs(change))}%`
		row.price.TextColor3 = color

		local owned = holdings[stock.id] or 0
		if owned > 0 then
			local value = price * owned
			local cost = costs[stock.id] or 0
			local profit = value - cost
			totalValue += value
			totalCost += cost
			row.owned.Text = `보유 {owned}주 · 평가 {comma(value)}원`
			row.profit.Text = `손익 {signed(math.floor(profit))}원 ({string.format("%+.1f", if cost > 0 then profit / cost * 100 else 0)}%)`
			row.profit.TextColor3 = if profit >= 0 then UP else DOWN
		else
			row.owned.Text = "보유 없음"
			row.profit.Text = ""
		end

		-- 그래프: 최근 가격들을 최저~최고 사이로 맞춰 막대 높이로
		local low, high = math.huge, -math.huge
		for _, p in points do
			low = math.min(low, p)
			high = math.max(high, p)
		end
		local range = math.max(high - low, 1)
		for b, bar in row.bars do
			local p = points[#points - BARS + b]
			if p then
				bar.Visible = true
				bar.Size = UDim2.new(1 / BARS, -1, (p - low) / range * 0.85 + 0.15, 0)
				bar.BackgroundColor3 = color
			else
				bar.Visible = false
			end
		end
	end

	if totalValue > 0 then
		local profit = totalValue - totalCost
		summaryText.Text = `💼 내 주식 평가액 {comma(totalValue)}원 · 손익 {signed(math.floor(profit))}원`
		summaryText.TextColor3 = if profit >= 0 then UP else DOWN
	else
		summaryText.Text = "💼 아직 가진 주식이 없어요. +1주로 시작해 보세요!"
		summaryText.TextColor3 = MUTED
	end

	local realized = player:GetAttribute("StockProfitTotal") or 0
	local left = player:GetAttribute("ToiletLeft") or 0
	local warning = if left > 0 then `⏰ 자리 비움 들키기까지 {left}초` else "🚨 자리 비운 게 티 나요! 얼른 자리로!"
	footerText.Text = `누적 실현 손익 {signed(realized)}원 · {warning} (게임 속 가짜 주식)`
end

-- 화면 크기에 맞추기: 폰에서는 가운데에, 화면에 들어가게 줄여요
local function fit()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local compact = Hud.isCompact()
	scale.Scale = math.clamp(math.min((viewport.Y - 90) / frame.Size.Y.Offset, (viewport.X - 24) / frame.Size.X.Offset), 0.45, 1)
	if compact then
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.new(0.5, 0, 0.53, 0)
	else
		frame.AnchorPoint = Vector2.new(1, 0.5)
		frame.Position = UDim2.new(1, -12, 0.55, 0)
	end
end

function StockPanel.start()
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	task.spawn(function()
		while true do
			local onToilet = player:GetAttribute("OnToilet") == true and player:GetAttribute("ScreenHidden") ~= true
			if onToilet and not frame.Visible then
				fit()
				Sounds.play("swoosh", 0.4)
				messageText.Text = "🚽 변기에 앉았다… 이제 시장을 볼 시간!"
				messageText.TextColor3 = MUTED
			end
			frame.Visible = onToilet
			if onToilet then
				refresh()
			end
			task.wait(0.25)
		end
	end)
end

return StockPanel
