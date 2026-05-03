# Check Progress

Use this command to review current work progress, fix formatting issues, and get a status summary. Does not stage or commit.

## Phase 1: Change Detection

```bash
git branch --show-current
git diff --cached --name-only
git diff --name-only
git log --oneline main..HEAD
```

- Count files by type (`.tf`, `.yaml`, `.md`, workflow files)
- Identify which plan (if any) these changes relate to
- Check plan status header for current state

## Phase 2: Quality Fixes (Auto-fix Only)

Fix formatting issues on modified files only:

### Terraform
- Run `terraform fmt -recursive` (auto-fixes formatting)
- Run `terraform validate` (report errors)

### YAML
- Validate syntax on changed `.yaml`/`.yml` files

### Markdown
- Check formatting on changed `.md` files

Report what was fixed.

## Phase 3: Change Analysis

Review `git diff` (staged + unstaged) and categorize:

### Critical Issues (fix before commit)
- Security: hardcoded secrets, overly permissive IAM, missing encryption
- Bugs: broken references, missing dependencies, invalid interpolation
- Breaking: resource recreation, state drift, missing `moved` blocks

### Recommended (fix before PR)
- Missing variable descriptions or types
- Missing lifecycle blocks on critical resources
- Inconsistent naming

### Optional (nice to have)
- Documentation gaps
- Minor formatting

## Phase 4: Progress Summary

```markdown
## Progress Summary

### Branch
- Branch: [name]
- Commits ahead of main: [count]

### Files Modified
- [count] Terraform files
- [count] YAML/Helm files
- [count] Workflow files
- [count] Other files

### Changes Summary
[What was done and why, grouped by logical area]

### Quality Check Results
- terraform fmt: [Pass/Fixed X files]
- terraform validate: [Pass/Fail]
- YAML syntax: [Pass/Fail]
- Secrets scan: [Clean/Found X issues]

### Issues Found
**Critical:** [count] — [brief list]
**Recommended:** [count] — [brief list]
**Optional:** [count]

### Plan Status
- Related plan: [plan file name or "none"]
- Tasks completed: [X/Y]
- Next task: [description]
```

## Phase 5: Commit Message Proposal

**Only if no Critical issues remain:**

```
<type>(<scope>): <summary>

- <change 1>
- <change 2>
- <change 3>
```

Types: `feat`, `fix`, `refactor`, `chore`, `docs`, `ci`
Scope: module or component name (e.g., `eks`, `vpc`, `datadog`, `ci`)

**If Critical issues found:** list them clearly, do NOT propose a commit message.

## Constraints

**DO NOT:**
- Stage files (`git add`)
- Commit or push
- Modify files outside the current diff

**DO:**
- Auto-fix formatting (terraform fmt, YAML lint)
- Report all findings with file references
- Link progress back to the plan if one exists
- Prioritize: Critical → Recommended → Optional
