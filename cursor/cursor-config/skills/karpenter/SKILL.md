---
name: karpenter
description: >-
  Karpenter decision system for EKS node provisioning and autoscaling. Use for NodePool design,
  instance selection, disruption strategy, scheduling interaction, and cost optimization.
  Do NOT use for general EKS config (use eks skill) or K8s scheduling concepts (use kubernetes skill).
metadata:
  author: SHELYOG
  version: 4.0.0
  category: kubernetes
  updated: 2026-05-05
---
# Karpenter Decision Engine

Decision rules for node provisioning and autoscaling. Not reference material.

- EKS cluster config → `skills/eks/`
- K8s scheduling → `skills/kubernetes/`
- This file answers: **how to configure NodePools, select instances, and manage node lifecycle**

## Interaction Model
- This skill defines **node-level** decisions (NodePool, EC2NodeClass, instance selection, disruption)
- Pod scheduling (affinity, topology spread) → `kubernetes` skill
- EKS cluster setup (VPC CNI, add-ons) → `eks` skill
- Spot vs on-demand architecture choice → `aws` skill (cost section)
- Terraform provisioning of Karpenter → `terraform` skill

---

## Execution Model

Karpenter is **constraint-driven**, not configuration-driven:
- NodePool defines **possibilities** (allowed instances, limits, policies)
- Pod defines **requirements** (requests, selectors, affinity, topology)
- Karpenter selects a **feasible, available, cost-efficient** instance (not guaranteed globally cheapest — uses price-capacity-optimized for Spot)
- NodePool + Pod constraints combine → overly strict combinations cause scheduling failure

**How it works**:
- Primarily reacts to individual pending pods; grouping is opportunistic, not guaranteed
- Node size determined by requests of unschedulable pods (aggregation may occur but is not guaranteed)
- Initial provisioning may be suboptimal — consolidation optimizes eventually (not immediate)
- Karpenter requests EC2 capacity via Fleet APIs; **kube-scheduler** places pods on provisioned nodes
- Limits apply **per NodePool** (no global cluster limit exists)

**System boundaries** (which layer is responsible):
- **Karpenter** → evaluates scheduling requirements, requests EC2 capacity, manages node lifecycle
- **kube-scheduler** → places pods on available nodes
- **EC2 Fleet API** → fulfills capacity requests (instance types, AZs, Spot pools)

---

## Decision Entry Points

| Task | Read sections |
|---|---|
| Design NodePool strategy | NODEPOOL_DESIGN |
| Choose instance types | INSTANCE_SELECTION |
| Configure consolidation | DISRUPTION |
| Fix scheduling issues | SCHEDULING |
| Reduce node costs | COST |

---

## Operational Guardrails

- Always define resource requests for all workloads (use LimitRanges for defaults)
- Always define NodePool cpu/memory limits
- Always monitor subnet IP capacity and EC2 service quotas
- Always validate NodePool constraints in non-prod before rollout
- Set billing alarms for autoscaling clusters (detect unexpected cost spikes)
- For memory: set requests ≈ limits to avoid OOM during consolidation

---

## Failure Modes (Quick Map)

| Failure | Cause | Fix |
|---|---|---|
| UnfulfillableCapacity | Constraints too restrictive | Broaden instance families/generations |
| Wrong instance size | Pod requests inaccurate | Right-size requests to actual usage |
| Subnet/IP exhaustion | Scaling beyond VPC capacity | Prefix delegation or secondary CIDRs |
| Cost runaway | No limits on NodePool | Set cpu/memory caps + billing alarms |
| Unpredictable placement | Overlapping NodePools | Make NodePools mutually exclusive |
| Controller unavailable | Running on Karpenter-managed node | Use Fargate or static node group |
| OOM during consolidation | requests << actual usage | Memory requests ≈ limits |

---

## Cross-Cutting Rules

| Decision | Domains | Rule |
|---|---|---|
| Diversify instance types | Instance + Cost | Always allow multiple families — never single type |
| Resource limits on NodePools | NodePool + Cost | Set CPU/memory caps to prevent runaway |
| Disruption budgets | Disruption + Availability | Production NodePools need explicit budgets |
| Accurate pod requests | Scheduling + Cost | Right-sized requests = efficient bin-packing |
| Encrypted volumes | Instance + Security | Always `encrypted: true` in blockDeviceMappings |
| LimitRanges | Scheduling + Safety | Enforce default requests for all workloads |

---

## [NODEPOOL_DESIGN]

**Baseline architecture** (Karpenter + managed node groups):
- **Managed node groups** for: Karpenter controller, system components, predictable baseline
- **Karpenter** for: dynamic workloads, burst capacity, cost optimization
- Karpenter is not always cheapest or simplest — baseline stability matters

**When to create separate NodePools**:
- GPU workloads → dedicated (g5, p4d, inf2)
- Spot-only batch → separate with `spot` capacity type
- System/platform → baseline with `on-demand` + taint
- General workloads → default with mixed spot/on-demand

**Limits** (per NodePool — no global cluster limit):
- Always set `limits.cpu` and `limits.memory`
- Size to ~150% of expected peak (burst room without unlimited growth)
- Total cluster capacity = sum of all NodePool limits + managed node groups
- Monitor: `karpenter_nodepools_usage` vs `karpenter_nodepools_limit`

**Weight**: Tie-breaker only when multiple NodePools match. Not a cost strategy — use constraints for that.

**Overlap**: If multiple NodePools match same pod → unpredictable. Make mutually exclusive (different taints, selectors, or instance families).

**Example NodePool**:
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

---

## [INSTANCE_SELECTION]

**Architecture**:
- **Default**: Both `amd64` + `arm64` (Graviton 20-40% cheaper)
- **If app needs x86** → `amd64` only
- **If cost-optimized + ARM-compatible** → Prefer `arm64`

**Instance families**:
- General: `m` (balanced), `c` (compute), `r` (memory)
- GPU: `g5` (A10G), `p4d` (A100), `inf2` (Inferentia)
- Burstable: `t` — dev/test only, never production
- Always: Generation ≥6

**Spot vs On-demand**:
- **Default**: Mixed (both allowed — Karpenter handles fallback)
- Fault-tolerant → Spot preferred (60-90% savings)
- Latency-critical / singleton → On-demand only
- Diversify 10+ instance types across multiple AZs for Spot reliability
- Over-constraining instance types (especially Spot) → no capacity available → scheduling failure
- Explicitly exclude bad-fit instances via `NotIn` requirements (e.g., exclude `t` family, small sizes)

**AMI pinning**:
- Production: Pin version — never `@latest`
- Non-prod: `@latest` for testing before promotion
- Use `expireAfter` for periodic rotation within known-good versions

**EC2NodeClass**:
```yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  role: KarpenterNodeRole-cluster-name
  amiSelectorTerms:
    - alias: al2023@v20260401
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
  metadataOptions:
    httpTokens: required
```

---

## [DISRUPTION]

**Consolidation**:
- **Default**: `WhenEmptyOrUnderutilized` (actively optimizes cost)
- **Conservative**: `WhenEmpty` (removes only empty nodes)
- `consolidateAfter`: `1m` aggressive, `30m` conservative

**Disruption budgets** (production):
```yaml
disruption:
  budgets:
    - nodes: "10%"
    - nodes: "0"
      schedule: "0 9 * * 1-5"
      duration: 8h
```
- Limit disruption during business hours
- Percentage for large clusters, absolute for small

**Node expiration**: `expireAfter: 720h` (30 days) — forces AMI rotation, respects budgets/PDBs

**Spot interruption**: Karpenter handles natively (cordon → drain → terminate). Requires SQS interruption queue for full handling (receives ITN + rebalance signals). Ensure `terminationGracePeriodSeconds` allows clean shutdown. PDBs must allow eviction.

**Drift detection**: AMI/NodePool/EC2NodeClass changes → nodes replaced (follows budgets, not instant)

---

## [SCHEDULING]

**Pod → Karpenter interaction**:
- Watches for Pending pods (reacts to individual unschedulable pods)
- Evaluates: requests, nodeSelector, affinity, tolerations, topology spread
- Launches node that satisfies constraints and is cost-efficient
- Karpenter provisions the node; kube-scheduler then places the pod

**Targeting a NodePool**: Use `nodeSelector` matching NodePool labels, or tolerations matching taints

**Requests vs limits** (critical):
- Karpenter sizes nodes on **requests only** — limits ignored for provisioning
- If limits >> requests → OOM during consolidation (smaller node fits requests but not usage)
- **Memory**: Set requests ≈ limits (avoids OOM when consolidated to tighter node)
- **CPU**: Requests can be lower than limits (CPU is compressible)

**LimitRanges** (prevent mis-sizing):
- Pods without requests → Karpenter cannot size correctly
- **Rule**: Use Kubernetes LimitRanges to enforce default requests for all namespaces

**Controller placement**:
- Must NOT run on Karpenter-managed nodes (circular dependency)
- Run on: Fargate, static managed node group, or EKS Auto Mode system nodes

**Subnet/IP exhaustion**:
- Nodes scale → VPC IPs consumed → scheduling stalls (even with compute available)
- **Rule**: Ensure subnet capacity for peak; use prefix delegation or secondary CIDRs
- Monitor: `aws ec2 describe-subnets` (available IPs)

---

## [COST]

- **Spot**: 60-90% savings (diversify types for availability)
- **Graviton**: 20-40% better price-performance
- **Consolidation**: 30-60% reduction (removes underutilized nodes)
- **Right-size pods**: Over-requesting wastes capacity, under-requesting causes OOM
- **Instance selection**: Karpenter selects cost-efficient instance that satisfies constraints — not necessarily absolute cheapest
- **Billing alarms**: Set anomaly detection for autoscaling clusters
- **Monitor**: `karpenter_nodepools_usage` / `karpenter_nodepools_limit` ratio

---

## Anti-Patterns

| Anti-Pattern | Do This Instead |
|---|---|
| Single instance type | Allow 10+ types/families |
| No NodePool limits | Set cpu/memory caps |
| Over-restrictive requirements | Broaden instance category/generation |
| No disruption budgets (prod) | Budget with schedule windows |
| `do-not-disrupt` on everything | Only on truly critical pods |
| No `expireAfter` | 30d expiration for AMI rotation |
| Burstable (t-family) for prod | Use c/m/r families |
| `@latest` AMI in production | Pin version, test in non-prod |
| Overlapping NodePools | Mutually exclusive or clearly weighted |
| Controller on Karpenter nodes | Fargate or static node group |
| Requests << actual usage | Requests ≈ usage (especially memory) |
| No LimitRanges | Enforce defaults for all namespaces |
| No billing alarms | Anomaly detection on autoscaling clusters |

---

## Troubleshooting Decision Trees

**Pods not scheduling?**
1. NodePool limits reached? → Increase or add NodePool
2. Requirements too restrictive? → Broaden families/sizes
3. Subnet out of IPs? → Check available IPs, prefix delegation
4. EC2 quota reached? → Request service quota increase
5. Karpenter controller running? → Check karpenter namespace

**Nodes not consolidating?**
1. `consolidationPolicy` set? → Must be `WhenEmptyOrUnderutilized`
2. `do-not-disrupt` on pods? → Remove if unnecessary
3. PDBs blocking? → Check PDB config
4. `consolidateAfter` too long? → Reduce
5. Budget at max? → Wait or adjust

**Capacity errors?**
- `InsufficientInstanceCapacity` → Add more types + AZs
- `UnfulfillableCapacity` → Relax pod constraints (affinity/selector)
- `NodeClaimNotFound` → Instance terminated externally, will retry

---

## Reference Documentation

- **Karpenter Docs**: https://karpenter.sh/docs/
- **NodePool Concepts**: https://karpenter.sh/docs/concepts/nodepools/
- **EC2NodeClass**: https://karpenter.sh/docs/concepts/nodeclasses/
- **Disruption**: https://karpenter.sh/docs/concepts/disruption/
- **Scheduling**: https://karpenter.sh/docs/concepts/scheduling/
- **Metrics**: https://karpenter.sh/docs/reference/metrics/
- **EKS Best Practices**: https://aws.github.io/aws-eks-best-practices/karpenter/
- **Karpenter Blueprints**: https://github.com/aws-samples/karpenter-blueprints
