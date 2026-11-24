# 공간 디자인 초안 (사무실·옥상·공원 각 2안) — 게임에 넣기 전, 분위기를 고르기 위한 블록아웃 렌더
# 실행: /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/drafts_spaces.py

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402

import lib  # noqa: E402
import office_desk_set as desk_set  # noqa: E402
from lib import Furniture, R, ball, boolean, box, cyl, lathe, rod  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "salary", "drafts")

lib.PALETTE.update({
    "floorWarm": (241, 228, 216),
    "floorCool": (226, 232, 233),
    "lawn": (160, 216, 150),
    "stone": (233, 226, 214),
    "skyline": (166, 210, 236),
    "water": (140, 212, 245),
})


def put(f, x, z, rot=0, y=0):
    f.place(x, y, z)
    f.root.rotation_euler = (0, 0, math.radians(rot))
    return f


def recolor(f, colors):
    for child in f.root.children:
        zone = child.name.split("_", 1)[1].split(".")[0]
        if zone in colors:
            child.data.materials[0] = lib._material(colors[zone], "SmoothPlastic")
    return f


def clear():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)


# ── 실내 ──────────────────────────────────────────────

def floor(w, d, color, x=0, z=0, y=0.02):
    f = Furniture("Floor")
    f.zone("Slab", [box((w, 0.1, d), at=(x, y, z), r=0)], color)
    return f


def workstation(x, z, partition="sage", chair="coral"):
    put(recolor(desk_set.build_desk(), {"Partition": partition}), x, z)
    put(desk_set.build_monitor(), x, z)
    put(desk_set.build_drawer(), x + 2.6, z + 0.3)
    put(desk_set.build_lamp(), x - 3.1, z - 1, y=2.56)
    put(recolor(desk_set.build_chair(), {"Seat": chair, "Back": chair}), x, z + 3.3)


def window_wall(width, z, x=0):
    f = Furniture("WindowWall")
    n = int(width // 9)
    pane = width / n
    glass, frame, city = [], [box((width, 1.6, 0.6), at=(0, 0.8, 0), r=0.1), box((width, 1.2, 0.6), at=(0, 10.2, 0), r=0.1)], []
    for i in range(n):
        cx = -width / 2 + pane * (i + 0.5)
        glass.append(box((pane - 0.5, 8, 0.2), at=(cx, 5.6, 0), r=0))
        for k, (dx, h) in enumerate(((-2.6, 3.4), (-0.6, 5.2), (1.4, 2.6), (3, 4.2))):
            city.append(box((1.5, h, 0.1), at=(cx + dx * pane / 9, 1.6 + h / 2, 0.16), r=0))
    for i in range(n + 1):
        frame.append(box((0.5, 10, 0.7), at=(-width / 2 + pane * i, 5.4, 0), r=0.12))
    f.zone("Glass", glass, "skySoft")
    f.zone("City", city, "skyline")
    f.zone("Frame", frame, "surface")
    return put(f, x, z)


def slat_wall(width, color="woodLight", slat="wood"):
    f = Furniture("SlatWall")
    f.zone("Panel", [box((width, 10.8, 0.4), at=(0, 5.4, 0), r=0.05)], color)
    f.zone("Slats", [box((0.35, 10.8, 0.3), at=(-width / 2 + 0.6 + i * 0.95, 5.4, 0.3), r=0.08) for i in range(int((width - 0.8) / 0.95) + 1)], slat)
    return f


def plain_wall(width, color="cream"):
    f = Furniture("Wall")
    f.zone("Panel", [box((width, 10.8, 0.5), at=(0, 5.4, 0), r=0.05)], color)
    return f


def bookshelf():
    f = Furniture("Bookshelf")
    body = box((5.2, 11, 1.6), at=(0, 3, 0), axis="z", rv=2.5, r=0.12)  # 아래 둥근 부분은 바닥에서 잘라요
    f.zone("Body", [boolean(body, box((8, 6, 4), at=(0, -3, 0), r=0))], "woodLight")
    f.zone("Niche", [box((4.2, 4.6, 0.2), at=(0, 5.6, 0.75), axis="z", rv=2.0, r=0)], "cream")
    f.zone("Shelf", [box((4.2, 0.2, 0.9), at=(0, 5.2, 0.6), r=0.05), box((4.2, 0.2, 0.9), at=(0, 3.3, 0.6), r=0.05)], "wood")
    books = [("coral", -1.4, 1.5), ("sky", -0.95, 1.8), ("yellow", -0.5, 1.4), ("mint", -0.05, 1.7)]
    for color, x, h in books:
        f.zone("Book" + color, [box((0.38, h, 0.7), at=(x, 5.3 + h / 2, 0.7), r=0.05)], color)
    f.zone("Box", [box((1.3, 0.9, 0.8), at=(1.1, 5.75, 0.7), r=0.12)], "coralSoft")
    f.zone("Doors", [box((1.95, 2.7, 0.16), at=(sx * 1.05, 1.6, 0.82), r=0.1) for sx in (-1, 1)], "surface")
    f.zone("Handles", [box((0.14, 0.8, 0.14), at=(sx * 0.3, 1.7, 0.95), r=0.06) for sx in (-1, 1)], "wood")
    return f


def sofa(color="mint", pillow="yellow", width=6.0):
    f = Furniture("Sofa")
    f.zone("Base", [box((width, 1.0, 2.6), at=(0, 0.75, 0), rv=0.6, r=0.25)], "surface")
    f.zone("Cushion", [
        box((width - 0.4, 0.7, 2.2), at=(0, 1.5, 0.1), rv=0.5, r=0.28),
        box((width, 1.9, 0.9), at=(0, 2.1, -0.95), axis="x", rv=0.4, r=0.3),
    ], color, "Fabric")
    f.zone("Pillow", [box((1.1, 1.0, 0.5), at=(width / 2 - 1.2, 2.3, -0.3), r=0.22, rot=R((1, 0, 0), -15))], pillow, "Fabric")
    return f


def rug(radius, color="mintSoft"):
    f = Furniture("Rug")
    f.zone("Rug", [cyl(radius, 0.08, at=(0, 0.1, 0), seg=48)], color)
    return f


def table_round(top="woodLight"):
    f = Furniture("RoundTable")
    f.zone("Top", [cyl(1.5, 0.22, at=(0, 1.3, 0), bevel=0.08)], top)
    f.zone("Leg", [cyl(0.25, 1.2, at=(0, 0.6, 0)), cyl(0.8, 0.12, at=(0, 0.06, 0), bevel=0.04)], "surface")
    return f


def vending(color="mint"):
    f = Furniture("Vending")
    f.zone("Body", [box((3, 6.2, 2.4), at=(0, 3.1, 0), rv=0.4, r=0.15)], color)
    f.zone("Window", [box((1.9, 3.6, 0.12), at=(-0.3, 3.9, 1.2), axis="z", rv=0.2, r=0)], "surfaceSoft")
    colors = ("coral", "yellow", "sky")
    for c in colors:  # 상품은 색별로 한 메시
        f.zone("Items" + c, [box((0.4, 0.6, 0.12), at=(-0.9 + col * 0.6, y, 1.26), r=0.05)
                              for row, y in enumerate((5.0, 4.0, 3.0)) for col in range(3) if colors[(row + col) % 3] == c], c)
    f.zone("Panel", [box((0.5, 1.4, 0.12), at=(1.1, 4.6, 1.22), r=0.05), box((2.2, 0.8, 0.12), at=(-0.2, 1.1, 1.22), r=0.1)], "mintDark")
    return f


def printer():
    f = Furniture("Printer")
    f.zone("Body", [box((3, 2.4, 2.4), at=(0, 1.5, 0), rv=0.35, r=0.15), box((3.1, 0.9, 2.5), at=(0, 3.1, 0), rv=0.35, r=0.15)], "surface")
    f.zone("Tray", [box((2.2, 0.15, 1.2), at=(0, 2.75, 1.4), r=0.05), box((2.4, 0.5, 0.1), at=(0, 1.2, 1.22), r=0.04)], "line")
    f.zone("Eyes", [ball(0.28, at=(sx * 0.5, 1.9, 1.2)) for sx in (-1, 1)], "navy")
    f.zone("Wheels", [ball(0.4, at=(sx * 1.1, 0.2, sz * 0.9)) for sx in (-1, 1) for sz in (-1, 1)], "navy")
    return f


def meeting_pod(color="coral"):
    f = Furniture("Pod")
    f.zone("Ring", [cyl(4.6, 0.3, at=(0, 0.15, 0), seg=40), cyl(4.7, 0.5, at=(0, 7.6, 0), seg=40, bevel=0.15)], color)
    f.zone("Posts", [rod((4.4 * math.cos(a), 0.3, 4.4 * math.sin(a)), (4.4 * math.cos(a), 7.4, 4.4 * math.sin(a)), 0.12) for a in [math.radians(20 + 40 * k) for k in range(9)]], "surface")
    f.zone("Table", [cyl(1.6, 0.2, at=(0, 2.2, 0), bevel=0.07), cyl(0.25, 2.1, at=(0, 1.1, 0))], "woodLight")
    f.zone("Seats", [box((1.3, 1.9, 1.3), at=(2.6 * math.cos(a), 0.95, 2.6 * math.sin(a)), rv=0.5, r=0.3) for a in [math.radians(60 + 120 * k) for k in range(3)]], color)
    f.zone("Lamp", [ball((1.6, 0.9, 1.6), at=(0, 6.4, 0))], "yellowSoft", "Neon")
    return f


def reception():
    f = Furniture("Reception")
    f.zone("Body", [cyl(3.2, 2.5, at=(0, 1.35, 0), seg=40)], "woodLight")
    f.zone("Top", [cyl(3.4, 0.25, at=(0, 2.72, 0), seg=40, bevel=0.08)], "surface")
    f.zone("Glow", [cyl(3.25, 0.2, at=(0, 0.1, 0), seg=40)], "yellowSoft", "Neon")
    return f


def lockers():
    f = Furniture("Lockers")
    for i, color in enumerate(("mint", "yellow", "sky", "coral")):
        f.zone(f"Door{i}", [box((1.5, 5.6, 1.6), at=(-2.4 + i * 1.6, 2.9, 0), r=0.15)], color)
    f.zone("Vents", [box((0.8, 0.12, 0.1), at=(-2.4 + i * 1.6, 4.8 - k * 0.3, 0.82), r=0.03) for i in range(4) for k in range(3)], "surface")
    return f


def floor_plant(scale=1.0):
    f = desk_set.build_plant()
    f.root.scale = (scale, scale, scale)
    return f


# ── 야외 ──────────────────────────────────────────────

def tree(s=1.0):
    f = Furniture("Tree")
    f.zone("Trunk", [cyl(0.5 * s, 3.4 * s, at=(0, 1.7 * s, 0), r2=0.35 * s, seg=10)], "woodDark")
    f.zone("Canopy", [ball(5.2 * s, at=(0, 5.4 * s, 0), seg=10), ball(3.6 * s, at=(-1.8 * s, 4.5 * s, 0.6 * s), seg=10)], "grass", smooth_angle=5)
    f.zone("CanopyLight", [ball(3.6 * s, at=(1.6 * s, 4.7 * s, -0.5 * s), seg=10), ball(3.3 * s, at=(0.3 * s, 7 * s, 0.4 * s), seg=10)], "grassLight", smooth_angle=5)
    return f


def bush(s=1.0):
    f = Furniture("Bush")
    f.zone("Leaves", [ball((2.4 * s, 1.8 * s, 2.2 * s), at=(0, 0.8 * s, 0), seg=10), ball(1.6 * s, at=(1.1 * s, 0.7 * s, 0.3 * s), seg=10)], "grass", smooth_angle=5)
    return f


def bench():
    f = Furniture("Bench")
    f.zone("Seat", [box((4.2, 0.22, 0.5), at=(0, 1.35, z), r=0.08) for z in (-0.5, 0.05, 0.6)], "woodLight")
    f.zone("Back", [box((4.2, 0.45, 0.2), at=(0, y, -0.85), r=0.08, rot=R((1, 0, 0), -10)) for y in (1.9, 2.5)], "wood")
    f.zone("Legs", [box((0.3, 1.3, 1.8), at=(sx * 1.7, 0.65, 0), r=0.1) for sx in (-1, 1)], "navySoft")
    return f


def fountain(s=1.0):
    f = Furniture("Fountain")
    f.zone("Stone", [
        lathe([(0, 0), (3.6 * s, 0), (3.8 * s, 0.25), (3.8 * s, 1.0), (3.6 * s, 1.15), (3.2 * s, 1.15), (3.1 * s, 0.5), (0, 0.5)], seg=40),
        cyl(0.45 * s, 2.4, at=(0, 1.6, 0)),
        lathe([(0, 2.6), (1.5 * s, 2.9), (1.7 * s, 3.2), (1.4 * s, 3.2), (0, 3.0)], seg=32),
    ], "stone")
    f.zone("Water", [cyl(3.15 * s, 0.3, at=(0, 0.85, 0), seg=40), cyl(1.4 * s, 0.1, at=(0, 3.15, 0), seg=32)], "water")
    jets = [ball((0.5, 1.6, 0.5), at=(0, 3.9, 0))]
    for k in range(6):
        a = math.radians(60 * k)
        jets.append(rod((0.9 * s * math.cos(a), 3.2, 0.9 * s * math.sin(a)), (2.3 * s * math.cos(a), 1.3, 2.3 * s * math.sin(a)), 0.16))
    f.zone("Jets", jets, "skySoft")
    return f


def stall(awning="coral"):
    f = Furniture("Stall")
    f.zone("Counter", [box((6, 2.4, 1.8), at=(0, 1.2, 0), r=0.15)], "woodLight")
    f.zone("Top", [box((6.4, 0.25, 2.2), at=(0, 2.5, 0), r=0.1)], "wood")
    f.zone("Posts", [box((0.3, 6, 0.3), at=(sx * 2.9, 3, sz * 0.85), r=0.08) for sx in (-1, 1) for sz in (-1, 1)], "wood")
    roof = R((1, 0, 0), 14)
    f.zone("Awning", [box((0.95, 0.2, 3.4), at=(-2.85 + i * 1.9, 6.1, 0.3), r=0.06, rot=roof) for i in range(4)]
           + [box((0.95, 0.7, 0.2), at=(-2.85 + i * 1.9, 5.45, 1.95), r=0.08) for i in range(4)], awning)
    f.zone("AwningWhite", [box((0.95, 0.2, 3.4), at=(-1.9 + i * 1.9, 6.1, 0.3), r=0.06, rot=roof) for i in range(3)]
           + [box((0.95, 0.7, 0.2), at=(-1.9 + i * 1.9, 5.45, 1.95), r=0.08) for i in range(3)], "surface")
    f.zone("Goods", [cyl(0.3, 0.7, at=(-1.8, 3.0, 0.2), bevel=0.05), cyl(0.3, 0.7, at=(-1.0, 3.0, 0.2), bevel=0.05)], "mint")
    f.zone("Machine", [box((1.4, 1.2, 1.1), at=(1.5, 3.2, 0), r=0.15)], "navySoft")
    f.zone("Stools", [cyl(0.55, 0.3, at=(x, 1.5, 1.9), bevel=0.1) for x in (-1.8, 0, 1.8)] , "yellow")
    f.zone("StoolLegs", [cyl(0.12, 1.4, at=(x, 0.7, 1.9)) for x in (-1.8, 0, 1.8)], "surface")
    return f


def pergola(canopy="cream"):
    f = Furniture("Pergola")
    f.zone("Deck", [box((9.6, 0.4, 7.6), at=(0, 0.2, 0), r=0.1)], "wood")
    f.zone("Frame", [box((0.4, 7, 0.4), at=(sx * 4.4, 3.8, sz * 3.4), r=0.08) for sx in (-1, 1) for sz in (-1, 1)]
           + [box((9.6, 0.4, 0.4), at=(0, 7.3, sz * 3.4), r=0.08) for sz in (-1, 1)]
           + [box((0.4, 0.4, 7.6), at=(sx * 4.4, 7.3, 0), r=0.08) for sx in (-1, 1)], "navySoft")
    f.zone("Canopy", [box((8.8, 0.15, 2.0), at=(0, 7.45 - 0.25 * abs(k), k * 2.2), r=0.05) for k in (-1, 0, 1)], canopy)
    f.zone("Lights", [ball(0.35, at=(-3.9 + k * 1.3, 6.75 - 0.5 * math.sin(math.pi * k / 6), 3.4)) for k in range(7)], "yellowSoft", "Neon")
    return f


def pod_chair():
    f = Furniture("PodChair")
    shell = boolean(ball(4.2, at=(0, 2.3, 0), seg=32), ball(3.6, at=(0, 2.5, 0.9), seg=32))
    f.zone("Shell", [shell], "cream")
    f.zone("Cushion", [ball((2.9, 1.1, 2.4), at=(0, 1.3, 0.3)), ball((2.2, 1.5, 0.8), at=(0, 2.3, -0.9))], "yellow")
    return f


def planter(flowers=("coral", "yellow"), width=5.0, color="stone"):
    f = Furniture("Planter")
    f.zone("Box", [box((width, 1.3, 1.8), at=(0, 0.65, 0), r=0.18)], color)
    n = int(width / 1.1)
    f.zone("Leaves", [ball((1.4, 1.2, 1.4), at=(-width / 2 + 0.8 + i * (width - 1.6) / max(n - 1, 1), 1.5, 0), seg=10) for i in range(n)], "grass", smooth_angle=5)
    for j, c in enumerate(flowers):
        f.zone("Flower" + c, [ball(0.42, at=(-width / 2 + 0.8 + i * (width - 1.6) / max(n - 1, 1) + (0.3 if j else -0.3), 2.1, 0.3 if j else -0.2), seg=10) for i in range(n)], c)
    return f


def lamp_post():
    f = Furniture("LampPost")
    f.zone("Pole", [cyl(0.16, 5.4, at=(0, 2.7, 0)), cyl(0.5, 0.2, at=(0, 0.1, 0), bevel=0.06)], "navySoft")
    f.zone("Bulb", [ball(1.1, at=(0, 5.8, 0))], "yellowSoft", "Neon")
    return f


def parasol_table(color="yellow"):
    f = Furniture("Parasol")
    f.zone("Table", [cyl(1.5, 0.2, at=(0, 2.2, 0), bevel=0.07)], "surface")
    f.zone("Pole", [cyl(0.12, 6.6, at=(0, 3.3, 0)), cyl(0.7, 0.2, at=(0, 0.1, 0), bevel=0.06)], "navySoft")
    f.zone("Shade", [lathe([(0, 7.0), (3.3, 5.9), (3.2, 5.7), (0, 6.3)], seg=8)], color, smooth_angle=5)
    f.zone("Stools", [cyl(0.6, 1.3, at=(2.3 * math.cos(a), 0.65, 2.3 * math.sin(a)), bevel=0.2) for a in (0.6, 2.7, 4.6)], "coral")
    return f


def railing(width):
    f = Furniture("Railing")
    f.zone("Rail", [box((width, 0.3, 0.3), at=(0, 3.3, 0), r=0.1)] + [box((0.3, 3.3, 0.3), at=(-width / 2 + i * 6, 1.65, 0), r=0.08) for i in range(int(width / 6) + 1)], "surface")
    f.zone("Glass", [box((width, 2.4, 0.1), at=(0, 1.6, 0), r=0)], "skySoft")
    return f


def skyline(width, z):
    f = Furniture("Skyline")
    heights = (10, 16, 8, 13, 19, 9, 14, 11, 17, 7, 12)
    f.zone("Far", [box((width / len(heights) * 0.8, h, 3), at=(-width / 2 + (i + 0.5) * width / len(heights), h / 2 - 8.3, 0), r=0) for i, h in enumerate(heights)], "skyline")
    return put(f, 0, z)


def pond(w, d):
    f = Furniture("Pond")
    f.zone("Edge", [ball((w + 1.2, 0.5, d + 1.2), at=(0, 0, 0), seg=32)], "stone")
    f.zone("Water", [ball((w, 0.62, d), at=(0, 0, 0), seg=32)], "water")
    f.zone("Lily", [ball((1.0, 0.75, 1.0), at=(x, 0, z), seg=12) for x, z in ((-w / 5, d / 6), (w / 6, -d / 5), (w / 4, d / 5))], "grassLight")
    return f


def stones(points):
    f = Furniture("Stones")
    f.zone("Stone", [ball((1.9, 0.3, 1.5), at=(x, 0.08, z), rot=R((0, 1, 0), 20 * i), seg=12) for i, (x, z) in enumerate(points)], "stone")
    return f


def flower_bed(w, d, colors=("coral", "yellow", "surface")):
    f = Furniture("FlowerBed")
    f.zone("Soil", [ball((w, 0.7, d), at=(0, 0.05, 0), seg=24)], "woodDark")
    pts = [(w * 0.36 * math.cos(a) * r, d * 0.36 * math.sin(a) * r) for r in (0.45, 1.0) for a in [math.radians(k * 45 + r * 20) for k in range(8)]]
    f.zone("Leaves", [ball(0.9, at=(x, 0.6, z), seg=8) for x, z in pts], "grass", smooth_angle=5)
    for j, c in enumerate(colors):
        f.zone("Flower" + c, [ball(0.5, at=(x, 1.1, z), seg=8) for i, (x, z) in enumerate(pts) if i % len(colors) == j], c)
    return f


def flower_bed_default():
    return flower_bed(7, 4.5)


def picnic():
    f = Furniture("Picnic")
    f.zone("Mat", [box((5, 0.08, 3.6), at=(0, 0.1, 0), r=0.03)], "coral")
    f.zone("Stripes", [box((0.5, 0.09, 3.6), at=(x, 0.11, 0), r=0.03) for x in (-1.6, 0, 1.6)], "surface")
    f.zone("Basket", [box((1.3, 0.9, 1.0), at=(1.2, 0.6, 0.6), r=0.2)], "wood")
    return f


def bridge():
    f = Furniture("Bridge")
    f.zone("Deck", [box((3, 0.3, 1.05), at=(0, 0.75, k * 1.15), r=0.08) for k in range(-5, 6)], "woodLight")
    f.zone("Rails", [rod((sx * 1.4, 2.2, -6.2), (sx * 1.4, 2.2, 6.2), 0.14) for sx in (-1, 1)]
           + [rod((sx * 1.4, 0.7, z), (sx * 1.4, 2.2, z), 0.12) for sx in (-1, 1) for z in (-6.2, -2, 2, 6.2)], "wood")
    return f


def path(points, width=3.4, color="stone"):
    f = Furniture("Path")
    segs = []
    for (x1, z1), (x2, z2) in zip(points, points[1:]):
        length = math.hypot(x2 - x1, z2 - z1) + width
        angle = math.degrees(math.atan2(-(z2 - z1), x2 - x1))
        segs.append(box((length, 0.12, width), at=((x1 + x2) / 2, 0.06 + 0.006 * len(segs), (z1 + z2) / 2), rv=width / 2 - 0.05, r=0, rot=R((0, 1, 0), angle)))
    f.zone("Paving", segs, color)
    return f


# ── 장면 ──────────────────────────────────────────────

def office_walls(left, back_color="cream"):
    window_wall(56, -20)
    put(left, -28, 0, rot=90)


def office_a():
    """민트 가든: 세이지 파티션 + 원목 슬랫 벽 + 식물 가득"""
    floor(56, 40, "floorWarm")
    window_wall(56, -20)
    put(slat_wall(40), -28, 0, rot=90)
    for x in (-13, 1, 15):
        workstation(x, -9)
        workstation(x, 5)
    put(bookshelf(), -26.8, -13, rot=90)
    put(bookshelf(), -26.8, -6.5, rot=90)
    put(rug(6, "mintSoft"), -19, 12)
    put(sofa("mint", "yellow"), -23.5, 12, rot=90)
    put(table_round(), -18.5, 12)
    put(floor_plant(1.6), -25, 17.5)
    put(floor_plant(1.3), -25.5, -18)
    put(floor_plant(1.4), 25.5, -18)
    put(planter(("coral", "yellow"), 6, "woodLight"), 23, 9, rot=90)
    put(printer(), 19, -17)
    put(vending("mint"), 24, -17.5)
    for x in (-6, 8):
        put(floor_plant(1.0), x, -17.5)


def office_b():
    """코랄 라운지: 유리 회의 부스 + 실내 카페 + 락커, 포인트 색이 더 많아요"""
    floor(56, 40, "floorCool")
    window_wall(56, -20)
    put(plain_wall(40, "surface"), -28, 0, rot=90)
    put(rug(13, "skySoft"), 1, -2)
    for x in (-13, 1, 15):
        workstation(x, -9, partition="skySoft", chair="yellow")
        workstation(x, 5, partition="skySoft", chair="coral")
    put(meeting_pod("coral"), -21, -13)
    put(stall("yellow"), -24.5, 6, rot=90)
    put(lockers(), -26.8, -3, rot=90)
    put(vending("coral"), 24, -17.5)
    put(printer(), 19, -17)
    put(reception(), 17, 10)
    put(rug(5, "coralSoft"), -18, 15.5)
    put(sofa("coral", "sky", 5), -22, 15.5, rot=90)
    put(table_round("surface"), -17, 15.5)
    put(floor_plant(1.5), -26, -19)
    put(floor_plant(1.3), 26, 2)
    put(floor_plant(1.2), 10, 17)


def rooftop_a():
    """카페 테라스: 원목 데크 + 줄무늬 매대 + 퍼걸러 라운지 + 파라솔"""
    floor(56, 40, "wood")
    floor(30, 18, "floorWarm", x=-4, z=3, y=0.05)
    put(railing(56), 0, -20)
    put(railing(40), -28, 0, rot=90)
    put(railing(40), 28, 0, rot=90)
    skyline(120, -44)
    put(stall("coral"), -17, -13)
    put(pergola(), 16, -11)
    put(sofa("mint", "yellow", 5.5), 16, -12.5, y=0.4)
    put(table_round(), 16, -8.5, y=0.4)
    put(parasol_table("yellow"), -12, 4)
    put(parasol_table("coral"), 0, 9)
    put(parasol_table("mint"), 10, 2)
    for x in (-22, -8, 6, 20):
        put(planter(("coral", "yellow"), 6), x, -18)
    put(tree(0.8), -24, 14)
    put(planter(("yellow", "surface"), 5, "woodLight"), -24, 6, rot=90)
    put(bench(), 22, 12, rot=-90)
    put(lamp_post(), 25, 17)
    put(lamp_post(), -4, -17)
    put(bush(), 24, 4)


def rooftop_b():
    """힐링 가든: 잔디 + 분수 + 캡슐 의자 + 화단, 쉬는 공간 위주"""
    floor(56, 40, "stone")
    f = Furniture("Lawn")
    f.zone("Grass", [box((40, 0.16, 26), at=(0, 0.1, 0), rv=9, r=0)], "lawn")
    put(railing(56), 0, -20)
    put(railing(40), -28, 0, rot=90)
    put(railing(40), 28, 0, rot=90)
    skyline(120, -44)
    put(fountain(), 0, -1)
    put(stones([(0, 7), (1, 10), (-0.5, 13), (0.5, 16), (-7, -1), (-10, 0), (-13, -1), (7, -1), (10, 0), (13, -1)]), 0, 0)
    put(pod_chair(), -14, -9, rot=-30)
    put(pod_chair(), 14, -9, rot=30)
    put(pod_chair(), -15, 8, rot=40)
    put(tree(1.0), -22, -14)
    put(tree(0.85), 22, -14)
    put(tree(0.7), 23, 13)
    put(flower_bed(7, 4.5), -8, -10)
    put(flower_bed(7, 4.5, ("sky", "surface", "coral")), 8, -10)
    put(flower_bed(6, 4), 13, 9)
    put(bench(), 6, 12, rot=180)
    put(bench(), -6, 12, rot=180)
    put(pergola("coralSoft"), -21, 14, rot=90)
    for x in (-10, 4, 18):
        put(planter(("coral", "yellow"), 6, "woodLight"), x, -18.4)
    put(lamp_post(), -4, -17)
    put(lamp_post(), 26, 4)


def park_a():
    """분수 광장: 가운데 분수와 원형 광장, 사방으로 뻗는 길 — 탁 트인 느낌"""
    floor(64, 46, "lawn")
    put(path([(-32, 0), (32, 0)], 4.2), 0, 0)
    put(path([(0, -23), (0, 23)], 4.2), 0, 0)
    put(rug(10.5, "stone"), 0, 0)
    put(fountain(1.25), 0, 0)
    for k in range(4):
        a = math.radians(45 + 90 * k)
        put(bench(), 8.6 * math.cos(a), 8.6 * math.sin(a), rot=-45 - 90 * k + 90 + 180)
        put(lamp_post(), 12.5 * math.cos(a), 12.5 * math.sin(a))
    for x, z, s in ((-24, -16, 1.2), (-14, -18, 0.9), (22, -17, 1.1), (27, -8, 0.8), (-27, 14, 1.0), (-18, 18, 0.8), (24, 16, 1.15), (14, 19, 0.85)):
        put(tree(s), x, z)
    put(stall("coral"), -20, -4, rot=90)
    put(parasol_table("yellow"), 20, 8)
    put(flower_bed(8, 4.5), 18, -8)
    put(flower_bed(8, 4.5, ("sky", "surface", "yellow")), -16, 9)
    for x, z in ((-8, -18), (8, 19), (28, 3), (-28, -3)):
        put(bush(1.2), x, z)
    put(planter(("coral", "yellow"), 6), 6, -20.5)
    put(planter(("coral", "yellow"), 6), -6, 20.5)


def park_b():
    """숲속 연못: 구불구불한 길 + 연못과 다리 + 피크닉, 아늑한 느낌"""
    floor(64, 46, "lawn")
    put(path([(-32, 14), (-18, 10), (-8, 15), (4, 12), (12, 2), (22, -4), (32, -2)], 3.4, "floorWarm"), 0, 0)
    put(pond(18, 11), -6, -4)
    put(bridge(), -6, -4)
    put(pergola("cream"), 20, 12, rot=0)
    put(bench(), 20, 12.5, y=0.4, rot=180)
    put(picnic(), 4, 18, rot=15)
    put(picnic(), -20, -14, rot=-20)
    for x, z, s in ((-27, -6, 1.25), (-22, 19, 0.9), (-12, -19, 1.1), (2, -18, 0.85), (14, -16, 1.2), (26, -15, 0.95), (28, 5, 0.8), (8, 6, 0.75), (-28, 4, 0.8), (-2, 21, 0.7), (29, 19, 1.0)):
        put(tree(s), x, z)
    put(flower_bed(7, 4), 8, -8)
    put(flower_bed(6, 4, ("sky", "surface", "yellow")), -16, 3.5)
    put(stones([(13, -6), (15, -9), (14, -12)]), 0, 0)
    put(bench(), -2, 9.5, rot=160)
    put(bench(), 16, -1, rot=-60)
    put(lamp_post(), -12, 12)
    put(lamp_post(), 9, 9)
    put(lamp_post(), 24, -7)
    for x, z in ((-30, -18), (20, 21), (-8, 6), (30, -20)):
        put(bush(1.3), x, z)


SCENES = [
    ("office_a", office_a, (26, 30, 44), (0, 1, -3)),
    ("office_b", office_b, (26, 30, 44), (0, 1, -3)),
    ("rooftop_a", rooftop_a, (26, 32, 46), (0, 0, -3)),
    ("rooftop_b", rooftop_b, (26, 32, 46), (0, 0, -3)),
    ("park_a", park_a, (28, 36, 50), (0, 0, -2)),
    ("park_b", park_b, (28, 36, 50), (0, 0, -2)),
]

if __name__ == "__main__":
    only = [a for a in sys.argv[sys.argv.index("--") + 1:]] if "--" in sys.argv else []
    lib.reset()
    os.makedirs(OUT, exist_ok=True)
    for name, build, eye, target in SCENES:
        if only and name not in only:
            continue
        clear()
        build()
        lib.render(os.path.join(OUT, name + ".png"), eye=eye, target=target, width=1500, height=900, lens=32)
        print("RENDERED", name)
