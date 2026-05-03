# Cursor IDE Custom Configuration

This directory contains my personalized Cursor IDE configuration that gets symlinked to `~/.cursor/`.

## Structure

- `skills/` - Custom domain-specific skills (AWS, Terraform, K8s, etc.)
- `rules/` - Coding standards, guardrails, and agent orchestration
- `commands/` - Agent personas and utility commands
- `.cursorignore` - Files to ignore in Cursor
- `.cursorindexignore` - Files to exclude from indexing

## Multi-Agent Orchestration

This configuration implements a team of specialist agents for AWS Cloud Platform engineering. Each agent is invoked via a slash command and operates interactively -- no autonomous changes to production, GitHub, or clusters.

### Agent Commands

| Command | Agent | Role |
|---------|-------|------|
| `/architect` | AWS Cloud Architect | High-level design, specs, plans. Never writes code. |
| `/k8s-expert` | Kubernetes Expert | Analysis and recommendations. Read-only, no admin rights. |
| `/iac-dev` | IaC Developer | Writes Terraform, Helm, YAML, Python, Shell scripts. |
| `/reviewer` | Security Reviewer | Reviews PRs with security-first mindset. Read-only. |
| `/platform-tester` | Platform Tester | Writes/runs tests, enforces TDD. Confirms before executing. |
| `/devops` | DevOps Engineer | CI/CD pipelines (GitHub Actions), monitoring (Datadog). |

### Utility Commands

| Command | Purpose |
|---------|---------|
| `/check-progress` | Progress tracking, quality fixes, status summary |

### Typical Workflow

```
/architect  -->  design & plan
/iac-dev    -->  implement the plan
/reviewer   -->  security review
/platform-tester  -->  validate with tests
/devops     -->  CI/CD & monitoring
```

## Skills Overview

| Skill | Purpose | Version |
|-------|---------|---------|
| aws | AWS services and Well-Architected patterns | 2.0.0 |
| terraform | Infrastructure-as-code with HCL | 2.0.0 |
| kubernetes | Container orchestration | 2.0.0 |
| git-pr-workflow | Automated PR creation workflow | 1.2.0 |
| ask-clarifying-questions | Risk mitigation for ambiguous requests | 1.1.0 |
| github | GitHub and GitHub Actions reference | 2.0.0 |
| datadog | Monitoring and observability | 2.0.0 |
| eks | Amazon EKS managed Kubernetes | 2.0.0 |
| helm | Kubernetes package manager | 2.0.0 |
| karpenter | EKS node provisioning and autoscaling | 2.0.0 |
| envoy-gateway | Advanced ingress and traffic management | 2.0.0 |

## Rules Overview

### Always Active
- `command-restrictions.mdc` - Safety restrictions for destructive operations
- `interactive-gate.mdc` - Enforces human approval at every stage
- `orchestrator.mdc` - Routes tasks to appropriate specialist agents
- `context-engineering.mdc` - Context management best practices
- `aws-security.mdc` - AWS security guardrails

### File-Scoped
- `eks-best-practices.mdc` - EKS operational guidelines
- `ci-cd-guidelines.mdc` - CI/CD pipeline guidelines
- `terraform.mdc` - Terraform best practices
- `github-actions.mdc` - GitHub Actions patterns
- `plan-standards.mdc` - Planning and documentation standards

## Installation

These configurations are automatically symlinked by the dotfiles bootstrap script.

## Safety Guarantees

All agents operate under these constraints:
- No autonomous changes to production environments
- No direct pushes to GitHub (all changes via PRs)
- No modifications to EKS clusters or AWS resources
- No destructive commands (terraform apply, kubectl apply, helm install)
- Human approval required at every stage
- Piped command chains blocked if they include any restricted command