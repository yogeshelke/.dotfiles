---
name: rds-aurora
description: >-
  RDS Aurora PostgreSQL decision system. Use for cluster configuration, PostgreSQL provider
  patterns (cyrilgdn/postgresql), credential management, read replica strategy, and
  monitoring. Do NOT use for general AWS architecture (use aws skill) or generic Terraform
  patterns (use terraform skill).
metadata:
  author: SHELYOG
  version: 1.0.0
  category: infrastructure
  updated: 2026-05-06
---
# RDS Aurora PostgreSQL Decision Engine

Decision rules for Aurora PostgreSQL cluster management.

- General AWS architecture → `skills/aws/`
- Terraform module patterns → `skills/terraform/`
- EKS pod access (IRSA + SG) → `skills/eks/`
- Monitoring → `skills/datadog/`
- This file answers: **how to configure Aurora, manage database users, and handle credentials**

## Interaction Model
- This skill defines **Aurora cluster config, PostgreSQL user management, and access patterns**
- VPC/subnet design → `aws` skill
- HCL module structure → `terraform` skill
- Network policies (pod → RDS) → `calico` skill
- Backup (application-level) → `velero` skill (for K8s state; RDS uses native snapshots)

---

## Decision Entry Points

| Task | Read sections |
|---|---|
| New Aurora cluster | CLUSTER_CONFIG + NETWORKING + ENCRYPTION |
| Manage database users/roles | POSTGRESQL_PROVIDER |
| Configure credentials | SECRETS_MANAGEMENT |
| Read replica strategy | REPLICAS |
| Monitor Aurora | MONITORING |
| RDS logging to CloudWatch | LOGGING |

---

## Cross-Cutting Rules

| Decision | Rule |
|---|---|
| Engine | Aurora PostgreSQL (not MySQL) unless explicit requirement |
| Credentials | Secrets Manager with rotation; never hardcoded |
| Encryption | KMS CMK at rest; TLS in transit (enforce `rds.force_ssl`) |
| Multi-AZ | Always for production; optional for dev |
| Backup | Automated snapshots + PITR; 7d min retention (prod: 35d) |
| Access | Via security group from EKS node/pod SG; no public access |

---

## CLUSTER_CONFIG

### Aurora Cluster Terraform Pattern

```hcl
module "rds_cluster" {
  source = "git::https://github.com/org/ae_terraform_modules.git//aws/rds_cluster?ref=vX.Y.Z"

  cluster_identifier = "ae-${var.environment}-${var.service_name}"
  engine             = "aurora-postgresql"
  engine_version     = var.aurora_engine_version

  master_username = "postgres_admin"
  master_password = random_password.rds_master.result

  instance_class = var.rds_instance_class
  instances      = var.rds_instance_count

  vpc_id                 = var.vpc_id
  subnet_ids             = var.database_subnet_ids
  vpc_security_group_ids = [aws_security_group.rds.id]

  storage_encrypted = true
  kms_key_id        = var.rds_kms_key_arn

  backup_retention_period = var.environment == "prod" ? 35 : 7
  preferred_backup_window = "03:00-04:00"

  deletion_protection = var.environment == "prod" ? true : false

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = local.common_tags
}
```

### Instance Size Selection

| Workload | Instance Class | When |
|---|---|---|
| Dev/test | `db.t4g.medium` | Low traffic, cost optimization |
| Standard prod | `db.r6g.large` | Balanced performance |
| High memory | `db.r6g.xlarge` | Large working sets, complex queries |
| Serverless v2 | `db.serverless` | Variable/unpredictable load |

### Aurora Serverless v2 Decisions

| Scenario | Use Serverless v2 | Use Provisioned |
|---|---|---|
| Variable traffic (spiky) | Yes | No |
| Predictable steady load | No | Yes (cheaper) |
| Dev/test environments | Yes (scales to 0.5 ACU) | No |
| Cost predictability needed | No | Yes |

---

## POSTGRESQL_PROVIDER

### `cyrilgdn/postgresql` Provider Pattern

Used for managing database-level objects (roles, databases, extensions) after the cluster exists:

```hcl
provider "postgresql" {
  host     = module.rds_cluster.cluster_endpoint
  port     = 5432
  username = "postgres_admin"
  password = data.aws_secretsmanager_secret_version.rds_master.secret_string
  sslmode  = "require"

  superuser = false
}
```

### Database and Role Management

```hcl
resource "postgresql_role" "context_role" {
  name     = "context_${var.context_name}"
  login    = true
  password = random_password.context_db_password.result

  connection_limit = var.connection_limit
}

resource "postgresql_database" "context_db" {
  name  = var.context_name
  owner = postgresql_role.context_role.name

  encoding   = "UTF8"
  lc_collate = "en_US.UTF-8"
}

resource "postgresql_grant" "context_schema" {
  database    = postgresql_database.context_db.name
  role        = postgresql_role.context_role.name
  schema      = "public"
  object_type = "schema"
  privileges  = ["CREATE", "USAGE"]
}
```

### Per-Context Access Pattern

Each bounded context gets:
1. Dedicated PostgreSQL role (login)
2. Dedicated database
3. Schema-level grants (not superuser)
4. Credentials stored in Secrets Manager
5. IRSA-based access from pods (via security group, not IAM auth for PostgreSQL)

---

## SECRETS_MANAGEMENT

### Credential Flow

```
Terraform creates → random_password
  → Stored in Secrets Manager (aws_secretsmanager_secret_version)
  → Application reads via:
    Option A: External Secrets Operator → K8s Secret → env/volume
    Option B: AWS SDK direct read (IRSA-authenticated)
    Option C: Init container fetches → shared volume
```

### Terraform Pattern

```hcl
resource "random_password" "context_db" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "context_db" {
  name = "platform/${var.environment}/rds/${var.context_name}"
  kms_key_id = var.secrets_kms_key_arn
}

resource "aws_secretsmanager_secret_version" "context_db" {
  secret_id = aws_secretsmanager_secret.context_db.id
  secret_string = jsonencode({
    host     = module.rds_cluster.cluster_endpoint
    port     = 5432
    dbname   = var.context_name
    username = postgresql_role.context_role.name
    password = random_password.context_db.result
    sslmode  = "require"
  })
}
```

---

## NETWORKING

### Security Group Pattern

```hcl
resource "aws_security_group" "rds" {
  name_prefix = "ae-${var.environment}-rds-"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_node_security_group_id]
    description     = "PostgreSQL from EKS nodes"
  }

  tags = merge(local.common_tags, {
    Name = "ae-${var.environment}-rds"
  })
}
```

### Access Decisions

| Source | Method |
|---|---|
| EKS pods | Security group allowing node SG → RDS SG on 5432 |
| Lambda | Security group + VPC attachment |
| Bastion (debugging) | Temporary SG rule; remove after use |
| Cross-account | Not recommended; use data replication instead |

---

## REPLICAS

### Read Replica Strategy

| Scenario | Configuration |
|---|---|
| Read-heavy workloads | Add reader instances; use reader endpoint |
| Cross-region DR | Aurora Global Database (async replication) |
| Analytics queries | Dedicated reader instance with larger class |
| Connection pooling | RDS Proxy (recommended for Lambda; optional for EKS) |

### Aurora Endpoints

| Endpoint | Use For |
|---|---|
| Cluster (writer) | All writes + reads requiring consistency |
| Reader | Read-only queries; load-balanced across readers |
| Custom | Specific instance targeting (analytics) |

---

## LOGGING

### CloudWatch Log Export

```hcl
enabled_cloudwatch_logs_exports = ["postgresql"]
```

### Log Fanout Pattern (Lambda)

For shared clusters with multiple contexts:
```
Aurora PostgreSQL logs → CloudWatch Log Group
  → Subscription Filter → Lambda (Python/boto3)
    → Per-context CloudWatch Log Group (filtered by database name)
```

This enables per-team log access without sharing the full cluster log stream.

---

## MONITORING

### Key Metrics (Datadog)

| Metric | Alert Threshold | Severity |
|---|---|---|
| `aws.rds.cpuutilization` | > 80% sustained 15min | Warning |
| `aws.rds.freeable_memory` | < 1GB | Warning |
| `aws.rds.free_storage_space` | < 20% | Critical |
| `aws.rds.database_connections` | > 80% of max | Warning |
| `aws.rds.read_latency` | > 20ms P99 | Warning |
| `aws.rds.write_latency` | > 10ms P99 | Warning |
| `aws.rds.replica_lag` | > 1000ms | Critical |
| `aws.rds.deadlocks` | > 0 sustained | Warning |
