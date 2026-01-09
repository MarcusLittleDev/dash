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

## Reference

### Project Structure

```
dash/
├── assets/
│   ├── css/
│   │   └── app.css
│   ├── js/
│   │   ├── app.js
│   │   └── hooks/
│   │       └── chart.js
│   └── vendor/
├── config/
│   ├── config.exs
│   ├── dev.exs
│   ├── prod.exs
│   ├── runtime.exs
│   └── test.exs
├── lib/
│   ├── dash/
│   │   ├── accounts/              # Ash Domain
│   │   │   ├── domain.ex
│   │   │   └── resources/
│   │   │       ├── user.ex
│   │   │       ├── team.ex
│   │   │       └── membership.ex
│   │   ├── pipelines/             # Ash Domain
│   │   │   ├── domain.ex
│   │   │   ├── resources/
│   │   │   │   ├── pipeline.ex
│   │   │   │   ├── pipeline_sink.ex
│   │   │   │   └── data_mapping.ex
│   │   │   ├── workers/
│   │   │   │   ├── polling_worker.ex
│   │   │   │   └── pipeline_supervisor.ex
│   │   │   ├── data_mapper.ex
│   │   │   └── adapters/
│   │   │       ├── sources/
│   │   │       │   ├── http_api.ex
│   │   │       │   └── webhook.ex
│   │   │       └── sinks/
│   │   │           └── http_api.ex
│   │   ├── dashboards/            # Ash Domain
│   │   │   ├── domain.ex
│   │   │   ├── resources/
│   │   │   │   ├── dashboard.ex
│   │   │   │   └── widget.ex
│   │   │   └── widget_data_transformer.ex
│   │   ├── data/                  # High-performance layer
│   │   │   ├── pipeline_data.ex
│   │   │   ├── cache_manager.ex
│   │   │   └── queries.ex
│   │   ├── storage/               # File storage
│   │   │   └── storage.ex
│   │   ├── monitoring/
│   │   │   ├── telemetry.ex
│   │   │   └── alerts.ex
│   │   ├── application.ex
│   │   └── repo.ex
│   └── dash_web/
│       ├── components/
│       │   ├── core_components.ex
│       │   └── widgets.ex
│       ├── controllers/
│       │   └── pipeline_webhook_controller.ex
│       ├── live/
│       │   ├── dashboard_live.ex
│       │   ├── pipeline_live.ex
│       │   └── team_live.ex
│       ├── endpoint.ex
│       ├── router.ex
│       └── telemetry.ex
├── priv/
│   ├── repo/
│   │   ├── migrations/
│   │   └── seeds.exs
│   ├── static/
│   └── gettext/
├── test/
├── .formatter.exs
├── .gitignore
├── Dockerfile
├── fly.toml
├── mix.exs
├── mix.lock
└── README.md
```

### Key Dependencies

```elixir
# mix.exs
defp deps do
  [
    # Phoenix
    {:phoenix, "~> 1.7.10"},
    {:phoenix_ecto, "~> 4.4"},
    {:phoenix_html, "~> 4.0"},
    {:phoenix_live_view, "~> 0.20.2"},
    {:phoenix_live_dashboard, "~> 0.8.3"},
    
    # Database
    {:ecto_sql, "~> 3.11"},
    {:postgrex, ">= 0.0.0"},
    
    # Ash Framework
    {:ash, "~> 3.0"},
    {:ash_postgres, "~> 2.0"},
    {:ash_authentication, "~> 4.0"},
    {:ash_authentication_phoenix, "~> 2.0"},
    {:ash_json_api, "~> 1.0"},
    {:ash_graphql, "~> 1.0"},
    
    # Background Jobs
    {:oban, "~> 2.17"},
    
    # HTTP Client
    {:httpoison, "~> 2.2"},
    {:req, "~> 0.4"},
    
    # JSON
    {:jason, "~> 1.4"},
    
    # Encryption
    {:cloak_ecto, "~> 1.2"},
    
    # Clustering
    {:libcluster, "~> 3.3"},
    
    # Monitoring
    {:telemetry_metrics, "~> 0.6"},
    {:telemetry_poller, "~> 1.0"},
    {:telemetry_metrics_prometheus, "~> 1.1"},
    
    # Error Tracking
    {:sentry, "~> 10.0"},
    
    # Rate Limiting
    {:hammer, "~> 6.1"},
    
    # Payments
    {:stripe, "~> 3.0"},
    {:stripity_stripe, "~> 3.0"},  # Alternative
    
    # File Storage
    {:ex_aws, "~> 2.5"},
    {:ex_aws_s3, "~> 2.4"},
    
    # Frontend
    {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
    {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
    
    # Dev/Test
    {:phoenix_live_reload, "~> 1.4", only: :dev},
    {:floki, ">= 0.30.0", only: :test},
    {:ex_machina, "~> 2.7", only: :test}
  ]
end
```

### Environment Variables

```bash
# .env.example

# Database
DATABASE_URL=ecto://postgres:postgres@localhost/dash_dev
DATABASE_REPLICA_URL=ecto://postgres:postgres@localhost/dash_dev  # Same initially

# Phoenix
SECRET_KEY_BASE=generate_with_mix_phx_gen_secret
PHX_HOST=localhost
PORT=4000

# Encryption
ENCRYPTION_KEY=generate_with_openssl_rand_base64_32

# Stripe (Payments)
STRIPE_PUBLIC_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...

# File Storage (Cloudflare R2)
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
R2_BUCKET=dash-files
R2_ENDPOINT=https://...r2.cloudflarestorage.com

# Monitoring
SENTRY_DSN=https://...@sentry.io/...

# Email (SendGrid/Postmark)
SENDGRID_API_KEY=...
FROM_EMAIL=noreply@dash.app

# Optional
SLACK_WEBHOOK_URL=...  # For team notifications
```

---

## Appendix A: Stripe Integration Code Examples

### Subscription Management

```elixir
# lib/dash/billing/stripe_service.ex
defmodule Dash.Billing.StripeService do
  @moduledoc """
  Handles all Stripe operations for subscription management
  """

  # Price IDs (set these in Stripe dashboard)
  @prices %{
    pro_monthly: "price_pro_monthly_id",
    pro_annual: "price_pro_annual_id",
    business_monthly: "price_business_monthly_id",
    business_annual: "price_business_annual_id"
  }

  def create_customer(team, user) do
    Stripe.Customer.create(%{
      email: user.email,
      name: team.name,
      metadata: %{
        team_id: team.id,
        user_id: user.id
      }
    })
  end

  def create_subscription(team, tier, interval) do
    price_id = get_price_id(tier, interval)
    
    Stripe.Subscription.create(%{
      customer: team.stripe_customer_id,
      items: [%{price: price_id}],
      trial_period_days: 14,
      metadata: %{
        team_id: team.id,
        tier: tier
      }
    })
  end

  def upgrade_subscription(subscription, new_tier, new_interval) do
    new_price_id = get_price_id(new_tier, new_interval)
    
    Stripe.Subscription.update(subscription.stripe_subscription_id, %{
      items: [
        %{
          id: get_subscription_item_id(subscription),
          price: new_price_id
        }
      ],
      proration_behavior: "always_invoice"  # Charge immediately for upgrade
    })
  end

  def cancel_subscription(subscription, at_period_end \\ true) do
    Stripe.Subscription.delete(
      subscription.stripe_subscription_id,
      %{at_period_end: at_period_end}
    )
  end

  def create_billing_portal_session(team, return_url) do
    Stripe.BillingPortal.Session.create(%{
      customer: team.stripe_customer_id,
      return_url: return_url
    })
  end

  defp get_price_id(tier, interval) do
    key = String.to_atom("#{tier}_#{interval}")
    Map.get(@prices, key)
  end
end
```

### Usage-Based Billing

```elixir
# lib/dash/billing/usage_tracker.ex
defmodule Dash.Billing.UsageTracker do
  @moduledoc """
  Tracks usage and reports to Stripe for overage billing
  """

  # Track data points ingested
  def track_data_points(team_id, count) do
    subscription = get_subscription(team_id)
    
    # Update local counter
    new_count = subscription.data_points_current_month + count
    update_subscription_usage(subscription, data_points: new_count)
    
    # Report to Stripe if metered billing
    if subscription.tier in [:business, :enterprise] do
      report_usage_to_stripe(subscription, count)
    end
    
    # Check if over limit
    if new_count > subscription.data_points_limit do
      handle_overage(subscription, :data_points)
    end
  end

  # Report usage to Stripe (for metered billing)
  defp report_usage_to_stripe(subscription, quantity) do
    subscription_item_id = get_metered_subscription_item(subscription)
    
    Stripe.SubscriptionItem.Usage.create(
      subscription_item_id,
      %{
        quantity: quantity,
        timestamp: DateTime.utc_now() |> DateTime.to_unix(),
        action: "increment"
      }
    )
  end

  # Handle usage overage
  defp handle_overage(subscription, usage_type) do
    case subscription.tier do
      :free ->
        # Hard limit - stop accepting data
        notify_team_limit_reached(subscription.team_id, usage_type)
        :limit_reached
      
      tier when tier in [:pro, :business] ->
        # Soft limit - charge overage
        calculate_and_charge_overage(subscription, usage_type)
        :overage_charged
      
      :enterprise ->
        # No limit, but notify if unusual
        if unusual_usage?(subscription, usage_type) do
          notify_account_manager(subscription)
        end
        :ok
    end
  end

  defp calculate_and_charge_overage(subscription, :data_points) do
    overage = subscription.data_points_current_month - subscription.data_points_limit
    overage_millions = overage / 1_000_000
    charge = overage_millions * 5.00  # $5 per million over limit
    
    # Create invoice item
    Stripe.InvoiceItem.create(%{
      customer: subscription.stripe_customer_id,
      amount: trunc(charge * 100),  # Convert to cents
      currency: "usd",
      description: "Data points overage: #{overage_millions}M @ $5/M"
    })
  end

  # Reset monthly counters
  def reset_monthly_usage(subscription) do
    update_subscription_usage(subscription,
      data_points_current_month: 0
    )
  end
end
```

### Subscription Lifecycle LiveView

```elixir
# lib/dash_web/live/billing_live.ex
defmodule DashWeb.BillingLive do
  use DashWeb, :live_view

  def mount(_params, session, socket) do
    team = get_current_team(session)
    subscription = Dash.Billing.get_subscription(team)
    
    socket =
      socket
      |> assign(:team, team)
      |> assign(:subscription, subscription)
      |> assign(:usage, calculate_usage(subscription))
      |> assign(:available_tiers, get_available_tiers())
    
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="billing-container">
      <h1>Billing & Usage</h1>
      
      <!-- Current Plan -->
      <div class="current-plan">
        <h2>Current Plan: <%= format_tier(@subscription.tier) %></h2>
        <p>
          <%= if @subscription.billing_interval == :annual do %>
            Billed annually - Next payment: <%= @subscription.current_period_end %>
          <% else %>
            Billed monthly - Next payment: <%= @subscription.current_period_end %>
          <% end %>
        </p>
        
        <button phx-click="manage_billing" class="btn-secondary">
          Manage Payment Method
        </button>
      </div>
      
      <!-- Usage Meters -->
      <div class="usage-meters">
        <h3>Usage This Month</h3>
        
        <!-- Pipelines -->
        <div class="usage-meter">
          <div class="meter-header">
            <span>Pipelines</span>
            <span><%= @usage.pipelines_count %> / <%= @subscription.pipelines_limit %></span>
          </div>
          <div class="meter-bar">
            <div class="meter-fill" style={"width: #{usage_percent(@usage.pipelines_count, @subscription.pipelines_limit)}%"}></div>
          </div>
        </div>
        
        <!-- Storage -->
        <div class="usage-meter">
          <div class="meter-header">
            <span>Storage</span>
            <span><%= format_gb(@subscription.storage_used_gb) %> / <%= @subscription.storage_limit_gb %> GB</span>
          </div>
          <div class="meter-bar">
            <div class="meter-fill" style={"width: #{usage_percent(@subscription.storage_used_gb, @subscription.storage_limit_gb)}%"}></div>
          </div>
        </div>
        
        <!-- Data Points -->
        <div class="usage-meter">
          <div class="meter-header">
            <span>Data Points</span>
            <span><%= format_millions(@subscription.data_points_current_month) %> / <%= format_millions(@subscription.data_points_limit) %>M</span>
          </div>
          <div class="meter-bar">
            <div class="meter-fill" style={"width: #{usage_percent(@subscription.data_points_current_month, @subscription.data_points_limit)}%"}></div>
          </div>
          <%= if @subscription.data_points_current_month > @subscription.data_points_limit do %>
            <p class="overage-notice">
              Overage: <%= format_millions(@subscription.data_points_current_month - @subscription.data_points_limit) %>M 
              @ $5/M = $<%= calculate_overage_cost(@subscription) %>
            </p>
          <% end %>
        </div>
      </div>
      
      <!-- Upgrade Options -->
      <%= if @subscription.tier != :enterprise do %>
        <div class="upgrade-options">
          <h3>Upgrade Your Plan</h3>
          
          <%= for tier <- @available_tiers do %>
            <div class="tier-card">
              <h4><%= tier.name %></h4>
              <p class="price">
                $<%= tier.monthly_price %>/month
                <span class="annual-save">Save 20% with annual</span>
              </p>
              
              <ul class="features">
                <%= for feature <- tier.features do %>
                  <li><%= feature %></li>
                <% end %>
              </ul>
              
              <button phx-click="upgrade" phx-value-tier={tier.slug} class="btn-primary">
                <%= if tier.slug == @subscription.tier, do: "Current Plan", else: "Upgrade" %>
              </button>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("upgrade", %{"tier" => tier}, socket) do
    # Redirect to checkout or upgrade flow
    {:noreply, push_navigate(socket, to: ~p"/billing/upgrade/#{tier}")}
  end

  def handle_event("manage_billing", _params, socket) do
    # Create Stripe billing portal session
    {:ok, session} = Dash.Billing.StripeService.create_billing_portal_session(
      socket.assigns.team,
      url(~p"/billing")
    )
    
    {:noreply, redirect(socket, external: session.url)}
  end

  defp calculate_usage(subscription) do
    %{
      pipelines_count: Dash.Pipelines.count_by_team(subscription.team_id),
      storage_gb: subscription.storage_used_gb,
      data_points: subscription.data_points_current_month
    }
  end

  defp usage_percent(current, limit) when limit > 0 do
    min(100, (current / limit * 100) |> Float.round(1))
  end
  defp usage_percent(_, _), do: 0
end
```

---

## Appendix B: Deployment Checklist

### Pre-Launch Checklist

**Infrastructure:**
- [ ] Fly.io app created
- [ ] PostgreSQL database provisioned
- [ ] TimescaleDB extension enabled
- [ ] Environment variables set (secrets)
- [ ] Domain configured (DNS)
- [ ] SSL certificate active
- [ ] Cloudflare R2 bucket created
- [ ] File upload limits configured

**Database:**
- [ ] Migrations run
- [ ] Indexes created
- [ ] TimescaleDB hypertables configured
- [ ] Compression policies set
- [ ] Backup strategy configured
- [ ] Connection pooling tested

**Application:**
- [ ] Authentication working (all methods)
- [ ] Email sending configured (SendGrid/Postmark)
- [ ] Stripe integration tested
- [ ] Webhook endpoints secured
- [ ] Rate limiting active
- [ ] CORS configured
- [ ] Error tracking (Sentry) working

**Monitoring:**
- [ ] Telemetry metrics exporting
- [ ] Grafana dashboards created
- [ ] Alerts configured
- [ ] Uptime monitoring (UptimeRobot/Pingdom)
- [ ] Log aggregation setup

**Security:**
- [ ] Security headers active
- [ ] CSRF protection enabled
- [ ] SQL injection prevention verified
- [ ] XSS protection verified
- [ ] Rate limiting tested
- [ ] Audit logging working
- [ ] Data encryption verified

**Legal/Compliance:**
- [ ] Privacy policy published
- [ ] Terms of service published
- [ ] Cookie consent (if EU traffic)
- [ ] GDPR compliance reviewed
- [ ] Data retention policies documented

---

## Glossary

**BEAM:** The Erlang virtual machine that runs Elixir code

**ETS:** Erlang Term Storage - in-memory key-value store

**GenServer:** Generic server behavior in Elixir for stateful processes

**Hypertable:** TimescaleDB's abstraction for time-series data

**LiveView:** Phoenix framework for real-time server-rendered UIs

**Multi-tenancy:** Architecture where multiple customers (teams) share infrastructure but data is isolated

**Oban:** Background job processing library for Elixir

**Pipeline:** User-configured data flow from source to destination

**PubSub:** Publish-subscribe messaging pattern for real-time updates

**Sink:** Destination where pipeline data is sent (email, Slack, API, etc.)

**Source:** Origin of data for a pipeline (API, webhook, database, etc.)

**Supervision Tree:** Elixir's fault-tolerance mechanism

**Widget:** Visualization component on a dashboard (chart, table, etc.)

---

## End of Documentation

**Last Updated:** January 2026  
**Version:** 1.0  
**Status:** Complete Technical Plan

For questions or updates, please contact the development team.

---

**Next Steps:**
1. Review this plan with stakeholders
2. Set up development environment
3. Initialize Phoenix project
4. Begin Phase 1 implementation (Week 1-2)
5. Deploy MVP to production (Week 8)

