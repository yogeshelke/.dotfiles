---
name: cert-manager
description: >-
  cert-manager decision system for automated TLS certificate management in Kubernetes.
  Use for Issuer/ClusterIssuer configuration, certificate lifecycle, DNS/HTTP challenges,
  and integration with Envoy Gateway and AWS. Do NOT use for ACM certificate provisioning
  (use aws skill) or general ingress routing (use envoy-gateway skill).
metadata:
  author: SHELYOG
  version: 1.0.0
  category: infrastructure
  updated: 2026-05-06
---
# cert-manager Decision Engine

Decision rules for automated TLS certificate management in Kubernetes.

- AWS ACM certificates → `skills/aws/`
- Envoy Gateway TLS termination → `skills/envoy-gateway/`
- DNS record management → `skills/external-dns/`
- Helm chart patterns → `skills/helm/`
- This file answers: **how to configure cert-manager for automated TLS in EKS**

## Interaction Model
- This skill defines **cert-manager installation, issuer config, and certificate patterns**
- Which TLS strategy (ACM vs cert-manager) → `aws` or `eks` skill for ALB/NLB
- Gateway TLS listener configuration → `envoy-gateway` skill
- DNS records for challenges → `external-dns` skill

---

## Decision Entry Points

| Task | Read sections |
|---|---|
| Deploy cert-manager | INSTALLATION |
| Configure Let's Encrypt issuer | ISSUERS |
| TLS for Envoy Gateway | GATEWAY_INTEGRATION |
| Private CA issuer | ISSUERS (private) |
| Certificate not renewing | TROUBLESHOOTING |
| DNS challenge setup | CHALLENGES |

---

## Cross-Cutting Rules

| Decision | Rule |
|---|---|
| TLS strategy for ALB | Use ACM (not cert-manager) — ALB terminates TLS at AWS layer |
| TLS strategy for Gateway API | Use cert-manager — Gateway/Envoy terminates TLS at pod layer |
| TLS strategy for internal services | cert-manager with private CA or self-signed |
| Renewal | Automatic; cert-manager renews at 2/3 of certificate lifetime |
| Namespace isolation | Prefer `Issuer` (namespaced) for app certs; `ClusterIssuer` for platform |

---

## INSTALLATION

### Helm Chart (via Terraform)

```hcl
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.cert_manager_version

  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.cert_manager_role_arn
  }
}
```

### IAM for DNS01 Challenges (IRSA)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "route53:GetChange",
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/${hosted_zone_id}"
    },
    {
      "Effect": "Allow",
      "Action": "route53:ListHostedZonesByName",
      "Resource": "*"
    }
  ]
}
```

---

## ISSUERS

### Let's Encrypt Production (ClusterIssuer)

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: platform-team@company.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - dns01:
          route53:
            region: eu-central-1
            hostedZoneID: ${hosted_zone_id}
        selector:
          dnsZones:
            - "example.com"
```

### Private CA (for internal services)

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: internal-ca
spec:
  ca:
    secretName: internal-ca-key-pair
```

### Issuer Selection

| Use Case | Issuer Type | Challenge |
|---|---|---|
| Public-facing services | Let's Encrypt (ClusterIssuer) | DNS01 (Route53) |
| Internal services | Private CA (ClusterIssuer) | None (CA signs directly) |
| Dev/test wildcard | Let's Encrypt staging | DNS01 |
| Per-team certificates | Namespaced Issuer | Varies |

---

## CHALLENGES

### DNS01 vs HTTP01

| Challenge | Use When | Requirements |
|---|---|---|
| DNS01 | Wildcard certs needed; no public ingress available | Route53 access (IRSA) |
| HTTP01 | Simple setup; public ingress already exists | Ingress controller serving `.well-known/acme-challenge` |

### DNS01 with Route53 (preferred for EKS)

- Requires IRSA on cert-manager service account
- Works for private clusters (no inbound internet needed)
- Supports wildcard certificates
- Hosted zone ID must be explicitly configured

---

## GATEWAY_INTEGRATION

### Certificate for Gateway Listener

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: gateway-tls
  namespace: envoy-gateway-system
spec:
  secretName: gateway-tls-cert
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - "*.platform.example.com"
    - "platform.example.com"
  duration: 2160h    # 90 days
  renewBefore: 720h  # 30 days before expiry
```

### Gateway TLS Reference

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: platform-gateway
spec:
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        certificateRefs:
          - name: gateway-tls-cert
            namespace: envoy-gateway-system
```

---

## TROUBLESHOOTING

| Problem | Diagnosis | Fix |
|---|---|---|
| Certificate stuck Pending | `kubectl describe certificate` → check Issuer ready | Verify issuer exists and is Ready |
| Challenge failing (DNS01) | `kubectl describe challenge` → DNS propagation | Check IRSA permissions; verify hosted zone ID |
| Challenge failing (HTTP01) | `kubectl describe challenge` → can't reach solver | Verify ingress routes `.well-known` correctly |
| Certificate not auto-renewing | Check `renewBefore` vs `Not After` | cert-manager renews at 2/3 lifetime; check logs |
| Secret not created | Certificate never reached Ready | Fix issuer/challenge issues first |
| Wrong namespace for secret | Certificate and Gateway in different namespaces | Create Certificate in same namespace as Gateway |
