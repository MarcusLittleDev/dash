## Deployment Strategy

### Phase 1: Fly.io Deployment

```dockerfile
# Dockerfile
FROM hexpm/elixir:1.16.0-erlang-26.2.1-alpine-3.19.0 AS build

WORKDIR /app

RUN apk add --no-cache git build-base npm

RUN mix local.hex --force && \
    mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only prod
RUN mix deps.compile

COPY assets assets
COPY lib lib
COPY priv priv

RUN mix assets.deploy
RUN mix compile
RUN mix release

FROM alpine:3.19.0 AS app

RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app

COPY --from=build /app/_build/prod/rel/dash ./

RUN addgroup -g 1000 dash && \
    adduser -D -u 1000 -G dash dash && \
    chown -R dash:dash /app

USER dash

ENV HOME=/app
ENV MIX_ENV=prod

EXPOSE 4000

CMD ["/app/bin/dash", "start"]
```

```toml
# fly.toml
app = "dash"
primary_region = "iad"

[build]

[env]
  PHX_HOST = "dash.fly.dev"
  PORT = "4000"

[[services]]
  internal_port = 4000
  protocol = "tcp"

  [[services.ports]]
    port = 80
    handlers = ["http"]
    force_https = true

  [[services.ports]]
    port = 443
    handlers = ["tls", "http"]

  [services.concurrency]
    type = "connections"
    hard_limit = 1000
    soft_limit = 800

[[vm]]
  cpu_kind = "shared"
  cpus = 2
  memory_mb = 2048
```

### Deployment Commands

```bash
# Initial setup
fly launch
fly postgres create
fly postgres attach

# Set secrets
fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
fly secrets set ENCRYPTION_KEY=$(openssl rand -base64 32)

# Deploy
fly deploy

# Scale
fly scale count 3
fly scale vm shared-cpu-2x

# Monitor
fly logs
fly status
```

### Phase 2: Multi-Region (If Needed)

```bash
# Add regions
fly regions add ord lax
fly scale count 6  # 2 per region
```

---

