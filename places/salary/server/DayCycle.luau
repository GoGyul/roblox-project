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
			ReplicatedStorage:SetAttribute("SalaryNextDayAt", workspace:GetServerTimeNow() + SalaryConfig.PAYSLIP_SECONDS)
			self:publish()
			self:emit("dayEnd")
			task.wait(SalaryConfig.PAYSLIP_SECONDS)
		end
	end)
end

return DayCycle
