#!/usr/bin/env python3
"""Apply the validated iPad CPU repairs to standalone Mac game libraries."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import argparse, re, subprocess, sys

games = ['SuperOxWars', 'GoatUp']
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--game', choices=games, help='build one of the repaired games')
args = parser.parse_args()

root=Path(__file__).resolve().parents[1]
division = root/'macos/build/cpu/libgcc-division.inc'
division.parent.mkdir(parents=True, exist_ok=True)
subprocess.run([sys.executable, str(root/'tools/prepare-libgcc-division.py'),
                str(root/'runtime/touchHLE_dylibs/libgcc_s.1.dylib'), str(division)], check=True)

for slug in ([args.game] if args.game else games):
    game=root/'games'/slug
    patch=root/'ios/ports'/slug/'cpu-fixes/generated'
    if not patch.exists():raise SystemExit('Run ios/prepare-cpu-fixes.py first.')
    out=root/'macos/build/cpu'/slug
    out.mkdir(parents=True,exist_ok=True)
    (game/'build/aot').mkdir(parents=True, exist_ok=True)
    keys={int(k) for k in re.findall(r'extern void b_(\d+)\(', (patch/'dispatch.cpp').read_text())}
    jobs=[]
    for original in sorted((game/'generated').glob('*.cpp')):
        body=original.read_text()
        if original.name=='dispatch.cpp':
            entries={int(k) for k in re.findall(r'\{(\d+)ULL,b_\d+\}',body)}|keys
            declarations='\n'.join(f'extern void b_{k}(State&);' for k in sorted(keys))
            body=re.sub(r'extern void b_(\d+)\(State&\);',lambda m:'' if int(m[1]) in keys else m[0],body)
            body=body.replace('struct Entry',declarations+'\nstruct Entry',1)
            table='static Entry entries[]={\n'+'\n'.join(f'{{{k}ULL,b_{k}}},' for k in sorted(entries))+'\n};'
            body=re.sub(r'static Entry entries\[\]=\{.*?\n\};',lambda _:table,body,flags=re.S)
        else:
            for match in reversed(list(re.finditer(r'void b_(\d+)\(State&s\)\{',body))):
                if int(match[1]) not in keys:continue
                cursor=match.end();depth=1
                while depth:
                    depth+=(body[cursor]=='{')-(body[cursor]=='}');cursor+=1
                body=body[:match.start()]+body[cursor:]
        if body!=original.read_text():
            source=out/original.name
            if not source.exists() or source.read_text()!=body:source.write_text(body)
            jobs.append((source,source.with_suffix('.o')))
        else:jobs.append((original,game/'build/aot'/original.with_suffix('.o').name))
    for original in sorted(patch.glob('blocks-*.cpp')):
        source=out/('repair-'+original.name)
        if not source.exists() or source.read_text()!=original.read_text():source.write_text(original.read_text())
        jobs.append((source,source.with_suffix('.o')))
    jobs.append((root/'aot/wrapper.cpp',out/'wrapper.o'))
    def compile(job):
        source,obj=job
        dependencies = [source, root/'aot/state.h']
        if source == root/'aot/wrapper.cpp':
            dependencies.append(division)
        if obj.exists() and obj.stat().st_mtime > max(p.stat().st_mtime for p in dependencies):
            return obj
        subprocess.run(['clang++','-std=c++20','-O1','-ffp-contract=off','-I'+str(root/'aot'),'-I'+str(division.parent),'-DMPR_LIBGCC_DIVISION','-c',str(source),'-o',str(obj)],check=True)
        return obj
    with ThreadPoolExecutor(max_workers=8) as pool:objects=list(pool.map(compile,jobs))
    archive=out/'libmpr_aot.next.a';archive.unlink(missing_ok=True)
    subprocess.run(['ar','rcs',str(archive),*[str(p) for p in objects]],check=True)
    archive.replace(out/'libmpr_aot.a')
    print(slug,'Mac CPU library built',flush=True)
