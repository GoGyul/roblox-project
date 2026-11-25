"""Read-only live v5 evidence, including independent workshop acceptance."""
import json
from pathlib import Path
from tools.salary_simulation.studio_logs import extract

ROOT = Path('docs/simulation/v5/revalidation')

def workshop(rows):
    settings=rows[0]['settings']
    outcome=next((r for r in rows if r['kind']=='workshop_status' and r['status'] in ('out','timeout','finished')),None)
    done=next((r for r in rows if r['kind']=='event_stage' and r.get('stage')=='done'),None)
    samples=[r for r in rows if r['kind']=='sample']
    seated=next((r for r in samples if done and r['time']>done['time'] and r.get('seated')),None)
    nav=[r for r in rows if r['kind'] in ('navigation','navigation_done','nav_stuck','navigation_seat_missing')]
    caught=max((r['caught'] for r in samples),default=None)
    stuck=sum(r['kind']=='nav_stuck' for r in nav)
    elapsed=seated['time']-done['time'] if seated else None
    expected={'finish':'finished','out':'out','timeout':'timeout'}[settings['workshopCase']]
    return dict(case=settings['workshopCase'],outcome=outcome['status'] if outcome else None,
        return_seconds=elapsed,caught=caught,nav_stuck=stuck,navigation=nav,
        passed=bool(seated and elapsed<=30 and caught==0 and stuck==0 and outcome and outcome['status']==expected))

def main():
    extract(Path.home()/'Library/Logs/Roblox',ROOT/'raw','v5-split-telemetry')
    manifest=json.loads((ROOT/'raw/studio_sessions.json').read_text())
    results=[]
    for name in manifest:
        rows=[json.loads(s) for s in (ROOT/'raw'/name).read_text().splitlines()]
        if rows[0]['settings']['scenario']=='workshop':
            result=dict(file=name,**workshop(rows));results.append(result)
    (ROOT/'B_checks.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
    if manifest:
        rows=[json.loads(s) for s in (ROOT/'raw'/manifest[-1]).read_text().splitlines()]
        samples=[r for r in rows if r['kind']=='sample']
        print(json.dumps(dict(file=manifest[-1],settings=rows[0]['settings'],last={k:samples[-1].get(k) for k in ('day','minute','state','event','eventStage','caught','seated')} if samples else None,complete=any(r['kind']=='complete' for r in rows),B_passed=sum(r['passed'] for r in results),B_latest={k:v for k,v in results[-1].items() if k!='navigation'} if results else None),ensure_ascii=False))

if __name__=='__main__': main()
