---
name: kubernetes
description: >-
  Kubernetes decision system for workload management, networking, security, and operations.
  Use for workload type selection, service networking, pod security, scheduling, and
  troubleshooting. Do NOT use for EKS-specific config (use eks skill) or Helm specifics (use helm skill).
metadata:
  author: SHELYOG
  version: 3.1.0
  category: infrastructure
  updated: 2026-05-05
---
# Kubernetes Decision Engine

Decision rules for Kubernetes workloads and operations. Not reference material.

- EKS cluster config → `skills/eks/`
- Helm chart management → `skills/helm/`
- Node autoscaling → `skills/karpenter/`
- This file answers: **what workload type, networking model, and security posture**

## Interaction Model
- This skill defines **workload-level** decisions (pods, services, scheduling, security)
- Cluster-level config (VPC CNI, add-ons, upgrades) → `eks` skill
- Node provisioning and scaling → `karpenter` skill
- Packaging and templating → `helm` skill
- Ingress/gateway routing → `envoy-gateway` skill

---

## Decision Entry Points

| Task | Read sections |
|---|---|
| Deploy new application | WORKLOADS + NETWORKING + SECURITY |
| Service-to-service communication | NETWORKING |
| Storage for stateful app | STORAGE |
| Pod security hardening | SECURITY |
| Scheduling constraints | SCHEDULING |
| Debugging pod issues | Troubleshooting |

---

<!-- CORE_DECISIONS: Read this section for design choices and constraints -->

## Cross-Cutting Rules

| Decision | Domains | Rule |
|---|---|---|
| Resource requests/limits | Workloads + Scheduling | Mandatory on all containers — no exceptions |
| Health probes | Workloads + Networking | All production pods need liveness + readiness |
| Non-root containers | Security + Workloads | Default for all pods — `runAsNonRoot: true` |
| PDBs | Workloads + Scheduling | Required for all production deployments |
| Namespace isolation | Security + Networking | Separate by team/function + NetworkPolicy |
| Admission control | Security + All | Enforces invariants at workload creation time (PSA + Kyverno/OPA) |

---

<!-- REFERENCE: Detailed implementation patterns below. Read only when you need specific configs. -->

## [WORKLOADS]

**Workload type selection**:
- **Stateless app** → Deployment (rolling updates, scaling)
- **Stateful app** (needs stable identity/storage) → StatefulSet
- **Node-level agent** (logging, monitoring) → DaemonSet
- **Run-to-completion task** → Job
- **Scheduled task** → CronJob
- **Never**: Bare pods without a controller

**Resource management**:
- Always set `requests` (scheduling) and `limits` (protection)
- Requests = typical usage; Limits = max burst (usually 2-4x requests for CPU)
- Memory limits = memory requests (OOMKilled is better than node pressure)
- **Consequences**: No requests → pod may never schedule or cause eviction of others; limits too low → OOMKill loops

**Images**:
- Always use immutable tags or SHA digests — never `latest` in production
- Rationale: rollback reliability, reproducibility, cache correctness

**Health probes**:
- **livenessProbe**: Failure → container restart (use for deadlocks/hangs)
- **readinessProbe**: Failure → removed from load balancer (use for startup/dependencies)
- **startupProbe**: Delays other probes — use for slow-starting apps
- **Default probe type**: HTTP GET on `/health` (or gRPC health check)
- **Common misuse**: Using liveness where readiness is needed → causes unnecessary restarts

**Rolling update config**:
- `maxSurge: 25%` + `maxUnavailable: 25%` (default, good for most)
- `minReadySeconds: 10` for slow-starting services
- `revisionHistoryLimit: 5` (enough for rollback)

---

## [NETWORKING]

**Service type selection**:
- **Default**: ClusterIP (internal-only)
- **If external HTTP traffic** → ClusterIP + Ingress/Gateway (ALB via controller)
- **If external TCP/UDP** → LoadBalancer (NLB)
- **If StatefulSet needs direct pod addressing** → Headless Service (clusterIP: None)
- **Avoid**: NodePort in production (exposes port on all nodes)

**Ingress strategy**:
- **Default**: Gateway API (HTTPRoute) — successor to Ingress, better role separation
- **If simple path-based routing** → Ingress still works (but prefer Gateway API for new work)
- **If gRPC, TLS passthrough, TCP** → Gateway API (GRPCRoute, TLSRoute, TCPRoute)

**Network Policies**:
- **Default**: Start with deny-all ingress/egress per namespace
- Add allow rules for specific traffic patterns
- Policies are additive (union of all matching)
- Policies are **namespace-scoped only** — no policy in a namespace = allow ALL traffic
- Enforcement depends on CNI support (Calico, Cilium, VPC CNI v1.14+) — verify before relying
- Use namespace selectors for cross-namespace rules

**DNS**:
- Services: `<service>.<namespace>.svc.cluster.local`
- Use short names within same namespace
- `dnsPolicy: ClusterFirst` (default) unless pod needs custom DNS

---

## [STORAGE]

**Access mode selection**:
- **ReadWriteOnce** → Single pod (EBS volumes) — most common
- **ReadOnlyMany** → Multiple pods read same data (pre-populated content)
- **ReadWriteMany** → Multiple pods write (EFS only — NFS-based)

**StorageClass decisions**:
- **Default**: gp3 (best price/performance for general use)
- **If high IOPS needed** → io2 (provisioned IOPS)
- **If shared filesystem** → EFS (ReadWriteMany, scales automatically)
- Set `volumeBindingMode: WaitForFirstConsumer` (topology-aware)
- Enable `allowVolumeExpansion: true`

**Reclaim policy**:
- **Production**: Retain (manual cleanup — prevents data loss)
- **Non-production**: Delete (automatic cleanup)
- **Warning**: PVC deletion + `Delete` reclaim policy = **permanent data loss** (no recovery)
- Production must always use `Retain` unless explicitly managed by backup/restore pipeline

**hostPath volumes**:
- **Avoid** in application workloads — grants direct access to node filesystem
- Effectively equivalent to privileged in many escape scenarios
- Only acceptable for system DaemonSets (log collectors, CSI drivers) with strict review

---

## [SECURITY]

**Pod Security Standards**:
- **Default for workloads**: Restricted (most secure)
- **If needs host networking or privileged** → Baseline (rare, justify in review)
- **Never**: Privileged (only for system-level DaemonSets like CNI)
- Enforce at namespace level: `pod-security.kubernetes.io/enforce: restricted`

**securityContext** (mandatory on all pods):
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  seccompProfile:
    type: RuntimeDefault
  capabilities:
    drop: ["ALL"]
```
- `RuntimeDefault` reduces kernel attack surface but still allows many syscalls
- If `seccompProfile` is omitted → may run as `Unconfined` (no syscall restriction at all)
- **If high-security workload** → Use custom seccomp profiles for stricter filtering
- `privileged: true` **bypasses seccomp and most security controls** — avoid entirely
- Containers inherit pod-level seccomp if not explicitly set — always verify at container level for critical workloads

**Container isolation boundary**:
- Containers share host kernel — kernel vulnerabilities bypass container hardening
- Patch node OS regularly; container security is defense-in-depth, not full isolation

**Admission control** (creation-time enforcement):
- Pod Security Admission (PSA) for baseline/restricted enforcement at namespace level
- **If custom policies needed** → Kyverno or OPA Gatekeeper
- RBAC alone cannot enforce pod-level security restrictions — admission control is required
- Admission control does NOT enforce runtime drift or node-level issues — complement with runtime monitoring

**Secrets**:
- **Never** store secrets in plain env vars or manifests (base64 is not encryption)
- Use External Secrets Operator or CSI Secrets Store Driver (AWS Secrets Manager / SSM)
- Rotate secrets on a defined schedule
- Secrets in etcd are only encrypted if envelope encryption is enabled (EKS: KMS)

**Image supply chain**:
- Use trusted registries only (ECR, private registries — not Docker Hub for production)
- Scan images before deploy (Trivy, Grype, or ECR native scanning)
- Prefer minimal base images (distroless, alpine) — fewer CVEs
- Image scanning is necessary but not sufficient — runtime behavior must also be monitored

**Service Accounts**:
- Dedicated SA per workload (never share)
- `automountServiceAccountToken: false` unless pod needs K8s API access
- IRSA annotation for AWS access (EKS-specific)

**RBAC**:
- **Default**: Deny-all (no wildcard verbs or resources in Roles)
- Namespace-scoped Roles for app teams
- ClusterRoles only for cluster-wide resources (nodes, namespaces, CRDs)
- **Never**: Bind `cluster-admin` to application workloads
- **Never**: Use `*` in verbs or resources (specify explicitly)
- RBAC misconfig is one of the highest real-world security risks

---

## [SCHEDULING]

**Spreading decisions**:
- **Default**: `topologySpreadConstraints` across zones (maxSkew: 1)
- **If anti-affinity between replicas** → podAntiAffinity (preferredDuringScheduling)
- **If specific node pool** → nodeSelector with labels matching NodePool

**Taints and tolerations**:
- Use for dedicated node pools (GPU, spot-only, system)
- Pods without matching toleration won't schedule on tainted nodes

**Priority**:
- `system-cluster-critical` / `system-node-critical` for platform components
- Custom PriorityClass for business-critical workloads
- Lower priority for batch/background jobs (preemptible)

---

## [OBSERVABILITY]

**Logging**:
- Application logs to stdout/stderr (collected by node agent)
- Structured JSON format for parsing
- Centralize via Datadog Agent or Fluentd

**Metrics**:
- Metrics Server for `kubectl top` and HPA
- Datadog/Prometheus for custom metrics and dashboards
- Expose `/metrics` endpoint on apps for scraping

**Tracing**:
- OpenTelemetry SDK in applications
- Datadog APM or ADOT collector for trace aggregation

---

## Execution Guarantees (Invariants)

These must hold for every workload — no exceptions without explicit justification:

- No workload runs without resource requests/limits
- No pod runs as root unless explicitly justified and approved
- No service exposed externally without Ingress/Gateway (never raw NodePort/LoadBalancer)
- No stateful workload without persistent storage and Retain reclaim policy
- No namespace should exist without a default-deny NetworkPolicy (effectiveness depends on CNI enforcement capability)
- No container uses `latest` tag or mutable image reference
- No Role uses wildcard (`*`) verbs or resources

---

## Anti-Patterns (Never Do)

| Anti-Pattern | Why It's Wrong | Do This Instead |
|---|---|---|
| Bare pods (no controller) | No restart, no scaling, no rolling update | Deployment/StatefulSet/Job |
| No resource requests/limits | Unschedulable or noisy-neighbor issues | Set requests AND limits |
| NodePort in production | Exposes ports on all nodes, security risk | ClusterIP + Ingress/Gateway |
| Privileged containers | Full host access, escape risk | Restricted security context |
| Default SA with auto-mount | Token exposed to all containers | Dedicated SA, disable auto-mount |
| No PDBs | Upgrades/scaling disrupts all replicas | minAvailable or maxUnavailable PDB |
| No health probes | Broken pods keep receiving traffic | liveness + readiness probes |
| `latest` or mutable image tags | Non-reproducible, rollback impossible, cache drift | Immutable tags or SHA digests |
| No Network Policies | Any pod can reach any pod | Default deny + explicit allow |
| Wildcard RBAC (`*`) | Over-privileged, lateral movement risk | Explicit verbs and resources |

---

## Troubleshooting Decision Trees

**Pod stuck Pending?**
1. Resource requests too high for available nodes? → Reduce or add nodes
2. Node selector/affinity too restrictive? → Check matching nodes exist
3. Taints blocking? → Add matching toleration
4. PVC waiting? → Check StorageClass, volume binding mode, available disk

**Pod CrashLoopBackOff?**
1. Check logs: `kubectl logs <pod> -p` (previous container)
2. OOMKilled? → Increase memory limits
3. Liveness probe failing? → Increase `initialDelaySeconds` or fix health endpoint
4. Config error? → Check ConfigMap/Secret mounts, env vars

**Pod ImagePullBackOff?**
1. Image name/tag correct? → Check for typos
2. Registry credentials? → Check imagePullSecrets or IRSA for ECR
3. Private registry? → VPC endpoint or network path needed

**Service not reachable?**
1. Selectors match pod labels? → Compare `spec.selector` with pod labels
2. Endpoints exist? → `kubectl get endpoints <service>`
3. Network Policy blocking? → Check ingress rules for the namespace
4. Port correct? → Verify `targetPort` matches container port

---

## Reference Documentation

- **Kubernetes Docs**: https://kubernetes.io/docs/home/
- **API Reference**: https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.35/
- **Pod Security Standards**: https://kubernetes.io/docs/concepts/security/pod-security-standards/
- **Network Policies**: https://kubernetes.io/docs/concepts/services-networking/network-policies/
- **Gateway API**: https://gateway-api.sigs.k8s.io/
- **kubectl Cheat Sheet**: https://kubernetes.io/docs/reference/kubectl/cheatsheet/
