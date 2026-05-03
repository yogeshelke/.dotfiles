# Plan AWS Infrastructure

Use this command template when planning new AWS infrastructure or modifying existing resources.

## Inputs Required
- **What**: Description of the infrastructure change
- **Environment**: Target environment (dev, staging, production)
- **Region**: AWS region
- **Existing context**: Related Terraform modules or state

## Steps

### 1. Scope Assessment
- What AWS services are involved?
- What Terraform modules already exist?
- What networking requirements are there (VPC, subnets, security groups)?
- What IAM roles/policies are needed?

### 2. Architecture Review
- Is this multi-AZ for availability?
- What's the connectivity model (public, private, VPN)?
- What encryption is required (KMS, SSE)?
- What logging/monitoring is needed?

### 3. Terraform Plan
```bash
# Format and validate
terraform fmt -recursive
terraform validate

# Generate plan for review
terraform plan -out=tfplan
terraform show -json tfplan | jq '.resource_changes[] | {action: .change.actions, address: .address}'
```

### 4. Security Review
- Run `checkov -d .` or `tfsec .` on the Terraform directory
- Review IAM policies for least privilege
- Verify encryption settings
- Check security group rules

### 5. Cost Estimate
- Check instance types and pricing
- Consider Reserved Instances / Savings Plans for baseline
- Consider Spot for fault-tolerant workloads
- Estimate monthly cost delta

### 6. Output
Produce a plan document following the format in `agents/planner.md`.
