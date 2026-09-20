#!/bin/bash
# fnmode 1 = Mac (media row, Globe/Fn for F-keys). 2 = F-keys first.
set -euo pipefail
[[ $# == 1 ]] || { echo "usage: set-fnmode 1|2" >&2; exit 2; }
val="$1"
case "$val" in
1 | 2) ;;
*)
  echo "usage: set-fnmode 1|2" >&2
  exit 2
  ;;
esac
printf '%s\n' "$val" >/sys/module/hid_apple/parameters/fnmode
