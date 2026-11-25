"""Evaluate only the explicitly selected C session; never mix smoke/workshop evidence."""
import json
from pathlib import Path
from tools.salary_simulation.studio_logs import extract
from tools.salary_simulation.v5_check import analyze
ROOT=Path('docs/simulation/v5/revalidation')

def run():
    extract(Path.home()/'Library/Logs/Roblox',ROOT/'raw','v5-split-telemetry')
    path=ROOT/'raw/studio_11.jsonl'
    if not path.exists():
        print('C session not yet logged');return
    rows=[json.loads(s) for s in path.read_text().splitlines()]
    settings=rows[0]['settings']
    assert settings['scenario']=='natural' and settings['playerType']=='normal' and settings['days']==5
    evidence=json.loads(path.with_name(path.stem+'_integrity.json').read_text())
    result=analyze(rows,evidence['parse_errors'])
    validity=[r for r in rows if r['kind']=='day_validity']
    result['gates']['five_day_validity']={r['day'] for r in validity}=={1,2,3,4,5}
    result['passed']=all(result['gates'].values())
    result['complete']=any(r['kind']=='complete' for r in rows)
    result['status']='passed' if result['passed'] else ('failed' if result['complete'] else 'pending')
    result['days']=[]
    for v in validity:
        day=v['day']
        conditions=next((r for r in rows if r['kind']=='day_conditions' and r['day']==day),None)
        summary=next((r for r in rows if r['kind']=='day_summary' and r['day']==day),{})
        slip=next((r for r in rows if r['kind']=='payslip' and r['day']==day),{})
        today=summary.get('today',{});earned=summary.get('earned')
        event=conditions.get('eventToday') if conditions else None
        result['days'].append(dict(day=day,event_category='bot_unsupported' if event in ('drill','audit') else 'other',conditions=conditions,valid=v['valid'],reasons=v['reasons'],net_pay=slip.get('dayTotal'),caught=summary.get('caught'),target_ok=slip.get('targetOk'),near_miss_count=today.get('nearMissCount'),near_miss_amount=today.get('nearMiss'),performance=earned,near_miss_performance_pct=100*today['nearMiss']/earned if earned and 'nearMiss' in today else None))
    result['file']=str(path)
    (ROOT/'C_check.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
    samples=[r for r in rows if r['kind']=='sample']
    print(json.dumps(dict(last={k:samples[-1].get(k) for k in ('day','minute','state','event','caught','rank')} if samples else None,ordinary=result['ordinary'],late=result['late'],return_overhead_median=result['return_overhead_median'],days=[{k:r[k] for k in ('day','valid','reasons','net_pay','near_miss_count')} for r in result['days']],gates=result['gates'],excluded=[dict(day=r.get('day'),reactionId=r['reactionId'],reason=r['excluded']) for r in result['transitions'] if 'excluded' in r]),ensure_ascii=False))

if __name__=='__main__': run()
