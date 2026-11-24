# 눈치 스트리트 가게 리뉴얼 세트: 카페 · 디저트 · 뽑기 천국 · 오락실 · 가게 외관
# 실행: /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/street_shops_set.py
# 좌표는 로블록스 기준(스터드, Y 위, 원점 = 바닥 가운데, 앞 = +Z). 천장에 다는 것은 원점이 천장(위)이에요.
# 색 이름은 shared/SalaryTheme.luau 의 Theme.Mesh 에 있어야 해요 (새 색은 NEW_COLORS 참고).

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402

import lib  # noqa: E402
import drafts_spaces as d  # noqa: E402
from lib import Furniture, R, ball, box, cyl, lathe, rod  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "salary")

# 차분한 월드 색 (Theme.Mesh) + 이번 세트에서 새로 쓰는 색
lib.PALETTE.update({
    "cream": (232, 229, 221), "surface": (232, 230, 225), "navy": (48, 50, 55), "mint": (122, 160, 148), "mintDark": (70, 110, 102),
    "sage": (142, 156, 150), "sky": (128, 160, 186), "coral": (190, 110, 98), "yellow": (206, 170, 92), "yellowSoft": (255, 236, 200),
    "wood": (176, 142, 104), "woodLight": (203, 172, 132), "woodDark": (120, 92, 66), "grass": (74, 128, 84), "grassLight": (104, 152, 100),
    "metal": (176, 180, 184), "stone": (206, 202, 194), "seat": (84, 92, 104), "screen": (170, 200, 225), "line": (168, 176, 182),
})
NEW_COLORS = {
    "espresso": (78, 58, 46), "blush": (226, 184, 184), "lilac": (168, 160, 204), "arcade": (62, 58, 104),
    "neonPink": (255, 120, 180), "neonCyan": (120, 225, 240), "glass": (196, 222, 232), "ink": (36, 38, 44),
    "gold": (208, 170, 96), "red": (196, 74, 66), "cakeCream": (246, 236, 220), "berry": (206, 70, 90), "choco": (104, 70, 52),
}
lib.PALETTE.update(NEW_COLORS)


def bx(size, at, r=0.06, **kw):
    return box(size, at=at, r=r, **kw)


# ───────────────────────── 카페 ─────────────────────────

def cafe_bar():
    """에스프레소 바 (가로 12 · 높이 3.6 · 깊이 2.6): 세로 원목 살 + 돌 상판"""
    f = Furniture("CafeBar")
    f.zone("Body", [bx((11.6, 3.2, 2.2), (0, 1.75, -0.1), r=0.05)], "espresso")
    f.zone("Slats", [bx((0.34, 3.0, 0.16), (-5.5 + i * 0.5, 1.75, 1.06), r=0.04) for i in range(23)], "wood", "Wood")
    f.zone("Top", [bx((12.2, 0.28, 2.9), (0, 3.5, 0), r=0.1)], "stone")
    f.zone("Kick", [bx((11.4, 0.3, 2.0), (0, 0.15, -0.1), r=0.02)], "ink")
    return f


def espresso_machine():
    """에스프레소 머신 + 그라인더 (계산대 위에 올려요, 원점 = 바닥면)"""
    f = Furniture("EspressoMachine")
    f.zone("Body", [bx((2.6, 1.5, 1.5), (0, 0.95, 0), r=0.16), bx((2.2, 0.2, 1.7), (0, 0.1, 0.05), r=0.05)], "metal", "Metal")
    f.zone("Panel", [bx((2.3, 0.7, 0.12), (0, 1.2, 0.78), r=0.04)] + [cyl(0.2, 0.5, at=(sx * 0.6, 0.62, 0.55), bevel=0.04) for sx in (-1, 1)], "ink")
    f.zone("Cups", [cyl(0.17, 0.26, at=(-0.8 + i * 0.4, 1.86, -0.1), r2=0.2) for i in range(5)], "cakeCream")
    f.zone("Grinder", [bx((0.7, 1.0, 0.8), (2.0, 0.5, 0), r=0.1), lathe([(0.18, 0), (0.36, 0.5), (0.36, 0.62), (0, 0.62)], at=(2.0, 1.0, 0))], "ink")
    return f


def pastry_case():
    """유리 진열장 (계산대 위): 빵과 케이크"""
    f = Furniture("PastryCase")
    f.zone("Frame", [bx((4.2, 0.18, 1.7), (0, 0.09, 0), r=0.03), bx((4.2, 0.12, 1.7), (0, 1.9, 0), r=0.03)]
           + [bx((0.1, 1.8, 0.1), (sx * 2.05, 1.0, sz * 0.8), r=0.02) for sx in (-1, 1) for sz in (-1, 1)], "ink")
    f.zone("Glass", [bx((4.0, 1.7, 1.5), (0, 1.0, 0), r=0.02)], "glass", "Glass")
    f.zone("Shelf", [bx((3.9, 0.06, 1.4), (0, 1.0, 0), r=0.01)], "metal", "Metal")
    f.zone("Bread", [ball((0.5, 0.3, 0.36), at=(-1.4 + i * 0.56, 0.35, 0.2)) for i in range(6)], "wood")
    f.zone("Cakes", [cyl(0.24, 0.3, at=(-1.4 + i * 0.7, 1.2, 0.1), bevel=0.05) for i in range(5)], "cakeCream")
    f.zone("Berries", [ball(0.14, at=(-1.4 + i * 0.7, 1.42, 0.1)) for i in range(5)], "berry")
    return f


def menu_board():
    """벽에 거는 메뉴판 (가로 9 · 세로 3.4, 원점 = 판 가운데, 뒤가 벽)"""
    f = Furniture("MenuBoard")
    f.zone("Board", [bx((8.6, 3.0, 0.16), (0, 0, 0.08), r=0.03)], "ink")
    f.zone("Frame", [bx((9.0, 0.2, 0.26), (0, sy * 1.6, 0.13), r=0.04) for sy in (-1, 1)] + [bx((0.2, 3.4, 0.26), (sx * 4.4, 0, 0.13), r=0.04) for sx in (-1, 1)], "wood", "Wood")
    lines = []
    for col in range(3):
        for row in range(4):
            lines.append(bx((1.9 - (row % 2) * 0.5, 0.12, 0.04), (-2.9 + col * 2.9 - (row % 2) * 0.25, 0.75 - row * 0.5, 0.18), r=0.02))
    f.zone("Chalk", lines, "cakeCream")
    f.zone("Accent", [bx((2.2, 0.2, 0.04), (-2.9 + col * 2.9, 1.2, 0.18), r=0.02) for col in range(3)], "yellow")
    return f


def cafe_table():
    """둥근 카페 탁자 (지름 3 · 높이 2.7)"""
    f = Furniture("CafeTable")
    f.zone("Top", [cyl(1.5, 0.16, at=(0, 2.62, 0), bevel=0.06)], "woodLight", "Wood")
    f.zone("Base", [cyl(0.12, 2.5, at=(0, 1.3, 0)), lathe([(0.9, 0), (0.9, 0.06), (0.2, 0.16), (0.12, 0.3), (0, 0.3)], at=(0, 0, 0))], "ink")
    return f


def cafe_chair():
    """카페 의자: 원목 좌판 + 검은 철제 다리 + 굽은 등받이"""
    f = Furniture("CafeChair")
    f.zone("Seat", [cyl(0.72, 0.14, at=(0, 1.6, 0), bevel=0.05)], "wood", "Wood")
    legs = [rod((sx * 0.5, 1.55, sz * 0.5), (sx * 0.62, 0.03, sz * 0.62), 0.05) for sx in (-1, 1) for sz in (-1, 1)]
    back = [rod((sx * 0.55, 1.6, -0.5), (sx * 0.6, 3.0, -0.68), 0.05) for sx in (-1, 1)]
    f.zone("Frame", legs + back, "ink")
    f.zone("Back", [bx((1.4, 0.5, 0.1), (0, 2.8, -0.68), r=0.05, rot=R((1, 0, 0), -6))], "wood", "Wood")
    return f


def bar_stool():
    """높은 스툴 (높이 2.9)"""
    f = Furniture("BarStool")
    f.zone("Seat", [cyl(0.6, 0.22, at=(0, 2.78, 0), bevel=0.08)], "seat", "Fabric")
    f.zone("Frame", [rod((sx * 0.38, 2.7, sz * 0.38), (sx * 0.55, 0.03, sz * 0.55), 0.045) for sx in (-1, 1) for sz in (-1, 1)]
           + [lathe([(0.52, 0), (0.52, 0.06), (0.47, 0.06), (0.47, 0)], at=(0, 1.0, 0))], "ink")
    return f


def pendant_lamp():
    """천장에 다는 조명 (원점 = 천장, 아래로 3.2)"""
    f = Furniture("PendantLamp")
    f.zone("Cord", [cyl(0.03, 2.2, at=(0, -1.1, 0)), cyl(0.2, 0.08, at=(0, -0.04, 0))], "ink")
    f.zone("Shade", [lathe([(0.12, -2.2), (0.2, -2.3), (0.75, -3.0), (0.8, -3.2), (0.74, -3.2), (0.7, -3.02), (0.18, -2.36), (0.1, -2.3)], at=(0, 0, 0))], "ink")
    f.zone("Bulb", [ball(0.42, at=(0, -3.0, 0))], "yellowSoft", "Neon")
    return f


def wall_shelf():
    """벽 선반 (가로 5): 컵·병·작은 화분"""
    f = Furniture("WallShelf")
    f.zone("Plank", [bx((5.0, 0.16, 0.9), (0, 0, 0.45), r=0.04)] + [bx((0.12, 0.5, 0.7), (sx * 2.0, -0.3, 0.4), r=0.03) for sx in (-1, 1)], "woodLight", "Wood")
    f.zone("Cups", [cyl(0.16, 0.3, at=(-2.0 + i * 0.42, 0.23, 0.5), r2=0.19) for i in range(4)], "cakeCream")
    f.zone("Jars", [cyl(0.2, 0.6, at=(0.1 + i * 0.5, 0.38, 0.5), bevel=0.05) for i in range(3)], "glass", "Glass")
    f.zone("Pot", [cyl(0.22, 0.34, at=(2.0, 0.25, 0.5), r2=0.28)], "coral")
    f.zone("Leaves", [ball((0.7, 0.6, 0.6), at=(2.0, 0.75, 0.5))], "grass")
    return f


def booth_sofa():
    """벽에 붙이는 긴 소파 (가로 6 · 등받이 높이 3.6)"""
    f = Furniture("BoothSofa")
    f.zone("Base", [bx((6.0, 0.9, 2.2), (0, 0.45, 0), r=0.06)], "woodDark", "Wood")
    f.zone("Seat", [bx((5.9, 0.6, 2.0), (0, 1.2, 0.1), r=0.2)], "sage", "Fabric")
    f.zone("Back", [bx((1.9, 2.0, 0.5), (-2.0 + i * 2.0, 2.5, -0.8), r=0.22) for i in range(3)], "sage", "Fabric")
    return f


# ───────────────────────── 디저트 ─────────────────────────

def dessert_showcase():
    """케이크 쇼케이스 (가로 8 · 높이 4): 둥근 유리 + 두 단 진열"""
    f = Furniture("DessertShowcase")
    f.zone("Base", [bx((8.0, 1.5, 2.6), (0, 0.75, 0), r=0.08)], "blush")
    f.zone("Trim", [bx((8.1, 0.12, 2.7), (0, 1.56, 0), r=0.04), bx((8.1, 0.14, 1.4), (0, 3.93, -0.6), r=0.04), bx((8.1, 0.2, 2.7), (0, 0.1, 0), r=0.03)], "gold", "Metal")
    f.zone("Glass", [bx((7.8, 2.3, 2.4), (0, 2.75, 0), r=0.5, rv=0.0)], "glass", "Glass")
    f.zone("Shelf", [bx((7.6, 0.06, 2.0), (0, 2.7, 0), r=0.01)], "cakeCream")
    cakes, cream, berries, choco = [], [], [], []
    for i in range(5):
        x = -3.0 + i * 1.5
        cakes.append(cyl(0.5, 0.5, at=(x, 1.9, 0.2), bevel=0.06))
        cream.append(cyl(0.52, 0.1, at=(x, 2.18, 0.2), bevel=0.04))
        berries.append(ball(0.2, at=(x, 2.34, 0.2)))
        choco.append(cyl(0.4, 0.4, at=(x, 2.95, 0.1), bevel=0.06))
        cream.append(ball((0.34, 0.2, 0.34), at=(x, 3.2, 0.1)))
    f.zone("Cake", cakes, "cakeCream")
    f.zone("Cream", cream, "blush")
    f.zone("Berry", berries, "berry")
    f.zone("Choco", choco, "choco")
    return f


def dessert_counter():
    """디저트 계산대 (가로 6): 분홍 몸통 + 돌 상판 + 금색 띠 + 계산기"""
    f = Furniture("DessertCounter")
    f.zone("Body", [bx((5.8, 3.2, 2.0), (0, 1.6, 0), r=0.3, rv=0.0)], "blush")
    f.zone("Panel", [bx((1.5, 2.2, 0.08), (-1.8 + i * 1.8, 1.7, 1.02), r=0.12) for i in range(3)], "cakeCream")
    f.zone("Top", [bx((6.2, 0.26, 2.4), (0, 3.4, 0), r=0.1)], "stone")
    f.zone("Trim", [bx((5.9, 0.1, 2.1), (0, 0.5, 0), r=0.03)], "gold", "Metal")
    f.zone("Register", [bx((1.3, 0.8, 1.0), (1.8, 3.95, -0.1), r=0.1), bx((1.1, 0.7, 0.08), (1.8, 4.5, -0.45), r=0.04, rot=R((1, 0, 0), -15))], "ink")
    return f


def cake_stand():
    """3단 케이크 스탠드 (탁자·계산대 위): 마카롱"""
    f = Furniture("CakeStand")
    f.zone("Stand", [cyl(0.06, 2.0, at=(0, 1.0, 0)), cyl(0.5, 0.06, at=(0, 0.03, 0))] + [cyl(0.9 - i * 0.22, 0.05, at=(0, 0.35 + i * 0.7, 0)) for i in range(3)], "gold", "Metal")
    colors = [("MacaronPink", "blush"), ("MacaronMint", "mint"), ("MacaronYellow", "yellow")]
    groups = {name: [] for name, _ in colors}
    for i in range(3):
        radius = 0.66 - i * 0.2
        count = 7 - i * 2
        for k in range(count):
            angle = 2 * math.pi * k / count
            name = colors[(k + i) % 3][0]
            groups[name].append(cyl(0.16, 0.16, at=(radius * math.cos(angle), 0.47 + i * 0.7, radius * math.sin(angle)), bevel=0.05))
    for name, color in colors:
        f.zone(name, groups[name], color)
    return f


def cupcake_sign():
    """큰 컵케이크 조형물 (높이 5.4): 가게 앞·안 포인트"""
    f = Furniture("CupcakeSign")
    f.zone("Cup", [lathe([(0, 0), (1.0, 0), (1.45, 2.0), (1.3, 2.0), (0, 2.0)], at=(0, 0, 0), seg=24)], "blush")
    f.zone("Pleats", [bx((0.14, 2.0, 0.1), (1.24 * math.cos(a), 1.0, 1.24 * math.sin(a)), r=0.03, rot=R((0, 1, 0), -math.degrees(a) + 90)) for a in [2 * math.pi * k / 16 for k in range(16)]], "cakeCream")
    f.zone("Cream", [ball((3.2, 1.4, 3.2), at=(0, 2.5, 0)), ball((2.5, 1.3, 2.5), at=(0, 3.3, 0)), ball((1.7, 1.2, 1.7), at=(0, 4.0, 0)), ball((0.9, 0.9, 0.9), at=(0, 4.6, 0))], "cakeCream")
    f.zone("Cherry", [ball(0.7, at=(0, 5.15, 0))], "berry")
    f.zone("Sprinkles", [ball(0.2, at=(1.2 * math.cos(k * 1.3), 2.9 + (k % 3) * 0.5, 1.2 * math.sin(k * 1.3) * (1 - (k % 3) * 0.2))) for k in range(10)], "yellow")
    return f


# ───────────────────────── 뽑기 천국 ─────────────────────────

def claw_machine():
    """인형뽑기 기계 (가로 3.6 · 높이 7.4 · 깊이 3.6)"""
    f = Furniture("ClawMachine")
    f.zone("Base", [bx((3.6, 3.0, 3.6), (0, 1.5, 0), r=0.14)], "coral")
    f.zone("Chute", [bx((1.1, 0.9, 0.2), (-0.9, 0.9, 1.74), r=0.08), bx((1.3, 0.3, 0.9), (0.8, 3.05, 1.5), r=0.08)], "ink")
    f.zone("Stick", [cyl(0.05, 0.5, at=(0.55, 3.4, 1.5)), ball(0.24, at=(0.55, 3.7, 1.5))], "red")
    f.zone("Button", [cyl(0.16, 0.12, at=(1.1, 3.26, 1.5))], "yellow", "Neon")
    f.zone("Posts", [bx((0.22, 3.6, 0.22), (sx * 1.66, 4.8, sz * 1.66), r=0.05) for sx in (-1, 1) for sz in (-1, 1)], "cakeCream")
    f.zone("Glass", [bx((3.3, 3.5, 3.3), (0, 4.8, 0), r=0.02)], "glass", "Glass")
    f.zone("Top", [bx((3.8, 0.9, 3.8), (0, 7.0, 0), r=0.18)], "coral")
    f.zone("Marquee", [bx((3.2, 0.6, 0.12), (0, 7.0, 1.92), r=0.05)], "yellowSoft", "Neon")
    f.zone("Claw", [cyl(0.03, 1.4, at=(0, 5.9, 0)), cyl(0.22, 0.2, at=(0, 5.15, 0))]
           + [rod((0.16 * math.cos(a), 5.1, 0.16 * math.sin(a)), (0.42 * math.cos(a), 4.6, 0.42 * math.sin(a)), 0.035) for a in (0, 2.1, 4.2)], "metal", "Metal")
    plush = {"PlushA": [], "PlushB": [], "PlushC": []}
    spots = [(-1.0, -0.9), (0.1, -1.0), (1.0, -0.7), (-0.6, 0.0), (0.6, 0.2), (-1.1, 0.9), (0.0, 1.0), (1.05, 0.95), (-0.2, -0.3), (0.5, -0.4)]
    for i, (x, z) in enumerate(spots):
        y = 3.4 + (0.5 if i >= 8 else 0)
        key = "PlushABC"[5 + i % 3]
        plush["Plush" + key].append(ball(0.8, at=(x, y, z)))
        plush["Plush" + key] += [ball(0.3, at=(x + sx * 0.28, y + 0.36, z)) for sx in (-1, 1)]
    f.zone("PlushA", plush["PlushA"], "blush")
    f.zone("PlushB", plush["PlushB"], "sky")
    f.zone("PlushC", plush["PlushC"], "yellow")
    return f


def gacha_machine():
    """캡슐 뽑기 두 단 (가로 2 · 높이 5.4)"""
    f = Furniture("GachaMachine")
    body, window, knob, cap = [], [], [], {"CapA": [], "CapB": [], "CapC": []}
    for k in range(2):
        y = k * 2.6
        body.append(bx((2.0, 2.5, 1.8), (0, y + 1.35, 0), r=0.2))
        window.append(bx((1.6, 1.2, 0.3), (0, y + 1.85, 0.8), r=0.12))
        knob.append(cyl(0.26, 0.2, at=(0.45, y + 0.75, 0.95), axis="z", bevel=0.05))
        knob.append(bx((0.7, 0.34, 0.12), (-0.45, y + 0.55, 0.92), r=0.05))
        for i in range(7):
            cap["Cap" + "ABC"[i % 3]].append(ball(0.36, at=(-0.55 + (i % 4) * 0.37, y + 1.6 + (i // 4) * 0.36, 0.72)))
    f.zone("Body", body + [bx((2.1, 0.2, 1.9), (0, 0.1, 0), r=0.05)], "sky")
    f.zone("Window", window, "glass", "Glass")
    f.zone("Knob", knob, "cakeCream")
    f.zone("CapA", cap["CapA"], "coral")
    f.zone("CapB", cap["CapB"], "yellow")
    f.zone("CapC", cap["CapC"], "mint")
    return f


def wheel_frame():
    """돌림판 테두리 (지름 9.6, 원점 = 원판 가운데, 뒤가 벽): 전구 16개 + 바늘 + 받침"""
    f = Furniture("WheelFrame")
    f.zone("Ring", [lathe([(4.5, -0.25), (4.95, -0.25), (5.05, 0), (4.95, 0.25), (4.5, 0.25)], seg=40, rot=R((1, 0, 0), 90))], "red")
    f.zone("Bulbs", [ball(0.34, at=(4.78 * math.cos(a), 4.78 * math.sin(a), 0.3)) for a in [2 * math.pi * k / 16 for k in range(16)]], "yellowSoft", "Neon")
    f.zone("Pointer", [lathe([(0, 0), (0.5, 0.9), (0, 0.9)], at=(0, 4.2, 0.45), seg=3)], "gold", "Metal")
    f.zone("Stand", [bx((1.0, 6.2, 0.5), (sx * 3.2, -5.6, -0.1), r=0.08, rot=R((0, 0, 1), sx * 8)) for sx in (-1, 1)] + [bx((8.4, 0.5, 1.6), (0, -8.5, 0), r=0.1)], "woodDark", "Wood")
    return f


def dart_booth():
    """풍선 다트 부스 (가로 7.2 · 높이 8): 줄무늬 차양 + 기둥 + 앞 선반"""
    f = Furniture("DartBooth")
    f.zone("Posts", [bx((0.3, 7.6, 0.3), (sx * 3.4, 3.8, sz * 1.4), r=0.06) for sx in (-1, 1) for sz in (-1, 1)], "cakeCream")
    red, white = [], []
    for i in range(8):
        piece = bx((0.9, 0.16, 3.6), (-3.15 + i * 0.9, 7.6, 0.2), r=0.03, rot=R((1, 0, 0), 12))
        (red if i % 2 == 0 else white).append(piece)
        flap = cyl(0.45, 0.14, at=(-3.15 + i * 0.9, 6.95, 2.0), axis="z")
        (red if i % 2 == 0 else white).append(flap)
    f.zone("AwningRed", red, "red", "Fabric")
    f.zone("AwningWhite", white, "cakeCream", "Fabric")
    f.zone("Shelf", [bx((7.2, 0.3, 1.2), (0, 3.3, 1.5), r=0.08), bx((7.0, 3.1, 0.2), (0, 1.6, 1.9), r=0.04)], "woodLight", "Wood")
    f.zone("Darts", [rod((-2.0 + i * 0.5, 3.5, 1.3), (-2.0 + i * 0.5, 3.5, 1.9), 0.04) for i in range(3)] + [ball(0.16, at=(-2.0 + i * 0.5, 3.5, 1.2)) for i in range(3)], "ink")
    return f


def plush_shelf():
    """인형 진열 선반 (가로 6 · 3단, 벽에 붙여요)"""
    f = Furniture("PlushShelf")
    f.zone("Frame", [bx((6.0, 0.14, 1.2), (0, 0.6 + i * 2.0, 0), r=0.04) for i in range(3)] + [bx((0.14, 5.2, 1.2), (sx * 2.95, 2.6, 0), r=0.04) for sx in (-1, 1)], "woodLight", "Wood")
    names = [("BearA", "blush"), ("BearB", "sky"), ("BearC", "yellow"), ("BearD", "mint")]
    groups = {n: [] for n, _ in names}
    for row in range(3):
        for i in range(4):
            x, y = -2.1 + i * 1.4, 1.25 + row * 2.0
            g = groups[names[(i + row) % 4][0]]
            g += [ball(1.0, at=(x, y, 0)), ball(0.7, at=(x, y + 0.75, 0))] + [ball(0.28, at=(x + sx * 0.3, y + 1.1, 0)) for sx in (-1, 1)]
    for n, c in names:
        f.zone(n, groups[n], c, "Fabric")
    return f


# ───────────────────────── 오락실 ─────────────────────────

def arcade_cabinet():
    """오락기 (가로 3.2 · 높이 6.6 · 깊이 2.8): 기울어진 화면 + 조작대 + 간판"""
    f = Furniture("ArcadeCabinet")
    f.zone("Body", [bx((3.0, 3.0, 2.6), (0, 1.5, -0.1), r=0.1), bx((3.0, 3.6, 1.7), (0, 4.6, -0.55), r=0.1)], "arcade")
    f.zone("Sides", [bx((0.14, 6.4, 2.8), (sx * 1.55, 3.3, -0.1), r=0.05) for sx in (-1, 1)], "ink")
    f.zone("Stripe", [bx((0.05, 0.4, 2.4), (sx * 1.64, 2.0 + i * 0.7, -0.1), r=0.02) for sx in (-1, 1) for i in range(2)], "neonPink", "Neon")
    f.zone("Screen", [bx((2.4, 1.8, 0.1), (0, 4.3, 0.34), r=0.06, rot=R((1, 0, 0), -12))], "neonCyan", "Neon")
    f.zone("Bezel", [bx((2.8, 2.2, 0.1), (0, 4.3, 0.28), r=0.06, rot=R((1, 0, 0), -12))], "ink")
    f.zone("Marquee", [bx((2.8, 0.8, 0.14), (0, 5.95, 0.36), r=0.05)], "neonPink", "Neon")
    f.zone("Deck", [bx((3.0, 0.3, 1.3), (0, 3.05, 0.75), r=0.08, rot=R((1, 0, 0), 8))], "ink")
    f.zone("Stick", [cyl(0.05, 0.5, at=(-0.8, 3.4, 0.75)), ball(0.26, at=(-0.8, 3.7, 0.75))], "red")
    f.zone("Buttons", [cyl(0.15, 0.1, at=(0.1 + i * 0.42, 3.25 - (i % 2) * 0.02, 0.6 + (i % 2) * 0.32)) for i in range(4)], "yellow", "Neon")
    f.zone("Coin", [bx((0.9, 0.5, 0.08), (0, 1.8, 1.22), r=0.04)], "metal", "Metal")
    return f


def mole_machine():
    """두더지 잡기 (가로 4 · 높이 6.2): 구멍 6개 + 두더지 + 망치 + 뒤판"""
    f = Furniture("MoleMachine")
    f.zone("Body", [bx((4.0, 2.8, 3.0), (0, 1.4, 0), r=0.14)], "mintDark")
    f.zone("Deck", [bx((4.1, 0.3, 3.1), (0, 2.95, 0), r=0.1, rot=R((1, 0, 0), 8))], "grassLight")
    holes, moles, noses = [], [], []
    for i in range(6):
        x, z = -1.3 + (i % 3) * 1.3, -0.6 + (i // 3) * 1.3
        y = 3.12 - z * 0.14
        holes.append(cyl(0.48, 0.08, at=(x, y, z)))
        if i in (0, 2, 4):
            moles.append(ball((0.8, 0.9, 0.8), at=(x, y + 0.3, z)))
            noses.append(ball(0.18, at=(x, y + 0.4, z + 0.38)))
    f.zone("Holes", holes, "ink")
    f.zone("Moles", moles, "wood")
    f.zone("Noses", noses, "blush")
    f.zone("Back", [bx((4.0, 3.0, 0.3), (0, 4.6, -1.35), r=0.12)], "mintDark")
    f.zone("Marquee", [bx((3.4, 1.4, 0.1), (0, 5.0, -1.16), r=0.08)], "yellowSoft", "Neon")
    f.zone("Hammer", [rod((1.5, 3.3, 1.2), (2.2, 3.9, 0.6), 0.07), cyl(0.3, 0.7, at=(2.3, 4.0, 0.5), axis="x", bevel=0.06)], "red")
    return f


def prize_counter():
    """경품 교환대 (가로 6 · 높이 3.5): 유리 진열 + 네온 띠"""
    f = Furniture("PrizeCounter")
    f.zone("Body", [bx((6.0, 3.2, 2.0), (0, 1.6, -0.1), r=0.08)], "arcade")
    f.zone("Glass", [bx((5.4, 1.6, 0.3), (0, 2.0, 0.85), r=0.04)], "glass", "Glass")
    f.zone("Neon", [bx((6.1, 0.12, 0.1), (0, 0.5, 1.0), r=0.03), bx((6.1, 0.12, 0.1), (0, 3.2, 1.0), r=0.03)], "neonCyan", "Neon")
    f.zone("Top", [bx((6.2, 0.2, 2.3), (0, 3.4, -0.05), r=0.08)], "ink")
    f.zone("PrizeA", [ball(0.6, at=(-2.0 + i * 2.0, 1.75, 0.6)) for i in range(3)], "blush")
    f.zone("PrizeB", [bx((0.6, 0.6, 0.4), (-1.0 + i * 2.0, 1.7, 0.6), r=0.08) for i in range(2)], "yellow")
    f.zone("Tickets", [cyl(0.3, 0.3, at=(2.3, 3.65, 0.2), axis="x", bevel=0.04)], "red")
    return f


def neon_sign():
    """벽 네온 사인 (가로 6): 별 + 번개 + 하트 (원점 = 가운데, 뒤가 벽)"""
    f = Furniture("NeonSign")

    def loop(points, r=0.09):
        return [rod((a[0], a[1], 0.14), (b[0], b[1], 0.14), r) for a, b in zip(points, points[1:] + points[:1])]

    star = []
    for k in range(10):
        radius = 1.2 if k % 2 == 0 else 0.52
        angle = math.radians(90 + k * 36)
        star.append((-2.0 + radius * math.cos(angle), radius * math.sin(angle)))
    bolt = [(0.25, 1.2), (-0.45, -0.05), (0.02, -0.05), (-0.25, -1.2), (0.5, 0.2), (0.02, 0.2)]
    heart = [(2.0 + 0.9 * 16 * math.sin(t) ** 3 / 16, 0.1 + 0.9 * (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)) / 16) for t in [2 * math.pi * k / 18 for k in range(18)]]
    f.zone("Star", loop(star), "yellowSoft", "Neon")
    f.zone("Bolt", loop(bolt), "neonCyan", "Neon")
    f.zone("Heart", loop(heart), "neonPink", "Neon")
    f.zone("Plate", [bx((6.4, 3.0, 0.08), (0, 0, 0.04), r=0.03)], "ink")
    return f


# ───────────────────────── 가게 외관 ─────────────────────────

def shop_awning():
    """줄무늬 차양 (가로 12 · 앞으로 4, 원점 = 벽에 붙는 윗선 가운데)"""
    f = Furniture("ShopAwning")
    a, b = [], []
    for i in range(12):
        x = -5.5 + i * 1.0
        slab = bx((1.0, 0.14, 4.3), (x, -0.9, 2.0), r=0.02, rot=R((1, 0, 0), 24))
        flap = cyl(0.5, 0.12, at=(x, -1.95, 3.98), axis="z")
        (a if i % 2 == 0 else b).extend([slab, flap])
    f.zone("StripeA", a, "coral", "Fabric")
    f.zone("StripeB", b, "cakeCream", "Fabric")
    f.zone("Arms", [rod((sx * 5.9, -0.1, 0.1), (sx * 5.9, -1.8, 3.9), 0.06) for sx in (-1, 1)] + [rod((-5.9, -1.8, 3.9), (5.9, -1.8, 3.9), 0.05)], "ink")
    return f


def blade_sign():
    """벽에서 튀어나온 둥근 간판 (원점 = 벽 붙는 자리, +X로 나와요)"""
    f = Furniture("BladeSign")
    f.zone("Bracket", [rod((0, 0, 0), (2.6, 0, 0), 0.07), rod((0.2, -0.9, 0), (1.4, 0, 0), 0.05), cyl(0.2, 0.12, at=(0, 0, 0), axis="x")] + [rod((x, 0, 0), (x, -0.5, 0), 0.03) for x in (1.2, 2.3)], "ink")
    f.zone("Board", [cyl(1.15, 0.2, at=(1.75, -1.65, 0), axis="z", bevel=0.05)], "cakeCream")
    f.zone("Rim", [lathe([(1.15, -0.13), (1.28, -0.13), (1.28, 0.13), (1.15, 0.13)], at=(1.75, -1.65, 0), seg=32, rot=R((1, 0, 0), 90))], "ink")
    return f


def a_board():
    """길가 A자 입간판 (높이 4)"""
    f = Furniture("ABoard")
    f.zone("Frame", [bx((2.4, 4.0, 0.16), (0, 1.95, sz * 0.55), r=0.05, rot=R((1, 0, 0), sz * -14)) for sz in (-1, 1)], "woodLight", "Wood")
    f.zone("Board", [bx((2.0, 3.0, 0.06), (0, 2.1, sz * 0.66), r=0.03, rot=R((1, 0, 0), sz * -14)) for sz in (-1, 1)], "ink")
    f.zone("Chalk", [bx((1.3 - (i % 2) * 0.3, 0.12, 0.04), (0, 3.0 - i * 0.45, 0.48 + i * 0.112), r=0.02, rot=R((1, 0, 0), -14)) for i in range(4)], "cakeCream")
    return f


def shop_door():
    """활짝 열린 유리 쌍문 (문 구멍 폭 10 · 높이 10): 문틀 + 안으로 젖힌 문짝 두 장"""
    f = Furniture("ShopDoor")
    f.zone("Frame", [bx((0.4, 10.2, 0.6), (sx * 5.2, 5.1, 0), r=0.06) for sx in (-1, 1)] + [bx((10.8, 0.4, 0.6), (0, 10.2, 0), r=0.06)], "ink")
    f.zone("Leaf", [bx((0.24, 9.8, 4.6), (sx * 4.85, 5.0, -2.5), r=0.05) for sx in (-1, 1)], "glass", "Glass")
    f.zone("LeafFrame", [bx((0.3, 0.5, 4.8), (sx * 4.85, y, -2.5), r=0.04) for sx in (-1, 1) for y in (0.3, 9.75)]
           + [bx((0.3, 9.9, 0.3), (sx * 4.85, 5.0, z), r=0.04) for sx in (-1, 1) for z in (-0.25, -4.75)], "ink")
    f.zone("Handle", [rod((sx * 4.62, 3.6, -4.2), (sx * 4.62, 6.2, -4.2), 0.07) for sx in (-1, 1)], "gold", "Metal")
    return f


def street_planter():
    """가게 앞 긴 화분 (가로 6): 낮은 생울타리 + 꽃"""
    f = Furniture("ShopPlanter")
    f.zone("Box", [bx((6.0, 1.3, 1.5), (0, 0.65, 0), r=0.08)], "espresso")
    f.zone("Hedge", [bx((5.7, 1.3, 1.25), (0, 1.8, 0), r=0.4)], "grass")
    f.zone("Flowers", [ball(0.36, at=(-2.4 + i * 0.8, 2.5, 0.25 * (-1) ** i)) for i in range(7)], "blush")
    return f


BUILDERS = [
    cafe_bar, espresso_machine, pastry_case, menu_board, cafe_table, cafe_chair, bar_stool, pendant_lamp, wall_shelf, booth_sofa,
    dessert_showcase, dessert_counter, cake_stand, cupcake_sign,
    claw_machine, gacha_machine, wheel_frame, dart_booth, plush_shelf,
    arcade_cabinet, mole_machine, prize_counter, neon_sign,
    shop_awning, blade_sign, a_board, shop_door, street_planter,
]
LIFT = {"PendantLamp": 4, "MenuBoard": 3, "WallShelf": 2, "WheelFrame": 9, "NeonSign": 2.5, "ShopAwning": 4, "BladeSign": 4}


def glassify():
    """미리보기용: Glass 재질을 반투명하게"""
    for mat in bpy.data.materials:
        if mat.name.endswith("_Glass") and mat.use_nodes:
            bsdf = mat.node_tree.nodes["Principled BSDF"]
            bsdf.inputs["Alpha"].default_value = 0.28
            bsdf.inputs["Roughness"].default_value = 0.08


def main():
    lib.reset()
    furniture = []
    for index, build in enumerate(BUILDERS):
        f = build()
        d.put(f, -42 + (index % 7) * 14, -24 + (index // 7) * 15, y=LIFT.get(f.name, 0))
        furniture.append(f)
    names = [f.name for f in furniture]
    assert len(set(names)) == len(names), names
    lib.export(os.path.join(OUT, "fbx", "street_shops_set.fbx"), furniture, os.path.join(OUT, "fbx", "street_shops_set.json"))
    glassify()
    if "--no-render" not in sys.argv:
        lib.render(os.path.join(OUT, "preview", "street_shops_set.png"), eye=(0, 58, 70), target=(0, 2, 2), width=2200, height=1300, lens=40, floor="stone", samples=40)
    for f in furniture:
        print(f.name, len(f.zones), sum(z["triangles"] for z in f.zones))
    print(f"DONE furniture={len(furniture)} zones={sum(len(f.zones) for f in furniture)} triangles={sum(z['triangles'] for f in furniture for z in f.zones)}")


if __name__ == "__main__":
    main()
