"""v5 acceptance: request reaction and configured return delay are separate gates."""
import argparse
import json
import statistics
from pathlib import Path

from tools.salary_simulation.studio_logs import extract, record_integrity

PROTOCOL = 'v5-split-telemetry'


def analyze(rows, parse_errors=0, return_tolerance=0.3):
    if rows[0].get('settings', {}).get('protocol') != PROTOCOL:
        raise ValueError('v5 records required; do not reinterpret v4 acceptance results')
    transitions = []
    starts = {r['reactionId']: r for r in rows if r['kind'] == 'reaction_start'}
    for request in (r for r in rows if r['kind'] == 'reaction_request'):
        if request.get('previousAction') in ('', 'work'):
            continue
        start = starts.get(request['reactionId'])
        if not start:
            transitions.append(dict(reactionId=request['reactionId'], excluded='missing_reaction_start'))
            continue
        same_day = [r for r in rows if r.get('day') == request['day']]
        sight = next((r for r in reversed(same_day) if r['kind'] == 'sight_signal'
                      and r.get('visible') and r['time'] <= start['time']), None)
        accepted = next((r for r in same_day if r['kind'] == 'return_requested'
                         and request['time'] <= r['time'] <= request['time'] + 1
                         and r.get('action') == request['previousAction']), None)
        item = dict(day=request['day'], reactionId=request['reactionId'], late=request['late'],
                    action=request['previousAction'], request_at=request['time'])
        if not accepted or not sight:
            item['excluded'] = 'missing_server_request_or_sight'
            transitions.append(item)
            continue
        next_request = next((r['time'] for r in same_day if r['kind'] == 'reaction_request'
                             and r['time'] > request['time']), float('inf'))
        limit = min(next_request, accepted['time'] + accepted['expectedReturnSeconds'] + 2)
        work = next((r for r in same_day if r['kind'] == 'observed_state' and r['state'] == 'work'
                     and r.get('playerId') == accepted.get('playerId')
                     and accepted['time'] <= r['time'] < limit), None)
        item.update(sight_to_request=request['time']-sight['time'],
                    expected_return=accepted['expectedReturnSeconds'])
        if not work:
            changed = next((r for r in same_day if r['kind']=='observed_state'
                            and r.get('playerId')==accepted.get('playerId')
                            and accepted['time'] < r['time'] < limit
                            and r['state'] not in ('work','returning')), None)
            item['excluded'] = 'nonwork_resumed_before_work_observed' if changed else 'work_transition_missing_or_interrupted'
            if changed: item['interruption_evidence'] = changed
        elif work['caught'] != accepted['caught']:
            item['excluded'] = 'catch_intervened'
        else:
            item.update(request_to_work=work['time']-request['time'],
                        server_accept_to_work=work['time']-accepted['time'],
                        sight_to_work=work['time']-sight['time'],
                        return_overhead=work['time']-request['time']-accepted['expectedReturnSeconds'])
            item['return_within_tolerance'] = -0.1 <= item['return_overhead'] <= return_tolerance
        transitions.append(item)

    usable = [r for r in transitions if 'excluded' not in r]
    def summary(late):
        group = [r for r in usable if r['late'] == late]
        requests = [r['sight_to_request'] for r in transitions if r.get('late')==late and 'sight_to_request' in r]
        return dict(n=len(group), request_n=len(requests), sight_to_request=statistics.median(requests) if requests else None,
                    **{key: statistics.median([r[key] for r in group]) if group else None
                    for key in ('request_to_work', 'sight_to_work', 'return_overhead')})

    integrity = record_integrity(rows)
    near_miss = [r for r in rows if r['kind'] == 'near_miss_award']
    bonus_checks = []
    for daily in (r for r in rows if r['kind'] == 'day_summary'):
        awards = [r for r in near_miss if r['day'] == daily['day']]
        today = daily.get('today', {})
        bonus_checks.append(dict(day=daily['day'], recorded=len(awards),
            expected=today.get('nearMissCount'), amount=sum(r['amount'] for r in awards),
            matched=len(awards)==today.get('nearMissCount') and sum(r['amount'] for r in awards)==today.get('nearMiss')))
    ordinary = summary(False)
    complete = any(r['kind'] == 'complete' for r in rows)
    gates = dict(
        records_complete=complete and not parse_errors and bool(integrity) and all(not r['missing'] for r in integrity),
        request_reaction=ordinary['sight_to_request'] is not None and 0.5 <= ordinary['sight_to_request'] <= 0.8,
        action_return=bool(usable) and statistics.median(r['return_overhead'] for r in usable) <= return_tolerance,
        transitions_accounted=not any(r.get('excluded') not in (None, 'catch_intervened', 'nonwork_resumed_before_work_observed') for r in transitions),
        bonus_records=bool(bonus_checks) and all(r['matched'] for r in bonus_checks),
        no_mesh_fallback=any(r['kind']=='environment' and r.get('meshFallback') is False for r in rows))
    return dict(protocol=PROTOCOL, ordinary=ordinary, late=summary(True), transitions=transitions,
                integrity=integrity, parse_errors=parse_errors, near_miss_awards=near_miss,
                return_overhead_median=statistics.median(r['return_overhead'] for r in usable) if usable else None,
                criteria='2026-11-25 request-median + return-overhead-median; total informational',
                bonus_checks=bonus_checks, return_tolerance_seconds=return_tolerance,
                gates=gates, passed=all(gates.values()))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--logs', type=Path, default=Path.home()/'Library/Logs/Roblox')
    parser.add_argument('--out', type=Path, default=Path('docs/simulation/v5'))
    parser.add_argument('--return-tolerance', type=float, default=0.3)
    args = parser.parse_args()
    if not 0 <= args.return_tolerance <= 1:
        parser.error('return tolerance must be between 0 and 1 second')
    extract(args.logs, args.out/'raw', PROTOCOL)
    results = []
    manifest = json.loads((args.out/'raw'/'studio_sessions.json').read_text())
    for name in manifest:
        path = args.out/'raw'/name
        rows = [json.loads(line) for line in path.read_text().splitlines()]
        evidence = json.loads(path.with_name(path.stem+'_integrity.json').read_text())
        result = analyze(rows, evidence['parse_errors'], args.return_tolerance)
        results.append(dict(file=path.name, **result))
    (args.out/'checks.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))
    print(json.dumps(dict(sessions=len(results), passed=sum(r['passed'] for r in results)), ensure_ascii=False))
    return 0 if results and all(r['passed'] for r in results) else 1


if __name__ == '__main__':
    raise SystemExit(main())
