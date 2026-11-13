-- 가운데 뜨는 창: 쪽지 읽기, 비밀번호 자물쇠

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Ui = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ui"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local gui = Ui.gui
local C = Ui.COLORS

local Panels = {}
local current: Frame? = nil

local function closeCurrent()
	if current then
		current:Destroy()
		current = nil
	end
end

local function basePanel(width: number, height: number): Frame
	closeCurrent()
	local panel = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = C.paper,
		ZIndex = 20,
		Parent = gui,
	}, { Ui.corner(14), Ui.stroke(C.brass, 4), Ui.padding(18) })
	current = panel
	return panel
end

local function title(panel: Frame, text: string)
	Ui.make("TextLabel", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = C.ink,
		Font = Enum.Font.GothamBlack,
		TextSize = 26,
		ZIndex = 21,
		Parent = panel,
	})
end

local function closeButton(panel: Frame, position: UDim2, text: string?): TextButton
	local button = Ui.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = position,
		Size = UDim2.fromOffset(130, 40),
		Text = text or "닫기",
		ZIndex = 21,
		Parent = panel,
	})
	button.Activated:Connect(closeCurrent)
	return button
end

---------------------------------------------------------------------------
-- 쪽지
---------------------------------------------------------------------------
function Panels.showNote(noteTitle: string, body: string)
	local panel = basePanel(480, 340)
	title(panel, `📜 {noteTitle}`)
	Ui.make("TextLabel", {
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 1, -100),
		BackgroundTransparency = 1,
		Text = body,
		TextColor3 = C.ink,
		Font = Enum.Font.GothamMedium,
		TextSize = 19,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 21,
		Parent = panel,
	})
	closeButton(panel, UDim2.new(0.5, 0, 1, 0))
end
Remotes:WaitForChild("ShowNote").OnClientEvent:Connect(Panels.showNote)

---------------------------------------------------------------------------
-- 비밀번호 자물쇠 (숫자를 ▲▼로 돌리고 "확인")
---------------------------------------------------------------------------
function Panels.openCodeLock(lockId: string, digits: number, lockTitle: string)
	local width = math.max(340, digits * 76 + 60)
	local panel = basePanel(width, 330)
	title(panel, `🔒 {lockTitle}`)

	local values = table.create(digits, 0)
	local row = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 170),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = panel,
	}, {
		Ui.make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
		}),
	})

	for i = 1, digits do
		local column = Ui.make("Frame", {
			Size = UDim2.fromOffset(64, 170),
			BackgroundTransparency = 1,
			LayoutOrder = i,
			ZIndex = 21,
			Parent = row,
		})
		local number = Ui.make("TextLabel", {
			Position = UDim2.fromOffset(0, 50),
			Size = UDim2.fromOffset(64, 70),
			BackgroundColor3 = C.panel,
			Text = "0",
			TextColor3 = C.brass,
			Font = Enum.Font.GothamBlack,
			TextSize = 44,
			ZIndex = 21,
			Parent = column,
		}, { Ui.corner(8) })
		local function change(delta: number)
			values[i] = (values[i] + delta) % 10
			number.Text = tostring(values[i])
		end
		Ui.button({ Size = UDim2.fromOffset(64, 44), Text = "▲", ZIndex = 21, Parent = column }).Activated:Connect(function()
			change(1)
		end)
		Ui.button({ Position = UDim2.fromOffset(0, 126), Size = UDim2.fromOffset(64, 44), Text = "▼", ZIndex = 21, Parent = column }).Activated:Connect(function()
			change(-1)
		end)
	end

	local feedback = Ui.make("TextLabel", {
		Position = UDim2.fromOffset(0, 226),
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(170, 40, 30),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		ZIndex = 21,
		Parent = panel,
	})

	local confirm = Ui.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, -72, 1, 0),
		Size = UDim2.fromOffset(130, 40),
		Text = "확인",
		ZIndex = 21,
		Parent = panel,
	})
	closeButton(panel, UDim2.new(0.5, 72, 1, 0))

	local busy = false
	confirm.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		local code = ""
		for _, value in values do
			code ..= tostring(value)
		end
		local ok = Remotes.SubmitCode:InvokeServer(lockId, code)
		busy = false
		if ok then
			if current == panel then
				closeCurrent()
			end
		else
			feedback.Text = "철컥. 번호가 맞지 않는다…"
			local start = panel.Position
			local shake = TweenService:Create(panel, TweenInfo.new(0.05, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 3, true), {
				Position = start + UDim2.fromOffset(10, 0),
			})
			shake:Play()
			shake.Completed:Connect(function()
				panel.Position = start
			end)
		end
	end)
end
Remotes:WaitForChild("OpenCodeLock").OnClientEvent:Connect(Panels.openCodeLock)

return Panels
