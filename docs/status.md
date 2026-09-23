# Status & Handoff

Living document tracking where the project is. Update it at the end of each work session so the next agent — or you — can resume without re-deriving context.

## Current state

- **Phase:** 0 (pre-hardware) — execution in progress
- **Last updated:** 2026-09-22
- **Hardware:** none purchased
- **Remote:** `origin` = `git@github.com:jmansmann/mantooth-homelab.git`; work currently on branch `jmansmann/phase-0` (root app targets `main`)
- **Cluster:** local k3d cluster `dev` (1 server + 2 agents, Traefik disabled) running; Argo CD installed and healthy in `argocd`
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
- First app repo `jmansmann/hello-mantooth` scaffolded (Go hello-world, multi-arch Dockerfile, `deploy/{base,overlays/{k3d,homelab}}`, GitHub Actions build → GHCR → tag bump)
- Local k3d `dev` cluster created; Argo CD installed via server-side apply and `argocd-server` rolled out
- `hello-mantooth` **running in k3d** via the local `make dev` loop (build → `k3d image import` → apply → rollout); verified serving over port-forward. This is a local escape hatch — the Argo CD/GitOps path is still pending bootstrap.
- Standard repo command interface (ADR-012): `Makefile` in both repos (`make verify` is the CI gate); CI wired to `make verify`; convention documented in the `AGENTS.md` files
- Manifest strategy decided (ADR-013): Helm for upstream components, Kustomize for first-party manifests
- Validated: `kustomize build` (config repo + app base/overlays), `go vet`/`go test`, `docker build` + container smoke test

## Next actions (Phase 0)

1. **Review the unstaged changes** in `mantooth-homelab` and `hello-mantooth`, then stage/commit/push. The root app targets `main`, so the config repo must be on `main` (merge `jmansmann/phase-0`) and both repos pushed before bootstrap.
2. **Give Argo CD read access to the private repos** (Settings → Repositories, or a repo-creds Secret with a GitHub PAT).
3. **Bootstrap the root app** (one-time, by hand):
   ```bash
   kubectl apply -f bootstrap/root/application.yaml
   argocd app get root
   ```
4. **GHCR image pull:** make the `hello-mantooth` package public, or create the `ghcr-pull` secret in the `hello-mantooth` namespace (PAT with `read:packages`).
5. **Verify** end to end: `argocd app list`, `kubectl get pods -n hello-mantooth`, port-forward `svc/hello-mantooth`.

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
