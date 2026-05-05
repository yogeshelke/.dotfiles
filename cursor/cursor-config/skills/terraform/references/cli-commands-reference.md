# CLI Commands Reference

## Core Workflow
- `terraform init` - Initialize working directory, download providers/modules
- `terraform init -upgrade` - Update providers/modules to latest allowed versions
- `terraform plan` - Preview changes (always review before apply)
- `terraform plan -out=FILE` - Save executable plan for later apply (critical for CI)
- `terraform plan -detailed-exitcode` - Detect changes in automation (0=no change, 2=changes)
- `terraform validate` - Check configuration syntax and consistency
- `terraform fmt` - Format code to canonical style
- `terraform apply plan.tfplan` - Executes exactly the saved plan (no re-evaluation, CI only, NEVER without approval)

## State Management
- `terraform state list` - List resources in state
- `terraform state show <resource>` - Show resource attributes
- `terraform state mv` - Move/rename resources in state
- `terraform state rm` - Remove resource from state (does not destroy)
- `terraform state pull` - Download remote state
- `terraform state push` - Upload state — can overwrite remote state and cause corruption; avoid unless recovery scenario
- Avoid `-lock=false` on any command — can cause concurrent state corruption

## Import and Migration
- `terraform import <address> <id>` - Import existing resource into state
- `import` blocks (Terraform 1.5+) - Declarative import in configuration
- `moved` blocks - Refactor without destroying/recreating resources
- `removed` blocks (Terraform 1.7+) - Remove from state without destroying

## Inspection
- `terraform show` - Display current state or plan output
- `terraform show -json` - Output state/plan in machine-readable format (used with jq/tools in CI)
- `terraform output` - Display output values
- `terraform graph` - Generate dependency graph (DOT format, visualize with Graphviz)
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
- Use for simple environment isolation (not recommended for critical multi-env setups — prefer separate backends)
- Access current workspace: `terraform.workspace`
