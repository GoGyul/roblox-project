# 월급루팡 메시 제작 도구 (Blender 4.5에서 실행)
# 모든 좌표는 로블록스 기준(스터드, Y가 위, 가구 원점 = 바닥 가운데)으로 적고,
# 여기서 Blender 좌표(Z가 위)로 바꿔요.

import json
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

# shared/SalaryTheme.luau 와 같은 색
PALETTE = {
    "cream": (250, 248, 241),
    "surface": (255, 255, 252),
    "surfaceSoft": (240, 247, 246),
    "navy": (34, 53, 76),
    "navySoft": (63, 82, 105),
    "muted": (105, 120, 139),
    "mint": (105, 215, 181),
    "mintDark": (42, 142, 125),
    "mintSoft": (204, 241, 228),
    "sage": (168, 213, 191),
    "sky": (99, 184, 231),
    "skySoft": (213, 238, 250),
    "coral": (247, 112, 111),
    "coralSoft": (255, 218, 213),
    "yellow": (250, 193, 70),
    "yellowSoft": (255, 238, 184),
    "wood": (218, 184, 142),
    "woodLight": (239, 218, 185),
    "woodDark": (150, 112, 78),
    "grass": (100, 177, 110),
    "grassLight": (140, 205, 130),
    "line": (181, 210, 218),
    "metal": (201, 211, 218),
}

AXIS_INDEX = {"x": 0, "y": 2, "z": 1}  # 로블록스 축 → Blender 축 번호


def P(x, y, z):
    return Vector((x, -z, y))


def S(x, y, z):
    return Vector((x, z, y))


def R(axis, degrees):
    """로블록스 축 기준 회전."""
    return Matrix.Rotation(math.radians(degrees), 4, P(*axis))


def T(x, y, z):
    return Matrix.Translation(P(x, y, z))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def _finish(bm, at=None, rot=None, mat=None):
    if mat is None:
        mat = Matrix.Translation(P(*at)) if at else Matrix.Identity(4)
        if rot is not None:
            mat = mat @ rot
    bm.transform(mat)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("tmp")
    bm.to_mesh(me)
    bm.free()
    return me


def _sharp_edges(bm, degrees):
    limit = math.radians(degrees)
    return [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0) > limit]


def box(size, at=None, r=0.1, rv=0.0, axis="y", seg=3, segv=8, rot=None, mat=None):
    """둥근 상자. rv: axis 방향 모서리 4개를 크게 둥글려요(알약·둥근 판). r: 나머지 모서리."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=S(*size), verts=bm.verts)
    if rv > 0:
        i = AXIS_INDEX[axis]
        edges = [e for e in bm.edges if abs((e.verts[0].co - e.verts[1].co).normalized()[i]) > 0.99]
        bmesh.ops.bevel(bm, geom=edges, offset=rv, segments=segv, profile=0.5, affect="EDGES", clamp_overlap=True)
        if r > 0:
            bmesh.ops.bevel(bm, geom=_sharp_edges(bm, 30), offset=r, segments=seg, profile=0.5, affect="EDGES", clamp_overlap=True)
    elif r > 0:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=r, segments=seg, profile=0.5, affect="EDGES", clamp_overlap=True)
    return _finish(bm, at, rot, mat)


def cyl(r, h, at=None, axis="y", r2=None, bevel=0.0, seg=28, rot=None, mat=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=h)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=_sharp_edges(bm, 50), offset=bevel, segments=3, profile=0.5, affect="EDGES", clamp_overlap=True)
    if axis == "x":
        bm.transform(Matrix.Rotation(math.radians(90), 4, "Y"))
    elif axis == "z":
        bm.transform(Matrix.Rotation(math.radians(90), 4, "X"))
    return _finish(bm, at, rot, mat)


def ball(size, at=None, seg=24, rot=None, mat=None):
    if isinstance(size, (int, float)):
        size = (size, size, size)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2, radius=0.5)
    bmesh.ops.scale(bm, vec=S(*size), verts=bm.verts)
    return _finish(bm, at, rot, mat)


def rod(p1, p2, r, seg=16):
    """두 점을 잇는 둥근 막대."""
    a, b = P(*p1), P(*p2)
    d = b - a
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=seg, radius1=r, radius2=r, depth=d.length)
    for end in (-0.5, 0.5):
        cap = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2, radius=r)
        bmesh.ops.translate(bm, vec=(0, 0, end * d.length), verts=cap["verts"])
    mat = Matrix.Translation((a + b) / 2) @ d.to_track_quat("Z", "Y").to_matrix().to_4x4()
    return _finish(bm, mat=mat)


def lathe(profile, at=None, seg=32, rot=None, mat=None):
    """(반지름, 높이) 점들을 Y축 둘레로 돌려 만든 회전체."""
    bm = bmesh.new()
    rings = []
    for radius, height in profile:
        if radius < 1e-6:
            rings.append([bm.verts.new((0, 0, height))])
        else:
            rings.append([
                bm.verts.new((radius * math.cos(2 * math.pi * k / seg), radius * math.sin(2 * math.pi * k / seg), height))
                for k in range(seg)
            ])
    for a, b in zip(rings, rings[1:]):
        for k in range(seg):
            n = (k + 1) % seg
            if len(a) == 1 and len(b) == 1:
                continue
            if len(a) == 1:
                bm.faces.new((a[0], b[k], b[n]))
            elif len(b) == 1:
                bm.faces.new((a[k], b[0], a[n]))
            else:
                bm.faces.new((a[k], b[k], b[n], a[n]))
    return _finish(bm, at, rot, mat)


def arc(cx, cy, radius, start, end, steps=8):
    """lathe 윤곽용 원호 점들 (각도는 도, 0 = +반지름 방향, 90 = 위)."""
    return [
        (cx + radius * math.cos(math.radians(start + (end - start) * k / steps)),
         cy + radius * math.sin(math.radians(start + (end - start) * k / steps)))
        for k in range(steps + 1)
    ]


def _temp_object(me):
    ob = bpy.data.objects.new("tmp", me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def boolean(a, b, operation="DIFFERENCE"):
    oa, ob = _temp_object(a), _temp_object(b)
    mod = oa.modifiers.new("bool", "BOOLEAN")
    mod.operation = operation
    mod.solver = "EXACT"
    mod.object = ob
    bpy.context.view_layer.update()
    result = bpy.data.meshes.new_from_object(oa.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(oa)
    bpy.data.objects.remove(ob)
    return result


def round_edges(me, r, seg=3, degrees=50):
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.bevel(bm, geom=_sharp_edges(bm, degrees), offset=r, segments=seg, profile=0.5, affect="EDGES", clamp_overlap=True)
    out = bpy.data.meshes.new("tmp")
    bm.to_mesh(out)
    bm.free()
    return out


def _material(color, material):
    key = f"{color}_{material}"
    mat = bpy.data.materials.get(key)
    if mat:
        return mat
    mat = bpy.data.materials.new(key)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    rgb = [((c / 255) ** 2.2) for c in PALETTE[color]]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Roughness"].default_value = 0.85 if material == "Fabric" else 0.55
    if material == "Neon":
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1)
        bsdf.inputs["Emission Strength"].default_value = 1.2
    mat.diffuse_color = (*rgb, 1)
    return mat


class Furniture:
    """색 구역(zone)마다 메시 하나. 구역 이름이 로블록스 MeshPart 이름이 돼요."""

    def __init__(self, name):
        self.name = name
        self.root = bpy.data.objects.new(name, None)
        bpy.context.scene.collection.objects.link(self.root)
        self.zones = []

    def zone(self, name, meshes, color, material="SmoothPlastic", smooth_angle=40):
        bm = bmesh.new()
        for me in meshes:
            bm.from_mesh(me)
            bpy.data.meshes.remove(me)
        lo = Vector((min(v.co[i] for v in bm.verts) for i in range(3)))
        hi = Vector((max(v.co[i] for v in bm.verts) for i in range(3)))
        center = (lo + hi) / 2
        bmesh.ops.translate(bm, vec=-center, verts=bm.verts)
        # 상자 투영 UV (1 UV = 4칸): 로블록스 재질 무늬가 메시 표면에 고르게 깔리도록
        uv_layer = bm.loops.layers.uv.new("UVMap")
        for face in bm.faces:
            face.smooth = True
            normal = face.normal
            axis = max(range(3), key=lambda i: abs(normal[i]))
            a, b = [i for i in range(3) if i != axis]
            for loop in face.loops:
                loop[uv_layer].uv = (loop.vert.co[a] / 4.0, loop.vert.co[b] / 4.0)
        full = f"{self.name}_{name}"
        me = bpy.data.meshes.new(full)
        bm.to_mesh(me)
        tris = sum(len(f.verts) - 2 for f in bm.faces)
        bm.free()
        me.set_sharp_from_angle(angle=math.radians(smooth_angle))
        me.materials.append(color if not isinstance(color, str) else _material(color, material))  # 재질을 직접 줘도 돼요 (초안용)
        color = color if isinstance(color, str) else color.name
        ob = bpy.data.objects.new(full, me)
        ob.location = center
        ob.parent = self.root
        bpy.context.scene.collection.objects.link(ob)
        size = hi - lo
        self.zones.append({
            "name": full,
            "color": color,
            "material": material,
            "size": [round(size.x, 3), round(size.z, 3), round(size.y, 3)],
            "center": [round(center.x, 3), round(center.z, 3), round(-center.y, 3)],
            "triangles": tris,
        })
        return ob

    def place(self, x, y, z):
        self.root.location = P(x, y, z)


def export(path, furniture, manifest_path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.fbx(
        filepath=path,
        object_types={"EMPTY", "MESH"},
        axis_forward="-Z",  # 어느 쪽으로 내보내도 로블록스에선 180° 돌아가 있어요 → Meshes 로더가 되돌려요
        axis_up="Y",
        bake_space_transform=True,
        apply_scale_options="FBX_SCALE_ALL",
        mesh_smooth_type="OFF",
        add_leaf_bones=False,
        bake_anim=False,
    )
    data = {f.name: f.zones for f in furniture}
    with open(manifest_path, "w") as fh:
        json.dump(data, fh, indent=1, ensure_ascii=False)


def render(path, eye, target, width=1600, height=1000, lens=50, sun=1.6, world=0.45, floor="woodLight", samples=48, sun_rot=(50, 10, 35)):
    """미리보기 그림. eye/target은 로블록스 좌표."""
    scene = bpy.context.scene
    for name in ("PreviewCam", "PreviewSun", "PreviewFill", "PreviewFloor"):
        old = bpy.data.objects.get(name)
        if old:
            bpy.data.objects.remove(old)

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = lens
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    cam.location = P(*eye)
    cam.rotation_euler = (P(*target) - P(*eye)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    scene.camera = cam

    sun_data = bpy.data.lights.new("PreviewSun", "SUN")
    sun_data.energy = sun
    sun_data.angle = math.radians(25)
    sun = bpy.data.objects.new("PreviewSun", sun_data)
    sun.rotation_euler = tuple(math.radians(a) for a in sun_rot)
    scene.collection.objects.link(sun)

    floor_mesh = box((120, 0.2, 120), at=(0, -0.1, 0), r=0)
    floor_mesh.materials.append(_material(floor, "SmoothPlastic"))
    floor = bpy.data.objects.new("PreviewFloor", floor_mesh)
    scene.collection.objects.link(floor)

    world_data = bpy.data.worlds.new("PreviewWorld")
    world_data.use_nodes = True
    bg = world_data.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (1.0, 0.96, 0.9, 1)
    bg.inputs["Strength"].default_value = world
    scene.world = world_data

    scene.render.engine = "CYCLES"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)

    for ob in (cam, sun, floor):
        bpy.data.objects.remove(ob)
