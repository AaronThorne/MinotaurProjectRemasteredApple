#!/usr/bin/env python3
"""Fetch pinned open-source dependencies and apply the Apple port patches."""
from pathlib import Path
import argparse,json,shutil,subprocess,sys

ROOT=Path(__file__).resolve().parents[1]
LOCK=json.loads((ROOT/'dependencies.json').read_text())
def run(*args,cwd=None):subprocess.run([str(a) for a in args],cwd=cwd,check=True)
def clone(url,revision,destination):
    if destination.exists():
        actual=subprocess.check_output(['git','-C',str(destination),'rev-parse','HEAD'],text=True).strip()
        if actual!=revision:raise SystemExit(f'{destination}: unexpected revision {actual}; no files changed.')
    else:
        destination.parent.mkdir(parents=True,exist_ok=True)
        run('git','clone','--filter=blob:none','--no-checkout',url,destination)
        run('git','-C',destination,'checkout','--detach',revision)
    run('git','-C',destination,'submodule','update','--init','--recursive','--depth','1','--jobs','4')
def apply(tree,patch):
    if subprocess.run(['git','-C',str(tree),'apply','--reverse','--check',str(patch)],capture_output=True).returncode==0:return
    run('git','-C',tree,'apply','--check',patch)
    run('git','-C',tree,'apply',patch)
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ios',action='store_true',help='also prepare the iPhone/iPad runtime and patched SDL crate')
    args=parser.parse_args()
    runtime=LOCK['runtime']
    clone(runtime['url'],runtime['commit'],ROOT/'runtime')
    apply(ROOT/'runtime',ROOT/'patches/runtime-macos.patch')
    if args.ios:
        clone(runtime['url'],runtime['commit'],ROOT/'ios/runtime')
        sdl=LOCK['rust_sdl2'];checkout=ROOT/'.deps/rust-sdl2'
        clone(sdl['url'],sdl['commit'],checkout)
        vendor=ROOT/'ios/vendor/sdl2-sys'
        if not vendor.exists():
            vendor.parent.mkdir(parents=True,exist_ok=True)
            shutil.copytree(checkout/'sdl2-sys',vendor,symlinks=False,ignore=shutil.ignore_patterns('.git'))
            run('git','init','--quiet',vendor)
        apply(vendor,ROOT/'patches/sdl2-uikit-scene.patch')
        apply(ROOT/'ios/runtime',ROOT/'patches/runtime-ios.patch')
    print('Pinned dependencies ready. Next: import game assets; see docs/BUILDING.md.')
if __name__=='__main__':main()
