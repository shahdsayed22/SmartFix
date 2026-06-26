#!/usr/bin/env bash
# ============================================================
# SmartFix — mobile capture helper (real Android device).
# Bridges the phone to the API, keeps the screen awake, launches
# the app, and screen-records with scrcpy. Driving (the taps) is
# done by the automated tour (drive-phone.sh) or by hand.
#
#   bash scripts/demo/capture-mobile.sh start   # reverse + wake + launch + record
#   bash scripts/demo/capture-mobile.sh stop    # stop recording
#
# Requires: a connected, UNLOCKED device (secure lockscreen must be
# off or the phone unlocked first) and scrcpy installed.
# ============================================================
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT="scripts/demo/out"; mkdir -p "$OUT"
ADB="${ADB:-$(command -v adb || echo "$HOME/Android/Sdk/platform-tools/adb")}"
PKG="com.smartfix.smart_fix"
REC="$OUT/smartfix-mobile-demo.mkv"

dev(){ "$ADB" get-state >/dev/null 2>&1 || { echo "No device. Plug in + unlock the phone."; exit 1; }; }

case "${1:-start}" in
  start)
    dev
    echo "▶ bridging phone → API (adb reverse 3000)…"; "$ADB" reverse tcp:3000 tcp:3000
    echo "▶ keep screen awake…"; "$ADB" shell svc power stayon true >/dev/null 2>&1 || true
    "$ADB" shell settings put system screen_off_timeout 1800000 >/dev/null 2>&1 || true
    echo "▶ launching app…"; "$ADB" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
    echo "▶ recording → $REC  (Ctrl-C or run: $0 stop)"
    # --no-window keeps it headless on CI/agent boxes; drop it to also watch live.
    scrcpy --no-audio --max-fps=30 --video-bit-rate=8M --record "$REC" ${SCRCPY_FLAGS:-} &
    echo $! > "$OUT/.scrcpy.pid"
    echo "scrcpy pid $(cat "$OUT/.scrcpy.pid")"
    ;;
  stop)
    if [ -f "$OUT/.scrcpy.pid" ]; then
      kill -INT "$(cat "$OUT/.scrcpy.pid")" 2>/dev/null || true; sleep 1
      rm -f "$OUT/.scrcpy.pid"
    fi
    "$ADB" shell svc power stayon false >/dev/null 2>&1 || true
    if [ -f "$REC" ]; then
      ffmpeg -y -loglevel error -i "$REC" -c:v libx264 -pix_fmt yuv420p -movflags +faststart "$OUT/smartfix-mobile-demo.mp4"
      echo "✅ $OUT/smartfix-mobile-demo.mp4"
    fi
    ;;
  *) echo "usage: $0 {start|stop}"; exit 1;;
esac
