#!/usr/bin/env bash
# opencode-splash.sh — brand splash del swarm worker
# Logo art © apoapps.com — proprietary, not for redistribution.
#
# Made by Alejandro Apodaca Cordova (apoapps.com)

URL="${1:-}"
JOB_ID="${2:-}"

DIM='\033[2m'
CYAN='\033[38;5;87m'
BOLD='\033[1m'
RESET='\033[0m'
GRAY='\033[38;5;240m'

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

printf "${DIM}                              made by apoapps.com${RESET}\n"
printf "\n"
printf "  ${BOLD}swarm-code${RESET} ${GRAY}·${RESET} ${DIM}swarm worker${RESET}\n"
printf "  ${GRAY}❯${RESET} ${DIM}github.com/apoapps   ${GRAY}❯${RESET} ${DIM}apoapps.com${RESET}\n"

if [[ -n "$JOB_ID" ]]; then
  printf "  ${GRAY}❯${RESET} ${DIM}job: ${BOLD}%s${RESET}\n" "$JOB_ID"
  printf "  ${GRAY}❯${RESET} ${DIM}report: /tmp/oc-report-%s.md${RESET}\n" "$JOB_ID"
  printf "  ${GRAY}❯${RESET} ${DIM}done signal: ${BOLD}DONE:%s${RESET}\n" "$JOB_ID"
fi

printf "\n"
printf "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
printf "\n"

sleep 1.2

# Launch OpenCode TUI
if [[ -n "$URL" ]]; then
  exec opencode attach "$URL"
else
  exec opencode
fi
