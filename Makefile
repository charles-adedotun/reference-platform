.PHONY: help kind-up kind-down demo smoke lint test build sbom scan gitleaks break-db fix-db tf-plan tf-apply clean

# Default target
.DEFAULT_GOAL := help

# Variables
CLUSTER_NAME ?= reference-platform
ARGOCD_NAMESPACE ?= argocd
ARGOCD_VERSION ?= 7.7.5
APP_NAMESPACE ?= taskflow
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
	kind create cluster --name $(CLUSTER_NAME) --config gitops/bootstrap/kind-config.yaml
	@echo ""
	@echo "$(GREEN)Installing ArgoCD via Helm$(NC)"
	helm repo add argo https://argoproj.github.io/argo-helm || true
	helm repo update
	kubectl create namespace $(ARGOCD_NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install argocd argo/argo-cd \
		--namespace $(ARGOCD_NAMESPACE) \
		--version $(ARGOCD_VERSION) \
		--set configs.params."application\.namespaces"="*" \
		--set server.service.type=NodePort \
		--set server.service.nodePortHttp=30080 \
		--wait --timeout $(TIMEOUT)
	@echo ""
	@echo "$(GREEN)Waiting for ArgoCD to be ready$(NC)"
	kubectl wait --for=condition=available --timeout=$(TIMEOUT) \
		deployment/argocd-server \
		deployment/argocd-repo-server \
		deployment/argocd-applicationset-controller \
		-n $(ARGOCD_NAMESPACE)
	@echo ""
	@echo "$(GREEN)ArgoCD admin password:$(NC)"
	@kubectl -n $(ARGOCD_NAMESPACE) get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo ""
	@echo ""
	@echo "$(GREEN)Cluster setup complete!$(NC)"
	@echo "  ArgoCD UI: http://localhost:30080"
	@echo "Run 'make demo' to deploy the TaskFlow app"

kind-down: ## Delete Kind cluster
	@echo "$(YELLOW)Deleting Kind cluster: $(CLUSTER_NAME)$(NC)"
	kind delete cluster --name $(CLUSTER_NAME)
	@echo "$(GREEN)Cluster deleted$(NC)"

demo: ## Deploy TaskFlow app via Helm and wait for ready
	@echo "$(GREEN)Deploying TaskFlow application$(NC)"
	kubectl create namespace taskflow --dry-run=client -o yaml | kubectl apply -f -
	helm upgrade --install taskflow apps/taskflow/deploy/helm/taskflow \
		--namespace taskflow \
		--set postgresql.auth.password=taskflow123 \
		--set redis.auth.password=redis123 \
		--set api.service.type=NodePort \
		--set api.service.nodePort=32000 \
		--wait --timeout $(TIMEOUT)
	@echo ""
	@echo "$(GREEN)Waiting for TaskFlow to be ready$(NC)"
	kubectl wait --for=condition=available --timeout=$(TIMEOUT) \
		deployment/taskflow-api -n taskflow || true
	@echo ""
	@echo "$(GREEN)TaskFlow deployed!$(NC)"
	@echo "  API: http://localhost:8080"
	@echo "  ArgoCD: http://localhost:30080"
	@echo ""
	@echo "Run 'make smoke' to test endpoints"

smoke: ## Run smoke tests (curl /health and /api/v1/transaction)
	@echo "$(GREEN)Running smoke tests$(NC)"
	@echo ""
	@echo "$(YELLOW)Testing /health endpoint:$(NC)"
	@curl -s -w "\nHTTP Status: %{http_code}\nLatency: %{time_total}s\n" http://localhost:8080/health || echo "$(RED)Failed to reach /health$(NC)"
	@echo ""
	@echo "$(YELLOW)Testing /api/v1/transaction endpoint:$(NC)"
	@curl -s -X POST -w "\nHTTP Status: %{http_code}\nLatency: %{time_total}s\n" http://localhost:8080/api/v1/transaction || echo "$(RED)Failed to reach /api/v1/transaction$(NC)"
	@echo ""
	@echo "$(GREEN)Smoke tests complete$(NC)"

lint: ## Run linters on Go code
	@echo "$(GREEN)Running linters$(NC)"
	cd apps/taskflow && golangci-lint run --timeout=5m ./...
	@echo "$(GREEN)Linting complete$(NC)"

test: ## Run unit tests
	@echo "$(GREEN)Running tests$(NC)"
	cd apps/taskflow && go test -v -race -coverprofile=coverage.out -covermode=atomic ./...
	cd apps/taskflow && go tool cover -func=coverage.out
	@echo "$(GREEN)Tests complete$(NC)"

build: ## Build Go application
	@echo "$(GREEN)Building TaskFlow$(NC)"
	cd apps/taskflow && go build -v -o bin/api ./cmd/api
	cd apps/taskflow && go build -v -o bin/worker ./cmd/worker
	cd apps/taskflow && go build -v -o bin/cron ./cmd/cron
	@echo "$(GREEN)Build complete$(NC)"

sbom: ## Generate Software Bill of Materials
	@echo "$(GREEN)Generating SBOM$(NC)"
	@if command -v syft > /dev/null; then \
		syft apps/taskflow/bin/api -o json > sbom.json; \
		syft apps/taskflow/bin/api -o spdx > sbom.spdx; \
		echo "$(GREEN)SBOM generated: sbom.json, sbom.spdx$(NC)"; \
	else \
		echo "$(RED)syft not found. Install from https://github.com/anchore/syft$(NC)"; \
		exit 1; \
	fi

scan: ## Scan for vulnerabilities
	@echo "$(GREEN)Scanning for vulnerabilities$(NC)"
	@if command -v grype > /dev/null; then \
		grype apps/taskflow/bin/api; \
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
	cd infra/terraform/environments/aws/dev && terraform init -backend=false && terraform plan
	@echo "$(GREEN)Terraform plan complete$(NC)"

tf-apply: ## Run Terraform apply
	@echo "$(GREEN)Running terraform apply$(NC)"
	cd infra/terraform/environments/aws/dev && terraform init && terraform apply -auto-approve
	@echo "$(GREEN)Terraform apply complete$(NC)"

clean: ## Clean build artifacts
	@echo "$(YELLOW)Cleaning build artifacts$(NC)"
	rm -rf apps/taskflow/bin
	rm -f apps/taskflow/coverage.out
	rm -f sbom.json sbom.spdx
	@echo "$(GREEN)Clean complete$(NC)"
