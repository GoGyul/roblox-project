"""Exploratory v5-only comparison, not a claim that the model reproduces the bot."""
import hashlib
import json
from pathlib import Path
import numpy as np
from tools.salary_simulation.run import CONFIG, day
ROOT=Path('docs/simulation/v5/main')

def run():
    days=json.loads((ROOT/'days.json').read_text())
    summaries=json.loads(Path('docs/simulation/v5/revalidation/raw/studio_summary.json').read_text())
    observations={(r['session'],r['day']):r for r in summaries}
    CONFIG.update(phone_suspicion_factor=.35,promotion_resets_warnings=True,project_chance=1.)
    types={'cautious':0,'normal':1,'greedy':2,'novice':3}
    result=[]
    for row in days:
        if not row['eligible_general'] or row['conditions']['eventToday']: continue
        obs=observations.get((f"studio_{row['session']+11:02d}",row['day']))
        if not obs or not obs['visit_mean'] or not obs['boss_visible_time_pct']: continue
        cond=row['conditions'];seed=20261125+900000+row['session']*10+row['day']
        modeled=day(10000,cond['rank']-1,types[row['strategy']],seed=seed,
                    weekday=row['day']-1,warnings=np.full(10000,cond['warnings']),
                    visibility=obs['boss_visible_time_pct']/100,visit_mean=obs['visit_mean'])
        mean=float(np.mean(modeled['net']));actual=row['net_pay']
        diff=100*(mean-actual)/abs(actual) if actual else None
        result.append(dict(session=row['session'],day=row['day'],rank=cond['rank'],strategy=row['strategy'],weekday=cond['weekday'],eventToday='',n=10000,seed=seed,observed_visibility=obs['boss_visible_time_pct']/100,observed_mean_visit=obs['visit_mean'],model_net_mean=mean,observed_net=actual,relative_difference_pct=diff,over_20_pct=abs(diff)>=20 if diff is not None else None,model_caught_mean=float(np.mean(modeled['caught'])),observed_caught=row['caught']))
    data=dict(source='calculation_vs_v5_observation_only',model_source_sha256=hashlib.sha256(Path('tools/salary_simulation/run.py').read_bytes()).hexdigest(),overrides=dict(phone_suspicion_factor=.35,promotion_resets_warnings=True,project_chance=1.),limitations=['One observed day compared with a model mean; not an estimate of game balance.', 'Visibility fraction and mean visit matched, but random visit process is not the observed path.', 'Model chat/project success bonuses differ from this bot, which does not actively complete those tasks.', 'Distance multiplier and actual near-miss cooldown/award timing are not fully represented.', 'Event days excluded; no v4 observations are used.'],rows=result)
    (ROOT/'model_comparison.json').write_text(json.dumps(data,ensure_ascii=False,indent=2))
    print(dict(compared_days=len(result),over_20_pct=sum(r['over_20_pct'] is True for r in result)))
if __name__=='__main__':run()
