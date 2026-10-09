#!/bin/bash
# v1.3 gameplay gallery capture — real boots under Xvfb, one shot per run
# Usage: bash tools/capture_gallery.sh [outdir]
set -u
GODOT=/home/z/godot-tools/Godot_v4.7.2-stable_linux.x86_64
PROJ=/home/z/astrawild-godot
OUT="${1:-$PROJ/gallery}"
mkdir -p "$OUT"

run_shot() {
  local outname="$1"; shift
  echo "=== CAPTURE $outname ==="
  timeout 180 env DISPLAY=:99 \
    "$GODOT" --path "$PROJ" --resolution 1600x900 -- \
    --screenshot "$@" 2>&1 | grep -E "SCREENSHOT saved|SCRIPT ERROR|ERROR:" | head -4
  if [ -f "$PROJ/shot_"*.png ]; then :; fi
  local found=""
  for f in "$PROJ"/shot_*.png; do
    [ -e "$f" ] || continue
    found="$f"
  done
  if [ -n "$found" ]; then
    mv "$found" "$OUT/$outname.png"
    echo "-> $OUT/$outname.png"
  else
    echo "!! FAILED: no png produced for $outname"
  fi
}

run_shot title            --shot=title --delay=7
run_shot gameplay_dawn    --shot=game  --delay=16
run_shot combat           --shot=combat --delay=12
run_shot zone_glimmerwood --shot=zone  --zone=Zone_Glimmerwood --delay=12
run_shot zone_frostveil   --shot=zone  --zone=Zone_Frostveil   --delay=12
run_shot zone_emberridge  --shot=zone  --zone=Zone_EmberRidge  --delay=12
run_shot zone_duskmarsh   --shot=zone  --zone=Zone_DuskMarsh   --delay=12
run_shot zone_pearlsea    --shot=zone  --zone=Zone_PearlseaReef --delay=12
run_shot village          --shot=village --delay=12
run_shot plaza            --shot=plaza  --delay=12
run_shot night            --shot=night  --delay=12
run_shot gallery          --shot=gallery --delay=14
run_shot tierb            --shot=tierb  --delay=14
run_shot map              --shot=map   --delay=11
run_shot inventory        --shot=inv   --delay=11
run_shot help             --shot=help  --delay=10

echo "=== DONE ==="
ls -la "$OUT"
