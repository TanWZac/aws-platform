# Authentication & Authorisation Matrix

## Who authenticates with what, and when

| Caller | Target | Mechanism | When active | Where configured |
|---|---|---|---|---|
| Browser (user) | API Gateway | JWT (Cognito / OIDC) | `enable_jwt_authorizer = true` | API Gateway JWT authorizer |
| Browser (user) | ALB (direct, no GW) | None | `enable_api_gateway = false` | — |
| Frontend CI | S3 + CloudFront | IAM role (OIDC) | Always | GitHub OIDC → AWS role |
| Backend service | Secrets Manager | IAM task role | When `task_role_arn` set | ECS task definition |
| Backend service | SageMaker | IAM task role | When `task_role_arn` set | ECS task definition |
| External client / service | FastAPI `/api/v1/*` | `X-API-Key` header | `AUTH_ENABLED = true` | `API_KEYS` env var (SSM SecureString) |
| ECS agent | ECR | IAM execution role | Always | `AmazonECSTaskExecutionRolePolicy` |
| ECS agent | CloudWatch Logs | IAM execution role | Always | `AmazonECSTaskExecutionRolePolicy` |

---

## Decision: when to enable API Gateway

```
Need JWT / OAuth?          → enable_api_gateway = true  + enable_jwt_authorizer = true
Need throttling per-route? → enable_api_gateway = true
Need custom domain?        → enable_api_gateway = true  (or ALB with ACM cert)
Internal service only?     → enable_api_gateway = false (use X-API-Key on FastAPI)
```

**Important**: enabling API Gateway mid-flight changes `NEXT_PUBLIC_API_BASE_URL`.
This requires a frontend rebuild. Plan the cutover as:
1. Apply Terraform with `enable_api_gateway = true`
2. Note the new API Gateway URL from `terraform output`
3. Update SSM `/platform/{env}/api-gateway-url`
4. Redeploy the frontend (CI picks up the new URL from SSM)

---

## X-API-Key lifecycle

| Stage | Action |
|---|---|
| Provisioning | Generate key → store in SSM `/platform/{env}/api-keys` as SecureString |
| Injection | ECS task reads from SSM via `container_secrets` in task definition |
| Rotation | Update SSM value → trigger ECS service update (new task revision picks it up) |
| Revocation | Remove key from SSM value → redeploy |

**Rotation time**: ~90 seconds (ECS health check grace period + stabilisation).

---

## Service-to-service auth (backend calling AWS services)

All AWS API calls from the ECS task use the **task role IAM policy** — not env vars or hardcoded credentials.

To add a new AWS service permission:
1. Create an IAM role with the required policy
2. Pass its ARN as `task_role_arn` to the `service` module in `main.tf`

Do **not** pass AWS credentials as environment variables to the container.

---

## Auth when API Gateway is disabled

When `enable_api_gateway = false`:
- The ALB is internet-facing with no auth at the load balancer layer
- WAF rate limiting applies (2000 req/5min per IP)
- FastAPI enforces `X-API-Key` when `AUTH_ENABLED = true`
- There is **no JWT validation** — callers with a valid API key have full access

This is acceptable for internal or service-to-service use cases. It is **not** suitable for user-facing APIs without an additional auth layer.
