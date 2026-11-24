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
local Players = game:GetService("Players")
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
local AUDITOR_RANGE = 36 -- (사무실이 넓어져서 26 → 36)
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
		return math.random(10 * 60, 10 * 60 + 30) -- 10:00 ~ 10:30 (점심 전에 끝나게)
	end
	return math.random(13 * 60 + 20, 16 * 60 + 20) -- 13:20 ~ 16:20
end

function Events.new(office, boss, dayCycle, remotes, coworkers)
	local self = setmetatable({
		office = office,
		boss = boss,
		dayCycle = dayCycle,
		remotes = remotes,
		coworkers = coworkers, -- 🌸 워크숍에 동료 NPC도 참가
		current = nil :: SalaryConfig.EventInfo?,
		active = false,
		token = 0,
		lastId = nil :: string?,
		todayId = nil :: string?, -- 오늘 있었던 이벤트 (퇴근 명세서 때도 남아 있어요)
		auditors = {} :: { any },
		disguised = nil :: any, -- 🕶️ 동료로 위장한 감사관 { coworker, watcher }
		auditRevealed = false, -- 정체가 밝혀졌으면 감사 끝 (농땡이 수입 ×2는 그대로)
		saved = nil :: any, -- 정전 전에 원래 조명 값을 기억해 둬요
		-- Employees가 채워 줘요
		snacks = nil :: any,
		onDrillCheck = nil :: ((isInZone: (Vector3) -> boolean) -> ())?,
		canJoinWorkshop = nil :: ((Player) -> boolean)?,
		onWorkshopFinish = nil :: ((Player, number) -> ())?, -- (플레이어, 등수)
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

-- 📸 감사관 중 누가 이 캐릭터를 보고 있나? → 보고 있는 감사관 (없으면 nil)
--   (감사관은 의심도를 올리지 않고, 대신 증거 사진을 찍어요 → Employees)
function Events:auditWatcher(character: Model): any?
	if not self:is("audit") or self.auditRevealed then
		return nil
	end
	local watchers = table.clone(self.auditors)
	if self.disguised and self.disguised.coworker.model.Parent then
		table.insert(watchers, self.disguised.watcher)
	end
	for _, watcher in watchers do
		if Boss.canSee(watcher, character) then
			return watcher
		end
	end
	return nil
end

-- 📷 감사관이 카메라를 들어요 (머리 위 📷)
function Events:auditAim(watcher: any, seconds: number)
	if self.disguised and watcher == self.disguised.watcher then
		self.coworkers.aim(self.disguised.coworker, seconds)
	else
		Npc.setStatus(watcher.model, "📷")
		task.delay(seconds, function()
			if watcher.model.Parent then
				Npc.setStatus(watcher.model, "🔍")
			end
		end)
	end
end

-- 이 동료가 위장 감사관인가?
function Events:isDisguisedAuditor(coworker: any): boolean
	return self:is("audit") and not self.auditRevealed and self.disguised ~= nil and self.disguised.coworker == coworker
end

-- 🕶️ 정체 폭로! 감사관은 떠나고, 오늘 감사는 끝
function Events:revealAuditor(revealer: Player)
	if not self.disguised or self.auditRevealed then
		return
	end
	self.auditRevealed = true
	self:publish("revealed", 0) -- (화면 위쪽 알림 바꾸기)
	self.coworkers.setAuditMode(false)
	self.coworkers.revealAuditor(self.disguised.coworker, `…{revealer.DisplayName} 씨, 눈썰미가 좋군요. 오늘 감사는 여기까지 하죠.`)
	self:notify(`🕶️ {revealer.DisplayName}님이 위장 감사관의 정체를 밝혀냈어요! 감사 끝, 📸 사진도 모두 폐기!`, true)
end

---------------------------------------------------------------------------
-- 내부
---------------------------------------------------------------------------
function Events:publish(stage: string, seconds: number)
	ReplicatedStorage:SetAttribute("SalaryEvent", if self.current then self.current.id else "")
	ReplicatedStorage:SetAttribute("SalaryEventStage", stage)
	ReplicatedStorage:SetAttribute("SalaryEventEndsAt", if seconds > 0 then workspace:GetServerTimeNow() + seconds else 0)
end

-- officeOnly: 사무실 안에서만 알 수 있는 소식 (옥상·공원에 있으면 안 보내요)
function Events:notify(message: string, officeOnly: boolean?)
	if self.notifyAll then
		self.notifyAll(message, officeOnly)
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
	elseif event.id == "workshop" then
		self:runWorkshop(token)
	end
end

-- 이벤트가 끝나면 부장님 감시 재개 (점심시간이면 점심 끝날 때 알아서 돌아와요)
function Events:resumeBoss()
	if self.dayCycle.phase == "work" then
		self.boss:resume()
	end
end

-- 하루가 끝나거나 새 하루가 시작되면 원래대로
function Events:cleanup()
	self.active = false
	for _, auditor in self.auditors do
		auditor.model:Destroy()
	end
	table.clear(self.auditors)
	if self.coworkers then
		self.coworkers.setAuditMode(false) -- 🕶️ 위장 감사관도 원래 동료로
	end
	self.disguised = nil
	self.auditRevealed = false
	self:restoreLights()
	self.office.setAssemblyVisible(false)
	if self.coworkers then
		self.coworkers.returnAll(true) -- 이벤트 중에 하루가 끝났으면 동료들은 바로 자리로
	end
	-- 🌸 워크숍 중에 하루가 끝나면 걷는 속도를 원래대로
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("WorkshopStatus") then
			player:SetAttribute("WorkshopStatus", nil)
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = SalaryConfig.walkSpeed(player, 16) -- ⚡ 민첩성 보너스 포함 평소 속도
			end
		end
	end
end

---------------------------------------------------------------------------
-- 🔍 감사 기간
---------------------------------------------------------------------------
function Events:startAudit(token: number)
	self.active = true
	self.auditRevealed = false
	self:publish("active", 0)
	-- 🕶️ 동료 중 한 명이 몰래 감사관!
	local coworker = self.coworkers and self.coworkers.pickAuditor()
	if coworker then
		self.disguised = {
			coworker = coworker,
			-- Boss.canSee가 쓰는 값들
			watcher = {
				active = true,
				watching = true,
				model = coworker.model,
				head = coworker.model:FindFirstChild("Head"),
				root = coworker.root,
				range = AUDITOR_RANGE,
				fovCos = AUDITOR_FOV,
			},
		}
		self.coworkers.setAuditMode(true)
		self:notify(
			"🔍 감사 기간! 감사관이 동료 중 한 명으로 위장했대요… 📸 농땡이를 찍히면 안 돼요! (수상한 동료에게 [R]) 대신 농땡이 수입 ×2!"
		)
		return
	end
	-- 동료가 아무도 없으면 (모든 자리에 플레이어) 예전처럼 검은 정장 감사팀이 와요
	self:notify("🔍 오늘은 감사 기간! 감사팀이 순찰하며 📸 농땡이를 찍어요. 대신 농땡이 수입 ×2!")
	local names = { "감사팀 최감사" } -- 감사팀은 한 명이면 충분해요
	for i, name in names do
		local model = Npc.create(name, {
			skin = Color3.fromRGB(math.random(210, 240), math.random(170, 200), math.random(140, 170)),
			shirt = Color3.fromRGB(35, 35, 45), -- 검은 정장
			pants = Color3.fromRGB(25, 25, 30),
		}, self.office.folder)
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
		local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		humanoid.WalkSpeed = 10
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
	self:notify("💡 정전! 컴퓨터가 꺼졌어요. 일해도 돈이 안 나오지만, 어두워서 자도 안 들켜요!", true)
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
		self:notify("💡 전기가 돌아왔어요! 컴퓨터 다시 켜짐.", true)
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
	self:notify(`🎂 {who} 생일이래요! 탕비실 조리대에 케이크 {#self.office.cakeSpots}조각! 먼저 먹는 사람이 임자`, true)
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
	self:notify(`🚨 소방 훈련! {SalaryConfig.DRILL_SECONDS}초 안에 사무실 창가의 초록색 집결지로! (점프하면 의자에서 일어나요)`)

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
	self:resumeBoss()
	self:notify("🚒 훈련 끝! 다시 자리로 돌아가세요. 부장님 감시 재개!")
end

---------------------------------------------------------------------------
-- 🌸 워크숍: 무궁화꽃이 피었습니다
--   부장님(술래)은 출입문 앞에 서요. 직원들은 뒷줄 출발선에서 시작해 초록 결승선까지!
--   "무궁화 꽃이 피었습니다~" 하는 동안만 움직이고, 부장님이 뒤돌아보면 멈춰야 해요.
---------------------------------------------------------------------------
local function flat(position: Vector3): Vector3
	return Vector3.new(position.X, 0, position.Z)
end

local function unseat(humanoid: Humanoid)
	local seat = humanoid.SeatPart
	if seat then
		for _, child in seat:GetChildren() do
			if child:IsA("Weld") and child.Name == "SeatWeld" then
				child:Destroy()
			end
		end
	end
	humanoid.Sit = false
end

function Events:runWorkshop(token: number)
	local office = self.office
	local zone = office.assemblyZone
	local goal = office.assemblyPoint
	local function inFinish(position: Vector3): boolean
		local offset = zone.CFrame:PointToObjectSpace(position)
		return math.abs(offset.X) <= zone.Size.X / 2 and math.abs(offset.Z) <= zone.Size.Z / 2
	end

	-- 참가자 모으기: 플레이어 + 동료 NPC 전원
	local racers = {}
	for _, player in Players:GetPlayers() do
		if self.canJoinWorkshop and not self.canJoinWorkshop(player) then
			continue
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and root and humanoid.Health > 0 then
			table.insert(racers, { player = player, name = player.DisplayName, model = character, humanoid = humanoid, root = root, status = "playing", mark = root.Position })
		end
	end
	if #racers == 0 then
		return
	end
	local npcs = if self.coworkers then self.coworkers.borrowAll() else {}
	for _, c in npcs do
		table.insert(racers, { npc = c, name = c.name, model = c.model, humanoid = c.humanoid, root = c.root, status = "playing", mark = c.root.Position })
	end

	self.active = true
	local stage = "ready"
	local endsAt = os.clock() + 4 + SalaryConfig.WORKSHOP_SECONDS
	local function left(): number
		return math.max(0, endsAt - os.clock())
	end
	local look = office.workshopLook -- 술래가 직원들을 볼 때 방향
	self.boss:host(office.workshopBoss, look)
	office.setAssemblyVisible(true, "🏁 결승선")
	self:notify("🌸 워크숍 레크리에이션! 동료들도 다 같이! 부장님이 뒤돌아볼 때 움직이면 탈락!")

	-- 출발선에 한 줄로 세우기
	for i, racer in racers do
		local x = (i - (#racers + 1) / 2) * 3.5
		local spot = CFrame.new(office.workshopStart + Vector3.new(x, 3, 0))
		if racer.player then
			unseat(racer.humanoid)
			racer.humanoid.WalkSpeed = SalaryConfig.WORKSHOP_SPEED
			racer.player:SetAttribute("WorkshopStatus", "playing")
			task.delay(0.15, function()
				if racer.model.Parent then
					racer.model:PivotTo(spot)
				end
			end)
		else
			-- 동료는 플레이어보다 살짝 느려요 (이길 수 있게)
			racer.humanoid.WalkSpeed = SalaryConfig.WORKSHOP_SPEED * math.random(75, 95) / 100
			Npc.setStatus(racer.model, "🌸")
			task.delay(0.3, function()
				if racer.model.Parent then
					racer.model:PivotTo(spot)
				end
			end)
		end
	end
	self:publish("ready", 4)
	if not self:wait(4, token) then
		return
	end

	local finished = 0
	local function finish(racer, status: string)
		racer.status = status
		if racer.player then
			racer.player:SetAttribute("WorkshopStatus", status)
			if racer.humanoid.Parent then
				racer.humanoid.WalkSpeed = SalaryConfig.walkSpeed(racer.player, 16) -- ⚡ 민첩성 보너스 포함 평소 속도 (게임 중엔 모두 같은 속도)
			end
		else
			racer.humanoid:MoveTo(racer.root.Position) -- 그 자리에 멈춰요
			Npc.setStatus(racer.model, if status == "finished" then "🏁" elseif status == "out" then "😵" else "🙂")
		end
	end
	local function gone(racer): boolean
		if racer.player then
			return not racer.player.Parent or not racer.humanoid.Parent or racer.humanoid.Health <= 0
		end
		return racer.npc.removed or not racer.model.Parent
	end
	local function playersLeft(): number
		local count = 0
		for _, racer in racers do
			if racer.status == "playing" then
				if gone(racer) then
					racer.status = "gone"
				elseif racer.player then
					count += 1
				end
			end
		end
		return count
	end
	-- 결승선에 들어온 사람 체크 (동료가 먼저 들어오면 등수가 밀려요!)
	local function checkGoal()
		for _, racer in racers do
			if racer.status == "playing" and racer.root.Parent and inFinish(racer.root.Position) then
				finished += 1
				finish(racer, "finished")
				self.boss:say(`{racer.name} 씨 {finished}등! 👏`, 2)
				if racer.player and self.onWorkshopFinish then
					self.onWorkshopFinish(racer.player, finished)
				end
			end
		end
	end
	local function waitChecking(seconds: number): boolean
		local finishAt = os.clock() + seconds
		while os.clock() < finishAt do
			if self.token ~= token then
				return false
			end
			checkGoal()
			task.wait(0.1)
		end
		return true
	end

	-- 🤖 동료 NPC: 노래하는 동안 결승선으로 걷고, 뒤돌아보면 멈춰요 (가끔 못 멈춰서 탈락)
	for _, racer in racers do
		if not racer.npc then
			continue
		end
		task.spawn(function()
			while self.token == token and racer.status == "playing" and stage ~= "over" do
				if stage == "chant" then
					Walker.walkTo(racer.humanoid, racer.root, goal, function()
						return stage ~= "chant" or racer.status ~= "playing" or self.token ~= token
					end)
					if racer.status == "playing" and stage == "look" and math.random() < 0.12 then
						task.wait(0.8) -- 앗, 못 멈췄다!
					end
					racer.humanoid:MoveTo(racer.root.Position)
				else
					task.wait(0.05)
				end
			end
			racer.humanoid:MoveTo(racer.root.Position)
		end)
	end

	while left() > 0 and playersLeft() > 0 do
		-- 1. 무궁화 꽃이 피었습니다~ (부장님이 등 돌림 → 움직여도 돼요)
		local chant = math.random(25, 50) / 10
		stage = "chant"
		self.boss:face(-look)
		self.boss:status("🌸")
		self.boss:say("무궁화~ 꽃이~ 피었습니다~!", chant)
		self:publish("chant", left())
		if not waitChecking(chant) then
			return
		end
		-- 2. 휙! 뒤돌아봐요 → 움직이면 탈락
		stage = "look"
		self.boss:face(look)
		self.boss:status("👀")
		self:publish("look", left())
		if not waitChecking(0.4) then -- 멈출 시간
			return
		end
		for _, racer in racers do
			if racer.status == "playing" and racer.root.Parent then
				racer.mark = racer.root.Position
			end
		end
		local lookUntil = os.clock() + math.random(15, 25) / 10
		while os.clock() < lookUntil do
			if self.token ~= token then
				return
			end
			for _, racer in racers do
				if racer.status == "playing" and racer.root.Parent then
					if (flat(racer.root.Position) - flat(racer.mark)).Magnitude > 0.8 then
						finish(racer, "out")
						self.boss:say(`{racer.name} 씨 움직였어! 탈락!`, 2)
					end
				end
			end
			task.wait(0.1)
		end
	end

	-- 끝!
	stage = "over"
	for _, racer in racers do
		if racer.status == "playing" then
			finish(racer, "timeout")
		end
	end
	self:publish("done", 0)
	office.setAssemblyVisible(false)
	self.active = false
	self:notify(if finished > 0 then `🌸 워크숍 끝! 골인 {finished}명. 다들 자리로!` else "🌸 워크숍 끝! 아무도 골인 못 했어요… 다들 자리로!")
	task.delay(4, function()
		for _, racer in racers do
			if racer.player then
				racer.player:SetAttribute("WorkshopStatus", nil)
			end
		end
	end)
	if self.coworkers then
		self.coworkers.returnAll(false) -- 동료들은 걸어서 자리로
	end
	self:resumeBoss()
end

return Events
