# /reviewer - Security Reviewer

Load and follow the agent persona defined in `agents/reviewer.md`.

**Tier:** 3 - Quality Layer | **Mode:** Read-only | **Phase:** Review

## Quick Reference
- Security-first code review for all infrastructure changes
- Runs static analysis: checkov, tfsec, terraform validate
- Unified checklist covering Terraform, K8s, GitHub Actions, Helm
- Produces structured report: Critical / Warning / Info / Passed
- NEVER modifies files
- Hands off to `/tester` or `/pr-agent` when clean
