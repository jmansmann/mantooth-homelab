# Architecture Decision Records

Decisions for the homelab, recorded as ADRs in a single file (a deliberate, low-ceremony convention for a solo project). Each entry follows: **Status / Date / Context / Decision / Alternatives Considered / Consequences**.

Lifecycle: `Proposed → Accepted → (Superseded | Deprecated)`. Don't delete old entries — supersede them.

| # | Title | Status |
|---|---|---|
| [001](#adr-001-three-node-talos-linux-ha-cluster) | Three-node Talos Linux HA cluster | Accepted |
| [002](#adr-002-app-repos-own-their-source-and-deployment-manifests) | App repos own their source and deployment manifests | Accepted |
| [003](#adr-003-github-actions--ghcr--argo-cd-pull-based-gitops) | GitHub Actions → GHCR → Argo CD (pull-based GitOps) | Accepted |
| [004](#adr-004-multi-arch-container-images) | Multi-arch container images | Accepted |
| [005](#adr-005-cloudflare-tunnel--zero-trust-for-public-exposure) | Cloudflare Tunnel + Zero Trust for public exposure | Accepted |
| [006](#adr-006-real-domain--lets-encrypt-dns-01--split-horizon-lan-dns) | Real domain + Let's Encrypt DNS-01 + split-horizon LAN DNS | Accepted |
| [007](#adr-007-longhorn-for-persistent-storage) | Longhorn for persistent storage | Accepted |
| [008](#adr-008-gaming-pc-kept-separate-from-the-247-cluster) | Gaming PC kept separate from the 24/7 cluster | Accepted |
| [009](#adr-009-managed-switch--virtualized-opnsense-lab-vlan-first) | Managed switch + virtualized OPNsense (lab VLAN first) | Accepted |

---

## ADR-001: Three-node Talos Linux HA cluster

### Status
Accepted

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