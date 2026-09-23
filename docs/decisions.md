# Architecture Decision Records

Decisions for the homelab, recorded as ADRs in a single file (a deliberate, low-ceremony convention for a solo project). Each entry follows: **Status / Date / Context / Decision / Alternatives Considered / Consequences**.

Lifecycle: `Proposed → Accepted → (Superseded | Deprecated)`. Don't delete old entries — supersede them.

| # | Title | Status |
|---|---|---|
| [001](#adr-001-three-node-talos-linux-ha-cluster) | Three-node Talos Linux HA cluster | Superseded by 010 |
| [002](#adr-002-app-repos-own-their-source-and-deployment-manifests) | App repos own their source and deployment manifests | Accepted |
| [003](#adr-003-github-actions--ghcr--argo-cd-pull-based-gitops) | GitHub Actions → GHCR → Argo CD (pull-based GitOps) | Accepted |
| [004](#adr-004-multi-arch-container-images) | Multi-arch container images | Accepted |
| [005](#adr-005-cloudflare-tunnel--zero-trust-for-public-exposure) | Cloudflare Tunnel + Zero Trust for public exposure | Accepted |
| [006](#adr-006-real-domain--lets-encrypt-dns-01--split-horizon-lan-dns) | Real domain + Let's Encrypt DNS-01 + split-horizon LAN DNS | Accepted |
| [007](#adr-007-longhorn-for-persistent-storage) | Longhorn for persistent storage | Accepted |
| [008](#adr-008-gaming-pc-kept-separate-from-the-247-cluster) | Gaming PC kept separate from the 24/7 cluster | Accepted |
| [009](#adr-009-managed-switch--virtualized-opnsense-lab-vlan-first) | Managed switch + virtualized OPNsense (lab VLAN first) | Accepted |
| [010](#adr-010-ubuntu-server--kubeadm-on-bare-metal) | Ubuntu Server + kubeadm on bare metal | Accepted |
| [011](#adr-011-ansible-manages-the-os-layer) | Ansible manages the OS layer | Accepted |
| [012](#adr-012-makefiles-as-the-standard-repo-command-interface) | Makefiles as the standard repo command interface | Accepted |
| [013](#adr-013-helm-for-upstream-components-kustomize-for-first-party-manifests) | Helm for upstream components, Kustomize for first-party manifests | Accepted |
| [014](#adr-014-longhorn-on-shared-nvme-with-three-replicas) | Longhorn on shared NVMe with three replicas | Accepted |
| [015](#adr-015-media-and-app-data-on-longhorn-backed-up-to-r2) | Media and app data on Longhorn, backed up to R2 | Accepted |

---

## ADR-001: Three-node Talos Linux HA cluster

### Status
Superseded by [ADR-010](#adr-010-ubuntu-server--kubeadm-on-bare-metal)

> **Note:** Superseded. The primary cluster now runs Ubuntu Server + kubeadm to maximize Linux/SRE exposure. Retained for historical context.

### Date
2026-09-20

### Context
The primary goal is deep Kubernetes learning, specifically control-plane internals relevant to managed offerings (GKE/EKS). A single node or a lightweight distribution would not exercise HA, etcd quorum, or realistic upgrades. Hardware must be quiet, low-heat, and fit a 1-bedroom apartment.

### Decision
Run a three-node Kubernetes cluster on identical used x86 mini PCs, using **Talos Linux**. All three nodes are control-plane + worker with **stacked etcd** and a **control-plane VIP** for the API server.

### Alternatives Considered
- **Single node + VMs (Proxmox/incus)** — cheapest, quietest, but no real clustering/HA or control-plane learning.
- **Raspberry Pi / SBC cluster** — quiet and low-power, but ARM, limited RAM/IO, weak for CI/CD and media workloads.
- **k3s / kubeadm** — viable; k3s is lighter but hides control-plane detail, kubeadm is maximally manual. Talos gives a declarative, immutable, API-driven control plane that maps well to managed-cluster concepts without the OS burden.

### Consequences
- Real etcd quorum and HA behavior; tolerates one node failure.
- Talos is API/config-driven (GitOps-friendly) and requires no OS maintenance.
- Three identical nodes simplify tooling but cost more than one.
- Workloads share nodes with the control plane; acceptable at personal scale.

---

## ADR-002: App repos own their source and deployment manifests

### Status
Accepted

### Date
2026-09-20

### Context
We need a repository strategy covering application source, cluster/platform config, and the manifests Argo CD syncs. The goal is to mirror production boundaries and keep the GitOps repo small and readable.

### Decision
Two kinds of repos:
- **`mantooth-homelab`** (config repo): platform components, cluster overlays, and an Argo CD **ApplicationSet** that discovers app repos and generates one Application each.
- **App repos** (`<app>`): source, Dockerfile, **and** their own deployment manifests under `deploy/overlays/<cluster>/`.

CI builds the image and bumps the tag **in the app repo**; Argo CD deploys from there.

### Alternatives Considered
- **Centralized config repo** (app repos hold source only; manifests in `mantooth-homelab`) — simpler visibility, but diverges from the "app team owns their deployment" boundary we want to practice.
- **Full monorepo** — simplest to start, but mixes concerns and does not model production.

### Consequences
- Deployments are spread across repos; the ApplicationSet is the single index of what is deployed.
- The config repo stays small and only holds platform + discovery.
- Each app is self-contained and independently deployable.
- Onboarding an app = create a repo that follows a convention; the ApplicationSet discovers it.
- Discovery requires a GitHub token secret for the SCM provider generator (or an explicit ApplicationSet list before auto-discovery is enabled).

---

## ADR-003: GitHub Actions → GHCR → Argo CD (pull-based GitOps)

### Status
Accepted

### Date
2026-09-20

### Context
We need CI/CD that is production-shaped, low-maintenance, and works offline-capable later. The cluster nodes are amd64; the dev Mac is arm64.

### Decision
GitHub Actions (native amd64) builds and pushes images to **GHCR**. **Argo CD** runs in-cluster and pulls desired state from Git. Deployment is pull-based; nothing external reaches into the cluster. A self-hosted Gitea/Forgejo + Actions Runner Controller pipeline is a later migration/learning project, with GitHub kept as a mirror.

### Alternatives Considered
- **Fully local CI now (Gitea + in-cluster runners)** — pure local, but blocked until the cluster exists and adds maintenance burden early.
- **Gaming PC as a CI runner** — an x86 runner before the cluster exists, but inconsistent availability and extra heat; not a good primary path.

### Consequences
- No local CI infrastructure to maintain in Phase 0.
- Deployment remains local and pull-based even though CI is cloud-hosted.
- Requires a private-repo strategy and image-pull credentials for GHCR if packages are private.
- The "app pipeline writes the image tag to Git" boundary is exercised directly.

---

## ADR-004: Multi-arch container images

### Status
Accepted

### Date
2026-09-20

### Context
Development happens on an Apple Silicon Mac (arm64) running a local k3d cluster; the target clusters (k3d on the Mac and the future bare-metal cluster) differ in architecture. A Mac-built image without care will not run on amd64 nodes.

### Decision
Build **all** images for `linux/amd64` **and** `linux/arm64` using `docker buildx` + QEMU in GitHub Actions. `linux/amd64` is authoritative for the bare-metal cluster; `linux/arm64` serves local k3d.

### Alternatives Considered
- **amd64 for cluster, arm64 only locally** — fewer moving parts, but risks mismatched tags and confusion.
- **Force amd64 everywhere (emulation on the Mac)** — one architecture, but slow and unnecessary.

### Consequences
- The same image tag works in every environment.
- Slightly longer builds from cross-arch emulation.
- Developers must not "just build locally" and push a single-arch image.

---

## ADR-005: Cloudflare Tunnel + Zero Trust for public exposure

### Status
Accepted

### Date
2026-09-20

### Context
Self-hosted apps must be reachable from anywhere and shared with friends, without exposing the home network or IP.

### Decision
Publish services via **Cloudflare Tunnel** (`cloudflared` deployed in-cluster) with **Cloudflare Access (Zero Trust)** in front of anything sensitive. No inbound ports are opened; DNS, TLS, WAF, and SSO are handled at Cloudflare.

### Alternatives Considered
- **WireGuard/Tailscale VPN only** — most secure, but not "open a URL anywhere" and requires clients.
- **Self-managed reverse proxy + port forward** — maximum learning but exposes the home IP and shifts all security burden onto us.

### Consequences
- No open ports, hidden origin, free TLS, built-in DDoS/WAF.
- Ties ingress availability to Cloudflare.
- Admin/sensitive services must be gated by Access + SSO (Authentik) — enforced before any public exposure.

---

## ADR-006: Real domain + Let's Encrypt DNS-01 + split-horizon LAN DNS

### Status
Accepted

### Date
2026-09-20

### Context
Local-network-first access is the priority. Clients (Mac, phone) should reach apps by name with valid TLS, without public exposure and without installing a private CA on every client.

### Decision
Use a **real registered domain** with **Let's Encrypt certificates issued via the DNS-01 challenge** (cert-manager + a Cloudflare API token — no inbound ports). A **LAN DNS server** provides split-horizon resolution: `*.<DOMAIN>` → the MetalLB LAN VIP internally, while public DNS later points to the Cloudflare Tunnel.

### Alternatives Considered
- **Internal CA + self-signed** — no public dependency, but requires installing/trusting a CA on every client.
- **Plain IPs (NodePort/MetalLB)** — simplest, but no names or TLS and poor learning value.

### Consequences
- Valid, universally trusted certificates on LAN clients with no client-side trust setup.
- Requires maintaining split-horizon DNS (public vs. internal answers).
- Depends on DNS-01 (Cloudflare API token) rather than HTTP-01.
- The same hostnames later work publicly by changing only the DNS answer.

---

## ADR-007: Longhorn for persistent storage

### Status
Accepted

### Date
2026-09-20

### Context
Workloads (photo/file apps, databases) need replicated, dynamically provisioned persistent storage on bare metal, with backup capability.

### Decision
Use **Longhorn** as the CSI storage layer, with replica data on the per-node SATA SSDs and backups to Cloudflare R2 (paired with Velero for cluster-level backup).

### Alternatives Considered
- **Local-path provisioner** — no replication; acceptable for throwaway data only.
- **Ceph/Rook** — more powerful but heavy and complex for three small nodes.
- **A dedicated NAS (NFS)** — another device and cost; not needed at this scale.

### Consequences
- Replicated volumes survive a single node failure.
- Useful replica count is limited by three data disks; usable capacity ≈ total ÷ replicas.
- Requires per-node dedicated data disks.
- Adds a component to operate (a deliberate learning opportunity).

---

## ADR-008: Gaming PC kept separate from the 24/7 cluster

### Status
Accepted

### Date
2026-09-20

### Context
An existing gaming PC (x86, 32 GB RAM, dedicated GPU, 2×512 GB NVMe) is available. It is powerful but idles at 50–100 W+ and produces noticeable heat/noise — at odds with the quiet, low-heat constraint in a 1-bedroom apartment. It is also used for gaming.

### Decision
Keep the gaming PC **separate** from the 24/7 cluster. Use it for Phase 0 development, on-demand CI/GPU jobs (e.g. accelerating Immich), and gaming. Do not fold it into the cluster as a permanent node.

### Alternatives Considered
- **Fold in as a worker** — maximum compute, but hot, loud-ish, and awkward to game on.
- **Dual-purpose via Proxmox + GPU passthrough** — powerful but complex and fragile.
- **Harvest parts only** — leaves it unusable for gaming; unnecessary here.

### Consequences
- The cluster stays quiet and cool; the gaming PC runs only when needed.
- GPU-accelerated workloads either run outside the cluster or join via an on-demand GPU worker later.
- Slightly less total compute during peak experiments.

---

## ADR-009: Managed switch + virtualized OPNsense (lab VLAN first)

### Status
Accepted

### Date
2026-09-20

### Context
Networking is a learning goal. We want hands-on experience with VLANs and firewalling/routing without jeopardizing the household's internet.

### Decision
Use a **managed switch** for VLAN segmentation, and run **OPNsense virtualized** on a cluster node as a **lab-VLAN router** initially — not as the sole internet gateway. Cloudflare Tunnel provides public ingress during this period. A dedicated 2-NIC appliance can be added later to promote the firewall to the edge.

### Alternatives Considered
- **Dedicated firewall appliance immediately** — cleaner separation, but extra cost and complexity before basics are proven.
- **Unmanaged switch only** — cheapest, but no VLAN learning.

### Consequences
- Safe, incremental networking learning; a rebooting node won't take down home internet.
- Requires VLAN trunking / router-on-a-stick on a node's NIC.
- Edge routing remains with the ISP router until we deliberately change it.

---

## ADR-010: Ubuntu Server + kubeadm on bare metal

### Status
Accepted

### Date
2026-09-20

### Context
The learning goals center on platform/SRE/Kubernetes work. Talos Linux (ADR-001) abstracts away the OS entirely — no shell, no package management, managed node upgrades, managed certificates. That removes precisely the Day-2 complexity (node upgrades, certificate expiry, config drift, containerd/kernel/network tuning) that the user wants hands-on exposure to, and which they confront professionally. Full-stack Linux exposure is therefore a higher priority than Talos' low operational burden. The hardware is unchanged (3× used x86 mini PCs).

### Decision
Run **Ubuntu Server LTS** on all three mini PCs and install Kubernetes with **kubeadm**. All three nodes are control-plane + worker with stacked etcd, fronted by a control-plane VIP (kube-vip or keepalived + haproxy). Container runtime: **containerd**. The OS layer is managed with **Ansible** (ADR-011). Talos may be revisited later by re-imaging a node, as a deliberate contrast exercise.

### Alternatives Considered
- **Talos Linux** — lowest operational burden and strong GitOps ergonomics, but hides the Linux/OS layer that is a primary learning target. Superseded.
- **RKE2 on Ubuntu** — production-shaped and less toil, but still bundles considerable automation and reduces control-plane/OS surface.
- **k3s/k0s on Ubuntu** — good Linux exposure with minimal ops, but the control plane is more heavily abstracted than kubeadm.
- **Debian/Rocky instead of Ubuntu** — equally valid; Ubuntu chosen for the largest documentation/community footprint.

### Consequences
- Maximum exposure to Linux and the Kubernetes control plane: systemd, containerd, kubelet, PKI, kube-proxy/netfilter, etcd, and version upgrades.
- Higher ongoing toil: OS and kernel patching, coordinated `kubeadm` upgrades (drain → upgrade → uncordon), etcd upgrades, and **kubeadm certificate expiry (~1 year)** must be managed.
- Config drift and snowflake risk — mitigated by Ansible (ADR-011), etcd snapshots, and documented runbooks.
- Nodes trend toward pets rather than cattle; recovery is more manual than re-imaging.
- Skills transfer directly to most real-world/self-managed Kubernetes environments.

---

## ADR-011: Ansible manages the OS layer

### Status
Accepted

### Date
2026-09-20

### Context
With raw Ubuntu + kubeadm (ADR-010), node configuration is manual by default and drifts quickly. Ansible is itself a widely used SRE skill, so automating the OS layer both reduces risk and adds a relevant learning axis.

### Decision
Maintain an **Ansible** codebase — in a dedicated repository (`mantooth-ansible`) to keep this GitOps repo focused on cluster desired state — that encodes the node baseline and lifecycle. Initial scope:
- Base: users, SSH hardening, time sync, unattended-upgrades policy, firewall rules.
- Kubernetes prerequisites: swap off, kernel modules (`overlay`, `br_netfilter`), sysctl (`ip_forward`, bridge-nf-call-iptables), containerd config (systemd cgroup driver).
- Cluster: `kubeadm`/`kubelet`/`kubectl` packages, control-plane VIP (kube-vip), join tokens.
- Day-2: patch runs, `kubeadm upgrade` orchestration (drain/upgrade/uncordon), certificate renewal checks.

### Alternatives Considered
- **Manual + runbooks only** — maximum manual learning, but drift and human error compound over time.
- **Cloud-init only** — good for first boot, but not for ongoing convergence/patching.
- **NixOS** — powerful declarative OS, but a steeper detour and less representative of typical SRE environments.

### Consequences
- Reproducible node builds; drift is detectable and correctable by re-running playbooks.
- Adds a repo and a skill to maintain; playbooks must be tested.
- Secret handling matters: Ansible Vault (or SOPS) for any secrets; never commit plaintext.
- The Ansible repo becomes part of the disaster-recovery story (rebuild a node from code).

---

## ADR-012: Makefiles as the standard repo command interface

### Status
Accepted

### Date
2026-09-22

### Context
Each repo needs a consistent, discoverable way to run its checks and local tasks. The stack is Go + Docker + Kustomize + kubectl + Argo CD, with CI in GitHub Actions. Without a convention, every repo invents its own commands and the local loop drifts from what CI actually runs.

### Decision
Every repo exposes a thin **`Makefile`** as its command interface, with a shared target vocabulary. `verify` is mandatory and is the same quality gate CI runs. App repos add `build`, `image`, `manifests`, `deploy`, `port-forward`; the config repo adds `render`, `validate`, `bootstrap`. `help` is the default target. Targets are thin wrappers around existing tools, and CI invokes `make verify` rather than duplicating commands.

### Alternatives Considered
- **npm scripts** — the wrong toolchain for a Go/Kustomize repo; adds a Node runtime and a package manager purely as a script runner.
- **`just` / `Task` (Taskfile)** — nicer syntax, but not preinstalled on macOS or GitHub runners, adding a bootstrap dependency for no functional gain.
- **Earthly / Dagger** — reproducible containerized pipelines; overkill at this scale and duplicates CI.
- **README commands only** — cheapest, but drifts from CI and varies per repo.

### Consequences
- One vocabulary across repos; `make verify` is identical locally and in CI.
- CI calls `make` targets, so local and CI commands cannot diverge.
- Make's quirks apply (tab-sensitive, no dependency management) — acceptable for thin wrappers.
- A future frontend keeps npm scoped inside its own directory; Make remains the top-level orchestrator.

---

## ADR-013: Helm for upstream components, Kustomize for first-party manifests

### Status
Accepted

### Date
2026-09-22

### Context
The platform leans on upstream charts (Cilium, MetalLB, Envoy Gateway, cert-manager, Longhorn, External Secrets, Kyverno, kube-prometheus-stack), while the repo also owns first-party resources: ApplicationSets, cluster overlays, and the deployment manifests that app repos ship (ADR-002). We need one consistent rendering strategy so apps and platform components don't each invent their own. Helm and Kustomize solve different problems — packaging/parameterization vs. patching a base per environment — and Argo CD renders both natively.

### Decision
- **Upstream / third-party components → Helm**, consumed **by reference** (chart repo + pinned chart version) with values committed to Git. Never vendor charts.
- **First-party manifests** (cluster overlays, ApplicationSets, app deployment manifests) → **Kustomize** bases + overlays.
- Escalate a first-party component to a Helm chart **only** when it genuinely needs reuse or heavy parameterization; don't template trivial manifests.
- Argo CD renders both. We do not run `helm install`; Argo owns lifecycle and state.

### Alternatives Considered
- **All-Helm** — uniform with work experience, but adds a chart + values to every app and hides the rendered result until `helm template`.
- **All-Kustomize (incl. upstream via `helmCharts`)** — avoids Helm releases entirely, but gives up chart versioning/dependency ergonomics for upstream components.
- **CUE / Timoni, Tanka (jsonnet), Helmfile, ytt/kapp** — more typing or power, but niche, steeper to learn, or redundant once Argo ApplicationSets exist.

### Consequences
- A clear, enforceable rule: upstream pinned by chart version, first-party readable as plain YAML with reviewable diffs.
- Two tools to know, each used in its natural role; skills transfer both ways.
- Upstream `values` files become part of the config repo and are reviewed like code.
- A first-party component can graduate to a chart later without changing the platform rule.

---

## ADR-014: Longhorn on shared NVMe with three replicas

### Status
Accepted

### Date
2026-09-20

### Context
The cluster needs resilient persistent storage. Initial hardware is deliberately minimal: **one 1 TB NVMe per node** (the SATA SSD is deferred). OS, etcd, and Longhorn data therefore share a single physical disk per node. The goal is the maximum redundancy achievable with three nodes.

### Decision
Start with **NVMe-only** storage. Each node's NVMe is **LVM-partitioned** into a root logical volume (OS) and a Longhorn data logical volume — LVM so the planned SATA SSD can later extend the volume group or be added as a second Longhorn disk **without reformatting**. **etcd stays on the local NVMe** (never on Longhorn). Longhorn runs at **replicaCount = 3** (one replica per node) for all volumes.

### Alternatives Considered
- **SATA data disk from day one** — decouples Longhorn data from OS/etcd and removes the correlated failure, but adds cost before it's needed.
- **2 replicas** — ~1.5 TB usable and survives one node loss, but a second failure during rebuild risks data loss.
- **local-path provisioner** — no replication; unsuitable for state.

### Consequences
- **Redundancy ceiling:** survives any single node/disk loss (Longhorn keeps 2 replicas; etcd quorum 2/3). Cannot survive two simultaneous failures.
- **Correlated failure:** a disk failure loses that node's OS + etcd member + replica together; there is no headroom for a second failure until the node is rebuilt.
- **IO contention:** etcd fsyncs compete with Longhorn writes on the same device.
- **Capacity:** 3 replicas everywhere ⇒ usable ≈ raw ÷ 3 (~1 TB total), shared by all workloads.
- LVM partitioning preserves a clean upgrade path to the SATA SSD.
- Offsite backups (ADR-015) are mandatory for total-loss protection.

---

## ADR-015: Media and app data on Longhorn, backed up to R2

### Status
Accepted

### Date
2026-09-20

### Context
Photos (Immich) and general files (Nextcloud) total hundreds of GB, alongside per-app databases. We want local-first access that also survives total local loss.

### Decision
Store media and app data on **Longhorn volumes** (replicated 3×, ADR-014), with **Velero + Longhorn backups to Cloudflare R2** (S3-compatible). App databases (e.g. Postgres) run as StatefulSets or via an operator (CloudNativePG) on Longhorn PVCs. Position R2 as the **backup/offsite tier**, not the primary.

### Alternatives Considered
- **MinIO in-cluster** — S3 API for apps, but more moving parts to operate.
- **Cloudflare R2 as primary** — cheap and resilient, but not local-first (depends on internet) and adds latency.
- **Local-path volumes for media** — no replication; a disk loss would drop media.

### Consequences
- Local-first, offline-capable; media available without internet.
- Media is stored 3× locally, consuming replicated capacity (a real constraint at ~1 TB usable) — this is accepted for safety.
- Backup schedules and restore drills become required operations.
- R2 credentials are managed via External Secrets Operator (never in Git).