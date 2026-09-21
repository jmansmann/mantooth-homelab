# bootstrap

One-time cluster bring-up — the parts that cannot be managed by Argo CD *because they install Argo CD*.

| Path | Purpose |
|---|---|
| `root/application.yaml` | The root **app-of-apps** Application. Once applied, Argo CD reconciles everything under `clusters/<cluster>/`. |

Keep this directory minimal. Everything after the initial Argo CD install should flow through Git, not scripts.

See `docs/phase-0-quickstart.md` for the exact commands.