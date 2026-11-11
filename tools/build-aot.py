#!/usr/bin/env python3
"""Compile generated translations for macOS, or compile-only for iPhone/iPad."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import argparse, subprocess, sys
parser=argparse.ArgumentParser();parser.add_argument('--ios',action='store_true');args=parser.parse_args()
from experiment_config import workspace,game
root=workspace();build=root/('build/aot-ios' if args.ios else 'build/aot');build.mkdir(parents=True,exist_ok=True)
flags=[]
if args.ios:
 sdk=subprocess.check_output(['xcrun','--sdk','iphoneos','--show-sdk-path'],text=True).strip()
 flags=['-target','arm64-apple-ios15.0','-isysroot',sdk]
subprocess.run([
    sys.executable, str(Path(__file__).resolve().with_name('prepare-libgcc-division.py')),
    str(root/'runtime/touchHLE_dylibs/libgcc_s.1.dylib'), str(build/'libgcc-division.inc')
], check=True)
flags += ['-DMPR_LIBGCC_DIVISION', '-I'+str(build)]
sources=sorted((root/'generated').glob('*.cpp'))+[root/'aot/wrapper.cpp']
def compile(p):
 obj=build/(p.stem+'.o')
 result=subprocess.run(['clang++','-std=c++20','-O1','-ffp-contract=off',*flags,'-I'+str(root/'aot'),'-c',str(p),'-o',str(obj)],capture_output=True,text=True)
 if result.returncode:raise RuntimeError(str(p)+'\n'+result.stderr[:6000])
 return obj
with ThreadPoolExecutor(max_workers=4) as pool:objects=list(pool.map(compile,sources))
(build/'libmpr_aot.a').unlink(missing_ok=True)
subprocess.run(['ar','rcs',str(build/'libmpr_aot.a'),*[str(p) for p in objects]],check=True)
print('Built',len(objects),'objects:',build/'libmpr_aot.a')
