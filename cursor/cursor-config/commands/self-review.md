# Self Review

Use this command before opening a PR. Performs a comprehensive read-only review of all changes on the current branch compared to `main`.

## Phase 1: Change Detection

```bash
# Branch context
git branch --show-current
git log --oneline main..HEAD
git diff main...HEAD --stat

# Staged and unstaged
git diff --cached --stat
git diff --stat
```

Summarize: how many files changed, what types (`.tf`, `.yaml`, `.md`, workflow files), and which logical areas are affected.

## Phase 2: Static Analysis

Run checks based on file types changed:

### Terraform Files
- `terraform fmt -check -recursive`
- `terraform validate`
- `checkov -d .` or `tfsec .`

### YAML / Helm Values
- Validate YAML syntax
- Check for hardcoded secrets or plain-text credentials
- Verify Helm values match expected schema

### GitHub Actions Workflows
- Check `permissions` is explicitly set (not default)
- Verify actions are pinned to SHA (not tags)
- Check for untrusted input in `run:` blocks
- Verify OIDC is used for cloud auth (no stored credentials)

### Kubernetes Manifests
- Containers run as non-root
- Resource requests/limits are set
- SecurityContext is configured
- Network Policies exist

### General
- Search for hardcoded secrets: API keys, passwords, tokens
- Check `.gitignore` covers sensitive files
- Verify no `.tfstate` or `.env` files are staged

## Phase 3: Diff Analysis

Analyze `git diff main...HEAD` and categorize findings:

### Critical (must fix before merge)
- Security vulnerabilities (hardcoded secrets, `0.0.0.0/0` ingress, IAM `*` actions)
- Bugs (wrong resource references, missing dependencies, broken interpolation)
- Breaking changes (resource recreation, state-affecting renames without `moved` blocks)

### Recommended (should fix)
- Missing `description` on Terraform variables
- Missing `lifecycle` blocks on critical resources
- Missing PodDisruptionBudgets on production deployments
- Overly broad IAM permissions that could be scoped tighter

### Optional (nice to have)
- Naming inconsistencies
- Missing comments on non-obvious configurations
- Minor formatting issues

## Phase 4: Review Report

```markdown
## Self Review: [branch-name]

### Summary
[X files changed, Y commits, main themes]

### Static Analysis Results
- Terraform fmt: [Pass/Fail]
- Terraform validate: [Pass/Fail]
- Security scan: [Pass/Fail with findings]
- Secrets scan: [Pass/Fail]

### Critical Issues
- [File:line] Issue description → Fix: [suggestion]

### Recommended Improvements
- [File:line] Issue description → Suggestion: [improvement]

### Optional Enhancements
- [Brief list]

### Checklist
- [ ] No hardcoded secrets
- [ ] IAM policies follow least privilege
- [ ] Encryption enabled on all data stores
- [ ] Variables have descriptions and types
- [ ] Resources follow naming conventions
- [ ] Plan output reviewed for unexpected changes
```

## Constraints

**DO NOT:**
- Modify any files (read-only analysis)
- Commit, push, or create PRs
- Switch branches

**DO:**
- Focus only on changed files
- Provide actionable, specific feedback with file references
- Prioritize: Critical → Recommended → Optional
- Reference relevant rules and skills for standards
