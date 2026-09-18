# Enterprise Bot DevOps Take-Home Submission

## How to Run and Verify

**Setup (one command):**
```bash
./setup.sh
```

Creates a kind cluster, installs ingress-nginx, builds the image, and deploys the chart.

**Verify:**
```bash
kubectl -n demo get pods
kubectl -n demo get svc
kubectl -n demo get ingress
```

---

## Part 1 — Service and Dockerfile

**Service:** Python HTTP server. GET / returns JSON with `app`, `version`, `pod` (hostname). GET /healthz returns 200 OK. Both APP_NAME and VERSION come from environment variables.

**Dockerfile:** Multi-stage build, non-root user (appuser, UID 1000), pinned base image (python:3.11-slim), .dockerignore to exclude build artifacts.

**Why these choices:**
- Multi-stage: Reduces image size, prepares for future complexity.
- Non-root: Security — container can't modify system if compromised.
- Pinned base: Reproducible builds. `latest` can change unexpectedly.
- .dockerignore: Keeps build context small, faster pushes.

**Skipped for now:** Graceful shutdown (SIGTERM handling). In production, the service would drain in-flight requests before exiting.

---

## Part 2 — Helm Chart

**Structure:** Chart.yaml, values.yaml, templates (Deployment, Service, ConfigMap, Ingress, helpers, RBAC).

**Design:**
- ConfigMap for APP_NAME/VERSION: Decouples config from image. Harness overrides values at runtime.
- Liveness + Readiness probes: Both hit /healthz. Liveness restarts hung containers; readiness removes them from traffic while unhealthy.
- Resource requests/limits:
  - **Requests (50m CPU, 64Mi memory):** Kubernetes uses this for scheduling.
  - **Limits (200m CPU, 128Mi memory):** Hard ceiling. Prevents noisy neighbors.
  - Numbers are conservative for a lightweight HTTP service.
- Ingress: Routes demo.local via ingress-nginx (no TLS — not required).

**Skipped:** Pod Disruption Budgets, Network Policies, HPA — good for production but out of scope.

---

## Part 3 — Setup Script

**setup.sh does:**
1. Create kind cluster named `demo`
2. Install ingress-nginx (with wait for readiness — critical fix after first attempt)
3. Build Docker image
4. Load into cluster
5. Create namespace
6. Install Helm chart
7. Wait for rollout

**Idempotent:** Running twice is safe. Helm upgrade --install reuses releases. Namespace creation uses --dry-run=client.

---

## Part 4 — Debug Lab

**Incomplete.** I created scenario.sh, cluster-state, and FINDINGS.md template. The broken-chart needs debug work (logs, describe, events) to find and fix 6 defects. Time ran out after investing in Parts 1–3 setup issues.

**Next steps if I had time:**
- Run ./scenario.sh up to deploy
- Run ./scenario.sh verify to see failures
- kubectl logs, describe, get events to diagnose each defect
- Fix broken-chart templates/values
- Document findings in FINDINGS.md with actual command output

---

## Production Gaps

1. **Logging:** No structured logging. Real app → JSON logs to stdout.
2. **Metrics:** No Prometheus /metrics endpoint. Can't observe latency, errors, throughput.
3. **Secrets:** No vault/sealed-secrets integration.
4. **Image scanning:** No Trivy CVE scanning in CI.
5. **GitOps:** No ArgoCD/Flux for drift detection.
6. **High availability:** Single cluster, single ingress replica. No multi-region failover.
7. **Resilience:** No rate limiting, circuit breakers, or bulkheads in the gateway.

---

## How I Used AI

- **Claude:** Pair programming on Helm syntax (toYaml, nindent, include), debugging setup.sh webhook timing, prioritizing scope.
- **Specific:** Reviewed templating helpers, figured out ingress-nginx readiness issue from error message.
- **Myself:** Wrote Python service, designed YAML structure, diagnosed dev machine network issues, paced the 3-hour window.
- **Differently with time:** Debug Part 4 hands-on, add Prometheus metrics, write CI/CD workflow (bonus).

