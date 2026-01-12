# Claude Code Sandbox

A containerized environment for running Claude Code CLI with full MCP (Model Context Protocol) server support using Apple's native container system.

## Overview

Claude Code Sandbox provides an isolated, reproducible environment for running Claude Code with:

- **Alpine Linux base** - Lightweight and secure
- **Bun runtime** - Fast JavaScript/TypeScript execution
- **MCP servers** - Filesystem, memory, and fetch capabilities
- **SSH agent forwarding** - Git operations with your keys
- **Smart wrapper script** - Seamless container management

## Features

### Core Components

- **Containerized Claude Code CLI** with bypassed permission prompts (`--dangerously-skip-permissions`)
- **Three MCP servers pre-configured**:
  - `filesystem` - File operations within workspace
  - `memory` - Persistent memory/knowledge graph
  - `fetch` - HTTP requests to external APIs
- **Git integration** - Syncs your host `.gitconfig` and forwards SSH keys
- **Persistent storage** - Configuration saved to `~/.claude-sandbox`
- **Smart container naming** - Automatic incremental naming for multiple instances

### Development Tools Included

- Python 3 with pip
- Node.js and npm
- Bun (JavaScript runtime)
- Git
- PostgreSQL 18 client
- SQLite
- curl, jq, bash

## Prerequisites

- **macOS** (Apple Silicon or Intel)
- **Apple Container** - Native macOS containerization
- **Claude Pro/Max subscription** OR **Anthropic API key**

### Installing Apple Container

```bash
brew install container
```

## Quick Start

### Automated Setup (Recommended)

Run the setup script to install everything:

```bash
./setup.sh
```

This will:

1. Check and start the container system
2. Build the container image
3. Install the `claude-sandbox` wrapper to `~/.local/bin`
4. Add the `ccs` alias to your shell config

After setup, reload your shell:

```bash
# For bash/zsh
source ~/.bashrc  # or ~/.zshrc

# For fish
source ~/.config/fish/config.fish
```

### Usage

```bash
# Start interactive session
ccs

# Or use the full command
claude-sandbox

# Execute specific prompts
ccs "help me refactor this code"
ccs "fix the bug in authentication"

# Pass Claude CLI flags
ccs --debug
ccs -p /path/to/workspace
```

## Manual Setup

If you prefer manual setup or want to understand each step:

### 1. Start Container System

```bash
container system start
container system status
```

### 2. Build the Image

```bash
make build
```

### 3. Run Claude Code

```bash
./claude
```

## Project Structure

```text
.
├── Dockerfile           # Alpine-based image with MCP servers
├── Makefile            # Build and management commands
├── setup.sh            # Automated installation script
├── claude              # Wrapper script for container launch
├── .claude/            # Local settings
│   └── settings.local.json
└── README.md
```

## How It Works

### The Wrapper Script

The `claude` wrapper script (`./claude`) handles:

1. **Container system verification** - Ensures Apple Container is running and starts it if needed
2. **Container naming** - Generates unique incremental names (claude-sandbox-0, claude-sandbox-1, etc.)
3. **Git config sync** - Copies your `.gitconfig` to the sandbox directory
4. **SSH key loading** - Runs `ssh-add` to make your keys available for git operations
5. **Container launch** - Mounts workspace and config with proper isolation

### Volume Mounts

The container mounts several directories for seamless integration:

```bash
~/.claude-sandbox              → /home/claude                    # Persistent config (includes synced .gitconfig)
~/.claude/ide                  → /home/claude/.claude/ide       # IDE settings (read-only)
$(pwd)                         → $(pwd)                          # Current workspace
```

**Note:** Your `.gitconfig` is copied to `~/.claude-sandbox/.gitconfig` and mounted into the container, ensuring git operations use your identity while maintaining isolation.

### MCP Server Configuration

Located at `/mcp.json` inside the container:

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "/usr/local/bin/bunx",
      "args": ["@modelcontextprotocol/server-filesystem", "/workspace"]
    },
    "memory": {
      "command": "/usr/local/bin/bunx",
      "args": ["@modelcontextprotocol/server-memory"]
    },
    "fetch": {
      "command": "/usr/bin/python3",
      "args": ["-m", "mcp_server_fetch"]
    }
  }
}
```

## Makefile Commands

| Command               | Description                        |
|-----------------------|------------------------------------|
| `make build`          | Build the container image          |
| `make build-no-cache` | Build without cache                |
| `make export`         | Export image to OCI archive        |
| `make import`         | Import image from OCI archive      |
| `make clean`          | Remove image and archives          |
| `make info`           | Show image information             |
| `make test`           | Test container with --version      |
| `make help`           | Display all available commands     |

## Environment Variables

The container sets these environment variables:

| Variable                            | Value  | Purpose                          |
|-------------------------------------|--------|----------------------------------|
| `CLAUDE_CODE_SKIP_PERMISSIONS`      | `true` | Bypass permission prompts        |
| `DISABLE_AUTOUPDATER`               | `1`    | Prevent auto-updates             |
| `CLAUDE_CODE_IDE_SKIP_AUTO_INSTALL` | `0`    | Allow IDE auto-install           |
| `CLAUDECODE`                        | `1`    | Indicate Claude Code environment |

## Security Considerations

### Permission Bypass

The container runs with `--dangerously-skip-permissions`, which:

- Skips all safety prompts
- Allows automatic file operations
- Should **only be used on trusted codebases**

### Container Isolation

While the container provides process isolation:

- Your workspace is directly mounted (read/write)
- Your git config and SSH keys are accessible
- Changes affect your actual files

### Recommended Practices

1. Only run on codebases you trust
2. Review changes before committing
3. Keep backups of important work
4. Use version control (git) religiously

## Advanced Usage

### Running Specific Commands

```bash
# Execute specific prompts (automatically handled without -p flag)
./claude "analyze the performance of this code"
./claude "fix the bug in login flow"

# Pass Claude CLI flags
./claude --debug
./claude -p /path/to/project

# Combine flags and prompts
./claude --debug "show me the error logs"
```

### Multiple Concurrent Instances

The wrapper script supports running multiple Claude Code containers simultaneously:

1. Each container gets a unique name (claude-sandbox-0, claude-sandbox-1, etc.)
2. Containers are automatically cleaned up when the session ends (`--rm` flag)
3. You can run Claude in different project directories at the same time

### Container Management

```bash
# Start/stop the container system
container system start
container system stop
container system status

# List running containers
container ps

# Remove stopped containers
container system prune
```

### Image Export/Import

For offline use or sharing:

```bash
# Export
make export  # Creates claude-code-sandbox-latest.oci

# Import (on another machine)
make import
```

## Troubleshooting

### Container System Not Running

```text
Error: container system is not running
```

**Solution:**

```bash
container system start
```

### Image Not Found

```text
Error: image not found: claude-code-sandbox:latest
```

**Solution:**

```bash
make build
```

### SSH Keys Not Available

If git operations fail with authentication errors:

**Solution:**

```bash
# Add your SSH key
ssh-add ~/.ssh/id_rsa  # or your key path

# Verify keys are loaded
ssh-add -l
```

### Git Operations Fail

If git operations fail inside the container:

**Solution:**

```bash
# Ensure your SSH keys are added to the agent
ssh-add ~/.ssh/id_rsa  # or your key path

# Verify keys are loaded
ssh-add -l

# Ensure git config is present
cat ~/.gitconfig
```

### Permission Denied on Wrapper Script

```text
Permission denied: ./claude
```

**Solution:**

```bash
chmod +x ./claude
```

### Container Name Conflicts

If you encounter container name conflicts:

**Solution:**

```bash
# List all containers
container ps -a

# Remove stopped containers
container rm claude-sandbox-0

# Or prune all stopped containers
container system prune
```

## Development

### Modifying the Image

1. Edit `Dockerfile`
2. Rebuild: `make build-no-cache`
3. Test: `make test`

### Adding MCP Servers

To add new MCP servers:

1. Install the server in `Dockerfile`:

   ```dockerfile
   RUN npm install -g @modelcontextprotocol/server-xyz
   ```

2. Add configuration to `/mcp.json`:

   ```json
   "xyz": {
     "command": "/usr/local/bin/bunx",
     "args": ["@modelcontextprotocol/server-xyz"]
   }
   ```

3. Rebuild the image

### Customizing the Wrapper

Edit the `claude` script to:

- Change mount points
- Add environment variables
- Modify container runtime flags
- Customize container naming logic
- Adjust git config sync behavior

## Comparison: Docker vs Apple Container

| Feature         | Docker                 | Apple Container          |
|-----------------|------------------------|--------------------------|
| Platform        | Cross-platform         | macOS only               |
| Integration     | Separate daemon        | Native macOS             |
| Performance     | VM overhead            | Native virtualization    |
| Installation    | Docker Desktop         | `brew install container` |
| Commands        | `docker`               | `container`              |
| Image format    | `.tar`                 | `.oci`                   |
| Config location | `~/.claude-docker`     | `~/.claude-sandbox`      |

## Resources

- [Apple Container GitHub](https://github.com/apple/container)
- [Apple Virtualization Framework](https://developer.apple.com/documentation/virtualization)
- [Claude Code Documentation](https://github.com/anthropics/claude-code)
- [Model Context Protocol (MCP)](https://modelcontextprotocol.io)

## License

This project configuration is provided as-is for running Claude Code in a containerized environment.

## Author

Maintained by Alois Bělaška <alois@belaska.me>

---

Happy coding with Claude! 🚀
