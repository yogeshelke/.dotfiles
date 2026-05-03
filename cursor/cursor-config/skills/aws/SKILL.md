---
name: aws
description: >-
  Comprehensive AWS reference with architecture patterns and best practices. 
  Use when user mentions "AWS", "set up VPC", "configure EKS cluster", "RDS database", 
  "IAM roles", "S3 bucket", "CloudWatch monitoring", "Route53 DNS", "ACM certificate", 
  "security groups", "load balancer", or asks about "Well-Architected Framework", 
  "AWS best practices", "cloud architecture", "infrastructure design", or any AWS service configuration.
  Do NOT use for non-AWS cloud providers (Azure, GCP) or general cloud concepts without AWS context.
metadata:
  author: SHELYOG
  version: 2.0.0
  category: infrastructure
  updated: 2026-05-03
---
# AWS Comprehensive Reference

This skill provides AWS architecture patterns, best practices, and service guidance following the Well-Architected Framework.

## Well-Architected Framework

The six pillars to evaluate all AWS architecture:

1. **Operational Excellence** - Automate changes, respond to events, define standards
2. **Security** - Protect data and systems through risk assessments and mitigation
3. **Reliability** - Ensure consistent, correct workload performance
4. **Performance Efficiency** - Use resources efficiently as demand changes
5. **Cost Optimization** - Avoid unnecessary costs, right-size resources
6. **Sustainability** - Minimize environmental impact

## Quick Reference

### Most Common Patterns
- **VPC Setup**: Multi-AZ with public/private subnets, NAT Gateways, VPC endpoints
- **EKS Cluster**: Private API endpoint, managed node groups, IRSA, envelope encryption
- **RDS Database**: Multi-AZ Aurora with KMS encryption, automated backups
- **Security**: IAM roles (not users), least-privilege policies, MFA enabled
- **Monitoring**: CloudWatch Logs + Metrics, appropriate retention periods

### Security Essentials
- Use IAM roles, never hardcoded keys
- Enable MFA for all human access
- KMS encryption for data at rest
- VPC endpoints to avoid internet routing
- Security groups with least-privilege rules

### Cost Optimization
- Use Graviton instances for better price/performance
- Right-size resources based on actual usage
- Implement lifecycle policies for S3 and EBS
- Tag everything for cost allocation
- Regular cleanup of unused resources

## Detailed Service Guidance

For comprehensive service-specific best practices, see `references/detailed-service-guides.md`.

For complete documentation links, see `references/documentation-links.md`.

## Troubleshooting

### Common Issues

**IAM Permission Errors**
- Verify IAM policies include required actions
- Check resource ARNs match exactly
- Ensure condition statements aren't blocking access
- For cross-account access, verify trust relationships

**VPC Connectivity Issues**
- Check route tables for correct destination/target
- Verify security groups allow required traffic
- Ensure NACLs aren't blocking (stateless, allow both inbound/outbound)
- For EKS: verify subnet tags for load balancer discovery

**EKS Authentication Problems**
- Use EKS access entries instead of aws-auth ConfigMap
- Verify IAM roles have necessary trust relationships
- Check cluster endpoint access (public/private configuration)
- Ensure kubectl context is correctly configured

**RDS Connection Failures**
- Verify security groups allow database port (3306/5432)
- Check VPC routing for subnet connectivity
- Ensure parameter groups allow required connections
- For cross-AZ: verify Multi-AZ deployment is enabled

### Performance Optimization
- Use VPC endpoints to avoid NAT Gateway costs and improve latency
- Enable CloudWatch detailed monitoring for better visibility
- Implement read replicas for read-heavy workloads
- Use Application Load Balancer target group health checks
