# Storage Architecture

How storage is layered, partitioned, replicated, and backed up. Companion to ADR-014 and ADR-015.

## The layers

```
Pods (Immich, Nextcloud, Postgres…)
   │  request a PersistentVolumeClaim (PVC)
   ▼
StorageClass            ← differs per cluster overlay
   │   k3d:     local-path  /  Longhorn
   │   homelab: Longhorn    /  local-path
   ▼
CSI driver → PersistentVolume → node disk
   │
   ▼
Physical disk (set up by Ansible, NOT by Kubernetes)
```

**Key point:** Kubernetes does **not** partition disks. It allocates *volumes* through a CSI driver. Partitioning, filesystems, LVM, and iSCSI are the **node layer** (Ansible), done before Longhorn runs.

## Two different "databases"

| | What it is | Where it lives |
|---|---|---|
| **etcd** | The cluster's database — every API object (Pods, Secrets…) | Local NVMe, `/var/lib/etcd`. Never on Longhorn. |
| **App databases** | Postgres/MySQL for Immich, Nextcloud, etc. | PVCs on Longhorn (StatefulSet or operator). |

etcd is fsync-heavy and latency-sensitive, which is why it stays on a **local** disk and never on replicated/network storage.

## Where each kind of data lives

| Data | Location | Mechanism |
|---|---|---|
| Cluster state | etcd, local NVMe (`/var/lib/etcd`) | control-plane static pod, local disk |
| Container images / logs | OS on NVMe | containerd |
| App databases (Postgres…) | PVC → **Longhorn** | StatefulSet / CloudNativePG |
| Photos (Immich originals) | PVC → **Longhorn** | Longhorn replicated volume |
| "Cloud" files (Nextcloud) | PVC → **Longhorn** | Longhorn |
| Backups | **Cloudflare R2** + Velero | S3-compatible (offsite) |

## Per-node disk layout (NVMe-only, initial)

One 1 TB NVMe per node, **LVM-partitioned**:

```
/dev/nvme0n1
└── LVM volume group (vg0)
    ├── lv_root      ~100–150 GB   → /            (OS, containerd, kubelet)
    └── lv_longhorn  remainder     → /var/lib/longhorn   (Longhorn data)
```

LVM is used deliberately: when the SATA SSD arrives it can **extend `vg0`** or be added as a **second Longhorn disk** without reformatting.

> etcd lives under `/` on `lv_root`, alongside the OS. It is local, fast, and never replicated.

## Replication & the redundancy ceiling

**Longhorn `replicaCount = 3`** for every volume (ADR-014).

| Failure | Survives? | Why |
|---|---|---|
| One node / disk dies | ✅ | 2 replicas remain; etcd quorum 2/3 |
| Two nodes lost | ❌ | etcd loses quorum; replicas below safe count |
| One pod crashes | ✅ | restart / reschedule |
| Total local loss (fire, theft) | ✅ only with offsite R2 | offsite backups |
| Power event | ✅ | UPS + graceful shutdown |

**Correlated failure:** because OS, etcd, and Longhorn share one physical disk, a disk failure removes all three from that node at once. Three-way replication absorbs it — but there is **no headroom for a second failure** until the node is rebuilt, and etcd fsyncs contend with Longhorn writes on the same device. Adding the SATA SSD removes this correlation.

**Capacity math:** 3 replicas everywhere ⇒ usable ≈ raw ÷ 3. With 3× 1 TB, **~1 TB usable total**, shared by media, app DBs, and everything else.

## k3d mock vs. VM dry run

| Real bare metal | k3d on the Mac |
|---|---|
| Separate disks, partitions, LVM | Docker overlay on one APFS volume |
| Longhorn across 3 physical nodes | *runs*, but no real fault isolation |
| Disk failure, IOPS, fsync latency | not reproducible |
| CSI / PVC / StorageClass / StatefulSet behavior | ✅ reproducible |
| Manifests, operators, backup jobs | ✅ reproducible |

k3d validates the **app-level storage contract**; the same PVCs work in both clusters because only the **StorageClass differs per overlay**. For a faithful disk mock (partitions, LVM, Longhorn disks, failure drills), use the **VM dry run** in `docs/phase-0.5-vm-dry-run.md`.

## Backup / recovery summary

- **Longhorn snapshots + backups → R2** for volume-level recovery.
- **Velero → R2** for cluster-object + PV recovery.
- **Restore drills** are part of Phase 5; a backup that has never been restored is not a backup.
- R2 credentials flow through **External Secrets Operator** — never committed.