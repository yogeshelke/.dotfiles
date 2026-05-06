---
name: docker
description: >-
  Docker containerization decision system. Use for base image selection, multi-stage build
  strategy, security hardening, image optimization, and ECR workflows. Covers build patterns
  for Node.js, Go, and Python. Security constraints enforced via aws-security.mdc.
  Do NOT use for Kubernetes orchestration (use kubernetes skill) or CI/CD pipelines
  (use github skill) unless Docker-specific.
metadata:
  author: SHELYOG
  version: 3.0.0
  category: infrastructure
  updated: 2026-05-05
---
# Docker Decision Engine

Decision rules for container image builds and ECR workflows. Not reference material.

- Security constraints → enforced via `aws-security.mdc` (always-on)
- Kubernetes runtime → `skills/kubernetes/`, `skills/eks/`
- This file answers: **what base image, what build pattern, and why not**

## Interaction Model
- This skill defines **image build patterns, security hardening, and ECR workflows** only
- Container orchestration (pods, deployments) → `kubernetes` skill
- ECR repository Terraform config → `terraform` skill
- CI/CD image build pipeline → `github` skill
- Base OS / instance selection → `aws` skill (compute section)
- Multi-arch node support → `karpenter` skill

---

## Decision Entry Points

Navigate by task type:

| Building... | Read sections |
|---|---|
| New containerized service | BASE_IMAGE + BUILD_STRATEGY + SECURITY |
| Optimizing image size | BASE_IMAGE + OPTIMIZATION |
| Securing container images | SECURITY + BASE_IMAGE |
| ECR repository setup | ECR |
| Multi-arch / Graviton support | MULTI_ARCH + BUILD_STRATEGY |
| CI/CD image pipeline | BUILD_STRATEGY + ECR + OPTIMIZATION |

---

<!-- CORE_DECISIONS: Read this section for design choices and constraints -->

## Cross-Cutting Rules

Decisions that span multiple domains (apply regardless of section):

| Decision | Domains | Rule |
|---|---|---|
| Non-root execution | Security + Build | Mandatory — always UID 1001+, never root |
| Multi-stage builds | Build + Optimization | Mandatory — separate build and runtime stages |
| Immutable tags | ECR + Security | Never deploy `latest` to production — use semver or SHA |
| BuildKit | Build + Security + Optimization | Always enable — required for secrets, cache mounts |
| .dockerignore | Build + Optimization | Required — exclude .git, node_modules, .env, tests |
| HEALTHCHECK | Security + Build | Required in all production images |
| Image scanning | Security + ECR | Enable on push — block HIGH/CRITICAL in CI |

---

<!-- REFERENCE: Detailed implementation patterns below. Read only when you need specific configs. -->

## [BASE_IMAGE]

| Base Image | Size | When to Use | When NOT to Use |
|---|---|---|---|
| `scratch` | 0 MB | Statically compiled Go/Rust binaries | Need shell, CA certs, or debugging |
| `distroless/static` | ~2 MB | Static binaries needing CA certs | Need shell or package manager |
| `distroless/base` | ~20 MB | Dynamically linked binaries | Need debugging tools |
| `alpine` | ~7 MB | Need shell for debugging, apk packages | glibc-dependent apps (use slim) |
| `*-slim` (debian) | ~80 MB | Need glibc, broader package availability | Production images where smaller is possible |
| Full images | 200+ MB | Build stages only | Never in production runtime stage |

**Decision flow**:
- Go/Rust with static linking → `scratch` or `distroless/static`
- Go/Rust with dynamic linking → `distroless/base`
- Node.js/Python → `alpine` (general) or `slim` (glibc issues)
- Need debugging in production → `alpine` (has shell)
- Pin base image digests for reproducible builds in production

---

## [BUILD_STRATEGY]

**Default**: Multi-stage with BuildKit enabled (`DOCKER_BUILDKIT=1`)

### Node.js
```dockerfile
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build && npm prune --production

FROM node:20-alpine AS runtime
RUN addgroup -g 1001 -S appgroup && adduser -S appuser -u 1001 -G appgroup
WORKDIR /app
COPY --from=build --chown=appuser:appgroup /app/node_modules ./node_modules
COPY --from=build --chown=appuser:appgroup /app/dist ./dist
COPY --from=build --chown=appuser:appgroup /app/package*.json ./
USER 1001
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1
CMD ["node", "dist/index.js"]
```

### Go (distroless)
```dockerfile
FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/server ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /app/server /server
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/server"]
```

### Python
```dockerfile
FROM python:3.12-slim AS build
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim AS runtime
RUN groupadd -g 1001 appgroup && useradd -u 1001 -g appgroup -s /bin/false appuser
WORKDIR /app
COPY --from=build /install /usr/local
COPY --chown=appuser:appgroup . .
USER 1001
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"
CMD ["gunicorn", "app:create_app()", "--bind", "0.0.0.0:8000"]
```

---

## [SECURITY]

**Non-root user** — mandatory (Alpine: `addgroup -g 1001 -S` + `adduser -S -u 1001`; Debian: `groupadd -g 1001` + `useradd -u 1001`). Always `USER 1001`. See BUILD_STRATEGY examples.

**Build-time secrets** — BuildKit mounts only, never ARG/ENV:
```dockerfile
# syntax=docker/dockerfile:1
RUN --mount=type=secret,id=api_key \
    API_KEY=$(cat /run/secrets/api_key) && \
    # Use during build — never stored in layer
```
Build with: `docker build --secret id=api_key,src=./api_key.txt .`

**Runtime securityContext** (K8s Pod spec — must match Dockerfile USER):
`runAsNonRoot: true`, `runAsUser/Group: 1001`, `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`, `capabilities.drop: ["ALL"]`

**Image scanning**: `trivy image --severity HIGH,CRITICAL myapp:latest` in CI; enable ECR scan-on-push for runtime

---

## [OPTIMIZATION]

**Layer ordering** — dependencies before source (cache preservation):
1. COPY dependency manifests (package.json, go.mod, requirements.txt)
2. RUN install dependencies
3. COPY source code
4. RUN build

**Cache mounts** (BuildKit): `RUN --mount=type=cache,target=/root/.npm npm ci` / `--mount=type=cache,target=/root/.cache/pip pip install`

**Rules**:
- Combine RUN commands to reduce layers
- Copy only artifacts from build stage — never full build context
- `--no-cache-dir` for pip, `npm cache clean --force` for npm
- `.dockerignore` mandatory: `.git node_modules .env* test/ coverage/ docs/ *.md .terraform *.tfstate* .vscode .idea`

---

## [ECR]

**Auth**: `aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin <account>.dkr.ecr.eu-central-1.amazonaws.com`

**Rules**:
- Enable image scanning on push — block deployments on HIGH/CRITICAL findings
- Use immutable tags for production (`v1.2.3`, never `latest`)
- Configure lifecycle policies to expire old images
- Cross-region replication for DR scenarios
- VPC endpoints for private ECR access from EKS

**Lifecycle policy** (Terraform): `aws_ecr_lifecycle_policy` with `imageCountMoreThan` rule (keep last 30 images). See `skills/terraform/` for full patterns.

---

## [MULTI_ARCH]

**When to build multi-arch**: EKS clusters with Graviton/ARM64 nodes (20-40% cost savings)

```bash
docker buildx create --name multiarch --use
docker buildx build --platform linux/amd64,linux/arm64 \
  -t <account>.dkr.ecr.eu-central-1.amazonaws.com/myapp:v1.0.0 \
  --push .
```

**Decision**: If Karpenter provisions ARM64 nodes → all images must be multi-arch

---

## Anti-Patterns (Never Do)

| Anti-Pattern | Why It's Wrong | Do This Instead |
|---|---|---|
| Running as root | Full container compromise on exploit | Non-root user (UID 1001+) |
| Secrets in ENV/ARG | Persisted in image layers, visible in inspect | BuildKit `--mount=type=secret` |
| No .dockerignore | Bloated context, secrets leaked into build | Maintain .dockerignore (see OPTIMIZATION) |
| `latest` tag in production | Non-reproducible, silent overwrites | Immutable semver or git SHA tags |
| Full base image in runtime stage | 200+ MB unnecessary bloat | Alpine/distroless/scratch |
| No HEALTHCHECK | K8s can't determine container health | Add HEALTHCHECK in Dockerfile |
| Dev tools in production image | Larger attack surface, wasted space | Multi-stage — dev tools in build stage only |
| Single-stage builds | Build tools + source in production image | Multi-stage with artifact copy |
| Ignoring layer order | Cache invalidation on every build | Dependencies before source code |

---

## Troubleshooting Decision Trees

**Build is slow?**
1. Layer ordering correct? → Dependencies before source code
2. .dockerignore excludes changing files? → Add .git, node_modules, tests
3. Using BuildKit cache mounts? → Enable for npm/pip/go caches
4. Context too large? → Run with `--progress=plain` to check size

**Image too large (> 500MB)?**
1. Using multi-stage? → If no, add build + runtime stages
2. Runtime base image minimal? → Switch to Alpine/distroless/scratch
3. Node.js? → `npm ci --only=production` + prune devDependencies
4. Python? → `--no-cache-dir` + slim base + multi-stage

**Security scan failures?**
1. CVE in base image? → Pin to latest patched version, rebuild
2. High-severity in dependency? → Update dependency; document exception if upstream
3. Secrets detected in layer? → Use BuildKit `--mount=type=secret`, never ARG/ENV

---

## Reference Documentation

- **Dockerfile Reference**: https://docs.docker.com/reference/dockerfile/
- **Multi-Stage Builds**: https://docs.docker.com/build/building/multi-stage/
- **BuildKit**: https://docs.docker.com/build/buildkit/
- **Docker Security Best Practices**: https://docs.docker.com/build/building/best-practices/
- **ECR User Guide**: https://docs.aws.amazon.com/AmazonECR/latest/userguide/what-is-ecr.html
- **Distroless Images**: https://github.com/GoogleContainerTools/distroless
- **Chainguard Images**: https://www.chainguard.dev/chainguard-images
- **Multi-Platform Builds**: https://docs.docker.com/build/building/multi-platform/
