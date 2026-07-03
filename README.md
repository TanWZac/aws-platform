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

## Getting started

[`docs/getting-started.md`](docs/getting-started.md) — Step-by-step guide: prerequisites → bootstrap → infrastructure → backend → frontend → CI/CD → Claude Code tooling → day-2 operations.

---

## Contributing

1. Changes to the API contract → update `contracts/api-contract.yaml` and open PRs in both `aws-python-platform-template` and `aws-web-platform-template`
2. New infrastructure outputs → update `contracts/ssm-parameters.yaml` and the consuming repo's env var docs
3. New repos → add to `platform.yaml` and this README

---

## Claude Code Setup (one-time per machine)

All repos ship `CLAUDE.md`, `.mcp.json`, `.claudeignore`, and `.graphifyignore`. The tools below must be installed once before they activate.

### Terminal installs

```bash
# 1. headroom — compresses tool output (bash, test results, logs) before it reaches Claude
pip install headroom

# 2. graphify — builds a queryable knowledge graph so Claude reads a graph query
#    instead of raw files. Run once per machine, then /graphify . once per repo.
uv tool install "graphifyy[terraform,sql]"
graphify install          # registers the skill with Claude Code globally
```

After installing graphify, open Claude Code in each repo and run:
```
/graphify .
```
Then commit `graphify-out/` so the whole team starts with a map:
```bash
git add graphify-out/ && git commit -m "Add knowledge graph" && git push
```

### Claude Code plugin installs (two separate prompts each)

```
/plugin marketplace add DietrichGebert/ponytail
/plugin install ponytail@ponytail
```

```
/plugin marketplace add thedotmack/claude-mem
/plugin install claude-mem@claude-mem
```

### What each tool does

| Tool | Reduces | Improves |
|---|---|---|
| Mandarin `CLAUDE.md` | ~35% instruction tokens | — |
| `.claudeignore` | Irrelevant file context | — |
| **headroom** | 60–95% of tool output tokens | Signal-to-noise on test/log output |
| **Context7** (auto via `.mcp.json`) | Hallucination correction loops | Accurate library API docs |
| **Ponytail** | ~20% cost, ~27% time | Avoids over-engineering |
| **Graphify** | Raw file reads → graph queries | Codebase understanding |
| **claude-mem** | Re-exploration per session | Persistent cross-session memory |
| `/compact` (workflow) | Long-session context drift | Attention on recent context |
