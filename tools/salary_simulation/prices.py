"""Exact price-only ledger reruns: changing price does not change simulated behavior."""
import csv
from pathlib import Path
from tools.salary_simulation.report import table

def run():
    root=Path('docs/simulation/results')
    rows=list(csv.DictReader((root/'q7_items.csv').open(encoding='utf-8-sig')))
    changes={'plant':200,'sleep_coffee':700,'trip':3500}
    reruns=[]; summary=[]; ranks=['사원','대리','과장','부장']
    for r in rows:
        if r['item'] in changes and r['total_gain']:
            value=float(r['total_gain']); price=changes[r['item']]
            reruns.append(dict(item=r['item'],rank=r['rank'],type=r['type'],use_second=r['use_second'],
                old_price=r['price'],new_price=price,old_profit=r['profit'],new_profit=value-price,
                method='exact same simulated payoff minus new price; no behavior change'))
    with (root/'rerun_prices.csv').open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(reruns[0])); w.writeheader(); w.writerows(reruns)
    for item in sorted({r['item'] for r in rows}):
        usable=[r for r in rows if r['item']==item and r['profit'] not in ('','nan')]
        good=[r for r in usable if float(r['profit'])>=0]
        if not usable: continue
        positive=sorted({r['rank'] for r in good},key=ranks.index)
        summary.append(dict(item=item,minimum_rank=positive[0] if positive else '없음 (착석 현금 기준)',
            best_profit=max(float(r['profit']) for r in usable),
            too_cheap=any(float(r['price'])>0 and float(r['profit'])>3*float(r['price']) for r in usable)))
    text='# 아이템 가격만 바꾼 정확한 손익 재계산\n\n'
    text+='가격은 행동에 영향을 주지 않는 모형이므로 기존 시행의 추가 수령액에서 새 가격만 빼면 동일 표본 재실험과 같습니다. 원본은 `results/rerun_prices.csv`입니다. **출장권 3,500원은 일부 조건에서 매일 구매가 이득이 되어 핵심 긴장을 없애므로 채택 권고가 아닙니다.** 반차권·출석 인형은 이 착석 모형으로 외출·해고 예방 편익을 평가할 수 없어 가격 인하를 권하지 않습니다.\n\n'
    text+=table(summary,[('item','물건'),('minimum_rank','이득인 최소 직급(유형 중 하나)'),('best_profit','기존 최대 순이익'),('too_cheap','순이익>가격3배')])
    text+='\n'+table([r for r in reruns if r['rank']=='부장'],[('item','물건'),('type','유형'),('use_second','사용 초'),('old_price','기존 가격'),('new_price','변경 가격'),('old_profit','기존 순이익'),('new_profit','변경 순이익')])
    Path('docs/simulation/아이템가격.md').write_text(text)

if __name__=='__main__':run()
