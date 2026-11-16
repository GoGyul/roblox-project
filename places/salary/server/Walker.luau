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
		while not done and os.clock() < giveUp and not isCancelled() do
			task.wait(0.05)
		end
		connection:Disconnect()
	end
	return not isCancelled()
end

return Walker
