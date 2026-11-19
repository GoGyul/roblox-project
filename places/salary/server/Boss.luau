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

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local Npc = require(script.Parent.Npc)
local Walker = require(script.Parent.Walker)

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
		summon = nil :: Vector3?, -- 이과장이 고자질한 위치
		distractedUntil = 0, -- 😺 고양이한테 정신 팔린 시각까지 (감시 멈춤)
		stareAt = nil :: Model?, -- 👀 사무실 밖에서 들킨 사람 (계속 노려봐요)
		stareUntil = 0,
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

---------------------------------------------------------------------------
-- 👀 노려보기: 사무실 밖(옥상·공원·거리)에서 농땡이를 들키면 하던 걸 멈추고 그 사람만 봐요
---------------------------------------------------------------------------
function Boss:isStaring(): boolean
	local target = self.stareAt
	return target ~= nil
		and target.Parent ~= nil
		and os.clock() < self.stareUntil
		and self.active
		and self.watching
		and not self.scolding
		and self.model.Parent ~= nil
end

-- 보일 때마다 불러요 (안 보이면 BOSS_STARE_GRACE초 뒤 풀려요)
function Boss:stare(character: Model)
	if self.stareAt ~= character and self:isStaring() then
		return -- 이미 다른 사람을 노려보는 중
	end
	local fresh = not self:isStaring()
	self.stareAt = character
	self.stareUntil = os.clock() + SalaryConfig.BOSS_STARE_GRACE
	if fresh then
		self:status("😠")
		self:say(pick({ "거기! 사무실 밖에서 뭐 하나?", "흠… 자네 지금 근무 시간 아닌가?", "어디 보자… 계속 지켜볼 거야." }), 3)
	end
end

-- 노려보는 동안은 제자리에 서서 그 사람 쪽만 봐요
function Boss:holdStare(token: number)
	if not self:isStaring() then
		return
	end
	self.footsteps.Playing = false
	while self:isStaring() and self.token == token do
		self.humanoid:MoveTo(self.root.Position)
		local targetRoot = (self.stareAt :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
		if targetRoot then
			self:face(targetRoot.Position - self.root.Position)
		end
		task.wait(0.1)
	end
	self.stareAt = nil
	if self.token == token and self.active and not self.scolding then
		self:status("👀")
	end
end

-- seconds 동안 기다리기. 도중에 다른 행동으로 끊기면 false
function Boss:wait(seconds: number, token: number): boolean
	local finish = os.clock() + seconds
	while os.clock() < finish do
		if self.token ~= token then
			return false
		end
		self:holdStare(token)
		task.wait(0.1)
	end
	return self.token == token
end

-- 길찾기로 target까지 걸어가기 (도중에 다른 행동으로 끊기면 false)
--   👀 가다가 누굴 노려보게 되면 멈췄다가, 다 보고 나서 다시 걸어가요
function Boss:walkTo(target: Vector3, token: number): boolean
	while true do
		self:holdStare(token)
		if self.token ~= token then
			return false
		end
		self.footsteps.Playing = true
		local arrived = Walker.walkTo(self.humanoid, self.root, target, function()
			return self.token ~= token or self:isStaring()
		end)
		self.footsteps.Playing = false
		if not self:isStaring() then
			return arrived
		end
	end
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
		-- 🏢 부장님은 사무실 안만 순찰해요 (공원·거리는 👮 경비원 담당)
		local inside = {}
		for _, point in self.office.waypoints do
			if self.office.insideOffice(point) then
				table.insert(inside, point)
			end
		end
		if not self:walkTo(pick(if #inside > 0 then inside else self.office.waypoints), token) then
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
	self.stareAt = nil -- 혼내러 가면 노려보기는 끝
	self.scolding = true
	self.watching = true
	self.model:SetAttribute("Pose", "scold")
	self:status("😡")
	self:say(line, 4)
	task.spawn(function()
		local targetRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if targetRoot then
			local away = self.root.Position - targetRoot.Position
			local stand = targetRoot.Position + (if away.Magnitude > 0.1 then away.Unit * 4 else Vector3.new(0, 0, 4))
			-- 의자에 앉아 있으면 의자 뒤에 서요 (책상 쪽으로 가면 책상 위로 올라가 버려요)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local seat = humanoid and humanoid.SeatPart
			if seat then
				local back = -seat.CFrame.LookVector
				stand = seat.Position + Vector3.new(back.X, 0, back.Z).Unit * 3.5
			end
			self:walkTo(stand, token)
			if self.token == token then
				self:face(targetRoot.Position - self.root.Position)
			end
		end
		self:wait(3, token)
		self.model:SetAttribute("Pose", nil)
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

-- ✈️ 쿠폰: 급한 출장 (사무실을 비워요)
function Boss:goTrip()
	self.token += 1
	local token = self.token
	self.active = false
	self.scolding = false
	self.watching = false
	self:status("✈️")
	self:say("뭐? 급한 출장이라고? …금방 다녀오지!", 4)
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

-- 😺 고양이한테 정신이 팔렸어요: seconds 동안 멈춰서 고양이만 봐요 (감시 안 함)
function Boss:distract(seconds: number, lookAt: Vector3)
	if not self.active or self.scolding then
		return
	end
	self.token += 1
	self.distractedUntil = os.clock() + seconds
	self.watching = false
	self.footsteps.Playing = false
	self:face(lookAt - self.root.Position)
	self:status("😻")
	self:say("어머, 고양이다~ 쮸쮸쮸 😺", seconds)
end

-- 👀 이과장이 고자질하면 하던 걸 멈추고 그 자리로 바로 와요
function Boss:callTo(position: Vector3)
	if not self.active or self.scolding then
		return
	end
	self.token += 1
	self.summon = position
end

-- 🌸 워크숍 술래: 감시를 멈추고 이 자리에 서요
function Boss:host(position: Vector3, look: Vector3)
	if self.model.Parent == nil then
		self:appearAt(position) -- ✈️ 출장 중이었어도 행사엔 나타나요
	end
	self.token += 1
	self.active = false
	self.scolding = false
	self.watching = false
	self.footsteps.Playing = false
	self.model:PivotTo(CFrame.lookAt(position + Vector3.new(0, 3, 0), position + Vector3.new(0, 3, 0) - look))
	self:status("🌸")
end

-- 🍻 회식 자리에 나타나기 / 회식 끝나면 퇴근
function Boss:joinDinner(position: Vector3, look: Vector3)
	self.token += 1
	self.active = false
	self.watching = false
	self.model.Parent = self.office.folder
	self.model:PivotTo(CFrame.lookAt(position + Vector3.new(0, 3, 0), position + Vector3.new(0, 3, 0) + look))
	self.root:SetNetworkOwner(nil)
	self:status("🍻")
end

function Boss:leaveDinner()
	self.model.Parent = nil
end

-- 🚒 소방 훈련: 감시를 멈추고 집결지로 가요
function Boss:evacuate(position: Vector3)
	if self.model.Parent == nil then
		self:appearAt(self.office.entrance) -- ✈️ 출장 중이었으면 훈련하러 돌아와요
	end
	self.token += 1
	local token = self.token
	self.active = false
	self.scolding = false
	self.watching = false
	self:status("📢")
	self:say("소방 훈련입니다! 다들 집결지로!", 4)
	task.spawn(function()
		self:walkTo(position, token)
	end)
end

-- 훈련이 끝나면 다시 감시 시작
function Boss:resume()
	if self.model.Parent == nil then
		return -- (점심·퇴근 중이면 원래 일정대로 돌아와요)
	end
	self.token += 1
	self.scolding = false
	self.active = true
end

-- AI 메인 루프 (서버 시작 시 한 번 실행)
function Boss:run()
	task.spawn(function()
		while true do
			if not self.active or self.scolding then
				task.wait(0.2)
				continue
			end
			if os.clock() < self.distractedUntil then
				self.watching = false -- 😺 고양이 보는 중
				task.wait(0.2)
				continue
			end
			Npc.standUpright(self.model) -- 혹시 넘어져 있으면 바로 세워요
			local token = self.token
			local summon = self.summon
			if summon then
				self.summon = nil
				self:say("뭐? 어디 어디!", 2)
				self:investigate(summon, token)
				task.wait(0.1)
				continue
			end
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
