---
name: helm
description: >-
  Helm decision system for Kubernetes application packaging. Use for chart design,
  values management, deployment strategy, dependencies, and testing.
  Do NOT use for raw Kubernetes manifests (use kubernetes skill) or Terraform helm_release specifics (use terraform skill).
metadata:
  author: SHELYOG
  version: 4.0.0
  category: kubernetes
  updated: 2026-05-05
---
# Helm Decision Engine

Decision rules for Helm chart management. Not reference material.

- K8s workload patterns → `skills/kubernetes/`
- Terraform integration → `skills/terraform/`
- Helm is a **packaging + rendering** engine — Kubernetes applies resources
- Never assume Helm enforces runtime correctness — always validate rendered output against cluster API

## Interaction Model
- This skill defines **chart design, values patterns, and release management** only
- K8s resource types and workload patterns → `kubernetes` skill
- Terraform `helm_release` resource config → `terraform` skill
- Karpenter NodePool Helm charts → `karpenter` skill
- What to deploy (service architecture) → `aws` skill

---

## Decision Entry Points

| Task | Read sections |
|---|---|
| Create new chart | CHART_DESIGN + VALUES |
| Configure deployment | VALUES + DEPLOYMENT |
| Manage chart dependencies | DEPENDENCIES |
| Validate before deploy | TESTING |
| Upgrade existing release | DEPLOYMENT |

---

<!-- CORE_DECISIONS: Read this section for design choices and constraints -->

## Cross-Cutting Rules

| Rule | Domain | Enforcement |
|---|---|---|
| No secrets in values | Values + Security | External Secrets Operator or sealed-secrets |
| Schema validation | Values + Testing | Every chart needs `values.schema.json` |
| Version pinning | Dependencies | Pessimistic constraints + Chart.lock committed |
| `include` over `template` | Chart Design | `include` is pipeable; `template` is not |
| Diff before upgrade | Deployment | Always `helm diff upgrade` before apply |
| Helm owns its resources | All | No manual kubectl edits on Helm-managed objects |
| Idempotent upgrades | Deployment + Hooks | `helm upgrade --install` must be safe to re-run |
| Explicit namespace | All | Never use `default`; always specify `-n` |
| One resource per file | Chart Design | File named after resource type |
| Template namespacing | Chart Design | All defines must be `<chart>.<name>` |

---

<!-- REFERENCE: Detailed implementation patterns below. Read only when you need specific configs. -->

## Operational Rules

**Resource ownership**:
- Helm must own all resources it creates — no manual edits, no mixing managed/unmanaged in same namespace
- Drift between Helm state and cluster state causes failed upgrades

**Idempotency**:
- `helm upgrade --install` must produce identical result on re-run
- Hooks must be idempotent (DB migrations need guards)
- No side effects outside Helm-managed resources

**Release naming + namespace**:
- Deterministic: `<app>-<environment>` or `<app>` (namespace encodes env)
- One release per application per environment
- Namespace explicit in commands (`-n`); aligned with env isolation
- Do NOT hardcode `metadata.namespace` in templates — charts must be namespace-agnostic (breaks multi-env and GitOps)

**Versioning + immutability**:
- Chart version → template/structure changes | App version → image/binary changes
- Never modify a published chart version — every change produces a new version
- Chart artifacts must be reproducible from version control

**Values contract stability**:
- Never remove/rename values without migration path
- Breaking changes → major chart version bump
- Deprecated values supported for at least one cycle (warn in NOTES.txt)

**Labels** (mandatory on all resources):
- `app.kubernetes.io/name`, `app.kubernetes.io/instance`, `app.kubernetes.io/version`, `helm.sh/chart`

**RBAC**:
- Define minimal permissions — avoid ClusterRoles unless strictly required
- ServiceAccounts must be explicitly defined, scoped to namespace
- Never grant cluster-admin via chart defaults

---

## [CHART_DESIGN]

**Chart type**: Application (deploys resources) | Library (shared templates only, no resources)

**When separate chart vs. same chart**:
- Separate: independent lifecycle, different team, different deploy cadence
- Same: tightly coupled, always deployed together

**Structure**:
- `_helpers.tpl` — reusable definitions (fullname, labels, selectors)
- `NOTES.txt` — post-install usage (always include)
- `tests/` — helm test pods
- One Kubernetes resource per template file, named after type (`deployment.yaml`, `service.yaml`)
- All template defines namespaced: `{{ define "<chart>.fullname" }}` (prevents collisions with subcharts)

**CRDs**:
- Prefer operators over chart-bundled CRDs
- Helm does NOT upgrade CRDs (only installs on first deploy)
- CRDs must exist before dependent resources
- If bundled: separate CRD-only chart or pre-install hook

**Hooks**:
- `pre-install/pre-upgrade` for migrations, validation
- `hook-delete-policy: before-hook-creation` (always — cleans up old resources)
- `hook-weight` for ordering
- Hook-created resources are NOT tracked by Helm — leads to orphans if not cleaned up

**Template determinism**:
- Same chart + values must produce identical output every time
- Avoid `randAlphaNum`, `now`, time-based functions (diff noise, unnecessary rollouts)
- If randomness needed → generate once, persist with `lookup`

---

## [VALUES]

**Merge behavior** (critical — causes hidden bugs):
- Helm **merges** values, not replaces — missing keys persist from previous state
- Explicitly set values to `null` when removing config
- `--reuse-values` amplifies this problem — avoid it

**Precedence** (lowest → highest): subchart defaults → parent values.yaml → `-f` files → `--set`

**Design rules**:
- Flat keys preferred (≤2 levels) — easier `--set` overrides
- `camelCase` naming
- Sensible defaults for ALL values (chart works with zero overrides)
- `required` function for mandatory values
- Document all values with inline comments
- Be explicit with types — YAML coerces silently (`"3"` ≠ `3`); use `int`, `quote`, `toString` in templates when needed

**Schema** (`values.schema.json`): validates on install/upgrade/template; define types, required, enums, patterns

---

## [DEPLOYMENT]

**Method selection**:
- **Default**: Terraform `helm_release` (state-tracked, IaC-managed)
- **If GitOps** → ArgoCD Application
- **If manual** → `helm upgrade --install` (avoid for production)

**Terraform rules**: Use values files (not inline set), `create_namespace = true`, `dependency_update = true`, set `timeout` + `wait = true`

**Upgrade strategy**:
- `helm diff upgrade` first (always)
- `--atomic` for auto-rollback on failure
- `--timeout` appropriate to app startup
- Never deploy unrendered templates

**Values on upgrade**:
- Explicit values files — predictable, auditable
- Avoid `--reuse-values` (carries deprecated values)
- `--reset-values` when chart structure changes significantly
- Review effective values: `helm get values <release>`

**Rollback safety**:
- Check `helm history` before rollback
- Do NOT rollback across incompatible schema changes
- Rollback reverts manifests, NOT external state (DB, PV data)

**Upgrade risk**:

| Risk | Examples | Requirement |
|---|---|---|
| Safe | Image tag, replicas, resource limits | Standard deploy |
| Medium | Config changes, feature flags | Review diff |
| High | CRD changes, schema breaking, new required values | Lower env test + approval |

---

## [DEPENDENCIES]

**Version constraints**: `~12.0` (pessimistic, preferred) | `^12.0` | `>=12.0 <13.0` (explicit range)

**Conditional**: `condition: redis.enabled` to toggle | `tags` for groups

**Management**: `helm dependency update` → download; `helm dependency build` → from lock. Commit `Chart.lock`.

**Subchart values**: Parent overrides under subchart key. `global` shared across all subcharts. Subcharts cannot access arbitrary parent values — use `global` for shared config.

---

## [TESTING]

**Validation pipeline** (in order):
1. `helm lint` — structure validation
2. `helm template` — render locally
3. `helm template | kubectl apply --dry-run=server -f -` — server-side check
4. `helm diff upgrade` — preview against live
5. `helm test` — test pods post-deploy

**Unit testing**: `helm-unittest` plugin — test edge cases, empty values, conditionals, iteration

---

## Anti-Patterns

| Anti-Pattern | Do This Instead |
|---|---|
| Secrets in values.yaml | External Secrets Operator |
| No schema validation | `values.schema.json` |
| Deep nesting (>2 levels) | Flat structure for `--set` compatibility |
| Unpinned dependencies | Pessimistic constraints + Chart.lock |
| `template` instead of `include` | `include` (pipeable) |
| No NOTES.txt | Always include usage notes |
| Deploy without diff | `helm diff upgrade` first |
| Manual kubectl edits on Helm resources | All changes through Helm |
| Non-idempotent hooks | Idempotent with guards |
| CRDs bundled without lifecycle plan | Separate chart or operator |
| `--reuse-values` on upgrades | Explicit values files |
| Non-deterministic templates | Generate once + persist |
| Modifying published chart version | New version for every change |
| Removing values without migration | Deprecate → one cycle → remove |
| Generic template names (`fullname`) | Namespace: `<chart>.fullname` |
| Multiple resources per file | One resource per file |
| ClusterRole by default | Minimal namespace-scoped RBAC |

---

## Troubleshooting Decision Trees

**Install/upgrade fails?**
1. Rendering error? → `helm template --debug`
2. Timeout? → Increase `--timeout`, check pod startup
3. Schema validation? → Fix values against schema
4. Missing dependency? → `helm dependency update`

**Rendered output wrong?**
1. Whitespace? → `{{-` / `-}}` trimming, `nindent`
2. Wrong value? → Check precedence (set > file > default)
3. Conditional broken? → Check zero values, empty strings
4. Helper not rendering? → Use `include` not `template`

**Release stuck failed?**
1. `helm history <release>` → identify revision
2. `helm rollback <release> <revision>`
3. If rollback fails → `helm uninstall --keep-history` + reinstall
4. Pending-upgrade → may need manual secret cleanup

**Values seem wrong after upgrade?**
1. Used `--reuse-values`? → Old values persisted (use explicit files)
2. Merge behavior? → Helm merges, not replaces (set null to remove)
3. Precedence issue? → `--set` wins over files

---

## Reference Documentation

- **Helm Docs**: https://helm.sh/docs/
- **Chart Best Practices**: https://helm.sh/docs/chart_best_practices/
- **Template Guide**: https://helm.sh/docs/chart_template_guide/
- **Template Functions**: https://helm.sh/docs/chart_template_guide/function_list/
- **Hooks**: https://helm.sh/docs/topics/charts_hooks/
- **OCI Registries**: https://helm.sh/docs/topics/registries/
- **Artifact Hub**: https://artifacthub.io/
