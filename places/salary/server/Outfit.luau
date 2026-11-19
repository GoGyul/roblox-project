-- 👔 출근룩: 캐릭터에 안경·넥타이·모자·헤드폰·시계·가방·오라를 직접 붙여요 (모두에게 보여요)
--   산 옷(outfitOwned)과 칸별로 입은 옷(outfitEquipped)은 저장돼요

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)

local Outfit = {}

-- 기본 R15 크기 (아바타 크기가 달라도 비율에 맞춰 붙여요)
local DEFAULT_SIZE = {
	Head = Vector3.new(1.2, 1.2, 1.2),
	UpperTorso = Vector3.new(2, 1.6, 1),
}

-- 캐릭터에 입히기 (기존 출근룩은 벗기고 새로)
function Outfit.apply(character: Model, equipped: { [string]: string })
	local old = character:FindFirstChild("SalaryOutfit")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "SalaryOutfit"
	folder.Parent = character
	for _, itemId in equipped do
		local option = SalaryConfig.getOutfit(itemId)
		local target = option and character:FindFirstChild(option.part) :: BasePart?
		if not option or not target or not target:IsA("BasePart") then
			continue
		end
		local base = DEFAULT_SIZE[option.part]
		local scale = if base then math.clamp(target.Size.X / base.X, 0.6, 2) else 1
		for _, piece in option.pieces do
			local p = Instance.new("Part")
			p.Name = itemId
			p.Size = piece.size * scale
			p.Shape = piece.shape or Enum.PartType.Block
			p.Color = piece.color
			p.Material = piece.material or Enum.Material.SmoothPlastic
			p.Transparency = piece.transparency or 0
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			p.CastShadow = false
			p.CFrame = target.CFrame * CFrame.new(piece.offset.Position * scale) * piece.offset.Rotation
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = target
			weld.Part1 = p
			weld.Parent = p
			p.Parent = folder
		end
		-- ✨ 오라: 반짝이 입자 + 은은한 빛
		if option.particles then
			local attachment = Instance.new("Attachment")
			attachment.Name = "OutfitAura"
			attachment.Parent = target
			local emitter = Instance.new("ParticleEmitter")
			emitter.Rate = 7
			emitter.Lifetime = NumberRange.new(0.8, 1.4)
			emitter.Speed = NumberRange.new(0.8, 1.8)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.28), NumberSequenceKeypoint.new(1, 0) })
			emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
			emitter.LightEmission = 1
			emitter.Color = if option.rainbow
				then ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 110, 110)),
					ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 100)),
					ColorSequenceKeypoint.new(0.66, Color3.fromRGB(110, 220, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 120, 255)),
				})
				else ColorSequence.new(option.particles)
			emitter.Parent = attachment
			if option.light then
				local light = Instance.new("PointLight")
				light.Color = option.light
				light.Range = 7
				light.Brightness = 0.8
				light.Parent = attachment
			end
			-- (벗을 때 같이 지워지도록 표시)
			attachment:SetAttribute("OutfitPart", true)
		end
	end
end

local function clearAuras(character: Model)
	for _, item in character:GetDescendants() do
		if item:IsA("Attachment") and item:GetAttribute("OutfitPart") then
			item:Destroy()
		end
	end
end

-- api: Employees.decorApi (get · charge · unlock · save · hooks)
function Outfit.start(remotes, api)
	local allow = RateLimit.new(0.25)

	local function publish(player: Player, profile)
		player:SetAttribute("OutfitOwned", HttpService:JSONEncode(profile.outfitOwned))
		player:SetAttribute("OutfitEquipped", HttpService:JSONEncode(profile.outfitEquipped))
	end
	local function dress(player: Player, profile)
		local character = player.Character
		if character and character:FindFirstChild("Head") then
			clearAuras(character)
			Outfit.apply(character, profile.outfitEquipped)
		end
	end

	-- 들어올 때 / 캐릭터가 새로 생길 때마다 입혀요 (자리 꾸미기의 joined 뒤에 이어서)
	local function onJoin(player: Player, d)
		-- 없어진 옷 ID는 정리
		for slotId, itemId in d.profile.outfitEquipped do
			if not SalaryConfig.getOutfit(itemId) or not d.profile.outfitOwned[itemId] then
				d.profile.outfitEquipped[slotId] = nil
			end
		end
		publish(player, d.profile)
		dress(player, d.profile)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 5)
			character:WaitForChild("UpperTorso", 5)
			local current = api.get(player)
			if current then
				dress(player, current.profile)
			end
		end)
	end
	local previousJoined = api.hooks.joined
	api.hooks.joined = function(player: Player, d)
		if previousJoined then
			previousJoined(player, d)
		end
		onJoin(player, d)
	end
	for player, d in api.list() do
		onJoin(player, d) -- 이미 들어와 있던 사람 (저장소가 없을 때처럼 먼저 들어온 경우)
	end

	remotes.OutfitAction.OnServerInvoke = function(player: Player, action: any, value: any)
		if not allow(player) then
			return { ok = false, message = "천천히!" }
		end
		local d = api.get(player)
		if not d then
			return { ok = false, message = "잠시 후 다시 해 주세요." }
		end
		local profile = d.profile
		if action == "buy" then
			local option, slot = SalaryConfig.getOutfit(if typeof(value) == "string" then value else "")
			if not option then
				return { ok = false, message = "없는 옷이에요." }
			end
			if profile.outfitOwned[option.id] then
				return { ok = false, message = "이미 가지고 있어요." }
			end
			local paid, message = api.charge(player, option.price)
			if not paid then
				return { ok = false, message = message }
			end
			profile.outfitOwned[option.id] = true
			profile.outfitEquipped[slot.id] = option.id -- 사자마자 입어요
			api.unlock(player, d, "outfit_first")
			if option.id == "hat_crown" then
				api.unlock(player, d, "outfit_crown")
			end
			local full = true
			for _, s in SalaryConfig.OutfitSlots do
				if not profile.outfitEquipped[s.id] then
					full = false
				end
			end
			if full then
				api.unlock(player, d, "outfit_full")
			end
			if option.price >= 80000 then
				for _, other in Players:GetPlayers() do
					remotes.Notify:FireClient(other, `👔 {player.DisplayName} 님이 {option.emoji} {option.name}을(를) 질렀어요!`)
				end
			end
			publish(player, profile)
			dress(player, profile)
			api.save(player, d)
			return { ok = true, message = `🛍️ {option.emoji} {option.name} 구매 완료! 바로 입었어요` }
		elseif action == "equip" then
			local option, slot = SalaryConfig.getOutfit(if typeof(value) == "string" then value else "")
			if not option or not profile.outfitOwned[option.id] then
				return { ok = false, message = "먼저 사야 해요." }
			end
			profile.outfitEquipped[slot.id] = option.id
			if option.id == "hat_crown" then
				api.unlock(player, d, "outfit_crown")
			end
			local full = true
			for _, s in SalaryConfig.OutfitSlots do
				if not profile.outfitEquipped[s.id] then
					full = false
				end
			end
			if full then
				api.unlock(player, d, "outfit_full")
			end
			publish(player, profile)
			dress(player, profile)
			api.save(player, d)
			return { ok = true, message = `👔 {option.emoji} {option.name} 착용!` }
		elseif action == "unequip" then
			if typeof(value) ~= "string" then
				return { ok = false, message = "잘못된 요청이에요." }
			end
			profile.outfitEquipped[value] = nil
			publish(player, profile)
			dress(player, profile)
			api.save(player, d)
			return { ok = true, message = "벗었어요." }
		end
		return { ok = false, message = "잘못된 요청이에요." }
	end
end

return Outfit
