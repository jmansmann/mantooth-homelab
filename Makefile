# mantooth-homelab — GitOps config entry points.
# Thin wrappers only; CI runs the same `make verify` (ADR-012).

CLUSTER   ?= k3d
KUSTOMIZE ?= kustomize
KUBECTL   ?= kubectl
K3D       ?= k3d
K3D_CLUSTER ?= dev
K3D_CONFIG  ?= clusters/k3d/k3d-config.yaml
ARGOCD_VERSION ?= v3.5.3

.DEFAULT_GOAL := help

.PHONY: help render verify validate cluster-up cluster-delete argocd-install bootstrap

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

render: ## Render the CLUSTER overlay
	$(KUSTOMIZE) build clusters/$(CLUSTER)

verify: ## Render every kustomization under platform/ and clusters/
	@for d in $$(find platform clusters -name kustomization.yaml -exec dirname {} \; | sort); do \
		echo "==> $$d"; $(KUSTOMIZE) build "$$d" >/dev/null || exit 1; \
	done
	@echo "all kustomizations render"

validate: ## Client-side validate the CLUSTER overlay against the API server
	@$(KUSTOMIZE) build clusters/$(CLUSTER) | $(KUBECTL) apply --dry-run=client -f - >/dev/null
	@echo "clusters/$(CLUSTER) valid"

cluster-up: ## Start/create k3d, install Argo CD, and bootstrap the root app
	@if $(K3D) cluster list --no-headers | awk '$$1 == "$(K3D_CLUSTER)" { found=1 } END { exit !found }'; then \
		echo "Starting existing k3d cluster $(K3D_CLUSTER)"; $(K3D) cluster start "$(K3D_CLUSTER)"; \
	else \
		echo "Creating k3d cluster $(K3D_CLUSTER) from $(K3D_CONFIG)"; $(K3D) cluster create "$(K3D_CLUSTER)" --config "$(K3D_CONFIG)"; \
	fi
	$(KUBECTL) config use-context k3d-$(K3D_CLUSTER)
	$(KUBECTL) wait --for=condition=Ready nodes --all --timeout=180s
	$(MAKE) argocd-install ARGOCD_VERSION=$(ARGOCD_VERSION)
	$(MAKE) bootstrap

cluster-delete: ## Delete the k3d cluster (node-container data is removed)
	$(K3D) cluster delete "$(K3D_CLUSTER)"

argocd-install: ## Install the pinned Argo CD version into the current cluster
	$(KUBECTL) create namespace argocd --dry-run=client -o yaml | $(KUBECTL) apply -f -
	$(KUBECTL) apply --server-side -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/$(ARGOCD_VERSION)/manifests/install.yaml
	$(KUBECTL) -n argocd rollout status deployment/argocd-server --timeout=180s

bootstrap: ## Apply the root app-of-apps (register private repos with Argo CLI first)
	$(KUBECTL) apply -f bootstrap/root/application.yaml
