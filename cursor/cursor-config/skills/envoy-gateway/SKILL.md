---
name: envoy-gateway
description: >-
  Envoy Gateway and Gateway API reference for advanced ingress and traffic management in Kubernetes. 
  Use when user mentions "Envoy Gateway", "Gateway API", "HTTPRoute", "TLSRoute", "traffic policies", 
  "gateway controller", or asks about advanced ingress patterns, API gateway functionality, 
  or migrating from traditional ingress controllers.
metadata:
  author: SHELYOG
  version: 2.0.0
  category: networking
  updated: 2026-05-03
---
# Envoy Gateway & Gateway API Comprehensive Reference

Use this skill when working with Envoy Gateway, Gateway API resources, or traffic routing configuration.

## Architecture

### Components
- **Envoy Gateway Controller** - Kubernetes control plane that watches Gateway API resources and generates Envoy configuration
- **Envoy Proxy (Data Plane)** - High-performance proxy handling live traffic; managed by the controller
- **Rate Limit Service** - Optional service for global rate limiting

### How It Works
1. User creates Gateway API resources (GatewayClass, Gateway, Routes)
2. Envoy Gateway translates these into Envoy xDS configuration
3. Envoy Proxy receives configuration and routes traffic accordingly
4. Status is reported back to the Gateway API resources

## Gateway API Resources

### GatewayClass
- Cluster-scoped resource defining the controller implementation
- One GatewayClass per Envoy Gateway controller
- Parameterized via `parametersRef` to EnvoyProxy resource

### Gateway
- Namespace-scoped; defines listeners (ports, protocols, TLS)
- Bound to a GatewayClass
- Each Gateway provisions its own Envoy Proxy deployment
- Multiple listeners per Gateway for different protocols/domains

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
spec:
  gatewayClassName: envoy-gateway
  listeners:
    - name: http
      port: 80
      protocol: HTTP
    - name: https
      port: 443
      protocol: HTTPS
      tls:
        mode: Terminate
        certificateRefs:
          - name: tls-secret
```

### Route Types
| Route | Protocol | Use Case |
|-------|----------|----------|
| HTTPRoute | HTTP/HTTPS | Web traffic, API routing |
| GRPCRoute | gRPC | gRPC services |
| TLSRoute | TLS | TLS passthrough |
| TCPRoute | TCP | Raw TCP traffic |
| UDPRoute | UDP | Raw UDP traffic |

### HTTPRoute Features
- Path matching: Exact, PathPrefix, RegularExpression
- Header matching: Exact, RegularExpression
- Query parameter matching
- Method matching
- Filters: RequestHeaderModifier, ResponseHeaderModifier, RequestRedirect, URLRewrite, RequestMirror, ExtensionRef
- Backend weighting for traffic splitting
- Timeouts per route

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-route
spec:
  parentRefs:
    - name: my-gateway
  hostnames:
    - "app.example.com"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api
      backendRefs:
        - name: api-service
          port: 8080
```

## Envoy Gateway CRDs

### EnvoyProxy
- Customize the Envoy Proxy data plane deployment
- Resource requests/limits, replicas, pod annotations
- Bootstrap configuration overrides
- Provider-specific settings (AWS NLB/ALB annotations)

### ClientTrafficPolicy
- Attached to Gateway listeners
- Client-facing settings:
  - TLS settings (min/max version, cipher suites, ALPN)
  - HTTP connection settings (HTTP/2, HTTP/3)
  - Client timeouts and keepalives
  - Client IP detection (XFF, custom header)
  - TCP keepalive settings

### BackendTrafficPolicy
- Attached to Gateway or Route resources
- Backend-facing settings:
  - Retry policy (number, backoff, retryable status codes)
  - Circuit breaker (max connections, pending requests, retries)
  - Load balancing algorithm (RoundRobin, LeastRequest, Random, ConsistentHash)
  - Timeouts (request, idle)
  - Health checks (active and passive)
  - Rate limiting (local and global)
  - Connection buffering

### SecurityPolicy
- Attached to Gateway or Route resources
- Authentication and authorization:
  - JWT validation (issuer, audiences, claim matching)
  - OIDC integration (provider discovery, client credentials)
  - Basic authentication
  - API key authentication
  - External authorization (ext_auth gRPC/HTTP service)
  - CORS policy

### EnvoyPatchPolicy
- Direct Envoy xDS configuration patches
- For advanced use cases not covered by standard policies
- JSON Patch operations on Envoy resources
- Use as escape hatch; prefer standard policies when possible

### EnvoyExtensionPolicy
- External processing filters
- Wasm extensions
- Ext_proc (external processing) integration

### Backend
- References non-Kubernetes backends
- FQDN or IP-based backends
- Allows routing to services outside the cluster

## Traffic Management Patterns

### TLS Termination
- Configure on Gateway listener with `tls.mode: Terminate`
- Reference Kubernetes TLS Secrets or AWS ACM certificates
- Use ClientTrafficPolicy for TLS version/cipher control

### Traffic Splitting (Canary/Blue-Green)
```yaml
backendRefs:
  - name: app-v1
    port: 8080
    weight: 90
  - name: app-v2
    port: 8080
    weight: 10
```

### Header-Based Routing
- Route to different backends based on headers
- Useful for A/B testing, feature flags

### Request/Response Modification
- Add/remove/set headers on requests and responses via filters
- URL rewriting (host, path)
- Redirects (scheme, host, path, port, status code)

### Rate Limiting
- **Local rate limiting** - Per-proxy instance limits
- **Global rate limiting** - Cluster-wide limits via Rate Limit Service
- Configure via BackendTrafficPolicy

## Observability

### Metrics
- Envoy Proxy exports Prometheus metrics by default
- Key metrics: request count, latency histograms, error rates, connection pools
- Configure via EnvoyProxy resource (Prometheus, OpenTelemetry)

### Access Logging
- Configurable access log format (text, JSON)
- Log to stdout, file, or OpenTelemetry collector
- Configure via EnvoyProxy resource

### Tracing
- Distributed tracing support (OpenTelemetry, Zipkin, Datadog)
- Configure via EnvoyProxy resource
- Propagates trace context headers

## Troubleshooting

### Common Issues
- **Route not matching** - Check hostnames, path matching, parentRefs, listener protocol
- **503 errors** - Backend not reachable; check Service endpoints, Network Policies
- **TLS errors** - Certificate mismatch, expired cert, wrong TLS mode
- **Policy not applied** - Check targetRef, resource exists, policy status

### Debugging Steps
1. Check resource status: `kubectl get gateway,httproute -o yaml`
2. Check Envoy Gateway controller logs
3. Check Envoy Proxy logs and access logs
4. Verify backend Service endpoints exist
5. Test connectivity: `kubectl port-forward` to Envoy Proxy pod
6. Review Network Policies blocking traffic

### Status Conditions
- All Gateway API resources report status conditions
- `Accepted` - Controller accepted the resource
- `Programmed` - Configuration applied to data plane
- `ResolvedRefs` - All references resolved successfully

## Migration from Ingress

- Gateway API replaces Ingress for HTTP routing
- Map Ingress rules to HTTPRoute rules
- Map Ingress annotations to policies (ClientTrafficPolicy, BackendTrafficPolicy, SecurityPolicy)
- Map IngressClass to GatewayClass
- Run both in parallel during migration; shift traffic gradually

## Reference Documentation

### Envoy Gateway
- **Envoy Gateway Home**: https://gateway.envoyproxy.io/
- **Concepts**: https://gateway.envoyproxy.io/latest/concepts/
- **Installation**: https://gateway.envoyproxy.io/latest/install/
- **API Reference**: https://gateway.envoyproxy.io/latest/api/
- **Tasks & Guides**: https://gateway.envoyproxy.io/latest/tasks/
- **Troubleshooting**: https://gateway.envoyproxy.io/latest/troubleshooting/
- **Envoy Gateway GitHub**: https://github.com/envoyproxy/gateway

### Gateway API
- **Gateway API Specification**: https://gateway-api.sigs.k8s.io/
- **API Reference**: https://gateway-api.sigs.k8s.io/reference/spec/
- **HTTPRoute**: https://gateway-api.sigs.k8s.io/api-types/httproute/
- **GatewayClass**: https://gateway-api.sigs.k8s.io/api-types/gatewayclass/
- **Gateway**: https://gateway-api.sigs.k8s.io/api-types/gateway/
- **Implementations**: https://gateway-api.sigs.k8s.io/implementations/
- **Gateway API GitHub**: https://github.com/kubernetes-sigs/gateway-api

### Envoy Proxy
- **Envoy Proxy Docs**: https://www.envoyproxy.io/docs/envoy/latest/
- **Configuration Best Practices**: https://envoyproxy.io/docs/envoy/latest/configuration/best_practices/best_practices
- **xDS Protocol**: https://www.envoyproxy.io/docs/envoy/latest/api-docs/xds_protocol
