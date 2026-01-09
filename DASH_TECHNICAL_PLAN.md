# Dash Application - Complete Technical Plan

**Version:** 1.0  
**Last Updated:** January 2026  
**Author:** Technical Planning Session

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [Technology Stack](#technology-stack)
4. [Database Design](#database-design)
5. [Data Pipeline System](#data-pipeline-system)
6. [Dashboard & Widget System](#dashboard--widget-system)
7. [Data Transformation](#data-transformation)
8. [Security Architecture](#security-architecture)
9. [Deployment Strategy](#deployment-strategy)
10. [Scaling Strategy](#scaling-strategy)
11. [Monitoring & Observability](#monitoring--observability)
12. [Development Roadmap](#development-roadmap)
13. [Cost Estimates](#cost-estimates)
14. [Decision Records](#decision-records)
15. [Reference](#reference)

---

## Executive Summary

### What is Dash?

Dash is a configurable data pipeline and dashboard platform that allows users to:
- Create data pipelines from various sources (APIs, webhooks, other pipelines)
- Transform and map data to desired schemas
- Persist data with flexible retention policies
- Visualize data in real-time customizable dashboards
- Share dashboards publicly or within teams
- Route data to multiple sinks/destinations

### Key Features

- **Multi-tenancy:** Team-based organization with role-based permissions
- **Flexible Data Sources:** Polling APIs, webhooks, pipeline-to-pipeline
- **Data Transformation:** Field mapping and custom transformations
- **Real-time Dashboards:** Live-updating visualizations using LiveView
- **Public Sharing:** Shareable dashboard links with access tokens
- **Data Sinks:** Forward data to external systems
- **File Support:** Handle file uploads via object storage
- **API-First:** GraphQL and REST APIs for mobile/external access

### Target Scale

**Phase 1 (MVP):** 100-1,000 users  
**Phase 2 (Growth):** 1,000-10,000 users  
**Phase 3 (Scale):** 10,000-50,000 users  
**Phase 4 (Enterprise):** 50,000+ users (requires architectural evolution)

### Technology Highlights

- **Backend:** Elixir/Phoenix with Ash Framework
- **Frontend:** Phoenix LiveView + Alpine.js
- **Database:** PostgreSQL + TimescaleDB extension
- **Deployment:** Fly.io (initially), Docker containers
- **Storage:** Cloudflare R2 for files

---

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
| **File Storage** | Cloudflare R2 | S3-compatible, no egress fees |
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

## Database Design

### Entity Relationship Diagram

```mermaid
erDiagram
    TEAMS ||--o{ USERS : "has members"
    TEAMS ||--o{ PIPELINES : owns
    TEAMS ||--o{ DASHBOARDS : owns
    USERS ||--o{ MEMBERSHIPS : "belongs to teams via"
    TEAMS ||--o{ MEMBERSHIPS : has
    PIPELINES ||--o{ PIPELINE_SINKS : has
    PIPELINES ||--o| DATA_MAPPINGS : has
    PIPELINES ||--o{ PIPELINE_DATA : generates
    DASHBOARDS ||--o{ WIDGETS : contains
    DASHBOARDS }o--o{ PIPELINES : "displays data from"
    
    TEAMS {
        uuid id PK
        string name
        string slug UK
        integer storage_limit_gb
        decimal storage_used_gb
        timestamp inserted_at
        timestamp updated_at
    }
    
    USERS {
        uuid id PK
        string email UK
        string hashed_password
        boolean email_confirmed
        timestamp inserted_at
        timestamp updated_at
    }
    
    MEMBERSHIPS {
        uuid id PK
        uuid team_id FK
        uuid user_id FK
        enum role "owner,admin,member,viewer"
        boolean active
        timestamp inserted_at
        timestamp updated_at
    }
    
    PIPELINES {
        uuid id PK
        uuid team_id FK
        string name
        enum type "polling,realtime,p2p"
        enum status "active,paused,error"
        integer interval_seconds
        string source_type
        jsonb source_config "encrypted"
        integer retention_days "null=indefinite"
        boolean persist_data
        timestamp inserted_at
        timestamp updated_at
    }
    
    PIPELINE_SINKS {
        uuid id PK
        uuid pipeline_id FK
        string sink_type
        jsonb sink_config "encrypted"
        timestamp inserted_at
        timestamp updated_at
    }
    
    DATA_MAPPINGS {
        uuid id PK
        uuid pipeline_id FK
        jsonb source_schema
        jsonb mappings "field mappings"
        jsonb transformations
        timestamp inserted_at
        timestamp updated_at
    }
    
    PIPELINE_DATA {
        bigserial id PK
        uuid pipeline_id FK
        uuid team_id FK
        jsonb data
        timestamptz ingested_at
    }
    
    DASHBOARDS {
        uuid id PK
        uuid team_id FK
        string name
        string slug UK
        boolean is_public
        string public_token
        jsonb layout
        integer refresh_interval_seconds
        timestamp inserted_at
        timestamp updated_at
    }
    
    WIDGETS {
        uuid id PK
        uuid dashboard_id FK
        string type "table,line_chart,bar_chart,stat_card"
        jsonb config "widget-specific settings"
        jsonb position "grid position x,y,w,h"
        jsonb data_query "pipeline,fields,filters"
        timestamp inserted_at
        timestamp updated_at
    }
```

### TimescaleDB Time-Series Schema

```sql
-- Hypertable for pipeline data (automatically partitioned by time)
CREATE TABLE pipeline_data (
  id BIGSERIAL,
  pipeline_id UUID NOT NULL,
  team_id UUID NOT NULL,
  data JSONB NOT NULL,
  ingested_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (pipeline_id, ingested_at, id)
);

-- Convert to hypertable (TimescaleDB magic)
SELECT create_hypertable(
  'pipeline_data', 
  'ingested_at',
  chunk_time_interval => INTERVAL '1 day',
  partitioning_column => 'pipeline_id',
  number_partitions => 4
);

-- Indexes for performance
CREATE INDEX idx_pipeline_data_pipeline_time 
  ON pipeline_data (pipeline_id, ingested_at DESC);

CREATE INDEX idx_pipeline_data_team 
  ON pipeline_data (team_id);

CREATE INDEX idx_pipeline_data_gin 
  ON pipeline_data USING GIN (data);

-- Compression policy (compress data older than 7 days)
SELECT add_compression_policy('pipeline_data', INTERVAL '7 days');

-- Continuous aggregates (pre-computed hourly rollups)
CREATE MATERIALIZED VIEW pipeline_data_hourly
WITH (timescaledb.continuous) AS
SELECT 
  time_bucket('1 hour', ingested_at) AS bucket,
  pipeline_id,
  team_id,
  COUNT(*) as record_count,
  SUM(pg_column_size(data)) as total_bytes
FROM pipeline_data
GROUP BY bucket, pipeline_id, team_id;

-- Refresh policy for continuous aggregate
SELECT add_continuous_aggregate_policy(
  'pipeline_data_hourly',
  start_offset => INTERVAL '3 hours',
  end_offset => INTERVAL '1 hour',
  schedule_interval => INTERVAL '1 hour'
);

-- Retention policy (set per pipeline dynamically)
-- Example: Delete data older than 90 days
-- SELECT add_retention_policy('pipeline_data', INTERVAL '90 days');
```

### Connection Pooling Strategy

```elixir
# config/config.exs

# Main repo for writes
config :dash, Dash.Repo,
  pool_size: 20,  # Smaller pool for writes
  queue_target: 5000,
  queue_interval: 1000

# Read replica pool (points to same DB initially, easy to split later)
config :dash, Dash.Repo.Replica,
  pool_size: 50,  # Larger pool for reads
  queue_target: 5000,
  queue_interval: 1000,
  priv: "priv/repo"  # Share migrations

# Usage pattern:
# Writes: Dash.Repo.insert_all(...)
# Reads: Dash.Repo.Replica.all(...)
```

---

## Data Pipeline System

### Pipeline Worker Architecture

```elixir
# lib/dash/pipelines/supervisor.ex
defmodule Dash.Pipelines.Supervisor do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_pipeline(pipeline) do
    spec = {Dash.Pipelines.Worker, pipeline}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def stop_pipeline(pipeline_id) do
    case Registry.lookup(Dash.Registry, {:pipeline, pipeline_id}) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> :ok
    end
  end
end

# lib/dash/pipelines/worker.ex
defmodule Dash.Pipelines.Worker do
  use GenServer
  require Logger

  def start_link(pipeline) do
    GenServer.start_link(__MODULE__, pipeline,
      name: {:via, Registry, {Dash.Registry, {:pipeline, pipeline.id}}}
    )
  end

  def init(pipeline) do
    # Subscribe to pipeline configuration changes
    Phoenix.PubSub.subscribe(Dash.PubSub, "pipeline:#{pipeline.id}:config")
    
    # Schedule initial run if polling
    if pipeline.type == :polling && pipeline.status == :active do
      schedule_poll(0)  # Run immediately
    end
    
    {:ok, %{pipeline: pipeline, last_run: nil}}
  end

  def handle_info(:poll, state) do
    pipeline = state.pipeline
    
    # Fetch data from source
    case fetch_data(pipeline) do
      {:ok, raw_data} ->
        # Process the data
        process_data(pipeline, raw_data)
        
        # Schedule next poll
        schedule_poll(pipeline.interval_seconds * 1000)
        
        {:noreply, %{state | last_run: DateTime.utc_now()}}
        
      {:error, reason} ->
        Logger.error("Pipeline #{pipeline.id} fetch failed: #{inspect(reason)}")
        
        # Mark pipeline as errored
        Ash.update!(pipeline, :mark_error, %{error_message: inspect(reason)})
        
        # Retry after backoff
        schedule_poll(60_000)  # 1 minute
        
        {:noreply, state}
    end
  end

  # Handle configuration updates
  def handle_info({:config_updated, updated_pipeline}, state) do
    {:noreply, %{state | pipeline: updated_pipeline}}
  end

  defp fetch_data(pipeline) do
    adapter = get_source_adapter(pipeline.source_type)
    adapter.fetch(pipeline.source_config)
  end

  defp process_data(pipeline, raw_data) do
    # Load data mapping if exists
    pipeline = Ash.load!(pipeline, :data_mapping)
    
    # Transform data
    transformed = Dash.Pipelines.DataMapper.transform(raw_data, pipeline.data_mapping)
    
    # Persist if configured
    if pipeline.persist_data do
      Dash.Data.PipelineData.insert_batch(
        pipeline.id,
        pipeline.team_id,
        transformed
      )
    end
    
    # Update cache
    Dash.Data.CacheManager.update_recent_data(pipeline.id, transformed)
    
    # Send to sinks
    send_to_sinks(pipeline, transformed)
    
    # Broadcast to dashboards
    Phoenix.PubSub.broadcast(
      Dash.PubSub,
      "pipeline:#{pipeline.id}",
      {:new_data, transformed}
    )
  end

  defp send_to_sinks(pipeline, data) do
    pipeline = Ash.load!(pipeline, :sinks)
    
    Enum.each(pipeline.sinks, fn sink ->
      Task.Supervisor.start_child(Dash.TaskSupervisor, fn ->
        adapter = get_sink_adapter(sink.sink_type)
        adapter.send(sink.sink_config, data)
      end)
    end)
  end

  defp schedule_poll(milliseconds) do
    Process.send_after(self(), :poll, milliseconds)
  end

  defp get_source_adapter("http_api"), do: Dash.Pipelines.Adapters.Sources.HttpApi
  defp get_source_adapter("graphql"), do: Dash.Pipelines.Adapters.Sources.GraphQL
  # ... more adapters

  defp get_sink_adapter("http_api"), do: Dash.Pipelines.Adapters.Sinks.HttpApi
  defp get_sink_adapter("webhook"), do: Dash.Pipelines.Adapters.Sinks.Webhook
  # ... more adapters
end
```

### Scheduled Pipelines (Oban)

```elixir
# lib/dash/pipelines/workers/polling_worker.ex
defmodule Dash.Pipelines.Workers.PollingWorker do
  use Oban.Worker,
    queue: :pipelines,
    max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"pipeline_id" => pipeline_id}}) do
    pipeline = Ash.get!(Dash.Pipelines.Pipeline, pipeline_id,
      load: [:sinks, :data_mapping]
    )
    
    # Fetch from source
    {:ok, raw_data} = fetch_from_source(pipeline)
    
    # Transform
    transformed = Dash.Pipelines.DataMapper.transform(raw_data, pipeline.data_mapping)
    
    # Persist
    if pipeline.persist_data do
      Dash.Data.PipelineData.insert_batch(pipeline.id, pipeline.team_id, transformed)
    end
    
    # Update cache & broadcast
    Dash.Data.CacheManager.update_recent_data(pipeline.id, transformed)
    Phoenix.PubSub.broadcast(Dash.PubSub, "pipeline:#{pipeline.id}", {:new_data, transformed})
    
    # Send to sinks
    Enum.each(pipeline.sinks, &send_to_sink(&1, transformed))
    
    :ok
  end

  defp fetch_from_source(pipeline) do
    # Implementation
  end

  defp send_to_sink(sink, data) do
    # Implementation
  end
end

# Schedule a pipeline
def schedule_pipeline(pipeline) do
  %{pipeline_id: pipeline.id}
  |> PollingWorker.new(schedule_in: {pipeline.interval_seconds, :second})
  |> Oban.insert()
end
```

### Webhook Receiver

```elixir
# lib/dash_web/controllers/pipeline_webhook_controller.ex
defmodule DashWeb.PipelineWebhookController do
  use DashWeb, :controller
  
  plug :verify_webhook_signature when action in [:receive]
  plug :rate_limit when action in [:receive]

  def receive(conn, %{"pipeline_id" => pipeline_id} = params) do
    pipeline = Ash.get!(Dash.Pipelines.Pipeline, pipeline_id,
      load: [:sinks, :data_mapping]
    )
    
    # Verify pipeline is active and realtime type
    if pipeline.status == :active && pipeline.type == :realtime do
      # Parse webhook data
      data = parse_webhook_payload(params)
      
      # Process asynchronously
      Task.Supervisor.start_child(Dash.TaskSupervisor, fn ->
        process_webhook_data(pipeline, data)
      end)
      
      json(conn, %{status: "received", pipeline_id: pipeline_id})
    else
      conn
      |> put_status(400)
      |> json(%{error: "Pipeline not configured for webhooks"})
    end
  end

  defp verify_webhook_signature(conn, _opts) do
    signature = get_req_header(conn, "x-webhook-signature") |> List.first()
    pipeline_id = conn.path_params["pipeline_id"]
    
    # Get pipeline webhook secret
    pipeline = Ash.get!(Dash.Pipelines.Pipeline, pipeline_id)
    secret = get_in(pipeline.source_config, ["webhook_secret"])
    
    # Read body
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    
    # Verify signature
    expected = :crypto.mac(:hmac, :sha256, secret, body)
                |> Base.encode16(case: :lower)
    
    if Plug.Crypto.secure_compare(signature || "", expected) do
      conn |> assign(:verified, true)
    else
      conn
      |> put_status(401)
      |> json(%{error: "Invalid signature"})
      |> halt()
    end
  end

  defp rate_limit(conn, _opts) do
    pipeline_id = conn.path_params["pipeline_id"]
    
    case Hammer.check_rate("webhook:#{pipeline_id}", 60_000, 100) do
      {:allow, _count} -> conn
      {:deny, _limit} ->
        conn
        |> put_status(429)
        |> json(%{error: "Rate limit exceeded"})
        |> halt()
    end
  end

  defp process_webhook_data(pipeline, data) do
    # Same processing as polling worker
    transformed = Dash.Pipelines.DataMapper.transform(data, pipeline.data_mapping)
    
    if pipeline.persist_data do
      Dash.Data.PipelineData.insert_batch(pipeline.id, pipeline.team_id, [transformed])
    end
    
    Dash.Data.CacheManager.update_recent_data(pipeline.id, [transformed])
    Phoenix.PubSub.broadcast(Dash.PubSub, "pipeline:#{pipeline.id}", {:new_data, [transformed]})
  end
end
```

### Source Adapters

```elixir
# lib/dash/pipelines/adapters/sources/http_api.ex
defmodule Dash.Pipelines.Adapters.Sources.HttpApi do
  @behaviour Dash.Pipelines.Adapters.SourceBehaviour

  @impl true
  def fetch(config) do
    url = config["url"]
    method = String.to_atom(config["method"] || "get")
    headers = build_headers(config)
    body = config["body"] || ""
    
    case HTTPoison.request(method, url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}
      
      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, "HTTP #{status}"}
      
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp build_headers(config) do
    base_headers = [{"Content-Type", "application/json"}]
    
    case config["auth_type"] do
      "bearer" ->
        [{"Authorization", "Bearer #{config["token"]}"} | base_headers]
      
      "api_key" ->
        [{config["api_key_header"], config["api_key"]} | base_headers]
      
      _ ->
        base_headers
    end
  end
end

# Behaviour definition
# lib/dash/pipelines/adapters/source_behaviour.ex
defmodule Dash.Pipelines.Adapters.SourceBehaviour do
  @callback fetch(config :: map()) :: {:ok, data :: term()} | {:error, reason :: term()}
end
```

---

## Dashboard & Widget System

### LiveView Dashboard

```elixir
# lib/dash_web/live/dashboard_live.ex
defmodule DashWeb.DashboardLive do
  use DashWeb, :live_view

  @impl true
  def mount(%{"slug" => slug}, session, socket) do
    # Load dashboard with all associations
    dashboard = Ash.get!(Dash.Dashboards.Dashboard, :get_by_slug,
      %{slug: slug},
      load: [:widgets, :pipelines, :team],
      actor: get_actor(session)
    )
    
    # Subscribe to pipeline updates if connected
    if connected?(socket) do
      Enum.each(dashboard.pipelines, fn pipeline ->
        Phoenix.PubSub.subscribe(Dash.PubSub, "pipeline:#{pipeline.id}")
      end)
    end
    
    socket =
      socket
      |> assign(:dashboard, dashboard)
      |> assign(:widgets, dashboard.widgets)
      |> assign(:is_public, dashboard.is_public)
      |> load_widget_data()
    
    {:ok, socket}
  end

  @impl true
  def handle_info({:new_data, pipeline_id, data}, socket) do
    # Update widgets that use this pipeline
    socket = update_widgets_for_pipeline(socket, pipeline_id, data)
    {:noreply, socket}
  end

  defp load_widget_data(socket) do
    widget_data =
      Enum.map(socket.assigns.widgets, fn widget ->
        data = fetch_widget_data(widget)
        {widget.id, data}
      end)
      |> Map.new()
    
    assign(socket, :widget_data, widget_data)
  end

  defp fetch_widget_data(widget) do
    pipeline_id = get_in(widget.data_query, ["pipeline_id"])
    
    # Try cache first (last 100 records)
    case Dash.Data.CacheManager.get_recent_data(pipeline_id) do
      data when length(data) > 0 ->
        # Have cached data, use it
        prepare_for_widget(data, widget)
      
      [] ->
        # No cache, query database
        from_time = DateTime.add(DateTime.utc_now(), -1, :hour)
        data = Dash.Data.PipelineData.query_for_widget(pipeline_id,
          from: from_time,
          limit: 100
        )
        prepare_for_widget(data, widget)
    end
  end

  defp prepare_for_widget(data, widget) do
    Dash.Dashboards.WidgetDataTransformer.prepare_for_widget(data, widget)
  end
end
```

### Widget Components

```elixir
# lib/dash_web/components/widgets.ex
defmodule DashWeb.Components.Widgets do
  use Phoenix.Component
  
  def widget(assigns) do
    ~H"""
    <div class="widget" data-widget-id={@widget.id}>
      <div class="widget-header">
        <h3><%= @widget.config["title"] || "Untitled Widget" %></h3>
      </div>
      <div class="widget-body">
        <%= render_widget_content(assigns) %>
      </div>
    </div>
    """
  end

  defp render_widget_content(%{widget: %{type: "line_chart"}} = assigns) do
    ~H"""
    <canvas
      id={"chart-#{@widget.id}"}
      phx-hook="Chart"
      phx-update="ignore"
      data-chart-config={Jason.encode!(@chart_config)}
    >
    </canvas>
    """
  end

  defp render_widget_content(%{widget: %{type: "table"}} = assigns) do
    ~H"""
    <table class="data-table">
      <thead>
        <tr>
          <%= for field <- @widget.config["fields"] do %>
            <th><%= field %></th>
          <% end %>
        </tr>
      </thead>
      <tbody>
        <%= for row <- @data do %>
          <tr>
            <%= for field <- @widget.config["fields"] do %>
              <td><%= get_in(row, ["data", field]) %></td>
            <% end %>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  defp render_widget_content(%{widget: %{type: "stat_card"}} = assigns) do
    ~H"""
    <div class="stat-card">
      <div class="stat-value"><%= @value %></div>
      <div class="stat-label"><%= @widget.config["label"] %></div>
    </div>
    """
  end
end
```

### Chart.js Hook

```javascript
// assets/js/hooks/chart.js
import Chart from 'chart.js/auto';

export const ChartHook = {
  mounted() {
    const ctx = this.el.getContext('2d');
    const config = JSON.parse(this.el.dataset.chartConfig);
    
    this.chart = new Chart(ctx, config);
    
    // Listen for updates from LiveView
    this.handleEvent("update-chart", ({data, labels}) => {
      this.chart.data.labels = labels;
      this.chart.data.datasets[0].data = data;
      this.chart.update('none'); // No animation for smooth updates
    });
  },
  
  updated() {
    const config = JSON.parse(this.el.dataset.chartConfig);
    this.chart.data = config.data;
    this.chart.options = config.options;
    this.chart.update();
  },
  
  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  }
};
```

---

## Data Transformation

### Data Mapper Module

```elixir
# lib/dash/pipelines/data_mapper.ex
defmodule Dash.Pipelines.DataMapper do
  @moduledoc """
  Transforms raw data according to pipeline's data mappings.
  Handles field mappings and transformations.
  """

  def transform(raw_data, nil), do: raw_data
  
  def transform(raw_data, data_mapping) when is_list(raw_data) do
    Enum.map(raw_data, &transform_single(&1, data_mapping))
  end
  
  def transform(raw_data, data_mapping) do
    transform_single(raw_data, data_mapping)
  end

  def transform_single(raw_data, data_mapping) do
    # Apply field mappings first
    mapped = apply_field_mappings(raw_data, data_mapping.mappings)
    
    # Then apply transformations
    apply_transformations(mapped, data_mapping.transformations)
  end

  defp apply_field_mappings(data, mappings) when mappings == %{}, do: data
  
  defp apply_field_mappings(data, mappings) do
    Enum.reduce(mappings, %{}, fn {source_field, target_field}, acc ->
      case get_nested_value(data, source_field) do
        nil -> acc
        value -> put_nested_value(acc, target_field, value)
      end
    end)
  end

  defp apply_transformations(data, transformations) when transformations == %{}, do: data
  
  defp apply_transformations(data, transformations) do
    Enum.reduce(transformations, data, fn {field, transform_config}, acc ->
      case get_nested_value(acc, field) do
        nil -> acc
        value ->
          transformed = apply_single_transformation(value, transform_config)
          put_nested_value(acc, field, transformed)
      end
    end)
  end

  defp apply_single_transformation(value, %{"type" => "multiply", "value" => multiplier}) do
    value * multiplier
  end

  defp apply_single_transformation(value, %{"type" => "uppercase"}) when is_binary(value) do
    String.upcase(value)
  end

  defp apply_single_transformation(value, %{"type" => "lowercase"}) when is_binary(value) do
    String.downcase(value)
  end

  defp apply_single_transformation(value, %{"type" => "round", "precision" => precision}) do
    Float.round(value, precision)
  end

  defp apply_single_transformation(value, %{"type" => "date_format", "format" => format}) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _} -> Calendar.strftime(datetime, format)
      _ -> value
    end
  end

  defp apply_single_transformation(value, _), do: value

  # Helper to get nested values like "user.address.city"
  defp get_nested_value(data, field) do
    field
    |> String.split(".")
    |> Enum.reduce(data, fn key, acc ->
      case acc do
        map when is_map(map) -> Map.get(map, key)
        _ -> nil
      end
    end)
  end

  # Helper to set nested values
  defp put_nested_value(data, field, value) do
    keys = String.split(field, ".")
    do_put_nested(data, keys, value)
  end

  defp do_put_nested(data, [key], value), do: Map.put(data, key, value)
  
  defp do_put_nested(data, [key | rest], value) do
    nested = Map.get(data, key, %{})
    Map.put(data, key, do_put_nested(nested, rest, value))
  end
end
```

---

## Security Architecture

### Authentication & Authorization

All security implementation is detailed in the previous sections. Key points:

1. **Authentication:** AshAuthentication with multiple strategies
2. **Authorization:** Ash policies at resource level
3. **Encryption:** Cloak for sensitive fields (API keys, secrets)
4. **Rate Limiting:** Hammer for API endpoints
5. **CSRF Protection:** Built into Phoenix
6. **Secure Headers:** Custom plug for security headers
7. **Multi-tenancy Isolation:** Team-based data isolation via Ash
8. **Audit Logging:** All sensitive operations logged
9. **Webhook Verification:** HMAC signature validation
10. **Public Dashboard Security:** Token-based access with rate limits

---

## Deployment Strategy

### Phase 1: Fly.io Deployment

```dockerfile
# Dockerfile
FROM hexpm/elixir:1.16.0-erlang-26.2.1-alpine-3.19.0 AS build

WORKDIR /app

RUN apk add --no-cache git build-base npm

RUN mix local.hex --force && \
    mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only prod
RUN mix deps.compile

COPY assets assets
COPY lib lib
COPY priv priv

RUN mix assets.deploy
RUN mix compile
RUN mix release

FROM alpine:3.19.0 AS app

RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app

COPY --from=build /app/_build/prod/rel/dash ./

RUN addgroup -g 1000 dash && \
    adduser -D -u 1000 -G dash dash && \
    chown -R dash:dash /app

USER dash

ENV HOME=/app
ENV MIX_ENV=prod

EXPOSE 4000

CMD ["/app/bin/dash", "start"]
```

```toml
# fly.toml
app = "dash"
primary_region = "iad"

[build]

[env]
  PHX_HOST = "dash.fly.dev"
  PORT = "4000"

[[services]]
  internal_port = 4000
  protocol = "tcp"

  [[services.ports]]
    port = 80
    handlers = ["http"]
    force_https = true

  [[services.ports]]
    port = 443
    handlers = ["tls", "http"]

  [services.concurrency]
    type = "connections"
    hard_limit = 1000
    soft_limit = 800

[[vm]]
  cpu_kind = "shared"
  cpus = 2
  memory_mb = 2048
```

### Deployment Commands

```bash
# Initial setup
fly launch
fly postgres create
fly postgres attach

# Set secrets
fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
fly secrets set ENCRYPTION_KEY=$(openssl rand -base64 32)

# Deploy
fly deploy

# Scale
fly scale count 3
fly scale vm shared-cpu-2x

# Monitor
fly logs
fly status
```

### Phase 2: Multi-Region (If Needed)

```bash
# Add regions
fly regions add ord lax
fly scale count 6  # 2 per region
```

---

## Scaling Strategy

### Capacity Planning Table

| Users | Data/Day | Writes/Sec | Storage/Month | Cost/Month | Architecture |
|-------|----------|------------|---------------|------------|--------------|
| 100 | 100 GB | 1.2K | 3 TB | $500 | Single instance |
| 1,000 | 1 TB | 12K | 30 TB | $2K | Larger instance + replicas |
| 10,000 | 10 TB | 120K | 300 TB | $20K | Multi-node DB + BEAM cluster |
| 50,000 | 50 TB | 600K | 1.5 PB | $100K | ClickHouse + S3 tiering |
| 100,000 | 100 TB | 1.2M | 3 PB | $300K+ | Data lake architecture |

### Scaling Triggers

**Scale Database When:**
- CPU consistently >80%
- Query latency >100ms for simple queries
- Connection pool frequently exhausted
- Storage >70% of instance capacity

**Scale Application When:**
- All instances >70% CPU
- Response time >500ms
- Pipeline workers timing out
- Memory pressure on cache

**Add Read Replicas When:**
- Dashboard queries slowing during writes
- >100 concurrent dashboard viewers
- Read query latency increasing

### Monitoring Alerts

```elixir
# lib/dash/monitoring/alerts.ex
defmodule Dash.Monitoring.Alerts do
  # Database alerts
  def check_database_health do
    cpu = get_db_cpu()
    storage = get_db_storage_percent()
    connections = get_db_connections()
    
    cond do
      cpu > 80 -> alert(:critical, "Database CPU >80%: #{cpu}%")
      storage > 70 -> alert(:warning, "Database storage >70%: #{storage}%")
      connections > 90 -> alert(:critical, "Connection pool >90%: #{connections}%")
      true -> :ok
    end
  end

  # Application alerts
  def check_app_health do
    memory = :erlang.memory(:total) / 1_000_000_000  # GB
    process_count = :erlang.system_info(:process_count)
    
    cond do
      memory > 3.5 -> alert(:warning, "High memory usage: #{memory}GB")
      process_count > 250_000 -> alert(:warning, "High process count: #{process_count}")
      true -> :ok
    end
  end

  # Pipeline alerts
  def check_pipeline_health(pipeline_id) do
    worker_status = get_worker_status(pipeline_id)
    last_success = get_last_successful_run(pipeline_id)
    error_rate = get_error_rate(pipeline_id)
    
    cond do
      worker_status == :down -> alert(:critical, "Pipeline #{pipeline_id} worker down")
      DateTime.diff(DateTime.utc_now(), last_success, :minute) > 30 ->
        alert(:warning, "Pipeline #{pipeline_id} no success in 30min")
      error_rate > 0.1 -> alert(:warning, "Pipeline #{pipeline_id} error rate >10%")
      true -> :ok
    end
  end
end
```

---

## Monitoring & Observability

### Metrics Collection

```elixir
# lib/dash/monitoring/telemetry.ex
defmodule Dash.Monitoring.Telemetry do
  use Supervisor

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    children = [
      # Prometheus metrics
      {TelemetryMetricsPrometheus, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp metrics do
    [
      # Phoenix metrics
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond},
        tags: [:route]
      ),
      
      # LiveView metrics
      summary("phoenix.live_view.mount.stop.duration",
        unit: {:native, :millisecond},
        tags: [:view]
      ),
      
      # Database metrics
      summary("dash.repo.query.total_time",
        unit: {:native, :millisecond},
        tags: [:source]
      ),
      counter("dash.repo.query.count"),
      
      # Pipeline metrics
      counter("dash.pipeline.execution.count",
        tags: [:pipeline_id, :status]
      ),
      summary("dash.pipeline.execution.duration",
        unit: {:native, :millisecond},
        tags: [:pipeline_id]
      ),
      counter("dash.pipeline.data.inserted",
        tags: [:pipeline_id]
      ),
      
      # Cache metrics
      counter("dash.cache.hits"),
      counter("dash.cache.misses"),
      
      # VM metrics
      last_value("vm.memory.total", unit: :byte),
      last_value("vm.total_run_queue_lengths.total"),
      last_value("vm.total_run_queue_lengths.cpu"),
      last_value("vm.system_counts.process_count")
    ]
  end
end
```

### Dashboard Monitoring (Grafana)

**Key Dashboards:**

1. **System Overview**
   - Request rate
   - Error rate
   - Response time (p50, p95, p99)
   - Active users

2. **Database Health**
   - Query latency
   - Connection pool usage
   - Write throughput
   - Storage usage

3. **Pipeline Health**
   - Active pipelines
   - Success/failure rate
   - Data ingestion rate
   - Pipeline latency

4. **BEAM Metrics**
   - Process count
   - Memory usage
   - Scheduler utilization
   - Message queue lengths

### Logging Strategy

```elixir
# config/prod.exs
config :logger,
  level: :info,
  backends: [:console, {LoggerFileBackend, :file_log}]

config :logger, :file_log,
  path: "/var/log/dash/dash.log",
  level: :info,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :user_id, :team_id]

# Structured logging
Logger.info("Pipeline executed",
  pipeline_id: pipeline.id,
  team_id: pipeline.team_id,
  duration_ms: duration,
  records_processed: count,
  status: :success
)
```

### Error Tracking (Sentry)

```elixir
# config/prod.exs
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: :prod,
  enable_source_code_context: true,
  root_source_code_path: File.cwd!(),
  tags: %{
    env: "production"
  }
```

---

## Development Roadmap

### Phase 1: MVP (Weeks 1-8)

**Week 1-2: Foundation**
- [x] Initialize Phoenix project
- [x] Set up Ash Framework
- [x] Configure PostgreSQL + TimescaleDB
- [x] Implement authentication (username/password, magic link)
- [x] Create Team/User schemas and contexts
- [x] Build basic UI shell with LiveView

**Week 3-4: Core Pipeline**
- [x] Pipeline CRUD operations
- [x] HTTP polling source adapter
- [x] Oban job scheduling
- [x] TimescaleDB data insertion
- [x] Basic data mapping (field remapping only)
- [x] Pipeline worker GenServer

**Week 5-6: Dashboard MVP**
- [x] Dashboard CRUD
- [x] Widget system (table widget only initially)
- [x] LiveView real-time updates
- [x] Chart.js integration (line chart)
- [x] Simple grid layout
- [x] ETS cache implementation

**Week 7-8: Polish & Deploy**
- [x] Add 2-3 more widget types (stat card, bar chart)
- [x] Public dashboard sharing
- [x] Error handling and user feedback
- [x] Deploy to Fly.io
- [x] Basic monitoring setup
- [x] Documentation

**MVP Deliverables:**
- Working application with 1 team, multiple users
- HTTP polling pipelines
- Real-time dashboards with 3-4 widget types
- Public sharing capability
- Deployed to production
- **All users on Free tier** (no billing yet)

---

### Phase 2: Growth Features (Weeks 9-16)

**Week 9-10: Webhook & Real-time**
- [ ] Webhook receiver endpoints
- [ ] Real-time pipeline type
- [ ] Webhook signature verification
- [ ] Rate limiting for webhooks

**Week 11-12: Advanced Transformations**
- [ ] Complex data transformations
- [ ] Calculated fields
- [ ] Data filtering
- [ ] Transformation testing UI

**Week 13-14: Data Sinks**
- [ ] HTTP sink adapter
- [ ] Webhook sink
- [ ] Email notifications
- [ ] Slack integration

**Week 15-16: Enhanced Dashboards**
- [ ] More widget types (gauges, maps, etc.)
- [ ] Dashboard templates
- [ ] Widget resize/drag-drop
- [ ] Dashboard export (PDF, PNG)

---

### Phase 3: Monetization & Scale (Weeks 17-24)

**Week 17-18: Usage Tracking & Limits**
- [ ] Implement usage tracking system
- [ ] Pipeline count enforcement
- [ ] Storage usage calculation
- [ ] Data points counting
- [ ] Retention policy enforcement
- [ ] Upgrade prompts in UI
- [ ] Usage dashboard for users

**Week 19-20: Stripe Integration** ⭐ **BILLING LAUNCH**
- [ ] Stripe account setup
- [ ] Subscription model implementation
- [ ] Stripe webhook handling
- [ ] Billing UI (LiveView)
- [ ] Payment method management
- [ ] Invoice generation
- [ ] Usage-based billing for overages
- [ ] Trial period implementation (14 days)
- [ ] Upgrade/downgrade flows
- [ ] Cancellation handling

**Week 21-22: Performance & File Support**
- [ ] Add read replicas
- [ ] Optimize hot queries
- [ ] Implement continuous aggregates
- [ ] Load testing and optimization
- [ ] File upload in webhooks
- [ ] Cloudflare R2 integration
- [ ] File widget for dashboards

**Week 23-24: Advanced Features**
- [ ] Pipeline-to-pipeline connections
- [ ] Retention policy management UI
- [ ] Storage purchase flow
- [ ] Team billing management
- [ ] GraphQL API (via Ash)
- [ ] API documentation

**Phase 3 Deliverables:**
- Live payment processing
- All pricing tiers active
- Usage enforcement
- Scalable infrastructure
- Enterprise-ready features

---

### Phase 4: Enterprise & Marketplace (Future)

**Months 7-9:**
- [ ] Enterprise features (SSO, audit logs)
- [ ] SOC 2 Type II preparation
- [ ] HIPAA BAA capability
- [ ] White-label options
- [ ] Advanced analytics

**Months 10-12:**
- [ ] Pipeline marketplace
- [ ] Pre-built templates
- [ ] OAuth integrations (Google Sheets, Salesforce)
- [ ] Mobile app (React Native)
- [ ] ML/AI insights

---

## Usage Limits & Tier-Based Enforcement

### Limit Enforcement Architecture

```elixir
# lib/dash/billing/limit_enforcer.ex
defmodule Dash.Billing.LimitEnforcer do
  @moduledoc """
  Enforces tier-based limits on usage.
  Prevents users from exceeding their plan limits.
  """

  alias Dash.Billing.Subscription

  # Define limits per tier
  @tier_limits %{
    free: %{
      pipelines: 3,
      teams: 1,
      members_per_team: 5,
      dashboards: 3,
      storage_gb: 1,
      retention_days: 7,
      data_points_per_month: 10_000,
      widgets_per_dashboard: 5,
      public_dashboards: 0
    },
    pro: %{
      pipelines: 25,
      teams: 2,
      members_per_team: 10,
      dashboards: 15,
      storage_gb: 25,
      retention_days: 30,
      data_points_per_month: 1_000_000,
      widgets_per_dashboard: 20,
      public_dashboards: 5
    },
    business: %{
      pipelines: 100,
      teams: 10,
      members_per_team: 50,
      dashboards: :unlimited,
      storage_gb: 100,
      retention_days: 90,
      data_points_per_month: 10_000_000,
      widgets_per_dashboard: :unlimited,
      public_dashboards: :unlimited
    },
    enterprise: %{
      pipelines: :unlimited,
      teams: :unlimited,
      members_per_team: :unlimited,
      dashboards: :unlimited,
      storage_gb: :custom,  # Negotiated
      retention_days: :custom,
      data_points_per_month: :unlimited,
      widgets_per_dashboard: :unlimited,
      public_dashboards: :unlimited
    }
  }

  # Check if action is allowed
  def can_create_pipeline?(team) do
    subscription = Subscription.get_by_team(team.id)
    current_count = count_pipelines(team.id)
    limit = get_limit(subscription.tier, :pipelines)

    case limit do
      :unlimited -> {:ok, :allowed}
      n when current_count < n -> {:ok, :allowed}
      n -> {:error, :limit_reached, 
        "Pipeline limit reached (#{n}). Upgrade to create more."}
    end
  end

  def can_create_dashboard?(team) do
    subscription = Subscription.get_by_team(team.id)
    current_count = count_dashboards(team.id)
    limit = get_limit(subscription.tier, :dashboards)

    case limit do
      :unlimited -> {:ok, :allowed}
      n when current_count < n -> {:ok, :allowed}
      n -> {:error, :limit_reached,
        "Dashboard limit reached (#{n}). Upgrade to Pro for unlimited."}
    end
  end

  def can_add_team_member?(team) do
    subscription = Subscription.get_by_team(team.id)
    current_count = count_team_members(team.id)
    limit = get_limit(subscription.tier, :members_per_team)

    case limit do
      :unlimited -> {:ok, :allowed}
      n when current_count < n -> {:ok, :allowed}
      n -> {:error, :limit_reached,
        "Team member limit reached (#{n}). Upgrade to add more members."}
    end
  end

  def can_ingest_data?(team, data_points) do
    subscription = Subscription.get_by_team(team.id)
    current_usage = subscription.data_points_current_month
    limit = get_limit(subscription.tier, :data_points_per_month)

    case limit do
      :unlimited -> 
        {:ok, :allowed}
      
      n when current_usage + data_points <= n -> 
        {:ok, :allowed}
      
      n ->
        # Calculate overage
        overage = (current_usage + data_points) - n
        
        case subscription.tier do
          :free ->
            # Hard limit - reject data
            {:error, :hard_limit,
              "Monthly data limit reached (#{format_number(n)}). Upgrade to continue."}
          
          tier when tier in [:pro, :business] ->
            # Soft limit - allow but charge overage
            overage_cost = calculate_overage_cost(overage)
            {:ok, :overage_allowed, 
              %{overage_points: overage, cost: overage_cost}}
          
          :enterprise ->
            # No limit, but track
            {:ok, :allowed}
        end
    end
  end

  def can_use_storage?(team, additional_gb) do
    subscription = Subscription.get_by_team(team.id)
    current_storage = subscription.storage_used_gb
    limit = get_limit(subscription.tier, :storage_gb)

    projected_storage = current_storage + additional_gb

    case limit do
      :custom -> {:ok, :allowed}  # Enterprise custom limits
      :unlimited -> {:ok, :allowed}
      
      n when projected_storage <= n -> 
        {:ok, :allowed}
      
      n ->
        overage_gb = projected_storage - n
        
        case subscription.tier do
          :free ->
            {:error, :hard_limit,
              "Storage limit reached (#{n} GB). Upgrade for more storage."}
          
          tier when tier in [:pro, :business, :enterprise] ->
            # Allow with additional charge
            overage_cost = overage_gb * 1.00  # $1/GB
            {:ok, :overage_allowed,
              %{overage_gb: overage_gb, monthly_cost: overage_cost}}
        end
    end
  end

  def check_retention_period(team, requested_days) do
    subscription = Subscription.get_by_team(team.id)
    limit = get_limit(subscription.tier, :retention_days)

    case limit do
      :custom -> {:ok, :allowed}
      :unlimited -> {:ok, :allowed}
      n when requested_days <= n -> {:ok, :allowed}
      n -> {:error, :limit_exceeded,
        "Retention period limited to #{n} days on your plan. Upgrade for longer retention."}
    end
  end

  # Helper functions
  defp get_limit(tier, resource) do
    @tier_limits[tier][resource]
  end

  defp calculate_overage_cost(data_points) do
    # $5 per million data points over limit
    millions = data_points / 1_000_000
    Float.round(millions * 5.00, 2)
  end

  defp count_pipelines(team_id) do
    Dash.Pipelines.count_by_team(team_id)
  end

  defp count_dashboards(team_id) do
    Dash.Dashboards.count_by_team(team_id)
  end

  defp count_team_members(team_id) do
    Dash.Accounts.count_members(team_id)
  end

  defp format_number(n) when n >= 1_000_000 do
    "#{div(n, 1_000_000)}M"
  end
  defp format_number(n) when n >= 1_000 do
    "#{div(n, 1_000)}K"
  end
  defp format_number(n), do: to_string(n)
end
```

### Storage Purchase Flow

```elixir
# lib/dash/billing/storage_addon.ex
defmodule Dash.Billing.StorageAddon do
  @moduledoc """
  Handles storage add-on purchases
  """

  # Storage add-on pricing
  @storage_price_per_gb 1.00  # $1/GB per month

  def purchase_storage(team, additional_gb) do
    subscription = Dash.Billing.Subscription.get_by_team(team.id)
    
    # Calculate cost
    monthly_cost = additional_gb * @storage_price_per_gb
    
    # Create Stripe price for this add-on
    {:ok, price} = create_storage_addon_price(additional_gb, monthly_cost)
    
    # Add to subscription
    {:ok, subscription_item} = Stripe.SubscriptionItem.create(%{
      subscription: subscription.stripe_subscription_id,
      price: price.id,
      quantity: 1
    })
    
    # Update local subscription
    Dash.Billing.Subscription.update(subscription, %{
      storage_limit_gb: subscription.storage_limit_gb + additional_gb,
      storage_addons: [
        %{
          gb: additional_gb,
          monthly_cost: monthly_cost,
          stripe_subscription_item_id: subscription_item.id
        } | subscription.storage_addons || []
      ]
    })
  end

  def remove_storage_addon(subscription, addon) do
    # Remove from Stripe
    Stripe.SubscriptionItem.delete(addon.stripe_subscription_item_id)
    
    # Update local subscription
    new_addons = Enum.reject(subscription.storage_addons, &(&1.id == addon.id))
    total_addon_storage = Enum.sum(Enum.map(new_addons, & &1.gb))
    
    base_limit = Dash.Billing.LimitEnforcer.get_base_limit(subscription.tier, :storage_gb)
    
    Dash.Billing.Subscription.update(subscription, %{
      storage_limit_gb: base_limit + total_addon_storage,
      storage_addons: new_addons
    })
  end

  defp create_storage_addon_price(gb, monthly_cost) do
    Stripe.Price.create(%{
      currency: "usd",
      unit_amount: trunc(monthly_cost * 100),  # Convert to cents
      recurring: %{interval: "month"},
      product_data: %{
        name: "Additional Storage - #{gb} GB"
      }
    })
  end
end
```

### Data Points Tracking

```elixir
# lib/dash/data/pipeline_data.ex - Enhanced with tracking
defmodule Dash.Data.PipelineData do
  import Ecto.Query
  alias Dash.Repo

  def insert_batch(pipeline_id, team_id, data_list) when is_list(data_list) do
    # Check if ingestion is allowed
    data_point_count = length(data_list)
    
    case Dash.Billing.LimitEnforcer.can_ingest_data?(
      %{id: team_id}, 
      data_point_count
    ) do
      {:ok, :allowed} ->
        # Proceed with normal insert
        do_insert_batch(pipeline_id, team_id, data_list)
        
        # Track usage
        Dash.Billing.UsageTracker.track_data_points(team_id, data_point_count)
        
        {:ok, data_point_count}
      
      {:ok, :overage_allowed, %{overage_points: overage, cost: cost}} ->
        # Insert data and notify about overage
        do_insert_batch(pipeline_id, team_id, data_list)
        
        # Track usage
        Dash.Billing.UsageTracker.track_data_points(team_id, data_point_count)
        
        # Notify team about overage charges
        notify_overage(team_id, overage, cost)
        
        {:ok, :overage, %{inserted: data_point_count, overage_cost: cost}}
      
      {:error, :hard_limit, message} ->
        # Reject data ingestion
        notify_limit_reached(team_id, :data_points, message)
        
        {:error, :limit_reached, message}
    end
  end

  defp do_insert_batch(pipeline_id, team_id, data_list) do
    now = DateTime.utc_now()
    
    entries = Enum.map(data_list, fn data ->
      %{
        pipeline_id: pipeline_id,
        team_id: team_id,
        data: data,
        ingested_at: now
      }
    end)
    
    # Insert in chunks
    entries
    |> Enum.chunk_every(1000)
    |> Enum.each(fn chunk ->
      Repo.insert_all("pipeline_data", chunk)
    end)
    
    # Update storage usage
    update_storage_usage(team_id, entries)
  end

  defp update_storage_usage(team_id, entries) do
    # Calculate approximate size
    total_bytes = Enum.reduce(entries, 0, fn entry, acc ->
      acc + byte_size(:erlang.term_to_binary(entry.data))
    end)
    
    gb_used = total_bytes / 1_073_741_824  # Convert to GB
    
    # Check storage limit
    case Dash.Billing.LimitEnforcer.can_use_storage?(%{id: team_id}, gb_used) do
      {:ok, :allowed} ->
        Dash.Billing.Subscription.increment_storage(team_id, gb_used)
      
      {:ok, :overage_allowed, %{overage_gb: overage, monthly_cost: cost}} ->
        Dash.Billing.Subscription.increment_storage(team_id, gb_used)
        notify_storage_overage(team_id, overage, cost)
      
      {:error, :hard_limit, _message} ->
        # This shouldn't happen if data points check passed
        # But handle gracefully
        :ok
    end
  end

  defp notify_overage(team_id, overage_points, cost) do
    # Send email/notification about overage charges
    Dash.Notifications.send_overage_notice(team_id, %{
      type: :data_points,
      overage: overage_points,
      estimated_cost: cost
    })
  end

  defp notify_limit_reached(team_id, limit_type, message) do
    Dash.Notifications.send_limit_notice(team_id, %{
      type: limit_type,
      message: message,
      upgrade_url: DashWeb.Endpoint.url() <> "/billing/upgrade"
    })
  end
end
```

### Usage Dashboard UI

```elixir
# lib/dash_web/live/usage_live.ex
defmodule DashWeb.UsageLive do
  use DashWeb, :live_view

  def mount(_params, session, socket) do
    team = get_current_team(session)
    subscription = Dash.Billing.Subscription.get_by_team(team.id)
    usage = calculate_current_usage(team, subscription)
    
    socket =
      socket
      |> assign(:team, team)
      |> assign(:subscription, subscription)
      |> assign(:usage, usage)
      |> assign(:limits, get_limits(subscription.tier))
    
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="usage-dashboard">
      <div class="usage-header">
        <h1>Usage & Limits</h1>
        <p class="tier-badge">Current Plan: <%= format_tier(@subscription.tier) %></p>
      </div>

      <!-- Usage Meters -->
      <div class="usage-grid">
        <!-- Pipelines -->
        <.usage_meter
          label="Pipelines"
          current={@usage.pipelines}
          limit={@limits.pipelines}
          unit="pipelines"
          upgrade_prompt={@usage.pipelines >= @limits.pipelines * 0.8}
        />

        <!-- Storage -->
        <.usage_meter
          label="Storage"
          current={@usage.storage_gb}
          limit={@limits.storage_gb}
          unit="GB"
          upgrade_prompt={@usage.storage_gb >= @limits.storage_gb * 0.8}
          can_purchase_more={@subscription.tier != :free}
        />

        <!-- Data Points This Month -->
        <.usage_meter
          label="Data Points (This Month)"
          current={@usage.data_points_this_month}
          limit={@limits.data_points_per_month}
          unit="points"
          upgrade_prompt={@usage.data_points_this_month >= @limits.data_points_per_month * 0.8}
          overage={calculate_overage(@usage.data_points_this_month, @limits.data_points_per_month)}
        />

        <!-- Team Members -->
        <.usage_meter
          label="Team Members"
          current={@usage.team_members}
          limit={@limits.members_per_team}
          unit="members"
          upgrade_prompt={@usage.team_members >= @limits.members_per_team * 0.8}
        />

        <!-- Dashboards -->
        <.usage_meter
          label="Dashboards"
          current={@usage.dashboards}
          limit={@limits.dashboards}
          unit="dashboards"
          upgrade_prompt={is_number(@limits.dashboards) && @usage.dashboards >= @limits.dashboards * 0.8}
        />
      </div>

      <!-- Overage Charges (if any) -->
      <%= if has_overages?(@usage, @limits) do %>
        <div class="overage-notice">
          <h3>⚠️ Overage Charges This Month</h3>
          <p>You've exceeded your plan limits. These overages will be charged at the end of your billing cycle.</p>
          
          <table class="overage-table">
            <thead>
              <tr>
                <th>Resource</th>
                <th>Overage</th>
                <th>Rate</th>
                <th>Estimated Charge</th>
              </tr>
            </thead>
            <tbody>
              <%= if @usage.data_points_this_month > @limits.data_points_per_month do %>
                <tr>
                  <td>Data Points</td>
                  <td><%= format_number(@usage.data_points_this_month - @limits.data_points_per_month) %></td>
                  <td>$5 / 1M points</td>
                  <td>${<%= calculate_data_point_overage_cost(@usage.data_points_this_month, @limits.data_points_per_month) %></td>
                </tr>
              <% end %>
              
              <%= if @usage.storage_gb > @limits.storage_gb do %>
                <tr>
                  <td>Storage</td>
                  <td><%= Float.round(@usage.storage_gb - @limits.storage_gb, 2) %> GB</td>
                  <td>$1 / GB / month</td>
                  <td>${<%= Float.round((@usage.storage_gb - @limits.storage_gb) * 1.00, 2) %></td>
                </tr>
              <% end %>
            </tbody>
            <tfoot>
              <tr>
                <td colspan="3"><strong>Total Estimated Overage</strong></td>
                <td><strong>${<%= calculate_total_overage(@usage, @limits) %></strong></td>
              </tr>
            </tfoot>
          </table>
        </div>
      <% end %>

      <!-- Purchase Additional Resources -->
      <%= if @subscription.tier in [:pro, :business, :enterprise] do %>
        <div class="addon-purchases">
          <h3>Purchase Additional Resources</h3>
          
          <div class="addon-card">
            <h4>Additional Storage</h4>
            <p>Need more storage? Purchase in 10 GB increments.</p>
            <div class="addon-pricing">
              <span class="price">$10/month</span>
              <span class="unit">per 10 GB</span>
            </div>
            <button phx-click="purchase_storage" class="btn-primary">
              Add 10 GB Storage
            </button>
          </div>

          <!-- Show current add-ons -->
          <%= if length(@subscription.storage_addons || []) > 0 do %>
            <div class="current-addons">
              <h4>Current Add-ons</h4>
              <%= for addon <- @subscription.storage_addons do %>
                <div class="addon-item">
                  <span><%= addon.gb %> GB Storage - $<%= addon.monthly_cost %>/month</span>
                  <button phx-click="remove_addon" phx-value-addon-id={addon.id} class="btn-danger-sm">
                    Remove
                  </button>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Upgrade Prompt -->
      <%= if should_show_upgrade_prompt?(@usage, @limits) do %>
        <div class="upgrade-prompt">
          <h3>🚀 Running Low on Resources?</h3>
          <p>Upgrade your plan to get more pipelines, storage, and data points.</p>
          <.link navigate={~p"/billing/upgrade"} class="btn-primary btn-lg">
            View Upgrade Options
          </.link>
        </div>
      <% end %>
    </div>
    """
  end

  # Component for usage meter
  def usage_meter(assigns) do
    percent = if assigns.limit == :unlimited do
      0
    else
      min(100, (assigns.current / assigns.limit * 100) |> Float.round(1))
    end

    assigns = assign(assigns, :percent, percent)

    ~H"""
    <div class="usage-meter-card">
      <div class="meter-header">
        <h4><%= @label %></h4>
        <span class="meter-value">
          <%= format_value(@current) %> / 
          <%= if @limit == :unlimited, do: "∞", else: format_value(@limit) %>
          <%= @unit %>
        </span>
      </div>

      <div class="meter-bar-container">
        <div class="meter-bar">
          <div 
            class={"meter-fill #{meter_color(@percent)}"}
            style={"width: #{@percent}%"}
          >
          </div>
        </div>
        <span class="meter-percent"><%= @percent %>%</span>
      </div>

      <%= if Map.get(assigns, :overage, 0) > 0 do %>
        <div class="overage-badge">
          Overage: <%= format_value(@overage) %> <%= @unit %>
        </div>
      <% end %>

      <%= if Map.get(assigns, :upgrade_prompt, false) do %>
        <div class="upgrade-hint">
          ⚠️ Approaching limit. 
          <.link navigate={~p"/billing/upgrade"}>Upgrade</.link>
        </div>
      <% end %>

      <%= if Map.get(assigns, :can_purchase_more, false) do %>
        <button phx-click="purchase_more" phx-value-resource={@label} class="btn-secondary btn-sm">
          Purchase More
        </button>
      <% end %>
    </div>
    """
  end

  def handle_event("purchase_storage", _params, socket) do
    # Purchase 10 GB of additional storage
    case Dash.Billing.StorageAddon.purchase_storage(socket.assigns.team, 10) do
      {:ok, _subscription} ->
        socket = 
          socket
          |> put_flash(:info, "Successfully added 10 GB storage ($10/month)")
          |> reload_subscription()
        
        {:noreply, socket}
      
      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to purchase storage: #{reason}")
        {:noreply, socket}
    end
  end

  defp meter_color(percent) when percent >= 90, do: "danger"
  defp meter_color(percent) when percent >= 75, do: "warning"
  defp meter_color(_), do: "success"

  defp calculate_overage(current, limit) when is_number(limit) and current > limit do
    current - limit
  end
  defp calculate_overage(_, _), do: 0

  defp has_overages?(usage, limits) do
    usage.data_points_this_month > limits.data_points_per_month ||
    usage.storage_gb > limits.storage_gb
  end

  defp should_show_upgrade_prompt?(usage, limits) do
    # Show if user is at 80%+ on any resource
    (usage.pipelines / limits.pipelines) >= 0.8 ||
    (usage.storage_gb / limits.storage_gb) >= 0.8 ||
    (usage.data_points_this_month / limits.data_points_per_month) >= 0.8
  end
end
```

---

## Target Customer Segments & Marketing Strategy

### Primary Target Segments (Launch Focus)

#### 1. **Digital Marketing Agencies** ⭐ Best Initial Target

**Profile:**
- 5-50 employees
- Managing 10-50 clients
- Annual revenue: $500K - $5M
- Currently using: Multiple tools (Google Analytics, Ads platforms, manual reporting)

**Pain Points:**
- Spending 15-20 hours/week on client reporting
- Manually pulling data from 5-10 platforms per client
- Clients constantly asking "how are my ads performing?"
- Difficult to show ROI and justify retainer fees

**Why Dash Wins:**
- Multi-tenancy perfect for agency/client model
- Automated reports save 80% of reporting time
- Public dashboards impress clients
- Real-time data shows value immediately
- Professional appearance justifies premium pricing

**Pricing Sweet Spot:** $199-599/month (Business tier)
**LTV:** $7,000 - $20,000 (3-year retention)

**Marketing Channels:**
- LinkedIn ads targeting "marketing agency owner"
- Content: "How to create client dashboards in 10 minutes"
- Partner with agency management tools (AgencyAnalytics competitors)
- Agency Facebook groups / communities

**Sales Message:**
*"Stop spending 20 hours a week on client reports. Dash automatically pulls data from Google Ads, Facebook, Analytics, and your CRM into beautiful real-time dashboards your clients will love. Save time, reduce churn, and win more business."*

**Success Metric:** 50 agency customers in Year 1 = $120K ARR

---

#### 2. **E-commerce Store Owners** ⭐ High Volume Potential

**Profile:**
- Online retailers doing $500K - $10M annual revenue
- Selling on multiple platforms (Shopify, Amazon, eBay, own site)
- 1-10 employees
- Currently: Manually checking each platform daily, Excel spreadsheets

**Pain Points:**
- No unified view across sales channels
- Don't know real-time inventory levels
- Miss stockouts until customer complaints
- Can't identify best-selling products quickly
- Accountant needs data in specific format

**Why Dash Wins:**
- See all sales channels in one dashboard
- Real-time inventory alerts prevent stockouts
- Automatic daily reports to accountant
- Public dashboard to share with investors/partners
- Mobile-friendly (check sales anywhere)

**Pricing Sweet Spot:** $49-199/month (Pro to Business tier)
**LTV:** $2,000 - $7,000

**Marketing Channels:**
- Shopify app store listing
- Amazon seller forums / Facebook groups
- YouTube tutorials: "Multi-channel e-commerce dashboard"
- Google ads: "shopify analytics dashboard"
- Partner with e-commerce coaches/consultants

**Sales Message:**
*"Monitor your Shopify, Amazon, and Stripe sales in one real-time dashboard. Get instant alerts when products are low in stock. Automate daily reports to your team. All for $49/month."*

**Success Metric:** 500 e-commerce customers in Year 1 = $350K ARR

---

#### 3. **SaaS Founders / Product Teams** ⭐ Word-of-Mouth Growth

**Profile:**
- Early to growth stage SaaS companies
- 500 - 50,000 users
- Currently using: Mixpanel, Amplitude, ChartMogul, custom dashboards
- Pain: Too many tools, expensive, manual board reporting

**Pain Points:**
- Paying $500-2,000/month for analytics tools
- Data scattered across 5+ platforms
- Creating board presentations manually
- Can't correlate product usage with revenue
- Marketing team needs different view than product team

**Why Dash Wins:**
- Consolidate 3-5 tools into one ($500/mo savings)
- Custom dashboards for different stakeholders
- Real-time metrics vs. daily updates
- Public board dashboard for investors
- API-first design (they're technical)

**Pricing Sweet Spot:** $199-999/month (Business to Enterprise)
**LTV:** $10,000 - $50,000

**Marketing Channels:**
- Product Hunt launch
- Dev.to / Hacker News (technical content)
- Indie Hackers community
- Twitter/X (#buildinpublic community)
- SaaS podcasts / newsletters

**Sales Message:**
*"Replace Mixpanel + ChartMogul + your custom dashboards with one platform. Track signups, MRR, churn, and product usage in real-time. Share beautiful dashboards with your board. Save $6,000/year."*

**Success Metric:** 100 SaaS customers in Year 1 = $300K ARR

---

### Secondary Target Segments (Year 2+)

#### 4. **IoT / Hardware Companies**

**Profile:**
- Smart home, industrial IoT, wearables
- 1,000 - 100,000 devices deployed
- Need: Device monitoring, fleet management

**Pricing:** $499 - $4,999/month (Enterprise)
**Volume:** 20 customers = $240K - $1.2M ARR

#### 5. **Healthcare Providers (Remote Patient Monitoring)**

**Profile:**
- Chronic disease management programs
- 100 - 10,000 patients
- Regulated industry (HIPAA required)

**Pricing:** $1,999 - $9,999/month (Enterprise + BAA)
**Volume:** 10 customers = $240K - $1.2M ARR

#### 6. **Restaurant / Retail Chains**

**Profile:**
- 10 - 100 locations
- Need operational visibility
- Currently: Manual reporting from each location

**Pricing:** $799 - $2,999/month (Business to Enterprise)
**Volume:** 30 customers = $287K - $1.08M ARR

---

### Marketing Strategy by Phase

#### Phase 1: Launch (Months 1-6) - Focus on Agencies

**Goal:** 20 paying customers, validate product-market fit

**Tactics:**
1. **Content Marketing**
   - Blog: "How to Build Client Dashboards" (SEO)
   - YouTube: Dashboard tutorials
   - Case study: First beta customer

2. **Direct Outreach**
   - LinkedIn: 50 DMs/week to agency owners
   - Cold email: Template offering free setup
   - Agency Facebook groups (value-first)

3. **Product**
   - Agency-specific templates
   - "Share with client" feature
   - White-label option (roadmap item)

**Budget:** $2,000/month (mostly time)
**Expected:** 20 customers @ $199/mo = $4K MRR

---

#### Phase 2: Growth (Months 7-12) - Add E-commerce

**Goal:** 100 paying customers, $20K MRR

**Tactics:**
1. **Paid Advertising**
   - Google Ads: "shopify analytics" ($500/mo)
   - Facebook Ads: E-commerce groups ($300/mo)
   - LinkedIn Ads: Agencies ($700/mo)

2. **Partnerships**
   - Shopify app listing
   - Agency tool integrations
   - Affiliate program (20% recurring)

3. **Content**
   - Weekly blog posts (SEO)
   - Monthly webinar
   - Customer success stories

**Budget:** $5,000/month
**Expected:** 100 customers avg $150/mo = $15K MRR

---

#### Phase 3: Scale (Year 2) - Enterprise Sales

**Goal:** $500K ARR, enterprise customers

**Tactics:**
1. **Sales Team**
   - Hire 2 sales reps
   - Focus on $999+/month deals
   - Outbound to IoT, healthcare

2. **Product**
   - SOC 2 Type II certification
   - HIPAA BAA capability
   - Enterprise features (SSO, audit logs)

3. **Marketing**
   - Industry conferences (exhibit)
   - Enterprise case studies
   - PR / press coverage

**Budget:** $25,000/month (including salaries)
**Expected:** $500K ARR

---

### Ideal Customer Profile (ICP) Summary

**Best Fit Customers:**
- **Company Size:** 5-50 employees
- **Revenue:** $500K - $10M annually
- **Tech Savvy:** Comfortable with SaaS tools
- **Pain Level:** Spending 10+ hours/week on manual reporting
- **Budget:** Can afford $100-500/month for time savings
- **Use Case:** Multi-platform data consolidation

**Disqualifying Factors:**
- Solo entrepreneurs (free tier is enough)
- Enterprise Fortune 500 (too complex for MVP)
- Non-technical industries (won't adopt)
- Looking for free solution (low LTV)

---

### Go-to-Market Priority

**Month 1-3:** Agencies only (focused approach)
**Month 4-6:** Add e-commerce (proven playbook)
**Month 7-12:** Add SaaS, expand agency
**Year 2:** Enterprise (IoT, healthcare, retail)

**Why This Order:**
1. **Agencies** = easiest to reach, highest willingness to pay, clear ROI
2. **E-commerce** = large market, self-serve friendly, predictable needs
3. **SaaS** = word-of-mouth growth, long LTV, technical validation
4. **Enterprise** = requires product maturity, compliance, dedicated sales

---

### Competitive Positioning

**vs. Zapier:**
*"Zapier moves data. Dash moves data AND visualizes it in real-time dashboards."*

**vs. Tableau/Looker:**
*"Tableau visualizes data. Dash fetches, transforms, AND visualizes data - no data team required."*

**vs. Custom Build:**
*"Custom dashboard costs $50K to build and $5K/month to maintain. Dash is $199/month, ready today."*

**vs. Segment:**
*"Segment routes data. Dash routes data AND shows it to your team in beautiful dashboards."*

**Unique Value Prop:**
*"The only platform that fetches your data, transforms it, and visualizes it in real-time dashboards - all in one place, with no code required."*

---

### Marketing Budget Allocation (Year 1)

| Channel | Monthly | Annual | Expected CAC | Expected Customers |
|---------|---------|--------|--------------|-------------------|
| **Content/SEO** | $1,000 | $12,000 | $200 | 60 |
| **Paid Ads** | $1,500 | $18,000 | $150 | 120 |
| **Partnerships** | $500 | $6,000 | $100 | 60 |
| **Events/Conferences** | $500 | $6,000 | $300 | 20 |
| **Tools/Software** | $500 | $6,000 | - | - |
| **TOTAL** | $4,000 | $48,000 | $185 avg | 260 |

**Targets:**
- 260 customers acquired
- Average LTV: $3,000
- LTV/CAC: 16:1 (excellent)
- Month 12 MRR: ~$35,000

---

### Sales Funnel

```
Website Visitors: 10,000/month
    ↓ (5% start trial)
Free Trial Signups: 500/month
    ↓ (10% convert)
Paying Customers: 50/month
    ↓ (5% churn monthly)
Retained Customers: 260 by month 12
```

**Key Metrics to Track:**
- Trial-to-paid conversion: 10% (improve to 15%)
- Monthly churn: 5% (reduce to 3%)
- Expansion MRR: 10% (upgrades, add-ons)
- CAC payback: 3 months

---

## Stripe Integration & Billing Implementation

### Integration Timeline (Week 19-20)

**Week 19: Stripe Setup & Backend**

**Day 1-2: Stripe Account & Configuration**
- [ ] Create Stripe account (production + test mode)
- [ ] Set up products in Stripe dashboard:
  - Pro Monthly ($59/mo)
  - Pro Annual ($588/year)
  - Business Monthly ($249/mo)
  - Business Annual ($2,388/year)
- [ ] Create webhook endpoint
- [ ] Configure tax settings (Stripe Tax)
- [ ] Set up customer portal

**Day 3-5: Backend Implementation**
- [ ] Add Stripe SDK to dependencies
- [ ] Create billing domain in Ash
- [ ] Implement subscription resource
- [ ] Build Stripe service module
- [ ] Add webhook handling
- [ ] Create usage tracking system

**Week 20: Frontend & Testing**

**Day 1-3: Billing UI**
- [ ] Create billing LiveView pages
- [ ] Build upgrade/downgrade flows
- [ ] Implement usage dashboard
- [ ] Add storage purchase flow
- [ ] Create payment method management

**Day 4-5: Testing & Launch**
- [ ] Test full subscription lifecycle
- [ ] Test webhook handling
- [ ] Test usage limits enforcement
- [ ] Load test with dummy data
- [ ] Deploy to production
- [ ] Migrate existing users to trials

---

### Stripe Schema Implementation

```elixir
# priv/repo/migrations/20260115_create_billing_tables.exs
defmodule Dash.Repo.Migrations.CreateBillingTables do
  use Ecto.Migration

  def change do
    # Subscriptions table
    create table(:subscriptions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :team_id, references(:teams, type: :uuid, on_delete: :delete_all), null: false
      
      # Stripe references
      add :stripe_customer_id, :string
      add :stripe_subscription_id, :string
      add :stripe_subscription_item_id, :string  # For metered billing
      
      # Subscription details
      add :tier, :string, null: false, default: "free"  # free, pro, business, enterprise
      add :status, :string, null: false, default: "active"  # active, past_due, canceled, trialing
      add :billing_interval, :string  # monthly, annual
      
      # Trial
      add :trial_ends_at, :utc_datetime
      add :trial_extended, :boolean, default: false
      
      # Billing periods
      add :current_period_start, :utc_datetime
      add :current_period_end, :utc_datetime
      
      # Usage tracking (resets monthly)
      add :pipelines_count, :integer, default: 0
      add :data_points_current_month, :bigint, default: 0
      add :storage_used_gb, :decimal, precision: 10, scale: 2, default: 0.0
      
      # Limits (based on tier)
      add :pipelines_limit, :integer
      add :data_points_limit, :bigint
      add :storage_limit_gb, :integer
      add :retention_days_limit, :integer
      
      # Add-ons
      add :storage_addons, :jsonb, default: "[]"
      
      timestamps()
    end

    create unique_index(:subscriptions, [:team_id])
    create index(:subscriptions, [:stripe_customer_id])
    create index(:subscriptions, [:stripe_subscription_id])
    create index(:subscriptions, [:status])

    # Invoices (for tracking)
    create table(:invoices, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :subscription_id, references(:subscriptions, type: :uuid), null: false
      
      add :stripe_invoice_id, :string, null: false
      add :amount_due, :integer  # in cents
      add :amount_paid, :integer
      add :status, :string  # draft, open, paid, void, uncollectible
      add :invoice_pdf, :string  # URL to PDF
      
      add :period_start, :utc_datetime
      add :period_end, :utc_datetime
      
      # Breakdown
      add :line_items, :jsonb
      
      timestamps()
    end

    create index(:invoices, [:subscription_id])
    create index(:invoices, [:stripe_invoice_id])

    # Usage events (for detailed tracking)
    create table(:usage_events, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :team_id, references(:teams, type: :uuid), null: false
      add :subscription_id, references(:subscriptions, type: :uuid), null: false
      
      add :event_type, :string  # data_points_ingested, storage_added, pipeline_created
      add :quantity, :bigint
      add :metadata, :jsonb
      
      add :timestamp, :utc_datetime, null: false
      
      timestamps()
    end

    create index(:usage_events, [:team_id, :timestamp])
    create index(:usage_events, [:subscription_id, :event_type])
  end
end
```

---

### Limit Enforcement in Pipelines

```elixir
# Update Pipeline resource to check limits
defmodule Dash.Pipelines.Pipeline do
  use Ash.Resource
  # ... existing config

  changes do
    change before_action(fn changeset, _context ->
      # Check pipeline limit before creating
      team_id = Ash.Changeset.get_attribute(changeset, :team_id)
      
      case Dash.Billing.LimitEnforcer.can_create_pipeline?(%{id: team_id}) do
        {:ok, :allowed} ->
          changeset
        
        {:error, :limit_reached, message} ->
          Ash.Changeset.add_error(changeset, field: :base, message: message)
      end
    end), on: [:create]
  end
end
```

---

## Final Checklist Before Go-Live with Billing

### Technical Readiness
- [ ] Stripe integration fully tested (test mode)
- [ ] All subscription tiers configured in Stripe
- [ ] Webhook endpoints secured and tested
- [ ] Usage tracking accurate (audited)
- [ ] Limit enforcement working (tested all limits)
- [ ] Overage billing calculated correctly
- [ ] Email notifications working (trial ending, payment failed, etc.)
- [ ] Billing UI responsive and clear
- [ ] Payment method updates working
- [ ] Cancellation flow tested
- [ ] Refund process documented

### Business Readiness
- [ ] Pricing page published
- [ ] Terms of Service updated (payment terms)
- [ ] Privacy Policy updated (payment data)
- [ ] Support documentation for billing
- [ ] FAQ for common billing questions
- [ ] Refund policy published
- [ ] Sales tax configuration (Stripe Tax)
- [ ] Accounting software integration (QuickBooks/Xero)

### Customer Communication
- [ ] Email sequence for trial users prepared
- [ ] Blog post announcing pricing
- [ ] Existing users notified (if beta)
- [ ] Grandfathering plan for early users (optional)
- [ ] Support team trained on billing issues

### Monitoring
- [ ] Revenue dashboards (internal)
- [ ] Stripe dashboard bookmarked
- [ ] Alerts for failed payments
- [ ] Churn tracking setup
- [ ] MRR/ARR reporting automated

---

## End of Documentation [x] Add 2-3 more widget types (stat card, bar chart)
- [x] Public dashboard sharing
- [x] Error handling and user feedback
- [x] Deploy to Fly.io
- [x] Basic monitoring setup
- [x] Documentation

**MVP Deliverables:**
- Working application with 1 team, multiple users
- HTTP polling pipelines
- Real-time dashboards with 3-4 widget types
- Public sharing capability
- Deployed to production

### Phase 2: Growth Features (Weeks 9-16)

**Week 9-10: Webhook & Real-time**
- [ ] Webhook receiver endpoints
- [ ] Real-time pipeline type
- [ ] Webhook signature verification
- [ ] Rate limiting for webhooks

**Week 11-12: Advanced Transformations**
- [ ] Complex data transformations
- [ ] Calculated fields
- [ ] Data filtering
- [ ] Transformation testing UI

**Week 13-14: Data Sinks**
- [ ] HTTP sink adapter
- [ ] Webhook sink
- [ ] Email notifications
- [ ] Slack integration

**Week 15-16: Enhanced Dashboards**
- [ ] More widget types (gauges, maps, etc.)
- [ ] Dashboard templates
- [ ] Widget resize/drag-drop
- [ ] Dashboard export (PDF, PNG)

### Phase 3: Scale & Enterprise (Weeks 17-24)

**Week 17-18: Performance**
- [ ] Add read replicas
- [ ] Optimize hot queries
- [ ] Implement continuous aggregates
- [ ] Load testing and optimization

**Week 19-20: File Support**
- [ ] File upload in webhooks
- [ ] Cloudflare R2 integration
- [ ] File widget for dashboards
- [ ] File size limits and validation

**Week 21-22: Advanced Features**
- [ ] Pipeline-to-pipeline connections
- [ ] Retention policy management UI
- [ ] Storage usage tracking
- [ ] Team billing integration

**Week 23-24: Mobile & API**
- [ ] GraphQL API (via Ash)
- [ ] API documentation
- [ ] Mobile app planning
- [ ] API rate limiting

### Phase 4: Marketplace & Advanced (Future)

- [ ] Pipeline marketplace
- [ ] Pre-built pipeline templates
- [ ] OAuth integrations (Google Sheets, Salesforce, etc.)
- [ ] Advanced analytics
- [ ] ML/AI features for data insights
- [ ] White-label options

---

## Cost Estimates

### Phase 1: MVP (100-1K Users)

**Infrastructure:**
- Fly.io (2x shared-cpu-1x): $16/month
- PostgreSQL (1GB): $15/month
- Cloudflare R2: $5/month (includes 10GB)
- Domain + SSL: $12/year
- **Total: ~$40/month**

**Development:**
- 1 full-time developer: 8 weeks
- Estimated hours: 320 hours
- At $100/hour: $32,000

### Phase 2: Growth (1K-10K Users)

**Infrastructure:**
- Fly.io (4x dedicated-cpu-2x): $240/month
- PostgreSQL (4GB) + Replica: $90/month
- Cloudflare R2: $50/month (includes 100GB)
- Monitoring (Grafana Cloud): $50/month
- **Total: ~$430/month**

**Development:**
- 1-2 developers: 8 weeks
- Maintenance & support ongoing

### Phase 3: Scale (10K-50K Users)

**Infrastructure:**
- Fly.io cluster (10-20 nodes): $2,000/month
- Database cluster: $1,000/month
- Object storage: $500/month
- Monitoring & tools: $200/month
- **Total: ~$3,700/month**

**Team:**
- 2-3 developers
- 1 DevOps engineer
- Customer support
- **Total: $50K-80K/month**

---

## Decision Records

### DR-001: Why Elixir/Phoenix?

**Decision:** Use Elixir and Phoenix framework

**Rationale:**
- Real-time capabilities built-in (perfect for live dashboards)
- BEAM's concurrency model ideal for many simultaneous pipelines
- Fault tolerance via supervision trees
- Great for I/O-bound operations (API polling, webhooks)
- LiveView eliminates need for separate frontend framework
- Strong ecosystem for our use case

**Alternatives Considered:**
- Node.js: Less robust concurrency, callback hell
- Python/Django: Slower, not designed for real-time
- Go: More verbose, no built-in real-time like LiveView
- Ruby/Rails: Similar benefits but slower than Elixir

### DR-002: Why Ash Framework?

**Decision:** Use Ash Framework for domain logic

**Rationale:**
- Auto-generated GraphQL and REST APIs (mobile-ready)
- Built-in authorization policies (critical for multi-tenancy)
- Resource-based architecture enforces good patterns
- Reduces boilerplate significantly
- Active development and community

**Alternatives Considered:**
- Plain Phoenix contexts: More manual work, no auto-APIs
- Absinthe (GraphQL only): Have to build REST separately

### DR-003: Why TimescaleDB over Cassandra?

**Decision:** Use PostgreSQL with TimescaleDB extension

**Rationale:**
- SQL familiarity for team
- Joins work (essential for dashboard queries)
- Single database to manage
- Good enough performance for our scale
- Cheaper operational costs
- Continuous aggregates feature

**Alternatives Considered:**
- Cassandra: Overkill, no joins, higher complexity
- ClickHouse: Consider for Phase 3 if needed
- InfluxDB: Less flexible querying

### DR-004: Why LiveView over React?

**Decision:** Use Phoenix LiveView for UI

**Rationale:**
- One codebase (mostly Elixir)
- Real-time updates built-in
- SEO-friendly server rendering
- Faster development
- Smaller team can manage
- Lower hosting costs

**Alternatives Considered:**
- React SPA: Two codebases, more complexity
- Vue.js: Same issues as React
- Svelte: Less mature ecosystem

### DR-005: Why No Umbrella Project?

**Decision:** Use standard Phoenix project structure

**Rationale:**
- Simpler for small team
- Faster compilation
- Easier refactoring
- Can extract later if needed (rare)
- Most successful Elixir apps don't use umbrellas

**Alternatives Considered:**
- Umbrella: Added complexity without clear benefit at this stage

### DR-006: Why Fly.io over AWS/GCP?

**Decision:** Deploy to Fly.io initially

**Rationale:**
- Optimized for Elixir/Phoenix
- Global edge deployment
- Simple scaling
- Integrated PostgreSQL
- Lower operational burden
- Can migrate later if needed

**Alternatives Considered:**
- AWS: More complex, higher DevOps overhead
- Digital Ocean: Manual setup, less Elixir-optimized
- Heroku: More expensive, less control

---

## Real-World Use Cases

### Use Case 1: E-commerce Multi-Platform Analytics

**Customer Profile:** Small to medium online retailer ($500K-$5M annual revenue)

**Challenge:** Manually checking Shopify, Amazon, and Stripe daily; updating Excel spreadsheets for inventory and sales reporting.

**Dash Implementation:**
- **Pipeline 1:** Shopify API (polls every 5 minutes)
  - New orders, customer data, inventory levels
  - Data mapping: `customer.first_name` → `firstName`
  - Transformation: All prices converted to USD
  
- **Pipeline 2:** Amazon Seller Central API (hourly)
  - Sales, returns, FBA inventory
  
- **Pipeline 3:** Stripe webhook (real-time)
  - Payment events, refunds, disputes

**Dashboards:**
- Executive: Real-time revenue, orders/hour, AOV (Average Order Value)
- Inventory: Stock levels across platforms, low-stock alerts
- Public investor dashboard: Monthly GMV, growth trends

**Automated Actions (Data Sinks):**
- Slack notification when daily revenue exceeds $10K
- Email alert when any SKU drops below 10 units
- Daily sales summary to Google Sheets for accountant
- Webhook to reorder system when inventory critical

**Results:**
- Time saved: 2 hours/day → 40 hours/month
- Faster response: Catch stock-outs 24 hours earlier
- Better decisions: Real-time data vs. day-old reports
- **Estimated value:** $2,000/month in time + opportunity cost
- **Willing to pay:** $99-199/month

---

### Use Case 2: SaaS Product Metrics Monitoring

**Customer Profile:** Early-stage SaaS startup, 500-5,000 users

**Challenge:** Using 3+ separate tools (Mixpanel $300/mo, ChartMogul $250/mo, custom scripts) for product analytics. Manual board reports every month.

**Dash Implementation:**
- **Pipeline 1:** Application database webhook
  - User signups, feature usage, session data
  - Real-time activity stream
  
- **Pipeline 2:** Stripe API
  - MRR, churn, failed payments
  
- **Pipeline 3:** Customer.io API
  - Email campaign performance
  
- **Pipeline 4:** Support ticket system (Zendesk)
  - Volume, response time, satisfaction

**Data Transformations:**
- Calculate Customer Lifetime Value (CLV)
- Compute cohort retention rates
- Aggregate feature usage by plan tier
- Customer health score calculation

**Dashboards:**
- Growth: Daily signups, activation rate, MRR growth
- Health: Customer health scores, churn risk
- Product: Feature adoption, engagement metrics
- Public board dashboard: KPIs for investors

**Automated Actions:**
- Post to #growth Slack when signups > 50/day
- Trigger customer success workflow when health score < 50
- Weekly metrics email to CEO
- Alert when churn rate increases 2% MoM

**Results:**
- Tool consolidation: Saves $550/month in SaaS subscriptions
- Time saved: 10 hours/month on manual reporting
- Faster action: Real-time churn risk vs. quarterly reviews
- **Estimated value:** $3,000/month
- **Willing to pay:** $199-399/month

---

### Use Case 3: Digital Marketing Agency Client Reporting

**Customer Profile:** Marketing agency managing 15-30 clients

**Challenge:** Manually pulling data from Google Ads, Facebook Ads, Analytics for each client. Creating weekly reports takes 20+ hours.

**Dash Implementation:**
- **Pipeline 1:** Google Ads API (hourly, per client)
  - Spend, impressions, clicks, conversions
  
- **Pipeline 2:** Facebook Ads API (hourly, per client)
  - Campaign performance across Meta platforms
  
- **Pipeline 3:** Google Analytics API (daily)
  - Website traffic, behavior, conversions
  
- **Pipeline 4:** CRM webhooks (HubSpot/Salesforce)
  - Lead quality, sales conversions

**Multi-Tenancy Configuration:**
- Each client is a separate team
- Agency admins see all clients
- Clients see only their data
- Role-based access: Client viewers can't edit

**Data Transformations:**
- Normalize metrics: CTR, CPA, ROAS across platforms
- Calculate blended CAC (Customer Acquisition Cost)
- Attribution modeling (first-touch, last-touch, linear)
- Custom client-specific calculations

**Dashboards (Per Client):**
- Campaign performance by channel
- Creative performance (which ads work)
- ROI dashboard with ROAS
- Public dashboard clients share with their executives

**Automated Actions:**
- Weekly automated report via email (PDF export)
- Slack alert when CPA exceeds client threshold
- Pause campaign webhook when budget exhausted
- Export to client data warehouse (BigQuery)

**Results:**
- Time saved: 20 hours/week → 80 hours/month
- Client retention: +30% (transparency builds trust)
- New business: Dashboard demos close deals
- **Estimated value:** $8,000/month (billable hours)
- **Willing to pay:** $299-599/month (price per client model)

---

### Use Case 4: IoT Device Fleet Management

**Customer Profile:** Smart home/industrial IoT company with 10K-100K devices

**Challenge:** Monitoring thousands of devices, identifying failures, tracking battery life, firmware updates.

**Dash Implementation:**
- **Pipeline 1:** Device telemetry webhook
  - Temperature, humidity, battery from sensors
  - 500K-5M data points per day
  - Real-time streaming
  
- **Pipeline 2:** Device status API (polling)
  - Online/offline, firmware version, errors

**Data Mappings:**
- Standardize device IDs across manufacturers
- Convert temperature (F→C, C→F based on region)
- Parse error codes to human-readable messages

**Dashboards:**
- Operations: Live device status map (geographic)
- Alerts: Offline devices, low battery, anomalies
- Analytics: Avg temp by region, battery drain patterns
- Customer-facing: Each customer sees only their devices

**Data Retention Strategy:**
- Raw telemetry: 7 days (high volume)
- Hourly aggregates: 90 days
- Daily summaries: Forever
- TimescaleDB compression: 10x reduction after 7 days

**Automated Actions:**
- PagerDuty when >10% devices offline in region
- Email customer when battery < 20%
- Trigger firmware update for vulnerable devices
- Archive to S3 for long-term ML training

**Results:**
- Proactive maintenance: 60% reduction in support calls
- Customer satisfaction: +40% (battery notifications)
- Operational efficiency: Identify issues before customer notices
- **Estimated value:** $15,000/month
- **Willing to pay:** $499-999/month

---

### Use Case 5: Restaurant Chain Operations

**Customer Profile:** Fast-food/casual dining chain with 20-100 locations

**Challenge:** No real-time visibility into sales, inventory, labor across locations. Regional managers drive location-to-location.

**Dash Implementation:**
- **Pipeline 1:** POS system webhook (Square/Toast)
  - Real-time transactions from all locations
  - Per-location, per-item sales
  
- **Pipeline 2:** Inventory management system
  - Stock levels, food costs, waste
  
- **Pipeline 3:** Staff scheduling system
  - Labor hours, overtime, schedule adherence
  
- **Pipeline 4:** Google Reviews API
  - Star ratings, review sentiment

**Multi-Tenancy:**
- Corporate sees all locations
- Regional manager sees their region
- Location manager sees only their location
- Franchisees see their locations only

**Data Transformations:**
- Normalize menu items across locations
- Calculate food cost percentage
- Labor efficiency metrics (sales per labor hour)
- Trend analysis (same-store sales growth)

**Dashboards:**
- Executive: System-wide sales, top/bottom performers
- Location: Real-time sales vs. target, labor, inventory
- Operations: Food cost %, labor efficiency
- Customer experience: Review trends, complaint analysis

**Automated Actions:**
- Slack alert when location misses hourly target
- Email district manager when food cost spikes
- Text manager when understaffed
- Daily P&L to each location manager

**Results:**
- Visibility: Issues identified in real-time vs. next day
- Cost control: Food waste down 15%, labor optimized
- Consistency: Enforce standards across locations
- **Estimated value:** $20,000/month (50 locations)
- **Willing to pay:** $799-1,499/month

---

### Use Case 6: Healthcare Remote Patient Monitoring

**Customer Profile:** Healthcare provider, chronic disease management program

**Challenge:** Manual data collection from patients, reactive care, hospital readmissions.

**Dash Implementation:**
- **Pipeline 1:** Wearable device API (Fitbit, Apple Health)
  - Heart rate, steps, sleep, glucose, blood pressure
  
- **Pipeline 2:** Smart scale webhook
  - Daily weight, body composition
  
- **Pipeline 3:** Medication adherence sensors
  - Pill bottle sensors, timestamps
  
- **Pipeline 4:** Patient self-reporting app
  - Symptom logs, mood, energy

**HIPAA Compliance:**
- Field-level encryption (Cloak)
- Audit logging on all access
- Role-based access (doctors, nurses, patients)
- Data retention: 7 years (compliance)
- BAA (Business Associate Agreement) with Dash

**Dashboards:**
- Doctor: All patients, flagged concerning trends
- Patient: Their own metrics (public dashboard with token)
- Care coordinator: Patients needing intervention
- Population health: Anonymized aggregate data

**Data Transformations:**
- HbA1c estimates from glucose readings
- Medication adherence patterns
- Risk scoring (hospital readmission risk)
- Trend detection (rapid weight gain = fluid retention)

**Automated Actions:**
- Alert nurse when patient misses 3 medications
- Email doctor when metrics worsen
- SMS encouragement when activity goal hit
- Trigger care coordinator outreach for high-risk

**File Support:**
- Upload lab results PDFs → link to patient
- EKG readings from device → stored, displayed

**Results:**
- Readmissions: 40% reduction
- Care team efficiency: Proactive vs. reactive
- Patient engagement: Patients see progress, stay motivated
- **Estimated value:** $50,000/month (1000 patients)
- **Willing to pay:** $1,999-4,999/month

---

### Use Case 7: Content Creator Cross-Platform Analytics

**Customer Profile:** YouTuber/influencer with 100K-1M followers

**Challenge:** Checking YouTube, Instagram, TikTok, Patreon separately. No unified view of performance and revenue.

**Dash Implementation:**
- **Pipeline 1:** YouTube Analytics API
  - Views, watch time, subscribers, revenue, CPM
  
- **Pipeline 2:** Instagram API
  - Post engagement, follower growth, story views
  
- **Pipeline 3:** TikTok API
  - Video views, engagement rate
  
- **Pipeline 4:** Patreon API
  - Patron count, monthly revenue, tier distribution
  
- **Pipeline 5:** Shopify (merchandise)
  - Sales, product performance

**Dashboards:**
- Performance: Cross-platform metrics in one view
- Revenue: Total income by source (YouTube, Patreon, merch)
- Audience: Demographics, growth trends
- Content: Which videos/posts perform best
- Public: Share with sponsors/potential brand deals

**Data Transformations:**
- Calculate engagement rate (each platform different)
- Normalize metrics for comparison
- Identify optimal posting times
- Revenue per follower by platform

**Automated Actions:**
- Auto-tweet when video hits 100K views
- Email when monthly revenue hits goal
- Update Notion content calendar
- Discord bot posts milestones to fan community

**Results:**
- Brand deals: Professional dashboard impresses sponsors
- Strategy: Data-driven content decisions
- Time saved: 5 hours/week on analytics
- **Estimated value:** $2,000/month
- **Willing to pay:** $49-99/month

---

## Pricing & Monetization Strategy

### Pricing Philosophy

**Value-Based Pricing:** Price based on customer value, not just our costs
**Tiered Model:** Grow with customers from hobbyist to enterprise
**Usage-Based Components:** Fair pricing for heavy users
**No Surprises:** Transparent, predictable billing

---

### Pricing Tiers

#### **Free Tier** - "Starter"
**Target:** Individuals, hobbyists, proof-of-concept

**Limits:**
- 3 pipelines
- 1 team (5 members max)
- 3 dashboards
- 1 GB data storage
- 7-day data retention
- 10,000 data points/month
- Community support only

**Price:** $0/month

**Purpose:** Acquisition, viral growth, learning platform

---

#### **Professional** - "Pro"
**Target:** Small businesses, solopreneurs, content creators

**Includes:**
- 25 pipelines
- 2 teams (10 members each)
- 15 dashboards
- 25 GB data storage
- 30-day data retention
- 1M data points/month
- Email support (24-hour response)
- Public dashboard sharing
- Basic data sinks (email, webhook)
- API access

**Price:** $49/month (annual) or $59/month (monthly)

**Target Customers:**
- E-commerce store owners
- Content creators
- Freelance consultants
- Small SaaS apps

---

#### **Business** - "Team"
**Target:** Growing companies, agencies, teams

**Includes:**
- 100 pipelines
- 10 teams (50 members each)
- Unlimited dashboards
- 100 GB data storage
- 90-day data retention
- 10M data points/month
- Priority email + chat support
- All data sinks (Slack, Zapier, etc.)
- Advanced transformations
- SSO (SAML)
- Audit logging
- SLA: 99.5% uptime

**Price:** $199/month (annual) or $249/month (monthly)

**Target Customers:**
- Marketing agencies (15-30 clients)
- SaaS companies (1K-10K users)
- Multi-location businesses
- DevOps teams

---

#### **Enterprise** - "Custom"
**Target:** Large companies, regulated industries, high-volume

**Includes:**
- Unlimited pipelines
- Unlimited teams
- Unlimited dashboards
- Custom storage (500GB-10TB+)
- Custom data retention (up to indefinite)
- Unlimited data points
- Dedicated account manager
- Phone + Slack support (1-hour response)
- Custom SLA (99.9% or 99.95%)
- SOC 2 Type II compliance
- BAA for HIPAA (healthcare)
- Custom contracts
- On-premise option (future)
- White-label option (future)

**Price:** Starting at $999/month (negotiated based on usage)

**Add-ons:**
- +$500/month for HIPAA BAA
- +$1,000/month for SOC 2 audit support
- +$2,000/month for dedicated infrastructure

**Target Customers:**
- Healthcare providers
- Large IoT deployments (100K+ devices)
- Enterprise SaaS companies
- Financial institutions
- Restaurant chains (50+ locations)

---

### Usage-Based Add-Ons (All Tiers)

**Additional Data Storage:**
- $1 per additional GB/month
- Encourages data retention policy usage

**Additional Data Points:**
- $5 per additional 1M data points/month
- Only charged if you exceed tier limit

**Additional Team Members:**
- $5 per user/month (above tier limit)

**File Storage:**
- First 10 GB included
- $0.03 per GB/month after (Cloudflare R2 pricing + margin)

**Data Sinks (Professional tier):**
- Advanced sinks: $10/month per sink type
  - Salesforce, HubSpot, BigQuery, etc.

---

### Annual Discount

**All paid tiers:** 15-20% discount for annual payment
- Improves cash flow
- Reduces churn
- Customer commitment

**Example:**
- Pro: $59/mo monthly = $708/year
- Pro: $49/mo annual = $588/year (saves $120)

---

### Pricing Comparison Table

| Feature | Free | Pro | Business | Enterprise |
|---------|------|-----|----------|------------|
| **Pipelines** | 3 | 25 | 100 | Unlimited |
| **Teams** | 1 (5 members) | 2 (10 each) | 10 (50 each) | Unlimited |
| **Dashboards** | 3 | 15 | Unlimited | Unlimited |
| **Storage** | 1 GB | 25 GB | 100 GB | Custom |
| **Retention** | 7 days | 30 days | 90 days | Custom |
| **Data Points/mo** | 10K | 1M | 10M | Unlimited |
| **Support** | Community | Email (24hr) | Priority | Dedicated |
| **Public Dashboards** | ✗ | ✓ | ✓ | ✓ |
| **SSO** | ✗ | ✗ | ✓ | ✓ |
| **API Access** | ✗ | ✓ | ✓ | ✓ |
| **SLA** | None | None | 99.5% | 99.9%+ |
| **SOC 2** | ✗ | ✗ | ✗ | ✓ |
| **HIPAA BAA** | ✗ | ✗ | ✗ | ✓ (+$500) |
| **Price** | $0 | $49/mo | $199/mo | $999+/mo |

---

### Revenue Projections

**Year 1 Goals:**

| Month | Free Users | Pro Users | Business Users | Enterprise | MRR | ARR |
|-------|-----------|-----------|----------------|------------|-----|-----|
| 3 | 100 | 5 | 0 | 0 | $245 | $2,940 |
| 6 | 250 | 20 | 2 | 0 | $1,378 | $16,536 |
| 9 | 500 | 50 | 5 | 1 | $4,444 | $53,328 |
| 12 | 1,000 | 100 | 15 | 3 | $11,882 | $142,584 |

**Assumptions:**
- 10% free → Pro conversion
- 5% Pro → Business upgrade
- 1-2 Enterprise deals per quarter
- 5% monthly churn (improves over time)

**Year 2 Goal:** $500K ARR (4,200 MRR)
**Year 3 Goal:** $2M ARR

---

### Competitive Pricing Analysis

**vs. Building Custom:**
- Developer time: $10K-50K
- Maintenance: $2K-5K/month
- Infrastructure: $500-5K/month
- **Total:** $30K-100K/year
- **Dash saves:** $20K-90K/year for Business tier customer

**vs. Competitors:**

| Competitor | Starting Price | Limitations | Dash Advantage |
|------------|---------------|-------------|----------------|
| **Zapier** | $20/mo | 100 tasks, no dashboards | We include visualizations |
| **Segment** | $120/mo | Data routing only, no viz | Full pipeline + dashboards |
| **Datadog** | $15/host/mo | Monitoring only | We handle data transformation |
| **Tableau** | $70/user/mo | Visualization only | We fetch + transform data |
| **Custom Build** | $10K-50K | Dev time, maintenance | Turnkey solution |

**Value Proposition:** Only platform combining data pipelines + transformations + real-time dashboards at this price point.

---

### Payment & Billing Implementation

**Technical Stack:**
- **Payment Processor:** Stripe
- **Integration:** via Ash or direct Stripe API
- **Subscription Management:** Stripe Billing
- **Invoicing:** Stripe invoices (auto-generated)

**Billing Schema:**

```elixir
# lib/dash/billing/resources/subscription.ex
defmodule Dash.Billing.Subscription do
  use Ash.Resource

  attributes do
    uuid_primary_key :id
    
    attribute :stripe_subscription_id, :string
    attribute :stripe_customer_id, :string
    
    attribute :tier, :atom do
      constraints one_of: [:free, :pro, :business, :enterprise]
      default :free
    end
    
    attribute :status, :atom do
      constraints one_of: [:active, :past_due, :canceled, :trialing]
    end
    
    attribute :billing_interval, :atom do
      constraints one_of: [:monthly, :annual]
    end
    
    # Usage tracking
    attribute :pipelines_count, :integer, default: 0
    attribute :data_points_current_month, :integer, default: 0
    attribute :storage_used_gb, :decimal, default: 0.0
    
    # Limits based on tier
    attribute :pipelines_limit, :integer
    attribute :data_points_limit, :integer
    attribute :storage_limit_gb, :integer
    
    attribute :trial_ends_at, :datetime
    attribute :current_period_end, :datetime
    
    belongs_to :team, Dash.Accounts.Team
  end
  
  # Usage enforcement
  calculations do
    calculate :is_over_pipeline_limit, :boolean, expr(
      pipelines_count > pipelines_limit
    )
    
    calculate :is_over_storage_limit, :boolean, expr(
      storage_used_gb > storage_limit_gb
    )
  end
end
```

**Usage Tracking:**

```elixir
# Track pipeline creation
defmodule Dash.Pipelines.Pipeline do
  # ...
  
  changes do
    change after_action(fn _changeset, pipeline ->
      Dash.Billing.track_pipeline_created(pipeline.team_id)
    end)
  end
end

# Enforce limits
defmodule Dash.Billing.LimitEnforcer do
  def check_can_create_pipeline(team) do
    subscription = get_subscription(team)
    
    if subscription.pipelines_count >= subscription.pipelines_limit do
      {:error, :limit_reached, "Upgrade to create more pipelines"}
    else
      :ok
    end
  end
  
  def check_storage_limit(team, additional_gb) do
    subscription = get_subscription(team)
    projected = subscription.storage_used_gb + additional_gb
    
    if projected > subscription.storage_limit_gb do
      {:error, :storage_limit, "Upgrade for more storage"}
    else
      :ok
    end
  end
end
```

**Stripe Webhook Handling:**

```elixir
# lib/dash_web/controllers/stripe_webhook_controller.ex
defmodule DashWeb.StripeWebhookController do
  use DashWeb, :controller

  def webhook(conn, _params) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    signature = get_req_header(conn, "stripe-signature") |> List.first()
    
    case Stripe.Webhook.construct_event(body, signature, webhook_secret()) do
      {:ok, %Stripe.Event{type: "customer.subscription.created"} = event} ->
        handle_subscription_created(event)
        json(conn, %{status: "ok"})
      
      {:ok, %Stripe.Event{type: "customer.subscription.updated"} = event} ->
        handle_subscription_updated(event)
        json(conn, %{status: "ok"})
      
      {:ok, %Stripe.Event{type: "customer.subscription.deleted"} = event} ->
        handle_subscription_canceled(event)
        json(conn, %{status: "ok"})
      
      {:ok, %Stripe.Event{type: "invoice.payment_failed"} = event} ->
        handle_payment_failed(event)
        json(conn, %{status: "ok"})
      
      {:error, _} ->
        conn |> put_status(400) |> json(%{error: "Invalid signature"})
    end
  end
  
  defp handle_subscription_created(event) do
    subscription_data = event.data.object
    
    # Update team's subscription
    team = find_team_by_stripe_customer(subscription_data.customer)
    
    Ash.update!(team.subscription, :activate, %{
      stripe_subscription_id: subscription_data.id,
      tier: map_stripe_plan_to_tier(subscription_data.plan.id),
      status: :active,
      current_period_end: DateTime.from_unix!(subscription_data.current_period_end)
    })
  end
end
```

---

### Free Trial Strategy

**14-Day Pro Trial:**
- New signups get Pro tier for 14 days
- No credit card required
- Convert to Free after trial unless they upgrade
- Email sequence during trial:
  - Day 1: Welcome + quick start guide
  - Day 3: Feature highlight (dashboards)
  - Day 7: Use case examples
  - Day 10: Upgrade prompt (4 days left)
  - Day 13: Final reminder (1 day left)

**Expected Conversion:** 8-12% trial → paid

---

### Upgrade Prompts (In-App)

**Soft Limits:**
- When approaching limit (80%), show banner: "You're using 20/25 pipelines. Upgrade for more."
- When at limit, show modal: "Pipeline limit reached. Upgrade to Pro or delete a pipeline."

**Feature Gating:**
- Try to create 4th dashboard on Free → "Upgrade to Pro for unlimited dashboards"
- Try to set retention > 7 days → "Upgrade for longer retention"
- Try to add SSO → "SSO available on Business tier"

---

### Customer Success & Retention

**Churn Prevention:**
- Email when usage drops 50% for 2 weeks
- Offer pause subscription option (3 months)
- Exit survey on cancellation
- Win-back campaign after 30 days

**Expansion Revenue:**
- Monitor usage approaching limits
- Proactive upgrade suggestions
- Annual plan conversion campaign
- Enterprise white-glove outreach at $500 MRR

**Target Metrics:**
- Gross churn: <5% monthly
- Net revenue retention: >100% (expansion covers churn)
- LTV/CAC ratio: >3:1

---

## Reference

### Project Structure

```
dash/
├── assets/
│   ├── css/
│   │   └── app.css
│   ├── js/
│   │   ├── app.js
│   │   └── hooks/
│   │       └── chart.js
│   └── vendor/
├── config/
│   ├── config.exs
│   ├── dev.exs
│   ├── prod.exs
│   ├── runtime.exs
│   └── test.exs
├── lib/
│   ├── dash/
│   │   ├── accounts/              # Ash Domain
│   │   │   ├── domain.ex
│   │   │   └── resources/
│   │   │       ├── user.ex
│   │   │       ├── team.ex
│   │   │       └── membership.ex
│   │   ├── pipelines/             # Ash Domain
│   │   │   ├── domain.ex
│   │   │   ├── resources/
│   │   │   │   ├── pipeline.ex
│   │   │   │   ├── pipeline_sink.ex
│   │   │   │   └── data_mapping.ex
│   │   │   ├── workers/
│   │   │   │   ├── polling_worker.ex
│   │   │   │   └── pipeline_supervisor.ex
│   │   │   ├── data_mapper.ex
│   │   │   └── adapters/
│   │   │       ├── sources/
│   │   │       │   ├── http_api.ex
│   │   │       │   └── webhook.ex
│   │   │       └── sinks/
│   │   │           └── http_api.ex
│   │   ├── dashboards/            # Ash Domain
│   │   │   ├── domain.ex
│   │   │   ├── resources/
│   │   │   │   ├── dashboard.ex
│   │   │   │   └── widget.ex
│   │   │   └── widget_data_transformer.ex
│   │   ├── data/                  # High-performance layer
│   │   │   ├── pipeline_data.ex
│   │   │   ├── cache_manager.ex
│   │   │   └── queries.ex
│   │   ├── storage/               # File storage
│   │   │   └── storage.ex
│   │   ├── monitoring/
│   │   │   ├── telemetry.ex
│   │   │   └── alerts.ex
│   │   ├── application.ex
│   │   └── repo.ex
│   └── dash_web/
│       ├── components/
│       │   ├── core_components.ex
│       │   └── widgets.ex
│       ├── controllers/
│       │   └── pipeline_webhook_controller.ex
│       ├── live/
│       │   ├── dashboard_live.ex
│       │   ├── pipeline_live.ex
│       │   └── team_live.ex
│       ├── endpoint.ex
│       ├── router.ex
│       └── telemetry.ex
├── priv/
│   ├── repo/
│   │   ├── migrations/
│   │   └── seeds.exs
│   ├── static/
│   └── gettext/
├── test/
├── .formatter.exs
├── .gitignore
├── Dockerfile
├── fly.toml
├── mix.exs
├── mix.lock
└── README.md
```

### Key Dependencies

```elixir
# mix.exs
defp deps do
  [
    # Phoenix
    {:phoenix, "~> 1.7.10"},
    {:phoenix_ecto, "~> 4.4"},
    {:phoenix_html, "~> 4.0"},
    {:phoenix_live_view, "~> 0.20.2"},
    {:phoenix_live_dashboard, "~> 0.8.3"},
    
    # Database
    {:ecto_sql, "~> 3.11"},
    {:postgrex, ">= 0.0.0"},
    
    # Ash Framework
    {:ash, "~> 3.0"},
    {:ash_postgres, "~> 2.0"},
    {:ash_authentication, "~> 4.0"},
    {:ash_authentication_phoenix, "~> 2.0"},
    {:ash_json_api, "~> 1.0"},
    {:ash_graphql, "~> 1.0"},
    
    # Background Jobs
    {:oban, "~> 2.17"},
    
    # HTTP Client
    {:httpoison, "~> 2.2"},
    {:req, "~> 0.4"},
    
    # JSON
    {:jason, "~> 1.4"},
    
    # Encryption
    {:cloak_ecto, "~> 1.2"},
    
    # Clustering
    {:libcluster, "~> 3.3"},
    
    # Monitoring
    {:telemetry_metrics, "~> 0.6"},
    {:telemetry_poller, "~> 1.0"},
    {:telemetry_metrics_prometheus, "~> 1.1"},
    
    # Error Tracking
    {:sentry, "~> 10.0"},
    
    # Rate Limiting
    {:hammer, "~> 6.1"},
    
    # Payments
    {:stripe, "~> 3.0"},
    {:stripity_stripe, "~> 3.0"},  # Alternative
    
    # File Storage
    {:ex_aws, "~> 2.5"},
    {:ex_aws_s3, "~> 2.4"},
    
    # Frontend
    {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
    {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
    
    # Dev/Test
    {:phoenix_live_reload, "~> 1.4", only: :dev},
    {:floki, ">= 0.30.0", only: :test},
    {:ex_machina, "~> 2.7", only: :test}
  ]
end
```

### Environment Variables

```bash
# .env.example

# Database
DATABASE_URL=ecto://postgres:postgres@localhost/dash_dev
DATABASE_REPLICA_URL=ecto://postgres:postgres@localhost/dash_dev  # Same initially

# Phoenix
SECRET_KEY_BASE=generate_with_mix_phx_gen_secret
PHX_HOST=localhost
PORT=4000

# Encryption
ENCRYPTION_KEY=generate_with_openssl_rand_base64_32

# Stripe (Payments)
STRIPE_PUBLIC_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...

# File Storage (Cloudflare R2)
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
R2_BUCKET=dash-files
R2_ENDPOINT=https://...r2.cloudflarestorage.com

# Monitoring
SENTRY_DSN=https://...@sentry.io/...

# Email (SendGrid/Postmark)
SENDGRID_API_KEY=...
FROM_EMAIL=noreply@dash.app

# Optional
SLACK_WEBHOOK_URL=...  # For team notifications
```

---

## Appendix A: Stripe Integration Code Examples

### Subscription Management

```elixir
# lib/dash/billing/stripe_service.ex
defmodule Dash.Billing.StripeService do
  @moduledoc """
  Handles all Stripe operations for subscription management
  """

  # Price IDs (set these in Stripe dashboard)
  @prices %{
    pro_monthly: "price_pro_monthly_id",
    pro_annual: "price_pro_annual_id",
    business_monthly: "price_business_monthly_id",
    business_annual: "price_business_annual_id"
  }

  def create_customer(team, user) do
    Stripe.Customer.create(%{
      email: user.email,
      name: team.name,
      metadata: %{
        team_id: team.id,
        user_id: user.id
      }
    })
  end

  def create_subscription(team, tier, interval) do
    price_id = get_price_id(tier, interval)
    
    Stripe.Subscription.create(%{
      customer: team.stripe_customer_id,
      items: [%{price: price_id}],
      trial_period_days: 14,
      metadata: %{
        team_id: team.id,
        tier: tier
      }
    })
  end

  def upgrade_subscription(subscription, new_tier, new_interval) do
    new_price_id = get_price_id(new_tier, new_interval)
    
    Stripe.Subscription.update(subscription.stripe_subscription_id, %{
      items: [
        %{
          id: get_subscription_item_id(subscription),
          price: new_price_id
        }
      ],
      proration_behavior: "always_invoice"  # Charge immediately for upgrade
    })
  end

  def cancel_subscription(subscription, at_period_end \\ true) do
    Stripe.Subscription.delete(
      subscription.stripe_subscription_id,
      %{at_period_end: at_period_end}
    )
  end

  def create_billing_portal_session(team, return_url) do
    Stripe.BillingPortal.Session.create(%{
      customer: team.stripe_customer_id,
      return_url: return_url
    })
  end

  defp get_price_id(tier, interval) do
    key = String.to_atom("#{tier}_#{interval}")
    Map.get(@prices, key)
  end
end
```

### Usage-Based Billing

```elixir
# lib/dash/billing/usage_tracker.ex
defmodule Dash.Billing.UsageTracker do
  @moduledoc """
  Tracks usage and reports to Stripe for overage billing
  """

  # Track data points ingested
  def track_data_points(team_id, count) do
    subscription = get_subscription(team_id)
    
    # Update local counter
    new_count = subscription.data_points_current_month + count
    update_subscription_usage(subscription, data_points: new_count)
    
    # Report to Stripe if metered billing
    if subscription.tier in [:business, :enterprise] do
      report_usage_to_stripe(subscription, count)
    end
    
    # Check if over limit
    if new_count > subscription.data_points_limit do
      handle_overage(subscription, :data_points)
    end
  end

  # Report usage to Stripe (for metered billing)
  defp report_usage_to_stripe(subscription, quantity) do
    subscription_item_id = get_metered_subscription_item(subscription)
    
    Stripe.SubscriptionItem.Usage.create(
      subscription_item_id,
      %{
        quantity: quantity,
        timestamp: DateTime.utc_now() |> DateTime.to_unix(),
        action: "increment"
      }
    )
  end

  # Handle usage overage
  defp handle_overage(subscription, usage_type) do
    case subscription.tier do
      :free ->
        # Hard limit - stop accepting data
        notify_team_limit_reached(subscription.team_id, usage_type)
        :limit_reached
      
      tier when tier in [:pro, :business] ->
        # Soft limit - charge overage
        calculate_and_charge_overage(subscription, usage_type)
        :overage_charged
      
      :enterprise ->
        # No limit, but notify if unusual
        if unusual_usage?(subscription, usage_type) do
          notify_account_manager(subscription)
        end
        :ok
    end
  end

  defp calculate_and_charge_overage(subscription, :data_points) do
    overage = subscription.data_points_current_month - subscription.data_points_limit
    overage_millions = overage / 1_000_000
    charge = overage_millions * 5.00  # $5 per million over limit
    
    # Create invoice item
    Stripe.InvoiceItem.create(%{
      customer: subscription.stripe_customer_id,
      amount: trunc(charge * 100),  # Convert to cents
      currency: "usd",
      description: "Data points overage: #{overage_millions}M @ $5/M"
    })
  end

  # Reset monthly counters
  def reset_monthly_usage(subscription) do
    update_subscription_usage(subscription,
      data_points_current_month: 0
    )
  end
end
```

### Subscription Lifecycle LiveView

```elixir
# lib/dash_web/live/billing_live.ex
defmodule DashWeb.BillingLive do
  use DashWeb, :live_view

  def mount(_params, session, socket) do
    team = get_current_team(session)
    subscription = Dash.Billing.get_subscription(team)
    
    socket =
      socket
      |> assign(:team, team)
      |> assign(:subscription, subscription)
      |> assign(:usage, calculate_usage(subscription))
      |> assign(:available_tiers, get_available_tiers())
    
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="billing-container">
      <h1>Billing & Usage</h1>
      
      <!-- Current Plan -->
      <div class="current-plan">
        <h2>Current Plan: <%= format_tier(@subscription.tier) %></h2>
        <p>
          <%= if @subscription.billing_interval == :annual do %>
            Billed annually - Next payment: <%= @subscription.current_period_end %>
          <% else %>
            Billed monthly - Next payment: <%= @subscription.current_period_end %>
          <% end %>
        </p>
        
        <button phx-click="manage_billing" class="btn-secondary">
          Manage Payment Method
        </button>
      </div>
      
      <!-- Usage Meters -->
      <div class="usage-meters">
        <h3>Usage This Month</h3>
        
        <!-- Pipelines -->
        <div class="usage-meter">
          <div class="meter-header">
            <span>Pipelines</span>
            <span><%= @usage.pipelines_count %> / <%= @subscription.pipelines_limit %></span>
          </div>
          <div class="meter-bar">
            <div class="meter-fill" style={"width: #{usage_percent(@usage.pipelines_count, @subscription.pipelines_limit)}%"}></div>
          </div>
        </div>
        
        <!-- Storage -->
        <div class="usage-meter">
          <div class="meter-header">
            <span>Storage</span>
            <span><%= format_gb(@subscription.storage_used_gb) %> / <%= @subscription.storage_limit_gb %> GB</span>
          </div>
          <div class="meter-bar">
            <div class="meter-fill" style={"width: #{usage_percent(@subscription.storage_used_gb, @subscription.storage_limit_gb)}%"}></div>
          </div>
        </div>
        
        <!-- Data Points -->
        <div class="usage-meter">
          <div class="meter-header">
            <span>Data Points</span>
            <span><%= format_millions(@subscription.data_points_current_month) %> / <%= format_millions(@subscription.data_points_limit) %>M</span>
          </div>
          <div class="meter-bar">
            <div class="meter-fill" style={"width: #{usage_percent(@subscription.data_points_current_month, @subscription.data_points_limit)}%"}></div>
          </div>
          <%= if @subscription.data_points_current_month > @subscription.data_points_limit do %>
            <p class="overage-notice">
              Overage: <%= format_millions(@subscription.data_points_current_month - @subscription.data_points_limit) %>M 
              @ $5/M = $<%= calculate_overage_cost(@subscription) %>
            </p>
          <% end %>
        </div>
      </div>
      
      <!-- Upgrade Options -->
      <%= if @subscription.tier != :enterprise do %>
        <div class="upgrade-options">
          <h3>Upgrade Your Plan</h3>
          
          <%= for tier <- @available_tiers do %>
            <div class="tier-card">
              <h4><%= tier.name %></h4>
              <p class="price">
                $<%= tier.monthly_price %>/month
                <span class="annual-save">Save 20% with annual</span>
              </p>
              
              <ul class="features">
                <%= for feature <- tier.features do %>
                  <li><%= feature %></li>
                <% end %>
              </ul>
              
              <button phx-click="upgrade" phx-value-tier={tier.slug} class="btn-primary">
                <%= if tier.slug == @subscription.tier, do: "Current Plan", else: "Upgrade" %>
              </button>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("upgrade", %{"tier" => tier}, socket) do
    # Redirect to checkout or upgrade flow
    {:noreply, push_navigate(socket, to: ~p"/billing/upgrade/#{tier}")}
  end

  def handle_event("manage_billing", _params, socket) do
    # Create Stripe billing portal session
    {:ok, session} = Dash.Billing.StripeService.create_billing_portal_session(
      socket.assigns.team,
      url(~p"/billing")
    )
    
    {:noreply, redirect(socket, external: session.url)}
  end

  defp calculate_usage(subscription) do
    %{
      pipelines_count: Dash.Pipelines.count_by_team(subscription.team_id),
      storage_gb: subscription.storage_used_gb,
      data_points: subscription.data_points_current_month
    }
  end

  defp usage_percent(current, limit) when limit > 0 do
    min(100, (current / limit * 100) |> Float.round(1))
  end
  defp usage_percent(_, _), do: 0
end
```

---

## Appendix B: Deployment Checklist

### Pre-Launch Checklist

**Infrastructure:**
- [ ] Fly.io app created
- [ ] PostgreSQL database provisioned
- [ ] TimescaleDB extension enabled
- [ ] Environment variables set (secrets)
- [ ] Domain configured (DNS)
- [ ] SSL certificate active
- [ ] Cloudflare R2 bucket created
- [ ] File upload limits configured

**Database:**
- [ ] Migrations run
- [ ] Indexes created
- [ ] TimescaleDB hypertables configured
- [ ] Compression policies set
- [ ] Backup strategy configured
- [ ] Connection pooling tested

**Application:**
- [ ] Authentication working (all methods)
- [ ] Email sending configured (SendGrid/Postmark)
- [ ] Stripe integration tested
- [ ] Webhook endpoints secured
- [ ] Rate limiting active
- [ ] CORS configured
- [ ] Error tracking (Sentry) working

**Monitoring:**
- [ ] Telemetry metrics exporting
- [ ] Grafana dashboards created
- [ ] Alerts configured
- [ ] Uptime monitoring (UptimeRobot/Pingdom)
- [ ] Log aggregation setup

**Security:**
- [ ] Security headers active
- [ ] CSRF protection enabled
- [ ] SQL injection prevention verified
- [ ] XSS protection verified
- [ ] Rate limiting tested
- [ ] Audit logging working
- [ ] Data encryption verified

**Legal/Compliance:**
- [ ] Privacy policy published
- [ ] Terms of service published
- [ ] Cookie consent (if EU traffic)
- [ ] GDPR compliance reviewed
- [ ] Data retention policies documented

---

## Glossary

**BEAM:** The Erlang virtual machine that runs Elixir code

**ETS:** Erlang Term Storage - in-memory key-value store

**GenServer:** Generic server behavior in Elixir for stateful processes

**Hypertable:** TimescaleDB's abstraction for time-series data

**LiveView:** Phoenix framework for real-time server-rendered UIs

**Multi-tenancy:** Architecture where multiple customers (teams) share infrastructure but data is isolated

**Oban:** Background job processing library for Elixir

**Pipeline:** User-configured data flow from source to destination

**PubSub:** Publish-subscribe messaging pattern for real-time updates

**Sink:** Destination where pipeline data is sent (email, Slack, API, etc.)

**Source:** Origin of data for a pipeline (API, webhook, database, etc.)

**Supervision Tree:** Elixir's fault-tolerance mechanism

**Widget:** Visualization component on a dashboard (chart, table, etc.)

---

## End of Documentation

**Last Updated:** January 2026  
**Version:** 1.0  
**Status:** Complete Technical Plan

For questions or updates, please contact the development team.

---

**Next Steps:**
1. Review this plan with stakeholders
2. Set up development environment
3. Initialize Phoenix project
4. Begin Phase 1 implementation (Week 1-2)
5. Deploy MVP to production (Week 8)

Good luck building Dash! 🚀