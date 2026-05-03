# Kubernetes Deployment Checklist

Use this command template before deploying any workload to EKS.

## Pre-Deployment

### Application Readiness
- [ ] Container image built, scanned, and pushed to ECR
- [ ] Image tagged with git SHA (not `latest`)
- [ ] Health check endpoints implemented (liveness, readiness, startup)
- [ ] Graceful shutdown handling configured (`SIGTERM`)
- [ ] Structured logging to stdout/stderr (JSON preferred)

### Kubernetes Manifests
- [ ] Resource `requests` and `limits` set on all containers
- [ ] Liveness, readiness, and startup probes configured
- [ ] `topologySpreadConstraints` for AZ distribution
- [ ] `PodDisruptionBudget` set (minAvailable or maxUnavailable)
- [ ] `terminationGracePeriodSeconds` matches shutdown time
- [ ] `securityContext`: non-root, read-only rootfs, capabilities dropped
- [ ] Dedicated ServiceAccount with IRSA annotation
- [ ] ConfigMaps and Secrets referenced (not inline)

### Datadog Observability
- [ ] Labels set: `tags.datadoghq.com/env`, `service`, `version`
- [ ] APM admission controller annotation or manual tracer config
- [ ] Log annotations for source and multi-line parsing
- [ ] Custom metrics emitted via DogStatsD if needed

### Networking
- [ ] Service type correct (ClusterIP, LoadBalancer)
- [ ] Ingress/HTTPRoute configured for external access
- [ ] Network Policy allows required traffic, blocks everything else
- [ ] TLS certificate provisioned (ACM or cert-manager)

## Deployment

### Execution
```bash
# Verify current state
kubectl get deployments -n <namespace>
kubectl get pods -n <namespace> -o wide

# After deploy (via Helm/ArgoCD), monitor rollout
kubectl rollout status deployment/<name> -n <namespace> --timeout=300s
kubectl get events -n <namespace> --sort-by=.metadata.creationTimestamp | tail -20
```

### Validation
- [ ] All pods in `Running` state with `Ready` condition
- [ ] No `CrashLoopBackOff` or `ImagePullBackOff`
- [ ] Endpoints populated for the Service
- [ ] Health check endpoints returning 200
- [ ] Logs flowing to Datadog
- [ ] Metrics visible in Datadog dashboard
- [ ] APM traces appearing for the service

## Post-Deployment
- [ ] Monitor error rate and latency for 15-30 minutes
- [ ] Verify SLO burn rate is nominal
- [ ] Check Datadog monitors for new alerts
- [ ] Update Service Catalog entry if needed
- [ ] Document the deployment in the team channel

## Rollback
```bash
# Helm rollback
helm rollback <release> <revision> -n <namespace>

# Or redeploy previous image tag
# Update image tag in values and re-deploy via CI/CD
```
