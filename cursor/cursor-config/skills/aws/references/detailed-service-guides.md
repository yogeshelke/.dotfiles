# AWS Detailed Service Guides

## Compute

### EC2
- Use instance types appropriate for workload (compute, memory, storage optimized)
- Use Graviton (ARM) instances for better price-performance
- Enable detailed monitoring for production instances
- Use launch templates for consistent instance configuration
- Tag all instances for cost allocation

### EKS (Elastic Kubernetes Service)
- Use managed node groups or Karpenter for node lifecycle
- Enable envelope encryption for Secrets via KMS
- Use IRSA for pod-level IAM permissions
- Prefer private API server endpoint
- Use EKS access entries for authentication
- Upgrade clusters within the support window (N-3 versions)
- Use managed add-ons (CoreDNS, kube-proxy, VPC CNI)

### ECR (Elastic Container Registry)
- Enable image scanning on push
- Use lifecycle policies to clean up old images
- Use immutable image tags for production
- Cross-region replication for DR scenarios
- Use VPC endpoints for private access

## Networking

### VPC
- Use multiple AZs for high availability (minimum 2, ideally 3)
- Separate public, private, and isolated subnets
- Size CIDR blocks for future growth; use secondary CIDRs if needed
- Use NAT Gateways in each AZ for resilient outbound access
- Enable VPC Flow Logs for network visibility
- Use Transit Gateway for multi-VPC connectivity

### Subnets
- Private subnets for workloads and databases
- Public subnets only for load balancers and NAT Gateways
- Tag subnets for EKS auto-discovery (`kubernetes.io/role/elb`, `kubernetes.io/role/internal-elb`)

### VPC Endpoints
- Use Gateway endpoints for S3 and DynamoDB (free)
- Use Interface endpoints for other services (ECR, STS, SSM, KMS, CloudWatch Logs, RDS)
- Reduces data transfer costs and improves security by keeping traffic on AWS backbone

### Security Groups
- Use least-privilege rules; avoid `0.0.0.0/0` for ingress
- Reference security groups instead of CIDR blocks where possible
- Separate security groups by function (ALB, nodes, RDS, endpoints)

### Route53
- Use alias records for AWS resources (free, faster resolution)
- Health checks for DNS failover
- Private hosted zones for internal service discovery
- Use External DNS for automatic record management from Kubernetes

### Load Balancing
- ALB for HTTP/HTTPS traffic with path/host-based routing
- NLB for TCP/UDP and high-performance workloads
- Use AWS Load Balancer Controller for Kubernetes integration
- Enable access logging to S3

## Database

### RDS / Aurora
- Use Multi-AZ deployments for production
- Enable automated backups with appropriate retention
- Use KMS encryption for data at rest
- Use IAM database authentication where appropriate
- Performance Insights for query analysis
- Use parameter groups for custom configuration
- Separate read replicas for read-heavy workloads
- Use RDS Proxy for connection pooling

## Security & Identity

### IAM
- Follow least-privilege principle
- Use IAM roles instead of long-term access keys
- Enable MFA for all human users
- Use IAM policies with conditions (source IP, MFA, tags)
- Use OIDC federation for CI/CD (GitHub Actions)
- Regular access reviews and unused credential removal
- Use Service Control Policies (SCPs) for guardrails

### KMS
- Use customer-managed keys for sensitive workloads
- Enable key rotation (automatic annual rotation)
- Use key policies with least-privilege grants
- Separate keys by service/function (EBS, RDS, S3, Secrets Manager)
- Use aliases for key management

### ACM (Certificate Manager)
- Use ACM for public TLS certificates (free, auto-renewed)
- DNS validation preferred over email validation
- Request certificates in the correct region (us-east-1 for CloudFront)
- Use wildcard certificates to reduce management overhead

### Secrets Manager
- Rotate secrets automatically
- Use resource-based policies for cross-account access
- Reference secrets from Kubernetes using External Secrets Operator or CSI driver
- Enable versioning for secret rollback

## Storage

### S3
- Enable versioning for critical buckets
- Use lifecycle policies for cost optimization (transition to Glacier, expire)
- Block public access by default
- Enable server-side encryption (SSE-S3 or SSE-KMS)
- Use S3 Intelligent-Tiering for unknown access patterns
- Enable access logging for audit trails

### DynamoDB
- Use for Terraform state locking
- On-demand capacity for unpredictable workloads
- Enable point-in-time recovery
- Use KMS encryption

## Monitoring & Observability

### CloudWatch
- CloudWatch Logs for centralized log aggregation
- CloudWatch Metrics for service-level monitoring
- CloudWatch Alarms for automated alerting
- Log Insights for ad-hoc log analysis
- Use metric filters to create custom metrics from logs
- Set appropriate retention periods to manage costs

## Cost Management
- Use AWS Cost Explorer for spending analysis
- Set up Budgets and alerts for cost anomalies
- Use Savings Plans for steady-state compute
- Tag resources consistently for cost allocation
- Review unused resources regularly (idle EC2, unattached EBS, old snapshots)