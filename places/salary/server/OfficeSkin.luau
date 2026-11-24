-- 🧊 사무실 겉면을 메시 키트로 입혀요 (벽 패널·카펫 타일·천장 타일).
-- 벽·바닥·천장 파트는 그대로 남아 충돌을 맡고, 그 위(안쪽 면)에 메시를 덧대요.
-- 벽은 Build:wall이 붙여 둔 "Wall" 속성으로 찾아요. 그래서 방 칸막이 벽까지 자동으로 입혀져요.

local Meshes = require(script.Parent.Meshes)

local OfficeSkin = {}

local FLOOR_Y = 1 -- 바닥 윗면 (OfficeBuilder와 같아요)
local PANEL_DEPTH = 0.25 -- 벽 패널 두께 비율 (0.5칸 → 0.125칸: 벽에 붙은 간판·시계가 묻히지 않게 얇게)

-- 회사별 바닥·천장 구역: { x1, x2, z1, z2, 천장 높이 }
local AREAS = {
	daechung = {
		{ -61, 61, -38.5, 43.5, 20 }, -- 사무실 층 (리뉴얼 평면, 1.25배. 남쪽은 복도를 넓히며 5칸 늘었어요)
		{ 18, 77, 43.5, 88.5, 20 }, -- 🏋️ 체력 단련실
	},
	nunchi = {
		{ -73, 73, -43, 43, 14 },
		{ -52, 12, 43, 91.5, 14 },
	},
}

local function tiles(kind: string, folder: Instance, area: { number }, y: number)
	local x1, x2, z1, z2 = area[1], area[2], area[3], area[4]
	local nx = math.max(1, math.ceil((x2 - x1) / 16))
	local nz = math.max(1, math.ceil((z2 - z1) / 16))
	local w, d = (x2 - x1) / nx, (z2 - z1) / nz
	for ix = 1, nx do
		for iz = 1, nz do
			Meshes.spawn(kind, folder, CFrame.new(x1 + (ix - 0.5) * w, y, z1 + (iz - 0.5) * d), { stretch = Vector3.new(w / 8, 1, d / 8) })
		end
	end
end

local function walls(folder: Instance, inside: (Vector3) -> boolean)
	local list = {}
	for _, part in folder:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("Wall") and part.Transparency < 0.05 then
			table.insert(list, part)
		end
	end
	for _, part in list do
		local size, position = part.Size, part.Position
		local alongX = size.X >= size.Z
		local length = if alongX then size.X else size.Z
		local thick = if alongX then size.Z else size.X
		local dir = if alongX then Vector3.xAxis else Vector3.zAxis
		local normal = if alongX then Vector3.zAxis else Vector3.xAxis
		local bottom = position.Y - size.Y / 2
		local grounded = size.Y > 6 and bottom < FLOOR_Y + 0.5 -- 문 위 조각에는 걸레받이·몰딩을 안 달아요
		local count = math.max(1, math.ceil(length / 8))
		local width = length / count
		for _, side in { 1, -1 } do
			local out = normal * side
			if inside(position + out * (thick / 2 + 1)) then
				for i = 1, count do
					local center = position + dir * (-length / 2 + (i - 0.5) * width) + out * (thick / 2 + PANEL_DEPTH / 4)
					local origin = CFrame.fromMatrix(Vector3.new(center.X, bottom, center.Z), Vector3.yAxis:Cross(out), Vector3.yAxis, out)
					Meshes.spawn("WallPanel", folder, origin, {
						stretch = Vector3.new(width / 8, 1, PANEL_DEPTH),
						scales = { Wall = Vector3.new(1, size.Y / 12, 1) }, -- 벽 면만 높이에 맞춰 늘리고 걸레받이·몰딩 높이는 그대로
						skip = if grounded then nil else { Base = true, Rail = true },
						colors = { Wall = part.Color },
					})
				end
			end
		end
	end
end

function OfficeSkin.apply(office)
	local areas = AREAS[office.companyId]
	if not areas or not Meshes.ready("WallPanel", "FloorTile", "CeilingTile") then
		return
	end
	local skin = Instance.new("Folder")
	skin.Name = "Skin"
	skin.Parent = office.folder
	walls(office.folder, office.insideOffice)
	for _, area in areas do
		tiles("FloorTile", skin, area, FLOOR_Y)
		tiles("CeilingTile", skin, area, FLOOR_Y + area[5])
	end
end

return OfficeSkin
