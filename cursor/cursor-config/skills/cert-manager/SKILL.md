---
name: cert-manager
description: >-
  cert-manager decision system for automated TLS certificate management in Kubernetes.
  Use for Issuer/ClusterIssuer configuration, certificate lifecycle, DNS/HTTP challenges,
  and integration with Envoy Gateway and AWS. Do NOT use for ACM certificate provisioning
  (use aws skill) or general ingress routing (use envoy-gateway skill).
metadata:
  author: SHELYOG
  version: 2.0.0
  category: infrastructure
  updated: 2026-05-06
---
# cert-manager Decision Engine

Decision rules for automated TLS certificate management in Kubernetes.

- AWS ACM certificates → `skills/aws/`
- Envoy Gateway TLS termination → `skills/envoy-gateway/`
- DNS record management → `skills/external-dns/`
- Helm chart patterns → `skills/helm/`
- Network policy for cert-manager namespace → `skills/calico/`
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
| Choose TLS strategy | TLS_STRATEGY |
| Deploy cert-manager | INSTALLATION + SECURITY |
| Configure issuer | ISSUERS |
| TLS for Envoy Gateway | GATEWAY_INTEGRATION |
| Certificate not renewing | FAILURE_MODES + LIFECYCLE |
| DNS challenge setup | CHALLENGES |
| Upgrade cert-manager | LIFECYCLE |

---

<!-- CORE_DECISIONS: Read this section for design choices and constraints -->

## Cross-Cutting Rules

| Decision | Rule |
|---|---|
| TLS for ALB/NLB | Use ACM (not cert-manager) — AWS LB terminates TLS at infrastructure layer |
| TLS for Gateway API / Envoy | Use cert-manager — Gateway terminates TLS at pod layer |
| TLS for internal services | cert-manager with private CA or self-signed |
| Renewal | Automatic at 2/3 of certificate lifetime; no manual intervention needed |
| Namespace isolation | `ClusterIssuer` for platform-wide; namespaced `Issuer` for team-scoped |
| Secret ownership | cert-manager owns the TLS secret; NEVER manually edit or recreate it |

---

<!-- REFERENCE: Detailed implementation patterns below. Read only when you need specific configs. -->

## TLS_STRATEGY

```
IF traffic terminates at AWS ALB/NLB:
  → Use ACM certificate (free, auto-renewing, AWS-managed)
  → cert-manager NOT needed for this path
  → Managed via Terraform aws_acm_certificate resource

IF traffic terminates at Envoy Gateway / in-cluster proxy:
  → Use cert-manager (Gateway needs TLS secret in-cluster)
  → ClusterIssuer + Certificate resource → Secret → Gateway listener reference

IF service-to-service mTLS (internal):
  → Use cert-manager with private CA issuer
  → Short-lived certs (24h-7d) for rotation without disruption
  → No external CA dependency

IF wildcard certificate needed:
  → DNS01 challenge required (HTTP01 cannot validate wildcards)
  → Let's Encrypt supports wildcards via DNS01 only

IF air-gapped / no internet:
  → Private CA issuer (self-signed root or imported corporate CA)
  → No ACME (requires internet to reach Let's Encrypt)
```

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

### Installation Decisions

```
IF production:
  → Replicas: 2 (HA)
  → Resources: 256Mi / 200m requests
  → PriorityClass: system-cluster-critical
  → installCRDs: true (Helm manages CRD lifecycle)
  → Prometheus metrics: enabled

IF non-production:
  → Replicas: 1
  → Resources: 128Mi / 100m requests
  → PriorityClass: default
  → installCRDs: true
```

---

## SECURITY

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

### Security Hardening

```
IF production:
  → NetworkPolicy (Calico): restrict cert-manager namespace egress to:
    - DNS (UDP/TCP 53 to kube-dns)
    - Let's Encrypt ACME endpoints (acme-v02.api.letsencrypt.org:443)
    - Route53 API (route53.amazonaws.com:443 — or VPC endpoint)
    - Block all other egress (prevent exfiltration via cert-manager SA)
  → RBAC: cert-manager SA has only cert/issuer/secret permissions (Helm default is correct)
  → Pod security: non-root, read-only rootfs, drop all capabilities
  → Secrets: TLS secrets created by cert-manager are namespace-scoped; never cluster-readable

IF using private CA:
  → CA private key secret: restrict access to cert-manager SA only
  → NEVER store CA key in Git or ConfigMap
  → Consider: external CA (Vault, AWS PCA) instead of in-cluster CA for production

IF multi-tenant:
  → Use namespaced Issuer (not ClusterIssuer) for team-scoped certificates
  → Each team can only issue certs for their own namespaces
  → ClusterIssuer reserved for platform team (wildcards, shared domains)
```

### Network Policy for cert-manager

```yaml
apiVersion: crd.projectcalico.org/v1
kind: NetworkPolicy
metadata:
  name: cert-manager-egress
  namespace: cert-manager
spec:
  order: 100
  selector: app.kubernetes.io/instance == 'cert-manager'
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
        nets: ["0.0.0.0/0"]
        ports: [443]
```

---

## ISSUERS

### Issuer Selection

```
IF public-facing services (internet-accessible):
  → Let's Encrypt production ClusterIssuer
  → Challenge: DNS01 via Route53 (preferred — works without public ingress)
  → Scope: ClusterIssuer (platform-wide, managed by platform team)

IF public-facing but no Route53 access:
  → Let's Encrypt production with HTTP01 challenge
  → Requires: ingress controller serving /.well-known/acme-challenge
  → Scope: ClusterIssuer or namespaced Issuer

IF internal services only (no public DNS):
  → Private CA ClusterIssuer (self-signed or corporate root)
  → No external dependency; instant issuance
  → Short cert lifetime (24h-7d) acceptable for internal

IF dev/test environments:
  → Let's Encrypt STAGING (not production — avoids rate limits)
  → Or: self-signed Issuer (fastest, no external calls)
  → Browsers will show warnings (acceptable for dev)

IF per-team isolation needed:
  → Namespaced Issuer (not ClusterIssuer)
  → Each team manages their own issuer in their namespace
  → Platform team provides ClusterIssuer for shared domains only
```

### Let's Encrypt Production ClusterIssuer

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

### Private CA ClusterIssuer

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: internal-ca
spec:
  ca:
    secretName: internal-ca-key-pair
```

---

## CHALLENGES

### Challenge Selection

```
IF wildcard certificate needed:
  → DNS01 (ONLY option — HTTP01 cannot validate wildcards)

IF cluster is private (no public ingress):
  → DNS01 (works without inbound internet; only needs outbound to Route53 API)

IF simple setup + public ingress exists:
  → HTTP01 (simpler; no IAM/DNS permissions needed)
  → Requires: ingress controller correctly routing /.well-known/acme-challenge

IF Route53 hosted zone available + IRSA configured:
  → DNS01 via Route53 (preferred for EKS — reliable, no ingress dependency)

IF multiple DNS zones:
  → Multiple solvers in same ClusterIssuer, each with dnsZones selector
```

### DNS01 with Route53

```
Requirements:
  → IRSA on cert-manager ServiceAccount
  → IAM policy: route53:ChangeResourceRecordSets on specific hosted zone
  → Hosted zone ID explicitly configured in solver
  → Works for private clusters (no inbound internet needed)
  → Supports wildcard certificates
```

### HTTP01

```
Requirements:
  → Ingress controller serving /.well-known/acme-challenge path
  → Pod reachable from internet on port 80 (Let's Encrypt validates via HTTP)
  → Does NOT support wildcard certificates
  → Simpler IAM (no Route53 permissions needed)
```

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

### Gateway Integration Decisions

```
IF single domain:
  → One Certificate resource with specific dnsNames
  → One Gateway listener referencing that secret

IF wildcard (*.platform.example.com):
  → One Certificate with wildcard + bare domain in dnsNames
  → All HTTPRoutes under that domain share the same listener/cert
  → DNS01 challenge required

IF multiple unrelated domains:
  → Separate Certificate resource per domain
  → Separate Gateway listener per domain (or SNI-based)
  → Each can use different issuer if needed

IF Certificate and Gateway in different namespaces:
  → Certificate MUST be in same namespace as Gateway
  → (Secret must be readable by Gateway controller)
  → OR: use ReferenceGrant to allow cross-namespace secret access
```

---

## LIFECYCLE

### Certificate Lifecycle

```
IF certificate approaching expiry:
  → cert-manager auto-renews at 2/3 of lifetime (renewBefore)
  → Default: 90-day cert renews at 60 days (30 days before expiry)
  → No manual intervention needed if issuer is healthy

IF changing issuerRef on existing Certificate:
  → Existing cert is NOT automatically reissued
  → Old secret remains valid until natural expiry
  → To force reissuance: delete the TLS secret → cert-manager recreates with new issuer
  → NEVER change issuer without verifying new issuer is Ready first

IF TLS secret manually deleted:
  → cert-manager detects missing secret → triggers immediate reissuance
  → Safe: this is the intended "force refresh" mechanism
  → Temporary gap: services using the secret may get TLS errors for 30-120s (challenge time)

IF renewal fails:
  → Certificate remains valid until actual expiry date
  → cert-manager retries renewal on backoff schedule
  → NO immediate outage — but clock is ticking
  → If not fixed before expiry → TLS errors on all services using that cert
  → Monitor: cert_manager_certificate_ready_status == 0 → alert immediately

IF ClusterIssuer deleted:
  → Existing certificates continue working (secret still exists)
  → Renewal will FAIL when triggered (issuer gone)
  → All certs referencing that issuer will eventually expire
  → NEVER delete an issuer with active certificates unless replacing it
```

### cert-manager Upgrade

```
IF upgrading cert-manager chart:
  → Safe: CRDs auto-upgrade with installCRDs=true
  → Existing certificates and secrets are NOT affected
  → New controller version applies to future issuance/renewal
  → NEVER skip more than one minor version
  → Test in non-prod first (especially if CRD schema changes)

IF downgrading cert-manager:
  → DANGEROUS: CRDs may have new fields not understood by old controller
  → Can cause reconciliation failures
  → NEVER downgrade in production without full testing
```

### Terraform Lifecycle

```hcl
resource "helm_release" "cert_manager" {
  lifecycle {
    prevent_destroy = true  # Production: never accidentally remove cert-manager
  }
}
```

---

## FAILURE_MODES

### Certificate Stuck Pending

```
IF Certificate status shows "Pending":
  → kubectl describe certificate <name> -n <ns>
  → Check: is Issuer/ClusterIssuer Ready?
    → kubectl get clusterissuer <name> -o yaml → status.conditions
    → IF issuer not Ready: fix issuer first (credentials, connectivity)
  → Check: is CertificateRequest created?
    → kubectl get certificaterequest -n <ns>
    → IF no CertificateRequest: cert-manager controller not reconciling → check controller pods
  → Check: is Order created? (ACME issuers only)
    → kubectl get order -n <ns>
    → IF Order stuck: challenge is failing → see below
```

### DNS01 Challenge Failures

```
IF challenge status shows DNS propagation error:
  → Route53 record created but not yet propagated
  → Wait: DNS propagation can take 60-300s
  → If persistent: check hosted zone ID matches actual zone
  → Check: aws route53 list-resource-record-sets → verify TXT record created

IF "AccessDenied" on Route53:
  → IRSA not configured or role missing permissions
  → Verify: kubectl get sa cert-manager -n cert-manager -o yaml → check annotation
  → Verify: IAM policy allows ChangeResourceRecordSets on correct hosted zone ARN
  → Common: hosted zone ARN typo or wrong account

IF "no such hosted zone":
  → hostedZoneID in solver config is wrong
  → Fix: verify zone ID in Route53 console; update ClusterIssuer

IF challenge times out (>10min):
  → DNS record created but Let's Encrypt can't verify
  → Possible: split-horizon DNS (private zone hides public records)
  → Fix: ensure public hosted zone is used for ACME challenges
```

### HTTP01 Challenge Failures

```
IF challenge pod not reachable:
  → Let's Encrypt must reach /.well-known/acme-challenge on port 80
  → Check: ingress/Gateway routes HTTP traffic to cert-manager solver pod
  → Check: security group allows inbound 80 from 0.0.0.0/0 (Let's Encrypt IPs not fixed)
  → Check: NetworkPolicy allows ingress to solver pod

IF solver pod not created:
  → cert-manager controller issue → check controller logs
  → Namespace may have restrictive admission (Wiz/OPA blocking)

IF wrong ingress class targeted:
  → Solver creates an Ingress resource; must match active ingress controller
  → Fix: set ingressClassName in HTTP01 solver config
```

### Renewal Failures

```
IF certificate shows "Renewal Failed":
  → Same challenge mechanism as initial issuance — debug as above
  → Additional: rate limits (Let's Encrypt: 5 duplicate certs per week per domain)
  → IF rate-limited: wait for reset (1 week) or use different domain/subdomain
  → Monitor window: renewBefore defines how much time you have before expiry

IF cert expired (renewal never succeeded):
  → Immediate impact: TLS handshake failures for all clients
  → Fix 1: resolve challenge issue → cert-manager auto-retries
  → Fix 2 (emergency): temporarily switch to self-signed issuer for immediate cert
  → Fix 3 (emergency): manually create TLS secret from backup cert (if available)
  → Prevention: alert on cert_manager_certificate_expiration_timestamp_seconds < 7 days
```

---

## OUTPUT_CONTRACTS

| Task | Outputs |
|---|---|
| cert-manager installation | CRDs installed, controller deployment (cert-manager ns), ServiceAccount with IRSA annotation, webhook deployment |
| ClusterIssuer creation | ClusterIssuer name, Ready status, ACME account registration (for Let's Encrypt), solver configuration |
| Certificate issuance | TLS Secret name + namespace, dnsNames covered, expiry date, issuer reference |
| Gateway integration | Secret name referenced by Gateway listener, Certificate resource in gateway namespace |
| DNS01 configuration | Hosted zone ID, IRSA role ARN, Route53 permissions verified |

---

## NON_GOALS

- **ACM certificate management** — ALB/NLB TLS uses ACM; cert-manager is for in-cluster termination only
- **Certificate Authority operation** — cert-manager consumes CAs; it does not replace dedicated CA infrastructure (Vault PKI, AWS PCA)
- **Secret distribution** — cert-manager creates secrets in one namespace; cross-namespace distribution requires additional tooling (Reflector, ExternalSecrets)
- **mTLS mesh** — service-to-service mTLS at scale is a service mesh concern (Istio, Linkerd); cert-manager handles individual certificates, not mesh-wide identity
- **Certificate monitoring** — cert-manager exposes metrics; alerting belongs in Datadog skill, not here
