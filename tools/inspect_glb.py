#!/usr/bin/env python3
"""Inspect a .glb / .gltf without any engine, and report what the game cares about.

    python3 tools/inspect_glb.py models/truck.glb

Prints the node tree, mesh and texture counts, triangle count, the bounding box
and whether the wheel nodes the loader looks for (`wheel_fl` ...) are present.
Exits non-zero if the file is not a valid glTF 2.0 binary.
"""

from __future__ import annotations

import json
import re
import struct
import sys
from pathlib import Path

GLB_MAGIC = b"glTF"
WHEEL_PATTERN = re.compile(r"(wheel|tyre|tire)[_\- ]?(fl|fr|rl|rr|front|rear|left|right)", re.I)


def fail(message: str) -> "None":
    print(f"  !! {message}")
    sys.exit(1)


def read_glb(path: Path) -> tuple[dict, bytes]:
    data = path.read_bytes()

    if len(data) < 20:
        fail("file is too small to be a GLB")

    magic, version, length = struct.unpack_from("<4sII", data, 0)

    if magic != GLB_MAGIC:
        fail(f"not a GLB (magic is {magic!r}, expected b'glTF')")
    if version != 2:
        fail(f"glTF version {version}, this project needs 2")

    if length > len(data):
        fail(f"header claims {length} bytes but the file is {len(data)}")

    offset = 12
    gltf: dict | None = None
    binary = b""

    while offset < length:
        chunk_length, chunk_type = struct.unpack_from("<I4s", data, offset)
        body = data[offset + 8 : offset + 8 + chunk_length]

        if chunk_type == b"JSON":
            gltf = json.loads(body.decode("utf-8").rstrip("\x00 "))
        elif chunk_type == b"BIN\x00":
            binary = body

        offset += 8 + chunk_length + ((4 - chunk_length % 4) % 4)

    if gltf is None:
        fail("no JSON chunk found")

    return gltf, binary


def read_json_gltf(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def accessor_bounds(gltf: dict, index: int) -> tuple[list[float], list[float]] | None:
    accessor = gltf.get("accessors", [])[index]
    low = accessor.get("min")
    high = accessor.get("max")

    if low and high and len(low) >= 3:
        return list(low[:3]), list(high[:3])

    return None


def mesh_bounds(gltf: dict) -> tuple[list[float], list[float]]:
    low = [float("inf")] * 3
    high = [float("-inf")] * 3
    found = False

    for mesh in gltf.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            position = primitive.get("attributes", {}).get("POSITION")

            if position is None:
                continue

            bounds = accessor_bounds(gltf, position)

            if bounds is None:
                continue

            found = True

            for axis in range(3):
                low[axis] = min(low[axis], bounds[0][axis])
                high[axis] = max(high[axis], bounds[1][axis])

    if not found:
        return [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]

    return low, high


def count_triangles(gltf: dict) -> int:
    total = 0

    for mesh in gltf.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            mode = primitive.get("mode", 4)

            if mode != 4:
                continue

            indices = primitive.get("indices")
            attributes = primitive.get("attributes", {})

            if indices is not None:
                total += gltf["accessors"][indices]["count"] // 3
            elif "POSITION" in attributes:
                total += gltf["accessors"][attributes["POSITION"]]["count"] // 3

    return total


def node_tree(gltf: dict, index: int, depth: int = 0) -> None:
    node = gltf["nodes"][index]
    name = node.get("name", f"node{index}")
    marker = "  *" if WHEEL_PATTERN.search(name) else ""
    print(f"    {'  ' * depth}- {name}{marker}")

    for child in node.get("children", []):
        node_tree(gltf, child, depth + 1)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__)
        return 2

    path = Path(argv[1])

    if not path.exists():
        fail(f"{path} does not exist")

    size_mb = path.stat().st_size / (1024 * 1024)
    print(f"file    : {path}  ({size_mb:.2f} MB)")

    if path.suffix.lower() in (".gltf",):
        gltf = read_json_gltf(path)
    else:
        gltf, _ = read_glb(path)

    generator = gltf.get("asset", {}).get("generator", "unknown")
    print(f"generator: {generator}")

    nodes = gltf.get("nodes", [])
    meshes = gltf.get("meshes", [])
    materials = gltf.get("materials", [])
    textures = gltf.get("textures", [])
    triangles = count_triangles(gltf)
    low, high = mesh_bounds(gltf)

    size = [high[axis] - low[axis] for axis in range(3)]

    print(f"nodes   : {len(nodes)}   meshes: {len(meshes)}   materials: {len(materials)}   textures: {len(textures)}")
    print(f"triangles: {triangles:,}")
    print(f"bounds  : x {low[0]:.2f}..{high[0]:.2f}   y {low[1]:.2f}..{high[1]:.2f}   z {low[2]:.2f}..{high[2]:.2f}")
    print(f"size    : {size[0]:.2f} m wide   {size[1]:.2f} m tall   {size[2]:.2f} m long")

    print("verdict :")

    if 2.0 <= size[0] <= 3.2:
        print("  ok   width looks like a truck")
    else:
        print(f"  !!   width {size[0]:.2f} m is off — the reference truck is 2.4 m")

    if 2.2 <= size[1] <= 4.2:
        print("  ok   height looks like a truck")
    else:
        print(f"  !!   height {size[1]:.2f} m is off — the reference truck is 2.6 m")

    if 5.5 <= size[2] <= 18.0:
        print("  ok   length looks like a tractor unit")
    else:
        print(f"  !!   length {size[2]:.2f} m is off — the reference truck is 8.0 m")

    if abs(low[1]) <= 0.35:
        print("  ok   origin sits on the ground")
    else:
        print(f"  !!   origin is {low[1]:.2f} m off the ground — the truck would float or sink")

    wheel_nodes = [node.get("name", "") for node in nodes if WHEEL_PATTERN.search(node.get("name", ""))]
    print(f"  {'ok  ' if len(wheel_nodes) >= 4 else '??  '} wheel nodes found: {len(wheel_nodes)}"
          + (f" ({', '.join(wheel_nodes[:8])})" if wheel_nodes else " — wheels stay procedural"))

    if triangles > 400_000:
        print(f"  !!   {triangles:,} triangles is heavy for a night scene with shadows")

    print("nodes   :")
    scenes = gltf.get("scenes", [])

    if scenes:
        for root in scenes[0].get("nodes", []):
            node_tree(gltf, root)
    else:
        for index in range(min(len(nodes), 12)):
            node_tree(gltf, index)

    print("  (* marks anything that looks like a wheel)")

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
