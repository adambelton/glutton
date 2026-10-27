"""Validate task 027 research artifacts; no app/database access or engine scoring."""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[3]
RUN = Path(__file__).resolve().parent
baseline = json.loads((RUN / 'baseline_hashes.json').read_text())
for name, digest in baseline.items():
    assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest, name

files = list(RUN.glob('*.md'))
links = 0
for path in files:
    for target in re.findall(r'\]\(([^)]+)\)', path.read_text()):
        if '://' in target:
            continue
        name, _, fragment = target.partition('#')
        dest = path.parent / name if name else path
        assert dest.exists(), (path, target)
        if fragment:
            content = dest.read_text()
            headings = re.findall(r'^#+ (.+)$', content, re.M)
            anchors = {re.sub(r'[^\w\- ]', '', h.lower()).replace(' ', '-') for h in headings}
            anchors.update(re.findall(r'<a id="([^"]+)">', content))
            assert fragment in anchors, (path, target)
        links += 1

associations = json.loads((RUN / 'associations.json').read_text())
assert len(associations) == 20
assert len({a['id'] for a in associations}) == 20
for association in associations:
    film = association['analysis'].split(':')[0]
    text = (RUN / (film + '.md')).read_text()
    assert association['quality'] in text
    for target in association['evidence']:
        filename, fragment = target.split('#')
        assert f'<a id="{fragment}">' in (RUN / filename).read_text(), target

fixture = json.loads((RUN / 'timeline.json').read_text())
assert fixture['illustrative_only']
versions = fixture['versions']
by_id = {v['id']: v for v in versions}
for version in versions:
    if version['superseded_at']:
        replacement = by_id[version['superseded_by_id']]
        assert version['superseded_at'] == replacement['activated_at']
        assert version['activated_at'] < version['superseded_at']
for case in fixture['cases']:
    at = case['at']  # uniform UTC ISO format; lexical comparison is chronological
    selected = [v for v in versions if v['activated_at'] and v['activated_at'] <= at
                and (not v['superseded_at'] or at < v['superseded_at'])]
    assert len(selected) <= 1, case
    assert (selected[0]['id'] if selected else None) == case['expected'], case
assert by_id['illustrative:a2']['qualities'] != by_id['illustrative:a3']['qualities']
assert by_id['illustrative:a3']['qualities'] == by_id['illustrative:a4']['qualities']
assert by_id['illustrative:a3']['qualities'] == [a['quality'] for a in associations
                                               if a['analysis'] == 'the_babadook:analysis:3']
print(f'PASS: {len(baseline)} baseline hashes, {links} local links/anchors, '
      f'{len(associations)} associations, {len(fixture["cases"])} historical selections; '
      'replacement boundaries and prose-only association equality.')
