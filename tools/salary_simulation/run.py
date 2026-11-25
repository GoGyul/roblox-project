#!/usr/bin/env python3
"""Request-sheet Monte Carlo model, NOT a Roblox emulator. NumPy only.

Run: python3 tools/salary_simulation/run.py --out docs/simulation/results
Apple system Python with Intel-only NumPy: arch -x86_64 /usr/bin/python3 ...
All uncertain assumptions are collected in CONFIG and assumptions.json.
"""
import argparse
import csv
import json
import time
from pathlib import Path
import numpy as np

# ---------- editable configuration (document values unless labelled assumption) ----------
CONFIG = dict(seed=20261125, day_seconds=420, lunch_start=140, lunch_seconds=47,
              day_samples=10000, career_samples=2000, review_samples=10000,
              friend_samples=5000, risk_samples=5000, event_weeks=20000,
              item_samples=10000, max_days=400, visibility=(.15,.25,.35),
              visit_mean=8., choice_seconds=8., reaction=.5, late_min=2., late_max=5.,
              chat_good=.6, chat_bad=.1, chat_turns=3, project_chance=.4,
              near_bonus=200., near_cap=5, late_arrival=0., lunch_late=0.,
              video_fraction=.0, gift_budgets=(1,2,4), gift_scale=1., help_chance=.35,
              xp_gain_scale=1., npc_score_offset=0., visibility_scale=1., reaction_scale=1., bonus_scale=1.,
              event_duration_scale=1., watch_interval_scale=1., phone_suspicion_factor=1.,
              promotion_resets_warnings=False, dt=1., risk_dt=.25)
RANK_NAMES = ['인턴','사원','주임','대리','과장','차장','부장','이사']
RANK = np.array([[0,1200,1,75,1000,2000,0], [6000,1600,1.15,85,1300,2500,1150],
 [20000,2200,1.3,90,1800,3200,1700], [50000,2800,1.5,100,2400,4000,2300],
 [100000,3600,1.75,105,3000,5000,2850], [170000,4600,2,115,3800,6200,3450],
 [260000,5800,2.3,120,4800,7500,4300], [380000,7200,2.7,130,6000,9000,5150]])
# action: income, detection, return delay, minimum rank (0-based)
ACTIONS = np.array([[2,0,0,0],[5,25,0,0],[7,40,.5,1],[9,55,1,0],
 [10,15,.5,1],[11,50,1,1],[14,45,1.2,0],[20,55,1.8,3]])
TYPES = ['조심형','보통형','욕심형','초보']
RATIOS = [.4,.55,.7,.5]
LATE = [.05,.15,.3,.45]
PROJECT_SUCCESS = [.8,.65,.55,.35]
POOLS = [[1,2],[2,3,5],[5,6,7],[3]]
ASSUMPTIONS = {
 'status':'All Monte Carlo outputs are 계산; Studio telemetry is separately labelled 실측.',
 'source':'Request-sheet rules, not a claim of parity with current SalaryConfig/Employees.',
 'visibility':'Alternating fixed 8s visits / exponential gaps, gap mean 8*(1-p)/p. Initially random stationary state; lunch interrupts visibility.',
 'time_resolution':'Q1 1s, Q5 .25s. Delay boundaries rounded up to tick; clock never accelerated in Studio.',
 'action_policy':'Initial quota seconds work (lunch still slack); then 8s decisions with type slack probability; actions uniformly drawn among unlocked pool. Visible players return to work after reaction+return delay and wait until visit ends.',
 'work_quota':'All seated seconds count as work in current game. Model deliberately works first quota seconds as request wording specifies; all simulated actions are seated.',
 'bonuses':'Chat count uniform 0..3; 3 reactions per chat, independent 60% good. Chat and project bonuses consume no time (optimistic document abstraction). Project resolves at 300s, 40% chance; success reduces warning or pays 3000; failure adds .10 speed, no invented warning.',
 'near_miss':'Only visible-entry while slacking, on-time return before visit end, maximum 5; combo reset on caught. No 30s cooldown in document model (actual game has one).',
 'weekdays':'Q1 equal Monday-Friday allocation; Q5 no project/chat/target warnings, rank 대리 fixed (not specified in Q5); Q2 carries warnings and removes one on project, Q2 Friday review rewards only.',
 'career':'Censor at 400 days; report reach fraction and conditional completion quantiles, never count censored players as reaching. Certificates one-time, cheapest affordable first, XP-only per document. Spending is 30% positive daily pay after settlement.',
 'review':'No commute/late-lunch penalties unless configured. 5 daily Q1 gross-income draws including fired-day outcomes, virtual full week (no survivor selection); day-1 provisional rank uses prior 0 score + peer score. Ties give worse rank. Theft/false-report adjustments are daily scores before averaging.',
 'friends':'Run full cross-product 4 strategies x chat budgets 2/4/6 x gift budgets 1/2/4. Three reaction attempts; bad answer ends conversation and loses 4, no completion +3. Gifts free for relationship-only study. Help random NPC. Report strategy picks focused NPC weekly; 0..3 random witnesses excluding target. No invented tattle-intercept opportunities.',
 'events':'Uniform starts in allowed windows; project duration U60..90, event U30..90. Window watches renewal U45..80, lunches not excluded by request. Manager tattle daily probability from neutral-normal Q3; deputy Wed/Thu one instantaneous incident. Video fraction defaults 0 because type pools contain no video; absence alarm 0 because desk model has no away route. Instantaneous incidents count but occupy zero time.',
 'items':'Paired seeds, independent repeated daily expectations times expiry. Warning coupon conditional valuation only. Attendance dolls cannot be priced from seated-only model; mark not identified rather than invent travel. Sleeping coffee success .85, failure +40 suspicion and +.10 at wake; no changed slack schedule when boss away. Halfday gives zero income as document says.',
 'not_measured':'Studio complete factorial runs, travel paths, 50-day mission frequency, item comparison and 20% calibration remain pending until adequate telemetry exists.',
}

def save_csv(path, rows):
    if not rows: return
    keys=list(dict.fromkeys(k for row in rows for k in row))
    with open(path,'w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=keys); w.writeheader(); w.writerows(rows)

def stats(x):
    return dict(mean=float(np.mean(x)),median=float(np.median(x)),p10=float(np.quantile(x,.1)),p90=float(np.quantile(x,.9)))

def day(n, rank, typ, visibility=.25, seed=0, dt=1., weekday=None, warnings=None,
        speed_limits=(.5,2.), bonuses=True, target_penalty=True, item=None,
        visit_mean=None, reaction_scale=1., bonus_scale=1., penalty_scale=1.,
        target_scale=1., detect_scale=1.):
    """Vectorized exact tick simulation, with per-tick incomes and absorbing firing."""
    rng=np.random.default_rng(seed)
    visibility*=CONFIG['visibility_scale']
    reaction_scale*=CONFIG['reaction_scale']
    bonus_scale*=CONFIG['bonus_scale']
    rk=np.broadcast_to(np.asarray(rank,dtype=int),(n,))
    wd=np.arange(n)%5 if weekday is None else np.broadcast_to(weekday,(n,))
    warn=np.zeros(n,dtype=int) if warnings is None else np.array(warnings,copy=True)
    quota=RANK[rk,3]; target=RANK[rk,6]*target_scale
    caught=np.zeros(n,dtype=int); earned=np.zeros(n); suspicion=np.zeros(n)
    speed=np.clip(1+np.where(wd==0,.1,np.where(wd==4,-.1,0)),*speed_limits)
    fired=np.zeros(n,dtype=bool); action=np.zeros(n,dtype=int); work=np.zeros(n)
    elapsed=np.zeros(n); bonus=np.zeros(n); near=np.zeros(n,dtype=int); combo=np.ones(n,dtype=int)
    visit_mean=CONFIG['visit_mean'] if visit_mean is None else visit_mean
    visible=rng.random(n)<visibility
    remaining=np.where(visible,rng.uniform(0,visit_mean,n),rng.exponential(visit_mean*(1-visibility)/visibility,n))
    response=np.full(n,np.inf); previous=np.zeros(n,dtype=bool)
    late_visit=np.zeros(n,dtype=bool); eligible=np.zeros(n,dtype=bool)
    hit_upper=np.zeros(n,dtype=bool); hit_lower=np.zeros(n,dtype=bool)
    visibility_seconds=np.zeros(n); busy_seconds=np.zeros(n)
    max_action=max(POOLS[typ]); pool=np.asarray(POOLS[typ])
    # Uniform among eligible actions, vectorized per rank; every pool has rank-1 fallback.
    rank_pools=[pool[ACTIONS[pool,3]<=r] for r in range(8)]
    late_probability=LATE[typ]*(.5 if item and item[0]=='radar' else 1)
    delay_factor=.5 if item and item[0]=='energy' else 1
    decay=10 if item and item[0]=='plant' else 8
    project=rng.random(n)<CONFIG['project_chance']
    success=rng.random(n)<PROJECT_SUCCESS[typ]
    coffee_success=rng.random(n)<.85
    coffee_used=False; project_done=False
    if item and item[0]=='boss_coffee': speed=np.clip(speed-.05,*speed_limits)
    for tick in range(int(round(CONFIG['day_seconds']/dt))):
        t=tick*dt; lunch=CONFIG['lunch_start']<=t<CONFIG['lunch_start']+CONFIG['lunch_seconds']
        alive=~fired
        remaining-=dt
        transition=remaining<=0
        to_visible=transition & ~visible; to_hidden=transition & visible
        visible[to_visible]=True; visible[to_hidden]=False
        remaining[to_visible]+=visit_mean
        remaining[to_hidden]+=rng.exponential(visit_mean*(1-visibility)/visibility,np.sum(to_hidden))
        seen=visible & ~np.full(n,lunch)
        if item and item[0] in ('trip','sleep_coffee'):
            use=item[1]
            if t>=use and item[0]=='trip': seen[:]=False
            if item[0]=='sleep_coffee':
                if use<=t<use+93: seen &= ~coffee_success
                if not coffee_used and t>=use:
                    suspicion+=np.where(coffee_success,0,40); coffee_used=True
                if t>=use+93 and t-dt<use+93: speed=np.clip(speed+coffee_success*.10,*speed_limits)
        if tick % max(1,int(CONFIG['choice_seconds']/dt))==0:
            choose=alive & ~seen
            slack=(rng.random(n)<RATIOS[typ]) & (t>=quota)
            if lunch: slack[:]=True
            picks=np.zeros(n,dtype=int)
            u=rng.random(n)
            for r in range(8):
                mask=rk==r; p=rank_pools[r]
                picks[mask]=p[np.minimum((u[mask]*len(p)).astype(int),len(p)-1)]
            action[choose]=np.where(slack[choose],picks[choose],0)
        if lunch and (t-dt<CONFIG['lunch_start']):
            for r in range(8):
                mask=(rk==r)&alive; p=rank_pools[r]
                action[mask]=rng.choice(p,np.sum(mask))
        enters=seen & ~previous & alive
        late_draw=rng.random(n)<late_probability
        extra=rng.uniform(CONFIG['late_min'],CONFIG['late_max'],n)
        response[enters]=t+(CONFIG['reaction']+np.where(late_draw[enters],extra[enters],0))*reaction_scale+ACTIONS[action[enters],2]*delay_factor
        late_visit[enters]=late_draw[enters]
        eligible[enters]=action[enters]!=0
        returned=alive & seen & (t>=response) & (action!=0)
        if bonuses:
            near_ok=returned & eligible & ~late_visit & (near<CONFIG['near_cap'])
            bonus[near_ok]+=CONFIG['near_bonus']*combo[near_ok]*bonus_scale
            near[near_ok]+=1; combo[near_ok]=np.minimum(5,combo[near_ok]+1)
        action[returned]=0; eligible[returned]=False
        rate=ACTIONS[action,1]*detect_scale
        rate*=np.where(action==3,CONFIG['phone_suspicion_factor'],1.)
        if item and item[0]=='screen': rate*=np.where(np.isin(action,[2,3,5]),.7,1)
        suspicion=np.where(alive & seen & (rate>0),suspicion+rate*speed/3*dt,np.maximum(0,suspicion-decay*dt))
        earn=ACTIONS[action,0]*RANK[rk,2]*dt
        earned+=np.where(alive,earn,0); elapsed+=alive*dt; work+=alive*dt
        visibility_seconds+=alive*seen*dt; busy_seconds+=alive*(not lunch)*dt
        hit=alive & (suspicion>=100)
        caught+=hit; warn+=hit; suspicion[hit]=0; combo[hit]=1; action[hit]=0
        speed=np.clip(speed+hit*.15,*speed_limits)
        fired |= warn>=3
        if bonuses and not project_done and t>=300:
            ok=project & success & ~fired
            bonus+=np.where(ok & (warn==0),3000*bonus_scale,0)
            warn-=ok & (warn>0)
            speed=np.clip(speed+np.where(project & ~fired,np.where(success,-.15,.10),0),*speed_limits)
            project_done=True
        hit_upper |= speed>=speed_limits[1]-1e-9
        hit_lower |= speed<=speed_limits[0]+1e-9
        previous=seen
    if bonuses:
        chats=rng.integers(0,4,n)
        good=rng.binomial(chats*3,CONFIG['chat_good'])
        bonus+=np.where(~fired,(chats*500+good*200)*bonus_scale,0)
    gross=earned+bonus
    performance=gross-caught*RANK[rk,4]*penalty_scale
    target_ok=(target==0)|(performance>=target)
    quota_ok=work>=quota
    if target_penalty:
        warn+=(~target_ok & ~fired).astype(int)+(~quota_ok & ~fired).astype(int)
    net=RANK[rk,1]+performance
    if target_penalty: net-=np.where(target_ok,0,target*.3)+np.where(quota_ok,0,RANK[rk,5])
    fired |= warn>=3
    net=np.where(fired,0,net)
    return dict(performance=performance,gross=gross,caught=caught,net=net,
                warnings=np.where(fired,0,warn),fired=fired,target_ok=target_ok & ~fired,
                quota_ok=quota_ok,speed=speed,upper=hit_upper,lower=hit_lower,
                seen_seconds=visibility_seconds,work_seconds=busy_seconds,elapsed=elapsed)

def request1(out):
    rows=[]; samples={}
    for vi,p in enumerate(CONFIG['visibility']):
        for r in range(8):
            for typ in range(4):
                d=day(CONFIG['day_samples'],r,typ,p,CONFIG['seed']+r*100+typ+vi*1000)
                s=stats(d['performance'])
                rows.append(dict(rank=RANK_NAMES[r],type=TYPES[typ],visibility=p,n=len(d['net']),
                    **s,ratio=s['mean']/RANK[r,6] if RANK[r,6] else None,
                    target_success=100*np.mean(d['target_ok']),caught=np.mean(d['caught']),
                    net=np.mean(d['net']),fired=100*np.mean(d['fired'])))
                if p==.25: samples[(r,typ)]=d
        print('Q1 visibility',p,flush=True)
    save_csv(out/'q1_income.csv',rows)
    np.savez_compressed(out/'q1_samples.npz',**{f'r{r}_t{t}_{k}':v for (r,t),d in samples.items() for k,v in d.items()})
    return rows,samples

def request5(out):
    rows=[]
    for typ in range(4):
        for vi,p in enumerate(CONFIG['visibility']):
            for lo,hi in [(.7,2.5),(.5,2.),(.5,1.5)]:
                n=CONFIG['risk_samples']; warnings=np.zeros(n,dtype=int); fired=np.zeros(n,dtype=bool)
                daily=[]
                for wd in range(5):
                    d=day(n,3,typ,p,CONFIG['seed']+typ*100+vi*10+wd,dt=.25,weekday=wd,
                          warnings=warnings,speed_limits=(lo,hi),bonuses=False,target_penalty=False)
                    active=~fired
                    daily.append((wd,d,active.copy()))
                    warnings=np.where(active,d['warnings'],warnings); fired |= d['fired'] & active
                week_fired=100*np.mean(fired)
                for wd,d,active in daily:
                    c=d['caught'][active]
                    rows.append(dict(type=TYPES[typ],visibility=p,low=lo,high=hi,weekday=wd+1,n=int(np.sum(active)),
                        caught=np.mean(c) if len(c) else None,first=100*np.mean(c>=1) if len(c) else None,
                        repeat=100*np.sum(c>=2)/np.sum(c>=1) if np.any(c>=1) else None,repeat_denominator=int(np.sum(c>=1)),
                        week_fired=week_fired,speed_mean=np.mean(d['speed'][active]),speed_p90=np.quantile(d['speed'][active],.9),
                        upper=100*np.mean(d['upper'][active]),lower=100*np.mean(d['lower'][active])))
        print('Q5',TYPES[typ],flush=True)
    save_csv(out/'q5_risk.csv',rows)
    return rows

def request2(out, types=range(4), strategies=('save','spend30','certificates')):
    rows=[]; stays=[]; bankrows=[]
    for typ in types:
        for strategy in strategies:
            n=CONFIG['career_samples']; xp=np.zeros(n); bank=np.zeros(n); rank=np.zeros(n,dtype=int)
            warnings=np.zeros(n,dtype=int); fires=np.zeros(n,dtype=int)
            reached=np.full((n,8),np.nan); reached[:,0]=0; banks=np.full((n,8),np.nan); banks[:,0]=0
            dwell=np.zeros((n,8)); bought=np.zeros((n,6),dtype=bool); early_fires=np.zeros(n,dtype=int)
            prices=np.array([15000,30000,50000,80000,150000,300000]); certxp=prices*.2
            rng=np.random.default_rng(CONFIG['seed']+typ)
            for daynum in range(CONFIG['max_days']):
                active=rank<7
                if not active.any(): break
                if daynum%5==0: warnings[:]=0
                # Same simulator, no aggregate-normal income shortcut; use a batched active population.
                ix=np.flatnonzero(active); rr=rank[ix].copy()
                d=day(len(ix),rr,typ,.25,CONFIG['seed']+10000+typ*1000+daynum,
                      weekday=daynum%5,warnings=warnings[ix])
                dwell[ix,rr]+=1
                fired=d['fired']; fires[ix]+=fired; early_fires[ix]+=fired & (rr<=2)
                pay=d['net'].copy(); extra_xp=np.zeros(len(ix))
                if daynum%5==4:
                    u=rng.random(len(ix)); reward=np.select([u<.15,u<.4,u<.8],[2,1,0],default=-1)
                    review=np.where((rr>=4)&~fired,reward*RANK[rr,1],0)
                    pay+=review; extra_xp=np.maximum(review,0)
                bank[ix]=np.maximum(0,bank[ix]+pay)
                xp[ix]+=(np.maximum(pay,0)+extra_xp)*CONFIG['xp_gain_scale']
                if strategy=='spend30': bank[ix]=np.maximum(0,bank[ix]-.3*np.maximum(pay,0))
                warnings[ix]=d['warnings']
                if strategy=='certificates':
                    for c in range(6):
                        can=active & ~bought[:,c] & (bank>=prices[c]); bought[can,c]=True
                        bank[can]-=prices[c]; xp[can]+=certxp[c]
                dead=ix[fired]; rank[dead]=np.maximum(0,rr[fired]-1); xp[dead]=RANK[rank[dead],0]; bank[dead]=0
                living=ix[~fired]; rank[living]=np.minimum(7,np.searchsorted(RANK[:,0],xp[living],side='right')-1)
                if CONFIG['promotion_resets_warnings']:
                    promoted=rank[living]>rr[~fired]; warnings[living[promoted]]=0
                for r in range(1,8):
                    new=(rank>=r)&np.isnan(reached[:,r]); reached[new,r]=daynum+1; banks[new,r]=bank[new]
            done=~np.isnan(reached[:,7]); durations=reached[done,7]
            rows.append(dict(type=TYPES[typ],strategy=strategy,n=n,reached_pct=100*np.mean(done),
                days_mean=float(np.mean(durations)) if len(durations) else None,
                days_p10=float(np.quantile(durations,.1)) if len(durations) else None,
                days_p90=float(np.quantile(durations,.9)) if len(durations) else None,
                hours=float(np.mean(durations)*7.5/60) if len(durations) else None,
                deputy_hours=float(np.nanmean(reached[:,3])*7.5/60),fires=float(np.mean(fires)),
                early_stuck_pct=100*np.mean((early_fires>=2)&np.isnan(reached[:,3])),censored=int(np.sum(~done))))
            for r in range(8):
                visited=~np.isnan(reached[:,r])
                stays.append(dict(type=TYPES[typ],strategy=strategy,rank=RANK_NAMES[r],n=int(np.sum(visited)),
                    dwell_mean=float(np.mean(dwell[visited,r])) if visited.any() else None,dwell_median=float(np.median(dwell[visited,r])) if visited.any() else None,
                    definition='total residence including repeat demotions; includes censored trajectories'))
                if strategy=='save': bankrows.append(dict(type=TYPES[typ],rank=RANK_NAMES[r],mean=float(np.nanmean(banks[:,r])) if visited.any() else None,median=float(np.nanmedian(banks[:,r])) if visited.any() else None))
            print('Q2',TYPES[typ],strategy,flush=True)
    save_csv(out/'q2_careers.csv',rows); save_csv(out/'q2_residence.csv',stays); save_csv(out/'q2_banks.csv',bankrows)
    return rows

def request3(out,samples):
    rows=[]; n=CONFIG['review_samples']; rng=np.random.default_rng(CONFIG['seed']+30000)
    kinds=np.array([0,0,1,1,2,2,3,3,4]); base=np.array([82,80.5,80.5,73.5,68.5]); swing=np.array([3,5,5,11,7]); growth=np.array([0,0,0,0,2.5]); propensity=np.array([1,1.4,1,.6,.5])
    for typ in range(4):
        for scene in range(6):
            friendship=np.zeros((n,9))
            if scene==1: friendship=rng.uniform(10,45,(n,9))
            if scene==2: friendship=rng.uniform(40,90,(n,9))
            if scene==3: friendship=rng.uniform(-70,-10,(n,9))
            if scene==4: friendship[:,:3]=50
            if scene==5: friendship[:]=5; friendship[:,0]=-40
            peer=np.select([friendship>=40,friendship>=20,friendship>-20,friendship>-60],[4,3.2,2.3,1.15],default=0).mean(axis=1)*5
            indices=np.argsort(rng.random((n,9)),axis=1)[:,:3]; k=kinds[indices]; f=np.take_along_axis(friendship,indices,axis=1)
            npc_sum=np.zeros((n,3)); mine_sum=np.zeros(n); tally=np.zeros(n); attempts=np.zeros(n); stolen=np.zeros((n,3),dtype=bool)
            previous_rank=np.ones(n,dtype=int)*4
            d=samples[(4,typ)]
            for wd in range(5):
                ix=rng.integers(0,len(d['net']),n); ratio=d['gross'][ix]/2850
                perf=np.where(ratio<1,24*ratio,24+16*np.minimum(1,(ratio-1)/2.5))
                attendance=np.maximum(0,20-6*(rng.random(n)<CONFIG['late_arrival'])-5*(rng.random(n)<CONFIG['lunch_late'])-8*(~d['quota_ok'][ix]))
                att=np.maximum(0,20-8*d['caught'][ix])
                away=rng.random(n)<.08
                npc=np.clip(base[k]+CONFIG['npc_score_offset']+rng.uniform(-1,1,(n,3))*swing[k]+growth[k]*wd+away[:,None]*np.select([k==2,k==3],[-8,4],0),30,98)
                npc-=3*(rng.random((n,3))<.5)
                singled=rng.integers(0,3,n); npc[np.arange(n),singled]-=3*(rng.random(n)<.25)
                if wd==0:
                    provisional=perf+attendance+att+peer
                    previous_rank=1+np.sum(npc>=provisional[:,None],axis=1)
                chance=np.select([f<=-60,f<=-20,(f<20)&(previous_rank[:,None]<=2)],[.75,.5,.3],0)*propensity[k]*(.5 if wd in (2,3) else 1)
                order=np.argsort(rng.random((n,3)),axis=1); initiated=np.zeros(n,dtype=bool)
                for j in range(3):
                    whom=order[:,j]; hit=(rng.random(n)<chance[np.arange(n),whom])&~initiated
                    attempts+=hit
                    success=hit&(rng.random(n)<.6); false=hit&~success&(rng.random(n)<.5)
                    att=np.maximum(0,att-success*3-(success&(rng.random(n)<.35))*8)
                    npc[np.arange(n),whom]-=false*5
                    initiated|=hit; tally+=success
                theft=(f<=-60)&~stolen&(rng.random((n,3))<.35); stolen|=theft
                perf=np.maximum(0,perf-theft.sum(axis=1)*3); npc+=theft*3
                npc_sum+=npc; mine_sum+=perf+attendance+att
                previous_rank=1+np.sum(npc_sum/(wd+1)>=(mine_sum/(wd+1)+peer)[:,None],axis=1)
            mine=mine_sum/5+peer+2*np.any(f>=85,axis=1); npc=npc_sum/5
            position=1+np.sum(npc>=mine[:,None],axis=1)
            rows.append(dict(type=TYPES[typ],friendship=scene,n=n,**{f'rank{i}':100*np.mean(position==i) for i in range(1,5)},
                score=np.mean(mine),best_npc=np.mean(npc.max(axis=1)),tattles=np.mean(tally),tattles_started=np.mean(attempts)))
    save_csv(out/'q3_review.csv',rows)
    return rows

def request4(out):
    rows=[]; distributions=[]; n=CONFIG['friend_samples']
    for strategy in ['focus1','spread3','all9','report_weekly']:
        for chats in [2,4,6]:
            for gifts in CONFIG['gift_budgets']:
                rng=np.random.default_rng(CONFIG['seed']+40000+chats*10+gifts)
                f=np.zeros((n,9)); last=np.zeros((n,9)); first=np.full((n,4),np.nan)
                all40=np.full(n,np.nan); targets=1 if strategy in ('focus1','report_weekly') else 3 if strategy=='spread3' else 9
                for d in range(1,61):
                    # Focus means extra daily slots cannot be spent on the same NPC.
                    order=np.argsort(f[:,:targets]+rng.random((n,targets))*.01,axis=1)
                    a=np.arange(n)[:,None]
                    cc=order[:,:min(chats,targets)]
                    active=np.ones(cc.shape,dtype=bool); gain=np.zeros(cc.shape)
                    for turn in range(3):
                        u=rng.random(cc.shape); bad=active&(u<CONFIG['chat_bad'])
                        gain+=active&(u>=CONFIG['chat_bad'])&(u<CONFIG['chat_bad']+CONFIG['chat_good'])
                        gain-=bad*4; active&=~bad
                    gain+=active*3
                    f[a,cc]+=gain; last[a,cc]=d
                    gg=order[:,:min(gifts,targets)]
                    f[a,gg]+=(12 if (d-1)%5==3 else 6)*CONFIG['gift_scale']; last[a,gg]=d
                    helpmask=rng.random(n)<CONFIG['help_chance']; helper=rng.integers(0,9,n)
                    f[np.arange(n),helper]+=helpmask*10
                    if strategy=='report_weekly' and d%5==0:
                        f[:,0]-=25
                        witnesses=np.argsort(rng.random((n,8)),axis=1)[:,:3]+1
                        count=rng.integers(0,4,n)
                        for j in range(3): f[np.arange(n),witnesses[:,j]]-=5*(count>j)
                    f-=((f>=65)&(d-last>=3))
                    f=np.clip(f,-100,100)
                    # Threshold metric: every intentionally targeted NPC has reached it.
                    for j,threshold in enumerate([20,40,65,85]):
                        new=np.isnan(first[:,j])&(f[:,:targets].min(axis=1)>=threshold); first[new,j]=d
                    new=np.isnan(all40)&(f.min(axis=1)>=40); all40[new]=d
                    if d in (30,60):
                        for npc in range(9):
                            distributions.append(dict(strategy=strategy,chats=chats,gifts=gifts,day=d,npc=npc+1,**stats(f[:,npc]),below_minus20=100*np.mean(f[:,npc]<-20)))
                for j,threshold in enumerate([20,40,65,85]):
                    hit=first[:,j][~np.isnan(first[:,j])]
                    rows.append(dict(strategy=strategy,chats=chats,gifts=gifts,threshold=threshold,n=n,
                        reached_pct=100*len(hit)/n,days_mean=np.mean(hit) if len(hit) else None,
                        days_median=np.median(hit) if len(hit) else None,
                        all9_40_by20_pct=100*np.mean(all40<20),below_minus20_count60=np.mean((f<-20).sum(axis=1)),
                        definition='all targeted NPCs; unreached censored at 60 days'))
    save_csv(out/'q4_friendships.csv',rows); save_csv(out/'q4_distributions.csv',distributions)
    return rows

def request6(out):
    from collections import Counter
    rows=[]; pairsrows=[]; n=CONFIG['event_weeks']; rng=np.random.default_rng(CONFIG['seed']+60000)
    # From the neutral-normal Q3 run; report this dependency explicitly.
    q3=list(csv.DictReader((out/'q3_review.csv').open(encoding='utf-8-sig')))
    tattle=float(next(x['tattles'] for x in q3 if x['type']==TYPES[1] and x['friendship']=='0'))/5/.6
    tattle=min(1,tattle)
    for rank in ['대리','과장']:
        pairs=Counter()
        for wd in range(5):
            counts=[]; nonwatch=[]; overlaps=[]; quiet_means=[]; quiet_max=[]
            for _ in range(n):
                events=[]
                def event(name,start,length): events.append((name,float(start),min(420.,float(start+length*CONFIG['event_duration_scale']))))
                if rng.random()<.5: event('돌발',rng.uniform(40*420/540,390),rng.uniform(30,90))
                if rng.random()<CONFIG['project_chance']: event('프로젝트',rng.uniform(0,370*420/540),rng.uniform(60,90))
                t=rng.uniform(45,80)*CONFIG['watch_interval_scale']
                while t<420:
                    event('창가감시',t,10); t+=rng.uniform(45,80)*CONFIG['watch_interval_scale']
                for _ in range(rng.integers(0,3)): event('고양이',rng.uniform(0,390),30)
                tt=None
                if rank=='대리' and wd in (2,3):
                    tt=rng.uniform(60*420/540,480*420/540); event('이과장',tt,0)
                if rank=='과장' and rng.random()<tattle:
                    tt=rng.uniform(60*420/540,480*420/540); event('동료고자질',tt,15)
                if rng.random()<.35:
                    ht=rng.uniform(0,375)
                    while tt is not None and abs(ht-tt)<420/9: ht=rng.uniform(0,375)
                    event('도움요청',ht,45)
                if CONFIG['video_fraction']>0:
                    for vt in np.arange(30,420,30):
                        if rng.random()<CONFIG['video_fraction']: event('화상질문',vt,5)
                counts.append(len(events)); nonwatch.append(sum(e[0]!='창가감시' for e in events))
                points=sorted({0.,420.,*(v for _,a,b in events for v in (a,b))})
                overlap=0.; quiet=[]; q=0.
                for a,b in zip(points,points[1:]):
                    active=[name for name,s,e in events if s<=a and e>=b and e>s]
                    if not active: q+=b-a
                    else:
                        if q: quiet.append(q); q=0.
                        if len(active)>1: overlap+=b-a
                if q: quiet.append(q)
                overlaps.append(overlap/420*100); quiet_means.append(np.mean(quiet) if quiet else 0); quiet_max.append(max(quiet,default=0))
                for i,(name,a,b) in enumerate(events):
                    for other,c,d in events[i+1:]:
                        if min(b,d)>max(a,c): pairs[tuple(sorted([name,other]))]+=1
            rows.append(dict(rank=rank,weekday=wd+1,weeks=n,events=np.mean(counts),excluding_watch=np.mean(nonwatch),quiet_mean=np.mean(quiet_means),quiet_longest_mean=np.mean(quiet_max),quiet_longest_observed=max(quiet_max),overlap_pct=np.mean(overlaps),tattle_daily_probability=tattle if rank=='과장' else None))
        for pair,count in pairs.most_common(5): pairsrows.append(dict(rank=rank,pair=' + '.join(pair),overlap_occurrences=count,per_day=count/(5*n)))
        print('Q6',rank,flush=True)
    save_csv(out/'q6_events.csv',rows); save_csv(out/'q6_pairs.csv',pairsrows)
    return rows

def request7(out):
    rows=[]; n=CONFIG['item_samples']
    items=[('plant',2000,7,0),('screen',6000,5,0),('radar',9000,5,0),('energy',1500,1,0),('boss_coffee',1000,1,0)]
    for r in [1,3,4,6]:
        for typ in range(4):
            seed=CONFIG['seed']+70000+r*10+typ
            base=day(n,r,typ,seed=seed)
            choices=items+[(name,price,1,minutes*420/540) for name,price,minrank in [('trip',30000,4),('sleep_coffee',6000,3)] if r>=minrank for minutes in [10,120,300]]
            for name,price,expiry,use in choices:
                d=day(n,r,typ,seed=seed,item=(name,use))
                delta=d['net']-base['net']; value=float(np.mean(delta))
                rows.append(dict(rank=RANK_NAMES[r],type=TYPES[typ],item=name,use_second=use,n=n,price=price,expiry=expiry,daily_gain=value,total_gain=value*expiry,profit=value*expiry-price,break_even_days=price/value if value>0 else None,paired_se=np.std(delta,ddof=1)/np.sqrt(n),status='계산: independent daily expectation x expiry; not a weekly warning trajectory'))
            for name,price,expiry in [('attendance_doll',12000,5),('mannequin',60000,5)]:
                rows.append(dict(rank=RANK_NAMES[r],type=TYPES[typ],item=name,price=price,expiry=expiry,daily_gain=0,total_gain=0,profit=-price,status='계산: 착석 전략에서 효과 0; 외출 전략의 가치는 식별 불가'))
            rows.append(dict(rank=RANK_NAMES[r],type=TYPES[typ],item='warning_coupon',price=50000,expiry=1,status='조건부 시나리오는 q7_coupon_scenarios.csv 참조',conditional_formula='bank + demotion_recovery_days * daily_income - 50000'))
            rows.append(dict(rank=RANK_NAMES[r],type=TYPES[typ],item='halfday',price=40000,expiry=1,profit=-float(np.mean(base['net']))-40000,status='계산: 금전 수입만; 해고 예방 가치는 별도'))
            if r>=4: rows.append(dict(rank=RANK_NAMES[r],type=TYPES[typ],item='corporate_card',price=0,expiry=1,profit=2000,break_even_days=0,status='계산: 지정된 첫 구매 2000원 대체'))
        print('Q7',RANK_NAMES[r],flush=True)
    save_csv(out/'q7_items.csv',rows)
    return rows

def main():
    p=argparse.ArgumentParser(); p.add_argument('--out',type=Path,default=Path('docs/simulation/results'))
    p.add_argument('--requests',default='1,5,2,3,4,6,7'); p.add_argument('--smoke',action='store_true')
    a=p.parse_args(); a.out.mkdir(parents=True,exist_ok=True)
    if a.smoke:
        for k in ('day_samples','career_samples','review_samples','friend_samples','risk_samples','event_weeks','item_samples'): CONFIG[k]=50
    (a.out/'assumptions.json').write_text(json.dumps(ASSUMPTIONS,ensure_ascii=False,indent=2))
    (a.out/'config.json').write_text(json.dumps(CONFIG,ensure_ascii=False,indent=2))
    samples=None
    for q in a.requests.split(','):
        start=time.time()
        if q=='1': _,samples=request1(a.out)
        elif q=='3':
            if samples is None:
                z=np.load(a.out/'q1_samples.npz')
                samples={(r,t):{k.split('_',2)[2]:z[k] for k in z.files if k.startswith(f'r{r}_t{t}_')} for r in range(8) for t in range(4)}
            request3(a.out,samples)
        else: globals()['request'+q](a.out)
        print('Finished Q'+q,round(time.time()-start,1),'seconds',flush=True)

if __name__=='__main__': main()
