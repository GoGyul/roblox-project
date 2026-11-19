-- 🚶 NPC 걷기 도우미: 길찾기(PathfindingService)로 책상을 피해 목적지까지 걸어가요.
-- 김부장과 동료 직원이 함께 써요.

local PathfindingService = game:GetService("PathfindingService")

local Walker = {}

-- humanoid를 target까지 걷게 해요.
-- isCancelled()가 true를 돌려주면 중간에 멈춰요. 끝까지 갔으면 true.
function Walker.walkTo(humanoid: Humanoid, root: BasePart, target: Vector3, isCancelled: () -> boolean): boolean
	local path = PathfindingService:CreatePath({
		AgentRadius = 1.5,
		AgentHeight = 5,
		AgentCanJump = false,
		WaypointSpacing = 4,
	})
	local ok = pcall(function()
		path:ComputeAsync(root.Position, target)
	end)
	local points: { Vector3 } = {}
	if ok and path.Status == Enum.PathStatus.Success then
		for _, waypoint in path:GetWaypoints() do
			table.insert(points, waypoint.Position)
		end
	else
		table.insert(points, target) -- 길을 못 찾으면 그냥 직진
	end

	for _, point in points do
		if isCancelled() then
			return false
		end
		humanoid:MoveTo(point)
		local done = false
		local connection = humanoid.MoveToFinished:Once(function()
			done = true
		end)
		local giveUp = os.clock() + 3
		local lastPosition = root.Position
		local stuckSince = os.clock()
		while not done and os.clock() < giveUp and not isCancelled() do
			task.wait(0.05)
			-- 1초 넘게 거의 못 움직였으면 끼인 거예요 → 가려던 쪽으로 살짝 밀어서 빠져나와요 (NPC는 점프 금지)
			if (root.Position - lastPosition).Magnitude > 0.3 then
				lastPosition = root.Position
				stuckSince = os.clock()
			elseif os.clock() - stuckSince > 1 then
				local toward = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
				if toward.Magnitude > 0.1 and not humanoid.SeatPart then -- 의자에 붙어 있으면 의자까지 끌려가니까 안 밀어요
					root.CFrame += toward.Unit * 1 -- (위로 띄우면 물건 속에 끼었다가 하늘로 튕겨서, 옆으로만)
				end
				stuckSince = os.clock()
			end
		end
		connection:Disconnect()
	end
	return not isCancelled()
end

return Walker
