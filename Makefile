.PHONY: help kind-up kind-down demo smoke lint test build sbom scan gitleaks break-db fix-db tf-plan tf-apply clean

# Default target
.DEFAULT_GOAL := help

# Variables
CLUSTER_NAME ?= reference-platform
ARGOCD_NAMESPACE ?= argocd
ARGOCD_VERSION ?= 7.7.5
APP_NAMESPACE ?= default
KUBECONFIG ?= $(HOME)/.kube/config
TIMEOUT ?= 300s

# Colors for output
GREEN  := \033[0;32m
YELLOW := \033[0;33m
RED    := \033[0;31m
NC     := \033[0m # No Color

help: ## Display this help message
	@echo "$(GREEN)Reference Platform - Makefile Targets$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""

kind-up: ## Create Kind cluster, install ArgoCD via Helm, apply root app
	@echo "$(GREEN)Creating Kind cluster: $(CLUSTER_NAME)$(NC)"
	kind create cluster --name $(CLUSTER_NAME) --config kind/kind-config.yaml || true
	@echo ""
	@echo "$(GREEN)Installing ArgoCD via Helm$(NC)"
	helm repo add argo https://argoproj.github.io/argo-helm || true
	helm repo update
	kubectl create namespace $(ARGOCD_NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install argocd argo/argo-cd \
		--namespace $(ARGOCD_NAMESPACE) \
		--version $(ARGOCD_VERSION) \
		--set configs.params."application\.namespaces"="*" \
		--wait --timeout $(TIMEOUT)
	@echo ""
	@echo "$(GREEN)Waiting for ArgoCD to be ready$(NC)"
	kubectl wait --for=condition=available --timeout=$(TIMEOUT) \
		deployment/argocd-server \
		deployment/argocd-repo-server \
		deployment/argocd-applicationset-controller \
		-n $(ARGOCD_NAMESPACE)
	@echo ""
	@echo "$(GREEN)Applying root ArgoCD Application$(NC)"
	kubectl apply -f argocd/root-app.yaml
	@echo ""
	@echo "$(GREEN)ArgoCD admin password:$(NC)"
	kubectl -n $(ARGOCD_NAMESPACE) get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
	@echo ""
	@echo "$(GREEN)Cluster setup complete!$(NC)"
	@echo "Run 'make demo' to start port-forwarding and access services"

kind-down: ## Delete Kind cluster
	@echo "$(YELLOW)Deleting Kind cluster: $(CLUSTER_NAME)$(NC)"
	kind delete cluster --name $(CLUSTER_NAME)
	@echo "$(GREEN)Cluster deleted$(NC)"

demo: ## Wait for platform ready, start port-forwarding
	@echo "$(GREEN)Waiting for platform to be ready$(NC)"
	@echo "Waiting for API deployment..."
	kubectl wait --for=condition=available --timeout=$(TIMEOUT) deployment/api -n $(APP_NAMESPACE) || echo "$(YELLOW)API deployment not yet available$(NC)"
	@echo ""
	@echo "$(GREEN)Starting port-forwarding:$(NC)"
	@echo "  - ArgoCD UI: http://localhost:8080"
	@echo "  - API: http://localhost:8081"
	@echo ""
	@echo "$(YELLOW)Press Ctrl+C to stop port-forwarding$(NC)"
	@echo ""
	@trap 'kill 0' EXIT; \
	kubectl port-forward svc/argocd-server -n $(ARGOCD_NAMESPACE) 8080:443 & \
	kubectl port-forward svc/api -n $(APP_NAMESPACE) 8081:80 & \
	wait

smoke: ## Run smoke tests (curl /health and /api/v1/transaction)
	@echo "$(GREEN)Running smoke tests$(NC)"
	@echo ""
	@echo "$(YELLOW)Testing /health endpoint:$(NC)"
	@curl -s -w "\nHTTP Status: %{http_code}\n" http://localhost:8081/health || echo "$(RED)Failed to reach /health$(NC)"
	@echo ""
	@echo "$(YELLOW)Testing /api/v1/transaction endpoint:$(NC)"
	@curl -s -w "\nHTTP Status: %{http_code}\n" http://localhost:8081/api/v1/transaction || echo "$(RED)Failed to reach /api/v1/transaction$(NC)"
	@echo ""
	@echo "$(GREEN)Smoke tests complete$(NC)"

lint: ## Run linters on Go code
	@echo "$(GREEN)Running linters$(NC)"
	cd api && golangci-lint run --timeout=5m ./...
	@echo "$(GREEN)Linting complete$(NC)"

test: ## Run unit tests
	@echo "$(GREEN)Running tests$(NC)"
	cd api && go test -v -race -coverprofile=coverage.out -covermode=atomic ./...
	cd api && go tool cover -func=coverage.out
	@echo "$(GREEN)Tests complete$(NC)"

build: ## Build Go application
	@echo "$(GREEN)Building API$(NC)"
	cd api && go build -v -o bin/api ./cmd/api
	@echo "$(GREEN)Build complete$(NC)"

sbom: ## Generate Software Bill of Materials
	@echo "$(GREEN)Generating SBOM$(NC)"
	@if command -v syft > /dev/null; then \
		syft api/bin/api -o json > sbom.json; \
		syft api/bin/api -o spdx > sbom.spdx; \
		echo "$(GREEN)SBOM generated: sbom.json, sbom.spdx$(NC)"; \
	else \
		echo "$(RED)syft not found. Install from https://github.com/anchore/syft$(NC)"; \
		exit 1; \
	fi

scan: ## Scan for vulnerabilities
	@echo "$(GREEN)Scanning for vulnerabilities$(NC)"
	@if command -v grype > /dev/null; then \
		grype api/bin/api; \
	else \
		echo "$(RED)grype not found. Install from https://github.com/anchore/grype$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Scan complete$(NC)"

gitleaks: ## Scan for secrets with gitleaks
	@echo "$(GREEN)Scanning for secrets$(NC)"
	@if command -v gitleaks > /dev/null; then \
		gitleaks detect --source . --verbose; \
		echo "$(GREEN)No secrets detected$(NC)"; \
	else \
		echo "$(RED)gitleaks not found. Install from https://github.com/gitleaks/gitleaks$(NC)"; \
		exit 1; \
	fi

break-db: ## Kill postgres pod to simulate failure
	@echo "$(YELLOW)Simulating database failure$(NC)"
	kubectl delete pod -n $(APP_NAMESPACE) -l app=postgres
	@echo "$(GREEN)Postgres pod deleted$(NC)"

fix-db: ## Restart postgres pod
	@echo "$(GREEN)Restarting postgres pod$(NC)"
	kubectl rollout restart statefulset/postgres -n $(APP_NAMESPACE) || kubectl rollout restart deployment/postgres -n $(APP_NAMESPACE)
	kubectl wait --for=condition=ready --timeout=$(TIMEOUT) pod -l app=postgres -n $(APP_NAMESPACE)
	@echo "$(GREEN)Postgres pod restarted$(NC)"

tf-plan: ## Run Terraform plan
	@echo "$(GREEN)Running terraform plan$(NC)"
	cd terraform && terraform init && terraform plan
	@echo "$(GREEN)Terraform plan complete$(NC)"

tf-apply: ## Run Terraform apply
	@echo "$(GREEN)Running terraform apply$(NC)"
	cd terraform && terraform init && terraform apply -auto-approve
	@echo "$(GREEN)Terraform apply complete$(NC)"

clean: ## Clean build artifacts
	@echo "$(YELLOW)Cleaning build artifacts$(NC)"
	rm -rf api/bin
	rm -f api/coverage.out
	rm -f sbom.json sbom.spdx
	@echo "$(GREEN)Clean complete$(NC)"
