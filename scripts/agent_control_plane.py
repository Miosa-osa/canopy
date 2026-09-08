#!/usr/bin/env python3
"""Validate declared document authority; no model inference or application startup."""
import argparse
import datetime
import json
from pathlib import Path
import re
import sys


def validate(root):
    root = root.resolve()
    errors = []
    def require(condition, message):
        if not condition:
            errors.append(message)
    def safe_path(value):
        if not isinstance(value, str) or not value or Path(value).is_absolute():
            raise ValueError(f'invalid repository path: {value!r}')
        if Path(value).as_posix() != value or '..' in Path(value).parts:
            raise ValueError(f'noncanonical repository path: {value}')
        path = (root / value).resolve()
        if not path.is_relative_to(root):
            raise ValueError(f'path escapes repository: {value}')
        return path
    def unique_object(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f'duplicate JSON key: {key}')
            result[key] = value
        return result
    manifest = json.loads((root / 'agent-authority.json').read_text(), object_pairs_hook=unique_object)
    require(type(manifest['schema_version']) is int and manifest['schema_version'] == 1, 'unsupported schema_version')
    require(isinstance(manifest['permissions'], dict) and bool(manifest['permissions']), 'permissions must be explicit')
    require(all(isinstance(k, str) and k.strip() and isinstance(v, str) and v.strip()
                for k, v in manifest['permissions'].items()), 'permission names and policies must be nonempty strings')
    for field in ('inventory', 'required_paths'):
        require(isinstance(manifest[field], list) and all(isinstance(v, str) and v for v in manifest[field]), f'invalid {field}')
    documents = manifest['documents']
    require(isinstance(documents, list) and bool(documents), 'documents must be a nonempty list')
    by_id, by_path, owners = {}, {}, {}
    resolved_paths = set()
    for doc in documents:
        for field in ('id', 'path', 'kind', 'status', 'owner', 'scope', 'effective'):
            require(isinstance(doc[field], str) and bool(doc[field].strip()), f'invalid {field}')
        require(type(doc['version']) is int and doc['version'] > 0, f'invalid version: {doc["id"]}')
        datetime.date.fromisoformat(doc['effective'])
        require(doc['kind'] in ('normative', 'contract', 'reference', 'historical'), f'invalid kind: {doc["id"]}')
        require(doc['status'] in ('active', 'superseded', 'deprecated'), f'invalid status: {doc["id"]}')
        require(doc['id'] not in by_id, f'duplicate id: {doc["id"]}')
        require(doc['path'] not in by_path, f'duplicate path: {doc["path"]}')
        by_id[doc['id']] = doc
        by_path[doc['path']] = doc
        resolved_path = safe_path(doc['path'])
        require(resolved_path not in resolved_paths, f'duplicate resolved document: {doc["path"]}')
        resolved_paths.add(resolved_path)
        require(resolved_path.is_file(), f'missing document: {doc["path"]}')
        current = doc['status'] == 'active' and doc['kind'] in ('normative', 'contract')
        require(not (doc['status'] != 'active' and doc['kind'] in ('normative', 'contract')), f'retired document remains normative: {doc["id"]}')
        require(isinstance(doc.get('requires', []), list), f'invalid requires: {doc["id"]}')
        require(all(isinstance(v, str) and v for v in doc.get('requires', [])), f'invalid required id: {doc["id"]}')
        require('check_references' not in doc or type(doc['check_references']) is bool, f'invalid check_references: {doc["id"]}')
        require(not current or doc.get('check_references', True), f'current authority reference checks disabled: {doc["id"]}')
        require(not doc.get('superseded_by') or doc['status'] == 'superseded', f'active/deprecated document declares supersession: {doc["id"]}')
        require(isinstance(doc['owns'], list), f'invalid owns: {doc["id"]}')
        require(current or not doc['owns'], f'historical/reference document owns current concepts: {doc["id"]}')
        for concept in doc['owns']:
            require(isinstance(concept, str) and bool(concept), f'invalid concept: {doc["id"]}')
            key = (doc['scope'], concept)
            require(key not in owners, f'competing authority: {key}')
            owners[key] = doc['id']
        if doc['status'] == 'superseded':
            require(bool(doc.get('superseded_by')), f'missing supersession: {doc["id"]}')
    visiting, visited = set(), set()
    def visit(doc_id):
        if doc_id in visiting:
            errors.append(f'circular authority requirement: {doc_id}')
            return
        if doc_id in visited or doc_id not in by_id:
            return
        visiting.add(doc_id)
        for required_id in by_id[doc_id].get('requires', []):
            visit(required_id)
        visiting.remove(doc_id)
        visited.add(doc_id)
    for doc_id in by_id:
        visit(doc_id)
    for doc in documents:
        for required_id in doc.get('requires', []):
            target = by_id.get(required_id)
            require(target is not None, f'dangling authority reference: {required_id}')
            if target:
                require(target['status'] == 'active' and target['kind'] in ('normative', 'contract'), f'boot references retired/non-normative authority: {required_id}')
        seen = {doc['id']}
        target_id = doc.get('superseded_by')
        while target_id:
            require(target_id not in seen, f'circular supersession: {doc["id"]}')
            if target_id in seen:
                break
            seen.add(target_id)
            target = by_id.get(target_id)
            require(target is not None, f'dangling supersession: {target_id}')
            if not target:
                break
            target_id = target.get('superseded_by')
            if not target_id:
                require(target['status'] == 'active' and target['kind'] in ('normative', 'contract'), f'supersession ends outside current authority: {doc["id"]}')
        if (doc['status'] == 'active' and doc['kind'] in ('normative', 'contract')) or doc.get('check_references', False):
            path = safe_path(doc['path'])
            if path.is_file():
                content = path.read_text()
                refs = set(re.findall(r'`([^`\n#]+\.md)(?:#[^`\n]*)?`', content))
                refs.update(re.findall(r'(?<![\w/])(?:docs|skills)/[\w./-]+\.md', content))
                refs.update(re.findall(r'\]\(<?([^)>\s#]+\.md)(?:#[^)>\s]*)?>?(?:\s+[\"\'][^)]*)?\)', content))
                refs.update(re.findall(r'^\s*\[[^]\n]+\]:\s*<?([^>\s#]+\.md)(?:#[^>\s]*)?>?', content, re.MULTILINE))
                # Bare paths in prose count too. Fenced examples and external URLs
                # are not repository dependencies; Markdown links above stay explicit.
                prose = re.sub(r"(?ms)^\s*(`{3,}|~{3,})[^\n]*\n.*?^\s*\1\s*$", "", content)
                prose = re.sub(r"(?:[a-zA-Z][a-zA-Z0-9+.-]*://|~/)[^\s<>`]+", "", prose)
                refs.update(re.findall(r"(?<![\w/*])((?:\.\.?/)*[\w.-]+(?:/[\w.-]+)*\.md)(?=[\s#.,;:)\]<>`\"']|$)", prose))
                for ref in refs:
                    if '://' in ref or ref.startswith('~'):
                        continue
                    resolved = (path.parent / ref).resolve()
                    if not resolved.is_relative_to(root):
                        errors.append(f'reference escapes root: {ref}')
                        continue
                    relative = resolved.relative_to(root).as_posix()
                    require(resolved.is_file(), f'broken document reference in {doc["path"]}: {ref}')
                    require(relative in by_path, f'unclassified boot document: {relative}')
                    target = by_path.get(relative)
                    if target and doc['kind'] == 'normative':
                        require(target['status'] == 'active' and target['kind'] != 'historical', f'boot text references retired/historical authority: {relative}')
    for pattern in manifest['inventory']:
        require(not Path(pattern).is_absolute() and '..' not in Path(pattern).parts, f'invalid inventory glob: {pattern}')
        for path in root.glob(pattern):
            if path.is_file():
                require(path.relative_to(root).as_posix() in by_path, f'unclassified document: {path.relative_to(root)}')
    for path in manifest['required_paths']:
        require(safe_path(path).exists(), f'missing command/tool/module: {path}')
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    try:
        errors = validate(args.root.resolve())
    except (KeyError, ValueError, TypeError, OSError) as exc:
        errors = [f'malformed authority manifest: {exc}']
    for error in errors:
        print(f'FAIL: {error}', file=sys.stderr)
    if errors:
        return 1
    print('agent-control-plane-integrity: PASS')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
