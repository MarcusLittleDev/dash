# Self-Hosted Deployment - Technical Guide

> **Note:** This is for Phase 3 (Month 12+) after core product is stable.
> 
> **For Months 1-11:** Use native development (`mix phx.server`) and deploy to Fly.io.

## Overview

This guide covers the technical implementation of self-hosted deployments for enterprise customers.

**Timeline:**
- **Months 1-8:** Native development, no Docker
- **Months 9-11:** Fly.io cloud deployment
- **Month 12+:** Add self-hosted capability (this document)

---

## Architecture

### Self-Hosted Stack

```
┌─────────────────────────────────────────┐
│          Customer Infrastructure        │
│                                         │
│  ┌──────────┐  ┌──────────┐           │
│  │  Nginx   │  │  Dash    │           │
│  │  (SSL)   │→ │  App     │           │
│  └──────────┘  └─────┬────┘           │
│                      │                 │
│                      ↓                 │
│  ┌──────────┐  ┌──────────┐           │
│  │TimescaleDB│  │  Redis   │           │
│  │(Postgres)│  │  Cache   │           │
│  └──────────┘  └──────────┘           │
│                                         │
│  ┌──────────────────────────┐         │
│  │  Customer's S3/MinIO     │         │
│  │  (File Storage)          │         │
│  └──────────────────────────┘         │
└─────────────────────────────────────────┘
```

---

## Docker Setup

### Dockerfile (Production)

```dockerfile
# Dockerfile
# Multi-stage build for optimal image size

# ============================================
# Stage 1: Build
# ============================================
FROM hexpm/elixir:1.16.0-erlang-26.2.1-alpine-3.19.0 AS build

# Install build dependencies
RUN apk add --no-cache \
    git \
    build-base \
    nodejs \
    npm

WORKDIR /app

# Install Hex and Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy dependency files
COPY mix.exs mix.lock ./
COPY config config

# Install dependencies
ENV MIX_ENV=prod
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy application code
COPY lib lib
COPY priv priv
COPY assets assets

# Compile assets
RUN cd assets && npm ci --prefer-offline --no-audit --progress=false
RUN mix assets.deploy

# Compile application
RUN mix compile

# Build release
RUN mix release

# ============================================
# Stage 2: Runtime
# ============================================
FROM alpine:3.19.0 AS app

# Install runtime dependencies
RUN apk add --no-cache \
    libstdc++ \
    openssl \
    ncurses-libs \
    ca-certificates

WORKDIR /app

# Create non-root user
RUN addgroup -g 1000 dash && \
    adduser -D -u 1000 -G dash dash

# Copy release from build stage
COPY --from=build --chown=dash:dash /app/_build/prod/rel/dash ./

USER dash

# Environment
ENV HOME=/app
ENV MIX_ENV=prod
ENV LANG=C.UTF-8

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD ["/app/bin/dash", "rpc", "1 + 1"]

# Expose port
EXPOSE 4000

# Start application
CMD ["/app/bin/dash", "start"]
```

### .dockerignore

```
# .dockerignore
# Exclude unnecessary files from Docker build

# Development
_build/
deps/
.elixir_ls/
.fetch

# Assets
/assets/node_modules/
npm-debug.log

# Test
/cover/
/test/

# Documentation
/docs/

# Git
.git/
.gitignore

# Environment
.env
.env.*

# OS
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/

# Logs
*.log
```

---

## Docker Compose Configuration

### docker-compose.yml (Full Stack)

```yaml
# docker-compose.yml
# Complete self-hosted deployment

version: '3.8'

services:
  # ============================================
  # Dash Application
  # ============================================
  dash:
    image: dash/dash:${VERSION:-latest}
    container_name: dash-app
    restart: unless-stopped
    
    ports:
      - "4000:4000"
    
    environment:
      # Database
      DATABASE_URL: "ecto://postgres:${DB_PASSWORD}@db:5432/dash_prod"
      POOL_SIZE: "10"
      
      # Application
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
      ENCRYPTION_KEY: ${ENCRYPTION_KEY}
      PHX_HOST: ${PHX_HOST}
      PHX_SERVER: "true"
      PORT: "4000"
      
      # Self-hosted mode
      SELF_HOSTED: "true"
      LICENSE_KEY: ${LICENSE_KEY}
      
      # Storage
      STORAGE_ADAPTER: "s3"
      STORAGE_BUCKET: ${STORAGE_BUCKET:-dash-files}
      STORAGE_ENDPOINT: ${STORAGE_ENDPOINT}
      STORAGE_ACCESS_KEY: ${STORAGE_ACCESS_KEY}
      STORAGE_SECRET_KEY: ${STORAGE_SECRET_KEY}
      STORAGE_PATH_STYLE: "true"
      
      # Redis
      REDIS_URL: "redis://redis:6379/0"
      
      # Release
      RELEASE_NODE: "dash@127.0.0.1"
      RELEASE_COOKIE: ${RELEASE_COOKIE}
    
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    
    volumes:
      # Uploads (if not using S3)
      - dash_uploads:/app/uploads
      # Logs
      - dash_logs:/app/logs
    
    networks:
      - dash_network
    
    healthcheck:
      test: ["CMD", "/app/bin/dash", "rpc", "1 + 1"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 40s

  # ============================================
  # PostgreSQL + TimescaleDB
  # ============================================
  db:
    image: timescale/timescaledb:latest-pg16
    container_name: dash-db
    restart: unless-stopped
    
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: dash_prod
      # Performance tuning
      POSTGRES_SHARED_BUFFERS: 256MB
      POSTGRES_EFFECTIVE_CACHE_SIZE: 1GB
      POSTGRES_MAINTENANCE_WORK_MEM: 128MB
      POSTGRES_WAL_BUFFERS: 16MB
    
    ports:
      - "5432:5432"
    
    volumes:
      - postgres_data:/var/lib/postgresql/data
      # Custom PostgreSQL config
      - ./config/postgresql.conf:/etc/postgresql/postgresql.conf:ro
    
    command: postgres -c config_file=/etc/postgresql/postgresql.conf
    
    networks:
      - dash_network
    
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ============================================
  # Redis (Cache & Queue)
  # ============================================
  redis:
    image: redis:7-alpine
    container_name: dash-redis
    restart: unless-stopped
    
    command: redis-server --appendonly yes --maxmemory 512mb --maxmemory-policy allkeys-lru
    
    ports:
      - "6379:6379"
    
    volumes:
      - redis_data:/data
    
    networks:
      - dash_network
    
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3

  # ============================================
  # Nginx (Reverse Proxy)
  # ============================================
  nginx:
    image: nginx:alpine
    container_name: dash-nginx
    restart: unless-stopped
    
    ports:
      - "80:80"
      - "443:443"
    
    volumes:
      - ./config/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
      - nginx_logs:/var/log/nginx
    
    depends_on:
      - dash
    
    networks:
      - dash_network
    
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost/health"]
      interval: 30s
      timeout: 3s
      retries: 3

# ============================================
# Volumes
# ============================================
volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
  dash_uploads:
    driver: local
  dash_logs:
    driver: local
  nginx_logs:
    driver: local

# ============================================
# Networks
# ============================================
networks:
  dash_network:
    driver: bridge
```

### .env.example

```bash
# .env.example
# Copy to .env and fill in values

# ============================================
# Application
# ============================================
VERSION=1.0.0
PHX_HOST=dash.company.com

# Generate with: mix phx.gen.secret
SECRET_KEY_BASE=

# Generate with: openssl rand -base64 32
ENCRYPTION_KEY=

# Generate with: openssl rand -base64 32
RELEASE_COOKIE=

# ============================================
# Database
# ============================================
# Generate with: openssl rand -base64 32
DB_PASSWORD=

# ============================================
# License
# ============================================
# Provided by Dash support
LICENSE_KEY=

# ============================================
# Storage (S3/MinIO)
# ============================================
STORAGE_ENDPOINT=https://minio.company.com
STORAGE_BUCKET=dash-files
STORAGE_ACCESS_KEY=
STORAGE_SECRET_KEY=

# ============================================
# Optional: SAML Authentication
# ============================================
# SAML_ENABLED=true
# SAML_IDP_METADATA_URL=https://sso.company.com/metadata
# SAML_SP_ENTITY_ID=https://dash.company.com

# ============================================
# Optional: LDAP Authentication
# ============================================
# LDAP_ENABLED=true
# LDAP_HOST=ldap.company.com
# LDAP_PORT=636
# LDAP_SSL=true
# LDAP_BASE_DN=dc=company,dc=com
# LDAP_BIND_DN=cn=dash-service,ou=services,dc=company,dc=com
# LDAP_BIND_PASSWORD=

# ============================================
# Optional: Monitoring
# ============================================
# SYSLOG_ENABLED=false
# SYSLOG_HOST=syslog.company.com
# SYSLOG_PORT=514

# PROMETHEUS_ENABLED=true
# PROMETHEUS_PORT=9090
```

---

## Nginx Configuration

### nginx.conf

```nginx
# config/nginx.conf
# Nginx reverse proxy configuration

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript 
               application/json application/javascript application/xml+rss;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=webhook_limit:10m rate=100r/s;

    # Upstream
    upstream dash_backend {
        server dash:4000;
        keepalive 32;
    }

    # HTTP -> HTTPS redirect
    server {
        listen 80;
        server_name _;
        
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
        
        location / {
            return 301 https://$host$request_uri;
        }
    }

    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name dash.company.com;

        # SSL certificates
        ssl_certificate /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;
        
        # SSL configuration
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;

        # Security headers
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;

        # Health check (no rate limit)
        location /health {
            access_log off;
            proxy_pass http://dash_backend;
        }

        # Webhook endpoints (higher rate limit)
        location /webhooks/ {
            limit_req zone=webhook_limit burst=20 nodelay;
            
            proxy_pass http://dash_backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Larger timeouts for webhooks
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }

        # API endpoints
        location /api/ {
            limit_req zone=api_limit burst=5 nodelay;
            
            proxy_pass http://dash_backend;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # WebSocket (LiveView)
        location /live/ {
            proxy_pass http://dash_backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # WebSocket timeouts
            proxy_connect_timeout 7d;
            proxy_send_timeout 7d;
            proxy_read_timeout 7d;
        }

        # Static files (cache)
        location /assets/ {
            proxy_pass http://dash_backend;
            proxy_cache_valid 200 1y;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # All other requests
        location / {
            proxy_pass http://dash_backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Timeouts
            proxy_connect_timeout 30s;
            proxy_send_timeout 30s;
            proxy_read_timeout 30s;
        }
    }
}
```

---

## PostgreSQL Configuration

### postgresql.conf

```conf
# config/postgresql.conf
# TimescaleDB optimized configuration

# ============================================
# Connections
# ============================================
max_connections = 100
shared_buffers = 256MB

# ============================================
# Memory
# ============================================
effective_cache_size = 1GB
maintenance_work_mem = 128MB
work_mem = 10MB
wal_buffers = 16MB

# ============================================
# Write-Ahead Logging
# ============================================
wal_level = replica
max_wal_size = 1GB
min_wal_size = 80MB
checkpoint_completion_target = 0.9

# ============================================
# Query Tuning
# ============================================
random_page_cost = 1.1  # For SSD
effective_io_concurrency = 200

# ============================================
# Logging
# ============================================
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 100MB
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_timezone = 'UTC'

# Log slow queries
log_min_duration_statement = 1000  # 1 second

# ============================================
# TimescaleDB
# ============================================
shared_preload_libraries = 'timescaledb'
timescaledb.max_background_workers = 8

# ============================================
# Locale
# ============================================
datestyle = 'iso, mdy'
timezone = 'UTC'
lc_messages = 'en_US.utf8'
lc_monetary = 'en_US.utf8'
lc_numeric = 'en_US.utf8'
lc_time = 'en_US.utf8'
default_text_search_config = 'pg_catalog.english'
```

---

## Installation Scripts

### generate-secrets.sh

```bash
#!/bin/bash
# scripts/generate-secrets.sh
# Generate secure random secrets for .env file

set -e

echo "Generating secrets for Dash self-hosted deployment..."
echo ""

# Check if .env exists
if [ -f .env ]; then
    echo "⚠️  .env file already exists!"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
    mv .env .env.backup
    echo "Backed up existing .env to .env.backup"
fi

# Generate secrets
echo "Generating secrets..."

SECRET_KEY_BASE=$(openssl rand -base64 64 | tr -d '\n')
ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -d '\n')
RELEASE_COOKIE=$(openssl rand -base64 32 | tr -d '\n')
DB_PASSWORD=$(openssl rand -base64 32 | tr -d '\n')

# Create .env
cat > .env << EOF
# ============================================
# Dash Self-Hosted Configuration
# Generated: $(date)
# ============================================

# Application
VERSION=1.0.0
PHX_HOST=dash.company.com
SECRET_KEY_BASE=$SECRET_KEY_BASE
ENCRYPTION_KEY=$ENCRYPTION_KEY
RELEASE_COOKIE=$RELEASE_COOKIE

# Database
DB_PASSWORD=$DB_PASSWORD

# License (obtain from Dash support)
LICENSE_KEY=your-license-key-here

# Storage (configure for your S3/MinIO)
STORAGE_ENDPOINT=https://minio.company.com
STORAGE_BUCKET=dash-files
STORAGE_ACCESS_KEY=your-storage-access-key
STORAGE_SECRET_KEY=your-storage-secret-key
EOF

echo ""
echo "✅ Secrets generated and saved to .env"
echo ""
echo "📋 Next steps:"
echo "1. Edit .env and set:"
echo "   - PHX_HOST (your domain)"
echo "   - LICENSE_KEY (from Dash support)"
echo "   - Storage credentials"
echo ""
echo "2. Place SSL certificates in ./ssl/"
echo "   - fullchain.pem"
echo "   - privkey.pem"
echo ""
echo "3. Start services:"
echo "   docker-compose up -d"
echo ""
```

### backup.sh

```bash
#!/bin/bash
# scripts/backup.sh
# Backup Dash database and uploads

set -e

BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="dash_backup_${TIMESTAMP}.tar.gz"

echo "🗄️  Starting Dash backup..."

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup database
echo "Backing up database..."
docker-compose exec -T db pg_dump -U postgres dash_prod | gzip > "${BACKUP_DIR}/db_${TIMESTAMP}.sql.gz"

# Backup uploads (if using local storage)
echo "Backing up uploads..."
docker run --rm \
  --volumes-from dash-app \
  -v "$(pwd)/${BACKUP_DIR}:/backup" \
  alpine \
  tar czf "/backup/uploads_${TIMESTAMP}.tar.gz" /app/uploads

# Create combined backup
echo "Creating combined backup..."
tar czf "${BACKUP_DIR}/${BACKUP_FILE}" \
  "${BACKUP_DIR}/db_${TIMESTAMP}.sql.gz" \
  "${BACKUP_DIR}/uploads_${TIMESTAMP}.tar.gz"

# Cleanup intermediate files
rm "${BACKUP_DIR}/db_${TIMESTAMP}.sql.gz"
rm "${BACKUP_DIR}/uploads_${TIMESTAMP}.tar.gz"

# Keep only last 7 backups
echo "Cleaning old backups..."
ls -t "${BACKUP_DIR}"/dash_backup_*.tar.gz | tail -n +8 | xargs -r rm

echo "✅ Backup complete: ${BACKUP_DIR}/${BACKUP_FILE}"
echo "📦 Size: $(du -h "${BACKUP_DIR}/${BACKUP_FILE}" | cut -f1)"
```

### restore.sh

```bash
#!/bin/bash
# scripts/restore.sh
# Restore Dash from backup

set -e

if [ "$#" -ne 1 ]; then
    echo "Usage: ./restore.sh <backup-file>"
    echo "Example: ./restore.sh backups/dash_backup_20260109_120000.tar.gz"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "⚠️  This will OVERWRITE current data!"
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "📦 Extracting backup..."
tar xzf "$BACKUP_FILE" -C "$TEMP_DIR"

# Stop application
echo "Stopping Dash..."
docker-compose stop dash

# Restore database
echo "Restoring database..."
DB_FILE=$(ls "$TEMP_DIR"/db_*.sql.gz)
gunzip -c "$DB_FILE" | docker-compose exec -T db psql -U postgres dash_prod

# Restore uploads
echo "Restoring uploads..."
UPLOADS_FILE=$(ls "$TEMP_DIR"/uploads_*.tar.gz)
docker run --rm \
  --volumes-from dash-app \
  -v "$TEMP_DIR:/backup" \
  alpine \
  sh -c "rm -rf /app/uploads/* && tar xzf /backup/$(basename $UPLOADS_FILE) -C /"

# Start application
echo "Starting Dash..."
docker-compose start dash

echo "✅ Restore complete!"
echo "🔍 Check logs: docker-compose logs -f dash"
```

---

## License Validation Code

### Self-Hosted Configuration

```elixir
# config/runtime.exs additions for self-hosted

if System.get_env("SELF_HOSTED") == "true" do
  config :dash,
    self_hosted: true,
    license_key: System.get_env("LICENSE_KEY"),
    license_public_key: """
    -----BEGIN PUBLIC KEY-----
    [Embedded RSA public key for license verification]
    -----END PUBLIC KEY-----
    """
  
  # Disable Stripe
  config :dash, :stripe_enabled, false
  
  # Enable custom branding if licensed
  config :dash, :custom_branding_enabled,
    Dash.Licensing.feature_enabled?(:custom_branding)
end
```

---

## Monitoring

### Prometheus Metrics Endpoint

```elixir
# lib/dash_web/telemetry.ex
defmodule DashWeb.Telemetry do
  # Expose metrics for Prometheus
  def metrics do
    if Application.get_env(:dash, :self_hosted) do
      [
        # Self-hosted specific metrics
        last_value("dash.license.days_remaining"),
        last_value("dash.license.user_count"),
        counter("dash.license.validation.total",
          tags: [:status]
        )
      ] ++ standard_metrics()
    else
      standard_metrics()
    end
  end
end
```

### Grafana Dashboard

```json
{
  "dashboard": {
    "title": "Dash Self-Hosted Monitoring",
    "panels": [
      {
        "title": "License Status",
        "targets": [
          {
            "expr": "dash_license_days_remaining"
          }
        ]
      },
      {
        "title": "Active Users",
        "targets": [
          {
            "expr": "dash_license_user_count"
          }
        ]
      }
    ]
  }
}
```

---

## Upgrade Process

### upgrade.sh

```bash
#!/bin/bash
# scripts/upgrade.sh
# Upgrade Dash to a new version

set -e

if [ "$#" -ne 1 ]; then
    echo "Usage: ./upgrade.sh <version>"
    echo "Example: ./upgrade.sh 1.1.0"
    exit 1
fi

NEW_VERSION="$1"

echo "🚀 Upgrading Dash to version ${NEW_VERSION}..."

# Backup first
echo "Creating backup..."
./scripts/backup.sh

# Pull new image
echo "Pulling new image..."
docker pull "dash/dash:${NEW_VERSION}"

# Update .env
sed -i.bak "s/VERSION=.*/VERSION=${NEW_VERSION}/" .env

# Stop old version
echo "Stopping services..."
docker-compose down

# Start new version
echo "Starting new version..."
docker-compose up -d

# Run migrations
echo "Running migrations..."
docker-compose exec dash bin/dash eval "Dash.Release.migrate"

echo "✅ Upgrade complete!"
echo "🔍 Check logs: docker-compose logs -f dash"
```

---

## Troubleshooting

### Common Issues

**Database connection failed:**
```bash
# Check database is running
docker-compose ps db

# Check logs
docker-compose logs db

# Test connection
docker-compose exec db psql -U postgres -c "SELECT 1"
```

**License validation failed:**
```bash
# Check license key in .env
grep LICENSE_KEY .env

# Check license status
docker-compose exec dash bin/dash rpc "Dash.Licensing.validate_license()"
```

**High memory usage:**
```bash
# Check container stats
docker stats

# Adjust PostgreSQL memory
# Edit config/postgresql.conf
shared_buffers = 128MB  # Reduce if needed
```

**Slow queries:**
```bash
# Check slow query log
docker-compose exec db tail -f /var/lib/postgresql/data/log/postgresql-*.log

# Check active queries
docker-compose exec db psql -U postgres dash_prod -c "SELECT * FROM pg_stat_activity WHERE state = 'active';"
```

---

## Security Hardening

### Checklist

- [ ] SSL certificates installed and valid
- [ ] Strong passwords generated (32+ characters)
- [ ] Firewall rules configured (only 80/443 open)
- [ ] Database not exposed externally
- [ ] Regular backups automated
- [ ] Security updates applied monthly
- [ ] Audit logging enabled
- [ ] Rate limiting configured
- [ ] SAML/LDAP configured (if required)
- [ ] Monitoring alerts configured

### Security Best Practices

1. **Network Isolation:**
   - Database and Redis not accessible from internet
   - Only Nginx exposed publicly
   - Use internal Docker network

2. **Secrets Management:**
   - Never commit .env to git
   - Rotate secrets quarterly
   - Use strong random passwords

3. **Updates:**
   - Apply security updates within 48 hours
   - Test in staging first
   - Keep backups before upgrading

4. **Monitoring:**
   - Alert on failed login attempts
   - Monitor for unusual activity
   - Track license expiration

---

## Performance Tuning

### Database Optimization

```sql
-- Create indexes for common queries
CREATE INDEX CONCURRENTLY idx_pipeline_data_team_time 
  ON pipeline_data (team_id, ingested_at DESC);

-- Analyze tables
ANALYZE pipeline_data;

-- Vacuum regularly
VACUUM ANALYZE;
```

### Application Tuning

```elixir
# config/runtime.exs
config :dash, Dash.Repo,
  pool_size: System.get_env("POOL_SIZE") || "20",
  queue_target: 50,
  queue_interval: 1000
```

---

## Next Steps

1. **Review** this technical guide
2. **Prepare** production environment
3. **Test** in staging environment
4. **Document** customer-specific configuration
5. **Schedule** production deployment
6. **Monitor** post-deployment

---

**Support:** enterprise@dash.app  
**Documentation:**