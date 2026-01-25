## Glossary

**Backpressure:** System mechanism to prevent OOM crashes by rejecting requests when GenServer mailbox exceeds thresholds

**Adapter Pattern:** Implementation strategy where a module implements a Behaviour contract; enables swappable infrastructure (e.g., R2Adapter, LocalAdapter)

**Apache Arrow:** Columnar memory format for zero-copy data access; used by Explorer for high-performance data processing

**BEAM:** The Erlang virtual machine that runs Elixir code

**Behaviour:** Elixir's mechanism for defining contracts (like interfaces); used to abstract infrastructure layers for testability and portability

**Broadway:** Elixir library for building data pipelines with built-in batching, backpressure, and partitioning (future Phase 3+)

**Bronze Layer:** Raw data lake storing Parquet files in object storage before transformation

**Data Lake:** Object storage (S3/R2) containing raw pipeline data for replay and audit

**ETS:** Erlang Term Storage - in-memory key-value store

**Explorer:** Elixir library for DataFrame operations backed by Apache Arrow; used for high-performance data processing in replays

**GenServer:** Generic server behavior in Elixir for stateful processes

**Gridstack.js:** JavaScript library for drag-and-drop dashboard layouts; integrates with LiveView hooks (future Phase 3+)

**Heterogeneous Clustering:** BEAM cluster architecture with specialized node roles (web vs ingestor)

**Horde:** Elixir library for distributed process supervision using CRDTs; enables process migration on node failure (future Phase 3+)

**Hypertable:** TimescaleDB's abstraction for time-series data

**Ingestor Node:** BEAM node optimized for CPU, running pipeline workers and Oban jobs (APP_ROLE=ingestor)

**LiveView:** Phoenix framework for real-time server-rendered UIs

**Medallion Architecture:** Multi-tiered data storage strategy (Bronze/Silver layers) for durability and performance

**Multi-tenancy:** Architecture where multiple customers (teams) share infrastructure but data is isolated

**Nx:** Elixir's numerical computing library; foundation for Bumblebee machine learning

**Oban:** Background job processing library for Elixir

**OpenTelemetry:** Observability framework for distributed tracing across services; tracks requests across web and ingestor nodes

**Parquet:** Columnar file format optimized for analytics; used for Bronze layer storage (smaller, faster than JSONL)

**Phoenix Presence:** Built-in Phoenix feature for tracking connected users across distributed nodes; used for collaboration features

**Pipeline:** User-configured data flow from source to destination

**PubSub:** Publish-subscribe messaging pattern for real-time updates

**Replay Engine:** System that reprocesses Bronze layer data through updated pipeline mappings

**Silver Layer:** Structured metric store in TimescaleDB optimized for fast dashboard queries

**Sink:** Destination where pipeline data is sent (email, Slack, API, etc.)

**Source:** Origin of data for a pipeline (API, webhook, database, etc.)

**Supervision Tree:** Elixir's fault-tolerance mechanism

**Web Node:** BEAM node optimized for RAM, serving HTTP and LiveView (APP_ROLE=web)

**Vector:** High-performance data pipeline tool (Rust); used as sidecar for Bronze layer I/O offloading (future Phase 3+)

**Wasmex:** Elixir library for running WebAssembly; enables sandboxed user code execution (future Phase 4+)

**Widget:** Visualization component on a dashboard (chart, table, etc.)

**Y.js:** JavaScript CRDT library for real-time collaboration; used for conflict-free concurrent editing (future Phase 4+)

---

