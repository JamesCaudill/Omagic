#!/bin/bash
# Remove the pre-0.4 experimental authentication integration. Run before upgrading.
set -euo pipefail
[[ $EUID == 0 ]] || { echo "Run: sudo ./cleanup-legacy.sh" >&2; exit 1; }
stamp=$(date +%Y%m%d-%H%M%S)
for file in /etc/pam.d/sudo /etc/pam.d/polkit-1 /etc/pam.d/omarchy-lock-password; do
  if [[ -f $file ]] && grep -q '/usr/lib/apple-magic/pam-wait' "$file"; then
    cp -a -- "$file" "$file.omagic-backup-$stamp"
    sed -i '\|/usr/lib/apple-magic/pam-wait|d' "$file"
    echo "Removed legacy authentication hook: $file"
  fi
done
rm -f /usr/lib/apple-magic/pam-wait /usr/lib/apple-magic/set-fnmode
rmdir /usr/lib/apple-magic 2>/dev/null || true
# The old policy points to the old helper; preserve a newly installed policy.
policy=/usr/share/polkit-1/actions/com.omagic.set-fnmode.policy
if [[ -f $policy ]] && grep -q '/usr/lib/apple-magic/set-fnmode' "$policy"; then
  rm -- "$policy"
fi
rm -f /etc/udev/rules.d/99-apple-magic-hidraw.rules
udevadm control --reload-rules
printf '%s\n' 'Legacy PAM hooks and HID rule removed. Reboot to clear old device ACLs.'
