#!/usr/bin/env bash
# oc-team-ui.sh — swarm-code monitor pane
# Logo art © apoapps.com — proprietary, not for redistribution.
# Made by Alejandro Apodaca · apoapps.com

DIM='\033[2m'
CYAN='\033[38;5;87m'
BOLD='\033[1m'
RESET='\033[0m'
GRAY='\033[38;5;240m'
YELLOW='\033[38;5;221m'

SHARED_LOG="${CLAUDE_PLUGIN_DATA:-/tmp}/swarm-code-logs/oc-team.log"
mkdir -p "$(dirname "$SHARED_LOG")"
touch "$SHARED_LOG"

clear

printf "${CYAN}"
cat << 'LOGO'
    ___      ___      ___      ___      ___      ___      ___
   /\  \    /\  \    /\  \    /\  \    /\  \    /\  \    /\__\
  /::\  \  /::\  \  /::\  \  /::\  \  /::\  \  /::\  \  /:/  /
 /:/\:\__\/:/\:\__\/:/\:\__\/:/\:\__\/:/\:\__\/:/\:\__\/:/__/
 \:\ \/__/\:\/:/  /\:\ \/__/\:\/:/  /\:\ \/__/\:\/:/  /\:\  \
  \:\__\   \::/  /  \:\__\   \::/  /  \:\__\   \::/  /  \:\__\
   \/__/    \/__/    \/__/    \/__/    \/__/    \/__/    \/__/
LOGO
printf "${RESET}"

printf "${DIM}                    made by Alejandro Apodaca · apoapps.com${RESET}\n"
printf "\n"
printf "  ${BOLD}swarm-code${RESET} ${GRAY}·${RESET} ${DIM}oc-team monitor${RESET}\n"
printf "  ${GRAY}❯${RESET} ${DIM}Claude delegates jobs here automatically${RESET}\n"
printf "\n"
printf "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
printf "\n"
printf "  ${DIM}${YELLOW}waiting for jobs...${RESET}\n\n"

exec tail -f "$SHARED_LOG"
