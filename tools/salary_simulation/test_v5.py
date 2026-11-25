import io
import json
import unittest
from tools.salary_simulation.studio_logs import read_records, record_integrity
from tools.salary_simulation.v5_check import analyze, PROTOCOL


def frames(row):
    data = json.dumps(row, ensure_ascii=False).encode()
    return [dict(kind='log_chunk', id='test', index=i//240+1,
                 count=(len(data)+239)//240, bytes=len(data), payload=data[i:i+240].hex())
            for i in range(0, len(data), 240)]


def decode(rows):
    return list(read_records(io.StringIO('\n'.join('SALARY_SIM '+json.dumps(r) for r in rows))))


def fixture(delay=1, overhead=.1, late=False):
    rows = [dict(kind='session', settings=dict(protocol=PROTOCOL)),
            dict(kind='environment', meshFallback=False),
            dict(kind='sight_signal', time=10, visible=True),
            dict(kind='reaction_start', time=10.1, reactionId=1),
            dict(kind='reaction_request', time=10.6, reactionId=1, previousAction='phone', late=late),
            dict(kind='return_requested', time=10.62, action='phone', expectedReturnSeconds=delay, caught=0, playerId=1),
            dict(kind='observed_state', time=10.6+delay+overhead, state='work', caught=0, playerId=1),
            dict(kind='day_conditions'), dict(kind='day_validity', valid=True),
            dict(kind='day_summary', today=dict(nearMissCount=1, nearMiss=100)),
            dict(kind='near_miss_award', amount=100), dict(kind='payslip'),
            dict(kind='complete', requestedDays=1)]
    return [dict(r, day=1) for r in rows]


class V5Tests(unittest.TestCase):
    def test_utf8_reordered_transport(self):
        row = dict(kind='test', text='한글 경계 🧪 '*100)
        result = decode(list(reversed(frames(row))))
        self.assertEqual([r for r, _, _ in result if r], [row])
        self.assertFalse(any(f for _, _, f in result))

    def test_missing_duplicate_corrupt_fail(self):
        chunks = frames(dict(kind='test', text='한글'*300))
        for rows in (chunks[:-1], [chunks[0]]+chunks, [dict(chunks[0], payload='zz')]+chunks[1:]):
            result = decode(rows)
            self.assertTrue(any(f for _, _, f in result))
            self.assertFalse(any(r for r, _, _ in result))

    def test_entire_missing_day(self):
        self.assertEqual(len(record_integrity([dict(kind='complete', requestedDays=5)])), 5)
        self.assertTrue(all(len(r['missing'])==4 for r in record_integrity([dict(kind='complete', requestedDays=5)])))

    def test_separate_timings_new_criteria(self):
        result = analyze(fixture())
        self.assertTrue(result['gates']['request_reaction'])
        self.assertTrue(result['gates']['action_return'])
        self.assertAlmostEqual(result['ordinary']['sight_to_work'], 1.7)
        self.assertNotIn('actual_work_reaction', result['gates'])
        self.assertTrue(result['passed'])

    def test_item_modifier_and_slow_return(self):
        self.assertTrue(analyze(fixture(.25))['gates']['action_return'])
        self.assertFalse(analyze(fixture(.25, .6))['gates']['action_return'])

    def test_late_separate_and_catch_excluded(self):
        self.assertEqual(analyze(fixture(late=True))['late']['n'], 1)
        rows = fixture(); rows[6]['caught'] = 1
        self.assertEqual(analyze(rows)['transitions'][0]['excluded'], 'catch_intervened')

    def test_missing_evidence_and_bonus_mismatch(self):
        rows = fixture(); rows.pop(5)
        self.assertFalse(analyze(rows)['gates']['transitions_accounted'])
        rows = fixture(); rows[10]['amount'] = 200
        self.assertFalse(analyze(rows)['gates']['bonus_records'])
        self.assertFalse(analyze(fixture(), parse_errors=1)['gates']['records_complete'])

    def test_return_gate_uses_median_not_max(self):
        rows = fixture()
        for day, overhead in ((2, .15), (3, .7)):
            extra = fixture(overhead=overhead)
            for row in extra:
                row['day'] = day
                if 'time' in row: row['time'] += day * 100
                if 'reactionId' in row: row['reactionId'] = day
            rows.extend(r for r in extra if r['kind'] not in ('session', 'complete'))
        rows = sorted(rows, key=lambda r: r.get('time', 0))
        # Session must be the first record for protocol verification.
        rows = [r for r in rows if r['kind']=='session'] + [r for r in rows if r['kind']!='session']
        result = analyze(rows)
        self.assertTrue(result['gates']['action_return'])
        self.assertAlmostEqual(result['return_overhead_median'], .15)
        self.assertTrue(any(not r['return_within_tolerance'] for r in result['transitions']))

    def test_action_interruption_is_explicit_and_not_zero_latency(self):
        rows = fixture(); rows[6].update(state='phone', action='phone')
        rows[5]['action']='shopping'; rows[4]['previousAction']='shopping'
        result = analyze(rows)
        self.assertEqual(result['transitions'][0]['excluded'], 'nonwork_resumed_before_work_observed')
        self.assertEqual(result['ordinary']['request_n'], 1)
        self.assertEqual(result['ordinary']['n'], 0)
        self.assertIsNone(result['ordinary']['request_to_work'])
        self.assertFalse(result['gates']['action_return'])

    def test_old_protocol_rejected(self):
        rows = fixture(); rows[0]['settings']['protocol'] = 'v4-fast-sight-validity'
        with self.assertRaises(ValueError): analyze(rows)

if __name__ == '__main__': unittest.main()
