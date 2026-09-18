#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"
NS=debug-lab
RELEASE=debug-lab
C_GREEN=$'\033[32m'; C_RED=$'\033[31m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ${C_GREEN}PASS${C_OFF}  $*"; }
bad() { FAIL=$((FAIL+1)); echo "  ${C_RED}FAIL${C_OFF}  $*"; }
up() {
  echo "==> applying cluster environment (cluster-state/)"
  kubectl apply -f cluster-state/
  echo "==> installing the broken chart"
  if ! helm upgrade --install "$RELEASE" ./broken-chart -n "$NS"; then
    echo "${C_DIM}helm reported an error.${C_OFF}"
  fi
}
verify() {
  echo "==> verifying goal state in namespace $NS"
  if [ "$(kubectl -n "$NS" get job migrate -o jsonpath='{.status.succeeded}' 2>/dev/null)" = "1" ]; then
    ok "migrate Job completed"
  else
    bad "migrate Job has not completed"
  fi
  for d in backend gateway worker reporter metrics; do
    want=$(kubectl -n "$NS" get deploy "$d" -o jsonpath='{.spec.replicas}' 2>/dev/null)
    have=$(kubectl -n "$NS" get deploy "$d" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
    if [ -n "$want" ] && [ "${have:-0}" = "$want" ]; then
      ok "deployment $d: $have/$want ready"
    else
      bad "deployment $d: ${have:-0}/${want:-?} ready"
    fi
  done
  echo ""
  if [ "$FAIL" -eq 0 ]; then
    echo "${C_GREEN}ALL GREEN${C_OFF}"
  else
    echo "${C_RED}$FAIL check(s) failing${C_OFF}"
  fi
  exit "$FAIL"
}
reset() {
  helm uninstall "$RELEASE" -n "$NS" 2>/dev/null || true
  kubectl delete namespace "$NS" --ignore-not-found --wait=true
}
case "${1:-}" in
  up)     up ;;
  verify) verify ;;
  reset)  reset ;;
  *) echo "usage: $0 up|verify|reset"; exit 2 ;;
esac
