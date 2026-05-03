---
name: helm
description: >-
  Helm package manager reference for Kubernetes application deployment and management. 
  Use when user mentions "Helm", "Helm charts", "helm install", "helm upgrade", "values.yaml", 
  "Chart.yaml", "templates", "Helm repositories", or asks about Kubernetes package management, 
  application deployment, or chart development.
metadata:
  author: SHELYOG
  version: 2.0.0
  category: kubernetes
  updated: 2026-05-03
---
# Helm Comprehensive Reference

Use this skill when working with Helm charts, templating, releases, or chart repositories.

## Core Concepts

- **Chart** - Package of Kubernetes resource templates and metadata
- **Release** - Instance of a chart deployed to a cluster
- **Repository** - HTTP server or OCI registry hosting chart packages
- **Values** - Configuration that customizes chart templates

## Chart Structure

```
mychart/
├── Chart.yaml           # Chart metadata (name, version, dependencies)
├── Chart.lock           # Locked dependency versions
├── values.yaml          # Default configuration values
├── values.schema.json   # JSON Schema for values validation (optional)
├── README.md            # Chart documentation
├── LICENSE              # License file
├── .helmignore          # Files to exclude from packaging
├── templates/           # Kubernetes manifest templates
│   ├── _helpers.tpl     # Reusable template definitions
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── NOTES.txt        # Post-install usage notes
│   └── tests/           # Test templates
│       └── test-connection.yaml
├── charts/              # Dependency charts (subcharts)
└── crds/                # Custom Resource Definitions
```

## Chart.yaml

```yaml
apiVersion: v2
name: mychart
version: 1.0.0          # Chart version (SemVer 2)
appVersion: "2.0.0"      # Application version
description: Description
type: application         # application or library
dependencies:
  - name: postgresql
    version: "~12.0"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled
```

## Templating

### Built-in Objects
- `.Release` - Release info (Name, Namespace, IsInstall, IsUpgrade, Revision)
- `.Values` - Values from values.yaml and overrides
- `.Chart` - Chart.yaml contents
- `.Files` - Access non-template files in the chart
- `.Capabilities` - Cluster capabilities (API versions, K8s version)
- `.Template` - Current template name and base path

### Template Functions
- **include** - Render a named template (pipeable): `{{ include "mychart.labels" . | nindent 4 }}`
- **template** - Render a named template (not pipeable; avoid in favor of include)
- **required** - Fail if value is empty: `{{ required "image.tag is required" .Values.image.tag }}`
- **toYaml** - Convert to YAML string: `{{ toYaml .Values.resources | nindent 12 }}`
- **tpl** - Render a string as a template: `{{ tpl .Values.customTemplate . }}`
- **lookup** - Query live cluster resources: `{{ lookup "v1" "Secret" "ns" "name" }}`

### Control Flow
- `{{ if }}...{{ else if }}...{{ else }}...{{ end }}`
- `{{ range }}...{{ end }}` - Iterate over lists/maps
- `{{ with }}...{{ end }}` - Set scope
- `{{- ... -}}` - Trim whitespace

### Helper Templates (_helpers.tpl)
- Define reusable snippets with `{{ define "name" }}...{{ end }}`
- Standard helpers: fullname, labels, selectorLabels, serviceAccountName
- Use `include` to call helpers within templates

### Whitespace Control
- `{{-` trims leading whitespace; `-}}` trims trailing whitespace
- Use `nindent` for consistent indentation: `{{ toYaml .Values.foo | nindent 8 }}`
- Use `indent` when not starting on a new line

## Values Management

### Precedence (lowest to highest)
1. Parent chart's `values.yaml`
2. Subchart's `values.yaml`
3. `-f` / `--values` flag files
4. `--set` flag values

### Best Practices
- Use flat keys where possible; avoid deep nesting
- Use camelCase for value names
- Document values with inline comments
- Provide sensible defaults for all values
- Use `values.schema.json` for validation
- Type-check with `kindIs`, `typeIs`
- Use `required` for mandatory values with no default

## Lifecycle Hooks

Hooks run at specific points in a release lifecycle:

| Hook | When |
|------|------|
| `pre-install` | Before any resources are created |
| `post-install` | After all resources are loaded |
| `pre-delete` | Before any resources are deleted |
| `post-delete` | After all resources are deleted |
| `pre-upgrade` | Before any resources are updated |
| `post-upgrade` | After all resources are updated |
| `pre-rollback` | Before rollback |
| `post-rollback` | After rollback |
| `test` | When `helm test` is invoked |

### Hook Annotations
```yaml
annotations:
  "helm.sh/hook": pre-install,pre-upgrade
  "helm.sh/hook-weight": "5"              # Execution order (ascending)
  "helm.sh/hook-delete-policy": hook-succeeded  # Cleanup policy
```

### Hook Delete Policies
- `hook-succeeded` - Delete after successful execution
- `hook-failed` - Delete after failure
- `before-hook-creation` - Delete old hook before creating new one (default)

## Dependencies (Subcharts)

### Declaration
```yaml
# Chart.yaml
dependencies:
  - name: redis
    version: "~17.0"
    repository: "https://charts.bitnami.com/bitnami"
    condition: redis.enabled        # Toggle with values
    tags:
      - backend                     # Toggle groups with tags
```

### Management
- `helm dependency update` - Download and lock dependencies
- `helm dependency build` - Build from lock file
- `helm dependency list` - Show dependency status
- Stored in `charts/` directory
- Use version ranges (`~1.2`, `^1.2`, `>=1.0 <2.0`)

### Subchart Values
- Parent can override subchart values under the subchart's key
- `global` values are shared across all subcharts
- Subcharts cannot access parent values (isolation)

## Repositories and Registries

### Helm Repositories (HTTP)
- `helm repo add <name> <url>` - Add a repository
- `helm repo update` - Refresh repository index
- `helm repo list` - List configured repositories
- `helm search repo <keyword>` - Search repositories

### OCI Registries
- `helm push <chart>.tgz oci://<registry>` - Push chart to OCI registry
- `helm pull oci://<registry>/<chart>` - Pull chart from OCI registry
- Works with ECR, Docker Hub, GitHub Container Registry, etc.

### Artifact Hub
- Central discovery platform for Helm charts
- https://artifacthub.io/

## Plugins

### Plugin Types
- **CLI plugins** - Add custom `helm` subcommands
- **Getter plugins** - Support additional storage backends
- **Postrenderer plugins** - Modify rendered manifests before deployment

### Useful Plugins
- `helm-diff` - Preview changes before upgrade
- `helm-secrets` - Manage encrypted values files
- `helm-unittest` - Unit test chart templates
- `helm-s3` - Use S3 as chart repository

## Testing and Validation

### Linting
- `helm lint <chart>` - Validate chart structure and templates
- Checks for common issues and best practice violations

### Template Rendering
- `helm template <release> <chart>` - Render templates locally
- `helm template --debug` - Show detailed rendering info
- `helm template --set key=val` - Test with overrides
- Pipe to `kubectl apply --dry-run=server` for server-side validation

### Chart Tests
- Templates in `templates/tests/` with `"helm.sh/hook": test` annotation
- `helm test <release>` - Run tests against a deployed release
- Tests are pods that exit 0 on success

### Schema Validation
- `values.schema.json` validates values on install/upgrade/template
- JSON Schema format; supports types, required fields, patterns, enums

## Deployment Patterns

### Terraform Integration
- Use `helm_release` resource in Terraform
- Pass values via `set` blocks or `values` files
- Use `templatefile()` for dynamic values
- Set `create_namespace = true` for namespace management
- Use `dependency_update = true` to auto-update deps

### GitOps (ArgoCD)
- ArgoCD Application resources point to Helm charts
- Values files per environment
- Automated sync for continuous deployment
- Use ApplicationSets for multi-cluster/multi-env

## CLI Quick Reference

| Command | Purpose |
|---------|---------|
| `helm list` | List releases |
| `helm get values <release>` | Show release values |
| `helm get manifest <release>` | Show deployed manifests |
| `helm get all <release>` | Show all release info |
| `helm history <release>` | Release revision history |
| `helm status <release>` | Release status |
| `helm template <release> <chart>` | Render locally |
| `helm lint <chart>` | Validate chart |
| `helm diff upgrade <release> <chart>` | Preview changes (plugin) |
| `helm search repo <keyword>` | Search repos |
| `helm show values <chart>` | Show default values |

## Reference Documentation

### Core
- **Helm Documentation**: https://helm.sh/docs/
- **Chart Development Guide**: https://helm.sh/docs/developing_charts/
- **Chart Template Guide**: https://helm.sh/docs/chart_template_guide/
- **Template Function List**: https://helm.sh/docs/chart_template_guide/function_list/

### Best Practices
- **Chart Best Practices**: https://helm.sh/docs/chart_best_practices/
- **General Conventions**: https://helm.sh/docs/chart_best_practices/conventions/
- **Values**: https://helm.sh/docs/chart_best_practices/values/
- **Templates**: https://helm.sh/docs/chart_best_practices/templates/
- **Dependencies**: https://helm.sh/docs/chart_best_practices/dependencies/
- **Labels and Annotations**: https://helm.sh/docs/chart_best_practices/labels/
- **RBAC**: https://helm.sh/docs/chart_best_practices/rbac/

### Advanced Topics
- **Chart Hooks**: https://helm.sh/docs/topics/charts_hooks/
- **Chart Tests**: https://helm.sh/docs/topics/chart_tests/
- **Library Charts**: https://helm.sh/docs/topics/library_charts/
- **Chart Repository Guide**: https://helm.sh/docs/topics/chart_repository/
- **Registries (OCI)**: https://helm.sh/docs/topics/registries/
- **Plugins Guide**: https://helm.sh/docs/plugins/overview/
- **Tips and Tricks**: https://helm.sh/docs/howto/charts_tips_and_tricks/

### Registry
- **Artifact Hub**: https://artifacthub.io/
