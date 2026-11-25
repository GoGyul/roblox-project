"""Model invariants, not a claim of equivalence with Roblox."""
import unittest
import numpy as np
from tools.salary_simulation.run import day, CONFIG, RANK, RATIOS

class ModelTests(unittest.TestCase):
    def test_seed_repeatable(self):
        a=day(100,3,2,seed=123); b=day(100,3,2,seed=123)
        for key in a: np.testing.assert_array_equal(a[key],b[key])

    def test_uninterrupted_work_ledger(self):
        old=RATIOS[0]; lunch=CONFIG['lunch_seconds']
        try:
            RATIOS[0]=0; CONFIG['lunch_seconds']=0
            d=day(40,1,0,seed=12,bonuses=False,target_penalty=False)
            np.testing.assert_allclose(d['gross'],420*2*RANK[1,2])
            np.testing.assert_allclose(d['net'],1600+420*2*RANK[1,2])
            self.assertFalse(d['fired'].any()); self.assertEqual(d['caught'].sum(),0)
        finally: RATIOS[0]=old; CONFIG['lunch_seconds']=lunch

    def test_firing_absorbs_and_zeroes_pay(self):
        d=day(500,3,3,.35,seed=9,dt=.25,warnings=np.full(500,2),bonuses=False,target_penalty=False,detect_scale=10)
        self.assertTrue(d['fired'].any())
        self.assertTrue(np.all(d['caught']<=1))
        self.assertTrue(np.all(d['net'][d['fired']]==0))
        self.assertTrue(np.all(d['elapsed'][d['fired']]<420))

    def test_trip_removes_sight_and_catches(self):
        d=day(500,4,2,.35,seed=10,item=('trip',0),bonuses=False)
        self.assertEqual(d['seen_seconds'].sum(),0)
        self.assertEqual(d['caught'].sum(),0)

    def test_limits_are_respected(self):
        d=day(500,3,3,.35,seed=44,dt=.25,speed_limits=(.7,1.1))
        self.assertTrue(np.all((d['speed']>=.7)&(d['speed']<=1.1)))

if __name__=='__main__': unittest.main()
