-- 클라이언트: 화면 위쪽에 스테이지와 타이머를 보여 주고, 클리어하면 축하 메시지를 띄워요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "ObbyHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function makeLabel(position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = position
	label.Size = size
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.BackgroundTransparency = 0.35
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = label

	return label
end

local stageLabel = makeLabel(UDim2.new(0.5, 0, 0, 10), UDim2.fromOffset(240, 44))
local timerLabel = makeLabel(UDim2.new(0.5, 0, 0, 60), UDim2.fromOffset(160, 34))
local clearLabel = makeLabel(UDim2.fromScale(0.5, 0.35), UDim2.fromOffset(420, 80))
clearLabel.BackgroundColor3 = Color3.fromRGB(255, 190, 0)
clearLabel.Visible = false

-- 스테이지 표시
local stage = player:WaitForChild("leaderstats"):WaitForChild("스테이지") :: IntValue

local function updateStage()
	local total = ReplicatedStorage:GetAttribute("TotalStages") or "?"
	stageLabel.Text = `스테이지 {stage.Value} / {total}`
end
stage.Changed:Connect(updateStage)
ReplicatedStorage:GetAttributeChangedSignal("TotalStages"):Connect(updateStage)
updateStage()

-- 타이머
RunService.RenderStepped:Connect(function()
	local clearTime = player:GetAttribute("ClearTime")
	local startTime = player:GetAttribute("StartTime")
	if clearTime then
		timerLabel.Text = string.format("⏱ %.1f초", clearTime)
	elseif startTime then
		timerLabel.Text = string.format("⏱ %.1f초", workspace:GetServerTimeNow() - startTime)
	end
end)

-- 클리어 메시지
player:GetAttributeChangedSignal("ClearTime"):Connect(function()
	local clearTime = player:GetAttribute("ClearTime")
	if not clearTime then
		return
	end
	clearLabel.Text = string.format("🎉 클리어! %.1f초", clearTime)
	clearLabel.Visible = true
	task.delay(6, function()
		clearLabel.Visible = false
	end)
end)
