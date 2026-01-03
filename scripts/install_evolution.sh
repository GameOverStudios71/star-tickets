#!/bin/bash

# StarTickets - Evolution API Installer (Local with ASDF)
# ---------------------------------------------------------

echo "🔍 Checking dependencies..."

# Source ASDF
if [ -f "$HOME/.asdf/asdf.sh" ]; then
  . "$HOME/.asdf/asdf.sh"
  echo "✅ ASDF loaded"
else
  echo "❌ Error: ASDF not found at $HOME/.asdf/asdf.sh"
  exit 1
fi

# 1. Setup Node.js via ASDF
echo "📦 Setting up Node.js via ASDF..."

# Add plugin if missing
if ! asdf plugin list | grep -q "nodejs"; then
  echo "   Adding nodejs plugin..."
  asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
fi

# Install Node 20 if missing
if ! asdf list nodejs | grep -q "20."; then
  echo "   Installing Node.js 20 (LTS)..."
  asdf install nodejs 20.11.0 # Using a fixed LTS version
fi

# Force use of Node 20 for this session
asdf local nodejs 20.11.0
echo "✅ Node.js $(node -v) is ready"

# 2. Check Git
if ! [ -x "$(command -v git)" ]; then
  echo "❌ Error: Git is not installed." >&2
  exit 1
fi

# 3. Setup Directory
BASE_DIR="evolution"
SRC_DIR="$BASE_DIR/src"

echo "📂 Setup directory structure..."

# 4. Clone Repository
if [ -d "$SRC_DIR/.git" ]; then
  echo "✅ Repository already cloned."
else
  # If dir exists but no .git, it's likely a failed install or artifact. Clean it.
  if [ -d "$SRC_DIR" ]; then
    echo "⚠️ removing existing non-repo directory $SRC_DIR to allow clone..."
    rm -rf "$SRC_DIR"
  fi

  echo "⬇️ Cloning Evolution API..."
  git clone https://github.com/EvolutionAPI/evolution-api.git "$SRC_DIR"
fi

# 5. Configure Environment & Tools
echo "⚙️ Configuring environment..."

# Setup .tool-versions AFTER clone
echo "nodejs 20.11.0" > "$SRC_DIR/.tool-versions"

if [ -f "$BASE_DIR/.env" ]; then
  cp "$BASE_DIR/.env" "$SRC_DIR/.env"
  echo "✅ Copied .env from $BASE_DIR to $SRC_DIR"
else
  echo "❌ Error: $BASE_DIR/.env not found! Please create it first."
  exit 1
fi

# 6. Install Dependencies & Build
echo "📦 Installing NPM dependencies..."
cd "$SRC_DIR" || exit

# Ensure clean install to avoid missing modules
if [ -d "node_modules" ]; then
  echo "♻️  Cleaning existing node_modules..."
  rm -rf node_modules package-lock.json
fi
npm install

# 7. Local Configuration Updates
echo "🔧 Configuring for Local Environment..."

# Update Hostnames to localhost
if grep -q "postgres:5432" .env; then
  sed -i 's/postgres:5432/localhost:5432/' .env
  echo "✅ Updated Postgres host to localhost"
fi

if grep -q "redis:6379" .env; then
  sed -i 's/redis:6379/localhost:6379/' .env
  echo "✅ Updated Redis host to localhost"
fi

# Check for Redis and toggle Local Cache if needed
if ! command -v redis-server &> /dev/null; then
  echo "⚠️  Redis server not found locally. Switching to Local Cache..."
  sed -i 's/CACHE_REDIS_ENABLED=true/CACHE_REDIS_ENABLED=false/' .env
  sed -i 's/CACHE_LOCAL_ENABLED=false/CACHE_LOCAL_ENABLED=true/' .env
fi

# 8. Database Setup
echo "🗄️  Setting up Database..."

# Check if postgres client exists
if command -v psql &> /dev/null; then
  # Try to create database if it doesn't exist (requires user to have access without password or via ~/.pgpass for this to be fully automated, but we try)
  if ! PGPASSWORD=postgres psql -h localhost -U postgres -lqt | cut -d \| -f 1 | grep -qw evolution_db; then
    echo "Creating database 'evolution_db'..."
    PGPASSWORD=postgres createdb -h localhost -U postgres evolution_db || echo "⚠️  Could not create database. You may need to create 'evolution_db' manually."
  else
    echo "✅ Database 'evolution_db' already exists."
  fi
fi

echo "🏭 Running Database Migrations..."
# Generate Client first
npm run db:generate

# Run Migrations
npx prisma migrate dev --schema ./prisma/postgresql-schema.prisma --name init || echo "⚠️  Migration failed. Ensure database credentials in .env are correct."

echo "🏗️ Building Application..."
npm run build

echo "✅ Installation complete!"
echo ""
echo "----------------------------------------------------------------"
echo "🚀 HOW TO START"
echo "----------------------------------------------------------------"
echo "1. Create the database (if needed):"
echo "   sudo -u postgres createdb evolution_db"
echo ""
echo "2. Start the API:"
echo "   cd $SRC_DIR"
echo "   npm run start:prod"
echo ""
echo "----------------------------------------------------------------"
