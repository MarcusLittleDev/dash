## Development Roadmap

### Phase 1: MVP (Weeks 1-8)

**Week 1-2: Foundation**
- [x] Initialize Phoenix project
- [x] Set up Ash Framework
- [ ] Configure PostgreSQL + TimescaleDB
- [ ] Implement authentication (username/password, magic link)
- [ ] Create Team/User schemas and contexts
- [ ] Build basic UI shell with LiveView

**Week 3-4: Core Pipeline**
- [ ] Pipeline CRUD operations
- [ ] HTTP polling source adapter
- [ ] Oban job scheduling
- [ ] TimescaleDB data insertion
- [ ] Basic data mapping (field remapping only)
- [ ] Pipeline worker GenServer

**Week 5-6: Dashboard MVP**
- [ ] Dashboard CRUD
- [ ] Widget system (table widget only initially)
- [ ] LiveView real-time updates
- [ ] Chart.js integration (line chart)
- [ ] Simple grid layout
- [ ] ETS cache implementation

**Week 7-8: Polish & Deploy**
- [ ] Add 2-3 more widget types (stat card, bar chart)
- [ ] Public dashboard sharing
- [ ] Error handling and user feedback
- [ ] Deploy to Fly.io
- [ ] Basic monitoring setup
- [ ] Documentation

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

