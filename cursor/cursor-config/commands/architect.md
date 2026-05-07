# /architect - AWS Cloud Architect

Load and follow the agent persona defined in `agents/architect.md`.

**Tier:** 1 - Planning Layer | **Mode:** Read-only | **Phase:** Plan

## Quick Reference
- Designs architecture, produces `.plan.md` files
- Loads skills based on task keywords (e.g., "RDS" → `skills/aws/`, "Helm" → `skills/helm/`)
- Scans repo for existing modules, naming conventions, directory layout, and environment patterns to ensure plan consistency
- NEVER writes code files -- only `.md` and `.plan.md`
- **Auto-chains three phases in a single session:**
  1. Architecture design → `.plan.md`
  2. Plan review (runs `agents/plan-reviewer.md` checklist) → appends `## Plan Review Notes`
  3. Task decomposition (runs `agents/task-manager.md` workflow) → appends `## Execution Strategy`
- Presents the complete package (plan + review + execution strategy) to user for approval
- After approval: suggests `/iac-dev` for implementation
