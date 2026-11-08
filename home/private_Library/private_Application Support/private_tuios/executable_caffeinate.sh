#!/bin/sh
# The dock's caffeinate cell (config.toml): whether the Mac stays awake with the
# display off. On while a caffeinate runs that Claude Code did not start (it runs its
# own, five minutes at a time, while it works), so one started by hand in a pane
# counts too. A click (toggle) starts `caffeinate -i` (it keeps the system up, on
# battery too, and lets the display sleep and lock) or stops them all.
pids=
for p in $(pgrep -x caffeinate); do
  [ "$(ps -o comm= -p "$(ps -o ppid= -p "$p")")" = claude ] || pids="$pids $p"
done

if [ "$1" = toggle ]; then
  if [ -n "$pids" ]; then kill $pids; else caffeinate -i >/dev/null 2>&1 & fi
  exec tuios refresh-dock caffeinate
fi

# On: a green pill, as the agents cell's yellow and red ones. Off: gray, no pill.
if [ -n "$pids" ]; then printf '\033[30;42m 󰅶 on \033[0m\n'; else printf '\033[90m󰛊 off\033[0m\n'; fi
