-- 🍪 탕비실 간식 테이블
-- 매일 아침 과자를 테이블 위에 다시 놓아요. 플레이어가 [E] 가져가기를 하면 테이블에서 사라져요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)

local Snacks = {}

-- onTake(player, snack): 가져갈 수 있으면 true를 돌려줘요 (Employees가 판단)
function Snacks.start(office, onTake: (Player, SalaryConfig.SnackInfo) -> boolean)
	local folder = Instance.new("Folder")
	folder.Name = "Snacks"
	folder.Parent = office.folder

	local function placeSnack(snack: SalaryConfig.SnackInfo, spot: Vector3)
		local part = Instance.new("Part")
		part.Name = snack.id
		part.Anchored = true
		part.CanCollide = false
		part.Size = snack.size
		part.Color = snack.color
		part.Material = Enum.Material.SmoothPlastic
		part.CFrame = CFrame.new(spot + Vector3.new(0, snack.size.Y / 2, 0)) * CFrame.Angles(0, math.rad(math.random(0, 359)), 0)

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.StudsOffset = Vector3.new(0, 1, 0)
		billboard.MaxDistance = 30
		billboard.Parent = part
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Text = snack.emoji
		label.Parent = billboard

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "가져가기"
		prompt.ObjectText = `{snack.emoji} {snack.name} (+{snack.bonus}원, {snack.seconds}초)`
		prompt.MaxActivationDistance = 6
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
		prompt.Triggered:Connect(function(player)
			if part.Parent and onTake(player, snack) then
				part:Destroy()
			end
		end)

		part.Parent = folder
	end

	local api = {}

	-- 테이블을 다시 채워요 (하루 시작할 때)
	function api.restock()
		folder:ClearAllChildren()
		local index = 0
		for _, snack in SalaryConfig.Snacks do
			for _ = 1, snack.count do
				index += 1
				local spot = office.snackSpots[index]
				if spot then
					placeSnack(snack, spot)
				end
			end
		end
	end

	api.restock()
	return api
end

return Snacks
