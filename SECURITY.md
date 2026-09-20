# Security and privacy

Omagic manages input-device preferences. It is not an authentication system.

## Data and access

- No telemetry, analytics, HTTP client, remote assets, credential storage, or upload code. The plugin invokes local Omarchy/BlueZ commands; Bluetooth discovery and pairing communicate with nearby devices.
- Device addresses are kept locally to reconnect known devices. State files are created with mode `0600` in a `0700` directory. CLI/panel status omits device addresses, serial numbers, and personal device names. Do not publish your state files or terminal diagnostics without reviewing them.
- QML displays runtime messages as plain text, preventing error text from being interpreted as rich text with external image URLs.
- Subprocesses use argument lists, without shell interpolation. Bluetooth addresses and settings are validated; device names are escaped before generating Lua. Failed configuration reloads restore the previous profile.
- The optional root-owned function-key helper accepts exactly one argument, `1` or `2`, and writes only the `hid_apple` function-key parameter. Installing it requires administrator authentication; its polkit policy then permits this one operation for active local desktop sessions only, with no repeated prompt. Inactive and remote sessions are denied. The plugin does not request raw HID access, open an authentication socket, or install a daemon/PAM module.
- Release archives use an explicit file list and exclude local state, caches, diagnostics, and development backups.

## Prototype migration

The pre-0.4 prototype's raw HID matching and user-controlled PAM socket were unsafe authentication mechanisms. They have been removed. Existing installations must run the documented legacy cleanup; upgrading source files alone does not remove system PAM hooks. Cleanup keeps backups of modified PAM files. Do not restore those backups without removing the legacy authentication lines.

Reboot after cleanup to clear legacy device ACLs. The old installer also attempted to add its user to the `input` group; review that membership separately before removing it, since other installed software may depend on it.

## Verification and limits

The release was reviewed for network/data flows, subprocess injection, local file permissions, privileged operations, generated Lua, accidental HTML loading, and archive contents. Regression tests cover input validation, private state permissions, status redaction, configuration rollback, and secondary-click behavior. The optional QML smoke test exercises every panel control with a mock backend, rapid changes, and error rollback.

This is a source and local-runtime review, not a guarantee against all vulnerabilities. Omarchy, Quickshell, BlueZ, Hyprland, polkit, Linux device drivers, Bluetooth peers, and software running as your user remain outside this plugin's security boundary. Bluetooth names are discovery hints, not proof of hardware identity; pair only devices you intend to trust.

Report security issues through [GitHub private vulnerability reporting](https://github.com/betnbd/Omagic/security/advisories/new). Do not include passwords, tokens, enrollment data, or unredacted local state in public reports.
