-- 🧱 가구는 통과도, 올라타기도 안 되게
--   1) 통과 막기: 충돌 상자 없이 놓인 메시 가구(장식 의자·화분·진열대…)에 보이지 않는 충돌 상자를 씌워요
--   2) 올라타기 막기: 낮은 가구(윗면이 바닥에서 0.9~8.5칸) 위에 보이지 않는 벽을 올려서 점프로 못 올라가게 해요
--   모두 "플레이어만" 막아요 (부장님·동료·경비원·공 같은 물건은 그대로 지나가요: 길 찾기가 달라지지 않게).
--   부장님 시선(광선)과 카메라도 이 상자들은 무시해요 (CanQuery 꺼짐).
--
--   예외 (올라가도 되는 곳): 의자(Seat), 넓은 바닥·무대·다리(넓이 150칸² 초과), 기울어진 판(계단·경사로),
--   Walk 속성을 붙인 파트, 그리고 앉은 사람과 겹칠 자리(의자 바로 위).
--   통과 예외: 벽·천장에 다는 것, 문, 정자, 디딤돌, 꽃밭처럼 원래 지나다니는 것 (NO_BOX).

local PhysicsService = game:GetService("PhysicsService")
local Meshes = require(script.Parent.Meshes)
require(script.Parent.Npc) -- (충돌 그룹 이름을 먼저 만들어 둬요)

local Solid = {}

local GROUP = "SalaryPlayerBlock"
pcall(function()
	PhysicsService:RegisterCollisionGroup(GROUP)
end)
for _, other in { "Default", "SalaryNpc", "SalaryNpcBlock", GROUP } do
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(GROUP, other, false)
	end)
end
pcall(function()
	PhysicsService:CollisionGroupSetCollidable(GROUP, "SalaryCharacter", true)
end)

local JUMP_TOP = 11.5 -- 바닥에서 이 높이까지 막아요 (점프로 닿는 높이보다 위. 의자에 앉았다가 뛰면 의자 높이만큼 더 올라가서, 9.5일 땐 투명 막이 "위에" 올라설 수 있었어요)
local LOW, HIGH = 0.9, 8.5 -- 윗면이 이 사이인 가구가 "올라탈 수 있는 것"
local MAX_AREA = 150 -- 이보다 넓으면 바닥·무대·다리로 쳐요
local CELL = 24

-- 충돌 상자를 씌우지 않는 메시 종류 (벽·천장·문·원래 지나다니는 것·다른 가구 위에 올려 둔 것)
local NO_BOX = {}
for _, kind in {
	"PendantLamp", "MenuBoard", "WallShelf", "NeonSign", "ShopAwning", "BladeSign", "WheelFrame", "CeilingLight", "CeilingTile", "FloorTile",
	"WallPanel", "WindowPanel", "NoticeBoard", "DoorFrame", "ShopDoor", "ElevatorDoor", "Pergola", "Stone", "FlowerBed",
	"ExecPanel", "ExecRug", "ExecPicture", "ExecShelf", -- 👔 임원실: 벽 패널·러그·액자·선반
	"Monitor", "RMonitor", "Lamp", "EspressoMachine", "PastryCase", "CakeStand",
} do
	NO_BOX[kind] = true
end
-- 기둥만 막는 종류 (잎·차양 밑은 지나다녀요): 종류 → 기둥 굵기
local POLE = { Tree = 1.6, Parasol = 1.0, LampPost = 1.0 }

type Box = { min: Vector3, max: Vector3 }

-- 파트의 월드 축 기준 상자. 비스듬히 놓인 파트는 nil
local function boxOf(part: BasePart): Box?
	local cf, half = part.CFrame, part.Size / 2
	local right, up, back = cf.RightVector, cf.UpVector, cf.LookVector
	for _, axis in { right, up, back } do
		if math.max(math.abs(axis.X), math.abs(axis.Y), math.abs(axis.Z)) < 0.995 then
			return nil
		end
	end
	local extent = Vector3.new(
		math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(back.X) * half.Z,
		math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(back.Y) * half.Z,
		math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(back.Z) * half.Z
	)
	return { min = cf.Position - extent, max = cf.Position + extent }
end

-- 돌려 놓은 메시도 넉넉히 감싸는 상자
local function looseBox(part: BasePart): Box
	local cf, half = part.CFrame, part.Size / 2
	local right, up, back = cf.RightVector, cf.UpVector, cf.LookVector
	local extent = Vector3.new(
		math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(back.X) * half.Z,
		math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(back.Y) * half.Z,
		math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(back.Z) * half.Z
	)
	return { min = cf.Position - extent, max = cf.Position + extent }
end

local function overlaps(a: Box, b: Box): boolean
	return a.min.X < b.max.X and a.max.X > b.min.X and a.min.Y < b.max.Y and a.max.Y > b.min.Y and a.min.Z < b.max.Z and a.max.Z > b.min.Z
end

function Solid.apply(folder: Instance, floorLevels: { number })
	local holder = Instance.new("Folder")
	holder.Name = "SolidBoxes"
	holder.Parent = folder

	-- 이 높이 바로 아래의 바닥 (사무실·단지 1, 옥상 300)
	local function floorUnder(y: number): number
		local best = floorLevels[1]
		for _, level in floorLevels do
			if level <= y + 2 and level > best then
				best = level
			end
		end
		return best
	end
	local function block(min: Vector3, max: Vector3, name: string)
		local size = max - min
		if size.X < 0.2 or size.Y < 0.2 or size.Z < 0.2 then
			return
		end
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.Transparency = 1
		part.CanCollide = true
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.CollisionGroup = GROUP
		part.Size = size
		part.CFrame = CFrame.new((min + max) / 2)
		part.Parent = holder
	end

	-- 지금 있는 충돌 파트와 의자를 칸(grid)에 모아 둬요
	local grid: { [string]: { { box: Box, seat: boolean } } } = {}
	local function cellsOf(box: Box): { string }
		local keys = {}
		for cx = math.floor(box.min.X / CELL), math.floor(box.max.X / CELL) do
			for cz = math.floor(box.min.Z / CELL), math.floor(box.max.Z / CELL) do
				table.insert(keys, `{cx}:{cz}`)
			end
		end
		return keys
	end
	local parts: { BasePart } = {}
	for _, item in folder:GetDescendants() do
		if not item:IsA("BasePart") or not item.Anchored or item:IsDescendantOf(holder) or item.Name == "NpcGuard" then
			continue
		end
		local seat = item:IsA("Seat") or item:IsA("VehicleSeat")
		if not seat and (not item.CanCollide or item:IsA("MeshPart")) then
			continue
		end
		local box = looseBox(item)
		local size = box.max - box.min
		if not seat then
			table.insert(parts, item)
			if size.X * size.Z > 400 then
				continue -- (바닥·큰 벽은 "가구가 이미 막혀 있나" 판단에서 빼요)
			end
		end
		local entry = { box = box, seat = seat }
		for _, key in cellsOf(box) do
			grid[key] = grid[key] or {}
			table.insert(grid[key], entry)
		end
	end
	local function touching(box: Box, seatsOnly: boolean): boolean
		for _, key in cellsOf(box) do
			for _, entry in grid[key] or {} do
				if (entry.seat or not seatsOnly) and overlaps(box, entry.box) then
					return true
				end
			end
		end
		return false
	end

	-- 1) 통과되는 메시 가구에 충돌 상자
	local boxed = 0
	for _, record in Meshes.placed do
		if NO_BOX[record.kind] then
			continue
		end
		local min: Vector3? = nil
		local max: Vector3? = nil
		for _, piece in record.parts do
			if piece.Parent and piece:IsDescendantOf(folder) then
				local box = looseBox(piece)
				min = if min then min:Min(box.min) else box.min
				max = if max then max:Max(box.max) else box.max
			end
		end
		if not min or not max then
			continue
		end
		local floor = floorUnder(min.Y)
		if min.Y - floor > 1.5 or max.Y - min.Y < 0.9 then
			continue -- (다른 가구 위·벽에 올려 둔 것, 납작한 것)
		end
		local center = (min + max) / 2
		local pole = POLE[record.kind]
		if pole then
			min = Vector3.new(center.X - pole / 2, min.Y, center.Z - pole / 2)
			max = Vector3.new(center.X + pole / 2, max.Y, center.Z + pole / 2)
		end
		-- 가운데 60%에 이미 충돌 파트나 의자가 있으면 손으로 만든 상자가 있는 가구예요
		local half = (max - min) / 2
		local probe = { min = Vector3.new(center.X - half.X * 0.6, min.Y + 0.3, center.Z - half.Z * 0.6), max = Vector3.new(center.X + half.X * 0.6, max.Y, center.Z + half.Z * 0.6) }
		if touching(probe, false) then
			continue
		end
		local inset = if pole then 0 else 0.92
		local lo = Vector3.new(center.X - half.X * (if pole then 1 else inset), min.Y, center.Z - half.Z * (if pole then 1 else inset))
		local hi = Vector3.new(center.X + half.X * (if pole then 1 else inset), math.max(max.Y, floor + JUMP_TOP), center.Z + half.Z * (if pole then 1 else inset))
		block(lo, hi, "SolidBox")
		boxed += 1
	end

	-- 2) 낮은 가구 위로 못 올라가게
	local capped = 0
	for _, part in parts do
		if part:GetAttribute("Walk") then
			continue
		end
		local box = boxOf(part)
		if not box then
			continue -- (계단·경사로처럼 기울어진 판)
		end
		local size = box.max - box.min
		if size.X * size.Z > MAX_AREA then
			continue
		end
		local floor = floorUnder(box.min.Y)
		local top = box.max.Y - floor
		if top < LOW or top > HIGH then
			continue
		end
		local lo = Vector3.new(box.min.X + 0.15, box.max.Y, box.min.Z + 0.15)
		local hi = Vector3.new(box.max.X - 0.15, floor + JUMP_TOP, box.max.Z - 0.15)
		if hi.X - lo.X < 0.2 or hi.Z - lo.Z < 0.2 then
			continue
		end
		if touching({ min = lo, max = hi }, true) then
			continue -- (의자 바로 위: 앉은 사람과 겹치면 안 돼요)
		end
		block(lo, hi, "SolidCap")
		capped += 1
	end
	return boxed, capped
end

return Solid
