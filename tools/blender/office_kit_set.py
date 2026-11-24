# 사무실 전체 메시 키트: 벽·창·바닥·천장 조각 + 탕비실·화장실·매점·체력 단련실·부장님 자리 가구
# 실행: /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/office_kit_set.py
# 건축 조각은 8칸 단위예요 (벽 높이 12, 게임에서 Y로 늘려 14까지 써요). 원점은 바닥 가운데, 앞은 +Z.

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import lib  # noqa: E402
import drafts_spaces as d  # noqa: E402
from lib import Furniture, R, arc, ball, box, cyl, lathe, rod  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "salary")

# 질감 B안 색 (shared/SalaryTheme.luau 의 Theme.Mesh 와 같아요)
lib.PALETTE.update({
    "cream": (232, 229, 221), "surface": (232, 230, 225), "surfaceSoft": (214, 220, 222), "navy": (48, 50, 55),
    "navySoft": (74, 78, 86), "mint": (122, 160, 148), "mintDark": (70, 110, 102), "sage": (142, 156, 150),
    "sky": (128, 160, 186), "skySoft": (190, 206, 218), "coral": (190, 110, 98), "yellow": (206, 170, 92),
    "yellowSoft": (255, 236, 200), "wood": (176, 142, 104), "woodLight": (203, 172, 132), "woodDark": (120, 92, 66),
    "line": (168, 176, 182), "metal": (176, 180, 184), "stone": (206, 202, 194),
    "carpet": (150, 156, 162), "carpetDark": (134, 140, 147), "wall": (232, 230, 225), "seat": (84, 92, 104), "screen": (170, 200, 225),
})


def B(size, at, r=0.0, **kw):
    """모서리 장식이 거의 없는 납작한 조각용 (삼각형 수를 아껴요)."""
    return box(size, at=at, r=r, seg=1, **kw)


def wall_panel():
    f = Furniture("WallPanel")
    f.zone("Wall", [B((8, 12, 0.5), (0, 6, 0))], "wall")
    f.zone("Base", [B((8, 0.7, 0.64), (0, 0.35, 0))], "navySoft")
    f.zone("Rail", [B((8, 0.2, 0.6), (0, 3.5, 0)), B((8, 0.3, 0.6), (0, 11.85, 0))], "woodLight")
    return f


def window_panel():
    f = Furniture("WindowPanel")
    f.zone("Wall", [B((8, 3, 0.5), (0, 1.5, 0)), B((8, 2, 0.5), (0, 11, 0)), B((0.6, 7, 0.5), (-3.7, 6.5, 0)), B((0.6, 7, 0.5), (3.7, 6.5, 0))], "wall")
    f.zone("Base", [B((8, 0.7, 0.64), (0, 0.35, 0))], "navySoft")
    f.zone("Frame", [B((7, 0.2, 0.3), (0, 3.1, 0)), B((7, 0.2, 0.3), (0, 9.9, 0)), B((0.2, 7, 0.3), (-3.4, 6.5, 0)), B((0.2, 7, 0.3), (3.4, 6.5, 0)), B((0.16, 7, 0.26), (0, 6.5, 0))], "metal")
    f.zone("Glass", [B((6.8, 6.8, 0.08), (0, 6.5, -0.05))], "skySoft")
    f.zone("Blinds", [B((6.6, 0.05, 0.3), (0, 9.7 - k * 0.33, 0.22), rot=R((1, 0, 0), 30)) for k in range(7)], "cream")
    f.zone("Sill", [B((7.4, 0.16, 0.9), (0, 3.02, 0.25), r=0.04)], "woodLight")
    return f


def pillar():
    f = Furniture("Pillar")
    f.zone("Wall", [B((1.4, 12, 1.0), (0, 6, 0), r=0.06)], "wall")
    f.zone("Base", [B((1.52, 0.7, 1.12), (0, 0.35, 0))], "navySoft")
    return f


def floor_tile():
    f = Furniture("FloorTile")
    f.zone("TileA", [B((3.96, 0.1, 3.96), (sx * 2, 0, sx * 2), r=0.02) for sx in (-1, 1)], "carpet", "Carpet")
    f.zone("TileB", [B((3.96, 0.1, 3.96), (sx * 2, 0, -sx * 2), r=0.02) for sx in (-1, 1)], "carpetDark", "Carpet")
    return f


def ceiling_tile(light):
    f = Furniture("CeilingLight" if light else "CeilingTile")
    f.zone("Tile", [B((3.9, 0.16, 3.9), (sx * 2, -0.1, sz * 2), r=0.03) for sx in (-1, 1) for sz in (-1, 1)], "surface")
    f.zone("Grid", [B((8, 0.08, 0.14), (0, -0.2, z)) for z in (-4, 0)] + [B((0.14, 0.08, 8), (x, -0.2, 0)) for x in (-4, 0)], "metal")
    if light:
        f.zone("Panel", [B((1.6, 0.08, 5.6), (0, -0.24, 0), r=0.02)], "yellowSoft", "Neon")
        f.zone("Housing", [B((2.0, 0.12, 6.0), (0, -0.2, 0), r=0.03)], "metal")
    return f


def door_frame():
    f = Furniture("DoorFrame")
    f.zone("Frame", [B((0.5, 9, 0.9), (-3.25, 4.5, 0), r=0.05), B((0.5, 9, 0.9), (3.25, 4.5, 0), r=0.05), B((7, 0.5, 0.9), (0, 9.25, 0), r=0.05)], "wood")
    return f


def boss_desk():
    f = Furniture("BossDesk")
    f.zone("Top", [box((10, 0.3, 4.6), at=(0, 2.75, 0), rv=0.25, r=0.06, seg=2, segv=4)], "wood")
    f.zone("Body", [box((2.6, 2.6, 4.0), at=(sx * 3.5, 1.3, 0), r=0.08, seg=2) for sx in (-1, 1)] + [B((4.6, 2.0, 0.2), (0, 1.6, -1.8), r=0.04)], "woodDark")
    f.zone("Handles", [B((0.9, 0.1, 0.12), (sx * 3.5, y, 2.03), r=0.04) for sx in (-1, 1) for y in (0.8, 1.6, 2.2)], "metal")
    f.zone("Mat", [B((3.2, 0.05, 2.0), (0, 2.92, 0.6), r=0.02)], "navy")
    f.zone("Plate", [B((1.8, 0.4, 0.3), (0, 3.1, -1.7), r=0.05)], "yellow")
    return f


def counter():
    f = Furniture("Counter")
    f.zone("Body", [B((8, 2.8, 2.4), (0, 1.4, 0), r=0.05)], "surface")
    f.zone("Top", [box((8.2, 0.25, 2.7), at=(0, 2.95, 0), r=0.06, seg=2)], "stone")
    f.zone("Doors", [B((1.8, 2.2, 0.08), (-3 + 2 * i, 1.45, 1.22), r=0.04) for i in range(4)], "cream")
    f.zone("Metal", [B((0.1, 0.8, 0.12), (-2.3 + 2 * i, 2.0, 1.3), r=0.03) for i in range(4)]
           + [B((1.9, 0.08, 1.4), (2.2, 3.09, 0)), rod((2.2, 3.1, -0.9), (2.2, 3.9, -0.9), 0.08), rod((2.2, 3.9, -0.9), (2.2, 3.8, -0.3), 0.08)], "metal")
    return f


def fridge():
    f = Furniture("Fridge")
    f.zone("Body", [box((3, 7, 2.8), at=(0, 3.5, 0), rv=0.2, r=0.08, seg=2, segv=4)], "surface")
    f.zone("Line", [B((2.9, 0.06, 0.05), (0, 4.5, 1.41))], "line")
    f.zone("Handles", [B((0.14, 1.6, 0.16), (1.1, 5.5, 1.46), r=0.05), B((0.14, 1.6, 0.16), (1.1, 3.3, 1.46), r=0.05)], "metal")
    return f


def dining_table():
    f = Furniture("DiningTable")
    f.zone("Top", [box((6, 0.25, 3.4), at=(0, 2.6, 0), rv=0.4, r=0.08, seg=2, segv=5)], "woodLight")
    f.zone("Legs", [rod((sx * 2.5, 0.1, sz * 1.3), (sx * 2.5, 2.5, sz * 1.3), 0.1, seg=8) for sx in (-1, 1) for sz in (-1, 1)], "metal")
    return f


def dining_chair():
    f = Furniture("DiningChair")
    f.zone("Seat", [box((1.7, 0.28, 1.7), at=(0, 1.6, 0), rv=0.3, r=0.08, seg=2, segv=4),
                    box((1.7, 1.5, 0.22), at=(0, 2.95, 0.8), axis="z", rv=0.3, r=0.06, seg=2, segv=4, rot=R((1, 0, 0), 6))], "seat", "Fabric")
    f.zone("Legs", [rod((sx * 0.7, 0.05, sz * 0.7), (sx * 0.7, 1.5, sz * 0.7), 0.07, seg=8) for sx in (-1, 1) for sz in (-1, 1)]
           + [rod((sx * 0.7, 1.6, 0.75), (sx * 0.7, 2.4, 0.85), 0.07, seg=8) for sx in (-1, 1)], "navy")
    return f


def toilet():
    f = Furniture("Toilet")
    f.zone("Bowl", [lathe([(0, 0), (0.85, 0), (0.75, 0.5), (1.05, 1.4), (1.1, 1.6), (0, 1.6)], seg=20, at=(0, 0, 0.3)),
                    box((2.0, 1.8, 0.8), at=(0, 2.5, -1.0), r=0.1, seg=2)], "surface")
    f.zone("Lid", [cyl(1.12, 0.14, at=(0, 1.67, 0.3), seg=20, bevel=0.04), B((0.5, 0.12, 0.3), (0.5, 3.45, -1.0), r=0.04)], "surfaceSoft")
    return f


def washbasin():
    f = Furniture("Washbasin")
    f.zone("Cabinet", [B((3.8, 2.7, 1.8), (0, 1.35, 0), r=0.05)], "surface")
    f.zone("Top", [box((4, 0.3, 2), at=(0, 2.85, 0), r=0.06, seg=2)], "stone")
    f.zone("Basin", [ball((1.7, 0.5, 1.2), at=(0, 3.0, 0.15), seg=16)], "surfaceSoft")
    f.zone("Metal", [rod((0, 3.0, -0.7), (0, 3.7, -0.7), 0.08, seg=8), rod((0, 3.7, -0.7), (0, 3.6, -0.15), 0.08, seg=8), B((3.8, 3.4, 0.12), (0, 6.2, -0.92), r=0.04)], "metal")
    f.zone("Mirror", [B((3.5, 3.1, 0.06), (0, 6.2, -0.85))], "skySoft")
    return f


def store_shelf():
    f = Furniture("StoreShelf")
    f.zone("Frame", [B((0.2, 6, 1.6), (sx * 2.9, 3, 0), r=0.03) for sx in (-1, 1)] + [B((6, 0.18, 1.6), (0, y, 0), r=0.03) for y in (0.3, 1.8, 3.3, 4.8, 5.9)] + [B((6, 6, 0.12), (0, 3, -0.74))], "surface")
    colors = ("coral", "yellow", "sky", "mint")
    for ci, c in enumerate(colors):
        f.zone("Goods" + c, [box((0.6, 0.95 if (row + i) % 2 else 0.7, 0.7), at=(-2.4 + i * 0.8, y + 0.09 + (0.475 if (row + i) % 2 else 0.35), 0.2), r=0.06, seg=1)
                             for row, y in enumerate((0.3, 1.8, 3.3, 4.8)) for i in range(7) if (row * 3 + i) % 4 == ci], c)
    return f


def store_counter():
    f = Furniture("StoreCounter")
    f.zone("Body", [B((6, 3, 2), (0, 1.5, 0), r=0.06)], "woodLight")
    f.zone("Top", [box((6.3, 0.25, 2.3), at=(0, 3.1, 0), r=0.06, seg=2)], "wood")
    f.zone("Register", [box((1.5, 1.0, 1.2), at=(1.5, 3.7, 0), r=0.1, seg=2), B((1.2, 0.9, 0.12), (1.5, 4.5, -0.3), r=0.04, rot=R((1, 0, 0), -15))], "navy")
    f.zone("Screen", [B((1.0, 0.7, 0.04), (1.5, 4.5, -0.22), rot=R((1, 0, 0), -15))], "screen", "Neon")
    return f


def locker():
    f = Furniture("Locker")
    f.zone("Body", [B((1.6, 6, 1.6), (0, 3, 0), r=0.06)], "sage")
    f.zone("Detail", [B((0.8, 0.1, 0.06), (0, 5.0 - k * 0.28, 0.81)) for k in range(3)] + [B((0.12, 0.6, 0.12), (0.55, 3.2, 0.84), r=0.03)], "metal")
    return f


def water_cooler():
    f = Furniture("WaterCooler")
    f.zone("Body", [box((1.4, 3.6, 1.4), at=(0, 1.8, 0), r=0.1, seg=2)], "surface")
    f.zone("Bottle", [lathe([(0, 3.6), (0.3, 3.6), (0.35, 3.9), (0.62, 4.2), (0.62, 5.3), (0.5, 5.5), (0, 5.5)], seg=18)], "sky")
    f.zone("Taps", [B((0.25, 0.3, 0.25), (-0.3, 2.6, 0.78), r=0.05)], "coral")
    f.zone("TapsCold", [B((0.25, 0.3, 0.25), (0.3, 2.6, 0.78), r=0.05), B((1.0, 0.1, 0.5), (0, 2.1, 0.85), r=0.03)], "navySoft")
    return f


def treadmill():
    f = Furniture("Treadmill")
    f.zone("Deck", [box((2.6, 0.5, 6), at=(0, 0.45, 0.4), r=0.12, seg=2), box((2.7, 1.0, 0.45), at=(0, 4.4, -2.95), r=0.12, seg=2, rot=R((1, 0, 0), -20))], "navy")
    f.zone("Belt", [B((2.0, 0.06, 5.2), (0, 0.73, 0.5))], "navySoft")
    f.zone("Frame", [rod((sx * 1.2, 0.7, -2.3), (sx * 1.2, 4.2, -2.95), 0.11, seg=10) for sx in (-1, 1)] + [rod((sx * 1.2, 3.6, -2.8), (sx * 1.2, 3.5, -1.2), 0.09, seg=10) for sx in (-1, 1)], "metal")
    f.zone("Screen", [B((1.6, 0.6, 0.05), (0, 4.42, -2.71), rot=R((1, 0, 0), -20))], "screen", "Neon")
    return f


def dumbbell_rack():
    f = Furniture("DumbbellRack")
    f.zone("Frame", [B((0.2, 3.2, 1.8), (sx * 2.4, 1.6, 0), r=0.04) for sx in (-1, 1)] + [B((5, 0.16, 1.2), (0, y, z), r=0.03, rot=R((1, 0, 0), 15)) for y, z in ((1.0, 0.25), (2.4, -0.15))], "metal")
    for ci, c in enumerate(("coral", "sky", "yellow")):
        parts = []
        for y, z in ((1.25, 0.3), (2.65, -0.1)):
            x = -1.6 + ci * 1.6
            parts += [cyl(0.38, 0.3, at=(x - 0.4, y + 0.2, z), axis="x", seg=12), cyl(0.38, 0.3, at=(x + 0.4, y + 0.2, z), axis="x", seg=12), cyl(0.1, 0.8, at=(x, y + 0.2, z), axis="x", seg=8)]
        f.zone("Bells" + c, parts, c)
    return f


def weight_bench():
    f = Furniture("WeightBench")
    f.zone("Pad", [box((1.6, 0.4, 5), at=(0, 1.6, 0.6), rv=0.3, r=0.1, seg=2, segv=4)], "seat", "Fabric")
    f.zone("Frame", [B((0.25, 1.4, 0.25), (0, 0.7, z), r=0.04) for z in (-1.4, 2.6)] + [B((1.8, 0.2, 0.3), (0, 0.1, z), r=0.04) for z in (-1.4, 2.6)]
           + [B((0.25, 4.4, 0.25), (sx * 1.5, 2.2, -1.6), r=0.04) for sx in (-1, 1)] + [cyl(0.09, 6.4, at=(0, 4.3, -1.6), axis="x", seg=10)], "metal")
    f.zone("Plates", [cyl(0.9, 0.22, at=(sx * 2.6, 4.3, -1.6), axis="x", seg=18) for sx in (-1, 1)] + [cyl(0.7, 0.2, at=(sx * 2.85, 4.3, -1.6), axis="x", seg=18) for sx in (-1, 1)], "navy")
    return f


def elevator_door():
    f = Furniture("ElevatorDoor")
    f.zone("Frame", [B((0.6, 8.6, 0.8), (sx * 2.8, 4.3, 0), r=0.06) for sx in (-1, 1)] + [B((6.2, 0.6, 0.8), (0, 8.6, 0), r=0.06)], "metal")
    f.zone("Leaves", [B((2.46, 8.3, 0.16), (sx * 1.25, 4.15, -0.05), r=0.03) for sx in (-1, 1)], "line", "Metal")
    f.zone("Sign", [B((2.2, 0.8, 0.2), (0, 9.5, 0.1), r=0.08)], "navy")
    f.zone("Lamp", [ball((0.4, 0.4, 0.2), at=(0, 9.5, 0.22), seg=12), B((0.3, 0.6, 0.1), (3.5, 4.2, 0.2), r=0.04)], "yellowSoft", "Neon")
    return f


def notice_board():
    f = Furniture("NoticeBoard")
    f.zone("Frame", [B((6, 3.6, 0.2), (0, 0, 0), r=0.05)], "wood")
    f.zone("Cork", [B((5.6, 3.2, 0.06), (0, 0, 0.1))], "woodLight")
    f.zone("Paper", [B((1.1, 1.4, 0.03), (x, y, 0.14), rot=R((0, 0, 1), a)) for x, y, a in ((-1.8, 0.4, 4), (-0.3, -0.3, -5), (1.9, 0.5, 3))], "surface")
    f.zone("Memo", [B((0.8, 0.8, 0.03), (x, y, 0.15), rot=R((0, 0, 1), a)) for x, y, a in ((0.9, 0.7, -6), (-1.9, -1.0, 8))], "yellow")
    return f


def cardboard_box():
    f = Furniture("CardboardBox")
    f.zone("Box", [B((2.4, 2, 2.4), (0, 1, 0), r=0.05)], "wood")
    f.zone("Tape", [B((0.5, 0.03, 2.42), (0, 2.01, 0)), B((0.5, 0.8, 0.03), (0, 1.62, 1.21))], "woodLight")
    return f


def trash_bin():
    f = Furniture("TrashBin")
    f.zone("Bin", [lathe([(0, 0), (0.55, 0), (0.75, 1.9), (0.8, 2.0), (0.68, 2.0), (0.5, 0.15), (0, 0.15)], seg=18)], "navySoft")
    return f


BUILDERS = [
    wall_panel, window_panel, pillar, floor_tile, lambda: ceiling_tile(False), lambda: ceiling_tile(True), door_frame,
    boss_desk, counter, fridge, dining_table, dining_chair, toilet, washbasin,
    store_shelf, store_counter, locker, water_cooler, treadmill, dumbbell_rack, weight_bench,
    elevator_door, notice_board, cardboard_box, trash_bin,
]


def main():
    lib.reset()
    furniture = []
    for index, build in enumerate(BUILDERS):
        f = build()
        lift = 12 if f.name.startswith("Ceiling") else (5 if f.name == "NoticeBoard" else 0)
        d.put(f, -33 + (index % 7) * 11, -18 + (index // 7) * 12, y=lift)
        furniture.append(f)
    names = [f.name for f in furniture]
    assert len(set(names)) == len(names), names
    lib.export(os.path.join(OUT, "fbx", "office_kit_set.fbx"), furniture, os.path.join(OUT, "fbx", "office_kit_set.json"))
    lib.render(os.path.join(OUT, "preview", "office_kit_set.png"), eye=(0, 50, 62), target=(0, 2, 0), width=2000, height=1200, lens=28, floor="carpetDark")
    for f in furniture:
        print(f.name, len(f.zones), sum(z["triangles"] for z in f.zones))
    print(f"DONE furniture={len(furniture)} zones={sum(len(f.zones) for f in furniture)} triangles={sum(z['triangles'] for f in furniture for z in f.zones)}")


if __name__ == "__main__":
    main()
