from pathlib import Path
from tools.salary_simulation.report import read, table

def select(rows,filters,key):
    hits=[r for r in rows if all(r.get(k)==v for k,v in filters.items())]
    return float(hits[0][key]) if hits and hits[0].get(key) not in ('','nan') else None

def run():
    income=('visibility_scale','reaction_scale','bonus_scale')
    cases=[
        (1,'사원 보통형 목표달성 %','q1_income.csv',{'rank':'사원','type':'보통형','visibility':'0.25'},'target_success',lambda x:80<=x<=95,income),
        (2,'보통형 이사 도달 시간','q2_careers.csv',{'type':'보통형','strategy':'save'},'hours',lambda x:15<=x<=30,income),
        (3,'중립 보통형 1등 %','q3_review.csv',{'type':'보통형','friendship':'0'},'rank1',lambda x:5<=x<=20,income),
        (4,'집중 +85 평균 일','q4_friendships.csv',{'strategy':'focus1','chats':'4','gifts':'2','threshold':'85'},'days_mean',lambda x:8<=x<=15,('gift_scale','chat_good','help_chance')),
        (4,'전원 +40 평균 일','q4_friendships.csv',{'strategy':'all9','chats':'4','gifts':'2','threshold':'40'},'days_mean',lambda x:x>=20,('gift_scale','chat_good','help_chance')),
        (5,'보통형 주간 해고 %','q5_risk.csv',{'type':'보통형','visibility':'0.25','high':'2.0','weekday':'1'},'week_fired',lambda x:3<=x<=10,('visibility_scale','reaction_scale','visit_mean')),
        (6,'과장 월요일 중첩 %','q6_events.csv',{'rank':'과장','weekday':'1'},'overlap_pct',lambda x:x<=10,('event_duration_scale','watch_interval_scale','project_chance')),
        (7,'과장 보통형 가리개 순이익','q7_items.csv',{'rank':'과장','type':'보통형','item':'screen'},'profit',lambda x:x>=0,income),
    ]
    rows=[]
    for q,label,file,filters,key,test,factors in cases:
        baseline=select(read(file),filters,key)
        for factor in factors:
            values=[]
            for scale in (.7,1.3):
                if q==1:
                    alias={'visibility_scale':'visibility','reaction_scale':'reaction_scale','bonus_scale':'bonus_scale'}[factor]
                    value=select(read('sensitivity_income.csv'),{'rank':'사원','type':'보통형','factor':alias,'scale':str(scale)},key)
                else: value=select(read(f'sensitivity/{factor}_{scale}/{file}'),filters,key)
                values.append(value)
            changed=any(test(v)!=test(baseline) for v in values if v is not None and baseline is not None)
            rows.append(dict(request=q,metric=label,assumption=factor,minus30=values[0],baseline=baseline,plus30=values[1],
                changed='미완료' if any(v is None for v in values) else '판정 바뀜' if changed else '판정 유지'))
    text='# ±30% 민감도 — 대표 판단 기준\n\n각 행은 가정 하나만 바꿉니다. 기본 표본 수를 유지했습니다. 아래 대표 지표 이외의 직급·유형은 해당 폴더의 원본 CSV에서 확인할 수 있습니다. 변화가 작다는 것은 가정이 맞다는 증거가 아닙니다.\n\n'
    text+=table(rows,[('request','요청'),('metric','대표 지표'),('assumption','바꾼 가정'),('minus30','−30%'),('baseline','기준'),('plus30','+30%'),('changed','기준 충족 여부')])
    text+='\nQ2는 보통형 무소비의 조건부 도달 시간입니다. 각 CSV의 도달률을 함께 확인하세요. Q7 대표 지표는 부재 아이템·면제권까지 대표하지 않습니다. 시야 가정의 ±30%는 Q1에서 17.5%/32.5%이며 요청된 별도 15%/35% 표도 보존했습니다.\n'
    Path('docs/simulation/민감도.md').write_text(text)

if __name__=='__main__':run()
