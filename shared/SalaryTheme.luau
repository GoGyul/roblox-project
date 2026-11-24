-- 월급루팡 전용 비주얼 토큰.
-- UI와 월드가 같은 색을 쓰도록 한 곳에서 관리해요.

local Theme = {}

Theme.Color = {
	cream = Color3.fromRGB(250, 248, 241),
	surface = Color3.fromRGB(255, 255, 252),
	surfaceSoft = Color3.fromRGB(240, 247, 246),
	navy = Color3.fromRGB(34, 53, 76),
	navySoft = Color3.fromRGB(63, 82, 105),
	muted = Color3.fromRGB(105, 120, 139),
	mint = Color3.fromRGB(105, 215, 181),
	mintDark = Color3.fromRGB(42, 142, 125),
	mintSoft = Color3.fromRGB(204, 241, 228),
	sky = Color3.fromRGB(99, 184, 231),
	skySoft = Color3.fromRGB(213, 238, 250),
	coral = Color3.fromRGB(247, 112, 111),
	coralSoft = Color3.fromRGB(255, 218, 213),
	yellow = Color3.fromRGB(250, 193, 70),
	yellowSoft = Color3.fromRGB(255, 238, 184),
	wood = Color3.fromRGB(218, 184, 142),
	woodLight = Color3.fromRGB(239, 218, 185),
	grass = Color3.fromRGB(100, 177, 110),
	line = Color3.fromRGB(181, 210, 218),
	-- 메시 가구용 (tools/blender/lib.py 의 PALETTE 와 같아요)
	sage = Color3.fromRGB(168, 213, 191),
	woodDark = Color3.fromRGB(150, 112, 78),
	grassLight = Color3.fromRGB(140, 205, 130),
	metal = Color3.fromRGB(201, 211, 218),
	stone = Color3.fromRGB(233, 226, 214),
	water = Color3.fromRGB(140, 212, 245),
}

-- 🧊 월드(메시·사무실)용 차분한 색 (질감 B안). UI 색(Theme.Color)은 그대로 두고, 월드만 톤을 낮춰요.
-- 같은 이름이 여기 있으면 메시는 이 색을 써요.
Theme.Mesh = {
	cream = Color3.fromRGB(232, 229, 221),
	surface = Color3.fromRGB(232, 230, 225),
	surfaceSoft = Color3.fromRGB(214, 220, 222),
	navy = Color3.fromRGB(48, 50, 55),
	navySoft = Color3.fromRGB(74, 78, 86),
	mint = Color3.fromRGB(122, 160, 148),
	mintDark = Color3.fromRGB(70, 110, 102),
	mintSoft = Color3.fromRGB(188, 204, 198),
	sage = Color3.fromRGB(142, 156, 150),
	sky = Color3.fromRGB(128, 160, 186),
	skySoft = Color3.fromRGB(190, 206, 218),
	coral = Color3.fromRGB(190, 110, 98),
	coralSoft = Color3.fromRGB(216, 190, 182),
	yellow = Color3.fromRGB(206, 170, 92),
	yellowSoft = Color3.fromRGB(255, 236, 200),
	wood = Color3.fromRGB(176, 142, 104),
	woodLight = Color3.fromRGB(203, 172, 132),
	woodDark = Color3.fromRGB(120, 92, 66),
	grass = Color3.fromRGB(74, 128, 84),
	grassLight = Color3.fromRGB(104, 152, 100),
	line = Color3.fromRGB(168, 176, 182),
	metal = Color3.fromRGB(176, 180, 184),
	stone = Color3.fromRGB(206, 202, 194),
	water = Color3.fromRGB(128, 184, 214),
	-- 사무실 바탕
	carpet = Color3.fromRGB(150, 156, 162),
	carpetDark = Color3.fromRGB(134, 140, 147),
	wall = Color3.fromRGB(232, 230, 225),
	seat = Color3.fromRGB(84, 92, 104),
	screen = Color3.fromRGB(170, 200, 225),
	laminate = Color3.fromRGB(214, 204, 190),
	paper = Color3.fromRGB(244, 243, 238),
}

Theme.UI = {
	panel = Theme.Color.surface,
	panelAlt = Theme.Color.surfaceSoft,
	paper = Theme.Color.cream,
	ink = Theme.Color.navy,
	brass = Theme.Color.yellow,
	text = Theme.Color.navy,
	muted = Theme.Color.muted,
	accent = Theme.Color.mint,
	accentDark = Theme.Color.mintDark,
	bad = Theme.Color.coral,
	line = Theme.Color.line,
}

Theme.corner = 16

return Theme
