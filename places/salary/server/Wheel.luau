-- 🎡 돌림판 (뽑기 천국 가게)
--   금액 고르고 숫자에 걸기(여러 개 가능) → [🎡 돌리기] → 4초 뒤 결과
--   멈춘 숫자에 건 돈 × (숫자 + 1)을 받아요. 뒷벽 큰 돌림판은 마지막으로 누가 돌린 판을 보여 줘요.
--
-- 🛡️ 결과는 서버가 정해요. 화면은 서버가 알려 준 시작·끝 각도로 똑같이 돌기만 해요.
--   뒷벽 돌림판용 ReplicatedStorage 속성: WheelFrom, WheelTo(회전 각도), WheelSpinStart

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)

local Wheel = {}

local RANGE = 18 -- 가게 안 (돌림판 베팅대에서 이 거리 안)
local SEGMENT_ANGLE = 360 / #SalaryConfig.WHEEL_SEGMENTS
local allowBet = RateLimit.new(0.2)

-- 돌림판 그림: 원판 위 SurfaceGui 안에 "Spin" 프레임(이게 돌아요) + 칸마다 숫자 상자
-- 칸 i는 위쪽에서 시계 방향으로 (i-1)×14.4° 자리에 있어요. 프레임을 R만큼 돌리면 그 칸은 (각도 + R)로 가요.
local function buildWheelGui(disc: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "WheelGui"
	gui.Face = Enum.NormalId.Left -- 원판이 가게 앞쪽을 보는 면
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.3
	gui.Parent = disc
	local spin = Instance.new("Frame")
	spin.Name = "Spin"
	spin.AnchorPoint = Vector2.new(0.5, 0.5)
	spin.Position = UDim2.fromScale(0.5, 0.5)
	spin.Size = UDim2.fromScale(1, 1)
	spin.BackgroundTransparency = 1
	spin.Parent = gui
	for i, number in SalaryConfig.WHEEL_SEGMENTS do
		local angle = math.rad((i - 1) * SEGMENT_ANGLE)
		local box = Instance.new("TextLabel")
		box.AnchorPoint = Vector2.new(0.5, 0.5)
		box.Position = UDim2.fromScale(0.5 + 0.4 * math.sin(angle), 0.5 - 0.4 * math.cos(angle))
		box.Size = UDim2.fromScale(0.11, 0.11)
		box.Rotation = (i - 1) * SEGMENT_ANGLE
		box.BackgroundColor3 = SalaryConfig.WHEEL_COLORS[number]
		box.TextColor3 = Color3.new(1, 1, 1)
		box.Font = Enum.Font.GothamBlack
		box.TextScaled = true
		box.Text = tostring(number)
		box.Parent = spin
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.2, 0)
		corner.Parent = box
	end
	local center = Instance.new("TextLabel")
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	center.Position = UDim2.fromScale(0.5, 0.5)
	center.Size = UDim2.fromScale(0.32, 0.32)
	center.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	center.TextColor3 = Color3.fromRGB(255, 220, 120)
	center.Font = Enum.Font.GothamBlack
	center.TextScaled = true
	center.Text = "🎡"
	center.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = center
end

-- hooks.charge(player, amount) → (ok, message)
-- hooks.payout(player, amount, number) : 당첨금 지급
function Wheel.start(office, remotes, hooks)
	local wheel = office.wheel
	if not wheel then
		return -- 눈치물산에만 있어요
	end
	buildWheelGui(wheel.disc)

	local bets: { [Player]: { [number]: number } } = {}
	local spinning: { [Player]: boolean } = {}
	local rotation = 0 -- 뒷벽 돌림판 각도

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "돌림판 하기"
	prompt.ObjectText = "🎡 돌림판"
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = wheel.kiosk
	prompt.Triggered:Connect(function(player)
		remotes.WheelOpen:FireClient(player)
	end)
	ReplicatedStorage:SetAttribute("WheelFrom", 0)
	ReplicatedStorage:SetAttribute("WheelTo", 0)
	ReplicatedStorage:SetAttribute("WheelSpinStart", 0)

	local function near(player: Player): boolean
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return root ~= nil and (root.Position - wheel.kiosk.Position).Magnitude <= RANGE
	end

	local function totalBet(player: Player): number
		local sum = 0
		for _, amount in bets[player] or {} do
			sum += amount
		end
		return sum
	end

	-- 숫자 키 표는 통신 중에 깨질 수 있어서 [숫자, 금액] 목록으로 보내요
	local function betList(player: Player)
		local list = {}
		for n, a in bets[player] or {} do
			table.insert(list, { n, a })
		end
		return list
	end

	remotes.WheelBet.OnServerInvoke = function(player: Player, action: any, amount: any, number: any)
		if not allowBet(player) then
			return { ok = false, message = "천천히 눌러 주세요." }
		end
		if spinning[player] then
			return { ok = false, message = "돌아가는 중이에요! 멈추면 다시 걸어 주세요." }
		end
		if not near(player) then
			return { ok = false, message = "돌림판 앞에서 해 주세요!" }
		end

		if action == "bet" then
			if typeof(amount) ~= "number" or not table.find(SalaryConfig.WHEEL_BETS, amount) then
				return { ok = false, message = "잘못된 금액이에요." }
			end
			if typeof(number) ~= "number" or not table.find(SalaryConfig.WHEEL_NUMBERS, number) then
				return { ok = false, message = "잘못된 숫자예요." }
			end
			if totalBet(player) + amount > SalaryConfig.WHEEL_MAX_ROUND then
				return { ok = false, message = `한 판에 {SalaryConfig.WHEEL_MAX_ROUND}원까지만 걸 수 있어요.` }
			end
			local ok, message = hooks.charge(player, amount)
			if not ok then
				return { ok = false, message = message }
			end
			bets[player] = bets[player] or {}
			bets[player][number] = (bets[player][number] or 0) + amount
			return { ok = true, bets = betList(player) }
		elseif action == "spin" then
			local stake = totalBet(player)
			if stake <= 0 then
				return { ok = false, message = "먼저 숫자에 걸어 주세요!" }
			end
			-- 결과 정하기 (칸 하나를 무작위로) → 그 칸이 맨 위(바늘)에 오도록 회전
			local index = math.random(1, #SalaryConfig.WHEEL_SEGMENTS)
			local result = SalaryConfig.WHEEL_SEGMENTS[index]
			local from = rotation % 360
			local finalAngle = (360 - (index - 1) * SEGMENT_ANGLE) % 360 -- (칸 각도 + R) ≡ 0
			local to = from + ((finalAngle - from) % 360) + 360 * 4 -- 시계 방향으로 4바퀴 더
			rotation = to
			local spinStart = workspace:GetServerTimeNow()
			ReplicatedStorage:SetAttribute("WheelFrom", from)
			ReplicatedStorage:SetAttribute("WheelTo", to)
			ReplicatedStorage:SetAttribute("WheelSpinStart", spinStart)

			local win = (bets[player][result] or 0) * (result + 1)
			bets[player] = nil
			spinning[player] = true
			-- 돌림판이 멈출 때 돈을 줘요
			task.delay(SalaryConfig.WHEEL_SPIN_SECONDS, function()
				spinning[player] = nil
				if win > 0 and player.Parent then
					hooks.payout(player, win, result)
				end
			end)
			return { ok = true, number = result, from = from, to = to, spinStart = spinStart, stake = stake, win = win }
		end
		return { ok = false, message = "잘못된 요청이에요." }
	end

	Players.PlayerRemoving:Connect(function(player)
		bets[player] = nil
		spinning[player] = nil
	end)
end

return Wheel
