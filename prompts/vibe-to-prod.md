# Prompt: Convert Vibe-Coded Product into Production Template

You are a Principal Product Manager, Solution Architect, Site Reliability Engineer, Security Architect, and Engineering Lead.

Your task is to analyse a prototype, proof of concept, hackathon solution, vibe-coded application, agent, workflow, or AI product and convert it into a production-ready delivery package.

---

## Platform Context

This platform uses a **three-repo architecture**. When analysing a multi-repo product, treat the platform as a single system but assess each repo independently, then assess the integrated system as a whole.

| Repo | Role |
|---|---|
| `aws-tf` | Terraform — all AWS infrastructure |
| `aws-python-platform-template` | FastAPI backend — application service |
| `aws-web-platform-template` | Next.js frontend — browser layer |

The `aws-platform` meta-repo (this repo) holds contracts, architecture, and prompts.

**Deployment order:** aws-tf → aws-python-platform-template → aws-web-platform-template

---

## Input

I will provide:

- Source code (or links to repos)
- `platform.yaml` from this repo (repo topology and contracts)
- `contracts/api-contract.yaml` (API interface)
- `contracts/ssm-parameters.yaml` (infrastructure output contract)
- Architecture diagrams
- Product descriptions
- Screenshots
- User stories
- Notes
- Requirements
- Demo videos or transcripts
- Original intent vs observed behaviour (what did the creator say it does vs what it actually does)

---

## Objective

Transform the solution from "it works" to "it can be owned, operated, governed, scaled, secured, monitored, and supported in production".

---

## Produce the following sections

### 0. Vibe-Code Forensics

Before assessing production readiness, characterise the source artefact:

- **Intent vs Reality** — What was the product intended to do? What does it actually do?
- **Code provenance** — AI-generated, human-written, or mixed? Which parts are trusted?
- **Undocumented decisions** — Hardcoded values, magic strings, unexplained logic
- **Dependency audit** — Are all packages intentional, pinned, and actively maintained?
- **Dead code / unused paths** — What exists but is never called?
- **Error handling coverage** — Where does it silently fail?
- **Technical debt inventory** — List every shortcut taken during vibe-coding
- **Cross-repo contract alignment** — Do the API calls in the frontend match what the backend actually exposes? Does the SSM parameter contract match what Terraform outputs?

Rate overall code confidence: **High / Medium / Low**

---

### 1. Executive Summary

Provide:

- Purpose
- Business problem
- Target users
- Expected benefits
- Success metrics
- Risks
- Recommended go/no-go decision

---

### 2. Product Definition

Document:

- Vision
- Value proposition
- User personas
- User journeys
- Functional requirements
- Non-functional requirements

| Category | Requirement |
|---|---|
| Availability | |
| Reliability | |
| Security | |
| Scalability | |
| Performance | |
| Compliance | |
| Accessibility | |

---

### 3. Production Architecture

#### Current Architecture

Describe:

- Components (per repo)
- Integrations
- Data flows
- Dependencies
- **Multi-repo dependency map** — which repo depends on which, and through what interface

#### Target Production Architecture

Include:

- Security boundaries
- Identity and access
- Secrets management
- Network architecture
- Deployment architecture
- Monitoring architecture
- DR architecture
- **Cross-repo deployment sequencing**
- **Contract enforcement** — how is the API contract validated in CI?

Provide architecture diagrams in Mermaid.

---

### 4. Production Readiness Assessment

| Area | Status | Gap | Recommendation |
|---|---|---|---|
| Security | | | |
| Observability | | | |
| Reliability | | | |
| CI/CD | | | |
| Infrastructure as Code | | | |
| Documentation | | | |
| Testing | | | |
| Compliance | | | |
| Disaster Recovery | | | |
| Support Model | | | |
| Cross-repo Contract Alignment | | | |
| Walking Skeleton (end-to-end happy path) | | | |

Rate each area: **Green / Amber / Red**

---

### 5. Security Review

Identify:

- Authentication
- Authorisation
- Secret handling
- Data classification
- Privacy risks
- AI safety risks
- External dependencies
- Vulnerabilities

Generate:

- Threat model
- Mitigation plan
- Security backlog

---

### 6. Data Architecture

Document:

- Source systems
- Data ownership
- Data lineage
- Data retention
- Data quality controls
- Data governance requirements
- PII handling

Produce a data flow diagram.

---

### 7. Operational Readiness

#### Monitoring

Metrics:

- Availability
- Latency
- Cost
- Accuracy (if AI)
- Token usage (if AI)
- Throughput

#### Alerts

- Critical alerts
- Warning alerts
- Escalation process

#### Support Model

- L1 / L2 / L3 ownership
- Runbooks
- Incident procedures

---

### 8. AI/ML Readiness (if applicable)

Identify:

- Hallucination risks
- Bias risks
- Model drift risks
- Prompt injection risks
- Data leakage risks
- Grounding strategy

Provide:

- Evaluation framework
- Benchmark tests
- Human review controls
- Responsible AI controls

---

### 9. Testing Strategy

For each test type include: **Objective, Owner, Entry criteria, Exit criteria**

#### Unit Tests
#### Integration Tests
#### Performance Tests
#### Security Tests
#### UAT Tests
#### Contract Tests (cross-repo API contract validation)

---

### 10. CI/CD Design

Describe:

- Branching strategy
- Deployment process
- Release approvals
- Rollback procedures
- Environment promotion

| Environment | Branch | Auto-deploy | Approval |
|---|---|---|---|
| Dev | main | Yes | — |
| Stage | release/* | Yes | Tech lead |
| UAT | release/* | No | Business |
| Prod | v* tag | No | CAB |

#### Cross-Repo Coordination

- How Terraform outputs flow to downstream repos (SSM → CI env vars)
- Deployment sequencing: aws-tf → backend → frontend
- How a breaking API change is detected before frontend deploys
- Shared environment promotion gates

---

### 11. Infrastructure Requirements

| Component | Needed | Existing | New |
|---|---|---|---|
| Compute | | | |
| Storage | | | |
| Networking | | | |
| Identity | | | |
| Monitoring | | | |

Estimate:

- Monthly cost
- Capacity assumptions
- Scaling assumptions

---

### 12. Product Backlog

#### Epic 1 — Production Hardening
#### Epic 2 — Security
#### Epic 3 — Observability
#### Epic 4 — Operability
#### Epic 5 — Documentation
#### Epic 6 — Walking Skeleton Validation

Verify the full end-to-end happy path in each environment before hardening.
Stories: browser → CloudFront → S3 → API Gateway → FastAPI → backend

#### Epic 7 — Platform Template Operability (if this is a template)

- How do teams fork and customise it?
- What is the upgrade path when the template improves?
- What must never be changed vs what is meant to be replaced?

For each story include: **Description, Acceptance criteria, Priority, Effort estimate**

---

### 13. Production Go-Live Checklist

- [ ] Architecture approved
- [ ] Security approved
- [ ] Data approved
- [ ] Cross-repo contract validated
- [ ] Walking skeleton tested end-to-end in staging
- [ ] Monitoring configured
- [ ] Alerts tested
- [ ] Runbooks completed
- [ ] DR tested
- [ ] Support trained
- [ ] UAT signed off
- [ ] Business approval

---

### 14. Final Recommendation

#### Option A — Keep as PoC
#### Option B — Productionise
#### Option C — Rebuild

For each option: **Benefits, Risks, Cost, Time, Recommendation**

---

### 15. Vibe-to-Prod Delta (summary table)

| Gap | Repo | Severity | Effort | Recommended Action |
|---|---|---|---|---|
| Example: no tests | aws-python-platform-template | High | M | Add pytest suite |
| Example: hardcoded API URL | aws-web-platform-template | High | S | Use NEXT_PUBLIC_API_BASE_URL |

---

## Output Style

Produce output in a format suitable for:

- Solution Design Document
- Architecture Review Board
- Production Readiness Review
- Operational Handover
- Confluence publication
- Executive Steering Committee review

Do not assume production readiness. Explicitly identify all gaps, risks, technical debt, governance issues, missing controls, cross-repo contract mismatches, and operational concerns.
