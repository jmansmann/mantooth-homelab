# AGENTS.md — mantooth-homelab

Conventions and orientation for agents working in this repository.

## What this repo is

The GitOps **config** repository for the home Kubernetes cluster. Argo CD reconciles the cluster to match this repo. Read `docs/plan.md` before making structural changes, and record significant, hard-to-reverse decisions in `docs/decisions.md`.

## Layout & boundaries

- `platform/` — platform components (Argo CD, Cilium, MetalLB, Envoy Gateway, cert-manager, Longhorn, External Secrets, Kyverno, observability). One directory per component.
- `clusters/<cluster>/` — cluster-specific overlays and the apps ApplicationSet. `<cluster>` is `k3d` (local dev) or `homelab` (bare metal).
- `bootstrap/` — one-time bring-up; the root app-of-apps Application.
- `docs/` — plan, ADRs, quickstarts.

**Do not put application source code here.** App repos own their source *and* their deployment manifests (ADR-002). This repo only references and discovers them. **OS provisioning lives in `mantooth-ansible`** (ADR-011) — this repo is only what Argo CD syncs.

## Conventions

- **Kustomize-first.** Use Kustomize bases + overlays for our own resources. Consume upstream Helm charts by reference (chart repo + pinned version); never vendor charts.
- **Pin versions.** Every Helm chart and container image is pinned — no floating `latest`.
- **No secrets in Git.** Use External Secrets Operator + a secret backend. Never commit kubeconfigs, node secrets, tokens, or `.env` files (see `.gitignore`).
- **Multi-arch images only** (`linux/amd64`, `linux/arm64`). The dev cluster runs on Apple Silicon and the bare-metal cluster is amd64 (ADR-004).
- **GitOps is the interface.** Change the cluster by committing here (or to an app repo). Do not `kubectl apply` long-lived changes by hand.
- **Write an ADR** in `docs/decisions.md` for significant decisions.

## Verify before committing

```bash
# Render what we manage
kustomize build platform/<component>
kustomize build clusters/k3d

# Validate against the API server (client-side)
kubectl apply --dry-run=client -f <rendered.yaml>
```

- Conventional commit messages (`feat:`, `fix:`, `docs:`, `chore:` …); atomic commits.
- Never commit or push unless explicitly asked.