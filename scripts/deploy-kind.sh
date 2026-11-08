#!/usr/bin/env bash
# Build the image, deploy it to a local kind cluster and wait until it is healthy.
set -euo pipefail
cd "$(dirname "$0")/.."

cluster="${KIND_CLUSTER:-workstation}"
kind get clusters | grep -qx "$cluster" || kind create cluster --name "$cluster"
docker build -f docker/Dockerfile -t linux-workstation:local .
kind load docker-image linux-workstation:local --name "$cluster"

kubectl apply -f k8s/base/namespace.yaml
if ! kubectl -n workstation get secret workstation-token >/dev/null 2>&1; then
  kubectl -n workstation create secret generic workstation-token \
    --from-literal=token="$(openssl rand -hex 24)"
fi
kubectl -n workstation delete job verify-workstation --ignore-not-found
kubectl apply -k k8s/overlays/local
kubectl -n workstation rollout status deployment/workstation --timeout=300s
kubectl -n workstation wait --for=condition=complete job/verify-workstation --timeout=300s
kubectl -n workstation logs job/verify-workstation
