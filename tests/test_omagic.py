"""Hardware-independent regressions; never change the desktop or pair devices."""
import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import omagic_lib as om

spec = importlib.util.spec_from_file_location("cli", Path(__file__).resolve().parents[1] / "omagic.py")
cli = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cli)


class SettingsTests(unittest.TestCase):
    def test_invalid_settings(self):
        for data in ({"tapToClick": "false"}, {"sensitivity": True},
                     {"sensitivity": float("nan")}, {"scrollFactor": 0},
                     {"unknown": True}, {"sensitivity": 10}):
            with self.subTest(data=data), self.assertRaises(ValueError):
                om.validate_settings(data)

    def test_corrupt_state_falls_back(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state.json"
            with patch.object(om, "STATE_PATH", path), patch.object(om, "SETTINGS_PATH", path):
                path.write_text('[]')
                self.assertEqual(om.load_saved(), {})
                path.write_text('{"tapToClick":"yes"}')
                self.assertEqual(om.load_settings(), om.DEFAULT_SETTINGS)

    def test_atomic_writes_leave_no_temporary_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "settings.json"
            with patch.object(om, "SETTINGS_PATH", path), patch.object(om, "STATE_DIR", Path(directory)):
                om.save_settings({"tapToClick": True})
                self.assertTrue(om.load_settings()["tapToClick"])
                self.assertEqual(list(Path(directory).iterdir()), [path])

    def test_fn_failure_does_not_save_or_require_trackpad(self):
        with patch.object(om, "apply_fnmode", return_value=(False, "denied")), \
             patch.object(om, "save_settings") as save, patch.object(cli, "apply_trackpad") as apply:
            with self.assertRaisesRegex(RuntimeError, "denied"):
                cli.set_settings('{"macFnKeys":false}')
            save.assert_not_called()
            apply.assert_not_called()

    def test_state_permissions_are_private(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory) / "private"
            with patch.object(om, "STATE_DIR", state), patch.object(om, "STATE_PATH", state / "state.json"):
                om.save_saved({"addresses": ["AA:BB:CC:DD:EE:FF"]})
                self.assertEqual(state.stat().st_mode & 0o777, 0o700)
                self.assertEqual(om.STATE_PATH.stat().st_mode & 0o777, 0o600)

    def test_public_status_excludes_identifiers(self):
        devices = om.public_devices([{"name": "Magic Trackpad", "link": "USB", "battery": 50,
                                      "serial": "private", "bluetooth": {"address": "private"}}])
        self.assertNotIn("private", json.dumps(devices))


class BluetoothTests(unittest.TestCase):
    def test_battery_hex_and_decimal(self):
        for value in ("0x62 (98)", "98", "0x62"):
            with patch.object(om, "run", return_value=subprocess.CompletedProcess([], 0, f"Battery Percentage: {value}\n", "")):
                self.assertEqual(om.bt_info("AA:BB:CC:DD:EE:FF")["battery"], 98)

    def test_no_generic_mouse_or_keyboard(self):
        for info in ({"icon": "input-mouse"}, {"icon": "input-keyboard"}, {"alias": "Logitech Trackpad"}):
            self.assertIsNone(om.classify_bt(info))
        self.assertEqual(om.classify_bt({"modalias": "bluetooth:v004cp0324d0319"}), "trackpad")

    def test_ansi_listing(self):
        self.assertEqual(om.parse_device_listing('\x1b[0;92mDevice AA:BB:CC:DD:EE:FF Magic Trackpad\x1b[0m'),
                         [("AA:BB:CC:DD:EE:FF", "Magic Trackpad")])

    def test_disconnected_devices_are_not_present_or_merged(self):
        devices = [{"kind": "trackpad", "address": mac, "alias": "Magic Trackpad", "connected": False}
                   for mac in ("AA:BB:CC:DD:EE:01", "AA:BB:CC:DD:EE:02")]
        with patch.object(om, "hypr_devices", return_value={}), patch.object(om, "hid_devices", return_value=[]), \
             patch.object(om, "batteries", return_value={}), patch.object(om, "bluetooth_magic", return_value=devices), \
             patch.object(om, "enabled_plugin_ids", return_value=set()):
            snapshot = om.merge_devices()
            self.assertFalse(snapshot["trackpad"]["present"])
            self.assertEqual(len(snapshot["trackpad"]["devices"]), 2)

    def test_pair_without_connection_fails(self):
        with patch.object(om, "run"), patch.object(om, "known_addresses", return_value=[]), \
             patch.object(om, "discover_magic", return_value=[{"address": "AA:BB:CC:DD:EE:FF"}]), \
             patch.object(om, "bt_info", return_value={"paired": True, "connected": False}):
            with self.assertRaisesRegex(RuntimeError, "did not connect"):
                cli.setup_wireless("trackpad")

    def test_multiple_candidates_are_not_automatically_paired(self):
        with patch.object(om, "run") as run, patch.object(om, "known_addresses", return_value=[]), \
             patch.object(om, "discover_magic", return_value=[{}, {}]):
            with self.assertRaisesRegex(RuntimeError, "Multiple"):
                cli.setup_wireless("keyboard")
            self.assertEqual(run.call_count, 1)


class ProfileTests(unittest.TestCase):
    def test_tap_is_persistent_and_device_scoped(self):
        profile = om.render_profile(['a"b\\c\nd'], {"tapToClick": True, "workspaceSwipe": False})
        self.assertIn("tap_to_click = true", profile)
        self.assertIn('name = "a\\"b\\\\c\\nd"', profile)
        self.assertNotIn("input =", profile)

    def test_secondary_click_off_uses_button_areas(self):
        for value in (True, False):
            profile = om.render_profile(["magic-trackpad"], {"clickfinger": value})
            self.assertIn("clickfinger_behavior = " + str(value).lower(), profile)

    def test_drag_avoids_horizontal_gesture_conflict(self):
        profile = om.render_profile(["magic-trackpad"], {"drag3fg": True, "notificationCenter": True})
        self.assertIn('fingers = 4, direction = "horizontal"', profile)
        self.assertNotIn("notifications", profile)

    def test_failed_reload_restores_old_profile(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "profile.lua"
            path.write_text("old profile")
            with patch.object(om, "PROFILE_PATH", path), patch.object(om, "enabled_plugin_ids", return_value=set()), \
                 patch.object(om, "hypr_devices", return_value={"trackpad": ["magic-trackpad"]}), \
                 patch.object(om, "hypr_reload", side_effect=[(False, "bad Lua"), (True, "")]), \
                 patch.object(om, "save_settings") as save:
                with self.assertRaisesRegex(RuntimeError, "bad Lua"):
                    cli.set_settings('{"tapToClick":true}')
                self.assertEqual(path.read_text(), "old profile")
                save.assert_not_called()

    def test_first_failed_profile_is_removed(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "profile.lua"
            with patch.object(om, "PROFILE_PATH", path), patch.object(om, "enabled_plugin_ids", return_value=set()), \
                 patch.object(om, "hypr_devices", return_value={"trackpad": ["magic-trackpad"]}), \
                 patch.object(om, "hypr_reload", side_effect=[(False, "bad Lua"), (True, "")]):
                with self.assertRaises(RuntimeError):
                    cli.apply_trackpad()
                self.assertFalse(path.exists())

    def test_other_plugin_blocks_without_writes(self):
        with patch.object(om, "enabled_plugin_ids", return_value={om.PLUS_ID}), patch.object(om, "atomic_write") as write:
            with self.assertRaisesRegex(ValueError, "Trackpad Plus"):
                cli.apply_trackpad()
            write.assert_not_called()

    def test_failed_error_query_is_not_success(self):
        results = [subprocess.CompletedProcess([], 0, "ok", ""), subprocess.CompletedProcess([], 1, "", "offline")]
        with patch.object(om, "run", side_effect=results):
            self.assertEqual(om.hypr_reload(), (False, "offline"))


if __name__ == "__main__":
    unittest.main()
