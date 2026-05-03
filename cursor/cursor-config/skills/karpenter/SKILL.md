---
name: karpenter
description: >-
  Karpenter node provisioning reference for EKS cluster autoscaling and node lifecycle management. 
  Use when user mentions "Karpenter", "node provisioning", "cluster autoscaling", "NodePool", 
  "EC2NodeClass", "node scaling", "spot instances", or asks about EKS node management, 
  cost optimization, or automatic scaling.
metadata:
  author: SHELYOG
  version: 2.0.0
  category: kubernetes
  updated: 2026-05-03
---
# Karpenter Comprehensive Reference

Use this skill when working with Karpenter node autoscaling on EKS, including NodePool configuration, capacity planning, and cost optimization.

## Architecture

### How Karpenter Works
1. Watches for unschedulable pods (Pending due to insufficient resources)
2. Evaluates pod scheduling constraints (requests, selectors, affinities, tolerations)
3. Groups compatible pods and computes optimal node configuration
4. Launches EC2 instances directly via the AWS Fleet API (bypasses ASGs)
5. Binds pods to new nodes
6. Continuously optimizes by consolidating or replacing underutilized nodes

### Components
- **Karpenter Controller** - Runs as a Deployment in the cluster
- **Webhooks** - Validates and defaults Karpenter resources
- **NodePool** - Defines scheduling constraints and limits
- **EC2NodeClass** - AWS-specific node configuration
- **NodeClaim** - Represents a single node request (managed automatically)

## NodePool Configuration

### Resource Requirements
```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64", "arm64"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand", "spot"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["5"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
  limits:
    cpu: "1000"
    memory: 1000Gi
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
```

### Requirement Keys
| Key | Description | Example Values |
|-----|-------------|----------------|
| `kubernetes.io/arch` | CPU architecture | amd64, arm64 |
| `kubernetes.io/os` | Operating system | linux |
| `karpenter.sh/capacity-type` | On-demand or spot | on-demand, spot |
| `karpenter.k8s.aws/instance-category` | Instance family category | c, m, r, t, g |
| `karpenter.k8s.aws/instance-family` | Specific instance family | m7i, c7g, r6i |
| `karpenter.k8s.aws/instance-generation` | Instance generation | 6, 7 |
| `karpenter.k8s.aws/instance-size` | Instance size | large, xlarge, 2xlarge |
| `karpenter.k8s.aws/instance-cpu` | vCPU count | 4, 8, 16 |
| `karpenter.k8s.aws/instance-memory` | Memory in MiB | 8192, 16384 |
| `topology.kubernetes.io/zone` | Availability zone | eu-central-1a, eu-central-1b |
| `node.kubernetes.io/instance-type` | Specific instance type | m7i.xlarge |

### Operators
- `In` - Value must be in the list
- `NotIn` - Value must not be in the list
- `Exists` - Key must exist
- `DoesNotExist` - Key must not exist
- `Gt` - Greater than (numeric comparison)
- `Lt` - Less than (numeric comparison)

### Resource Limits
- Set `limits.cpu` and `limits.memory` to cap total cluster capacity
- Prevents runaway scaling and cost overruns
- Monitor actual usage against limits

### Weight
- NodePools with higher `weight` are preferred when multiple match
- Use to prefer certain instance types or capacity types

## EC2NodeClass Configuration

```yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  role: KarpenterNodeRole-cluster-name
  amiSelectorTerms:
    - alias: al2023@latest
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: cluster-name
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: cluster-name
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 100Gi
        volumeType: gp3
        encrypted: true
        kmsKeyID: "arn:aws:kms:..."
  tags:
    Environment: production
  metadataOptions:
    httpEndpoint: enabled
    httpProtocolIPv6: disabled
    httpPutResponseHopLimit: 1
    httpTokens: required
  userData: |
    # Custom user data (appended to EKS bootstrap)
```

### AMI Selection
- `alias` - Use well-known AMI aliases: `al2023@latest`, `al2@latest`, `bottlerocket@latest`
- `id` - Specific AMI ID
- `tags` - Select by AMI tags
- `name` - Select by AMI name pattern
- AMI drift is detected automatically; nodes replaced when new AMIs available

### Subnet and Security Group Selection
- Use tag-based selectors for automatic discovery
- Standard tag: `karpenter.sh/discovery: <cluster-name>`
- Multiple selector terms are OR'd; tags within a term are AND'd

### Block Device Mappings
- Configure root and additional volumes
- Use gp3 for best price-performance
- Enable encryption with KMS
- Set appropriate volume size for workload needs

### Instance Profile / Role
- `role` - IAM role name (Karpenter creates instance profile)
- `instanceProfile` - Use existing instance profile
- Role needs permissions: ECR pull, SSM, CloudWatch Logs

## Disruption and Consolidation

### Consolidation Policies
| Policy | Behavior |
|--------|----------|
| `WhenEmpty` | Only remove nodes with no running pods |
| `WhenEmptyOrUnderutilized` | Remove empty or consolidate underutilized nodes |

### Consolidation Mechanisms
1. **Node deletion** - Remove empty or underutilized nodes
2. **Node replacement** - Replace with a smaller/cheaper instance
3. **Multi-node consolidation** - Consolidate pods from multiple nodes onto fewer

### consolidateAfter
- Duration to wait before consolidating an empty/underutilized node
- Set to `0s` for aggressive consolidation
- Set to `Never` to disable time-based consolidation

### Disruption Budgets
```yaml
disruption:
  budgets:
    - nodes: "10%"           # Max percentage of nodes to disrupt
    - nodes: "3"             # Or absolute count
    - nodes: "0"             # Block disruption during schedule
      schedule: "0 9 * * 1-5"  # Weekdays 9am
      duration: 8h              # For 8 hours
```

### Disruption Reasons
- **Consolidation** - Underutilized or empty nodes
- **Drift** - Node spec doesn't match current NodePool/EC2NodeClass
- **Expiration** - Node exceeded `expireAfter` TTL
- **Emptiness** - No schedulable pods running

### Controlling Disruption
- `karpenter.sh/do-not-disrupt: "true"` annotation on pods prevents node disruption
- Pod Disruption Budgets (PDBs) are respected
- `expireAfter` forces periodic node rotation (patching)
- `terminationGracePeriod` on NodePool controls drain timeout

## Scheduling

### How Pods Get Scheduled
- Karpenter respects all standard Kubernetes scheduling constraints:
  - Resource requests (CPU, memory, GPU, ephemeral storage)
  - Node selectors
  - Node affinity/anti-affinity
  - Pod affinity/anti-affinity
  - Topology spread constraints
  - Tolerations
  - Persistent volume topology

### Pod-Level Controls
- Use `nodeSelector` to target specific NodePools
- Use `tolerations` to match NodePool taints
- Set accurate resource requests for efficient bin-packing
- Use `topologySpreadConstraints` for zone distribution

### Taints on NodePools
```yaml
template:
  spec:
    taints:
      - key: dedicated
        value: gpu
        effect: NoSchedule
```
- Only pods with matching tolerations will schedule on these nodes

## Drift Detection

Karpenter detects drift when:
- NodePool requirements change
- EC2NodeClass changes (AMI, subnets, security groups, user data)
- New AMI available (if using `@latest` alias)
- Subnet or security group tags change

Drifted nodes are gracefully replaced following disruption budgets.

## Monitoring

### Key Metrics
| Metric | Description |
|--------|-------------|
| `karpenter_nodes_total` | Total nodes managed by Karpenter |
| `karpenter_nodeclaims_created_total` | NodeClaims created |
| `karpenter_nodeclaims_disrupted_total` | NodeClaims disrupted (by reason) |
| `karpenter_nodeclaims_terminated_total` | NodeClaims terminated |
| `karpenter_pods_startup_duration_seconds` | Time from pod creation to running |
| `karpenter_nodes_allocatable` | Allocatable resources per node |
| `karpenter_nodepools_usage` | Current resource usage per NodePool |
| `karpenter_nodepools_limit` | Configured limits per NodePool |

### Alerts to Configure
- NodePool approaching resource limits
- High pod startup latency
- Frequent disruption/replacement cycles
- Capacity errors (insufficient capacity in selected instance types)

## Troubleshooting

### Pods Not Scheduling
1. Check pod events: `kubectl describe pod <pod>`
2. Verify NodePool requirements match pod constraints
3. Check NodePool limits aren't reached
4. Verify subnets have available IPs
5. Check EC2 service quotas for instance types
6. Review Karpenter controller logs

### Nodes Not Consolidating
1. Verify `consolidationPolicy` is set
2. Check for `do-not-disrupt` annotations on pods
3. Check PDBs preventing eviction
4. Verify `consolidateAfter` duration
5. Check disruption budgets

### Common Errors
- **InsufficientInstanceCapacity** - Add more instance types/families to requirements
- **UnfulfillableCapacity** - Pod constraints too restrictive; relax requirements
- **NodeClaimNotFound** - EC2 instance terminated externally; Karpenter will retry

## Migration

### From Cluster Autoscaler
1. Install Karpenter alongside Cluster Autoscaler
2. Create NodePools matching existing node group configurations
3. Cordon managed node groups
4. Workloads reschedule onto Karpenter-provisioned nodes
5. Remove managed node groups and Cluster Autoscaler

### From v1beta1 to v1 API
- `Provisioner` → `NodePool`
- `AWSNodeTemplate` → `EC2NodeClass`
- `Machine` → `NodeClaim`
- Update API versions and field names per migration guide

## Cost Optimization

- Use Spot instances for fault-tolerant workloads (60-90% savings)
- Enable consolidation for 30-60% node cost reduction
- Use Graviton (arm64) instances for 20-40% better price-performance
- Diversify instance types for better Spot availability
- Set accurate resource requests (overprovisioning wastes capacity)
- Monitor `karpenter_nodepools_usage` vs `karpenter_nodepools_limit`

## Reference Documentation

### Core
- **Karpenter Docs**: https://karpenter.sh/docs/
- **Concepts Overview**: https://karpenter.sh/docs/concepts/
- **Getting Started**: https://karpenter.sh/docs/getting-started/

### API Reference
- **NodePool**: https://karpenter.sh/docs/concepts/nodepools/
- **EC2NodeClass**: https://karpenter.sh/docs/concepts/nodeclasses/
- **NodeClaim**: https://karpenter.sh/docs/concepts/nodeclaims/
- **Disruption**: https://karpenter.sh/docs/concepts/disruption/
- **Scheduling**: https://karpenter.sh/docs/concepts/scheduling/

### Operations
- **Metrics**: https://karpenter.sh/docs/reference/metrics/
- **Settings**: https://karpenter.sh/docs/reference/settings/
- **Troubleshooting**: https://karpenter.sh/docs/troubleshooting/
- **Upgrading**: https://karpenter.sh/docs/upgrading/
- **Migration from CA**: https://karpenter.sh/docs/getting-started/migrating-from-cas/

### AWS Integration
- **EKS Karpenter Best Practices**: https://aws.github.io/aws-eks-best-practices/karpenter/
- **Cluster Autoscaling Best Practices**: https://docs.aws.amazon.com/eks/latest/best-practices/cluster-autoscaling.html
- **Karpenter AWS Provider GitHub**: https://github.com/aws/karpenter-provider-aws
- **Karpenter Blueprints**: https://github.com/aws-samples/karpenter-blueprints
