# 공간 소품 세트 (사무실 A · 옥상 B · 공원 A 초안에서 고른 가구들)
# 실행: /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/space_props_set.py
# 벽·바닥·창·난간·러그처럼 길이가 제각각인 납작한 것들은 메시 대신 게임 코드에서 파트로 지어요.

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import lib  # noqa: E402
import drafts_spaces as d  # noqa: E402
from lib import Furniture, R, ball, box  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "salary")


def sunbed():
    f = Furniture("Sunbed")
    f.zone("Frame", [box((2.6, 0.3, 6.4), at=(0, 0.9, 0), r=0.1)] + [box((0.3, 0.8, 0.3), at=(sx * 1.1, 0.4, sz * 2.7), r=0.08) for sx in (-1, 1) for sz in (-1, 1)], "woodLight")
    f.zone("Mattress", [
        box((2.3, 0.45, 4.2), at=(0, 1.25, 1.0), rv=0.4, r=0.18),
        box((2.3, 0.45, 2.4), at=(0, 1.75, -2.0), r=0.18, rot=R((1, 0, 0), 28)),
    ], "surface")
    f.zone("Pillow", [box((1.5, 0.4, 0.8), at=(0, 2.45, -2.75), r=0.18, rot=R((1, 0, 0), 28))], "sky")
    return f


def stone():
    f = Furniture("Stone")
    f.zone("Stone", [ball((1.9, 0.3, 1.5), at=(0, 0.08, 0), seg=12)], "stone")
    return f


BUILDERS = [
    d.bookshelf, lambda: d.sofa("mint", "yellow"), d.table_round, lambda: d.vending("mint"), d.printer, d.reception,
    lambda: d.planter(("coral", "yellow"), 6, "stone"), d.tree, d.bush, d.bench, d.fountain, d.stall,
    d.pergola, d.pod_chair, d.lamp_post, d.parasol_table, d.flower_bed_default, sunbed, stone,
]


def main():
    lib.reset()
    furniture = []
    for index, build in enumerate(BUILDERS):
        f = build()
        d.put(f, -36 + (index % 7) * 12, -12 + (index // 7) * 13)
        furniture.append(f)
    names = [f.name for f in furniture]
    assert len(set(names)) == len(names), names
    lib.export(os.path.join(OUT, "fbx", "space_props_set.fbx"), furniture, os.path.join(OUT, "fbx", "space_props_set.json"))
    lib.render(os.path.join(OUT, "preview", "space_props_set.png"), eye=(0, 46, 58), target=(0, 0, 3), width=2000, height=1100, lens=38)
    for f in furniture:
        print(f.name, len(f.zones), sum(z["triangles"] for z in f.zones))
    print(f"DONE furniture={len(furniture)} zones={sum(len(f.zones) for f in furniture)} triangles={sum(z['triangles'] for f in furniture for z in f.zones)}")


if __name__ == "__main__":
    main()
