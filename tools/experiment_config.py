from pathlib import Path
import os,json,shutil,subprocess
COLLECTION=Path(__file__).resolve().parents[1]
def workspace():return Path(os.environ.get('MPR_EXPERIMENT_ROOT',str(COLLECTION)))
def game():
 path=workspace()/'game.json'
 return json.loads(path.read_text()) if path.exists() else {'id':'Gridrunner','title':'Gridrunner'}
def source_runtime(): return COLLECTION/'runtime'
def assets(): return COLLECTION/'local-assets'
def brew_prefix(package):
 return Path(subprocess.check_output(['brew','--prefix',package],text=True).strip())
def llvm_tool(name):
 candidate=brew_prefix('llvm')/'bin'/name
 return str(candidate) if candidate.exists() else shutil.which(name) or name
