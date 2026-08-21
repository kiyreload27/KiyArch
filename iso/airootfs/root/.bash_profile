if [[ "$(tty 2>/dev/null || true)" == /dev/tty1 && -z "${SSH_CONNECTION:-}" && -z "${SSH_TTY:-}" && "$(cat /proc/cmdline 2>/dev/null)" != *kiyarch_rescue=1* ]]; then
    exec /usr/local/bin/kiyarch-menu
fi
