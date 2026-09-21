# clusters/homelab

Overlay for the **bare-metal cluster** (3× mini PCs, Ubuntu Server + kubeadm, amd64) — the production-shaped environment.

This is the sync target of the root app-of-apps in `bootstrap/`. It selects platform components from `platform/` and hosts the apps ApplicationSet.

| Path | Purpose |
|---|---|
| `apps-applicationset.yaml` | Generates one Argo CD Application per application repo (path `deploy/overlays/homelab`) |
| `platform.yaml` | Argo CD Application(s) wiring `platform/` components for this cluster |

Differences from `clusters/k3d`: full HA platform (Cilium, MetalLB, Envoy Gateway, cert-manager with Let's Encrypt DNS-01, Longhorn with replication), VPN/edge networking, and production resource sizing.

Populated during Phase 1–2; see `docs/plan.md`.