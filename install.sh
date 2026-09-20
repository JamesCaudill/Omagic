#!/bin/bash
# Install an extracted release without requiring Git or root.
set -euo pipefail
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
plugin_dir="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/ben.omagic"
for command in python3 omarchy omarchy-shell; do
  command -v "$command" >/dev/null || { echo "Missing dependency: $command" >&2; exit 1; }
done
if [[ $(realpath -m -- "$plugin_dir") != "$source_dir" ]]; then
  [[ ! -e $plugin_dir && ! -L $plugin_dir ]] || {
    echo "Already installed: $plugin_dir. Update it in place or remove it first." >&2
    exit 1
  }
  omarchy plugin validate "$source_dir"
  mkdir -p -- "$plugin_dir"
  for file in Panel.qml WandIcon.qml Model.js manifest.json omagic.py omagic_lib.py set-fnmode.sh install-fnmode.sh cleanup-legacy.sh README.md SECURITY.md LICENSE; do
    cp -p -- "$source_dir/$file" "$plugin_dir/"
  done
fi
omarchy-shell shell rescanPlugins
omarchy plugin enable ben.omagic --section right
printf 'Installed Omagic in %s\n' "$plugin_dir"
