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
}
