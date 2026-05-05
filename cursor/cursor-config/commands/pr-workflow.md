# /pr-workflow - Git PR Workflow

Run the standard Git PR workflow using `skills/git-pr-workflow/SKILL.md`.

**Phase:** PR Creation | **Mode:** Read/Write

## Instructions

1. Inspect git status and diff
2. Preview commit message, PR title/body, and Slack message
3. **Wait for explicit approval** before any write operations
4. Execute: commit → push → PR → Slack notification
5. Report final PR URL and Slack notification status

## Safety

- Never commit without showing the preflight summary first
- Never run `git add .` without explicit approval
- Stop and report state if any step fails
