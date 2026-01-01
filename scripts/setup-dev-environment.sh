#!/bin/bash
# =============================================================================
# StarTickets - Development Environment Setup Script
# =============================================================================
# This script installs asdf, Erlang, and Elixir for the StarTickets project.
# Run this script from the project root: ./scripts/setup-dev-environment.sh
# =============================================================================

set -e  # Exit on error

echo "=============================================="
echo "🚀 StarTickets - Development Environment Setup"
echo "=============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Versions
ASDF_VERSION="v0.14.0"
ERLANG_VERSION="27.2"
ELIXIR_VERSION="1.18.1-otp-27"

print_step() {
    echo -e "${GREEN}▶ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✖ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✔ $1${NC}"
}

# =============================================================================
# Step 1: Install system dependencies
# =============================================================================
print_step "Installing system dependencies for Erlang compilation..."

sudo apt-get update
sudo apt-get install -y \
    build-essential \
    autoconf \
    inotify-tools \
    m4 \
    libncurses5-dev \
    libncurses-dev \
    libssl-dev \
    libwxgtk3.2-dev \
    libwxgtk-webview3.2-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libpng-dev \
    libssh-dev \
    unixodbc-dev \
    xsltproc \
    fop \
    libxml2-utils \
    git \
    curl

print_success "System dependencies installed"
echo ""

# =============================================================================
# Step 2: Install asdf version manager
# =============================================================================
print_step "Installing asdf version manager ${ASDF_VERSION}..."

if [ -d "$HOME/.asdf" ]; then
    print_warning "asdf directory already exists at ~/.asdf"
    read -p "Do you want to remove and reinstall? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$HOME/.asdf"
        git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch ${ASDF_VERSION}
    fi
else
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch ${ASDF_VERSION}
fi

print_success "asdf installed"
echo ""

# =============================================================================
# Step 3: Configure shell
# =============================================================================
print_step "Configuring shell..."

# Add to bashrc if not already present
if ! grep -q 'asdf/asdf.sh' ~/.bashrc; then
    echo '' >> ~/.bashrc
    echo '# asdf version manager' >> ~/.bashrc
    echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
    echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
    print_success "Added asdf to ~/.bashrc"
else
    print_warning "asdf already configured in ~/.bashrc"
fi

# Add to zshrc if it exists
if [ -f "$HOME/.zshrc" ]; then
    if ! grep -q 'asdf/asdf.sh' ~/.zshrc; then
        echo '' >> ~/.zshrc
        echo '# asdf version manager' >> ~/.zshrc
        echo '. "$HOME/.asdf/asdf.sh"' >> ~/.zshrc
        echo 'fpath=(${ASDF_DIR}/completions $fpath)' >> ~/.zshrc
        echo 'autoload -Uz compinit && compinit' >> ~/.zshrc
        print_success "Added asdf to ~/.zshrc"
    fi
fi

# Source asdf for current session
. "$HOME/.asdf/asdf.sh"

echo ""

# =============================================================================
# Step 4: Install asdf plugins
# =============================================================================
print_step "Installing asdf plugins for Erlang and Elixir..."

# Erlang plugin
if asdf plugin list | grep -q erlang; then
    print_warning "Erlang plugin already installed"
else
    asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
    print_success "Erlang plugin installed"
fi

# Elixir plugin
if asdf plugin list | grep -q elixir; then
    print_warning "Elixir plugin already installed"
else
    asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git
    print_success "Elixir plugin installed"
fi

echo ""

# =============================================================================
# Step 5: Install Erlang
# =============================================================================
print_step "Installing Erlang ${ERLANG_VERSION} (this may take 10-15 minutes)..."

if asdf list erlang | grep -q "${ERLANG_VERSION}"; then
    print_warning "Erlang ${ERLANG_VERSION} already installed"
else
    asdf install erlang ${ERLANG_VERSION}
    print_success "Erlang ${ERLANG_VERSION} installed"
fi

echo ""

# =============================================================================
# Step 6: Install Elixir
# =============================================================================
print_step "Installing Elixir ${ELIXIR_VERSION}..."

if asdf list elixir | grep -q "${ELIXIR_VERSION}"; then
    print_warning "Elixir ${ELIXIR_VERSION} already installed"
else
    asdf install elixir ${ELIXIR_VERSION}
    print_success "Elixir ${ELIXIR_VERSION} installed"
fi

echo ""

# =============================================================================
# Step 7: Set versions for the project
# =============================================================================
print_step "Setting project versions..."

# Create .tool-versions in project directory if we're in the project
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$PROJECT_DIR/mix.exs" ]; then
    cat > "$PROJECT_DIR/.tool-versions" << EOF
erlang ${ERLANG_VERSION}
elixir ${ELIXIR_VERSION}
EOF
    print_success "Created .tool-versions in project directory"
fi

# Also set global versions
asdf global erlang ${ERLANG_VERSION}
asdf global elixir ${ELIXIR_VERSION}

print_success "Global versions set"
echo ""

# =============================================================================
# Step 8: Verify installation
# =============================================================================
print_step "Verifying installation..."

echo "Erlang version:"
erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell

echo ""
echo "Elixir version:"
elixir --version

echo ""

# =============================================================================
# Step 9: Install Hex and Rebar (optional but recommended)
# =============================================================================
print_step "Installing Hex and Rebar..."

mix local.hex --force
mix local.rebar --force

print_success "Hex and Rebar installed"
echo ""

# =============================================================================
# Complete!
# =============================================================================
echo "=============================================="
echo -e "${GREEN}✅ Development environment setup complete!${NC}"
echo "=============================================="
echo ""
echo "Installed versions:"
echo "  - asdf: ${ASDF_VERSION}"
echo "  - Erlang: ${ERLANG_VERSION}"
echo "  - Elixir: ${ELIXIR_VERSION}"
echo ""
echo "Next steps:"
echo "  1. Open a new terminal (or run: source ~/.bashrc)"
echo "  2. Navigate to the project: cd ${PROJECT_DIR}"
echo "  3. Install dependencies: mix setup"
echo "  4. Start the server: mix phx.server"
echo ""
echo "Happy coding! 🎉"
