#!/bin/sh
# The agents in every session (Claude Code and the rest), for OmniWM's bar
# (~/.config/omniwm/shell/widgets/agents): how many are working, and whether one waits
# for you or errored; no value when there are none. Run by config.toml's hooks and
# dock poll; prints nothing, so the dock's cell stays hidden. Needs OmniWM's IPC.
list=$(/run/current-system/sw/bin/tuios list-agents --all-sessions --json 2>/dev/null)
states=$(printf '%s' "$list" | /usr/bin/jq -r '.agents[].state' 2>/dev/null)
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
# The same, for the notch island (~/.config/omniwm/shell/widgets/notch).
/opt/homebrew/bin/omniwmctl shell trigger notch update ${value:+"$value"} >/dev/null 2>&1 || :
# Each agent, for the notch's avatars and its "needs your help" card: pane id, session,
# name, state, harness, what blocks it, since when (ns), whether it finished unread,
# and what it is doing (or asking, while it waits for you).
crew=$(printf '%s' "$list" | /usr/bin/jq -c '[.agents[:8][] | {i: .window_id, x: .session, n: .name,
  s: .state, h: .harness_id, b: .blocked_by, t: .agent_state_at, u: (.finished_unread == true),
  m: ((if .state == "needs_input" then (.message // "") else "" end) as $ask
      | if $ask != "" then $ask else (.program_status[0].msg // .message // "") end | .[0:90])}]' 2>/dev/null)
/opt/homebrew/bin/omniwmctl shell trigger notch agents "${crew:-[]}" >/dev/null 2>&1 || :
