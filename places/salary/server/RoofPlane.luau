-- ✈️ 옥상 종이비행기
--   발사대 [E] → 화면에서 🌬️ 바람 확인 → ① 각도 게이지 멈추기 → ② 힘 게이지 멈추기 → 슈웅~
--   게이지 값은 "누른 시각"으로 서버가 다시 계산해요 (화면을 조작해도 소용없어요)
--   비행기는 모든 사람 화면에 똑같이 날아가요 (PlaneFlight)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local Build = require(ReplicatedStorage.Shared.Build)

local RoofPlane = {}

local FORWARD = Vector3.new(0, 0, -1) -- 도시 쪽 (앞 난간 너머)
local RIGHT = Vector3.new(1, 0, 0)
local ROOF_DROP = 8 -- 건너편 빌딩 옥상은 우리 옥상보다 이만큼 낮아요
local NEAR_START, NEAR_END, HALF_WIDTH = 55, 205, 42 -- 건너편 빌딩 옥상 범위 (발사대 기준)

-- hooks:
--   onRoof(position) → 옥상 위인가
--   bossModel() → 옥상에 올라온 부장님 모델 (없으면 nil)
--   prize(player, 금액) → (준 돈, 오늘 남은 횟수)
--   bossHit(player) → 부장님 머리에 꽂힘 (의심도 + 업적)
--   unlock(player, 업적 ID)
--   best(player, 거리) → (새 기록인가, 내 최고 기록)
function RoofPlane.start(folder: Instance, launch: Vector3, remotes, hooks)
	local B = Build.new(folder, Vector3.zero)

	---------------------------------------------------------------- 발사대
	B:part(Vector3.new(4, 0.4, 3), launch + Vector3.new(0, 0.2, 0), { Color = Color3.fromRGB(70, 130, 200), Material = Enum.Material.Metal })
	B:part(Vector3.new(3.4, 0.1, 0.25), launch + Vector3.new(0, 0.45, -1.2), { Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon })
	local stand = B:part(Vector3.new(1.2, 1.2, 0.8), launch + Vector3.new(1.4, 0.9, 1), { Name = "PlaneStand", Color = Color3.fromRGB(240, 240, 235) })
	local padSign = B:part(Vector3.new(4, 1, 0.15), launch + Vector3.new(0, 2.6, 1.6), { Color = Color3.fromRGB(30, 60, 110) })
	Build.surfaceText(padSign, Enum.NormalId.Back, "✈️ 종이비행기 발사대", { Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1) })
	Build.surfaceText(padSign, Enum.NormalId.Front, "✈️ 종이비행기 발사대", { Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1) })
	for i = 0, 3 do -- 종이 더미
		B:part(Vector3.new(0.9, 0.05, 1.2), launch + Vector3.new(1.4, 1.53 + i * 0.06, 1), { Color = Color3.fromRGB(250, 250, 250), CanCollide = false })
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "종이비행기 날리기"
	prompt.ObjectText = "✈️ 보고서로 접은"
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = stand
	prompt.Triggered:Connect(function(player)
		remotes.PlaneOpen:FireClient(player)
	end)

	---------------------------------------------------------------- 건너편 빌딩 + 🎯 과녁
	local roofY = launch.Y - ROOF_DROP
	local depth = NEAR_END - NEAR_START
	local buildingCenter = launch + FORWARD * (NEAR_START + depth / 2) + Vector3.new(0, -ROOF_DROP - 60, 0)
	B:part(Vector3.new(HALF_WIDTH * 2, 120, depth), buildingCenter, { Color = Color3.fromRGB(170, 160, 150), Material = Enum.Material.Concrete, CanQuery = false })
	B:part(Vector3.new(HALF_WIDTH * 2, 0.4, depth), Vector3.new(buildingCenter.X, roofY - 0.2, buildingCenter.Z), { Color = Color3.fromRGB(140, 150, 140), Material = Enum.Material.Concrete, CanQuery = false })
	-- 창문 줄
	for row = 1, 6 do
		B:part(Vector3.new(HALF_WIDTH * 2 + 0.2, 2.2, depth + 0.2), Vector3.new(buildingCenter.X, roofY - row * 9, buildingCenter.Z), { Color = Color3.fromRGB(120, 170, 210), Material = Enum.Material.Glass, Transparency = 0.2, CanQuery = false })
	end
	local targetCenter = launch + FORWARD * SalaryConfig.PLANE_TARGET_DISTANCE
	targetCenter = Vector3.new(targetCenter.X, roofY, targetCenter.Z)
	for i, info in { { SalaryConfig.PLANE_TARGET_RADIUS, Color3.fromRGB(220, 50, 50) }, { SalaryConfig.PLANE_TARGET_RADIUS * 0.66, Color3.fromRGB(250, 250, 250) }, { SalaryConfig.PLANE_TARGET_RADIUS * 0.33, Color3.fromRGB(220, 50, 50) } } do
		B:part(Vector3.new(0.1, info[1] * 2, info[1] * 2), targetCenter + Vector3.new(0, 0.02 + i * 0.02, 0), {
			Shape = Enum.PartType.Cylinder,
			Orientation = Vector3.new(0, 0, 90),
			Color = info[2],
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
		})
	end
	local flag = B:part(Vector3.new(0.3, 8, 0.3), targetCenter + Vector3.new(SalaryConfig.PLANE_TARGET_RADIUS + 1, 4, 0), { Color = Color3.fromRGB(230, 230, 230), CanQuery = false })
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(110, 36)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.LightInfluence = 0
	billboard.Parent = flag
	local flagLabel = Instance.new("TextLabel")
	flagLabel.Size = UDim2.fromScale(1, 1)
	flagLabel.BackgroundTransparency = 1
	flagLabel.Text = `🎯 {SalaryConfig.PLANE_TARGET_DISTANCE}m`
	flagLabel.TextScaled = true
	flagLabel.Font = Enum.Font.GothamBlack
	flagLabel.TextColor3 = Color3.fromRGB(255, 80, 70)
	flagLabel.TextStrokeTransparency = 0.2
	flagLabel.Parent = billboard
	-- 거리 표시 (50m마다)
	for distance = 100, 200, 50 do
		local mark = launch + FORWARD * distance
		local post = B:part(Vector3.new(0.2, 3, 0.2), Vector3.new(mark.X - HALF_WIDTH + 2, roofY + 1.5, mark.Z), { Color = Color3.fromRGB(250, 250, 250), CanQuery = false })
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(60, 22)
		gui.StudsOffset = Vector3.new(0, 2.5, 0)
		gui.LightInfluence = 0
		gui.Parent = post
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = `{distance}m`
		text.TextScaled = true
		text.Font = Enum.Font.GothamBold
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0.3
		text.Parent = gui
	end

	---------------------------------------------------------------- 🏆 오늘의 기록판
	local board = B:part(Vector3.new(5, 3.4, 0.2), launch + Vector3.new(5.5, 2.6, 1.6), { Color = Color3.fromRGB(25, 30, 45) })
	local boardGui = Instance.new("SurfaceGui")
	boardGui.Face = Enum.NormalId.Back
	boardGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	boardGui.PixelsPerStud = 50
	boardGui.LightInfluence = 0
	boardGui.Parent = board
	local boardText = Instance.new("TextLabel")
	boardText.Size = UDim2.fromScale(1, 1)
	boardText.BackgroundTransparency = 1
	boardText.TextColor3 = Color3.fromRGB(255, 230, 150)
	boardText.Font = Enum.Font.GothamBold
	boardText.TextSize = 20
	boardText.TextYAlignment = Enum.TextYAlignment.Top
	boardText.Parent = boardGui
	local records: { { name: string, distance: number } } = {}
	local function refreshBoard()
		local lines = { "🏆 오늘의 종이비행기 기록" }
		for i = 1, 5 do
			local record = records[i]
			table.insert(lines, if record then `{i}. {record.name}  {math.floor(record.distance)}m` else `{i}. -`)
		end
		boardText.Text = table.concat(lines, "\n")
	end
	refreshBoard()

	---------------------------------------------------------------- 던지기
	type Throw = { wind: { forward: number, side: number }, angleStart: number, angle: number?, powerStart: number? }
	local throws: { [Player]: Throw } = {}
	local cooldown: { [Player]: number } = {}
	local flying: { [Player]: boolean } = {}

	local function near(player: Player): boolean
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return root ~= nil and (root.Position - launch).Magnitude < 12
	end
	local function pressTime(value: any): number
		local now = workspace:GetServerTimeNow()
		if typeof(value) == "number" and value <= now + 0.05 and value >= now - 0.6 then
			return value
		end
		return now
	end
	local function roundWind(): number
		return math.floor((math.random() * 2 - 1) * 10 + 0.5) / 10
	end

	remotes.PlaneThrow.OnServerInvoke = function(player: Player, action: any, value: any)
		if not near(player) then
			return { ok = false, message = "✈️ 발사대 앞에서 날려요!" }
		end
		local now = workspace:GetServerTimeNow()
		if action == "begin" then
			if flying[player] then
				return { ok = false, message = "아직 날아가는 중이에요!" }
			end
			if os.clock() < (cooldown[player] or 0) then
				return { ok = false, message = `종이를 접는 중… {math.ceil((cooldown[player] :: number) - os.clock())}초` }
			end
			local throw: Throw = { wind = { forward = roundWind(), side = roundWind() }, angleStart = now + 0.4 }
			throws[player] = throw
			return { ok = true, wind = throw.wind, angleStart = throw.angleStart }
		end
		local throw = throws[player]
		if not throw then
			return { ok = false, message = "먼저 [준비]를 눌러 주세요." }
		end
		if action == "angle" and not throw.angle then
			throw.angle = SalaryConfig.planeAngle(math.max(0, pressTime(value) - throw.angleStart))
			throw.powerStart = now + 0.3
			return { ok = true, angle = throw.angle, powerStart = throw.powerStart }
		elseif action == "power" and throw.angle and throw.powerStart then
			throws[player] = nil
			cooldown[player] = os.clock() + SalaryConfig.PLANE_COOLDOWN
			local angle = throw.angle :: number
			local power = SalaryConfig.planePower(math.max(0, pressTime(value) - (throw.powerStart :: number)))
			local distance, drift = SalaryConfig.planeFlight(angle, power, throw.wind.forward, throw.wind.side)
			local start = launch + Vector3.new(0, 3.2, -1.5)

			-- 😱 맞바람이 세면 가끔 되돌아와요
			local boomerang = throw.wind.forward <= -0.5 and math.random() < SalaryConfig.PLANE_BOOMERANG_CHANCE
			local bossModel = hooks.bossModel()
			local finish: Vector3
			local control: Vector3
			local hitBoss = false
			if boomerang then
				local bossHead = bossModel and bossModel:FindFirstChild("Head") :: BasePart?
				if bossHead then
					hitBoss = true
					finish = bossHead.Position + Vector3.new(0, 0.3, 0)
				else
					finish = launch + Vector3.new(math.random(-4, 4), 0.2, math.random(3, 7))
				end
				control = launch + FORWARD * 40 + Vector3.new(drift * 0.3, 22, 0)
				distance = 0
			else
				finish = launch + FORWARD * distance + RIGHT * drift
				local onBuilding = distance >= NEAR_START and distance <= NEAR_END and math.abs(drift) <= HALF_WIDTH
				finish = Vector3.new(finish.X, if onBuilding then roofY + 0.15 else launch.Y - 70, finish.Z)
				local lift = distance * math.tan(math.rad(angle)) * 0.3
				control = start:Lerp(finish, 0.45) + Vector3.new(drift * 0.2, lift + 4, 0)
			end
			local duration = if boomerang then 3.2 else 1.3 + distance / 75
			flying[player] = true
			remotes.PlaneFlight:FireAllClients({ start = start, control = control, finish = finish, duration = duration, owner = player.UserId })

			-- 결과
			local flat = Vector3.new(finish.X - targetCenter.X, 0, finish.Z - targetCenter.Z)
			local hitTarget = not boomerang and flat.Magnitude <= SalaryConfig.PLANE_TARGET_RADIUS
			local prize, label = 0, "🍂 툭… 금방 떨어졌어요"
			if hitTarget then
				prize, label = SalaryConfig.PLANE_TARGET_PRIZE, "🎯 과녁 명중!!"
			elseif not boomerang then
				for _, tier in SalaryConfig.PlanePrizes do
					if distance >= tier.distance then
						prize, label = tier.prize, tier.label
						break
					end
				end
			else
				label = if hitBoss then "😱 되돌아와서 부장님 머리에 꽂혔어요!!" else "🔄 바람에 되돌아왔어요…"
			end
			local result = {
				ok = true,
				angle = angle,
				power = power,
				distance = distance,
				drift = drift,
				duration = duration,
				hitTarget = hitTarget,
				boomerang = boomerang,
				hitBoss = hitBoss,
				label = label,
				prize = 0,
				prizesLeft = 0,
			}
			hooks.unlock(player, "plane_first")
			task.delay(duration, function()
				flying[player] = nil
				if not player.Parent then
					return
				end
				if hitBoss then
					hooks.bossHit(player)
				end
				if hitTarget then
					hooks.unlock(player, "plane_target")
					for _, other in Players:GetPlayers() do
						remotes.Notify:FireClient(other, `🎯 {player.DisplayName} 님의 종이비행기가 건너편 빌딩 과녁에 명중!`)
					end
				end
			end)
			if prize > 0 then
				local paid, left = hooks.prize(player, prize)
				result.prize = paid
				result.prizesLeft = left
			end
			if distance > 0 then
				local isRecord, best = hooks.best(player, distance)
				result.record = isRecord
				result.best = best
				-- 오늘의 기록판 (이름마다 최고 기록 하나)
				local mine = nil
				for _, record in records do
					if record.name == player.DisplayName then
						mine = record
					end
				end
				if mine then
					mine.distance = math.max(mine.distance, distance)
				else
					table.insert(records, { name = player.DisplayName, distance = distance })
				end
				table.sort(records, function(a, b)
					return a.distance > b.distance
				end)
				refreshBoard()
			end
			return result
		end
		return { ok = false, message = "잘못된 요청이에요." }
	end

	Players.PlayerRemoving:Connect(function(player)
		throws[player] = nil
		cooldown[player] = nil
		flying[player] = nil
	end)
end

return RoofPlane
