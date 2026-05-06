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

## Cross-Cutting Rules

| Decision | Rule |
|---|---|
| Authentication | IAM SASL (preferred) for AWS-native clients; mTLS for cross-account/external |
| Encryption | TLS in-transit mandatory; KMS at-rest mandatory for production |
| Access control | Per-context ACLs via Terraform `mongey/kafka` provider; no shared super-user topics |
| Networking | Private subnets only; no public endpoints in production |
| Versioning | Pin Kafka version explicitly; upgrade via blue-green or rolling |

---

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

| Workload | Instance Type | When |
|---|---|---|
| Dev/test | `kafka.t3.small` | Low throughput, cost optimization |
| Standard production | `kafka.m5.large` | Balanced cost/performance |
| High throughput | `kafka.m5.2xlarge` | Heavy streaming workloads |
| Storage-intensive | `kafka.m5.4xlarge` | Large retention, many partitions |

### Configuration Properties

Standard production properties file pattern:
```properties
auto.create.topics.enable=false
default.replication.factor=3
min.insync.replicas=2
num.partitions=6
log.retention.hours=168
log.retention.bytes=-1
message.max.bytes=1048576
replica.fetch.max.bytes=1048576
```

---

## SECURITY

### Authentication Modes

| Mode | Use Case | Configuration |
|---|---|---|
| IAM SASL | AWS-native clients (EKS pods with IRSA) | `client_authentication.sasl.iam = true` |
| mTLS | Cross-account, external consumers | `client_authentication.tls.certificate_authority_arns` |
| SASL/SCRAM | Legacy clients (avoid for new) | `client_authentication.sasl.scram = true` + Secrets Manager |

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
```

---

## KAFKA_PROVIDER

### `mongey/kafka` Provider Configuration

```hcl
provider "kafka" {
  bootstrap_servers = [data.aws_msk_cluster.this.bootstrap_brokers_sasl_iam]

  tls_enabled    = true
  sasl_mechanism = "aws-iam"
  sasl_aws_region = var.region

  skip_tls_verify = false
}
```

### ACLS

Per-context ACL pattern (one per bounded context):
```hcl
resource "kafka_acl" "context_read" {
  resource_name       = "context-${var.context_name}"
  resource_type       = "Topic"
  acl_principal       = "User:${var.context_iam_role_arn}"
  acl_host            = "*"
  acl_operation       = "Read"
  acl_permission_type = "Allow"
  resource_pattern_type_filter = "Prefixed"
}

resource "kafka_acl" "context_write" {
  resource_name       = "context-${var.context_name}"
  resource_type       = "Topic"
  acl_principal       = "User:${var.context_iam_role_arn}"
  acl_host            = "*"
  acl_operation       = "Write"
  acl_permission_type = "Allow"
  resource_pattern_type_filter = "Prefixed"
}

resource "kafka_acl" "context_group" {
  resource_name       = "context-${var.context_name}"
  resource_type       = "Group"
  acl_principal       = "User:${var.context_iam_role_arn}"
  acl_host            = "*"
  acl_operation       = "Read"
  acl_permission_type = "Allow"
  resource_pattern_type_filter = "Prefixed"
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

## SCHEMA_REGISTRY

### Confluent for Kubernetes (CFK) Pattern

Schema Registry deployed via CFK operator on EKS:
- Helm chart: `confluent/confluent-for-kubernetes`
- SchemaRegistry CRD managed via `kubernetes_manifest`
- Connects to MSK via IAM SASL or mTLS
- Topic backup via custom CronJob chart

### Decisions

| Scenario | Decision |
|---|---|
| Schema format | Avro (default) or Protobuf; JSON Schema for simple events |
| Compatibility mode | `BACKWARD` (default) or `FULL` for breaking-change-sensitive topics |
| HA | Multi-replica with leader election; `topologySpreadConstraints` across AZs |
| Backup | Periodic topic backup to S3 via custom chart/CronJob |

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

## TERRAFORM_MODULES

### Internal Module: `ae_terraform_modules//aws/msk`
- Wraps MSK cluster creation with org defaults
- Enforces encryption, logging, monitoring
- Outputs bootstrap brokers, ZooKeeper connect, cluster ARN

### Internal Module: `ae_terraform_modules//aws/kafka_acl`
- Manages ACLs via `mongey/kafka` provider
- Per-context prefix-based access pattern
- Depends on cluster being ready (use `depends_on` or data source)
