# ============================================================================
# Claude Code Container
# ============================================================================
# Alpine-based container image with full MCP (Model Context Protocol) server
# support for running Claude Code CLI in an isolated environment.
#
# This image includes:
#   - Claude Code CLI (official Anthropic client)
#   - Three MCP servers (filesystem, memory, fetch)
#   - Development tools (git, python, node, bun)
#   - Database clients (postgresql, sqlite)
# ============================================================================

FROM alpine:3

LABEL maintainer="Alois Bělaška <alois@belaska.me>"
LABEL description="Claude Code CLI with MCP server support"

# ============================================================================
# Install Base Dependencies
# ============================================================================
# Install essential system packages and development tools:
#   - build-base: C/C++ compiler and build tools
#   - sqlite/postgresql: Database clients and development libraries
#   - bash, curl, git: Essential CLI tools
#   - nodejs, npm, python3: Runtime environments for MCP servers
#   - openssh-client: SSH support for git operations
#   - jq: JSON processing utility
#   - shadow: User management utilities
# ============================================================================
RUN apk add --no-cache \
    build-base \
    sqlite sqlite-dev \
    postgresql18-dev postgresql18-client \
    bash \
    curl \
    git \
    nodejs \
    npm \
    python3 \
    py3-pip \
    ca-certificates \
    openssh-client \
    tzdata \
    jq \
    shadow \
    tini

# ============================================================================
# User Setup
# ============================================================================
# Create a non-root user 'claude' for security best practices
# - Home directory: /home/claude
# - Workspace directory: /workspace (for mounting project files)
# ============================================================================
RUN useradd -m -s /bin/bash claude && \
    mkdir -p /workspace && \
    chown -R claude:claude /workspace

# ============================================================================
# Install Bun Runtime
# ============================================================================
# Bun is a fast JavaScript runtime used to execute MCP servers
# Installed globally to /usr/local for system-wide availability
# ============================================================================
ENV BUN_INSTALL="/usr/local"
ENV PATH="$BUN_INSTALL/bin:$PATH"
RUN curl -fsSL https://bun.sh/install | bash

# ============================================================================
# Install MCP Servers
# ============================================================================
# Install Model Context Protocol servers that extend Claude's capabilities:
#
# 1. mcp-server-fetch (Python): HTTP fetch capabilities for external APIs
# 2. server-filesystem (Node): File system operations within workspace
# 3. server-memory (Node): Persistent memory and knowledge graph
# ============================================================================
RUN pip3 install --no-cache-dir --break-system-packages mcp-server-fetch

# ============================================================================
# Install Claude Code CLI
# ============================================================================
# The official Claude Code command-line interface from Anthropic
# Installed globally via npm for system-wide access
# ============================================================================
RUN curl -fsSL https://claude.ai/install.sh | bash
RUN cp ~/.local/bin/claude /usr/local/bin && rm -rf ~/.local

# Install MCP server packages globally via npm
RUN npm install -g \
    @modelcontextprotocol/server-filesystem \
    @modelcontextprotocol/server-memory

# ============================================================================
# MCP Server Configuration
# ============================================================================
# Create the MCP configuration file at /mcp.json
# This file tells Claude Code which MCP servers to launch and how to run them
#
# Configured servers:
#   - filesystem: Access files within /workspace directory
#   - memory: Persistent knowledge graph and memory storage
#   - fetch: HTTP requests to external APIs and web resources
# ============================================================================
RUN cat <<'EOF' > /mcp.json
{
  "mcpServers": {
    "filesystem": {
      "command": "/usr/local/bin/bunx",
      "args": [
        "@modelcontextprotocol/server-filesystem",
        "/workspace"
      ]
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
EOF

# ============================================================================
# Runtime Configuration
# ============================================================================

# Switch to non-root user for security
USER claude

# Set working directory to the mounted workspace
WORKDIR /workspace

# ============================================================================
# Environment Variables
# ============================================================================
# Configure Claude Code behavior and runtime environment:
#
# PATH: Include all binary directories for system-wide tool access
# CLAUDE_CODE_SKIP_PERMISSIONS: Bypass interactive permission prompts
# DISABLE_AUTOUPDATER: Prevent automatic updates within container
# CLAUDE_CODE_IDE_SKIP_AUTO_INSTALL: Control IDE integration behavior
# CLAUDECODE: Flag indicating running in Claude Code environment
# ============================================================================
ENV HOME="/home/claude"
ENV PATH="$BUN_INSTALL/bin:/bin:/usr/bin:/usr/local/bin:/usr/local/sbin:/home/claude/.npm-global/bin:/home/claude/.local/bin:$PATH"
ENV CLAUDE_CODE_SKIP_PERMISSIONS="true"
ENV DISABLE_AUTOUPDATER="1"
ENV CLAUDE_CODE_IDE_SKIP_AUTO_INSTALL="0"
ENV CLAUDECODE="1"

# ============================================================================
# Volume Mount Points
# ============================================================================
# Define persistent volume for configuration and credentials
# The wrapper script mounts ~/.claude-sandbox to this location
# ============================================================================
VOLUME ["/home/claude"]

# ============================================================================
# Container Entrypoint
# ============================================================================
# Launch Claude Code CLI with the following flags:
#   tini: Lightweight init system to properly reap zombie processes and
#         forward signals to child processes (MCP servers)
#   --dangerously-skip-permissions: Skip all safety prompts (use with caution)
#   --allow-dangerously-skip-permissions: Confirm permission bypass
#   --ide: Enable IDE integration features
#   --mcp-config: Specify MCP server configuration file path
# ============================================================================
ENTRYPOINT [ "/sbin/tini", "--", "/usr/local/bin/claude", "--dangerously-skip-permissions", "--allow-dangerously-skip-permissions", "--ide", "--mcp-config", "/mcp.json" ]
