# mantooth-homelab

GitOps and platform configuration for a home Kubernetes lab.

This repository is the **source of truth for what runs in the cluster**: platform components (CNI, ingress, storage, secrets, policy), cluster overlays, and the ApplicationSet that onboards application repositories. Argo CD continuously reconciles the cluster to match this repo.

Application **source code does not live here** — each app is its own repository that also owns its deployment manifests. See ADR-002 in `docs/decisions.md`.

## Documentation

- [`docs/plan.md`](docs/plan.md) — full architecture, hardware, and roadmap
- [`docs/decisions.md`](docs/decisions.md) — architecture decision records (ADRs)
- [`docs/phase-0-quickstart.md`](docs/phase-0-quickstart.md) — get a local k3d + Argo CD pipeline running
- [`docs/phase-0.5-vm-dry-run.md`](docs/phase-0.5-vm-dry-run.md) — rehearse the real cluster in VMs before buying hardware
- [`docs/notes/storage-architecture.md`](docs/notes/storage-architecture.md) — storage layers, disk layout, replication, backups
- [`docs/status.md`](docs/status.md) — current state and next actions (handoff)

## Layout

| Path | Purpose |
|---|---|
| `bootstrap/` | One-time cluster bring-up and the root Argo CD app-of-apps |
| `platform/` | Platform components, grouped by concern |
| `clusters/` | Per-cluster overlays (`k3d` local, `homelab` bare metal) |
| `docs/` | Plan, ADRs, quickstarts |

## Status

Planning complete. Phase 0 (local k3d + Argo CD + first application pipeline) in progress.