# 질감 초안: 같은 책상 구역을 세 단계로 보여 줘요
#   A 지금(파스텔 토이) / B 같은 모델 + 차분한 색·재질 / C 실제 사무실 비율의 새 모델
# 실행: /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/drafts_texture.py

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402

import lib  # noqa: E402
import drafts_spaces as d  # noqa: E402
import office_desk_set as desk_set  # noqa: E402
from lib import Furniture, R, ball, box, cyl, rod  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "salary", "drafts")
lib.PALETTE["dark"] = (58, 60, 64)

NOISE = {  # 종류 → (무늬 크기, 색 얼룩 세기, 요철 세기)
    "wood": ((1.2, 16, 16), 0.5, 0.12),
    "fabric": ((70, 70, 70), 0.3, 0.45),
    "carpet": ((40, 40, 40), 0.45, 0.8),
    "metal": ((3, 90, 3), 0.15, 0.06),
}


def tex(name, rgb, kind="plain", rough=0.6, emit=0.0):
    key = "T_" + name
    m = bpy.data.materials.get(key)
    if m:
        return m
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    base = [(c / 255) ** 2.2 for c in rgb] + [1]
    bsdf.inputs["Base Color"].default_value = base
    bsdf.inputs["Roughness"].default_value = rough
    if kind == "metal":
        bsdf.inputs["Metallic"].default_value = 0.8
    if emit:
        bsdf.inputs["Emission Color"].default_value = base
        bsdf.inputs["Emission Strength"].default_value = emit
    if kind in NOISE:
        scale, stain, bump_strength = NOISE[kind]
        coord = nt.nodes.new("ShaderNodeTexCoord")
        mapping = nt.nodes.new("ShaderNodeMapping")
        mapping.inputs["Scale"].default_value = scale
        noise = nt.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 3.0
        noise.inputs["Detail"].default_value = 8.0
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position = 0.3
        ramp.color_ramp.elements[0].color = (0.45, 0.45, 0.45, 1)
        ramp.color_ramp.elements[1].position = 0.7
        mix = nt.nodes.new("ShaderNodeMixRGB")
        mix.blend_type = "MULTIPLY"
        mix.inputs["Fac"].default_value = stain
        mix.inputs["Color1"].default_value = base
        bump = nt.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = bump_strength
        bump.inputs["Distance"].default_value = 0.05
        nt.links.new(coord.outputs["Object"], mapping.inputs["Vector"])
        nt.links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
        nt.links.new(noise.outputs[0], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], mix.inputs["Color2"])
        nt.links.new(mix.outputs["Color"], bsdf.inputs["Base Color"])
        nt.links.new(noise.outputs[0], bump.inputs["Height"])
        nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def repaint(rules):
    """이미 만든 물체들의 재질을 이름 규칙으로 바꿔요: {"Desk_Top": material, ...}"""
    for ob in bpy.data.objects:
        if ob.type != "MESH":
            continue
        base = ob.name.split(".")[0]
        if base in rules:
            ob.data.materials[0] = rules[base]


def room_soft(floor_color, wall_color):
    d.floor(40, 26, floor_color, z=2)
    d.window_wall(40, -11)


# ── A: 지금 ──
def style_a():
    room_soft("floorCool", "cream")
    for x in (-13, 0, 13):
        d.workstation(x, -3)
    d.put(d.floor_plant(1.4), -18, -9)
    d.put(d.floor_plant(1.4), 18, -9)


# ── B: 같은 모델, 차분한 색과 재질 ──
def style_b():
    style_a()
    wood = tex("oak", (203, 172, 132), "wood", 0.45)
    cloth = tex("partition", (142, 156, 150), "fabric", 0.95)
    seat = tex("seat", (84, 92, 104), "fabric", 0.95)
    white = tex("white", (232, 230, 225), "plain", 0.5)
    dark = tex("dark", (48, 50, 55), "plain", 0.45)
    steel = tex("steel", (176, 180, 184), "metal", 0.35)
    repaint({
        "Floor_Slab": tex("carpet", (176, 182, 188), "carpet", 1.0),
        "WindowWall_Glass": tex("glass", (196, 216, 230), "plain", 0.15),
        "WindowWall_City": tex("city", (160, 182, 200), "plain", 0.6),
        "WindowWall_Frame": white,
        "Desk_Top": wood, "Desk_Partition": cloth, "Desk_Legs": white, "Desk_Keyboard": dark,
        "Monitor_Frame": dark, "Monitor_Arm": steel, "Monitor_Screen": tex("screen", (170, 200, 225), "plain", 0.3, 0.6),
        "Chair_Seat": seat, "Chair_Back": seat, "Chair_Frame": steel, "Chair_Arms": dark, "Chair_Wheels": dark,
        "Drawer_Body": white, "Drawer_Fronts": white, "Drawer_Top": wood, "Drawer_Handles": steel, "Drawer_Wheels": dark,
        "Lamp_Body": dark, "Lamp_Stem": steel, "Lamp_Bulb": tex("bulb", (255, 236, 200), "plain", 0.4, 1.5),
        "Plant_Pot": white, "Plant_Leaves": tex("leaf", (74, 128, 84), "plain", 0.6), "Plant_LeavesLight": tex("leaf2", (104, 152, 100), "plain", 0.6),
    })


# ── C: 실제 사무실 비율 ──
def desk_real(x, z):
    laminate = tex("laminate", (214, 204, 190), "wood", 0.4)
    cloth = tex("panel", (112, 124, 138), "fabric", 0.95)
    alu = tex("alu", (186, 190, 194), "metal", 0.3)
    dark = tex("dark", (48, 50, 55), "plain", 0.45)
    paper = tex("paper", (244, 243, 238), "plain", 0.7)
    f = Furniture("RDesk")
    f.zone("Top", [box((7.6, 0.16, 3.8), at=(-0.2, 2.48, 0), r=0.03, seg=2)], laminate)
    f.zone("Frame", [box((0.14, 2.4, 0.14), at=(sx, 1.2, sz), r=0.02, seg=1) for sx in (-3.8, 3.4) for sz in (-1.6, 1.6)]
           + [box((0.14, 0.14, 3.34), at=(sx, 0.07, 0), r=0.02, seg=1) for sx in (-3.8, 3.4)]
           + [box((7.2, 0.14, 0.14), at=(-0.2, 2.3, -1.6), r=0.02, seg=1)], alu)
    f.zone("Panel", [box((8.2, 4.2, 0.2), at=(-0.2, 2.1, -2.1), r=0.03, seg=1),
                     box((0.2, 4.2, 3.4), at=(-4.3, 2.1, -0.5), r=0.03, seg=1),
                     box((0.2, 4.2, 3.4), at=(3.9, 2.1, -0.5), r=0.03, seg=1)], cloth)
    f.zone("Trim", [box((8.3, 0.1, 0.28), at=(-0.2, 4.25, -2.1), r=0.02, seg=1)]
           + [box((0.28, 0.1, 3.5), at=(sx, 4.25, -0.5), r=0.02, seg=1) for sx in (-4.3, 3.9)]
           + [box((0.26, 4.3, 0.26), at=(sx, 2.15, 1.2), r=0.03, seg=1) for sx in (-4.3, 3.9)], alu)
    f.zone("Keys", [box((1.9, 0.08, 0.62), at=(-0.3, 2.6, 0.5), r=0.02, seg=1), box((0.34, 0.12, 0.56), at=(1.3, 2.62, 0.55), r=0.05)], dark)
    f.zone("Paper", [box((1.0, 0.03, 1.4), at=(-2.4, 2.58, 0.3), r=0, rot=R((0, 1, 0), 12)),
                     box((1.0, 0.03, 1.4), at=(-2.2, 2.61, 0.4), r=0, rot=R((0, 1, 0), -8))], paper)
    f.zone("Mug", [cyl(0.2, 0.42, at=(2.3, 2.77, -0.6), bevel=0.03)], tex("mug", (190, 80, 70), "plain", 0.3))
    d.put(f, x, z)

    m = Furniture("RMonitor")
    m.zone("Panel", [box((3.3, 1.95, 0.1), at=(0.3, 4.05, -1.2), r=0.03, seg=1),
                     box((0.26, 1.2, 0.1), at=(0.3, 3.1, -1.28), r=0.02, seg=1),
                     box((1.5, 0.06, 0.9), at=(0.3, 2.59, -1.25), r=0.02, seg=1)], dark)
    m.zone("Screen", [box((3.16, 1.78, 0.02), at=(0.3, 4.07, -1.14), r=0)], tex("screen2", (205, 220, 232), "plain", 0.25, 0.7))
    d.put(m, x, z)

    w = Furniture("RDrawer")
    w.zone("Body", [box((1.7, 2.05, 2.4), at=(0, 1.1, 0), r=0.04, seg=1)], tex("cabinet", (206, 208, 210), "plain", 0.45))
    w.zone("Lines", [box((1.56, 0.03, 0.03), at=(0, y, 1.2), r=0) for y in (0.75, 1.4, 1.75)]
           + [box((0.7, 0.07, 0.04), at=(0, y, 1.21), r=0) for y in (1.05, 1.58, 1.92)], dark)
    d.put(w, x + 2.5, z + 0.3)


def chair_real(x, z, yaw=0):
    fabric = tex("mesh", (40, 42, 46), "fabric", 0.9)
    dark = tex("dark", (48, 50, 55), "plain", 0.45)
    f = Furniture("RChair")
    f.zone("Seat", [box((1.9, 0.32, 1.9), at=(0, 1.62, 0), rv=0.35, r=0.1)], fabric)
    f.zone("Back", [box((1.8, 2.3, 0.14), at=(0, 3.15, 1.0), axis="z", rv=0.4, r=0.04, rot=R((1, 0, 0), 9))], fabric)
    frame = [cyl(0.1, 1.0, at=(0, 0.95, 0)), cyl(0.2, 0.2, at=(0, 0.42, 0)),
             rod((0, 1.45, 0.6), (0, 2.2, 1.12), 0.08), rod((0, 2.2, 1.12), (0, 3.9, 1.2), 0.07)]
    wheels = []
    for k in range(5):
        a = math.radians(90 + 72 * k)
        tip = (1.2 * math.cos(a), 0.3, 1.2 * math.sin(a))
        frame.append(rod((0, 0.42, 0), tip, 0.07))
        wheels.append(ball(0.28, at=(tip[0], 0.14, tip[2])))
    for side in (-1, 1):
        frame.append(rod((side * 0.95, 1.55, 0.2), (side * 1.1, 2.3, 0.2), 0.06))
        frame.append(box((0.24, 0.1, 1.1), at=(side * 1.1, 2.36, 0.1), r=0.04))
    f.zone("Frame", frame, dark)
    f.zone("Wheels", wheels, dark)
    d.put(f, x, z, rot=yaw)


def style_c():
    carpet_a = tex("tileA", (172, 178, 186), "carpet", 1.0)
    carpet_b = tex("tileB", (156, 162, 170), "carpet", 1.0)
    f = Furniture("RFloor")
    f.zone("TileA", [box((3.96, 0.1, 3.96), at=(-18 + i * 4, 0.02, -9 + j * 4), r=0) for i in range(10) for j in range(7) if (i + j) % 2 == 0], carpet_a)
    f.zone("TileB", [box((3.96, 0.1, 3.96), at=(-18 + i * 4, 0.02, -9 + j * 4), r=0) for i in range(10) for j in range(7) if (i + j) % 2 == 1], carpet_b)
    f.zone("Gap", [box((40, 0.08, 28), at=(0, 0.02, 3), r=0)], tex("gap", (70, 74, 80), "plain", 1.0))
    wall = Furniture("RWall")
    wall.zone("Wall", [box((40, 3, 0.5), at=(0, 1.5, -11), r=0), box((40, 1.6, 0.5), at=(0, 10.2, -11), r=0)]
              + [box((1.2, 11, 0.62), at=(x, 5.5, -11), r=0) for x in (-19.4, -6.6, 6.6, 19.4)], tex("wall", (236, 234, 228), "plain", 0.8))
    wall.zone("Glass", [box((11.6, 6.4, 0.1), at=(x, 6.2, -11.1), r=0) for x in (-13, 0, 13)], tex("sky", (188, 212, 232), "plain", 0.1, 0.5))
    wall.zone("Blinds", [box((11.6, 0.05, 0.3), at=(x, 9.3 - k * 0.34, -10.7), r=0, rot=R((1, 0, 0), 30)) for x in (-13, 0, 13) for k in range(9)], tex("blind", (226, 224, 216), "plain", 0.5))
    wall.zone("Base", [box((40, 0.5, 0.56), at=(0, 0.25, -10.98), r=0)], tex("base", (72, 74, 78), "plain", 0.6))
    for i, x in enumerate((-13, 0, 13)):
        desk_real(x, -3)
        chair_real(x + (0.6 if i == 1 else 0), 0.3 + (0.5 if i == 1 else 0), yaw=(25 if i == 1 else -6 * i))
    plant = d.put(d.floor_plant(1.5), -18, -8.5)
    repaint({"Plant_Pot": tex("pot", (90, 92, 96), "plain", 0.6), "Plant_Leaves": tex("leaf", (64, 112, 74), "plain", 0.6), "Plant_LeavesLight": tex("leaf2", (92, 138, 90), "plain", 0.6)})
    cab = Furniture("RCabinet")
    cab.zone("Body", [box((5, 4.4, 1.6), at=(0, 2.2, 0), r=0.04, seg=1)], tex("cabinet", (206, 208, 210), "plain", 0.45))
    cab.zone("Lines", [box((0.04, 4.2, 0.03), at=(0, 2.2, 0.8), r=0), box((4.8, 0.04, 0.03), at=(0, 2.2, 0.8), r=0)], tex("dark", (48, 50, 55), "plain", 0.45))
    cab.zone("Boxes", [box((1.4, 1.0, 1.1), at=(-1.2, 4.9, 0), r=0.03, seg=1), box((1.4, 1.0, 1.1), at=(0.5, 4.9, 0.1), r=0.03, seg=1, rot=R((0, 1, 0), 8))], tex("cardboard", (184, 150, 108), "plain", 0.9))
    d.put(cab, 17.3, -9.6)


SCENES = [
    ("texture_a_now", style_a, dict(sun=1.6, world=0.45, floor="floorCool")),
    ("texture_b_calm", style_b, dict(sun=1.7, world=0.6, floor="muted")),
    ("texture_c_real", style_c, dict(sun=1.7, world=0.6, floor="muted")),
]

if __name__ == "__main__":
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    lib.reset()
    os.makedirs(OUT, exist_ok=True)
    for name, build, light in SCENES:
        if only and name not in only:
            continue
        d.clear()
        build()
        lib.render(os.path.join(OUT, name + ".png"), eye=(8, 13, 23), target=(0, 2.5, -3), width=1500, height=900, lens=30, samples=72, **light)
        print("RENDERED", name)
