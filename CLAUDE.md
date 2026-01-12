# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Code Sandbox is a containerized environment for running Claude Code CLI using Docker (via OrbStack or Docker Desktop). The project provides an isolated, reproducible environment with full MCP (Model Context Protocol) server support, SSH agent forwarding for git operations, and persistent configuration storage. It supports macOS, Linux, and Windows (via WSL2).

## Architecture

### Core Components

1. **Dockerfile** - Alpine Linux-based image that includes:
   - Claude Code CLI (installed via npm: `@anthropic-ai/claude-code`)
   - Three MCP servers: filesystem, memory, and fetch
   - Development tools: Python 3, Node.js, npm, Bun runtime
   - Database clients: PostgreSQL 18, SQLite
   - User setup: Non-root user `claude` with home at `/home/claude`

2. **claude wrapper script** - Bash script that:
   - Verifies Docker is running (starts it if needed via OrbStack, Docker Desktop, or systemctl)
   - Generates unique incremental container names (`claude-sandbox-0`, `claude-sandbox-1`, etc.)
   - Syncs `.gitconfig` from `~/.gitconfig` to `~/.claude-sandbox/.gitconfig`
   - Loads SSH keys via `ssh-add` for git operations
   - Mounts workspace and configuration directories
   - Supports `--ssh-key` flag to specify which SSH key to load
   - Automatically handles prompt arguments (positional args become prompts with `-p` flag)
   - Platform-aware SSH agent forwarding (macOS uses Docker socket, Linux uses direct forwarding)

3. **setup.sh** - Automated installation script that:
   - Checks/starts Docker (platform-specific: OrbStack, Docker Desktop, or systemctl)
   - Builds the container image via `make build`
   - Installs wrapper to `~/.local/bin/claude-sandbox`
   - Adds `ccs` alias to shell config (bash/zsh/fish)

4. **MCP Configuration** (`/mcp.json` in container):
   - `filesystem`: Provides file operations within `/workspace` (uses Bun)
   - `memory`: Persistent knowledge graph storage (uses Bun)
   - `fetch`: HTTP requests to external APIs (uses Python)

### Volume Mounts

The wrapper script creates these mounts:
- `~/.claude-sandbox` → `/home/claude` (persistent config, includes synced `.gitconfig`)
- `~/.claude/ide` → `/home/claude/.claude/ide:ro` (IDE settings, read-only)
- `$(pwd)` → `$(pwd)` (current workspace directory)

### Environment Variables

Set in the Dockerfile:
- `CLAUDE_CODE_SKIP_PERMISSIONS="true"` - Bypasses all permission prompts
- `DISABLE_AUTOUPDATER="1"` - Prevents auto-updates
- `CLAUDE_CODE_IDE_SKIP_AUTO_INSTALL="0"` - Allows IDE integration
- `CLAUDECODE="1"` - Indicates running in Claude Code environment

### Container Entrypoint

```bash
tini -- claude --dangerously-skip-permissions --allow-dangerously-skip-permissions --ide --mcp-config /mcp.json
```

- `tini`: Init system for proper signal handling and zombie process reaping
- `--dangerously-skip-permissions`: Skips all safety prompts (use with caution)

## Development Commands

### Setup and Installation

```bash
# Automated setup (recommended)
./setup.sh

# Manual setup steps (Docker must be running)
make build                    # Build container image
./claude                      # Run Claude Code
```

### Building and Testing

```bash
make build              # Build container image
make build-no-cache     # Build without cache
make test               # Test container with --version
make info               # Show image information
```

### Running Claude Code

```bash
# Interactive session
./claude
ccs                     # If setup.sh was run

# With specific SSH key
./claude --ssh-key id_ed25519
./claude --ssh-key ~/.ssh/custom_key
export CLAUDE_SSH_KEY=id_ed25519; ./claude

# Configure resource limits
./claude --cpus 4                # Allocate 4 CPUs
./claude --memory 4g             # Set memory limit to 4GB
./claude --cpus 2 --memory 2g    # Combine both settings

# Pass prompts directly (automatically converted to -p flag)
./claude "fix the bug"
./claude "analyze the performance bottleneck"

# Pass Claude CLI flags
./claude --debug
./claude -p /path/to/workspace

# Combine flags and prompts
./claude --debug "show error logs"
./claude --cpus 4 --memory 4g "optimize this code"
```

### Container Management

```bash
# Check Docker status
docker info

# List containers
docker ps              # Running containers
docker ps -a           # All containers

# Cleanup
docker rm <name>       # Remove specific container
docker system prune    # Remove all stopped containers

# Image management
make export               # Export to tar archive (.tar file)
make import               # Import from tar archive
make clean                # Remove image and archives
```

## Working with This Project

### Modifying the Container Image

1. Edit `Dockerfile`
2. Rebuild: `make build-no-cache`
3. Test: `make test`
4. Run: `./claude`

### Adding New MCP Servers

1. Install the server package in `Dockerfile`:
   ```dockerfile
   RUN npm install -g @modelcontextprotocol/server-xyz
   ```

2. Add configuration to the heredoc section that creates `/mcp.json`:
   ```json
   "xyz": {
     "command": "/usr/local/bin/bunx",
     "args": ["@modelcontextprotocol/server-xyz"]
   }
   ```

3. Rebuild: `make build-no-cache`

### Customizing the Wrapper Script

The `claude` wrapper script can be modified to:
- Change default SSH key behavior (see `SSH_KEY` variable)
- Modify volume mount points
- Add additional environment variables
- Adjust container naming logic
- Change git config sync behavior
- Customize prompt argument parsing (see `Argument Parsing` section)

### SSH Key Management

The wrapper script supports flexible SSH key loading:
- Default: Uses `$CLAUDE_SSH_KEY` environment variable or `id_ed25519`
- Override: Use `--ssh-key <name>` or `--ssh-key <path>` flag
- Before running: Ensure keys are available with `ssh-add -l`
- The script calls `ssh-add` to load keys into the agent
- SSH agent is forwarded into container via volume mount (platform-specific):
  - macOS: Uses `/run/host-services/ssh-auth.sock` (Docker Desktop/OrbStack magic socket)
    - The socket's group ID is detected dynamically and added via `--group-add`
  - Linux: Uses `$SSH_AUTH_SOCK` directly

### Multiple Container Instances

The wrapper automatically generates unique container names, allowing multiple instances:
- First run: `claude-sandbox-0`
- Second run: `claude-sandbox-1`
- Each container is automatically removed after exit (`--rm` flag)

## Important Notes

### Security Considerations

- Container runs with `--dangerously-skip-permissions` - only use on trusted codebases
- Workspace is directly mounted with read/write access
- Git config and SSH keys are accessible inside container
- Changes affect actual files on host

### Platform Requirements

- **macOS**: Docker via OrbStack (recommended) or Docker Desktop
  - Install OrbStack: `brew install orbstack`
  - Or download Docker Desktop from <https://docker.com/products/docker-desktop>
- **Linux**: Docker Engine
  - Ubuntu/Debian: `sudo apt-get install docker.io`
  - Fedora: `sudo dnf install docker`
- **Windows**: Docker Desktop with WSL2 backend
- Commands use `docker` CLI
- Image format is tar (`.tar` files for export/import)

### Git Configuration

- Host `.gitconfig` is copied to `~/.claude-sandbox/.gitconfig` before each run
- Container automatically uses this config for git operations
- SSH agent is forwarded for authentication with remote repositories
