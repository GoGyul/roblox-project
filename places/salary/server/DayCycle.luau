-- 하루 흐름: 출근(09:00) → 점심(12:00~13:00) → 퇴근(18:00) → 월급명세서 → 다음 날
-- 지금 시각과 단계는 ReplicatedStorage의 속성(Attribute)으로 클라이언트에도 보여 줘요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)

local DayCycle = {}
DayCycle.__index = DayCycle

export type Phase = "work" | "lunch" | "offwork"

function DayCycle.new()
	return setmetatable({
		day = 0,
		started = false, -- 첫 플레이어가 들어와 날짜를 불러오면 true
		extraOffwork = 0, -- 퇴근 후 추가 시간 (회식)
		waiting = false, -- 🏢 출근하기 버튼을 기다리는 중
		readyGate = nil :: (() -> ())?, -- 출근해도 되는지 기다리는 함수 (Employees가 채워요)
		minute = SalaryConfig.START_MINUTE,
		phase = "offwork" :: Phase,
		listeners = {} :: { [string]: { (...any) -> () } },
	}, DayCycle)
end

-- 이벤트 듣기: "dayStart", "lunchStart", "lunchEnd", "dayEnd"
function DayCycle:on(event: string, callback: (...any) -> ())
	self.listeners[event] = self.listeners[event] or {}
	table.insert(self.listeners[event], callback)
end

function DayCycle:emit(event: string, ...)
	for _, callback in self.listeners[event] or {} do
		task.spawn(callback, ...)
	end
end

function DayCycle:weekday()
	return SalaryConfig.Weekdays[(self.day - 1) % #SalaryConfig.Weekdays + 1]
end

function DayCycle:publish()
	local weekday = self:weekday()
	ReplicatedStorage:SetAttribute("SalaryDay", self.day)
	ReplicatedStorage:SetAttribute("SalaryWeekday", weekday.name)
	ReplicatedStorage:SetAttribute("SalaryMood", weekday.mood)
	ReplicatedStorage:SetAttribute("SalaryMinute", math.floor(self.minute))
	ReplicatedStorage:SetAttribute("SalaryPhase", self.phase)
end

function DayCycle:run()
	task.spawn(function()
		while true do
			-- 🏢 출근 대기: 다들 [출근하기]를 누를 때까지 08:50에 멈춰 있어요
			if self.readyGate then
				self.waiting = true
				self.minute = SalaryConfig.START_MINUTE - 10
				ReplicatedStorage:SetAttribute("SalaryWaiting", true)
				self:publish()
				self.readyGate()
				self.waiting = false
				ReplicatedStorage:SetAttribute("SalaryWaiting", false)
			end

			self.day += 1
			self.minute = SalaryConfig.START_MINUTE
			self.phase = "work"
			self:publish()
			self:emit("dayStart", self:weekday())

			local elapsed = 0
			while elapsed < SalaryConfig.DAY_SECONDS do
				elapsed += task.wait(0.25)
				local progress = math.min(elapsed / SalaryConfig.DAY_SECONDS, 1)
				self.minute = SalaryConfig.START_MINUTE + (SalaryConfig.END_MINUTE - SalaryConfig.START_MINUTE) * progress

				local isLunch = self.minute >= SalaryConfig.LUNCH_START and self.minute < SalaryConfig.LUNCH_END
				if isLunch and self.phase == "work" then
					self.phase = "lunch"
					self:emit("lunchStart")
				elseif not isLunch and self.phase == "lunch" then
					self.phase = "work"
					self:emit("lunchEnd")
				end
				self:publish()
			end

			self.phase = "offwork"
			self.minute = SalaryConfig.END_MINUTE
			self.extraOffwork = 0 -- 🍻 회식 같은 퇴근 후 일정이 있으면 dayEnd에서 늘려요
			self:publish()
			self:emit("dayEnd")
			local rest = SalaryConfig.PAYSLIP_SECONDS + self.extraOffwork
			ReplicatedStorage:SetAttribute("SalaryNextDayAt", workspace:GetServerTimeNow() + rest)
			task.wait(rest)
		end
	end)
end

return DayCycle
