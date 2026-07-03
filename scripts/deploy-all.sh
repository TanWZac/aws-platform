#!/usr/bin/env bash
# deploy-all.sh — Deploy the full platform in dependency order.
#
# Usage:
#   ./scripts/deploy-all.sh <env>
#   ./scripts/deploy-all.sh dev
#   ./scripts/deploy-all.sh prod
#
# Prerequisites:
#   - AWS CLI configured with credentials for the target environment
#   - Terraform installed (>= 1.6)
#   - Node.js 22+ installed
#   - Docker installed and running
#   - GitHub CLI (gh) installed and authenticated (for triggering Actions)
#
# The script deploys in this order:
#   1. aws-tf         — terraform apply
#   2. aws-python-platform-template — docker build, ECR push, ECS deploy
#   3. aws-web-platform-template    — next build, S3 sync, CloudFront invalidate

set -euo pipefail

ENV="${1:-}"
if [[ -z "$ENV" ]]; then
  echo "Usage: $0 <env>  (dev | stage | prod)"
  exit 1
fi

if [[ "$ENV" == "prod" ]]; then
  echo "⚠️  Deploying to PRODUCTION. Press Enter to continue or Ctrl+C to abort."
  read -r
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_ROOT="$(dirname "$SCRIPT_DIR")"
TF_REPO="${PLATFORM_ROOT}/../aws-tf"
BACKEND_REPO="${PLATFORM_ROOT}/../aws-python-platform-template"
FRONTEND_REPO="${PLATFORM_ROOT}/../aws-web-platform-template"

AWS_REGION="${AWS_REGION:-us-east-1}"

log() { echo "[deploy-all] $*"; }
ssm_get() {
  aws ssm get-parameter \
    --name "/platform/${ENV}/$1" \
    --query Parameter.Value \
    --output text \
    --region "$AWS_REGION"
}

# ── 1. Terraform ──────────────────────────────────────────────────────────────
log "Step 1/3: Terraform apply (env=$ENV)"

if [[ ! -d "$TF_REPO" ]]; then
  echo "ERROR: aws-tf repo not found at $TF_REPO"
  exit 1
fi

pushd "$TF_REPO" > /dev/null
terraform init -input=false
terraform apply -auto-approve -var="environment=${ENV}"
popd > /dev/null

log "Terraform apply complete."

# ── 2. Backend ────────────────────────────────────────────────────────────────
log "Step 2/3: Backend deploy (aws-python-platform-template)"

if [[ ! -d "$BACKEND_REPO" ]]; then
  echo "ERROR: aws-python-platform-template repo not found at $BACKEND_REPO"
  exit 1
fi

ECR_URL=$(ssm_get "ecr-repository-url")
ECS_CLUSTER=$(ssm_get "ecs-cluster-name")
ECS_SERVICE=$(ssm_get "ecs-service-name")
IMAGE_TAG="${ENV}-$(git -C "$BACKEND_REPO" rev-parse --short HEAD)"

log "ECR: $ECR_URL"
log "Image tag: $IMAGE_TAG"

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_URL"

docker build -t "${ECR_URL}:${IMAGE_TAG}" -t "${ECR_URL}:${ENV}-latest" "$BACKEND_REPO"
docker push "${ECR_URL}:${IMAGE_TAG}"
docker push "${ECR_URL}:${ENV}-latest"

aws ecs update-service \
  --cluster "$ECS_CLUSTER" \
  --service "$ECS_SERVICE" \
  --force-new-deployment \
  --region "$AWS_REGION" \
  --output text > /dev/null

log "Waiting for ECS service to stabilise..."
aws ecs wait services-stable \
  --cluster "$ECS_CLUSTER" \
  --services "$ECS_SERVICE" \
  --region "$AWS_REGION"

log "Backend deploy complete."

# ── 3. Frontend ───────────────────────────────────────────────────────────────
log "Step 3/3: Frontend deploy (aws-web-platform-template)"

if [[ ! -d "$FRONTEND_REPO" ]]; then
  echo "ERROR: aws-web-platform-template repo not found at $FRONTEND_REPO"
  exit 1
fi

API_URL=$(ssm_get "api-gateway-url")
S3_BUCKET=$(ssm_get "s3-frontend-bucket")
CF_DIST_ID=$(ssm_get "cloudfront-distribution-id")
APP_NAME="${APP_NAME:-AWS Platform}"

log "API URL: $API_URL"
log "S3 bucket: $S3_BUCKET"

pushd "$FRONTEND_REPO" > /dev/null
NEXT_PUBLIC_API_BASE_URL="$API_URL" \
NEXT_PUBLIC_APP_NAME="$APP_NAME" \
NEXT_PUBLIC_APP_ENV="$ENV" \
  npm run build

aws s3 sync out/ "s3://${S3_BUCKET}" \
  --delete \
  --region "$AWS_REGION" \
  --cache-control "public,max-age=31536000,immutable" \
  --exclude "*.html"

# HTML files must not be cached aggressively
aws s3 sync out/ "s3://${S3_BUCKET}" \
  --delete \
  --region "$AWS_REGION" \
  --cache-control "public,max-age=0,must-revalidate" \
  --include "*.html"

popd > /dev/null

log "Invalidating CloudFront cache..."
aws cloudfront create-invalidation \
  --distribution-id "$CF_DIST_ID" \
  --paths "/*" \
  --region "$AWS_REGION" \
  --output text > /dev/null

log "Frontend deploy complete."

# ── Done ──────────────────────────────────────────────────────────────────────
log "✅ Full platform deploy complete (env=$ENV)"
log "   Frontend: https://$(ssm_get cloudfront-domain)"
log "   API:      $API_URL"
