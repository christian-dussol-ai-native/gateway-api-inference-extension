#!/usr/bin/env bash
#
# GAIE Routing Tutorial — Cleanup
# Tears down everything created by setup.sh.

set -uo pipefail  # not -e: we want cleanup to continue even if a resource is already gone

CLUSTER_NAME="gaie-lab"

echo "==> Deleting application manifests"
kubectl delete -f manifests/05-inferenceobjective.yaml --ignore-not-found
kubectl delete -f manifests/04-httproute.yaml --ignore-not-found
kubectl delete -f manifests/03-inferencepool.yaml --ignore-not-found
kubectl delete -f manifests/02-gateway.yaml --ignore-not-found
kubectl delete -f manifests/01-vllm-simulator.yaml --ignore-not-found

echo "==> Uninstalling Agentgateway"
helm uninstall agentgateway -n agentgateway-system --ignore-not-found || true
helm uninstall agentgateway-crds -n agentgateway-system --ignore-not-found || true

echo "==> Deleting the kind cluster (simplest full cleanup)"
kind delete cluster --name "${CLUSTER_NAME}"

echo "==> Done. Remember to stop cloud-provider-kind in its terminal (Ctrl+C)."
