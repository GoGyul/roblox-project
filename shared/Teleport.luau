-- 다른 장소로 플레이어 보내기 (서버에서만 사용)

local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Teleport = {}

-- reserve = true 이면 이 플레이어들만을 위한 새 서버(전용 서버)를 만들어서 보내요.
-- 반환값: 성공 여부, 실패했을 때 보여 줄 메시지
function Teleport.send(placeId: number, players: { Player }, reserve: boolean?): (boolean, string?)
	if placeId == 0 then
		return false, "장소 ID가 아직 설정되지 않았어요. (shared/Places.luau)"
	end
	if RunService:IsStudio() then
		return false, "스튜디오 테스트에서는 텔레포트가 동작하지 않아요. Publish한 게임에서 확인해 주세요!"
	end

	local options = Instance.new("TeleportOptions")
	options.ShouldReserveServer = reserve == true

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(placeId, players, options)
	end)
	if not ok then
		return false, `텔레포트에 실패했어요. 잠시 후 다시 시도해 주세요. ({err})`
	end
	return true, nil
end

return Teleport
