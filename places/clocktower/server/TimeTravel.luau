-- 시간 전환: 회중시계를 가진 플레이어가 [T]를 누르면
-- 같은 자리의 다른 시대 탑으로 순간이동해요. (시대는 플레이어마다 따로예요)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(script.Parent.Inventory)
local Remotes = require(script.Parent.Remotes)

local TimeTravel = {}

function TimeTravel.start(towerFolder: Folder)
	local lastSwitch: { [Player]: number } = {}

	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { towerFolder }
	overlap.RespectCanCollide = true

	Remotes.ToggleEra.OnServerEvent:Connect(function(player: Player)
		if not Inventory.has(player, "watch") then
			return
		end
		local now = os.clock()
		if lastSwitch[player] and now - lastSwitch[player] < Config.TOGGLE_COOLDOWN then
			return
		end

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (character and root and humanoid) or humanoid.Health <= 0 then
			return
		end

		local current = player:GetAttribute("Era") or "present"
		local target = if current == "present" then "past" else "present"
		local delta = if target == "past" then Config.ERA_OFFSET else -Config.ERA_OFFSET

		-- 도착할 자리가 벽이나 물건으로 막혀 있으면 이동하지 않아요
		local blockers = workspace:GetPartBoundsInBox(root.CFrame + delta, Vector3.new(2, 4, 2), overlap)
		if #blockers > 0 then
			Remotes.Notify:FireClient(player, "그 시대의 이 자리는 무언가로 막혀 있다. 조금 옮겨서 다시 시도해 보자.")
			return
		end

		lastSwitch[player] = now
		character:PivotTo(character:GetPivot() + delta)
		player:SetAttribute("Era", target)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastSwitch[player] = nil
	end)
end

return TimeTravel
