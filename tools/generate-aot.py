#!/usr/bin/env python3
"""Emit native C++ functions from captured ARM IR. No runtime instruction decoder."""
from pathlib import Path
import json, collections
from experiment_config import workspace,game
root=workspace()
out=root/'generated';out.mkdir(exist_ok=True)
for stale in out.glob('blocks-*.cpp'): stale.unlink()
blocks=sorted([json.loads(l) for l in (root/'work/gridrunner-ir.jsonl').open()],key=lambda b:b['location'])
unsupported=collections.Counter()
def term(t):
 k=t['type']
 if k=='Link':return f'link(s,{t["next"]}ULL);'
 if k=='Dispatch':return ''
 if k=='CheckHalt':return f'if(s.status==-1){{{term(t["no"])}}}'
 if k in ['If','CheckBit']:
  c=f'cond(s,{t["cond"]})' if k=='If' else 's.check'
  return f'if({c}){{{term(t["yes"])}}}else{{{term(t["no"])}}}'
 return 's.status=-3;'
def emit_op(o,i,b):
 op=o['op'];args=o['args'];a=[f'v{x["ref"]}' if 'ref' in x else str(x['imm'])+'ULL' for x in args];v=f'v{i}';x=a+['0']*4
 A,B,C,D=x[:4]
 binary={'And32':'&','And64':'&','Or32':'|','Or64':'|','Eor32':'^','Eor64':'^','VectorOr':'|','Mul32':'*','Mul64':'*'}
 expr=None;code=''
 if op=='GetRegister':expr=f's.r[{A}]'
 elif op=='SetRegister':code=f's.r[{A}]=uint32_t({B});'
 elif op=='GetExtendedRegister32':expr=f's.ext[{A}]'
 elif op=='SetExtendedRegister32':code=f's.ext[{A}]=uint32_t({B});'
 elif op=='GetExtendedRegister64':expr=f'getdouble(s,{A})'
 elif op=='SetExtendedRegister64':code=f'setdouble(s,{A},{B});'
 elif op=='GetVector':expr=f'getvec(s,{A})'
 elif op=='SetVector':code=f'setvec(s,{A},{B});'
 elif op=='GetCpsr':expr='s.cpsr'
 elif op=='SetCpsr':code=f's.cpsr={A};'
 elif op=='GetCFlag':expr='(s.cpsr>>29)&1'
 elif op in ['SetCpsrNZCV','SetCpsrNZCVRaw']:code=f's.cpsr=(s.cpsr&0x0fffffff)|({A}&0xf0000000);'
 elif op=='SetCpsrNZ':code=f's.cpsr=(s.cpsr&0x3fffffff)|({A}&0xc0000000);'
 elif op=='SetCpsrNZC':code=f's.cpsr=(s.cpsr&0x1fffffff)|({A}&0xc0000000)|(uint32_t({B})<<29);'
 elif op=='GetFpscrNZCV':expr='s.fpscr&0xf0000000'
 elif op=='SetFpscrNZCV':code=f's.fpscr=(s.fpscr&0x0fffffff)|({A}&0xf0000000);'
 elif op=='SetCheckBit':code=f's.check={A};'
 elif op in ['Add32','Sub32','LogicalShiftLeft32','LogicalShiftRight32','ArithmeticShiftRight32','RotateRight32']:
  f={'Add32':'add32','Sub32':'sub32','LogicalShiftLeft32':'shl32','LogicalShiftRight32':'shr32','ArithmeticShiftRight32':'asr32','RotateRight32':'ror32'}[op]
  code=f'auto res{i}={f}({A},{B},{C}); uint32_t {v}=res{i}.v;'
 elif op in binary:expr=f'{A}{binary[op]}{B}'
 elif op=='Add64':expr=f'uint64_t({A}+{B}+{C})'
 elif op=='Sub64':expr=f'uint64_t({A}-{B}-(1-{C}))'
 elif op=='VectorExtractLower':expr=f'uint64_t((U128(uint64_t({A}))|(U128(uint64_t({B}))<<64))>>{C})'
 elif op=='VectorZeroExtend8':code=f'U128 {v}=0;for(int lane=0;lane<8;lane++){v}|=U128(uint8_t({A}>>(lane*8)))<<(lane*16);'
 elif op=='VectorAdd16':code=f'U128 {v}=0;for(int lane=0;lane<8;lane++){v}|=U128(uint16_t(uint16_t({A}>>(lane*16))+uint16_t({B}>>(lane*16))))<<(lane*16);'
 elif op=='ExceptionRaised':
  # PLD/PLDW/PLI are optional cache hints, not guest faults. The IR has
  # already advanced PC; no registers or memory need to change.
  code='' if args[1].get('imm') in (9,10,11) else f's.status=({B}==8?-4:-3);'
 elif op=='PackedSaturatedAddS16':
  code=f'uint32_t {v}=0;Result res{i}{{0}};for(int lane=0;lane<2;lane++){{int sum=int16_t({A}>>(lane*16))+int16_t({B}>>(lane*16));int clamped=std::clamp(sum,-32768,32767);res{i}.o|=sum!=clamped;{v}|=uint32_t(uint16_t(clamped))<<(lane*16);}}res{i}.v={v};'
 elif op=='AndNot32':expr=f'{A}&~{B}'
 elif op=='Not32':expr=f'~{A}'
 elif op in ['LogicalShiftLeft64','LogicalShiftRight64']:
  expr=f'({B}<64?({A}{"<<" if "Left" in op else ">>"}{B}):0)'
 elif op=='RotateRightExtended':code=f'uint32_t {v}=(uint32_t({B})<<31)|(uint32_t({A})>>1);Result res{i}{{{v},bool({A}&1)}};'
 elif op=='GetCarryFromOp':expr=f'res{args[0]["ref"]}.c'
 elif op=='GetOverflowFromOp':expr=f'res{args[0]["ref"]}.o'
 elif op=='GetNZCVFromOp':expr=f'nz({A})|(uint32_t(res{args[0]["ref"]}.c)<<29)|(uint32_t(res{args[0]["ref"]}.o)<<28)'
 elif op=='GetNZFromOp':expr=f'nz({A})'
 elif op=='IsZero32':expr=f'uint32_t({A})==0'
 elif op=='Pack2x32To1x64':expr=f'uint64_t({A})|(uint64_t({B})<<32)'
 elif op=='MostSignificantWord':code=f'uint32_t {v}={A}>>32;Result res{i}{{{v},bool(({A}>>31)&1)}};'
 elif op in ['LeastSignificantWord','LeastSignificantHalf','LeastSignificantByte']:expr=f'{A}&'+{'LeastSignificantWord':'0xffffffffULL','LeastSignificantHalf':'65535','LeastSignificantByte':'255'}[op]
 elif op.startswith('ZeroExtend'):expr=A
 elif op=='SignExtendByteToWord':expr=f'uint32_t(int32_t(int8_t({A})))'
 elif op=='SignExtendHalfToWord':expr=f'uint32_t(int32_t(int16_t({A})))'
 elif op=='SignExtendWordToLong':expr=f'uint64_t(int64_t(int32_t({A})))'
 elif op=='ByteReverseHalf':expr=f'(({A}&0x00ff00ffu)<<8)|(({A}>>8)&0x00ff00ffu)'
 elif op=='ByteReverseWord':expr=f'__builtin_bswap32(uint32_t({A}))'
 elif op=='CountLeadingZeros32':expr=f'({A}?__builtin_clz(uint32_t({A})):32)'
 elif op.startswith('ReadMemory') or op.startswith('ExclusiveReadMemory'):
  n=op.split('Memory')[1];expr=f'read{n}(s,{B})'
 elif op.startswith('WriteMemory') or op.startswith('ExclusiveWriteMemory'):
  n=op.split('Memory')[1];code=f'write{n}(s,{B},{C});'
  if op.startswith('Exclusive'):code+=f'uint32_t {v}=0;'
 elif op=='BXWritePC':code=f'bx(s,{A});'
 elif op=='UpdateUpperLocationDescriptor':
  if not any(i['op']=='BXWritePC' for i in b['ops']):code=f'{{auto pc=s.r[15];link(s,{b["end"]}ULL);s.r[15]=pc;}}'
 elif op=='CallSupervisor':
  pc=b['location']&0xffffffff;thumb=(b['location']>>32)&1
  code=f's.status=read{16 if thumb else 32}(s,{pc}u)&{255 if thumb else 16777215}u;'
 elif op in ['DataMemoryBarrier','DataSynchronizationBarrier','PushRSB','Void']:pass
 elif op=='VectorBroadcast64':expr=f'U128({A})|(U128({A})<<64)'
 elif op in ['FPCompare32','FPCompare64']:
  f='f32' if op.endswith('32') else 'f64';expr=f'fcompare({f}({A}),{f}({B}))'
 elif op in ['FPSingleToDouble','FPDoubleToSingle']:
  expr=f'bits64(f32({A}))' if op=='FPSingleToDouble' else f'bits32(float(f64({A})))'
 elif op in ['FPSingleToFixedS32','FPSingleToFixedU32']:
  expr=f'toint(f32({A}),{str("FixedS" in op).lower()},{B},{C})'
 elif op in ['FPFixedS32ToSingle','FPFixedU32ToSingle']:
  cast='int32_t' if 'FixedS' in op else 'uint32_t';expr=f'bits32(std::ldexp(float({cast}({A})),-int({B})))'
 elif op in ['FPDoubleToFixedS32','FPDoubleToFixedU32']:
  expr=f'toint(f64({A}),{str("FixedS" in op).lower()},{B},{C})'
 elif op in ['FPFixedS32ToDouble','FPFixedU32ToDouble']:
  cast='int32_t' if 'FixedS' in op else 'uint32_t';expr=f'bits64(std::ldexp(double({cast}({A})),-int({B})))'
 elif op.startswith('FPVector'):
  kind=op[len('FPVector'):];code=f'U128 {v}=0; for(int lane=0;lane<4;lane++){{uint32_t a=uint32_t({A}>>(lane*32)),z=0;'
  if kind in ['Add32','Sub32','Mul32']:
   operator={'Add32':'+','Sub32':'-','Mul32':'*'}[kind];code+=f'uint32_t b=uint32_t({B}>>(lane*32));z=bits32(f32(a){operator}f32(b));'
  elif kind in ['Max32','Min32']:
   operator='>' if kind=='Max32' else '<';zero='&' if kind=='Max32' else '|'
   code+=f'uint32_t b=uint32_t({B}>>(lane*32));z=(std::isnan(f32(a))||std::isnan(f32(b)))?0x7fc00000u:((a&0x7fffffff)==0&&(b&0x7fffffff)==0)?(a{zero}b):(f32(a){operator}f32(b)?a:b);'
  elif kind=='Abs32':code+='z=a&0x7fffffff;'
  elif kind=='Neg32':code+='z=a^0x80000000;'
  elif kind in ['FromSignedFixed32','FromUnsignedFixed32']:
   cast='int32_t' if kind=='FromSignedFixed32' else 'uint32_t';code+=f'z=bits32(std::ldexp(float({cast}(a)),-int({B})));'
  elif kind in ['ToSignedFixed32','ToUnsignedFixed32']:code+=f'z=toint(f32(a),{str(kind=="ToSignedFixed32").lower()},{B},{C});'
  else:unsupported[op]+=1;return f'uint64_t {v}=0;Result res{i}{{0}};s.status=-3;return;'
  code+=f'{v}|=U128(z)<<(lane*32);}}'
 elif op.startswith('FP') and op[-2:] in ['32','64']:
  n=op[-2:];kind=op[2:-2];f='f'+n;bits='bits'+n
  if kind in ['Add','Sub','Mul','Div']:
   operator={'Add':'+','Sub':'-','Mul':'*','Div':'/'}[kind];expr=f'{bits}({f}({A}){operator}{f}({B}))'
  elif kind=='Abs':expr=f'{A}&'+('0x7fffffffULL' if n=='32' else '0x7fffffffffffffffULL')
  elif kind=='Neg':expr=f'{A}^'+('0x80000000ULL' if n=='32' else '0x8000000000000000ULL')
  elif kind=='Sqrt':expr=f'{bits}(std::sqrt({f}({A})))'
  else:unsupported[op]+=1;return f'uint64_t {v}=0;Result res{i}{{0}};s.status=-3;return;'
 else:unsupported[op]+=1;return f'uint64_t {v}=0;Result res{i}{{0}};s.status=-3;return;'
 if expr is not None:
  typ={'U128':'U128','U64':'uint64_t'}.get(o['type'],'uint32_t');code=f'{typ} {v}={expr};'
 return code
files=[]
for start in range(0,len(blocks),750):
 lines=['#include "state.h"']
 for b in blocks[start:start+750]:
  key=b['location'];lines.append(f'void b_{key}(State&s){{')
  if not (key>>32)&1 and b.get('words') and b['words'][0] in [0xe59cf000,0xe08fc00c]:
   lines.append(f'if(read32(s,{key&0xffffffff}u)==0xe12fff1eu){{bx(s,s.r[14]);return;}}')
  if not (key>>32)&1 and b.get('words') and ((b['words'][0]&0xfffff000)==0xe59ff000 or b['words'][0] in [0xe59fc000,0xe59fc004]) and not any(o['op']=='CallSupervisor' for o in b['ops']):
   lines.append(f'{{auto instruction=read32(s,{key&0xffffffff}u);if((instruction&0xff000000u)==0xef000000u){{s.r[15]={((key&0xffffffff)+4)}u;s.status=instruction&0xffffffu;return;}}}}')
  if not (key>>32)&1 and any(o['op']=='CallSupervisor' for o in b['ops']):lines.append(f'if(import_stub(s,{key&0xffffffff}u))return;')
  if b['condition']!=14:lines.append(f'if(!cond(s,{b["condition"]})){{link(s,{b["failed"]}ULL);return;}}')
  for i,o in enumerate(b['ops']):lines.append(emit_op(o,i,b))
  lines.append(term(b['terminal']));lines.append('}')
 p=out/f'blocks-{start//750:03}.cpp';p.write_text('\n'.join(lines)+'\n');files.append(p.name)
lines=['#include "state.h"']+[f'extern void b_{b["location"]}(State&);' for b in blocks]
lines+=['struct Entry{uint64_t key;Block block;};','static Entry entries[]={']+[f'{{{b["location"]}ULL,b_{b["location"]}}},' for b in blocks]+['};','static Block find_uncached(uint64_t key){auto p=std::lower_bound(std::begin(entries),std::end(entries),key,[](const Entry&e,uint64_t k){return e.key<k;});return p!=std::end(entries)&&p->key==key?p->block:nullptr;}',
'static const bool cache_enabled=std::getenv("MPR_DISABLE_LOOKUP_CACHE")==nullptr;',
'static const bool collect_stats=std::getenv("MPR_AOT_LOOKUP_STATS")!=nullptr;',
'static thread_local Entry lookup_cache[16384]{};',
'static thread_local uint64_t cache_hits=0,cache_misses=0;',
'Block find_block(uint64_t key){if(!cache_enabled)return find_uncached(key);auto &slot=lookup_cache[((key>>1)^(key>>15)^(key>>32))&16383];if(slot.key==key&&slot.block){if(collect_stats)cache_hits++;return slot.block;}if(collect_stats)cache_misses++;auto block=find_uncached(key);slot={key,block};return block;}',
'void report_lookup_stats(){if(collect_stats)std::fprintf(stderr,"AOT lookup cache: %llu hits, %llu misses\\n",(unsigned long long)cache_hits,(unsigned long long)cache_misses);}' ]
(out/'dispatch.cpp').write_text('\n'.join(lines)+'\n')
(root/'reports/aot-coverage.json').write_text(json.dumps({'locations':len(blocks),'unsupported_ir':dict(unsupported)},indent=2)+'\n')
print('Generated',len(blocks),'functions in',len(files),'files; unsupported:',dict(unsupported))
