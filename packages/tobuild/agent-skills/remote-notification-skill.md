---
name: remote-notification
description: Trigger this skill whenever the user mentions they are running opencode remotely (e.g., via SSH, on a server, or in a headless environment) and cannot see the local output directly. Use this if the user says "I'm running this remotely", "I'm on my server", "I can't see the terminal", or "notify my phone when you're done." The skill instructs how to send status notifications to the user's phone using ntfy.sh.
---

# Skill: remote-notification

This skill provides instructions on how to send a push notification to the user's phone when they are running `opencode` remotely and can't monitor the output in real-time.

## Instructions

Whenever you complete a significant task, or when the user explicitly asks for a notification, use the following `curl` command to send a notification to the user's phone:

```bash
curl -d "[Summary of current status or task completion]" ntfy.sh/demolinux
```

### When to use:
- When the user indicates they are running `opencode` on a remote machine (SSH, server, etc.).
- When the user mentions they can't see the output right now.
- After finishing a long-running process (like a build, test suite, or large refactor) on a remote system.
- When the user explicitly asks: "let me know on my phone when you're done."

### Example:
- User: "I'm running this on my server, can you notify me when the tests are done?"
- Action: Run `npm test` and then `curl -d "Tests completed successfully on server." ntfy.sh/demolinux`
