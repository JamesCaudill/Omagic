#!/bin/bash
# Optional: install a narrowly scoped root-owned Fn-mode helper.
set -euo pipefail
[[ $EUID == 0 ]] || { echo "Run: sudo ./install-fnmode.sh" >&2; exit 1; }
plugin_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
install -Dm755 "$plugin_dir/set-fnmode.sh" /usr/lib/omagic/set-fnmode
install -d /usr/share/polkit-1/actions
cat > /usr/share/polkit-1/actions/com.omagic.set-fnmode.policy <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<policyconfig>
  <action id="com.omagic.set-fnmode">
    <description>Set Apple keyboard function-key mode</description>
    <message>Authenticate to change Apple keyboard function-key mode</message>
    <defaults>
      <allow_any>no</allow_any>
      <allow_inactive>no</allow_inactive>
      <allow_active>yes</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">/usr/lib/omagic/set-fnmode</annotate>
  </action>
</policyconfig>
XML
chmod 644 /usr/share/polkit-1/actions/com.omagic.set-fnmode.policy
