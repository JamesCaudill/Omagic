#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
python3 -m unittest discover -s tests
python3 -m py_compile omagic.py omagic_lib.py
for script in ./*.sh; do bash -n "$script"; done
if command -v omarchy >/dev/null; then omarchy plugin validate .; fi
qmlformat=$(command -v qmlformat || true)
[[ -n $qmlformat || ! -x /usr/lib/qt6/bin/qmlformat ]] || qmlformat=/usr/lib/qt6/bin/qmlformat
if [[ -n $qmlformat ]]; then
  "$qmlformat" -n Panel.qml >/dev/null
  "$qmlformat" -n WandIcon.qml >/dev/null
fi
version=$(python3 -c 'import json; print(json.load(open("manifest.json"))["version"])')
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
mkdir -p dist
archive="Omagic-$version.tar.gz"
tar --sort=name --owner=0 --group=0 --numeric-owner \
  --transform='s,^,Omagic/,' --exclude=__pycache__ \
  -czf "dist/$archive" \
  Panel.qml WandIcon.qml Model.js manifest.json omagic.py omagic_lib.py \
  install.sh install-fnmode.sh set-fnmode.sh cleanup-legacy.sh \
  README.md SECURITY.md LICENSE release.sh tests
(cd dist && sha256sum "$archive" > "$archive.sha256")
printf 'Created dist/%s\n' "$archive"
