-- 🏙️ 눈치 스트리트 가게: 사장님 NPC + [E] 주문하기 → 화면에 메뉴 창
-- 실제 구매(돈 빼기, 효과 주기)는 Employees.buyStreet가 해요.
-- 🛡️ 서버가 "그 가게 계산대 근처에 있는지"를 다시 확인해요 (멀리서 몰래 사는 걸 막아요).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)
local Npc = require(script.Parent.Npc)

local Street = {}

local ORDER_RANGE = 12 -- 계산대에서 이 거리 안이어야 살 수 있어요
local allowBuy = RateLimit.new(0.3)

local CLERK_LOOKS = {
	store = { skin = Color3.fromRGB(235, 205, 180), shirt = Color3.fromRGB(230, 120, 60), pants = Color3.fromRGB(60, 50, 50) },
	cafe = { skin = Color3.fromRGB(235, 200, 170), shirt = Color3.fromRGB(40, 120, 80), pants = Color3.fromRGB(50, 40, 35) },
	dessert = { skin = Color3.fromRGB(240, 210, 185), shirt = Color3.fromRGB(250, 190, 210), pants = Color3.fromRGB(240, 240, 240) },
	cafe1f = { skin = Color3.fromRGB(232, 200, 172), shirt = Color3.fromRGB(96, 70, 52), pants = Color3.fromRGB(50, 46, 44) },
	bunsik = { skin = Color3.fromRGB(236, 204, 178), shirt = Color3.fromRGB(196, 70, 60), pants = Color3.fromRGB(60, 56, 60) },
	pharmacy = { skin = Color3.fromRGB(236, 206, 182), shirt = Color3.fromRGB(246, 248, 246), pants = Color3.fromRGB(58, 148, 112) },
	truck = { skin = Color3.fromRGB(226, 190, 160), shirt = Color3.fromRGB(190, 108, 92), pants = Color3.fromRGB(52, 56, 62) },
}
local GREETINGS = {
	store = { "어서 와요~ 부장님 선물 찾아요?", "홍삼이 제일 잘 먹혀~ 호호", "꽃다발도 있어요!" },
	cafe = { "어서 오세요~ 오늘도 출근 고생 많으세요!", "근무 중이세요? 빨리 해 드릴게요 😉", "아아 한 잔 어떠세요?" },
	dessert = { "갓 구운 크로플 있어요~", "회사에 몰래 가져가시게요? 포장해 드릴게요!", "달콤한 거 드시고 힘내세요!" },
	cafe1f = { "어서 와요~ 믹스커피가 제일 잘 나가요!", "오늘도 출근했네, 힘내요!", "사무실에서 몰래 마시게? 뚜껑 닫아 줄게요." },
	pharmacy = { "어디가 불편하세요?", "수면제요? 잠이 안 오시나 봐요… 하루 한 알만 드세요.", "커피랑 같이 드시면 안 돼요~ (찡긋)" },
	truck = { "점심엔 역시 타코죠!", "닭강정 방금 튀겼어요~", `{SalaryConfig.clockText(SalaryConfig.LUNCH_START)}부터 {SalaryConfig.clockText(SalaryConfig.LUNCH_END)}까지만 팔아요!` },
	bunsik = { "어서 와~ 떡볶이 방금 했어!", "회사에 들고 가서 몰래 먹게? 냄새 조심해~", "김밥은 금방 말아 줄게!" },
}

-- buy(player, shopId, itemId) → (성공 여부, 메시지)
function Street.start(office, remotes, buy: (Player, string, string) -> (boolean, string))
	if next(office.shops) == nil then
		return -- 눈치물산에만 거리가 있어요
	end

	for key, spot in office.shops do
		local shopId = spot.shopId or key -- (같은 가게의 2호점은 shopId로 원래 가게를 가리켜요)
		local shop = SalaryConfig.StreetShops[shopId]
		if not shop then
			continue
		end
		-- 사장님 (계산대 뒤에 가만히 서 있어요)
		local clerk = Npc.create(shop.clerk, CLERK_LOOKS[shopId] or CLERK_LOOKS.cafe, office.folder)
		clerk:PivotTo(CFrame.lookAt(spot.clerkSpot + Vector3.new(0, 3, 0), spot.clerkSpot + Vector3.new(0, 3, 0) + (spot.clerkLook or Vector3.new(0, 0, 1)) * 5))
		local clerkRoot = clerk:FindFirstChild("HumanoidRootPart") :: BasePart
		clerkRoot.Anchored = true
		Npc.setStatus(clerk, utf8.char(utf8.codepoint(shop.name, 1))) -- 가게 이름 맨 앞 이모지

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "주문하기"
		prompt.ObjectText = shop.name
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = spot.counter
		prompt.Triggered:Connect(function(player)
			local greetings = GREETINGS[shopId]
			if greetings then
				Npc.say(clerk, greetings[math.random(1, #greetings)], 3)
			end
			remotes.StreetMenu:FireClient(player, shopId)
		end)
	end

	remotes.BuyStreet.OnServerInvoke = function(player: Player, shopId: any, itemId: any): (boolean, string)
		if not allowBuy(player) then
			return false, "천천히 주문해 주세요."
		end
		if typeof(shopId) ~= "string" or typeof(itemId) ~= "string" then
			return false, "잘못된 주문이에요."
		end
		if not SalaryConfig.getStreetItem(shopId, itemId) then
			return false, "없는 메뉴예요."
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local close = false
		for key, spot in office.shops do -- (2호점이 있는 가게는 어느 계산대든)
			if (spot.shopId or key) == shopId and root and (root.Position - spot.counter.Position).Magnitude <= ORDER_RANGE then
				close = true
			end
		end
		if not close then
			return false, "가게 계산대 앞에서 주문해 주세요!"
		end
		return buy(player, shopId, itemId)
	end
end

return Street
