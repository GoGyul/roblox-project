-- 📈 화장실 증권 창: 변기에 앉으면 화면 오른쪽에 떠요 (게임 속 가짜 주식)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SalaryConfig = require(Shared:WaitForChild("SalaryConfig"))
local Ui = require(Shared:WaitForChild("Ui"))
local Hud = require(script.Parent.Hud)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local comma = Hud.comma
local text = Hud.text

local UP = Color3.fromRGB(230, 80, 70) -- 한국 증시처럼 오르면 빨강
local DOWN = Color3.fromRGB(80, 140, 240) -- 내리면 파랑
local ROW_HEIGHT = 100
local BARS = 30

local StockPanel = {}

local function decode(attribute: string): { [string]: any }
	local ok, value = pcall(function()
		return HttpService:JSONDecode(ReplicatedStorage:GetAttribute(attribute) or player:GetAttribute(attribute) or "{}")
	end)
	return if ok and typeof(value) == "table" then value else {}
end

local function decodePlayer(attribute: string): { [string]: any }
	local ok, value = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute(attribute) or "{}")
	end)
	return if ok and typeof(value) == "table" then value else {}
end

---------------------------------------------------------------------------
-- 창 만들기
---------------------------------------------------------------------------
local frame = Ui.make("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.56, 0),
	Size = UDim2.fromOffset(420, 96 + #SalaryConfig.Stocks * ROW_HEIGHT + 44),
	BackgroundColor3 = Color3.fromRGB(20, 24, 32),
	BackgroundTransparency = 0.05,
	Visible = false,
	ZIndex = 20,
	Parent = Ui.gui,
}, { Ui.corner(12), Ui.padding(12), Ui.stroke(Color3.fromRGB(90, 160, 255), 2), Ui.make("UIScale", {}) })

local titleText = text({ Size = UDim2.new(1, 0, 0, 26), TextSize = 21, Text = "📈 화장실 증권", ZIndex = 21, Parent = frame })
local balanceText = text({
	Size = UDim2.new(1, 0, 0, 26),
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = Color3.fromRGB(255, 220, 120),
	ZIndex = 21,
	Parent = frame,
})
local newsText = text({
	Position = UDim2.fromOffset(0, 30),
	Size = UDim2.new(1, 0, 0, 40),
	TextSize = 15,
	TextWrapped = true,
	TextColor3 = Color3.fromRGB(255, 230, 150),
	ZIndex = 21,
	Parent = frame,
})

local function tradeButton(parent: Instance, x: number, label: string, onClick: () -> ()): TextButton
	local b = Ui.button({
		Position = UDim2.new(1, x, 0, 52),
		Size = UDim2.fromOffset(68, 28),
		Text = label,
		TextSize = 14,
		ZIndex = 22,
		Parent = parent,
	})
	b.Activated:Connect(onClick)
	return b
end

local messageText -- 아래에서 만들어요

local function trade(stockId: string, quantity: number)
	local ok, message = Remotes.TradeStock:InvokeServer(stockId, quantity)
	messageText.Text = message
	messageText.TextColor3 = if ok then Color3.fromRGB(140, 230, 160) else Color3.fromRGB(255, 140, 130)
end

local rows = {}
for i, stock in SalaryConfig.Stocks do
	local row = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 76 + (i - 1) * ROW_HEIGHT),
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT - 6),
		BackgroundColor3 = Color3.fromRGB(34, 40, 52),
		ZIndex = 21,
		Parent = frame,
	}, { Ui.corner(8), Ui.padding(6) })

	local nameText = text({ Size = UDim2.fromOffset(170, 22), TextSize = 16, Text = `{stock.emoji} {stock.name}`, ZIndex = 22, Parent = row })
	local priceText = text({ Position = UDim2.fromOffset(0, 22), Size = UDim2.fromOffset(170, 22), TextSize = 18, ZIndex = 22, Parent = row })
	local ownedText = text({
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.fromOffset(170, 18),
		TextSize = 13,
		TextColor3 = Color3.fromRGB(190, 195, 210),
		ZIndex = 22,
		Parent = row,
	})

	-- 미니 그래프 (최근 가격 막대)
	local chart = Ui.make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 2),
		Size = UDim2.fromOffset(200, 44),
		BackgroundTransparency = 1,
		ZIndex = 22,
		Parent = row,
	})
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

	tradeButton(row, -216, "+1주", function()
		trade(stock.id, 1)
	end)
	tradeButton(row, -144, "+10주", function()
		trade(stock.id, 10)
	end)
	tradeButton(row, -72, "전부 팔기", function()
		trade(stock.id, -999999)
	end)

	rows[stock.id] = { name = nameText, price = priceText, owned = ownedText, bars = bars }
end

messageText = text({
	Position = UDim2.new(0, 0, 1, -40),
	Size = UDim2.new(1, 0, 0, 20),
	TextSize = 14,
	Text = "",
	ZIndex = 21,
	Parent = frame,
})
local footerText = text({
	Position = UDim2.new(0, 0, 1, -18),
	Size = UDim2.new(1, 0, 0, 18),
	TextSize = 13,
	TextColor3 = Color3.fromRGB(170, 175, 190),
	ZIndex = 21,
	Parent = frame,
})

---------------------------------------------------------------------------
-- 갱신
---------------------------------------------------------------------------
local function refresh()
	local prices = decode("StockPrices")
	local history = decode("StockHistory")
	local holdings = decodePlayer("StockHoldings")
	local costs = decodePlayer("StockCost")

	balanceText.Text = `🏦 {comma(player:GetAttribute("TotalMoney") or 0)}원`
	newsText.Text = ReplicatedStorage:GetAttribute("StockNews") or ""

	for _, stock in SalaryConfig.Stocks do
		local row = rows[stock.id]
		local price = prices[stock.id] or stock.price
		local points = history[stock.id] or { price }
		local first = points[1] or price
		local change = if first > 0 then (price - first) / first * 100 else 0
		local color = if change >= 0 then UP else DOWN
		row.price.Text = `{comma(price)}원  {if change >= 0 then "▲" else "▼"} {string.format("%.1f", math.abs(change))}%`
		row.price.TextColor3 = color

		local owned = holdings[stock.id] or 0
		if owned > 0 then
			local profit = price * owned - (costs[stock.id] or 0)
			row.owned.Text = `보유 {owned}주 · 평가 {if profit >= 0 then "+" else ""}{comma(profit)}원`
		else
			row.owned.Text = "보유 없음"
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

	local total = player:GetAttribute("StockProfitTotal") or 0
	footerText.Text = `누적 실현 손익 {if total >= 0 then "+" else ""}{comma(total)}원 · ⚠️ 오래 있으면 자리 비움이 티 나요!`
end

-- 화면이 작으면 창을 줄여요
local function fit()
	local camera = workspace.CurrentCamera
	local scale = frame:FindFirstChildOfClass("UIScale")
	if camera and scale then
		scale.Scale = math.clamp((camera.ViewportSize.Y - 140) / frame.Size.Y.Offset, 0.5, 1)
	end
end

function StockPanel.start()
	fit()
	task.spawn(function()
		while true do
			local onToilet = player:GetAttribute("OnToilet") == true
			if onToilet and not frame.Visible then
				fit()
				messageText.Text = "🚽 변기에 앉았다… 이제 시장을 볼 시간!"
				messageText.TextColor3 = Color3.fromRGB(200, 200, 210)
			end
			frame.Visible = onToilet
			if onToilet then
				refresh()
			end
			task.wait(0.25)
		end
	end)
	titleText.Text = "📈 화장실 증권 (게임 속 가짜 주식)"
end

return StockPanel
