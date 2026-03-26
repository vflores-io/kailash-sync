#!/usr/bin/env node
// check-kailash-updates.js — SessionStart hook that checks if upstream COC template has updates
//
// Reads .sync-kailash.conf for the upstream repo URL, compares the latest
// upstream commit with the local kailash-setup subtree's last merge commit.
// If they differ, prints a reminder to sync.

const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const projectDir =
  process.env.CLAUDE_PROJECT_DIR || process.cwd();
const confPath = path.join(projectDir, ".sync-kailash.conf");
const subtreeDir = path.join(projectDir, "kailash-setup");

// Skip if sync workflow not set up
if (!fs.existsSync(confPath) || !fs.existsSync(subtreeDir)) {
  process.exit(0);
}

// Read upstream URL from config
const conf = fs.readFileSync(confPath, "utf-8");
const match = conf.match(/UPSTREAM_REPO="([^"]+)"/);
if (!match) {
  process.exit(0);
}
const upstreamUrl = match[1];

try {
  // Get latest upstream commit (network call — may fail offline, that's OK)
  const remoteHead = execSync(
    `git ls-remote ${upstreamUrl} refs/heads/main 2>/dev/null`,
    { encoding: "utf-8", timeout: 10000 }
  )
    .trim()
    .split(/\s/)[0];

  if (!remoteHead) {
    process.exit(0);
  }

  // Get the last subtree merge commit hash
  const localHead = execSync(
    `git log -1 --format=%H -- kailash-setup/ 2>/dev/null`,
    { encoding: "utf-8", cwd: projectDir }
  ).trim();

  // Get the squash-merged upstream hash from the subtree merge commit message
  const mergeMsg = execSync(
    `git log -1 --format=%B -- kailash-setup/ 2>/dev/null`,
    { encoding: "utf-8", cwd: projectDir }
  ).trim();

  // If the remote HEAD appears in our last merge message, we're up to date
  if (mergeMsg.includes(remoteHead.substring(0, 12))) {
    // Up to date — say nothing
    process.exit(0);
  }

  // Updates available
  console.log(
    `[kailash-sync] Upstream COC template has updates. Run: ./sync-kailash.sh --pull --apply`
  );
} catch (e) {
  // Network error, git error, offline — silently skip
  process.exit(0);
}
