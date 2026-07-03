# Getting Started — AWS Platform Template

Step-by-step guide for taking a new project from zero to a production-ready AWS deployment using the four-repo platform template.

---

## Prerequisites

Install the following on your machine before starting.

| Tool | Version | Install |
|---|---|---|
| AWS CLI | >= 2.x | [docs.aws.amazon.com/cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| Terraform | >= 1.6 | [developer.hashicorp.com](https://developer.hashicorp.com/terraform/install) |
| uv (Python) | any | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| Node.js | >= 22 | [nodejs.org](https://nodejs.org) |
| Docker | any | [docs.docker.com](https://docs.docker.com/get-docker) |
| Git | any | system package manager |

You also need:
- An **AWS account** with an IAM user or role that can create VPCs, ECS clusters, S3 buckets, CloudFront distributions, and Cognito user pools
- A **GitHub account** with four repos forked or cloned from this template
- A **GitHub Personal Access Token** with `repo` scope (for pushing and creating PRs)

---

## Step 1 — Fork or clone the four repos

```bash
# Recommended: fork each repo on GitHub, then clone your forks
git clone https://github.com/<you>/aws-tf
git clone https://github.com/<you>/aws-python-platform-template
git clone https://github.com/<you>/aws-web-platform-template
git clone https://github.com/<you>/aws-platform
```

Keep them as siblings in the same parent directory — the `deploy-all.sh` script expects this layout.

```
zac-playground/
  aws-tf/
  aws-python-platform-template/
  aws-web-platform-template/
  aws-platform/
```

---

## Step 2 — Bootstrap Terraform remote state

The `bootstrap/` module creates the S3 bucket and DynamoDB lock table that all subsequent Terraform runs use as their backend. **Run this once per AWS account.**

```bash
cd aws-tf/bootstrap

# Configure AWS credentials
export AWS_PROFILE=your-profile   # or use environment variables

terraform init
terraform apply
```

Copy the outputs into each environment's backend config:

```bash
# terraform output will show:
#   state_bucket = "platform-ai-tf-state-abcd1234"
#   lock_table   = "platform-ai-tf-locks"

cp environments/dev/backend.hcl.example  environments/dev/backend.hcl
cp environments/stage/backend.hcl.example environments/stage/backend.hcl
cp environments/prod/backend.hcl.example  environments/prod/backend.hcl

# Edit each backend.hcl and replace placeholders with the bootstrap outputs
```

---

## Step 3 — Configure environment variables

Copy and fill in the tfvars files for each environment:

```bash
cp environments/dev/terraform.tfvars.example   environments/dev/terraform.tfvars
cp environments/stage/terraform.tfvars.example environments/stage/terraform.tfvars
cp environments/prod/terraform.tfvars.example  environments/prod/terraform.tfvars
```

Key settings to update in each `terraform.tfvars`:

| Variable | What to set |
|---|---|
| `aws_region` | Your target AWS region (e.g. `ap-southeast-2`) |
| `alarm_email` | Your email address for CloudWatch alert notifications |
| `enable_frontend` | `true` to provision S3 + CloudFront hosting |
| `enable_cognito` | `true` to provision Cognito user pool + app client |
| `cognito_callback_urls` | Your app's OAuth callback URLs |
| `enable_api_gateway` | `true` to put API Gateway in front of the backend |
| `api_gateway_enable_jwt_authorizer` | `true` (requires `enable_cognito = true` first) |
| `api_gateway_jwt_issuer` | Set to the `cognito_issuer_url` output after step 4 |

For `prod` and `stage`, also set:
- `enable_alb_https = true`
- `alb_certificate_arn` — a valid ACM certificate ARN in your region
- `enable_waf = true`

---

## Step 4 — Deploy infrastructure

```bash
cd aws-tf

# Dev environment
terraform init -backend-config=environments/dev/backend.hcl
terraform plan -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars
```

After apply completes, Terraform writes all outputs to SSM Parameter Store automatically (ECR URL, ECS cluster, CloudFront domain, Cognito issuer, etc.). The backend and frontend CI pipelines read from SSM — no manual secret copying required.

**If you enabled Cognito**, confirm your email subscription to the SNS alert topic (check your inbox).

**If you enabled the JWT authorizer**, update `terraform.tfvars` with the Cognito issuer URL:
```bash
# Get the issuer URL
terraform output cognito_issuer_url

# Add to terraform.tfvars:
api_gateway_jwt_issuer   = "https://cognito-idp.<region>.amazonaws.com/<pool-id>"
api_gateway_jwt_audiences = ["<cognito_client_id>"]

# Re-apply
terraform apply -var-file=environments/dev/terraform.tfvars
```

---

## Step 5 — Configure GitHub Environments and Secrets

In each repo on GitHub: **Settings → Environments** — you'll find `dev`, `stage`, and `prod` already created.

For each environment in **aws-python-platform-template** and **aws-platform**, add these secrets:

| Secret | Value | Where to find it |
|---|---|---|
| `AWS_DEPLOY_ROLE_ARN` | IAM role ARN for CI | Create a role with ECS + ECR permissions and OIDC trust for `token.actions.githubusercontent.com` |
| `AWS_OIDC_ROLE_ARN` | Same as above (or a read-only role for plan) | — |

For each environment, add these variables:

| Variable | Value |
|---|---|
| `AWS_REGION` | e.g. `ap-southeast-2` |
| `ECR_REPOSITORY` | From `terraform output ai_ecr_repository_url` |
| `APP_NAME` | Your platform display name |

> **OIDC setup**: Create an IAM OIDC provider for `token.actions.githubusercontent.com` in your AWS account. Then create an IAM role that trusts it, scoped to your GitHub org/repo.

---

## Step 6 — Deploy the backend

```bash
cd aws-python-platform-template

# Copy and fill in your .env.local
cp .env.example .env

# Build and test locally
make install
make test
make docker-run   # verify http://localhost:8000/health/ready
```

Push to `main` to trigger the CI pipeline, or trigger the deploy workflow manually:

```
GitHub → aws-python-platform-template → Actions → Build and Publish Image → Run workflow → dev
```

The workflow will:
1. Build the Docker image
2. Scan it with Trivy (blocks on CRITICAL/HIGH)
3. Push to ECR
4. Update the ECS service and wait for stability

---

## Step 7 — Deploy the frontend

```bash
cd aws-web-platform-template

# Copy and fill in your environment file
cp .env.example .env.local
# Set NEXT_PUBLIC_API_BASE_URL to the API Gateway or ALB URL from SSM

# Test locally
npm install
npm test
npm run build
npm run dev   # verify at http://localhost:3000
```

Push to `main` to trigger CI, or trigger the platform deploy workflow:

```
GitHub → aws-platform → Actions → Platform Deploy → Run workflow
  environment: dev
  component: frontend
```

The workflow will:
1. Run preflight checks (SSM params, backend health)
2. Build the Next.js static export with the correct API URL from SSM
3. Sync to S3
4. Invalidate the CloudFront cache

---

## Step 8 — Verify the deployment

```bash
# Get the CloudFront URL
terraform -chdir=aws-tf output frontend_cloudfront_domain

# Check backend health
curl https://<api-gateway-url>/health/ready
```

Open the CloudFront URL in a browser. You should see:
- Landing page at `/`
- Dashboard at `/dashboard`
- Backend status at `/status` (live API calls to your FastAPI service)
- Health check at `/health`

---

## Step 9 — Set up Terraform git hooks (optional but recommended)

```bash
cd aws-tf
graphify hook install   # auto-rebuild knowledge graph on commit
```

---

## Step 10 — Set up Claude Code AI tooling

Install once on your machine:

```bash
pip install headroom
uv tool install "graphifyy[terraform,sql]"
graphify install
```

In Claude Code (two separate prompts each):
```
/plugin marketplace add DietrichGebert/ponytail
/plugin install ponytail@ponytail
```
```
/plugin marketplace add thedotmack/claude-mem
/plugin install claude-mem@claude-mem
```

Build knowledge graphs for each repo:
```bash
# Open Claude Code in each repo and type:
/graphify .

# Then commit the graph so teammates start with a map
git add graphify-out/ && git commit -m "Add knowledge graph" && git push
```

See [README.md](../README.md#claude-code-setup-one-time-per-machine) for the full tooling table.

---

## Day-2 Operations

### Deploy a new version

```bash
# Full platform (all three repos in order)
./scripts/deploy-all.sh dev

# Individual component
./scripts/preflight-check.sh dev backend
```

### Promote to production

```bash
# Stage first
terraform apply -var-file=environments/stage/terraform.tfvars
./scripts/deploy-all.sh stage

# Then prod (confirmation prompt)
./scripts/deploy-all.sh prod
```

### Rotate the API key

```bash
# Generate a new key and store it in SSM
aws ssm put-parameter \
  --name "/platform/dev/api-keys" \
  --value "new-key-here" \
  --type SecureString \
  --overwrite

# Trigger an ECS service update to pick it up (new task revision reads from SSM)
aws ecs update-service \
  --cluster $(aws ssm get-parameter --name /platform/dev/ecs-cluster-name --query Parameter.Value --output text) \
  --service $(aws ssm get-parameter --name /platform/dev/ecs-service-name --query Parameter.Value --output text) \
  --force-new-deployment
```

### Monitor

```bash
# View CloudWatch dashboard (open in browser)
aws cloudwatch get-dashboard --dashboard-name platform-ai-dev

# Check active alarms
aws cloudwatch describe-alarms --state-value ALARM --region ap-southeast-2
```

---

## Converting a vibe-coded project to production

Use the `vibe-to-prod.md` prompt whenever you need to assess and harden a prototype:

1. Open Claude Code in the `aws-platform` repo
2. Paste the contents of `prompts/vibe-to-prod.md` as your prompt
3. Attach or describe the PoC: source code, architecture, product description
4. Claude will produce: Executive Summary → Security Review → Testing Strategy → Product Backlog → Go-Live Checklist

See [`prompts/vibe-to-prod.md`](../prompts/vibe-to-prod.md) for the full template.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `terraform init` fails with backend error | Run `bootstrap/` first (Step 2) |
| ECS service won't stabilise | Check `/health/ready` returns 200; increase `health_check_grace_period_seconds` |
| CloudFront returns 403 | S3 bucket policy may not be attached yet; re-run `terraform apply` |
| Email subscription not confirmed | Check inbox for SNS confirmation email after first `terraform apply` |
| `graphify: command not found` | Run `uv tool update-shell` and open a new terminal |
| CI fails on `AWS_DEPLOY_ROLE_ARN` | Add the secret to the environment in GitHub → Settings → Environments |
| JWT authorizer returns 401 | Ensure `api_gateway_jwt_issuer` matches the Cognito issuer URL exactly |
