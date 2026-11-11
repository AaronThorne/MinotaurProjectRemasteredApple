#!/usr/bin/env python3
"""Check the shareable source tree, not the ignored local game/build data."""
from pathlib import Path
import ast,json,re,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
IGNORED={'.git','.deps','runtime','games','work','build','local-assets','__pycache__'}
def files():
    if (ROOT/'.git').exists():
        names=subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode().split('\0')
        return [ROOT/n for n in names if n]
    return [p for p in ROOT.rglob('*') if p.is_file() and not any(part in IGNORED for part in p.relative_to(ROOT).parts) and not str(p.relative_to(ROOT)).startswith(('ios/runtime/','ios/vendor/','ios/Resources/','ios/ports/'))]
def main():
    errors=[];paths=files()
    blocked={'.ipa','.exe','.dylib','.a','.o','.air','.metallib','.mobileprovision','.p12','.p8','.key','.bin','.trace','.pyc'}
    for p in paths:
        rel=p.relative_to(ROOT)
        if 'build' in rel.parts[:-1]:errors.append(f'Build directory tracked: {rel}')
        if p.suffix.lower() in blocked:errors.append(f'Non-source file tracked: {rel}')
        if p.stat().st_size>2_000_000:errors.append(f'Unexpectedly large source file: {rel}')
        try:text=p.read_text()
        except UnicodeDecodeError:continue
        if '/'+ 'Users/' in text:errors.append(f'Personal checkout path: {rel}')
        if re.search(r'\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{16}\b',text):errors.append(f'Possible device UDID: {rel}')
        if '-----BEGIN '+ 'PRIVATE KEY-----' in text:errors.append(f'Private key material: {rel}')
        if p.suffix=='.py':
            try:ast.parse(text,filename=str(rel))
            except SyntaxError as exc:errors.append(str(exc))
        if p.suffix=='.md':
            for target in re.findall(r'\]\(([^)]+)\)',text):
                if target.startswith(('http:','https:','#')):continue
                target=target.split('#')[0]
                if target and not (p.parent/target).exists():errors.append(f'Broken local link in {rel}: {target}')
    games=json.loads((ROOT/'games.json').read_text())
    if len(games)!=9 or len({g['id'] for g in games})!=9:errors.append('Expected nine distinct game IDs')
    if not all(re.fullmatch('[0-9a-f]{64}',g['arm32_sha256']) for g in games):errors.append('Invalid game hash')
    if errors:
        print('\n'.join(errors));return 1
    print(f'Checked {len(paths)} source files: syntax, local links, manifests and source-only hygiene passed.')
    return 0
if __name__=='__main__':sys.exit(main())
