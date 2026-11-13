-- 👔 김부장 AI
--
-- 하는 일 (계속 반복):
--   🖥️👀 자기 자리에서 감시   : 모니터 보는 중(🖥️, 안 봄) ↔ 고개 듦(👀, 봄)을 번갈아 해요
--   👞 순찰                  : 복도를 돌아다니며 두리번거려요
--   ❓ 조사                  : 폰 게임 소리, 코 고는 소리가 나면 그 자리로 와요
--   😡 잔소리                : 누군가를 적발하면 그 앞으로 가서 혼내요
--   🍚 점심                  : 12시에 나가서 13시에 돌아와요
--
-- 시야: 부장 앞쪽 부채꼴 안 + 가리는 물건이 없을 때만 보여요.

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local Npc = require(script.Parent.Npc)

local Boss = {}
Boss.__index = Boss

local LOOK = {
	skin = Color3.fromRGB(234, 192, 160),
	shirt = Color3.fromRGB(35, 45, 70), -- 남색 양복
	pants = Color3.fromRGB(40, 40, 45),
}

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

function Boss.new(office)
	local model = Npc.create("김부장", LOOK, office.folder)
	local self = setmetatable({
		office = office,
		model = model,
		humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid,
		root = model:FindFirstChild("HumanoidRootPart") :: BasePart,
		head = model:FindFirstChild("Head") :: BasePart,
		active = false, -- false면 자리에 없음 (점심, 퇴근)
		watching = false, -- true일 때만 직원을 볼 수 있어요
		scolding = false,
		token = 0, -- 하던 행동을 끊을 때마다 1씩 올라가요
		range = 40,
		fovCos = math.cos(math.rad(58)),
		noiseSource = nil :: (() -> (Vector3?, number))?,
	}, Boss)

	-- 빨간 넥타이
	local torso = model:FindFirstChild("UpperTorso") :: BasePart
	if torso then
		local tie = Instance.new("Part")
		tie.Name = "Tie"
		tie.Size = Vector3.new(0.35, 1.3, 0.1)
		tie.Color = Color3.fromRGB(190, 30, 40)
		tie.CanCollide = false
		tie.Massless = true
		tie.CFrame = torso.CFrame * CFrame.new(0, -0.1, -torso.Size.Z / 2 - 0.05)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = torso
		weld.Part1 = tie
		weld.Parent = tie
		tie.Parent = model
	end

	-- 발소리 (가까이 오면 들려요)
	local footsteps = Instance.new("Sound")
	footsteps.Name = "Footsteps"
	footsteps.SoundId = "rbxasset://sounds/action_footsteps_plastic.mp3"
	footsteps.Looped = true
	footsteps.Volume = 1
	footsteps.RollOffMinDistance = 6
	footsteps.RollOffMaxDistance = 45
	footsteps.Parent = self.root
	self.footsteps = footsteps

	model.Parent = nil -- 출근 전에는 숨겨 둬요
	return self
end

---------------------------------------------------------------------------
-- 기본 동작
---------------------------------------------------------------------------
function Boss:status(emoji: string)
	Npc.setStatus(self.model, emoji)
end

function Boss:say(text: string, seconds: number?)
	Npc.say(self.model, text, seconds)
end

function Boss:face(direction: Vector3)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude > 0.01 then
		self.root.CFrame = CFrame.lookAt(self.root.Position, self.root.Position + flat)
	end
end

-- seconds 동안 기다리기. 도중에 다른 행동으로 끊기면 false
function Boss:wait(seconds: number, token: number): boolean
	local finish = os.clock() + seconds
	while os.clock() < finish do
		if self.token ~= token then
			return false
		end
		task.wait(0.1)
	end
	return self.token == token
end

-- 길찾기로 target까지 걸어가기
function Boss:walkTo(target: Vector3, token: number): boolean
	local path = PathfindingService:CreatePath({
		AgentRadius = 1.5,
		AgentHeight = 5,
		AgentCanJump = false,
		WaypointSpacing = 4,
	})
	local ok = pcall(function()
		path:ComputeAsync(self.root.Position, target)
	end)
	local points: { Vector3 } = {}
	if ok and path.Status == Enum.PathStatus.Success then
		for _, waypoint in path:GetWaypoints() do
			table.insert(points, waypoint.Position)
		end
	else
		table.insert(points, target) -- 길을 못 찾으면 그냥 직진
	end

	self.footsteps.Playing = true
	for _, point in points do
		if self.token ~= token then
			break
		end
		self.humanoid:MoveTo(point)
		local done = false
		local connection = self.humanoid.MoveToFinished:Once(function()
			done = true
		end)
		local giveUp = os.clock() + 3
		while not done and os.clock() < giveUp and self.token == token do
			task.wait(0.05)
		end
		connection:Disconnect()
	end
	self.footsteps.Playing = false
	return self.token == token
end

---------------------------------------------------------------------------
-- 시야
---------------------------------------------------------------------------
function Boss:canSee(character: Model): (boolean, number)
	if not self.active or not self.watching or not self.model.Parent then
		return false, math.huge
	end
	local targetHead = character:FindFirstChild("Head") :: BasePart?
	if not targetHead then
		return false, math.huge
	end

	local offset = targetHead.Position - self.head.Position
	local distance = offset.Magnitude
	if distance > self.range then
		return false, distance
	end

	-- 부채꼴 안에 있나? (수평 방향만 비교)
	local look = self.root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z).Unit
	local flatOffset = Vector3.new(offset.X, 0, offset.Z)
	if flatOffset.Magnitude > 0.5 and flatOffset.Unit:Dot(flatLook) < self.fovCos then
		return false, distance
	end

	-- 사이에 가리는 물건(파티션, 벽)이 있나?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.model, character }
	if workspace:Raycast(self.head.Position, offset, params) then
		return false, distance
	end
	return true, distance
end

---------------------------------------------------------------------------
-- 행동들
---------------------------------------------------------------------------
function Boss:watchFromDesk(token: number)
	self.watching = true
	self:status("👞")
	if not self:walkTo(self.office.bossStand, token) then
		return
	end
	self:face(self.office.bossLook)
	local finish = os.clock() + math.random(10, 16)
	while os.clock() < finish do
		self.watching = false
		self:status("🖥️")
		if not self:wait(math.random(20, 40) / 10, token) then
			return
		end
		self.watching = true
		self:status("👀")
		if math.random() < 0.3 then
			self:say(pick(SalaryConfig.BossLines.patrol), 3)
		end
		if not self:wait(math.random(25, 50) / 10, token) then
			return
		end
	end
end

function Boss:patrol(token: number)
	self.watching = true
	for _ = 1, math.random(2, 3) do
		self:status("👞")
		if math.random() < 0.3 then
			self:say(pick(SalaryConfig.BossLines.patrol), 3)
		end
		if not self:walkTo(pick(self.office.waypoints), token) then
			return
		end
		-- 두리번두리번
		self:status("👀")
		for _ = 1, 2 do
			self:face(CFrame.Angles(0, math.rad(math.random(-120, 120)), 0) * self.root.CFrame.LookVector)
			if not self:wait(0.8, token) then
				return
			end
		end
	end
end

function Boss:investigate(position: Vector3, token: number)
	self.watching = true
	self:status("❓")
	self:say(pick(SalaryConfig.BossLines.investigate), 2.5)
	if not self:walkTo(position, token) then
		return
	end
	self:face(Vector3.new(0, 0, -1)) -- 직원 등 뒤에서 모니터 쪽을 들여다봐요
	self:status("👀")
	self:wait(3, token)
end

-- 적발한 직원 앞으로 가서 잔소리
function Boss:scold(character: Model, line: string)
	if not self.active then
		return
	end
	self.token += 1
	local token = self.token
	self.scolding = true
	self.watching = true
	self:status("😡")
	self:say(line, 4)
	task.spawn(function()
		local targetRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if targetRoot then
			local away = self.root.Position - targetRoot.Position
			local stand = targetRoot.Position + (if away.Magnitude > 0.1 then away.Unit * 4 else Vector3.new(0, 0, 4))
			self:walkTo(stand, token)
			if self.token == token then
				self:face(targetRoot.Position - self.root.Position)
			end
		end
		self:wait(3, token)
		if self.token == token then
			self.scolding = false
		end
	end)
end

---------------------------------------------------------------------------
-- 하루 일정
---------------------------------------------------------------------------
function Boss:applyMood(weekday)
	self.humanoid.WalkSpeed = weekday.walkSpeed
	self.fovCos = math.cos(math.rad(weekday.fov))
	self.range = weekday.range
end

function Boss:appearAt(position: Vector3)
	self.model.Parent = self.office.folder
	self.model:PivotTo(CFrame.lookAt(position + Vector3.new(0, 3, 0), position + Vector3.new(0, 3, 0) + self.office.bossLook))
	self.root:SetNetworkOwner(nil) -- 서버가 직접 움직여요
end

function Boss:startDay(weekday)
	self.token += 1
	self.scolding = false
	self:applyMood(weekday)
	self:appearAt(self.office.bossStand)
	self.active = true
end

function Boss:goLunch()
	self.token += 1
	local token = self.token
	self.active = false
	self.scolding = false
	self.watching = false
	self:status("🍚")
	self:say(SalaryConfig.BossLines.lunch, 4)
	task.spawn(function()
		self:walkTo(self.office.entrance, token)
		if self.token == token then
			self.model.Parent = nil
		end
	end)
end

function Boss:backFromLunch()
	self.token += 1
	self.scolding = false
	self:appearAt(self.office.entrance)
	self.active = true
	self:say(SalaryConfig.BossLines.back, 4)
end

function Boss:leaveWork()
	self.token += 1
	self.active = false
	self.scolding = false
	self.watching = false
	self.footsteps.Playing = false
	self.model.Parent = nil
end

-- AI 메인 루프 (서버 시작 시 한 번 실행)
function Boss:run()
	task.spawn(function()
		while true do
			if not self.active or self.scolding then
				task.wait(0.2)
				continue
			end
			local token = self.token
			local noisePosition, noiseChance = nil, 0
			if self.noiseSource then
				noisePosition, noiseChance = self.noiseSource()
			end

			if noisePosition and math.random() < noiseChance then
				self:investigate(noisePosition, token)
			elseif math.random() < 0.4 then
				self:watchFromDesk(token)
			else
				self:patrol(token)
			end
			task.wait(0.1)
		end
	end)
end

return Boss
