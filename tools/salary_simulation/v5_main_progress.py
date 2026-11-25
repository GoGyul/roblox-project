"""Archive main sessions separately from v5 validation; no simulated data substitution."""
import collections
import json
from pathlib import Path
from tools.salary_simulation.studio_logs import extract, record_integrity
ROOT=Path('docs/simulation/v5/main')
RAW=Path('docs/simulation/v5/revalidation/raw')

def main():
    extract(Path.home()/'Library/Logs/Roblox',RAW,'v5-split-telemetry')
    allfiles=json.loads((RAW/'studio_sessions.json').read_text())
    plan=json.loads((ROOT/'plan.json').read_text())
    days=[];results=[]
    (ROOT/'raw').mkdir(exist_ok=True)
    scope=json.loads((ROOT/'scope.json').read_text()) if (ROOT/'scope.json').exists() else {'requested_sessions':24}
    for task,name in zip(plan[:scope['requested_sessions']],allfiles[11:]):
        rows=[json.loads(s) for s in (RAW/name).read_text().splitlines()]
        settings=rows[0]['settings']
        assert settings['scenario']=='natural' and settings['playerType']==task['strategy'] and settings['rank']==task['initial_rank'], (task,settings)
        target=f"session_{task['session']:02d}.jsonl"
        (ROOT/'raw'/target).write_text((RAW/name).read_text())
        evidence=json.loads((RAW/(Path(name).stem+'_integrity.json')).read_text())
        complete=any(r['kind']=='complete' for r in rows)
        task.update(status='complete' if complete else 'running',file=target,start_time=rows[0]['time'])
        samples=[r for r in rows if r['kind']=='sample']
        result=dict(task,record_integrity=evidence,last={k:samples[-1].get(k) for k in ('day','minute','rank','event','state','caught','fired')} if samples else None)
        results.append(result)
        for validity in (r for r in rows if r['kind']=='day_validity'):
            day=validity['day']
            cond=next((r for r in rows if r['kind']=='day_conditions' and r['day']==day),{})
            summary=next((r for r in rows if r['kind']=='day_summary' and r['day']==day),{})
            slip=next((r for r in rows if r['kind']=='payslip' and r['day']==day),{})
            today=summary.get('today',{});earned=summary.get('earned')
            event=cond.get('eventToday');company=cond.get('company')
            lee=company=='daechung' and cond.get('weekday') in ('수요일','목요일')
            unsupported=event in ('drill','audit') or lee
            awards=[r for r in rows if r['kind']=='near_miss_award' and r['day']==day]
            matched=len(awards)==today.get('nearMissCount') and sum(r['amount'] for r in awards)==today.get('nearMiss')
            missing=next((r['missing'] for r in evidence['days'] if r['day']==day),['integrity_missing'])
            reasons=list(validity['reasons'])
            if unsupported:reasons.append('bot_unsupported_event_or_scheduled_lee')
            if missing:reasons.append('missing_records')
            if evidence['parse_errors']:reasons.append('session_parse_errors')
            if not matched:reasons.append('bonus_records_mismatch')
            record=dict(session=task['session'],initial_rank=task['initial_rank'],strategy=task['strategy'],replicate=task['replicate'],day=day,conditions=cond,valid=validity['valid'],reasons=validity['reasons'],excluded_from_general_comparison=reasons,eligible_general=validity['valid'] and not reasons,unsupported_event=unsupported,lee_expected_from_source_schedule=lee,net_pay=slip.get('dayTotal'),caught=summary.get('caught'),target_ok=slip.get('targetOk'),near_miss_count=today.get('nearMissCount'),near_miss_amount=today.get('nearMiss'),performance=earned,near_miss_performance_pct=100*today['nearMiss']/earned if earned and 'nearMiss' in today else None,review=summary.get('review'),friday_review_note=slip.get('reviewNote'),bonus_records_match=matched)
            days.append(record)
    (ROOT/'plan.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2))
    (ROOT/'sessions.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
    (ROOT/'days.json').write_text(json.dumps(days,ensure_ascii=False,indent=2))
    print(json.dumps(dict(completed=sum(r['status']=='complete' for r in plan),planned=scope['requested_sessions'],last=results[-1] if results else None,settled_days=len(days),eligible_general=sum(r['eligible_general'] for r in days),excluded=collections.Counter(reason for r in days for reason in r['excluded_from_general_comparison'])),ensure_ascii=False))

if __name__=='__main__': main()
