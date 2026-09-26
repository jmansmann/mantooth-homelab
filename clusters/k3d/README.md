# clusters/k3d

Overlay for the **local development cluster** (k3d on the Mac / Apple Silicon).

This is the sync target of the root app-of-apps in `bootstrap/`. It selects platform components from `platform/` and hosts the apps ApplicationSet.

| Path | Purpose |
|---|---|
| `k3d-config.yaml` | Pinned k3d cluster definition; add host bind mounts here before recreating the cluster |
| `kustomization.yaml` | Renders everything in this directory for the root app-of-apps |
| `apps-applicationset.yaml` | Generates one Argo CD Application per application repo |
| `platform.yaml` | *(planned)* Argo CD Application(s) wiring `platform/` components for this cluster |

Differences from `clusters/homelab`: smaller resource requests, no Longhorn replication (`longhorn` may be omitted for single-replica), local DNS/TLS substitutes.

## Cluster lifecycle

```bash
make cluster-delete # removes k3d node containers and data stored only inside them
make cluster-up     # create/start from k3d-config.yaml, install Argo CD, bootstrap root
```

Edit `k3d-config.yaml` to add required host bind mounts **before** recreating the
cluster. Bind-mounted host directories survive cluster deletion; node-local
container data does not. `cluster-up` starts an existing cluster as-is, so it
does not apply new mount settings until after `cluster-delete` and recreation.
