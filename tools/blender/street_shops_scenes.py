# 눈치 스트리트 가게 리뉴얼 시안: 가게 네 곳의 배치를 그림으로 (게임에 넣기 전 확인용)
# 실행: /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/street_shops_scenes.py
# 가게 한 칸: 안쪽 x ±23.5 · 깊이 18 (앞 유리 z +9 ~ 뒷벽 z -9) · 천장 13.5. 그림은 앞벽과 천장을 떼고 봐요.

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import lib  # noqa: E402
import drafts_spaces as d  # noqa: E402
import street_shops_set as s  # noqa: E402
from lib import Furniture, box, cyl  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "salary", "renewal")
H = 13.5


def room(wall, floor, floor_mat="Wood", accent=None):
    f = Furniture("Room")
    f.zone("Floor", [box((47, 0.1, 18), at=(0, -0.01, 0), r=0)], floor, floor_mat)  # (미리보기 바닥과 겹치지 않게 살짝 위)
    f.zone("Walls", [box((47, H, 0.4), at=(0, H / 2, -9.2), r=0)] + [box((0.4, H, 18), at=(sx * 23.7, H / 2, 0), r=0) for sx in (-1, 1)], wall)
    if accent:
        f.zone("Wainscot", [box((47, 3.2, 0.1), at=(0, 1.6, -8.95), r=0)] + [box((0.1, 3.2, 18), at=(sx * 23.45, 1.6, 0), r=0) for sx in (-1, 1)], accent)
    f.zone("Sill", [box((18.5, 0.5, 0.4), at=(sx * 14.25, 0.25, 9), r=0) for sx in (-1, 1)], "ink")
    return f


def put(build, x, z, rot=0, y=0, colors=None):
    f = build()
    if colors:
        d.recolor(f, colors)
    return d.put(f, x, z, rot=rot, y=y)


def rug(x, z, radius, color):
    f = Furniture("Rug")
    f.zone("Rug", [cyl(radius, 0.06, at=(0, 0.03, 0))], color, "Fabric")
    return d.put(f, x, z)


def lamps(points):
    for x, z in points:
        put(s.pendant_lamp, x, z, y=H)


def cafe():
    room("cream", "woodLight", accent="mintDark")
    put(s.menu_board, 0, -8.9, y=9.2)
    put(s.cafe_bar, 0, -5.4)
    put(s.espresso_machine, -3.2, -5.5, y=3.64)
    put(s.pastry_case, 3.0, -5.3, y=3.64)
    for x in (-9.5, 9.5):
        put(s.wall_shelf, x, -8.95, y=7.2)
        put(s.wall_shelf, x, -8.95, y=9.6)
    # 왼쪽: 벽 소파 + 탁자
    for z in (-3.5, 3.0):
        put(s.booth_sofa, -21.8, z, rot=-90)
        put(s.cafe_table, -18.2, z)
        put(s.cafe_chair, -15.6, z, rot=90)
    # 오른쪽: 둥근 탁자 세 개
    rug(14.5, 1.0, 7.5, "mintDark")
    for x, z in ((10.5, -1.5), (17.5, -0.5), (13.5, 4.0)):
        put(s.cafe_table, x, z)
        put(s.cafe_chair, x - 2.3, z, rot=-90)
        put(s.cafe_chair, x + 2.3, z, rot=90)
    # 앞 창가 높은 자리
    for x in (-13, -10.5, -8):
        put(s.bar_stool, x, 7.0)
    put(d.floor_plant, 21.5, -7.2)
    put(d.floor_plant, -6.2, 7.6)
    put(s.a_board, 7.5, 11.5)
    lamps([(-4, -5), (0, -5), (4, -5), (-18.2, -3.5), (-18.2, 3.0), (10.5, -1.5), (17.5, -0.5), (13.5, 4.0)])


def dessert():
    room("cakeCream", "woodLight", accent="blush")
    put(s.dessert_showcase, -4.5, -5.6)
    put(s.dessert_counter, 4.2, -5.6)
    put(s.cake_stand, 3.0, -5.4, y=3.53)
    put(s.menu_board, 0, -8.9, y=9.4)
    put(s.wall_shelf, -12, -8.95, y=7.4)
    put(s.wall_shelf, 12, -8.95, y=7.4)
    put(s.cupcake_sign, -19.5, 4.5)
    pink = {"Seat": "blush", "Back": "blush", "Base": "cakeCream"}
    for z in (-4.5, 1.5):
        put(s.booth_sofa, 21.8, z, rot=90, colors=pink)
        put(s.cafe_table, 18.2, z, colors={"Top": "cakeCream", "Base": "gold"})
        put(s.cafe_chair, 15.6, z, rot=-90, colors={"Seat": "blush", "Back": "blush", "Frame": "gold"})
    rug(-12.5, 0.5, 6.2, "blush")
    for x, z in ((-14.5, -1.0), (-10.0, 2.5)):
        put(s.cafe_table, x, z, colors={"Top": "cakeCream", "Base": "gold"})
        put(s.cake_stand, x, z, y=2.7)
        put(s.cafe_chair, x - 2.3, z, rot=-90, colors={"Seat": "blush", "Back": "blush", "Frame": "gold"})
        put(s.cafe_chair, x + 2.3, z, rot=90, colors={"Seat": "blush", "Back": "blush", "Frame": "gold"})
    put(d.floor_plant, 9.5, -7.4)
    lamps([(-7.5, -5.5), (-4.5, -5.5), (-1.5, -5.5), (4.2, -5.5), (18.2, -4.5), (18.2, 1.5), (-14.5, -1.0), (-10.0, 2.5)])


def claw():
    room("cream", "cakeCream", "SmoothPlastic", accent="yellow")
    colors = [("coral", "coral"), ("sky", "sky"), ("mint", "mint"), ("lilac", "lilac")]
    for i, (body, _) in enumerate(colors):
        put(s.claw_machine, -20.5 + i * 4.6, -6.6, colors={"Base": body, "Top": body})
    put(s.wheel_frame, 3.5, -8.4, y=6.8)
    wheel = Furniture("WheelDisc")
    wheel.zone("Disc", [cyl(4.5, 0.3, at=(0, 0, 0), axis="z")], "navy")
    d.put(wheel, 3.5, -8.7, y=6.8)
    kiosk = Furniture("Kiosk")
    kiosk.zone("Body", [box((5, 3.5, 1.6), at=(0, 1.75, 0), r=0.15)], "yellow")
    d.put(kiosk, 3.5, -3.5)
    put(s.dart_booth, 13.5, -6.8)
    for i in range(4):
        put(s.gacha_machine, 22.4, -1.5 + i * 2.2, rot=90, colors={"Body": ("sky", "coral", "mint", "yellow")[i]})
    put(s.plush_shelf, -22.6, 2.5, rot=-90)
    put(s.neon_sign, -8, -8.95, y=10.6)
    rug(-6, 3.5, 5.0, "yellow")
    put(s.bar_stool, -8, 3.0, colors={"Seat": "coral"})
    put(s.bar_stool, -4.5, 4.5, colors={"Seat": "sky"})
    lamps([(-16, -2), (-8, -2), (3.5, -2), (13.5, -2)])


def arcade():
    room("arcade", "ink", "Fabric")
    bodies = ["arcade", "red", "mintDark", "arcade", "lilac", "red"]
    for i, body in enumerate(bodies):
        put(s.arcade_cabinet, -9.5 + i * 3.7, -7.3, colors={"Body": body})
        put(s.bar_stool, -9.5 + i * 3.7, -4.2, colors={"Seat": "neonPink" if i % 2 else "neonCyan"})
    put(s.mole_machine, -20.0, -6.8)
    put(s.mole_machine, -15.2, -6.8)
    put(s.prize_counter, 19.0, -2.0, rot=90)
    put(s.plush_shelf, 22.6, -2.0, rot=90)
    put(s.neon_sign, 0, -8.95, y=10.8)
    put(s.neon_sign, -23.4, 1.0, rot=-90, y=8.5)
    put(s.claw_machine, -20.5, 3.5, rot=-90 + 90, colors={"Base": "lilac", "Top": "lilac"})
    strip = Furniture("FloorNeon")
    strip.zone("Line", [box((44, 0.06, 0.25), at=(0, 0.04, z), r=0) for z in (-2.6, 6.5)], "neonPink", "Neon")
    d.put(strip, 0, 0)
    back = Furniture("WallNeon")
    back.zone("Line", [box((46.5, 0.2, 0.1), at=(0, y, -8.95), r=0) for y in (0.6, 13.0)], "neonCyan", "Neon")
    d.put(back, 0, 0)


SCENES = [("cafe", cafe, 1.5, 0.5, "woodLight"), ("dessert", dessert, 1.5, 0.55, "woodLight"), ("claw", claw, 1.5, 0.55, "cakeCream"), ("arcade", arcade, 0.5, 0.22, "ink")]


def main():
    only = [a for a in sys.argv if a.startswith("--only=")]
    for name, build, sun, world, floor in SCENES:
        if only and only[0][7:] != name:
            continue
        lib.reset()
        build()
        s.glassify()
        lib.render(os.path.join(OUT, f"shop_{name}.png"), eye=(0, 26, 34), target=(0, 3.5, -3.5), width=1900, height=1000, lens=26, sun=sun, world=world, floor=floor, samples=44, sun_rot=(42, 6, 20))
        print("RENDERED", name)


if __name__ == "__main__":
    main()
