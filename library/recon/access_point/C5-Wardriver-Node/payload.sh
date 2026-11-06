#!/bin/bash
# Title: C5 Wardriver Pager Node
# Author: JustCallMeKoko
# Description: Adds Wi-Fi 6 GHz observations to a C5 Wardriver Core over ESP-NOW
# Version: 0.1.0
# Category: Reconnaissance

LAUNCH_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$LAUNCH_DIR/c5_pager_node.py" ]; then
  DIR="$LAUNCH_DIR"
elif [ -f /root/payloads/user/reconnaissance/c5_wardriver_node/c5_pager_node.py ]; then
  DIR=/root/payloads/user/reconnaissance/c5_wardriver_node
elif [ -f /mmc/root/payloads/user/reconnaissance/c5_wardriver_node/c5_pager_node.py ]; then
  DIR=/mmc/root/payloads/user/reconnaissance/c5_wardriver_node
else
  ERROR_DIALOG "C5 Wardriver node worker is missing."
  exit 1
fi
IFACE=wlan1mon; STATS=/tmp/c5-pager-node.json; LOGFILE=/tmp/c5-pager-node.log
CORE_CONFIG=/root/.config/c5-wardriver/core_mac
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
# Pager packages installed on MMC are not included in the stock interpreter path.
PYTHON_MMCLIB="/mmc/usr/lib/python$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
if [ -d "$PYTHON_MMCLIB" ]; then
  export PYTHONPATH="$PYTHON_MMCLIB:$PYTHON_MMCLIB/lib-dynload${PYTHONPATH:+:$PYTHONPATH}"
fi
python3 -c 'import argparse,json,select,socket,struct,subprocess' >/dev/null 2>&1 || {
  ERROR_DIALOG "Python 3 standard-library modules are unavailable. Install python3-light."; exit 1;
}
iw dev "$IFACE" info >/dev/null 2>&1 || { ERROR_DIALOG "wlan1mon is unavailable."; exit 1; }
[ -s "$CORE_CONFIG" ] || { ERROR_DIALOG "Configure the C5 Core MAC in $CORE_CONFIG first."; exit 1; }
CORE_MAC=$(python3 -c 'import sys; print(open(sys.argv[1]).read().strip())' "$CORE_CONFIG")
echo "$CORE_MAC" | grep -Eq '^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$' || { ERROR_DIALOG "The configured C5 Core MAC is invalid."; exit 1; }
PROMPT_IMAGE "$DIR/splash.png"
CONFIRMATION_DIALOG "Start C5 Wardriver 6 GHz node?" || exit 0
OLD_HOP=$(uci -q get pineapd.wlan1mon.hop); OLD_CHANNEL=$(uci -q get pineapd.wlan1mon.channel)
uci set pineapd.wlan1mon.hop=0; uci set pineapd.wlan1mon.channel=6; RADIO_SET=1
/etc/init.d/pineapd restart >/dev/null 2>&1; sleep 3
rm -f "$STATS"
python3 "$DIR/c5_pager_node.py" --iface "$IFACE" --core "$CORE_MAC" --stats "$STATS" >"$LOGFILE" 2>&1 & PID=$!
LOG cyan "C5 WARDRIVER 6 GHz NODE"
while kill -0 "$PID" 2>/dev/null; do
  status=$(python3 "$DIR/c5_pager_node.py" --render-stats "$STATS")
  if echo "$status" | grep -q "CORE: LINKED"; then
    LOG green "$status"
  else
    LOG yellow "$status"
  fi

  timeout 2 WAIT_FOR_BUTTON_PRESS A >/dev/null 2>&1
  rc=$?
  [ "$rc" -eq 0 ] && break
  [ "$rc" -eq 124 ] || sleep 2
done
if ! kill -0 "$PID" 2>/dev/null; then
  LOG red "Node worker stopped. See $LOGFILE"
fi
kill "$PID" 2>/dev/null; wait "$PID" 2>/dev/null; PID=""
if [ -s "$STATS" ]; then
  summary=$(python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); print("Core: %s\n6 GHz seen: %d\nRecords sent: %d\nCore ACKs: %d"%(s.get("core") or "not found",s["seen"],s["sent"],s.get("acked",0)))' "$STATS")
  PROMPT "$summary"
else
  ERROR_DIALOG "Node stopped before producing status. See $LOGFILE"
fi
