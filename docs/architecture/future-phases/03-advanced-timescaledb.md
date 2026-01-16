# Advanced TimescaleDB Features

**Status**: 📋 Future Implementation (Phase 3 - Month 8+)
**Prerequisites**: Hypertables created, significant data volume (>10M rows)

## Overview

This document describes advanced TimescaleDB features for production-scale time-series data management: continuous aggregates, compression policies, and retention management.

⚠️ **DO NOT implement during Phase 1-2**. Create basic hypertables only. Add these optimizations when you have real data volume.

---

## Phase 1-2: Basic Hypertable (Implement This First)

### Simple Pipeline Events Table

```elixir
# priv/repo/migrations/XXXXXX_create_pipeline_events.exs
defmodule Dash.Repo.Migrations.CreatePipelineEvents do
  use Ecto.Migration

  def up do
    create table(:pipeline_events, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :pipeline_id, :uuid, null: false
      add :team_id, :uuid, null: false
      add :data, :jsonb, null: false
      add :ingested_at, :utc_datetime_usec, null: false
    end

    # Convert to hypertable
    execute """
    SELECT create_hypertable(
      'pipeline_events',
      'ingested_at',
      chunk_time_interval => INTERVAL '1 day'
    )
    """

    # Basic indexes
    create index(:pipeline_events, [:pipeline_id, :ingested_at])
    create index(:pipeline_events, [:team_id])
    create index(:pipeline_events, [:data], using: :gin)
  end

  def down do
    drop table(:pipeline_events)
  end
end
```

**Stop here for MVP**. The above is sufficient for Phase 1-2.

---

## Phase 3+: Analytical Views (The Gold Layer)

### Problem with Direct Queries

```elixir
# Dashboard query - SLOW on millions of rows
query = from e in Event,
  where: e.pipeline_id == ^pipeline_id,
  where: e.ingested_at > ago(24, "hour"),
  select: %{
    hour: fragment("date_trunc('hour', ?)", e.ingested_at),
    count: count(e.id)
  },
  group_by: 1

Repo.all(query)  # Scans millions of rows every time!
```

**Issues at Scale**:
- Full table scan on every dashboard load
- Aggregations computed from scratch
- Slow query times (>5 seconds)
- High database CPU usage

### Solution: Continuous Aggregates

Pre-compute hourly rollups automatically:

```sql
-- Migration: Create continuous aggregate
CREATE MATERIALIZED VIEW pipeline_stats_1h
WITH (timescaledb.continuous) AS
SELECT
  time_bucket('1 hour', ingested_at) AS bucket,
  pipeline_id,
  team_id,
  COUNT(*) as event_count,
  SUM(pg_column_size(data)) as total_bytes,
  percentile_cont(0.5) WITHIN GROUP (ORDER BY pg_column_size(data)) as median_size
FROM pipeline_events
GROUP BY bucket, pipeline_id, team_id;
```

**Now query the view** (instant results):
```elixir
query = from s in "pipeline_stats_1h",
  where: s.pipeline_id == ^pipeline_id,
  where: s.bucket > ago(24, "hour"),
  select: %{hour: s.bucket, count: s.event_count}

Repo.all(query)  # Returns in <50ms
```

---

## Compression Policies

### Why Compress?

- Pipeline events table grows quickly (1M rows/day = 365M/year)
- Older data rarely queried but takes storage
- Compression reduces storage by 90-95%
- Compressed data still queryable (transparent decompression)

### When to Compress

Compress data older than **7 days** (hot data stays uncompressed):

```sql
-- Migration: Add compression policy
SELECT add_compression_policy(
  'pipeline_events',
  INTERVAL '7 days'
);
```

**What this does**:
- Data < 7 days old: Uncompressed (fast writes)
- Data > 7 days old: Compressed automatically
- Compression runs daily in background
- No application code changes needed

### Compression Results

**Before Compression**:
```
# Pipeline events table
1 million rows = ~500 MB disk space
```

**After Compression**:
```
# Same 1 million rows
Compressed = ~25 MB disk space (95% reduction)
```

**Query Performance**:
- Recent data (<7 days): Same speed (uncompressed)
- Old data (>7 days): Slightly slower (decompression overhead)
- Acceptable for analytics (not transactional queries)

---

## Retention Policies

### Automatic Data Deletion

Per-pipeline retention without expensive `DELETE` queries:

```sql
-- Migration: Add retention policy
-- Delete data older than 90 days
SELECT add_retention_policy(
  'pipeline_events',
  INTERVAL '90 days'
);
```

**How it works**:
- TimescaleDB stores data in "chunks" (1 day per chunk)
- Retention policy **drops entire chunks** by unlinking files
- No row-by-row deletion (instant, no table scan)
- Runs in background, zero downtime

### Per-Pipeline Retention (Advanced)

Allow users to configure retention per pipeline:

```elixir
# pipelines table
field :retention_days, :integer, default: 90

# Custom job to update policies
defmodule Dash.Workers.UpdateRetentionPolicies do
  def perform do
    for pipeline <- Repo.all(Pipeline) do
      case pipeline.retention_days do
        nil ->
          # Indefinite retention
          Repo.query("""
          SELECT remove_retention_policy('pipeline_events')
          WHERE EXISTS (
            SELECT 1 FROM timescaledb_information.jobs
            WHERE proc_name = 'policy_retention'
          )
          """)

        days ->
          # Set retention
          Repo.query("""
          SELECT add_retention_policy(
            'pipeline_events',
            INTERVAL '#{days} days',
            if_not_exists => true
          )
          """)
      end
    end
  end
end
```

---

## Read Replica Configuration

### Problem: Write/Read Contention

- Ingestion writes compete with dashboard reads
- Both use same connection pool
- High write volume slows read queries

### Solution: Separate Pools

```elixir
# config/config.exs

# Write pool (smaller, optimized for writes)
config :dash, Dash.Repo,
  pool_size: 20,
  queue_target: 5000,
  queue_interval: 1000

# Read pool (larger, optimized for reads)
config :dash, Dash.Repo.Replica,
  pool_size: 50,
  queue_target: 5000,
  queue_interval: 1000,
  priv: "priv/repo"  # Share migrations
```

```elixir
# lib/dash/repo/replica.ex
defmodule Dash.Repo.Replica do
  use Ecto.Repo,
    otp_app: :dash,
    adapter: Ecto.Adapters.Postgres,
    read_only: true  # Prevent accidental writes
end
```

### Usage Pattern

```elixir
# Writes go to main repo
Dash.Repo.insert_all("pipeline_events", events)

# Reads go to replica
Dash.Repo.Replica.all(from e in Event, ...)
```

### Deployment

**Phase 3 (Month 8)**: Point to same database initially
```bash
# Both use same DATABASE_URL
DATABASE_URL=ecto://...
DATABASE_REPLICA_URL=ecto://...  # Same as above
```

**Phase 4 (Month 10+)**: Split to actual read replica
```bash
# Separate databases
DATABASE_URL=ecto://primary.example.com/dash
DATABASE_REPLICA_URL=ecto://replica.example.com/dash
```

---

## Continuous Aggregate Refresh Policies

### Automatic Refresh

Keep the materialized view up-to-date:

```sql
SELECT add_continuous_aggregate_policy(
  'pipeline_stats_1h',
  start_offset => INTERVAL '3 hours',
  end_offset => INTERVAL '1 hour',
  schedule_interval => INTERVAL '1 hour'
);
```

**What this means**:
- Refresh hourly
- Refresh window: 3 hours ago → 1 hour ago
- Allows 1 hour for late-arriving data
- Most recent hour refreshed next cycle

### Real-Time Aggregates

For dashboards that need latest data:

```sql
CREATE MATERIALIZED VIEW pipeline_stats_1h
WITH (
  timescaledb.continuous,
  timescaledb.materialized_only = false  -- Enable real-time aggregation
) AS ...
```

**Trade-off**:
- Real-time view: Queries combine materialized + fresh data (slower)
- Materialized-only: Queries use only pre-computed data (faster, but stale)

**Recommendation**: Use materialized-only for MVP, add real-time in Phase 4.

---

## Implementation Migration Path

### Current State (Phase 1-2)
```
[Pipeline Events Hypertable]
  ├── No compression
  ├── No retention
  ├── No continuous aggregates
  └── Direct queries from dashboards
```

### Phase 3 (Month 8)
```
[Pipeline Events Hypertable]
  ├── ✅ Compression policy (7 days)
  ├── ✅ Retention policy (90 days default)
  ├── ✅ Continuous aggregate (1 hour buckets)
  └── ✅ Dashboards query aggregates
```

### Phase 4 (Month 10+)
```
[Primary DB]                    [Read Replica]
  ├── Writes                      ├── Dashboard reads
  ├── Compression                 ├── API queries
  └── Retention                   └── Exports
```

---

## When to Implement Each Feature

| Feature | Trigger | Phase | Effort |
|---------|---------|-------|--------|
| **Hypertable** | MVP start | 1-2 | 1 day |
| **Compression** | >1M rows/day | 3 | 2 hours |
| **Retention** | Storage costs concern | 3 | 2 hours |
| **Continuous Aggregates** | Dashboard queries >1sec | 3 | 1 week |
| **Read Replica (same DB)** | Write/read contention | 3 | 1 day |
| **Read Replica (separate DB)** | CPU consistently >70% | 4 | 1 week |

---

## Cost Impact

### Storage Costs (Monthly)

**Without Compression/Retention**:
```
1M events/day × 30 days × 500 bytes = 15 GB/month
```

**With Compression + 90-day Retention**:
```
Hot data (7 days): 3.5 GB uncompressed
Cold data (83 days): 41.5 GB × 5% = 2 GB compressed
Total: ~5.5 GB/month (63% reduction)
```

**Fly.io Volumes Pricing**:
- 15 GB × $0.15/GB = $2.25/month (without optimization)
- 5.5 GB × $0.15/GB = $0.83/month (with optimization)
- **Savings: $1.42/month per pipeline**

---

## References

- [TimescaleDB Continuous Aggregates](https://docs.timescale.com/use-timescale/latest/continuous-aggregates/)
- [TimescaleDB Compression](https://docs.timescale.com/use-timescale/latest/compression/)
- [TimescaleDB Data Retention](https://docs.timescale.com/use-timescale/latest/data-retention/)
- [Ecto Read Replicas](https://hexdocs.pm/ecto/replicas-and-dynamic-repositories.html)

---

**Implementation Timeline**: Phase 3 (Month 8-9)
**Estimated Effort**: 2 weeks
**Risk Level**: Low (TimescaleDB handles heavy lifting)
**Dependencies**: Significant data volume, observed performance issues
