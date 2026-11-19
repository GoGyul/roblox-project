-- 🌱 옥상 텃밭
--   옥상 화단 [E] → 내 화분 창 (심기 · 💧 물 주기 · 🧺 수확)
--   화분 데이터는 사람마다 저장돼요. 화분 위 식물은 각자 화면에 "내 것"으로 그려져요 (GardenSlots 위치)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)

local RoofGarden = {}

-- boxes: 화단 Part들 / hooks.action(player, 행동, 화분 번호, 씨앗) → (ok, 메시지)
function RoofGarden.start(boxes: { BasePart }, remotes, hooks)
	local allow = RateLimit.new(0.25)
	-- 화단 하나에 화분 두 칸씩 (왼쪽·오른쪽)
	local slots = {}
	for _, box in boxes do
		for _, dx in { -1.2, 1.2 } do
			local top = box.Position + Vector3.new(dx, box.Size.Y / 2, 0)
			table.insert(slots, { top.X, top.Y, top.Z })
			if #slots >= SalaryConfig.GARDEN_SLOTS then
				break
			end
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "텃밭 돌보기"
		prompt.ObjectText = "🌱 내 화분"
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.Parent = box
		prompt.Triggered:Connect(function(player)
			remotes.GardenOpen:FireClient(player)
		end)
	end
	ReplicatedStorage:SetAttribute("GardenSlots", HttpService:JSONEncode(slots))

	local function near(player: Player): boolean
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return false
		end
		for _, box in boxes do
			if (root.Position - box.Position).Magnitude < 12 then
				return true
			end
		end
		return false
	end

	remotes.GardenAction.OnServerInvoke = function(player: Player, action: any, slotIndex: any, seedId: any)
		if not allow(player) then
			return { ok = false, message = "천천히!" }
		end
		if not near(player) then
			return { ok = false, message = "🌱 옥상 화단 앞에서 해 주세요!" }
		end
		if typeof(action) ~= "string" or typeof(slotIndex) ~= "number" then
			return { ok = false, message = "잘못된 요청이에요." }
		end
		local ok, message = hooks.action(player, action, slotIndex, seedId)
		return { ok = ok, message = message }
	end
end

return RoofGarden
