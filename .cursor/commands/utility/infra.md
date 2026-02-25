---
description: "Create/change infrastructure (Terraform+Docker+AWS; small diffs; always plan+patch)"
---
IN:GOAL=<brief>;SCOPE=<terraform|docker|aws|all>;TARGETS=<opt file list|glob>;CTX=<opt notes|paste>;MODE=plan+patch|patch(def plan+patch)

SAFETY:
  - Read-only commands (terraform plan, docker compose config, aws describe/list, git read commands) can be run directly without asking.
  - Destructive commands (terraform destroy/apply, docker system prune, aws delete-*) must present the exact command and wait for user approval.
  - If the user declines a step, skip it and move to the next.
  - Never hardcode secrets, credentials, or tokens. Use environment variables, SSM, or Secrets Manager.

RULES:-Infrastructure-only change: Terraform files (.tf, .tfvars), Dockerfiles, docker-compose, shell scripts, CI/CD pipelines.-Follow existing project structure; reuse modules/patterns already in the repo.-Small diff discipline: minimal changes; if large, propose Phase1/2/3 in PLAN; implement Phase1 only.-No inline comments unless they clarify non-obvious infra constraints (e.g., AWS limits, port conflicts, dependency ordering).-Keep comments tight; no narration.

TERRAFORM:
  - Prefer modules for reusable resource groups; keep root modules thin.
  - Use variables with descriptions and type constraints; set sensible defaults.
  - Use locals for computed values; avoid repeating expressions.
  - State: always use remote backend (S3+DynamoDB lock or equivalent); never local state in shared envs.
  - Naming: resource names follow <project>-<env>-<resource> convention unless repo already has a pattern.
  - Outputs: expose only what downstream consumers need.
  - Use data sources over hardcoded ARNs/IDs.
  - Pin provider versions.
  - Validate: terraform fmt && terraform validate after changes.

DOCKER:
  - Multi-stage builds when image size matters.
  - Pin base image versions (no :latest in prod).
  - Order layers for cache efficiency: deps before code.
  - Use .dockerignore to exclude build artifacts, docs, tests.
  - Health checks for long-running services.
  - docker-compose: use named volumes, explicit networks, depends_on with condition when available.

AWS:
  - Least privilege IAM policies; no wildcards (*) on actions unless explicitly justified.
  - Tag all resources: project, env, managed_by=terraform.
  - Prefer managed services (RDS, ECS, Lambda) over self-hosted when appropriate.
  - Use parameter store (SSM) or Secrets Manager for config/secrets.

OUTPUT:MODE=plan+patch => PLAN(3-12 bullets,max 1200 chars) then unified diff; MODE=patch => diff only.No commentary outside contract.
PLAN fmt(tight):-Goal:-Scope(terraform/docker/aws):-Targets:-Key changes:-Risks(cost/downtime/security):-Verify commands:

POST(ask mode):
  - Prompt user to run validation for the scope:
    - Terraform: terraform fmt -check && terraform validate && terraform plan
    - Docker: docker build (dry run or targeted) && docker compose config
    - AWS CLI: aws sts get-caller-identity (verify credentials); relevant describe/list commands to confirm state.

LEARNINGS (self-improvement cycle):
  - Before running, read and respect ALL bullets below.
  - After running, if the output required manual fixes or missed something,
    append ONE concise bullet: - <what went wrong> -> <how to avoid it>
  - Keep each bullet to 1 line. No refactors to the command itself.

EX:
  /infra GOAL="Add PostgreSQL RDS instance for dev" SCOPE=terraform TARGETS="infra/**.tf"
  /infra GOAL="Create Dockerfile for the Elixir app" SCOPE=docker
  /infra GOAL="Add ECS service definition" SCOPE=all CTX="App runs on port 4000, needs RDS access"
