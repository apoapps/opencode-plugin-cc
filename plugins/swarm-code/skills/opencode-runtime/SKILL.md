---
name: opencode-runtime
description: Delegate a task to an OpenCode worker (Haiku subagent). No tmux required. Use for analysis, code review, planning, or any task where offloading saves Claude tokens.
user-invocable: false
---

<!-- Made by Alejandro Apodaca Cordova (apoapps.com) -->

# OpenCode Runtime

Spawn a Haiku subagent that runs OpenCode via bash. Use this when delegating a well-defined task saves tokens vs doing it yourself.

## How to delegate (the only thing you need to do)

Use the Agent tool with:
- `subagent_type`: `"swarm-code:opencode-worker"`
- `model`: `"haiku"`
- `prompt`: your full task description (be specific — the worker has no context)

Example:
```
Agent(
  subagent_type="swarm-code:opencode-worker",
  model="haiku",
  prompt="Review the auth middleware in src/middleware/auth.ts for security issues. List findings as: [SEVERITY] file:line — description."
)
```

The Haiku agent will:
1. ACK via SendMessage
2. Run `oc-run.sh` which calls `opencode run --model <model> "<prompt>"`
3. Stream colored progress to `/tmp/swarm-code-logs/oc-team.log` (visible in oc-team pane if tmux active)
4. Return the result via SendMessage

## When to use

- Code review, analysis, or architectural planning with clear scope
- Tasks over ~200 words of context that don't need live file edits
- Offloading repetitive analysis work (linting patterns, summarizing logs, etc.)

## When NOT to use

- Tasks requiring iterative file editing — do those yourself
- Tasks where you need intermediate results to proceed
- Simple lookups or questions you can answer immediately

## No tmux required

The oc-team split-pane is **optional eye candy**. The worker runs fine without it.
If tmux is active and `/swarm-code:init` was run, colored logs appear in the oc-team pane automatically.

## Model setup

Models are configured once via:
```
/swarm-code:init
```
The worker picks the best available model from config. You can override by passing a model ID as the second argument to `oc-run.sh` inside the worker prompt.
