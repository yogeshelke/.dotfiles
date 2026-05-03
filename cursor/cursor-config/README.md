# Cursor IDE Custom Configuration

This directory contains my personalized Cursor IDE configuration that gets symlinked to `~/.cursor/`.

## Structure

- `skills/` - Custom domain-specific skills (AWS, Terraform, K8s, etc.)
- `rules/` - Coding standards and guardrails  
- `commands/` - Workflow automation commands
- `.cursorignore` - Files to ignore in Cursor
- `.cursorindexignore` - Files to exclude from indexing

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

- `aws-security.mdc` - AWS security guardrails
- `command-restrictions.mdc` - Safety restrictions for destructive operations
- `context-engineering.mdc` - Context management best practices
- `eks-best-practices.mdc` - EKS operational guidelines
- `ci-cd-guidelines.mdc` - CI/CD pipeline guidelines
- `terraform.mdc` - Terraform best practices
- `github-actions.mdc` - GitHub Actions patterns
- `plan-standards.mdc` - Planning and documentation standards

## Commands Overview

- `check-progress.md` - Progress tracking and milestone checking
- `self-review.md` - Code and infrastructure review checklist
- `kube-deploy-checklist.md` - Kubernetes deployment validation
- `review-security.md` - Security audit and compliance checks
- `plan-aws-infra.md` - AWS infrastructure planning workflow

## Installation

These configurations are automatically symlinked by the dotfiles bootstrap script.

## Best Practices Applied

This configuration follows Anthropic's best practices for skills:
- ✅ Specific trigger phrases for accurate skill activation
- ✅ Progressive disclosure for large skills (AWS, Terraform)
- ✅ Semantic versioning and proper metadata
- ✅ Negative trigger conditions to prevent conflicts
- ✅ Troubleshooting sections for complex workflows
- ✅ Security guardrails and safety restrictions

## Usage

After installation, skills activate automatically based on your requests:
- Ask about "AWS VPC setup" → aws skill activates
- Mention "terraform plan" → terraform skill provides guidance
- Say "pr workflow" → git-pr-workflow automates PR creation
- Request "infrastructure changes" → ask-clarifying-questions ensures safety