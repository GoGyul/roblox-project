"""Check actual result coverage and probability/accounting constraints."""
import csv
import json
import math
from pathlib import Path

def run():
    root=Path('docs/simulation/results'); checks=[]
    def load(name): return list(csv.DictReader((root/name).open(encoding='utf-8-sig')))
    for name,count in [('q1_income.csv',96),('q2_careers.csv',12),('q2_residence.csv',96),('q3_review.csv',24),('q4_friendships.csv',144),('q4_distributions.csv',648),('q5_risk.csv',180),('q6_events.csv',10),('q7_items.csv',212)]:
        r=load(name); assert len(r)==count,(name,len(r),count); checks.append(f'{name}: {count} rows')
    assert all(int(r['n'])==10000 for r in load('q1_income.csv'))
    assert all(int(r['n'])==2000 for r in load('q2_careers.csv'))
    assert all(int(r['n'])==5000 for r in load('q4_friendships.csv'))
    assert all(int(r['n'])==5000 for r in load('q5_risk.csv') if r['weekday']=='1')
    assert all(int(r['weeks'])==20000 for r in load('q6_events.csv'))
    for r in load('q3_review.csv'):
        assert abs(sum(float(r['rank'+str(k)]) for k in (1,2,3,4))-100)<1e-8
        assert float(r['tattles'])<=float(r['tattles_started'])<=5
    for r in load('q2_careers.csv'):
        assert abs(float(r['reached_pct'])/100*2000+int(r['censored'])-2000)<1e-6
        if float(r['reached_pct'])==0: assert r['days_mean']=='' and r['hours']==''
    for r in load('q1_income.csv'): assert float(r['p10'])<=float(r['median'])<=float(r['p90'])
    for r in load('q7_items.csv'):
        if r['total_gain'] and r['profit']: assert abs(float(r['total_gain'])-float(r['price'])-float(r['profit']))<1e-7
    checks+=['sample counts verified','review probabilities sum to 100%','censoring identities verified','item profit identities verified']
    (root/'verification.json').write_text(json.dumps({'passed':True,'checks':checks},ensure_ascii=False,indent=2))
    print('\n'.join(checks))

if __name__=='__main__':run()
