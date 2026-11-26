-- 📺 웹툰 뷰어
--
-- [웹툰 정주행] 농땡이를 켜면 화면 오른쪽에 폰 모양 창이 떠요.
--   목록: 작품과 화 번호 (본 화 ✅ · 볼 차례 ▶ · 아직 🔒)
--   보기: 네 컷을 한 컷씩. 컷마다 잠깐(읽는 시간) 뒤에 [다음 컷]이 켜져요. 마지막 컷까지 보면 완독!
--   일하기로 돌아가면 창이 닫히고, 보던 화는 처음부터 다시 봐요.
-- 그림은 이미지 없이 이모지·말풍선·배경색으로 그려요 (내용은 SalaryConfig.Webtoons).

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

local Webtoon = {}

local WIDTH, HEIGHT = 300, 430
local INK = Theme.Color.navy
local MUTED = Theme.Color.muted

-- 배경: 바탕색 · 바닥색 · 글씨색
local SCENES = {
	office = { back = Color3.fromRGB(226, 236, 244), floor = Color3.fromRGB(196, 204, 212), ink = INK },
	hall = { back = Color3.fromRGB(236, 228, 212), floor = Color3.fromRGB(206, 194, 172), ink = INK },
	night = { back = Color3.fromRGB(46, 50, 86), floor = Color3.fromRGB(30, 32, 58), ink = Color3.fromRGB(240, 240, 250) },
	screen = { back = Color3.fromRGB(26, 32, 44), floor = Color3.fromRGB(18, 22, 32), ink = Color3.fromRGB(190, 240, 210) },
}

local frame: Frame? = nil
local token = 0 -- 창을 다시 그릴 때마다 올려서, 예전 화면의 기다리던 일을 멈춰요

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local options = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = INK,
		TextSize = 15,
		TextWrapped = true,
		ZIndex = 47,
		Parent = parent,
	}
	for key, value in props do
		options[key] = value
	end
	return Ui.make("TextLabel", options)
end

function Webtoon.close()
	token += 1
	if frame then
		frame:Destroy()
		frame = nil
	end
end

-- 폰 모양 바깥 틀을 새로 만들어요 (안쪽 내용만 바꿀 때도 통째로 다시 그려요: 단순하게)
local function shell(title: string): Frame
	Webtoon.close()
	local phone = Hud.isPhone()
	local newFrame = Ui.make("Frame", {
		AnchorPoint = if phone then Vector2.new(0.5, 0) else Vector2.new(1, 0.5),
		Position = if phone then UDim2.new(0.5, 0, 0, 44) else UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundColor3 = Color3.fromRGB(32, 36, 46),
		ZIndex = 45, -- (직급 창·프로젝트 카드보다 위에)
		Parent = gui,
	}, { Ui.corner(22), Ui.stroke(INK, 3), Ui.padding(10) })
	local scale = Ui.make("UIScale", { Parent = newFrame })
	local size = gui.AbsoluteSize
	-- 화면이 허락하는 만큼 크게 (예전엔 위아래 여백을 150이나 빼서 작은 화면에서 반 토막이 났어요)
	scale.Scale = math.clamp(math.min((size.X - 24) / WIDTH, (size.Y - (if phone then 150 else 24)) / HEIGHT), 0.5, 1.4)
	frame = newFrame
	label(newFrame, { Size = UDim2.new(1, -34, 0, 24), Text = title, TextColor3 = Color3.fromRGB(240, 240, 246), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 15, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
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
		Parent = newFrame,
	}, { Ui.corner(14) })
	x.Activated:Connect(function()
		Sounds.play("click", 0.4)
		Webtoon.close()
		-- 창을 닫으면 폰 게임·쇼핑처럼 [일하기]로 돌아가요
		if player:GetAttribute("SalaryAction") == "webtoon" then
			Remotes.SetAction:FireServer("work")
		end
	end)
	return newFrame
end

local function screenOf(parent: Frame): Frame
	return Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 1, -32),
		BackgroundColor3 = Color3.fromRGB(252, 250, 244),
		ZIndex = 46,
		Parent = parent,
	}, { Ui.corner(14), Ui.padding(10) })
end

local showList: (known: any?) -> ()

---------------------------------------------------------------------------
-- 한 화 보기
---------------------------------------------------------------------------
local function drawPanel(parent: Frame, panel: any)
	local scene = SCENES[panel.scene] or SCENES.office
	local box = Ui.make("Frame", {
		Size = UDim2.new(1, 0, 0, 232),
		BackgroundColor3 = scene.back,
		ClipsDescendants = true,
		ZIndex = 47,
		Parent = parent,
	}, { Ui.corner(10), Ui.stroke(INK, 2) })
	Ui.make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = scene.floor, BorderSizePixel = 0, ZIndex = 47, Parent = box })
	-- 등장인물 (왼쪽 · 오른쪽) · 가운데 소품
	if panel.left then
		label(box, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.26, 0, 1, -18), Size = UDim2.fromOffset(92, 92), Text = panel.left, TextSize = 76, TextWrapped = false, ZIndex = 48 })
	end
	if panel.right then
		label(box, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.74, 0, 1, -18), Size = UDim2.fromOffset(92, 92), Text = panel.right, TextSize = 76, TextWrapped = false, ZIndex = 48 })
	end
	if panel.prop then
		local alone = not panel.left and not panel.right
		label(box, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, if alone then -24 else -12),
			Size = UDim2.fromOffset(if alone then 96 else 52, if alone then 96 else 52),
			Text = panel.prop,
			TextSize = if alone then 80 else 40,
			TextWrapped = false,
			ZIndex = 49,
		})
	end
	-- 말풍선 (왼쪽 사람 말은 왼쪽 위, 오른쪽 사람 말은 오른쪽 위)
	local function bubble(text: string, right: boolean, y: number)
		local back = Ui.make("Frame", {
			AnchorPoint = Vector2.new(if right then 1 else 0, 0),
			Position = UDim2.new(if right then 1 else 0, if right then -8 else 8, 0, y),
			Size = UDim2.fromOffset(176, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 50,
			Parent = box,
		}, { Ui.corner(12), Ui.stroke(INK, 2), Ui.padding(8) })
		label(back, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = text, TextSize = 15, ZIndex = 51 })
	end
	if panel.sayLeft then
		bubble(panel.sayLeft, false, 8)
	end
	if panel.sayRight then
		bubble(panel.sayRight, true, if panel.sayLeft then 70 else 8)
	end
	-- 효과음 글씨
	if panel.sfx then
		label(box, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.36),
			Size = UDim2.fromOffset(200, 44),
			Text = panel.sfx,
			Font = Enum.Font.GothamBlack,
			TextSize = 30,
			TextColor3 = Theme.Color.coral,
			Rotation = -8,
			TextWrapped = false,
			ZIndex = 51,
		})
	end
	-- 해설
	label(parent, {
		Position = UDim2.fromOffset(0, 238),
		Size = UDim2.new(1, 0, 0, 44),
		Text = panel.caption or "",
		Font = Enum.Font.GothamMedium,
		TextSize = 14,
		TextColor3 = MUTED,
	})
end

local function showEpisode(series: any, episodeIndex: number)
	local episode = series.episodes[episodeIndex]
	local okStart, reply = pcall(function()
		return Remotes.Webtoon:InvokeServer("start", series.id, episodeIndex)
	end)
	if not okStart or typeof(reply) ~= "table" or not reply.ok then
		Ui.toast(if okStart and typeof(reply) == "table" and reply.message then reply.message else "📺 지금은 볼 수 없어요.", 3)
		return
	end
	local index = 1
	local reached = 1 -- 여기까지는 읽는 시간을 채웠어요 (이전 컷으로 돌아가도 다시 기다리지 않아요)
	local function draw()
		local root = shell(`{series.emoji} {series.title} · {episodeIndex}화 「{episode.title}」`)
		local myToken = token
		local screen = screenOf(root)
		drawPanel(screen, episode.panels[index])
		-- 컷 번호 점
		local dots = {}
		for i = 1, #episode.panels do
			table.insert(dots, if i == index then "●" else "○")
		end
		label(screen, { Position = UDim2.fromOffset(0, 286), Size = UDim2.new(1, 0, 0, 18), Text = table.concat(dots, " "), TextSize = 13, TextColor3 = MUTED })
		-- 읽는 시간 막대 + 다음 버튼
		local back = Ui.make("Frame", { Position = UDim2.fromOffset(0, 308), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = Color3.fromRGB(226, 226, 220), ZIndex = 47, Parent = screen }, { Ui.corner(3) })
		local fill = Ui.make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Color.yellow, ZIndex = 48, Parent = back }, { Ui.corner(3) })
		local last = index == #episode.panels
		-- ◀ 이전 컷 (첫 컷에서는 목록으로)
		local prevButton = Ui.button({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(0.34, -4, 0, 40),
			Text = if index == 1 then "◀ 목록" else "◀ 이전",
			TextSize = 15,
			BackgroundColor3 = Color3.fromRGB(240, 242, 248),
			TextColor3 = INK,
			ZIndex = 47,
			Parent = screen,
		})
		prevButton.Activated:Connect(function()
			if token ~= myToken then
				return
			end
			Sounds.play("click", 0.4)
			if index == 1 then
				showList()
			else
				index -= 1
				draw()
			end
		end)
		local nextButton = Ui.button({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, 0, 1, 0),
			Size = UDim2.new(0.66, -4, 0, 40),
			Text = "읽는 중…",
			TextSize = 16,
			BackgroundColor3 = Color3.fromRGB(226, 226, 220),
			TextColor3 = MUTED,
			AutoButtonColor = false,
			ZIndex = 47,
			Parent = screen,
		})
		local ready = false
		local function unlock()
			if token == myToken and nextButton.Parent then
				ready = true
				reached = math.max(reached, index + 1)
				nextButton.Text = if last then "끝! 완독하기 🎉" else "다음 컷 ▶"
				nextButton.BackgroundColor3 = Theme.Color.yellow
				nextButton.TextColor3 = INK
			end
		end
		if index < reached then
			fill.Size = UDim2.fromScale(1, 1)
			unlock() -- (이미 읽은 컷)
		else
			TweenService:Create(fill, TweenInfo.new(SalaryConfig.WEBTOON_PANEL_SECONDS, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) }):Play()
			task.delay(SalaryConfig.WEBTOON_PANEL_SECONDS, unlock)
		end
		nextButton.Activated:Connect(function()
			if not ready or token ~= myToken then
				return
			end
			ready = false
			Sounds.play("click", 0.4)
			if not last then
				index += 1
				draw()
				return
			end
			local okFinish, result = pcall(function()
				return Remotes.Webtoon:InvokeServer("finish", series.id, episodeIndex)
			end)
			if okFinish and typeof(result) == "table" and result.ok then
				if (result.bonus or 0) > 0 then
					Sounds.play("ping", 0.6, 1.2)
				end
			else
				Ui.toast(if okFinish and typeof(result) == "table" and result.message then result.message else "📺 완독 처리에 실패했어요.", 3)
			end
			if token == myToken then
				-- 완독 답장에 들어 있는 진행 상황으로 바로 그려요 (다음 화 자물쇠가 곧바로 풀려요)
				showList(if okFinish and typeof(result) == "table" then result.progress else nil)
			end
		end)
	end
	draw()
end

---------------------------------------------------------------------------
-- 작품 목록
---------------------------------------------------------------------------
function showList(known: any?)
	local root = shell("📺 월급툰")
	local myToken = token
	local screen = screenOf(root)
	local status = label(screen, { Size = UDim2.new(1, 0, 0, 20), Text = "불러오는 중…", TextSize = 13, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left })
	task.spawn(function()
		local progress = known
		if typeof(progress) ~= "table" then
			local okList, reply = pcall(function()
				return Remotes.Webtoon:InvokeServer("list")
			end)
			if token ~= myToken then
				return
			end
			progress = if okList and typeof(reply) == "table" and typeof(reply.progress) == "table" then reply.progress else { read = {}, newLeft = 0 }
		end
		local read = if typeof(progress.read) == "table" then progress.read else {}
		local newLeft = progress.newLeft or 0
		status.Text = if newLeft > 0 then `오늘 새로 볼 수 있는 화: {newLeft}화` else "오늘 새 화는 다 봤어요. 다음 화는 내일!"
		local listBox = Ui.make("ScrollingFrame", {
			Position = UDim2.fromOffset(0, 24),
			Size = UDim2.new(1, 0, 1, -24 - 38),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = INK,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			CanvasSize = UDim2.fromOffset(0, #SalaryConfig.Webtoons * 98),
			ZIndex = 46,
			Parent = screen,
		}, { Ui.make("UIPadding", { PaddingRight = UDim.new(0, 8) }) })
		local y = 0
		for _, series in SalaryConfig.Webtoons do
			local seen = read[series.id] or 0
			local card = Ui.make("Frame", {
				Position = UDim2.fromOffset(0, y),
				Size = UDim2.new(1, 0, 0, 92),
				BackgroundColor3 = Color3.fromRGB(240, 242, 248),
				ZIndex = 47,
				Parent = listBox,
			}, { Ui.corner(10), Ui.padding(8) })
			label(card, { Size = UDim2.new(1, 0, 0, 22), Text = `{series.emoji} {series.title}`, Font = Enum.Font.GothamBlack, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 48 })
			label(card, { Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 18), Text = `{series.blurb} · {seen}/{#series.episodes}화`, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 48 })
			for i, episode in series.episodes do
				local column, row = (i - 1) % 5, math.floor((i - 1) / 5)
				local open = i <= seen + 1
				local fresh = i == seen + 1
				local button = Ui.button({
					Position = UDim2.new(column / 5, 2, 0, 46 + row * 36),
					Size = UDim2.new(1 / 5, -4, 0, 32),
					Text = if i <= seen then `{i}화 ✅` elseif fresh then `{i}화 ▶` else `{i}화 🔒`,
					TextSize = 12,
					BackgroundColor3 = if fresh and newLeft > 0 then Theme.Color.yellow elseif open then Color3.fromRGB(255, 255, 252) else Color3.fromRGB(214, 222, 228),
					TextColor3 = if open then INK else MUTED,
					ZIndex = 48,
					Parent = card,
				})
				button.Activated:Connect(function()
					Sounds.play("click", 0.4)
					if not open then
						Ui.toast("📺 앞의 화부터 봐야 해요.", 2)
						return
					end
					local _ = episode
					showEpisode(series, i)
				end)
			end
			y += 98
		end
		label(screen, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 34),
			Text = `한 화를 끝까지 보면 완독 보너스 +{SalaryConfig.WEBTOON_BONUS}원\n중간에 일하기로 돌아가면 처음부터 다시 봐요`,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = MUTED,
		})
	end)
end

---------------------------------------------------------------------------
-- 시작: [웹툰 정주행] 상태가 되면 열고, 벗어나면 닫아요
---------------------------------------------------------------------------
function Webtoon.start()
	local function watching(): boolean
		return player:GetAttribute("SalaryState") == "webtoon"
	end
	local was = false
	player:GetAttributeChangedSignal("SalaryState"):Connect(function()
		local now = watching()
		if now and not was then
			showList()
		elseif not now and was then
			Webtoon.close()
		end
		was = now
	end)
	-- 웹툰을 보는 중에 [웹툰] 버튼을 또 누르면 창을 다시 열어요
	Hud.onWebtoonAgain = function()
		if watching() and not frame then
			showList()
		end
	end
end

return Webtoon
