# AWS 平台 — Claude 助理指南

## 项目结构
四个仓库组成完整平台，部署顺序固定：
1. `aws-tf` — Terraform 基础设施（VPC、ECS、ALB、API Gateway、Redis）
2. `aws-python-platform-template` — FastAPI 后端（ECS Fargate，端口 8000）
3. `aws-web-platform-template` — Next.js 前端（静态导出，S3 + CloudFront）
4. `aws-platform` — 元仓库（合同、提示词、部署脚本）

## 关键约定
- Terraform：模块化设计，`checks.tf` 保护生产环境，`bootstrap/` 初始化状态后端
- Python：FastAPI + Pydantic Settings，`core/` 层不可修改，`services/` + `repositories/` 层用于业务逻辑
- Next.js：`output: "export"` 静态导出，所有 API 调用使用 `useEffect`，`platformApi` 客户端读取 `NEXT_PUBLIC_API_BASE_URL`
- 合同文件位于 `aws-platform/contracts/`，变更 API 必须先更新合同

## 常用命令
```bash
# Python
pytest                          # 运行测试
ruff check src tests            # 代码检查
ruff format src tests           # 格式化

# Next.js
npm test                        # Vitest 测试
npm run typecheck               # TypeScript 检查
npm run build                   # 静态构建

# Terraform
terraform plan -var-file=environments/dev/terraform.tfvars
terraform apply -var-file=environments/dev/terraform.tfvars
```

## 环境变量
- `NEXT_PUBLIC_API_BASE_URL` — 前端 API 地址（来自 SSM `/platform/{env}/api-gateway-url`）
- `API_KEYS` — 后端认证密钥（逗号分隔，SSM SecureString）
- `AUTH_ENABLED` — 本地默认关闭，非本地默认开启
- `REDIS_HOST` / `REDIS_PORT` — Redis 连接（`enable_redis = true` 时需要）

## 禁止事项
- 禁止在代码中硬编码 AWS 账户 ID 或密钥
- 禁止修改 `core/` 层基础中间件（`CorrelationIdMiddleware`、`SecurityHeadersMiddleware`）
- 禁止跳过 `checks.tf` 中的生产保护检查
- 禁止在前端使用服务端渲染（静态导出限制）
