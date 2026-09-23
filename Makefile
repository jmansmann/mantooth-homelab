# mantooth-homelab — GitOps config entry points.
# Thin wrappers only; CI runs the same `make verify` (ADR-012).

CLUSTER   ?= k3d
KUSTOMIZE ?= kustomize
KUBECTL   ?= kubectl

.DEFAULT_GOAL := help

.PHONY: help render verify validate bootstrap

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

bootstrap: ## Apply the root app-of-apps (one-time, by hand)
	$(KUBECTL) apply -f bootstrap/root/application.yaml
