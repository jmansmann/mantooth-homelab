# clusters/k3d

Overlay for the **local development cluster** (k3d on the Mac / Apple Silicon).

This is the sync target of the root app-of-apps in `bootstrap/`. It selects platform components from `platform/` and hosts the apps ApplicationSet.

| Path | Purpose |
|---|---|
| `k3d-config.yaml` | Pinned k3d cluster definition with persistent Mantooth Tasks host mounts |
| `kustomization.yaml` | Renders everything in this directory for the root app-of-apps |
| `apps-applicationset.yaml` | Generates one Argo CD Application per application repo |
| `platform.yaml` | *(planned)* Argo CD Application(s) wiring `platform/` components for this cluster |

Differences from `clusters/homelab`: smaller resource requests, no Longhorn replication (`longhorn` may be omitted for single-replica), local DNS/TLS substitutes.

The ApplicationSet lists `mantooth-tasks` alongside `hello-mantooth`. Merge and
publish the app repository's first immutable image, and merge the image-tag PR,
before merging this onboarding change; that keeps the new Argo CD Application
from attempting to pull its placeholder image.

## Cluster lifecycle

```bash
make cluster-delete # removes k3d node containers and data stored only inside them
make cluster-up     # create/start from k3d-config.yaml, install Argo CD, bootstrap root
```

Edit `k3d-config.yaml` to add required host bind mounts **before** recreating the
cluster. Bind-mounted host directories survive cluster deletion; node-local
container data does not. `cluster-up` starts an existing cluster as-is, so it
does not apply new mount settings until after `cluster-delete` and recreation.

Mantooth Tasks has isolated Mac-backed storage for the local development and
production-like GitOps overlays:

| Purpose | Mac directory | Path in every k3d node |
|---|---|---|
| Local development | `~/.local/share/mantooth-tasks/dev` | `/var/lib/mantooth-tasks/dev` |
| GitOps k3d deployment | `~/.local/share/mantooth-tasks/prod` | `/var/lib/mantooth-tasks/prod` |

The k3d config uses its supported `${HOME}` expansion and `nodeFilters: [all]`,
so either path is available regardless of which node schedules the pod. The
recreation helper creates the two host directories with owner-only permissions,
requires the current context to be `k3d-dev`, and asks for the exact confirmation
`dev` before deleting anything. It then recreates only that cluster and runs
`cluster-up` to restore the pinned Argo CD installation and root Application.
It never deletes the Mac data directories.

```bash
make cluster-recreate
```

This deletes data stored only inside k3d node containers. Export or back up any
other cluster-local data before using it. The Mantooth Tasks data directories
are bind mounts and are intentionally retained.
