# Claude Code Container
# Alpine-based image with full MCP server support

FROM alpine:3

LABEL maintainer="Alois Bělaška <alois@belaska.me>"
LABEL description="Claude Code CLI with MCP server support"

# Install base dependencies
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
    shadow

# Create non-root user
RUN useradd -m -s /bin/bash claude && \
    mkdir -p /workspace && \
    chown -R claude:claude /workspace

# Install Bun globally
ENV BUN_INSTALL="/usr/local"
ENV PATH="$BUN_INSTALL/bin:$PATH"
RUN curl -fsSL https://bun.sh/install | bash

# Install Python MCP fetch server
RUN pip3 install --no-cache-dir --break-system-packages mcp-server-fetch

# Install Claude Code CLI globally via npm
RUN npm install -g @anthropic-ai/claude-code

# Install MCP server packages globally
RUN npm install -g \
    @modelcontextprotocol/server-filesystem \
    @modelcontextprotocol/server-memory

# Create MCP configuration file
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

# Switch to non-root user
USER claude

# Set working directory
WORKDIR /workspace

# Environment variables
ENV HOME="/home/claude"
ENV PATH="$BUN_INSTALL/bin:/bin:/usr/bin:/usr/local/bin:/usr/local/sbin:/home/claude/.npm-global/bin:$PATH"
ENV CLAUDE_CODE_SKIP_PERMISSIONS="true"
ENV DISABLE_AUTOUPDATER="1"
ENV CLAUDE_CODE_IDE_SKIP_AUTO_INSTALL="0"
ENV CLAUDECODE="1"

# Create volume mount point for credentials persistence
VOLUME ["/home/claude"]

# Default entrypoint runs Claude Code with --dangerously-skip-permissions
ENTRYPOINT [ "claude", "--dangerously-skip-permissions", "--allow-dangerously-skip-permissions", "--ide", "--mcp-config", "/mcp.json" ]
