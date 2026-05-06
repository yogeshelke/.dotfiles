---
name: velero
description: >-
  Velero backup and disaster recovery decision system for Kubernetes. Use for backup schedule
  design, restore procedures, CSI snapshot integration, IAM/S3 configuration, and monitoring.
  Do NOT use for general Kubernetes workloads (use kubernetes skill) or EKS cluster config
  (use eks skill) unless backup-specific.
metadata:
  author: SHELYOG
  version: 2.0.0
  category: infrastructure
  updated: 2026-05-06
---
# Velero Decision Engine

Decision rules for Kubernetes backup and disaster recovery with Velero.

- EKS cluster configuration → `skills/eks/`
- S3 bucket Terraform → `skills/terraform/` + `skills/aws/`
- Helm chart installation patterns → `skills/helm/`
- Backup monitoring dashboards → `skills/datadog/`
- This file answers: **how to configure Velero, design backup schedules, and manage restores**

## Interaction Model
- This skill defines **backup strategy, schedule design, and restore patterns** only
- IAM role creation (IRSA/Pod Identity) → `aws` + `eks` skills
- S3 bucket with lifecycle rules → `terraform` skill
- Datadog monitors for backup failures → `datadog` skill

---

## Decision Entry Points

| Task | Read sections |
|---|---|
| Deploy Velero to cluster | INSTALLATION + IAM + STORAGE |
| Design backup schedule | RPO_RTO + SCHEDULES |
| Configure CSI snapshots | CSI_SNAPSHOTS |
| Test restore procedure | RESTORE |
| Monitor backup health | MONITORING |
| Troubleshoot failed backups | FAILURE_MODES |
| Assess change risk | LIFECYCLE |

---

## Cross-Cutting Rules

| Decision | Rule |
|---|---|
| Authentication | Pod Identity (preferred) or IRSA — never node-level IAM |
| Encryption | S3 bucket with SSE-KMS; Velero respects bucket-level encryption |
| Retention | Production: 30d minimum; DR copy: cross-region S3 replication |
| Testing | Monthly restore drill to non-prod; document RTO/RPO evidence |
| CSI snapshots | Enable for PV-backed workloads; Velero + CSI snapshot controller |
| Restore safety | NEVER restore into production without dry-run + namespace isolation first |

---

## RPO_RTO

### Recovery Point Objective (how much data can you lose)

```
IF RPO ≤ 15 minutes:
  → Continuous replication (not Velero alone — consider app-level replication, DB native)
  → Velero supplements but cannot guarantee sub-15min RPO

IF RPO ≤ 1 hour:
  → Hourly Velero backups + CSI volume snapshots
  → snapshotVolumes: true mandatory
  → TTL: 7-30 days depending on compliance

IF RPO ≤ 24 hours:
  → Daily Velero backups sufficient
  → CSI snapshots optional (reduces restore time, not RPO)
  → TTL: 30 days minimum for production

IF RPO = "best effort" (non-critical):
  → Daily backup, no volume snapshots
  → TTL: 7 days
  → Accept that stateful data may be lost between backups
```

### Recovery Time Objective (how fast must you recover)

```
IF RTO ≤ 15 minutes:
  → Velero alone CANNOT guarantee this
  → Requires: pre-warmed standby cluster + DNS failover + pre-restored state
  → Velero role: initial seeding of standby, not real-time failover

IF RTO ≤ 30 minutes:
  → Pre-warmed cluster in DR region (EKS + addons ready)
  → Velero restore from cross-region S3 bucket
  → CSI snapshots pre-replicated (EBS cross-region snapshot copy)
  → Tested monthly; restore script automated

IF RTO ≤ 4 hours:
  → Full restore to new or existing cluster
  → Acceptable to provision cluster during recovery
  → CSI snapshots restore PVCs in parallel with workloads

IF RTO = "next business day" (non-critical):
  → Standard restore procedure; manual intervention acceptable
  → No pre-warmed infrastructure needed
```

### RPO/RTO → Schedule Mapping

```
IF RPO=1h + RTO=30min  → hourly backups, CSI snapshots, cross-region replication, pre-warmed DR
IF RPO=1h + RTO=4h     → hourly backups, CSI snapshots, cross-region bucket, restore-on-demand
IF RPO=24h + RTO=4h    → daily backups, CSI snapshots, same-region, restore-on-demand
IF RPO=24h + RTO=24h   → daily backups, no CSI, same-region, manual restore
```

---

## INSTALLATION

### Helm Chart Pattern (via Terraform)

```hcl
resource "helm_release" "velero" {
  name       = "velero"
  namespace  = "velero"
  repository = "https://vmware-tanzu.github.io/helm-charts"
  chart      = "velero"
  version    = var.velero_chart_version

  create_namespace = true

  values = [templatefile("${path.module}/configs/manifests/velero/values.yaml", {
    bucket_name       = var.velero_bucket_name
    region            = var.region
    service_account   = "velero"
    kms_key_arn       = var.velero_kms_key_arn
  })]
}
```

### Values Decisions

```
IF production:
  → Dedicated bucket per cluster
  → schedules defined in values (not ad-hoc)
  → resources.requests: 512Mi / 500m
  → nodeSelector: system/platform nodes
  → PDB: minAvailable 1

IF non-production:
  → Shared bucket with cluster-name prefix
  → Minimal schedules (daily or disabled)
  → resources.requests: 256Mi / 100m
  → nodeSelector: any
  → No PDB needed
```

---

## IAM

### Pod Identity / IRSA Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::${bucket_name}",
        "arn:aws:s3:::${bucket_name}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeVolumes",
        "ec2:DescribeSnapshots",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:CreateSnapshot",
        "ec2:DeleteSnapshot"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "ec2:ResourceTag/kubernetes.io/cluster/${cluster_name}": "owned"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey"
      ],
      "Resource": "${kms_key_arn}"
    }
  ]
}
```

---

## STORAGE

### S3 Bucket Decisions

```
IF production:
  → SSE-KMS with dedicated CMK (not aws/s3 default key)
  → Versioning: enabled (protects against accidental overwrite)
  → Lifecycle: transition to IA after 30d; delete after retention period
  → Public access: blocked (all four settings)
  → Cross-region replication: enabled to DR region bucket
  → Object lock: enable for compliance workloads (prevents deletion)

IF non-production:
  → SSE-S3 or SSE-KMS (shared key acceptable)
  → Versioning: enabled
  → Lifecycle: delete after 14 days
  → No cross-region replication needed
```

---

## SCHEDULES

```
IF stateless workloads (Deployments, ConfigMaps, Services only):
  → Daily backup at 02:00 UTC
  → snapshotVolumes: false
  → TTL: 168h (7 days)
  → Rationale: manifests are in Git; backup is convenience, not DR

IF stateful workloads (PVCs attached):
  → Hourly backup
  → snapshotVolumes: true (CSI plugin required)
  → TTL: 720h (30 days)
  → Rationale: PVC data is NOT in Git; backup is the DR mechanism

IF critical data (databases on PVC, queues):
  → Hourly backup + pre-change backup (before upgrades/migrations)
  → snapshotVolumes: true
  → TTL: 2160h (90 days)
  → Label selector: backup-priority=critical
  → Rationale: extended retention for audit + rollback beyond standard window

IF cluster-wide DR:
  → Daily full backup (all namespaces except kube-system, velero)
  → snapshotVolumes: true
  → TTL: 720h (30 days)
  → Cross-region S3 replication for the backup bucket
```

### Schedule YAML Pattern

```yaml
schedules:
  daily-full:
    schedule: "0 2 * * *"
    template:
      ttl: "720h"
      includedNamespaces: ["*"]
      excludedNamespaces: ["kube-system", "velero"]
      snapshotVolumes: true
      storageLocation: default

  hourly-critical:
    schedule: "0 * * * *"
    template:
      ttl: "168h"
      includedNamespaces: ["production-workloads"]
      labelSelector:
        matchLabels:
          backup-priority: critical
      snapshotVolumes: true
```

---

## CSI_SNAPSHOTS

### CSI Snapshot Limitations (CRITICAL — understand before relying on them)

```
CSI snapshot != full application-consistent backup

IF application writes data across multiple files/volumes:
  → CSI snapshot is crash-consistent ONLY (not application-consistent)
  → Equivalent to pulling the power plug — data may be in inconsistent state
  → For databases: ALWAYS use database-native backup (pg_dump, mysqldump) in addition to CSI

IF application uses single volume with simple writes:
  → CSI snapshot is sufficient for recovery
  → Example: single-writer log storage, object cache

IF storage class does not support snapshots:
  → CSI snapshots silently fail or are skipped
  → Verify: kubectl get volumesnapshotclass — must exist for your CSI driver
  → EBS CSI driver (ebs.csi.aws.com): supports snapshots
  → EFS CSI driver: does NOT support VolumeSnapshots (use EFS backup instead)

IF no quiescing mechanism exists:
  → Accept crash-consistent recovery
  → OR implement pre/post hooks in Velero backup spec (fsfreeze, pg_start_backup)
```

### CSI Snapshot Controller (prerequisite)

```hcl
resource "helm_release" "csi_snapshot_controller" {
  name       = "snapshot-controller"
  namespace  = "kube-system"
  repository = "https://piraeus.io/helm-charts/"
  chart      = "snapshot-controller"
  version    = var.csi_snapshot_controller_version
}
```

### Velero CSI Plugin

```yaml
initContainers:
  - name: velero-plugin-for-csi
    image: velero/velero-plugin-for-csi:<version>
    volumeMounts:
      - mountPath: /target
        name: plugins

configuration:
  features: EnableCSI
```

### VolumeSnapshotClass

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: velero-csi-snapclass
  labels:
    velero.io/csi-volumesnapshot-class: "true"
driver: ebs.csi.aws.com
deletionPolicy: Retain
```

---

## RESTORE

### Restore Decisions

```
IF restoring single namespace:
  → velero restore create --from-backup <name> --include-namespaces <ns>
  → Safe: isolated to one namespace

IF restoring single resource type:
  → velero restore create --from-backup <name> --include-resources <type> --selector <labels>
  → Safe: minimal blast radius

IF full cluster DR (new cluster):
  → Provision new EKS cluster + addons first
  → Restore from cross-region S3 bucket
  → Verify: all CRDs installed BEFORE restore (Velero cannot restore CRD instances without CRD definitions)

IF restoring PVCs:
  → --restore-volumes=true
  → CSI snapshot must exist in same region
  → Storage class must match (or use --change-storage-class mapping)

IF restoring into cluster that already has resources:
  → DEFAULT: Velero SKIPS existing resources (no overwrite)
  → To overwrite: --existing-resource-policy=update (DANGEROUS — can corrupt running workloads)
  → SAFE PATTERN: restore to new namespace, validate, then swap traffic
```

### Idempotency / Repeatability

```
IF re-running restore from same backup:
  → Velero creates a NEW restore object (restore-<backup>-<timestamp>)
  → Existing resources are SKIPPED by default (not overwritten, not duplicated)
  → Safe to retry — but previously-skipped resources stay skipped
  → To force overwrite: --existing-resource-policy=update (DANGEROUS)

IF orchestrator retries a failed restore task:
  → Safe: Velero skips already-restored resources
  → Check: previous restore's partial results before retrying
  → Pattern: describe previous restore → identify what failed → restore only missing pieces with selectors

IF backup schedule fires while previous backup is still running:
  → New backup is queued (not concurrent)
  → No duplication or corruption
  → If queue grows: investigate why backups are slow (large PVCs, S3 throttling)
```

### Restore Procedure (read-only from agent — human executes)

1. `velero backup get` — list available backups
2. `velero backup describe <name> --details` — verify contents
3. `velero restore create --from-backup <name> --dry-run` — preview
4. Human executes: `velero restore create --from-backup <name>` 
5. `velero restore describe <name>` — verify completion
6. Check pod/PVC status in restored namespaces

---

## LIFECYCLE

### What Is Safe vs Unsafe

```
IF upgrading Velero chart version:
  → Safe: backups continue working; CRDs auto-upgrade
  → Risk: new version may change backup format (test restore from old backup in non-prod first)
  → NEVER skip more than one minor version

IF changing backup schedule:
  → Safe: only affects future backups; existing backups untouched
  → No restart needed

IF changing S3 bucket:
  → DANGEROUS: old backups become inaccessible from new BSL
  → Keep old BSL as read-only until all old backups expire
  → Never delete old bucket until retention period passes

IF restoring into existing namespace:
  → Risk: resource conflicts (existing Deployments, Services, ConfigMaps)
  → Velero default: SKIP existing resources (safe but incomplete)
  → --existing-resource-policy=update: OVERWRITES resources (can break running workloads)
  → SAFE PATTERN: restore to temporary namespace → validate → swap

IF restoring PVCs into cluster with existing PVCs:
  → Risk: duplicate PVs created (cost + confusion)
  → Risk: PVC binds to wrong PV if names collide
  → Fix: ensure PVCs are deleted before restore OR use --include-resources to target only PVCs

IF deleting Velero backups:
  → PERMANENT data loss — backup files removed from S3
  → S3 versioning mitigates accidental deletion (can recover from versions)
  → Object lock prevents deletion entirely (compliance mode)
  → NEVER delete backups that haven't exceeded retention TTL

IF deleting Velero from cluster:
  → CRDs remain (backup/restore/schedule resources stay in etcd)
  → S3 data remains (backups still in bucket)
  → Re-installing Velero reconnects to existing backups via BSL
  → DANGER: if CRDs deleted, backup metadata lost (S3 data orphaned)
```

### Terraform Lifecycle

```hcl
resource "helm_release" "velero" {
  lifecycle {
    prevent_destroy = true  # Production: never accidentally remove Velero
  }
}

resource "aws_s3_bucket" "velero" {
  lifecycle {
    prevent_destroy = true  # NEVER delete backup bucket via Terraform
  }
}
```

---

## FAILURE_MODES

### Backup Failures

```
IF backup status = Failed:
  → Check: velero backup describe <name> --details
  → Check: velero backup logs <name>
  → Common causes:
    IF "error getting volume" → PVC deleted during backup; harmless if intentional
    IF "timed out" → node pressure, large PVCs, slow S3 upload
    IF "AccessDenied" → IRSA/Pod Identity broken; check SA annotation + trust policy
    IF "no such bucket" → S3 bucket deleted or name mismatch in BSL config

IF backup status = PartiallyFailed:
  → Some resources backed up, others failed
  → Check logs for specific failures (usually CRD issues or webhook timeouts)
  → Webhook timeouts: pods with admission webhooks that are down → Velero can't validate
  → Fix: add webhook timeout annotation or exclude problematic namespaces

IF backup never starts (schedule exists but no backups created):
  → Check Velero pod is running: kubectl get pods -n velero
  → Check schedule is not paused: velero schedule get
  → Check BSL is Available: velero backup-location get (must show "Available")
  → If BSL shows "Unavailable": S3 connectivity or IAM issue
```

### Restore Failures

```
IF restore status = Failed:
  → velero restore describe <name> --details
  → velero restore logs <name>

IF "no matching resource" errors:
  → CRDs not installed in target cluster
  → Fix: install CRDs/operators BEFORE restoring their instances
  → Common: Calico CRDs, cert-manager CRDs, Velero's own CRDs

IF PVC restore fails:
  → CSI snapshot missing (expired or not replicated to this region)
  → Storage class mismatch (source used gp3, target only has gp2)
  → Fix: ensure VolumeSnapshotClass exists; use --change-storage-class flag

IF restore completes but pods are CrashLooping:
  → Likely: secrets/configmaps reference external resources that don't exist in target
  → Likely: IRSA annotations point to IAM roles that don't exist in target account
  → Fix: restore infrastructure (IAM, SGs, endpoints) before workload restore

IF restore creates resources but they don't work:
  → Check: namespace labels (network policies may block traffic)
  → Check: service accounts (IRSA annotations may be wrong for target cluster)
  → Check: external dependencies (RDS endpoint, MSK brokers — may differ in DR region)
```

### CSI Snapshot Failures

```
IF VolumeSnapshot stuck in "ReadyToUse: false":
  → CSI driver issue — check snapshot-controller logs
  → EBS: check ec2:CreateSnapshot IAM permission
  → Timeout: large volumes take time; increase CSI timeout

IF snapshot exists but restore fails:
  → Snapshot in wrong AZ (EBS snapshots are AZ-specific for in-region)
  → Fix: Velero handles cross-AZ via volume creation, but verify AZ availability

IF EFS volumes not snapshotted:
  → EFS CSI driver does NOT support VolumeSnapshots
  → Fix: use AWS Backup for EFS, not Velero CSI plugin
  → OR: exclude EFS PVCs from Velero and back up separately
```

---

## MONITORING

### Datadog Monitors for Velero

```
IF velero_backup_failure_total > 0 for 15min   → Critical alert
IF velero_backup_last_successful_timestamp age > (schedule_interval + 30min buffer) → Critical alert
IF velero_backup_partial_failure_total > 0 for 30min → Warning alert
IF velero_restore_failure_total > 0             → Critical alert (restore failures are always urgent)
IF velero_backup_duration_seconds > 2x normal   → Warning (performance degradation)
```

---

## NON_GOALS

Velero is **not** a solution for:

- **Application-level backup** — database dumps (pg_dump, mysqldump), application state exports; use native tools for these
- **Real-time replication** — Velero is point-in-time snapshots, not streaming DR; sub-minute RPO requires app-level replication (RDS Multi-AZ, Kafka MirrorMaker)
- **Configuration management** — GitOps (ArgoCD, Flux) is the source of truth for manifests; Velero is the safety net, not the deployment mechanism
- **Secret rotation or migration** — Velero restores secrets as-is; rotated secrets must be updated post-restore
- **Cross-cloud portability** — CSI snapshots are provider-specific (EBS snapshots don't restore to GCP); only Kubernetes resource metadata is portable

---

## OUTPUT_CONTRACTS

| Task | Outputs |
|---|---|
| Velero installation | Namespace (`velero`), Helm release name, ServiceAccount with IRSA annotation, CRDs installed |
| Backup storage location | BSL name, S3 bucket ARN, region, prefix, KMS key ARN |
| Backup schedule | Schedule name, cron expression, TTL, included/excluded namespaces, snapshotVolumes flag |
| CSI snapshot config | VolumeSnapshotClass name, CSI driver, deletion policy, Velero plugin installed |
| IAM configuration | IAM role ARN, trust policy (Pod Identity or IRSA), S3 + EC2 + KMS permissions |
| Restore operation | Restore name, source backup, target namespaces, resource count, PVC bindings, completion status |
