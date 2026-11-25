-- 🏢 회사별 서버 배정
--
-- 월급루팡은 서버 하나가 사무실 하나(대충상사 또는 눈치물산)예요.
-- 단독 게임이 되면서 모르는 사람끼리 같은 서버에 배정되는데, Roblox는 직급을 모르니까
-- 신입이 눈치물산 서버에 들어오는 일이 생겨요. 그래서:
--
--   1. 서버마다 "나는 어느 회사이고 자리가 몇 개 남았어요"를 게시판(MemoryStore)에 30초마다 적어요.
--   2. 내 직급의 회사와 다른 서버에 들어온 사람은, 게시판에서 내 회사 서버를 찾아 그리로 보내요.
--   3. 자리가 있는 서버가 없으면 새 서버를 하나 열고(예약 서버) 게시판에 올려서 다음 사람이 찾아오게 해요.
--
-- 그대로 두는 경우: 친구를 따라 들어온 사람, 비공개(VIP) 서버, 스튜디오, 이미 한 번 배정받아 온 사람(무한 이동 방지)
-- 게시판이 고장 나도 게임은 돌아가요: 그때는 예전처럼 새 서버를 열거나, 지금 서버에서 그냥 일해요.

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Matchmaking = {}

local OPEN_PREFIX = "SalaryOpen_v1_" -- + 회사 id: 자리가 있는 서버 목록
local RESERVED_MAP = "SalaryReserved_v1" -- 예약 서버 ID → { code, company }
local HEARTBEAT = 30 -- 초마다 게시판을 고쳐 써요
local ENTRY_TTL = 75 -- 이만큼 소식이 없으면 목록에서 사라져요 (서버가 꺼진 것)
local RESERVED_TTL = 30 * 24 * 3600 -- 예약 서버 입장 코드를 기억해 두는 시간
local MARKER = "salaryMatched" -- 배정받아 온 사람 표시 (도착한 서버에서 또 보내지 않게)

type Entry = { players: number, jobId: string?, code: string? }

local isStudio = RunService:IsStudio()
-- 공개 서버: 둘 다 비어 있음 / 예약 서버: PrivateServerId만 있음 / 비공개(VIP) 서버: 주인 ID가 있음
local isVip = game.PrivateServerOwnerId ~= 0
local isReserved = game.PrivateServerId ~= "" and not isVip

local myCode: string? = nil -- (예약 서버일 때) 다른 사람이 들어올 수 있는 입장 코드
local myCompany: string? = nil
local reservedInfo: { code: string, company: string }? = nil
local reservedLoaded = false
local pending: { [Player]: string } = {} -- 보내는 중인 사람 → 회사 id (실패하면 한 번 더 시도)

local function openMap(companyId: string)
	return MemoryStoreService:GetSortedMap(OPEN_PREFIX .. companyId)
end

-- 예약 서버라면, 이 서버를 연 쪽이 남겨 둔 정보(입장 코드·회사)를 읽어요
local function loadReserved()
	if reservedLoaded or not isReserved or isStudio then
		return
	end
	reservedLoaded = true
	for _ = 1, 3 do
		local ok, value = pcall(function()
			return MemoryStoreService:GetSortedMap(RESERVED_MAP):GetAsync(game.PrivateServerId)
		end)
		if ok then
			if type(value) == "table" and type(value.code) == "string" and type(value.company) == "string" then
				reservedInfo = value
			end
			return
		end
		task.wait(1)
	end
end

-- 이 예약 서버가 어느 회사용으로 열렸나 (공개 서버·알 수 없으면 nil → 처음 들어온 사람의 직급으로 정해요)
function Matchmaking.reservedCompany(): string?
	loadReserved()
	return reservedInfo and reservedInfo.company
end

local function publish()
	if not myCompany then
		return
	end
	local count = #Players:GetPlayers()
	local key = if isReserved then game.PrivateServerId else game.JobId
	pcall(function()
		if count >= Players.MaxPlayers or count == 0 then
			openMap(myCompany):RemoveAsync(key) -- 꽉 찼거나 비었으면 목록에서 빼요
		else
			local entry: Entry = { players = count, jobId = if isReserved then nil else game.JobId, code = myCode }
			openMap(myCompany):SetAsync(key, entry, ENTRY_TTL)
		end
	end)
end

-- 사무실이 정해진 뒤 한 번 불러요: 이 서버를 게시판에 올리기 시작해요
function Matchmaking.start(companyId: string)
	if isStudio or isVip or game.JobId == "" then
		return
	end
	loadReserved()
	if isReserved then
		if not reservedInfo then
			return -- 입장 코드를 모르는 예약 서버는 남이 찾아올 수 없어요
		end
		myCode = reservedInfo.code
	end
	myCompany = companyId
	task.spawn(function()
		while true do
			publish()
			task.wait(HEARTBEAT)
		end
	end)
	-- 사람이 들고 날 때는 바로 고쳐 써요 (꽉 찬 서버로 보내는 일을 줄이려고)
	Players.PlayerAdded:Connect(function()
		task.defer(publish)
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(publish)
	end)
	game:BindToClose(function()
		local key = if isReserved then game.PrivateServerId else game.JobId
		pcall(function()
			openMap(companyId):RemoveAsync(key)
		end)
	end)
end

-- 이 사람을 내 회사 서버로 옮겨 줘야 하나? (회사가 다른 건 부르는 쪽에서 확인해요)
function Matchmaking.shouldRoute(player: Player): boolean
	if isStudio or isVip then
		return false
	end
	if player.FollowUserId ~= 0 then
		return false -- 친구를 따라 들어온 사람은 같이 일해요
	end
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	local teleportData = ok and joinData and joinData.TeleportData
	if type(teleportData) == "table" and teleportData[MARKER] == true then
		return false -- 이미 배정받아 온 사람 (또 보내면 끝없이 돌아요)
	end
	return true
end

local function teleport(player: Player, configure: (TeleportOptions) -> ()): (boolean, any)
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({ [MARKER] = true })
	configure(options)
	return pcall(function()
		return TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
end

-- 자리가 있는 그 회사 서버를 찾아요 (사람이 많은 서버부터: 서로 모이게)
local function findOpen(companyId: string): Entry?
	local ok, rows = pcall(function()
		return openMap(companyId):GetRangeAsync(Enum.SortDirection.Ascending, 30)
	end)
	if not ok or type(rows) ~= "table" then
		return nil
	end
	local best: Entry? = nil
	for _, row in rows do
		local entry = row.value
		if type(entry) == "table" and type(entry.players) == "number" and entry.players < Players.MaxPlayers
			and (type(entry.jobId) == "string" or type(entry.code) == "string")
			and entry.jobId ~= game.JobId
			and (myCode == nil or entry.code ~= myCode) -- (내 서버는 빼요)
		then
			if not best or entry.players > best.players then
				best = entry
			end
		end
	end
	return best
end

-- 그 회사용 새 서버를 열어서 보내요 (다음 사람이 찾아올 수 있게 입장 코드를 남겨요)
local function sendToNew(player: Player, companyId: string): (boolean, string?)
	local ok, result = teleport(player, function(options)
		options.ShouldReserveServer = true
	end)
	if not ok then
		return false, `이동에 실패했어요. 잠시 후 다시 시도해 주세요. ({result})`
	end
	task.spawn(function()
		pcall(function()
			local code, serverId = result.ReservedServerAccessCode, result.PrivateServerId
			if type(code) == "string" and code ~= "" and type(serverId) == "string" and serverId ~= "" then
				MemoryStoreService:GetSortedMap(RESERVED_MAP):SetAsync(serverId, { code = code, company = companyId }, RESERVED_TTL)
			end
		end)
	end)
	return true, nil
end

-- 플레이어를 그 회사 사무실 서버로 보내요. 반환값: 성공 여부, 실패했을 때 보여 줄 메시지
function Matchmaking.send(player: Player, companyId: string): (boolean, string?)
	if isStudio then
		return false, "스튜디오 테스트에서는 서버 이동이 동작하지 않아요. 게시한 게임에서 확인해 주세요!"
	end
	local entry = findOpen(companyId)
	if entry then
		local ok = teleport(player, function(options)
			if entry.code then
				options.ReservedServerAccessCode = entry.code
			else
				options.ServerInstanceId = entry.jobId :: string
			end
		end)
		if ok then
			pending[player] = companyId -- 그 사이 꽉 찼으면 아래에서 새 서버로 한 번 더 보내요
			return true, nil
		end
	end
	return sendToNew(player, companyId)
end

Players.PlayerRemoving:Connect(function(player)
	pending[player] = nil
end)

if not isStudio then
	-- 고른 서버가 그 사이 꽉 찼거나 꺼졌을 때: 새 서버를 열어 한 번만 다시 보내요
	TeleportService.TeleportInitFailed:Connect(function(player: Player)
		local companyId = pending[player]
		if companyId then
			pending[player] = nil
			if player.Parent then
				sendToNew(player, companyId)
			end
		end
	end)
end

return Matchmaking
