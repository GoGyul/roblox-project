-- UI를 짧게 만들기 위한 도우미

local Players = game:GetService("Players")

local Ui = {}

Ui.STYLE = {
	corner = 10,
	buttonCorner = 8,
	stroke = Color3.fromRGB(205, 165, 75),
}

Ui.COLORS = {
	panel = Color3.fromRGB(28, 22, 16),
	paper = Color3.fromRGB(240, 228, 200),
	ink = Color3.fromRGB(50, 35, 20),
	brass = Color3.fromRGB(205, 165, 75),
	text = Color3.fromRGB(245, 235, 215),
}

function Ui.make(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	for key, value in props or {} do
		if key == "Parent" then
			parent = value
		else
			(instance :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Ui.corner(radius: number?)
	return Ui.make("UICorner", { CornerRadius = UDim.new(0, radius or Ui.STYLE.corner) })
end

function Ui.padding(px: number)
	local p = UDim.new(0, px)
	return Ui.make("UIPadding", { PaddingTop = p, PaddingBottom = p, PaddingLeft = p, PaddingRight = p })
end

function Ui.stroke(color: Color3, thickness: number?)
	return Ui.make("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.button(props: { [string]: any }): TextButton
	local defaults = {
		BackgroundColor3 = Ui.COLORS.brass,
		TextColor3 = Ui.COLORS.ink,
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		AutoButtonColor = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	return Ui.make("TextButton", defaults, {
		Ui.corner(Ui.STYLE.buttonCorner),
		Ui.stroke(Ui.STYLE.stroke, 1.5),
	})
end

Ui.gui = Ui.make("ScreenGui", {
	Name = "GameUi",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
})

---------------------------------------------------------------------------
-- 안내 문구 (화면 아래에 잠깐 떴다가 사라짐)
---------------------------------------------------------------------------
local toastLabel = Ui.make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -110),
	Size = UDim2.fromOffset(620, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Ui.COLORS.panel,
	BackgroundTransparency = 0.15,
	TextColor3 = Ui.COLORS.text,
	Font = Enum.Font.GothamMedium,
	TextSize = 20,
	TextWrapped = true,
	Visible = false,
	ZIndex = 30,
	Parent = Ui.gui,
}, { Ui.corner(10), Ui.padding(12) })
local toastToken = 0

-- 게임별 디자인 테마를 적용해요. ScreenGui는 공유하지만 색은 각 Place가 시작할 때 정해요.
function Ui.setTheme(colors: { [string]: Color3 }, style: { [string]: any }?)
	for key, value in colors do
		Ui.COLORS[key] = value
	end
	for key, value in style or {} do
		Ui.STYLE[key] = value
	end
	toastLabel.BackgroundColor3 = Ui.COLORS.panel
	toastLabel.TextColor3 = Ui.COLORS.text
	local stroke = toastLabel:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Ui.STYLE.stroke
	end
end

-- 안내 문구 크기 바꾸기 (게임마다 원하는 크기로)
function Ui.setToastStyle(width: number, textSize: number, padding: number?)
	toastLabel.Size = UDim2.fromOffset(width, 0)
	toastLabel.TextSize = textSize
	local pad = toastLabel:FindFirstChildOfClass("UIPadding")
	if pad and padding then
		pad.PaddingTop = UDim.new(0, padding)
		pad.PaddingBottom = UDim.new(0, padding)
		pad.PaddingLeft = UDim.new(0, padding + 2)
		pad.PaddingRight = UDim.new(0, padding + 2)
	end
end

-- 안내 문구 위치 바꾸기 (화면 아래 버튼과 겹칠 때)
function Ui.setToastPosition(position: UDim2)
	toastLabel.Position = position
end

-- seconds: 보여 줄 시간 (안 주면 4.5초. 💬 수다 대사처럼 빨리 넘어가는 건 짧게)
function Ui.toast(text: string, seconds: number?)
	toastToken += 1
	local myToken = toastToken
	toastLabel.Text = text
	toastLabel.Visible = true
	task.delay(if typeof(seconds) == "number" then seconds else 4.5, function()
		if myToken == toastToken then
			toastLabel.Visible = false
		end
	end)
end

return Ui
