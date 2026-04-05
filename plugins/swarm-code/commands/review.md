---
description: Run an OpenCode code review against local git state to save Claude tokens
argument-hint: '[--wait|--background] [--base <ref>]'
allowed-tools: Read, Glob, Grep, Bash, AskUserQuestion
---

<!-- Made by Alejandro Apodaca Cordova (apoapps.com) -->

Run a code review via OpenCode (configured model with auto-fallback) against local git changes.

Raw slash-command arguments:
`$ARGUMENTS`

Core constraint:
- This is a review-only command.
- Do not fix issues, apply patches, or suggest you are about to make changes.
- Your job is to run the review, validate findings, and present them.

Execution mode rules:
- If `--wait`, run foreground. If `--background`, run background.
- Otherwise, estimate review size:
  - Run `git status --short` and `git diff --shortstat` to gauge size.
  - If 1-2 small files: recommend foreground.
  - Otherwise: recommend background.
  - Use `AskUserQuestion` exactly once with two options (recommended first):
    - `Wait for results` / `Run in background`

Foreground flow:
- Run via bridge (tmux window, auto model):
```bash
BRIDGE="${CLAUDE_PLUGIN_ROOT:-/Volumes/SandiskSSD/Documents/Local/dev/apoapps/cc-skills/opencode-plugin-cc/plugins/opencode}/scripts/opencode-bridge.sh"
DIFF=$(git diff --cached; git diff)
bash "$BRIDGE" --type review "Review this git diff for bugs, security issues, and code quality. Output findings as: - [SEVERITY] file:line — description. Severity: CRITICAL/HIGH/MEDIUM/LOW. Max 10 findings ordered by severity.

## DIFF
$DIFF"
```
- Validate the output per `opencode-result-handling`:
  - Check that findings reference real files.
  - Spot-check 1-2 referenced files if suspicious.
  - If MiniMax missed obvious issues, add them in a "Claude additions" section.
- Present findings ordered by severity.
- Keep validation commentary under 200 tokens.

CRITICAL: After presenting review findings, STOP. Do not fix issues. Ask the user which ones to fix.

Model: auto-detected. No hardcoded model names.
