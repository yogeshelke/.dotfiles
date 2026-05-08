---
name: aws
description: >-
  AWS architecture decision system. Use for AWS service selection, infrastructure design,
  and platform engineering decisions. Covers compute, networking, database, IAM, cost,
  scalability, DR, and AI/ML tradeoffs. Security constraints enforced via aws-security.mdc.
  Do NOT use for non-AWS cloud providers or general cloud concepts without AWS context.
metadata:
  author: SHELYOG
  version: 3.0.0
  category: infrastructure
  updated: 2026-05-05
---
# AWS Architecture Decision Engine

Decision rules for AWS platform engineering. Not reference material.

- Security constraints → enforced via `aws-security.mdc` (always-on)
- Implementation details → `skills/terraform/`, `skills/eks/`, `skills/helm/`
- This file answers: **what to use, when, and why not**

## Interaction Model
- This skill defines **AWS service selection and architecture** decisions only
- EKS cluster operations → `eks` skill
- Terraform implementation (HCL, modules, state) → `terraform` skill
- Kubernetes workloads → `kubernetes` skill
- Container builds → `docker` skill
- Monitoring/observability → `datadog` skill

---

## Decision Entry Points

Navigate by task type:

| Building... | Read sections |
|---|---|
| API / Microservice | COMPUTE + NETWORKING + IAM |
| Database-backed service | DATABASE + NETWORKING + IAM |
| EKS platform component | COMPUTE + IAM + NETWORKING |
| Public-facing service | NETWORKING + IAM + SCALABILITY |
| Cost optimization | COST |
| Performance fix | SCALABILITY + DATABASE |
| Disaster recovery | DR |
| ML/AI workload | AI/ML + COMPUTE + COST |

---

<!-- CORE_DECISIONS: Read this section for design choices and constraints -->

## Cross-Cutting Rules

Decisions that span multiple domains (apply regardless of section):

| Decision | Domains | Rule |
|---|---|---|
| IRSA | Compute + IAM | Mandatory for all EKS workloads — never node-level IAM |
| VPC Endpoints | Networking + Database + Cost | Use for all AWS API access — not NAT Gateway |
| RDS Proxy | Database + Compute | Required when many short-lived connections (EKS, Lambda) |
| CloudFront | Networking + Scalability | Front all public content — reduces origin load + latency |
| Karpenter | Compute + Cost | Handles spot + scaling — pair with managed nodes for baseline |
| KMS encryption | IAM + Database + Storage | All data at rest — no exceptions |
| Tagging | Cost + All | Every resource tagged: env, service, team, managed-by |

---

<!-- REFERENCE: Detailed implementation patterns below. Read only when you need specific configs. -->

## [COMPUTE]

**Default**: EKS with managed node groups + Karpenter
- Prefer over ECS: unified platform, richer ecosystem, portable skills
- Avoid Fargate for steady-state (cost premium vs managed nodes)

**Lambda** — use ONLY if ALL conditions met:
- Runtime < 15 min
- Stateless
- Low cold-start sensitivity
- Minimal VPC dependencies
- Not DB-heavy (connection overhead)

Avoid Lambda for: long-running, stateful, high-throughput, latency-critical workloads

**Batch processing**: EKS Jobs or Step Functions + Fargate
- Avoid EC2-based batch unless specific AMI/hardware dependency

**GPU / ML inference**: Karpenter node pool with g5/inf2 instances
- Prefer inf2 (Inferentia) if model architecture is supported (40-70% cheaper)

---

## [NETWORKING]

**Default**: Multi-AZ VPC (minimum 3 AZs for production), private subnets for all workloads
- Avoid single-AZ for any production resource

**Public subnets**: Only for ALBs and NAT Gateways — nothing else
- Avoid placing EC2, EKS nodes, or databases in public subnets

**AWS service access**: VPC endpoint — not NAT Gateway (cheaper, lower latency, no internet path)

**Connectivity**:
- <3 VPCs → VPC peering (simple 1:1)
- >3 VPCs → Transit Gateway

**Public API endpoint**: Must restrict source CIDRs or use private + VPN
- Avoid `0.0.0.0/0` on anything except ALB port 443

---

## [DATABASE]

**Default**: Aurora PostgreSQL, Multi-AZ, KMS encrypted
- Prefer over standard RDS: better failover (<30s), read scaling, storage auto-scaling
- Avoid DynamoDB unless access pattern is strictly key-value (no joins, no transactions across items)
- Avoid self-managed DB on EC2 (patching, backups, failover — all manual)

**DynamoDB** — use ONLY if:
- Strict key-value or document access pattern
- Needs single-digit ms latency at any scale
- No complex queries, no joins

**Scaling**:
- Read-heavy → Aurora read replicas + RDS Proxy for connection pooling
- Variable/unpredictable load → Aurora Serverless v2 (scales to zero ACUs in non-prod)

**Caching** (ElastiCache Redis):
- Use when < 100ms read latency needed
- Avoid Memcached unless: no persistence needed AND no pub/sub AND no data structures

---

## [IAM]

**Workloads**: IRSA (EKS) or task roles (ECS) — never long-term keys
**CI/CD**: OIDC federation (GitHub Actions → assume role)
**Humans**: SSO/Identity Center with MFA — never IAM users with keys
**Cross-account**: Assume role with external ID, not resource sharing

**Rules**:
- No long-lived access keys — rotate or eliminate
- Least privilege always — specific actions + resource ARNs
- Encrypt everything (KMS customer-managed keys for sensitive workloads)

---

## [SCALABILITY]

- **Predictable load** → Target tracking auto-scaling
- **Spiky/unpredictable** → Step scaling + over-provision buffer
- **Read latency critical** → ElastiCache Redis in front of database
- **Many short-lived DB connections** → RDS Proxy (connection pooling)
- **Static content** → CloudFront CDN (also reduces origin load)
- **Components can be async** → SQS/EventBridge (decouple, retry built-in)

---

## [COST]

**Defaults**:
- Graviton (ARM64) for all non-GPU workloads (20-40% savings)
- Spot instances via Karpenter for fault-tolerant workloads (up to 90% savings)
- Savings Plans for steady-state compute (compute-type, not instance-specific)

**Rules**:
- Tag everything for cost allocation — no untagged resources
- Scale non-prod to zero outside business hours (scheduled scaling)
- Lifecycle policies on all S3 buckets and EBS snapshots
- Right-size based on actual utilization (CloudWatch/Datadog metrics)

---

## [DR]

- **RTO > 4 hours** → Backup & Restore (cheapest)
- **RTO 10-30 min** → Pilot Light (minimal DR resources, scale on failover)
- **RTO < 5 min** → Warm Standby (scaled-down copy always running)
- **Zero downtime** → Active-Active (highest cost, most complex)

**Default for production databases**: Aurora Global Database (async replication, <1s)

**Untested DR = no DR** — schedule quarterly failover drills

---

## [AI/ML]

- **API-based LLM access** → Bedrock (no infra, pay per token)
- **Custom model training** → SageMaker with spot training (90% savings)
- **Model inference on EKS** → Karpenter GPU pool (g5 general, inf2 cost-optimized)
- **Supported model architecture** → Inferentia/Trainium (40-70% cheaper than NVIDIA)

See `references/detailed-service-guides.md` for full MLOps pipeline patterns.

---

## Anti-Patterns (Never Do)

| Anti-Pattern | Why It's Wrong | Do This Instead |
|---|---|---|
| Single-AZ production | One AZ failure = full outage | Multi-AZ (3 AZs preferred) |
| Workloads in public subnets | Exposed attack surface | Private subnets + ALB in public |
| NAT for AWS service access | Costly, adds latency, unnecessary internet path | VPC endpoints |
| Long-lived IAM access keys | Rotation burden, leak risk | IRSA, OIDC, SSO |
| Broad IAM (`*` actions/resources) | Over-privileged, blast radius | Specific actions + ARNs |
| Self-managed DB on EC2 | Patching, backups, HA all manual | RDS/Aurora (managed) |
| Hardcoded values across envs | Painful promotion, drift | Variables + env-specific tfvars |
| Untagged resources | No cost allocation, no ownership | Tag policy enforced |
| Secrets in code/env vars | Leak via git, logs, process listing | Secrets Manager / SSM |
| Manual console changes | Drift, no audit, not reproducible | Terraform only |

---

## Troubleshooting Decision Trees

**Can't connect to resource?**
1. Security group allows the port? → If no, add inbound rule
2. Route table has path to target? → If no, add route
3. NACLs blocking? → Check both inbound AND outbound (stateless)
4. VPC endpoint needed? → If private subnet + AWS service, yes

**IAM "Access Denied"?**
1. Policy has the right action? → Check exact action name (case-sensitive)
2. Resource ARN matches? → Check account ID, region, resource name
3. Condition blocking? → Check source IP, MFA, tag conditions
4. Cross-account? → Verify trust policy + permissions on source

**EKS auth failing?**
1. Using access entries (not aws-auth ConfigMap)? → Migrate if not
2. IAM role trust policy allows `eks.amazonaws.com`? → Fix trust
3. Cluster endpoint private? → Need VPN/bastion or VPC access
4. kubectl context correct? → `aws eks update-kubeconfig`

**RDS can't connect?**
1. Security group allows DB port from source? → Add rule for 5432/3306
2. Subnet routing allows traffic? → Check route tables
3. Cross-VPC? → Need peering/TGW
4. Parameter group limits? → Check `max_connections`

**High latency / poor performance?**
- Database slow → Add read replicas or ElastiCache
- NAT bottleneck → Switch to VPC endpoints
- Cross-AZ latency → Topology-aware scheduling in EKS
- API responses slow → CloudFront + cache headers

---

## Deep Reference (load only when needed)

- `references/detailed-service-guides.md` — full service-by-service best practices
- `references/documentation-links.md` — official AWS documentation URLs

## References

- [AWS Well-Architected Framework](https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html)
- [AWS Architecture Center](https://aws.amazon.com/architecture/)
- [AWS Service Documentation](https://docs.aws.amazon.com/)
- [AWS Pricing Calculator](https://calculator.aws/)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)
- [AWS CLI Command Reference](https://docs.aws.amazon.com/cli/latest/reference/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
