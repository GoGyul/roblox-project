"""Outdoor pilot summaries; keep protocol versions in separate output folders."""
import argparse
import json
from collections import Counter
from pathlib import Path
from tools.salary_simulation.studio_logs import extract
parser=argparse.ArgumentParser()
parser.add_argument('--protocol', default='v6-outside-pilot')
parser.add_argument('--out', type=Path, default=Path('docs/simulation/v6-outside'))
args=parser.parse_args()
if args.protocol!='v6-outside-pilot' and args.out==Path('docs/simulation/v6-outside'):
 parser.error('A different protocol requires a separate --out directory')
OUT=args.out
extract(Path.home()/'Library/Logs/Roblox',OUT/'raw',args.protocol)
results=[]
notes_path=OUT/'session_notes.json'
notes=json.loads(notes_path.read_text()) if notes_path.exists() else {}
for name in json.loads((OUT/'raw/studio_sessions.json').read_text()):
 rows=[json.loads(s) for s in (OUT/'raw'/name).read_text().splitlines()]
 for day in sorted({r.get('day',0) for r in rows}-{0}):
  rr=[r for r in rows if r.get('day')==day]
  samples=[r for r in rr if r['kind']=='sample']
  durations=Counter()
  for a,b in zip(samples,samples[1:]):
   dt=b['time']-a['time']
   if a.get('waiting') or a.get('phase')=='offwork' or not 0<dt<=2: continue
   x,y,z=a['position']; location='cabin' if y>250 and x>=150 else 'roof' if y>250 else 'ground' if z>700 else 'office'
   durations[location]+=dt
  def one(k): return next((r for r in rr if r['kind']==k),None)
  result=dict(session=name,day=day,conditions=one('day_conditions'),validity=one('day_validity'),payslip=one('payslip'),summary=one('day_summary'),location_seconds={k:round(v,1) for k,v in durations.items()},departures=sum(r['kind']=='outside_departure' for r in rr),completed_trips=sum(r['kind']=='outside_trip_done' for r in rr),navigation_failures=[r for r in rr if r['kind']=='outside_navigation_failed' or r['kind']=='outside_navigation' and not r['reached'] or r['kind']=='outside_arrival' and not r['success']],last=samples[-1] if samples else None)
  results.append(result)
  result['transport_arrivals']=[r for r in rr if r['kind']=='outside_arrival']
  result['prompt_diagnostics']=[r for r in rr if r['kind']=='outside_prompt']
  result['session_assessment']=notes.get(name)
  result['eligible_for_comparison']=bool(one('day_validity') and one('day_validity').get('valid') and notes.get(name,{}).get('status')=='passed')
(OUT/'progress.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
for r in results:
 print(json.dumps({k:v for k,v in r.items() if k not in ('last','summary','conditions','validity','payslip','navigation_failures','transport_arrivals','prompt_diagnostics')},ensure_ascii=False))
 print('last', {k:(r['last'] or {}).get(k) for k in ('minute','state','awayGauge','caught','workSeconds','position')},'nav_failures',len(r['navigation_failures']),'pay',r['payslip'])
