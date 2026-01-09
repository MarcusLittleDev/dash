#!/bin/bash
# PostgreSQL Setup Script for Dash Application
# Run this after PostgreSQL is installed and initialized

set -e

echo "🐘 Setting up PostgreSQL for Dash..."
echo ""

# Get current username
CURRENT_USER=$(whoami)

echo "📝 Creating PostgreSQL user: $CURRENT_USER"
sudo -u postgres createuser -s $CURRENT_USER 2>/dev/null || echo "  ✓ User already exists"

echo ""
echo "🗄️  Creating databases..."

# Create development database
createdb dash_dev 2>/dev/null && echo "  ✓ Created dash_dev" || echo "  ✓ dash_dev already exists"

# Create test database
createdb dash_test 2>/dev/null && echo "  ✓ Created dash_test" || echo "  ✓ dash_test already exists"

echo ""
echo "🔧 Installing TimescaleDB extension..."

# Check if timescaledb is installed
if pacman -Qi timescaledb &> /dev/null; then
    echo "  ✓ TimescaleDB package is installed"
else
    echo "  ⚠️  TimescaleDB not installed. Installing now..."
    echo "  Run: sudo pacman -S timescaledb"
    echo ""
    read -p "Install TimescaleDB now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo pacman -S timescaledb
    else
        echo "  ⚠️  Skipping TimescaleDB - you'll need to install it later"
    fi
fi

# Enable TimescaleDB extension in databases
echo ""
echo "🔌 Enabling TimescaleDB extension in databases..."
psql dash_dev -c "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;" 2>/dev/null && \
    echo "  ✓ TimescaleDB enabled in dash_dev" || \
    echo "  ⚠️  Could not enable TimescaleDB in dash_dev (install timescaledb package first)"

psql dash_test -c "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;" 2>/dev/null && \
    echo "  ✓ TimescaleDB enabled in dash_test" || \
    echo "  ⚠️  Could not enable TimescaleDB in dash_test (install timescaledb package first)"

echo ""
echo "✅ PostgreSQL setup complete!"
echo ""
echo "📊 Database Information:"
echo "  • Development DB: dash_dev"
echo "  • Test DB: dash_test"
echo "  • User: $CURRENT_USER"
echo "  • Host: localhost"
echo "  • Port: 5432"
echo ""
echo "🧪 Test your connection:"
echo "  psql -l                    # List all databases"
echo "  psql dash_dev              # Connect to dev database"
echo ""
echo "🔐 Default connection string for Phoenix:"
echo "  DATABASE_URL=ecto://$(whoami):@localhost/dash_dev"
echo ""
echo "Next steps:"
echo "  1. Initialize your Phoenix project"
echo "  2. Update config/dev.exs with database credentials"
echo "  3. Run: mix ecto.create"
echo "  4. Run: mix ecto.migrate"
