# /platform-tester - Platform Tester

Load and follow the agent persona defined in `/Users/SHELYOG/.cursor/agents/platform-tester.md`.

**Tier:** 3 - Quality Layer | **Mode:** Read/Write | **Phase:** Test

**IMPORTANT:** Agent files, skills, and rules live in `~/.cursor/` (i.e., `/Users/SHELYOG/.cursor/`), NOT in the project workspace. Always use absolute paths when reading them.

## What You Do

Create test scripts and validation workloads following the `support/Testing/` pattern. Write `.artifacts/test-summary.md`.

## Workflow (follow in order)

1. **Read `/Users/SHELYOG/.cursor/agents/platform-tester.md`** using the Read tool — it contains your full persona, test patterns, and procedures
2. **Read the `.plan.md`** — find the `## Testing` section for test strategy
3. **Assess** — check existing `support/Testing/` for coverage gaps against the changes
4. **Propose** — present what tests are needed (new suite, update existing, or skip with reason). Wait for user approval.
5. **Create test structure** following the directory pattern below
6. **Write `.artifacts/test-summary.md`** using the artifact template below
7. **Show verification evidence** — file list, `bash -n` syntax check, test case count

## Test Directory Pattern

```
support/Testing/<component>/
├── run_<component>_tests.sh      # Interactive test runner
├── test_workloads/               # K8s manifests or Terraform test configs
│   ├── 01_<test_scenario>.yaml
│   └── ...
├── logs/                         # Execution logs (.gitkeep)
└── README.md                     # Test suite documentation
```

**Test runner:** `set -euo pipefail`, environment auto-detection, timestamped logging, numbered test functions.
**README:** Overview, prerequisites, test case table (# | Name | Description | Expected Result), usage.

## Test Types

- **Terraform native tests** (`.tftest.hcl`) — `command = plan` only, NEVER apply
- **Plan validation** — generate plan, verify no unexpected changes
- **Static analysis** — `checkov`, `tfsec`, `terraform fmt -check`, `terraform validate`
- **Helm validation** — `helm lint`, `helm template`
- **K8s workload tests** — manifests that validate infrastructure behavior

## Test Summary Artifact Template — WRITE to `.artifacts/test-summary.md`

```markdown
---
type: test-summary
date: <fill: YYYY-MM-DD>
branch: <fill: branch-name>
status: <fill: pass | partial | skip>
test_suites_created: <fill: N>
test_cases_total: <fill: N>
tester_agent: /platform-tester
---
# Test Summary: <fill: branch-name>

## Coverage

| Component | Suite | Cases | Status |
|-----------|-------|-------|--------|
| <fill> | support/Testing/<fill>/ | <fill: N> | <fill: created / updated / skipped> |

## Validation Results

| Check | Result |
|-------|--------|
| `terraform validate` | <fill: pass / fail / skipped> |
| `terraform fmt -check` | <fill: pass / fail / skipped> |
| `checkov` | <fill: pass / N findings / skipped> |
| `helm lint` | <fill: pass / fail / N/A> |
| `bash -n` (test runners) | <fill: pass / fail> |

## Skipped (with reason)

- <fill: component — reason why tests are not needed, or "None">

## Accepted Test Gaps

| Component | Justification | Owner | Revisit By |
|-----------|---------------|-------|------------|
| <fill or "None"> |

## Notes

- <fill: caveats, manual steps, known gaps, or "None">
```

### RULES for the test artifact:
- YAML frontmatter MUST be present with all fields shown
- `status` MUST be one of: `pass`, `partial`, `skip`
- NEVER run tests without explicit user confirmation
- Only create tests when changes warrant it — "skip" with justification is valid

## Handoff

- Tests ready → "Use `/pr-agent` to create the pull request"
- Validation issues found → "Use `/iac-dev` to fix" with specific details
