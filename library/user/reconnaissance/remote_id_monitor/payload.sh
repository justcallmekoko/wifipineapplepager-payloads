#!/bin/bash
# Title: Remote ID Radar
# Author: JustCallMeKoko
# Description: Passively detects and tracks ASTM/OpenDroneID broadcasts over Wi-Fi and Bluetooth
# Version: 0.1.1
# Category: Reconnaissance

LAUNCH_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$LAUNCH_DIR/remote_id_monitor.py" ]; then
  DIR="$LAUNCH_DIR"
elif [ -f /root/payloads/user/reconnaissance/remote_id_monitor/remote_id_monitor.py ]; then
  DIR=/root/payloads/user/reconnaissance/remote_id_monitor
elif [ -f /mmc/root/payloads/user/reconnaissance/remote_id_monitor/remote_id_monitor.py ]; then
  DIR=/mmc/root/payloads/user/reconnaissance/remote_id_monitor
else
  ERROR_DIALOG "Remote ID Radar worker is missing."
  exit 1
fi

WORKER="$DIR/remote_id_monitor.py"
SPLASH="$DIR/splash.png"
STATE=/tmp/remote-id-radar.json
LOGFILE=/tmp/remote-id-radar.log
PID=""
LOCKDIR=/tmp/remote-id-radar.lock
LOCKED=0

cleanup() {
  if [ -n "$PID" ]; then
    kill "$PID" 2>/dev/null
    wait "$PID" 2>/dev/null
    PID=""
  fi
  if [ "$LOCKED" = 1 ] && [ -d "$LOCKDIR" ]; then
    owner=$(cat "$LOCKDIR/pid" 2>/dev/null || true)
    [ "$owner" = "$$" ] && rm -rf "$LOCKDIR"
  fi
}
trap cleanup EXIT
trap 'cleanup; exit 0' INT TERM

command -v python3 >/dev/null 2>&1 || { ERROR_DIALOG "Python 3 is required."; exit 1; }
PYTHON_MMCLIB="/mmc/usr/lib/python$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
if [ -d "$PYTHON_MMCLIB" ]; then
  export PYTHONPATH="$PYTHON_MMCLIB:$PYTHON_MMCLIB/lib-dynload${PYTHONPATH:+:$PYTHONPATH}"
fi
command -v tcpdump >/dev/null 2>&1 || { ERROR_DIALOG "The stock tcpdump package is required."; exit 1; }
iw dev wlan1mon info >/dev/null 2>&1 || { ERROR_DIALOG "wlan1mon is unavailable."; exit 1; }
python3 -m py_compile "$WORKER" >/dev/null 2>&1 || { ERROR_DIALOG "Remote ID Radar failed its startup check."; exit 1; }

if ! mkdir "$LOCKDIR" 2>/dev/null; then
  owner=$(cat "$LOCKDIR/pid" 2>/dev/null || true)
  if [ -n "$owner" ] && kill -0 "$owner" 2>/dev/null; then
    ERROR_DIALOG "Remote ID Radar is already running."
    exit 1
  fi
  rm -rf "$LOCKDIR"
  mkdir "$LOCKDIR" || { ERROR_DIALOG "Could not acquire the monitor lock."; exit 1; }
fi
printf '%s\n' "$$" >"$LOCKDIR/pid"
LOCKED=1

show_devices() {
  [ -s "$STATE" ] || { PROMPT "No Remote ID session data is available."; return; }
  mapfile -t devices < <(python3 "$WORKER" --list-state "$STATE")
  [ "${#devices[@]}" -gt 0 ] || devices=("No Remote ID devices")
  if [ "${devices[0]}" = "No Remote ID devices" ]; then
    PROMPT "No Remote ID devices were detected."
    return
  fi
  selected=$(LIST_PICKER "Remote ID devices" "${devices[@]}" "${devices[0]}") || return
  index=$(printf '%s' "$selected" | sed -n 's/^\([0-9][0-9]*\)\..*/\1/p')
  [ -n "$index" ] || return
  detail=$(python3 "$WORKER" --detail-state "$STATE" --index "$((index - 1))")
  PROMPT "$detail"
}

run_monitor() {
  timestamp=$(date +%Y%m%d_%H%M%S)
  if [ -d /mmc/root/loot ] && [ -w /mmc/root/loot ]; then
    loot_dir=/mmc/root/loot/remote_id_monitor
  else
    loot_dir=/root/loot/remote_id_monitor
  fi
  mkdir -p "$loot_dir"
  events="$loot_dir/remote_id_${timestamp}.jsonl"
  csv="$loot_dir/remote_id_${timestamp}.csv"
  gpx="$loot_dir/remote_id_${timestamp}.gpx"
  rm -f "$STATE"
  : >"$LOGFILE"
  python3 "$WORKER" --run --interface wlan1mon --wifi-channel 6 --state "$STATE" --events "$events" --csv "$csv" --gpx "$gpx" >>"$LOGFILE" 2>&1 &
  PID=$!

  LOG cyan "REMOTE ID RADAR"
  LOG "Passive Wi-Fi + Bluetooth monitor"
  LOG "Press A to stop"
  last_render=""
  last_event=0
  last_heartbeat=0
  while kill -0 "$PID" 2>/dev/null; do
    if [ -s "$STATE" ]; then
      render=$(python3 "$WORKER" --render-state "$STATE" 2>/dev/null || true)
      event=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("event_seq",0))' "$STATE" 2>/dev/null || echo 0)
      now=$(date +%s)
      if [ "$event" -gt "$last_event" ] 2>/dev/null; then
        VIBRATE 200 >/dev/null 2>&1 || true
        LOG green "NEW REMOTE ID DEVICE"
        last_event="$event"
      fi
      if [ "$render" != "$last_render" ] || [ $((now - last_heartbeat)) -ge 10 ]; then
        if echo "$render" | grep -q '^WARN '; then
          LOG red "$render"
        elif echo "$render" | grep -q '^ACTIVE [1-9]'; then
          LOG green "$render"
        else
          LOG cyan "$render"
        fi
        last_render="$render"
        last_heartbeat="$now"
      fi
    fi
    timeout 2 WAIT_FOR_BUTTON_PRESS A >/dev/null 2>&1
    rc=$?
    [ "$rc" -eq 0 ] && break
    [ "$rc" -eq 124 ] || sleep 1
  done

  if kill -0 "$PID" 2>/dev/null; then kill "$PID" 2>/dev/null; fi
  wait "$PID" 2>/dev/null
  PID=""

  if [ ! -s "$STATE" ]; then
    ERROR_DIALOG "Monitor stopped before producing status. See $LOGFILE"
    return
  fi
  summary=$(python3 "$WORKER" --render-state "$STATE")
  PROMPT "$summary\n\nLoot: $loot_dir"
  show_devices
}

[ -f "$SPLASH" ] && PROMPT_IMAGE "$SPLASH"
while true; do
  action=$(LIST_PICKER "REMOTE ID RADAR" "Start live monitor" "View last detections" "About" "Exit" "Start live monitor") || exit 0
  case "$action" in
    "Start live monitor") run_monitor ;;
    "View last detections") show_devices ;;
    "About") PROMPT "Remote ID Radar v0.1.1\n\nPassive ASTM/OpenDroneID monitor for Wi-Fi Beacon, Wi-Fi NAN, and Bluetooth broadcasts. Wi-Fi uses Remote ID channel 6 and restores the prior channel when stopped.\n\nLogs JSONL, CSV, and GPX under the MMC loot directory when available." ;;
    "Exit") exit 0 ;;
  esac
done
