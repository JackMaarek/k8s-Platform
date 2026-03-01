#!/bin/bash
# lib/logging.sh — shared log helpers
# Sourced by setup-local.sh and all lib/ modules.
# Safe to source multiple times (guard via LOGGING_LOADED).
[[ -n "${LOGGING_LOADED:-}" ]] && return 0
LOGGING_LOADED=1

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERR]${NC}   $*" >&2; }

ask_yn() {
  local question="$1"
  echo -e "${YELLOW}?${NC} $question [y/n] "
  read -r response < /dev/tty
  [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
}
