# Dash - Data Pipeline & Dashboard Platform

![Elixir](https://img.shields.io/badge/elixir-1.16+-purple.svg)
![Phoenix](https://img.shields.io/badge/phoenix-1.7+-orange.svg)
![Status](https://img.shields.io/badge/status-development-blue)

## Overview

Dash is a configurable data pipeline and dashboard platform that enables users to:

- 📊 **Create data pipelines** from various sources (APIs, webhooks, databases)
- 🔄 **Transform data** with custom mappings and transformations
- 💾 **Persist data** with flexible retention policies
- 📈 **Visualize in real-time** with customizable dashboards
- 🔗 **Share dashboards** publicly or within teams
- 🚀 **Route data** to multiple destinations

## Technology Stack

- **Backend:** Elixir, Phoenix Framework, Ash Framework
- **Frontend:** Phoenix LiveView, Alpine.js, Tailwind CSS
- **Database:** PostgreSQL + TimescaleDB extension
- **Job Processing:** Oban
- **Deployment:** Fly.io (Cloud) or Self-Hosted (Docker/Kubernetes)
- **Payments:** Stripe (Cloud only)
- **Error Tracking:** Sentry
- **Logging:** Structured logging with Elixir Logger

## Documentation

### Technical Documentation
- [Architecture Overview](docs/technical/01-architecture.md) - System design and components
- [Technology Stack](docs/technical/02-tech-stack.md) - Technology choices & rationale
- [Database Design](docs/technical/03-database.md) - Schemas and data models
- [Pipeline System](docs/technical/04-pipelines.md) - Data pipeline architecture
- [Dashboard System](docs/technical/05-dashboards.md) - LiveView dashboards and widgets
- [Security](docs/technical/06-security.md) - Authentication, authorization, encryption
- [Deployment](docs/technical/07-deployment.md) - Cloud deployment (Fly.io)
- [Self-Hosted Deployment](docs/technical/08-self-hosted-deployment.md) - Enterprise self-hosted setup
- [Error Logging & Monitoring](docs/technical/09-error-logging.md) - Error tracking, logging, observability

### Business Documentation
- [Use Cases](docs/business/use-cases.md) - Real-world scenarios with ROI
- [Pricing & Monetization](docs/business/pricing.md) - Tiers, billing, Stripe integration
- [Self-Hosted Strategy](docs/business/self-hosted.md) - Enterprise self-hosted business case
- [Marketing Strategy](docs/business/marketing.md) - Target customers and GTM
- [Development Roadmap](docs/business/roadmap.md) - 24-week implementation plan

### Reference
- [Decision Records](docs/reference/decisions.md) - Architecture decisions (ADRs)
- [Glossary](docs/reference/glossary.md) - Terms and definitions

## Getting Started

### Prerequisites

- Elixir 1.16 or later
- Erlang/OTP 26 or later
- PostgreSQL 16 or later
- Node.js 18+ (for asset compilation)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/dash.git
   cd dash
   ```

2. **Install dependencies**
   ```bash
   mix deps.get
   cd assets && npm install && cd ..
   ```

3. **Set up the database**
   ```bash
   mix ecto.setup
   ```

4. **Start the Phoenix server**
   ```bash
   mix phx.server
   ```

5. **Visit** [`localhost:4000`](http://localhost:4000)

### Development Setup

1. **Copy environment variables**
   ```bash
   cp .env.example .env
   ```

2. **Configure database** (if not using defaults)
   - Edit `config/dev.exs`
   - Update database credentials

3. **Install TimescaleDB extension** (for time-series data)
   ```sql
   psql -U postgres -d dash_dev -c "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;"
   ```

4. **Run tests**
   ```bash
   mix test
   ```

## Deployment Options

### Cloud (SaaS)

**For most users:** Deploy to Fly.io

```bash
# Install flyctl
curl -L https://fly.io/install.sh | sh

# Launch app
fly launch

# Deploy
fly deploy

# Open app
fly open
```

See [Deployment Guide](docs/technical/07-deployment.md) for details.

### Self-Hosted (Enterprise)

**For organizations requiring data sovereignty:**

- Docker Compose (1-100 users)
- Kubernetes (100+ users)
- Air-gapped installation (government/secure environments)

See [Self-Hosted Deployment](docs/technical/08-self-hosted-deployment.md) and [Self-Hosted Business Case](docs/business/self-hosted.md) for details.

## Project Structure

```
dash/
├── assets/              # Frontend assets (CSS, JS)
├── config/              # Configuration files
├── docs/                # Project documentation
│   ├── technical/       # Technical specs
│   ├── business/        # Business docs
│   └── reference/       # Reference materials
├── lib/
│   ├── dash/            # Business logic
│   │   ├── accounts/    # User & team management
│   │   ├── pipelines/   # Pipeline system
│   │   ├── dashboards/  # Dashboard system
│   │   └── data/        # Time-series data layer
│   └── dash_web/        # Web interface
│       ├── live/        # LiveView modules
│       ├── controllers/ # Controllers
│       └── components/  # UI components
├── priv/
│   ├── repo/
│   │   └── migrations/  # Database migrations
│   └── static/          # Static assets
└── test/                # Tests
```

## Development Roadmap

### Phase 1: MVP (Weeks 1-8) - In Progress
- [x] Project initialization
- [x] Authentication (email/password + magic link)
- [x] Organization & team management with RBAC
- [x] LiveViews for org/team management
- [x] Application shell with navigation ✅ **COMPLETE**
  - [x] App and admin layouts with separate navigation
  - [x] Role-based routing
  - [x] Landing page and home page
- [ ] Basic pipeline creation (next)
- [ ] Simple dashboards
- [ ] Real-time updates

### Phase 2: Growth Features (Weeks 9-16)
- [ ] Webhook support
- [ ] Advanced transformations
- [ ] Data sinks
- [ ] Enhanced dashboards

### Phase 3: Monetization (Weeks 17-24)
- [ ] Usage tracking & limits
- [ ] Stripe integration
- [ ] Billing UI
- [ ] Performance optimization
- [ ] Self-hosted Docker images

See [Development Roadmap](docs/business/roadmap.md) for details.

## Available Commands

```bash
# Start development server
mix phx.server

# Start with IEx console
iex -S mix phx.server

# Run tests
mix test

# Run tests with coverage
mix test --cover

# Format code
mix format

# Check code quality
mix credo

# Database commands
mix ecto.create          # Create database
mix ecto.migrate         # Run migrations
mix ecto.rollback        # Rollback last migration
mix ecto.reset           # Drop, create, and migrate database

# Generate resources
mix phx.gen.live Accounts User users email:string name:string
```

## Environment Variables

Required environment variables (see `.env.example`):

```bash
# Database
DATABASE_URL=ecto://postgres:postgres@localhost/dash_dev

# Phoenix
SECRET_KEY_BASE=generate_with_mix_phx_gen_secret
PHX_HOST=localhost
PORT=4000

# Error Tracking (Sentry)
SENTRY_DSN=https://...@sentry.io/...

# Stripe (for billing - Phase 3)
STRIPE_PUBLIC_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...

# File Storage (Cloudflare R2)
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
```

Generate `SECRET_KEY_BASE`:
```bash
mix phx.gen.secret
```

## Pricing

### Cloud (SaaS)
- **Free:** $0 (3 pipelines, 1GB storage)
- **Pro:** $49/month (25 pipelines, 25GB storage)
- **Business:** $199/month (100 pipelines, 100GB storage)
- **Enterprise:** Custom pricing

### Self-Hosted
- **Starter:** $499/month (25 users, 50 pipelines)
- **Professional:** $1,999/month (100 users, unlimited pipelines)
- **Enterprise:** $4,999+/month (unlimited, white-label, 24/7 support)

See [Pricing Strategy](docs/business/pricing.md) for details.

## Contributing

1. Create a feature branch (`git checkout -b feature/amazing-feature`)
2. Commit your changes (`git commit -m 'Add amazing feature'`)
3. Push to branch (`git push origin feature/amazing-feature`)
4. Open a Pull Request

## Testing

```bash
# Run all tests
mix test

# Run specific test file
mix test test/dash/pipelines/pipeline_test.exs

# Run tests with coverage
mix test --cover

# Run tests in watch mode (requires mix_test_watch)
mix test.watch
```

## License

Proprietary - All Rights Reserved

## Support

- **Documentation:** [docs/](docs/)
- **Issues:** [GitHub Issues](https://github.com/YOUR_USERNAME/dash/issues)
- **Discussions:** [GitHub Discussions](https://github.com/YOUR_USERNAME/dash/discussions)
- **Enterprise Support:** enterprise@dash.app

---

**Status:** 🚧 In Development (Phase 1 - Week 1-2 Complete)
**Started:** January 2026
**Latest Milestone:** Application Shell & Foundation ✅
**Next Up:** Pipeline System (Week 3-4)

Built with ❤️ using Elixir and Phoenix