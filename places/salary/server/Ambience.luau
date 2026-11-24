-- 🔊 공간 소리 (리뉴얼 5단계)
--   소리 ID는 shared/SalaryConfig.luau 의 SalaryConfig.Sounds 표에 적어요. 비어 있는 칸("")은 그냥 소리가 안 나요.
--   로블록스에 기본으로 들어 있는 소리(rbxasset://)만 미리 채워 뒀고, 나머지는 크리에이터 스토어에서 골라 ID를 넣으면 돼요.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)

local Ambience = {}

local function soundId(key: string): string?
	local id = (SalaryConfig.Sounds or {})[key]
	return if typeof(id) == "string" and id ~= "" then id else nil
end

local function anchor(parent: Instance, position: Vector3, name: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Position = position
	part.Parent = parent
	return part
end

-- 그 자리에서 계속 도는 배경 소리 (가까이 갈수록 커져요). range = 들리는 거리(칸)
function Ambience.loop(key: string, parent: Instance, position: Vector3, range: number)
	local id = soundId(key)
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = (SalaryConfig.SoundVolume or {})[key] or 0.35
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMinDistance = range * 0.4
	sound.RollOffMaxDistance = range
	sound.Parent = anchor(parent, position, "Ambience_" .. key)
	sound:Play()
end

-- 한 번 울리는 소리 (엘리베이터 도착 "띵" 등)
function Ambience.once(key: string, position: Vector3, volume: number?)
	local id = soundId(key)
	if not id then
		return
	end
	local part = anchor(workspace, position, "Sound_" .. key)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.6
	sound.RollOffMaxDistance = 60
	sound.Parent = part
	sound:Play()
	Debris:AddItem(part, 4)
end

function Ambience.ding(position: Vector3)
	Ambience.once("elevatorDing", position, 0.7)
end

return Ambience
