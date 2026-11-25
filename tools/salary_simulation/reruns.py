"""Reproduce isolated balance counterfactuals; never edits the live Luau balance."""
import argparse
import json
from pathlib import Path
import numpy as np
from tools.salary_simulation.run import CONFIG, ACTIONS, TYPES, day, save_csv, request2, request3, request4, request5

def run(selected):
    root=Path('docs/simulation/results')
    def directory(name, change):
        p=root/name; p.mkdir(parents=True,exist_ok=True)
        (p/'change.json').write_text(json.dumps(change,ensure_ascii=False,indent=2)); return p
    if '3' in selected:
        z=np.load(root/'q1_samples.npz')
        samples={(r,t):{k.split('_',2)[2]:z[k] for k in z.files if k.startswith(f'r{r}_t{t}_')} for r in range(8) for t in range(4)}
        for value in [4,6,8]:
            CONFIG['npc_score_offset']=value
            request3(directory(f'rerun_npc_{value}',{'npc_score_offset':value}),samples)
        CONFIG['npc_score_offset']=0
    if '4' in selected:
        for name,value in [('half',.5),('045',.45)]:
            CONFIG['gift_scale']=value; request4(directory('rerun_gift_'+name,{'gift_scale':value}))
        CONFIG['gift_scale']=1
    if '5' in selected:
        for value in (50,45,40):
            ACTIONS[3,1]=value; request5(directory(f'rerun_phone_{value}',{'phone_detect':value}))
        ACTIONS[3,1]=55
    if '2' in selected:
        CONFIG['xp_gain_scale']=.5
        request2(directory('rerun_xp_half',{'xp_gain_scale':.5}),types=[1],strategies=['save'])
        CONFIG['xp_gain_scale']=1
    if '1' in selected:
        rows=[]
        for t in range(4):
            d=day(10000,1,t,seed=CONFIG['seed']+100+t+1000,target_scale=2.2)
            rows.append(dict(type=TYPES[t],target=2530,n=10000,target_success=100*np.mean(d['target_ok']),net=np.mean(d['net'])))
        save_csv(root/'rerun_employee_target2530.csv',rows)

if __name__=='__main__':
    p=argparse.ArgumentParser(); p.add_argument('--requests',default='1,2,3,4,5')
    run(p.parse_args().requests.split(','))
