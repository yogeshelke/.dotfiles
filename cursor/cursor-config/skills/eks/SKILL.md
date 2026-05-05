---
name: eks
description: >-
  EKS decision system for managed Kubernetes on AWS. Use for cluster configuration,
  networking mode, security model, add-on management, upgrades, and cost optimization.
  Do NOT use for general Kubernetes workload patterns (use kubernetes skill) or
  node autoscaling specifics (use karpenter skill).
metadata:
  author: SHELYOG
  version: 3.0.0
  category: infrastructure
  updated: 2026-05-05
---
# EKS Decision Engine

Decision rules for EKS cluster management. Not reference material.

- General K8s workloads → `skills/kubernetes/`
- Node autoscaling → `skills/karpenter/`
- AWS service selection → `skills/aws/`
- This file answers: **how to configure and operate EKS clusters**

## Interaction Model
- This skill defines **cluster-level** decisions only
- Workload patterns (pods, deployments, scheduling) → `kubernetes` skill
- Node scaling (NodePool, consolidation, spot) → `karpenter` skill
- Infrastructure provisioning (HCL, modules, state) → `terraform` skill

---

## Decision Entry Points

| Task | Read sections |
|---|---|
| New EKS cluster | CLUSTER_CONFIG + NETWORKING + SECURITY |
| Add-on selection | ADD_ONS |
| Cluster upgrade | UPGRADES |
| Cost reduction | COST |
| Auth/access issues | SECURITY |
| Network architecture | NETWORKING |
| Pod placement / HA | SCHEDULING_AND_AZ |
| IP exhaustion / CNI limits | NETWORKING (VPC CNI limits) |

---

## Cross-Cutting Rules

| Decision | Domains | Rule |
|---|---|---|
| IRSA | Security + Workloads | Mandatory for all pods — never node-level IAM |
| Private endpoint | Cluster + Security | Default; public only with CIDR restriction |
| Managed add-ons | Add-ons + Upgrades | Use for core components — auto-patched |
| Envelope encryption | Security + Storage | KMS encryption for all Secrets |
| Prefix delegation | Networking + Scaling | Enable for high pod density (16x more IPs) |

---

## [CLUSTER_CONFIG]

**API endpoint**:
- **Default**: Private endpoint only
- **If public needed** → Restrict to specific CIDRs (VPN, office IPs)
- **Avoid**: Public endpoint without CIDR restriction

**Data plane strategy**:
- **Default**: Managed node groups (baseline) + Karpenter (scaling)
- **If minimal operations wanted** → EKS Auto Mode
- **If pod-level isolation needed** → Fargate (but limited features)
- **Avoid**: Self-managed nodes unless custom AMI is mandatory

**Version policy**:
- Stay within standard support window (N-3 versions, 14 months each)
- Upgrade before extended support kicks in (higher cost)
- Never skip versions — upgrade one minor at a time

**Logging**:
- Enable: API server, audit, authenticator
- Optional: controller manager, scheduler (verbose, cost consideration)
- Ship to CloudWatch Logs → Datadog for analysis

---

## [NETWORKING]

**VPC CNI mode**:
- **Default**: Standard (secondary IPs) — sufficient for most clusters
- **If >100 pods per node** → Prefix delegation (/28 per ENI slot, 16x density)
- **If overlapping CIDRs or pod isolation** → Custom networking (separate pod subnets)
- **If IP exhaustion risk** → Secondary CIDRs (100.64.0.0/16) for pods

**VPC CNI limits** (production bottleneck):
- Each pod consumes one VPC IP address
- ENI slots + max IPs are instance-type-dependent (e.g., m5.large = 29 pods max without prefix delegation)
- Monitor: `aws ec2 describe-network-interfaces` for ENI utilization
- **If hitting limits** → Enable prefix delegation OR use secondary CIDR
- **If secondary CIDR** → Use 100.64.0.0/10 range (not routable outside VPC)

**AZ-aware load balancing**:
- ALB: Enable cross-zone load balancing awareness
- NLB: Consider zone-affinity (`service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "false"`) to reduce cross-AZ costs
- Cross-AZ data transfer: ~$0.01/GB — significant at scale

**Load balancing**:
- **Default**: AWS Load Balancer Controller (manages ALB/NLB)
- **HTTP/HTTPS traffic** → ALB (L7, path/host routing, WAF integration)
- **TCP/UDP or high performance** → NLB (L4, static IPs)
- **Target type**: `ip` (direct to pod) preferred over `instance` (NodePort)

**DNS**:
- CoreDNS as managed add-on
- External DNS for automatic Route53 record management
- NodeLocal DNSCache for scale (>500 pods)

**Network Policies**:
- **Default**: Enable VPC CNI network policy engine (v1.14+)
- **If advanced L7 policies needed** → Calico or Cilium
- Start with default-deny, whitelist required traffic

---

## [SCHEDULING_AND_AZ]

Kubernetes is NOT AZ-aware by default. Without explicit constraints, all replicas can land in the same AZ.

**Topology spread** (mandatory for production workloads):
```yaml
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app: my-service
```

**Rules**:
- **Default**: Use `topologySpreadConstraints` for all stateless services (≥2 replicas)
- **If single replica** → Acceptable to skip, but consider availability impact
- **If latency-sensitive** → Prefer zone-local traffic (service topology, zone-affinity)
- **Avoid**: Relying solely on pod anti-affinity (doesn't guarantee even spread)

**Pod density tradeoffs**:
- Higher density (more pods/node) → fewer nodes → lower cost
- But: larger blast radius per node failure + noisy neighbor risk
- **Guideline**: Critical services should spread across ≥3 nodes in ≥2 AZs
- Balance density against failure impact per workload tier

---

## [SECURITY]

**Authentication**:
- **Default**: EKS access entries (cluster-level IAM mapping)
- **Avoid**: aws-auth ConfigMap (legacy, error-prone, single point of failure)
- Migrate existing aws-auth to access entries when possible

**Pod identity**:
- **Default**: IRSA (IAM Roles for Service Accounts) — mature, well-supported
- **Alternative**: EKS Pod Identity (simpler setup, cross-account support)
- **Never**: Broad node-level IAM roles

**Authorization**:
- Namespace-scoped Roles for application teams
- ClusterRoles only for cluster-wide resources
- Access policies: use AmazonEKSViewPolicy for read-only, AmazonEKSEditPolicy for developers

**Encryption**:
- Envelope encryption for Secrets via KMS (enable at cluster creation)
- EBS encryption on all node volumes (via EC2NodeClass)
- TLS/mTLS for service-to-service (via service mesh or Envoy Gateway)

---

## [ADD_ONS]

**Use managed add-ons for**:
- vpc-cni, coredns, kube-proxy, ebs-csi-driver, pod-identity-agent
- Benefit: auto-upgraded, AWS-supported, security patches

**Use self-managed (Helm) for**:
- AWS Load Balancer Controller, External DNS, Karpenter, Datadog, ArgoCD
- Benefit: more control over versions and config

**Install order** (dependencies matter — out-of-order causes broken installs):
1. IRSA roles (prerequisite for everything below)
2. VPC CNI + CoreDNS + kube-proxy (networking foundation)
3. EBS CSI driver (storage)
4. AWS Load Balancer Controller (ingress)
5. External DNS (DNS automation)
6. Karpenter (node scaling — needs LB controller for webhooks)
7. Application-level (Datadog, ArgoCD, app workloads)

**Version decisions**:
- Pin add-on versions for stability
- Upgrade add-ons alongside cluster upgrades (same maintenance window)
- Test in non-prod before promoting

**IRSA requirement**: LB Controller, External DNS, Karpenter, EBS CSI — all need IRSA roles configured before installation

---

## [UPGRADES]

**Control plane vs data plane** (critical distinction):
- Control plane is AWS-managed — **cannot be rolled back** (forward only)
- Data plane (nodes) must be version-aligned with control plane (kubelet ≤ control plane version)
- Always test node AMI compatibility before upgrading data plane
- Control plane upgrade is non-disruptive; data plane upgrade causes pod evictions

**Strategy** (sequential, never skip):
1. Review release notes + API deprecations
2. Test full upgrade path in non-production cluster
3. Upgrade control plane (irreversible — ensure readiness)
4. Upgrade managed add-ons (CoreDNS, kube-proxy, VPC CNI, EBS CSI)
5. Upgrade data plane (node groups, Karpenter AMIs — stagger AZs)
6. Upgrade self-managed add-ons (Helm charts)
7. Validate (integration tests, pod health, monitoring)

**Pre-upgrade checklist**:
- Check deprecated APIs: `kubectl get --raw /metrics | grep apiserver_requested_deprecated_apis`
- Verify add-on version compatibility matrix
- Review PodDisruptionBudgets (ensure pods can be evicted safely)
- Back up with Velero
- Check webhook compatibility (webhooks may reject new API versions)
- Verify node AMI supports target K8s version

**Rollback**:
- Control plane: **cannot roll back** — this is why step 2 (test in non-prod) is mandatory
- Data plane: launch nodes with previous AMI
- Applications: ArgoCD/Helm rollback

---

## [COST]

- **Spot instances** via Karpenter: 60-90% savings on fault-tolerant workloads
- **Graviton (arm64)**: 20-40% better price-performance
- **Consolidation**: Karpenter removes underutilized nodes (30-60% reduction)
- **Savings Plans**: For baseline on-demand capacity
- **Right-size pods**: Accurate resource requests prevent over-provisioning
- **Upgrade within standard support**: Extended support costs more

---

## Anti-Patterns (Never Do)

| Anti-Pattern | Why It's Wrong | Do This Instead |
|---|---|---|
| aws-auth ConfigMap for auth | Error-prone, no audit trail, single point of failure | EKS access entries |
| Node-level IAM roles | Over-privileged, all pods get same permissions | IRSA per workload |
| Public endpoint without CIDR restriction | Exposed API server to internet | Private endpoint or restricted CIDRs |
| Skipping Kubernetes versions | Unsupported, may break APIs | Upgrade one minor at a time |
| No PDBs on production workloads | Upgrades/disruptions cause downtime | PDB with minAvailable |
| Unpinned add-on versions | Unexpected behavior after auto-update | Pin and test before upgrading |
| No envelope encryption | Secrets stored in plaintext in etcd | Enable KMS encryption |
| Fargate for everything | Limited features, no DaemonSets, higher cost | Managed nodes + Karpenter |
| No topologySpreadConstraints | All replicas can land in one AZ — single AZ failure = full outage | Spread across zones |
| Ignoring ENI/IP limits | Pods stuck Pending when node hits IP ceiling | Prefix delegation or secondary CIDR |
| Upgrading data plane before control plane | Version skew breaks kubelet-apiserver compat | Always control plane first |

---

## Troubleshooting Decision Trees

**API server unreachable?**
1. Private endpoint? → Need VPN/bastion/VPC access
2. Security groups allow traffic from source? → Add rule
3. kubeconfig correct? → `aws eks update-kubeconfig --name <cluster>`
4. IAM permissions to call EKS API? → Check caller identity

**Nodes not joining?**
1. Node IAM role has required policies? → EKS worker node policy, CNI policy, ECR read
2. Security groups allow node-to-control-plane? → Check cluster SG
3. Subnet tags correct? → `kubernetes.io/cluster/<name>: owned/shared`
4. VPC CNI running? → Check CNI pods in kube-system

**Pods stuck ImagePullBackOff?**
1. ECR permissions via IRSA? → Check ServiceAccount annotation
2. VPC endpoint for ECR? → Needed if no NAT/internet
3. Image exists with that tag? → Verify in ECR console/CLI
4. Cross-region? → Need ECR replication or correct region

**Auth/RBAC denied?**
1. Access entry exists for IAM principal? → Add via Terraform
2. Correct access policy attached? → Check scope (cluster vs namespace)
3. Pod using correct ServiceAccount? → Check pod spec
4. IRSA role trust policy correct? → Verify OIDC provider + conditions

---

## Reference Documentation

- **EKS User Guide**: https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html
- **EKS Best Practices**: https://docs.aws.amazon.com/eks/latest/best-practices/introduction.html
- **EKS Best Practices (GitHub)**: https://github.com/aws/aws-eks-best-practices
- **VPC CNI Plugin**: https://github.com/aws/amazon-vpc-cni-k8s
- **AWS Load Balancer Controller**: https://kubernetes-sigs.github.io/aws-load-balancer-controller/
- **IRSA**: https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html
- **Pod Identity**: https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html
- **Access Entries**: https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html
- **EKS Blueprints (Terraform)**: https://github.com/aws-ia/terraform-aws-eks-blueprints
- **Karpenter**: https://karpenter.sh/docs/
