# Dash Documentation

Welcome to the Dash project documentation.

## Quick Links

### For Developers
Start here: [Architecture Overview](technical/01-architecture.md)

### For Product/Business
Start here: [Use Cases](business/use-cases.md)

### For DevOps
Start here: [Deployment Strategy](technical/07-deployment.md) | [Error Logging & Monitoring](technical/09-error-logging.md)

### For Enterprise Customers
Start here: [Self-Hosted Overview](business/self-hosted.md)

## Documentation Structure

### Technical Documentation (`technical/`)

**Core Architecture:**
1. [Architecture Overview](technical/01-architecture.md) - System design, components, data flow
2. [Technology Stack](technical/02-tech-stack.md) - Technology choices and rationale
3. [Database Design](technical/03-database.md) - Schemas, TimescaleDB, multi-tenancy

**System Implementation:**
4. [Pipeline System](technical/04-pipelines.md) - Data pipeline architecture and workers
5. [Dashboard System](technical/05-dashboards.md) - LiveView dashboards and widgets
6. [Security](technical/06-security.md) - Authentication, authorization, encryption

**Deployment & Operations:**
7. [Cloud Deployment](technical/07-deployment.md) - Fly.io deployment for SaaS
8. [Self-Hosted Deployment](technical/08-self-hosted-deployment.md) - Docker/Kubernetes for enterprise
9. [Error Logging & Monitoring](technical/09-error-logging.md) - Error tracking, logging, observability

### Business Documentation (`business/`)

**Market & Strategy:**
- [Use Cases](business/use-cases.md) - 7 real-world scenarios with ROI calculations
- [Pricing & Monetization](business/pricing.md) - Pricing tiers, Stripe integration, usage limits
- [Self-Hosted Strategy](business/self-hosted.md) - Enterprise self-hosted business case and revenue
- [Marketing Strategy](business/marketing.md) - Target customers, GTM, channels, budget

**Planning:**
- [Development Roadmap](business/roadmap.md) - 24-week phase-by-phase implementation plan

### Reference (`reference/`)

- [Decision Records](reference/decisions.md) - Architecture Decision Records (ADRs)
- [Glossary](reference/glossary.md) - Terms, acronyms, and definitions

### Diagrams (`diagrams/`)

- `system-architecture.mmd` - Complete system overview (Mermaid)
- `data-flow.mmd` - Sequence diagram of data movement
- `scaling-phases.mmd` - Architecture evolution across phases
- `pipeline-execution.mmd` - Pipeline worker flowchart

## How to Use This Documentation

### First Time Reading?

**Option 1: Technical Focus**
1. Start: [Architecture Overview](technical/01-architecture.md)
2. Then: [Technology Stack](technical/02-tech-stack.md)
3. Next: [Database Design](technical/03-database.md)
4. Continue through technical docs in order

**Option 2: Business Focus**
1. Start: [Use Cases](business/use-cases.md)
2. Then: [Pricing Strategy](business/pricing.md)
3. Next: [Marketing Strategy](business/marketing.md)
4. Finally: [Development Roadmap](business/roadmap.md)

**Option 3: Implementation Focus**
1. Start: [Development Roadmap](business/roadmap.md)
2. Then: [Architecture Overview](technical/01-architecture.md)
3. Next: Pick relevant technical docs for current phase

### Looking for Something Specific?

**"How do pipelines work?"**
→ [Pipeline System](technical/04-pipelines.md)

**"How do I deploy to production?"**
→ Cloud: [Deployment](technical/07-deployment.md)  
→ Self-hosted: [Self-Hosted Deployment](technical/08-self-hosted-deployment.md)

**"How do I monitor errors and debug issues?"**
→ [Error Logging & Monitoring](technical/09-error-logging.md)

**"What's the business model?"**
→ [Pricing Strategy](business/pricing.md)  
→ [Self-Hosted Strategy](business/self-hosted.md)

**"Who are the target customers?"**
→ [Marketing Strategy](business/marketing.md)  
→ [Use Cases](business/use-cases.md)

**"Why did we choose technology X?"**
→ [Decision Records](reference/decisions.md)

**"What does term X mean?"**
→ [Glossary](reference/glossary.md)

## Documentation by Role

### Software Engineer
**Must Read:**
- [Architecture Overview](technical/01-architecture.md)
- [Technology Stack](technical/02-tech-stack.md)
- [Database Design](technical/03-database.md)
- [Pipeline System](technical/04-pipelines.md) OR [Dashboard System](technical/05-dashboards.md)

**Reference:**
- [Security](technical/06-security.md)
- [Error Logging & Monitoring](technical/09-error-logging.md)
- [Decision Records](reference/decisions.md)
- [Glossary](reference/glossary.md)

### Product Manager
**Must Read:**
- [Use Cases](business/use-cases.md)
- [Development Roadmap](business/roadmap.md)
- [Pricing Strategy](business/pricing.md)

**Reference:**
- [Architecture Overview](technical/01-architecture.md) (high-level)
- [Marketing Strategy](business/marketing.md)

### DevOps / SRE
**Must Read:**
- [Cloud Deployment](technical/07-deployment.md)
- [Self-Hosted Deployment](technical/08-self-hosted-deployment.md)
- [Error Logging & Monitoring](technical/09-error-logging.md)
- [Database Design](technical/03-database.md) (scaling sections)
- [Security](technical/06-security.md)

**Reference:**
- [Architecture Overview](technical/01-architecture.md)
- [Technology Stack](technical/02-tech-stack.md)

### Sales / Business Development
**Must Read:**
- [Use Cases](business/use-cases.md)
- [Pricing Strategy](business/pricing.md)
- [Self-Hosted Strategy](business/self-hosted.md)
- [Marketing Strategy](business/marketing.md)

**Reference:**
- [Architecture Overview](technical/01-architecture.md) (for technical discussions)

### Customer Success / Support
**Must Read:**
- [Use Cases](business/use-cases.md)
- [Self-Hosted Deployment](technical/08-self-hosted-deployment.md) (troubleshooting)
- [Error Logging & Monitoring](technical/09-error-logging.md) (debugging customer issues)

**Reference:**
- [Glossary](reference/glossary.md)
- [Security](technical/06-security.md)

## Updating Documentation

### Adding New Features

When adding a feature:
1. Update relevant technical doc (04-pipelines.md, 05-dashboards.md, etc.)
2. Add to [Development Roadmap](business/roadmap.md) if not already there
3. Update [Glossary](reference/glossary.md) if new terms introduced
4. Consider adding a use case to [Use Cases](business/use-cases.md)

### Making Architecture Decisions

When making a major decision:
1. Document in [Decision Records](reference/decisions.md)
2. Update relevant technical documentation
3. Update diagrams if architecture changes

### Deployment Changes

When changing deployment:
1. Update [Cloud Deployment](technical/07-deployment.md) or [Self-Hosted](technical/08-self-hosted-deployment.md)
2. Update scripts and configuration examples
3. Add troubleshooting section if new issues might arise
4. Update [Error Logging & Monitoring](technical/09-error-logging.md) if monitoring changes

### Adding Error Tracking / Monitoring

When adding new error tracking or monitoring:
1. Update [Error Logging & Monitoring](technical/09-error-logging.md)
2. Update environment variables in main README
3. Add alert configuration examples
4. Document common error patterns

## Documentation Standards

### File Naming
- Use lowercase with hyphens: `my-document.md`
- Number technical docs: `01-architecture.md`
- Group by category: `technical/`, `business/`, `reference/`

### Content Structure
- Start with overview/summary
- Use clear headings (H2, H3)
- Include code examples where relevant
- Add diagrams for complex concepts
- End with "Next Steps" or "See Also"

### Cross-References
- Link to related docs: `[Pipeline System](technical/04-pipelines.md)`
- Link to specific sections: `[Database Schema](technical/03-database.md#schema)`
- Use relative paths (not absolute URLs)

### Code Examples
- Use proper syntax highlighting (```elixir, ```bash, etc.)
- Include comments explaining key parts
- Provide working, tested examples
- Show both correct and incorrect approaches when helpful

### Diagrams
- Use Mermaid format (renders on GitHub)
- Store in `diagrams/` directory
- Include diagram source in technical docs
- Provide text description for accessibility

## Maintenance

### Regular Updates
- **Weekly:** Review open issues/PRs that affect docs
- **Monthly:** Check for outdated information
- **Quarterly:** Full documentation audit
- **Per release:** Update roadmap, deployment guides

### Documentation Debt
Track documentation TODOs:
- Missing sections marked with `> TODO:`
- Placeholder content marked with `> PLACEHOLDER`
- Update issues tagged with `documentation` label

## Production Readiness Checklist

Before deploying to production, ensure documentation covers:
- ✅ [Error tracking and monitoring](technical/09-error-logging.md) is configured
- ✅ [Deployment procedures](technical/07-deployment.md) are documented
- ✅ [Security measures](technical/06-security.md) are in place
- ✅ [Database backup/restore](technical/03-database.md) procedures documented
- ✅ Runbooks for common incidents created
- ✅ On-call procedures documented

## Getting Help

### Documentation Issues
- Found an error? [Open an issue](https://github.com/YOUR_USERNAME/dash/issues)
- Unclear section? [Start a discussion](https://github.com/YOUR_USERNAME/dash/discussions)
- Want to contribute? See [Contributing](../README.md#contributing)

### Content Questions
- Technical questions: Ask in engineering channel
- Business questions: Ask product team
- Deployment questions: Ask DevOps team
- Error tracking questions: See [Error Logging & Monitoring](technical/09-error-logging.md)

---

**Last Updated:** January 2026  
**Maintained By:** Dash Development Team  

**Quick Stats:**
- Technical Docs: 9 files
- Business Docs: 5 files
- Reference: 2 files
- Diagrams: 4 files
- **Total Pages:** ~220+ pages of documentation