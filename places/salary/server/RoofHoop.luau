-- 🏀 옥상 농구
--   공 거치대 [E] → 화면에서 슛 게이지 멈추기 × 공 HOOP_SHOTS개 → 점수만큼 상금 (하루 HOOP_DAILY_PRIZES번)
--   게이지 값은 "누른 시각"으로 서버가 다시 계산해요. 공이 날아가는 모습은 모두의 화면에 (HoopShot)
--   🔊 공 소리(새 판·놓친 공)에 👮 옥상 경비원이 농구대 쪽으로 확인하러 와요 (hooks.noise)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local Build = require(ReplicatedStorage.Shared.Build)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)

local RoofHoop = {}

local RIM_HEIGHT = 10
local RIM_RADIUS = 1.15

-- base: 골대 기둥 자리 (골대는 -Z 쪽을 봐요) / spot: 슛하는 자리
-- hooks.prize(player, 금액) → (준 돈, 남은 횟수) / hooks.noise() / hooks.unlock(player, 업적)
function RoofHoop.start(folder: Instance, base: Vector3, remotes, hooks)
	local B = Build.new(folder, Vector3.zero)
	local spot = base + Vector3.new(0, 0, -10)
	local rim = base + Vector3.new(0, RIM_HEIGHT, -1.3)

	---------------------------------------------------------------- 골대
	B:part(Vector3.new(0.5, RIM_HEIGHT + 2, 0.5), base + Vector3.new(0, (RIM_HEIGHT + 2) / 2, 0.8), { Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Metal })
	B:part(Vector3.new(2.4, 0.4, 2.4), base + Vector3.new(0, 0.2, 0.8), { Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Metal })
	B:part(Vector3.new(0.3, 0.3, 1.2), base + Vector3.new(0, RIM_HEIGHT + 1, 0.2), { Color = Color3.fromRGB(60, 60, 70) })
	local board = B:part(Vector3.new(6, 3.6, 0.2), base + Vector3.new(0, RIM_HEIGHT + 1.4, -0.4), { Color = Color3.fromRGB(245, 245, 245), Material = Enum.Material.SmoothPlastic })
	B:part(Vector3.new(2, 1.4, 0.05), base + Vector3.new(0, RIM_HEIGHT + 0.9, -0.52), { Color = Color3.fromRGB(220, 60, 50), Transparency = 0.2 })
	local _ = board
	for i = 1, 14 do -- 🟠 림 (작은 조각을 동그랗게)
		local angle = i / 14 * math.pi * 2
		B:part(Vector3.new(0.18, 0.18, 0.55), nil, {
			CFrame = CFrame.new(rim + Vector3.new(math.cos(angle) * RIM_RADIUS, 0, math.sin(angle) * RIM_RADIUS)) * CFrame.Angles(0, -angle, 0),
			Color = Color3.fromRGB(255, 120, 30),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end
	for i = 1, 8 do -- 그물
		local angle = i / 8 * math.pi * 2
		B:part(Vector3.new(0.06, 1.6, 0.06), rim + Vector3.new(math.cos(angle) * RIM_RADIUS * 0.8, -0.8, math.sin(angle) * RIM_RADIUS * 0.8), {
			Color = Color3.fromRGB(250, 250, 250),
			CanCollide = false,
			CanQuery = false,
		})
	end
	-- 바닥 코트 선 + 자유투 라인
	B:part(Vector3.new(7, 0.05, 11), base + Vector3.new(0, 0.03, -5), { Color = Color3.fromRGB(190, 110, 70), Material = Enum.Material.SmoothPlastic, CanCollide = false })
	B:part(Vector3.new(5, 0.07, 0.25), spot + Vector3.new(0, 0.04, 0), { Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Neon, CanCollide = false })
	-- 공 거치대
	local rack = B:part(Vector3.new(1.6, 1.6, 1.2), spot + Vector3.new(3.4, 0.8, 0), { Name = "BallRack", Color = Color3.fromRGB(90, 70, 50), Material = Enum.Material.WoodPlanks })
	for i = 0, 2 do
		B:part(Vector3.new(0.9, 0.9, 0.9), spot + Vector3.new(3.4 - 0.45 + i * 0.45, 1.9 + (i % 2) * 0.5, 0), { Shape = Enum.PartType.Ball, Color = Color3.fromRGB(230, 110, 40), CanCollide = false })
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "농구 한 판"
	prompt.ObjectText = `🏀 공 {SalaryConfig.HOOP_SHOTS}개`
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = rack
	prompt.Triggered:Connect(function(player)
		remotes.HoopOpen:FireClient(player, spot) -- 🚪 자유투 라인에서 멀어지면 창이 닫혀요
	end)

	---------------------------------------------------------------- 🏆 오늘의 농구 기록판 (코트 옆, 자유투 라인 쪽을 봐요)
	--   그날 서버의 1위를 다른 사람에게서 빼앗으면 보너스 (hooks.recordBonus). 근무일이 바뀌면 지워져요
	local recordBoard = B:part(Vector3.new(5, 3.4, 0.2), base + Vector3.new(6, 2.6, -3), { Color = Color3.fromRGB(25, 30, 45) })
	local recordGui = Instance.new("SurfaceGui")
	recordGui.Face = Enum.NormalId.Front
	recordGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	recordGui.PixelsPerStud = 50
	recordGui.LightInfluence = 0
	recordGui.Parent = recordBoard
	local recordText = Instance.new("TextLabel")
	recordText.Size = UDim2.fromScale(1, 1)
	recordText.BackgroundTransparency = 1
	recordText.TextColor3 = Color3.fromRGB(255, 230, 150)
	recordText.Font = Enum.Font.GothamBold
	recordText.TextSize = 20
	recordText.TextYAlignment = Enum.TextYAlignment.Top
	recordText.Parent = recordGui
	local records: { { id: number, name: string, score: number } } = {}
	local recordDay = if hooks.workDay then hooks.workDay() else 0
	local function checkDay()
		local day = if hooks.workDay then hooks.workDay() else 0
		if day ~= recordDay then
			recordDay = day
			table.clear(records)
		end
	end
	local function refreshRecords()
		checkDay()
		local lines = { "🏆 오늘의 농구 기록" }
		for i = 1, 5 do
			local record = records[i]
			table.insert(lines, if record then `{i}. {record.name}  {record.score}점` else `{i}. -`)
		end
		table.insert(lines, `1위를 빼앗으면 +{SalaryConfig.ROOF_RECORD_BONUS}원`)
		recordText.Text = table.concat(lines, "\n")
	end
	refreshRecords()
	task.spawn(function() -- (근무일이 바뀌면 기록판을 비워요)
		while recordBoard.Parent do
			task.wait(5)
			refreshRecords()
		end
	end)
	local function addRecord(player: Player, score: number)
		checkDay()
		local top = records[1]
		local mine = nil
		for _, record in records do
			if record.id == player.UserId then
				mine = record
			end
		end
		if mine then
			mine.score = math.max(mine.score, score)
		else
			table.insert(records, { id = player.UserId, name = player.DisplayName, score = score })
		end
		table.sort(records, function(a, b)
			return a.score > b.score
		end)
		refreshRecords()
		-- 다른 사람의 1위를 빼앗았어요
		if top and top.id ~= player.UserId and records[1].id == player.UserId and score > top.score then
			if hooks.recordBonus then
				hooks.recordBonus(player, "🏀 농구 기록 1위 탈환!")
			end
			for _, other in Players:GetPlayers() do
				remotes.Notify:FireClient(other, `🏀 {player.DisplayName} 님이 {top.name} 님을 제치고 옥상 농구 1위! ({score}점)`)
			end
		end
	end

	---------------------------------------------------------------- 한 판
	type Round = { shot: number, score: number, streak: number, makes: number, swishes: number, gaugeStart: number }
	local rounds: { [Player]: Round } = {}
	local allow = RateLimit.new(0.3)

	local function near(player: Player): Vector3?
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - spot).Magnitude < 13 then -- (공 거치대 [E] 거리까지 닿게 · 화면은 12에서 창을 닫아요)
			return root.Position
		end
		return nil
	end
	local function pressTime(value: any): number
		local now = workspace:GetServerTimeNow()
		if typeof(value) == "number" and value <= now + 0.05 and value >= now - 0.35 then -- (너무 옛날 시각은 못 골라요)
			return value
		end
		return now
	end

	remotes.HoopPlay.OnServerInvoke = function(player: Player, action: any, value: any)
		if not allow(player) then
			return { ok = false, message = "천천히!" }
		end
		local position = near(player)
		if not position then
			return { ok = false, message = "🏀 자유투 라인 근처에서 해요!" }
		end
		local now = workspace:GetServerTimeNow()
		if action == "start" then
			local old = rounds[player]
			-- (창을 닫고 다시 시작해도 소리가 나요: 하던 판이 없거나 오래 멈춰 있었으면)
			local wasPlaying = old ~= nil and now - old.gaugeStart < 8
			local round: Round = { shot = 0, score = 0, streak = 0, makes = 0, swishes = 0, gaugeStart = now + 0.5 }
			rounds[player] = round
			if not wasPlaying then
				hooks.noise() -- 🔊 공 튀기는 소리 (새 판을 시작할 때만) → 경비원이 확인하러 와요
			end
			return { ok = true, gaugeStart = round.gaugeStart, shots = SalaryConfig.HOOP_SHOTS }
		elseif action == "shoot" then
			local round = rounds[player]
			if not round or now < round.gaugeStart - 0.05 then
				return { ok = false, message = "잠깐! 공 받는 중…" }
			end
			round.shot += 1
			local gauge = SalaryConfig.hoopGauge(math.max(0, pressTime(value) - round.gaugeStart), round.shot)
			local result = SalaryConfig.hoopResult(gauge, SalaryConfig.playerFitnessEffect(player, "hoop")) -- 💪 근력: 성공 범위가 넓어져요 (최대 +20%)
			local points = 0
			if result == "swish" or result == "make" then
				points = if result == "swish" then 3 else 2
				if round.streak >= 1 then
					points += 1 -- 🔥 연속 성공 보너스
				end
				round.streak += 1
				round.makes += 1
				if result == "swish" then
					round.swishes += 1
				end
				hooks.unlock(player, "hoop_first")
			else
				round.streak = 0
			end
			round.score += points
			if points == 0 then
				hooks.noise() -- 🔊 놓친 공이 데굴데굴 시끄럽게 굴러가요 → 경비원이 확인하러 와요
			end
			remotes.HoopShot:FireAllClients({ from = position + Vector3.new(0, 3, 0), rim = rim, result = result })
			round.gaugeStart = now + 1.7 -- 다음 공 받는 시간
			local reply = {
				ok = true,
				gauge = gauge,
				result = result,
				points = points,
				score = round.score,
				streak = round.streak,
				shot = round.shot,
				gaugeStart = round.gaugeStart,
			}
			if round.shot >= SalaryConfig.HOOP_SHOTS then
				rounds[player] = nil
				reply.done = true
				if round.score > 0 then
					addRecord(player, round.score) -- 🏆 오늘의 기록판
				end
				reply.prize = 0
				reply.label = "😅 다음엔 더 잘할 거예요"
				for _, tier in SalaryConfig.HoopPrizes do
					if round.score >= tier.score then
						local paid, left = hooks.prize(player, tier.prize)
						reply.prize = paid
						reply.prizesLeft = left
						reply.label = tier.label
						break
					end
				end
				if round.makes >= SalaryConfig.HOOP_SHOTS then
					hooks.unlock(player, "hoop_perfect")
				end
				if round.swishes >= SalaryConfig.HOOP_SHOTS then
					hooks.unlock(player, "hoop_swish")
					for _, other in Players:GetPlayers() do
						remotes.Notify:FireClient(other, `🏀 {player.DisplayName} 님이 옥상 농구 전부 🎯 클린슛!!`)
					end
				end
			end
			return reply
		end
		return { ok = false, message = "잘못된 요청이에요." }
	end

	Players.PlayerRemoving:Connect(function(player)
		rounds[player] = nil
	end)
end

return RoofHoop
