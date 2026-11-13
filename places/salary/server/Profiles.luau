-- 💾 저장 기능 (DataStore)
-- 플레이어가 나가도 직급, 경력, 통장, 아이템, 도감이 남아 있게 로블록스 서버에 저장해요.
--
-- ⚠️ 스튜디오에서 테스트할 때는 저장이 되려면 설정이 필요해요:
--    File → Experience Settings → Security → "Enable Studio Access to API Services" 켜기
--    꺼져 있으면 저장 없이 그냥 플레이돼요 (오류로 멈추지 않아요).

local DataStoreService = game:GetService("DataStoreService")

local Profiles = {}

local STORE_NAME = "SalaryLupin_v1"

export type Profile = {
	version: number,
	rank: number, -- SalaryConfig.Ranks 번호
	xp: number, -- 누적 경력 (지금까지 받은 월급 합계, 매점에서 써도 안 줄어요)
	money: number, -- 통장 잔고
	warnings: number,
	items: { [string]: boolean }, -- 산 아이템
	energy: number, -- 에너지 드링크 개수
	collection: { [string]: boolean }, -- 도감: "action_낮잠" 같은 행동 + 업적 ID
	stats: { days: number, nearMiss: number, caught: number, fired: number },
}

function Profiles.default(): Profile
	return {
		version = 1,
		rank = 1,
		xp = 0,
		money = 0,
		warnings = 0,
		items = {},
		energy = 0,
		collection = {},
		stats = { days = 0, nearMiss = 0, caught = 0, fired = 0 },
	}
end

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Profiles] DataStore를 열 수 없어요. 저장 없이 진행합니다:", result)
	end
end

local function key(player: Player): string
	return `player_{player.UserId}`
end

-- 예전 저장 데이터에 없는 항목은 기본값으로 채워요
local function fillDefaults(profile: any): Profile
	local base = Profiles.default()
	for field, value in base do
		if profile[field] == nil then
			profile[field] = value
		end
	end
	for field, value in base.stats do
		if profile.stats[field] == nil then
			profile.stats[field] = value
		end
	end
	return profile
end

-- 불러오기. 두 번째 값 canSave가 false면 저장하지 않아요
-- (불러오기에 실패했는데 저장해 버리면 진짜 데이터를 빈 데이터로 덮어쓸 수 있어서)
function Profiles.load(player: Player): (Profile, boolean)
	if not store then
		return Profiles.default(), false
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return (store :: DataStore):GetAsync(key(player))
		end)
		if ok then
			if typeof(result) == "table" then
				return fillDefaults(result), true
			end
			return Profiles.default(), true -- 처음 온 플레이어
		end
		warn(`[Profiles] 불러오기 실패 ({attempt}/3):`, result)
		task.wait(1)
	end
	return Profiles.default(), false
end

function Profiles.save(player: Player, profile: Profile): boolean
	if not store then
		return false
	end
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync(key(player), profile)
	end)
	if not ok then
		warn("[Profiles] 저장 실패:", err)
	end
	return ok
end

return Profiles
