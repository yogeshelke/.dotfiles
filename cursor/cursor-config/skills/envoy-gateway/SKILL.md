---
name: envoy-gateway
description: >-
  Envoy Gateway decision system for traffic management in Kubernetes. Use for routing strategy,
  TLS configuration, traffic policies, security policies, and observability.
  Do NOT use for general K8s networking (use kubernetes skill) or EKS LB controller (use eks skill).
metadata:
  author: SHELYOG
  version: 4.0.0
  category: networking
  updated: 2026-05-05
---
# Envoy Gateway Decision Engine

Decision rules for Envoy Gateway and Gateway API. Not reference material.

- K8s service networking → `skills/kubernetes/`
- EKS load balancer controller → `skills/eks/`
- Node autoscaling → `skills/karpenter/`

## Interaction Model
- This skill defines **north-south traffic routing, TLS, and traffic policies** only
- Pod-to-pod networking (east-west) → `kubernetes` skill or service mesh
- AWS ALB/NLB integration → `eks` skill
- Helm chart deployment of Envoy Gateway → `helm` skill
- DNS and Route53 → `aws` skill

## Decision Scope
- **Handles**: North-south traffic, L7 routing, traffic/security policies
- **Does NOT handle**: East-west (service mesh), pod networking, service discovery
- East-West → Istio/Linkerd or direct service calls — NOT Envoy Gateway

## Why Gateway API (not Ingress)
- Role separation: platform owns Gateway, app teams own Routes
- Richer routing: headers, query params, traffic splitting, gRPC native
- Extensible policies without annotation hacks
- Portable: vendor-neutral spec

---

## System Model

```
Internet → AWS NLB (L4) → Envoy Gateway → K8s Service → Pods
                              ↑
                    Routing, Auth, Rate Limit,
                    TLS termination, Observability
```

**Architecture**:
- Control plane: Envoy Gateway Controller (watches Gateway API resources → computes xDS config)
- Data plane: Envoy Proxy (one deployment per Gateway resource → serves traffic)
- xDS: Eventually syncs control plane to data plane (not instant, not atomic)

**Key principle**: correctness = config validity + propagation complete + runtime verified

**Ownership** (Gateway API role separation):

| Owner | Owns | Does NOT touch |
|---|---|---|
| Platform team | Gateway, GatewayClass, global policies, Envoy deployment | App-specific routes |
| Application teams | HTTPRoute, GRPCRoute, service-specific SecurityPolicy | Shared Gateway config |

---

## Decision Entry Points

| Task | Read sections |
|---|---|
| Expose new service externally | ROUTING + TLS |
| Add authentication/authorization | SECURITY |
| Configure retries/circuit breaking | TRAFFIC_POLICIES |
| Traffic splitting (canary/blue-green) | ROUTING |
| Performance/latency issues | PERFORMANCE |
| TLS certificate setup | TLS |
| Gateway placement / multi-team | ROUTING (Gateway design) |
| Debugging failures | TROUBLESHOOTING |

---

## Operational Risks (Quick Scan)

| Risk | Impact | Mitigation |
|---|---|---|
| Propagation delay | Config not live yet | Verify `Accepted`/`Programmed` status |
| xDS ordering race | Transient 503 (route before cluster) | Avoid rapid churn, validate e2e |
| Valid-but-wrong config | Goes live immediately — no safety net | Progressive rollout, never full cutover |
| Retry storms | Amplify outages under load | Budget cap (<25%), idempotent-only |
| Shared gateway blast radius | One bad route impacts all services | Namespace isolation or dedicated gateway |
| Filter chain stacking | p99 latency creeps silently | Audit filters, minimize chain |
| Fail-open vs fail-close | Security vs availability tradeoff | Explicit per-service decision |
| Config drift | Envoy runs stale config indefinitely | Periodic `/config_dump` verification |
| Data plane overload | Connection drops, cascading failures | Circuit breakers + overload manager |
| Long-lived connections | Old config until reconnect | Connection drain during rollouts |

---

<!-- CORE_DECISIONS: Read this section for design choices and constraints -->

## Cross-Cutting Rules

| Decision | Domains | Rule |
|---|---|---|
| TLS termination at gateway | TLS + Routing | All external traffic terminates TLS at Gateway |
| Rate limiting on public endpoints | Security + Traffic | Every public route must have rate limiting |
| Health checks on backends | Traffic + Routing | BackendTrafficPolicy with active health checks |
| Standard policies first | All | ClientTrafficPolicy/BackendTrafficPolicy before EnvoyPatchPolicy |
| Observability by default | All | Access logging + metrics on every Gateway |
| Fail-close for auth | Security | Auth dependency failure → block traffic |
| Circuit breakers always | Traffic | Configure per upstream cluster |

---

<!-- REFERENCE: Detailed implementation patterns below. Read only when you need specific configs. -->

## [ROUTING]

**Route type selection**:
- HTTP/HTTPS → HTTPRoute | gRPC → GRPCRoute | TLS passthrough → TLSRoute | TCP → TCPRoute

**Matching strategy**:
- **Default**: PathPrefix (most common)
- **If exact endpoint** → Exact match
- **If complex patterns** → RegularExpression (sparingly — performance cost)
- **If versioned API** → Header-based matching

**Traffic splitting** (canary/blue-green):
```yaml
backendRefs:
  - name: app-v1
    port: 8080
    weight: 90
  - name: app-v2
    port: 8080
    weight: 10
```

**Progressive rollout**:
1. Start at 1-10% → monitor error rate + p99 latency
2. Stable → increase (10 → 25 → 50 → 100%)
3. Regression → immediately shift 100% back to stable
4. Rollback must be faster than rollout (single weight change)
5. **Never** full cutover without validation at partial traffic

**Gateway design**:
- **Default**: Shared gateway per domain group (reduces LB cost)
- **If team isolation** → Dedicated gateway per team
- **If compliance boundary** → Separate gateway in isolated namespace
- **If blast radius concern** → Dedicated for critical services
- Multiple listeners per Gateway (HTTP redirect + HTTPS)

**Scaling**:
- Small cluster → single shared gateway
- Medium → shared + dedicated for critical services
- Large → sharded by domain/team
- **Envoy HA**: ≥2 replicas, HPA on CPU/request rate, pod anti-affinity across AZs

---

## [TLS]

**Mode selection**:

| Mode | Use when | Tradeoff |
|---|---|---|
| Terminate at gateway | Most services (default) | Backend traffic unencrypted within cluster |
| Passthrough (TLSRoute) | Compliance, regulated data | No L7 routing or policy enforcement |
| Re-encrypt | Balance security + observability | Complexity, double TLS overhead |

**Certificate management**:
- **If TLS terminates at Envoy Gateway** (default) → Kubernetes TLS Secrets via cert-manager or External Secrets
- **If TLS terminates at AWS LB** (ALB/NLB via AWS LB Controller) → ACM via annotations
- These are mutually exclusive — choose based on where termination happens

**TLS policy** (ClientTrafficPolicy):
- Minimum: TLS 1.2 | Prefer: TLS 1.3 | Strong cipher suites only | Enable ALPN for HTTP/2

---

## [TRAFFIC_POLICIES]

**ClientTrafficPolicy** (client → gateway): HTTP/2-3, timeouts, keepalives, client IP detection. Targets Gateway only (not routes), must be in same namespace.

**BackendTrafficPolicy** (gateway → backend):
- Retries: 3 attempts, exponential backoff, on 5xx + reset
- Circuit breaker: max connections, pending requests, retries per cluster (counters are per Envoy process, not globally synchronized)
- Load balancing: RoundRobin (default), LeastRequest (varied latency)
- Timeouts: request + idle timeout
- Health checks: active HTTP every 10s
- Targets Gateway or HTTPRoute, must be in same namespace as target

**Retry safety** (retries can cause outages):
- Only retry idempotent: GET, HEAD, OPTIONS, PUT
- Never retry: non-idempotent POSTs unless explicitly safe
- Budget: <25% of total requests | Backoff: always exponential
- During outages: retries multiply load — cap `maxRetries`

**Rate limiting**:
- **Local**: Per-proxy-instance, no external service, simple
- **Global**: Cluster-wide via Rate Limit Service
- Use global when: multi-replica gateway, shared API quota, tenant-based limits, billing
- Use local when: burst protection, DDoS mitigation, approximate is acceptable

---

## [SECURITY]

**Auth options** (pick based on use case):
- JWT validation → stateless API auth
- OIDC → web app SSO
- API key → machine-to-machine
- ext_auth → complex logic (external gRPC/HTTP service)
- Basic auth → internal tools only (never production APIs)

**CORS**: Configure on browser-facing routes (origins, methods, headers)

**EnvoyPatchPolicy**: Escape hatch only — avoid unless standard policies insufficient. Document rationale.

**Failure mode** (ext_auth, rate limit service):

| Mode | Behavior | Use when |
|---|---|---|
| Fail-close | Block requests (503) | Auth, payments, PII |
| Fail-open | Allow without check | Non-critical, read-only |

- **Rule**: Explicitly choose per service — never leave default undefined
- Document the decision for incident response clarity

---

## [POLICY_ATTACHMENT_RULES]

| Policy | Scope | Targets | Namespace rule |
|---|---|---|---|
| BackendTrafficPolicy | Backend behavior (retries, rate limits, circuit breakers) | Gateway, HTTPRoute, GRPCRoute | Same namespace as target |
| ClientTrafficPolicy | Client/downstream behavior (HTTP settings, timeouts) | Gateway (listener-level only) | Same namespace as Gateway |
| SecurityPolicy | Auth, CORS, authorization | Gateway, HTTPRoute, GRPCRoute; limited TCPRoute (IP allow/deny only) | Same namespace as target |

**Precedence** (more specific wins): route-rule > route > listener > gateway

**Rules**:
- All policies must be in the same namespace as their target resource
- Avoid multiple same-level policies unless precedence is intentional and documented
- Circuit breaker counters are per Envoy process (not globally synchronized across replicas)

---

## [PERFORMANCE]

**External LB choice** (AWS-specific):
- **Default**: NLB (L4) — Envoy handles all L7
- **If WAF/Shield needed** → ALB (but double L7 processing)
- **If static IP** → NLB (Elastic IP per AZ)
- **Avoid**: ALB L7 routing + Envoy L7 routing (redundant)

**Latency budget**: NLB (~0.5-2ms) + Envoy (~1-5ms, filter-dependent) + backend
- Monitor p95/p99 — averages hide tail latency
- Every policy adds per-request latency
- Tracing: sample 1-10% in production

**Filter chain** (sequential per request):
- Order: auth → rate limit → routing → logging
- Expensive (network calls): ext_auth, global rate limit
- Cheap (local): JWT decode, local rate limit, header manipulation
- **Rule**: Minimize chain; place short-circuit filters early; audit when p99 rises

---

## [RUNTIME_BEHAVIOR]

**Config propagation**: apply → controller reconcile → xDS push → Envoy applies → traffic changes
- Not instant. Verify `Accepted`/`Programmed` before testing.
- Wait for propagation before shifting more traffic during rollouts.

**xDS ordering**: Routes (RDS) depend on clusters (CDS) depend on endpoints (EDS)
- Out-of-order delivery → transient 503 (route exists, backend missing)
- Mitigation: avoid rapid successive changes; validate end-to-end

**Config safety**:

| Case | Behavior |
|---|---|
| Invalid config | Rejected — previous stays active (safe) |
| Valid but wrong config | Applied immediately (dangerous) |

- xDS protects against schema errors, NOT logic errors
- Rollback = traffic shift (weight change), not config revert
- **Rule**: Treat config changes like code deploys — progressive rollout always

**Connection vs request model**:
- Filter chain selection → per connection (TLS, protocol)
- Routing → per request (path, headers)
- Long-lived connections (HTTP/2, gRPC, WebSocket) continue with old config until reconnect
- During rollouts: force connection drain if immediate effect needed

**Control plane backpressure**:
- Controller recomputes on every resource change; batches reduce CPU spikes
- Envoy processes xDS updates sequentially (ACK/NACK) — high churn causes queue delay
- **Rule**: Batch changes; avoid CI loops creating/deleting routes rapidly

**Drift detection**:
- Desired: Gateway API resources | Actual: Envoy runtime (`/config_dump`)
- Signals: metrics mismatch routing, `envoy_*_update_rejected` counters increasing
- **Rule**: Never assume applied — periodically verify status + runtime + behavior

**Data plane overload**:
- Symptoms: p99 spikes, `downstream_cx_overflow`, `upstream_rq_pending_overflow`
- Protection: circuit breakers (per cluster) + rate limiting (shed load early) + overload manager
- **Rule**: Always configure circuit breakers; tune from observed traffic + backend capacity

---

## Anti-Patterns

| Anti-Pattern | Do This Instead |
|---|---|
| No health checks | BackendTrafficPolicy with active checks |
| Overly broad route matching | Specific path/host matching |
| No retry policy | 3 retries with backoff on 5xx (idempotent only) |
| TLS 1.0/1.1 allowed | Minimum TLS 1.2 |
| No rate limiting on public routes | Rate limit all public endpoints |
| EnvoyPatchPolicy for standard features | Standard policies first |
| Retrying non-idempotent requests | Only retry safe operations |
| Envoy Gateway for east-west traffic | Service mesh or direct calls |
| No retry budget | Cap at <25% of total traffic |
| Apps modifying shared Gateway | Apps own Routes only |
| Not checking resource status | Always verify Accepted/Programmed |
| Single gateway at scale | Shard by domain/team |
| Single Envoy replica in production | ≥2 replicas with HPA |
| Undefined fail-open/fail-close | Explicit per-service decision |

---

## Configuration Validation

```bash
kubectl get gateway -A              # Programmed=True
kubectl get httproute -A            # Accepted=True
kubectl describe gateway <name>     # rejection reasons in events
kubectl describe httproute <name>   # parentRef resolution
```
- If not `Accepted` + `Programmed` → config is **ignored** (silent failure)
- Common causes: wrong parentRef, hostname mismatch, missing TLS secret, namespace mismatch

---

## Troubleshooting Decision Trees

**Route not matching?**
1. Hostname matches Gateway listener? 2. parentRefs correct (name + namespace)? 3. Path match type (Prefix vs Exact)? 4. Protocol matches listener?

**503 errors?**
1. Backend pods running? 2. Service endpoints exist? 3. Network Policy blocking? 4. Health check failing? 5. xDS ordering race (transient)?

**TLS errors?**
1. Certificate SAN matches hostname? 2. Not expired? 3. TLS mode correct? 4. Client supports min version?

**Policy not applied?**
1. targetRef correct? 2. Same namespace? 3. Status shows Accepted? 4. xDS propagation complete?

**Config changed but traffic didn't?**
1. Status verified (Accepted/Programmed)? 2. Long-lived connections still active? → Force drain 3. xDS backpressure queueing? 4. Drift between desired and runtime?

---

## Reference Documentation

- **Envoy Gateway**: https://gateway.envoyproxy.io/
- **Gateway API Spec**: https://gateway-api.sigs.k8s.io/
- **HTTPRoute**: https://gateway-api.sigs.k8s.io/api-types/httproute/
- **Envoy Gateway API Reference**: https://gateway.envoyproxy.io/latest/api/
- **Tasks & Guides**: https://gateway.envoyproxy.io/latest/tasks/
- **Envoy Proxy**: https://www.envoyproxy.io/docs/envoy/latest/
