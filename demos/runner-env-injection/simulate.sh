#!/usr/bin/env bash
# =============================================================================
# Runner Environment File Injection
# Safe simulation of LD_PRELOAD, NODE_OPTIONS, and PATH injection via
# GitHub Actions runner environment control files.
#
# SAFE: Injected payloads are empty stubs. LD_PRELOAD .so is not a valid ELF
#       (dynamic linker opens it then fails — the open() syscall still fires).
#       PATH-hijacked binary is a copy of /bin/ls with a tool name.
#       Step summary writes contain no real secrets.
#
# Each stage maps to one Falco rule.
# =============================================================================

set -uo pipefail

BOLD='\033[1m'
RESET='\033[0m'
RED='\033[0;31m'
YELLOW='\033[0;33m'

# Use real runner control files if available, fall back to /tmp stubs for local runs
RUNNER_ENV_FILE="${GITHUB_ENV:-/tmp/simulate_runner_env}"
RUNNER_PATH_FILE="${GITHUB_PATH:-/tmp/simulate_runner_path}"
RUNNER_SUMMARY_FILE="${GITHUB_STEP_SUMMARY:-/tmp/simulate_runner_summary}"

echo -e "${BOLD}Runner Environment File Injection${RESET}"
echo "Simulating LD_PRELOAD, NODE_OPTIONS, and PATH injection via runner control files"
echo "Reference: https://docs.github.com/en/actions/concepts/security/compromised-runners"
echo ""

# =============================================================================
# Stage 1: LD_PRELOAD Injection via $GITHUB_ENV
# Write LD_PRELOAD=/tmp/evil.so to the runner environment control file.
# The runner injects this into every subsequent step's environment.
# Expected rule: Shared Library Loaded from Temp Path in CI Runner (CRITICAL)
# =============================================================================
echo -e "${BOLD}=== Stage 1: LD_PRELOAD Injection ===${RESET}"
echo "Simulating: write LD_PRELOAD=/tmp/evil.so to \$GITHUB_ENV"
echo ""

# Drop the (stub) payload to /tmp/
echo "# simulated malicious shared library" > /tmp/evil.so

# Inject into the runner environment file
echo "LD_PRELOAD=/tmp/evil.so" >> "$RUNNER_ENV_FILE"
echo "Written: LD_PRELOAD=/tmp/evil.so → $RUNNER_ENV_FILE"

# Simulate execution of the next step loading the .so via LD_PRELOAD
# Even though evil.so is not a valid ELF, the dynamic linker opens() it first.
# Falco fires on the open() call before the linker fails.
LD_PRELOAD=/tmp/evil.so bash -c "exit 0" 2>/dev/null || true

echo -e "${RED}Expected rule: Shared Library Loaded from Temp Path in CI Runner (CRITICAL)${RESET}"
echo ""
sleep 1

# =============================================================================
# Stage 2: NODE_OPTIONS Injection via $GITHUB_ENV
# Write NODE_OPTIONS=--require /tmp/evil.js to $GITHUB_ENV.
# Every subsequent node invocation executes the malicious script first.
# Expected rule: Node.js Script Loaded from Temp Path via NODE_OPTIONS (CRITICAL)
# =============================================================================
echo -e "${BOLD}=== Stage 2: NODE_OPTIONS Injection ===${RESET}"
echo "Simulating: write NODE_OPTIONS=--require /tmp/evil.js to \$GITHUB_ENV"
echo ""

# Drop the (stub) payload to /tmp/
echo "// simulated malicious Node.js payload" > /tmp/evil.js

# Inject into the runner environment file
echo "NODE_OPTIONS=--require /tmp/evil.js" >> "$RUNNER_ENV_FILE"
echo "Written: NODE_OPTIONS=--require /tmp/evil.js → $RUNNER_ENV_FILE"

# Simulate execution of a Node step loading the script via NODE_OPTIONS
NODE_OPTIONS="--require /tmp/evil.js" node -e "process.exit(0)" 2>/dev/null || true

echo -e "${RED}Expected rule: Node.js Script Loaded from Temp Path via NODE_OPTIONS (CRITICAL)${RESET}"
echo ""
sleep 1

# =============================================================================
# Stage 3: PATH Hijacking via $GITHUB_PATH
# Write /tmp/evil_bins to $GITHUB_PATH and place a fake 'git' binary there.
# The next step that calls 'git' runs the attacker's binary instead.
# Expected rule: Known CI Tool Executed from Temp Path (CRITICAL)
# =============================================================================
echo -e "${BOLD}=== Stage 3: PATH Hijacking ===${RESET}"
echo "Simulating: prepend /tmp/evil_bins to PATH via \$GITHUB_PATH, place fake git"
echo ""

mkdir -p /tmp/evil_bins

# Fake 'git' binary: copies a real binary (ls) but with the git name
# proc.name = "git", proc.exepath = "/tmp/evil_bins/git" → fires the rule
cp /bin/ls /tmp/evil_bins/git 2>/dev/null || cp /usr/bin/ls /tmp/evil_bins/git 2>/dev/null || true
chmod +x /tmp/evil_bins/git 2>/dev/null || true

# Inject /tmp/evil_bins into PATH via the runner path control file
echo "/tmp/evil_bins" >> "$RUNNER_PATH_FILE"
echo "Written: /tmp/evil_bins → $RUNNER_PATH_FILE"

# Execute the hijacked binary directly to trigger the rule
/tmp/evil_bins/git --version 2>/dev/null || true

echo -e "${RED}Expected rule: Known CI Tool Executed from Temp Path (CRITICAL)${RESET}"
echo ""
sleep 1

# =============================================================================
# Stage 4: Step Summary Exfiltration
# Write sensitive content to $GITHUB_STEP_SUMMARY.
# The runner uploads this automatically — readable by anyone with repo read access.
# No outbound network connection required — bypasses all egress controls.
# Expected base rule: Process Reading Environment Variables of Others (WARNING)
# (Supplementary visibility — no dedicated scenario rule for this stage)
# =============================================================================
echo -e "${BOLD}=== Stage 4: Step Summary Exfiltration ===${RESET}"
echo "Simulating: write captured env vars to \$GITHUB_STEP_SUMMARY"
echo ""

{
  echo "## Captured Runner Environment"
  echo ""
  echo "| Variable | Value |"
  echo "|---|---|"
  echo "| GITHUB_TOKEN | \$(REDACTED-PLACEHOLDER-ghs_simulation) |"
  echo "| AWS_ACCESS_KEY_ID | \$(REDACTED-PLACEHOLDER) |"
  echo "| ACTIONS_RUNTIME_TOKEN | \$(REDACTED-PLACEHOLDER) |"
} >> "$RUNNER_SUMMARY_FILE"

echo "Written: captured env summary → $RUNNER_SUMMARY_FILE"
echo "Note: this file is uploaded to GitHub Actions UI — readable by all repo readers"

echo -e "${YELLOW}Visibility: written-files section of forensic report will show summary content${RESET}"
echo ""

# =============================================================================
# Cleanup
# =============================================================================
rm -f /tmp/evil.so /tmp/evil.js
rm -rf /tmp/evil_bins

# =============================================================================
echo -e "${BOLD}=== Simulation Complete ===${RESET}"
echo ""
echo "Rules expected to fire:"
echo "  CRITICAL  Shared Library Loaded from Temp Path in CI Runner"
echo "  CRITICAL  Node.js Script Loaded from Temp Path via NODE_OPTIONS"
echo "  CRITICAL  Known CI Tool Executed from Temp Path"
echo "  WARNING   Runner Environment Control File Written by Non-Shell Process (if Python/curl writes)"
