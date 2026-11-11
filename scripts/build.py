#!/usr/bin/env python3
"""Build the Apple collection from pinned sources and locally imported games."""
from pathlib import Path
import argparse,json,os,shutil,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
GAMES=json.loads((ROOT/'games.json').read_text())
def run(args,env=None,cwd=ROOT,stdout=None):
    print('+',' '.join(str(a) for a in args),flush=True)
    subprocess.run([str(a) for a in args],cwd=cwd,env=env,stdout=stdout,check=True)
def workspace(game):
    path=ROOT/'games'/game['id']
    for name in ['work','build','reports','generated']:(path/name).mkdir(parents=True,exist_ok=True)
    for name in ['aot','tools','runtime']:
        link=path/name
        if not link.exists():link.symlink_to(ROOT/name,target_is_directory=True)
    (path/'game.json').write_text(json.dumps(game)+'\n')
    return path
def prepare_translations(games):
    reference=ROOT/'work/touchHLE-trace';reference.parent.mkdir(exist_ok=True)
    if not reference.exists():
        env=dict(os.environ);env.pop('MPR_AOT_DIR',None)
        run(['cargo','build','--release','--locked'],env=env,cwd=ROOT/'runtime')
        shutil.copy2(ROOT/'runtime/target/release/touchHLE',reference)
    for game in games:
        path=workspace(game);env=dict(os.environ,MPR_EXPERIMENT_ROOT=str(path))
        ipa=ROOT/'local-assets/ipas'/(game['id']+'.ipa')
        if not ipa.exists():raise SystemExit(f'Missing {ipa.name}; run scripts/import_assets.py first.')
        def tool(name,*args,stdout=None):run(['python3',ROOT/'tools'/name,*args],env=env,stdout=stdout)
        if (path/'generated/dispatch.cpp').exists():continue
        tool('audit-ipa.py',ipa)
        data=path/'work/trace-data';data.mkdir(exist_ok=True)
        shutil.copy2(ROOT/'runtime/touchHLE_options.txt',data/'touchHLE_options.txt')
        trace_env=dict(env,MPR_DATA_DIR=str(data),MPR_RESOURCE_DIR=str(ROOT/'runtime'),MPR_TRACE_FILE=str(path/'work/gridrunner.trace'))
        with (path/'work/record.log').open('w') as log:
            process=subprocess.Popen([str(reference),str(ipa),'--windowed','--plain-bars'],cwd=data,env=trace_env,stdout=log,stderr=subprocess.STDOUT)
            try:process.wait(timeout=25)
            except subprocess.TimeoutExpired:
                process.terminate()
                try:process.wait(timeout=5)
                except subprocess.TimeoutExpired:process.kill();process.wait()
        if not (path/'work/gridrunner.trace').exists():raise SystemExit('Reference trace missing; inspect '+str(path/'work/record.log'))
        recorded=(path/'work/record.log').read_text(errors='replace')
        if 'panicked at' in recorded or 'fatal runtime error' in recorded:
            raise SystemExit('Reference run failed; inspect '+str(path/'work/record.log'))
        tool('seed-functions.py');tool('build-ir-tool.py')
        audit=json.loads((path/'reports/binary-audit.json').read_text())
        segment=next(s for s in audit['segments'] if s['name']=='__TEXT')
        with (path/'work/gridrunner-ir.jsonl').open('w') as output:
            run([path/'work/dump-ir',path/'work/gridrunner-seeds.trace',path/'work/text-image.bin',segment['address']],stdout=output)
        tool('generate-aot.py')
def build_macos(games):
    prepare_translations(games)
    # Same generator already includes the generic cache-hint and ARM-table fixes.
    for game in games:
        path=workspace(game);env=dict(os.environ,MPR_EXPERIMENT_ROOT=str(path))
        run(['python3',ROOT/'tools/build-aot.py'],env=env)
        run(['python3',ROOT/'tools/build-runtime.py'],env=env)
    run(['python3',ROOT/'scripts/package_mac.py'])
def build_ios(args):
    if not args.no_sign and (not args.team or not args.bundle_id):
        raise SystemExit('Device builds require --team YOURTEAMID --bundle-id YOUR.UNIQUE.ID (or use --no-sign to compile only).')
    if not (ROOT/'ios/runtime/Cargo.toml').exists():raise SystemExit('Run scripts/bootstrap.py --ios first.')
    prepare_translations(GAMES)
    run(['python3',ROOT/'ios/prepare-minotron.py'])
    run(['python3',ROOT/'ios/prepare-cpu-fixes.py'])
    run(['python3',ROOT/'ios/build-cpu.py'])
    run(['python3',ROOT/'scripts/prepare_assets.py','ios'])
    env=dict(os.environ,MPR_AOT_DIR=str(ROOT/'ios/build/cpu'),CMAKE=str(ROOT/'ios/cmake-wrapper'),CMAKE_POLICY_VERSION_MINIMUM='3.5',RUSTC_BOOTSTRAP='1',IPHONEOS_DEPLOYMENT_TARGET='15.0')
    run(['cargo','build','--manifest-path',ROOT/'ios/runtime/Cargo.toml','--release','--lib','--target','aarch64-apple-ios','-Zbuild-std=std,panic_abort','--locked'],env=env)
    run(['xcodegen','generate','--spec',ROOT/'ios/project.yml'])
    command=['xcodebuild','-project',ROOT/'ios/MinotaurApple.xcodeproj','-scheme','MinotaurApple','-configuration','Release','-destination','generic/platform=iOS','-derivedDataPath',ROOT/'ios/build/Xcode']
    if args.no_sign:command+=['CODE_SIGNING_ALLOWED=NO']
    else:command+=['DEVELOPMENT_TEAM='+args.team,'PRODUCT_BUNDLE_IDENTIFIER='+args.bundle_id,'-allowProvisioningUpdates','-allowProvisioningDeviceRegistration']
    run(command+['build'])
    print('iOS app:',ROOT/'ios/build/Xcode/Build/Products/Release-iphoneos/MinotaurApple.app')
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('platform',choices=['macos','ios'])
    parser.add_argument('--game',choices=[g['id'] for g in GAMES],help='build one Mac game first; iOS currently requires all nine')
    parser.add_argument('--team');parser.add_argument('--bundle-id');parser.add_argument('--no-sign',action='store_true')
    args=parser.parse_args()
    if not (ROOT/'runtime/Cargo.toml').exists():raise SystemExit('Run scripts/bootstrap.py first.')
    if args.platform=='macos':build_macos([g for g in GAMES if not args.game or args.game==g['id']])
    else:
        if args.game:parser.error('--game is only supported for macos')
        build_ios(args)
if __name__=='__main__':main()
