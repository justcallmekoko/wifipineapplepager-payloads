# C5 Wardriver Pager Node

Development preview for WiFi Pineapple Pager 2.0.0. It scans 6 GHz preferred scanning channels with the Pager's MT7921AU radio and forwards observations to a nearby C5 Wardriver running in unencrypted Core mode.

## Current scope

- 6 GHz PSC scanning only
- Existing C5 ESP-NOW discovery, heartbeat, and text framing
- Explicit $W6$ record type so the Core calculates the correct 6 GHz frequency
- Bounded queue and 30-second BSSID deduplication

## Requirements

- C5 Wardriver firmware containing Pager protocol support
- C5 configured as Core with ESP-NOW encryption disabled
- Pager $wlan1mon$ available in monitor mode
- Python 3 installed on the Pager

This is an early hardware-validation build, not yet ready for upstream submission.
