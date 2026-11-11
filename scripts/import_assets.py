#!/usr/bin/env python3
"""Import game assets locally, without executing Windows programs."""
from pathlib import Path
import argparse,hashlib,io,json,plistlib,shutil,struct,subprocess,tempfile,zipfile

ROOT=Path(__file__).resolve().parents[1]
GAMES=json.loads((ROOT/'games.json').read_text())
BY_ID={g['bundle_id']:g for g in GAMES}
OUT=ROOT/'local-assets'
def read_ipa(data):
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        name=next(n for n in archive.namelist() if n.startswith('Payload/') and n.count('/')==2 and n.endswith('/Info.plist'))
        info=plistlib.loads(archive.read(name));game=BY_ID.get(info['CFBundleIdentifier'])
        if not game:return None
        raw=archive.read(name.rsplit('/',1)[0]+'/'+info['CFBundleExecutable'])
        if raw[:4]==b'\xca\xfe\xba\xbe':
            count=struct.unpack_from('>I',raw,4)[0]
            arches=[struct.unpack_from('>5I',raw,8+20*i) for i in range(count)]
            arch=max((a for a in arches if a[0]==12),key=lambda a:a[1]==9)
            raw=raw[arch[2]:arch[2]+arch[3]]
        if hashlib.sha256(raw).hexdigest()!=game['arm32_sha256']:
            raise ValueError(f"{game['title']}: unsupported/encrypted binary version; see docs/ASSETS.md")
        icons=[]
        prefix=name.rsplit('/',1)[0]+'/'
        for entry in archive.namelist():
            if not entry.startswith(prefix) or not entry.lower().endswith('.png') or 'icon' not in Path(entry).name.lower():continue
            png=archive.read(entry)
            if png[:8]!=b'\x89PNG\r\n\x1a\n':continue
            ihdr=png.find(b'IHDR',8,80)
            if ihdr<0:continue
            w,h=struct.unpack_from('>II',png,ihdr+4)
            if w==h:icons.append((w,png))
        (OUT/'ipas').mkdir(parents=True,exist_ok=True)
        (OUT/'ipas'/(game['id']+'.ipa')).write_bytes(data)
        if icons:
            png=max(icons,key=lambda item:item[0])[1];target=OUT/'Icons'/(game['id']+'.png')
            target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(png)
            if b'CgBI' in png[:64]:
                converted=target.with_suffix('.standard.png')
                subprocess.run(['xcrun','pngcrush','-q','-revert-iphone-optimizations',str(target),str(converted)],check=True)
                converted.replace(target)
        print('Imported',game['title'])
        return game
def embedded_ipa(executable):
    position=0
    while (end:=executable.find(b'PK\x05\x06',position))>=0:
        position=end+4
        if end+22>len(executable):continue
        _,_,_,_,_,size,offset,comment=struct.unpack_from('<4s4H2IH',executable,end)
        start=end-size-offset
        if start<0 or executable[start:start+4]!=b'PK\x03\x04':continue
        data=executable[start:end+22+comment]
        try:
            game=read_ipa(data)
            if game:return game
        except (zipfile.BadZipFile,StopIteration,KeyError):continue
    return None
def embedded_pngs(data):
    position=0
    while (start:=data.find(b'\x89PNG\r\n\x1a\n',position))>=0:
        position=start+8;cursor=position
        if data[start+12:start+16]!=b'IHDR':continue
        try:
            w,h=struct.unpack_from('>II',data,start+16)
            while cursor+12<=len(data):
                size=struct.unpack_from('>I',data,cursor)[0];kind=data[cursor+4:cursor+8];cursor+=size+12
                if cursor>len(data):break
                if kind==b'IEND':yield w,h,data[start:cursor];break
        except struct.error:continue
def import_release(path):
    with tempfile.TemporaryDirectory(prefix='minotaur-assets-') as temp:
        folder=Path(temp)
        with zipfile.ZipFile(path) as archive:
            for item in archive.infolist():
                destination=(folder/item.filename).resolve()
                if not destination.is_relative_to(folder.resolve()):raise ValueError('Archive path leaves extraction directory')
            archive.extractall(folder)
        for exe in sorted(folder.rglob('*.exe')):
            data=exe.read_bytes();game=embedded_ipa(data)
            if not game:continue
            images=list(embedded_pngs(data))
            icons=[(w,png) for w,h,png in images if w==h and w in (72,128,256)]
            if icons:
                (OUT/'Icons').mkdir(exist_ok=True);(OUT/'Icons'/(game['id']+'.png')).write_bytes(icons[-1][1])
            art={'Gridrunner':'gridrunner_bezel.png','FiveADay':'fiveaday_bezel.png','SuperOxWars':'superoxwars_bezel.png'}
            if game['id'] in art and images:
                (OUT/art[game['id']]).write_bytes(max(images,key=lambda item:item[0]*item[1])[2])
        icon=next(folder.glob('**/Extras/Steam art/icon.png'),None)
        if icon:shutil.copy2(icon,OUT/'AppIcon.png')
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    source=parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--windows-zip',type=Path,help='full upstream v1.2 release, with games included')
    source.add_argument('--ipa-dir',type=Path,help='directory containing the supported decrypted original IPAs')
    parser.add_argument('--icon',type=Path,help='optional collection icon PNG')
    args=parser.parse_args();OUT.mkdir(exist_ok=True)
    if args.windows_zip:import_release(args.windows_zip)
    else:
        for path in sorted(args.ipa_dir.glob('*.ipa')):read_ipa(path.read_bytes())
    if args.icon:shutil.copy2(args.icon,OUT/'AppIcon.png')
    if not (OUT/'AppIcon.png').exists():
        subprocess.run(['swift',str(ROOT/'macos/default-icon.swift'),str(OUT/'AppIcon.png')],check=True)
    missing=[g['id'] for g in GAMES if not (OUT/'ipas'/(g['id']+'.ipa')).exists()]
    if missing:print('Not imported (can be built later):',', '.join(missing))
    print('Assets stay in ignored local-assets/. No original games are added to Git.')
if __name__=='__main__':main()
