"""Retained adversarial expectations for the trusted-baseline harness."""
import copy
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('trusted_control_plane', ROOT / 'scripts/trusted_control_plane.py')
harness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(harness)


class TrustedBaselineTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.trusted = Path(self.tmp.name) / 'trusted'
        self.candidate = Path(self.tmp.name) / 'candidate'
        shutil.copytree(ROOT / 'evidence/control-plane/fixtures/known-good', self.trusted)
        for name in (harness.VALIDATOR, harness.TESTS):
            target = self.trusted / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, target)
        shutil.copytree(ROOT / 'evidence', self.trusted / 'evidence')
        shutil.copytree(self.trusted, self.candidate)

    def evaluate(self):
        return harness.evaluate(self.trusted, self.candidate)

    def test_valid_candidate_replays_trusted_tests_and_exact_fixtures(self):
        report = self.evaluate()
        self.assertTrue(report['passed'], report['errors'])
        self.assertIn('trusted-tests-on-candidate-validator', [r['name'] for r in report['checks']])
        self.assertIn(harness.TESTS, report['trusted_sha256'])

    def test_permissive_checker_and_all_success_candidate_tests_do_not_pass(self):
        shutil.copy2(self.candidate / 'evidence/control-plane/fixtures/missing-boot-contract/permissive-checker.py', self.candidate / harness.VALIDATOR)
        shutil.copy2(self.candidate / 'evidence/control-plane/fixtures/missing-boot-contract/all-success-tests.py', self.candidate / harness.TESTS)
        report = self.evaluate()
        self.assertFalse(report['passed'])
        self.assertIn('trusted regression expectations failed or no tests executed', report['errors'])
        self.assertIn('candidate fixture expectation failed: missing-boot-contract', report['errors'])
        self.assertEqual(report['incidents'][0]['classification'], 'known-failure-recurrence')
        self.assertEqual(report['incidents'][0]['category'], 'process-defect')

    def test_trusted_validator_rejects_candidate_registry_even_if_candidate_accepts(self):
        (self.candidate / 'docs/current-product-contract.md').unlink()
        shutil.copy2(self.candidate / 'evidence/control-plane/fixtures/missing-boot-contract/permissive-checker.py', self.candidate / harness.VALIDATOR)
        report = self.evaluate()
        self.assertIn('trusted validator rejected candidate registry', report['errors'])

    def test_missing_baseline_or_empty_trusted_tests_fails_closed(self):
        (self.trusted / harness.LEDGER).unlink()
        self.assertFalse(self.evaluate()['passed'])
        shutil.copy2(self.candidate / harness.LEDGER, self.trusted / harness.LEDGER)
        (self.trusted / harness.TESTS).write_text('')
        self.assertFalse(self.evaluate()['passed'])

    def test_deletion_of_negative_evidence_is_rejected(self):
        path = self.candidate / harness.LEDGER
        data = json.loads(path.read_text())
        data['records'] = data['records'][:1]
        path.write_text(json.dumps(data))
        self.assertFalse(self.evaluate()['passed'])

    def test_evidence_rewrite_cannot_be_hidden_by_rehashing(self):
        path = self.candidate / harness.LEDGER
        data = json.loads(path.read_text())
        record = data['records'][0]
        name = next(n for n in record['sha256'] if n.endswith('contract.md'))
        (self.candidate / name).write_text('Changed causal evidence\n')
        record['sha256'][name] = harness.digest(self.candidate / name)
        path.write_text(json.dumps(data))
        self.assertIn('retained evidence deleted or rewritten', ' '.join(self.evaluate()['errors']))

    def test_hash_mismatch_is_rejected(self):
        path = self.candidate / 'evidence/control-plane/fixtures/known-good/docs/current-product-contract.md'
        path.write_text('Evidence lost\n')
        self.assertIn('evidence hash changed', ' '.join(self.evaluate()['errors']))

    def test_explicit_additive_supersession_retains_prior_evidence(self):
        path = self.candidate / harness.LEDGER
        data = json.loads(path.read_text())
        replacement = copy.deepcopy(data['records'][0])
        replacement.update(id='known-good-followup', supersedes='known-good',
                           retained_reason='Follow-up review retains unchanged exact positive fixture.')
        data['records'].append(replacement)
        path.write_text(json.dumps(data))
        report = self.evaluate()
        self.assertTrue(report['passed'], report['errors'])

    def test_bootstrap_is_explicit_and_still_runs_prior_trusted_tests(self):
        (self.trusted / harness.LEDGER).unlink()
        report = harness.evaluate(self.trusted, self.candidate, bootstrap_ledger=True)
        self.assertTrue(report['passed'], report['errors'])
        self.assertEqual(report['evidence_status'], 'pending-independent-bootstrap')
        shutil.copy2(self.candidate / 'evidence/control-plane/fixtures/missing-boot-contract/permissive-checker.py', self.candidate / harness.VALIDATOR)
        self.assertFalse(harness.evaluate(self.trusted, self.candidate, bootstrap_ledger=True)['passed'])

    def test_bootstrap_cannot_override_existing_trusted_ledger(self):
        self.assertFalse(harness.evaluate(self.trusted, self.candidate, bootstrap_ledger=True)['passed'])

    def test_boolean_schema_and_unstructured_red_team_record_are_rejected(self):
        path = self.candidate / harness.LEDGER
        original = json.loads(path.read_text())
        for mutation in ['boolean-schema', 'unstructured-review', 'missing-review-field']:
            data = copy.deepcopy(original)
            if mutation == 'boolean-schema':
                data['schema_version'] = True
            elif mutation == 'unstructured-review':
                data['records'][0]['red_team_record'] = 'Generic summary'
            else:
                del data['records'][0]['red_team_record']['strongest_against']
            path.write_text(json.dumps(data))
            self.assertFalse(self.evaluate()['passed'], mutation)

    def test_symlink_parent_is_not_immutable_evidence(self):
        target = self.candidate / 'evidence/control-plane/fixtures/known-good'
        moved = self.candidate / 'aliased-fixture'
        target.rename(moved)
        target.symlink_to(moved, target_is_directory=True)
        self.assertIn('symlink evidence path', ' '.join(self.evaluate()['errors']))

    def test_new_bootstrap_fixture_failure_is_discovery_not_recurrence(self):
        (self.trusted / harness.LEDGER).unlink()
        shutil.copy2(self.candidate / 'evidence/control-plane/fixtures/missing-boot-contract/permissive-checker.py', self.candidate / harness.VALIDATOR)
        report = harness.evaluate(self.trusted, self.candidate, bootstrap_ledger=True)
        self.assertEqual(report['incidents'][0]['classification'], 'discovery')

    def test_cli_provenance_rejects_non_git_dirty_and_wrong_revision(self):
        with self.assertRaises(ValueError):
            harness.require_clean_checkout(self.candidate)
        subprocess.run(['git', 'init', '-q', str(self.candidate)], check=True)
        subprocess.run(['git', 'add', '.'], cwd=self.candidate, check=True)
        subprocess.run(['git', '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                        'commit', '-qm', 'Synthetic baseline'], cwd=self.candidate, check=True)
        sha = harness.require_clean_checkout(self.candidate)
        self.assertEqual(harness.require_clean_checkout(self.candidate, sha), sha)
        with self.assertRaisesRegex(ValueError, 'required base SHA'):
            harness.require_clean_checkout(self.candidate, '0' * 40)
        (self.candidate / harness.VALIDATOR).write_text('print("PASS")\n')
        with self.assertRaisesRegex(ValueError, 'clean tracked'):
            harness.require_clean_checkout(self.candidate)
        subprocess.run(['git', 'update-index', '--assume-unchanged', harness.VALIDATOR], cwd=self.candidate, check=True)
        with self.assertRaisesRegex(ValueError, 'differs from committed revision'):
            harness.require_clean_checkout(self.candidate)

    def test_cli_provenance_rejects_untracked_evidence(self):
        subprocess.run(['git', 'init', '-q', str(self.candidate)], check=True)
        subprocess.run(['git', 'add', '.'], cwd=self.candidate, check=True)
        subprocess.run(['git', '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                        'commit', '-qm', 'Synthetic baseline'], cwd=self.candidate, check=True)
        (self.candidate / 'untracked-evidence.json').write_text('{}')
        with self.assertRaisesRegex(ValueError, 'clean tracked'):
            harness.require_clean_checkout(self.candidate)

    def test_trusted_validation_precedes_candidate_execution_and_detects_mutation(self):
        script = f'from pathlib import Path\nPath({str(self.trusted / harness.VALIDATOR)!r}).write_text("print(123)\\n")\n'
        (self.candidate / harness.VALIDATOR).write_text(script)
        report = self.evaluate()
        self.assertEqual(report['checks'][0]['name'], 'trusted-validator-on-candidate-registry')
        self.assertIn('changed during evaluation', ' '.join(report['errors']))

    def test_same_root_is_not_independent_baseline(self):
        self.assertFalse(harness.evaluate(self.candidate, self.candidate)['passed'])


if __name__ == '__main__':
    unittest.main()
