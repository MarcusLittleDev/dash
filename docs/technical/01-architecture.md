## Architecture Overview

### High-Level System Architecture

```mermaid
graph TB
    subgraph "Client Layer"
        Web[Web Browser<br/>LiveView]
        Mobile[Mobile App<br/>Future API Client]
    end
    
    subgraph "Application Layer - BEAM Cluster"
        LV[LiveView UI<br/>Real-time Dashboards]
        API[REST/GraphQL API<br/>Ash Auto-generated]
        Workers[Pipeline Workers<br/>GenServers]
        Scheduler[Oban Scheduler<br/>Background Jobs]
    end
    
    subgraph "Data Layer"
        PG[(PostgreSQL<br/>Relational Data<br/>Teams, Users, Config)]
        TS[(TimescaleDB<br/>Time-Series Data<br/>Pipeline Data)]
        Cache[ETS Cache<br/>Hot Data<br/>Last 100 records]
    end
    
    subgraph "External Storage"
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
    
    style "Application Layer - BEAM Cluster" fill:#e1f5ff
    style "Data Layer" fill:#fff4e1
    style "External Storage" fill:#f0f0f0
```

### Data Flow Architecture

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

### Pipeline Execution Flow

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

### Scaling Phases

```mermaid
graph LR
    subgraph "Phase 1: 100-1K Users<br/>$500-2K/month"
        P1_App[Single BEAM Node<br/>2-4 cores]
        P1_DB[(Single TimescaleDB<br/>4GB RAM)]
        P1_Cache[ETS Cache]
        
        P1_App --> P1_DB
        P1_App --> P1_Cache
    end
    
    subgraph "Phase 2: 1K-10K Users<br/>$10-20K/month"
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
    
    subgraph "Phase 3: 10K-50K Users<br/>$50-100K/month"
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
    
    style "Phase 1: 100-1K Users<br/>$500-2K/month" fill:#e8f5e9
    style "Phase 2: 1K-10K Users<br/>$10-20K/month" fill:#fff3e0
    style "Phase 3: 10K-50K Users<br/>$50-100K/month" fill:#fce4ec
```

---

