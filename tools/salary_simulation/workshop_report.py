"""Summarize observed transitions; no missing transition is treated as a pass."""
import json
from pathlib import Path
from tools.salary_simulation.studio_logs import extract

def run():
    out=Path('docs/simulation/next-tests')
    extract(Path.home()/'Library/Logs/Roblox',out/'raw')
    results=[]
    for file in sorted((out/'raw').glob('studio_*.jsonl')):
        rows=[json.loads(line) for line in file.read_text().splitlines()]
        settings=rows[0].get('settings',{})
        if settings.get('scenario')!='workshop': continue
        states=[r for r in rows if r.get('kind')=='workshop_status']
        outcome=next((r for r in states if r.get('status') in ('out','timeout','finished')),None)
        cleared=next((r for r in states if outcome and r['time']>outcome['time'] and r.get('status')==''),None)
        samples=[r for r in rows if r.get('kind')=='sample']
        seated=next((r for r in samples if cleared and r['time']>cleared['time'] and r.get('seated')),None)
        work=next((r for r in samples if seated and r['time']>seated['time']+2 and r.get('seated') and r.get('workSeconds',0)>seated['workSeconds']),None)
        nav=[r for r in rows if r.get('kind')=='navigation']
        results.append(dict(log=file.name,case=settings['workshopCase'],observed_outcome=outcome['status'] if outcome else None,status_cleared=bool(cleared),returned=bool(seated),work_resumed=bool(work),return_seconds=round(seated['time']-cleared['time'],2) if seated else None,navigation_attempts=len(nav),path_statuses=sorted(set(r['pathStatus'] for r in nav)),last_position=samples[-1].get('position') if samples else None))
    (out/'workshop_results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
    print(json.dumps(results,ensure_ascii=False,indent=2))
if __name__=='__main__': run()
