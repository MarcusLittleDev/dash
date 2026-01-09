# Dash Development Environment Setup (CachyOS)

## ✅ Completed Steps

- [x] PostgreSQL installed and initialized
- [x] PostgreSQL service started

## 📋 Next Steps

### 1. Run PostgreSQL Setup Script

```bash
chmod +x setup-postgres.sh
./setup-postgres.sh
```

This will:
- Create your PostgreSQL user
- Create `dash_dev` and `dash_test` databases
- Install and enable TimescaleDB extension

### 2. Install Required System Packages

```bash
# Core development tools
sudo pacman -S elixir erlang nodejs npm git inotify-tools

# Optional but recommended
sudo pacman -S timescaledb  # For time-series data
```

### 3. Install VSCode Extensions

Open VSCode and install these extensions (or install via command line):

```bash
# Core Elixir/Phoenix
code --install-extension jakebecker.elixir-ls
code --install-extension phoenixframework.phoenix

# Tailwind CSS
code --install-extension bradlc.vscode-tailwindcss

# Database
code --install-extension ckolkman.vscode-postgres

# Git & Utilities
code --install-extension eamodio.gitlens
code --install-extension usernamehw.errorlens
code --install-extension yzhang.markdown-all-in-one
code --install-extension gruntfuggly.todo-tree
code --install-extension aaron-bond.better-comments
```

Or open the project in VSCode and it will prompt you to install recommended extensions.

### 4. Configure File Watching (Important for Phoenix Live Reload)

```bash
# Check current limit
cat /proc/sys/fs/inotify/max_user_watches

# If it's less than 524288, increase it
echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### 5. Initialize Phoenix Project

```bash
# Install Phoenix
mix archive.install hex phx_new

# Create new Phoenix project (if starting fresh)
mix phx.new dash --database postgres

# Or if continuing existing project
cd dash
mix deps.get
mix ecto.setup
```

### 6. Configure Environment

Create `.env` file in project root:

```bash
# Database
DATABASE_URL=ecto://YOUR_USERNAME:@localhost/dash_dev

# Phoenix
SECRET_KEY_BASE=your_secret_key_here_generate_with_mix_phx_gen_secret
PHX_HOST=localhost
PORT=4000

# Error Tracking (Sentry) - for later
SENTRY_DSN=

# Stripe (for billing - Phase 3) - for later
STRIPE_PUBLIC_KEY=
STRIPE_SECRET_KEY=

# File Storage (Cloudflare R2) - for later
R2_ACCESS_KEY_ID=
R2_SECRET_ACCESS_KEY=
```

Generate `SECRET_KEY_BASE`:
```bash
mix phx.gen.secret
```

### 7. Test Your Setup

```bash
# Start PostgreSQL (should already be running)
sudo systemctl status postgresql

# Test database connection
psql -l
psql dash_dev -c "SELECT version();"

# Install Elixir dependencies
mix deps.get

# Run database migrations
mix ecto.migrate

# Start Phoenix server
mix phx.server

# Or with IEx console
iex -S mix phx.server
```

Visit http://localhost:4000 to see your app!

## 🔧 Development Workflow

### Common Commands

```bash
# Start server
mix phx.server

# Start with console
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
mix ecto.reset           # Drop, create, and migrate
mix ecto.setup           # Create DB + run migrations + seed

# Generate code
mix phx.gen.live Accounts User users email:string name:string
mix phx.gen.context Pipelines Pipeline pipelines name:string
```

### VSCode Shortcuts

- `Ctrl+Shift+P`: Command palette
- `Ctrl+P`: Quick file open
- `F12`: Go to definition
- `Shift+F12`: Find all references
- `Ctrl+.`: Quick fix / suggestions
- `F5`: Start debugging

## 📚 Useful Resources

### Elixir/Phoenix
- [Elixir Docs](https://hexdocs.pm/elixir/)
- [Phoenix Docs](https://hexdocs.pm/phoenix/)
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/)

### Project Documentation
- [Architecture Overview](docs/technical/01-architecture.md)
- [Development Roadmap](docs/business/roadmap.md)
- [Error Logging & Monitoring](docs/technical/09-error-logging.md)

## 🐛 Troubleshooting

### ElixirLS not working
```bash
# Clear ElixirLS cache
rm -rf .elixir_ls
# Restart VSCode
```

### Phoenix live reload not working
```bash
# Check inotify limit
cat /proc/sys/fs/inotify/max_user_watches
# Should be 524288 or higher
```

### Database connection issues
```bash
# Check PostgreSQL is running
sudo systemctl status postgresql

# Check you can connect
psql -l

# Reset database if needed
mix ecto.reset
```

### Port already in use
```bash
# Check what's using port 4000
sudo ss -tulpn | grep 4000

# Kill process if needed
kill -9 <PID>
```

## 🚀 Performance Tips for CachyOS

1. **Enable compiler optimizations** in `mix.exs`:
   ```elixir
   def project do
     [
       # ... other config
       compilers: [:phoenix] ++ Mix.compilers(),
       consolidate_protocols: Mix.env() != :dev
     ]
   end
   ```

2. **Use CachyOS optimized kernel**: CachyOS already provides this by default

3. **Disable VSCode telemetry**: Already configured in settings.json

4. **Use local PostgreSQL**: Faster than Docker containers

## ✅ Setup Complete Checklist

- [ ] PostgreSQL running and databases created
- [ ] Elixir and Erlang installed
- [ ] Node.js installed (for assets)
- [ ] VSCode extensions installed
- [ ] File watching configured (inotify)
- [ ] Phoenix project initialized
- [ ] Environment variables configured
- [ ] Database migrations run
- [ ] Server starts successfully on http://localhost:4000

---

**Need help?** Check the [Error Logging & Monitoring](docs/technical/09-error-logging.md) doc for debugging tips!
