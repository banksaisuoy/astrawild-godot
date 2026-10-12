#!/bin/bash
# v1.5.2 capture harness — the fresh sandbox's llvmpipe sometimes deadlocks
# the game boot pre-autoload (nondeterministic). Strategy: retry each shot
# with a fresh Xvfb until the PNG lands. Usage:
#   bash tools/cap_retry.sh <outname> <timeout_s> <args...>
set -u
GODOT=/home/z/godot-tools/Godot_v4.7.2-stable_linux.x86_64
PROJ=/home/z/astrawild-godot
OUT="$1"; shift
TMO="$1"; shift
for attempt in 1 2 3 4 5 6; do
  echo "=== $OUT attempt $attempt ==="
  rm -f "$PROJ"/shot_*.png /tmp/.X11-unix/X99
  nohup setsid Xvfb :99 -screen 0 800x450x24 > /tmp/xvfb.log 2>&1 < /dev/null &
  disown
  sleep 2
  DISPLAY=:99 timeout "$TMO" "$GODOT" --path "$PROJ" --resolution 800x450 \
    -- --screenshot "$@" > "/tmp/cap_$OUT.log" 2>&1
  rc=$?
  for f in "$PROJ"/shot_*.png; do
    [ -e "$f" ] || continue
    mv "$f" "docs/shots/v15_2/$OUT.png"
    echo "OK -> docs/shots/v15_2/$OUT.png (attempt $attempt, rc=$rc)"
    exit 0
  done
  echo "no png (rc=$rc); retrying"
done
echo "FAILED: $OUT after 6 attempts"
exit 1
