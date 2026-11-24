# 리뉴얼 추가 세트: 푸드트럭 · 체력 단련실 기구 · 대충상사 옥상 소품
# 실행: /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/renewal_extra_set.py
# 좌표는 로블록스 기준(스터드, Y 위, 원점 = 바닥 가운데, 앞 = +Z).

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import lib  # noqa: E402
import drafts_spaces as d  # noqa: E402
import street_shops_set as shops  # noqa: E402  (색 표를 같이 써요)
from lib import Furniture, R, ball, box, cyl, lathe, rod  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "salary")
lib.PALETTE.update({"rubber": (58, 96, 150), "tub": (150, 60, 52)})
bx = shops.bx


def food_truck():
    """푸드트럭 (길이 21 · 높이 9 · 깊이 7.4): 앞(+Z)에 판매 창구와 차양, +X 쪽이 운전석"""
    f = Furniture("FoodTruck")
    f.zone("Body", [bx((15.0, 6.6, 7.0), (-2.0, 5.0, 0), r=0.5), bx((5.2, 4.6, 6.8), (7.8, 4.0, 0), r=0.6)], "coral")
    f.zone("Stripe", [bx((15.1, 0.7, 7.1), (-2.0, 2.4, 0), r=0.1), bx((5.3, 0.7, 6.9), (7.8, 2.4, 0), r=0.1)], "cakeCream")
    f.zone("Window", [bx((8.6, 3.0, 0.3), (-2.6, 5.6, 3.42), r=0.12), bx((2.6, 3.4, 0.3), (-8.0, 5.0, -3.42), r=0.1)], "ink")
    f.zone("Glass", [bx((0.3, 2.2, 5.6), (10.3, 4.9, 0), r=0.2, rot=R((0, 0, 1), -14)), bx((3.0, 1.9, 0.2), (8.0, 5.0, 3.36), r=0.15), bx((3.0, 1.9, 0.2), (8.0, 5.0, -3.36), r=0.15)], "glass", "Glass")
    f.zone("Counter", [bx((9.4, 0.3, 1.6), (-2.6, 3.9, 4.1), r=0.08)] + [rod((-2.6 + sx * 4.2, 3.8, 4.7), (-2.6 + sx * 4.2, 2.6, 3.6), 0.07) for sx in (-1, 1)], "woodLight", "Wood")
    a, b = [], []
    for i in range(10):
        x = -6.9 + i * 0.96
        slab = bx((0.96, 0.12, 3.2), (x, 8.0, 4.7), r=0.02, rot=R((1, 0, 0), 20))
        flap = cyl(0.48, 0.1, at=(x, 7.42, 6.2), axis="z")
        (a if i % 2 == 0 else b).extend([slab, flap])
    f.zone("AwningA", a, "red", "Fabric")
    f.zone("AwningB", b, "cakeCream", "Fabric")
    f.zone("Wheels", [cyl(1.25, 0.9, at=(x, 1.25, sz * 3.2), axis="z", bevel=0.2) for x in (-6.5, 6.6) for sz in (-1, 1)], "ink")
    f.zone("Hubs", [cyl(0.55, 0.96, at=(x, 1.25, sz * 3.2), axis="z") for x in (-6.5, 6.6) for sz in (-1, 1)] + [bx((0.5, 0.7, 7.2), (10.5, 2.0, 0), r=0.15), bx((0.5, 0.7, 7.2), (-9.6, 2.0, 0), r=0.15)], "metal", "Metal")
    f.zone("Lights", [ball((0.3, 0.7, 0.9), at=(10.45, 3.0, sz * 2.4)) for sz in (-1, 1)], "yellowSoft", "Neon")
    f.zone("Sign", [bx((7.0, 1.6, 0.4), (-2.6, 9.1, 0), r=0.2)] + [bx((0.3, 0.8, 0.3), (-2.6 + sx * 2.6, 8.5, 0), r=0.05) for sx in (-1, 1)], "yellow")
    f.zone("Menu", [bx((1.6, 1.3, 0.1), (-5.4 + i * 2.0, 5.9, 3.6), r=0.05) for i in range(2)], "cakeCream")
    f.zone("Food", [ball((0.7, 0.4, 0.5), at=(0.2 + i * 0.9, 4.25, 4.2)) for i in range(3)], "yellow")
    return f


def gym_bike():
    """실내 자전거 (앞 = 핸들 쪽 +Z, 안장은 z -0.7 · 높이 2.3)"""
    f = Furniture("GymBike")
    f.zone("Base", [bx((0.6, 0.3, 4.6), (0, 0.15, 0), r=0.08)] + [bx((2.6, 0.3, 0.5), (0, 0.15, dz), r=0.1) for dz in (-2.1, 2.1)], "ink")
    f.zone("Frame", [rod((0, 0.3, -0.7), (0, 2.1, -0.7), 0.16), rod((0, 0.3, 1.6), (0, 3.5, 2.7), 0.16), rod((0, 1.4, -0.7), (0, 1.6, 1.5), 0.14)], "metal", "Metal")
    f.zone("Wheel", [cyl(1.15, 0.5, at=(0, 1.6, 1.5), axis="x", bevel=0.1)], "coral")
    f.zone("Hub", [cyl(0.5, 0.56, at=(0, 1.6, 1.5), axis="x")], "ink")
    f.zone("Saddle", [bx((1.1, 0.3, 1.5), (0, 2.25, -0.75), r=0.14)], "ink")
    f.zone("Bars", [rod((-1.1, 3.6, 2.6), (1.1, 3.6, 2.6), 0.1)] + [rod((sx * 1.1, 3.6, 2.6), (sx * 1.1, 3.75, 2.0), 0.1) for sx in (-1, 1)], "ink")
    f.zone("Screen", [bx((1.1, 0.7, 0.12), (0, 4.05, 2.95), r=0.06, rot=R((1, 0, 0), 20))], "neonCyan", "Neon")
    f.zone("Pedals", [rod((-0.8, 1.1, 0.4), (0.8, 1.1, 0.4), 0.06)] + [bx((0.5, 0.14, 0.8), (sx * 0.8, 1.1, 0.4), r=0.04) for sx in (-1, 1)], "ink")
    return f


def gym_rower():
    """로잉머신 (앞 = 바람 바퀴 쪽 +Z, 의자는 z -1.2 · 높이 0.85)"""
    f = Furniture("GymRower")
    f.zone("Rail", [bx((0.5, 0.3, 8.0), (0, 0.5, -0.5), r=0.08)], "metal", "Metal")
    f.zone("Feet", [bx((2.0, 0.3, 0.5), (0, 0.15, dz), r=0.1) for dz in (-4.3, 3.3)] + [bx((0.4, 0.5, 0.4), (0, 0.3, dz), r=0.05) for dz in (-4.3, 3.3)], "ink")
    f.zone("Fan", [cyl(0.95, 1.5, at=(0, 1.3, 3.5), axis="x", bevel=0.14)], "coral")
    f.zone("FanCover", [cyl(0.6, 1.6, at=(0, 1.3, 3.5), axis="x"), bx((1.0, 1.0, 1.0), (0, 0.9, 2.9), r=0.15)], "ink")
    f.zone("Pads", [bx((0.8, 0.16, 1.1), (sx * 0.55, 1.0, 2.2), r=0.05, rot=R((1, 0, 0), -35)) for sx in (-1, 1)], "ink")
    f.zone("Handle", [rod((-0.9, 1.5, 2.6), (0.9, 1.5, 2.6), 0.08), rod((0, 1.5, 2.6), (0, 1.4, 3.0), 0.03)], "ink")
    f.zone("Screen", [bx((0.9, 0.6, 0.1), (0, 2.5, 3.4), r=0.05, rot=R((1, 0, 0), 25)), rod((0, 2.0, 3.6), (0, 2.5, 3.5), 0.06)], "neonCyan", "Neon")
    return f


def gym_sandbag():
    """샌드백 (바닥 매트 + 천장에서 내려온 사슬 끝의 가방. 가방 중심 높이 4, z +1.6)"""
    f = Furniture("GymSandbag")
    f.zone("Bag", [cyl(1.0, 4.0, at=(0, 4.0, 1.6), bevel=0.3)], "coral", "Fabric")
    f.zone("Bands", [cyl(1.03, 0.25, at=(0, y, 1.6)) for y in (2.7, 5.3)], "ink")
    f.zone("Chain", [rod((sx * 0.6, 6.0, 1.6 + sz * 0.6), (0, 7.2, 1.6), 0.04) for sx, sz in ((1, 0), (-1, 0), (0, 1), (0, -1))] + [cyl(0.12, 0.3, at=(0, 7.3, 1.6))], "metal", "Metal")
    f.zone("Mat", [bx((4.0, 0.14, 5.0), (0, 0.07, 0), r=0.05)], "sky")
    return f


def gym_mat():
    """스트레칭 자리: 요가 매트 + 말아 둔 매트 + 물병 + 작은 아령"""
    f = Furniture("GymMat")
    f.zone("Mat", [bx((3.0, 0.12, 6.5), (0, 0.06, 0), r=0.05)], "sky")
    f.zone("Roll", [cyl(0.28, 3.0, at=(0, 0.3, 3.5), axis="x", bevel=0.04)], "lilac")
    f.zone("Bottle", [cyl(0.16, 0.6, at=(1.9, 0.3, 1.0), bevel=0.05), cyl(0.09, 0.14, at=(1.9, 0.66, 1.0))], "mint")
    f.zone("Dumbbells", [cyl(0.2, 0.26, at=(-1.9 + sx * 0.3, 0.2, 0.6 + k * 0.7), axis="x", bevel=0.04) for sx in (-1, 1) for k in range(2)] + [rod((-2.2, 0.2, 0.6 + k * 0.7), (-1.6, 0.2, 0.6 + k * 0.7), 0.06) for k in range(2)], "ink")
    return f


def gym_ball():
    """밸런스 볼 (지름 3.2) + 받침 고리"""
    f = Furniture("GymBall")
    f.zone("Ball", [ball(3.2, at=(0, 1.6, 0), seg=28)], "yellow")
    f.zone("Ring", [lathe([(1.0, 0), (1.3, 0), (1.3, 0.25), (1.0, 0.25)], at=(0, 0, 0), seg=28)], "ink")
    f.zone("Mat", [cyl(1.8, 0.08, at=(0, 0.04, 0))], "navy")
    return f


def pyeongsang():
    """평상 (가로 8 · 깊이 5 · 높이 1.4): 나무 마루 + 방석 + 작은 상"""
    f = Furniture("Pyeongsang")
    f.zone("Deck", [bx((0.72, 0.2, 5.0), (-3.6 + i * 0.8, 1.3, 0), r=0.04) for i in range(10)], "woodLight", "Wood")
    f.zone("Frame", [bx((8.0, 0.3, 0.3), (0, 1.05, sz * 2.3), r=0.04) for sz in (-1, 1)] + [bx((0.4, 1.0, 0.4), (sx * 3.6, 0.5, sz * 2.2), r=0.05) for sx in (-1, 1) for sz in (-1, 1)], "woodDark", "Wood")
    f.zone("Cushions", [bx((1.6, 0.25, 1.6), (-2.4 + i * 2.4, 1.55, -1.2), r=0.1) for i in range(3)], "coral", "Fabric")
    f.zone("Table", [bx((2.4, 0.14, 1.5), (0.6, 2.0, 0.9), r=0.05)] + [bx((0.14, 0.6, 0.14), (0.6 + sx * 1.0, 1.7, 0.9 + sz * 0.55), r=0.03) for sx in (-1, 1) for sz in (-1, 1)], "wood", "Wood")
    f.zone("Kettle", [lathe([(0, 0), (0.3, 0), (0.36, 0.25), (0.26, 0.5), (0.1, 0.56), (0, 0.56)], at=(0.2, 2.07, 0.9)), cyl(0.12, 0.2, at=(1.1, 2.17, 0.8))], "yellow", "Metal")
    return f


def plastic_chair():
    """파란 플라스틱 의자 (옥상·골목의 그 의자)"""
    f = Furniture("PlasticChair")
    f.zone("Chair", [bx((1.5, 0.16, 1.5), (0, 1.55, 0), r=0.06), bx((1.5, 1.5, 0.14), (0, 2.3, -0.7), r=0.06, rot=R((1, 0, 0), -8))]
           + [rod((sx * 0.6, 1.5, sz * 0.6), (sx * 0.72, 0.03, sz * 0.72), 0.07) for sx in (-1, 1) for sz in (-1, 1)], "rubber")
    return f


def tub_planter():
    """고무 대야 텃밭: 빨간 대야 + 흙 + 상추와 파"""
    f = Furniture("TubPlanter")
    f.zone("Tub", [lathe([(0, 0), (1.3, 0), (1.6, 1.1), (1.7, 1.1), (1.7, 1.2), (1.5, 1.2), (1.2, 0.12), (0, 0.12)], at=(0, 0, 0), seg=28)], "tub")
    f.zone("Soil", [cyl(1.5, 0.1, at=(0, 1.0, 0))], "choco")
    f.zone("Lettuce", [ball((0.8, 0.5, 0.8), at=(0.8 * math.cos(a), 1.25, 0.8 * math.sin(a))) for a in [2 * math.pi * k / 5 for k in range(5)]], "grassLight")
    f.zone("Onions", [rod((0.15 * k - 0.2, 1.05, 0.1 * k - 0.1), (0.2 * k - 0.3, 2.3, 0.14 * k - 0.2), 0.05) for k in range(4)], "grass")
    return f


def ac_unit():
    """실외기 (가로 4 · 높이 3 · 깊이 1.6): 앞에 둥근 팬 망"""
    f = Furniture("AcUnit")
    f.zone("Body", [bx((4.0, 3.0, 1.6), (0, 1.6, 0), r=0.12), bx((3.6, 0.2, 1.2), (0, 0.1, 0), r=0.04)], "surface", "Metal")
    f.zone("Fan", [cyl(1.15, 0.12, at=(-0.6, 1.6, 0.82), axis="z")], "ink")
    f.zone("Grille", [lathe([(r - 0.04, -0.04), (r + 0.04, -0.04), (r + 0.04, 0.04), (r - 0.04, 0.04)], at=(-0.6, 1.6, 0.92), seg=24, rot=R((1, 0, 0), 90)) for r in (0.35, 0.7, 1.05)]
           + [rod((-0.6 - 1.1, 1.6, 0.92), (-0.6 + 1.1, 1.6, 0.92), 0.03), rod((-0.6, 0.5, 0.92), (-0.6, 2.7, 0.92), 0.03)], "metal", "Metal")
    f.zone("Vents", [bx((0.9, 0.08, 0.06), (1.35, 0.9 + i * 0.28, 0.82), r=0.02) for i in range(6)], "line")
    return f


def clothes_line():
    """빨랫줄 (가로 10): 기둥 두 개 + 줄 + 널어 둔 옷"""
    f = Furniture("ClothesLine")
    f.zone("Poles", [cyl(0.12, 7.0, at=(sx * 5, 3.5, 0)) for sx in (-1, 1)] + [bx((1.0, 0.2, 1.0), (sx * 5, 0.1, 0), r=0.05) for sx in (-1, 1)] + [rod((sx * 5, 6.8, -0.8), (sx * 5, 6.8, 0.8), 0.07) for sx in (-1, 1)], "metal", "Metal")
    f.zone("Lines", [rod((-5, 6.8, sz * 0.7), (5, 6.8, sz * 0.7), 0.025) for sz in (-1, 1)], "ink")
    f.zone("White", [bx((3.2, 3.6, 0.08), (-2.6, 5.0, -0.7), r=0.03), bx((1.4, 1.6, 0.08), (3.4, 6.0, 0.7), r=0.03)], "cakeCream", "Fabric")
    f.zone("Blue", [bx((2.6, 3.2, 0.08), (1.2, 5.2, -0.7), r=0.03), bx((1.2, 1.4, 0.08), (-0.4, 6.1, 0.7), r=0.03)], "sky", "Fabric")
    f.zone("Pink", [bx((1.6, 2.0, 0.08), (-3.4, 5.8, 0.7), r=0.03), bx((1.0, 1.2, 0.08), (1.4, 6.2, 0.7), r=0.03)], "blush", "Fabric")
    return f


BUILDERS = [food_truck, gym_bike, gym_rower, gym_sandbag, gym_mat, gym_ball, pyeongsang, plastic_chair, tub_planter, ac_unit, clothes_line]


def main():
    lib.reset()
    furniture = []
    for index, build in enumerate(BUILDERS):
        f = build()
        d.put(f, -30 + (index % 4) * 18 + (6 if f.name == "FoodTruck" else 0), -14 + (index // 4) * 13)
        furniture.append(f)
    names = [f.name for f in furniture]
    assert len(set(names)) == len(names), names
    lib.export(os.path.join(OUT, "fbx", "renewal_extra_set.fbx"), furniture, os.path.join(OUT, "fbx", "renewal_extra_set.json"))
    shops.glassify()
    if "--no-render" not in sys.argv:
        lib.render(os.path.join(OUT, "preview", "renewal_extra_set.png"), eye=(0, 40, 50), target=(0, 2, 0), width=2000, height=1150, lens=40, floor="stone", samples=40)
    for f in furniture:
        print(f.name, len(f.zones), sum(z["triangles"] for z in f.zones))
    print(f"DONE furniture={len(furniture)} zones={sum(len(f.zones) for f in furniture)} triangles={sum(z['triangles'] for f in furniture for z in f.zones)}")


if __name__ == "__main__":
    main()
