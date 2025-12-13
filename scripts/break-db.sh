#!/usr/bin/env bash

################################################################################
# break-db.sh
#
# Simulates a database failure for testing incident response procedures.
# This script forcefully deletes the PostgreSQL pod to test failover,
# monitoring, and recovery procedures.
#
# Usage:
#   ./break-db.sh [namespace] [pod-name]
#
# Arguments:
#   namespace  - Kubernetes namespace (default: staging)
#   pod-name   - PostgreSQL pod name (default: postgres-0)
#
# WARNING: This will cause database downtime! Only use in non-production
#          environments or during planned game day exercises.
#
################################################################################

set -euo pipefail

# Color output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
NAMESPACE="${1:-staging}"
POD_NAME="${2:-postgres-0}"
FORCE_DELETE=true

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

log_step() {
  echo -e "${BLUE}[STEP]${NC} $1"
}

confirm() {
  local message="$1"
  echo -e "${YELLOW}${message}${NC}"
  read -p "Are you sure you want to continue? (yes/no): " -r
  if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    log_info "Operation cancelled"
    exit 0
  fi
}

check_prerequisites() {
  if ! command -v kubectl &> /dev/null; then
    log_error "kubectl not found. Please install kubectl."
    exit 1
  fi

  if ! kubectl cluster-info &> /dev/null; then
    log_error "Not connected to a Kubernetes cluster"
    exit 1
  fi
}

check_namespace() {
  if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    log_error "Namespace '$NAMESPACE' does not exist"
    exit 1
  fi
}

check_pod_exists() {
  if ! kubectl get pod "$POD_NAME" -n "$NAMESPACE" &> /dev/null; then
    log_error "Pod '$POD_NAME' not found in namespace '$NAMESPACE'"
    log_info "Available pods:"
    kubectl get pods -n "$NAMESPACE" -l app=postgres -o name
    exit 1
  fi
}

################################################################################
# Main Script
################################################################################

main() {
  log_info "Database Failure Simulation Script"
  log_info "====================================="
  echo ""

  # Verify prerequisites
  log_step "Checking prerequisites..."
  check_prerequisites

  # Get current context to ensure we're not in production
  CURRENT_CONTEXT=$(kubectl config current-context)
  log_info "Current context: $CURRENT_CONTEXT"

  # Safety check - prevent running in production
  if [[ "$CURRENT_CONTEXT" =~ prod|production ]]; then
    log_error "DANGER: You are connected to a PRODUCTION context!"
    log_error "This script should NEVER be run in production."
    exit 1
  fi

  if [[ "$NAMESPACE" =~ prod|production ]]; then
    log_error "DANGER: You specified a PRODUCTION namespace!"
    log_error "This script should NEVER be run in production."
    exit 1
  fi

  log_info "Target namespace: $NAMESPACE"
  log_info "Target pod: $POD_NAME"
  echo ""

  # Check namespace exists
  log_step "Verifying namespace..."
  check_namespace

  # Check pod exists
  log_step "Verifying pod..."
  check_pod_exists

  # Display current pod status
  log_step "Current pod status:"
  kubectl get pod "$POD_NAME" -n "$NAMESPACE"
  echo ""

  # Capture baseline metrics
  log_step "Capturing baseline metrics..."
  log_info "Pod status before failure:"
  kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}'
  echo ""

  log_info "Pod ready status:"
  kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
  echo ""

  log_info "Database connections (if accessible):"
  kubectl exec "$POD_NAME" -n "$NAMESPACE" -- psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null || log_warn "Could not query connection count"
  echo ""

  # Final confirmation
  confirm "WARNING: This will forcefully delete the PostgreSQL pod '$POD_NAME' in namespace '$NAMESPACE'!"
  echo ""

  # Record start time
  START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  log_info "Exercise started at: $START_TIME"
  echo ""

  # Delete the pod
  log_step "Simulating database failure..."
  if [[ "$FORCE_DELETE" == true ]]; then
    log_warn "Force deleting pod (simulating catastrophic failure)..."
    if kubectl delete pod "$POD_NAME" -n "$NAMESPACE" --grace-period=0 --force; then
      log_info "✓ Pod deleted successfully"
    else
      log_error "Failed to delete pod"
      exit 1
    fi
  else
    log_info "Gracefully deleting pod..."
    kubectl delete pod "$POD_NAME" -n "$NAMESPACE"
  fi
  echo ""

  # Monitor the aftermath
  log_step "Monitoring pod status after deletion..."
  sleep 2

  log_info "Current pod status:"
  kubectl get pods -n "$NAMESPACE" -l app=postgres
  echo ""

  log_info "Recent events:"
  kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -10
  echo ""

  # Provide next steps
  log_step "Next Steps:"
  echo "1. Check if alerts fired (PagerDuty, Prometheus, etc.)"
  echo "2. Monitor application error rates"
  echo "3. Observe StatefulSet behavior (should recreate pod)"
  echo "4. Test failover procedures from runbook"
  echo "5. Verify monitoring and alerting"
  echo ""

  log_info "Useful commands for monitoring:"
  echo "  # Watch pod status:"
  echo "  kubectl get pods -n $NAMESPACE -l app=postgres -w"
  echo ""
  echo "  # View pod logs:"
  echo "  kubectl logs -n $NAMESPACE $POD_NAME -f"
  echo ""
  echo "  # Check events:"
  echo "  kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' -w"
  echo ""
  echo "  # Check application errors:"
  echo "  kubectl logs -n $NAMESPACE -l app=<your-app> --tail=50"
  echo ""

  log_info "To restore service, see: ../runbooks/database-connection-exhausted.md"
  log_info "To run automated recovery: ./fix-db.sh $NAMESPACE"
  echo ""

  log_info "Failure simulation complete. Start time: $START_TIME"
  log_warn "Database should be recovering. Monitor the cluster!"
}

# Run main function
main "$@"
