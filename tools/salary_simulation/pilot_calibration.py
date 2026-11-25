"""Exploratory reruns from completed pilot days, not validated game calibration."""
import json
from pathlib import Path
import numpy as np
from tools.salary_simulation.run import day, CONFIG, ACTIONS, save_csv

def run():
    root=Path('docs/simulation'); summaries=json.loads((root/'studio/studio_summary.json').read_text())
    rows=[]; types={'cautious':0,'normal':1,'greedy':2,'novice':3}
    for r in summaries:
        if not r['complete'] or r['session']!='studio_02' or not r['visit_count']: continue
        if r['pay'] is None or r['desk_work_samples'] < .9 * r['work_samples']: continue
        typ=types[r['strategy']]; rank=r['start_rank']-1
        p=r['boss_visible_time_pct']/100; duration=r['visit_mean']
        for label in ['document','pilot_visibility','pilot_visibility_phone_factor']:
            ACTIONS[3,1]=55*(.35 if label=='pilot_visibility_phone_factor' else 1)
            kw={} if label=='document' else {'visibility':p,'visit_mean':duration}
            d=day(CONFIG['day_samples'],rank,typ,seed=CONFIG['seed']+80000+r['day'],weekday=(r['day']-1)%5,
                  warnings=np.full(CONFIG['day_samples'],r['start_warnings']),**kw)
            net=float(np.mean(d['net'])); measured=r['pay']
            rows.append(dict(day=r['day'],strategy=r['strategy'],scenario=label,n=CONFIG['day_samples'],
                visibility=.25 if label=='document' else p,visit_mean=8 if label=='document' else duration,
                modeled_net=net,observed_pay=measured,relative_difference_pct=100*(net-measured)/abs(measured) if measured else None,
                modeled_catches=float(np.mean(d['caught'])),observed_catches=r['caught'],
                caveat='single observed day vs model mean; event pay, chat/project behavior and sub-second sight unresolved'))
    ACTIONS[3,1]=55
    save_csv(root/'results/pilot_calibration.csv',rows)

if __name__=='__main__': run()
