#!/usr/bin/env bash
# apply-extras.sh — Overlay kailash-sync extras onto the current project
#
# Usage:
#   From any project directory:
#     bash <(curl -sSL https://raw.githubusercontent.com/vflores-io/kailash-sync/main/apply-extras.sh)
#
#   Or if kailash-sync is cloned locally:
#     bash /path/to/kailash-sync/apply-extras.sh
#
# What it does:
#   Copies extras/.claude/commands/* and extras/.claude/rules/* into the current project,
#   overwriting upstream versions where they exist. These are project-level enhancements
#   that sit on top of the COC template.

set -euo pipefail

# Determine where extras live
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTRAS_DIR="$SCRIPT_DIR/extras"

if [ ! -d "$EXTRAS_DIR" ]; then
  echo "❌ extras/ directory not found at $EXTRAS_DIR"
  exit 1
fi

# Ensure we're in a project directory with .claude/
if [ ! -d ".claude" ]; then
  echo "❌ No .claude/ directory found. Run this from a project root."
  exit 1
fi

echo "==> Applying kailash-sync extras to $(basename "$(pwd)")..."

# Copy commands
if [ -d "$EXTRAS_DIR/.claude/commands" ]; then
  mkdir -p .claude/commands
  for f in "$EXTRAS_DIR/.claude/commands"/*.md; do
    name=$(basename "$f")
    cp "$f" ".claude/commands/$name"
    echo "  ✓ .claude/commands/$name"
  done
fi

# Copy rules
if [ -d "$EXTRAS_DIR/.claude/rules" ]; then
  mkdir -p .claude/rules
  for f in "$EXTRAS_DIR/.claude/rules"/*.md; do
    name=$(basename "$f")
    cp "$f" ".claude/rules/$name"
    echo "  ✓ .claude/rules/$name"
  done
fi

echo "==> Done. Extras applied."
echo ""
echo "Files changed — if .claude/rules/ was updated, restart your Claude Code session."
