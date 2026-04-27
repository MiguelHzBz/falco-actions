# Supply Chain Attack Detection — Demo Scenarios

This directory contains self-contained attack simulation scenarios for the
`Supply Chain Attack Detection Framework` workflow.

Each scenario simulates a real-world supply chain attack **safely** (no real C2 contacted,
all exfiltration targets localhost) and maps every attack step to a Falco rule that fires.

## Running the Framework

Go to **Actions → Supply Chain Attack Detection Framework → Run workflow** in your fork.
Select a specific scenario or `all` to run them in parallel.

## Scenarios

| Scenario | Attack | Threat Actor | Detection Rules |
|---|---|---|---|
| `teampcp-trivy` | GitHub Actions tag hijack + CI runner secret theft | TeamPCP | 4 new + 2 existing |
| `teampcp-pypi` | Malicious PyPI package + `.pth` persistence | TeamPCP / CanisterWorm | 3 new |
| `teampcp-canisterworm` | npm token theft + autonomous self-propagation | TeamPCP / CanisterWorm | 2 new |

## Adding a New Scenario

Adding coverage for a new attack requires three files — no changes to the workflow.

```
demos/<scenario-name>/
├── threat-profile.yaml   # TTPs and IOCs extracted from the research article
├── rules.yaml            # Falco rules — one rule per TTP
└── simulate.sh           # Safe simulation — one bash block per TTP
```

### Step-by-step

1. **Get the threat intelligence.** If you have a research article or blog post, run the
   `threat-intel` skill against it. The output is a structured YAML with TTPs, IOCs, and
   a kill chain. Save it as `threat-profile.yaml`.

2. **Write `rules.yaml`.** For each TTP in the threat profile, write one Falco rule.
   - Use `spawned_process` for command execution TTPs
   - Use `open_read` / `open_write` for file access TTPs
   - Use `outbound` for network TTPs
   - Priority: CRITICAL for active exfil/exploitation, WARNING for recon/persistence

3. **Write `simulate.sh`.** For each TTP, write a safe bash block that triggers the behavior:
   - Network calls → target `http://127.0.0.1:9999/` (unreachable, fails gracefully)
   - IMDS calls → add `--max-time 2` to avoid hanging
   - File writes → use `/tmp/` or `~/.local/` paths
   - Add `|| true` to every command so failures don't abort the simulation
   - Label each stage clearly: `echo "=== Stage N: <description> ==="`

4. **Push.** The workflow's `discover` job reads `ls demos/` and picks up the new directory
   automatically — no workflow changes needed.

### Template

```bash
#!/usr/bin/env bash
# Scenario: <name>
# Simulates: <attack description>
# All network calls target localhost. No real C2 contacted.
set -euo pipefail

SCENARIO_NAME="<name>"

echo "=== $SCENARIO_NAME: Stage 1 — <TTP name> ==="
echo "Simulating: <what the attacker does>"
<safe command> || true
echo "Expected rule: <Rule Name>"
echo ""

echo "=== $SCENARIO_NAME: Stage 2 — <TTP name> ==="
...
```

### Rule template

```yaml
- rule: <Threat Actor> - <Short TTP Description>
  desc: >
    <One sentence describing the attack behavior and which real-world incident it models.>
  condition: >
    <falco condition>
  output: >
    <description> (process=%proc.name command=%proc.cmdline
    gparent=%proc.aname[2] ggparent=%proc.aname[3])
  priority: <CRITICAL|WARNING|INFO>
  tags: [CI/CD, supply-chain, <ThreatActor>, <MITRE-ID>]
```
