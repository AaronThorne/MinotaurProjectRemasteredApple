#!/usr/bin/env python3
"""Stage clean resources; never seed an application with the builder's saves."""
from pathlib import Path
import argparse,json,plistlib,re,shutil,subprocess
from zipfile import ZipFile
ROOT=Path(__file__).resolve().parents[1]
GAMES=json.loads((ROOT/'games.json').read_text())

def prepare_picker_sprites(game_data, icons):
    """Use sprite sheets from the player's locally imported game archives."""
    icons.mkdir(parents=True, exist_ok=True)
    (icons / 'PickerSheep.png').unlink(missing_ok=True)
    for game, sheet, output in (
        ('Minotron2112', 'minotron.png', 'PickerCamels.png'),
        ('SuperOxWars', 'sf.png', 'PickerFighter.png'),
        ('Gridrunner', 'gridrunner.png', 'PickerInvader.png'),
        ('Deflex', 'deflex.png', 'PickerWhiteCamel.png'),
        ('GoatUp2', 'grunt.png', 'PickerGoat.png'),
    ):
        target = icons / output
        ipa = game_data / game / 'touchHLE_apps' / f'{game}.ipa'
        if not ipa.exists():
            target.unlink(missing_ok=True)
            continue
        with ZipFile(ipa) as archive:
            name = next(
                (item for item in archive.namelist()
                 if item.count('/') == 2 and item.startswith('Payload/') and item.endswith('/' + sheet)),
                None,
            )
            if name is not None:
                target.write_bytes(archive.read(name))
            else:
                target.unlink(missing_ok=True)

def prepare(platform):
    assets=ROOT/'local-assets';source=ROOT/'runtime'
    output=ROOT/'ios/Resources' if platform=='ios' else assets/'prepared'
    output.mkdir(parents=True,exist_ok=True)
    runtime=output/'Runtime';runtime.mkdir(exist_ok=True)
    for name in ['touchHLE_fonts','touchHLE_dylibs']:
        shutil.copytree(source/name,runtime/name,dirs_exist_ok=True)
    for name in ['touchHLE_default_options.txt','OPTIONS_HELP.txt','LICENSE']:shutil.copy2(source/name,runtime/name)
    shutil.copytree(assets/'Icons',output/'Icons',dirs_exist_ok=True)
    options=(source/'touchHLE_options.txt').read_text()
    for game in GAMES:
        ipa=assets/'ipas'/(game['id']+'.ipa')
        if not ipa.exists():continue
        data=output/'GameData'/game['id'];(data/'touchHLE_apps').mkdir(parents=True,exist_ok=True)
        shutil.copy2(ipa,data/'touchHLE_apps'/ipa.name)
        text=options.replace(' --fullscreen','').replace(' --mouse-to-swipe=1','')
        for name in ['gridrunner_bezel.png','fiveaday_bezel.png','superoxwars_bezel.png']:
            if (assets/name).exists():shutil.copy2(assets/name,data/name)
            else:text=re.sub(r'\s+--bezel='+re.escape(name)+r'(?=\s|$)','',text)
        text=re.sub(r'\s+--edge-bars-texture=\S+','',text)
        if platform=='ios':
            text=re.sub(r'(?<!\S)--(?:bezel|move-to-margin|margin-scale|ambient-bars|edge-bars|edge-bars-texture|starfield-bars|trim-edges|sharp-scaling|stick-to-icade|disable-analog-stick-tilt-controls|deflex-pad|minos-pad|goat-pad|goat2-pad|rescue-pad|minotron-pad|right-stick-tilt|left-stick-tilt)(?:=[^\s]+)?(?=\s|$)','',text)
        (data/'touchHLE_options.txt').write_text(text)
    prepare_picker_sprites(output/'GameData', output/'Icons')
    if platform=='ios':
        shutil.copy2(ROOT/'ios/controller-options.txt',runtime/'touchHLE_gamepad_options.txt')
        (output/'CompiledGames.plist').write_bytes(plistlib.dumps([g['id'] for g in GAMES]))
        subprocess.run(['swift',str(ROOT/'ios/prepare-app-icon.swift'),str(assets/'AppIcon.png')],check=True)
    return output
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('platform',choices=['macos','ios'])
    print(prepare(parser.parse_args().platform))
