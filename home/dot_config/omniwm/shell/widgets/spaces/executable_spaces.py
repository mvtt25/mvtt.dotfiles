#!/usr/bin/python3
# Provider for the notch's "spaces" component: the apps in each workspace, from OmniWM's
# workspace-bar feed, which OmniWM keeps up to date while the bar itself is off.
# Publishes the "spaces" state topic as {raw workspace name: [{i: window id,
# b: bundle id, a: app name, c: its windows, f: focused}]}.
import json
import signal
import subprocess
import sys
import threading

FEED = ["/opt/homebrew/bin/omniwmctl", "subscribe", "workspace-bar", "--reconnect", "--format", "ndjson"]


def spaces(event):
    result = {}
    payload = (event.get("result") or {}).get("payload") or {}
    for monitor in payload.get("monitors") or []:
        for workspace in monitor.get("workspaces") or []:
            result[workspace.get("rawName") or ""] = [
                {"i": item["id"], "b": item.get("bundleId") or "", "a": item.get("appName") or "",
                 "c": item.get("windowCount") or 1, "f": bool(item.get("isFocused"))}
                for item in workspace.get("windows") or [] if item.get("id")]
    return result


def main():
    feed = subprocess.Popen(FEED, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, text=True)

    def stop(*_):
        feed.terminate()
        sys.exit(0)

    signal.signal(signal.SIGTERM, stop)

    def follow_stdin():  # OmniWM closes stdin to stop the provider: the feed goes with it
        for _ in sys.stdin:
            pass
        feed.terminate()

    threading.Thread(target=follow_stdin, daemon=True).start()
    published = None
    for line in feed.stdout:
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if not isinstance(event, dict) or event.get("kind") != "event":
            continue
        frame = json.dumps(["state", "spaces", spaces(event)], separators=(",", ":"), sort_keys=True)
        if frame != published:
            sys.stdout.write(frame + "\n")
            sys.stdout.flush()
            published = frame
    feed.wait()


if __name__ == "__main__":
    main()
