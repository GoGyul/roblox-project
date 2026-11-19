-- 🃏 카드 더미: 1~count 번호를 섞어 두고 한 장씩 뽑아요
--   더미를 다 쓸 때까지 같은 번호가 다시 안 나와요 (문제·퍼즐을 최대한 골고루 랜덤하게)
--   local draw = Deck.new(function() return #목록 end)  →  draw() 하면 번호 하나

local Deck = {}

function Deck.new(getCount: () -> number): () -> number
	local pile: { number } = {}
	local last = 0
	return function(): number
		local count = getCount()
		if count <= 0 then
			return 1
		end
		if #pile == 0 then
			for i = 1, count do
				pile[i] = i
			end
			for i = #pile, 2, -1 do
				local j = math.random(1, i)
				pile[i], pile[j] = pile[j], pile[i]
			end
			-- 새 더미 첫 장이 방금 나온 번호면 맨 아래로 (연속으로 같은 게 안 나오게)
			if #pile > 1 and pile[#pile] == last then
				pile[1], pile[#pile] = pile[#pile], pile[1]
			end
		end
		local index = table.remove(pile) :: number
		if index > count then
			table.clear(pile) -- 목록 길이가 바뀌었으면 새로 섞어요
			return math.random(1, count)
		end
		last = index
		return index
	end
end

return Deck
