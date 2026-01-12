#!/bin/bash
#
# Claude Code Sandbox Setup Script
# =================================
# This script automates the complete setup process:
#   1. Checks and starts Docker if needed
#   2. Builds the container image using make build
#   3. Installs the claude wrapper script to ~/.local/bin/claude-sandbox
#   4. Adds the 'ccs' alias to your shell configuration
#
# Usage: ./setup.sh
#

set -e  # Exit on any error

# ============================================================================
# Color codes for pretty output
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Helper functions
# ============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# ============================================================================
# Main Setup Process
# ============================================================================

print_header "Claude Code Sandbox Setup"

# ============================================================================
# Step 1: Check Docker
# ============================================================================

print_header "Step 1: Docker Check"

# Check if docker command exists
if ! command -v docker &> /dev/null; then
    print_error "docker command not found"
    print_info "Install Docker via OrbStack: brew install orbstack"
    print_info "Or install Docker Desktop from: https://docker.com/products/docker-desktop"
    exit 1
fi

print_success "docker command found"

# Check if Docker daemon is running
if ! docker info >/dev/null 2>&1; then
    print_warning "Docker is not running, attempting to start..."

    # Platform-specific startup
    case "$(uname -s)" in
        Darwin)
            if command -v orbctl &>/dev/null; then
                orbctl start 2>/dev/null || true
            elif [ -d "/Applications/Docker.app" ]; then
                open -a Docker
            fi
            ;;
        Linux)
            if command -v systemctl &>/dev/null; then
                sudo systemctl start docker 2>/dev/null || true
            fi
            ;;
    esac

    # Wait for Docker to be ready (up to 30 seconds)
    attempts=0
    while ! docker info >/dev/null 2>&1 && [ $attempts -lt 30 ]; do
        sleep 1
        ((attempts++))
    done

    if docker info >/dev/null 2>&1; then
        print_success "Docker started"
    else
        print_error "Failed to start Docker"
        print_info "Please start Docker manually and try again"
        exit 1
    fi
else
    print_success "Docker is running"
fi

# ============================================================================
# Step 2: Build Container Image
# ============================================================================

print_header "Step 2: Building Container Image"

print_info "Running 'make build'..."

if make build; then
    print_success "Container image built successfully"
else
    print_error "Failed to build container image"
    exit 1
fi

# ============================================================================
# Step 3: Install Claude Wrapper Script
# ============================================================================

print_header "Step 3: Installing Claude Wrapper"

INSTALL_DIR="$HOME/.local/bin"
CLAUDE_SCRIPT="$(pwd)/claude"

# Check if claude script exists
if [ ! -f "$CLAUDE_SCRIPT" ]; then
    print_error "claude script not found at: $CLAUDE_SCRIPT"
    exit 1
fi

print_info "Creating directory: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

print_info "Copying claude script to: $INSTALL_DIR/claude-sandbox"
cp "$CLAUDE_SCRIPT" "$INSTALL_DIR/claude-sandbox"
chmod +x "$INSTALL_DIR/claude-sandbox"

print_success "Claude wrapper installed"

# ============================================================================
# Step 4: Setup Shell Alias
# ============================================================================

print_header "Step 4: Setting up Shell Alias"

# Detect the user's shell
CURRENT_SHELL=$(basename "$SHELL")
print_info "Detected shell: $CURRENT_SHELL"

# Determine which config file to modify
case "$CURRENT_SHELL" in
    bash)
        SHELL_CONFIG="$HOME/.bashrc"
        # On macOS, use .bash_profile if .bashrc doesn't exist
        if [[ "$OSTYPE" == "darwin"* ]] && [ ! -f "$SHELL_CONFIG" ]; then
            SHELL_CONFIG="$HOME/.bash_profile"
        fi
        ;;
    zsh)
        SHELL_CONFIG="$HOME/.zshrc"
        ;;
    fish)
        SHELL_CONFIG="$HOME/.config/fish/config.fish"
        ;;
    *)
        print_warning "Unknown shell: $CURRENT_SHELL"
        print_info "Please manually add this alias to your shell config:"
        echo "    alias ccs='$INSTALL_DIR/claude-sandbox'"
        exit 0
        ;;
esac

print_info "Shell config: $SHELL_CONFIG"

# Check if alias already exists
ALIAS_LINE="alias ccs='$INSTALL_DIR/claude-sandbox'"

if [ -f "$SHELL_CONFIG" ] && grep -q "alias ccs=" "$SHELL_CONFIG"; then
    print_warning "Alias 'ccs' already exists in $SHELL_CONFIG"
    print_info "Please check if it points to the correct location"
else
    # Add alias to shell config
    if [ "$CURRENT_SHELL" = "fish" ]; then
        # Fish uses a different alias syntax
        ALIAS_LINE="alias ccs '$INSTALL_DIR/claude-sandbox'"
    fi

    print_info "Adding alias to $SHELL_CONFIG"

    # Create config file if it doesn't exist
    touch "$SHELL_CONFIG"

    # Add a comment and the alias
    echo "" >> "$SHELL_CONFIG"
    echo "# Claude Code Sandbox alias (added by setup.sh)" >> "$SHELL_CONFIG"
    echo "$ALIAS_LINE" >> "$SHELL_CONFIG"

    print_success "Alias added to $SHELL_CONFIG"
fi

# ============================================================================
# Setup Complete
# ============================================================================

print_header "Setup Complete! 🎉"

echo ""
print_success "Container system is running"
print_success "Container image built"
print_success "Claude wrapper installed to: $INSTALL_DIR/claude-sandbox"
print_success "Alias 'ccs' configured"

echo ""
print_info "To start using Claude Code Sandbox:"
echo ""
echo "  1. Reload your shell configuration:"

case "$CURRENT_SHELL" in
    bash)
        echo "     source $SHELL_CONFIG"
        ;;
    zsh)
        echo "     source $SHELL_CONFIG"
        ;;
    fish)
        echo "     source $SHELL_CONFIG"
        ;;
esac

echo ""
echo "  2. Run Claude Code using the 'ccs' command:"
echo "     ccs"
echo ""
echo "  Or use the full path without reloading:"
echo "     $INSTALL_DIR/claude-sandbox"
echo ""

print_info "Happy coding! 🚀"
