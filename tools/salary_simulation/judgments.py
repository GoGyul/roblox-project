"""Evaluate the document's numeric criteria against baseline CSVs."""
from pathlib import Path
from tools.salary_simulation.report import read, table

def run():
    rows=[]
    def add(q,criterion,context,value,good,note=''):
        rows.append(dict(request=q,criterion=criterion,context=context,value=value,verdict='통과' if good else '미달',note=note))
    q1=[r for r in read('q1_income.csv') if r['visibility']=='0.25']
    for r in q1:
        if r['type']=='보통형' and r['rank']!='인턴': add(1,'보통형 달성률 80~95%',r['rank'],float(r['target_success']),80<=float(r['target_success'])<=95)
        if r['type']=='초보' and r['rank'] in ('사원','주임'): add(1,'초보 초반 달성률 ≥50%',r['rank'],float(r['target_success']),float(r['target_success'])>=50)
    greedy={r['rank']:float(r['net']) for r in q1 if r['type']=='욕심형'}
    cautious={r['rank']:float(r['net']) for r in q1 if r['type']=='조심형'}
    greater=sum(greedy[k]>cautious[k] for k in greedy)
    add(1,'욕심형이 모든 직급에서 조심형보다 이득이면 실패','8직급',greater,greater<8,'욕심형 수령액이 더 높은 직급 수')
    add(1,'목표 배수의 지속 감소 없음','보통형 사원→이사','5.0→1.4',False)
    q2=read('q2_careers.csv'); normal=next(r for r in q2 if r['type']=='보통형' and r['strategy']=='save')
    add(2,'대리 도달 1.5~3시간','보통형 무소비',float(normal['deputy_hours']),1.5<=float(normal['deputy_hours'])<=3)
    add(2,'이사 도달 15~30시간','보통형 무소비',float(normal['hours']),15<=float(normal['hours'])<=30)
    novice=next(r for r in q2 if r['type']=='초보' and r['strategy']=='save')
    add(2,'초보 초반 반복해고 정체 ≤20%','400일 내 대리 미도달',float(novice['early_stuck_pct']),float(novice['early_stuck_pct'])<=20,'중반 이후 정체를 검사하는 기준은 아님')
    stays=[r for r in read('q2_residence.csv') if r['type']=='보통형' and r['strategy']=='save' and r['rank']!='이사']
    for a,b in zip(stays,stays[1:]):
        ratio=float(b['dwell_mean'])/float(a['dwell_mean']); add(2,'체류 기간 전 직급의 2.5배 이하',b['rank'],ratio,ratio<=2.5)
    for r in read('q2_banks.csv'):
        if r['rank'] in ('과장','차장','부장','이사') and r['mean'] not in ('','nan'):
            add(2,'평균 통장 60만원 이하',r['type']+' '+r['rank'],float(r['mean']),float(r['mean'])<=600000,'Q7 최고가 6만원의 10배')
    q3=read('q3_review.csv')
    for r in q3:
        if r['type']=='보통형' and r['friendship']=='0':
            add(3,'중립 1등 5~20%','보통형',float(r['rank1']),5<=float(r['rank1'])<=20)
            add(3,'중립 꼴찌 15~30%','보통형',float(r['rank4']),15<=float(r['rank4'])<=30)
        if r['type']=='보통형' and r['friendship']=='4': add(3,'3명 친밀 1등 30~45%','보통형',float(r['rank1']),30<=float(r['rank1'])<=45)
        if r['type']=='욕심형':
            c=next(x for x in q3 if x['type']=='조심형' and x['friendship']==r['friendship'])
            add(3,'욕심형 1등이 조심형 이하','친밀도 '+r['friendship'],float(r['rank1'])-float(c['rank1']),float(r['rank1'])<=float(c['rank1']))
        if 'tattles_started' in r: add(3,'고자질 시작 주 3회 이하',r['type']+' 상황'+r['friendship'],float(r['tattles_started']),float(r['tattles_started'])<=3)
        v=max(float(r['rank'+str(k)]) for k in (1,2,3,4)); add(3,'한 순위 고정률 <99%',r['type']+' 상황'+r['friendship'],v,v<99)
    for r in read('q4_friendships.csv'):
        if r['strategy']=='focus1' and r['threshold']=='85': add(4,'집중 +85 평균 8~15일',f"수다{r['chats']}/선물{r['gifts']}",float(r['days_mean']),8<=float(r['days_mean'])<=15)
        if r['strategy']=='all9' and r['threshold']=='40': add(4,'전원+40 평균 20일 이상',f"수다{r['chats']}/선물{r['gifts']}",float(r['days_mean']),float(r['days_mean'])>=20)
    for r in read('q5_risk.csv'):
        if r['high']!='2.0': continue
        if r['weekday']=='1' and r['type'] in ('보통형','초보'):
            v=float(r['week_fired']); good=3<=v<=10 if r['type']=='보통형' else v<40
            add(5,'주간 해고 보통3~10%/초보<40%',r['type']+' 시야'+r['visibility'],v,good)
        if int(r['repeat_denominator'])>0:
            add(5,'재적발률 ≤ 첫 적발률 2배',r['type']+' 시야'+r['visibility']+' 요일'+r['weekday'],float(r['repeat']),float(r['repeat'])<=2*float(r['first']),f"첫 적발 {float(r['first']):.1f}%, 분모 {r['repeat_denominator']}")
    for r in read('q6_events.csv'):
        ctx=r['rank']+' 요일'+r['weekday']
        add(6,'창가 제외 사건 2~4개/일',ctx,float(r['excluding_watch']),2<=float(r['excluding_watch'])<=4)
        add(6,'중첩 ≤10%',ctx,float(r['overlap_pct']),float(r['overlap_pct'])<=10)
        add(6,'최장 조용한 구간 평균 ≤120초',ctx,float(r['quiet_longest_mean']),float(r['quiet_longest_mean'])<=120)
    items=read('q7_items.csv')
    for name in sorted({r['item'] for r in items}):
        usable=[r for r in items if r['item']==name and r['profit'] not in ('','nan')]
        if not usable: continue
        best=max(float(r['profit']) for r in usable)
        add(7,'어느 직급·유형에서라도 비음수 순이익',name,best,best>=0,'착석 모형의 현금 효과만')
        if name=='trip': add(7,'매일 출장 구매가 이득이 아님','전 직급·유형·시각 중 최대',best,best<=0)
    text='# 계산 모형 판정표\n\n통과/미달은 요청서의 수치 기준에만 적용합니다. 실측 전체 게임 판정이 아닙니다.\n\n'
    text+=table(rows,[('request','요청'),('criterion','기준'),('context','조건'),('value','결과'),('verdict','판정'),('note','설명')])
    Path('docs/simulation/판정표.md').write_text(text)

if __name__=='__main__':run()
