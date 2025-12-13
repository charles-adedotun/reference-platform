#!/usr/bin/env bash

################################################################################
# fix-db.sh
#
# Automated database recovery script. Attempts to restore database service
# after a failure by restarting the PostgreSQL StatefulSet.
#
# Usage:
#   ./fix-db.sh [namespace] [statefulset-name]
#
# Arguments:
#   namespace        - Kubernetes namespace (default: staging)
#   statefulset-name - PostgreSQL StatefulSet name (default: postgres)
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
STATEFULSET_NAME="${2:-postgres}"
TIMEOUT=300  # 5 minutes timeout for rollout

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

check_statefulset() {
  if ! kubectl get statefulset "$STATEFULSET_NAME" -n "$NAMESPACE" &> /dev/null; then
    log_error "StatefulSet '$STATEFULSET_NAME' not found in namespace '$NAMESPACE'"
    log_info "Available StatefulSets:"
    kubectl get statefulsets -n "$NAMESPACE"
    exit 1
  fi
}

wait_for_ready() {
  local pod_name="$1"
  local timeout=60
  local elapsed=0

  log_info "Waiting for pod $pod_name to be ready..."

  while [[ $elapsed -lt $timeout ]]; do
    if kubectl get pod "$pod_name" -n "$NAMESPACE" &> /dev/null; then
      local ready_status
      ready_status=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')

      if [[ "$ready_status" == "True" ]]; then
        log_info "✓ Pod $pod_name is ready"
        return 0
      fi
    fi

    sleep 5
    elapsed=$((elapsed + 5))
    echo -n "."
  done

  echo ""
  log_warn "Pod $pod_name not ready after ${timeout}s"
  return 1
}

verify_database_health() {
  local pod_name="$1"

  log_info "Verifying database health..."

  # Check if pod is running
  local phase
  phase=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
  if [[ "$phase" != "Running" ]]; then
    log_error "Pod is not running. Phase: $phase"
    return 1
  fi

  # Try to connect to database
  log_info "Testing database connection..."
  if kubectl exec "$pod_name" -n "$NAMESPACE" -- pg_isready -U postgres &> /dev/null; then
    log_info "✓ Database is accepting connections"
  else
    log_warn "Database not ready yet"
    return 1
  fi

  # Check replication status (if applicable)
  log_info "Checking database status..."
  kubectl exec "$pod_name" -n "$NAMESPACE" -- psql -U postgres -c "SELECT version();" &> /dev/null || {
    log_warn "Could not query database"
    return 1
  }

  log_info "✓ Database health check passed"
  return 0
}

################################################################################
# Main Script
################################################################################

main() {
  log_info "Database Recovery Script"
  log_info "========================"
  echo ""

  # Record start time
  START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  log_info "Recovery started at: $START_TIME"
  echo ""

  # Verify prerequisites
  log_step "Checking prerequisites..."
  check_prerequisites

  log_info "Current context: $(kubectl config current-context)"
  log_info "Target namespace: $NAMESPACE"
  log_info "Target StatefulSet: $STATEFULSET_NAME"
  echo ""

  # Check namespace and StatefulSet exist
  log_step "Verifying namespace and StatefulSet..."
  check_namespace
  check_statefulset

  # Display current status
  log_step "Current StatefulSet status:"
  kubectl get statefulset "$STATEFULSET_NAME" -n "$NAMESPACE"
  echo ""

  log_step "Current pod status:"
  kubectl get pods -n "$NAMESPACE" -l app=postgres
  echo ""

  # Check for stuck pods
  log_step "Checking for stuck or failing pods..."
  STUCK_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=postgres -o jsonpath='{.items[?(@.status.phase!="Running")].metadata.name}')

  if [[ -n "$STUCK_PODS" ]]; then
    log_warn "Found non-running pods: $STUCK_PODS"

    for pod in $STUCK_PODS; do
      log_info "Checking pod: $pod"
      kubectl describe pod "$pod" -n "$NAMESPACE" | grep -A 5 "State:" || true
    done
    echo ""
  fi

  # Perform rolling restart
  log_step "Restarting StatefulSet..."
  log_info "This will perform a rolling restart of all pods"

  if kubectl rollout restart statefulset/"$STATEFULSET_NAME" -n "$NAMESPACE"; then
    log_info "✓ Rollout restart initiated"
  else
    log_error "Failed to restart StatefulSet"
    exit 1
  fi
  echo ""

  # Wait for rollout to complete
  log_step "Waiting for rollout to complete (timeout: ${TIMEOUT}s)..."
  if timeout "$TIMEOUT" kubectl rollout status statefulset/"$STATEFULSET_NAME" -n "$NAMESPACE"; then
    log_info "✓ Rollout completed successfully"
  else
    log_error "Rollout did not complete within ${TIMEOUT}s"
    log_info "Current status:"
    kubectl get pods -n "$NAMESPACE" -l app=postgres
    exit 1
  fi
  echo ""

  # Verify pods are ready
  log_step "Verifying pod readiness..."
  PODS=$(kubectl get pods -n "$NAMESPACE" -l app=postgres -o jsonpath='{.items[*].metadata.name}')

  ALL_READY=true
  for pod in $PODS; do
    if ! wait_for_ready "$pod"; then
      ALL_READY=false
    fi
  done
  echo ""

  if [[ "$ALL_READY" == false ]]; then
    log_error "Not all pods are ready"
    exit 1
  fi

  # Verify database health
  log_step "Verifying database health..."
  PRIMARY_POD="${STATEFULSET_NAME}-0"

  if verify_database_health "$PRIMARY_POD"; then
    log_info "✓ Database is healthy"
  else
    log_error "Database health check failed"
    log_info "Check logs: kubectl logs $PRIMARY_POD -n $NAMESPACE"
    exit 1
  fi
  echo ""

  # Check recent events
  log_step "Recent events:"
  kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -10
  echo ""

  # Final status
  log_step "Final status:"
  kubectl get statefulset "$STATEFULSET_NAME" -n "$NAMESPACE"
  kubectl get pods -n "$NAMESPACE" -l app=postgres
  echo ""

  # Calculate recovery time
  END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  log_info "Recovery completed at: $END_TIME"
  log_info "Started: $START_TIME"
  echo ""

  # Success summary
  log_info "=== Recovery Summary ==="
  log_info "✓ StatefulSet restarted successfully"
  log_info "✓ All pods are running and ready"
  log_info "✓ Database health check passed"
  echo ""

  # Next steps
  log_step "Next Steps:"
  echo "1. Verify application connectivity to database"
  echo "2. Check application logs for errors:"
  echo "   kubectl logs -n $NAMESPACE -l app=<your-app> --tail=50"
  echo "3. Monitor database metrics in Grafana/Prometheus"
  echo "4. Verify data integrity if needed"
  echo "5. Document incident in postmortem (if real incident)"
  echo ""

  log_info "Useful commands for verification:"
  echo "  # Check database connections:"
  echo "  kubectl exec $PRIMARY_POD -n $NAMESPACE -- psql -U postgres -c \"SELECT count(*) FROM pg_stat_activity;\""
  echo ""
  echo "  # Check replication status (if applicable):"
  echo "  kubectl exec $PRIMARY_POD -n $NAMESPACE -- psql -U postgres -c \"SELECT * FROM pg_stat_replication;\""
  echo ""
  echo "  # View database logs:"
  echo "  kubectl logs $PRIMARY_POD -n $NAMESPACE -f"
  echo ""

  log_info "Database recovery complete!"
}

# Run main function
main "$@"
