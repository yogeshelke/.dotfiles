---
name: terraform
description: >-
  Terraform infrastructure-as-code reference with HCL language, CLI commands, 
  and AWS patterns. Use when user mentions "Terraform", "HCL", "terraform plan", 
  "terraform apply", "infrastructure as code", "IAC", "state management", 
  "terraform modules", "provider configuration", "resource blocks", "terraform import", 
  or asks about infrastructure automation, Terraform best practices, or .tf file syntax.
  Do NOT use for other IaC tools (Ansible, CloudFormation, CDK) or general devops questions.
metadata:
  author: SHELYOG
  version: 2.0.0
  category: infrastructure
  updated: 2026-05-03
---
# Terraform Comprehensive Reference

Infrastructure-as-code using HashiCorp Terraform with focus on AWS deployments and best practices.

## Quick Reference

### Essential Commands
- `terraform init` - Initialize working directory
- `terraform plan` - Preview changes (always review first)
- `terraform apply` - Apply changes ⚠️ **NEVER** without approval in this project
- `terraform validate` - Check syntax and consistency
- `terraform fmt` - Format code to standard style

### Key Concepts
- **Resources**: Infrastructure objects (`aws_vpc`, `aws_instance`)
- **Data Sources**: Read existing infrastructure
- **Variables**: Input parameters with validation
- **Outputs**: Return values for other configurations
- **Modules**: Reusable infrastructure components
- **State**: Current infrastructure tracking (remote backend required)

### Security Essentials
- Never hardcode credentials or secrets
- Use `sensitive = true` for secret variables/outputs
- Enable backend encryption for state files
- Use IAM roles, not access keys
- Scan with `checkov` or `tfsec`

## Language Basics

For detailed HCL language reference including resource blocks, expressions, type system, and built-in functions, see `references/hcl-language-reference.md`.

## CLI Commands

For comprehensive CLI command reference including core workflow, state management, import/migration, inspection, testing, and workspaces, see `references/cli-commands-reference.md`.

## Providers and Modules

For detailed provider configuration, module structure, design principles, and AWS module registry, see `references/modules-and-providers.md`.

## State Management

### Critical State Rules
- **Use S3 backend** with DynamoDB locking for team environments
- **Enable encryption** at rest for state files
- **Separate state files** per environment (dev/staging/prod)
- **Never commit** `.tfstate` files to version control
- **Always plan** after state operations to verify changes

### Common State Operations
- `terraform state mv` - Rename or move resources between modules
- `terraform import` - Adopt existing infrastructure
- Use `moved` blocks for declarative refactoring (preferred)
- Use `terraform_remote_state` data source for cross-configuration references

## Project Structure

### Recommended Layout
```
provisioning/terraform/aws/
├── base/                # Core infrastructure (VPC, EKS, RDS)
│   ├── locals.tf        # Environment-specific values
│   ├── variables.tf     # Input parameters
│   ├── providers.tf     # Provider configuration
│   ├── vpc.tf           # Network resources
│   ├── eks.tf           # Kubernetes cluster
│   ├── rds_clusters.tf  # Database resources
│   └── outputs.tf       # Exported values
├── k8s/                 # Kubernetes platform components
├── qa-kritis.hcl        # QA environment backend
├── prod-kritis.hcl      # Production backend
└── mgmt-kritis.hcl      # Management backend
```

### Naming Conventions
- Use `snake_case` for all identifiers
- Prefix resources descriptively: `aws_security_group.eks_nodes`
- Group by resource type in separate files
- Clear variable/output names without abbreviations

## Troubleshooting

### Common Issues

**Provider Version Conflicts**
- Update `.terraform.lock.hcl` with `terraform init -upgrade`
- Check for compatible provider versions
- Use `terraform providers` to see current versions

**State Lock Errors**
- Check DynamoDB for stuck locks (force-unlock with caution)
- Ensure team isn't running concurrent operations
- Verify backend configuration is correct

**Import Failures**
- Verify resource ID format matches provider documentation
- Use `terraform show` to confirm imported state
- Check resource configuration matches actual infrastructure

**Plan Shows Unexpected Changes**
- Review `ignore_changes` in lifecycle blocks
- Check for external modifications to infrastructure
- Verify provider version hasn't changed behavior

## Documentation References

For comprehensive documentation links covering core Terraform, CLI commands, providers/modules, state management, and testing, see `references/documentation-links.md`.
