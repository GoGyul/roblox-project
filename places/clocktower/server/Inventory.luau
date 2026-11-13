-- 플레이어 소지품 관리
-- 플레이어 밑의 "Inventory" 폴더에 StringValue로 저장하면 클라이언트에도 자동으로 보여요.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Inventory = {}

local function getFolder(player: Player): Folder
	local folder = player:FindFirstChild("Inventory")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Inventory"
		folder.Parent = player
	end
	return folder :: Folder
end

function Inventory.setup(player: Player)
	getFolder(player)
end

function Inventory.has(player: Player, itemId: string): boolean
	return getFolder(player):FindFirstChild(itemId) ~= nil
end

function Inventory.give(player: Player, itemId: string)
	local folder = getFolder(player)
	if folder:FindFirstChild(itemId) then
		return
	end
	local item = Instance.new("StringValue")
	item.Name = itemId
	item.Value = Config.Items[itemId] or itemId
	item.Parent = folder
end

function Inventory.take(player: Player, itemId: string): boolean
	local item = getFolder(player):FindFirstChild(itemId)
	if item then
		item:Destroy()
		return true
	end
	return false
end

return Inventory
