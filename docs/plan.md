# Homelab Build Plan

A personal home lab built as a production-shaped Kubernetes platform: real GitOps, HA control plane, CI/CD, and internet-exposed self-hosted apps — sized for a single-bedroom apartment (quiet, low heat).

> **Placeholders used throughout:** `GITHUB_USER` = your GitHub username/org · `DOMAIN` = your registered domain · `<app>` = an application repository name. Replace them as you go.

---

## 1. Goals

| Area | Goal |
|---|---|
| **Storage** | Photo backup (Google Photos replacement) and general cloud storage (Google Drive replacement); hundreds of GB to start |
| **Compute** | Multi-node Kubernetes for learning, with deep exposure to the control plane |
| **Linux/SRE** | Hands-on Linux systems administration — systemd, containerd, kernel/network tuning, node upgrades, certificate management — built and fixed by hand, not abstracted away |
| **Networking** | Hands-on learning; securely expose services to the public internet |
| **Apps** | Self-hosted personal webapps, reachable from anywhere, shared with friends |
| **Dev/Platform** | A production-like pipeline: CI/CD, environments, redundancy |
| **Priorities** | Local-network access first; public exposure and hardening later |
| **Constraints** | Reasonable cost, quiet, low heat, ~personal scale |

---

## 2. Locked decisions

See `docs/decisions.md` for full ADRs.

| # | Decision |
|---|---|
| 010 | 3-node **Ubuntu Server + kubeadm** HA cluster (all nodes control-plane + worker, stacked etcd, control-plane VIP) — supersedes 001 |
| 002 | **App repos own their source and deployment manifests**; the config repo discovers them via an Argo CD ApplicationSet |
| 003 | **GitHub Actions → GHCR → Argo CD** (pull-based GitOps) for CI/CD |
| 004 | **Multi-arch images** (`linux/amd64`, `linux/arm64`) |
| 005 | **Cloudflare Tunnel + Zero Trust** for public exposure (no open ports) |
| 006 | Real domain + **Let's Encrypt DNS-01** + split-horizon LAN DNS for local access |
| 007 | **Longhorn** for replicated persistent storage |
| 008 | The gaming PC stays a **separate** dev/CI/GPU box — not a 24/7 cluster node |
| 009 | **Managed VLAN switch + virtualized OPNsense** (lab VLAN first; not the sole internet gateway) |
| 011 | **Ansible** manages the OS layer (bootstrap, patching, upgrades) to prevent drift |

---

## 3. Architecture

```
                         Internet
                            │
              Cloudflare (DNS, TLS, WAF, Zero Trust)
                            │  outbound-only tunnel (no inbound ports)
                            ▼
        ┌──────────────────────────────────────────────┐
        │                 Home LAN                      │
        │                                               │
        │   Managed switch (VLANs: trusted/IoT/lab)     │
        │   OPNsense — lab VLAN router (Phase 2+)       │
        │                                               │
        │   LAN DNS (AdGuard / Unbound, split-horizon)  │
        │        │  *.<DOMAIN> → MetalLB VIP            │
        │        ▼                                       │
        │   MetalLB VIP ── Envoy Gateway ── Services    │
        │                                               │
        │   3× Mini PC — Ubuntu + kubeadm (amd64)       │
        │     node1/node2/node3 = control plane+worker  │
        │     stacked etcd · control-plane VIP          │
        │     Cilium · Longhorn · Argo CD · runners     │
        └───────────────────────┬───────────────────────┘
                                │ on demand
                 Gaming PC (x86): dev / CI / GPU jobs / games
```

**Why 3 control-plane nodes:** stacked etcd with 3 nodes gives a real quorum (tolerates one failure) and is the closest bare-metal analog to a managed HA control plane — the exact thing to learn for GKE/EKS work.

**OS layer:** nodes run Ubuntu Server LTS, provisioned and patched by **Ansible** (ADR-011); Kubernetes is installed with **kubeadm** (ADR-010). The OS and node lifecycle are deliberately *not* abstracted — building and fixing them is part of the goal.

**Local-first:** everything is reachable from your Mac and phone on home WiFi *before* anything is exposed publicly. Public access is layered on later via the same Gateway.

---

## 4. Hardware

| Item | Recommendation | Qty | Est. |
|---|---|---|---|
| Compute nodes | Lenovo M920q/M720q Tiny or Dell OptiPlex 7070 Micro (i5-8500T/9500T class) | 3 | $360–540 |
| RAM | 32 GB (2×16 DDR4 SO-DIMM) per node | 3 | $150–210 |
| OS/etcd disk | 1 TB NVMe per node | 3 | $150–210 |
| Data disk | 1 TB 2.5" SATA SSD per node (Longhorn) | 3 | $150–210 |
| Switch | Managed 8-port Gigabit (TP-Link TL-SG108E / Netgear GS308E / used Cisco 2960G) | 1 | $30–60 |
| Firewall | Virtualized OPNsense (no purchase) | — | $0 |
| Rack | 10" mini rack (DeskPi RackMate T1 / GeeekPi) + shelves / 1L mounts | 1 | $60–120 |
| Cabling | Short Cat6 patch cables + keystone patch panel | — | $20–40 |
| UPS | Small line-interactive (~600–900 VA) | 1 | $70–100 |
| Domain | Cheap TLD via Cloudflare Registrar | 1 | ~$10/yr |
| **Total** | | | **~$1,000–1,500** |

Notes:

- **CPU:** target **i5-8500T / i5-9500T (6c/6t, 8th–9th gen)**; step up to **i7-8700T/9700T or i5-10500T** only if the delta is small. Cores/threads matter more than clocks or generation here — 8th→9th is a minor refresh, and 12th-gen IPC gains aren't worth the platform premium.
- **RAM:** **32 GB (2×16 GB) used DDR4 SO-DIMM per node**, both slots populated as a matched pair. Prefer DDR4 over DDR5 — the bandwidth difference is negligible for etcd/Longhorn/containers (latency- and IO-bound), and used DDR4 pulls from retired office PCs are far cheaper. Dual-channel and capacity matter more than memory speed.
- Buy the three nodes as one matched lot from a refurb seller; used DDR4 SO-DIMM is cheap in bulk.
- Idle power ≈ 45 W, loaded ≈ 150 W — effectively silent and cool. The gaming PC stays off the 24/7 path for exactly this reason.
- **OPNsense caveat:** do not make a *virtualized* OPNsense your sole internet gateway initially — if that node reboots, the whole apartment loses internet. Start it as a lab-VLAN router; promote it to the edge (or add a dedicated 2-NIC N100 appliance, ~$150–200) once comfortable.

---

## 5. Repository model

Three repositories serve the lab:

| Content | Repo |
|---|---|
| Platform components, cluster overlays, ApplicationSets, bootstrap | **`mantooth-homelab`** (this repo — the GitOps/config repo) |
| Application source, Dockerfile, tests, **and** deployment manifests | **One repo per app** (`<app>`) |
| Node OS provisioning and patching (Ansible) | **`mantooth-ansible`** (see ADR-011) |
| Third-party Helm charts | Referenced by URL + pinned version (never vendored) |

The `mantooth-homelab` repo holds an **Argo CD ApplicationSet** that generates one Application per app repo. Onboarding a new app = creating a repo that follows the convention; the ApplicationSet picks it up.

**Deployment flow:**

1. Push to an app repo → GitHub Actions builds a multi-arch image → pushes to GHCR.
2. CI updates the image tag in that same app repo's manifests (or Argo CD Image Updater does it).
3. Argo CD notices the commit and syncs the new version.

This reproduces the real "app pipeline ↔ GitOps repo" boundary that platform teams operate.

**App repo convention:**

```
<app>/
├── Dockerfile
├── src/
├── deploy/
│   ├── base/                     # Kustomize base
│   └── overlays/
│       ├── k3d/                  # local dev cluster
│       └── homelab/              # bare-metal cluster
└── .github/workflows/build.yml   # multi-arch build → GHCR → tag bump
```

---

## 6. Platform stack

| Concern | Component | Managed-cloud analog |
|---|---|---|
| GitOps | Argo CD (+ ApplicationSets, Image Updater later) | Config Sync / Fleet |
| CNI | Cilium (eBPF, kube-proxy replacement, network policy, Hubble) | GKE Dataplane V2 / EKS VPC CNI |
| Load balancing | MetalLB (L2) | Cloud LoadBalancer |
| Ingress | Gateway API + Envoy Gateway | GKE Gateway / ALB Ingress |
| Certificates | cert-manager (Let's Encrypt DNS-01) | Managed certs |
| Storage | Longhorn (replicated CSI) | EBS/GCE PD + StorageClasses |
| Secrets | External Secrets Operator + Vault or SOPS/age | Secrets Manager / IRSA |
| Policy | Kyverno + Pod Security Standards | Anthos policy / OPA |
| Observability | kube-prometheus-stack + Loki + Grafana | Cloud Monitoring |
| Runtime security | Trivy Operator, Falco, cosign image signing | Artifact/registry scanning |
| Backups | Velero + Longhorn → Cloudflare R2 | Managed backups |

Control plane (kubeadm-managed): kube-apiserver, etcd, kube-scheduler, kube-controller-manager — HA, with a control-plane VIP (kube-vip). Container runtime: containerd.

---

## 7. Access design

**Local (Phase 2):**

1. **MetalLB (L2)** assigns the Gateway a real LAN VIP. Reserve a small range on the router **outside DHCP**.
2. **Gateway API / Envoy Gateway** routes hostnames → services.
3. **Split-horizon DNS:** a LAN DNS server (AdGuard Home or OPNsense Unbound) resolves `*.<DOMAIN>` → the MetalLB VIP. The router's DHCP hands this DNS server to clients, so Mac and phone resolve names with **zero public exposure**.
4. **TLS:** real domain + **Let's Encrypt DNS-01** (proves ownership via DNS; no port opened), combined with split-horizon DNS. Valid certs everywhere, no client trust setup.

**Public (Phase 5):** layer **Cloudflare Tunnel + Zero Trust** — same Gateway, different entry path. Public Cloudflare DNS points to the tunnel; internal DNS points to the LAN VIP (same names, different answers). Admin/sensitive apps stay behind Cloudflare Access + SSO.

---

## 8. CI/CD

**Phase 0 onward:** GitHub Actions (native amd64) → GHCR → Argo CD (pull-based). No local CI infrastructure to maintain. The deploy side is fully local even though CI is cloud.

**Phase 5 upgrade:** self-hosted **Gitea/Forgejo + Actions Runner Controller** in-cluster for a fully local pipeline, with GitHub kept as a mirror/backup.

**Arch gotcha:** the Mac is `arm64`, the cluster is `amd64`. Always build multi-arch; never assume a Mac-built image runs in the cluster.

---

## 9. Roadmap

### Phase 0 — Now, on the Mac (no hardware required)
1. Install tooling; create GitHub repos (`mantooth-homelab`, `mantooth-ansible`, first `<app>`).
2. Scaffold the repos and this documentation.
3. Create a local **k3d** cluster + install **Argo CD**.
4. Build a first webapp with a **multi-arch** Dockerfile; GitHub Actions → GHCR; Argo CD deploys it to k3d.
5. Buy a domain + Cloudflare account; validate cert-manager DNS-01 locally.

See `docs/phase-0-quickstart.md`.

### Phase 1 — Physical & OS
6. Rack, switch, cabling; configure VLANs.
7. Bench nodes, upgrade RAM/disks; install Ubuntu Server LTS.
8. **Ansible baseline** (ADR-011): users/SSH, time sync, swap off, kernel modules + sysctl, containerd, `kubeadm`/`kubelet`/`kubectl`, patching policy.
9. `kubeadm init` with a control-plane VIP (kube-vip) + CNI; join the remaining nodes; verify etcd quorum and HA.

### Phase 2 — Core platform → LAN access working
10. Argo CD → Cilium → MetalLB → Gateway API/Envoy Gateway → cert-manager → **LAN DNS** → Longhorn.
11. Reach apps from Mac and phone on WiFi with valid TLS. No public exposure yet.
12. Add OPNsense lab router + VLANs.

### Phase 3 — Platform services
13. Observability (Prometheus/Grafana/Loki); External Secrets Operator; Kyverno + PSS + NetworkPolicies + Trivy.

### Phase 4 — Workloads
14. Immich (photos), Nextcloud or Syncthing+Filebrowser (files), Vaultwarden, Authentik SSO, dashboards.

### Phase 5 — Public, local CI, resilience
15. In-cluster Gitea/Forgejo + ARC runners.
16. Cloudflare Tunnel + Zero Trust for public/friend access.
17. Velero + Longhorn backups → Cloudflare R2; UPS graceful shutdown; node-failure and restore drills; cosign + Falco.
18. Ongoing Linux/SRE drills: `kubeadm upgrade`, certificate renewal, etcd backup/restore.

---

## 10. Risks & gotchas

- **Security sequencing:** stand up Access/Authentik *before* anything is public. Admin UIs always behind Zero Trust.
- **Virtualized firewall:** lab VLAN only until proven; it must not gate the whole home's internet.
- **Split-horizon DNS:** public Cloudflare → tunnel; internal DNS → LAN VIP. Same names, different answers.
- **Image architecture:** build `linux/amd64` (or multi-arch). GitHub runners and cluster are amd64; Mac k3d is arm64.
- **Node/OS lifecycle:** raw Ubuntu + kubeadm means you own patching and upgrades. In particular, **kubeadm certificates expire (~1 year)** — automate renewal and alert on expiry.
- **Config drift / snowflakes:** apply the node baseline exclusively through Ansible; never hand-edit nodes. Snapshot etcd before upgrades.
- **Upgrade discipline:** drain → `kubeadm upgrade` → uncordon, one node at a time; keep a short runbook per operation.
- **GPU apps (Immich):** simplest outside the cluster on the gaming PC, or as an on-demand GPU worker later.
- **Secrets:** never in Git. External Secrets Operator + a backend for cluster secrets; Ansible Vault/SOPS for node secrets; kubeconfigs stay out of every repo.

---

## 11. Linux/SRE learning track

Raw Ubuntu + kubeadm is chosen specifically to exercise these, roughly in order:

| Domain | Where it's practiced |
|---|---|
| systemd, journald, users/SSH, packages | Ansible baseline (Phase 1) |
| Kernel modules, `sysctl`, cgroups v2, namespaces | Ansible baseline + Cilium/eBPF (Phases 1–2) |
| containerd / CRI / OCI runtime | Phase 1 and ongoing |
| Networking: `ip`, nftables, routing, DNS, VLANs | OPNsense + switch + LAN DNS (Phase 2) |
| Storage: LVM, filesystems, NFS/iSCSI | Longhorn + node disks (Phase 2) |
| PKI / TLS / certificates | cert-manager + **kubeadm cert renewal** |
| Debugging: `journalctl`, `strace`, `tcpdump`, `perf` | Throughout |
| K8s node lifecycle: `kubeadm upgrade`, etcd backup/restore | Phase 5 drills |
| Config management at scale | Ansible (ongoing) |

Talos can be revisited later by re-imaging a node — a deliberate contrast in abstraction (see ADR-001, superseded by ADR-010).

---

## 12. Stretch ideas

- **Cluster API (CAPI)** — use the lab as a management cluster to provision workload clusters.
- **Crossplane** — expose the platform as declarative APIs.
- **Backstage** — internal developer portal for your services.
- **Cilium service mesh** or **Istio ambient** — advanced networking.
- **KubeVirt** — run VMs inside Kubernetes.
- **Chaos Mesh** — deliberate failure drills.
- **Multi-cluster** — separate "prod" and "staging" clusters once the first feels easy.
- **Home automation** (Home Assistant), **AdGuard/Pi-hole**, **Tailscale subnet router**, game servers.