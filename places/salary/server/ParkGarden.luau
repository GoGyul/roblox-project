-- 🌷 내 공원 화단 (눈치물산 공원만)
--   공원 화단 [E] → 내 화단 창 (🎒 꽃씨 심기 · 💧 물 주기 · 🧪 거름 주기 · 🧹 뽑기)
--   꽃씨·거름은 🏪 사내 매점 [🌱 씨앗] 탭 → [🌷 꽃씨·거름]에서 사서 🎒에 보관해요
--   화단 데이터는 사람마다 저장돼요. 화단 위 꽃은 각자 화면에 "내 것"으로 그려져요 (ParkBeds 위치)
--   규칙은 SalaryConfig "🌷 내 공원 화단" 설명을 봐요

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local RateLimit = require(ReplicatedStorage.Shared.RateLimit)

local ParkGarden = {}

-- beds: 화단 흙 Part들 / hooks.action(player, 행동, 화단 번호, 꽃 ID) → (ok, 메시지)
function ParkGarden.start(beds: { BasePart }?, remotes, hooks)
	if not beds or #beds == 0 then
		return -- 🏢 대충상사엔 공원이 없어요
	end
	local bedList = beds :: { BasePart }
	local allow = RateLimit.new(0.25)
	-- 화면이 꽃을 그릴 자리: 흙 윗면 가운데 + 크기
	local spots = {}
	for i, bed in bedList do
		local top = bed.Position + Vector3.new(0, bed.Size.Y / 2, 0)
		table.insert(spots, { top.X, top.Y, top.Z, bed.Size.X, bed.Size.Z })
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "화단 가꾸기"
		prompt.ObjectText = `🌷 내 공원 화단 {i}`
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = bed
		prompt.Triggered:Connect(function(player)
			remotes.ParkOpen:FireClient(player, i, bed.Position) -- 🚪 화단에서 멀어지면 창이 닫혀요
		end)
	end
	ReplicatedStorage:SetAttribute("ParkBeds", HttpService:JSONEncode(spots))

	local function near(player: Player, index: number): boolean
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local bed = bedList[index]
		if not root or not bed then
			return false
		end
		return (root.Position - bed.Position).Magnitude < 13
	end

	remotes.ParkAction.OnServerInvoke = function(player: Player, action: any, index: any, flowerId: any)
		if not allow(player) then
			return { ok = false, message = "천천히!" }
		end
		if typeof(action) ~= "string" or typeof(index) ~= "number" or index ~= math.floor(index) then
			return { ok = false, message = "잘못된 요청이에요." }
		end
		if not near(player, index) then
			return { ok = false, message = `🌷 {index}번 화단 앞에서 해 주세요!` }
		end
		local ok, message = hooks.action(player, action, index, flowerId)
		return { ok = ok, message = message }
	end
end

return ParkGarden
