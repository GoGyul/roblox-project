-- 🔭 건너편 빌딩 관찰 일지
--   옥상 오른쪽 관찰 망원경 [E] → 화면에 동그란 렌즈 뷰 → (주)야근물산 창문들을 둘러봐요
--   어떤 창문에 어떤 장면이 언제까지 보이는지는 서버가 정해요 (ScopeScenes) → 모두에게 같은 장면이 보여요
--   렌즈 가운데에 맞추면 화면이 ScopeSpot으로 알려 주고, 서버가 "지금 정말 보이는지" 확인해요

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)
local Build = require(ReplicatedStorage.Shared.Build)

local RoofScope = {}

-- 지금 시간대 ("morning" / "lunch" / "afternoon", 퇴근 후면 nil)
local function timeOfDay(dayCycle): string?
	if dayCycle.phase == "offwork" or dayCycle.waiting then
		return nil
	end
	if dayCycle.phase == "lunch" then
		return "lunch"
	end
	return if dayCycle.minute < SalaryConfig.LUNCH_START then "morning" else "afternoon"
end

-- hooks.found(player, 장면 ID) → (처음인가, 보상)
function RoofScope.start(folder: Instance, stand: Vector3, dayCycle, remotes, hooks)
	local B = Build.new(folder, Vector3.zero)
	local allow = RateLimit.new(0.3)

	---------------------------------------------------------------- 관찰 망원경 (난간 쪽, 오른쪽 빌딩을 향해)
	B:part(Vector3.new(0.3, 3.2, 0.3), stand + Vector3.new(0, 1.6, 0), { Color = Color3.fromRGB(50, 50, 55) })
	B:part(Vector3.new(1.6, 0.2, 1.6), stand + Vector3.new(0, 0.1, 0), { Color = Color3.fromRGB(50, 50, 55) })
	local scope = B:part(Vector3.new(2.6, 0.8, 0.8), nil, {
		Name = "ObservationScope",
		CFrame = CFrame.new(stand + Vector3.new(0.3, 3.4, 0)) * CFrame.Angles(0, 0, math.rad(6)),
		Color = Color3.fromRGB(70, 110, 170),
		Material = Enum.Material.Metal,
	})
	B:part(Vector3.new(0.5, 1, 1), stand + Vector3.new(1.7, 3.55, 0), { Color = Color3.fromRGB(30, 30, 35), Material = Enum.Material.Glass })
	local sign = B:part(Vector3.new(0.15, 0.9, 3.2), stand + Vector3.new(-0.9, 2, 0), { Color = Color3.fromRGB(30, 50, 90) })
	Build.surfaceText(sign, Enum.NormalId.Left, "🔭 건너편 관찰", { Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1) })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "건너편 빌딩 엿보기"
	prompt.ObjectText = "🔭 관찰 망원경"
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = scope
	prompt.Triggered:Connect(function(player)
		remotes.ScopeOpen:FireClient(player)
	end)

	---------------------------------------------------------------- 건너편 (주)야근물산 (오른쪽 멀리)
	local cols, rows = SalaryConfig.SCOPE_COLUMNS, SalaryConfig.SCOPE_ROWS
	local face = stand + Vector3.new(80, 0, 0) -- 빌딩 앞면 (이쪽을 보는 면)
	local width, height = cols * 7 + 6, rows * 6 + 30
	B:part(Vector3.new(30, height + 80, width), face + Vector3.new(15, -40 + height / 2 - 18, 0), { Color = Color3.fromRGB(110, 115, 130), Material = Enum.Material.Concrete, CanCollide = false, CanQuery = false })
	for r = 1, rows do
		for c = 1, cols do
			local z = (c - (cols + 1) / 2) * 7
			local y = (rows - r) * 6 - 6
			B:part(Vector3.new(0.3, 4, 5), face + Vector3.new(-0.1, y, z), {
				Color = if (r + c) % 3 == 0 then Color3.fromRGB(255, 235, 170) else Color3.fromRGB(150, 190, 220),
				Material = Enum.Material.Neon,
				Transparency = 0.25,
				CanCollide = false,
				CanQuery = false,
			})
		end
	end
	local nameSign = B:part(Vector3.new(0.3, 4, width - 6), face + Vector3.new(-0.2, rows * 6 + 1, 0), { Color = Color3.fromRGB(40, 40, 50), CanCollide = false, CanQuery = false })
	Build.surfaceText(nameSign, Enum.NormalId.Left, "(주)야근물산", { Font = Enum.Font.GothamBlack, TextColor3 = Color3.fromRGB(255, 120, 90) })

	---------------------------------------------------------------- 장면 정하기 (서버만)
	type Showing = { w: number, s: string, u: number } -- 창문 번호, 장면 ID, 언제까지(서버 시각)
	local showing: { Showing } = {}
	local function publish()
		ReplicatedStorage:SetAttribute("ScopeScenes", HttpService:JSONEncode(showing))
	end
	publish()

	local function rollScene(period: string, taken: { [string]: boolean }): any?
		local total = 0
		local pool = {}
		for _, scene in SalaryConfig.ScopeScenes do
			if table.find(scene.times, period) and not taken[scene.id] then
				total += scene.weight
				table.insert(pool, scene)
			end
		end
		if total <= 0 then
			return nil
		end
		local roll = math.random() * total
		for _, scene in pool do
			roll -= scene.weight
			if roll <= 0 then
				return scene
			end
		end
		return pool[#pool]
	end

	task.spawn(function()
		local target = SalaryConfig.SCOPE_ACTIVE[1]
		while true do
			task.wait(1)
			local now = workspace:GetServerTimeNow()
			local changed = false
			-- 시간이 다 된 장면은 사라져요
			for i = #showing, 1, -1 do
				if showing[i].u <= now then
					table.remove(showing, i)
					changed = true
				end
			end
			local period = timeOfDay(dayCycle)
			if not period then
				if #showing > 0 then
					table.clear(showing)
					changed = true
				end
			else
				if math.random() < 0.15 then
					target = math.random(SalaryConfig.SCOPE_ACTIVE[1], SalaryConfig.SCOPE_ACTIVE[2])
				end
				-- 빈 창문에 새 장면 (같은 장면은 동시에 한 곳만)
				while #showing < target do
					local takenWindow, takenScene = {}, {}
					for _, item in showing do
						takenWindow[item.w] = true
						takenScene[item.s] = true
					end
					local free = {}
					for w = 1, cols * rows do
						if not takenWindow[w] then
							table.insert(free, w)
						end
					end
					local scene = rollScene(period, takenScene)
					if #free == 0 or not scene then
						break
					end
					table.insert(showing, {
						w = free[math.random(1, #free)],
						s = scene.id,
						u = now + math.random(SalaryConfig.SCOPE_SHOW[1] * 10, SalaryConfig.SCOPE_SHOW[2] * 10) / 10,
					})
					changed = true
				end
			end
			if changed then
				publish()
			end
		end
	end)

	---------------------------------------------------------------- 발견!
	local function nearScope(player: Player): boolean
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return root ~= nil and (root.Position - stand).Magnitude < 12
	end

	remotes.ScopeSpot.OnServerInvoke = function(player: Player, window: any, sceneId: any)
		if not allow(player) then
			return { ok = false }
		end
		if not nearScope(player) then
			return { ok = false, message = "🔭 망원경 앞에서 봐야 해요!" }
		end
		local now = workspace:GetServerTimeNow()
		local visible = false
		for _, item in showing do
			-- (화면과 서버 사이 시간 차이를 조금 봐줘요)
			if item.w == window and item.s == sceneId and item.u > now - 1.5 then
				visible = true
			end
		end
		if not visible then
			return { ok = false, message = "앗, 놓쳤어요!" }
		end
		local scene = SalaryConfig.getScopeScene(sceneId)
		local first, reward = hooks.found(player, sceneId)
		return { ok = true, first = first, reward = reward, name = scene.name, emoji = scene.emoji, rarity = scene.rarity, description = scene.description }
	end

	Players.PlayerRemoving:Connect(function() end)
end

return RoofScope
