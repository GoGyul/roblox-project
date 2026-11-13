-- NPC 사람 만들기 (김부장, 동료 직원)
-- 로블록스 기본 아바타 몸에 색만 입혀서 만들고, 머리 위에 상태 이모지와 말풍선을 달아요.

local Players = game:GetService("Players")

local Npc = {}

export type Look = {
	skin: Color3,
	shirt: Color3,
	pants: Color3,
}

function Npc.create(name: string, look: Look, parent: Instance): Model
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = look.skin
	description.TorsoColor = look.shirt
	description.LeftArmColor = look.shirt
	description.RightArmColor = look.shirt
	description.LeftLegColor = look.pants
	description.RightLegColor = look.pants

	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = name
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	-- 머리 위 표시: 이름 / 상태 이모지 / 말풍선
	local head = model:WaitForChild("Head") :: BasePart
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Bubble"
	billboard.Size = UDim2.fromOffset(260, 110)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
	billboard.MaxDistance = 90
	billboard.Parent = head

	local function label(labelName: string, y: number, height: number, textSize: number): TextLabel
		local text = Instance.new("TextLabel")
		text.Name = labelName
		text.AnchorPoint = Vector2.new(0.5, 0)
		text.Position = UDim2.new(0.5, 0, 0, y)
		text.Size = UDim2.new(1, 0, 0, height)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBold
		text.TextSize = textSize
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0.3
		text.TextWrapped = true
		text.Text = ""
		text.Parent = billboard
		return text
	end
	local speech = label("Speech", 0, 44, 18)
	speech.BackgroundTransparency = 0.1
	speech.BackgroundColor3 = Color3.new(1, 1, 1)
	speech.TextColor3 = Color3.fromRGB(30, 30, 30)
	speech.TextStrokeTransparency = 1
	speech.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = speech
	label("Status", 48, 36, 30)
	label("NameTag", 84, 22, 16).Text = name

	model.Parent = parent
	return model
end

-- 머리 위 이모지 바꾸기
function Npc.setStatus(model: Model, emoji: string)
	local bubble = model:FindFirstChild("Bubble", true)
	if bubble then
		(bubble :: any).Status.Text = emoji
	end
end

-- 말풍선 띄우기 (seconds 뒤에 사라짐)
function Npc.say(model: Model, text: string, seconds: number?)
	local bubble = model:FindFirstChild("Bubble", true)
	if not bubble then
		return
	end
	local speech = (bubble :: any).Speech :: TextLabel
	speech.Text = text
	speech.Visible = true
	local myText = text
	task.delay(seconds or 3, function()
		if speech.Text == myText then
			speech.Visible = false
		end
	end)
end

-- 의자에 앉히기
function Npc.sit(model: Model, seat: Seat)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	model:PivotTo(seat.CFrame + Vector3.new(0, 3, 0))
	seat:Sit(humanoid)
end

return Npc
