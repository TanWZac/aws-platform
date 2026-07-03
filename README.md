# aws-platform

Meta-repository for the AWS Platform. This is the entry point for understanding, deploying, and operating the full platform.

## Repos

| Repo | Role | Deploy Order |
|---|---|---|
| [aws-tf](https://github.com/TanWZac/aws-tf) | Terraform — provisions all AWS infrastructure | 1 |
| [aws-python-platform-template](https://github.com/TanWZac/aws-python-platform-template) | FastAPI backend — application service | 2 |
| [aws-web-platform-template](https://github.com/TanWZac/aws-web-platform-template) | Next.js frontend — browser layer | 3 |

> See [`platform.yaml`](platform.yaml) for the machine-readable version of this map.

---

## Architecture

```
Browser
  └─► CloudFront / S3  (aws-web-platform-template)
        └─► API Gateway / ALB  (aws-tf)
              └─► ECS Fargate  (aws-python-platform-template)
                    └─► RDS / S3 / SageMaker  (aws-tf)
```

Full diagrams: [`architecture/diagrams.md`](architecture/diagrams.md)

---

## Contracts

| Contract | File |
|---|---|
| Backend API (OpenAPI) | [`contracts/api-contract.yaml`](contracts/api-contract.yaml) |
| SSM parameter paths | [`contracts/ssm-parameters.yaml`](contracts/ssm-parameters.yaml) |

The contracts are the **source of truth** shared between repos. When the backend adds an endpoint, update `api-contract.yaml` here first.

---

## Deploying

### Full platform deploy (all envs)

```bash
# Set your environment: dev | stage | prod
export ENV=dev

# Deploy all three repos in order
./scripts/deploy-all.sh $ENV
```

### Individual repo deploy

Each repo has its own CI pipeline. See `.github/workflows/ci.yml` in each repo.

---

## Environments

| Environment | Branch | AWS Account |
|---|---|---|
| dev | `main` | development |
| stage | `release/*` | development |
| prod | tag `v*` | production |

---

## SSM Parameter Contract

Infrastructure (aws-tf) writes outputs to SSM. Backend and frontend read from SSM at deploy time.

See [`contracts/ssm-parameters.yaml`](contracts/ssm-parameters.yaml) for the full list.

---

## Prompts

[`prompts/vibe-to-prod.md`](prompts/vibe-to-prod.md) — Production readiness assessment prompt. Use this when converting a prototype into a production delivery.

---

## Contributing

1. Changes to the API contract → update `contracts/api-contract.yaml` and open PRs in both `aws-python-platform-template` and `aws-web-platform-template`
2. New infrastructure outputs → update `contracts/ssm-parameters.yaml` and the consuming repo's env var docs
3. New repos → add to `platform.yaml` and this README
