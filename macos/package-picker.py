#!/usr/bin/env python3
"""Compile and embed the Mac picker, shared Metal backdrop and sheep icon."""
from pathlib import Path
import subprocess,sys
root=Path(__file__).resolve().parents[1]
app=Path(sys.argv[1]);resources=app/'Contents/Resources';resources.mkdir(parents=True,exist_ok=True)
(app/'Contents/MacOS').mkdir(parents=True,exist_ok=True)
subprocess.run(['swiftc','-O','-parse-as-library','-target','arm64-apple-macos13.0',*[str(root/'macos'/name) for name in ['CollectionLauncher.swift','PickerInfo.swift','PixelArt.swift','TrippyBackground.swift']],'-framework','AppKit','-framework','MetalKit','-framework','Metal','-o',str(app/'Contents/MacOS/MinotaurRecompiled')],check=True)
air=root/'macos/build/Background.air';air.parent.mkdir(parents=True,exist_ok=True)
subprocess.run(['xcrun','--sdk','macosx','metal','-c',str(root/'ios/App/TrippyBackground.metal'),'-o',str(air)],check=True)
subprocess.run(['xcrun','--sdk','macosx','metallib',str(air),'-o',str(resources/'Background.metallib')],check=True)
icons=root/'work/AppIcon.iconset'
icons.mkdir(parents=True,exist_ok=True)
for size in [16,32,128,256,512]:
    for scale in [1,2]:
        name=f'icon_{size}x{size}'+('@2x' if scale==2 else '')+'.png'
        subprocess.run(['sips','-z',str(size*scale),str(size*scale),str(root/'local-assets/AppIcon.png'),'--out',str(icons/name)],stdout=subprocess.DEVNULL,check=True)
subprocess.run(['iconutil','-c','icns',str(icons),'-o',str(resources/'AppIcon.icns')],check=True)
