## Decision Records

### DR-001: Why Elixir/Phoenix?

**Decision:** Use Elixir and Phoenix framework

**Rationale:**
- Real-time capabilities built-in (perfect for live dashboards)
- BEAM's concurrency model ideal for many simultaneous pipelines
- Fault tolerance via supervision trees
- Great for I/O-bound operations (API polling, webhooks)
- LiveView eliminates need for separate frontend framework
- Strong ecosystem for our use case

**Alternatives Considered:**
- Node.js: Less robust concurrency, callback hell
- Python/Django: Slower, not designed for real-time
- Go: More verbose, no built-in real-time like LiveView
- Ruby/Rails: Similar benefits but slower than Elixir

### DR-002: Why Ash Framework?

**Decision:** Use Ash Framework for domain logic

**Rationale:**
- Auto-generated GraphQL and REST APIs (mobile-ready)
- Built-in authorization policies (critical for multi-tenancy)
- Resource-based architecture enforces good patterns
- Reduces boilerplate significantly
- Active development and community

**Alternatives Considered:**
- Plain Phoenix contexts: More manual work, no auto-APIs
- Absinthe (GraphQL only): Have to build REST separately

### DR-003: Why TimescaleDB over Cassandra?

**Decision:** Use PostgreSQL with TimescaleDB extension

**Rationale:**
- SQL familiarity for team
- Joins work (essential for dashboard queries)
- Single database to manage
- Good enough performance for our scale
- Cheaper operational costs
- Continuous aggregates feature

**Alternatives Considered:**
- Cassandra: Overkill, no joins, higher complexity
- ClickHouse: Consider for Phase 3 if needed
- InfluxDB: Less flexible querying

### DR-004: Why LiveView over React?

**Decision:** Use Phoenix LiveView for UI

**Rationale:**
- One codebase (mostly Elixir)
- Real-time updates built-in
- SEO-friendly server rendering
- Faster development
- Smaller team can manage
- Lower hosting costs

**Alternatives Considered:**
- React SPA: Two codebases, more complexity
- Vue.js: Same issues as React
- Svelte: Less mature ecosystem

### DR-005: Why No Umbrella Project?

**Decision:** Use standard Phoenix project structure

**Rationale:**
- Simpler for small team
- Faster compilation
- Easier refactoring
- Can extract later if needed (rare)
- Most successful Elixir apps don't use umbrellas

**Alternatives Considered:**
- Umbrella: Added complexity without clear benefit at this stage

### DR-006: Why Fly.io over AWS/GCP?

**Decision:** Deploy to Fly.io initially

**Rationale:**
- Optimized for Elixir/Phoenix
- Global edge deployment
- Simple scaling
- Integrated PostgreSQL
- Lower operational burden
- Can migrate later if needed

**Alternatives Considered:**
- AWS: More complex, higher DevOps overhead
- Digital Ocean: Manual setup, less Elixir-optimized
- Heroku: More expensive, less control

### DR-007: Layer Abstraction with Behaviours

**Decision:** Abstract infrastructure layers using Elixir Behaviours and Adapter pattern, implemented incrementally as needed.

**Rationale:**
- **Testability**: Swap production implementations for in-memory/mock adapters in tests
- **Portability**: Easily migrate from S3 to R2, PostgreSQL to ClickHouse, ETS to Redis
- **Local Development**: Use local filesystem instead of cloud storage
- **Self-Hosted**: Enable customers to use their own infrastructure
- **Future-Proofing**: Technology choices can evolve without rewriting business logic

**Pattern:**

```elixir
# lib/dash/storage/lake.ex
defmodule Dash.Storage.Lake do
  @moduledoc "Behaviour defining the Bronze layer storage interface"

  @callback put_batch(binary(), String.t()) :: :ok | {:error, any()}
  @callback stream_batch(String.t()) :: Enumerable.t()
  @callback list_files(String.t()) :: [String.t()]
  @callback delete_file(String.t()) :: :ok | {:error, any()}

  def put_batch(data, path), do: adapter().put_batch(data, path)
  def stream_batch(path), do: adapter().stream_batch(path)
  def list_files(prefix), do: adapter().list_files(prefix)
  def delete_file(path), do: adapter().delete_file(path)

  defp adapter, do: Application.get_env(:dash, :lake_adapter)
end
```

**Adapters by Layer:**

| Layer | Behaviour | Production Adapter | Test/Dev Adapter | Future |
|-------|-----------|-------------------|------------------|--------|
| **Bronze (Data Lake)** | `Dash.Storage.Lake` | `Lake.R2Adapter` | `Lake.LocalAdapter` | S3, GCS |
| **Silver (Metrics)** | `Dash.Storage.Metrics` | `Metrics.TimescaleAdapter` | `Metrics.EtsAdapter` | ClickHouse |
| **Processing** | `Dash.Processing.Engine` | `Engine.ObanAdapter` | `Engine.InlineAdapter` | Broadway |
| **Cache** | `Dash.Cache` | `Cache.EtsAdapter` | `Cache.AgentAdapter` | Redis, Horde |

**Configuration:**

```elixir
# config/config.exs (production defaults)
config :dash, :lake_adapter, Dash.Storage.Lake.R2Adapter
config :dash, :metrics_adapter, Dash.Storage.Metrics.TimescaleAdapter
config :dash, :cache_adapter, Dash.Cache.EtsAdapter

# config/test.exs
config :dash, :lake_adapter, Dash.Storage.Lake.LocalAdapter
config :dash, :metrics_adapter, Dash.Storage.Metrics.EtsAdapter
config :dash, :cache_adapter, Dash.Cache.AgentAdapter
```

**Alternatives Considered:**
- **Direct module calls**: Simpler but tightly couples code to specific implementations
- **Protocol-based dispatch**: More Elixir-idiomatic for data types, but Behaviours fit better for service contracts
- **Dependency injection via GenServer**: Overkill for this use case

**Implementation Strategy (Incremental):**

The key insight is to avoid premature abstraction. Extract Behaviours when there's a concrete need:

| Trigger | Action |
|---------|--------|
| First integration test needs mock storage | Extract `Dash.Storage.Lake` behaviour |
| Self-hosted feature prioritized | Add `LocalAdapter` implementations |
| Performance requires Redis/ClickHouse | Extract remaining Behaviours |
| Test suite is slow due to DB calls | Add `EtsAdapter` for Silver layer |

**Phase 1 (MVP)**: Direct calls to R2/TimescaleDB are acceptable. Focus on features.

**Phase 2 (Testing)**: Extract `Dash.Storage.Lake` behaviour first (highest value for dev/test). Consider using [Mox](https://hexdocs.pm/mox) library for test mocks instead of full adapter implementations.

**Phase 3 (Self-Hosted)**: Add local/bring-your-own adapters for all layers when self-hosted deployment is prioritized.

**Keep APIs Minimal**: Only add methods to Behaviours when actually needed. Resist the urge to "complete" the interface upfront.

---

## Real-World Use Cases

### Use Case 1: E-commerce Multi-Platform Analytics

**Customer Profile:** Small to medium online retailer ($500K-$5M annual revenue)

**Challenge:** Manually checking Shopify, Amazon, and Stripe daily; updating Excel spreadsheets for inventory and sales reporting.

**Dash Implementation:**
- **Pipeline 1:** Shopify API (polls every 5 minutes)
  - New orders, customer data, inventory levels
  - Data mapping: `customer.first_name` → `firstName`
  - Transformation: All prices converted to USD
  
- **Pipeline 2:** Amazon Seller Central API (hourly)
  - Sales, returns, FBA inventory
  
- **Pipeline 3:** Stripe webhook (real-time)
  - Payment events, refunds, disputes

**Dashboards:**
- Executive: Real-time revenue, orders/hour, AOV (Average Order Value)
- Inventory: Stock levels across platforms, low-stock alerts
- Public investor dashboard: Monthly GMV, growth trends

**Automated Actions (Data Sinks):**
- Slack notification when daily revenue exceeds $10K
- Email alert when any SKU drops below 10 units
- Daily sales summary to Google Sheets for accountant
- Webhook to reorder system when inventory critical

**Results:**
- Time saved: 2 hours/day → 40 hours/month
- Faster response: Catch stock-outs 24 hours earlier
- Better decisions: Real-time data vs. day-old reports
- **Estimated value:** $2,000/month in time + opportunity cost
- **Willing to pay:** $99-199/month

---

### Use Case 2: SaaS Product Metrics Monitoring

**Customer Profile:** Early-stage SaaS startup, 500-5,000 users

**Challenge:** Using 3+ separate tools (Mixpanel $300/mo, ChartMogul $250/mo, custom scripts) for product analytics. Manual board reports every month.

**Dash Implementation:**
- **Pipeline 1:** Application database webhook
  - User signups, feature usage, session data
  - Real-time activity stream
  
- **Pipeline 2:** Stripe API
  - MRR, churn, failed payments
  
- **Pipeline 3:** Customer.io API
  - Email campaign performance
  
- **Pipeline 4:** Support ticket system (Zendesk)
  - Volume, response time, satisfaction

**Data Transformations:**
- Calculate Customer Lifetime Value (CLV)
- Compute cohort retention rates
- Aggregate feature usage by plan tier
- Customer health score calculation

**Dashboards:**
- Growth: Daily signups, activation rate, MRR growth
- Health: Customer health scores, churn risk
- Product: Feature adoption, engagement metrics
- Public board dashboard: KPIs for investors

**Automated Actions:**
- Post to #growth Slack when signups > 50/day
- Trigger customer success workflow when health score < 50
- Weekly metrics email to CEO
- Alert when churn rate increases 2% MoM

**Results:**
- Tool consolidation: Saves $550/month in SaaS subscriptions
- Time saved: 10 hours/month on manual reporting
- Faster action: Real-time churn risk vs. quarterly reviews
- **Estimated value:** $3,000/month
- **Willing to pay:** $199-399/month

---

### Use Case 3: Digital Marketing Agency Client Reporting

**Customer Profile:** Marketing agency managing 15-30 clients

**Challenge:** Manually pulling data from Google Ads, Facebook Ads, Analytics for each client. Creating weekly reports takes 20+ hours.

**Dash Implementation:**
- **Pipeline 1:** Google Ads API (hourly, per client)
  - Spend, impressions, clicks, conversions
  
- **Pipeline 2:** Facebook Ads API (hourly, per client)
  - Campaign performance across Meta platforms
  
- **Pipeline 3:** Google Analytics API (daily)
  - Website traffic, behavior, conversions
  
- **Pipeline 4:** CRM webhooks (HubSpot/Salesforce)
  - Lead quality, sales conversions

**Multi-Tenancy Configuration:**
- Each client is a separate team
- Agency admins see all clients
- Clients see only their data
- Role-based access: Client viewers can't edit

**Data Transformations:**
- Normalize metrics: CTR, CPA, ROAS across platforms
- Calculate blended CAC (Customer Acquisition Cost)
- Attribution modeling (first-touch, last-touch, linear)
- Custom client-specific calculations

**Dashboards (Per Client):**
- Campaign performance by channel
- Creative performance (which ads work)
- ROI dashboard with ROAS
- Public dashboard clients share with their executives

**Automated Actions:**
- Weekly automated report via email (PDF export)
- Slack alert when CPA exceeds client threshold
- Pause campaign webhook when budget exhausted
- Export to client data warehouse (BigQuery)

**Results:**
- Time saved: 20 hours/week → 80 hours/month
- Client retention: +30% (transparency builds trust)
- New business: Dashboard demos close deals
- **Estimated value:** $8,000/month (billable hours)
- **Willing to pay:** $299-599/month (price per client model)

---

### Use Case 4: IoT Device Fleet Management

**Customer Profile:** Smart home/industrial IoT company with 10K-100K devices

**Challenge:** Monitoring thousands of devices, identifying failures, tracking battery life, firmware updates.

**Dash Implementation:**
- **Pipeline 1:** Device telemetry webhook
  - Temperature, humidity, battery from sensors
  - 500K-5M data points per day
  - Real-time streaming
  
- **Pipeline 2:** Device status API (polling)
  - Online/offline, firmware version, errors

**Data Mappings:**
- Standardize device IDs across manufacturers
- Convert temperature (F→C, C→F based on region)
- Parse error codes to human-readable messages

**Dashboards:**
- Operations: Live device status map (geographic)
- Alerts: Offline devices, low battery, anomalies
- Analytics: Avg temp by region, battery drain patterns
- Customer-facing: Each customer sees only their devices

**Data Retention Strategy:**
- Raw telemetry: 7 days (high volume)
- Hourly aggregates: 90 days
- Daily summaries: Forever
- TimescaleDB compression: 10x reduction after 7 days

**Automated Actions:**
- PagerDuty when >10% devices offline in region
- Email customer when battery < 20%
- Trigger firmware update for vulnerable devices
- Archive to S3 for long-term ML training

**Results:**
- Proactive maintenance: 60% reduction in support calls
- Customer satisfaction: +40% (battery notifications)
- Operational efficiency: Identify issues before customer notices
- **Estimated value:** $15,000/month
- **Willing to pay:** $499-999/month

---

### Use Case 5: Restaurant Chain Operations

**Customer Profile:** Fast-food/casual dining chain with 20-100 locations

**Challenge:** No real-time visibility into sales, inventory, labor across locations. Regional managers drive location-to-location.

**Dash Implementation:**
- **Pipeline 1:** POS system webhook (Square/Toast)
  - Real-time transactions from all locations
  - Per-location, per-item sales
  
- **Pipeline 2:** Inventory management system
  - Stock levels, food costs, waste
  
- **Pipeline 3:** Staff scheduling system
  - Labor hours, overtime, schedule adherence
  
- **Pipeline 4:** Google Reviews API
  - Star ratings, review sentiment

**Multi-Tenancy:**
- Corporate sees all locations
- Regional manager sees their region
- Location manager sees only their location
- Franchisees see their locations only

**Data Transformations:**
- Normalize menu items across locations
- Calculate food cost percentage
- Labor efficiency metrics (sales per labor hour)
- Trend analysis (same-store sales growth)

**Dashboards:**
- Executive: System-wide sales, top/bottom performers
- Location: Real-time sales vs. target, labor, inventory
- Operations: Food cost %, labor efficiency
- Customer experience: Review trends, complaint analysis

**Automated Actions:**
- Slack alert when location misses hourly target
- Email district manager when food cost spikes
- Text manager when understaffed
- Daily P&L to each location manager

**Results:**
- Visibility: Issues identified in real-time vs. next day
- Cost control: Food waste down 15%, labor optimized
- Consistency: Enforce standards across locations
- **Estimated value:** $20,000/month (50 locations)
- **Willing to pay:** $799-1,499/month

---

### Use Case 6: Healthcare Remote Patient Monitoring

**Customer Profile:** Healthcare provider, chronic disease management program

**Challenge:** Manual data collection from patients, reactive care, hospital readmissions.

**Dash Implementation:**
- **Pipeline 1:** Wearable device API (Fitbit, Apple Health)
  - Heart rate, steps, sleep, glucose, blood pressure
  
- **Pipeline 2:** Smart scale webhook
  - Daily weight, body composition
  
- **Pipeline 3:** Medication adherence sensors
  - Pill bottle sensors, timestamps
  
- **Pipeline 4:** Patient self-reporting app
  - Symptom logs, mood, energy

**HIPAA Compliance:**
- Field-level encryption (Cloak)
- Audit logging on all access
- Role-based access (doctors, nurses, patients)
- Data retention: 7 years (compliance)
- BAA (Business Associate Agreement) with Dash

**Dashboards:**
- Doctor: All patients, flagged concerning trends
- Patient: Their own metrics (public dashboard with token)
- Care coordinator: Patients needing intervention
- Population health: Anonymized aggregate data

**Data Transformations:**
- HbA1c estimates from glucose readings
- Medication adherence patterns
- Risk scoring (hospital readmission risk)
- Trend detection (rapid weight gain = fluid retention)

**Automated Actions:**
- Alert nurse when patient misses 3 medications
- Email doctor when metrics worsen
- SMS encouragement when activity goal hit
- Trigger care coordinator outreach for high-risk

**File Support:**
- Upload lab results PDFs → link to patient
- EKG readings from device → stored, displayed

**Results:**
- Readmissions: 40% reduction
- Care team efficiency: Proactive vs. reactive
- Patient engagement: Patients see progress, stay motivated
- **Estimated value:** $50,000/month (1000 patients)
- **Willing to pay:** $1,999-4,999/month

---

### Use Case 7: Content Creator Cross-Platform Analytics

**Customer Profile:** YouTuber/influencer with 100K-1M followers

**Challenge:** Checking YouTube, Instagram, TikTok, Patreon separately. No unified view of performance and revenue.

**Dash Implementation:**
- **Pipeline 1:** YouTube Analytics API
  - Views, watch time, subscribers, revenue, CPM
  
- **Pipeline 2:** Instagram API
  - Post engagement, follower growth, story views
  
- **Pipeline 3:** TikTok API
  - Video views, engagement rate
  
- **Pipeline 4:** Patreon API
  - Patron count, monthly revenue, tier distribution
  
- **Pipeline 5:** Shopify (merchandise)
  - Sales, product performance

**Dashboards:**
- Performance: Cross-platform metrics in one view
- Revenue: Total income by source (YouTube, Patreon, merch)
- Audience: Demographics, growth trends
- Content: Which videos/posts perform best
- Public: Share with sponsors/potential brand deals

**Data Transformations:**
- Calculate engagement rate (each platform different)
- Normalize metrics for comparison
- Identify optimal posting times
- Revenue per follower by platform

**Automated Actions:**
- Auto-tweet when video hits 100K views
- Email when monthly revenue hits goal
- Update Notion content calendar
- Discord bot posts milestones to fan community

**Results:**
- Brand deals: Professional dashboard impresses sponsors
- Strategy: Data-driven content decisions
- Time saved: 5 hours/week on analytics
- **Estimated value:** $2,000/month
- **Willing to pay:** $49-99/month

---

## Pricing & Monetization Strategy

### Pricing Philosophy

**Value-Based Pricing:** Price based on customer value, not just our costs
**Tiered Model:** Grow with customers from hobbyist to enterprise
**Usage-Based Components:** Fair pricing for heavy users
**No Surprises:** Transparent, predictable billing

---

### Pricing Tiers

#### **Free Tier** - "Starter"
**Target:** Individuals, hobbyists, proof-of-concept

**Limits:**
- 3 pipelines
- 1 team (5 members max)
- 3 dashboards
- 1 GB data storage
- 7-day data retention
- 10,000 data points/month
- Community support only

**Price:** $0/month

**Purpose:** Acquisition, viral growth, learning platform

---

#### **Professional** - "Pro"
**Target:** Small businesses, solopreneurs, content creators

**Includes:**
- 25 pipelines
- 2 teams (10 members each)
- 15 dashboards
- 25 GB data storage
- 30-day data retention
- 1M data points/month
- Email support (24-hour response)
- Public dashboard sharing
- Basic data sinks (email, webhook)
- API access

**Price:** $49/month (annual) or $59/month (monthly)

**Target Customers:**
- E-commerce store owners
- Content creators
- Freelance consultants
- Small SaaS apps

---

#### **Business** - "Team"
**Target:** Growing companies, agencies, teams

**Includes:**
- 100 pipelines
- 10 teams (50 members each)
- Unlimited dashboards
- 100 GB data storage
- 90-day data retention
- 10M data points/month
- Priority email + chat support
- All data sinks (Slack, Zapier, etc.)
- Advanced transformations
- SSO (SAML)
- Audit logging
- SLA: 99.5% uptime

**Price:** $199/month (annual) or $249/month (monthly)

**Target Customers:**
- Marketing agencies (15-30 clients)
- SaaS companies (1K-10K users)
- Multi-location businesses
- DevOps teams

---

#### **Enterprise** - "Custom"
**Target:** Large companies, regulated industries, high-volume

**Includes:**
- Unlimited pipelines
- Unlimited teams
- Unlimited dashboards
- Custom storage (500GB-10TB+)
- Custom data retention (up to indefinite)
- Unlimited data points
- Dedicated account manager
- Phone + Slack support (1-hour response)
- Custom SLA (99.9% or 99.95%)
- SOC 2 Type II compliance
- BAA for HIPAA (healthcare)
- Custom contracts
- On-premise option (future)
- White-label option (future)

**Price:** Starting at $999/month (negotiated based on usage)

**Add-ons:**
- +$500/month for HIPAA BAA
- +$1,000/month for SOC 2 audit support
- +$2,000/month for dedicated infrastructure

**Target Customers:**
- Healthcare providers
- Large IoT deployments (100K+ devices)
- Enterprise SaaS companies
- Financial institutions
- Restaurant chains (50+ locations)

---

### Usage-Based Add-Ons (All Tiers)

**Additional Data Storage:**
- $1 per additional GB/month
- Encourages data retention policy usage

**Additional Data Points:**
- $5 per additional 1M data points/month
- Only charged if you exceed tier limit

**Additional Team Members:**
- $5 per user/month (above tier limit)

**File Storage:**
- First 10 GB included
- $0.03 per GB/month after (Cloudflare R2 pricing + margin)

**Data Sinks (Professional tier):**
- Advanced sinks: $10/month per sink type
  - Salesforce, HubSpot, BigQuery, etc.

---

### Annual Discount

**All paid tiers:** 15-20% discount for annual payment
- Improves cash flow
- Reduces churn
- Customer commitment

**Example:**
- Pro: $59/mo monthly = $708/year
- Pro: $49/mo annual = $588/year (saves $120)

---

### Pricing Comparison Table

| Feature | Free | Pro | Business | Enterprise |
|---------|------|-----|----------|------------|
| **Pipelines** | 3 | 25 | 100 | Unlimited |
| **Teams** | 1 (5 members) | 2 (10 each) | 10 (50 each) | Unlimited |
| **Dashboards** | 3 | 15 | Unlimited | Unlimited |
| **Storage** | 1 GB | 25 GB | 100 GB | Custom |
| **Retention** | 7 days | 30 days | 90 days | Custom |
| **Data Points/mo** | 10K | 1M | 10M | Unlimited |
| **Support** | Community | Email (24hr) | Priority | Dedicated |
| **Public Dashboards** | ✗ | ✓ | ✓ | ✓ |
| **SSO** | ✗ | ✗ | ✓ | ✓ |
| **API Access** | ✗ | ✓ | ✓ | ✓ |
| **SLA** | None | None | 99.5% | 99.9%+ |
| **SOC 2** | ✗ | ✗ | ✗ | ✓ |
| **HIPAA BAA** | ✗ | ✗ | ✗ | ✓ (+$500) |
| **Price** | $0 | $49/mo | $199/mo | $999+/mo |

---

### Revenue Projections

**Year 1 Goals:**

| Month | Free Users | Pro Users | Business Users | Enterprise | MRR | ARR |
|-------|-----------|-----------|----------------|------------|-----|-----|
| 3 | 100 | 5 | 0 | 0 | $245 | $2,940 |
| 6 | 250 | 20 | 2 | 0 | $1,378 | $16,536 |
| 9 | 500 | 50 | 5 | 1 | $4,444 | $53,328 |
| 12 | 1,000 | 100 | 15 | 3 | $11,882 | $142,584 |

**Assumptions:**
- 10% free → Pro conversion
- 5% Pro → Business upgrade
- 1-2 Enterprise deals per quarter
- 5% monthly churn (improves over time)

**Year 2 Goal:** $500K ARR (4,200 MRR)
**Year 3 Goal:** $2M ARR

---

### Competitive Pricing Analysis

**vs. Building Custom:**
- Developer time: $10K-50K
- Maintenance: $2K-5K/month
- Infrastructure: $500-5K/month
- **Total:** $30K-100K/year
- **Dash saves:** $20K-90K/year for Business tier customer

**vs. Competitors:**

| Competitor | Starting Price | Limitations | Dash Advantage |
|------------|---------------|-------------|----------------|
| **Zapier** | $20/mo | 100 tasks, no dashboards | We include visualizations |
| **Segment** | $120/mo | Data routing only, no viz | Full pipeline + dashboards |
| **Datadog** | $15/host/mo | Monitoring only | We handle data transformation |
| **Tableau** | $70/user/mo | Visualization only | We fetch + transform data |
| **Custom Build** | $10K-50K | Dev time, maintenance | Turnkey solution |

**Value Proposition:** Only platform combining data pipelines + transformations + real-time dashboards at this price point.

---

### Payment & Billing Implementation

**Technical Stack:**
- **Payment Processor:** Stripe
- **Integration:** via Ash or direct Stripe API
- **Subscription Management:** Stripe Billing
- **Invoicing:** Stripe invoices (auto-generated)

**Billing Schema:**

```elixir
# lib/dash/billing/resources/subscription.ex
defmodule Dash.Billing.Subscription do
  use Ash.Resource

  attributes do
    uuid_primary_key :id
    
    attribute :stripe_subscription_id, :string
    attribute :stripe_customer_id, :string
    
    attribute :tier, :atom do
      constraints one_of: [:free, :pro, :business, :enterprise]
      default :free
    end
    
    attribute :status, :atom do
      constraints one_of: [:active, :past_due, :canceled, :trialing]
    end
    
    attribute :billing_interval, :atom do
      constraints one_of: [:monthly, :annual]
    end
    
    # Usage tracking
    attribute :pipelines_count, :integer, default: 0
    attribute :data_points_current_month, :integer, default: 0
    attribute :storage_used_gb, :decimal, default: 0.0
    
    # Limits based on tier
    attribute :pipelines_limit, :integer
    attribute :data_points_limit, :integer
    attribute :storage_limit_gb, :integer
    
    attribute :trial_ends_at, :datetime
    attribute :current_period_end, :datetime
    
    belongs_to :team, Dash.Accounts.Team
  end
  
  # Usage enforcement
  calculations do
    calculate :is_over_pipeline_limit, :boolean, expr(
      pipelines_count > pipelines_limit
    )
    
    calculate :is_over_storage_limit, :boolean, expr(
      storage_used_gb > storage_limit_gb
    )
  end
end
```

**Usage Tracking:**

```elixir
# Track pipeline creation
defmodule Dash.Pipelines.Pipeline do
  # ...
  
  changes do
    change after_action(fn _changeset, pipeline ->
      Dash.Billing.track_pipeline_created(pipeline.team_id)
    end)
  end
end

# Enforce limits
defmodule Dash.Billing.LimitEnforcer do
  def check_can_create_pipeline(team) do
    subscription = get_subscription(team)
    
    if subscription.pipelines_count >= subscription.pipelines_limit do
      {:error, :limit_reached, "Upgrade to create more pipelines"}
    else
      :ok
    end
  end
  
  def check_storage_limit(team, additional_gb) do
    subscription = get_subscription(team)
    projected = subscription.storage_used_gb + additional_gb
    
    if projected > subscription.storage_limit_gb do
      {:error, :storage_limit, "Upgrade for more storage"}
    else
      :ok
    end
  end
end
```

**Stripe Webhook Handling:**

```elixir
# lib/dash_web/controllers/stripe_webhook_controller.ex
defmodule DashWeb.StripeWebhookController do
  use DashWeb, :controller

  def webhook(conn, _params) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)
    signature = get_req_header(conn, "stripe-signature") |> List.first()
    
    case Stripe.Webhook.construct_event(body, signature, webhook_secret()) do
      {:ok, %Stripe.Event{type: "customer.subscription.created"} = event} ->
        handle_subscription_created(event)
        json(conn, %{status: "ok"})
      
      {:ok, %Stripe.Event{type: "customer.subscription.updated"} = event} ->
        handle_subscription_updated(event)
        json(conn, %{status: "ok"})
      
      {:ok, %Stripe.Event{type: "customer.subscription.deleted"} = event} ->
        handle_subscription_canceled(event)
        json(conn, %{status: "ok"})
      
      {:ok, %Stripe.Event{type: "invoice.payment_failed"} = event} ->
        handle_payment_failed(event)
        json(conn, %{status: "ok"})
      
      {:error, _} ->
        conn |> put_status(400) |> json(%{error: "Invalid signature"})
    end
  end
  
  defp handle_subscription_created(event) do
    subscription_data = event.data.object
    
    # Update team's subscription
    team = find_team_by_stripe_customer(subscription_data.customer)
    
    Ash.update!(team.subscription, :activate, %{
      stripe_subscription_id: subscription_data.id,
      tier: map_stripe_plan_to_tier(subscription_data.plan.id),
      status: :active,
      current_period_end: DateTime.from_unix!(subscription_data.current_period_end)
    })
  end
end
```

---

### Free Trial Strategy

**14-Day Pro Trial:**
- New signups get Pro tier for 14 days
- No credit card required
- Convert to Free after trial unless they upgrade
- Email sequence during trial:
  - Day 1: Welcome + quick start guide
  - Day 3: Feature highlight (dashboards)
  - Day 7: Use case examples
  - Day 10: Upgrade prompt (4 days left)
  - Day 13: Final reminder (1 day left)

**Expected Conversion:** 8-12% trial → paid

---

### Upgrade Prompts (In-App)

**Soft Limits:**
- When approaching limit (80%), show banner: "You're using 20/25 pipelines. Upgrade for more."
- When at limit, show modal: "Pipeline limit reached. Upgrade to Pro or delete a pipeline."

**Feature Gating:**
- Try to create 4th dashboard on Free → "Upgrade to Pro for unlimited dashboards"
- Try to set retention > 7 days → "Upgrade for longer retention"
- Try to add SSO → "SSO available on Business tier"

---

### Customer Success & Retention

**Churn Prevention:**
- Email when usage drops 50% for 2 weeks
- Offer pause subscription option (3 months)
- Exit survey on cancellation
- Win-back campaign after 30 days

**Expansion Revenue:**
- Monitor usage approaching limits
- Proactive upgrade suggestions
- Annual plan conversion campaign
- Enterprise white-glove outreach at $500 MRR

**Target Metrics:**
- Gross churn: <5% monthly
- Net revenue retention: >100% (expansion covers churn)
- LTV/CAC ratio: >3:1

---

