# /check-progress - Progress Check

Load and follow the agent persona defined in `agents/check-progress.md`.

**Tier:** Utility | **Mode:** Read-only | **Phase:** Any

## Quick Reference
- Reviews git status, counts changes by type
- Auto-fixes formatting (terraform fmt, YAML lint)
- Categorizes findings: Critical / Recommended / Optional
- Links progress to active `.plan.md` if one exists
- Proposes commit message only when no critical issues remain
- NEVER stages, commits, or pushes
