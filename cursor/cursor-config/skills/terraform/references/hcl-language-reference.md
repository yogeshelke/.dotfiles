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
- String interpolation: `"${var.name}-suffix"`
- Conditional: `condition ? true_val : false_val`
- For expressions: `[for s in var.list : upper(s)]`, `{for k, v in var.map : k => v}`
- Splat: `aws_instance.example[*].id`
- Dynamic blocks: `dynamic "ingress" { ... }` for repeating nested blocks

## Type System
- Primitives: `string`, `number`, `bool`
- Collections: `list(type)`, `set(type)`, `map(type)`
- Structural: `object({...})`, `tuple([...])`
- `any` - Accepts any type
- Use `optional()` for optional object attributes with defaults

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