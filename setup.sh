#!/bin/bash
# setup.sh — Bootstrap the sync workflow for a Kailash COC project
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/vflores-io/kailash-sync/main/setup.sh | bash -s -- py
#   curl -sSL https://raw.githubusercontent.com/vflores-io/kailash-sync/main/setup.sh | bash -s -- rs
#
# Or locally:
#   bash setup.sh py
#   bash setup.sh rs
#
# Prerequisites:
#   - You are in the root of a freshly cloned kailash-coc-claude-py or -rs project
#   - The project has a git repo initialized
#   - git, rsync, and node are available

set -euo pipefail

# --- Argument parsing ---

VARIANT="${1:-}"

if [ -z "$VARIANT" ]; then
  echo "Usage: $0 <py|rs>"
  echo ""
  echo "  py  — For projects based on kailash-coc-claude-py (pure Python SDK)"
  echo "  rs  — For projects based on kailash-coc-claude-rs (Rust-backed Python/Ruby)"
  exit 1
fi

case "$VARIANT" in
  py)
    UPSTREAM_REPO="https://github.com/terrene-foundation/kailash-coc-claude-py.git"
    UPSTREAM_NAME="kailash-coc-claude-py"
    ;;
  rs)
    UPSTREAM_REPO="https://github.com/terrene-foundation/kailash-coc-claude-rs.git"
    UPSTREAM_NAME="kailash-coc-claude-rs"
    ;;
  *)
    echo "Error: Unknown variant '$VARIANT'. Use 'py' or 'rs'."
    exit 1
    ;;
esac

echo "==> Setting up sync workflow for $UPSTREAM_NAME..."

# --- Validation ---

if [ ! -d ".git" ]; then
  echo "Error: Not a git repository. Run from the project root."
  exit 1
fi

if [ ! -f ".claude/settings.json" ] || [ ! -d ".claude/agents" ]; then
  echo "Error: This doesn't look like a Kailash COC project."
  echo "Expected .claude/settings.json and .claude/agents/ to exist."
  exit 1
fi

if [ -d "kailash-setup" ]; then
  echo "Sync workflow already set up (kailash-setup/ exists)."
  echo "To update: ./sync-kailash.sh --pull --apply"
  exit 0
fi

# --- Add subtree ---

echo "==> Adding kailash-setup subtree from $UPSTREAM_NAME..."
git subtree add --prefix=kailash-setup "$UPSTREAM_REPO" main --squash

# --- Generate sync-kailash.sh ---

echo "==> Creating sync-kailash.sh..."

cat > sync-kailash.sh <<'SYNCEOF'
#!/bin/bash
# sync-kailash.sh — Sync Kailash COC template from subtree into project
#
# Usage:
#   ./sync-kailash.sh              # Dry run (show what would change)
#   ./sync-kailash.sh --apply      # Actually sync files
#   ./sync-kailash.sh --pull       # Pull latest from upstream, then dry run
#   ./sync-kailash.sh --pull --apply  # Pull latest and sync
#
# Protected (never overwritten):
#   - Root CLAUDE.md (project-specific — shows diff instead)
#   - .claude/learning/ (project-specific observations/instincts)
#   - .claude/agents/project/ and .claude/skills/project/ (codified knowledge)

set -euo pipefail

SUBTREE_DIR="kailash-setup"
APPLY=false
PULL=false

for arg in "$@"; do
  case $arg in
    --apply) APPLY=true ;;
    --pull)  PULL=true ;;
    --help|-h)
      echo "Usage: $0 [--pull] [--apply]"
      echo "  --pull   Pull latest from upstream before syncing"
      echo "  --apply  Actually apply changes (default is dry run)"
      exit 0
      ;;
    *) echo "Unknown arg: $arg"; exit 1 ;;
  esac
done

if [ ! -d "$SUBTREE_DIR" ]; then
  echo "Error: $SUBTREE_DIR/ not found. Run from the repo root."
  exit 1
fi

# Read config
if [ ! -f ".sync-kailash.conf" ]; then
  echo "Error: .sync-kailash.conf not found."
  echo "This file should have been created by setup.sh."
  exit 1
fi
source .sync-kailash.conf

if $PULL; then
  echo "==> Pulling latest from upstream..."
  git subtree pull --prefix="$SUBTREE_DIR" "$UPSTREAM_REPO" main --squash
  echo ""
fi

if $APPLY; then
  echo "==> APPLYING changes..."
  RSYNC_FLAGS="-av"
else
  echo "==> DRY RUN (use --apply to actually sync)"
  RSYNC_FLAGS="-avn"
fi

CHANGES_FOUND=false

# Sync directories
IFS=',' read -ra DIRS <<< "$SYNC_DIRS"
for mapping in "${DIRS[@]}"; do
  SRC="${SUBTREE_DIR}/${mapping%%:*}/"
  DST="${mapping##*:}/"

  if [ ! -d "$SRC" ]; then
    continue
  fi

  if $APPLY; then
    mkdir -p "$DST"
  fi

  # Exclude project-specific dirs from being overwritten
  OUTPUT=$(rsync $RSYNC_FLAGS \
    --exclude='project/' \
    "$SRC" "$DST" 2>&1 || true)

  if echo "$OUTPUT" | grep -qE '^(deleting |>f|cf|cd)'; then
    CHANGES_FOUND=true
    echo ""
    echo "--- ${mapping##*:} ---"
    echo "$OUTPUT" | grep -vE '^(sending|receiving|total|sent |$|building file list|\./$)'
  fi
done

# Sync individual files
IFS=',' read -ra FILES <<< "$SYNC_FILES"
for mapping in "${FILES[@]}"; do
  SRC="${SUBTREE_DIR}/${mapping%%:*}"
  DST="${mapping##*:}"

  if [ ! -f "$SRC" ]; then
    continue
  fi

  if $APPLY; then
    mkdir -p "$(dirname "$DST")"
  fi

  if [ ! -f "$DST" ] || ! diff -q "$SRC" "$DST" > /dev/null 2>&1; then
    CHANGES_FOUND=true
    echo ""
    echo "--- ${mapping##*:} ---"
    if $APPLY; then
      cp "$SRC" "$DST"
      echo "  updated"
    else
      echo "  would update"
      diff --brief "$SRC" "$DST" 2>/dev/null || echo "  (new file)"
    fi
  fi
done

# Sync Kailash package versions in pyproject.toml
if [ -f "${SUBTREE_DIR}/pyproject.toml" ] && [ -f "pyproject.toml" ]; then
  echo ""
  echo "--- pyproject.toml (Kailash package versions) ---"

  # Extract kailash dependency lines from upstream
  UPSTREAM_DEPS=$(grep -E '^\s+"kailash' "${SUBTREE_DIR}/pyproject.toml" | sed 's/^[[:space:]]*//' | tr -d '",' || true)

  if [ -n "$UPSTREAM_DEPS" ]; then
    PKG_CHANGES=false
    while IFS= read -r upstream_line; do
      # Extract package name (everything before >= or ==)
      pkg_name=$(echo "$upstream_line" | sed 's/[>=<].*//' | xargs)

      # Find current version in project pyproject.toml
      current_line=$(grep -E "^\s+\"${pkg_name}[>=<\[]" "pyproject.toml" 2>/dev/null | sed 's/^[[:space:]]*//' | tr -d '",' || true)

      if [ -n "$current_line" ] && [ "$current_line" != "$upstream_line" ]; then
        PKG_CHANGES=true
        if $APPLY; then
          # Escape for sed: handle brackets and special chars
          escaped_current=$(printf '%s\n' "$current_line" | sed 's/[][\\/.^$*]/\\&/g')
          escaped_upstream=$(printf '%s\n' "$upstream_line" | sed 's/[&/\\]/\\&/g')
          sed -i '' "s/${escaped_current}/${escaped_upstream}/" "pyproject.toml" 2>/dev/null || \
          sed -i "s/${escaped_current}/${escaped_upstream}/" "pyproject.toml" 2>/dev/null || \
          echo "  ⚠ Could not auto-update $pkg_name — update manually"
          echo "  updated: $current_line -> $upstream_line"
        else
          echo "  would update: $current_line -> $upstream_line"
        fi
      elif [ -z "$current_line" ]; then
        PKG_CHANGES=true
        if $APPLY; then
          echo "  ⚠ New package: $upstream_line — add to pyproject.toml manually"
        else
          echo "  new package (not in project): $upstream_line"
        fi
      fi
    done <<< "$UPSTREAM_DEPS"

    if $PKG_CHANGES; then
      CHANGES_FOUND=true
    else
      echo "  All Kailash packages up to date."
    fi
  fi
fi

# Always show CLAUDE.md diff but never auto-sync it
if [ -f "${SUBTREE_DIR}/CLAUDE.md" ] && [ -f "CLAUDE.md" ]; then
  if ! diff -q "${SUBTREE_DIR}/CLAUDE.md" "CLAUDE.md" > /dev/null 2>&1; then
    CHANGES_FOUND=true
    echo ""
    echo "--- CLAUDE.md (NOT auto-synced — project-specific) ---"
    echo "  Upstream CLAUDE.md differs from yours."
    echo "  Review with:  diff ${SUBTREE_DIR}/CLAUDE.md CLAUDE.md"
    echo "  Or merge manually."
  fi
fi

# Report preserved directories
for preserve_dir in ".claude/learning" ".claude/agents/project" ".claude/skills/project"; do
  if [ -d "$preserve_dir" ]; then
    echo ""
    echo "--- $preserve_dir/ (preserved — project-specific) ---"
  fi
done

echo ""
if $CHANGES_FOUND; then
  if $APPLY; then
    echo "Sync complete."
  else
    echo "Changes found. Run with --apply to sync."
  fi
else
  echo "Everything is up to date."
fi
SYNCEOF

chmod +x sync-kailash.sh

# --- Generate config file ---

echo "==> Creating .sync-kailash.conf..."

if [ "$VARIANT" = "py" ]; then
  cat > .sync-kailash.conf <<'PYCONF'
# .sync-kailash.conf — Sync configuration (generated by setup.sh)
# Variant: py (kailash-coc-claude-py)

UPSTREAM_REPO="https://github.com/terrene-foundation/kailash-coc-claude-py.git"

# Directories to sync (subtree_path:dest_path, comma-separated)
SYNC_DIRS=".claude/agents:.claude/agents,.claude/commands:.claude/commands,.claude/guides:.claude/guides,.claude/rules:.claude/rules,.claude/skills:.claude/skills,scripts/hooks:scripts/hooks,scripts/ci:scripts/ci,scripts/learning:scripts/learning,scripts/plugin:scripts/plugin,sdk-users:sdk-users,mcp-configs:mcp-configs,instructions:instructions,tests:tests,workspaces/instructions:workspaces/instructions"

# Individual files to sync
SYNC_FILES=".claude/settings.json:.claude/settings.json,workspaces/README.md:workspaces/README.md,workspaces/CLAUDE.md:workspaces/CLAUDE.md"
PYCONF
else
  cat > .sync-kailash.conf <<'RSCONF'
# .sync-kailash.conf — Sync configuration (generated by setup.sh)
# Variant: rs (kailash-coc-claude-rs)

UPSTREAM_REPO="https://github.com/terrene-foundation/kailash-coc-claude-rs.git"

# Directories to sync (subtree_path:dest_path, comma-separated)
SYNC_DIRS=".claude/agents:.claude/agents,.claude/commands:.claude/commands,.claude/guides:.claude/guides,.claude/rules:.claude/rules,.claude/skills:.claude/skills,scripts/hooks:scripts/hooks,scripts/ci:scripts/ci,scripts/learning:scripts/learning,scripts/plugin:scripts/plugin,spec:spec,tests:tests,workspaces/instructions:workspaces/instructions"

# Individual files to sync
SYNC_FILES=".claude/settings.json:.claude/settings.json,workspaces/README.md:workspaces/README.md,workspaces/CLAUDE.md:workspaces/CLAUDE.md"
RSCONF
fi

# --- Wire up session-start hook ---

echo "==> Wiring up update-check hook..."
node -e "
const fs = require('fs');
const path = '.claude/settings.json';
if (!fs.existsSync(path)) { console.log('⚠ No settings.json found, skipping hook setup'); process.exit(0); }
const settings = JSON.parse(fs.readFileSync(path, 'utf-8'));

if (!settings.hooks) settings.hooks = {};
if (!settings.hooks.SessionStart) settings.hooks.SessionStart = [{ matcher: '', hooks: [] }];

const sessionStart = settings.hooks.SessionStart[0].hooks;
const hasHook = sessionStart.some(h => h.command && h.command.includes('check-kailash-updates'));

if (!hasHook) {
  sessionStart.push({
    type: 'command',
    command: 'node \"\$CLAUDE_PROJECT_DIR/scripts/hooks/check-kailash-updates.js\"',
    timeout: 20
  });
  fs.writeFileSync(path, JSON.stringify(settings, null, 2) + '\n');
  console.log('  Added check-kailash-updates hook to SessionStart');
} else {
  console.log('  Update hook already configured');
}
" 2>/dev/null || echo "  ⚠ Could not wire up hook automatically (Node.js required). Add manually."

# --- Commit ---

echo "==> Committing sync workflow setup..."
git add sync-kailash.sh .sync-kailash.conf
git commit -m "chore: add sync workflow for upstream COC template updates

- Added kailash-setup subtree from $UPSTREAM_NAME
- Added sync-kailash.sh + .sync-kailash.conf
- Wired up check-kailash-updates SessionStart hook

Usage: ./sync-kailash.sh --pull --apply

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"

echo ""
echo "==> Setup complete!"
echo ""
echo "To pull template updates in the future:"
echo "  ./sync-kailash.sh --pull --apply"
echo ""
echo "The SessionStart hook will check for updates on every new Claude Code session."
echo ""
