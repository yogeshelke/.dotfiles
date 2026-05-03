---
name: ask-clarifying-questions
description: Ensures the agent asks clarifying questions before acting on ambiguous, risky, or under-specified requests. Use on every task involving infrastructure changes, deployments, plan creation, or multi-step operations where assumptions could lead to incorrect outcomes.
metadata:
  author: SHELYOG
  version: 1.1.0
  category: workflow
  updated: 2026-05-03
---
# Ask Clarifying Questions

Before executing any non-trivial task, check for ambiguity. If the request is unclear, under-specified, or carries risk, **stop and ask** before proceeding. Never guess on things that matter.

## When to Ask

### Always ask if any of these are unclear:
- **Target environment** — Which environment? (dev, staging, production, all)
- **Scope** — Which resources, services, or repos are affected?
- **Intent** — Is this additive (create/add), modifying (update/change), or destructive (remove/delete)?
- **Blast radius** — Could this affect production traffic, data, or other teams?
- **Credentials/access** — Does this need specific IAM roles, secrets, or permissions?
- **Existing state** — Is there existing infrastructure that might conflict or need migration?

### Always ask before:
- Any destructive operation (delete, deprovision, remove)
- Changes that span multiple environments or accounts
- Modifications to shared infrastructure (VPC, DNS, IAM, networking)
- Creating resources with cost implications (RDS, NAT Gateways, large instance types)
- Changing CI/CD pipelines or deployment workflows
- Operations where rollback is difficult or impossible

### Don't ask when:
- The request is fully specified with no ambiguity
- It's a read-only operation (describe, get, list, plan)
- You're following an approved plan with clear tasks
- The answer is obvious from context (e.g., file already open, environment clear from branch name)

## How to Ask

### Use structured questions (AskQuestion tool) when possible:
Prefer multiple-choice over open-ended questions. This is faster for the user and reduces back-and-forth.

```
Example: User says "Set up monitoring for the API"

Good questions:
- "Which API service?" → [api-gateway, user-service, payment-service, all]
- "Which monitoring?" → [Datadog APM, Datadog monitors/alerts, Dashboard, SLOs, All]
- "Which environment?" → [QA only, Production only, Both]
```

### Question format guidelines:
- **Be specific** — Don't ask "Can you clarify?" — ask the exact thing you need to know
- **Provide options** — Give the most likely choices so the user can pick
- **Batch questions** — Ask all unclear points at once, not one at a time
- **State your assumption** — If you have a best guess, say "I'll assume X unless you say otherwise"
- **Explain why you're asking** — Brief context helps the user give better answers

### Examples

**Ambiguous request**: "Add a database"
```
Before I proceed, I need to clarify:
- Engine: PostgreSQL (Aurora) or MySQL?
- Environment: QA, Production, or both?
- Size: What instance class? (e.g., db.r6g.large)
- Is this a new cluster or a replica/read-only instance of an existing one?
- Does it need cross-AZ failover?
```

**Risky request**: "Clean up unused resources"
```
This could be destructive, so I want to confirm scope:
- Which account/environment? [QA, Production, Management]
- Which resource types? [EC2, EBS, Security Groups, IAM, All]
- Should I list candidates first for review, or proceed directly?
- Are there any resources that must NOT be touched?
```

**Under-specified request**: "Deploy the new version"
```
A few things to confirm:
- Which service? [service-a, service-b, all services]
- Which version/image tag?
- Deployment target? [QA first then promote, Production directly]
- Is there a change ticket or PR linked to this?
```

## Assumption Escalation

If you must make an assumption to proceed, follow this priority:

1. **Safe default** — Pick the least destructive, least costly, most reversible option
2. **State it clearly** — "I'm assuming QA environment since you didn't specify"
3. **Pause on high-risk** — Never assume production. Never assume destructive intent
4. **Document it** — Note assumptions in the plan or PR description

## Integration with Other Agents

- **Planner**: Ask clarifying questions during the planning phase, before producing the plan
- **Orchestrator**: Confirm task dependencies and parallel groups if the user's request is ambiguous
- **Implementer**: Ask before implementing if the plan leaves room for interpretation
- **Verifier**: Flag ambiguous security configurations rather than assuming they're acceptable
