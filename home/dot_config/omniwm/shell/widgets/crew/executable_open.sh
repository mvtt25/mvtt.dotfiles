#!/bin/sh
# Crew's provider: the office's Open button. For each ["action", id, "open", {session, pane}]
# from OmniWM it shows that TUIOS session in the attached client, focuses the agent's pane
# there, brings Ghostty forward, and answers ["result", id, ok, error].
TUIOS=/run/current-system/sw/bin/tuios
JQ=/usr/bin/jq
OMNIWMCTL=/opt/homebrew/bin/omniwmctl

reply() {
    printf '["result",%s,%s,%s]\n' "$1" "$2" "$3"
}

while IFS= read -r frame; do
    id=$(printf '%s' "$frame" | $JQ -c 'if .[0] == "action" then .[1] else empty end' 2>/dev/null)
    [ -n "$id" ] || continue
    session=$(printf '%s' "$frame" | $JQ -r '.[3].session // empty')
    pane=$(printf '%s' "$frame" | $JQ -r '.[3].pane // empty')
    if [ "$(printf '%s' "$frame" | $JQ -r '.[2]')" != "open" ] || [ -z "$session" ] || [ -z "$pane" ]; then
        reply "$id" false '"open needs a session and a pane"'
        continue
    fi
    if ! failure=$($TUIOS focus-window "$pane" -s "$session" 2>&1 >/dev/null); then
        reply "$id" false "$(printf '%s' "$failure" | $JQ -Rs '.[0:200]')"
        continue
    fi
    # Then, if no client shows the agent's session, switch the one in Ghostty (the first that shows any) to it.
    client=$($TUIOS list-clients --json 2>/dev/null | $JQ -r --arg s "$session" \
        '[.[] | select(.session != "")] | if any(.session == $s) then empty else (.[0].client_id // empty) end')
    if [ -n "$client" ]; then
        $TUIOS switch-session --client "$client" "$session" >/dev/null 2>&1
    fi
    # shortcut: with several Ghostty windows this raises the most recent one; map client pids to windows if that matters.
    window=$($OMNIWMCTL query windows --format json 2>/dev/null | $JQ -r \
        '[.. | objects | select(.app?.bundleId? == "com.mitchellh.ghostty")] | sort_by(.focusRank) | .[0].id // empty')
    if [ -n "$window" ]; then
        $OMNIWMCTL window focus "$window" >/dev/null 2>&1
    fi
    reply "$id" true null
done
