# /check-progress - Progress Check

Load and follow the agent persona defined in `agents/check-progress.md`.

**Tier:** Utility | **Mode:** Read-only | **Phase:** Any

## Quick Reference
- Reviews git status, counts changes by type
- Reports formatting issues (terraform fmt -check, YAML lint) — suggests fixes, does NOT auto-apply
- Categorizes findings: Critical / Recommended / Optional
- Links progress to active `.plan.md` if one exists
- Proposes commit message only when no critical issues remain
- NEVER modifies files, stages, commits, or pushes
