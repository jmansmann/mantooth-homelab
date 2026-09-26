# Phase 0 Quickstart — local k3d + Argo CD + first app pipeline

Goal: before buying any hardware, stand up a **local Kubernetes cluster**, install **Argo CD**, and ship a first webapp through a real pipeline: **GitHub Actions → GHCR → Argo CD (pull-based GitOps)**, building **multi-arch** images.

> Replace `jmansmann` with your GitHub username/org throughout.

## 0. Prerequisites

Docker must be installed and running (Docker Desktop, or `colima start`). Then install the CLI tooling:

```bash
brew install k3d kubectl helm kustomize argocd
```

Verify: `docker info`, `k3d version`, `kubectl version --client`, `argocd version --client`.

## 1. Create the GitHub repositories

Create two **private** repos on GitHub:

- `jmansmann/mantooth-homelab` — this config repo
- `jmansmann/<app>` — your first application (a small webapp)


Wire up the local `mantooth-homelab` repo (run from `~/development/mantooth-homelab`):

```bash
git remote add origin git@github.com:jmansmann/mantooth-homelab.git
git push -u origin main
```

## 2. Create a local k3d cluster

```bash
k3d cluster create dev \
  --agents 2 \
  --k3s-arg "--disable=traefik@server:*"
```

`traefik` is disabled because we will install our own Gateway later. Confirm:

```bash
kubectl config current-context   # k3d-dev
kubectl get nodes
```

## 3. Install Argo CD

```bash
kubectl create namespace argocd
kubectl apply --server-side -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.3/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server
```

Get the initial admin password and log in:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo

# in a separate terminal
kubectl -n argocd port-forward svc/argocd-server 8080:443

# back in this terminal
argocd login localhost:8080 --insecure --username admin
```

## 4. Bootstrap the root app-of-apps

Create `bootstrap/root/application.yaml` in this repo:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/GITHUB_USER/mantooth-homelab.git
    targetRevision: main
    path: clusters/k3d
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

For private Git repositories, Argo CD's CLI can register a **read-only GitHub
App** directly. Install the App on both repositories with `Contents: read`,
keep its PEM private key outside the repo, and register both URLs before
applying the root Application:

```bash
argocd repo add https://github.com/GITHUB_USER/mantooth-homelab.git \
  --github-app-id "$APP_ID" \
  --github-app-installation-id "$INSTALLATION_ID" \
  --github-app-private-key-path "$HOME/.config/github/argo-readonly-app.pem"
argocd repo add 'https://github.com/GITHUB_USER/<app>.git' \
  --github-app-id "$APP_ID" \
  --github-app-installation-id "$INSTALLATION_ID" \
  --github-app-private-key-path "$HOME/.config/github/argo-readonly-app.pem"
```

These commands store repository credentials as Kubernetes Secrets in the
`argocd` namespace. Public repositories need no credentials. Then apply the
root app-of-apps:

```bash
make bootstrap
argocd app get root
```

Everything under `clusters/k3d/` is now reconciled by Argo CD.

## 5. First application repo

Create `jmansmann/<app>` with this layout:

```
<app>/
├── Dockerfile
├── src/
├── deploy/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── overlays/
│       ├── k3d/
│       │   └── kustomization.yaml
│       └── homelab/
│           └── kustomization.yaml
└── .github/workflows/build.yml
```

`deploy/base/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
images:
  - name: ghcr.io/jmansmann/<app>
    newTag: latest
```

`deploy/overlays/k3d/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
```

### Multi-arch build workflow

`.github/workflows/build.yml` — builds both architectures, pushes to GHCR, and bumps the image tag **in this same repo**:

```yaml
name: build

on:
  push:
    branches: [main]
    # The tag-bump commit only touches deploy/; ignoring it stops the bot's own
    # push from re-triggering a build (works for any bot identity).
    paths-ignore:
      - 'deploy/**'
  workflow_dispatch:

permissions:
  # The app token handles the git write; GITHUB_TOKEN only needs to push images.
  contents: read
  packages: write

concurrency:
  group: build-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Generate app token
        id: app-token
        uses: actions/create-github-app-token@v3
        with:
          # GitHub App with Contents: write, added to the main bypass list.
          app-id: ${{ secrets.APP_ID }}
          private-key: ${{ secrets.APP_PRIVATE_KEY }}
          permission-contents: write

      - uses: actions/checkout@v4
        with:
          token: ${{ steps.app-token.outputs.token }}
          fetch-depth: 0

      - uses: docker/setup-qemu-action@v3
      - uses: docker/setup-buildx-action@v3

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Docker metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=sha,format=long

      - uses: docker/build-push-action@v6
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}

      - uses: imranismail/setup-kustomize@v2

      - name: Update image tag in manifests
        run: |
          IMAGE="ghcr.io/${{ github.repository }}:${{ steps.meta.outputs.version }}"
          for env in k3d homelab; do
            (cd "deploy/overlays/$env" && kustomize edit set image "ghcr.io/${{ github.repository }}=$IMAGE")
          done
          git config user.name  "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add deploy
          git commit -m "chore: bump image to ${GITHUB_SHA::7}" || echo "no changes to commit"
          git pull --rebase --autostash
          git push
```

> **Order matters:** `kustomize edit set image` dirties the working tree, so commit *before* `git pull --rebase`; otherwise the pull aborts with `cannot pull with rebase: You have unstaged changes`. `--autostash` is a safety net for anything left behind.

> **Protected `main`:** if `main` requires pull requests, the default `GITHUB_TOKEN` cannot push the bump (GH006). Create a **GitHub App** with `Contents: write`, install it on the repo, add it to the branch ruleset's **bypass list**, store its App ID and private key as `APP_ID` / `APP_PRIVATE_KEY` secrets, and mint a per-run token with `actions/create-github-app-token` as shown above.

> **GHCR visibility:** either make the package public, or create an image-pull secret in the cluster. For a private package in k3d:
> ```bash
> kubectl create secret docker-registry ghcr-pull \
>   --docker-server=ghcr.io \
>   --docker-username=jmansmann \
>   --docker-password=<a PAT with read:packages>
> ```
> then reference `imagePullSecrets: [{ name: ghcr-pull }]` in the Deployment.

## 6. Onboard the app with an ApplicationSet

Create `clusters/k3d/apps-applicationset.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: apps
  namespace: argocd
spec:
  goTemplate: true
  generators:
    - list:
        elements:
          - app: <app>
            repoURL: https://github.com/jmansmann/<app>.git
  template:
    metadata:
      name: '{{.app}}'
    spec:
      project: default
      source:
        repoURL: '{{.repoURL}}'
        targetRevision: main
        path: deploy/overlays/k3d
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{.app}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

Commit and push. Argo CD (via the root app) syncs the ApplicationSet, which generates an Application for the app.

**Upgrade path:** once you have several app repos, replace the `list` generator with an **SCM provider generator** (GitHub, with a `github-token` secret) so new repos are discovered automatically.

## 7. Verify

```bash
argocd app list
kubectl get pods -n <app>
kubectl -n <app> port-forward svc/<app> 8090:80   # then open http://localhost:8090
```

You now have the full loop: **edit → push → CI builds multi-arch image → manifest tag bumps → Argo CD syncs → app running**, all locally, with no hardware.

## 8. Optional — validate cert-manager DNS-01

Before Phase 2, prove Let's Encrypt DNS-01 works with your domain/Cloudflare account:

1. Create a Cloudflare API token with **DNS:Edit** for `DOMAIN`.
2. Store it as a secret and install `cert-manager` + a `ClusterIssuer` with a Cloudflare `dns01` solver.
3. Request a test certificate for `test.<DOMAIN>` and confirm it reaches `Ready`.

This de-risks Phase 2's TLS setup.

## Troubleshooting

- **`MANIFEST_UNKNOWN` / `ImagePullBackOff`** — private GHCR package without a pull secret; make it public or add the secret above.
- **Image runs locally but not in the cluster** — you built `arm64` only. Always pass `platforms: linux/amd64,linux/arm64`.
- **Argo CD CRDs fail to apply** — use `kubectl apply --server-side` (already specified above).
- **ApplicationSet has no Applications** — confirm the app repo is pushed and the `list` element's `repoURL` is reachable by Argo CD (add the repo under Settings → Repositories if private).
