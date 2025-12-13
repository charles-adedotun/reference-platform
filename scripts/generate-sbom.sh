#!/usr/bin/env bash

################################################################################
# generate-sbom.sh
#
# Generates Software Bill of Materials (SBOM) for container images using Syft.
# Supports multiple output formats and can scan local or remote images.
#
# Usage:
#   ./generate-sbom.sh <image> [output-format] [output-file]
#
# Arguments:
#   image         - Container image (e.g., myapp:latest or registry.io/myapp:v1.0)
#   output-format - SBOM format: spdx-json, cyclonedx-json, syft-json, table (default: spdx-json)
#   output-file   - Output file path (default: sbom-<image-name>.<format>)
#
# Examples:
#   ./generate-sbom.sh myapp:latest
#   ./generate-sbom.sh registry.io/myapp:v1.0 cyclonedx-json
#   ./generate-sbom.sh myapp:latest spdx-json ./sbom.json
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
IMAGE="${1:-}"
OUTPUT_FORMAT="${2:-spdx-json}"
OUTPUT_FILE="${3:-}"

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
Usage: $0 <image> [output-format] [output-file]

Arguments:
  image         Container image to scan (required)
  output-format SBOM format (default: spdx-json)
                Options: spdx-json, spdx, cyclonedx-json, cyclonedx-xml,
                         syft-json, syft-table, github-json, table
  output-file   Output file path (default: auto-generated)

Examples:
  $0 myapp:latest
  $0 registry.io/myapp:v1.0 cyclonedx-json
  $0 myapp:latest spdx-json ./sbom.json

EOF
  exit 1
}

check_prerequisites() {
  if ! command -v syft &> /dev/null; then
    log_error "syft not found. Please install syft."
    log_info "Install with: curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin"
    exit 1
  fi

  syft_version=$(syft version | head -n1)
  log_info "Using syft: $syft_version"
}

validate_format() {
  local format="$1"
  local valid_formats=("spdx-json" "spdx" "cyclonedx-json" "cyclonedx-xml" "syft-json" "syft-table" "github-json" "table")

  for valid in "${valid_formats[@]}"; do
    if [[ "$format" == "$valid" ]]; then
      return 0
    fi
  done

  log_error "Invalid output format: $format"
  log_info "Valid formats: ${valid_formats[*]}"
  exit 1
}

get_file_extension() {
  local format="$1"

  case "$format" in
    spdx-json|cyclonedx-json|syft-json|github-json)
      echo "json"
      ;;
    cyclonedx-xml)
      echo "xml"
      ;;
    spdx)
      echo "spdx"
      ;;
    table|syft-table)
      echo "txt"
      ;;
    *)
      echo "txt"
      ;;
  esac
}

sanitize_image_name() {
  local image="$1"
  # Remove registry prefix, replace special chars with dash
  echo "$image" | sed 's|.*/||' | tr ':/@' '-'
}

################################################################################
# Main Script
################################################################################

main() {
  log_info "SBOM Generation Script"
  log_info "======================"
  echo ""

  # Validate arguments
  if [[ -z "$IMAGE" ]]; then
    log_error "No image specified"
    usage
  fi

  log_step "Checking prerequisites..."
  check_prerequisites
  echo ""

  # Validate output format
  validate_format "$OUTPUT_FORMAT"

  # Generate output filename if not provided
  if [[ -z "$OUTPUT_FILE" ]]; then
    SANITIZED_NAME=$(sanitize_image_name "$IMAGE")
    FILE_EXT=$(get_file_extension "$OUTPUT_FORMAT")
    OUTPUT_FILE="sbom-${SANITIZED_NAME}.${FILE_EXT}"
    log_info "Output file: $OUTPUT_FILE"
  fi

  log_info "Configuration:"
  log_info "  Image: $IMAGE"
  log_info "  Format: $OUTPUT_FORMAT"
  log_info "  Output: $OUTPUT_FILE"
  echo ""

  # Check if image exists locally or needs to be pulled
  log_step "Checking image availability..."
  if docker image inspect "$IMAGE" &> /dev/null || podman image inspect "$IMAGE" &> /dev/null; then
    log_info "✓ Image found locally"
  else
    log_warn "Image not found locally, syft will attempt to pull it"
  fi
  echo ""

  # Generate SBOM
  log_step "Generating SBOM..."
  log_info "This may take a few minutes for large images..."

  START_TIME=$(date +%s)

  if syft "$IMAGE" -o "$OUTPUT_FORMAT" > "$OUTPUT_FILE"; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    log_info "✓ SBOM generated successfully in ${DURATION}s"
  else
    log_error "Failed to generate SBOM"
    exit 1
  fi
  echo ""

  # Display summary
  log_step "SBOM Summary:"

  FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
  log_info "File size: $FILE_SIZE"

  # Count packages (format-specific)
  case "$OUTPUT_FORMAT" in
    spdx-json|cyclonedx-json|syft-json|github-json)
      if command -v jq &> /dev/null; then
        PACKAGE_COUNT=$(jq -r '.artifacts // .components // .packages | length' "$OUTPUT_FILE" 2>/dev/null || echo "unknown")
        log_info "Packages found: $PACKAGE_COUNT"
      fi
      ;;
    table|syft-table)
      PACKAGE_COUNT=$(grep -c "^" "$OUTPUT_FILE" || echo "unknown")
      log_info "Lines in output: $PACKAGE_COUNT"
      ;;
  esac
  echo ""

  # Display sample of SBOM (for table format)
  if [[ "$OUTPUT_FORMAT" == "table" ]] || [[ "$OUTPUT_FORMAT" == "syft-table" ]]; then
    log_step "Sample SBOM content (first 20 lines):"
    head -n 20 "$OUTPUT_FILE"
    echo ""
  fi

  # Additional analysis
  log_step "Additional Information:"

  # Generate vulnerability report suggestion
  log_info "To scan for vulnerabilities, run:"
  echo "  syft $IMAGE | grype"
  echo ""

  # Attestation suggestion
  log_info "To create an attestation, run:"
  echo "  cosign attest --predicate $OUTPUT_FILE --type spdx --key cosign.key $IMAGE"
  echo ""

  # Validation suggestion (for SPDX)
  if [[ "$OUTPUT_FORMAT" == "spdx-json" ]]; then
    log_info "To validate SPDX document:"
    echo "  # Using spdx-tools (if installed):"
    echo "  pyspdxtools -i $OUTPUT_FILE"
  fi
  echo ""

  # Success
  log_info "=== SBOM Generation Complete ==="
  log_info "✓ Image scanned: $IMAGE"
  log_info "✓ Format: $OUTPUT_FORMAT"
  log_info "✓ Output saved to: $OUTPUT_FILE"
  echo ""

  log_info "Next steps:"
  echo "1. Review the SBOM for unexpected dependencies"
  echo "2. Scan for vulnerabilities with Grype or Trivy"
  echo "3. Store SBOM in artifact repository"
  echo "4. Attach SBOM to release artifacts"
  echo "5. Create cryptographic attestation with Cosign"
  echo ""

  # Generate multiple formats suggestion
  if [[ "$OUTPUT_FORMAT" != "table" ]]; then
    log_info "To generate a human-readable table:"
    echo "  $0 $IMAGE table"
  fi

  if [[ "$OUTPUT_FORMAT" != "spdx-json" ]]; then
    log_info "To generate SPDX JSON (recommended for attestation):"
    echo "  $0 $IMAGE spdx-json"
  fi
}

# Run main function
main "$@"
