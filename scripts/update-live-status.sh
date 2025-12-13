#!/usr/bin/env bash

################################################################################
# update-live-status.sh
#
# Updates live deployment status tracking. This script collects deployment
# status, health metrics, and version information for all environments and
# updates a status dashboard or file.
#
# Usage:
#   ./update-live-status.sh [environment] [output-format]
#
# Arguments:
#   environment    - Environment to check: staging, production, all (default: all)
#   output-format  - Output format: json, yaml, markdown, html (default: json)
#
# Examples:
#   ./update-live-status.sh
#   ./update-live-status.sh production
#   ./update-live-status.sh all markdown
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
ENVIRONMENT="${1:-all}"
OUTPUT_FORMAT="${2:-json}"
OUTPUT_DIR="./status-reports"
# Note: This date format is POSIX-compliant and works on both GNU (Linux) and BSD (macOS) date
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Environments to check
ENVIRONMENTS=()
if [[ "$ENVIRONMENT" == "all" ]]; then
  ENVIRONMENTS=("staging" "production")
else
  ENVIRONMENTS=("$ENVIRONMENT")
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

log_step() {
  echo -e "${BLUE}[STEP]${NC} $1"
}

check_prerequisites() {
  if ! command -v kubectl &> /dev/null; then
    log_error "kubectl not found. Please install kubectl."
    exit 1
  fi

  if ! command -v jq &> /dev/null; then
    log_warn "jq not found. JSON processing may be limited."
  fi

  if ! kubectl cluster-info &> /dev/null; then
    log_error "Not connected to a Kubernetes cluster"
    exit 1
  fi
}

get_deployment_status() {
  local namespace="$1"
  local deployment="$2"

  local ready_replicas
  local desired_replicas
  local available_replicas
  local updated_replicas

  ready_replicas=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  desired_replicas=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
  available_replicas=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
  updated_replicas=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.status.updatedReplicas}' 2>/dev/null || echo "0")

  local status="Unknown"
  if [[ "$ready_replicas" == "$desired_replicas" ]] && [[ "$ready_replicas" -gt 0 ]]; then
    status="Healthy"
  elif [[ "$available_replicas" -gt 0 ]]; then
    status="Degraded"
  else
    status="Down"
  fi

  cat << EOF
{
  "deployment": "$deployment",
  "namespace": "$namespace",
  "status": "$status",
  "replicas": {
    "desired": $desired_replicas,
    "ready": $ready_replicas,
    "available": $available_replicas,
    "updated": $updated_replicas
  }
}
EOF
}

get_deployment_version() {
  local namespace="$1"
  local deployment="$2"

  local image
  local version

  image=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "unknown")
  version=$(echo "$image" | cut -d: -f2)

  cat << EOF
{
  "image": "$image",
  "version": "$version"
}
EOF
}

get_service_health() {
  local namespace="$1"
  local service="$2"

  # Try to get service endpoints
  local endpoints
  endpoints=$(kubectl get endpoints "$service" -n "$namespace" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")

  local endpoint_count=0
  if [[ -n "$endpoints" ]]; then
    endpoint_count=$(echo "$endpoints" | wc -w | tr -d ' ')
  fi

  local health_status="Unknown"
  if [[ $endpoint_count -gt 0 ]]; then
    health_status="Healthy"
  else
    health_status="No Endpoints"
  fi

  cat << EOF
{
  "service": "$service",
  "namespace": "$namespace",
  "health": "$health_status",
  "endpoints": $endpoint_count
}
EOF
}

collect_environment_status() {
  local env="$1"

  log_step "Collecting status for environment: $env"

  # Initialize status object
  local env_status="{}"

  # Check if namespace exists
  if ! kubectl get namespace "$env" &> /dev/null; then
    log_warn "Namespace $env does not exist"
    echo "{\"environment\": \"$env\", \"status\": \"Not Found\", \"timestamp\": \"$TIMESTAMP\"}"
    return
  fi

  # Get all deployments in namespace
  local deployments
  deployments=$(kubectl get deployments -n "$env" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

  if [[ -z "$deployments" ]]; then
    log_warn "No deployments found in namespace $env"
    echo "{\"environment\": \"$env\", \"status\": \"No Deployments\", \"timestamp\": \"$TIMESTAMP\"}"
    return
  fi

  # Build deployment status array
  local deployment_statuses="["
  local first=true

  for deployment in $deployments; do
    if [[ "$first" == false ]]; then
      deployment_statuses+=","
    fi
    first=false

    local dep_status
    local dep_version

    dep_status=$(get_deployment_status "$env" "$deployment")
    dep_version=$(get_deployment_version "$env" "$deployment")

    # Merge status and version
    deployment_statuses+=$(echo "$dep_status $dep_version" | jq -s '.[0] + .[1]')
  done

  deployment_statuses+="]"

  # Get overall environment health
  local overall_status="Healthy"
  local unhealthy_count
  unhealthy_count=$(echo "$deployment_statuses" | jq '[.[] | select(.status != "Healthy")] | length')

  if [[ $unhealthy_count -gt 0 ]]; then
    overall_status="Degraded"
  fi

  # Build final status object
  cat << EOF
{
  "environment": "$env",
  "status": "$overall_status",
  "timestamp": "$TIMESTAMP",
  "deployments": $deployment_statuses
}
EOF
}

format_as_markdown() {
  local json_data="$1"

  cat << EOF
# Live Deployment Status

**Last Updated**: $(echo "$json_data" | jq -r '.timestamp')

EOF

  # For each environment
  echo "$json_data" | jq -r '.environments[] | @json' | while IFS= read -r env_json; do
    local env_name
    local env_status

    env_name=$(echo "$env_json" | jq -r '.environment')
    env_status=$(echo "$env_json" | jq -r '.status')

    cat << EOF

## Environment: $env_name

**Status**: $env_status

| Deployment | Status | Version | Ready/Desired |
|------------|--------|---------|---------------|
EOF

    echo "$env_json" | jq -r '.deployments[]? | [.deployment, .status, .version, "\(.replicas.ready)/\(.replicas.desired)"] | @tsv' | \
      while IFS=$'\t' read -r dep status version replicas; do
        echo "| $dep | $status | $version | $replicas |"
      done
  done

  cat << EOF

---
*Generated by update-live-status.sh*
EOF
}

format_as_html() {
  local json_data="$1"

  cat << EOF
<!DOCTYPE html>
<html>
<head>
  <title>Live Deployment Status</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    h1 { color: #333; }
    .timestamp { color: #666; font-size: 0.9em; }
    .environment { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
    .status-healthy { color: green; font-weight: bold; }
    .status-degraded { color: orange; font-weight: bold; }
    .status-down { color: red; font-weight: bold; }
    table { border-collapse: collapse; width: 100%; margin-top: 10px; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background-color: #f2f2f2; }
  </style>
</head>
<body>
  <h1>Live Deployment Status</h1>
  <p class="timestamp">Last Updated: $(echo "$json_data" | jq -r '.timestamp')</p>
EOF

  # For each environment
  echo "$json_data" | jq -r '.environments[] | @json' | while IFS= read -r env_json; do
    local env_name
    local env_status

    env_name=$(echo "$env_json" | jq -r '.environment')
    env_status=$(echo "$env_json" | jq -r '.status')

    local status_class="status-healthy"
    if [[ "$env_status" == "Degraded" ]]; then
      status_class="status-degraded"
    elif [[ "$env_status" == "Down" ]]; then
      status_class="status-down"
    fi

    cat << EOF
  <div class="environment">
    <h2>Environment: $env_name</h2>
    <p>Status: <span class="$status_class">$env_status</span></p>
    <table>
      <tr>
        <th>Deployment</th>
        <th>Status</th>
        <th>Version</th>
        <th>Ready/Desired</th>
      </tr>
EOF

    echo "$env_json" | jq -r '.deployments[]? | [.deployment, .status, .version, "\(.replicas.ready)/\(.replicas.desired)"] | @tsv' | \
      while IFS=$'\t' read -r dep status version replicas; do
        echo "      <tr><td>$dep</td><td>$status</td><td>$version</td><td>$replicas</td></tr>"
      done

    echo "    </table>"
    echo "  </div>"
  done

  cat << EOF
  <p style="margin-top: 30px; color: #666; font-size: 0.8em;">Generated by update-live-status.sh</p>
</body>
</html>
EOF
}

################################################################################
# Main Script
################################################################################

main() {
  log_info "Live Status Update Script"
  log_info "=========================="
  echo ""

  # Check prerequisites
  log_step "Checking prerequisites..."
  check_prerequisites
  echo ""

  log_info "Configuration:"
  log_info "  Environment(s): ${ENVIRONMENTS[*]}"
  log_info "  Output format: $OUTPUT_FORMAT"
  log_info "  Timestamp: $TIMESTAMP"
  echo ""

  # Create output directory if needed
  mkdir -p "$OUTPUT_DIR"

  # Collect status for all environments
  log_step "Collecting deployment status..."

  local all_env_status="{"
  all_env_status+="\"timestamp\": \"$TIMESTAMP\","
  all_env_status+="\"environments\": ["

  local first=true
  for env in "${ENVIRONMENTS[@]}"; do
    if [[ "$first" == false ]]; then
      all_env_status+=","
    fi
    first=false

    all_env_status+=$(collect_environment_status "$env")
  done

  all_env_status+="]}"

  echo ""

  # Format and save output
  log_step "Generating output..."

  local output_file=""

  case "$OUTPUT_FORMAT" in
    json)
      output_file="$OUTPUT_DIR/status-$(date +%Y%m%d-%H%M%S).json"
      echo "$all_env_status" | jq '.' > "$output_file"
      log_info "JSON report saved to: $output_file"
      ;;
    yaml)
      output_file="$OUTPUT_DIR/status-$(date +%Y%m%d-%H%M%S).yaml"
      if command -v yq &> /dev/null; then
        echo "$all_env_status" | yq -P '.' > "$output_file"
        log_info "YAML report saved to: $output_file"
      else
        log_warn "yq not found, saving as JSON instead"
        output_file="$OUTPUT_DIR/status-$(date +%Y%m%d-%H%M%S).json"
        echo "$all_env_status" | jq '.' > "$output_file"
        log_info "JSON report saved to: $output_file"
      fi
      ;;
    markdown)
      output_file="$OUTPUT_DIR/status-$(date +%Y%m%d-%H%M%S).md"
      format_as_markdown "$all_env_status" > "$output_file"
      log_info "Markdown report saved to: $output_file"
      ;;
    html)
      output_file="$OUTPUT_DIR/status-$(date +%Y%m%d-%H%M%S).html"
      format_as_html "$all_env_status" > "$output_file"
      log_info "HTML report saved to: $output_file"
      ;;
    *)
      log_error "Invalid output format: $OUTPUT_FORMAT"
      exit 1
      ;;
  esac

  # Also save as latest
  local latest_file="$OUTPUT_DIR/status-latest.$OUTPUT_FORMAT"
  cp "$output_file" "$latest_file"
  log_info "Latest status: $latest_file"
  echo ""

  # Display summary
  log_step "Status Summary:"
  echo "$all_env_status" | jq -r '.environments[] | "\(.environment): \(.status)"'
  echo ""

  # Display on console (if table format or markdown)
  if [[ "$OUTPUT_FORMAT" == "markdown" ]]; then
    log_info "=== Status Report ==="
    cat "$output_file"
  fi

  echo ""
  log_info "Status update complete!"
  log_info "Reports saved to: $OUTPUT_DIR/"
}

# Run main function
main "$@"
