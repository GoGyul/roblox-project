-- 👀 눈치 빠른 이과장
-- 수요일·목요일에만 출근해요 (스튜디오에서는 TEST_LEE면 매일).
-- 직접 혼내지는 않고, 농땡이를 보면 부장님께 고자질해요.
--
-- 행동 순서:
--   1. 사무실을 어슬렁어슬렁 (📱 휴대폰 보는 중 → 이때는 아무것도 안 봐요)
--   2. 머리 위에 ❗ (0.7초 예고)
--   3. 휙 뒤돌아서 가장 가까운 직원 쪽을 2.5초 동안 노려봐요 (👀 이때만 봐요)
-- ☕ [E] 커피 상납: 그날 고자질을 한 번 눈감아 줘요 (Employees가 처리)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local Boss = require(script.Parent.Boss)
local Npc = require(script.Parent.Npc)
local Walker = require(script.Parent.Walker)

local Lee = {}
Lee.__index = Lee

local RANGE = 35 -- (사무실이 넓어져서 24 → 35)
local FOV = math.cos(math.rad(55))
local WARN_SECONDS = 0.7 -- ❗가 뜨고 뒤돌아보기까지
local STARE_SECONDS = 2.5

local LINES = {
	idle = { "(휴대폰 보는 중)", "음~ 오늘 점심 뭐 먹지", "부장님 오늘 기분 어떠시려나~" },
	stare = { "…지금 뭐 해요?", "흐음~?", "다 보고 있어요~" },
	bribed = { "어머, 고마워요~ ☕", "이런 거 안 주셔도 되는데~ (홀짝)", "센스 있으시네~ ☕" },
}

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

function Lee.new(office, dayCycle)
	local model = Npc.create("이과장", {
		skin = Color3.fromRGB(235, 200, 170),
		shirt = Color3.fromRGB(150, 110, 170), -- 보라색 니트 조끼
		pants = Color3.fromRGB(60, 55, 70),
	}, office.folder)
	local self = setmetatable({
		office = office,
		dayCycle = dayCycle,
		model = model,
		humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid,
		root = model:FindFirstChild("HumanoidRootPart") :: BasePart,
		head = model:FindFirstChild("Head") :: BasePart,
		-- Boss.canSee가 쓰는 값들
		active = false,
		watching = false,
		range = RANGE,
		fovCos = FOV,
		token = 0,
		comesBack = false, -- 점심 먹고 돌아올지
		onBribe = nil :: ((Player) -> boolean)?, -- Employees가 채워 줘요
	}, Lee)
	self.humanoid.WalkSpeed = 9

	-- ☕ 커피 상납
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = `☕ 커피 상납 (-{SalaryConfig.LEE_BRIBE_COST}원)`
	prompt.ObjectText = "눈치 빠른 이과장"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 7
	prompt.RequiresLineOfSight = false
	prompt.Parent = self.root
	prompt.Triggered:Connect(function(player)
		if self.active and self.onBribe and self.onBribe(player) then
			self:say(pick(LINES.bribed), 3)
		end
	end)

	model.Parent = nil -- 출근 전에는 숨겨 둬요

	dayCycle:on("dayStart", function(weekday)
		if SalaryConfig.leeWorksOn(weekday.name) then
			self:arrive()
		else
			self:leave()
		end
	end)
	dayCycle:on("lunchStart", function()
		if self.active then
			self:leave()
			self.comesBack = true
		end
	end)
	dayCycle:on("lunchEnd", function()
		if self.comesBack then
			self.comesBack = false
			self:arrive()
		end
	end)
	dayCycle:on("dayEnd", function()
		self.comesBack = false
		self:leave()
	end)
	return self
end

---------------------------------------------------------------------------
function Lee:say(text: string, seconds: number?)
	Npc.say(self.model, text, seconds)
end

-- 지금 이 캐릭터를 보고 있나? (뒤돌아본 2.5초 동안만)
function Lee:sees(character: Model): boolean
	if not self.active or not self.watching then
		return false
	end
	local seen = Boss.canSee(self :: any, character)
	return seen
end

function Lee:arrive()
	self.token += 1
	local token = self.token
	self.model.Parent = self.office.folder
	self.model:PivotTo(CFrame.new(self.office.entrance + Vector3.new(3, 3, 0)))
	self.root:SetNetworkOwner(nil)
	self.active = true
	self.watching = false
	ReplicatedStorage:SetAttribute("LeePresent", true) -- 화면에 "👀 이과장" 버튼과 소개 카드
	Npc.setStatus(self.model, "📱")
	task.spawn(function()
		self:run(token)
	end)
end

function Lee:leave()
	self.token += 1
	self.active = false
	self.watching = false
	self.model.Parent = nil
	ReplicatedStorage:SetAttribute("LeePresent", false)
end

function Lee:wait(seconds: number, token: number): boolean
	local finish = os.clock() + seconds
	while os.clock() < finish do
		if self.token ~= token then
			return false
		end
		task.wait(0.1)
	end
	return self.token == token
end

-- 가장 가까운 플레이어 (뒤돌아볼 방향)
function Lee:nearestPlayer(): BasePart?
	local best, bestDistance = nil, RANGE + 6
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local distance = (root.Position - self.root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = root, distance
			end
		end
	end
	return best
end

function Lee:run(token: number)
	while self.token == token do
		Npc.standUpright(self.model)
		-- 1. 어슬렁어슬렁 (휴대폰 보면서)
		self.watching = false
		Npc.setStatus(self.model, "📱")
		Walker.walkTo(self.humanoid, self.root, pick(self.office.waypoints), function()
			return self.token ~= token
		end)
		if math.random() < 0.25 then
			self:say(pick(LINES.idle), 3)
		end
		if not self:wait(math.random(15, 35) / 10, token) then
			return
		end

		-- 2~3. ❗ 예고 후 휙 뒤돌아보기
		if math.random() < 0.7 then
			local target = self:nearestPlayer()
			if target then
				Npc.setStatus(self.model, "❗")
				if not self:wait(WARN_SECONDS, token) then
					return
				end
				local position = self.root.Position
				local flat = Vector3.new(target.Position.X, position.Y, target.Position.Z)
				if (flat - position).Magnitude > 0.5 then
					self.root.CFrame = CFrame.lookAt(position, flat)
				end
				Npc.setStatus(self.model, "👀")
				self.watching = true
				if math.random() < 0.4 then
					self:say(pick(LINES.stare), 2)
				end
				if not self:wait(STARE_SECONDS, token) then
					return
				end
				self.watching = false
			end
		end
	end
end

return Lee
