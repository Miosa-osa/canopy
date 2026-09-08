"""Adversarial CLI fixtures exercise the same validator invoked by CI."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'agent_control_plane.py'

class IntegrityTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / 'AGENTS.md').write_text('Read `contract.md`.\n')
        (self.root / 'contract.md').write_text('Current contract\n')
        (self.root / 'old.md').write_text('Historical evidence\n')
        self.manifest = {'schema_version': 1, 'documents': [
            dict(id='boot', path='AGENTS.md', kind='normative', status='active', owner='platform', scope='repo', version=1, effective='2026-09-08', owns=['boot'], requires=['contract']),
            dict(id='contract', path='contract.md', kind='contract', status='active', owner='platform', scope='repo', version=1, effective='2026-09-08', owns=['architecture']),
            dict(id='old', path='old.md', kind='historical', status='superseded', owner='platform', scope='repo', version=1, effective='2026-09-08', owns=[], superseded_by='contract')],
            'required_paths': [], 'inventory': [], 'permissions': {'fact_creation': 'review-required'}}
    def run_check(self, expected):
        (self.root / 'agent-authority.json').write_text(json.dumps(self.manifest))
        result = subprocess.run([sys.executable, str(SCRIPT), '--root', str(self.root)], capture_output=True, text=True)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
    def test_clean(self): self.run_check(0)
    def test_missing_authority(self):
        (self.root / 'contract.md').unlink(); self.run_check(1)
    def test_competing_authority(self):
        self.manifest['documents'][0]['owns'] = ['architecture']; self.run_check(1)
    def test_superseded_normative(self):
        self.manifest['documents'][2]['kind'] = 'normative'; self.run_check(1)
    def test_retired_boot_reference(self):
        self.manifest['documents'][0]['requires'] = ['old']; self.run_check(1)
    def test_supersession_cycle(self):
        self.manifest['documents'][1].update(status='superseded', kind='historical', superseded_by='old', owns=[]); self.run_check(1)
    def test_dangling_supersession(self):
        self.manifest['documents'][2]['superseded_by'] = 'absent'; self.run_check(1)
    def test_unregistered_boot_reference(self):
        (self.root / 'AGENTS.md').write_text('Read `missing.md`.'); self.run_check(1)
    def test_historical_cannot_own_current_state(self):
        self.manifest['documents'][2]['owns'] = ['architecture']; self.run_check(1)
    def test_inventory_new_document(self):
        self.manifest['inventory'] = ['*.md']; (self.root / 'new.md').write_text('New authority'); self.run_check(1)
    def test_missing_command(self):
        self.manifest['required_paths'] = ['bin/missing']; self.run_check(1)
    def test_outside_root(self):
        self.manifest['documents'][1]['path'] = '../contract.md'; self.run_check(1)
    def test_malformed(self):
        self.manifest['documents'][0].pop('owner'); self.run_check(1)

    def test_textual_retired_boot_reference(self):
        (self.root / 'AGENTS.md').write_text('Read `old.md`.'); self.run_check(1)
    def test_current_document_cannot_have_supersession(self):
        self.manifest['documents'][1]['superseded_by'] = 'boot'; self.run_check(1)
    def test_authority_dependency_cycle(self):
        self.manifest['documents'][1]['requires'] = ['boot']; self.run_check(1)
    def test_boolean_schema_version(self):
        self.manifest['schema_version'] = True; self.run_check(1)
    def test_non_list_requires(self):
        self.manifest['documents'][0]['requires'] = {}; self.run_check(1)
    def test_empty_permission_value(self):
        self.manifest['permissions']['fact_creation'] = ''; self.run_check(1)
    def test_alias_document_path(self):
        self.manifest['documents'][1]['path'] = './contract.md'; self.run_check(1)
    def test_markdown_reference_link_missing(self):
        (self.root / 'AGENTS.md').write_text('Read [contract][required].\n[required]: missing.md\n'); self.run_check(1)
    def test_inline_link_with_title_missing(self):
        (self.root / 'AGENTS.md').write_text('Read [contract](missing.md "Required").'); self.run_check(1)
    def test_inline_code_fragment_missing(self):
        (self.root / 'AGENTS.md').write_text('Read `missing.md#authority`.'); self.run_check(1)
    def test_normative_reference_checks_cannot_be_disabled(self):
        self.manifest['documents'][0]['check_references'] = False
        (self.root / 'AGENTS.md').write_text('Read `missing.md`.'); self.run_check(1)

    def test_duplicate_json_keys(self):
        raw = json.dumps(self.manifest).replace('"schema_version": 1', '"schema_version": 9, "schema_version": 1')
        (self.root / 'agent-authority.json').write_text(raw)
        result = subprocess.run([sys.executable, str(SCRIPT), '--root', str(self.root)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('duplicate JSON key', result.stderr)
    def test_symlink_alias_authority(self):
        (self.root / 'alias.md').symlink_to(self.root / 'contract.md')
        self.manifest['documents'].append(dict(self.manifest['documents'][1], id='alias', path='alias.md', owns=['other']))
        self.run_check(1)

    def test_current_contract_references_are_checked(self):
        (self.root / 'contract.md').write_text('Read `missing.md`.'); self.run_check(1)
    def test_contract_checks_cannot_be_disabled(self):
        self.manifest['documents'][1]['check_references'] = False; self.run_check(1)
    def test_plain_boot_reference(self):
        (self.root / 'AGENTS.md').write_text('Before work, read missing.md.'); self.run_check(1)
    def test_plain_contract_reference(self):
        (self.root / 'contract.md').write_text('Before work, read missing.md.'); self.run_check(1)
    def test_external_and_fenced_example_are_not_local_references(self):
        (self.root / 'contract.md').write_text('See https://example.invalid/remote.md.\n```text\nexample.md\n```\n')
        self.run_check(0)
    def test_contract_relative_reference(self):
        (self.root / 'docs').mkdir()
        (self.root / 'contract.md').rename(self.root / 'docs' / 'contract.md')
        self.manifest['documents'][1]['path'] = 'docs/contract.md'
        (self.root / 'AGENTS.md').write_text('Read docs/contract.md.')
        (self.root / 'docs' / 'contract.md').write_text('Read ../AGENTS.md.')
        self.run_check(0)

if __name__ == '__main__': unittest.main()
