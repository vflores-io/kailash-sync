---
name: walkthrough
description: "Force a complete click-through of every screen before /redteam can proceed."
---

## User Flow Walkthrough (Mandatory before /redteam)

This command forces a complete click-through of every screen, every nav item, every link, and every button — documenting what the user sees and what they can do next at each step. No feature is "done" until this walkthrough passes.

### Execution

1. **Open every nav item** in order (sidebar on web, bottom nav + More on mobile)
2. **For each screen**, document:
   - What is visible
   - What can the user click/tap
   - Where does each click lead
   - Can the user get back
   - Is there a dead end (no way forward, no way back, empty state with no guidance)
3. **For each primary entity** (matter, patient, order, etc.), open every tab and verify:
   - Content loads
   - Links work
   - The user can complete a task from this screen
4. **For every action button**, click it and verify:
   - It does something
   - The result is visible to the user
   - The user knows what happened (success/error feedback)
5. **Document every gap** found — missing nav links, dead ends, broken transitions, empty states without guidance, features that exist but can't be reached

### Output

Write `workspaces/<project>/04-validate/user-flow-walkthrough.md` with:

- Timestamp and commit hash
- Every screen visited with result (PASS/FAIL)
- Every gap found with severity (BLOCKING = user stuck, HIGH = user confused, MEDIUM = user inconvenienced)
- Screenshots of every failure

### Gate

This file MUST exist and have zero BLOCKING gaps before `/redteam` can proceed. If BLOCKING gaps are found, fix them first, then re-run `/walkthrough`.

### Tools

- Web: Playwright MCP (browser_navigate, browser_click, browser_snapshot, browser_take_screenshot)
- Mobile: Marionette MCP (connect, tap, take_screenshots, get_interactive_elements)
- Both platforms must be walked through independently

### Mindset

You are NOT an engineer checking if code works. You are the end user who just opened this app for the first time. At every screen ask:

- "What am I supposed to do here?"
- "How do I get to [feature X] from here?"
- "I just finished [task Y], now what?"
- "Where is my data?"
- "How do I search for something?"

If you cannot answer these questions by looking at the screen, it's a gap.
