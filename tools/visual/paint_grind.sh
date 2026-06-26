#!/usr/bin/env bash
# paint_grind.sh — robustly repaint clay frames into the VtM style via agy.
# Each frame is a fully-separate agy process with cooldown + retry (agy fails on
# rapid repeats, so we space them and retry). Idempotent: skips frames already painted.
#   usage: paint_grind.sh <clay_dir> <painted_dir> <bible.png> [cooldown] [max]
set -u
CLAY="$1"; OUT="$2"; BIBLE="$3"; COOL="${4:-70}"; MAX="${5:-9999}"
mkdir -p "$OUT"
mapfile -t FRAMES < <(ls "$CLAY"/clay_*.png 2>/dev/null | sort)
done_n=0; made=0
for f in "${FRAMES[@]}"; do
  base=$(basename "$f" .png)            # clay_d0_p0
  out="$OUT/p_${base#clay_}.png"        # p_d0_p0.png
  if [ -f "$out" ] && [ "$(wc -c <"$out")" -gt 50000 ]; then echo "skip $base (done)"; done_n=$((done_n+1)); continue; fi
  [ "$made" -ge "$MAX" ] && { echo "hit MAX=$MAX this run"; break; }
  ok=0
  for attempt in 1 2 3; do
    rm -f "$out"
    timeout 340 agy --dangerously-skip-permissions -p "Character bible (identity reference): $BIBLE — a pale gaunt vampire, fitted black leather longcoat with collar up, slicked dark hair, cold blue + warm orange light. Input clay render: $f — the SAME character in a specific pose at a specific facing direction (rough grey 3D). REPAINT it into gritty VtM/Hellsing hand-painted style as the EXACT SAME character as the bible (identical face, hair, coat, palette), keeping this input's pose, facing direction, camera angle, silhouette and framing IDENTICAL. Isolated on a plain dark background. Save to exactly $out" >"$OUT/${base}.log" 2>&1
    if [ -f "$out" ] && [ "$(wc -c <"$out")" -gt 50000 ]; then ok=1; break; fi
    echo "  retry $base (attempt $attempt failed)"; sleep "$COOL"
  done
  if [ "$ok" = 1 ]; then echo "painted $base $(date +%H:%M:%S)"; made=$((made+1)); else echo "FAILED $base after 3 tries"; fi
  sleep "$COOL"
done
echo "GRIND DONE: $made painted this run, $done_n already done, total $(ls "$OUT"/p_*.png 2>/dev/null|wc -l)/${#FRAMES[@]}"
