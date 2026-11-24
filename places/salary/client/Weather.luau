-- 🌧️🌸 단지 날씨: 비 오는 날엔 빗줄기, 벚꽃 주간엔 꽃잎이 내 화면 주위로 떨어져요
--   서버가 ReplicatedStorage의 CampusRain · CampusBlossom 속성으로 알려 줘요 (CampusEvents 모듈).
--   바깥(회사 단지, 옥상)에 있을 때만 보여요. 사무실 안에서는 안 보여요.
--   내 화면에만 그리는 효과라 다른 사람에게 부담을 주지 않아요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Weather = {}

local player = Players.LocalPlayer
local CAMPUS_Z = 700 -- 단지는 사무실에서 남쪽으로 멀리 떨어져 있어요 (z 약 750~1040)
local ROOF_Y = 250 -- 옥상은 높이 300

function Weather.start()
	-- 카메라 위에 떠서 따라다니는 보이지 않는 판 (여기서 비·꽃잎이 떨어져요)
	local cloud = Instance.new("Part")
	cloud.Name = "WeatherCloud"
	cloud.Anchored = true
	cloud.CanCollide = false
	cloud.CanQuery = false
	cloud.CanTouch = false
	cloud.Transparency = 1
	cloud.Size = Vector3.new(70, 1, 70)
	cloud.Parent = workspace

	local rain = Instance.new("ParticleEmitter")
	rain.Name = "Rain"
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Speed = NumberRange.new(70, 90)
	rain.Lifetime = NumberRange.new(0.55, 0.7)
	rain.Rate = 0
	rain.Size = NumberSequence.new(0.09)
	rain.Squash = NumberSequence.new(4) -- 길쭉한 빗줄기
	rain.Orientation = Enum.ParticleOrientation.VelocityParallel
	rain.Color = ColorSequence.new(Color3.fromRGB(200, 220, 240))
	rain.Transparency = NumberSequence.new(0.35)
	rain.LightEmission = 0.2
	rain.SpreadAngle = Vector2.new(3, 3)
	rain.Enabled = true
	rain.Parent = cloud

	local petals = Instance.new("ParticleEmitter")
	petals.Name = "Petals"
	petals.EmissionDirection = Enum.NormalId.Bottom
	petals.Speed = NumberRange.new(4, 7)
	petals.Lifetime = NumberRange.new(5, 7)
	petals.Rate = 0
	petals.Size = NumberSequence.new(0.28)
	petals.Color = ColorSequence.new(Color3.fromRGB(255, 205, 220))
	petals.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) })
	petals.Rotation = NumberRange.new(0, 360)
	petals.RotSpeed = NumberRange.new(-90, 90)
	petals.Acceleration = Vector3.new(1.5, 0, 0.8) -- 바람에 살짝 날려요
	petals.SpreadAngle = Vector2.new(25, 25)
	petals.Enabled = true
	petals.Parent = cloud

	-- 비 오는 날엔 화면을 살짝 흐리게
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "RainGrade"
	grade.Enabled = false
	grade.Brightness = -0.05
	grade.Saturation = -0.18
	grade.TintColor = Color3.fromRGB(222, 230, 240)
	grade.Parent = Lighting

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not camera or not root then
			rain.Rate, petals.Rate = 0, 0
			grade.Enabled = false
			return
		end
		local position = root.Position
		local outside = position.Y > ROOF_Y or (position.Z > CAMPUS_Z and position.Y < 120)
		local raining = outside and ReplicatedStorage:GetAttribute("CampusRain") == true
		local blossom = position.Z > CAMPUS_Z and position.Y < 120 and ReplicatedStorage:GetAttribute("CampusBlossom") == true
		cloud.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, if raining then 32 else 22, 0))
		rain.Rate = if raining then 420 else 0
		petals.Rate = if blossom then 14 else 0
		grade.Enabled = raining
	end)
end

return Weather
