-- UI를 짧게 만들기 위한 도우미

local Players = game:GetService("Players")

local Ui = {}

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
	return Ui.make("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
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
	return Ui.make("TextButton", defaults, { Ui.corner(8) })
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

function Ui.toast(text: string)
	toastToken += 1
	local myToken = toastToken
	toastLabel.Text = text
	toastLabel.Visible = true
	task.delay(4.5, function()
		if myToken == toastToken then
			toastLabel.Visible = false
		end
	end)
end

return Ui
