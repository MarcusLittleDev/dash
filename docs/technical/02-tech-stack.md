# Technology Stack

## Backend Technologies

| Component | Technology | Version | Rationale |
|-----------|-----------|---------|-----------|
| **Language** | Elixir | 1.16+ | Concurrency, fault tolerance, distributed |
| **Web Framework** | Phoenix | 1.7+ | Proven, batteries-included, LiveView |
| **Domain Framework** | Ash Framework | 3.0+ | Auto APIs, policies, resources |
| **Database ORM** | Ecto | 3.11+ | Mature, composable queries |
| **Time-Series** | TimescaleDB | 2.14+ | PostgreSQL extension, familiar SQL |
| **Job Processing** | Oban | 2.17+ | Reliable, uses PostgreSQL |
| **Data Processing** | Explorer | 0.8+ | Apache Arrow-backed DataFrames, zero-copy reads |
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

## Data Processing Stack

### Current: Explorer + Apache Arrow

**Explorer** is the standard library for data processing in Dash, providing:

- **Apache Arrow** memory format for zero-copy data access
- **Rust NIFs** for high-performance operations outside BEAM
- **DataFrame API** for filtering, aggregation, and transformation
- **Parquet support** for efficient Bronze layer storage

```elixir
# Example: Replay worker using Explorer
require Explorer.DataFrame, as: DF

df = DF.from_parquet!(bronze_file_path)
|> DF.filter(col("pipeline_id") == ^pipeline_id)
|> DF.mutate(
     metric_value: cast(col("value"), :float) * col("multiplier"),
     metric_name: "transformed_metric"
   )
|> DF.select(["timestamp", "metric_name", "metric_value"])

Dash.Repo.insert_all("pipeline_metrics", DF.to_rows(df))
```

**Benefits over Enum/Stream:**
- 10-50x faster for large datasets
- Memory-mapped files (no BEAM heap allocation)
- Columnar operations optimized for analytics

### Future: Broadway (Phase 3+)

**Broadway** provides Flink-like stream processing natively in Elixir:

- **Automatic batching** with configurable sizes
- **Built-in backpressure** from producers to consumers
- **Partitioning** for parallel processing
- **Rate limiting** to protect downstream systems

```elixir
# Future: Broadway pipeline for high-throughput ingestion
defmodule Dash.Pipelines.Broadway do
  use Broadway

  def start_link(opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [module: {BroadwayKafka.Producer, [...]}],
      processors: [default: [concurrency: 10]],
      batchers: [
        timescale: [concurrency: 5, batch_size: 1000],
        bronze: [concurrency: 2, batch_size: 5000]
      ]
    )
  end

  def handle_message(_, message, _) do
    message
    |> Message.update_data(&apply_pipeline_mapping/1)
    |> Message.put_batcher(:timescale)
  end

  def handle_batch(:timescale, messages, _, _) do
    Dash.Data.PipelineData.insert_batch(messages)
    messages
  end
end
```

**When to adopt Broadway:**
- Single-node throughput exceeds 50k events/second
- Need complex windowing (e.g., "3 events in 10 minutes")
- Want to decouple ingestion from processing

### Not Using: Apache Flink

| Technology | Status | Reason |
|------------|--------|--------|
| **Apache Flink** | Not planned | Requires Java/Kafka/Zookeeper infrastructure; breaks single-binary deployment; Broadway handles our scale |
| **Apache Kafka** | Not planned (Phase 3 maybe) | Phoenix PubSub sufficient; adds operational complexity |
| **Apache Spark** | Not planned | Batch-oriented; Explorer/Arrow covers our analytics needs |

---

## Why NOT These Alternatives

| Rejected | Reason |
|----------|--------|
| **Umbrella Project** | Unnecessary complexity, slower compilation, harder refactoring |
| **React/Vue SPA** | Two codebases, API overhead, no real-time benefits |
| **Lit Components** | Added complexity, start simple with LiveView |
| **Cassandra/Scylla** | Overkill, TimescaleDB sufficient, SQL easier |
| **Rust for DB Layer** | Database is bottleneck, not Elixir; premature optimization |
| **Kubernetes** | Too complex initially, BEAM clustering sufficient |
| **Supabase/Pocketbase** | Can't handle custom pipeline logic, not for time-series |
| **Apache Flink** | Java ecosystem; Broadway provides similar capabilities natively |

---

