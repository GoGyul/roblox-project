-- 👀 창밖 시선: 부장님이 가끔 사무실 창가에서 회사 단지를 내려다봐요
--   예고(3초) → 내려다보기(7초). 그동안 창에서 보이는 곳(지붕·나무 밑·건물 안·건물 옆과 뒤·아주 먼 곳 제외)에 있으면 의심도가 올라요.
--   내려다보는 동안에는 사무실 안을 못 봐요: 사무실에 남은 사람에게는 잠깐의 기회예요.
--   단지에 있는 사람에게만 알림이 가고, 우리 회사 건물 창에 👀 표시가 켜져요 (멀리서도 보여요).
--   실제 의심도 계산은 Employees가 해요 (Employees.hooks.windowSees).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local Campus = require(script.Parent.Campus)

local WindowWatch = {}

function WindowWatch.start(office, boss, dayCycle, events, remotes)
	local campus = Campus.get()
	if not campus or not campus.windows then
		return nil
	end
	local eye = campus.windows[office.companyId] -- { part = 창 불빛, position = 눈 위치 }
	if not eye then
		return nil
	end
	local watching = false
	local random = Random.new()

	-- 창 위에 뜨는 👀 (평소엔 꺼 둬요)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 120)
	gui.StudsOffset = Vector3.new(0, 9, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 600
	gui.Enabled = false
	gui.Parent = eye.part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Text = "👀"
	label.Parent = gui
	local function show(state: "off" | "warn" | "watch")
		gui.Enabled = state ~= "off"
		label.Text = if state == "warn" then "❗" else "👀"
		eye.part.Transparency = if state == "off" then 1 else 0
		eye.part.Color = if state == "watch" then Color3.fromRGB(255, 96, 80) else Color3.fromRGB(255, 214, 110)
	end
	show("off")

	local function tellCampus(message: string)
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and Campus.contains(root.Position) then
				remotes.Notify:FireClient(player, message, 3)
			end
		end
	end
	local function tellOffice(message: string)
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and office.insideOffice(root.Position) then
				remotes.Notify:FireClient(player, message, 3)
			end
		end
	end
	local function canWatch(): boolean
		return dayCycle.phase == "work" and boss.active == true and not events:is("drill") and not events:is("workshop")
			and ReplicatedStorage:GetAttribute("CampusRain") ~= true -- 🌧️ 비 오는 날엔 창밖이 안 보여요
	end

	task.spawn(function()
		while true do
			task.wait(random:NextNumber(SalaryConfig.WINDOW_GAP[1], SalaryConfig.WINDOW_GAP[2]))
			if not canWatch() then
				continue
			end
			show("warn")
			tellCampus("❗ 부장님이 창가로 걸어와요! 지붕이나 나무 밑, 건물 안으로 숨어요!")
			task.wait(SalaryConfig.WINDOW_WARN)
			if canWatch() then
				watching = true
				show("watch")
				tellOffice("🪟 부장님이 창밖을 내려다봐요. 지금 사무실 안은 안 봐요! (잠깐)")
				local left = SalaryConfig.WINDOW_SECONDS
				while left > 0 and canWatch() do
					left -= task.wait(0.25)
				end
				watching = false
				tellCampus("😮‍💨 부장님이 창가에서 돌아섰어요.")
			end
			show("off")
		end
	end)

	return {
		-- 지금 이 자리가 창가의 부장님 눈에 보이나
		sees = function(position: Vector3): boolean
			return watching and Campus.contains(position) and Campus.inWindowView(position, office.companyId) and not Campus.hidden(position)
		end,
		-- 부장님이 창밖을 보느라 사무실 안을 못 보는 중인가
		busy = function(): boolean
			return watching
		end,
	}
end

return WindowWatch
