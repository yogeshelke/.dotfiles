---
name: kubernetes
description: >-
  Kubernetes reference for container orchestration, workload management, and cluster operations. 
  Use when user mentions "Kubernetes", "K8s", "kubectl", "pods", "deployments", "services", 
  "ingress", "namespace", "configmap", "secret", "persistent volume", "cluster", "nodes", 
  "YAML manifest", "Helm charts", or asks about container orchestration, microservices deployment, 
  or K8s troubleshooting. Do NOT use for Docker-only questions or other orchestration platforms 
  (Docker Swarm, Nomad) without Kubernetes context.
metadata:
  author: SHELYOG
  version: 2.0.0
  category: infrastructure
  updated: 2026-05-03
---
# Kubernetes Comprehensive Reference

Use this skill when working with any Kubernetes resources, troubleshooting, cluster operations, or application deployment.

## Architecture

### Control Plane Components
- **kube-apiserver** - API frontend; all communication goes through it
- **etcd** - Distributed key-value store for cluster state
- **kube-scheduler** - Assigns pods to nodes based on constraints and resources
- **kube-controller-manager** - Runs controllers (Deployment, ReplicaSet, Node, Job, etc.)
- **cloud-controller-manager** - Integrates with cloud provider APIs (AWS, GCP, Azure)

### Node Components
- **kubelet** - Agent on each node; manages pod lifecycle
- **kube-proxy** - Network proxy implementing Service networking
- **Container runtime** - Runs containers (containerd, CRI-O)

## Workload Resources

### Pods
- Smallest deployable unit; one or more containers sharing network/storage
- Always use controllers (Deployment, StatefulSet) to manage pods; never create bare pods
- Set resource `requests` and `limits` for all containers
- Use init containers for startup dependencies
- Configure `terminationGracePeriodSeconds` for graceful shutdown

### Deployments
- Manages stateless applications with ReplicaSets
- Rolling updates with `maxSurge` and `maxUnavailable` control
- Use `revisionHistoryLimit` to control rollback depth
- Supports pause/resume for batched changes
- Use `minReadySeconds` to slow down rollouts

### StatefulSets
- For stateful applications requiring stable network identity and persistent storage
- Ordered, graceful deployment and scaling
- Stable, unique network identifiers (pod-0, pod-1, ...)
- Persistent volume claims per replica

### DaemonSets
- Runs a pod on every node (or selected nodes)
- Use for node-level agents: log collectors, monitoring, network plugins
- Supports rolling updates

### Jobs and CronJobs
- **Job** - Run-to-completion workloads; configurable retries and parallelism
- **CronJob** - Scheduled Jobs using cron syntax
- Set `activeDeadlineSeconds` to prevent runaway jobs
- Use `backoffLimit` to control retry behavior

## Service & Networking

### Services
- **ClusterIP** - Internal-only access (default)
- **NodePort** - Exposes on a static port on each node (avoid in production)
- **LoadBalancer** - Provisions cloud load balancer
- **ExternalName** - DNS CNAME alias to external service
- **Headless Service** - No ClusterIP; returns pod IPs directly (for StatefulSets)

### Ingress / Gateway API
- **Ingress** - Legacy HTTP routing (L7); being superseded by Gateway API
- **Gateway API** - Next-generation routing: GatewayClass, Gateway, HTTPRoute, GRPCRoute, TLSRoute
- Gateway API provides better role separation (infra admin vs app developer)

### Network Policies
- Control pod-to-pod traffic at L3/L4
- Default deny ingress/egress as baseline, then whitelist
- Requires a CNI that supports Network Policies (Calico, Cilium)
- Policies are additive (union of all matching policies)
- Use namespace selectors for cross-namespace rules

### DNS
- CoreDNS provides cluster DNS
- Services: `<service>.<namespace>.svc.cluster.local`
- Pods: `<pod-ip>.<namespace>.pod.cluster.local`
- Use `dnsPolicy` and `dnsConfig` for custom DNS settings

## Configuration

### ConfigMaps
- Store non-sensitive configuration data
- Mount as files or inject as environment variables
- Changes to mounted ConfigMaps propagate automatically (with delay)
- Immutable ConfigMaps for performance at scale

### Secrets
- Store sensitive data (passwords, tokens, certificates)
- Base64-encoded (not encrypted by default); enable encryption at rest
- Types: Opaque, TLS, docker-registry, service-account-token
- Use External Secrets Operator for AWS Secrets Manager integration

## Storage

### Persistent Volumes (PV) and Claims (PVC)
- PV = cluster-level storage resource; PVC = namespace-level request
- Use StorageClasses for dynamic provisioning
- Access modes: ReadWriteOnce, ReadOnlyMany, ReadWriteMany
- Reclaim policies: Retain (manual), Delete (automatic)

### Storage Classes
- Define different tiers (gp3, io2, etc.)
- Set `volumeBindingMode: WaitForFirstConsumer` for topology-aware provisioning
- Configure `allowVolumeExpansion: true` for resize support

### CSI (Container Storage Interface)
- Standard interface for storage providers
- EBS CSI Driver for AWS EBS volumes
- Use Volume Snapshots for backup/restore

## Security

### RBAC (Role-Based Access Control)
- **Role/ClusterRole** - Define permissions (verbs on resources)
- **RoleBinding/ClusterRoleBinding** - Bind roles to users/groups/service accounts
- Use namespace-scoped Roles for application workloads
- ClusterRoles for cluster-wide resources (nodes, namespaces, CRDs)
- Aggregate ClusterRoles for composable permissions

### Pod Security
- **Pod Security Standards**: Privileged, Baseline, Restricted
- Enforce at namespace level with `pod-security.kubernetes.io/enforce` label
- Run containers as non-root (`runAsNonRoot: true`)
- Drop all capabilities, add only what's needed
- Read-only root filesystem where possible
- Use `securityContext` at pod and container level

### Service Accounts
- Every pod runs with a service account
- Disable auto-mounting of service account tokens when not needed
- Use dedicated service accounts per workload
- IRSA (EKS) binds Kubernetes SAs to AWS IAM roles

## Scheduling and Node Management

### Node Selection
- `nodeSelector` - Simple key-value matching
- `nodeAffinity` - Flexible rules (required/preferred, operators)
- `podAffinity/podAntiAffinity` - Co-locate or spread pods relative to other pods
- `topologySpreadConstraints` - Distribute pods evenly across zones/nodes
- `tolerations` - Allow scheduling on tainted nodes

### Taints and Tolerations
- Taint nodes to repel pods; tolerate to override
- Effects: NoSchedule, PreferNoSchedule, NoExecute
- Use for dedicated node pools, GPU nodes, critical system pods

### Priority and Preemption
- `PriorityClass` for workload importance
- Higher priority pods can preempt lower priority ones
- Set `system-cluster-critical` and `system-node-critical` for essential components

## Observability

### Health Checks
- **livenessProbe** - Restart container if unhealthy
- **readinessProbe** - Remove from Service endpoints if not ready
- **startupProbe** - Delay liveness/readiness checks for slow-starting apps
- Probe types: HTTP GET, TCP socket, exec command, gRPC

### Logging
- Application logs to stdout/stderr (collected by node agent)
- Use structured logging (JSON) for easier parsing
- Centralize with Datadog, Fluentd, or CloudWatch

### Metrics
- Metrics Server for resource metrics (CPU, memory)
- Prometheus / Datadog for custom metrics
- Use `kubectl top pods/nodes` for quick resource checks

## Debugging and Troubleshooting

### Common Commands
- `kubectl get` - List resources
- `kubectl describe` - Detailed resource info and events
- `kubectl logs` - Container logs (`-p` for previous container, `-f` for follow)
- `kubectl exec` - Run commands in a container
- `kubectl port-forward` - Local port forwarding to a pod/service
- `kubectl top` - Resource usage
- `kubectl events` - Cluster events

### Debugging Patterns
- Pod stuck in `Pending` - Check resource constraints, node capacity, taints, affinity
- Pod in `CrashLoopBackOff` - Check logs, liveness probes, resource limits (OOMKilled)
- Pod in `ImagePullBackOff` - Check image name, tag, registry credentials
- Service not reachable - Check selectors, endpoints, Network Policies
- Use `kubectl get events --sort-by=.metadata.creationTimestamp` for timeline

### Resource Status Fields
- `.status.conditions` - Health conditions for most resources
- `.status.phase` - High-level lifecycle phase
- Use `-o wide` for additional columns
- Use `-o yaml` or `-o json` for full resource details
- Use `jsonpath` or `jq` for targeted field extraction

## Operations

### Namespace Management
- Isolate workloads by team, environment, or function
- Apply ResourceQuotas and LimitRanges per namespace
- Use NetworkPolicies for namespace-level network isolation
- Standard namespaces: `default`, `kube-system`, `kube-public`, `kube-node-lease`

### Upgrades
- Upgrade one minor version at a time
- Review deprecation guides before upgrading
- Test in non-production first
- Upgrade control plane, then nodes, then add-ons
- Watch for API removals (`kubectl convert` for manifest migration)

### Backup and Restore
- Use Velero for cluster-level backup and restore
- Back up etcd for disaster recovery
- PVC snapshots via CSI for stateful workload data

## Reference Documentation

### Core
- **Kubernetes Docs Home**: https://kubernetes.io/docs/home/
- **Concepts**: https://kubernetes.io/docs/concepts/
- **Tasks**: https://kubernetes.io/docs/tasks/
- **Tutorials**: https://kubernetes.io/docs/tutorials/
- **API Reference (v1.35)**: https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.35/

### Best Practices
- **Best Practices Overview**: https://kubernetes.io/docs/setup/best-practices/
- **Production Environment**: https://kubernetes.io/docs/setup/production-environment/
- **Large Clusters**: https://kubernetes.io/docs/setup/best-practices/cluster-large/
- **Configuration Best Practices**: https://kubernetes.io/docs/concepts/configuration/overview/

### Security
- **Pod Security Standards**: https://kubernetes.io/docs/concepts/security/pod-security-standards/
- **RBAC**: https://kubernetes.io/docs/reference/access-authn-authz/rbac/
- **Network Policies**: https://kubernetes.io/docs/concepts/services-networking/network-policies/
- **Secrets**: https://kubernetes.io/docs/concepts/configuration/secret/

### Networking
- **Services**: https://kubernetes.io/docs/concepts/services-networking/service/
- **Ingress**: https://kubernetes.io/docs/concepts/services-networking/ingress/
- **Gateway API**: https://gateway-api.sigs.k8s.io/
- **DNS for Services and Pods**: https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/

### Storage
- **Persistent Volumes**: https://kubernetes.io/docs/concepts/storage/persistent-volumes/
- **Storage Classes**: https://kubernetes.io/docs/concepts/storage/storage-classes/
- **Volume Snapshots**: https://kubernetes.io/docs/concepts/storage/volume-snapshots/

### kubectl
- **kubectl Reference**: https://kubernetes.io/docs/reference/kubectl/
- **kubectl Cheat Sheet**: https://kubernetes.io/docs/reference/kubectl/cheatsheet/
- **kubectl Commands**: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands

### Troubleshooting
- **Debug Applications**: https://kubernetes.io/docs/tasks/debug/debug-application/
- **Debug Clusters**: https://kubernetes.io/docs/tasks/debug/debug-cluster/
- **Troubleshoot kubectl**: https://kubernetes.io/docs/tasks/debug/debug-cluster/troubleshoot-kubectl/

### Ecosystem
- **Helm**: https://helm.sh/docs/
- **Kustomize**: https://kustomize.io/
- **ArgoCD**: https://argo-cd.readthedocs.io/
- **Argo Rollouts**: https://argoproj.github.io/argo-rollouts/
