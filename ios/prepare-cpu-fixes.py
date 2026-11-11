#!/usr/bin/env python3
"""Lift missing bounded ARM switch cases and cache hints for the iPad port.

Keep the player-tested Mac translations unchanged. Only supplemental/replacement
functions are emitted here; build-cpu.py merges these into the iPad dispatch table.
"""
from pathlib import Path
import json, os, struct, subprocess

root = Path(__file__).resolve().parents[1]

def switch_roots(binary, audit):
    segment = next(s for s in audit['segments'] if s['name'] == '__TEXT')
    base = segment['address'] - segment['file_offset']
    code = next(s for s in audit['sections'] if s['name'] == '__text')
    lower, upper = code['address'], code['address'] + code['size']
    tables, roots = [], set()
    for pc in range((lower + 3) & ~3, upper - 3, 4):
        word = struct.unpack_from('<I', binary, pc - base)[0]
        if word & 0xfffffff0 != 0x908ff100:  # ADDLS pc, pc, Rm, LSL #2
            continue
        reg, bound = word & 15, None
        for prior in range(pc - 4, max(lower - 1, pc - 128), -4):
            instruction = struct.unpack_from('<I', binary, prior - base)[0]
            if instruction & 0x0ff0f000 == 0x03500000 and (instruction >> 16) & 15 == reg:
                immediate, rotation = instruction & 255, ((instruction >> 8) & 15) * 2
                bound = (((immediate >> rotation) | (immediate << (32 - rotation))) & 0xffffffff) if rotation else immediate
                break
        if bound is None or bound > 1023:
            continue
        entries = []
        for n in range(bound + 1):
            address = pc + 8 + n * 4
            if not lower <= address < upper:
                break
            branch = struct.unpack_from('<I', binary, address - base)[0]
            if branch & 0xff000000 != 0xea000000:
                break
            displacement = branch & 0xffffff
            if displacement & 0x800000:
                displacement -= 0x1000000
            target = address + 8 + (displacement << 2)
            if not lower <= target < upper:
                break
            entries.extend([address, target])
        else:
            roots.update(entries)
            tables.append({'address': pc, 'bound': bound, 'roots': entries})
    return tables, roots

for slug in ['SuperOxWars', 'GoatUp']:
    source = root / 'games' / slug
    port = root / 'ios/ports' / slug / 'cpu-fixes'
    for name in ['work', 'reports']:
        (port / name).mkdir(parents=True, exist_ok=True)
    for name in ['aot', 'tools']:
        if not (port / name).exists():
            (port / name).symlink_to(root / name, target_is_directory=True)
    (port / 'game.json').write_text((source / 'game.json').read_text())
    audit = json.loads((source / 'reports/binary-audit.json').read_text())
    binary = (source / 'work/Gridrunner.bin').read_bytes()
    segment = next(s for s in audit['segments'] if s['name'] == '__TEXT')
    image = (source / 'work/text-image.bin').read_bytes()
    existing, hints = set(), set()
    for line in (source / 'work/gridrunner-ir.jsonl').open():
        block = json.loads(line)
        existing.add(block['location'])
        if any(o['op'] == 'ExceptionRaised' and o['args'][1].get('imm') in (9, 10, 11) for o in block['ops']):
            hints.add(block['location'])
    tables, roots = switch_roots(binary, audit)
    missing = roots - existing
    seeds = missing | hints
    with (port / 'work/repairs.trace').open('wb') as output:
        for key in sorted(seeds):
            offset = ((key & 0xffffffff) & ~3) - segment['address']
            output.write(struct.pack('<QII', key, *struct.unpack_from('<II', image, offset)))
    lifted = port / 'work/lifted.jsonl'
    subprocess.run(['python3', str(root / 'tools/build-ir-tool.py')], env=dict(os.environ, MPR_EXPERIMENT_ROOT=str(source)), check=True)
    with lifted.open('w') as output, (port / 'work/lift.log').open('w') as log:
        subprocess.run([str(source / 'work/dump-ir'), str(port / 'work/repairs.trace'), str(source / 'work/text-image.bin'), str(segment['address'])], stdout=output, stderr=log, check=True)
    count, emitted, continuations = 0, set(), set()
    with (port / 'work/gridrunner-ir.jsonl').open('w') as output:
        for line in lifted.open():
            block = json.loads(line)
            key = block['location']
            if key not in existing or key in hints:
                output.write(line)
                count += 1
                emitted.add(key)
                if any(o['op'] == 'ExceptionRaised' and o['args'][1].get('imm') in (9, 10, 11) for o in block['ops']):
                    continuations.add(block['end'] & ~(4 << 32))
    assert not continuations - (existing | emitted), 'Missing execution path after cache hint'
    (port / 'reports/repair-scope.json').write_text(json.dumps({'tables': tables, 'missing_roots': sorted(missing), 'cache_hints': sorted(hints), 'emitted_locations': count}, indent=2) + '\n')
    env = dict(os.environ, MPR_EXPERIMENT_ROOT=str(port))
    for stale in (port / 'generated').glob('blocks-*.cpp'):
        stale.unlink()
    subprocess.run(['python3', str(root / 'tools/generate-aot.py')], env=env, check=True)
    subprocess.run(['python3', str(root / 'tools/prepare-checks.py')], env=env, check=True)
    print(f'{slug}: {len(missing)} missing roots, {len(hints)} cache hints, {count} supplemental locations', flush=True)
