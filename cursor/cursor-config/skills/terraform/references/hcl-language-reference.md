# HCL Language Reference

## Resource Blocks
- `resource` - Declares infrastructure objects
- `data` - Reads existing infrastructure or external data
- `variable` - Input parameters
- `output` - Return values
- `locals` - Computed values within a module
- `module` - Calls reusable modules
- `provider` - Configures provider plugins
- `terraform` - Settings block (required_version, required_providers, backend)

## Expressions
- Direct references: `var.name`, `local.value`, `resource.attr` (preferred)
- String interpolation: `"${var.name}-suffix"` (legacy syntax, still supported — use only when embedding in strings)
- Heredoc: `<<EOT ... EOT` for multi-line strings (IAM policies, scripts, templates)
- Template directives: `%{ if }`, `%{ for }` — used in heredoc templates for conditional/loop rendering
- Conditional: `condition ? true_val : false_val`
- For expressions: `[for s in var.list : upper(s)]`, `{for k, v in var.map : k => v}`
- Splat: `aws_instance.example[*].id` — extracts attribute from all instances of a resource
- Dynamic blocks: `dynamic "ingress" { ... }` — generates nested blocks from a collection (only works for nested blocks, not top-level resources)
- Operators: `+`, `-`, `*`, `/`, `%`, `&&`, `||`, `!`, `==`, `!=`, `<`, `>`, `<=`, `>=`

## Type System
- Primitives: `string`, `number`, `bool`
- Collections: `list(type)` (same-type elements), `set(type)`, `map(type)`
- Structural: `object({...})`, `tuple([...])` (fixed-length, mixed types)
- `any` - Accepts any type (avoid unless necessary — reduces type safety)
- `null` - Absence of value (used to conditionally omit arguments)
- Use `optional()` for optional object attributes with defaults
- Pattern: `try(var.optional_value, null)` — safely access with fallback

## Built-in Functions
- String: `format`, `join`, `split`, `replace`, `trim`, `lower`, `upper`, `regex`
- Collection: `length`, `merge`, `lookup`, `flatten`, `distinct`, `sort`, `concat`, `coalesce`
- Filesystem: `file`, `filebase64`, `templatefile`, `yamldecode`, `jsondecode`
- Encoding: `base64encode`, `base64decode`, `jsonencode`, `yamlencode`
- Crypto: `sha256`, `md5`, `bcrypt`
- IP/CIDR: `cidrsubnet`, `cidrhost`, `cidrnetmask`
- Type: `try`, `can`, `type`, `nonsensitive`, `sensitive`

## Meta-Arguments
- `count` - Create multiple instances by count
- `for_each` - Create instances from a map or set
- `depends_on` - Explicit dependency declaration
- `lifecycle` - `create_before_destroy`, `prevent_destroy`, `ignore_changes`, `replace_triggered_by`
- `provider` - Select non-default provider configuration
