from pathlib import Path
import subprocess,argparse
parser=argparse.ArgumentParser();parser.add_argument('--aot-dir');args=parser.parse_args()
from experiment_config import workspace,game,source_runtime,brew_prefix
root=workspace()
base=source_runtime()
dyn=base/'vendor/dynarmic'
out=next((base/'target/release/build').glob('touchHLE_dynarmic_wrapper-*/out/lib/libdynarmic.a')).parent.parent
library=Path(args.aot_dir).resolve()/'libmpr_aot.a' if args.aot_dir else root/'build/aot/libmpr_aot.a'
args=['clang++','-std=c++20','-O2', '-I'+str(dyn/'src'),'-I'+str(dyn/'externals/mcl/include'),'-I'+str(dyn/'externals/fmt/include'),'-I'+str(brew_prefix('boost')/'include'),'-I'+str(root/'aot'),str(root/'tools/check-aot.cpp'),str(library),str(out/'lib/libdynarmic.a'),str(out/'build/externals/fmt/libfmt.a'),str(out/'build/externals/mcl/src/libmcl.a'),'-o',str(root/'work/check-aot')]
subprocess.run(args,check=True)
