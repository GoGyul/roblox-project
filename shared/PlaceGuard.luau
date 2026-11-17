-- 🛡️ 장소 확인 안전장치 (서버에서 사용)
--
-- 세 장소(광장, 시계탑, 월급루팡)는 스크립트 폴더 이름이 같아서,
-- Rojo를 엉뚱한 스튜디오 창에 연결하고 게시하면 다른 장소가 덮어써질 수 있어요.
-- (예: 광장 창에 월급루팡 코드를 넣고 게시 → 게임에 들어가면 바로 사무실이 나옴)
--
-- 각 게임 코드가 시작할 때 "지금 장소 ID가 내가 있어야 할 장소인가?"를 확인하고,
-- 아니면 Output에 경고를 남기고 화면 위에 빨간 경고 띠를 띄워요.
-- 저장 안 한 새 Baseplate(장소 ID 0)에서는 확인하지 않아요.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Places = require(ReplicatedStorage.Shared.Places)

local PlaceGuard = {}

local function placeName(placeId: number): string
	if placeId == Places.LOBBY then
		return "🏛️ 광장"
	end
	for _, info in Places.Games do
		if info.placeId == placeId then
			return `{info.emoji} {info.name}`
		end
	end
	return "알 수 없는 장소"
end

local function showBanner(player: Player, message: string)
	local gui = Instance.new("ScreenGui")
	gui.Name = "PlaceGuardWarning"
	gui.DisplayOrder = 20000
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 70)
	label.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextWrapped = true
	label.Text = message
	label.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
end

-- codeName: 이 코드가 어떤 게임인지 ("lobby" 또는 Places.Games의 id)
function PlaceGuard.check(codeName: string)
	local expectedId = Places.LOBBY
	local codeLabel = "🏛️ 광장"
	if codeName ~= "lobby" then
		for _, info in Places.Games do
			if info.id == codeName then
				expectedId = info.placeId
				codeLabel = `{info.emoji} {info.name}`
			end
		end
	end

	local actualId = game.PlaceId
	if actualId == 0 or expectedId == 0 or actualId == expectedId then
		return -- 정상 (또는 아직 게시 안 한 새 장소)
	end

	local message = `⚠️ 장소가 잘못됐어요! 이 장소는 {placeName(actualId)}(ID {actualId})인데 {codeLabel} 코드가 들어 있어요. `
		.. "Rojo를 다른 창에 연결한 것 같아요. 이대로 게시하면 안 돼요!"
	for _ = 1, 3 do
		warn(message)
	end
	Players.PlayerAdded:Connect(function(player)
		showBanner(player, message)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(showBanner, player, message)
	end
end

return PlaceGuard
