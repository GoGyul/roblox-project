# 사무실 책상 세트 6종: 파티션 책상, 모니터, 의자, 서랍장, 스탠드, 화분
# 실행: /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/office_desk_set.py

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import lib  # noqa: E402
from lib import Furniture, R, T, arc, ball, boolean, box, cyl, lathe, rod, round_edges  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "assets", "salary")
SEAT_OFFSET = 3.3  # SalaryConfig.DESK_SEAT_OFFSET
PARTITION_H = 3.0  # 게임에서 회사별 높이(2.6 / 3.4)로 늘려 써요


def build_desk():
    f = Furniture("Desk")
    main = box((7.6, 0.42, 3.8), at=(-0.2, 2.35, 0), rv=0.9, r=0)
    wing = box((2.0, 0.42, 2.6), at=(2.6, 2.35, 1.7), rv=0.85, r=0)
    f.zone("Top", [round_edges(boolean(main, wing, "UNION"), 0.14)], "woodLight")
    f.zone("Legs", [
        box((0.75, 2.14, 3.0), at=(-3.35, 1.07, 0), rv=0.32, r=0.08),
        box((5.6, 1.25, 0.22), at=(-0.4, 1.5, -1.55), r=0.08),
    ], "surface")
    outer = box((8.7, PARTITION_H, 3.7), at=(-0.2, PARTITION_H / 2, -0.5), rv=1.35, r=0)
    inner = box((8.1, PARTITION_H + 1, 5.0), at=(-0.2, PARTITION_H / 2, 0.45), rv=1.05, r=0)
    f.zone("Partition", [round_edges(boolean(outer, inner), 0.13)], "sage", "Fabric")
    f.zone("Keyboard", [
        box((1.9, 0.1, 0.65), at=(-0.45, 2.61, 0.5), r=0.04),
        ball((0.42, 0.2, 0.6), at=(1.05, 2.62, 0.55)),
    ], "surface")
    f.zone("Cup", [cyl(0.2, 0.5, at=(-2.6, 2.81, -1.2), bevel=0.05)], "coral")
    return f


def build_monitor():
    f = Furniture("Monitor")
    f.zone("Frame", [box((3.0, 1.9, 0.3), at=(0.75, 4.15, -1.25), axis="z", rv=0.28, r=0.1)], "navy")
    f.zone("Screen", [box((2.62, 1.52, 0.06), at=(0.75, 4.15, -1.09), axis="z", rv=0.16, r=0)], "sky", "Neon")
    f.zone("Arm", [
        cyl(0.55, 0.12, at=(-0.4, 2.62, -1.35), bevel=0.04),
        cyl(0.13, 1.25, at=(-0.4, 3.25, -1.35)),
        rod((-0.4, 3.85, -1.35), (0.75, 4.15, -1.5), 0.12),
        ball(0.4, at=(0.75, 4.15, -1.45)),
    ], "metal")
    return f


def build_chair():
    f = Furniture("Chair")
    f.zone("Seat", [box((2.1, 0.55, 2.0), at=(0, 1.55, 0), rv=0.5, r=0.2)], "coral", "Fabric")
    f.zone("Back", [
        box((1.9, 2.3, 0.45), at=(0, 3.0, 0.98), axis="z", rv=0.6, r=0.18, rot=R((1, 0, 0), 8)),
        box((1.3, 0.62, 0.42), at=(0, 4.5, 1.2), axis="z", rv=0.28, r=0.15, rot=R((1, 0, 0), 8)),
    ], "coral", "Fabric")
    frame = [
        cyl(0.16, 1.0, at=(0, 0.85, 0)),
        cyl(0.3, 0.26, at=(0, 0.42, 0), bevel=0.06),
        rod((0, 1.25, 0.8), (0, 2.6, 1.32), 0.13),
        rod((0, 3.9, 1.1), (0, 4.3, 1.16), 0.1),
    ]
    wheels = []
    for k in range(5):
        a = math.radians(90 + 72 * k)
        tip = (1.25 * math.cos(a), 0.3, 1.25 * math.sin(a))
        frame.append(rod((0, 0.42, 0), tip, 0.11))
        wheels.append(ball(0.36, at=(tip[0], 0.18, tip[2])))
    for side in (-1, 1):
        frame.append(rod((side * 0.95, 1.5, 0.25), (side * 1.2, 2.15, 0.25), 0.1))
    f.zone("Frame", frame, "surface")
    f.zone("Arms", [box((0.32, 0.2, 1.4), at=(side * 1.2, 2.22, 0.15), r=0.09) for side in (-1, 1)], "navySoft")
    f.zone("Wheels", wheels, "navy")
    return f


def build_drawer():
    f = Furniture("Drawer")
    f.zone("Body", [box((1.9, 1.62, 2.5), at=(0, 1.11, 0), rv=0.25, r=0.1)], "cream")
    f.zone("Top", [box((2.0, 0.16, 2.6), at=(0, 2.0, 0), rv=0.3, r=0.06)], "woodLight")
    f.zone("Fronts", [box((1.5, 0.6, 0.12), at=(0, y, 1.28), axis="z", rv=0.12, r=0.04) for y in (0.75, 1.47)], "surface")
    f.zone("Handles", [box((0.7, 0.1, 0.12), at=(0, y, 1.38), r=0.045) for y in (0.75, 1.47)], "wood")
    f.zone("Wheels", [ball(0.32, at=(sx * 0.65, 0.16, sz * 0.95)) for sx in (-1, 1) for sz in (-1, 1)], "navy")
    return f


def build_lamp():
    f = Furniture("Lamp")
    shade = lathe([(0, 0)] + arc(0, 0, 0.62, 0, 90, 10), mat=T(0.45, 1.3, 0) @ R((0, 0, 1), 28))
    f.zone("Body", [cyl(0.5, 0.14, at=(0, 0.07, 0), bevel=0.05), shade], "yellow")
    f.zone("Stem", [
        rod((0, 0.1, 0), (-0.25, 0.9, 0), 0.07),
        rod((-0.25, 0.9, 0), (0.3, 1.5, 0), 0.07),
        ball(0.22, at=(-0.25, 0.9, 0)),
    ], "wood")
    f.zone("Bulb", [ball(0.5, at=(0.5, 1.27, 0))], "yellowSoft", "Neon")
    return f


def build_plant():
    f = Furniture("Plant")
    pot = [(0, 0), (0.5, 0)] + arc(0.5, 0.1, 0.1, -90, 0, 4) + [(0.78, 1.05)] + arc(0.72, 1.14, 0.09, 0, 180, 6) + [(0.6, 1.1), (0, 1.1)]
    f.zone("Pot", [lathe(pot)], "surface")
    f.zone("Soil", [cyl(0.62, 0.06, at=(0, 1.12, 0))], "woodDark")
    dark, light = [], []
    for k in range(7):
        m = T(0, 1.1, 0) @ R((0, 1, 0), k * 360 / 7) @ R((1, 0, 0), 38 + 6 * (k % 2)) @ T(0, 0.95, 0)
        dark.append(ball((0.8, 1.9, 0.16), mat=m))
    for k in range(5):
        m = T(0, 1.1, 0) @ R((0, 1, 0), 25 + k * 72) @ R((1, 0, 0), 14 + 5 * (k % 2)) @ T(0, 1.15, 0)
        light.append(ball((0.75, 2.3, 0.16), mat=m))
    f.zone("Leaves", dark, "grass")
    f.zone("LeavesLight", light, "grassLight")
    return f


def main():
    lib.reset()
    desk, monitor, chair, drawer, lamp, plant = build_desk(), build_monitor(), build_chair(), build_drawer(), build_lamp(), build_plant()
    furniture = [desk, monitor, chair, drawer, lamp, plant]

    # 조립된 모습 (게임 배치와 같아요)
    chair.place(0, 0, SEAT_OFFSET)
    drawer.place(2.6, 0, 0.3)
    lamp.place(-3.1, 2.56, -1.0)
    plant.place(-6.0, 0, -1.2)

    lib.export(os.path.join(OUT, "fbx", "office_desk_set.fbx"), furniture, os.path.join(OUT, "fbx", "office_desk_set.json"))
    lib.render(os.path.join(OUT, "preview", "office_desk_set.png"), eye=(8.5, 8.5, 12.5), target=(-0.5, 2.1, 0.6))
    lib.render(os.path.join(OUT, "preview", "office_desk_set_front.png"), eye=(-7, 5.5, -11), target=(-0.5, 2.2, 0.5))

    # 낱개로 늘어놓은 모습
    for item, x in zip([desk, chair, monitor, drawer, lamp, plant], [-18, -11, -5.5, 0, 5, 10]):
        item.place(x, 0, 0)
    monitor.place(-5.7, -2.5, 1.3)  # 책상 위 높이에 맞춰 만든 걸 바닥으로 내려요
    lib.render(os.path.join(OUT, "preview", "office_desk_set_parts.png"), eye=(-4, 9, 40), target=(-4, 1.8, 0), width=2000, height=640, lens=45)

    for f in furniture:
        print(f.name, [(z["name"].split("_")[1], z["triangles"]) for z in f.zones])
    total = sum(z["triangles"] for f in furniture for z in f.zones)
    print(f"DONE zones={sum(len(f.zones) for f in furniture)} triangles={total}")


if __name__ == "__main__":
    main()
