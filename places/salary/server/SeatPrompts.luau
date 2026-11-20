-- 🪑 의자마다 [E] 앉기
--   의자 위에 딱 맞게 착지하지 않아도, 가까이 가서 [E]만 누르면 앉아요.
--   (내 책상 의자, 변기, 회의실 의자, 회식 자리, 옥상 선베드… 모든 Seat)
--   책상 의자(이름 "Seat")는 주인(OwnerId)만 앉을 수 있어요. 동료 NPC 자리엔 안 떠요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)

local SeatPrompts = {}

-- 의자 종류별 안내 문구
local OBJECT_TEXT = {
	Seat = "🪑 내 자리",
	ToiletSeat = "🚽 변기",
	MeetingSeat = "📊 회의실 의자",
	DinnerSeat = "🍻 회식 자리",
	Lounger = "🏖️ 선베드",
	HideSeat = "📦 상자 속 (밖에서 안 보여요)",
	GymSeat = "🏋️ 운동기구", -- (기구마다 PromptText 속성이 있으면 그걸 써요: "🏃 러닝머신" 등)
}

local function sitOn(player: Player, seat: Seat)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and humanoid) or humanoid.Health <= 0 or seat.Occupant then
		return
	end
	if humanoid.SeatPart == seat then
		return
	end
	-- ⚠️ 다른 의자에 앉은 채로 옮기면 그 의자까지 끌려와요 → 먼저 일어나요
	if humanoid.SeatPart then
		for _, child in humanoid.SeatPart:GetChildren() do
			if child:IsA("Weld") and child.Name == "SeatWeld" then
				child:Destroy()
			end
		end
		humanoid.Sit = false
		task.wait(0.1)
	end
	character:PivotTo(seat.CFrame + Vector3.new(0, 3, 0))
	task.wait(0.05)
	if not seat.Occupant then
		if seat.Name == "GymSeat" then
			seat.Disabled = false -- 🏋️ 운동기구는 [E]로만 탈 수 있어요 (평소엔 잠가 둬요)
		end
		seat:Sit(humanoid)
		if seat.Name == "GymSeat" then
			task.delay(0.3, function()
				if seat.Occupant ~= humanoid and not seat.Occupant then
					seat.Disabled = true -- (앉기에 실패했으면 다시 잠가요: 지나가다 밟아서 앉지 않게)
				end
			end)
		end
	end
end

function SeatPrompts.start(remotes)
	local function attach(seat: Instance)
		if not seat:IsA("Seat") or seat:FindFirstChild("SitPrompt") then
			return
		end
		local isGym = seat.Name == "GymSeat"
		if isGym then
			-- 🏋️ 운동기구: 지나가다 밟아서 앉는 일 없이 [E] 운동하기로만 시작해요
			seat.Disabled = true
			seat:GetPropertyChangedSignal("Occupant"):Connect(function()
				if not seat.Occupant then
					seat.Disabled = true
				end
			end)
			-- 기구 위에 무슨 스탯이 오르는지 미리 보여 줘요
			local machineId = seat:GetAttribute("Machine") or ""
			local machine = SalaryConfig.GymMachines[machineId]
			if machine then
				local board = Instance.new("BillboardGui")
				board.Name = "GymInfo"
				board.Size = UDim2.fromOffset(150, 40)
				board.StudsOffset = Vector3.new(0, 4.5, 0)
				board.MaxDistance = 22
				board.AlwaysOnTop = false
				board.Parent = seat
				local label = Instance.new("TextLabel")
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundColor3 = Color3.fromRGB(25, 28, 36)
				label.BackgroundTransparency = 0.25
				label.TextColor3 = Color3.new(1, 1, 1)
				label.Font = Enum.Font.GothamBold
				label.TextScaled = true
				label.Text = `{machine.emoji} {machine.name}\n⬆️ {SalaryConfig.gymStatText(machineId)}`
				label.Parent = board
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 8)
				corner.Parent = label
			end
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SitPrompt"
		prompt.ActionText = if seat.Name == "HideSeat" then "숨기" elseif seat.Name == "GymSeat" then "운동하기" else "앉기"
		prompt.ObjectText = seat:GetAttribute("PromptText") or OBJECT_TEXT[seat.Name] or "🪑 의자"
		if isGym then
			local statText = SalaryConfig.gymStatText(seat:GetAttribute("Machine") or "")
			if statText ~= "" then
				prompt.ObjectText ..= ` · ⬆️ {statText}` -- 예) 🏃 러닝머신 · ⬆️ 🔋 지구력
			end
		end
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 6
		prompt.RequiresLineOfSight = false
		prompt.Parent = seat
		local function refresh()
			prompt.Enabled = seat.Occupant == nil -- 누가 앉아 있으면 숨겨요
		end
		refresh()
		seat:GetPropertyChangedSignal("Occupant"):Connect(refresh)
		prompt.Triggered:Connect(function(player)
			if seat.Name == "Seat" and seat:GetAttribute("OwnerId") ~= player.UserId then
				remotes.Notify:FireClient(player, "🙅 다른 사람 자리예요! ⭐ 내 자리로")
				return
			end
			sitOn(player, seat)
		end)
	end
	for _, item in workspace:GetDescendants() do
		attach(item)
	end
	workspace.DescendantAdded:Connect(attach)
end

return SeatPrompts
