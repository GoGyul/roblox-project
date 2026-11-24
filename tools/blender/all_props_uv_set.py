# 공간 소품 + 사무실 키트를 UV를 넣어 한 파일로 다시 내보내요 (리뉴얼 3단계 마무리)
# 실행: /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender/all_props_uv_set.py
# 모양과 이름은 space_props_set · office_kit_set 과 같고, 메시에 UV가 들어가 로블록스 재질 무늬(나무·천·카펫·금속)가 보여요.
# 가져온 뒤에는 예전 두 세트의 .json / .ids.json 을 지우고 make_mesh_data.py 를 다시 돌려요.

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import lib  # noqa: E402
import drafts_spaces as d  # noqa: E402
import office_kit_set as kit  # noqa: E402
import space_props_set as props  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "salary")


def main():
    lib.reset()
    furniture = []
    for index, build in enumerate(props.BUILDERS + kit.BUILDERS):
        f = build()
        lift = 12 if f.name.startswith("Ceiling") else (5 if f.name == "NoticeBoard" else 0)
        d.put(f, -42 + (index % 8) * 12, -30 + (index // 8) * 13, y=lift)
        furniture.append(f)
    names = [f.name for f in furniture]
    assert len(set(names)) == len(names), names
    lib.export(os.path.join(OUT, "fbx", "all_props_uv_set.fbx"), furniture, os.path.join(OUT, "fbx", "all_props_uv_set.json"))
    print(f"DONE furniture={len(furniture)} zones={sum(len(f.zones) for f in furniture)} triangles={sum(z['triangles'] for f in furniture for z in f.zones)}")


if __name__ == "__main__":
    main()
