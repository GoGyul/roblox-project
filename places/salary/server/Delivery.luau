-- 📦 택배 보관함: 🛒 쇼핑몰에서 주문한 물건이 다음 근무일에 출입문 근처 보관함에 와요
--   1) 보관함 상자 [E] "택배 받기" → 상자를 들고 걸어요 (택배 대란처럼 느려져요, 💪 근력이 도와줘요 · 한 번에 하나)
--   2) 내 자리에 앉거나 내 책상 [E] "📦 택배 뜯기" → 물건 도착! (꾸미기 = 바로 장착 / 장비 = 한 단계 업)
--   들고 있다가 나가거나 퇴근하면 상자는 다시 보관함으로 돌아가요 (주문은 그대로, 손해 없음)
--   주문·도착 기록은 Employees(profile.orders)가 갖고 있고, 여기서는 상자 모양과 들기·뜯기만 해요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)

local Delivery = {}

local BOX_SIZE = Vector3.new(1.4, 1.2, 1.2)
local BOX_COLOR = Color3.fromRGB(190, 140, 90)

-- 주문 이름 (상자 위 글씨용)
local function orderLabel(order): string
	if order.kind == "decor" then
		local option = SalaryConfig.getDecor(order.itemId)
		if option then
			return `{option.emoji} {option.name}`
		end
	elseif order.kind == "upgrade" then
		local upgrade = SalaryConfig.getDeskUpgrade(order.itemId)
		if upgrade then
			return `{upgrade.emoji} {upgrade.name}`
		end
	end
	return "📦 택배"
end

-- 상자 하나 (보관함용 / 들고 다니는 용)
local function makeBox(name: string, cframe: CFrame): BasePart
	local box = Instance.new("Part")
	box.Name = name
	box.CFrame = cframe
	box.Size = BOX_SIZE
	box.Color = BOX_COLOR
	box.Material = Enum.Material.Cardboard
	box.CanCollide = false
	box.CanTouch = false
	local tape = Instance.new("Part")
	tape.Name = "Tape"
	tape.Size = Vector3.new(BOX_SIZE.X + 0.04, 0.25, BOX_SIZE.Z + 0.04)
	tape.Color = Color3.fromRGB(220, 200, 150)
	tape.CanCollide = false
	tape.CanTouch = false
	tape.CanQuery = false
	tape.Massless = true
	tape.CFrame = cframe -- (상자 가운데를 두르는 테이프)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = box
	weld.Part1 = tape
	weld.Parent = tape
	tape.Parent = box
	return box
end

-- office: OfficeBuilder 결과 (deliveryShelf) / api: Employees.deliveryApi
function Delivery.start(office, dayCycle, remotes, api)
	local shelf = office.deliveryShelf
	if not shelf then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "DeliveryBoxes"
	folder.Parent = office.folder

	-- 놓을 자리: 선반 6칸 + 모자라면 선반 앞 바닥에 3칸씩 두 줄
	local spots = table.clone(shelf.spots)
	for row = 0, 1 do
		for _, dx in { -1.9, 0, 1.9 } do
			table.insert(spots, shelf.front + Vector3.new(dx, BOX_SIZE.Y / 2, -1.4 + row * 1.6))
		end
	end

	local carrying: { [Player]: { orderId: number, held: BasePart?, deskPrompt: ProximityPrompt? } } = {}

	local function setSpeed(player: Player, speed: number)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = speed
		end
	end

	local startCarry: (Player, number) -> () -- 아래에서 정의

	-- 📦 보관함 상자 다시 놓기 (누가 받거나·도착하거나·나가면 전부 새로)
	local function layout()
		folder:ClearAllChildren()
		local index = 0
		local players = Players:GetPlayers()
		table.sort(players, function(a, b)
			return a.UserId < b.UserId
		end)
		for _, player in players do
			local d = api.get(player)
			if not d then
				continue
			end
			local held = carrying[player]
			for _, order in d.profile.orders do
				if order.arrived ~= true or (held and held.orderId == order.id) then
					continue
				end
				index += 1
				local spot = spots[index]
				if not spot then
					return -- 자리가 꽉 찼어요 (먼저 받은 사람이 생기면 다음 상자가 나와요)
				end
				local box = makeBox("DeliveryBox", CFrame.new(spot))
				box.Anchored = true
				;(box:FindFirstChild("Tape") :: BasePart).Anchored = true
				local tag = Instance.new("BillboardGui")
				tag.Size = UDim2.fromOffset(120, 22)
				tag.StudsOffset = Vector3.new(0, 1.1, 0)
				tag.MaxDistance = 30
				tag.Parent = box
				local label = Instance.new("TextLabel")
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundTransparency = 1
				label.TextScaled = true
				label.Font = Enum.Font.GothamBold
				label.TextColor3 = Color3.fromRGB(255, 220, 120)
				label.TextStrokeTransparency = 0.3
				label.Text = `📦 {player.DisplayName}`
				label.Parent = tag
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "택배 받기"
				prompt.ObjectText = orderLabel(order)
				prompt.MaxActivationDistance = 7
				prompt.RequiresLineOfSight = false
				prompt:SetAttribute("OnlyFor", player.UserId) -- 내 상자에만 [E]가 떠요 (화면이 숨겨요)
				prompt.Parent = box
				local orderId = order.id
				prompt.Triggered:Connect(function(who)
					if who == player then
						startCarry(player, orderId)
					end
				end)
				box.Parent = folder
			end
		end
	end

	-- 들고 있던 상자 내려놓기 (뜯었거나 · 취소)
	local function stopCarry(player: Player)
		local c = carrying[player]
		if not c then
			return
		end
		carrying[player] = nil
		if c.held then
			c.held:Destroy()
		end
		if c.deskPrompt then
			c.deskPrompt:Destroy()
		end
		player:SetAttribute("CarryingPackage", nil)
		setSpeed(player, SalaryConfig.walkSpeed(player, 16)) -- ⚡ 민첩성 보너스를 넣은 평소 속도로
	end

	-- 📦 택배 뜯기 → 물건 도착!
	local function unbox(player: Player)
		local c = carrying[player]
		local d = api.get(player)
		if not c or not d then
			return
		end
		local orderId = c.orderId
		stopCarry(player)
		local label = api.unbox(player, d, orderId)
		if label then
			remotes.Unboxed:FireClient(player, label)
		end
		layout()
	end

	startCarry = function(player: Player, orderId: number)
		local d = api.get(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not d or not root then
			return
		end
		if carrying[player] then
			api.notify(player, "📦 한 번에 하나만! 먼저 내 자리에서 뜯어요")
			return
		end
		local order = nil
		for _, o in d.profile.orders do
			if o.id == orderId and o.arrived == true then
				order = o
			end
		end
		if not order then
			return
		end
		-- 두 손으로 앞에 들어요
		local held = makeBox("HeldPackage", root.CFrame * CFrame.new(0, 0.2, -1.3))
		held.Massless = true
		held.CanQuery = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = held
		weld.Parent = held
		held.Parent = character
		-- 내 책상 [E] 📦 택배 뜯기 (앉아도 저절로 뜯어요)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "📦 택배 뜯기"
		prompt.ObjectText = orderLabel(order)
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("OnlyFor", player.UserId)
		prompt.Parent = d.desk.top
		prompt.Triggered:Connect(function(who)
			if who == player then
				unbox(player)
			end
		end)
		carrying[player] = { orderId = orderId, held = held, deskPrompt = prompt }
		player:SetAttribute("CarryingPackage", orderLabel(order))
		-- 💪 근력: 들고 느려지는 정도가 줄어요 · ⚡ 민첩성 보너스도 곱해요
		setSpeed(player, SalaryConfig.carrySpeed(player, SalaryConfig.BOX_SPEEDS[1]))
		api.notify(player, "📦 받았어요! 내 자리로 가서 뜯어요")
		layout()
	end

	-- 🚚 도착·새 주문 → 보관함 다시 놓기
	api.hooks.ordersChanged = function(_player: Player, _d)
		layout()
	end

	-- 들고 있다가 캐릭터가 사라지거나(리셋) 나가면 → 상자는 보관함으로
	local function watch(player: Player)
		player.CharacterRemoving:Connect(function()
			local c = carrying[player]
			if c then
				carrying[player] = nil -- (들고 있던 상자는 캐릭터와 같이 사라져요)
				if c.deskPrompt then
					c.deskPrompt:Destroy()
				end
				player:SetAttribute("CarryingPackage", nil)
				layout()
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		local c = carrying[player]
		carrying[player] = nil
		if c and c.deskPrompt then
			c.deskPrompt:Destroy()
		end
		task.delay(0.5, layout) -- (Employees가 정리한 뒤에)
	end)

	-- 🌙 퇴근하면 들고 있던 상자는 보관함으로 (주문은 그대로)
	dayCycle:on("dayEnd", function()
		local any = false
		for player in carrying do
			stopCarry(player)
			any = true
		end
		if any then
			layout()
		end
	end)

	-- 🪑 상자를 들고 내 자리에 앉으면 저절로 뜯어요
	task.spawn(function()
		while true do
			for player in carrying do
				if api.isSeated(player) then
					unbox(player)
				end
			end
			task.wait(0.3)
		end
	end)

	layout()
end

return Delivery
