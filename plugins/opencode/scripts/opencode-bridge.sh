#!/usr/bin/env bash
# opencode-bridge.sh — bridge entre Claude Code y OpenCode CLI
#
# Interfaz mínima: solo el prompt. Todo lo demás es automático:
# - Tipo de tarea → detectado del contenido del prompt
# - System prompt → inyectado según tipo (basado en claude-code-sourcemap)
# - Modelo → detectado por opencode-runner según config del proyecto
# - tmux window → abierta automáticamente para visibilidad en tiempo real
#
# Made by Alejandro Apodaca Cordova (apoapps.com)
#
# Usage:
#   opencode-bridge.sh "<prompt>"
#   opencode-bridge.sh --type <ask|review|plan> "<prompt>"

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNNER="$SCRIPTS_DIR/opencode-runner.mjs"

# ─── Args ─────────────────────────────────────────────────────────────────────

TYPE_OVERRIDE=""
PROMPT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --type) TYPE_OVERRIDE="$2"; shift 2 ;;
    *)      PROMPT="$1"; shift ;;
  esac
done

if [[ -z "$PROMPT" ]]; then
  echo "Usage: opencode-bridge.sh \"<prompt>\" [--type ask|review|plan]" >&2
  exit 2
fi

# ─── Hook: auto-detect task type ─────────────────────────────────────────────

detect_type() {
  local lower
  lower="$(echo "$1" | tr '[:upper:]' '[:lower:]')"

  if echo "$lower" | grep -qE "(git diff|code review|revisa (el|los|esta|este)|review (the|these|this|my)|cambios|pull request|\bpr\b|staged|unstaged|diff)"; then
    echo "review"; return
  fi
  if echo "$lower" | grep -qE "(plan|architect|diseña|implementa|cómo (estructurar|construir|crear)|roadmap|pasos para|step.by.step|scaffold|estructura de)"; then
    echo "plan"; return
  fi
  echo "ask"
}

CMD="${TYPE_OVERRIDE:-$(detect_type "$PROMPT")}"

# ─── Hook: system prompt injection ───────────────────────────────────────────
# Esencia de los prompts de claude-code-sourcemap, adaptados para OpenCode.
# Se antepone al prompt del usuario para mejorar calidad sin que el caller
# tenga que especificar nada.

inject_system_context() {
  local cmd="$1"
  local user_prompt="$2"

  case "$cmd" in
    plan)
      # Basado en: claude-code-sourcemap ArchitectTool/prompt.ts
      cat << 'SYS'
[SYSTEM CONTEXT — software architect mode]
Analyze the technical requirements and produce a clear, actionable implementation plan.
The plan will be executed by a software engineer — be specific and detailed.
Do NOT write code. Do NOT ask if you should implement changes.
Structure your output:
1. Core approach (1-2 sentences)
2. Concrete steps in implementation order
3. Key decisions and tradeoffs
4. Files to create/modify (with paths)
Keep under 600 words unless complexity demands more.

[TASK]
SYS
      echo "$user_prompt"
      ;;

    review)
      # Basado en: claude-code-sourcemap BashTool commit analysis + OpenCode review pattern
      cat << 'SYS'
[SYSTEM CONTEXT — code reviewer mode]
Review the provided code/diff for bugs, security issues, and quality problems.
Output findings ONLY in this format:
- [SEVERITY] file:line — description
Severity levels: CRITICAL / HIGH / MEDIUM / LOW
Max 12 findings, ordered by severity (CRITICAL first).
Do NOT suggest fixes. Do NOT add explanations beyond the one-line description.
If no issues found, output: "No significant issues found."

[DIFF / CODE TO REVIEW]
SYS
      echo "$user_prompt"
      ;;

    ask)
      # Basado en: claude-code-sourcemap agent system prompt patterns
      cat << 'SYS'
[SYSTEM CONTEXT — analytical assistant mode]
You are running as a subagent inside Claude Code. Claude will read and validate your response.
Be maximally concise — no preamble, no "here is", no filler.
Jump straight to findings. Use bullet points and file:line references where applicable.
400 words max unless the task genuinely requires more.

[QUESTION / TASK]
SYS
      echo "$user_prompt"
      ;;
  esac
}

# ─── Job setup ────────────────────────────────────────────────────────────────

JOB_ID="$(date +%s%3N)"
OUTFILE="/tmp/oc-${JOB_ID}.out"
PROMPT_FILE="/tmp/oc-${JOB_ID}.prompt"
SCRIPT_FILE="/tmp/oc-${JOB_ID}.sh"
SENTINEL="__OC_DONE_${JOB_ID}__"
PANE_TITLE="oc:${CMD}"
MAX_WAIT=300
TMUX_BIN="$(command -v tmux 2>/dev/null || echo /opt/homebrew/bin/tmux)"

# Escribir prompt enriquecido (context + user prompt) al archivo
inject_system_context "$CMD" "$PROMPT" > "$PROMPT_FILE"

# ─── Runner script (ejecutado en tmux para visibilidad) ───────────────────────

cat > "$SCRIPT_FILE" << RUNNER_EOF
#!/usr/bin/env bash
FULL_PROMPT=\$(cat "$PROMPT_FILE")
printf "\033[1;36m⚡ opencode [%s]\033[0m\n" "$CMD"
printf "\033[2m%s\033[0m\n\n" "$(date '+%H:%M:%S')"
node "$RUNNER" $CMD "\$FULL_PROMPT" 2>&1 | tee "$OUTFILE"
echo "$SENTINEL" >> "$OUTFILE"
printf "\n\033[1;32m✓ done [%s]\033[0m\n" "$CMD"
sleep 3
RUNNER_EOF
chmod +x "$SCRIPT_FILE"

# ─── Hook: launch en tmux split-pane (fallback a background) ──────────────────

if [[ -n "${TMUX:-}" ]] && "$TMUX_BIN" info &>/dev/null 2>&1; then
  # Split current window vertically — pane lives below, auto-closes when done
  "$TMUX_BIN" split-window -v -l 35% "bash '$SCRIPT_FILE'"
elif "$TMUX_BIN" info &>/dev/null 2>&1; then
  # Inside a tmux session but TMUX var not set — new window fallback
  "$TMUX_BIN" new-window -n "$PANE_TITLE" "bash '$SCRIPT_FILE'"
else
  bash "$SCRIPT_FILE" &>/dev/null &
fi

# ─── Hook: wait for completion ────────────────────────────────────────────────

WAIT=0
while ! grep -q "$SENTINEL" "$OUTFILE" 2>/dev/null; do
  sleep 1
  WAIT=$((WAIT + 1))
  if [[ $WAIT -ge $MAX_WAIT ]]; then
    printf "ERROR: OpenCode timeout (%ds)\n" "$MAX_WAIT" >&2
    exit 1
  fi
done

# ─── Output (sin sentinel ni contexto interno) ────────────────────────────────

grep -v "$SENTINEL" "$OUTFILE"

rm -f "$PROMPT_FILE" "$SCRIPT_FILE"
