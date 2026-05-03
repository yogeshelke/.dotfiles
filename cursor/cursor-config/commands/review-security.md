# Review Security

Use this command template for security reviews of infrastructure code, Kubernetes configs, or CI/CD pipelines.

## Scope
Specify what to review:
- [ ] Terraform code (IAM, networking, encryption, storage)
- [ ] Kubernetes manifests (pod security, RBAC, network policies)
- [ ] GitHub Actions workflows (supply chain, secrets, permissions)
- [ ] Application configuration (secrets management, TLS)

## IAM Review
- List all IAM roles and policies in scope
- Check for `*` in actions or resources
- Verify trust policies are scoped to specific principals
- Confirm IRSA/Pod Identity is used for EKS workloads
- Check for unused or overly broad roles

## Network Review
- List all security groups and their rules
- Flag any `0.0.0.0/0` ingress (except public ALB on 443)
- Verify private subnet usage for internal services
- Check VPC endpoint configuration
- Review Network Policies for default deny

## Encryption Review
- Verify encryption at rest: S3, EBS, RDS, DynamoDB, EFS
- Verify encryption in transit: TLS/HTTPS everywhere
- Check KMS key policies and rotation
- Confirm Terraform state backend encryption

## Secrets Review
- Search for hardcoded secrets (API keys, passwords, tokens)
- Verify secrets are sourced from Secrets Manager or SSM
- Check that Terraform sensitive values are marked correctly
- Verify CI/CD uses OIDC, not stored credentials

## Container Security Review
- Check base image source and vulnerability scan results
- Verify non-root user configuration
- Check for read-only root filesystem
- Review capability drops
- Verify image tag immutability (SHA-based, not `latest`)

## Output
Follow the verifier output format in `agents/verifier.md`:
- Critical / Warning / Info findings with remediation
- List of passed checks
