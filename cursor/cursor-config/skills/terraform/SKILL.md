---
name: terraform
description: >-
  Terraform decision system for infrastructure-as-code. Use for module design, state management,
  coding patterns, refactoring, and project structure decisions. Covers HCL best practices and
  AWS deployment patterns. Do NOT use for other IaC tools (Ansible, CloudFormation, CDK).
metadata:
  author: SHELYOG
  version: 3.1.0
  category: infrastructure
  updated: 2026-05-05
---
# Terraform Decision Engine

Decision rules for Terraform IaC. Not reference material.

- AWS service selection → `skills/aws/`
- This file answers: **how to write, structure, and manage Terraform code**

## Interaction Model
- This skill defines **HCL code patterns, module design, and state management** only
- What AWS services to use → `aws` skill
- Kubernetes resource manifests → `kubernetes` skill
- Helm release configuration → `helm` skill
- CI/CD pipeline for Terraform → `github` skill

---

## Decision Entry Points

| Task | Read sections |
|---|---|
| New module from scratch | MODULE + STRUCTURE + CODING |
| Refactoring existing code | REFACTORING + STATE |
| State issues or migration | STATE |
| Adding resources to existing config | CODING + STRUCTURE |
| Environment promotion | STRUCTURE + STATE |
| Dependency/version management | DEPENDENCIES |
| CI/CD pipeline design | Execution Rules + STRUCTURE |
| Drift detection | Execution Rules + STATE |

---

## Cross-Cutting Rules

| Decision | Domains | Rule |
|---|---|---|
| `sensitive = true` | Coding + Security | All secrets, passwords, tokens — mark sensitive on variables AND outputs |
| `lifecycle.prevent_destroy` | Coding + State | On critical resources (RDS, S3, EKS) — override only with justification |
| `moved` blocks | Refactoring + State | Preferred over `terraform state mv` — declarative, version-controlled |
| Environment separation | Structure + State | Separate state files per environment, same module structure |
| Pin versions | Dependencies + All | Providers, modules, and Terraform CLI — always pin |

---

## Execution Rules

- **Agents NEVER run `terraform apply` or `terraform destroy`** — only `fmt`, `validate`, `plan`
- Always run `terraform init` before plan in CI (idempotent and safe — removes ambiguity)
- CI pipeline: `terraform plan -out=plan.tfplan` on PR (for visibility), regenerate post-merge before apply
- PR plan is for review only, never reused — always regenerate after merge (race conditions from other merges)
- Plan files are valid only for the exact configuration + state they were generated from — any change invalidates
- Use `terraform plan -detailed-exitcode` in CI (exit 0 = no changes, exit 2 = changes present)
- Use `terraform plan` to detect drift — avoid `terraform refresh` (it mutates state silently)
- Drift must be resolved in Terraform code, not manually in cloud console (prevents permanent divergence)
- Never run concurrent applies on same state — always respect state lock, do not bypass unless emergency
- `terraform destroy` follows same workflow as apply: plan destroy → review → apply via CI only
- Avoid targeted destroy (`-target`) unless explicitly required — default is full lifecycle management

**Plan file security**:
- Never commit `.tfplan` files to version control (they contain variable values, resource state, potentially secrets)
- Treat plan files as sensitive CI artifacts — restrict access
- Delete plan files after apply unless required for audit — do not retain longer than necessary

**Infrastructure lifecycle** (full flow):
1. PR: `terraform init` → `terraform fmt` → `terraform validate` → `terraform plan` (visibility)
2. Post-merge CI: `terraform init` → `terraform plan -out=plan.tfplan` → `terraform apply plan.tfplan`
3. Post-apply: verify outputs, monitor via Datadog, delete plan artifact

---

## [MODULE]

**Default**: Use terraform-aws-modules registry modules when available
- Prefer over custom: battle-tested, community-maintained, well-documented
- But validate: maintenance activity, versioning discipline, security posture (not all registry modules are equal)
- Custom modules only when: registry module doesn't support your use case, or you need org-specific abstractions

**Module structure decisions**:
- **If shared across repos** → Separate module repository with versioned releases
- **If repo-local only** → `modules/` directory within the project
- **If thin wrapper over a single resource** → Don't create a module (over-abstraction)

**Module design rules**:
- One logical component per module (e.g., "rds-cluster", not "database-layer")
- Every variable: `description`, `type`, validation block where appropriate
- Every output: `description`, mark `sensitive` if contains secrets
- Use `for_each` for multiple instances — never `count` for complex resources
- Modules must not depend on implicit provider config — pass all dependencies explicitly via variables
- No hidden coupling: module inputs/outputs are the contract

---

## [STATE]

**Default**: S3 backend with DynamoDB locking, encryption enabled
- Separate state per environment (`qa-kritis.hcl`, `prod-kritis.hcl`)
- Never commit `.tfstate` to version control
- Always `terraform plan` after state operations

**State operation decisions**:
- **If renaming a resource** → `moved` block (preferred) or `terraform state mv`
- **If adopting existing infra** → `terraform import` + write matching config
- **If splitting a module** → `moved` blocks for each resource with new address
- **If state is corrupted** → Pull remote state, compare with `terraform show`, fix manually only as last resort

**Backend rules**:
- Enable versioning on state S3 bucket
- DynamoDB table for locking (prevents concurrent operations)
- **Default**: Separate backend config per environment (preferred for isolation)
- Use `-backend-config` flags or `.hcl` files for environment-specific backend settings
- Workspaces only for simple/identical environments — not for critical multi-env setups
- Never hardcode backend credentials — use environment variables or IAM roles

**State coupling rule**:
- Resources in same state are tightly coupled — they change, lock, and plan together
- Split state when: teams differ, lifecycle differs, or blast radius must be reduced
- Prevents: accidental large-scale changes, slow plans, locking contention

**State security**:
- Restrict S3 state bucket access via IAM (only CI + platform engineers)
- State contains secrets + full infra map — treat as sensitive
- Never allow broad read/write access to state bucket
- Enable S3 bucket encryption (SSE-KMS preferred)
- Terraform should NOT be the source of truth for secrets — use external secret managers (AWS Secrets Manager, Vault); Terraform always persists secret values in state
- Avoid logging secrets in provisioners (`local-exec`/`remote-exec`) — logs can expose sensitive values

---

## [CODING]

**Naming**: `snake_case` for all identifiers — resources, variables, outputs, locals
- Prefix resources descriptively: `aws_security_group.eks_nodes`
- Clear names without abbreviations

**Iteration**:
- **Default**: `for_each` with maps/sets (when identity matters or inputs vary)
- **`count`**: Only for identical or conditional resources (e.g., `count = var.enabled ? 1 : 0`)
- **Avoid** `count` when resources have distinct identities (deletion reindexes)
- **Constraint**: `count`/`for_each` keys must be known at plan time — avoid computed values

**Lifecycle**:
- `prevent_destroy` on stateful resources (databases, S3 buckets, KMS keys) — default enabled
- Exception: must be explicitly overridden with justification (otherwise destroys become impossible)
- `ignore_changes` only for externally-managed fields (auto-scaling group size, tags added by external tools) — these are documented, controlled drift exceptions
- `create_before_destroy` for zero-downtime replacements (security groups, IAM policies)

**Variables**:
- Every variable must have `description` and `type`
- Use `validation` blocks for constraints (CIDR format, allowed values)
- Never hardcode values that vary by environment — use variables + tfvars

**Data sources vs resources**:
- Use **data sources** for existing/external resources (read-only lookup)
- Use **resources** only for infrastructure you manage — prevents accidental recreation or state conflicts

**Dependencies**:
- Prefer explicit references (resource attributes) over implicit ordering
- Use `depends_on` only when no data flow exists between resources (last resort)

**Provider aliases**:
- Use for multi-region or multi-account setups (`provider = aws.secondary`)
- Pass explicitly to modules via `providers` block — never rely on implicit inheritance

**Outputs**:
- Export what downstream configs or modules need — nothing more
- Mark `sensitive = true` for any secret-containing output

---

## [STRUCTURE]

**Project layout** (this project):
```
provisioning/terraform/aws/
├── base/                # Core infrastructure (VPC, EKS, RDS)
│   ├── locals.tf        # Environment-specific values
│   ├── variables.tf     # Input parameters
│   ├── providers.tf     # Provider configuration
│   ├── vpc.tf           # Network resources
│   ├── eks.tf           # Kubernetes cluster
│   ├── rds_clusters.tf  # Database resources
│   └── outputs.tf       # Exported values
├── k8s/                 # Kubernetes platform components
├── qa-kritis.hcl        # QA environment backend
├── prod-kritis.hcl      # Production backend
└── mgmt-kritis.hcl      # Management backend
```

**File organization decisions**:
- **If <5 resources of same type** → Single file by resource type (`vpc.tf`, `rds.tf`)
- **If >5 resources of same type** → Split by logical group (`rds_clusters.tf`, `rds_monitoring.tf`)
- **Always separate**: `providers.tf`, `variables.tf`, `outputs.tf`, `locals.tf`

---

## [REFACTORING]

- **Rename resource** → `moved` block (declarative, appears in plan)
- **Move to module** → `moved` block with module address
- **Split state** → Use `terraform state mv` to move resources between states
- **Import existing** → `terraform import` + write config that matches current state

**Rules**:
- Always run `terraform plan` after refactoring — must show zero changes if done correctly
- Use `moved` over manual state manipulation whenever possible
- Remove `moved` blocks after successful apply across all environments (they are temporary migration instructions)
- Never delete and recreate stateful resources — always move/import

---

## [DEPENDENCIES]

**Provider pinning**:
- Use pessimistic constraint: `~> 5.0` (allows 5.x, blocks 6.0)
- Lock file (`.terraform.lock.hcl`) committed to version control
- Update with `terraform init -upgrade` — review changelog before merging

**Module version pinning**:
- Registry modules: exact version or pessimistic (`~> 7.0`)
- Git modules: tag reference (never branch — not reproducible)
- Always review module changelogs before upgrading

**Terraform CLI version**:
- Pin with `required_version = "~> 1.9"` in providers.tf
- Team uses same version via `.terraform-version` or `tfenv`

---

## Anti-Patterns (Never Do)

| Anti-Pattern | Why It's Wrong | Do This Instead |
|---|---|---|
| `.tfstate` in git | Secrets exposed, merge conflicts, corruption | S3 backend with encryption |
| Hardcoded values across envs | Drift, copy-paste errors, unmaintainable | Variables + environment tfvars |
| `count` for complex resources | Deletion reindexes, causes destroy/recreate | `for_each` with maps |
| Unpinned provider versions | Breaking changes on next init | Pessimistic constraint `~> X.0` |
| Manual `terraform state` commands | Error-prone, not version-controlled | `moved` blocks |
| Inline blocks for reusable config | Duplication, inconsistency | Separate resources or modules |
| No `description` on variables | Unreadable, undocumented config | Always include description |
| `lifecycle.ignore_changes = all` | Hides real drift, masks problems | Ignore only specific fields |
| Monolithic state file | Slow plans, blast radius, locking contention | Split by component/environment |
| `terraform apply -auto-approve` | No human review, dangerous | Always review plan first |

---

## Troubleshooting Decision Trees

**Provider version conflict?**
1. Run `terraform providers` to see current versions
2. Check `.terraform.lock.hcl` for locked versions
3. Run `terraform init -upgrade` to update
4. If still failing → check constraint compatibility in `required_providers`

**State lock error?**
1. Is someone else running? → Wait
2. Stale lock? → Verify no operation running, then `terraform force-unlock` (with caution)
3. DynamoDB table accessible? → Check IAM permissions

**Plan shows unexpected changes?**
1. External modification? → Check CloudTrail for manual changes
2. Provider upgrade changed behavior? → Pin to previous version, review changelog
3. `ignore_changes` missing? → Add for externally-managed fields
4. State drift? → Run `terraform plan` to see actual vs expected (avoid `terraform refresh` — it mutates state)

**Import not matching?**
1. Resource ID correct format? → Check provider docs for ID format
2. Config matches actual state? → Use `terraform show` after import to see actual values
3. Nested blocks different? → Align config with imported state, then modify in next apply

---

## Deep Reference (load only when needed)

- `references/hcl-language-reference.md` — HCL syntax, expressions, type system, functions
- `references/cli-commands-reference.md` — Full CLI command reference
- `references/modules-and-providers.md` — Module design, provider config, registry
- `references/documentation-links.md` — Official Terraform documentation URLs
