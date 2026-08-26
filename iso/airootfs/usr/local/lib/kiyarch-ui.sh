#!/usr/bin/env bash
# shellcheck disable=SC2034 # Public color tokens are consumed by sourcing scripts.

# Midnight Forge console tokens. Keep these to the basic ANSI palette so the
# interface remains readable on the Linux VT, serial consoles, and SSH.
KIY_UI_RESET='\033[0m'
KIY_UI_BOLD='\033[1m'
KIY_UI_DIM='\033[2m'
KIY_UI_EMBER='\033[33m'
KIY_UI_TEMPER='\033[36m'
KIY_UI_OK='\033[32m'
KIY_UI_FAIL='\033[31m'

kiyarch_ui_banner() {
    printf '%b' "$KIY_UI_EMBER$KIY_UI_BOLD"
    printf '  /\\  K I Y A R C H\n'
    printf ' /__\\ MIDNIGHT FORGE\n'
    printf '%b\n' "$KIY_UI_RESET"
}

kiyarch_ui_rule() {
    local label="${1:-}"
    if [[ -n "$label" ]]; then
        printf '%b-- %s %b' "$KIY_UI_EMBER$KIY_UI_BOLD" "$label" "$KIY_UI_RESET"
        printf '%*s\n' "$((48 - ${#label} > 1 ? 48 - ${#label} : 1))" '' | tr ' ' '-'
    else
        printf '%b------------------------------------------------%b\n' "$KIY_UI_DIM" "$KIY_UI_RESET"
    fi
}

kiyarch_ui_key() {
    printf '%b[%s]%b' "$KIY_UI_EMBER$KIY_UI_BOLD" "$1" "$KIY_UI_RESET"
}
