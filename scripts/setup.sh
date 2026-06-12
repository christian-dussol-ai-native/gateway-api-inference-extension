#!/usr/bin/env bash
#
# GAIE Routing Tutorial — Setup
# Mirrors the README steps exactly. Run it after reading the README at least once.
#
# ⚠️ Agentgateway is beta. RE-VERIFY versions before running:
#    https://gateway-api-inference-extension.sigs.k8s.io/guides/getting-started-latest/
#    https://agentgateway.dev/docs/
#
# Reminder: cloud-provider-kind must be running in a SEPARATE terminal (sudo) for the
# Gateway to get an external address.

set -euo pipefail

INFERENCE_POOL_NAME="vllm-sim"       # Helm release name and InferencePool name
MODEL_SERVER_LABEL="vllm-qwen3-32b" # app label on simulator pods (from sim-deployment.yaml)
GATEWAY_PROVIDER="none"
AGW_VERSION="v1.0.0"                # RE-VERIFY
GATEWAY_API_VERSION="v1.5.0"        # RE-VERIFY

echo "==> [1] Creating kind cluster"
kind create cluster --name gaie-lab
kubectl get nodes
echo ">>> Start 'sudo cloud-provider-kind --gateway-channel=disabled' in a separate terminal now."
echo "    (--gateway-channel=none prevents it from downgrading the Gateway API CRDs we just installed)"
read -r -p "Press enter once cloud-provider-kind is running..."

echo "==> [2] Resolving latest GAIE release"
IGW_RELEASE=$(curl -s https://api.github.com/repos/kubernetes-sigs/gateway-api-inference-extension/releases \
  | jq -r '.[] | select(.prerelease == false) | .tag_name' | sort -V | tail -n1)
echo "    GAIE release: ${IGW_RELEASE}"

echo "==> [3] Installing CRDs"
kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml"
kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/download/${IGW_RELEASE}/manifests.yaml"
kubectl get crds | grep inference.networking || echo "    (no inference CRDs — investigate)"

echo "==> [4] Deploying vLLM simulator (no GPU)"
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/raw/main/config/manifests/vllm/sim-deployment.yaml

echo "==> [5] Installing Agentgateway (beta — version ${AGW_VERSION})"
helm upgrade -i --create-namespace --namespace agentgateway-system --version "${AGW_VERSION}" \
  agentgateway-crds oci://cr.agentgateway.dev/charts/agentgateway-crds
helm upgrade -i --namespace agentgateway-system --version "${AGW_VERSION}" \
  agentgateway oci://cr.agentgateway.dev/charts/agentgateway --set inferenceExtension.enabled=true
echo "    Waiting for GatewayClass to be created..."
for i in $(seq 1 30); do
  kubectl get gatewayclass agentgateway &>/dev/null && break
  sleep 2
done
kubectl wait --for=condition=Accepted gatewayclass/agentgateway --timeout=60s \
  || echo "    (gatewayclass not accepted after 60s — investigate)"
kubectl get gatewayclass agentgateway

echo "==> [6] Deploying the Gateway"
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/raw/main/config/manifests/gateway/agentgateway/gateway.yaml
kubectl get gateway inference-gateway

echo "==> [7] Installing InferencePool + EPP (chart version ${IGW_RELEASE})"
helm install "${INFERENCE_POOL_NAME}" \
  --dependency-update \
  --version "${IGW_RELEASE}" \
  --set inferencePool.modelServers.matchLabels.app="${MODEL_SERVER_LABEL}" \
  --set provider.name="${GATEWAY_PROVIDER}" \
  --set inferencePool.modelServerType=vllm \
  --set inferencePool.modelServerProtocol=http \
  --set experimentalHttpRoute.enabled=true \
  oci://us-central1-docker.pkg.dev/k8s-staging-images/gateway-api-inference-extension/charts/inferencepool

echo "==> [9] InferenceObjective (priority)"
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/raw/main/config/manifests/inferenceobjective.yaml

echo ""
echo "==> Done issuing setup. Verify:"
echo "    kubectl get gateway inference-gateway        # ADDRESS + PROGRAMMED=True"
echo "    kubectl get inferencepool ${INFERENCE_POOL_NAME} -o yaml"
echo "    kubectl get pods | grep epp"
echo "    kubectl get httproute"
echo "Then: ./scripts/test-routing.sh"
