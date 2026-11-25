-- Studio-only observation. No gameplay decisions or balances are changed here.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local S = require(RS.Shared.SalarySimulation)
local Log = require(RS.Shared.SalarySimulationLog)
local Recorder = {}
function Recorder.start(office, boss, cycle, employees)
	if not S.enabled() then return end
	local function emit(kind, fields)
		fields.kind = kind
		fields.source = "studio_measured"
		fields.time = workspace:GetServerTimeNow()
		fields.day = cycle.day
		fields.minute = cycle.minute
		fields.company = office.companyId
		fields.strategy = S.strategies[math.max(1,cycle.day)] or S.playerType
		Log.write(fields)
	end
	employees.simulationObserve = function(kind, fields)
		emit(kind, fields)
	end
	emit("session", { settings = { protocol = S.protocol, scenario = S.scenario, workshopCase = S.workshopCase, seed = S.seed, rank = S.rank, playerType = S.playerType, days = S.days }, daySeconds = require(RS.Shared.SalaryConfig).DAY_SECONDS })
	emit("environment", { meshFallback = workspace:GetAttribute("SalaryMeshFallback"), meshFailedKinds = workspace:GetAttribute("SalaryMeshFailedKinds") })
	RS:SetAttribute("SimulationAssemblyPoint", office.assemblyPoint)
	RS:SetAttribute("SimulationReady", true)
	local dtSum, dtMax, frames = 0, 0, 0
	RunService.Heartbeat:Connect(function(dt)
		dtSum += dt; dtMax = math.max(dtMax, dt); frames += 1
	end)
	local summaries = {}
	-- 하루 유효 여부를 가리는 집계 (기록만 해요. 게임 판정에는 쓰지 않아요)
	local tally: { [Player]: { workSamples: number, unseated: number, eventSamples: number } } = {}
	cycle:on("dayStart", function()
		emit("day_start", {})
		table.clear(tally)
		-- 이벤트 선택·출근 처리가 끝난 뒤의 시작 조건을 따로 남겨요 (전략 비교는 이 값이 같은 날끼리만)
		task.delay(1, function()
			for _, player in Players:GetPlayers() do
				local row = employees.simulationSnapshot(player)
				if row then
					emit("day_conditions", {
						weekday = RS:GetAttribute("SalaryWeekday"), eventToday = RS:GetAttribute("SalaryEvent") or "",
						rank = row.rank, warnings = row.warnings, bank = row.bank, xp = row.xp, speed = row.speed,
						meshFallback = workspace:GetAttribute("SalaryMeshFallback"), meshFailedKinds = workspace:GetAttribute("SalaryMeshFailedKinds"),
						scenario = S.scenario,
					})
				end
			end
		end)
	end)
	cycle:on("dayEnd", function()
		-- DayCycle dispatches settlement asynchronously; the client also records the exact Payslip.
		task.wait(1)
		for _, player in Players:GetPlayers() do
			local snapshot = employees.simulationSnapshot(player)
			if snapshot then
				emit("day_summary", snapshot)
				summaries[cycle.day] = true
				-- 이 날을 표본에 넣어도 되나: 이유가 하나라도 있으면 전략 수입 비교에서 빼요
				local t = tally[player] or { workSamples = 0, unseated = 0, eventSamples = 0 }
				local reasons = {}
				if snapshot.fired then table.insert(reasons, "fired") end
				if t.unseated > 30 and not S.outside then table.insert(reasons, "unseated_over_30s") end
				if workspace:GetAttribute("SalaryMeshFallback") == true then table.insert(reasons, "mesh_fallback") end
				if S.scenario ~= "natural" then table.insert(reasons, "forced_scenario") end
				if t.workSamples < 200 then table.insert(reasons, "short_day") end
				emit("day_validity", {
					valid = #reasons == 0, reasons = reasons, eventToday = RS:GetAttribute("SalaryEvent") or "",
					validityPolicy = if S.outside then "intentional_outside; navigation failures assessed separately" else "desk",
                    workSamples = t.workSamples, unseatedWorkSeconds = t.unseated, eventSeconds = t.eventSamples,
				})
			end
		end
		if cycle.day >= S.days then
			RS:SetAttribute("SimulationDone", true)
			emit("complete", { requestedDays = S.days })
		end
	end)
	RS:GetAttributeChangedSignal("SalaryEvent"):Connect(function()
		emit("event", { event = RS:GetAttribute("SalaryEvent"), stage = RS:GetAttribute("SalaryEventStage") })
	end)
	RS:GetAttributeChangedSignal("SalaryEventStage"):Connect(function()
		emit("event_stage", { event = RS:GetAttribute("SalaryEvent"), stage = RS:GetAttribute("SalaryEventStage") })
	end)
	-- 봇이 보는 시야 신호는 0.1초마다 갱신해요 (1초 기록 주기에 묶여 반응이 최대 1초 늦던 문제)
	task.spawn(function()
		local previousState = {}
		while not RS:GetAttribute("SimulationDone") do
			for _, player in Players:GetPlayers() do
				if player.Character then
					local seen = boss:canSee(player.Character)
					if player:GetAttribute("SimulationBossVisible") ~= seen then
						player:SetAttribute("SimulationBossVisible", seen)
						emit("sight_signal", {visible = seen})
					end
					local snapshot = employees.simulationSnapshot(player)
					if snapshot and previousState[player] ~= snapshot.state then
						previousState[player] = snapshot.state
						emit("observed_state", {state = snapshot.state, action = snapshot.action, caught = snapshot.caught, playerId = player.UserId})
					end
				end
			end
			task.wait(0.1)
		end
	end)
	task.spawn(function()
		while not RS:GetAttribute("SimulationDone") do
			for _, player in Players:GetPlayers() do
				local row = employees.simulationSnapshot(player)
				if row and player.Character then
					local seen, distance = boss:canSee(player.Character)
					local root = player.Character:FindFirstChild("HumanoidRootPart")
					row.awayGauge = player:GetAttribute("AwayGauge")
                    row.workQuota = player:GetAttribute("WorkQuota")
                    row.bossVisible = seen
					row.distance = if root then (root.Position - boss.root.Position).Magnitude else nil
					row.phase = cycle.phase
					row.seated = player:GetAttribute("Seated")
					row.workshopStatus = player:GetAttribute("WorkshopStatus") or ""
					row.position = if root then {root.Position.X, root.Position.Y, root.Position.Z} else nil
					row.event = RS:GetAttribute("SalaryEvent")
					row.eventStage = RS:GetAttribute("SalaryEventStage")
					row.waiting = cycle.waiting
					row.mission = player:GetAttribute("MissionId")
					row.missionStatus = player:GetAttribute("MissionStatus")
					row.heartbeatMean = if frames > 0 then dtSum / frames else 0
					row.heartbeatMax = dtMax
					row.memoryMb = Stats:GetTotalMemoryUsageMb()
					row.today = nil -- full tables only in daily summaries
					local t = tally[player]
					if not t then
						t = { workSamples = 0, unseated = 0, eventSamples = 0 }
						tally[player] = t
					end
					local stage = RS:GetAttribute("SalaryEventStage") or ""
					local commonEvent = (row.event == "drill" or row.event == "workshop") and stage ~= "" and stage ~= "done"
					if cycle.phase == "work" and not cycle.waiting then
						t.workSamples += 1
						if commonEvent then
							t.eventSamples += 1
						elseif not row.seated and not row.fired and row.workshopStatus == "" then
							t.unseated += 1
						end
					end
					emit("sample", row)
				end
			end
			dtSum = 0; dtMax = 0; frames = 0
			task.wait(1)
		end
	end)
end
return Recorder
