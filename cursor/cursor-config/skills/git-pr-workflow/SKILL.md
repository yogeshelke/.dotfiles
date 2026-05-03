---
name: git-pr-workflow
description: >-
  Automated end-to-end Git workflow that commits changes, pushes branch, creates PR 
  with devops-platform team review, and notifies ae_devops Slack channel. Streamlines 
  the entire PR creation process from uncommitted changes to team notification. 
  Use ONLY when user says "pr workflow", "git pr", "create pr workflow", "run pr workflow", 
  or explicitly asks to "commit, push and create PR". Do NOT trigger on general PR 
  discussions or questions about pull requests.
metadata:
  author: SHELYOG
  version: 1.2.0
  category: automation
  updated: 2026-05-03
  mcp-server: user-slack
---

# Git PR Workflow

This skill automates the complete Git workflow for creating PRs with team notifications.

## When to Use

Trigger this skill ONLY when the user types these specific phrases:
- **"pr workflow"** (safe trigger - won't conflict with normal PR mentions)
- **"git pr"**
- **"create pr workflow"**
- **"run pr workflow"**
- "Commit, push and create PR"
- "Follow the standard PR workflow"

**DO NOT trigger** when user just mentions "PR" in normal conversation or asks questions about PRs.

## Workflow Steps

Follow these steps in order:

### 1. Check Git Status
```bash
git status
```
Verify there are staged or unstaged changes to commit.

### 2. Commit Changes
Generate a descriptive commit message based on the changes:
```bash
git commit -m "$(cat <<'EOF'
[Type]: [Brief description]

- [Change 1 with details]
- [Change 2 with details]
- [Change 3 with details]

EOF
)"
```

**Commit Message Guidelines:**
- Use conventional commit types: feat, fix, refactor, docs, chore, etc.
- Keep first line under 50 characters
- Use bullet points for detailed changes
- Focus on WHY and WHAT, not HOW

### 3. Push Branch
```bash
git push -u origin HEAD
```
Push the current branch to remote with upstream tracking.

### 4. Create PR with Team Assignment
```bash
gh pr create \
  --title "[Descriptive PR Title]" \
  --body "$(cat <<'EOF'
## Summary
- [Brief overview of changes]
- [Key functionality added/modified]

## Test plan
- [ ] [Testing step 1]
- [ ] [Testing step 2]
- [ ] [Validation step]

EOF
)" \
  --reviewer team:fielmann-ag/devops-platform
```

**PR Requirements:**
- Clear, descriptive title
- Summary section with bullet points
- Test plan with checkboxes
- Always assign to `team:fielmann-ag/devops-platform`

### 5. Send Slack Notification

Use the MCP Slack tool to notify the team:
```bash
# Get repository name from git remote
REPO_NAME=$(basename $(git remote get-url origin) .git)

# Extract PR URL from previous gh command output
# Use the returned PR URL in the Slack message
```

**Slack Message Template:**
```
Hi Team, Kindly review PR made in [REPOSITORY_NAME]
Changes: [Brief summary of changes - 1 line]
PR: [PR_URL]
```

**Slack Configuration:**
- Channel: `#ae_devops`
- Format: 3-line message as specified
- Include repository name, brief changes summary, and PR link

## Error Handling

### Common Issues:
1. **No changes to commit**: Inform user and exit gracefully
2. **Branch not pushed**: Ensure push succeeds before creating PR
3. **PR creation fails**: Check if branch already has an open PR
4. **Slack notification fails**: Warn user but don't block the workflow

### Recovery Steps:
- If any step fails, stop the workflow and report the error
- Provide specific guidance for manual completion
- Never leave the process in an incomplete state

## MCP Tool Integration

### Required MCP Tools:
1. **Slack**: `user-slack` server
   - Tool: `conversations_add_message`
   - Channel: `#ae_devops`
   - Format: `text/plain` or `text/markdown`

### Before Using Slack:
1. Read the Slack tool schema: `/Users/SHELYOG/.cursor/projects/Users-SHELYOG-git-ae-platform-contexts/mcps/user-slack/tools/conversations_add_message.json`
2. Use `CallMcpTool` with proper parameters
3. Handle authentication if required

## Complete Example

**User Request:** "Commit, push and create PR"

**Agent Response:**
1. Check `git status` - show current changes
2. Commit with descriptive message based on changes
3. Push branch to remote
4. Create PR with summary and assign to devops-platform team
5. Send 3-line Slack notification to #ae_devops
6. Confirm completion with PR URL

## Customization Notes

This skill is configured for:
- **Team**: fielmann-ag/devops-platform
- **Slack Channel**: #ae_devops
- **Repository Context**: ae-platform-contexts and related repos

For different teams or channels, modify the `--reviewer` and `channel_id` parameters accordingly.