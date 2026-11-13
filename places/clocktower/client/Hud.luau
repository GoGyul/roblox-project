-- 화면 표시: 지금 시대, 시간 전환 버튼, 소지품, 안내 문구, 시대별 색감, 탈출 화면

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Ui = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ui"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local gui = Ui.gui
local C = Ui.COLORS

local Hud = {}

---------------------------------------------------------------------------
-- 시대 표시 + 전환 버튼
---------------------------------------------------------------------------
local eraLabel = Ui.make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(280, 42),
	BackgroundColor3 = C.panel,
	BackgroundTransparency = 0.2,
	TextColor3 = C.text,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	Parent = gui,
}, { Ui.corner(10), Ui.padding(8), Ui.stroke(C.brass) })

local toggleButton = Ui.button({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 60),
	Size = UDim2.fromOffset(200, 36),
	Text = "⏳ 시간 전환 [T]",
	Visible = false,
	Parent = gui,
})

local function requestToggle()
	if toggleButton.Visible then
		Remotes.ToggleEra:FireServer()
	end
end

toggleButton.Activated:Connect(requestToggle)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == Config.TOGGLE_KEY then
		requestToggle()
	end
end)

---------------------------------------------------------------------------
-- 시대별 색감 + 번쩍 효과
---------------------------------------------------------------------------
local colorCorrection = Ui.make("ColorCorrectionEffect", { Name = "EraColor", Parent = Lighting })
local ERA_LOOK = {
	present = { TintColor = Color3.fromRGB(205, 215, 240), Saturation = -0.3, Contrast = 0.05, Brightness = -0.02 },
	past = { TintColor = Color3.fromRGB(255, 225, 180), Saturation = -0.05, Contrast = 0.1, Brightness = 0.04 },
}

local flash = Ui.make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(255, 245, 220),
	BackgroundTransparency = 1,
	ZIndex = 50,
	Parent = gui,
})

local function applyEra(animate: boolean)
	local era = player:GetAttribute("Era") or "present"
	eraLabel.Text = `🕰️ {Config.EraNames[era] or era}`
	local look = ERA_LOOK[era] or ERA_LOOK.present
	TweenService:Create(colorCorrection, TweenInfo.new(if animate then 0.8 else 0), look):Play()
	if animate then
		flash.BackgroundTransparency = 0
		TweenService:Create(flash, TweenInfo.new(0.7), { BackgroundTransparency = 1 }):Play()
	end
end
player:GetAttributeChangedSignal("Era"):Connect(function()
	applyEra(true)
end)
applyEra(false)

---------------------------------------------------------------------------
-- 소지품
---------------------------------------------------------------------------
local inventoryFrame = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 16, 1, -16),
	Size = UDim2.fromOffset(210, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = C.panel,
	BackgroundTransparency = 0.2,
	Parent = gui,
}, {
	Ui.corner(10),
	Ui.padding(10),
	Ui.stroke(C.brass),
	Ui.make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local inventory = player:WaitForChild("Inventory")

local function refreshInventory()
	for _, child in inventoryFrame:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local function line(text: string, order: number, color: Color3)
		Ui.make("TextLabel", {
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamBold,
			TextSize = 18,
			LayoutOrder = order,
			Parent = inventoryFrame,
		})
	end
	line("🎒 소지품", 0, C.brass)
	local count = 0
	for order, itemId in Config.ItemOrder do
		local item = inventory:FindFirstChild(itemId)
		if item then
			count += 1
			line(`• {item.Value}`, order, C.text)
		end
	end
	if count == 0 then
		line("(비어 있음)", 99, Color3.fromRGB(150, 140, 125))
	end
	toggleButton.Visible = inventory:FindFirstChild("watch") ~= nil
end
inventory.ChildAdded:Connect(refreshInventory)
inventory.ChildRemoved:Connect(refreshInventory)
refreshInventory()

---------------------------------------------------------------------------
-- 안내 문구 (화면 아래)
---------------------------------------------------------------------------
Remotes:WaitForChild("Notify").OnClientEvent:Connect(Ui.toast)

---------------------------------------------------------------------------
-- 탈출 성공 화면
---------------------------------------------------------------------------
Remotes:WaitForChild("Escaped").OnClientEvent:Connect(function(seconds: number)
	local minutes = math.floor(seconds / 60)
	local rest = math.floor(seconds % 60)
	local panel = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(460, 220),
		BackgroundColor3 = C.paper,
		ZIndex = 40,
		Parent = gui,
	}, { Ui.corner(16), Ui.stroke(C.brass, 4), Ui.padding(20) })
	Ui.make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		Text = "🔔 탈출 성공!",
		TextColor3 = C.ink,
		Font = Enum.Font.GothamBlack,
		TextSize = 36,
		ZIndex = 41,
		Parent = panel,
	})
	Ui.make("TextLabel", {
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 0, 80),
		BackgroundTransparency = 1,
		Text = `9시 정각, 50년 만에 시계탑의 종이 울렸다.\n기록: {minutes}분 {rest}초`,
		TextColor3 = C.ink,
		Font = Enum.Font.GothamMedium,
		TextSize = 20,
		TextWrapped = true,
		ZIndex = 41,
		Parent = panel,
	})
	local lobby = Ui.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, -80, 1, 0),
		Size = UDim2.fromOffset(150, 40),
		Text = "🏛️ 광장으로",
		ZIndex = 41,
		Parent = panel,
	})
	lobby.Activated:Connect(function()
		Remotes.ReturnToLobby:FireServer()
	end)

	local close = Ui.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 80, 1, 0),
		Size = UDim2.fromOffset(150, 40),
		Text = "닫기",
		ZIndex = 41,
		Parent = panel,
	})
	close.Activated:Connect(function()
		panel:Destroy()
	end)
end)

return Hud
