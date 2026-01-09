# Dash Documentation

Welcome to the Dash project documentation.

## Quick Links

### For Developers
Start here: [Architecture Overview](technical/01-architecture.md)

### For Product/Business
Start here: [Use Cases](business/use-cases.md)

### For DevOps
Start here: [Deployment Strategy](technical/07-deployment.md)

## Documentation Structure

- **technical/** - Technical specifications and architecture
- **business/** - Business strategy and planning
- **reference/** - Glossary and decision records
- **diagrams/** - Visual diagrams (Mermaid format)

## How to Use This Documentation

1. **First time?** Read the [Architecture Overview](technical/01-architecture.md)
2. **Want to understand tech choices?** See [Technology Stack](technical/02-tech-stack.md)
3. **Need to implement a feature?** Check the relevant technical doc
4. **Want to understand the business?** Review [Use Cases](business/use-cases.md)

## Updating Documentation

To populate the placeholder files:
1. Copy sections from `DASH_TECHNICAL_PLAN.md`
2. Paste into the appropriate file
3. Commit changes

Or use the split script:
```bash
./split-docs.sh DASH_TECHNICAL_PLAN.md
```
