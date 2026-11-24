#!/usr/bin/env python3
"""assets/salary/fbx 의 치수(.json)와 에셋 ID(.ids.json)를 합쳐 shared/SalaryMeshData.luau 를 만들어요.
사용: python3 tools/make_mesh_data.py"""
import glob
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FBX = os.path.join(ROOT, "assets", "salary", "fbx")
# Studio로 가져오면 메시가 Y축으로 180° 돌아가 있어요 (내보내기 축 설정과 상관없이 그랬어요) → 로더가 되돌려요


def vec(v):
    return f"Vector3.new({v[0]:g}, {v[1]:g}, {v[2]:g})"


lines = ["-- 자동 생성 파일이에요: python3 tools/make_mesh_data.py (직접 고치지 마세요)", "-- 가구 → 색 구역별 메시 (크기·중심은 가구 원점(바닥 가운데) 기준, 스터드)", "", "return {"]
for path in sorted(glob.glob(os.path.join(FBX, "*.json"))):
    if path.endswith(".ids.json"):
        continue
    set_name = os.path.basename(path)[:-5]
    ids_path = path[:-5] + ".ids.json"
    if not os.path.exists(ids_path):
        print(f"skip {set_name}: no ids yet")
        continue
    ids = json.load(open(ids_path))
    for furniture, zones in json.load(open(path)).items():
        lines.append(f"\t{furniture} = {{")
        lines.append(f"\t\tflip = true,")
        lines.append("\t\tparts = {")
        for zone in zones:
            short = zone["name"].split("_", 1)[1]
            lines.append(
                f"\t\t\t{short} = {{ id = \"{ids[zone['name']]}\", size = {vec(zone['size'])}, center = {vec(zone['center'])}, "
                f"color = \"{zone['color']}\", material = \"{zone['material']}\" }},"
            )
        lines += ["\t\t},", "\t},"]
lines += ["}", ""]
# 메시가 쓰는 색 이름이 테마에 다 있는지 확인 (없으면 게임에서 회색으로 보여요)
import re
theme = open(os.path.join(ROOT, "shared", "SalaryTheme.luau")).read()
missing = set(re.findall(r'color = "(\w+)"', "\n".join(lines))) - set(re.findall(r"^\t(\w+) = Color3", theme, re.M))
if missing:
    print("⚠️ shared/SalaryTheme.luau 에 없는 색:", sorted(missing))
open(os.path.join(ROOT, "shared", "SalaryMeshData.luau"), "w").write("\n".join(lines))
print("wrote shared/SalaryMeshData.luau")
