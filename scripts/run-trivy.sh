#!/usr/bin/env bash

################################################################################
# run-trivy.sh
#
# Runs Trivy security scanner on container images, filesystems, and IaC.
# Supports multiple scan types and output formats with severity filtering.
#
# Usage:
#   ./run-trivy.sh <target> [scan-type] [severity] [format]
#
# Arguments:
#   target      - Image, directory, or resource to scan (required)
#   scan-type   - Type of scan: image, fs, config, k8s (default: image)
#   severity    - Minimum severity: UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL (default: HIGH,CRITICAL)
#   format      - Output format: table, json, sarif, template (default: table)
#
# Examples:
#   ./run-trivy.sh myapp:latest
#   ./run-trivy.sh myapp:latest image CRITICAL
#   ./run-trivy.sh ./kubernetes config
#   ./run-trivy.sh . fs MEDIUM,HIGH,CRITICAL json
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
TARGET="${1:-}"
SCAN_TYPE="${2:-image}"
SEVERITY="${3:-HIGH,CRITICAL}"
FORMAT="${4:-table}"
OUTPUT_FILE=""

# Exit codes for CI/CD
EXIT_CODE_THRESHOLD=1  # Exit with error if vulnerabilities found

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

usage() {
  cat << EOF
Usage: $0 <target> [scan-type] [severity] [format]

Arguments:
  target      Image, directory, or resource to scan (required)
  scan-type   Type of scan (default: image)
              - image: Scan container image
              - fs: Scan filesystem/directory
              - config: Scan IaC (Kubernetes, Terraform, etc.)
              - k8s: Scan running Kubernetes cluster
              - sbom: Scan SBOM file
  severity    Minimum severity (default: HIGH,CRITICAL)
              Options: UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL
  format      Output format (default: table)
              Options: table, json, sarif, template, cyclonedx, spdx

Examples:
  # Scan container image
  $0 myapp:latest

  # Scan with specific severity
  $0 myapp:latest image CRITICAL

  # Scan Kubernetes manifests
  $0 ./kubernetes config

  # Scan filesystem for secrets and misconfigs
  $0 . fs MEDIUM,HIGH,CRITICAL json

  # Scan running Kubernetes cluster
  $0 all k8s

EOF
  exit 1
}

check_prerequisites() {
  if ! command -v trivy &> /dev/null; then
    log_error "trivy not found. Please install trivy."
    log_info "Install with:"
    log_info "  macOS: brew install trivy"
    log_info "  Linux: curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin"
    exit 1
  fi

  trivy_version=$(trivy version | grep Version | cut -d: -f2 | tr -d ' ')
  log_info "Using trivy version: $trivy_version"
}

validate_scan_type() {
  local scan_type="$1"
  local valid_types=("image" "fs" "config" "k8s" "sbom" "vm" "repo")

  for valid in "${valid_types[@]}"; do
    if [[ "$scan_type" == "$valid" ]]; then
      return 0
    fi
  done

  log_error "Invalid scan type: $scan_type"
  log_info "Valid types: ${valid_types[*]}"
  exit 1
}

update_trivy_db() {
  log_step "Updating Trivy vulnerability database..."
  if trivy image --download-db-only; then
    log_info "✓ Database updated successfully"
  else
    log_warn "Failed to update database, using cached version"
  fi
}

sanitize_target_name() {
  local target="$1"
  # Remove special chars, replace with dash
  echo "$target" | tr ':/@.' '-' | sed 's/^-//' | sed 's/-$//'
}

################################################################################
# Main Script
################################################################################

main() {
  log_info "Trivy Security Scanner"
  log_info "======================"
  echo ""

  # Validate arguments
  if [[ -z "$TARGET" ]]; then
    log_error "No target specified"
    usage
  fi

  log_step "Checking prerequisites..."
  check_prerequisites
  echo ""

  # Validate scan type
  validate_scan_type "$SCAN_TYPE"

  # Update database (for image/fs scans)
  if [[ "$SCAN_TYPE" == "image" ]] || [[ "$SCAN_TYPE" == "fs" ]]; then
    update_trivy_db
    echo ""
  fi

  # Generate output filename if using non-table format
  if [[ "$FORMAT" != "table" ]] && [[ -z "$OUTPUT_FILE" ]]; then
    SANITIZED_NAME=$(sanitize_target_name "$TARGET")
    OUTPUT_FILE="trivy-report-${SANITIZED_NAME}-$(date +%Y%m%d-%H%M%S).${FORMAT}"
  fi

  log_info "Scan configuration:"
  log_info "  Target: $TARGET"
  log_info "  Scan type: $SCAN_TYPE"
  log_info "  Severity filter: $SEVERITY"
  log_info "  Output format: $FORMAT"
  if [[ -n "$OUTPUT_FILE" ]]; then
    log_info "  Output file: $OUTPUT_FILE"
  fi
  echo ""

  # Build trivy command
  TRIVY_CMD="trivy $SCAN_TYPE"
  TRIVY_ARGS=()

  # Add common arguments
  TRIVY_ARGS+=("--severity" "$SEVERITY")

  if [[ -n "$OUTPUT_FILE" ]]; then
    TRIVY_ARGS+=("--format" "$FORMAT" "--output" "$OUTPUT_FILE")
  else
    TRIVY_ARGS+=("--format" "$FORMAT")
  fi

  # Add scan-type specific arguments
  case "$SCAN_TYPE" in
    image)
      TRIVY_ARGS+=("--scanners" "vuln,secret,misconfig")
      # Check if image exists locally
      if ! docker image inspect "$TARGET" &> /dev/null && ! podman image inspect "$TARGET" &> /dev/null; then
        log_warn "Image not found locally, Trivy will attempt to pull it"
      fi
      ;;
    fs)
      TRIVY_ARGS+=("--scanners" "vuln,secret,misconfig,license")
      # Check if directory exists
      if [[ ! -d "$TARGET" ]] && [[ ! -f "$TARGET" ]]; then
        log_error "Directory or file not found: $TARGET"
        exit 1
      fi
      ;;
    config)
      TRIVY_ARGS+=("--scanners" "misconfig,secret")
      ;;
    k8s)
      # For k8s, we need kubectl access
      if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Required for k8s scanning."
        exit 1
      fi
      TRIVY_ARGS+=("--scanners" "vuln,misconfig")
      ;;
  esac

  # Run scan
  log_step "Running Trivy scan..."
  log_info "Command: $TRIVY_CMD ${TRIVY_ARGS[*]} $TARGET"
  echo ""

  START_TIME=$(date +%s)

  # Run trivy and capture exit code
  set +e
  $TRIVY_CMD "${TRIVY_ARGS[@]}" "$TARGET"
  TRIVY_EXIT_CODE=$?
  set -e

  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  echo ""
  log_info "Scan completed in ${DURATION}s"

  # Check results
  if [[ $TRIVY_EXIT_CODE -eq 0 ]]; then
    log_info "✓ No vulnerabilities found at severity level: $SEVERITY"
    FINAL_EXIT_CODE=0
  else
    log_warn "⚠ Vulnerabilities or issues found!"
    FINAL_EXIT_CODE=$TRIVY_EXIT_CODE
  fi
  echo ""

  # If output file was created, show info
  if [[ -n "$OUTPUT_FILE" ]] && [[ -f "$OUTPUT_FILE" ]]; then
    FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    log_info "Report saved to: $OUTPUT_FILE (${FILE_SIZE})"

    # For JSON format, show vulnerability counts
    if [[ "$FORMAT" == "json" ]] && command -v jq &> /dev/null; then
      log_step "Vulnerability Summary:"

      # Count by severity
      CRITICAL=$(jq -r '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")
      HIGH=$(jq -r '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")] | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")
      MEDIUM=$(jq -r '[.Results[]?.Vulnerabilities[]? | select(.Severity=="MEDIUM")] | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")
      LOW=$(jq -r '[.Results[]?.Vulnerabilities[]? | select(.Severity=="LOW")] | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")

      echo "  CRITICAL: $CRITICAL"
      echo "  HIGH: $HIGH"
      echo "  MEDIUM: $MEDIUM"
      echo "  LOW: $LOW"
      echo ""
    fi
  fi

  # Additional recommendations
  log_step "Next Steps:"

  if [[ $FINAL_EXIT_CODE -ne 0 ]]; then
    echo "1. Review identified vulnerabilities and misconfigurations"
    echo "2. Update vulnerable dependencies to patched versions"
    echo "3. Fix misconfigurations according to best practices"
    echo "4. Re-run scan to verify fixes"
    echo ""

    log_info "Common fixes:"
    echo "  - Update base image to latest patch version"
    echo "  - Update application dependencies (npm update, go get -u, etc.)"
    echo "  - Apply security patches"
    echo "  - Review and remove secrets from code"
    echo ""
  else
    echo "1. Include this scan in your CI/CD pipeline"
    echo "2. Set up automated scanning on schedule"
    echo "3. Monitor for new vulnerabilities in databases"
    echo ""
  fi

  # Show additional scan suggestions
  log_info "Additional scans you can run:"

  if [[ "$SCAN_TYPE" != "config" ]]; then
    echo "  # Scan for IaC misconfigurations:"
    echo "  $0 ./kubernetes config"
  fi

  if [[ "$SCAN_TYPE" != "fs" ]]; then
    echo "  # Scan filesystem for secrets:"
    echo "  $0 . fs"
  fi

  if [[ "$SCAN_TYPE" != "k8s" ]] && command -v kubectl &> /dev/null; then
    echo "  # Scan running K8s cluster:"
    echo "  $0 all k8s"
  fi
  echo ""

  # CI/CD integration suggestion
  log_info "CI/CD Integration:"
  echo "Add to your pipeline:"
  cat << 'EOF'
  - name: Run Trivy vulnerability scanner
    run: |
      trivy image --severity HIGH,CRITICAL \
        --exit-code 1 \
        --format sarif \
        --output trivy-results.sarif \
        ${{ env.IMAGE_NAME }}
EOF
  echo ""

  # Generate SBOM suggestion
  if [[ "$SCAN_TYPE" == "image" ]]; then
    log_info "To generate SBOM for this image:"
    echo "  ./generate-sbom.sh $TARGET"
    echo ""
  fi

  # Final summary
  log_info "=== Scan Summary ==="
  log_info "Target: $TARGET"
  log_info "Scan type: $SCAN_TYPE"
  log_info "Duration: ${DURATION}s"
  if [[ $FINAL_EXIT_CODE -eq 0 ]]; then
    log_info "Result: ✓ PASSED"
  else
    log_warn "Result: ⚠ FAILED (vulnerabilities found)"
  fi
  echo ""

  exit $FINAL_EXIT_CODE
}

# Run main function
main "$@"
