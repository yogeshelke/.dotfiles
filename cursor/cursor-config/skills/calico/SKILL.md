---
name: calico
description: >-
  Calico CNI and network policy decision system. Use for Tigera operator deployment,
  Calico-native NetworkPolicy vs standard K8s NetworkPolicy, GlobalNetworkPolicy design,
  and EKS VPC CNI + Calico overlay integration. Do NOT use for general Kubernetes scheduling
  (use kubernetes skill) or EKS cluster config (use eks skill) unless CNI/policy-specific.
metadata:
  author: SHELYOG
  version: 1.0.0
  category: infrastructure
  updated: 2026-05-06
---
# Calico CNI & Network Policy Decision Engine

Decision rules for Calico/Tigera network policy management in EKS.

- EKS cluster networking mode → `skills/eks/`
- Kubernetes workload scheduling → `skills/kubernetes/`
- Helm chart patterns → `skills/helm/`
- Envoy Gateway traffic routing → `skills/envoy-gateway/`
- This file answers: **how to configure Calico and design network policies**

## Interaction Model
- This skill defines **CNI configuration and network policy patterns** only
- EKS VPC CNI settings → `eks` skill
- Pod scheduling, topology → `kubernetes` skill
- Ingress/egress traffic routing → `envoy-gateway` skill

---

## Decision Entry Points

| Task | Read sections |
|---|---|
| Deploy Calico to EKS | INSTALLATION |
| Write network policies | POLICY_PATTERNS |
| Default deny strategy | DEFAULT_DENY |
| Calico vs standard K8s NetworkPolicy | POLICY_TYPES |
| GlobalNetworkPolicy for cluster-wide rules | GLOBAL_POLICIES |
| Troubleshoot connectivity | TROUBLESHOOTING |

---

<!-- CORE_DECISIONS: Read this section for design choices and constraints -->

## Cross-Cutting Rules

| Decision | Rule |
|---|---|
| CNI mode | EKS VPC CNI for pod networking + Calico for policy enforcement only |
| Default stance | Default deny per namespace; explicit allow for each communication path |
| Policy type | Use Calico CRDs (`crd.projectcalico.org/v1`) for advanced features; standard `networking.k8s.io` for portable basics |
| Ordering | `order` field in Calico policies — lower number = higher priority |
| Logging | Enable flow logs for denied traffic in production |

---

<!-- REFERENCE: Detailed implementation patterns below. Read only when you need specific configs. -->

## INSTALLATION

### Tigera Operator via Helm (Terraform pattern)

```hcl
resource "helm_release" "calico" {
  name       = "calico"
  namespace  = "tigera-operator"
  repository = "https://docs.tigera.io/calico/charts"
  chart      = "tigera-operator"
  version    = var.calico_chart_version

  create_namespace = true

  values = [templatefile("${path.module}/configs/manifests/calico/values.yaml", {
    pod_cidr = var.pod_cidr
  })]
}
```

### EKS Integration Decisions

| Scenario | Decision |
|---|---|
| VPC CNI + Calico | Use AWS VPC CNI for pod IP assignment; Calico for policy enforcement only (most common EKS pattern) |
| Full Calico CNI | Replace VPC CNI entirely — only for non-standard networking requirements; lose VPC-native pod IPs |
| Calico eBPF mode | Performance improvement; requires kernel 5.3+; evaluate for high-throughput clusters |

### Installation Mode for EKS (policy-only)

```yaml
installation:
  cni:
    type: AmazonVPC
  calicoNetwork:
    bgp: Disabled
```

---

## POLICY_TYPES

### When to Use Which

| Policy Type | API | Use When |
|---|---|---|
| Standard K8s NetworkPolicy | `networking.k8s.io/v1` | Basic ingress/egress; portability matters |
| Calico NetworkPolicy | `crd.projectcalico.org/v1` | Need: global scope, deny rules, application-layer, service accounts, ordering |
| Calico GlobalNetworkPolicy | `crd.projectcalico.org/v1` | Cluster-wide rules (DNS, monitoring, platform services) |

### Feature Comparison

| Feature | K8s Standard | Calico Native |
|---|---|---|
| Namespace-scoped | Yes | Yes |
| Cluster-scoped | No | Yes (Global) |
| Deny rules | Implicit only | Explicit deny actions |
| Application layer (L7) | No | Yes |
| Service account selectors | No | Yes |
| Order/priority | No | Yes (`order` field) |
| Egress to FQDN | No | Yes |
| Log action | No | Yes |

---

## DEFAULT_DENY

### Namespace Default Deny Pattern

```yaml
apiVersion: crd.projectcalico.org/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: <context-namespace>
spec:
  order: 9999
  selector: all()
  types:
    - Ingress
    - Egress
```

### Then Allow Specific Traffic

```yaml
apiVersion: crd.projectcalico.org/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: <context-namespace>
spec:
  order: 100
  selector: all()
  types:
    - Egress
  egress:
    - action: Allow
      protocol: UDP
      destination:
        selector: k8s-app == 'kube-dns'
        namespaceSelector: kubernetes.io/metadata.name == 'kube-system'
        ports: [53]
    - action: Allow
      protocol: TCP
      destination:
        selector: k8s-app == 'kube-dns'
        namespaceSelector: kubernetes.io/metadata.name == 'kube-system'
        ports: [53]
```

---

## GLOBAL_POLICIES

### Platform-Wide Allow Rules

```yaml
apiVersion: crd.projectcalico.org/v1
kind: GlobalNetworkPolicy
metadata:
  name: allow-datadog-agents
spec:
  order: 50
  selector: all()
  types:
    - Egress
  egress:
    - action: Allow
      protocol: TCP
      destination:
        selector: app == 'datadog-agent'
        namespaceSelector: kubernetes.io/metadata.name == 'datadog'
        ports: [8125, 8126]
```

### Common Global Policies

| Policy | Purpose | Order |
|---|---|---|
| `allow-dns` | All pods → kube-dns | 10 |
| `allow-datadog` | All pods → Datadog agent | 50 |
| `allow-metrics-server` | Kubelet → metrics-server | 50 |
| `allow-health-checks` | ALB/NLB → pod health endpoints | 50 |
| `deny-metadata-service` | Block IMDS access (169.254.169.254) | 100 |
| `default-deny-all` | Catch-all deny | 9999 |

---

## POLICY_PATTERNS

### Context-Based Access Pattern (Terraform `kubernetes_manifest`)

```hcl
resource "kubernetes_manifest" "network_policy" {
  manifest = {
    apiVersion = "crd.projectcalico.org/v1"
    kind       = "NetworkPolicy"
    metadata = {
      name      = "allow-ingress-from-gateway"
      namespace = var.namespace
    }
    spec = {
      order    = 200
      selector = "app == '${var.app_name}'"
      types    = ["Ingress"]
      ingress = [{
        action   = "Allow"
        protocol = "TCP"
        source = {
          namespaceSelector = "kubernetes.io/metadata.name == 'envoy-gateway-system'"
        }
        destination = {
          ports = [var.container_port]
        }
      }]
    }
  }
}
```

### Common Patterns

| Communication Path | Policy |
|---|---|
| Gateway → App | Allow from `envoy-gateway-system` namespace on app port |
| App → RDS | Allow egress TCP 5432 to RDS security group CIDR |
| App → MSK | Allow egress TCP 9098 (IAM SASL) to MSK broker CIDR |
| App → S3/AWS | Allow egress HTTPS to VPC endpoints or NAT |
| App → App (same namespace) | Allow ingress/egress with matching selectors |

---

## TROUBLESHOOTING

| Problem | Diagnosis | Fix |
|---|---|---|
| Pods can't resolve DNS | Check egress to kube-dns allowed | Add DNS allow policy (order < deny) |
| Intermittent connectivity | Policy order conflict | Check `order` values; lower = higher priority |
| Health checks failing | ALB source IPs not allowed | Allow ingress from VPC CIDR on health port |
| Datadog metrics missing | Egress to agent blocked | Add global allow for Datadog ports |
| Cross-namespace blocked | Missing `namespaceSelector` | Add explicit namespace selector in source/destination |
| `calicoctl get networkpolicy` empty | Wrong namespace or API mismatch | Use `kubectl get networkpolicies.crd.projectcalico.org -n <ns>` |
