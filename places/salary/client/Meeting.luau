-- 🎧 화상회의 창
--
-- [화상회의 하는 척]을 켜면 화면 오른쪽에 회의 창이 떠요. 진행은 서버가 하고(Remotes.Meeting), 여기는 보여 주기만 해요.
--   위: 참석자 네 칸 (말하는 사람 칸이 노랗게) · 자막
--   가운데: 돌발 상황 문구 + 남은 시간 막대
--   아래: 버튼 판 (돌발 상황마다 맞는 버튼 하나) 또는 지목 질문의 보기 네 개
-- X를 누르면 회의에서 나가고 [일하기]로 돌아가요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SalaryConfig = require(Shared:WaitForChild("SalaryConfig"))
local Ui = require(Shared:WaitForChild("Ui"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Theme = require(Shared:WaitForChild("SalaryTheme"))
local Hud = require(script.Parent.Hud)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local gui = Ui.gui

local Meeting = {}

local WIDTH, HEIGHT = 330, 470
local INK = Theme.Color.navy
local MUTED = Theme.Color.muted
local GREEN = Color3.fromRGB(34, 140, 84)
local PEOPLE = { { id = "부장", face = "😤" }, { id = "박대리", face = "🙂" }, { id = "이사원", face = "🤓" }, { id = "나", face = "😶" } }

-- 지금 떠 있는 창의 부품들 (창이 없으면 nil)
local view: any = nil
local current: { id: number, kind: string }? = nil -- 지금 진행 중인 돌발 상황
local barTween: Tween? = nil

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local options = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = INK,
		TextSize = 14,
		TextWrapped = true,
		ZIndex = 47,
		Parent = parent,
	}
	for key, value in props do
		options[key] = value
	end
	return Ui.make("TextLabel", options)
end

function Meeting.close()
	current = nil
	if barTween then
		barTween:Cancel()
		barTween = nil
	end
	if view then
		view.frame:Destroy()
		view = nil
	end
end

local function focusText(focus: number): string
	local left = math.clamp(focus, 0, SalaryConfig.MEETING_FOCUS)
	return "집중도 " .. string.rep("●", left) .. string.rep("○", SalaryConfig.MEETING_FOCUS - left)
end

-- 아래 칸 비우기 (버튼 판 ↔ 보기 네 개를 바꿀 때)
local function clearActions()
	for _, child in view.actions:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function send(value: any)
	local event = current
	if not event then
		return
	end
	Sounds.play("click", 0.4)
	Remotes.MeetingAct:FireServer(event.id, value)
end

-- 버튼 판: 돌발 상황마다 이 중 하나가 정답
local function showButtons()
	clearActions()
	for i, info in SalaryConfig.MeetingButtons do
		local column, row = (i - 1) % 4, math.floor((i - 1) / 4)
		local button = Ui.button({
			Position = UDim2.new(column / 4, 2, 0, row * 58),
			Size = UDim2.new(1 / 4, -4, 0, 54),
			Text = `<font size="20">{info.emoji}</font>\n{info.name}`,
			RichText = true,
			TextSize = 10,
			TextWrapped = true,
			BackgroundColor3 = Color3.fromRGB(240, 242, 248),
			TextColor3 = INK,
			ZIndex = 47,
			Parent = view.actions,
		})
		button.Activated:Connect(function()
			send(info.id)
		end)
	end
end

-- 지목 질문: 보기 네 개
local function showOptions(options: { string })
	clearActions()
	for i, text in options do
		local button = Ui.button({
			Position = UDim2.fromOffset(0, (i - 1) * 43),
			Size = UDim2.new(1, 0, 0, 39),
			Text = text,
			TextSize = 13,
			TextWrapped = true,
			BackgroundColor3 = Theme.Color.yellow,
			TextColor3 = INK,
			ZIndex = 47,
			Parent = view.actions,
		})
		button.Activated:Connect(function()
			send(i)
		end)
	end
end

local function open(focus: number)
	Meeting.close()
	local phone = Hud.isPhone()
	local frame = Ui.make("Frame", {
		AnchorPoint = if phone then Vector2.new(0.5, 0) else Vector2.new(1, 0.5),
		Position = if phone then UDim2.new(0.5, 0, 0, 44) else UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundColor3 = Color3.fromRGB(32, 36, 46),
		ZIndex = 45,
		Parent = gui,
	}, { Ui.corner(20), Ui.stroke(INK, 3), Ui.padding(10) })
	local scale = Ui.make("UIScale", { Parent = frame })
	local size = gui.AbsoluteSize
	scale.Scale = math.clamp(math.min((size.X - 24) / WIDTH, (size.Y - (if phone then 150 else 24)) / HEIGHT), 0.5, 1.4)

	local title = label(frame, { Size = UDim2.new(1, -34, 0, 22), Text = "🎧 화상회의 연결 중…", TextColor3 = Color3.fromRGB(240, 240, 246), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
	local x = Ui.make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 2, 0, -2),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = Theme.Color.coralSoft,
		Text = "X",
		TextColor3 = INK,
		Font = Enum.Font.GothamBlack,
		TextSize = 14,
		ZIndex = 48,
		Parent = frame,
	}, { Ui.corner(14) })
	x.Activated:Connect(function()
		Sounds.play("click", 0.4)
		Meeting.close()
		if player:GetAttribute("SalaryAction") == "video" then
			Remotes.SetAction:FireServer("work") -- 회의에서 나가면 [일하기]로
		end
	end)

	local body = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 1, -30),
		BackgroundColor3 = Color3.fromRGB(252, 250, 244),
		ZIndex = 46,
		Parent = frame,
	}, { Ui.corner(12), Ui.padding(8) })

	-- 참석자 네 칸
	local tiles = {}
	for i, person in PEOPLE do
		local tile = Ui.make("Frame", {
			Position = UDim2.new((i - 1) / 4, 2, 0, 0),
			Size = UDim2.new(1 / 4, -4, 0, 60),
			BackgroundColor3 = Color3.fromRGB(46, 52, 66),
			ZIndex = 47,
			Parent = body,
		}, { Ui.corner(8) })
		local ring = Ui.stroke(Theme.Color.yellow, 3)
		ring.Enabled = false
		ring.Parent = tile
		label(tile, { Size = UDim2.new(1, 0, 0, 40), Text = person.face, TextSize = 28, TextWrapped = false, ZIndex = 48 })
		label(tile, { Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 18), Text = person.id, TextSize = 11, TextColor3 = Color3.fromRGB(226, 230, 240), TextWrapped = false, ZIndex = 48 })
		tiles[person.id] = ring
	end
	local focusLabel = label(body, { Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 0, 18), Text = focusText(focus), TextSize = 12, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Right })
	-- 자막
	local subtitle = label(body, {
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(240, 242, 248),
		Text = "회의가 곧 시작돼요…",
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
	})
	Ui.corner(8).Parent = subtitle
	Ui.padding(6).Parent = subtitle
	-- 돌발 상황 문구 + 남은 시간
	local alert = label(body, { Position = UDim2.fromOffset(0, 140), Size = UDim2.new(1, 0, 0, 46), Text = "", TextSize = 15 })
	local back = Ui.make("Frame", { Position = UDim2.fromOffset(0, 190), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = Color3.fromRGB(226, 226, 220), ZIndex = 47, Parent = body }, { Ui.corner(3) })
	local fill = Ui.make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Color.coral, ZIndex = 48, Parent = back }, { Ui.corner(3) })
	local actions = Ui.make("Frame", { Position = UDim2.fromOffset(0, 204), Size = UDim2.new(1, 0, 1, -204), BackgroundTransparency = 1, ZIndex = 46, Parent = body })

	view = { frame = frame, title = title, tiles = tiles, focus = focusLabel, subtitle = subtitle, alert = alert, fill = fill, actions = actions }
	showButtons()
end

local function setSpeaker(who: string?)
	for id, ring in view.tiles do
		ring.Enabled = id == who
	end
end

local function startBar(seconds: number)
	if barTween then
		barTween:Cancel()
	end
	view.fill.Size = UDim2.fromScale(1, 1)
	barTween = TweenService:Create(view.fill, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) })
	barTween:Play()
end

local function stopBar()
	if barTween then
		barTween:Cancel()
		barTween = nil
	end
	if view then
		view.fill.Size = UDim2.fromScale(0, 1)
	end
end

local function handle(message: any)
	if typeof(message) ~= "table" then
		return
	end
	local kind = message.type
	if kind == "open" then
		open(message.focus or SalaryConfig.MEETING_FOCUS)
		return
	end
	if kind == "end" then
		Meeting.close()
		return
	end
	if kind == "finished" then
		-- 🎉 회의를 끝까지 마쳤어요 (서버가 [일하기]로 돌려보내요)
		Sounds.play("ping", 0.7, 1.1)
		Ui.toast(message.text or "🎧 회의 끝!", 5)
		Meeting.close()
		return
	end
	if not view then
		if kind == "kicked" then
			Ui.toast(message.text or "🎧 회의에서 쫓겨났어요.", 5)
		end
		return
	end
	if kind == "topic" then
		view.title.Text = `🎧 화상회의 · {message.title}` .. (if message.total then ` ({message.index or 1}/{message.total})` else "")
		view.subtitle.Text = `— 안건: {message.title} —`
		view.alert.Text = ""
		view.focus.Text = focusText(message.focus or 0)
		setSpeaker(nil)
	elseif kind == "line" then
		view.subtitle.Text = `{message.who}: {message.text}`
		setSpeaker(message.who)
	elseif kind == "event" then
		current = { id = message.id, kind = message.kind }
		view.alert.Text = message.text or ""
		view.alert.TextColor3 = if message.kind == "peek" then INK else Theme.Color.coral
		setSpeaker(if message.kind == "quiz" then "부장" else "나")
		startBar(message.seconds or 4)
		Sounds.play("ping", 0.5, if message.kind == "quiz" then 0.9 else 1.3)
		if message.kind == "quiz" and typeof(message.options) == "table" then
			showOptions(message.options)
		end
	elseif kind == "result" then
		local wasQuiz = current ~= nil and current.kind == "quiz"
		current = nil
		stopBar()
		view.focus.Text = focusText(message.focus or 0)
		local amount = message.amount or 0
		view.alert.Text = (message.text or "") .. (if amount > 0 then `  +{amount}원` else "")
		view.alert.TextColor3 = if message.ok then GREEN else Theme.Color.coral
		if message.ok == false then
			Sounds.play("bass", 0.6, 0.9)
		elseif amount > 0 then
			Sounds.play("ping", 0.6, 1.2)
		end
		if wasQuiz then
			showButtons()
		end
	elseif kind == "kicked" then
		current = nil
		stopBar()
		Sounds.play("bass", 0.8, 0.7)
		Ui.toast(message.text or "🎧 회의에서 쫓겨났어요.", 6)
		Meeting.close()
	end
end

function Meeting.start()
	Remotes:WaitForChild("Meeting").OnClientEvent:Connect(handle)
end

return Meeting
