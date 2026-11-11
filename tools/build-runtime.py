#!/usr/bin/env python3
from pathlib import Path
import os,subprocess,shutil,fcntl,argparse
parser=argparse.ArgumentParser();parser.add_argument('--aot-dir');args=parser.parse_args()
from experiment_config import workspace,game
root=workspace()
env=dict(os.environ,MPR_AOT_DIR=str(Path(args.aot_dir).resolve() if args.aot_dir else root/'build/aot'))
with (Path(__file__).resolve().parents[1]/'work/runtime-build.lock').open('w') as lock:
 fcntl.flock(lock,fcntl.LOCK_EX)
 subprocess.run(['cargo','build','--release'],cwd=root/'runtime',env=env,check=True)
 temporary=root/'work/touchHLE-aot.new'
 shutil.copy2(root/'runtime/target/release/touchHLE',temporary)
 os.replace(temporary,root/'work/touchHLE-aot')
