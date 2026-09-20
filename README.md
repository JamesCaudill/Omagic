# Omagic

A small [Omarchy](https://omarchy.org/) bar plugin for Apple Magic Keyboard and Magic Trackpad. Connect over Bluetooth, check battery levels, and adjust trackpad feel and gestures from one panel.

Python standard library only. No background daemon or root access is needed for device status and trackpad settings.

## Requirements

- Omarchy with its Quickshell plugin system and **Hyprland 0.56+ Lua configuration**. The old Waybar / `hyprland.conf` setup is not supported.
- Python 3.10+, BlueZ (`bluetoothctl`), `hyprctl`, and the `omarchy` / `omarchy-shell` commands.
- For the optional function-key control: the `hid_apple` kernel module, polkit, and its graphical authentication agent.

Device support depends on the Linux HID drivers and Bluetooth adapter. Battery values appear when the device reports them. Detection recognizes Magic device names and known Apple product IDs; ordinary Bluetooth mice and keyboards are excluded.

## Install as an Omarchy plugin

Install directly from the public repository:

```sh
omarchy plugin add https://github.com/betnbd/Omagic.git --enable
```

Or download and extract the [latest release](https://github.com/betnbd/Omagic/releases/latest), then run from the extracted **Omagic** folder:

```sh
./install.sh
```

This copies the plugin to `~/.config/omarchy/plugins/ben.omagic`, rescans the shell, and enables its wand icon on the right of the bar. It honors `XDG_CONFIG_HOME`. An existing installation is never overwritten.

For a development checkout, run from its root instead:

```sh
mkdir -p ~/.config/omarchy/plugins
ln -s "$(pwd -P)" ~/.config/omarchy/plugins/ben.omagic
omarchy-shell shell rescanPlugins
omarchy plugin enable ben.omagic --section right
```

If the icon does not appear after a code update, run `omarchy restart shell`.

To update a Git-based installation, run `omarchy plugin update ben.omagic`.

### Optional: function-key control

From the extracted source or installed plugin directory:

```sh
sudo ./install-fnmode.sh
```

This installs `/usr/lib/omagic/set-fnmode` and a polkit policy. **Media keys first** uses `hid_apple` mode 1; off uses mode 2. After this one-time administrator installation, an active local desktop session can switch modes without another password prompt. Inactive and remote sessions are denied. The setting affects all keyboards handled by `hid_apple` and lasts until the module is reloaded or the machine reboots. For a persistent preference, configure `options hid_apple fnmode=1` (or `2`) in your system's modprobe configuration.

The helper accepts only `1` or `2`. It does not install PAM hooks or grant raw input access.

## Use

- **Devices:** connection state and battery for the first connected device of each kind; Bluetooth connection buttons; function-key mode. For several discoverable Magic devices, use Omarchy's Bluetooth panel to choose which one to pair.
- **Trackpad:** tap to click, secondary-click method, natural scrolling, tracking and scroll speed, and disable-while-typing.
- **Gestures:** workspace swipes, three-finger drag, desktop pinch zoom, app launcher, and notification history.

Switches react immediately and save automatically in the background. Rapid changes are queued; a failed change reverts and displays an error. **Use defaults** removes Omagic's generated profile while keeping saved preferences. **Apply saved** reapplies them, including after switching between USB and Bluetooth if the device name changes.

Use Tab / Shift+Tab to move through controls, Space / Enter to activate, arrow keys to adjust a focused slider, and Escape to close. Long panels scroll on smaller screens.

Trackpad feel applies to detected Magic Trackpad device names. Hyprland gestures are global and affect other touchpads too. Three-finger drag moves workspace swipes to four fingers; notification history is unavailable while that horizontal gesture is occupied. Pinch zoom magnifies the desktop, not application content. Other custom Hyprland gestures can conflict with these assignments. See the [Hyprland gesture documentation](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/) for compositor behavior.

When Trackpad Plus or Trackpad Pulse is enabled, Omagic disables its trackpad controls. Use **Use defaults** to remove an existing Omagic profile before handing control to another plugin.

## Touch ID and upgrades from the prototype

**Omagic does not provide Touch ID authentication.** The previous prototype compared raw HID packets and trusted a user-controlled socket for PAM authentication. Those mechanisms do not establish fingerprint identity and have been removed. Apple's implementation uses a secure connection to a Mac's Secure Enclave; see [Apple Platform Security](https://support.apple.com/en-ie/guide/security-pdf/secf60513daa/1/web/1).

If the old `ben.apple-magic` prototype was installed, clean it up **before enabling this version**:

```sh
systemctl --user disable --now apple-magic-touchid.service
sudo ./cleanup-legacy.sh
rm -f ~/.config/systemd/user/apple-magic-touchid.service
systemctl --user daemon-reload
omarchy plugin disable ben.apple-magic
rm -f "${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/toggles/hypr/zz-apple-magic.lua"
hyprctl reload
hyprctl configerrors
```

The service or plugin commands can report “not found” if those components were never installed. `cleanup-legacy.sh` backs up affected PAM files alongside the originals, removes only lines referencing the legacy helper, and removes its old helper files and udev rule. Reboot to clear previously granted device ACLs. The old installer may also have added your user to the `input` group; remove that membership only if no other software requires it.

Remove the old plugin folder or symlink after saving any local changes. To keep preferences, move `settings.json` and `state.json` from the old `apple-magic` state directory into the new `omagic` state directory **only if the destination files do not exist**. Old enrollment files are not used. Install the new plugin, connect the trackpad, and choose **Apply saved**.

## CLI and storage

Run from the source or plugin directory:

```sh
python3 omagic.py state
python3 omagic.py setup-wireless keyboard
python3 omagic.py setup-wireless trackpad
python3 omagic.py set-settings '{"naturalScroll":true}'
python3 omagic.py apply-trackpad
python3 omagic.py revert-trackpad
python3 omagic.py --help
```

Commands return JSON; failures return a nonzero exit status. Settings are validated before use, and an invalid generated Hyprland profile is rolled back.

| Path | Purpose |
| --- | --- |
| `~/.config/omarchy/plugins/ben.omagic/` | Installed plugin |
| `~/.local/state/omarchy/omagic/settings.json` | Preferences |
| `~/.local/state/omarchy/omagic/state.json` | Remembered Bluetooth addresses |
| `~/.local/state/omarchy/toggles/hypr/zz-omagic.lua` | Generated Hyprland profile |

State paths honor `XDG_STATE_HOME`; config paths honor `XDG_CONFIG_HOME`. IPC target: `ben.omagic`, with `open`, `close`, `toggle`, `refresh`, `status`, and `showPage Devices|Trackpad|Gestures`.

## Uninstall

Before deleting the plugin:

```sh
python3 ~/.config/omarchy/plugins/ben.omagic/omagic.py revert-trackpad
omarchy plugin disable ben.omagic
```

Remove `~/.config/omarchy/plugins/ben.omagic` (or just unlink it if it is a development symlink). Remove the `omagic` state directory if you no longer want its saved preferences. Disabling the bar icon alone does not remove a generated Hyprland profile.

If you installed the optional Fn helper:

```sh
sudo rm -f /usr/lib/omagic/set-fnmode /usr/share/polkit-1/actions/com.omagic.set-fnmode.policy
sudo rmdir /usr/lib/omagic
```

## Development and release

```sh
python3 -m unittest discover -s tests -v
# Optional, in an Omarchy Wayland session (uses a mock backend):
python3 tests/ui_smoke.py
omarchy plugin validate .
./release.sh
```

`release.sh` checks Python and shell syntax, runs regression tests, and creates `dist/Omagic-1.0.0.tar.gz` with a SHA-256 checksum. If available, it also checks the Omarchy manifest and QML syntax. Generated caches and local state are excluded. Hardware-independent tests cover settings validation, Bluetooth parsing and identity, device grouping, pairing failures, plugin conflicts, and profile rollback.

A live check still needs an Omarchy session and hardware: inspect all three pages; exercise disconnected, busy, error, and disabled states; pair both devices; switch USB/Bluetooth; confirm battery readings; test gestures, Fn mode, and profile reset. Bluetooth pairing and privileged installation cannot be fully verified by the unit tests.

## Privacy

No telemetry or uploads. Saved Bluetooth addresses stay in private local state files; status output omits hardware identifiers. See [SECURITY.md](SECURITY.md) for the security review, data flow, and prototype cleanup.

## License

[MIT](LICENSE), copyright © 2026 ben. Omagic is an independent project and is not affiliated with Apple.
