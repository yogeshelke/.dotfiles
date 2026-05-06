# Cursor IDE Agent Orchestration Ecosystem

A comprehensive cloud platform engineering system powered by specialized AI agents for AWS infrastructure, Kubernetes, and DevOps workflows.

## 🏗️ Architecture Overview

This dotfiles configuration provides a **three-tier agent orchestration system** for cloud platform engineering:

```
Tier 1 - Planning: /architect → plan-reviewer → USER approval
Tier 2 - Execution: /iac-dev | /k8s-expert | /devops  
Tier 3 - Quality: /reviewer → /tester → /pr-agent
```

### Agent Ecosystem

| Command | Agent | Tier | Phase | Specialization |
|---------|-------|------|-------|----------------|
| `/architect` | AWS Cloud Architect | 1 - Plan | Plan | Architecture design, infrastructure planning |
| `/iac-dev` | IaC Developer | 2 - Build | Build | Terraform, Helm, YAML implementation |
| `/k8s-expert` | Kubernetes Expert | 2 - Build | Build | EKS, pods, networking analysis |
| `/devops` | DevOps Engineer | 2 - Build | Build | CI/CD, GitHub Actions, monitoring |
| `/reviewer` | Security Reviewer | 3 - Quality | Review | Security audit, compliance checks |
| `/tester` | Platform Tester | 3 - Quality | Test | Test automation, validation scripts |
| `/pr-agent` | PR Agent | 3 - Quality | PR | Git workflow, PR creation, Slack notifications |

## 🚀 Quick Start

### 1. Automatic Setup
The agent system is automatically configured by `bootstrap.sh`:

```bash
# All agent configurations are symlinked:
~/.cursor/agents/     → cursor/cursor-config/agents/
~/.cursor/commands/   → cursor/cursor-config/commands/ 
~/.cursor/rules/      → cursor/cursor-config/rules/
~/.cursor/skills/     → cursor/cursor-config/skills/
```

### 2. MCP Integration Setup
Configure MCP servers for enhanced capabilities:

```bash
# Copy template and add your API tokens
cp ~/.dotfiles/cursor/mcp.json.template ~/.cursor/mcp.json
```

Edit `~/.cursor/mcp.json` with your credentials:
- **Atlassian**: Site name, email, API token
- **Slack**: xoxc and xoxd tokens
- **Other integrations**: As needed

### 3. Standard Workflow

1. **Plan Phase**: Start with `/architect` for new infrastructure
2. **Build Phase**: Use `/iac-dev` for implementation  
3. **Quality Phase**: Run `/reviewer` → `/tester` → `/pr-agent`

## 🎯 Core Features

### Skills-Based Knowledge System
- **AWS**: Comprehensive service patterns and best practices
- **Terraform**: HCL syntax, modules, state management
- **Kubernetes/EKS**: Container orchestration, networking
- **Helm**: Package management and chart development
- **GitHub Actions**: CI/CD automation workflows
- **Datadog**: Monitoring, observability, SLOs

### Verification Gates
All agents must provide **fresh evidence** before claiming completion:
- No "should work" or "looks correct" - only verified output
- Commands like `terraform validate`, `helm lint` must pass
- Security and compliance checks enforced

### Interactive Safety
- **No autonomous actions** on production systems
- All destructive operations require explicit approval
- Command policy is split: **always-on core** (`command-restrictions-core.mdc`) plus **glob-scoped** Terraform, Kubernetes, and AWS CLI rules when matching files are in context
- Environment boundary enforcement

## 📁 Directory Structure

```
cursor/
├── README.md                    # This file - ecosystem overview
├── settings.json               # IDE configuration  
├── keybindings.json           # Custom key bindings
├── mcp.json.template          # MCP server template
└── cursor-config/
    ├── agents/                # Agent persona definitions
    │   ├── architect.md       # AWS cloud architecture planning
    │   ├── iac-dev.md        # Infrastructure as code development
    │   ├── k8s-expert.md     # Kubernetes domain expertise  
    │   ├── devops.md         # CI/CD and platform operations
    │   ├── reviewer.md       # Security and compliance review
    │   ├── tester.md         # Platform testing and validation
    │   └── pr-agent.md       # Git workflow automation
    ├── commands/              # Slash command interfaces
    ├── rules/                 # Behavioral guidelines
    │   ├── orchestrator.mdc   # Agent coordination rules
    │   ├── verification-gate.mdc  # Evidence requirements
    │   ├── interactive-gate.mdc   # Safety controls
    │   ├── command-restrictions-core.mdc  # Core command policy (always on)
    │   ├── terraform-safety.mdc   # Terraform CLI (glob-scoped)
    │   ├── kubernetes-safety.mdc  # kubectl/Helm (glob-scoped)
    │   ├── aws-safety.mdc         # AWS CLI (glob-scoped)
    │   └── aws-security.mdc   # AWS security standards
    └── skills/                # Domain knowledge modules
        ├── aws/              # AWS reference materials
        ├── terraform/        # Terraform best practices  
        ├── kubernetes/       # K8s operational guides
        └── github/           # CI/CD workflow patterns
```

## 🔧 Usage Patterns

### New Infrastructure Project
```bash
/architect          # Design architecture, create .plan.md
# → User reviews and approves plan
/iac-dev           # Implement Terraform modules  
/reviewer          # Security and compliance audit
/pr-agent          # Create PR with devops-platform review
```

### Quick Configuration Change  
```bash
/iac-dev           # Make the change directly
/reviewer          # Quick security check
/pr-agent          # Commit and PR
```

### Troubleshooting Issues
```bash
/k8s-expert        # Analyze cluster problems
/devops            # Check CI/CD pipeline issues  
```

## 🛡️ Safety & Compliance

### Command Restrictions
- **Terraform**: Only `validate`, `fmt`, `plan` - never `apply`
- **Kubernetes**: Only read operations - no `apply`, `delete`
- **AWS CLI**: Only describe/get operations - no create/delete
- **Git**: Safe operations only - no force push

### Environment Protection
- Production changes require explicit approval
- No direct cluster modifications
- All changes go through PR workflow
- Verification evidence required

### Security Standards
- IAM least privilege enforcement
- Encryption at rest and in transit
- VPC security group validation  
- Secret management compliance

## 🔍 Monitoring & Observability

The ecosystem includes built-in observability through:
- **Datadog integration** for infrastructure monitoring
- **GitHub Actions** for workflow visibility
- **Slack notifications** for team coordination  
- **Progress tracking** via `/check-progress`

## 🤝 Contributing

### Adding New Agents
1. Create agent definition in `agents/`
2. Add corresponding command in `commands/`
3. Update orchestrator routing rules
4. Add skills as needed

### Extending Skills  
1. Create skill module in `skills/`
2. Follow established patterns for domain knowledge
3. Include practical examples and references
4. Test with relevant agents

---

**Note**: This system is designed for cloud platform engineering teams managing AWS infrastructure, EKS clusters, and DevOps workflows. All configurations are version-controlled and team-shareable through dotfiles.
