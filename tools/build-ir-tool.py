from pathlib import Path
import subprocess
from experiment_config import workspace,game,source_runtime,brew_prefix
root=workspace()
base=source_runtime()
dyn=base/'vendor/dynarmic'
out=next((base/'target/release/build').glob('touchHLE_dynarmic_wrapper-*/out/lib/libdynarmic.a')).parent.parent
args=['clang++','-std=c++20','-O2', '-I'+str(dyn/'src'),'-I'+str(dyn/'externals/mcl/include'),'-I'+str(dyn/'externals/fmt/include'),'-I'+str(brew_prefix('boost')/'include'),str(Path(__file__).resolve().with_name('dump-ir.cpp')),str(out/'lib/libdynarmic.a'),str(out/'build/externals/fmt/libfmt.a'),str(out/'build/externals/mcl/src/libmcl.a'),'-o',str(root/'work/dump-ir')]
subprocess.run(args,check=True)
