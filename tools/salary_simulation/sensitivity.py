"""Full requested sample sizes; change one assumption at a time."""
from pathlib import Path
import json
import shutil
import numpy as np
from tools.salary_simulation.run import CONFIG, day, request2, request3, request4, request5, request6, request7

def run():
    root=Path('docs/simulation/results'); baseline=dict(CONFIG)
    for key in ('visibility_scale','reaction_scale','bonus_scale'):
        for scale in (.7,1.3):
            CONFIG.update(baseline); CONFIG[key]=scale
            out=root/'sensitivity'/f'{key}_{scale}'; out.mkdir(parents=True,exist_ok=True)
            (out/'config.json').write_text(json.dumps(CONFIG,indent=2))
            # Four manager income distributions feed the full Q3 factorial.
            samples={(4,t):day(CONFIG['day_samples'],4,t,seed=CONFIG['seed']+400+t+1000) for t in range(4)}
            request3(out,samples)
            request2(out,types=[1],strategies=['save'])
            request7(out)
            # Bonus-free Q5 has no bonus sensitivity by definition. Use visit duration separately.
            if key!='bonus_scale': request5(out)
            print('Sensitivity complete',key,scale,flush=True)
    CONFIG.update(baseline)
    for key in ('gift_scale','chat_good','help_chance'):
        for scale in (.7,1.3):
            CONFIG.update(baseline); CONFIG[key]*=scale
            out=root/'sensitivity'/f'{key}_{scale}'; out.mkdir(parents=True,exist_ok=True)
            request4(out)
    for key in ('event_duration_scale','watch_interval_scale','project_chance'):
        for scale in (.7,1.3):
            CONFIG.update(baseline); CONFIG[key]*=scale
            out=root/'sensitivity'/f'{key}_{scale}'; out.mkdir(parents=True,exist_ok=True)
            shutil.copy(root/'q3_review.csv',out/'q3_review.csv'); request6(out)
    for scale in (.7,1.3):
        CONFIG.update(baseline); CONFIG['visit_mean']*=scale
        out=root/'sensitivity'/f'visit_mean_{scale}'; out.mkdir(parents=True,exist_ok=True); request5(out)
    CONFIG.update(baseline)

if __name__=='__main__': run()
