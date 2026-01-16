# Future Architecture Documentation

**Status**: 📋 Planning Documents for Phase 3-4 (Months 7-12+)

## Purpose

This directory contains advanced architectural designs and implementation patterns for **future phases** of Dash development. These documents describe production-scale, distributed systems features that will be implemented **after** the MVP is complete and validated.

## Important Notes

⚠️ **DO NOT implement these patterns during Phase 1-2 (Weeks 1-8)**

These documents represent the vision for a mature, high-scale production system. Implementing them prematurely will:
- Add unnecessary complexity to the MVP
- Slow down initial development
- Create maintenance burden before product-market fit
- Violate YAGNI (You Aren't Gonna Need It) principle

## Current Phase vs. Future Architecture

| Feature | Phase 1-2 MVP (Now) | Phase 3-4 Future (These Docs) |
|---------|-------------------|-------------------------------|
| **Deployment** | Single-node Fly.io instance | Multi-region distributed cluster |
| **Ingestion** | Simple Oban jobs, direct writes | BufferServer GenServers with backpressure |
| **Node Topology** | Monolithic | Heterogeneous (Web + Ingestor roles) |
| **Transformations** | Basic field mapping in Oban worker | Ash Reactor declarative DSL |
| **TimescaleDB** | Hypertables only | Continuous aggregates, compression, retention |
| **Clustering** | None | Full BEAM mesh with DNS discovery |
| **Self-Hosting** | N/A | Binary compilation, license enforcement |

## When to Implement These Patterns

### Phase 1-2: Foundation (Weeks 1-8) - **Current**
- ✅ Basic CRUD with Ash Framework
- ✅ Simple polling pipelines via Oban
- ✅ TimescaleDB hypertables for storage
- ✅ LiveView dashboards with basic queries
- ✅ Single-node deployment to Fly.io

### Phase 3: Growth & Scale (Months 7-9) - **Refer to These Docs**
- 📋 BufferServer for high-throughput ingestion
- 📋 Distributed clustering with node roles
- 📋 Continuous aggregates for analytics
- 📋 Compression & retention policies
- 📋 Multi-region deployment

### Phase 4: Enterprise (Months 10-12) - **Advanced Patterns**
- 📋 Self-hosted deployment with Burrito
- 📋 License enforcement system
- 📋 White-label capabilities
- 📋 SOC 2 compliance infrastructure

## Document Index

1. **[01-distributed-architecture.md](01-distributed-architecture.md)**
   - Multi-node BEAM clustering
   - Heterogeneous topology (Web vs Ingestor nodes)
   - DNS discovery and PubSub patterns
   - **Implement in**: Phase 3 (Month 7+)

2. **[02-buffered-ingestion.md](02-buffered-ingestion.md)**
   - GenServer-based buffering system
   - Backpressure and rate limiting
   - Batch insert optimization
   - **Implement in**: Phase 3 (Month 7+)

3. **[03-advanced-timescaledb.md](03-advanced-timescaledb.md)**
   - Continuous aggregates (Gold layer)
   - Compression policies
   - Retention management
   - Read replica strategy
   - **Implement in**: Phase 3 (Month 8+)

4. **[04-transformation-engine.md](04-transformation-engine.md)**
   - Ash Reactor integration
   - Declarative transformation DSL
   - Dead Letter Queue (DLQ) handling
   - **Implement in**: Phase 3 (Month 9+)

5. **[05-self-hosted-deployment.md](05-self-hosted-deployment.md)**
   - Binary compilation with Burrito
   - License key enforcement
   - Enterprise deployment strategy
   - **Implement in**: Phase 4 (Month 10+)

6. **[CONTRIBUTING-advanced.md](CONTRIBUTING-advanced.md)**
   - Advanced coding standards
   - Type system usage (Elixir 1.20+)
   - Performance guidelines
   - Security policies
   - **Enforce when**: Phase 3+

## How to Use These Documents

### During Phase 1-2 (Current)
- ❌ Don't implement
- ✅ Read for context and understanding
- ✅ Design current code to not conflict with future patterns
- ✅ Keep in mind when making architectural decisions

### Example: Pipeline Ingestion

**Phase 1-2 (Simple)**:
```elixir
# In Oban worker - direct database write
defmodule Dash.Workers.PipelinePoller do
  use Oban.Worker

  def perform(%{args: %{"pipeline_id" => id}}) do
    data = fetch_from_api(id)

    # Simple, direct write
    Ash.create!(Dash.Pipelines.Event, %{
      pipeline_id: id,
      payload: data
    })
  end
end
```

**Phase 3+ (Buffered - from future docs)**:
```elixir
# Send to BufferServer for batching
GenServer.cast(
  {:via, PartitionSupervisor, {BufferServer, pipeline_id}},
  {:buffer_event, payload}
)
```

### When You're Ready to Implement

1. **Validate need first**: Do you have actual traffic that requires these optimizations?
2. **Read the specific document**: Understand the full pattern
3. **Plan migration**: How to transition from simple → advanced
4. **Implement incrementally**: One subsystem at a time
5. **Measure impact**: Validate the optimization actually helps

## Key Principle: YAGNI (You Aren't Gonna Need It)

> "Always implement things when you actually need them, never when you just foresee that you need them."
> — Martin Fowler

These documents exist to:
- ✅ Preserve research and design thinking
- ✅ Guide future implementation when scale demands it
- ✅ Ensure current code doesn't paint us into a corner

They DO NOT exist to:
- ❌ Guide current MVP development
- ❌ Be implemented before product-market fit
- ❌ Add complexity before it's needed

## Questions?

If you're unsure whether to implement a pattern from these docs:

1. **Ask**: "Will the MVP fail without this?"
   - If NO → defer to Phase 3+
   - If YES → it might belong in Phase 1-2

2. **Check the roadmap**: [docs/business/roadmap.md](../../business/roadmap.md)
   - What phase are you in?
   - What are the current deliverables?

3. **Prioritize shipping**: Working software > perfect architecture

---

**Last Updated**: 2026-01-16
**Status**: Draft - Not Yet Implemented
**Target Implementation**: Phase 3+ (Month 7+)
