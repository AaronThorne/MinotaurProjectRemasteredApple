"""Restore Minotron's original touch-control instructions in the iPad translations."""
from pathlib import Path
import struct,subprocess,os,json
root=Path(__file__).resolve().parents[1]
port=root/'ios/ports/Minotron2112'
for directory in ['work','reports']:(port/directory).mkdir(parents=True,exist_ok=True)
for name in ['aot','tools']:
    if not (port/name).exists():(port/name).symlink_to(root/name,target_is_directory=True)
(port/'game.json').write_text(json.dumps({'id':'Minotron2112','title':'Minotron 2112'}))
image=(root/'games/Minotron2112/work/text-image.bin').read_bytes()
start,end=0x5f4d4,0x5f544
data=image[start-0x1000:end-0x1000+4]
(port/'work/native-block.bin').write_bytes(data)
with (port/'work/native.trace').open('wb') as trace:
    for address in range(start,end,4):
        a,b=struct.unpack_from('<II',image,address-0x1000)
        trace.write(struct.pack('<QII',address,a,b))
with (port/'work/gridrunner-ir.jsonl').open('w') as output:
    subprocess.run([str(root/'games/Minotron2112/work/dump-ir'),str(port/'work/native.trace'),str(port/'work/native-block.bin'),str(start)],stdout=output,check=True)
ir=port/'work/gridrunner-ir.jsonl'
ir.write_text(''.join(line for line in ir.read_text().splitlines(keepends=True) if start<=json.loads(line)['location']&0xffffffff<end))
subprocess.run(['python3',str(root/'tools/generate-aot.py')],env=dict(os.environ,MPR_EXPERIMENT_ROOT=str(port)),check=True)
