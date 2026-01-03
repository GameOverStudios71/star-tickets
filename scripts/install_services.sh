#!/bin/bash

# Configuration
CURRENT_USER=$(whoami)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SYSTEMCTL_DIR="$PROJECT_DIR/systemctl"
ASDF_SCRIPT="$HOME/.asdf/asdf.sh"

echo "🔧 Setting up Systemd Services for StarTickets..."
echo "User: $CURRENT_USER"
echo "Project Dir: $PROJECT_DIR"
echo "Services Dir: $SYSTEMCTL_DIR"

# 1. Create directory
mkdir -p "$SYSTEMCTL_DIR"

# 2. Create Wrapper for Evolution API
echo "📝 Generating Evolution API Wrapper..."
cat <<EOF > "$SYSTEMCTL_DIR/run_evolution_service.sh"
#!/bin/bash
source "$ASDF_SCRIPT"
source "$PROJECT_DIR/.env"
cd "$PROJECT_DIR/evolution/src"
npm run start:prod
EOF
chmod +x "$SYSTEMCTL_DIR/run_evolution_service.sh"

# 3. Create Wrapper for StarTickets (Phoenix)
echo "📝 Generating StarTickets Wrapper..."
cat <<EOF > "$SYSTEMCTL_DIR/run_startickets_service.sh"
#!/bin/bash
source "$ASDF_SCRIPT"
source "$PROJECT_DIR/.env"
# Ensure we map the correct mix path/env if needed, though source asdf helps
cd "$PROJECT_DIR"
# Increase file watcher limit
ulimit -n 65535
mix phx.server
EOF
chmod +x "$SYSTEMCTL_DIR/run_startickets_service.sh"

# 4. Create Evolution API Service Unit
echo "📝 Generating Evolution Service Unit..."
cat <<EOF > "$SYSTEMCTL_DIR/evolution-api.service"
[Unit]
Description=Evolution API (WhatsApp)
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$PROJECT_DIR/evolution/src
ExecStart=$SYSTEMCTL_DIR/run_evolution_service.sh
Restart=always
RestartSec=10
Environment=PATH=/usr/bin:/usr/local/bin
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

# 5. Create StarTickets Service Unit
echo "📝 Generating StarTickets Service Unit..."
cat <<EOF > "$SYSTEMCTL_DIR/star-tickets.service"
[Unit]
Description=StarTickets Platform (Phoenix)
After=network.target postgresql.service evolution-api.service
Wants=postgresql.service evolution-api.service

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$SYSTEMCTL_DIR/run_startickets_service.sh
Restart=always
RestartSec=10
Environment=MIX_ENV=dev
Environment=PATH=/usr/bin:/usr/local/bin

[Install]
WantedBy=multi-user.target
EOF

echo "✅ Files created in $SYSTEMCTL_DIR"
echo ""
echo "🚀 Installing services to /etc/systemd/system/..."
echo "⚠️  You may be asked for your sudo password."

# Install and Enable
sudo cp "$SYSTEMCTL_DIR/evolution-api.service" /etc/systemd/system/
sudo cp "$SYSTEMCTL_DIR/star-tickets.service" /etc/systemd/system/

echo "🔄 Reloading Systemd Daemon..."
sudo systemctl daemon-reload

echo "🔌 Enabling and Starting Services..."
sudo systemctl enable --now evolution-api
sudo systemctl enable --now star-tickets

echo ""
echo "✅ SUCCESS! Services installed and started."
echo "   - Evolution API: sudo systemctl status evolution-api"
echo "   - StarTickets:   sudo systemctl status star-tickets"
