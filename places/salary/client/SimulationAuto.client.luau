-- Uses real RemoteEvents, including the game's own return delay. No money/XP injection.
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local S = require(RS:WaitForChild("Shared"):WaitForChild("SalarySimulation"))
if not S.enabled() then return end
local Log = require(RS.Shared.SalarySimulationLog)
local Config = require(RS.Shared.SalaryConfig)
local player = Players.LocalPlayer
local remotes = RS:WaitForChild("Remotes")
local rng = Random.new(S.seed)
local types = {
	cautious = { ratio = 0.4, late = 0.05, actions = { "blank", "webtoon" } },
	normal = { ratio = 0.55, late = 0.15, actions = { "webtoon", "phone", "shopping" } },
	greedy = { ratio = 0.7, late = 0.3, actions = { "shopping", "sleep", "recline" } },
	novice = { ratio = 0.5, late = 0.45, actions = { "phone" } },
}
local behavior = types[S.playerType]
local strategyDay = -1
remotes:WaitForChild("Payslip").OnClientEvent:Connect(function(slip)
	slip.kind = "payslip"; slip.source = "studio_measured"
	Log.write(slip)
end)
if S.outside then
 require(script.Parent.SimulationOutside).run(S, player, remotes, Log)
 return
end
local wasVisible, reactAt, chooseAt = false, math.huge, 0
local lastAction = ""
local sightAt, reactionId, reactionLate, reactionSent = 0, 0, false, false
local signalAt = workspace:GetServerTimeNow()
player:GetAttributeChangedSignal("SimulationBossVisible"):Connect(function()
	if player:GetAttribute("SimulationBossVisible") then signalAt = workspace:GetServerTimeNow() end
end)
local function reactionLog(kind, fields)
	fields.kind = kind; fields.source = "studio_measured"; fields.day = RS:GetAttribute("SalaryDay")
	fields.time = workspace:GetServerTimeNow(); fields.reactionId = reactionId
	Log.write(fields)
end
local characterReadyAt = math.huge
local function characterReady(character)
	character:WaitForChild("HumanoidRootPart")
	-- Arrival moves the first character after 0.6 s. Clock in after it finishes.
	characterReadyAt = os.clock() + 2
end
player.CharacterAdded:Connect(characterReady)
if player.Character then task.spawn(characterReady, player.Character) end
-- Exercise the real workshop outcomes through walking, never by changing status.
task.spawn(function()
	local previous = ""
	while not RS:GetAttribute("SimulationDone") do
		local status = player:GetAttribute("WorkshopStatus") or ""
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if status ~= previous then
			Log.write({kind = "workshop_status", status = status, case = S.workshopCase, time = workspace:GetServerTimeNow(), day = RS:GetAttribute("SalaryDay")})
			previous = status
		end
		if S.scenario == "workshop" and status ~= "" and humanoid and root then
			local stage = RS:GetAttribute("SalaryEventStage")
			local goal = RS:GetAttribute("SimulationAssemblyPoint")
			local walk = status == "playing" and ((S.workshopCase == "finish" and stage == "chant") or (S.workshopCase == "out" and stage == "look"))
			humanoid:MoveTo(if walk and goal then goal else root.Position)
		end
		task.wait(0.05)
	end
end)
-- Return after a forced event using walking and the ordinary owned-seat prompt.
-- Never teleport or directly set SeatPart / payroll / suspicion.
task.spawn(function()
	local Pathfinding = game:GetService("PathfindingService")
	local seatCache: Instance? = nil
	local awaySince: number? = nil -- 자리에서 떨어진 채 복귀를 시도하기 시작한 시각
	local attempts, stuckLogged, seatMissingLogged = 0, false, false
	local function log(fields)
		fields.source = "studio_measured"; fields.day = RS:GetAttribute("SalaryDay"); fields.time = workspace:GetServerTimeNow()
		Log.write(fields)
	end
	while not RS:GetAttribute("SimulationDone") do
		task.wait(2)
		if player:GetAttribute("Seated") then
			if awaySince then
				log({ kind = "navigation_done", seconds = os.clock() - awaySince, attempts = attempts })
			end
			awaySince = nil; attempts = 0; stuckLogged = false
		end
		-- 다 같이 하는 이벤트(소방 훈련·워크숍)가 진행 중이면 자리로 돌아가지 않아요 (끝난 뒤에만)
		do
			local event, stage = RS:GetAttribute("SalaryEvent"), RS:GetAttribute("SalaryEventStage") or ""
			if (event == "drill" or event == "workshop") and stage ~= "" and stage ~= "done" then continue end
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 or RS:GetAttribute("SalaryWaiting")
			or RS:GetAttribute("SalaryPhase") == "offwork" or player:GetAttribute("Seated")
			or player:GetAttribute("Fired") or player:GetAttribute("WorkshopStatus") ~= nil then continue end
		local seat = seatCache
		if not seat or not seat:IsDescendantOf(workspace) or seat:GetAttribute("OwnerId") ~= player.UserId then
			seat = nil
			for _, instance in workspace:GetDescendants() do
				if instance:IsA("Seat") and instance:GetAttribute("OwnerId") == player.UserId then seat = instance; break end
			end
			seatCache = seat
		end
		if not seat then
			if not seatMissingLogged then
				seatMissingLogged = true
				log({ kind = "navigation_seat_missing" })
			end
			continue
		end
		seatMissingLogged = false
		awaySince = awaySince or os.clock()
		attempts += 1
		local path = Pathfinding:CreatePath({ AgentRadius = 1.5, AgentHeight = 5, AgentCanJump = true })
		local ok = false
		-- The desk can cover the front of the chair. Try walkable approaches around
		-- it, all within the ordinary prompt radius, instead of one blocked point.
		for i = 0, 7 do
			local angle = i * math.pi / 4
			local offset = -seat.CFrame.LookVector * math.cos(angle) * 4 + seat.CFrame.RightVector * math.sin(angle) * 4
			local target = Vector3.new(seat.Position.X + offset.X, root.Position.Y, seat.Position.Z + offset.Z)
			ok = pcall(function() path:ComputeAsync(root.Position, target) end)
			if ok and path.Status == Enum.PathStatus.Success then break end
		end
		if ok and path.Status == Enum.PathStatus.Success then
			for _, waypoint in path:GetWaypoints() do
				if player:GetAttribute("Seated") or player:GetAttribute("WorkshopStatus") ~= nil or player:GetAttribute("Fired") or RS:GetAttribute("SalaryPhase") == "offwork" then break end
				if waypoint.Action == Enum.PathWaypointAction.Jump then humanoid.Jump = true end
				humanoid:MoveTo(waypoint.Position)
				local deadline = os.clock() + 6
				repeat task.wait(0.1) until Vector2.new(root.Position.X - waypoint.Position.X, root.Position.Z - waypoint.Position.Z).Magnitude < 2 or os.clock() > deadline or player:GetAttribute("Seated")
				if os.clock() > deadline then break end
			end
		elseif humanoid.Health > 0 and root.Parent then
			-- 경로를 못 찾았을 때: 의자 쪽으로 3초만 똑바로 걸어 봐요 (순간이동은 하지 않아요)
			humanoid:MoveTo(Vector3.new(seat.Position.X, root.Position.Y, seat.Position.Z))
			local deadline = os.clock() + 3
			repeat task.wait(0.1) until (root.Position - seat.Position).Magnitude <= 5 or os.clock() > deadline or player:GetAttribute("Seated")
			humanoid:MoveTo(root.Position)
		end
		local prompt = seat:FindFirstChild("SitPrompt")
		if prompt and prompt:IsA("ProximityPrompt") and (root.Position - seat.Position).Magnitude <= prompt.MaxActivationDistance then
			prompt:InputHoldBegin()
			task.wait(math.max(0.1, prompt.HoldDuration + 0.1))
			prompt:InputHoldEnd()
		end
		log({ kind = "navigation", seated = player:GetAttribute("Seated"), pathStatus = tostring(path.Status), attempt = attempts,
			seatDistance = (root.Position - seat.Position).Magnitude, position = { root.Position.X, root.Position.Y, root.Position.Z },
			secondsAway = os.clock() - (awaySince or os.clock()) })
		-- 20초 넘게 못 돌아오면 한 번만 표시해요 (이 날은 표본에서 빼야 해요)
		if not stuckLogged and awaySince and os.clock() - awaySince > 20 and not player:GetAttribute("Seated") then
			stuckLogged = true
			log({ kind = "nav_stuck", attempts = attempts, pathStatus = tostring(path.Status), seatDistance = (root.Position - seat.Position).Magnitude })
		end
	end
end)
local function act(id)
	if id ~= lastAction or player:GetAttribute("SalaryAction") ~= id then
		remotes.SetAction:FireServer(id)
		lastAction = id
	end
end
while not RS:GetAttribute("SimulationDone") do
	local day = RS:GetAttribute("SalaryDay") or 0
	if day ~= strategyDay then
		strategyDay = day
		local strategy = S.strategies[math.max(1,day)] or S.playerType
		behavior = types[strategy]
		Log.write({ kind = "strategy", source = "studio_measured", day = day, strategy = strategy })
		wasVisible = false; reactAt = math.huge; chooseAt = 0; lastAction = ""
	end
	if RS:GetAttribute("SalaryWaiting") and player:GetAttribute("Rank") and RS:GetAttribute("SimulationReady") and os.clock() >= characterReadyAt then
		remotes.ClockIn:FireServer("desk")
	elseif RS:GetAttribute("SalaryPhase") ~= "offwork" and player:GetAttribute("Seated") and not player:GetAttribute("Fired") then
		local now = os.clock()
		local visible = player:GetAttribute("SimulationBossVisible") == true
		if visible and not wasVisible then
			reactionLate = rng:NextNumber() < behavior.late
			local extra = if reactionLate then rng:NextNumber(2, 5) else 0
			reactAt = now + 0.5 + extra
			sightAt = signalAt; reactionId += 1; reactionSent = false
			reactionLog("reaction_start", {signalAt = sightAt, late = reactionLate, scheduledDelay = 0.5 + extra, action = player:GetAttribute("SalaryAction"), lastRequestedAction = lastAction})
		end
		if visible and now >= reactAt then
			if not reactionSent then
				reactionSent = true
				reactionLog("reaction_request", {signalAt = sightAt, late = reactionLate, elapsed = workspace:GetServerTimeNow() - sightAt, previousAction = lastAction})
			end
			act("work")
		elseif not visible and now >= chooseAt then
			chooseAt = now + 8
			local quotaLeft = (player:GetAttribute("WorkQuota") or 75) - (player:GetAttribute("WorkSeconds") or 0)
			local slack = RS:GetAttribute("SalaryPhase") == "lunch" or (quotaLeft <= 0 and rng:NextNumber() < behavior.ratio)
			local available = {}
			for _, id in behavior.actions do
				if (Config.States[id].unlockRank or 1) <= (player:GetAttribute("Rank") or 1) then table.insert(available, id) end
			end
			act(if slack and #available > 0 then available[rng:NextInteger(1, #available)] else "work")
		end
		wasVisible = visible
	end
	task.wait(0.25)
end
