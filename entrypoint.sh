#!/bin/bash
# ============================================================================
# Claude Code Container Entrypoint
# ============================================================================
# Seeds plugins on first boot, then starts Claude Code.
#
# Because /home/claude is volume-mounted from ~/.claude-sandbox at runtime,
# any config written during `docker build` is hidden by the mount. This
# entrypoint detects first boot (no marker file) and installs required
# plugins into the persistent volume.
# ============================================================================

MARKER="$HOME/.claude/.plugins-seeded"

if [ ! -f "$MARKER" ]; then
    mkdir -p "$HOME/.claude"
    /usr/local/bin/claude plugin install rust-analyzer-lsp 2>/dev/null && \
    /usr/local/bin/claude plugin install pyright-lsp 2>/dev/null && \
        touch "$MARKER" || \
        echo "[entrypoint] Warning: rust-analyzer-lsp plugin install failed (will retry next boot)"
fi

exec /sbin/tini -- /usr/local/bin/claude \
    --dangerously-skip-permissions \
    --allow-dangerously-skip-permissions \
    --ide \
    --mcp-config /mcp.json \
    "$@"
