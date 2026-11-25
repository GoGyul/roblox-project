-- 자동 생성 파일이에요: python3 tools/make_mesh_data.py (직접 고치지 마세요)
-- 가구 → 색 구역별 메시 (크기·중심은 가구 원점(바닥 가운데) 기준, 스터드)

return {
	Bookshelf = {
		flip = true,
		parts = {
			Body = { id = "rbxassetid://79433440166429", size = Vector3.new(5.2, 8.5, 1.6), center = Vector3.new(0, 4.25, -0), color = "woodLight", material = "SmoothPlastic" },
			Niche = { id = "rbxassetid://121507585459741", size = Vector3.new(4.2, 4.6, 0.2), center = Vector3.new(0, 5.6, 0.75), color = "cream", material = "SmoothPlastic" },
			Shelf = { id = "rbxassetid://120826770087828", size = Vector3.new(4.2, 2.1, 0.9), center = Vector3.new(0, 4.25, 0.6), color = "wood", material = "SmoothPlastic" },
			Bookcoral = { id = "rbxassetid://112982582205860", size = Vector3.new(0.38, 1.5, 0.7), center = Vector3.new(-1.4, 6.05, 0.7), color = "coral", material = "SmoothPlastic" },
			Booksky = { id = "rbxassetid://102475952851111", size = Vector3.new(0.38, 1.8, 0.7), center = Vector3.new(-0.95, 6.2, 0.7), color = "sky", material = "SmoothPlastic" },
			Bookyellow = { id = "rbxassetid://80728412537117", size = Vector3.new(0.38, 1.4, 0.7), center = Vector3.new(-0.5, 6, 0.7), color = "yellow", material = "SmoothPlastic" },
			Bookmint = { id = "rbxassetid://89885785239221", size = Vector3.new(0.38, 1.7, 0.7), center = Vector3.new(-0.05, 6.15, 0.7), color = "mint", material = "SmoothPlastic" },
			Box = { id = "rbxassetid://77313299734366", size = Vector3.new(1.3, 0.9, 0.8), center = Vector3.new(1.1, 5.75, 0.7), color = "coralSoft", material = "SmoothPlastic" },
			Doors = { id = "rbxassetid://96052350305701", size = Vector3.new(4.05, 2.7, 0.16), center = Vector3.new(0, 1.6, 0.82), color = "surface", material = "SmoothPlastic" },
			Handles = { id = "rbxassetid://86891090336998", size = Vector3.new(0.74, 0.8, 0.14), center = Vector3.new(0, 1.7, 0.95), color = "wood", material = "SmoothPlastic" },
		},
	},
	Sofa = {
		flip = true,
		parts = {
			Base = { id = "rbxassetid://87512974748852", size = Vector3.new(6, 1, 2.6), center = Vector3.new(0, 0.75, -0), color = "surface", material = "SmoothPlastic" },
			Cushion = { id = "rbxassetid://93079811674582", size = Vector3.new(6, 1.9, 2.6), center = Vector3.new(0, 2.1, -0.1), color = "mint", material = "Fabric" },
			Pillow = { id = "rbxassetid://118669197049582", size = Vector3.new(1.1, 0.982, 0.628), center = Vector3.new(1.8, 2.3, -0.3), color = "yellow", material = "Fabric" },
		},
	},
	RoundTable = {
		flip = true,
		parts = {
			Top = { id = "rbxassetid://106482270629821", size = Vector3.new(3, 0.22, 3), center = Vector3.new(0, 1.3, -0), color = "woodLight", material = "SmoothPlastic" },
			Leg = { id = "rbxassetid://87644295226282", size = Vector3.new(1.6, 1.2, 1.6), center = Vector3.new(0, 0.6, -0), color = "surface", material = "SmoothPlastic" },
		},
	},
	Vending = {
		flip = true,
		parts = {
			Body = { id = "rbxassetid://99904468976160", size = Vector3.new(3, 6.2, 2.4), center = Vector3.new(0, 3.1, -0), color = "mint", material = "SmoothPlastic" },
			Window = { id = "rbxassetid://74380073006542", size = Vector3.new(1.9, 3.6, 0.12), center = Vector3.new(-0.3, 3.9, 1.2), color = "surfaceSoft", material = "SmoothPlastic" },
			Itemscoral = { id = "rbxassetid://102152131944032", size = Vector3.new(1.6, 2.6, 0.12), center = Vector3.new(-0.3, 4, 1.26), color = "coral", material = "SmoothPlastic" },
			Itemsyellow = { id = "rbxassetid://71883894717321", size = Vector3.new(1.6, 2.6, 0.12), center = Vector3.new(-0.3, 4, 1.26), color = "yellow", material = "SmoothPlastic" },
			Itemssky = { id = "rbxassetid://117595868887237", size = Vector3.new(1.6, 2.6, 0.12), center = Vector3.new(-0.3, 4, 1.26), color = "sky", material = "SmoothPlastic" },
			Panel = { id = "rbxassetid://131626271519109", size = Vector3.new(2.65, 4.6, 0.12), center = Vector3.new(0.025, 3, 1.22), color = "mintDark", material = "SmoothPlastic" },
		},
	},
	Printer = {
		flip = true,
		parts = {
			Body = { id = "rbxassetid://131458672933932", size = Vector3.new(3.1, 3.25, 2.5), center = Vector3.new(0, 1.925, -0), color = "surface", material = "SmoothPlastic" },
			Tray = { id = "rbxassetid://133703825393397", size = Vector3.new(2.4, 1.875, 1.2), center = Vector3.new(0, 1.888, 1.4), color = "line", material = "SmoothPlastic" },
			Eyes = { id = "rbxassetid://101861688501348", size = Vector3.new(1.28, 0.28, 0.28), center = Vector3.new(0, 1.9, 1.2), color = "navy", material = "SmoothPlastic" },
			Wheels = { id = "rbxassetid://92476524722434", size = Vector3.new(2.6, 0.4, 2.2), center = Vector3.new(0, 0.2, -0), color = "navy", material = "SmoothPlastic" },
		},
	},
	Reception = {
		flip = true,
		parts = {
			Body = { id = "rbxassetid://137381240138188", size = Vector3.new(6.4, 2.5, 6.4), center = Vector3.new(0, 1.35, -0), color = "woodLight", material = "SmoothPlastic" },
			Top = { id = "rbxassetid://79705389297897", size = Vector3.new(6.8, 0.25, 6.8), center = Vector3.new(0, 2.72, -0), color = "surface", material = "SmoothPlastic" },
			Glow = { id = "rbxassetid://90346281008809", size = Vector3.new(6.5, 0.2, 6.5), center = Vector3.new(0, 0.1, -0), color = "yellowSoft", material = "Neon" },
		},
	},
	Planter = {
		flip = true,
		parts = {
			Box = { id = "rbxassetid://98170620713777", size = Vector3.new(6, 1.3, 1.8), center = Vector3.new(0, 0.65, -0), color = "stone", material = "SmoothPlastic" },
			Leaves = { id = "rbxassetid://113204980003857", size = Vector3.new(5.666, 1.2, 1.331), center = Vector3.new(0, 1.5, 0), color = "grass", material = "SmoothPlastic" },
			Flowercoral = { id = "rbxassetid://123496192554049", size = Vector3.new(4.78, 0.42, 0.399), center = Vector3.new(-0.3, 2.1, -0.2), color = "coral", material = "SmoothPlastic" },
			Floweryellow = { id = "rbxassetid://75042351187993", size = Vector3.new(4.78, 0.42, 0.399), center = Vector3.new(0.3, 2.1, 0.3), color = "yellow", material = "SmoothPlastic" },
		},
	},
	Tree = {
		flip = true,
		parts = {
			Trunk = { id = "rbxassetid://109537783110733", size = Vector3.new(0.951, 3.4, 1), center = Vector3.new(0, 1.7, -0), color = "woodDark", material = "SmoothPlastic" },
			Canopy = { id = "rbxassetid://88500439436152", size = Vector3.new(5.78, 5.3, 4.945), center = Vector3.new(-0.538, 5.35, -0), color = "grass", material = "SmoothPlastic" },
			CanopyLight = { id = "rbxassetid://125659367289914", size = Vector3.new(4.421, 5.75, 4.181), center = Vector3.new(1.018, 5.775, -0.121), color = "grassLight", material = "SmoothPlastic" },
		},
	},
	Bush = {
		flip = true,
		parts = {
			Leaves = { id = "rbxassetid://140345932326089", size = Vector3.new(2.909, 1.8, 2.107), center = Vector3.new(0.369, 0.8, 0.007), color = "grass", material = "SmoothPlastic" },
		},
	},
	Bench = {
		flip = true,
		parts = {
			Seat = { id = "rbxassetid://89265213268657", size = Vector3.new(4.2, 0.22, 1.6), center = Vector3.new(0, 1.35, 0.05), color = "woodLight", material = "SmoothPlastic" },
			Back = { id = "rbxassetid://104725604129800", size = Vector3.new(4.2, 1.05, 0.247), center = Vector3.new(0, 2.2, -0.85), color = "wood", material = "SmoothPlastic" },
			Legs = { id = "rbxassetid://87551079428552", size = Vector3.new(3.7, 1.3, 1.8), center = Vector3.new(0, 0.65, -0), color = "navySoft", material = "SmoothPlastic" },
		},
	},
	Fountain = {
		flip = true,
		parts = {
			Stone = { id = "rbxassetid://80892443308123", size = Vector3.new(7.6, 3.2, 7.6), center = Vector3.new(0, 1.6, -0), color = "stone", material = "SmoothPlastic" },
			Water = { id = "rbxassetid://137963976771803", size = Vector3.new(6.3, 2.5, 6.3), center = Vector3.new(0, 1.95, -0), color = "water", material = "SmoothPlastic" },
			Jets = { id = "rbxassetid://107050503840483", size = Vector3.new(4.916, 3.558, 4.297), center = Vector3.new(0, 2.921, -0), color = "skySoft", material = "SmoothPlastic" },
		},
	},
	Stall = {
		flip = true,
		parts = {
			Counter = { id = "rbxassetid://117167169884559", size = Vector3.new(6, 2.4, 1.8), center = Vector3.new(0, 1.2, -0), color = "woodLight", material = "SmoothPlastic" },
			Top = { id = "rbxassetid://89622932327602", size = Vector3.new(6.4, 0.25, 2.2), center = Vector3.new(0, 2.5, -0), color = "wood", material = "SmoothPlastic" },
			Posts = { id = "rbxassetid://135869490077292", size = Vector3.new(6.1, 6, 2), center = Vector3.new(0, 3, -0), color = "wood", material = "SmoothPlastic" },
			Awning = { id = "rbxassetid://122545190090498", size = Vector3.new(6.65, 1.494, 3.409), center = Vector3.new(0, 5.847, 0.345), color = "coral", material = "SmoothPlastic" },
			AwningWhite = { id = "rbxassetid://129386148203558", size = Vector3.new(4.75, 1.494, 3.409), center = Vector3.new(0, 5.847, 0.345), color = "surface", material = "SmoothPlastic" },
			Goods = { id = "rbxassetid://85973056940605", size = Vector3.new(1.4, 0.7, 0.6), center = Vector3.new(-1.4, 3, 0.2), color = "mint", material = "SmoothPlastic" },
			Machine = { id = "rbxassetid://130628765686445", size = Vector3.new(1.4, 1.2, 1.1), center = Vector3.new(1.5, 3.2, -0), color = "navySoft", material = "SmoothPlastic" },
			Stools = { id = "rbxassetid://99972306610746", size = Vector3.new(4.7, 0.3, 1.1), center = Vector3.new(0, 1.5, 1.9), color = "yellow", material = "SmoothPlastic" },
			StoolLegs = { id = "rbxassetid://125899622129927", size = Vector3.new(3.84, 1.4, 0.24), center = Vector3.new(0, 0.7, 1.9), color = "surface", material = "SmoothPlastic" },
		},
	},
	Pergola = {
		flip = true,
		parts = {
			Deck = { id = "rbxassetid://101641925196364", size = Vector3.new(9.6, 0.4, 7.6), center = Vector3.new(0, 0.2, -0), color = "wood", material = "SmoothPlastic" },
			Frame = { id = "rbxassetid://140178390041451", size = Vector3.new(9.6, 7.2, 7.6), center = Vector3.new(0, 3.9, -0), color = "navySoft", material = "SmoothPlastic" },
			Canopy = { id = "rbxassetid://102624927956627", size = Vector3.new(8.8, 0.4, 6.4), center = Vector3.new(0, 7.325, -0), color = "cream", material = "SmoothPlastic" },
			Lights = { id = "rbxassetid://89804617747462", size = Vector3.new(8.15, 0.85, 0.35), center = Vector3.new(0, 6.5, 3.4), color = "yellowSoft", material = "Neon" },
		},
	},
	PodChair = {
		flip = true,
		parts = {
			Shell = { id = "rbxassetid://90345571696415", size = Vector3.new(4.2, 4.2, 3.566), center = Vector3.new(0, 2.3, -0.317), color = "cream", material = "SmoothPlastic" },
			Cushion = { id = "rbxassetid://131648602471149", size = Vector3.new(2.9, 2.3, 2.8), center = Vector3.new(0, 1.9, 0.1), color = "yellow", material = "SmoothPlastic" },
		},
	},
	LampPost = {
		flip = true,
		parts = {
			Pole = { id = "rbxassetid://94492393957381", size = Vector3.new(1, 5.4, 1), center = Vector3.new(0, 2.7, -0), color = "navySoft", material = "SmoothPlastic" },
			Bulb = { id = "rbxassetid://111188518893645", size = Vector3.new(1.1, 1.1, 1.1), center = Vector3.new(0, 5.8, -0), color = "yellowSoft", material = "Neon" },
		},
	},
	Parasol = {
		flip = true,
		parts = {
			Table = { id = "rbxassetid://113745257206857", size = Vector3.new(3, 0.2, 3), center = Vector3.new(0, 2.2, -0), color = "surface", material = "SmoothPlastic" },
			Pole = { id = "rbxassetid://117773132926132", size = Vector3.new(1.4, 6.6, 1.4), center = Vector3.new(0, 3.3, -0), color = "navySoft", material = "SmoothPlastic" },
			Shade = { id = "rbxassetid://119366246334599", size = Vector3.new(6.6, 1.3, 6.6), center = Vector3.new(0, 6.35, -0), color = "yellow", material = "SmoothPlastic" },
			Stools = { id = "rbxassetid://87381183734845", size = Vector3.new(5.178, 1.3, 4.784), center = Vector3.new(-0.091, 0.65, -0.493), color = "coral", material = "SmoothPlastic" },
		},
	},
	FlowerBed = {
		flip = true,
		parts = {
			Soil = { id = "rbxassetid://74859694684749", size = Vector3.new(7, 0.7, 4.5), center = Vector3.new(0, 0.05, -0), color = "woodDark", material = "SmoothPlastic" },
			Leaves = { id = "rbxassetid://137201742219314", size = Vector3.new(5.636, 0.9, 3.945), center = Vector3.new(0, 0.6, -0), color = "grass", material = "SmoothPlastic" },
			Flowercoral = { id = "rbxassetid://90621233671867", size = Vector3.new(5.152, 0.5, 2.688), center = Vector3.new(-0.042, 1.1, 0.374), color = "coral", material = "SmoothPlastic" },
			Floweryellow = { id = "rbxassetid://134528773333674", size = Vector3.new(2.537, 0.5, 3.491), center = Vector3.new(-0.101, 1.1, 0.027), color = "yellow", material = "SmoothPlastic" },
			Flowersurface = { id = "rbxassetid://81256030681374", size = Vector3.new(5.152, 0.5, 2.742), center = Vector3.new(0.042, 1.1, -0.401), color = "surface", material = "SmoothPlastic" },
		},
	},
	Sunbed = {
		flip = true,
		parts = {
			Frame = { id = "rbxassetid://127727017164560", size = Vector3.new(2.6, 1.05, 6.4), center = Vector3.new(0, 0.525, -0), color = "woodLight", material = "SmoothPlastic" },
			Mattress = { id = "rbxassetid://73572696100000", size = Vector3.new(2.3, 1.423, 6.202), center = Vector3.new(0, 1.737, -0.001), color = "surface", material = "SmoothPlastic" },
			Pillow = { id = "rbxassetid://137649394501622", size = Vector3.new(1.5, 0.602, 0.767), center = Vector3.new(0, 2.45, -2.75), color = "sky", material = "SmoothPlastic" },
		},
	},
	Stone = {
		flip = true,
		parts = {
			Stone = { id = "rbxassetid://109924473737474", size = Vector3.new(1.9, 0.3, 1.5), center = Vector3.new(0, 0.08, -0), color = "stone", material = "SmoothPlastic" },
		},
	},
	WallPanel = {
		flip = true,
		parts = {
			Wall = { id = "rbxassetid://128448924736836", size = Vector3.new(8, 12, 0.5), center = Vector3.new(0, 6, -0), color = "wall", material = "SmoothPlastic" },
			Base = { id = "rbxassetid://109159165491900", size = Vector3.new(8, 0.7, 0.64), center = Vector3.new(0, 0.35, -0), color = "navySoft", material = "SmoothPlastic" },
			Rail = { id = "rbxassetid://138427747988466", size = Vector3.new(8, 8.6, 0.6), center = Vector3.new(0, 7.7, -0), color = "woodLight", material = "SmoothPlastic" },
		},
	},
	WindowPanel = {
		flip = true,
		parts = {
			Wall = { id = "rbxassetid://118051135033730", size = Vector3.new(8, 12, 0.5), center = Vector3.new(0, 6, -0), color = "wall", material = "SmoothPlastic" },
			Base = { id = "rbxassetid://137310473021188", size = Vector3.new(8, 0.7, 0.64), center = Vector3.new(0, 0.35, -0), color = "navySoft", material = "SmoothPlastic" },
			Frame = { id = "rbxassetid://133219468893747", size = Vector3.new(7, 7, 0.3), center = Vector3.new(0, 6.5, -0), color = "metal", material = "SmoothPlastic" },
			Glass = { id = "rbxassetid://108545796255886", size = Vector3.new(6.8, 6.8, 0.08), center = Vector3.new(0, 6.5, -0.05), color = "skySoft", material = "SmoothPlastic" },
			Blinds = { id = "rbxassetid://126818138110918", size = Vector3.new(6.6, 2.173, 0.285), center = Vector3.new(0, 8.71, 0.22), color = "cream", material = "SmoothPlastic" },
			Sill = { id = "rbxassetid://117435271299823", size = Vector3.new(7.4, 0.16, 0.9), center = Vector3.new(0, 3.02, 0.25), color = "woodLight", material = "SmoothPlastic" },
		},
	},
	Pillar = {
		flip = true,
		parts = {
			Wall = { id = "rbxassetid://133129203978854", size = Vector3.new(1.4, 12, 1), center = Vector3.new(0, 6, -0), color = "wall", material = "SmoothPlastic" },
			Base = { id = "rbxassetid://86913855746627", size = Vector3.new(1.52, 0.7, 1.12), center = Vector3.new(0, 0.35, -0), color = "navySoft", material = "SmoothPlastic" },
		},
	},
	FloorTile = {
		flip = true,
		parts = {
			TileA = { id = "rbxassetid://132630958425624", size = Vector3.new(7.96, 0.1, 7.96), center = Vector3.new(0, 0, -0), color = "carpet", material = "Carpet" },
			TileB = { id = "rbxassetid://79821794780371", size = Vector3.new(7.96, 0.1, 7.96), center = Vector3.new(0, 0, -0), color = "carpetDark", material = "Carpet" },
		},
	},
	CeilingTile = {
		flip = true,
		parts = {
			Tile = { id = "rbxassetid://101731811090308", size = Vector3.new(7.9, 0.16, 7.9), center = Vector3.new(0, -0.1, -0), color = "surface", material = "SmoothPlastic" },
			Grid = { id = "rbxassetid://74280464079125", size = Vector3.new(8.07, 0.08, 8.07), center = Vector3.new(-0.035, -0.2, -0.035), color = "metal", material = "SmoothPlastic" },
		},
	},
	CeilingLight = {
		flip = true,
		parts = {
			Tile = { id = "rbxassetid://90209921981080", size = Vector3.new(7.9, 0.16, 7.9), center = Vector3.new(0, -0.1, -0), color = "surface", material = "SmoothPlastic" },
			Grid = { id = "rbxassetid://119239316315331", size = Vector3.new(8.07, 0.08, 8.07), center = Vector3.new(-0.035, -0.2, -0.035), color = "metal", material = "SmoothPlastic" },
			Panel = { id = "rbxassetid://131069176490440", size = Vector3.new(1.6, 0.08, 5.6), center = Vector3.new(0, -0.24, -0), color = "yellowSoft", material = "Neon" },
			Housing = { id = "rbxassetid://86072813084693", size = Vector3.new(2, 0.12, 6), center = Vector3.new(0, -0.2, -0), color = "metal", material = "SmoothPlastic" },
		},
	},
	DoorFrame = {
		flip = true,
		parts = {
			Frame = { id = "rbxassetid://86527064799140", size = Vector3.new(7, 9.5, 0.9), center = Vector3.new(0, 4.75, -0), color = "wood", material = "SmoothPlastic" },
		},
	},
	BossDesk = {
		flip = true,
		parts = {
			Top = { id = "rbxassetid://105268629003774", size = Vector3.new(10, 0.3, 4.6), center = Vector3.new(0, 2.75, -0), color = "wood", material = "SmoothPlastic" },
			Body = { id = "rbxassetid://88056944001791", size = Vector3.new(9.6, 2.6, 4), center = Vector3.new(0, 1.3, -0), color = "woodDark", material = "SmoothPlastic" },
			Handles = { id = "rbxassetid://134020705456247", size = Vector3.new(7.9, 1.5, 0.12), center = Vector3.new(0, 1.5, 2.03), color = "metal", material = "SmoothPlastic" },
			Mat = { id = "rbxassetid://117026521252226", size = Vector3.new(3.2, 0.05, 2), center = Vector3.new(0, 2.92, 0.6), color = "navy", material = "SmoothPlastic" },
			Plate = { id = "rbxassetid://80252476796537", size = Vector3.new(1.8, 0.4, 0.3), center = Vector3.new(0, 3.1, -1.7), color = "yellow", material = "SmoothPlastic" },
		},
	},
	Counter = {
		flip = true,
		parts = {
			Body = { id = "rbxassetid://102820628231354", size = Vector3.new(8, 2.8, 2.4), center = Vector3.new(0, 1.4, -0), color = "surface", material = "SmoothPlastic" },
			Top = { id = "rbxassetid://130923751397488", size = Vector3.new(8.2, 0.25, 2.7), center = Vector3.new(0, 2.95, -0), color = "stone", material = "SmoothPlastic" },
			Doors = { id = "rbxassetid://134295998620401", size = Vector3.new(7.8, 2.2, 0.08), center = Vector3.new(0, 1.45, 1.22), color = "cream", material = "SmoothPlastic" },
			Metal = { id = "rbxassetid://99409086024048", size = Vector3.new(6.1, 2.38, 2.34), center = Vector3.new(0.7, 2.79, 0.19), color = "metal", material = "SmoothPlastic" },
		},
	},
	Fridge = {
		flip = true,
		parts = {
			Body = { id = "rbxassetid://130056988440596", size = Vector3.new(3, 7, 2.8), center = Vector3.new(0, 3.5, -0), color = "surface", material = "SmoothPlastic" },
			Line = { id = "rbxassetid://98732008687224", size = Vector3.new(2.9, 0.06, 0.05), center = Vector3.new(0, 4.5, 1.41), color = "line", material = "SmoothPlastic" },
			Handles = { id = "rbxassetid://99588180259417", size = Vector3.new(0.14, 3.8, 0.16), center = Vector3.new(1.1, 4.4, 1.46), color = "metal", material = "SmoothPlastic" },
		},
	},
	DiningTable = {
		flip = true,
		parts = {
			Top = { id = "rbxassetid://92484934374120", size = Vector3.new(6, 0.25, 3.4), center = Vector3.new(0, 2.6, -0), color = "woodLight", material = "SmoothPlastic" },
			Legs = { id = "rbxassetid://138125266701707", size = Vector3.new(5.2, 2.6, 2.8), center = Vector3.new(0, 1.3, -0), color = "metal", material = "SmoothPlastic" },
		},
	},
	DiningChair = {
		flip = true,
		parts = {
			Seat = { id = "rbxassetid://132588087074861", size = Vector3.new(1.7, 2.241, 1.832), center = Vector3.new(0, 2.581, 0.066), color = "seat", material = "Fabric" },
			Legs = { id = "rbxassetid://106847920905816", size = Vector3.new(1.54, 2.489, 1.689), center = Vector3.new(0, 1.225, 0.075), color = "navy", material = "SmoothPlastic" },
		},
	},
	Toilet = {
		flip = true,
		parts = {
			Bowl = { id = "rbxassetid://104023365007598", size = Vector3.new(2.2, 3.4, 2.8), center = Vector3.new(0, 1.7, 0), color = "surface", material = "SmoothPlastic" },
			Lid = { id = "rbxassetid://100378701514569", size = Vector3.new(2.24, 1.91, 2.57), center = Vector3.new(0, 2.555, 0.135), color = "surfaceSoft", material = "SmoothPlastic" },
		},
	},
	Washbasin = {
		flip = true,
		parts = {
			Cabinet = { id = "rbxassetid://122752801464654", size = Vector3.new(3.8, 2.7, 1.8), center = Vector3.new(0, 1.35, -0), color = "surface", material = "SmoothPlastic" },
			Top = { id = "rbxassetid://72853967418667", size = Vector3.new(4, 0.3, 2), center = Vector3.new(0, 2.85, -0), color = "stone", material = "SmoothPlastic" },
			Basin = { id = "rbxassetid://92978506459300", size = Vector3.new(1.7, 0.5, 1.2), center = Vector3.new(0, 3, 0.15), color = "surfaceSoft", material = "SmoothPlastic" },
			Metal = { id = "rbxassetid://137046345462943", size = Vector3.new(3.8, 4.98, 0.909), center = Vector3.new(0, 5.41, -0.526), color = "metal", material = "SmoothPlastic" },
			Mirror = { id = "rbxassetid://106656034544257", size = Vector3.new(3.5, 3.1, 0.06), center = Vector3.new(0, 6.2, -0.85), color = "skySoft", material = "SmoothPlastic" },
		},
	},
	StoreShelf = {
		flip = true,
		parts = {
			Frame = { id = "rbxassetid://106909974310142", size = Vector3.new(6, 6, 1.6), center = Vector3.new(0, 3, -0), color = "surface", material = "SmoothPlastic" },
			Goodscoral = { id = "rbxassetid://115850909950893", size = Vector3.new(5.4, 5.2, 0.7), center = Vector3.new(0, 2.99, 0.2), color = "coral", material = "SmoothPlastic" },
			Goodsyellow = { id = "rbxassetid://87841913206724", size = Vector3.new(5.4, 5.45, 0.7), center = Vector3.new(0, 3.115, 0.2), color = "yellow", material = "SmoothPlastic" },
			Goodssky = { id = "rbxassetid://118466239609526", size = Vector3.new(5.4, 5.2, 0.7), center = Vector3.new(0, 2.99, 0.2), color = "sky", material = "SmoothPlastic" },
			Goodsmint = { id = "rbxassetid://118474693236833", size = Vector3.new(5.4, 5.45, 0.7), center = Vector3.new(0, 3.115, 0.2), color = "mint", material = "SmoothPlastic" },
		},
	},
	StoreCounter = {
		flip = true,
		parts = {
			Body = { id = "rbxassetid://75045737492012", size = Vector3.new(6, 3, 2), center = Vector3.new(0, 1.5, -0), color = "woodLight", material = "SmoothPlastic" },
			Top = { id = "rbxassetid://121206513682504", size = Vector3.new(6.3, 0.25, 2.3), center = Vector3.new(0, 3.1, -0), color = "wood", material = "SmoothPlastic" },
			Register = { id = "rbxassetid://114242310451516", size = Vector3.new(1.5, 1.74, 1.2), center = Vector3.new(1.5, 4.07, -0), color = "navy", material = "SmoothPlastic" },
			Screen = { id = "rbxassetid://128565291873682", size = Vector3.new(1, 0.687, 0.22), center = Vector3.new(1.5, 4.5, -0.22), color = "screen", material = "Neon" },
		},
	},
	Locker = {
		flip = true,
		parts = {
			Body = { id = "rbxassetid://86039538052463", size = Vector3.new(1.6, 6, 1.6), center = Vector3.new(0, 3, -0), color = "sage", material = "SmoothPlastic" },
			Detail = { id = "rbxassetid://106139428676661", size = Vector3.new(1.01, 2.15, 0.12), center = Vector3.new(0.105, 3.975, 0.84), color = "metal", material = "SmoothPlastic" },
		},
	},
	WaterCooler = {
		flip = true,
		parts = {
			Body = { id = "rbxassetid://119525419502702", size = Vector3.new(1.4, 3.6, 1.4), center = Vector3.new(0, 1.8, -0), color = "surface", material = "SmoothPlastic" },
			Bottle = { id = "rbxassetid://118382074713749", size = Vector3.new(1.24, 1.9, 1.221), center = Vector3.new(0, 4.55, -0), color = "sky", material = "SmoothPlastic" },
			Taps = { id = "rbxassetid://81470345928021", size = Vector3.new(0.25, 0.3, 0.25), center = Vector3.new(-0.3, 2.6, 0.78), color = "coral", material = "SmoothPlastic" },
			TapsCold = { id = "rbxassetid://126622958666688", size = Vector3.new(1, 0.7, 0.5), center = Vector3.new(0, 2.4, 0.85), color = "navySoft", material = "SmoothPlastic" },
		},
	},
	Treadmill = {
		flip = true,
		parts = {
			Deck = { id = "rbxassetid://105751997113250", size = Vector3.new(2.7, 4.706, 6.691), center = Vector3.new(0, 2.553, 0.054), color = "navy", material = "SmoothPlastic" },
			Belt = { id = "rbxassetid://139123634104831", size = Vector3.new(2, 0.06, 5.2), center = Vector3.new(0, 0.73, 0.5), color = "navySoft", material = "SmoothPlastic" },
			Frame = { id = "rbxassetid://109506451074220", size = Vector3.new(2.609, 3.716, 1.949), center = Vector3.new(0, 2.45, -2.085), color = "metal", material = "SmoothPlastic" },
			Screen = { id = "rbxassetid://98147938998334", size = Vector3.new(1.6, 0.581, 0.252), center = Vector3.new(0, 4.42, -2.71), color = "screen", material = "Neon" },
		},
	},
	DumbbellRack = {
		flip = true,
		parts = {
			Frame = { id = "rbxassetid://124862586641674", size = Vector3.new(5, 3.2, 1.8), center = Vector3.new(0, 1.6, -0), color = "metal", material = "SmoothPlastic" },
			Bellscoral = { id = "rbxassetid://137829093488182", size = Vector3.new(1.1, 2.16, 1.16), center = Vector3.new(-1.6, 2.15, 0.1), color = "coral", material = "SmoothPlastic" },
			Bellssky = { id = "rbxassetid://131539591960624", size = Vector3.new(1.1, 2.16, 1.16), center = Vector3.new(0, 2.15, 0.1), color = "sky", material = "SmoothPlastic" },
			Bellsyellow = { id = "rbxassetid://119742184604820", size = Vector3.new(1.1, 2.16, 1.16), center = Vector3.new(1.6, 2.15, 0.1), color = "yellow", material = "SmoothPlastic" },
		},
	},
	WeightBench = {
		flip = true,
		parts = {
			Pad = { id = "rbxassetid://95089125990787", size = Vector3.new(1.6, 0.4, 5), center = Vector3.new(0, 1.6, 0.6), color = "seat", material = "Fabric" },
			Frame = { id = "rbxassetid://78463308782809", size = Vector3.new(6.4, 4.4, 4.475), center = Vector3.new(0, 2.2, 0.512), color = "metal", material = "SmoothPlastic" },
			Plates = { id = "rbxassetid://82215440019404", size = Vector3.new(5.9, 1.773, 1.8), center = Vector3.new(0, 4.3, -1.6), color = "navy", material = "SmoothPlastic" },
		},
	},
	ElevatorDoor = {
		flip = true,
		parts = {
			Frame = { id = "rbxassetid://94035604552447", size = Vector3.new(6.2, 8.9, 0.8), center = Vector3.new(0, 4.45, -0), color = "metal", material = "SmoothPlastic" },
			Leaves = { id = "rbxassetid://108990865639634", size = Vector3.new(4.96, 8.3, 0.16), center = Vector3.new(0, 4.15, -0.05), color = "line", material = "Metal" },
			Sign = { id = "rbxassetid://103625697091646", size = Vector3.new(2.2, 0.8, 0.2), center = Vector3.new(0, 9.5, 0.1), color = "navy", material = "SmoothPlastic" },
			Lamp = { id = "rbxassetid://138205070959566", size = Vector3.new(3.85, 5.8, 0.2), center = Vector3.new(1.725, 6.8, 0.22), color = "yellowSoft", material = "Neon" },
		},
	},
	NoticeBoard = {
		flip = true,
		parts = {
			Frame = { id = "rbxassetid://76373938243667", size = Vector3.new(6, 3.6, 0.2), center = Vector3.new(0, 0, -0), color = "wood", material = "SmoothPlastic" },
			Cork = { id = "rbxassetid://105901815504743", size = Vector3.new(5.6, 3.2, 0.06), center = Vector3.new(0, 0, 0.1), color = "woodLight", material = "SmoothPlastic" },
			Paper = { id = "rbxassetid://72421081492862", size = Vector3.new(4.883, 2.273, 0.03), center = Vector3.new(0.044, 0.091, 0.14), color = "surface", material = "SmoothPlastic" },
			Memo = { id = "rbxassetid://127558657463655", size = Vector3.new(3.691, 2.591, 0.03), center = Vector3.new(-0.506, -0.156, 0.15), color = "yellow", material = "SmoothPlastic" },
		},
	},
	CardboardBox = {
		flip = true,
		parts = {
			Box = { id = "rbxassetid://115847740562754", size = Vector3.new(2.4, 2, 2.4), center = Vector3.new(0, 1, -0), color = "wood", material = "SmoothPlastic" },
			Tape = { id = "rbxassetid://128265201175115", size = Vector3.new(0.5, 0.805, 2.435), center = Vector3.new(0, 1.623, 0.007), color = "woodLight", material = "SmoothPlastic" },
		},
	},
	TrashBin = {
		flip = true,
		parts = {
			Bin = { id = "rbxassetid://119731033037339", size = Vector3.new(1.6, 2, 1.576), center = Vector3.new(0, 1, -0), color = "navySoft", material = "SmoothPlastic" },
		},
	},
	RDesk = {
		flip = true,
		parts = {
			Top = { id = "rbxassetid://109233100118795", size = Vector3.new(7.6, 0.2, 3.8), center = Vector3.new(-0.2, 2.46, -0), color = "laminate", material = "SmoothPlastic" },
			Frame = { id = "rbxassetid://81249359682554", size = Vector3.new(7.36, 2.36, 3.44), center = Vector3.new(-0.2, 1.18, -0.04), color = "metal", material = "SmoothPlastic" },
			Partition = { id = "rbxassetid://132617565482788", size = Vector3.new(8.42, 3, 3.21), center = Vector3.new(-0.2, 1.5, -0.605), color = "sage", material = "Fabric" },
			Trim = { id = "rbxassetid://126465795589147", size = Vector3.new(8.5, 3.12, 3.49), center = Vector3.new(-0.2, 1.56, -0.505), color = "metal", material = "SmoothPlastic" },
			Keyboard = { id = "rbxassetid://131633109585427", size = Vector3.new(2.72, 0.12, 0.64), center = Vector3.new(0.11, 2.62, 0.51), color = "navy", material = "SmoothPlastic" },
			Paper = { id = "rbxassetid://108220853676989", size = Vector3.new(1.427, 0.06, 1.651), center = Vector3.new(-2.421, 2.595, 0.337), color = "paper", material = "SmoothPlastic" },
			Cup = { id = "rbxassetid://140677363136781", size = Vector3.new(0.39, 0.42, 0.4), center = Vector3.new(2.6, 2.77, -0.7), color = "coral", material = "SmoothPlastic" },
		},
	},
	RMonitor = {
		flip = true,
		parts = {
			Frame = { id = "rbxassetid://134777630384713", size = Vector3.new(3.3, 2.575, 0.9), center = Vector3.new(0.75, 3.787, -1.3), color = "navy", material = "SmoothPlastic" },
			Screen = { id = "rbxassetid://118772919389630", size = Vector3.new(3.14, 1.78, 0.03), center = Vector3.new(0.75, 4.12, -1.18), color = "screen", material = "Neon" },
		},
	},
	RChair = {
		flip = true,
		parts = {
			Seat = { id = "rbxassetid://140262678193565", size = Vector3.new(1.95, 0.34, 1.95), center = Vector3.new(0, 1.6, -0), color = "seat", material = "Fabric" },
			Back = { id = "rbxassetid://85425383604939", size = Vector3.new(1.85, 2.281, 0.502), center = Vector3.new(0, 3.15, 1), color = "seat", material = "Fabric" },
			Frame = { id = "rbxassetid://75729644512220", size = Vector3.new(2.46, 3.74, 2.33), center = Vector3.new(0, 2.1, 0.125), color = "navy", material = "SmoothPlastic" },
			Wheels = { id = "rbxassetid://114361254252213", size = Vector3.new(2.536, 0.28, 2.437), center = Vector3.new(0, 0.14, 0.115), color = "navy", material = "SmoothPlastic" },
		},
	},
	RDrawer = {
		flip = true,
		parts = {
			Body = { id = "rbxassetid://91428974799506", size = Vector3.new(1.7, 2.05, 2.4), center = Vector3.new(0, 1.1, -0), color = "surfaceSoft", material = "Metal" },
			Lines = { id = "rbxassetid://108907556038837", size = Vector3.new(1.56, 1.22, 0.045), center = Vector3.new(0, 1.345, 1.207), color = "navy", material = "SmoothPlastic" },
		},
	},
	Desk = {
		flip = true,
		parts = {
			Top = { id = "rbxassetid://79896876608529", size = Vector3.new(7.6, 0.42, 4.9), center = Vector3.new(-0.2, 2.35, 0.55), color = "woodLight", material = "SmoothPlastic" },
			Legs = { id = "rbxassetid://136110689305236", size = Vector3.new(6.125, 2.14, 3.16), center = Vector3.new(-0.663, 1.07, -0.08), color = "surface", material = "SmoothPlastic" },
			Partition = { id = "rbxassetid://75203700320121", size = Vector3.new(8.7, 3, 3.167), center = Vector3.new(-0.2, 1.5, -0.766), color = "sage", material = "Fabric" },
			Keyboard = { id = "rbxassetid://123411498848257", size = Vector3.new(2.66, 0.2, 0.675), center = Vector3.new(-0.07, 2.62, 0.512), color = "surface", material = "SmoothPlastic" },
			Cup = { id = "rbxassetid://115602256360582", size = Vector3.new(0.4, 0.5, 0.4), center = Vector3.new(-2.6, 2.81, -1.2), color = "coral", material = "SmoothPlastic" },
		},
	},
	Monitor = {
		flip = true,
		parts = {
			Frame = { id = "rbxassetid://124760707219806", size = Vector3.new(3, 1.9, 0.3), center = Vector3.new(0.75, 4.15, -1.25), color = "navy", material = "SmoothPlastic" },
			Screen = { id = "rbxassetid://85130163865657", size = Vector3.new(2.62, 1.52, 0.06), center = Vector3.new(0.75, 4.15, -1.09), color = "sky", material = "Neon" },
			Arm = { id = "rbxassetid://129701790780133", size = Vector3.new(1.9, 1.79, 1.1), center = Vector3.new(-0, 3.455, -1.35), color = "metal", material = "SmoothPlastic" },
		},
	},
	Chair = {
		flip = true,
		parts = {
			Seat = { id = "rbxassetid://72435890934338", size = Vector3.new(2.1, 0.55, 2), center = Vector3.new(0, 1.55, -0), color = "coral", material = "Fabric" },
			Back = { id = "rbxassetid://120086763861412", size = Vector3.new(1.9, 2.96, 0.808), center = Vector3.new(0, 3.335, 1.026), color = "coral", material = "Fabric" },
			Frame = { id = "rbxassetid://90876142811699", size = Vector3.new(2.6, 4.208, 2.57), center = Vector3.new(0, 2.295, 0.165), color = "surface", material = "SmoothPlastic" },
			Arms = { id = "rbxassetid://104301652411934", size = Vector3.new(2.72, 0.2, 1.4), center = Vector3.new(0, 2.22, 0.15), color = "navySoft", material = "SmoothPlastic" },
			Wheels = { id = "rbxassetid://114556241294368", size = Vector3.new(2.738, 0.36, 2.621), center = Vector3.new(0, 0.18, 0.119), color = "navy", material = "SmoothPlastic" },
		},
	},
	Drawer = {
		flip = true,
		parts = {
			Body = { id = "rbxassetid://85993709749817", size = Vector3.new(1.9, 1.62, 2.5), center = Vector3.new(0, 1.11, -0), color = "cream", material = "SmoothPlastic" },
			Top = { id = "rbxassetid://128441914140413", size = Vector3.new(2, 0.16, 2.6), center = Vector3.new(0, 2, -0), color = "woodLight", material = "SmoothPlastic" },
			Fronts = { id = "rbxassetid://99961917864684", size = Vector3.new(1.5, 1.32, 0.12), center = Vector3.new(0, 1.11, 1.28), color = "surface", material = "SmoothPlastic" },
			Handles = { id = "rbxassetid://119985885529164", size = Vector3.new(0.7, 0.82, 0.12), center = Vector3.new(0, 1.11, 1.38), color = "wood", material = "SmoothPlastic" },
			Wheels = { id = "rbxassetid://95356159119855", size = Vector3.new(1.62, 0.32, 2.22), center = Vector3.new(0, 0.16, -0), color = "navy", material = "SmoothPlastic" },
		},
	},
	Lamp = {
		flip = true,
		parts = {
			Body = { id = "rbxassetid://82839409116790", size = Vector3.new(1.497, 1.92, 1.24), center = Vector3.new(0.249, 0.96, -0), color = "yellow", material = "SmoothPlastic" },
			Stem = { id = "rbxassetid://116421615819319", size = Vector3.new(0.73, 1.54, 0.22), center = Vector3.new(0.005, 0.8, -0), color = "wood", material = "SmoothPlastic" },
			Bulb = { id = "rbxassetid://119345540430740", size = Vector3.new(0.5, 0.5, 0.5), center = Vector3.new(0.5, 1.27, -0), color = "yellowSoft", material = "Neon" },
		},
	},
	Plant = {
		flip = true,
		parts = {
			Pot = { id = "rbxassetid://128187338478469", size = Vector3.new(1.62, 1.23, 1.62), center = Vector3.new(0, 0.615, -0), color = "surface", material = "SmoothPlastic" },
			Soil = { id = "rbxassetid://98010772579274", size = Vector3.new(1.24, 0.06, 1.24), center = Vector3.new(0, 1.12, -0), color = "woodDark", material = "SmoothPlastic" },
			Leaves = { id = "rbxassetid://118632189076097", size = Vector3.new(2.441, 1.497, 2.386), center = Vector3.new(-0.072, 1.849, -0.023), color = "grass", material = "SmoothPlastic" },
			LeavesLight = { id = "rbxassetid://117189573731398", size = Vector3.new(1.461, 2.232, 1.121), center = Vector3.new(0.023, 2.216, -0.004), color = "grassLight", material = "SmoothPlastic" },
		},
	},
	PharmCounter = {
		flip = true,
		parts = {
			Body = { id = "rbxassetid://72411943743217", size = Vector3.new(10, 3.2, 2.2), center = Vector3.new(0, 1.6, -0.1), color = "cakeCream", material = "SmoothPlastic" },
			Band = { id = "rbxassetid://75663185442216", size = Vector3.new(10.1, 3, 2.3), center = Vector3.new(0, 1.5, -0.1), color = "pharm", material = "SmoothPlastic" },
			Top = { id = "rbxassetid://131029783361980", size = Vector3.new(10.4, 0.24, 2.7), center = Vector3.new(0, 3.4, -0), color = "stone", material = "SmoothPlastic" },
			Glass = { id = "rbxassetid://135820618874473", size = Vector3.new(4.6, 1.6, 0.2), center = Vector3.new(-2.3, 1.5, 1.02), color = "glass", material = "Glass" },
			Boxes = { id = "rbxassetid://99718737530729", size = Vector3.new(4.1, 0.9, 0.4), center = Vector3.new(-2.3, 1.4, 0.7), color = "pharmSoft", material = "SmoothPlastic" },
			Cross = { id = "rbxassetid://107009136996965", size = Vector3.new(0.9, 0.9, 0.08), center = Vector3.new(3, 1.6, 1.02), color = "pharm", material = "SmoothPlastic" },
			Register = { id = "rbxassetid://137868380694946", size = Vector3.new(1.3, 1.288, 1), center = Vector3.new(3.6, 4.144, -0.1), color = "ink", material = "SmoothPlastic" },
			Bags = { id = "rbxassetid://125129765867226", size = Vector3.new(3, 1.018, 0.422), center = Vector3.new(-2.1, 4, 0.2), color = "surface", material = "SmoothPlastic" },
		},
	},
	MedShelf = {
		flip = true,
		parts = {
			Frame = { id = "rbxassetid://77348057801670", size = Vector3.new(6, 9, 1.45), center = Vector3.new(0, 4.5, -0.025), color = "cakeCream", material = "SmoothPlastic" },
			Drawers = { id = "rbxassetid://90351531805616", size = Vector3.new(5.7, 2.4, 1.3), center = Vector3.new(0, 1.25, -0), color = "pharmSoft", material = "SmoothPlastic" },
			Handles = { id = "rbxassetid://77071478582399", size = Vector3.new(4.6, 1.12, 0.1), center = Vector3.new(0, 1.25, 0.68), color = "pharm", material = "SmoothPlastic" },
			BoxesA = { id = "rbxassetid://72953475546180", size = Vector3.new(5.3, 5.25, 0.5), center = Vector3.new(0, 5.3, 0.1), color = "pharmSoft", material = "SmoothPlastic" },
			BoxesB = { id = "rbxassetid://108193827174233", size = Vector3.new(5.3, 5.45, 0.5), center = Vector3.new(0, 5.4, 0.1), color = "surface", material = "SmoothPlastic" },
			Bottles = { id = "rbxassetid://135762496319318", size = Vector3.new(5.12, 5.3, 0.52), center = Vector3.new(0, 5.32, 0.1), color = "woodDark", material = "SmoothPlastic" },
			Caps = { id = "rbxassetid://128198535860482", size = Vector3.new(5, 4.68, 0.4), center = Vector3.new(0, 5.81, 0.1), color = "cakeCream", material = "SmoothPlastic" },
		},
	},
	PharmCross = {
		flip = true,
		parts = {
			Plate = { id = "rbxassetid://113259783017601", size = Vector3.new(3.4, 3.4, 0.2), center = Vector3.new(0, 0, 0.1), color = "cakeCream", material = "SmoothPlastic" },
			Cross = { id = "rbxassetid://87035515076438", size = Vector3.new(2.6, 2.6, 0.16), center = Vector3.new(0, 0, 0.26), color = "pharm", material = "Neon" },
		},
	},
	WaitBench = {
		flip = true,
		parts = {
			Seats = { id = "rbxassetid://116380931468077", size = Vector3.new(5.7, 1.693, 1.833), center = Vector3.new(0, 2.347, -0.066), color = "pharm", material = "SmoothPlastic" },
			Frame = { id = "rbxassetid://115731294558692", size = Vector3.new(6, 3.028, 1.878), center = Vector3.new(0, 1.545, -0.07), color = "metal", material = "Metal" },
		},
	},
	PillBottle = {
		flip = true,
		parts = {
			Bottle = { id = "rbxassetid://85194083528602", size = Vector3.new(2.6, 3.6, 2.6), center = Vector3.new(0, 1.8, -0), color = "woodDark", material = "SmoothPlastic" },
			Cap = { id = "rbxassetid://99100561198061", size = Vector3.new(1.9, 0.9, 1.9), center = Vector3.new(0, 4.05, -0), color = "cakeCream", material = "SmoothPlastic" },
			Label = { id = "rbxassetid://100838175415789", size = Vector3.new(2.72, 1.6, 2.72), center = Vector3.new(0, 1.7, -0), color = "surface", material = "SmoothPlastic" },
			Mark = { id = "rbxassetid://72160183346560", size = Vector3.new(0.9, 0.9, 0.1), center = Vector3.new(0, 1.7, 1.36), color = "pharm", material = "SmoothPlastic" },
			PillsA = { id = "rbxassetid://125154315930795", size = Vector3.new(0.907, 0.36, 2.207), center = Vector3.new(1.981, 0.18, -0.231), color = "blush", material = "SmoothPlastic" },
			PillsB = { id = "rbxassetid://128439861396184", size = Vector3.new(5.433, 0.36, 1.781), center = Vector3.new(0.272, 0.18, 0.235), color = "sky", material = "SmoothPlastic" },
		},
	},
	BpMachine = {
		flip = true,
		parts = {
			Table = { id = "rbxassetid://104123606494024", size = Vector3.new(3, 2.72, 2.2), center = Vector3.new(0, 1.34, -0), color = "cakeCream", material = "SmoothPlastic" },
			Body = { id = "rbxassetid://137533465449800", size = Vector3.new(1.6, 1.3, 1.6), center = Vector3.new(-0.4, 3.35, -0.1), color = "surface", material = "SmoothPlastic" },
			Cuff = { id = "rbxassetid://116423559289975", size = Vector3.new(1, 1, 1.7), center = Vector3.new(-0.4, 3.3, -0.1), color = "ink", material = "SmoothPlastic" },
			Screen = { id = "rbxassetid://111782861034376", size = Vector3.new(0.9, 0.533, 0.35), center = Vector3.new(0.9, 3.2, 0.2), color = "neonCyan", material = "Neon" },
		},
	},
	FoodTruck = {
		flip = true,
		parts = {
			Body = { id = "rbxassetid://103841276350949", size = Vector3.new(19.9, 6.6, 7), center = Vector3.new(0.45, 5, -0), color = "coral", material = "SmoothPlastic" },
			Stripe = { id = "rbxassetid://86821988818794", size = Vector3.new(20, 0.7, 7.1), center = Vector3.new(0.45, 2.4, -0), color = "cakeCream", material = "SmoothPlastic" },
			Window = { id = "rbxassetid://85847186295084", size = Vector3.new(11, 3.8, 7.14), center = Vector3.new(-3.8, 5.2, -0), color = "ink", material = "SmoothPlastic" },
			Glass = { id = "rbxassetid://133020706297782", size = Vector3.new(4.175, 2.135, 6.92), center = Vector3.new(8.588, 4.9, -0), color = "glass", material = "Glass" },
			Counter = { id = "rbxassetid://101922096064375", size = Vector3.new(9.4, 1.52, 1.6), center = Vector3.new(-2.6, 3.29, 4.1), color = "woodLight", material = "Wood" },
			AwningA = { id = "rbxassetid://106926586870131", size = Vector3.new(8.64, 1.658, 3.068), center = Vector3.new(-3.06, 7.769, 4.716), color = "red", material = "Fabric" },
			AwningB = { id = "rbxassetid://102315484183564", size = Vector3.new(8.64, 1.658, 3.068), center = Vector3.new(-2.1, 7.769, 4.716), color = "cakeCream", material = "Fabric" },
			Wheels = { id = "rbxassetid://75985313574516", size = Vector3.new(15.6, 2.5, 7.3), center = Vector3.new(0.05, 1.25, -0), color = "ink", material = "SmoothPlastic" },
			Hubs = { id = "rbxassetid://80480791849293", size = Vector3.new(20.6, 1.65, 7.36), center = Vector3.new(0.45, 1.525, -0), color = "metal", material = "Metal" },
			Lights = { id = "rbxassetid://136766402394230", size = Vector3.new(0.3, 0.7, 5.7), center = Vector3.new(10.45, 3, -0), color = "yellowSoft", material = "Neon" },
			Sign = { id = "rbxassetid://76567803276516", size = Vector3.new(7, 1.8, 0.4), center = Vector3.new(-2.6, 9, -0), color = "yellow", material = "SmoothPlastic" },
			Menu = { id = "rbxassetid://124102598767806", size = Vector3.new(3.6, 1.3, 0.1), center = Vector3.new(-4.4, 5.9, 3.6), color = "cakeCream", material = "SmoothPlastic" },
			Food = { id = "rbxassetid://77233605042643", size = Vector3.new(2.5, 0.4, 0.5), center = Vector3.new(1.1, 4.25, 4.2), color = "yellow", material = "SmoothPlastic" },
		},
	},
	GymBike = {
		flip = true,
		parts = {
			Base = { id = "rbxassetid://98260944601236", size = Vector3.new(2.6, 0.3, 4.7), center = Vector3.new(0, 0.15, -0), color = "ink", material = "SmoothPlastic" },
			Frame = { id = "rbxassetid://78937577515100", size = Vector3.new(0.32, 3.52, 3.72), center = Vector3.new(0, 1.9, 1), color = "metal", material = "Metal" },
			Wheel = { id = "rbxassetid://124398858333721", size = Vector3.new(0.5, 2.3, 2.3), center = Vector3.new(0, 1.6, 1.5), color = "coral", material = "SmoothPlastic" },
			Hub = { id = "rbxassetid://102886269301013", size = Vector3.new(0.56, 1, 1), center = Vector3.new(0, 1.6, 1.5), color = "ink", material = "SmoothPlastic" },
			Saddle = { id = "rbxassetid://96477788504417", size = Vector3.new(1.1, 0.3, 1.5), center = Vector3.new(0, 2.25, -0.75), color = "ink", material = "SmoothPlastic" },
			Bars = { id = "rbxassetid://72434509986575", size = Vector3.new(2.4, 0.349, 0.799), center = Vector3.new(0, 3.674, 2.301), color = "ink", material = "SmoothPlastic" },
			Screen = { id = "rbxassetid://89122173247528", size = Vector3.new(1.1, 0.663, 0.317), center = Vector3.new(0, 4.05, 2.95), color = "neonCyan", material = "Neon" },
			Pedals = { id = "rbxassetid://120239677051038", size = Vector3.new(2.1, 0.14, 0.8), center = Vector3.new(0, 1.1, 0.4), color = "ink", material = "SmoothPlastic" },
		},
	},
	GymRower = {
		flip = true,
		parts = {
			Rail = { id = "rbxassetid://77525010545287", size = Vector3.new(0.5, 0.3, 8), center = Vector3.new(0, 0.5, -0.5), color = "metal", material = "Metal" },
			Feet = { id = "rbxassetid://93978712687597", size = Vector3.new(2, 0.55, 8.1), center = Vector3.new(0, 0.275, -0.5), color = "ink", material = "SmoothPlastic" },
			Fan = { id = "rbxassetid://125828608010981", size = Vector3.new(1.5, 1.9, 1.9), center = Vector3.new(0, 1.3, 3.5), color = "coral", material = "SmoothPlastic" },
			FanCover = { id = "rbxassetid://121074416739949", size = Vector3.new(1.6, 1.5, 1.7), center = Vector3.new(0, 1.15, 3.25), color = "ink", material = "SmoothPlastic" },
			Pads = { id = "rbxassetid://80558820536724", size = Vector3.new(1.9, 0.722, 0.953), center = Vector3.new(0, 1, 2.2), color = "ink", material = "SmoothPlastic" },
			Handle = { id = "rbxassetid://72399882773373", size = Vector3.new(1.96, 0.21, 0.51), center = Vector3.new(0, 1.475, 2.775), color = "ink", material = "SmoothPlastic" },
			Screen = { id = "rbxassetid://111673451411475", size = Vector3.new(0.9, 0.835, 0.414), center = Vector3.new(0, 2.359, 3.452), color = "neonCyan", material = "Neon" },
		},
	},
	GymSandbag = {
		flip = true,
		parts = {
			Bag = { id = "rbxassetid://105680703627365", size = Vector3.new(2, 4, 2), center = Vector3.new(0, 4, 1.6), color = "coral", material = "Fabric" },
			Bands = { id = "rbxassetid://99585363362371", size = Vector3.new(2.06, 2.85, 2.06), center = Vector3.new(0, 4, 1.6), color = "ink", material = "SmoothPlastic" },
			Chain = { id = "rbxassetid://93636773946945", size = Vector3.new(1.28, 1.49, 1.28), center = Vector3.new(0, 6.705, 1.6), color = "metal", material = "Metal" },
			Mat = { id = "rbxassetid://105471879845588", size = Vector3.new(4, 0.14, 5), center = Vector3.new(0, 0.07, -0), color = "sky", material = "SmoothPlastic" },
		},
	},
	GymMat = {
		flip = true,
		parts = {
			Mat = { id = "rbxassetid://92995139122514", size = Vector3.new(3, 0.12, 6.5), center = Vector3.new(0, 0.06, -0), color = "sky", material = "SmoothPlastic" },
			Roll = { id = "rbxassetid://115445946799749", size = Vector3.new(3, 0.56, 0.56), center = Vector3.new(0, 0.3, 3.5), color = "lilac", material = "SmoothPlastic" },
			Bottle = { id = "rbxassetid://71754804904306", size = Vector3.new(0.32, 0.73, 0.32), center = Vector3.new(1.9, 0.365, 1), color = "mint", material = "SmoothPlastic" },
			Dumbbells = { id = "rbxassetid://107748987391797", size = Vector3.new(0.86, 0.4, 1.1), center = Vector3.new(-1.9, 0.2, 0.95), color = "ink", material = "SmoothPlastic" },
		},
	},
	GymBall = {
		flip = true,
		parts = {
			Ball = { id = "rbxassetid://111019458445182", size = Vector3.new(3.2, 3.2, 3.2), center = Vector3.new(0, 1.6, -0), color = "yellow", material = "SmoothPlastic" },
			Ring = { id = "rbxassetid://129746288572471", size = Vector3.new(2.6, 0.25, 2.6), center = Vector3.new(0, 0.125, -0), color = "ink", material = "SmoothPlastic" },
			Mat = { id = "rbxassetid://109092600686392", size = Vector3.new(3.6, 0.08, 3.6), center = Vector3.new(0, 0.04, -0), color = "navy", material = "SmoothPlastic" },
		},
	},
	Pyeongsang = {
		flip = true,
		parts = {
			Deck = { id = "rbxassetid://102793261811676", size = Vector3.new(7.92, 0.2, 5), center = Vector3.new(0, 1.3, -0), color = "woodLight", material = "Wood" },
			Frame = { id = "rbxassetid://107265543084672", size = Vector3.new(8, 1.2, 4.9), center = Vector3.new(0, 0.6, -0), color = "woodDark", material = "Wood" },
			Cushions = { id = "rbxassetid://93954760047617", size = Vector3.new(6.4, 0.25, 1.6), center = Vector3.new(0, 1.55, -1.2), color = "coral", material = "Fabric" },
			Table = { id = "rbxassetid://120031602729999", size = Vector3.new(2.4, 0.67, 1.5), center = Vector3.new(0.6, 1.735, 0.9), color = "wood", material = "Wood" },
			Kettle = { id = "rbxassetid://102043900279084", size = Vector3.new(1.38, 0.56, 0.72), center = Vector3.new(0.53, 2.35, 0.9), color = "yellow", material = "Metal" },
		},
	},
	PlasticChair = {
		flip = true,
		parts = {
			Chair = { id = "rbxassetid://108893447924383", size = Vector3.new(1.58, 3.084, 1.655), center = Vector3.new(0, 1.502, -0.038), color = "rubber", material = "SmoothPlastic" },
		},
	},
	TubPlanter = {
		flip = true,
		parts = {
			Tub = { id = "rbxassetid://73955523339122", size = Vector3.new(3.4, 1.2, 3.4), center = Vector3.new(0, 0.6, -0), color = "tub", material = "SmoothPlastic" },
			Soil = { id = "rbxassetid://114674697667395", size = Vector3.new(3, 0.1, 3), center = Vector3.new(0, 1, -0), color = "choco", material = "SmoothPlastic" },
			Lettuce = { id = "rbxassetid://75695921699925", size = Vector3.new(2.247, 0.5, 2.322), center = Vector3.new(0.076, 1.25, -0), color = "grassLight", material = "SmoothPlastic" },
			Onions = { id = "rbxassetid://114413170644665", size = Vector3.new(0.7, 1.35, 0.52), center = Vector3.new(0, 1.675, 0.01), color = "grass", material = "SmoothPlastic" },
		},
	},
	AcUnit = {
		flip = true,
		parts = {
			Body = { id = "rbxassetid://125606111600052", size = Vector3.new(4, 3.1, 1.6), center = Vector3.new(0, 1.55, -0), color = "surface", material = "Metal" },
			Fan = { id = "rbxassetid://133920414427746", size = Vector3.new(2.3, 2.3, 0.12), center = Vector3.new(-0.6, 1.6, 0.82), color = "ink", material = "SmoothPlastic" },
			Grille = { id = "rbxassetid://118648470714633", size = Vector3.new(2.26, 2.26, 0.08), center = Vector3.new(-0.6, 1.6, 0.92), color = "metal", material = "Metal" },
			Vents = { id = "rbxassetid://137748746119534", size = Vector3.new(0.9, 1.48, 0.06), center = Vector3.new(1.35, 1.6, 0.82), color = "line", material = "SmoothPlastic" },
		},
	},
	ClothesLine = {
		flip = true,
		parts = {
			Poles = { id = "rbxassetid://125959767645764", size = Vector3.new(11, 7, 1.74), center = Vector3.new(0, 3.5, -0), color = "metal", material = "Metal" },
			Lines = { id = "rbxassetid://95310757795259", size = Vector3.new(10.05, 0.05, 1.45), center = Vector3.new(0, 6.8, -0), color = "ink", material = "SmoothPlastic" },
			White = { id = "rbxassetid://99384399460592", size = Vector3.new(8.3, 3.6, 1.48), center = Vector3.new(-0.05, 5, -0), color = "cakeCream", material = "Fabric" },
			Blue = { id = "rbxassetid://105254818682186", size = Vector3.new(3.5, 3.2, 1.48), center = Vector3.new(0.75, 5.2, -0), color = "sky", material = "Fabric" },
			Pink = { id = "rbxassetid://82673296846592", size = Vector3.new(6.1, 2, 0.08), center = Vector3.new(-1.15, 5.8, 0.7), color = "blush", material = "Fabric" },
		},
	},
	CafeBar = {
		flip = true,
		parts = {
			Body = { id = "rbxassetid://121069954260659", size = Vector3.new(11.6, 3.2, 2.2), center = Vector3.new(0, 1.75, -0.1), color = "espresso", material = "SmoothPlastic" },
			Slats = { id = "rbxassetid://129908493209004", size = Vector3.new(11.34, 3, 0.16), center = Vector3.new(0, 1.75, 1.06), color = "wood", material = "Wood" },
			Top = { id = "rbxassetid://136284590307766", size = Vector3.new(12.2, 0.28, 2.9), center = Vector3.new(0, 3.5, -0), color = "stone", material = "SmoothPlastic" },
			Kick = { id = "rbxassetid://123374627211165", size = Vector3.new(11.4, 0.3, 2), center = Vector3.new(0, 0.15, -0.1), color = "ink", material = "SmoothPlastic" },
		},
	},
	EspressoMachine = {
		flip = true,
		parts = {
			Body = { id = "rbxassetid://87863961597548", size = Vector3.new(2.6, 1.7, 1.7), center = Vector3.new(0, 0.85, 0.05), color = "metal", material = "Metal" },
			Panel = { id = "rbxassetid://129575886593330", size = Vector3.new(2.3, 1.18, 0.49), center = Vector3.new(0, 0.96, 0.595), color = "ink", material = "SmoothPlastic" },
			Cups = { id = "rbxassetid://91080306105308", size = Vector3.new(2, 0.26, 0.4), center = Vector3.new(0, 1.86, -0.1), color = "cakeCream", material = "SmoothPlastic" },
			Grinder = { id = "rbxassetid://105800898216778", size = Vector3.new(0.72, 1.62, 0.8), center = Vector3.new(2, 0.81, -0), color = "ink", material = "SmoothPlastic" },
		},
	},
	PastryCase = {
		flip = true,
		parts = {
			Frame = { id = "rbxassetid://140172920159945", size = Vector3.new(4.2, 1.96, 1.7), center = Vector3.new(0, 0.98, -0), color = "ink", material = "SmoothPlastic" },
			Glass = { id = "rbxassetid://135696863290570", size = Vector3.new(4, 1.7, 1.5), center = Vector3.new(0, 1, -0), color = "glass", material = "Glass" },
			Shelf = { id = "rbxassetid://75881120280464", size = Vector3.new(3.9, 0.06, 1.4), center = Vector3.new(0, 1, -0), color = "metal", material = "Metal" },
			Bread = { id = "rbxassetid://100481085021401", size = Vector3.new(3.3, 0.3, 0.36), center = Vector3.new(0, 0.35, 0.2), color = "wood", material = "SmoothPlastic" },
			Cakes = { id = "rbxassetid://110929920493597", size = Vector3.new(3.28, 0.3, 0.48), center = Vector3.new(0, 1.2, 0.1), color = "cakeCream", material = "SmoothPlastic" },
			Berries = { id = "rbxassetid://73768252400764", size = Vector3.new(2.94, 0.14, 0.14), center = Vector3.new(0, 1.42, 0.1), color = "berry", material = "SmoothPlastic" },
		},
	},
	MenuBoard = {
		flip = true,
		parts = {
			Board = { id = "rbxassetid://78367754092595", size = Vector3.new(8.6, 3, 0.16), center = Vector3.new(0, 0, 0.08), color = "ink", material = "SmoothPlastic" },
			Frame = { id = "rbxassetid://107944775585567", size = Vector3.new(9, 3.4, 0.26), center = Vector3.new(0, 0, 0.13), color = "wood", material = "Wood" },
			Chalk = { id = "rbxassetid://131432641260644", size = Vector3.new(7.7, 1.62, 0.04), center = Vector3.new(0, 0, 0.18), color = "cakeCream", material = "SmoothPlastic" },
			Accent = { id = "rbxassetid://72358035059266", size = Vector3.new(8, 0.2, 0.04), center = Vector3.new(0, 1.2, 0.18), color = "yellow", material = "SmoothPlastic" },
		},
	},
	CafeTable = {
		flip = true,
		parts = {
			Top = { id = "rbxassetid://87266748544398", size = Vector3.new(3, 0.16, 3), center = Vector3.new(0, 2.62, -0), color = "woodLight", material = "Wood" },
			Base = { id = "rbxassetid://74647993928192", size = Vector3.new(1.8, 2.55, 1.8), center = Vector3.new(0, 1.275, -0), color = "ink", material = "SmoothPlastic" },
		},
	},
	CafeChair = {
		flip = true,
		parts = {
			Seat = { id = "rbxassetid://94440574786179", size = Vector3.new(1.44, 0.14, 1.44), center = Vector3.new(0, 1.6, -0), color = "wood", material = "Wood" },
			Frame = { id = "rbxassetid://113867431692466", size = Vector3.new(1.34, 3.069, 1.399), center = Vector3.new(0, 1.515, -0.03), color = "ink", material = "SmoothPlastic" },
			Back = { id = "rbxassetid://133314259567824", size = Vector3.new(1.4, 0.497, 0.141), center = Vector3.new(0, 2.8, -0.68), color = "wood", material = "Wood" },
		},
	},
	BarStool = {
		flip = true,
		parts = {
			Seat = { id = "rbxassetid://135195714436473", size = Vector3.new(1.2, 0.22, 1.2), center = Vector3.new(0, 2.78, -0), color = "seat", material = "Fabric" },
			Frame = { id = "rbxassetid://122875642254851", size = Vector3.new(1.19, 2.76, 1.19), center = Vector3.new(0, 1.365, -0), color = "ink", material = "SmoothPlastic" },
		},
	},
	PendantLamp = {
		flip = true,
		parts = {
			Cord = { id = "rbxassetid://77229022232975", size = Vector3.new(0.4, 2.2, 0.4), center = Vector3.new(0, -1.1, -0), color = "ink", material = "SmoothPlastic" },
			Shade = { id = "rbxassetid://92344858021921", size = Vector3.new(1.6, 1, 1.6), center = Vector3.new(0, -2.7, -0), color = "ink", material = "SmoothPlastic" },
			Bulb = { id = "rbxassetid://100093842020154", size = Vector3.new(0.42, 0.42, 0.42), center = Vector3.new(0, -3, -0), color = "yellowSoft", material = "Neon" },
		},
	},
	WallShelf = {
		flip = true,
		parts = {
			Plank = { id = "rbxassetid://116331980895360", size = Vector3.new(5, 0.63, 0.9), center = Vector3.new(0, -0.235, 0.45), color = "woodLight", material = "Wood" },
			Cups = { id = "rbxassetid://109696947328446", size = Vector3.new(1.64, 0.3, 0.38), center = Vector3.new(-1.37, 0.23, 0.5), color = "cakeCream", material = "SmoothPlastic" },
			Jars = { id = "rbxassetid://113705032432398", size = Vector3.new(1.4, 0.6, 0.4), center = Vector3.new(0.6, 0.38, 0.5), color = "glass", material = "Glass" },
			Pot = { id = "rbxassetid://109924989990321", size = Vector3.new(0.56, 0.34, 0.56), center = Vector3.new(2, 0.25, 0.5), color = "coral", material = "SmoothPlastic" },
			Leaves = { id = "rbxassetid://90900472454285", size = Vector3.new(0.7, 0.6, 0.6), center = Vector3.new(2, 0.75, 0.5), color = "grass", material = "SmoothPlastic" },
		},
	},
	BoothSofa = {
		flip = true,
		parts = {
			Base = { id = "rbxassetid://94165549342383", size = Vector3.new(6, 0.9, 2.2), center = Vector3.new(0, 0.45, -0), color = "woodDark", material = "Wood" },
			Seat = { id = "rbxassetid://140244756841045", size = Vector3.new(5.9, 0.6, 2), center = Vector3.new(0, 1.2, 0.1), color = "sage", material = "Fabric" },
			Back = { id = "rbxassetid://94388168021475", size = Vector3.new(5.9, 2, 0.5), center = Vector3.new(0, 2.5, -0.8), color = "sage", material = "Fabric" },
		},
	},
	DessertShowcase = {
		flip = true,
		parts = {
			Base = { id = "rbxassetid://91297276548271", size = Vector3.new(8, 1.5, 2.6), center = Vector3.new(0, 0.75, -0), color = "blush", material = "SmoothPlastic" },
			Trim = { id = "rbxassetid://105210911638249", size = Vector3.new(8.1, 4, 2.7), center = Vector3.new(0, 2, -0), color = "gold", material = "Metal" },
			Glass = { id = "rbxassetid://128598842994291", size = Vector3.new(7.8, 2.3, 2.4), center = Vector3.new(0, 2.75, -0), color = "glass", material = "Glass" },
			Shelf = { id = "rbxassetid://138389597762801", size = Vector3.new(7.6, 0.06, 2), center = Vector3.new(0, 2.7, -0), color = "cakeCream", material = "SmoothPlastic" },
			Cake = { id = "rbxassetid://71042339213438", size = Vector3.new(7, 0.5, 1), center = Vector3.new(0, 1.9, 0.2), color = "cakeCream", material = "SmoothPlastic" },
			Cream = { id = "rbxassetid://80001409519339", size = Vector3.new(7.04, 1.17, 1.04), center = Vector3.new(0, 2.715, 0.2), color = "blush", material = "SmoothPlastic" },
			Berry = { id = "rbxassetid://80891366800173", size = Vector3.new(6.2, 0.2, 0.2), center = Vector3.new(0, 2.34, 0.2), color = "berry", material = "SmoothPlastic" },
			Choco = { id = "rbxassetid://119467870692616", size = Vector3.new(6.8, 0.4, 0.8), center = Vector3.new(0, 2.95, 0.1), color = "choco", material = "SmoothPlastic" },
		},
	},
	DessertCounter = {
		flip = true,
		parts = {
			Body = { id = "rbxassetid://84231067645158", size = Vector3.new(5.8, 3.2, 2), center = Vector3.new(0, 1.6, -0), color = "blush", material = "SmoothPlastic" },
			Panel = { id = "rbxassetid://108856685554584", size = Vector3.new(5.1, 2.2, 0.08), center = Vector3.new(0, 1.7, 1.02), color = "cakeCream", material = "SmoothPlastic" },
			Top = { id = "rbxassetid://116350726123033", size = Vector3.new(6.2, 0.26, 2.4), center = Vector3.new(0, 3.4, -0), color = "stone", material = "SmoothPlastic" },
			Trim = { id = "rbxassetid://114661426960142", size = Vector3.new(5.9, 0.1, 2.1), center = Vector3.new(0, 0.5, -0), color = "gold", material = "Metal" },
			Register = { id = "rbxassetid://76785453224214", size = Vector3.new(1.3, 1.288, 1), center = Vector3.new(1.8, 4.194, -0.1), color = "ink", material = "SmoothPlastic" },
		},
	},
	CakeStand = {
		flip = true,
		parts = {
			Stand = { id = "rbxassetid://132074825219478", size = Vector3.new(1.8, 2, 1.8), center = Vector3.new(0, 1, -0), color = "gold", material = "Metal" },
			MacaronPink = { id = "rbxassetid://81310359059419", size = Vector3.new(1.575, 1.56, 1.122), center = Vector3.new(0.033, 1.17, -0.115), color = "blush", material = "SmoothPlastic" },
			MacaronMint = { id = "rbxassetid://122441630269214", size = Vector3.new(1.375, 1.56, 1.122), center = Vector3.new(-0.067, 1.17, 0.115), color = "mint", material = "SmoothPlastic" },
			MacaronYellow = { id = "rbxassetid://78792739345378", size = Vector3.new(0.727, 1.56, 1.607), center = Vector3.new(0.057, 1.17, -0), color = "yellow", material = "SmoothPlastic" },
		},
	},
	CupcakeSign = {
		flip = true,
		parts = {
			Cup = { id = "rbxassetid://80875587738844", size = Vector3.new(2.9, 2, 2.9), center = Vector3.new(0, 1, -0), color = "blush", material = "SmoothPlastic" },
			Pleats = { id = "rbxassetid://99463502868840", size = Vector3.new(2.58, 2, 2.58), center = Vector3.new(0, 1, -0), color = "cakeCream", material = "SmoothPlastic" },
			Cream = { id = "rbxassetid://119852663570958", size = Vector3.new(3.2, 3.25, 3.2), center = Vector3.new(0, 3.425, -0), color = "cakeCream", material = "SmoothPlastic" },
			Cherry = { id = "rbxassetid://136826538627432", size = Vector3.new(0.7, 0.7, 0.7), center = Vector3.new(0, 5.15, -0), color = "berry", material = "SmoothPlastic" },
			Sprinkles = { id = "rbxassetid://97865596666581", size = Vector3.new(2.537, 1.2, 2.313), center = Vector3.new(0.031, 3.4, 0.142), color = "yellow", material = "SmoothPlastic" },
		},
	},
	ClawMachine = {
		flip = true,
		parts = {
			Base = { id = "rbxassetid://101970771311088", size = Vector3.new(3.6, 3, 3.6), center = Vector3.new(0, 1.5, -0), color = "coral", material = "SmoothPlastic" },
			Chute = { id = "rbxassetid://109997216823023", size = Vector3.new(2.9, 2.75, 0.9), center = Vector3.new(0, 1.825, 1.5), color = "ink", material = "SmoothPlastic" },
			Stick = { id = "rbxassetid://110238777551850", size = Vector3.new(0.24, 0.67, 0.24), center = Vector3.new(0.55, 3.485, 1.5), color = "red", material = "SmoothPlastic" },
			Button = { id = "rbxassetid://122257911368785", size = Vector3.new(0.32, 0.12, 0.32), center = Vector3.new(1.1, 3.26, 1.5), color = "yellow", material = "Neon" },
			Posts = { id = "rbxassetid://115662582518081", size = Vector3.new(3.54, 3.6, 3.54), center = Vector3.new(0, 4.8, -0), color = "cakeCream", material = "SmoothPlastic" },
			Glass = { id = "rbxassetid://140410170454986", size = Vector3.new(3.3, 3.5, 3.3), center = Vector3.new(0, 4.8, -0), color = "glass", material = "Glass" },
			Top = { id = "rbxassetid://108414209514789", size = Vector3.new(3.8, 0.9, 3.8), center = Vector3.new(0, 7, -0), color = "coral", material = "SmoothPlastic" },
			Marquee = { id = "rbxassetid://87844627540066", size = Vector3.new(3.2, 0.6, 0.12), center = Vector3.new(0, 7, 1.92), color = "yellowSoft", material = "Neon" },
			Claw = { id = "rbxassetid://138734369157154", size = Vector3.new(0.701, 2.035, 0.798), center = Vector3.new(0.104, 5.583, -0.002), color = "metal", material = "Metal" },
			PlushA = { id = "rbxassetid://137141065085012", size = Vector3.new(2.36, 1.41, 2.7), center = Vector3.new(-0.25, 3.705, 0.05), color = "blush", material = "SmoothPlastic" },
			PlushB = { id = "rbxassetid://108448568629300", size = Vector3.new(1.81, 0.91, 2.75), center = Vector3.new(0.575, 3.455, -0.025), color = "sky", material = "SmoothPlastic" },
			PlushC = { id = "rbxassetid://92440629339921", size = Vector3.new(2.96, 1.41, 2.4), center = Vector3.new(-0.05, 3.705, 0.1), color = "yellow", material = "SmoothPlastic" },
		},
	},
	GachaMachine = {
		flip = true,
		parts = {
			Body = { id = "rbxassetid://131726418411855", size = Vector3.new(2.1, 5.2, 1.9), center = Vector3.new(0, 2.6, -0), color = "sky", material = "SmoothPlastic" },
			Window = { id = "rbxassetid://92104651037621", size = Vector3.new(1.6, 3.8, 0.3), center = Vector3.new(0, 3.15, 0.8), color = "glass", material = "Glass" },
			Knob = { id = "rbxassetid://77550360134654", size = Vector3.new(1.51, 3.23, 0.2), center = Vector3.new(-0.045, 1.995, 0.95), color = "cakeCream", material = "SmoothPlastic" },
			CapA = { id = "rbxassetid://122148860068183", size = Vector3.new(1.47, 3.32, 0.36), center = Vector3.new(0.005, 3.08, 0.72), color = "coral", material = "SmoothPlastic" },
			CapB = { id = "rbxassetid://130498241852201", size = Vector3.new(0.73, 3.32, 0.36), center = Vector3.new(-0.365, 3.08, 0.72), color = "yellow", material = "SmoothPlastic" },
			CapC = { id = "rbxassetid://86800912744407", size = Vector3.new(0.73, 3.32, 0.36), center = Vector3.new(0.005, 3.08, 0.72), color = "mint", material = "SmoothPlastic" },
		},
	},
	WheelFrame = {
		flip = true,
		parts = {
			Ring = { id = "rbxassetid://81590895200812", size = Vector3.new(10.1, 10.1, 0.5), center = Vector3.new(0, 0, -0), color = "red", material = "SmoothPlastic" },
			Bulbs = { id = "rbxassetid://82343212272859", size = Vector3.new(9.9, 9.9, 0.34), center = Vector3.new(0, 0, 0.3), color = "yellowSoft", material = "Neon" },
			Pointer = { id = "rbxassetid://135707508450544", size = Vector3.new(0.75, 0.9, 0.866), center = Vector3.new(0.125, 4.65, 0.45), color = "gold", material = "Metal" },
			Stand = { id = "rbxassetid://88302697134575", size = Vector3.new(8.4, 6.278, 1.6), center = Vector3.new(0, -5.611, -0), color = "woodDark", material = "Wood" },
		},
	},
	DartBooth = {
		flip = true,
		parts = {
			Posts = { id = "rbxassetid://104337846505665", size = Vector3.new(7.1, 7.6, 3.1), center = Vector3.new(0, 3.8, -0), color = "cakeCream", material = "SmoothPlastic" },
			AwningRed = { id = "rbxassetid://72385943014529", size = Vector3.new(6.3, 1.546, 3.641), center = Vector3.new(-0.45, 7.273, 0.249), color = "red", material = "Fabric" },
			AwningWhite = { id = "rbxassetid://123408782581599", size = Vector3.new(6.3, 1.546, 3.641), center = Vector3.new(0.45, 7.273, 0.249), color = "cakeCream", material = "Fabric" },
			Shelf = { id = "rbxassetid://129653342797631", size = Vector3.new(7.2, 3.4, 1.2), center = Vector3.new(0, 1.75, 1.5), color = "woodLight", material = "Wood" },
			Darts = { id = "rbxassetid://115757253620495", size = Vector3.new(1.16, 0.16, 0.82), center = Vector3.new(-1.5, 3.5, 1.53), color = "ink", material = "SmoothPlastic" },
		},
	},
	PlushShelf = {
		flip = true,
		parts = {
			Frame = { id = "rbxassetid://129142078602756", size = Vector3.new(6.04, 5.2, 1.2), center = Vector3.new(0, 2.6, -0), color = "woodLight", material = "Wood" },
			BearA = { id = "rbxassetid://70679695058958", size = Vector3.new(5.2, 5.74, 1), center = Vector3.new(0, 3.62, -0), color = "blush", material = "Fabric" },
			BearB = { id = "rbxassetid://139496617817367", size = Vector3.new(5.2, 5.74, 1), center = Vector3.new(0, 3.62, -0), color = "sky", material = "Fabric" },
			BearC = { id = "rbxassetid://124027396910459", size = Vector3.new(3.8, 5.74, 1), center = Vector3.new(-0.7, 3.62, -0), color = "yellow", material = "Fabric" },
			BearD = { id = "rbxassetid://124603602803208", size = Vector3.new(3.8, 5.74, 1), center = Vector3.new(0.7, 3.62, -0), color = "mint", material = "Fabric" },
		},
	},
	ArcadeCabinet = {
		flip = true,
		parts = {
			Body = { id = "rbxassetid://115992810781912", size = Vector3.new(3, 6.4, 2.6), center = Vector3.new(0, 3.2, -0.1), color = "arcade", material = "SmoothPlastic" },
			Sides = { id = "rbxassetid://114198288970484", size = Vector3.new(3.24, 6.4, 2.8), center = Vector3.new(0, 3.3, -0.1), color = "ink", material = "SmoothPlastic" },
			Stripe = { id = "rbxassetid://96866862957441", size = Vector3.new(3.33, 1.1, 2.4), center = Vector3.new(0, 2.35, -0.1), color = "neonPink", material = "Neon" },
			Screen = { id = "rbxassetid://124334461350027", size = Vector3.new(2.4, 1.761, 0.451), center = Vector3.new(0, 4.3, 0.34), color = "neonCyan", material = "Neon" },
			Bezel = { id = "rbxassetid://108500899923476", size = Vector3.new(2.8, 2.152, 0.534), center = Vector3.new(0, 4.3, 0.28), color = "ink", material = "SmoothPlastic" },
			Marquee = { id = "rbxassetid://122723943991759", size = Vector3.new(2.8, 0.8, 0.14), center = Vector3.new(0, 5.95, 0.36), color = "neonPink", material = "Neon" },
			Deck = { id = "rbxassetid://113286141788067", size = Vector3.new(3, 0.456, 1.307), center = Vector3.new(0, 3.05, 0.75), color = "ink", material = "SmoothPlastic" },
			Stick = { id = "rbxassetid://119425489796093", size = Vector3.new(0.26, 0.68, 0.26), center = Vector3.new(-0.8, 3.49, 0.75), color = "red", material = "SmoothPlastic" },
			Buttons = { id = "rbxassetid://102734767406973", size = Vector3.new(1.56, 0.12, 0.62), center = Vector3.new(0.73, 3.24, 0.76), color = "yellow", material = "Neon" },
			Coin = { id = "rbxassetid://83328466770483", size = Vector3.new(0.9, 0.5, 0.08), center = Vector3.new(0, 1.8, 1.22), color = "metal", material = "Metal" },
		},
	},
	MoleMachine = {
		flip = true,
		parts = {
			Body = { id = "rbxassetid://102820704749933", size = Vector3.new(4, 2.8, 3), center = Vector3.new(0, 1.4, -0), color = "mintDark", material = "SmoothPlastic" },
			Deck = { id = "rbxassetid://128218457444956", size = Vector3.new(4.1, 0.701, 3.084), center = Vector3.new(0, 2.95, -0), color = "grassLight", material = "SmoothPlastic" },
			Holes = { id = "rbxassetid://133162414488223", size = Vector3.new(3.56, 0.262, 2.26), center = Vector3.new(0, 3.113, 0.05), color = "ink", material = "SmoothPlastic" },
			Moles = { id = "rbxassetid://106278354299632", size = Vector3.new(3.4, 1.082, 2.1), center = Vector3.new(0, 3.413, 0.05), color = "wood", material = "SmoothPlastic" },
			Noses = { id = "rbxassetid://83087729252220", size = Vector3.new(2.78, 0.362, 1.48), center = Vector3.new(0, 3.513, 0.43), color = "blush", material = "SmoothPlastic" },
			Back = { id = "rbxassetid://137731782321495", size = Vector3.new(4, 3, 0.3), center = Vector3.new(0, 4.6, -1.35), color = "mintDark", material = "SmoothPlastic" },
			Marquee = { id = "rbxassetid://93359324176948", size = Vector3.new(3.4, 1.4, 0.1), center = Vector3.new(0, 5, -1.16), color = "yellowSoft", material = "Neon" },
			Hammer = { id = "rbxassetid://72061925032500", size = Vector3.new(1.219, 1.069, 1.069), center = Vector3.new(2.04, 3.766, 0.734), color = "red", material = "SmoothPlastic" },
		},
	},
	PrizeCounter = {
		flip = true,
		parts = {
			Body = { id = "rbxassetid://90564445573835", size = Vector3.new(6, 3.2, 2), center = Vector3.new(0, 1.6, -0.1), color = "arcade", material = "SmoothPlastic" },
			Glass = { id = "rbxassetid://126198008359135", size = Vector3.new(5.4, 1.6, 0.3), center = Vector3.new(0, 2, 0.85), color = "glass", material = "Glass" },
			Neon = { id = "rbxassetid://107280358843548", size = Vector3.new(6.1, 2.82, 0.1), center = Vector3.new(0, 1.85, 1), color = "neonCyan", material = "Neon" },
			Top = { id = "rbxassetid://107086715146847", size = Vector3.new(6.2, 0.2, 2.3), center = Vector3.new(0, 3.4, -0.05), color = "ink", material = "SmoothPlastic" },
			PrizeA = { id = "rbxassetid://104423068799133", size = Vector3.new(4.6, 0.6, 0.6), center = Vector3.new(0, 1.75, 0.6), color = "blush", material = "SmoothPlastic" },
			PrizeB = { id = "rbxassetid://97362420189175", size = Vector3.new(2.6, 0.6, 0.4), center = Vector3.new(0, 1.7, 0.6), color = "yellow", material = "SmoothPlastic" },
			Tickets = { id = "rbxassetid://139527023003304", size = Vector3.new(0.3, 0.6, 0.6), center = Vector3.new(2.3, 3.65, 0.2), color = "red", material = "SmoothPlastic" },
		},
	},
	NeonSign = {
		flip = true,
		parts = {
			Star = { id = "rbxassetid://136210244231575", size = Vector3.new(2.462, 2.35, 0.18), center = Vector3.new(-2, 0.115, 0.14), color = "yellowSoft", material = "Neon" },
			Bolt = { id = "rbxassetid://122368769657341", size = Vector3.new(1.13, 2.579, 0.18), center = Vector3.new(0.025, -0, 0.14), color = "neonCyan", material = "Neon" },
			Heart = { id = "rbxassetid://73763682575965", size = Vector3.new(1.899, 1.783, 0.18), center = Vector3.new(2, -0.055, 0.14), color = "neonPink", material = "Neon" },
			Plate = { id = "rbxassetid://109442399157617", size = Vector3.new(6.4, 3, 0.08), center = Vector3.new(0, 0, 0.04), color = "ink", material = "SmoothPlastic" },
		},
	},
	ShopAwning = {
		flip = true,
		parts = {
			StripeA = { id = "rbxassetid://73502610880604", size = Vector3.new(11, 2.482, 4.026), center = Vector3.new(-0.5, -1.209, 2.027), color = "coral", material = "Fabric" },
			StripeB = { id = "rbxassetid://111146369630550", size = Vector3.new(11, 2.482, 4.026), center = Vector3.new(0.5, -1.209, 2.027), color = "cakeCream", material = "Fabric" },
			Arms = { id = "rbxassetid://79390418158872", size = Vector3.new(11.92, 1.82, 3.92), center = Vector3.new(0, -0.95, 2), color = "ink", material = "SmoothPlastic" },
		},
	},
	BladeSign = {
		flip = true,
		parts = {
			Bracket = { id = "rbxassetid://86178412016881", size = Vector3.new(2.74, 1.149, 0.4), center = Vector3.new(1.3, -0.375, -0), color = "ink", material = "SmoothPlastic" },
			Board = { id = "rbxassetid://112662927279423", size = Vector3.new(2.3, 2.3, 0.2), center = Vector3.new(1.75, -1.65, -0), color = "cakeCream", material = "SmoothPlastic" },
			Rim = { id = "rbxassetid://130548141397480", size = Vector3.new(2.56, 2.56, 0.26), center = Vector3.new(1.75, -1.65, -0), color = "ink", material = "SmoothPlastic" },
		},
	},
	ABoard = {
		flip = true,
		parts = {
			Frame = { id = "rbxassetid://75476218142301", size = Vector3.new(2.4, 3.896, 2.199), center = Vector3.new(0, 1.95, -0), color = "woodLight", material = "Wood" },
			Board = { id = "rbxassetid://126583847682196", size = Vector3.new(2, 2.911, 2.089), center = Vector3.new(0, 2.1, -0), color = "ink", material = "SmoothPlastic" },
			Chalk = { id = "rbxassetid://84337436983086", size = Vector3.new(1.3, 1.466, 0.394), center = Vector3.new(0, 2.325, 0.648), color = "cakeCream", material = "SmoothPlastic" },
		},
	},
	ShopDoor = {
		flip = true,
		parts = {
			Frame = { id = "rbxassetid://106250100012145", size = Vector3.new(10.8, 10.4, 0.6), center = Vector3.new(0, 5.2, -0), color = "ink", material = "SmoothPlastic" },
			Leaf = { id = "rbxassetid://88136340732579", size = Vector3.new(9.94, 9.8, 4.6), center = Vector3.new(0, 5, -2.5), color = "glass", material = "Glass" },
			LeafFrame = { id = "rbxassetid://95416446443801", size = Vector3.new(10, 9.95, 4.8), center = Vector3.new(0, 5.025, -2.5), color = "ink", material = "SmoothPlastic" },
			Handle = { id = "rbxassetid://103412388463502", size = Vector3.new(9.38, 2.74, 0.14), center = Vector3.new(0, 4.9, -4.2), color = "gold", material = "Metal" },
		},
	},
	ShopPlanter = {
		flip = true,
		parts = {
			Box = { id = "rbxassetid://136999314094559", size = Vector3.new(6, 1.3, 1.5), center = Vector3.new(0, 0.65, -0), color = "espresso", material = "SmoothPlastic" },
			Hedge = { id = "rbxassetid://103488868004921", size = Vector3.new(5.7, 1.3, 1.25), center = Vector3.new(0, 1.8, -0), color = "grass", material = "SmoothPlastic" },
			Flowers = { id = "rbxassetid://109478853897866", size = Vector3.new(5.16, 0.36, 0.86), center = Vector3.new(0, 2.5, -0), color = "blush", material = "SmoothPlastic" },
		},
	},
}
