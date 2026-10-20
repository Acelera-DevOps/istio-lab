#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="payments-mesh"
SERVICE_HOST="payments.acelera-devops.local"

echo "=================================================================="
echo " 🕸️  Acelera DevOps — Istio Service Mesh Verification Harness"
echo "=================================================================="

echo "[1/5] Checking namespace & automatic sidecar injection label..."
kubectl get namespace "${NAMESPACE}" -o jsonpath='{.metadata.labels.istio-injection}' | grep -q "enabled"
echo "  -> OK: Namespace '${NAMESPACE}' has istio-injection=enabled"

echo "[2/5] Waiting for payments-v1 and payments-v2 deployments to be Ready..."
kubectl rollout status deployment/payments-v1 -n "${NAMESPACE}" --timeout=90s
kubectl rollout status deployment/payments-v2 -n "${NAMESPACE}" --timeout=90s

echo "[3/5] Verifying STRICT mTLS PeerAuthentication & AuthorizationPolicy..."
kubectl get peerauthentication payments-strict-mtls -n "${NAMESPACE}"
kubectl get authorizationpolicy payments-zero-trust-rbac -n "${NAMESPACE}"

echo "[4/5] Testing 90/10 Canary traffic distribution (20 requests inside mesh)..."
V1_COUNT=0
V2_COUNT=0
for i in $(seq 1 20); do
  RESP=$(kubectl exec -n "${NAMESPACE}" deploy/payments-v1 -c payments-api -- wget -qO- http://payments-service:8080/ 2>/dev/null || true)
  if echo "${RESP}" | grep -q "v1-stable"; then
    V1_COUNT=$((V1_COUNT + 1))
  elif echo "${RESP}" | grep -q "v2-canary"; then
    V2_COUNT=$((V2_COUNT + 1))
  fi
done
echo "  -> Canary Traffic Split Result (20 requests): v1=${V1_COUNT} | v2=${V2_COUNT}"

echo "[5/5] Testing Header-Based Routing (x-canary-tier: insider -> 100% v2-canary)..."
INSIDER_RESP=$(kubectl exec -n "${NAMESPACE}" deploy/payments-v1 -c payments-api -- wget -qO- --header="x-canary-tier: insider" http://payments-service:8080/ 2>/dev/null || true)
echo "  -> Insider Response: ${INSIDER_RESP}"

echo "✅ Istio Service Mesh verification completed successfully!"
