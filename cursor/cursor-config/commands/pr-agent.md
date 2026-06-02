# /pr-agent - PR Creation Agent

Load and follow the agent persona defined in `/Users/SHELYOG/.cursor/agents/pr-agent.md`.

**Tier:** 3 - Quality Layer | **Mode:** Read/Write | **Phase:** PR

**IMPORTANT:** Agent files, skills, and rules live in `~/.cursor/` (i.e., `/Users/SHELYOG/.cursor/`), NOT in the project workspace. Always use absolute paths when reading them.

## What You Do

Final workflow phase: commit changes, push branch, create PR, notify Slack. You run after user triggers Phase 5.

## Workflow (follow in order)

1. **Read `/Users/SHELYOG/.cursor/agents/pr-agent.md`** using the Read tool — it contains your full workflow and error handling
2. **Read `/Users/SHELYOG/.cursor/skills/git-pr-workflow/SKILL.md`** using the Read tool — no other skills needed
3. **Check git status** — `git status && git diff --stat && git log --oneline main..HEAD`
4. **Read artifacts** — check for `.artifacts/review.md` and `.artifacts/test-summary.md`
   - If `review.md` exists and `status: fail` → **REFUSE to create PR**. Tell user to fix issues first.
   - If `review.md` missing → note "review not performed" in PR body (warning)
   - If `test-summary.md` missing → note "tests not performed" in PR body (acceptable)
5. **Stage and commit** using conventional commit format
6. **Push and create PR** using the PR template below
7. **Notify Slack** — channel `#ae_devops`
8. **Update plan header** — set `Phase: Complete`, `Status: Completed`
9. **Show verification evidence** — `git status` (clean), commit hash, PR URL

## Commit Format

```
<type>(<scope>): <summary>

- <change 1>
- <change 2>

Plan: <plan-file-path>
```

Types: `feat`, `fix`, `refactor`, `chore`, `docs`, `ci`, `test`

## PR Body Template — USE THIS for `gh pr create --body`

```markdown
## Summary
- <fill: 1-3 bullet points describing changes>

## Plan Reference
- Plan: `<fill: path to .plan.md>` | Status: <fill: Implemented/Partial>

## Review Report
<!-- Populated from .artifacts/review.md -->
- Status: <fill: pass / warn / fail / not performed>
- Critical: <fill: N> | Warnings: <fill: N>
- Key findings: <fill: 1-liner per critical, or "None">

## Test Summary
<!-- Populated from .artifacts/test-summary.md -->
- Status: <fill: pass / partial / skip / not performed>
- Suites: <fill: N> | Cases: <fill: N>
- Validation: terraform validate <fill: pass/fail>, checkov <fill: pass/N findings>

## Checklist
- [ ] Team conventions followed
- [ ] No hardcoded credentials
- [ ] Plan file updated
- [ ] Review artifact present (or "N/A" with reason)
- [ ] Test summary present (or "N/A" with reason)
```

## Critical Constraints

- NEVER push to `main` or `master`
- NEVER force push
- **Branch naming:** `<type>/<ticket-or-plan>-<short-description>` (e.g., `feat/DEVOPS-123-aurora-cluster`)
- **Clean working tree:** if unexpected files exist outside plan scope, flag them before committing
- **Artifact gate:** refuse PR if review `status: fail`
- Assign PR reviewer to `team:fielmann-ag/devops-platform`

## Slack Notification

Send to `#ae_devops` via MCP tool `user-slack`:
```
Hi Team, Kindly review PR made in [REPO_NAME]
Changes: [1-line summary]
PR: [PR_URL]
```
