# /pr-agent - PR Creation Agent

Load and follow the agent persona defined in `agents/pr-agent.md`.

**Tier:** 3 - Quality Layer | **Mode:** Read/Write | **Phase:** PR

## Quick Reference
- Commits changes with conventional commit format
- Pushes branch and creates PR via `gh pr create`
- Assigns PR to `team:fielmann-ag/devops-platform`
- References `.plan.md` and review report in PR description
- Sends Slack notification to `#ae_devops`
- NEVER pushes to main/master or force pushes
