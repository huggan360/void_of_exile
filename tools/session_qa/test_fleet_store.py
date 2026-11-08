"""Fleet transactions against a temporary database, never live accounts."""
import concurrent.futures
import importlib.util
import json
from pathlib import Path
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('void_accounts', ROOT/'account_service/void_accounts.py')
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)

class FleetTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = str(Path(self.temp.name)/'accounts.db')
        self.store = a.Store(self.path)
        self.owner = self.store.create_account('owner', '12345')
        self.other = self.store.create_account('other', '12345')
        self.cid = self.store.create_character(self.owner, 'archer', 5)
        self.other_cid = self.store.create_character(self.other, 'archer', 5)
        self.store.db().execute("UPDATE characters SET lease_server='A',lease_until=?", (time.time()+300,))
        self.store.add_dots(self.owner, 2000)

    def tearDown(self):
        self.store.db().close()
        self.temp.cleanup()

    def action(self, op, **kw):
        return self.store.fleet_action('A', op, character_id=self.cid, **kw)

    def buy(self, key='one'):
        return self.action('buy', request_id=key)['ships'][-1]['id']

    def deployed(self):
        return self.action('deploy', ship_id=self.buy())['deployment']

    def update(self, deployment, op='store', **kw):
        return self.store.fleet_action('A', op, ship_id=deployment['id'], token=deployment['token'], **kw)

    def test_purchase_and_retry_charge_once(self):
        first = self.action('buy', request_id='retry')
        second = self.action('buy', request_id='retry')
        self.assertEqual(first['dots'], 1500)
        self.assertEqual(second['dots'], 1500)
        self.assertEqual(len(second['ships']), 1)

    def test_multiple_owned_ships_have_distinct_ids(self):
        first, second = self.buy('one'), self.buy('two')
        self.assertNotEqual(first, second)
        self.assertEqual(len(self.action('list')['ships']), 2)
        self.assertEqual(self.action('list')['dots'], 1000)

    def test_store_and_redeploy_is_free_and_keeps_damage(self):
        d = self.deployed()
        state = {'hp': 1234, 'parts': {'engines': 42}, 'glasses': [.32, 1, .66, 0]}
        self.update(d, state=state)
        again = self.action('deploy', ship_id=d['id'])
        self.assertEqual(again['dots'], 1500)
        self.assertEqual(again['deployment']['state'], state)
        self.assertEqual(again['deployment']['id'], d['id'])

    def test_in_use_ship_cannot_be_duplicated(self):
        d = self.deployed()
        with self.assertRaises(a.ApiError): self.action('deploy', ship_id=d['id'])

    def test_foreign_account_cannot_deploy(self):
        ship = self.buy()
        with self.assertRaises(a.ApiError):
            self.store.fleet_action('A', 'deploy', character_id=self.other_cid, ship_id=ship)

    def test_wrong_token_or_server_cannot_recall(self):
        d = self.deployed()
        with self.assertRaises(a.ApiError):
            self.store.fleet_action('B', 'store', ship_id=d['id'], token=d['token'])
        with self.assertRaises(a.ApiError):
            self.store.fleet_action('A', 'store', ship_id=d['id'], token='wrong')

    def test_destroyed_ship_stays_lost_and_replacement_costs(self):
        d = self.deployed()
        result = self.update(d, 'destroy', state={'hp': 0})
        self.assertEqual(result['ships'][0]['status'], 'destroyed')
        with self.assertRaises(a.ApiError): self.action('deploy', ship_id=d['id'])
        self.buy('replacement')
        self.assertEqual(self.action('list')['dots'], 1000)

    def test_zero_hull_heartbeat_cannot_resurrect_a_wreck(self):
        d = self.deployed()
        result = self.update(d, 'heartbeat', state={'hp': 0})
        self.assertEqual(result['ships'][0]['status'], 'destroyed')

    def test_crashed_server_recovery_rejects_stale_token(self):
        d = self.deployed()
        self.store.db().execute('UPDATE fleet_ships SET lease_until=0 WHERE id=?', (d['id'],))
        self.assertEqual(self.action('list')['ships'][0]['status'], 'stored')
        fresh = self.action('deploy', ship_id=d['id'])['deployment']
        self.assertNotEqual(fresh['token'], d['token'])
        with self.assertRaises(a.ApiError): self.update(d)

    def test_singleplayer_key_cannot_touch_another_account(self):
        with self.assertRaises(a.ApiError):
            self.store.fleet_action('A', 'list', character_id=self.cid, only_account=self.other)

    def test_legacy_ship_is_migrated_exactly_once(self):
        self.store.save_campaign(self.owner, {'reach_ship': {'name': 'Legacy ship'}, 'runs': {}})
        result = self.action('list')
        self.assertEqual(len(result['ships']), 1)
        self.assertEqual(result['ships'][0]['name'], 'Legacy ship')
        d = self.action('deploy', ship_id=result['ships'][0]['id'])['deployment']
        self.update(d, 'destroy', state={'hp': 0})
        self.assertEqual(len(self.action('list')['ships']), 1)
        self.assertEqual(self.action('list')['ships'][0]['status'], 'destroyed')

    def test_terminal_updates_are_idempotent_after_lost_ack(self):
        d = self.deployed()
        self.update(d, 'store', state={'hp': 1200})
        result = self.update(d, 'store', state={'hp': 1200})
        self.assertEqual(result['ships'][0]['status'], 'stored')
        self.assertEqual(result['dots'], 1500)
        fresh = self.action('deploy', ship_id=d['id'])['deployment']
        self.update(fresh, 'destroy', state={'hp': 0})
        self.assertEqual(self.update(fresh, 'destroy', state={'hp': 0})['ships'][0]['status'], 'destroyed')

    def test_concurrent_deploy_only_one_wins(self):
        ship = self.buy()
        def claim(_):
            store = a.Store(self.path)
            try:
                store.fleet_action('A', 'deploy', character_id=self.cid, ship_id=ship)
                return True
            except a.ApiError: return False
            finally: store.db().close()
        with concurrent.futures.ThreadPoolExecutor(2) as pool:
            self.assertEqual(sum(pool.map(claim, range(2))), 1)

    def test_insufficient_funds_cannot_create_a_ship(self):
        self.store.add_dots(self.other, 499)
        with self.assertRaises(a.ApiError):
            self.store.fleet_action('A', 'buy', character_id=self.other_cid, request_id='no-money')
        self.assertEqual(self.store.db().execute('SELECT COUNT(*) FROM fleet_ships WHERE account_id=?',(self.other,)).fetchone()[0], 0)

if __name__ == '__main__': unittest.main(verbosity=2)
