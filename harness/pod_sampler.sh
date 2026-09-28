#!/usr/bin/env bash
# One-shot pod-metrics sampler for the sci#1685 dry-check.
# Context pinned on EVERY call (fleet rule). Samples until killed.
set -u
CTX="gke_tercen-ring_europe-west4_tercen"
OUT="$1"
while true; do
  echo "=== $(date -u +%FT%TZ)" >> "$OUT"
  kubectl --context "$CTX" top pod -n tercen-stage \
    -l app.kubernetes.io/name=tercen-worker 2>/dev/null | grep worker >> "$OUT"
  sleep 10
done
