# 리뉴얼 7단계 초안: 눈치물산 사무실 층 블록아웃 (신축 오피스 빌딩의 한 층)
# 실행: /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/renewal_nunchi.py
# 설계 좌표: x -56~56, z -34(북쪽 통유리)~34. 지을 때 S(1.25)배 → 실제 140×85칸. 천장 22칸.

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import lib  # noqa: E402
import drafts_spaces as d  # noqa: E402
import drafts_texture as t  # noqa: E402
import office_kit_set as kit  # noqa: E402
import renewal_daechung as rd  # noqa: E402
from lib import Furniture, R, ball, box, cyl  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "salary", "renewal")
S = 1.25
HX, HZ = 56, 34


def bx(size, at, **kw):
    return box(size, at=at, r=0, **kw)


def put(f, x, z, rot=0, y=0):
    return d.put(f, x * S, z * S, rot=rot, y=y)


def shell(h):
    white = t.tex("n_wall", (240, 239, 235), "plain", 0.8)
    dark = t.tex("n_frame", (52, 56, 62), "metal", 0.4)
    glass = t.tex("n_glass", (190, 214, 226), "plain", 0.05, 0.0, 0.22)
    day = t.tex("n_day", (214, 230, 242), "plain", 0.1, 2.4)
    solid, mull, panes, part_glass, part_frame = [], [], [], [], []

    def wall(x1, z1, x2, z2, y1=0, y2=None, bucket=solid, thick=0.7):
        y2 = h if y2 is None else y2
        x1, z1, x2, z2 = x1 * S, z1 * S, x2 * S, z2 * S
        if abs(x2 - x1) < 0.01:
            bucket.append(bx((thick, y2 - y1, abs(z2 - z1)), (x1, (y1 + y2) / 2, (z1 + z2) / 2)))
        else:
            bucket.append(bx((abs(x2 - x1), y2 - y1, thick), ((x1 + x2) / 2, (y1 + y2) / 2, z1)))

    def doors(x1, z1, x2, z2, openings, bucket=solid, door_h=11):
        horizontal = abs(z2 - z1) < 0.01
        a, end = (x1, x2) if horizontal else (z1, z2)
        for center, width in sorted(openings):
            s, e = center - width / 2 / S, center + width / 2 / S
            if horizontal:
                wall(a, z1, s, z1, bucket=bucket)
                wall(s, z1, e, z1, min(door_h, h), h, bucket=bucket)
            else:
                wall(x1, a, x1, s, bucket=bucket)
                wall(x1, s, x1, e, min(door_h, h), h, bucket=bucket)
            a = e
        if horizontal:
            wall(a, z1, end, z1, bucket=bucket)
        else:
            wall(x1, a, x1, end, bucket=bucket)

    # 통유리 외벽: 북쪽 전체 + 서쪽(사무실 쪽)
    for x in range(-HX, HX, 7):
        panes.append(bx((7 * S - 0.4, h - 1.2, 0.2), ((x + 3.5) * S, h / 2, -HZ * S)))
        mull.append(bx((0.5, h, 0.8), (x * S, h / 2, -HZ * S)))
    for z in range(-HZ, 10, 7):
        panes.append(bx((0.2, h - 1.2, 7 * S - 0.4), (-HX * S, h / 2, (z + 3.5) * S)))
        mull.append(bx((0.8, h, 0.5), (-HX * S, h / 2, z * S)))
    mull.append(bx((HX * 2 * S, 0.6, 0.9), (0, 0.3, -HZ * S)))
    wall(-HX, 10, -HX, HZ)
    wall(HX, -HZ, HX, HZ)
    wall(-HX, HZ, HX, HZ)
    # 안쪽 벽
    doors(-HX, 10, 20, 10, [(6, 10)])  # 사무실 ↔ 복도 (넓은 유리문)
    doors(-HX, 20, HX, 20, [(-46, 7), (-22, 8), (6, 8), (32, 7)])  # 화장실 · 라운지 · 폰부스 · 계단실
    wall(-36, 20, -36, HZ)
    wall(-8, 20, -8, HZ)
    wall(20, 20, 20, HZ)
    # 유리 칸막이: 회의실(북동) · 카페 라운지(동)
    doors(20, -HZ, 20, 10, [(-26, 7), (-6, 12)], bucket=part_glass)
    wall(20, -18, HX, -18, bucket=part_glass)
    for z1, z2 in ((-HZ, -18), (-18, 10)):
        part_frame.append(bx((0.5, 0.5, (z2 - z1) * S), (20 * S, h - 0.25 if h < 15 else 11.2, (z1 + z2) / 2 * S)))
    part_frame.append(bx(((HX - 20) * S, 0.5, 0.5), ((HX + 20) / 2 * S, h - 0.25 if h < 15 else 11.2, -18 * S)))
    f = Furniture("NShell")
    f.zone("Wall", solid, white)
    f.zone("Mullion", mull, dark)
    f.zone("Daylight", panes, day)
    f.zone("Partition", part_glass, glass)
    f.zone("PartitionFrame", part_frame, dark)


def floors():
    carpet = t.tex("n_carpet", (176, 178, 176), "carpet", 1.0)
    oak = t.tex("n_oak", (206, 176, 136), "wood", 0.4)
    stone = t.tex("n_stone", (222, 220, 214), "plain", 0.25)
    f = Furniture("NFloor")
    f.zone("Carpet", [bx((76 * S, 0.1, 44 * S), (-18 * S, 0.02, -12 * S)), bx((36 * S, 0.1, 16 * S), (38 * S, 0.02, -26 * S))], carpet)
    f.zone("Oak", [bx((36 * S, 0.1, 28 * S), (38 * S, 0.02, -4 * S)), bx((28 * S, 0.1, 14 * S), (-22 * S, 0.02, 27 * S))], oak)
    f.zone("Stone", [bx((HX * 2 * S, 0.1, 10 * S), (0, 0.02, 15 * S)), bx((20 * S, 0.1, 14 * S), (-46 * S, 0.02, 27 * S)),
                     bx((28 * S, 0.1, 14 * S), (6 * S, 0.02, 27 * S)), bx((36 * S, 0.1, 14 * S), (38 * S, 0.02, 27 * S))], stone)


def furnish():
    # 사무실: 창을 보고 앉는 책상 3줄 × 4, 뒤에 부장님
    for row, z in enumerate((-27, -17, -7)):
        for col, x in enumerate((-44, -30.5, -17, -3.5)):
            t.desk_real(x * S, z * S)
            t.chair_real(x * S + (0.5 if (row + col) % 3 == 0 else 0), z * S + 3.3, yaw=(16 if (row + col) % 3 == 0 else -5 * col))
    put(kit.boss_desk(), -24, 4.5)
    t.chair_real(-24 * S, 4.5 * S + 3.8, yaw=180)
    for x in (-50, -38, 10):
        put(d.floor_plant(1.6), x, 7.5)
    put(d.printer(), 14, -30, rot=0)
    put(d.bookshelf(), 16.5, -12, rot=-90)
    put(d.bookshelf(), 16.5, -17, rot=-90)
    rd.person(-10 * S, 2 * S, (230, 232, 236), yaw=200)
    rd.person(-30.5 * S, -17 * S + 3.4, (196, 208, 226), yaw=0)
    # 유리 회의실
    for x in (30, 36.5, 43):
        put(kit.dining_table(), x, -26)
    for x in (28, 33, 38, 43):
        put(kit.dining_chair(), x, -26 - 2.8 / S, rot=180)
        put(kit.dining_chair(), x, -26 + 2.8 / S)
    screen = Furniture("Screen")
    screen.zone("Frame", [bx((0.3, 5.5, 9), (0, 7, 0))], t.tex("n_frame", (52, 56, 62), "metal", 0.4))
    screen.zone("Glow", [bx((0.1, 4.9, 8.4), (-0.2, 7, 0))], t.tex("n_screen", (150, 190, 226), "plain", 0.2, 1.2))
    put(screen, 55.3, -26)
    # 카페 라운지 (탕비실): 아일랜드 조리대 + 바 의자 + 소파
    put(kit.counter(), 54.6, -4, rot=-90)
    put(kit.fridge(), 54.3, 6.5, rot=-90)
    put(kit.counter(), 38, -6, rot=0)
    for x in (35.5, 38, 40.5):
        put(kit.dining_chair(), x, -6 + 3 / S)
    put(d.rug(7, "mintSoft"), 30, 3.5)
    put(d.sofa("mint", "yellow"), 30, 7.4, rot=180)
    put(d.sofa("mint", "yellow", 5), 24.2, 3, rot=90)
    put(d.table_round(), 30, 3)
    put(d.floor_plant(1.5), 22.5, 8.5)
    put(d.floor_plant(1.4), 53.5, -16)
    put(kit.water_cooler(), 46, 8.8, rot=180)
    rd.person(41 * S, -1 * S, (214, 190, 170), yaw=180)
    # 복도: 안내 데스크 + 로고 벽 + 엘리베이터 2대
    put(d.slat_wall(16), 44, 19.4, rot=180)
    logo = Furniture("Logo")
    logo.zone("Glow", [bx((9, 1.6, 0.2), (0, 9, 0))], t.tex("n_logo", (255, 244, 214), "plain", 0.3, 2.0))
    put(logo, 44, 18.9)
    put(d.reception(), 44, 15.5)
    put(kit.elevator_door(), 55.6, 12.6, rot=-90)
    put(kit.elevator_door(), 55.6, 17.4, rot=-90)
    put(d.floor_plant(1.4), 51, 19)
    put(d.vending("mint"), -54.3, 15, rot=90)
    rd.person(48 * S, 14 * S, (120, 130, 150), yaw=-90)
    # 남쪽: 화장실 · 휴게 라운지 · 폰부스 · 계단실
    for x in (-53, -48.5, -44):
        put(kit.toilet(), x, 32.6, rot=180)
    put(kit.washbasin(), -37.5, 27, rot=-90)
    put(d.pod_chair(), -30, 30, rot=160)
    put(d.pod_chair(), -22, 30.5, rot=180)
    put(d.pod_chair(), -14, 30, rot=200)
    put(d.rug(6, "coralSoft"), -22, 25.5)
    put(d.floor_plant(1.4), -34, 22)
    booth = Furniture("Booths")
    booth.zone("Shell", [box((5, 9, 5), at=((-2 + i * 7.5) * S, 4.5, 30.5 * S), r=0.3, seg=2) for i in range(3)], t.tex("n_booth", (122, 160, 148), "fabric", 0.9))
    booth.zone("Glass", [bx((3.6, 7, 0.15), ((-2 + i * 7.5) * S, 4.2, 30.5 * S - 2.5)) for i in range(3)], t.tex("n_boothglass", (200, 222, 232), "plain", 0.05, 0.4))
    put(kit.locker(), 52, 33, rot=180)
    put(kit.locker(), 53.4, 33, rot=180)


def ceiling(h):
    f = Furniture("NCeiling")
    f.zone("Tiles", [bx((HX * 2 * S + 2, 0.3, HZ * 2 * S + 2), (0, h + 0.15, 0))], t.tex("n_ceiling", (242, 241, 236), "plain", 0.9))
    f.zone("Lights", [bx((0.5, 0.1, 40 * S), (x * S, h - 0.06, -12 * S)) for x in range(-50, 20, 8)]
           + [bx((0.5, 0.1, 22 * S), (x * S, h - 0.06, -4 * S)) for x in range(26, 56, 8)]
           + [bx((HX * 2 * S - 10, 0.1, 0.5), (0, h - 0.06, 15 * S))], t.tex("n_tube", (255, 250, 236), "plain", 0.3, 14.0))
    f.zone("Pendants", [ball((1.6, 1.1, 1.6), at=(x * S, 12, -6 * S), seg=16) for x in (35.5, 38, 40.5)], t.tex("n_pendant", (255, 232, 190), "plain", 0.3, 4.0))


if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    lib.reset()
    os.makedirs(OUT, exist_ok=True)
    lib.PALETTE["ground"] = (92, 96, 102)
    if not only or "overview" in only:
        shell(11)
        floors()
        furnish()
        lib.render(os.path.join(OUT, "nunchi_floor_overview.png"), eye=(10, 150, 62), target=(0, 0, 4), width=2000, height=1300, lens=40, floor="ground", samples=64, sun=1.5, world=0.7)
    if not only or "eye" in only:
        d.clear()
        shell(22)
        floors()
        furnish()
        ceiling(22)
        lib.render(os.path.join(OUT, "nunchi_floor_office.png"), eye=(4 * S, 5.6, 8.5 * S), target=(-26 * S, 6, -30 * S), width=1800, height=1000, lens=20, floor="ground", samples=96, sun=0.0, world=0.05)
        lib.render(os.path.join(OUT, "nunchi_floor_cafe.png"), eye=(22 * S + 2, 5.6, 8.5 * S), target=(46 * S, 4.5, -8 * S), width=1800, height=1000, lens=20, floor="ground", samples=96, sun=0.0, world=0.05)
    print("DONE")
