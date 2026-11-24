-- 🧊 메시 가구 불러오기
-- Blender로 만든 가구(shared/SalaryMeshData)를 에셋 ID로 불러와 원하는 자리에 놓아요.
-- 메시는 "겉모습"만 맡아요: 충돌·좌석·판정은 빌더가 만드는 보이지 않는 파트가 그대로 해요.
-- 불러오기에 실패하면 ready()가 false라서, 빌더가 예전 파트 가구로 대신 지어요.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage.Shared.SalaryMeshData)
local Theme = require(ReplicatedStorage.Shared.SalaryTheme)

local Meshes = {}

local FLIP = CFrame.Angles(0, math.pi, 0)
local LOAD_TIMEOUT = 10 -- 초. 넘기면 파트 가구로 지어요

-- 나무·금속 색은 재질도 그에 맞게 입혀요 (질감 B안)
local MATERIAL_BY_COLOR: { [string]: Enum.Material } = {
	wood = Enum.Material.Wood,
	woodLight = Enum.Material.Wood,
	woodDark = Enum.Material.Wood,
	metal = Enum.Material.Metal,
	laminate = Enum.Material.Wood,
	wall = Enum.Material.Plaster,
	stone = Enum.Material.Concrete,
}

local templates: { [string]: { [string]: MeshPart } } = {}

export type SpawnOptions = {
	colors: { [string]: Color3 }?, -- 구역 이름 → 색 (없으면 메시 기본색)
	scales: { [string]: Vector3 }?, -- 구역 이름 → 늘리는 비율 (가구 원점 기준)
	skip: { [string]: boolean }?, -- 놓지 않을 구역
	scale: number?, -- 가구 전체를 키우는 비율
	stretch: Vector3?, -- 가구 전체를 축마다 다르게 늘리는 비율 (메시 기준 X·Y·Z)
}

-- 데이터에 있는 모든 가구 종류
-- 지금까지 놓은 가구들 (Solid 모듈이 충돌 상자를 씌울 때 봐요)
Meshes.placed = {} :: { { kind: string, parts: { [string]: MeshPart } } }
Meshes.ALL = {} :: { string }
for kind in Data do
	table.insert(Meshes.ALL, kind)
end

-- 가구 종류들을 미리 불러와요 (기다려요). 한 종류라도 조각이 빠지면 그 종류는 못 쓰는 걸로 쳐요.
function Meshes.preload(kinds: { string })
	local pending = 0
	local loaded: { [string]: { [string]: MeshPart } } = {}
	local failed: { [string]: boolean } = {}
	for _, kind in kinds do
		local data = Data[kind]
		if templates[kind] or not data then
			continue
		end
		loaded[kind] = {}
		for name, info in data.parts do
			pending += 1
			task.spawn(function()
				local ok, result = pcall(function()
					return AssetService:CreateMeshPartAsync(Content.fromUri(info.id), {
						CollisionFidelity = Enum.CollisionFidelity.Box,
						RenderFidelity = Enum.RenderFidelity.Automatic,
					})
				end)
				if ok then
					loaded[kind][name] = result
				else
					failed[kind] = true
					warn(`[Meshes] {kind}_{name} 불러오기 실패: {result}`)
				end
				pending -= 1
			end)
		end
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < LOAD_TIMEOUT do
		task.wait()
	end
	if pending > 0 then
		warn("[Meshes] 메시를 제때 못 불러왔어요 → 파트 가구로 지어요")
		return
	end
	for kind, parts in loaded do
		if not failed[kind] then
			templates[kind] = parts
		end
	end
end

function Meshes.ready(...: string): boolean
	for _, kind in { ... } do
		if not templates[kind] then
			return false
		end
	end
	return true
end

-- origin(월드 CFrame, 가구의 바닥 가운데)에 가구를 놓고 { 구역 이름 = MeshPart }를 돌려줘요.
function Meshes.spawn(kind: string, parent: Instance, origin: CFrame, options: SpawnOptions?): { [string]: MeshPart }
	local data = Data[kind]
	local template = templates[kind]
	local colors = options and options.colors or {}
	local scales = options and options.scales or {}
	local skip = options and options.skip or {}
	local parts = {}
	for name, info in data.parts do
		if skip[name] then
			continue
		end
		local scale = (scales[name] or Vector3.one) * (if options and options.scale then options.scale else 1) * (if options and options.stretch then options.stretch else Vector3.one)
		local part = template[name]:Clone()
		part.Name = `{kind}_{name}`
		part.Size = info.size * scale
		part.CFrame = origin * CFrame.new(info.center * scale) * (if data.flip then FLIP else CFrame.identity)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		-- 월드용 차분한 색(Theme.Mesh)이 먼저, 없으면 기본 색. 둘 다 없어도 짓다가 멈추지 않게 회색을 써요
		part.Color = colors[name] or (Theme.Mesh :: any)[info.color] or (Theme.Color :: any)[info.color] or Color3.fromRGB(200, 200, 200)
		part.Material = if info.material == "SmoothPlastic" then (MATERIAL_BY_COLOR[info.color] or Enum.Material.SmoothPlastic) else (Enum.Material :: any)[info.material]
		-- 작은 조각(컵·손잡이·버튼…)은 그림자를 드리우지 않아요: 그림자 계산이 메시 수만큼 늘어나는 걸 줄여요
		part.CastShadow = math.max(part.Size.X, part.Size.Y, part.Size.Z) >= 2.5
		if info.material == "Glass" then
			part.Transparency = 0.6 -- (유리 진열장·기계 창: 안이 비쳐 보여요)
			part.CastShadow = false
		end
		part.Parent = parent
		parts[name] = part
	end
	table.insert(Meshes.placed, { kind = kind, parts = parts })
	return parts
end

-- 빌더 좌표(position)에 yaw(도)만큼 돌려서 놓아요. 메시의 앞은 +Z예요.
function Meshes.place(B: any, kind: string, position: Vector3, yaw: number?, options: SpawnOptions?): { [string]: MeshPart }
	return Meshes.spawn(kind, B.parent, B:cf(CFrame.new(position) * CFrame.Angles(0, math.rad(yaw or 0), 0)), options)
end

-- build()가 만드는 예전 파트 가구를 메시로 덮어요: 파트는 안 보이게만 하고(충돌·판정은 그대로) 그 자리에 메시를 놓아요.
-- 메시를 못 불러왔으면 build()만 실행해서 예전 모습 그대로예요.
function Meshes.over(B: any, kind: string, position: Vector3, yaw: number?, options: SpawnOptions?, build: () -> ())
	if not Meshes.ready(kind) then
		build()
		return nil
	end
	local before = #B.parent:GetChildren()
	build()
	local children = B.parent:GetChildren()
	for i = before + 1, #children do
		local child = children[i]
		if child:IsA("BasePart") then
			child.Transparency = 1
		end
	end
	return Meshes.place(B, kind, position, yaw, options)
end

-- 보이지 않는 판정 파트(source)의 색·재질이 바뀌면 메시(target)에도 그대로 입혀요.
-- (🪑 내 자리 꾸미기처럼 예전 파트를 칠하던 코드가 그대로 동작해요)
function Meshes.mirror(source: BasePart, target: BasePart)
	for _, property in { "Color", "Material" } do
		source:GetPropertyChangedSignal(property):Connect(function()
			(target :: any)[property] = (source :: any)[property]
		end)
	end
end

return Meshes
