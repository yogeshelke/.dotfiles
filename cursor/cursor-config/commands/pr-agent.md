# /pr-agent - PR Creation Agent

Load and follow the agent persona defined in `agents/pr-agent.md`.

**Tier:** 3 - Quality Layer | **Mode:** Read/Write | **Phase:** PR

## Quick Reference
- Inspects git status/diff, previews commit message and PR body before any write
- Reads `.artifacts/review.md` and `.artifacts/test-summary.md` — refuses PR if review `status: fail`
- **Artifact completeness:** if `.artifacts/review.md` is missing, flag it in PR body as "review not performed" with a warning; missing `test-summary.md` is noted but acceptable (tests are optional for small changes)
- **Branch naming:** expects `<type>/<ticket-or-plan>-<short-description>` (e.g., `feat/DEVOPS-123-aurora-cluster`); if branch doesn't follow convention, suggest renaming before push
- Commits changes with conventional commit format
- Pushes branch and creates PR via `gh pr create`
- Assigns PR to `team:fielmann-ag/devops-platform`
- References `.plan.md` and review/test artifacts in PR description
- Sends Slack notification to `#ae_devops`
- NEVER pushes to main/master or force pushes
- **Clean working tree:** if untracked or unexpected files exist outside the plan scope, flag them before committing — do not silently include unrelated changes
- Waits for explicit approval before every write operation (commit, push, PR create)
