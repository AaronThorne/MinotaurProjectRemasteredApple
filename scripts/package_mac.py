#!/usr/bin/env python3
"""Build a relocatable collection from compiled engines, with no prior app needed."""
from pathlib import Path
import json,plistlib,shutil,subprocess,sys
from prepare_assets import prepare
ROOT=Path(__file__).resolve().parents[1]
def package():
    app=ROOT/'build/MinotaurProjectRemastered for Apple.app'
    if app.exists():shutil.rmtree(app)
    contents=app/'Contents';resources=contents/'Resources';helpers=contents/'Helpers'
    for folder in [resources,helpers,contents/'MacOS']:folder.mkdir(parents=True,exist_ok=True)
    prepared=prepare('macos')
    shutil.copytree(prepared/'Runtime',resources/'Support/Runtime')
    shutil.copytree(prepared/'GameData',resources/'Support/GameData')
    shutil.copytree(prepared/'Icons',resources/'Icons')
    shutil.copy2(ROOT/'macos/Resources/GoatUpDefaultPreferences.plist',resources/'GoatUpDefaultPreferences.plist')
    subprocess.run(['python3',str(ROOT/'macos/package-picker.py'),str(app)],check=True)
    bootstrap=ROOT/'work/BundledGameBootstrap'
    subprocess.run(['clang','-arch','arm64','-mmacosx-version-min=13.0','-O2','-fobjc-arc',str(ROOT/'macos/BundledGameBootstrap.m'),str(ROOT/'macos/GoatControls.m'),'-framework','AppKit','-o',str(bootstrap)],check=True)
    count=0
    for game in json.loads((ROOT/'games.json').read_text()):
        engine=ROOT/'games'/game['id']/'work/touchHLE-aot'
        if not engine.exists():continue
        helper=helpers/(game['title']+'.app');mac=helper/'Contents/MacOS';mac.mkdir(parents=True)
        shutil.copy2(engine,mac/'GridrunnerAOT');shutil.copy2(bootstrap,mac/'MinotaurGame')
        info={'CFBundleName':game['title'],'CFBundleExecutable':'MinotaurGame','CFBundlePackageType':'APPL','CFBundleIdentifier':'local.minotaur.apple.bundled.'+game['id'].lower(),'MPRGameIdentifier':game['id'],'NSHighResolutionCapable':True}
        (helper/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
        for target in [mac/'GridrunnerAOT',helper]:subprocess.run(['codesign','--force','--sign','-',str(target)],check=True)
        count+=1
    if not count:raise SystemExit('No compiled engines found. Run scripts/build.py macos first.')
    info={'CFBundleName':'Minotaur Project','CFBundleDisplayName':'Minotaur Project','CFBundleIdentifier':'local.minotaur.apple.collection','CFBundleExecutable':'MinotaurRecompiled','CFBundlePackageType':'APPL','CFBundleShortVersionString':'1.4.12','CFBundleVersion':'17','CFBundleIconFile':'AppIcon.icns','NSHighResolutionCapable':True,'LSMinimumSystemVersion':'13.0'}
    (contents/'Info.plist').write_bytes(plistlib.dumps(info))
    shutil.copy2(ROOT/'CREDITS.md',resources/'Credits.txt')
    subprocess.run(['codesign','--force','--sign','-',str(app)],check=True)
    subprocess.run(['codesign','--verify','--deep','--strict',str(app)],check=True)
    print(f'Ready: {app} ({count} games). Saves remain in Application Support.')
    return app
if __name__=='__main__':package()
