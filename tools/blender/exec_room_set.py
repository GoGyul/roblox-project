# 임원실 세트 (눈치물산 12층, 이사부터): 큰 책상 · 가죽 의자 · 가죽 소파 · 탁자 · 미니 냉장고
#   · 트로피 선반 · 벽 패널(징두리 판벽) · 러그 · 스탠드 조명 · 액자
# 실행: /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/exec_room_set.py
# 좌표는 로블록스 기준(스터드, Y 위, 원점 = 바닥 가운데, 앞 = +Z).

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import lib  # noqa: E402
import drafts_spaces as d  # noqa: E402
import street_shops_set as shops  # noqa: E402
from lib import Furniture, R, ball, box, cyl, lathe, rod  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "salary")
# 새 색: leather(짙은 가죽) · wine(러그) — shared/SalaryTheme.luau 에도 같은 값이 있어야 해요
lib.PALETTE.update({"leather": (78, 50, 40), "wine": (122, 40, 52), "pharm": (58, 148, 112)})
bx = shops.bx


def exec_desk():
    """임원 책상 (가로 9.4 · 높이 3.5 · 깊이 4.3): 양쪽 서랍장 + 두꺼운 상판 + 명패·스탠드·노트북. 앞(+Z) = 손님 쪽"""
    f = Furniture("ExecDesk")
    f.zone("Top", [bx((9.4, 0.32, 4.3), (0, 3.34, 0), r=0.1)], "espresso", "Wood")
    f.zone("Body", [bx((2.5, 3.1, 3.8), (sx * 3.3, 1.6, 0), r=0.08) for sx in (-1, 1)] + [bx((4.3, 2.5, 0.25), (0, 1.9, 1.7), r=0.05)], "choco", "Wood")
    f.zone("Inset", [bx((1.9, 2.3, 0.1), (sx * 3.3, 1.7, 1.92), r=0.04) for sx in (-1, 1)] + [bx((3.5, 1.7, 0.1), (0, 1.9, 1.84), r=0.04)], "espresso", "Wood")
    f.zone("Trim", [bx((0.8, 0.1, 0.12), (sx * 3.3, 0.75 + i * 0.95, -1.93), r=0.03) for sx in (-1, 1) for i in range(3)]
           + [bx((9.42, 0.07, 4.32), (0, 3.16, 0), r=0.02)], "gold", "Metal")
    f.zone("Drawers", [bx((2.1, 0.8, 0.08), (sx * 3.3, 0.75 + i * 0.95, -1.9), r=0.03) for sx in (-1, 1) for i in range(3)], "espresso", "Wood")
    f.zone("Pad", [bx((3.8, 0.06, 2.2), (0, 3.53, -0.7), r=0.02)], "leather", "Leather")
    f.zone("Plate", [bx((2.6, 0.5, 0.3), (0, 3.78, 1.5), r=0.05, rot=R((1, 0, 0), 12))]
           + [cyl(0.4, 0.1, at=(-3.5, 3.55, 0.6))] + [rod((-3.5, 3.6, 0.6), (-3.5, 4.5, 0.6), 0.06)], "gold", "Metal")
    f.zone("Shade", [bx((1.5, 0.45, 0.7), (-3.5, 4.6, 0.75), r=0.2)], "pharm")
    f.zone("Gear", [bx((1.9, 0.08, 1.3), (1.0, 3.55, -0.6), r=0.03), bx((1.9, 1.2, 0.07), (1.0, 4.1, 0.1), r=0.03, rot=R((1, 0, 0), -14)),
                    cyl(0.24, 0.6, at=(3.4, 3.8, 0.9)), bx((1.1, 0.28, 0.8), (3.3, 3.64, -0.6), r=0.08)], "ink")
    f.zone("Paper", [bx((1.3, 0.05, 1.7), (-1.5, 3.53, -0.7), r=0.01, rot=R((0, 1, 0), 8)), bx((1.3, 0.05, 1.7), (-1.4, 3.57, -0.6), r=0.01, rot=R((0, 1, 0), -5))], "cakeCream")
    return f


def exec_chair():
    """임원 의자 (가로 3.2 · 높이 5.8): 높은 등받이 가죽 회전의자"""
    f = Furniture("ExecChair")
    f.zone("Base", [rod((0, 0.3, 0), (1.35 * __import__("math").cos(a), 0.18, 1.35 * __import__("math").sin(a)), 0.1) for a in [k * 1.2566 for k in range(5)]]
           + [cyl(0.22, 1.3, at=(0, 0.95, 0))] + [rod((sx * 1.5, 2.0, 0.7), (sx * 1.5, 2.85, 0.3), 0.08) for sx in (-1, 1)], "metal", "Metal")
    f.zone("Seat", [bx((2.8, 0.7, 2.6), (0, 1.95, 0.1), r=0.3), bx((2.7, 3.5, 0.6), (0, 4.0, -1.15), r=0.3, rot=R((1, 0, 0), -6))]
           + [bx((0.36, 0.26, 1.7), (sx * 1.5, 2.95, 0.0), r=0.1) for sx in (-1, 1)], "leather", "Leather")
    f.zone("Buttons", [ball(0.16, at=(-0.7 + c * 0.7, 3.4 + r * 0.9, -0.82 - r * 0.09)) for c in range(3) for r in range(3)], "gold", "Metal")
    return f


def exec_sofa():
    """가죽 소파 (가로 8.2 · 높이 3.6 · 깊이 3.2): 세 자리 + 쿠션"""
    f = Furniture("ExecSofa")
    f.zone("Frame", [bx((7.9, 1.0, 2.9), (0, 0.8, 0), r=0.2), bx((7.9, 2.4, 0.8), (0, 2.3, -1.1), r=0.3)]
           + [bx((0.9, 2.1, 3.1), (sx * 3.75, 1.65, 0), r=0.3) for sx in (-1, 1)], "leather", "Leather")
    f.zone("Cushions", [bx((2.15, 0.6, 2.2), (-2.2 + i * 2.2, 1.55, 0.3), r=0.22) for i in range(3)]
           + [bx((2.15, 1.5, 0.5), (-2.2 + i * 2.2, 2.6, -0.65), r=0.2, rot=R((1, 0, 0), -8)) for i in range(3)], "choco", "Leather")
    f.zone("Feet", [cyl(0.16, 0.32, at=(sx * 3.6, 0.16, sz * 1.2)) for sx in (-1, 1) for sz in (-1, 1)], "gold", "Metal")
    f.zone("Pillow", [bx((1.2, 1.2, 0.45), (-2.5, 2.4, 0.15), r=0.18, rot=R((1, 0, 0), -14))], "wine", "Fabric")
    return f


def exec_table():
    """소파 탁자 (가로 4.4 · 높이 1.3 · 깊이 2.6): 원목 상판 + 금색 다리 + 찻잔 쟁반 · 책"""
    f = Furniture("ExecTable")
    f.zone("Top", [bx((4.4, 0.22, 2.6), (0, 1.2, 0), r=0.08)], "espresso", "Wood")
    f.zone("Shelf", [bx((3.8, 0.12, 2.0), (0, 0.45, 0), r=0.04)], "choco", "Wood")
    f.zone("Legs", [rod((sx * 1.95, 0.05, sz * 1.05), (sx * 1.95, 1.15, sz * 1.05), 0.08) for sx in (-1, 1) for sz in (-1, 1)]
           + [bx((1.7, 0.07, 1.1), (-0.9, 1.35, 0), r=0.03)], "gold", "Metal")
    f.zone("Cups", [cyl(0.2, 0.3, at=(-1.3 + i * 0.75, 1.53, 0.05), bevel=0.04) for i in range(2)]
           + [bx((1.0, 0.16, 0.75), (1.15, 1.56, 0.25), r=0.02, rot=R((0, 1, 0), -8))], "cakeCream")
    f.zone("Book", [bx((1.2, 0.26, 0.85), (1.1, 1.44, 0.2), r=0.03, rot=R((0, 1, 0), 14))], "wine")
    return f


def exec_fridge():
    """미니 냉장고 (가로 2.6 · 높이 5.1): 유리문 안에 캔이 보이는 음료 냉장고 + 위에 커피 머신"""
    f = Furniture("ExecFridge")
    f.zone("Body", [bx((2.6, 4.2, 2.3), (0, 2.2, -0.15), r=0.12)]
           + [bx((0.28, 3.9, 0.3), (sx * 1.16, 2.25, 1.1), r=0.05) for sx in (-1, 1)]
           + [bx((2.6, 0.3, 0.3), (0, sy, 1.1), r=0.05) for sy in (0.45, 4.05)], "ink")
    f.zone("Shelves", [bx((2.05, 0.08, 0.3), (0, 1.0 + i * 1.0, 1.05), r=0.01) for i in range(3)], "metal", "Metal")
    cans_a, cans_b = [], []
    for row in range(3):
        for i in range(4):
            (cans_a if (i + row) % 2 == 0 else cans_b).append(cyl(0.17, 0.62, at=(-0.72 + i * 0.48, 1.36 + row * 1.0, 1.06), seg=14))
    f.zone("CansA", cans_a, "cakeCream")
    f.zone("CansB", cans_b, "gold", "Metal")
    f.zone("Glass", [bx((2.05, 3.3, 0.08), (0, 2.25, 1.24), r=0.02)], "glass", "Glass")
    f.zone("Handle", [rod((0.82, 1.6, 1.36), (0.82, 2.9, 1.36), 0.06)], "gold", "Metal")
    f.zone("Machine", [bx((1.3, 0.85, 1.2), (-0.4, 4.73, -0.2), r=0.12), cyl(0.2, 0.3, at=(0.75, 4.45, 0.2), bevel=0.04)], "metal", "Metal")
    return f


def exec_shelf():
    """트로피 선반 (가로 6, 벽에 붙여요. 원점 = 바닥, 선반 높이 6): 트로피 세 개 + 상장 액자 둘"""
    f = Furniture("ExecShelf")
    f.zone("Board", [bx((6.0, 0.3, 1.1), (0, 6.0, 0.55), r=0.06)], "espresso", "Wood")
    trophies = [bx((0.5, 0.5, 0.12), (sx * 2.2, 5.6, 0.3), r=0.03, rot=R((1, 0, 0), 0)) for sx in (-1, 1)]
    for i, h in enumerate((1.5, 2.0, 1.3)):
        x = -1.8 + i * 1.8
        trophies.append(lathe([(0, 0), (0.34, 0), (0.34, 0.1), (0.1, 0.22), (0.08, h * 0.45), (0.18, h * 0.5), (0.42, h * 0.72), (0.5, h), (0.44, h), (0.36, h * 0.76), (0, h * 0.62)], at=(x, 6.33, 0.55), seg=22))
        for sx in (-1, 1):
            trophies.append(rod((x + sx * 0.44, 6.33 + h * 0.92, 0.55), (x + sx * 0.7, 6.33 + h * 0.74, 0.55), 0.04))
    f.zone("Trophies", trophies, "gold", "Metal")
    f.zone("Bases", [bx((0.8, 0.18, 0.8), (-1.8 + i * 1.8, 6.24, 0.55), r=0.04) for i in range(3)], "ink")
    f.zone("Frames", [bx((2.0, 1.5, 0.12), (sx * 1.5, 9.6, 0.08), r=0.04) for sx in (-1, 1)], "gold", "Metal")
    f.zone("Awards", [bx((1.7, 1.2, 0.05), (sx * 1.5, 9.6, 0.15), r=0.02) for sx in (-1, 1)], "cakeCream")
    return f


def exec_panel():
    """벽 패널 (가로 4.875 · 높이 10 · 두께 0.3, 뒤가 벽): 짙은 원목 판벽. 옆으로 이어 붙이면 기둥이 맞물려요"""
    f = Furniture("ExecPanel")
    w = 4.875
    f.zone("Back", [bx((w, 10.0, 0.1), (0, 5.0, 0.05), r=0.01)], "choco", "Wood")
    f.zone("Frame", [bx((0.45, 10.0, 0.3), (sx * (w / 2 - 0.225), 5.0, 0.15), r=0.03) for sx in (-1, 1)]
           + [bx((w - 0.86, 1.0, 0.26), (0, 0.5, 0.13), r=0.03), bx((w - 0.04, 0.45, 0.36), (0, 4.2, 0.18), r=0.05), bx((w - 0.04, 0.6, 0.36), (0, 9.68, 0.18), r=0.05)], "espresso", "Wood")
    f.zone("Insets", [bx((3.3, 2.5, 0.14), (0, 2.5, 0.12), r=0.05), bx((3.3, 4.3, 0.14), (0, 6.85, 0.12), r=0.05)], "woodDark", "Wood")
    f.zone("Line", [bx((w - 0.06, 0.08, 0.4), (0, 4.47, 0.2), r=0.02)], "gold", "Metal")
    return f


def exec_rug():
    """러그 (가로 11 · 세로 8): 와인색 바탕 + 금색 테두리 줄"""
    f = Furniture("ExecRug")
    f.zone("Base", [bx((11.0, 0.1, 8.0), (0, 0.05, 0), r=0.03)], "wine", "Fabric")
    f.zone("Border", [bx((9.8, 0.03, 0.18), (0, 0.11, sz * 3.4), r=0.01) for sz in (-1, 1)] + [bx((0.18, 0.03, 6.98), (sx * 4.9, 0.11, 0), r=0.01) for sx in (-1, 1)]
           + [bx((0.7, 0.03, 0.7), (sx * 4.9, 0.112, sz * 3.4), r=0.01, rot=R((0, 1, 0), 45)) for sx in (-1, 1) for sz in (-1, 1)]
           + [bx((2.2, 0.03, 2.2), (0, 0.112, 0), r=0.01, rot=R((0, 1, 0), 45))], "gold", "Fabric")
    return f


def exec_lamp():
    """스탠드 조명 (높이 7.4): 금색 기둥 + 크림색 갓"""
    f = Furniture("ExecLamp")
    f.zone("Stand", [cyl(0.8, 0.16, at=(0, 0.08, 0), bevel=0.05), rod((0, 0.1, 0), (0, 5.9, 0), 0.08)], "gold", "Metal")
    f.zone("Shade", [lathe([(0.55, 5.6), (1.15, 5.6), (0.75, 7.3), (0.5, 7.3)], at=(0, 0, 0), seg=28)], "cakeCream", "Fabric")
    f.zone("Glow", [ball(0.6, at=(0, 6.1, 0))], "yellowSoft", "Neon")
    return f


def exec_picture():
    """액자 (가로 4.4 · 세로 3.2, 벽에 붙여요. 원점 = 바닥, 그림 가운데 높이 7.6): 금색 틀 + 산 그림"""
    f = Furniture("ExecPicture")
    f.zone("Frame", [bx((4.4, 3.2, 0.16), (0, 7.6, 0.08), r=0.06)], "gold", "Metal")
    f.zone("Canvas", [bx((3.8, 2.6, 0.06), (0, 7.6, 0.17), r=0.02)], "navy")
    # 계단식 산 두 개 (틀 밖으로 삐져나오지 않게 네모로 쌓아요)
    hills = []
    for cx, base, steps in ((-0.8, 2.0, 4), (0.95, 1.5, 3)):
        for k in range(steps):
            hills.append(bx((base * (1 - k / steps), 0.34, 0.05), (cx, 6.5 + k * 0.34, 0.2), r=0.01))
    f.zone("Hills", hills, "mint")
    f.zone("Sun", [cyl(0.4, 0.05, at=(1.1, 8.3, 0.2), axis="z")], "yellow")
    return f


BUILDERS = [exec_panel, exec_shelf, exec_picture, exec_lamp, exec_fridge, exec_desk, exec_chair, exec_sofa, exec_table, exec_rug]  # (뒷줄에 키 큰 것)


def main():
    lib.reset()
    furniture = []
    for index, build in enumerate(BUILDERS):
        f = build()
        d.put(f, -24 + (index % 5) * 12, -8 + (index // 5) * 13)
        furniture.append(f)
    lib.export(os.path.join(OUT, "fbx", "exec_room_set.fbx"), furniture, os.path.join(OUT, "fbx", "exec_room_set.json"))
    shops.glassify()
    if "--no-render" not in sys.argv:
        lib.render(os.path.join(OUT, "preview", "exec_room_set.png"), eye=(0, 30, 50), target=(0, 3, -1), width=1800, height=1000, lens=30, floor="stone", samples=40)
    for f in furniture:
        print(f.name, len(f.zones), sum(z["triangles"] for z in f.zones))
    print(f"DONE furniture={len(furniture)} zones={sum(len(f.zones) for f in furniture)}")


if __name__ == "__main__":
    main()
