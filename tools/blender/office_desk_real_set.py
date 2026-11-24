# 현실 비율 책상 세트 (리뉴얼 3단계): 얇은 상판 + 금속 다리 + 직선 파티션 + 메시 의자 + 슬림 모니터 + 철제 서랍
# 실행: /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/office_desk_real_set.py
# 치수는 게임 판정(상판 높이 2.35~2.56, 좌석 1.55, 파티션 기준 높이 3)에 맞췄어요. 둥근 책상 세트(Desk·Chair…)를 대체해요.

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import lib  # noqa: E402
import drafts_spaces as d  # noqa: E402
import office_kit_set  # noqa: E402,F401  (B안 팔레트)
from lib import Furniture, R, ball, box, cyl, rod  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "salary")
lib.PALETTE.update({"laminate": (214, 204, 190), "paper": (244, 243, 238)})
PARTITION_H = 3.0


def B(size, at, r=0.03, **kw):
    return box(size, at=at, r=r, seg=1, **kw)


def desk():
    f = Furniture("RDesk")
    f.zone("Top", [box((7.6, 0.2, 3.8), at=(-0.2, 2.46, 0), r=0.04, seg=2)], "laminate")
    f.zone("Frame", [B((0.16, 2.36, 0.16), (sx, 1.18, sz), r=0.02) for sx in (-3.8, 3.4) for sz in (-1.6, 1.6)]
           + [B((0.16, 0.16, 3.36), (sx, 0.08, 0), r=0.02) for sx in (-3.8, 3.4)]
           + [B((7.2, 0.16, 0.16), (-0.2, 2.28, -1.6), r=0.02), B((7.0, 1.3, 0.08), (-0.2, 1.6, -1.72), r=0.02)], "metal")
    f.zone("Partition", [B((8.2, PARTITION_H, 0.22), (-0.2, PARTITION_H / 2, -2.1)),
                         B((0.22, PARTITION_H, 3.2), (-4.3, PARTITION_H / 2, -0.6)),
                         B((0.22, PARTITION_H, 3.2), (3.9, PARTITION_H / 2, -0.6))], "sage", "Fabric")
    f.zone("Trim", [B((8.3, 0.1, 0.3), (-0.2, PARTITION_H + 0.04, -2.1), r=0.02)]
           + [B((0.3, 0.1, 3.0), (sx, PARTITION_H + 0.04, -0.45), r=0.02) for sx in (-4.3, 3.9)]
           + [B((0.28, PARTITION_H + 0.12, 0.28), (sx, PARTITION_H / 2 + 0.06, 1.1), r=0.03) for sx in (-4.3, 3.9)], "metal")
    f.zone("Keyboard", [B((1.9, 0.08, 0.62), (-0.3, 2.6, 0.5), r=0.02), box((0.34, 0.12, 0.56), at=(1.3, 2.62, 0.55), r=0.05, seg=2)], "navy")
    f.zone("Paper", [B((1.0, 0.03, 1.4), (-2.5, 2.58, 0.3), r=0, rot=R((0, 1, 0), 12)), B((1.0, 0.03, 1.4), (-2.3, 2.61, 0.4), r=0, rot=R((0, 1, 0), -8))], "paper")
    f.zone("Cup", [cyl(0.2, 0.42, at=(2.6, 2.77, -0.7), bevel=0.03, seg=14)], "coral")
    return f


def monitor():
    f = Furniture("RMonitor")
    f.zone("Frame", [B((3.3, 1.95, 0.12), (0.75, 4.1, -1.25)), B((0.26, 1.3, 0.12), (0.75, 3.15, -1.33), r=0.02), B((1.5, 0.07, 0.9), (0.75, 2.6, -1.3), r=0.02)], "navy")
    f.zone("Screen", [B((3.14, 1.78, 0.03), (0.75, 4.12, -1.18), r=0)], "screen", "Neon")
    return f


def chair():
    f = Furniture("RChair")
    f.zone("Seat", [box((1.95, 0.34, 1.95), at=(0, 1.6, 0), rv=0.35, r=0.1, seg=2, segv=5)], "seat", "Fabric")
    f.zone("Back", [box((1.85, 2.3, 0.16), at=(0, 3.15, 1.0), axis="z", rv=0.4, r=0.05, seg=2, segv=5, rot=R((1, 0, 0), 9))], "seat", "Fabric")
    frame = [cyl(0.1, 1.0, at=(0, 0.95, 0), seg=10), cyl(0.2, 0.2, at=(0, 0.42, 0), seg=12),
             rod((0, 1.45, 0.6), (0, 2.2, 1.14), 0.08, seg=8), rod((0, 2.2, 1.14), (0, 3.9, 1.22), 0.07, seg=8)]
    wheels = []
    for k in range(5):
        a = math.radians(90 + 72 * k)
        tip = (1.2 * math.cos(a), 0.3, 1.2 * math.sin(a))
        frame.append(rod((0, 0.42, 0), tip, 0.07, seg=8))
        wheels.append(ball(0.28, at=(tip[0], 0.14, tip[2]), seg=10))
    for side in (-1, 1):
        frame.append(rod((side * 0.95, 1.55, 0.2), (side * 1.1, 2.3, 0.2), 0.06, seg=8))
        frame.append(box((0.26, 0.1, 1.1), at=(side * 1.1, 2.36, 0.1), r=0.04, seg=2))
    f.zone("Frame", frame, "navy")
    f.zone("Wheels", wheels, "navy")
    return f


def drawer():
    f = Furniture("RDrawer")
    f.zone("Body", [B((1.7, 2.05, 2.4), (0, 1.1, 0), r=0.04)], "surfaceSoft", "Metal")
    f.zone("Lines", [B((1.56, 0.03, 0.03), (0, y, 1.2), r=0) for y in (0.75, 1.4, 1.75)] + [B((0.7, 0.07, 0.04), (0, y, 1.21), r=0) for y in (1.05, 1.58, 1.92)], "navy")
    return f


def main():
    lib.reset()
    furniture = [desk(), monitor(), chair(), drawer()]
    d.put(furniture[2], 0.6, 3.6, rot=25)
    d.put(furniture[3], 2.5, 0.3)
    lib.export(os.path.join(OUT, "fbx", "office_desk_real_set.fbx"), furniture, os.path.join(OUT, "fbx", "office_desk_real_set.json"))
    lib.render(os.path.join(OUT, "preview", "office_desk_real_set.png"), eye=(7.5, 7.5, 10.5), target=(0, 2.4, 0.6), width=1600, height=1000, lens=42, floor="carpetDark", samples=64)
    for f in furniture:
        print(f.name, len(f.zones), sum(z["triangles"] for z in f.zones))
    print("DONE", sum(z["triangles"] for f in furniture for z in f.zones))


if __name__ == "__main__":
    main()
