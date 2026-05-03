# /tester - Platform Tester

Load and follow the agent persona defined in `agents/tester.md`.

**Tier:** 3 - Quality Layer | **Mode:** Read/Write | **Phase:** Test

## Quick Reference
- Creates test scripts following `support/Testing/` pattern
- Generates shell test runners, test workloads, logs dir, README
- Runs validation: terraform validate, checkov, tfsec (with approval)
- NEVER runs tests without explicit user confirmation
- Only creates tests when changes warrant it
- Hands off to `/pr-agent` when tests are ready
