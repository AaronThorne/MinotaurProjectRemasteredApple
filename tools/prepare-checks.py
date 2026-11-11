#!/usr/bin/env python3
"""Prepare differential cases; intentionally trapping instructions are separate."""
from pathlib import Path
import json,struct
from experiment_config import workspace,game
root=workspace()
blocks=[json.loads(l) for l in (root/'work/gridrunner-ir.jsonl').open()]
skipped={};count=0
unsupported=set(json.loads((root/'reports/aot-coverage.json').read_text())['unsupported_ir'])
with (root/'work/check-expanded.trace').open('wb') as f:
 for b in blocks:
  reasons=[o['op'] for o in b['ops'] if o['op'] in unsupported or o['op'].startswith('Exclusive') or o['op']=='CallSupervisor' or (o['op']=='ExceptionRaised' and o['args'][1].get('imm') not in (9,10,11))]
  if reasons:
   for op in set(reasons):skipped[op]=skipped.get(op,0)+1
   continue
  f.write(struct.pack('<QII',b['location'],*b['words']));count+=1
(root/'reports/check-scope.json').write_text(json.dumps({'eligible_locations':count,'skipped_locations_by_reason':skipped,'states_per_location':4,'compared':['integer registers','FP register bits','CPSR','memory writes'],'not_compared':['FPSCR exception/status flags']},indent=2)+'\n')
print(count,'eligible locations; excluded:',skipped)
