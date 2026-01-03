#!/bin/bash

# StarTickets - Start Evolution API
# ---------------------------------

# Source ASDF if available
if [ -f "$HOME/.asdf/asdf.sh" ]; then
  . "$HOME/.asdf/asdf.sh"
fi

APP_DIR="evolution/src"

if [ ! -d "$APP_DIR" ]; then
  echo "❌ Error: Directory $APP_DIR not found. Did you run install_evolution.sh?"
  exit 1
fi

cd "$APP_DIR" || exit

echo "🚀 Starting Evolution API..."
# Preserving the CONFIDENT_HOST override the user was using, just in case, 
# although .env should handle it if SERVER_URL is set correctly.
# Using standard start command.
npm run start
