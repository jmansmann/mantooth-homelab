# AGENTS.md — mantooth-homelab

Conventions and orientation for agents working in this repository.

## What this repo is

The GitOps **config** repository for the home Kubernetes cluster. Argo CD reconciles the cluster to match this repo. Read `docs/plan.md` before making structural changes, and record significant, hard-to-reverse decisions in `docs/decisions.md`.

## Layout & boundaries

- `platform/` — platform components (Argo CD, Cilium, MetalLB, Envoy Gateway, cert-manager, Longhorn, External Secrets, Kyverno, observability). One directory per component.
- `clusters/<cluster>/` — cluster-specific overlays and the apps ApplicationSet. `<cluster>` is `k3d` (local dev) or `homelab` (bare metal).
- `bootstrap/` — one-time bring-up; the root app-of-apps Application.
- `docs/` — plan, ADRs, quickstarts, and `docs/notes/` for deeper references (e.g. storage architecture).

**Do not put application source code here.** App repos own their source *and* their deployment manifests (ADR-002). This repo only references and discovers them. **OS provisioning lives in `mantooth-ansible`** (ADR-011) — this repo is only what Argo CD syncs.

## Conventions

- **Manifest management (ADR-013): Helm for upstream, Kustomize for first-party.** Consume upstream/third-party components as Helm charts **by reference** (chart repo + pinned version, values in Git) — never vendor charts. Manage our own resources (cluster overlays, ApplicationSets, app manifests) with Kustomize bases + overlays. Escalate a first-party component to a chart only when it truly needs reuse/parameterization; don't template trivial manifests.
- **Pin versions.** Every Helm chart and container image is pinned — no floating `latest`.
- **No secrets in Git.** Use External Secrets Operator + a secret backend. Never commit kubeconfigs, node secrets, tokens, or `.env` files (see `.gitignore`).
- **Multi-arch images only** (`linux/amd64`, `linux/arm64`). The dev cluster runs on Apple Silicon and the bare-metal cluster is amd64 (ADR-004).
- **GitOps is the interface.** Change the cluster by committing here (or to an app repo). Do not `kubectl apply` long-lived changes by hand.
- **Write an ADR** in `docs/decisions.md` for significant decisions.

## Verify before committing

```bash
make verify    # render every kustomization under platform/ and clusters/
make validate  # client-side validate clusters/k3d against the API server
```

`make help` lists all targets. CI uses the same `make verify` (ADR-012).

- **Create changes only — never stage, commit, or push.** Leave edits **unstaged**; Jimmy reviews the diff and handles staging, commits, and pushes himself. Do not run `git add`, `git commit`, `git push`, or history-rewriting commands unless explicitly asked in the same message.
- Conventional commit messages (`feat:`, `fix:`, `docs:`, `chore:` …); atomic commits (when Jimmy commits).