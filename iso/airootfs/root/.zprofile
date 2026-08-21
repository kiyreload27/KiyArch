# Preserve Archiso's scripted-startup and accessibility hooks before handing
# the local live tty to KiyArch.
if grep -Fqa 'accessibility=' /proc/cmdline 2>/dev/null; then
    setopt SINGLE_LINE_ZLE
fi

if [[ -o interactive && -z "${DISPLAY:-}" && "$(tty 2>/dev/null || true)" == "/dev/tty1" && -z "${SSH_CONNECTION:-}" && -z "${SSH_TTY:-}" && "$(cat /proc/cmdline 2>/dev/null || true)" != *kiyarch_rescue=1* ]]; then
    [[ -x "$HOME/.automated_script.sh" ]] && "$HOME/.automated_script.sh"
    exec /usr/local/bin/kiyarch-menu
fi
