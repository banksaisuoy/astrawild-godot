#!/bin/bash
# v1.7 capture harness — 1920x1080 showcase set (vista/game/variants/tierb/boss).
# Fresh Xvfb per attempt (llvmpipe pre-autoload deadlock is nondeterministic).
# Usage: bash tools/cap_v17.sh <outname> <timeout_s> <args...>
set -u
GODOT=/home/z/godot-tools/Godot_v4.7.2-stable_linux.x86_64
PROJ=/home/z/astrawild-godot
OUT="$1"; shift
TMO="$1"; shift
for attempt in 1 2 3 4 5 6; do
  echo "=== $OUT attempt $attempt ==="
  rm -f "$PROJ"/shot_*.png /tmp/.X11-unix/X99
  nohup setsid Xvfb :99 -screen 0 1920x1080x24 > /tmp/xvfb.log 2>&1 < /dev/null &
  disown
  sleep 2
  DISPLAY=:99 timeout "$TMO" "$GODOT" --path "$PROJ" --resolution 1920x1080 \
    -- --screenshot "$@" > "/tmp/cap_$OUT.log" 2>&1
  rc=$?
  for f in "$PROJ"/shot_*.png; do
    [ -e "$f" ] || continue
    mv "$f" "docs/shots/v17/$OUT.png"
    echo "OK -> docs/shots/v17/$OUT.png (attempt $attempt, rc=$rc)"
    grep -E "WORLDGEN|SCREENSHOT saved" "/tmp/cap_$OUT.log" | tail -2
    exit 0
  done
  echo "no png (rc=$rc); retrying"
done
echo "FAILED: $OUT after 6 attempts"
exit 1
