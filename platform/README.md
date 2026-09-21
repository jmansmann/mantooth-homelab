# platform

Cluster-wide platform components, one directory per component. Each is consumed by the cluster overlays in `clusters/<cluster>/`.

Planned components (see `docs/plan.md` and `docs/decisions.md`):

| Directory | Component |
|---|---|
| `argocd/` | Argo CD configuration (ApplicationSets, projects, Image Updater) |
| `cilium/` | CNI, kube-proxy replacement, network policy, Hubble |
| `metallb/` | L2 load balancing → LAN VIPs |
| `envoy-gateway/` | Gateway API ingress |
| `cert-manager/` | Let's Encrypt DNS-01 certificates |
| `longhorn/` | Replicated persistent storage |
| `external-secrets/` | Secret synchronization |
| `kyverno/` | Policy |
| `observability/` | Prometheus, Loki, Grafana |

Conventions: pin versions, no vendored charts, no secrets in Git. See the repo `AGENTS.md`.