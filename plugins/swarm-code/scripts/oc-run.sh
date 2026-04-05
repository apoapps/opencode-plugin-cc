#!/usr/bin/env bash
# oc-run.sh — headless OpenCode runner with colored log output
# Usage: bash oc-run.sh "<prompt>" [model] [cwd]
#
# Runs opencode headlessly (no TUI, no server required).
# Streams colored progress to /tmp/swarm-code-logs/oc-team.log.
# Prints JSON result: {"job":"<id>","out":"<path>","status":<0|1>}
#
# Made by Alejandro Apodaca · apoapps.com

PROMPT="${1:-}"
MODEL="${2:-}"
WORK_DIR="${3:-$(pwd)}"

if [[ -z "$PROMPT" ]]; then
  printf '{"error":"no prompt","status":1}\n'
  exit 1
fi

LOG_DIR="/tmp/swarm-code-logs"
LOG="$LOG_DIR/oc-team.log"
mkdir -p "$LOG_DIR"

JOB_ID="$(date +%s%3N)"
OUT="/tmp/oc-${JOB_ID}.out"

# ── Colors ──────────────────────────────────────────────────────────────
CYAN='\033[38;5;87m'
DIM='\033[2m'
GREEN='\033[38;5;114m'
RED='\033[38;5;203m'
YELLOW='\033[38;5;221m'
RESET='\033[0m'

log() { printf '%s\n' "$1" >> "$LOG"; }

# ── Resolve model ────────────────────────────────────────────────────────
# Use passed model, or fall back to first model in opencode config
if [[ -z "$MODEL" ]]; then
  # Try reading from swarm-code state
  STATE_FILE="/tmp/opencode-companion/$(echo "$WORK_DIR" | md5)/state.json"
  if [[ -f "$STATE_FILE" ]]; then
    MODEL="$(node -e "try{const s=JSON.parse(require('fs').readFileSync('$STATE_FILE','utf8')); process.stdout.write((s.modelPriority||[])[0]||'')}catch{}" 2>/dev/null)"
  fi
fi

# ── Log job start ────────────────────────────────────────────────────────
log ""
log "$(printf "${CYAN}  ⚡ job %s starting${RESET}" "$JOB_ID")"
if [[ -n "$MODEL" ]]; then
  log "$(printf "${DIM}     model: %s${RESET}" "$MODEL")"
fi
log "$(printf "${DIM}     task: %s${RESET}" "$(echo "$PROMPT" | head -c 80)")"

# ── Run opencode headlessly ───────────────────────────────────────────────
# opencode run --model <model> --dir <cwd> "<prompt>"
OC_BIN="$(command -v opencode 2>/dev/null)"

if [[ -z "$OC_BIN" ]]; then
  log "$(printf "${RED}  ✗ job %s failed: opencode not found in PATH${RESET}" "$JOB_ID")"
  printf '{"job":"%s","out":"","status":1,"error":"opencode not found"}\n' "$JOB_ID"
  exit 1
fi

# Build args
OC_ARGS=("run")
[[ -n "$MODEL" ]] && OC_ARGS+=("--model" "$MODEL")
[[ -n "$WORK_DIR" && -d "$WORK_DIR" ]] && OC_ARGS+=("--dir" "$WORK_DIR")
OC_ARGS+=("$PROMPT")

# Run and stream lines to log
"$OC_BIN" "${OC_ARGS[@]}" 2>&1 | while IFS= read -r line; do
  log "$(printf "${DIM}  │ %s${RESET}" "$line")"
  printf '%s\n' "$line"
done > "$OUT"

STATUS="${PIPESTATUS[0]}"

# ── Log completion ────────────────────────────────────────────────────────
if [[ $STATUS -eq 0 ]]; then
  LINES="$(wc -l < "$OUT" 2>/dev/null || echo 0)"
  log "$(printf "${GREEN}  ✓ job %s done (%s lines)${RESET}" "$JOB_ID" "$LINES")"
  log "$(printf "${YELLOW}  ──────────────────────────────────────────────────${RESET}")"
else
  log "$(printf "${RED}  ✗ job %s failed (exit %d)${RESET}" "$JOB_ID" "$STATUS")"
fi

# ── Emit JSON result for caller ───────────────────────────────────────────
printf '{"job":"%s","out":"%s","status":%d}\n' "$JOB_ID" "$OUT" "$STATUS"
