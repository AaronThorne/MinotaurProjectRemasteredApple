#!/usr/bin/env python3
"""Translate the pinned guest libgcc's complete ARM32 integer division section."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys

TOOLS = Path(__file__).resolve().parent
LIBGCC_SHA256 = "d758fbf1ac952532955d62866bd02df55315c0599f64bdd978ff941fccbdcf83"
SLIDE = 0x30000000
# The pinned armv7 slice maps these __TEXT virtual offsets to file offsets.
# This range includes udivsi3, divsi3, umodsi3, modsi3 and their zero handler.
START, END = 0x11C4, 0x18B0


def prepare(dylib, output):
    dylib, output = dylib.resolve(), output.resolve()
    if hashlib.sha256(dylib.read_bytes()).hexdigest() != LIBGCC_SHA256:
        raise SystemExit("The guest libgcc does not match the pinned division code.")

    workspace = output.parent / "libgcc-division"
    work = workspace / "work"
    work.mkdir(parents=True, exist_ok=True)
    (workspace / "reports").mkdir(exist_ok=True)
    env = dict(os.environ, MPR_EXPERIMENT_ROOT=str(workspace))
    lifter = work / "dump-ir"
    lifter_sources = [TOOLS / "build-ir-tool.py", TOOLS / "dump-ir.cpp"]
    if not lifter.exists() or any(p.stat().st_mtime_ns > lifter.stat().st_mtime_ns for p in lifter_sources):
        subprocess.run([sys.executable, str(TOOLS / "build-ir-tool.py")], env=env, check=True)

    thin = work / "libgcc-armv7.dylib"
    subprocess.run(["xcrun", "lipo", str(dylib), "-thin", "armv7", "-output", str(thin)], check=True)
    image = thin.read_bytes()
    code = work / "division.bin"
    code.write_bytes(image[START:END])
    seeds = work / "division.trace"
    with seeds.open("wb") as stream:
        for address in range(START, END, 4):
            word, next_word = struct.unpack_from("<II", image, address)
            stream.write(struct.pack("<QII", SLIDE + address, word, next_word))

    lifted = work / "gridrunner-ir.jsonl"
    with lifted.open("w") as stream, (work / "lift.log").open("w") as log:
        subprocess.run([str(lifter), str(seeds), str(code), hex(SLIDE + START)],
                       stdout=stream, stderr=log, check=True)
    entries = set(range(SLIDE + START, SLIDE + END, 4))
    blocks = [json.loads(line) for line in lifted.read_text().splitlines()]
    blocks = [block for block in blocks if block["location"] in entries]
    if {block["location"] for block in blocks} != entries or len(blocks) != len(entries):
        raise SystemExit("The division translation did not cover each ARM instruction.")
    if any(op["op"] == "ExceptionRaised" for block in blocks for op in block["ops"]):
        raise SystemExit("The division translation encountered an unexpected instruction.")
    lifted.write_text("".join(json.dumps(block) + "\n" for block in blocks))

    subprocess.run([sys.executable, str(TOOLS / "generate-aot.py")], env=env, check=True)
    coverage = json.loads((workspace / "reports/aot-coverage.json").read_text())
    if coverage["unsupported_ir"]:
        raise SystemExit(f"Unsupported division instructions: {coverage['unsupported_ir']}")
    bodies = []
    for index in range((len(blocks) + 749) // 750):
        source = workspace / "generated" / f"blocks-{index:03}.cpp"
        bodies.append(source.read_text().removeprefix('#include "state.h"\n'))
    cases = "\n".join(f"    case 0x{entry:08x}u: return b_{entry};" for entry in sorted(entries))
    translated = (
        "// Generated from the pinned guest libgcc armv7 slice.\n"
        "namespace mpr_libgcc_division {\n" + "".join(bodies) +
        "Block find_block(uint64_t location) {\n"
        "    if (location & (3ull << 32)) return nullptr;\n"
        "    switch (static_cast<uint32_t>(location)) {\n" + cases +
        "\n    default: return nullptr;\n    }\n}\n}\n"
    )
    if not output.exists() or output.read_text() != translated:
        output.write_text(translated)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dylib", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    prepare(args.dylib, args.output)
