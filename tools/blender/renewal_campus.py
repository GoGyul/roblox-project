# 회사 단지 통합 맵 블록아웃 (대충상사 + 눈치물산 + 6배 중앙 공원 + 가게 거리)
# 실행: /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/renewal_campus.py
# 좌표: x 동서(-240~240), z 남북(-150 큰길 ~ 135 눈치 스트리트). 공원은 x ±130 / z -110~70 (260×180칸).

import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import lib  # noqa: E402
import drafts_spaces as d  # noqa: E402
import drafts_texture as t  # noqa: E402
import office_kit_set as kit  # noqa: E402,F401
import renewal_daechung as rd  # noqa: E402
from lib import Furniture, R, ball, box, cyl, rod  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "salary", "renewal")
random.seed(7)
lib.PALETTE.update({"grass": (74, 128, 84), "grassLight": (104, 152, 100), "lawn": (132, 176, 118), "water": (128, 184, 214), "stone": (206, 202, 194), "coralSoft": (216, 190, 182)})


def bx(size, at, **kw):
    return box(size, at=at, r=0, **kw)


def M(name, rgb, rough=0.7, emit=0.0, kind="plain"):
    return t.tex("c_" + name, rgb, kind, rough, emit)


def ground():
    f = Furniture("Ground")
    f.zone("Pave", [bx((500, 1, 300), (0, -0.5, -8))], M("pave", (190, 186, 176), 0.9))
    f.zone("Lawn", [box((260, 0.3, 180), at=(0, 0.1, -20), rv=24, r=0)], M("lawn", (124, 170, 112), 0.95))
    f.zone("Road", [bx((500, 0.3, 26), (0, 0.1, -138)), bx((500, 0.3, 14), (0, 0.1, 98))], M("asphalt", (66, 68, 72), 0.95))
    f.zone("Lines", [bx((10, 0.32, 0.6), (x, 0.11, -138)) for x in range(-230, 231, 22)], M("yellowline", (226, 186, 70)))
    f.zone("Cross", [bx((1.8, 0.32, 22), (x + k * 3.4, 0.11, -138)) for x in (-150, 0, 150) for k in range(-3, 4)], M("white", (236, 236, 232)))
    # 공원 길: 둥근 광장 + 십자 큰길 + 바깥 순환로
    path = M("path", (226, 214, 190), 0.9)
    # (겹치는 길은 높이를 조금씩 달리해요: 같은 높이면 겹친 자리가 검게 떨려요)
    f.zone("Paths", [cyl(26, 0.42, at=(0, 0.2, -20), seg=48),
                     box((250, 0.34, 8), at=(0, 0.2, -20), r=0), box((8, 0.36, 172), at=(0, 0.2, -20), r=0),
                     box((200, 0.38, 6), at=(0, 0.2, -92), r=0), box((200, 0.38, 6), at=(0, 0.2, 52), r=0),
                     box((6, 0.4, 150), at=(-100, 0.2, -20), r=0), box((6, 0.4, 150), at=(100, 0.2, -20), r=0)], path)


def windows(f, name, face, x1, x2, y1, y2, fixed, step=13, w=9, h=9, floor_h=21, lit=()):
    """face: 창이 난 면 ("e" = +x, "w" = -x, "s" = +z, "n" = -z)."""
    glass, lit_m = M("glass", (120, 150, 172), 0.15), M("lit", (255, 240, 200), 0.2, 1.6)
    panes, glow = [], []
    k = 0
    y = y1
    while y + h <= y2:
        a = x1 + step / 2
        while a < x2:
            size = (0.4, h, w) if face in "ew" else (w, h, 0.4)
            at = (fixed, y + h / 2, a) if face in "ew" else (a, y + h / 2, fixed)
            (glow if k in lit else panes).append(bx(size, at))
            a += step
            k += 1
        y += floor_h
    f.zone(name, panes, glass)
    if glow:
        f.zone(name + "Lit", glow, lit_m)


def daechung():
    """서쪽: 낡은 4층 상가 건물 (x -232~-152 / z -110~10). 동쪽 면이 공원을 보고, 남쪽 1층이 골목 상가."""
    f = Furniture("Daechung")
    tile = M("facade", (198, 186, 164), 0.85)
    f.zone("Body", [bx((80, 84, 120), (-192, 42, -50))], tile)
    f.zone("Bands", [bx((81, 1.2, 121), (-192, 21 * k, -50)) for k in (1, 2, 3, 4)], M("band", (150, 140, 124)))
    windows(f, "WinE", "e", -106, 6, 25, 84, -151.8, lit=(9, 10, 12, 14))
    windows(f, "WinS", "s", -228, -156, 25, 84, 10.2)
    f.zone("Entrance", [bx((0.5, 12, 12), (-151.7, 7, -80))], M("lobby", (255, 236, 196), 0.2, 1.2))
    f.zone("Canopy", [bx((6, 0.8, 16), (-149, 14.4, -80))], M("canopy", (70, 76, 84)))
    f.zone("Shopfront", [bx((0.5, 12, 22), (-151.7, 7.5, z)) for z in (-40, -12)] + [bx((22, 12, 0.5), (x, 7.5, 10.3)) for x in (-216, -190, -164)], M("shopglass", (176, 206, 214), 0.1, 0.5))
    for i, (pos, color) in enumerate((((-150.9, 16.2, -40), (88, 150, 132)), ((-150.9, 16.2, -12), (196, 108, 92)))):
        f.zone(f"SignE{i}", [bx((1.2, 3.4, 22), pos)], M(f"sign{i}", color))
    for i, (x, color) in enumerate(((-216, (214, 174, 84)), (-190, (88, 150, 132)), (-164, (196, 108, 92)))):
        f.zone(f"SignS{i}", [bx((22, 3.4, 1.2), (x, 16.2, 10.9))], M(f"signs{i}", color))
    f.zone("AC", [box((1.8, 2.4, 3.2), at=(-150.9, 21 * k + 1.6, z), r=0.1, seg=1) for k in (1, 2, 3) for z in (-93, -54, -2)], M("ac", (214, 214, 208)))
    f.zone("Parapet", [bx((80, 3, 1), (-192, 85.5, 9.5)), bx((1, 3, 120), (-152.5, 85.5, -50))], tile)
    f.zone("Tank", [cyl(5, 7, at=(-176, 91.5, -30), seg=20)], M("tank", (220, 178, 70)))
    f.zone("Penthouse", [bx((16, 11, 14), (-200, 89.5, -80))], tile)
    f.zone("Name", [bx((0.6, 5, 30), (-151.4, 78, -50))], M("namesign", (44, 62, 92)))


def nunchi():
    """동쪽: 눈치물산 유리 사옥 타워 (x 152~232 / z -110~10, 높이 170). 서쪽 면이 공원을 보고, 남쪽이 사옥 앞 광장."""
    f = Furniture("Nunchi")
    f.zone("Tower", [bx((80, 170, 120), (192, 85, -50))], M("tower", (132, 164, 190), 0.12))
    steel = M("steel", (52, 56, 62), 0.4)
    f.zone("Grid", [bx((0.6, 170, 0.8), (151.6, 85, z)) for z in range(-110, 11, 12)] + [bx((0.6, 1, 120), (151.6, y, -50)) for y in range(22, 171, 11)]
           + [bx((0.8, 170, 0.6), (x, 85, 10.4)) for x in range(152, 233, 10)] + [bx((80, 1, 0.6), (192, y, 10.4)) for y in range(22, 171, 11)], steel)
    f.zone("Lobby", [bx((0.6, 20, 100), (151.5, 11, -50)), bx((60, 20, 0.6), (192, 11, 10.5))], M("lobbyglow", (255, 240, 214), 0.15, 1.0))
    f.zone("Canopy", [bx((10, 1, 40), (146, 21.5, -50)), bx((40, 1, 10), (192, 21.5, 15))], steel)
    f.zone("Crown", [bx((82, 4, 122), (192, 172, -50))], M("crown", (226, 226, 222)))
    f.zone("Logo", [bx((0.8, 9, 46), (151.2, 156, -50))], M("logo", (255, 250, 236), 0.3, 2.0))


def park():
    # 분수 광장 (한가운데)
    d.put(d.fountain(2.0), 0, -20)
    for k in range(8):
        a = math.radians(22.5 + 45 * k)
        d.put(d.bench(), 19 * math.cos(a), -20 + 19 * math.sin(a), rot=90 - math.degrees(a))
    for k in range(4):
        a = math.radians(90 * k + 45)
        d.put(d.lamp_post(), 27 * math.cos(a), -20 + 27 * math.sin(a)).root.scale = (2, 2, 2)
    # 연못과 다리 (북서)
    d.put(d.pond(60, 34), -60, -62)
    d.put(d.bridge(), -60, -62).root.scale = (2.2, 1.6, 2.9)
    for x, z in ((-92, -52), (-36, -44), (-72, -84), (-30, -80)):
        d.put(d.bench(), x, z, rot=random.choice((0, 90, 180)))
    # 잔디 광장과 야외무대 (북동)
    stage = Furniture("Stage")
    stage.zone("Deck", [box((36, 1.6, 18), at=(64, 0.8, -82), r=0.2, seg=1)], M("deck", (176, 142, 104), 0.6, 0, "wood"))
    stage.zone("Roof", [box((38, 0.8, 20), at=(64, 16, -82), r=0.2, seg=1)] + [bx((0.8, 15, 0.8), (64 + sx * 17, 8.4, -82 + sz * 8.5)) for sx in (-1, 1) for sz in (-1, 1)], M("steel", (52, 56, 62), 0.4))
    for x, z, r in ((48, -56, 10), (74, -52, -15), (92, -66, 20)):
        d.put(d.picnic(), x, z, rot=r)
    # 사탕 구역 (남서, 숲 뒤편): 지붕 있는 쉼터
    d.put(d.pergola("cream"), -70, 30).root.scale = (1.8, 1.4, 1.8)
    d.put(d.bench(), -70, 31, rot=180)
    # 내 화단 (남쪽 가운데): 텃밭 12칸
    for i in range(6):
        for j in range(2):
            d.put(d.planter(("coral", "yellow"), 8, "stone"), -28 + i * 11.2, 26 + j * 12)
    # 야외 식탁 (남동): 긴 식탁 줄 + 차양
    for i in range(3):
        d.put(d.pergola("coralSoft"), 52 + i * 22, 30).root.scale = (1.5, 1.3, 1.5)
        tbl = Furniture("LongTable")
        tbl.zone("Top", [box((12, 0.4, 4), at=(0, 2.6, 0), r=0.1, seg=1)], M("tabletop", (203, 172, 132), 0.5, 0, "wood"))
        tbl.zone("Seats", [box((12, 0.4, 1.4), at=(0, 1.5, sz * 3.2), r=0.1, seg=1) for sz in (-1, 1)], M("tableseat", (176, 142, 104), 0.5, 0, "wood"))
        d.put(tbl, 52 + i * 22, 30)
    # 꽃밭 · 가로등 · 순환로 벤치
    for x, z in ((-40, -6), (40, -6), (-40, -36), (40, -36), (0, -64), (0, 20), (-112, -92), (112, 52)):
        d.put(d.flower_bed(11, 7), x, z)
    for x in range(-110, 111, 44):
        for z in (-96, 56):
            d.put(d.lamp_post(), x, z).root.scale = (2, 2, 2)
    for z in range(-80, 41, 40):
        for x in (-104, 104):
            d.put(d.lamp_post(), x, z).root.scale = (2, 2, 2)
            d.put(d.bench(), x * 0.93, z + 10, rot=90 if x < 0 else -90)
    # 나무: 가장자리는 빽빽하게, 남서쪽은 숲, 안쪽은 드문드문
    spots = [(x, -104) for x in range(-120, 121, 20)] + [(x, 64) for x in range(-120, 121, 20)] + [(-124, z) for z in range(-90, 61, 22)] + [(124, z) for z in range(-90, 61, 22)]
    spots += [(-112 + random.uniform(0, 62), 4 + random.uniform(0, 54)) for _ in range(22)]  # 숲
    spots += [(random.uniform(-110, 110), random.uniform(-98, 58)) for _ in range(30)]
    kept = []
    for x, z in spots:
        clear = math.hypot(x, z + 20) > 34 and abs(x) > 7 and abs(z + 20) > 7 and math.hypot(x + 60, (z + 62) * 1.7) > 36
        clear = clear and not (36 < x < 100 and -96 < z < -44) and not (-36 < x < 40 and 18 < z < 46) and not (40 < x < 110 and 20 < z < 42) and not (-84 < x < -56 and 20 < z < 42)
        if clear and all(math.hypot(x - a, z - b) > 9 for a, b in kept):
            kept.append((x, z))
            d.put(d.tree(random.uniform(1.4, 2.2)), x, z, rot=random.uniform(0, 360))
    for _ in range(26):
        x, z = random.uniform(-122, 122), random.uniform(-102, 62)
        if math.hypot(x, z + 20) > 30 and abs(x) > 8:
            d.put(d.bush(random.uniform(1.2, 2.0)), x, z)


def shops_and_streets():
    # 눈치 스트리트 (남쪽): 가게 9칸 + 위층
    f = Furniture("Street")
    colors = [(88, 150, 132), (196, 108, 92), (214, 174, 84), (104, 128, 176), (150, 110, 170), (196, 108, 92), (88, 150, 132), (214, 174, 84), (104, 128, 176)]
    f.zone("Upper", [bx((470, 44, 26), (0, 36, 122))], M("shopblock", (204, 196, 182), 0.85))
    f.zone("ShopGlass", [bx((44, 11, 0.5), (-208 + i * 52, 6.5, 108.8)) for i in range(9)], M("shopglass", (176, 206, 214), 0.1, 0.6))
    f.zone("Pillars", [bx((5, 14, 27), (-234 + i * 52, 7, 122)) for i in range(10)], M("shopblock", (204, 196, 182), 0.85))
    for i, c in enumerate(colors):
        f.zone(f"Sign{i}", [bx((40, 4, 1.2), (-208 + i * 52, 15.6, 108.4))], M(f"st{i}", c))
        f.zone(f"Awn{i}", [bx((42, 0.4, 5), (-208 + i * 52, 12.6, 106), rot=R((1, 0, 0), 14))], M(f"aw{i}", tuple(min(255, int(v * 1.15)) for v in c)))
    windows(f, "WinN", "n", -232, 232, 20, 58, 108.8, step=14, w=9, h=7, floor_h=11)
    # 골목 상가 (대충상사 남쪽) · 푸드트럭 (사옥 앞 광장)
    for i, x in enumerate((-222, -196, -170)):
        d.put(d.stall(("coral", "yellow", "mint")[i]), x, 40, rot=0).root.scale = (2, 1.6, 2)
    for i, (x, color) in enumerate(((170, (196, 108, 92)), (200, (88, 150, 132)))):
        truck = Furniture("Truck")
        truck.zone("Body", [box((20, 9, 9), at=(0, 6, 0), r=0.6, seg=3), box((6, 6, 8.6), at=(-12.6, 4.5, 0), r=0.8, seg=3)], M(f"truck{i}", color, 0.4))
        truck.zone("Hatch", [bx((12, 4, 0.4), (1, 7, -4.7)), bx((12, 0.4, 5), (1, 10.4, -6.6), rot=R((1, 0, 0), -18))], M("hatch", (250, 246, 236)))
        truck.zone("Wheels", [cyl(1.6, 1.2, at=(sx, 1.6, sz * 4.2), axis="z", seg=16) for sx in (-11, 6) for sz in (-1, 1)], M("tire", (40, 40, 44)))
        d.put(truck, x, 48, rot=180)
    for x, z in ((176, 30), (196, 34), (216, 30)):
        d.put(d.parasol_table(("yellow", "coral", "mint")[int(x) % 3]), x, z).root.scale = (1.6, 1.4, 1.6)


def road_things():
    for i, x in enumerate((-150, 0, 150)):
        stop = Furniture("BusStop")
        stop.zone("Frame", [bx((0.4, 9, 0.4), (sx * 7, 4.5, sz)) for sx in (-1, 1) for sz in (-1.6, 1.6)] + [bx((16, 0.4, 5), (0, 9.2, 0))], M("canopy", (70, 76, 84)))
        stop.zone("Glass", [bx((14, 6.5, 0.2), (0, 4.6, 1.6))], M("stopglass", (190, 214, 226), 0.1))
        d.put(stop, x + 20, -118)
        d.put(d.bench(), x + 20, -117.4, rot=0)
    for x, z, c, r in ((-80, -132, (226, 226, 222), 0), (60, -144, (70, 110, 170), 180), (190, -132, (196, 80, 70), 0)):
        car = Furniture("Car")
        car.zone("Body", [box((16, 3.2, 7), at=(0, 2.6, 0), r=0.6, seg=3), box((9, 2.8, 6.4), at=(-0.6, 5.2, 0), r=0.7, seg=3)], M(f"car{x}", c, 0.35))
        car.zone("Wheels", [cyl(1.3, 1.0, at=(sx * 5, 1.3, sz * 3.2), axis="z", seg=16) for sx in (-1, 1) for sz in (-1, 1)], M("tire", (40, 40, 44)))
        d.put(car, x, z, rot=r)
    bus = Furniture("Bus")
    bus.zone("Body", [box((34, 10, 9), at=(0, 6.5, 0), r=0.8, seg=3)], M("bus", (70, 150, 110), 0.4))
    bus.zone("Glass", [box((30, 4, 9.2), at=(0, 8, 0), r=0.3, seg=2)], M("busglass", (50, 62, 74), 0.1))
    bus.zone("Wheels", [cyl(1.7, 1.2, at=(sx * 11, 1.7, sz * 4.2), axis="z", seg=16) for sx in (-1, 1) for sz in (-1, 1)], M("tire", (40, 40, 44)))
    d.put(bus, -14, -131)
    # 지하철 출구 · 경비 초소 · 뒤쪽 도시
    sub = Furniture("Subway")
    sub.zone("Canopy", [bx((12, 0.6, 20), (0, 9, 0)), bx((0.5, 9, 0.5), (-5.5, 4.5, -9)), bx((0.5, 9, 0.5), (5.5, 4.5, -9)), bx((0.6, 4, 20), (-5.8, 2, 0)), bx((0.6, 4, 20), (5.8, 2, 0))], M("canopy", (70, 76, 84)))
    sub.zone("Sign", [bx((8, 2.4, 0.4), (0, 10.6, -9.8))], M("subsign", (60, 110, 190)))
    d.put(sub, 96, -112)
    for x, z in ((-140, -96), (140, 60), (-140, 74)):
        booth = Furniture("Booth")
        booth.zone("Box", [box((6, 8, 6), at=(0, 4, 0), r=0.2, seg=1)], M("booth", (232, 230, 225)))
        booth.zone("Glass", [bx((4.4, 3, 6.1), (0, 5, 0))], M("boothglass", (150, 180, 200), 0.1))
        booth.zone("Roof", [bx((7.4, 0.5, 7.4), (0, 8.2, 0))], M("canopy", (70, 76, 84)))
        d.put(booth, x, z)
    city = Furniture("City")
    for i, (x, z, w, dp, h, c) in enumerate(((-150, -210, 120, 60, 110, (176, 170, 160)), (10, -216, 140, 60, 150, (160, 168, 176)), (170, -208, 110, 60, 96, (186, 178, 168)),
                                               (-270, -60, 50, 140, 70, (170, 166, 158)), (272, -40, 50, 160, 120, (158, 166, 176)), (-270, 90, 50, 110, 90, (176, 172, 166)), (272, 100, 50, 90, 76, (182, 176, 166)))):
        city.zone(f"B{i}", [bx((w, h, dp), (x, h / 2, z))], M(f"city{i}", c, 0.85))
    for x, z, s, yaw in ((-146, -76, (230, 232, 236), 90), (-120, -30, (150, 164, 190), -90), (-10, -8, (206, 170, 150), 40), (12, -36, (196, 208, 226), 200), (60, -60, (230, 200, 160), 10),
                         (146, -44, (70, 84, 110), -90), (-60, 34, (214, 190, 170), 0), (184, 38, (230, 232, 236), 0), (-80, 100, (150, 164, 190), 90), (30, 102, (206, 170, 150), -90), (20, -121, (230, 232, 236), 180)):
        rd.person(x, z, s, yaw=yaw)


if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    lib.reset()
    os.makedirs(OUT, exist_ok=True)
    lib.PALETTE["ground"] = (150, 150, 146)
    ground()
    daechung()
    nunchi()
    park()
    shops_and_streets()
    road_things()
    shots = {
        "campus_aerial": dict(eye=(24, 470, 210), target=(0, 0, -14), lens=30, width=2200, height=1400),
        "campus_from_daechung": dict(eye=(-138, 9, -40), target=(150, 64, -50), lens=22, width=1900, height=1100),
        "campus_park": dict(eye=(-34, 8, 16), target=(60, 30, -70), lens=22, width=1900, height=1100),
        "campus_street": dict(eye=(-150, 8, 92), target=(40, 12, 104), lens=22, width=1900, height=1100),
    }
    for name, shot in shots.items():
        if only and name not in only:
            continue
        lib.render(os.path.join(OUT, name + ".png"), floor="ground", samples=48, sun=2.0, world=0.7, sun_rot=(50, 0, 205), **shot)
        print("RENDERED", name)
    print("DONE")
