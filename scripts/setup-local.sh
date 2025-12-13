#!/usr/bin/env bash

################################################################################
# setup-local.sh
#
# Validates and installs prerequisites for local development.
# This script checks for required tools and helps set up the development
# environment for the reference platform.
#
# Usage:
#   ./setup-local.sh [--install]
#
# Options:
#   --install    Attempt to install missing prerequisites (requires sudo)
#
################################################################################

set -euo pipefail

# Color output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Track if any prerequisites are missing
MISSING_PREREQS=0
INSTALL_MODE=false

# Parse arguments
if [[ "${1:-}" == "--install" ]]; then
  INSTALL_MODE=true
fi

################################################################################
# Helper Functions
################################################################################

log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

check_command() {
  local cmd="$1"
  local version_flag="${2:---version}"
  local required_version="${3:-}"

  if command -v "$cmd" &> /dev/null; then
    local version
    version=$($cmd $version_flag 2>&1 | head -n1)
    log_info "✓ $cmd is installed: $version"

    if [[ -n "$required_version" ]]; then
      log_info "  Required version: $required_version (please verify manually)"
    fi
    return 0
  else
    log_error "✗ $cmd is not installed"
    MISSING_PREREQS=$((MISSING_PREREQS + 1))
    return 1
  fi
}

install_homebrew() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    log_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    log_error "Homebrew installation is only supported on macOS"
    return 1
  fi
}

install_tool() {
  local tool="$1"
  local install_cmd="$2"

  if [[ "$INSTALL_MODE" == true ]]; then
    log_info "Attempting to install $tool..."
    # Note: eval is used here because install commands contain pipes and subshells. Commands are hardcoded in this script, not user-provided, so injection risk is mitigated.
    eval "$install_cmd"
  else
    log_warn "To install $tool, run: $install_cmd"
  fi
}

################################################################################
# Main Checks
################################################################################

log_info "Checking prerequisites for reference-platform local development..."
echo ""

log_info "=== Operating System ==="
echo "OS: $(uname -s)"
echo "Architecture: $(uname -m)"
echo ""

log_info "=== Container Runtime ==="
# Check for Docker or Podman
if check_command docker version; then
  docker info > /dev/null 2>&1 || log_warn "Docker daemon not running. Start it with: docker start"
elif check_command podman --version; then
  log_info "Using Podman as container runtime"
else
  log_error "Neither Docker nor Podman found"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    install_tool "Docker Desktop" "open https://www.docker.com/products/docker-desktop"
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    install_tool "Docker" "curl -fsSL https://get.docker.com | sh"
  fi
fi
echo ""

log_info "=== Kubernetes Tools ==="
check_command kubectl version || install_tool "kubectl" \
  "curl -LO https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/$(uname -s | tr '[:upper:]' '[:lower:]')/$(uname -m)/kubectl && chmod +x kubectl && sudo mv kubectl /usr/local/bin/"

check_command kind version || install_tool "kind" \
  "curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m) && chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind"

check_command helm version || install_tool "helm" \
  "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"

check_command kustomize version || install_tool "kustomize" \
  "curl -s https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh | bash && sudo mv kustomize /usr/local/bin/"
echo ""

log_info "=== GitOps Tools ==="
check_command argocd version || install_tool "argocd" \
  "curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m) && chmod +x argocd && sudo mv argocd /usr/local/bin/"

check_command flux --version || install_tool "flux" \
  "curl -s https://fluxcd.io/install.sh | bash"
echo ""

log_info "=== Development Tools ==="
check_command git --version ">=2.0.0" || install_tool "git" \
  "brew install git  # Or: sudo apt-get install git"

check_command jq --version || install_tool "jq" \
  "brew install jq  # Or: sudo apt-get install jq"

check_command yq --version || install_tool "yq" \
  "brew install yq  # Or: wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && chmod +x /usr/local/bin/yq"
echo ""

log_info "=== Security & Compliance Tools ==="
check_command syft version || install_tool "syft" \
  "curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin"

check_command trivy --version || install_tool "trivy" \
  "brew install trivy  # Or: curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin"

check_command cosign version || install_tool "cosign" \
  "brew install cosign  # Or: curl -sSfL https://github.com/sigstore/cosign/releases/latest/download/cosign-$(uname -s | tr '[:upper:]' '[:lower:]')-$(uname -m) -o /usr/local/bin/cosign && chmod +x /usr/local/bin/cosign"
echo ""

log_info "=== Observability Tools ==="
check_command prometheus --version || log_warn "Prometheus not installed (optional - runs in cluster)"

check_command grafana-cli --version || log_warn "Grafana not installed (optional - runs in cluster)"
echo ""

log_info "=== Language Runtimes (Optional) ==="
check_command go version || log_warn "Go not installed (optional for development)"
check_command python3 --version || log_warn "Python 3 not installed (optional for development)"
check_command node --version || log_warn "Node.js not installed (optional for development)"
echo ""

################################################################################
# Kubernetes Cluster Check
################################################################################

log_info "=== Kubernetes Cluster ==="
if kubectl cluster-info &> /dev/null; then
  log_info "✓ Connected to Kubernetes cluster:"
  kubectl cluster-info | head -n 1
  log_info "Current context: $(kubectl config current-context)"
  log_info "Kubernetes version: $(kubectl version --short 2>/dev/null || kubectl version --output=yaml | grep gitVersion | head -1)"
else
  log_warn "Not connected to a Kubernetes cluster"
  log_info "To create a local cluster, run: kind create cluster --name reference-platform"
fi
echo ""

################################################################################
# Local Configuration Check
################################################################################

log_info "=== Local Configuration ==="
if [[ -f ~/.kube/config ]]; then
  log_info "✓ kubectl config found at ~/.kube/config"
else
  log_warn "kubectl config not found. You may need to configure cluster access."
fi

if [[ -d ~/.docker ]]; then
  log_info "✓ Docker config directory exists"
else
  log_warn "Docker config directory not found"
fi
echo ""

################################################################################
# Summary
################################################################################

log_info "=== Summary ==="
if [[ $MISSING_PREREQS -eq 0 ]]; then
  log_info "✓ All required prerequisites are installed!"
  log_info "You're ready to develop on the reference platform."
  exit 0
else
  log_error "✗ $MISSING_PREREQS prerequisite(s) missing"

  if [[ "$INSTALL_MODE" == false ]]; then
    echo ""
    log_info "To attempt automatic installation, run:"
    log_info "  $0 --install"
  fi

  exit 1
fi
