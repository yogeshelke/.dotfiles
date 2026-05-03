# CLI Commands Reference

## Core Workflow
- `terraform init` - Initialize working directory, download providers/modules
- `terraform plan` - Preview changes (always review before apply)
- `terraform validate` - Check configuration syntax and consistency
- `terraform fmt` - Format code to canonical style
- `terraform apply` - Apply changes (NEVER run in this project without approval)

## State Management
- `terraform state list` - List resources in state
- `terraform state show <resource>` - Show resource attributes
- `terraform state mv` - Move/rename resources in state
- `terraform state rm` - Remove resource from state (does not destroy)
- `terraform state pull` - Download remote state
- `terraform state push` - Upload state (use with extreme caution)

## Import and Migration
- `terraform import <address> <id>` - Import existing resource into state
- `import` blocks (Terraform 1.5+) - Declarative import in configuration
- `moved` blocks - Refactor without destroying/recreating resources
- `removed` blocks (Terraform 1.7+) - Remove from state without destroying

## Inspection
- `terraform show` - Display current state or plan output
- `terraform output` - Display output values
- `terraform graph` - Generate dependency graph (DOT format)
- `terraform providers` - Show provider requirements
- `terraform console` - Interactive expression evaluation

## Testing
- `terraform test` - Run test files (`.tftest.hcl`) for modules
- Tests support `plan` and `apply` modes
- Use `mock_provider` for unit testing without real infrastructure
- Variables, assertions, and expected outcomes in test files

## Workspaces
- `terraform workspace list/new/select/delete`
- Separate state per workspace
- Use for environment isolation (dev, staging, prod)
- Access current workspace: `terraform.workspace`