---
description: Initialize swarm-code — interactive setup wizard, model selection, project context, swarm profile
argument-hint: '[--upgrade] [--reset] [--test] [--json]'
allowed-tools: Bash(node:*), Bash(git:*), Bash(tmux:*), AskUserQuestion
---

<!-- Made by Alejandro Apodaca Cordova (apoapps.com) -->

# swarm-code init

Interactive setup wizard. Configures the swarm for this project. Run once per project.

Raw arguments: `$ARGUMENTS`

---

## Step 1 — Status check

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/opencode-runner.mjs" init --json $ARGUMENTS
```

Parse the JSON. If `$ARGUMENTS` contains `--upgrade`, `--reset`, `--test`, or `--json`, run the command and return verbatim output — skip all wizard steps.

---

## Step 2 — Model setup (if needed)

If `activeModel` is null in the JSON output:

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/opencode-runner.mjs" models
```

Use AskUserQuestion to ask:
- Question: "Which OpenCode model should be the primary worker?"
- Build options from the detected model list (max 4 options, prefer free/fast ones first)
- Include "I'll configure it later" as an option

Then set the chosen model:
```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/opencode-runner.mjs" init --set-primary "<chosen-model>"
```

---

## Step 3 — Project context interview

Ask these 3 questions using AskUserQuestion. Do all 3 in one message (you can call AskUserQuestion once with multiple questions if supported, or sequentially).

### Q1 — Goal
- Question: "What are you working on? (brief description of this project or current goal)"
- This is free text — show it as a single text input option + "Skip / use defaults"

### Q2 — Directories in scope
First detect available directories:
```bash
git ls-files 2>/dev/null | sed 's|/[^/]*$||' | sort -u | head -15
```

Use AskUserQuestion (multiSelect: true):
- Question: "Which directories are in scope for this swarm?"
- Options: [detected top-level dirs], "Whole repository", "I'll specify later"
- Max 4 options (pick most common top-level dirs)

### Q3 — Task types to delegate
Use AskUserQuestion (multiSelect: true):
- Question: "What kinds of tasks will you delegate to OpenCode?"
- Options:
  - "Code review" — reviewing diffs, PRs, security
  - "Planning & architecture" — designing systems, writing specs
  - "Analysis & Q&A" — answering questions, explaining code
  - "All of the above"

---

## Step 4 — Save swarm profile

Build a JSON profile from the answers and save it:

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/opencode-runner.mjs" init --save-profile '<JSON>'
```

Where `<JSON>` is:
```json
{
  "goal": "<Q1 answer>",
  "dirs": ["<Q2 answers>"],
  "tasks": ["<Q3 answers>"],
  "configuredAt": "<ISO date>"
}
```

---

## Step 5 — Print agent plan

Based on the task types, describe the swarm configuration to the user:

| Tasks selected | Agent plan |
|----------------|-----------|
| Code review only | 1 worker, heavy model, review-focused |
| Planning only | 1 worker, heavy model, architect-focused |
| Analysis/Q&A only | 1 fast worker, concise answers |
| Mixed (2+ types) | 1-2 workers, mixed model tiers |
| All / complex | 2-3 workers, orchestrated |

Print a short, friendly summary:
> "Swarm configured. I'll use [N] OpenCode worker(s) focused on [tasks]. Model: [model]. Dirs: [dirs]."

---

## After init — Claude delegates automatically

Once initialized, route tasks internally:

| Task type | Internal action |
|-----------|----------------|
| Analysis / questions | `Agent(subagent_type="swarm-code:opencode-worker", model="haiku", prompt="<task>")` |
| Code review | Same, with review-specific prompt |
| Implementation planning | Same, with planning-specific prompt |
| Multi-faceted | Multiple workers in parallel |

Claude picks the right approach — the user never needs to type these.

## Flags

| Flag | Action |
|------|--------|
| `--upgrade` | Pull latest from git, sync installed plugin |
| `--reset` | Clear model and profile configuration |
| `--test` | Test the active model with a probe |
| `--json` | Machine-readable output (skip wizard) |
