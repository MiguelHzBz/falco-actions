#!/usr/bin/env python3
"""
Validate that expected Falco rules fired during a demo scenario replay.

Usage: validate_rules.py <falco_events_json> <expected_rules_txt> <scenario_name>

Exits 0 if all expected rules fired, 1 if any were missed.
Writes a summary table to $GITHUB_STEP_SUMMARY when set.
"""
import json
import os
import sys


def load_expected(path):
    try:
        with open(path) as f:
            return [l.strip() for l in f if l.strip() and not l.startswith('#')]
    except FileNotFoundError:
        print(f"ERROR: expected-rules.txt not found at {path}", file=sys.stderr)
        return []


def load_fired(path):
    fired = set()
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    event = json.loads(line)
                    rule = event.get('rule', '')
                    if rule:
                        fired.add(rule)
                except json.JSONDecodeError:
                    continue
    except FileNotFoundError:
        pass
    return fired


def main():
    if len(sys.argv) < 4:
        print(f"Usage: {sys.argv[0]} <falco_events_json> <expected_rules_txt> <scenario_name>",
              file=sys.stderr)
        sys.exit(2)

    events_path, expected_path, scenario = sys.argv[1], sys.argv[2], sys.argv[3]

    expected = load_expected(expected_path)
    fired = load_fired(events_path)

    missed = [r for r in expected if r not in fired]
    hit = [r for r in expected if r in fired]
    bonus = sorted(fired - set(expected))

    all_pass = len(missed) == 0

    # Console output
    print(f"\n{'='*60}")
    print(f"Rule Validation: {scenario}")
    print(f"{'='*60}")
    for rule in expected:
        mark = "FIRED  " if rule in fired else "MISSED "
        sym = "+" if rule in fired else "!"
        print(f"  [{sym}] {mark} {rule}")

    if bonus:
        print(f"\n  Bonus rules fired (base Falco rules):")
        for rule in bonus:
            print(f"  [+]         {rule}")

    print(f"\n  Result: {'PASS — all {n} expected rules fired'.format(n=len(expected)) if all_pass else 'FAIL — {n}/{t} rules missed'.format(n=len(missed), t=len(expected))}")
    print(f"{'='*60}\n")

    # GitHub Step Summary
    summary_path = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary_path:
        lines = []
        lines.append(f"\n## Rule Validation: `{scenario}` — {'✅ PASS' if all_pass else '❌ FAIL'}\n")
        lines.append("| Status | Rule | Priority |")
        lines.append("|---|---|---|")

        priority_map = {}
        try:
            with open(events_path) as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        e = json.loads(line)
                        priority_map[e.get('rule', '')] = e.get('priority', '')
                    except json.JSONDecodeError:
                        continue
        except FileNotFoundError:
            pass

        for rule in expected:
            if rule in fired:
                pri = priority_map.get(rule, '')
                lines.append(f"| ✅ FIRED | {rule} | {pri} |")
            else:
                lines.append(f"| ❌ MISSED | {rule} | — |")

        if bonus:
            lines.append("")
            lines.append("**Additional rules fired (base Falco rules):**")
            lines.append("")
            lines.append("| Rule |")
            lines.append("|---|")
            for rule in bonus:
                lines.append(f"| {rule} |")

        with open(summary_path, 'a') as f:
            f.write('\n'.join(lines) + '\n')

    sys.exit(0 if all_pass else 1)


if __name__ == '__main__':
    main()
