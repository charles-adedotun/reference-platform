#!/bin/bash
set -e

echo "Installing ArgoCD..."

# Add ArgoCD Helm repository
echo "Adding ArgoCD Helm repository..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Create argocd namespace
echo "Creating argocd namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD via Helm
echo "Installing ArgoCD via Helm..."
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --values ../argocd/values.yaml \
  --wait \
  --timeout 10m

# Wait for argocd-server to be ready
echo "Waiting for ArgoCD server to be ready..."
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd

echo ""
echo "ArgoCD installed successfully!"
echo ""
echo "To get the admin password, run:"
echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
echo ""
echo "To access ArgoCD UI:"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "Then visit: https://localhost:8080"
echo ""
