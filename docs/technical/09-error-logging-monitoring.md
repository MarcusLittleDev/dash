# Error Logging & Monitoring

## Overview

Comprehensive error logging and monitoring strategy for diagnosing issues in production, tracking system health, and ensuring reliability.

**Goals:**
- Catch and log all errors before users report them
- Quick diagnosis of production issues
- Proactive alerting on critical failures
- Performance monitoring and bottleneck identification
- Audit trail for security and compliance

---

## Error Tracking Stack

### Recommended Tools

**Primary: Sentry** (Error tracking & monitoring)
- Real-time error tracking
- Stack traces with context
- Release tracking
- Performance monitoring
- 30-day free trial, then $26/month

**Alternative: AppSignal** (Elixir-native)
- Built specifically for Elixir
- Excellent BEAM VM monitoring
- Performance insights
- $79/month

**Budget Option: Built-in Logging**
- Elixir Logger
- File-based logs
- Log aggregation (ELK, Loki)
- Free (infrastructure cost only)

---

## Implementation

### Phase 1: Basic Error Logging (Week 1)

#### Install Sentry

```elixir
# mix.exs
defp deps do
  [
    {:sentry, "~> 10.0"},
    {:hackney, "~> 1.19"}, # HTTP client for Sentry
    {:jason, "~> 1.4"}     # JSON parser
  ]
end
```

#### Configure Sentry

```elixir
# config/config.exs
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: Mix.env(),
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()],
  tags: %{
    env: Mix.env()
  },
  included_environments: [:prod, :staging],
  
  # Sample rate for performance monitoring
  traces_sample_rate: 0.1,
  
  # Before send callback - add custom context
  before_send: {Dash.Sentry, :before_send}

# Don't log in test
config :sentry, :included_environments, [:prod, :staging]
```

```elixir
# config/prod.exs
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: :prod,
  enable_source_code_context: true
```

#### Set Up Error Handler

```elixir
# lib/dash/sentry.ex
defmodule Dash.Sentry do
  @moduledoc """
  Sentry integration and error reporting utilities.
  """

  require Logger

  @doc """
  Called before sending error to Sentry.
  Adds custom context like user info, request details.
  """
  def before_send(event, hint) do
    # Add custom context
    event = add_user_context(event)
    event = add_request_context(event)
    event = add_custom_tags(event)
    
    # Log locally as well
    Logger.error("Sentry error: #{inspect(event.message)}")
    
    event
  end

  defp add_user_context(event) do
    # Add user info if available
    case get_current_user() do
      nil -> event
      user ->
        user_context = %{
          id: user.id,
          email: user.email,
          role: user.role
        }
        put_in(event, [:user], user_context)
    end
  end

  defp add_request_context(event) do
    # Add request details if in web context
    case Process.get(:phoenix_endpoint_pid) do
      nil -> event
      _ ->
        request_context = %{
          url: get_request_url(),
          method: get_request_method(),
          headers: get_safe_headers()
        }
        put_in(event, [:request], request_context)
    end
  end

  defp add_custom_tags(event) do
    tags = %{
      server: System.get_env("HOSTNAME") || "unknown",
      release: Application.spec(:dash, :vsn) |> to_string(),
      beam_version: :erlang.system_info(:otp_release) |> to_string()
    }
    
    update_in(event, [:tags], &Map.merge(&1 || %{}, tags))
  end

  # Helper to report errors manually
  def report_error(error, context \\ %{}) do
    Sentry.capture_exception(error, extra: context)
  end

  # Helper to report messages
  def report_message(message, level \\ :info, context \\ %{}) do
    Sentry.capture_message(message, level: level, extra: context)
  end

  defp get_current_user do
    # Implement based on your auth system
    nil
  end

  defp get_request_url, do: nil
  defp get_request_method, do: nil
  defp get_safe_headers, do: %{}
end
```

#### Integrate with Phoenix

```elixir
# lib/dash_web/endpoint.ex
defmodule DashWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :dash
  use Sentry.PlugContext  # Add this line

  # ... rest of endpoint configuration
end
```

#### Add Plug for Error Capture

```elixir
# lib/dash_web/router.ex
defmodule DashWeb.Router do
  use DashWeb, :router

  pipeline :browser do
    # ... existing plugs
    plug Sentry.PlugCapture  # Capture errors
  end

  pipeline :api do
    # ... existing plugs
    plug Sentry.PlugCapture  # Capture errors
  end
end
```

---

### Phase 2: Structured Logging (Week 2)

#### Configure Logger

```elixir
# config/prod.exs
config :logger,
  level: :info,
  backends: [:console],
  compile_time_purge_matching: [
    [level_lower_than: :info]
  ]

# Structured logging format
config :logger, :console,
  format: {Dash.Logger.Formatter, :format},
  metadata: [
    :request_id,
    :user_id,
    :team_id,
    :pipeline_id,
    :dashboard_id,
    :error_type,
    :stacktrace
  ]
```

#### Custom Logger Formatter

```elixir
# lib/dash/logger/formatter.ex
defmodule Dash.Logger.Formatter do
  @moduledoc """
  Custom JSON logger formatter for structured logging.
  """

  def format(level, message, timestamp, metadata) do
    %{
      timestamp: format_timestamp(timestamp),
      level: level,
      message: IO.iodata_to_binary(message),
      metadata: format_metadata(metadata),
      node: node(),
      pid: inspect(self())
    }
    |> Jason.encode!()
    |> Kernel.<>("\n")
  rescue
    _ -> "#{inspect(level)}: #{inspect(message)}\n"
  end

  defp format_timestamp({date, {h, m, s, ms}}) do
    {year, month, day} = date
    
    "#{year}-#{pad(month)}-#{pad(day)}T#{pad(h)}:#{pad(m)}:#{pad(s)}.#{pad3(ms)}Z"
  end

  defp format_metadata(metadata) do
    metadata
    |> Enum.into(%{})
    |> Map.take([
      :request_id,
      :user_id,
      :team_id,
      :pipeline_id,
      :dashboard_id,
      :error_type,
      :module,
      :function,
      :file,
      :line
    ])
  end

  defp pad(int) when int < 10, do: "0#{int}"
  defp pad(int), do: to_string(int)

  defp pad3(int) when int < 10, do: "00#{int}"
  defp pad3(int) when int < 100, do: "0#{int}"
  defp pad3(int), do: to_string(int)
end
```

#### Add Context to Logs

```elixir
# lib/dash_web/plugs/log_context.ex
defmodule DashWeb.Plugs.LogContext do
  @moduledoc """
  Adds context to Logger metadata for all requests.
  """
  
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    # Add request context
    Logger.metadata(request_id: get_request_id(conn))
    
    # Add user context if authenticated
    if user = conn.assigns[:current_user] do
      Logger.metadata(
        user_id: user.id,
        team_id: get_current_team_id(conn)
      )
    end

    conn
  end

  defp get_request_id(conn) do
    case Plug.Conn.get_req_header(conn, "x-request-id") do
      [id] -> id
      _ -> Ecto.UUID.generate()
    end
  end

  defp get_current_team_id(conn) do
    conn.assigns[:current_team]?.id
  end
end
```

```elixir
# Add to router
pipeline :browser do
  plug DashWeb.Plugs.LogContext  # Add this
  # ... other plugs
end
```

---

### Phase 3: Application-Specific Logging

#### Pipeline Error Handling

```elixir
# lib/dash/pipelines/workers/polling_worker.ex
defmodule Dash.Pipelines.Workers.PollingWorker do
  use Oban.Worker, queue: :pipelines, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"pipeline_id" => pipeline_id}} = job) do
    Logger.metadata(pipeline_id: pipeline_id, job_id: job.id)
    Logger.info("Starting pipeline execution", pipeline_id: pipeline_id)

    pipeline = Dash.Pipelines.get_pipeline!(pipeline_id)
    
    try do
      {:ok, data} = fetch_data(pipeline)
      Logger.debug("Fetched #{length(data)} records", pipeline_id: pipeline_id)
      
      transformed = transform_data(data, pipeline)
      Logger.debug("Transformed data", pipeline_id: pipeline_id)
      
      persist_data(transformed, pipeline)
      Logger.info("Pipeline execution complete", 
        pipeline_id: pipeline_id,
        records: length(transformed)
      )
      
      :ok
    rescue
      error ->
        Logger.error("Pipeline execution failed",
          pipeline_id: pipeline_id,
          error: inspect(error),
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        )
        
        # Report to Sentry with context
        Dash.Sentry.report_error(error, %{
          pipeline_id: pipeline_id,
          pipeline_name: pipeline.name,
          source_type: pipeline.source_type,
          job_id: job.id,
          attempt: job.attempt
        })
        
        # Notify team
        notify_pipeline_failure(pipeline, error)
        
        {:error, error}
    end
  end

  defp fetch_data(pipeline) do
    # Implementation with error handling
  end

  defp notify_pipeline_failure(pipeline, error) do
    Dash.Notifications.send_pipeline_error(pipeline, %{
      error: Exception.message(error),
      timestamp: DateTime.utc_now()
    })
  end
end
```

#### Database Query Logging

```elixir
# config/config.exs
config :dash, Dash.Repo,
  # Log slow queries (>100ms)
  log: :info,
  telemetry_prefix: [:dash, :repo]

# lib/dash/repo.ex
defmodule Dash.Repo do
  use Ecto.Repo,
    otp_app: :dash,
    adapter: Ecto.Adapters.Postgres

  # Log all queries in development
  if Mix.env() == :dev do
    def default_options(_operation) do
      [log: :debug]
    end
  end
end
```

```elixir
# lib/dash/telemetry.ex - Add slow query logging
defmodule Dash.Telemetry do
  require Logger

  def handle_event([:dash, :repo, :query], measurements, metadata, _config) do
    # Log slow queries
    if measurements.total_time > 100_000_000 do # 100ms in nanoseconds
      Logger.warning("Slow database query detected",
        duration_ms: measurements.total_time / 1_000_000,
        query: metadata.query,
        source: metadata.source,
        params: inspect(metadata.params)
      )
      
      # Report to Sentry
      Dash.Sentry.report_message(
        "Slow database query: #{metadata.query}",
        :warning,
        %{
          duration_ms: measurements.total_time / 1_000_000,
          source: metadata.source
        }
      )
    end
  end
end
```

#### LiveView Error Handling

```elixir
# lib/dash_web/live/dashboard_live.ex
defmodule DashWeb.DashboardLive do
  use DashWeb, :live_view

  require Logger

  @impl true
  def mount(params, session, socket) do
    Logger.metadata(dashboard_id: params["id"])
    
    try do
      dashboard = load_dashboard(params["id"], session)
      {:ok, assign(socket, dashboard: dashboard)}
    rescue
      error ->
        Logger.error("Failed to load dashboard",
          dashboard_id: params["id"],
          error: inspect(error)
        )
        
        Dash.Sentry.report_error(error, %{
          dashboard_id: params["id"],
          user_id: socket.assigns[:current_user]?.id
        })
        
        {:ok, 
         socket
         |> put_flash(:error, "Failed to load dashboard")
         |> redirect(to: "/")}
    end
  end

  @impl true
  def handle_event("refresh_data", _params, socket) do
    Logger.info("Refreshing dashboard data",
      dashboard_id: socket.assigns.dashboard.id
    )
    
    case refresh_dashboard_data(socket.assigns.dashboard) do
      {:ok, data} ->
        {:noreply, assign(socket, data: data)}
      
      {:error, reason} ->
        Logger.error("Failed to refresh dashboard",
          dashboard_id: socket.assigns.dashboard.id,
          reason: inspect(reason)
        )
        
        {:noreply, put_flash(socket, :error, "Failed to refresh data")}
    end
  end
end
```

---

## Log Aggregation

### Option 1: ELK Stack (Self-Hosted)

**Elasticsearch + Logstash + Kibana**

```yaml
# docker-compose.yml addition
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"

  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
    volumes:
      - ./config/logstash.conf:/usr/share/logstash/pipeline/logstash.conf:ro
    depends_on:
      - elasticsearch

  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch
```

```conf
# config/logstash.conf
input {
  file {
    path => "/var/log/dash/*.log"
    codec => json
    type => "dash_logs"
  }
}

filter {
  if [type] == "dash_logs" {
    json {
      source => "message"
    }
    
    date {
      match => ["timestamp", "ISO8601"]
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "dash-logs-%{+YYYY.MM.dd}"
  }
}
```

### Option 2: Grafana Loki (Lightweight)

**Recommended for most deployments**

```elixir
# Send logs to Loki
# mix.exs
{:logger_loki, "~> 0.5"}
```

```elixir
# config/prod.exs
config :logger,
  backends: [:console, LoggerLoki]

config :logger, LoggerLoki,
  url: "http://loki:3100",
  level: :info,
  metadata: [:request_id, :user_id, :team_id],
  labels: %{
    application: "dash",
    environment: "production"
  }
```

### Option 3: Cloud Services

**Papertrail** (Simple, affordable)
```elixir
# config/prod.exs
config :logger,
  backends: [:console, LoggerPapertrailBackend.Logger]

config :logger, :logger_papertrail_backend,
  host: "logs.papertrailapp.com",
  port: 12345,
  level: :info
```

**Datadog** (Enterprise)
```elixir
# config/prod.exs
config :logger, :console,
  format: {Dash.Logger.DatadogFormatter, :format}
```

---

## Error Alerting

### Configure Alert Rules

```elixir
# lib/dash/monitoring/alerts.ex
defmodule Dash.Monitoring.Alerts do
  @moduledoc """
  Alert rules for critical errors.
  """

  require Logger

  # Alert if error rate exceeds threshold
  def check_error_rate do
    last_hour_errors = count_errors_last_hour()
    
    cond do
      last_hour_errors > 100 ->
        send_critical_alert("High error rate: #{last_hour_errors} errors/hour")
      
      last_hour_errors > 50 ->
        send_warning_alert("Elevated error rate: #{last_hour_errors} errors/hour")
      
      true ->
        :ok
    end
  end

  # Alert if critical pipeline fails
  def check_pipeline_health(pipeline_id) do
    failures = count_pipeline_failures(pipeline_id, hours: 1)
    
    if failures >= 3 do
      pipeline = Dash.Pipelines.get_pipeline!(pipeline_id)
      
      send_critical_alert(
        "Pipeline '#{pipeline.name}' failed 3 times in last hour",
        %{
          pipeline_id: pipeline_id,
          team_id: pipeline.team_id
        }
      )
      
      # Notify team
      notify_team(pipeline.team_id, :pipeline_failure, pipeline)
    end
  end

  # Alert on database issues
  def check_database_health do
    case Dash.Repo.query("SELECT 1") do
      {:ok, _} -> :ok
      {:error, reason} ->
        send_critical_alert(
          "Database health check failed: #{inspect(reason)}"
        )
    end
  end

  defp send_critical_alert(message, context \\ %{}) do
    Logger.error(message, context)
    
    # Send to PagerDuty/OpsGenie
    send_pagerduty_alert(message, :critical, context)
    
    # Send to Slack
    send_slack_alert(message, :critical, context)
    
    # Report to Sentry
    Dash.Sentry.report_message(message, :error, context)
  end

  defp send_warning_alert(message, context \\ %{}) do
    Logger.warning(message, context)
    send_slack_alert(message, :warning, context)
  end

  defp send_slack_alert(message, level, context) do
    webhook_url = Application.get_env(:dash, :slack_webhook_url)
    
    if webhook_url do
      payload = %{
        text: message,
        attachments: [
          %{
            color: alert_color(level),
            fields: format_context_fields(context),
            footer: "Dash Monitoring",
            ts: System.system_time(:second)
          }
        ]
      }
      
      HTTPoison.post(webhook_url, Jason.encode!(payload), [
        {"Content-Type", "application/json"}
      ])
    end
  end

  defp alert_color(:critical), do: "danger"
  defp alert_color(:warning), do: "warning"
  defp alert_color(_), do: "good"

  defp format_context_fields(context) do
    Enum.map(context, fn {key, value} ->
      %{
        title: to_string(key),
        value: inspect(value),
        short: true
      }
    end)
  end
end
```

### Scheduled Health Checks

```elixir
# lib/dash/monitoring/health_checker.ex
defmodule Dash.Monitoring.HealthChecker do
  use GenServer

  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    # Run health checks every 5 minutes
    schedule_check()
    {:ok, state}
  end

  def handle_info(:check_health, state) do
    Logger.debug("Running health checks")
    
    # Check various systems
    check_database()
    check_redis()
    check_pipelines()
    check_disk_space()
    check_memory()
    
    schedule_check()
    {:noreply, state}
  end

  defp schedule_check do
    Process.send_after(self(), :check_health, :timer.minutes(5))
  end

  defp check_database do
    case Dash.Repo.query("SELECT 1", [], timeout: 5000) do
      {:ok, _} -> :ok
      {:error, reason} ->
        Dash.Monitoring.Alerts.send_critical_alert(
          "Database health check failed",
          %{reason: inspect(reason)}
        )
    end
  end

  defp check_redis do
    case Redix.command(:redix, ["PING"]) do
      {:ok, "PONG"} -> :ok
      error ->
        Dash.Monitoring.Alerts.send_warning_alert(
          "Redis health check failed",
          %{error: inspect(error)}
        )
    end
  end

  defp check_pipelines do
    # Check for stuck pipelines
    stuck_pipelines = Dash.Pipelines.list_stuck_pipelines()
    
    if length(stuck_pipelines) > 0 do
      Dash.Monitoring.Alerts.send_warning_alert(
        "#{length(stuck_pipelines)} pipelines appear stuck",
        %{pipeline_ids: Enum.map(stuck_pipelines, & &1.id)}
      )
    end
  end

  defp check_disk_space do
    {result, _} = System.cmd("df", ["-h", "/"])
    
    if String.contains?(result, "9%") or String.contains?(result, "100%") do
      Dash.Monitoring.Alerts.send_critical_alert("Disk space critical")
    end
  end

  defp check_memory do
    memory = :erlang.memory()
    total_mb = memory[:total] / 1_000_000
    
    if total_mb > 2000 do # 2GB
      Dash.Monitoring.Alerts.send_warning_alert(
        "High memory usage: #{trunc(total_mb)}MB"
      )
    end
  end
end
```

---

## Metrics & Performance Monitoring

### Telemetry Integration

Already covered in monitoring section, but key metrics:

```elixir
# Key metrics to track
- Pipeline execution duration
- Pipeline failure rate
- Database query duration
- LiveView mount time
- API response time
- Memory usage
- Process count
- Error rate
```

---

## Development vs Production

### Development

```elixir
# config/dev.exs
config :logger, :console,
  format: "[$level] $message\n",
  metadata: [:request_id]

# Don't send to Sentry in dev
config :sentry, included_environments: []
```

### Production

```elixir
# config/prod.exs
config :logger,
  level: :info,
  backends: [:console, LoggerLoki]

# Send errors to Sentry
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  included_environments: [:prod]
```

---

## Common Error Patterns to Log

### 1. Authentication Failures

```elixir
Logger.warning("Failed login attempt",
  email: email,
  ip: ip_address,
  reason: "invalid_password"
)
```

### 2. API Rate Limiting

```elixir
Logger.info("Rate limit exceeded",
  user_id: user_id,
  endpoint: endpoint,
  limit: limit
)
```

### 3. Pipeline Failures

```elixir
Logger.error("Pipeline execution failed",
  pipeline_id: pipeline_id,
  error_type: error_type,
  attempt: attempt_number
)
```

### 4. Data Validation Errors

```elixir
Logger.warning("Invalid data received",
  pipeline_id: pipeline_id,
  validation_errors: errors
)
```

### 5. External API Failures

```elixir
Logger.error("External API request failed",
  api: "stripe",
  endpoint: endpoint,
  status_code: status,
  response: response_body
)
```

---

## Debugging Production Issues

### Log Search Queries

**Find all errors for a user:**
```
level:error AND user_id:USER_ID
```

**Find slow database queries:**
```
message:"Slow database query" AND duration_ms:>1000
```

**Find failed pipelines:**
```
pipeline_id:* AND level:error
```

**Find authentication issues:**
```
message:*authentication* OR message:*login*
```

### Using Sentry for Debugging

1. **Find the error** in Sentry dashboard
2. **View stack trace** with source context
3. **Check breadcrumbs** (what happened before error)
4. **Review user context** (who experienced it)
5. **Check similar errors** (is this a pattern?)
6. **Create issue** in GitHub from Sentry

---

## Monitoring Dashboard

### Key Metrics to Display

```
┌─────────────────────────────────────┐
│ System Health                       │
├─────────────────────────────────────┤
│ • Error Rate: 0.1% (↓ 0.05%)       │
│ • Response Time: 120ms (p95)        │
│ • Active Pipelines: 245             │
│ • Failed Pipelines (1h): 2          │
│ • Database Queries/sec: 450         │
│ • Memory Usage: 45%                 │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Recent Errors                       │
├─────────────────────────────────────┤
│ 2 min ago │ Pipeline timeout        │
│ 5 min ago │ Database connection     │
│ 12 min ago│ Rate limit exceeded     │
└─────────────────────────────────────┘
```

---

## Roadmap

### Phase 1 (Week 1) - Essential
- [ ] Install and configure Sentry
- [ ] Add error tracking to pipeline workers
- [ ] Configure structured logging
- [ ] Set up basic alerts

### Phase 2 (Week 2) - Production Ready
- [ ] Add log aggregation (Loki or ELK)
- [ ] Create monitoring dashboard
- [ ] Set up health checks
- [ ] Configure Slack alerts

### Phase 3 (Month 2) - Advanced
- [ ] Performance monitoring
- [ ] Custom metrics dashboard
- [ ] Automated error analysis
- [ ] Predictive alerting

---

## Cost Estimates

| Tool | Free Tier | Paid (Startup) | Enterprise |
|------|-----------|----------------|------------|
| **Sentry** | 5K events/mo | $26/mo | $80+/mo |
| **AppSignal** | 30-day trial | $79/mo | Custom |
| **Papertrail** | 50MB/mo | $7/mo | $230+/mo |
| **Datadog** | 14-day trial | $15/host/mo | $23+/host/mo |
| **Self-Hosted (ELK)** | Infrastructure only | ~$50/mo | $200+/mo |

**Recommended Stack:**
- **Development:** Built-in Logger (Free)
- **Small Production:** Sentry ($26/mo) + Papertrail ($7/mo) = **$33/mo**
- **Growing:** Sentry ($80/mo) + Loki (self-hosted $50/mo) = **$130/mo**
- **Enterprise:** AppSignal ($79/mo) + Datadog ($15/host) = **$150+/mo**

---

## Best Practices

✅ **DO:**
- Log at appropriate levels (debug, info, warning, error)
- Include context (user_id, request_id, resource_id)
- Use structured logging (JSON format)
- Set up alerts for critical errors
- Review logs regularly
- Rotate log files
- Monitor disk space

❌ **DON'T:**
- Log sensitive data (passwords, tokens, credit cards)
- Log at debug level in production
- Ignore warnings
- Let log files grow unbounded
- Alert on every error (alert fatigue)
- Log in tight loops (performance impact)

---

## Next Steps

1. Install Sentry and configure basic error tracking
2. Add structured logging to critical paths
3. Set up Slack webhooks for alerts
4. Create monitoring dashboard
5. Document common error patterns
6. Train team on using logging tools

---

**Questions?** See [Monitoring Strategy](10-monitoring.md) for metrics and performance monitoring.

**Support:** devops@dash.app