#!/usr/bin/env python3
"""Recover function entries and bounded compiler-generated Thumb jump tables."""
from pathlib import Path
import json,struct,re,subprocess
from experiment_config import workspace,game,llvm_tool
root=workspace()
audit=json.loads((root/'reports/binary-audit.json').read_text());binary=(root/'work/Gridrunner.bin').read_bytes()
segment=next(s for s in audit['segments'] if s['name']=='__TEXT')
image_base=segment['address']-segment['file_offset']
code=next(s for s in audit['sections'] if s['name']=='__text')
seeds={(a&~1)|((a&1)<<32) for a in audit['function_starts']}
# Recover bounded ARM ADDLS-PC switch tables, without scanning arbitrary branch roots.
arm_tables=[]
for pc in range((code['address']+3)&~3,code['address']+code['size']-3,4):
 offset=pc-image_base;word=struct.unpack_from('<I',binary,offset)[0]
 if (word&0xfffffff0)!=0x908ff100:continue
 reg=word&15;bound=None
 for prior in range(pc-4,max(code['address']-1,pc-128),-4):
  instruction=struct.unpack_from('<I',binary,prior-image_base)[0]
  if (instruction&0x0ff0f000)==0x03500000 and (instruction>>16)&15==reg:
   immediate=instruction&255;rotation=((instruction>>8)&15)*2
   bound=((immediate>>rotation)|(immediate<<(32-rotation)))&0xffffffff if rotation else immediate
   break
 if bound is None or bound>1023:continue
 entries=[]
 for n in range(bound+1):
  address=pc+8+n*4
  if not code['address']<=address<code['address']+code['size']:break
  branch=struct.unpack_from('<I',binary,address-image_base)[0]
  if (branch&0xff000000)!=0xea000000:break
  displacement=branch&0xffffff
  if displacement&0x800000:displacement-=0x1000000
  target=(address+8+(displacement<<2))&0xffffffff
  if not code['address']<=target<code['address']+code['size']:break
  entries.extend([address,target])
 else:
  seeds.update(entries);arm_tables.append({'address':pc,'bound':bound,'roots':entries})
(root/'reports/arm-jump-tables.json').write_text(json.dumps(arm_tables,indent=2))
extra=root/'reports/additional-roots.json'
if extra.exists():seeds.update(json.loads(extra.read_text()))
text=subprocess.check_output([llvm_tool('llvm-objdump'),'--disassemble','--triple=thumbv7-apple-ios',str(root/'work/Gridrunner.bin')],stderr=subprocess.DEVNULL,text=True)
(root/'work/disassembly.txt').write_text(text)
lines=text.splitlines();tables=[];unresolved=[]
for index,line in enumerate(lines):
 m=re.search(r'^\s*([0-9a-f]+):.*\b(tbb|tbh)\s+\[pc, r(\d+)',line)
 if not m:continue
 pc=int(m[1],16);width=1 if m[2]=='tbb' else 2;reg=m[3];bound=None
 for prior in reversed(lines[max(0,index-32):index]):
  compare=re.search(r'\bcmp(?:\.w)?\s+r'+reg+r',\s*#(0x[0-9a-f]+|\d+)',prior)
  if compare:bound=int(compare[1],0);break
 if bound is None:
  candidates=[]
  for j,branch in enumerate(lines):
   if not re.search(r'\bbls(?:\.w)?\s+0x'+format(pc,'x')+r'\b',branch):continue
   for prior in reversed(lines[max(0,j-4):j]):
    compare=re.search(r'\bcmp(?:\.w)?\s+r'+reg+r',\s*#(0x[0-9a-f]+|\d+)',prior)
    if compare:candidates.append(int(compare[1],0));break
  if candidates and len(set(candidates))==1:bound=candidates[0]
 if bound is None or bound>1023:
  unresolved.append(hex(pc));continue
 base=pc+4;targets=[]
 for n in range(bound+1):
  offset=base-image_base+n*width
  if not 0<=offset<=len(binary)-width:raise RuntimeError('Table outside file')
  value=int.from_bytes(binary[offset:offset+width],'little');target=base+value*2
  if not code['address']<=target<code['address']+code['size']:continue
  seeds.add(target|(1<<32));targets.append(target)
 tables.append({'address':pc,'width':width,'bound':bound,'targets':targets})
with (root/'work/gridrunner-seeds.trace').open('wb') as out:
 for key in sorted(seeds):
  pc=key&0xffffffff;offset=(pc&~3)-image_base
  if 0<=offset and offset+8<=len(binary):out.write(struct.pack('<QII',key,*struct.unpack_from('<II',binary,offset)))
 out.write((root/'work/gridrunner.trace').read_bytes())
(root/'reports/jump-tables.json').write_text(json.dumps({'recovered':len(tables),'unresolved':unresolved,'tables':tables},indent=2)+'\n')
print('Function roots:',len(audit['function_starts']),'recovered jump tables:',len(tables),'unresolved:',unresolved,'total roots:',len(seeds))
