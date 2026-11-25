"""v4-only evidence; pending observations never pass a gate."""
import json, statistics
from pathlib import Path
from tools.salary_simulation.studio_logs import extract
ROOT=Path('docs/simulation/v4')
PROTOCOL='v4-fast-sight-validity'
def run():
 extract(Path.home()/'Library/Logs/Roblox', ROOT/'raw', PROTOCOL, ROOT/'ui_recovered.json' if (ROOT/'ui_recovered.json').exists() else None)
 results=[]
 for path in sorted((ROOT/'raw').glob('studio_*.jsonl')):
  rows=[json.loads(s) for s in path.read_text().splitlines()]
  settings=rows[0]['settings']; samples=[r for r in rows if r['kind']=='sample']
  env=next((r for r in rows if r['kind']=='environment'),{})
  result={'file':path.name,'settings':settings,'environment':env,'samples':len(samples)}
  if settings['scenario']=='workshop':
   statuses=[r for r in rows if r['kind']=='workshop_status']
   outcome=next((r for r in statuses if r['status'] in ('out','finished','timeout')),None)
   done=next((r for r in rows if r['kind']=='event_stage' and r.get('stage')=='done'),None)
   seated=next((r for r in samples if done and r['time']>done['time'] and r.get('seated')),None)
   nav=[r for r in rows if r['kind'] in ('navigation','navigation_done','nav_stuck','navigation_seat_missing')]
   elapsed=seated['time']-done['time'] if seated else None
   stuck=sum(r['kind']=='nav_stuck' for r in nav)
   caught=max((r['caught'] for r in samples),default=None)
   expected={'finish':'finished','out':'out','timeout':'timeout'}[settings['workshopCase']]
   result.update(outcome=outcome['status'] if outcome else None,return_seconds=elapsed,caught=caught,nav_stuck=stuck,navigation=nav,
    passed=bool(seated and elapsed<=30 and caught==0 and stuck==0 and outcome and outcome['status']==expected))
  else:
   starts={r['reactionId']:r for r in rows if r['kind']=='reaction_start'}
   response=[]
   for r in rows:
    if r['kind']!='reaction_request':continue
    start=starts.get(r['reactionId'])
    if not start or r.get('previousAction') in ('','work'):continue
    observed=next((x for x in rows if x['kind']=='observed_state' and x['time']>=r['time'] and x['time']<=r['time']+8 and x['state']=='work'),None)
    sight=next((x for x in reversed(rows) if x['kind']=='sight_signal' and x.get('visible') and x['time']<=start['time']),None)
    before=next((x for x in reversed(samples) if x['day']==r['day'] and x['time']<=r['time']),None)
    after=next((x for x in samples if observed and x['day']==r['day'] and observed['time']<=x['time']<=observed['time']+1.5),None)
    catch_intervened=bool(before and after and after['caught']>before['caught'])
    response.append(dict(day=r['day'],reactionId=r['reactionId'],late=r['late'],previous_action=r.get('previousAction'),
     catch_intervened=catch_intervened,
     server_sight_at=sight['time'] if sight else None,client_signal_at=r['signalAt'],request_at=r['time'],work_at=observed['time'] if observed else None,
     request_seconds=r['elapsed'],client_actual_work_seconds=observed['time']-r['signalAt'] if observed else None,
     actual_work_seconds=observed['time']-sight['time'] if observed and sight else None))
   result['reaction_counts']={str(late):sum(x['late']==late for x in response) for late in (False,True)}
   for late in (False,True):
    values=[x['request_seconds'] for x in response if x['late']==late]
    actual=[x['actual_work_seconds'] for x in response if x['late']==late and x['actual_work_seconds'] is not None and not x['catch_intervened']]
    result['late' if late else 'ordinary']={'request_median':statistics.median(values) if values else None,'actual_work_median':statistics.median(actual) if actual else None,
     'completed_transitions':len(actual),'unresolved_transitions':sum(x['late']==late and x['actual_work_seconds'] is None for x in response),
     'catch_intervened_excluded':sum(x['late']==late and x['catch_intervened'] for x in response),
     'scheduled_reactions':sum(x.get('late')==late for x in starts.values())}
    requested_ids={x['reactionId'] for x in rows if x['kind']=='reaction_request'}
    result['late' if late else 'ordinary']['scheduled_without_request']=sum(x.get('late')==late and x['reactionId'] not in requested_ids for x in starts.values())
   result['by_action']={}
   for action in sorted({x['previous_action'] for x in response}):
    values=[x['actual_work_seconds'] for x in response if not x['late'] and x['previous_action']==action and x['actual_work_seconds'] is not None and not x['catch_intervened']]
    result['by_action'][action]={'n':len(values),'median':statistics.median(values) if values else None,'min':min(values) if values else None,'max':max(values) if values else None}
   result['reactions']=response
   result['validity']=[r for r in rows if r['kind']=='day_validity']
   result['days']=[]
   for validity in result['validity']:
    day=validity['day']
    conditions=next((r for r in rows if r['kind']=='day_conditions' and r['day']==day),None)
    summary=next((r for r in rows if r['kind']=='day_summary' and r['day']==day),{})
    slip=next((r for r in rows if r['kind']=='payslip' and r['day']==day),{})
    today=summary.get('today',{}); earned=summary.get('earned')
    event=conditions.get('eventToday') if conditions else None
    # Source schedule, not an observed LeePresent signal. Never merge unsupported days.
    company=conditions.get('company') if conditions else None
    lee_expected=False if company=='nunchi' else (conditions.get('weekday') in ('수요일','목요일') if company=='daechung' else None)
    result['days'].append({'day':day,'conditions':conditions,'valid':validity['valid'],'reasons':validity['reasons'],
     'lee_expected_from_source_schedule':lee_expected,
     'event_category':'bot_unsupported' if event in ('drill','audit') or lee_expected else ('unknown' if lee_expected is None else 'other'),
     'net_pay':slip.get('dayTotal'),'caught':summary.get('caught'),'target_ok':slip.get('targetOk'),
     'near_miss_count':today.get('nearMissCount'),'near_miss_amount':today.get('nearMiss'),
     'performance':earned,'near_miss_performance_pct':100*today['nearMiss']/earned if earned and 'nearMiss' in today else None})
   result['completed']=any(r['kind']=='complete' for r in rows)
   median=result['ordinary']['actual_work_median']
   result['gates']={'actual_work_latency':median is not None and 0.5<=median<=0.8,
    'five_day_validity':set(r['day'] for r in result['validity'])==set(range(1,6)),
    'no_mesh_fallback':env.get('meshFallback') is False}
   result['passed']=result['completed'] and all(result['gates'].values())
  results.append(result)
 (ROOT/'checks.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
 for r in results:
  print(json.dumps({k:v for k,v in r.items() if k not in ('navigation','reactions')},ensure_ascii=False))
if __name__=='__main__':run()
