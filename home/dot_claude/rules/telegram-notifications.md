## Purpose

Send Telegram notifications for important agent lifecycle events using:

```bash
~/.claude/scripts/telegram-notify.sh
```

---

## Completion

When a meaningful task is completed successfully:

1. Run:

```bash
~/.claude/scripts/telegram-notify.sh success "<summary>"
```

2. The summary must contain:

- agent role or responsibility
- completed action
- relevant area or feature

Example:

```bash
~/.claude/scripts/telegram-notify.sh success "Backend agent: implemented JWT authentication flow"
```

---

## Failure

When a task cannot be completed because of:

- errors
- missing dependencies
- blocked operations
- unresolved issues

Run:

```bash
~/.claude/scripts/telegram-notify.sh error "<summary>"
```

Example:

```bash
~/.claude/scripts/telegram-notify.sh error "Frontend agent: build failed due to missing dependency"
```

---

## Multi Agent Behavior

When multiple agents are running:

- Each agent sends its own notification.
- Do not wait for other agents.
- Include the agent responsibility in every message.
- Send only one final notification per task.

Examples:

```
Backend: completed API migration
Frontend: completed UI implementation
DevOps: completed deployment configuration
```

---

## Timing Rules

Send notifications only for:

- completed tasks
- failed tasks
- blocked tasks requiring user intervention

Do not send notifications for:

- individual commands
- intermediate steps
- small changes
- analysis

---

## Final Response

Before returning the final answer:

1. Send the Telegram notification.
2. Ensure the notification command completed.
3. Then provide the user-facing response.
