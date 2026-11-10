-- 체크포인트 저장, 죽는 발판, 골인 처리를 담당해요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StageService = {}

-- 닿은 부품이 어느 플레이어 캐릭터의 일부인지 찾아요
local function getCharacter(hit: BasePart): (Model?, Player?)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return nil, nil
	end
	return character, Players:GetPlayerFromCharacter(character)
end

function StageService.start(course)
	local totalStages = #course.checkpoints
	ReplicatedStorage:SetAttribute("TotalStages", totalStages)

	local stageValues: { [Player]: IntValue } = {}

	-- 죽는 발판
	for _, part in course.killParts do
		part.Touched:Connect(function(hit)
			local character = getCharacter(hit)
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid.Health = 0
			end
		end)
	end

	-- 체크포인트
	for index, checkpoint in course.checkpoints do
		checkpoint.Touched:Connect(function(hit)
			local _, player = getCharacter(hit)
			local stage = player and stageValues[player]
			if stage and index > stage.Value then
				stage.Value = index
			end
		end)
	end

	-- 골인 (마지막 체크포인트까지 왔을 때만 인정)
	course.finish.Touched:Connect(function(hit)
		local _, player = getCharacter(hit)
		local stage = player and stageValues[player]
		if not (player and stage) or stage.Value < totalStages or player:GetAttribute("ClearTime") then
			return
		end
		local elapsed = workspace:GetServerTimeNow() - player:GetAttribute("StartTime")
		player:SetAttribute("ClearTime", elapsed)
		print(`🏆 {player.Name} 님이 {string.format("%.1f", elapsed)}초 만에 클리어!`)
	end)

	local function onPlayerAdded(player: Player)
		-- 리더보드(오른쪽 위)에 스테이지 표시
		local leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		local stage = Instance.new("IntValue")
		stage.Name = "스테이지"
		stage.Value = 1
		stage.Parent = leaderstats
		leaderstats.Parent = player
		stageValues[player] = stage

		player:SetAttribute("StartTime", workspace:GetServerTimeNow())

		-- 다시 태어날 때 마지막 체크포인트로 이동
		player.CharacterAdded:Connect(function(character)
			if stage.Value <= 1 then
				return -- 첫 스테이지는 스폰 지점에서 시작
			end
			character:WaitForChild("HumanoidRootPart")
			task.wait()
			local checkpoint = course.checkpoints[stage.Value]
			character:PivotTo(checkpoint.CFrame + Vector3.new(0, 4, 0))
		end)

		print(`{player.Name} 님이 게임에 들어왔어요!`)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		stageValues[player] = nil
	end)
end

return StageService
