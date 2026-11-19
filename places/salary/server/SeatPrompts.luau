-- 🪑 의자마다 [E] 앉기
--   의자 위에 딱 맞게 착지하지 않아도, 가까이 가서 [E]만 누르면 앉아요.
--   (내 책상 의자, 변기, 회의실 의자, 회식 자리, 옥상 선베드… 모든 Seat)
--   책상 의자(이름 "Seat")는 주인(OwnerId)만 앉을 수 있어요. 동료 NPC 자리엔 안 떠요.

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
		seat:Sit(humanoid)
	end
end

function SeatPrompts.start(remotes)
	local function attach(seat: Instance)
		if not seat:IsA("Seat") or seat:FindFirstChild("SitPrompt") then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SitPrompt"
		prompt.ActionText = if seat.Name == "HideSeat" then "숨기" elseif seat.Name == "GymSeat" then "운동하기" else "앉기"
		prompt.ObjectText = seat:GetAttribute("PromptText") or OBJECT_TEXT[seat.Name] or "🪑 의자"
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
				remotes.Notify:FireClient(player, "🙅 여기는 다른 사람 자리예요! ⭐ 표시된 내 자리에 앉아요.")
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
