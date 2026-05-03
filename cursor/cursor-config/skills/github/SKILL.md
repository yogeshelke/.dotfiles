---
name: github
description: >-
  GitHub and GitHub Actions reference for repository management, CI/CD pipelines, and automation. 
  Use when user mentions "GitHub", "GitHub Actions", "pull request", "PR", "workflow", "CI/CD", 
  "repository", "branch", "gh CLI", "OIDC", "secrets", "environments", or asks about version control, 
  automation, continuous integration, or deployment workflows.
metadata:
  author: SHELYOG
  version: 2.0.0
  category: devops
  updated: 2026-05-03
---
# GitHub & GitHub Actions Comprehensive Reference

Use this skill when working with GitHub repositories, pull requests, branching, GitHub Actions workflows, CI/CD pipelines, or the gh CLI.

## Repository Management

### Branch Protection Rules
| Setting | Purpose |
|---------|---------|
| Require PR reviews | Enforce code review before merge |
| Require status checks | CI must pass before merge |
| Require signed commits | GPG-signed commits only |
| Restrict push access | Limit who can push to branch |
| Require linear history | No merge commits (rebase/squash only) |
| Lock branch | Prevent any changes |

### Branching Strategies
| Strategy | Flow | Best For |
|----------|------|----------|
| GitHub Flow | `main` + feature branches | Continuous deployment |
| Git Flow | `main` + `develop` + `release` + `feature` | Versioned releases |
| Trunk-based | `main` + short-lived branches | High-velocity teams |

### CODEOWNERS
```
# .github/CODEOWNERS
*                       @org/platform-team
/terraform/             @org/infra-team
/src/api/               @org/backend-team
/.github/workflows/     @org/devops-team
```

## Pull Requests

### PR Best Practices
- Keep PRs small and focused (< 400 lines)
- Use draft PRs for work-in-progress
- Write descriptive titles and descriptions
- Link to issues using `Closes #123` or `Fixes #456`
- Use PR templates (`.github/pull_request_template.md`)
- Request specific reviewers via CODEOWNERS or manually

### PR Template Example
```markdown
<!-- .github/pull_request_template.md -->
## Summary
<!-- Brief description of changes -->

## Changes
- 

## Test Plan
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Related Issues
Closes #
```

### Merge Strategies
| Method | Result | When to use |
|--------|--------|-------------|
| Merge commit | Preserves all commits + merge commit | Feature branches with meaningful commits |
| Squash and merge | Single commit on target branch | Small PRs, noisy commit history |
| Rebase and merge | Linear history, no merge commit | Clean commit history, each commit is atomic |

## GitHub Actions

### Workflow Structure
```yaml
name: CI Pipeline
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: make build

  test:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Test
        run: make test
```

### Trigger Events
| Event | Description |
|-------|-------------|
| `push` | Commits pushed to branch |
| `pull_request` | PR opened, synchronized, reopened |
| `workflow_dispatch` | Manual trigger with inputs |
| `schedule` | Cron-based schedule |
| `release` | Release published, created, etc. |
| `workflow_call` | Called by another workflow (reusable) |
| `repository_dispatch` | External webhook trigger |
| `merge_group` | Merge queue events |

### Event Filters
```yaml
on:
  push:
    branches: [main, 'release/**']
    paths: ['src/**', '!src/**/*.md']
    tags: ['v*']
  pull_request:
    types: [opened, synchronize, reopened]
    branches: [main]
```

### Runners
| Runner | Label | Use Case |
|--------|-------|----------|
| GitHub-hosted (Linux) | `ubuntu-latest`, `ubuntu-24.04` | Standard CI/CD |
| GitHub-hosted (macOS) | `macos-latest`, `macos-15` | iOS/macOS builds |
| GitHub-hosted (Windows) | `windows-latest` | Windows builds |
| Self-hosted | Custom labels | Private network, GPU, compliance |
| Larger runners | `ubuntu-latest-xl` etc. | Resource-intensive builds |

### Job Configuration
```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    concurrency:
      group: deploy-${{ github.ref }}
      cancel-in-progress: true
    environment:
      name: production
      url: https://app.example.com
    if: github.ref == 'refs/heads/main'
    strategy:
      matrix:
        node-version: [18, 20, 22]
      fail-fast: false
```

### Common Actions
| Action | Purpose |
|--------|---------|
| `actions/checkout@v4` | Check out repository code |
| `actions/setup-node@v4` | Set up Node.js |
| `actions/setup-python@v5` | Set up Python |
| `actions/setup-go@v5` | Set up Go |
| `actions/cache@v4` | Cache dependencies |
| `actions/upload-artifact@v4` | Upload build artifacts |
| `actions/download-artifact@v4` | Download artifacts from other jobs |
| `docker/build-push-action@v6` | Build and push Docker images |
| `docker/login-action@v3` | Login to container registry |
| `aws-actions/configure-aws-credentials@v4` | Configure AWS credentials (OIDC) |
| `aws-actions/amazon-ecr-login@v2` | Login to Amazon ECR |
| `hashicorp/setup-terraform@v3` | Set up Terraform CLI |

## Secrets and Variables

### Secret Types
| Type | Scope | Access |
|------|-------|--------|
| Repository secrets | Single repo | All workflows in repo |
| Environment secrets | Specific environment | Jobs using that environment |
| Organization secrets | Org-wide or selected repos | Workflows in permitted repos |

### Using Secrets
```yaml
steps:
  - name: Deploy
    env:
      API_KEY: ${{ secrets.API_KEY }}
    run: ./deploy.sh
```

### Variables (Non-sensitive)
```yaml
steps:
  - name: Build
    env:
      APP_ENV: ${{ vars.APP_ENV }}
    run: echo "Building for $APP_ENV"
```

### Secret Best Practices
- Never echo or log secrets
- Use environment-scoped secrets for sensitive environments
- Rotate secrets regularly
- Use OIDC instead of long-lived credentials where possible
- Mask secrets in logs with `::add-mask::`

## Environments

### Environment Configuration
- **Protection rules** - Required reviewers, wait timers, branch restrictions
- **Environment secrets** - Scoped to jobs targeting the environment
- **Deployment branches** - Restrict which branches can deploy
- **Custom rules** - Third-party integrations for approvals

### Environment Usage
```yaml
jobs:
  deploy-staging:
    environment: staging
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy.sh staging

  deploy-production:
    needs: deploy-staging
    environment:
      name: production
      url: https://app.example.com
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy.sh production
```

## OIDC (OpenID Connect)

### AWS OIDC Authentication
```yaml
permissions:
  id-token: write
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::123456789012:role/github-actions-role
      aws-region: us-east-1
      role-session-name: github-actions-${{ github.run_id }}
```

### AWS IAM Trust Policy for OIDC
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:org/repo:*"
      }
    }
  }]
}
```

## Reusable Workflows

### Defining a Reusable Workflow
```yaml
# .github/workflows/reusable-deploy.yml
name: Reusable Deploy
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      image-tag:
        required: true
        type: string
    secrets:
      AWS_ROLE_ARN:
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - uses: actions/checkout@v4
      - name: Deploy
        run: ./deploy.sh ${{ inputs.environment }} ${{ inputs.image-tag }}
```

### Calling a Reusable Workflow
```yaml
jobs:
  deploy-staging:
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: staging
      image-tag: ${{ needs.build.outputs.image-tag }}
    secrets:
      AWS_ROLE_ARN: ${{ secrets.STAGING_AWS_ROLE_ARN }}
```

### Reusable Workflow Limits
- Max 4 levels of nesting
- Max 20 reusable workflows per workflow file
- Secrets must be passed explicitly (or use `secrets: inherit`)
- `env` context not available in `workflow_call` triggered workflows

## Composite Actions

### Creating a Composite Action
```yaml
# .github/actions/setup-app/action.yml
name: Setup Application
description: Install dependencies and build
inputs:
  node-version:
    description: Node.js version
    default: '20'
runs:
  using: composite
  steps:
    - uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node-version }}
        cache: npm
    - run: npm ci
      shell: bash
    - run: npm run build
      shell: bash
```

### Using a Composite Action
```yaml
steps:
  - uses: actions/checkout@v4
  - uses: ./.github/actions/setup-app
    with:
      node-version: '22'
```

## Workflow Patterns

### CI/CD Pipeline
```yaml
name: CI/CD
on:
  push:
    branches: [main]
  pull_request:

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: make lint

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: make test

  build:
    needs: [lint, test]
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
    steps:
      - uses: actions/checkout@v4
      - id: meta
        uses: docker/metadata-action@v5
        with:
          images: 123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app
          tags: type=sha,prefix=

  deploy:
    if: github.ref == 'refs/heads/main'
    needs: build
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: production
      image-tag: ${{ needs.build.outputs.image-tag }}
```

### Matrix Strategy
```yaml
jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest]
        python: ['3.11', '3.12', '3.13']
        exclude:
          - os: macos-latest
            python: '3.11'
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python }}
```

### Concurrency Control
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

## Permissions

### Minimum Permissions
```yaml
permissions:
  contents: read          # Checkout code
  id-token: write         # OIDC token
  pull-requests: write    # Comment on PRs
  packages: write         # Push to GHCR
  issues: write           # Create/update issues
  actions: read           # Read workflow runs
```

### GITHUB_TOKEN Permissions
- Automatically available in every workflow
- Scoped to the repository
- Use `permissions` key to restrict (principle of least privilege)
- Cannot trigger other workflows (prevents recursive loops)

## gh CLI

### Common Commands
| Command | Purpose |
|---------|---------|
| `gh repo clone org/repo` | Clone repository |
| `gh pr create --title "..." --body "..."` | Create pull request |
| `gh pr list` | List open pull requests |
| `gh pr view 123` | View PR details |
| `gh pr checks 123` | View CI status |
| `gh pr merge 123 --squash` | Merge PR |
| `gh issue create --title "..."` | Create issue |
| `gh issue list --label bug` | List issues by label |
| `gh run list` | List workflow runs |
| `gh run view <id>` | View workflow run |
| `gh run watch <id>` | Watch a running workflow |
| `gh release create v1.0.0` | Create a release |
| `gh api repos/{owner}/{repo}/pulls` | Direct API call |

### gh CLI in Actions
```yaml
steps:
  - uses: actions/checkout@v4
  - name: Create PR comment
    env:
      GH_TOKEN: ${{ github.token }}
    run: gh pr comment ${{ github.event.pull_request.number }} --body "Deployed to staging"
```

## Security Best Practices

### Workflow Security
- Pin actions to full commit SHA (not tags): `actions/checkout@a81bbb...`
- Use `permissions` to restrict `GITHUB_TOKEN` scope
- Avoid `pull_request_target` with `actions/checkout` on PR head (code injection risk)
- Never use `${{ github.event.*.body }}` in `run:` commands (injection risk)
- Use OIDC for cloud provider authentication instead of stored credentials
- Audit third-party actions before using

### Dependabot
```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
    groups:
      actions:
        patterns: ["*"]
  - package-ecosystem: npm
    directory: /
    schedule:
      interval: weekly
```

## Troubleshooting

### Workflow Issues
- Workflow not triggering → Check event filters, branch names, path filters
- Permission denied → Review `permissions` key, check GITHUB_TOKEN scope
- Action not found → Verify action reference, check marketplace
- Job timeout → Increase `timeout-minutes`, check for hanging processes

### OIDC Issues
- AssumeRoleWithWebIdentity failed → Check trust policy conditions, verify `sub` claim format
- Token audience mismatch → Ensure `aud` is `sts.amazonaws.com`
- Wrong account → Verify `role-to-assume` ARN

### Runner Issues
- No matching runner → Check runner labels, verify self-hosted runner is online
- Disk space → Use `actions/cache` cleanup, minimize artifacts
- Rate limits → Use `GITHUB_TOKEN` instead of PAT, implement retry logic

## Reference Documentation

### Core
- **GitHub Docs**: https://docs.github.com/
- **GitHub Actions Docs**: https://docs.github.com/en/actions
- **Actions Marketplace**: https://github.com/marketplace?type=actions
- **GitHub REST API**: https://docs.github.com/en/rest
- **GitHub GraphQL API**: https://docs.github.com/en/graphql

### Actions
- **Workflow Syntax**: https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions
- **Reusable Workflows**: https://docs.github.com/en/actions/using-workflows/reusing-workflows
- **Contexts and Expressions**: https://docs.github.com/en/actions/learn-github-actions/contexts
- **Environment Variables**: https://docs.github.com/en/actions/learn-github-actions/variables
- **Encrypted Secrets**: https://docs.github.com/en/actions/security-guides/encrypted-secrets

### Security
- **Security Hardening**: https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions
- **OIDC**: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect
- **Permissions**: https://docs.github.com/en/actions/using-jobs/assigning-permissions-to-jobs

### gh CLI
- **gh CLI Manual**: https://cli.github.com/manual/
- **gh API**: https://cli.github.com/manual/gh_api
