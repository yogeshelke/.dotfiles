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

## Caching & Performance

### ElastiCache
- Redis for session stores, leaderboards, real-time analytics, pub/sub
- Memcached for simple key-value caching without persistence needs
- Use cluster mode enabled (Redis) for horizontal scaling
- Deploy in private subnets; encrypt in transit and at rest
- Use IAM authentication (Redis 7+) or AUTH tokens
- Multi-AZ with automatic failover for production

### CloudFront
- Use Origin Access Control (OAC) for S3 origins
- Enable WAF integration for DDoS and application layer protection
- Use cache policies and origin request policies (not legacy settings)
- Invalidate only when necessary; prefer versioned file names

## Async & Event-Driven

### SQS
- Standard queues for high throughput; FIFO for strict ordering
- Dead-letter queues for failed message handling
- Visibility timeout should exceed processing time
- Enable server-side encryption (SSE-SQS or SSE-KMS)

### SNS / EventBridge
- SNS for fan-out to multiple subscribers
- EventBridge for event-driven architectures with filtering rules
- Use schema registry for event documentation
- Cross-account event delivery via resource policies

## Disaster Recovery

### Strategy Selection
| Strategy | RTO | RPO | Cost | Use When |
|----------|-----|-----|------|----------|
| Backup & Restore | Hours | Hours | Lowest | Non-critical, can tolerate downtime |
| Pilot Light | 10-30 min | Minutes | Low | Core systems need fast recovery |
| Warm Standby | Minutes | Seconds-Minutes | Medium | Business-critical, low RTO needed |
| Active-Active | Near-zero | Near-zero | Highest | Mission-critical, zero-downtime required |

### Cross-Region Patterns
- Aurora Global Database: <1s replication, promote secondary in <1 min
- S3 Cross-Region Replication: eventual consistency, 15-min SLA
- DynamoDB Global Tables: multi-region active-active
- Route53 health checks + DNS failover for automated traffic steering
- EKS: separate cluster per region with shared ECR images

### DR Testing
- Schedule regular DR drills (quarterly minimum)
- Use chaos engineering (AWS Fault Injection Simulator) to validate resilience
- Document and automate runbooks — manual failover is error-prone under pressure

## AI/ML Platforms

### Amazon Bedrock (Managed Foundation Models)
- Fully managed access to foundation models (Claude, Titan, Llama, Mistral) via API
- No infrastructure to manage — pay per token/request
- **Knowledge Bases**: RAG (Retrieval Augmented Generation) with S3/OpenSearch as data source
- **Agents**: Multi-step task execution using function calling
- **Guardrails**: Content filtering, PII redaction, topic denial
- **Model evaluation**: Compare models on your data before selecting
- Use VPC endpoints for private access (no internet traversal)
- Enable CloudWatch logging for inference requests
- Use provisioned throughput for predictable latency on high-volume workloads

### Amazon SageMaker
- **SageMaker Studio**: IDE for ML development (notebooks, experiments, pipelines)
- **Training**: Managed training jobs with spot instances (up to 90% cost reduction)
- **Inference Endpoints**: Real-time, serverless, or async inference options
  - Real-time: persistent endpoint, low latency, pay per hour
  - Serverless: scale to zero, pay per request, cold starts
  - Async: batch/large payload processing via S3
- **Multi-model endpoints**: Host multiple models on single endpoint (cost optimization)
- **Model Registry**: Version models, track lineage, approval workflows
- **Feature Store**: Centralized feature storage for training and inference
- Deploy in private subnets; use VPC-only mode for Studio
- Use IRSA/Pod Identity if serving from EKS via SageMaker endpoints

### SageMaker on EKS (Self-Managed Inference)
- Use Kubernetes operators for SageMaker (ACK — AWS Controllers for Kubernetes)
- Karpenter node pools with GPU instance types (p4d, g5, inf2)
- Use Neuron SDK for AWS Inferentia/Trainium chips (cost-effective inference)
- NVIDIA device plugin for GPU workloads
- Horizontal Pod Autoscaler on custom metrics (queue depth, inference latency)
- Topology-aware scheduling for multi-GPU training

### MLOps Pipeline Patterns

```
Data → Feature Store → Training → Model Registry → Approval → Deployment → Monitoring
         ↑                                                           ↓
         └──────────── Retraining trigger (drift detected) ←────────┘
```

**Components:**
- **Data pipeline**: S3 + Glue/Athena for data preparation, EventBridge for triggers
- **Feature engineering**: SageMaker Feature Store (online + offline)
- **Training pipeline**: SageMaker Pipelines or Step Functions for orchestration
- **Experiment tracking**: SageMaker Experiments (metrics, params, artifacts)
- **Model registry**: SageMaker Model Registry with approval gates (Manual/CI)
- **Deployment**: SageMaker endpoints or EKS (inference containers)
- **Monitoring**: SageMaker Model Monitor for data drift, bias detection, quality metrics
- **Retraining**: EventBridge trigger on drift detection → new training job

### GPU/Accelerator Instance Selection

| Use Case | Instance Family | Notes |
|----------|----------------|-------|
| LLM inference (large) | p4d, p5 (NVIDIA A100/H100) | High memory, expensive |
| LLM inference (cost-opt) | inf2 (AWS Inferentia2) | Best cost/token for supported models |
| Training (general) | p4d, p5, trn1 (Trainium) | trn1 best price/performance for training |
| Fine-tuning (small models) | g5 (NVIDIA A10G) | Good balance of cost and capability |
| Embedding/lightweight | g5, inf2 | Over-provisioning GPUs wastes budget |

### Security for AI/ML
- Encrypt training data (S3 SSE-KMS) and model artifacts at rest
- Use VPC-only mode for SageMaker Studio and endpoints
- IAM roles per pipeline stage (data access ≠ model deployment)
- Bedrock: use guardrails for content safety; log all requests via CloudWatch
- Model access logging for audit (who invoked what model, when)
- Network isolation for training jobs (no internet access by default)

### Cost Optimization for AI/ML
- **Bedrock**: Use batch inference for non-real-time workloads (50% cheaper)
- **SageMaker Training**: Managed spot training (up to 90% savings, with checkpointing)
- **Inference**: Auto-scaling with scale-to-zero (serverless endpoints) for dev/test
- **GPU scheduling**: Time-share GPU nodes in EKS (NVIDIA MPS or time-slicing)
- **Inferentia/Trainium**: 40-70% cheaper than GPU for supported model architectures
- **Right-size**: Monitor GPU utilization — many workloads use <30% of GPU capacity

## Cost Management
- Use AWS Cost Explorer for spending analysis
- Set up Budgets and alerts for cost anomalies
- Use Savings Plans for steady-state compute
- Tag resources consistently for cost allocation
- Review unused resources regularly (idle EC2, unattached EBS, old snapshots)