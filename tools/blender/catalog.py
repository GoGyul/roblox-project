# 메시 카탈로그: 만든 모델들을 종류별로 가까이서 보여 주는 확대 렌더 (질감 B안 색)
# 실행: /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/catalog.py

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import lib  # noqa: E402
import drafts_spaces as d  # noqa: E402
import office_desk_set as desk  # noqa: E402
import office_kit_set as kit  # noqa: E402  (불러오면 팔레트가 B안 색으로 바뀌어요)
import space_props_set as props  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "salary", "catalog")
lib.PALETTE.update({"grass": (74, 128, 84), "grassLight": (104, 152, 100), "water": (128, 184, 214), "coralSoft": (216, 190, 182), "mintSoft": (188, 204, 198)})


def chair_calm():
    return d.recolor(desk.build_chair(), {"Seat": "seat", "Back": "seat"})


GROUPS = {
    "2_office": [(d.bookshelf, 5.2), (lambda: d.sofa("mint", "yellow"), 6), (d.table_round, 3), (lambda: d.vending("mint"), 3), (d.printer, 3.2), (d.reception, 6.8), (desk.build_plant, 2.6)],
    "3_outdoor": [(d.tree, 6.5), (d.bench, 4.4), (d.fountain, 7.8), (d.lamp_post, 1.4), (d.flower_bed_default, 7), (lambda: d.planter(("coral", "yellow"), 6, "stone"), 6), (d.bush, 3)],
    "4_rooftop": [(d.stall, 6.6), (d.pergola, 9.8), (d.pod_chair, 4.4), (d.parasol_table, 6.8), (props.sunbed, 2.8)],
    "5_building": [(kit.wall_panel, 8), (kit.window_panel, 8), (kit.pillar, 1.6), (kit.door_frame, 7.2), (kit.elevator_door, 6.4), (kit.floor_tile, 8), (lambda: kit.ceiling_tile(True), 8)],
    "6_rooms": [(kit.boss_desk, 10), (kit.counter, 8.4), (kit.fridge, 3.2), (kit.dining_table, 6.2), (kit.dining_chair, 2), (kit.toilet, 2.4), (kit.washbasin, 4.2), (kit.water_cooler, 1.6)],
    "7_store_gym": [(kit.store_shelf, 6.2), (kit.store_counter, 6.5), (kit.locker, 1.8), (kit.treadmill, 2.9), (kit.dumbbell_rack, 5.2), (kit.weight_bench, 6.6), (kit.cardboard_box, 2.6), (kit.trash_bin, 1.8)],
}


def desk_closeup():
    d.put(d.recolor(desk.build_desk(), {"Partition": "sage"}), 0, 0)
    d.put(desk.build_monitor(), 0, 0)
    d.put(desk.build_drawer(), 2.6, 0.3)
    d.put(desk.build_lamp(), -3.1, -1, y=2.56)
    d.put(chair_calm(), 0.6, 3.6, rot=25)
    lib.render(os.path.join(OUT, "1_desk.png"), eye=(7.5, 7.5, 10.5), target=(0, 2.4, 0.6), width=1600, height=1000, lens=42, floor="carpetDark", samples=64)
    d.clear()
    d.put(chair_calm(), -3.2, 0, rot=-150)
    d.put(desk.build_monitor(), 0.3, 1.5, y=-2.56)
    d.put(desk.build_drawer(), 4.2, 0, rot=20)
    d.put(desk.build_lamp(), 7, 0)
    lib.render(os.path.join(OUT, "1_desk_parts.png"), eye=(3.5, 4.2, 9.5), target=(1.6, 1.6, 0), width=1600, height=800, lens=42, floor="carpetDark", samples=64)


if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    lib.reset()
    os.makedirs(OUT, exist_ok=True)
    if not only or "1_desk" in only:
        desk_closeup()
    for name, items in GROUPS.items():
        if only and name not in only:
            continue
        d.clear()
        total = sum(w for _, w in items) + 1.6 * (len(items) - 1)
        x = -total / 2
        for build, width in items:
            f = build()
            lift = 7 if f.name.startswith("Ceiling") else 0
            d.put(f, x + width / 2, 0, y=lift, rot=-12 if f.name not in ("WallPanel", "WindowPanel", "FloorTile", "CeilingLight") else 0)
            x += width + 1.6
        lib.render(os.path.join(OUT, name + ".png"), eye=(total * 0.08, total * 0.3 + 3, total * 0.82 + 7), target=(0, 3, 0), width=2000, height=900, lens=32, floor="carpetDark", samples=64)
        print("RENDERED", name)
