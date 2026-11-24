#!/usr/bin/env python3
"""Studio에서 저장한 .rbxl/.rbxm 안의 MeshPart 이름 → 메시 에셋 ID를 뽑아요.
사용: python3 tools/rbx_mesh_ids.py <저장한 파일> <출력 .ids.json> [모델 이름]
  모델 이름을 주면 그 모델 아래에 있는 메시만 뽑아요 (같은 이름의 메시가 다른 세트에도 있을 때 필요해요).
(zstd 명령이 필요해요)"""
import json
import struct
import subprocess
import sys


def unzstd(blob):
    return subprocess.run(["zstd", "-d", "-c"], input=blob, capture_output=True, check=True).stdout


def chunks(data):
    o = 32
    while o < len(data):
        name = data[o:o + 4]
        comp, raw, _ = struct.unpack("<III", data[o + 4:o + 16])
        body = data[o + 16:o + 16 + (comp or raw)]
        yield name, (unzstd(body) if comp else body)
        o += 16 + (comp or raw)


def string(b, o):
    n = struct.unpack("<I", b[o:o + 4])[0]
    return b[o + 4:o + 4 + n], o + 4 + n


def interleaved(b, n):
    return [int.from_bytes(bytes(b[k * n + i] for k in range(4)), "big") for i in range(n)]


def zigzag(v):
    return (v >> 1) ^ -(v & 1)


def referents(b, n):
    out, acc = [], 0
    for v in interleaved(b, n):
        acc += zigzag(v)
        out.append(acc)
    return out


def main(src, dst, root=None):
    data = open(src, "rb").read()
    classes = {}  # class id → (이름, [referent])
    names = {}  # referent → 이름
    class_of = {}
    mesh_ids = {}  # referent → 에셋 ID
    parent = {}
    for name, b in chunks(data):
        if name == b"INST":
            class_id = struct.unpack("<I", b[:4])[0]
            class_name, o = string(b, 4)
            count = struct.unpack("<I", b[o + 1:o + 5])[0]
            refs = referents(b[o + 5:o + 5 + 4 * count], count)
            classes[class_id] = (class_name.decode(), refs)
            for r in refs:
                class_of[r] = class_name.decode()
        elif name == b"PROP":
            class_id = struct.unpack("<I", b[:4])[0]
            class_name, refs = classes[class_id]
            prop, o = string(b, 4)
            kind = b[o]
            o += 1
            count = len(refs)
            if prop == b"Name" and kind == 0x01:
                for r in refs:
                    value, o = string(b, o)
                    names[r] = value.decode("utf8", "replace")
            elif class_name == "MeshPart" and prop == b"MeshContent" and kind == 0x22:
                sources = interleaved(b[o:o + 4 * count], count)
                o += 4 * count
                uri_count = struct.unpack("<I", b[o:o + 4])[0]
                o += 4
                uris = []
                for _ in range(uri_count):
                    value, o = string(b, o)
                    uris.append(value.decode())
                it = iter(uris)
                for r, s in zip(refs, sources):
                    if zigzag(s) == 1:  # 1 = URI
                        mesh_ids[r] = next(it)
            elif class_name == "MeshPart" and prop == b"MeshId" and kind == 0x01:
                for r in refs:
                    value, o = string(b, o)
                    if value and r not in mesh_ids:
                        mesh_ids[r] = value.decode()
        elif name == b"PRNT":
            count = struct.unpack("<I", b[1:5])[0]
            children = referents(b[5:5 + 4 * count], count)
            parents = referents(b[5 + 4 * count:5 + 8 * count], count)
            parent = dict(zip(children, parents))

    def under(r):
        if root is None:
            return True
        while r in parent and parent[r] != -1:
            r = parent[r]
            if names.get(r) == root:
                return True
        return False

    result, duplicates = {}, set()
    for r, cls in class_of.items():
        if cls == "MeshPart" and under(r):
            n = names.get(r, "?")
            if n in result:
                duplicates.add(n)
            result[n] = mesh_ids.get(r)
    result = dict(sorted(result.items()))
    missing = [n for n, i in result.items() if not i]
    json.dump(result, open(dst, "w"), indent=1)
    print(f"{len(result)} meshes, {len(missing)} without id {missing}" + (f", {len(duplicates)} duplicate names (모델 이름을 주세요)" if duplicates else ""))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
