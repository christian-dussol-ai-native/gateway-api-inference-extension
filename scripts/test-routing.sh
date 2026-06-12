#!/usr/bin/env bash
#
# GAIE Routing Tutorial — Test the routing path
# Sends an inference request through the gateway to the vLLM simulator.

set -euo pipefail

MODEL_NAME="dummy-model-name"

echo "==> Resolving gateway address"
IP=$(kubectl get gateway/inference-gateway -o jsonpath='{.status.addresses[0].value}')
PORT=80

if [ -z "${IP}" ]; then
  echo "ERROR: gateway has no address yet."
  echo "Check that cloud-provider-kind is running and the gateway is PROGRAMMED=True:"
  echo "  kubectl get gateway inference-gateway -o yaml"
  exit 1
fi

echo "    Gateway address: ${IP}:${PORT}"
echo ""
echo "==> Sending an inference request through the gateway"
curl -i "${IP}:${PORT}/v1/completions" \
  -H 'Content-Type: application/json' \
  -d "{
    \"model\": \"${MODEL_NAME}\",
    \"prompt\": \"Write as if you were a critic: San Francisco\",
    \"max_tokens\": 100,
    \"temperature\": 0
  }"

echo ""
echo "==> Request sent. Capture the response above for the write-up."
echo "    Note: the vLLM simulator returns simulated output. This validates the"
echo "    routing PATH (Gateway -> EPP -> InferencePool -> simulator), not real"
echo "    model performance."
