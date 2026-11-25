"""Single-variable reruns and explicit +/-30% assumption sensitivity."""
from pathlib import Path
import numpy as np
from tools.salary_simulation.run import day, CONFIG, RANK_NAMES, TYPES, save_csv, request4, request6

def run(out):
    out.mkdir(parents=True,exist_ok=True)
    n=CONFIG['day_samples']; rows=[]
    # The same baseline seed is paired to each variant. Exactly one factor changes.
    for r in [1,4,6]:
        for typ in range(4):
            for factor in ['visibility','reaction_scale','bonus_scale']:
                for scale in [.7,1.,1.3]:
                    kw={factor:scale} if factor!='visibility' else {'visibility':.25*scale}
                    d=day(n,r,typ,seed=CONFIG['seed']+r*10+typ,**kw)
                    rows.append(dict(rank=RANK_NAMES[r],type=TYPES[typ],factor=factor,scale=scale,n=n,
                        target_success=100*np.mean(d['target_ok']),caught=np.mean(d['caught']),net=np.mean(d['net']),fired=100*np.mean(d['fired'])))
    save_csv(out/'sensitivity_income.csv',rows)
    rows=[]
    for r in [1,2,3,4,5,6,7]:
        for typ in range(4):
            for scale in [1.,1.3,1.6,2.]:
                d=day(n,r,typ,seed=CONFIG['seed']+r*100+typ+1000,target_scale=scale)
                rows.append(dict(rank=RANK_NAMES[r],type=TYPES[typ],variable='target_scale',value=scale,n=n,
                    target_success=100*np.mean(d['target_ok']),net=np.mean(d['net']),fired=100*np.mean(d['fired'])))
    save_csv(out/'rerun_targets.csv',rows)
    rows=[]
    for scale in [1.,1.3,2.]:
        for typ in range(4):
            d=day(n,4,typ,seed=CONFIG['seed']+400+typ+1000,penalty_scale=scale)
            rows.append(dict(rank=RANK_NAMES[4],type=TYPES[typ],variable='catch_penalty_scale',value=scale,n=n,target_success=100*np.mean(d['target_ok']),net=np.mean(d['net'])))
    save_csv(out/'rerun_penalty.csv',rows)

if __name__=='__main__': run(Path('docs/simulation/results'))
