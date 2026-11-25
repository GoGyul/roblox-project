"""Separate source-derived rule scenarios. Still not a complete Roblox emulator."""
from pathlib import Path
import json
from tools.salary_simulation.run import CONFIG, request2

def run():
    baseline=dict(CONFIG)
    for name,changes in [('promotion_reset',{'promotion_resets_warnings':True}),
                         ('phone_factor',{'phone_suspicion_factor':.35}),
                         ('both',{'promotion_resets_warnings':True,'phone_suspicion_factor':.35})]:
        CONFIG.update(baseline); CONFIG.update(changes)
        out=Path('docs/simulation/results/source_rules')/name; out.mkdir(parents=True,exist_ok=True)
        (out/'change.json').write_text(json.dumps(changes,indent=2))
        request2(out,strategies=['save'])
    CONFIG.update(baseline)

if __name__=='__main__': run()
