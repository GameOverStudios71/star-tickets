#!/bin/bash
set -e

# StarTickets - Bare Metal Deployment Script
# ---------------------------------------------------------
# Installs everything needed to run StarTickets and Evolution API
# on a fresh Debian/Ubuntu server without Docker.

USER_HOME=$(eval echo ~$USER)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Configure script to always run from project root
cd "$PROJECT_DIR"

echo "🚀 Starting Bare Metal Deployment..."
echo "📂 Project Directory: $PROJECT_DIR"
echo "👤 User: $USER"

# 1. Update System & Install Core Services (Postgres, Redis)
echo ""
echo "📦 Step 1: Installing System Dependencies & Services..."
sudo apt-get update
sudo apt-get install -y git curl build-essential postgresql postgresql-contrib redis-server

# Start services
sudo systemctl enable --now postgresql
sudo systemctl enable --now redis-server

echo "✅ System services installed."

# 2. Configure Database
echo ""
echo "🗄️ Step 2: Configuring Databases..."
# Create postgres user if not exists (usually created by package)
# We need to ensure we can connect. We will use 'postgres' user for simplicity or current user.
# Let's create a database user 'postgres' with password 'postgres' if it doesn't align.
# OR better, trust local connections.
# For simplicity in this script, we'll try to create a DB user matching the one in .env usually 'postgres'.

sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';" || true
echo "✅ Postgres default user password ensuring 'postgres'."

# 3. Setup Dev Environment (Erlang/Elixir/ASDF)
echo ""
echo "🛠️ Step 3: Setting up Language Runtimes (Erlang/Elixir/Node)..."
# We can allow the interactive parts of setup-dev-environment to run or assume defaults.
# The existing script might prompt. We will try to run strictly.
# Note: setup-dev-environment installs ASDF, Erlang, Elixir.

# Check for .env file
if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo "⚠️  WARNING: .env file not found in $PROJECT_DIR"
    if [ -f "$PROJECT_DIR/.env.example" ]; then
        echo "   Copying .env.example to .env..."
        cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
    else
        echo "❌ Error: No .env or .env.example found. Please create .env first."
        exit 1
    fi
fi

# Force "no" to prompts in setup-dev-environment (like reinstalling asdf)
chmod +x ./scripts/setup-dev-environment.sh
echo "n" | ./scripts/setup-dev-environment.sh

# Source ASDF for this script explicitly
. "$USER_HOME/.asdf/asdf.sh"

# 4. Install Evolution API
echo ""
echo "💬 Step 4: Installing Evolution API..."

# Ensuring .env exists in evolution/src if needed (install_evolution handles copy from base to src)
# We just need to make sure project .env is available to install_evolution
# install_evolution.sh copies from evolution/.env to evolution/src/.env
# So we update evolution/.env
if [ -f "$PROJECT_DIR/.env" ]; then
    cp "$PROJECT_DIR/.env" "$PROJECT_DIR/evolution/.env"
fi

chmod +x ./scripts/install_evolution.sh
# install_evolution.sh expects to be run from project root
./scripts/install_evolution.sh

# 5. Setup StarTickets Application
echo ""
echo "🎟️ Step 5: Setting up StarTickets..."
# Install deps
mix local.hex --force
mix local.rebar --force
mix setup

# pre-compile assets?
echo "   Compiling assets..."
npm install --prefix assets
npm run deploy --prefix assets
mix phx.digest

# 6. Install Systemd Services
echo ""
echo "🔌 Step 6: Installing Systemd Services..."
chmod +x ./scripts/install_services.sh
./scripts/install_services.sh

echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo "Check services with:"
echo "  sudo systemctl status evolution-api"
echo "  sudo systemctl status star-tickets"
