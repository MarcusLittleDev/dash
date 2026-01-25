# Architecture Overview

Dash is a real-time data pipeline and visualization platform built on the BEAM VM (Elixir/Phoenix). The system scales from a single node serving hundreds of users to a distributed cluster handling tens of thousands of users with high-throughput data ingestion.

## Core Design Principles

1. **Real-time First**: LiveView-powered dashboards update instantly as data flows through pipelines
2. **Scalable by Design**: Horizontal scaling via BEAM clustering with specialized node roles
3. **Data Durability**: Multi-tiered storage (Bronze/Silver) enables replay and schema evolution
4. **Developer Experience**: Ash Framework provides declarative resource definitions and auto-generated APIs

## Distributed System Architecture

### Heterogeneous Clustering

Dash operates as a distributed BEAM cluster with specialized node roles to ensure heavy data processing never impacts UI responsiveness.

**Node Roles:**

- **`APP_ROLE=web`** - User-facing nodes
  - Optimized for: RAM and connection handling
  - Runs: Phoenix Endpoint, LiveView processes, static assets
  - Purpose: Serve web traffic and maintain WebSocket connections

- **`APP_ROLE=ingestor`** - Data processing nodes
  - Optimized for: CPU and throughput
  - Runs: Pipeline workers (GenServers), Oban job queue, Data Lake writers
  - Purpose: Handle heavy data ingestion and transformation workloads

### Distributed Communication

**Node Discovery:**
- Uses `dns_cluster` for automatic BEAM node peering
- Works with Fly.io's .internal DNS or Kubernetes headless services
- Nodes automatically join/leave cluster without manual configuration

**Real-time Updates:**
- Ingestor nodes broadcast via `Phoenix.PubSub` when batches are flushed
- Web nodes subscribe to `pipeline:<id>` topics
- LiveViews receive updates and push to clients via WebSockets

**State Management:**
- Pipeline configurations cached in distributed ETS table (via `:pg` or Horde)
- Ensures all nodes have consistent view of active pipelines
- Automatic failover if primary node crashes

### Security & Isolation

**Private Network:**
- Ingestor nodes are **not** exposed to public internet
- Communication happens over encrypted Fly.io WireGuard mesh (or k8s internal network)
- Only web nodes accept external traffic

**Token Authentication:**
- All pipeline ingress requires signed `pipeline_secret` in HTTP headers
- HMAC signature verification prevents unauthorized data submission
- Secrets encrypted at rest in PostgreSQL

---

**Note on Implementation Timeline:**

The distributed architecture described above is the **target production design**. Implementation follows this timeline:

- **Phase 1-2 (MVP)**: Single Fly.io node runs all components (web + ingestor)
- **Phase 3 (Month 7+)**: Split into specialized web and ingestor nodes when traffic justifies it

For detailed migration path, see [future-phases/01-distributed-architecture.md](../architecture/future-phases/01-distributed-architecture.md).

---

## Application Layers

Dash is built with a layered architecture where each layer has specific responsibilities and can scale independently.

### Layer Diagram

```mermaid
graph TB
    subgraph UserInterface["User Interface Layer"]
        Browser[Web Browser]
        Mobile[Mobile App<br/>Future]
    end

    subgraph Presentation["Presentation Layer - Web Nodes"]
        LiveView[Phoenix LiveView<br/>Real-time UI]
        Channels[Phoenix Channels<br/>WebSockets]
        Controllers[Phoenix Controllers<br/>HTTP API]
    end

    subgraph API["API Layer"]
        REST[REST API<br/>Controllers]
        GraphQL[GraphQL API<br/>Ash Generated<br/>Future]
        JSONAPI[JSON:API<br/>Ash Generated<br/>Future]
    end

    subgraph Business["Business Logic Layer - Ash Framework"]
        Resources[Resources<br/>User, Org, Team, Pipeline]
        Policies[Policies<br/>RBAC Authorization]
        Actions[Actions<br/>CRUD + Custom]
        Calculations[Calculations<br/>Computed Fields]
    end

    subgraph Processing["Processing Layer - Ingestor Nodes"]
        Workers[GenServer Workers<br/>Pipeline Execution]
        Oban[Oban Jobs<br/>Scheduled Tasks]
        Transformers[Data Transformers<br/>Mappings]
    end

    subgraph DataAccess["Data Access Layer"]
        Ecto[Ecto Queries<br/>Query Builder]
        AshData[Ash Data Layer<br/>Abstractions]
        ConnPool[Connection Pool<br/>pgbouncer]
    end

    subgraph Storage["Storage Layers"]
        Bronze[Bronze Layer<br/>Object Storage<br/>Raw JSONL]
        Silver[Silver Layer<br/>TimescaleDB<br/>Metrics]
        Relational[PostgreSQL<br/>Relational Data]
        Cache[ETS Cache<br/>Hot Data]
    end

    subgraph Communication["Communication Layer"]
        PubSub[Phoenix PubSub<br/>Cluster Events]
    end

    subgraph Integration["Integration Layers"]
        Sources[Source Adapters<br/>HTTP, GraphQL, Webhooks]
        Sinks[Sink Adapters<br/>Webhooks, Email, Slack]
    end

    Browser --> LiveView
    Browser --> Channels
    Mobile -.Future.-> REST

    LiveView --> Business
    Channels --> Business
    Controllers --> Business
    REST --> Business
    GraphQL -.Future.-> Business
    JSONAPI -.Future.-> Business

    Business --> Processing
    Business --> DataAccess

    Processing --> Transformers
    Processing --> Sources
    Processing --> Sinks
    Processing --> Bronze
    Processing --> Silver

    DataAccess --> Relational
    DataAccess --> Silver
    DataAccess --> Cache

    Processing --> PubSub
    Presentation --> PubSub

    PubSub -.Broadcast.-> LiveView

    style UserInterface fill:#e3f2fd
    style Presentation fill:#fff3e0
    style Business fill:#f3e5f5
    style Processing fill:#e8f5e9
    style Storage fill:#fce4ec
    style Communication fill:#fff9c4
```

### Layer Responsibilities

#### 1. User Interface Layer
- **Components**: Web browsers, mobile apps (future)
- **Purpose**: User interaction and display
- **Technologies**: HTML/CSS/JavaScript, Phoenix LiveView client

#### 2. Presentation Layer (Web Nodes)
- **Components**: Phoenix LiveView, Phoenix Channels, HTTP endpoints
- **Purpose**: Serve UI and maintain WebSocket connections
- **Optimization**: RAM and connection handling
- **Runs on**: `APP_ROLE=web` nodes

#### 3. API Layer
- **Components**: REST controllers, auto-generated GraphQL/JSON:API (future)
- **Purpose**: Programmatic access to Dash
- **Authentication**: Token-based, pipeline-specific tokens

#### 4. Business Logic Layer (Ash Framework)
- **Components**: Resources, policies, actions, calculations
- **Purpose**: Domain logic and authorization
- **Key Features**:
  - Declarative resource definitions
  - Row-level security with policies
  - Automatic API generation
  - Changesets and validations

#### 5. Processing Layer (Ingestor Nodes)
- **Components**: GenServer workers, Oban jobs, data transformers
- **Purpose**: Heavy data processing and pipeline execution
- **Optimization**: CPU and throughput
- **Runs on**: `APP_ROLE=ingestor` nodes
- **Key Processes**:
  - Pipeline polling workers
  - Webhook receivers
  - Data transformation
  - Bronze/Silver layer writes

#### 6. Data Access Layer
- **Components**: Ecto queries, Ash data layer, connection pooling
- **Purpose**: Database abstraction and query optimization
- **Features**:
  - Composable queries
  - Connection pooling
  - Read replica support
  - Query optimization

#### 7. Storage Layers (Medallion Architecture)
- **Bronze Layer**: Raw JSONL in object storage (R2/S3)
  - Purpose: Permanent source of truth
  - Enables: Pipeline replays, schema evolution
- **Silver Layer**: TimescaleDB time-series data
  - Purpose: Fast analytical queries
  - Enables: Real-time dashboards
- **Relational**: PostgreSQL for application data
  - Purpose: Users, teams, pipelines, configs
- **Cache**: ETS in-memory cache
  - Purpose: Hot data (last 100 records per pipeline)

#### 8. Communication Layer
- **Component**: Phoenix PubSub
- **Purpose**: Cluster-wide event broadcasting
- **Topics**: `pipeline:<id>`, `dashboard:<id>`
- **Use**: Real-time updates from ingestor → web nodes

#### 9. Integration Layers
- **Source Adapters**: Fetch data from external systems
  - HTTP API, GraphQL, webhooks, P2P pipelines
- **Sink Adapters**: Send data to external systems
  - Webhooks, email, Slack, custom APIs

### Cross-Cutting Concerns

**Security** (spans all layers):
- Authentication (AshAuthentication)
- Authorization (Ash policies)
- Encryption (at-rest and in-transit)
- Token management

**Observability** (instruments all layers):
- Structured logging (Elixir Logger)
- Metrics (Telemetry)
- Error tracking (Sentry)
- Health checks

**Reliability** (fault tolerance at each layer):
- Supervision trees
- Backpressure mechanisms
- Circuit breakers
- Retry logic

### Layer Scaling Strategy

| Layer | Phase 1 (MVP) | Phase 3 (Scale) |
|-------|---------------|-----------------|
| **Presentation** | Single node | Multi-region web nodes |
| **Processing** | Same node | Dedicated ingestor nodes |
| **Storage** | Single PostgreSQL | Primary + read replicas |
| **Cache** | Local ETS | Distributed cache (Horde) |
| **Communication** | Local PubSub | Distributed PubSub |

### Layer Abstraction Strategy

Infrastructure layers are abstracted using **Elixir Behaviours** to enable:
- Swappable implementations (R2 → S3, TimescaleDB → ClickHouse)
- Test adapters (in-memory mocks instead of real storage)
- Self-hosted deployments (local filesystem, bring-your-own database)

| Layer | Behaviour | Default Adapter |
|-------|-----------|-----------------|
| **Bronze (Data Lake)** | `Dash.Storage.Lake` | R2Adapter |
| **Silver (Metrics)** | `Dash.Storage.Metrics` | TimescaleAdapter |
| **Processing** | `Dash.Processing.Engine` | ObanAdapter |
| **Cache** | `Dash.Cache` | EtsAdapter |

**Implementation approach**: Extract Behaviours incrementally when there's a concrete need (testing, self-hosted, technology migration). See [DR-007](../reference/decisions.md#dr-007-layer-abstraction-with-behaviours) for full rationale.

---

## High-Level System Architecture

```mermaid
graph TB
    subgraph ClientLayer["Client Layer"]
        Web[Web Browser<br/>LiveView]
        Mobile[Mobile App<br/>Future API Client]
    end

    subgraph ApplicationLayer["Application Layer - BEAM Cluster"]
        LV[LiveView UI<br/>Real-time Dashboards]
        API[REST/GraphQL API<br/>Ash Auto-generated]
        Workers[Pipeline Workers<br/>GenServers]
        Scheduler[Oban Scheduler<br/>Background Jobs]
    end

    subgraph DataLayer["Data Layer"]
        PG[(PostgreSQL<br/>Relational Data<br/>Teams, Users, Config)]
        TS[(TimescaleDB<br/>Time-Series Data<br/>Pipeline Data)]
        Cache[ETS Cache<br/>Hot Data<br/>Last 100 records]
    end

    subgraph ExternalStorage["External Storage"]
        S3[Object Storage<br/>Cloudflare R2<br/>File Uploads]
        ExtAPI[External APIs<br/>Data Sources]
        Sinks[Data Sinks<br/>Destinations]
    end

    Web --> LV
    Web --> API
    Mobile -.Future.-> API

    LV --> Workers
    API --> Workers

    Workers --> Scheduler
    Scheduler --> Workers

    Workers --> PG
    Workers --> TS
    Workers --> Cache
    Workers --> S3

    Workers <--> ExtAPI
    Workers --> Sinks

    LV --> Cache
    LV --> PG
    API --> PG

    style ApplicationLayer fill:#e1f5ff
    style DataLayer fill:#fff4e1
    style ExternalStorage fill:#f0f0f0
```

## Data Flow Architecture

```mermaid
sequenceDiagram
    participant Src as External API
    participant Worker as Pipeline Worker
    participant Mapper as Data Mapper
    participant TS as TimescaleDB
    participant Cache as ETS Cache
    participant PubSub as Phoenix PubSub
    participant LV as LiveView Dashboard
    participant Sink as Data Sink

    Note over Worker: Scheduled or Webhook Triggered

    Worker->>Src: Poll for data / Receive webhook
    Src-->>Worker: Return raw data

    Worker->>Mapper: Transform with mappings
    Mapper-->>Worker: Transformed data

    par Persist & Distribute
        Worker->>TS: Batch insert (if persist=true)
        and
        Worker->>Cache: Update recent data
        and
        Worker->>Sink: Send to configured sinks
        and
        Worker->>PubSub: Broadcast new data event
    end

    PubSub-->>LV: Push real-time update

    LV->>Cache: Query recent data (fast)
    Cache-->>LV: Return cached records

    alt Need Historical Data
        LV->>TS: Query time-series data
        TS-->>LV: Return historical records
    end

    LV->>LV: Render/update charts
```

## Pipeline Execution Flow

```mermaid
flowchart TD
    Start([Pipeline Triggered]) --> CheckType{Pipeline Type?}

    CheckType -->|Polling| PollAPI[Poll External API<br/>HTTP/GraphQL]
    CheckType -->|Realtime| WaitWebhook[Receive Webhook<br/>POST endpoint]
    CheckType -->|P2P| ReadPipeline[Read from Another Pipeline]

    PollAPI --> FetchData[Fetch Raw Data]
    WaitWebhook --> ReceiveData[Receive Data]
    ReadPipeline --> SubscribeData[Subscribe to Pipeline]

    FetchData --> HasMapping{Has Data Mapping?}
    ReceiveData --> HasMapping
    SubscribeData --> HasMapping

    HasMapping -->|Yes| Transform[Apply Field Mappings<br/>Apply Transformations]
    HasMapping -->|No| UseRaw[Use Raw Data]

    Transform --> Validate[Validate Data]
    UseRaw --> Validate

    Validate --> ShouldPersist{Persist Setting?}

    ShouldPersist -->|Yes| BatchInsert[Batch Insert to TimescaleDB<br/>Chunks of 1000]
    ShouldPersist -->|No| SkipDB[Memory Only]

    BatchInsert --> UpdateCache[Update ETS Cache<br/>Keep last 100 records]
    SkipDB --> UpdateCache

    UpdateCache --> HasSinks{Has Data Sinks?}

    HasSinks -->|Yes| SendSinks[Send to Each Sink<br/>Async Tasks]
    HasSinks -->|No| Broadcast

    SendSinks --> Broadcast[Broadcast via PubSub<br/>pipeline:id channel]

    Broadcast --> UpdateDashboards[LiveView Dashboards<br/>Receive & Update]

    UpdateDashboards --> UpdateMetrics[Update Metrics<br/>Storage, Count, etc.]

    UpdateMetrics --> Schedule{Polling Pipeline?}

    Schedule -->|Yes| ScheduleNext[Schedule Next Oban Job<br/>Based on interval]
    Schedule -->|No| End([Complete])

    ScheduleNext --> End

    style Transform fill:#e1f5ff
    style BatchInsert fill:#fff4e1
    style UpdateCache fill:#ffe1e1
    style Broadcast fill:#e1ffe1
```

## Scaling Phases

```mermaid
graph LR
    subgraph Phase1["Phase 1: 100-1K Users"]
        P1_App[Single BEAM Node<br/>2-4 cores]
        P1_DB[(Single TimescaleDB<br/>4GB RAM)]
        P1_Cache[ETS Cache]

        P1_App --> P1_DB
        P1_App --> P1_Cache
    end

    subgraph Phase2["Phase 2: 1K-10K Users"]
        P2_App[BEAM Cluster<br/>2-5 nodes]
        P2_Primary[(Primary DB<br/>16GB RAM)]
        P2_Replica1[(Read Replica 1)]
        P2_Replica2[(Read Replica 2)]
        P2_Cache[Distributed Cache]

        P2_App -->|Writes| P2_Primary
        P2_App -->|Reads| P2_Replica1
        P2_App -->|Reads| P2_Replica2
        P2_Primary -.Async Repl.-> P2_Replica1
        P2_Primary -.Async Repl.-> P2_Replica2
        P2_App --> P2_Cache
    end

    subgraph Phase3["Phase 3: 10K-50K Users"]
        P3_App[BEAM Cluster<br/>10-50 nodes<br/>Kubernetes]
        P3_Hot[(Hot Storage<br/>ClickHouse<br/>Last 30 days)]
        P3_Cold[(Cold Storage<br/>S3 Parquet<br/>Historical)]
        P3_Kafka[Kafka Stream<br/>Data Ingestion]
        P3_Cache[Redis Cluster<br/>Distributed Cache]

        P3_App --> P3_Kafka
        P3_Kafka --> P3_Hot
        P3_Kafka --> P3_Cold
        P3_App --> P3_Cache
        P3_Hot -.Archive.-> P3_Cold
    end

    P1_DB -.Migrate.-> P2_Primary
    P2_Replica1 -.Evolve.-> P3_Hot

    style Phase1 fill:#e8f5e9
    style Phase2 fill:#fff3e0
    style Phase3 fill:#fce4ec
```

## Notes on Cost by Phase

- **Phase 1**: $500-2K/month infrastructure
- **Phase 2**: $10-20K/month infrastructure
- **Phase 3**: $50-100K/month infrastructure

---

## Key Changes Made

1. **Removed spaces from subgraph IDs**: Changed `"Application Layer - BEAM Cluster"` to `ApplicationLayer` with display name in brackets
2. **Fixed style references**: Now references the ID (`ApplicationLayer`) instead of the display name
3. **Applied same fix to all three diagrams** that had style statements

This syntax is compatible with GitHub, GitLab, and most Mermaid renderers.
