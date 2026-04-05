#!/usr/bin/env bash
# opencode-splash.sh — swarm-code super splash (once per session)
# Logo art © apoapps.com — proprietary, not for redistribution.
# Made by Alejandro Apodaca · apoapps.com

# ── Session guard — show splash only once per tmux session ──────────────
TMUX_SESSION="${TMUX_PANE:-none}"
SPLASH_MARKER="${TMPDIR:-/tmp}/.swarm-splash-${TMUX_SESSION//\//-}"

skip_splash=0
if [[ -f "$SPLASH_MARKER" ]]; then
  skip_splash=1
fi
touch "$SPLASH_MARKER" 2>/dev/null

# ── Colors ──────────────────────────────────────────────────────────────
R='\033[0m'
DIM='\033[2m'
BOLD='\033[1m'
CYAN='\033[38;5;87m'
CYAN2='\033[38;5;51m'
GRAY='\033[38;5;240m'
SILVER='\033[38;5;248m'
WHITE='\033[97m'
YELLOW='\033[38;5;221m'
GREEN='\033[38;5;114m'

hide_cursor() { printf '\033[?25l'; }
show_cursor() { printf '\033[?25h'; }
clear_line()  { printf '\033[2K\r'; }
move_up()     { printf '\033[%dA' "${1:-1}"; }

trap 'show_cursor; tput cnorm 2>/dev/null' EXIT INT TERM

# ── If already seen this session → go straight to oc-team-ui.sh ─────────
if [[ "$skip_splash" -eq 1 ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  exec bash "$SCRIPT_DIR/oc-team-ui.sh"
fi

# ── Full splash ──────────────────────────────────────────────────────────
clear
hide_cursor

LOGO_LINES=(
"                                ,▄▄▄▓██████████████▓▌▄▄,_"
"                          _▄▄██████████████████████████████▌▄_"
"                      _▄▓██████████████████████████████████████▓▄_"
"                   _▄██████████████████████████████████████████████▄_"
"                 ▄████████████████████████████████████████████████████▄"
"               ▄████████████████████████████████████████████████████████▌_"
"             ▄████████████████████████████████████████████████████████████▌_"
"           ▄██████████████████████▀▀╙└└└└└└└└└└└└└└╙▀▀██████████████████████▄"
"          ▓████████████████████▀  _▄▄▓▓▓▓▓▓▓▓▓▓▓▓▓▓▄▄_  ▀█████████████████████"
"        ┌█████████████████████  ╓█████████████████████▓,  █████████████████████µ"
"       ╒█████████████████████  ▄████████████████████████▄  █████████████████████▄"
"      ┌█████████████████████M  ██████████████████████████  ╫█████████████████████w"
"      ██████████████████████M  ██████████████████████████  ▐██████████████████████"
"     ╫████████████▀╙╙╫██████M  █████████████▀▀╙╙╙╙▀▀█████  ▐█████╙╙╙▀██████████████"
"     ███████████▌  ╓▓███████M  ███████▀▀\"             ╙▀█  ▐█████▓▌   █████████████⌐"
"    ▐███████████▌  █████████M  ███▀╙                       ▐███████M  █████████████▌"
"    ████████████M  █████████M  ╙                           ▐███████M  ██████████████"
"    ██████████╙└ ,▄█████████M                              ▐████████▄_ ╙▀███████████"
"    ██████████▄, └▀█████████M                              ▐████████╙─ ▄▄███████████"
"    ████████████W  █████████M                              ▐███████M  ▓█████████████"
"    ╫███████████▌  █████████M                              ▐███████M  ██████████████"
"    ?███████████▌  ╙▀███████M                              ▐██████▀   █████████████Ñ"
"     █████████████▄▄,▐██████M                              ▐█████╓╓▄▄██████████████"
"     \"██████████████████████M                              ▐██████████████████████M"
"      ╙█████████████████████N                              ▐█████████████████████▌"
"       ▀████████████████████▌                              ▓█████████████████████"
"        ▀████████████████████▄                            ▄████████████████████▌"
"         ╙████████████████████▓,                        ╓█████████████████████▀"
"           ██████████████████████▄▄_                _▄▄██████████████████████\""
"            ╙██████████████████████████████████████████████████████████████▀"
"              ╙██████████████████████████████████████████████████████████▀"
"                ╙██████████████████████████████████████████████████████▀"
"                  └▀████████████████████████████████████████████████▀\""
"                     └▀██████████████████████████████████████████▀╙"
"                         ╙▀██████████████████████████████████▀╙"
"                              ╙▀▀██████████████████████▀▀╙─"
)

# Phase 1 — reveal logo line by line, dim→bright
total=${#LOGO_LINES[@]}
for i in "${!LOGO_LINES[@]}"; do
  # First pass: dim
  printf "${DIM}${CYAN}%s${R}\n" "${LOGO_LINES[$i]}"
  sleep 0.02
done

# Phase 2 — flash bright
sleep 0.1
# Move cursor back to top of logo
printf '\033[%dA' "$total"
for i in "${!LOGO_LINES[@]}"; do
  printf '\033[2K'
  printf "${CYAN2}${BOLD}%s${R}\n" "${LOGO_LINES[$i]}"
done

# Phase 3 — settle back to dim cyan (final look)
sleep 0.15
printf '\033[%dA' "$total"
for i in "${!LOGO_LINES[@]}"; do
  printf '\033[2K'
  printf "${DIM}${CYAN}%s${R}\n" "${LOGO_LINES[$i]}"
done

# Tagline — type it out
printf "\n"
tagline="                    made by Alejandro Apodaca · apoapps.com"
printf "${DIM}"
for ((i=0; i<${#tagline}; i++)); do
  printf '%s' "${tagline:$i:1}"
  sleep 0.015
done
printf "${R}\n\n"

# Info bar — slide in
sleep 0.1
printf "  ${BOLD}${CYAN}swarm-code${R} ${GRAY}·${R} ${DIM}oc-team${R}\n"
sleep 0.08
printf "${GRAY}  ──────────────────────────────────────────────────────${R}\n"
sleep 0.08

# Animate "accepting jobs..."
printf "  "
msg="⏳ accepting jobs..."
printf "${DIM}${YELLOW}"
for ((i=0; i<${#msg}; i++)); do
  printf '%s' "${msg:$i:1}"
  sleep 0.025
done
printf "${R}\n\n"

sleep 0.3
show_cursor

# Hand off to oc-team-ui.sh tail loop (skipping the splash next time)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_LOG="${CLAUDE_PLUGIN_DATA:-/tmp}/swarm-code-logs/oc-team.log"
mkdir -p "$(dirname "$SHARED_LOG")"
touch "$SHARED_LOG"
exec tail -f "$SHARED_LOG"
