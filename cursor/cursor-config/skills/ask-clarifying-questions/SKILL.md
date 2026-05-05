---
name: ask-clarifying-questions
description: >-
  Execution gate that blocks agents from proceeding on ambiguous, risky, or under-specified
  requests. Enforces clarification before any infrastructure changes, deployments, plan creation,
  or multi-step operations. This is a control gate, not guidance.
metadata:
  author: SHELYOG
  version: 2.1.0
  category: workflow
  updated: 2026-05-05
---
# Clarification Gate

This skill is an **execution gate** — it blocks work until ambiguity is resolved.

## Execution Gate (HARD RULE)

If required information is missing:
- **DO NOT** implement
- **DO NOT** generate code, infrastructure, or commands
- **DO NOT** create plans or designs
- **ONLY** ask clarifying questions

Proceed **only** after:
- User answers the questions, OR
- User explicitly approves stated assumptions (e.g., "use defaults", "assume QA")

---

## Minimum Required Context

Do not proceed until **all four** are known:

| Priority | Field | What you need | Example |
|---|---|---|---|
| 1 (highest) | **Environment** | Target env name | QA, production, dev, all |
| 2 | **Intent** | Create / modify / delete | "add new" vs "update existing" vs "remove" |
| 3 | **Scope** | Resources/services affected | payment-service RDS, all VPCs, single module |
| 4 | **Constraints** | Requirements or limits | cost ceiling, region, compliance, timeline |

If **any** of these are missing → ask before proceeding.

## Context Priority

When multiple fields are missing, clarify in priority order (1 → 4):

1. **Environment** — highest risk; determines blast radius and safety posture
2. **Intent** — determines if action is destructive, additive, or modifying
3. **Scope** — defines impact boundary (one resource vs many)
4. **Constraints** — optimization limits (cost, region, compliance)

If question limit (5) is reached before all are resolved, ask higher-priority fields first. Lower-priority fields can use safe defaults temporarily.

## Avoid Redundant Questions

- Never re-ask questions already answered (even in different wording)
- Track which fields are resolved after each user response
- Only ask for missing or conflicting information
- If user gives partial answer → acknowledge resolved parts, ask only what remains
- If context was provided earlier in conversation → treat as answered (unless later contradicted)

## Context Invalidation

- If user provides new information that overrides previous context → update resolved fields immediately
- If later statement contradicts earlier answer → trigger conflict detection again
- Never persist stale context — most recent explicit statement wins
- When override involves escalation (e.g., QA → production), re-apply Override Safety rules

---

## Detect Ambiguity

Treat as ambiguous if:
- Multiple valid interpretations exist
- Request uses vague terms ("optimize", "fix", "set up", "improve", "clean up")
- Critical parameters are missing (see minimum context above)
- Action could affect shared or production systems
- Scope could be one resource or many

## Detect Conflicts

Treat as **conflicting** (not just ambiguous) if:
- Context fields contradict (e.g., "QA production cluster" — which is it?)
- Instructions are incompatible (e.g., "safe" + "delete everything")
- Scope boundaries overlap or are unclear (e.g., "this module and related resources")
- Environment and intent mismatch (e.g., "test this in production")

When conflict detected:
- Name the specific conflict
- Ask user to resolve before proceeding
- Do not pick one interpretation over another

```
I see a conflict: you said "QA production cluster."
- Did you mean the QA environment, or Production?
- These are different targets with different safety requirements.
```

---

## When to Ask

### Always ask before:
- Any destructive operation (delete, deprovision, remove)
- Changes spanning multiple environments or accounts
- Modifications to shared infrastructure (VPC, DNS, IAM, networking)
- Creating resources with cost implications (RDS, NAT Gateways, large instances)
- Changing CI/CD pipelines or deployment workflows
- Operations where rollback is difficult or impossible

### Don't ask when:
- Request is fully specified (all 4 minimum context fields are clear)
- It's a read-only operation (describe, get, list, plan)
- Following an approved plan with explicit tasks
- Answer is obvious from context (file open, environment clear from branch)

---

## How to Ask

### Question Limits
- Ask **1–5** high-impact questions in the first pass
- Prioritize questions that eliminate the largest ambiguity
- Never ask low-impact or obvious questions
- If >5 unknowns exist, ask the top 5 and state "I'll ask follow-ups after these"

### Use structured questions (AskQuestion tool preferred):
Multiple-choice is faster for the user and reduces back-and-forth.

```
Example: User says "Set up monitoring for the API"

Questions:
- "Which API service?" → [api-gateway, user-service, payment-service, all]
- "Which monitoring?" → [Datadog APM, monitors/alerts, Dashboard, SLOs, All]
- "Which environment?" → [QA only, Production only, Both]
```

### Question format:
- **Be specific** — Don't ask "Can you clarify?" — ask the exact thing you need
- **Provide options** — Give the most likely choices
- **Batch questions** — Ask all unclear points at once
- **State your assumption** — "I'll assume X unless you say otherwise"
- **Explain why** — Brief context helps the user give better answers

---

## Fast Path

When appropriate, provide recommended defaults so the user can shortcut:

```
I need a few details. You can answer individually or say "use defaults":

Defaults I'd recommend:
- Environment: QA (deploy to prod later)
- Instance: db.r6g.large (right-size after load test)
- Multi-AZ: yes (standard for stateful services)
- Encryption: KMS (mandatory per policy)

Proceed with these defaults? Or specify changes?
```

Valid fast-path responses from user:
- "use defaults" → proceed with stated defaults
- "assume QA" → use QA for environment, ask rest
- "proceed with safe assumptions" → use least-risk options for all unknowns

---

## Override Safety

If user says "use defaults" or "proceed with assumptions", **still block** if:
- Production environment is involved
- Operation is destructive (delete, remove, replace)
- Scope is unclear and could impact multiple systems
- Changes are irreversible (data loss, state destruction)

In these cases:
- Acknowledge the fast-path request
- Explain why explicit confirmation is needed
- Ask targeted confirmation (not full re-clarification)

```
You said "use defaults" — but this involves production.
I need explicit confirmation: deploy Aurora cluster to PRODUCTION with Multi-AZ? [yes/no]
```

---

## Assumption Escalation

If you must assume to proceed:

1. **Safe default** — Least destructive, least costly, most reversible option
2. **State it clearly** — "I'm assuming QA environment since you didn't specify"
3. **Never assume**: production, destructive intent, broad scope, public access
4. **Document** — Note assumptions in plan or PR description

---

## System Integration

This skill runs as a **pre-gate** for:
- `/architect` — before creating a plan
- `/iac-dev` — before implementing
- `/devops` — before executing workflows
- `/reviewer` — before flagging ambiguous security configs

**If triggered → block execution until clarification is complete.**

Agents must not partially implement while waiting for answers.

---

## Clarification Completion

After user responds to questions:
1. Re-check all 4 required fields (environment, scope, intent, constraints)
2. If any are **still** unclear or unanswered → ask again (only the missing ones)
3. Only proceed to execution when **all** are satisfied
4. If user gives partial answer → acknowledge what's resolved, ask what remains

```
Thanks — environment (QA) and intent (create new) are clear.
Still need: which service does this RDS belong to, and any size/cost constraints?
```

This prevents premature execution on partial answers.

---

## Examples

**Ambiguous**: "Add a database"
```
Before I proceed, I need to clarify:
- Engine: PostgreSQL (Aurora) or MySQL?
- Environment: QA, Production, or both?
- Size: What instance class? (e.g., db.r6g.large)
- New cluster or replica of existing?
- Cross-AZ failover needed?

Or say "use defaults" and I'll go with: Aurora PostgreSQL, QA, db.r6g.large, new cluster, Multi-AZ yes.
```

**Risky**: "Clean up unused resources"
```
This is potentially destructive — I need to confirm:
- Which account/environment? [QA, Production, Management]
- Which resource types? [EC2, EBS, Security Groups, IAM, All]
- List candidates first for review, or proceed directly?
- Any resources that must NOT be touched?
```

**Vague**: "Optimize the cluster"
```
"Optimize" could mean several things:
- Cost optimization? (smaller instances, spot, consolidation)
- Performance? (right-sizing, scaling, caching)
- Security hardening? (network policies, IRSA, encryption)
- All of the above?

Which is the priority?
```
