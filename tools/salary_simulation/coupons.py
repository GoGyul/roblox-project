"""Conditional firing-prevention valuation with explicit account-balance scenarios."""
from pathlib import Path
import csv
import numpy as np
from tools.salary_simulation.run import CONFIG, RANK, RANK_NAMES, TYPES, day, save_csv

def run():
    root=Path('docs/simulation/results'); n=2000
    banks=list(csv.DictReader((root/'q2_banks.csv').open(encoding='utf-8-sig')))
    income=list(csv.DictReader((root/'q1_income.csv').open(encoding='utf-8-sig')))
    rows=[]
    for target in [1,3,4,6]:
        for typ in range(4):
            rank=np.full(n,target-1,dtype=int); xp=np.full(n,RANK[target-1,0]); warn=np.zeros(n,dtype=int)
            reached=np.full(n,np.nan)
            for d in range(400):
                ix=np.flatnonzero(np.isnan(reached))
                if not len(ix): break
                if d%5==0: warn[:]=0
                x=day(len(ix),rank[ix],typ,seed=CONFIG['seed']+90000+target*1000+typ*400+d,weekday=d%5,warnings=warn[ix])
                xp[ix]+=np.maximum(x['net'],0); warn[ix]=x['warnings']
                dead=ix[x['fired']]; rank[dead]=np.maximum(0,rank[dead]-1); xp[dead]=RANK[rank[dead],0]
                alive=ix[~x['fired']]; rank[alive]=np.searchsorted(RANK[:,0],xp[alive],side='right')-1
                reached[(rank>=target)&np.isnan(reached)]=d+1
            values=reached[np.isfinite(reached)]; days=float(values.mean()) if len(values) else None
            pay=float(next(r['net'] for r in income if r['rank']==RANK_NAMES[target] and r['type']==TYPES[typ] and r['visibility']=='0.25'))
            bankrow=next(r for r in banks if r['rank']==RANK_NAMES[target] and r['type']==TYPES[typ])
            bank=float(bankrow['median']) if bankrow['median'] else float('nan')
            for label,balance in [('empty_account',0.),('median_first_rank_arrival',bank)]:
                valid=days is not None and np.isfinite(balance)
                rows.append(dict(rank=RANK_NAMES[target],type=TYPES[typ],scenario=label,n=n,bank=balance if np.isfinite(balance) else None,
                    recovery_days=days,recovered_pct=100*len(values)/n,current_daily_income=pay,
                    saved_value=balance+days*pay if valid else None,profit=balance+days*pay-50000 if valid else None,
                    caveat='conditional on preventing one firing; recovery starts Monday from demoted threshold; no certificates or review rewards; recovery mean excludes 400-day censoring'))
            print('Coupon recovery',RANK_NAMES[target],TYPES[typ],flush=True)
    save_csv(root/'q7_coupon_scenarios.csv',rows)

if __name__=='__main__': run()
