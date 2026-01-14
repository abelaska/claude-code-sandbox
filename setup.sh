#!/bin/bash
#
# Claude Code Sandbox Setup Script
# =================================
# This script automates the complete setup process:
#   1. Installs Colima, Docker CLI, docker-compose, and docker-buildx (macOS)
#   2. Configures Docker CLI plugins via ~/.docker/config.json
#   3. Starts Colima with configured resources
#   4. Configures Colima to auto-start on login (via brew services)
#   5. Builds the container image using make build
#   6. Installs the claude wrapper script to ~/.local/bin/claude-sandbox
#   7. Adds the 'ccs' alias to your shell configuration
#
# Usage: ./setup.sh [options]
#   --cpu <num>      Number of CPUs for Colima VM (default: 4)
#   --memory <num>   Memory in GB for Colima VM (default: 8)
#   --disk <num>     Disk size in GB for Colima VM (default: 100)
#
# Examples:
#   ./setup.sh                           # Use defaults (4 CPU, 8GB RAM, 100GB disk)
#   ./setup.sh --cpu 8 --memory 16       # Custom CPU and memory
#   ./setup.sh --disk 200                # Larger disk
#

set -e  # Exit on any error

# ============================================================================
# Default Configuration
# ============================================================================

COLIMA_CPU=4
COLIMA_MEMORY=8
COLIMA_DISK=100

# ============================================================================
# Argument Parsing
# ============================================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cpu)
            COLIMA_CPU="$2"
            shift 2
            ;;
        --cpu=*)
            COLIMA_CPU="${1#*=}"
            shift
            ;;
        --memory)
            COLIMA_MEMORY="$2"
            shift 2
            ;;
        --memory=*)
            COLIMA_MEMORY="${1#*=}"
            shift
            ;;
        --disk)
            COLIMA_DISK="$2"
            shift 2
            ;;
        --disk=*)
            COLIMA_DISK="${1#*=}"
            shift
            ;;
        -h|--help)
            echo "Usage: ./setup.sh [options]"
            echo ""
            echo "Options:"
            echo "  --cpu <num>      Number of CPUs for Colima VM (default: 4)"
            echo "  --memory <num>   Memory in GB for Colima VM (default: 8)"
            echo "  --disk <num>     Disk size in GB for Colima VM (default: 100)"
            echo ""
            echo "Examples:"
            echo "  ./setup.sh                           # Use defaults"
            echo "  ./setup.sh --cpu 8 --memory 16       # Custom CPU and memory"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

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

print_info "Configuration: ${COLIMA_CPU} CPUs, ${COLIMA_MEMORY}GB memory, ${COLIMA_DISK}GB disk"

# ============================================================================
# Step 1: Install Dependencies (macOS only)
# ============================================================================

print_header "Step 1: Installing Dependencies"

case "$(uname -s)" in
    Darwin)
        # Check if Homebrew is installed
        if ! command -v brew &> /dev/null; then
            print_error "Homebrew not found"
            print_info "Install Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            exit 1
        fi
        print_success "Homebrew found"

        # Install Colima if not present
        if ! command -v colima &> /dev/null; then
            print_info "Installing Colima..."
            brew install colima
            print_success "Colima installed"
        else
            print_success "Colima already installed"
        fi

        # Install Docker CLI if not present
        if ! command -v docker &> /dev/null; then
            print_info "Installing Docker CLI..."
            brew install docker
            print_success "Docker CLI installed"
        else
            print_success "Docker CLI already installed"
        fi

        # Install docker-compose if not present
        if ! brew list docker-compose &> /dev/null; then
            print_info "Installing docker-compose..."
            brew install docker-compose
            print_success "docker-compose installed"
        else
            print_success "docker-compose already installed"
        fi

        # Install docker-buildx if not present
        if ! brew list docker-buildx &> /dev/null; then
            print_info "Installing docker-buildx..."
            brew install docker-buildx
            print_success "docker-buildx installed"
        else
            print_success "docker-buildx already installed"
        fi

        # Configure Docker CLI plugins path in ~/.docker/config.json
        print_info "Configuring Docker CLI plugins..."
        DOCKER_CONFIG_DIR="$HOME/.docker"
        DOCKER_CONFIG_FILE="$DOCKER_CONFIG_DIR/config.json"
        BREW_PREFIX="$(brew --prefix)"

        mkdir -p "$DOCKER_CONFIG_DIR"

        # Build the cliPluginsExtraDirs array
        COMPOSE_PATH="$BREW_PREFIX/opt/docker-compose/bin"
        BUILDX_PATH="$BREW_PREFIX/opt/docker-buildx/bin"

        if [ -f "$DOCKER_CONFIG_FILE" ]; then
            # Update existing config.json using jq if available, otherwise use python
            if command -v jq &> /dev/null; then
                jq --arg compose "$COMPOSE_PATH" --arg buildx "$BUILDX_PATH" \
                    '.cliPluginsExtraDirs = [$compose, $buildx]' \
                    "$DOCKER_CONFIG_FILE" > "$DOCKER_CONFIG_FILE.tmp" && \
                    mv "$DOCKER_CONFIG_FILE.tmp" "$DOCKER_CONFIG_FILE"
            elif command -v python3 &> /dev/null; then
                python3 -c "
import json
import sys
config_file = '$DOCKER_CONFIG_FILE'
compose_path = '$COMPOSE_PATH'
buildx_path = '$BUILDX_PATH'
try:
    with open(config_file, 'r') as f:
        config = json.load(f)
except:
    config = {}
config['cliPluginsExtraDirs'] = [compose_path, buildx_path]
with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)
"
            else
                print_warning "Neither jq nor python3 found, skipping config.json update"
            fi
        else
            # Create new config.json
            cat > "$DOCKER_CONFIG_FILE" << EOF
{
  "cliPluginsExtraDirs": [
    "$COMPOSE_PATH",
    "$BUILDX_PATH"
  ]
}
EOF
        fi
        print_success "Docker CLI plugins configured"
        ;;
    Linux)
        print_info "Linux detected - please ensure Docker is installed via your package manager"
        if ! command -v docker &> /dev/null; then
            print_error "Docker not found"
            print_info "Ubuntu/Debian: sudo apt-get install docker.io"
            print_info "Fedora: sudo dnf install docker"
            exit 1
        fi
        print_success "Docker found"
        ;;
esac

# ============================================================================
# Step 2: Start Colima/Docker
# ============================================================================

print_header "Step 2: Docker Runtime Check"

# Check if Docker daemon is running
if ! docker info >/dev/null 2>&1; then
    print_warning "Docker is not running, attempting to start..."

    # Platform-specific startup
    case "$(uname -s)" in
        Darwin)
            # Start Colima with specified resources and SSH agent forwarding
            if command -v colima &>/dev/null; then
                print_info "Starting Colima with ${COLIMA_CPU} CPUs, ${COLIMA_MEMORY}GB memory, ${COLIMA_DISK}GB disk..."
                colima start --cpu "$COLIMA_CPU" --memory "$COLIMA_MEMORY" --disk "$COLIMA_DISK" --ssh-agent
                print_success "Colima started with configured resources"
            else
                print_error "Colima not found - please run setup again"
                exit 1
            fi
            ;;
        Linux)
            if command -v systemctl &>/dev/null; then
                sudo systemctl start docker 2>/dev/null || true
            fi
            ;;
    esac

    # Wait for Docker to be ready (up to 60 seconds for Colima)
    attempts=0
    max_attempts=60
    while ! docker info >/dev/null 2>&1 && [ $attempts -lt $max_attempts ]; do
        sleep 1
        ((attempts++))
    done

    if docker info >/dev/null 2>&1; then
        print_success "Docker is now running"
    else
        print_error "Failed to start Docker"
        print_info "Please check Colima status: colima status"
        exit 1
    fi
else
    print_success "Docker is already running"

    # On macOS, verify Colima is the runtime
    if [[ "$(uname -s)" == "Darwin" ]] && command -v colima &>/dev/null; then
        if colima status 2>&1 | grep -qi "running"; then
            print_success "Colima runtime verified"
        else
            print_warning "Docker is running but Colima may not be the active runtime"
            print_info "If you want to use Colima, stop other runtimes and run: colima start"
        fi
    fi
fi

# Configure Colima auto-start on login (macOS only)
if [[ "$(uname -s)" == "Darwin" ]] && command -v colima &>/dev/null; then
    print_info "Configuring Colima auto-start on login..."

    COLIMA_PLIST="$HOME/Library/LaunchAgents/homebrew.mxcl.colima.plist"

    # Check if LaunchAgent plist exists (this is what enables auto-start)
    if [ -f "$COLIMA_PLIST" ]; then
        print_success "Colima auto-start already configured"
    elif colima status 2>&1 | grep -qi "running"; then
        # Colima is running but plist doesn't exist - need to stop and restart via brew services
        print_info "Colima is running manually, configuring auto-start..."
        colima stop >/dev/null 2>&1
        sleep 2
        if brew services start colima >/dev/null 2>&1; then
            print_success "Colima configured to start automatically on login"
        else
            # Fallback: restart Colima manually if brew services fails
            colima start --cpu "$COLIMA_CPU" --memory "$COLIMA_MEMORY" --disk "$COLIMA_DISK" --ssh-agent >/dev/null 2>&1
            print_warning "Could not configure auto-start via brew services"
            print_info "You can manually enable it with: brew services start colima"
        fi
    else
        # Colima not running - start via brew services
        if brew services start colima >/dev/null 2>&1; then
            print_success "Colima configured to start automatically on login"
        else
            print_warning "Could not configure auto-start via brew services"
            print_info "You can manually enable it with: brew services start colima"
        fi
    fi
fi

# ============================================================================
# Step 3: Build Container Image
# ============================================================================

print_header "Step 3: Building Container Image"

print_info "Running 'make build'..."

if make build; then
    print_success "Container image built successfully"
else
    print_error "Failed to build container image"
    exit 1
fi

# ============================================================================
# Step 4: Install Claude Wrapper Script
# ============================================================================

print_header "Step 4: Installing Claude Wrapper"

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
# Step 5: Setup Shell Alias
# ============================================================================

print_header "Step 5: Setting up Shell Alias"

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
