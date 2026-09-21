# Status & Handoff

Living document tracking where the project is. Update it at the end of each work session so the next agent — or you — can resume without re-deriving context.

## Current state

- **Phase:** 0 (pre-hardware) — planning complete, execution not started
- **Last updated:** 2026-09-20
- **Hardware:** none purchased
- **Remote:** local repo only; `origin` not yet configured
- **Repo name:** `mantooth-homelab` (bare-metal **cluster** name remains `homelab`)

## Done

- Architecture, hardware BOM, repo model, and Phase 0–5 roadmap — `docs/plan.md`
- Decisions recorded as ADR-001…009 — `docs/decisions.md`
- Phase 0 runbook — `docs/phase-0-quickstart.md`
- Repo skeleton committed: `bootstrap/`, `platform/`, `clusters/{k3d,homelab}/`

## Next actions (Phase 0)

1. Add the GitHub remote and push `main`:
   ```bash
   git remote add origin git@github.com:<GITHUB_USER>/mantooth-homelab.git
   git push -u origin main
   ```
2. Follow `docs/phase-0-quickstart.md`:
   a. Create the local k3d cluster `dev`
   b. Install Argo CD
   c. Bootstrap the root app-of-apps
   d. Create the first `<app>` repo with the multi-arch build pipeline
   e. Onboard it via the apps ApplicationSet

## Open questions / deferred

- **First real webapp** — not yet chosen. Decide before step 2d.
- **App auto-discovery** — the `scmProvider` generator is deferred until there are 2+ app repos; the `list` generator is used until then.
- **Immich GPU strategy** — deferred to Phase 4 (run outside the cluster vs. on-demand GPU worker on the gaming PC).

## Environment notes

- **Local path:** `~/development/mantooth-homelab`
- **Dev machine:** Apple Silicon (arm64); cluster target is amd64 → **always build multi-arch** (ADR-004).
- **Agents:** run from `~/development` (workspace root) or this repo; conventions live in the `AGENTS.md` files.
- **Hardware plan:** 3× used x86 mini PCs running Talos (ADR-001); gaming PC stays separate (ADR-008).