---
name: tfsec-tflint
description: >-
  Terraform static analysis and quality tooling decision system. Use for TFLint ruleset
  configuration, tfsec/trivy scanning, pre-commit-terraform hooks, terraform-docs generation,
  and SARIF/CodeQL integration. Do NOT use for Terraform HCL authoring (use terraform skill)
  or CI/CD pipeline design (use github skill) unless quality-gate-specific.
metadata:
  author: SHELYOG
  version: 1.0.0
  category: quality
  updated: 2026-05-06
---
# Terraform Static Analysis & Quality Tooling Decision Engine

Decision rules for Terraform quality gates: TFLint, tfsec, pre-commit, and terraform-docs.

- Terraform HCL authoring → `skills/terraform/`
- CI/CD pipeline design → `skills/github/`
- Security review checklist → `/reviewer` agent
- This file answers: **how to configure and maintain Terraform quality tooling**

## Interaction Model
- This skill defines **quality gate configuration and scanning patterns** only
- Writing Terraform code → `terraform` skill
- GitHub Actions workflow structure → `github` skill
- Security findings remediation → `aws` or `terraform` skill depending on domain

---

## Decision Entry Points

| Task | Read sections |
|---|---|
| Add quality gates to new repo | PRE_COMMIT + TFLINT + TFSEC |
| Configure TFLint rules | TFLINT |
| Set up tfsec/trivy scanning | TFSEC |
| Generate module documentation | TERRAFORM_DOCS |
| Integrate with GitHub security tab | TFSEC |
| Fix pre-commit failures | PRE_COMMIT + TROUBLESHOOTING |

---

<!-- CORE_DECISIONS: Read this section for design choices and constraints -->

## Cross-Cutting Rules

| Decision | Rule |
|---|---|
| Hook ordering | `terraform_fmt` → `terraform_validate` → `terraform_tflint` → `terraform_docs` |
| Severity treatment | TFLint errors block commit; tfsec Critical/High block merge |
| False positives | Use inline `#tfsec:ignore:RULE_ID` with justification comment, never blanket disable |
| Version pinning | Pin pre-commit hook revs and TFLint ruleset versions in config |

---

<!-- REFERENCE: Detailed implementation patterns below. Read only when you need specific configs. -->

## PRE_COMMIT

### Standard `.pre-commit-config.yaml` Pattern

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: <pinned>
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-merge-conflict

  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: <pinned>
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
        args: ['--hook-config=--retry-once-with-cleanup=true']
      - id: terraform_tflint
        args: ['--args=--config=__GIT_WORKING_DIR__/.tflint.hcl']
      - id: terraform_docs
        args: ['--args=--config=__GIT_WORKING_DIR__/.terraform-docs.yml']

  - repo: https://github.com/koalaman/shellcheck-precommit
    rev: <pinned>
    hooks:
      - id: shellcheck
```

### Decisions

| Scenario | Decision |
|---|---|
| Monorepo with multiple roots | Use `__GIT_WORKING_DIR__` for config paths; TFLint config at repo root |
| Module repo vs environment repo | Same hooks; module repos add `terraform_docs` mandatory |
| CI vs local | pre-commit runs both locally (developer) and in CI (PR check) |
| Hook failures in CI | Fail the PR; show diff for fmt, show findings for tflint/tfsec |

---

## TFLINT

### `.tflint.hcl` Configuration Pattern

```hcl
plugin "aws" {
  enabled = true
  version = "<pinned>"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

config {
  call_module_type    = "local"
  force               = false
  disabled_by_default = false
}
```

### Rule Decisions

| Rule Category | Default | Override When |
|---|---|---|
| AWS instance type validation | Enabled | Never disable |
| AWS region validation | Enabled | Never disable |
| Deprecated resource checks | Enabled | Never disable |
| Naming convention rules | Enabled (snake_case) | Project-specific override with justification |
| Module source pinning | Enabled | Never disable for production |

### TFLint in CI

- Install via `terraform-linters/setup-tflint` action
- Run against changed directories only (use `dorny/paths-filter` for monorepo)
- Cache `.tflint.d/` plugins between runs
- Exit code 2 = findings present → fail the check

---

## TFSEC

### Scanning Patterns

| Pattern | When to use |
|---|---|
| `tfsec .` (local) | Developer pre-push validation |
| `aquasecurity/tfsec-sarif-action` | CI: upload results to GitHub Security tab |
| `aquasecurity/tfsec-pr-commenter-action` | CI: inline PR comments on findings |
| Trivy (`aquasecurity/trivy-action` with `config` scanner) | Successor to tfsec; prefer for new repos |

### SARIF Integration

```yaml
- uses: aquasecurity/tfsec-sarif-action@<sha>
  with:
    sarif_file: tfsec.sarif
- uses: github/codeql-action/upload-sarif@<sha>
  with:
    sarif_file: tfsec.sarif
    category: tfsec
```

### Severity Mapping

| tfsec Severity | Action |
|---|---|
| CRITICAL | Block merge; immediate fix required |
| HIGH | Block merge; fix before review |
| MEDIUM | Warning; fix recommended, reviewer decides |
| LOW | Info; tracked, not blocking |

### Inline Ignores (when justified)

```hcl
resource "aws_s3_bucket" "logs" {
  #tfsec:ignore:aws-s3-enable-versioning -- Log bucket, versioning adds cost without value
  bucket = "platform-logs-${var.environment}"
}
```

---

## TERRAFORM_DOCS

### `.terraform-docs.yml` Pattern

```yaml
formatter: markdown table
header-from: ""
footer-from: ""
recursive:
  enabled: false
output:
  file: README.md
  mode: inject
  template: |-
    <!-- BEGIN_TF_DOCS -->
    {{ .Content }}
    <!-- END_TF_DOCS -->
sort:
  enabled: true
  by: required
settings:
  anchor: true
  color: true
  escape: true
  indent: 2
  required: true
  type: true
```

### Decisions

| Scenario | Decision |
|---|---|
| Module repo | terraform-docs is mandatory; inject into each module's README |
| Environment/root repo | Optional; useful for variable documentation |
| Output format | `markdown table` for readability |
| Sort order | `by: required` — required vars first |

---

## TROUBLESHOOTING

| Problem | Cause | Fix |
|---|---|---|
| TFLint can't find AWS plugin | Plugin not installed | Run `tflint --init` or cache `.tflint.d/` in CI |
| terraform_validate fails in pre-commit | Missing providers/backend | Use `--retry-once-with-cleanup=true` arg |
| tfsec finds in vendored modules | Scanning `modules/.terraform/` | Add `--exclude-path .terraform` |
| terraform-docs not updating README | Missing inject markers | Add `<!-- BEGIN_TF_DOCS -->` markers to README |
| pre-commit hooks slow | Running on all files | Use `files` regex or run on changed files only in CI |

---

## References

- [TFLint Documentation](https://github.com/terraform-linters/tflint)
- [TFLint AWS Ruleset](https://github.com/terraform-linters/tflint-ruleset-aws)
- [tfsec (now Trivy)](https://aquasecurity.github.io/tfsec/)
- [Trivy — Terraform Scanning](https://aquasecurity.github.io/trivy/latest/docs/scanner/misconfiguration/terraform/)
- [pre-commit-terraform](https://github.com/antonbabenko/pre-commit-terraform)
- [terraform-docs](https://terraform-docs.io/)
- [Checkov](https://www.checkov.io/1.Welcome/What%20is%20Checkov.html)
- [SARIF Format for GitHub Code Scanning](https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/sarif-support-for-code-scanning)
