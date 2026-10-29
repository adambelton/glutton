#!/usr/bin/env python3
"""Task 053 only. --collect makes authorised paid requests; default replays evidence."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'docs/film_qualities'
RAW = ROOT / 'tmp/quality-policy-053'
OUT = ROOT / 'docs/research/quality_selection_policy_053.json'
PRICE = 0.042 / 1_000_000
RESERVE = 65_536 * PRICE
BUDGET = 1.0
MODEL = 'jev-1.14.0'

def read(path):
    return json.loads(path.read_text())

def digest(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()).hexdigest()

def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')

def request_for(film, vocabulary, contract):
    return {'model': MODEL, 'state': {'film_title': film['title'], 'source_paragraphs': film['source_paragraphs'], 'evidence_policy': contract['evidence_policy']}, 'questions': {
        q['id']: {'type': 'noul', 'instructions': contract['question_template'].format(name=q['name']), 'criteria': {'true': q['match_rule'], 'false': contract['false_criterion_template'].format(not_sufficient=q['not_sufficient'])}} for q in vocabulary}}

def api_key():
    # Read just this key; never execute or print the development environment.
    for line in (ROOT / '.env.development').read_text().splitlines():
        name, sep, value = line.removeprefix('export ').partition('=')
        if sep and name.strip() == 'TYPESAFE_API_KEY':
            value = value.strip()
            if value[:1] in ('"', "'") and value[-1:] == value[:1]:
                value = value[1:-1]
            if value:
                return value
    raise RuntimeError('TYPESAFE_API_KEY not available')

def validate(response, vocabulary):
    assert response['model'] == MODEL, 'Unexpected model'
    assert set(response['answers']) == {q['id'] for q in vocabulary}, 'Incomplete answers'
    for a in response['answers'].values():
        assert a['type'] == 'noul' and isinstance(a['noul'], (int, float)) and 0 <= a['noul'] <= 1, 'Invalid answer'
    assert response['usage']['input_tokens'] <= 65_536, 'Unexpected billing/context usage'

def select(probabilities, vocabulary, threshold, policy):
    ordered = sorted((q for q in vocabulary if probabilities[q['id']] >= threshold), key=lambda q: (-probabilities[q['id']], q['id']))
    chosen = []
    counts = Counter()
    for q in ordered:
        if policy == 'global20' and len(chosen) == 20:
            break
        if policy.startswith('category') and counts[q['facet']] >= int(policy[8:]):
            continue
        chosen.append(q['id'])
        counts[q['facet']] += 1
    return chosen

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--collect', action='store_true')
    args = parser.parse_args()
    vocabulary = read(BASE / 'vocabulary.json')['qualities']
    contract = read(BASE / 'matching.json')
    examples = read(BASE / 'examples.json')['examples']
    ledger_path = RAW / 'ledger.json'
    ledger = read(ledger_path) if ledger_path.exists() else []
    key = api_key() if args.collect else None
    for round_no in (1, 2):
        for film in examples:
            case = f"round{round_no}-{film['film']}"
            payload = request_for(film, vocabulary, contract)
            response_path = RAW / (case + '.response.json')
            prior = [entry for entry in ledger if entry['case'] == case]
            if prior:
                assert len(prior) == 1 and prior[0]['request_sha256'] == digest(payload), 'Mismatched existing case'
                if not response_path.exists():
                    raise RuntimeError('Prior attempt has no complete result; no automatic paid retry: ' + case)
                validate(read(response_path), vocabulary)
                continue
            if not args.collect:
                continue
            assert (len(ledger) + 1) * RESERVE <= BUDGET, 'Budget reservation exhausted'
            save(RAW / (case + '.request.json'), payload)
            entry = {'case': case, 'film': film['film'], 'round': round_no, 'request_sha256': digest(payload), 'reserved_usd': RESERVE, 'status': 'attempted'}
            ledger.append(entry)
            save(ledger_path, ledger)
            started = time.monotonic()
            req = urllib.request.Request('https://api.typesafe.ai/v1/systemone', data=json.dumps(payload, ensure_ascii=False).encode(), headers={'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json'}, method='POST')
            try:
                with urllib.request.urlopen(req, timeout=90) as response:
                    result = json.load(response)
                save(response_path, result)
                validate(result, vocabulary)
            except Exception as error:
                entry['status'] = 'failed'
                entry['error_type'] = type(error).__name__
                save(ledger_path, ledger)
                raise RuntimeError('Provider call failed; no automatic paid retry: ' + case + ' (' + type(error).__name__ + ')') from None
            entry.update(status='complete', seconds=round(time.monotonic() - started, 3), usage=result['usage'], cost_usd=result['usage']['input_tokens'] * PRICE)
            save(ledger_path, ledger)
            print(case, 'complete', 'usd=' + format(entry['cost_usd'], '.8f'), flush=True)
    retained = read(OUT) if OUT.exists() else None
    if retained:
        for name, expected_hash in retained['input_file_sha256'].items():
            assert hashlib.sha256((BASE / name).read_bytes()).hexdigest() == expected_hash, 'Baseline differs from retained experiment'
    cases = [{'case': 'historical-' + film['film'], 'film': film['film'], 'round': 0, 'probabilities': film['support_probabilities']} for film in examples]
    for entry in ledger:
        if entry['status'] != 'complete':
            continue
        response = read(RAW / (entry['case'] + '.response.json'))
        validate(response, vocabulary)
        cases.append({**entry, 'model': response['model'], 'probabilities': {k: v['noul'] for k, v in response['answers'].items()}})
    if not ledger and not args.collect and retained:
        cases.extend(c for c in retained['cases'] if c['round'] > 0)
    ledger_evidence = ledger or [c for c in cases if c['round'] > 0]
    by_id = {q['id']: q for q in vocabulary}
    by_film = {f['film']: f for f in examples}
    summaries = []
    for case in cases:
        reviews = {r['quality_id']: r for r in by_film[case['film']]['candidate_reviews']}
        for threshold in (.6, .7):
            for policy in ('global20', 'category2', 'category3', 'category4', 'threshold_only'):
                chosen = select(case['probabilities'], vocabulary, threshold, policy)
                counts = Counter(by_id[q]['facet'] for q in chosen)
                flags = Counter(reviews[q]['verdict'] if q in reviews else 'not_historically_reviewed' for q in chosen)
                summaries.append({'case': case['case'], 'film': case['film'], 'round': case['round'], 'threshold': threshold, 'policy': policy, 'selected': chosen, 'count': len(chosen), 'category_counts': dict(counts), 'covered_categories': len(counts), 'largest_category_share': max(counts.values(), default=0) / len(chosen) if chosen else 0, 'historical_review_counts_not_accuracy': dict(flags)})
    comparisons = []
    for film in examples:
        for threshold in (.6, .7):
            for policy in ('global20', 'category2', 'category3', 'category4', 'threshold_only'):
                rounds = {r['round']: r for r in summaries if r['film'] == film['film'] and r['threshold'] == threshold and r['policy'] == policy}
                if 1 in rounds and 2 in rounds:
                    first, second = set(rounds[1]['selected']), set(rounds[2]['selected'])
                    comparisons.append({'film': film['film'], 'threshold': threshold, 'policy': policy, 'removed_between_fresh_rounds': sorted(first-second), 'added_between_fresh_rounds': sorted(second-first), 'jaccard': len(first & second) / len(first | second) if first | second else 1.0})
    save(OUT, {'task': '053', 'fresh_repeat_comparisons': comparisons, 'model': MODEL, 'price_usd_per_input_million': .042, 'budget_usd': BUDGET, 'reserved_usd': len(ledger_evidence) * RESERVE, 'cost_usd': sum(e.get('cost_usd', 0) for e in ledger_evidence), 'input_file_sha256': {name: hashlib.sha256((BASE / name).read_bytes()).hexdigest() for name in ('vocabulary.json', 'matching.json', 'examples.json')}, 'category_vocabulary_sizes': dict(Counter(q['facet'] for q in vocabulary)), 'historical_labels_are_not_ground_truth': True, 'cases': cases, 'summaries': summaries})
    print('Evidence saved; complete fresh calls:', sum(e['status'] == 'complete' for e in ledger_evidence), 'cost_usd:', sum(e.get('cost_usd', 0) for e in ledger_evidence))

if __name__ == '__main__':
    main()
