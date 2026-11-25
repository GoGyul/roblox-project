# 약국 세트 (눈치 스트리트 약국): 조제대 · 약 진열장 · 초록 십자 간판 · 대기 의자 · 큰 약병 · 혈압계
# 실행: /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/pharmacy_set.py
# 좌표는 로블록스 기준(스터드, Y 위, 원점 = 바닥 가운데, 앞 = +Z).

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import lib  # noqa: E402
import drafts_spaces as d  # noqa: E402
import street_shops_set as shops  # noqa: E402
from lib import Furniture, R, ball, box, cyl, lathe, rod  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "salary")
lib.PALETTE.update({"pharm": (58, 148, 112), "pharmSoft": (196, 226, 210)})
bx = shops.bx


def pharm_counter():
    """조제대 (가로 10 · 높이 3.6): 흰 몸통 + 초록 띠 + 유리 진열 + 계산기 + 약 봉투"""
    f = Furniture("PharmCounter")
    f.zone("Body", [bx((10.0, 3.2, 2.2), (0, 1.6, -0.1), r=0.1)], "cakeCream")
    f.zone("Band", [bx((10.1, 0.5, 2.3), (0, 2.75, -0.1), r=0.05), bx((10.1, 0.3, 2.3), (0, 0.15, -0.1), r=0.03)], "pharm")
    f.zone("Top", [bx((10.4, 0.24, 2.7), (0, 3.4, 0), r=0.08)], "stone")
    f.zone("Glass", [bx((4.6, 1.6, 0.2), (-2.3, 1.5, 1.02), r=0.04)], "glass", "Glass")
    f.zone("Boxes", [bx((0.7, 0.9, 0.4), (-4.0 + i * 0.85, 1.4, 0.7), r=0.05) for i in range(5)], "pharmSoft")
    f.zone("Cross", [bx((0.9, 0.3, 0.08), (3.0, 1.6, 1.02), r=0.03), bx((0.3, 0.9, 0.08), (3.0, 1.6, 1.02), r=0.03)], "pharm")
    f.zone("Register", [bx((1.3, 0.8, 1.0), (3.6, 3.9, -0.1), r=0.1), bx((1.1, 0.7, 0.08), (3.6, 4.45, -0.45), r=0.04, rot=R((1, 0, 0), -15))], "ink")
    f.zone("Bags", [bx((0.8, 1.0, 0.3), (-3.2 + i * 1.1, 4.0, 0.2), r=0.05, rot=R((1, 0, 0), -8)) for i in range(3)], "surface")
    return f


def med_shelf():
    """약 진열장 (가로 6 · 높이 9, 벽에 붙여요): 서랍 + 선반 네 단의 약 상자와 약병"""
    f = Furniture("MedShelf")
    f.zone("Frame", [bx((6.0, 9.0, 0.3), (0, 4.5, -0.6), r=0.04), bx((6.0, 0.2, 1.4), (0, 8.9, 0), r=0.04)]
           + [bx((0.2, 9.0, 1.4), (sx * 2.9, 4.5, 0), r=0.04) for sx in (-1, 1)]
           + [bx((5.7, 0.14, 1.3), (0, 2.6 + i * 1.5, 0), r=0.03) for i in range(4)], "cakeCream")
    f.zone("Drawers", [bx((5.7, 2.4, 1.3), (0, 1.25, 0), r=0.06)], "pharmSoft")
    f.zone("Handles", [bx((0.8, 0.12, 0.1), (-1.9 + c * 1.9, 0.75 + r * 1.0, 0.68), r=0.03) for c in range(3) for r in range(2)], "pharm")
    a, b, bottles, caps = [], [], [], []
    for row in range(4):
        y = 2.67 + row * 1.5
        for i in range(6):
            x = -2.3 + i * 0.92
            if (i + row) % 3 == 2:
                bottles.append(cyl(0.26, 0.8, at=(x, y + 0.4, 0.1), bevel=0.06))
                caps.append(cyl(0.2, 0.18, at=(x, y + 0.89, 0.1)))
            else:
                ((a if (i + row) % 2 == 0 else b)).append(bx((0.7, 0.95 - (i % 2) * 0.2, 0.5), (x, y + 0.48 - (i % 2) * 0.1, 0.1), r=0.04))
    f.zone("BoxesA", a, "pharmSoft")
    f.zone("BoxesB", b, "surface")
    f.zone("Bottles", bottles, "woodDark")
    f.zone("Caps", caps, "cakeCream")
    return f


def pharm_cross():
    """초록 십자 간판 (가로 3.4, 원점 = 가운데, 뒤가 벽): 불 켜지는 십자 + 흰 테두리"""
    f = Furniture("PharmCross")
    f.zone("Plate", [bx((3.4, 3.4, 0.2), (0, 0, 0.1), r=0.3)], "cakeCream")
    f.zone("Cross", [bx((2.6, 0.9, 0.16), (0, 0, 0.26), r=0.08), bx((0.9, 2.6, 0.16), (0, 0, 0.26), r=0.08)], "pharm", "Neon")
    return f


def wait_bench():
    """대기 의자 (세 자리, 가로 6): 철제 다리 + 초록 좌판"""
    f = Furniture("WaitBench")
    f.zone("Seats", [bx((1.7, 0.2, 1.7), (-2.0 + i * 2.0, 1.6, 0), r=0.12) for i in range(3)] + [bx((1.7, 1.4, 0.2), (-2.0 + i * 2.0, 2.5, -0.8), r=0.12, rot=R((1, 0, 0), -8)) for i in range(3)], "pharm")
    f.zone("Frame", [bx((6.0, 0.2, 0.3), (0, 1.4, 0), r=0.05)] + [rod((sx * 2.6, 1.4, 0), (sx * 2.6, 0.1, sz * 0.8), 0.07) for sx in (-1, 1) for sz in (-1, 1)]
           + [rod((sx * 2.6, 1.4, -0.7), (sx * 2.6, 3.0, -0.95), 0.06) for sx in (-1, 1)], "metal", "Metal")
    return f


def pill_bottle():
    """큰 약병 조형물 (높이 4.6): 갈색 병 + 흰 뚜껑 + 라벨 + 굴러 나온 알약"""
    f = Furniture("PillBottle")
    f.zone("Bottle", [lathe([(0, 0), (1.2, 0), (1.3, 0.2), (1.3, 3.0), (1.0, 3.5), (0.8, 3.6), (0, 3.6)], at=(0, 0, 0), seg=28)], "woodDark")
    f.zone("Cap", [cyl(0.95, 0.9, at=(0, 4.05, 0), bevel=0.1)], "cakeCream")
    f.zone("Label", [lathe([(1.33, 0.9), (1.36, 0.9), (1.36, 2.5), (1.33, 2.5)], at=(0, 0, 0), seg=28)], "surface")
    f.zone("Mark", [bx((0.9, 0.3, 0.1), (0, 1.7, 1.36), r=0.03), bx((0.3, 0.9, 0.1), (0, 1.7, 1.36), r=0.03)], "pharm")
    pills_a, pills_b = [], []
    for i, (x, z, a) in enumerate([(2.0, 0.6, 20), (2.6, -0.3, -40), (1.8, -0.9, 70), (-2.0, 0.9, 10)]):
        (pills_a if i % 2 == 0 else pills_b).append(box((0.9, 0.36, 0.36), at=(x, 0.18, z), r=0.17, rot=R((0, 1, 0), a)))
    f.zone("PillsA", pills_a, "blush")
    f.zone("PillsB", pills_b, "sky")
    return f


def bp_machine():
    """혈압계 (탁자 + 팔 넣는 통 + 화면)"""
    f = Furniture("BpMachine")
    f.zone("Table", [bx((3.0, 0.2, 2.2), (0, 2.6, 0), r=0.06)] + [rod((sx * 1.3, 2.6, sz * 0.9), (sx * 1.3, 0.05, sz * 0.9), 0.07) for sx in (-1, 1) for sz in (-1, 1)], "cakeCream")
    f.zone("Body", [bx((1.6, 1.3, 1.6), (-0.4, 3.35, -0.1), r=0.2)], "surface")
    f.zone("Cuff", [cyl(0.5, 1.7, at=(-0.4, 3.3, -0.1), axis="z")], "ink")
    f.zone("Screen", [bx((0.9, 0.6, 0.1), (0.9, 3.2, 0.2), r=0.05, rot=R((1, 0, 0), -30))], "neonCyan", "Neon")
    return f


BUILDERS = [pharm_counter, med_shelf, pharm_cross, wait_bench, pill_bottle, bp_machine]


def main():
    lib.reset()
    furniture = []
    for index, build in enumerate(BUILDERS):
        f = build()
        d.put(f, -18 + (index % 3) * 16, -6 + (index // 3) * 13, y=3 if f.name == "PharmCross" else 0)
        furniture.append(f)
    lib.export(os.path.join(OUT, "fbx", "pharmacy_set.fbx"), furniture, os.path.join(OUT, "fbx", "pharmacy_set.json"))
    shops.glassify()
    if "--no-render" not in sys.argv:
        lib.render(os.path.join(OUT, "preview", "pharmacy_set.png"), eye=(0, 26, 34), target=(0, 2, 2), width=1800, height=1000, lens=40, floor="stone", samples=40)
    for f in furniture:
        print(f.name, len(f.zones), sum(z["triangles"] for z in f.zones))
    print(f"DONE furniture={len(furniture)} zones={sum(len(f.zones) for f in furniture)}")


if __name__ == "__main__":
    main()
