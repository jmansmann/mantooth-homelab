# Status & Handoff

Living document tracking where the project is. Update it at the end of each work session so the next agent — or you — can resume without re-deriving context.

## Current state

- **Phase:** 0 (pre-hardware) — execution in progress
- **Last updated:** 2026-09-25
- **Hardware:** none purchased
- **Remote:** `origin` = `git@github.com:jmansmann/mantooth-homelab.git`; config repo work is on `main` (root app targets `main`)
- **Cluster:** local k3d cluster `dev` (1 server + 2 agents, Traefik disabled) running; Argo CD `root` and `hello-mantooth` Applications are synced and healthy; local `hello-mantooth-dev` namespace runs a 3-replica dev copy
- **Repo name:** `mantooth-homelab` (bare-metal **cluster** name remains `homelab`)

## Done

- Architecture, hardware BOM (NVMe-only), repo model, and Phase 0–5 roadmap — `docs/plan.md`
- Decisions recorded as ADR-001…015 — `docs/decisions.md` (ADR-001 Talos superseded by ADR-010; storage = ADR-014/015)
- Runbooks: Phase 0 (`docs/phase-0-quickstart.md`) and Phase 0.5 VM dry run (`docs/phase-0.5-vm-dry-run.md`)
- Storage architecture reference — `docs/notes/storage-architecture.md`
- Repo skeleton committed: `bootstrap/`, `platform/`, `clusters/{k3d,homelab}/`
- CLI tooling installed: `k3d` 5.9.0, `argocd` 3.5.3 (kubectl/helm/kustomize already present)
- Config-repo Phase 0 manifests:
  - `bootstrap/root/application.yaml` — root app-of-apps (targets `clusters/k3d` on `main`)
  - `clusters/k3d/kustomization.yaml`, `clusters/k3d/apps-applicationset.yaml` — `list` generator with the `hello-mantooth` element
- k3d lifecycle is reproducible via `make cluster-delete` / `make cluster-up`; `clusters/k3d/k3d-config.yaml` pins the node image and is the place for host bind mounts.
- First app repo `jmansmann/hello-mantooth` scaffolded (Go hello-world, multi-arch Dockerfile, `deploy/{base,overlays/{k3d,homelab}}`, GitHub Actions build → GHCR → tag bump)
- Local k3d `dev` cluster created; Argo CD installed via server-side apply and `argocd-server` rolled out
- `hello-mantooth` initially deployed via local `make dev`; now adopted and managed by Argo CD. The `root` Application syncs `clusters/k3d`, and its ApplicationSet creates the `hello-mantooth` Application.
- Fast local loop now deploys to isolated `hello-mantooth-dev`, so local image changes do not conflict with Argo's `hello-mantooth` namespace. Verified three ready replicas, EndpointSlice entries across all three nodes, in-cluster Service DNS, and requests reaching all three pod hostnames.
- Latest CI run successfully published the multi-arch GHCR image and committed its immutable SHA tag to the app repo (`17b50721`).
- GHCR package anonymously pullable; no image-pull Secret is needed. The app Deployment no longer references `ghcr-pull`.
- Both Git repositories and the GHCR package are public, verified with GitHub CLI/anonymous registry access; no Argo Git credential or image-pull Secret was applied. If a repo becomes private, register it with Argo CD's CLI or declarative credentials sourced from a secret provider.
- Standard repo command interface (ADR-012): `Makefile` in both repos (`make verify` is the CI gate); CI wired to `make verify`; convention documented in the `AGENTS.md` files
- Manifest strategy decided (ADR-013): Helm for upstream components, Kustomize for first-party manifests
- Validated: `kustomize build` (config repo + app base/overlays), `go vet`/`go test`, `docker build` + container smoke test

## Next actions

1. Decide whether to keep `mantooth-homelab` public or make it private before adding real network-specific details. `hello-mantooth` and its GHCR image can remain public as portfolio artifacts.
2. Optional Phase 0: buy a domain and validate cert-manager DNS-01 as described in `docs/phase-0-quickstart.md` §8.
3. Phase 0.5: continue the Ubuntu/kubeadm VM dry run in `docs/phase-0.5-vm-dry-run.md`.
4. For hands-on learning before the full observability phase, try a resource-limited Prometheus/Grafana setup locally in k3d (managed by Argo CD, preferably via the pinned upstream Helm chart).
5. Merge the local Kustomize k3d overlay change to three `hello-mantooth` replicas if you want the Argo-managed copy to use three too; the isolated local copy already demonstrates DNS and EndpointSlice balancing.
6. Add the database app's required host bind mount(s) to `clusters/k3d/k3d-config.yaml` before deleting/recreating k3d; host paths survive, while data stored only inside node containers does not.

## Open questions / deferred

- **App auto-discovery** — the `scmProvider` generator is deferred until there are 2+ app repos; the `list` generator is used until then.
- **`mantooth-ansible` repo** — planned (ADR-011) for OS/`kubeadm` lifecycle; not created yet.
- **Immich GPU strategy** — deferred to Phase 4 (run outside the cluster vs. on-demand GPU worker on the gaming PC).

## Environment notes

- **Local path:** `~/development/mantooth-homelab` (config) and `~/development/hello-mantooth` (first app)
- **Dev machine:** Apple Silicon (arm64); cluster target is amd64 → **always build multi-arch** (ADR-004).
- **Agents:** run from `~/development` (workspace root) or a repo; conventions live in the `AGENTS.md` files. **Create changes only — never stage, commit, or push** (Jimmy handles that).
- **Hardware plan:** 3× used x86 mini PCs running **Ubuntu Server + kubeadm**, OS layer managed with **Ansible** (ADR-010, ADR-011; supersedes ADR-001); gaming PC stays separate (ADR-008).
- **Storage plan:** NVMe-only initially (1 TB/node, LVM); Longhorn at **3 replicas** (~1 TB usable); media on Longhorn with **R2** backups (ADR-014, ADR-015).
