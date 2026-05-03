# Quick Reference Templates

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

## PR Body Template
```markdown
## Summary
- [Key change or feature]
- [Important modification]
- [Configuration update]

## Test plan
- [ ] Verify [specific functionality]
- [ ] Test [integration point]
- [ ] Validate [configuration/deployment]
```

## Slack Message Template
```
Hi Team, Kindly review PR made in [REPO_NAME]
Changes: [One line summary of key changes]
PR: [PR_URL]
```

## Common Commands

### Full Workflow
```bash
# 1. Check status
git status

# 2. Commit (if changes not staged)
git add .
git commit -m "[message]"

# 3. Push
git push -u origin HEAD

# 4. Create PR
gh pr create --title "[title]" --body "[body]" --reviewer team:fielmann-ag/devops-platform

# 5. Notify Slack (via MCP tool)
# Use CallMcpTool with user-slack server
```

### Repository Name Extraction
```bash
basename $(git remote get-url origin) .git
```

### Branch Name
```bash
git branch --show-current
```