-- 🐦 옥상 비둘기 친구
--   🍪 모이 통 [E] → 🎒 과자 고르기 → 하늘에서 비둘기들이 내려와 콕콕 쪼아 먹어요 (PIGEON_STAY초)
--   ⚠️ 👮 옥상 경비원이 가까이 다가오면 먼저 놀라서 푸드덕! (살아 있는 근접 알람)
--   💕 친밀도가 오를수록 더 많이, 더 희귀한 비둘기가 와요 → 📒 관찰 노트에 기록
--   🎁 비둘기의 보은: 친해지면 가끔 비둘기가 선물을 물어 와서 모이 통 근처에 떨어뜨려요 → [E] 줍기 (나만!)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local Build = require(ReplicatedStorage.Shared.Build)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)

local allowFeed = RateLimit.new(0.5)

local RoofPigeons = {}

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

local RAINBOW = {
	Color3.fromRGB(255, 110, 110),
	Color3.fromRGB(255, 190, 90),
	Color3.fromRGB(250, 240, 110),
	Color3.fromRGB(120, 220, 130),
	Color3.fromRGB(110, 180, 255),
	Color3.fromRGB(190, 130, 240),
}

type Pigeon = { model: Model, root: BasePart, kind: any, alive: boolean }

-- 비둘기 한 마리 만들기 (부품을 몸통에 붙여서 몸통만 움직이면 다 같이 움직여요)
local function makePigeon(parent: Instance, kind: any, cframe: CFrame): Pigeon
	local s = kind.scale or 1
	local model = Instance.new("Model")
	model.Name = "Pigeon"
	local function part(name: string, size: Vector3, offset: CFrame, color: Color3, shape: Enum.PartType?): BasePart
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * s
		p.Shape = shape or Enum.PartType.Block
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CFrame = cframe * CFrame.new(offset.Position * s) * offset.Rotation
		p.Parent = model
		return p
	end
	local body = part("Body", Vector3.new(1.1, 0.9, 1.5), CFrame.new(), kind.body, Enum.PartType.Ball)
	body.Anchored = true
	local head = part("Head", Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, 0.5, -0.7), kind.head, Enum.PartType.Ball)
	local beak = part("Beak", Vector3.new(0.18, 0.15, 0.32), CFrame.new(0, 0.45, -1.12), Color3.fromRGB(240, 160, 60))
	local wingColor = kind.head:Lerp(Color3.new(0, 0, 0), 0.15)
	local left = part("WingL", Vector3.new(0.15, 0.55, 1.0), CFrame.new(-0.55, 0.05, 0.05), wingColor)
	local right = part("WingR", Vector3.new(0.15, 0.55, 1.0), CFrame.new(0.55, 0.05, 0.05), wingColor)
	local tail = part("Tail", Vector3.new(0.6, 0.12, 0.55), CFrame.new(0, 0.15, 0.9) * CFrame.Angles(math.rad(15), 0, 0), wingColor)
	local eyeL = part("EyeL", Vector3.new(0.12, 0.12, 0.12), CFrame.new(-0.22, 0.62, -0.95), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local eyeR = part("EyeR", Vector3.new(0.12, 0.12, 0.12), CFrame.new(0.22, 0.62, -0.95), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	for _, p in { head, beak, left, right, tail, eyeL, eyeR } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = p
		weld.Parent = p
	end
	if kind.crown then
		local crown = part("Crown", Vector3.new(0.5, 0.3, 0.5), CFrame.new(0, 0.95, -0.7), Color3.fromRGB(255, 205, 60))
		crown.Material = Enum.Material.Neon
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = crown
		weld.Parent = crown
	end
	-- 희귀 비둘기는 머리 위에 표시
	if kind.rarity == "rare" or kind.rarity == "legend" then
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(70, 22)
		billboard.StudsOffset = Vector3.new(0, 1.8 * s, 0)
		billboard.MaxDistance = 45
		billboard.Parent = body
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = `{kind.emoji} {kind.name}`
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = if kind.rarity == "legend" then Color3.fromRGB(255, 215, 90) else Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.3
		label.Parent = billboard
	end
	model.PrimaryPart = body
	model.Parent = parent
	return { model = model, root = body, kind = kind, alive = true }
end

-- hooks:
--   snackCount(player, 과자 ID) → 🎒에 있는 개수
--   useSnack(player, 과자 ID) → 🎒에서 하나 꺼냈나 (하루 한 번)
--   fedToday(player) → 오늘 이미 과자를 줬나
--   fed(player, 친밀도 점수) → 친밀도(점수)
--   seen(player, 비둘기 ID) → 처음 만났나
--   giftRoll(player, 친밀도 단계, 과자 ID) → 🎁 물어 올 선물 ID (안 오면 nil)
--   giftMissed(player) → 🎁 못 받은 선물 (오늘 횟수 돌려주기)
--   giftPicked(player, 선물 ID) → 🎁 주운 결과 메시지
--   guardNear() → 경비원이 모이 통 가까이 있나
--   onRoof(position) → 옥상 위인가
--   workDay() → 지금 근무일 (날이 바뀌면 떨어진 선물이 사라져요)
function RoofPigeons.start(folder: Instance, spot: Vector3, remotes, hooks)
	local pigeonFolder = Instance.new("Folder")
	pigeonFolder.Name = "Pigeons"
	pigeonFolder.Parent = folder
	local B = Build.new(folder, Vector3.zero)

	-- 🍞 모이 통 + 📒 관찰 노트 (작은 나무 상자 위)
	B:part(Vector3.new(2.4, 1.6, 1.6), spot + Vector3.new(0, 0.8, 4.5), { Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.WoodPlanks })
	local feeder = B:part(Vector3.new(1.4, 0.9, 1), spot + Vector3.new(-0.4, 2.05, 4.5), { Name = "PigeonFeeder", Color = Color3.fromRGB(240, 210, 140), Material = Enum.Material.Fabric })
	local feederSign = B:part(Vector3.new(2.4, 0.9, 0.15), spot + Vector3.new(0, 2.4, 5.35), { Color = Color3.fromRGB(60, 45, 35) })
	Build.surfaceText(feederSign, Enum.NormalId.Front, "🍪 비둘기 과자", { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 230, 170) })
	Build.surfaceText(feederSign, Enum.NormalId.Back, "🍪 비둘기 과자", { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 230, 170) })
	local notebook = B:part(Vector3.new(0.8, 0.12, 1), spot + Vector3.new(0.75, 1.66, 4.5), { Name = "PigeonBook", Color = Color3.fromRGB(90, 160, 110) })

	local feedPrompt = Instance.new("ProximityPrompt")
	feedPrompt.ActionText = "과자 뿌리기 (🎒)"
	feedPrompt.ObjectText = "🍪 비둘기 모이 통"
	feedPrompt.HoldDuration = 0.5
	feedPrompt.MaxActivationDistance = 7
	feedPrompt.RequiresLineOfSight = false
	feedPrompt.Parent = feeder

	local bookPrompt = Instance.new("ProximityPrompt")
	bookPrompt.ActionText = "관찰 노트 보기"
	bookPrompt.ObjectText = "📒 비둘기"
	bookPrompt.KeyboardKeyCode = Enum.KeyCode.F
	bookPrompt.MaxActivationDistance = 7
	bookPrompt.RequiresLineOfSight = false
	bookPrompt.Parent = notebook
	bookPrompt.Triggered:Connect(function(player)
		remotes.PigeonBook:FireClient(player, notebook.Position) -- 🚪 멀어지면 노트가 닫혀요
	end)

	local flock: { Pigeon } = {}
	local seeds: { BasePart } = {}
	local leaveAt = 0

	local function roofPlayers(): { Player }
		local list = {}
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and hooks.onRoof(root.Position) then
				table.insert(list, player)
			end
		end
		return list
	end

	local function clearSeeds()
		for _, seed in seeds do
			seed:Destroy()
		end
		table.clear(seeds)
	end

	local function scatterSeeds()
		clearSeeds()
		for _ = 1, 14 do
			local angle = math.random() * math.pi * 2
			local radius = math.random() * 3.5
			local seed = B:part(Vector3.new(0.18, 0.1, 0.18), spot + Vector3.new(math.cos(angle) * radius, 0.06, math.sin(angle) * radius), {
				Color = Color3.fromRGB(235, 205, 120),
				CanCollide = false,
				CanQuery = false,
			})
			table.insert(seeds, seed)
		end
	end

	-- 날아가기 (calm: 배불러서 천천히 / 아니면 놀라서 푸드덕)
	local function flyAway(pigeon: Pigeon, calm: boolean)
		if not pigeon.alive then
			return
		end
		pigeon.alive = false
		local root = pigeon.root
		local direction = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
		if direction.Magnitude < 0.1 then
			direction = Vector3.new(1, 0, 0)
		end
		direction = direction.Unit
		local target = root.Position + direction * (if calm then 45 else 60) + Vector3.new(0, if calm then 25 else 40, 0)
		local duration = if calm then 3.2 else 1.8 + math.random() * 0.6
		local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.lookAt(target, target + direction) * CFrame.Angles(math.rad(-20), 0, 0),
		})
		tween:Play()
		-- 날개 파닥파닥
		task.spawn(function()
			local wings = { pigeon.model:FindFirstChild("WingL"), pigeon.model:FindFirstChild("WingR") }
			local up = true
			local finish = os.clock() + duration
			while os.clock() < finish and pigeon.model.Parent do
				for i, wing in wings do
					if wing then
						local weld = wing:FindFirstChildOfClass("WeldConstraint")
						if weld then
							weld.Enabled = false
							wing.CFrame = root.CFrame * CFrame.new((if i == 1 then -0.7 else 0.7) * (pigeon.kind.scale or 1), if up then 0.35 else -0.1, 0) * CFrame.Angles(0, 0, math.rad((if i == 1 then 1 else -1) * (if up then 50 else -20)))
							wing.Anchored = true
						end
					end
				end
				up = not up
				task.wait(0.09)
			end
		end)
		task.delay(duration + 0.1, function()
			pigeon.model:Destroy()
		end)
	end

	-- 콕콕 쪼고, 종종걸음 (살아 있는 동안 반복)
	local function liveLoop(pigeon: Pigeon)
		local root = pigeon.root
		local hue = 1
		while pigeon.alive and pigeon.model.Parent do
			if pigeon.kind.rainbow then
				hue = hue % #RAINBOW + 1
				root.Color = RAINBOW[hue]
			end
			if math.random() < 0.55 then
				-- 콕콕
				local base = root.CFrame
				for _ = 1, math.random(1, 3) do
					if not pigeon.alive then
						return
					end
					TweenService:Create(root, TweenInfo.new(0.12), { CFrame = base * CFrame.Angles(math.rad(-30), 0, 0) }):Play()
					task.wait(0.14)
					if not pigeon.alive then
						return
					end
					TweenService:Create(root, TweenInfo.new(0.12), { CFrame = base }):Play()
					task.wait(0.16)
				end
			else
				-- 모이 근처로 종종종
				local angle = math.random() * math.pi * 2
				local radius = 1 + math.random() * 3.5
				local scale = pigeon.kind.scale or 1
				local target = spot + Vector3.new(math.cos(angle) * radius, 0.45 * scale, math.sin(angle) * radius)
				local look = target - root.Position
				local flat = Vector3.new(look.X, 0, look.Z)
				if flat.Magnitude > 0.1 then
					TweenService:Create(root, TweenInfo.new(0.45, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(target, target + flat.Unit) }):Play()
				end
				task.wait(0.5)
			end
			task.wait(0.3 + math.random() * 0.9)
		end
	end

	-- 하늘에서 내려앉기
	local generation = 0 -- 모두 날아갈 때마다 +1 (늦게 내려오던 비둘기는 취소)
	local function land(kind: any, myGeneration: number?)
		if myGeneration and myGeneration ~= generation then
			return -- 그사이 다들 날아갔어요
		end
		local scale = kind.scale or 1
		local angle = math.random() * math.pi * 2
		local radius = 1 + math.random() * 3.5
		local ground = spot + Vector3.new(math.cos(angle) * radius, 0.45 * scale, math.sin(angle) * radius)
		local from = ground + Vector3.new(math.cos(angle) * 35, 28, math.sin(angle) * 35)
		local facing = (spot - ground) * Vector3.new(1, 0, 1)
		if facing.Magnitude < 0.1 then
			facing = Vector3.new(0, 0, -1)
		end
		local pigeon = makePigeon(pigeonFolder, kind, CFrame.lookAt(from, ground))
		table.insert(flock, pigeon)
		local tween = TweenService:Create(pigeon.root, TweenInfo.new(1.6 + math.random() * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.lookAt(ground, ground + facing.Unit),
		})
		tween:Play()
		tween.Completed:Once(function()
			task.spawn(liveLoop, pigeon)
		end)
	end

	-- 친밀도 단계에 맞춰 비둘기 종류 뽑기 (luck: 🍪 좋은 과자일수록 희귀 비둘기가 조금 더 잘 와요)
	local function rollKind(level: number, luck: number): any
		local total = 0
		local pool = {}
		for _, kind in SalaryConfig.Pigeons do
			if level >= kind.minLevel then
				local weight = kind.weight + kind.perLevel * (level - 1 + luck)
				if weight > 0 then
					total += weight
					table.insert(pool, { kind = kind, weight = weight })
				end
			end
		end
		local roll = math.random() * total
		for _, entry in pool do
			roll -= entry.weight
			if roll <= 0 then
				return entry.kind
			end
		end
		return SalaryConfig.Pigeons[1]
	end

	local function aliveCount(): number
		local count = 0
		for i = #flock, 1, -1 do
			if not flock[i].alive then
				table.remove(flock, i)
			else
				count += 1
			end
		end
		return count
	end

	-- 모두 날아가요
	local function scatter(calm: boolean)
		generation += 1
		for _, pigeon in flock do
			flyAway(pigeon, calm)
		end
		table.clear(flock)
		clearSeeds()
		leaveAt = 0
	end

	---------------------------------------------------------------- 🎁 비둘기의 보은
	local gifts: { [Player]: BasePart } = {} -- 떨어져 있는 선물 (한 사람당 하나)
	local pendingGift: { [Player]: boolean } = {} -- 선물을 물고 오는 중 (한 사람당 하나)

	local function playerOnRoof(player: Player): boolean
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return root ~= nil and hooks.onRoof(root.Position)
	end

	-- 🎁 선물 상자 떨어뜨리기 → [E] 줍기 (주인만)
	local function dropGift(owner: Player, treasureId: string, at: Vector3)
		local treasure = SalaryConfig.getPigeonTreasure(treasureId)
		if not treasure then
			pendingGift[owner] = nil
			return
		end
		local box = B:part(Vector3.new(0.9, 0.9, 0.9), at + Vector3.new(0, 6, 0), {
			Name = "PigeonGift",
			Color = if treasure.kind == "valuable" then Color3.fromRGB(255, 205, 80) else Color3.fromRGB(240, 110, 120),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
		local ribbon = B:part(Vector3.new(0.95, 0.95, 0.2), at + Vector3.new(0, 6, 0), { Color = Color3.fromRGB(255, 255, 255), CanCollide = false, CanQuery = false, Massless = true, Parent = box }) -- 🎀 리본 (상자와 같이 사라져요)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = box
		weld.Part1 = ribbon
		weld.Parent = ribbon
		ribbon.Anchored = false
		gifts[owner] = box
		-- 하늘에서 툭!
		TweenService:Create(box, TweenInfo.new(0.7, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { CFrame = CFrame.new(at) * CFrame.Angles(0, math.rad(math.random(0, 90)), 0) }):Play()
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(150, 26)
		billboard.StudsOffset = Vector3.new(0, 1.4, 0)
		billboard.MaxDistance = 40
		billboard.Parent = box
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = `🎁 {owner.DisplayName}의 선물`
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.3
		label.Parent = billboard
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "줍기"
		prompt.ObjectText = "🎁 비둘기 선물"
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.Parent = box
		local picked = false
		prompt.Triggered:Connect(function(player)
			if picked then
				return
			end
			if player ~= owner then
				remotes.Notify:FireClient(player, `🐦 {owner.DisplayName}님 비둘기 선물이에요!`)
				return
			end
			picked = true
			gifts[owner] = nil
			pendingGift[owner] = nil
			box:Destroy()
			local message = hooks.giftPicked(player, treasureId)
			if message ~= "" then
				remotes.Notify:FireClient(player, message)
			end
			if treasure.rare or treasure.kind == "valuable" then
				for _, other in roofPlayers() do
					if other ~= player then
						remotes.Notify:FireClient(other, `🐦 와! {player.DisplayName}님 비둘기가 {treasure.emoji} {treasure.name}을(를) 물어 왔어요!`)
					end
				end
			end
		end)
		-- ⏳ 오래 안 주우면(또는 날이 바뀌면) 바람에 날아가요
		task.spawn(function()
			local day = hooks.workDay()
			local expire = os.clock() + SalaryConfig.PIGEON_GIFT_LIFETIME
			while not picked and box.Parent and os.clock() < expire and hooks.workDay() == day do
				task.wait(1)
			end
			if picked then
				return
			end
			if gifts[owner] == box then
				gifts[owner] = nil
			end
			pendingGift[owner] = nil
			box:Destroy()
			if owner.Parent then
				if hooks.workDay() == day then
					hooks.giftMissed(owner) -- (오늘 횟수는 돌려줘요)
				end
				remotes.Notify:FireClient(owner, "🍃 비둘기 선물이 날아갔어요…")
			end
		end)
	end

	-- 🐦 선물을 문 비둘기가 날아와서 툭 떨어뜨리고 가요
	local function deliverGift(owner: Player, treasureId: string)
		local angle = math.random() * math.pi * 2
		local radius = 2.5 + math.random() * 2
		local at = spot + Vector3.new(math.cos(angle) * radius, 0.45, math.sin(angle) * radius)
		local kind = SalaryConfig.Pigeons[math.random(1, 2)] -- (평범한 동네 비둘기가 물어 와요)
		local from = at + Vector3.new(math.cos(angle) * 40, 30, math.sin(angle) * 40)
		local hover = at + Vector3.new(0, 6, 0)
		local carrier = makePigeon(pigeonFolder, kind, CFrame.lookAt(from, hover))
		remotes.Notify:FireClient(owner, "🐦 구구구! 비둘기가 선물을 물어 왔어요!")
		if hooks.giftDropped then
			hooks.giftDropped(owner, treasureId) -- 🔔 알림함에도 남겨요
		end
		local tween = TweenService:Create(carrier.root, TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.lookAt(hover, hover + (at - from) * Vector3.new(1, 0, 1)),
		})
		tween:Play()
		tween.Completed:Once(function()
			if owner.Parent then
				dropGift(owner, treasureId, at)
			else
				pendingGift[owner] = nil
			end
			task.wait(0.4)
			flyAway(carrier, true)
		end)
	end

	-- 🎁 과자를 먹은 비둘기가 나중에(PIGEON_GIFT_DELAY초 뒤) 선물을 물고 와요 (내가 옥상에 있을 때만)
	local function scheduleGift(owner: Player, treasureId: string)
		pendingGift[owner] = true
		local delayRange = SalaryConfig.PIGEON_GIFT_DELAY
		task.delay(math.random(delayRange[1], delayRange[2]), function()
			local giveUp = os.clock() + SalaryConfig.PIGEON_GIFT_WAIT
			while owner.Parent and not playerOnRoof(owner) and os.clock() < giveUp do
				task.wait(2)
			end
			if not owner.Parent then
				pendingGift[owner] = nil
				return
			end
			if not playerOnRoof(owner) then
				pendingGift[owner] = nil
				hooks.giftMissed(owner) -- (오늘 횟수는 돌려줘요)
				return
			end
			deliverGift(owner, treasureId)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		pendingGift[player] = nil
		local box = gifts[player]
		gifts[player] = nil
		if box then
			box:Destroy()
		end
	end)

	---------------------------------------------------------------- 🍪 과자 뿌리기
	local function feed(player: Player, snack: any)
		local feeds = hooks.fed(player, snack.friend)
		local levelIndex, level = SalaryConfig.pigeonLevel(feeds)
		scatterSeeds()
		leaveAt = os.clock() + SalaryConfig.PIGEON_STAY
		local want = math.min(level.flock + snack.flock, SalaryConfig.PIGEON_MAX_FLOCK) - aliveCount()
		for i = 1, math.max(0, want) do
			local kind = rollKind(levelIndex, snack.luck)
			task.delay((i - 1) * 0.35 + math.random() * 0.3, land, kind, generation)
			if hooks.seen(player, kind.id) then
				remotes.Notify:FireClient(player, `📒 새 비둘기! {kind.emoji} {kind.name}`)
			end
			if kind.rarity == "legend" or kind.rarity == "rare" then
				for _, other in roofPlayers() do
					remotes.Notify:FireClient(other, `{kind.emoji} 와! {kind.name}가 날아왔어요!`)
				end
			end
		end
		if want <= 0 then
			remotes.Notify:FireClient(player, `{snack.emoji} 더 뿌렸어요! +{SalaryConfig.PIGEON_STAY}초 · 💕 +{snack.friend}`)
		else
			remotes.Notify:FireClient(player, `🐦 비둘기 {want}마리가 날아와요! 💕 +{snack.friend}`)
		end
		-- 🎁 비둘기의 보은 (선물을 기다리는 중이면 다음 기회에)
		if not pendingGift[player] and not gifts[player] then
			local treasureId = hooks.giftRoll(player, levelIndex, snack.id)
			if treasureId then
				scheduleGift(player, treasureId)
			end
		end
	end

	-- [E] → 🎒 과자 고르기 창 (과자가 없으면 매점 안내)
	feedPrompt.Triggered:Connect(function(player)
		if hooks.guardNear() then
			remotes.Notify:FireClient(player, "🐦 경비원 때문에 겁먹었어요… 잠시 후 다시")
			return
		end
		if hooks.fedToday and hooks.fedToday(player) then
			remotes.Notify:FireClient(player, "🐦 오늘은 이미 줬어요")
			return
		end
		local any = false
		for _, snack in SalaryConfig.PigeonSnacks do
			if hooks.snackCount(player, snack.id) > 0 then
				any = true
				break
			end
		end
		if not any then
			remotes.Notify:FireClient(player, "🍪 과자가 없어요")
			return
		end
		remotes.PigeonSnackOpen:FireClient(player, feeder.Position)
	end)

	-- 고른 과자 뿌리기 (서버가 거리·경비원·🎒 개수를 다시 확인해요)
	remotes.PigeonFeed.OnServerInvoke = function(player: Player, snackId: any): (boolean, string)
		if not allowFeed(player) then
			return false, "천천히 눌러 주세요."
		end
		local snack = typeof(snackId) == "string" and SalaryConfig.getPigeonSnack(snackId)
		if not snack then
			return false, "알 수 없는 과자예요."
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or (root.Position - feeder.Position).Magnitude > 12 then
			return false, "🍪 모이 통 가까이에서 뿌려 주세요!"
		end
		if hooks.guardNear() then
			return false, "🐦 경비원 때문에 겁먹었어요… 잠시 후 다시"
		end
		if hooks.fedToday and hooks.fedToday(player) then
			return false, "🐦 오늘은 이미 과자를 줬어요! 내일 또 와요"
		end
		if not hooks.useSnack(player, snack.id) then
			return false, `🎒 {snack.emoji} {snack.name}이(가) 없어요`
		end
		feed(player, snack)
		return true, `{snack.emoji} {snack.name}을(를) 솔솔 뿌렸어요!`
	end

	-- 다 먹으면 배불러서 천천히 날아가요
	task.spawn(function()
		while true do
			task.wait(1)
			if leaveAt > 0 and os.clock() > leaveAt then
				scatter(true)
			end
		end
	end)

	local api = {}
	-- ⚠️ 경비원이 다가와요 → 놀라서 푸드덕! (비둘기가 있을 때만 경고가 돼요)
	function api.scare(): boolean
		if aliveCount() == 0 then
			return false
		end
		scatter(false)
		for _, player in roofPlayers() do
			remotes.Notify:FireClient(player, "🐦 푸드덕!! 👮 경비원이 와요!")
			remotes.PigeonScare:FireClient(player)
		end
		return true
	end
	function api.count(): number
		return aliveCount()
	end
	return api
end

return RoofPigeons
