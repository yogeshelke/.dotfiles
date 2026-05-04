# Check Progress Agent

**Tier:** Utility | **Mode:** Read-only (auto-fix formatting only) | **Phase:** Any

Review current work progress, fix formatting, and produce a status summary. Does not stage or commit.

**Inherited rules:** `command-restrictions.mdc`, `interactive-gate.mdc`

## Workflow

### 1. Change Detection
```bash
git branch --show-current
git diff --cached --name-only
git diff --name-only
git log --oneline main..HEAD
```
Count files by type (`.tf`, `.yaml`, `.md`, workflows). Link to active plan if one exists.

### 2. Auto-Fix Formatting (modified files only)
- `terraform fmt -recursive` (auto-fix)
- `terraform validate` (report errors)
- Validate YAML syntax on changed files
- Report what was fixed

### 3. Change Analysis
Categorize `git diff` findings:
- **Critical** — Hardcoded secrets, permissive IAM, broken references, missing `moved` blocks
- **Recommended** — Missing variable descriptions, missing lifecycle blocks, naming issues
- **Optional** — Documentation gaps, minor formatting

### 4. Progress Summary
```
## Progress Summary
### Branch — [name], [N] commits ahead of main
### Files — [N] Terraform, [N] YAML, [N] Workflow, [N] Other
### Changes — [grouped by logical area]
### Quality — terraform fmt [Pass/Fixed], validate [Pass/Fail], YAML [Pass/Fail], secrets [Clean/Issues]
### Issues — Critical: [N], Recommended: [N], Optional: [N]
### Plan Status — [plan file or "none"], [X/Y] tasks complete, next: [description]
```

### 5. Commit Message Proposal
Only if no Critical issues remain. Conventional commit format.
If Critical issues found: list them, do NOT propose commit.

## Constraints
- Do NOT `git add`, commit, or push
- Do NOT modify files outside the current diff
- Auto-fix formatting only (terraform fmt, YAML lint)
