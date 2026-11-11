#!/usr/bin/env python3
"""Inspect an ARM32 Mach-O in an IPA without executing its code."""
import argparse, hashlib, json, plistlib, struct, zipfile
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('ipa',type=Path);args=parser.parse_args()
from experiment_config import workspace,game
root=workspace();work=root/'work';work.mkdir(exist_ok=True)
with zipfile.ZipFile(args.ipa) as z:
 name=next(n for n in z.namelist() if n.endswith('.app/Info.plist'))
 info=plistlib.loads(z.read(name));raw=z.read(name.rsplit('/',1)[0]+'/'+info['CFBundleExecutable'])
if raw[:4] == b'\xca\xfe\xba\xbe':
 arches=[struct.unpack_from('>5I',raw,8+20*i) for i in range(struct.unpack_from('>I',raw,4)[0])]
 cpu,subtype,offset,size,align=max((a for a in arches if a[0]==12),key=lambda a:a[1]==9)
 raw=raw[offset:offset+size]
if struct.unpack_from('<I',raw)[0] != 0xfeedface: raise SystemExit('Expected a thin 32-bit Mach-O')
_,cpu,subtype,filetype,ncmds,sizeofcmds,flags=struct.unpack_from('<7I',raw)
report={'bundle_id':info['CFBundleIdentifier'],'version':info.get('CFBundleShortVersionString'),'binary_size':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'cpu_type':cpu,'cpu_subtype':subtype,'segments':[],'sections':[],'imports':[],'function_starts':[]}
pos=28;symtab=None;image_base=0x1000
for _ in range(ncmds):
 cmd,size=struct.unpack_from('<II',raw,pos)
 if cmd==1:
  _,_,name,va,vs,off,fs,maxprot,initprot,ns,segflags=struct.unpack_from('<II16s8I',raw,pos)
  if name.rstrip(b'\0')==b'__TEXT':image_base=va
  report['segments'].append({'name':name.rstrip(b'\0').decode(),'address':va,'size':vs,'file_offset':off,'file_size':fs,'executable':bool(initprot&4)})
  for i in range(ns):
   sn,sg,addr,length,offset,align,ro,rn,fl,r1,r2=struct.unpack_from('<16s16s9I',raw,pos+56+i*68)
   report['sections'].append({'name':sn.rstrip(b'\0').decode(),'segment':sg.rstrip(b'\0').decode(),'address':addr,'size':length,'file_offset':offset,'flags':fl})
 if cmd==2: symtab=struct.unpack_from('<4I',raw,pos+8)
 if cmd==0x21: report['encryption']=dict(zip(['offset','size','cryptid'],struct.unpack_from('<3I',raw,pos+8)))
 if cmd==0x26:
  off,length=struct.unpack_from('<II',raw,pos+8);cur=off;addr=image_base
  while cur<off+length:
   value=0;shift=0
   while True:
    b=raw[cur];cur+=1;value|=(b&127)<<shift;shift+=7
    if not b&128:break
   if value==0:break
   addr+=value;report['function_starts'].append(addr)
 pos+=size
if symtab:
 off,count,stroff,strsize=symtab
 for i in range(count):
  ix,typ,sect,desc,value=struct.unpack_from('<IBBHI',raw,off+i*12)
  if (typ&0x0e)==0x0e and value and any(x['name']=='__text' and x['address']<=value<x['address']+x['size'] for x in report['sections']):
   report['function_starts'].append(value|(1 if desc&8 else 0))
  if ix and typ&0x0e==0:
   end=raw.find(b'\0',stroff+ix);report['imports'].append(raw[stroff+ix:end].decode())
report['function_starts']=sorted(set(report['function_starts']))
(work/'Gridrunner.bin').write_bytes(raw)
text=next(x for x in report['segments'] if x['name']=='__TEXT')
(work/'text-image.bin').write_bytes(raw[text['file_offset']:text['file_offset']+text['file_size']])
(root/'reports/binary-audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:report[k] for k in ['bundle_id','binary_size','cpu_subtype','encryption']},indent=2))
print('Function starts:',len(report['function_starts']),'Imports:',len(report['imports']))
