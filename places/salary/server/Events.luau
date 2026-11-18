-- 🎲 돌발 이벤트: 하루에 최대 1개
--   🔍 감사 기간: 하루 종일 감사팀이 순찰 (대신 농땡이 수입 ×2)
--   💡 정전: 30초 동안 불과 컴퓨터가 꺼져요 (일해도 돈 0, 자도 안 들켜요)
--   🎂 생일 케이크: 탕비실에 케이크 3조각
--   🚒 소방 훈련: 45초 안에 집결지로 대피 (안 하면 경고)
--
-- 클라이언트에는 ReplicatedStorage 속성으로 알려 줘요:
--   SalaryEvent(이벤트 ID), SalaryEventStage("" / "active" / "rollcall"), SalaryEventEndsAt(서버 시각)
--
-- 🧪 스튜디오에서는 테스트하기 쉽게 매일 이벤트가 순서대로 나오고, 9시 40분쯤 바로 시작해요.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local Boss = require(script.Parent.Boss)
local Npc = require(script.Parent.Npc)
local Walker = require(script.Parent.Walker)

local Events = {}
Events.__index = Events

local IS_STUDIO = RunService:IsStudio()

-- 감사팀 시야
local AUDITOR_RANGE = 26
local AUDITOR_FOV = math.cos(math.rad(50))

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

-- 근무 중 이벤트가 일어날 시각 (점심과 퇴근 직전은 피해요)
local function triggerMinute(): number
	if IS_STUDIO then
		return SalaryConfig.START_MINUTE + 40
	end
	if math.random() < 0.35 then
		return math.random(10 * 60, 10 * 60 + 50) -- 10:00 ~ 10:50
	end
	return math.random(13 * 60 + 20, 16 * 60 + 20) -- 13:20 ~ 16:20
end

function Events.new(office, boss, dayCycle, remotes)
	local self = setmetatable({
		office = office,
		boss = boss,
		dayCycle = dayCycle,
		remotes = remotes,
		current = nil :: SalaryConfig.EventInfo?,
		active = false,
		token = 0,
		lastId = nil :: string?,
		todayId = nil :: string?, -- 오늘 있었던 이벤트 (퇴근 명세서 때도 남아 있어요)
		auditors = {} :: { any },
		saved = nil :: any, -- 정전 전에 원래 조명 값을 기억해 둬요
		-- Employees가 채워 줘요
		snacks = nil :: any,
		onDrillCheck = nil :: ((isInZone: (Vector3) -> boolean) -> ())?,
		notifyAll = nil :: ((string) -> ())?,
	}, Events)

	dayCycle:on("dayStart", function()
		self:beginDay()
	end)
	dayCycle:on("dayEnd", function()
		self.token += 1
		self:cleanup()
		self.current = nil
		self:publish("", 0)
	end)
	return self
end

---------------------------------------------------------------------------
-- 다른 모듈이 물어보는 것들
---------------------------------------------------------------------------
function Events:is(eventId: string): boolean
	return self.active and self.current ~= nil and self.current.id == eventId
end

-- 감사팀 중 누가 이 캐릭터를 보고 있나? (본 사람 중 가장 가까운 거리)
function Events:auditorSees(character: Model): (boolean, number)
	if not self:is("audit") then
		return false, math.huge
	end
	local best = math.huge
	for _, auditor in self.auditors do
		local seen, distance = Boss.canSee(auditor, character)
		if seen and distance < best then
			best = distance
		end
	end
	return best < math.huge, best
end

---------------------------------------------------------------------------
-- 내부
---------------------------------------------------------------------------
function Events:publish(stage: string, seconds: number)
	ReplicatedStorage:SetAttribute("SalaryEvent", if self.current then self.current.id else "")
	ReplicatedStorage:SetAttribute("SalaryEventStage", stage)
	ReplicatedStorage:SetAttribute("SalaryEventEndsAt", if seconds > 0 then workspace:GetServerTimeNow() + seconds else 0)
end

function Events:notify(message: string)
	if self.notifyAll then
		self.notifyAll(message)
	end
end

-- 기다리기 (그 사이 하루가 끝나면 false)
function Events:wait(seconds: number, token: number): boolean
	local waited = 0
	while waited < seconds do
		waited += task.wait(0.25)
		if self.token ~= token then
			return false
		end
	end
	return true
end

function Events:choose()
	local day = self.dayCycle.day
	-- 👀 이과장이 출근하는 날(수·목)에는 감사 기간이 안 나와요 (감시자가 너무 많아지니까)
	local leeToday = SalaryConfig.leeWorksOn(self.dayCycle:weekday().name)
	if IS_STUDIO then
		local forced = SalaryConfig.getEvent(SalaryConfig.TEST_EVENT)
		if forced then
			return forced
		end
		for offset = 0, #SalaryConfig.Events - 1 do
			local event = SalaryConfig.Events[(day - 1 + offset) % #SalaryConfig.Events + 1]
			if not (leeToday and event.id == "audit") then
				return event
			end
		end
		return nil
	end
	if day < 2 or math.random() > SalaryConfig.EVENT_CHANCE then
		return nil
	end
	local candidates = {}
	for _, event in SalaryConfig.Events do
		if event.id ~= self.lastId and not (leeToday and event.id == "audit") then
			table.insert(candidates, event)
		end
	end
	return pick(candidates)
end

function Events:beginDay()
	self.token += 1
	local token = self.token
	self:cleanup()
	local event = self:choose()
	self.current = event
	self.todayId = if event then event.id else nil
	self.active = false
	self:publish("", 0)
	if not event then
		return
	end
	self.lastId = event.id

	if event.allDay then
		self:startAudit(token)
		return
	end

	-- 근무 중 갑자기 (점심시간이면 끝날 때까지 기다려요)
	local at = triggerMinute()
	while self.token == token and (self.dayCycle.minute < at or self.dayCycle.phase ~= "work") do
		task.wait(0.5)
	end
	if self.token ~= token then
		return
	end
	if event.id == "blackout" then
		self:runBlackout(token)
	elseif event.id == "cake" then
		self:runCake()
	elseif event.id == "drill" then
		self:runDrill(token)
	end
end

-- 하루가 끝나거나 새 하루가 시작되면 원래대로
function Events:cleanup()
	self.active = false
	for _, auditor in self.auditors do
		auditor.model:Destroy()
	end
	table.clear(self.auditors)
	self:restoreLights()
	self.office.setAssemblyVisible(false)
end

---------------------------------------------------------------------------
-- 🔍 감사 기간
---------------------------------------------------------------------------
function Events:startAudit(token: number)
	self.active = true
	self:publish("active", 0)
	self:notify("🔍 오늘은 감사 기간! 감사팀이 순찰해요. 대신 농땡이 수입 ×2!")
	local names = { "감사팀 최감사" } -- 감사팀은 한 명이면 충분해요
	for i, name in names do
		local model = Npc.create(name, {
			skin = Color3.fromRGB(math.random(210, 240), math.random(170, 200), math.random(140, 170)),
			shirt = Color3.fromRGB(35, 35, 45), -- 검은 정장
			pants = Color3.fromRGB(25, 25, 30),
		}, self.office.folder)
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
		local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.WalkSpeed = 7
		model:PivotTo(CFrame.new(self.office.entrance + Vector3.new(i * 3 - 3, 3, 0)))
		root:SetNetworkOwner(nil)
		Npc.setStatus(model, "🔍")
		local auditor = {
			-- Boss.canSee가 쓰는 값들
			active = true,
			watching = true,
			model = model,
			head = model:FindFirstChild("Head"),
			root = root,
			range = AUDITOR_RANGE,
			fovCos = AUDITOR_FOV,
		}
		table.insert(self.auditors, auditor)
		task.spawn(function()
			self:patrolAuditor(auditor, humanoid, token)
		end)
	end
end

function Events:patrolAuditor(auditor, humanoid: Humanoid, token: number)
	local lines = { "흠… 영수증 좀 볼까요?", "이 자리는 뭐 하는 분이죠?", "근무 태도 체크 중입니다.", "메모해 둡니다." }
	while self.token == token and auditor.model.Parent do
		-- 점심시간에는 감시 안 해요
		auditor.watching = self.dayCycle.phase == "work"
		Npc.standUpright(auditor.model)
		local target = pick(self.office.waypoints)
		Walker.walkTo(humanoid, auditor.root, target, function()
			return self.token ~= token or auditor.model.Parent == nil
		end)
		if math.random() < 0.3 then
			Npc.say(auditor.model, pick(lines), 3)
		end
		-- 잠깐 서서 두리번두리번
		for _ = 1, 3 do
			if not self:wait(1, token) then
				return
			end
			if auditor.model.Parent then
				local angle = math.rad(math.random(0, 359))
				local position = auditor.root.Position
				auditor.root.CFrame = CFrame.lookAt(position, position + Vector3.new(math.cos(angle), 0, math.sin(angle)))
			end
		end
	end
end

---------------------------------------------------------------------------
-- 💡 정전
---------------------------------------------------------------------------
function Events:runBlackout(token: number)
	self.active = true
	self:publish("active", SalaryConfig.BLACKOUT_SECONDS)
	self:notify("💡 정전! 컴퓨터가 꺼졌어요. 일해도 돈이 안 나오지만, 어두워서 자도 안 들켜요!")
	self.boss:say("뭐야, 정전이야?!", 3)

	local saved = {
		brightness = Lighting.Brightness,
		clockTime = Lighting.ClockTime,
		ambient = Lighting.Ambient,
		outdoor = Lighting.OutdoorAmbient,
		lamps = {},
		screens = {},
	}
	self.saved = saved
	Lighting.Brightness = 0
	Lighting.ClockTime = 0
	Lighting.Ambient = Color3.fromRGB(25, 25, 32)
	Lighting.OutdoorAmbient = Color3.fromRGB(18, 18, 24)
	for _, lamp in self.office.lamps do
		saved.lamps[lamp] = lamp.Color
		lamp.Material = Enum.Material.SmoothPlastic
		lamp.Color = Color3.fromRGB(90, 90, 95)
		local light = lamp:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = false
		end
	end
	for _, desk in self.office.desks do
		local screen = desk.model:FindFirstChild("Screen") :: BasePart?
		if screen then
			saved.screens[screen] = { color = screen.Color, material = screen.Material, transparency = screen.Transparency }
			screen.Color = Color3.fromRGB(10, 10, 12)
			screen.Material = Enum.Material.SmoothPlastic
			screen.Transparency = 0
		end
	end

	if self:wait(SalaryConfig.BLACKOUT_SECONDS, token) then
		self:restoreLights()
		self.active = false
		self:publish("done", 0)
		self:notify("💡 전기가 돌아왔어요! 컴퓨터 다시 켜짐.")
		self.boss:say("자자, 다시 일들 해요!", 3)
	end
end

function Events:restoreLights()
	local saved = self.saved
	if not saved then
		return
	end
	self.saved = nil
	Lighting.Brightness = saved.brightness
	Lighting.ClockTime = saved.clockTime
	Lighting.Ambient = saved.ambient
	Lighting.OutdoorAmbient = saved.outdoor
	for lamp, color in saved.lamps do
		lamp.Material = Enum.Material.Neon
		lamp.Color = color
		local light = lamp:FindFirstChildOfClass("PointLight")
		if light then
			light.Enabled = true
		end
	end
	for screen, look in saved.screens do
		screen.Color = look.color
		screen.Material = look.material
		screen.Transparency = look.transparency
	end
end

---------------------------------------------------------------------------
-- 🎂 생일 케이크
---------------------------------------------------------------------------
function Events:runCake()
	self.active = true
	self:publish("active", 0)
	if self.snacks then
		self.snacks.placeExtra("birthday", self.office.cakeSpots)
	end
	local who = pick({ "옆자리 박대리", "경리팀 윤주임", "막내 인턴 한사원", "김부장님 따님" })
	self:notify(`🎂 {who} 생일이래요! 탕비실 조리대에 케이크 {#self.office.cakeSpots}조각! 먼저 먹는 사람이 임자`)
end

---------------------------------------------------------------------------
-- 🚒 소방 훈련
---------------------------------------------------------------------------
function Events:runDrill(token: number)
	local office = self.office
	self.active = true
	self:publish("active", SalaryConfig.DRILL_SECONDS)
	office.setAssemblyVisible(true)
	self.boss:evacuate(office.assemblyPoint)
	self:notify(`🚨 소방 훈련! {SalaryConfig.DRILL_SECONDS}초 안에 출입문 앞 초록색 집결지로! (점프하면 의자에서 일어나요)`)

	if not self:wait(SalaryConfig.DRILL_SECONDS, token) then
		return
	end
	-- 인원 점검
	if self.onDrillCheck then
		local zone = office.assemblyZone
		self.onDrillCheck(function(position: Vector3): boolean
			local offset = zone.CFrame:PointToObjectSpace(position)
			return math.abs(offset.X) <= zone.Size.X / 2 and math.abs(offset.Y) <= zone.Size.Y / 2 and math.abs(offset.Z) <= zone.Size.Z / 2
		end)
	end
	self:publish("rollcall", SalaryConfig.DRILL_ROLLCALL_SECONDS)
	self.boss:say("인원 점검 끝! 잠깐 쉬었다가 자리로!", 4)

	if not self:wait(SalaryConfig.DRILL_ROLLCALL_SECONDS, token) then
		return
	end
	office.setAssemblyVisible(false)
	self.active = false
	self:publish("done", 0)
	self.boss:resume()
	self:notify("🚒 훈련 끝! 다시 자리로 돌아가세요. 부장님 감시 재개!")
end

return Events
