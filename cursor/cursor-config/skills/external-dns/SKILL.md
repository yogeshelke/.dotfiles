---
name: external-dns
description: >-
  ExternalDNS decision system for automated DNS record management in Kubernetes. Use for
  Route53 integration, record ownership, filtering strategies, and Gateway API annotation
  patterns. Do NOT use for Route53 Terraform management (use aws/terraform skill) or
  cert-manager DNS challenges (use cert-manager skill).
metadata:
  author: SHELYOG
  version: 1.0.0
  category: infrastructure
  updated: 2026-05-06
---
# ExternalDNS Decision Engine

Decision rules for automated DNS record management from Kubernetes resources.

- Route53 hosted zone Terraform → `skills/aws/` + `skills/terraform/`
- TLS certificates → `skills/cert-manager/`
- Envoy Gateway routing → `skills/envoy-gateway/`
- Helm chart patterns → `skills/helm/`
- This file answers: **how to configure ExternalDNS for automated Route53 management**

## Interaction Model
- This skill defines **ExternalDNS deployment, filtering, and ownership patterns**
- Route53 zone creation → `terraform` + `aws` skills
- DNS challenge for certs → `cert-manager` skill
- Ingress/Gateway annotations → `envoy-gateway` skill

---

## Decision Entry Points

| Task | Read sections |
|---|---|
| Deploy ExternalDNS | INSTALLATION |
| Configure Route53 integration | ROUTE53 + IAM |
| Filter which records are managed | FILTERING |
| Prevent record conflicts | OWNERSHIP |
| Gateway API DNS automation | GATEWAY_INTEGRATION |
| Troubleshoot missing records | TROUBLESHOOTING |

---

## Cross-Cutting Rules

| Decision | Rule |
|---|---|
| Source of truth | ExternalDNS owns records it creates (via TXT ownership records); never manually edit |
| txt-owner-id | Unique per cluster — prevents multi-cluster conflicts |
| Policy | `sync` (create + delete) for prod; `upsert-only` for initial rollout |
| Domain filtering | Always restrict to specific domains; never manage entire zone without filter |
| Multiple clusters | Each cluster gets unique `txt-owner-id`; shared zones are safe with ownership |

---

## INSTALLATION

### Helm Chart (via Terraform)

```hcl
resource "helm_release" "external_dns" {
  name       = "external-dns"
  namespace  = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = var.external_dns_version

  create_namespace = true

  values = [templatefile("${path.module}/configs/manifests/external-dns/values.yaml", {
    cluster_name   = var.cluster_name
    domain_filter  = var.domain_filter
    hosted_zone_id = var.hosted_zone_id
    role_arn       = var.external_dns_role_arn
    txt_owner_id   = "ae-${var.environment}-${var.cluster_name}"
  })]
}
```

### Values Pattern

```yaml
provider: aws
policy: sync
registry: txt
txtOwnerId: "${txt_owner_id}"
txtPrefix: "_externaldns."

sources:
  - service
  - ingress
  - gateway-httproute
  - gateway-grpcroute

domainFilters:
  - "${domain_filter}"

extraArgs:
  - --aws-zone-type=private  # or public, or omit for both
  - --annotation-filter=external-dns.alpha.kubernetes.io/enabled=true

serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: "${role_arn}"

resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    memory: 128Mi
```

---

## IAM

### IRSA Policy for Route53

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/${hosted_zone_id}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ListHostedZones",
        "route53:ListResourceRecordSets",
        "route53:ListTagsForResource"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## FILTERING

### Annotation-Based Filtering (recommended)

Only manage resources with explicit opt-in annotation:
```yaml
extraArgs:
  - --annotation-filter=external-dns.alpha.kubernetes.io/enabled=true
```

Service/Ingress must include:
```yaml
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/enabled: "true"
    external-dns.alpha.kubernetes.io/hostname: "app.platform.example.com"
```

### Domain Filtering

Restrict to specific domains:
```yaml
domainFilters:
  - "platform.example.com"
  - "internal.example.com"
```

### Zone Type Filtering

| Zone Type | Flag | Use Case |
|---|---|---|
| Public only | `--aws-zone-type=public` | Internet-facing services |
| Private only | `--aws-zone-type=private` | Internal services (EKS-only DNS) |
| Both | Omit flag | Mixed workloads (careful with overlapping names) |

---

## OWNERSHIP

### TXT Record Ownership

ExternalDNS creates TXT records alongside A/CNAME records to track ownership:
```
app.example.com.          A       1.2.3.4
_externaldns.app.example.com.  TXT  "heritage=external-dns,external-dns/owner=ae-prod-cluster1,..."
```

### Multi-Cluster Safety

| Scenario | Configuration |
|---|---|
| Single cluster per zone | Any `txt-owner-id`; `policy: sync` |
| Multiple clusters, shared zone | Unique `txt-owner-id` per cluster; each only manages its own records |
| Migration between clusters | Change `txt-owner-id` carefully or use `upsert-only` during transition |

---

## GATEWAY_INTEGRATION

### Gateway API Source

Enable Gateway API sources:
```yaml
sources:
  - gateway-httproute
  - gateway-grpcroute
```

ExternalDNS reads hostnames from HTTPRoute:
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-route
  annotations:
    external-dns.alpha.kubernetes.io/enabled: "true"
spec:
  hostnames:
    - "app.platform.example.com"  # ExternalDNS creates this record
  parentRefs:
    - name: platform-gateway
      namespace: envoy-gateway-system
```

---

## ROUTE53

### Record Types Created

| K8s Resource | DNS Record Type | Target |
|---|---|---|
| Service (type: LoadBalancer) | A (alias) or CNAME | NLB/ALB endpoint |
| Ingress | A (alias) or CNAME | Ingress LB |
| HTTPRoute (Gateway API) | A (alias) or CNAME | Gateway LB |

### TTL Configuration

```yaml
metadata:
  annotations:
    external-dns.alpha.kubernetes.io/ttl: "300"  # 5 minutes (default: 300)
```

| Environment | Recommended TTL |
|---|---|
| Production | 300s (5min) |
| Pre-prod | 60s (faster DNS propagation for testing) |
| During migration | 60s (then increase after stable) |

---

## TROUBLESHOOTING

| Problem | Diagnosis | Fix |
|---|---|---|
| Records not created | Check ExternalDNS logs | Verify annotation filter matches; check domain filter |
| Permission denied | IAM policy missing | Verify IRSA annotation + hosted zone ARN in policy |
| Wrong record target | Source type mismatch | Check `sources` list includes the resource type |
| Orphaned records after delete | `policy: upsert-only` doesn't clean up | Switch to `policy: sync` or manually delete |
| Conflict with another controller | Duplicate TXT owner records | Ensure unique `txt-owner-id` per cluster/controller |
| Records in wrong zone | Zone type filter | Add `--aws-zone-type` flag to restrict |
