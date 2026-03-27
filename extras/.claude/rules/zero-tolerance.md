# Zero-Tolerance Enforcement Rules

## Scope

These rules apply to ALL sessions, ALL agents, ALL code changes, ALL phases. They are ABSOLUTE and NON-NEGOTIABLE. There is NO flexibility on any of these rules.

## ABSOLUTE RULE 1: Pre-Existing Failures MUST Be Resolved

When tests, red team validation, code review, or any analysis reveals a pre-existing failure:

**YOU MUST FIX IT.** Period.

"It was not introduced in this session" is NOT an acceptable response. If you found it, you own it.

**Required response to ANY pre-existing failure:**

1. Diagnose the root cause
2. Implement the fix
3. Write a regression test that fails without the fix and passes with it
4. Verify the fix with `pytest`
5. Include the fix in the current commit or a dedicated fix commit

**BLOCKED responses:**

- "This is a pre-existing issue, not introduced in this session"
- "This failure exists in the current codebase and is outside the scope of this change"
- "Noting this as a known issue for future resolution"
- ANY response that acknowledges a failure without fixing it

**The only acceptable exception:** The user explicitly says "skip this issue" or "ignore this for now."

## ABSOLUTE RULE 2: No Stubs, Placeholders, or Deferred Implementation — EVER

Stubs are BLOCKED. No approval process. No exceptions. The validate-workflow hook exits with code 2 (BLOCK) on detection.

Full detection patterns and enforcement: see `rules/no-stubs.md`.

## ABSOLUTE RULE 3: No Naive Fallbacks or Error Hiding

Hiding errors behind `except: pass`, `return None`, or silent discards is BLOCKED.

Full detection patterns and acceptable exceptions: see `rules/no-stubs.md` Section 3.

## ABSOLUTE RULE 4: No Workarounds for Core SDK Issues

When you encounter a bug in the SDK:

**DO NOT work around it. DO NOT re-implement it naively.**

**This is a BUILD repo.** You have the source. Fix it directly in the affected package. Do NOT file GitHub issues for your own repo — use the internal todo system.

**BLOCKED:** Naive re-implementations, post-processing to "fix" SDK output, downgrading to avoid bugs.

## ABSOLUTE RULE 5: Version Consistency on Release

When releasing ANY package, ALL version locations MUST be updated atomically:

1. `pyproject.toml` → `version = "X.Y.Z"`
2. `src/{package}/__init__.py` → `__version__ = "X.Y.Z"`

The session-start hook checks this automatically. **A release with mismatched versions is BLOCKED.**

## ABSOLUTE RULE 6: No Bypassing Hooks

Git hooks, pre-commit hooks, and validation hooks exist for a reason. NEVER use `--no-verify`, `--no-gpg-sign`, or any flag that skips hook execution.

**BLOCKED:** `git commit --no-verify`, `git push --no-verify`, disabling hooks via config.

## ABSOLUTE RULE 7: /walkthrough Before /redteam — NO EXCEPTIONS

Before running `/redteam` or declaring any implementation "verified", you MUST run `/walkthrough` first. The walkthrough forces a complete click-through of every screen, every nav item, every link on both platforms.

**Why this rule exists:** The pattern of testing features in isolation (search works, nav looks right, titles show up) and declaring "PASS" — without ever clicking through the app as a user would — was caught by the human repeatedly. Individual feature tests miss navigation gaps, dead ends, unreachable features, and broken transitions that only appear when you use the product sequentially.

The walkthrough output (`workspaces/<project>/04-validate/user-flow-walkthrough.md`) MUST exist with zero BLOCKING gaps before red team can proceed.

**BLOCKED:** Running `/redteam` without a current walkthrough file. Declaring features "verified" based on API tests or individual screen checks alone.

## Enforcement

1. **validate-workflow.js hook** — BLOCKS stubs and error hiding in production code
2. **user-prompt-rules-reminder.js hook** — Injects zero-tolerance reminders every message
3. **session-start.js hook** — Checks package freshness and COC sync status
4. **intermediate-reviewer agent** — Validates compliance during code review
5. **security-reviewer agent** — Validates compliance during security review
6. **/walkthrough command** — MANDATORY before `/redteam` (checks for walkthrough file with zero BLOCKING gaps)

## Language Policy

Every "MUST" means "MUST." Every "BLOCKED" means the operation WILL NOT proceed. Every "NO" means "NO."
