---
name: eks
description: >-
  Amazon EKS (Elastic Kubernetes Service) reference for managed Kubernetes on AWS. 
  Use when user mentions "EKS", "EKS cluster", "managed Kubernetes", "node groups", 
  "Fargate", "IRSA", "VPC CNI", "EKS add-ons", "access entries", "cluster upgrades", 
  or asks about AWS Kubernetes service, EKS networking, security, or troubleshooting.
metadata:
  author: SHELYOG
  version: 2.0.0
  category: infrastructure
  updated: 2026-05-03
---
# Amazon EKS Comprehensive Reference

Use this skill when working with EKS cluster configuration, upgrades, networking, security, or operations.

## Architecture

### Control Plane
- Managed by AWS across multiple AZs
- API server, etcd, controllers, scheduler
- Accessible via public endpoint, private endpoint, or both
- CloudWatch audit logging available

### Data Plane Options
| Option | Description | Use Case |
|--------|-------------|----------|
| Managed Node Groups | AWS-managed ASGs with lifecycle | Standard workloads |
| Self-managed Nodes | User-managed EC2 instances | Custom AMIs, special requirements |
| Karpenter | Kubernetes-native autoscaler | Dynamic, cost-optimized workloads |
| Fargate | Serverless pods | Isolated, low-maintenance pods |
| EKS Auto Mode | Fully automated node management | Minimal operations overhead |

### Supported Versions
- EKS supports N-3 Kubernetes minor versions
- Standard support: 14 months per version
- Extended support: Additional 12 months (higher cost)
- Current versions: 1.31, 1.32, 1.33, 1.34, 1.35

## Networking

### VPC CNI Plugin
- Native VPC networking; pods get VPC IP addresses
- ENI-based: each node gets ENIs with secondary IPs
- **Prefix delegation**: Assign /28 prefixes instead of individual IPs (16x density)
- **Custom networking**: Use different subnets/security groups for pods vs nodes
- **Security groups for pods**: Fine-grained network control per pod
- **Network policy support**: Built-in network policy engine (v1.14+)

### IP Address Management
- Plan CIDR ranges to avoid IP exhaustion
- Use secondary CIDRs (100.64.0.0/16) for pod networking
- Enable prefix delegation for high pod density
- Monitor available IPs per subnet

### Pod Networking Modes
| Mode | Pod IPs | Use Case |
|------|---------|----------|
| Default | VPC secondary IPs | Standard; limited by ENI capacity |
| Prefix Delegation | /28 prefix per slot | High density; 16x more pods per node |
| Custom Networking | Separate pod subnets | Overlapping CIDRs, isolated pod traffic |

### Load Balancing
- **AWS Load Balancer Controller** - Manages ALB (Ingress) and NLB (Service)
- **ALB** - Layer 7; path/host-based routing, WAF integration
- **NLB** - Layer 4; TCP/UDP, static IPs, high performance
- Use annotations on Services/Ingress to control LB configuration
- Target types: `instance` (NodePort) or `ip` (direct pod IP)

### DNS
- **CoreDNS** - Cluster DNS managed add-on
- **External DNS** - Syncs Kubernetes Services/Ingress to Route53
- NodeLocal DNSCache for improved DNS performance at scale

## Security

### Authentication

#### EKS Access Entries (Recommended)
- Cluster-level IAM principal authentication
- Access policies: AmazonEKSClusterAdminPolicy, AmazonEKSAdminPolicy, AmazonEKSEditPolicy, AmazonEKSViewPolicy
- Supports IAM users, roles, and federated identities
- Configure via `access_entries` in Terraform

#### aws-auth ConfigMap (Legacy)
- Maps IAM principals to Kubernetes RBAC
- Error-prone; single point of failure
- Migrate to access entries when possible

### Authorization
- RBAC for Kubernetes resource access control
- Use namespace-scoped Roles for application teams
- ClusterRoles for cluster-wide permissions
- Bind to IAM principals via access entries or aws-auth

### IRSA (IAM Roles for Service Accounts)
- Associates Kubernetes ServiceAccounts with AWS IAM roles
- Uses OIDC federation; no credentials on nodes
- Scoped to specific ServiceAccount and namespace
- Preferred over node-level IAM roles

```yaml
# ServiceAccount annotation for IRSA
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/my-app-role
```

### Pod Identity (EKS Pod Identity)
- Newer alternative to IRSA
- Simplified setup; no OIDC provider configuration
- Uses EKS Pod Identity Agent DaemonSet
- Supports cross-account access

### Encryption
- Envelope encryption for Kubernetes Secrets via KMS
- EBS encryption for node volumes
- In-transit encryption via TLS/mTLS

### Network Security
- Security groups on nodes and pods
- Network Policies (VPC CNI or Calico)
- Private API server endpoint
- VPC endpoints for AWS service access

## Add-ons

### Managed Add-ons
| Add-on | Purpose | Namespace |
|--------|---------|-----------|
| vpc-cni | Pod networking | kube-system |
| coredns | Cluster DNS | kube-system |
| kube-proxy | Service networking | kube-system |
| ebs-csi-driver | EBS persistent volumes | kube-system |
| efs-csi-driver | EFS persistent volumes | kube-system |
| adot | OpenTelemetry collector | opentelemetry |
| guardduty-agent | Threat detection | amazon-guardduty |
| pod-identity-agent | Pod Identity | kube-system |

### Self-managed Add-ons (Common)
| Add-on | Purpose |
|--------|---------|
| AWS Load Balancer Controller | ALB/NLB management |
| External DNS | Route53 sync |
| Karpenter | Node autoscaling |
| Calico | Network policies |
| Metrics Server | Resource metrics |
| ArgoCD | GitOps |
| Velero | Backup/restore |
| Datadog / Prometheus | Monitoring |

### Add-on Management
- Use managed add-ons for core components (auto-upgraded)
- Pin add-on versions for stability
- Upgrade add-ons alongside cluster upgrades
- Test add-on upgrades in non-production first
- Some add-ons require IRSA; configure before installing

## Cluster Upgrades

### Upgrade Strategy
1. **Review release notes** - Kubernetes and EKS changelogs, API deprecations
2. **Test in non-production** - Upgrade QA cluster first
3. **Upgrade control plane** - `aws eks update-cluster-version`
4. **Upgrade managed add-ons** - CoreDNS, kube-proxy, VPC CNI, EBS CSI
5. **Upgrade data plane** - Node groups, Karpenter EC2NodeClass AMIs
6. **Upgrade self-managed add-ons** - Helm chart versions
7. **Validate** - Run integration tests, check pod health

### Pre-upgrade Checklist
- Check API deprecations: `kubectl get --raw /metrics | grep apiserver_requested_deprecated_apis`
- Review PSP to PSS migration if applicable
- Check webhook compatibility
- Verify add-on version compatibility matrix
- Back up cluster state with Velero
- Review PodDisruptionBudgets

### Rollback
- Control plane upgrades cannot be rolled back
- Data plane: launch new nodes with old AMI
- Application rollback via ArgoCD/Helm

## Observability

### Logging
- **Control plane logging**: API server, audit, authenticator, controller manager, scheduler → CloudWatch Logs
- **Application logging**: stdout/stderr collected by Datadog/Fluentd/CloudWatch agent
- **Node logging**: System logs via CloudWatch agent

### Metrics
- **Metrics Server** - kubectl top, HPA
- **Prometheus / Datadog** - Custom metrics, dashboards, alerts
- **CloudWatch Container Insights** - AWS-native monitoring
- **Karpenter metrics** - Node lifecycle, capacity usage

### Tracing
- AWS X-Ray or OpenTelemetry via ADOT
- Datadog APM for distributed tracing

## Cost Optimization

- **Spot Instances** via Karpenter for 60-90% savings on fault-tolerant workloads
- **Graviton instances** for 20-40% better price-performance
- **Karpenter consolidation** for 30-60% node cost reduction
- **Savings Plans** for baseline on-demand capacity
- **Right-size pods** with accurate resource requests
- **Kubecost / AWS Cost Explorer** for visibility
- **Extended support** costs more; upgrade within standard support window

## Troubleshooting

### Cluster Issues
- API server unreachable → Check endpoint access, security groups, VPN
- Nodes not joining → Check node IAM role, security groups, user data, VPC CNI
- DNS not resolving → Check CoreDNS pods, ConfigMap, Service

### Node Issues
- Node NotReady → Check kubelet logs, disk pressure, memory pressure
- Instance launch failed → Check EC2 quotas, subnet IPs, AMI availability
- Node draining stuck → Check PDBs, finalizers, long-running pods

### Pod Issues
- ImagePullBackOff → Check ECR permissions (IRSA), image name/tag, VPC endpoint
- CrashLoopBackOff → Check container logs, resource limits, probes
- Pending → Check resource requests, node capacity, taints, affinity rules
- Evicted → Check node disk/memory pressure

### Networking Issues
- Service unreachable → Check endpoints, selectors, security groups
- Cross-namespace blocked → Check Network Policies
- External access failed → Check LB controller, security groups, target group health

## Reference Documentation

### Core
- **EKS User Guide**: https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html
- **EKS API Reference**: https://docs.aws.amazon.com/eks/latest/APIReference/
- **EKS Best Practices Guide**: https://docs.aws.amazon.com/eks/latest/best-practices/introduction.html
- **EKS Best Practices (PDF)**: https://docs.aws.amazon.com/eks/latest/best-practices/eks-bpg.pdf
- **EKS Best Practices (GitHub)**: https://github.com/aws/aws-eks-best-practices

### Networking
- **VPC CNI Plugin**: https://github.com/aws/amazon-vpc-cni-k8s
- **AWS Load Balancer Controller**: https://kubernetes-sigs.github.io/aws-load-balancer-controller/
- **EKS Networking Best Practices**: https://aws.github.io/aws-eks-best-practices/networking/index/

### Security
- **EKS Security Best Practices**: https://aws.github.io/aws-eks-best-practices/security/docs/
- **IRSA Documentation**: https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html
- **Pod Identity**: https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html
- **Access Entries**: https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html

### Operations
- **EKS Reliability Best Practices**: https://aws.github.io/aws-eks-best-practices/reliability/docs/
- **EKS Cost Optimization**: https://aws.github.io/aws-eks-best-practices/cost_optimization/
- **Cluster Autoscaling**: https://docs.aws.amazon.com/eks/latest/best-practices/cluster-autoscaling.html
- **EKS Upgrades**: https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html

### Ecosystem
- **EKS Blueprints (Terraform)**: https://github.com/aws-ia/terraform-aws-eks-blueprints
- **EKS Anywhere**: https://anywhere.eks.amazonaws.com/
- **Karpenter**: https://karpenter.sh/docs/
- **Data on EKS**: https://awslabs.github.io/data-on-eks/
