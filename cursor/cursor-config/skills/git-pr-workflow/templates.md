# Git PR Workflow Templates

## Preflight Approval Summary

Present this before executing any write operations:

```
┌─────────────────────────────────────────────┐
│ PR WORKFLOW PREFLIGHT                       │
├─────────────────────────────────────────────┤
│ Repository: [repo name]                     │
│ Branch:     [current branch]                │
│ Files:      [count] changed                 │
├─────────────────────────────────────────────┤
│ Changed files:                              │
│   M  [file1]                                │
│   A  [file2]                                │
│   D  [file3]                                │
├─────────────────────────────────────────────┤
│ Commit message:                             │
│   [type]: [brief description]               │
│   - [change 1]                              │
│   - [change 2]                              │
├─────────────────────────────────────────────┤
│ PR title: [title]                           │
│ PR body:                                    │
│   ## Summary                                │
│   - [key change]                            │
│   ## Test plan                              │
│   - [ ] [test step]                         │
├─────────────────────────────────────────────┤
│ Slack (#ae_devops):                         │
│   Hi Team, Kindly review PR made in [repo]  │
│   Changes: [one-line summary]               │
│   PR: [will be filled after creation]       │
├─────────────────────────────────────────────┤
│ Actions pending approval:                   │
│   1. git commit                             │
│   2. git push -u origin HEAD                │
│   3. gh pr create                           │
│   4. Slack notification                     │
└─────────────────────────────────────────────┘

Proceed? (yes/no)
```

---

## Commit Message Template

```bash
git commit -m "$(cat <<'EOF'
[type]: [brief description]

- [Specific change 1]
- [Specific change 2]
- [Specific change 3]

EOF
)"
```

Types: `feat`, `fix`, `refactor`, `docs`, `chore`, `ci`, `test`

---

## PR Body Template

```markdown
## Summary
- [Key change or feature]
- [Important modification]

## Test plan
- [ ] Verify [specific functionality]
- [ ] Test [integration point]
- [ ] Validate [configuration/deployment]
```

---

## Slack Message Template

```
Hi Team, Kindly review PR made in [REPO_NAME]
Changes: [One line summary of key changes]
PR: [PR_URL]
```

---

## Useful Commands

```bash
git status                              # current state
git diff --stat                         # unstaged changes summary
git diff --cached --stat                # staged changes summary
git branch --show-current               # current branch
basename $(git remote get-url origin) .git  # repo name
```
