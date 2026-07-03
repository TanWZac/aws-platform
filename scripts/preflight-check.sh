#!/usr/bin/env bash
# preflight-check.sh — Validate all prerequisites before deploying the platform.
#
# Usage:
#   ./scripts/preflight-check.sh <env> [component]
#   ./scripts/preflight-check.sh dev all
#   ./scripts/preflight-check.sh prod backend
#
# Components: all | infrastructure | backend | frontend
#
# Exit codes:
#   0  All checks passed
#   1  One or more checks failed (deploy should not proceed)

set -euo pipefail

ENV="${1:-}"
COMPONENT="${2:-all}"

if [[ -z "$ENV" ]]; then
  echo "Usage: $0 <env> [component]"
  exit 1
fi

AWS_REGION="${AWS_REGION:-us-east-1}"
PASS=0
FAIL=0

# ── Helpers ───────────────────────────────────────────────────────────────────

ok()   { echo "  [PASS] $*"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $*"; FAIL=$((FAIL + 1)); }
info() { echo ""; echo "==> $*"; }

ssm_exists() {
  aws ssm get-parameter --name "$1" --region "$AWS_REGION" \
    --query Parameter.Value --output text > /dev/null 2>&1
}

ssm_get() {
  aws ssm get-parameter --name "$1" --region "$AWS_REGION" \
    --query Parameter.Value --output text 2>/dev/null
}

http_ok() {
  local url="$1"
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
  [[ "$status" =~ ^2[0-9]{2}$ ]]
}

# ── 1. Environment name ───────────────────────────────────────────────────────

info "Checking environment"

if [[ "$ENV" =~ ^(dev|stage|prod)$ ]]; then
  ok "Environment name is valid: $ENV"
else
  fail "Environment '$ENV' is not valid. Must be: dev, stage, or prod"
fi

# ── 2. AWS credentials ────────────────────────────────────────────────────────

info "Checking AWS credentials"

if aws sts get-caller-identity --region "$AWS_REGION" > /dev/null 2>&1; then
  IDENTITY=$(aws sts get-caller-identity --region "$AWS_REGION" --output text \
    --query 'join(`:`,[Account,Arn])' 2>/dev/null)
  ok "AWS credentials valid: $IDENTITY"
else
  fail "AWS credentials are not configured or have expired"
fi

# ── 3. Terraform tools (infrastructure only) ─────────────────────────────────

if [[ "$COMPONENT" == "all" || "$COMPONENT" == "infrastructure" ]]; then
  info "Checking Terraform tools"

  if command -v terraform > /dev/null 2>&1; then
    TF_VER=$(terraform version -json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['terraform_version'])" 2>/dev/null || terraform version | head -1)
    ok "Terraform available: $TF_VER"
  else
    fail "Terraform not found. Install terraform >= 1.6"
  fi
fi

# ── 4. Docker available (backend only) ───────────────────────────────────────

if [[ "$COMPONENT" == "all" || "$COMPONENT" == "backend" ]]; then
  info "Checking Docker"

  if docker info > /dev/null 2>&1; then
    ok "Docker daemon is running"
  else
    fail "Docker daemon is not running or not installed"
  fi
fi

# ── 5. Node.js available (frontend only) ─────────────────────────────────────

if [[ "$COMPONENT" == "all" || "$COMPONENT" == "frontend" ]]; then
  info "Checking Node.js"

  if command -v node > /dev/null 2>&1; then
    NODE_VER=$(node --version)
    ok "Node.js available: $NODE_VER"
  else
    fail "Node.js not found. Install Node.js >= 22"
  fi
fi

# ── 6. SSM parameters (backend + frontend require infra to exist first) ───────

if [[ "$COMPONENT" == "all" || "$COMPONENT" == "backend" || "$COMPONENT" == "frontend" ]]; then
  info "Checking SSM parameters for env=$ENV"

  REQUIRED_SSM=(
    "/platform/${ENV}/api-gateway-url"
    "/platform/${ENV}/ecr-repository-url"
    "/platform/${ENV}/ecs-cluster-name"
    "/platform/${ENV}/ecs-service-name"
    "/platform/${ENV}/s3-frontend-bucket"
    "/platform/${ENV}/cloudfront-distribution-id"
    "/platform/${ENV}/cloudfront-domain"
  )

  for param in "${REQUIRED_SSM[@]}"; do
    if ssm_exists "$param"; then
      ok "SSM param exists: $param"
    else
      fail "SSM param missing: $param  (run infrastructure deploy first)"
    fi
  done
fi

# ── 7. Backend health check (frontend requires backend to be up) ──────────────

if [[ "$COMPONENT" == "all" || "$COMPONENT" == "frontend" ]]; then
  info "Checking backend health"

  if ssm_exists "/platform/${ENV}/api-gateway-url"; then
    API_URL=$(ssm_get "/platform/${ENV}/api-gateway-url")
    if http_ok "${API_URL}/health/ready"; then
      ok "Backend health check passed: ${API_URL}/health/ready"
    else
      fail "Backend health check failed at ${API_URL}/health/ready — ensure backend is deployed and healthy before deploying frontend"
    fi
  else
    fail "Cannot check backend health: SSM /platform/${ENV}/api-gateway-url not found"
  fi
fi

# ── 8. Production-specific gate ───────────────────────────────────────────────

if [[ "$ENV" == "prod" ]]; then
  info "Production deployment gate"

  echo ""
  echo "  ⚠️  You are about to deploy to PRODUCTION."
  echo "  Confirm the following checklist before continuing:"
  echo "    [ ] terraform plan reviewed and approved"
  echo "    [ ] staging deployment validated"
  echo "    [ ] change request / CAB approval obtained"
  echo "    [ ] rollback plan documented"
  echo ""
  read -r -p "  Type 'deploy prod' to confirm: " CONFIRMATION
  if [[ "$CONFIRMATION" == "deploy prod" ]]; then
    ok "Production deployment confirmed by operator"
  else
    fail "Production deployment not confirmed. Aborting."
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "─────────────────────────────────────────────"
echo "  Preflight results: ${PASS} passed, ${FAIL} failed"
echo "─────────────────────────────────────────────"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo "  Deployment blocked. Fix the failures above before proceeding."
  exit 1
else
  echo "  All checks passed. Deployment may proceed."
  exit 0
fi
