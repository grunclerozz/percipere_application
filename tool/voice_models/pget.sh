#!/bin/bash
# Parallel ranged download: pget.sh URL OUT SIZE PARTS
url=$1; out=$2; size=$3; parts=$4
dir="$out.parts"; mkdir -p "$dir"
chunk=$(( (size + parts - 1) / parts ))
for i in $(seq 0 $((parts-1))); do
  start=$(( i * chunk )); end=$(( start + chunk - 1 )); [ $end -ge $size ] && end=$((size-1))
  want=$(( end - start + 1 ))
  ( f="$dir/$i"; for try in 1 2 3 4 5 6 7 8; do
      have=$( [ -f "$f" ] && stat -c %s "$f" || echo 0 )
      [ "$have" -ge "$want" ] && break
      curl -sL --max-time 1200 -r $((start+have))-$end "$url" >> "$f"
    done ) &
done
wait
cat $(for i in $(seq 0 $((parts-1))); do echo "$dir/$i"; done) > "$out"
stat -c %s "$out"; sha256sum "$out"
