## Technology Stack

### Backend Technologies

| Component | Technology | Version | Rationale |
|-----------|-----------|---------|-----------|
| **Language** | Elixir | 1.16+ | Concurrency, fault tolerance, distributed |
| **Web Framework** | Phoenix | 1.7+ | Proven, batteries-included, LiveView |
| **Domain Framework** | Ash Framework | 3.0+ | Auto APIs, policies, resources |
| **Database ORM** | Ecto | 3.11+ | Mature, composable queries |
| **Time-Series** | TimescaleDB | 2.14+ | PostgreSQL extension, familiar SQL |
| **Job Processing** | Oban | 2.17+ | Reliable, uses PostgreSQL |
| **Authentication** | AshAuthentication | Latest | Built into Ash, multiple strategies |
| **Clustering** | libcluster | 3.3+ | Automatic BEAM node discovery |

### Frontend Technologies

| Component | Technology | Version | Rationale |
|-----------|-----------|---------|-----------|
| **UI Framework** | Phoenix LiveView | 0.20+ | Real-time, server-rendered |
| **Client Interactivity** | Alpine.js | 3.x | Lightweight (15kb), simple |
| **Styling** | Tailwind CSS | 3.x | Utility-first, fast development |
| **Charts** | Chart.js | 4.x | Flexible, well-documented |
| **Icons** | Heroicons | 2.x | Tailwind-compatible |

### Infrastructure

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| **Database** | PostgreSQL 16 + TimescaleDB | SQL, time-series, mature |
| **File Storage** | Cloudflare R2 | S3-compatible, no egress fees, Bronze layer (data lake) |
| **Hosting** | Fly.io | Elixir-optimized, global edge |
| **Container** | Docker | Standard, portable |
| **Secrets** | Fly.io Secrets | Integrated, simple |

### Why NOT These Alternatives

| Rejected | Reason |
|----------|--------|
| **Umbrella Project** | Unnecessary complexity, slower compilation, harder refactoring |
| **React/Vue SPA** | Two codebases, API overhead, no real-time benefits |
| **Lit Components** | Added complexity, start simple with LiveView |
| **Cassandra/Scylla** | Overkill, TimescaleDB sufficient, SQL easier |
| **Rust for DB Layer** | Database is bottleneck, not Elixir; premature optimization |
| **Kubernetes** | Too complex initially, BEAM clustering sufficient |
| **Supabase/Pocketbase** | Can't handle custom pipeline logic, not for time-series |

---

