#!/usr/bin/env python3
"""Extract observed JSON only; separate every Studio session (including failed pilots)."""
import argparse
import collections
import csv
import json
import statistics
from pathlib import Path

def read_records(stream):
    """Reassemble bounded hex frames; never invent a missing or corrupt fragment."""
    pending = {}
    for line in stream:
        if 'SALARY_SIM {' not in line:
            yield None, line.rstrip(), False
            continue
        try:
            row = json.JSONDecoder().raw_decode(line.split('SALARY_SIM ', 1)[1])[0]
            if not isinstance(row, dict):
                raise ValueError('record is not an object')
            if row.get('kind') != 'log_chunk':
                yield row, line.rstrip(), False
                continue
            ident, index, count, size = row['id'], row['index'], row['count'], row['bytes']
            if not isinstance(ident, str) or not all(type(x) is int for x in (index, count, size)) or not 1 <= index <= count <= 10000 or not 0 < size <= 240 * count:
                raise ValueError('invalid chunk envelope')
            payload = bytes.fromhex(row['payload'])
            item = pending.setdefault(ident, dict(count=count, size=size, parts={}, invalid=False))
            if (count, size) != (item['count'], item['size']) or index in item['parts'] or len(payload) > 240:
                item['invalid'] = True
                raise ValueError('duplicate or inconsistent chunk')
            item['parts'][index] = payload
            if len(item['parts']) == count:
                if item['invalid']:
                    raise ValueError('invalid chunk group')
                encoded = b''.join(item['parts'][i] for i in range(1, count + 1))
                if len(encoded) != size:
                    raise ValueError('chunk byte length mismatch')
                decoded = json.loads(encoded.decode('utf-8'))
                if not isinstance(decoded, dict) or decoded.get('kind') == 'log_chunk':
                    raise ValueError('invalid reconstructed record')
                del pending[ident]
                yield decoded, line.rstrip(), False
        except (ValueError, KeyError, TypeError) as error:
            yield None, f'{line.rstrip()} [parse_error: {error}]', True
    for ident, item in pending.items():
        missing = sorted(set(range(1, item['count'] + 1)) - item['parts'].keys())
        yield None, f'incomplete_chunk id={ident} missing={missing} invalid={item["invalid"]}', True

def record_integrity(rows):
    complete = next((r for r in rows if r.get('kind') == 'complete'), None)
    days = {r.get('day') for r in rows if isinstance(r.get('day'), int) and r['day'] > 0}
    if complete:
        days.update(range(1, complete['requestedDays'] + 1))
    result = []
    for day in sorted(days):
        kinds = {r.get('kind') for r in rows if r.get('day') == day}
        # Live days remain pending, but completed sessions must contain every day.
        ended = bool(complete or kinds & {'day_validity', 'day_summary', 'payslip'})
        required = {'day_conditions', 'day_validity', 'day_summary', 'payslip'} if ended else {'day_conditions'}
        result.append(dict(day=day, ended=ended, missing=sorted(required-kinds)))
    return result

def extract(log_dir, out, protocol=None, supplements=None):
    out.mkdir(parents=True, exist_ok=True)
    sessions=[]
    for log in sorted(log_dir.glob('*Studio*.log')):
        current=None
        recent=collections.deque(maxlen=80)
        with log.open(errors='replace') as stream:
            for row, line, failed in read_records(stream):
                if failed:
                    if current is not None: current.setdefault('parse_errors',[]).append(line)
                    continue
                if row is None:
                    recent.append(line.rstrip())
                    if current is not None and any(k in line for k in ('Error', 'Warning', '[Meshes]', 'Disconnect from')):
                        current['diagnostics'].append(line.rstrip())
                    continue
                if row.get('kind')=='session':
                    startup=[x for x in recent if any(k in x for k in ('Error', 'Warning', '[Meshes]', 'StudioAccessToApisNotAllowed', 'failed due to'))]
                    current={'log':log.name,'rows':[], 'diagnostics':startup}; sessions.append(current)
                    recent.clear()
                if current is not None: current['rows'].append(row)
    reports=[]
    if protocol:
        sessions=[s for s in sessions if s['rows'][0].get('settings',{}).get('protocol')==protocol]
    if supplements:
        for item in json.loads(supplements.read_text()):
            for session in sessions:
                head=session['rows'][0]
                if head.get('time')!=item['session_time'] or head.get('settings',{}).get('protocol')!=item['protocol']: continue
                row=item['row']
                if not any(r.get('kind')==row['kind'] and r.get('day')==row['day'] for r in session['rows']):
                    session['rows'].append(dict(row,_recovered_from=item['source']))
    (out/'studio_sessions.json').write_text(json.dumps([f'studio_{i+1:02d}.jsonl' for i in range(len(sessions))]))
    for i,s in enumerate(sessions):
        name=f'studio_{i+1:02d}'
        integrity=record_integrity(s['rows'])
        (out/f'{name}_integrity.json').write_text(json.dumps(dict(days=integrity,parse_errors=len(s.get('parse_errors',[]))),ensure_ascii=False,indent=2))
        (out/f'{name}.jsonl').write_text(''.join(json.dumps(x,ensure_ascii=False)+'\n' for x in s['rows']))
        (out/f'{name}_diagnostics.log').write_text('\n'.join(s['diagnostics'])+'\n')
        (out/f'{name}_parse_errors.log').write_text('\n'.join(s.get('parse_errors',[]))+'\n')
        groups=collections.defaultdict(list)
        for x in s['rows']:
            if x.get('kind')=='sample': groups[x['day']].append(x)
        for day,rows in groups.items():
            work=[r for r in rows if r.get('phase')=='work' and not r.get('waiting')]
            desk=[r for r in work if r['state'] in ('work','blank','webtoon','phone','shopping','sleep','recline','returning')]
            summary=next((r for r in s['rows'] if r.get('kind')=='day_summary' and r['day']==day),None)
            payslip=next((r for r in s['rows'] if r.get('kind')=='payslip' and r['day']==day),None)
            conditions=next((r for r in s['rows'] if r.get('kind')=='day_conditions' and r['day']==day),None)
            validity=next((r for r in s['rows'] if r.get('kind')=='day_validity' and r['day']==day),None)
            navigation=[r for r in s['rows'] if r.get('day')==day and r.get('kind') in ('navigation','navigation_done','nav_stuck','navigation_seat_missing')]
            observed=max(0,rows[-1]['time']-rows[0]['time'])
            visible_time=0.; measured_time=0.; visits=[]; entered=None
            desk_states=('work','blank','webtoon','phone','shopping','sleep','recline','returning')
            for previous,current in zip(rows,rows[1:]):
                eligible=previous.get('phase')=='work' and not previous.get('waiting') and previous['state'] in desk_states
                dt=current['time']-previous['time']
                if not eligible or dt>2:
                    entered=None
                    continue
                measured_time+=dt
                if previous['bossVisible']: visible_time+=dt
                if not previous['bossVisible'] and current['bossVisible']: entered=current['time']
                if previous['bossVisible'] and not current['bossVisible'] and entered is not None:
                    visits.append(current['time']-entered); entered=None
            reports.append(dict(session=name,protocol=s['rows'][0].get('settings',{}).get('protocol','v1-studio-preview'),day=day,strategy=rows[-1]['strategy'],samples=len(rows),observed_seconds=round(observed,1),
                source='실측',complete=summary is not None,desk_work_samples=len(desk),work_samples=len(work),
                valid=validity.get('valid') if validity else None,reasons=validity.get('reasons') if validity else ['validity_missing'],
                record_integrity=next((r for r in integrity if r['day']==day),None),
                start_conditions=conditions,day_validity=validity,navigation=navigation,
                navigation_counts=dict(collections.Counter(r['kind'] for r in navigation)),
                boss_visible_sample_pct=round(100*sum(r['bossVisible'] for r in desk)/len(desk),1) if desk else None,
                boss_visible_time_pct=round(100*visible_time/measured_time,1) if measured_time else None,
                visible_seconds=round(visible_time,1),measured_work_seconds=round(measured_time,1),
                visit_count=len(visits),visit_mean=round(statistics.mean(visits),1) if visits else None,
                visit_median=round(statistics.median(visits),1) if visits else None,
                start_rank=rows[0]['rank'],end_rank=rows[-1]['rank'],start_warnings=rows[0]['warnings'],end_warnings=rows[-1]['warnings'],
                pay=payslip.get('dayTotal') if payslip else None,fired=payslip.get('fired') if payslip else summary.get('fired') if summary else None,
                end_bank=rows[-1]['bank'],end_xp=rows[-1]['xp'],
                states=dict(collections.Counter(r['state'] for r in rows)),
                caught=rows[-1]['caught'],earned=round(rows[-1]['earned'],1),work_seconds=round(rows[-1]['workSeconds'],1),
                memory_first=round(rows[0]['memoryMb'],1),memory_last=round(rows[-1]['memoryMb'],1),
                max_heartbeat=round(max(r['heartbeatMax'] for r in rows),3),
                summary=summary,log=s['log']))
    (out/'studio_summary.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2))
    return reports

if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('--logs',type=Path,default=Path.home()/'Library/Logs/Roblox')
    p.add_argument('--out',type=Path,default=Path('docs/simulation/studio'))
    p.add_argument('--protocol',help='Only export this protocol; use a separate output directory.')
    p.add_argument('--supplements',type=Path,help='Explicit UI-recovered records with matching session time and protocol.')
    a=p.parse_args()
    for row in extract(a.logs,a.out,a.protocol,a.supplements):
        print(json.dumps({k:v for k,v in row.items() if k not in ('summary','log')},ensure_ascii=False))
