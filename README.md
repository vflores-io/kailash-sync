# Kailash Sync

Keep your project's COC template (agents, skills, rules, hooks) up to date with upstream — without losing your project-specific customizations.

## What This Solves

When you start a project from `kailash-coc-claude-py` or `kailash-coc-claude-rs`, you get a snapshot of the COC template at that point in time. As the template evolves (new agents, updated skills, bug fixes in hooks), your project falls behind. This sync workflow lets you pull updates cleanly.

## Starting a New Project

### Step 1: Clone the COC template

**For Python SDK projects:**
```bash
git clone https://github.com/terrene-foundation/kailash-coc-claude-py.git my-project
cd my-project
rm -rf .git && git init && git branch -m main
git add -A && git commit -m "chore: init from kailash-coc-claude-py template"
```

**For Rust-backed SDK projects (Python/Ruby bindings):**
```bash
git clone https://github.com/terrene-foundation/kailash-coc-claude-rs.git my-project
cd my-project
rm -rf .git && git init && git branch -m main
git add -A && git commit -m "chore: init from kailash-coc-claude-rs template"
```

### Step 2: Attach the sync workflow

**Python:**
```bash
curl -sSL https://raw.githubusercontent.com/vflores-io/kailash-sync/main/setup.sh | bash -s -- py
```

**Rust:**
```bash
curl -sSL https://raw.githubusercontent.com/vflores-io/kailash-sync/main/setup.sh | bash -s -- rs
```

This does three things:
1. Adds the upstream COC repo as a git subtree at `kailash-setup/`
2. Creates `sync-kailash.sh` and `.sync-kailash.conf` in your project
3. Wires up a session-start hook that checks for updates when you open Claude Code

### Step 3: Customize your project

Edit `CLAUDE.md` with your project-specific directives. The sync workflow will **never** overwrite your `CLAUDE.md` — it only shows you when upstream differs so you can merge manually.

## Updating Your Project

Whenever you want to pull the latest COC template changes:

```bash
./sync-kailash.sh --pull --apply
```

Or check what would change first (dry run):

```bash
./sync-kailash.sh --pull
```

The session-start hook also reminds you when updates are available.

## What Gets Synced vs Protected

### Synced (updated from upstream)

These directories are overwritten with the latest upstream versions:

| Directory | Contents |
|-----------|----------|
| `.claude/agents/` | Specialist agent definitions |
| `.claude/commands/` | Slash command definitions |
| `.claude/guides/` | Framework guides |
| `.claude/rules/` | Behavioral constraint rules |
| `.claude/skills/` | Domain knowledge (290+ files) |
| `scripts/hooks/` | Lifecycle hooks (Node.js) |
| `scripts/ci/` | CI validation scripts |
| `scripts/learning/` | Learning system scripts |
| `workspaces/instructions/` | Workspace phase instructions |

**Python-only:** `sdk-users/`, `mcp-configs/`, `instructions/`
**Rust-only:** `spec/`

### Package versions (updated in pyproject.toml)

The sync also checks Kailash package versions in your `pyproject.toml` against upstream:

**Python variant** updates: `kailash`, `kailash-nexus`, `kailash-dataflow`, `kailash-kaizen`, `kailash-pact`
**Rust variant** updates: `kailash-enterprise`

Only the version pins are updated — your project name, description, and non-Kailash dependencies are never touched. New packages that appear upstream are flagged for manual addition.

### Protected (never overwritten)

| Path | Why |
|------|-----|
| `CLAUDE.md` | Project-specific directives (diff shown, not synced) |
| `.claude/learning/` | Project-specific observations and instincts |
| `.claude/agents/project/` | Codified agents from /codify phase |
| `.claude/skills/project/` | Codified skills from /codify phase |
| `src/`, `apps/`, `docs/` | Your actual project code |
| `workspaces/<name>/` | Your workspace data (analysis, todos, etc.) |

## For Claude Code

When starting a new session on a project that has this sync workflow attached, you can check for upstream updates:

```bash
./sync-kailash.sh --pull
```

If updates are available, apply them:

```bash
./sync-kailash.sh --pull --apply
```

After syncing, review any CLAUDE.md differences flagged in the output and merge relevant changes into the project's CLAUDE.md manually.

## Files Added to Your Project

| File | Purpose |
|------|---------|
| `kailash-setup/` | Git subtree — upstream snapshot (do not edit directly) |
| `sync-kailash.sh` | The sync script you run |
| `.sync-kailash.conf` | Configuration: upstream URL and directory mappings |

## Variants

| Variant | Upstream Repo | For |
|---------|--------------|-----|
| `py` | `terrene-foundation/kailash-coc-claude-py` | Pure Python Kailash SDK projects |
| `rs` | `terrene-foundation/kailash-coc-claude-rs` | Rust-backed Python/Ruby projects |

Both variants use the same `sync-kailash.sh` script — only the config (upstream URL and directory list) differs.
