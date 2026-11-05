#!/bin/bash
# Title: C5 Wardriver Pager Node
# Author: JustCallMeKoko
# Description: Adds Wi-Fi 6 GHz observations to a C5 Wardriver Core over ESP-NOW
# Version: 0.1.0
# Category: Reconnaissance

DIR="$(cd "$(dirname "$0")" && pwd)"; IFACE=wlan1mon; STATS=/tmp/c5-pager-node.json; LOGFILE=/tmp/c5-pager-node.log
RADIO_SET=0; OLD_HOP=""; OLD_CHANNEL=""
cleanup() {
  [ -n "${PID:-}" ] && kill "$PID" 2>/dev/null
  if [ "$RADIO_SET" = 1 ]; then
    [ -n "$OLD_HOP" ] && uci set pineapd.wlan1mon.hop="$OLD_HOP" || uci -q delete pineapd.wlan1mon.hop
    [ -n "$OLD_CHANNEL" ] && uci set pineapd.wlan1mon.channel="$OLD_CHANNEL" || uci -q delete pineapd.wlan1mon.channel
    /etc/init.d/pineapd restart >/dev/null 2>&1
  fi
}
trap cleanup EXIT INT TERM
command -v python3 >/dev/null 2>&1 || { ERROR_DIALOG "Python 3 is required for this development preview."; exit 1; }
iw dev "$IFACE" info >/dev/null 2>&1 || { ERROR_DIALOG "wlan1mon is unavailable."; exit 1; }
PROMPT_IMAGE "$DIR/splash.png"
CONFIRMATION_DIALOG "Start C5 Wardriver 6 GHz node?" || exit 0
OLD_HOP=$(uci -q get pineapd.wlan1mon.hop); OLD_CHANNEL=$(uci -q get pineapd.wlan1mon.channel)
uci set pineapd.wlan1mon.hop=0; uci set pineapd.wlan1mon.channel=6; RADIO_SET=1
/etc/init.d/pineapd restart >/dev/null 2>&1; sleep 3
python3 "$DIR/c5_pager_node.py" --iface "$IFACE" --stats "$STATS" >"$LOGFILE" 2>&1 & PID=$!
LOG cyan "C5 Wardriver Pager Node"
LOG white "6 GHz PSC scan active"
LOG white "Press A to stop"
WAIT_FOR_BUTTON_PRESS A >/dev/null 2>&1
kill "$PID" 2>/dev/null; wait "$PID" 2>/dev/null; PID=""
if [ -s "$STATS" ]; then
  summary=$(python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); print("Core: %s\n6 GHz seen: %d\nRecords sent: %d"%(s.get("core") or "not found",s["seen"],s["sent"]))' "$STATS")
  PROMPT "$summary"
else
  ERROR_DIALOG "Node stopped before producing status. See $LOGFILE"
fi
