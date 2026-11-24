-- 🚏 도착 동선: 회사 단지(Campus) ↔ 사무실 층을 엘리베이터·계단으로 오가요
--   처음 접속하면 단지 북쪽 버스 정류장에서 시작해요 → 우리 회사 건물 로비 → 엘리베이터 → 사무실 층
--   (대충상사는 계단도 있어요: 느리지만 부장님을 안 만나요)
--   그 뒤로 다시 태어날 땐 사무실 엘리베이터 앞이에요 (사무실의 SpawnLocation).
--   단지는 사무실에서 멀리 떨어진 곳에 있어요. 옥상처럼 순간이동으로 오가요.
--   엘리베이터 [E]를 누르면 층 고르기 창(옥상 / 사무실 / 1층)이 떠요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Build = require(ReplicatedStorage.Shared.Build)
local Rooftop = require(script.Parent.Rooftop)
local Ambience = require(script.Parent.Ambience)
local Campus = require(script.Parent.Campus)

local Arrival = {}

local ELEVATOR_SECONDS = 2.5
local STAIRS_SECONDS = 7 -- 계단은 느려요 (대신 부장님과 마주칠 일이 없어요)

function Arrival.start(office, remotes, events)
	local campus = Campus.get()
	if not campus then
		return -- 단지가 없는 (예전) 사무실
	end
	local daechung = office.companyId == "daechung"
	local place = if daechung then campus.daechung else campus.nunchi -- 우리 회사 로비
	local other = if daechung then campus.nunchi else campus.daechung -- 옆 회사 로비 (구경만 돼요)
	local FLOOR = if daechung then "3층" else "12층"
	local folder = office.folder
	Ambience.loop("street", folder, Campus.point(0, 6, -120), 160) -- 🚗 큰길 소리
	Ambience.loop("lobby", folder, place.lobbyElevator.Position + Vector3.new(0, 4, 0), 34) -- 로비 소리

	local traveling: { [Player]: boolean } = {}
	local function travel(player: Player, target: CFrame, seconds: number, message: string)
		if traveling[player] then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not humanoid or humanoid.Health <= 0 then
			return
		end
		traveling[player] = true
		remotes.Notify:FireClient(player, message)
		humanoid.Sit = false
		local speed = humanoid.WalkSpeed
		humanoid.WalkSpeed = 0
		task.delay(seconds, function()
			traveling[player] = nil
			if character.Parent and humanoid.Health > 0 then
				if humanoid.WalkSpeed == 0 then
					humanoid.WalkSpeed = speed
				end
				character:PivotTo(target)
				-- 📷 도착: 화면을 캐릭터 등 뒤로 돌려 도착한 곳이 바로 보이게 해요 (Guide 모듈이 받아서 돌려요)
				player:SetAttribute("ArriveLook", target.LookVector)
				player:SetAttribute("ArriveTick", os.clock())
				if string.find(message, "엘리베이터", 1, true) then
					Ambience.ding(target.Position) -- 🔔 띵
				end
			end
		end)
	end
	local function prompt(part: BasePart, action: string, object: string, hold: number, onTrigger: (Player) -> ())
		local p = Instance.new("ProximityPrompt")
		p.ActionText = action
		p.ObjectText = object
		p.HoldDuration = hold
		p.MaxActivationDistance = 9
		p.RequiresLineOfSight = false
		p.Parent = part
		p.Triggered:Connect(onTrigger)
	end

	local officeElevator = CFrame.new(office.elevator.exit + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.rad(-90), 0)
	local officeStairs = CFrame.new((office.stairSpot or office.elevator.exit) + Vector3.new(-3, 3, 0)) * CFrame.Angles(0, math.rad(90), 0) -- 계단 문 앞 (방 안쪽을 보고)

	-- 🚪 엘리베이터: [E] → 층 고르기 창 → 고른 층으로 (3층↔옥상은 예전처럼 Rooftop이 태워요: 부장님과 마주칠 수 있어요)
	local FLOOR_NAMES = { roof = "옥상", office = if daechung then "3층 (주)대충상사" else "12층 (주)눈치물산", lobby = "1층 로비 (단지)" }
	local FLOOR_ORDER = { "roof", "office", "lobby" }
	local pending: { [Player]: { from: string, at: number } } = {}
	local function openMenu(player: Player, from: string)
		pending[player] = { from = from, at = os.clock() }
		local options = {}
		for _, id in FLOOR_ORDER do
			if id ~= from then
				table.insert(options, { id = id, name = FLOOR_NAMES[id] })
			end
		end
		remotes.ElevatorMenu:FireClient(player, from, options)
	end
	local function near(player: Player, position: Vector3, range: number): boolean
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return root ~= nil and (root.Position - position).Magnitude <= range
	end
	local function rideRoof(player: Player, toRoof: boolean)
		if Rooftop.ride then
			Rooftop.ride(player, toRoof)
		end
	end
	remotes.ElevatorGo.OnServerEvent:Connect(function(player, destination)
		local request = pending[player]
		pending[player] = nil
		if not request or os.clock() - request.at > 20 or typeof(destination) ~= "string" or not FLOOR_NAMES[destination] or destination == request.from then
			return
		end
		local from = request.from
		-- 🛡️ 아직 그 엘리베이터 앞에 있는지 다시 확인해요
		if from == "office" and not near(player, office.elevator.exit, 18) then
			return
		elseif from == "lobby" and not near(player, place.elevatorDoor.Position, 16) then
			return
		end
		if from == "office" and destination == "roof" then
			rideRoof(player, true)
		elseif from == "roof" and destination == "office" then
			rideRoof(player, false)
		elseif from == "office" and destination == "lobby" then
			travel(player, place.lobbyElevator, ELEVATOR_SECONDS, "🚪 엘리베이터를 타고 1층으로 내려가요...")
		elseif from == "lobby" and destination == "office" then
			-- 올라가는 엘리베이터는 사무실↔옥상처럼 칸을 타요: 근무 중엔 부장님과 마주칠 수 있어요 (그래서 계단이 안전해요)
			if Rooftop.ride then
				remotes.Notify:FireClient(player, `🚪 엘리베이터를 타고 {FLOOR}으로 올라가요...`)
				Rooftop.ride(player, false, true)
			else
				travel(player, officeElevator, ELEVATOR_SECONDS, `🚪 엘리베이터를 타고 {FLOOR}으로 올라가요...`)
			end
		elseif from == "lobby" and destination == "roof" then
			-- 옥상까지 한 번에: 옥상행 칸을 타요 (부장님과 마주칠 수 있어요)
			remotes.Notify:FireClient(player, `🚪 엘리베이터를 타고 올라가요... ({FLOOR}을 지나 옥상으로)`)
			if Rooftop.ride then
				Rooftop.ride(player, true, true)
			end
		elseif from == "roof" and destination == "lobby" then
			rideRoof(player, false) -- 사무실 층에 닿을 때까지 기다려요
			if near(player, office.elevator.exit, 14) then
				travel(player, place.lobbyElevator, 1, `🚪 {FLOOR}을 지나 1층으로 내려가요...`)
			end
		end
	end)
	Rooftop.onElevator = function(player: Player, from: string): boolean
		openMenu(player, from)
		return true
	end
	prompt(place.elevatorDoor, "타기", "엘리베이터", 0, function(player)
		if events and events:is("blackout") then -- 💡 정전 중엔 엘리베이터도 멈춰요 (사무실·옥상 쪽과 같아요)
			remotes.Notify:FireClient(player, "💡 정전이라 엘리베이터가 멈췄어요! 불이 들어오면 타세요." .. (if daechung then " (계단은 돼요)" else ""))
			return
		end
		openMenu(player, "lobby")
	end)
	prompt(other.elevatorDoor, "타기", "엘리베이터", 0, function(player)
		remotes.Notify:FireClient(player, if daechung then "🚫 (주)눈치물산 사원증이 있어야 탈 수 있어요. (대리 이상)" else "🚫 여긴 (주)대충상사 엘리베이터예요. 우리 회사는 공원 동쪽 유리 타워!")
	end)

	-- 🚶 계단: 계단 앞에서 [E] (부장님을 안 만나는 대신 엘리베이터보다 오래 걸려요)
	local stairs = daechung and office.stairSpot ~= nil
	if stairs then
		prompt(place.stairTrigger, "3층으로 올라가기", "계단", 0.4, function(player)
			travel(player, officeStairs, STAIRS_SECONDS, "🚶 계단으로 3층까지 올라가요... (헉헉)")
		end)
	end

	if stairs then
		-- 3층 계단실: 동쪽 벽의 방화문 (계단은 문 뒤에 있어요) → [E] 1층으로 내려가기
		local spot = office.stairSpot :: Vector3
		local function piece(size: Vector3, offset: Vector3, color: Color3, material: Enum.Material, collide: boolean): Part
			local part = Instance.new("Part")
			part.Anchored = true
			part.CanCollide = collide
			part.Size = size
			part.Color = color
			part.Material = material
			part.CFrame = CFrame.new(spot + offset)
			part.Parent = office.folder
			return part
		end
		local frameColor, doorColor = Color3.fromRGB(70, 76, 84), Color3.fromRGB(138, 146, 152)
		local door = piece(Vector3.new(0.3, 10, 5.6), Vector3.new(3.0, 5, 0), doorColor, Enum.Material.Metal, true)
		door.Name = "StairsDoor"
		piece(Vector3.new(0.5, 10.6, 0.4), Vector3.new(2.95, 5.3, -3.0), frameColor, Enum.Material.Metal, false) -- 문틀
		piece(Vector3.new(0.5, 10.6, 0.4), Vector3.new(2.95, 5.3, 3.0), frameColor, Enum.Material.Metal, false)
		piece(Vector3.new(0.5, 0.5, 6.4), Vector3.new(2.95, 10.4, 0), frameColor, Enum.Material.Metal, false)
		piece(Vector3.new(0.1, 2.6, 1.4), Vector3.new(2.82, 6.6, 1.2), Color3.fromRGB(170, 196, 206), Enum.Material.Glass, false) -- 문에 난 작은 창
		piece(Vector3.new(0.3, 0.2, 1.2), Vector3.new(2.72, 4, -1.7), frameColor, Enum.Material.Metal, false) -- 손잡이
		local doorSign = piece(Vector3.new(0.2, 1.2, 3.6), Vector3.new(2.9, 11.6, 0), Color3.fromRGB(40, 110, 80), Enum.Material.SmoothPlastic, false)
		Build.surfaceText(doorSign, Enum.NormalId.Left, "계단", { Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1, 1, 1) })
		prompt(door, "1층으로 내려가기", "계단", 0.4, function(player)
			travel(player, place.lobbyStairs, STAIRS_SECONDS - 1, "🚶 계단으로 1층까지 내려가요...")
		end)
	end

	-- 처음 접속했을 때 한 번만 거리에서 시작해요
	local arrived: { [Player]: boolean } = {}
	local function onCharacter(player: Player, character: Model)
		if arrived[player] then
			return
		end
		arrived[player] = true
		task.wait(0.6) -- 다른 모듈이 캐릭터를 자리 잡게 한 뒤에
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.SeatPart then
			-- (의자에 앉은 채 옮기면 의자까지 끌려와요 → 먼저 떼어 내요)
			for _, child in humanoid.SeatPart:GetChildren() do
				if child:IsA("Weld") and child.Name == "SeatWeld" then
					child:Destroy()
				end
			end
			humanoid.Sit = false
			task.wait(0.1)
		end
		if character.Parent then
			character:PivotTo(Campus.SPAWN)
			remotes.Notify:FireClient(player, if daechung then "🚏 눈치단지 도착! 공원 서쪽(오른쪽) 상가 건물 3층이 (주)대충상사예요. 로비에서 엘리베이터나 계단을 타세요." else "🚏 눈치단지 도착! 공원 동쪽(왼쪽) 유리 타워 12층이 (주)눈치물산이에요. 로비에서 엘리베이터를 타세요.")
		end
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		arrived[player] = nil
		traveling[player] = nil
		pending[player] = nil
	end)
end

return Arrival
