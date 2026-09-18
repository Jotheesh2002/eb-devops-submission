cat > setup.sh << 'EOF'
#!/bin/bash
set -e

CLUSTER_NAME="demo"
NAMESPACE="demo"
RELEASE="demo"

echo "==> Checking for kind cluster '$CLUSTER_NAME'..."
if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "Creating kind cluster..."
  kind create cluster --name "$CLUSTER_NAME"
else
  echo "Cluster '$CLUSTER_NAME' already exists."
fi

echo "==> Setting kubectl context..."
kubectl cluster-info --context "kind-${CLUSTER_NAME}"

echo "==> Checking for ingress-nginx..."
if ! kubectl get namespace ingress-nginx &>/dev/null; then
  echo "Installing ingress-nginx..."
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm repo update
  helm install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx --create-namespace \
    --set controller.service.type=NodePort
else
  echo "ingress-nginx already installed."
fi

echo "==> Building Docker image..."
docker build -t eb-test:1.0.0 service/

echo "==> Loading image into cluster..."
kind load docker-image eb-test:1.0.0 --name "$CLUSTER_NAME"

echo "==> Creating namespace '$NAMESPACE'..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Installing Helm chart..."
helm upgrade --install "$RELEASE" ./chart \
  --namespace "$NAMESPACE" \
  --set image.repository=eb-test \
  --set image.tag=1.0.0

echo ""
echo "==> Waiting for rollout..."
kubectl rollout status deployment/"${RELEASE}" -n "$NAMESPACE" --timeout=2m

echo ""
echo "✓ Setup complete!"
echo ""
echo "To verify:"
echo "  kubectl -n $NAMESPACE get pods"
echo "  kubectl -n $NAMESPACE get ingress"
echo ""
EOF
chmod +x setup.sh
