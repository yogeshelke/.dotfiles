---
name: github-runners
description: >-
  GitHub Actions Runner Controller (ARC) and self-hosted runner decision system. Use for
  runner scale set configuration, docker-in-docker builds, ECR runner images, and runner
  label topology. Do NOT use for writing GitHub Actions workflows (use github skill) or
  general Kubernetes workloads (use kubernetes skill).
metadata:
  author: SHELYOG
  version: 1.0.0
  category: infrastructure
  updated: 2026-05-06
---
# GitHub Actions Runner Controller Decision Engine

Decision rules for self-hosted GitHub Actions runners on Kubernetes (ARC).

- GitHub Actions workflow authoring → `skills/github/`
- Kubernetes workload patterns → `skills/kubernetes/`
- Helm chart installation → `skills/helm/`
- Docker image builds → `skills/docker/`
- This file answers: **how to deploy and manage self-hosted runners on EKS**

## Interaction Model
- This skill defines **runner infrastructure, scaling, and image patterns** only
- Workflow YAML syntax → `github` skill
- Pod scheduling, resources → `kubernetes` skill
- Runner container image builds → `docker` skill

---

## Decision Entry Points

| Task | Read sections |
|---|---|
| Deploy ARC to cluster | ARC_CONTROLLER + SCALE_SETS |
| Configure runner labels | SCALE_SETS + LABELS |
| Build custom runner image | RUNNER_IMAGE |
| Enable Docker-in-Docker | DIND |
| Scale runner capacity | SCALING |
| Troubleshoot runner issues | TROUBLESHOOTING |

---

## Cross-Cutting Rules

| Decision | Rule |
|---|---|
| Runner isolation | Each scale set = dedicated namespace; no shared state between runners |
| Image source | Always from private ECR; never pull public runner images in production |
| Secrets | GitHub App credentials in Secrets Manager → External Secrets or Helm values |
| Node placement | Dedicated node pool (Karpenter NodePool) for CI workloads; taint + toleration |
| Ephemeral | Runners are ephemeral (one job per pod); never reuse runner pods |

---

## ARC_CONTROLLER

### Controller Installation (Helm via Terraform)

```hcl
resource "helm_release" "arc_controller" {
  name       = "arc"
  namespace  = "arc-system"
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set-controller"
  version    = var.arc_controller_version

  create_namespace = true
}
```

### Controller Decisions

| Setting | Production | Non-Production |
|---|---|---|
| Replicas | 2 (HA) | 1 |
| Resource requests | 256Mi / 250m | 128Mi / 100m |
| Priority class | `system-cluster-critical` | Default |
| Metrics | Enable Prometheus metrics | Optional |

---

## SCALE_SETS

### Runner Scale Set Pattern

```hcl
resource "helm_release" "runner_scale_set" {
  name       = "arc-runner-${var.environment}"
  namespace  = "arc-runners-${var.environment}"
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set"
  version    = var.arc_runner_version

  create_namespace = true

  values = [templatefile("${path.module}/configs/manifests/gha-runner-scale-set/values.yaml", {
    github_config_url    = var.github_org_url
    runner_group         = var.runner_group
    min_runners          = var.min_runners
    max_runners          = var.max_runners
    runner_image         = "${var.ecr_registry}/${var.runner_image_name}:${var.runner_image_tag}"
    service_account_name = var.runner_sa_name
  })]
}
```

### Values Template

```yaml
githubConfigUrl: "${github_config_url}"
githubConfigSecret: arc-github-secret
runnerGroup: "${runner_group}"
minRunners: ${min_runners}
maxRunners: ${max_runners}

template:
  spec:
    serviceAccountName: "${service_account_name}"
    containers:
      - name: runner
        image: "${runner_image}"
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            cpu: "4"
            memory: "8Gi"
    nodeSelector:
      node-role: ci
    tolerations:
      - key: "ci-workload"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"
```

---

## LABELS

### Runner Label Topology

| Label Pattern | Purpose | Example |
|---|---|---|
| `ec2-ubuntu` | Generic Linux runner | Most workflows |
| `ubuntu-kubernetes-<account>` | Account-specific runner with AWS creds | Terraform plan/apply in CI |
| `<environment>-runner` | Environment-scoped | Prod deploy gates |

### Label → Scale Set Mapping

Each label maps to a dedicated `gha-runner-scale-set` Helm release:
- Different IAM roles (via IRSA/Pod Identity)
- Different resource limits
- Different node pools

---

## RUNNER_IMAGE

### Custom ECR Runner Image Pattern

```dockerfile
FROM ghcr.io/actions/actions-runner:<version>

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl unzip git jq python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Terraform
COPY --from=hashicorp/terraform:<version> /bin/terraform /usr/local/bin/
# TFLint
RUN curl -sL https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
# Helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
# kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install kubectl /usr/local/bin/

# AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws/
```

### Image Decisions

| Tool | Include When |
|---|---|
| Terraform + TFLint | IaC workflows |
| Helm + kubectl | K8s deployment workflows |
| AWS CLI | Any AWS interaction |
| Docker CLI | Container build workflows (pair with DinD) |
| pre-commit | Lint/format workflows |
| trivy/tfsec | Security scanning workflows |

---

## DIND

### Docker-in-Docker for Container Builds

Separate DinD sidecar or dedicated DinD deployment:

```hcl
resource "helm_release" "docker_dind" {
  name       = "docker-dind"
  namespace  = "arc-runners-${var.environment}"
  chart      = "${path.module}/configs/manifests/docker-dind"
  version    = "1.0.0"
}
```

### DinD Decisions

| Approach | Pros | Cons | Use When |
|---|---|---|---|
| Sidecar DinD | Simple, isolated per job | Resource overhead per pod | Few build jobs |
| Shared DinD deployment | Efficient, shared cache | Security boundary weaker | Many build jobs, trusted code |
| Kaniko (daemonless) | No privileged container | Slower, no `RUN --mount` cache | Security-sensitive environments |

### DinD Security

- Run DinD in dedicated namespace with restricted NetworkPolicy
- Use `--userns-remap` if available
- Never expose Docker socket to application namespaces
- Consider rootless Docker or Kaniko for hardened environments

---

## SCALING

### Karpenter NodePool for CI

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: ci-runners
spec:
  template:
    metadata:
      labels:
        node-role: ci
    spec:
      taints:
        - key: ci-workload
          value: "true"
          effect: NoSchedule
      requirements:
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m"]
        - key: karpenter.k8s.aws/instance-size
          operator: In
          values: ["xlarge", "2xlarge"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]  # CI needs predictable performance
  limits:
    cpu: "128"
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 5m
```

---

## TROUBLESHOOTING

| Problem | Diagnosis | Fix |
|---|---|---|
| Runners not registering | Check controller logs + GitHub App permissions | Verify App installation scope, secret validity |
| Jobs queued but not picked up | Label mismatch | Verify `runs-on` matches scale set runner label |
| Runner pods OOMKilled | Insufficient memory limits | Increase limits; consider per-workflow sizing |
| Docker build fails in runner | DinD not available | Check DinD sidecar/deployment, `DOCKER_HOST` env |
| Image pull failures | ECR auth expired | Verify ECR pull-through cache or cron refresh |
| Runners not scaling down | `minRunners` too high or jobs stuck | Check ARC listener logs; reduce `minRunners` |
