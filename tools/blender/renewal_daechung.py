# 리뉴얼 1단계: 대충상사 3층 평면 블록아웃 (낡은 상가 건물의 중소기업 사무실)
# 실행: /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/renewal_daechung.py
# 좌표: x 동서(-48~48), z 남북(-30 창가 ~ 30), 1칸 = 스터드. 캐릭터 키 약 5칸.

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import lib  # noqa: E402
import drafts_spaces as d  # noqa: E402
import drafts_texture as t  # noqa: E402
import office_kit_set as kit  # noqa: E402
from lib import Furniture, R, ball, box  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "salary", "renewal")
H = 11  # 천장 높이


def slab(name, x1, z1, x2, z2, material, y=0.0, h=0.1):
    f = Furniture(name)
    f.zone("Slab", [box((x2 - x1, h, z2 - z1), at=((x1 + x2) / 2, y, (z1 + z2) / 2), r=0)], material)
    return f


def walls():
    paint = t.tex("oldwall", (226, 222, 210), "plain", 0.85)
    segs = []

    def w(x1, z1, x2, z2, y1=0, y2=H, thick=0.6):
        if abs(x2 - x1) < 0.01:
            segs.append(box((thick, y2 - y1, abs(z2 - z1)), at=(x1, (y1 + y2) / 2, (z1 + z2) / 2), r=0))
        else:
            segs.append(box((abs(x2 - x1), y2 - y1, thick), at=((x1 + x2) / 2, (y1 + y2) / 2, z1), r=0))

    def with_doors(x1, z1, x2, z2, doors, door_h=8):
        """문 구멍(중심, 폭) 목록을 뚫은 벽."""
        horizontal = abs(z2 - z1) < 0.01
        a = x1 if horizontal else z1
        end = x2 if horizontal else z2
        for center, width in sorted(doors):
            s, e = center - width / 2, center + width / 2
            if horizontal:
                w(a, z1, s, z1)
                w(s, z1, e, z1, door_h, H)
            else:
                w(x1, a, x1, s)
                w(x1, s, x1, e, door_h, H)
            a = e
        if horizontal:
            w(a, z1, end, z1)
        else:
            w(x1, a, x1, end)

    # 바깥 벽 (북쪽 창가는 창턱 + 창 위 벽 + 기둥)
    w(-48, -30, 48, -30, 0, 3.2)
    w(-48, -30, 48, -30, 9, H)
    for x in range(-48, 49, 12):
        w(x - 0.6, -30, x + 0.6, -30, 3.2, 9, thick=0.9)
    w(48, -30, 48, 30)
    w(-48, 30, 48, 30)
    w(-48, -30, -48, 30)
    # 안쪽 벽
    with_doors(22, -30, 22, 12, [(-23, 4), (-10, 4)])  # 사무실 ↔ 회의실 / 비품실
    with_doors(-48, 12, 22, 12, [(-9, 6)])  # 사무실 유리문
    with_doors(22, 12, 40, 12, [(31, 7)])  # 탕비실 입구
    with_doors(-48, 20, 40, 20, [(-38, 4), (-18, 4), (10, 5), (34, 4)])  # 화장실 / 문서고 / 휴게실 / 계단
    w(22, -16, 48, -16)
    w(22, -4, 48, -4)
    w(-28, 20, -28, 30)
    w(-8, 20, -8, 30)
    w(28, 20, 28, 30)
    f = Furniture("Walls")
    f.zone("Paint", segs, paint)
    f.zone("Glass", [box((11, 5.8, 0.15), at=(x + 6, 6.1, -30), r=0) for x in range(-48, 48, 12)], t.tex("daylight", (206, 224, 238), "plain", 0.1, 2.2))
    f.zone("Blinds", [box((10.8, 0.05, 0.3), at=(x + 6, 8.8 - k * 0.34, -29.6), r=0, rot=R((1, 0, 0), 30)) for x in range(-48, 22, 12) for k in range(6)], t.tex("blind", (226, 224, 216), "plain", 0.5))
    f.zone("Base", [box((70, 0.5, 0.1), at=(-13, 0.25, 11.65), r=0), box((0.1, 0.5, 42), at=(-47.65, 0.25, -9), r=0), box((0.1, 0.5, 42), at=(21.65, 0.25, -9), r=0)], t.tex("base", (72, 74, 78), "plain", 0.6))
    f.zone("DoorGlass", [box((6, 8, 0.12), at=(-9, 4, 12), r=0)], t.tex("doorglass", (170, 196, 206), "plain", 0.1))


def person(x, z, shirt, yaw=0):
    f = Furniture("Person")
    f.zone("Legs", [box((1.7, 2.1, 0.9), at=(0, 1.05, 0), r=0.15)], t.tex("slacks", (52, 56, 66), "fabric", 0.9))
    f.zone("Shirt", [box((2.0, 2.0, 1.0), at=(0, 3.1, 0), r=0.2), box((0.7, 1.9, 0.8), at=(-1.4, 3.1, 0), r=0.2), box((0.7, 1.9, 0.8), at=(1.4, 3.1, 0), r=0.2)], t.tex("shirt" + str(shirt), shirt, "fabric", 0.9))
    f.zone("Head", [ball(1.35, at=(0, 4.8, 0), seg=16)], t.tex("skin", (232, 200, 172), "plain", 0.7))
    d.put(f, x, z, rot=yaw)


def cabinet(x, z, yaw=0, width=5.0, height=4.4):
    f = Furniture("RCabinet")
    f.zone("Body", [box((width, height, 1.6), at=(0, height / 2, 0), r=0.04, seg=1)], t.tex("cabinet", (206, 208, 210), "plain", 0.45))
    f.zone("Lines", [box((0.04, height - 0.2, 0.03), at=(0, height / 2, 0.8), r=0), box((width - 0.2, 0.04, 0.03), at=(0, height / 2, 0.8), r=0)], t.tex("dark", (48, 50, 55), "plain", 0.45))
    d.put(f, x, z, rot=yaw)


def furnish():
    carpet = t.tex("oldcarpet", (150, 152, 150), "carpet", 1.0)
    vinyl = t.tex("vinyl", (206, 196, 174), "plain", 0.35)
    tile = t.tex("tile", (214, 220, 222), "plain", 0.25)
    slab("FloorOffice", -48, -30, 22, 12, carpet)
    slab("FloorEast", 22, -30, 48, -4, carpet)
    slab("FloorPantry", 22, -4, 48, 12, vinyl)
    slab("FloorCorridor", -48, 12, 48, 20, vinyl)
    slab("FloorToilet", -48, 20, -28, 30, tile)
    slab("FloorSouth", -28, 20, 48, 30, vinyl)
    # 사무실: 창을 보고 앉는 책상 2줄 × 5, 그 뒤에 부장님
    for row, z in enumerate((-21, -9)):
        for col, x in enumerate((-41, -30, -19, -8, 3)):
            t.desk_real(x, z)
            t.chair_real(x + (0.5 if (row + col) % 3 == 0 else 0), z + 3.3 + (0.4 if (row + col) % 3 == 0 else 0), yaw=(18 if (row + col) % 3 == 0 else -4 * col))
    d.put(kit.boss_desk(), -19, 4)
    t.chair_real(-19, 7.6, yaw=180)
    for x in (2, 7.4, 12.8):
        cabinet(x, 10.9, yaw=180)
    cabinet(20.9, 3, yaw=-90, width=6, height=7)
    d.put(d.printer(), 16, -3, rot=-90)
    d.put(kit.cardboard_box(), 16.5, -8)
    d.put(kit.cardboard_box(), 19, -7.2, rot=20)
    d.put(kit.water_cooler(), -3.5, 10.8, rot=180)
    d.put(kit.trash_bin(), 12, -2)
    d.put(d.floor_plant(1.3), -45.5, 9.5)
    d.put(d.floor_plant(1.3), 19.5, -27.5)
    d.put(kit.notice_board(), -30, 11.6, y=5.5, rot=180)
    person(4, -2, (230, 232, 236), yaw=200)
    person(-30, -17.7, (196, 208, 226), yaw=0)
    # 회의실
    d.put(kit.dining_table(), 32, -23)
    d.put(kit.dining_table(), 38, -23)
    for x in (30.5, 35, 39.5):
        d.put(kit.dining_chair(), x, -26, rot=0 + 180)
        d.put(kit.dining_chair(), x, -20, rot=0)
    d.put(kit.notice_board(), 47.6, -23, y=5.5, rot=-90)
    # 비품실
    d.put(kit.store_shelf(), 46.5, -10, rot=-90)
    d.put(kit.locker(), 24, -14.8, rot=0 + 180)
    d.put(kit.locker(), 25.7, -14.8, rot=180)
    d.put(kit.cardboard_box(), 30, -7)
    d.put(kit.cardboard_box(), 32.8, -6.6, rot=15)
    d.put(kit.cardboard_box(), 31.2, -6.8, y=2)
    # 탕비실
    d.put(kit.counter(), 46.5, 4, rot=-90)
    d.put(kit.fridge(), 46.3, 10, rot=-90)
    d.put(kit.dining_table(), 30, 4)
    for x in (28.5, 31.5):
        d.put(kit.dining_chair(), x, 1.2, rot=180)
        d.put(kit.dining_chair(), x, 6.8)
    d.put(kit.trash_bin(), 23.5, -2.5)
    person(41, 4.5, (214, 190, 170), yaw=90)
    # 복도 · 엘리베이터 홀
    d.put(d.vending("mint"), -45.8, 16, rot=90)
    d.put(kit.notice_board(), 0, 19.6, y=5.5, rot=180)
    d.put(kit.elevator_door(), 47.6, 16, rot=-90)
    d.put(d.floor_plant(1.2), 45.5, 13.3)
    d.put(kit.trash_bin(), -41, 13.2)
    person(22, 17.6, (120, 130, 150), yaw=-90)
    # 화장실
    for x in (-45, -40.5, -36):
        d.put(kit.toilet(), x, 28.2, rot=180)
    stall = Furniture("Stalls")
    stall.zone("Panel", [box((0.2, 7, 5), at=(x, 3.5, 27.2), r=0) for x in (-42.75, -38.25, -33.8)] + [box((13.4, 7, 0.2), at=(-41, 3.5, 24.7), r=0)], t.tex("stall", (150, 160, 166), "plain", 0.5))
    d.put(kit.washbasin(), -30, 22.2, rot=0)
    # 문서고
    d.put(kit.store_shelf(), -18, 29, rot=180)
    cabinet(-26.9, 25, yaw=90, width=6, height=7)
    d.put(kit.cardboard_box(), -11, 27.5)
    # 휴게실
    d.put(d.sofa("mint", "yellow"), 4, 28.2, rot=180)
    d.put(d.sofa("mint", "yellow", 5), 25.5, 25, rot=-90)
    d.put(d.table_round(), 6, 24)
    d.put(d.floor_plant(1.3), -5.5, 28)
    # 계단
    stairs = Furniture("Stairs")
    stairs.zone("Steps", [box((8, 0.8 * (k + 1), 1.2), at=(34, 0.4 * (k + 1), 21.2 + k * 1.2), r=0) for k in range(7)], t.tex("concrete", (176, 176, 172), "plain", 0.8))


def ceiling():
    f = Furniture("Ceiling")
    f.zone("Tiles", [box((96, 0.3, 60), at=(0, H + 0.15, 0), r=0)], t.tex("ceiling", (236, 235, 230), "plain", 0.9))
    f.zone("Grid", [box((96, 0.06, 0.12), at=(0, H - 0.02, z), r=0) for z in range(-30, 31, 4)] + [box((0.12, 0.06, 60), at=(x, H - 0.02, 0), r=0) for x in range(-48, 49, 4)], t.tex("gridbar", (200, 200, 196), "plain", 0.6))
    f.zone("Lights", [box((1.4, 0.1, 5.4), at=(x, H - 0.06, z), r=0) for x in range(-42, 20, 12) for z in (-24, -12, 0)]
           + [box((5.4, 0.1, 1.4), at=(x, H - 0.06, 16), r=0) for x in range(-40, 44, 16)]
           + [box((1.4, 0.1, 5.4), at=(x, H - 0.06, z), r=0) for x, z in ((35, -23), (35, -10), (35, 4), (-38, 25), (-18, 25), (10, 25))], t.tex("tube", (255, 250, 236), "plain", 0.3, 9.0))


if __name__ == "__main__":
    lib.reset()
    os.makedirs(OUT, exist_ok=True)
    lib.PALETTE["ground"] = (92, 96, 102)
    walls()
    furnish()
    lib.render(os.path.join(OUT, "daechung_3f_overview.png"), eye=(8, 118, 46), target=(0, 0, 3), width=2000, height=1300, lens=40, floor="ground", samples=64, sun=1.5, world=0.7)
    ceiling()
    lib.render(os.path.join(OUT, "daechung_3f_office.png"), eye=(-8.5, 5.4, 10.2), target=(-22, 4.2, -22), width=1800, height=1000, lens=20, floor="ground", samples=96, sun=0.0, world=0.05)
    lib.render(os.path.join(OUT, "daechung_3f_corridor.png"), eye=(44, 5.4, 16.2), target=(-40, 4.6, 16), width=1800, height=1000, lens=20, floor="ground", samples=96, sun=0.0, world=0.05)
    print("DONE")
