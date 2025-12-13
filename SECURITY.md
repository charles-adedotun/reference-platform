# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security issue, please report it responsibly.

### How to Report

1. **Do NOT** open a public GitHub issue for security vulnerabilities
2. Email the maintainers directly or use GitHub's private vulnerability reporting feature
3. Include as much detail as possible:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### What to Expect

- **Acknowledgment**: Within 48 hours of your report
- **Initial Assessment**: Within 7 days
- **Resolution Timeline**: Depends on severity, typically 30-90 days

### Scope

This security policy applies to:
- All code in this repository
- Infrastructure configurations (Terraform, Kubernetes manifests)
- CI/CD pipeline configurations
- Docker images built from this repository

### Out of Scope

- Third-party dependencies (report to upstream maintainers)
- Intentional example credentials in documentation (e.g., `example.com`, placeholder values)

## Security Measures

This repository implements several security practices:

### Automated Scanning
- **CodeQL**: Static code analysis for Go
- **Trivy**: Container and filesystem vulnerability scanning
- **Gitleaks**: Secret detection in code and git history
- **Dependabot**: Automated dependency updates
- **govulncheck**: Go-specific vulnerability checking

### Runtime Security
- **Kyverno Policies**: Kubernetes admission control
  - Require resource limits
  - Disallow latest tag
  - Require non-root containers
  - Restrict host path mounts
  - Allowed container registries

### Supply Chain Security
- **SBOM Generation**: Software Bill of Materials with Syft
- **Image Signing**: Container signatures with cosign
- **SLSA Provenance**: Build attestations

## Security Contacts

For security-related inquiries, contact the repository maintainers through GitHub.
