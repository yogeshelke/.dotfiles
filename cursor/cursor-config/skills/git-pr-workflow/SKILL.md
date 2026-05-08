---
name: git-pr-workflow
description: >-
  Automated end-to-end Git workflow that commits changes, pushes branch, creates PR
  with devops-platform team review, and notifies ae_devops Slack channel.
  Use ONLY when user says "pr workflow", "git pr", "create pr workflow", "run pr workflow",
  or explicitly asks to "commit, push and create PR". Do NOT trigger on general PR
  discussions or questions about pull requests.
metadata:
  author: SHELYOG
  version: 2.0.0
  category: automation
  updated: 2026-05-05
  mcp-server: user-slack
---
# Git PR Workflow

Automates: commit → push → PR → Slack notification with mandatory approval gates.

## When to Use

Trigger ONLY on these phrases:
- "pr workflow" / "git pr" / "create pr workflow" / "run pr workflow"
- "Commit, push and create PR"

**DO NOT trigger** on casual PR mentions or PR questions.

---

## Safety Gate (MANDATORY)

Before running `git commit`, `git push`, `gh pr create`, or Slack notification:

1. Show `git status` and `git diff --stat`
2. Show list of files to be committed
3. Show proposed commit message
4. Show proposed PR title and body
5. Show proposed Slack message
6. **Ask for explicit approval**

**Do not proceed without approval.** No exceptions.

---

## Workflow Steps

### 1. Inspect State

```bash
git status
git diff --stat
git diff --cached --stat
git branch --show-current
```

Verify there are changes to commit. If nothing to commit → inform user and stop.

### 2. Stage Files

- **If files already staged** → Use staged files only
- **If nothing staged** → Ask user which files to stage (show list)
- **Never** run `git add .` without explicit user approval

### 3. Preview and Approve (Safety Gate)

Present the **Preflight Summary** (see templates) and wait for approval.

### 4. Commit Changes

```bash
git commit -m "$(cat <<'EOF'
[type]: [brief description]

- [Change 1]
- [Change 2]

EOF
)"
```

Commit message rules:
- Conventional types: feat, fix, refactor, docs, chore
- First line under 50 characters
- Bullet points for details
- Focus on WHY and WHAT

### 5. Push Branch

```bash
git push -u origin HEAD
```

If push fails → stop and report state (commit succeeded, push failed). Do not retry automatically.

### 6. Create PR

```bash
gh pr create \
  --title "[Descriptive PR Title]" \
  --body "$(cat <<'EOF'
## Summary
- [Key change]
- [Important modification]

## Test plan
- [ ] [Testing step 1]
- [ ] [Validation step]

EOF
)" \
  --reviewer team:fielmann-ag/devops-platform
```

### 7. Send Slack Notification

Use MCP Slack tool (`user-slack` server, `conversations_add_message`):

```
Hi Team, Kindly review PR made in [REPOSITORY_NAME]
Changes: [One-line summary]
PR: [PR_URL]
```

Channel: `#ae_devops`

---

## Error Handling

| Failure point | State | Action |
|---|---|---|
| No changes to commit | Clean | Inform user, stop |
| Push fails | Commit exists locally | Report state, suggest manual fix |
| PR creation fails | Branch pushed | Check for existing PR, report |
| Slack fails | PR created | Warn user, provide PR URL anyway |

**Rules**:
- If any step fails → stop immediately and report current state
- Provide what succeeded and what failed
- Suggest manual recovery steps
- Partial states are acceptable — do not attempt to "undo" completed steps

---

## MCP Tool Integration

### Slack (`user-slack` server):
- Tool: `conversations_add_message`
- Channel: `#ae_devops`
- Read schema before first use

---

## Configuration

| Setting | Value |
|---|---|
| Team reviewer | `team:fielmann-ag/devops-platform` |
| Slack channel | `#ae_devops` |
| Slack format | 3-line message (repo, changes, PR URL) |

For different teams/channels, modify `--reviewer` and channel accordingly.

## References

- [GitHub CLI (gh) Manual](https://cli.github.com/manual/)
- [gh pr create](https://cli.github.com/manual/gh_pr_create)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Pull Request Documentation](https://docs.github.com/en/pull-requests)
- [GitHub Branch Protection Rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-a-branch-protection-rule)
