-- 🐦 옥상 비둘기 친구
--   🍞 모이 통 [E] → 하늘에서 비둘기들이 내려와 콕콕 쪼아 먹어요 (PIGEON_STAY초)
--   ⚠️ 👮 옥상 경비원이 가까이 다가오면 먼저 놀라서 푸드덕! (살아 있는 근접 알람)
--   💕 친밀도가 오를수록 더 많이, 더 희귀한 비둘기가 와요 → 📒 관찰 노트에 기록

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local Build = require(ReplicatedStorage.Shared.Build)

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
--   charge(player, 금액) → (ok, 메시지)
--   fed(player) → 친밀도(모이 준 횟수)
--   seen(player, 비둘기 ID) → 처음 만났나
--   guardNear() → 경비원이 모이 통 가까이 있나
--   onRoof(position) → 옥상 위인가
function RoofPigeons.start(folder: Instance, spot: Vector3, remotes, hooks)
	local pigeonFolder = Instance.new("Folder")
	pigeonFolder.Name = "Pigeons"
	pigeonFolder.Parent = folder
	local B = Build.new(folder, Vector3.zero)

	-- 🍞 모이 통 + 📒 관찰 노트 (작은 나무 상자 위)
	B:part(Vector3.new(2.4, 1.6, 1.6), spot + Vector3.new(0, 0.8, 4.5), { Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.WoodPlanks })
	local feeder = B:part(Vector3.new(1.4, 0.9, 1), spot + Vector3.new(-0.4, 2.05, 4.5), { Name = "PigeonFeeder", Color = Color3.fromRGB(240, 210, 140), Material = Enum.Material.Fabric })
	local feederSign = B:part(Vector3.new(2.4, 0.9, 0.15), spot + Vector3.new(0, 2.4, 5.35), { Color = Color3.fromRGB(60, 45, 35) })
	Build.surfaceText(feederSign, Enum.NormalId.Front, "🍞 비둘기 모이", { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 230, 170) })
	Build.surfaceText(feederSign, Enum.NormalId.Back, "🍞 비둘기 모이", { Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 230, 170) })
	local notebook = B:part(Vector3.new(0.8, 0.12, 1), spot + Vector3.new(0.75, 1.66, 4.5), { Name = "PigeonBook", Color = Color3.fromRGB(90, 160, 110) })

	local feedPrompt = Instance.new("ProximityPrompt")
	feedPrompt.ActionText = `모이 뿌리기 ({SalaryConfig.PIGEON_FEED_PRICE}원)`
	feedPrompt.ObjectText = "🍞 비둘기 모이"
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
		remotes.PigeonBook:FireClient(player)
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

	-- 친밀도 단계에 맞춰 비둘기 종류 뽑기
	local function rollKind(level: number): any
		local total = 0
		local pool = {}
		for _, kind in SalaryConfig.Pigeons do
			if level >= kind.minLevel then
				local weight = kind.weight + kind.perLevel * (level - 1)
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

	feedPrompt.Triggered:Connect(function(player)
		if hooks.guardNear() then
			remotes.Notify:FireClient(player, "🐦 경비원 아저씨 때문에 비둘기들이 겁먹었어요… 조금 있다가 다시!")
			return
		end
		local paid, message = hooks.charge(player, SalaryConfig.PIGEON_FEED_PRICE)
		if not paid then
			remotes.Notify:FireClient(player, message)
			return
		end
		local feeds = hooks.fed(player)
		local levelIndex, level = SalaryConfig.pigeonLevel(feeds)
		scatterSeeds()
		leaveAt = os.clock() + SalaryConfig.PIGEON_STAY
		local want = math.min(level.flock, SalaryConfig.PIGEON_MAX_FLOCK) - aliveCount()
		local found = {}
		for i = 1, math.max(0, want) do
			local kind = rollKind(levelIndex)
			task.delay((i - 1) * 0.35 + math.random() * 0.3, land, kind, generation)
			table.insert(found, kind)
			if hooks.seen(player, kind.id) then
				remotes.Notify:FireClient(player, `📒 새 비둘기 발견! {kind.emoji} {kind.name} — {kind.description}`)
			end
			if kind.rarity == "legend" or kind.rarity == "rare" then
				for _, other in roofPlayers() do
					remotes.Notify:FireClient(other, `{kind.emoji} 와! {kind.name}가 날아왔어요!`)
				end
			end
		end
		if want <= 0 then
			remotes.Notify:FireClient(player, `🍞 모이를 더 뿌렸어요! 비둘기들이 {SalaryConfig.PIGEON_STAY}초 더 머물러요 (💕 {level.name})`)
		else
			remotes.Notify:FireClient(player, `🐦 비둘기 {want}마리가 날아와요! (💕 친밀도: {level.name} · 모이 {feeds}번)`)
		end
		local _ = found
	end)

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
			remotes.Notify:FireClient(player, "🐦 푸드덕!! 비둘기들이 놀라서 날아갔어요… 👮 경비원이 이쪽으로 와요!")
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
