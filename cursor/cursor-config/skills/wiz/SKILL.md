---
name: wiz
description: >-
  Wiz security platform decision system for Kubernetes admission control and runtime
  protection. Use for Wiz Terraform provider configuration, Helm chart deployment,
  admission webhook policies, and connector setup. Do NOT use for general Kubernetes
  security (use kubernetes skill) or standalone OPA/Gatekeeper patterns.
metadata:
  author: SHELYOG
  version: 1.0.0
  category: security
  updated: 2026-05-06
---
# Wiz Security Platform Decision Engine

Decision rules for Wiz integration in EKS clusters.

- General K8s pod security → `skills/kubernetes/`
- EKS cluster security settings → `skills/eks/`
- IAM and encryption → `skills/aws/`
- Helm installation patterns → `skills/helm/`
- This file answers: **how to deploy and configure Wiz for admission control and runtime security**

## Interaction Model
- This skill defines **Wiz provider config, Helm deployment, and admission policy** patterns
- Cluster-level security (PSA, RBAC) → `kubernetes` skill
- Network isolation → `calico` skill
- Image scanning in CI → `github` or `docker` skill

---

## Decision Entry Points

| Task | Read sections |
|---|---|
| Deploy Wiz to cluster | INSTALLATION + PROVIDER |
| Configure admission policies | ADMISSION_WEBHOOK |
| Manage Wiz connector | PROVIDER + CONNECTOR |
| Wiz secrets management | SECRETS |
| Troubleshoot Wiz issues | TROUBLESHOOTING |

---

<!-- CORE_DECISIONS: Read this section for design choices and constraints -->

## Cross-Cutting Rules

| Decision | Rule |
|---|---|
| Provider credentials | Always from Secrets Manager; never in Terraform state or values |
| Admission mode | Start with `Audit` (non-blocking); move to `Enforce` after baseline |
| Namespace scope | Apply to application namespaces; exclude system namespaces |
| Failure mode | `failurePolicy: Ignore` in production (fail-open); prevents Wiz outage from blocking deploys |
| Updates | Pin chart version; upgrade in non-prod first; validate admission rules don't break |

---

<!-- REFERENCE: Detailed implementation patterns below. Read only when you need specific configs. -->

## PROVIDER

### Wiz Terraform Provider

```hcl
terraform {
  required_providers {
    wiz = {
      source  = "tf.app.wiz.io/wizsec/wiz"
      version = "~> 1.0"
    }
  }
}

provider "wiz" {
  client_id     = data.aws_secretsmanager_secret_version.wiz_client_id.secret_string
  client_secret = data.aws_secretsmanager_secret_version.wiz_client_secret.secret_string
}
```

### Provider Resources

| Resource | Purpose |
|---|---|
| `wiz_connector_aws` | Connect AWS account to Wiz for cloud scanning |
| `wiz_kubernetes_cluster` | Register EKS cluster for runtime protection |
| `wiz_admission_policy` | Define admission control rules |
| `wiz_integration_aws_sns` | Alert routing to SNS |

---

## INSTALLATION

### Wiz Kubernetes Integration Helm Chart

```hcl
resource "helm_release" "wiz" {
  name       = "wiz-kubernetes-integration"
  namespace  = "wiz"
  repository = "https://charts.wiz.io"
  chart      = "wiz-kubernetes-integration"
  version    = var.wiz_chart_version

  create_namespace = true

  values = [templatefile("${path.module}/configs/manifests/wiz/values.yaml", {
    cluster_name = var.cluster_name
    wiz_api_url  = var.wiz_api_url
  })]

  set_sensitive {
    name  = "global.wizApiToken.clientId"
    value = data.aws_secretsmanager_secret_version.wiz_client_id.secret_string
  }

  set_sensitive {
    name  = "global.wizApiToken.clientToken"
    value = data.aws_secretsmanager_secret_version.wiz_client_secret.secret_string
  }
}
```

### Component Decisions

| Component | Enable When |
|---|---|
| `opaWebhook` (admission controller) | All production clusters |
| `sensor` (runtime) | Clusters with sensitive workloads |
| `connector` | All clusters (inventory/scanning) |
| `broker` | Air-gapped or restricted egress environments |

---

## ADMISSION_WEBHOOK

### OPA Webhook Configuration

```yaml
opaWebhook:
  enabled: true
  failurePolicy: Ignore  # Fail-open in production
  namespaceSelector:
    matchExpressions:
      - key: kubernetes.io/metadata.name
        operator: NotIn
        values:
          - kube-system
          - kube-node-lease
          - kube-public
          - wiz
          - velero
          - datadog
          - arc-system
  rules:
    - operations: ["CREATE", "UPDATE"]
      apiGroups: ["apps", ""]
      resources: ["deployments", "pods", "replicasets", "statefulsets", "daemonsets"]
```

### Admission Policy Decisions

| Policy | Mode | What It Catches |
|---|---|---|
| Privileged containers | Enforce | `securityContext.privileged: true` |
| Root user | Audit → Enforce | `runAsUser: 0` or missing `runAsNonRoot` |
| Latest tag | Enforce | `image: foo:latest` |
| Missing resource limits | Audit | No `resources.limits` defined |
| Host networking | Enforce | `hostNetwork: true` |
| Sensitive mounts | Audit | `/var/run/docker.sock`, `/etc/shadow` |

### Rollout Strategy

1. Deploy with `Audit` mode (logs violations, doesn't block)
2. Review findings for 1-2 weeks
3. Address legitimate violations
4. Switch to `Enforce` for clear-cut rules (privileged, latest tag)
5. Keep `Audit` for rules with known exceptions

---

## SECRETS

### Credentials Pattern

```hcl
data "aws_secretsmanager_secret_version" "wiz_client_id" {
  secret_id = "platform/wiz/client-id"
}

data "aws_secretsmanager_secret_version" "wiz_client_secret" {
  secret_id = "platform/wiz/client-secret"
}
```

### Secret Rotation

- Wiz service account credentials should be rotated quarterly
- Use Secrets Manager automatic rotation if supported
- After rotation: restart Wiz pods to pick up new credentials

---

## CONNECTOR

### AWS Account Connector

```hcl
resource "wiz_connector_aws" "this" {
  name                 = "ae-${var.environment}"
  auth_params          = jsonencode({
    roleArn = aws_iam_role.wiz_connector.arn
  })
  extra_config         = jsonencode({
    region = var.region
  })
}
```

### Connector IAM Role

- Cross-account trust to Wiz's AWS account
- ReadOnly access for scanning (SecurityAudit + ViewOnlyAccess managed policies)
- Additional custom policy for EKS describe, ECR scan results
- Never grant write permissions to Wiz connector role

---

## TROUBLESHOOTING

| Problem | Diagnosis | Fix |
|---|---|---|
| Admission webhook blocking deploys | Check Wiz webhook logs | Set `failurePolicy: Ignore` or add namespace exclusion |
| Wiz pods CrashLooping | Secret credentials invalid | Verify Secrets Manager values; restart pods after rotation |
| Missing cluster in Wiz dashboard | Connector not registered | Check `wiz_kubernetes_cluster` resource; verify API connectivity |
| False positive admission blocks | Legitimate workload pattern | Add policy exception in Wiz console or switch rule to Audit |
| High webhook latency | Wiz API slow or webhook overloaded | Check resource limits; consider `timeoutSeconds` increase |

---

## References

- [Wiz Documentation](https://docs.wiz.io/)
- [Wiz Kubernetes Admission Controller](https://docs.wiz.io/wiz-docs/docs/kubernetes-admission-controller)
- [Wiz Terraform Provider](https://registry.terraform.io/providers/AxtonGrams/wiz/latest/docs)
- [Wiz Helm Charts](https://charts.wiz.io/)
- [Kubernetes Admission Webhooks](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/)
