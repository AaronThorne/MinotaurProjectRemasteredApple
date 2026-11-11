#!/usr/bin/env python3
"""Namespace each game's already generated translations into one iPad CPU library."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import json, subprocess, re, sys

root = Path(__file__).resolve().parents[1]
out = root / 'ios/build/cpu'
out.mkdir(parents=True, exist_ok=True)
sdk = subprocess.check_output(['xcrun','--sdk','iphoneos','--show-sdk-path'], text=True).strip()
division = out/'libgcc-division.inc'
subprocess.run([sys.executable, str(root/'tools/prepare-libgcc-division.py'),
                str(root/'ios/runtime/touchHLE_dylibs/libgcc_s.1.dylib'), str(division)], check=True)
games = [(entry['id'],root/'games'/entry['id']) for entry in json.loads((root/'games.json').read_text())]
patch=root/'ios/ports/Minotron2112/generated'
jobs=[]
declarations=[]
choices=[]
for slug, workspace in games:
    directory=out/slug
    directory.mkdir(exist_ok=True)
    overlays=[]
    if slug=='Minotron2112' and patch.exists():overlays.append(patch)
    repairs=root/'ios/ports'/slug/'cpu-fixes/generated'
    if repairs.exists():overlays.append(repairs)
    newkeys=[]
    for overlay in overlays:
        newkeys += [int(k) for k in re.findall(r'extern void b_(\d+)\(', (overlay/'dispatch.cpp').read_text())]
    replacement_keys=set(newkeys)
    def replaced(key):
        return key in replacement_keys or (slug=='Minotron2112' and patch.exists() and 0x5f4d4<=key&0xffffffff<0x5f544)
    for original in sorted((workspace/'generated').glob('*.cpp')):
        source=directory/original.name
        body=original.read_text()
        if overlays:
            if original.name=='dispatch.cpp':
                entries=[int(k) for k in re.findall(r'\{(\d+)ULL,b_\d+\}',body) if not replaced(int(k))]
                body=re.sub(r'extern void b_(\d+)\(State&\);',lambda m:'' if replaced(int(m[1])) else m[0],body)
                body=body.replace('struct Entry', '\n'.join(f'extern void b_{k}(State&);' for k in newkeys)+'\nstruct Entry',1)
                table='static Entry entries[]={\n'+'\n'.join(f'{{{k}ULL,b_{k}}},' for k in sorted(set(entries+newkeys)))+'\n};'
                body=re.sub(r'static Entry entries\[\]=\{.*?\n\};',lambda _:table,body,flags=re.S)
            else:
                # Replaced functions must not have duplicate definitions.
                for match in reversed(list(re.finditer(r'void b_(\d+)\(State&s\)\{',body))):
                    if not replaced(int(match[1])):continue
                    cursor=match.end();depth=1
                    while depth:
                        depth += (body[cursor]=='{')-(body[cursor]=='}');cursor+=1
                    body=body[:match.start()]+body[cursor:]
        content='#include "state.h"\nnamespace MPR_'+slug+' {\n'+body+'\n}\n'
        if not source.exists() or source.read_text()!=content: source.write_text(content)
        jobs.append(source)
    for number,overlay in enumerate(overlays):
        for original in sorted(overlay.glob('blocks-*.cpp')):
            source=directory/f'overlay-{number}-{original.name}'
            content='#include "state.h"\nnamespace MPR_'+slug+' {\n'+original.read_text()+'\n}\n'
            if not source.exists() or source.read_text()!=content:source.write_text(content)
            jobs.append(source)
    declarations.append(f'namespace MPR_{slug} {{ Block find_block(uint64_t); void report_lookup_stats(); }}')
    choices.append(f'if(game=="{slug}") {{ selected=MPR_{slug}::find_block; stats=MPR_{slug}::report_lookup_stats; return; }}')
selector=out/'selector.cpp'
selector.write_text('#include "state.h"\n#include <string_view>\n'+'\n'.join(declarations)+'''
static Block (*selected)(uint64_t)=nullptr;
static void (*stats)()=nullptr;
bool minotron_selected=false;
void select_game(){
 std::string_view game=std::getenv("MPR_GAME_ID")?std::getenv("MPR_GAME_ID"):"Gridrunner";
 minotron_selected=game=="Minotron2112";
'''+ '\n'.join(choices)+'''
 std::fprintf(stderr,"Unknown game CPU\n"); std::abort();
}
Block find_block(uint64_t key){return selected(key);}
void report_lookup_stats(){if(stats)stats();}
'''.replace('CPU\n','CPU\\n'))
wrapper=out/'wrapper.cpp'
wrapper_source = (root/'aot/wrapper.cpp').read_text()
wrapper_source = wrapper_source.replace(
    'struct Context', 'void select_game();\nextern bool minotron_selected;\n'
    '#include "minotron-controller.h"\nstruct Context', 1)
wrapper_source = wrapper_source.replace(
    'return new State;', 'select_game();return new State;', 1)
wrapper_source = wrapper_source.replace(
    '  uint64_t key=location(*s);',
    '  if (minotron_selected && step_minotron_controller(*s)) { remaining--; continue; }\n'
    '  uint64_t key=location(*s);', 1)
wrapper.write_text(wrapper_source)
jobs += [selector,wrapper]
def compile(source):
    obj=source.with_suffix('.o')
    dependencies = [source, root/'aot/state.h']
    if source == wrapper:
        dependencies.extend([root/'ios/minotron-controller.h', division])
    if obj.exists() and obj.stat().st_mtime > max(p.stat().st_mtime for p in dependencies):
        return obj
    result=subprocess.run(['clang++','-std=c++20','-O1','-ffp-contract=off','-target','arm64-apple-ios15.0','-isysroot',sdk,'-I'+str(root/'aot'),'-I'+str(root/'ios'),'-I'+str(out),'-DMPR_LIBGCC_DIVISION','-c',str(source),'-o',str(obj)],capture_output=True,text=True)
    if result.returncode: raise RuntimeError(str(source)+'\n'+result.stderr[:6000])
    return obj
print(f'Compiling {len(jobs)} translation units for nine games',flush=True)
with ThreadPoolExecutor(max_workers=12) as pool:
    objects=[]
    for i,obj in enumerate(pool.map(compile,jobs)):
        objects.append(obj)
        if i%50==0: print(f'{i+1}/{len(jobs)}',flush=True)
# Assemble afresh so removed overlays cannot survive as stale archive members.
archive=out/'libmpr_aot.next.a'
archive.unlink(missing_ok=True)
subprocess.run(['ar','rcs',str(archive),*[str(o) for o in objects]],check=True)
archive.replace(out/'libmpr_aot.a')
print('All nine CPU translations built',flush=True)
