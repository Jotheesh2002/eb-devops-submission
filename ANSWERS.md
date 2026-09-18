# Q1: Migrating 40 Ingress Objects to Kubernetes Gateway API (No Downtime)

## Approach

**Phase 1: Preparation (1-2 weeks)**
- Install Gateway API CRDs and controller (e.g., ingress-nginx-based Gateway controller) in the cluster.
- Audit the 40 Ingress objects: identify common patterns, TLS termination, routing rules, host-based vs path-based.
- Set up metrics: track in-flight request latency, error rates, connection resets before/during/after migration.
- Create Gateway and HTTPRoute test objects in a staging namespace to validate syntax and behavior.

**Phase 2: Gradual Migration (4-8 weeks, in batches)**
- **Start with stateless, low-traffic services:** Migrate 5-10 Ingress objects at a time to HTTPRoute + Gateway.
- **Dual-run period (1-2 weeks per batch):** Keep the old Ingress and new Gateway/HTTPRoute both active. Route some percentage of traffic to the new path using a traffic splitter (if available) or via DNS/LoadBalancer config.
- **Validation:** Monitor metrics for latency increase, error rate spike, or connection issues.
- **Rollback trigger:** If latency p99 > 110% of baseline or error rate > baseline + 1%, revert that batch and investigate.
- **Repeat:** Once a batch is stable (3-5 days), mark it complete and move to the next batch.

**Phase 3: Sunset Ingress (1 week)**
- Remove all old Ingress objects only after all HTTPRoute batches are validated and stable for 1 week.
- Keep the Ingress controller running for 1-2 weeks as a safety net (easy to re-enable if needed).
- Monitor for 24 hours post-removal.

## Order of Migration

1. **Non-critical internal services first** (staging, dev tools, monitoring dashboards).
2. **Single-host services** (simplest routing rules, lowest risk).
3. **High-traffic customer-facing services last** (most operational expertise, slowest rollback).

## What Will Likely Break

1. **TLS certificate paths:** If you're using cert-manager annotations on Ingress, Gateway API may require explicit Certificate objects or a different cert-manager integration. Test this early.
2. **Custom headers / request/response transformation:** ingress-nginx Ingress uses annotations (`nginx.ingress.kubernetes.io/...`). Gateway API uses Policy objects (more verbose but explicit). Some annotations have no Gateway equivalent; you'll need to rewrite routing logic.
3. **Namespace scoping:** Ingress objects can only reference services in the same namespace. Gateway listeners can cross namespaces with ReferenceGrant. This is a feature, but requires careful RBAC audits to avoid unintended cross-namespace exposure.
4. **Old client versions:** If you have clients using Service discovery DNS names hardcoded as Ingress hosts, they won't resolve post-migration. Rare but check.
5. **Controller bugs:** The Gateway controller (ingress-nginx-based or Envoy Gateway) may have edge cases ingress-nginx doesn't. Expect a 10-20% chance of issues on the first few batches. That's why batching matters.

## Risk Mitigation

- **Metrics-first:** Set up Prometheus dashboards for latency (p50, p95, p99), error rates (4xx, 5xx), and connection resets before starting.
- **Feature flags / traffic splitting:** Use a load balancer or service mesh (if available) to route X% of traffic to Gateway, Y% to Ingress, during the overlap period. If X% of users see errors, immediately flip to 0% and investigate.
- **Runbook:** Pre-write the rollback procedure. "If p99 latency > 500ms, delete all HTTPRoute objects in namespace X and restore the old Ingress YAML from git."
- **Communication:** Notify on-call and support teams. "We're migrating routing layer for service X this week. If customers report HTTP errors, page us immediately."
- **Vendor lock-in awareness:** Gateway API is newer and less battle-tested than Ingress. If you need to switch controllers later (e.g., Envoy Gateway → ingress-nginx), Gateway API gives you optionality. Ingress kept you locked into ingress-nginx.

## Timeline Summary

- **Weeks 1-2:** Setup, testing, metrics.
- **Weeks 3-10:** Gradual migration in 5-10 object batches (1-2 weeks per batch).
- **Week 11:** Sunset old Ingress, monitor for 24 hours.
- **Total:** ~2.5 months with low risk. Rushing it to 2 weeks trades risk for speed.

