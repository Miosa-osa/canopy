#!/usr/bin/env python3
"""Evaluate candidate authority with a separately selected trusted checkout.

No network or application startup. This is regression verification, not a sandbox
for malicious Python: CI must use an unprivileged ordinary pull_request runner.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

VALIDATOR = 'scripts/agent_control_plane.py'
TESTS = 'scripts/tests/test_agent_control_plane.py'
LEDGER = 'evidence/control-plane/ledger.json'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def safe(root, name):
    if not isinstance(name, str) or not name or Path(name).is_absolute() or '..' in Path(name).parts:
        raise ValueError(f'unsafe evidence path: {name!r}')
    path = root / name
    current = root
    for part in Path(name).parts:
        current = current / part
        if current.is_symlink():
            raise ValueError(f'symlink evidence path: {name}')
    if path.is_symlink() or not path.resolve().is_relative_to(root.resolve()):
        raise ValueError(f'evidence escapes checkout: {name}')
    if not path.is_file():
        raise ValueError(f'missing required file: {name}')
    return path


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f'duplicate JSON key: {key}')
        result[key] = value
    return result


def ledger(root):
    data = json.loads(safe(root, LEDGER).read_text(), object_pairs_hook=unique_object)
    if type(data.get('schema_version')) is not int or data['schema_version'] != 1 or not data.get('records'):
        raise ValueError('missing supported nonempty evidence ledger')
    records = {}
    for record in data['records']:
        identity = record['id']
        if not isinstance(identity, str) or not identity or identity in records:
            raise ValueError('invalid or duplicate evidence ID')
        for field in ('causal_lesson', 'observed_failure', 'retained_reason'):
            if not isinstance(record.get(field), str) or not record[field].strip():
                raise ValueError(f'{identity}: missing {field}')
        review = record.get('red_team_record')
        if not isinstance(review, dict):
            raise ValueError(f'{identity}: missing structured red-team record')
        for field in ('strongest_for', 'strongest_against', 'assumptions_to_break', 'constraints', 'verdict', 'revisit_condition'):
            if not isinstance(review.get(field), str) or not review[field].strip():
                raise ValueError(f'{identity}: missing red-team field {field}')
        if type(record.get('expected_exit')) is not int or record['expected_exit'] not in (0, 1):
            raise ValueError(f'{identity}: invalid expected exit')
        fixture = record['fixture_root']
        if not isinstance(fixture, str) or not fixture.startswith('evidence/control-plane/fixtures/'):
            raise ValueError(f'{identity}: invalid fixture root')
        files = record['sha256']
        if not isinstance(files, dict) or not files or f'{fixture}/agent-authority.json' not in files:
            raise ValueError(f'{identity}: fixture must retain manifest and hashes')
        for name, expected in files.items():
            if not name.startswith(f'{fixture}/') or not re.fullmatch('[0-9a-f]{64}', expected):
                raise ValueError(f'{identity}: invalid fixture hash')
            if digest(safe(root, name)) != expected:
                raise ValueError(f'{identity}: evidence hash changed: {name}')
        actual = {p.relative_to(root).as_posix() for p in (root / fixture).rglob('*') if p.is_file()}
        if actual != set(files):
            raise ValueError(f'{identity}: unrecorded fixture file or missing evidence')
        records[identity] = record
    if not any(r['expected_exit'] == 0 for r in records.values()) or not any(r['expected_exit'] == 1 for r in records.values()):
        raise ValueError('ledger needs both known-good and known-bad fixtures')
    for identity, record in records.items():
        seen = {identity}
        while record.get('supersedes'):
            prior = record['supersedes']
            if prior not in records or prior in seen:
                raise ValueError('invalid or cyclic evidence supersession')
            seen.add(prior)
            record = records[prior]
    return records


def run(command, cwd):
    result = subprocess.run(command, cwd=cwd, capture_output=True, text=True, timeout=90)
    return {'exit_code': result.returncode, 'stdout': result.stdout[-24000:], 'stderr': result.stderr[-24000:]}


def revision(root):
    result = run(['git', 'rev-parse', 'HEAD'], root)
    return result['stdout'].strip() if result['exit_code'] == 0 else 'not-a-git-checkout'


def evaluate(trusted, candidate, bootstrap_ledger=False):
    trusted, candidate = trusted.resolve(), candidate.resolve()
    report = {'schema_version': 1, 'trusted_revision': revision(trusted),
              'candidate_revision': revision(candidate), 'checks': [], 'errors': [], 'incidents': []}
    try:
        if trusted == candidate:
            raise ValueError('trusted and candidate roots must be separate checkouts')
        trusted_script = safe(trusted, VALIDATOR)
        candidate_script = safe(candidate, VALIDATOR)
        trusted_tests = safe(trusted, TESTS)
        if not trusted_tests.read_text().strip():
            raise ValueError('trusted regression suite is empty')
        report['trusted_sha256'] = {VALIDATOR: digest(trusted_script), TESTS: digest(trusted_tests)}
        if (trusted / LEDGER).exists():
            if bootstrap_ledger:
                raise ValueError('bootstrap is forbidden when a trusted ledger already exists')
            baseline = ledger(trusted)
            report['trusted_sha256'][LEDGER] = digest(safe(trusted, LEDGER))
            report['evidence_status'] = 'retained-baseline-verified'
        elif bootstrap_ledger:
            baseline = {}
            report['evidence_status'] = 'pending-independent-bootstrap'
        else:
            raise ValueError('missing trusted ledger; independent initial bootstrap must be explicit')
        proposed = ledger(candidate)
        report['candidate_sha256'] = {name: digest(safe(candidate, name)) for name in (VALIDATOR, TESTS, LEDGER)}
        for identity, record in baseline.items():
            if proposed.get(identity) != record:
                raise ValueError(f'retained evidence deleted or rewritten: {identity}; add supersession instead')
        with tempfile.TemporaryDirectory(prefix='authority-trusted-') as tmp:
            stage = Path(tmp)
            result = run([sys.executable, '-I', str(trusted_script), '--root', str(candidate)], stage)
            report['checks'].append({'name': 'trusted-validator-on-candidate-registry', **result})
            if result['exit_code'] != 0:
                report['errors'].append('trusted validator rejected candidate registry')
            # This prevents candidate tests from replacing trusted expectations.
            (stage / 'scripts/tests').mkdir(parents=True)
            shutil.copy2(trusted_tests, stage / TESTS)
            shutil.copy2(candidate_script, stage / VALIDATOR)
            result = run([sys.executable, '-I', str(stage / TESTS)], stage)
            report['checks'].append({'name': 'trusted-tests-on-candidate-validator', **result})
            count = re.search(r'Ran (\d+) tests?', result['stderr'])
            if result['exit_code'] != 0 or not count or int(count[1]) == 0:
                report['errors'].append('trusted regression expectations failed or no tests executed')
            # Replay retained exact trees from both roots, not just candidate-produced summaries.
            for identity, record in proposed.items():
                fixture = candidate / record['fixture_root']
                for label, script in [('trusted', trusted_script), ('candidate', candidate_script)]:
                    result = run([sys.executable, '-I', str(script), '--root', str(fixture)], stage)
                    report['checks'].append({'name': f'{label}-fixture:{identity}', 'expected_exit': record['expected_exit'], **result})
                    if result['exit_code'] != record['expected_exit']:
                        report['errors'].append(f'{label} fixture expectation failed: {identity}')
                        report['incidents'].append({
                            'classification': 'known-failure-recurrence' if identity in baseline else 'discovery',
                            'category': 'process-defect' if identity in baseline else 'new-fixture-failure',
                            'fixture_id': identity, 'causal_lesson': record['causal_lesson'],
                            'evaluator': label, 'expected_exit': record['expected_exit'],
                            'actual_exit': result['exit_code']})
        for root, hashes in ((trusted, report['trusted_sha256']), (candidate, report['candidate_sha256'])):
            for name, expected in hashes.items():
                if digest(safe(root, name)) != expected:
                    report['errors'].append(f'enforcement/evidence changed during evaluation: {name}')
        if baseline and ledger(trusted) != baseline:
            report['errors'].append('trusted ledger changed during evaluation')
        if ledger(candidate) != proposed:
            report['errors'].append('candidate ledger changed during evaluation')
    except (ValueError, KeyError, TypeError, OSError, subprocess.TimeoutExpired) as exc:
        report['errors'].append(str(exc))
    report['passed'] = not report['errors']
    return report


def require_clean_checkout(root, expected_sha=None, bootstrap_ledger=False):
    root = root.resolve()
    top = run(['git', 'rev-parse', '--show-toplevel'], root)
    if top['exit_code'] or Path(top['stdout'].strip()).resolve() != root:
        raise ValueError('CLI roots must be exact Git checkout roots')
    sha = revision(root)
    if not re.fullmatch('[0-9a-f]{40}', sha):
        raise ValueError('checkout has no committed revision')
    if expected_sha and sha != expected_sha:
        raise ValueError('trusted checkout does not match required base SHA')
    status = run(['git', 'status', '--porcelain', '--untracked-files=all'], root)
    if status['exit_code'] or status['stdout'].strip():
        raise ValueError('CLI requires clean tracked checkouts without untracked candidate evidence')
    for name in (VALIDATOR, TESTS, LEDGER):
        if name == LEDGER and bootstrap_ledger and not (root / name).exists():
            continue
        tracked = run(['git', 'ls-files', '--error-unmatch', '--', name], root)
        if tracked['exit_code']:
            raise ValueError(f'baseline/candidate enforcement file is not tracked: {name}')
        blob = subprocess.run(['git', 'show', f'{sha}:{name}'], cwd=root,
                              capture_output=True, timeout=90)
        if blob.returncode or hashlib.sha256(blob.stdout).hexdigest() != digest(safe(root, name)):
            raise ValueError(f'enforcement file differs from committed revision: {name}')
    return sha


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--trusted-root', type=Path, required=True)
    parser.add_argument('--candidate-root', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--trusted-sha', help='required full base commit SHA for CI provenance')
    parser.add_argument('--bootstrap-ledger', action='store_true',
                        help='initial ledger only; baseline validator/tests remain mandatory')
    args = parser.parse_args()
    try:
        require_clean_checkout(args.trusted_root, args.trusted_sha, args.bootstrap_ledger)
        require_clean_checkout(args.candidate_root)
        report = evaluate(args.trusted_root, args.candidate_root, args.bootstrap_ledger)
    except (ValueError, OSError, subprocess.TimeoutExpired) as exc:
        report = {'schema_version': 1, 'passed': False, 'errors': [str(exc)], 'checks': [],
                  'evidence_status': 'provenance-rejected'}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + '\n')
    for error in report['errors']:
        print(f'FAIL: {error}', file=sys.stderr)
    print('trusted-control-plane: ' + ('PASS' if report['passed'] else 'FAIL'))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
