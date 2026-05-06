---
name: velero
description: >-
  Velero backup and disaster recovery decision system for Kubernetes. Use for backup schedule
  design, restore procedures, CSI snapshot integration, IAM/S3 configuration, and monitoring.
  Do NOT use for general Kubernetes workloads (use kubernetes skill) or EKS cluster config
  (use eks skill) unless backup-specific.
metadata:
  author: SHELYOG
  version: 1.0.0
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
| Design backup schedule | SCHEDULES |
| Configure CSI snapshots | CSI_SNAPSHOTS |
| Test restore procedure | RESTORE |
| Monitor backup health | MONITORING |
| Troubleshoot failed backups | TROUBLESHOOTING |

---

## Cross-Cutting Rules

| Decision | Rule |
|---|---|
| Authentication | Pod Identity (preferred) or IRSA — never node-level IAM |
| Encryption | S3 bucket with SSE-KMS; Velero respects bucket-level encryption |
| Retention | Production: 30d minimum; DR copy: cross-region S3 replication |
| Testing | Monthly restore drill to non-prod; document RTO/RPO evidence |
| CSI snapshots | Enable for PV-backed workloads; Velero + CSI snapshot controller |

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

| Setting | Production | Non-Production |
|---|---|---|
| `configuration.backupStorageLocation.bucket` | Dedicated per-cluster | Shared with prefix |
| `configuration.volumeSnapshotLocation` | Same region | Same region |
| `schedules` | Defined in values | Minimal or disabled |
| `resources.requests.memory` | 512Mi | 256Mi |
| `resources.requests.cpu` | 500m | 100m |
| `nodeSelector` | System/platform nodes | Any |

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

### S3 Bucket Requirements

| Requirement | Configuration |
|---|---|
| Encryption | SSE-KMS with dedicated key |
| Versioning | Enabled (protects against accidental deletion) |
| Lifecycle rules | Transition to IA after 30d; delete after retention period |
| Public access | Blocked (all four settings) |
| Cross-region replication | Production DR buckets only |
| Object lock | Consider for compliance workloads |

---

## SCHEDULES

### Standard Schedule Pattern

```yaml
schedules:
  daily-full:
    schedule: "0 2 * * *"
    template:
      ttl: "720h"  # 30 days
      includedNamespaces: ["*"]
      excludedNamespaces: ["kube-system", "velero"]
      snapshotVolumes: true
      storageLocation: default

  hourly-critical:
    schedule: "0 * * * *"
    template:
      ttl: "168h"  # 7 days
      includedNamespaces: ["production-workloads"]
      labelSelector:
        matchLabels:
          backup-priority: critical
      snapshotVolumes: true
```

### Schedule Decisions

| Workload Type | Frequency | Retention | Volumes |
|---|---|---|---|
| Stateless (deployments only) | Daily | 7 days | No |
| Stateful (PVCs) | Hourly | 30 days | Yes (CSI) |
| Critical data | Hourly + pre-change | 90 days | Yes |
| Cluster-wide DR | Daily | 30 days | Yes |

---

## CSI_SNAPSHOTS

### CSI Snapshot Controller (prerequisite)

Deploy Piraeus CSI snapshot controller before Velero CSI integration:

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

Enable in Velero values:
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

### Restore Procedure (read-only from agent — human executes)

1. List available backups: `velero backup get`
2. Describe target backup: `velero backup describe <name> --details`
3. Dry-run restore: `velero restore create --from-backup <name> --dry-run`
4. Execute restore (human/CI only): `velero restore create --from-backup <name>`
5. Verify: `velero restore describe <name>`, check pod/PVC status

### Restore Decisions

| Scenario | Approach |
|---|---|
| Single namespace recovery | `--include-namespaces <ns>` |
| Single resource restore | `--include-resources <type>` + `--selector <labels>` |
| Full cluster DR | New cluster + full restore from cross-region bucket |
| PVC data recovery | Restore with `--restore-volumes=true` |

---

## MONITORING

### Datadog Monitors for Velero

| Monitor | Query Pattern | Threshold |
|---|---|---|
| Backup failure | `velero_backup_failure_total` | > 0 for 15min |
| Backup not running | `velero_backup_last_successful_timestamp` | Age > schedule + buffer |
| Partial failure | `velero_backup_partial_failure_total` | > 0 for 30min |
| Restore failure | `velero_restore_failure_total` | > 0 |

---

## TROUBLESHOOTING

| Problem | Diagnosis | Fix |
|---|---|---|
| Backup stuck InProgress | `velero backup describe --details` | Check node/pod resource pressure; increase timeout |
| S3 permission denied | Check IRSA annotation + trust policy | Verify SA annotation matches IAM role |
| CSI snapshot timeout | VolumeSnapshot stuck | Check CSI driver logs, snapshot controller |
| Partial failure (some items) | `velero backup logs <name>` | Usually CRD issues or webhook timeouts |
| Restore creates duplicate PVs | `--existing-resource-policy=update` not set | Set policy or clean up old PVCs first |
