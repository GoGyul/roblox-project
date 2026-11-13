-- 출발 대기열: 포탈 앞 발판 위에 선 플레이어들을 한 팀으로 묶어서
-- 카운트다운이 끝나면 그 게임의 팀 전용 서버로 함께 텔레포트해요.
-- 포탈마다 Queue.new()로 대기열을 하나씩 만들어요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Places = require(ReplicatedStorage.Shared.Places)
local Teleport = require(ReplicatedStorage.Shared.Teleport)

local Queue = {}

local COUNTDOWN = 10 -- 첫 사람이 올라선 뒤 출발까지 몇 초

local remotes = nil
local launching: { [Player]: boolean } = {} -- 텔레포트 중인 사람 (모든 포탈 공통)

local function failed(player: Player, message: string)
	launching[player] = nil
	remotes.TeleportFailed:FireClient(player)
	remotes.Notify:FireClient(player, message)
end

-- 처음 한 번만 호출
function Queue.setup(lobbyRemotes)
	remotes = lobbyRemotes

	-- 텔레포트 요청은 성공했지만 이동 도중 실패한 경우
	TeleportService.TeleportInitFailed:Connect(function(player, _result, errorMessage)
		failed(player, `이동 중에 문제가 생겼어요. 다시 시도해 주세요. ({errorMessage})`)
	end)

	Players.PlayerRemoving:Connect(function(player)
		launching[player] = nil
	end)
end

-- 포탈 하나의 대기열 만들기
function Queue.new(pad: BasePart, statusLabel: TextLabel, info: Places.GameInfo)
	local members: { Player } = {} -- 지금 대기 중인 팀 (들어온 순서)
	local warnedFull: { [Player]: boolean } = {}
	local timeLeft: number? = nil

	-- 이 플레이어가 발판 위에 서 있나요?
	local function isOnPad(player: Player): boolean
		if launching[player] then
			return false
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (root and humanoid) or humanoid.Health <= 0 then
			return false
		end
		-- 발판 기준 좌표로 바꿔서 발판 사각형 안에 있는지 확인
		local offset = pad.CFrame:PointToObjectSpace(root.Position)
		return math.abs(offset.X) <= pad.Size.X / 2 and math.abs(offset.Z) <= pad.Size.Z / 2 and offset.Y > 0 and offset.Y < 8
	end

	local function launch(group: { Player })
		for _, player in group do
			launching[player] = true
			remotes.Teleporting:FireClient(player, `{info.emoji} {info.name}`)
		end
		task.spawn(function()
			local ok, message = Teleport.send(info.placeId, group, true)
			if not ok then
				task.wait(1.5) -- 로딩 화면이 너무 순식간에 사라지지 않게
				for _, player in group do
					failed(player, message or "텔레포트에 실패했어요.")
				end
			end
		end)
	end

	local function updateStatus()
		if #members == 0 then
			statusLabel.Text = `발판에 올라서면 출발 대기!\n(한 팀 최대 {info.maxPlayers}명)`
		else
			statusLabel.Text = `{#members}/{info.maxPlayers}명 대기 중\n{math.ceil(timeLeft or COUNTDOWN)}초 후 출발`
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		-- 발판에서 내려간 사람 빼기
		for i = #members, 1, -1 do
			if not isOnPad(members[i]) then
				table.remove(members, i)
			end
		end
		-- 새로 올라온 사람 넣기
		for _, player in Players:GetPlayers() do
			if not isOnPad(player) then
				warnedFull[player] = nil
			elseif not table.find(members, player) then
				if #members < info.maxPlayers then
					table.insert(members, player)
				elseif not warnedFull[player] then
					warnedFull[player] = true
					remotes.Notify:FireClient(player, "이번 팀은 가득 찼어요. 다음 출발을 기다려 주세요!")
				end
			end
		end

		-- 카운트다운
		if #members == 0 then
			timeLeft = nil
		else
			timeLeft = (timeLeft or COUNTDOWN) - dt
			if (timeLeft :: number) <= 0 then
				local group = table.clone(members)
				table.clear(members)
				timeLeft = nil
				launch(group)
			end
		end
		updateStatus()
	end)

	Players.PlayerRemoving:Connect(function(player)
		warnedFull[player] = nil
	end)
end

return Queue
