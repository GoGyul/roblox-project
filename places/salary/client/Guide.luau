-- 🧭 출근길 안내: "걸어서 출근"을 고르면 가야 할 곳까지 빛나는 선과 목적지 표시가 떠요
--   서버가 내 캐릭터에 CommuteTarget(가야 할 위치)을 붙여 줘요:
--   단지에서는 우리 회사 로비 엘리베이터 → 사무실 층에 올라오면 내 자리. 자리에 앉으면 사라져요.
--   나한테만 보여요 (다른 사람 화면에는 안 그려요).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(Shared:WaitForChild("SalaryTheme"))

local Guide = {}

local player = Players.LocalPlayer
local COLOR = Theme.Color.mint

function Guide.start()
	-- 목적지 표시 (보이지 않는 작은 파트 + 머리 위 글씨)
	local marker = Instance.new("Part")
	marker.Name = "CommuteMarker"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = Vector3.new(1, 1, 1)
	local goal = Instance.new("Attachment")
	goal.Parent = marker
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(190, 54)
	board.StudsOffset = Vector3.new(0, 7, 0)
	board.AlwaysOnTop = true
	board.MaxDistance = 2000
	board.Parent = marker
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Theme.Color.navy
	label.BackgroundTransparency = 0.15
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.Text = ""
	label.Parent = board
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = label
	-- 빛 기둥 (멀리서도 어디인지 보여요)
	local pillar = Instance.new("Part")
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CanQuery = false
	pillar.CanTouch = false
	pillar.CastShadow = false
	pillar.Material = Enum.Material.Neon
	pillar.Color = COLOR
	pillar.Transparency = 0.55
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Size = Vector3.new(26, 2.4, 2.4)

	-- 발밑에서 목적지까지 이어지는 선
	local beam = Instance.new("Beam")
	beam.Color = ColorSequence.new(COLOR)
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.5) })
	beam.Width0 = 1.2
	beam.Width1 = 1.2
	beam.FaceCamera = true
	beam.LightEmission = 0.6
	beam.Segments = 1
	beam.Attachment1 = goal
	beam.Parent = marker
	local foot: Attachment? = nil

	local shown = false
	local function hide()
		if shown then
			shown = false
			marker.Parent = nil
			pillar.Parent = nil
		end
	end

	-- 📷 엘리베이터·계단으로 도착하면 화면을 캐릭터 등 뒤로 돌려요 (벽 쪽을 보고 있으면 화면이 벽에 묻혀 멈춘 것처럼 보여요)
	player:GetAttributeChangedSignal("ArriveTick"):Connect(function()
		local look = player:GetAttribute("ArriveLook")
		if typeof(look) ~= "Vector3" then
			return
		end
		for _ = 1, 12 do -- (도착 직후 약 0.2초 동안 다시 맞춰요: 기본 카메라가 예전 방향으로 되돌리지 않게)
			RunService.RenderStepped:Wait()
			local camera = workspace.CurrentCamera
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if camera and root then
				camera.CFrame = CFrame.lookAt(root.Position - look * 9 + Vector3.new(0, 5, 0), root.Position + look * 12)
			end
		end
	end)

	RunService.RenderStepped:Connect(function()
		local target = player:GetAttribute("CommuteTarget")
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if typeof(target) ~= "Vector3" or not root then
			hide()
			return
		end
		if not foot or foot.Parent ~= root then
			foot = Instance.new("Attachment")
			foot.Name = "CommuteFoot"
			foot.Position = Vector3.new(0, -2.4, 0)
			foot.Parent = root
			beam.Attachment0 = foot
		end
		marker.CFrame = CFrame.new(target + Vector3.new(0, 0.6, 0))
		pillar.CFrame = CFrame.new(target + Vector3.new(0, 13, 0)) * CFrame.Angles(0, 0, math.rad(90))
		if not shown then
			shown = true
			marker.Parent = workspace
			pillar.Parent = workspace
			-- 📷 출근길 시작: 화면을 캐릭터 등 뒤로 돌려 가는 방향(공원)이 보이게 해요
			local camera = workspace.CurrentCamera
			if camera and (root.Position - target).Magnitude > 60 then -- (멀리서 시작할 때만 = 단지 정류장)
				local look = root.CFrame.LookVector
				camera.CFrame = CFrame.lookAt(root.Position - look * 14 + Vector3.new(0, 7, 0), root.Position + look * 12)
			end
		end
		local distance = math.floor((root.Position - target).Magnitude)
		label.Text = `{player:GetAttribute("CommuteLabel") or "🏢 여기로!"}  {distance}칸`
	end)
end

return Guide
