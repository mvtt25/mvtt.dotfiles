#!/bin/sh
# Ghostty's command (./config). OmniWM's quake terminal (alt-w) reads this config
# too: there, under OmniWM, a plain login shell; in Ghostty's own window, TUIOS.
p=$$
while [ "$p" -gt 1 ]; do
  case $(ps -o comm= -p "$p") in
    */OmniWM) exec "${SHELL:-/bin/zsh}" -l ;;
  esac
  p=$(ps -o ppid= -p "$p" | tr -d ' ')
done
exec /run/current-system/sw/bin/tuios attach
