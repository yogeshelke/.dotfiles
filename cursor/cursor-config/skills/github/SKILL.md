---
name: github
description: >-
  GitHub and Actions decision system for repository management and CI/CD. Use for branching strategy,
  workflow design, Actions security, environment configuration, and gh CLI workflows.
  Do NOT use for general git operations or non-GitHub CI/CD platforms.
metadata:
  author: SHELYOG
  version: 4.0.0
  category: devops
  updated: 2026-05-05
---
# GitHub and Actions Decision Engine

Decision rules for GitHub repositories and CI/CD pipelines. Not reference material.

- Git PR workflow → `skills/git-pr-workflow/`
- Datadog CI monitoring → `skills/datadog/`
- This file answers: **how to structure repos, secure Actions, and design CI/CD pipelines**

## Interaction Model
- This skill defines **repo structure, Actions pipelines, and CI/CD security** only
- What to deploy (infrastructure) → `aws` skill
- How to write Terraform in CI → `terraform` skill
- How to build container images → `docker` skill
- Monitoring CI/CD health → `datadog` skill
- Actual PR creation automation → `git-pr-workflow` skill

---

## Decision Entry Points

| Task | Read sections |
|---|---|
| Set up new repository | REPOSITORY + BRANCHING |
| Create CI/CD workflow | ACTIONS_WORKFLOW |
| Secure Actions pipeline | ACTIONS_SECURITY |
| Configure deployment environments | ENVIRONMENTS |
| PR/release automation | GH_CLI |

---

<!-- CORE_DECISIONS: Read this section for design choices and constraints -->

## Cross-Cutting Rules

| Decision | Domains | Rule |
|---|---|---|
| Pin actions to SHA | Security + Workflow | Default: full SHA; first-party may use major tags if org allows |
| OIDC for AWS | Security + Environments | No stored AWS credentials — OIDC federation only |
| Explicit permissions | Security + All | Every workflow declares minimum `permissions` block |
| Branch protection | Repository + Security | main/master always protected — require PR + CI pass |
| CODEOWNERS | Repository + All | Define ownership for automated review assignment |
| Pre-merge ≠ deploy | Workflow + Security | Never apply/deploy on `pull_request` — only on push to main |

---

<!-- REFERENCE: Detailed implementation patterns below. Read only when you need specific configs. -->

## [REPOSITORY]

**Branch protection** (mandatory on main):
- Require PR reviews (minimum 1 approval)
- Require status checks to pass (CI must succeed)
- Require linear history (squash or rebase)
- Restrict direct push (only through PRs)

**CODEOWNERS**:
```
*                       @org/platform-team
/provisioning/          @org/devops-platform
/.github/workflows/     @org/devops-platform
```

**Workflow file protection**:
- Changes to `.github/workflows/` require platform/security team approval (CODEOWNERS)
- Never auto-merge workflow changes — workflow = execution engine, compromise = full system compromise
- Review action version changes as security-sensitive (dependency review)

**Rulesets vs branch protection**:
- **Default**: Branch protection rules (simpler, well-understood)
- **If complex conditions** → Rulesets (target patterns, bypass actors)
- **If org-wide standards** → Org-level rulesets

---

## [BRANCHING]

**Strategy selection**:
- **Default**: Trunk-based (main + short-lived feature branches, <3 days)
- **If versioned releases** → GitHub Flow (main + feature + release tags)
- **Avoid**: Git Flow for infrastructure (too complex)

**Branch naming**: `<type>/<ticket>-<short-description>`
- Examples: `feat/PLAT-123-add-rds-module`, `fix/PLAT-456-sg-rule`

---

## [ACTIONS_WORKFLOW]

**Trigger selection**:
- **pull_request** → Pre-merge CI (lint, validate, terraform plan)
- **push to main** → Post-merge deploy (apply, release)
- **workflow_dispatch** → Manual triggers (with inputs)
- **schedule** → Recurring tasks (cleanup, rotation)

**Pre-merge vs post-merge** (critical separation):
- Pre-merge (PR): validate, lint, plan, test — **never apply/deploy**
- Post-merge (main): apply, deploy, release — **only from protected branch**

**Workflow isolation**: Separate CI and CD into different workflow files
- Reduced blast radius, clearer security boundaries, independent failure domains

**Job structure**:
- Shared filesystem state → same job
- Independent + parallelizable → separate jobs
- Sequential with handoff → `needs:` dependency

**Performance**:
- Cache: `actions/cache` for terraform providers, node_modules, pip
- Concurrency: `concurrency: { group: ${{ github.workflow }}-${{ github.ref }}, cancel-in-progress: true }`
- Timeout: Always set `timeout-minutes` (default 6 hours is too long)
- Matrix: multi-environment plans with `fail-fast: false`

---

## [ACTIONS_SECURITY]

**OIDC authentication to AWS**:
```yaml
permissions:
  id-token: write
  contents: read

- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::123456789:role/github-actions-role
    aws-region: eu-central-1
```
- Role trust policy restricts to specific repo + branch

**Action pinning**:
- **Default**: Pin to full commit SHA
- **Exception**: Trusted first-party actions may use major tags if org policy permits
- Requires update strategy: Dependabot or Renovate for SHA bumps
- **Trust rule**: Verify source (owner, repo, commits) before adopting; prefer verified creators or org-owned forks; pin ≠ trust

**Checkout hardening**:
```yaml
- uses: actions/checkout@<sha>
  with:
    persist-credentials: false
```
- Prevents token reuse/leakage in subsequent steps

**`GITHUB_TOKEN` scope**:
- Default can be broad if not explicitly scoped — always define `permissions:` block
- Fork PRs → always read-only regardless of workflow config
- Use minimum scope per job (job-level overrides workflow-level)
- All steps in a job share the same permissions — split jobs if different permissions needed (avoid over-privileged jobs)

**Secrets**:
- Environment-scoped (not repo-wide) for sensitive values
- Never echo/log secrets; never use untrusted input in `run:` blocks (injection risk)

**`pull_request_target` (CRITICAL)**:
- **Never** use with `actions/checkout` of fork PR code
- Runs with write permissions + secrets against untrusted code — known exploit vector
- **Alternative**: `workflow_run` triggered by a separate `pull_request` workflow

**Fork PR behavior**:
- Fork PRs → read-only token, no secrets access
- **Default**: No write permissions for fork workflows
- **Exception**: Only with explicit approval + strict conditions (e.g., labeled by maintainer)

**Self-hosted runners**:
- Access to internal network, host filesystem, stored credentials — high-risk surface
- **Never** run fork PRs on self-hosted runners
- Restrict to: trusted branches, manual approval, or labeled PRs only
- Prefer GitHub-hosted for public/fork workflows

**Cache and artifact safety**:
- Do not save cache on untrusted PR workflows (cache poisoning risk)
- Treat artifacts from other workflows as untrusted input
- Never execute downloaded artifacts without validation
- `workflow_run` + artifacts = known attack path

---

## [ENVIRONMENTS]

**When to use**: Production deploys, user-affecting changes, different secrets per environment

**Protection rules**:
- Required reviewers for production
- Wait timer (optional — gives time to cancel)
- Restrict to specific branches (only `main` → prod)

**Environment secrets**: Scoped per environment — prevents accidental prod secret use in dev

---

## [GH_CLI]

```bash
gh pr create --title "feat: add Aurora module" --body "..." --reviewer team:devops-platform
gh pr merge --squash --auto
gh pr checks
gh release create v1.2.0 --generate-notes
gh pr list --state open --author @me
```

---

## Workflow Lifecycle

```
PR (pre-merge)          Merge (post-merge)       Post-deploy
─────────────────────   ─────────────────────    ─────────────────
lint                    apply / deploy           monitor (Datadog)
validate                release tag              alert on failure
terraform plan          notify Slack             rollback if needed
security scan
```
- This skill owns: PR + Merge phases
- Observability: `skills/datadog/` owns post-deploy
- Rollback: ArgoCD/Helm for apps, Terraform for infra

---

## Execution Guarantees

All workflows must:
- Fail fast on critical errors (no silent continuation)
- Never deploy on `pull_request` events
- Require CI success before merge
- Deploy only from protected branches
- Set explicit `timeout-minutes` on every job

---

## Anti-Patterns

| Anti-Pattern | Do This Instead |
|---|---|
| Actions pinned to tags | Pin to full SHA |
| No `permissions` block | Explicit minimum permissions |
| AWS credentials in secrets | OIDC federation |
| Untrusted input in `run:` | Validate/sanitize inputs |
| No `timeout-minutes` | Always set explicit timeout |
| Direct push to main | Branch protection + PR required |
| No CODEOWNERS | Define per directory/pattern |
| Manual prod deploys without gate | Environment protection rules |
| Repo-wide secrets for prod | Environment-scoped secrets |
| `pull_request_target` + checkout fork | `workflow_run` pattern |
| Deploy on pull_request | Deploy only on push to main |
| CI and CD in same workflow | Separate workflow files |
| Fork PRs on self-hosted runners | GitHub-hosted for untrusted code |
| `persist-credentials: true` | Always set `false` on checkout |
| Cache saved on fork PRs | Restrict cache save to trusted events |

---

## Troubleshooting Decision Trees

**Workflow not triggering?**
1. Event type correct? 2. Branch/path filter matches? 3. Workflow file on default branch? 4. Concurrency cancelling?

**OIDC auth failing?**
1. Role trust policy allows repo/branch? 2. `id-token: write` set? 3. Correct role ARN? 4. OIDC provider configured in AWS?

**Permission error?**
1. `permissions` block too restrictive? 2. Branch protection blocking? 3. Fork PR (read-only token)? 4. Environment approval pending?

---

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [GitHub Actions Marketplace](https://github.com/marketplace?type=actions)
- [GitHub Actions — Starter Workflows](https://github.com/actions/starter-workflows)
- [GitHub Actions Security Hardening](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-for-github-actions)
- [GitHub OIDC for Cloud Providers](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [Reusable Workflows](https://docs.github.com/en/actions/sharing-automations/reusing-workflows)
- [GitHub Environments](https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-deployments/managing-environments-for-deployment)
- [GitHub Actions — Workflow Syntax](https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions)
- [gh CLI Manual](https://cli.github.com/manual/)
