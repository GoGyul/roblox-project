-- 📈 화장실 주식 시장 (게임 속 가짜 회사)
--
-- 2초마다 회사마다 주가가 조금씩 오르내리고, 가끔 뉴스가 터지면 크게 움직여요.
-- 가격·최근 흐름·뉴스는 ReplicatedStorage 속성으로 클라이언트 주식 창에 보여 줘요.
-- 실제로 사고파는 건 Employees가 이 시장 가격을 보고 처리해요.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)

local StockMarket = {}

local HISTORY_LENGTH = 30 -- 그래프에 보여 줄 최근 가격 개수

-- 평균 0, 대부분 -1~1 사이인 랜덤 값 (자연스러운 오르내림)
local function wobble(): number
	return (math.random() + math.random() + math.random() - 1.5) / 1.5
end

function StockMarket.start()
	local prices: { [string]: number } = {}
	local history: { [string]: { number } } = {}
	local trend: { [string]: number } = {} -- 뉴스 뒤 몇 틱 동안 이어지는 흐름

	for _, stock in SalaryConfig.Stocks do
		prices[stock.id] = stock.price
		history[stock.id] = { stock.price }
		trend[stock.id] = 0
	end

	local function publish(news: string?)
		local rounded = {}
		for id, price in prices do
			rounded[id] = math.floor(price + 0.5)
		end
		ReplicatedStorage:SetAttribute("StockPrices", HttpService:JSONEncode(rounded))
		ReplicatedStorage:SetAttribute("StockHistory", HttpService:JSONEncode(history))
		if news then
			ReplicatedStorage:SetAttribute("StockNews", news)
		end
	end

	local function tick()
		local news: string? = nil
		-- 뉴스 (가끔 한 회사가 크게 움직여요)
		if math.random() < SalaryConfig.STOCK_NEWS_CHANCE then
			local stock = SalaryConfig.Stocks[math.random(1, #SalaryConfig.Stocks)]
			local good = math.random() < 0.5
			local list = if good then stock.good else stock.bad
			local jump = (0.12 + math.random() * 0.18) * (if good then 1 else -1)
			prices[stock.id] *= 1 + jump
			trend[stock.id] = jump / 6
			news = `{if good then "📈" else "📉"} {list[math.random(1, #list)]}`
		end

		for _, stock in SalaryConfig.Stocks do
			local id = stock.id
			-- 시작 가격 쪽으로 아주 약하게 끌어당겨서 너무 멀리 가지 않게 해요
			local pull = (stock.price - prices[id]) / stock.price * 0.01
			prices[id] *= 1 + wobble() * stock.volatility + trend[id] + pull
			prices[id] = math.max(prices[id], stock.price * 0.1) -- 상장폐지는 없어요 :)
			trend[id] *= 0.7
			table.insert(history[id], math.floor(prices[id] + 0.5))
			if #history[id] > HISTORY_LENGTH then
				table.remove(history[id], 1)
			end
		end
		publish(news)
	end

	publish("📊 화장실 증권 개장! 변기에 앉아 거래해 보세요.")
	task.spawn(function()
		while true do
			task.wait(SalaryConfig.STOCK_TICK)
			tick()
		end
	end)

	return {
		-- 지금 가격 (정수)
		price = function(stockId: string): number?
			local price = prices[stockId]
			return if price then math.floor(price + 0.5) else nil
		end,
	}
end

return StockMarket
