-- 👥 동료 직원 NPC
--
-- 동료들도 살아 있어요:
--   ⌨️ 자리에서 일하기 (대부분)
--   📱😴 몰래 농땡이 → 김부장에게 들키면 혼나요 (그동안 부장 시선이 거기 쏠려요 = 플레이어의 기회!)
--   🚶 탕비실·프린터·창가에 다녀오기
--   💬 플레이어가 말을 걸면 수다 떨기
--
-- 자세(Pose)는 모델 속성으로 알려 주면 클라이언트가 팔·몸 자세를 바꿔 보여 줘요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local ChatTopics = require(ReplicatedStorage.Shared.ChatTopics)
local Npc = require(script.Parent.Npc)
local Walker = require(script.Parent.Walker)

local Coworkers = {}

export type Coworker = {
	index: number,
	name: string,
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	desk: any,
	prompt: ProximityPrompt,
	atDesk: boolean,
	slacking: boolean,
	chatting: boolean,
	removed: boolean,
	borrowed: boolean, -- 🌸 워크숍·🍻 회식에 불려 가 있는 중 (평소 AI 멈춤)
}

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

local function randomLook()
	local shirts = {
		Color3.fromRGB(240, 240, 240),
		Color3.fromRGB(170, 200, 230),
		Color3.fromRGB(230, 200, 170),
		Color3.fromRGB(120, 120, 130),
		Color3.fromRGB(200, 170, 200),
	}
	return {
		skin = Color3.fromRGB(math.random(210, 240), math.random(170, 200), math.random(140, 170)),
		shirt = pick(shirts),
		pants = Color3.fromRGB(50, 50, 60),
	}
end

local SLACK_POSES = {
	{ pose = "phone", emoji = "📱" },
	{ pose = "sleep", emoji = "😴" },
}
local ERRAND_POSES = {
	{ pose = "coffee", emoji = "☕" },
	{ pose = "docs", emoji = "📄" },
}

-- onChat(player, coworker): 플레이어가 "수다 떨기"를 눌렀을 때 Employees가 처리해요
function Coworkers.start(office, boss, dayCycle, remotes, onChat: (Player, Coworker) -> ())
	local list: { [number]: Coworker } = {}

	local function setState(c: Coworker, pose: string, emoji: string)
		c.model:SetAttribute("Pose", pose)
		Npc.setStatus(c.model, emoji)
	end

	-- seconds 동안 기다려요. keepGoing()이 false가 되면 일찍 끝나요
	local function waitWhile(c: Coworker, seconds: number, keepGoing: (() -> boolean)?)
		local finish = os.clock() + seconds
		while os.clock() < finish and not c.removed and not c.borrowed do
			if keepGoing and not keepGoing() then
				return
			end
			task.wait(0.25)
		end
	end

	local function goErrand(c: Coworker)
		c.atDesk = false
		c.prompt.Enabled = false
		Npc.stand(c.model, c.desk.seat)
		task.wait(0.4)
		Npc.standUpright(c.model)
		c.desk.seat.Disabled = true -- 자리를 비운 동안 아무도 못 앉게 잠가요
		local function cancelled()
			return c.removed or c.borrowed
		end

		setState(c, "walk", "🚶")
		Walker.walkTo(c.humanoid, c.root, pick(office.spots), cancelled)
		local errand = pick(ERRAND_POSES)
		setState(c, errand.pose, errand.emoji)
		waitWhile(c, math.random(6, 12))

		setState(c, "walk", "🚶")
		Walker.walkTo(c.humanoid, c.root, c.desk.behind, cancelled)
		if c.removed or c.borrowed then
			return
		end
		c.desk.seat.Disabled = false
		Npc.sit(c.model, c.desk.seat)
		c.atDesk = true
		c.prompt.Enabled = true
	end

	local function runAi(c: Coworker)
		task.wait(math.random() * 10) -- 다 같이 움직이지 않게 시작을 흩어요
		while not c.removed do
			if dayCycle.phase == "offwork" or c.chatting or c.borrowed then
				task.wait(1)
				continue
			end
			setState(c, "work", "⌨️")
			if math.random() < 0.3 then
				Npc.say(c.model, pick(ChatTopics.Mumbles), 3) -- 혼잣말
			end
			waitWhile(c, math.random(15, 40), function()
				return not c.chatting
			end)
			if c.removed or c.chatting or c.borrowed then
				continue
			end

			local roll = math.random()
			if roll < 0.35 then
				-- 몰래 농땡이 (부장에게 들키면 혼나요)
				local slack = pick(SLACK_POSES)
				c.slacking = true
				setState(c, slack.pose, slack.emoji)
				waitWhile(c, math.random(8, 16), function()
					return c.slacking and not c.chatting
				end)
				c.slacking = false
			elseif roll < 0.65 then
				goErrand(c)
			end
		end
	end

	-- 동료 만들기
	for i, desk in office.desks do
		local name = SalaryConfig.CoworkerNames[(i - 1) % #SalaryConfig.CoworkerNames + 1]
		local model = Npc.create(name, randomLook(), office.folder)
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
		root:SetNetworkOwner(nil)

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "수다 떨기"
		prompt.ObjectText = name
		prompt.MaxActivationDistance = 6
		prompt.RequiresLineOfSight = false
		prompt.Parent = root

		local c: Coworker = {
			index = i,
			name = name,
			model = model,
			humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid,
			root = root,
			desk = desk,
			prompt = prompt,
			atDesk = true,
			slacking = false,
			chatting = false,
			removed = false,
			borrowed = false,
		}
		prompt.Triggered:Connect(function(player)
			if c.atDesk and not c.chatting then
				onChat(player, c)
			end
		end)

		Npc.sit(model, desk.seat)
		setState(c, "work", "⌨️")
		list[i] = c
		task.spawn(runAi, c)
	end

	-- 안전장치: 걷다가 넘어지거나 기울어진 동료를 1초마다 바로 세워요
	task.spawn(function()
		while true do
			task.wait(1)
			for _, c in list do
				if not c.removed and not c.atDesk and not c.borrowed then
					Npc.standUpright(c.model)
				end
			end
		end
	end)

	-- 김부장이 농땡이 치는 동료를 발견하면 혼내요
	task.spawn(function()
		while true do
			task.wait(0.3)
			if not boss.active or boss.scolding then
				continue
			end
			for _, c in list do
				if c.slacking and not c.removed and not c.borrowed and boss:canSee(c.model) then
					c.slacking = false
					setState(c, "work", "😰")
					local line = string.gsub(pick(SalaryConfig.BossLines.scoldCoworker), "{name}", c.name)
					boss:scold(c.model, line)
					for _, player in Players:GetPlayers() do
						remotes.Notify:FireClient(player, `🗣️ 김부장이 {c.name}을(를) 혼내는 중! 지금이 기회?`)
					end
					break
				end
			end
		end
	end)

	---------------------------------------------------------------- 다른 모듈에서 쓰는 기능
	local api = {}

	-- 플레이어가 이 자리에 앉게 되면 동료를 내보내요
	function api.remove(index: number)
		local c = list[index]
		if not c then
			return
		end
		c.removed = true
		c.desk.seat.Disabled = false -- 이제 플레이어 자리
		for _, child in c.desk.seat:GetChildren() do
			if child:IsA("Weld") and child.Name == "SeatWeld" then
				child:Destroy()
			end
		end
		c.model:Destroy()
		list[index] = nil
	end

	-- 🌸🍻 이벤트에 동료들을 불러가요: 자리에서 일으켜 세우고 평소 AI를 멈춰요
	function api.borrowAll(): { Coworker }
		local borrowed = {}
		for _, c in list do
			if c.removed or c.chatting or c.borrowed then
				continue
			end
			c.borrowed = true
			c.slacking = false
			c.atDesk = false
			c.prompt.Enabled = false
			Npc.stand(c.model, c.desk.seat)
			c.desk.seat.Disabled = true -- 비운 자리는 잠가요
			Npc.standUpright(c.model)
			setState(c, "walk", "🙂")
			table.insert(borrowed, c)
		end
		return borrowed
	end

	-- 이벤트가 끝나면 자리로 돌려보내요 (instant면 바로 순간이동해서 앉아요)
	function api.returnAll(instant: boolean?)
		for _, c in list do
			if not c.borrowed or c.removed then
				continue
			end
			task.spawn(function()
				local seated = c.humanoid.SeatPart -- 회식 벤치 등에 앉아 있었으면 일어나기
				if seated and seated:IsA("Seat") then
					Npc.stand(c.model, seated)
				end
				c.humanoid.WalkSpeed = 16
				if not instant then
					setState(c, "walk", "🚶")
					Walker.walkTo(c.humanoid, c.root, c.desk.behind, function()
						return c.removed
					end)
				end
				if c.removed then
					return
				end
				c.desk.seat.Disabled = false
				Npc.sit(c.model, c.desk.seat)
				c.atDesk = true
				c.prompt.Enabled = true
				c.borrowed = false
				setState(c, "work", "⌨️")
			end)
		end
	end

	function api.setChatting(c: Coworker, on: boolean)
		if c.removed then
			return
		end
		c.chatting = on
		c.slacking = false
		if on then
			setState(c, "chat", "💬")
		else
			setState(c, "work", "⌨️")
		end
	end

	return api
end

return Coworkers
