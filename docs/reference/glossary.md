## Glossary

**Backpressure:** System mechanism to prevent OOM crashes by rejecting requests when GenServer mailbox exceeds thresholds

**BEAM:** The Erlang virtual machine that runs Elixir code

**Bronze Layer:** Raw data lake storing original JSONL files in object storage before transformation

**Data Lake:** Object storage (S3/R2) containing raw pipeline data for replay and audit

**ETS:** Erlang Term Storage - in-memory key-value store

**GenServer:** Generic server behavior in Elixir for stateful processes

**Heterogeneous Clustering:** BEAM cluster architecture with specialized node roles (web vs ingestor)

**Hypertable:** TimescaleDB's abstraction for time-series data

**Ingestor Node:** BEAM node optimized for CPU, running pipeline workers and Oban jobs (APP_ROLE=ingestor)

**LiveView:** Phoenix framework for real-time server-rendered UIs

**Medallion Architecture:** Multi-tiered data storage strategy (Bronze/Silver layers) for durability and performance

**Multi-tenancy:** Architecture where multiple customers (teams) share infrastructure but data is isolated

**Oban:** Background job processing library for Elixir

**Pipeline:** User-configured data flow from source to destination

**PubSub:** Publish-subscribe messaging pattern for real-time updates

**Replay Engine:** System that reprocesses Bronze layer data through updated pipeline mappings

**Silver Layer:** Structured metric store in TimescaleDB optimized for fast dashboard queries

**Sink:** Destination where pipeline data is sent (email, Slack, API, etc.)

**Source:** Origin of data for a pipeline (API, webhook, database, etc.)

**Supervision Tree:** Elixir's fault-tolerance mechanism

**Web Node:** BEAM node optimized for RAM, serving HTTP and LiveView (APP_ROLE=web)

**Widget:** Visualization component on a dashboard (chart, table, etc.)

---

