---
name: msk
description: >-
  Amazon MSK and Kafka decision system. Use for MSK cluster configuration, Kafka ACL
  management, client authentication (IAM SASL, mTLS), Schema Registry patterns, and
  mongey/kafka Terraform provider usage. Do NOT use for general AWS networking (use aws skill)
  or Kubernetes workload deployment (use kubernetes skill).
metadata:
  author: SHELYOG
  version: 1.0.0
  category: infrastructure
  updated: 2026-05-06
---
# MSK & Kafka Decision Engine

Decision rules for Amazon MSK clusters and Kafka ecosystem management.

- AWS networking/VPC → `skills/aws/`
- Terraform HCL patterns → `skills/terraform/`
- Kubernetes consumers/producers → `skills/kubernetes/`
- Monitoring MSK metrics → `skills/datadog/`
- This file answers: **how to configure MSK, manage Kafka ACLs, and handle schema management**

## Interaction Model
- This skill defines **MSK cluster config, Kafka access control, and Schema Registry** patterns
- VPC/subnet placement → `aws` skill
- Helm-deployed Kafka operators → `helm` skill
- Datadog Kafka monitors → `datadog` skill

---

## Decision Entry Points

| Task | Read sections |
|---|---|
| New MSK cluster | CLUSTER_CONFIG + NETWORKING + SECURITY |
| Kafka ACL management | KAFKA_PROVIDER + ACLS |
| Client authentication | SECURITY |
| Schema Registry setup | SCHEMA_REGISTRY |
| MSK monitoring | MONITORING |
| Topic management | KAFKA_PROVIDER + TOPICS |
| MSK module configuration | TERRAFORM_MODULES |

---

<!-- CORE_DECISIONS: Read this section for design choices and constraints -->

## Cross-Cutting Rules

| Decision | Rule |
|---|---|
| Authentication | IAM SASL (preferred) for AWS-native clients; mTLS for cross-account/external |
| Encryption | TLS in-transit mandatory; KMS at-rest mandatory for production |
| Authorization model | **IAM auth → IAM policies for authorization (Kafka ACLs are IGNORED)**; mTLS/SCRAM → Kafka ACLs for authorization |
| Networking | Private subnets only; no public endpoints in production |
| Versioning | Pin Kafka version explicitly; upgrade via blue-green or rolling |
| Default access | MSK defaults `allow.everyone.if.no.acl.found=true` — always define explicit ACLs OR use IAM auth; never rely on default open behavior |

### CRITICAL: IAM vs Kafka ACL Authorization

**AWS explicitly states: Kafka ACLs do not apply when IAM authentication is used.**

| Auth Method | Authorization Method | Kafka ACLs Apply? |
|---|---|---|
| IAM SASL | IAM policies (resource-based + identity-based) | **NO — ACLs are ignored** |
| mTLS | Kafka ACLs (via `mongey/kafka` provider) | **YES** |
| SASL/SCRAM | Kafka ACLs (via `mongey/kafka` provider) | **YES** |

**Decision rule:**
- If using IAM SASL: authorization MUST be done via IAM policies attached to the client's IAM role. Do NOT create Kafka ACL resources — they have no effect.
- If Kafka ACLs are required for fine-grained topic/group control: use mTLS or SCRAM authentication instead of IAM.
- Never mix: IAM auth + `kafka_acl` resources = silent misconfiguration (ACLs exist but are never evaluated).

---

<!-- REFERENCE: Detailed implementation patterns below. Read only when you need specific configs. -->

## CLUSTER_CONFIG

### MSK Terraform Module Pattern

```hcl
module "msk" {
  source = "git::https://github.com/org/ae_terraform_modules.git//aws/msk?ref=vX.Y.Z"

  cluster_name    = "ae-${var.environment}-msk"
  kafka_version   = "3.6.0"
  instance_type   = var.msk_instance_type
  number_of_nodes = var.msk_node_count
  ebs_volume_size = var.msk_ebs_size

  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.msk.id]

  configuration_info = {
    arn      = aws_msk_configuration.this.arn
    revision = aws_msk_configuration.this.latest_revision
  }

  encryption_in_transit = "TLS"
  encryption_at_rest_kms_key_arn = var.kms_key_arn

  tags = local.common_tags
}
```

### Instance Type Selection

```
IF dev/test              → kafka.t3.small
IF standard production   → kafka.m5.large
IF high throughput       → kafka.m5.2xlarge
IF storage-intensive     → kafka.m5.4xlarge
IF cost-sensitive prod   → kafka.m5.large + tiered storage (if available)
```

### Configuration Properties

```
IF production:
  auto.create.topics.enable     = false        # NEVER true in production
  default.replication.factor    = 3
  min.insync.replicas           = 2            # Ensures durability (N-1 tolerance)
  num.partitions                = 6            # Default; override per-topic
  log.retention.hours           = 168          # 7 days
  log.retention.bytes           = -1           # No size limit (use hours)
  message.max.bytes             = 1048576      # 1MB; increase only with justification
  replica.fetch.max.bytes       = 1048576

IF non-production:
  auto.create.topics.enable     = false        # Still false — prevents drift
  default.replication.factor    = 2            # Cost savings acceptable
  min.insync.replicas           = 1
  num.partitions                = 3
  log.retention.hours           = 24
```

---

## SECURITY

### Security Model (4 Layers)

MSK security is a layered model — all four layers must be configured correctly:

```
Layer 1: Encryption      → TLS in-transit + KMS at-rest
Layer 2: Authentication  → IAM SASL / mTLS / SCRAM (who is connecting)
Layer 3: Authorization   → IAM policies OR Kafka ACLs (what they can do)
Layer 4: Network         → VPC, Security Groups, PrivateLink (where they connect from)
```

| Layer | Production Requirement | Non-Production |
|---|---|---|
| Encryption (transit) | TLS mandatory (`encryption_in_transit = "TLS"`) | TLS mandatory |
| Encryption (rest) | KMS CMK mandatory | KMS or AWS-managed key |
| Authentication | IAM SASL or mTLS (no unauthenticated) | IAM SASL minimum |
| Authorization | IAM policies (if IAM auth) or explicit ACLs (if mTLS/SCRAM) | Same |
| Network | Private subnets + SG allowlist; no public endpoint | Private subnets |

### Authentication Modes

| Mode | Use Case | Port | Authorization Via | Configuration |
|---|---|---|---|---|
| IAM SASL | AWS-native clients (EKS pods with IRSA) | 9098 | **IAM policies** (NOT Kafka ACLs) | `client_authentication.sasl.iam = true` |
| mTLS | Cross-account, external consumers | 9094 | **Kafka ACLs** | `client_authentication.tls.certificate_authority_arns` |
| SASL/SCRAM | Legacy clients (avoid for new) | 9096 | **Kafka ACLs** | `client_authentication.sasl.scram = true` + Secrets Manager |

### ACL Safety

**MSK default behavior:** `allow.everyone.if.no.acl.found = true`

This means: if no ACLs are defined for a resource, **all authenticated principals can access it**.

| Scenario | Risk | Mitigation |
|---|---|---|
| mTLS/SCRAM with no ACLs defined | All authenticated clients can read/write all topics | Always define explicit ACLs before granting client access |
| IAM auth with no IAM policy | Client cannot access anything (IAM is deny-by-default) | IAM is inherently safe — no policy = no access |
| Mixed auth (IAM + mTLS on same cluster) | mTLS clients get open access if no ACLs exist | Define ACLs for mTLS clients; IAM clients use IAM policies |

**Decision:** Prefer IAM SASL for new workloads — IAM's deny-by-default model is safer than Kafka ACLs with `allow.everyone.if.no.acl.found=true`.

### Security Group Rules

```hcl
ingress {
  from_port   = 9098  # IAM SASL
  to_port     = 9098
  protocol    = "tcp"
  cidr_blocks = var.client_cidrs
}

ingress {
  from_port   = 9094  # mTLS
  to_port     = 9094
  protocol    = "tcp"
  cidr_blocks = var.client_cidrs
}

ingress {
  from_port   = 9096  # SASL/SCRAM
  to_port     = 9096
  protocol    = "tcp"
  cidr_blocks = var.client_cidrs
}
```

---

## KAFKA_PROVIDER

### When to Use `mongey/kafka` Provider

**ONLY use this provider for clusters using mTLS or SCRAM authentication.**

If the cluster uses IAM SASL authentication, Kafka ACLs are ignored by MSK — use IAM policies instead.

| Cluster Auth Mode | Use `mongey/kafka` for ACLs? | Use `mongey/kafka` for Topics? |
|---|---|---|
| IAM SASL | **NO** — ACLs have no effect | Yes (topic management still works) |
| mTLS | **YES** — ACLs are the authorization layer | Yes |
| SASL/SCRAM | **YES** — ACLs are the authorization layer | Yes |

### Provider Configuration (mTLS cluster)

```hcl
provider "kafka" {
  bootstrap_servers = [data.aws_msk_cluster.this.bootstrap_brokers_tls]

  tls_enabled       = true
  client_cert       = file(var.client_cert_path)
  client_key        = file(var.client_key_path)
  ca_cert           = file(var.ca_cert_path)

  skip_tls_verify = false
}
```

### Provider Configuration (IAM — for topic management only, NOT ACLs)

```hcl
provider "kafka" {
  bootstrap_servers = [data.aws_msk_cluster.this.bootstrap_brokers_sasl_iam]

  tls_enabled    = true
  sasl_mechanism = "aws-iam"
  sasl_aws_region = var.region

  skip_tls_verify = false
}
```

### ACLs (mTLS/SCRAM clusters ONLY)

Per-context ACL pattern (one per bounded context):
```hcl
resource "kafka_acl" "context_read" {
  resource_name       = "context-${var.context_name}"
  resource_type       = "Topic"
  acl_principal       = "User:CN=${var.context_client_cn}"
  acl_host            = "*"
  acl_operation       = "Read"
  acl_permission_type = "Allow"
  resource_pattern_type_filter = "Prefixed"
}

resource "kafka_acl" "context_write" {
  resource_name       = "context-${var.context_name}"
  resource_type       = "Topic"
  acl_principal       = "User:CN=${var.context_client_cn}"
  acl_host            = "*"
  acl_operation       = "Write"
  acl_permission_type = "Allow"
  resource_pattern_type_filter = "Prefixed"
}

resource "kafka_acl" "context_group" {
  resource_name       = "context-${var.context_name}"
  resource_type       = "Group"
  acl_principal       = "User:CN=${var.context_client_cn}"
  acl_host            = "*"
  acl_operation       = "Read"
  acl_permission_type = "Allow"
  resource_pattern_type_filter = "Prefixed"
}
```

### IAM Authorization (IAM SASL clusters)

For IAM-authenticated clusters, authorization is via IAM policy on the client role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kafka-cluster:Connect",
        "kafka-cluster:DescribeCluster"
      ],
      "Resource": "arn:aws:kafka:${region}:${account_id}:cluster/${cluster_name}/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kafka-cluster:ReadData",
        "kafka-cluster:DescribeTopic"
      ],
      "Resource": "arn:aws:kafka:${region}:${account_id}:topic/${cluster_name}/*/context-${context_name}.*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kafka-cluster:WriteData",
        "kafka-cluster:DescribeTopic"
      ],
      "Resource": "arn:aws:kafka:${region}:${account_id}:topic/${cluster_name}/*/context-${context_name}.*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kafka-cluster:AlterGroup",
        "kafka-cluster:DescribeGroup"
      ],
      "Resource": "arn:aws:kafka:${region}:${account_id}:group/${cluster_name}/*/context-${context_name}.*"
    }
  ]
}
```

### TOPICS

```hcl
resource "kafka_topic" "events" {
  name               = "context-${var.context_name}.events"
  partitions         = var.topic_partitions
  replication_factor = 3

  config = {
    "cleanup.policy" = "delete"
    "retention.ms"   = "604800000"  # 7 days
  }
}
```

---

## LIFECYCLE

### Cluster Lifecycle (Terraform)

```
IF changing instance_type      → Rolling update (safe); brief per-broker unavailability
IF changing kafka_version      → Rolling upgrade (safe if minor); validate compatibility first
IF changing number_of_nodes    → Online scaling; BUT new brokers get zero partitions (manual reassign needed)
IF changing subnet_ids         → FORCES REPLACEMENT (cluster destroyed + recreated) — plan carefully
IF changing encryption config  → FORCES REPLACEMENT — never change on existing production cluster
IF changing auth mechanisms    → Online update; BUT clients must reconnect — coordinate with consumers
IF changing configuration_info → Rolling restart; new config applied per-broker
```

**Terraform lifecycle rules:**
```hcl
lifecycle {
  prevent_destroy = true  # ALWAYS on production MSK clusters
  ignore_changes  = []    # Do NOT ignore security-relevant attributes
}
```

### Topic Lifecycle

```
IF creating topic              → Safe; idempotent (exists = no-op)
IF increasing partitions       → Safe but IRREVERSIBLE; triggers rebalance; breaks key ordering
IF decreasing partitions       → NOT POSSIBLE — must delete and recreate topic (data loss)
IF changing replication_factor → NOT POSSIBLE in-place — requires partition reassignment tool
IF changing retention          → Safe; online update; old data purged on next log segment roll
IF changing cleanup.policy     → Safe; but switching delete→compact changes data semantics permanently
IF deleting topic              → DESTRUCTIVE; all data lost; consumer offsets orphaned
```

**Decision rules:**
- NEVER decrease partitions — design the initial count for peak parallelism
- NEVER delete a production topic without verifying zero active consumers
- ALWAYS increase partitions during low-traffic windows
- Topic names are permanent — typos require delete + recreate (with data loss)

### Configuration Change Safety

| Change Type | Safe to Apply? | Restart Required? | Data Risk |
|---|---|---|---|
| Broker config (properties) | Yes | Rolling restart | None |
| Instance type | Yes | Rolling restart | None |
| Storage increase | Yes | No restart | None |
| Storage decrease | **NO** — not supported | N/A | N/A |
| Add brokers | Yes | No restart | None (but unbalanced) |
| Remove brokers | **NO** — not supported by MSK | N/A | N/A |
| Kafka version upgrade | Yes (minor) | Rolling restart | Low (test first) |
| Kafka version downgrade | **NO** — not supported | N/A | N/A |

---

## SCHEMA_REGISTRY

### Deployment Pattern

Confluent for Kubernetes (CFK) operator on EKS:
- Helm chart: `confluent/confluent-for-kubernetes`
- SchemaRegistry CRD managed via `kubernetes_manifest`
- Connects to MSK via IAM SASL or mTLS
- Topic backup via custom CronJob chart

### Decisions

```
IF schema format:
  IF structured events with evolution needs → Avro (default, best tooling)
  IF high-performance RPC / gRPC alignment  → Protobuf
  IF simple events, human-readable          → JSON Schema (weakest validation)

IF compatibility mode:
  IF consumers deploy before producers      → BACKWARD (default — safe)
  IF producers deploy before consumers      → FORWARD
  IF both directions must be safe           → FULL
  IF breaking changes are forbidden         → FULL_TRANSITIVE

IF HA:
  → Multi-replica (3+) with leader election
  → topologySpreadConstraints across AZs
  → Anti-affinity with other Schema Registry pods

IF backup:
  → Periodic `_schemas` topic backup to S3 via CronJob
  → Frequency: daily minimum; hourly for high-change environments
  → Retention: 30 days of backups
```

---

## MONITORING

### Key MSK Metrics (Datadog)

| Metric | Alert Threshold | Severity |
|---|---|---|
| `aws.kafka.cpu_user` | > 70% sustained | Warning |
| `aws.kafka.kafka_data_logs_disk_used` | > 80% | Critical |
| `aws.kafka.global_partition_count` | Forecast breach | Warning |
| `aws.kafka.under_replicated_partitions` | > 0 for 5min | Critical |
| `aws.kafka.offline_partitions_count` | > 0 | Critical |
| Consumer lag (custom metric) | Context-specific SLO | Warning |

---

## OPERATIONAL_CONSIDERATIONS

### Partition Sizing

```
IF designing new topic:
  partitions = expected peak consumer instances per consumer group
  MINIMUM: 3 (for meaningful parallelism)
  MAXIMUM: broker_count * 100 (avoid hot-spotting)

IF key-ordered topic:
  partitions should be set HIGH at creation — cannot increase later without breaking ordering
  
IF throughput-focused (no ordering):
  partitions = target_throughput_MB_s / per_partition_throughput_MB_s
```

### Broker Scaling

```
IF CPU > 70% sustained:
  → Vertical scale (larger instance type) — rolling restart, safe
  
IF disk > 80%:
  → Expand EBS volume — online, no restart, immediate
  
IF partition count growing beyond single-broker capacity:
  → Add brokers — BUT must manually reassign partitions afterward
  → MSK does NOT auto-rebalance partitions to new brokers

IF need to remove brokers:
  → NOT SUPPORTED by MSK — cannot shrink cluster
```

### Consumer Lag (Primary SLO Signal)

```
IF lag stable near zero        → Healthy; no action
IF lag growing steadily        → Consumer throughput < producer rate → scale consumers or optimize
IF lag spikes then recovers    → Transient (deploy, restart) → no action if within SLO window
IF lag infinite / not moving   → Consumer crashed or stuck → investigate health, check DLQ
IF lag negative                → Clock skew or offset reset → verify consumer offset commit logic
```

### Rebalancing

```
IF rebalancing frequently (> 1/hour):
  → Check: consumer crash loop, unstable network, aggressive session.timeout.ms
  → Fix: CooperativeStickyAssignor, increase session.timeout.ms, use static group membership
  
IF rebalancing takes > 30s:
  → Too many partitions per consumer OR slow partition assignment
  → Fix: reduce max.poll.interval.ms, increase partition.assignment.strategy efficiency
```

---

## FAILURE_MODES

### Broker Failures

```
IF single broker fails:
  → MSK auto-recovers (replaces broker, replicates data)
  → Impact: partitions led by that broker briefly unavailable
  → Consumer sees: transient read failures, then recovery
  → Producer sees: retries succeed if acks=all and retries>0
  → Duration: 5-15 minutes typical
  → REQUIRED: min.insync.replicas=2 with replication_factor=3 (tolerates 1 broker loss)

IF multiple brokers fail simultaneously:
  → Partitions with all replicas on failed brokers go OFFLINE
  → Monitor: aws.kafka.offline_partitions_count > 0 → Critical alert
  → Recovery: wait for MSK auto-recovery; if prolonged → AWS support case
  → Prevention: ensure partitions spread across all AZs (MSK rack-awareness does this by default)
```

### Under-Replicated Partitions

```
IF under_replicated_partitions > 0:
  → Meaning: some replicas are behind the leader (data loss risk if leader fails now)
  → Common causes: broker overload, network issues, disk I/O saturation
  → Immediate: check broker CPU, disk, network metrics
  → IF transient (< 5min): monitor, usually self-heals
  → IF sustained (> 5min): Critical alert — investigate broker health
  → IF after scaling/restart: expected briefly — monitor for recovery
```

### Disk Full

```
IF kafka_data_logs_disk_used > 85%:
  → Broker stops accepting writes for affected partitions
  → Recovery: expand EBS (online, immediate) OR reduce retention
  → Prevention: alert at 70%, auto-expand via Terraform if possible
  → NEVER let disk reach 100% — broker becomes unhealthy, partitions go offline
```

### Consumer Group Failures

```
IF consumer group has no active members:
  → Messages accumulate (lag grows unbounded)
  → No data loss — messages retained per retention policy
  → Fix: restart consumer application
  → Risk: if lag exceeds retention period → messages lost permanently

IF consumer commits offsets but doesn't process:
  → Silent data loss (messages skipped)
  → Prevention: monitor processing rate alongside commit rate
  → Detection: business metrics diverge from message count

IF consumer resets to earliest:
  → Reprocesses all retained messages (duplicate processing)
  → Impact depends on consumer idempotency
  → Prevention: never use auto.offset.reset=earliest in production without idempotent processing
```

### Producer Failures

```
IF producer gets NotLeaderForPartition:
  → Leader election in progress (broker restart/failure)
  → Fix: producer retries handle this automatically (ensure retries > 0)

IF producer gets TopicAuthorizationFailed:
  → IAM policy missing kafka-cluster:WriteData (IAM auth)
  → OR Kafka ACL missing Write permission (mTLS/SCRAM auth)
  → Fix: update IAM policy or ACL for the topic pattern

IF producer gets MessageTooLargeException:
  → Message exceeds message.max.bytes
  → Fix: increase message.max.bytes in cluster config (requires rolling restart)
  → OR compress messages (recommended: lz4 or zstd)
```

### Network / Connectivity Failures

```
IF clients cannot connect to bootstrap brokers:
  → Check: security group rules (port 9094/9096/9098)
  → Check: DNS resolution (use bootstrap broker DNS, not IPs)
  → Check: client is in allowed VPC/subnet
  → Check: NACLs not blocking ephemeral return ports

IF intermittent timeouts:
  → Check: client-side socket timeout configuration
  → Check: cross-AZ latency (ensure clients co-located with brokers)
  → Check: broker CPU/network saturation
```

---

## OUTPUT_CONTRACTS

| Task | Outputs |
|---|---|
| MSK cluster creation | Bootstrap brokers (IAM/TLS/SCRAM), cluster ARN, ZooKeeper connect string, security group ID |
| ACL setup (mTLS/SCRAM) | Topic permissions (read/write per context), group permissions, principal identity |
| IAM authorization (IAM SASL) | IAM policy ARN, permitted topic ARN patterns, permitted group ARN patterns |
| Topic management | Topic name, partition count, replication factor, retention config |
| Schema Registry | Registry endpoint URL, compatibility mode, backup schedule |
| Security group | SG ID, ingress rules (ports 9094/9096/9098), allowed source CIDRs |

---

## TERRAFORM_MODULES

### Internal Module: `ae_terraform_modules//aws/msk`
- Wraps MSK cluster creation with org defaults
- Enforces encryption, logging, monitoring
- Outputs: bootstrap brokers (per auth type), cluster ARN, ZooKeeper connect, security group ID

### Internal Module: `ae_terraform_modules//aws/kafka_acl`
- Manages ACLs via `mongey/kafka` provider
- **Only applicable for mTLS/SCRAM clusters** — do not use with IAM-authenticated clusters
- Per-context prefix-based access pattern
- Depends on cluster being ready (use `depends_on` or data source)
