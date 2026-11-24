-- 🏃 달리기: [왼쪽 Shift]를 누르고 있는 동안 빨리 달려요.
--   걷는 속도는 서버가 상황마다 바꿔요 (워크숍 게임, 이동 중 멈춤 등). 그래서 "지금 평소 속도"를 기억해 두고
--   Shift를 누른 동안만 그 속도에 배율을 곱해요. 서버가 속도를 바꾸면 그 값을 새 평소 속도로 받아들여요.
--   (서버가 0으로 멈춰 세우면 달리기도 멈춰요.)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Sprint = {}

local SPRINT_SCALE = 1.5
local player = Players.LocalPlayer

function Sprint.start()
	local held = false
	local normal = 16 -- 평소 속도
	local applied: number? = nil -- 우리가 넣은 달리기 속도 (서버가 바꾼 것과 구분하려고)
	local humanoid: Humanoid? = nil

	local function apply()
		if not humanoid then
			return
		end
		if held and normal > 0 then
			applied = normal * SPRINT_SCALE
			humanoid.WalkSpeed = applied
		elseif applied then
			applied = nil
			humanoid.WalkSpeed = normal
		end
	end

	local function bind(character: Model)
		local found = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if not found then
			return
		end
		humanoid = found
		normal = found.WalkSpeed
		applied = nil
		found:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			if humanoid ~= found then
				return
			end
			local speed = found.WalkSpeed
			if applied and math.abs(speed - applied) < 0.01 then
				return -- 우리가 방금 넣은 값
			end
			normal = speed -- 서버(게임 규칙)가 바꾼 값 → 새 평소 속도
			applied = nil
			apply()
		end)
		apply()
	end
	if player.Character then
		task.spawn(bind, player.Character)
	end
	player.CharacterAdded:Connect(bind)

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.LeftShift and not processed then
			held = true
			apply()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			held = false
			apply()
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		held = false
		apply()
	end)
end

return Sprint
