# 리뉴얼 4단계 초안: 도착 동선 — 건물 앞 거리와 1층 로비 (대충상사가 3층에 세 든 낡은 상가 건물)
# 실행: /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/renewal_arrival.py
# 건물 바닥 120×75칸(3층 평면과 같아요), 남쪽이 큰길. 좌표: x 동서, z 남북(+가 길 쪽).

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402

import lib  # noqa: E402
import drafts_spaces as d  # noqa: E402
import drafts_texture as t  # noqa: E402
import office_kit_set as kit  # noqa: E402
import renewal_daechung as rd  # noqa: E402
from lib import Furniture, R, ball, box, cyl, rod  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "salary", "renewal")
FLOOR_H = 21
SOUTH = 37.5


def bx(size, at, **kw):
    return box(size, at=at, r=0, **kw)


def building():
    tile = t.tex("facade", (198, 186, 164), "plain", 0.8)
    f = Furniture("Building")
    f.zone("Body", [bx((120, FLOOR_H * 4, 75), (0, FLOOR_H * 2, 0))], tile)
    f.zone("Bands", [bx((120.6, 1.2, 75.6), (0, FLOOR_H * k, 0)) for k in (1, 2, 3, 4)], t.tex("band", (150, 140, 124), "plain", 0.8))
    glass = t.tex("winglass", (120, 150, 172), "plain", 0.15)
    f.zone("Windows", [bx((9.5, 10, 0.3), (x, FLOOR_H * k + 9, SOUTH + 0.1)) for k in (1, 2, 3) for x in range(-52, 53, 13)], glass)
    f.zone("Frames", [bx((10.3, 0.5, 0.5), (x, FLOOR_H * k + 3.8, SOUTH + 0.25)) for k in (1, 2, 3) for x in range(-52, 53, 13)]
           + [bx((0.3, 10, 0.4), (x, FLOOR_H * k + 9, SOUTH + 0.25)) for k in (1, 2, 3) for x in range(-52, 53, 13)], t.tex("frame", (226, 224, 216), "plain", 0.6))
    f.zone("Lit", [bx((9.5, 10, 0.32), (x, FLOOR_H * 2 + 9, SOUTH + 0.1)) for x in (-26, 0, 13)], t.tex("litwin", (255, 240, 200), "plain", 0.2, 1.6))
    # 1층 가게 유리와 간판
    f.zone("Shopfront", [bx((22, 12, 0.3), (x, 7.5, SOUTH + 0.1)) for x in (-12, 14, 42)], t.tex("shopglass", (176, 206, 214), "plain", 0.1, 0.5))
    for i, (x, color) in enumerate(((-12, (88, 150, 132)), (14, (196, 108, 92)), (42, (214, 174, 84)))):
        f.zone(f"Sign{i}", [bx((22, 3.4, 0.8), (x, 16.2, SOUTH + 0.5))], t.tex(f"sign{i}", color, "plain", 0.5))
        f.zone(f"SignText{i}", [bx((12, 1.4, 0.1), (x, 16.2, SOUTH + 0.95))], t.tex("signtext", (250, 248, 240), "plain", 0.4, 0.8))
    # 건물 입구 (서쪽): 어두운 현관 + 캐노피 + 층별 안내 간판
    f.zone("Entrance", [bx((10, 12, 0.3), (-46, 7.5, SOUTH + 0.1))], t.tex("lobbyglow", (255, 236, 196), "plain", 0.2, 1.2))
    f.zone("Canopy", [bx((13, 0.8, 5), (-46, 14.4, SOUTH + 2.5)), bx((0.4, 14, 0.4), (-52, 7, SOUTH + 4.6)), bx((0.4, 14, 0.4), (-40, 7, SOUTH + 4.6))], t.tex("canopy", (70, 76, 84), "plain", 0.6))
    f.zone("Directory", [bx((3.2, 13, 0.6), (-55.5, 26, SOUTH + 0.5))], t.tex("directory", (44, 62, 92), "plain", 0.5))
    f.zone("DirectoryLines", [bx((2.4, 0.9, 0.1), (-55.5, 20.6 + k * 1.6, SOUTH + 0.85)) for k in range(7)], t.tex("signtext", (250, 248, 240), "plain", 0.4, 0.8))
    # 실외기 · 옥상 (난간, 물탱크, 옥탑)
    f.zone("AC", [box((3.2, 2.4, 1.6), at=(x, FLOOR_H * k + 1.6, SOUTH + 0.9), r=0.1, seg=1) for k in (1, 2, 3) for x in (-45.5, -6.5, 32.5)], t.tex("ac", (214, 214, 208), "plain", 0.6))
    top = FLOOR_H * 4
    f.zone("Parapet", [bx((120, 3, 1), (0, top + 1.5, SOUTH - 0.5)), bx((1, 3, 75), (-59.5, top + 1.5, 0)), bx((1, 3, 75), (59.5, top + 1.5, 0))], tile)
    f.zone("Penthouse", [bx((16, 11, 14), (-48, top + 5.5, 6))], tile)
    f.zone("Tank", [cyl(5, 7, at=(26, top + 7.5, 8), seg=20), cyl(5.2, 0.5, at=(26, top + 11.2, 8), seg=20)], t.tex("tank", (220, 178, 70), "plain", 0.6))
    f.zone("TankLegs", [bx((0.5, 4, 0.5), (26 + sx * 3, top + 2, 8 + sz * 3)) for sx in (-1, 1) for sz in (-1, 1)], t.tex("canopy", (70, 76, 84), "plain", 0.6))


def neighbors():
    f = Furniture("Neighbors")
    for i, (x, w, h, color) in enumerate(((-96, 64, 60, (176, 170, 160)), (92, 56, 104, (160, 168, 176)), (-150, 40, 120, (150, 152, 158)))):
        f.zone(f"Block{i}", [bx((w, h, 70), (x, h / 2, 2))], t.tex(f"nb{i}", color, "plain", 0.8))
        f.zone(f"Win{i}", [bx((w * 0.86, 5, 0.3), (x, y, SOUTH + 0.1)) for y in range(10, h - 4, 11)], t.tex("winglass", (120, 150, 172), "plain", 0.15))


def street():
    f = Furniture("Street")
    f.zone("Sidewalk", [bx((400, 0.6, 15), (0, 0.3, SOUTH + 7.5)), bx((400, 0.6, 14), (0, 0.3, SOUTH + 54))], t.tex("pave", (186, 180, 168), "plain", 0.9))
    f.zone("Joints", [bx((0.12, 0.62, 15), (x, 0.3, SOUTH + 7.5)) for x in range(-120, 121, 6)], t.tex("joint", (150, 146, 138), "plain", 0.9))
    f.zone("Road", [bx((400, 0.2, 32), (0, 0.1, SOUTH + 31))], t.tex("asphalt", (66, 68, 72), "plain", 0.95))
    f.zone("Yellow", [bx((9, 0.22, 0.5), (x, 0.1, SOUTH + 31)) for x in range(-120, 121, 18)], t.tex("yellowline", (226, 186, 70), "plain", 0.8))
    f.zone("White", [bx((1.6, 0.22, 26), (-46 + k * 3.2, 0.1, SOUTH + 31)) for k in range(-3, 4)], t.tex("whiteline", (232, 232, 228), "plain", 0.8))
    # 가로수 · 가로등 · 전봇대
    for x in (-78, -22, 6, 34, 62):
        d.put(d.tree(1.5), x, SOUTH + 12.5, rot=x * 7)
    for x in (-64, -8, 48):
        d.put(d.lamp_post(), x, SOUTH + 13.2).root.scale = (2.2, 2.2, 2.2)
    pole = Furniture("Pole")
    pole.zone("Wood", [cyl(0.5, 44, at=(20, 22, SOUTH + 13.8), seg=10), bx((9, 0.5, 0.5), (20, 40, SOUTH + 13.8)), bx((6, 0.4, 0.4), (20, 36, SOUTH + 13.8))], t.tex("pole", (120, 112, 100), "plain", 0.9))
    pole.zone("Wires", [rod((20 + dx, 40.2, SOUTH + 13.8), (-140, 37 + dx * 0.2, SOUTH + 13.8), 0.07, seg=6) for dx in (-4, 0, 4)]
              + [rod((20 + dx, 40.2, SOUTH + 13.8), (160, 38, SOUTH + 13.8), 0.07, seg=6) for dx in (-4, 0, 4)], t.tex("wire", (40, 40, 44), "plain", 0.8))
    # 버스 정류장
    stop = Furniture("BusStop")
    stop.zone("Frame", [bx((0.3, 8, 0.3), (x, 4.3, z)) for x in (-33, -21) for z in (SOUTH + 9.4, SOUTH + 12)] + [bx((13, 0.3, 3.4), (-27, 8.4, SOUTH + 10.7))], t.tex("canopy", (70, 76, 84), "plain", 0.6))
    stop.zone("Glass", [bx((12, 6, 0.12), (-27, 4.6, SOUTH + 9.4))], t.tex("stopglass", (190, 214, 226), "plain", 0.1))
    stop.zone("Sign", [bx((0.3, 9, 0.3), (-18.5, 4.8, SOUTH + 12.5)), cyl(1.1, 0.3, at=(-18.5, 9.6, SOUTH + 12.5), axis="z", seg=16)], t.tex("bussign", (60, 110, 190), "plain", 0.5))
    d.put(d.bench(), -27, SOUTH + 10.4)
    # 세워 둔 차
    car = Furniture("Car")
    car.zone("Body", [box((16, 3.2, 7), at=(0, 2.6, 0), r=0.6, seg=3), box((9, 2.8, 6.4), at=(-0.6, 5.2, 0), r=0.7, seg=3)], t.tex("carpaint", (226, 226, 222), "plain", 0.35))
    car.zone("Glass", [box((8.4, 2.0, 6.5), at=(-0.6, 5.3, 0), r=0.3, seg=2)], t.tex("carglass", (50, 62, 74), "plain", 0.1))
    car.zone("Wheels", [cyl(1.3, 1.0, at=(sx * 5, 1.3, sz * 3.2), axis="z", seg=16) for sx in (-1, 1) for sz in (-1, 1)], t.tex("wire", (40, 40, 44), "plain", 0.8))
    d.put(car, 46, SOUTH + 19.5)
    rd.person(-44, SOUTH + 8, (230, 232, 236), yaw=170)
    rd.person(-25, SOUTH + 11.5, (150, 164, 190), yaw=20)
    rd.person(8, SOUTH + 5, (206, 170, 150), yaw=-90)


def lobby():
    """1층 로비 (건물 남서쪽 모퉁이, x -60~-30 / z 17.5~37.5, 천장 14칸)."""
    paint = t.tex("oldwall", (226, 222, 210), "plain", 0.85)
    f = Furniture("Lobby")
    f.zone("Floor", [bx((30, 0.2, 20), (-45, 0.1, 27.5))], t.tex("terrazzo", (196, 192, 184), "carpet", 0.4))
    f.zone("Walls", [bx((0.6, 14, 20), (-60, 7, 27.5)), bx((0.6, 14, 20), (-30, 7, 27.5)), bx((30, 14, 0.6), (-45, 7, 17.5)),
                     bx((10, 14, 0.6), (-55, 7, 37.5)), bx((10, 14, 0.6), (-35, 7, 37.5)), bx((10, 3, 0.6), (-45, 12.5, 37.5))], paint)
    f.zone("Wainscot", [bx((0.1, 4, 20), (-59.65, 2, 27.5)), bx((0.1, 4, 20), (-30.35, 2, 27.5)), bx((30, 4, 0.1), (-45, 2, 17.85))], t.tex("wainscot", (150, 162, 156), "plain", 0.6))
    f.zone("Door", [bx((9.6, 11, 0.15), (-45, 5.5, 37.5))], t.tex("lobbyday", (214, 230, 240), "plain", 0.1, 3.0))
    f.zone("Ceiling", [bx((30, 0.3, 20), (-45, 14.15, 27.5))], t.tex("ceiling", (236, 235, 230), "plain", 0.9))
    f.zone("Lights", [bx((5.4, 0.1, 1.4), (x, 13.95, z)) for x in (-52, -38) for z in (23, 32)], t.tex("tube", (255, 250, 236), "plain", 0.3, 9.0))
    # 엘리베이터 (서쪽 벽) · 층 안내판 · 우편함 · 게시판
    d.put(kit.elevator_door(), -59.5, 25, rot=90)
    f.zone("Directory", [bx((0.15, 5, 3.4), (-59.6, 6.5, 30.6))], t.tex("directory", (44, 62, 92), "plain", 0.5))
    f.zone("DirectoryLines", [bx((0.1, 0.5, 2.6), (-59.5, 4.8 + k * 0.85, 30.6)) for k in range(5)], t.tex("signtext", (250, 248, 240), "plain", 0.4, 0.6))
    f.zone("Mailbox", [box((0.5, 1.2, 1.5), at=(-30.6, 4 + r * 1.4, 22 + c * 1.7), r=0.05, seg=1) for r in range(4) for c in range(5)], t.tex("mail", (170, 176, 180), "metal", 0.4))
    d.put(kit.notice_board(), -30.5, 32.5, y=6.5, rot=-90)
    # 경비실 창구 · 화분 · 자판기 · 계단
    d.put(kit.store_counter(), -37, 19.6, rot=0)
    rd.person(-38.5, 18.6, (70, 84, 110), yaw=0)
    d.put(d.floor_plant(1.5), -57.5, 35)
    d.put(d.vending("mint"), -57.8, 19.8, rot=0)
    d.put(kit.trash_bin(), -54.5, 19.2)
    stairs = Furniture("Stairs")
    stairs.zone("Steps", [bx((1.3, 0.9 * (k + 1), 5), (-52.5 + k * 1.3, 0.45 * (k + 1), 20.4)) for k in range(8)], t.tex("concrete", (176, 176, 172), "plain", 0.8))
    rd.person(-50, 28, (230, 232, 236), yaw=110)


if __name__ == "__main__":
    lib.reset()
    os.makedirs(OUT, exist_ok=True)
    lib.PALETTE["ground"] = (92, 96, 102)
    building()
    neighbors()
    street()
    lib.render(os.path.join(OUT, "arrival_street.png"), eye=(-6, 14, SOUTH + 78), target=(-14, 24, SOUTH), width=1800, height=1100, lens=20, floor="ground", samples=64, sun=2.4, world=0.9, sun_rot=(52, 0, 150))
    lib.render(os.path.join(OUT, "arrival_entrance.png"), eye=(-34, 6.5, SOUTH + 30), target=(-44, 9, SOUTH), width=1800, height=1000, lens=22, floor="ground", samples=64, sun=2.4, world=0.9, sun_rot=(52, 0, 150))
    d.clear()
    lobby()
    lib.render(os.path.join(OUT, "arrival_lobby.png"), eye=(-42, 5.6, 36), target=(-52, 5.2, 21), width=1800, height=1000, lens=18, floor="ground", samples=96, sun=0.0, world=0.05)
    print("DONE")
