---
name: github-runners
description: >-
  GitHub Actions Runner Controller (ARC) and self-hosted runner decision system. Use for
  runner scale set configuration, docker-in-docker builds, ECR runner images, and runner
  label topology. Do NOT use for writing GitHub Actions workflows (use github skill) or
  general Kubernetes workloads (use kubernetes skill).
metadata:
  author: SHELYOG
  version: 2.0.0
  category: infrastructure
  updated: 2026-05-06
---
# GitHub Actions Runner Controller Decision Engine

Decision rules for self-hosted GitHub Actions runners on Kubernetes (ARC).

- GitHub Actions workflow authoring → `skills/github/`
- Kubernetes workload patterns → `skills/kubernetes/`
- Helm chart installation → `skills/helm/`
- Docker image builds → `skills/docker/`
- Node autoscaling for CI → `skills/karpenter/`
- This file answers: **how to deploy, scale, and operate self-hosted runners on EKS**

## Interaction Model
- This skill defines **runner infrastructure, scaling, security, and image patterns** only
- Workflow YAML syntax → `github` skill
- Pod scheduling, topology → `kubernetes` skill
- Runner container image builds → `docker` skill
- CI node provisioning → `karpenter` skill

---

## Decision Entry Points

| Task | Read sections |
|---|---|
| Deploy ARC to cluster | ARC_CONTROLLER + SCALE_SETS |
| Choose runner auth model | SECURITY |
| Configure runner labels | SCALE_SETS + LABELS |
| Build custom runner image | RUNNER_IMAGE |
| Enable Docker-in-Docker | DIND |
| Scale runner capacity | SCALING |
| Upgrade ARC or runners | LIFECYCLE |
| Troubleshoot runner issues | FAILURE_MODES |

---

<!-- CORE_DECISIONS: Read this section for design choices and constraints -->

## Cross-Cutting Rules

| Decision | Rule |
|---|---|
| Authentication | GitHub App (NEVER PAT for production); App credentials in Secrets Manager |
| Isolation | Each scale set = dedicated namespace; no shared state between runners |
| Ephemeral | Runners are ephemeral (one job per pod); never reuse runner pods |
| Image source | Always from private ECR; never pull public runner images in production |
| Node placement | Dedicated Karpenter NodePool for CI workloads; taint + toleration |
| Privilege | Runners run as non-root by default; DinD is the ONLY exception (isolated) |

---

<!-- REFERENCE: Detailed implementation patterns below. Read only when you need specific configs. -->

## SECURITY

### Authentication Model

```
IF production org/repo:
  → GitHub App authentication (NOT Personal Access Token)
  → App scoped to minimum permissions: actions:read, organization_self_hosted_runners:write
  → App credentials stored in Secrets Manager → mounted as K8s secret
  → NEVER store PAT in Helm values or ConfigMap

IF testing / PoC:
  → PAT acceptable (short-lived, scoped to single repo)
  → Rotate every 30 days maximum
  → Migrate to GitHub App before production use

IF fine-grained PAT required (temporary):
  → Scope to specific repositories only
  → permissions: actions:write, administration:write (for runner registration)
  → Set expiry ≤ 90 days
```

### Runner Privilege Boundaries

```
IF trusted internal code only:
  → Standard runner (non-root, no privileged)
  → DinD sidecar acceptable for container builds
  → Shared DinD deployment acceptable for efficiency

IF untrusted code (forks, external PRs, open source):
  → NEVER use shared DinD (container escape = cluster compromise)
  → Use Kaniko (daemonless, no privileged container)
  → OR: isolated sidecar DinD with NetworkPolicy restricting egress
  → NEVER mount service account tokens into runner pods
  → NEVER allow hostNetwork or hostPID

IF privileged operations needed (container builds):
  → Isolate DinD in separate namespace with strict NetworkPolicy
  → default-deny ingress + egress; allow only ECR + GitHub
  → Use seccomp profiles where supported
  → Monitor: alert on any unexpected egress from runner namespace
```

### Namespace Isolation

```
IF multi-tenant (multiple teams share cluster):
  → Separate namespace per team/runner-group
  → Separate IRSA role per namespace (least-privilege per team)
  → NetworkPolicy: default-deny between runner namespaces
  → ResourceQuota per namespace to prevent noisy-neighbor

IF single team:
  → One namespace per scale set sufficient
  → Separate from application workloads (never co-locate)

IF environment separation (prod deploy runners vs lint runners):
  → Separate namespace + scale set per environment
  → Prod deploy runners: restricted IAM role with apply permissions
  → Lint/test runners: read-only IAM role (describe, plan, validate only)
```

---

## CI_SLO

### Job Start Latency (RTO equivalent for CI)

```
IF job must start within 10s (interactive, developer-blocking):
  → minRunners ≥ 2 (always-warm pool)
  → on-demand instances (no spot interruption)
  → Karpenter: WhenEmpty consolidation with 10m delay (nodes stay warm)
  → Runner image: pre-pulled via DaemonSet on CI nodes
  → Cost: highest — paying for idle runners + idle nodes

IF job must start within 60s (standard PR workflows):
  → minRunners ≥ 1 (at least one warm runner)
  → on-demand instances
  → Karpenter: WhenEmpty consolidation with 5m delay
  → Acceptable: one cold-start if burst exceeds warm pool
  → Cost: moderate — one idle runner + one warm node minimum

IF job must start within 3min (batch, scheduled, non-blocking):
  → minRunners: 0 (scale to zero when idle)
  → spot instances acceptable (retry on interruption)
  → Karpenter: WhenEmpty consolidation with 1m delay
  → Accept: node provisioning time (60-90s) + pod startup (15-30s)
  → Cost: lowest — pay only when jobs run

IF job must start within 10min (nightly, weekly, non-urgent):
  → minRunners: 0
  → spot instances (cheapest capacity type)
  → Karpenter: aggressive consolidation (30s)
  → Accept: full cold-start including possible spot interruption + retry
  → Cost: minimal
```

### Cost Model

```
IF cost-sensitive (budget-constrained, non-revenue-critical CI):
  → spot instances for all runner nodes
  → minRunners: 0 (scale to zero)
  → consolidateAfter: 30s-1m (aggressive node reclaim)
  → smaller instance sizes (large instead of xlarge)
  → shared DinD deployment (fewer daemon pods)
  → Trade-off: occasional spot interruption → job retry (1-3min delay)
  → Estimated savings: 60-70% vs on-demand always-warm

IF latency-sensitive (developer experience priority):
  → on-demand instances (no interruption risk)
  → minRunners ≥ 1 per critical label (warm pool)
  → consolidateAfter: 5-10m (keep nodes warm between bursts)
  → larger instance sizes (2xlarge — handle burst without new node)
  → sidecar DinD (dedicated per job, no queuing)
  → Trade-off: higher cost for consistent <60s job start
  → Estimated cost: 3-5x vs scale-to-zero spot

IF balanced (most teams):
  → on-demand instances (reliability > savings for CI)
  → minRunners: 1 (one warm runner per label)
  → consolidateAfter: 5m
  → medium instance sizes (xlarge)
  → shared DinD (cost efficient, acceptable for trusted code)
  → Trade-off: first-in-burst job is warm; subsequent jobs may wait for pod creation (15-30s)
  → Estimated cost: 40-50% less than full latency-optimized
```

---

## ARC_CONTROLLER

### Controller Installation

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

```
IF production:
  → Replicas: 2 (HA across AZs)
  → Resources: 256Mi / 250m requests
  → PriorityClass: system-cluster-critical
  → Metrics: enable Prometheus metrics endpoint
  → topologySpreadConstraints: spread across AZs

IF non-production:
  → Replicas: 1
  → Resources: 128Mi / 100m requests
  → PriorityClass: default
  → Metrics: optional
```

---

## SCALE_SETS

### Scale Set Decisions

```
IF new runner group needed:
  → One helm_release per scale set
  → Dedicated namespace: arc-runners-<team>-<environment>
  → Unique runner label matching workflow runs-on
  → Dedicated IRSA role scoped to team's AWS permissions

IF runner needs AWS access:
  → IRSA ServiceAccount with least-privilege policy
  → NEVER attach node-level IAM for runner permissions
  → Scope: only the AWS actions the workflow actually needs

IF runner needs Docker build capability:
  → Pair scale set with DinD (sidecar or shared deployment)
  → Set DOCKER_HOST env var in runner container
  → See DIND section for pattern selection
```

### Scale Set Terraform Pattern

```hcl
resource "helm_release" "runner_scale_set" {
  name       = "arc-runner-${var.team}-${var.environment}"
  namespace  = "arc-runners-${var.team}-${var.environment}"
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

### Label → Scale Set Mapping

```
IF workflow needs generic Linux runner:
  → Label: ec2-ubuntu
  → Scale set: general-purpose, moderate resources

IF workflow needs AWS account access (Terraform plan/apply):
  → Label: ubuntu-kubernetes-<account-name>
  → Scale set: account-specific IRSA role, Terraform/AWS tooling in image

IF workflow needs environment-scoped deploy:
  → Label: <environment>-runner
  → Scale set: environment-scoped IRSA, deploy-specific tooling

IF workflow needs Docker build:
  → Label: docker-builder OR append to existing label with DinD sidecar
  → Scale set: paired with DinD, larger resource limits (4CPU/8Gi minimum)
```

Each label maps to a dedicated `gha-runner-scale-set` Helm release with:
- Different IAM roles (via IRSA/Pod Identity)
- Different resource limits
- Different node pool targeting
- Different namespace isolation

---

## RUNNER_IMAGE

### Image Decisions

```
IF IaC workflows (Terraform, Helm, kubectl):
  → Include: terraform, tflint, helm, kubectl, aws-cli, pre-commit
  → Base: ghcr.io/actions/actions-runner:<version>

IF container build workflows:
  → Include: docker CLI (connects to DinD), trivy, crane
  → Do NOT include Docker daemon (that's DinD's job)

IF security scanning workflows:
  → Include: trivy, tfsec, checkov, grype
  → Minimal other tooling (reduce attack surface)

IF general-purpose:
  → Include: curl, jq, python3, git, aws-cli
  → Keep minimal — workflow can install additional tools via Actions
```

### Dockerfile Pattern

```dockerfile
FROM ghcr.io/actions/actions-runner:<version>

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl unzip git jq python3 python3-pip \
    && rm -rf /var/lib/apt/lists/*

COPY --from=hashicorp/terraform:<version> /bin/terraform /usr/local/bin/
RUN curl -sL https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install kubectl /usr/local/bin/

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws/
```

### Image Lifecycle

```
IF updating runner image:
  → Build new image, push to ECR with new tag
  → Update Helm values (image tag)
  → ARC effect: new pods get new image; running pods finish current job on old image
  → Zero-downtime: jobs in progress are NOT interrupted

IF base image (actions-runner) has security update:
  → Rebuild immediately; push with updated tag
  → Roll scale sets (existing runners drain naturally)

IF adding new tool to image:
  → Add to Dockerfile, rebuild, test in non-prod scale set first
  → Never add tools that require privileged mode to install
```

---

## DIND

### Docker-in-Docker Selection

```
IF few build jobs per day (< 20):
  → Sidecar DinD per runner pod
  → Simple, fully isolated per job
  → Higher resource overhead (each pod runs its own Docker daemon)

IF many build jobs per day (> 20) AND trusted code only:
  → Shared DinD deployment (1-3 replicas)
  → Runners connect via DOCKER_HOST=tcp://docker-dind:2376
  → Shared layer cache = faster builds
  → Risk: shared daemon = weaker isolation between jobs

IF security-sensitive environment OR untrusted code:
  → Kaniko (daemonless, no privileged container needed)
  → Slower than DinD (no RUN layer cache by default)
  → No Docker socket exposure
  → No container escape risk

IF rootless Docker available and kernel supports it:
  → Rootless DinD sidecar (best of both: isolated + no privileged)
  → Requires kernel ≥ 5.11, user namespace support
  → Not all base images work in rootless mode
```

### DinD Terraform Pattern

```hcl
resource "helm_release" "docker_dind" {
  name       = "docker-dind"
  namespace  = "arc-runners-${var.team}-${var.environment}"
  chart      = "${path.module}/configs/manifests/docker-dind"
  version    = "1.0.0"
}
```

### DinD Security Rules

```
IF shared DinD deployment:
  → Dedicated namespace (same as runners, never application namespaces)
  → NetworkPolicy: allow only from runner pods in same namespace
  → Block egress except: ECR, GitHub Container Registry
  → Resource limits: prevent single build from exhausting daemon
  → No hostNetwork, no hostPID

IF sidecar DinD:
  → securityContext.privileged: true (required, but contained to pod)
  → Pod-level NetworkPolicy still applies
  → Pod terminates after job = daemon dies with it
```

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
          values: ["on-demand"]
  limits:
    cpu: "128"
  disruption:
    consolidationPolicy: WhenEmpty
    consolidateAfter: 5m
```

### Scaling Decisions

```
IF CI jobs are latency-sensitive (developers waiting):
  → minRunners ≥ 1 (warm pool, no cold-start)
  → on-demand instances (no spot interruption during job)
  → consolidateAfter: 5m (nodes stay warm briefly after last job)

IF CI jobs are batch/async (nightly, scheduled):
  → minRunners: 0 (scale to zero when idle)
  → spot instances acceptable (job can retry on interruption)
  → consolidateAfter: 1m (aggressive node reclaim)

IF bursty workload (many PRs at once):
  → maxRunners high enough to avoid queuing
  → Karpenter limits set to allow burst (cpu: 128+)
  → Monitor queue depth; alert if jobs wait > 5min

IF cost-constrained:
  → minRunners: 0
  → spot instances for non-critical jobs
  → smaller instance sizes (large instead of xlarge)
  → consolidateAfter: 1m
```

---

## LIFECYCLE

### Controller Upgrade

```
IF upgrading ARC controller:
  → Existing runner pods continue running (not terminated)
  → New reconciliation logic applies to new pods only
  → Safe: rolling update of controller deployment
  → Risk: if CRD schema changes, apply CRDs before controller upgrade
  → NEVER skip more than one minor version

IF controller pod restarts:
  → Existing runners continue (they're registered with GitHub independently)
  → New runner creation paused until controller healthy
  → No job loss — GitHub queues jobs until runner available
```

### Scale Set Changes

```
IF runner image tag updated in Helm values:
  → New pods use new image immediately
  → Existing pods finish current job, then terminate (ephemeral)
  → No manual intervention needed — natural drain
  → Zero-downtime: jobs in progress complete on old image

IF scale set min/max runners change:
  → Applied immediately by controller
  → IF increasing max: new pods created if pending jobs exist
  → IF decreasing max: excess idle runners terminated (active jobs finish first)
  → IF increasing min: warm pods created immediately
  → IF decreasing min: idle pods above new min terminated

IF namespace or labels change:
  → Requires Helm release update (new namespace = new release)
  → Old scale set should be drained: set minRunners=0, maxRunners=0
  → Wait for active jobs to complete, then delete old release
  → GitHub: old runner group/label becomes empty; workflows must target new label

IF GitHub App secret rotated:
  → Update K8s secret (Secrets Manager → ExternalSecrets or manual)
  → Restart controller pod to pick up new credentials
  → Existing runners with valid token continue until token expires
  → New runners use new credentials immediately after controller restart
```

### Runner Pod Lifecycle

```
IF job completes:
  → Runner pod terminates immediately (ephemeral, single-use)
  → Controller creates new pod if pending jobs or below minRunners

IF job times out (workflow timeout-minutes exceeded):
  → GitHub cancels job → runner pod terminates
  → Controller creates replacement

IF runner pod evicted (node drain, preemption):
  → Job fails → GitHub re-queues to another available runner
  → No manual intervention needed (GitHub handles retry)
  → Karpenter: set do-not-disrupt annotation during active jobs (if supported)

IF runner pod OOMKilled:
  → Job fails → marked as failed in GitHub
  → NOT automatically retried (GitHub does not retry failed jobs)
  → Fix: increase memory limits in scale set values
```

---

## FAILURE_MODES

### Runner Registration Failures

```
IF runners not registering with GitHub:
  → Check controller logs: kubectl logs -n arc-system deploy/arc-gha-runner-scale-set-controller
  → IF "unauthorized" or "401": GitHub App credentials invalid or expired
    → Verify: Secrets Manager value matches GitHub App configuration
    → Fix: regenerate App private key; update K8s secret; restart controller
  → IF "app not installed": GitHub App not installed on target org/repo
    → Fix: install App on correct scope (org-level recommended)
  → IF "runner group not found": runnerGroup in values doesn't exist in GitHub
    → Fix: create runner group in GitHub org settings first

IF runners register but immediately go offline:
  → Check runner pod logs: kubectl logs <pod> -n <runner-ns>
  → IF "ENTRYPOINT failed": image incompatibility
    → Fix: verify image is based on ghcr.io/actions/actions-runner
  → IF OOMKilled: insufficient memory for runner + job
    → Fix: increase limits
```

### Job Scheduling Failures

```
IF jobs stuck in "Queued" state (not picked up):
  → Check 1: runs-on label matches scale set runner label EXACTLY
    → GitHub is case-sensitive; "EC2-Ubuntu" ≠ "ec2-ubuntu"
  → Check 2: runner group assignment — workflow must target correct group
  → Check 3: maxRunners reached — scale set at capacity
    → Fix: increase maxRunners or add another scale set
  → Check 4: runners exist but "Idle" — controller not assigning
    → Restart controller; check for listener pod issues

IF jobs assigned but pod never starts:
  → Check: kubectl get pods -n <runner-ns> (look for Pending)
  → IF Pending + "Insufficient cpu/memory": nodes at capacity
    → Fix: verify Karpenter NodePool limits; check instance availability
  → IF Pending + "no nodes match selector": nodeSelector/toleration mismatch
    → Fix: verify node-role label exists on CI nodes; verify taint matches toleration
  → IF Pending + ImagePullBackOff: ECR auth or image not found
    → Fix: verify ECR pull-through cache or cron job refreshing auth
```

### Scaling Issues

```
IF scaling is slow (jobs wait > 2min for runner):
  → Expected: ARC uses polling (not webhooks by default) — 10-30s delay
  → IF using webhook mode: check webhook delivery in GitHub App settings
  → IF node creation needed: Karpenter cold-start adds 60-90s for new node
  → Mitigation: set minRunners ≥ 1 for latency-sensitive workflows
  → Mitigation: pre-warm nodes with Karpenter WhenEmpty + 5min consolidation

IF runners not scaling down (idle pods remain):
  → Check: minRunners setting — pods won't drop below this
  → Check: controller health — unhealthy controller can't reconcile
  → Check: stale runner registrations in GitHub (manually remove if needed)
  → IF pods stuck "Running" with no job: possible listener desync — restart controller
```

### DinD Failures

```
IF Docker build fails inside runner:
  → Check: DOCKER_HOST env var set correctly in runner container
  → IF "Cannot connect to Docker daemon": DinD not running or wrong port
    → Sidecar: check sidecar container status in same pod
    → Shared: check DinD deployment pods; verify NetworkPolicy allows connection
  → IF "permission denied": TLS cert mismatch between runner and DinD
    → Fix: ensure shared certs mounted correctly; or use --tls=false for internal-only

IF DinD pod OOMKilled:
  → Large image builds exhaust daemon memory
  → Fix: increase DinD resource limits
  → Fix: use multi-stage builds to reduce peak memory
  → Fix: prune images between builds (docker system prune in shared mode)
```

---

## OUTPUT_CONTRACTS

| Task | Outputs |
|---|---|
| ARC controller install | Controller deployment (arc-system ns), CRDs (AutoscalingRunnerSet, EphemeralRunnerSet), webhook endpoint (if enabled) |
| Runner scale set | Runner pods, GitHub runner registration, label mapping, listener pod, namespace |
| Runner image | ECR image URI (registry/repo:tag), tools installed, base runner version |
| Scaling config | minRunners, maxRunners, Karpenter NodePool name, instance types, capacity type |
| DinD setup | DinD deployment/sidecar, DOCKER_HOST value, TLS config, NetworkPolicy |
| GitHub App auth | K8s secret name, Secrets Manager ARN, App ID, installation ID |

---

## NON_GOALS

- **Workflow authoring** — writing `jobs:`, `steps:`, `uses:` belongs in `github` skill
- **Application deployment** — runners execute pipelines; they are not the deployment mechanism
- **Permanent workloads** — runners are ephemeral single-use; never run long-lived services as "runner jobs"
- **Cluster-admin operations** — runner IRSA roles should NEVER have cluster-admin; scope to specific namespaces/resources
- **Public runner replacement** — self-hosted runners add complexity; only use when GitHub-hosted runners cannot meet requirements (network access, custom tooling, cost at scale)
