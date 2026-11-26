-- 🪑 내 자리 꾸미기 + 🏆 칭호
--   [🪑] 버튼 → 온라인 주문 → 다음 근무일에 택배로 도착! 칸(의자·모니터·액자·책상 색·소품)마다 하나씩 장착해요.
--   꾸민 책상은 다른 사람 눈에도 보이고, 책상 명패에 이름·칭호·인테리어 점수가 떠요.
--   남의 책상 명패에서 [E] 자리 구경 → 그 사람의 인테리어와 칭호를 볼 수 있어요.
--   🏆 칭호는 업적으로 열리고 머리 위에 떠요. (내 것은 내 화면에서는 직급 창에 보여요)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SalaryConfig = require(ReplicatedStorage.Shared.SalaryConfig)
local RateLimit = require(ReplicatedStorage.Shared.RateLimit)

local Decor = {}

local allowAction = RateLimit.new(0.3)

local GOLD = Color3.fromRGB(225, 185, 60)

-- 칸별로 지금 장착한 아이템 (없으면 기본)
local function equipped(profile, slotId: string): string
	local id = profile.decorEquipped[slotId]
	if id then
		return id
	end
	for _, slot in SalaryConfig.DecorSlots do
		if slot.id == slotId then
			return slot.options[1].id
		end
	end
	return ""
end

local function decorScore(profile): number
	local total = 0
	for _, slot in SalaryConfig.DecorSlots do
		local option = SalaryConfig.getDecor(equipped(profile, slot.id))
		if option then
			total += option.price
		end
	end
	return math.floor(total / 1000)
end

local function titleText(profile): string
	local title = SalaryConfig.getTitle(profile.title) or SalaryConfig.Titles[1]
	return title.text
end

local function titleUnlocked(profile, title): boolean
	return title.achievement == nil or profile.collection[title.achievement] == true
end

---------------------------------------------------------------------------
-- 책상 위에 꾸미기 만들기
---------------------------------------------------------------------------
local function part(folder: Instance, size: Vector3, cframe: CFrame, color: Color3, props: { [string]: any }?): BasePart
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props or {} do
		(p :: any)[key] = value
	end
	p.Parent = folder
	return p
end

local function label(target: BasePart, face: Enum.NormalId, text: string, color: Color3?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0.2
	gui.Parent = target
	local text_ = Instance.new("TextLabel")
	text_.Size = UDim2.fromScale(1, 1)
	text_.BackgroundTransparency = 1
	text_.TextScaled = true
	text_.TextWrapped = true
	text_.Font = Enum.Font.GothamBold
	text_.TextColor3 = color or Color3.fromRGB(40, 30, 30)
	text_.Text = text
	text_.Parent = gui
	return text_
end

local PHOTO_TEXT = {
	photo_passion = "🔥\n열정!",
	photo_goal = "🏃\n목표: 칼퇴",
	photo_cat = "🐱\n냥",
	photo_idol = "⭐\n최애",
	photo_art = "🖼️\n모나리자(?)",
}
local DESK_COLORS = {
	desk_white = { Color3.fromRGB(240, 240, 238), Enum.Material.SmoothPlastic },
	desk_black = { Color3.fromRGB(35, 35, 40), Enum.Material.SmoothPlastic },
	desk_pink = { Color3.fromRGB(255, 185, 205), Enum.Material.SmoothPlastic },
	desk_gold = { GOLD, Enum.Material.Metal },
}

local function buildDecor(player: Player, d)
	local desk = d.desk
	local profile = d.profile
	local old = desk.model:FindFirstChild("Decor")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = desk.model

	local top: BasePart = desk.top
	local surface = top.Position + Vector3.new(0, top.Size.Y / 2, 0) -- 책상 윗면 가운데
	local back: BasePart = desk.chairBack
	local seat: Seat = desk.seat

	-- 🎨 책상 색
	local deskColor = DESK_COLORS[equipped(profile, "desk")]
	top.Color = if deskColor then deskColor[1] else desk.base.deskColor
	top.Material = if deskColor then deskColor[2] else desk.base.deskMaterial

	-- 🪑 의자
	local chair = equipped(profile, "chair")
	local backCF = back.CFrame
	if chair == "chair_gaming" then
		seat.Color, back.Color = Color3.fromRGB(200, 30, 40), Color3.fromRGB(30, 30, 35)
		part(folder, Vector3.new(1.4, 0.7, 0.35), backCF * CFrame.new(0, 1.55, 0), Color3.fromRGB(200, 30, 40)) -- 머리 받침
		for _, dx in { -1.05, 1.05 } do
			part(folder, Vector3.new(0.3, 2.4, 0.6), backCF * CFrame.new(dx, 0, -0.15), Color3.fromRGB(200, 30, 40)) -- 날개
		end
	elseif chair == "chair_massage" then
		seat.Color, back.Color = Color3.fromRGB(110, 70, 45), Color3.fromRGB(110, 70, 45)
		seat.Material, back.Material = Enum.Material.Leather, Enum.Material.Leather
		for _, dx in { -1.25, 1.25 } do
			part(folder, Vector3.new(0.5, 0.9, 2), seat.CFrame * CFrame.new(dx, 0.6, 0), Color3.fromRGB(90, 55, 35), { Material = Enum.Material.Leather })
		end
		part(folder, Vector3.new(1.6, 0.8, 0.5), backCF * CFrame.new(0, 1.5, -0.1), Color3.fromRGB(130, 85, 55), { Material = Enum.Material.Leather })
	elseif chair == "chair_throne" then
		seat.Color, back.Color = GOLD, GOLD
		seat.Material, back.Material = Enum.Material.Metal, Enum.Material.Metal
		part(folder, Vector3.new(2.4, 3.2, 0.4), backCF * CFrame.new(0, 1.9, 0.05), GOLD, { Material = Enum.Material.Metal }) -- 높은 등받이
		part(folder, Vector3.new(1.8, 2.6, 0.1), backCF * CFrame.new(0, 1.9, -0.17), Color3.fromRGB(170, 20, 40), { Material = Enum.Material.Fabric }) -- 빨간 벨벳
		for _, dx in { -0.7, 0, 0.7 } do
			part(folder, Vector3.new(0.3, 0.6, 0.3), backCF * CFrame.new(dx, 3.8, 0.05), GOLD, { Material = Enum.Material.Metal }) -- 왕관 뿔
		end
		part(folder, Vector3.new(0.35, 0.35, 0.35), backCF * CFrame.new(0, 3.75, -0.15), Color3.fromRGB(220, 30, 50), { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon })
		for _, dx in { -1.25, 1.25 } do
			part(folder, Vector3.new(0.4, 1, 2), seat.CFrame * CFrame.new(dx, 0.6, 0), GOLD, { Material = Enum.Material.Metal })
		end
	else
		seat.Color, back.Color = desk.base.chairColor, desk.base.chairColor
		seat.Material, back.Material = Enum.Material.SmoothPlastic, Enum.Material.SmoothPlastic
	end

	-- 🖥️ 모니터
	local monitor = equipped(profile, "monitor")
	local monitorCF: CFrame = desk.monitor.CFrame
	local screenColor = Color3.fromRGB(90, 150, 220)
	if monitor == "monitor_dual" then
		local second = monitorCF * CFrame.new(2.4, 0, 0.45) * CFrame.Angles(0, math.rad(-25), 0)
		part(folder, Vector3.new(2.4, 1.7, 0.3), second, Color3.fromRGB(25, 25, 30))
		part(folder, Vector3.new(2.1, 1.4, 0.05), second * CFrame.new(0, 0, 0.18), Color3.fromRGB(120, 200, 140), { Material = Enum.Material.Neon, Transparency = 0.2 })
	elseif monitor == "monitor_wide" then
		for _, side in { -1, 1 } do
			local wing = monitorCF * CFrame.new(side * 1.85, 0, 0.3) * CFrame.Angles(0, math.rad(-side * 22), 0)
			part(folder, Vector3.new(1.2, 1.8, 0.3), wing, Color3.fromRGB(25, 25, 30))
			part(folder, Vector3.new(1.05, 1.5, 0.05), wing * CFrame.new(0, 0, 0.18), screenColor, { Material = Enum.Material.Neon, Transparency = 0.2 })
		end
	elseif monitor == "monitor_rgb" then
		local rainbow = { Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 210, 60), Color3.fromRGB(80, 220, 120), Color3.fromRGB(80, 140, 255) }
		local bars = {
			{ Vector3.new(2.8, 0.15, 0.35), CFrame.new(0, 0.97, 0) },
			{ Vector3.new(2.8, 0.15, 0.35), CFrame.new(0, -0.97, 0) },
			{ Vector3.new(0.15, 2.1, 0.35), CFrame.new(-1.38, 0, 0) },
			{ Vector3.new(0.15, 2.1, 0.35), CFrame.new(1.38, 0, 0) },
		}
		for i, bar in bars do
			part(folder, bar[1], monitorCF * bar[2], rainbow[i], { Material = Enum.Material.Neon })
		end
	end

	-- 🖼️ 액자 (책상 왼쪽 뒤)
	local photo = PHOTO_TEXT[equipped(profile, "photo")]
	if photo then
		local frame = part(folder, Vector3.new(1.3, 1.3, 0.12), CFrame.new(surface + Vector3.new(-3.4, 0.75, -1.5)) * CFrame.Angles(math.rad(-10), 0, 0), Color3.fromRGB(120, 80, 50), { Material = Enum.Material.Wood })
		local canvas = part(folder, Vector3.new(1.1, 1.1, 0.02), frame.CFrame * CFrame.new(0, 0, 0.07), Color3.fromRGB(250, 245, 235))
		label(canvas, Enum.NormalId.Back, photo)
	end

	-- 💡 소품 (책상 오른쪽 뒤)
	local gadget = equipped(profile, "gadget")
	local spot = surface + Vector3.new(3.4, 0, -1.4)
	if gadget == "gadget_cactus" then
		part(folder, Vector3.new(0.6, 0.5, 0.6), CFrame.new(spot + Vector3.new(0, 0.25, 0)), Color3.fromRGB(200, 120, 70))
		part(folder, Vector3.new(0.35, 0.9, 0.35), CFrame.new(spot + Vector3.new(0, 0.9, 0)), Color3.fromRGB(70, 150, 70), { Material = Enum.Material.Grass })
		part(folder, Vector3.new(0.4, 0.15, 0.15), CFrame.new(spot + Vector3.new(0.25, 1, 0)), Color3.fromRGB(70, 150, 70))
	elseif gadget == "gadget_figure" then
		part(folder, Vector3.new(0.7, 0.12, 0.7), CFrame.new(spot + Vector3.new(0, 0.06, 0)), Color3.fromRGB(40, 40, 45))
		part(folder, Vector3.new(0.45, 0.6, 0.3), CFrame.new(spot + Vector3.new(0, 0.45, 0)), Color3.fromRGB(40, 90, 200))
		part(folder, Vector3.new(0.35, 0.35, 0.35), CFrame.new(spot + Vector3.new(0, 0.95, 0)), Color3.fromRGB(240, 200, 160))
		part(folder, Vector3.new(0.5, 0.55, 0.05), CFrame.new(spot + Vector3.new(0, 0.5, 0.2)), Color3.fromRGB(210, 40, 40)) -- 망토
	elseif gadget == "gadget_lamp" then
		part(folder, Vector3.new(0.5, 0.15, 0.5), CFrame.new(spot + Vector3.new(0, 0.08, 0)), Color3.fromRGB(60, 50, 40))
		local bulb = part(folder, Vector3.new(0.7, 0.7, 0.7), CFrame.new(spot + Vector3.new(0, 0.5, 0)), Color3.fromRGB(255, 200, 120), { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon })
		local light = Instance.new("PointLight")
		light.Range = 9
		light.Brightness = 1.2
		light.Color = Color3.fromRGB(255, 190, 120)
		light.Parent = bulb
	elseif gadget == "gadget_fish" then
		part(folder, Vector3.new(1, 0.8, 0.7), CFrame.new(spot + Vector3.new(0, 0.4, 0)), Color3.fromRGB(150, 210, 240), { Material = Enum.Material.Glass, Transparency = 0.5 })
		part(folder, Vector3.new(0.3, 0.18, 0.1), CFrame.new(spot + Vector3.new(0.1, 0.45, 0)), Color3.fromRGB(255, 140, 40)) -- 금붕어 '월급이'
		part(folder, Vector3.new(0.95, 0.1, 0.65), CFrame.new(spot + Vector3.new(0, 0.12, 0)), Color3.fromRGB(230, 210, 160)) -- 모래
	end

	-- 🏷️ 책상 명패 (앞쪽 가장자리, 지나가는 사람이 봐요)
	local plate = part(folder, Vector3.new(2.6, 0.75, 0.15), CFrame.new(surface + Vector3.new(0, 0.38, 1.85)), Color3.fromRGB(30, 30, 40), { Name = "Nameplate" })
	label(plate, Enum.NormalId.Back, `⭐ {player.DisplayName}\n{titleText(profile)} · 🪑 {decorScore(profile)}점`, Color3.fromRGB(255, 225, 130))
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "자리 구경"
	prompt.ObjectText = `👀 {player.DisplayName} 님 자리`
	prompt.MaxActivationDistance = 4.5 -- 명패 바로 앞에서만 (지나가다 계속 뜨지 않게)
	prompt.HoldDuration = 0.4
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerId", player.UserId) -- (넣기 전에 표시해야 화면이 알아봐요)
	prompt.Parent = plate
end

---------------------------------------------------------------------------
-- 머리 위 칭호
---------------------------------------------------------------------------
local function updateTitleTag(player: Player, profile)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head then
		return
	end
	local tag = head:FindFirstChild("TitleTag") :: BillboardGui?
	if not tag then
		local newTag = Instance.new("BillboardGui")
		newTag.Name = "TitleTag"
		newTag.Size = UDim2.fromOffset(220, 26)
		newTag.StudsOffset = Vector3.new(0, 3.1, 0)
		newTag.MaxDistance = 60
		newTag.PlayerToHideFrom = player -- 내 칭호는 내 화면 머리 위에는 안 떠요 (직급 창에 보여요). 다른 사람에게는 그대로 보여요
		newTag.Parent = head
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.TextScaled = true
		text.Font = Enum.Font.GothamBold
		text.TextColor3 = Color3.fromRGB(255, 220, 120)
		text.TextStrokeTransparency = 0.3
		text.Parent = newTag
		tag = newTag
	end
	((tag :: BillboardGui):FindFirstChild("Text") :: TextLabel).Text = titleText(profile)
end

---------------------------------------------------------------------------
-- api: Employees.decorApi (get, list, charge, unlock, save)
function Decor.start(remotes, api)
	local function publish(player: Player, d)
		local profile = d.profile
		player:SetAttribute("DecorOwned", HttpService:JSONEncode(profile.decorOwned))
		player:SetAttribute("DecorEquipped", HttpService:JSONEncode(profile.decorEquipped))
		player:SetAttribute("Title", profile.title)
		player:SetAttribute("TitleText", titleText(profile))
		player:SetAttribute("DecorScore", decorScore(profile))
	end

	local function refresh(player: Player, d)
		buildDecor(player, d)
		updateTitleTag(player, d.profile)
		publish(player, d)
	end

	local function onJoin(player: Player, d)
		if not SalaryConfig.getTitle(d.profile.title) then
			d.profile.title = "newbie"
		end
		refresh(player, d)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 5)
			local current = api.get(player)
			if current then
				updateTitleTag(player, current.profile)
			end
		end)
	end

	api.hooks.joined = onJoin
	api.hooks.left = function(_player: Player, d)
		local folder = d.desk.model:FindFirstChild("Decor")
		if folder then
			folder:Destroy()
		end
		-- 다음 사람을 위해 기본 모습으로
		d.desk.top.Color, d.desk.top.Material = d.desk.base.deskColor, d.desk.base.deskMaterial
		d.desk.seat.Color, d.desk.chairBack.Color = d.desk.base.chairColor, d.desk.base.chairColor
		d.desk.seat.Material, d.desk.chairBack.Material = Enum.Material.SmoothPlastic, Enum.Material.SmoothPlastic
	end
	api.hooks.collectionChanged = function(player: Player, d)
		publish(player, d) -- 새 업적 → 새 칭호가 열렸을 수 있어요
	end
	for player, d in api.list() do
		onJoin(player, d) -- 이미 들어와 있던 사람
	end

	-- 📦 택배를 뜯으면: 내 물건이 되고 바로 장착해요 → 화면에 보여 줄 이름
	api.grantDecor = function(player: Player, d, id: string): string?
		local option, slot = SalaryConfig.getDecor(id)
		if not option or not slot then
			return nil
		end
		local profile = d.profile
		profile.decorOwned[id] = true
		profile.decorEquipped[slot.id] = id
		api.unlock(player, d, "interior_first")
		if id == "chair_throne" then
			api.unlock(player, d, "throne")
		end
		if decorScore(profile) >= SalaryConfig.INTERIOR_MASTER_SCORE then
			api.unlock(player, d, "interior_master")
		end
		refresh(player, d)
		return `{option.emoji} {option.name}`
	end

	remotes.Decor.OnServerInvoke = function(player: Player, action: any, id: any)
		if not allowAction(player) then
			return { ok = false, message = "천천히 눌러 주세요." }
		end
		local d = api.get(player)
		if not d or typeof(id) ~= "string" then
			return { ok = false, message = "잘못된 요청이에요." }
		end
		local profile = d.profile
		if action == "buy" or action == "equip" then
			local option, slot = SalaryConfig.getDecor(id)
			if not option or not slot then
				return { ok = false, message = "없는 물건이에요." }
			end
			local owned = option.price == 0 or profile.decorOwned[id] == true
			if action == "buy" and not owned then
				-- 🛒 꾸미기 물건은 인터넷 쇼핑(농땡이) 중에만 주문 → 🚚 다음 근무일에 📦 택배 보관함으로 와요
				if api.ordered(d, "decor", id) then
					return { ok = false, message = "🚚 이미 주문했어요! (📦 택배 보관함을 확인해요)" }
				end
				if d.state ~= "shopping" then
					return { ok = false, message = "🛒 [온라인 쇼핑] 농땡이 중에만 주문할 수 있어요! 내 자리에서 쇼핑을 켜 봐요" }
				end
				local ok, message = api.placeOrder(player, d, "decor", id, option.price, `{option.emoji} {option.name}`)
				return { ok = ok, message = message }
			end
			if not owned then
				return { ok = false, message = "먼저 사야 해요." }
			end
			profile.decorEquipped[slot.id] = id
			if decorScore(profile) >= SalaryConfig.INTERIOR_MASTER_SCORE then
				api.unlock(player, d, "interior_master")
			end
			refresh(player, d)
			api.save(player, d)
			return { ok = true, message = `{option.emoji} {option.name} 장착!` }
		elseif action == "title" then
			local title = SalaryConfig.getTitle(id)
			if not title or not titleUnlocked(profile, title) then
				return { ok = false, message = "🔒 아직 잠긴 칭호예요." }
			end
			profile.title = id
			refresh(player, d)
			api.save(player, d)
			return { ok = true, message = `🏆 칭호 장착: {title.text}` }
		end
		return { ok = false, message = "잘못된 요청이에요." }
	end
end

return Decor
