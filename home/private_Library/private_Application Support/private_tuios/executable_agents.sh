#!/bin/sh
# The agents in every session (Claude Code and the rest), for OmniWM's bar
# (~/.config/omniwm/shell/widgets/agents): how many are working, and whether one waits
# for you or errored; no value when there are none. Run by config.toml's hooks and
# dock poll; prints nothing, so the dock's cell stays hidden. Needs OmniWM's IPC.
states=$(/run/current-system/sw/bin/tuios list-agents --all-sessions --json | /usr/bin/jq -r '.agents[].state')
value=
if [ -n "$states" ]; then
  n=$(printf '%s\n' "$states" | grep -c '^working$')
  case "$states" in
    *errored*) value="$n errored" ;;
    *needs_input*) value="$n needs_input" ;;
    *) value="$n ok" ;;
  esac
fi
/opt/homebrew/bin/omniwmctl shell trigger agents update ${value:+"$value"} >/dev/null 2>&1 || :
