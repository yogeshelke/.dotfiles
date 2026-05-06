---
name: datadog
description: >-
  Datadog decision system for monitoring and observability. Use for agent deployment,
  metrics strategy, log management, APM setup, monitors/alerts, and Kubernetes integration.
  Do NOT use for AWS CloudWatch (use aws skill) unless comparing Datadog vs CloudWatch.
metadata:
  author: SHELYOG
  version: 3.0.0
  category: observability
  updated: 2026-05-05
  mcp-server: datadog
---
# Datadog Decision Engine

Decision rules for monitoring and observability. Not reference material.

- AWS CloudWatch → `skills/aws/` (fallback when Datadog unavailable)
- K8s observability concepts → `skills/kubernetes/`
- This file answers: **what to monitor, how to alert, and how to instrument**

## Interaction Model
- This skill defines **monitoring strategy, alerting, and instrumentation** only
- What infrastructure to build → `aws` skill
- Kubernetes probes and resource limits → `kubernetes` skill
- Datadog Helm chart deployment → `helm` skill
- CI/CD pipeline monitoring → `github` skill
- Cost of monitoring infrastructure → `aws` skill (cost section)

---

## Decision Entry Points

| Task | Read sections |
|---|---|
| Deploy agent to EKS | AGENT_DEPLOYMENT |
| Add custom metrics | METRICS |
| Set up application logging | LOGS |
| Enable distributed tracing | APM |
| Create alerts/monitors | MONITORS |
| Build dashboards | DASHBOARDS |
| EKS-specific monitoring | KUBERNETES |

---

<!-- CORE_DECISIONS: Read this section for design choices and constraints -->

## Cross-Cutting Rules

| Decision | Domains | Rule |
|---|---|---|
| Unified Service Tagging | All | Every resource tagged: `env`, `service`, `version` |
| No unfiltered log collection | Logs + Cost | Filter at source; don't index everything |
| Monitor all critical paths | Monitors + APM | Every user-facing endpoint has a monitor |
| Trace sampling for cost | APM + Cost | Sample at 100% in non-prod, rule-based in prod |
| Namespace metrics | Metrics + All | Prefix custom metrics: `<service>.<metric>` |

---

<!-- REFERENCE: Detailed implementation patterns below. Read only when you need specific configs. -->

## [AGENT_DEPLOYMENT]

**Default**: Helm chart (`datadog/datadog`) on EKS

**Essential config** (values.yaml):
```yaml
datadog:
  apiKey: <from-secret>
  site: datadoghq.eu        # or datadoghq.com
  clusterName: <cluster>
  logs:
    enabled: true
    containerCollectAll: true
  apm:
    portEnabled: true
  processAgent:
    enabled: true
clusterAgent:
  enabled: true
  metricsProvider:
    enabled: true           # HPA with Datadog metrics
```

**Decisions**:
- **Cluster Agent**: Always enable (reduces API server load, enables HPA)
- **Logs**: Enable `containerCollectAll` but use exclusion rules for noisy namespaces
- **APM**: Enable port (8126) — apps connect via environment variable
- **Process Agent**: Enable for live process monitoring

---

## [METRICS]

**Custom metric strategy**:
- Use DogStatsD (port 8125) for application metrics
- Prefix: `<service_name>.<metric_name>` (e.g., `payment.transactions.count`)
- Types: counter (cumulative), gauge (point-in-time), histogram (distribution)

**Tagging (critical)**:
- **Unified Service Tags**: `env`, `service`, `version` on ALL resources
- Additional: `team`, `component`, `cluster`
- Tags enable: filtering, grouping, correlation across metrics/logs/traces

**Infrastructure metrics** (auto-collected):
- CPU, memory, disk, network (node and pod level)
- EKS: node groups, pod counts, container restarts
- Custom: expose `/metrics` endpoint for Prometheus-format scraping

---

## [LOGS]

**Collection strategy**:
- Collect from stdout/stderr via Datadog Agent (containerCollectAll)
- **Exclude** noisy/low-value namespaces (kube-system debug logs)
- Use log `source` and `service` tags for pipeline routing

**Processing**:
- Log Pipelines: parse, enrich, remap attributes
- Use Grok parser for structured extraction
- Remap to standard attributes (`http.method`, `http.status_code`, `duration`)

**Retention decisions**:
- **Hot (indexed)**: 15-30 days for searchable logs
- **Archive to S3**: All logs for compliance (rehydrate when needed)
- **Exclusion filters**: Drop debug/health-check logs before indexing (cost control)

**Format**: JSON structured logging from applications (not plain text)

---

## [APM]

**When to instrument**:
- All user-facing services (API, web)
- Internal services on critical paths
- Skip: batch jobs, cron (unless latency matters)

**Setup**:
- Install language-specific tracing library (dd-trace)
- Set env vars: `DD_AGENT_HOST`, `DD_SERVICE`, `DD_ENV`, `DD_VERSION`
- Auto-instrumentation available for common frameworks

**Trace sampling**:
- **Non-prod**: 100% (full visibility, low volume)
- **Prod**: Rule-based (100% for errors, 10-50% for normal traffic)
- **High volume**: Head-based sampling at agent level

**Service Map**: Automatically built from traces — shows dependencies and error propagation

---

## [MONITORS]

**Monitor type selection**:
- **Metric monitor** → Threshold on a metric (CPU > 80%, error rate > 5%)
- **Log monitor** → Alert on log pattern (ERROR count in 5min window)
- **APM monitor** → Latency or error rate on a service/endpoint
- **Composite monitor** → AND/OR multiple conditions
- **Anomaly monitor** → ML-based deviation from baseline

**Alert design rules**:
- **Evaluation window**: 5min minimum (avoid flapping on spikes)
- **Recovery threshold**: Set explicitly (not just "when condition clears")
- **Notification routing**: PagerDuty for critical, Slack for warning
- **No-data handling**: Alert if no data for >10min (indicates collection failure)

**What to monitor** (minimum set):
- Error rate per service (>5% = warning, >10% = critical)
- P95 latency per endpoint (2x baseline = warning)
- Pod restarts per deployment (>3 in 10min = warning)
- Node CPU/memory utilization (>85% = warning)
- Deployment rollout health (stuck for >10min)

---

## [DASHBOARDS]

**Design rules**:
- Template variables: `env`, `service`, `cluster` (user filters at top)
- Golden signals at top: traffic, errors, latency, saturation
- Drill-down sections below: per-service, per-endpoint

**Widget selection**:
- **Timeseries**: Trends over time (default for most metrics)
- **Query Value**: Single current number (SLO %, error count)
- **Top List**: Highest consumers (top services by error rate)
- **Heatmap**: Distribution visualization (latency buckets)
- **Service Map**: Dependency visualization

**SLO dashboards**: Track SLOs with burn rate alerts (budget consumption rate)

---

## [KUBERNETES]

**EKS integration**:
- Cluster Agent handles: service discovery, external metrics, admission controller
- Node Agent handles: pod metrics, logs, traces, process monitoring
- Admission Controller: auto-injects DD_AGENT_HOST and tracing env vars

**Pod-level tagging** (via annotations):
```yaml
annotations:
  ad.datadoghq.com/tags: '{"team":"platform","component":"api"}'
```

**External metrics (HPA)**:
- Cluster Agent serves custom Datadog metrics to HPA
- Scale on: request rate, queue depth, custom business metrics
- Faster than CloudWatch metrics (15s scrape interval)

**Cluster checks**: Monitor cluster-level resources (endpoints, services) from Cluster Agent

---

## Anti-Patterns (Never Do)

| Anti-Pattern | Why It's Wrong | Do This Instead |
|---|---|---|
| No unified service tagging | Can't correlate metrics/logs/traces | Always tag: env, service, version |
| Collect ALL logs unfiltered | Cost explosion, noise | Exclude debug, health checks; archive rest |
| No monitors on critical paths | Silent failures | Monitor error rate + latency per service |
| Overly sensitive alerts | Alert fatigue, team ignores alerts | 5min+ window, explicit recovery threshold |
| Custom metrics without namespace | Collision, unclear ownership | `<service>.<metric>` naming |
| No log pipelines | Raw unstructured logs, slow queries | Parse and remap to standard attributes |
| 100% trace sampling in prod | Cost, storage explosion | Rule-based: 100% errors, sample normal |
| No SLOs defined | No objective measure of reliability | SLOs for key services with burn rate alerts |

---

## Troubleshooting Decision Trees

**Metrics not appearing?**
1. Agent running on node? → Check DaemonSet pods in datadog namespace
2. Correct API key/site? → Verify in agent status (`agent status`)
3. Custom metric being sent? → Check DogStatsD port (8125) connectivity
4. Tag filtering? → Check if dashboard has restrictive tag filters

**Logs not collected?**
1. Logs enabled in Helm values? → `datadog.logs.enabled: true`
2. Container writing to stdout? → Not writing to file (agent collects stdout only)
3. Excluded by filter? → Check exclusion rules in agent config
4. Pipeline processing error? → Check pipeline status in DD UI

**Traces missing?**
1. APM port enabled? → `datadog.apm.portEnabled: true`
2. App has DD_AGENT_HOST set? → Should point to node agent (downward API)
3. Tracing library initialized? → Check app startup logs
4. Sampling dropping traces? → Check sampling rules

**Alert flapping?**
1. Evaluation window too short? → Increase to 5min+
2. Threshold too tight? → Add buffer (alert at 80% not 75%)
3. Recovery threshold missing? → Set explicit recovery
4. Data gaps causing no-data alerts? → Adjust no-data timeout

---

## Reference Documentation

- **Datadog Docs**: https://docs.datadoghq.com/
- **Agent (Kubernetes)**: https://docs.datadoghq.com/containers/kubernetes/
- **APM**: https://docs.datadoghq.com/tracing/
- **Log Management**: https://docs.datadoghq.com/logs/
- **Monitors**: https://docs.datadoghq.com/monitors/
- **Dashboards**: https://docs.datadoghq.com/dashboards/
- **SLOs**: https://docs.datadoghq.com/service_level_objectives/
- **Unified Service Tagging**: https://docs.datadoghq.com/getting_started/tagging/unified_service_tagging/
- **Helm Chart**: https://github.com/DataDog/helm-charts
