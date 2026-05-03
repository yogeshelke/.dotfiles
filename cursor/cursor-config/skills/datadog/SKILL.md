---
name: datadog
description: >-
  Datadog monitoring and observability reference for infrastructure, APM, and log management. 
  Use when user mentions "Datadog", "monitoring", "observability", "metrics", "logs", "tracing", 
  "APM", "dashboards", "monitors", "alerts", "SLOs", "synthetic tests", or asks about application 
  performance monitoring, infrastructure monitoring, or log analysis.
metadata:
  author: SHELYOG
  version: 2.0.0
  category: observability
  updated: 2026-05-03
  mcp-server: datadog
---
# Datadog Comprehensive Reference

Use this skill when working with Datadog monitoring, APM, logging, dashboards, alerts, or Kubernetes observability.

## Architecture

### Core Components
- **Datadog Agent** - Collects metrics, traces, and logs from hosts and containers
- **Cluster Agent** - Kubernetes-specific; handles API server communication, external metrics, admission controller
- **DogStatsD** - StatsD-compatible daemon for custom metrics (port 8125)
- **Trace Agent** - Receives APM traces from instrumented applications (port 8126)

### Data Flow
```
App → DD Agent (node) → Datadog Backend → Dashboards/Monitors/SLOs
App → Trace Agent → APM → Service Map / Traces
App → Log Agent → Log Management → Log Analytics / Pipelines
```

## Agent Deployment

### Kubernetes (Helm)
```yaml
# values.yaml for datadog/datadog Helm chart
datadog:
  apiKey: <DD_API_KEY>          # or use existingSecret
  appKey: <DD_APP_KEY>
  site: datadoghq.com           # or datadoghq.eu, us3.datadoghq.com, etc.
  clusterName: my-cluster
  logs:
    enabled: true
    containerCollectAll: true
  apm:
    portEnabled: true
  processAgent:
    enabled: true
    processCollection: true
  networkMonitoring:
    enabled: true
clusterAgent:
  enabled: true
  metricsProvider:
    enabled: true               # External metrics for HPA
  admissionController:
    enabled: true               # Auto-inject DD_AGENT_HOST, trace libraries
```

### Agent Configuration
| Setting | Purpose |
|---------|---------|
| `DD_API_KEY` | Authentication to Datadog backend |
| `DD_SITE` | Datadog region endpoint |
| `DD_LOGS_ENABLED` | Enable log collection |
| `DD_APM_ENABLED` | Enable trace collection |
| `DD_DOGSTATSD_NON_LOCAL_TRAFFIC` | Accept DogStatsD from other containers |
| `DD_CLUSTER_NAME` | Tag all data with cluster name |
| `DD_ENV`, `DD_SERVICE`, `DD_VERSION` | Unified service tagging |

## Unified Service Tagging

Apply three tags consistently across metrics, traces, and logs:

| Tag | Purpose | Where to set |
|-----|---------|-------------|
| `env` | Environment (prod, staging, dev) | Pod labels, DD_ENV |
| `service` | Application name | Pod labels, DD_SERVICE |
| `version` | Application version | Pod labels, DD_VERSION |

```yaml
# Kubernetes labels for unified tagging
metadata:
  labels:
    tags.datadoghq.com/env: production
    tags.datadoghq.com/service: my-app
    tags.datadoghq.com/version: "1.2.3"
```

## Infrastructure Monitoring

### Metrics
- **System metrics** - CPU, memory, disk, network (auto-collected by agent)
- **Integration metrics** - 800+ integrations (AWS, Kubernetes, databases, etc.)
- **Custom metrics** - DogStatsD, agent checks, or API submission
- **Metric types**: count, rate, gauge, histogram, distribution, set

### Tags
- Tags are key:value pairs attached to all telemetry
- Inherited from host, container labels, cloud provider
- Use for filtering, grouping, and scoping in dashboards and monitors
- Reserved tags: `host`, `device`, `source`, `service`, `env`, `version`

### Live Processes & Containers
- Real-time visibility into processes and containers
- Container map for resource usage visualization
- Orchestrator Explorer for Kubernetes resource visibility

## APM (Application Performance Monitoring)

### Tracing Setup
1. Deploy Datadog Agent with APM enabled
2. Install language-specific tracing library (`dd-trace`)
3. Configure via environment variables or code

### Supported Languages
| Language | Library | Auto-instrumentation |
|----------|---------|---------------------|
| Python | `ddtrace` | Yes (patching) |
| Java | `dd-java-agent` | Yes (javaagent) |
| Node.js | `dd-trace` | Yes (require hook) |
| Go | `dd-trace-go` | Manual |
| .NET | `dd-trace-dotnet` | Yes (auto) |
| Ruby | `ddtrace` | Yes (auto) |

### Key APM Features
- **Service Map** - Visual topology of service dependencies
- **Trace Search** - Query and filter individual traces
- **Service Catalog** - Ownership, docs, and metadata per service
- **Error Tracking** - Group and track application errors
- **Continuous Profiler** - CPU and memory profiling in production
- **Data Streams Monitoring** - End-to-end pipeline latency (Kafka, SQS, etc.)

### Trace Configuration
```yaml
# Kubernetes pod annotations for APM
annotations:
  admission.datadoghq.com/enabled: "true"    # Admission controller injects tracer
  # Or set manually:
  # DD_AGENT_HOST: <node-agent-service>
  # DD_TRACE_AGENT_PORT: "8126"
```

## Log Management

### Log Collection
- Agent collects from container stdout/stderr automatically
- File-based collection via `logs` agent config
- Supports multi-line aggregation and log parsing

### Log Pipeline
```
Source → Parsing (Grok) → Enrichment (Remapper, GeoIP) → Filtering → Indexing
```

### Log Configuration (Kubernetes)
```yaml
# Pod annotations for log configuration
annotations:
  ad.datadoghq.com/my-container.logs: |
    [{
      "source": "java",
      "service": "my-app",
      "log_processing_rules": [{
        "type": "multi_line",
        "name": "java_stacktrace",
        "pattern": "\\d{4}-\\d{2}-\\d{2}"
      }]
    }]
```

### Log Patterns
- **Indexes** - Route logs to different retention/cost tiers
- **Exclusion Filters** - Drop noisy logs before indexing
- **Archives** - Long-term storage in S3/GCS/Azure Blob
- **Rehydration** - Re-index archived logs for investigation
- **Log-based Metrics** - Generate metrics from log patterns

## Monitors (Alerting)

### Monitor Types
| Type | Use Case |
|------|----------|
| Metric | Threshold or anomaly on any metric |
| Log | Alert on log patterns or counts |
| APM | Latency, error rate, throughput on services |
| Composite | Combine multiple monitors with boolean logic |
| SLO | Alert when SLO burn rate is too high |
| Process | Process up/down checks |
| Network | TCP/HTTP checks |
| Event | Alert on specific events |
| Forecast | Predict future metric values |
| Outlier | Detect outlier behavior in groups |
| Anomaly | ML-based anomaly detection |

### Monitor Best Practices
- Use `{{threshold}}` and `{{value}}` in messages for context
- Set `notify_no_data: true` for critical checks
- Use `renotify_interval` to re-alert on unresolved issues
- Tag monitors with `team`, `service`, `env` for routing
- Use `@pagerduty-<service>`, `@slack-<channel>`, `@opsgenie-<team>` for notifications
- Set appropriate evaluation windows (avoid 1-minute windows for noisy metrics)

### Monitor Terraform Example
```hcl
resource "datadog_monitor" "high_cpu" {
  name    = "High CPU on {{host.name}}"
  type    = "metric alert"
  query   = "avg(last_5m):avg:system.cpu.user{env:production} by {host} > 90"
  message = <<-EOF
    CPU usage above 90% on {{host.name}}.
    @slack-platform-alerts @pagerduty-infra
  EOF

  monitor_thresholds {
    critical = 90
    warning  = 80
  }

  notify_no_data    = true
  no_data_timeframe = 10
  renotify_interval = 30

  tags = ["env:production", "team:platform"]
}
```

## SLOs (Service Level Objectives)

### SLO Types
| Type | Based On |
|------|----------|
| Metric-based | Custom metric query (good events / total events) |
| Monitor-based | Percentage of time a monitor is in OK state |
| Time Slice | Percentage of time slices meeting criteria |

### SLO Best Practices
- Define SLIs first (latency, error rate, availability)
- Set targets below 100% (e.g., 99.9%, 99.95%)
- Use error budgets to balance reliability and velocity
- Alert on burn rate, not raw SLO breach
- Review SLOs monthly with stakeholders

### SLO Terraform Example
```hcl
resource "datadog_service_level_objective" "api_availability" {
  name = "API Availability"
  type = "metric"

  query {
    numerator   = "sum:http.requests.success{service:api-gateway}.as_count()"
    denominator = "sum:http.requests.total{service:api-gateway}.as_count()"
  }

  thresholds {
    timeframe = "30d"
    target    = 99.9
    warning   = 99.95
  }

  tags = ["service:api-gateway", "team:platform"]
}
```

## Dashboards

### Dashboard Types
- **Screenboard** - Free-form layout; mixed widget sizes
- **Timeboard** - Synchronized time across all widgets; grid layout

### Common Widgets
| Widget | Purpose |
|--------|---------|
| Timeseries | Metric trends over time |
| Query Value | Single current value |
| Top List | Ranked list by metric |
| Table | Tabular metric/log data |
| Heatmap | Distribution over time |
| SLO | SLO status and error budget |
| Service Map | APM service topology |
| Log Stream | Real-time log feed |
| Alert Graph | Monitor status visualization |

### Dashboard Best Practices
- Use template variables for `env`, `service`, `cluster`
- Group related widgets with headings
- Include SLO widgets alongside operational metrics
- Link to runbooks from widget annotations
- Use `$env.value` and `$service.value` in queries for dynamic filtering

## Kubernetes Integration

### What Datadog Collects
- **Cluster**: Node count, pod count, namespace metrics
- **Nodes**: CPU, memory, disk, network per node
- **Pods**: CPU, memory, restarts, status per pod
- **Containers**: Resource usage, OOMKills, throttling
- **Kubernetes Events**: Warning and Normal events
- **Orchestrator Explorer**: Deployments, ReplicaSets, Services, etc.

### Autodiscovery
Automatically detects and configures integrations for containerized services using pod annotations:

```yaml
annotations:
  ad.datadoghq.com/my-container.check_names: '["nginx"]'
  ad.datadoghq.com/my-container.init_configs: '[{}]'
  ad.datadoghq.com/my-container.instances: '[{"nginx_status_url": "http://%%host%%:%%port%%/status"}]'
```

### HPA with Datadog Metrics
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  metrics:
    - type: External
      external:
        metric:
          name: datadogmetric@<namespace>:<datadogmetric-name>
        target:
          type: Value
          value: "10"
```

## Synthetics

### Test Types
| Type | Purpose |
|------|---------|
| API Test | HTTP, SSL, DNS, TCP, WebSocket, gRPC checks |
| Browser Test | Multi-step browser interactions |
| Multistep API | Chained API requests |

### Use Cases
- Uptime monitoring from global locations
- SLA validation for external endpoints
- Critical user journey testing
- SSL certificate expiry monitoring
- API contract validation

## Terraform Provider

### Provider Configuration
```hcl
terraform {
  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 3.0"
    }
  }
}

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  api_url = "https://api.datadoghq.com/"   # adjust for region
}
```

### Key Terraform Resources
| Resource | Purpose |
|----------|---------|
| `datadog_monitor` | Alerting rules |
| `datadog_dashboard` | Dashboard definitions |
| `datadog_service_level_objective` | SLOs |
| `datadog_synthetics_test` | Synthetic monitoring |
| `datadog_downtime` | Scheduled downtimes |
| `datadog_logs_index` | Log index configuration |
| `datadog_logs_pipeline` | Log processing pipelines |
| `datadog_role` | RBAC roles |
| `datadog_integration_aws` | AWS account integration |

## Troubleshooting

### Agent Issues
- Agent not reporting → Check `DD_API_KEY`, network connectivity, `datadog-agent status`
- Missing metrics → Verify integration config, check `datadog-agent check <integration>`
- High agent resource usage → Tune `max_returned_metrics`, reduce check frequency

### APM Issues
- Traces not appearing → Check `DD_APM_ENABLED`, verify trace agent port connectivity
- Missing spans → Verify library instrumentation, check sampling rules
- High trace volume → Configure sampling (`DD_TRACE_SAMPLE_RATE`, priority sampling)

### Log Issues
- Logs not collected → Verify `DD_LOGS_ENABLED`, container annotations, file permissions
- Logs not parsed → Check pipeline processors, grok patterns
- High log volume/cost → Use exclusion filters, adjust index retention

### Kubernetes Issues
- No cluster metrics → Check Cluster Agent deployment, RBAC permissions
- Missing pod metrics → Verify DaemonSet scheduling, node taints/tolerations
- Autodiscovery not working → Check annotation format, container names

## Reference Documentation

### Core
- **Datadog Docs**: https://docs.datadoghq.com/
- **API Reference**: https://docs.datadoghq.com/api/latest/
- **Integrations**: https://docs.datadoghq.com/integrations/

### Agent
- **Agent Docs**: https://docs.datadoghq.com/agent/
- **Kubernetes Agent**: https://docs.datadoghq.com/containers/kubernetes/
- **Cluster Agent**: https://docs.datadoghq.com/containers/cluster_agent/
- **Helm Chart**: https://github.com/DataDog/helm-charts

### APM
- **APM Docs**: https://docs.datadoghq.com/tracing/
- **Service Catalog**: https://docs.datadoghq.com/service_catalog/
- **Continuous Profiler**: https://docs.datadoghq.com/profiler/

### Logs
- **Log Management**: https://docs.datadoghq.com/logs/
- **Log Pipelines**: https://docs.datadoghq.com/logs/log_configuration/pipelines/
- **Log Archives**: https://docs.datadoghq.com/logs/log_configuration/archives/

### Monitoring
- **Monitors**: https://docs.datadoghq.com/monitors/
- **SLOs**: https://docs.datadoghq.com/service_management/service_level_objectives/
- **Dashboards**: https://docs.datadoghq.com/dashboards/
- **Synthetics**: https://docs.datadoghq.com/synthetics/

### Terraform
- **Datadog Provider**: https://registry.terraform.io/providers/DataDog/datadog/latest/docs
