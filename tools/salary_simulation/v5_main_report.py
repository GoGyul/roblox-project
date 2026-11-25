"""Descriptive results plus explicitly matched strata; pending sessions stay pending."""
import collections
import itertools
import json
import statistics
from pathlib import Path
ROOT=Path('docs/simulation/v5/main')
NAMES={'cautious':'조심형','normal':'보통형','greedy':'욕심형','novice':'초보'}
RANKS={2:'사원 시작',4:'대리 시작',5:'과장 시작'}

def run():
    plan=json.loads((ROOT/'plan.json').read_text())
    days=json.loads((ROOT/'days.json').read_text())
    requested=json.loads((ROOT/'scope.json').read_text())['requested_sessions'] if (ROOT/'scope.json').exists() else 24
    completed=sum(r['status']=='complete' for r in plan)
    lines=['# v5 본 실측 진행 보고서','',f'완료 {completed}/{requested}세션. 정산 기록 {len(days)}/{requested*5}일. 원래 24세션 계획은 사용자 요청으로 4세션까지로 축소했다. 실행 중인 세션의 정산된 날은 잠정 관측이며 세션 완료로 세지 않는다.','',
        'A·B·C는 ../revalidation/검증보고서.md 참조. 아래 표는 검증 C를 제외한 본 실측만 포함한다. 실측하지 않은 조합은 미확인이다.', '',
        '## 시작 직급별 관측 요약','',
        '자연 승진을 막지 않았다. 따라서 아래 행의 직급은 세션 시작 직급이다. 일별 실제 시작 직급·잔액·경험치·경고·속도·요일·이벤트는 days.json의 conditions에 있다. 유효 일수는 valid=true 전체, 일반 표본은 여기서 봇 미대응 이벤트와 기록 문제를 제외한 수다. 수입 등은 일반 표본 내 기술 통계이며 서로 다른 이벤트 구성을 가진 행 간 우열 판단에 사용하지 않는다.','',
        '| 시작 직급 | 전략 | 유효 일수 / 일반 표본 | 실수령 평균 (범위) | 적발 합계 | 목표 달성 | 아슬아슬 횟수 합계 | 아슬아슬 금액 / 실적 합계 비율 |',
        '|---|---|---:|---|---:|---:|---:|---|']
    groups={}
    for rank in (2,4,5):
        for strategy in NAMES:
            allrows=[r for r in days if r['initial_rank']==rank and r['strategy']==strategy]
            valid=sum(r['valid'] for r in allrows)
            rows=[r for r in allrows if r['eligible_general']]
            groups[rank,strategy]=rows
            if not rows:
                lines.append(f'| {RANKS[rank]} | {NAMES[strategy]} | {valid} / 0 | 미확인 | 미확인 | 미확인 | 미확인 | 미확인 |');continue
            pay=[r['net_pay'] for r in rows];amount=sum(r['near_miss_amount'] for r in rows);performance=sum(r['performance'] for r in rows)
            lines.append(f"| {RANKS[rank]} | {NAMES[strategy]} | {valid} / {len(rows)} | {statistics.mean(pay):.1f} ({min(pay)}~{max(pay)}) | {sum(r['caught'] for r in rows)} | {sum(r['target_ok'] for r in rows)}/{len(rows)} | {sum(r['near_miss_count'] for r in rows)} | {amount} / {100*amount/performance:.2f}% |")
    comparisons=[]
    def stratum(r):
        c=r['conditions'];return (c['rank'],c['weekday'],c['eventToday'])
    for rank in (2,4,5):
        for a,b in itertools.combinations(NAMES,2):
            left=groups[rank,a];right=groups[rank,b]
            common=set(map(stratum,left)) & set(map(stratum,right))
            for key in sorted(common):
                l=[r for r in left if stratum(r)==key];rr=[r for r in right if stratum(r)==key]
                comparisons.append(dict(initial_rank=rank,actual_rank=key[0],weekday=key[1],eventToday=key[2],strategy_a=a,strategy_b=b,n_a=len(l),n_b=len(rr),net_mean_a=statistics.mean(r['net_pay'] for r in l),net_mean_b=statistics.mean(r['net_pay'] for r in rr)))
    (ROOT/'matched_comparisons.json').write_text(json.dumps(comparisons,ensure_ascii=False,indent=2))
    lines += ['', '戦略 비교용 수치는 matched_comparisons.json에 같은 실제 시작 직급·요일·eventToday끼리만 저장했다. 조건이 겹치지 않는 조합은 비교하지 않는다.'.replace('戦略','전략'), '', '## 일반 비교에서 제외한 날','', '| 세션 | 날 | 이벤트 | valid | 이유 |','|---:|---:|---|---|---|']
    excluded=[r for r in days if not r['eligible_general']]
    for r in excluded:lines.append(f"| {r['session']} | {r['day']} | {r['conditions'].get('eventToday')} | {r['valid']} | {', '.join(r['excluded_from_general_comparison'])} |")
    if not excluded:lines.append('| — | — | — | 현재 정산 기록 중 없음 |')
    lines += ['', '## 일별 아슬아슬 기록','', '실적 비율의 분모는 day_summary.earned(적발 감액을 반영한 실적)다. 감액된 날은 보너스 지급액/실적이 100%를 넘을 수 있으며, 총수입 구성비를 뜻하지 않는다.', '', '| 세션 | 날 | 시작 직급 | 이벤트 | 횟수 | 금액 | 실적 비율 |','|---:|---:|---:|---|---:|---:|---:|']
    for r in days:
        c=r['conditions'];pct=r['near_miss_performance_pct'];lines.append(f"| {r['session']} | {r['day']} | {c.get('rank')} | {c.get('eventToday') or '없음'} | {r['near_miss_count']} | {r['near_miss_amount']} | {pct:.2f}% |" if pct is not None else f"| {r['session']} | {r['day']} | {c.get('rank')} | {c.get('eventToday') or '없음'} | {r['near_miss_count']} | {r['near_miss_amount']} | 미확인 |")
    lines += ['', '## 근거의 한계','', '계산 모형과 20% 이상 차이: 아직 동일 조건 비교를 완료하지 않아 미확인. 탐색 계산에서 프로젝트 확률·폰 의심 배율은 보정했지만 행동과 거리 판정 등 나머지 차이가 있어, 동일 조건의 예측으로 취급하지 않는다.', '', '과장 인사평가 화면 실적 ○/40 및 금요일 순위: 별도 화면 관측 근거를 확보하기 전까지 미확인. 원시 Review 속성과 금요일 reviewNote는 days.json에 저장한다.', '', '밸런스 판단은 내리지 않는다. 정산 완료·기록 일치가 확인된 날의 기술 통계에는 근거가 있고, 아직 실행하지 않은 직급·전략 및 조건이 맞지 않는 전략 간 우열에는 근거가 부족하다.']
    comparison=ROOT/'model_comparison.json'
    if comparison.exists():
        model=json.loads(comparison.read_text())
        lines=[line.replace('계산 모형과 20% 이상 차이: 아직 동일 조건 비교를 완료하지 않아 미확인.', '계산 모형과의 탐색적 비교는 아래 표에 기재한다. 동일 조건을 완전히 재현한 검증은 아니다.') for line in lines]
        lines += ['', '## 계산 모형과 20% 이상 차이 난 관측', '',
                  '같은 직급·요일·시작 경고와 관측 시야 비율·평균 노출 시간을 넣어 10,000회 계산했다. 폰 의심도 0.35배·승진 경고 초기화·프로젝트 확률 1을 반영했다. 다만 수다·프로젝트 대응, 거리 배율, 아슬아슬 판정은 봇/게임과 달라 게임 오류나 밸런스 문제의 근거로 삼지 않는다. 개별 실측일과 모형 평균의 차이며 v4 데이터는 사용하지 않았다.', '',
                  '| 세션 | 날 | 모형 실수령 평균 | 실측 실수령 | (모형−실측)/실측 |',
                  '|---:|---:|---:|---:|---:|']
        for r in model['rows']:
            if r['over_20_pct']:
                lines.append(f"| {r['session']} | {r['day']} | {r['model_net_mean']:.1f} | {r['observed_net']} | {r['relative_difference_pct']:.1f}% |")
        lines += ['', '전체 계산값·설정·한계는 model_comparison.json 참조.']
    (ROOT/'진행보고서.md').write_text('\n'.join(lines)+'\n')
    print(dict(completed=completed,days=len(days),matched_strata=len(comparisons),excluded=len(excluded)))
if __name__=='__main__':run()
