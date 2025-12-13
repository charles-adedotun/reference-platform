# Contributing to Reference Platform

Thank you for your interest in contributing to the Reference Platform project! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for all contributors.

## Getting Started

### Prerequisites

Ensure you have the following tools installed:

- Go 1.23.0 or later
- Terraform 1.10.0 or later
- Helm 3.16.0 or later
- Kind 0.24.0 or later
- Docker
- kubectl

We recommend using [asdf](https://asdf-vm.com/) for managing tool versions. The `.tool-versions` file in the repository root specifies the exact versions.

```bash
asdf install
```

### Setting Up Your Development Environment

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/reference-platform.git
   cd reference-platform
   ```
3. Add the upstream repository as a remote:
   ```bash
   git remote add upstream https://github.com/ORIGINAL_OWNER/reference-platform.git
   ```
4. Create a new branch for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

### Running the Platform Locally

Start the local Kind cluster with ArgoCD:

```bash
make kind-up
```

This will:
- Create a Kind cluster
- Install ArgoCD via Helm
- Apply the root ArgoCD application
- Display the ArgoCD admin password

Access the services:

```bash
make demo
```

Run smoke tests:

```bash
make smoke
```

## Development Workflow

### Making Changes

1. **Write Tests**: Add or update tests for your changes
2. **Run Tests Locally**:
   ```bash
   make test
   ```
3. **Run Linters**:
   ```bash
   make lint
   ```
4. **Build the Application**:
   ```bash
   make build
   ```

### Code Style

- **Go Code**: Follow standard Go formatting (use `gofmt` and `golangci-lint`)
- **YAML**: Use 2-space indentation
- **Terraform**: Use 2-space indentation and run `terraform fmt`
- **Commit Messages**: Write clear, descriptive commit messages in imperative mood
  - Good: "Add health check endpoint"
  - Bad: "Added some stuff"

### Pre-commit Hooks

We use pre-commit hooks to ensure code quality. Install them:

```bash
pre-commit install
```

The hooks will automatically run on each commit and check for:
- Secret leaks (gitleaks)
- YAML syntax errors
- Terraform formatting

## Testing

### Unit Tests

Run unit tests for the Go API:

```bash
make test
```

### Integration Tests

Test the full platform deployment:

```bash
make kind-up
make demo
make smoke
```

### Security Scanning

Scan for vulnerabilities and secrets:

```bash
make scan
make gitleaks
```

## Submitting Changes

### Pull Request Process

1. **Update Documentation**: If you've changed functionality, update relevant documentation
2. **Run All Tests**: Ensure all tests pass locally
3. **Commit Your Changes**:
   ```bash
   git add .
   git commit -m "Brief description of changes"
   ```
4. **Push to Your Fork**:
   ```bash
   git push origin feature/your-feature-name
   ```
5. **Create a Pull Request**:
   - Go to your fork on GitHub
   - Click "New Pull Request"
   - Select your feature branch
   - Fill out the PR template with details about your changes

### Pull Request Guidelines

- **Title**: Use a clear, descriptive title
- **Description**: Explain what changes you made and why
- **Link Issues**: Reference any related issues (e.g., "Fixes #123")
- **Small PRs**: Keep pull requests focused and reasonably sized
- **Tests**: Include tests for new functionality
- **Documentation**: Update docs for user-facing changes

### Review Process

1. Maintainers will review your PR within a few days
2. Address any feedback or requested changes
3. Once approved, a maintainer will merge your PR

## Project Structure

```
reference-platform/
├── api/                  # Go API service
├── argocd/              # ArgoCD application manifests
├── kind/                # Kind cluster configuration
├── terraform/           # Infrastructure as Code
├── Makefile             # Build and deployment targets
└── README.md            # Project documentation
```

## Common Tasks

### Adding a New Feature

1. Create a new branch
2. Implement the feature with tests
3. Update documentation
4. Submit a pull request

### Fixing a Bug

1. Write a test that reproduces the bug
2. Fix the bug
3. Verify the test passes
4. Submit a pull request

### Updating Dependencies

```bash
cd api
go get -u ./...
go mod tidy
```

## Getting Help

- **Issues**: Check existing [GitHub Issues](https://github.com/OWNER/reference-platform/issues)
- **Discussions**: Start a [GitHub Discussion](https://github.com/OWNER/reference-platform/discussions)
- **Documentation**: Review the [README.md](README.md) and other docs

## License

By contributing to this project, you agree that your contributions will be licensed under the Apache License 2.0.

## Recognition

Contributors will be recognized in the project's release notes and documentation. Thank you for helping make this project better!
