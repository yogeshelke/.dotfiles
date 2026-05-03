# Cursor Skills Testing Framework

This document defines comprehensive test scenarios for all custom skills to ensure proper triggering and functionality.

## Testing Categories

### 1. Trigger Accuracy Tests
Verify skills activate on intended phrases and don't activate on unrelated queries.

### 2. Functional Tests  
Verify skills produce correct outputs and handle edge cases properly.

### 3. Integration Tests
Test MCP integration and cross-skill functionality.

---

## Skill Test Scenarios

### AWS Skill

#### ✅ Should Trigger On:
- "Set up VPC for production environment"
- "Configure EKS cluster with best practices" 
- "Create RDS database with encryption"
- "IAM roles for service accounts"
- "S3 bucket policy configuration"
- "CloudWatch monitoring setup"
- "Route53 DNS configuration"
- "ACM certificate management"
- "Security groups for ALB"
- "Load balancer configuration"
- "Well-Architected Framework review"
- "AWS best practices for security"
- "Cloud architecture design"
- "Infrastructure design patterns"

#### ❌ Should NOT Trigger On:
- "Azure resource groups"
- "GCP compute engine" 
- "General cloud concepts"
- "Docker containers"
- "Kubernetes without AWS context"

#### 🧪 Functional Tests:
- **Test**: Request VPC setup guidance
- **Expected**: Provides multi-AZ, subnet guidance, references detailed guides
- **Validation**: Contains security best practices, links to references/

### Terraform Skill

#### ✅ Should Trigger On:
- "Terraform plan shows unexpected changes"
- "terraform apply failed with error"
- "Infrastructure as code best practices"
- "HCL syntax for resource blocks"
- "State management issues" 
- "terraform modules configuration"
- "Provider configuration"
- "terraform import existing resources"
- ".tf file syntax error"

#### ❌ Should NOT Trigger On:
- "Ansible playbooks"
- "CloudFormation templates"
- "AWS CDK deployment"
- "General devops questions"

#### 🧪 Functional Tests:
- **Test**: Ask about state management
- **Expected**: Explains S3 backend, DynamoDB locking, references CLI commands
- **Validation**: Contains troubleshooting section, progressive disclosure working

### Git PR Workflow Skill

#### ✅ Should Trigger On:
- "pr workflow" (exact match)
- "git pr" (exact match)
- "create pr workflow" (exact match)
- "run pr workflow" (exact match)
- "commit, push and create PR"
- "Follow the standard PR workflow"

#### ❌ Should NOT Trigger On:
- "What is a pull request?"
- "How do pull requests work?"
- "PR review process"
- "Git branch strategy"
- General PR discussions

#### 🧪 Functional Tests:
- **Test**: Say "pr workflow"
- **Expected**: Executes git status → commit → push → create PR → Slack notification
- **Validation**: Uses specific commit message format, creates PR with team review

### Ask Clarifying Questions Skill

#### ✅ Should Trigger On:
- Any infrastructure change request
- Deployment operations
- Plan creation tasks
- Multi-step operations with risk
- Ambiguous requests
- Operations affecting production

#### ❌ Should NOT Trigger On:
- Fully specified requests
- Read-only operations (describe, get, list)
- Following approved plans
- Obvious context situations

#### 🧪 Functional Tests:
- **Test**: "Deploy the application"
- **Expected**: Asks about environment, scope, blast radius
- **Validation**: Uses AskQuestion tool, structured questions

### Kubernetes Skill

#### ✅ Should Trigger On:
- "Kubernetes deployment issues"
- "kubectl commands for debugging"
- "Pod scheduling problems"
- "Service discovery not working"
- "Ingress configuration"
- "Namespace management"
- "ConfigMap and Secret handling"
- "Persistent volume issues"
- "Cluster autoscaling"
- "YAML manifest validation"

#### ❌ Should NOT Trigger On:
- "Docker containers only"
- "Docker Swarm orchestration"
- "Nomad scheduling"

#### 🧪 Functional Tests:
- **Test**: "Pod is stuck in pending state"
- **Expected**: Debugging steps, resource checks, node capacity
- **Validation**: Includes kubectl commands, troubleshooting flow

---

## Test Execution Plan

### Phase 1: Manual Trigger Testing (Immediate)
```bash
# Test each skill with 5 positive and 5 negative trigger phrases
# Document which skills activate for each phrase
# Identify over-triggering or under-triggering issues
```

### Phase 2: Functional Validation (Short-term)
```bash
# For each skill:
# 1. Trigger with realistic scenario
# 2. Verify output quality and completeness  
# 3. Check progressive disclosure works
# 4. Validate troubleshooting sections
```

### Phase 3: Integration Testing (Medium-term)
```bash
# Test MCP integration (git-pr-workflow with Slack)
# Test skill interactions (ask-clarifying-questions → other skills)
# Verify no conflicts between similar skills
```

## Success Criteria

### Trigger Accuracy
- **Target**: 95%+ accuracy on trigger phrases
- **Measurement**: 10 test phrases per skill, track activation rate

### Functional Quality  
- **Target**: Complete, actionable guidance in single response
- **Measurement**: User can complete task without additional prompts

### Performance
- **Target**: Skills load within 2-3 seconds
- **Measurement**: Progressive disclosure reduces context load time

## Test Results Template

### Skill: [name]
**Date**: [test date]  
**Version**: [skill version]

#### Trigger Test Results:
- ✅ Positive triggers: X/Y successful
- ❌ False positives: X instances  
- ⚠️ Missed triggers: X instances

#### Functional Test Results:
- Output completeness: [rating]
- Actionability: [rating]  
- References working: [yes/no]

#### Issues Found:
1. [Issue description]
2. [Issue description]

#### Actions Taken:
1. [Fix applied]
2. [Fix applied]

---

## Continuous Monitoring

### Weekly Checks:
- Review skill activation logs
- Monitor for user corrections/clarifications
- Track completion rates

### Monthly Reviews:
- Update test scenarios based on usage
- Refine trigger phrases if needed
- Update skill versions for improvements

### Quarterly Audits:
- Full compliance review against Anthropic guidelines
- Performance optimization
- New skill development based on usage patterns