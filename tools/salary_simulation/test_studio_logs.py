import json,tempfile,unittest
from pathlib import Path
from tools.salary_simulation.studio_logs import extract

class StudioLogsTests(unittest.TestCase):
 def test_v4_validity_conditions_and_navigation_are_preserved(self):
  samples=[json.loads(s) for s in Path('docs/simulation/v4/raw/studio_01.jsonl').read_text().splitlines() if json.loads(s).get('kind')=='sample']
  sample=dict(samples[-1],day=1)
  rows=[{'kind':'session','settings':{'protocol':'v3'}},sample,
        {'kind':'session','settings':{'protocol':'v4-fast-sight-validity'}},sample,
        {'kind':'day_conditions','day':1,'weekday':'월요일','rank':2,'eventToday':'workshop'},
        {'kind':'day_validity','day':1,'valid':False,'reasons':['forced_scenario']},
        *[{'kind':k,'day':1,'position':[1,2,3]} for k in ('navigation_done','nav_stuck','navigation_seat_missing')]]
  with tempfile.TemporaryDirectory() as tmp:
   base=Path(tmp); (base/'fixtureStudio.log').write_text('\n'.join('SALARY_SIM '+json.dumps(r) for r in rows))
   result=extract(base,base/'out','v4-fast-sight-validity')
   self.assertEqual(len(result),1)
   self.assertFalse(result[0]['valid']); self.assertEqual(result[0]['reasons'],['forced_scenario'])
   self.assertEqual(result[0]['start_conditions']['rank'],2)
   self.assertEqual(result[0]['navigation_counts']['nav_stuck'],1)
   self.assertEqual(result[0]['navigation'][0]['position'],[1,2,3])
 def test_missing_validity_is_not_assumed_valid(self):
  with tempfile.TemporaryDirectory() as tmp:
   base=Path(tmp)
   raw=Path('docs/simulation/v4/raw/studio_01.jsonl').read_text()
   (base/'fixtureStudio.log').write_text('\n'.join('SALARY_SIM '+s for s in raw.splitlines() if json.loads(s)['kind'] in ('session','sample')))
   result=extract(base,base/'out','v4-fast-sight-validity')
   self.assertTrue(result)
   self.assertTrue(all(r['valid'] is None for r in result))
 def test_truncated_records_are_preserved_and_ui_recovery_is_session_scoped(self):
  source=[json.loads(s) for s in Path('docs/simulation/v4/raw/studio_01.jsonl').read_text().splitlines()]
  head=source[0]; sample=next(r for r in source if r['kind']=='sample' and r['day']==1)
  with tempfile.TemporaryDirectory() as tmp:
   base=Path(tmp)
   (base/'fixtureStudio.log').write_text('\n'.join('SALARY_SIM '+json.dumps(r) for r in (head,sample))+'\nSALARY_SIM {"truncated":')
   supplement=base/'ui.json'
   item=dict(session_time=head['time']+1,protocol=head['settings']['protocol'],source='observed UI',row=dict(kind='day_summary',day=1,fired=False))
   supplement.write_text(json.dumps([item]))
   self.assertFalse(extract(base,base/'out',supplements=supplement)[0]['complete'])
   item['session_time']=head['time']; supplement.write_text(json.dumps([item]))
   result=extract(base,base/'out',supplements=supplement)[0]
   self.assertTrue(result['complete']); self.assertEqual(result['summary']['_recovered_from'],'observed UI')
   self.assertIn('truncated',(base/'out/studio_01_parse_errors.log').read_text())
if __name__=='__main__': unittest.main()
