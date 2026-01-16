# Distributed Cluster Architecture

**Status**: 📋 Future Implementation (Phase 3 - Month 7+)
**Prerequisites**: MVP deployed, traffic validated, scaling needs confirmed

## Overview

This document describes the multi-node, distributed BEAM cluster architecture for Dash at production scale. This design supports global deployment with specialized node roles for optimal resource utilization.

⚠️ **DO NOT implement during Phase 1-2**. The MVP should run on a single Fly.io instance.

---

## High-Level Architecture

```mermaid
graph LR
    subgraph "External World"
        A[API Source]
        B[User Browser]
    end

    subgraph "Ingestion Layer (Bronze)"
        C(Phoenix Endpoint)
        D{Buffer GenServer}
    end

    subgraph "Persistence Layer (Silver)"
        E[(TimescaleDB Hypertable)]
    end

    subgraph "Presentation Layer (Gold)"
        F[Materialized View]
        G(LiveView Dashboard)
    end

    A -->|Webhook POST| C
    C -->|Cast| D
    D -->|Buffer (1s / 1000 items)| D
    D -->|Ash.Bulk Insert| E
    E -->|Refresh Policy| F
    F -->|PubSub Broadcast| G
    G -->|WebSocket Push| B
```

---

## Core Principles

The system is designed with three core principles:

1. **Fault Isolation**: Ingestion failures must never crash the user interface
2. **Write Efficiency**: Database writes are batched to prevent lock contention
3. **Location Transparency**: Nodes can be distributed globally while acting as a single cluster

---

## Cluster Topology & Node Roles

To maximize data processing efficiency and stability, Dash utilizes a **Heterogeneous Cluster** setup. Nodes are assigned specific roles via the `APP_ROLE` environment variable.

### A. Web Nodes (`role=web`)

**Responsibility**: Handle HTTP traffic, WebSocket connections, and Phoenix LiveView rendering.

**Scaling Metric**: Memory (RAM) usage

**Connectivity**: Public Internet (Ports 80/443)

**Behavior**:
- Subscribe to PubSub topics to receive data updates
- Perform no heavy data processing
- Render dashboards and serve user requests
- Auto-scale based on HTTP request queue depth

**Configuration**:
```elixir
# config/runtime.exs
if System.get_env("APP_ROLE") == "web" do
  config :dash,
    oban_queues: [],  # No job processing
    buffer_servers: []  # No ingestion buffers
end
```

---

### B. Ingestor Nodes (`role=ingestor`)

**Responsibility**: Run Oban jobs, GenServer buffers, and data transformations

**Scaling Metric**: CPU usage

**Connectivity**: Private mesh network only (No public HTTP)

**Behavior**:
- Accept webhook data and process it
- Run scheduled pipeline polling jobs
- Write to database via buffered batches
- Broadcast updates to Web nodes via PubSub

**Configuration**:
```elixir
# config/runtime.exs
if System.get_env("APP_ROLE") == "ingestor" do
  config :dash, DashWeb.Endpoint,
    http: false  # No HTTP server

  config :dash,
    oban_queues: [default: 10, pipelines: 20, mailers: 5],
    buffer_servers: [enabled: true, partitions: 10]
end
```

---

## Communication Patterns

### Internal DNS Discovery

Utilize `dns_cluster` for automatic node discovery. On Fly.io, this leverages internal IPv6 DNS to form a full mesh network.

**Configuration**:
```elixir
# config/runtime.exs
if config_env() == :prod do
  config :dash, DNSCluster,
    query: System.get_env("DNS_CLUSTER_QUERY") || :ignore,
    interval: 5_000
end
```

**Fly.io Setup**:
```bash
# fly.toml
[env]
  DNS_CLUSTER_QUERY = "dash.internal"
  RELEASE_NODE = "dash@${FLY_PRIVATE_IP}"
```

---

### Distributed PubSub

Dash uses `Phoenix.PubSub` over the standard `pg` (process group) adapter for cluster-wide message broadcasting.

**Channel**: `dash:pipelines`
**Topic**: `pipeline:{pipeline_id}`
**Payload**: `{:data_updated, %{count: 123, last_event: ...}}`

**Example Flow**:
1. Ingestor node in `iad` (US-East) receives webhook
2. Buffers and writes to database
3. Broadcasts `{:data_updated, ...}` to PubSub
4. Web node in `fra` (Europe) receives broadcast instantly
5. Web node pushes update to user's browser via LiveView

**Code Example**:
```elixir
# In BufferServer (Ingestor node)
defp notify_dashboard_update(pipeline_id, stats) do
  Phoenix.PubSub.broadcast(
    Dash.PubSub,
    "pipeline:#{pipeline_id}",
    {:data_updated, stats}
  )
end

# In LiveView (Web node)
def mount(%{"id" => pipeline_id}, _session, socket) do
  Phoenix.PubSub.subscribe(Dash.PubSub, "pipeline:#{pipeline_id}")
  {:ok, socket}
end

def handle_info({:data_updated, stats}, socket) do
  {:noreply, assign(socket, :stats, stats)}
end
```

---

## Deployment Strategy

### Fly.io Multi-Region Setup

**Web Nodes**: Deploy close to users
```bash
# Primary regions (Web nodes)
fly scale count 2 --region iad  # US-East
fly scale count 1 --region fra  # Europe
fly scale count 1 --region syd  # Australia
```

**Ingestor Nodes**: Deploy close to database
```bash
# Ingestor region (co-located with DB)
fly scale count 3 --region iad --process=ingestor
```

**App Configuration** (`fly.toml`):
```toml
[processes]
  web = "bin/dash start"
  ingestor = "bin/dash start"

[env]
  PHX_HOST = "dash.example.com"

[[services]]
  processes = ["web"]

  [[services.ports]]
    handlers = ["http"]
    port = 80

  [[services.ports]]
    handlers = ["tls", "http"]
    port = 443

# Ingestor nodes don't expose HTTP
```

---

## Monitoring & Observability

### Node Health Checks

**Web Nodes**:
- HTTP `/health` endpoint
- WebSocket connection count
- Memory usage

**Ingestor Nodes**:
- Oban job queue depth
- BufferServer queue lengths
- CPU utilization

### Metrics to Track

| Metric | Alert Threshold | Action |
|--------|----------------|--------|
| Web node memory | > 80% | Scale horizontally |
| Ingestor CPU | > 70% sustained | Add ingestor nodes |
| Oban queue depth | > 1000 jobs | Investigate slow jobs |
| BufferServer backlog | > 5000 messages | Trigger backpressure |
| PubSub latency | > 500ms | Check network mesh |

---

## Migration Path from MVP

### Phase 1-2: Single Node (Current)
```
[Single Fly.io Instance]
  ├── Phoenix Endpoint
  ├── LiveView
  ├── Oban Workers
  └── Database Connection
```

### Phase 3: Add Ingestor Role
```
[Web Node]              [Ingestor Node]
  ├── Phoenix              ├── Oban
  ├── LiveView             ├── BufferServers
  └── PubSub Subscribe     └── PubSub Broadcast
```

### Migration Steps

1. **Deploy ingestor node** with `APP_ROLE=ingestor`
2. **Verify clustering** via `Node.list()` in remote console
3. **Test PubSub** message delivery between nodes
4. **Gradually migrate** Oban queues to ingestor-only
5. **Disable HTTP** on ingestor nodes
6. **Monitor and tune** queue distribution

---

## Cost Analysis

### Single Node (Phase 1-2)
- **1x Fly.io Shared CPU** (1GB RAM): ~$7/month
- **Total**: ~$7/month

### Distributed Cluster (Phase 3)
- **4x Web nodes** (512MB RAM): ~$12/month
- **2x Ingestor nodes** (1GB RAM): ~$14/month
- **Total**: ~$26/month

**When to upgrade**: When single node CPU consistently > 60% or user latency > 200ms

---

## Security Considerations

### Private Mesh Network
- Ingestor nodes should NEVER be publicly accessible
- Use Fly.io private networking (6PN) for inter-node communication
- Web nodes are the only public-facing entry points

### Node Authentication
```elixir
# Require secure cookie for clustering
config :dash,
  release_cookie: System.fetch_env!("RELEASE_COOKIE")
```

Generate secure cookie:
```bash
openssl rand -base64 32
# Set as RELEASE_COOKIE secret
```

---

## References

- [Distributed Erlang (BEAM)](https://www.erlang.org/doc/reference_manual/distributed.html)
- [Phoenix PubSub](https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html)
- [Fly.io Clustering](https://fly.io/docs/elixir/the-basics/clustering/)
- [libcluster DNS](https://hexdocs.pm/libcluster/Cluster.Strategy.DNSPoll.html)

---

**Implementation Timeline**: Phase 3 (Month 7-9)
**Estimated Effort**: 2-3 weeks
**Risk Level**: Medium (requires careful testing of clustering)
**Dependencies**: MVP deployed, traffic patterns validated
