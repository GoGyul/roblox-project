-- 🛡️ 요청 속도 제한
-- 해킹 툴로 서버에 요청을 1초에 수백 번 보내는 걸 막아요.
-- 정상 플레이어는 버튼을 이렇게 빨리 누를 수 없어서 아무 차이도 못 느껴요.
--
-- 사용법:
--   local allowBuy = RateLimit.new(0.3)      -- 0.3초에 한 번까지
--   if not allowBuy(player) then return end  -- 너무 빠르면 무시

local Players = game:GetService("Players")

local RateLimit = {}

function RateLimit.new(seconds: number): (player: Player) -> boolean
	local last: { [Player]: number } = {}
	Players.PlayerRemoving:Connect(function(player)
		last[player] = nil
	end)
	return function(player: Player): boolean
		local now = os.clock()
		local previous = last[player]
		if previous and now - previous < seconds then
			return false
		end
		last[player] = now
		return true
	end
end

return RateLimit
