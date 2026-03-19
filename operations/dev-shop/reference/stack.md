# Tech Stack Decisions

> Technology choices with rationale. Load at boot.

## Core Stack

| Layer | Technology | Version | Rationale |
|-------|-----------|---------|-----------|
| Frontend Framework | React | 18+ | Component model, ecosystem, team expertise |
| Frontend Language | TypeScript | 5+ | Type safety, refactoring confidence, IDE support |
| Styling | Tailwind CSS | 3+ | Utility-first, consistent design tokens, small bundle |
| Backend Framework | Node.js + Express | 20+ / 4+ | JavaScript fullstack, async I/O, ecosystem |
| Backend Language | TypeScript | 5+ | Shared types with frontend, strict mode required |
| Database | PostgreSQL | 16+ | ACID compliance, JSON support, full-text search |
| ORM | Prisma | 5+ | Type-safe queries, migration management, schema-first |
| Cache | Redis | 7+ | Session storage, caching, rate limiting |
| Message Queue | BullMQ (Redis-backed) | 5+ | Background jobs, retry logic, dashboard |
| API Style | REST | -- | Predictable, cacheable, well-understood |
| Auth | JWT + refresh tokens | -- | Stateless auth, httpOnly cookie storage |
| Testing | Vitest + Playwright | -- | Fast unit tests, reliable E2E |

## Infrastructure

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| Container Runtime | Docker | Standard containerization, reproducible builds |
| Orchestration | Docker Compose (dev), Kubernetes (prod) | Simple local dev, scalable production |
| CI/CD | GitHub Actions | Integrated with repo, free tier sufficient |
| Monitoring | Prometheus + Grafana | Open source, flexible, proven at scale |
| Logging | Structured JSON + Loki | Grep-friendly, Grafana integration |
| Error Tracking | Sentry | Real-time error reporting with context |
| CDN | Cloudflare | Edge caching, DDoS protection, DNS |

## Decision Records

Significant technology decisions are documented as ADRs in `docs/adrs/`.
When evaluating a new technology, document:
1. What problem it solves
2. What alternatives were considered
3. Why this option was chosen
4. What trade-offs were accepted

## Upgrade Policy

- **Patch versions**: auto-update via Dependabot, merge if CI passes
- **Minor versions**: review changelog, update within 2 weeks
- **Major versions**: evaluate breaking changes, schedule upgrade sprint
- **Security patches**: apply within 24 hours for P0/P1 CVEs
