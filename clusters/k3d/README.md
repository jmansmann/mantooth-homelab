# clusters/k3d

Overlay for the **local development cluster** (k3d on the Mac / Apple Silicon).

This is the sync target of the root app-of-apps in `bootstrap/`. It selects platform components from `platform/` and hosts the apps ApplicationSet.

| Path | Purpose |
|---|---|
| `kustomization.yaml` | Renders everything in this directory for the root app-of-apps |
| `apps-applicationset.yaml` | Generates one Argo CD Application per application repo |
| `platform.yaml` | *(planned)* Argo CD Application(s) wiring `platform/` components for this cluster |

Differences from `clusters/homelab`: smaller resource requests, no Longhorn replication (`longhorn` may be omitted for single-replica), local DNS/TLS substitutes.